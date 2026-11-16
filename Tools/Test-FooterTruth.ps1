[CmdletBinding()]
param()

# KS-B02A-FOOTER-TRUTH-1A - il piede del sito dice solo cio che e vero per l'azienda e rimanda solo a pagine che esistono.
# Oracolo 1 (markup reale di SiteFooter.ascx): nessun testo del template o inventato (telefono finto, promozione, newsletter in inglese, social generici, pagamenti fissi, "#"),
# ogni link interno punta a un file .aspx che esiste (e l'ancora esiste nel file di destinazione), nessuna etichetta fissa da elettronica.
# Oracolo 2 (codice reale di SiteFooter.ascx.vb, regione FooterPure, compilato in memoria): telefono, e-mail, Facebook, copyright e contatti con casi limite e iniezioni;
# due aziende sintetiche e sessione di un'altra azienda senza dati incrociati. Oracolo 3: il collegamento del codice (nessun database, nessun ripiego sulla sessione).
# Limite noto: l'ancora #diritto-recesso e uno span vuoto sopra il testo letto dal database (condizioni-vendita.aspx): il test prova che esiste, non che il testo parli di recesso.
# KS-B02B-FOOTER-LEGAL-1A - i dati societari (ragione sociale, P.IVA, sede legale e operativa) vengono SOLO dal profilo legale dell'azienda dell'host.
# Oracolo 4 (markup): il blocco legale e un controllo del server dentro .ft-bottom, senza testo fisso. Oracolo 5 (regione FooterPure compilata INSIEME al file della policy):
# regole di visualizzazione, due aziende con marcatori disgiunti, profilo di un'altra azienda = nessun dato. Oracolo 6 (policy compilata): mappatura colonna -> proprieta,
# aggancio profilo -> identita solo per Id che compare UNA volta (la chiave di aziende e (id, IvaTipo): l'id non e unico per schema). Oracolo 7 (testo del caricatore): il SELECT principale
# e invariato, il secondo e facoltativo, dopo la chiusura del primo reader e prima della cache. Confronti sensibili alle maiuscole (-ceq, -cne, -cmatch).
# Mutazioni su copie in memoria. Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
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
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}

$ascx = Read-Repo 'Public/ui/controls/SiteFooter.ascx'
$vb = Read-Repo 'Public/ui/controls/SiteFooter.ascx.vb'
$policy = Read-Repo 'App_Code/StorefrontCanonicalHostPolicy.vb'
$links = Read-Repo 'App_Code/KeepStoreContactLinks.vb'
$ctx = Read-Repo 'App_Code/StorefrontSeoTenantContext.vb'

# --- Oracolo 1: markup reale -----------------------------------------------------------------------------------------------------------------
function Test-NoFabricatedContent([string]$text) {
    foreach ($bad in @('10% Off', 'Enter your email', 'Subscribe', 'Be the first', '+39 000', '390000000000', 'x.com', 'linkedin.com', 'whatsapp.com',
                       'Pagamenti accettati', 'method-payment', 'Discover', 'Visa', 'PayPal', 'Mastercard', 'ft-body-center', 'ksNewsletter', 'litSupportEmail', 'lnkSupportEmail',
                       'Nuovi arrivi', 'Occasione del giorno', 'Top offerte', 'Informazioni consegna', 'Servizio clienti', 'Resi e cambi', 'Supporto prodotti',
                       'Notebook e computer', 'Gaming e console', 'Smartphone e tablet', 'Accessori tech', 'Audio e cuffie', 'Fotografia e video', 'icon-location',
                       'P.IVA', 'Partita IVA', 'Sede legale', 'Sede operativa', 'Capitale sociale', 'Registro imprese')) {
        if ($text.IndexOf($bad, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $false }
    }
    if ($text -match 'href="#"') { return $false }
    if ($text -match '(?i)onsus') { return $false }
    return $true
}
function Get-StaticHrefs([string]$text) {
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($text, '<a\b[^>]*?\shref="([^"<>]*)"')) { $list.Add($m.Groups[1].Value) }
    return $list
}
function Test-StaticLinksExist([string]$text) {
    $hrefs = Get-StaticHrefs $text
    # insieme chiuso: aggiungere un link (per esempio a una pagina con testo da un'altra merceologia) richiede di cambiare questo test e di decidere
    $expected = @('Default.aspx', 'condizioni-vendita.aspx', 'condizioni-vendita.aspx#diritto-recesso', 'faq.aspx', 'privacy.aspx', 'myaccount.aspx', 'pay_your_orders.aspx', 'track-your-order.aspx', 'articoli.aspx?inpromo=1', 'Contattaci.aspx')
    if (($hrefs | Sort-Object) -join '|' -ne (($expected | Sort-Object) -join '|')) { return $false }
    foreach ($h in $hrefs) {
        if ($h -match '^(https?:|mailto:|tel:|//)') { return $false }
        $path = $h; $anchor = ''
        $i = $path.IndexOf('#'); if ($i -ge 0) { $anchor = $path.Substring($i + 1); $path = $path.Substring(0, $i) }
        $i = $path.IndexOf('?'); if ($i -ge 0) { $path = $path.Substring(0, $i) }
        if ($path -eq '' -or $path -notmatch '^[A-Za-z0-9_\-]+\.aspx$') { return $false }
        $file = Join-Path $repoRoot $path
        if (-not (Test-Path -LiteralPath $file)) { return $false }
        if ($anchor -ne '') {
            $dest = Norm ([IO.File]::ReadAllText($file))
            if ($dest -notmatch ('id="' + [regex]::Escape($anchor) + '"')) { return $false }
        }
    }
    return $true
}
function Test-RequiredLinks([string]$text) {
    foreach ($pair in @(
        @('condizioni-vendita.aspx', 'Condizioni di vendita'), @('condizioni-vendita.aspx#diritto-recesso', 'Diritto di recesso'),
        @('faq.aspx', 'Domande frequenti'), @('privacy.aspx', 'Privacy'), @('Contattaci.aspx', 'Contatti'),
        @('myaccount.aspx', 'Il mio account'), @('pay_your_orders.aspx', 'I miei ordini'), @('track-your-order.aspx', 'Traccia il tuo ordine'),
        @('articoli.aspx?inpromo=1', 'Offerte'))) {
        if ($text -notmatch ('<a class="[^"]*" href="' + [regex]::Escape($pair[0]) + '">' + [regex]::Escape($pair[1]) + '</a>')) { return $false }
    }
    return $true
}
function Test-DynamicHooks([string]$text) {
    foreach ($id in @('ulFooterColumns', 'phFooterCategories', 'litFooterCategories', 'litFooterContacts', 'litFooterCopyright', 'ulFooterSocial', 'liFooterFacebook', 'lnkFooterFacebook', 'imgFooterLogo', 'phFooterLegal', 'litFooterLegal')) {
        if ($text -notmatch ('\bID="' + $id + '"') -and $text -notmatch ('\bid="' + $id + '"')) { return $false }
    }
    # il blocco e il piede stampabile nascosto da ordine.aspx; la griglia e un controllo del server (3 o 4 colonne decise dal codice)
    if ($text -notmatch '<footer class="tf-footer">') { return $false }
    foreach ($lit in @('litFooterCategories', 'litFooterContacts', 'litFooterCopyright', 'litFooterLegal')) {
        if ($text -notmatch ('<asp:Literal ID="' + $lit + '" runat="server" EnableViewState="False" />')) { return $false }
    }
    if ($text -notmatch '<i class="icon-facebook" aria-hidden="true"></i>') { return $false }
    return ($text -match '<ul id="ulFooterColumns" runat="server" class="ft-link-wrap w-100 tf-grid-layout md-col-2')
}

Assert-Source (Test-NoFabricatedContent $ascx) 'F01_NO_FABRICATED_OR_TEMPLATE_CONTENT_IN_THE_FOOTER_MARKUP'
Assert-Source (Test-StaticLinksExist $ascx) 'F02_EVERY_STATIC_FOOTER_LINK_POINTS_TO_AN_EXISTING_PAGE_AND_ANCHOR'
Assert-Source (Test-RequiredLinks $ascx) 'F03_THE_REAL_LEGAL_AND_ACCOUNT_PAGES_ARE_LINKED_WITH_THEIR_OWN_LABELS'
Assert-Source (Test-DynamicHooks $ascx) 'F04_DYNAMIC_PARTS_ARE_SERVER_CONTROLS_WITHOUT_VIEWSTATE'

# il blocco dei dati societari: un controllo del server (nascosto se vuoto) dentro .ft-bottom, prima del copyright, a capo anche per nomi lunghi (text-break), nessun testo fisso
function Test-LegalMarkup([string]$text) {
    $one = '<asp:PlaceHolder ID="phFooterLegal" runat="server" Visible="false">\s*<p class="caption text-center text-break ft-legal"><asp:Literal ID="litFooterLegal" runat="server" EnableViewState="False" /></p>\s*</asp:PlaceHolder>'
    if ([regex]::Matches($text, 'phFooterLegal').Count -ne 1 -or [regex]::Matches($text, 'litFooterLegal').Count -ne 1) { return $false }
    return ($text -cmatch ('(?s)<div class="ft-bottom">.*?' + $one + '.*?<p class="nocopy caption text-center"><asp:Literal ID="litFooterCopyright"'))
}
Assert-Source (Test-LegalMarkup $ascx) 'F09_THE_LEGAL_BLOCK_IS_A_HIDDEN_SERVER_CONTROL_INSIDE_THE_BOTTOM_ROW_BEFORE_THE_COPYRIGHT'

