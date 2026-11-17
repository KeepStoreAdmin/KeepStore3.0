[CmdletBinding()]
param([string]$ScreenshotDir = '')

# ORDER-REMOTE-PAYMENT-1A - rendering in Edge headless del riquadro "Questo ordine e da pagare" (dettaglio) e dell'etichetta "Da pagare" con il pulsante "Paga adesso" (lista) su
# frammenti STATICI costruiti dal VERO markup (tag server tolti; importo e metodo di esempio) con i VERI fogli bootstrap, styles, theme-overrides, keepstore, documents-ui e order-ui.
# A 320, 360, 390, 768 e 1280 px: nessuno scorrimento orizzontale, nessun elemento fuori dal riquadro, pulsanti alti almeno 44 px (a tutta larghezza sotto i 576 px), contrasto >= 4.5
# del testo e 3 dell'icona, riquadro piatto (ombra ONSUS, nessun angolo arrotondato, nessun bordo), h2 collegato alla regione. Non prova il ciclo WebForms ne la pagina autenticata.
# Solo ASCII: Windows PowerShell 5.1.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $repoRoot $rel), [Text.Encoding]::UTF8) }

$detail = Read-Repo 'documentidettaglio.aspx'
$i0 = $detail.IndexOf('<div id="pnlPayNowCard"', [StringComparison]::Ordinal)
$i1 = $detail.IndexOf('<section class="ks-order-confirmation"', [StringComparison]::Ordinal)
if ($i0 -lt 0 -or $i1 -le $i0) { throw 'DETAIL_CARD_NOT_FOUND' }
$card = $detail.Substring($i0, $i1 - $i0)
$card = $card.Replace(' runat="server" visible="false"', '')
$card = $card.Replace('<%# Eval("TotaleDocumento", "{0:C}") %>', '50,00 EUR').Replace('<%# Eval("PagamentiTipoDescrizione") %>', 'PayPal')
$card = [regex]::Replace($card, '<%#.*?%>', 'x')
# controlli server: i collegamenti diventano ancore, i pulsanti pulsanti, gli altri campi nascosti spariscono
$card = [regex]::Replace($card, '<asp:HyperLink\b[^>]*?CssClass="([^"]*)"[^>]*?Text="([^"]*)"[^>]*/>', '<a class="$1" href="#">$2</a>')
$card = [regex]::Replace($card, '<asp:Button\b[^>]*?Text="([^"]*)"[^>]*?CssClass="([^"]*)"[^>]*/>', '<a class="$2" href="#">$1</a>')
$card = [regex]::Replace($card, '(?s)<asp:TextBox\b.*?</asp:TextBox>', '')
$card = [regex]::Replace($card, '<asp:(TextBox|HiddenField|ImageButton)\b[^>]*/>', '')
if ($card -match '<asp:') { throw 'SERVER_TAG_LEFT' }
$aLinks = [regex]::Matches($card, '<a class="[^"]*ks-pay-now__btn[^"]*"').Count
if ($aLinks -lt 2) { throw ('BUTTONS_NOT_RENDERED ' + $aLinks) }

$list = '<div class="ks-myaccount"><table><tr><td><div class="ks-order-payment-state"><span class="ks-pay-now__badge">Da pagare</span><span class="body-small text-main-2">Non avviato</span></div></td>' +
    '<td><div class="ks-action-stack"><a class="tf-btn btn-small d-inline-flex ks-pay-now__btn" href="#">Paga adesso</a><a class="tf-btn btn-small d-inline-flex" href="#"><span class="text-white">Dettaglio</span></a></div></td></tr></table></div>'

$cssDir = Join-Path $repoRoot 'Public/assets/keepstore/css'
$sheets = @('bootstrap.min.css', 'styles.css', 'keepstore.css', 'documents-ui.css', 'order-ui.css', 'theme-overrides.css')
$links = ($sheets | ForEach-Object { '<link rel="stylesheet" href="file:///' + ((Join-Path $cssDir $_) -replace '\\', '/') + '">' }) -join ''
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-remotepay-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$pages = @{
    Detail = '<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' + $links + '</head><body><section class="tf-sp-2 ks-order-detail"><div class="container"><div class="tf-order-detail">' + $card + '</div></div></section></body></html>'
    List = '<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' + $links + '</head><body><section class="tf-sp-2"><div class="container">' + $list + '</div></section></body></html>'
}
foreach ($k in $pages.Keys) { [IO.File]::WriteAllText((Join-Path $work ($k + '.html')), $pages[$k], (New-Object Text.UTF8Encoding($false))) }

