[CmdletBinding()]
param()

# KS-A04-SEARCH-PANEL-UX-1A - pannello dei suggerimenti della ricerca in alto.
# Controllo statico del sorgente reale (JS, CSS, markup, code-behind) con mutazioni: ogni regola, rotta apposta, deve far fallire il controllo.
# La prova nel browser (desktop 1440 e telefono 390: attesa con scheletro, risultati con reparti e badge, riesecuzione con reparto,
# zero risultati, campo vuoto, tastiera) e descritta nel Masterplan.
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
function Get-Func([string]$js, [string]$name) {
    $m = [regex]::Match($js, '(?s)\n  function ' + [regex]::Escape($name) + '\(.*?\n  \}\n')
    if (-not $m.Success) { throw ('FUNCTION_MISSING=' + $name) }
    return $m.Value
}

# ---- controlli (usati sul sorgente reale e su quello mutato) ------------------
function Test-ResultMarkup([string]$js) {
    $fn = Get-Func $js 'renderSuggest'
    return ($fn -match "Prodotti per \\u00ab' \+ query \+ '\\u00bb" -and $fn -match "'Visti di recente'" -and
            $fn -match 'class="ks-suggest-item" role="option" aria-selected="false" tabindex="-1"' -and
            $fn -match "data-idx=" -and $fn -match 'matchLabel\(kind\)' -and $fn -notmatch 'esc\(item\.matchKind\)' -and
            $fn -match "if \(item\.ean && /ean/\.test\(kind\)\)" -and $fn -match 'badgesHtml\(item\)' -and
            $fn -match 'alt=""' -and $fn -match "if \(!recent\) html\.push\(scopeChipsHtml\(root, items\)\)" -and
            $fn -match "'Vedi tutti i risultati'" -and $fn -match "safeSearchUrl\(data && data\.catalogUrl, '/articoli\.aspx'\)" -and
            $fn -match "typeof data\.displayLabel === 'string'")
}
function Test-MatchLabels([string]$js) {
    return ($js -match "'exact-code': 'Codice esatto'" -and $js -match "'exact-ean': 'EAN esatto'" -and
            $js -match "'prefix-code': 'Codice'" -and $js -match "'prefix-ean': 'EAN'")
}
function Test-States([string]$js) {
    $fn = Get-Func $js 'renderSuggestMessage'
    $zero = Get-Func $js 'zeroResultHtml'
    $idle = Get-Func $js 'idleHtml'
    $phone = Get-Func $js 'supportPhone'
    return ($fn -match "pending = s\.phase === 'pending'" -and $fn -match 'skeletonHtml\(message, query\.length >= 2 \? 3 : 0\)' -and
            $fn -match "s\.phase === 'empty'" -and $fn -match 'zeroResultHtml\(root, query\)' -and $fn -match 'idleHtml\(root\)' -and
            $fn -match "box\.setAttribute\('aria-busy'" -and $fn -match 'bindSuggestLinks\(root, box\)' -and
            $zero -match 'Nessun prodotto per' -and $zero -match "browseChipsHtml\(root, 'Sfoglia un reparto'\)" -and
            $zero -match 'scopeActive\(root\) \? scopeChipsHtml\(root, \[\]\) : ''' -and $zero -match 'supportPhone\(\)' -and $zero -match 'catalogLinkHtml\(root,' -and
            $idle -match 'Cosa stai cercando\?' -and $idle -match 'Scrivi almeno 2 caratteri' -and
            $phone.Contains('if (!/^tel:\+?[0-9][0-9 ().\-]{4,24}$/.test(href)) return null;'))
}
function Test-Departments([string]$js) {
    $fn = Get-Func $js 'departmentOptions'
    return ($fn -match "safeSearchUrl\(String\(option\.value \|\| ''\), '/articoli\.aspx'\)" -and $fn -match "params\.get\('st'\)" -and
            $fn -match "\['ct', 'tp', 'gr', 'sg', 'mr'\]\.some\(function \(k\) \{ return params\.has\(k\); \}\)" -and
            $fn -match '\[1-9\]\\d\*')
}
function Test-ScopeChips([string]$js) {
    $chips = Get-Func $js 'scopeChipsHtml'
    $bind = Get-Func $js 'bindSuggestLinks'
    return ($chips -match 'data-ks-scope-reset="1"' -and $chips -match 'data-ks-scope="' -and $chips -match 'if \(chips\.length < 2\) return' -and
            $chips -match 'byKey\[key\]' -and $chips -match 'visually-hidden' -and
            $bind -match "new Event\('change', \{ bubbles: true \}\)" -and $bind -match "sel\.selectedIndex = target" -and
            $bind -match "navigateSuggestLink\(root, a\)" -and $bind -match 'e\.preventDefault\(\)')
}
function Test-Messages([string]$js) {
    return ($js -notmatch 'Errore temporaneo nella suggest' -and $js -match "Suggerimenti non disponibili ora\. Premi Invio per cercare nel catalogo\." -and
            $js -match "function pendingMessage\(root\)" -and
            (([regex]::Matches($js, 'renderSuggestMessage\(root, pendingMessage\(root\), ''pending''\)')).Count -eq 2) -and
            $js -notmatch 'Puoi premere Invio per cercare nel catalogo')
}
function Test-Keyboard([string]$js) {
    $bind = Get-Func $js 'bindSuggestLinks'
    $quiet = Get-Func $js 'focusFieldQuietly'
    $buttons = Get-Func $js 'buttonsFromRoot'
    return ($buttons -match "return !button\.closest\('\.ks-suggest'\);" -and
            $js -match 'if \(e\.relatedTarget && root\.contains\(e\.relatedTarget\)\) return;' -and
            $bind -match 'box\.__ksEscapeBound' -and $bind -match "if \(e\.key !== 'Escape'\) return;" -and $bind -match 'hideSuggest\(root\);\s+focusFieldQuietly\(root\);' -and
            $bind -match "sel\.dispatchEvent\(new Event\('change', \{ bubbles: true \}\)\);\s+focusFieldQuietly\(root\);" -and
            $quiet -match 'document\.activeElement === field' -and $quiet -match 's\.suppressFocusOpen = true' -and $quiet -match 'finally \{ s\.suppressFocusOpen = false; \}' -and
            $js -match "input\.addEventListener\('focus', function \(\) \{ if \(!s\.suppressFocusOpen && inputFromRoot\(root\) === input\) queueSearch\(root, true\); \}\);")
}
function Test-Navigation([string]$js) {
    $fn = Get-Func $js 'navigateSuggestLink'
    return ($fn -match 'currentSearch\(root, generation, intent\)' -and $fn -match "safeSearchUrl\(String\(anchor\.getAttribute\('href'\) \|\| ''\), '/articoli\.aspx'\)" -and
            $fn -match 'invalidateSearch\(root\)' -and $fn -match 'window\.location\.href = url')
}
function Test-PanelCss([string]$js) {
    return ($js -match '\.ks-suggest-all\{[^}]*min-height:44px[^}]*background:#d80027;color:#fff' -and
            $js -match '\.ks-suggest-price\{[^}]*color:#b0001f' -and
            $js -match '\.ks-suggest-chip\{[^}]*min-height:32px' -and
            $js -match '\.ks-suggest-chip:focus-visible,\.ks-suggest-all:focus-visible[^}]*outline:3px solid #d80027' -and
            $js -match '@media \(prefers-reduced-motion:no-preference\)\{\.ks-suggest-skel-thumb' -and
            $js -notmatch 'ks-suggest-hint' -and
            $js -match '\.ks-suggest-foot\{display:grid;\}\.ks-suggest-all\{width:100%;\}')
}
function Test-MobileMarkup([string]$ascx) {
    $block = [regex]::Match($ascx, '(?s)data-ks-search-form="mobile">.*?id="ksSearchSuggestMobile"').Value
    if (-not $block) { return $false }
    $i = $block.IndexOf('ID="tbCercaMobile"'); $b = $block.IndexOf('id="btnSearchMobile"'); $s = $block.IndexOf('ID="product_cat_mobile"')
    return ($i -ge 0 -and $b -gt $i -and $s -gt $b)
}
function Test-MobileCss([string]$css) {
    return ($css -match '(?s)\.ks-header-ui \.ks-mobile-search-area \.ks-search-shell \.select-category \{[^}]*grid-row: 2;[^}]*justify-self: start;' -and
            $css -match '(?s)\.ks-header-ui \.ks-mobile-search-area \.ks-search-shell \.ks-search-category-select \{[^}]*min-height: 40px;[^}]*border-radius: 999px;')
}
function Test-Busters([string]$master) {
    return ($master -match 'js/ks-page-flags\.js"\) %>\?v=20261114-(?:search-panel1a|deadcode-c1a)' -and $master -match 'theme-overrides\.css"\) & "\?v=(?:20261114-(?:search-panel1a|home-vetrina[12]a|deadcode-c1a)|20261115-home-cards1a)"')
}
function Test-ServerLabel([string]$vb) {
    $recent = [regex]::Match($vb, '(?s)Private Function BuildRecentResult\(.*?End Function').Value
    $search = [regex]::Match($vb, '(?s)Private Function BuildSearchResult\(.*?End Function').Value
    return ($recent -match 'output\("displayLabel"\) = _commercial\.PriceContext\.DisplayLabel' -and
            $search -match '\{"displayLabel", _commercial\.PriceContext\.DisplayLabel\}')
}

