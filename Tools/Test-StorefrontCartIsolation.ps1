[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$policyPath = Join-Path $repoRoot 'App_Code\CartStorefrontScopePolicy.vb'
$harnessPath = Join-Path $PSScriptRoot 'StorefrontCartIsolationHarness.vb'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreCartIsolation-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $tempRoot 'StorefrontCartIsolationHarness.exe'

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

$ownerContext = Read-RepoFile 'App_Code\CartStorefrontOwnerContext.vb'
$mutation = Read-RepoFile 'App_Code\CartMutationService.vb'
$idempotency = Read-RepoFile 'App_Code\CartMutationIdempotencyService.vb'
$ownership = Read-RepoFile 'App_Code\CartOwnershipService.vb'
$snapshot = Read-RepoFile 'App_Code\CartStateSnapshotProvider.vb'
$revalidation = Read-RepoFile 'App_Code\CartPriceRevalidationHelper.vb'
$cart = Read-RepoFile 'carrello.aspx.vb'
$miniCart = Read-RepoFile 'Public\ui\controls\MiniCart.ascx.vb'
$nativeEndpoint = Read-RepoFile 'cart_add.aspx.vb'
$asyncEndpoint = Read-RepoFile 'catalog_cart_async.aspx.vb'
$returnUrlPolicy = Read-RepoFile 'App_Code\StorefrontReturnUrlPolicy.vb'

Assert-Source ($ownerContext -match 'StorefrontSeoTenantContext\.Resolve\(context\)') 'CART_OWNER_TENANT_FROM_SERVER_CONTEXT'
Assert-Source ($ownerContext -match 'ConfiguredDatabaseScopeKey') 'CART_OWNER_DATABASE_SCOPE'
Assert-Source ($ownerContext -match 'AuthenticatedAziendaID') 'CART_AUTHENTICATED_COMPANY_MARKER'
Assert-Source ($ownerContext -match 'BuildAnonymousOwnerToken') 'CART_ANONYMOUS_DATABASE_COMPANY_TOKEN'
Assert-Source ($ownerContext -match 'BuildCanonicalRedirect') 'CART_MUTATION_CANONICAL_HOST_GUARD'
Assert-Source ($mutation -match 'CartStorefrontOwnerContext\.ResolveForMutation') 'CART_MUTATIONS_USE_AUTHORITATIVE_OWNER'
Assert-Source ($idempotency -match 'scope\.OwnerScopeKey') 'CART_IDEMPOTENCY_DATABASE_COMPANY_OWNER_SCOPE'
Assert-Source ($ownership -match 'BuildAnonymousOwnerToken') 'CART_LOGIN_MERGE_TENANT_SCOPED'
Assert-Source ($snapshot -match 'CartStorefrontOwnerContext\.Resolve\(context\)') 'CART_SNAPSHOT_TENANT_SCOPED'
Assert-Source ($revalidation -match 'CartStorefrontOwnerContext\.ResolveForMutation') 'CART_REVALIDATION_TENANT_SCOPED'
Assert-Source ($cart -match 'CartStorefrontOwnerContext\.Resolve\(HttpContext\.Current\)') 'CART_PAGE_TENANT_SCOPED'
Assert-Source ($miniCart -match 'CartStorefrontOwnerContext\.Resolve\(HttpContext\.Current\)') 'MINICART_TENANT_SCOPED'
Assert-Source ($nativeEndpoint -match 'Request\.HttpMethod.*POST') 'NATIVE_CART_POST_ONLY'
Assert-Source ($nativeEndpoint -match 'StatusCode\s*=\s*405') 'NATIVE_CART_GET_RETURNS_405'
Assert-Source ($nativeEndpoint -match 'ValidateCsrfToken') 'NATIVE_CART_CSRF_REQUIRED'
Assert-Source ($asyncEndpoint -match 'Request\.HttpMethod.*POST') 'ASYNC_CART_POST_ONLY'
Assert-Source ($asyncEndpoint -match 'Reject\(405') 'ASYNC_CART_GET_RETURNS_405'
Assert-Source ($asyncEndpoint -match 'ValidateCsrfToken') 'ASYNC_CART_CSRF_REQUIRED'
Assert-Source ($returnUrlPolicy -match 'Not String\.Equals\(resolved\.Host, context\.Request\.Url\.Host') 'CART_EXTERNAL_RETURN_URL_REJECTED'
Assert-Source ($snapshot -notmatch 'context\.Session\.SessionID') 'CART_SNAPSHOT_RAW_SESSION_ABSENT'
Assert-Source ($miniCart -notmatch 'Context\.Session\.SessionID') 'MINICART_RAW_SESSION_ABSENT'

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" $policyPath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'CART_ISOLATION_HARNESS_COMPILE_FAILED' }
    & $executable
    if ($LASTEXITCODE -ne 0) { throw 'CART_ISOLATION_HARNESS_FAILED' }
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

Write-Output 'PASS STOREFRONT_CART_ISOLATION'
