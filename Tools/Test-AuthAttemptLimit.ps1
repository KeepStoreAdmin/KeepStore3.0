[CmdletBinding()]
param([switch]$SkipLab, [switch]$LabOnce)

# AUTH-ATTEMPT-LIMIT-1A. Limite ai tentativi sulla password: servizio (App_Code/KeepStoreAuthAttemptLimit.vb), strato web (KeepStoreAuthAttemptLimitWeb.vb),
# cablaggio nelle pagine (login, cambio password, cambio e-mail, recupero) e tabella login_attempt_limits (docs/AUTH_ATTEMPT_LIMIT_TABLE.md).
# (B) sorgenti (autonomia del servizio, tempo del database, parametri, ordine delle chiamate nelle pagine, nessun confronto di password fuori dai punti noti,
# script della pagina docs), (C) mutazioni dei sorgenti, (D) LAB locale: servizio reale su tabella creata dallo script della pagina docs, concorrenza reale con
# 30 connessioni, progressione, scadenze, pulizia, piu mutazioni del livello dati. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return ([IO.File]::ReadAllText($p, $utf8)).Replace("`r`n", "`n") } else { return '' } }

$files = @{
    svc    = Read-Repo 'App_Code/KeepStoreAuthAttemptLimit.vb'
    web    = Read-Repo 'App_Code/KeepStoreAuthAttemptLimitWeb.vb'
    login  = Read-Repo 'login.aspx.vb'
    pwd    = Read-Repo 'password.aspx.vb'
    acc    = Read-Repo 'my-account-edit.aspx.vb'
    reset  = Read-Repo 'App_Code/PasswordResetTokenService.vb'
    master = Read-Repo 'Page.master'
    doc    = Read-Repo 'docs/AUTH_ATTEMPT_LIMIT_TABLE.md'
}

function Get-Ddl([string]$doc) {
    $m = [regex]::Match($doc, 'CREATE TABLE IF NOT EXISTS login_attempt_limits \([\s\S]*?\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;')
    if ($m.Success) { return $m.Value } else { return '' }
}
function Idx([string]$text, [string]$needle) { return $text.IndexOf($needle, [StringComparison]::Ordinal) }