# ---- 1) sorgente reale --------------------------------------------------------
$js = Read-Repo 'Public\assets\keepstore\js\ks-page-flags.js'
$ascx = Read-Repo 'Public\ui\controls\SiteHeader.ascx'
$themeCss = Read-Repo 'Public\assets\keepstore\css\theme-overrides.css'
$master = Read-Repo 'Page.master'
$vb = Read-Repo 'search_suggest.aspx.vb'
Assert-Source (Test-ResultMarkup $js) 'S01_RESULTS_HEAD_ITEMS_BADGES_FOOTER_AND_CONTRACT_HOOKS'
Assert-Source (Test-MatchLabels $js) 'S02_MATCH_KIND_SHOWN_AS_READABLE_LABEL'
Assert-Source (Test-States $js) 'S03_WAITING_ZERO_RESULT_AND_IDLE_STATES'
Assert-Source (Test-Departments $js) 'S04_DEPARTMENTS_FROM_THE_REAL_SELECT_ONLY_TOP_LEVEL'
Assert-Source (Test-ScopeChips $js) 'S05_SCOPE_CHIPS_REUSE_THE_SELECT_AND_THE_EXISTING_CHANGE_HANDLER'
Assert-Source (Test-Messages $js) 'S06_MESSAGES_CORRECTED_AND_PENDING_TEXT_SHARED'
Assert-Source (Test-Navigation $js) 'S07_CATALOG_LINKS_VALIDATED_AND_GUARDED_BY_GENERATION'
Assert-Source (Test-Keyboard $js) 'S07B_KEYBOARD_REACHES_THE_PANEL_ACTIONS_AND_CHIPS_ARE_NOT_SEARCH_BUTTONS'
Assert-Source (Test-PanelCss $js) 'S08_PANEL_CSS_CONTRAST_TOUCH_TARGETS_MOTION_AND_MOBILE'
Assert-Source (Test-MobileMarkup $ascx) 'S09_MOBILE_DOM_ORDER_FIELD_BUTTON_THEN_DEPARTMENT'
Assert-Source (Test-MobileCss $themeCss) 'S10_MOBILE_DEPARTMENT_SELECT_IS_A_COMPACT_SECOND_ROW'
Assert-Source (Test-Busters $master) 'S11_CACHE_BUSTERS_UPDATED'
Assert-Source (Test-ServerLabel $vb) 'S12_SERVER_SENDS_THE_PRICE_DISPLAY_LABEL'
$noNames = $true
foreach ($p in 'Public\assets\keepstore\js\ks-page-flags.js') { if ((Read-Repo $p) -match '(?i)onsus|taikun') { $noNames = $false } }
Assert-Source $noNames 'S13_NO_TEMPLATE_OR_CUSTOMER_NAME_IN_THE_SEARCH_SCRIPT'

