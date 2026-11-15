[CmdletBinding()]
param()

# KS-A04-HOME-DEADCODE-C-1A - codice morto parte c: pagine e risorse mai referenziate, funzioni JavaScript dichiarate e mai chiamate,
# regole CSS di classi che nessun markup, script o codice usa, attributi mai letti, membri della master e dell'intestazione senza chiamanti.
# Controllo statico con mutazioni: se il codice morto torna (o se si cancella un contratto vivo) il test deve fallire.
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
    $old = $old -replace "`r`n", "`n"; $new = $new -replace "`r`n", "`n"
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}

$removedFiles = @('home_runtime_feed.aspx', 'home_runtime_feed.aspx.vb', 'search.aspx', 'search.aspx.vb', 'ThemeTest.aspx', 'ThemeTest.aspx.vb',
    'Public/ui/controls/ProductCardStatic.ascx', 'Public/ui/controls/ProductCardStatic.ascx.vb', 'Public/assets/theme/default/theme.css', 'Public/assets/theme/default/theme.js')
$removedJs = @('buildQueryUrl', 'rankKey', 'saveRank', 'localHomeProducts', 'marketplaceMarkup', 'renderMarketItems', 'renderFacets', 'addCompare', 'itemBadges', 'compareList', 'saveCompare')
$removedMembers = @('AddToHeader', 'AggiornaTotaleCarrelloHeader', 'CreaVistaPromo', 'DataList_DIV1_Init', 'DataList_DIV2_Init', 'DataList_DIV3_Init', 'DataList_DIV4_Init',
    'rptNavSettori_ItemDataBound', 'rptNavCategorie_ItemDataBound', 'rptNavSettoriMobile_ItemDataBound', 'rptNavCategorieMobile_ItemDataBound', 'BindNavSettori', 'LoadNavSettori')
$removedClasses = @('ks-order-status-row', 'ks-status-card', 'ks-status-card-head', 'ks-home-full-width', 'ks-home-benefits-section', 'ks-ai130-kicker', 'ks-ai130-form', 'ks-ai130-results',
    'ks-ai130-answer', 'ks-ai130-examples', 'ks-ai130-head', 'ks-home-offers-fallback', 'ks-home-promo-institutional', 'ks-home-bottom-promo-grid', 'ks-home-services-grid', 'ks-home-service-item',
    'ks-home-service-icon', 'ks-home-trust-list', 'ks-home-progress-heading', 'ks-home-progress-bar', 'ks-home-progress-quantity', 'ks-recent-price-slot', 'ks-ai130-img', 'ks-guide-request',
    'ks-filter-actions', 'ks-filter-removeall', 'ks-gv-grid', 'ks-gv-header', 'ks-gv-pager', 'ks-product-card', 'ks-product-img', 'ks-product-title', 'ks-product-meta', 'ks-rv-cart-action',
    'ks-availability-info', 'ks-availability-info__icon', 'ks-availability-info__shape', 'ks-availability-info__stem', 'ks-availability-info__dot')
# contratti: sembrano morti ma sono letti da test o da codice
$keepClasses = @('ks-deal-slot--progress', 'ks-ai130-shell', 'ks-ai130-tools', 'ks-home-category-card', 'ks-home-direct-category-link')
$keepJs = @('bindHeaderSearch', 'requestSuggest', 'renderSuggest', 'readRank', 'resolveSearch', 'queueSearch', 'bindGlobalSubmitGuard')

$js = Read-Repo 'Public/assets/keepstore/js/ks-page-flags.js'
$cssFiles = @('Public/assets/keepstore/css/theme-overrides.css', 'Public/assets/keepstore/css/catalog-ui.css', 'Public/assets/keepstore/css/product-ui.css')
$css = @{}
foreach ($f in $cssFiles) { $css[$f] = Read-Repo $f }
$master = Read-Repo 'Page.master.vb'
$headerAscx = Read-Repo 'Public/ui/controls/SiteHeader.ascx'
$headerVb = Read-Repo 'Public/ui/controls/SiteHeader.ascx.vb'
$postLogin = Read-Repo 'App_Code/PostLoginReturnUrlPolicy.vb'

