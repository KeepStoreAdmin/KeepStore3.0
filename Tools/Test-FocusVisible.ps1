[CmdletBinding()]
param()

# KS-A04-FOCUS-FORCED-COLORS-1A - focus da tastiera sempre visibile e confini/stati leggibili in colori forzati.
# Oracolo COMPORTAMENTALE: i veri fogli di stile (nell'ordine di Page.master, piu il CSS che ks-page-flags.js inietta a runtime, estratto dal sorgente) sono caricati in Edge su
# frammenti del MARKUP REALE (testata, mega menu, barra reparti, card, swiper, piede, modale, form Bootstrap, registrazione, ordinamento, minicarrello, carrello, suggerimenti).
# Il test usa la TASTIERA VERA (eventi Tab via CDP): per ogni elemento raggiunto legge gli stili COMPUTATI con :focus-visible reale (compresi :focus-within e le regole di
# rivelazione). Regole: ogni bersaglio atteso deve essere raggiunto da Tab (un bersaglio non raggiunto = FALLIMENTO); ogni elemento raggiunto deve avere un outline opaco di almeno
# 2px, con contrasto >= 3:1 contro lo sfondo adiacente e contro le superfici dichiarate, visibile (opacita e visibilita effettive), non tagliato da un antenato overflow:hidden fuori
# dall'allowlist esplicita, e con la geometria locale dichiarata. I contenitori con tabindex=-1 (modale, offcanvas) NON devono mostrare l'anello. In forced-colors: outline presente su ogni
# elemento raggiunto, confine presente (senza focus) sui controlli dichiarati, stato attivo diverso dal fratello per una proprieta visibile (non solo lo sfondo).
# Guardia statica: nessun outline a colore con alfa < 1 nei selettori :focus* dei fogli runtime; --focus-ring definito e usato sempre con fallback.
# Senza Edge: NON ESEGUITO (uscita 2), mai PASS. Limiti dichiarati: Edge headless, non un tema ad alto contrasto reale ne lettori di schermo; pagine con login non coperte;
# i tagli parziali ai bordi dei contenitori a scorrimento e dei pallini degli swiper sono residui accettati (allowlist). Fuori dall'oracolo: le azioni delle card (wishlist, vista
# rapida, confronto), rivelate da :hover/:focus-within e da JS, e il menu lingua/valuta (il pulsante ha tabindex=-1): le copre l'audit sul Smoke registrato nel Masterplan.
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

# --- Sorgenti reali e ancore del markup ---------------------------------------------------------------------------------------------
$styles = Read-Repo 'Public/assets/keepstore/css/styles.css'
$theme = Read-Repo 'Public/assets/keepstore/css/theme-overrides.css'
$header = Read-Repo 'Public/ui/controls/SiteHeader.ascx'
$footer = Read-Repo 'Public/ui/controls/SiteFooter.ascx'
$master = Read-Repo 'Page.master'
$flagsJs = Read-Repo 'Public/assets/keepstore/js/ks-page-flags.js'
$catalogAspx = Read-Repo 'articoli.aspx'
$catalogFlowJs = Read-Repo 'Public/assets/keepstore/js/catalog-product-flow.js'
$registerAspx = Read-Repo 'registrazione.aspx'

$navMatch = [regex]::Match($header, '(?s)<nav class="main-nav-menu">.*?</nav>')
# il menu e reso dal server: qui lo si legge come sulla HOME (voce Home attiva, nessun aria-current, che non cambia colori ne anelli)
$navHtml = [regex]::Replace([regex]::Replace($navMatch.Value, '<%= MainNavActive\("home"\) %>', ' active'), '<%= MainNav(?:Active|Current)\("[a-z]+"\) %>', '')
Assert-Source ($navMatch.Success -and $navHtml.Contains('<a href="Default.aspx" class="item-link link body-md-2">') -and $navHtml.Contains('<a href="articoli.aspx?inpromo=1" class="item-link body-md-2">')) 'ANCHOR_HEADER_MAIN_NAV_LINKS'
Assert-Source ($header.Contains('class="form-search-product m-auto ks-search-shell"') -and $header.Contains('class="btn-submit-form"') -and $header.Contains('CssClass="dropdown_product_cat ks-search-category-select"') -and $header.Contains('class="image-select center style-default type-lan"')) 'ANCHOR_HEADER_SEARCH_AND_LANGUAGE'
Assert-Source ($header.Contains("class='ks-dept-link body-md-2'") -or (Read-Repo 'Public/ui/controls/SiteHeader.ascx.vb').Contains("class='ks-dept-link body-md-2'")) 'ANCHOR_DEPARTMENTS_BAR_LINK'
# KS-B02A-FOOTER-TRUTH-1A: il piede reale non ha piu la fascia scura della newsletter (era una promozione e una iscrizione finte). La fixture di questo test ne conserva una scritta a mano per provare la regola dell'anello bianco (PR 505), che oggi nessun piede usa: regola e fixture sono codice morto da togliere insieme in un task di pulizia del CSS.
Assert-Source (-not $footer.Contains('ft-body-center') -and -not $footer.Contains('subscribe-email')) 'ANCHOR_FOOTER_HAS_NO_DARK_NEWSLETTER_BAND_ANY_MORE'
Assert-Source ($master.Contains('class="modal fade ks-newsletter-modal" id="ksNewsletterModal" tabindex="-1"') -and $master.Contains('class="btn-close close position-absolute"')) 'ANCHOR_NEWSLETTER_MODAL_AND_BTN_CLOSE'
Assert-Source ($registerAspx.Contains('background-color:rgb(16, 152, 23)') -and $registerAspx.Contains('ID="btRegistrati"')) 'ANCHOR_REGISTER_BUTTON_ON_THE_GREEN_TABLE'
Assert-Source ($catalogAspx.Contains('ks-multi-footer__cta') -and $catalogFlowJs.Contains("'ks-qty-btn ks-qty-minus'") -and $catalogFlowJs.Contains("'ks-qty-btn ks-qty-plus'")) 'ANCHOR_CATALOG_MULTI_CTA_AND_QTY_BUTTONS_BUILT_BY_JS'
Assert-Source ($flagsJs.Contains('.ks-search-host input[type="text"]') -and $flagsJs.Contains('.ks-suggest-item.is-active')) 'ANCHOR_JS_INJECTED_CSS_HAS_THE_SEARCH_HOST_RULE'

# CSS che ks-page-flags.js aggiunge in coda al <head> a runtime: estratto dal sorgente (le stringhe del vettore st.textContent).
$flagsBlock = [regex]::Match($flagsJs, "(?s)st\.textContent = \[(.*?)\]\.join\(''\);")
if (-not $flagsBlock.Success) { throw 'JS_INJECTED_CSS_BLOCK_NOT_FOUND' }
$injectedCss = (([regex]::Matches($flagsBlock.Groups[1].Value, "'((?:[^'\\]|\\.)*)'") | ForEach-Object { $_.Groups[1].Value }) -join '')
Assert-Source ($injectedCss.Length -gt 500 -and $injectedCss.Contains('.ks-search-host input[type="text"]')) 'JS_INJECTED_CSS_EXTRACTED'

