[CmdletBinding()]
param()

# KS-A03-CATALOG-NAV-1A - filtri del catalogo a caselle, colonna senza scorrimento interno, stato accessibile.
# Controllo statico di markup, code-behind, CSS e JS con mutazioni (ogni regola, rotta apposta, deve far fallire il controllo).
# La prova nel browser (desktop 1440, mobile 390, Applica/Annulla/Reset, 1199/1200 px) e descritta nel Masterplan.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
function Read-Repo([string]$relativePath) { return [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)) }
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

# ---- controlli (usati sul sorgente reale e su quello mutato) ------------------
function Test-NoScrollCage([string]$css) {
    # La colonna dei filtri non e piu alta come lo schermo ne sticky, ne con scorrimento interno.
    if ($css -match '(?s)canvas-filter-product\.sidebar-filter\s*\{[^}]*(position:\s*sticky|height:\s*calc\(100vh|overflow:\s*hidden)') { return $false }
    if ($css -match '(?s)canvas-filter-product\.sidebar-filter\s+\.canvas-body\s*\{[^}]*overflow-y:\s*auto') { return $false }
    return ($css -match '(?s)@media \(min-width: 1200px\) \{\s*#ksCatalogPage \.canvas-filter-product\.sidebar-filter \{\s*align-self: flex-start;')
}
function Test-AriaCurrentOnFilters([string]$aspx) {
    foreach ($k in 'mr', 'tp', 'gr', 'sg') {
        $sel = 'CatalogFilterSelected\("' + $k + '", Container\.DataItem\), " active", ""\) %>''<%# If\(ThemeManager\.CatalogFilterSelected\("' + $k + '", Container\.DataItem\), " aria-current=""true""", ""\) %> href='
        if ($aspx -notmatch $sel) { return $false }
    }
    return $true
}
function Test-NoPy3OnToggles([string]$aspx, [string]$vb) {
    if ($aspx -match 'ID="lnkCatalog(Deals|Refurbished)"[^>]*py-3') { return $false }
    if ($vb -match '"ks-filter-option link py-3"') { return $false }
    return ($aspx -match 'ID="lnkCatalogDeals" runat="server" class="ks-filter-option link"' -and $vb -match '"ks-filter-option link" & If\(dealsActive')
}
function Test-CheckboxRows([string]$css) {
    $box = ($css -match '(?s)\.ks-filter-option::before \{[^}]*width: 18px;[^}]*height: 18px;' -and
            $css -match '(?s)\.ks-filter-option\.active::before \{[^}]*background: var\(--primary[^}]*url\("data:image/svg\+xml' -and
            $css -match '(?s)\.ks-filter-option:focus-visible \{[^}]*outline: 2px solid' -and
            $css -match '(?s)@media \(forced-colors: active\) \{[^@]*Highlight')
    # il min-height compatto vale solo da desktop: fuori dal blocco @media (min-width: 1200px) non deve comparire
    $outside = [regex]::Replace($css, '(?s)@media \(min-width: 1200px\) \{.*?\r?\n\}\r?\n', '')
    $global = ($outside -match '(?s)#ksCatalogPage \.widget-facet \.ks-filter-option \{[^}]*min-height' -or
               $outside -match '(?s)#ksCatalogPage \.ks-filter-checkbox > span \{[^}]*min-height')
    $inside = ($css -match '(?s)@media \(min-width: 1200px\) \{\s*#ksCatalogPage \.widget-facet \.ks-filter-option \{\s*min-height: 32px;')
    $lists = ($css -match '#ksCatalogPage \.widget-facet \.ks-filter-list > span \{\s*display: contents;' -and
              $css -match '#ksCatalogPage \.widget-facet \.ks-filter-list > br \{\s*display: none;')
    return ($box -and (-not $global) -and $inside -and $lists)
}
function Test-BatchKeepsAriaState([string]$js) {
    return ($js -match "node\.setAttribute\('aria-checked', String\(selected\)\); node\.removeAttribute\('aria-current'\);" -and
            $js -match "current: node\.getAttribute\('aria-current'\)" -and
            $js -match "\['aria-current', item\.current\]")
}
function Test-CacheBusters([string]$aspx, [string]$master) {
    return ($aspx -match 'css/catalog-ui\.css"\) %>\?v=(?:20261114-(?:(?:catalog-nav|dept-nav|cards)1a|deadcode-c1a)|20261115-(?:grey|palette)-aa1a)' -and
            $aspx -match 'js/catalog-ui\.js"\) %>\?v=20261114-catalog-nav1a' -and
            $master -match 'theme-overrides\.css"\) & "\?v=(?:20261114-(catalog-nav1a|dept-nav1a|search-panel1a|home-vetrina[12]a|deadcode-c1a)|20261115-(?:home-cards|palette-aa)1a)"')
}
function Test-AvailabilitySeparator([string]$aspx, [string]$css) {
    return ($aspx -match 'widget-facet facet-fieldset ks-facet-availability' -and
            $css -match '(?s)\.widget-facet\.ks-facet-availability \{[^}]*border-bottom: 1px solid')
}

# ---- 1) sorgente reale --------------------------------------------------------
$aspx = Read-Repo 'articoli.aspx'
$vb = Read-Repo 'articoli.aspx.vb'
$theme = Read-Repo 'Public\assets\keepstore\css\theme-overrides.css'
$cat = Read-Repo 'Public\assets\keepstore\css\catalog-ui.css'
$js = Read-Repo 'Public\assets\keepstore\js\catalog-ui.js'
$master = Read-Repo 'Page.master'

