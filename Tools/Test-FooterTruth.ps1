[CmdletBinding()]
param()

# KS-B02A-FOOTER-TRUTH-1A - il piede del sito dice solo cio che e vero per l'azienda e rimanda solo a pagine che esistono.
# Oracolo 1 (markup reale di SiteFooter.ascx): nessun testo del template o inventato (telefono finto, promozione, newsletter in inglese, social generici, pagamenti fissi, "#"),
# ogni link interno punta a un file .aspx che esiste (e l'ancora esiste nel file di destinazione), nessuna etichetta fissa da elettronica.
# Oracolo 2 (codice reale di SiteFooter.ascx.vb, regione FooterPure, compilato in memoria): telefono, e-mail, Facebook, copyright e contatti con casi limite e iniezioni;
# due aziende sintetiche e sessione di un'altra azienda senza dati incrociati. Oracolo 3: il collegamento del codice (nessun database, nessun ripiego sulla sessione).
# Limite noto: l'ancora #diritto-recesso e uno span vuoto sopra il testo letto dal database (condizioni-vendita.aspx): il test prova che esiste, non che il testo parli di recesso.
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

# --- Oracolo 1: markup reale -----------------------------------------------------------------------------------------------------------------
function Test-NoFabricatedContent([string]$text) {
    foreach ($bad in @('10% Off', 'Enter your email', 'Subscribe', 'Be the first', '+39 000', '390000000000', 'x.com', 'linkedin.com', 'whatsapp.com',
                       'Pagamenti accettati', 'method-payment', 'Discover', 'Visa', 'PayPal', 'Mastercard', 'ft-body-center', 'ksNewsletter', 'litSupportEmail', 'lnkSupportEmail',
                       'Nuovi arrivi', 'Occasione del giorno', 'Top offerte', 'Informazioni consegna', 'Servizio clienti', 'Resi e cambi', 'Supporto prodotti',
                       'Notebook e computer', 'Gaming e console', 'Smartphone e tablet', 'Accessori tech', 'Audio e cuffie', 'Fotografia e video', 'icon-location')) {
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
    foreach ($id in @('ulFooterColumns', 'phFooterCategories', 'litFooterCategories', 'litFooterContacts', 'litFooterCopyright', 'ulFooterSocial', 'liFooterFacebook', 'lnkFooterFacebook', 'imgFooterLogo')) {
        if ($text -notmatch ('\bID="' + $id + '"') -and $text -notmatch ('\bid="' + $id + '"')) { return $false }
    }
    # il blocco e il piede stampabile nascosto da ordine.aspx; la griglia e un controllo del server (3 o 4 colonne decise dal codice)
    if ($text -notmatch '<footer class="tf-footer">') { return $false }
    foreach ($lit in @('litFooterCategories', 'litFooterContacts', 'litFooterCopyright')) {
        if ($text -notmatch ('<asp:Literal ID="' + $lit + '" runat="server" EnableViewState="False" />')) { return $false }
    }
    if ($text -notmatch '<i class="icon-facebook" aria-hidden="true"></i>') { return $false }
    return ($text -match '<ul id="ulFooterColumns" runat="server" class="ft-link-wrap w-100 tf-grid-layout md-col-2')
}

Assert-Source (Test-NoFabricatedContent $ascx) 'F01_NO_FABRICATED_OR_TEMPLATE_CONTENT_IN_THE_FOOTER_MARKUP'
Assert-Source (Test-StaticLinksExist $ascx) 'F02_EVERY_STATIC_FOOTER_LINK_POINTS_TO_AN_EXISTING_PAGE_AND_ANCHOR'
Assert-Source (Test-RequiredLinks $ascx) 'F03_THE_REAL_LEGAL_AND_ACCOUNT_PAGES_ARE_LINKED_WITH_THEIR_OWN_LABELS'
Assert-Source (Test-DynamicHooks $ascx) 'F04_DYNAMIC_PARTS_ARE_SERVER_CONTROLS_WITHOUT_VIEWSTATE'

# --- Oracolo 2: il VERO codice (regione FooterPure di SiteFooter.ascx.vb) compilato ed eseguito ---------------------------------------------------
function Get-PureRegion([string]$vbText) {
    $m = [regex]::Match($vbText, '(?ms)^[ \t]*#Region "FooterPure"\n(.*?)\n[ \t]*#End Region')
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
function Compile-Footer([string]$region) {
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
        Return BuildTelHref(p)
    End Function
    Public Function Mail(ByVal e As String) As String
        Return BuildMailtoHref(e)
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
        Dim d As FooterData = BuildFooterData(host, sess, name, logo, phone, email, fb, year)
        Return New String() {d.LogoFileName, d.CompanyName, d.FacebookUrl, d.ContactsHtml, d.CopyrightHtml}
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
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($code))
    if ($c.Errors.HasErrors) { throw ('FOOTER_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('FooterProbe', $true))
}
function Test-Behaviour([string]$vbText) {
    $region = Get-PureRegion $vbText
    if ($null -eq $region) { throw 'FOOTER_PURE_REGION_NOT_FOUND' }
    $p = Compile-Footer $region
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
    return $true
}
Assert-Source (Test-Behaviour $vb) 'F05_THE_REAL_FOOTER_CODE_IS_TRUTHFUL_SAFE_AND_TENANT_ISOLATED'

# --- Oracolo 3: il collegamento del codice (nessun database, nessun ripiego sulla sessione) ------------------------------------------------------
function Test-Glue([string]$vbText) {
    # nessuna connessione, nessuna lettura dell'azienda dalla sola sessione, nessun valore inventato, nessuna richiesta usata per dedurre l'azienda
    foreach ($bad in @('MySqlConnection', 'MySqlCommand', 'ConfigurationManager', 'Session("AziendaNome")', 'Session("AziendaCopyright")', 'info@', 'KeepStore.Site.SupportEmail', 'SELECT ', 'Request.Url', 'Request.Headers')) {
        if ($vbText.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { return $false }
    }
    if ($vbText -match '(?i)\b(Visa|PayPal|Mastercard|Maestro|Discover)\b|Pagamenti accettati|\+39 0|Notebook|Subscribe|10% Off') { return $false }
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
    foreach ($line in @('hostCompanyId = tenant.CompanyId', 'companyName = tenant.CompanyName', 'logoFileName = tenant.LogoFileName', 'phone = tenant.SupportPhone', 'email = tenant.SupportEmail')) {
        if ($vbText.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if ($vbText -notmatch 'Dim data As FooterData = BuildFooterData\(hostCompanyId, SessionCompanyId\(\), companyName, logoFileName, phone, email, facebookRaw, DateTime\.Now\.Year\)') { return $false }
    # tutto cio che il piede mostra dell'azienda viene da BuildFooterData
    foreach ($line in @('litFooterContacts.Text = data.ContactsHtml', 'litFooterCopyright.Text = data.CopyrightHtml', 'BindFooterLogo(data)', 'BindFooterSocial(data)', 'BuildLogoAssetUrlFromFileName(data.LogoFileName)', 'lnkFooterFacebook.HRef = data.FacebookUrl')) {
        if ($vbText.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    # il collegamento Facebook ha un nome accessibile (icona senza testo)
    return ($vbText -match 'lnkFooterFacebook\.Attributes\("aria-label"\) = "Facebook"')
}
Assert-Source (Test-Glue $vb) 'F06_THE_FOOTER_READS_ONLY_THE_VERIFIED_HOST_IDENTITY_NO_DATABASE_NO_SESSION_FALLBACK'
Assert-Source ($ascx -notmatch '(?i)onsus' -and $vb -notmatch '(?i)onsus') 'F07_NO_TEMPLATE_NAME_IN_THE_FOOTER_SOURCES'
Assert-Source ($vb -notmatch '[^\x00-\x7F]') 'F08_FOOTER_CODE_BEHIND_IS_ASCII_ONLY'

# --- Mutazioni (copie in memoria): ognuna deve far fallire almeno un controllo ------------------------------------------------------------------
function Test-AllMarkup([string]$text) { return ((Test-NoFabricatedContent $text) -and (Test-StaticLinksExist $text) -and (Test-RequiredLinks $text) -and (Test-DynamicHooks $text)) }
function Test-AllCode([string]$text) { return ((Test-Behaviour $text) -and (Test-Glue $text)) }

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
$m = Mutate-Text $vb '                If i <> 0 Then Return String.Empty
                digits.Append(c)' '                digits.Append(c)' 'M25'
Assert-Detected (Test-AllCode $m) 'M25_PLUS_SIGN_ACCEPTED_ANYWHERE_IN_THE_PHONE'
$m = Mutate-Text $vb 'If count < 6 OrElse count > 15 OrElse Not nonZero Then Return String.Empty' 'If count < 1 OrElse count > 15 OrElse Not nonZero Then Return String.Empty' 'M26'
Assert-Detected (Test-AllCode $m) 'M26_SHORT_NUMBER_BECOMES_A_PHONE_LINK'
$m = Mutate-Text $vb 'If count < 6 OrElse count > 15 OrElse Not nonZero Then Return String.Empty' 'If count < 6 OrElse count > 15 Then Return String.Empty' 'M27'
Assert-Detected (Test-AllCode $m) 'M27_ALL_ZERO_NUMBER_BECOMES_A_PHONE_LINK'
$m = Mutate-Text $vb 'If c >= "0"c AndAlso c <= "9"c Then' 'If Char.IsDigit(c) Then' 'M28'
Assert-Detected (Test-AllCode $m) 'M28_UNICODE_DIGITS_ACCEPTED_IN_THE_PHONE'
$m = Mutate-Text $vb 'c = "("c OrElse c = ")"c Then' 'c = "("c OrElse c = ")"c OrElse c = "/"c Then' 'M29'
Assert-Detected (Test-AllCode $m) 'M29_TWO_NUMBERS_ARE_MERGED_INTO_ONE_PHONE_LINK'
$m = Mutate-Text $vb '            Else
                Return String.Empty
            End If
        Next
        Dim number' '            End If
        Next
        Dim number' 'M30'
Assert-Detected (Test-AllCode $m) 'M30_LETTERS_AND_SYMBOLS_ARE_DROPPED_FROM_THE_PHONE_INSTEAD_OF_REJECTED'
$m = Mutate-Text $vb '        If raw.Contains("..") Then Return String.Empty
' '' 'M31'
Assert-Detected (Test-AllCode $m) 'M31_CONSECUTIVE_DOTS_ARE_ACCEPTED_IN_THE_EMAIL'
$m = Mutate-Text $vb '(?:[A-Za-z0-9._+\-]{0,62}' '(?:[A-Za-z0-9._+%\-]{0,62}' 'M32'
Assert-Detected (Test-AllCode $m) 'M32_PERCENT_ESCAPES_ACCEPTED_IN_THE_EMAIL_LOCAL_PART'
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
$m = Mutate-Text $vb '        If raw.StartsWith("+", StringComparison.Ordinal) AndAlso raw.Contains("(0)") Then Return String.Empty
' '' 'M54'
Assert-Detected (Test-AllCode $m) 'M54_TRUNK_ZERO_AFTER_THE_COUNTRY_PREFIX_IS_KEPT'
$m = Mutate-Text $vb '        Dim html As String = String.Empty
        Try' '        Dim html As String = String.Empty
        Visa.ToString()
        Try' 'M55'
Assert-Detected (Test-AllCode $m) 'M55_A_FIXED_PAYMENT_NAME_COMES_BACK_IN_THE_CODE'

Write-Output 'FOOTER_TRUTH_ALL_PASS'
