[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$policyPath = Join-Path $repoRoot 'App_Code\CartStorefrontScopePolicy.vb'
$harnessPath = Join-Path $PSScriptRoot 'CartConsistencyHarness.vb'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreCartConsistency-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $tempRoot 'CartConsistencyHarness.exe'

function Read-RepoFile([string]$relativePath) {
    return [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath))
}

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}

foreach ($required in @($compiler, $policyPath, $harnessPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw ('REQUIRED_FILE_MISSING=' + $required) }
}

$readModel = Read-RepoFile 'App_Code\CartAuthoritativeReadModel.vb'
$snapshot = Read-RepoFile 'App_Code\CartStateSnapshotProvider.vb'
$cartMarkup = Read-RepoFile 'carrello.aspx'
$cartCode = Read-RepoFile 'carrello.aspx.vb'
$miniCart = Read-RepoFile 'Public\ui\controls\MiniCart.ascx.vb'
$master = Read-RepoFile 'Page.master.vb'
$mutation = Read-RepoFile 'App_Code\CartMutationService.vb'
$nativeEndpoint = Read-RepoFile 'cart_add.aspx.vb'
$ownership = Read-RepoFile 'App_Code\CartOwnershipService.vb'

Assert-Source ($readModel -match 'CartStorefrontOwnerContext\.Resolve\(context\)') 'CART_READ_MODEL_USES_AUTHORITATIVE_OWNER'
Assert-Source ($readModel -match 'If\(_owner\.IsAuthenticated') 'CART_READ_MODEL_SELECTS_ONE_OWNER_PREDICATE'
Assert-Source ($readModel -match 'RequestCacheKey') 'CART_READ_MODEL_REQUEST_SCOPED'
Assert-Source ($cartMarkup -match 'TypeName="CartAuthoritativeReadDataSource"') 'CART_PAGE_USES_AUTHORITATIVE_READ_MODEL'
Assert-Source ($cartCode -notmatch 'sdsArticoli\.SelectCommand') 'CART_PAGE_LEGACY_QUERY_REMOVED'
Assert-Source ($miniCart -match 'CartAuthoritativeReadModel\.GetCurrent') 'MINICART_USES_AUTHORITATIVE_READ_MODEL'
Assert-Source ($miniCart -notmatch 'MySqlConnection|FROM\s+vcarrello') 'MINICART_LEGACY_QUERY_REMOVED'
Assert-Source ($miniCart -notmatch 'Session\("LoginI[Dd]"\)') 'MINICART_DOES_NOT_REBUILD_OWNER_SCOPE'
Assert-Source ($master -match 'CartAuthoritativeReadModel\.GetCurrent') 'HEADER_USES_AUTHORITATIVE_READ_MODEL'
Assert-Source ($master -notmatch 'Sum\(Qnt\).*FROM carrello WHERE') 'HEADER_LEGACY_CART_AGGREGATE_REMOVED'
Assert-Source ($snapshot -match 'CartAuthoritativeReadModel\.GetCurrent') 'CART_SNAPSHOT_USES_AUTHORITATIVE_READ_MODEL'
Assert-Source ($snapshot -notmatch 'MySqlConnection|FROM\s+carrello') 'CART_SNAPSHOT_LEGACY_QUERY_REMOVED'
Assert-Source ($mutation -match 'ownedRowIds\.Contains\(cartRowId\)[\s\S]+?Else[\s\S]+?CartTransactionWorkResult\(Of CartOwnerRemovalResult\)\.Abort') 'REMOVE_MISSING_OWNER_ROW_FAILS_CLOSED'
Assert-Source ($mutation -match 'CartAuthoritativeReadModel\.Invalidate\(ctx\)') 'CART_MUTATIONS_INVALIDATE_READ_MODEL'
Assert-Source ($nativeEndpoint -match 'Not clearAll AndAlso result\.AffectedRows <> 1') 'REMOVE_SUCCESS_REQUIRES_ONE_AFFECTED_ROW'
Assert-Source ($nativeEndpoint -match 'If result\.WasNoOp Then[\s\S]+?SessionChangedKey\) = 0') 'CLEAR_NOOP_DOES_NOT_REPORT_UPDATED'
Assert-Source ($ownership -match 'MergeRequestCacheKey') 'LOGIN_MERGE_RUNS_ONCE_PER_REQUEST'
Assert-Source ($ownership -match 'CartAuthoritativeReadModel\.Invalidate\(ctx\)') 'LOGIN_MERGE_INVALIDATES_READ_MODEL'

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" $policyPath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'CART_CONSISTENCY_HARNESS_COMPILE_FAILED' }
    & $executable
    if ($LASTEXITCODE -ne 0) { throw 'CART_CONSISTENCY_HARNESS_FAILED' }
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

Write-Output 'PASS CART_CONSISTENCY_23_SCENARIOS'
