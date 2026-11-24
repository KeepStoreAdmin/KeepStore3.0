[CmdletBinding()]
param([string]$ScreenshotDir = '')

# KS-MYACCOUNT-1B - rendering in Edge headless del pannello dell'account e della lista dei documenti a schede, su pagine STATICHE costruite dal VERO markup di myaccount.aspx e
# documenti.aspx (espressioni server sostituite con l'HTML che i VERI moduli compilati producono) e con i VERI fogli (bootstrap, styles, keepstore, order-ui, account-hub-ui, theme-overrides).
# La lista e resa come la rende GridView: tabella con una cella per riga, classe td-order-item, riga del pager con tabella annidata e riga "nessun documento".
# A 320, 360, 390, 768 e 1280 px: nessuno scorrimento orizzontale, niente che esca dalla scheda o dal riquadro, schede non sovrapposte, riquadri >= 88 px e collegamenti/pulsanti >= 44 px,
# riquadri "in arrivo" non raggiungibili da tastiera e senza href, contrasto >= 4.5, pager in riga. NON prova il ciclo WebForms ne le pagine con login. Solo ASCII: Windows PowerShell 5.1.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $repoRoot $rel), [Text.Encoding]::UTF8) }

# --- HTML vero dai moduli compilati ---------------------------------------------------------------------------------------------------------------------
$probeSource = @"
Option Strict On
Option Explicit On
Imports System
Imports System.Collections.Generic
Public Class LayoutProbe
    Public Function Tiles(ByVal enabled As Boolean) As String
        Dim types As New List(Of AccountDocType)()
        Dim spec As String() = {"2~Preventivo~0~3", "4~Ordine~1~1223", "3~D.D.T.~0~1", "16~Fattura Differita con descrizione lunghissima~0~12", "5~Notadicreditosenzaspaziperprovarelandareacapo~0~2"}
        For Each part As String In spec
            Dim f As String() = part.Split("~"c)
            Dim t As New AccountDocType()
            t.Id = Integer.Parse(f(0)) : t.Description = f(1) : t.IsOrder = (f(2) = "1") : t.Count = Integer.Parse(f(3))
            types.Add(t)
        Next
        Return KeepStoreAccountTiles.RenderHtml(KeepStoreAccountTiles.Build(types), enabled)
    End Function
    Public Function Mini(ByVal isOrder As Boolean, ByVal statiId As Integer) As String
        Return KeepStoreOrderProgress.MiniProgressHtml(isOrder, statiId)
    End Function
    Public Function Track(ByVal tracking As String, ByVal statiId As Integer) As String
        Return KeepStoreOrderProgress.TrackingLinksHtml(tracking, "https://corriere.example/t/#ID#", statiId)
    End Function
End Class
"@
$cp = New-Object CodeDom.Compiler.CompilerParameters
$cp.GenerateInMemory = $true
$cp.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
@('System.dll', 'System.Core.dll') | ForEach-Object { [void]$cp.ReferencedAssemblies.Add($_) }
$compiled = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($cp, [string[]]@((Read-Repo 'App_Code/KeepStoreAccountTiles.vb'), (Read-Repo 'App_Code/KeepStoreOrderProgress.vb'), $probeSource))
if ($compiled.Errors.HasErrors) { throw ('LAYOUT_COMPILE ' + (($compiled.Errors | Select-Object -First 3 | ForEach-Object { $_.ErrorText }) -join ' | ')) }
$probe = [Activator]::CreateInstance($compiled.CompiledAssembly.GetType('LayoutProbe', $true))

