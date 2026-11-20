[CmdletBinding()]
param([switch]$SkipMutants, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# CART-RECENT-LAYOUT-1B. Schede "Visti di recente" del carrello allineate (richiesta del PO del 2026-11-20: i prezzi "sono disallineati
# con gli altri"). Difetto: il titolo della scheda vuole due righe (-webkit-line-clamp: 2) ma contiene un collegamento che il foglio
# generale rende un blocco in linea: il taglio non entra nel blocco e il titolo cresce a 3 o 4 righe, spostando prezzo e pulsante;
# sotto 768 px il prezzo toccava il pulsante. Regole provate nel browser sulla pagina vera del sito LAB (https, 127.0.0.1, porta 18843),
# con nomi lunghi veri, a 1280 (4 colonne), 800 (2 colonne), 700 e 390 px (1 colonna):
#  - titolo visibile e mai piu alto di due righe; prezzo e pulsante non coperti dal titolo;
#  - prezzo, pulsante e altezza della scheda uguali in tutte le schede; almeno 12 px fra prezzo e pulsante;
#  - da tastiera il contorno sta sul titolo intero (il titolo non taglia il proprio contorno) e resta dentro la scheda.
# (A) sorgente, (B) misure, (C) mutazioni eseguite nel browser sul foglio caricato, ciascuna uccisa dal SUO controllo.
# Il test copia nella cartella del sito LAB i soli file cart-ui.css e carrello.aspx della copia di lavoro. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$token = '20261120-recent-1b'
$fail = New-Object Collections.Generic.List[string]

# ---------- (A) sorgente ----------
$css = [IO.File]::ReadAllText((Join-Path $root 'Public\assets\keepstore\css\cart-ui.css'), $utf8)
$page = [IO.File]::ReadAllText((Join-Path $root 'carrello.aspx'), $utf8)
function Get-Rule([string]$selector) {
    $i = $css.IndexOf($selector + '{', [StringComparison]::Ordinal); if ($i -lt 0) { return '' }
    return $css.Substring($i, $css.IndexOf('}', $i) - $i)
}
if ((Get-Rule '.ks-rv-name a') -notmatch 'display:\s*inline;') { $fail.Add('S01 il collegamento dentro il titolo scorre in linea (il taglio a due righe puo agire)') }
if ((Get-Rule '.ks-rv-price') -notmatch 'margin-bottom:\s*14px;') { $fail.Add('S02 distacco minimo sotto il prezzo') }
if ((Get-Rule '.ks-rv-name:has(a:focus-visible)') -notmatch 'outline:\s*3px solid currentColor;') { $fail.Add('S03 contorno da tastiera sul titolo intero') }
if ((Get-Rule '.ks-rv-section .ks-rv-name a:focus-visible') -notmatch 'outline:\s*none;') { $fail.Add('S04 nessun contorno tagliato sul collegamento interno') }
if (-not $page.Contains('css/cart-ui.css") & "?v=' + $token + '"')) { $fail.Add('S05 nuova sigla del foglio del carrello') }
foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) }

