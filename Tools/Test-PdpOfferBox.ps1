[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$ShotDir = '', [string]$Article = '21906', [string]$PlainArticle = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# PDP-OFFER-BOX-1A. Riquadro d'acquisto della scheda prodotto (linea di stile 3.6 e 3.7).
# Sotto il prezzo scontato: risparmio in euro e percentuale (regola unica dello sconto mostrato) e scadenza vera dell'offerta applicata.
# La scheda "Gia applicata al prezzo principale" non si ripete; le altre offerte stanno sotto il pulsante, raggiungibili da un collegamento
# accanto alla quantita; "Acquista" e l'unico pulsante pieno e su computer sta nella prima schermata; in stampa le offerte restano.
# I valori attesi si leggono dalla pagina stessa (prezzi stampati, righe "Promozione" di Informazioni prodotto), non sono scritti qui.
# Prova sul sito LAB (https, 127.0.0.1, porta 18843); mutazioni sulla copia LAB, file rimessi alla fine. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$css = 'Public\assets\keepstore\css\ks-pdp-offer-box.css'; $helper = 'App_Code\ProductPromotionDisplayHelper.vb'
$files = @('articolo.aspx', 'articolo.aspx.vb', $helper, $css)
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('PDP_OFFER_BOX FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'articolo.aspx'))) { Write-Host ('PDP_OFFER_BOX FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$base = 'https://www.taikun.it:18843'
$page = '/articolo.aspx?id=' + $Article
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); $crlf = (Get-Text $b).Contains("`r`n"); if ($crlf) { $text = $text.Replace("`r`n", "`n").Replace("`n", "`r`n") }; [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }

# ---- parte sorgente ----
function Test-Source {
    $bad = New-Object Collections.Generic.List[string]
    $a = Get-Text $repoBytes['articolo.aspx']; $vb = Get-Text $repoBytes['articolo.aspx.vb']; $h = Get-Text $repoBytes[$helper]
    if ($h -notmatch 'model\.Html = RenderHtml\(model, useNetPrices\)\s*model\.InfoHtml = RenderInfoHtml\(model, useNetPrices\)') { $bad.Add('S1 Html e InfoHtml non piu adiacenti nel modello') }
    if ($h -notmatch 'Public Function RenderBuyBoxOffersHtml\(') { $bad.Add('S2 funzione del riquadro assente nel modulo delle offerte') }
    if ($a -match 'ks-product-promos|box-sale-tag') { $bad.Add('S3 classi delle offerte o del bollino scritte nella pagina') }
    $others = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -eq '.vb' -and $_.FullName -notmatch '\\\.claude\\|\\\.git\\|\\Tools\\' -and $_.Name -ne 'articolo.aspx.vb' -and $_.Name -ne 'ProductPromotionDisplayHelper.vb' } | Where-Object { [IO.File]::ReadAllText($_.FullName) -match 'RenderBuyBoxOffersHtml' })
    if ($others.Count -gt 0) { $bad.Add('S4 la funzione del riquadro e chiamata fuori dalla scheda prodotto') }
    if ($vb -notmatch 'StorefrontPromotionDisplayPolicy\.Resolve\(price\.OldPrice\.Value, price\.CurrentPrice\.Value\)') { $bad.Add('S5 il risparmio non nasce dai due prezzi stampati') }
    return $bad
}