function Test-FilesGone() {
    foreach ($f in $removedFiles) { if (Test-Path -LiteralPath (Join-Path $repoRoot $f)) { return $false } }
    $hits = @(& git -C $repoRoot grep -n -i -E 'ProductCardStatic|assets/theme/default|home_runtime_feed\.aspx"|ThemeTest\.aspx"|Inherits="ThemeTest"' -- '*.aspx' '*.ascx' '*.master' '*.vb' '*.js' '*.config' | Where-Object { $_ -notmatch '^App_Code/StorefrontReturnUrlPolicy\.vb' })
    return ($hits.Count -eq 0 -and (Test-Path -LiteralPath (Join-Path $repoRoot 'Public/ui/controls/ProductCard.ascx')))
}
function Test-JsClean([string]$text) {
    foreach ($n in $removedJs) { if ($text -match ('(?m)^\s*function ' + [regex]::Escape($n) + '\s*\(')) { return $false } }
    if ($text -match 'MARKET_KEY|COMPARE_KEY') { return $false }
    # nessuna funzione dichiarata e mai usata, nessuna variabile dichiarata e mai usata
    $names = [regex]::Matches($text, '(?m)^\s*function ([A-Za-z0-9_$]+)\s*\(') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    foreach ($n in $names) { if (([regex]::Matches($text, '(?<![A-Za-z0-9_$.])' + [regex]::Escape($n) + '(?![A-Za-z0-9_$])')).Count -le 1) { return $false } }
    $vars = [regex]::Matches($text, '(?m)^\s*(?:var|const|let) ([A-Za-z0-9_$]+)\s*=') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    foreach ($n in $vars) { if (([regex]::Matches($text, '(?<![A-Za-z0-9_$.])' + [regex]::Escape($n) + '(?![A-Za-z0-9_$])')).Count -le 1) { return $false } }
    foreach ($n in $keepJs) { if ($text -notmatch ('(?m)^\s*function ' + [regex]::Escape($n) + '\s*\(')) { return $false } }
    return $true
}
function Test-CssClean([hashtable]$files) {
    $all = ''
    foreach ($k in $files.Keys) {
        $t = $files[$k]
        $all += $t
        if (([regex]::Matches($t, '\{')).Count -ne ([regex]::Matches($t, '\}')).Count) { return $false }
        if ($t -match "(?m)^(/\*[^\n]*\*/)[ \t]*\n(?:[ \t]*\n)*(?=/\*[^\n]*\*/|\s*\}|\z)") { return $false }
    }
    foreach ($c in $removedClasses) { if ($all -match ('\.' + [regex]::Escape($c) + '(?![A-Za-z0-9_-])')) { return $false } }
    foreach ($c in $keepClasses) { if ($all -notmatch ('\.' + [regex]::Escape($c) + '(?![A-Za-z0-9_-])')) { return $false } }
    return $true
}
function Test-MarkupAndMembers([string]$m, [string]$hAscx, [string]$hVb, [string]$policy) {
    foreach ($n in $removedMembers) { if ($m -match ('(?m)^\s*(?:(?:Private|Protected|Public|Friend)\s+)?(?:Shared\s+)?(?:Function|Sub)\s+' + [regex]::Escape($n) + '\s*\(')) { return $false } }
    if ($m -match 'Public Class Nav(?:Settore|Categoria|Tipologia)Item') { return $false }
    # contratti vivi della master
    if (-not ($m.Contains('Implements ISeoMaster') -and $m.Contains('Public Property SeoJsonLd As String Implements ISeoMaster.SeoJsonLd') -and $m.Contains('Private Function GetHeadDynamicContainer() As Control') -and
              $m.Contains('Private Function HeaderHasMeta(') -and $m.Contains('Public Function SafeText('))) { return $false }
    if ($hAscx -match 'data-ks-i18n') { return $false }
    if ($hVb -match 'rptNavTipologieMobile_ItemDataBound') { return $false }
    if ($hAscx -notmatch 'rptNavTipologieMobile' -or $hVb -notmatch 'rptNavSettoriMobile_ItemDataBound' -or $hVb -notmatch 'rptNavCategorieMobile_ItemDataBound') { return $false }
    if ($policy -match '"search\.aspx"') { return $false }
    # nessun membro della master dichiarato e mai usato (ne altrove)
    $others = @(& git -C $repoRoot ls-files -- '*.aspx' '*.ascx' '*.vb' '*.master' '*.js') | Where-Object { $_ -ne 'Page.master.vb' -and $_ -notmatch '^(docs|Tools)/' }
    $otherText = ''
    foreach ($f in $others) { $p = Join-Path $repoRoot $f; if (Test-Path -LiteralPath $p) { $otherText += [IO.File]::ReadAllText($p) + "`n" } }
    $masterMarkup = Read-Repo 'Page.master'
    $names = [regex]::Matches($m, '(?m)^\s*(?:Private|Protected|Public|Friend)\s+(?:Shared\s+)?(?:Function|Sub)\s+(\w+)\s*\(') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    foreach ($n in $names) {
        $rx = [regex]('\b' + [regex]::Escape($n) + '\b')
        $handles = [regex]::IsMatch($m, '(?m)^\s*(?:Private|Protected|Public)\s+(?:Shared\s+)?Sub\s+' + [regex]::Escape($n) + '\([^\r\n]*\bHandles\b')
        if ($rx.Matches($m).Count -le 1 -and $rx.Matches($masterMarkup).Count -eq 0 -and $rx.Matches($otherText).Count -eq 0 -and -not $handles) { return $false }
    }
    return $true
}