# ---- 2) mutazioni -------------------------------------------------------------
$m = Mutate-Text $js "if (item.ean && /ean/.test(kind)) meta.push" "if (item.ean) meta.push" 'M01'
Assert-Detected (Test-ResultMarkup $m) 'M01_EAN_SHOWN_ON_EVERY_ROW'
$m = Mutate-Text $js "if (label) meta.push('<span class=""ks-suggest-tag"">' + esc(label) + '</span>');" "meta.push('<span class=""ks-suggest-tag"">' + esc(item.matchKind) + '</span>');" 'M02'
Assert-Detected (Test-ResultMarkup $m) 'M02_RAW_MATCH_KIND_SHOWN'
$m = Mutate-Text $js "if (!recent) html.push(scopeChipsHtml(root, items));" "html.push(scopeChipsHtml(root, items));" 'M03'
Assert-Detected (Test-ResultMarkup $m) 'M03_SCOPE_CHIPS_ON_RECENT_PRODUCTS'
$m = Mutate-Text $js "'Vedi tutti i risultati'" "'Vai al catalogo'" 'M04'
Assert-Detected (Test-ResultMarkup $m) 'M04_NO_SEE_ALL_RESULTS_LINK'
$m = Mutate-Text $js "'exact-code': 'Codice esatto'" "'exact-code': 'exact-code'" 'M05'
Assert-Detected (Test-MatchLabels $m) 'M05_TECHNICAL_LABEL_KEPT'
$m = Mutate-Text $js "zeroResultHtml(root, query) : idleHtml(root)" "idleHtml(root) : idleHtml(root)" 'M06'
Assert-Detected (Test-States $m) 'M06_ZERO_RESULT_STATE_LOST'
$m = Mutate-Text $js "skeletonHtml(message, query.length >= 2 ? 3 : 0)" "skeletonHtml(message, 0)" 'M07'
Assert-Detected (Test-States $m) 'M07_NO_WAITING_SKELETON'
$m = Mutate-Text $js "if (!/^tel:" "if (false && !/^tel:" 'M08'
Assert-Detected (Test-States $m) 'M08_PHONE_NOT_VALIDATED'
$m = Mutate-Text $js "['ct', 'tp', 'gr', 'sg', 'mr'].some(function (k) { return params.has(k); })" "false" 'M09'
Assert-Detected (Test-Departments $m) 'M09_CATEGORY_OPTIONS_LISTED_AS_DEPARTMENTS'
$m = Mutate-Text $js "sel.dispatchEvent(new Event('change', { bubbles: true }));" "" 'M10'
Assert-Detected (Test-ScopeChips $m) 'M10_CHIP_DOES_NOT_TRIGGER_THE_SEARCH'
$m = Mutate-Text $js "if (chips.length < 2) return '';" "if (chips.length < 1) return '';" 'M11'
Assert-Detected (Test-ScopeChips $m) 'M11_SCOPE_CHIPS_FOR_A_SINGLE_DEPARTMENT'
$m = Mutate-Text $js "'Suggerimenti non disponibili ora. Premi Invio per cercare nel catalogo.', timeout" "'Errore temporaneo nella suggest. Premi Invio per cercare nel catalogo.', timeout" 'M12'
Assert-Detected (Test-Messages $m) 'M12_OLD_ERROR_TEXT_BACK'
$m = Mutate-Text $js "if (!currentSearch(root, generation, intent)) return;`n    var url = safeSearchUrl(String(anchor" "var url = safeSearchUrl(String(anchor" 'M13'
Assert-Detected (Test-Navigation $m) 'M13_LINK_FOLLOWS_A_STALE_SEARCH'
$m = Mutate-Text $js ".ks-suggest-all{display:inline-flex;align-items:center;justify-content:center;min-height:44px;padding:0 18px;border-radius:999px;background:#d80027;color:#fff;" ".ks-suggest-all{display:inline-flex;align-items:center;justify-content:center;min-height:44px;padding:0 18px;border-radius:999px;background:#ff3d3d;color:#fff;" 'M14'
Assert-Detected (Test-PanelCss $m) 'M14_LOW_CONTRAST_PRIMARY_BUTTON'
$m = Mutate-Text $js "@media (prefers-reduced-motion:no-preference){.ks-suggest-skel-thumb" "@media (min-width:1px){.ks-suggest-skel-thumb" 'M15'
Assert-Detected (Test-PanelCss $m) 'M15_SKELETON_ANIMATES_WITH_REDUCED_MOTION'
# ordine invertito: il reparto prima del campo
$blk = [regex]::Match($ascx, '(?s)<div class="select-category">\s*<asp:Label runat="server" AssociatedControlID="product_cat_mobile".*?</div>').Value
if (-not $blk) { throw 'MUTATION_NOT_APPLIED=M16' }
$m = $ascx.Replace($blk, '')
$m = $m.Replace('<fieldset>' + "`n" + '                    <asp:TextBox ID="tbCercaMobile"', $blk + "`n" + '                <fieldset>' + "`n" + '                    <asp:TextBox ID="tbCercaMobile"')
Assert-Detected (Test-MobileMarkup $m) 'M16_DEPARTMENT_BEFORE_THE_FIELD_IN_DOM_ORDER'
$m = Mutate-Text $themeCss "  grid-row: 2;`n  min-width: 0;" "  min-width: 0;" 'M17'
Assert-Detected (Test-MobileCss $m) 'M17_DEPARTMENT_SELECT_NOT_ON_A_SECOND_ROW'
$m = Mutate-Text $master 'js/ks-page-flags.js") %>?v=20261114-deadcode-c1a' 'js/ks-page-flags.js") %>?v=20261021-suggest-commercial1a' 'M18'
Assert-Detected (Test-Busters $m) 'M18_SCRIPT_CACHE_BUSTER_NOT_UPDATED'
$m = Mutate-Text $vb 'output("displayLabel") = _commercial.PriceContext.DisplayLabel' 'output("displayLabel") = String.Empty' 'M19'
Assert-Detected (Test-ServerLabel $m) 'M19_RECENT_RESULT_WITHOUT_LABEL'

