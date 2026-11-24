[CmdletBinding()]
param()

# AUTH-ATTEMPT-LIMIT-1A, prova reale sul SITO LAB (https, 127.0.0.1 forzato, porta 18843, database LAB): accesso, cambio password e cambio e-mail con richieste
# HTTP vere. Il sito LAB deve servire questo codice. La tabella login_attempt_limits viene creata dallo script della pagina docs e tolta alla fine (il LAB
# non la ha di partenza); la riga di PROVA (password, data, e-mail) e riportata allo stato di partenza. Mai password, cookie o dati personali in output.
# Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$base = 'https://www.taikun.it:18843'
$secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
$testUser = 'PROVA'
$tmp = Join-Path $env:TEMP ('ks-attemptpages-' + [Guid]::NewGuid().ToString('N'))
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
# Accesso con nome e password indicati ('' = la password vera di PROVA).
function Invoke-Login([string]$jar, [string]$user, [string]$word = '') {
    $page = Invoke-Http '/login.aspx' $jar
    $set = @{ '__EVENTTARGET' = (Get-FieldName $page.Body 'btnLogin'); '__EVENTARGUMENT' = '' }
    if ($set['__EVENTTARGET'] -eq '') { $set['__EVENTTARGET'] = 'ctl00$MainContent$btnLogin' }
    $set[(Get-FieldName $page.Body 'tbUsername')] = $user
    $set[(Get-FieldName $page.Body 'tbPassword')] = if ($word -ne '') { $word } else { Get-Secret }
    $f = New-FormFile $page.Body $set
    try {
        $r = Invoke-Http '/login.aspx' $jar $f '/login.aspx'
        # dopo un accesso riuscito il sito cambia sessione: il browser segue il rinvio verso login.aspx?k=1 (AUTH-LOGIN-SESSION-RENEW-1A)
        if ($r.Status -eq 302 -and $r.Location -match 'login\.aspx\?k=1') { $null = Invoke-Http $r.Location $jar }
        return $r
    } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
# Il servizio ricorda per 5 minuti che la tabella manca: il sito LAB si riavvia (web.config toccato) cosi ogni prova parte da uno stato noto.
function Restart-LabSite {
    $cfg = 'C:\Temp\KeepStoreRegOrderLab-20261025\site\web.config'
    if (Test-Path -LiteralPath $cfg) { (Get-Item -LiteralPath $cfg).LastWriteTime = Get-Date }
    $jar = Join-Path $tmp ('rs' + [Guid]::NewGuid().ToString('N') + '.txt')
    for ($i = 0; $i -lt 40; $i++) {
        try { $x = Invoke-Http '/login.aspx' $jar; if ($x.Status -eq 200) { return } } catch { }
        Start-Sleep -Seconds 6
    }
}
function Invoke-PasswordChange([string]$jar, [string]$current, [string]$new) {
    $page = Invoke-Http '/password.aspx' $jar
    $btn = Get-FieldName $page.Body 'btnSalva'
    $set = @{ (Get-FieldName $page.Body 'tbPasswordAttuale') = $current; (Get-FieldName $page.Body 'tbPasswordNuova') = $new; (Get-FieldName $page.Body 'tbPasswordConferma') = $new }
    if ($btn -ne '') { $set[$btn] = 'Aggiorna password' }
    $f = New-FormFile $page.Body $set
    try { return (Invoke-Http '/password.aspx' $jar $f '/password.aspx') } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Invoke-EmailChange([string]$jar, [string]$newEmail, [string]$current) {
    $page = Invoke-Http '/my-account-edit.aspx' $jar
    $emailField = Get-FieldName $page.Body 'txtEmail'
    $passField = Get-FieldName $page.Body 'txtCurrentPassword'
    $saveTarget = [regex]::Match($page.Body, '__doPostBack\(&#39;([^&]*btnSave)&#39;').Groups[1].Value
    if ($emailField -eq '' -or $passField -eq '' -or $saveTarget -eq '') { return [pscustomobject]@{ Status = 0; Location = ''; Headers = ''; Body = 'FORM_NOT_FOUND' } }
    $f = New-FormFile $page.Body @{ '__EVENTTARGET' = $saveTarget; '__EVENTARGUMENT' = ''; $emailField = $newEmail; $passField = $current }
    try { return (Invoke-Http '/my-account-edit.aspx' $jar $f '/my-account-edit.aspx') } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}

$docText = ([IO.File]::ReadAllText((Join-Path $root 'docs\AUTH_ATTEMPT_LIMIT_TABLE.md'), $utf8)).Replace("`r`n", "`n")
$ddl = [regex]::Match($docText, 'CREATE TABLE IF NOT EXISTS login_attempt_limits \([\s\S]*?\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;').Value
$blocked = 'Troppi tentativi'
$generic = 'Accesso non riuscito'
$loginId = ''
try {
    if (-not (Test-Path -LiteralPath $secretFile)) { Write-Host 'AUTH_ATTEMPT_LIMIT_PAGES FAIL credenziale di prova assente'; exit 1 }
    if ($ddl -eq '') { Write-Host 'AUTH_ATTEMPT_LIMIT_PAGES FAIL script della tabella assente nella pagina docs'; exit 1 }
    $loginId = Get-Scalar ("SELECT DISTINCT id AS ksval FROM vlogin WHERE AziendeId=1 AND UPPER(UserName)='" + $testUser + "' AND Abilitato=1 AND UtentiAbilitato=1;")
    if ($loginId -notmatch '^\d+$') { Write-Host 'AUTH_ATTEMPT_LIMIT_PAGES FAIL utente di prova assente sul LAB'; exit 1 }
    $backupSql = "DROP TABLE IF EXISTS ks_test_attempt_pages_backup; CREATE TABLE ks_test_attempt_pages_backup AS SELECT l.id, l.$col AS w, l.DataPassword AS d, l.Email AS em, u.Email AS uem FROM login l INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.id=$loginId; DROP TABLE IF EXISTS login_attempt_limits;"
    $null = Invoke-Sql $backupSql -Write
    Check ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM ks_test_attempt_pages_backup;') -eq '1') 'E00 copia dei dati di prova'
    $same = "SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_attempt_pages_backup b ON b.id=l.id INNER JOIN utenti u ON u.id=l.UtentiId WHERE BINARY l.$col<=>BINARY b.w AND l.Email<=>b.em AND u.Email<=>b.uem;"
    $null = Invoke-Sql $ddl -Write
    Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='login_attempt_limits';") -eq '9') 'E01 tabella creata dallo script della pagina docs'
    Restart-LabSite
    $probe = Join-Path $tmp 'probe.txt'
    $first = Invoke-Http '/login.aspx' $probe
    Check ($first.Status -eq 200 -and $first.Body -match 'name="ctl00\$MainContent\$tbPassword"') 'E02 sito LAB raggiungibile su 127.0.0.1'
    if ($e2e.Count -gt 0) { throw 'PREREQUISITI' }
    $rows = "SELECT COUNT(*) AS ksval FROM login_attempt_limits WHERE ScopeCode=1 AND BlockedUntilUtc > UTC_TIMESTAMP();"

    # accesso: cinque password sbagliate, poi blocco anche con la password giusta
    $jar1 = Join-Path $tmp 'j1.txt'
    $okWrong = $true
    for ($i = 1; $i -le 5; $i++) { $r = Invoke-Login $jar1 $testUser ('Wrong-' + $i + '-ks'); if (-not ($r.Status -eq 200 -and $r.Body -match $generic -and $r.Body -notmatch $blocked)) { $okWrong = $false } }
    Check $okWrong 'E03 cinque password sbagliate: messaggio generico, nessun blocco'
    $r = Invoke-Login $jar1 $testUser 'Wrong-6-ks'
    Check ($r.Status -eq 200 -and $r.Body -match $blocked) 'E04 il sesto tentativo e bloccato'
    $r = Invoke-Login $jar1 $testUser
    Check ($r.Status -eq 200 -and $r.Body -match $blocked -and $r.Location -eq '') 'E05 password GIUSTA durante il blocco: ancora bloccato, nessun accesso'
    Check ((Get-Scalar $rows) -eq '1') 'E06 un solo blocco registrato (accesso)'
    Check ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM login_attempt_limits WHERE KeyHash NOT REGEXP ''^[0-9a-f]{64}$'';') -eq '0') 'E07 nella tabella solo impronte'
    # sblocco di emergenza (assistenza): la tabella si svuota e l'accesso riparte da zero
    $null = Invoke-Sql 'DELETE FROM login_attempt_limits;' -Write
    $r = Invoke-Login $jar1 $testUser
    Check ($r.Status -eq 302 -and $r.Location -match 'myaccount|Default|/$|\.aspx') 'E08 dopo lo sblocco di emergenza: accesso riuscito'
    Check ((Get-Scalar 'SELECT FailCount AS ksval FROM login_attempt_limits WHERE ScopeCode=1 LIMIT 1;') -eq '0') 'E09 il successo azzera il conteggio'
    # un errore dopo cinque non basta: quattro errori, un successo, quattro errori = nessun blocco
    $jar2 = Join-Path $tmp 'j2.txt'
    for ($i = 1; $i -le 4; $i++) { $null = Invoke-Login $jar2 $testUser ('Wrong-a' + $i + '-ks') }
    $r = Invoke-Login $jar2 $testUser
    Check ($r.Status -eq 302) 'E10 quattro errori e poi la password giusta: accesso'
    $jar3 = Join-Path $tmp 'j3.txt'
    $stillOk = $true
    for ($i = 1; $i -le 4; $i++) { $r = Invoke-Login $jar3 $testUser ('Wrong-b' + $i + '-ks'); if ($r.Body -match $blocked) { $stillOk = $false } }
    Check $stillOk 'E11 dopo il successo i quattro errori nuovi non bloccano'
    # nome inesistente: stessa regola, nessuna differenza visibile
    $null = Invoke-Sql 'DELETE FROM login_attempt_limits;' -Write
    $jar4 = Join-Path $tmp 'j4.txt'
    $ghostOk = $true
    for ($i = 1; $i -le 5; $i++) { $r = Invoke-Login $jar4 'ks_nobody_here' ('Wrong-' + $i + '-ks'); if (-not ($r.Status -eq 200 -and $r.Body -match $generic)) { $ghostOk = $false } }
    $r = Invoke-Login $jar4 'KS_NOBODY_HERE ' 'Wrong-6-ks'
    Check ($ghostOk -and $r.Body -match $blocked) 'E12 nome inesistente: stessi cinque messaggi e poi stesso blocco (maiuscole e spazi uguali)'
    Check ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM login_attempt_limits WHERE ScopeCode=3;') -eq '1') 'E13 il nome inesistente ha il suo conteggio separato'
    $r = Invoke-Login (Join-Path $tmp 'j5.txt') $testUser
    Check ($r.Status -eq 302) 'E14 il blocco di un nome inesistente non tocca PROVA'

    # tabella assente: il sito si comporta come prima
    $null = Invoke-Sql 'DROP TABLE login_attempt_limits;' -Write
    $r = Invoke-Login (Join-Path $tmp 'j6.txt') $testUser 'Wrong-x-ks'
    Check ($r.Status -eq 200 -and $r.Body -match $generic -and $r.Body -notmatch $blocked) 'E15 tabella assente: errore generico, nessun errore del sito'
    $r = Invoke-Login (Join-Path $tmp 'j7.txt') $testUser
    Check ($r.Status -eq 302) 'E16 tabella assente: accesso come prima'
    $null = Invoke-Sql $ddl -Write
    Restart-LabSite

    # cambio password: cinque password attuali sbagliate, poi blocco anche con quella giusta; la password non cambia
    $jarP = Join-Path $tmp 'jp.txt'
    $null = Invoke-Login $jarP $testUser
    $newWord = 'Ks-Never-Applied-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)
    $wrongSeen = $true
    for ($i = 1; $i -le 5; $i++) { $r = Invoke-PasswordChange $jarP ('Wrong-p' + $i + '-ks') $newWord; if (-not ($r.Status -eq 200 -and $r.Body -match 'La password attuale non e corretta' -and $r.Body -notmatch $blocked)) { $wrongSeen = $false } }
    Check $wrongSeen 'E17 cambio password: cinque password attuali sbagliate, messaggio normale'
    $r = Invoke-PasswordChange $jarP 'Wrong-p6-ks' $newWord
    Check ($r.Status -eq 200 -and $r.Body -match $blocked) 'E18 cambio password: il sesto tentativo e bloccato'
    $r = Invoke-PasswordChange $jarP (Get-Secret) $newWord
    Check ($r.Status -eq 200 -and $r.Body -match $blocked -and $r.Body -notmatch 'Password aggiornata correttamente') 'E19 cambio password: password attuale GIUSTA durante il blocco, nessun cambio'
    Check ((Get-Scalar $same) -eq '1') 'E20 la password non e cambiata'
    # lo stesso conteggio vale per il cambio e-mail
    $r = Invoke-EmailChange $jarP 'ks.attempt.test@example.invalid' (Get-Secret)
    Check ($r.Status -eq 200 -and $r.Body -match $blocked) 'E21 cambio e-mail: bloccato dal conteggio condiviso con il cambio password'
    Check ((Get-Scalar $same) -eq '1') 'E22 e-mail invariata'
    # cambio e-mail da solo: cinque password sbagliate, poi blocco
    $null = Invoke-Sql 'DELETE FROM login_attempt_limits;' -Write
    $jarE = Join-Path $tmp 'je.txt'
    $null = Invoke-Login $jarE $testUser
    $emailSeen = $true
    for ($i = 1; $i -le 5; $i++) { $r = Invoke-EmailChange $jarE 'ks.attempt.test@example.invalid' ('Wrong-e' + $i + '-ks'); if (-not ($r.Status -eq 200 -and $r.Body -match 'La password attuale non e corretta' -and $r.Body -notmatch $blocked)) { $emailSeen = $false } }
    Check $emailSeen 'E23 cambio e-mail: cinque password sbagliate, messaggio normale (l''errore sopravvive all''annullamento della transazione)'
    Check ((Get-Scalar "SELECT FailCount AS ksval FROM login_attempt_limits WHERE ScopeCode=2 LIMIT 1;") -eq '5') 'E24 cinque errori registrati nonostante gli annullamenti'
    $r = Invoke-EmailChange $jarE 'ks.attempt.test@example.invalid' 'Wrong-e6-ks'
    Check ($r.Status -eq 200 -and $r.Body -match $blocked) 'E25 cambio e-mail: il sesto tentativo e bloccato'
    $r = Invoke-PasswordChange $jarE (Get-Secret) $newWord
    Check ($r.Status -eq 200 -and $r.Body -match $blocked -and $r.Body -notmatch 'Password aggiornata correttamente') 'E26 il blocco del cambio e-mail vale anche per il cambio password'
    Check ((Get-Scalar $same) -eq '1') 'E27 password ed e-mail invariate'
    # l'accesso (conteggio separato) non e bloccato dai tentativi sulle pagine dell'account
    $r = Invoke-Login (Join-Path $tmp 'j8.txt') $testUser
    Check ($r.Status -eq 302) 'E28 l''accesso resta libero (conteggio separato)'
} catch {
    if ($_.Exception.Message -ne 'PREREQUISITI') { $m = [string]$_.Exception.Message; Write-Host ('  FAIL ECCEZIONE ' + $_.Exception.GetType().Name + ' riga ' + $_.InvocationInfo.ScriptLineNumber + ' ' + $m.Substring(0, [Math]::Min(120, $m.Length))); $e2e.Add('ECCEZIONE') }
} finally {
    try {
        $restore = "UPDATE login l INNER JOIN ks_test_attempt_pages_backup b ON b.id=l.id SET l.$col" + "=b.w, l.DataPassword=b.d, l.Email=b.em; UPDATE utenti u INNER JOIN login l ON l.UtentiId=u.id INNER JOIN ks_test_attempt_pages_backup b ON b.id=l.id SET u.Email=b.uem; DROP TABLE IF EXISTS login_attempt_limits;"
        $null = Invoke-Sql $restore -Write
        if ($loginId -match '^\d+$') {
            if ((Get-Scalar $same) -eq '1') { $null = Invoke-Sql 'DROP TABLE IF EXISTS ks_test_attempt_pages_backup;' -Write; Write-Host '  ok   E99 dati di prova riportati allo stato di partenza' } else { Write-Host '  FAIL E99 ripristino non verificato'; $e2e.Add('E99') }
        }
    } catch { Write-Host '  FAIL E99 ripristino con errore'; $e2e.Add('E99') }
    try { Restart-LabSite } catch { }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($e2e.Count -gt 0) { Write-Host ('AUTH_ATTEMPT_LIMIT_PAGES FAIL (' + $e2e.Count + ')'); exit 1 }
Write-Host 'AUTH_ATTEMPT_LIMIT_PAGES PASS'
exit 0
