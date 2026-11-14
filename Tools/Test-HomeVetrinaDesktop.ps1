[CmdletBinding()]
param()

# KS-A04-HOME-VETRINA-2A - vetrina HOME su desktop e tablet: reparti e categorie in un solo blocco compatto, offerte prima delle novita,
# piu scelti in una fila con frecce e solo articoli acquistabili, prezzi come il catalogo, scheda offerta senza spazi riservati inutili,
# fila scorrevole su tablet. Controllo statico con mutazioni: ogni regola, rotta apposta, deve far fallire il controllo.
# La misura nel browser (altezze per larghezza, nessuno scorrimento orizzontale) e descritta nel Masterplan.
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
    # i letterali multilinea del file prendono i fine riga del checkout (CRLF con autocrlf): si confrontano sempre con LF.
    $old = $old -replace "`r`n", "`n"; $new = $new -replace "`r`n", "`n"
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}
function Get-Method([string]$source, [string]$name) {
    $m = [regex]::Match($source, '(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) ' + [regex]::Escape($name) + '\b.*?^    End (?:Function|Sub)')
    if (-not $m.Success) { return '' }
    return $m.Value
}
function Get-Block([string]$css) {
    $a = $css.IndexOf('/* ===== KS-A04-HOME-VETRINA-2A')
    if ($a -lt 0) { throw 'VETRINA2A_BLOCK_MISSING' }
    return $css.Substring($a)
}
function Get-MediaBody([string]$block, [string]$header) {
    # corpo (con le graffe bilanciate) della prima @media che inizia con $header
    $i = $block.IndexOf($header)
    if ($i -lt 0) { return '' }
    $open = $block.IndexOf('{', $i)
    $depth = 0
    for ($k = $open; $k -lt $block.Length; $k++) {
        if ($block[$k] -eq '{') { $depth++ } elseif ($block[$k] -eq '}') { $depth--; if ($depth -eq 0) { return $block.Substring($open + 1, $k - $open - 1) } }
    }
    return ''
}

$aspx = Read-Repo 'Default.aspx'
$vb = Read-Repo 'Default.aspx.vb'
$css = Read-Repo 'Public/assets/keepstore/css/theme-overrides.css'
$master = Read-Repo 'Page.master'