# ---------- (B) browser sul sito LAB ----------
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'carrello.aspx'))) { Write-Host ('CART_RECENT_LAYOUT FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
foreach ($rel in @('Public\assets\keepstore\css\cart-ui.css', 'carrello.aspx')) {
    $a = [IO.File]::ReadAllBytes((Join-Path $root $rel)); $bPath = Join-Path $SitePath $rel
    if (-not (Test-Path -LiteralPath $bPath) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($bPath)) -ne [Convert]::ToBase64String($a)) { [IO.File]::WriteAllBytes($bPath, $a); Write-Host ('  sito LAB: ' + $rel + ' allineato alla copia di lavoro') }
}
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$base = 'https://www.taikun.it:18843'
$visit = @(15499, 16100, 19765, 20225, 20033, 21906, 13736, 19209)      # nomi lunghi veri (fino a 4 righe prima della correzione)
$measureJs = "(function(){var o=[];var cs=document.querySelectorAll('.ks-rv-card');for(var i=0;i<cs.length;i++){var c=cs[i];c.scrollIntoView({block:'center',behavior:'instant'});var rc=c.getBoundingClientRect(),n=c.querySelector('.ks-rv-name'),a=n?n.querySelector('a'):null,p=c.querySelector('.ks-rv-price'),l=c.querySelector('a.ks-rv-link'),im=c.querySelector('img');if(!n||!a||!p||!l){o.push({bad:1});continue;}" +
             "var nr=n.getBoundingClientRect(),pr=p.getBoundingClientRect(),lr=l.getBoundingClientRect(),ar=a.getClientRects();var ep=document.elementFromPoint(pr.left+Math.min(pr.width/2,12),pr.top+pr.height/2),el=document.elementFromPoint(lr.left+lr.width/2,lr.top+lr.height/2);var shown=a.textContent.trim().replace(/\.\.\.$/,'').trim();var alt=im?(im.getAttribute('alt')||''):'';" +
             "o.push({bad:0,h:Math.round(rc.height),nameH:Math.round(nr.height),lineH:parseFloat(getComputedStyle(n).lineHeight),aW:ar.length?Math.round(ar[0].width):0,aH:ar.length?Math.round(ar[0].height):0,priceY:Math.round(pr.top-rc.top),linkY:Math.round(lr.top-rc.top),gap:Math.round(lr.top-pr.bottom),priceHit:(ep===p||p.contains(ep))?1:0,linkHit:(el===l||l.contains(el))?1:0,text:shown.length,altOk:(shown.length>0&&alt.indexOf(shown)===0)?1:0,href:a.getAttribute('href')||''});}" +
             "return JSON.stringify({cards:o,scroll:document.documentElement.scrollWidth-document.documentElement.clientWidth});})()"
# Dopo un Tab vero dal collegamento dell'immagine: stato del collegamento del titolo e rettangolo del contorno.
$focusPrepJs = "(function(){var c=document.querySelector('.ks-rv-card');c.scrollIntoView({block:'center',behavior:'instant'});c.querySelector('a.ks-rv-image-link').focus();return 1;})()"
$focusReadJs = "(function(){var c=document.querySelector('.ks-rv-card'),n=c.querySelector('.ks-rv-name'),a=n.querySelector('a');var sn=getComputedStyle(n),sa=getComputedStyle(a),rc=c.getBoundingClientRect(),nr=n.getBoundingClientRect();var w=parseFloat(sn.outlineWidth)||0,off=parseFloat(sn.outlineOffset)||0,e=w+off;" +
               "return JSON.stringify({active:document.activeElement===a?1:0,fv:a.matches(':focus-visible')?1:0,aStyle:sa.outlineStyle,nStyle:sn.outlineStyle,nWidth:w,inside:(sn.outlineStyle!=='none'&&w>=2&&nr.left-e>=rc.left&&nr.right+e<=rc.right&&nr.top-e>=rc.top&&nr.bottom+e<=rc.bottom)?1:0});})()"
function Get-MutJs([string]$selector, [string]$prop, [string]$value) {
    $set = if ($value -eq '') { "rs[q].style.removeProperty('$prop');" } else { "rs[q].style.setProperty('$prop','$value');" }
    return "(function(){var n=0;for(var k=0;k<document.styleSheets.length;k++){var rs;try{rs=document.styleSheets[k].cssRules;}catch(e){continue;}for(var q=0;q<rs.length;q++){if(rs[q].selectorText==='$selector'&&rs[q].style.getPropertyValue('$prop')){" + $set + "n++;}}}return n;})()"
}
$mutants = @(
    @{ Id = 'M01_TITLE_LINK_BLOCK'; Js = (Get-MutJs '.ks-rv-name a' 'display' 'inline-block'); Kill = 'piu di due righe'; Widths = @(1280, 800, 390) },      # a 700 px (una colonna larga) i nomi stanno comunque in due righe
    @{ Id = 'M02_NO_PRICE_MARGIN'; Js = (Get-MutJs '.ks-rv-price' 'margin-bottom' ''); Kill = 'dal pulsante'; Widths = @(700, 390) },
    @{ Id = 'M03_NO_TITLE_RING'; Js = (Get-MutJs '.ks-rv-name:has(a:focus-visible)' 'outline' ''); Kill = 'contorno'; Widths = @(1280) }
)
function Set-Width($browser, [int]$w, [int]$h) { $null = Invoke-KsCdp $browser 'Emulation.setDeviceMetricsOverride' @{ width = $w; height = $h; deviceScaleFactor = 1; mobile = $false } }
function Open-Cart($browser) { Open-KsUrl $browser ($base + '/carrello.aspx') 300; Start-Sleep -Milliseconds 1200 }
# Elenco dei difetti di una misura (vuoto = tutto giusto).
function Test-Layout($browser, [string]$tag) {
    $bad = New-Object Collections.Generic.List[string]
    $m = ConvertFrom-Json ([string](Invoke-KsJs $browser $measureJs))
    $cards = @($m.cards)
    if ($cards.Count -lt 4) { $bad.Add($tag + ' schede lette: ' + $cards.Count + ' (minimo 4)'); return $bad.ToArray() }
    if (@($cards | Where-Object { $_.bad -eq 1 }).Count -gt 0) { $bad.Add($tag + ' scheda senza titolo, prezzo o pulsante'); return $bad.ToArray() }
    if (@($cards | Where-Object { $_.text -ge 50 }).Count -lt 3) { $bad.Add($tag + ' meno di 3 titoli lunghi: la prova non direbbe nulla') }
    foreach ($c in $cards) {
        $mm = [regex]::Match([string]$c.href, '^articolo\.aspx\?id=(\d+)')
        if (-not $mm.Success -or $visit -notcontains [int]$mm.Groups[1].Value) { $bad.Add($tag + ' scheda di un articolo non visitato o senza collegamento') }
        if ($c.aW -lt 20 -or $c.aH -lt 10) { $bad.Add($tag + ' collegamento del titolo non visibile') }
        if ($c.nameH -gt [Math]::Round(2 * $c.lineH) + 1) { $bad.Add($tag + ' titolo alto ' + $c.nameH + ' px (piu di due righe)') }
        if ($c.gap -lt 12) { $bad.Add($tag + ' prezzo a ' + $c.gap + ' px dal pulsante (minimo 12)') }
        if ($c.priceHit -ne 1 -or $c.linkHit -ne 1) { $bad.Add($tag + ' prezzo o pulsante coperti da un altro elemento') }
        if ($c.altOk -ne 1) { $bad.Add($tag + ' il nome intero dell''immagine non inizia con il titolo mostrato') }
    }
    foreach ($f in @(@{ P = 'priceY'; T = 'prezzi a distanze diverse dall''alto della scheda' }, @{ P = 'linkY'; T = 'pulsanti a distanze diverse dall''alto della scheda' }, @{ P = 'h'; T = 'schede di altezza diversa' })) {
        $v = @($cards | ForEach-Object { [int]$_.($f.P) })
        if ((($v | Measure-Object -Maximum).Maximum - ($v | Measure-Object -Minimum).Minimum) -gt 1) { $bad.Add($tag + ' ' + $f.T + ': ' + (($v | Select-Object -Unique) -join ',')) }
    }
    if ([int]$m.scroll -gt 1) { $bad.Add($tag + ' scorrimento orizzontale ' + $m.scroll) }
    # contorno da tastiera: Tab vero dal collegamento dell'immagine al collegamento del titolo
    $null = Invoke-KsJs $browser $focusPrepJs
    $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' @{ type = 'rawKeyDown'; key = 'Tab'; code = 'Tab'; windowsVirtualKeyCode = 9; nativeVirtualKeyCode = 9 }
    $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' @{ type = 'keyUp'; key = 'Tab'; code = 'Tab'; windowsVirtualKeyCode = 9; nativeVirtualKeyCode = 9 }
    Start-Sleep -Milliseconds 250
    $f = ConvertFrom-Json ([string](Invoke-KsJs $browser $focusReadJs))
    if ($f.active -ne 1 -or $f.fv -ne 1) { $bad.Add($tag + ' il Tab non arriva al collegamento del titolo: la prova del contorno non direbbe nulla') }
    elseif ($f.inside -ne 1 -or $f.aStyle -ne 'none') { $bad.Add($tag + ' contorno da tastiera assente, tagliato o fuori dalla scheda (titolo: ' + $f.nStyle + ' ' + $f.nWidth + ' px, collegamento: ' + $f.aStyle + ')') }
    return $bad.ToArray()
}

$browserFail = New-Object Collections.Generic.List[string]
$killed = 0; $expected = 0
$b = $null
try {
    $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width 1280 -Height 900
    foreach ($id in $visit) { Open-KsUrl $b ($base + '/articolo.aspx?id=' + $id) 300; Start-Sleep -Milliseconds 500 }
    Open-KsUrl $b ($base + '/articoli.aspx') 300
    $ready = $false
    for ($k = 0; $k -lt 40 -and -not $ready; $k++) { $ready = ([string](Invoke-KsJs $b "document.querySelector('button.js-ks-cart-link')?1:0") -eq '1'); if (-not $ready) { Start-Sleep -Milliseconds 500 } }
    if (-not $ready) { throw ('nessun pulsante di acquisto nell''elenco: ' + [string](Invoke-KsJs $b 'document.title + " | " + location.href + " | schede " + document.querySelectorAll(".card-product").length')) }
    Invoke-KsClick $b 'button.js-ks-cart-link' -NoWait; Start-Sleep -Seconds 5
    foreach ($w in @(1280, 800, 700, 390)) {
        $tag = 'B' + $w
        Set-Width $b $w 900
        Open-Cart $b
        $bad = @(Test-Layout $b $tag)
        foreach ($x in ($bad | Select-Object -Unique)) { $browserFail.Add($x) }
        Write-Host ('  ' + $tag + ': difetti ' + $bad.Count)
        if ($bad.Count -ne 0 -or $fail.Count -ne 0 -or $SkipMutants) { continue }
        foreach ($mu in $mutants) {
            if ($mu.Widths -notcontains $w) { continue }
            $expected++
            Open-Cart $b
            $n = [int](Invoke-KsJs $b $mu.Js)
            if ($n -ne 1) { $browserFail.Add($tag + ' ' + $mu.Id + ' regola trovata ' + $n + ' volte (attesa 1)'); continue }
            Start-Sleep -Milliseconds 300
            $mb = @(Test-Layout $b $tag | Where-Object { $_ -like ('*' + $mu.Kill + '*') })
            if ($mb.Count -eq 0) { $browserFail.Add($tag + ' ' + $mu.Id + ' sopravvive') } else { $killed++; Write-Host ('  ucciso ' + $mu.Id + ' a ' + $w + ' px: ' + $mb[0]) }
        }
    }
} catch { $browserFail.Add('browser: ' + $_.Exception.Message) } finally { if ($b) { Stop-KsBrowser $b } }
foreach ($x in ($browserFail | Select-Object -Unique)) { Write-Host ('  FAIL ' + $x) }
if ($fail.Count -gt 0 -or $browserFail.Count -gt 0) { Write-Host 'CART_RECENT_LAYOUT FAIL'; exit 1 }
if ($SkipMutants) { Write-Host 'CART_RECENT_LAYOUT OK (mutazioni saltate)' } else { Write-Host ('CART_RECENT_LAYOUT OK (mutazioni uccise: ' + $killed + ' su ' + $expected + ')') }
exit 0