Assert-Source (Test-NoScrollCage $theme) 'S01_FILTER_COLUMN_HAS_NO_STICKY_OR_INNER_SCROLL_CAGE'
Assert-Source (Test-AriaCurrentOnFilters $aspx) 'S02_SELECTED_FILTER_LINKS_EXPOSE_ARIA_CURRENT'
Assert-Source (Test-NoPy3OnToggles $aspx $vb) 'S03_OFFERS_AND_CONDITION_LINKS_HAVE_NO_PY3_OVERRIDE'
Assert-Source (Test-CheckboxRows $cat) 'S04_CHECKBOX_ROWS_FOCUS_FORCED_COLORS_AND_DESKTOP_ONLY_COMPACT_HEIGHT'
Assert-Source (Test-BatchKeepsAriaState $js) 'S05_MOBILE_BATCH_SUSPENDS_AND_RESTORES_ARIA_CURRENT'
Assert-Source (Test-CacheBusters $aspx $master) 'S06_CACHE_BUSTERS_UPDATED'
Assert-Source (Test-AvailabilitySeparator $aspx $cat) 'S07_AVAILABILITY_SECTION_HAS_SEPARATOR'
Assert-Source ($aspx -match '>Disponibilit[^a<]' -and $aspx -notmatch '>Disponibilita<') 'S08_AVAILABILITY_LABEL_HAS_ACCENT'

# ---- 2) mutazioni -------------------------------------------------------------
$m = Mutate-Text $theme '    align-self: flex-start;' "    align-self: flex-start;`r`n    position: sticky;" 'M01'
Assert-Detected (Test-NoScrollCage $m) 'M01_STICKY_REINTRODUCED'
$m = Mutate-Text $theme '@media (min-width: 1200px) {' '@media (min-width: 1201px) {' 'M02'
Assert-Detected (Test-NoScrollCage $m) 'M02_COLUMN_RULE_NOT_LIMITED_TO_1200'
$m = Mutate-Text $aspx 'CatalogFilterSelected("sg", Container.DataItem), " aria-current=""true""", "")' 'CatalogFilterSelected("sg", Container.DataItem), "", "")' 'M03'
Assert-Detected (Test-AriaCurrentOnFilters $m) 'M03_ARIA_CURRENT_REMOVED_FROM_ONE_FILTER'
$m = Mutate-Text $aspx 'ID="lnkCatalogDeals" runat="server" class="ks-filter-option link"' 'ID="lnkCatalogDeals" runat="server" class="ks-filter-option link py-3"' 'M04'
Assert-Detected (Test-NoPy3OnToggles $m $vb) 'M04_PY3_RESTORED_IN_MARKUP'
$m = Mutate-Text $vb '"ks-filter-option link" & If(dealsActive' '"ks-filter-option link py-3" & If(dealsActive' 'M05'
Assert-Detected (Test-NoPy3OnToggles $aspx $m) 'M05_PY3_RESTORED_IN_CODE_BEHIND'
$m = Mutate-Text $cat "@media (min-width: 1200px) {`r`n  #ksCatalogPage .widget-facet .ks-filter-option {`r`n    min-height: 32px;`r`n    padding: 4px 0;`r`n  }`r`n}`r`n" "#ksCatalogPage .widget-facet .ks-filter-option {`r`n  min-height: 32px;`r`n}`r`n" 'M06'
Assert-Detected (Test-CheckboxRows $m) 'M06_COMPACT_ROW_HEIGHT_APPLIED_ON_MOBILE_TOO'
$m = Mutate-Text $cat '@media (forced-colors: active) {' '@media (hover: none) {' 'M07'
Assert-Detected (Test-CheckboxRows $m) 'M07_FORCED_COLORS_BLOCK_REMOVED'
$m = Mutate-Text $cat '#ksCatalogPage .widget-facet .ks-filter-list > br {' '#ksCatalogPage .ks-brand-facet .ks-filter-list > br {' 'M08'
Assert-Detected (Test-CheckboxRows $m) 'M08_LIST_NORMALISATION_LIMITED_TO_BRANDS_AGAIN'
$m = Mutate-Text $js " node.removeAttribute('aria-current');" '' 'M09'
Assert-Detected (Test-BatchKeepsAriaState $m) 'M09_BATCH_LEAVES_STALE_ARIA_CURRENT'
$m = Mutate-Text $js "['aria-current', item.current], " '' 'M10'
Assert-Detected (Test-BatchKeepsAriaState $m) 'M10_CANCEL_DOES_NOT_RESTORE_ARIA_CURRENT'
$m = Mutate-Text $aspx 'js/catalog-ui.js") %>?v=20261114-catalog-nav1a' 'js/catalog-ui.js") %>?v=20261111-catalog-departments1a' 'M11'
Assert-Detected (Test-CacheBusters $m $master) 'M11_JS_CACHE_BUSTER_NOT_UPDATED'
$m = Mutate-Text $aspx 'widget-facet facet-fieldset ks-facet-availability' 'widget-facet facet-fieldset' 'M12'
Assert-Detected (Test-AvailabilitySeparator $m $cat) 'M12_AVAILABILITY_SEPARATOR_CLASS_REMOVED'

Write-Output 'CATALOG_NAVIGATION_FILTERS_OK'