# --- Oracolo 2: il VERO codice (regione FooterPure di SiteFooter.ascx.vb) compilato ed eseguito ---------------------------------------------------
function Get-PureRegion([string]$vbText) {
    $m = [regex]::Match($vbText, '(?ms)^[ \t]*#Region "FooterPure"\n(.*?)\n[ \t]*#End Region')
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
function Compile-Footer([string]$region, [string]$policyText, [string]$linksText) {
    $code = @"
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Public Class FooterProbe
$region
    Public Function Fb(ByVal tenantId As Integer, ByVal sessionId As Integer, ByVal raw As String) As String
        Return ResolveFooterFacebookUrl(tenantId, sessionId, raw)
    End Function
    Public Function Tel(ByVal p As String) As String
        Return KeepStoreContactLinks.BuildTelHref(p)
    End Function
    Public Function Mail(ByVal e As String) As String
        Return KeepStoreContactLinks.BuildMailtoHref(e)
    End Function
    Public Function Copy(ByVal y As Integer, ByVal n As String) As String
        Return BuildCopyrightHtml(y, n)
    End Function
    Public Function Allowed(ByVal t As Integer, ByVal s As Integer) As Boolean
        Return IsFooterTenantAllowed(t, s)
    End Function
    Public Function Contacts(ByVal n As String, ByVal p As String, ByVal e As String) As String
        Return BuildFooterContactsHtml(n, p, e)
    End Function
    Public Function Data(ByVal host As Integer, ByVal sess As Integer, ByVal name As String, ByVal logo As String, ByVal phone As String, ByVal email As String, ByVal fb As String, ByVal year As Integer) As String()
        Dim d As FooterData = BuildFooterData(host, sess, name, logo, phone, email, fb, Nothing, Nothing, False, year)
        Return New String() {d.LogoFileName, d.CompanyName, d.FacebookUrl, d.ContactsHtml, d.CopyrightHtml}
    End Function
    Private Shared Function Prof(ByVal id As Integer, ByVal f As String()) As StorefrontCompanyLegalProfile
        Return New StorefrontCompanyLegalProfile(id, f(0), f(1), f(2), f(3), f(4), f(5), f(6), f(7), f(8), f(9))
    End Function
    Public Function Legal(ByVal f As String()) As String
        Return BuildFooterLegalHtml(Prof(1, f))
    End Function
    Public Function LegalNothing() As String
        Return BuildFooterLegalHtml(Nothing)
    End Function
    Public Function Vat(ByVal v As String) As String
        Return NormalizeVatNumber(v)
    End Function
    Public Function DataL(ByVal host As Integer, ByVal sess As Integer, ByVal name As String, ByVal profileId As Integer, ByVal f As String()) As String()
        Dim p As StorefrontCompanyLegalProfile = Nothing
        If f IsNot Nothing Then p = Prof(profileId, f)
        Dim d As FooterData = BuildFooterData(host, sess, name, "", "", "", "", p, Nothing, False, 2026)
        Return New String() {d.LegalHtml, d.ContactsHtml, d.CopyrightHtml}
    End Function
    Public Function Cats(ByVal spec As String, ByVal max As Integer) As String
        Dim items As New List(Of KeyValuePair(Of String, String))()
        If spec IsNot Nothing Then
            For Each part As String In spec.Split(New Char() {";"c}, StringSplitOptions.RemoveEmptyEntries)
                Dim i As Integer = part.IndexOf("|"c)
                items.Add(New KeyValuePair(Of String, String)(part.Substring(0, i), part.Substring(i + 1)))
            Next
        End If
        Return BuildFooterCategoriesHtml(items, max)
    End Function
    Public Function Grid(ByVal n As Integer) As String
        Return FooterGridClass(n)
    End Function
End Class
"@
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Web.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($policyText, $linksText, $code))
    if ($c.Errors.HasErrors) { throw ('FOOTER_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('FooterProbe', $true))
}
function Test-Behaviour([string]$vbText, [string]$policyText, [string]$linksText) {
    $region = Get-PureRegion $vbText
    if ($null -eq $region) { throw 'FOOTER_PURE_REGION_NOT_FOUND' }
    $p = Compile-Footer $region $policyText $linksText
    # Facebook: solo se la sessione appartiene all'azienda dell'host (la stessa riga che ha scritto il link) e l'indirizzo e https su un host facebook
    $fbUrl = 'https://www.facebook.com/alfa.srl'
    if ($p.Fb(1, 1, $fbUrl) -ne $fbUrl -or $p.Fb(1, 1, (' ' + $fbUrl + ' ')) -ne $fbUrl) { return $false }
    if ($p.Fb(1, 2, $fbUrl) -ne '' -or $p.Fb(1, 0, $fbUrl) -ne '' -or $p.Fb(0, 0, $fbUrl) -ne '' -or $p.Fb(0, 1, $fbUrl) -ne '' -or $p.Fb(1, -1, $fbUrl) -ne '') { return $false }
    foreach ($f in @('http://www.facebook.com/x', 'https://evil.example/facebook.com', 'https://facebook.com.evil.example/x', 'https://www.facebook.com@evil.example/x', 'javascript:alert(1)', '//www.facebook.com/x', 'https://notfacebook.com/x', 'https://l.facebook.com/l.php?u=http://evil.example', 'https://evil.facebook.com/x', 'https://sub.fb.com/x', '', '   ', ('https://www.facebook.com/' + [char]10 + 'x'), 'https://www.facebook.com/x"onclick="1')) { if ($p.Fb(1, 1, $f) -ne '') { return $false } }
    if ($p.Fb(1, 1, ('https://www.facebook.com/x' + [char]13 + [char]10)) -ne 'https://www.facebook.com/x') { return $false }
    if ($p.Fb(1, 1, $null) -ne '') { return $false }
    foreach ($f in @('https://facebook.com/x', 'https://m.facebook.com/x', 'https://www.facebook.com/pages/a-b/123?ref=ts', 'https://fb.com/x')) { if ($p.Fb(1, 1, $f) -ne $f) { return $false } }
    # telefono: solo numeri plausibili, mai un attributo iniettato, mai un numero inventato dalle cifre di un testo
    $telCases = @(@('+39 02 1234567', 'tel:+39021234567'), @('02.1234-567', 'tel:021234567'), @('(02) 12 34 567', 'tel:021234567'), @('0039 02 1234567', 'tel:0039021234567'), @('123456', 'tel:123456'),
                  @('+44 (0)20 7946 0958', ''), @('+39 (0)2 1234567', ''), @('', ''), @('   ', ''), @('123', ''), @('12345', ''), @('0', ''), @('000000', ''), @('+000000', ''), @('javascript:alert(1)', ''), @('02 1234567 int. 3', ''), @('"><script>1</script>', ''), @('+39 02 12+34567', ''),
                  @('dalle 9 alle 18', ''), @('0721 1234 / 0721 5678', ''), @('02 123 / 06 456', ''), @('02 1234567; 06 7654321', ''),
                  @('1234567890123456', ''), @(('0212345678' + [char]10 + 'x'), ''), @('javascript:123456', ''), @('+39 02 1234567 #1', ''), @('+39 02 12%34567', ''),
                  @((([string][char]0x0660) * 8), ''), @((([string][char]0xFF11) * 8), ''), @('++39 02 1234567', ''), @('02 1234567+', ''), @('+', ''), @('()-./ ', ''))
    foreach ($c in $telCases) { if ($p.Tel($c[0]) -ne $c[1]) { return $false } }
    if ($p.Tel($null) -ne '') { return $false }
    # e-mail: solo un indirizzo semplice, senza parametri, elenchi, spazi, percentuali o a capo
    $mailOk = @('info@alfa.example.it', 'first.last+tag@sub.example.co.uk', 'a_b-c@d-e.it')
    foreach ($e in $mailOk) { if ($p.Mail($e) -ne ('mailto:' + $e)) { return $false } }
    $mailBad = @('', '   ', 'a@b', 'x@y.it?subject=hi', 'x@y.it&cc=z@z.it', 'x@y.it, z@z.it', 'x@y.it; z@z.it', 'x y@z.it', ('x@y.it' + [char]13 + [char]10 + 'Bcc:z@z.it'), '<b>@y.it', 'x@y.it"', 'javascript:alert(1)@y.it', ([string][char]0x00E8 + '@y.it'),
                 'x%0d%0aBcc@y.it', 'x%3f@y.it', 'x#y@y.it', 'x@y.it#a', 'x@y.it%0d', 'x@@y.it', '@y.it', 'x@.it', 'x@y..it', '.x@y.it', 'x.@y.it', 'a..b@y.it', (('x' * 70) + '@y.it'))
    foreach ($e in $mailBad) { if ($p.Mail($e) -ne '') { return $false } }
    if ($p.Mail($null) -ne '') { return $false }
    # copyright
    if ($p.Copy(2026, 'Alfa Srl') -ne '&copy; 2026 Alfa Srl') { return $false }
    if ($p.Copy(2026, '') -ne '&copy; 2026' -or $p.Copy(2026, $null) -ne '&copy; 2026' -or $p.Copy(2026, '  ') -ne '&copy; 2026') { return $false }
    if ($p.Copy(2026, 'Alfa & <b>Beta</b>') -ne '&copy; 2026 Alfa &amp; &lt;b&gt;Beta&lt;/b&gt;') { return $false }
    # azienda dell'host e azienda della sessione: se discordano il piede non mostra dati
    if (-not $p.Allowed(1, 0) -or -not $p.Allowed(1, 1) -or $p.Allowed(1, 2) -or $p.Allowed(0, 0) -or $p.Allowed(0, 1) -or $p.Allowed(-1, -1)) { return $false }
    # contatti
    $a = $p.Contacts('Alfa Srl', '+39 02 1234567', 'info@alfa.example.it')
    $b = $p.Contacts('Beta SpA', '', '')
    if (-not ($a.Contains('Alfa Srl') -and $a.Contains('href="tel:+39021234567"') -and $a.Contains('href="mailto:info@alfa.example.it"') -and $a.Contains('href="Contattaci.aspx"'))) { return $false }
    if ($b -match 'tel:|mailto:|Alfa|alfa|1234567|000') { return $false }
    if (-not ($b.Contains('Beta SpA') -and $b.Contains('href="Contattaci.aspx"'))) { return $false }
    $solo = $p.Contacts('', '', '')
    if ($solo -match 'tel:|mailto:|icon-' -or -not $solo.Contains('href="Contattaci.aspx"')) { return $false }
    # nome, telefono ed e-mail non plausibili: testo codificato, nessun attributo iniettato, l'unico collegamento e "Scrivici"
    $x = $p.Contacts('<script>alert(1)</script>', '"><img src=x onerror=1>', 'x@y.it"><script>')
    if ($x -match '<script|<img|onerror=1>|href="tel:|href="mailto:' -or -not $x.Contains('&lt;script&gt;')) { return $false }
    if ([regex]::Matches($x, '<a ').Count -ne 1) { return $false }
    $ext = $p.Contacts('Gamma', '02 1234567 int. 3', 'non-un-indirizzo')
    if ([regex]::Matches($ext, '<a ').Count -ne 1 -or -not $ext.Contains('02 1234567 int. 3') -or -not $ext.Contains('non-un-indirizzo')) { return $false }
    # due aziende sintetiche e una sessione di un'altra azienda: ognuna mostra solo i propri dati, mai quelli dell'altra
    $sep = [string][char]1
    $alfa = @('alfa.png', 'Alfa Srl', '+39 02 1234567', 'info@alfa.example.it', 'https://www.facebook.com/alfa.srl')
    $beta = @('beta.png', 'Beta SpA', '', '', '')
    $d = $p.Data(1, 1, $alfa[1], $alfa[0], $alfa[2], $alfa[3], $alfa[4], 2026)
    if ($d[0] -ne 'alfa.png' -or $d[1] -ne 'Alfa Srl' -or $d[2] -ne 'https://www.facebook.com/alfa.srl' -or -not $d[3].Contains('href="tel:+39021234567"') -or $d[4] -ne '&copy; 2026 Alfa Srl') { return $false }
    $d = $p.Data(2, 2, $beta[1], $beta[0], $beta[2], $beta[3], $beta[4], 2026)
    if ($d[0] -ne 'beta.png' -or $d[1] -ne 'Beta SpA' -or $d[2] -ne '' -or ($d[3] + $d[4]) -match 'Alfa|alfa|tel:|mailto:|1234567' -or $d[4] -ne '&copy; 2026 Beta SpA') { return $false }
    $d = $p.Data(2, 0, $beta[1], $beta[0], $beta[2], $beta[3], $alfa[4], 2026)
    if ($d[1] -ne 'Beta SpA' -or $d[2] -ne '') { return $false }
    foreach ($case in @(@(1, 2), @(2, 1), @(0, 0), @(0, 1), @(-1, 0))) {
        $d = $p.Data($case[0], $case[1], $alfa[1], $alfa[0], $alfa[2], $alfa[3], $alfa[4], 2026)
        if ($d[0] -ne '' -or $d[1] -ne '' -or $d[2] -ne '' -or $d[4] -ne '&copy; 2026' -or ($d[3] -match 'Alfa|alfa|tel:|mailto:|1234567') -or -not $d[3].Contains('href="Contattaci.aspx"')) { return $false }
    }
    # categorie: solo link del catalogo nella forma esatta del provider, codificati, fino al massimo richiesto
    $good = $p.Cats('Alfa|articoli.aspx?st=1;Beta|articoli.aspx?st=2;Gamma|articoli.aspx?st=3', 2)
    if ($good -ne '<li><a class="link" href="articoli.aspx?st=1">Alfa</a></li><li><a class="link" href="articoli.aspx?st=2">Beta</a></li>') { return $false }
    foreach ($evil in @('javascript:alert(1)', 'http://evil.example/', '//evil.example/', '\\evil.example\x', 'articoli.aspx?st=1" onclick="1', '/articoli.aspx?st=1', 'articoli.aspx?st=1%0d%0a', 'articoli.aspx?st=1&x=2', 'articoli.aspx?st=', 'articoli.aspx?st=abc', 'articoli.aspx?st=1#x', 'Articoli.aspx?st=1 ', 'articoli.aspx?st=-1', 'articoli.aspx?st=12345678901', 'articoli.aspx?ct=1', 'x/../articoli.aspx?st=1', ('articoli.aspx?st=1' + [char]10))) { if ($p.Cats(('X|' + $evil), 7) -ne '') { return $false } }
    if ($p.Cats('|articoli.aspx?st=9', 7) -ne '') { return $false }
    if ($p.Cats('A&B <i>|articoli.aspx?st=4', 7) -ne '<li><a class="link" href="articoli.aspx?st=4">A&amp;B &lt;i&gt;</a></li>') { return $false }
    if ($p.Cats($null, 7) -ne '' -or $p.Cats('', 7) -ne '') { return $false }
    # griglia: tre colonne senza il catalogo, quattro con il catalogo
    if ($p.Grid(3) -ne 'ft-link-wrap w-100 tf-grid-layout md-col-2 lg-col-3' -or $p.Grid(4) -ne 'ft-link-wrap w-100 tf-grid-layout md-col-2 lg-col-4') { return $false }
    return (Test-Legal $p)
}

# riga dei dati societari: nome, P.IVA, sede legale (via, CAP, citta, provincia), sede operativa (via, CAP, citta, provincia)
function Lg([string]$n, [string]$v, [string]$ra, [string]$rp, [string]$rc, [string]$rv, [string]$oa, [string]$op, [string]$oc, [string]$ov) { return , [string[]]@($n, $v, $ra, $rp, $rc, $rv, $oa, $op, $oc, $ov) }
function Show-LegalFailure([string]$id, [string]$got) { if ($env:KS_FOOTER_TEST_VERBOSE) { Write-Host ('LEGAL_CASE_FAILED ' + $id + ' got=[' + $got + ']') } }
function Test-Legal($p) {
    $nl = [string][char]10; $cr = [string][char]13; $tab = [string][char]9; $nbsp = [string][char]0x00A0; $ls = [string][char]0x2028; $rlo = [string][char]0x202E; $zw = [string][char]0x200B
    $head = 'Alfa Srl - P.IVA 12345678901'
    $legalCases = @(
        @('c01 due sedi diverse', (Lg 'Alfa Srl' '12345678901' 'Via Roma 1' '20100' 'Milano' 'MI' 'Via Torino 2' '10100' 'Torino' 'TO'), ($head + '<br />Sede legale: Via Roma 1, 20100 Milano (MI)<br />Sede operativa: Via Torino 2, 10100 Torino (TO)')),
        @('c02 stessa sede (maiuscole e spazi diversi)', (Lg 'Alfa Srl' '12345678901' 'Via Roma 1' '20100' 'Milano' 'MI' '  VIA   ROMA 1 ' '20100' 'MILANO' 'mi'), ($head + '<br />Sede legale e operativa: Via Roma 1, 20100 Milano (MI)')),
        @('c03 stessa via, citta diversa', (Lg 'Alfa Srl' '12345678901' 'Via Roma 1' '20100' 'Milano' 'MI' 'Via Roma 1' '20100' 'Monza' 'MI'), ($head + '<br />Sede legale: Via Roma 1, 20100 Milano (MI)<br />Sede operativa: Via Roma 1, 20100 Monza (MI)')),
        @('c03b stessa citta, via diversa', (Lg 'Alfa Srl' '12345678901' 'Via Roma 1' '20100' 'Milano' 'MI' 'Via Roma 2' '20100' 'Milano' 'MI'), ($head + '<br />Sede legale: Via Roma 1, 20100 Milano (MI)<br />Sede operativa: Via Roma 2, 20100 Milano (MI)')),
        @('c04 stessa via e citta, CAP diverso', (Lg 'Alfa Srl' '12345678901' 'Via Roma 1' '20100' 'Milano' 'MI' 'Via Roma 1' '20121' 'Milano' 'MI'), ($head + '<br />Sede legale: Via Roma 1, 20100 Milano (MI)<br />Sede operativa: Via Roma 1, 20121 Milano (MI)')),
        @('c05 stessa sede, provincia diversa', (Lg 'Alfa Srl' '12345678901' 'Via Roma 1' '20100' 'Milano' 'MI' 'Via Roma 1' '20100' 'Milano' 'MB'), ($head + '<br />Sede legale: Via Roma 1, 20100 Milano (MI)<br />Sede operativa: Via Roma 1, 20100 Milano (MB)')),
        @('c06 solo sede operativa', (Lg 'Alfa Srl' '12345678901' '' '' '' '' 'Via Torino 2' '10100' 'Torino' 'TO'), ($head + '<br />Sede: Via Torino 2, 10100 Torino (TO)')),
        @('c07 solo sede legale', (Lg 'Alfa Srl' '12345678901' 'Via Roma 1' '20100' 'Milano' 'MI' '' '' '' ''), ($head + '<br />Sede legale: Via Roma 1, 20100 Milano (MI)')),
        @('c08 solo nome', (Lg 'Alfa Srl' '' '' '' '' '' '' '' '' ''), 'Alfa Srl'),
        @('c09 sola P.IVA', (Lg '' '12345678901' '' '' '' '' '' '' '' ''), 'P.IVA 12345678901'),
        @('c10 niente', (Lg '' '' '' '' '' '' '' '' '' ''), ''),
        @('c11 CAP tutto zeri', (Lg '' '' 'Via Roma 1' '00000' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via Roma 1, Milano (MI)'),
        @('c12 CAP non plausibile N/D', (Lg '' '' 'Via Roma 1' 'N/D' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via Roma 1, Milano (MI)'),
        @('c13 CAP non plausibile trattino', (Lg '' '' 'Via Roma 1' '-' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via Roma 1, Milano (MI)'),
        @('c14 CAP di quattro cifre', (Lg '' '' 'Via Roma 1' '2010' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via Roma 1, Milano (MI)'),
        @('c15 CAP di sei cifre', (Lg '' '' 'Via Roma 1' '201000' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via Roma 1, Milano (MI)'),
        @('c16 CAP con una lettera', (Lg '' '' 'Via Roma 1' '2010a' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via Roma 1, Milano (MI)'),
        @('c17 senza via nessuna sede', (Lg '' '' '' '20100' 'Milano' 'MI' '' '' '' ''), ''),
        @('c18 senza citta nessuna sede', (Lg '' '' 'Via Roma 1' '20100' '' 'MI' '' '' '' ''), ''),
        @('c19 via senza lettere', (Lg '' '' '-' '20100' 'Milano' 'MI' '' '' '' ''), ''),
        @('c20 via di sole cifre', (Lg '' '' '123' '20100' 'Milano' 'MI' '' '' '' ''), ''),
        @('c21 citta senza lettere', (Lg '' '' 'Via Roma 1' '20100' '-' 'MI' '' '' '' ''), ''),
        @('c22 virgola finale nella via', (Lg '' '' 'Via Roma 1,' '20100' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via Roma 1, 20100 Milano (MI)'),
        @('c23 punto finale nella via', (Lg '' '' 'Via Roma 1.' '20100' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via Roma 1, 20100 Milano (MI)'),
        @('c24 punteggiatura e spazi finali', (Lg '' '' 'Via Roma 1 , ;' '20100' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via Roma 1, 20100 Milano (MI)'),
        @('c25 provincia minuscola', (Lg '' '' 'Via Roma 1' '20100' 'Milano' 'mi' '' '' '' ''), 'Sede legale: Via Roma 1, 20100 Milano (MI)'),
        @('c26 provincia per esteso', (Lg '' '' 'Via Roma 1' '20100' 'Milano' 'Milano' '' '' '' ''), 'Sede legale: Via Roma 1, 20100 Milano'),
        @('c27 provincia con cifra', (Lg '' '' 'Via Roma 1' '20100' 'Milano' 'M1' '' '' '' ''), 'Sede legale: Via Roma 1, 20100 Milano'),
        @('c28 provincia vuota', (Lg '' '' 'Via Roma 1' '20100' 'Milano' '' '' '' '' ''), 'Sede legale: Via Roma 1, 20100 Milano'),
        @('c29 a capo, tab, spazio non separabile, separatore di riga', (Lg ('Alfa' + $nl + $cr + $nl + $tab + 'Srl') '12345678901' ('Via' + $nbsp + 'Roma' + $ls + '1') '20100' 'Milano' 'MI' '' '' '' ''), ($head + '<br />Sede legale: Via Roma 1, 20100 Milano (MI)')),
        @('c30 caratteri di formato (bidi, larghezza zero)', (Lg 'Alfa Srl' '12345678901' ('Via' + $rlo + ' Roma 1') '20100' ('Mil' + $zw + 'ano') 'MI' '' '' '' ''), ($head + '<br />Sede legale: Via Roma 1, 20100 Milano (MI)')),
        @('c31 e commerciale codificata una volta sola', (Lg 'Rossi & Figli' '' '' '' '' '' '' '' '' ''), 'Rossi &amp; Figli'),
        @('c32 apostrofo', (Lg '' '' ("Via dell'Orto 3") '20100' 'Milano' 'MI' '' '' '' ''), 'Sede legale: Via dell&#39;Orto 3, 20100 Milano (MI)'),
        @('c33 P.IVA con prefisso e spazi', (Lg 'Alfa Srl' 'it 12345678901' '' '' '' '' '' '' '' ''), 'Alfa Srl - P.IVA IT12345678901'),
        @('c34 P.IVA non valida: il nome resta', (Lg 'Alfa Srl' 'DA COMUNICARE' '' '' '' '' '' '' '' ''), 'Alfa Srl'),
        @('c35 P.IVA tutta a zeri: il nome resta', (Lg 'Alfa Srl' '00000000000' '' '' '' '' '' '' '' ''), 'Alfa Srl'),
        @('c36 P.IVA con prefisso e zeri', (Lg 'Alfa Srl' 'IT00000000000' '' '' '' '' '' '' '' ''), 'Alfa Srl')
    )
    foreach ($c in $legalCases) {
        $got = $p.Legal($c[1])
        if ($got -cne $c[2]) { Show-LegalFailure $c[0] $got; return $false }
    }
    # null: nessun campo e un valore inventato
    $nulls = New-Object 'string[]' 10
    if ($p.LegalNothing() -cne '' -or $p.Legal($nulls) -cne '' -or $p.LegalNothing() -cne '') { return $false }   # il primo giro viene dopo un caso non vuoto: nessuno stato condiviso tra le chiamate
    # l'accento passa (codificato o no) e non diventa un altro carattere
    $acc = $p.Legal((Lg '' '' ('Via Giosu' + [char]0x00E8 + ' Carducci 4') '20100' 'Milano' 'MI' '' '' '' ''))
    if ($acc -cnotmatch ('^Sede legale: Via Giosu(' + [char]0x00E8 + '|&#232;) Carducci 4, 20100 Milano \(MI\)$')) { return $false }
    # nessun testo dell'azienda puo aggiungere markup o righe: tutto codificato, una sola separazione per riga
    $evil = $p.Legal((Lg '<script>alert(1)</script>' '12345678901' 'Via "Roma" & <b>1</b>' '20100' '<i>Mi</i>lano' 'MI' '' '' '' ''))
    if ($evil -cmatch '<script|<b>|<i>|</b>|</i>|onerror|href=' -or -not $evil.Contains('&lt;script&gt;') -or [regex]::Matches($evil, '<br />').Count -ne 1) { return $false }
    $brs = $p.Legal((Lg 'A<br />B' '' 'Via Roma 1' '20100' 'Milano' 'MI' '' '' '' ''))
    if ([regex]::Matches($brs, '<br />').Count -ne 1 -or -not $brs.Contains('&lt;br /&gt;')) { return $false }
    # P.IVA: solo prefisso di due lettere e da 5 a 14 cifre, mai tutta a zeri, mai testo
    $vatOk = @(@(' 123 456 789 01 ', '12345678901'), @('IT 12345678901', 'IT12345678901'), @('it12345678901', 'IT12345678901'), @('123.456.789-01', '12345678901'), @('01234567890', '01234567890'),
               @('12345', '12345'), @('12345678901234', '12345678901234'), @('DE123456789', 'DE123456789'), @(('12345678901' + $nl), '12345678901'), @(('0' * 4 + '1'), '00001'))
    foreach ($v in $vatOk) { if ($p.Vat($v[0]) -cne $v[1]) { Show-LegalFailure ('vat ' + $v[0]) ($p.Vat($v[0])); return $false } }
    $vatBad = @($null, '', '   ', '1234', '123456789012345', '00000000000', 'IT00000000000', '00000', 'ABC12345678', '12345678901x', 'P.IVA 12345678901', 'DA COMUNICARE', 'NON DISPONIBILE', '01234567890 REA', 'AAAAA', 'IT', '+39 12345678901',
                (([string][char]0x0661) * 11), (([string][char]0xFF11) * 11), ([string][char]0x212A + '1234567'), ('1' * 31), '12345678901;', '123/456')
    foreach ($v in $vatBad) { if ($p.Vat($v) -cne '') { Show-LegalFailure ('vatbad ' + $v) ($p.Vat($v)); return $false } }
    # maiuscola indipendente dalla cultura corrente (turco: la i minuscola non diventa I)
    $saved = [Threading.Thread]::CurrentThread.CurrentCulture
    try { [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('tr-TR'); $tr = $p.Vat('ie1234567890') } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $saved }
    if ($tr -cne 'IE1234567890') { return $false }
    # due aziende con marcatori disgiunti: ognuna solo i propri dati; il profilo di un'altra azienda o la sessione di un'altra azienda non mostrano nulla
    $A = Lg 'ZZAalfa Srl' '11111111111' 'ZZAvia Uno 1' '10100' 'ZZAcitta' 'MI' '' '' '' ''
    $B = Lg 'ZZBbeta SpA' '22222222222' 'ZZBvia Due 2' '20200' 'ZZBcitta' 'VE' '' '' '' ''
    $da = $p.DataL(1, 1, 'Alfa', 1, $A)
    if ($da[0] -cne 'ZZAalfa Srl - P.IVA 11111111111<br />Sede legale: ZZAvia Uno 1, 10100 ZZAcitta (MI)' -or -not $da[1].Contains('href="Contattaci.aspx"')) { return $false }
    $db = $p.DataL(2, 0, 'Beta', 2, $B)
    if ($db[0] -cne 'ZZBbeta SpA - P.IVA 22222222222<br />Sede legale: ZZBvia Due 2, 20200 ZZBcitta (VE)') { return $false }
    if ($p.DataL(2, 2, 'Beta', 2, $null)[0] -cne '') { return $false }
    if ($p.DataL(1, 1, 'Alfa', 1, $A)[0] -cne $da[0]) { return $false }
    foreach ($bad in @(@(1, 1, 2, $B), @(2, 2, 1, $A), @(1, 1, 0, $A), @(1, 1, -1, $A), @(0, 0, 0, $A), @(0, 0, 1, $A), @(1, 2, 1, $A), @(2, 1, 2, $B), @(0, 1, 1, $A), @(-1, 0, -1, $A))) {
        $r = $p.DataL($bad[0], $bad[1], 'X', $bad[2], $bad[3])
        if ($r[0] -cne '' -or -not $r[1].Contains('href="Contattaci.aspx"')) { return $false }
    }
    return $true
}
Assert-Source (Test-Behaviour $vb $policy $links) 'F05_THE_REAL_FOOTER_CODE_IS_TRUTHFUL_SAFE_AND_TENANT_ISOLATED'

# --- Oracolo 3: il collegamento del codice (nessun database, nessun ripiego sulla sessione) ------------------------------------------------------
function Test-Glue([string]$vbText) {
    # nessuna connessione, nessuna lettura dell'azienda dalla sola sessione, nessun valore inventato, nessuna richiesta usata per dedurre l'azienda
    foreach ($bad in @('MySqlConnection', 'MySqlCommand', 'ConfigurationManager', 'Session("AziendaNome")', 'Session("AziendaCopyright")', 'info@', 'KeepStore.Site.SupportEmail', 'SELECT ', 'Request.Url', 'Request.Headers', 'CodiceFiscale', 'CognomeNome', 'TaxCode')) {
        if ($vbText.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { return $false }
    }
    if ($vbText -match '(?i)\b(Visa|Mastercard|Maestro|Discover)\b|Pagamenti accettati|\+39 0|Notebook|Subscribe|10% Off') { return $false }
    # nessun marchio di pagamento nel TESTO mostrato: dal task KS-B02F il codice puo nominare PayPal come identificatore o commento (il carrello e la sua politica), mai dentro una stringa
    if ($vbText -match '(?i)"[^"\r\n]*\bPayPal\b[^"\r\n]*"') { return $false }
    # sessione: si leggono soltanto l'azienda (per il confronto con l'host) e il link di Facebook scritto con essa
    $sessionNames = @([regex]::Matches($vbText, 'Session\("([^"]+)"\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if (($sessionNames -join '|') -ne 'AziendaID|facebookLink') { return $false }
    # la lista dei settori e quella in cache, condivisa tra le aziende del database: qui si legge soltanto (nessun metodo che modifica, su qualunque variabile)
    if ($vbText -match '\.(Remove|RemoveAll|RemoveAt|RemoveRange|Sort|Clear|Insert|InsertRange|AddRange|Reverse)\(') { return $false }
    # la colonna del catalogo e il blocco social non restano vuoti, la griglia segue il numero di colonne
    foreach ($line in @('phFooterCategories.Visible = html.Length > 0', 'ulFooterColumns.Attributes("class") = FooterGridClass(If(html.Length > 0, 4, 3))', 'liFooterFacebook.Visible = show', 'ulFooterSocial.Visible = show', 'Dim show As Boolean = data.FacebookUrl.Length > 0')) {
        if ($vbText.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if ($vbText -notmatch 'CatalogMenuProvider\.LoadCatalogMenuCached\(\)') { return $false }
    # nessun ViewState: il piede si ricostruisce a ogni richiesta
    if ($vbText -notmatch '(?s)Handles Me\.Init\s+Me\.EnableViewState = False') { return $false }
    # l'azienda e quella dell'host (identita in cache), mai quella della sola sessione
    if ($vbText -notmatch '(?s)Private Function ResolveFooterTenant\(\) As StorefrontSeoTenantIdentity\s+Try\s+Return StorefrontSeoTenantContext\.Resolve\(HttpContext\.Current\)') { return $false }
    foreach ($line in @('hostCompanyId = tenant.CompanyId', 'companyName = tenant.CompanyName', 'logoFileName = tenant.LogoFileName', 'phone = tenant.SupportPhone', 'email = tenant.SupportEmail', 'legalProfile = tenant.LegalProfile')) {
        if ($vbText.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if ($vbText -notmatch 'Dim data As FooterData = BuildFooterData\(hostCompanyId, SessionCompanyId\(\), companyName, logoFileName, phone, email, facebookRaw, legalProfile, payments, payPalLive, DateTime\.Now\.Year\)') { return $false }
    # tutto cio che il piede mostra dell'azienda viene da BuildFooterData
    foreach ($line in @('litFooterContacts.Text = data.ContactsHtml', 'litFooterCopyright.Text = data.CopyrightHtml', 'BindFooterLogo(data)', 'BindFooterSocial(data)', 'BuildLogoAssetUrlFromFileName(data.LogoFileName)', 'lnkFooterFacebook.HRef = data.FacebookUrl',
                  'BindFooterLegal(data)', 'phFooterLegal.Visible = data.LegalHtml.Length > 0', 'litFooterLegal.Text = data.LegalHtml')) {
        if ($vbText.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    # il collegamento Facebook ha un nome accessibile (icona senza testo)
    return ($vbText -match 'lnkFooterFacebook\.Attributes\("aria-label"\) = "Facebook"')
}
Assert-Source (Test-Glue $vb) 'F06_THE_FOOTER_READS_ONLY_THE_VERIFIED_HOST_IDENTITY_NO_DATABASE_NO_SESSION_FALLBACK'
Assert-Source ($ascx -notmatch '(?i)onsus' -and $vb -notmatch '(?i)onsus') 'F07_NO_TEMPLATE_NAME_IN_THE_FOOTER_SOURCES'
Assert-Source ($vb -notmatch '[^\x00-\x7F]') 'F08_FOOTER_CODE_BEHIND_IS_ASCII_ONLY'

# --- Oracolo 6: la policy (profilo legale, mappatura colonne, aggancio all'identita) compilata ed eseguita ---------------------------------------------
function Compile-Policy([string]$policyText) {
    $code = @"
Imports System
Imports System.Collections.Generic
Public Class PolicyProbe
    Public Function Cols(ByVal id As Integer) As String
        Dim p As StorefrontCompanyLegalProfile = StorefrontCanonicalHostPolicy.CreateLegalProfile(id, Function(name As String) "<" & name & ">")
        If p Is Nothing Then Return "NOTHING"
        Return p.CompanyId.ToString() & "|" & p.LegalName & "|" & p.VatNumber & "|" & p.RegisteredAddress & "|" & p.RegisteredPostalCode & "|" & p.RegisteredCity & "|" & p.RegisteredProvince & "|" & p.OperationalAddress & "|" & p.OperationalPostalCode & "|" & p.OperationalCity & "|" & p.OperationalProvince
    End Function
    Public Function ColsNullFunction(ByVal id As Integer) As String
        Dim p As StorefrontCompanyLegalProfile = StorefrontCanonicalHostPolicy.CreateLegalProfile(id, Nothing)
        If p Is Nothing Then Return "NOTHING"
        Return "PROFILE"
    End Function
    Public Function ColsNullValues(ByVal id As Integer) As String
        Dim p As StorefrontCompanyLegalProfile = StorefrontCanonicalHostPolicy.CreateLegalProfile(id, Function(name As String) CType(Nothing, String))
        If p Is Nothing Then Return "NOTHING"
        Return p.LegalName & "|" & p.VatNumber & "|" & p.RegisteredCity & "|" & p.OperationalProvince
    End Function
    Public Function Trimmed() As String
        Dim p As New StorefrontCompanyLegalProfile(7, "  A  ", " B ", " C", "D ", " E ", "F", "G", "H", "I", " J ")
        Return p.LegalName & "|" & p.VatNumber & "|" & p.RegisteredAddress & "|" & p.RegisteredPostalCode & "|" & p.RegisteredCity & "|" & p.RegisteredProvince & "|" & p.OperationalAddress & "|" & p.OperationalPostalCode & "|" & p.OperationalCity & "|" & p.OperationalProvince
    End Function
    Private Shared Function Idents(ByVal spec As String) As List(Of StorefrontSeoTenantIdentity)
        Dim list As New List(Of StorefrontSeoTenantIdentity)()
        If spec Is Nothing Then Return list
        For Each part As String In spec.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
            list.Add(StorefrontCanonicalHostPolicy.CreateTenant(Integer.Parse(part), "T" & part, "", "https://t" & list.Count.ToString() & ".example.it", "", "", 1))
        Next
        Return list
    End Function
    Private Shared Function Rows(ByVal spec As String) As List(Of StorefrontCompanyLegalProfile)
        If spec Is Nothing Then Return Nothing
        Dim list As New List(Of StorefrontCompanyLegalProfile)()
        For Each part As String In spec.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
            list.Add(New StorefrontCompanyLegalProfile(Integer.Parse(part), "P" & part, "", "", "", "", "", "", "", "", ""))
        Next
        Return list
    End Function
    Private Shared Function Show(ByVal list As List(Of StorefrontSeoTenantIdentity)) As String
        Dim sb As New System.Text.StringBuilder()
        For Each t As StorefrontSeoTenantIdentity In list
            sb.Append(t.CompanyId.ToString()).Append("=").Append(If(t.LegalProfile Is Nothing, "-", t.LegalProfile.LegalName)).Append(";")
        Next
        Return sb.ToString()
    End Function
    Public Function Apply(ByVal identityIds As String, ByVal profileIds As String) As String
        Dim list As List(Of StorefrontSeoTenantIdentity) = Idents(identityIds)
        StorefrontCanonicalHostPolicy.ApplyLegalProfiles(list, Rows(profileIds))
        Return Show(list)
    End Function
    Public Function ApplyTwice(ByVal identityIds As String, ByVal first As String, ByVal second As String) As String
        Dim list As List(Of StorefrontSeoTenantIdentity) = Idents(identityIds)
        StorefrontCanonicalHostPolicy.ApplyLegalProfiles(list, Rows(first))
        StorefrontCanonicalHostPolicy.ApplyLegalProfiles(list, Rows(second))
        Return Show(list)
    End Function
    Public Function ApplyNothingList() As String
        StorefrontCanonicalHostPolicy.ApplyLegalProfiles(Nothing, Rows("1"))
        Return "OK"
    End Function
End Class
"@
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($policyText, $code))
    if ($c.Errors.HasErrors) { throw ('POLICY_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return $c.CompiledAssembly
}
function Test-PolicyBehaviour([string]$policyText) {
    $asm = Compile-Policy $policyText
    $o = [Activator]::CreateInstance($asm.GetType('PolicyProbe', $true))
    # mappatura: ogni proprieta riceve la colonna giusta (nessuno scambio tra sede legale e operativa, nessun campo fuori elenco)
    if ($o.Cols(5) -cne '5|<RagioneSociale>|<Piva>|<SL_Indirizzo>|<SL_CAP>|<SL_Citta>|<SL_Provincia>|<Indirizzo>|<Cap>|<Citta>|<Provincia>') { return $false }
    if ($o.Cols(0) -cne 'NOTHING' -or $o.Cols(-3) -cne 'NOTHING' -or $o.ColsNullFunction(5) -cne 'NOTHING') { return $false }
    if ($o.ColsNullValues(5) -cne '|||') { return $false }
    if ($o.Trimmed() -cne 'A|B|C|D|E|F|G|H|I|J') { return $false }
    # il profilo e immutabile: nessuna proprieta con scrittura pubblica
    $type = $asm.GetType('StorefrontCompanyLegalProfile', $true)
    foreach ($prop in $type.GetProperties()) { if ($prop.CanWrite) { return $false } }
    if ($type.GetProperties().Count -ne 11) { return $false }
    # aggancio: per Id intero, mai per posizione; solo se l'Id compare UNA volta tra le righe e UNA volta tra le identita; chiave di aziende = (id, IvaTipo)
    if ($o.Apply('1,2,3', '2,1,99') -cne '1=P1;2=P2;3=-;') { return $false }
    if ($o.Apply('3,2,1', '1,2,3') -cne '3=P3;2=P2;1=P1;') { return $false }
    if ($o.Apply('1,2', '') -cne '1=-;2=-;' -or $o.Apply('1,2', $null) -cne '1=-;2=-;') { return $false }
    if ($o.Apply('1,2', '1,1,2') -cne '1=-;2=P2;') { return $false }
    if ($o.Apply('1,1,2', '1,2') -cne '1=-;1=-;2=P2;') { return $false }
    if ($o.Apply('0,2', '0,2') -cne '0=-;2=P2;' -or $o.Apply('2', '-2,2') -cne '2=P2;') { return $false }
    if ($o.Apply('', '1') -cne '') { return $false }
    if ($o.Apply('1,2,3', '3') -cne '1=-;2=-;3=P3;') { return $false }
    if ($o.ApplyTwice('1,2', '1,2', '') -cne '1=-;2=-;' -or $o.ApplyTwice('1,2', '1,2', '2') -cne '1=-;2=P2;') { return $false }
    if ($o.ApplyNothingList() -cne 'OK') { return $false }
    return $true
}
Assert-Source (Test-PolicyBehaviour $policy) 'F10_THE_LEGAL_PROFILE_IS_MAPPED_PER_COLUMN_AND_ATTACHED_ONLY_BY_A_UNIQUE_COMPANY_ID'

# --- Oracolo 7: il caricatore (testo): SELECT principale invariato, secondo SELECT facoltativo, dopo il primo reader e prima della cache --------------------
function Test-Context([string]$c, [string]$policyText) {
    $main = 'Const sql As String = "SELECT Id, Nome, Descrizione, url1, url2, LogoWeb, ListinoDefault, telefono, email FROM aziende ORDER BY Id"'
    $legalFull = 'SELECT Id, RagioneSociale, Indirizzo, Cap, Citta, Provincia, Piva, SL_Indirizzo, SL_CAP, SL_Citta, SL_Provincia FROM aziende ORDER BY Id'
    $legalReduced = 'SELECT Id, RagioneSociale, Indirizzo, Cap, Citta, Provincia, Piva FROM aziende ORDER BY Id'
    $callFull = 'ReadLegalProfiles(connection, "' + $legalFull + '")'
    $callReduced = 'If profiles Is Nothing Then profiles = ReadLegalProfiles(connection, "' + $legalReduced + '")'
    if (-not $c.Contains($main) -or -not $c.Contains($callFull) -or -not $c.Contains($callReduced)) { return $false }
    # tre per le letture esistenti (identita, dati societari completo e ridotto) piu quattro per i metodi di pagamento (la SELECT e tre sottoquery annidate: DISTINCT bancario, conteggio righe, aggregato): la loro regola e provata da Test-FooterPayments.ps1
    if ([regex]::Matches($c, 'SELECT ').Count -ne 7) { return $false }
    if ($c -match '(?is)CodiceFiscale|CognomeNome|For Each candidate|Exit For|Session\(') { return $false }
    # la lettura dei dati societari parte quando il primo reader e gia chiuso, dentro la stessa connessione e PRIMA di inserire l'elenco in cache
    if ($c -cnotmatch '(?s)End While\s+End Using\s+End Using\s+AttachLegalProfiles\(connection, result\)\s+AttachPaymentMethods\(connection, result\)\s+End Using\s+HttpRuntime\.Cache\.Insert') { return $false }
    # completo per primo; il ridotto (senza SL_*) SOLO se il completo ha fallito; l'aggancio dopo entrambe le letture
    $m = [regex]::Match($c, '(?ms)^    Private Shared Sub AttachLegalProfiles\(.*?^    End Sub')
    if (-not $m.Success) { return $false }
    $a = $m.Value
    $iFull = $a.IndexOf('Dim profiles As List(Of StorefrontCompanyLegalProfile) = ' + $callFull); $iReduced = $a.IndexOf($callReduced); $iApply = $a.IndexOf('StorefrontCanonicalHostPolicy.ApplyLegalProfiles(identities, profiles)')
    if ($iFull -lt 0 -or $iReduced -lt $iFull -or $iApply -lt $iReduced) { return $false }
    if ($legalReduced -cmatch 'SL_') { return $false }
    # la lettura: nessun profilo parziale (lista intera restituita solo dopo la lettura, Nothing su errore), nessun aggancio qui dentro, tempo massimo breve
    $r = [regex]::Match($c, '(?ms)^    Private Shared Function ReadLegalProfiles\(.*?^    End Function')
    if (-not $r.Success) { return $false }
    $b = $r.Value
    $iTry = $b.IndexOf("        Try`n"); $iWhile = $b.IndexOf('While reader.Read()'); $iEndWhile = $b.IndexOf('End While'); $iReturn = $b.IndexOf("            Return profiles`n"); $iCatch = $b.IndexOf("        Catch`n")
    if ($iTry -lt 0 -or $iWhile -lt $iTry -or $iEndWhile -lt $iWhile -or $iReturn -lt $iEndWhile -or $iCatch -lt $iReturn) { return $false }
    if ($b.Contains('ApplyLegalProfiles')) { return $false }
    foreach ($line in @('command.CommandTimeout = 5', 'Dim profiles As New List(Of StorefrontCompanyLegalProfile)()', 'Dim companyId As Integer = SafeReaderInteger(reader, "Id")',
                        'StorefrontCanonicalHostPolicy.CreateLegalProfile(companyId, Function(name As String) SafeReaderString(reader, name))', 'If profile IsNot Nothing Then profiles.Add(profile)')) {
        if ($b.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if ($b -cnotmatch '(?s)Catch\s+Return Nothing\s+End Try') { return $false }
    # ogni colonna che la policy legge sta nel SELECT completo; le non-SL anche nel ridotto
    # solo le colonne del profilo legale: CreatePaymentMethod legge altre colonne (di pagamentitipo), provate da Test-FooterPayments.ps1
    $legalFn = [regex]::Match($policyText, '(?ms)Public Shared Function CreateLegalProfile\(.*?^    End Function').Value
    $cols = @([regex]::Matches($legalFn, 'column\("([A-Za-z_]+)"\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if ($cols.Count -ne 10) { return $false }
    foreach ($col in $cols) {
        if ($legalFull -cnotmatch ('[ ,]' + $col + '[ ,]')) { return $false }
        if ($col -cnotmatch '^SL_' -and $legalReduced -cnotmatch ('[ ,]' + $col + '[ ,]')) { return $false }
    }
    return $true
}
Assert-Source (Test-Context $ctx $policy) 'F11_THE_LEGAL_READ_TRIES_THE_FULL_SELECT_THEN_ONE_REDUCED_SELECT_AFTER_THE_FIRST_READER_AND_BEFORE_THE_CACHE_AND_THE_MAIN_SELECT_IS_UNCHANGED'

# --- Mutazioni (copie in memoria): ognuna deve far fallire almeno un controllo ------------------------------------------------------------------
function Test-AllMarkup([string]$text) { return ((Test-NoFabricatedContent $text) -and (Test-StaticLinksExist $text) -and (Test-RequiredLinks $text) -and (Test-DynamicHooks $text) -and (Test-LegalMarkup $text)) }
function Test-AllCode([string]$text) { return ((Test-Behaviour $text $policy $links) -and (Test-Glue $text)) }
function Test-AllPolicy([string]$text) { return ((Test-PolicyBehaviour $text) -and (Test-Behaviour $vb $text) -and (Test-Context $ctx $text)) }
function Test-AllContext([string]$text) { return (Test-Context $text $policy) }

$m = Mutate-Text $ascx '<div class="ft-body-bottom">' '<p>10% Off Your First Order</p><div class="ft-body-bottom">' 'M01'
Assert-Detected (Test-AllMarkup $m) 'M01_THE_FABRICATED_PROMOTION_COMES_BACK'
$m = Mutate-Text $ascx 'href="faq.aspx">Domande frequenti' 'href="faq-inesistente.aspx">Domande frequenti' 'M02'
Assert-Detected (Test-AllMarkup $m) 'M02_LINK_TO_A_PAGE_THAT_DOES_NOT_EXIST'
$m = Mutate-Text $ascx 'condizioni-vendita.aspx#diritto-recesso' 'condizioni-vendita.aspx#sezione-inesistente' 'M03'
Assert-Detected (Test-AllMarkup $m) 'M03_ANCHOR_THAT_DOES_NOT_EXIST'
$m = Mutate-Text $ascx 'href="condizioni-vendita.aspx">Condizioni di vendita' 'href="Contattaci.aspx">Condizioni di vendita' 'M04'
Assert-Detected (Test-AllMarkup $m) 'M04_TERMS_LINK_POINTS_TO_THE_CONTACT_PAGE_AGAIN'
$m = Mutate-Text $ascx 'href="privacy.aspx">Privacy' 'href="#">Privacy' 'M05'
Assert-Detected (Test-AllMarkup $m) 'M05_PLACEHOLDER_HASH_LINK'
$m = Mutate-Text $ascx '<ul id="ulFooterSocial" runat="server" class="social-list">' '<ul id="ulFooterSocial" runat="server" class="social-list"><li><a href="https://x.com/"><i class="icon-x"></i></a></li>' 'M06'
Assert-Detected (Test-AllMarkup $m) 'M06_GENERIC_SOCIAL_LINK_COMES_BACK'
$m = Mutate-Text $ascx '<li class="footer-col-block type-sp-2">' '<li><a class="link" href="articoli.aspx">Notebook e computer</a></li><li class="footer-col-block type-sp-2">' 'M07'
Assert-Detected (Test-AllMarkup $m) 'M07_HARDCODED_ELECTRONICS_CATEGORY_COMES_BACK'
$m = Mutate-Text $ascx '<ul id="ulFooterColumns" runat="server" class=' '<ul id="ulFooterColumns" class=' 'M08'
Assert-Detected (Test-AllMarkup $m) 'M08_COLUMNS_ARE_NOT_A_SERVER_CONTROL_ANY_MORE'
$m = Mutate-Text $ascx '<div class="ft-body-bottom">' '<div class="ft-body-center bg-gray"><input id="ksNewsletterEmail" /></div><div class="ft-body-bottom">' 'M09'
Assert-Detected (Test-AllMarkup $m) 'M09_NEWSLETTER_BAND_COMES_BACK'
$m = Mutate-Text $ascx '<div class="ft-logo">' '<div class="ft-logo"><div class="method-payment"><p>Pagamenti accettati:</p></div>' 'M10b'
Assert-Detected (Test-AllMarkup $m) 'M10_FIXED_PAYMENT_CLAIM_COMES_BACK'
$m = Mutate-Text $ascx '<li><a class="link" href="privacy.aspx">Privacy</a></li>' '' 'M11b'
Assert-Detected (Test-AllMarkup $m) 'M11_PRIVACY_LINK_IS_REMOVED'
$m = Mutate-Text $ascx '<footer class="tf-footer">' '<footer class="site-ft">' 'M12b'
Assert-Detected (Test-AllMarkup $m) 'M12_FOOTER_LOSES_THE_CLASS_THE_ORDER_PRINT_PAGE_HIDES'
$m = Mutate-Text $ascx '<asp:Literal ID="litFooterContacts" runat="server" EnableViewState="False" />' '<asp:Literal ID="litFooterContacts" runat="server" />' 'M13b'
Assert-Detected (Test-AllMarkup $m) 'M13_CONTACTS_LITERAL_GETS_VIEWSTATE_BACK'
$m = Mutate-Text $ascx '<li><a class="link" href="faq.aspx">Domande frequenti</a></li>' '<li><a class="link" href="faq.aspx">Domande frequenti</a></li><li><a id="lnkSupportEmail" runat="server" href="faq.aspx">x</a></li>' 'M14b'
Assert-Detected (Test-AllMarkup $m) 'M14_MASTER_OVERWRITABLE_SUPPORT_EMAIL_CONTROL_COMES_BACK'

# codice: ogni mutazione toglie una difesa e almeno un controllo del comportamento o del collegamento deve accorgersene
$m = Mutate-Text $vb '        If tenantCompanyId <= 0 Then Return False
        If sessionCompanyId > 0' '        If sessionCompanyId > 0' 'M20'
Assert-Detected (Test-AllCode $m) 'M20_HOST_WITHOUT_A_COMPANY_IS_ALLOWED'
$m = Mutate-Text $vb '        If sessionCompanyId > 0 AndAlso sessionCompanyId <> tenantCompanyId Then Return False
        Return True' '        Return True' 'M21'
Assert-Detected (Test-AllCode $m) 'M21_SESSION_OF_ANOTHER_COMPANY_IS_ACCEPTED'
$m = Mutate-Text $vb '        If IsFooterTenantAllowed(hostCompanyId, sessionCompanyId) Then' '        If hostCompanyId > 0 Then' 'M22'
Assert-Detected (Test-AllCode $m) 'M22_FOOTER_DATA_IGNORES_THE_SESSION_COMPANY'
$m = Mutate-Text $vb 'If tenantCompanyId <= 0 OrElse sessionCompanyId <> tenantCompanyId Then Return String.Empty' 'If tenantCompanyId <= 0 Then Return String.Empty' 'M23'
Assert-Detected (Test-AllCode $m) 'M23_FACEBOOK_LINK_OF_ANOTHER_COMPANY_IS_SHOWN'
$m = Mutate-Text $vb 'If host = "facebook.com" OrElse' 'If True OrElse host = "facebook.com" OrElse' 'M24'
Assert-Detected (Test-AllCode $m) 'M24_ANY_HTTPS_HOST_IS_ACCEPTED_AS_FACEBOOK'
# Le mutazioni M25-M32 e M54 (regole del validatore di telefono ed e-mail) sono passate in Tools/Test-ContactLinks.ps1 (V*), insieme al validatore condiviso.
$m = Mutate-Text $vb 'sb.Append("<li><span class=""product-title"">").Append(HttpUtility.HtmlEncode(name)).Append("</span></li>")' 'sb.Append("<li><span class=""product-title"">").Append(name).Append("</span></li>")' 'M33'
Assert-Detected (Test-AllCode $m) 'M33_COMPANY_NAME_IS_NOT_ENCODED'
$m = Mutate-Text $vb '            If telHref.Length > 0 Then' '            If True Then' 'M34'
Assert-Detected (Test-AllCode $m) 'M34_PHONE_LINK_IS_BUILT_EVEN_WHEN_THE_NUMBER_IS_NOT_VALID'
$m = Mutate-Text $vb 'st=[0-9]{1,9}\z"' 'st=[0-9]{1,9}$"' 'M35'
Assert-Detected (Test-AllCode $m) 'M35_CATEGORY_PATTERN_ACCEPTS_A_TRAILING_NEWLINE'
$m = Mutate-Text $vb '            If count >= maxItems Then Exit For
' '' 'M36'
Assert-Detected (Test-AllCode $m) 'M36_CATEGORY_LIMIT_IS_IGNORED'
$m = Mutate-Text $vb 'If(visibleColumns >= 4, "4", "3")' '"4"' 'M37'
Assert-Detected (Test-AllCode $m) 'M37_GRID_ALWAYS_HAS_FOUR_COLUMNS'
$m = Mutate-Text $vb 'If name.Length > 0 Then text &= " " & HttpUtility.HtmlEncode(name)' 'If name.Length > 0 Then text &= " " & name' 'M38'
Assert-Detected (Test-AllCode $m) 'M38_COPYRIGHT_NAME_IS_NOT_ENCODED'
$m = Mutate-Text $vb '        sb.Append("<li><a class=""link"" href=""Contattaci.aspx"">Scrivici</a></li>")
' '' 'M39'
Assert-Detected (Test-AllCode $m) 'M39_THE_WRITE_TO_US_LINK_IS_MISSING'
$m = Mutate-Text $vb 'hostCompanyId = tenant.CompanyId' 'hostCompanyId = SessionCompanyId()' 'M40'
Assert-Detected (Test-AllCode $m) 'M40_COMPANY_IS_TAKEN_FROM_THE_SESSION_INSTEAD_OF_THE_HOST'
$m = Mutate-Text $vb '        Dim html As String = String.Empty
        Try' '        Dim connectionText As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        Dim html As String = String.Empty
        Try' 'M41'
Assert-Detected (Test-AllCode $m) 'M41_THE_FOOTER_READS_THE_DATABASE_AGAIN'
$m = Mutate-Text $vb 'BuildFooterData(hostCompanyId, SessionCompanyId(), companyName' 'BuildFooterData(hostCompanyId, hostCompanyId, companyName' 'M42'
Assert-Detected (Test-AllCode $m) 'M42_THE_SESSION_COMPANY_IS_REPLACED_BY_THE_HOST_COMPANY'
$m = Mutate-Text $vb 'lnkFooterFacebook.Attributes("aria-label") = "Facebook"' 'lnkFooterFacebook.Attributes("title") = "Facebook"' 'M43'
Assert-Detected (Test-AllCode $m) 'M43_ICON_LINK_HAS_NO_ACCESSIBLE_NAME'
$m = Mutate-Text $vb '        Me.EnableViewState = False' '        Me.EnableViewState = True' 'M44'
Assert-Detected (Test-AllCode $m) 'M44_THE_FOOTER_KEEPS_ITS_VIEWSTATE'
$m = Mutate-Text $vb '                For Each sector As CatalogMenuSector In sectors' '                sectors.Sort()
                For Each sector As CatalogMenuSector In sectors' 'M45'
Assert-Detected (Test-AllCode $m) 'M45_THE_SHARED_CACHED_SECTOR_LIST_IS_MODIFIED'
$m = Mutate-Text $vb '        Dim html As String = String.Empty
        Try' '        Dim html As String = "info@" & Request.Url.Host
        Try' 'M46'
Assert-Detected (Test-AllCode $m) 'M46_INVENTED_INFO_ADDRESS_FROM_THE_HOST_COMES_BACK'

$m = Mutate-Text $vb '        liFooterFacebook.Visible = show
' '' 'M47'
Assert-Detected (Test-AllCode $m) 'M47_FACEBOOK_ITEM_VISIBILITY_IS_NOT_SET'
$m = Mutate-Text $vb '        If ulFooterSocial IsNot Nothing Then ulFooterSocial.Visible = show
' '' 'M48'
Assert-Detected (Test-AllCode $m) 'M48_EMPTY_SOCIAL_LIST_STAYS_IN_THE_PAGE'
$m = Mutate-Text $vb '            phFooterCategories.Visible = html.Length > 0
' '' 'M49'
Assert-Detected (Test-AllCode $m) 'M49_EMPTY_CATALOG_COLUMN_STAYS_IN_THE_PAGE'
$m = Mutate-Text $vb 'FooterGridClass(If(html.Length > 0, 4, 3))' 'FooterGridClass(4)' 'M50'
Assert-Detected (Test-AllCode $m) 'M50_GRID_IGNORES_THE_NUMBER_OF_VISIBLE_COLUMNS'
$m = Mutate-Text $vb '        Dim html As String = String.Empty
        Try' '        Dim extra As String = Convert.ToString(Session("Telefono"))
        Dim html As String = String.Empty
        Try' 'M51'
Assert-Detected (Test-AllCode $m) 'M51_AN_UNLISTED_SESSION_VALUE_IS_READ'
$m = Mutate-Text $ascx '<li><a class="link" href="privacy.aspx">Privacy</a></li>' '<li><a class="link" href="privacy.aspx">Privacy</a></li><li><a class="link" href="about.aspx">Chi siamo</a></li>' 'M52'
Assert-Detected (Test-AllMarkup $m) 'M52_AN_UNREVIEWED_PAGE_IS_LINKED'
$m = Mutate-Text $vb 'OrElse host = "fb.com" OrElse' 'OrElse host.EndsWith(".facebook.com", StringComparison.Ordinal) OrElse host = "fb.com" OrElse' 'M53'
Assert-Detected (Test-AllCode $m) 'M53_FACEBOOK_REDIRECTOR_SUBDOMAIN_IS_ACCEPTED'
$m = Mutate-Text $vb '        Dim html As String = String.Empty
        Try' '        Dim html As String = String.Empty
        Visa.ToString()
        Try' 'M55'
Assert-Detected (Test-AllCode $m) 'M55_A_FIXED_PAYMENT_NAME_COMES_BACK_IN_THE_CODE'

# --- dati societari: markup ---------------------------------------------------------------------------------------------------------------------
$m = Mutate-Text $ascx '<asp:Literal ID="litFooterLegal" runat="server" EnableViewState="False" />' '<asp:Literal ID="litFooterLegal" runat="server" />' 'M90'
Assert-Detected (Test-AllMarkup $m) 'M90_LEGAL_LITERAL_GETS_VIEWSTATE_BACK'
$m = Mutate-Text $ascx 'class="caption text-center text-break ft-legal"' 'class="caption text-center ft-legal"' 'M91'
Assert-Detected (Test-AllMarkup $m) 'M91_A_LONG_COMPANY_NAME_CANNOT_WRAP_ANY_MORE'
$m = Mutate-Text $ascx '<asp:PlaceHolder ID="phFooterLegal" runat="server" Visible="false">' '<asp:PlaceHolder ID="phFooterLegal" runat="server">' 'M92'
Assert-Detected (Test-AllMarkup $m) 'M92_AN_EMPTY_LEGAL_PARAGRAPH_STAYS_IN_THE_PAGE'
$m = Mutate-Text $ascx '<div class="ft-body-bottom">' '<p>P.IVA 00000000000</p><div class="ft-body-bottom">' 'M93'
Assert-Detected (Test-AllMarkup $m) 'M93_A_FIXED_VAT_NUMBER_IS_WRITTEN_IN_THE_MARKUP'
$m = Mutate-Text $ascx '<p class="caption text-center text-break ft-legal">' '<p class="nocopy caption text-center text-break ft-legal">' 'M94'
Assert-Detected (Test-AllMarkup $m) 'M94_THE_LEGAL_PARAGRAPH_GETS_THE_NO_COPY_CLASS'
$m = Mutate-Text $ascx '<asp:PlaceHolder ID="phFooterLegal" runat="server" Visible="false">
                        <p class="caption text-center text-break ft-legal"><asp:Literal ID="litFooterLegal" runat="server" EnableViewState="False" /></p>
                    </asp:PlaceHolder>
                    <p class="nocopy caption text-center"><asp:Literal ID="litFooterCopyright" runat="server" EnableViewState="False" /></p>' '<p class="nocopy caption text-center"><asp:Literal ID="litFooterCopyright" runat="server" EnableViewState="False" /></p>
                    <asp:PlaceHolder ID="phFooterLegal" runat="server" Visible="false">
                        <p class="caption text-center text-break ft-legal"><asp:Literal ID="litFooterLegal" runat="server" EnableViewState="False" /></p>
                    </asp:PlaceHolder>' 'M95'
Assert-Detected (Test-AllMarkup $m) 'M95_THE_LEGAL_PARAGRAPH_COMES_AFTER_THE_COPYRIGHT'

# --- dati societari: codice del piede -----------------------------------------------------------------------------------------------------------
$m = Mutate-Text $vb 'If legal IsNot Nothing AndAlso legal.CompanyId = hostCompanyId Then data.LegalHtml' 'If legal IsNot Nothing Then data.LegalHtml' 'M60'
Assert-Detected (Test-AllCode $m) 'M60_THE_PROFILE_OF_ANOTHER_COMPANY_IS_SHOWN_ON_THE_HOST'
$m = Mutate-Text $vb '        Dim data As New FooterData()
        If IsFooterTenantAllowed(hostCompanyId, sessionCompanyId) Then' '        Dim data As New FooterData()
        If legal IsNot Nothing AndAlso legal.CompanyId = hostCompanyId Then data.LegalHtml = BuildFooterLegalHtml(legal)
        If IsFooterTenantAllowed(hostCompanyId, sessionCompanyId) Then' 'M61'
Assert-Detected (Test-AllCode $m) 'M61_LEGAL_DATA_IS_BUILT_OUTSIDE_THE_TENANT_GATE'
$m = Mutate-Text $vb 'Dim head As String = HttpUtility.HtmlEncode(CleanLegalText(legal.LegalName))' 'Dim head As String = CleanLegalText(legal.LegalName)' 'M62'
Assert-Detected (Test-AllCode $m) 'M62_THE_LEGAL_NAME_IS_NOT_ENCODED'
$m = Mutate-Text $vb '"Sede legale: " & HttpUtility.HtmlEncode(registered)' '"Sede legale: " & registered' 'M63'
Assert-Detected (Test-AllCode $m) 'M63_THE_REGISTERED_ADDRESS_IS_NOT_ENCODED'
$m = Mutate-Text $vb 'If Not nonZeroDigit OrElse Not VatPattern.IsMatch(vat) Then Return String.Empty' 'If Not VatPattern.IsMatch(vat) Then Return String.Empty' 'M64'
Assert-Detected (Test-AllCode $m) 'M64_AN_ALL_ZERO_VAT_NUMBER_IS_SHOWN'
$m = Mutate-Text $vb '^[A-Z]{0,2}[0-9]{5,14}\z' '^[A-Z]{0,2}[0-9]{1,14}\z' 'M65'
Assert-Detected (Test-AllCode $m) 'M65_A_SHORT_VAT_NUMBER_IS_SHOWN'
$m = Mutate-Text $vb '^[A-Z]{0,2}[0-9]{5,14}\z' '^[A-Z0-9]{5,16}\z' 'M66'
Assert-Detected (Test-AllCode $m) 'M66_FREE_TEXT_IS_ACCEPTED_AS_A_VAT_NUMBER'
$m = Mutate-Text $vb 'Return LegalSpaces.Replace(LegalFormatChars.Replace(value, String.Empty), " ").Trim()' 'Return LegalFormatChars.Replace(value, String.Empty).Trim()' 'M67'
Assert-Detected (Test-AllCode $m) 'M67_LINE_BREAKS_AND_SPACES_ARE_NOT_COLLAPSED'
$m = Mutate-Text $vb 'Return LegalSpaces.Replace(LegalFormatChars.Replace(value, String.Empty), " ").Trim()' 'Return LegalSpaces.Replace(value, " ").Trim()' 'M68'
Assert-Detected (Test-AllCode $m) 'M68_BIDI_AND_ZERO_WIDTH_CHARACTERS_ARE_KEPT'
$m = Mutate-Text $vb 'If Not PostalPattern.IsMatch(raw) OrElse raw = "00000" Then Return String.Empty' 'If Not PostalPattern.IsMatch(raw) Then Return String.Empty' 'M69'
Assert-Detected (Test-AllCode $m) 'M69_AN_ALL_ZERO_POSTAL_CODE_IS_SHOWN'
$m = Mutate-Text $vb '^[0-9]{5}\z' '^[0-9]{4,6}\z' 'M70'
Assert-Detected (Test-AllCode $m) 'M70_A_POSTAL_CODE_OF_THE_WRONG_LENGTH_IS_SHOWN'
$m = Mutate-Text $vb '            If IsSameLegalPlace(' '            If False AndAlso IsSameLegalPlace(' 'M71'
Assert-Detected (Test-AllCode $m) 'M71_THE_SAME_PLACE_IS_SHOWN_TWICE'
$m = Mutate-Text $vb 'String.Equals(NormalizeCity(city1), NormalizeCity(city2), StringComparison.OrdinalIgnoreCase) AndAlso' 'True AndAlso' 'M72'
Assert-Detected (Test-AllCode $m) 'M72_TWO_CITIES_WITH_THE_SAME_STREET_ARE_MERGED'
$m = Mutate-Text $vb 'String.Equals(NormalizePostalCode(postal1), NormalizePostalCode(postal2), StringComparison.OrdinalIgnoreCase) AndAlso' 'True AndAlso' 'M72b'
Assert-Detected (Test-AllCode $m) 'M72B_TWO_POSTAL_CODES_ARE_MERGED'
$m = Mutate-Text $vb 'String.Equals(NormalizeProvince(province1), NormalizeProvince(province2), StringComparison.OrdinalIgnoreCase)' 'True' 'M72c'
Assert-Detected (Test-AllCode $m) 'M72C_TWO_PROVINCES_ARE_MERGED'
$m = Mutate-Text $vb 'String.Equals(NormalizeStreet(street1), NormalizeStreet(street2), StringComparison.OrdinalIgnoreCase)' 'String.Equals(NormalizeStreet(street1), NormalizeStreet(street2), StringComparison.Ordinal)' 'M73'
Assert-Detected (Test-AllCode $m) 'M73_THE_STREET_COMPARISON_IS_CASE_SENSITIVE'
$m = Mutate-Text $vb 'lines.Add("Sede operativa: " & HttpUtility.HtmlEncode(operational))' 'lines.Add("Sede operativa: " & HttpUtility.HtmlEncode(registered))' 'M74'
Assert-Detected (Test-AllCode $m) 'M74_THE_OPERATIONAL_LINE_SHOWS_THE_REGISTERED_ADDRESS'
$m = Mutate-Text $vb 'lines.Add("Sede: " & ' 'lines.Add("Sede legale: " & ' 'M75'
Assert-Detected (Test-AllCode $m) 'M75_A_LONE_OPERATIONAL_ADDRESS_IS_CALLED_THE_REGISTERED_OFFICE'
$m = Mutate-Text $vb 'If streetText.Length = 0 OrElse cityText.Length = 0 Then Return String.Empty' 'If cityText.Length = 0 Then Return String.Empty' 'M76'
Assert-Detected (Test-AllCode $m) 'M76_AN_ADDRESS_WITHOUT_A_STREET_IS_SHOWN'
$m = Mutate-Text $vb 'If streetText.Length = 0 OrElse cityText.Length = 0 Then Return String.Empty' 'If streetText.Length = 0 Then Return String.Empty' 'M77'
Assert-Detected (Test-AllCode $m) 'M77_AN_ADDRESS_WITHOUT_A_CITY_IS_SHOWN'
$m = Mutate-Text $vb 'CleanLegalText(value).TrimEnd(New Char() {" "c, ","c, ";"c, "."c})' 'CleanLegalText(value)' 'M78'
Assert-Detected (Test-AllCode $m) 'M78_TRAILING_PUNCTUATION_STAYS_IN_THE_STREET'
$m = Mutate-Text $vb '^[A-Za-z]{2}\z' '^[A-Za-z]{2,20}\z' 'M79'
Assert-Detected (Test-AllCode $m) 'M79_A_PROVINCE_NAME_IS_SHOWN_INSTEAD_OF_THE_CODE'
$m = Mutate-Text $vb 'Return raw.ToUpperInvariant()' 'Return raw' 'M80'
Assert-Detected (Test-AllCode $m) 'M80_THE_PROVINCE_IS_NOT_UPPERCASED'
$m = Mutate-Text $vb 'sb.Append(Char.ToUpperInvariant(c))' 'sb.Append(c)' 'M81'
Assert-Detected (Test-AllCode $m) 'M81_THE_VAT_COUNTRY_PREFIX_IS_NOT_UPPERCASED'
$m = Mutate-Text $vb 'sb.Append(Char.ToUpperInvariant(c))' 'sb.Append(Char.ToUpper(c))' 'M82'
Assert-Detected (Test-AllCode $m) 'M82_THE_VAT_UPPERCASE_DEPENDS_ON_THE_CURRENT_CULTURE'
$m = Mutate-Text $vb '        Dim head As String = HttpUtility' '        Dim taxCode As String = "CodiceFiscale"
        Dim head As String = HttpUtility' 'M83'
Assert-Detected (Test-AllCode $m) 'M83_THE_TAX_CODE_OF_A_PERSON_IS_USED'
$m = Mutate-Text $vb 'Return String.Join("<br />", lines.ToArray())' 'Return String.Join(" ", lines.ToArray())' 'M84'
Assert-Detected (Test-AllCode $m) 'M84_LEGAL_LINES_ARE_NOT_SEPARATED'
$m = Mutate-Text $vb 'Return String.Join("<br />", lines.ToArray())' 'Return HttpUtility.HtmlEncode(String.Join("<br />", lines.ToArray()))' 'M85'
Assert-Detected (Test-AllCode $m) 'M85_THE_WHOLE_BLOCK_IS_ENCODED_AGAIN'
$m = Mutate-Text $vb '        If legal Is Nothing Then Return String.Empty
        Dim lines As New List(Of String)()' '        If legal Is Nothing Then Return LastLegalHtml
        Dim lines As New List(Of String)()' 'M86a'
$m = Mutate-Text $m 'Return String.Join("<br />", lines.ToArray())' 'LastLegalHtml = String.Join("<br />", lines.ToArray())
        Return LastLegalHtml' 'M86b'
$m = Mutate-Text $m 'Private Shared ReadOnly VatPattern' 'Private Shared LastLegalHtml As String = String.Empty
    Private Shared ReadOnly VatPattern' 'M86c'
Assert-Detected (Test-AllCode $m) 'M86_THE_LAST_LEGAL_BLOCK_IS_REMEMBERED_ACROSS_CALLS'
$m = Mutate-Text $vb 'legalProfile = tenant.LegalProfile' 'legalProfile = Nothing' 'M87'
Assert-Detected (Test-AllCode $m) 'M87_THE_PROFILE_OF_THE_HOST_IS_NOT_READ'
$m = Mutate-Text $vb 'phFooterLegal.Visible = data.LegalHtml.Length > 0' 'phFooterLegal.Visible = True' 'M88'
Assert-Detected (Test-AllCode $m) 'M88_AN_EMPTY_LEGAL_PARAGRAPH_IS_ALWAYS_VISIBLE'
$m = Mutate-Text $vb 'litFooterLegal.Text = data.LegalHtml' 'litFooterLegal.Text = String.Empty' 'M89'
Assert-Detected (Test-AllCode $m) 'M89_THE_LEGAL_TEXT_IS_NEVER_WRITTEN'
$m = Mutate-Text $vb 'BindFooterLegal(data)
        BindFooterPayments(data)' 'BindFooterPayments(data)' 'M89b'
Assert-Detected (Test-AllCode $m) 'M89B_THE_LEGAL_BLOCK_IS_NEVER_BOUND'

# --- dati societari: policy (profilo e aggancio) -------------------------------------------------------------------------------------------------
$m = Mutate-Text $policy 'If profileCounts(companyId) = 1 AndAlso identityCounts(companyId) = 1 Then attached = profileById(companyId)' 'attached = profileById(companyId)' 'M100'
Assert-Detected (Test-AllPolicy $m) 'M100_A_PROFILE_IS_ATTACHED_EVEN_WHEN_THE_ID_IS_NOT_UNIQUE'
$m = Mutate-Text $policy 'If profileCounts(companyId) = 1 AndAlso identityCounts(companyId) = 1 Then' 'If profileCounts(companyId) = 1 Then' 'M101'
Assert-Detected (Test-AllPolicy $m) 'M101_A_DUPLICATED_IDENTITY_ID_STILL_GETS_A_PROFILE'
$m = Mutate-Text $policy 'If profileCounts(companyId) = 1 AndAlso identityCounts(companyId) = 1 Then' 'If identityCounts(companyId) = 1 Then' 'M102'
Assert-Detected (Test-AllPolicy $m) 'M102_A_DUPLICATED_PROFILE_ROW_STILL_GETS_ATTACHED'
$m = Mutate-Text $policy 'attached = profileById(companyId)' 'attached = System.Linq.Enumerable.Last(profileById.Values)' 'M103'
Assert-Detected (Test-AllPolicy $m) 'M103_THE_SAME_PROFILE_IS_ATTACHED_TO_EVERY_IDENTITY'
$m = Mutate-Text $policy '            identity.LegalProfile = attached' '            If attached IsNot Nothing Then identity.LegalProfile = attached' 'M104'
Assert-Detected (Test-AllPolicy $m) 'M104_A_STALE_PROFILE_SURVIVES_A_NEW_ATTACH'
$m = Mutate-Text $policy 'If profile Is Nothing OrElse profile.CompanyId <= 0 Then Continue For' 'If profile Is Nothing Then Continue For' 'M105a'
$m = Mutate-Text $m 'If identity Is Nothing OrElse identity.CompanyId <= 0 Then Continue For' 'If identity Is Nothing Then Continue For' 'M105b'
$m = Mutate-Text $m 'If companyId > 0 AndAlso profileCounts.ContainsKey(companyId)' 'If profileCounts.ContainsKey(companyId)' 'M105c'
Assert-Detected (Test-AllPolicy $m) 'M105_AN_UNREADABLE_ID_ZERO_PAIRS_A_PROFILE_WITH_AN_IDENTITY'
$m = Mutate-Text $policy 'column("SL_Citta")' 'column("Citta")' 'M106'
Assert-Detected (Test-AllPolicy $m) 'M106_THE_REGISTERED_CITY_IS_READ_FROM_THE_OPERATIONAL_COLUMN'
$m = Mutate-Text $policy 'Return value.Trim()' 'Return value' 'M108'
Assert-Detected (Test-AllPolicy $m) 'M108_PROFILE_VALUES_ARE_NOT_TRIMMED'
$m = Mutate-Text $policy 'If companyId <= 0 OrElse column Is Nothing Then Return Nothing' 'If column Is Nothing Then Return Nothing' 'M110'
Assert-Detected (Test-AllPolicy $m) 'M110_A_PROFILE_IS_CREATED_FOR_AN_UNREADABLE_ID'
$m = Mutate-Text $policy 'column("Piva")' 'column("RagioneSociale")' 'M111'
Assert-Detected (Test-AllPolicy $m) 'M111_THE_VAT_NUMBER_IS_READ_FROM_THE_NAME_COLUMN'

# --- dati societari: caricatore (testo) ----------------------------------------------------------------------------------------------------------
$m = Mutate-Text $ctx 'ListinoDefault, telefono, email FROM aziende ORDER BY Id' 'ListinoDefault, telefono, email, Piva FROM aziende ORDER BY Id' 'M120'
Assert-Detected (Test-AllContext $m) 'M120_THE_MAIN_IDENTITY_SELECT_IS_WIDENED'
$m = Mutate-Text $ctx 'SL_Provincia FROM aziende ORDER BY Id' 'SL_Provincia, CodiceFiscale FROM aziende ORDER BY Id' 'M121'
Assert-Detected (Test-AllContext $m) 'M121_THE_TAX_CODE_IS_READ'
$m = Mutate-Text $ctx '                AttachLegalProfiles(connection, result)
' '' 'M122'
Assert-Detected (Test-AllContext $m) 'M122_THE_LEGAL_PROFILES_ARE_NEVER_ATTACHED'
$m = Mutate-Text $ctx '                AttachLegalProfiles(connection, result)
                AttachPaymentMethods(connection, result)
            End Using
            HttpRuntime.Cache.Insert(' '                AttachPaymentMethods(connection, result)
            End Using
            HttpRuntime.Cache.Insert(' 'M123a'
$m = Mutate-Text $m '    Private Shared Function BuildTenantListCacheKey' '    Private Shared Sub UnusedAttach(ByVal connection As MySqlConnection, ByVal result As IList(Of StorefrontSeoTenantIdentity))
        AttachLegalProfiles(connection, result)
    End Sub

    Private Shared Function BuildTenantListCacheKey' 'M123b'
Assert-Detected (Test-AllContext $m) 'M123_THE_LEGAL_PROFILES_ARE_ATTACHED_OUTSIDE_THE_CONNECTION_BEFORE_THE_CACHE'
$m = Mutate-Text $ctx '        Catch
            Return Nothing' '        Catch
            Return New List(Of StorefrontCompanyLegalProfile)()' 'M124'
Assert-Detected (Test-AllContext $m) 'M124_AN_ERROR_RETURNS_AN_EMPTY_LIST_INSTEAD_OF_FAILING_SO_THE_FALLBACK_IS_NEVER_TRIED'
$m = Mutate-Text $ctx 'If profile IsNot Nothing Then profiles.Add(profile)' 'If profile IsNot Nothing Then profiles.Add(profile)
                        StorefrontCanonicalHostPolicy.ApplyLegalProfiles(Nothing, profiles)' 'M125'
Assert-Detected (Test-AllContext $m) 'M125_PROFILES_ARE_ATTACHED_WHILE_THE_ROWS_ARE_STILL_BEING_READ'
$m = Mutate-Text $ctx '        If profiles Is Nothing Then profiles = ReadLegalProfiles(connection, "SELECT Id, RagioneSociale, Indirizzo, Cap, Citta, Provincia, Piva FROM aziende ORDER BY Id")
' '' 'M129'
Assert-Detected (Test-AllContext $m) 'M129_THE_REDUCED_SELECT_IS_NEVER_TRIED'
$m = Mutate-Text $ctx 'If profiles Is Nothing Then profiles = ReadLegalProfiles(connection, "SELECT Id, RagioneSociale, Indirizzo, Cap, Citta, Provincia, Piva FROM aziende ORDER BY Id")' 'profiles = ReadLegalProfiles(connection, "SELECT Id, RagioneSociale, Indirizzo, Cap, Citta, Provincia, Piva FROM aziende ORDER BY Id")' 'M130'
Assert-Detected (Test-AllContext $m) 'M130_THE_REDUCED_SELECT_REPLACES_A_SUCCESSFUL_FULL_READ'
$m = Mutate-Text $ctx 'Provincia, Piva FROM aziende ORDER BY Id")' 'Provincia, Piva, SL_Indirizzo FROM aziende ORDER BY Id")' 'M131'
Assert-Detected (Test-AllContext $m) 'M131_THE_REDUCED_SELECT_STILL_NEEDS_THE_REGISTERED_OFFICE_COLUMNS'
$m = Mutate-Text $ctx 'SELECT Id, RagioneSociale, Indirizzo, Cap, Citta, Provincia, Piva FROM aziende ORDER BY Id' 'SELECT Id, RagioneSociale, Cap, Citta, Provincia, Piva FROM aziende ORDER BY Id' 'M132'
Assert-Detected (Test-AllContext $m) 'M132_THE_REDUCED_SELECT_LOSES_THE_OPERATIONAL_STREET'
$m = Mutate-Text $ctx '            Return profiles
        Catch' '            Return Nothing
        Catch' 'M133'
Assert-Detected (Test-AllContext $m) 'M133_A_SUCCESSFUL_READ_RETURNS_NOTHING'
$m = Mutate-Text $ctx '                command.CommandTimeout = 5
' '' 'M126'
Assert-Detected (Test-AllContext $m) 'M126_THE_OPTIONAL_QUERY_HAS_NO_SHORT_TIMEOUT'
$m = Mutate-Text $ctx 'Dim companyId As Integer = SafeReaderInteger(reader, "Id")' 'Dim companyId As Integer = SafeReaderInteger(reader, "IvaTipo")' 'M127'
Assert-Detected (Test-AllContext $m) 'M127_THE_PROFILE_ID_IS_READ_FROM_THE_WRONG_COLUMN'
$m = Mutate-Text $ctx 'Function(name As String) SafeReaderString(reader, name)' 'Function(name As String) SafeReaderString(reader, "RagioneSociale")' 'M128'
Assert-Detected (Test-AllContext $m) 'M128_EVERY_PROFILE_FIELD_READS_THE_SAME_COLUMN'

Write-Output 'FOOTER_TRUTH_ALL_PASS'
