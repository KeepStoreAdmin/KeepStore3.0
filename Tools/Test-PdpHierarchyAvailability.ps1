[CmdletBinding()]
param()

# KS-A03-PDP-HIERARCHY-1A - scheda articolo piu pulita e regola delle scorte (numeri solo a chi e loggato).
# 1) controllo statico del markup, del code-behind e del CSS, con mutazioni;
# 2) harness compilato con AvailabilityDisplayHelper REALE e sessioni finte (12 casi), con due mutazioni sull'helper.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStorePdp-' + [Guid]::NewGuid().ToString('N'))

function Read-Repo([string]$relativePath) { return [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)) }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Assert-Detects([string]$code, [bool]$checkResultOnMutation) {
    if ($checkResultOnMutation) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}

# Funzioni di controllo (usate sul sorgente reale e su quello mutato)
function Test-PdpMarkupClean([string]$aspx) {
    return -not ($aspx -match 'product-fearture-list|phProductInfoPrice|litCodice3|phEan3|litMarcaFeature|litCategory2|phCategoryFeature|phBrandFeature|Prezzi e disponibilita sono calcolati')
}
function Test-PdpCodeBehindClean([string]$vb) {
    return -not ($vb -match '\blitCodice3\b|\blitEan3\b|\blitMarcaFeature\b|\blitCategory2\b|\bphCategoryFeature\b|\bphBrandFeature\b|\bphEan3\b|\blitPriceHtml\b|\bphAvailability\b|\blitAvailability\b')
}
function Test-RelatedExcludesSimilar([string]$vb) {
    return ($vb -match 'shownAsSimilar' -and $vb -match 'relatedItems\.RemoveAll' -and $vb -notmatch 'AddUniqueRelatedItems\(relatedItems, similarItems')
}
function Test-HelperGateUsesAuthContract([string]$helper) {
    $mode = [regex]::Match($helper, '(?s)Public Function GetDisplayMode\(.*?End Function').Value
    $auth = [regex]::Match($helper, '(?s)Public Function IsAuthenticatedVisitor\(.*?End Function').Value
    return ($mode -match 'IsAuthenticatedVisitor' -and $auth -match 'CartStorefrontScopePolicy\.IsAuthenticatedScopeValid')
}
function Test-CssMobileOrder([string]$css) {
    $found = $false
    foreach ($m in [regex]::Matches($css, '(?s)@media \(max-width: 1199\.98px\) \{.*?\r?\n\}\r?\n')) {
        $v = $m.Value
        if ($v -match 'tf-product-info-content \{\s*display: contents;' -and $v -match 'infor-heading \{\s*order: 1;' -and
            $v -match 'tf-product-info-choose-option \{\s*order: 2;' -and $v -match 'infor-bottom \{\s*order: 4;') { $found = $true }
    }
    return ($found -and -not ($css -match 'product-fearture-list|product-info-price'))
}
foreach ($required in @($compiler)) { if (-not (Test-Path -LiteralPath $required)) { throw ('REQUIRED_FILE_MISSING=' + $required) } }

# ---- 1) controllo statico ----------------------------------------------------
$aspx = Read-Repo 'articolo.aspx'
$vb = Read-Repo 'articolo.aspx.vb'
$helper = Read-Repo 'App_Code\AvailabilityDisplayHelper.vb'
$css = Read-Repo 'Public\assets\keepstore\css\product-ui.css'

Assert-Source (Test-PdpMarkupClean $aspx) 'S01_PDP_MARKUP_HAS_NO_DUPLICATED_FEATURE_LIST_OR_STATIC_PURCHASE_TEXT'
Assert-Source (Test-PdpCodeBehindClean $vb) 'S02_PDP_CODE_BEHIND_HAS_NO_REFERENCES_TO_REMOVED_CONTROLS'
Assert-Source (Test-RelatedExcludesSimilar $vb) 'S03_RELATED_PRODUCTS_DO_NOT_REPEAT_SIMILAR_PRODUCTS'
Assert-Source (Test-HelperGateUsesAuthContract $helper) 'S04_AVAILABILITY_NUMBERS_GATED_BY_STOREFRONT_AUTH_CONTRACT'
Assert-Source (Test-CssMobileOrder $css) 'S05_CSS_MOBILE_ORDER_AND_NO_DEAD_RULES'
Assert-Source ($aspx -match 'product-ui\.css"\) %>\?v=20261114-(pdp-(hierarchy|buybar)1a|deadcode-c1a)') 'S06_CSS_CACHE_BUSTER_UPDATED'
$explicitCallers = @(& git -C $repoRoot grep -l -E 'BuildFromDataItemExplicit|BuildFromValuesExplicit' -- '*.vb' '*.aspx' '*.ascx' '*.master' ':!Tools' ':!docs' ':!App_Code/AvailabilityDisplayHelper.vb' 2>$null)
Assert-Source ($explicitCallers.Count -eq 0) 'S07_NO_PRODUCTION_CALLER_OF_EXPLICIT_MODE_THAT_BYPASSES_THE_VISITOR_RULE'

