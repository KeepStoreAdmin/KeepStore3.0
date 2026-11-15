[CmdletBinding()]
param()

# KS-A04-PALETTE-AA-1A - rosso di marca e grigi del tema a contrasto AA su tutto il sito.
# Oracolo COMPORTAMENTALE: i veri fogli di stile (nell'ordine di Page.master e delle pagine) sono caricati in Edge su frammenti del MARKUP REALE (estratti dai file del sito,
# con le ancore verificate sul sorgente); il test legge i colori COMPUTATI (cascata, specificita, variabili del tema, stati :hover forzati via CDP) e calcola il contrasto W3C.
# Regole: ogni bersaglio deve esistere (zero elementi = FALLIMENTO); un caso NON CALCOLABILE (opacita < 1, immagine di sfondo o sfondo non risolto) FALLISCE salvo eccezione
# dichiarata (componente disabilitato); il feedback hover dei pulsanti deve cambiare il fondo. Senza Edge: NON ESEGUITO (uscita 2), mai PASS.
# Guardia statica: nessun letterale rosso o grigio sotto AA come colore/fondo/bordo/variabile fuori da un fallback var(--x, #...) nei fogli e negli stili in linea elencati.
# Non certifica l'intero sito: misura i componenti e gli stati elencati (pagine con login, checkout a piu passi e focus a bassa alfa restano fuori; vedi il Masterplan).
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI. Le mutazioni lavorano su copie temporanee, mai sulla copia di lavoro.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$cssDir = Join-Path $repoRoot 'Public/assets/keepstore/css'
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$relativePath) { return (Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)))) }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $old = Norm $old; $new = Norm $new
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}

# --- Contrasto WCAG (formula W3C, double, senza arrotondare prima del confronto) -----------------------------------------------------
function Lin([double]$c) { $c = $c / 255.0; if ($c -le 0.04045) { return $c / 12.92 }; return [Math]::Pow(($c + 0.055) / 1.055, 2.4) }
function Lum([double[]]$rgb) { return (0.2126 * (Lin $rgb[0]) + 0.7152 * (Lin $rgb[1]) + 0.0722 * (Lin $rgb[2])) }
function Parse-Rgb([string]$s) {
    $m = [regex]::Match($s, 'rgba?\(\s*([0-9.]+)[ ,]+([0-9.]+)[ ,]+([0-9.]+)')
    if (-not $m.Success) { throw ('COLOR_NOT_PARSED=' + $s) }
    return [double[]]@([double]$m.Groups[1].Value, [double]$m.Groups[2].Value, [double]$m.Groups[3].Value)
}
function Contrast([string]$fg, [string]$bg) {
    $l1 = Lum (Parse-Rgb $fg); $l2 = Lum (Parse-Rgb $bg)
    return ((([Math]::Max($l1, $l2)) + 0.05) / (([Math]::Min($l1, $l2)) + 0.05))
}
Assert-Source (((Contrast 'rgb(216, 0, 39)' 'rgb(255, 255, 255)') -ge 4.5) -and ((Contrast 'rgb(255, 61, 61)' 'rgb(255, 255, 255)') -lt 4.5) -and ((Contrast 'rgb(115, 120, 125)' 'rgb(255, 255, 255)') -lt 4.5) -and ((Contrast 'rgb(102, 102, 102)' 'rgb(255, 255, 255)') -ge 4.5) -and ((Contrast 'rgb(51, 62, 72)' 'rgb(216, 0, 39)') -lt 4.5)) 'CONTRAST_HELPER_KNOWS_THE_OLD_PALETTE_FAILS_AND_THE_NEW_ONE_PASSES'

# --- Sorgenti reali e ancore del markup ---------------------------------------------------------------------------------------------
$styles = Read-Repo 'Public/assets/keepstore/css/styles.css'
$header = Read-Repo 'Public/ui/controls/SiteHeader.ascx'
$miniCart = Read-Repo 'Public/ui/controls/MiniCart.ascx'
$docDetail = Read-Repo 'documentidettaglio.aspx'
$orderAspx = Read-Repo 'ordine.aspx'
$catalogAspx = Read-Repo 'articoli.aspx'
$homeVb = Read-Repo 'Default.aspx.vb'
$pdpAspx = Read-Repo 'articolo.aspx'
$recentJs = Read-Repo 'Public/assets/keepstore/js/keepstore-recently-viewed.js'
$master = Read-Repo 'Page.master'