function Test-Busters([string]$m, [string]$catalogPage, [string]$productPage, [string]$cartPage) {
    $tag = '20261119-compact-1a'
    return ($m -match ('css/styles\.css"\) & "\?v=' + $tag + '"') -and $m -match ('css/theme-overrides\.css"\) & "\?v=' + $tag + '"') -and $m -match ('css/auth-ui\.css"\) & "\?v=' + $tag + '"') -and $m -match ('css/minicart-ui\.css"\) & "\?v=' + $tag + '"') -and
        $catalogPage -match ('css/catalog-ui\.css"\)[^\r\n]*\?v=' + $tag) -and $catalogPage -match ('css/catalog-product-flow\.css"\)[^\r\n]*\?v=' + $tag) -and
        $productPage -match ('css/product-ui\.css"\)[^\r\n]*\?v=(?:' + $tag + '|20261115-focus-obscured1a|20261118-pdp-sections1a|20261118-pdp-tools1a|20261119-compact-1b)') -and $cartPage -match ('css/cart-ui\.css"\)[^\r\n]*\?v=(?:' + $tag + '|20261117-pay-guide-[12]a|20261118-vat-note-1a|20261120-recent-1b)'))
}
$productAspx = Read-Repo 'articolo.aspx'
$cartAspx = Read-Repo 'carrello.aspx'

# Ordine reale dei fogli (Page.master righe 18-38, piu i fogli delle pagine, theme-overrides.css per ultimo).
$sheetOrder = @('bootstrap.min.css', 'keepstore.css', 'keepstore-overrides.css', 'account-ui.css', 'documents-ui.css', 'auth-ui.css', 'ks-ui.css', 'nice-select.css', 'swiper-bundle.min.css', 'animate.css', 'styles.css', 'minicart-ui.css',
    'catalog-ui.css', 'catalog-filters-ui.css', 'catalog-product-flow.css', 'product-ui.css', 'order-ui.css', 'cart-ui.css', 'theme-overrides.css')
foreach ($n in $sheetOrder) { if (-not (Test-Path -LiteralPath (Join-Path $cssDir $n))) { throw ('STYLESHEET_MISSING=' + $n) } }

# --- Pagina di prova: frammenti del markup reale, ogni bersaglio ha data-probe ----------------------------------------------------------
# Attributi: data-probe=nome; data-tab="no" = non raggiungibile da Tab per costruzione (si prova con :focus-visible forzato); data-container="1" = contenitore tabindex=-1 (nessun anello);
# data-surfaces="rgb(..)|rgb(..)" = superfici aggiuntive su cui l'anello deve avere 3:1; data-clip-ok="motivo" = taglio parziale accettato; data-expect-width / data-expect-offset =
# geometria locale da preservare; data-boundary="1" = confine atteso in colori forzati; data-state-pair="id:active|rest" = stato attivo da distinguere dal fratello in colori forzati.
$pixel = 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
$bodyTemplate = @'
<header class="tf-header ks-header-ui">
  <div class="header-bottom bg-gray-5 d-none d-xl-block"><div class="container relative"><div class="row"><div class="col-xl-9 col-12"><div class="header-bt-left ks-header-nav-shell">{{NAV}}</div></div></div></div></div>
  <div style="padding:12px 24px">
    <div class="form-search-product m-auto ks-search-shell ks-search-host" data-ks-search-form="desktop">
      <div class="select-category"><label for="pcat" class="visually-hidden">Ambito di ricerca</label><select id="pcat" class="dropdown_product_cat ks-search-category-select" data-probe="hdr-search-select"><option>Tutti i settori</option></select></div>
      <span class="br-line type-vertical bg-line"></span>
      <fieldset><input type="text" id="tbCerca" placeholder="Cerca prodotti" data-probe="hdr-search-input" /></fieldset>
      <button type="submit" class="btn-submit-form" aria-label="Cerca" data-probe="hdr-search-btn"><i class="icon-search"></i></button>
    </div>
  </div>
  <div style="padding:12px 24px"><a class="link link-fill nav-icon-item relative" href="carrello.aspx" data-probe="hdr-icon"><i class="icon-cart text-main fs-26 link"></i><span class="count-box">0</span></a></div>
  <div class="ks-header-catalog-item is-open" style="padding:12px 24px"><nav class="category-menu sub-menu-container ks-header-catalog-menu" style="display:block;visibility:visible;opacity:1;position:static;transform:none"><ul class="megamenu ks-header-catalog-list"><li><a class="body-md-2 link ks-header-catalog-tipology-link" href="#" data-probe="mega-link">Cavi e adattatori</a></li></ul></nav></div>
  <div class="ks-dept-nav" style="padding:12px 24px"><ul class="ks-dept-list"><li class="ks-dept-item"><a class="ks-dept-link body-md-2" href="#" data-probe="dept-link" data-expect-width="2" data-expect-offset="-2">Informatica</a></li></ul><a class="ks-dept-all body-md-2" href="#" data-probe="dept-all">Tutti i reparti</a></div>