Assert-Detects 'M1_FEATURE_LIST_REAPPEARS' (Test-PdpMarkupClean ($aspx + '<ul class="product-fearture-list"></ul>'))
Assert-Detects 'M2_SIMILAR_FILLS_RELATED_AGAIN' (Test-RelatedExcludesSimilar ($vb + "`n AddUniqueRelatedItems(relatedItems, similarItems, 10)"))
Assert-Detects 'M3_GATE_REMOVED_FROM_GETDISPLAYMODE' (Test-HelperGateUsesAuthContract (Mutate-Text $helper 'If mode = 2 AndAlso Not IsAuthenticatedVisitor(ctx) Then mode = DefaultDisplayMode' '' 'M3'))
Assert-Detects 'M4_MOBILE_ORDER_REMOVED' (Test-CssMobileOrder (Mutate-Text $css 'display: contents;' 'display: block;' 'M4'))

# ---- 2) harness comportamentale con l'helper reale --------------------------
function Invoke-Harness([string]$helperPath, [string]$name) {
    $exe = Join-Path $tempRoot ($name + '.exe')
    $sources = @($helperPath) + @('App_Code\UiData.vb', 'App_Code\OrderInventoryAvailabilityService.vb', 'App_Code\StorefrontCommercialIsolationPolicy.vb',
        'App_Code\CartStorefrontScopePolicy.vb', 'App_Code\ThemeManager.vb', 'Tools\AvailabilityVisitorHarness.vb' | ForEach-Object { if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $repoRoot $_ } })
    & $compiler /nologo /optionstrict- /target:exe "/out:$exe" /reference:System.dll /reference:System.Web.dll /reference:System.Data.dll /reference:System.Configuration.dll ('/reference:' + (Join-Path $tempRoot 'MySql.Data.dll')) $sources | Out-Null
    if ($LASTEXITCODE -ne 0) { throw ('HARNESS_COMPILE_FAILED=' + $name) }
    $lines = @(& $exe)
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $lines }
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $repoRoot 'Bin\MySql.Data.dll') -Destination $tempRoot
    $real = Invoke-Harness (Join-Path $repoRoot 'App_Code\AvailabilityDisplayHelper.vb') 'real'
    $real.Output | ForEach-Object { Write-Output $_ }
    if ($real.ExitCode -ne 0) { throw 'HARNESS_FAILED_ON_REAL_HELPER' }

    # Mutazione comportamentale 1: nessun controllo di autenticazione (tutti vedono i numeri).
    $m1 = Join-Path $tempRoot 'mut1.vb'
    [IO.File]::WriteAllText($m1, (Mutate-Text $helper 'If mode = 2 AndAlso Not IsAuthenticatedVisitor(ctx) Then mode = DefaultDisplayMode' '' 'B1'))
    if ((Invoke-Harness $m1 'mut1').ExitCode -eq 0) { throw 'MUTATION_NOT_DETECTED=B1_BEHAVIOR_NO_GATE' }
    Write-Output 'PASS MUTATION_DETECTED B1_BEHAVIOR_NO_GATE'

    # Mutazione comportamentale 2: contratto debole (basta un LoginId positivo, qualunque azienda).
    $m2 = Join-Path $tempRoot 'mut2.vb'
    [IO.File]::WriteAllText($m2, (Mutate-Text $helper 'Return CartStorefrontScopePolicy.IsAuthenticatedScopeValid(companyId, authenticatedCompanyId, loginId)' 'Return loginId > 0' 'B2'))
    if ((Invoke-Harness $m2 'mut2').ExitCode -eq 0) { throw 'MUTATION_NOT_DETECTED=B2_BEHAVIOR_WEAK_CONTRACT' }
    Write-Output 'PASS MUTATION_DETECTED B2_BEHAVIOR_WEAK_CONTRACT'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = (Resolve-Path -LiteralPath $tempRoot).Path
        $allowedRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $resolvedTemp.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'UNSAFE_TEMP_CLEANUP_PATH' }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'PASS KS_A03_PDP_HIERARCHY_AVAILABILITY'