$stateJs = @'
(function(){
function vis(e){if(!e||!e.getClientRects().length)return false;var s=getComputedStyle(e);if(s.visibility==='hidden'||s.display==='none')return false;var b=e.getBoundingClientRect();return b.width>1&&b.height>1;}
function txt(e){return e?(e.textContent||'').replace(/\s+/g,' ').trim():'';}
function rc(e){var b=e.getBoundingClientRect();return {top:Math.round(b.top),bottom:Math.round(b.bottom),h:Math.round(b.height)};}
var box=document.querySelector('.tf-product-info-choose-option');var o={vh:innerHeight,vw:innerWidth,path:location.pathname+location.search,box:!!box};if(!box)return JSON.stringify(o);
var d=box.querySelector('.product-delivery');
o.price=txt(d.querySelector('.new-price'));o.old=txt(d.querySelector('.old-price'));
var note=d.querySelector('.price-text + p.body-text-3');o.note=txt(note);
var line=box.querySelector('.ks-pdp-offer-line');o.line=vis(line)?txt(line):'';o.lineAfterNote=!!(line&&note&&line.previousElementSibling===note);o.lineInDelivery=!!(line&&d.contains(line));
o.applied=/applicata al prezzo principale/i.test(txt(box));
var p=box.querySelector('.ks-product-promos');o.panel=vis(p);o.panelInDelivery=!!(p&&d.contains(p));o.panelRect=p?rc(p):null;
o.items=p?p.querySelectorAll('.ks-product-promos__item').length:0;o.count=p?txt(p.querySelector('.ks-product-promos__count')):'';
o.tiers=p?p.querySelectorAll('.ks-product-promos__item--tier').length:0;
var wrap=box.querySelector('.ks-pdp-offers');o.wrap=!!wrap;
var link=box.querySelector('.ks-pdp-offers-link');o.link=vis(link)?txt(link):'';o.linkHref=link?String(link.getAttribute('href')||''):'';
var btn=document.getElementById('MainContent_btnAddToCart');o.buy=btn?rc(btn):null;
var btns=box.querySelector('.product-box-btn');o.btns=btns?rc(btns):null;
var cart=btns?btns.querySelector('a[href="/carrello.aspx"]'):null;
if(cart){var cs=getComputedStyle(cart);o.cart={bg:cs.backgroundColor,color:cs.color,border:cs.borderTopColor,bw:cs.borderTopWidth,h:Math.round(cart.getBoundingClientRect().height),cls:String(cart.className)};}
var ship=box.querySelector('.shipping-to');o.ship=ship?rc(ship):null;
var q=box.querySelector('.product-quantity .title');o.qtyLabel=txt(q).replace(txt(link),'').trim();
var rows=[].slice.call(document.querySelectorAll('.ks-pdp-info-promo'));o.infoRows=rows.length;
var ap=rows.filter(function(r){return r.querySelector('.ks-pdp-info-promo__applied');})[0];o.appliedDates=ap?txt(ap.querySelector('.ks-pdp-info-promo__dates')):'';
var tr=rows.filter(function(r){return !r.querySelector('.ks-pdp-info-promo__applied');})[0];o.otherDates=tr?txt(tr.querySelector('.ks-pdp-info-promo__dates')):'';
var bar=document.querySelector('.ks-pdp-buybar');o.bar=vis(bar)?txt(bar):'';
o.links=[].slice.call(document.querySelectorAll('a[href*="articolo.aspx?id="]')).map(function(x){var m=/[?&]id=(\d+)/.exec(x.getAttribute('href'));return m?m[1]:'';}).filter(function(v,i,a){return v&&a.indexOf(v)===i;}).slice(0,12);
return JSON.stringify(o);})()
'@
function Read-State($browser) { return (ConvertFrom-Json ([string](Invoke-KsJs $browser $stateJs))) }
function Open-Page($browser, [string]$path) {
    try { $null = Invoke-KsCdp $browser 'Network.enable' @{}; $null = Invoke-KsCdp $browser 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
    Open-KsUrl $browser ($base + $path) 300
    if ([string](Invoke-KsJs $browser 'location.origin') -ne $base) { throw 'ORIGINE_INATTESA' }
    $null = Invoke-KsJs $browser "(function(){var st=document.createElement('style');st.textContent='*,*::before,*::after{animation:none!important;transition:none!important;scroll-behavior:auto!important}';document.head.appendChild(st);return 1;})()"
    Start-Sleep -Milliseconds 1200
}
function To-Number([string]$t) { $m = [regex]::Match($t, '(\d{1,3}(?:\.\d{3})*|\d+),(\d{2})'); if (-not $m.Success) { return $null }; return [decimal]::Parse(($m.Groups[1].Value.Replace('.', '') + '.' + $m.Groups[2].Value), [Globalization.CultureInfo]::InvariantCulture) }
function Rgb([string]$c) { $m = [regex]::Match($c, 'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?'); if (-not $m.Success) { return $null }; return @([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value, $(if ($m.Groups[4].Success) { [double]::Parse($m.Groups[4].Value, [Globalization.CultureInfo]::InvariantCulture) } else { 1.0 })) }
function Lum($c) { $v = @(); foreach ($i in 0..2) { $x = $c[$i] / 255.0; $v += $(if ($x -le 0.03928) { $x / 12.92 } else { [Math]::Pow(($x + 0.055) / 1.055, 2.4) }) }; return 0.2126 * $v[0] + 0.7152 * $v[1] + 0.0722 * $v[2] }

# Controlli comuni del riquadro con sconto mostrato. $tag distingue telefono e computer nei messaggi.
function Test-Offer($s, [string]$tag) {
    $bad = New-Object Collections.Generic.List[string]
    if (-not [bool]$s.box) { $bad.Add($tag + ' NON PROVATO: riquadro assente'); return $bad }
    $new = To-Number ([string]$s.price); $old = To-Number ([string]$s.old)
    if ($null -eq $new -or $null -eq $old -or $old -le $new) { $bad.Add($tag + ' NON PROVATO: l''articolo ' + $Article + ' non ha piu uno sconto mostrato (serve un articolo con prezzo barrato)'); return $bad }
    $saving = $old - $new; $pct = [Math]::Min(99, [int][Math]::Round(($saving / $old) * 100, 0, [MidpointRounding]::AwayFromZero))
    $wantSaving = 'Risparmi ' + $saving.ToString('N2', [Globalization.CultureInfo]::GetCultureInfo('it-IT')) + ' (-' + $pct + '%)'
    if ([string]$s.line -eq '') { $bad.Add($tag + ' riga dell''offerta assente sotto il prezzo') }
    else {
        if (-not ([string]$s.line).Contains($wantSaving)) { $bad.Add($tag + ' riga dell''offerta: atteso "' + $wantSaving + '", letto "' + [string]$s.line + '"') }
        $end = [regex]::Match([string]$s.appliedDates, 'al (\d{2}/\d{2}/\d{4})\s*$')
        if ($end.Success) { if (-not ([string]$s.line).Contains('fino al ' + $end.Groups[1].Value)) { $bad.Add($tag + ' scadenza: attesa "fino al ' + $end.Groups[1].Value + '", letto "' + [string]$s.line + '"') } }
        elseif ([string]$s.line -match 'fino al') { $bad.Add($tag + ' scadenza scritta senza una data di fine dell''offerta applicata') }
        if (-not [bool]$s.lineAfterNote -or -not [bool]$s.lineInDelivery) { $bad.Add($tag + ' posizione: la riga dell''offerta non segue la nota IVA') }
    }
    if ([string]$s.note -notmatch 'IVA') { $bad.Add($tag + ' nota IVA non piu accanto al prezzo') }
    if ([bool]$s.applied) { $bad.Add($tag + ' ripetizione: "applicata al prezzo principale" ancora nel riquadro') }
    $wantItems = [int]$s.infoRows - 1
    if ($wantItems -lt 1) { $bad.Add($tag + ' NON PROVATO: l''articolo non ha altre offerte oltre a quella applicata') }
    else {
        if (-not [bool]$s.panel -or [int]$s.items -ne $wantItems) { $bad.Add($tag + ' offerte rimaste: attese ' + $wantItems + ', trovate ' + [int]$s.items) }
        elseif (-not ([string]$s.count).StartsWith([string]$wantItems + ' ')) { $bad.Add($tag + ' contatore delle offerte: "' + [string]$s.count + '"') }
        if ([bool]$s.panelInDelivery -or ($null -ne $s.panelRect -and $null -ne $s.btns -and [int]$s.panelRect.top -lt [int]$s.btns.bottom)) { $bad.Add($tag + ' ordine: le offerte stanno ancora sopra il pulsante') }
        $wantLink = $(if ([int]$s.tiers -gt 0) { 'Offerte a quantit' } else { 'Altre offerte' })
        if (-not ([string]$s.link).StartsWith($wantLink)) { $bad.Add($tag + ' collegamento alle offerte: "' + [string]$s.link + '"') }
    }
    if ($null -eq $s.cart) { $bad.Add($tag + ' NON PROVATO: collegamento al carrello assente') }
    else {
        $bg = Rgb ([string]$s.cart.bg); $fg = Rgb ([string]$s.cart.color); $bd = Rgb ([string]$s.cart.border)
        if ($null -ne $bg -and $bg[3] -gt 0.05 -and (Lum $bg) -lt 0.8) { $bad.Add($tag + ' gerarchia: "Vai al carrello" e ancora un pulsante pieno (' + [string]$s.cart.bg + ')') }
        if ($null -ne $fg -and (Lum $fg) -gt 0.4) { $bad.Add($tag + ' gerarchia: testo di "Vai al carrello" chiaro (' + [string]$s.cart.color + ')') }
        if ($null -ne $bd -and ((1.05) / ((Lum $bd) + 0.05)) -lt 3) { $bad.Add($tag + ' gerarchia: bordo di "Vai al carrello" poco visibile (' + [string]$s.cart.border + ')') }
        if ([int]$s.cart.h -lt 44) { $bad.Add($tag + ' gerarchia: "Vai al carrello" alto ' + [int]$s.cart.h + ' px') }
    }
    if ([string]$s.qtyLabel -notmatch '^Quantit.$' -or [string]$s.qtyLabel -eq 'Quantita') { $bad.Add($tag + ' etichetta della quantita: "' + [string]$s.qtyLabel + '"') }
    return $bad
}

function Find-Plain($browser, $s) {
    if ($PlainArticle -ne '') { return $PlainArticle }
    foreach ($id in @($s.links)) {
        if ([string]$id -eq $Article) { continue }
        Open-Page $browser ('/articolo.aspx?id=' + $id)
        $p = Read-State $browser
        if ([bool]$p.box -and [string]$p.price -match '\d' -and [string]$p.old -eq '' -and [int]$p.infoRows -eq 0) { return [string]$id }
    }
    return ''
}

function Invoke-Phone($browser) {
    $bad = New-Object Collections.Generic.List[string]
    Open-Page $browser $page
    $s = Read-State $browser
    if ($ShotDir -ne '') { Save-KsScreenshot $browser (Join-Path $ShotDir 'offerta-390.png') -FullPage }
    foreach ($x in (Test-Offer $s 'A')) { $bad.Add($x) }
    if ($bad.Count -gt 0) { return $bad }
    # B: il collegamento porta le offerte in vista
    $null = Invoke-KsJs $browser "(function(){var a=document.querySelector('.ks-pdp-offers-link');a.scrollIntoView({block:'center'});a.click();return 1;})()"; Start-Sleep -Milliseconds 900
    $b1 = Read-State $browser
    if ($null -eq $b1.panelRect -or [int]$b1.panelRect.top -lt 0 -or [int]$b1.panelRect.top -gt [int]$b1.vh - 80) { $bad.Add('B collegamento: le offerte non sono in vista (' + $(if ($null -ne $b1.panelRect) { [string]$b1.panelRect.top } else { '-' }) + ' px)') }
    if ([string]$b1.path -ne $page) { $bad.Add('B collegamento: la pagina e cambiata') }
    # C: barra fissa su telefono con prezzo e nota IVA
    $null = Invoke-KsJs $browser "window.scrollTo({top:2600,behavior:'instant'});1"; Start-Sleep -Milliseconds 900
    $c1 = Read-State $browser
    if ([string]$c1.bar -eq '') { $bad.Add('C barra fissa NON PROVATA: non visibile dopo lo scorrimento') }
    elseif ([string]$c1.bar -notmatch 'IVA' -or -not ([string]$c1.bar).Contains([string]$s.price)) { $bad.Add('C barra fissa: prezzo o nota IVA persi ("' + [string]$c1.bar + '")') }
    # D: stampa
    $null = Invoke-KsJs $browser "window.scrollTo({top:0,behavior:'instant'});1"
    $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ media = 'print' }; Start-Sleep -Milliseconds 500
    try {
        $d1 = Read-State $browser
        if (-not [bool]$d1.panel) { $bad.Add('D stampa: le offerte non sono stampate') }
        if ([string]$d1.line -eq '') { $bad.Add('D stampa: la riga dell''offerta non e stampata') }
    } finally { $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ media = '' } }
    # E: articolo senza promozione
    $plain = Find-Plain $browser $s
    if ($plain -eq '') { $bad.Add('E NON PROVATO: nessun articolo senza promozione fra i collegati (usare -PlainArticle)') }
    else {
        Open-Page $browser ('/articolo.aspx?id=' + $plain)
        $e1 = Read-State $browser
        if ([string]$e1.line -ne '' -or [bool]$e1.wrap -or [bool]$e1.panel -or [string]$e1.link -ne '') { $bad.Add('E senza promozione (' + $plain + '): riga, blocco o collegamento presenti') }
        if ($null -ne $e1.btns -and $null -ne $e1.ship -and ([int]$e1.ship.top - [int]$e1.btns.bottom) -gt 24) { $bad.Add('E senza promozione: spazio vuoto fra pulsanti e spedizione (' + ([int]$e1.ship.top - [int]$e1.btns.bottom) + ' px)') }
    }
    return $bad
}