# --- pannello: markup vero fra il saluto e il FormView, piu la sezione "in arrivo" ------------------------------------------------------------------------
$acc = Read-Repo 'myaccount.aspx'
$a0 = $acc.IndexOf('<div class="ks-dashboard-hero">', [StringComparison]::Ordinal)
$a1 = $acc.IndexOf('<asp:FormView ID="fvDashboardProfile"', [StringComparison]::Ordinal)
$s0 = $acc.IndexOf('<section class="ks-account-soon"', [StringComparison]::Ordinal)
$s1 = $acc.IndexOf('</section>', $s0, [StringComparison]::Ordinal)
if ($a0 -lt 0 -or $a1 -le $a0 -or $s0 -lt 0 -or $s1 -le $s0) { throw 'DASHBOARD_MARKUP_NOT_FOUND' }
$dash = $acc.Substring($a0, $a1 - $a0) + $acc.Substring($s0, $s1 + 10 - $s0)
$dash = $dash.Replace('<asp:Literal ID="litGreeting" runat="server" Text="Benvenuto nella tua Dashboard" />', 'Ciao, Azienda Di Prova Con Una Ragione Sociale Molto Lunga S.R.L.')
$dash = $dash.Replace('<asp:Literal ID="litPayNotice" runat="server" />', 'Hai un ordine da pagare')
$dash = $dash.Replace('<div id="pnlPayNotice" runat="server" visible="false" class="ks-account-notice">', '<div class="ks-account-notice">')
$dash = $dash.Replace('<a id="lnkPayNotice" runat="server" class="tf-btn btn-fill ks-account-notice__btn">', '<a href="#" class="tf-btn btn-fill ks-account-notice__btn">')
$dash = $dash.Replace('<%= TilesHtml(True) %>', $probe.Tiles($true)).Replace('<%= TilesHtml(False) %>', $probe.Tiles($false))
if ($dash -match '<%|runat=') { throw 'DASHBOARD_EXPRESSION_LEFT' }
$dashPage = '<div class="ks-myaccount ks-account-dashboard"><section class="tf-sp-2"><div class="container"><div class="row"><div class="col-12"><div class="myaccount-content account-dashboard">' + $dash + '</div></div></div></div></section></div>'