function Test-SectionOrder([string]$a) {
    $ids = @('HomeHeroSection', 'KsLocalAiSearch130', 'HomeMainCategoriesSection', 'HomeDirectCategoriesSection', 'HomeOffersSection', 'HomeFeaturedProductsSection', 'HomeCollectionSection', 'HomeLegacyBestSection', 'HomeRecentlyViewedSection', 'HomeTrustSection', 'HomeBrandsSection')
    $last = -1
    foreach ($id in $ids) {
        $i = $a.IndexOf('<section id="' + $id + '"')
        if ($i -lt 0 -or $i -le $last) { return $false }
        $last = $i
    }
    return $true
}
function Test-BestSection([string]$a, [string]$v) {
    $tag = [regex]::Match($a, '<div class="swiper tf-sw-products" data-preview="[^"]*"[^>]*data-grid="[^"]*"[^>]*>').Value
    $pool = Get-Method $v 'GetBestSellerPool'
    return ($tag.Contains('data-preview="4"') -and $tag.Contains('data-tablet="3"') -and $tag.Contains('data-pagination-lg="4"') -and $tag.Contains('data-pagination-md="3"') -and
            $tag.Contains('data-grid="1"') -and $tag.Contains('data-grid-mobile="1"') -and
            $pool.Contains('COALESCE(ca.CommercialScore,0)>0 AND (" & StockWhereClause() & "-" & ReservedWhereClause() & ")>=1"') -and $pool.Contains('limit, False, False, True)'))
}
function Test-NetQuantityEquivalence([string]$v) {
    # il filtro e i valori che la scheda legge (Giacenza e Impegnata) nascono dalle STESSE espressioni, mai NULL: stessa quantita netta
    $load = Get-Method $v 'TryLoadProducts'
    return ($load.Contains('Dim stockSql As String = If(catalogDiscovery, "COALESCE(stk.Giacenza,0)", StockWhereClause())') -and
            $load.Contains('Dim reservedSql As String = If(catalogDiscovery, "COALESCE(stk.Impegnata,0)", ReservedWhereClause())') -and
            $load.Contains('sql.Append(stockSql).Append(" AS Giacenza, ")') -and $load.Contains('sql.Append(reservedSql).Append(" AS Impegnata, ")') -and
            $v.Contains('Return "COALESCE(stk.Giacenza, COALESCE(v.Giacenza,0))"') -and $v.Contains('Return "COALESCE(stk.Impegnata, COALESCE(v.Impegnata,0))"'))
}
function Test-PriceMarkup([string]$v) {
    $fn = Get-Method $v 'RenderPriceBlock'
    return ($fn.Contains('If(emphasize, "new-price h4 fw-semibold text-primary mb-0", "new-price body-md-2 fw-medium mb-0")') -and $fn -notmatch 'fw-normal')
}
function Test-PriceCss([string]$c) {
    $b = Get-Block $c
    $top = $b
    $m = [regex]::Match($b, '@media')
    if ($m.Success) { $top = $b.Substring(0, $m.Index) }
    return ($top.Contains('body.ks-page-home #ksHomePage .ks-home-price-value { font-family: inherit; }') -and
            [regex]::IsMatch($top, '(?s)#ksHomePage \.ks-grid-card \.new-price\.ks-home-price-value--current \{\s*color: var\(--black, #121212\);\s*font-size: 20px;\s*line-height: 22px;\s*font-weight: 500;') -and
            [regex]::IsMatch($top, '(?s)#ksHomePage \.ks-home-deals \.ks-deal-card \.new-price\.ks-home-price-value--current \{\s*font-size: 28px;\s*line-height: 32px;\s*font-weight: 600;'))
}
function Test-MediaScopes([string]$c) {
    # ogni @media del blocco vale solo da 768 px in su: il telefono resta quello della prima tranche
    $b = Get-Block $c
    $medias = [regex]::Matches($b, '@media[^{]*')
    if ($medias.Count -ne 3) { return $false }
    foreach ($m in $medias) {
        if ($m.Value -notmatch '^@media \(min-width: (768|1200)px\)(?: and \(max-width: 1199\.98px\))?\s*$') { return $false }
    }
    return $true
}
function Test-DepartmentsCss([string]$c) {
    $b = Get-Block $c
    $d = Get-MediaBody $b '@media (min-width: 768px) {'
    $d1200 = Get-MediaBody $b '@media (min-width: 1200px) {'
    $gridRule = [regex]::Match($d, '(?s)(body\.ks-page-home[^{]*\.ks-home-category-grid) \{\s*grid-template-columns: repeat\(3, minmax\(0, 1fr\)\);').Groups[1].Value
    return ($gridRule -ne '' -and -not $gridRule.Contains('#') -and
            [regex]::IsMatch($d1200, 'ks-home-category-grid \{ grid-template-columns: repeat\(4, minmax\(0, 1fr\)\); \}') -and
            [regex]::IsMatch($d, '(?s)\.ks-home-category-card \{\s*flex-direction: row;\s*justify-content: flex-start;\s*gap: 12px;\s*min-height: 64px;') -and
            [regex]::IsMatch($d, '\.ks-home-categories \.ks-home-category-link \{ display: none; \}') -and
            [regex]::IsMatch($d, '(?s)#ksHomePage \.ks-home-direct-category-list \{\s*display: flex;\s*flex-wrap: wrap;') -and
            [regex]::IsMatch($d, '(?s)#ksHomePage \.ks-home-direct-category-link \{\s*display: inline-flex;[^}]*min-height: 44px;') -and
            [regex]::IsMatch($d, '(?s)#ksHomePage \.ks-home-direct-categories \{ padding-top: 0;'))
}
function Test-DealSlotsCss([string]$c) {
    $b = Get-Block $c
    $d = Get-MediaBody $b '@media (min-width: 768px) {'
    return ($d.Contains('.ks-home-deals .ks-deal-thumbs { grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 6px; margin: 8px 0 12px; }') -and
            $d.Contains('.ks-home-deals .ks-deal-slot--price .ks-home-price-stack { min-height: 84px; }') -and
            $d.Contains('.ks-deal-price-amount-slot { min-height: 40px; }') -and $d.Contains('.ks-deal-price-tier-slot { min-height: 34px; }') -and
            $d.Contains('.ks-home-deals .ks-deal-slot--availability { min-height: 40px; }') -and $d.Contains('.ks-deal-slot--gallery { min-height: 64px; }') -and
            $d.Contains('.ks-home-deals .ks-deal-thumbs .image-swap { height: 44px; }'))
}
function Test-TabletRail([string]$c) {
    $b = Get-Block $c
    $t = Get-MediaBody $b '@media (min-width: 768px) and (max-width: 1199.98px) {'
    return ([regex]::IsMatch($t, '(?s)#ksHomePage \.ks-home-product-grid \{\s*display: grid;\s*grid-auto-flow: column;\s*grid-template-columns: none;\s*grid-auto-columns: calc\(\(100% - 32px\) / 3\.2\);') -and
            $t.Contains('overflow-x: auto;') -and $t.Contains('scroll-snap-type: x mandatory;') -and $t.Contains('::-webkit-scrollbar { display: none; }') -and $t.Contains('scroll-snap-align: start;'))
}
function Test-Names([string]$c) {
    return ((Get-Block $c) -notmatch '(?i)onsus|taikun|prezzoforte|stay ?on|ikea|bytecno')
}
function Test-Buster([string]$m) {
    return $m.Contains('ThemeManager.Asset("css/theme-overrides.css") & "?v=20261114-home-vetrina2a"')
}