function Invoke-Desktop($browser) {
    $bad = New-Object Collections.Generic.List[string]
    $null = Invoke-KsCdp $browser 'Emulation.setDeviceMetricsOverride' @{ width = 1280; height = 761; deviceScaleFactor = 1; mobile = $false }
    Open-Page $browser $page
    $s = Read-State $browser
    if ($ShotDir -ne '') { Save-KsScreenshot $browser (Join-Path $ShotDir 'offerta-1280.png') }
    foreach ($x in (Test-Offer $s 'F')) { $bad.Add($x) }
    if ($null -eq $s.buy) { $bad.Add('G NON PROVATO: pulsante Acquista assente'); return $bad }
    if ([int]$s.buy.bottom -gt [int]$s.vh) { $bad.Add('G prima schermata: "Acquista" finisce a ' + [int]$s.buy.bottom + ' px su ' + [int]$s.vh) }
    # con un riquadro variante simulato (stessa altezza di quello vero: etichetta + tendina)
    $null = Invoke-KsJs $browser "(function(){var q=document.querySelector('.tf-product-info-choose-option .product-quantity');var v=document.createElement('div');v.className='product-color';v.style.height='98px';q.parentNode.insertBefore(v,q);return 1;})()"; Start-Sleep -Milliseconds 300
    $g2 = Read-State $browser
    if ([int]$g2.buy.bottom -gt [int]$g2.vh) { $bad.Add('G prima schermata con variante: "Acquista" finisce a ' + [int]$g2.buy.bottom + ' px su ' + [int]$g2.vh) }
    return $bad
}

