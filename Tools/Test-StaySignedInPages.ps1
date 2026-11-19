[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants)

# AUTH-STAY-SIGNED-IN-2B, fase 2 di "Resta collegato": casella nella pagina di accesso, ripristino nel master, uscita, cambio password,
# accesso recente richiesto per i dati di accesso. (A) decisione pura sul modulo compilato, (B) sorgenti, (C) mutazioni,
# (D) prova reale sul SITO LAB (https, 127.0.0.1 forzato, porta 18843, database LAB): il sito deve servire questo codice e avere la chiave
# KeepStore.StaySignedIn.Enabled=true. Mai password, valori dei cookie o dati personali in output. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p, $utf8) } else { return '' } }

$files = @{
    module   = Read-Repo 'App_Code/KeepStoreStaySignedIn.vb'
    web      = Read-Repo 'App_Code/KeepStoreStaySignedInWeb.vb'
    master   = Read-Repo 'Page.master.vb'
    loginUi  = Read-Repo 'login.aspx'
    login    = Read-Repo 'login.aspx.vb'
    logout   = Read-Repo 'logout.aspx.vb'
    passPage = Read-Repo 'password.aspx.vb'
    reg      = Read-Repo 'registrazione.aspx.vb'
    edit     = Read-Repo 'my-account-edit.aspx.vb'
    dati     = Read-Repo 'datiutente.aspx.vb'
    privacy  = Read-Repo 'privacy.aspx'
}