Assert-Source (Test-SectionOrder $aspx) 'S01_OFFERS_BEFORE_NEW_ARRIVALS_AND_THE_REST_OF_THE_ORDER_HOLDS'
Assert-Source (Test-BestSection $aspx $vb) 'S02_BEST_SELLERS_ONE_ROW_WITH_ARROWS_ONLY_BUYABLE_NET_QUANTITY'
Assert-Source (Test-NetQuantityEquivalence $vb) 'S11_BEST_SELLER_FILTER_USES_THE_SAME_STOCK_EXPRESSIONS_THE_CARD_READS'
Assert-Source (Test-PriceMarkup $vb) 'S03_PRICE_COLOUR_AND_WEIGHT_COME_FROM_THE_STYLESHEET'
Assert-Source (Test-PriceCss $css) 'S04_PRICES_LIKE_THE_CATALOG_AND_THE_SAME_FONT_AS_THE_TEXT'
Assert-Source (Test-MediaScopes $css) 'S05_THE_BLOCK_NEVER_TOUCHES_THE_PHONE_LAYOUT'
Assert-Source (Test-DepartmentsCss $css) 'S06_DEPARTMENTS_COMPACT_AND_CATEGORIES_AS_CHIPS_WITH_44PX_TARGETS'
Assert-Source (Test-DealSlotsCss $css) 'S07_DEAL_CARD_RESERVES_ONLY_THE_SPACE_IT_NEEDS'
Assert-Source (Test-TabletRail $css) 'S08_TABLET_PRODUCT_GRID_IS_A_SNAP_RAIL'
Assert-Source (Test-Names $css) 'S09_NO_TEMPLATE_CUSTOMER_OR_COMPETITOR_NAME_IN_THE_NEW_CSS'
Assert-Source (Test-Buster $master) 'S10_CSS_CACHE_BUSTER_UPDATED'