</header>
<div class="tf-cur-item tf-languages gap-0" style="padding:12px 24px"><div class="tf-lans"><div class="dropdown bootstrap-select image-select center style-default type-lan"><button type="button" tabindex="-1" class="btn dropdown-toggle btn-light" role="combobox" aria-haspopup="listbox" aria-expanded="false" title="Italiano" data-probe="lang-toggle" data-tab="no" data-boundary="1"><div class="filter-option"><div class="filter-option-inner"><div class="filter-option-inner-inner">Italiano</div></div></div></button></div></div></div>
<section id="ksCatalogPage" style="padding:24px">
  <div class="tf-grid-layout lg-col-4 md-col-3 sm-col-2" style="width:360px">
    <article class="card-product">
      <div class="card-product-wrapper"><a href="#" class="product-img" aria-label="Prodotto" data-probe="card-img"><img class="img-product" src="{{PIXEL}}" alt="Prodotto" width="174" height="174" /><img class="img-hover" src="{{PIXEL}}" alt="" aria-hidden="true" /></a>
        <ul class="list-product-btn top-0 end-0" aria-label="Azioni prodotto"><li><a href="#" class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-wishlist-link" aria-label="Aggiungi a wishlist"><span class="icon icon-heart2"></span><span class="tooltip">Wishlist</span></a></li></ul></div>
      <div class="card-product-info"><div class="box-title"><div><p class="product-tag caption text-main-2 ks-card-category">Categoria</p><a href="#" class="name-product body-md-2 fw-semibold text-secondary link ks-card-title" data-probe="card-name">NOME PRODOTTO LUNGO DI PROVA PER IL TEST</a></div><p class="price-wrap fw-medium"><span class="new-price price-text fw-medium">3,00</span></p></div>
        <div class="box-infor-detail"><div class="d-flex align-items-center gap-2 mt-2 ks-card-purchase-actions"><span class="form-check-input" title="Seleziona prodotto per acquisto multiplo"><input id="cb1" type="checkbox" name="cb1" data-probe="card-check" /><label for="cb1">Seleziona</label></span>
          <div class="ks-qty-wrap"><button type="button" class="ks-qty-btn ks-qty-minus" aria-label="Diminuisci quantita" data-probe="card-qty-minus">-</button><input name="q1" type="text" value="1" class="form-control form-control-sm ks-qty" aria-label="Quantita" style="width:70px;" data-probe="card-qty-input" /><button type="button" class="ks-qty-btn ks-qty-plus" aria-label="Aumenta quantita" data-probe="card-qty-plus">+</button></div>
          <button type="submit" class="ks-card-buy-cta ks-compact-buy-cta js-ks-cart-link" aria-label="Acquista" tabindex="0" data-probe="card-buy" data-expect-width="3">Acquista</button></div></div></div>
    </article>
  </div>
  <ul class="tf-control-layout menu-tab-line" role="tablist" aria-label="Visualizzazione prodotti" style="padding:12px 0"><li role="presentation"><a href="#" class="ks-view-layout-switch active" role="tab" aria-label="Vista griglia" aria-pressed="true" aria-selected="true" data-probe="view-active" data-state-pair="view:active"><i class="icon-menu-dots" aria-hidden="true"></i></a></li><li role="presentation"><a href="#" class="ks-view-layout-switch" role="tab" aria-label="Vista lista" aria-pressed="false" aria-selected="false" data-probe="view-rest" data-state-pair="view:rest"><i class="icon-list-1" aria-hidden="true"></i></a></li></ul>
  <div class="tf-control-sort" style="padding:12px 0"><button type="button" class="btn-select ks-sort-trigger" aria-haspopup="listbox" aria-expanded="false" data-probe="sort-trigger"><span class="ks-sort-trigger-label">Ordina:</span> <span class="ks-sort-trigger-value">Consigliati</span></button><div class="ks-sort-menu" role="listbox" style="display:block;visibility:visible;opacity:1;position:static"><button type="button" class="ks-sort-option is-selected" role="option" aria-selected="true" data-probe="sort-option" data-tab="no"><span>Consigliati</span></button></div></div>
  <nav class="ks-catalog-pager" style="padding:12px 0"><a class="ks-catalog-pager__control ks-catalog-pager__next ks-catalog-pager__control--wide" href="#" aria-label="Pagina successiva" data-probe="pager-next"><span>Prossimo</span></a></nav>
  <div class="ks-multi-footer" style="padding:12px 0"><input type="submit" class="tf-btn btn-fill ks-multi-footer__cta" value="Aggiungi selezionati al carrello" data-probe="multi-cta" /></div>
  <div style="padding:12px 0"><button type="button" class="btn-loadmore ks-brand-loadmore" data-probe="brand-loadmore" data-boundary="1">Altri marchi</button></div>
</section>
<section class="ks-home-main" style="padding:24px">
  <div class="swiper tf-sw-products" style="width:300px"><div class="swiper-wrapper"><div class="swiper-slide" style="width:300px"><article class="card-product"><div class="card-product-wrapper"><a class="product-img" href="#" data-probe="sw-img"><img class="img-product" src="{{PIXEL}}" alt="" width="296" height="120" /></a></div><div class="card-product-info"><div class="box-title"><a class="name-product body-md-2 fw-semibold text-secondary" href="#" data-probe="sw-name">NOME PRODOTTO DELLO SWIPER</a></div></div></article></div></div>
    <div class="swiper-pagination" style="position:static;padding:8px 0"><span class="swiper-pagination-bullet swiper-pagination-bullet-active" tabindex="0" role="button" aria-label="Go to slide 1" data-probe="sw-bullet-active" data-clip-ok="swiper-bullet" data-state-pair="bullet:active"></span><span class="swiper-pagination-bullet" tabindex="0" role="button" aria-label="Go to slide 2" data-probe="sw-bullet" data-clip-ok="swiper-bullet" data-state-pair="bullet:rest"></span></div></div>
  <div class="banner-image-product-4 style-2 hover-img" style="background:#070707;padding:20px;margin-top:12px"><a class="tf-btn btn-line-white mt-1" href="#" data-probe="banner-link"><span>Scopri ora</span></a></div>
  <div class="ks-guide-choices" style="margin-top:12px"><button type="button" aria-pressed="true" data-probe="guide-on" data-state-pair="guide:active">Casa</button><button type="button" aria-pressed="false" data-probe="guide-off" data-state-pair="guide:rest">Ufficio</button></div>
  <div style="margin-top:12px"><button type="button" class="ks-guide-path" data-probe="guide-path" data-boundary="1">Percorso guidato</button></div>
  <div class="ks-suggest is-open" style="position:static;margin-top:12px"><div class="ks-suggest-scope"><button type="button" class="ks-suggest-chip is-active" data-probe="sug-chip-on" data-state-pair="chip:active">Tutti</button><button type="button" class="ks-suggest-chip" data-probe="sug-chip-off" data-state-pair="chip:rest">Marca</button></div><ul class="ks-suggest-list"><li><a class="ks-suggest-item is-active" href="#" data-probe="sug-item-on" data-state-pair="sugitem:active"><span class="ks-suggest-meta"><span class="ks-suggest-title">Risultato uno</span></span></a></li><li><a class="ks-suggest-item" href="#" data-probe="sug-item-off" data-state-pair="sugitem:rest"><span class="ks-suggest-meta"><span class="ks-suggest-title">Risultato due</span></span></a></li></ul><a class="ks-suggest-all" href="#" data-probe="sug-all">Vedi tutti i risultati</a></div>