$navMatch = [regex]::Match($header, '(?s)<nav class="main-nav-menu">.*?</nav>')
$orderStyle = [regex]::Match($orderAspx, '(?s)<style>(.*?)</style>')
Assert-Source ($navMatch.Success -and $navMatch.Value.Contains('<li class="nav-item active pst-unset"><a href="Default.aspx" class="item-link link body-md-2"><span>Home</span></a></li>') -and $navMatch.Value.Contains('<a href="articoli.aspx?inpromo=1" class="item-link body-md-2"><span>Offerte</span></a>')) 'ANCHOR_MAIN_NAV_FROM_SITEHEADER'
Assert-Source ($header.Contains('<div class="header-bottom bg-gray-5 d-none d-xl-block">') -and $miniCart.Contains('<a class="tf-btn btn-fill w-100" href="articoli.aspx">Vai al catalogo</a>') -and $miniCart.Contains('<div class="minicart-empty text-center">')) 'ANCHOR_HEADER_BAR_AND_EMPTY_MINICART'
Assert-Source ($docDetail.Contains('<button type="button" class="tf-btn ks-print-order" data-action="print-order">Stampa ordine</button>') -and $docDetail.Contains('<a href="documenti.aspx?t=4" class="tf-btn btn-gray">Vai ai miei ordini</a>')) 'ANCHOR_ORDER_CONFIRMATION_BUTTONS'
Assert-Source ($orderStyle.Success -and $orderStyle.Groups[1].Value.Contains('.ks-order-actions .ks-order-btn-primary') -and $orderAspx.Contains('class="tf-btn ks-order-btn-primary"')) 'ANCHOR_ORDER_PAGE_INLINE_STYLE_AND_BUTTON'
Assert-Source ($catalogAspx.Contains('CssClass="tf-btn btn-fill ks-multi-footer__cta"') -and $homeVb.Contains("<div class='box-sale-wrap top-0 start-0 pst-default z-5'><p class='small-text'>Promo</p><p class='title-sidebar-2'>") -and $homeVb.Contains("<p class='box-sale-tag'>Risparmi ")) 'ANCHOR_CATALOG_MULTI_CTA_AND_HOME_BADGES'
Assert-Source ($pdpAspx.Contains('class="tf-btn text-white js-ks-cart-context"') -and $pdpAspx.Contains('<div class="product-delivery">') -and $recentJs.Contains('class="tf-btn btn-line w-100 mt-2 ks-recent-history-link"')) 'ANCHOR_PDP_BUY_BUTTON_AND_RECENT_BTN_LINE'
function Test-Busters([string]$m) {
    return ($m -match 'css/styles\.css"\) & "\?v=(?:20261115-palette-aa1a|20261115-focus-fc1a)"' -and $m -match 'css/theme-overrides\.css"\) & "\?v=(?:20261115-palette-aa1a|20261115-focus-fc1a)"')
}
Assert-Source (Test-Busters $master) 'MASTER_LOADS_STYLES_AND_THEME_OVERRIDES_WITH_THE_NEW_BUSTER'
$sheetOrder = @('bootstrap.min.css', 'keepstore.css', 'keepstore-overrides.css', 'account-ui.css', 'documents-ui.css', 'auth-ui.css', 'ks-ui.css', 'nice-select.css', 'swiper-bundle.min.css', 'animate.css', 'styles.css', 'minicart-ui.css',
    'catalog-ui.css', 'catalog-filters-ui.css', 'catalog-product-flow.css', 'product-ui.css', 'order-ui.css', 'cart-ui.css', 'theme-overrides.css')
foreach ($n in $sheetOrder) { if (-not (Test-Path -LiteralPath (Join-Path $cssDir $n))) { throw ('STYLESHEET_MISSING=' + $n) } }

