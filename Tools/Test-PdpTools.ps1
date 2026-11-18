[CmdletBinding()]
param([switch]$SkipLab)

# PDP-TOOLS-1A. Strumenti della scheda prodotto (stampa, condividi, richiedi informazioni e richiesta di avviso su WhatsApp, sito del
# produttore e scheda tecnica) e contatto WhatsApp del sito, letto dalla tabella dei pulsanti social dell'azienda dell'host.
# Quattro parti: (A) contratto dei sorgenti, (B) comportamento del modulo puro KeepStoreShareLinks (compilato), (C) mutazioni,
# (D) lettura reale sul LAB locale con il connettore del sito (la regola e tinyint(1): senza CAST il connettore la legge come Boolean).
# -SkipLab salta (D). L'apertura di WhatsApp e l'anteprima con la foto si provano solo con un telefono. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $root $rel), $utf8) }

$files = @{
    aspx     = Read-Repo 'articolo.aspx'
    vb       = Read-Repo 'articolo.aspx.vb'
    master   = Read-Repo 'Page.master'
    mastervb = Read-Repo 'Page.master.vb'
    share    = Read-Repo 'App_Code/KeepStoreShareLinks.vb'
    channels = Read-Repo 'App_Code/KeepStoreContactChannels.vb'
    links    = Read-Repo 'App_Code/KeepStoreContactLinks.vb'
    css      = Read-Repo 'Public/assets/keepstore/css/product-ui.css'
    uicss    = Read-Repo 'Public/assets/keepstore/css/ks-ui.css'
    js       = Read-Repo 'Public/assets/keepstore/js/ks-pdp-tools.js'
}

