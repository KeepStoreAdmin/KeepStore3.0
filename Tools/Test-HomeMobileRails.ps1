[CmdletBinding()]
param()

# KS-A04-HOME-VETRINA-1A - HOME piu corta su telefono: rail orizzontali e scheda offerta compatta. Desktop invariato.
# Controllo statico del CSS, del carosello e del markup con mutazioni (ogni regola, rotta apposta, deve far fallire il controllo).
# La misura nel browser (altezza della pagina a 320/360/390/430/767 px, assenza di scorrimento orizzontale della pagina,
# desktop 1440 con le stesse altezze di prima) e descritta nel Masterplan.
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
function Get-RailBlock([string]$css) {
    $a = $css.IndexOf('/* ===== KS-A04-HOME-VETRINA-1A')
    if ($a -lt 0) { throw 'RAIL_BLOCK_MISSING' }
    # il blocco della seconda tranche (desktop e tablet) viene dopo: qui conta solo quello del telefono
    $z = $css.IndexOf('/* ===== KS-A04-HOME-VETRINA-2A', $a)
    if ($z -gt $a) { return $css.Substring($a, $z - $a) }
    return $css.Substring($a)
}

# ---- controlli (usati sul sorgente reale e su quello mutato) ------------------
function Test-ScopedToPhones([string]$css) {
    $block = Get-RailBlock $css
    $open = $block.IndexOf('@media (max-width: 767.98px) {')
    if ($open -lt 0) { return $false }
    # tutto il blocco sta dentro la media query: dopo la sua apertura la parentesi graffa si chiude solo alla fine del file
    $depth = 0; $closedAt = -1
    for ($i = $open; $i -lt $block.Length; $i++) {
        if ($block[$i] -eq '{') { $depth++ } elseif ($block[$i] -eq '}') { $depth--; if ($depth -eq 0) { $closedAt = $i; break } }
    }
    $beforeMedia = $block.Substring(0, $open)
    $afterMedia = if ($closedAt -ge 0) { $block.Substring($closedAt + 1).Trim() } else { 'x' }
    return ($closedAt -gt 0 -and $beforeMedia -notmatch '\{' -and $afterMedia.Length -eq 0)
}
function Test-Rails([string]$css) {
    $b = Get-RailBlock $css
    return ($b -match '(?s)#ksHomePage \.ks-home-category-grid \{[^}]*display: flex;[^}]*flex-wrap: nowrap;[^}]*overflow-x: auto;[^}]*scroll-snap-type: x proximity;' -and
            $b -match '(?s)#ksHomePage \.ks-home-category-card \{[^}]*flex: 0 0 112px;[^}]*min-height: 0;[^}]*scroll-snap-align: start;' -and
            $b -match '#ksHomePage \.ks-home-category-link \{ display: none; \}' -and
            $b -match '(?s)#ksHomePage \.ks-home-direct-category-list \{[^}]*display: flex;[^}]*overflow-x: auto;' -and
            $b -match '(?s)#ksHomePage \.ks-home-direct-category-list > li \{[^}]*flex: 0 0 188px;' -and
            $b -match '(?s)#ksHomePage \.ks-home-product-grid \{[^}]*grid-auto-flow: column;[^}]*grid-template-columns: none;[^}]*grid-auto-columns: min\(64%, 236px\);[^}]*overflow-x: auto;[^}]*scroll-snap-type: x mandatory;' -and
            $b -match '(?s)#ksHomePage \.ks-home-collection-grid \{[^}]*display: flex;[^}]*overflow-x: auto;' -and
            $b -match '(?s)#ksHomePage \.ks-home-collection-grid > \* \{[^}]*flex: 0 0 min\(78%, 280px\);')
}
function Test-RailSpecificity([string]$css) {
    $b = Get-RailBlock $css
    $selectors = [regex]::Matches($b, '(?m)^\s{2}(body\.ks-page-home[^{,]*)[,{]') | ForEach-Object { $_.Groups[1].Value }
    if (@($selectors).Count -lt 12) { return $false }
    foreach ($s in $selectors) { if ($s -notmatch '^body\.ks-page-home #ksHomePage ') { return $false } }
    return $true
}
function Test-ScrollbarsAndTouch([string]$css) {
    $b = Get-RailBlock $css
    return (([regex]::Matches($b, 'scrollbar-width: none;')).Count -eq 4 -and ([regex]::Matches($b, '::-webkit-scrollbar \{ display: none; \}')).Count -eq 4 -and
            ([regex]::Matches($b, '-webkit-overflow-scrolling: touch;')).Count -eq 4)
}
function Test-DealCard([string]$css) {
    $b = Get-RailBlock $css
    $needed = @('ks-deal-slot--title', 'ks-deal-slot--title h6', 'ks-deal-card .name-product', 'ks-deal-slot--price .ks-home-price-stack', 'ks-deal-price-amount-slot',
        'ks-deal-price-tier-slot', 'ks-deal-slot--availability', 'ks-deal-slot--savings', 'ks-deal-slot--countdown', 'ks-deal-slot--progress')
    foreach ($n in $needed) { if ($b -notmatch ('\.ks-home-deals \.' + [regex]::Escape($n) + '(?:,|\s*\{)')) { return $false } }
    return ($b -match '#ksHomePage \.ks-home-deals \.ks-deal-slot--gallery \{ display: none; \}' -and $b -match '(?s)ks-deal-slot--progress \{\s*min-height: 0;\s*\}')
}
function Test-CarouselRows([string]$js) {
    $decl = $js -match 'var gridRowsMobile = \$this\.data\("grid-mobile"\) \|\| gridRows;'
    $base = $js -match '(?s)slidesPerGroup: perGroup,\s+grid: \{\s+rows: gridRowsMobile,'
    $breakpoints = ([regex]::Matches($js, 'rows: gridRows,')).Count -ge 4
    return ($decl -and $base -and $breakpoints)
}
function Test-BestSwiper([string]$aspx) {
    return ($aspx -match 'data-pagination-lg="4" data-grid="1" data-grid-mobile="1">')
}
function Test-Busters([string]$master) {
    return ($master -match 'theme-overrides\.css"\) & "\?v=(?:20261114-(?:home-vetrina2a|deadcode-c1a)|20261115-(?:home-cards|palette-aa|focus-fc)1a)"' -and $master -match 'js/carousel\.js"\) %>\?v=20261114-home-vetrina1a')
}

