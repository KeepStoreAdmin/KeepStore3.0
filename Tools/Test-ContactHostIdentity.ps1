[CmdletBinding()]
param()

# KS-B02C-CONTATTACI-HOST-1A - la pagina Contattaci legge nome, telefono, e-mail, logo e indirizzo SOLO dall'identita dell'host (nessuna sessione, nessuna connessione).
# Oracolo 1 (testo del codice, senza commenti): nessuna sessione ne database; l'azienda e quella dell'host; guardia 421; le stringhe fissate da altri test restano; ogni controllo usato
# nel codice esiste nel markup. Oracolo 2 (regione ContactPure compilata con /optionStrict+ INSIEME ai file della policy, dell'e-mail e del validatore condiviso dei link): stesso formato di prima (confronto con
# il blocco di formattazione ATTUALE incorporato qui, su 768 combinazioni), due aziende con marcatori disgiunti, profilo di un'altra azienda = nessun indirizzo, vista neutra, codifica
# dei testi e corpo reso dell'e-mail di contatto con il logo dell'azienda (percorso della sessione = logo predefinito, nome file + file esistente = logo proprio).
# I collegamenti tel: e mailto: vengono dal validatore condiviso (App_Code/KeepStoreContactLinks.vb): dato vuoto o non valido = nessun href (prima: ripiego sulla mappa); si assegnano SEMPRE (ApplyContactLinks). Confronti sensibili alle maiuscole (-ceq, -cne, -cmatch).
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

$vb = Read-Repo 'Contattaci.aspx.vb'
$aspx = Read-Repo 'Contattaci.aspx'
$policy = Read-Repo 'App_Code/StorefrontCanonicalHostPolicy.vb'
$emailSource = Read-Repo 'App_Code/KeepStoreEmailTemplate.vb'
$links = Read-Repo 'App_Code/KeepStoreContactLinks.vb'