# --- Pagine di prova ------------------------------------------------------------------------------------------------------------------
function Build-Nav() {
    $n = $navMatch.Value
    $n = $n.Replace('<a href="Default.aspx" class="item-link link body-md-2">', '<a href="Default.aspx" class="item-link link body-md-2" data-probe="nav-home-active">')
    $n = $n.Replace('<a href="articoli.aspx?inpromo=1" class="item-link body-md-2">', '<a href="articoli.aspx?inpromo=1" class="item-link body-md-2" data-probe="nav-offerte">')
    return $n
}
$pixel = 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
function Body-Generic() {
    $nav = Build-Nav
    return @"
<div class="header-bottom bg-gray-5 d-none d-xl-block"><div class="container relative"><div class="row"><div class="col-xl-9 col-12"><div class="header-bt-left ks-header-nav-shell">$nav</div></div></div></div></div>
<div id="ksMiniCartCanvas"><div class="offcanvas-body"><div class="minicart-empty text-center"><a class="tf-btn btn-fill w-100" href="articoli.aspx" data-probe="minicart-cta">Vai al catalogo</a></div></div></div>
<div class="ks-confirm-actions"><button type="button" class="tf-btn ks-print-order" data-action="print-order" data-probe="print-order">Stampa ordine</button><a href="documenti.aspx?t=4" class="tf-btn btn-gray" data-probe="btn-gray">Vai ai miei ordini</a></div>
<section class="ks-myaccount"><div class="ks-quick-links"><a class="tf-btn btn-fill" href="documenti.aspx?t=4" data-probe="account-btn-fill">I miei ordini</a><button type="button" class="tf-btn" data-probe="plain-button">Salva</button><a href="#" class="tf-btn btn-small d-inline-flex" data-probe="plain-small">Filtra</a></div></section>
<div style="background:#fff"><a class="tf-btn btn-line w-100 mt-2 ks-recent-history-link" href="#" data-probe="btn-line">Vedi prodotto</a></div>
<section id="ksCatalogPage"><div class="ks-multi-footer"><input type="submit" class="tf-btn btn-fill ks-multi-footer__cta" value="Aggiungi selezionati al carrello" data-probe="multi-cta" /><input type="submit" class="tf-btn btn-fill ks-multi-footer__cta" value="Aggiungi selezionati al carrello" disabled="disabled" data-probe="multi-cta-disabled" data-exempt="disabled" /></div></section>
<div class="ks-order-actions"><a class="tf-btn ks-order-btn-primary" href="#" data-probe="order-primary">Procedi</a><a class="tf-btn ks-order-btn-secondary" href="#" data-probe="order-secondary">Annulla</a></div>
<div class="ks-product-page"><div class="ks-pdp-buybox-sticky"><div class="product-delivery"><span class="new-price" data-probe="pdp-price">24,40</span></div><div class="product-box-btn"><button type="submit" class="tf-btn text-white js-ks-cart-context" data-probe="pdp-buy">Acquista</button></div></div></div>
<div style="background:#fff"><a class="text-primary" href="#" data-probe="tp-white">Registrati</a><p class="body-text-3 text-main-2" data-probe="tm2-white">Prezzi visualizzati IVA inclusa</p></div>
<div style="background:#fafafa"><a class="text-primary" href="#" data-probe="tp-fafafa">081-771.83.26</a></div>
<div style="background:#f5f5f5"><a class="text-primary" href="#" data-probe="tp-f5f5f5">Esplora</a><p class="body-text-3 text-main-2" data-probe="tm2-f5f5f5">Esplora i settori del catalogo</p></div>
<div style="background:#2c3135"><button type="button" class="subscribe-button tf-btn btn-large hover-shine"><span class="body-md-2 fw-semibold text-white" data-probe="subscribe">Subscribe</span></button></div>
"@
}
function Body-Home() {
    return @"
<main class="ks-home-main">
  <div class="ks-home-deals"><div class="ks-deal-card"><p class='box-sale-tag' data-probe="home-sale-tag-deal">Risparmi 1,01</p></div></div>
  <div class="ks-grid-card">
    <div class='box-sale-wrap top-0 start-0 pst-default z-5'><p class='small-text' data-probe="home-badge-small">Promo</p><p class='title-sidebar-2' data-probe="home-badge-title">-17%</p></div>
    <p class='box-sale-tag' data-probe="home-sale-tag-grid">Risparmi 1,01</p>
    <p class="caption text-main-2 font-2" data-probe="home-category">Per Registratori di Cassa</p>
    <span class="old-price price-text text-main-2" data-probe="home-old">24,99</span>
    <span class="new-price price-text" data-probe="home-new-price">19,99</span>
  </div>
  <div class="ks-home-collection-card"><em data-probe="home-collection">Scopri il reparto</em></div>
  <a class="ks-home-category-link" href="#" data-probe="home-cat-link">Vedi tutto</a>
  <!-- Il pannello reale e rgba(8,10,16,.72) sopra una foto: non calcolabile. Si prova il CASO PEGGIORE per un testo chiaro, la foto bianca: 0,72*(8,10,16)+0,28*255 = rgb(77,79,83) = #4d4f53. -->
  <div class="ks-home-hero-panel"><div class="content ks-home-hero-content" style="background:#4d4f53"><p class="caption fw-semibold ks-home-hero-eyebrow mb-0" data-probe="home-hero-eyebrow">In evidenza</p></div></div>
</main>
"@
}
function Write-Doc([string]$directory, [string]$name, [string]$bodyClass, [string]$bodyHtml, [hashtable]$cssOverride) {
    $cssCopy = Join-Path $directory 'css'
    New-Item -ItemType Directory -Force -Path $cssCopy | Out-Null
    foreach ($n in $sheetOrder) {
        $target = Join-Path $cssCopy $n
        if ($cssOverride -and $cssOverride.ContainsKey($n)) { [IO.File]::WriteAllText($target, $cssOverride[$n], (New-Object Text.UTF8Encoding($false))) }
        elseif (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath (Join-Path $cssDir $n) -Destination $target -Force }
    }
    # Ordine reale: fogli del tema e delle pagine, poi il CSS in linea della pagina (HeadContent), poi theme-overrides.css per ultimo (Page.master riga 38).
    $links = ($sheetOrder | Where-Object { $_ -ne 'theme-overrides.css' } | ForEach-Object { '<link rel="stylesheet" href="css/' + $_ + '" />' }) -join "`n"
    $inline = $orderStyle.Groups[1].Value
    $html = "<!doctype html><html lang=`"it`"><head><meta charset=`"utf-8`" /><meta name=`"viewport`" content=`"width=device-width, initial-scale=1`" />`n$links`n<style id=`"order-inline`">$inline</style>`n<link rel=`"stylesheet`" href=`"css/theme-overrides.css`" /></head><body class=`"$bodyClass`">`n$bodyHtml`n</body></html>"
    $path = Join-Path $directory ($name + '.html')
    [IO.File]::WriteAllText($path, $html, (New-Object Text.UTF8Encoding($false)))
    return $path
}

$statesByProbe = @{
    'nav-home-active' = @('rest', 'hover'); 'nav-offerte' = @('rest', 'hover'); 'minicart-cta' = @('rest', 'hover'); 'print-order' = @('rest', 'hover'); 'btn-gray' = @('rest', 'hover');
    'account-btn-fill' = @('rest', 'hover'); 'plain-button' = @('rest', 'hover'); 'plain-small' = @('rest', 'hover'); 'btn-line' = @('rest', 'hover'); 'multi-cta' = @('rest', 'hover');
    'order-primary' = @('rest', 'hover'); 'order-secondary' = @('rest', 'hover'); 'pdp-buy' = @('rest', 'hover')
}
$feedbackProbes = @('minicart-cta', 'print-order', 'multi-cta', 'order-primary', 'account-btn-fill')

$measureJs = @'
(function(){
  function parse(c){var m=c.match(/rgba?\(([^)]+)\)/); if(!m) return null; var p=m[1].split(',').map(function(x){return parseFloat(x)}); return {r:p[0],g:p[1],b:p[2],a:(p.length>3?p[3]:1)};}
  function chain(el){var op=1,bg=null,bgImg=false,own=null,n=el;
    while(n && n.nodeType===1){var cs=getComputedStyle(n); op*=parseFloat(cs.opacity);
      if(bg===null){var c=parse(cs.backgroundColor); if(cs.backgroundImage && cs.backgroundImage!=='none') bgImg=true; if(c && c.a>0.99){bg='rgb('+c.r+', '+c.g+', '+c.b+')';} else if(c && c.a>0){bgImg=true;} }
      n=n.parentElement;}
    return {opacity:op,bg:(bg===null?'NO_OPAQUE_BACKGROUND':bg),bgImage:bgImg};}
  var out=[];
  document.querySelectorAll('[data-probe]').forEach(function(el){
    var cs=getComputedStyle(el), r=el.getBoundingClientRect(), ch=chain(el);
    out.push({name:el.getAttribute('data-probe'),exempt:el.getAttribute('data-exempt')||'',color:cs.color,bg:ch.bg,opacity:Math.round(ch.opacity*1000)/1000,bgImage:ch.bgImage,size:parseFloat(cs.fontSize),weight:parseInt(cs.fontWeight,10),visible:(cs.display!=='none'&&cs.visibility!=='hidden'&&r.width>0&&r.height>0)});
  });
  return JSON.stringify(out);
})()
'@

function Evaluate-Rows([object[]]$rows, [string]$state, [hashtable]$restBg, [System.Collections.Generic.List[string]]$fails, [string[]]$expected) {
    $seen = @{}
    foreach ($r in $rows) {
        $seen[$r.name] = $true
        $tag = $state + ':' + $r.name
        if (-not $r.visible) { $fails.Add($tag + ':NOT_VISIBLE'); continue }
        if ($r.exempt -ne '') { continue }
        if ($r.opacity -lt 0.999 -or $r.bgImage -or $r.bg -eq 'NO_OPAQUE_BACKGROUND') { $fails.Add($tag + ':NOT_COMPUTABLE opacity=' + $r.opacity + ' bgImage=' + $r.bgImage + ' bg=' + $r.bg); continue }
        $large = ($r.size -ge 24) -or ($r.size -ge 18.66 -and $r.weight -ge 700)
        $need = if ($large) { 3.0 } else { 4.5 }
        $ratio = Contrast $r.color $r.bg
        if ($ratio -lt $need) { $fails.Add($tag + ':CONTRAST_BELOW_AA ' + $r.color + ' on ' + $r.bg + ' = ' + [Math]::Round($ratio, 2) + ' need ' + $need) }
        if ($state -eq 'hover' -and ($feedbackProbes -contains $r.name) -and $restBg.ContainsKey($r.name) -and $restBg[$r.name] -eq $r.bg) { $fails.Add($tag + ':NO_HOVER_FEEDBACK background stays ' + $r.bg) }
        if ($state -eq 'rest') { $restBg[$r.name] = $r.bg }
    }
    foreach ($e in $expected) { if (-not $seen.ContainsKey($e)) { $fails.Add($state + ':' + $e + ':TARGET_NOT_FOUND') } }
}

. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-palette-aa-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$browser = $null
try {
    try { $browser = Start-KsBrowser -LoopbackHosts @('localhost') -Width 1440 -Height 900 }
    catch { Write-Output ('BROWSER_NON_ESEGUITO: ' + $_.Exception.Message); exit 2 }
    $null = Invoke-KsCdp $browser 'DOM.enable' @{}
    $null = Invoke-KsCdp $browser 'CSS.enable' @{}

    function Measure-Doc([string]$path) {
        Open-KsUrl $browser ('file:///' + ($path -replace '\\', '/'))
        Start-Sleep -Milliseconds 1200
        $null = Invoke-KsJs $browser "(function(){document.getAnimations().forEach(function(a){try{a.finish()}catch(e){}}); return 1})()"
        return @((Invoke-KsJs $browser $measureJs) | ConvertFrom-Json)
    }
    function Measure-WithState([string]$path, [string[]]$names) {
        Open-KsUrl $browser ('file:///' + ($path -replace '\\', '/'))
        Start-Sleep -Milliseconds 1200
        $doc = Invoke-KsCdp $browser 'DOM.getDocument' @{ depth = 0 }
        $root = $doc['root']['nodeId']
        foreach ($n in $names) {
            $q = Invoke-KsCdp $browser 'DOM.querySelector' @{ nodeId = $root; selector = ('[data-probe="' + $n + '"]') }
            if ($q['nodeId'] -gt 0) { $null = Invoke-KsCdp $browser 'CSS.forcePseudoState' @{ nodeId = $q['nodeId']; forcedPseudoClasses = @('hover') } }
        }
        Start-Sleep -Milliseconds 400
        $null = Invoke-KsJs $browser "(function(){document.getAnimations().forEach(function(a){try{a.finish()}catch(e){}}); return 1})()"
        Start-Sleep -Milliseconds 300
        return @((Invoke-KsJs $browser $measureJs) | ConvertFrom-Json)
    }
    function Run-All([string]$tag, [hashtable]$cssOverride) {
        $dir = Join-Path $work $tag
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $genericPath = Write-Doc $dir 'generic' '' (Body-Generic) $cssOverride
        $homePath = Write-Doc $dir 'home' 'ks-page-home' (Body-Home) $cssOverride
        $fails = New-Object 'System.Collections.Generic.List[string]'
        $restBg = @{}
        $genericNames = @('nav-home-active', 'nav-offerte', 'minicart-cta', 'print-order', 'btn-gray', 'account-btn-fill', 'plain-button', 'plain-small', 'btn-line', 'multi-cta', 'multi-cta-disabled', 'order-primary', 'order-secondary', 'pdp-price', 'pdp-buy', 'tp-white', 'tm2-white', 'tp-fafafa', 'tp-f5f5f5', 'tm2-f5f5f5', 'subscribe')
        $homeNames = @('home-sale-tag-deal', 'home-badge-small', 'home-badge-title', 'home-sale-tag-grid', 'home-category', 'home-old', 'home-new-price', 'home-collection', 'home-cat-link', 'home-hero-eyebrow')
        Evaluate-Rows (Measure-Doc $genericPath) 'rest' $restBg $fails $genericNames
        Evaluate-Rows (Measure-Doc $homePath) 'rest-home' $restBg $fails $homeNames
        $hoverRows = Measure-WithState $genericPath @($statesByProbe.Keys)
        $hoverRows = @($hoverRows | Where-Object { $statesByProbe.ContainsKey($_.name) })
        Evaluate-Rows $hoverRows 'hover' $restBg $fails @($statesByProbe.Keys)
        return $fails.ToArray()
    }
    function Assert-Fails([string]$name, [hashtable]$cssOverride, [string]$mustContain) {
        $f = @(Run-All $name $cssOverride)
        if ($f.Count -eq 0) { throw ('MUTATION_NOT_DETECTED=' + $name) }
        if (-not (@($f | Where-Object { $_ -like ('*' + $mustContain + '*') }).Count)) { throw ('MUTATION_DETECTED_FOR_THE_WRONG_REASON=' + $name + ' wanted ' + $mustContain + ' got ' + (($f | Select-Object -First 4) -join ' | ')) }
        Write-Output ('PASS MUTATION_DETECTED ' + $name + ' (' + $f.Count + ' findings)')
    }

    # --- Stato reale ----------------------------------------------------------------------------------------------------------------------
    $real = @(Run-All 'real' $null)
    if ($real.Count -gt 0) { $real | ForEach-Object { Write-Output ('FINDING ' + $_) }; throw 'REAL_CSS_FAILS_THE_BEHAVIOURAL_ORACLE' }
    Write-Output 'PASS REAL_CSS_PASSES_ALL_PROBES_AT_REST_AND_ON_HOVER_WITH_FEEDBACK'

    # --- Mutazioni sul CSS (copie temporanee) ---------------------------------------------------------------------------------------------
    $theme = Read-Repo 'Public/assets/keepstore/css/theme-overrides.css'
    $stylesMut = @{ 'styles.css' = $styles }
    Assert-Fails 'M01_primary_back_to_the_old_red' @{ 'styles.css' = (Mutate-Text $styles '--primary: #D80027;' '--primary: #ff3d3d;' 'M01') } 'CONTRAST_BELOW_AA'
    Assert-Fails 'M02_gray_2_back_to_the_old_grey' @{ 'styles.css' = (Mutate-Text $styles '--gray-2: #666666;' '--gray-2: #73787d;' 'M02') } 'CONTRAST_BELOW_AA'
    Assert-Fails 'M03_filled_button_without_white_text' @{ 'styles.css' = (Mutate-Text $styles "  background-color: var(--primary);`n  color: var(--white);`n  display: flex;" "  background-color: var(--primary);`n  display: flex;" 'M03') } 'CONTRAST_BELOW_AA'
    Assert-Fails 'M04_btn_line_loses_its_dark_text' @{ 'styles.css' = (Mutate-Text $styles ".tf-btn.btn-line {`n  color: var(--gray);" ".tf-btn.btn-line {" 'M04') } 'btn-line'
    Assert-Fails 'M05_hover_token_equal_to_the_primary_no_feedback' @{ 'styles.css' = (Mutate-Text $styles '--primary-hover: #B8001F;' '--primary-hover: #D80027;' 'M05') } 'NO_HOVER_FEEDBACK'
    Assert-Fails 'M06_nav_states_lose_the_darker_red' @{ 'theme-overrides.css' = ($theme + "`n.header-bottom .main-nav-menu .nav-item.active .item-link, .header-bottom .main-nav-menu .nav-item:hover .item-link, .header-bottom .main-nav-menu .nav-item .item-link.link:hover { color: var(--primary) !important; }`n") } 'nav-'
    Assert-Fails 'M07_home_badge_literal_back' @{ 'theme-overrides.css' = ($theme + "`nbody.ks-page-home .ks-home-main .box-sale-wrap { background: #ff3b30; }`n") } 'home-badge'
    Assert-Fails 'M08_home_grey_literal_back' @{ 'theme-overrides.css' = ($theme + "`nbody.ks-page-home .ks-home-main .caption { color: #7d8793; }`n") } 'home-category'
    Assert-Fails 'M09_opacity_on_a_primary_button_is_not_computable' @{ 'theme-overrides.css' = ($theme + "`n.tf-btn.btn-fill { opacity: .8; }`n") } 'NOT_COMPUTABLE'
    Assert-Fails 'M10_gradient_background_is_not_computable' @{ 'theme-overrides.css' = ($theme + "`n.ks-product-page .product-box-btn .tf-btn { background-image: linear-gradient(#d80027, #b8001f); }`n") } 'NOT_COMPUTABLE'
    $eyebrowRule = [regex]::Match($theme, '(?s)body\.ks-page-home \.ks-home-main \.ks-home-hero-eyebrow\.caption \{.*?\}').Value
    if ($eyebrowRule -eq '') { throw 'EYEBROW_FIX_RULE_NOT_FOUND' }
    Assert-Fails 'M13_hero_eyebrow_fix_removed_grey_on_near_black' @{ 'theme-overrides.css' = $theme.Replace($eyebrowRule, '') } 'home-hero-eyebrow'
    Assert-Fails 'M11_order_page_hover_uses_the_same_red' @{ 'theme-overrides.css' = ($theme + "`n.ks-order-actions .ks-order-btn-primary:hover { background: var(--primary); border-color: var(--primary); }`n") } 'order-primary'

    # --- Guardia statica sui letterali (fuori dai fallback var(--x, #...)) ---------------------------------------------------------------
    $guardFiles = @('theme-overrides.css', 'cart-ui.css', 'product-ui.css', 'catalog-ui.css', 'minicart-ui.css', 'ks-ui.css', 'keepstore-overrides.css', 'order-ui.css', 'account-ui.css', 'documents-ui.css', 'catalog-product-flow.css', 'catalog-filters-ui.css')
    $badLiteral = '#ff3d3d|#ff3b30|#73787d|#7d8793|#8b949e|#667280|#777777'
    function Test-NoBadLiterals([string]$name, [string]$text) {
        $bad = New-Object System.Collections.Generic.List[string]
        $text = [regex]::Replace($text, '(?s)/\*.*?\*/', '')
        foreach ($d in ($text -split '[;{}]')) {
            if ($d -match '^\s*(--[a-z0-9-]+|[a-z-]+)\s*:\s*(.*)$') {
                $prop = $Matches[1]; $val = $Matches[2]
                $stripped = [regex]::Replace($val, '(?is)var\(\s*--[a-z0-9-]+\s*,\s*#[0-9a-f]{3,8}\s*\)', 'VARFALLBACK')
                $stripped = [regex]::Replace($stripped, '(?is)rgba?\([^)]*\)', 'RGBA')
                $hits = @([regex]::Matches($stripped, ('(?i)(' + $badLiteral + ')')) | ForEach-Object { $_.Value.ToLower() })
                # Un bordo e un elemento grafico (soglia 3:1): il vecchio grigio #73787d (4,46:1) li supera, quindi non e un difetto come colore di bordo.
                if ($prop -match '^border') { $hits = @($hits | Where-Object { $_ -ne '#73787d' }) }
                if ($hits.Count -gt 0 -and $prop -notmatch '^(outline|box-shadow|filter|text-shadow)$') { $bad.Add($name + ': ' + $prop + ': ' + $val.Trim().Substring(0, [Math]::Min(40, $val.Trim().Length))) }
            }
        }
        return $bad.ToArray()
    }
    $allBad = New-Object System.Collections.Generic.List[string]
    foreach ($g in $guardFiles) { foreach ($b in @(Test-NoBadLiterals $g (Read-Repo ('Public/assets/keepstore/css/' + $g)))) { $allBad.Add($b) } }
    foreach ($b in @(Test-NoBadLiterals 'ordine.aspx(style)' $orderStyle.Groups[1].Value)) { $allBad.Add($b) }
    $defaultAspx = Read-Repo 'Default.aspx'
    $defStyle = [regex]::Match($defaultAspx, '(?s)<style[^>]*>(.*?)</style>')
    if ($defStyle.Success) { foreach ($b in @(Test-NoBadLiterals 'Default.aspx(style)' $defStyle.Groups[1].Value)) { $allBad.Add($b) } }
    if ($allBad.Count -gt 0) { $allBad | ForEach-Object { Write-Output ('LITERAL ' + $_) }; throw 'BAD_RED_OR_GREY_LITERALS_REMAIN_OUTSIDE_FALLBACKS' }
    Write-Output 'PASS NO_BAD_RED_OR_GREY_LITERAL_OUTSIDE_A_FALLBACK_IN_THE_LISTED_STYLESHEETS_AND_INLINE_STYLES'
    foreach ($case in @(
            @('G1_literal_red_in_theme_overrides', 'theme-overrides.css', "`nbody.ks-page-home .x { background: #ff3b30; }`n"),
            @('G2_checkout_primary_variable_literal', 'cart-ui.css', "`n.ks-cart-page.ks-checkout-modern { --ks-checkout-primary: #ff3d3d; }`n"),
            @('G3_old_grey_in_product_ui', 'product-ui.css', "`n.x::before { color: #73787d; }`n"),
            @('G4_old_grey_text_in_cart', 'cart-ui.css', "`n.x { color: #777777; }`n"))) {
        $t = (Read-Repo ('Public/assets/keepstore/css/' + $case[1])) + $case[2]
        if (@(Test-NoBadLiterals $case[1] $t).Count -eq 0) { throw ('MUTATION_NOT_DETECTED=' + $case[0]) }
        Write-Output ('PASS MUTATION_DETECTED ' + $case[0])
    }
    if (@(Test-NoBadLiterals 'ordine.aspx(style)' ($orderStyle.Groups[1].Value + '.x{color:#ff3d3d;}')).Count -eq 0) { throw 'MUTATION_NOT_DETECTED=G5_literal_in_the_inline_order_style' }
    Write-Output 'PASS MUTATION_DETECTED G5_literal_in_the_inline_order_style'
    if (@(Test-NoBadLiterals 'cart-ui.css' '.x { background: var(--primary, #ff3d3d); box-shadow: 0 0 0 2px rgba(255,61,61,.3); }').Count -ne 0) { throw 'GUARD_REJECTS_A_LEGITIMATE_FALLBACK_OR_SHADOW' }
    Write-Output 'PASS GUARD_ALLOWS_FALLBACKS_AND_RGBA_SHADOWS'
    if (Test-Busters (Mutate-Text $master '"?v=20261115-focus-fc1a"' '"?v=20261115-home-cards1a"' 'M12')) { throw 'MUTATION_NOT_DETECTED=M12_master_buster_not_bumped' }
    Write-Output 'PASS MUTATION_DETECTED M12_master_buster_not_bumped'

    Write-Output 'PALETTE_AA_ALL_PASS'
}
finally {
    if ($browser) { Stop-KsBrowser $browser }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
