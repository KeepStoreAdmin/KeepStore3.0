[CmdletBinding()]
param()

# KS-A03-DEPARTMENTS-NAV-1A - barra dei reparti sempre visibile (desktop) e riquadri delle categorie nella pagina di un reparto.
# Controllo statico di markup, code-behind, CSS e JS con mutazioni (ogni regola, rotta apposta, deve far fallire il controllo).
# La prova nel browser (larghezze 1440/1280/1200/1199, focus durante il ridimensionamento, senza JavaScript, riquadri con
# ricerca/filtri/pagina, 390 e 320 px) e descritta nel Masterplan.
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

# ---- controlli (usati sul sorgente reale e su quello mutato) ------------------
function Test-HeaderLiteral([string]$ascx) {
    return ($ascx -match '(?s)</div>\s*<asp:Literal ID="litDepartmentsBar" runat="server" EnableViewState="false" />\s*</header>')
}
function Test-BarBuilder([string]$vb) {
    $bind = [regex]::Match($vb, '(?s)Private Sub BindDesktopCatalog\(.*?End Sub').Value
    $fn = [regex]::Match($vb, '(?s)Private Function BuildDepartmentsBarHtml\(.*?End Function').Value
    return ($bind -match 'litDepartmentsBar\.Text = BuildDepartmentsBarHtml\(sectors\)' -and
            $fn -match 'Return String\.Empty' -and
            $fn -match 'HttpUtility\.HtmlAttributeEncode\(sector\.DefaultUrl\)' -and
            $fn -match 'HttpUtility\.HtmlEncode\(sector\.Descrizione\)' -and
            $fn -match 'AppendDesktopCatalogPathAttributes\(items, onPath, onPath AndAlso Not scope\.HasCategory\)' -and
            $fn -match "id='ksDepartmentsBar' class='ks-departments-bar d-none d-xl-block'" -and
            $fn -match "aria-label='Reparti'" -and $fn -match 'Tutti i reparti')
}
function Test-BarCss([string]$css) {
    $m = [regex]::Match($css, '(?s)/\* ===== Barra dei reparti.*?\n\}\n@media \(forced-colors: active\) \{.*?\n\}(?:\n|$)')
    if (-not $m.Success) { return $false }
    $v = $m.Value
    return ($v -match '@media \(min-width: 1200px\) \{' -and
            $v -match '\.ks-dept-list \{[^}]*flex-wrap: wrap;[^}]*height: 44px;[^}]*overflow: hidden;' -and
            $v -match '\.ks-dept-link \{[^}]*text-overflow: ellipsis;' -and
            $v -match '\.ks-dept-link \{[^}]*height: 44px;' -and
            $v -match 'focus-visible \{ outline: 2px solid' -and
            $v -match 'ks-dept-link\[aria-current\]' -and
            $v -match 'Highlight')
}
function Test-BarScript([string]$js) {
    return ($js -match 'getBoundingClientRect\(\)' -and
            $js -match 'r\.bottom > box\.bottom \+ 1 \|\| r\.right > box\.right \+ 1' -and
            $js -match "setAttribute\('aria-hidden', 'true'\)" -and $js -match "setAttribute\('tabindex', '-1'\)" -and
            $js -match "removeAttribute\('aria-hidden'\)" -and $js -match "removeAttribute\('tabindex'\)" -and
            $js -match 'if \(lostFocus && all\) \{ all\.focus\(\); \}' -and
            $js -match "addEventListener\('resize', schedule\)" -and $js -match 'new window\.ResizeObserver\(schedule\)\.observe\(list\)')
}
function Test-MasterWiring([string]$master) {
    return ($master -match 'js/ks-departments-bar\.js"\) %>\?v=20261114-dept-nav1a' -and
            $master -match 'theme-overrides\.css"\) & "\?v=(?:20261114-(?:dept-nav1a|search-panel1a|home-vetrina[12]a|deadcode-c1a)|20261115-home-cards1a)"')
}
function Test-TilesMarkup([string]$aspx) {
    $i = $aspx.IndexOf('ID="pnlCatalogDepartmentTiles"')
    $j = $aspx.IndexOf('ID="pnlCatalogDepartmentsMobile"')
    return ($i -gt 0 -and $j -gt $i -and
            $aspx -match 'ID="litCatalogDepartmentTiles" runat="server" EnableViewState="false"' -and
            $aspx -match 'css/catalog-ui\.css"\) %>\?v=(?:20261114-(?:(?:dept-nav|cards)1a|deadcode-c1a)|20261115-grey-aa1a)')
}
function Test-TilesCodeBehind([string]$vb) {
    $nav = [regex]::Match($vb, '(?s)Private Sub BindCatalogCategoryNavigation\(\).*?End Sub').Value
    $tiles = [regex]::Match($vb, '(?s)Private Sub BindCatalogDepartmentTiles\(.*?End Sub').Value
    $ref = [regex]::Match($vb, '(?s)Private Function HasCatalogRefinement\(\).*?End Function').Value
    $resetFirst = ($nav.IndexOf('pnlCatalogDepartmentTiles.Visible = False') -gt 0 -and
                   $nav.IndexOf('pnlCatalogDepartmentTiles.Visible = False') -lt $nav.IndexOf('Exit Sub'))
    $called = ($nav -match 'BindCatalogDepartmentTiles\(sectors, taxonomy\)')
    $conds = ($tiles -match 'Not taxonomy\.HasSector OrElse taxonomy\.HasCategory' -and $tiles -match 'If HasCatalogRefinement\(\) Then Return' -and
              $tiles -match 'If tiles\.Count < 2 Then Return' -and
              $tiles -match 'BuildCatalogCategoryUrl\(sector\.Id, category\.Id\)' -and
              $tiles -match 'Server\.HtmlEncode\(label\)' -and $tiles -match 'aria-labelledby=""ksDeptTilesTitle""' -and $tiles -match 'id=""ksDeptTilesTitle""' -and
              $tiles -match 'Math\.Min\(CatalogDepartmentTilesVisible, tiles\.Count\)')
    $keys = ($ref -match '"q", "mr", "tp", "gr", "sg", "inpromo", "ricondizionato", "disponibile", "pmin", "pmax", "taglia", "colore"' -and
             $ref -match 'Request\.QueryString\("pg"\)' -and $ref -match 'pg > 1')
    $const = ($vb -match 'Private Const CatalogDepartmentTilesVisible As Integer = 12')
    return ($resetFirst -and $called -and $conds -and $keys -and $const)
}
function Test-TilesCss([string]$css) {
    $m = [regex]::Match($css, '(?s)/\* ===== Riquadri di reparto.*$')
    if (-not $m.Success) { return $false }
    $v = $m.Value
    return ($v -match 'repeat\(2, minmax\(0, 1fr\)\)' -and
            $v -match '@media \(min-width: 768px\) \{\s*#ksCatalogPage \.ks-dept-tile-grid \{ grid-template-columns: repeat\(3' -and
            $v -match '@media \(min-width: 1200px\) \{\s*#ksCatalogPage \.ks-dept-tile-grid \{ grid-template-columns: repeat\(4' -and
            $v -match '\.ks-dept-tile \{[^}]*min-height: 64px;' -and
            $v -match '\.ks-dept-tile-grid > li \{ display: flex; \}' -and
            $v -match '\.ks-dept-tile:focus-visible \{[^}]*outline: 2px solid' -and
            $v -match '\.ks-dept-more-summary \{[^}]*min-height: 44px;' -and
            $v -match 'ks-dept-more-closed' -and $v -match 'ks-dept-more-open' -and
            $v -match '@media \(forced-colors: active\)')
}