Assert-Source (Test-FilesGone) 'D01_LEGACY_PAGES_AND_THEME_ASSETS_ARE_GONE_AND_NOTHING_REFERENCES_THEM'
Assert-Source (Test-JsClean $js) 'D02_KS_PAGE_FLAGS_HAS_NO_DECLARED_ONLY_FUNCTIONS_OR_VARIABLES'
Assert-Source (Test-CssClean $css) 'D03_NO_RULE_FOR_A_CLASS_THAT_NOTHING_USES_AND_THE_LIVE_ONES_REMAIN'
Assert-Source (Test-MarkupAndMembers $master $headerAscx $headerVb $postLogin) 'D04_MASTER_AND_HEADER_HAVE_NO_UNREFERENCED_MEMBERS_OR_DEAD_ATTRIBUTES'
$busterOk = (((Read-Repo 'Page.master').Contains('ThemeManager.Asset("css/theme-overrides.css") & "?v=20261114-deadcode-c1a"') -or (Read-Repo 'Page.master').Contains('ThemeManager.Asset("css/theme-overrides.css") & "?v=20261115-home-cards1a"')) -and (Read-Repo 'Page.master').Contains('ThemeManager.Asset("js/ks-page-flags.js") %>?v=20261114-deadcode-c1a') -and
             (Read-Repo 'articoli.aspx').Contains('css/catalog-ui.css") %>?v=20261114-deadcode-c1a') -and (Read-Repo 'articolo.aspx').Contains('css/product-ui.css") %>?v=20261114-deadcode-c1a'))
Assert-Source $busterOk 'D05_CACHE_BUSTERS_OF_THE_CLEANED_ASSETS_UPDATED'

