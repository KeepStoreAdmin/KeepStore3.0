[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipLabMutants)

# AUTH-RESET-ISSUE-LOCK-1C. Una richiesta di recupero della password che ha letto l'e-mail vecchia prima di un cambio dell'e-mail non deve far
# nascere un codice valido verso il vecchio indirizzo. L'emissione sta in App_Code/PasswordResetTokenIssuance.vb (modulo autonomo): blocca la
# riga dell'accesso, rilegge l'e-mail, la confronta con la regola del profilo, poi annulla i pendenti e inserisce il codice, tutto in una
# transazione. (A) sorgenti, (B) mutazioni dei sorgenti, (C) LAB locale: modulo reale con due connessioni (Tools/ResetIssueLockLabHarness.vb),
# (D) mutazioni del modulo eseguite sul LAB. Un mutante del LAB e "ucciso" SOLO se compila, il riepilogo c'e, non ci sono errori del programma
# di prova, la guardia e superata e compare almeno una delle righe FAIL attese. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p, $utf8) } else { return '' } }
$files = @{
    module  = Read-Repo 'App_Code/PasswordResetTokenIssuance.vb'
    service = Read-Repo 'App_Code/PasswordResetTokenService.vb'
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $m = $f.module; $s = $f.service
    if ($m -eq '') { $fail.Add('S00 modulo assente') }
    # S01 modulo autonomo e silenzioso
    if ($m -match 'HttpContext|System\.Web|ConfigurationManager|KeepStoreLog|Session\(|\bPage\b') { $fail.Add('S01 modulo non autonomo') }
    # S02 lettura bloccante per chiave, confronto in VB con la regola del profilo
    if ($m -notmatch '"SELECT Email, Abilitato FROM login WHERE id = @loginId FOR UPDATE"') { $fail.Add('S02 lettura bloccante dell''accesso') }
    if ($m -match '(?i)UPPER\s*\(|LOWER\s*\(|COLLATE') { $fail.Add('S02 confronto dell''e-mail fatto in SQL') }
    if ($m -notmatch 'Return String\.Equals\(locked, expected, StringComparison\.OrdinalIgnoreCase\)') { $fail.Add('S02 regola del profilo (senza maiuscole, con gli accenti)') }
    if ($m -notmatch 'If locked\.Length = 0 OrElse expected\.Length = 0 Then Return False') { $fail.Add('S02 due indirizzi vuoti non sono uguali') }
    # S03 una sola transazione: revoca filtrata, inserimento, commit; nessuna eccezione inghiottita
    if ($m -notmatch '"UPDATE login_password_reset_tokens SET RevokedAt = NOW\(\) WHERE LoginId = @loginId AND UsedAt IS NULL AND RevokedAt IS NULL"') { $fail.Add('S03 revoca dei soli pendenti dell''accesso') }
    if ($m -notmatch '"VALUES \(@loginId, @tokenHash, NOW\(\), DATE_ADD\(NOW\(\), INTERVAL 30 MINUTE\), NULL, NULL, @ipHash, @userAgentHash, ''web_remind''\)"') { $fail.Add('S03 inserimento del codice') }
    $iSel = $m.IndexOf('FOR UPDATE"'); $iRev = $m.IndexOf('SET RevokedAt = NOW()'); $iIns = $m.IndexOf('INSERT INTO login_password_reset_tokens'); $iCommit = $m.IndexOf('tx.Commit()')
    if ($iSel -lt 0 -or $iRev -lt 0 -or $iIns -lt 0 -or $iCommit -lt 0 -or -not ($iSel -lt $iRev -and $iRev -lt $iIns -and $iIns -lt $iCommit)) { $fail.Add('S03 ordine: blocco, revoca, inserimento, commit') }
    if (([regex]::Matches($m, 'tx\.Commit\(\)')).Count -ne 1) { $fail.Add('S03 un solo commit') }
    if ($m -match 'AddWithValue') { $fail.Add('S03 parametri senza tipo esplicito') }
    # S04 attesa del blocco breve e ripristinata
    if ($m -notmatch 'Public Const LockWaitSeconds As Integer = 5' -or $m -notmatch '"SET SESSION innodb_lock_wait_timeout = "') { $fail.Add('S04 attesa del blocco della sessione') }
    # S05 il servizio usa il modulo con l'e-mail LETTA dal database e non invia nulla se il codice non e nato
    if ($s -notmatch 'If Not PasswordResetTokenIssuance\.TryIssue\(conn, loginId, destinationEmail, tokenHash, ipHash, userAgentHash\) Then\s+Return\s+End If\s+Try\s+SendResetEmail\(page, destinationEmail, displayName, clearToken, companyInfo\)') { $fail.Add('S05 emissione tramite il modulo, prima dell''invio') }
    if ($s -match 'INSERT INTO login_password_reset_tokens|Private Sub InsertToken') { $fail.Add('S05 secondo inserimento dei codici nel servizio') }
    if ($s -notmatch 'Dim ipHash As Object = HashOptional\(GetClientIp\(page\)\)' -or $s -notmatch 'Dim userAgentHash As Object = HashOptional\(Convert\.ToString\(page\.Request\.UserAgent\)\)') { $fail.Add('S05 impronte facoltative come oggetti (senza User-Agent la conversione falliva)') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

if (-not (Test-Source $files)) { Write-Host 'RESET_ISSUE_LOCK FAIL (sorgenti)'; exit 1 }
Write-Host 'RESET_ISSUE_LOCK sorgenti OK'

$nl = "`r`n"
$sourceMutants = @(
    @{ Id = 'M01_TYPED_EMAIL'; File = 'service'; Old = 'TryIssue(conn, loginId, destinationEmail, tokenHash'; New = 'TryIssue(conn, loginId, cleanEmail, tokenHash' },
    @{ Id = 'M02_RESULT_IGNORED'; File = 'service'; Old = 'If Not PasswordResetTokenIssuance.TryIssue('; New = 'If False AndAlso Not PasswordResetTokenIssuance.TryIssue(' },
    @{ Id = 'M03_STRING_HASHES'; File = 'service'; Old = 'Dim userAgentHash As Object ='; New = 'Dim userAgentHash As String =' },
    @{ Id = 'M04_SQL_COMPARE'; File = 'module'; Old = '"SELECT Email, Abilitato FROM login WHERE id = @loginId FOR UPDATE"'; New = '"SELECT Email, Abilitato FROM login WHERE id = @loginId AND UPPER(Email) = UPPER(@email) FOR UPDATE"' },
    @{ Id = 'M05_WEB_DEPENDENCY'; File = 'module'; Old = 'Public NotInheritable Class PasswordResetTokenIssuance'; New = "' HttpContext.Current" + $nl + 'Public NotInheritable Class PasswordResetTokenIssuance' }
)
$survived = New-Object Collections.Generic.List[string]
foreach ($mu in $sourceMutants) {
    $text = [string]$files[$mu.File]
    $i = $text.IndexOf($mu.Old, [StringComparison]::Ordinal)
    if ($i -lt 0) { $survived.Add($mu.Id + ' (ancora non trovata)'); continue }
    $copy = $files.Clone(); $copy[$mu.File] = $text.Substring(0, $i) + $mu.New + $text.Substring($i + $mu.Old.Length)
    if (Test-Source $copy -Quiet) { $survived.Add($mu.Id) }
}
if ($survived.Count -gt 0) { Write-Host ('RESET_ISSUE_LOCK FAIL mutanti dei sorgenti sopravvissuti: ' + ($survived -join ', ')); exit 1 }
Write-Host ('RESET_ISSUE_LOCK mutanti dei sorgenti uccisi: ' + $sourceMutants.Count)
if ($SkipLab) { Write-Host 'RESET_ISSUE_LOCK PASS (senza LAB)'; exit 0 }

# ---------------------------------------------------------------- (C) LAB
$labMutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLocalLabSql')
function Invoke-Lab([string]$moduleText) {
    $credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
    $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $bin = Join-Path $root 'Bin'
    if (-not (Test-Path -LiteralPath $credFile)) { return 'LAB_UNAVAILABLE credenziale assente' }
    $work = Join-Path $env:TEMP ('ks-resetissue-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    $held = $false
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
        $exe = Join-Path $work 'ResetIssueLockLabHarness.exe'
        $modFile = Join-Path $work 'PasswordResetTokenIssuance.vb'
        [IO.File]::WriteAllText($exe + '.config', $cfg, $utf8)
        [IO.File]::WriteAllText($modFile, $moduleText, $utf8)
        $ref = '/reference:' + (Join-Path $bin 'MySql.Data.dll')
        $build = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ /out:$exe $ref /reference:System.dll /reference:System.Data.dll /reference:System.Core.dll (Join-Path $root 'Tools\ResetIssueLockLabHarness.vb') $modFile 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { return ('COMPILE_ERROR ' + (($build | Select-Object -First 3) -join ' | ')) }
        try { $held = $labMutex.WaitOne(600000) } catch [System.Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { return 'LAB_UNAVAILABLE occupato' }
        $cred = Import-Clixml -LiteralPath $credFile
        $plain = $cred.GetNetworkCredential().Password
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $exe; $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.CreateNoWindow = $true
        $info.EnvironmentVariables['KS_LAB_USER'] = $cred.UserName
        $info.EnvironmentVariables['KS_LAB_PWD'] = $plain
        $proc = [Diagnostics.Process]::Start($info)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync(); $stderrTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit(240000)) { try { $proc.Kill() } catch { }; return 'HARNESS_ERROR tempo scaduto' }
        $stdout = $stdoutTask.Result
        if ($plain) { $stdout = $stdout.Replace($plain, '<hidden>') }
        $plain = $null; $cred = $null
        return ((@($stdout -split "`r?`n" | Where-Object { $_ -match '^(FAIL|HARNESS_ERROR|RESET_ISSUE_LAB)' })) -join "`n")
    } finally {
        if ($held) { try { $labMutex.ReleaseMutex() } catch { } }
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
function Get-LabVerdict([string]$out) {
    # PASS / FAIL (controlli di comportamento falliti, elenco in .Ids) / INVALID (prova non valida: non conta ne come successo ne come uccisione)
    if ($out -match '(?m)^(COMPILE_ERROR|LAB_UNAVAILABLE|HARNESS_ERROR)' -or $out -notmatch '(?m)^RESET_ISSUE_LAB CHECKS=\d+ FAIL=\d+') { return [pscustomobject]@{ State = 'INVALID'; Ids = @(); Text = $out } }
    $ids = @([regex]::Matches($out, '(?m)^FAIL (\S+)') | ForEach-Object { $_.Groups[1].Value })
    if (@($ids | Where-Object { $_ -match '^(G\d+|Z99)$' }).Count -gt 0) { return [pscustomobject]@{ State = 'INVALID'; Ids = $ids; Text = $out } }
    if ($out -match '(?m)^RESET_ISSUE_LAB CHECKS=(\d+) FAIL=0\s*$' -and $ids.Count -eq 0) { return [pscustomobject]@{ State = 'PASS'; Ids = @(); Text = $out } }
    return [pscustomobject]@{ State = 'FAIL'; Ids = $ids; Text = $out }
}

$first = Get-LabVerdict (Invoke-Lab $files.module)
if ($first.State -ne 'PASS') { Write-Host ('RESET_ISSUE_LOCK FAIL LAB (' + $first.State + '):'); Write-Host $first.Text; exit 1 }
Write-Host ('RESET_ISSUE_LOCK LAB OK: ' + ([regex]::Match($first.Text, 'RESET_ISSUE_LAB CHECKS=\d+ FAIL=0').Value))
if ($SkipLabMutants) { Write-Host 'RESET_ISSUE_LOCK PASS (senza mutazioni sul LAB)'; exit 0 }

# ---------------------------------------------------------------- (D) mutazioni del modulo eseguite sul LAB
$labMutants = @(
    @{ Id = 'L01_NO_ROW_LOCK'; Old = 'WHERE id = @loginId FOR UPDATE"'; New = 'WHERE id = @loginId"'; Expect = @('T09', 'T10') },
    @{ Id = 'L02_ALWAYS_MATCH'; Old = 'Return String.Equals(locked, expected, StringComparison.OrdinalIgnoreCase)'; New = 'Return True'; Expect = @('T03', 'T04') },
    @{ Id = 'L03_NO_TRIM'; Old = 'Dim expected As String = If(expectedEmail, String.Empty).Trim()'; New = 'Dim expected As String = If(expectedEmail, String.Empty)'; Expect = @('T02') },
    @{ Id = 'L04_CASE_SENSITIVE'; Old = 'Return String.Equals(locked, expected, StringComparison.OrdinalIgnoreCase)'; New = 'Return String.Equals(locked, expected, StringComparison.Ordinal)'; Expect = @('T02') },
    @{ Id = 'L05_DISABLED_ACCEPTED'; Old = 'If Not found OrElse Not enabled OrElse Not EmailMatches(lockedEmail, expectedEmail) Then'; New = 'If Not found OrElse Not EmailMatches(lockedEmail, expectedEmail) Then'; Expect = @('T05') },
    @{ Id = 'L06_NO_REVOKE'; Old = '                    revoke.ExecuteNonQuery()' + $nl; New = ''; Expect = @('T01', 'T02', 'T13') },
    @{ Id = 'L07_REVOKE_OTHER_LOGINS'; Old = 'WHERE LoginId = @loginId AND UsedAt IS NULL AND RevokedAt IS NULL"'; New = 'WHERE @loginId = @loginId AND UsedAt IS NULL AND RevokedAt IS NULL"'; Expect = @('T01') },
    @{ Id = 'L08_REVOKE_USED'; Old = 'AND UsedAt IS NULL AND RevokedAt IS NULL"'; New = 'AND RevokedAt IS NULL"'; Expect = @('T01') },
    @{ Id = 'L09_ERRORS_SWALLOWED'; Old = '        Finally' + $nl + '            RestoreLockWait(conn, previousWait)'; New = '        Catch ex As MySqlException' + $nl + '            Return False' + $nl + '        Finally' + $nl + '            RestoreLockWait(conn, previousWait)'; Expect = @('T08', 'T09') },
    @{ Id = 'L10_WAIT_NOT_RESTORED'; Old = '            RestoreLockWait(conn, previousWait)' + $nl + '        End Try'; New = '        End Try'; Expect = @('T09b') },
    @{ Id = 'L11_EMPTY_ACCEPTED'; Old = 'If locked.Length = 0 OrElse expected.Length = 0 Then Return False'; New = 'If False Then Return False'; Expect = @('T07') },
    # Atomicita: la revoca viene confermata prima dell'inserimento; l'inserimento fallito lascia il danno.
    @{ Id = 'L12_COMMIT_BEFORE_INSERT'; Old = '                    revoke.ExecuteNonQuery()' + $nl + '                End Using' + $nl; New = '                    revoke.ExecuteNonQuery()' + $nl + '                End Using' + $nl + '                Using early As New MySqlCommand("COMMIT", conn)' + $nl + '                    early.ExecuteNonQuery()' + $nl + '                End Using' + $nl + '                Using again As New MySqlCommand("BEGIN", conn)' + $nl + '                    again.ExecuteNonQuery()' + $nl + '                End Using' + $nl; Expect = @('T08') }
)
$bad = New-Object Collections.Generic.List[string]
foreach ($mu in $labMutants) {
    $text = [string]$files.module
    if (([regex]::Matches($text, [regex]::Escape($mu.Old))).Count -ne 1) { $bad.Add($mu.Id + ' (ancora non unica)'); continue }
    $v = Get-LabVerdict (Invoke-Lab ($text.Replace($mu.Old, $mu.New)))
    $hit = @($v.Ids | Where-Object { $mu.Expect -contains $_ })
    if ($v.State -eq 'FAIL' -and $hit.Count -gt 0) { Write-Host ('  ucciso ' + $mu.Id + ' da ' + ($hit -join ',')) }
    elseif ($v.State -eq 'INVALID') { $bad.Add($mu.Id + ' (prova non valida: ' + (($v.Text -split "`n")[0]) + ')') }
    else { $bad.Add($mu.Id + ' (sopravvissuto; falliti: ' + ($v.Ids -join ',') + ')') }
}
$last = Get-LabVerdict (Invoke-Lab $files.module)
if ($last.State -ne 'PASS') { $bad.Add('programma originale non piu verde dopo le mutazioni') }
if ($bad.Count -gt 0) { Write-Host ('RESET_ISSUE_LOCK FAIL mutazioni sul LAB: ' + ($bad -join '; ')); exit 1 }
Write-Host ('RESET_ISSUE_LOCK PASS (' + $sourceMutants.Count + ' mutanti dei sorgenti, ' + $labMutants.Count + ' mutazioni sul LAB, ' + ([regex]::Match($first.Text, 'CHECKS=\d+').Value) + ')')
exit 0