# ---- mutazioni -----------------------------------------------------------------
$m = Mutate-Text $aspx '<section id="HomeOffersSection"' '<section id="HomeOffersSectionX"' 'M01'
Assert-Detected (Test-SectionOrder $m) 'M01_OFFERS_SECTION_LOST'
# offerte dopo novita: spostamento inverso del blocco
$offStart = $aspx.IndexOf('    <section id="HomeOffersSection"'); $offEnd = $aspx.IndexOf('    <section id="HomeFeaturedProductsSection"')
$block = $aspx.Substring($offStart, $offEnd - $offStart)
$swapped = $aspx.Remove($offStart, $offEnd - $offStart)
$swapped = $swapped.Insert($swapped.IndexOf('    <section id="HomeWidePromoSection"'), $block)
Assert-Detected (Test-SectionOrder $swapped) 'M02_OFFERS_BACK_AFTER_NEW_ARRIVALS'
$m = Mutate-Text $aspx 'data-grid="1" data-grid-mobile="1"' 'data-grid="2" data-grid-mobile="1"' 'M03'
Assert-Detected (Test-BestSection $m $vb) 'M03_BEST_SELLERS_BACK_TO_TWO_ROWS'
$m = Mutate-Text $aspx 'data-preview="4" data-tablet="3"' 'data-preview="5" data-tablet="3"' 'M04'
Assert-Detected (Test-BestSection $m $vb) 'M04_BEST_SELLERS_FIVE_COLUMNS_UNEVEN_AGAIN'
$m = Mutate-Text $vb '(" & StockWhereClause() & "-" & ReservedWhereClause() & ")>=1"' '(" & StockWhereClause() & ")>=1"' 'M05'
Assert-Detected (Test-BestSection $aspx $m) 'M05_BEST_SELLERS_IGNORE_COMMITTED_STOCK'
$m = Mutate-Text $vb 'COALESCE(ca.CommercialScore,0)>0 AND (' 'COALESCE(ca.CommercialScore,0)>0 OR (' 'M06'
Assert-Detected (Test-BestSection $aspx $m) 'M06_BEST_SELLERS_AVAILABILITY_OR_INSTEAD_OF_AND'
$m = Mutate-Text $vb '"new-price body-md-2 fw-medium mb-0"' '"new-price body-md-2 fw-medium text-primary mb-0"' 'M07'
Assert-Detected (Test-PriceMarkup $m) 'M07_UTILITY_COLOUR_OVERRIDES_THE_STYLESHEET_AGAIN'
$m = Mutate-Text $vb '"new-price h4 fw-semibold text-primary mb-0"' '"new-price h4 fw-normal text-primary mb-0"' 'M08'
Assert-Detected (Test-PriceMarkup $m) 'M08_DEAL_PRICE_WEIGHT_BACK_TO_NORMAL'
$m = Mutate-Text $css 'body.ks-page-home #ksHomePage .ks-home-price-value { font-family: inherit; }' '' 'M09'
Assert-Detected (Test-PriceCss $m) 'M09_PRICE_FONT_FALLS_BACK_TO_A_SERIF_AGAIN'
$m = Mutate-Text $css '  color: var(--black, #121212);
  font-size: 20px;' '  color: #ff3b30;
  font-size: 20px;' 'M10'
