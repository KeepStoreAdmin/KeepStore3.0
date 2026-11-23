[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$Cases = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# AUTH-LOGIN-SESSION-RENEW-1A. Dopo l'accesso con password il cliente riceve un identificativo di sessione NUOVO e quello vecchio non vale piu
# (contro la fissazione della sessione). Prova HTTP sul sito LAB (https, 127.0.0.1, porta 18843, utente di prova, curl con cookie separati:
# i rinvii si seguono a mano). Si registrano solo impronte dei cookie, mai i valori. Mutazioni sulla copia LAB, file rimessi alla fine.
# Sola lettura sul database salvo il normale registro degli accessi dell'utente di prova. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$files = @('login.aspx.vb', 'App_Code\KeepStoreSignInSessionRenew.vb')
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('LOGIN_SESSION_RENEW FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Page.master'))) { Write-Host ('LOGIN_SESSION_RENEW FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }

$base = 'https://www.taikun.it:18843'
$secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
$testUser = 'PROVA'
$tmp = Join-Path $env:TEMP ('ks-signinrenew-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$labSql = Join-Path $root 'Tools\Invoke-KeepStoreLabSql.ps1'
$ticketName = '__Host-KeepStoreSignIn'

function Invoke-Sql([string]$sql) {
    $f = Join-Path $tmp ('q' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($f, $sql, $utf8)
    try { return @(& powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f) } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Get-Scalar([string]$sql) { $o = @(Invoke-Sql $sql); for ($i = 0; $i -lt $o.Count - 1; $i++) { if ([string]$o[$i] -eq 'ksval') { return ([string]$o[$i + 1]).Trim() } }; return '' }
function Get-Secret {
    $sec = ConvertTo-SecureString (Get-Content -LiteralPath $secretFile)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
# Richiesta con cookie jar (i rinvii non si seguono) oppure con intestazione Cookie scritta a mano (senza jar).
function Invoke-Http([string]$path, [string]$jar, [string]$bodyFile = '', [string]$referer = '', [string]$cookieHeader = '', [string]$method = '') {
    $out = Join-Path $tmp ('b' + [Guid]::NewGuid().ToString('N') + '.html'); $hdr = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N') + '.txt')
    $a = @('--noproxy', '*', '-s', '--max-time', '180', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-D', $hdr, '-o', $out, '-w', '%{http_code}|%{remote_ip}')
    if ($jar -ne '') { $a += @('-b', $jar, '-c', $jar) }
    if ($cookieHeader -ne '') { $a += @('-H', ('Cookie: ' + $cookieHeader)) }
    if ($method -ne '') { $a += @('-X', $method) }
    if ($bodyFile -ne '') { $a += @('-H', ('Origin: ' + $base), '-H', ('Referer: ' + $base + $referer), '--data', ('@' + $bodyFile)) }
    $a += ($base + $path)
    $w = (& curl.exe @a) -join ''
    $parts = $w.Split('|')
    if ($parts.Count -lt 2 -or $parts[1] -ne '127.0.0.1') { throw ('NOT_LOOPBACK ' + $w) }
    $headers = if (Test-Path -LiteralPath $hdr) { [IO.File]::ReadAllText($hdr) } else { '' }
    $body = if (Test-Path -LiteralPath $out) { [IO.File]::ReadAllText($out, [Text.Encoding]::UTF8) } else { '' }
    $loc = ''; $mm = [regex]::Match($headers, '(?im)^Location:\s*(\S+)'); if ($mm.Success) { $loc = $mm.Groups[1].Value }
    Remove-Item -LiteralPath $out, $hdr -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Status = [int]$parts[0]; Location = $loc; Headers = $headers; Body = $body }
}
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
# Accesso con password: restituisce la risposta del POST. $path puo portare un ReturnUrl.
function Invoke-Login([string]$jar, [string]$path = '/login.aspx', [string]$word = '') {
    $page = Invoke-Http $path $jar
    $set = @{ '__EVENTTARGET' = (Get-FieldName $page.Body 'btnLogin'); '__EVENTARGUMENT' = '' }
    if ($set['__EVENTTARGET'] -eq '') { $set['__EVENTTARGET'] = 'ctl00$MainContent$btnLogin' }
    $set[(Get-FieldName $page.Body 'tbUsername')] = $testUser
    $set[(Get-FieldName $page.Body 'tbPassword')] = if ($word -ne '') { $word } else { Get-Secret }
    $f = New-FormFile $page.Body $set
    try { return (Invoke-Http $path $jar $f $path) } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Get-JarValue([string]$jar, [string]$name) {
    if (-not (Test-Path -LiteralPath $jar)) { return '' }
    foreach ($line in [IO.File]::ReadAllLines($jar)) { $c = $line.Split("`t"); if ($c.Count -ge 7 -and $c[5] -eq $name) { return $c[6] } }
    return ''
}
function Get-SetCookie([string]$headers, [string]$name) {
    $mm = [regex]::Match($headers, '(?im)^Set-Cookie:\s*' + [regex]::Escape($name) + '=([^;\r\n]*)(;[^\r\n]*)?')
    if ($mm.Success) { return [pscustomobject]@{ Found = $true; Empty = ($mm.Groups[1].Value -eq ''); Value = $mm.Groups[1].Value; Attr = $mm.Groups[2].Value } }
    return [pscustomobject]@{ Found = $false; Empty = $false; Value = ''; Attr = '' }
}
function Test-CookieAttr([string]$attr) { return ($attr -match '(?i);\s*path=/(;|$)' -and $attr -match '(?i);\s*secure' -and $attr -match '(?i);\s*HttpOnly' -and $attr -match '(?i);\s*SameSite=Lax' -and $attr -notmatch '(?i);\s*domain=') }
function Short([string]$v) { if ($v -eq '') { return '(vuoto)' }; $sha = [Security.Cryptography.SHA256]::Create(); return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($v)) | Select-Object -First 3 | ForEach-Object { $_.ToString('x2') }) -join '') }
function Get-SessionName {
    $probe = Join-Path $tmp 'probe.txt'
    $null = Invoke-Http '/login.aspx' $probe
    foreach ($line in [IO.File]::ReadAllLines($probe)) { $c = $line.Split("`t"); if ($c.Count -ge 7 -and $c[6].Length -eq 24 -and -not $c[5].StartsWith('__Host-')) { return $c[5] } }
    return ''
}
function Start-Fresh([string]$name) { $j = Join-Path $tmp ($name + '.txt'); if (Test-Path -LiteralPath $j) { Remove-Item -LiteralPath $j -Force }; return $j }

# ---------------------------------------------------------------- prova (restituisce l'elenco dei difetti)
function Invoke-Checks([string]$sessionName, [string]$loginId, [string]$only) {
    $bad = New-Object Collections.Generic.List[string]
    function Want([string]$code) { return ($only -eq '' -or $only -match $code) }

    # R01-R06: accesso, rinvio, sessione nuova, vecchio identificativo, riuso del biglietto
    $jar = Start-Fresh 'a'
    $page = Invoke-Http '/login.aspx' $jar
    $old = Get-JarValue $jar $sessionName
    if ($old -eq '') { $bad.Add('R00 NON PROVATO: nessun cookie di sessione prima dell''accesso'); return $bad }
    $accessBefore = Get-Scalar "SELECT COALESCE(NumeroAccessi,0) AS ksval FROM login WHERE id=$loginId;"
    $r = Invoke-Login $jar '/login.aspx'
    $t = Get-SetCookie $r.Headers $ticketName
    $expired = Get-SetCookie $r.Headers $sessionName
    if ($r.Status -ne 302 -or $r.Location -notmatch '(?i)login\.aspx\?k=1$') { $bad.Add('R01 accesso: stato ' + [string]$r.Status + ' e rinvio [' + $r.Location + '] invece di 302 verso login.aspx?k=1'); return $bad }
    if (-not $t.Found -or $t.Empty -or $t.Value -notmatch '^[A-Za-z0-9_-]{43}$') { $bad.Add('R02 accesso: cookie del biglietto assente o con formato diverso') ; return $bad }
    if (-not (Test-CookieAttr $t.Attr)) { $bad.Add('R02 accesso: attributi del cookie del biglietto [' + $t.Attr + ']') }
    if (-not $expired.Found -or -not $expired.Empty) { $bad.Add('R03 accesso: il cookie di sessione vecchio non viene fatto scadere') }
    $ticket = $t.Value
    $hop = Invoke-Http '/login.aspx?k=1' $jar
    $new = Get-JarValue $jar $sessionName
    $cleared = Get-SetCookie $hop.Headers $ticketName
    if ($hop.Status -ne 302 -or $hop.Location -match '(?i)NoAccess|accessonegato|login\.aspx') { $bad.Add('R04 rinvio: stato ' + [string]$hop.Status + ' verso [' + $hop.Location + '] (cookie impostati: ' + ((([regex]::Matches($hop.Headers, '(?im)^Set-Cookie:\s*([^=;
]+)') | ForEach-Object { $_.Groups[1].Value }) -join ',')) + ')') }
    if ($new -eq '' -or $new -eq $old) { $bad.Add('R05 la sessione dopo l''accesso ha lo stesso identificativo di prima (' + (Short $old) + ' / ' + (Short $new) + ')') }
    if (-not $cleared.Found -or -not $cleared.Empty) { $bad.Add('R06 il cookie del biglietto non viene cancellato dopo l''uso') }
    $mine = Invoke-Http '/myaccount.aspx' $jar
    if ($mine.Status -ne 200) { $bad.Add('R07 dopo il rinvio il cliente non e collegato (area personale: stato ' + [string]$mine.Status + ')') }
    $accessAfter = Get-Scalar "SELECT COALESCE(NumeroAccessi,0) AS ksval FROM login WHERE id=$loginId;"
    if ([int]$accessAfter -ne [int]$accessBefore + 1) { $bad.Add('R08 accessi registrati: ' + $accessBefore + ' -> ' + $accessAfter + ' invece di +1') }
    # il vecchio identificativo, presentato da solo, non e collegato
    $oldOnly = Invoke-Http '/myaccount.aspx' '' '' '' ($sessionName + '=' + $old)
    if ($oldOnly.Status -eq 200) { $bad.Add('R09 il vecchio identificativo di sessione, presentato da solo, e ancora collegato') }
    # il biglietto e monouso
    $replay = Invoke-Http '/login.aspx?k=1' '' '' '' ($ticketName + '=' + $ticket)
    if ($replay.Status -eq 302) { $bad.Add('R10 il biglietto gia usato collega ancora una sessione nuova') }

    # R11: con un cookie di sessione nella richiesta il biglietto non si consuma e resta bruciato
    $jarB = Start-Fresh 'b'
    $null = Invoke-Http '/login.aspx' $jarB
    $r2 = Invoke-Login $jarB '/login.aspx'
    $t2 = (Get-SetCookie $r2.Headers $ticketName).Value
    # identificativo di sessione sconosciuto (24 caratteri validi): il server lo accetterebbe come sessione "nuova", ma la richiesta porta un cookie di sessione
    $unknownId = -join ((1..24) | ForEach-Object { 'abcdefghijklmnopqrstuvwxyz012345'[(Get-Random -Maximum 32)] })
    $with = Invoke-Http '/login.aspx?k=1' '' '' '' ($sessionName + '=' + $unknownId + '; ' + $ticketName + '=' + $t2)
    if ($with.Status -eq 302) { $bad.Add('R11 il biglietto viene consumato anche con un cookie di sessione nella richiesta') }
    $again = Invoke-Http '/login.aspx?k=1' '' '' '' ($ticketName + '=' + $t2)
    if ($again.Status -eq 302) { $bad.Add('R12 il biglietto non e bruciato dopo un consumo respinto') }
    # sessione gia esistente (il vecchio identificativo e stato usato da solo piu su)
    $r2b = Invoke-Login $jarB '/login.aspx'
    $t2b = (Get-SetCookie $r2b.Headers $ticketName).Value
    $withLive = Invoke-Http '/login.aspx?k=1' '' '' '' ($sessionName + '=' + $old + '; ' + $ticketName + '=' + $t2b)
    if ($withLive.Status -eq 302) { $bad.Add('R11 il biglietto viene consumato in una sessione gia esistente') }

    # R13: un POST non consuma il biglietto
    $jarC = Start-Fresh 'c'
    $null = Invoke-Http '/login.aspx' $jarC
    $r3 = Invoke-Login $jarC '/login.aspx'
    $t3 = (Get-SetCookie $r3.Headers $ticketName).Value
    $jarP = Start-Fresh 'p'
    $formSource = Start-Fresh 'q'
    $formPage = Invoke-Http '/login.aspx' $formSource
    $formFile = New-FormFile $formPage.Body @{}
    try { $post = Invoke-Http '/login.aspx?k=1' $jarP $formFile '/login.aspx' ($ticketName + '=' + $t3) 'POST' } finally { Remove-Item -LiteralPath $formFile -Force -ErrorAction SilentlyContinue }
    $afterPost = Invoke-Http '/myaccount.aspx' $jarP
    if ($afterPost.Status -eq 200) { $bad.Add('R13 un POST consuma il biglietto e collega la sessione') }

    # R14: password sbagliata = nessun rinnovo, nessun biglietto
    $jarD = Start-Fresh 'd'
    $null = Invoke-Http '/login.aspx' $jarD
    $dOld = Get-JarValue $jarD $sessionName
    $r4 = Invoke-Login $jarD '/login.aspx' 'password-sbagliata-ks'
    if ((Get-SetCookie $r4.Headers $ticketName).Found) { $bad.Add('R14 password sbagliata: emesso un biglietto') }
    if ((Get-JarValue $jarD $sessionName) -ne $dOld) { $bad.Add('R14 password sbagliata: la sessione e cambiata') }

    # R15: la destinazione richiesta prima dell'accesso si conserva
    $jarE = Start-Fresh 'e'
    $r5 = Invoke-Login $jarE '/login.aspx?ReturnUrl=%2Fdocumenti.aspx%3Ft%3D4'
    $hop5 = Invoke-Http '/login.aspx?k=1' $jarE
    if ($hop5.Status -ne 302 -or $hop5.Location -notmatch '(?i)documenti\.aspx\?t=4') { $bad.Add('R15 destinazione dopo l''accesso: [' + $hop5.Location + '] invece di documenti.aspx?t=4') }

    # R16: scadenza (si usa il cookie scritto a mano: il jar di curl lo scarterebbe da solo)
    if (Want 'R16') {
        $jarF = Start-Fresh 'f'
        $null = Invoke-Http '/login.aspx' $jarF
        $r6 = Invoke-Login $jarF '/login.aspx'
        $t6 = (Get-SetCookie $r6.Headers $ticketName).Value
        Start-Sleep -Seconds 64
        $late = Invoke-Http '/login.aspx?k=1' '' '' '' ($ticketName + '=' + $t6)
        if ($late.Status -eq 302) { $bad.Add('R16 un biglietto scaduto collega ancora una sessione nuova') }
    }

    # R17: al massimo 3 biglietti pendenti per account (il piu vecchio e sostituito)
    if (Want 'R17') {
        $tickets = @()
        for ($i = 0; $i -lt 4; $i++) { $j = Start-Fresh ('g' + $i); $null = Invoke-Http '/login.aspx' $j; $rr = Invoke-Login $j '/login.aspx'; $tickets += (Get-SetCookie $rr.Headers $ticketName).Value }
        $first = Invoke-Http '/login.aspx?k=1' '' '' '' ($ticketName + '=' + $tickets[0])
        $last = Invoke-Http '/login.aspx?k=1' '' '' '' ($ticketName + '=' + $tickets[3])
        if ($first.Status -eq 302) { $bad.Add('R17 con 4 biglietti pendenti il piu vecchio e ancora valido') }
        if ($last.Status -ne 302) { $bad.Add('R17 l''ultimo biglietto non e valido (stato ' + [string]$last.Status + ')') }
    }
    return $bad
}
# Caso di fallimento chiuso: nella sola copia LAB l'emissione del biglietto fallisce; la sessione vecchia non deve restare collegata.
function Invoke-FailClosed([string]$sessionName) {
    $bad = New-Object Collections.Generic.List[string]
    $svc = Get-Text $repoBytes['App_Code\KeepStoreSignInSessionRenew.vb']
    $key = "        If Not IsSupported(context) Then Return SignInRenewOutcome.NotSupported`r`n        Try"
    $key2 = "        If Not IsSupported(context) Then Return SignInRenewOutcome.NotSupported`n        Try"
    $mut = if ($svc.Contains($key)) { $svc.Replace($key, "        If Not IsSupported(context) Then Return SignInRenewOutcome.NotSupported`r`n        If True Then Return SignInRenewOutcome.Failed`r`n        Try") } elseif ($svc.Contains($key2)) { $svc.Replace($key2, "        If Not IsSupported(context) Then Return SignInRenewOutcome.NotSupported`n        If True Then Return SignInRenewOutcome.Failed`n        Try") } else { '' }
    if ($mut -eq '') { $bad.Add('R20 NON PROVATO: punto del servizio non trovato'); return $bad }
    Write-SiteText 'App_Code\KeepStoreSignInSessionRenew.vb' $mut
    try {
        Start-Sleep -Seconds 8; $null = Invoke-Http '/login.aspx' (Start-Fresh 'warm'); Start-Sleep -Seconds 2
        $jar = Start-Fresh 'h'
        $null = Invoke-Http '/login.aspx' $jar
        $r = Invoke-Login $jar '/login.aspx'
        if ((Get-SetCookie $r.Headers $ticketName).Found) { $bad.Add('R20 NON PROVATO: emesso un biglietto con l''emissione forzata in errore') }
        if ($r.Status -eq 302) { $bad.Add('R20 con il rinnovo fallito l''accesso prosegue lo stesso (stato 302)') }
        $mine = Invoke-Http '/myaccount.aspx' $jar
        if ($mine.Status -eq 200) { $bad.Add('R21 con il rinnovo fallito la sessione vecchia resta collegata') }
    } finally { Write-Site 'App_Code\KeepStoreSignInSessionRenew.vb' $repoBytes['App_Code\KeepStoreSignInSessionRenew.vb']; Start-Sleep -Seconds 8; $null = Invoke-Http '/login.aspx' (Start-Fresh 'warm2') }
    return $bad
}

$exit = 0
try {
    if (-not (Test-Path -LiteralPath $secretFile)) { Write-Host 'LOGIN_SESSION_RENEW FAIL credenziale di prova assente'; exit 1 }
    Sync-Site
    $null = Invoke-Http '/login.aspx' (Start-Fresh 'warm0'); Start-Sleep -Seconds 4; $null = Invoke-Http '/login.aspx' (Start-Fresh 'warm1')
    $sessionName = Get-SessionName
    if ($sessionName -eq '') { Write-Host 'LOGIN_SESSION_RENEW FAIL: nome del cookie di sessione non trovato'; exit 1 }
    $loginId = Get-Scalar ("SELECT DISTINCT id AS ksval FROM vlogin WHERE AziendeId=1 AND UPPER(UserName)='" + $testUser + "' AND Abilitato=1 AND UtentiAbilitato=1;")
    if ($loginId -notmatch '^\d+$') { Write-Host 'LOGIN_SESSION_RENEW FAIL utente di prova assente sul LAB'; exit 1 }

    $bad = @(Invoke-Checks $sessionName $loginId $Cases)
    if ($bad.Count -eq 0) { Write-Host '  ok   accesso con sessione nuova (R01-R17)' } else { $exit = 1; foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) } }
    if ($Cases -eq '' -or $Cases -match 'R20') {
        $bad = @(Invoke-FailClosed $sessionName)
        if ($bad.Count -eq 0) { Write-Host '  ok   fallimento chiuso (R20-R21)' } else { $exit = 1; foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) } }
    }

    if (-not $SkipMutants -and $exit -eq 0 -and $Cases -eq '') {
        $svcRel = 'App_Code\KeepStoreSignInSessionRenew.vb'; $loginRel = 'login.aspx.vb'
        $mutants = @(
            @{ Id = 'M01_NO_ABANDON'; File = $svcRel; Expect = 'R09'; Old = 'context.Session.Abandon()'; New = 'Dim keepOldSession As Integer = 0' },
            @{ Id = 'M02_NO_COOKIE_EXPIRY'; File = $svcRel; Expect = 'R03'; Old = '            KeepStoreStaySignedInWeb.ExpireSessionCookie(context)' + "`n"; New = '' },
            @{ Id = 'M03_TICKET_NOT_REMOVED'; File = $svcRel; Expect = 'R10'; Old = 'HttpRuntime.Cache.Remove(CacheKey(nonce))'; New = 'HttpRuntime.Cache.Get(CacheKey(nonce))' },
            @{ Id = 'M04_SESSION_COOKIE_IGNORED'; File = $svcRel; Expect = 'R11'; Old = 'If KeepStoreStaySignedInWeb.HasSessionCookie(context) Then Return False'; New = '' },
            @{ Id = 'M05_CONSUMED_ON_POST'; File = $svcRel; Expect = 'R13'; Old = 'String.Equals(context.Request.HttpMethod, "GET", StringComparison.Ordinal) AndAlso'; New = 'True AndAlso' },
            @{ Id = 'M06_NO_EXPIRY'; File = $svcRel; Expect = 'R16'; Old = 'Public Const LifetimeSeconds As Integer = 60'; New = 'Public Const LifetimeSeconds As Integer = 3600' },
            @{ Id = 'M07_NO_PER_ACCOUNT_CAP'; File = $svcRel; Expect = 'R17'; Old = 'Public Const MaxPendingPerAccount As Integer = 3'; New = 'Public Const MaxPendingPerAccount As Integer = 3000' },
            @{ Id = 'M08_RENEWAL_NOT_USED'; File = $loginRel; Expect = 'R01'; Old = 'If renewal = SignInRenewOutcome.Renewed Then'; New = 'If False Then' },
            @{ Id = 'M09_DESTINATION_LOST'; File = $svcRel; Expect = 'R15'; Old = '.Target = If(String.IsNullOrWhiteSpace(target), "~/Default.aspx", target),'; New = '.Target = "~/Default.aspx",' }
        )
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
            $src = (Get-Text $repoBytes[$mu.File])
            $i0 = $src.IndexOf($mu.Old, [StringComparison]::Ordinal)
            if ($i0 -lt 0 -or $i0 -ne $src.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            Write-SiteText $mu.File $src.Replace($mu.Old, $mu.New)
            try {
                Start-Sleep -Seconds 8; $null = Invoke-Http '/login.aspx' (Start-Fresh 'warm'); Start-Sleep -Seconds 2
                $mb = @(Invoke-Checks $sessionName $loginId $(if ($mu.Expect -match 'R16|R17') { $mu.Expect } else { '' }))
                if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' ; ')); $exit = 1 }
            } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
            finally { Write-Site $mu.File $repoBytes[$mu.File] }
        }
        # mutazione del fallimento chiuso: l'identita non viene tolta
        if ($MutantFilter -eq '' -or 'M10_FAIL_OPEN' -match $MutantFilter) {
            $src = (Get-Text $repoBytes[$loginRel]); $old = 'If Not renewalFinished AndAlso KeepStoreSignInSessionRenew.IsSupported(HttpContext.Current) Then FailSignInRenewalClosed()'
            if ($src.IndexOf($old, [StringComparison]::Ordinal) -lt 0) { Write-Host '  FAIL M10_FAIL_OPEN: punto non trovato'; $exit = 1 }
            else {
                Write-SiteText $loginRel $src.Replace($old, '')
                try { Start-Sleep -Seconds 8; $null = Invoke-Http '/login.aspx' (Start-Fresh 'warm'); Start-Sleep -Seconds 2; $mb = @(Invoke-FailClosed $sessionName)
                    if (@($mb | Where-Object { ([string]$_).StartsWith('R21') }).Count -gt 0) { Write-Host '  ok   mutazione uccisa M10_FAIL_OPEN' } else { Write-Host ('  FAIL mutazione sopravvissuta M10_FAIL_OPEN :: ' + (($mb | Select-Object -First 2) -join ' ; ')); $exit = 1 }
                } catch { Write-Host ('  FAIL M10_FAIL_OPEN: ' + $_.Exception.Message); $exit = 1 } finally { Write-Site $loginRel $repoBytes[$loginRel] }
            }
        }
    }
} catch { Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1 }
finally {
    Sync-Site
    foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($exit -eq 0) { Write-Host ('LOGIN_SESSION_RENEW PASS' + $(if ($SkipMutants -or $Cases -ne '') { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (10 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'LOGIN_SESSION_RENEW FAIL' }
exit $exit
