[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$policyPath = Join-Path $repoRoot 'App_Code\StorefrontCommercialIsolationPolicy.vb'
$harnessPath = Join-Path $PSScriptRoot 'StorefrontPricingAccountIsolationHarness.vb'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStorePricingIsolation-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $tempRoot 'StorefrontPricingAccountIsolationHarness.exe'

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

$login = Read-RepoFile 'login.aspx.vb'
$master = Read-RepoFile 'Page.master.vb'
$registration = Read-RepoFile 'registrazione.aspx.vb'
$homeSource = Read-RepoFile 'Default.aspx.vb'
$catalog = Read-RepoFile 'articoli.aspx.vb'
$pdp = Read-RepoFile 'articolo.aspx.vb'
$eligibility = Read-RepoFile 'App_Code\ProductPromotionEligibilityResolver.vb'
$display = Read-RepoFile 'App_Code\ProductPromotionDisplayHelper.vb'
$schema = Read-RepoFile 'Database Taikun\KeepStore.sql'

Assert-Source ($login -match 'WHERE AziendeID=\?aziendaId AND UPPER\(Username\)') 'LOGIN_QUERY_COMPANY_SCOPED'
Assert-Source ($login -notmatch 'WHERE UPPER\(Username\)\s*=\s*\?username') 'LOGIN_UNSCOPED_FALLBACK_ABSENT'
Assert-Source ($login -match 'AuthenticatedAziendaID') 'LOGIN_SESSION_COMPANY_MARKER'
Assert-Source ($master -match 'ShouldClearAuthentication') 'TENANT_CHANGE_AUTHENTICATION_FAIL_CLOSED'
Assert-Source ($master -match 'WHERE id=@loginId AND AziendeID=@companyId') 'LEGACY_SESSION_COMPANY_REVALIDATION'
Assert-Source ($registration -match '\?parAziendeID", assignment\.CompanyId') 'REGISTRATION_COMPANY_ASSIGNMENT'
Assert-Source ($registration -match '\?parListino", assignment\.InitialPriceListId') 'REGISTRATION_LISTINOUSER_ASSIGNMENT'
Assert-Source ($registration -match 'WHERE Codice=\?codice AND AziendeID=\?aziendaId') 'REGISTRATION_RESULT_COMPANY_SCOPED'
Assert-Source ($schema -match '(?is)CREATE[^\r\n]*PROCEDURE[^\r\n]*Newutenti.*?parAziendeI[dD].*?parListino') 'SCHEMA_REGISTRATION_CONTRACT'

foreach ($surface in @($homeSource, $catalog, $pdp)) {
    Assert-Source ($surface -match 'StorefrontCommercialIsolationPolicy\.ResolveSessionPriceList') 'VISIBLE_PRICE_LISTINO_FAIL_CLOSED'
}
Assert-Source ($homeSource -notmatch 'COALESCE\(v\.NListino,\s*1\)') 'HOME_PRICE_QUERY_HAS_NO_LISTINO_ONE_FALLBACK'
Assert-Source ($homeSource -match '(?s)FROM bannerv2.*?WHERE AziendeId=@companyId') 'HOME_WIDE_BANNERS_COMPANY_SCOPED'
Assert-Source ($homeSource -match 'WHERE s\.aziendeId=@companyId') 'HOME_SIDE_BANNERS_COMPANY_SCOPED'
Assert-Source ($homeSource -notmatch 'COALESCE\(AziendeId,\s*1\)\s*=\s*1') 'HOME_COMPANY_ONE_FALLBACK_ABSENT'
Assert-Source ($eligibility -match 'DatabaseScopeKey') 'PROMOTION_CACHE_DATABASE_SCOPE'
Assert-Source ($eligibility -match 'StorefrontSeoTenantContext\.ConfiguredDatabaseScopeKey') 'PROMOTION_CONTEXT_DATABASE_IDENTITY'
Assert-Source ($eligibility -match 'CompanyId') 'PROMOTION_CACHE_COMPANY_SCOPE'
Assert-Source ($eligibility -match 'Listino') 'PROMOTION_CACHE_LISTINO_SCOPE'
Assert-Source ($eligibility -match '(?s)BuildCommercialScope\(.*?IsAuthenticated,.*?CurrentUserId') 'PROMOTION_CACHE_AUTH_SCOPE'
Assert-Source ($eligibility -match 'CurrentUserId') 'PROMOTION_CACHE_OWNER_SCOPE'
Assert-Source ($eligibility -match 'snapshot\.Status\s*<>\s*ProductPromotionEligibilityLoadStatus\.TechnicalError') 'PROMOTION_TECHNICAL_ERROR_NOT_CACHED'
Assert-Source ($display -match 'ProductPromotionEligibilityResolver') 'PROMOTION_AUTHORITATIVE_RESOLVER_REUSED'
Assert-Source ($pdp -match '_pdpStructuredPrice\.CurrentPrice') 'JSONLD_USES_PDP_COMMERCIAL_PRICE'
Assert-Source ($catalog -match 'data-ks-price') 'CATALOG_DATA_PRICE_PRESENT'

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" $policyPath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'PRICING_ISOLATION_HARNESS_COMPILE_FAILED' }
    & $executable
    if ($LASTEXITCODE -ne 0) { throw 'PRICING_ISOLATION_HARNESS_FAILED' }
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

Write-Output 'PASS STOREFRONT_PRICING_ACCOUNT_ISOLATION'
