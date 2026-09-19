[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$harnessPath = Join-Path $PSScriptRoot 'OrderStorefrontProvenanceHarness.vb'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreOrderTenant-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $tempRoot 'OrderStorefrontProvenanceHarness.exe'

function Read-RepoFile([string]$relativePath) {
    return [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath))
}

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}

foreach ($required in @($compiler, $harnessPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw ('REQUIRED_FILE_MISSING=' + $required) }
}

$context = Read-RepoFile 'App_Code\OrderStorefrontContext.vb'
$durable = Read-RepoFile 'App_Code\OrderDurableIdempotencyService.vb'
$confirmation = Read-RepoFile 'App_Code\OrderConfirmationTokenService.vb'
$cart = Read-RepoFile 'carrello.aspx.vb'
$order = Read-RepoFile 'ordine.aspx.vb'
$documents = Read-RepoFile 'documenti.aspx.vb'
$documentsMarkup = Read-RepoFile 'documenti.aspx'
$documentDetail = Read-RepoFile 'documentidettaglio.aspx.vb'
$canonicalProcedure = Read-RepoFile 'Database Taikun\Migrations\20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_forward.sql'

Assert-Source ($context -match 'CartStorefrontOwnerContext\.Resolve\(context\)') 'ORDER_CONTEXT_SERVER_TENANT'
Assert-Source ($context -match 'DatabaseScopeKey') 'ORDER_CONTEXT_DATABASE_SCOPE'
Assert-Source ($context -match 'vlogin WHERE id=\?loginId AND AziendeID=\?aziendaId') 'ORDER_CONTEXT_ACCOUNT_COMPANY_VERIFIED'
Assert-Source ($context -match '(?i)SELECT\s+DISTINCT\s+utentiid\s*,\s*COALESCE\s*\(\s*listino\s*,\s*0\s*\)\s+AS\s+listino') 'ORDER_CONTEXT_DISTINCT_LOGICAL_IDENTITY'
Assert-Source ($context -match '"checkout-v3".*identity\.DatabaseScopeKey' -or $context -match '(?s)"checkout-v3".*identity\.DatabaseScopeKey') 'ORDER_FINGERPRINT_DATABASE_COMPANY_OWNER'
Assert-Source ($cart -match '"v3\|".*DatabaseScopeKey' -or $cart -match '(?s)"v3\|".*DatabaseScopeKey') 'CHECKOUT_TOKEN_TENANT_BOUND'
Assert-Source ($confirmation -match '"v2\|".*databaseScope' -or $confirmation -match '(?s)"v2\|".*databaseScope') 'CONFIRMATION_TOKEN_TENANT_BOUND'
Assert-Source ($durable -match 'Public Property AziendaId As Integer') 'IDEMPOTENCY_RECORD_COMPANY'
Assert-Source ($durable -match 'record\.AziendaId <> aziendaId') 'IDEMPOTENCY_REPLAY_COMPANY_GUARD'
Assert-Source ($durable -match 'd\.AziendeId=\?aziendaId') 'IDEMPOTENCY_COMPLETION_DOCUMENT_COMPANY_GUARD'
Assert-Source ($order -match 'vd\.AziendeId=\?aziendaId AND vd\.UtentiId=\?utentiId') 'CONFIRMATION_RECEIPT_OWNER_COMPANY_GUARD'
Assert-Source ($documents -match 'vdocumenti.*AziendeId') 'DOCUMENT_LIST_COMPANY_GUARD'
Assert-Source ($documentsMarkup -match 'vdocumenti.*AziendeId.*AziendaId') 'DOCUMENT_LIST_INITIAL_QUERY_COMPANY_GUARD'
Assert-Source ($documentDetail -match 'UtentiId=@uid AND AziendeId=@aziendaId') 'DOCUMENT_DETAIL_COMPANY_GUARD'
Assert-Source ($canonicalProcedure -match 'SELECT MAX\(ndocumento\).*documenti' -or $canonicalProcedure -match '(?s)SELECT MAX\(ndocumento\).*FROM documenti') 'DOCUMENT_NUMBER_GLOBAL_SOURCE'
$numberingSlice = [regex]::Match($canonicalProcedure, '(?s)SELECT MAX\(ndocumento\).*?INTO ndoc').Value
Assert-Source ($numberingSlice -notmatch 'AziendeId') 'DOCUMENT_NUMBER_NOT_PARTITIONED_BY_COMPANY'
Assert-Source ($canonicalProcedure -match 'AziendeId=Azienda') 'DOCUMENT_PROVENANCE_PERSISTED'
Assert-Source ($order -notmatch 'Session\.Item\("AziendaId"\)\s*=\s*2') 'ORDER_EMAIL_HARDCODED_COMPANY_REMOVED'
Assert-Source ($order -notmatch '(?i)taikun|webaffare') 'ORDER_SHARED_CODE_NO_CLIENT_NAME'
Assert-Source ($order -match 'LoadOrderEmailBrandData\(conn, receiptAziendaId, False\)') 'ORDER_EMAIL_BRAND_FROM_PERSISTED_COMPANY'
Assert-Source ($order -match 'emailBrand\.SmtpHost') 'ORDER_EMAIL_SMTP_FROM_PERSISTED_COMPANY'
Assert-Source ($order -match 'emailBrand\.AdministrativeRecipient') 'ORDER_EMAIL_ADMIN_FROM_PERSISTED_COMPANY'
Assert-Source ($order -match 'ReplyToList\.Add') 'ORDER_EMAIL_REPLY_TO_TENANT'
Assert-Source ($order.IndexOf('trns.Commit()', [StringComparison]::Ordinal) -lt $order.IndexOf('SendEmail(', $order.IndexOf('trns.Commit()', [StringComparison]::Ordinal), [StringComparison]::Ordinal)) 'ORDER_EMAIL_AFTER_COMMIT'
Assert-Source ($order -match 'Invio conferma ordine non riuscito\. Error type:') 'ORDER_EMAIL_FAILURE_SANITIZED'

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'ORDER_TENANT_HARNESS_COMPILE_FAILED' }
    & $executable
    if ($LASTEXITCODE -ne 0) { throw 'ORDER_TENANT_HARNESS_FAILED' }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = (Resolve-Path -LiteralPath $tempRoot).Path
        $allowedRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $resolvedTemp.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'UNSAFE_TEMP_CLEANUP_PATH'
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'PASS MULTI_STOREFRONT_ORDER_PROVENANCE_EMAIL'