</section>
<div class="ft-body-center bg-gray"><div class="container"><div class="ft-center justify-content-xxl-between"><div class="form-newsletter" data-ks-newsletter="1"><div class="subscribe-content"><fieldset class="email"><input id="ksNewsletterEmail" class="subscribe-email type-fs-2" name="ksNewsletterEmail" placeholder="Email" tabindex="0" type="text" inputmode="email" data-probe="ft-news-input" data-boundary="1" /></fieldset><div class="button-submit"><button id="ksNewsletterSubmit" class="subscribe-button tf-btn btn-large hover-shine" type="button" aria-label="Subscribe to newsletter" data-probe="ft-news-btn" data-boundary="1"><span class="body-md-2 fw-semibold text-white">Subscribe</span></button></div></div></div></div></div></div>
<div class="modal fade ks-newsletter-modal show" id="ksNewsletterModal" tabindex="-1" style="display:block;position:static;opacity:1" data-probe="modal-container" data-container="1"><div class="modal-dialog modal-dialog-centered modal-lg"><div class="modal-content"><button type="button" class="btn-close close position-absolute" style="right:12px;top:12px;z-index:3;" data-bs-dismiss="modal" aria-label="Chiudi" data-probe="modal-close"><span aria-hidden="true">&times;</span></button><div class="modal-body text-center"><h5 class="fw-semibold mb-2">Resta aggiornato</h5><div class="subscribe-content"><fieldset class="email"><input type="text" inputmode="email" id="ksNewsletterEmailModal" class="subscribe-email type-fs-2" placeholder="Email" data-probe="modal-news-input" /></fieldset></div></div></div></div></div>
<section class="ks-review-form" style="padding:24px"><input type="text" class="form-control" aria-label="Titolo" data-probe="bs-input" /><select class="form-select" aria-label="Voto" data-probe="bs-select"><option>5</option></select><textarea class="form-control" aria-label="Testo" data-probe="bs-textarea"></textarea><div class="form-check"><input class="form-check-input" type="checkbox" id="fc1" data-probe="bs-check" /><label class="form-check-label" for="fc1">Consiglio</label></div><button type="submit" class="btn btn-primary" data-probe="bs-btn">Invia</button><ul class="nav"><li class="nav-item"><a class="nav-link" href="#" data-probe="bs-navlink">Scheda</a></li></ul><button type="button" class="accordion-button" data-probe="bs-accordion">Dettagli</button><input type="text" aria-label="Campo semplice" data-probe="plain-input" /></section>
<div class="ks-auth-register" data-ks-registration-form="standard" style="padding:24px"><input type="text" aria-label="Nome" data-probe="reg-input" /><table style="width:100%; height:50px; margin-top:20px; background-color:rgb(16, 152, 23); font-size:11pt; text-align:center; color:White;"><tr><td><input type="submit" id="MainContent_btRegistrati" value="REGISTRATI" style="width:100%;height:100%;background-color:transparent;border:0;color:white;font-size:20px;" data-probe="reg-button" data-surfaces="rgb(16, 152, 23)|rgb(255, 255, 255)" /></td></tr></table></div>
<div class="offcanvas offcanvas-end popup-style popup-shopping-cart show" id="ksMiniCartCanvas" tabindex="-1" style="position:static;visibility:visible;transform:none;width:360px" data-probe="minicart-container" data-container="1"><div class="canvas-header"><button type="button" class="icon-close icon-close-popup link ks-mini-cart-close" data-bs-dismiss="offcanvas" aria-label="Chiudi" data-probe="mini-close"></button></div><div class="offcanvas-body"><div class="minicart-empty text-center"><a class="tf-btn btn-fill w-100" href="articoli.aspx" data-probe="mini-cta">Vai al catalogo</a><button type="button" class="ks-mini-remove" aria-label="Rimuovi" data-probe="mini-remove">x</button></div></div></div>
<div class="ks-cart-page" style="padding:24px"><div class="tf-table-page-cart"><div class="ks-cart-remove-cell"><button type="button" class="ks-cart-remove-button icon icon-close link border-0 bg-transparent" title="Rimuovi articolo" data-probe="cart-remove" data-expect-width="3"><span class="visually-hidden">Rimuovi articolo</span></button></div><div class="ks-wg-quantity"><button type="button" class="btn-quantity btn-decrease" aria-label="Diminuisci quantita" data-probe="cart-qty-minus" data-expect-width="3"><i class="icon icon-minus" aria-hidden="true"></i></button><input type="text" class="quantity-product" value="1" aria-label="Quantita" data-probe="cart-qty-input" /></div></div></div>
'@
function Build-Body([string]$extraReplaceFrom, [string]$extraReplaceTo) {
    $nav = $navHtml
    $nav = $nav.Replace('<a href="Default.aspx" class="item-link link body-md-2">', '<a href="Default.aspx" class="item-link link body-md-2" data-probe="nav-home-active">')
    $nav = $nav.Replace('<a href="articoli.aspx?inpromo=1" class="item-link body-md-2">', '<a href="articoli.aspx?inpromo=1" class="item-link body-md-2" data-probe="nav-offerte">')
    $b = $bodyTemplate.Replace('{{NAV}}', $nav).Replace('{{PIXEL}}', $pixel)
    if ($extraReplaceFrom) { $b = Mutate-Text $b $extraReplaceFrom $extraReplaceTo 'BODY' }
    return $b
}

function Write-Doc([string]$directory, [string]$name, [string]$bodyHtml, [hashtable]$cssOverride) {
    $cssCopy = Join-Path $directory 'css'
    New-Item -ItemType Directory -Force -Path $cssCopy | Out-Null
    foreach ($n in $sheetOrder) {
        $target = Join-Path $cssCopy $n
        if ($cssOverride -and $cssOverride.ContainsKey($n)) { [IO.File]::WriteAllText($target, $cssOverride[$n], (New-Object Text.UTF8Encoding($false))) }
        elseif (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath (Join-Path $cssDir $n) -Destination $target -Force }
    }
    $links = ($sheetOrder | Where-Object { $_ -ne 'theme-overrides.css' } | ForEach-Object { '<link rel="stylesheet" href="css/' + $_ + '" />' }) -join "`n"
    $html = "<!doctype html><html lang=`"it`"><head><meta charset=`"utf-8`" /><meta name=`"viewport`" content=`"width=device-width, initial-scale=1`" />`n$links`n<link rel=`"stylesheet`" href=`"css/theme-overrides.css`" />`n<style id=`"ks-page-flags-injected`">$injectedCss</style>`n<style id=`"test-no-transitions`">*,*::before,*::after{transition:none !important;animation:none !important}</style>`n</head><body class=`"ks-page-home`"><form id=`"form1`" onsubmit=`"return false`">`n$bodyHtml`n</form></body></html>"
    $path = Join-Path $directory ($name + '.html')
    [IO.File]::WriteAllText($path, $html, (New-Object Text.UTF8Encoding($false)))
    return $path
}