$css = Read-Repo 'Public\assets\keepstore\css\theme-overrides.css'
$js = Read-Repo 'Public\assets\keepstore\js\carousel.js'
$aspx = Read-Repo 'Default.aspx'
$master = Read-Repo 'Page.master'
Assert-Source (Test-ScopedToPhones $css) 'S01_THE_WHOLE_BLOCK_IS_INSIDE_THE_PHONE_MEDIA_QUERY'
Assert-Source (Test-Rails $css) 'S02_DEPARTMENTS_CATEGORIES_PRODUCTS_AND_COLLECTION_ARE_SNAP_RAILS'
Assert-Source (Test-RailSpecificity $css) 'S03_EVERY_RULE_OUTRANKS_THE_PAGE_INLINE_STYLES_THROUGH_THE_PAGE_ID'
Assert-Source (Test-ScrollbarsAndTouch $css) 'S04_RAILS_HIDE_SCROLLBARS_AND_KEEP_TOUCH_MOMENTUM'
Assert-Source (Test-DealCard $css) 'S05_OFFER_CARD_WITHOUT_DUPLICATE_THUMBNAILS_OR_RESERVED_SPACE'
Assert-Source (Test-CarouselRows $js) 'S06_CAROUSEL_ACCEPTS_A_MOBILE_ONLY_GRID_ROWS_VALUE'
Assert-Source (Test-BestSwiper $aspx) 'S07_BEST_SELLER_SWIPER_USES_ONE_ROW_ON_PHONES'
Assert-Source (Test-Busters $master) 'S08_CACHE_BUSTERS_UPDATED'
$noNames = $true
if ((Get-RailBlock $css) -match '(?i)onsus|taikun') { $noNames = $false }
Assert-Source $noNames 'S09_NO_TEMPLATE_OR_CUSTOMER_NAME_IN_THE_NEW_CSS'

