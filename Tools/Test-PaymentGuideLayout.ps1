[CmdletBinding()]
param([string]$ScreenshotDir = '')

# PAYPAL-FAILED-PAYMENT-GUIDE-1A - rendering della guida del carrello in Edge headless su un frammento STATICO costruito dal VERO markup di carrello.aspx
# (tag server tolti, messaggio = costante reale di PayPalPayFirst.vb) con i VERI fogli bootstrap, styles, theme-overrides e cart-ui.
# Per ogni variante e ogni larghezza (320, 360, 390, 768, 1280): nessuno scorrimento orizzontale, nessun elemento che esce dal contenitore, pulsanti alti almeno 44 px
# (a tutta larghezza sotto i 576 px), contrasto del testo >= 4.5 (3 per le icone) sullo sfondo opaco piu vicino, titolo h2 collegato alla sezione, passi in colonna
# su telefono e in tre colonne da 768 px. NON prova il ciclo WebForms ne il carrello autenticato. Solo ASCII: Windows PowerShell 5.1.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $repoRoot $rel), [Text.Encoding]::UTF8) }

$aspx = Read-Repo 'carrello.aspx'
$payFirst = Read-Repo 'App_Code/PayPalPayFirst.vb'
function Get-Const([string]$name) {
    $m = [regex]::Match($payFirst, '(?m)^\s*Public Const ' + $name + ' As String = "((?:[^"]|"")*)"')
    if (-not $m.Success) { throw ('CONST_NOT_FOUND ' + $name) }
    return $m.Groups[1].Value.Replace('""', '"')
}
$messages = @{ Retry = (Get-Const 'MsgCanceled'); Wait = (Get-Const 'MsgBusy'); Contact = (Get-Const 'MsgManual') }
$iGuide = $aspx.IndexOf('<asp:Panel ID="pnlPaymentGuide"', [StringComparison]::Ordinal)
$iNotice = $aspx.IndexOf('<asp:Panel ID="pnlCartPriceRevalidation"', [StringComparison]::Ordinal)
if ($iGuide -lt 0 -or $iNotice -le $iGuide) { throw 'GUIDE_PANEL_NOT_FOUND' }
$guide = $aspx.Substring($iGuide, $iNotice - $iGuide)
$fragments = @{}
foreach ($kind in @('Retry', 'Wait', 'Contact')) {
    $m = [regex]::Match($guide, '(?s)<asp:PlaceHolder ID="phGuide' + $kind + '"[^>]*>(.*?)</asp:PlaceHolder>')
    if (-not $m.Success) { throw ('VARIANT_NOT_FOUND ' + $kind) }
    $html = $m.Groups[1].Value
    $html = [regex]::Replace($html, '<asp:Literal ID="litPaymentGuideMessage' + $kind + '"[^>]*/>', [Net.WebUtility]::HtmlEncode($messages[$kind]))
    if ($html -match '<asp:') { throw ('SERVER_TAG_LEFT ' + $kind) }
    foreach ($im in [regex]::Matches($html, 'src="(/Public/[^"]+)"')) {
        $assetPath = Join-Path $repoRoot ($im.Groups[1].Value.TrimStart('/') -replace '/', '\')
        if (-not (Test-Path -LiteralPath $assetPath)) { throw ('ASSET_MISSING ' + $im.Groups[1].Value) }
        $html = $html.Replace('src="' + $im.Groups[1].Value + '"', 'src="file:///' + ($assetPath -replace '\\', '/') + '"')
    }
    $fragments[$kind] = $html
}

$cssDir = Join-Path $repoRoot 'Public/assets/keepstore/css'
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-payguide-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
foreach ($kind in $fragments.Keys) {
    $page = '<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
        '<link rel="stylesheet" href="file:///' + ((Join-Path $cssDir 'bootstrap.min.css') -replace '\\', '/') + '">' +
        '<link rel="stylesheet" href="file:///' + ((Join-Path $cssDir 'styles.css') -replace '\\', '/') + '">' +
        '<link rel="stylesheet" href="file:///' + ((Join-Path $cssDir 'theme-overrides.css') -replace '\\', '/') + '">' +
        '<link rel="stylesheet" href="file:///' + ((Join-Path $cssDir 'cart-ui.css') -replace '\\', '/') + '"></head>' +
        '<body><section class="s-shoping-cart tf-sp-2 ks-cart-page ks-cart-modern"><div class="container"><div class="ks-pay-guide">' + $fragments[$kind] + '</div></div></section></body></html>'
    [IO.File]::WriteAllText((Join-Path $work ($kind + '.html')), $page, (New-Object Text.UTF8Encoding($false)))
}

$measureJs = @'
(function(){
  function parse(c){ var m=c.match(/rgba?\(([^)]+)\)/); if(!m) return null; var p=m[1].split(',').map(function(x){return parseFloat(x)}); return {r:p[0],g:p[1],b:p[2],a:(p.length>3?p[3]:1)}; }
  function lum(c){ function f(v){ v=v/255; return v<=0.03928? v/12.92 : Math.pow((v+0.055)/1.055,2.4); } return 0.2126*f(c.r)+0.7152*f(c.g)+0.0722*f(c.b); }
  function ratio(a,b){ var l1=lum(a), l2=lum(b); var hi=Math.max(l1,l2), lo=Math.min(l1,l2); return (hi+0.05)/(lo+0.05); }
  function bgOf(el){ var e=el; while(e){ var c=parse(getComputedStyle(e).backgroundColor); if(c && c.a>=0.99) return c; e=e.parentElement; } return {r:255,g:255,b:255,a:1}; }
  var out={fails:[],info:{}};
  var doc=document.documentElement;
  out.info.scrollW=doc.scrollWidth; out.info.innerW=window.innerWidth;
  if(doc.scrollWidth>window.innerWidth+1) out.fails.push('HORIZONTAL_SCROLL '+doc.scrollWidth+'>'+window.innerWidth);
  var card=document.querySelector('.ks-pay-guide__card'); var cr=card.getBoundingClientRect();
  document.querySelectorAll('.ks-pay-guide__card *').forEach(function(el){ var r=el.getBoundingClientRect(); if(r.width>0 && (r.right>cr.right+1 || r.left<cr.left-1)) out.fails.push('OVERFLOW '+el.tagName+'.'+el.className+' '+Math.round(r.right)+'>'+Math.round(cr.right)); });
  var h2=document.querySelector('.ks-pay-guide__card h2'); var sec=document.querySelector('section.ks-pay-guide__card');
  if(!h2 || document.getElementById(sec.getAttribute('aria-labelledby'))!==h2) out.fails.push('ARIA_LABELLEDBY');
  document.querySelectorAll('.ks-pay-guide__btn').forEach(function(b){ var r=b.getBoundingClientRect(); if(r.height<43.5) out.fails.push('BUTTON_TOO_SHORT '+Math.round(r.height)); if(window.innerWidth<576 && r.width<cr.width-60) out.fails.push('BUTTON_NOT_FULL_WIDTH '+Math.round(r.width)+' vs '+Math.round(cr.width)); });
  var textSel=['.ks-pay-guide h2','.ks-pay-guide__lead','.ks-pay-guide__steps strong','.ks-pay-guide__steps span','.ks-pay-guide__btn'];
  textSel.forEach(function(s){ document.querySelectorAll(s).forEach(function(el){ var cs=getComputedStyle(el); var fg=parse(cs.color); var bg=bgOf(el); var r=ratio(fg,bg); if(r<4.5) out.fails.push('CONTRAST '+s+' '+r.toFixed(2)); }); });
  document.querySelectorAll('.ks-pay-guide__icon').forEach(function(el){ var r=ratio(parse(getComputedStyle(el).color),parse(getComputedStyle(el).backgroundColor)); if(r<3) out.fails.push('ICON_CONTRAST '+r.toFixed(2)); });
  var cols=getComputedStyle(document.querySelector('.ks-pay-guide__steps')).gridTemplateColumns.split(' ').length; out.info.stepCols=cols;
  if(window.innerWidth<768 && cols!==1) out.fails.push('STEPS_NOT_ONE_COLUMN '+cols);
  if(window.innerWidth>=768 && cols!==3) out.fails.push('STEPS_NOT_THREE_COLUMNS '+cols);
  var li=document.querySelectorAll('.ks-pay-guide__steps li'); if(li.length!==3) out.fails.push('STEP_COUNT '+li.length);
  var cs0=getComputedStyle(card); if(cs0.boxShadow==='none') out.fails.push('NO_SHADOW'); if(parseFloat(cs0.borderTopLeftRadius)>0) out.fails.push('ROUNDED_CARD'); if(parseFloat(cs0.borderLeftWidth)>0) out.fails.push('BORDER_ON_CARD'); if(document.querySelector('.ks-pay-guide img')) out.fails.push('IMG_IN_GUIDE');
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
        foreach ($kind in @('Retry', 'Wait', 'Contact')) {
            Open-KsUrl $browser ('file:///' + ((Join-Path $work ($kind + '.html')) -replace '\\', '/'))
            Start-Sleep -Milliseconds 500
            $res = (Invoke-KsJs $browser $measureJs) | ConvertFrom-Json
            $tag = $kind + '@' + $width
            if ($ScreenshotDir) { New-Item -ItemType Directory -Force -Path $ScreenshotDir | Out-Null; Save-KsScreenshot $browser (Join-Path $ScreenshotDir ($tag + '.png')) -FullPage }
            if (@($res.fails).Count -gt 0) { foreach ($f in $res.fails) { $failures.Add($tag + ' ' + $f) } } else { Write-Output ('PASS ' + $tag + ' scrollW=' + $res.info.scrollW + ' stepCols=' + $res.info.stepCols) }
        }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Output ('FAIL ' + $_) }; throw 'GUIDE_LAYOUT_FAIL' }
Write-Output 'GUIDE_LAYOUT_PASS widths=5 variants=3'
