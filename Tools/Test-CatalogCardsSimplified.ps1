[CmdletBinding()]
param()

# KS-A03-CARDS-1A - card prodotto del catalogo piu pulite: disponibilita e codice senza riquadri, una sola casella
# "Seleziona", riga di acquisto senza riquadro, prezzo in evidenza. Solo CSS, solo la griglia predefinita (layout-tabgrid-1).
# Controllo statico con mutazioni (ogni regola, rotta apposta, deve far fallire il controllo).
# La prova nel browser (tastiera, colori forzati, area di tocco, stato "gia nel carrello", promo, 390/320 px, altre viste)
# e descritta nel Masterplan.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
function Read-Repo([string]$relativePath) { return ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)) -replace "`r`n", "`n") }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}

$scope = '#ksCatalogPage #gridLayout.layout-tabgrid-1 article.card-product'

function Get-CardBlock([string]$css) {
    # Il blocco finisce al marker del task successivo (KS-A04-...) o a fine file: le regole di altri task accodati dopo non sono "card della griglia".
    $m = [regex]::Match($css, '(?s)/\* ===== Card prodotto: meno riquadri.*?(?=\r?\n/\* KS-A04-|\z)')
    if ($m.Success) { return $m.Value } else { return '' }
}

# ---- controlli (usati sul sorgente reale e su quello mutato) ------------------
function Test-ScopedToDefaultGrid([string]$css) {
    $b = Get-CardBlock $css
    if ($b -eq '') { return $false }
    # ogni selettore (riga che precede "{" o ",") deve iniziare dal prefisso della griglia predefinita
    $bad = 0
    foreach ($m in [regex]::Matches($b, '(?m)^\s*(#[^\n{]+?)\s*[,{]\s*$')) {
        if (-not $m.Groups[1].Value.StartsWith($scope)) { $bad++ }
    }
    if ($b -match 'layout-tabgrid-2|layout-tablist|\.ks-recently|body\.ks-page-home') { $bad++ }
    return ($bad -eq 0 -and $b -match [regex]::Escape($scope))
}
function Test-Price([string]$css) {
    $b = Get-CardBlock $css
    return ($b -match '(?s)article\.card-product \.price-wrap \.new-price \{\s*font-size: 22px;\s*font-weight: 700 !important;' -and
            $b -notmatch 'old-price')
}
function Test-MetaRow([string]$css) {
    $b = Get-CardBlock $css
    return ($b -match '(?s)\.list-computer-memory \{\s*align-items: center;\s*gap: 4px 10px;' -and
            $b -match '(?s)\.list-computer-memory li \{\s*padding: 0;\s*border: 0;\s*border-radius: 0;')
}
function Test-PurchaseRowAndCartState([string]$css) {
    $b = Get-CardBlock $css
    $reset = ($b -match '(?s)\.box-infor-detail > \.ks-card-purchase-actions \{\s*padding: 0;\s*border-color: transparent;\s*border-radius: 0;\s*background: none;\s*box-shadow: none;')
    $state = ($b -match '(?s)\.ks-card-purchase-actions\.ks-cart-qty-present,\s*' + [regex]::Escape($scope) + ' \.box-infor-detail > \.ks-card-purchase-actions:has\(\.ks-cart-qty-input-present\) \{\s*padding: 7px 8px;\s*border-color: rgba\(19, 140, 64, 0\.2\);[^}]*linear-gradient')
    return ($reset -and $state)
}
function Test-Checkbox([string]$css) {
    $b = Get-CardBlock $css
    return ($b -match '(?s)\.form-check-input::before,\s*' + [regex]::Escape($scope) + ' \.ks-card-purchase-actions > \.form-check-input::after \{\s*content: none;\s*display: none;' -and
            $b -match 'accent-color: var\(--primary-2' -and
            $b -match 'input\[type="checkbox"\]:focus-visible \{\s*outline: 2px solid' -and
            $b -match '(?s)\.form-check-input label \{\s*margin: 0;\s*padding-block: 7px;')
}
function Test-MobileHitArea([string]$css) {
    $b = Get-CardBlock $css
    return ($b -match '(?s)@media \(max-width: 1199\.98px\) \{.*input\[type="checkbox"\] \{\s*position: relative;\s*z-index: 1;.*\.form-check-input label \{\s*margin-left: -26px;\s*padding: 13px 0 13px 26px;')
}
function Test-CacheBuster([string]$aspx) {
    return ($aspx -match 'css/catalog-ui\.css"\) %>\?v=(?:20261114-(?:cards1a|deadcode-c1a)|20261115-(?:(?:grey|palette)-aa|focus-fc)1a|20261119-compact-1a)')
}

# ---- 1) sorgente reale --------------------------------------------------------
$cat = Read-Repo 'Public\assets\keepstore\css\catalog-ui.css'
$aspx = Read-Repo 'articoli.aspx'