$m = Mutate-Text $js ".filter(function (button) { return !button.closest('.ks-suggest'); })" "" 'M20'
Assert-Detected (Test-Keyboard $m) 'M20_PANEL_CHIPS_ARE_BOUND_AS_SEARCH_BUTTONS'
$m = Mutate-Text $js "if (e.relatedTarget && root.contains(e.relatedTarget)) return;" "" 'M21'
Assert-Detected (Test-Keyboard $m) 'M21_TAB_CLOSES_THE_PANEL_BEFORE_THE_ACTIONS'
$m = Mutate-Text $js "if (e.key !== 'Escape') return;" "return;" 'M22'
Assert-Detected (Test-Keyboard $m) 'M22_ESCAPE_FROM_THE_PANEL_NOT_HANDLED'
$m = Mutate-Text $js "sel.dispatchEvent(new Event('change', { bubbles: true }));`n        focusFieldQuietly(root);" "sel.dispatchEvent(new Event('change', { bubbles: true }));" 'M23'
Assert-Detected (Test-Keyboard $m) 'M23_FOCUS_LOST_AFTER_A_CHIP'
$m = Mutate-Text $js "if (!s.suppressFocusOpen && inputFromRoot(root) === input)" "if (inputFromRoot(root) === input)" 'M24'
Assert-Detected (Test-Keyboard $m) 'M24_ESCAPE_REOPENS_THE_SUGGESTIONS'
$m = Mutate-Text $js "(scopeActive(root) ? scopeChipsHtml(root, []) : '') + browseChipsHtml(root, 'Sfoglia un reparto') +" "browseChipsHtml(root, 'Sfoglia un reparto') +" 'M25'
Assert-Detected (Test-States $m) 'M25_NO_WAY_OUT_OF_A_DEPARTMENT_WITH_ZERO_RESULTS'
$m = Mutate-Text $js "esc(head) + '</span></div>'];" "esc(head) + '</span><span class=""ks-suggest-hint"">Invio: tutti i risultati</span></div>'];" 'M26'
Assert-Detected (Test-PanelCss $m) 'M26_MISLEADING_ENTER_HINT_BACK'

Write-Output 'SEARCH_PANEL_OK'