function Get-Between([string]$text, [string]$from, [string]$to) {
    $i = $text.IndexOf($from); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($to, $i + $from.Length); if ($j -lt 0) { return $text.Substring($i) }
    return $text.Substring($i, $j - $i)
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $a = $f.aspx

    # A1 barra degli strumenti nel riquadro d'acquisto, dopo i pulsanti di acquisto
    $buy = Get-Between $a 'ks-pdp-buybox-sticky' 'data-ks-pdp-sections'
    $tools = Get-Between $buy '<nav class="ks-pdp-tools"' '</nav>'
    if ($tools -eq '') { $fail.Add('A1 barra strumenti assente dal riquadro d''acquisto') }
    if ($buy.IndexOf('<nav class="ks-pdp-tools"') -lt $buy.IndexOf('class="product-box-btn"')) { $fail.Add('A1 strumenti prima dei pulsanti di acquisto') }
    if ($tools -notmatch 'aria-label="Strumenti della scheda"') { $fail.Add('A1 barra senza nome') }
    # A2 stampa: pulsante vero con type=button (dentro il form della pagina non deve inviarlo); nessun altro pulsante senza type
    if ($tools -notmatch '<button type="button" class="ks-pdp-tool" data-ks-pdp-print>') { $fail.Add('A2 pulsante stampa') }
    if (([regex]::Matches($tools, '<button(?![^>]*type="button")')).Count -ne 0) { $fail.Add('A2 pulsante senza type=button') }
    # A3 condividi: details/summary (funziona senza script), link prodotti dal server, copia con stato, nessun widget di terzi
    if ($tools -notmatch '<asp:PlaceHolder ID="phToolShare" runat="server" Visible="false">\s*<details class="ks-pdp-share" data-ks-pdp-share>\s*<summary class="ks-pdp-tool">') { $fail.Add('A3 condividi non e un details condizionale') }
    $panel = Get-Between $tools 'class="ks-pdp-share__panel"' '</details>'
    if ($panel -notmatch '<asp:Literal ID="litShareLinks" runat="server" EnableViewState="false" />') { $fail.Add('A3 link di condivisione non prodotti dal server') }
    if ($panel -notmatch '<button type="button" class="ks-pdp-share__copy" data-ks-pdp-copy>') { $fail.Add('A3 copia link') }
    if ($panel -notmatch '<span class="ks-pdp-share__status" role="status" aria-live="polite" data-ks-pdp-share-status></span>') { $fail.Add('A3 regione di stato') }
    if ($panel -notmatch '<input type="text" class="ks-pdp-share__url" readonly="readonly" hidden="hidden" data-ks-pdp-share-url') { $fail.Add('A3 campo per la copia a mano') }
    foreach ($third in 'addthis', 'sharethis', 'getbutton', 'addtoany', 'connect.facebook.net', 'platform.twitter.com') { if (($a + $f.master + $f.js) -match [regex]::Escape($third)) { $fail.Add('A3 script o widget di terzi: ' + $third) } }
    # A4 richiedi informazioni sempre; richiesta di avviso solo se non disponibile; nessuna promessa di avviso automatico
    if ($tools -notmatch '<asp:HyperLink ID="lnkToolInfo" runat="server" CssClass="ks-pdp-tool" EnableViewState="false"') { $fail.Add('A4 richiedi informazioni') }
    if ($tools -notmatch '<asp:PlaceHolder ID="phToolNotify" runat="server" Visible="false">\s*<asp:HyperLink ID="lnkToolNotify" runat="server" CssClass="ks-pdp-tool ks-pdp-tool--notify" EnableViewState="false"') { $fail.Add('A4 richiesta di avviso non condizionale') }
    if ($tools -notmatch 'Chiedi di essere avvisato') { $fail.Add('A4 etichetta della richiesta di avviso') }
    if ($a -match '(?i)>\s*Avvisami') { $fail.Add('A4 etichetta che promette un avviso automatico') }
    $bt = Get-Between $f.vb 'Private Sub BindProductTools' 'End Sub'
    if ($bt -eq '') { $fail.Add('A4 BindProductTools assente') }
    if ($bt -notmatch 'Dim unavailable As Boolean = \(_pdpStructuredAvailability IsNot Nothing AndAlso Not _pdpStructuredAvailability\.IsAvailable\)') { $fail.Add('A4 condizione di non disponibilita') }
    if ($bt -notmatch 'phToolNotify\.Visible = unavailable AndAlso notifyHref <> ""') { $fail.Add('A4 richiesta di avviso legata alla non disponibilita') }
    if ((Get-Between $f.vb 'Private Sub BindProduct(row As DataRow)' 'End Sub') -notmatch 'BindPdpCartState\(_id, currentTcid, True\)\s*BindProductTools\(') { $fail.Add('A4 strumenti non legati in fondo a BindProduct') }
    # A5 azienda dall'host, mai da sessione o parametri; URL canonico dell'azienda; condividi nascosto senza URL
    if ($bt -notmatch 'StorefrontSeoTenantContext\.Resolve\(HttpContext\.Current\)') { $fail.Add('A5 azienda non risolta dall''host') }
    if ($bt -match 'Session\(|Request\.QueryString|Request\.Form|Request\.Url|MakeAbsoluteUrl') { $fail.Add('A5 strumenti che leggono sessione o richiesta') }
    if ($bt -notmatch 'StorefrontCanonicalHostPolicy\.BuildCanonicalUrl\(tenant, ') { $fail.Add('A5 URL condiviso non canonico') }
    if ($bt -notmatch 'KeepStoreContactChannels\.ForCompany\(tenant\.CompanyId\)') { $fail.Add('A5 canale non chiesto per l''azienda dell''host') }
    if ($bt -notmatch 'phToolShare\.Visible = \(shareUrl <> ""\)') { $fail.Add('A5 condividi visibile senza URL') }
    # A6 link esterni: nuova scheda senza opener
    foreach ($id in 'lnkToolInfo', 'lnkToolNotify') {
        if ($bt -notmatch ('SetExternalToolLink\(' + $id + ', ')) { $fail.Add('A6 rel/target su ' + $id) }
    }
    $st = Get-Between $f.vb 'Private Shared Sub SetExternalToolLink' 'End Sub'
    if ($st -notmatch 'link\.Target = "_blank"' -or $st -notmatch 'link\.Attributes\("rel"\) = "noopener noreferrer"') { $fail.Add('A6 SetExternalToolLink senza noopener') }
    $infoBlock = Get-Between $a 'id="prd-infor"' 'id="prd-review"'
    $ident = Get-Between $infoBlock 'data-ks-info-group="identita"' 'data-ks-info-group="prezzi"'
    if ($ident -notmatch '(?s)<asp:PlaceHolder ID="phManufacturerLink" runat="server" Visible="false">.*?<p class="name-feature">Sito del produttore</p>.*?<asp:HyperLink ID="lnkManufacturer" runat="server" EnableViewState="false" Target="_blank" rel="noopener noreferrer nofollow"') { $fail.Add('A6 riga sito del produttore') }
    if ($ident -notmatch '(?s)<asp:PlaceHolder ID="phBrochureLink" runat="server" Visible="false">.*?<p class="name-feature">Scheda tecnica</p>.*?<asp:HyperLink ID="lnkBrochure" runat="server" EnableViewState="false" Target="_blank" rel="noopener noreferrer nofollow"') { $fail.Add('A6 riga scheda tecnica') }
    # A7 link del produttore: dalla riga gia caricata (nessuna query in piu), validati dal modulo, testo = host codificato
    $bl = Get-Between $f.vb 'Private Sub BindExternalProductLinks' 'End Sub'
    if ($bl -notmatch 'KeepStoreShareLinks\.ExternalUrl\(GetRowString\(row, "LinkProduttore"\)\)' -or $bl -notmatch 'KeepStoreShareLinks\.ExternalUrl\(GetRowString\(row, "Brochure"\)\)') { $fail.Add('A7 link non validati o non letti dalla riga') }
    if ($bl -match 'MySqlCommand|SELECT ') { $fail.Add('A7 query in piu per i link') }
    if ($bl -notmatch 'phManufacturerLink\.Visible = \(manufacturerUrl <> ""\)' -or $bl -notmatch 'phBrochureLink\.Visible = \(brochureUrl <> ""\)') { $fail.Add('A7 righe visibili senza link valido') }
    if ($bl -notmatch 'lnkManufacturer\.Text = Server\.HtmlEncode\(KeepStoreShareLinks\.ExternalHost\(manufacturerUrl\)\)') { $fail.Add('A7 testo del link non codificato') }
    if ($f.vb -notmatch '"SELECT NormeGaranzia FROM articoli WHERE id = @id LIMIT 1"') { $fail.Add('A7 la query della garanzia non doveva cambiare') }
    # A8 lettore del canale: cache per azienda gia provata, filtro sull'azienda chiesta, CAST sulla regola tinyint(1), sola lettura
    $c = $f.channels
    if ($c -notmatch 'StorefrontTenantScopedCache\.GetOrLoad\(Of ContactChannel\)\(CacheArea, StorefrontSeoTenantContext\.ConfiguredDatabaseScopeKey\(\), companyId, String\.Empty, CacheSeconds,') { $fail.Add('A8 cache non per database e azienda') }
    if ($c -notmatch 'WHERE b\.company_id=@companyId AND b\.`key`=''whatsapp'' AND b\.enabled=1') { $fail.Add('A8 filtro azienda/whatsapp/abilitato') }
    if ($c -notmatch 'CAST\(COALESCE\(r\.enabled,0\) AS SIGNED\) AS WidgetEnabled') { $fail.Add('A8 CAST sulla regola') }
    if ($c -notmatch 'command\.Parameters\.Add\("@companyId", MySqlDbType\.Int32\)\.Value = companyId') { $fail.Add('A8 parametro azienda') }
    if ($c -match 'Session|HttpContext\.Current|QueryString') { $fail.Add('A8 lettore che guarda sessione o richiesta') }
    if ($c -notmatch 'If ex\.Number = 1146 Then Return ContactChannel\.None') { $fail.Add('A8 tabella assente non trattata come nessun canale') }
    if ($c -match '(?i)\b(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\b') { $fail.Add('A8 il lettore non deve scrivere') }
    if ($c -notmatch 'Return ContactChannelPolicy\.SelectChannel\(rows\)') { $fail.Add('A8 scelta del canale fuori dal modulo puro') }
    # A9 contatto WhatsApp del sito: solo con numero valido E regola attiva, dall'azienda dell'host, mai nel checkout; il master non nomina la tabella
    $m = $f.master
    if ($m -notmatch '<asp:HyperLink ID="lnkWhatsAppContact" runat="server" Visible="false" EnableViewState="false" CssClass="ks-wa-contact" Target="_blank" rel="noopener noreferrer"') { $fail.Add('A9 link fisso nel master') }
    $bw = Get-Between $f.mastervb 'Private Sub BindWhatsAppContact' 'End Sub'
    if ($bw -eq '') { $fail.Add('A9 BindWhatsAppContact assente') }
    if ($bw -notmatch 'If channel Is Nothing OrElse Not channel\.WidgetEnabled OrElse channel\.WhatsAppNumber = "" Then Return') { $fail.Add('A9 pulsante senza controllo della regola') }
    if ($bw -notmatch 'StorefrontSeoTenantContext\.Resolve\(HttpContext\.Current\)' -or $bw -match 'Session\(') { $fail.Add('A9 azienda del pulsante non dall''host') }
    if ($bw -notmatch 'If IsCheckoutFlowPath\(CurrentScriptPathLower\(\)\) Then Return') { $fail.Add('A9 pulsante presente nel checkout') }
    $cf = Get-Between $f.mastervb 'Private Shared Function IsCheckoutFlowPath' 'End Function'
    foreach ($p in '/ordine.aspx', '/pagamento.aspx', '/bancasella.aspx', '/bancasella/', '/paypal') { if ($cf -notmatch [regex]::Escape('"' + $p)) { $fail.Add('A9 pagina di checkout non esclusa: ' + $p) } }
    if ($bw -notmatch 'lnkWhatsAppContact\.Attributes\("aria-label"\) = ') { $fail.Add('A9 nome accessibile') }
    if ($f.mastervb -match 'social_buttons') { $fail.Add('A9 Page.master.vb nomina la tabella (vietato da Test-HomePerfCaches)') }
    # A10 stile: bersagli da 44 px; pulsante fisso nell'angolo sotto goTop, sotto offcanvas e messaggio del carrello; con la barra d'acquisto sale insieme a goTop
    $toolRule = [regex]::Match($f.css, '(?s)\.ks-pdp-tool \{([^}]*)\}')
    $mh = [regex]::Match($toolRule.Groups[1].Value, 'min-height: (\d+)px')
    if (-not $mh.Success -or [int]$mh.Groups[1].Value -lt 44) { $fail.Add('A10 strumento sotto i 44 px') }
    $wa = [regex]::Match($f.uicss, '(?s)\.ks-wa-contact \{([^}]*)\}')
    $w = $wa.Groups[1].Value
    if (-not $wa.Success -or $w -notmatch 'position: fixed' -or $w -notmatch 'width: 52px' -or $w -notmatch 'height: 52px') { $fail.Add('A10 pulsante fisso') }
    if ($w -notmatch 'bottom: calc\(24px \+ env\(safe-area-inset-bottom, 0px\)\)') { $fail.Add('A10 pulsante non nell''angolo sotto goTop (goTop occupa 90-128 px)') }
    $z = [regex]::Match($w, 'z-index: (\d+)')
    if (-not $z.Success -or [int]$z.Groups[1].Value -ge 1045) { $fail.Add('A10 pulsante sopra offcanvas e messaggio del carrello') }
    if ($f.css -notmatch 'body\.ks-pdp-buybar-on \.ks-wa-contact \{ bottom: calc\(var\(--ks-pdp-buybar-h, 72px\) \+ 12px\); \}') { $fail.Add('A10 pulsante sotto la barra d''acquisto') }
    if ($f.css -notmatch 'body\.ks-pdp-buybar-on #goTop \{ bottom: calc\(var\(--ks-pdp-buybar-h, 72px\) \+ 76px\); \}') { $fail.Add('A10 goTop non spostato sopra il pulsante con la barra d''acquisto') }
    if ($f.uicss -notmatch '(?s)@media print \{\s*\.ks-wa-contact \{ display: none !important; \}') { $fail.Add('A10 pulsante fisso in stampa') }
    # A11 stampa: blocco dedicato in coda, niente selettore nudo header, galleria ferma, elementi fissi e di acquisto nascosti
    $print = Get-Between $f.css '/* KS-PDP-PRINT-A4-1A:' "`0"
    if ($print -notmatch '(?s)@page \{[^}]*size: A4 portrait;[^}]*\}\s*@media print \{') { $fail.Add('A11 blocco di stampa assente') }
    foreach ($sel in '.tf-header', '.tf-footer', '.ks-pdp-toc', '.ks-pdp-tools', '.product-box-btn', '.product-quantity', '.ks-review-form-wrap', '.ks-product-list-section', '#goTop', '.ks-pdp-buybar', '.ks-cart-feedback-toast', '#preload', '.offcanvas', '.modal', '.ks-wa-contact') { if ($print -notmatch ('(?m)^\s*' + [regex]::Escape($sel) + '\s*[,{]')) { $fail.Add('A11 in stampa resta ' + $sel) } }
    if ($print -match '(?m)^\s*(header|footer|nav)\s*[,{]') { $fail.Add('A11 selettore nudo che toglie i titoli delle sezioni') }
    if ($print -notmatch '\.swiper-wrapper \{[^}]*transform: none !important;') { $fail.Add('A11 galleria spostata fuori pagina') }
    if ($print -notmatch 'position: static !important') { $fail.Add('A11 elementi sticky in stampa') }
    if ($print -notmatch '\.ks-pdp-print-head \{[^}]*display: grid') { $fail.Add('A11 intestazione di stampa non mostrata') }
    if ($f.css -notmatch '(?m)^\.ks-pdp-print-head \{ display: none; \}') { $fail.Add('A11 intestazione di stampa visibile a schermo') }
    if ($print -notmatch 'break-inside: avoid') { $fail.Add('A11 righe tagliate fra due pagine') }
    if ($a -notmatch '<div class="ks-pdp-print-head" aria-hidden="true">') { $fail.Add('A11 intestazione di stampa nella pagina') }
    if ($f.css.TrimEnd() -match '\*/$') { $fail.Add('A11 commento in coda al foglio di stile (vietato da Test-HomeDeadCodeC)') }
    # A12 script: stampa con i details aperti e poi richiusi, condivisione nativa con annullo silenzioso, copia con ripiego onesto, nessuna rete
    $j = $f.js
    if ($j -notmatch 'window\.print\(\)') { $fail.Add('A12 stampa') }
    if ($j -notmatch "addEventListener\('beforeprint', openDetails\)" -or $j -notmatch "addEventListener\('afterprint', restoreDetails\)") { $fail.Add('A12 details non aperti per la stampa') }
    if ($j -notmatch "details:not\(\[open\]\):not\(\[data-ks-pdp-share\]\)") { $fail.Add('A12 la stampa apre anche il pannello condividi') }
    if ($j -notmatch "typeof navigator\.share === 'function'") { $fail.Add('A12 condivisione nativa non rilevata') }
    if ($j -notmatch "error\.name === 'AbortError'") { $fail.Add('A12 annullo trattato come errore') }
    if ($j -notmatch 'navigator\.clipboard' -or $j -notmatch "document\.execCommand\('copy'\)") { $fail.Add('A12 copia senza ripiego') }
    if ($j -notmatch 'showManualCopy\(\)') { $fail.Add('A12 copia fallita senza campo da copiare a mano') }
    if ($j -match 'fetch\(|XMLHttpRequest|sendBeacon|document\.write|innerHTML') { $fail.Add('A12 script con rete o HTML dinamico') }
    if ($a -notmatch 'js/ks-pdp-tools\.js"\) %>\?v=20261118-pdp-tools1a"') { $fail.Add('A12 script non caricato') }
    if ($a -notmatch 'css/product-ui\.css"\) %>\?v=20261118-pdp-print-a4"') { $fail.Add('A12 sigla del foglio di stile') }
    if ($m -notmatch 'css/ks-ui\.css"\) & "\?v=20261118-h1-legacy1a"') { $fail.Add('A12 sigla di ks-ui.css') }

    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

# ---- (B) comportamento del modulo puro -------------------------------------------------------------------------------------------
$probe = @'
Imports System
Imports System.Collections.Generic
Imports Microsoft.VisualBasic
Public Module ShareLinksProbe
    Public Function Run() As String
        Dim r As New List(Of String)()
        Dim S As Func(Of String, String) = Function(x) KeepStoreShareLinks.NormalizeWhatsAppNumber(x)
        r.Add("B01=" & (S("+39 333 1234567") = "393331234567" AndAlso S("0039 333-123.4567") = "393331234567" AndAlso S("393331234567") = "393331234567" AndAlso S("+39 (333) 1234567") = "393331234567").ToString())
        r.Add("B02=" & (S("081 7718326") = "" AndAlso S("3331234567a") = "" AndAlso S("") = "" AndAlso S(Nothing) = "" AndAlso S("1234567") = "" AndAlso S("1234567890123456") = "").ToString())
        r.Add("B03=" & (S("3331234567") = "" AndAlso S("++393331234567") = "" AndAlso S("39 333 1234567 int. 2") = "" AndAlso S("+39 (0) 81 7718326") = "" AndAlso S("39+3331234567") = "" AndAlso S("+0393331234567") = "" AndAlso S("0393331234567") = "").ToString())
        Dim chat As String = KeepStoreShareLinks.WhatsAppChatUrl("393331234567", "Ciao & benvenuti #1 100%" & vbCrLf & "riga due")
        r.Add("B04=" & (chat = "https://wa.me/393331234567?text=Ciao%20%26%20benvenuti%20%231%20100%25%0Ariga%20due").ToString())
        r.Add("B05=" & (KeepStoreShareLinks.WhatsAppChatUrl("081123", "x") = "" AndAlso KeepStoreShareLinks.WhatsAppChatUrl("393331234567", "") = "https://wa.me/393331234567").ToString())
        r.Add("B06=" & (KeepStoreShareLinks.WhatsAppShareUrl("a b") = "https://wa.me/?text=a%20b").ToString())
        Dim u As String = "https://www.esempio.it/articolo.aspx?id=5&TCid=7"
        Dim eu As String = "https%3A%2F%2Fwww.esempio.it%2Farticolo.aspx%3Fid%3D5%26TCid%3D7"
        r.Add("B07=" & (KeepStoreShareLinks.TelegramShareUrl(u, "Nome x") = "https://t.me/share/url?url=" & eu & "&text=Nome%20x").ToString())
        r.Add("B08=" & (KeepStoreShareLinks.FacebookShareUrl(u) = "https://www.facebook.com/sharer/sharer.php?u=" & eu).ToString())
        r.Add("B09=" & (KeepStoreShareLinks.XShareUrl(u, "Nome x") = "https://x.com/intent/post?url=" & eu & "&text=Nome%20x").ToString())
        r.Add("B10=" & (KeepStoreShareLinks.MailShareHref("", "Oggetto & co", "riga 1" & vbLf & "riga 2") = "mailto:?subject=Oggetto%20%26%20co&body=riga%201%0D%0Ariga%202").ToString())
        r.Add("B11=" & (KeepStoreShareLinks.MailShareHref("info@esempio.it", "a", "b") = "mailto:info@esempio.it?subject=a&body=b" AndAlso KeepStoreShareLinks.MailShareHref("non un indirizzo", "a", "b") = "" AndAlso KeepStoreShareLinks.MailShareHref("a@b.it?cc=x@y.it", "a", "b") = "").ToString())
        Dim E As Func(Of String, String) = Function(x) KeepStoreShareLinks.ExternalUrl(x)
        r.Add("B12=" & (E("http://") = "" AndAlso E("https://") = "" AndAlso E("javascript:alert(1)") = "" AndAlso E("//www.esempio.it/x") = "" AndAlso E("www.esempio.it") = "" AndAlso E("http://localhost/x") = "" AndAlso E("ftp://www.esempio.it/x") = "" AndAlso E(Nothing) = "" AndAlso E("  ") = "" AndAlso E("http://192.168.1.10/x") = "").ToString())
        r.Add("B13=" & (E(" https://www.esempio.it/prodotto?a=1&b=2 ") = "https://www.esempio.it/prodotto?a=1&b=2" AndAlso E("HTTP://WWW.Esempio.IT/Scheda.pdf") = "http://www.esempio.it/Scheda.pdf" AndAlso E("http://www.esempio.it/a b") = "http://www.esempio.it/a%20b").ToString())
        r.Add("B14=" & (E("https://www.esempio.it/" & New String("a"c, 300)) = "" AndAlso E("https://user:pw@www.esempio.it/") = "" AndAlso E("https://www.esempio.it/" & ChrW(10) & "x") = "" AndAlso E("https://www.esempio.it/""><script>") <> "" AndAlso Not E("https://www.esempio.it/""><script>").Contains("""") AndAlso Not E("https://www.esempio.it/""><script>").Contains("<")).ToString())
        r.Add("B15=" & (KeepStoreShareLinks.ExternalHost("https://www.Esempio.it:8443/x?y=1") = "www.esempio.it" AndAlso KeepStoreShareLinks.ExternalHost("non url") = "").ToString())
        Dim nl As String() = New String() {vbLf}
        Dim info As String = KeepStoreShareLinks.ProductInfoMessage("Mouse *ottico*" & vbCrLf & "USB ~x~ `y`", "AB_12", "12,50 " & ChrW(&H20AC), "IVA inclusa", u)
        Dim lines As String() = info.Split(nl, StringSplitOptions.None)
        r.Add("B16=" & (lines.Length = 5 AndAlso lines(0) = "Buongiorno, vorrei informazioni su questo articolo:" AndAlso lines(1) = "*Mouse ottico USB x y*" AndAlso lines(2) = "Codice: AB_12" AndAlso lines(3) = "Prezzo: 12,50 " & ChrW(&H20AC) & " (IVA inclusa)" AndAlso lines(4) = u).ToString())
        r.Add("B17=" & (KeepStoreShareLinks.ProductInfoMessage("Nome", "", "", "", u) = "Buongiorno, vorrei informazioni su questo articolo:" & vbLf & "*Nome*" & vbLf & u).ToString())
        r.Add("B18=" & (KeepStoreShareLinks.ProductAvailabilityMessage("Nome", "C1", u, False) = "Buongiorno, vorrei essere avvisato quando questo articolo torna disponibile:" & vbLf & "*Nome*" & vbLf & "Codice: C1" & vbLf & u).ToString())
        r.Add("B19=" & (KeepStoreShareLinks.ProductAvailabilityMessage("Nome", "", u, True) = "Buongiorno, vorrei sapere quando arriva questo articolo:" & vbLf & "*Nome*" & vbLf & u).ToString())
        Dim longName As String = KeepStoreShareLinks.ProductInfoMessage(New String("n"c, 400), "c", "", "", u)
        r.Add("B20=" & (longName.Split(nl, StringSplitOptions.None)(1).Length <= 165 AndAlso longName.EndsWith(u) AndAlso KeepStoreShareLinks.ProductInfoMessage("Nome", "c", "1", "x", "") = "").ToString())
        r.Add("B21=" & (KeepStoreShareLinks.SiteContactMessage("www.esempio.it") = "Buongiorno, vi scrivo dal sito www.esempio.it" AndAlso KeepStoreShareLinks.SiteContactMessage("") = "Buongiorno, vi scrivo dal vostro sito").ToString())
        Dim html As String = KeepStoreShareLinks.ShareLinksHtml(u, "Nome <b>""x""</b> & co")
        r.Add("B22=" & (html.Contains("href=""https://wa.me/?text=") AndAlso html.Contains("href=""https://t.me/share/url?") AndAlso html.Contains("href=""https://www.facebook.com/sharer/") AndAlso html.Contains("href=""https://x.com/intent/post?") AndAlso html.Contains("href=""mailto:?subject=")).ToString())
        r.Add("B23=" & (Not html.Contains("<b>") AndAlso Not html.Contains("""x""") AndAlso (System.Text.RegularExpressions.Regex.Matches(html, "target=""_blank"" rel=""noopener noreferrer""").Count = 4) AndAlso html.Contains("&amp;text=")).ToString())
        r.Add("B24=" & (KeepStoreShareLinks.ShareLinksHtml("", "Nome") = "" AndAlso KeepStoreShareLinks.ShareLinksHtml("javascript:x", "Nome") = "").ToString())
        ' scelta del canale: una sola riga valida, altrimenti nessun canale
        Dim one As New List(Of ContactChannelRow)()
        one.Add(New ContactChannelRow("+39 333 1234567", 1, "  Scrivici  ", "LEFT"))
        Dim ch As ContactChannel = ContactChannelPolicy.SelectChannel(one)
        r.Add("B25=" & (ch.WhatsAppNumber = "393331234567" AndAlso ch.WidgetEnabled AndAlso ch.CallToAction = "Scrivici" AndAlso ch.Position = "left").ToString())
        Dim two As New List(Of ContactChannelRow)(one)
        two.Add(New ContactChannelRow("393339999999", 1, "", "right"))
        r.Add("B26=" & (ContactChannelPolicy.SelectChannel(two) Is ContactChannel.None AndAlso ContactChannelPolicy.SelectChannel(Nothing) Is ContactChannel.None AndAlso ContactChannelPolicy.SelectChannel(New List(Of ContactChannelRow)()) Is ContactChannel.None).ToString())
        Dim bad As New List(Of ContactChannelRow)()
        bad.Add(New ContactChannelRow("3331234567", 1, "x", "right"))
        r.Add("B27=" & (ContactChannelPolicy.SelectChannel(bad) Is ContactChannel.None).ToString())
        Dim off As New List(Of ContactChannelRow)()
        off.Add(New ContactChannelRow("393331234567", 0, "", "sopra"))
        Dim chOff As ContactChannel = ContactChannelPolicy.SelectChannel(off)
        r.Add("B28=" & (chOff.WhatsAppNumber = "393331234567" AndAlso Not chOff.WidgetEnabled AndAlso chOff.Position = "right" AndAlso chOff.CallToAction = "").ToString())
        Dim odd As New List(Of ContactChannelRow)()
        odd.Add(New ContactChannelRow("393331234567", 2, New String("c"c, 300), "right"))
        Dim chOdd As ContactChannel = ContactChannelPolicy.SelectChannel(odd)
        r.Add("B29=" & (Not chOdd.WidgetEnabled AndAlso chOdd.CallToAction.Length <= 80).ToString())
        Return String.Join(";", r.ToArray())
    End Function