# ---- 1) sorgente reale --------------------------------------------------------
$ascx = Read-Repo 'Public\ui\controls\SiteHeader.ascx'
$headerVb = Read-Repo 'Public\ui\controls\SiteHeader.ascx.vb'
$theme = Read-Repo 'Public\assets\keepstore\css\theme-overrides.css'
$js = Read-Repo 'Public\assets\keepstore\js\ks-departments-bar.js'
$master = Read-Repo 'Page.master'
$aspx = Read-Repo 'articoli.aspx'
$vb = Read-Repo 'articoli.aspx.vb'
$cat = Read-Repo 'Public\assets\keepstore\css\catalog-ui.css'

Assert-Source (Test-HeaderLiteral $ascx) 'S01_HEADER_HAS_DEPARTMENTS_LITERAL_WITHOUT_VIEWSTATE'
Assert-Source (Test-BarBuilder $headerVb) 'S02_BAR_BUILDER_ENCODES_REUSES_SCOPE_AND_IS_EMPTY_WITHOUT_SECTORS'
Assert-Source (Test-BarCss $theme) 'S03_BAR_CSS_DESKTOP_ONLY_ONE_ROW_ELLIPSIS_FOCUS_FORCED_COLORS'
Assert-Source (Test-BarScript $js) 'S04_BAR_SCRIPT_HIDES_CLIPPED_ITEMS_AND_KEEPS_FOCUS_VISIBLE'
Assert-Source (Test-MasterWiring $master) 'S05_MASTER_LOADS_SCRIPT_AND_BUSTS_CSS_CACHE'
Assert-Source (Test-TilesMarkup $aspx) 'S06_TILES_PANEL_BEFORE_MOBILE_DEPARTMENTS_AND_CSS_BUSTER'
Assert-Source (Test-TilesCodeBehind $vb) 'S07_TILES_CODE_BEHIND_RESET_CONDITIONS_ENCODING_AND_LIMITS'
Assert-Source (Test-TilesCss $cat) 'S08_TILES_CSS_GRID_TOUCH_TARGETS_DISCLOSURE_FORCED_COLORS'
$noNames = $true
foreach ($p in 'Public\assets\keepstore\js\ks-departments-bar.js', 'Public\ui\controls\SiteHeader.ascx.vb') {
    if ((Read-Repo $p) -match '(?i)onsus|taikun') { $noNames = $false }
}
Assert-Source $noNames 'S09_NO_TEMPLATE_OR_CUSTOMER_NAME_IN_NEW_RUNTIME_CODE'

