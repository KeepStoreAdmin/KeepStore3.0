[CmdletBinding()]
param([string]$ScreenshotDir = '')

# KS-MYACCOUNT-1A - rendering in Edge headless della barra di avanzamento e della scheda di tracking del dettaglio ordine, su frammenti STATICI costruiti dal VERO markup di
# documentidettaglio.aspx (le espressioni server sostituite con i valori che le funzioni produrrebbero) con i VERI fogli bootstrap, styles, keepstore, documents-ui, order-ui e theme-overrides.
# Scenari: stato 1, 2, 5, 4 con due numeri (uno lunghissimo senza spazi), 3 annullato. A 320, 360, 390, 768 e 1280 px: nessuno scorrimento orizzontale, testo mai tagliato, sotto 576 px i passi sono
# in colonna e da 576 in riga, un solo aria-current per le barre note, testo nascosto presente, pulsanti >= 44 px, contrasto >= 4.5, annullato senza barra. NON prova il ciclo WebForms ne la pagina con login.
# Solo ASCII: Windows PowerShell 5.1.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $repoRoot $rel), [Text.Encoding]::UTF8) }

$aspx = Read-Repo 'documentidettaglio.aspx'
$i0 = $aspx.IndexOf('<article class="ks-confirm-card ks-order-progress-card"', [StringComparison]::Ordinal)
$i1 = $aspx.IndexOf('<article class="ks-confirm-card ks-order-tracking-card"', [StringComparison]::Ordinal)
$i2 = $aspx.IndexOf('</article>', $i1, [StringComparison]::Ordinal)
if ($i0 -lt 0 -or $i1 -le $i0 -or $i2 -le $i1) { throw 'CARDS_NOT_FOUND' }
$progressCard = $aspx.Substring($i0, $i1 - $i0)
$trackingCard = $aspx.Substring($i1, $i2 + 10 - $i1)
function Get-Step([int]$state) { switch ($state) { 1 { 1 } 6 { 1 } 2 { 2 } 5 { 3 } 4 { 4 } default { 0 } } }
function Render-Cards([int]$state, [string]$stateName, [string]$stateText, [string]$trackingHtml) {
    $step = Get-Step $state
    $known = ($step -gt 0)
    $cancelled = ($state -eq 3)
    $c = $progressCard -replace ' runat="server"', '' -replace "visible='<%# [A-Za-z]+\([^%]*%>'", ''
    for ($n = 1; $n -le 4; $n++) {
        $css = 'ks-order-progress__step'; $aria = ''; $sr = ''
        if ($known) {
            if ($n -lt $step) { $css += ' is-done'; $sr = ', completato' } elseif ($n -eq $step) { $css += ' is-current'; $aria = ' aria-current="step"'; $sr = ', stato attuale' } else { $sr = ', da fare' }
        }
        $c = $c.Replace('<%# ProgressStepCss(Eval("StatiId"), ' + $n + ') %>', $css).Replace('<%# ProgressAriaCurrent(Eval("StatiId"), ' + $n + ') %>', $aria).Replace('<%# ProgressSrText(Eval("StatiId"), ' + $n + ') %>', $sr)
    }
    $c = $c.Replace('<%# HtmlText(Eval("StatiDescrizione1")) %>', $stateName).Replace('<%# HtmlText(Eval("StatiDescrizione2")) %>', $stateText)
    if (-not $known -or $cancelled) { $c = [regex]::Replace($c, '(?s)<ol class="ks-order-progress".*?</ol>', '') }
    if (-not $cancelled) { $c = [regex]::Replace($c, '(?s)<p class="ks-order-progress__cancelled".*?</p>', '') }
    $t = $trackingCard -replace ' runat="server"', '' -replace "visible='<%# [A-Za-z]+\([^%]*%>'", ''
    $t = $t.Replace('<%# HtmlText(Eval("VettoriDescrizione")) %>', 'BRT SpA').Replace('<%# HtmlText(Eval("VettoriInformazioni")) %>', 'Consegna in 24-48 ore').Replace('<%# TrackingHtml(Eval("Tracking"), Eval("Link_Tracking"), Eval("StatiId")) %>', $trackingHtml)
    if ($c -match '<%#' -or $t -match '<%#') { throw ('EXPRESSION_LEFT state ' + $state) }
    return ('<div class="ks-confirm-card-grid">' + $c + $t + '</div>')
}
$long = 'A' * 60
$twoCodes = '<ul class="ks-order-tracking__list"><li><span class="ks-order-tracking__code">3UW1WHC117829</span> <a class="tf-btn btn-small ks-order-tracking__btn" href="#" target="_blank" rel="noopener noreferrer">Segui la spedizione<span class="ks-order-progress__sr"> numero 3UW1WHC117829</span></a></li><li><span class="ks-order-tracking__code">' + $long + '</span></li></ul><p class="ks-muted">Il corriere aggiorna lo stato sul proprio sito: il collegamento si apre in una nuova scheda.</p>'
$scenarios = @(
    @{ Name = 'S1'; Html = (Render-Cards 1 'Inviato' 'Il tuo ordine e stato memorizzato e sara processato al piu presto.' '<p class="ks-muted">Il numero di tracking comparira qui quando l ordine sara affidato al corriere.</p>'); Step = 1 },
    @{ Name = 'S2'; Html = (Render-Cards 2 'In lavorazione' 'Il tuo ordine e stato processato e sara spedito al piu presto.' '<p class="ks-muted">Il numero di tracking comparira qui quando l ordine sara affidato al corriere.</p>'); Step = 2 },
    @{ Name = 'S5'; Html = (Render-Cards 5 'Evaso' 'Il tuo ordine e pronto per la spedizione/ritiro.' '<p class="ks-muted">Pronto per la spedizione o il ritiro.</p>'); Step = 3 },
    @{ Name = 'S4'; Html = (Render-Cards 4 'Spedito' 'Il tuo ordine e stato consegnato o spedito secondo le modalita concordate.' $twoCodes); Step = 4 },
    @{ Name = 'S3'; Html = (Render-Cards 3 'Annullato' 'Il tuo ordine e stato annullato, la preghiamo di contattarci.' ''); Step = 0 }
)
$cssDir = Join-Path $repoRoot 'Public/assets/keepstore/css'
$sheets = @('bootstrap.min.css', 'styles.css', 'keepstore.css', 'documents-ui.css', 'order-ui.css', 'theme-overrides.css')
$links = ($sheets | ForEach-Object { '<link rel="stylesheet" href="file:///' + ((Join-Path $cssDir $_) -replace '\\', '/') + '">' }) -join ''
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-progress-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
foreach ($s in $scenarios) {
    $page = '<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' + $links + '</head><body><section class="tf-sp-2 ks-order-detail"><div class="container"><div class="tf-order-detail"><section class="ks-order-confirmation">' + $s.Html + '</section></div></div></section></body></html>'
    [IO.File]::WriteAllText((Join-Path $work ($s.Name + '.html')), $page, (New-Object Text.UTF8Encoding($false)))
}

