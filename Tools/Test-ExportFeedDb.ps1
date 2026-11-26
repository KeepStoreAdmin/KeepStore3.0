[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$SkipHarness)

# EXPORT-FEED-GESTIONALE-1A (migrazione EXPORT-FEED-DB-2A, che sostituisce la 1A mai applicata). Prova degli script di docs/EXPORT_FEED_DB_SCRIPTS.md sul LAB locale:
#  - preflight, forward, verify, rollback eseguiti dagli script REALI (nessuna copia di prova), sul database LAB (identita verificata da Invoke-KeepStoreLabSql);
#  - la tabella export, le routine esistenti (Newexport, Modexport, Delexport, Newexport_filtri), il loro registro in sysparametristored, export_filtri NON cambiano;
#  - una riga di export_opzioni per ogni feed esistente, con codice del link distinto creato dal database; un codice errato o duplicato e rifiutato; SET TokenAccesso = DEFAULT lo rinnova;
#  - il forward si rilancia (idempotente: nessuna riga doppia nel registro) e riprende dopo OGNI interruzione (script fermato prima di ciascun passo -- STEP n); il rollback riporta lo stato iniziale;
#  - rifiuto del rollback senza conferma, arresto con binlog STATEMENT (condizione sostituita: il LAB ha log_bin=0), verify che si ferma se i dati o il registro sono corrotti;
#  - il programma Tools\ExportFeedGestionaleHarness.vb (connettore .NET, registro REALE, stessa logica di AggiungiDati/ExecStoreTrnNoCommit del gestionale) salva, modifica, duplica;
#  - mutazioni degli script (una modifica per volta): la prova deve fallire.
# Scrive solo righe sintetiche (KSGESTHARNESS%) e gli oggetti della migrazione, riportati allo stato iniziale dal rollback. Solo ASCII (Windows PowerShell 5.1).
# Durata circa 8 minuti: con Tools\Run-KeepStoreRelatedTests.ps1 serve -TimeoutSec 1800.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$scriptsDoc = Join-Path $root 'docs\EXPORT_FEED_DB_SCRIPTS.md'
$prefix = '20261126_EXPORT_FEED_DB_2A_'
$labSql = Join-Path $root 'Tools\Invoke-KeepStoreLabSql.ps1'
$tmp = Join-Path $env:TEMP ('ks-exportfeeddb-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$migDir = Join-Path $tmp 'mig'
New-Item -ItemType Directory -Force -Path $migDir | Out-Null
$docText = [IO.File]::ReadAllText($scriptsDoc, $utf8)
foreach ($k in @('preflight', 'forward', 'verify', 'rollback')) {
    $m = [regex]::Match($docText, '(?s)## ' + [regex]::Escape($prefix + $k) + '\.sql\r?\n\r?\n```sql\r?\n(.*?)```')
    if ($m.Success) { [IO.File]::WriteAllText((Join-Path $migDir ($prefix + $k + '.sql')), ($m.Groups[1].Value -replace '\r\n', "`n"), $utf8) }
}
$confirm = 'SET @KeepStoreConfirmDropFeedData=1;' + "`n"
$names = "'Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice'"

function Invoke-Sql([string]$sql, [switch]$Write) {
    $f = Join-Path $tmp ('q' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($f, $sql, $utf8)
    try {
        if ($Write) { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f -Write 2>&1 }
        else { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f 2>&1 }
        return (@($o) | ForEach-Object { [string]$_ }) -join "`n"
    } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Failed([string]$out) { return ($out -match '(?m)^stderr:' -or $out -match 'ERROR \d+' -or $out -notmatch 'client exit=0') }
function Get-Scalar([string]$sql) {
    $o = (Invoke-Sql $sql) -split "`n"
    for ($i = 0; $i -lt $o.Count - 1; $i++) { if ($o[$i].Trim() -eq 'ksval') { return $o[$i + 1].Trim() } }
    return ''
}
function Read-Mig([string]$kind) { return [IO.File]::ReadAllText((Join-Path $migDir ($prefix + $kind + '.sql')), $utf8) }
# Fotografia di cio che la migrazione NON deve cambiare: export (colonne, righe), le routine esistenti (definizione), il loro registro, export_filtri, exportcampi senza la voce nostra.
function Get-Snapshot {
    return Get-Scalar ("SELECT CONCAT_WS('#', " +
        "(SELECT SHA2(IFNULL(GROUP_CONCAT(CONCAT_WS(':', COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, IFNULL(COLUMN_DEFAULT, 'NULL'), IFNULL(COLLATION_NAME, '-'), EXTRA) ORDER BY ORDINAL_POSITION SEPARATOR '|'), ''), 256) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export')," +
        "(SELECT COUNT(*) FROM export)," +
        "(SELECT SHA2(IFNULL(GROUP_CONCAT(CONCAT_WS(':', ROUTINE_NAME, SHA2(ROUTINE_DEFINITION, 256), DEFINER) ORDER BY ROUTINE_NAME SEPARATOR '|'), ''), 256) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME IN ('Newexport', 'Modexport', 'Delexport', 'Newexport_filtri'))," +
        "(SELECT SHA2(IFNULL(GROUP_CONCAT(CONCAT_WS(':', NomeStore, NomeParametro, Tipo, Lunghezza, Direzione) ORDER BY NomeStore, id SEPARATOR '|'), ''), 256) FROM sysparametristored WHERE NomeStore IN ('Newexport', 'Modexport', 'Delexport', 'Newexport_filtri'))," +
        "(SELECT COUNT(*) FROM sysparametristored)," +
        "(SELECT COUNT(*) FROM export_filtri)," +
        "(SELECT COUNT(*) FROM exportcampi)," +
        "(SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_opzioni', 'export_stato', 'export_colonne'))," +
        "(SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME IN (" + $names + "))) AS ksval;")
}
$e2e = New-Object Collections.Generic.List[string]
function Check([bool]$ok, [string]$name) {
    if ($ok) { Write-Host ('  ok   ' + $name) } else { Write-Host ('  FAIL ' + $name); $e2e.Add($name) }
}
function Get-ForwardUpTo([string]$text, [int]$upTo) {
    $ms = [regex]::Matches($text, '(?m)^-- STEP (\d+)')
    if ($upTo -ge $ms.Count) { return $text }
    return $text.Substring(0, $ms[$upTo].Index)
}
function Count-Steps([string]$text) { return [regex]::Matches($text, '(?m)^-- STEP (\d+)').Count }
function Run-Rollback([string]$rollbackText) { return Invoke-Sql ($confirm + $rollbackText) -Write }
function Remove-TestRows { $null = Invoke-Sql "DELETE FROM export_filtri WHERE ExportId IN (SELECT ID FROM export WHERE Descrizione LIKE 'KSGESTHARNESS%'); DELETE FROM export WHERE Descrizione LIKE 'KSGESTHARNESS%'; DELETE FROM exportcampi WHERE NomeCampo = 'CategoriaPercorsoX'; DELETE FROM export_filtri WHERE ExportId = 0;" -Write }

# --- programma .NET che simula il gestionale ---
function Run-Harness {
    $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $bin = Join-Path $root 'Bin'
    $work = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $work | Out-Null
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
    $exe = Join-Path $work 'h.exe'
    [IO.File]::WriteAllText($exe + '.config', $cfg, $utf8)
    $b = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ ('/out:' + $exe) ('/reference:' + (Join-Path $bin 'MySql.Data.dll')) /reference:System.dll /reference:System.Data.dll /reference:System.Core.dll (Join-Path $root 'Tools\ExportFeedGestionaleHarness.vb') 2>&1
    if (-not (Test-Path -LiteralPath $exe)) { return @{ Out = ('COMPILE_ERROR ' + (($b | Select-Object -First 4) -join ' | ')); Code = -1 } }
    $credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
    $cred = Import-Clixml -LiteralPath $credFile
    $plain = $cred.GetNetworkCredential().Password
    $schema = Get-Scalar 'SELECT DATABASE() AS ksval;'
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $exe; $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.CreateNoWindow = $true
    $info.EnvironmentVariables['KS_LAB_USER'] = $cred.UserName
    $info.EnvironmentVariables['KS_LAB_PWD'] = $plain
    $info.EnvironmentVariables['KS_LAB_SCHEMA'] = $schema
    $proc = [Diagnostics.Process]::Start($info)
    $stdout = $proc.StandardOutput.ReadToEnd(); $stderr = $proc.StandardError.ReadToEnd(); $proc.WaitForExit()
    if ($plain) { $stdout = $stdout.Replace($plain, '<hidden>'); $stderr = $stderr.Replace($plain, '<hidden>') }
    $plain = $null; $cred = $null
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    return @{ Out = $stdout + $stderr; Code = $proc.ExitCode }
}

# Applica forward (una o due volte), verify e harness: restituisce l'elenco dei guasti (vuoto = tutto passa).
function Exercise([string]$forwardText, [int]$times = 2) {
    $fails = New-Object Collections.Generic.List[string]
    for ($i = 1; $i -le $times; $i++) {
        $f = Invoke-Sql $forwardText -Write
        if ($f -notmatch 'EXPORT_FEED_DB_FORWARD_OK') { $fails.Add('forward ' + $i + ' senza FORWARD_OK'); return $fails.ToArray() }
    }
    $v = Invoke-Sql (Read-Mig 'verify')
    if ($v -notmatch 'EXPORT_FEED_DB_VERIFY_OK') { $fails.Add('verify: ' + (@($v -split "`n" | Where-Object { $_ -match "`tKO$" } | ForEach-Object { $_.Split("`t")[0] }) -join ',')) }
    if (-not $SkipHarness) {
        $h = Run-Harness
        if ($h.Code -ne 0) { $fails.Add('harness: ' + (@($h.Out -split "`r?`n" | Where-Object { $_ -cmatch '^(FAIL |HARNESS_ERROR|COMPILE_ERROR)' } | Select-Object -First 3) -join ' | ')) }
    }
    return $fails.ToArray()
}

$exit = 0
try {
    $uuid = Get-Scalar 'SELECT @@server_uuid AS ksval;'
    if ($uuid -ne '1167ebae-d0c0-11f1-b348-9c7bef540c10') { throw 'NOT_THE_LAB' }
    Remove-TestRows
    $forward = Read-Mig 'forward'; $rollback = Read-Mig 'rollback'; $verify = Read-Mig 'verify'; $preflight = Read-Mig 'preflight'
    if ($forward -eq '' -or $rollback -eq '' -or $verify -eq '' -or $preflight -eq '') { throw 'SCRIPTS_NOT_FOUND_IN_DOC' }
    $initial = Get-Snapshot
    if ($initial -notmatch '#0#0$') { throw 'LAB_NOT_IN_INITIAL_STATE (eseguire il rollback prima di provare)' }
    $nSteps = Count-Steps $forward
    Check ($nSteps -eq 8) ('il forward ha 8 passi (visti ' + $nSteps + ')')

    # --- preflight, forward, verify ---
    $pf = Invoke-Sql $preflight
    Check ($pf -match 'EXPORT_FEED_DB_PREFLIGHT_OK' -and -not (Failed $pf)) 'preflight: PREFLIGHT_OK'
    $f1 = Invoke-Sql $forward -Write
    Check (-not (Failed $f1) -and $f1 -match 'EXPORT_FEED_DB_FORWARD_OK') 'forward: FORWARD_OK'
    $v1 = Invoke-Sql $verify
    Check ($v1 -match 'EXPORT_FEED_DB_VERIFY_OK' -and $v1 -notmatch "`tKO") 'verify: tutte OK e VERIFY_OK'
    $afterSnap = Get-Snapshot
    $a = $initial.Split('#'); $b = $afterSnap.Split('#')
    Check ($a[0] -eq $b[0] -and $a[1] -eq $b[1]) 'export: colonne e righe IDENTICHE a prima (il gestionale attuale non vede differenze)'
    Check ($a[2] -eq $b[2] -and $a[3] -eq $b[3]) 'routine esistenti e loro registro IDENTICI a prima (nessuna routine esistente cambia)'
    Check ($a[5] -eq $b[5] -and ([int]$b[6] -eq [int]$a[6] + 1)) 'export_filtri invariata; exportcampi ha una voce in piu (CategoriaPercorso)'
    Check ([int]$b[4] -gt [int]$a[4] -and $b[7] -eq '3' -and $b[8] -eq '4') 'registro: righe delle sole routine nuove aggiunte; tre tabelle e quattro routine create'
    $feeds = Get-Scalar 'SELECT COUNT(*) AS ksval FROM export;'
    Check ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM export_opzioni;') -eq $feeds -and (Get-Scalar 'SELECT COUNT(DISTINCT TokenAccesso) AS ksval FROM export_opzioni;') -eq $feeds) ('una riga di opzioni per ognuno dei ' + $feeds + ' feed, con codici tutti distinti')
    $regCount1 = Get-Scalar 'SELECT COUNT(*) AS ksval FROM sysparametristored;'

    # --- idempotenza ---
    $f2 = Invoke-Sql $forward -Write
    Check ($f2 -match 'EXPORT_FEED_DB_FORWARD_OK') 'forward rilanciato da solo: FORWARD_OK'
    Check ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM sysparametristored;') -eq $regCount1 -and (Get-Snapshot) -eq $afterSnap) 'forward rilanciato: nessuna riga doppia nel registro, stato identico'
    Check ((Invoke-Sql $verify) -match 'EXPORT_FEED_DB_VERIFY_OK') 'verify dopo il secondo forward: VERIFY_OK'

    # --- vincoli di export_opzioni (SQL diretto) ---
    $ins = Invoke-Sql "INSERT INTO export (Descrizione, FormatString, NListino, Azienda, Tipo, Abilitato) VALUES ('KSGESTHARNESSX', '#Codice#', 10, 'www.example.test', 'txt', 0); INSERT INTO export_opzioni (ExportId) SELECT ID FROM export WHERE Descrizione = 'KSGESTHARNESSX'; SELECT CHAR_LENGTH(TokenAccesso) AS ksval FROM export_opzioni o JOIN export e ON e.ID = o.ExportId WHERE e.Descrizione = 'KSGESTHARNESSX';" -Write
    Check ($ins -match '(?m)^48$') 'una riga inserita dopo la migrazione riceve un codice da 48 caratteri'
    $bad = Invoke-Sql "UPDATE export_opzioni o JOIN export e ON e.ID = o.ExportId SET o.TokenAccesso = 'ABC' WHERE e.Descrizione = 'KSGESTHARNESSX';" -Write
    Check ($bad -match 'ERROR 3819') 'un codice di formato errato e rifiutato (ERROR 3819)'
    $dup = Invoke-Sql "UPDATE export_opzioni o JOIN export e ON e.ID = o.ExportId SET o.TokenAccesso = (SELECT t FROM (SELECT TokenAccesso AS t FROM export_opzioni WHERE ExportId <> (SELECT ID FROM export WHERE Descrizione = 'KSGESTHARNESSX') LIMIT 1) z) WHERE e.Descrizione = 'KSGESTHARNESSX';" -Write
    Check ($dup -match 'ERROR 1062') 'un codice duplicato e rifiutato (ERROR 1062)'
    $second = Invoke-Sql "INSERT INTO export_opzioni (ExportId) SELECT ID FROM export WHERE Descrizione = 'KSGESTHARNESSX';" -Write
    Check ($second -match 'ERROR 1062') 'una seconda riga di opzioni per lo stesso feed e rifiutata'
    $reg = Invoke-Sql "UPDATE export_opzioni SET TokenAccesso = DEFAULT WHERE ExportId = (SELECT ID FROM export WHERE Descrizione = 'KSGESTHARNESSX');" -Write
    Check (-not (Failed $reg)) 'SET TokenAccesso = DEFAULT rinnova il codice'
    $null = Invoke-Sql "DELETE FROM export WHERE Descrizione = 'KSGESTHARNESSX';" -Write
    Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM export_opzioni WHERE ExportId NOT IN (SELECT ID FROM export);") -eq '0') 'cancellare il feed cancella la riga delle opzioni'

    # --- il programma che simula il gestionale ---
    if (-not $SkipHarness) {
        $h = Run-Harness
        $hFails = @($h.Out -split "`r?`n" | Where-Object { $_ -cmatch '^(FAIL |HARNESS_ERROR|COMPILE_ERROR)' })
        $hOk = @($h.Out -split "`r?`n" | Where-Object { $_ -match '^ok ' }).Count
        Check ($h.Code -eq 0 -and $hFails.Count -eq 0 -and $hOk -ge 30) ('gestionale simulato (connettore .NET, registro reale): ' + $hOk + ' casi ok' + $(if ($hFails.Count -gt 0) { '; ' + ($hFails -join ' | ') } else { '' }))
        Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM export WHERE Descrizione LIKE 'KSGESTHARNESS%';") -eq '0') 'il programma di prova non lascia righe'
    }

    # --- rollback senza conferma: rifiutato ---
    $before = Get-Snapshot
    $rbNo = Invoke-Sql $rollback -Write
    Check ($rbNo -match 'ERROR 1109' -and (Get-Snapshot) -eq $before) 'rollback senza conferma: si ferma e non cambia nulla'

    # --- verify che si ferma se i dati o il registro sono corrotti ---
    $null = Invoke-Sql "ALTER TABLE export_opzioni ALTER CHECK ck_export_opzioni_token NOT ENFORCED; UPDATE export_opzioni SET TokenAccesso = 'ABC' WHERE Id = (SELECT m FROM (SELECT MIN(Id) AS m FROM export_opzioni) z);" -Write
    $vBad = Invoke-Sql $verify
    Check ($vBad -match "codici_validi_e_distinti`tKO" -and $vBad -match "controllo_formato_codice_attivo`tKO" -and $vBad -notmatch 'EXPORT_FEED_DB_VERIFY_OK') 'verify si ferma con un codice corrotto e il controllo di formato spento'
    $null = Invoke-Sql "UPDATE export_opzioni SET TokenAccesso = DEFAULT WHERE TokenAccesso = 'ABC'; ALTER TABLE export_opzioni ALTER CHECK ck_export_opzioni_token ENFORCED;" -Write
    $null = Invoke-Sql "DELETE FROM sysparametristored WHERE NomeStore = 'Dupexport' AND NomeParametro = 'parRetVal';" -Write
    $vReg = Invoke-Sql $verify
    Check ($vReg -match "registro_uguale_ai_parametri_nello_stesso_ordine`tKO" -and $vReg -notmatch 'EXPORT_FEED_DB_VERIFY_OK') 'verify si ferma se manca una riga del registro'
    $null = Invoke-Sql $forward -Write
    Check ((Invoke-Sql $verify) -match 'EXPORT_FEED_DB_VERIFY_OK') 'il forward ripristina il registro'
    $null = Invoke-Sql "UPDATE sysparametristored SET id = id + 100000 WHERE NomeStore = 'Newexport_opzioni' AND NomeParametro IN ('parExportId', 'parTokenAccesso') ORDER BY id DESC;" -Write
    $vOrd = Invoke-Sql $verify
    Check ($vOrd -match "registro_uguale_ai_parametri_nello_stesso_ordine`tKO" -and $vOrd -notmatch 'EXPORT_FEED_DB_VERIFY_OK') 'verify si ferma se il registro e in un altro ordine'
    $null = Invoke-Sql $forward -Write

    # --- rollback con conferma e binlog STATEMENT ---
    $rbBase = Invoke-Sql ($confirm + $rollback) -Write
    Check ($rbBase -match 'EXPORT_FEED_DB_ROLLBACK_OK' -and (Get-Snapshot) -eq $initial) 'rollback con conferma: stato iniziale identico (tabelle, routine, registro, exportcampi)'
    $sub = "@@global.log_bin = 1 AND (@@global.binlog_format = 'STATEMENT' OR @@session.binlog_format = 'STATEMENT')"
    foreach ($kind in @('preflight', 'forward')) {
        $text = Read-Mig $kind
        Check ($text.Contains($sub)) ('il testo ' + $kind + ' contiene la condizione sul binlog')
        $simulated = $text.Replace($sub, '1 = 1')
        $r = if ($kind -eq 'forward') { Invoke-Sql $simulated -Write } else { Invoke-Sql $simulated }
        Check ($r -match 'ERROR 1109' -and ((Get-Snapshot) -eq $initial)) ('binlog STATEMENT simulato: ' + $kind + ' si ferma e non crea nulla')
    }

    # --- ripresa: interruzione dopo ogni passo, poi forward completo, verify, rollback ---
    for ($n = 0; $n -le $nSteps; $n++) {
        $part = Get-ForwardUpTo $forward $n
        $r = Invoke-Sql $part -Write
        if (Failed $r) { Check $false ('forward interrotto prima del passo ' + ($n + 1) + ' eseguito senza errori') }
        $r2 = Invoke-Sql $forward -Write
        $okv = (Invoke-Sql $verify) -match 'EXPORT_FEED_DB_VERIFY_OK'
        Check ($r2 -match 'EXPORT_FEED_DB_FORWARD_OK' -and $okv) ('ripresa dopo l''interruzione prima del passo ' + ($n + 1) + ': forward e verify OK')
        $null = Run-Rollback $rollback
        Check ((Get-Snapshot) -eq $initial) ('rollback dopo la ripresa ' + ($n + 1) + ': stato iniziale')
    }
    foreach ($n in 2, 4, 6, 7) {
        $null = Invoke-Sql (Get-ForwardUpTo $forward $n) -Write
        $null = Run-Rollback $rollback
        Check ((Get-Snapshot) -eq $initial) ('rollback direttamente dopo un forward interrotto al passo ' + $n + ': stato iniziale')
    }

    # --- mutazioni degli script ---
    if (-not $SkipMutants) {
        $nl = "`n"
        $mutants = @(
            @('registro-non-ripulito', 'DELETE FROM sysparametristored WHERE NomeStore IN', 'DELETE FROM sysparametristored WHERE 1 = 0 AND NomeStore IN'),
            @('registro-ordine-inverso', 'ORDER BY SPECIFIC_NAME, ORDINAL_POSITION', 'ORDER BY SPECIFIC_NAME, ORDINAL_POSITION DESC'),
            @('cascata-tolta-opzioni', ('FOREIGN KEY (ExportId) REFERENCES `export` (ID) ON DELETE CASCADE,' + $nl + '  CONSTRAINT ck_export_opzioni_token'), ('FOREIGN KEY (ExportId) REFERENCES `export` (ID),' + $nl + '  CONSTRAINT ck_export_opzioni_token')),
            @('codice-senza-predefinito-database', 'DEFAULT (HEX(RANDOM_BYTES(24)))', 'DEFAULT ''AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'''),
            @('riempimento-tolto', 'WHERE NOT EXISTS (SELECT 1 FROM export_opzioni o WHERE o.ExportId = e.ID) ORDER BY e.ID', 'WHERE 1 = 0 ORDER BY e.ID'),
            @('salvataggio-riscrive-il-codice', 'ON DUPLICATE KEY UPDATE Separatore = nuovo.Separatore', 'ON DUPLICATE KEY UPDATE TokenAccesso = DEFAULT, Separatore = nuovo.Separatore'),
            @('parametri-scambiati', 'IFNULL(parSeparatore, DEFAULT(Separatore)), IFNULL(parDelimitatoreTesto, DEFAULT(DelimitatoreTesto))', 'IFNULL(parDelimitatoreTesto, DEFAULT(DelimitatoreTesto)), IFNULL(parSeparatore, DEFAULT(Separatore))'),
            @('duplicato-abilitato', ('NoVettoreSuGratis, 0' + $nl + '  FROM `export` WHERE ID = parId;'), ('NoVettoreSuGratis, Abilitato' + $nl + '  FROM `export` WHERE ID = parId;')),
            @('duplicato-senza-filtri', ('SottogruppiId, ArticoliId)' + $nl + '    SELECT vNuovo'), ('SottogruppiId, ArticoliId)' + $nl + '    SELECT 0')),
            @('colonne-id-sbagliato', 'SET parRetVal = LAST_INSERT_ID();', 'SET parRetVal = parExportId;'),
            @('nuovo-codice-non-cambia', 'UPDATE export_opzioni SET TokenAccesso = DEFAULT WHERE ExportId = parId;', 'UPDATE export_opzioni SET Separatore = Separatore WHERE ExportId = parId;'),
            @('posizione-non-unica', 'UNIQUE KEY uk_export_colonne_posizione (ExportId, Posizione),', ''),
            @('opzioni-id-uguale-exportid', 'SELECT Id INTO parRetVal FROM export_opzioni WHERE ExportId = parExportId;', 'SET parRetVal = parExportId;'),
            @('voce-categoriapercorso-tolta', 'SELECT ''''CategoriaPercorso'''' FROM DUAL', 'SELECT ''''CategoriaPercorsoX'''' FROM DUAL')
        )
        $killed = 0; $total = 0
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu[0] -notlike ('*' + $MutantFilter + '*')) { continue }
            $total++
            if (-not $forward.Contains($mu[1])) { Write-Host ('  FAIL mutante ' + $mu[0] + ': testo da mutare non trovato'); $e2e.Add('mutante ' + $mu[0] + ' non applicabile'); continue }
            $mutated = $forward.Replace($mu[1], $mu[2])
            $null = Run-Rollback $rollback
            $fails = @(Exercise $mutated 2)
            if ($fails.Count -gt 0) { $killed++; Write-Host ('  ok   mutante ' + $mu[0] + ' ucciso (' + $fails[0] + ')') }
            else { Write-Host ('  FAIL mutante ' + $mu[0] + ' sopravvissuto'); $e2e.Add('mutante ' + $mu[0] + ' sopravvissuto') }
            $null = Run-Rollback $rollback
            Remove-TestRows
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
    }

    # --- stato finale ---
    $null = Run-Rollback $rollback
    Check ((Get-Snapshot) -eq $initial) 'stato finale del LAB identico a quello iniziale'
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    try { Remove-TestRows } catch { }
    try {
        if ((Get-Scalar "SELECT COUNT(*) AS ksval FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_opzioni', 'export_stato', 'export_colonne');") -ne '0') {
            $null = Run-Rollback (Read-Mig 'rollback')
            Write-Host '  nota: migrazione rimasta sul LAB, annullata dal rollback finale'
        }
    } catch { Write-Host ('  ATTENZIONE: pulizia finale non riuscita: ' + $_.Exception.Message); $exit = 1 }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'EXPORT_FEED_DB PASS' } else { Write-Host 'EXPORT_FEED_DB FAIL' }
exit $exit
