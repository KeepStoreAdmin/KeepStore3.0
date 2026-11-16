[CmdletBinding()]
param([switch]$SkipMutations)

# KS-A04-CONTACT-LINKS-1A - un solo validatore per i collegamenti tel: e mailto: di piede, testata e Contattaci.
# Oracolo 1: il VERO file App_Code/KeepStoreContactLinks.vb compilato (Strict) e provato con una matrice di numeri ed e-mail (validi, non validi, ai limiti).
# Oracolo 2: la regione HeaderContactPure della testata compilata INSIEME alla classe condivisa, con i VERI controlli HyperLink e Literal resi su un
# HtmlTextWriter: dato valido = href normalizzato, dato non vuoto ma non valido = solo il testo codificato SENZA href, dato vuoto = controllo nascosto.
# Oracolo 3 (testo del codice, senza commenti): piede, testata e Contattaci non costruiscono piu "tel:" o "mailto:" da soli e chiamano la classe condivisa;
# Contattaci imposta l'href SOLO se il dato e valido. Il comportamento del piede e di Contattaci e provato anche da Test-FooterTruth e Test-ContactHostIdentity.
# Mutazioni su copie in memoria. Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'WINDOWS_POWERSHELL_5_1_REQUIRED_FOR_CODEDOM' }
$repoRoot = Split-Path -Parent $PSScriptRoot
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$relativePath) { return (Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath), [Text.Encoding]::UTF8))) }
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
function Strip-Comments([string]$text) { return (([regex]::Replace($text, "(?m)^[ \t]*'.*$", '')) -replace "(?m)[ \t]+'[^`"\n]*$", '') }
function Show-Failure([string]$id, [string]$got) { if ($env:KS_LINKS_TEST_VERBOSE) { Write-Host ('LINKS_CASE_FAILED ' + $id + ' got=[' + $got + ']') } }

$links = Read-Repo 'App_Code/KeepStoreContactLinks.vb'
$footer = Read-Repo 'Public/ui/controls/SiteFooter.ascx.vb'
$header = Read-Repo 'Public/ui/controls/SiteHeader.ascx.vb'
$contact = Read-Repo 'Contattaci.aspx.vb'

# --- Oracolo 1: il validatore compilato ---------------------------------------------------------------------------------------------------------------
function New-ValidatorProbe([string]$linksText) {
    $code = @"
Option Strict On
Option Explicit On
Imports System
Public Class LinksProbe
    Public Function Tel(ByVal p As String) As String
        Return KeepStoreContactLinks.BuildTelHref(p)
    End Function
    Public Function Mail(ByVal e As String) As String
        Return KeepStoreContactLinks.BuildMailtoHref(e)
    End Function
End Class
"@
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Web.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($linksText, $code))
    if ($c.Errors.HasErrors) { throw ('LINKS_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('LinksProbe', $true))
}

$lab63 = 'a' * 63
$mail254 = 'x@' + $lab63 + '.' + $lab63 + '.' + $lab63 + '.' + ('a' * 57) + '.it'
$mail255 = 'x@' + $lab63 + '.' + $lab63 + '.' + $lab63 + '.' + ('a' * 58) + '.it'
if ($mail254.Length -ne 254 -or $mail255.Length -ne 255) { throw 'TEST_FIXTURE_MAIL_LENGTH' }
# gli spazi stanno DENTRO il numero: il Trim() toglie quelli ai bordi prima del controllo di lunghezza
$tel40 = '12345' + (' ' * 30) + '67890'
$tel41 = '12345' + (' ' * 31) + '67890'
if ($tel40.Length -ne 40 -or $tel41.Length -ne 41) { throw 'TEST_FIXTURE_TEL_LENGTH' }

# [ingresso, atteso]: l'atteso vuoto = nessun collegamento
$telCases = @(
    @('+39 02 1234567', 'tel:+39021234567'), @('02.1234-567', 'tel:021234567'), @('(02) 12 34 567', 'tel:021234567'), @('0039 02 1234567', 'tel:0039021234567'),
    @('123456', 'tel:123456'), @('800 123 456', 'tel:800123456'), @('+39 06.1234.5678', 'tel:+390612345678'), @('  081 123456  ', 'tel:081123456'),
    @('123456789012345', 'tel:123456789012345'), @($tel40, 'tel:1234567890'), @(('123456' + (' ' * 40)), 'tel:123456'),
    @('+123456789012345', 'tel:+123456789012345'), @('+123456', 'tel:+123456'), @('+39 (02) 1234567', 'tel:+39021234567'),
    @($tel41, ''), @('1234567890123456', ''), @('+1234567890123456', ''), @('12345', ''), @('+12345', ''), @('123', ''), @('', ''), @('   ', ''), @('0', ''), @('000000', ''), @('+000000', ''),
    @('+44 (0)20 7946 0958', ''), @('+44 ( 0 )20 7946 0958', ''), @('0039 (0)2 1234567', ''), @('(0) 123456', ''), @('+39 (0)2 1234567', ''),
    @('javascript:alert(1)', ''), @('javascript:123456', ''), @('"><script>1</script>', ''),
    @('02 1234567 int. 3', ''), @('Tel. 081 123456', ''), @('tel:081123456', ''), @('+39 02 12+34567', ''), @('++39 02 1234567', ''), @('02 1234567+', ''), @('+', ''), @('()-./ ', ''),
    @('dalle 9 alle 18', ''), @('0721 1234 / 0721 5678', ''), @('02 123 / 06 456', ''), @('02 1234567; 06 7654321', ''), @('081 123456 - 081 654321', ''),
    @(('0212345678' + [char]10 + 'x'), ''), @('+39 02 1234567 #1', ''), @('+39 02 12%34567', ''), @('02%0d%0a1234567', ''),
    @((([string][char]0x0660) * 8), ''), @((([string][char]0xFF11) * 8), '')
)
$mailCases = @(
    @('info@alfa.example.it', 'mailto:info@alfa.example.it'), @('first.last+tag@sub.example.co.uk', 'mailto:first.last+tag@sub.example.co.uk'), @('a_b-c@d-e.it', 'mailto:a_b-c@d-e.it'),
    @('INFO@ALFA.IT', 'mailto:INFO@ALFA.IT'), @('  info@alfa.it  ', 'mailto:info@alfa.it'), @((('a' * 64) + '@y.it'), ('mailto:' + ('a' * 64) + '@y.it')),
    @(('x@' + ('a' * 63) + '.it'), ('mailto:x@' + ('a' * 63) + '.it')), @($mail254, ('mailto:' + $mail254)), @(('a@b.' + ('c' * 24)), ('mailto:a@b.' + ('c' * 24))),
    @('', ''), @('   ', ''), @('a@b', ''), @('a@b.c', ''), @(('a@b.' + ('c' * 25)), ''), @($mail255, ''), @((('a' * 65) + '@y.it'), ''), @(('x@' + ('a' * 64) + '.it'), ''), @((('x' * 70) + '@y.it'), ''),
    @('x@y.it?bcc=z@z.it', ''), @('x@y.it?subject=hi', ''), @('x@y.it&cc=z@z.it', ''), @('mailto:x@y.it', ''), @('x@y.it, z@z.it', ''), @('x@y.it; z@z.it', ''), @('x y@z.it', ''),
    @(('x@y.it' + [char]13 + [char]10 + 'Bcc:z@z.it'), ''), @('<b>@y.it', ''), @('x@y.it"', ''), @('javascript:alert(1)@y.it', ''), @(([string][char]0x00E8 + '@y.it'), ''),
    @('x%0d%0aBcc@y.it', ''), @('x%3f@y.it', ''), @('x#y@y.it', ''), @('x@y.it#a', ''), @('x@y.it%0d', ''), @('x@@y.it', ''), @('@y.it', ''), @('x@.it', ''), @('x@y..it', ''),
    @('.x@y.it', ''), @('x.@y.it', ''), @('a..b@y.it', ''), @('x?y@z.it', ''), @('x&y@z.it', ''), @('x=y@z.it', ''), @('x/y@z.it', ''), @('x!y@z.it', ''), @("x'y@z.it", ''), @('x"y@z.it', ''),
    @(('x@y.it' + [char]9 + 'z'), '')
)
function Test-ValidatorMatrix([string]$linksText) {
    try { $p = New-ValidatorProbe $linksText } catch { Show-Failure 'compile' $_.Exception.Message; return $false }
    foreach ($c in $telCases) { $got = $p.Tel($c[0]); if ($got -cne $c[1]) { Show-Failure ('tel [' + $c[0] + ']') $got; return $false } }
    foreach ($c in $mailCases) { $got = $p.Mail($c[0]); if ($got -cne $c[1]) { Show-Failure ('mail [' + $c[0] + ']') $got; return $false } }
    if ($p.Tel($null) -cne '' -or $p.Mail($null) -cne '') { return $false }
    return $true
}
function Test-LinksStructure([string]$text) {
    $code = Strip-Comments $text
    if ($code -notmatch '(?m)^Public NotInheritable Class KeepStoreContactLinks\s*$') { return $false }
    if ([regex]::Matches($code, '(?m)^\s*Public Shared Function (BuildTelHref|BuildMailtoHref)\(').Count -ne 2) { return $false }
    if ([regex]::Matches($code, '(?m)^\s*(Public|Friend|Protected)\b').Count -ne 3) { return $false }
    if ([regex]::Matches($code, [regex]::Escape('"tel:"')).Count -ne 1 -or [regex]::Matches($code, [regex]::Escape('"mailto:"')).Count -ne 1) { return $false }
    if ($text -match '(?i)\b(taikun|webaffare|onsus|italcomed|ks_marea|panificiosa|miranda|newnda|tecind)\b') { return $false }
    foreach ($bad in @('MySqlConnection', 'Session', 'HttpContext', 'ConfigurationManager')) { if ($code.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { return $false } }
    return $true
}
Assert-Source (Test-ValidatorMatrix $links) 'L01_THE_REAL_VALIDATOR_ACCEPTS_ONLY_A_SINGLE_PLAUSIBLE_NUMBER_OR_ADDRESS_AND_NORMALIZES_THE_HREF'
Assert-Source (Test-LinksStructure $links) 'L02_THE_SHARED_CLASS_HAS_ONLY_THE_TWO_PUBLIC_FUNCTIONS_AND_NO_SESSION_DATABASE_OR_CUSTOMER_NAME'

# --- Oracolo 2: la regione della testata con i veri controlli -------------------------------------------------------------------------------------
function Get-HeaderRegion([string]$vbText) {
    $m = [regex]::Match($vbText, '(?ms)^[ \t]*#Region "HeaderContactPure"\n(.*?)\n[ \t]*#End Region')
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
function New-HeaderProbe([string]$region, [string]$linksText) {
    $code = @"
Option Strict On
Option Explicit On
Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Public Class HeaderProbe
$region
    Private Shared Function Render(ByVal link As HyperLink) As String
        Dim sw As New StringWriter()
        Dim hw As New HtmlTextWriter(sw)
        link.RenderControl(hw)
        hw.Flush()
        Return sw.ToString()
    End Function
    Public Function Phone(ByVal value As String) As String()
        Dim link As New HyperLink()
        Dim lit As New Literal()
        link.Controls.Add(lit)
        link.CssClass = "x"
        SetPhoneLink(link, lit, value)
        Return New String() {Render(link), lit.Text, link.Visible.ToString()}
    End Function
    Public Function Mail(ByVal value As String) As String()
        Dim link As New HyperLink()
        Dim lit As New Literal()
        link.Controls.Add(lit)
        link.CssClass = "x"
        SetMailLink(link, lit, value)
        Return New String() {Render(link), lit.Text, link.Visible.ToString()}
    End Function
    Public Function Sequence(ByVal phone As Boolean) As String()
        Dim link As New HyperLink()
        Dim lit As New Literal()
        link.Controls.Add(lit)
        link.CssClass = "x"
        Dim values As String() = If(phone, New String() {"+39 02 1234567", "dalle 9 alle 18", "", "081 123456"}, New String() {"info@alfa.it", "x@y.it?bcc=z@z.it", "", "info@alfa.it"})
        Dim result As New List(Of String)()
        For Each value As String In values
            If phone Then
                SetPhoneLink(link, lit, value)
            Else
                SetMailLink(link, lit, value)
            End If
            result.Add(Render(link))
        Next
        Return result.ToArray()
    End Function
    Public Function Nulls() As Boolean
        Dim link As New HyperLink()
        Dim lit As New Literal()
        SetPhoneLink(Nothing, lit, "123456")
        SetPhoneLink(link, Nothing, "123456")
        SetMailLink(Nothing, lit, "a@b.it")
        SetMailLink(link, Nothing, "a@b.it")
        Return True
    End Function
End Class
"@
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Web.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($linksText, $code))
    if ($c.Errors.HasErrors) { throw ('HEADER_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('HeaderProbe', $true))
}
# [ingresso, html atteso, testo atteso, visibile]
$headerPhone = @(
    @('+39 02 1234567', '<a class="x" href="tel:+39021234567">+39 02 1234567</a>', '+39 02 1234567', 'True'),
    @('  081-123.456  ', '<a class="x" href="tel:081123456">081-123.456</a>', '081-123.456', 'True'),
    @('800 123 456', '<a class="x" href="tel:800123456">800 123 456</a>', '800 123 456', 'True'),
    @('dalle 9 alle 18', '<a class="x">dalle 9 alle 18</a>', 'dalle 9 alle 18', 'True'),
    @('+44 (0)20 7946 0958', '<a class="x">+44 (0)20 7946 0958</a>', '+44 (0)20 7946 0958', 'True'),
    @('0721 1234 / 0721 5678', '<a class="x">0721 1234 / 0721 5678</a>', '0721 1234 / 0721 5678', 'True'),
    @('<script>alert(1)</script>', '<a class="x">&lt;script&gt;alert(1)&lt;/script&gt;</a>', '&lt;script&gt;alert(1)&lt;/script&gt;', 'True'),
    @('"><img src=x onerror=1>', '<a class="x">&quot;&gt;&lt;img src=x onerror=1&gt;</a>', '&quot;&gt;&lt;img src=x onerror=1&gt;', 'True'),
    @('', '', '', 'False'), @('   ', '', '', 'False'), @($null, '', '', 'False')
)
$headerMail = @(
    @('info@alfa.example.it', '<a class="x" href="mailto:info@alfa.example.it">info@alfa.example.it</a>', 'info@alfa.example.it', 'True'),
    @('  info@alfa.it  ', '<a class="x" href="mailto:info@alfa.it">info@alfa.it</a>', 'info@alfa.it', 'True'),
    @('x@y.it?bcc=z@z.it', '<a class="x">x@y.it?bcc=z@z.it</a>', 'x@y.it?bcc=z@z.it', 'True'),
    @('a@b.it, c@d.it', '<a class="x">a@b.it, c@d.it</a>', 'a@b.it, c@d.it', 'True'),
    @('x"y<script>@z', '<a class="x">x&quot;y&lt;script&gt;@z</a>', 'x&quot;y&lt;script&gt;@z', 'True'),
    @('', '', '', 'False'), @('   ', '', '', 'False'), @($null, '', '', 'False')
)
function Test-HeaderBehaviour([string]$vbText, [string]$linksText) {
    $region = Get-HeaderRegion $vbText
    if ($null -eq $region) { Show-Failure 'region' 'HEADER_REGION_NOT_FOUND'; return $false }
    try { $p = New-HeaderProbe $region $linksText } catch { Show-Failure 'compile' $_.Exception.Message; return $false }
    try {
        foreach ($c in $headerPhone) {
            $r = $p.Phone($c[0])
            if ($r[0] -cne $c[1] -or $r[1] -cne $c[2] -or $r[2] -cne $c[3]) { Show-Failure ('phone [' + $c[0] + ']') ($r -join ' | '); return $false }
        }
        foreach ($c in $headerMail) {
            $r = $p.Mail($c[0])
            if ($r[0] -cne $c[1] -or $r[1] -cne $c[2] -or $r[2] -cne $c[3]) { Show-Failure ('mail [' + $c[0] + ']') ($r -join ' | '); return $false }
        }
        # lo STESSO controllo attraverso valido -> non valido -> vuoto -> valido: nessuno stato vecchio deve restare (href, visibilita)
        $sp = $p.Sequence($true)
        $expP = @('<a class="x" href="tel:+39021234567">+39 02 1234567</a>', '<a class="x">dalle 9 alle 18</a>', '', '<a class="x" href="tel:081123456">081 123456</a>')
        $sm = $p.Sequence($false)
        $expM = @('<a class="x" href="mailto:info@alfa.it">info@alfa.it</a>', '<a class="x">x@y.it?bcc=z@z.it</a>', '', '<a class="x" href="mailto:info@alfa.it">info@alfa.it</a>')
        for ($i = 0; $i -lt 4; $i++) {
            if ($sp[$i] -cne $expP[$i]) { Show-Failure ('phone sequence ' + $i) $sp[$i]; return $false }
            if ($sm[$i] -cne $expM[$i]) { Show-Failure ('mail sequence ' + $i) $sm[$i]; return $false }
        }
        if (-not $p.Nulls()) { return $false }
    } catch { Show-Failure 'exception' $_.Exception.Message; return $false }
    return $true
}
Assert-Source (Test-HeaderBehaviour $header $links) 'L03_THE_HEADER_LINKS_ARE_REAL_ONLY_FOR_VALID_DATA_AND_AN_INVALID_VALUE_STAYS_VISIBLE_AS_TEXT_WITHOUT_AN_HREF'

# --- Oracolo 3: i tre consumatori non costruiscono piu i collegamenti da soli -----------------------------------------------------------------------
function Test-NoLocalLinkBuilding([string]$text) {
    $code = Strip-Comments $text
    foreach ($bad in @('"tel:"', '"mailto:"', 'MailPattern', 'Function BuildTelHref', 'Function BuildMailtoHref', 'telClean')) { if ($code.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { return $false } }
    return $true
}
function Test-FooterUses([string]$text) {
    if (-not (Test-NoLocalLinkBuilding $text)) { return $false }
    $code = Strip-Comments $text
    return ($code.Contains('Dim telHref As String = KeepStoreContactLinks.BuildTelHref(phoneText)') -and $code.Contains('Dim mailHref As String = KeepStoreContactLinks.BuildMailtoHref(emailText)'))
}
function Test-HeaderUses([string]$text) {
    if (-not (Test-NoLocalLinkBuilding $text)) { return $false }
    $code = Strip-Comments $text
    foreach ($line in @('link.NavigateUrl = KeepStoreContactLinks.BuildTelHref(cleanPhone)', 'link.NavigateUrl = KeepStoreContactLinks.BuildMailtoHref(cleanEmail)',
                        'SetPhoneLink(hlSupportPhoneTop, litSupportPhoneTop, phone)', 'SetPhoneLink(hlSupportPhoneHeader, litSupportPhoneHeader, phone)', 'SetMailLink(hlSupportEmailHeader, litSupportEmailHeader, email)')) {
        if ([regex]::Matches($code, [regex]::Escape($line)).Count -ne 1) { return $false }
    }
    return $true
}
function Test-ContactUses([string]$text) {
    if (-not (Test-NoLocalLinkBuilding $text)) { return $false }
    $code = Strip-Comments $text
    foreach ($line in @('view.TelHref = KeepStoreContactLinks.BuildTelHref(telefono)', 'view.MailHref = KeepStoreContactLinks.BuildMailtoHref(mail)',
                        'ApplyContactLinks(lnkPhone, lnkEmail, view)', 'phoneLink.HRef = view.TelHref', 'mailLink.HRef = view.MailHref')) {
        if ([regex]::Matches($code, [regex]::Escape($line)).Count -ne 1) { return $false }
    }
    # nessun ripiego sulla mappa per il telefono o l'e-mail, e NESSUNA guardia sull'assegnazione: un href vecchio (ViewState) si toglie solo assegnando anche il vuoto
    if ($code -match 'TelHref\s*=\s*view\.MapUrl' -or $code -match 'MailHref\s*=\s*view\.MapUrl') { return $false }
    if ($code -match 'If\s+view\.(Tel|Mail)Href\.Length' -or $code -match 'If\s+(phone|mail)Link\.' -or $code -match 'view\.(Tel|Mail)Href\s*<>') { return $false }
    return $true
}
Assert-Source (Test-FooterUses $footer) 'L04_THE_FOOTER_CALLS_THE_SHARED_VALIDATOR_AND_HAS_NO_COPY_OF_IT'
Assert-Source (Test-HeaderUses $header) 'L05_THE_HEADER_CALLS_THE_SHARED_VALIDATOR_AND_NEVER_BUILDS_A_LINK_BY_ITSELF'
Assert-Source (Test-ContactUses $contact) 'L06_THE_CONTACT_PAGE_CALLS_THE_SHARED_VALIDATOR_AND_ALWAYS_ASSIGNS_ITS_RESULT_TO_THE_HREF'

if ($SkipMutations) { Write-Output 'CONTACT_LINKS_ALL_PASS_WITHOUT_MUTATIONS'; return }

# --- Mutazioni (copie in memoria) -------------------------------------------------------------------------------------------------------------------
function Test-LinksAll([string]$text) { return ((Test-ValidatorMatrix $text) -and (Test-LinksStructure $text)) }
function MutLinks([string]$old, [string]$new, [string]$code, [string]$name) {
    $m = Mutate-Text $links $old $new $code
    Assert-Detected (Test-LinksAll $m) $name
}
# telefono
MutLinks 'raw.Length > 40' 'raw.Length > 41' 'V01' 'V01_THE_PHONE_LENGTH_LIMIT_MOVES_UP'
MutLinks 'raw.Length > 40' 'raw.Length > 39' 'V02' 'V02_THE_PHONE_LENGTH_LIMIT_MOVES_DOWN'
MutLinks 'Dim raw As String = If(phone, String.Empty).Trim()' 'Dim raw As String = If(phone, String.Empty)' 'V03' 'V03_THE_PHONE_IS_NOT_TRIMMED'
MutLinks 'If ZeroGroup.IsMatch(raw) Then Return String.Empty' '' 'V04' 'V04_THE_OPTIONAL_TRUNK_ZERO_IN_PARENTHESES_IS_ACCEPTED'
MutLinks '"\(\s*0\s*\)"' '"\(0\)"' 'V04b' 'V04B_THE_OPTIONAL_TRUNK_ZERO_WITH_SPACES_INSIDE_THE_PARENTHESES_IS_ACCEPTED'
MutLinks '"\(\s*0\s*\)"' '"\(\s*0\s*\)\d"' 'V04c' 'V04C_THE_OPTIONAL_TRUNK_ZERO_IS_ACCEPTED_WHEN_NOT_FOLLOWED_BY_A_DIGIT'
MutLinks 'OrElse Not nonZero' '' 'V05' 'V05_A_NUMBER_OF_ONLY_ZEROS_IS_ACCEPTED'
MutLinks '                If i <> 0 Then Return String.Empty
' '' 'V06' 'V06_A_PLUS_IS_ACCEPTED_ANYWHERE'
MutLinks 'OrElse c = ")"c' '' 'V07' 'V07_A_CLOSING_PARENTHESIS_IS_REJECTED'
MutLinks 'OrElse c = "("c' '' 'V08' 'V08_AN_OPENING_PARENTHESIS_IS_REJECTED'
MutLinks 'OrElse c = "."c' '' 'V09' 'V09_A_DOT_IS_REJECTED'
MutLinks 'OrElse c = "-"c' '' 'V10' 'V10_A_DASH_IS_REJECTED'
MutLinks 'c = " "c OrElse' '' 'V11' 'V11_A_SPACE_IS_REJECTED'
MutLinks 'count < 6' 'count < 5' 'V12' 'V12_FIVE_DIGITS_ARE_ACCEPTED'
MutLinks 'count < 6' 'count < 7' 'V13' 'V13_SIX_DIGITS_ARE_REJECTED'
MutLinks 'count > 15' 'count > 16' 'V14' 'V14_SIXTEEN_DIGITS_ARE_ACCEPTED'
MutLinks 'count > 15' 'count > 14' 'V15' 'V15_FIFTEEN_DIGITS_ARE_REJECTED'
MutLinks 'Dim count As Integer = number.Length - If(number.StartsWith("+", StringComparison.Ordinal), 1, 0)' 'Dim count As Integer = number.Length' 'V35' 'V35_THE_PLUS_SIGN_IS_COUNTED_AMONG_THE_DIGITS'
MutLinks 'OrElse c = ")"c Then' 'OrElse c = ")"c OrElse c = "/"c Then' 'V36' 'V36_TWO_NUMBERS_ARE_MERGED_INTO_ONE_PHONE_LINK'
MutLinks 'Return "tel:" & number' 'Return "tel:" & raw' 'V16' 'V16_THE_PHONE_HREF_KEEPS_THE_SEPARATORS'
MutLinks 'If c >= "0"c AndAlso c <= "9"c Then' 'If Char.IsDigit(c) Then' 'V17' 'V17_NON_ASCII_DIGITS_ARE_ACCEPTED'
MutLinks '            Else
                Return String.Empty
            End If
        Next' '            End If
        Next' 'V18' 'V18_LETTERS_AND_SYMBOLS_ARE_IGNORED'
# e-mail
MutLinks 'raw.Length > 254' 'raw.Length > 255' 'V20' 'V20_THE_MAIL_LENGTH_LIMIT_MOVES_UP'
MutLinks 'Dim raw As String = If(email, String.Empty).Trim()' 'Dim raw As String = If(email, String.Empty)' 'V21' 'V21_THE_MAIL_IS_NOT_TRIMMED'
MutLinks 'If Not MailPattern.IsMatch(raw) Then Return String.Empty' '' 'V22' 'V22_THE_MAIL_PATTERN_IS_NOT_APPLIED'
MutLinks 'If raw.Contains("..") Then Return String.Empty' '' 'V23' 'V23_DOUBLE_DOTS_ARE_ACCEPTED'
MutLinks 'Return "mailto:" & raw' 'Return "mailto:" & email' 'V24' 'V24_THE_MAIL_HREF_IS_NOT_THE_TRIMMED_VALUE'
MutLinks '{0,62}[A-Za-z0-9])?@' '{0,63}[A-Za-z0-9])?@' 'V25' 'V25_THE_LOCAL_PART_MAY_BE_65_CHARACTERS'
MutLinks '{0,61}[A-Za-z0-9])?\.)+' '{0,62}[A-Za-z0-9])?\.)+' 'V26' 'V26_A_DOMAIN_LABEL_MAY_BE_64_CHARACTERS'
MutLinks '[A-Za-z]{2,24}\z' '[A-Za-z]{1,24}\z' 'V27' 'V27_A_ONE_LETTER_TOP_LEVEL_DOMAIN_IS_ACCEPTED'
MutLinks '[A-Za-z]{2,24}\z' '[A-Za-z]{2,25}\z' 'V28' 'V28_A_25_LETTER_TOP_LEVEL_DOMAIN_IS_ACCEPTED'
MutLinks '[A-Za-z0-9._+\-]{0,62}' '[A-Za-z0-9_+\-]{0,62}' 'V29' 'V29_A_DOT_IN_THE_LOCAL_PART_IS_REJECTED'
MutLinks '[A-Za-z0-9._+\-]{0,62}' '[A-Za-z0-9._\-]{0,62}' 'V30' 'V30_A_PLUS_IN_THE_LOCAL_PART_IS_REJECTED'
MutLinks '[A-Za-z0-9._+\-]{0,62}' '[A-Za-z0-9._+]{0,62}' 'V31' 'V31_A_DASH_IN_THE_LOCAL_PART_IS_REJECTED'
MutLinks '[A-Za-z0-9._+\-]{0,62}' '[A-Za-z0-9._+\-?&=%/#]{0,62}' 'V32' 'V32_QUERY_CHARACTERS_ARE_ACCEPTED_IN_THE_LOCAL_PART'
MutLinks '(?:[A-Za-z0-9\-]{0,61}' '(?:[A-Za-z0-9]{0,61}' 'V33' 'V33_A_DASH_IN_A_DOMAIN_LABEL_IS_REJECTED'
MutLinks '^[A-Za-z0-9](?:' '[A-Za-z0-9](?:' 'V34' 'V34_THE_PATTERN_IS_NOT_ANCHORED_AT_THE_START'
# i due equivalenti dichiarati (non contati): la regex con \z contro $ dopo il Trim; il Trim del telefono quando restano solo separatori ai bordi.

# testata
function Test-HeaderAll([string]$text) { return ((Test-HeaderBehaviour $text $links) -and (Test-HeaderUses $text)) }
function MutHeader([string]$old, [string]$new, [string]$code, [string]$name) {
    $m = Mutate-Text $header $old $new $code
    Assert-Detected (Test-HeaderAll $m) $name
}
MutHeader 'link.NavigateUrl = KeepStoreContactLinks.BuildTelHref(cleanPhone)' 'link.NavigateUrl = "tel:" & cleanPhone' 'H01' 'H01_THE_HEADER_PHONE_LINK_IS_BUILT_BY_HAND_AGAIN'
MutHeader 'link.NavigateUrl = KeepStoreContactLinks.BuildMailtoHref(cleanEmail)' 'link.NavigateUrl = "mailto:" & cleanEmail' 'H02' 'H02_THE_HEADER_MAIL_LINK_IS_BUILT_BY_HAND_AGAIN'
MutHeader 'link.NavigateUrl = KeepStoreContactLinks.BuildTelHref(cleanPhone)' 'link.NavigateUrl = KeepStoreContactLinks.BuildMailtoHref(cleanPhone)' 'H03' 'H03_THE_HEADER_PHONE_USES_THE_MAIL_VALIDATOR'
MutHeader 'link.NavigateUrl = KeepStoreContactLinks.BuildMailtoHref(cleanEmail)' 'link.NavigateUrl = KeepStoreContactLinks.BuildTelHref(cleanEmail)' 'H04' 'H04_THE_HEADER_MAIL_USES_THE_PHONE_VALIDATOR'
MutHeader 'literal.Text = HttpUtility.HtmlEncode(cleanPhone)' 'literal.Text = cleanPhone' 'H05' 'H05_THE_HEADER_PHONE_TEXT_IS_NOT_ENCODED'
MutHeader 'literal.Text = HttpUtility.HtmlEncode(cleanEmail)' 'literal.Text = cleanEmail' 'H06' 'H06_THE_HEADER_MAIL_TEXT_IS_NOT_ENCODED'
MutHeader 'Dim cleanPhone As String = If(phone, String.Empty).Trim()' 'Dim cleanPhone As String = If(phone, String.Empty)' 'H07' 'H07_THE_HEADER_PHONE_IS_NOT_TRIMMED'
MutHeader 'Dim cleanEmail As String = If(email, String.Empty).Trim()' 'Dim cleanEmail As String = If(email, String.Empty)' 'H08' 'H08_THE_HEADER_MAIL_IS_NOT_TRIMMED'
MutHeader '        Dim cleanPhone As String = If(phone, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(cleanPhone) Then
            link.Visible = False' '        Dim cleanPhone As String = If(phone, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(cleanPhone) Then
            link.Visible = True' 'H09' 'H09_AN_EMPTY_HEADER_PHONE_STAYS_VISIBLE'
MutHeader '        Dim cleanEmail As String = If(email, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(cleanEmail) Then
            link.Visible = False' '        Dim cleanEmail As String = If(email, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(cleanEmail) Then
            link.Visible = True' 'H10' 'H10_AN_EMPTY_HEADER_MAIL_STAYS_VISIBLE'
MutHeader '        Dim cleanPhone As String = If(phone, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(cleanPhone) Then
            link.Visible = False
            literal.Text = String.Empty
            Return
        End If' '        Dim cleanPhone As String = If(phone, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(cleanPhone) Then
            Return
        End If' 'H11' 'H11_AN_EMPTY_HEADER_PHONE_IS_NOT_HIDDEN'
MutHeader '    Friend Shared Sub SetPhoneLink(ByVal link As HyperLink, ByVal literal As Literal, ByVal phone As String)
        If link Is Nothing OrElse literal Is Nothing Then
            Return
        End If
' '    Friend Shared Sub SetPhoneLink(ByVal link As HyperLink, ByVal literal As Literal, ByVal phone As String)
' 'H12' 'H12_THE_HEADER_PHONE_HAS_NO_NULL_GUARD'
MutHeader '    Friend Shared Sub SetMailLink(ByVal link As HyperLink, ByVal literal As Literal, ByVal email As String)
        If link Is Nothing OrElse literal Is Nothing Then
            Return
        End If
' '    Friend Shared Sub SetMailLink(ByVal link As HyperLink, ByVal literal As Literal, ByVal email As String)
' 'H13' 'H13_THE_HEADER_MAIL_HAS_NO_NULL_GUARD'
MutHeader '        link.NavigateUrl = KeepStoreContactLinks.BuildTelHref(cleanPhone)' '        Dim telHref As String = KeepStoreContactLinks.BuildTelHref(cleanPhone)
        If telHref.Length > 0 Then link.NavigateUrl = telHref' 'H16' 'H16_AN_OLD_HEADER_PHONE_HREF_SURVIVES_A_NOT_VALID_VALUE'
MutHeader '        link.NavigateUrl = KeepStoreContactLinks.BuildMailtoHref(cleanEmail)' '        Dim mailHref As String = KeepStoreContactLinks.BuildMailtoHref(cleanEmail)
        If mailHref.Length > 0 Then link.NavigateUrl = mailHref' 'H17' 'H17_AN_OLD_HEADER_MAIL_HREF_SURVIVES_A_NOT_VALID_VALUE'
MutHeader '        link.Visible = True
' '' 'H18' 'H18_A_HEADER_LINK_HIDDEN_BEFORE_STAYS_HIDDEN_WHEN_THE_VALUE_COMES_BACK'
MutHeader 'SetPhoneLink(hlSupportPhoneTop, litSupportPhoneTop, phone)' 'SetPhoneLink(hlSupportPhoneTop, litSupportPhoneTop, email)' 'H19' 'H19_THE_TOP_BAR_PHONE_SHOWS_THE_MAIL'
MutHeader 'SetMailLink(hlSupportEmailHeader, litSupportEmailHeader, email)' 'SetMailLink(hlSupportEmailHeader, litSupportEmailHeader, phone)' 'H14' 'H14_THE_HEADER_MAIL_SHOWS_THE_PHONE'
MutHeader 'SetPhoneLink(hlSupportPhoneHeader, litSupportPhoneHeader, phone)' 'SetPhoneLink(hlSupportPhoneHeader, litSupportPhoneHeader, email)' 'H15' 'H15_THE_HEADER_PHONE_SHOWS_THE_MAIL'

# piede e Contattaci
function MutFooter([string]$old, [string]$new, [string]$code, [string]$name) {
    $m = Mutate-Text $footer $old $new $code
    Assert-Detected (Test-FooterUses $m) $name
}
MutFooter 'Dim telHref As String = KeepStoreContactLinks.BuildTelHref(phoneText)' 'Dim telHref As String = "tel:" & phoneText' 'F01' 'F01_THE_FOOTER_PHONE_LINK_IS_BUILT_BY_HAND_AGAIN'
MutFooter 'Dim mailHref As String = KeepStoreContactLinks.BuildMailtoHref(emailText)' 'Dim mailHref As String = "mailto:" & emailText' 'F02' 'F02_THE_FOOTER_MAIL_LINK_IS_BUILT_BY_HAND_AGAIN'
MutFooter '    Friend Shared Function BuildCopyrightHtml(' '    Friend Shared Function BuildTelHref(ByVal phone As String) As String
        Return phone
    End Function

    Friend Shared Function BuildCopyrightHtml(' 'F03' 'F03_THE_FOOTER_HAS_ITS_OWN_COPY_OF_THE_VALIDATOR_AGAIN'
MutFooter '    Friend Shared Function BuildCopyrightHtml(' '    Private Shared ReadOnly MailPattern As New Regex("x")
    Friend Shared Function BuildCopyrightHtml(' 'F04' 'F04_THE_FOOTER_HAS_ITS_OWN_MAIL_PATTERN_AGAIN'
function MutContact([string]$old, [string]$new, [string]$code, [string]$name) {
    $m = Mutate-Text $contact $old $new $code
    Assert-Detected (Test-ContactUses $m) $name
}
MutContact 'view.TelHref = KeepStoreContactLinks.BuildTelHref(telefono)' 'view.TelHref = "tel:" & telefono' 'C01' 'C01_THE_CONTACT_PHONE_LINK_IS_BUILT_BY_HAND_AGAIN'
MutContact 'view.MailHref = KeepStoreContactLinks.BuildMailtoHref(mail)' 'view.MailHref = "mailto:" & mail' 'C02' 'C02_THE_CONTACT_MAIL_LINK_IS_BUILT_BY_HAND_AGAIN'
MutContact 'phoneLink.HRef = view.TelHref' 'If view.TelHref.Length > 0 Then phoneLink.HRef = view.TelHref' 'C03' 'C03_THE_CONTACT_PHONE_HREF_IS_SET_ONLY_WHEN_VALID_SO_AN_OLD_HREF_SURVIVES'
MutContact 'mailLink.HRef = view.MailHref' 'If view.MailHref.Length > 0 Then mailLink.HRef = view.MailHref' 'C04' 'C04_THE_CONTACT_MAIL_HREF_IS_SET_ONLY_WHEN_VALID_SO_AN_OLD_HREF_SURVIVES'
MutContact 'view.TelHref = KeepStoreContactLinks.BuildTelHref(telefono)' 'view.TelHref = KeepStoreContactLinks.BuildMailtoHref(telefono)' 'C05' 'C05_THE_CONTACT_PHONE_USES_THE_MAIL_VALIDATOR'
MutContact 'view.MailHref = KeepStoreContactLinks.BuildMailtoHref(mail)' 'view.MailHref = view.MapUrl' 'C06' 'C06_THE_CONTACT_MAIL_LINK_FALLS_BACK_TO_THE_MAP_AGAIN'
MutContact 'phoneLink.HRef = view.TelHref' 'phoneLink.HRef = view.MailHref' 'C07' 'C07_THE_CONTACT_PHONE_LINK_GETS_THE_MAIL_HREF'

Write-Output 'CONTACT_LINKS_ALL_PASS'