# ---- 2) mutazioni -------------------------------------------------------------
$m = Mutate-Text $ascx '<asp:Literal ID="litDepartmentsBar" runat="server" EnableViewState="false" />' '<asp:Literal ID="litDepartmentsBar" runat="server" />' 'M01'
Assert-Detected (Test-HeaderLiteral $m) 'M01_BAR_LITERAL_WITH_VIEWSTATE'
$m = Mutate-Text $headerVb 'items.Append(HttpUtility.HtmlEncode(sector.Descrizione))' 'items.Append(sector.Descrizione)' 'M02'
Assert-Detected (Test-BarBuilder $m) 'M02_SECTOR_NAME_NOT_ENCODED'
$m = Mutate-Text $headerVb 'litDepartmentsBar.Text = BuildDepartmentsBarHtml(sectors)' 'litDepartmentsBar.Text = String.Empty' 'M03'
Assert-Detected (Test-BarBuilder $m) 'M03_BAR_NOT_BOUND'
$m = Mutate-Text $theme 'flex-wrap: wrap; column-gap: 2px; min-width: 0; height: 44px;' 'flex-wrap: wrap; column-gap: 2px; min-width: 0;' 'M04'
Assert-Detected (Test-BarCss $m) 'M04_BAR_LIST_NOT_LIMITED_TO_ONE_ROW'
$m = Mutate-Text $theme 'white-space: nowrap; text-overflow: ellipsis; text-decoration: none; border-bottom: 2px solid transparent;' 'white-space: nowrap; text-decoration: none; border-bottom: 2px solid transparent;' 'M05'
Assert-Detected (Test-BarCss $m) 'M05_LONG_NAMES_NOT_BOUNDED'
$m = Mutate-Text $js 'if (lostFocus && all) { all.focus(); }' '' 'M06'
Assert-Detected (Test-BarScript $m) 'M06_FOCUS_LEFT_ON_HIDDEN_ITEM'
$m = Mutate-Text $js ' || r.right > box.right + 1' '' 'M07'
Assert-Detected (Test-BarScript $m) 'M07_HORIZONTAL_CLIPPING_NOT_DETECTED'
$m = Mutate-Text $js "if (window.ResizeObserver) { new window.ResizeObserver(schedule).observe(list); }" '' 'M08'
Assert-Detected (Test-BarScript $m) 'M08_RESIZE_OBSERVER_REMOVED'
$m = Mutate-Text $js "link.removeAttribute('tabindex');" '' 'M09'
Assert-Detected (Test-BarScript $m) 'M09_TABINDEX_NOT_RESTORED_WHEN_WIDER'
$m = Mutate-Text $master 'js/ks-departments-bar.js") %>?v=20261114-dept-nav1a' 'js/ks-departments-bar.js") %>?v=20261114-old' 'M10'
Assert-Detected (Test-MasterWiring $m) 'M10_SCRIPT_CACHE_BUSTER_NOT_UPDATED'
$m = Mutate-Text $aspx 'ID="litCatalogDepartmentTiles" runat="server" EnableViewState="false"' 'ID="litCatalogDepartmentTiles" runat="server"' 'M11'
Assert-Detected (Test-TilesMarkup $m) 'M11_TILES_LITERAL_WITH_VIEWSTATE'
$m = Mutate-Text $vb '        If HasCatalogRefinement() Then Return' '' 'M12'
Assert-Detected (Test-TilesCodeBehind $m) 'M12_TILES_SHOWN_WHILE_REFINING'
$m = Mutate-Text $vb 'If tiles.Count < 2 Then Return' 'If tiles.Count = 0 Then Return' 'M13'
Assert-Detected (Test-TilesCodeBehind $m) 'M13_TILES_FOR_SINGLE_CATEGORY_SECTOR'
$m = Mutate-Text $vb "        If pnlCatalogDepartmentTiles IsNot Nothing Then pnlCatalogDepartmentTiles.Visible = False`n" '' 'M14'
Assert-Detected (Test-TilesCodeBehind $m) 'M14_TILES_NOT_RESET_BEFORE_EARLY_EXITS'
$m = Mutate-Text $vb 'AndAlso pg > 1' 'AndAlso pg > 0' 'M15'
Assert-Detected (Test-TilesCodeBehind $m) 'M15_FIRST_PAGE_TREATED_AS_REFINEMENT'
$m = Mutate-Text $vb 'Server.HtmlEncode(label)' 'label' 'M16'
Assert-Detected (Test-TilesCodeBehind $m) 'M16_TILE_NAME_NOT_ENCODED'
$m = Mutate-Text $cat ("@media (min-width: 1200px) {" + [char]10 + "  #ksCatalogPage .ks-dept-tile-grid { grid-template-columns: repeat(4") ("@media (min-width: 1200px) {" + [char]10 + "  #ksCatalogPage .ks-dept-tile-grid { grid-template-columns: repeat(5") 'M17'
Assert-Detected (Test-TilesCss $m) 'M17_TILES_NOT_FOUR_COLUMNS_ON_DESKTOP'
$m = Mutate-Text $cat '#ksCatalogPage .ks-dept-tile-grid > li { display: flex; }' '' 'M18'
Assert-Detected (Test-TilesCss $m) 'M18_TILES_OF_A_ROW_HAVE_DIFFERENT_HEIGHTS'

Write-Output 'DEPARTMENTS_NAVIGATION_OK'