$measureJs = @'
(function(){
  function parse(c){ var m=c.match(/rgba?\(([^)]+)\)/); if(!m) return null; var p=m[1].split(',').map(function(x){return parseFloat(x)}); return {r:p[0],g:p[1],b:p[2],a:(p.length>3?p[3]:1)}; }
  function lum(c){ function f(v){ v=v/255; return v<=0.03928? v/12.92 : Math.pow((v+0.055)/1.055,2.4); } return 0.2126*f(c.r)+0.7152*f(c.g)+0.0722*f(c.b); }
  function ratio(a,b){ var l1=lum(a), l2=lum(b); var hi=Math.max(l1,l2), lo=Math.min(l1,l2); return (hi+0.05)/(lo+0.05); }
  function bgOf(el){ var e=el; while(e){ var c=parse(getComputedStyle(e).backgroundColor); if(c && c.a>=0.99) return c; e=e.parentElement; } return {r:255,g:255,b:255,a:1}; }
  var out={fails:[],info:{}};
  var doc=document.documentElement;
  if(doc.scrollWidth>window.innerWidth+1) out.fails.push('HORIZONTAL_SCROLL '+doc.scrollWidth+'>'+window.innerWidth);
  var box=document.querySelector('.ks-pay-now');
  if(box){
    var br=box.getBoundingClientRect(); var cs0=getComputedStyle(box);
    document.querySelectorAll('.ks-pay-now *').forEach(function(el){ var r=el.getBoundingClientRect(); if(r.width>0 && (r.right>br.right+1 || r.left<br.left-1)) out.fails.push('OVERFLOW '+el.tagName+'.'+el.className+' '+Math.round(r.right)+'>'+Math.round(br.right)); });
    if(cs0.boxShadow==='none') out.fails.push('NO_SHADOW'); if(parseFloat(cs0.borderTopLeftRadius)>0) out.fails.push('ROUNDED'); if(parseFloat(cs0.borderLeftWidth)>0) out.fails.push('BORDER');
    var h2=box.querySelector('h2'); if(!h2 || box.getAttribute('aria-labelledby')!==h2.id) out.fails.push('ARIA_LABELLEDBY');
    ['.ks-pay-now h2','.ks-pay-now__lead'].forEach(function(s){ document.querySelectorAll(s).forEach(function(el){ var r=ratio(parse(getComputedStyle(el).color),bgOf(el)); if(r<4.5) out.fails.push('CONTRAST '+s+' '+r.toFixed(2)); }); });
    var ic=box.querySelector('.ks-pay-now__icon'); var r2=ratio(parse(getComputedStyle(ic).color),parse(getComputedStyle(ic).backgroundColor)); if(r2<3) out.fails.push('ICON_CONTRAST '+r2.toFixed(2));
    box.querySelectorAll('.ks-pay-now__btn').forEach(function(b){ var r=b.getBoundingClientRect(); if(r.height<43.5) out.fails.push('BUTTON_TOO_SHORT '+Math.round(r.height)); if(window.innerWidth<576 && r.width<br.width-40) out.fails.push('BUTTON_NOT_FULL_WIDTH '+Math.round(r.width)+' vs '+Math.round(br.width)); var rc=ratio(parse(getComputedStyle(b).color),bgOf(b)); if(rc<4.5) out.fails.push('BUTTON_CONTRAST '+rc.toFixed(2)); });
  }
  var badge=document.querySelector('.ks-pay-now__badge');
  if(badge){ var rb=ratio(parse(getComputedStyle(badge).color),parse(getComputedStyle(badge).backgroundColor)); if(rb<4.5) out.fails.push('BADGE_CONTRAST '+rb.toFixed(2)); var lb=document.querySelector('.ks-myaccount .ks-pay-now__btn'); if(lb){ var rr=lb.getBoundingClientRect(); if(rr.height<43.5) out.fails.push('LIST_BUTTON_TOO_SHORT '+Math.round(rr.height)); if(rr.right>window.innerWidth+1) out.fails.push('LIST_BUTTON_OFFSCREEN'); } }
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
        foreach ($kind in @('Detail', 'List')) {
            Open-KsUrl $browser ('file:///' + ((Join-Path $work ($kind + '.html')) -replace '\\', '/'))
            Start-Sleep -Milliseconds 500
            $res = (Invoke-KsJs $browser $measureJs) | ConvertFrom-Json
            $tag = $kind + '@' + $width
            if ($ScreenshotDir) { New-Item -ItemType Directory -Force -Path $ScreenshotDir | Out-Null; Save-KsScreenshot $browser (Join-Path $ScreenshotDir ($tag + '.png')) -FullPage }
            if (@($res.fails).Count -gt 0) { foreach ($f in $res.fails) { $failures.Add($tag + ' ' + $f) } } else { Write-Output ('PASS ' + $tag) }
        }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Output ('FAIL ' + $_) }; throw 'REMOTE_PAYMENT_LAYOUT_FAIL' }
Write-Output 'REMOTE_PAYMENT_LAYOUT_PASS widths=5 pages=2'
