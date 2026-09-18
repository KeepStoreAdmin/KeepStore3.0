[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$policyPath = Join-Path $repoRoot 'App_Code\StorefrontCanonicalHostPolicy.vb'
$assetResolverPath = Join-Path $repoRoot 'App_Code\TenantRuntimeAssetResolver.vb'
$harnessPath = Join-Path $PSScriptRoot 'StorefrontSeoPolicyHarness.vb'
$sameDatabaseHarnessPath = Join-Path $PSScriptRoot 'StorefrontSameDatabaseTenantHarness.vb'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'

if (-not (Test-Path -LiteralPath $compiler)) { throw 'VB_COMPILER_NOT_FOUND' }
if (-not (Test-Path -LiteralPath $policyPath)) { throw 'SEO_POLICY_SOURCE_NOT_FOUND' }
if (-not (Test-Path -LiteralPath $assetResolverPath)) { throw 'TENANT_ASSET_RESOLVER_SOURCE_NOT_FOUND' }
if (-not (Test-Path -LiteralPath $sameDatabaseHarnessPath)) { throw 'SAME_DATABASE_TENANT_HARNESS_NOT_FOUND' }

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('KeepStoreSeoPolicy-' + [Guid]::NewGuid().ToString('N'))
$exePath = Join-Path $tempRoot 'StorefrontSeoPolicyHarness.exe'
$sameDatabaseExePath = Join-Path $tempRoot 'StorefrontSameDatabaseTenantHarness.exe'
$sameDatabaseFixtureRoot = Join-Path $tempRoot 'same-database-fixture'
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    & $compiler /nologo /target:exe "/out:$exePath" $policyPath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'SEO_POLICY_COMPILE_FAILED' }

    & $exePath
    if ($LASTEXITCODE -ne 0) { throw 'SEO_POLICY_HARNESS_FAILED' }

    & $compiler /nologo /target:exe "/out:$sameDatabaseExePath" $policyPath $assetResolverPath $sameDatabaseHarnessPath
    if ($LASTEXITCODE -ne 0) { throw 'SAME_DATABASE_TENANT_COMPILE_FAILED' }

    & $sameDatabaseExePath $sameDatabaseFixtureRoot
    if ($LASTEXITCODE -ne 0) { throw 'SAME_DATABASE_TENANT_HARNESS_FAILED' }

    $seoFiles = @(
        'App_Code\StorefrontCanonicalHostPolicy.vb',
        'App_Code\StorefrontSeoTenantContext.vb',
        'App_Code\StorefrontSeoEndpointHandler.vb',
        'App_Code\SeoBuilder.vb',
        'Default.aspx.vb',
        'Global.asax',
        'Page.master.vb',
        'articoli.aspx.vb',
        'articolo.aspx.vb',
        'carrello.aspx.vb',
        'Contattaci.aspx.vb',
        'robots.aspx.vb',
        'sitemap.aspx.vb',
        'Public\ui\controls\SiteHeader.ascx.vb',
        'Public\ui\controls\SiteFooter.ascx',
        'Public\ui\controls\SiteFooter.ascx.vb'
    )

    $sharedSource = ($seoFiles | ForEach-Object {
        Get-Content -LiteralPath (Join-Path $repoRoot $_) -Raw
    }) -join "`n"

    $forbiddenClientReferences = '(?i)\b(taikun|webaffare|onsus|italcomed|ks_marea|panificiosa|miranda|newnda|tecind)\b'
    if ($sharedSource -match $forbiddenClientReferences) { throw 'SEO_SHARED_CLIENT_REFERENCE_FOUND' }
    if ($sharedSource -match '(?i)(Headers|ServerVariables)\s*\(\s*["'']X-Forwarded-Host["'']') { throw 'SEO_UNTRUSTED_FORWARDED_HOST_FOUND' }
    if ($sharedSource -match '(?i)\b(SeoAbilitato|SEO_VISIBILITY_PRO|SEO_ENTITLEMENT|SEO_LICENSE)\b') { throw 'SEO_COMMERCIAL_GATE_FOUND' }

    $seoCoreSource = @(
        'App_Code\StorefrontSeoTenantContext.vb',
        'robots.aspx.vb',
        'sitemap.aspx.vb'
    ) | ForEach-Object { Get-Content -LiteralPath (Join-Path $repoRoot $_) -Raw }
    if (($seoCoreSource -join "`n") -match '(?i)\b(INSERT\s+(INTO|IGNORE)|UPDATE\s+[A-Za-z`]|DELETE\s+FROM|CREATE\s+TABLE|ALTER\s+TABLE|DROP\s+TABLE)\b') { throw 'SEO_MUTATING_SQL_FOUND' }

    $tenantContextSource = Get-Content -LiteralPath (Join-Path $repoRoot 'App_Code\StorefrontSeoTenantContext.vb') -Raw
    $masterSource = Get-Content -LiteralPath (Join-Path $repoRoot 'Page.master.vb') -Raw
    $masterMarkup = Get-Content -LiteralPath (Join-Path $repoRoot 'Page.master') -Raw
    $keepStoreCssSource = Get-Content -LiteralPath (Join-Path $repoRoot 'Public\assets\keepstore\css\keepstore.css') -Raw
    if ($tenantContextSource -notmatch 'StorefrontCanonicalHostPolicy\.SelectExactTenant\(') { throw 'TENANT_EXACT_HOST_SELECTION_MISSING' }
    if ($tenantContextSource -match '(?is)For Each candidate.*?Exit For') { throw 'TENANT_FIRST_MATCH_SELECTION_FOUND' }
    if ($tenantContextSource -notmatch 'BuildTenantListCacheKey\(') { throw 'TENANT_DATABASE_SCOPED_LIST_CACHE_MISSING' }
    if ($masterSource -notmatch 'sessionCompanyId\s*<>\s*resolvedTenant\.CompanyId') { throw 'TENANT_SESSION_REALIGNMENT_MISSING' }
    if ($masterSource -notmatch 'WHERE Id=@companyId') { throw 'TENANT_SELECTED_ROW_LOAD_MISSING' }
    if ($masterSource -notmatch 'Me\.Session\("Listino"\)\s*=\s*dr\.Item\("ListinoDefault"\)') { throw 'TENANT_DEFAULT_PRICE_LIST_SELECTED_ROW_BINDING_MISSING' }
    if ($masterSource -notmatch 'Me\.Session\("ListinoUser"\)\s*=\s*dr\.Item\("ListinoUser"\)') { throw 'TENANT_INITIAL_USER_PRICE_LIST_SELECTED_ROW_BINDING_MISSING' }
    if ($masterSource -notmatch 'Me\.Session\("css"\)\s*=\s*dr\.Item\("css"\)') { throw 'TENANT_CSS_SELECTED_ROW_BINDING_MISSING' }
    if ($masterSource -match 'PageBody\.Style\("background-image"\)' -or
        $masterSource -match 'Default"\s*&\s*Session\("AziendaID"\)\s*&\s*"\.png"' -or
        $masterSource -match '(?is)SELECT\s+\*\s+FROM\s+sfondi') { throw 'LEGACY_PAGE_BACKGROUND_EMISSION_FOUND' }
    $globalBodyRules = [regex]::Matches($keepStoreCssSource, '(?is)(?:^|})\s*body\s*\{([^}]*)\}')
    foreach ($bodyRule in $globalBodyRules) {
        if ($bodyRule.Groups[1].Value -match '(?i)background(?:-image|-color)?\s*:|DXImageTransform\.Microsoft\.gradient') {
            throw 'GLOBAL_LEGACY_BODY_BACKGROUND_FOUND'
        }
    }
    if ($masterMarkup -notmatch 'css/keepstore\.css"\)\s*&\s*"\?v=20260918-runtime-asset-404-rev3"') { throw 'KEEPSTORE_CSS_CACHE_BUSTER_STALE' }

    if (Test-Path -LiteralPath (Join-Path $repoRoot 'robots.txt')) { throw 'STATIC_ROBOTS_CONFLICT_FOUND' }
    if (Test-Path -LiteralPath (Join-Path $repoRoot 'sitemap.xml')) { throw 'STATIC_SITEMAP_CONFLICT_FOUND' }

    Write-Output 'SEO_STATIC_GATES=PASS'
    Write-Output ('SEO_SHARED_FILES=' + $seoFiles.Count)
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