$measureJs = @'
(function(){
  function parse(c){ var m=c.match(/rgba?\(([^)]+)\)/); if(!m) return null; var p=m[1].split(',').map(function(x){return parseFloat(x)}); return {r:p[0],g:p[1],b:p[2],a:(p.length>3?p[3]:1)}; }
  function lum(c){ function f(v){ v=v/255; return v<=0.03928? v/12.92 : Math.pow((v+0.055)/1.055,2.4); } return 0.2126*f(c.r)+0.7152*f(c.g)+0.0722*f(c.b); }
  function ratio(a,b){ var l1=lum(a), l2=lum(b); var hi=Math.max(l1,l2), lo=Math.min(l1,l2); return (hi+0.05)/(lo+0.05); }
  function bgOf(el){ var e=el; while(e){ var c=parse(getComputedStyle(e).backgroundColor); if(c && c.a>=0.99) return c; e=e.parentElement; } return {r:255,g:255,b:255,a:1}; }
  var out={fails:[],info:{}};
  var doc=document.documentElement;
  if(doc.scrollWidth>window.innerWidth+1) out.fails.push('HORIZONTAL_SCROLL '+doc.scrollWidth+'>'+window.innerWidth);
  var ol=document.querySelector('.ks-order-progress');
  var cancelled=document.querySelector('.ks-order-progress__cancelled');
  var cur=document.querySelectorAll('.ks-order-progress [aria-current="step"]').length;
  if(ol){
    var lis=ol.querySelectorAll('li'); if(lis.length!==4) out.fails.push('FOUR_STEPS '+lis.length);
    if(cur!==1) out.fails.push('ONE_ARIA_CURRENT '+cur);
    var tops=[]; lis.forEach(function(li){ tops.push(Math.round(li.getBoundingClientRect().top)); if(li.scrollWidth>li.clientWidth+1) out.fails.push('STEP_TEXT_CLIPPED '+li.textContent.trim().slice(0,20)); var lb=li.querySelector('.ks-order-progress__label'); var rc=ratio(parse(getComputedStyle(lb).color),bgOf(lb)); if(rc<4.5) out.fails.push('STEP_CONTRAST '+rc.toFixed(2)); var sr=li.querySelector('.ks-order-progress__sr'); if(!sr || sr.getBoundingClientRect().width>2) out.fails.push('SR_TEXT_NOT_HIDDEN'); });
    var sameRow=(tops[0]===tops[1] && tops[1]===tops[2] && tops[2]===tops[3]);
    if(window.innerWidth<576 && sameRow) out.fails.push('STEPS_NOT_VERTICAL');
    if(window.innerWidth>=576 && !sameRow) out.fails.push('STEPS_NOT_HORIZONTAL '+tops.join(','));
    var rcd=ol.getBoundingClientRect(); lis.forEach(function(li){ var r=li.getBoundingClientRect(); if(r.right>rcd.right+1) out.fails.push('STEP_OFF_CONTAINER'); });
  } else { if(cur!==0) out.fails.push('ARIA_WITHOUT_BAR'); }
  if(cancelled){ if(ol) out.fails.push('BAR_WITH_CANCELLED'); if(cancelled.getAttribute('role')!=='status' || cancelled.hasAttribute('aria-live')) out.fails.push('CANCELLED_ROLE'); var cc=ratio(parse(getComputedStyle(cancelled).color),bgOf(cancelled)); if(cc<4.5) out.fails.push('CANCELLED_CONTRAST '+cc.toFixed(2)); }
  ['.ks-order-progress__state','.ks-order-progress__state strong','.ks-order-tracking__code'].forEach(function(s){ document.querySelectorAll(s).forEach(function(el){ var r=ratio(parse(getComputedStyle(el).color),bgOf(el)); if(r<4.5) out.fails.push('CONTRAST '+s+' '+r.toFixed(2)); }); });
  document.querySelectorAll('.ks-order-tracking-card *').forEach(function(el){ var r=el.getBoundingClientRect(), card=el.closest('.ks-order-tracking-card').getBoundingClientRect(); if(r.width>0 && r.right>card.right+1) out.fails.push('TRACKING_OVERFLOW '+el.tagName+'.'+el.className); });
  document.querySelectorAll('.ks-order-tracking__btn').forEach(function(b){ var r=b.getBoundingClientRect(); if(r.height<43.5) out.fails.push('BUTTON_TOO_SHORT '+Math.round(r.height)); var rc=ratio(parse(getComputedStyle(b).color),bgOf(b)); if(rc<4.5) out.fails.push('BUTTON_CONTRAST '+rc.toFixed(2)); });
  return JSON.stringify(out);
})()
'@