# --- Lettura degli stili dell'elemento che ha il focus (o di un elemento dato) ---------------------------------------------------------------
$setupJs = @'
(function(){
  function parse(c){var m=c.match(/rgba?\(([^)]+)\)/); if(!m) return null; var p=m[1].split(',').map(function(x){return parseFloat(x)}); return {r:p[0],g:p[1],b:p[2],a:(p.length>3?p[3]:1)};}
  function lin(v){v/=255; return v<=0.04045? v/12.92 : Math.pow((v+0.055)/1.055,2.4);}
  function lum(c){return 0.2126*lin(c.r)+0.7152*lin(c.g)+0.0722*lin(c.b);}
  function ratio(a,b){var x=lum(a),y=lum(b); return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05);}
  function bgOf(el){var n=el; while(n && n.nodeType===1){var c=parse(getComputedStyle(n).backgroundColor); if(c && c.a>0.99) return c; n=n.parentElement;} return {r:255,g:255,b:255,a:1};}
  function cls(el){return (typeof el.className==='string'?el.className:'').split(' ').filter(Boolean).slice(0,3).join('.');}
  window.__ksEval=function(a){
    var cs=getComputedStyle(a), op=1, n=a;
    while(n && n.nodeType===1){op*=parseFloat(getComputedStyle(n).opacity); n=n.parentElement;}
    var w=parseFloat(cs.outlineWidth)||0, off=parseFloat(cs.outlineOffset)||0, r=a.getBoundingClientRect();
    var ext=off>=0? w+off : Math.max(0,w+off);
    var oc=parse(cs.outlineColor)||{r:0,g:0,b:0,a:0};
    var adj=bgOf(a.parentElement||a);
    var surf=[]; var ds=a.getAttribute('data-surfaces'); if(ds){ds.split('|').forEach(function(s){var c=parse(s); if(c) surf.push(c);});}
    surf.push(adj);
    var ratios=surf.map(function(s){ var comp={r:oc.r*oc.a+s.r*(1-oc.a),g:oc.g*oc.a+s.g*(1-oc.a),b:oc.b*oc.a+s.b*(1-oc.a)}; return Math.round(ratio(comp,s)*100)/100; });
    var clip=''; var p=a.parentElement;
    while(p && p!==document.body){var pcs=getComputedStyle(p); if(pcs.overflowX==='hidden'||pcs.overflowY==='hidden'||pcs.overflowX==='clip'||pcs.overflowY==='clip'){var pr=p.getBoundingClientRect();
        var sd=[]; if(r.left-ext<pr.left-0.5)sd.push('L'); if(r.top-ext<pr.top-0.5)sd.push('T'); if(r.right+ext>pr.right+0.5)sd.push('R'); if(r.bottom+ext>pr.bottom+0.5)sd.push('B');
        if(sd.length){clip=p.tagName.toLowerCase()+'.'+cls(p)+' sides='+sd.join(''); break;}} p=p.parentElement;}
    var bw=[cs.borderTopWidth,cs.borderRightWidth,cs.borderBottomWidth,cs.borderLeftWidth].map(parseFloat);
    var bs=[cs.borderTopStyle,cs.borderRightStyle,cs.borderBottomStyle,cs.borderLeftStyle];
    return {name:a.getAttribute('data-probe')||('auto:'+a.tagName.toLowerCase()+'.'+cls(a)+'#'+Array.prototype.indexOf.call(document.getElementsByTagName('*'),a)),tag:a.tagName.toLowerCase(),fv:a.matches(':focus-visible'),oStyle:cs.outlineStyle,oWidth:w,oOffset:off,oAlpha:oc.a,
      oColor:cs.outlineColor,opacity:Math.round(op*1000)/1000,visibility:cs.visibility,ratios:ratios,clip:clip,clipOk:a.getAttribute('data-clip-ok')||'',
      expW:a.getAttribute('data-expect-width')||'',expO:a.getAttribute('data-expect-offset')||'',boundary:a.getAttribute('data-boundary')||'',
      noTab:a.getAttribute('data-tab')||'',container:a.getAttribute('data-container')||'',statePair:a.getAttribute('data-state-pair')||'',
      bwMax:Math.max.apply(null,bw),bsAny:bs.some(function(s){return s!=='none'&&s!=='hidden'}),
      sig:[cs.borderTopWidth,cs.borderRightWidth,cs.borderBottomWidth,cs.borderLeftWidth,cs.borderTopStyle,cs.borderBottomStyle,cs.borderTopColor,cs.borderBottomColor,cs.borderLeftColor,cs.textDecorationLine,cs.outlineStyle,cs.outlineWidth].join('|')};
  };
  window.__ksActive=function(){var a=document.activeElement; if(!a||a===document.body||a===document.documentElement) return JSON.stringify({done:true}); return JSON.stringify(window.__ksEval(a));};
  window.__ksByProbe=function(n){var a=document.querySelector('[data-probe="'+n+'"]'); if(!a) return JSON.stringify({missing:true}); return JSON.stringify(window.__ksEval(a));};
  window.__ksProbeNames=function(){return JSON.stringify(Array.prototype.map.call(document.querySelectorAll('[data-probe]'),function(e){return e.getAttribute('data-probe')}));};
  window.__ksFocusContainer=function(n){var a=document.querySelector('[data-probe="'+n+'"]'); if(!a) return JSON.stringify({missing:true}); a.focus(); var cs=getComputedStyle(a); return JSON.stringify({active:document.activeElement===a,style:cs.outlineStyle,width:parseFloat(cs.outlineWidth)||0});};
  return 1;
})()
'@

. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-focus-visible-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$browser = $null
try {
    try { $browser = Start-KsBrowser -LoopbackHosts @('localhost') -Width 1440 -Height 900 }
    catch { Write-Output ('BROWSER_NON_ESEGUITO: ' + $_.Exception.Message); exit 2 }
    $null = Invoke-KsCdp $browser 'DOM.enable' @{}
    $null = Invoke-KsCdp $browser 'CSS.enable' @{}

    function Press-Tab() {
        $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' @{ type = 'rawKeyDown'; key = 'Tab'; code = 'Tab'; windowsVirtualKeyCode = 9; nativeVirtualKeyCode = 9 }
        $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' @{ type = 'keyUp'; key = 'Tab'; code = 'Tab'; windowsVirtualKeyCode = 9; nativeVirtualKeyCode = 9 }
    }
    function Open-Fixture([string]$path, [bool]$forced) {
        $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ features = @(@{ name = 'forced-colors'; value = $(if ($forced) { 'active' } else { 'none' }) }) }
        Open-KsUrl $browser ('file:///' + $path.Replace([string][char]92, '/'))
        Start-Sleep -Milliseconds 1100
        $null = Invoke-KsJs $browser $setupJs
        $null = Invoke-KsCdp $browser 'Page.bringToFront' @{}
    }
    function Walk-Tab() {
        $rows = New-Object 'System.Collections.Generic.List[object]'
        $seen = @{}
        for ($i = 0; $i -lt 160; $i++) {
            Press-Tab
            Start-Sleep -Milliseconds 40
            $r = (Invoke-KsJs $browser 'window.__ksActive()') | ConvertFrom-Json
            if (-not ($r.PSObject.Properties.Name -contains 'done') -and ($r.oStyle -eq 'none' -or -not $r.fv)) { Start-Sleep -Milliseconds 150; $r = (Invoke-KsJs $browser 'window.__ksActive()') | ConvertFrom-Json }
            if ($r.PSObject.Properties.Name -contains 'done') { if ($rows.Count -gt 0) { break } else { continue } }
            $k = $r.name + '#' + $i
            if ($seen.ContainsKey($r.name)) { break }
            $seen[$r.name] = $true
            $rows.Add($r)
        }
        return @($rows.ToArray())
    }

    function Test-Ring($r, [System.Collections.Generic.List[string]]$fails, [string]$mode) {
        $t = $mode + ':' + $r.name
        if ($r.opacity -lt 0.99 -or $r.visibility -ne 'visible') { $fails.Add($t + ':FOCUSED_ELEMENT_NOT_VISIBLE opacity=' + $r.opacity + ' visibility=' + $r.visibility); return }
        if ($r.oStyle -eq 'none' -or $r.oWidth -lt 2) { $fails.Add($t + ':NO_RING style=' + $r.oStyle + ' width=' + $r.oWidth); return }
        if ($mode -eq 'normal') {
            if ($r.oAlpha -lt 0.999) { $fails.Add($t + ':RING_NOT_OPAQUE alpha=' + $r.oAlpha); return }
            foreach ($x in @($r.ratios)) { if ($x -lt 3.0) { $fails.Add($t + ':RING_LOW_CONTRAST ' + $r.oColor + ' ratios=' + (@($r.ratios) -join ',')); break } }
            if ($r.clip -ne '' -and $r.clipOk -eq '') { $fails.Add($t + ':RING_CLIPPED_BY ' + $r.clip) }
            if ($r.expW -ne '' -and [double]$r.expW -ne $r.oWidth) { $fails.Add($t + ':GEOMETRY_WIDTH expected ' + $r.expW + ' got ' + $r.oWidth) }
            if ($r.expO -ne '' -and [double]$r.expO -ne $r.oOffset) { $fails.Add($t + ':GEOMETRY_OFFSET expected ' + $r.expO + ' got ' + $r.oOffset) }
        }
    }

    function Run-All([string]$tag, [hashtable]$cssOverride, [string]$bodyFrom, [string]$bodyTo, [string]$passes) {
        $dir = Join-Path $work $tag
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $path = Write-Doc $dir 'fixture' (Build-Body $bodyFrom $bodyTo) $cssOverride
        $fails = New-Object 'System.Collections.Generic.List[string]'
        Open-Fixture $path $false
        $names = @(((Invoke-KsJs $browser 'window.__ksProbeNames()') | ConvertFrom-Json) | ForEach-Object { $_ })
        if ($names.Count -lt 40) { $fails.Add('FIXTURE_TOO_SMALL=' + $names.Count) }
        if ($passes -ne 'forced') {
            $rows = @(Walk-Tab)
            $reached = @{}
            foreach ($r in $rows) { $reached[$r.name] = $true; if (-not $r.fv) { $fails.Add('normal:' + $r.name + ':NOT_FOCUS_VISIBLE_AFTER_TAB') }; Test-Ring $r $fails 'normal' }
            foreach ($n in $names) {
                $probe = (Invoke-KsJs $browser ('window.__ksByProbe("' + $n + '")')) | ConvertFrom-Json
                if ($probe.container -ne '' -or $probe.noTab -eq 'no') { continue }
                if (-not $reached.ContainsKey($n)) { $fails.Add('normal:' + $n + ':TARGET_NOT_REACHED_BY_TAB') }
            }
            foreach ($n in $names) {
                $probe = (Invoke-KsJs $browser ('window.__ksByProbe("' + $n + '")')) | ConvertFrom-Json
                if ($probe.container -ne '') {
                    $c = (Invoke-KsJs $browser ('window.__ksFocusContainer("' + $n + '")')) | ConvertFrom-Json
                    if ($c.active -and $c.style -ne 'none' -and $c.width -gt 0) { $fails.Add('normal:' + $n + ':CONTAINER_HAS_RING width=' + $c.width) }
                }
                if ($probe.noTab -eq 'no') {
                    $doc = Invoke-KsCdp $browser 'DOM.getDocument' @{ depth = 0 }
                    $q = Invoke-KsCdp $browser 'DOM.querySelector' @{ nodeId = $doc['root']['nodeId']; selector = ('[data-probe="' + $n + '"]') }
                    if ($q['nodeId'] -gt 0) {
                        $null = Invoke-KsCdp $browser 'CSS.forcePseudoState' @{ nodeId = $q['nodeId']; forcedPseudoClasses = @('focus', 'focus-visible') }
                        $fr = (Invoke-KsJs $browser ('window.__ksByProbe("' + $n + '")')) | ConvertFrom-Json
                        $null = Invoke-KsCdp $browser 'CSS.forcePseudoState' @{ nodeId = $q['nodeId']; forcedPseudoClasses = @() }
                        Test-Ring $fr $fails 'normal'
                    }
                }
            }
        }
        if ($passes -ne 'normal') {
            Open-Fixture $path $true
            $rows = @(Walk-Tab)
            $reached = @{}
            foreach ($r in $rows) { $reached[$r.name] = $true; Test-Ring $r $fails 'forced' }
            $states = @{}
            foreach ($n in $names) {
                $probe = (Invoke-KsJs $browser ('window.__ksByProbe("' + $n + '")')) | ConvertFrom-Json
                if ($probe.container -ne '') { continue }
                if ($probe.noTab -ne 'no' -and -not $reached.ContainsKey($n)) { $fails.Add('forced:' + $n + ':TARGET_NOT_REACHED_BY_TAB') }
                if ($probe.boundary -eq '1') {
                    # Il confine va provato SENZA focus (l'outline del focus non deve mascherarlo): lettura a riposo.
                    $null = Invoke-KsJs $browser 'document.activeElement && document.activeElement.blur && document.activeElement.blur(); 1'
                    $rest = (Invoke-KsJs $browser ('window.__ksByProbe("' + $n + '")')) | ConvertFrom-Json
                    if (-not ($rest.bwMax -gt 0 -and $rest.bsAny)) { $fails.Add('forced:' + $n + ':BOUNDARY_LOST_IN_FORCED_COLORS border=' + $rest.bwMax) }
                }
                if ($probe.statePair -ne '') {
                    $parts = $probe.statePair.Split(':')
                    if (-not $states.ContainsKey($parts[0])) { $states[$parts[0]] = @{} }
                    $states[$parts[0]][$parts[1]] = $probe.sig
                }
            }
            foreach ($k in $states.Keys) {
                if ($states[$k].ContainsKey('active') -and $states[$k].ContainsKey('rest') -and $states[$k]['active'] -eq $states[$k]['rest']) { $fails.Add('forced:' + $k + ':ACTIVE_STATE_NOT_DISTINGUISHABLE_FROM_ITS_SIBLING') }
            }
        }
        return @($fails.ToArray())
    }
    function Assert-Fails([string]$name, [hashtable]$cssOverride, [string]$mustContain, [string]$passes, [string]$bodyFrom, [string]$bodyTo) {
        $f = @(Run-All $name $cssOverride $bodyFrom $bodyTo $passes)
        if ($f.Count -eq 0) { throw ('MUTATION_NOT_DETECTED=' + $name) }
        if (-not (@($f | Where-Object { $_ -like ('*' + $mustContain + '*') }).Count)) { throw ('MUTATION_DETECTED_FOR_THE_WRONG_REASON=' + $name + ' wanted ' + $mustContain + ' got ' + (($f | Select-Object -First 5) -join ' | ')) }
        Write-Output ('PASS MUTATION_DETECTED ' + $name + ' (' + $f.Count + ' findings)')
    }

    # --- Stato reale ----------------------------------------------------------------------------------------------------------------------
    $real = @(Run-All 'real' $null '' '' 'both')
    if ($real.Count -gt 0) { $real | ForEach-Object { Write-Output ('FINDING ' + $_) }; throw 'REAL_CSS_FAILS_THE_KEYBOARD_FOCUS_ORACLE' }
    Write-Output 'PASS REAL_CSS_SHOWS_A_VISIBLE_ACCESSIBLE_RING_ON_EVERY_TAB_TARGET_AND_KEEPS_BOUNDARIES_AND_STATES_IN_FORCED_COLORS'

    # --- Mutazioni sul CSS (copie temporanee) ---------------------------------------------------------------------------------------------
    $flowCss = Read-Repo 'Public/assets/keepstore/css/catalog-product-flow.css'
    $cartCss = Read-Repo 'Public/assets/keepstore/css/cart-ui.css'
    $globalStart = $styles.IndexOf('/* ===== KS-A04-FOCUS-FORCED-COLORS-1A - focus da tastiera')
    if ($globalStart -lt 0) { throw 'GLOBAL_FOCUS_BLOCK_NOT_FOUND_IN_STYLES' }
    $globalBlock = $styles.Substring($globalStart)
    $stylesNoGlobal = $styles.Substring(0, $globalStart)
    Assert-Fails 'M01_form_input_base_outline_zero_back' @{ 'styles.css' = (Mutate-Text $styles "form input[type=color] {`n  -webkit-box-shadow: none;" "form input[type=color] {`n  outline: 0;`n  -webkit-box-shadow: none;" 'M01') } 'NO_RING' 'normal' '' ''
    Assert-Fails 'M02_global_ring_before_the_anchor_reset' @{ 'styles.css' = (Mutate-Text $stylesNoGlobal "a:focus, a:hover {" ($globalBlock + "`na:focus, a:hover {") 'M02') } 'NO_RING' 'normal' '' ''
    Assert-Fails 'M03_search_host_rule_removed' @{ 'styles.css' = (Mutate-Text $styles '.ks-search-host input[type="text"]:focus-visible' '.ks-removed-host input[type="text"]:focus-visible' 'M03') } 'hdr-search-input' 'normal' '' ''
    Assert-Fails 'M04_qty_button_outline_none_back' @{ 'catalog-product-flow.css' = ($flowCss + "`n.ks-qty-btn:focus{ outline: none; }`n") } 'card-qty' 'normal' '' ''
    Assert-Fails 'M05_cart_remove_low_alpha_back' @{ 'cart-ui.css' = ($cartCss + "`n.ks-cart-page .tf-table-page-cart .ks-cart-remove-cell .ks-cart-remove-button:focus-visible { outline: 3px solid rgba(216,0,39,.45); }`n") } 'cart-remove' 'normal' '' ''
    Assert-Fails 'M06_dark_band_white_ring_removed' @{ 'styles.css' = (Mutate-Text $styles '.ft-body-center.bg-gray :is(a, button, input):focus-visible' '.ft-body-center.removed-band :is(a, button, input):focus-visible' 'M06') } 'ft-news' 'normal' '' ''
    Assert-Fails 'M07_inset_ring_removed_for_swiper_and_wrapper' @{ 'styles.css' = (Mutate-Text (Mutate-Text (Mutate-Text $styles '.swiper a:focus-visible' '.removedswiper a:focus-visible' 'M07a') '.card-product-wrapper a:focus-visible' '.removedwrapper a:focus-visible' 'M07b') '.card-product a.name-product:focus-visible' '.card-product a.removed-name:focus-visible' 'M07c') } 'RING_CLIPPED_BY' 'normal' '' ''
    Assert-Fails 'M08_forced_guide_and_loadmore_border_removed' @{ 'theme-overrides.css' = (Mutate-Text $theme '.ks-guide-path, .ks-brand-loadmore {' '.removed-guide-path, .removed-brand-loadmore {' 'M08') } 'BOUNDARY_LOST_IN_FORCED_COLORS' 'forced' '' ''
    Assert-Fails 'M08b_forced_newsletter_border_removed' @{ 'theme-overrides.css' = (Mutate-Text $theme '.form-newsletter .subscribe-content input.subscribe-email {' '.form-newsletter .subscribe-content input.removed-email {' 'M08b') } 'ft-news' 'forced' '' ''
    Assert-Fails 'M09_forced_dropdown_border_loses_important' @{ 'theme-overrides.css' = (Mutate-Text $theme 'border: 1px solid ButtonText !important; /* KS-FC-DROPDOWN */' 'border: 1px solid ButtonText; /* KS-FC-DROPDOWN */' 'M09') } 'lang-toggle' 'forced' '' ''
    Assert-Fails 'M10_forced_active_states_disabled' @{ 'theme-overrides.css' = (Mutate-Text (Mutate-Text $theme '/* KS-FC-STATES */' '/* KS-FC-STATES */ @media (forced-colors: none) {' 'M10a') '/* KS-FC-STATES-END */' '} /* KS-FC-STATES-END */' 'M10b') } 'ACTIVE_STATE_NOT_DISTINGUISHABLE' 'forced' '' ''
    Assert-Fails 'M11_global_ring_with_important_overrides_local_geometry' @{ 'styles.css' = ($styles + "`na:focus-visible, button:focus-visible, input:focus-visible { outline-width: 2px !important; outline-offset: 2px !important; }`n") } 'GEOMETRY' 'normal' '' ''
    Assert-Fails 'M12_tabindex_selector_loses_the_where_and_beats_local_rings' @{ 'styles.css' = (Mutate-Text $styles ':where([tabindex]:not([tabindex^="-"])):focus-visible' '[tabindex]:not([tabindex^="-"]):focus-visible' 'M12') } 'GEOMETRY_WIDTH' 'normal' '' ''
    Assert-Fails 'M12b_tabindex_selector_includes_minus_one_containers' @{ 'styles.css' = (Mutate-Text $styles ':where([tabindex]:not([tabindex^="-"])):focus-visible' ':where([tabindex]):focus-visible' 'M12b') } 'CONTAINER_HAS_RING' 'normal' '' ''
    Assert-Fails 'M13_bootstrap_form_control_ring_removed' @{ 'styles.css' = (Mutate-Text $styles '.form-control:focus-visible' '.removed-form-control:focus-visible' 'M13') } 'bs-input' 'normal' '' ''
    Assert-Fails 'M14_probe_removed_from_the_tab_sequence' @{} 'TARGET_NOT_REACHED_BY_TAB' 'normal' 'data-probe="card-qty-plus">+</button>' 'data-probe="card-qty-plus" tabindex="-1">+</button>'
    $fallback = @(Run-All 'T01_token_removed_fallback_holds' @{ 'styles.css' = (Mutate-Text $styles '--focus-ring: #B8001F;' '/* token removed */' 'T01') } '' '' 'normal')
    if ($fallback.Count -gt 0) { throw ('FALLBACK_DOES_NOT_HOLD_WHEN_THE_TOKEN_IS_MISSING: ' + (($fallback | Select-Object -First 3) -join ' | ')) }
    Write-Output 'PASS TOKEN_REMOVED_THE_FALLBACK_KEEPS_THE_RING'

    # --- Guardia statica: nessun outline con alfa < 1 nei selettori :focus* dei fogli runtime; token definito e usato con fallback ------------------------
    $runtimeSheets = @('styles.css', 'theme-overrides.css', 'catalog-ui.css', 'catalog-filters-ui.css', 'catalog-product-flow.css', 'cart-ui.css', 'minicart-ui.css', 'product-ui.css', 'auth-ui.css', 'ks-ui.css', 'keepstore-overrides.css', 'keepstore.css', 'order-ui.css', 'account-ui.css', 'documents-ui.css', 'datiutente-ui.css')
    function Test-FocusRingGuard([string]$name, [string]$text) {
        $bad = New-Object System.Collections.Generic.List[string]
        $text = [regex]::Replace($text, '(?s)/\*.*?\*/', '')
        foreach ($m in [regex]::Matches($text, '(?s)([^{}]+)\{([^{}]*)\}')) {
            $sel = ($m.Groups[1].Value -replace '\s+', ' ').Trim(); $body = $m.Groups[2].Value
            if ($sel -notmatch ':focus' -or $sel -match '^\s*@') { continue }
            if ($sel -match ':not\(:focus-visible\)' -and $sel -notmatch ':focus-visible\s*[,{]|:focus-visible$') { continue }
            foreach ($d in [regex]::Matches($body, '(?i)(?<![a-z-])outline(?:-color)?\s*:\s*([^;]+)')) {
                $v = $d.Groups[1].Value
                foreach ($c in [regex]::Matches($v, '(?i)(rgba|hsla)\(([^)]*)\)')) {
                    $parts = $c.Groups[2].Value -split '[,/ ]+' | Where-Object { $_ -ne '' }
                    if ($parts.Count -ge 4 -and [double]$parts[3] -lt 1) { $bad.Add($name + ': ' + $sel.Substring(0, [Math]::Min(60, $sel.Length)) + ' => ' + $v.Trim()) }
                }
                if ($v -match '#[0-9a-fA-F]{8}\b' -or $v -match '#[0-9a-fA-F]{4}\b') { $bad.Add($name + ': ' + $sel.Substring(0, [Math]::Min(60, $sel.Length)) + ' => ' + $v.Trim()) }
            }
        }
        return $bad.ToArray()
    }
    $allBad = New-Object System.Collections.Generic.List[string]
    foreach ($s in $runtimeSheets) { foreach ($b in @(Test-FocusRingGuard $s (Read-Repo ('Public/assets/keepstore/css/' + $s)))) { $allBad.Add($b) } }
    if ($allBad.Count -gt 0) { $allBad | ForEach-Object { Write-Output ('LOW_ALPHA ' + $_) }; throw 'LOW_ALPHA_FOCUS_OUTLINES_REMAIN_IN_RUNTIME_SHEETS' }
    Write-Output 'PASS NO_FOCUS_OUTLINE_WITH_ALPHA_BELOW_ONE_IN_THE_RUNTIME_SHEETS'
    foreach ($case in @(@('G1_rgba_in_a_focus_visible_rule', ".x:focus-visible { outline: 3px solid rgba(216,0,39,.45); }"), @('G2_hsla_in_a_focus_rule', ".x:focus { outline: 2px solid hsla(0,100%,42%,.3); }"), @('G3_eight_digit_hex', ".x:focus-visible { outline-color: #d8002740; }"))) {
        if (@(Test-FocusRingGuard 'x.css' $case[1]).Count -eq 0) { throw ('MUTATION_NOT_DETECTED=' + $case[0]) }
        Write-Output ('PASS MUTATION_DETECTED ' + $case[0])
    }
    if (@(Test-FocusRingGuard 'x.css' ".x:focus:not(:focus-visible) { outline: 0; } .y:focus-visible { outline: 2px solid var(--focus-ring, #B8001F); } .z:hover { box-shadow: 0 0 0 2px rgba(0,0,0,.2); }").Count -ne 0) { throw 'GUARD_REJECTS_A_LEGITIMATE_RULE' }
    Write-Output 'PASS GUARD_ALLOWS_OPAQUE_RINGS_NOT_VISIBLE_RESETS_AND_NON_FOCUS_SHADOWS'
    Assert-Source ($styles -match '(?m)^\s*--focus-ring:\s*#B8001F;') 'FOCUS_RING_TOKEN_DEFINED_IN_ROOT'
    $withoutFallback = New-Object System.Collections.Generic.List[string]
    foreach ($s in $runtimeSheets) { $t = Read-Repo ('Public/assets/keepstore/css/' + $s); foreach ($m in [regex]::Matches($t, 'var\(\s*--focus-ring\s*\)')) { $withoutFallback.Add($s) } }
    if ($withoutFallback.Count -gt 0) { throw ('FOCUS_RING_USED_WITHOUT_FALLBACK_IN=' + (($withoutFallback | Select-Object -Unique) -join ',')) }
    Write-Output 'PASS EVERY_USE_OF_THE_TOKEN_HAS_A_FALLBACK'
    Assert-Source (Test-Busters $master $catalogAspx $productAspx $cartAspx) 'PAGES_LOAD_THE_SHEETS_WITH_THE_NEW_BUSTER'
    if (Test-Busters (Mutate-Text $master '"?v=20261119-compact-1a"' '"?v=20261115-palette-aa1a"' 'M15') $catalogAspx $productAspx $cartAspx) { throw 'MUTATION_NOT_DETECTED=M15_master_buster_not_bumped' }
    Write-Output 'PASS MUTATION_DETECTED M15_master_buster_not_bumped'

    Write-Output 'FOCUS_VISIBLE_ALL_PASS'
}
finally {
    if ($browser) { Stop-KsBrowser $browser }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