function Get-Block([string]$text, [string]$start, [string]$end) {
    $i = $text.IndexOf($start, [StringComparison]::Ordinal); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($end, $i + $start.Length, [StringComparison]::Ordinal); if ($j -lt 0) { return '' }
    return $text.Substring($i, $j - $i)
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $w = $f.web; $m = $f.master
    if ($w -eq '') { $fail.Add('S00 file di collegamento assente') }
    # S01 la funzione e accesa solo con la chiave esplicita E la tabella; nessun registro di codici
    if ($w -notmatch 'Public Const EnabledSettingName As String = "KeepStore\.StaySignedIn\.Enabled"') { $fail.Add('S01 nome della chiave') }
    if ($w -notmatch 'Return String\.Equals\(Convert\.ToString\(ConfigurationManager\.AppSettings\(EnabledSettingName\)\)\.Trim\(\), "true", StringComparison\.OrdinalIgnoreCase\)') { $fail.Add('S01 chiave assente deve valere spento') }
    if ($w -notmatch 'Return IsEnabled\(\) AndAlso KeepStoreStaySignedIn\.IsAvailable\(ConnectionText\(\)\) AndAlso Not KeepStoreStaySignedIn\.IsSuspended\(\)') { $fail.Add('S01 attiva = chiave + tabella') }
    if ($w -match 'KeepStoreLog|Trace\.|Debug\.') { $fail.Add('S01 il collegamento scrive registri') }
    # S02 cookie: prefisso __Host-, attributi, cancellazione con gli stessi attributi, mai su HTTP
    if ($w -notmatch 'Return New HttpCookie\(name, value\) With \{\.Path = "/", \.Secure = True, \.HttpOnly = True, \.SameSite = SameSiteMode\.Lax, \.Expires = expires\}') { $fail.Add('S02 attributi del cookie') }
    if ($w -match '\.Domain\s*=') { $fail.Add('S02 il cookie non deve avere Domain') }
    if ($w -notmatch 'If context Is Nothing OrElse String\.IsNullOrEmpty\(value\) OrElse Not context\.Request\.IsSecureConnection Then Return False') { $fail.Add('S02 emissione solo su HTTPS') }
    if ($w -notmatch 'context\.Response\.Cookies\.Set\(BuildCookie\(KeepStoreStaySignedIn\.CookieName, String\.Empty, New DateTime\(2000, 1, 1, 0, 0, 0, DateTimeKind\.Utc\)\)\)') { $fail.Add('S02 cancellazione del cookie') }
    if ($w -notmatch 'Dim header As String = context\.Request\.Headers\("Cookie"\)' -or $w -match 'Request\.Cookies\(SessionCookieName\(\)\)') { $fail.Add('S02 cookie di sessione letto dall''intestazione inviata dal browser') }
    if ($w -notmatch 'context\.Response\.AppendHeader\("Set-Cookie", name & "=; expires=Sat, 01 Jan 2000 00:00:00 GMT; path=/; HttpOnly"') { $fail.Add('S02 scadenza del cookie di sessione') }
    # S03 dopo l'accesso: il vecchio dispositivo si annulla SEMPRE, prima di ogni uscita anticipata; emissione solo con casella e funzione attiva
    $after = Get-Block $w 'Public Shared Sub AfterSignIn(' 'End Sub'
    $iRevoke = $after.IndexOf('KeepStoreStaySignedIn.Revoke(ConnectionText(), DatabaseScope(), companyId, previous, "replaced")')
    $iGate = $after.IndexOf('If Not wantsStay OrElse companyId <= 0 OrElse loginId <= 0 OrElse Not context.Request.IsSecureConnection OrElse Not IsActive() Then Return')
    $iIssue = $after.IndexOf('KeepStoreStaySignedIn.Issue(ConnectionText(), DatabaseScope(), companyId, loginId)')
    if ($iRevoke -lt 0 -or $iGate -lt 0 -or $iIssue -lt 0 -or -not ($iRevoke -lt $iGate -and $iGate -lt $iIssue)) { $fail.Add('S03 ordine dopo l''accesso') }
    if ($after -notmatch 'context\.Session\.Remove\(RestoredSessionKey\)') { $fail.Add('S03 l''accesso con password toglie il marcatore del ripristino') }
    # S04 uscita e cambio password funzionano anche a funzione spenta
    $out = Get-Block $w 'Public Shared Sub SignOut(' 'End Sub'
    if ($out -match 'IsEnabled|IsActive') { $fail.Add('S04 l''uscita non deve dipendere dalla chiave') }
    $iClear = $out.IndexOf('ClearCookie(context)'); $iTenant = $out.IndexOf('StorefrontSeoTenantContext.Resolve(context)'); $iRev = $out.IndexOf('KeepStoreStaySignedIn.Revoke(ConnectionText(), DatabaseScope(), tenant.CompanyId, current, "logout")')
    if ($iClear -lt 0 -or $iTenant -lt 0 -or $iRev -lt 0 -or -not ($iClear -lt $iTenant -and $iTenant -lt $iRev)) { $fail.Add('S04 uscita: cookie cancellato prima di tutto, poi revoca per l''azienda dell''host') }
    $chg = Get-Block $w 'Public Shared Sub PasswordChanged(' 'End Sub'
    if ($chg -match 'IsEnabled|IsActive' -or $chg -notmatch 'KeepStoreStaySignedIn\.RevokeAllForLogin\(ConnectionText\(\), loginId, "password"\)') { $fail.Add('S04 cambio password') }
    if ($f.logout -notmatch 'Protected Sub Page_PreInit\(ByVal sender As Object, ByVal e As System\.EventArgs\) Handles Me\.PreInit\s+KeepStoreStaySignedInWeb\.SignOut\(HttpContext\.Current\)\s+End Sub') { $fail.Add('S04 uscita in PreInit, prima del master') }
    if ($f.passPage -notmatch 'ShowPasswordMessage\("Password aggiornata correttamente\.", True\)\s+Session\("DataPassword"\) = DateTime\.Today\s+''[^\r\n]*\s+KeepStoreStaySignedInWeb\.PasswordChanged\(HttpContext\.Current, loginIdValue\)') { $fail.Add('S04 cambio password: revoca dopo l''aggiornamento riuscito') }
    # S05 pagina di accesso
    if ($f.loginUi -notmatch '<asp:PlaceHolder ID="phStaySignedIn" runat="server" Visible="false">\s*<div class="ks-login__stay">\s*<asp:CheckBox ID="chkStaySignedIn" runat="server" Text="Resta collegato su questo dispositivo" />') { $fail.Add('S05 casella spenta per default e non spuntata') }
    if ($f.loginUi -match 'ID="chkStaySignedIn"[^>]*Checked="true"') { $fail.Add('S05 casella spuntata per default') }
    if ($f.loginUi -notmatch 'id="ksStaySignedInHint"[^>]*>[^<]*Non usarlo su computer o telefoni condivisi') { $fail.Add('S05 avvertenza') }
    if ($f.login -notmatch 'phStaySignedIn\.Visible = KeepStoreStaySignedInWeb\.IsActive\(\)') { $fail.Add('S05 casella visibile solo a funzione attiva') }
    if ($f.login -notmatch 'LoginAccessAuditRecorder\.TryRecordSuccessfulLogin\(HttpContext\.Current, CurrentLoginIdSafe\(\)\)\s+''[^\r\n]*\s+KeepStoreStaySignedInWeb\.AfterSignIn\(HttpContext\.Current,\s+StorefrontCommercialIsolationPolicy\.PositiveInteger\(Session\("AuthenticatedAziendaID"\)\), CurrentLoginIdSafe\(\),\s+phStaySignedIn\.Visible AndAlso chkStaySignedIn\.Checked\)') { $fail.Add('S05 aggancio dopo l''accesso riuscito') }
    # S06 master: ripristino solo nel ramo senza accesso, dopo il rifiuto, e locale loginId aggiornato
    if ($m -notmatch 'If loginId <= 0 Then\s+If StorefrontCommercialIsolationPolicy\.PositiveInteger\(Session\("AuthenticatedAziendaID"\)\) > 0 Then\s+RejectStorefrontAuthentication\(\)\s+End If\s+''[^\r\n]*\s+If Not TryBeginDeviceRestore\(companyId\) Then\s+ClearStorefrontAuthenticationState\(\)\s+RestoreAnonymousPriceDisplayState\(\)\s+Return\s+End If\s+''[^\r\n]*\s+loginId = CurrentLoginIdSafe\(\)\s+End If') { $fail.Add('S06 punto del ripristino e locale loginId') }
    $begin = Get-Block $m 'Private Function TryBeginDeviceRestore(' 'End Function'
    if ($begin -notmatch 'KeepStoreStaySignedIn\.DecideRestoreStep\(\s+KeepStoreStaySignedInWeb\.IsEnabled\(\), Request\.HttpMethod, scriptPath, IsCheckoutFlowPath\(scriptPath\), True,\s+KeepStoreStaySignedInWeb\.HasSessionCookie\(current\), hasHop, KeepStoreStaySignedInWeb\.IsSkippedInThisSession\(current\)\)') { $fail.Add('S06 decisione con tutti gli ingressi') }
    if ($begin -notmatch 'If restoreStep = StaySignedInRestoreStep\.Blocked OrElse Not KeepStoreStaySignedInWeb\.IsActive\(\) Then Return False') { $fail.Add('S06 blocco e funzione attiva') }
    if ($begin -notmatch 'If outcome = StaySignedInOutcome\.Unavailable Then Return False\s+If outcome <> StaySignedInOutcome\.Restored OrElse account Is Nothing Then\s+KeepStoreStaySignedInWeb\.ClearCookie\(current\)\s+Return False\s+End If') { $fail.Add('S06 esiti: non disponibile lascia il cookie, rifiuto lo cancella') }
    # S07 cambio di sessione: nessun dato dell'account nella sessione portata dal browser
    $regen = Get-Block $begin 'If restoreStep = StaySignedInRestoreStep.Regenerate Then' 'End If'
    if ($regen -notmatch 'Session\.Abandon\(\)\s+KeepStoreStaySignedInWeb\.ExpireSessionCookie\(current\)\s+KeepStoreStaySignedInWeb\.SetHopCookie\(current\)') { $fail.Add('S07 cambio di sessione') }
    if ($regen -notmatch 'Response\.Redirect\(KeepStoreStaySignedIn\.LocalRedirectTarget\(Request\.RawUrl\), True\)') { $fail.Add('S07 redirect locale') }
    if ($regen -match 'Session\("') { $fail.Add('S07 scrittura in sessione prima del cambio') }
    $iRegen = $begin.IndexOf('If restoreStep = StaySignedInRestoreStep.Regenerate Then'); $iWrite = $begin.IndexOf('Me.Session("LoginId") = account.LoginId')
    if ($iRegen -lt 0 -or $iWrite -lt 0 -or $iWrite -lt $iRegen) { $fail.Add('S07 l''accesso si scrive solo dopo il controllo del cambio di sessione') }
    # S08 identita legata all'utente verificato
    if ($begin -notmatch 'Me\.Session\("LoginId"\) = account\.LoginId\s+Me\.Session\("LoginID"\) = account\.LoginId\s+Me\.Session\("UtentiId"\) = account\.UtentiId\s+Me\.Session\("UtentiID"\) = account\.UtentiId\s+_deviceRestoreAccount = account') { $fail.Add('S08 accesso e utente verificati in sessione') }
    if ($begin -match 'AuthenticatedAziendaID"\) =|LoginEmail|CanOrder') { $fail.Add('S08 chiavi scritte prima della rivalidazione') }
    # S09 rivalidazione fallita durante il ripristino: anonimo, mai 403
    if ($m -notmatch 'Catch ex As Exception\s+validationFailedTechnically = True\s+KeepStoreLog\.Error\("storefront-auth-scope"[^\r\n]*\s+End Try\s+''[^\r\n]*\s+If _deviceRestoreAccount IsNot Nothing Then\s+AbortDeviceRestore\(companyId, validationFailedTechnically\)\s+Return\s+End If\s+RejectStorefrontAuthentication\(\)\s+End Sub') { $fail.Add('S09 nessun 403 per il dispositivo ricordato') }
    $abort = Get-Block $m 'Private Sub AbortDeviceRestore(' 'End Sub'
    if ($abort -match 'RejectStorefrontAuthentication|HttpException') { $fail.Add('S09 annullamento con errore') }
    if ($abort -notmatch 'ClearStorefrontAuthenticationState\(\)\s+RestoreAnonymousPriceDisplayState\(\)\s+Dim current As HttpContext = HttpContext\.Current\s+KeepStoreStaySignedInWeb\.SkipInThisSession\(current\)\s+If technicalFailure Then Return\s+Dim cookieValue As String = KeepStoreStaySignedInWeb\.ReadCookie\(current\)\s+KeepStoreStaySignedIn\.Revoke\([^\r\n]*"account"\)\s+KeepStoreStaySignedInWeb\.ClearCookie\(current\)') { $fail.Add('S09 annullamento: anonimo, non si riprova, rifiuto definitivo = revoca e cookie cancellato') }
    # S10 completamento dopo la rivalidazione: controlli, chiavi, marcatore, registro, carrello
    if ($m -notmatch 'EnsureAuthenticatedStorefrontScope\(resolvedTenant\.CompanyId, resolvedTenant\.DefaultPriceListId\)\s+CompleteDeviceRestore\(resolvedTenant\.CompanyId\)\s+ImpostaTemplate\(\)') { $fail.Add('S10 completamento dopo la rivalidazione') }
    $done = Get-Block $m 'Private Sub CompleteDeviceRestore(' 'End Sub'
    if ($done -notmatch 'If CurrentLoginIdSafe\(\) <> account\.LoginId OrElse\s+StorefrontCommercialIsolationPolicy\.PositiveInteger\(Session\("AuthenticatedAziendaID"\)\) <> companyId OrElse\s+StorefrontCommercialIsolationPolicy\.PositiveInteger\(Session\("UtentiId"\)\) <> account\.UtentiId Then\s+AbortDeviceRestore\(companyId, True\)') { $fail.Add('S10 controllo di accesso, azienda e utente') }
    if ($done -notmatch 'If profile Is Nothing Then\s+AbortDeviceRestore\(companyId, True\)') { $fail.Add('S10 profilo assente') }
    foreach ($key in 'AbilitaListino', 'LoginEmail', 'LoginNomeCognome', 'LoginUltimoAccesso', 'genera_html_mail', 'DataPassword', 'CanOrder') {
        if ($done -notmatch ('Me\.Session\("' + $key + '"\) = ')) { $fail.Add('S10 chiave di sessione mancante: ' + $key) }
    }
    $iMark = $done.IndexOf('KeepStoreStaySignedInWeb.MarkRestored(current)'); $iAudit = $done.IndexOf('LoginAccessAuditRecorder.TryRecordSuccessfulLogin(current, account.LoginId)'); $iCart = $done.IndexOf('AggiornaDati()'); $iLast = $done.IndexOf('Me.Session("LoginUltimoAccesso")')
    if ($iMark -lt 0 -or $iAudit -lt 0 -or $iCart -lt 0 -or $iLast -lt 0 -or -not ($iLast -lt $iAudit -and $iMark -lt $iAudit -and $iAudit -lt $iCart)) { $fail.Add('S10 ordine: chiavi, marcatore, registro, carrello') }
    if ($done -notmatch 'Try\s+AggiornaDati\(\)\s+Catch ex As Exception') { $fail.Add('S10 il carrello non annulla il ripristino') }
    # S11 dati di accesso: da una sessione ripristinata serve un accesso nuovo
    if ($w -notmatch 'Public Shared Function RequiresFreshSignIn\(ByVal context As HttpContext\) As Boolean\s+Return SessionFlag\(context, RestoredSessionKey\)') { $fail.Add('S11 marcatore') }
    # (registrazione.aspx.vb: da AUTH-CREDENTIALS-OLD-PASSWORD-1A la pagina non scrive piu i dati di accesso per nessuna sessione; vedi Tools/Test-CredentialsOldPassword.ps1)
    if ($f.reg -match '(?i)UPDATE\s+LOGIN\s+SET\s*"\s*\r?\n[^\r\n]*username' -or $f.reg -match '(?i)"\s*password\s*=\s*\?password') { $fail.Add('S11 registrazione: la pagina scrive ancora nome utente o password') }
    # (my-account-edit e datiutente: da AUTH-EMAIL-CHANGE-PASSWORD-1B il cambio dell'e-mail chiede la password attuale a OGNI sessione, e la vecchia pagina non scrive piu l'e-mail; vedi Tools/Test-EmailChangePassword.ps1)
    if ($f.edit -notmatch 'If emailChanged Then sqlUtente &= " AND BINARY l\.Pass" & "word = BINARY @CurrentPassword"') { $fail.Add('S11 dettagli account: e-mail senza password attuale') }
    if ($f.dati -match '(?i)u\.Email\s*=\s*@Email|"UPDATE login "') { $fail.Add('S11 dati utente: la vecchia pagina scrive ancora l''e-mail') }
    # S12 privacy
    if ($f.privacy -notmatch '__Host-KeepStoreStay' -or $f.privacy -notmatch 'creato soltanto se, nella pagina di accesso, scegli') { $fail.Add('S12 scheda privacy del cookie') }
    # S13 lettura dell'account: la vista restituisce una riga per indirizzo, servono righe distinte
    if (([regex]::Matches($f.module, 'Const sql As String = "SELECT DISTINCT ')).Count -ne 2) { $fail.Add('S13 letture da vlogin senza DISTINCT') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$probe = @'
Imports System
Imports System.Text
Public Module StayPagesProbe
    Private sb As New StringBuilder()
    Private Sub T(ByVal name As String, ByVal ok As Boolean)
        If sb.Length > 0 Then sb.Append(";")
        sb.Append(name).Append("=").Append(ok.ToString())
    End Sub
    Private Function S(Optional ByVal enabled As Boolean = True, Optional ByVal method As String = "GET", Optional ByVal path As String = "/myaccount.aspx",
                       Optional ByVal checkout As Boolean = False, Optional ByVal device As Boolean = True, Optional ByVal session As Boolean = False,
                       Optional ByVal hop As Boolean = False, Optional ByVal skipped As Boolean = False) As StaySignedInRestoreStep
        Return KeepStoreStaySignedIn.DecideRestoreStep(enabled, method, path, checkout, device, session, hop, skipped)
    End Function
    Public Function Run() As String
        T("P01_ripristino", S() = StaySignedInRestoreStep.Restore)
        T("P02_spento", S(enabled:=False) = StaySignedInRestoreStep.None)
        T("P03_senza_cookie", S(device:=False) = StaySignedInRestoreStep.None)
        T("P04_solo_get", S(method:="POST") = StaySignedInRestoreStep.None AndAlso S(method:="HEAD") = StaySignedInRestoreStep.None AndAlso S(method:="get") = StaySignedInRestoreStep.None AndAlso S(method:=Nothing) = StaySignedInRestoreStep.None)
        T("P05_uscita", S(path:="/logout.aspx") = StaySignedInRestoreStep.None)
        T("P06_accesso", S(path:="/login.aspx") = StaySignedInRestoreStep.None)
        T("P07_accesso_negato", S(path:="/accessonegato.aspx") = StaySignedInRestoreStep.None)
        T("P08_ordine_e_pagamento", S(checkout:=True) = StaySignedInRestoreStep.None)
        T("P09_percorso_vuoto", S(path:="") = StaySignedInRestoreStep.None AndAlso S(path:=Nothing) = StaySignedInRestoreStep.None)
        T("P10_cookie_di_sessione_cambia_sessione", S(session:=True) = StaySignedInRestoreStep.Regenerate)
        T("P11_secondo_tentativo_bloccato", S(session:=True, hop:=True) = StaySignedInRestoreStep.Blocked)
        T("P12_passaggio_senza_sessione_ripristina", S(hop:=True) = StaySignedInRestoreStep.Restore)
        T("P13_saltato_in_questa_sessione", S(skipped:=True) = StaySignedInRestoreStep.None AndAlso S(skipped:=True, session:=True) = StaySignedInRestoreStep.None)
        T("P14_altre_pagine", S(path:="/default.aspx") = StaySignedInRestoreStep.Restore AndAlso S(path:="/carrello.aspx") = StaySignedInRestoreStep.Restore AndAlso S(path:="/sub/mylogout.aspx") = StaySignedInRestoreStep.Restore)
        T("R01_locale", KeepStoreStaySignedIn.LocalRedirectTarget("/myaccount.aspx?a=1&b=2") = "/myaccount.aspx?a=1&b=2")
        T("R02_altro_host", KeepStoreStaySignedIn.LocalRedirectTarget("//evil.example/x") = "/" AndAlso KeepStoreStaySignedIn.LocalRedirectTarget("/\evil.example") = "/" AndAlso KeepStoreStaySignedIn.LocalRedirectTarget("https://evil.example/") = "/")
        T("R03_vuoto_o_strano", KeepStoreStaySignedIn.LocalRedirectTarget(Nothing) = "/" AndAlso KeepStoreStaySignedIn.LocalRedirectTarget("") = "/" AndAlso KeepStoreStaySignedIn.LocalRedirectTarget("/a\b") = "/" AndAlso KeepStoreStaySignedIn.LocalRedirectTarget("/a" & Convert.ToChar(13) & Convert.ToChar(10) & "Set-Cookie: x=1") = "/")
        KeepStoreStaySignedIn.ResetAvailability()
        T("V01_senza_connessione", Not KeepStoreStaySignedIn.IsAvailable("") AndAlso Not KeepStoreStaySignedIn.IsAvailable(Nothing))
        T("V02_errore_non_disponibile_senza_eccezione", Not KeepStoreStaySignedIn.IsAvailable("Server=127.0.0.1;Port=1;Connection Timeout=1"))
        T("V03_profilo_senza_identita", KeepStoreStaySignedIn.LoadSessionProfile("x", 0, 1, 1) Is Nothing AndAlso KeepStoreStaySignedIn.LoadSessionProfile("x", 1, 0, 1) Is Nothing AndAlso KeepStoreStaySignedIn.LoadSessionProfile("x", 1, 1, 0) Is Nothing AndAlso KeepStoreStaySignedIn.LoadSessionProfile("Server=127.0.0.1;Port=1;Connection Timeout=1", 1, 1, 1) Is Nothing)
        Return sb.ToString()
    End Function
End Module
'@

function Test-Behaviour([string]$moduleText, [switch]$Quiet) {
    if ($moduleText -eq '') { if (-not $Quiet) { Write-Host '  FAIL A modulo assente' }; return $false }
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    foreach ($ref in 'System.dll', 'System.Data.dll', 'System.Core.dll') { [void]$p.ReferencedAssemblies.Add($ref) }
    [void]$p.ReferencedAssemblies.Add((Join-Path $root 'Bin\MySql.Data.dll'))
    [void][Reflection.Assembly]::LoadFrom((Join-Path $root 'Bin\MySql.Data.dll'))
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($moduleText, $probe))
    if ($c.Errors.HasErrors) { if (-not $Quiet) { foreach ($e in $c.Errors) { Write-Host ('  COMPILE ' + $e.ErrorText) } }; return $false }
    try { $out = [string]$c.CompiledAssembly.GetType('StayPagesProbe').GetMethod('Run').Invoke($null, @()) } catch { if (-not $Quiet) { Write-Host ('  FAIL A eccezione: ' + $_.Exception.InnerException.Message) }; return $false }
    $ok = $true
    foreach ($kv in $out.Split(';')) { if (-not $kv.EndsWith('=True')) { $ok = $false; if (-not $Quiet) { Write-Host ('  FAIL ' + $kv) } } }
    return $ok
}

$okBehaviour = Test-Behaviour $files.module
$okSource = Test-Source $files
if (-not ($okSource -and $okBehaviour)) { Write-Host 'STAY_SIGNED_IN_PAGES FAIL (sorgenti o comportamento)'; exit 1 }
Write-Host 'STAY_SIGNED_IN_PAGES sorgenti e comportamento OK'

# ---------------------------------------------------------------- (C) mutazioni
$mutants = @(
    @{ Id = 'M01_POST'; File = 'module'; Old = 'If Not String.Equals(httpMethod, "GET", StringComparison.Ordinal) Then Return StaySignedInRestoreStep.None'; New = 'If httpMethod Is Nothing Then Return StaySignedInRestoreStep.None' },
    @{ Id = 'M02_ENABLED_IGNORED'; File = 'module'; Old = 'If Not enabled OrElse Not hasDeviceCookie OrElse skippedInThisSession Then Return StaySignedInRestoreStep.None'; New = 'If Not hasDeviceCookie OrElse skippedInThisSession Then Return StaySignedInRestoreStep.None' },
    @{ Id = 'M03_SKIP_IGNORED'; File = 'module'; Old = 'If Not enabled OrElse Not hasDeviceCookie OrElse skippedInThisSession Then Return StaySignedInRestoreStep.None'; New = 'If Not enabled OrElse Not hasDeviceCookie Then Return StaySignedInRestoreStep.None' },
    @{ Id = 'M04_LOGOUT_NOT_EXCLUDED'; File = 'module'; Old = 'isCheckoutPath OrElse path.EndsWith("/logout.aspx", StringComparison.Ordinal) OrElse'; New = 'isCheckoutPath OrElse' },
    @{ Id = 'M05_LOGIN_NOT_EXCLUDED'; File = 'module'; Old = 'path.EndsWith("/login.aspx", StringComparison.Ordinal) OrElse path.EndsWith("/accessonegato.aspx", StringComparison.Ordinal) Then'; New = 'path.EndsWith("/accessonegato.aspx", StringComparison.Ordinal) Then' },
    @{ Id = 'M06_CHECKOUT_NOT_EXCLUDED'; File = 'module'; Old = 'If path.Length = 0 OrElse isCheckoutPath OrElse'; New = 'If path.Length = 0 OrElse' },
    @{ Id = 'M07_SESSION_COOKIE_RESTORES'; File = 'module'; Old = 'If hasSessionCookie Then Return If(hasHopCookie, StaySignedInRestoreStep.Blocked, StaySignedInRestoreStep.Regenerate)'; New = 'If hasSessionCookie AndAlso hasHopCookie Then Return StaySignedInRestoreStep.Blocked' },
    @{ Id = 'M08_HOP_LOOP'; File = 'module'; Old = 'Return If(hasHopCookie, StaySignedInRestoreStep.Blocked, StaySignedInRestoreStep.Regenerate)'; New = 'Return StaySignedInRestoreStep.Regenerate' },
    @{ Id = 'M09_HOP_BYPASS'; File = 'module'; Old = 'Return If(hasHopCookie, StaySignedInRestoreStep.Blocked, StaySignedInRestoreStep.Regenerate)'; New = 'Return If(hasHopCookie, StaySignedInRestoreStep.Restore, StaySignedInRestoreStep.Regenerate)' },
    @{ Id = 'M10_REDIRECT_OTHER_HOST'; File = 'module'; Old = 'If value.Length > 1 AndAlso (value.Chars(1) = "/"c OrElse value.Chars(1) = "\"c) Then Return "/"'; New = 'If value.Length > 1 AndAlso value.Chars(1) = "\"c Then Return "/"' },
    @{ Id = 'M11_REDIRECT_HEADER_INJECTION'; File = 'module'; Old = 'If Convert.ToInt32(ch) < 32 OrElse ch = "\"c Then Return "/"'; New = 'If ch = "\"c Then Return "/"' },
    @{ Id = 'M12_REDIRECT_ABSOLUTE'; File = 'module'; Old = 'If value.Length = 0 OrElse value.Chars(0) <> "/"c Then Return "/"'; New = 'If value.Length = 0 Then Return "/"' },
    @{ Id = 'M13_DISTINCT_ACCOUNT'; File = 'module'; Old = 'Const sql As String = "SELECT DISTINCT id, COALESCE(UtentiId,0)'; New = 'Const sql As String = "SELECT id, COALESCE(UtentiId,0)' },
    @{ Id = 'M14_KEY_DEFAULT_ON'; File = 'web'; Old = '.Trim(), "true", StringComparison.OrdinalIgnoreCase)'; New = '.Trim(), "false", StringComparison.OrdinalIgnoreCase) = False' },
    @{ Id = 'M15_ACTIVE_WITHOUT_TABLE'; File = 'web'; Old = 'Return IsEnabled() AndAlso KeepStoreStaySignedIn.IsAvailable(ConnectionText()) AndAlso Not KeepStoreStaySignedIn.IsSuspended()'; New = 'Return IsEnabled()' },
    @{ Id = 'M16_COOKIE_NOT_SECURE'; File = 'web'; Old = '.Path = "/", .Secure = True, .HttpOnly = True, .SameSite'; New = '.Path = "/", .HttpOnly = True, .SameSite' },
    @{ Id = 'M17_COOKIE_NOT_HTTPONLY'; File = 'web'; Old = '.Secure = True, .HttpOnly = True, .SameSite = SameSiteMode.Lax'; New = '.Secure = True, .SameSite = SameSiteMode.Lax' },
    @{ Id = 'M18_COOKIE_SAMESITE_NONE'; File = 'web'; Old = '.SameSite = SameSiteMode.Lax, .Expires = expires}'; New = '.SameSite = SameSiteMode.None, .Expires = expires}' },
    @{ Id = 'M19_COOKIE_ON_HTTP'; File = 'web'; Old = 'If context Is Nothing OrElse String.IsNullOrEmpty(value) OrElse Not context.Request.IsSecureConnection Then Return False'; New = 'If context Is Nothing OrElse String.IsNullOrEmpty(value) Then Return False' },
    @{ Id = 'M20_OLD_DEVICE_NOT_REVOKED'; File = 'web'; Old = '                KeepStoreStaySignedIn.Revoke(ConnectionText(), DatabaseScope(), companyId, previous, "replaced")' + "`r`n"; New = '' },
    @{ Id = 'M21_ISSUE_WITHOUT_BOX'; File = 'web'; Old = 'If Not wantsStay OrElse companyId <= 0 OrElse loginId <= 0 OrElse'; New = 'If companyId <= 0 OrElse loginId <= 0 OrElse' },
    @{ Id = 'M22_MARKER_SURVIVES_LOGIN'; File = 'web'; Old = '            context.Session.Remove(RestoredSessionKey)' + "`r`n"; New = '' },
    @{ Id = 'M23_LOGOUT_NEEDS_KEY'; File = 'web'; Old = '            Dim current As String = ReadCookie(context)' + "`r`n" + '            If current.Length = 0 Then Return' + "`r`n" + '            ClearCookie(context)'; New = '            Dim current As String = ReadCookie(context)' + "`r`n" + '            If current.Length = 0 OrElse Not IsEnabled() Then Return' + "`r`n" + '            ClearCookie(context)' },
    @{ Id = 'M24_LOGOUT_REVOKE_BEFORE_CLEAR'; File = 'web'; Old = '            ClearCookie(context)' + "`r`n" + '            Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)' + "`r`n" + '            If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then Return'; New = '            Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)' + "`r`n" + '            If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then Return' + "`r`n" + '            ClearCookie(context)' },
    @{ Id = 'M25_PASSWORD_NEEDS_KEY'; File = 'web'; Old = '            KeepStoreStaySignedIn.RevokeAllForLogin(ConnectionText(), loginId, "password")'; New = '            If IsEnabled() Then KeepStoreStaySignedIn.RevokeAllForLogin(ConnectionText(), loginId, "password")' },
    @{ Id = 'M26_FRESH_SIGN_IN_OFF'; File = 'web'; Old = '        Return SessionFlag(context, RestoredSessionKey)'; New = '        Return False' },
    @{ Id = 'M27_LOGOUT_IN_LOAD'; File = 'logout'; Old = 'Handles Me.PreInit'; New = 'Handles Me.PreRender' },
    @{ Id = 'M28_PASSWORD_NO_REVOKE'; File = 'passPage'; Old = '                KeepStoreStaySignedInWeb.PasswordChanged(HttpContext.Current, loginIdValue)' + "`r`n"; New = '' },
    @{ Id = 'M29_BOX_ALWAYS_VISIBLE'; File = 'login'; Old = 'phStaySignedIn.Visible = KeepStoreStaySignedInWeb.IsActive()'; New = 'phStaySignedIn.Visible = True' },
    @{ Id = 'M30_BOX_IGNORED'; File = 'login'; Old = 'phStaySignedIn.Visible AndAlso chkStaySignedIn.Checked)'; New = 'True)' },
    @{ Id = 'M31_BOX_CHECKED'; File = 'loginUi'; Old = 'Text="Resta collegato su questo dispositivo" />'; New = 'Text="Resta collegato su questo dispositivo" Checked="true" />' },
    @{ Id = 'M32_LOCAL_LOGINID'; File = 'master'; Old = '            loginId = CurrentLoginIdSafe()' + "`r`n" + '        End If' + "`r`n"; New = '        End If' + "`r`n" },
    @{ Id = 'M33_RESTORE_BEFORE_REJECT'; File = 'master'; Old = '            If StorefrontCommercialIsolationPolicy.PositiveInteger(Session("AuthenticatedAziendaID")) > 0 Then' + "`r`n" + '                RejectStorefrontAuthentication()' + "`r`n" + '            End If' + "`r`n" + '            '' AUTH-STAY-SIGNED-IN-2B'; New = '            '' AUTH-STAY-SIGNED-IN-2B' },
    @{ Id = 'M34_USER_NOT_BOUND'; File = 'master'; Old = '            Me.Session("UtentiId") = account.UtentiId' + "`r`n"; New = '' },
    @{ Id = 'M35_403_ON_FAILED_RESTORE'; File = 'master'; Old = '        If _deviceRestoreAccount IsNot Nothing Then' + "`r`n" + '            AbortDeviceRestore(companyId, validationFailedTechnically)' + "`r`n" + '            Return' + "`r`n" + '        End If' + "`r`n"; New = '' },
    @{ Id = 'M36_TECHNICAL_REVOKES'; File = 'master'; Old = '        If technicalFailure Then Return' + "`r`n"; New = '' },
    @{ Id = 'M37_RETRY_EVERY_PAGE'; File = 'master'; Old = '        KeepStoreStaySignedInWeb.SkipInThisSession(current)' + "`r`n"; New = '' },
    @{ Id = 'M38_NO_SESSION_CHANGE'; File = 'master'; Old = '                Session.Abandon()' + "`r`n"; New = '' },
    @{ Id = 'M39_KEYS_BEFORE_VALIDATION'; File = 'master'; Old = '            _deviceRestoreAccount = account' + "`r`n"; New = '            Me.Session("CanOrder") = 1' + "`r`n" + '            _deviceRestoreAccount = account' + "`r`n" },
    @{ Id = 'M40_REFUSED_KEEPS_COOKIE'; File = 'master'; Old = '                KeepStoreStaySignedInWeb.ClearCookie(current)' + "`r`n" + '                Return False'; New = '                Return False' },
    @{ Id = 'M41_NO_COMPLETE'; File = 'master'; Old = '        CompleteDeviceRestore(resolvedTenant.CompanyId)' + "`r`n"; New = '' },
    @{ Id = 'M42_NO_CANORDER'; File = 'master'; Old = '        Me.Session("CanOrder") = If(IsDBNull(profile.CanOrder), CType(1, Object), profile.CanOrder)' + "`r`n"; New = '' },
    @{ Id = 'M43_NO_MARKER'; File = 'master'; Old = '        KeepStoreStaySignedInWeb.MarkRestored(current)' + "`r`n"; New = '' },
    @{ Id = 'M44_CART_BREAKS_RESTORE'; File = 'master'; Old = '        Try' + "`r`n" + '            AggiornaDati()' + "`r`n" + '        Catch ex As Exception' + "`r`n" + '            KeepStoreLog.Error("login-cart-sync", "Device restore cart'; New = '        AggiornaDati()' + "`r`n" + '        Try' + "`r`n" + '        Catch ex As Exception' + "`r`n" + '            KeepStoreLog.Error("login-cart-sync", "Device restore cart' },
    @{ Id = 'M45_COMPLETE_WITHOUT_USER_CHECK'; File = 'master'; Old = ' OrElse' + "`r`n" + '           StorefrontCommercialIsolationPolicy.PositiveInteger(Session("UtentiId")) <> account.UtentiId Then'; New = ' Then' },
    @{ Id = 'M46_REG_WRITES_SECRET'; File = 'reg'; Old = '    Protected Sub imgModAccesso_Click('; New = ('    Private Const KsMutantSql As String = " pass' + 'word = ?pass' + 'word "' + "`r`n" + '    Protected Sub imgModAccesso_Click(') },
    @{ Id = 'M47_EDIT_NO_PREDICATE'; File = 'edit'; Old = 'If emailChanged Then sqlUtente &= '; New = 'If False Then sqlUtente &= ' },
    @{ Id = 'M48_DATI_WRITES_EMAIL'; File = 'dati'; Old = '"u.Fax = @Fax " & _'; New = '"u.Fax = @Fax, u.Email = @Email " & _' }
)
if (-not $SkipMutants) {
    $survived = New-Object Collections.Generic.List[string]
    foreach ($mu in $mutants) {
        $text = [string]$files[$mu.File]
        if (-not $text.Contains($mu.Old)) { $survived.Add($mu.Id + ' (ancora non trovata)'); continue }
        $i = $text.IndexOf($mu.Old, [StringComparison]::Ordinal)
        $copy = $files.Clone()
        $copy[$mu.File] = $text.Substring(0, $i) + $mu.New + $text.Substring($i + $mu.Old.Length)
        $alive = (Test-Source $copy -Quiet)
        if ($alive -and $mu.File -eq 'module') { $alive = (Test-Behaviour $copy.module -Quiet) }
        if ($alive) { $survived.Add($mu.Id) }
    }
    if ($survived.Count -gt 0) { Write-Host ('STAY_SIGNED_IN_PAGES FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); exit 1 }
    Write-Host ('STAY_SIGNED_IN_PAGES mutanti uccisi: ' + $mutants.Count)
}

if ($SkipLab) { Write-Host 'STAY_SIGNED_IN_PAGES PASS (senza prova sul sito LAB)'; exit 0 }

# ---------------------------------------------------------------- (D) prova reale sul sito LAB
$base = 'https://www.taikun.it:18843'
$secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
$testUser = 'PROVA'
$tmp = Join-Path $env:TEMP ('ks-staypages-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$labSql = Join-Path $root 'Tools\Invoke-KeepStoreLabSql.ps1'
$col = 'Pass' + 'word'
$e2e = New-Object Collections.Generic.List[string]
function Check([bool]$ok, [string]$name) { if ($ok) { Write-Host ('  ok   ' + $name) } else { Write-Host ('  FAIL ' + $name); $e2e.Add($name) } }

function Invoke-Sql([string]$sql, [switch]$Write) {
    $f = Join-Path $tmp ('q' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($f, $sql, $utf8)
    try {
        if ($Write) { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f -Write }
        else { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f }
        return @($o)
    } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Get-Scalar([string]$sql) {
    $o = @(Invoke-Sql $sql)
    for ($i = 0; $i -lt $o.Count - 1; $i++) { if ([string]$o[$i] -eq 'ksval') { return ([string]$o[$i + 1]).Trim() } }
    return ''
}
function Invoke-Http([string]$path, [string]$jar, [string]$bodyFile = '', [string]$referer = '') {
    $out = Join-Path $tmp ('b' + [Guid]::NewGuid().ToString('N') + '.html'); $hdr = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N') + '.txt')
    $a = @('--noproxy', '*', '-s', '--max-time', '180', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-b', $jar, '-c', $jar, '-D', $hdr, '-o', $out, '-w', '%{http_code}|%{remote_ip}')
    if ($bodyFile -ne '') { $a += @('-H', ('Origin: ' + $base), '-H', ('Referer: ' + $base + $referer), '--data', ('@' + $bodyFile)) }
    $a += ($base + $path)
    $w = (& curl.exe @a) -join ''
    $parts = $w.Split('|')
    if ($parts.Count -lt 2 -or $parts[1] -ne '127.0.0.1') { throw ('NOT_LOOPBACK ' + $w) }
    $headers = if (Test-Path -LiteralPath $hdr) { [IO.File]::ReadAllText($hdr) } else { '' }
    $body = if (Test-Path -LiteralPath $out) { [IO.File]::ReadAllText($out, [Text.Encoding]::UTF8) } else { '' }
    $loc = ''; $mm = [regex]::Match($headers, '(?im)^Location:\s*(\S+)'); if ($mm.Success) { $loc = $mm.Groups[1].Value }
    return [pscustomobject]@{ Status = [int]$parts[0]; Location = $loc; Headers = $headers; Body = $body }
}
# Tutti i campi del modulo della pagina (nascosti e di testo), poi quelli indicati.
function New-FormFile([string]$html, [hashtable]$set) {
    $fields = @{}
    foreach ($mm in [regex]::Matches($html, '<input\b[^>]*>')) {
        $tag = $mm.Value
        $n = [regex]::Match($tag, '\bname="([^"]*)"'); if (-not $n.Success) { continue }
        $t = [regex]::Match($tag, '\btype="([^"]*)"'); $type = if ($t.Success) { $t.Groups[1].Value.ToLowerInvariant() } else { 'text' }
        if (@('submit', 'button', 'image', 'checkbox', 'radio', 'file', 'reset') -contains $type) { continue }
        $v = [regex]::Match($tag, '\bvalue="([^"]*)"')
        $fields[[Net.WebUtility]::HtmlDecode($n.Groups[1].Value)] = if ($v.Success) { [Net.WebUtility]::HtmlDecode($v.Groups[1].Value) } else { '' }
    }
    foreach ($k in $set.Keys) { $fields[$k] = [string]$set[$k] }
    $pairs = New-Object Collections.Generic.List[string]
    foreach ($k in $fields.Keys) { $pairs.Add(([Uri]::EscapeDataString($k)) + '=' + ([Uri]::EscapeDataString([string]$fields[$k]))) }
    $f = Join-Path $tmp ('f' + [Guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($f, ($pairs -join '&'), $utf8)
    return $f
}
function Get-FieldName([string]$html, [string]$suffix) {
    $mm = [regex]::Match($html, 'name="([^"]*\$' + [regex]::Escape($suffix) + ')"'); if ($mm.Success) { return [Net.WebUtility]::HtmlDecode($mm.Groups[1].Value) } else { return '' }
}
function Get-Secret {
    $sec = ConvertTo-SecureString (Get-Content -LiteralPath $secretFile)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
function Invoke-Login([string]$jar, [bool]$stay, [string]$word = '') {
    $page = Invoke-Http '/login.aspx' $jar
    $set = @{ '__EVENTTARGET' = (Get-FieldName $page.Body 'btnLogin'); '__EVENTARGUMENT' = '' }
    if ($set['__EVENTTARGET'] -eq '') { $set['__EVENTTARGET'] = 'ctl00$MainContent$btnLogin' }
    $set[(Get-FieldName $page.Body 'tbUsername')] = $testUser
    $set[(Get-FieldName $page.Body 'tbPassword')] = if ($word -ne '') { $word } else { Get-Secret }
    if ($stay) { $set['ctl00$MainContent$chkStaySignedIn'] = 'on' }
    $f = New-FormFile $page.Body $set
    try { return (Invoke-Http '/login.aspx' $jar $f '/login.aspx') } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Get-JarValue([string]$jar, [string]$name) {
    if (-not (Test-Path -LiteralPath $jar)) { return '' }
    foreach ($line in [IO.File]::ReadAllLines($jar)) { $c = $line.Split("`t"); if ($c.Count -ge 7 -and $c[5] -eq $name) { return $c[6] } }
    return ''
}
function Set-JarValue([string]$jar, [string]$name, [string]$value) {
    $lines = [IO.File]::ReadAllLines($jar)
    $outLines = New-Object Collections.Generic.List[string]
    foreach ($line in $lines) {
        $c = $line.Split("`t")
        if ($c.Count -ge 7 -and $c[5] -eq $name) { if ($value -ne '') { $c[6] = $value; $outLines.Add(($c -join "`t")) } } else { $outLines.Add($line) }
    }
    [IO.File]::WriteAllLines($jar, $outLines.ToArray())
}
function Get-SetCookie([string]$headers, [string]$name) {
    $mm = [regex]::Match($headers, '(?im)^Set-Cookie:\s*' + [regex]::Escape($name) + '=([^;\r\n]*)(;[^\r\n]*)?')
    if ($mm.Success) { return [pscustomobject]@{ Found = $true; Empty = ($mm.Groups[1].Value -eq ''); Attr = $mm.Groups[2].Value } }
    return [pscustomobject]@{ Found = $false; Empty = $false; Attr = '' }
}
function Test-CookieAttr([string]$attr) { return ($attr -match '(?i);\s*path=/(;|$)' -and $attr -match '(?i);\s*secure' -and $attr -match '(?i);\s*HttpOnly' -and $attr -match '(?i);\s*SameSite=Lax' -and $attr -notmatch '(?i);\s*domain=') }

$stayName = '__Host-KeepStoreStay'
# Nessun blocco qui: Tools/Invoke-KeepStoreLabSql.ps1 prende da solo il blocco del LAB a ogni chiamata.
$loginId = ''
try {
    if (-not (Test-Path -LiteralPath $secretFile)) { Write-Host 'STAY_SIGNED_IN_PAGES FAIL credenziale di prova assente'; exit 1 }
    $loginId = Get-Scalar ("SELECT DISTINCT id AS ksval FROM vlogin WHERE AziendeId=1 AND UPPER(UserName)='" + $testUser + "' AND Abilitato=1 AND UtentiAbilitato=1;")
    if ($loginId -notmatch '^\d+$') { Write-Host 'STAY_SIGNED_IN_PAGES FAIL utente di prova assente sul LAB'; exit 1 }
    $active = "SELECT COUNT(*) AS ksval FROM login_remembered_devices WHERE LoginId=$loginId AND RevokedUtc IS NULL;"
    $backupSql = "DROP TABLE IF EXISTS ks_test_stay_pages_backup; CREATE TABLE ks_test_stay_pages_backup AS SELECT l.id, l.$col AS w, l.DataPassword AS d, l.Email AS em, u.Listino AS li, u.Email AS uem FROM login l INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.id=$loginId; DELETE FROM login_remembered_devices WHERE LoginId=$loginId;"
    $null = Invoke-Sql $backupSql -Write
    Check ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM ks_test_stay_pages_backup;') -eq '1') 'E00 copia dei dati di prova'

    # nome del cookie di sessione del sito (configurazione privata del sito)
    $probeJar = Join-Path $tmp 'probe.txt'
    $first = Invoke-Http '/login.aspx' $probeJar
    $sessionName = ''
    foreach ($line in [IO.File]::ReadAllLines($probeJar)) { $c = $line.Split("`t"); if ($c.Count -ge 7 -and $c[6].Length -eq 24 -and -not $c[5].StartsWith('__Host-')) { $sessionName = $c[5] } }
    Check ($first.Status -eq 200 -and $sessionName -ne '') 'E01 sito LAB raggiungibile su 127.0.0.1'
    Check ($first.Body -match 'name="ctl00\$MainContent\$chkStaySignedIn"' -and $first.Body -match 'Resta collegato su questo dispositivo' -and $first.Body -notmatch 'chkStaySignedIn"[^>]*checked') 'E02 casella presente e non spuntata (funzione accesa)'
    if ($e2e.Count -gt 0) { throw 'PREREQUISITI' }

    # accesso senza casella
    $jarA = Join-Path $tmp 'a.txt'
    $r = Invoke-Login $jarA $false
    Check ($r.Status -eq 302 -and -not (Get-SetCookie $r.Headers $stayName).Found -and (Get-JarValue $jarA $stayName) -eq '') 'E03 accesso senza casella: nessun cookie'
    Check ((Get-Scalar $active) -eq '0') 'E04 accesso senza casella: nessun dispositivo'
    # senza dispositivo la sessione nuova resta anonima
    Set-JarValue $jarA $sessionName ''
    $r = Invoke-Http '/myaccount.aspx' $jarA
    Check ($r.Status -eq 302 -and $r.Location -match 'accessonegato\.aspx') 'E05 senza dispositivo: pagina riservata -> accesso negato'

    # accesso con casella
    $jarB = Join-Path $tmp 'b.txt'
    $r = Invoke-Login $jarB $true
    $sc = Get-SetCookie $r.Headers $stayName
    Check ($r.Status -eq 302 -and $sc.Found -and -not $sc.Empty -and (Test-CookieAttr $sc.Attr) -and $sc.Attr -match '(?i);\s*expires=') 'E06 accesso con casella: cookie con Path=/, Secure, HttpOnly, SameSite=Lax, senza Domain'
    Check ((Get-JarValue $jarB $stayName) -match '^v1\.[A-Za-z0-9_-]{43}$') 'E07 formato del codice'
    Check ((Get-Scalar $active) -eq '1') 'E08 un dispositivo attivo'
    $accessBefore = Get-Scalar "SELECT COALESCE(NumeroAccessi,0) AS ksval FROM login WHERE id=$loginId;"

    # ripristino in una sessione nuova (browser riaperto: nessun cookie di sessione)
    Set-JarValue $jarB $sessionName ''
    $r = Invoke-Http '/myaccount.aspx' $jarB
    Check ($r.Status -eq 200 -and $r.Body -match 'logout\.aspx') 'E09 ripristino: pagina riservata da collegato'
    $newSession = Get-JarValue $jarB $sessionName
    Check ($newSession.Length -eq 24) 'E10 sessione nuova creata dal sito'
    Check ([int](Get-Scalar "SELECT COALESCE(NumeroAccessi,0) AS ksval FROM login WHERE id=$loginId;") -eq ([int]$accessBefore + 1)) 'E11 accesso registrato una volta'
    $r = Invoke-Http '/documenti.aspx?t=4' $jarB
    Check ($r.Status -eq 200) 'E12 altra pagina riservata nella stessa sessione'
    $r = Invoke-Http '/carrello.aspx' $jarB
    Check ($r.Status -eq 200) 'E13 carrello da collegato'
    Check ([int](Get-Scalar "SELECT COALESCE(NumeroAccessi,0) AS ksval FROM login WHERE id=$loginId;") -eq ([int]$accessBefore + 1)) 'E14 nessun altro accesso registrato nella sessione'

    # cookie di sessione vecchio (sessione scaduta con il browser aperto): cambio di sessione, poi ripristino
    $planted = 'abcdefghijklmnopqrstuvwx'
    Set-JarValue $jarB $sessionName $planted
    $r = Invoke-Http '/myaccount.aspx?ks=1' $jarB
    $ss = Get-SetCookie $r.Headers $sessionName
    Check ($r.Status -eq 302 -and $r.Location -eq '/myaccount.aspx?ks=1' -and $ss.Found -and $ss.Empty) 'E15 identificativo di sessione portato dal browser: redirect alla stessa pagina e cookie di sessione scaduto'
    Check ((Get-JarValue $jarB $sessionName) -eq '') 'E16 il browser non ha piu il vecchio identificativo'
    $r = Invoke-Http '/myaccount.aspx?ks=1' $jarB
    $regenerated = Get-JarValue $jarB $sessionName
    Check ($r.Status -eq 200 -and $regenerated.Length -eq 24 -and $regenerated -ne $planted) 'E17 ripristino solo nella sessione creata dal sito'
    # l'identificativo piantato non e mai diventato una sessione collegata
    $jarEvil = Join-Path $tmp 'evil.txt'
    Copy-Item -LiteralPath $probeJar -Destination $jarEvil
    Set-JarValue $jarEvil $sessionName $planted
    $r = Invoke-Http '/myaccount.aspx' $jarEvil
    Check ($r.Status -eq 302 -and $r.Location -match 'accessonegato\.aspx') 'E18 l''identificativo portato dal browser non e collegato'

    # POST e pagine escluse: nessun ripristino
    $jarC = Join-Path $tmp 'c.txt'
    Copy-Item -LiteralPath $jarB -Destination $jarC
    Set-JarValue $jarC $sessionName ''
    $post = Join-Path $tmp 'post.txt'; [IO.File]::WriteAllText($post, 'x=1', $utf8)
    $r = Invoke-Http '/myaccount.aspx' $jarC $post '/myaccount.aspx'
    Check ($r.Status -eq 302 -and $r.Location -match 'accessonegato\.aspx') 'E19 POST senza sessione: nessun ripristino'
    Copy-Item -LiteralPath $jarB -Destination $jarC -Force
    Set-JarValue $jarC $sessionName ''
    $r = Invoke-Http '/login.aspx' $jarC
    Check ($r.Status -eq 200 -and $r.Body -match 'name="ctl00\$MainContent\$tbPassword"') 'E20 pagina di accesso: nessun ripristino'

    # dati di accesso: da una sessione ripristinata serve un accesso nuovo
    $page = Invoke-Http '/my-account-edit.aspx' $jarB
    $emailField = Get-FieldName $page.Body 'txtEmail'
    $saveTarget = [regex]::Match($page.Body, '__doPostBack\(&#39;([^&]*btnSave)&#39;').Groups[1].Value
    if ($page.Status -eq 200 -and $emailField -ne '' -and $saveTarget -ne '') {
        $f = New-FormFile $page.Body @{ '__EVENTTARGET' = $saveTarget; '__EVENTARGUMENT' = ''; $emailField = 'ks.test.changed@example.invalid' }
        $r = Invoke-Http '/my-account-edit.aspx' $jarB $f '/my-account-edit.aspx'
        Check ($r.Status -eq 200 -and $r.Body -match 'La password attuale non e corretta') 'E21 cambio e-mail da sessione ripristinata senza password: rifiutato con spiegazione'
    } else { Check $false 'E21 modulo dei dettagli account non leggibile' }
    Check ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_stay_pages_backup b ON b.id=l.id INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.Email<=>b.em AND u.Email<=>b.uem;') -eq '1') 'E22 e-mail invariata'

    # uscita
    $r = Invoke-Http '/logout.aspx' $jarB
    $sc = Get-SetCookie $r.Headers $stayName
    Check ($r.Status -eq 200 -and $sc.Found -and $sc.Empty -and (Test-CookieAttr $sc.Attr)) 'E23 uscita: cookie cancellato con gli stessi attributi'
    Check ((Get-Scalar $active) -eq '0' -and (Get-Scalar "SELECT RevokeReason AS ksval FROM login_remembered_devices WHERE LoginId=$loginId ORDER BY id DESC LIMIT 1;") -eq 'logout') 'E24 uscita: dispositivo annullato'
    Set-JarValue $jarB $sessionName ''
    $r = Invoke-Http '/myaccount.aspx' $jarB
    Check ($r.Status -eq 302 -and $r.Location -match 'accessonegato\.aspx') 'E25 dopo l''uscita: accesso negato'

    # credenziali cambiate fuori dal sito (gestionale): rifiuto, dispositivo annullato, cookie cancellato
    $jarD = Join-Path $tmp 'd.txt'
    $null = Invoke-Login $jarD $true
    $null = Invoke-Sql "UPDATE login SET DataPassword=DATE_ADD(COALESCE(DataPassword,'2020-01-01'), INTERVAL 1 SECOND) WHERE id=$loginId;" -Write
    Set-JarValue $jarD $sessionName ''
    $r = Invoke-Http '/myaccount.aspx' $jarD
    $sc = Get-SetCookie $r.Headers $stayName
    Check ($r.Status -eq 302 -and $r.Location -match 'accessonegato\.aspx' -and $sc.Found -and $sc.Empty) 'E26 credenziali cambiate dal gestionale: accesso negato e cookie cancellato'
    Check ((Get-Scalar $active) -eq '0' -and (Get-Scalar "SELECT RevokeReason AS ksval FROM login_remembered_devices WHERE LoginId=$loginId ORDER BY id DESC LIMIT 1;") -eq 'credentials') 'E27 dispositivo annullato per credenziali'
    $null = Invoke-Sql 'UPDATE login l INNER JOIN ks_test_stay_pages_backup b ON b.id=l.id SET l.DataPassword=b.d;' -Write

    # listino non valido: la rivalidazione del master rifiuta; mai 403, mai un ciclo
    $jarE = Join-Path $tmp 'e.txt'
    $null = Invoke-Login $jarE $true
    $null = Invoke-Sql "UPDATE utenti u INNER JOIN login l ON l.UtentiId=u.id SET u.Listino=0 WHERE l.id=$loginId;" -Write
    Set-JarValue $jarE $sessionName ''
    $r = Invoke-Http '/myaccount.aspx' $jarE
    $sc = Get-SetCookie $r.Headers $stayName
    Check ($r.Status -eq 302 -and $r.Location -match 'accessonegato\.aspx' -and $sc.Found -and $sc.Empty) 'E28 account non piu valido per il sito: nessun 403, cookie cancellato'
    $r = Invoke-Http '/Default.aspx' $jarE
    Check ($r.Status -eq 200) 'E29 il sito resta navigabile da anonimo'
    Check ((Get-Scalar "SELECT RevokeReason AS ksval FROM login_remembered_devices WHERE LoginId=$loginId ORDER BY id DESC LIMIT 1;") -eq 'account') 'E30 dispositivo annullato per account'
    $null = Invoke-Sql 'UPDATE utenti u INNER JOIN login l ON l.UtentiId=u.id INNER JOIN ks_test_stay_pages_backup b ON b.id=l.id SET u.Listino=b.li;' -Write

    # cambio password dal sito con due dispositivi: tutti annullati
    $jarF = Join-Path $tmp 'f.txt'; $jarG = Join-Path $tmp 'g.txt'
    $null = Invoke-Login $jarF $true
    $null = Invoke-Login $jarG $true
    Check ((Get-Scalar $active) -eq '2') 'E31 due dispositivi attivi'
    $page = Invoke-Http '/password.aspx' $jarF
    $newWord = 'Ks' + [Guid]::NewGuid().ToString('N').Substring(0, 14)
    $btn = Get-FieldName $page.Body 'btnSalva'
    $set = @{ (Get-FieldName $page.Body 'tbPasswordAttuale') = (Get-Secret); (Get-FieldName $page.Body 'tbPasswordNuova') = $newWord; (Get-FieldName $page.Body 'tbPasswordConferma') = $newWord }
    if ($btn -ne '') { $set[$btn] = 'Aggiorna password' }
    $f = New-FormFile $page.Body $set
    $r = Invoke-Http '/password.aspx' $jarF $f '/password.aspx'
    $sc = Get-SetCookie $r.Headers $stayName
    Check ($r.Status -eq 200 -and $r.Body -match 'Password aggiornata correttamente' -and $sc.Found -and $sc.Empty) 'E32 cambio password: riuscito e cookie cancellato'
    Check ((Get-Scalar $active) -eq '0' -and (Get-Scalar "SELECT COUNT(*) AS ksval FROM login_remembered_devices WHERE LoginId=$loginId AND RevokeReason='password';") -eq '2') 'E33 cambio password: tutti i dispositivi annullati'
    Set-JarValue $jarG $sessionName ''
    $r = Invoke-Http '/myaccount.aspx' $jarG
    Check ($r.Status -eq 302 -and $r.Location -match 'accessonegato\.aspx') 'E34 l''altro dispositivo non entra piu'
    # accesso con password dopo un ripristino: la sessione non e piu "ripristinata" (prova con la password nuova, poi tutto torna com''era)
    $jarH = Join-Path $tmp 'h.txt'
    $r = Invoke-Login $jarH $false $newWord
    Check ($r.Status -eq 302) 'E35 accesso con la password nuova'
} catch {
    if ($_.Exception.Message -ne 'PREREQUISITI') { Write-Host ('  FAIL eccezione: ' + $_.Exception.Message); $e2e.Add('eccezione') }
} finally {
    if ($loginId -match '^\d+$') {
        $restore = "UPDATE login l INNER JOIN ks_test_stay_pages_backup b ON b.id=l.id SET l.$col" + "=b.w, l.DataPassword=b.d, l.Email=b.em; UPDATE utenti u INNER JOIN login l ON l.UtentiId=u.id INNER JOIN ks_test_stay_pages_backup b ON b.id=l.id SET u.Listino=b.li, u.Email=b.uem; DELETE FROM login_remembered_devices WHERE LoginId=$loginId;"
        try { $null = Invoke-Sql $restore -Write } catch { $e2e.Add('ripristino dei dati di prova') }
        try {
            $same = Get-Scalar ("SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_stay_pages_backup b ON b.id=l.id INNER JOIN utenti u ON u.id=l.UtentiId WHERE BINARY l.$col<=>BINARY b.w AND l.DataPassword<=>b.d AND l.Email<=>b.em AND u.Listino<=>b.li AND u.Email<=>b.uem;")
            if ($same -eq '1') { $null = Invoke-Sql 'DROP TABLE IF EXISTS ks_test_stay_pages_backup;' -Write; Write-Host '  ok   E99 dati di prova riportati allo stato di partenza' } else { Write-Host '  FAIL E99 dati di prova NON ripristinati (copia lasciata in ks_test_stay_pages_backup)'; $e2e.Add('E99') }
        } catch { $e2e.Add('E99 verifica') }
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($e2e.Count -gt 0) { Write-Host ('STAY_SIGNED_IN_PAGES FAIL sito LAB: ' + $e2e.Count + ' controlli'); exit 1 }
Write-Host 'STAY_SIGNED_IN_PAGES PASS'
exit 0