function Invoke-All {
    $out = New-Object Collections.Generic.List[string]
    $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 390 -Height 844 -Mobile
    try { foreach ($x in (Invoke-Phone $b)) { $out.Add($x) } } finally { Stop-KsBrowser $b }
    $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900
    try { foreach ($x in (Invoke-Desktop $b)) { $out.Add($x) } } finally { Stop-KsBrowser $b }
    return $out
}

$exit = 0
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
if ($ShotDir -ne '') { New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null }
$siteBefore = @{}; foreach ($f in $files) { $p = Join-Path $SitePath $f; if (Test-Path -LiteralPath $p) { $siteBefore[$f] = $true } }
try {
    $src = @(Test-Source)
    if ($src.Count -gt 0) { $exit = 1; foreach ($b in $src) { Write-Host ('  FAIL ' + $b) } }
    Sync-Site
    $bad = @(Invoke-All)
    if ($bad.Count -eq 0 -and $exit -eq 0) { Write-Host '  ok   riquadro d''acquisto: riga dell''offerta, ordine, gerarchia, stampa (390 px e 1280 x 761)' } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 14)) { Write-Host ('  FAIL ' + $b) } }
    if (-not $SkipMutants -and $exit -eq 0) {
        $mutants = @(
            @{ Id = 'M01_LINE_WITHOUT_SHOWN_DISCOUNT_RULE'; File = 'articolo.aspx.vb'; Expect = 'A riga dell''offerta: atteso'; Old = 'StorefrontPromotionDisplayPolicy.Resolve(price.OldPrice.Value, price.CurrentPrice.Value)'; New = 'StorefrontPromotionDisplayPolicy.Resolve(price.OldPrice.Value + 1D, price.CurrentPrice.Value)' },
            @{ Id = 'M02_DEADLINE_FROM_QUANTITY_TIER'; File = 'articolo.aspx.vb'; Expect = 'A scadenza'; Old = 'promotionModel.BestDefaultQuantityEndsOn.Value.ToString('; New = 'promotionModel.BestDefaultQuantityEndsOn.Value.AddDays(3).ToString(' },
            @{ Id = 'M03_APPLIED_CARD_NOT_REMOVED'; File = $helper; Expect = 'A ripetizione'; Old = 'If omitAppliedOffer AndAlso isPrimaryImmediate Then Continue For'; New = 'If False AndAlso isPrimaryImmediate Then Continue For' },
            @{ Id = 'M04_ALL_OFFERS_REMOVED'; File = $helper; Expect = 'A offerte rimaste'; Old = 'If omitAppliedOffer AndAlso isPrimaryImmediate Then Continue For'; New = 'If omitAppliedOffer Then Continue For' },
            @{ Id = 'M05_COUNTER_NOT_RECOUNTED'; File = $helper; Expect = 'A contatore'; Old = 'Dim shownCount As Integer = shown.Count'; New = 'Dim shownCount As Integer = model.Offers.Count' },
            @{ Id = 'M06_PRINT_RULE_REMOVED'; File = $css; Expect = 'D stampa: le offerte'; Old = '  .ks-product-page .tf-product-info-choose-option > .ks-pdp-offers {'; New = '  .ks-product-page .tf-product-info-choose-option > .ks-pdp-offers-off {' },
            @{ Id = 'M07_SECONDARY_BUTTON_FILLED'; File = 'articolo.aspx'; Expect = 'A gerarchia'; Old = 'class="tf-btn btn-line ks-pdp-cart-link" href="/carrello.aspx"'; New = 'class="tf-btn text-white btn-gray ks-pdp-cart-link" href="/carrello.aspx"' },
            @{ Id = 'M08_LINE_BEFORE_VAT_NOTE'; File = 'articolo.aspx'; Expect = 'A posizione'; Old = '<p class="body-text-3 text-main-2"><asp:Literal ID="litPriceDisplayLabel" runat="server" Mode="Encode" /></p>' + "`n" + '                                            <asp:Literal ID="litOfferLine" runat="server" EnableViewState="false" />'; New = '<asp:Literal ID="litOfferLine" runat="server" EnableViewState="false" />' + "`n" + '                                            <p class="body-text-3 text-main-2"><asp:Literal ID="litPriceDisplayLabel" runat="server" Mode="Encode" /></p>' },
            @{ Id = 'M09_SHEET_NOT_INCLUDED'; File = 'articolo.aspx'; Expect = 'A gerarchia'; Old = 'css/ks-pdp-offer-box.css'; New = 'css/ks-pdp-offer-box-off.css' },
            @{ Id = 'M10_LINK_WITHOUT_OFFERS'; File = 'articolo.aspx.vb'; Expect = 'E senza promozione'; Old = 'phOffersLink.Visible = hasBuyBoxOffers'; New = 'phOffersLink.Visible = True' }
        )
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
            $text = (Get-Text $repoBytes[$mu.File]).Replace("`r`n", "`n")
            $i0 = $text.IndexOf($mu.Old, [StringComparison]::Ordinal)
            if ($i0 -lt 0 -or $i0 -ne $text.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            Write-SiteText $mu.File $text.Replace($mu.Old, $mu.New)
            try {
                $mb = @(Invoke-All)
                if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' | ')); $exit = 1 }
            } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
            finally { Write-Site $mu.File $repoBytes[$mu.File] }
        }
    }
} finally {
    Sync-Site
    foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
}
if ($exit -eq 0) { Write-Host ('PDP_OFFER_BOX PASS' + $(if ($SkipMutants) { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (10 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'PDP_OFFER_BOX FAIL' }
exit $exit