# Elenco dei file che leggono la colonna della password dalla vista di accesso: oggi solo la pagina di accesso e la master (percorso non raggiungibile).
$pwdReaders = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.vb -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\(\.claude|\.ai-review|\.git|Tools|obj|Bin|Public|App_Data|Database Taikun)\\' } |
    Where-Object { (Select-String -LiteralPath $_.FullName -Pattern 'Item\("Password"\)' -Quiet) } | ForEach-Object { $_.Name } | Sort-Object)

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $s = $f.svc; $w = $f.web; $l = $f.login; $p = $f.pwd; $a = $f.acc; $r = $f.reset; $d = $f.doc
    if ($s -eq '' -or $w -eq '') { $fail.Add('B0 servizio o strato web assente') }
    else {
        # B1 servizio autonomo e silenzioso; tempo del database
        if ($s -match 'HttpContext|Session\(|ConfigurationManager|Request\.|Response\.') { $fail.Add('B1 servizio non autonomo') }
        if ($s -match 'KeepStoreLog|Trace\.|Console\.|Debug\.') { $fail.Add('B1 il servizio scrive registri') }
        if ($s -match 'DateTime\.Now') { $fail.Add('B1 ora locale') }
        if (([regex]::Matches($s, 'DateTime\.UtcNow')).Count -ne 2) { $fail.Add('B1 orologio del sito usato fuori dalla sospensione') }
        if ($s -notmatch 'UTC_TIMESTAMP\(\)' -or $s -match '(?i)\bNOW\(\)|CURRENT_TIMESTAMP|SYSDATE') { $fail.Add('B1 il tempo non e quello del database') }
        if ($s -match '(?i)\bMD5\b|\bSHA1\b|New Random\(') { $fail.Add('B1 primitive non ammesse') }
        # B2 costanti e durate
        foreach ($need in 'Public Const MaxFailures As Integer = 5', 'Public Const WindowMinutes As Integer = 15', 'Public Const StrikeHours As Integer = 24', 'Public Const CleanupEvery As Integer = 50', 'Public Const CleanupRows As Integer = 200', 'Public Const CleanupAfterHours As Integer = 48', 'Public Const SuspendMinutes As Integer = 5', ', 15, 30, 60) MINUTE', ' + 1, 2), ') {
            if (-not $s.Contains($need)) { $fail.Add('B2 servizio senza: ' + $need) }
        }
        # B3 solo parametri: nessun valore di chiave nel testo SQL
        if ((($s -split "`n" | Where-Object { $_ -notmatch '"v1\|"' }) -join "`n") -match '&\s*(hash|key|companyId|loginId|scope)\b') { $fail.Add('B3 valori concatenati nello SQL') }
        if (([regex]::Matches($s, 'WHERE AziendeId = \?aziendaId AND ScopeCode = \?scope AND KeyHash = \?hash')).Count -ne 5) { $fail.Add('B3 le cinque istruzioni sulla riga devono avere azienda, scopo e impronta') }
        if ($s -notmatch 'INSERT IGNORE INTO login_attempt_limits' -or $s -notmatch 'KeyHash = \?hash FOR UPDATE') { $fail.Add('B3 prenotazione non atomica') }
        # B4 ogni operazione e protetta: errore = sospensione o degrado, mai eccezione verso la pagina
        if ($s -match '(?m)^\s*Throw\b') { $fail.Add('B4 il servizio lancia eccezioni') }
        if ($s -notmatch 'Suspend\("table-missing"\)' -or $s -notmatch 'NoteDegraded\(\)') { $fail.Add('B4 sospensione o degrado assenti') }
        # B5 strato web: chiave assente = accesa, solo "false" spegne; nessun dato nel registro
        if ($w -notmatch 'Return Not String\.Equals\(If\(value, String\.Empty\)\.Trim\(\), "false", StringComparison\.OrdinalIgnoreCase\)') { $fail.Add('B5 chiave di configurazione') }
        if ($w -notmatch 'Troppi tentativi') { $fail.Add('B5 messaggio di blocco') }
        $logLines = @($w -split "`n" | Where-Object { $_ -match 'KeepStoreLog\.' })
        if ($logLines.Count -ne 1 -or ($logLines | Where-Object { $_ -match ' & ' })) { $fail.Add('B5 il registro deve avere una sola riga fissa senza dati') }
        if ($w -match '(?m)^\s*Throw\b') { $fail.Add('B5 lo strato web lancia eccezioni') }
    }
    # B6 accesso: prenotazione PRIMA di ogni confronto, esito in Finally, chiave dal LoginId trovato
    $iReserve = Idx $l 'limitDecision = KeepStoreAuthAttemptLimitWeb.Reserve(HttpContext.Current, limitCompany, limitScope, limitKeyText)'
    $iCompare = Idx $l 'If dbPass.ToLower() <> pass.ToLower() Then'
    $iUsing = Idx $l 'Using dr As MySqlDataReader = cmd.ExecuteReader()'
    if ($iReserve -lt 0 -or $iCompare -lt 0 -or $iUsing -lt 0 -or $iReserve -gt $iCompare) { $fail.Add('B6 accesso: la prenotazione deve precedere il confronto') }
    elseif (($l.Substring($iUsing, $iReserve - $iUsing)) -cmatch 'Password|pass\.') { $fail.Add('B6 accesso: confronto di password prima della prenotazione') }
    if ((Idx $l 'limitPasswordOk = True') -lt $iCompare -or (Idx $l 'limitPasswordOk = True') -lt 0) { $fail.Add('B6 accesso: il successo si registra dopo il confronto') }
    if ($l -notmatch '(?s)Finally\s+If limitReserved Then\s+If limitPasswordOk Then\s+KeepStoreAuthAttemptLimitWeb\.Succeed\(HttpContext\.Current, limitCompany, limitScope, limitKeyText\)\s+Else\s+KeepStoreAuthAttemptLimitWeb\.Fail\(HttpContext\.Current, limitCompany, limitScope, limitKeyText\)') { $fail.Add('B6 accesso: esito (successo o errore) in Finally') }
    if ($l -notmatch 'KeepStoreAuthAttemptLimitWeb\.LoginKey\(Convert\.ToInt32\(dr\.Item\("id"\)\)\)' -or $l -notmatch 'KeepStoreAuthAttemptLimit\.NormalizeUnknownName\(user\)') { $fail.Add('B6 accesso: chiavi') }
    if ($l -notmatch '(?s)Dim limitMarker As Object = HttpContext\.Current\.Items\(LimitRequestItemKey\).*?If limitMarker Is Nothing Then\s+limitDecision = KeepStoreAuthAttemptLimitWeb\.Reserve.*?Items\(LimitRequestItemKey\) = If\(limitDecision = AttemptLimitDecision\.Blocked, "blocked", "counted"\).*?ElseIf String\.Equals\(Convert\.ToString\(limitMarker\), "blocked", StringComparison\.Ordinal\) Then\s+limitDecision = AttemptLimitDecision\.Blocked\s+Else\s+limitDecision = AttemptLimitDecision\.Inactive') { $fail.Add('B6 accesso: un solo conteggio per richiesta (il gestore gira due volte per clic)') }
    if ($l -notmatch 'limitCompany = aziendaId') { $fail.Add('B6 accesso: azienda risolta dall''host') }
    if ($l -notmatch '(?s)AttemptLimitDecision\.Blocked Then\s+lblLogin\.Text = KeepStoreAuthAttemptLimitWeb\.BlockedMessage\s+Return False') { $fail.Add('B6 accesso: messaggio e uscita del blocco') }
    # B7 cambio password
    $iR2 = Idx $p 'KeepStoreAuthAttemptLimitWeb.Reserve(HttpContext.Current, limitCompany, KeepStoreAuthAttemptLimit.ScopeCurrentPassword'
    $iV2 = Idx $p 'ValidatePasswordChange(oldPwd'
    if ($iR2 -lt 0 -or $iV2 -lt 0 -or $iR2 -gt $iV2) { $fail.Add('B7 password: la prenotazione deve precedere la verifica') }
    if ($p -notmatch '(?s)AttemptLimitDecision\.Blocked Then\s+ShowPasswordMessage\(KeepStoreAuthAttemptLimitWeb\.BlockedMessage, False\)\s+Exit Sub') { $fail.Add('B7 password: blocco') }
    if ($p -notmatch '(?s)String\.Equals\(currentPassword, oldPwd, StringComparison\.Ordinal\) Then\s+KeepStoreAuthAttemptLimitWeb\.Succeed\([^\n]*\)\s+Else\s+KeepStoreAuthAttemptLimitWeb\.Fail\(') { $fail.Add('B7 password: successo e errore') }
    # B8 cambio e-mail: prenotazione su connessione propria dopo emailChanged, errore registrato PRIMA del Return
    $iE = Idx $a 'Dim emailChanged As Boolean'
    $iR3 = Idx $a 'KeepStoreAuthAttemptLimitWeb.Reserve(HttpContext.Current, scope.CompanyId, KeepStoreAuthAttemptLimit.ScopeCurrentPassword'
    $iU = Idx $a 'Dim sqlUtente As String ='
    $iF = Idx $a 'KeepStoreAuthAttemptLimitWeb.Fail(HttpContext.Current, scope.CompanyId, KeepStoreAuthAttemptLimit.ScopeCurrentPassword'
    $iZ = Idx $a 'If emailChanged AndAlso affectedUsers = 0 Then'
    if ($iE -lt 0 -or $iR3 -lt $iE -or $iR3 -gt $iU) { $fail.Add('B8 e-mail: la prenotazione sta dopo emailChanged e prima dell''aggiornamento') }
    if ($iF -lt 0 -or $iZ -lt 0 -or $iF -gt $iZ) { $fail.Add('B8 e-mail: l''errore si registra prima del Return') }
    if ($a -notmatch '(?s)If emailChanged Then\s+Dim limitDecision As AttemptLimitDecision = KeepStoreAuthAttemptLimitWeb\.Reserve\(HttpContext\.Current, scope\.CompanyId') { $fail.Add('B8 e-mail: solo se l''e-mail cambia') }
    if (([regex]::Matches($a, 'scope\.CompanyId, KeepStoreAuthAttemptLimit\.ScopeCurrentPassword')).Count -ne 3) { $fail.Add('B8 e-mail: azienda dallo scope del profilo (3 usi)') }
    if ($a -notmatch 'KeepStoreAuthAttemptLimitWeb\.Succeed\(HttpContext\.Current, scope\.CompanyId' -or $a -notmatch '(?s)AttemptLimitDecision\.Blocked Then\s+ShowMessage\(KeepStoreAuthAttemptLimitWeb\.BlockedMessage, False\)\s+Return') { $fail.Add('B8 e-mail: successo e blocco') }
    # B9 recupero: sblocco dopo il commit
    $iFn = Idx $r 'Public Function CompleteReset'; $iC = $r.IndexOf('tx.Commit()', $iFn, [StringComparison]::Ordinal); $iK = Idx $r 'KeepStoreAuthAttemptLimitWeb.ClearLogin(HttpContext.Current, loginId)'; $iM = Idx $r 'Password aggiornata correttamente'
    if ($iC -lt 0 -or $iK -lt $iC -or $iK -gt $iM) { $fail.Add('B9 recupero: lo sblocco sta dopo il commit del recupero') }
    # B10 percorsi di accesso: la master non ha campi di accesso e solo i due file noti leggono la password della vista
    if ($f.master -match 'tbUsername|tbPassword') { $fail.Add('B10 la master ha di nuovo i campi di accesso: cablare il limite in Page.master.vb') }
    if ((($script:pwdReaders) -join ',') -ne 'login.aspx.vb,Page.master.vb') { $fail.Add('B10 file che leggono la password della vista: ' + (($script:pwdReaders) -join ',')) }
    # B11 pagina docs: script completo, nomi ASCII, stesso nome di tabella del servizio
    $ddl = Get-Ddl $d
    if ($ddl -eq '') { $fail.Add('B11 script di creazione assente nella pagina docs') }
    else {
        if ($ddl -match '[^\x20-\x7E\r\n]') { $fail.Add('B11 caratteri non ASCII nello script') }
        foreach ($need in 'AziendeId INT NOT NULL,', 'ScopeCode TINYINT NOT NULL,', 'KeyHash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,', 'FailCount INT NOT NULL DEFAULT 0,', 'WindowStartUtc DATETIME NOT NULL,', 'BlockedUntilUtc DATETIME NULL DEFAULT NULL,', 'StrikeLevel TINYINT NOT NULL DEFAULT 0,', 'StrikeExpiresUtc DATETIME NULL DEFAULT NULL,', 'UpdatedUtc DATETIME NOT NULL,', 'PRIMARY KEY (AziendeId, ScopeCode, KeyHash),', 'KEY idx_login_attempt_limits_updated (UpdatedUtc)') {
            if (-not $ddl.Contains($need)) { $fail.Add('B11 script senza: ' + $need) }
        }
        if ($ddl -match '(?i)FOREIGN KEY|DEFINER|\bUSE\b') { $fail.Add('B11 script con chiavi esterne, DEFINER o USE') }
    }
    if ($d -notmatch 'DROP TABLE IF EXISTS login_attempt_limits;' -or $d -notmatch 'NON applicato a nessun database reale') { $fail.Add('B11 pagina docs senza ritorno indietro o stato') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$labMutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLocalLabSql')
function Invoke-Lab([string]$moduleText, [string]$ddlText) {
    $credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
    $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $bin = Join-Path $root 'Bin'
    $work = Join-Path $env:TEMP ('ks-attemptlimit-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    $held = $false
    try {
        foreach ($dep in 'MySql.Data.dll', 'Google.Protobuf.dll', 'BouncyCastle.Cryptography.dll', 'System.Buffers.dll', 'System.Memory.dll', 'System.Numerics.Vectors.dll', 'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll', 'K4os.Compression.LZ4.dll', 'K4os.Compression.LZ4.Streams.dll', 'K4os.Hash.xxHash.dll', 'ZstdSharp.dll', 'System.Configuration.ConfigurationManager.dll') {
            if (Test-Path -LiteralPath (Join-Path $bin $dep)) { Copy-Item -LiteralPath (Join-Path $bin $dep) -Destination $work -Force }
        }
        $cfg = '<?xml version="1.0" encoding="utf-8"?><configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/></startup><runtime><assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">' +
            '<dependentAssembly><assemblyIdentity name="System.Threading.Tasks.Extensions" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.2.4.0" newVersion="4.2.4.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Buffers" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Memory" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Runtime.CompilerServices.Unsafe" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-6.0.3.0" newVersion="6.0.3.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Numerics.Vectors" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.1.6.0" newVersion="4.1.6.0"/></dependentAssembly>' +
            '</assemblyBinding></runtime></configuration>'
        $exe = Join-Path $work 'AuthAttemptLimitHarness.exe'
        $modFile = Join-Path $work 'KeepStoreAuthAttemptLimit.vb'
        $ddlFile = Join-Path $work 'ddl.sql'
        [IO.File]::WriteAllText($exe + '.config', $cfg, $utf8)
        [IO.File]::WriteAllText($modFile, $moduleText, $utf8)
        [IO.File]::WriteAllText($ddlFile, $ddlText, $utf8)
        $ref = '/reference:' + (Join-Path $bin 'MySql.Data.dll')
        $build = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ /out:$exe $ref /reference:System.dll /reference:System.Data.dll /reference:System.Core.dll (Join-Path $root 'Tools\AuthAttemptLimitHarness.vb') $modFile 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { return ('COMPILE_ERROR ' + (($build | Select-Object -First 4) -join ' | ')) }
        try { $held = $labMutex.WaitOne(600000) } catch [System.Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { return 'LAB_BUSY' }
        $cred = Import-Clixml -LiteralPath $credFile
        $plain = $cred.GetNetworkCredential().Password
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $exe; $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.CreateNoWindow = $true
        $info.EnvironmentVariables['KS_LAB_USER'] = $cred.UserName
        $info.EnvironmentVariables['KS_LAB_PWD'] = $plain
        $info.EnvironmentVariables['KS_AUTH_DDL'] = $ddlFile
        $proc = [Diagnostics.Process]::Start($info)
        $stdout = $proc.StandardOutput.ReadToEnd(); $stderr = $proc.StandardError.ReadToEnd(); $proc.WaitForExit()
        if ($plain) { $stdout = $stdout.Replace($plain, '<hidden>') }
        $plain = $null; $cred = $null
        return ((@($stdout -split "`r?`n" | Where-Object { $_ -match '^(FAIL|HARNESS_ERROR|AUTH_ATTEMPT_LIMIT_LAB)' })) -join "`n")
    } finally {
        if ($held) { try { $labMutex.ReleaseMutex() } catch { } }
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$okSource = Test-Source $files
if (-not $okSource) { Write-Host 'AUTH_ATTEMPT_LIMIT FAIL'; exit 1 }

$sourceMutants = @(
    @{ Id = 'M01_THRESHOLD_6'; File = 'svc'; Old = 'Public Const MaxFailures As Integer = 5'; New = 'Public Const MaxFailures As Integer = 6' },
    @{ Id = 'M02_APP_CLOCK'; File = 'svc'; Old = 'Private Shared Sub NoteDegraded()'; New = "Private Shared Function ClockMut() As DateTime`n        Return DateTime.UtcNow`n    End Function`n    Private Shared Sub NoteDegraded()" },
    @{ Id = 'M03_LOG_IN_SERVICE'; File = 'svc'; Old = 'Private Shared Sub NoteDegraded()'; New = "Private Shared Sub LogMut()`n        KeepStoreLog.Error(`"x`", `"y`", Nothing, Nothing)`n    End Sub`n    Private Shared Sub NoteDegraded()" },
    @{ Id = 'M04_WEB_CONTEXT_IN_SERVICE'; File = 'svc'; Old = 'Private Shared Sub NoteDegraded()'; New = "Private Shared Function CtxMut() As Object`n        Return System.Web.HttpContext.Current`n    End Function`n    Private Shared Sub NoteDegraded()" },
    @{ Id = 'M05_KEY_CONCATENATED'; File = 'svc'; Old = '"FROM login_attempt_limits WHERE AziendeId = ?aziendaId AND ScopeCode = ?scope AND KeyHash = ?hash FOR UPDATE"'; New = '"FROM login_attempt_limits WHERE AziendeId = ?aziendaId AND ScopeCode = ?scope AND KeyHash = " & hash & " FOR UPDATE"' },
    @{ Id = 'M06_RELEASE_WITHOUT_COMPANY'; File = 'svc'; Old = '"WHERE AziendeId = ?aziendaId AND ScopeCode = ?scope AND KeyHash = ?hash AND (BlockedUntilUtc IS NULL OR BlockedUntilUtc <= UTC_TIMESTAMP())")'; New = '"WHERE ScopeCode = ?scope AND KeyHash = ?hash AND (BlockedUntilUtc IS NULL OR BlockedUntilUtc <= UTC_TIMESTAMP())")' },
    @{ Id = 'M07_NOW_INSTEAD_OF_UTC'; File = 'svc'; Old = '"UPDATE login_attempt_limits SET FailCount = 0, BlockedUntilUtc = NULL, StrikeLevel = 0, StrikeExpiresUtc = NULL, UpdatedUtc = UTC_TIMESTAMP() "'; New = '"UPDATE login_attempt_limits SET FailCount = 0, BlockedUntilUtc = NULL, StrikeLevel = 0, StrikeExpiresUtc = NULL, UpdatedUtc = NOW() "' },
    @{ Id = 'M08_DURATIONS_CHANGED'; File = 'svc'; Old = ', 15, 30, 60) MINUTE'; New = ', 15, 15, 15) MINUTE' },
    @{ Id = 'M09_THROWS'; File = 'svc'; Old = "            Catch ex As Exception`n                Remember(ex)`n                If IsTableMissing(ex) Then`n                    Suspend(`"table-missing`")`n                    Return AttemptLimitDecision.Inactive`n                End If"; New = "            Catch ex As Exception`n                Remember(ex)`n                If IsTableMissing(ex) Then`n                    Throw`n                End If" },
    @{ Id = 'M10_WEB_DEFAULT_OFF'; File = 'web'; Old = 'Return Not String.Equals(If(value, String.Empty).Trim(), "false", StringComparison.OrdinalIgnoreCase)'; New = 'Return String.Equals(If(value, String.Empty).Trim(), "true", StringComparison.OrdinalIgnoreCase)' },
    @{ Id = 'M11_WEB_LOG_WITH_DATA'; File = 'web'; Old = 'unchecked."), Nothing, context)'; New = 'unchecked." & context.Request.UserHostAddress), Nothing, context)' },
    @{ Id = 'M12_WEB_THROWS'; File = 'web'; Old = "        Catch`n            Return AttemptLimitDecision.Inactive`n        End Try"; New = "        Catch`n            Throw`n        End Try" },
    @{ Id = 'P01_LOGIN_NO_RESERVE'; File = 'login'; Old = 'limitDecision = KeepStoreAuthAttemptLimitWeb.Reserve(HttpContext.Current, limitCompany, limitScope, limitKeyText)'; New = 'limitDecision = AttemptLimitDecision.Allowed' },
    @{ Id = 'P22_LOGIN_COUNTS_TWICE_PER_REQUEST'; File = 'login'; Old = 'If limitMarker Is Nothing Then'; New = 'If True Then' },
    @{ Id = 'P23_LOGIN_SECOND_CALL_NOT_BLOCKED'; File = 'login'; Old = "ElseIf String.Equals(Convert.ToString(limitMarker), `"blocked`", StringComparison.Ordinal) Then`n                            limitDecision = AttemptLimitDecision.Blocked"; New = "ElseIf String.Equals(Convert.ToString(limitMarker), `"blocked`", StringComparison.Ordinal) Then`n                            limitDecision = AttemptLimitDecision.Inactive" },
    @{ Id = 'P02_LOGIN_COMPARE_BEFORE_RESERVE'; File = 'login'; Old = "                    Dim rowFound As Boolean = dr.Read()`n"; New = "                    Dim rowFound As Boolean = dr.Read()`n                    Dim earlyMut As Boolean = rowFound AndAlso dr.Item(`"Password`").ToString().ToLower() = pass.ToLower()`n" },
    @{ Id = 'P03_LOGIN_SUCCESS_NOT_RECORDED'; File = 'login'; Old = "                    limitPasswordOk = True`n"; New = '' },
    @{ Id = 'P04_LOGIN_SUCCESS_BEFORE_COMPARE'; File = 'login'; Old = "                    Dim rowFound As Boolean = dr.Read()`n"; New = "                    limitPasswordOk = True`n                    Dim rowFound As Boolean = dr.Read()`n" },
    @{ Id = 'P05_LOGIN_BLOCKED_MESSAGE_GENERIC'; File = 'login'; Old = 'lblLogin.Text = KeepStoreAuthAttemptLimitWeb.BlockedMessage'; New = 'lblLogin.Text = GenericLoginFailureMessage' },
    @{ Id = 'P06_LOGIN_UNKNOWN_KEY_RAW'; File = 'login'; Old = 'KeepStoreAuthAttemptLimit.NormalizeUnknownName(user))'; New = 'user)' },
    @{ Id = 'P07_LOGIN_FOUND_KEY_FROM_TYPED_NAME'; File = 'login'; Old = 'KeepStoreAuthAttemptLimitWeb.LoginKey(Convert.ToInt32(dr.Item("id")))'; New = 'KeepStoreAuthAttemptLimit.NormalizeUnknownName(user)' },
    @{ Id = 'P08_LOGIN_FIXED_COMPANY'; File = 'login'; Old = 'limitCompany = aziendaId'; New = 'limitCompany = 1' },
    @{ Id = 'P09_LOGIN_NO_FAIL_IN_FINALLY'; File = 'login'; Old = "                Else`n                    KeepStoreAuthAttemptLimitWeb.Fail(HttpContext.Current, limitCompany, limitScope, limitKeyText)`n"; New = "                Else`n" },
    @{ Id = 'P10_PWD_NO_RESERVE'; File = 'pwd'; Old = 'KeepStoreAuthAttemptLimitWeb.Reserve(HttpContext.Current, limitCompany, KeepStoreAuthAttemptLimit.ScopeCurrentPassword, KeepStoreAuthAttemptLimitWeb.LoginKey(loginIdValue))'; New = 'AttemptLimitDecision.Allowed' },
    @{ Id = 'P11_PWD_VALIDATE_BEFORE_RESERVE'; File = 'pwd'; Old = "                Dim limitCompany As Integer = StorefrontCommercialIsolationPolicy"; New = "                Dim validateFirst As Boolean = ValidatePasswordChange(oldPwd, newPwd, newPwd2, currentPassword, validationMessage)`n                Dim limitCompany As Integer = StorefrontCommercialIsolationPolicy" },
    @{ Id = 'P12_PWD_BLOCKED_CONTINUES'; File = 'pwd'; Old = "ShowPasswordMessage(KeepStoreAuthAttemptLimitWeb.BlockedMessage, False)`n                        Exit Sub"; New = 'ShowPasswordMessage(KeepStoreAuthAttemptLimitWeb.BlockedMessage, False)' },
    @{ Id = 'P13_PWD_NO_SUCCESS'; File = 'pwd'; Old = "                            KeepStoreAuthAttemptLimitWeb.Succeed(HttpContext.Current, limitCompany, KeepStoreAuthAttemptLimit.ScopeCurrentPassword, KeepStoreAuthAttemptLimitWeb.LoginKey(loginIdValue))`n"; New = '' },
    @{ Id = 'P14_ACC_NO_FAIL'; File = 'acc'; Old = 'KeepStoreAuthAttemptLimitWeb.Fail(HttpContext.Current, scope.CompanyId,'; New = 'KeepStoreAuthAttemptLimitWeb.Release(HttpContext.Current, scope.CompanyId,' },
    @{ Id = 'P15_ACC_FIXED_COMPANY'; File = 'acc'; Old = 'KeepStoreAuthAttemptLimitWeb.Reserve(HttpContext.Current, scope.CompanyId,'; New = 'KeepStoreAuthAttemptLimitWeb.Reserve(HttpContext.Current, 1,' },
    @{ Id = 'P16_ACC_ALWAYS_RESERVES'; File = 'acc'; Old = "                    If emailChanged Then`n                        Dim limitDecision"; New = "                    If True Then`n                        Dim limitDecision" },
    @{ Id = 'P17_ACC_NO_RESERVE'; File = 'acc'; Old = 'KeepStoreAuthAttemptLimitWeb.Reserve(HttpContext.Current, scope.CompanyId, KeepStoreAuthAttemptLimit.ScopeCurrentPassword, KeepStoreAuthAttemptLimitWeb.LoginKey(loginId))'; New = 'AttemptLimitDecision.Allowed' },
    @{ Id = 'P18_ACC_BLOCKED_CONTINUES'; File = 'acc'; Old = "ShowMessage(KeepStoreAuthAttemptLimitWeb.BlockedMessage, False)`n                            Return"; New = 'ShowMessage(KeepStoreAuthAttemptLimitWeb.BlockedMessage, False)' },
    @{ Id = 'P19_RESET_NO_CLEAR'; File = 'reset'; Old = "                    KeepStoreAuthAttemptLimitWeb.ClearLogin(HttpContext.Current, loginId)`n"; New = '' },
    @{ Id = 'P20_RESET_CLEAR_BEFORE_COMMIT'; File = 'reset'; Old = "                    MarkTokenUsed(conn, tx, tokenHash)`n"; New = "                    KeepStoreAuthAttemptLimitWeb.ClearLogin(HttpContext.Current, loginId)`n                    MarkTokenUsed(conn, tx, tokenHash)`n" },
    @{ Id = 'P21_MASTER_LOGIN_FIELDS_BACK'; File = 'master'; Old = '<%@ Master'; New = '<asp:TextBox ID="tbUsername" runat="server" /><%@ Master' },
    @{ Id = 'M13_DOC_HASH_CASE_INSENSITIVE'; File = 'doc'; Old = 'KeyHash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL'; New = 'KeyHash CHAR(64) NOT NULL' },
    @{ Id = 'M14_DOC_PK_WITHOUT_COMPANY'; File = 'doc'; Old = 'PRIMARY KEY (AziendeId, ScopeCode, KeyHash),'; New = 'PRIMARY KEY (ScopeCode, KeyHash),' },
    @{ Id = 'M15_DOC_ROLLBACK_LOST'; File = 'doc'; Old = 'DROP TABLE IF EXISTS login_attempt_limits;'; New = '' },
    @{ Id = 'M16_DOC_FOREIGN_KEY'; File = 'doc'; Old = '  PRIMARY KEY (AziendeId, ScopeCode, KeyHash),'; New = '  FOREIGN KEY (AziendeId) REFERENCES aziende (id), PRIMARY KEY (AziendeId, ScopeCode, KeyHash),' },
    @{ Id = 'M17_DOC_NON_ASCII'; File = 'doc'; Old = 'FailCount INT NOT NULL DEFAULT 0,'; New = "FailCount INT NOT NULL DEFAULT 0, -- perch$([char]0x00E9)" },
    @{ Id = 'M18_DOC_STATE_LOST'; File = 'doc'; Old = 'NON applicato a nessun database reale'; New = 'applicato' }
)
$labMutants = @(
    @{ Id = 'D01_THRESHOLD_6'; Old = 'Public Const MaxFailures As Integer = 5'; New = 'Public Const MaxFailures As Integer = 6' },
    @{ Id = 'D02_WINDOW_NEVER_EXPIRES'; Old = 'Dim reset As Boolean = blockExpired OrElse windowExpired'; New = 'Dim reset As Boolean = blockExpired' },
    @{ Id = 'D03_BLOCK_NOT_CHECKED_FIRST'; Old = '                If blocked Then'; New = '                If False Then' },
    @{ Id = 'D04_FAIL_EXTENDS_BLOCK'; Old = '& " AND (BlockedUntilUtc IS NULL OR BlockedUntilUtc <= UTC_TIMESTAMP())")'; New = '& "")' },
    @{ Id = 'D05_STRIKE_NOT_CAPPED'; Old = 'StrikeLevel = LEAST(IF(StrikeExpiresUtc IS NOT NULL AND StrikeExpiresUtc <= UTC_TIMESTAMP(), 0, StrikeLevel) + 1, 2), '; New = 'StrikeLevel = IF(StrikeExpiresUtc IS NOT NULL AND StrikeExpiresUtc <= UTC_TIMESTAMP(), 0, StrikeLevel) + 1, ' },
    @{ Id = 'D06_DURATIONS_FLAT'; Old = ', 15, 30, 60) MINUTE'; New = ', 15, 15, 15) MINUTE' },
    @{ Id = 'D07_SUCCESS_KEEPS_STRIKES'; Old = 'FailCount = 0, BlockedUntilUtc = NULL, StrikeLevel = 0, StrikeExpiresUtc = NULL, UpdatedUtc'; New = 'FailCount = 0, BlockedUntilUtc = NULL, UpdatedUtc' },
    @{ Id = 'D08_RELEASE_NEGATIVE'; Old = 'GREATEST(FailCount - 1, 0)'; New = '(FailCount - 1)' },
    @{ Id = 'D09_SUCCESS_ALL_COMPANIES'; Old = '"WHERE AziendeId = ?aziendaId AND ScopeCode = ?scope AND KeyHash = ?hash")'; New = '"WHERE ScopeCode = ?scope AND KeyHash = ?hash")' },
    @{ Id = 'D10_CLEANUP_DELETES_ACTIVE_BLOCKS'; Old = '"AND (BlockedUntilUtc IS NULL OR BlockedUntilUtc < UTC_TIMESTAMP()) ORDER BY UpdatedUtc LIMIT "'; New = '"ORDER BY UpdatedUtc LIMIT "' },
    @{ Id = 'D11_CLEANUP_UNLIMITED'; Old = 'ORDER BY UpdatedUtc LIMIT " & CleanupRows.ToString(CultureInfo.InvariantCulture)'; New = 'ORDER BY UpdatedUtc LIMIT 100000"' },
    @{ Id = 'D12_CLEANUP_EVERY_49'; Old = 'Public Const CleanupEvery As Integer = 50'; New = 'Public Const CleanupEvery As Integer = 49' },
    @{ Id = 'D13_RESET_KEEPS_OLD_BLOCK'; Old = 'If(reset, "WindowStartUtc = UTC_TIMESTAMP(), BlockedUntilUtc = NULL, ", String.Empty)'; New = 'If(reset, "WindowStartUtc = UTC_TIMESTAMP(), ", String.Empty)' },
    @{ Id = 'D14_STRIKE_EXPIRY_IGNORED'; Old = 'IF(StrikeExpiresUtc IS NOT NULL AND StrikeExpiresUtc <= UTC_TIMESTAMP(), 0, StrikeLevel)'; New = 'StrikeLevel' },
    @{ Id = 'D15_RELEASE_ON_BLOCKED'; Old = 'AND KeyHash = ?hash AND (BlockedUntilUtc IS NULL OR BlockedUntilUtc <= UTC_TIMESTAMP())")'; New = 'AND KeyHash = ?hash")' },
    @{ Id = 'D16_CLEAR_WRONG_SCOPE'; Old = 'ComputeKeyHash(ScopeLogin, loginId.ToString('; New = 'ComputeKeyHash(ScopeCurrentPassword, loginId.ToString(' },
    @{ Id = 'D17_NAME_CASE_SENSITIVE'; Old = 'Return If(typed, String.Empty).Trim().ToLowerInvariant()'; New = 'Return If(typed, String.Empty).Trim()' },
    @{ Id = 'D18_COMPANY_NOT_VALIDATED'; Old = 'companyId > 0 AndAlso scope >= ScopeLogin'; New = 'scope >= ScopeLogin' },
    @{ Id = 'D19_TABLE_MISSING_NOT_DETECTED'; Old = 'Return mysql IsNot Nothing AndAlso mysql.Number = MySqlTableMissing'; New = 'Return False' },
    @{ Id = 'D20_DEGRADED_BLOCKS'; Old = "                NoteDegraded()`n                Return AttemptLimitDecision.Inactive"; New = "                NoteDegraded()`n                Return AttemptLimitDecision.Blocked" },
    @{ Id = 'D21_NO_ROW_LOCK'; Old = 'KeyHash = ?hash FOR UPDATE"'; New = 'KeyHash = ?hash"' },
    @{ Id = 'D22_PLAIN_INSERT'; Old = 'INSERT IGNORE INTO'; New = 'INSERT INTO' },
    @{ Id = 'D23_SUCCESS_KEEPS_COUNT'; Old = 'SET FailCount = 0, BlockedUntilUtc = NULL, StrikeLevel = 0'; New = 'SET FailCount = FailCount, BlockedUntilUtc = NULL, StrikeLevel = 0' },
    @{ Id = 'D24_WINDOW_1_MINUTE'; Old = 'Public Const WindowMinutes As Integer = 15'; New = 'Public Const WindowMinutes As Integer = 1' },
    @{ Id = 'D25_FAIL_AT_ONE'; Old = '"AND FailCount >= " & MaxFailures.ToString(CultureInfo.InvariantCulture)'; New = '"AND FailCount >= 1"' },
    @{ Id = 'D26_PENDING_NOT_COUNTED'; Old = 'If Not reset AndAlso failCount >= MaxFailures Then'; New = 'If False Then' },
    @{ Id = 'D27_HASH_FROM_COMPANY_ONLY'; Old = 'Dim text As String = "v1|" & scope.ToString(CultureInfo.InvariantCulture) & "|" & If(key, String.Empty)'; New = 'Dim text As String = "v1|" & scope.ToString(CultureInfo.InvariantCulture)' },
    @{ Id = 'D28_SUSPEND_NEVER'; Old = '_suspendedUntilUtc = DateTime.UtcNow.AddMinutes(SuspendMinutes)'; New = '_suspendedUntilUtc = DateTime.MinValue' }
)
if (($sourceMutants.Count + $labMutants.Count) -lt 60) { Write-Host 'AUTH_ATTEMPT_LIMIT FAIL (pochi mutanti)'; exit 1 }
$bad = 0
foreach ($mu in $sourceMutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'AUTH_ATTEMPT_LIMIT FAIL (mutanti dei sorgenti)'; exit 1 }

$labNote = 'LAB saltato'
if (-not $SkipLab) {
    $labUp = $false
    try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 13317); $labUp = $t.Connected; $t.Close() } catch { $labUp = $false }
    if (-not ((Test-Path -LiteralPath (Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml')) -and (Test-Path -LiteralPath (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe')) -and $labUp)) {
        $labNote = 'LAB non disponibile su questa macchina: parte (D) NON ESEGUITA'
    } else {
        $ddl = Get-Ddl $files.doc
        $result = Invoke-Lab $files.svc $ddl
        $summary = @($result -split "`n" | Where-Object { $_ -match '^AUTH_ATTEMPT_LIMIT_LAB ' }) | Select-Object -Last 1
        if ($summary -notmatch 'FAIL=0$') { $result -split "`n" | ForEach-Object { Write-Host ('  ' + $_) }; Write-Host 'AUTH_ATTEMPT_LIMIT FAIL (LAB)'; exit 1 }
        if ($LabOnce) { Write-Host ('AUTH_ATTEMPT_LIMIT LAB ONCE ' + $summary); exit 0 }
        foreach ($mu in $labMutants) {
            if (-not $files.svc.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
            $r = Invoke-Lab ($files.svc.Replace($mu.Old, $mu.New)) $ddl
            $s = @($r -split "`n" | Where-Object { $_ -match '^AUTH_ATTEMPT_LIMIT_LAB ' }) | Select-Object -Last 1
            if ($r -match 'COMPILE_ERROR|LAB_BUSY') { Write-Host ('  MUTANT_INVALID ' + $mu.Id + ' ' + $r); $bad++; continue }
            if ($s -match 'FAIL=0$') { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
        }
        if ($bad -gt 0) { Write-Host 'AUTH_ATTEMPT_LIMIT FAIL (mutanti LAB)'; exit 1 }
        $final = Invoke-Lab $files.svc $ddl
        if ((@($final -split "`n" | Where-Object { $_ -match '^AUTH_ATTEMPT_LIMIT_LAB ' }) | Select-Object -Last 1) -notmatch 'FAIL=0$') { $final -split "`n" | ForEach-Object { Write-Host ('  ' + $_) }; Write-Host 'AUTH_ATTEMPT_LIMIT FAIL (LAB finale)'; exit 1 }
        $labNote = $summary + ', ' + $labMutants.Count + ' mutazioni del livello dati sul LAB'
    }
}
Write-Host ('AUTH_ATTEMPT_LIMIT PASS (' + ($sourceMutants.Count + $labMutants.Count) + ' mutanti; ' + $labNote + ')')
exit 0