Assert-Detected (Test-PriceCss $m) 'M10_PRICE_COLOUR_NOT_LIKE_THE_CATALOG'
$m = Mutate-Text $css '@media (min-width: 1200px) {
  body.ks-page-home .ks-home-categories .ks-home-category-grid' '@media (max-width: 1199.98px) {
  body.ks-page-home .ks-home-categories .ks-home-category-grid' 'M11'
Assert-Detected (Test-MediaScopes $m) 'M11_BLOCK_WOULD_APPLY_BELOW_THE_TABLET_WIDTH'
$m = Mutate-Text $css 'body.ks-page-home .ks-home-categories .ks-home-category-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));' 'body.ks-page-home #ksHomePage .ks-home-category-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));' 'M12'
Assert-Detected (Test-DepartmentsCss $m) 'M12_FEW_DEPARTMENTS_RULES_WOULD_LOSE_TO_THE_NEW_GRID'
$m = Mutate-Text $css '.ks-home-categories .ks-home-category-link { display: none; }' '.ks-home-categories .ks-home-category-link { display: inline; }' 'M13'
Assert-Detected (Test-DepartmentsCss $m) 'M13_REPEATED_TILE_TEXT_COMES_BACK'
$m = Mutate-Text $css '    display: inline-flex;
    align-items: center;
    gap: 8px;
    width: auto;
    height: auto;
    min-height: 44px;' '    display: inline-flex;
    align-items: center;
    gap: 8px;
    width: auto;
    height: auto;
    min-height: 30px;' 'M14'
Assert-Detected (Test-DepartmentsCss $m) 'M14_CATEGORY_CHIP_BELOW_THE_44PX_TARGET'
$m = Mutate-Text $css '#ksHomePage .ks-home-direct-categories { padding-top: 0; padding-bottom: 22px; }' '#ksHomePage .ks-home-direct-categories { padding-bottom: 22px; }' 'M15'
Assert-Detected (Test-DepartmentsCss $m) 'M15_GAP_BETWEEN_DEPARTMENTS_AND_CATEGORIES_COMES_BACK'
$m = Mutate-Text $css '.ks-home-deals .ks-deal-slot--availability { min-height: 40px; }' '.ks-home-deals .ks-deal-slot--availability { min-height: 76px; }' 'M16'
Assert-Detected (Test-DealSlotsCss $m) 'M16_DEAL_AVAILABILITY_SPACE_RESERVED_AGAIN'
$m = Mutate-Text $css '.ks-home-deals .ks-deal-slot--price .ks-home-price-stack { min-height: 84px; }' '.ks-home-deals .ks-deal-slot--price .ks-home-price-stack { min-height: 134px; }' 'M17'
Assert-Detected (Test-DealSlotsCss $m) 'M17_DEAL_PRICE_SPACE_RESERVED_AGAIN'
$m = Mutate-Text $css 'grid-auto-columns: calc((100% - 32px) / 3.2);' 'grid-auto-columns: calc((100% - 32px) / 3);' 'M18'
Assert-Detected (Test-TabletRail $m) 'M18_TABLET_RAIL_WITHOUT_THE_PEEKING_NEXT_CARD'
$m = Mutate-Text $css 'scroll-snap-type: x mandatory;
    scrollbar-width: none;
    -webkit-overflow-scrolling: touch;
  }
  body.ks-page-home #ksHomePage .ks-home-product-grid::-webkit-scrollbar { display: none; }
  body.ks-page-home #ksHomePage .ks-home-product-grid > * {
    min-width: 0;
    scroll-snap-align: start;
  }
}' 'scrollbar-width: none;
    -webkit-overflow-scrolling: touch;
  }
  body.ks-page-home #ksHomePage .ks-home-product-grid::-webkit-scrollbar { display: none; }
  body.ks-page-home #ksHomePage .ks-home-product-grid > * {
    min-width: 0;
  }
}' 'M19'
Assert-Detected (Test-TabletRail $m) 'M19_TABLET_RAIL_WITHOUT_SNAP'
Assert-Detected (Test-Names ($css + "`n/* KS-A04-HOME-VETRINA-2A extra: copiato da ONSUS */`n")) 'M20_TEMPLATE_NAME_IN_THE_NEW_CSS'
$m = Mutate-Text $master 'v=20261114-home-vetrina2a' 'v=20261114-home-vetrina1a' 'M21'
Assert-Detected (Test-Buster $m) 'M21_CSS_CACHE_BUSTER_NOT_UPDATED'
$m = Mutate-Text $vb 'Return "COALESCE(stk.Impegnata, COALESCE(v.Impegnata,0))"' 'Return "stk.Impegnata"' 'M22'
Assert-Detected (Test-NetQuantityEquivalence $m) 'M22_COMMITTED_QUANTITY_CAN_BE_NULL_IN_THE_FILTER'
$m = Mutate-Text $vb 'sql.Append(reservedSql).Append(" AS Impegnata, ")' 'sql.Append("0").Append(" AS Impegnata, ")' 'M23'
Assert-Detected (Test-NetQuantityEquivalence $m) 'M23_CARD_READS_A_DIFFERENT_COMMITTED_QUANTITY_THAN_THE_FILTER'
$m = Mutate-Text $css '.ks-home-deals .ks-deal-thumbs .image-swap { height: 44px; }' '.ks-home-deals .ks-deal-thumbs .image-swap { height: 40px; }' 'M24'
Assert-Detected (Test-DealSlotsCss $m) 'M24_DEAL_THUMBNAIL_BELOW_THE_44PX_TARGET'
Write-Output 'HOME_VETRINA_DESKTOP_OK'