# --- lista: la scheda vera, resa come una riga di GridView ------------------------------------------------------------------------------------------------
$list = Read-Repo 'documenti.aspx'
$c0 = $list.IndexOf('<article class="ks-doc-card">', [StringComparison]::Ordinal)
$c1 = $list.IndexOf('</article>', $c0, [StringComparison]::Ordinal)
if ($c0 -lt 0 -or $c1 -le $c0) { throw 'CARD_MARKUP_NOT_FOUND' }
$cardTemplate = $list.Substring($c0, $c1 + 10 - $c0)
function Render-Card([hashtable]$d) {
    $c = $cardTemplate
    $c = [regex]::Replace($c, '(?s)<asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="idcoupon".*?</asp:HyperLink>', '')
    $c = [regex]::Replace($c, '(?s)<asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="iddoc".*?</asp:HyperLink>', ('<a href="#" style="color:#E12825;font-weight:bold;">' + $d.Number + '</a>'))
    $c = [regex]::Replace($c, '(?s)<asp:Label ID="lblListaDaPagare".*?/>', $(if ($d.Pay) { '<span class="ks-pay-now__badge">Da pagare</span>' } else { '' }))
    $c = [regex]::Replace($c, '(?s)<asp:HyperLink ID="hlListaPagaAdesso".*?/>', $(if ($d.Pay) { '<a class="tf-btn btn-small d-inline-flex ks-pay-now__btn" href="#">Paga adesso</a>' } else { '' }))
    $map = [ordered]@{
        '<%#: Eval("TipoDocumentiDescrizione") %>' = $d.Type
        '<%#: KeepStoreDates.ShortDate(Eval("DataDocumento")) %>' = '17/11/2026'
        '<%#: OrderStatusTitle(Eval("StatiDescrizione1"), Eval("StatiDescrizione2")) %>' = $d.State
        '<%#: OrderStatusNote(Eval("StatiDescrizione1"), Eval("StatiDescrizione2")) %>' = $d.Note
        '<%# ListProgressHtml(Eval("ListaOrdineWeb"), Eval("StatiId")) %>' = $probe.Mini([bool]$d.IsOrder, [int]$d.StatiId)
        '<%# Eval("TotaleDocumento", "{0:C}") %>' = '1.234,56 &euro;'
        '<%# Eval("TotImponibile", "{0:C}") %>' = '1.011,93 &euro;'
        '<%#: GetPaymentMethodLabel(Eval("ListaPagamentoDescrizione")) %>' = 'Carta di Credito - Banca Sella ON-LINE'
        '<%# GetPaymentStatusCssClass(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb")) %>' = 'ks-status-badge is-warning'
        '<%# GetPaymentStatusLabel(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb")) %>' = 'In verifica'
        '<%#: GetPaymentStatusDescription(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb"), Eval("ListaUltimoEsitoPagamentoWeb"), Eval("ListaPagamentiTipoOnline"), Eval("ListaPagamentoDescrizione")) %>' = 'Pagamento online successivo disponibile'
        '<%#: Eval("VettoriDescrizione") %>' = 'Corriere Espresso Nazionale'
        '<%# ListTrackingHtml(Eval("Tracking"), Eval("Link_Tracking"), Eval("StatiId")) %>' = $probe.Track([string]$d.Tracking, [int]$d.StatiId)
        '<%#: Eval("RagioneSociale") %>' = 'Azienda Di Prova S.R.L.'
        '<%#: Eval("CognomeNome") %>' = 'Mario Rossi'
        '<%#: Eval("SedeLegale") %>' = 'Via di Prova 1, 80100 Napoli'
        '<%#: Eval("DestinazioneMerci") %>' = 'Via Secondaria 22, 80100 Napoli'
        '<%# testNote(Eval("Note")) %>' = ''
        '<%#: Eval("Note") %>' = 'Citofonare'
        '<%#: Eval("NoteEsterne") %>' = 'Nessuna'
        '<%# Eval("id", "documentidettaglio.aspx?id={0}") %>' = '#'
    }
    foreach ($k in $map.Keys) { $c = $c.Replace($k, [string]$map[$k]) }
    if ($d.ContainsKey('Open') -and $d.Open) { $c = $c.Replace('<details class="ks-order-details">', '<details class="ks-order-details" open>') }
    if ($c -match '<%|runat=|<asp:') { throw ('CARD_EXPRESSION_LEFT ' + $d.Number + ' ' + ([regex]::Match($c, '<%[^%]*%>|<asp:[^>]*>').Value)) }
    return ('<tr class="td-order-item"><td>' + $c + '</td></tr>')
}
$long = 'A' * 60
$rows = @(
    (Render-Card @{ Number = '1201'; Type = 'Ordine'; State = 'In lavorazione'; Note = 'Il tuo ordine e stato processato e sara spedito al piu presto, grazie per averci scelto.'; IsOrder = $true; StatiId = 2; Tracking = ''; Pay = $true; Open = $true }),
    (Render-Card @{ Number = '1187'; Type = 'Ordine'; State = 'Spedito'; Note = 'Il tuo ordine e stato consegnato o spedito secondo le modalita concordate.'; IsOrder = $true; StatiId = 4; Tracking = ('3UW1WHC117829;' + $long); Pay = $false }),
    (Render-Card @{ Number = '1150'; Type = 'Ordine'; State = 'Annullato'; Note = ''; IsOrder = $true; StatiId = 3; Tracking = 'ABC123'; Pay = $false }),
    (Render-Card @{ Number = '88'; Type = 'Fattura Immediata'; State = 'Emessa'; Note = ''; IsOrder = $false; StatiId = 4; Tracking = ''; Pay = $false })
) -join ''
$pager = '<tr class="nav ks-doc-list__pager" style="font-weight:bold;"><td><table><tr><td><span>1</span></td><td><a href="#">2</a></td><td><a href="#">3</a></td></tr></table></td></tr>'
$listPage = '<div class="ks-myaccount"><section class="tf-sp-2"><div class="container"><div class="row"><div class="col-12"><div class="myaccount-content account-dashboard"><div class="tf-order_history-table ks-doc-list-wrap"><div><table class="table_def ks-order-table ks-doc-list" cellspacing="0" style="width:100%;border-collapse:collapse;"><thead></thead><tbody>' + $rows + $pager + '</tbody></table></div></div></div></div></div></div></section></div>'
$emptyPage = '<div class="ks-myaccount"><section class="tf-sp-2"><div class="container"><div class="tf-order_history-table ks-doc-list-wrap"><div><table class="table_def ks-order-table ks-doc-list" cellspacing="0" style="width:100%;border-collapse:collapse;"><tr align="center" style="font-weight:normal;height:100px;"><td>Nessun documento presente</td></tr></table></div></div></div></section></div>'

