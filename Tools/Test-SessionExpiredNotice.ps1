[CmdletBinding()]
param([switch]$SkipSmoke)

# AUTH-SESSION-EXPIRED-NOTICE-1A. Chi perde la sessione (30 minuti di inattivita o riavvio del sito) su una pagina riservata deve leggere perche
# e poter accedere tornando dov'era: la pagina unica e accessonegato.aspx (titolo e testo nuovi, promessa di ritorno solo quando il ritorno
# esiste); preferiti e dettaglio ordine, che mandavano a home e lista, ora passano di li ricordando la pagina richiesta.
# (A) sorgenti, (B) mutazioni, (C) prova reale sul sito locale Smoke (https, 127.0.0.1 forzato, sola lettura, senza accesso). Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $root $rel), $utf8) }

$files = @{
    page   = Read-Repo 'accessonegato.aspx'
    code   = Read-Repo 'accessonegato.aspx.vb'
    wish   = Read-Repo 'wishlist.aspx.vb'
    detail = Read-Repo 'documentidettaglio.aspx.vb'
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $p = $f.page; $c = $f.code; $w = $f.wish; $d = $f.detail
    # A1 titolo e testo: non piu un errore, dice perche
    if ($p -match 'Accesso non consentito') { $fail.Add('A1 titolo di errore ancora presente') }
    if ($p -notmatch '<h1 id="ksAccessDeniedTitle" class="ks-auth-title h4 fw-semibold">Accedi per continuare</h1>') { $fail.Add('A1 titolo nuovo') }
    if ($p -notmatch 'la sessione &egrave; scaduta per inattivit&agrave; o per un aggiornamento del sito') { $fail.Add('A1 motivo della scadenza') }
    if ($p -notmatch 'Quello che non avevi ancora salvato va inserito di nuovo') { $fail.Add('A1 avviso sui dati non salvati') }
    # A2 la promessa di ritorno sta in un blocco spento per default e acceso solo dal codice
    if ($p -notmatch '<asp:PlaceHolder ID="phReturnPromise" runat="server" Visible="false">\s*<p class="body-text-3 mb-4">Dopo l''accesso tornerai alla pagina che stavi aprendo\.</p>\s*</asp:PlaceHolder>') { $fail.Add('A2 promessa di ritorno non condizionata') }
    if (([regex]::Matches($p, 'tornerai alla pagina')).Count -ne 1) { $fail.Add('A2 promessa di ritorno fuori dal blocco') }
    if ($c -notmatch 'Dim returnsToProtectedPage As Boolean = PostLoginReturnUrlPolicy\.IsProtectedDestination\(HttpContext\.Current, returnUrl\)\s+phReturnPromise\.Visible = returnsToProtectedPage') { $fail.Add('A2 visibilita non decisa dalla politica del ritorno') }
    if (([regex]::Matches($c, 'phReturnPromise\.Visible = ')).Count -ne 2 -or $c -notmatch 'phReturnPromise\.Visible = False') { $fail.Add('A2 senza ritorno la promessa non viene spenta') }
    if ($c -notmatch 'hlLogin\.NavigateUrl = PostLoginReturnUrlPolicy\.BuildLoginUrl\(HttpContext\.Current, returnUrl\)') { $fail.Add('A2 pulsante Accedi senza ritorno validato') }
    # A3 preferiti: identita assente = pagina ricordata e pagina unica, non la home
    if ($w -notmatch 'If Session\("UtentiId"\) < 1 Then\s+Session\("Page"\) = Me\.Request\.Url\.ToString\(\)\s+Response\.Redirect\("accessonegato\.aspx", True\)\s+End If') { $fail.Add('A3 preferiti senza pagina unica') }
    if ($w -match 'Response\.Redirect\("default\.aspx"\)') { $fail.Add('A3 preferiti ancora verso la home') }
    # A4 dettaglio ordine: senza identita pagina unica con l'ordine ricordato; per chi e collegato l'esito resta la lista
    if ($d -notmatch 'If Not AuthorizeDocumentRequest\(\) Then\s+If IsOrderIdentityMissing\(\) Then RequireSignInForDocument\(\) Else DenyDocumentAccess\(\)\s+End If') { $fail.Add('A4 dettaglio: scelta fra accesso richiesto e rifiuto') }
    if ($d -notmatch 'Private Function IsOrderIdentityMissing\(\) As Boolean\s+Return CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity\.IsComplete\s+End Function') { $fail.Add('A4 dettaglio: identita assente definita male') }
    if ($d -notmatch 'If GetRequestedDocumentId\(\) > 0 Then Session\("Page"\) = Me\.Request\.Url\.ToString\(\)\s+Response\.Redirect\(ResolveUrl\("~/accessonegato\.aspx"\), True\)') { $fail.Add('A4 dettaglio: pagina non ricordata o destinazione diversa') }
    if ($d -notmatch "' One terminal outcome for missing, invalid, foreign and unverifiable IDs\.\s+Response\.Redirect\(ResolveUrl\(""~/documenti\.aspx\?t=4""\), True\)") { $fail.Add('A4 dettaglio: esito per chi e collegato cambiato') }
    if (([regex]::Matches($d, 'RequireSignInForDocument\(\)')).Count -ne 2) { $fail.Add('A4 dettaglio: accesso richiesto usato fuori da OnInit') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

if (-not (Test-Source $files)) { Write-Host 'SESSION_EXPIRED_NOTICE FAIL'; exit 1 }

$nl = "`r`n"
$mutants = @(
    @{ Id = 'M01_OLD_TITLE'; File = 'page'; Old = '>Accedi per continuare</h1>'; New = '>Accesso non consentito</h1>' },
    @{ Id = 'M02_REASON_REMOVED'; File = 'page'; Old = 'la sessione &egrave; scaduta per inattivit&agrave; o per un aggiornamento del sito'; New = 'riprova' },
    @{ Id = 'M03_PROMISE_ALWAYS_VISIBLE'; File = 'page'; Old = '<asp:PlaceHolder ID="phReturnPromise" runat="server" Visible="false">'; New = '<asp:PlaceHolder ID="phReturnPromise" runat="server">' },
    @{ Id = 'M04_PROMISE_OUTSIDE_BLOCK'; File = 'page'; Old = 'Quello che non avevi ancora salvato va inserito di nuovo.'; New = 'Quello che non avevi ancora salvato va inserito di nuovo. Dopo l''accesso tornerai alla pagina richiesta.' },
    @{ Id = 'M05_PROMISE_FOR_ANY_RETURN'; File = 'code'; Old = 'Dim returnsToProtectedPage As Boolean = PostLoginReturnUrlPolicy.IsProtectedDestination(HttpContext.Current, returnUrl)'; New = 'Dim returnsToProtectedPage As Boolean = True' },
    @{ Id = 'M06_PROMISE_NOT_SWITCHED_OFF'; File = 'code'; Old = 'phReturnPromise.Visible = False'; New = 'phReturnPromise.Visible = True' },
    @{ Id = 'M07_LOGIN_WITHOUT_RETURN'; File = 'code'; Old = 'hlLogin.NavigateUrl = PostLoginReturnUrlPolicy.BuildLoginUrl(HttpContext.Current, returnUrl)'; New = 'hlLogin.NavigateUrl = PostLoginReturnUrlPolicy.BuildLoginUrl(HttpContext.Current, Nothing)' },
    @{ Id = 'M08_WISHLIST_HOME_AGAIN'; File = 'wish'; Old = 'Response.Redirect("accessonegato.aspx", True)'; New = 'Response.Redirect("default.aspx")' },
    @{ Id = 'M09_WISHLIST_PAGE_NOT_REMEMBERED'; File = 'wish'; Old = "Session(`"Page`") = Me.Request.Url.ToString()$nl"; New = '' },
    @{ Id = 'M10_DETAIL_ALWAYS_LIST'; File = 'detail'; Old = 'If IsOrderIdentityMissing() Then RequireSignInForDocument() Else DenyDocumentAccess()'; New = 'DenyDocumentAccess()' },
    @{ Id = 'M11_DETAIL_SIGNIN_FOR_FOREIGN_DOCUMENT'; File = 'detail'; Old = 'If IsOrderIdentityMissing() Then RequireSignInForDocument() Else DenyDocumentAccess()'; New = 'RequireSignInForDocument()' },
    @{ Id = 'M12_DETAIL_IDENTITY_TEST_WEAK'; File = 'detail'; Old = 'Return CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity.IsComplete'; New = 'Return CurrentOrderIdentity Is Nothing' },
    @{ Id = 'M13_DETAIL_PAGE_NOT_REMEMBERED'; File = 'detail'; Old = 'If GetRequestedDocumentId() > 0 Then Session("Page") = Me.Request.Url.ToString()'; New = '' },
    @{ Id = 'M14_DETAIL_REMEMBERS_INVALID_ID'; File = 'detail'; Old = 'If GetRequestedDocumentId() > 0 Then Session("Page") = Me.Request.Url.ToString()'; New = 'Session("Page") = Me.Request.Url.ToString()' },
    @{ Id = 'M15_DETAIL_FOREIGN_OUTCOME_CHANGED'; File = 'detail'; Old = 'Response.Redirect(ResolveUrl("~/documenti.aspx?t=4"), True)'; New = 'Response.Redirect(ResolveUrl("~/accessonegato.aspx"), True)' }
)
$bad = 0
foreach ($mu in $mutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'SESSION_EXPIRED_NOTICE FAIL (mutanti)'; exit 1 }

# ---- (C) sito locale Smoke: visitatore senza accesso, sola lettura ----
$smokeNote = 'Smoke saltato'
if (-not $SkipSmoke) {
    $curl = Join-Path $env:WINDIR 'System32\curl.exe'
    $siteHost = 'www.taikun.it'; $port = 8443; $base = 'https://' + $siteHost + ':' + $port + '/'
    $up = $false
    try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', $port); $up = $t.Connected; $t.Close() } catch { $up = $false }
    if (-not ($up -and (Test-Path -LiteralPath $curl))) { $smokeNote = 'sito locale non disponibile: parte (C) NON ESEGUITA' }
    else {
        $work = Join-Path $env:TEMP ('ks-sessnotice-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        $sfail = New-Object Collections.Generic.List[string]
        try {
            function Get-Page([string]$jar, [string]$path, [switch]$Follow) {
                $out = Join-Path $work ([Guid]::NewGuid().ToString('N') + '.html')
                $curlArgs = @('--noproxy', '*', '--resolve', ($siteHost + ':' + $port + ':127.0.0.1'), '-s', '-S', '--max-time', '120', '-b', $jar, '-c', $jar, '-o', $out, '-w', '%{http_code}|%{remote_ip}|%{url_effective}|%{redirect_url}')
                if ($Follow) { $curlArgs += @('-L', '--max-redirs', '4') }
                $curlArgs += ($base + $path)
                $meta = & $curl @curlArgs 2>$null
                $body = if (Test-Path -LiteralPath $out) { [IO.File]::ReadAllText($out, $utf8) } else { '' }
                return @{ Meta = [string]$meta; Body = $body }
            }
            $cases = @(
                @{ Name = 'account'; Path = 'myaccount.aspx'; Return = 'myaccount.aspx' },
                @{ Name = 'preferiti'; Path = 'wishlist.aspx'; Return = 'wishlist.aspx' },
                @{ Name = 'dettaglio ordine'; Path = 'documentidettaglio.aspx?id=169284'; Return = 'documentidettaglio.aspx%3fid%3d169284' }
            )
            foreach ($case in $cases) {
                $jar = Join-Path $work ([Guid]::NewGuid().ToString('N') + '.txt')
                $first = Get-Page $jar $case.Path
                $parts = $first.Meta.Split('|')
                if ($parts.Count -lt 4 -or $parts[1] -ne '127.0.0.1') { $sfail.Add($case.Name + ': richiesta non locale'); continue }
                if ($parts[0] -ne '302' -or $parts[3] -notmatch '/accessonegato\.aspx$') { $sfail.Add($case.Name + ': non porta alla pagina unica (' + $parts[0] + ' ' + $parts[3] + ')'); continue }
                $page = Get-Page $jar 'accessonegato.aspx'
                if ($page.Meta -notmatch '^200\|127\.0\.0\.1\|') { $sfail.Add($case.Name + ': pagina unica non 200'); continue }
                $b = $page.Body
                if ($b -notmatch 'Accedi per continuare' -or $b -match 'Accesso non consentito') { $sfail.Add($case.Name + ': titolo') }
                if ($b -notmatch 'la sessione &egrave; scaduta per inattivit&agrave; o per un aggiornamento del sito') { $sfail.Add($case.Name + ': motivo') }
                if ($b -notmatch 'Dopo l(&#39;|'')accesso tornerai alla pagina che stavi aprendo') { $sfail.Add($case.Name + ': promessa di ritorno assente') }
                $m = [regex]::Match($b, '<a id="[^"]*hlLogin"[^>]*href="([^"]+)"')
                if (-not $m.Success) { $sfail.Add($case.Name + ': pulsante Accedi assente') }
                else {
                    $href = [Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
                    if ($href -notmatch 'login\.aspx\?ReturnUrl=' -or $href.ToLowerInvariant().IndexOf($case.Return.ToLowerInvariant()) -lt 0) { $sfail.Add($case.Name + ': Accedi senza ritorno alla pagina (' + $href + ')') }
                }
            }
            # aperta direttamente, da un visitatore nuovo: nessuna promessa di ritorno
            $jarDirect = Join-Path $work 'direct.txt'
            $direct = Get-Page $jarDirect 'accessonegato.aspx'
            if ($direct.Meta -notmatch '^200\|127\.0\.0\.1\|' -or $direct.Body -notmatch 'Accedi per continuare') { $sfail.Add('diretta: pagina non servita') }
            if ($direct.Body -match 'tornerai alla pagina che stavi aprendo') { $sfail.Add('diretta: promette un ritorno che non esiste') }
            # ritorno esterno o tecnico: non entra nel pulsante
            $jarEvil = Join-Path $work 'evil.txt'
            $evil = Get-Page $jarEvil 'accessonegato.aspx?ReturnUrl=https%3A%2F%2Fexample.org%2Fx'
            # (la pagina riporta il proprio indirizzo nell'azione del form: contano solo i collegamenti di accesso e di ritorno)
            $evilLinks = ([regex]::Matches($evil.Body, '<a id="[^"]*hl(Login|Return)"[^>]*>') | ForEach-Object { $_.Value }) -join ' '
            if ($evilLinks -notmatch 'hlLogin' -or $evilLinks -match 'example' -or $evilLinks -match 'ReturnUrl' -or $evil.Body -match 'tornerai alla pagina che stavi aprendo') { $sfail.Add('ritorno esterno accettato') }
            # dettaglio con id non valido: pagina unica senza promessa (nessun ritorno ricordato)
            $jarBad = Join-Path $work 'bad.txt'
            $badFirst = Get-Page $jarBad 'documentidettaglio.aspx?id=abc'
            $badPage = Get-Page $jarBad 'accessonegato.aspx'
            if ($badFirst.Meta -notmatch '^302\|127\.0\.0\.1\|.*accessonegato\.aspx$') { $sfail.Add('dettaglio con id non valido: destinazione') }
            if ($badPage.Body -match 'documentidettaglio') { $sfail.Add('dettaglio con id non valido: ritorno ricordato') }
        } finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
        if ($sfail.Count -gt 0) { foreach ($x in $sfail) { Write-Host ('  FAIL C ' + $x) }; Write-Host 'SESSION_EXPIRED_NOTICE FAIL (sito locale)'; exit 1 }
        $smokeNote = 'sito locale: 3 pagine riservate, apertura diretta, ritorno esterno e id non valido verificati'
    }
}
Write-Host ('SESSION_EXPIRED_NOTICE PASS (' + $mutants.Count + ' mutanti; ' + $smokeNote + ')')
exit 0
