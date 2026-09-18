[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$builderPath = Join-Path $repoRoot 'App_Code\ProductStructuredDataBuilder.vb'
$harnessPath = Join-Path $PSScriptRoot 'GoogleProductStructuredDataHarness.vb'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$frameworkRoot = Split-Path -Parent $compiler
$systemWeb = Join-Path $frameworkRoot 'System.Web.dll'
$systemWebExtensions = Join-Path $frameworkRoot 'System.Web.Extensions.dll'

foreach ($required in @($compiler, $systemWeb, $systemWebExtensions, $builderPath, $harnessPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw ('STRUCTURED_DATA_REQUIRED_FILE_MISSING=' + $required) }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('KeepStoreProductStructuredData-' + [Guid]::NewGuid().ToString('N'))
$exePath = Join-Path $tempRoot 'GoogleProductStructuredDataHarness.exe'
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    & $compiler /nologo /target:exe "/out:$exePath" "/reference:$systemWeb" "/reference:$systemWebExtensions" $builderPath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'PRODUCT_STRUCTURED_DATA_COMPILE_FAILED' }

    & $exePath
    if ($LASTEXITCODE -ne 0) { throw 'PRODUCT_STRUCTURED_DATA_HARNESS_FAILED' }

    $builderSource = Get-Content -LiteralPath $builderPath -Raw
    $pdpSource = Get-Content -LiteralPath (Join-Path $repoRoot 'articolo.aspx.vb') -Raw
    $nonPdpSources = @(
        'Default.aspx.vb',
        'articoli.aspx.vb',
        'Public\ui\controls\ProductCard.ascx.vb',
        'Public\ui\controls\ProductCard.ascx'
    ) | ForEach-Object {
        $path = Join-Path $repoRoot $_
        if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw }
    }

    if ($builderSource -match '(?i)\b(MySql|SELECT\s|INSERT\s|UPDATE\s|DELETE\s|ConfigurationManager|ProductPromotionEligibilityResolver)\b') {
        throw 'PRODUCT_STRUCTURED_DATA_BUILDER_HAS_DATA_ACCESS'
    }
    if ($builderSource -match '(?i)\b(TAIKUN|ONSUS|webaffare|italcomed|ks_marea|panificiosa|miranda|newnda|tecind)\b') {
        throw 'PRODUCT_STRUCTURED_DATA_CLIENT_REFERENCE_FOUND'
    }
    if ($builderSource -match '(?i)\b(ProductGroup|AggregateOffer|aggregateRating|reviewCount)\b') {
        throw 'PRODUCT_STRUCTURED_DATA_UNSUPPORTED_ENTITY_FOUND'
    }
    if ($pdpSource -notmatch 'ProductStructuredDataBuilder\.BuildJson') {
        throw 'PRODUCT_STRUCTURED_DATA_PDP_INTEGRATION_MISSING'
    }
    if (($nonPdpSources -join "`n") -match 'ProductStructuredDataBuilder\.BuildJson') {
        throw 'PRODUCT_STRUCTURED_DATA_OUTSIDE_PDP'
    }

    $buildFunction = [regex]::Match($pdpSource, '(?s)Private Function BuildProductJsonLd\(.*?End Function').Value
    if ($buildFunction -match '(?i)\b(MySql|SELECT\s|BuildAuthorizedPriceContext\(|GetAuthorizedPromotionModel\()') {
        throw 'PRODUCT_STRUCTURED_DATA_DUPLICATES_COMMERCIAL_RESOLUTION'
    }
    if ($buildFunction -match '(?i)_id\.ToString\([^\)]*\).*sku') {
        throw 'PRODUCT_STRUCTURED_DATA_TECHNICAL_ID_AS_SKU'
    }

    Write-Output 'PRODUCT_STRUCTURED_DATA_STATIC_GATES=PASS'
    Write-Output 'PRODUCT_STRUCTURED_DATA_DB_QUERY_DELTA=0'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