End Module
'@

function Test-Behaviour([string]$moduleText, [switch]$Quiet) {
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    [void]$p.ReferencedAssemblies.Add('System.dll')
    [void]$p.ReferencedAssemblies.Add('System.Core.dll')
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($moduleText, $files.links, $probe))
    if ($c.Errors.HasErrors) { if (-not $Quiet) { foreach ($e in $c.Errors) { Write-Host ('  COMPILE ' + $e.ErrorText) } }; return $false }
    $out = [string]$c.CompiledAssembly.GetType('ShareLinksProbe').GetMethod('Run').Invoke($null, @())
    $ok = $true
    foreach ($kv in $out.Split(';')) { if (-not $kv.EndsWith('=True')) { $ok = $false; if (-not $Quiet) { Write-Host ('  FAIL ' + $kv) } } }
    return $ok
}

$okSource = Test-Source $files
$okBehaviour = Test-Behaviour $files.share
if (-not ($okSource -and $okBehaviour)) { Write-Host 'PDP_TOOLS FAIL'; exit 1 }

# ---- (C) mutazioni -----------------------------------------------------------------------------------------------------------------
$mutants = @(
    @{ Id = 'M01_NO_CAST_RULE'; File = 'channels'; Old = 'CAST(COALESCE(r.enabled,0) AS SIGNED) AS WidgetEnabled'; New = 'COALESCE(r.enabled,0) AS WidgetEnabled' },
    @{ Id = 'M02_ALL_COMPANIES'; File = 'channels'; Old = 'WHERE b.company_id=@companyId AND '; New = 'WHERE ' },
    @{ Id = 'M03_DISABLED_BUTTONS_TOO'; File = 'channels'; Old = " AND b.enabled=1"; New = '' },
    @{ Id = 'M04_CACHE_WITHOUT_COMPANY'; File = 'channels'; Old = 'StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey(), companyId, String.Empty, CacheSeconds,'; New = 'StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey(), 1, String.Empty, CacheSeconds,' },
    @{ Id = 'M05_MISSING_TABLE_THROWS'; File = 'channels'; Old = 'If ex.Number = 1146 Then Return ContactChannel.None'; New = '' },
    @{ Id = 'M06_NOTIFY_ALWAYS'; File = 'vb'; Old = 'phToolNotify.Visible = unavailable AndAlso notifyHref <> ""'; New = 'phToolNotify.Visible = notifyHref <> ""' },
    @{ Id = 'M07_NOTIFY_STATIC_VISIBLE'; File = 'aspx'; Old = '<asp:PlaceHolder ID="phToolNotify" runat="server" Visible="false">'; New = '<asp:PlaceHolder ID="phToolNotify" runat="server">' },
    @{ Id = 'M08_PROMISE_LABEL'; File = 'aspx'; Old = '<span class="ks-pdp-tool__label">Chiedi di essere avvisato</span>'; New = '<span class="ks-pdp-tool__label">Avvisami</span>' },
    @{ Id = 'M09_COMPANY_FROM_SESSION'; File = 'vb'; Old = 'KeepStoreContactChannels.ForCompany(tenant.CompanyId)'; New = 'KeepStoreContactChannels.ForCompany(Convert.ToInt32(Session("AziendaID")))' },
    @{ Id = 'M10_REQUEST_HOST_URL'; File = 'vb'; Old = 'StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenant, '; New = 'MakeAbsoluteUrl(' },
    @{ Id = 'M11_SHARE_WITHOUT_URL'; File = 'vb'; Old = 'phToolShare.Visible = (shareUrl <> "")'; New = 'phToolShare.Visible = True' },
    @{ Id = 'M12_NO_NOOPENER'; File = 'vb'; Old = 'link.Attributes("rel") = "noopener noreferrer"'; New = 'link.Attributes("rel") = "nofollow"' },
    @{ Id = 'M13_MANUFACTURER_UNVALIDATED'; File = 'vb'; Old = 'KeepStoreShareLinks.ExternalUrl(GetRowString(row, "LinkProduttore"))'; New = 'GetRowString(row, "LinkProduttore")' },
    @{ Id = 'M14_MANUFACTURER_ROW_ALWAYS'; File = 'vb'; Old = 'phManufacturerLink.Visible = (manufacturerUrl <> "")'; New = 'phManufacturerLink.Visible = True' },
    @{ Id = 'M15_TOOLS_BEFORE_AVAILABILITY'; File = 'vb'; Old = "BindPdpCartState(_id, currentTcid, True)`r`n        BindProductTools("; New = "BindPdpCartState(_id, currentTcid, True)`r`n        ' BindProductTools(" },
    @{ Id = 'M16_WIDGET_WITHOUT_RULE'; File = 'mastervb'; Old = 'If channel Is Nothing OrElse Not channel.WidgetEnabled OrElse channel.WhatsAppNumber = "" Then Return'; New = 'If channel Is Nothing OrElse channel.WhatsAppNumber = "" Then Return' },
    @{ Id = 'M17_WIDGET_IN_CHECKOUT'; File = 'mastervb'; Old = 'If IsCheckoutFlowPath(CurrentScriptPathLower()) Then Return'; New = '' },
    @{ Id = 'M18_WIDGET_VISIBLE_BY_DEFAULT'; File = 'master'; Old = 'ID="lnkWhatsAppContact" runat="server" Visible="false"'; New = 'ID="lnkWhatsAppContact" runat="server" Visible="true"' },
    @{ Id = 'M19_SUBMIT_BUTTON'; File = 'aspx'; Old = '<button type="button" class="ks-pdp-tool" data-ks-pdp-print>'; New = '<button class="ks-pdp-tool" data-ks-pdp-print>' },
    @{ Id = 'M20_THIRD_PARTY_WIDGET'; File = 'aspx'; Old = '<nav class="ks-pdp-tools"'; New = '<script src="//s7.addthis.com/js/300/addthis_widget.js"></script><nav class="ks-pdp-tools"' },
    @{ Id = 'M21_SMALL_TARGET'; File = 'css'; Old = "  min-height: 44px;`r`n  padding: 0 12px;"; New = "  min-height: 30px;`r`n  padding: 0 12px;" },
    @{ Id = 'M22_WIDGET_OVER_GOTOP'; File = 'uicss'; Old = 'bottom: calc(24px + env(safe-area-inset-bottom, 0px));'; New = 'bottom: calc(84px + env(safe-area-inset-bottom, 0px));' },
    @{ Id = 'M23_WIDGET_ABOVE_OFFCANVAS'; File = 'uicss'; Old = 'z-index: 1030;'; New = 'z-index: 2000;' },
    @{ Id = 'M24_GOTOP_NOT_RAISED'; File = 'css'; Old = 'body.ks-pdp-buybar-on #goTop { bottom: calc(var(--ks-pdp-buybar-h, 72px) + 76px); }'; New = '' },
    @{ Id = 'M25_PRINT_KEEPS_TOOLS'; File = 'css'; Old = "  .ks-pdp-tools,`r`n"; New = '' },
    @{ Id = 'M26_PRINT_BARE_HEADER'; File = 'css'; Old = "  .tf-header,`r`n"; New = "  header,`r`n  .tf-header,`r`n" },
    @{ Id = 'M27_PRINT_GALLERY_SHIFTED'; File = 'css'; Old = "    transform: none !important;`r`n"; New = '' },
    @{ Id = 'M28_PRINT_TOAST'; File = 'css'; Old = "  .ks-cart-feedback-toast,`r`n"; New = '' },
    @{ Id = 'M29_PRINT_HEAD_ON_SCREEN'; File = 'css'; Old = '.ks-pdp-print-head { display: none; }'; New = '.ks-pdp-print-head { display: block; }' },
    @{ Id = 'M30_EXTRA_QUERY'; File = 'vb'; Old = '"SELECT NormeGaranzia FROM articoli WHERE id = @id LIMIT 1"'; New = '"SELECT NormeGaranzia, LinkProduttore FROM articoli WHERE id = @id LIMIT 1"' },
    @{ Id = 'M31_JS_NETWORK'; File = 'js'; Old = 'window.print()'; New = "fetch('/x'); window.print()" },
    @{ Id = 'M32_ABORT_AS_ERROR'; File = 'js'; Old = "if (error && error.name === 'AbortError') { return; }"; New = '' },
    @{ Id = 'M33_PRINT_OPENS_SHARE'; File = 'js'; Old = "details:not([open]):not([data-ks-pdp-share])"; New = "details:not([open])" },
    @{ Id = 'M34_OLD_BUSTER'; File = 'aspx'; Old = 'css/product-ui.css") %>?v=20261118-pdp-print-a4"'; New = 'css/product-ui.css") %>?v=20261118-pdp-sections1a"' },
    @{ Id = 'M35_MASTER_NAMES_TABLE'; File = 'mastervb'; Old = 'Private Sub BindWhatsAppContact'; New = "' social_buttons`r`n    Private Sub BindWhatsAppContact" }
)
$behaviourMutants = @(
    @{ Id = 'N01_ACCEPT_LEADING_ZERO'; Old = 'If digits.StartsWith("0", StringComparison.Ordinal) Then Return ""'; New = '' },
    @{ Id = 'N02_NATIONAL_MOBILE_OK'; Old = 'If digits.Length < MinWhatsAppDigits OrElse digits.Length > MaxWhatsAppDigits Then Return ""'; New = 'If digits.Length < 8 OrElse digits.Length > MaxWhatsAppDigits Then Return ""' },
    @{ Id = 'N03_NO_ENCODING'; Old = 'Return Uri.EscapeDataString(NormalizeNewLines(value, lineBreak))'; New = 'Return NormalizeNewLines(value, lineBreak)' },
    @{ Id = 'N04_PLACEHOLDER_URL_OK'; Old = 'If parsed.HostNameType <> UriHostNameType.Dns OrElse parsed.Host.IndexOf("."c) <= 0 Then Return ""'; New = '' },
    @{ Id = 'N05_ANY_SCHEME'; Old = 'If parsed.Scheme <> Uri.UriSchemeHttp AndAlso parsed.Scheme <> Uri.UriSchemeHttps Then Return ""'; New = '' },
    @{ Id = 'N06_MARKERS_KEPT'; Old = 'If ch = "*"c OrElse ch = "~"c OrElse ch = "`"c Then Continue For'; New = '' },
    @{ Id = 'N07_HTML_NOT_ENCODED'; Old = 'WebUtility.HtmlEncode(href)'; New = 'href' },
    @{ Id = 'N08_USERINFO_OK'; Old = 'If parsed.UserInfo <> "" Then Return ""'; New = '' },
    @{ Id = 'N09_MAIL_RECIPIENT_UNCHECKED'; Old = 'target = KeepStoreContactLinks.BuildMailtoHref(recipient)'; New = 'target = "mailto:" & recipient' },
    @{ Id = 'N10_TWO_ROWS_FIRST_WINS'; Old = 'If rows Is Nothing OrElse rows.Count <> 1 Then Return ContactChannel.None'; New = 'If rows Is Nothing OrElse rows.Count < 1 Then Return ContactChannel.None' },
    @{ Id = 'N11_RULE_ANY_NONZERO'; Old = 'row.WidgetEnabled = 1'; New = 'row.WidgetEnabled <> 0' },
    @{ Id = 'N12_EMPTY_URL_MESSAGE'; Old = 'If link = "" Then Return ""'; New = '' },
    @{ Id = 'N13_INCOMING_TEXT_SWAPPED'; Old = 'If(incoming, IncomingRequest, AvailabilityRequest)'; New = 'If(incoming, AvailabilityRequest, IncomingRequest)' }
)
$bad = 0
foreach ($mu in $mutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
foreach ($mu in $behaviourMutants) {
    if (-not $files.share.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    if (Test-Behaviour ($files.share.Replace($mu.Old, $mu.New)) -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'PDP_TOOLS FAIL (mutanti)'; exit 1 }

# ---- (D) LAB: lettura reale con il connettore del sito --------------------------------------------------------------------------------
$labNote = 'LAB saltato'
if (-not $SkipLab) {
    $credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
    $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $bin = Join-Path $root 'Bin'
    $labUp = $false
    try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 13317); $labUp = $t.Connected; $t.Close() } catch { $labUp = $false }
    if (-not ((Test-Path -LiteralPath $credFile) -and (Test-Path -LiteralPath $vbc) -and $labUp)) {
        $labNote = 'LAB non disponibile su questa macchina: parte (D) NON ESEGUITA'
    } else {
        $work = Join-Path $env:TEMP ('ks-pdptools-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        try {
            foreach ($dep in 'MySql.Data.dll', 'Google.Protobuf.dll', 'BouncyCastle.Cryptography.dll', 'System.Buffers.dll', 'System.Memory.dll', 'System.Numerics.Vectors.dll', 'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll') {
                if (Test-Path -LiteralPath (Join-Path $bin $dep)) { Copy-Item -LiteralPath (Join-Path $bin $dep) -Destination $work -Force }
            }
            $cfg = '<?xml version="1.0" encoding="utf-8"?><configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/></startup><runtime><assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">' +
                '<dependentAssembly><assemblyIdentity name="System.Threading.Tasks.Extensions" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.2.4.0" newVersion="4.2.4.0"/></dependentAssembly>' +
                '<dependentAssembly><assemblyIdentity name="System.Buffers" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
                '<dependentAssembly><assemblyIdentity name="System.Memory" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
                '<dependentAssembly><assemblyIdentity name="System.Runtime.CompilerServices.Unsafe" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-6.0.3.0" newVersion="6.0.3.0"/></dependentAssembly>' +
                '<dependentAssembly><assemblyIdentity name="System.Numerics.Vectors" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.1.6.0" newVersion="4.1.6.0"/></dependentAssembly>' +
                '</assemblyBinding></runtime></configuration>'
            $exe = Join-Path $work 'PdpToolsLabHarness.exe'
            [IO.File]::WriteAllText($exe + '.config', $cfg, $utf8)
            $ref = '/reference:' + (Join-Path $bin 'MySql.Data.dll')
            $build = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ /out:$exe $ref /reference:System.dll /reference:System.Data.dll /reference:System.Web.dll /reference:System.Configuration.dll /reference:System.Core.dll (Join-Path $root 'Tools\PdpToolsLabHarness.vb') (Join-Path $root 'App_Code\KeepStoreContactChannels.vb') (Join-Path $root 'App_Code\KeepStoreShareLinks.vb') (Join-Path $root 'App_Code\KeepStoreContactLinks.vb') 2>&1
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { $build | ForEach-Object { Write-Host ('  ' + $_) }; Write-Host 'PDP_TOOLS FAIL (harness LAB non compila)'; exit 1 }
            $cred = Import-Clixml -LiteralPath $credFile
            $plain = $cred.GetNetworkCredential().Password
            $info = New-Object Diagnostics.ProcessStartInfo
            $info.FileName = $exe; $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.CreateNoWindow = $true
            $info.EnvironmentVariables['KS_LAB_USER'] = $cred.UserName
            $info.EnvironmentVariables['KS_LAB_PWD'] = $plain
            $proc = [Diagnostics.Process]::Start($info)
            $stdout = $proc.StandardOutput.ReadToEnd(); $stderr = $proc.StandardError.ReadToEnd(); $proc.WaitForExit()
            if ($plain) { $stdout = $stdout.Replace($plain, '<hidden>'); $stderr = $stderr.Replace($plain, '<hidden>') }
            $plain = $null; $cred = $null
            $summary = @($stdout -split "`r?`n" | Where-Object { $_ -match '^PDP_TOOLS_LAB ' }) | Select-Object -Last 1
            if ($proc.ExitCode -ne 0 -or $summary -notmatch 'FAIL=0$') {
                @($stdout -split "`r?`n" | Where-Object { $_ -match '^(FAIL|HARNESS_ERROR|PDP_TOOLS_LAB)' }) | ForEach-Object { Write-Host ('  ' + $_) }
                if ($stderr.Trim()) { Write-Host ('  stderr: ' + $stderr.Trim()) }
                Write-Host 'PDP_TOOLS FAIL (LAB)'; exit 1
            }
            $labNote = $summary
        } finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
Write-Host ('PDP_TOOLS PASS (' + ($mutants.Count + $behaviourMutants.Count) + ' mutanti; ' + $labNote + ')')
exit 0