# --- Oracolo 1: il markup non cambia e il collegamento del codice -----------------------------------------------------------------------------------
function Test-Markup([string]$text, [string]$aspxText) {
    foreach ($id in @('iframeMap', 'pnlAlert', 'lblAlert', 'txtNome', 'txtEmail', 'txtOggetto', 'txtMessaggio', 'btnInvia', 'lnkMap', 'litAddress', 'lnkPhone', 'litPhone', 'lnkEmail', 'litEmail')) {
        if ($aspxText -notmatch ('\bid="' + $id + '"') -and $aspxText -notmatch ('\bID="' + $id + '"')) { return $false }
    }
    # ogni controllo usato dal codice esiste nel markup (un controllo mancante non lo vede nessun altro test: la pagina darebbe errore al primo accesso)
    $used = @([regex]::Matches((Strip-Comments $text), '\b(lit|lnk|iframe|pnl|lbl|txt|rfv|btn|rev|cvl)[A-Z][A-Za-z0-9]*\b') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    if ($used.Count -lt 10) { return $false }
    foreach ($name in $used) {
        if ($aspxText -notmatch ('\b(?:id|ID)="' + [regex]::Escape($name) + '"')) { return $false }
    }
    return $true
}
Assert-Source (Test-Markup $vb $aspx) 'K01_THE_CONTACT_PAGE_USES_ONLY_CONTROLS_THAT_EXIST_IN_ITS_MARKUP'

function Test-Glue([string]$text) {
    $code = Strip-Comments $text
    # nessuna sessione, nessun database, nessun valore ricavato da richiesta o intestazioni, nessun blocco "e-mail vuota" (fissato da un altro test)
    foreach ($bad in @('MySqlConnection', 'MySqlCommand', 'MySqlDataReader', 'ConfigurationManager', 'SELECT ', 'AddWithValue', 'Request.Url', 'Request.Headers', 'Errore caricamento dati azienda',
                       'AziendaID', 'AziendaNome', 'AziendaEmail', 'AziendaLogo', 'IsPostBack', 'If aziendaEmail = ""')) {
        if ($code.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { return $false }
    }
    if ($code -cmatch '\bSession\b' -or $code -cmatch '\bS\(' -or $code -cmatch 'Private Function S\b') { return $false }
    if ($code -cnotmatch '(?s)Private Function ResolveContactTenant\(\) As StorefrontSeoTenantIdentity\s+Try\s+Return StorefrontSeoTenantContext\.Resolve\(HttpContext\.Current\)\s+Catch\s+Return Nothing') { return $false }
    if ([regex]::Matches($code, [regex]::Escape('Dim tenant As StorefrontSeoTenantIdentity = ResolveContactTenant()')).Count -ne 2) { return $false }
    if ([regex]::Matches($code, [regex]::Escape('If Response.StatusCode = 421 Then Return')).Count -ne 2) { return $false }
    foreach ($line in @('LoadCompanyInfo(tenant)', 'ApplySeoBasics(tenant)', 'Dim view As ContactView = BuildContactView(tenant)',
                        'litAddress.Text = view.AddressHtml', 'litPhone.Text = view.PhoneHtml', 'litEmail.Text = view.EmailHtml', 'lnkMap.HRef = view.MapUrl',
                        'iframeMap.Attributes("src") = view.MapEmbedUrl', 'ApplyContactLinks(lnkPhone, lnkEmail, view)',
                        'If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then', 'Dim aziendaId As Integer = tenant.CompanyId', '.AziendaId = aziendaId',
                        'RenderContactEmail(tenant, nome, fromEmailUser, oggetto, messaggio)',
                        'Dim brand As KeepStoreEmailBrandInfo = BuildContactBrand(tenant, BuildSiteHomeUrl(), EmailLogoFileExists(tenant))',
                        'Server.MapPath("~" & KeepStoreEmailLogo.LogoBasePath & fileName)', 'tenant.CompanyName.Trim()')) {
        if ($code.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    # stringhe fissate da altri test (Test-TenantEmailAllCallersMigration, Test-StorefrontSeoTechnical)
    foreach ($pin in @('New TenantEmailDeliveryService().Deliver(deliveryRequest)', 'ReplyToRecipients.Add', 'StorefrontSeoTenantContext.Resolve(HttpContext.Current)', 'CONTACT_EMAIL_FAILURE type=', 'TenantEmailMessageClassifications.ContactRequest')) {
        if ($code.IndexOf($pin, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if ($text -match '(?i)\b(taikun|webaffare|onsus|italcomed|ks_marea|panificiosa|miranda|newnda|tecind)\b' -or $text -match '(?i)x-forwarded-host') { return $false }
    return $true
}
Assert-Source (Test-Glue $vb) 'K02_THE_CONTACT_PAGE_READS_ONLY_THE_VERIFIED_HOST_IDENTITY_NO_SESSION_NO_DATABASE_AND_STOPS_ON_421'

# --- Oracolo 2: la regione ContactPure compilata (Strict) insieme alla policy e al file dell'e-mail --------------------------------------------------
function Get-PureRegion([string]$vbText) {
    $m = [regex]::Match($vbText, '(?ms)^[ \t]*#Region "ContactPure"\n(.*?)\n[ \t]*#End Region')
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
# il blocco di formattazione ATTUALE (PR #510, Contattaci.aspx.vb 82-126) con gli ingressi gia tagliati: l'oracolo di equivalenza
$legacyCode = @'
Public Class LegacyContact
    Public Shared Function Format(ByVal ragione As String, ByVal indirizzo As String, ByVal cap As String, ByVal citta As String, ByVal prov As String, ByVal telefono As String, ByVal email As String) As String()
        Dim line1 As String = indirizzo.Trim()
        If line1.Length > 200 Then line1 = line1.Substring(0, 200)
        Dim cityLine As String = (cap & " " & citta).Trim()
        If prov <> "" Then cityLine = (cityLine & " (" & prov & ")").Trim()
        Dim htmlAddress As String = ""
        If line1 <> "" Then htmlAddress = System.Web.HttpUtility.HtmlEncode(line1)
        If cityLine <> "" Then
            If htmlAddress <> "" Then
                htmlAddress &= "<br />" & System.Web.HttpUtility.HtmlEncode(cityLine)
            Else
                htmlAddress = System.Web.HttpUtility.HtmlEncode(cityLine)
            End If
        End If
        If String.IsNullOrWhiteSpace(htmlAddress) Then htmlAddress = System.Web.HttpUtility.HtmlEncode(ragione)
        Dim phoneHtml As String = System.Web.HttpUtility.HtmlEncode(If(String.IsNullOrWhiteSpace(telefono), "-", telefono))
        Dim emailHtml As String = System.Web.HttpUtility.HtmlEncode(If(String.IsNullOrWhiteSpace(email), "-", email))
        Dim addrForMap As String = (indirizzo & " " & cap & " " & citta & " " & prov).Trim()
        If addrForMap = "" Then addrForMap = ragione
        Dim mapQ As String = System.Web.HttpUtility.UrlEncode(addrForMap)
        Dim mapUrl As String = "https://www.google.com/maps?q=" & mapQ
        Dim mapEmbed As String = "https://www.google.com/maps?q=" & mapQ & "&output=embed"
        Dim telClean As String = telefono.Trim().Replace(" ", "").Replace(".", "").Replace("-", "")
        Dim telHref As String
        If telClean <> "" Then telHref = "tel:" & telClean Else telHref = mapUrl
        Dim mailHref As String
        If email.Trim() <> "" AndAlso email <> "-" Then mailHref = "mailto:" & email.Trim() Else mailHref = mapUrl
        Return New String() {htmlAddress, phoneHtml, emailHtml, mapUrl, mapEmbed, telHref, mailHref}
    End Function
End Class
'@
function Compile-Contact([string]$region, [string]$policyText, [string]$emailText, [string]$linksText) {
    $code = @"
Option Strict On
Option Explicit On
Imports System
Imports System.IO
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Public Class ContactProbe
$region
    Private Shared Function Make(ByVal id As Integer, ByVal name As String, ByVal phone As String, ByVal email As String, ByVal logo As String, ByVal profileId As Integer, ByVal f As String()) As StorefrontSeoTenantIdentity
        Dim t As StorefrontSeoTenantIdentity = StorefrontCanonicalHostPolicy.CreateTenant(id, name, "", "https://t" & id.ToString() & ".example.it", "", logo, 1)
        If t Is Nothing Then Return Nothing
        t.SupportPhone = phone
        t.SupportEmail = email
        If f IsNot Nothing Then t.LegalProfile = New StorefrontCompanyLegalProfile(profileId, f(0), f(1), f(2), f(3), f(4), f(5), f(6), f(7), f(8), f(9))
        Return t
    End Function
    Public Function View(ByVal id As Integer, ByVal name As String, ByVal phone As String, ByVal email As String, ByVal profileId As Integer, ByVal f As String()) As String()
        Dim t As StorefrontSeoTenantIdentity = Make(Math.Max(id, 1), name, phone, email, "", profileId, f)
        If id <= 0 Then t.GetType().GetProperty("CompanyId").SetValue(t, id, Nothing)
        Return Pack(BuildContactView(t))
    End Function
    Public Function ViewOfNothing() As String()
        Return Pack(BuildContactView(Nothing))
    End Function
    Private Shared Function Pack(ByVal v As ContactView) As String()
        Return New String() {v.AddressHtml, v.PhoneHtml, v.EmailHtml, v.MapUrl, v.MapEmbedUrl, v.TelHref, v.MailHref}
    End Function
    Private Shared Function Render(ByVal link As HtmlAnchor) As String
        Dim sw As New StringWriter()
        Dim hw As New HtmlTextWriter(sw)
        link.RenderControl(hw)
        hw.Flush()
        Return sw.ToString()
    End Function
    Public Function Anchors(ByVal phone1 As String, ByVal mail1 As String, ByVal phone2 As String, ByVal mail2 As String) As String()
        Dim phoneLink As New HtmlAnchor()
        Dim mailLink As New HtmlAnchor()
        ApplyContactLinks(phoneLink, mailLink, BuildContactView(Make(1, "ZZAalfa", phone1, mail1, "", 0, Nothing)))
        Dim first As String = phoneLink.HRef & "|" & mailLink.HRef
        ApplyContactLinks(phoneLink, mailLink, BuildContactView(Make(1, "ZZAalfa", phone2, mail2, "", 0, Nothing)))
        Return New String() {first, Render(phoneLink) & "|" & Render(mailLink)}
    End Function
    Public Function Cut(ByVal value As String, ByVal max As Integer) As String
        Return TrimToLen(value, max)
    End Function
    Public Function Mail(ByVal id As Integer, ByVal name As String, ByVal email As String, ByVal logo As String, ByVal logoExists As Boolean) As String
        Dim t As StorefrontSeoTenantIdentity = Make(id, name, "", email, logo, 0, Nothing)
        Dim brand As KeepStoreEmailBrandInfo = BuildContactBrand(t, "https://t" & id.ToString() & ".example.it/", logoExists)
        Dim r As KeepStoreEmailRenderResult = KeepStoreContactEmailMessages.RenderContactRequest(brand, "Mario", "m@cliente.example.it", "Oggetto", "Messaggio")
        Return r.HtmlBody
    End Function
End Class
$legacyCode
"@
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Web.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($policyText, $emailText, $linksText, $code))
    if ($c.Errors.HasErrors) { throw ('CONTACT_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return $c.CompiledAssembly
}
function Lg([string]$n, [string]$v, [string]$ra, [string]$rp, [string]$rc, [string]$rv, [string]$oa, [string]$op, [string]$oc, [string]$ov) { return , [string[]]@($n, $v, $ra, $rp, $rc, $rv, $oa, $op, $oc, $ov) }
function Show-Failure([string]$id, [string]$got) { if ($env:KS_CONTACT_TEST_VERBOSE) { Write-Host ('CONTACT_CASE_FAILED ' + $id + ' got=[' + $got + ']') } }
function Test-Behaviour([string]$vbText, [string]$policyText, [string]$emailText, [string]$linksText) {
    $region = Get-PureRegion $vbText
    if ($null -eq $region) { throw 'CONTACT_PURE_REGION_NOT_FOUND' }
    $asm = Compile-Contact $region $policyText $emailText $linksText
    $p = [Activator]::CreateInstance($asm.GetType('ContactProbe', $true))
    $map = 'https://www.google.com/maps?q='
    # due aziende con marcatori disgiunti; sede legale e operativa differiscono in OGNI campo (la pagina mostra la SEDE OPERATIVA)
    $profA = Lg 'ZZA Alfa Srl' '11111111111' 'ZZAvia Legale 9' '10199' 'ZZAcittaL' 'TO' 'ZZAvia Uno 1' '10100' 'ZZAcitta' 'MI'
    $profB = Lg 'ZZB Beta SpA' '22222222222' 'ZZBvia Legale 8' '20299' 'ZZBcittaL' 'PD' 'ZZBvia Due 2' '20200' 'ZZBcitta' 'VE'
    $viewA = $p.View(1, 'ZZAalfa', '+39 02 12.34-56 7', 'a@zza.example.it', 1, $profA)
    $expA = @('ZZAvia Uno 1<br />10100 ZZAcitta (MI)', '+39 02 12.34-56 7', 'a@zza.example.it', ($map + 'ZZAvia+Uno+1+10100+ZZAcitta+MI'), ($map + 'ZZAvia+Uno+1+10100+ZZAcitta+MI&output=embed'), 'tel:+39021234567', 'mailto:a@zza.example.it')
    for ($i = 0; $i -lt 7; $i++) { if ($viewA[$i] -cne $expA[$i]) { Show-Failure ('A' + $i) $viewA[$i]; return $false } }
    $viewB = $p.View(2, 'ZZBbeta', '', '', 2, $profB)
    $expB = @('ZZBvia Due 2<br />20200 ZZBcitta (VE)', '-', '-', ($map + 'ZZBvia+Due+2+20200+ZZBcitta+VE'), ($map + 'ZZBvia+Due+2+20200+ZZBcitta+VE&output=embed'), '', '')
    for ($i = 0; $i -lt 7; $i++) { if ($viewB[$i] -cne $expB[$i]) { Show-Failure ('B' + $i) $viewB[$i]; return $false } }
    if (($viewB -join '|') -cmatch 'ZZA|tel:|mailto:') { return $false }
    if (($p.View(1, 'ZZAalfa', '+39 02 12.34-56 7', 'a@zza.example.it', 1, $profA) -join '|') -cne ($viewA -join '|')) { return $false }
    # il profilo di un'altra azienda non si mostra: ripiego sul nome dell'azienda dell'host, mai un marcatore dell'altra
    foreach ($case in @(@(1, 'ZZAalfa', 2, $profB), @(1, 'ZZAalfa', 0, $profB), @(1, 'ZZAalfa', -1, $profB), @(2, 'ZZBbeta', 1, $profA))) {
        $x = $p.View($case[0], $case[1], '+39 02 1234567', 'x@y.example.it', $case[2], $case[3])
        if ($x[0] -cne $case[1] -or $x[3] -cne ($map + $case[1]) -or (($x -join '|') -cmatch 'ZZ[AB]via|ZZ[AB]citta|ZZ[AB] ')) { Show-Failure 'mismatch' ($x -join '|'); return $false }
    }
    # senza azienda valida dell'host: vista neutra, anche con nome, telefono, e-mail e profilo (id 0 e id negativo, identita assente)
    $neutral = @(@(0, 'ZZAalfa', '+39 02 1234567', 'a@zza.example.it', 0, $profA), @(-1, 'ZZAalfa', '+39 02 1234567', 'a@zza.example.it', -1, $profA))
    foreach ($case in $neutral) {
        $n = $p.View($case[0], $case[1], $case[2], $case[3], $case[4], $case[5])
        if ($n[0] -cne '' -or $n[1] -cne '-' -or $n[2] -cne '-' -or $n[3] -cne $map -or $n[4] -cne ($map + '&output=embed') -or $n[5] -cne '' -or $n[6] -cne '') { Show-Failure 'neutral' ($n -join '|'); return $false }
    }
    $n = $p.ViewOfNothing()
    if ($n[0] -cne '' -or $n[1] -cne '-' -or $n[2] -cne '-' -or $n[3] -cne $map -or $n[5] -cne '' -or $n[6] -cne '') { return $false }
    # ripiego: profilo senza indirizzo = ragione sociale; nessun profilo o ragione vuota = nome dell'azienda
    $r = $p.View(1, 'ZZAalfa', '', '', 1, (Lg 'ZZA Alfa Srl' '' '' '' '' '' '' '' '' ''))
    if ($r[0] -cne 'ZZA Alfa Srl' -or $r[3] -cne ($map + 'ZZA+Alfa+Srl')) { Show-Failure 'legalname' ($r -join '|'); return $false }
    $r = $p.View(1, 'ZZAalfa', '', '', 0, $null)
    if ($r[0] -cne 'ZZAalfa') { return $false }
    $r = $p.View(1, 'ZZAalfa', '', '', 1, (Lg '' '' '' '' '' '' '' '' '' ''))
    if ($r[0] -cne 'ZZAalfa') { return $false }
    # differenze VOLUTE rispetto a oggi: spazi attorno ai valori tolti; provincia di soli spazi senza parentesi
    $sp = $p.View(1, '  ZZAalfa  ', '  02 1234567  ', '  s@zza.example.it  ', 0, $null)
    if ($sp[0] -cne 'ZZAalfa' -or $sp[1] -cne '02 1234567' -or $sp[2] -cne 's@zza.example.it' -or $sp[5] -cne 'tel:021234567' -or $sp[6] -cne 'mailto:s@zza.example.it') { Show-Failure 'spaces' ($sp -join '|'); return $false }
    $pv = $p.View(1, 'N', '', '', 1, (Lg '' '' '' '' '' '' 'Via Roma 1' '20100' 'Milano' '   '))
    if ($pv[0] -cne 'Via Roma 1<br />20100 Milano') { Show-Failure 'blankprov' ($pv -join '|'); return $false }
    # equivalenza con il formato ATTUALE su 768 combinazioni (ingressi gia tagliati; ragione = nome non vuoto per escludere la differenza voluta)
    $legacy = $asm.GetType('LegacyContact', $true).GetMethod('Format')
    $streets = @('', 'Via Roma 1', ('V' * 250)); $caps = @('', '20100'); $cities = @('', 'Milano'); $provs = @('', 'MI'); $phones = @('', '081-771.83.26', '+39 081 7718326', '. -')
    $emails = @('', '-', 'a@b.it', 'x"y<script>@z'); $names = @('Alfa', 'N & <b>')
    # i collegamenti attesi dal validatore condiviso (niente ripiego sulla mappa, niente testo grezzo nell'href)
    $telExp = @{}; $telExp[''] = ''; $telExp['081-771.83.26'] = 'tel:0817718326'; $telExp['+39 081 7718326'] = 'tel:+390817718326'; $telExp['. -'] = ''
    $mailExp = @{}; $mailExp[''] = ''; $mailExp['-'] = ''; $mailExp['a@b.it'] = 'mailto:a@b.it'; $mailExp['x"y<script>@z'] = ''
    $count = 0
    foreach ($s in $streets) { foreach ($c in $caps) { foreach ($ci in $cities) { foreach ($pr in $provs) { foreach ($ph in $phones) { foreach ($em in $emails) { foreach ($nm in $names) {
        $got = $p.View(1, $nm, $ph, $em, 1, (Lg $nm '' '' '' '' '' $s $c $ci $pr))
        $exp = $legacy.Invoke($null, @($nm, $s, $c, $ci, $pr, $ph, $em))
        for ($i = 0; $i -lt 5; $i++) { if ($got[$i] -cne $exp[$i]) { Show-Failure ('equiv ' + $count + ' field ' + $i) ($got[$i] + ' <> ' + $exp[$i]); return $false } }
        if ($got[5] -cne $telExp[$ph] -or $got[6] -cne $mailExp[$em]) { Show-Failure ('equiv ' + $count + ' links') ($got[5] + ' | ' + $got[6]); return $false }
        $count++
    } } } } } } }
    if ($count -ne 768) { return $false }
    # codifica: testo codificato (indirizzo, nome, telefono, e-mail); query della mappa codificata; gli attributi li codifica il controllo del server
    $e = $p.View(1, '<script>alert(1)</script>', '"><img src=x onerror=1>', '<b>x</b>@y.it', 1, (Lg '<i>Ragione</i>' '' '' '' '' '' 'Via "Roma" & <b>1</b>' '2<0' 'Mi&lano' ''))
    if ((($e[0], $e[1], $e[2]) -join '|') -cmatch '<script|<img|<b>|<i>|"><') { return $false }
    if (-not $e[0].Contains('&quot;Roma&quot; &amp; &lt;b&gt;1&lt;/b&gt;') -or -not $e[1].Contains('&quot;&gt;&lt;img') -or -not $e[2].Contains('&lt;b&gt;x&lt;/b&gt;@y.it')) { return $false }
    if ($e[3] -cmatch '[<>" ]' -or $e[4] -cmatch '[<>" ]' -or -not $e[3].StartsWith($map + 'Via')) { return $false }
    if (-not $e[0].EndsWith('<br />2&lt;0 Mi&amp;lano')) { return $false }
    $lc = $p.View(1, 'N', '', '', 1, (Lg '' '' '' '' '' '' '' '2<0' 'Mi&lano' ''))
    if ($lc[0] -cne '2&lt;0 Mi&amp;lano') { return $false }
    $nf = $p.View(1, '<script>alert(1)</script>', '', '', 0, $null)
    if ($nf[0] -cne '&lt;script&gt;alert(1)&lt;/script&gt;') { return $false }
    $nn = $p.View(1, $null, $null, $null, 1, (New-Object 'string[]' 10))
    if ($nn[0] -cne '' -or $nn[1] -cne '-' -or $nn[2] -cne '-') { return $false }
    if ($p.Cut(('x' * 205), 200).Length -ne 200 -or $p.Cut($null, 5) -cne '' -or $p.Cut('  ab  ', 5) -cne 'ab') { return $false }
    # e-mail di contatto: marchio, e-mail di supporto e logo dell'identita dell'host nel corpo reso; mai quelli di un'altra azienda; file mancante = logo predefinito
    $mailA = $p.Mail(1, 'ZZAalfa', 'sup@zza.example.it', 'zza.png', $true)
    $mailB = $p.Mail(2, 'ZZBbeta', 'sup@zzb.example.it', 'zzb.png', $true)
    $mailMissing = $p.Mail(1, 'ZZAalfa', 'sup@zza.example.it', 'zza.png', $false)
    $mailPath = $p.Mail(1, 'ZZAalfa', 'sup@zza.example.it', '/Public/assets/images/logo/zza.png', $true)
    if (-not $mailA.Contains('https://t1.example.it/Public/assets/images/logo/zza.png') -or -not $mailA.Contains('ZZAalfa') -or -not $mailA.Contains('sup@zza.example.it') -or $mailA.Contains('logo.svg') -or $mailA -cmatch 'ZZB|zzb') { Show-Failure 'mailA' $mailA; return $false }
    if (-not $mailB.Contains('https://t2.example.it/Public/assets/images/logo/zzb.png') -or -not $mailB.Contains('ZZBbeta') -or -not $mailB.Contains('sup@zzb.example.it') -or $mailB -cmatch 'ZZA|zza') { return $false }
    if ($mailMissing.Contains('zza.png') -or -not $mailMissing.Contains('/Public/assets/images/logo/logo.svg')) { Show-Failure 'mailMissing' $mailMissing; return $false }
    if ($mailPath.Contains('zza.png') -or -not $mailPath.Contains('/Public/assets/images/logo/logo.svg')) { Show-Failure 'mailPath' $mailPath; return $false }
    # i collegamenti si assegnano SEMPRE (la pagina rilegge i dati a ogni richiesta e gli attributi vivono nel ViewState): un href di prima non sopravvive a un dato vuoto o non valido.
    # Tra le due assegnazioni NON si rende il controllo (la resa di HtmlAnchor consuma l'attributo href): si legge la proprieta, come fa il ViewState prima della richiesta successiva.
    $okP = '+39 02 1234567'; $okM = 'a@zza.example.it'
    $an = $p.Anchors($okP, $okM, 'dalle 9 alle 18', 'x@y.it?bcc=z@z.it')
    if ($an[0] -cne 'tel:+39021234567|mailto:a@zza.example.it' -or $an[1] -cne '<a></a>|<a></a>') { Show-Failure 'anchors valid-invalid' ($an -join ' / '); return $false }
    $an = $p.Anchors($okP, $okM, '', '')
    if ($an[1] -cne '<a></a>|<a></a>') { Show-Failure 'anchors valid-empty' ($an -join ' / '); return $false }
    $an = $p.Anchors('', '', $okP, $okM)
    if ($an[0] -cne '|' -or $an[1] -cne '<a href="tel:+39021234567"></a>|<a href="mailto:a@zza.example.it"></a>') { Show-Failure 'anchors empty-valid' ($an -join ' / '); return $false }
    $an = $p.Anchors($okP, $okM, '081 123456', 'b@zzb.example.it')
    if ($an[1] -cne '<a href="tel:081123456"></a>|<a href="mailto:b@zzb.example.it"></a>') { Show-Failure 'anchors valid-valid' ($an -join ' / '); return $false }
    return $true
}
Assert-Source (Test-Behaviour $vb $policy $emailSource $links) 'K03_THE_REAL_CONTACT_CODE_SHOWS_ONLY_THE_HOST_COMPANY_KEEPS_TODAYS_FORMAT_AND_SENDS_THE_COMPANY_LOGO'

# --- Mutazioni (copie in memoria) -------------------------------------------------------------------------------------------------------------------
function Test-AllCode([string]$text) { return ((Test-Behaviour $text $policy $emailSource $links) -and (Test-Glue $text) -and (Test-Markup $text $aspx)) }
function MutCode([string]$old, [string]$new, [string]$code, [string]$name) {
    $m = Mutate-Text $vb $old $new $code
    Assert-Detected (Test-AllCode $m) $name
}

# collegamento
MutCode '        Me.Title = "Contattaci"' '        Me.Title = "Contattaci"
        Dim sessionName As String = Convert.ToString(Session("AziendaNome"))' 'M01' 'M01_THE_COMPANY_IS_READ_FROM_THE_SESSION_AGAIN'
MutCode '    Private Function ResolveContactTenant() As StorefrontSeoTenantIdentity' '    Private Function S(ByVal key As String) As String
        Return Convert.ToString(Session(key))
    End Function

    Private Function ResolveContactTenant() As StorefrontSeoTenantIdentity' 'M02' 'M02_THE_SESSION_HELPER_COMES_BACK'
MutCode '        Me.Title = "Contattaci"
        Dim tenant As StorefrontSeoTenantIdentity = ResolveContactTenant()
        LoadCompanyInfo(tenant)
        ApplySeoBasics(tenant)' '        If Not IsPostBack Then
            Me.Title = "Contattaci"
            Dim tenant As StorefrontSeoTenantIdentity = ResolveContactTenant()
            LoadCompanyInfo(tenant)
            ApplySeoBasics(tenant)
        End If' 'M03' 'M03_THE_CONTACTS_ARE_BOUND_ONLY_ON_THE_FIRST_REQUEST'
MutCode '        If Response.StatusCode = 421 Then Return
        Me.Title' '        Me.Title' 'M04' 'M04_THE_PAGE_LOADS_ON_A_REJECTED_HOST'
MutCode '        If Response.StatusCode = 421 Then Return
        pnlAlert.Visible = False' '        pnlAlert.Visible = False' 'M05' 'M05_A_MESSAGE_IS_SENT_ON_A_REJECTED_HOST'
MutCode 'Dim view As ContactView = BuildContactView(tenant)' 'Dim view As ContactView = BuildContactView(Nothing)' 'M06' 'M06_THE_VIEW_IS_BUILT_WITHOUT_THE_HOST_IDENTITY'
MutCode 'litPhone.Text = view.PhoneHtml' 'litPhone.Text = view.EmailHtml' 'M07' 'M07_THE_PHONE_CONTROL_SHOWS_THE_EMAIL'
MutCode 'ApplyContactLinks(lnkPhone, lnkEmail, view)' 'ApplyContactLinks(lnkEmail, lnkPhone, view)' 'M08' 'M08_THE_PHONE_AND_MAIL_LINKS_ARE_SWAPPED'
MutCode 'phoneLink.HRef = view.TelHref' 'phoneLink.HRef = view.MailHref' 'M08b' 'M08B_THE_PHONE_LINK_GETS_THE_MAIL_HREF'
MutCode 'mailLink.HRef = view.MailHref' 'mailLink.HRef = view.TelHref' 'M08c' 'M08C_THE_MAIL_LINK_GETS_THE_PHONE_HREF'
MutCode 'phoneLink.HRef = view.TelHref' 'If view.TelHref.Length > 0 Then phoneLink.HRef = view.TelHref' 'M08d' 'M08D_AN_OLD_PHONE_HREF_SURVIVES_A_VALUE_THAT_IS_NOT_VALID'
MutCode 'mailLink.HRef = view.MailHref' 'If view.MailHref.Length > 0 Then mailLink.HRef = view.MailHref' 'M08e' 'M08E_AN_OLD_MAIL_HREF_SURVIVES_A_VALUE_THAT_IS_NOT_VALID'
MutCode 'iframeMap.Attributes("src") = view.MapEmbedUrl' 'iframeMap.Attributes("src") = view.MapUrl' 'M09' 'M09_THE_MAP_FRAME_USES_THE_NON_EMBED_URL'
MutCode 'litAddress.Text = view.AddressHtml' 'litAddress.Text = view.PhoneHtml' 'M10' 'M10_THE_ADDRESS_CONTROL_SHOWS_THE_PHONE'
MutCode 'Dim brand As KeepStoreEmailBrandInfo = BuildContactBrand(tenant, BuildSiteHomeUrl(), EmailLogoFileExists(tenant))' 'Dim brand As KeepStoreEmailBrandInfo = BuildContactBrand(tenant, BuildSiteHomeUrl(), True)' 'M11' 'M11_THE_LOGO_FILE_IS_NEVER_CHECKED'
MutCode 'If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then' 'If tenant Is Nothing Then' 'M12' 'M12_A_MESSAGE_IS_SENT_FOR_AN_INVALID_COMPANY'
MutCode '.AziendaId = aziendaId' '.AziendaId = 1' 'M13' 'M13_THE_DELIVERY_COMPANY_IS_A_CONSTANT'
MutCode 'Dim aziendaId As Integer = tenant.CompanyId' 'Dim aziendaId As Integer = 1' 'M14' 'M14_THE_DELIVERY_COMPANY_ID_IS_A_CONSTANT'
MutCode 'tenant.CompanyName.Trim()' '"Shop"' 'M15' 'M15_THE_META_DESCRIPTION_NAME_IS_A_CONSTANT'
MutCode 'Return StorefrontSeoTenantContext.Resolve(HttpContext.Current)
        Catch
            Return Nothing' 'Return Nothing
        Catch
            Return Nothing' 'M16' 'M16_THE_HOST_IDENTITY_IS_NEVER_RESOLVED'
MutCode 'Server.MapPath("~" & KeepStoreEmailLogo.LogoBasePath & fileName)' 'Server.MapPath(KeepStoreEmailLogo.LogoBasePath & fileName)' 'M17' 'M17_THE_LOGO_FILE_IS_LOOKED_UP_OUTSIDE_THE_APPLICATION_ROOT'
# regione pura: marchio dell'e-mail
MutCode 'brand.CompanyName = tenant.CompanyName' 'brand.CompanyName = "Shop"' 'M20' 'M20_THE_EMAIL_BRAND_IS_A_CONSTANT'
MutCode 'brand.SupportEmail = tenant.SupportEmail' 'brand.SupportEmail = tenant.SupportPhone' 'M21' 'M21_THE_EMAIL_SUPPORT_ADDRESS_IS_THE_PHONE'
MutCode 'brand.LogoWeb = If(logoExists, KeepStoreEmailLogo.SafeLogoFileName(tenant.LogoFileName), KeepStoreEmailLogo.SafeLogoFileName(String.Empty))' 'brand.LogoWeb = KeepStoreEmailLogo.SafeLogoFileName(KeepStoreEmailLogo.LogoBasePath & tenant.LogoFileName)' 'M22' 'M22_THE_EMAIL_LOGO_IS_A_PATH_AGAIN_AND_FALLS_BACK_TO_THE_DEFAULT'
MutCode 'brand.LogoWeb = If(logoExists, KeepStoreEmailLogo.SafeLogoFileName(tenant.LogoFileName), KeepStoreEmailLogo.SafeLogoFileName(String.Empty))' 'brand.LogoWeb = KeepStoreEmailLogo.SafeLogoFileName(tenant.LogoFileName)' 'M23' 'M23_A_MISSING_LOGO_FILE_IS_USED_ANYWAY'
MutCode 'brand.LogoWeb = If(logoExists, KeepStoreEmailLogo.SafeLogoFileName(tenant.LogoFileName), KeepStoreEmailLogo.SafeLogoFileName(String.Empty))' 'brand.LogoWeb = KeepStoreEmailLogo.SafeLogoFileName(String.Empty)' 'M24' 'M24_THE_COMPANY_LOGO_IS_NEVER_USED'
MutCode 'brand.SiteUrl = siteUrl' 'brand.SiteUrl = "https://example.invalid/"' 'M25' 'M25_THE_EMAIL_SITE_URL_IS_A_CONSTANT'
# regione pura: vista
MutCode 'If tenant IsNot Nothing AndAlso tenant.CompanyId > 0 Then' 'If tenant IsNot Nothing Then' 'M30' 'M30_AN_IDENTITY_WITHOUT_A_COMPANY_SHOWS_DATA'
MutCode 'If legal IsNot Nothing AndAlso legal.CompanyId = tenant.CompanyId Then' 'If legal IsNot Nothing Then' 'M31' 'M31_THE_PROFILE_OF_ANOTHER_COMPANY_IS_SHOWN'
MutCode '                If legal.LegalName.Length > 0 Then ragione = legal.LegalName
' '' 'M32' 'M32_THE_LEGAL_NAME_IS_NEVER_USED_AS_THE_FALLBACK'
MutCode '        If String.IsNullOrWhiteSpace(htmlAddress) Then htmlAddress = HttpUtility.HtmlEncode(ragione)
' '' 'M33' 'M33_THERE_IS_NO_FALLBACK_TO_THE_NAME_WITHOUT_AN_ADDRESS'
MutCode 'htmlAddress = HttpUtility.HtmlEncode(line1)' 'htmlAddress = line1' 'M34' 'M34_THE_STREET_IS_NOT_ENCODED'
MutCode 'htmlAddress &= "<br />" & HttpUtility.HtmlEncode(cityLine)' 'htmlAddress &= "<br />" & cityLine' 'M35' 'M35_THE_CITY_LINE_IS_NOT_ENCODED'
MutCode 'htmlAddress = HttpUtility.HtmlEncode(cityLine)' 'htmlAddress = cityLine' 'M36' 'M36_A_LONE_CITY_LINE_IS_NOT_ENCODED'
MutCode 'If String.IsNullOrWhiteSpace(htmlAddress) Then htmlAddress = HttpUtility.HtmlEncode(ragione)' 'If String.IsNullOrWhiteSpace(htmlAddress) Then htmlAddress = ragione' 'M37' 'M37_THE_NAME_FALLBACK_IS_NOT_ENCODED'
MutCode 'view.PhoneHtml = HttpUtility.HtmlEncode(If(String.IsNullOrWhiteSpace(telefono), "-", telefono))' 'view.PhoneHtml = If(String.IsNullOrWhiteSpace(telefono), "-", telefono)' 'M38' 'M38_THE_PHONE_TEXT_IS_NOT_ENCODED'
MutCode 'view.EmailHtml = HttpUtility.HtmlEncode(If(String.IsNullOrWhiteSpace(mail), "-", mail))' 'view.EmailHtml = If(String.IsNullOrWhiteSpace(mail), "-", mail)' 'M39' 'M39_THE_EMAIL_TEXT_IS_NOT_ENCODED'
MutCode 'Dim mapQ As String = HttpUtility.UrlEncode(addrForMap)' 'Dim mapQ As String = addrForMap' 'M40' 'M40_THE_MAP_QUERY_IS_NOT_ENCODED'
MutCode 'view.MapEmbedUrl = "https://www.google.com/maps?q=" & mapQ & "&output=embed"' 'view.MapEmbedUrl = "https://www.google.com/maps?q=" & mapQ' 'M41' 'M41_THE_MAP_EMBED_PARAMETER_IS_MISSING'
MutCode 'If addrForMap = "" Then addrForMap = ragione' '' 'M42' 'M42_THE_MAP_HAS_NO_NAME_FALLBACK'
MutCode '        If s.Length > maxLen Then s = s.Substring(0, maxLen)
' '' 'M46' 'M46_THE_TEXT_IS_NOT_CUT_TO_THE_MAXIMUM_LENGTH'
MutCode 'TrimToLen(indirizzo, 200)' 'TrimToLen(indirizzo, 250)' 'M47' 'M47_THE_STREET_LIMIT_CHANGES'
MutCode 'htmlAddress &= "<br />" & HttpUtility.HtmlEncode(cityLine)' 'htmlAddress &= " " & HttpUtility.HtmlEncode(cityLine)' 'M48' 'M48_THE_ADDRESS_LINES_ARE_NOT_SEPARATED'
MutCode 'cityLine = (cityLine & " (" & prov & ")").Trim()' 'cityLine = (cityLine & " " & prov).Trim()' 'M49' 'M49_THE_PROVINCE_LOSES_ITS_PARENTHESES'
MutCode 'indirizzo = legal.OperationalAddress' 'indirizzo = legal.RegisteredAddress' 'M50' 'M50_THE_REGISTERED_STREET_IS_SHOWN_INSTEAD_OF_THE_OPERATIONAL_ONE'
MutCode 'cap = legal.OperationalPostalCode' 'cap = legal.RegisteredPostalCode' 'M51' 'M51_THE_REGISTERED_POSTAL_CODE_IS_SHOWN'
MutCode 'citta = legal.OperationalCity' 'citta = legal.RegisteredCity' 'M52' 'M52_THE_REGISTERED_CITY_IS_SHOWN'
MutCode 'prov = legal.OperationalProvince' 'prov = legal.RegisteredProvince' 'M53' 'M53_THE_REGISTERED_PROVINCE_IS_SHOWN'
MutCode 'view.TelHref = KeepStoreContactLinks.BuildTelHref(telefono)' 'view.TelHref = "tel:" & telefono' 'M54' 'M54_THE_PHONE_LINK_IS_BUILT_BY_HAND_AGAIN'
MutCode 'view.MailHref = KeepStoreContactLinks.BuildMailtoHref(mail)' 'view.MailHref = "mailto:" & mail.Trim()' 'M56' 'M56_THE_MAIL_LINK_IS_BUILT_BY_HAND_AGAIN'
MutCode 'view.TelHref = KeepStoreContactLinks.BuildTelHref(telefono)' 'view.TelHref = view.MapUrl' 'M55' 'M55_AN_EMPTY_PHONE_LINK_FALLS_BACK_TO_THE_MAP_AGAIN'
MutCode 'view.MailHref = KeepStoreContactLinks.BuildMailtoHref(mail)' 'view.MailHref = view.MapUrl' 'M57b' 'M57B_AN_EMPTY_MAIL_LINK_FALLS_BACK_TO_THE_MAP_AGAIN'
# (M57, il Trim del nome, e un mutante EQUIVALENTE: CreateTenant taglia gia il nome dell'identita; non si conta)
MutCode 'telefono = If(tenant.SupportPhone, String.Empty).Trim()' 'telefono = If(tenant.SupportPhone, String.Empty)' 'M58' 'M58_THE_PHONE_IS_NOT_TRIMMED'
MutCode 'mail = If(tenant.SupportEmail, String.Empty).Trim()' 'mail = If(tenant.SupportEmail, String.Empty)' 'M59' 'M59_THE_EMAIL_IS_NOT_TRIMMED'
MutCode 'telefono = If(tenant.SupportPhone, String.Empty).Trim()' 'telefono = If(tenant.SupportEmail, String.Empty).Trim()' 'M60' 'M60_THE_PHONE_IS_TAKEN_FROM_THE_EMAIL'
MutCode 'mail = If(tenant.SupportEmail, String.Empty).Trim()' 'mail = If(tenant.SupportPhone, String.Empty).Trim()' 'M61' 'M61_THE_EMAIL_IS_TAKEN_FROM_THE_PHONE'
# equivalenti dichiarati (non contati): SafeLogoFileName in Contattaci e ridondante con BuildLogoUrl (il test misura il corpo reso); il Trim dei valori del profilo
# e ridondante perche CreateLegalProfile li taglia gia.

Write-Output 'CONTACT_HOST_IDENTITY_ALL_PASS'