$cssDir = Join-Path $repoRoot 'Public/assets/keepstore/css'
$sheets = @('bootstrap.min.css', 'account-ui.css', 'styles.css', 'keepstore.css', 'order-ui.css', 'account-hub-ui.css', 'theme-overrides.css')
$links = ($sheets | ForEach-Object { '<link rel="stylesheet" href="file:///' + ((Join-Path $cssDir $_) -replace '\\', '/') + '">' }) -join ''
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-account-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$pages = @{ Dashboard = $dashPage; List = $listPage; Empty = $emptyPage; ListNarrow = ('<div style="max-width:760px">' + $listPage + '</div>'); ListTiny = ('<div style="max-width:480px">' + $listPage + '</div>') }
foreach ($name in $pages.Keys) {
    $html = '<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' + $links + '</head><body>' + $pages[$name] + '</body></html>'
    [IO.File]::WriteAllText((Join-Path $work ($name + '.html')), $html, (New-Object Text.UTF8Encoding($false)))
}

$measureJs = @'
(function(){
  function parse(c){ var m=c.match(/rgba?\(([^)]+)\)/); if(!m) return null; var p=m[1].split(',').map(function(x){return parseFloat(x)}); return {r:p[0],g:p[1],b:p[2],a:(p.length>3?p[3]:1)}; }
  function lum(c){ function f(v){ v=v/255; return v<=0.03928? v/12.92 : Math.pow((v+0.055)/1.055,2.4); } return 0.2126*f(c.r)+0.7152*f(c.g)+0.0722*f(c.b); }
  function ratio(a,b){ var l1=lum(a), l2=lum(b); var hi=Math.max(l1,l2), lo=Math.min(l1,l2); return (hi+0.05)/(lo+0.05); }
  function bgOf(el){ var e=el; while(e){ var c=parse(getComputedStyle(e).backgroundColor); if(c && c.a>=0.99) return c; e=e.parentElement; } return {r:255,g:255,b:255,a:1}; }
  function contrast(sel,min){ document.querySelectorAll(sel).forEach(function(el){ if(!el.textContent.trim()) return; var r=ratio(parse(getComputedStyle(el).color),bgOf(el)); if(r<min) out.fails.push('CONTRAST '+sel+' '+r.toFixed(2)); }); }
  var out={fails:[]};
  var doc=document.documentElement;
  if(doc.scrollWidth>window.innerWidth+1) out.fails.push('HORIZONTAL_SCROLL '+doc.scrollWidth+'>'+window.innerWidth);
  document.querySelectorAll('.tf-order_history-table').forEach(function(w){ if(w.scrollWidth>w.clientWidth+1) out.fails.push('LIST_WRAPPER_SCROLLS '+w.scrollWidth+'>'+w.clientWidth); });
  // riquadri
  var tiles=document.querySelectorAll('.ks-account-tile');
  tiles.forEach(function(t){ var r=t.getBoundingClientRect(); if(r.height<88) out.fails.push('TILE_TOO_SHORT '+Math.round(r.height)); if(r.width<88) out.fails.push('TILE_TOO_NARROW '+Math.round(r.width));
    t.querySelectorAll('*').forEach(function(ch){ var c=ch.getBoundingClientRect(); if(c.width>0 && (c.right>r.right+1 || c.left<r.left-1)) out.fails.push('TILE_CONTENT_OVERFLOW '+t.textContent.trim().slice(0,18)); }); });
  var soon=document.querySelectorAll('.ks-account-tile.is-soon');
  soon.forEach(function(t){ if(t.tagName==='A' || t.hasAttribute('href') || t.tabIndex>=0 || t.querySelector('a')) out.fails.push('SOON_TILE_REACHABLE'); if(t.textContent.indexOf('In arrivo')<0) out.fails.push('SOON_TILE_WITHOUT_TEXT'); });
  if(tiles.length>0){ if(soon.length!==5) out.fails.push('SOON_COUNT '+soon.length); if(document.querySelectorAll('a.ks-account-tile').length!==12) out.fails.push('ACTIVE_COUNT '+document.querySelectorAll('a.ks-account-tile').length);
    var hub=document.querySelector('.ks-account-hub .ks-account-tiles'); var cols=getComputedStyle(hub).gridTemplateColumns.split(' ').length; var want=(window.innerWidth>=992?4:(window.innerWidth>=576?3:2)); if(cols!==want) out.fails.push('TILE_COLUMNS '+cols+' want '+want);
    var nb=document.querySelector('.ks-account-notice__btn'); if(!nb || nb.getBoundingClientRect().height<43.5) out.fails.push('NOTICE_BUTTON_SHORT'); }
  contrast('.ks-account-tile__label',4.5); contrast('.ks-account-tile__hint',4.5); contrast('.ks-account-notice__title',4.5); contrast('.ks-account-soon p',4.5);
  // schede
  var cards=document.querySelectorAll('.ks-doc-card'); var prevBottom=-1;
  cards.forEach(function(card,i){ var r=card.getBoundingClientRect(); if(r.height<120) out.fails.push('CARD_COLLAPSED '+Math.round(r.height)); if(r.top<prevBottom-1) out.fails.push('CARDS_OVERLAP '+i); prevBottom=r.bottom;
    var tr=card.closest('tr').getBoundingClientRect(); if(tr.height<r.height-1) out.fails.push('ROW_SHORTER_THAN_CARD '+i);
    card.querySelectorAll('*').forEach(function(ch){ if(ch.classList.contains('ks-mini-progress__sr')) return; var c=ch.getBoundingClientRect(); if(c.width>0 && c.height>0 && (c.right>r.right+1 || c.left<r.left-1)) out.fails.push('CARD_CONTENT_OVERFLOW '+i+' '+ch.tagName+'.'+String(ch.className).slice(0,30)); });
    card.querySelectorAll('.ks-doc-card__track, .ks-action-stack .tf-btn, .ks-order-details summary').forEach(function(b){ if(b.getBoundingClientRect().height<43.5) out.fails.push('TARGET_TOO_SHORT '+i+' '+b.textContent.trim().slice(0,16)+' '+Math.round(b.getBoundingClientRect().height)); }); });
  if(cards.length>0){
    if(cards[0].querySelectorAll('.ks-mini-progress__bar > i.is-on').length!==2) out.fails.push('MINI_BAR_STEP');
    if(cards[2].querySelector('.ks-mini-progress') || cards[2].querySelector('.ks-doc-card__tracking')) out.fails.push('CANCELLED_SHOWS_PROGRESS_OR_TRACKING');
    if(cards[3].querySelector('.ks-mini-progress')) out.fails.push('INVOICE_SHOWS_PROGRESS');
    if(cards[1].querySelectorAll('.ks-doc-card__tracking > li').length!==2 || cards[1].querySelectorAll('.ks-doc-card__track').length!==1) out.fails.push('TRACKING_ITEMS');
    // KS-DASHBOARD-ORDERS-1B: le colonne seguono la larghezza della SCHEDA (contenitore), non della finestra: >=820 px 4 colonne, >=520 px 2, sotto 1.
    cards.forEach(function(card,i){ var cs=getComputedStyle(card); var cw=card.clientWidth-parseFloat(cs.paddingLeft)-parseFloat(cs.paddingRight); var body=card.querySelector('.ks-doc-card__body'); var bc=getComputedStyle(body).gridTemplateColumns.split(' ').length; var bw=(cw>=820?4:(cw>=520?2:1)); if(bc!==bw) out.fails.push('CARD_COLUMNS '+i+' '+bc+' want '+bw+' at '+Math.round(cw));
      var cells=Array.prototype.slice.call(card.querySelectorAll('.ks-doc-card__body > .ks-doc-card__cell'));
      for(var a=0;a<cells.length;a++){ var ra=cells[a].getBoundingClientRect(); cells[a].querySelectorAll('*').forEach(function(ch){ if(ch.classList.contains('ks-mini-progress__sr')) return; var c=ch.getBoundingClientRect(); if(c.width>0 && c.height>0 && (c.right>ra.right+1 || c.left<ra.left-1)) out.fails.push('CELL_CONTENT_OVERFLOW '+i+' '+ch.tagName+'.'+String(ch.className).slice(0,30)); });
        for(var b=a+1;b<cells.length;b++){ var rb=cells[b].getBoundingClientRect(); if(ra.left<rb.right-1 && rb.left<ra.right-1 && ra.top<rb.bottom-1 && rb.top<ra.bottom-1) out.fails.push('CELLS_OVERLAP '+i+' '+a+'/'+b); } }
      var badge=card.querySelector('.ks-status-badge-order'); var note=card.querySelector('.ks-doc-card__status-note');
      if(!badge) out.fails.push('STATUS_BADGE_MISSING '+i);
      if(note && badge && note.textContent.trim()!=='' && note.getBoundingClientRect().top<badge.getBoundingClientRect().bottom-1) out.fails.push('STATUS_NOTE_NOT_BELOW_BADGE '+i);
      if(note && badge && badge.contains(note)) out.fails.push('STATUS_NOTE_INSIDE_BADGE '+i); });
    if(cards[0].querySelector('.ks-doc-card__status-note')===null) out.fails.push('STATUS_NOTE_MISSING');
    var pg=document.querySelectorAll('.ks-doc-list__pager table td'); if(pg.length!==3) out.fails.push('PAGER_CELLS '+pg.length); else { var t0=Math.round(pg[0].getBoundingClientRect().top), t2=Math.round(pg[2].getBoundingClientRect().top); if(t0!==t2) out.fails.push('PAGER_NOT_IN_A_ROW'); if(pg[2].getBoundingClientRect().left<=pg[0].getBoundingClientRect().left) out.fails.push('PAGER_STACKED'); }
    contrast('.ks-doc-card__k',4.5); contrast('.ks-doc-card__date',4.5); contrast('.ks-mini-progress__text',4.5); contrast('.ks-doc-card__track',4.5); contrast('.ks-doc-card__code',4.5);
  }
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
        foreach ($name in @('Dashboard', 'List', 'Empty', 'ListNarrow', 'ListTiny')) {
            Open-KsUrl $browser ('file:///' + ((Join-Path $work ($name + '.html')) -replace '\\', '/'))
            Start-Sleep -Milliseconds 400
            $res = (Invoke-KsJs $browser $measureJs) | ConvertFrom-Json
            $tag = $name + '@' + $width
            if ($ScreenshotDir) { New-Item -ItemType Directory -Force -Path $ScreenshotDir | Out-Null; Save-KsScreenshot $browser (Join-Path $ScreenshotDir ($tag + '.png')) -FullPage }
            if (@($res.fails).Count -gt 0) { foreach ($f in ($res.fails | Select-Object -Unique)) { $failures.Add($tag + ' ' + $f) } } else { Write-Output ('PASS ' + $tag) }
        }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Output ('FAIL ' + $_) }; throw 'ACCOUNT_LAYOUT_FAIL' }
Write-Output 'ACCOUNT_LAYOUT_PASS widths=5 pages=5'
