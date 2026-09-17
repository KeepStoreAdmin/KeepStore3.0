[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$policyPath = Join-Path $repoRoot 'App_Code\StorefrontCanonicalHostPolicy.vb'
$harnessPath = Join-Path $PSScriptRoot 'StorefrontSeoPolicyHarness.vb'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'

if (-not (Test-Path -LiteralPath $compiler)) { throw 'VB_COMPILER_NOT_FOUND' }
if (-not (Test-Path -LiteralPath $policyPath)) { throw 'SEO_POLICY_SOURCE_NOT_FOUND' }

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('KeepStoreSeoPolicy-' + [Guid]::NewGuid().ToString('N'))
$exePath = Join-Path $tempRoot 'StorefrontSeoPolicyHarness.exe'
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    & $compiler /nologo /target:exe "/out:$exePath" $policyPath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'SEO_POLICY_COMPILE_FAILED' }

    & $exePath
    if ($LASTEXITCODE -ne 0) { throw 'SEO_POLICY_HARNESS_FAILED' }

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