$browser = $null
$failures = New-Object Collections.Generic.List[string]
try {
    try { $browser = Start-KsBrowser -LoopbackHosts @('localhost') -Width 390 -Height 900 }
    catch { Write-Output ('BROWSER_NON_ESEGUITO: ' + $_.Exception.Message); exit 2 }
    foreach ($width in @(320, 360, 390, 768, 1280)) {
        $null = Invoke-KsCdp $browser 'Emulation.setDeviceMetricsOverride' @{ width = $width; height = 900; deviceScaleFactor = 1; mobile = ($width -lt 768) }
        foreach ($s in $scenarios) {
            Open-KsUrl $browser ('file:///' + ((Join-Path $work ($s.Name + '.html')) -replace '\\', '/'))
            Start-Sleep -Milliseconds 400
            $res = (Invoke-KsJs $browser $measureJs) | ConvertFrom-Json
            $tag = $s.Name + '@' + $width
            if ($ScreenshotDir) { New-Item -ItemType Directory -Force -Path $ScreenshotDir | Out-Null; Save-KsScreenshot $browser (Join-Path $ScreenshotDir ($tag + '.png')) -FullPage }
            if (@($res.fails).Count -gt 0) { foreach ($f in $res.fails) { $failures.Add($tag + ' ' + $f) } } else { Write-Output ('PASS ' + $tag) }
        }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Output ('FAIL ' + $_) }; throw 'ORDER_PROGRESS_LAYOUT_FAIL' }
Write-Output 'ORDER_PROGRESS_LAYOUT_PASS widths=5 scenarios=5'