# JS: una funzione morta che torna, una chiamata che sparisce (funzione viva che diventa morta), una variabile morta
Assert-Detected (Test-JsClean ($js + "`nfunction brokenLeftover() { return 1; }`n")) 'M01_DEAD_JS_FUNCTION_COMES_BACK'
Assert-Detected (Test-JsClean ($js + "`nvar MARKET_KEY = 'x';`n")) 'M02_DEAD_JS_VARIABLE_COMES_BACK'
$m = Mutate-Text $js 'function bindHeaderSearch(' 'function bindHeaderSearchX(' 'M03'
Assert-Detected (Test-JsClean $m) 'M03_LIVE_ENTRY_POINT_DELETED_OR_RENAMED'
# CSS: una regola morta che torna, una regola viva cancellata, graffe rotte, commento orfano
$tcss = @{}; foreach ($k in $css.Keys) { $tcss[$k] = $css[$k] }
$tcss['Public/assets/keepstore/css/catalog-ui.css'] = $css['Public/assets/keepstore/css/catalog-ui.css'] + "`n.ks-gv-grid { display: block; }`n"
Assert-Detected (Test-CssClean $tcss) 'M04_DEAD_CSS_RULE_COMES_BACK'
$tcss = @{}; foreach ($k in $css.Keys) { $tcss[$k] = $css[$k] }
$tcss['Public/assets/keepstore/css/theme-overrides.css'] = $css['Public/assets/keepstore/css/theme-overrides.css'] + "`n.ks-home-trust-list > div { color: red; }`n"
Assert-Detected (Test-CssClean $tcss) 'M05_DEAD_CSS_COMPOUND_SELECTOR_COMES_BACK'
$tcss = @{}; foreach ($k in $css.Keys) { $tcss[$k] = $css[$k] }
$tcss['Public/assets/keepstore/css/theme-overrides.css'] = ($css['Public/assets/keepstore/css/theme-overrides.css'] -replace '(?s)body\.ks-page-home #ksHomePage \.ks-home-deals \.ks-deal-slot--progress \{[^}]*\}', '') -replace 'ks-deal-slot--progress', 'ks-deal-slot--other'
Assert-Detected (Test-CssClean $tcss) 'M06_LIVE_CONTRACT_CLASS_DELETED'
$tcss = @{}; foreach ($k in $css.Keys) { $tcss[$k] = $css[$k] }
$tcss['Public/assets/keepstore/css/product-ui.css'] = $css['Public/assets/keepstore/css/product-ui.css'] + "`n.x {`n"
Assert-Detected (Test-CssClean $tcss) 'M07_UNBALANCED_BRACES'
$tcss = @{}; foreach ($k in $css.Keys) { $tcss[$k] = $css[$k] }
$tcss['Public/assets/keepstore/css/catalog-ui.css'] = $css['Public/assets/keepstore/css/catalog-ui.css'] + "`n/* Orphan section title */`n"
Assert-Detected (Test-CssClean $tcss) 'M08_ORPHAN_COMMENT_AFTER_A_REMOVAL'
# master e intestazione
$m = $master + "`n    Private Sub UnusedLeftover()`n    End Sub`n"
Assert-Detected (Test-MarkupAndMembers $m $headerAscx $headerVb $postLogin) 'M09_UNREFERENCED_MASTER_MEMBER_COMES_BACK'
$m = Mutate-Text $master 'Public Property SeoJsonLd As String Implements ISeoMaster.SeoJsonLd' 'Public Property SeoJsonLdX As String' 'M10'
Assert-Detected (Test-MarkupAndMembers $m $headerAscx $headerVb $postLogin) 'M10_LIVE_MASTER_CONTRACT_DELETED'
$m = $master + "`n    Private Sub BindNavSettori()`n    End Sub`n"
Assert-Detected (Test-MarkupAndMembers $m $headerAscx $headerVb $postLogin) 'M11_UNREACHABLE_NAVIGATION_LOADER_COMES_BACK'
Assert-Detected (Test-MarkupAndMembers $master ($headerAscx + ' data-ks-i18n="x"') $headerVb $postLogin) 'M12_DEAD_I18N_ATTRIBUTE_COMES_BACK'
Assert-Detected (Test-MarkupAndMembers $master $headerAscx ($headerVb + "`n    Protected Sub rptNavTipologieMobile_ItemDataBound(ByVal sender As Object, ByVal e As EventArgs)`n    End Sub`n") $postLogin) 'M13_UNWIRED_HEADER_HANDLER_COMES_BACK'
Assert-Detected (Test-MarkupAndMembers $master $headerAscx $headerVb ($postLogin + "`n        `"search.aspx`",`n")) 'M14_ALLOWLIST_ENTRY_FOR_THE_DELETED_PAGE_COMES_BACK'
Write-Output 'HOME_DEADCODE_C_OK'