# ---- mutazioni -----------------------------------------------------------------
$m = Mutate-Text $css '@media (max-width: 767.98px) {
  /* Reparti: una fila scorrevole' '@media (max-width: 1199.98px) {
  /* Reparti: una fila scorrevole' 'M01'
Assert-Detected (Test-ScopedToPhones $m -and $true) 'M01_RAILS_WOULD_ALSO_APPLY_ON_TABLET_AND_DESKTOP'
$m = Mutate-Text $css '  body.ks-page-home #ksHomePage .ks-home-category-card {
    flex: 0 0 112px;' '  body.ks-page-home #ksHomePage .ks-home-category-card {
    flex: 1 1 112px;' 'M02'
Assert-Detected (Test-Rails $m) 'M02_DEPARTMENT_TILES_SHRINK_INSTEAD_OF_SCROLLING'
$m = Mutate-Text $css 'grid-auto-columns: min(64%, 236px);' 'grid-auto-columns: 1fr;' 'M03'
Assert-Detected (Test-Rails $m) 'M03_PRODUCT_RAIL_WITHOUT_PEEKING_NEXT_CARD'
$m = Mutate-Text $css 'scroll-snap-type: x mandatory;' 'scroll-snap-type: none;' 'M04'
Assert-Detected (Test-Rails $m) 'M04_PRODUCT_RAIL_WITHOUT_SNAP'
$m = Mutate-Text $css '#ksHomePage .ks-home-category-link { display: none; }' '#ksHomePage .ks-home-category-link { display: inline; }' 'M05'
Assert-Detected (Test-Rails $m) 'M05_REPEATED_SCOPRI_REPARTO_TEXT_BACK'
$m = $css.Replace('body.ks-page-home #ksHomePage .ks-home-direct-category-list {', 'body.ks-page-home .ks-home-direct-category-list {')
Assert-Detected (Test-RailSpecificity $m) 'M06_RULE_LOSES_TO_THE_INLINE_STYLES'
$m = Mutate-Text $css '  body.ks-page-home #ksHomePage .ks-home-product-grid::-webkit-scrollbar { display: none; }' '' 'M07'
Assert-Detected (Test-ScrollbarsAndTouch $m) 'M07_SCROLLBAR_SHOWN_ON_A_RAIL'
$m = Mutate-Text $css '#ksHomePage .ks-home-deals .ks-deal-slot--gallery { display: none; }' '' 'M08'
Assert-Detected (Test-DealCard $m) 'M08_DUPLICATE_THUMBNAILS_BACK_ON_PHONES'
$m = Mutate-Text $css '  body.ks-page-home #ksHomePage .ks-home-deals .ks-deal-slot--availability,
' '  body.ks-page-home #ksHomePage .ks-home-deals .ks-deal-slot--availability-x,
' 'M09'
Assert-Detected (Test-DealCard $m) 'M09_RESERVED_AVAILABILITY_SPACE_BACK'
$m = Mutate-Text $js 'rows: gridRowsMobile,' 'rows: gridRows,' 'M10'
Assert-Detected (Test-CarouselRows $m) 'M10_PHONES_KEEP_TWO_ROWS'
$m = Mutate-Text $js 'var gridRowsMobile = $this.data("grid-mobile") || gridRows;' 'var gridRowsMobile = 1;' 'M11'
Assert-Detected (Test-CarouselRows $m) 'M11_EVERY_SWIPER_FORCED_TO_ONE_ROW_ON_PHONES'
$m = Mutate-Text $aspx ' data-grid-mobile="1">' '>' 'M12'
Assert-Detected (Test-BestSwiper $m) 'M12_BEST_SELLER_KEEPS_TWO_ROWS_ON_PHONES'
$m = Mutate-Text $master 'js/carousel.js") %>?v=20261114-home-vetrina1a' 'js/carousel.js") %>' 'M13'
Assert-Detected (Test-Busters $m) 'M13_CAROUSEL_CACHE_BUSTER_MISSING'

Write-Output 'HOME_MOBILE_RAILS_OK'