Assert-Source (Test-ScopedToDefaultGrid $cat) 'S01_EVERY_RULE_SCOPED_TO_DEFAULT_GRID_ONLY'
Assert-Source (Test-Price $cat) 'S02_ONLY_CURRENT_PRICE_ENLARGED_WEIGHT_OVER_THEME_UTILITY'
Assert-Source (Test-MetaRow $cat) 'S03_AVAILABILITY_AND_CODE_WITHOUT_BOXES'
Assert-Source (Test-PurchaseRowAndCartState $cat) 'S04_PURCHASE_ROW_WITHOUT_BOX_AND_IN_CART_STATE_PRESERVED'
Assert-Source (Test-Checkbox $cat) 'S05_SINGLE_CHECKBOX_FOCUS_AND_LABEL'
Assert-Source (Test-MobileHitArea $cat) 'S06_MOBILE_LABEL_IS_THE_44PX_TOUCH_TARGET'
Assert-Source (Test-CacheBuster $aspx) 'S07_CACHE_BUSTER_UPDATED'

# ---- 2) mutazioni -------------------------------------------------------------
$m = Mutate-Text $cat ($scope + ' .list-computer-memory {') '#ksCatalogPage article.card-product .list-computer-memory {' 'M01'
Assert-Detected (Test-ScopedToDefaultGrid $m) 'M01_RULE_LEAKS_TO_ALL_LAYOUTS'
$m = Mutate-Text $cat ($scope + ' .list-computer-memory li {') ($scope + ' .list-computer-memory li,' + "`n" + '#ksCatalogPage #gridLayout.layout-tabgrid-2 article.card-product .list-computer-memory li {') 'M02'
Assert-Detected (Test-ScopedToDefaultGrid $m) 'M02_RULE_REACHES_COMPACT_VIEW'
$m = Mutate-Text $cat 'font-weight: 700 !important;' 'font-weight: 700;' 'M03'
Assert-Detected (Test-Price $m) 'M03_PRICE_WEIGHT_LOSES_TO_THEME_UTILITY'
$m = Mutate-Text $cat ($scope + ' .price-wrap .new-price {') ($scope + ' .price-wrap .new-price,' + "`n" + $scope + ' .price-wrap .old-price {') 'M04'
Assert-Detected (Test-Price $m) 'M04_STRUCK_PRICE_ENLARGED_TOO'
$m = Mutate-Text $cat "  padding: 0;`n  border: 0;`n  border-radius: 0;`n}" "  padding: 0;`n  border: 1px solid #ddd;`n  border-radius: 0;`n}" 'M05'
Assert-Detected (Test-MetaRow $m) 'M05_BOX_AROUND_AVAILABILITY_AND_CODE_BACK'
$m = Mutate-Text $cat ($scope + ' .box-infor-detail > .ks-card-purchase-actions:has(.ks-cart-qty-input-present) {') ($scope + ' .box-infor-detail > .ks-card-purchase-actions.ks-other {') 'M06'
Assert-Detected (Test-PurchaseRowAndCartState $m) 'M06_IN_CART_STATE_VIA_HAS_LOST'
$m = Mutate-Text $cat ($scope + ' .box-infor-detail > .ks-card-purchase-actions.ks-cart-qty-present,') ($scope + ' .box-infor-detail > .ks-card-purchase-actions.ks-other,') 'M07'
Assert-Detected (Test-PurchaseRowAndCartState $m) 'M07_IN_CART_STATE_VIA_CLASS_LOST'
$m = Mutate-Text $cat "  content: none;`n  display: none;" "  content: `"`";`n  display: none;" 'M08'
Assert-Detected (Test-Checkbox $m) 'M08_DECORATIVE_ICON_NOT_REMOVED'
$m = Mutate-Text $cat '  accent-color: var(--primary-2, #D80027);' '' 'M09'
Assert-Detected (Test-Checkbox $m) 'M09_CHECKBOX_LOSES_BRAND_COLOUR'
$m = Mutate-Text $cat 'input[type="checkbox"]:focus-visible {' 'input[type="checkbox"]:hover {' 'M10'
Assert-Detected (Test-Checkbox $m) 'M10_KEYBOARD_FOCUS_NOT_VISIBLE'
$m = Mutate-Text $cat '  margin-left: -26px;' '  margin-left: 0;' 'M11'
Assert-Detected (Test-MobileHitArea $m) 'M11_MOBILE_TOUCH_TARGET_NOT_44PX'
$m = Mutate-Text $aspx 'css/catalog-ui.css") %>?v=20261119-compact-1a' 'css/catalog-ui.css") %>?v=20261114-dept-nav1a' 'M12'
Assert-Detected (Test-CacheBuster $m) 'M12_CACHE_BUSTER_NOT_UPDATED'

Write-Output 'CATALOG_CARDS_SIMPLIFIED_OK'
