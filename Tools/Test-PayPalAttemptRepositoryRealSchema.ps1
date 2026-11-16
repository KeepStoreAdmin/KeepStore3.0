[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [switch]$SkipMutations,
    [string]$MysqlRoot = 'C:\Temp\KeepStoreRegOrderLab-20261025\mysql',
    [string]$Schema = 'keepstore_regorder_lab_20261025',
    [int]$Port = 13317
)

# PAYPAL-ATTEMPTS-TABLE-1A (fase P2 del pay-first): prova la tabella dei tentativi di pagamento PayPal, la macchina a stati e il repository con il CONNETTORE REALE e
# lo SCHEMA REALE sul LAB locale. Lo script SQL (preflight, forward, verify, rollback) e letto da docs\PAYPAL_PAY_FIRST_ATTEMPTS_TABLE.md (fonte unica, nessuna copia).
# Compila TUTTA App_Code con un harness (Tools\PayPalAttemptRepositoryHarness.vb) e lo esegue due volte (TreatTinyAsBoolean true/false). Poi le mutazioni:
# ogni mutante dichiara ExpectedKill (prefissi del PRIMO controllo che deve cadere); un mutante ucciso da un altro controllo non conta. I mutanti DDL mutano una copia
# della pagina docs: tabella vuota -> rollback -> forward mutato -> prova -> rollback -> forward vero.
# Il LAB e solo locale (127.0.0.1): se manca credenziale o server il test dichiara SKIP (mai PASS). Credenziale solo dal deposito DPAPI, nell'ambiente del processo figlio,
# mai in argv, file o output. Esce con 1 se qualunque controllo cade o se l'harness esce con codice diverso da zero. Solo ASCII (Windows PowerShell 5.1).
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
$ca = Join-Path $MysqlRoot 'data\ca.pem'
$labTool = Join-Path $PSScriptRoot 'Invoke-KeepStoreLabSql.ps1'
$docsPage = Join-Path $RepositoryRoot 'docs\PAYPAL_PAY_FIRST_ATTEMPTS_TABLE.md'
$vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
if (-not (Test-Path -LiteralPath $vbc)) { $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\vbc.exe' }

foreach ($needed in @($credFile, $ca, $labTool, $vbc)) {
    if (-not (Test-Path -LiteralPath $needed)) { Write-Output ('SKIP: LAB non disponibile, manca un prerequisito locale (' + (Split-Path -Leaf $needed) + ')'); exit 0 }
}
if (-not (Test-Path -LiteralPath $docsPage)) { Write-Output 'DOCS_PAGE_MISSING'; exit 1 }
$reachable = $false
try {
    $tcp = New-Object Net.Sockets.TcpClient
    $async = $tcp.BeginConnect('127.0.0.1', $Port, $null, $null)
    $reachable = $async.AsyncWaitHandle.WaitOne(1500) -and $tcp.Connected
    $tcp.Close()
} catch { $reachable = $false }
if (-not $reachable) { Write-Output 'SKIP: LAB non raggiungibile su 127.0.0.1 (avviarlo con la procedura standard)'; exit 0 }

function Invoke-Lab([string]$Sql, [switch]$Write) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('ks-paypal-attempt-' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($tmp, $Sql, (New-Object Text.UTF8Encoding($false)))
    try {
        $args1 = @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', $labTool, '-SqlFile', $tmp)
        if ($Write) { $args1 += '-Write' }
        return ((& powershell.exe @args1 2>&1) -join "`n")
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Get-SqlBlock([string]$PageText, [string]$Name) {
    $m = [regex]::Match($PageText, '(?s)```sql ' + $Name + '\r?\n(.*?)```')
    if (-not $m.Success) { throw ('SQL_BLOCK_NOT_FOUND_' + $Name) }
    return $m.Groups[1].Value
}

# --- preflight sul LAB (sola lettura): identita e schema ---
$identity = Invoke-Lab "SELECT @@server_uuid AS u, DATABASE() AS d, @@port AS p, (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_account' AND COLUMN_NAME IN ('ClientId','ClientSecret','WebhookId')) AS c3, (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('paypal_checkout_account','paypal_checkout_azienda','paypal_checkout_transazioni','paypal_checkout_eventi')) AS t4, (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi') AS tent;"
$row = @(($identity -split "`r?`n") | Where-Object { $_ -match '^[0-9a-f]{8}-[0-9a-f]{4}-' } | Select-Object -First 1)
if ($row.Count -eq 0) { Write-Output 'LAB_PREFLIGHT_UNREADABLE: nessuna scrittura eseguita'; exit 1 }
$cells = $row[0].Split("`t")
if ($cells.Count -lt 6 -or $cells[0] -ne '1167ebae-d0c0-11f1-b348-9c7bef540c10' -or $cells[1] -ne $Schema) { Write-Output 'LAB_IDENTITY_MISMATCH: nessuna scrittura eseguita'; exit 1 }
if ($cells[4] -ne '4') { Write-Output 'LAB_SCHEMA_INCOMPLETE: mancano tabelle paypal_checkout_*'; exit 1 }
if ($cells[3] -ne '3') {
    $forward = Join-Path $RepositoryRoot 'Database Taikun\Migrations\20260923_PAYPAL_DB_DRIVEN_CREDENTIALS_1A_forward.sql'
    if (-not (Test-Path -LiteralPath $forward)) { Write-Output 'MIGRATION_FILE_MISSING'; exit 1 }
    $applied = Invoke-Lab ([IO.File]::ReadAllText($forward)) -Write
    if ($applied -match 'ERROR') { Write-Output ('LAB_MIGRATION_FAILED: ' + ($applied.Substring(0, [Math]::Min(300, $applied.Length)))); exit 1 }
    Write-Output 'LAB: applicata la migrazione 20260923 (ClientId/ClientSecret/WebhookId) allo schema del LAB (schema aggiornato di proposito)'
}

$pageText = [IO.File]::ReadAllText($docsPage)
$ddlForward = Get-SqlBlock $pageText 'forward'
$ddlVerify = Get-SqlBlock $pageText 'verify'
$ddlPreflight = Get-SqlBlock $pageText 'preflight'
$ddlRollback = Get-SqlBlock $pageText 'rollback'

function Test-VerifyOk([string]$Output) { return ($Output -match 'VERIFY\s+OK\s+OK\s+OK\s+OK\s+OK\s+OK') -and ($Output -notmatch 'FAIL_') }

# Tabella nuova: DDL di prova, ammessa solo sul LAB, applicata una volta dallo script della pagina docs (aggiorna di proposito lo schema del LAB).
if ($cells[5] -ne '1') {
    $pf = Invoke-Lab $ddlPreflight
    if ($pf -notmatch 'PREFLIGHT\s+OK\s+OK\s+OK' -or $pf -match 'FAIL_') { Write-Output ('ATTEMPTS_PREFLIGHT_FAILED: ' + ($pf.Substring(0, [Math]::Min(300, $pf.Length)))); exit 1 }
    $applied = Invoke-Lab $ddlForward -Write
    if ($applied -match 'ERROR') { Write-Output ('ATTEMPTS_FORWARD_FAILED: ' + ($applied.Substring(0, [Math]::Min(300, $applied.Length)))); exit 1 }
    Write-Output 'LAB: creata la tabella paypal_checkout_tentativi dallo script della pagina docs (schema aggiornato di proposito)'
}
$verify = Invoke-Lab $ddlVerify
if (-not (Test-VerifyOk $verify)) { Write-Output ('ATTEMPTS_VERIFY_FAILED: ' + ($verify.Substring(0, [Math]::Min(300, $verify.Length)))); exit 1 }

# --- compilazione ---
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-paypal-attempt-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -ErrorAction Stop | Out-Null
$bin = Join-Path $RepositoryRoot 'Bin'
$runtimeDeps = @('MySql.Data.dll', 'Google.Protobuf.dll', 'BouncyCastle.Cryptography.dll', 'System.Buffers.dll', 'System.Memory.dll',
    'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll', 'System.Numerics.Vectors.dll', 'System.Formats.Asn1.dll')
$compileRefs = New-Object System.Collections.ArrayList
foreach ($d in @(Get-ChildItem -LiteralPath $bin -Filter *.dll -File)) {
    try { [void][Reflection.AssemblyName]::GetAssemblyName($d.FullName); [void]$compileRefs.Add('/r:' + $d.FullName); Copy-Item -LiteralPath $d.FullName -Destination (Join-Path $work $d.Name) -Force } catch { }
}
$redirects = foreach ($dependency in $runtimeDeps) {
    $path = Join-Path $bin $dependency
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination (Join-Path $work $dependency)
        $assembly = [Reflection.AssemblyName]::GetAssemblyName($path)
        $token = [BitConverter]::ToString($assembly.GetPublicKeyToken()).Replace('-', '').ToLowerInvariant()
        if ($token -and $dependency -ne 'MySql.Data.dll') {
            '<dependentAssembly><assemblyIdentity name="' + $assembly.Name + '" publicKeyToken="' + $token + '" /><bindingRedirect oldVersion="0.0.0.0-' + $assembly.Version + '" newVersion="' + $assembly.Version + '" /></dependentAssembly>'
        }
    }
}
$configXml = '<configuration><runtime><assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">' + ($redirects -join '') + '</assemblyBinding></runtime></configuration>'

function Build-Harness([string]$AppCodeDir, [string]$ExeName) {
    $exe = Join-Path $work $ExeName
    $files = @(Get-ChildItem -LiteralPath $AppCodeDir -Filter *.vb -File | ForEach-Object { $_.FullName })
    $harness = Join-Path $RepositoryRoot 'Tools\PayPalAttemptRepositoryHarness.vb'
    $log = & $vbc /nologo /target:exe /out:$exe /imports:System.Collections.Generic,System.Configuration /r:System.dll /r:System.Data.dll /r:System.Configuration.dll /r:System.Web.dll /r:System.Web.Extensions.dll /r:System.Drawing.dll /r:System.Xml.dll /r:System.Xml.Linq.dll /r:System.Core.dll /r:System.Runtime.Serialization.dll /r:System.Security.dll /r:System.Net.Http.dll /r:System.ComponentModel.DataAnnotations.dll @($compileRefs.ToArray()) $harness @files 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) {
        $first = @($log | Where-Object { $_.ToString() -match 'error' } | Select-Object -First 4 | ForEach-Object { $_.ToString().Substring(0, [Math]::Min(240, $_.ToString().Length)) })
        return @{ ok = $false; exe = $null; log = ($first -join ' | ') }
    }
    [IO.File]::WriteAllText(($exe + '.config'), $configXml, [Text.Encoding]::UTF8)
    return @{ ok = $true; exe = $exe; log = '' }
}

function Invoke-Variant([string]$Exe, [string]$Variant, [switch]$FailFast) {
    # Stesso mutex di Invoke-KeepStoreLabSql.ps1: un solo uso del LAB alla volta (altre prove correlate in parallelo usano le stesse tabelle).
    $mutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLocalLabSql')
    $held = $false
    try {
        try { $held = $mutex.WaitOne(900000) } catch [System.Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { return @{ exit = 4; failed = @(); result = ''; notReady = @('LAB_BUSY_TIMEOUT'); lines = @() } }
        $argv = @('tiny=' + $Variant)
        if ($FailFast) { $argv += 'failfast=true' }
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $lines = @(& $Exe @argv 2>&1 | ForEach-Object { $_.ToString() })
        $exit = $LASTEXITCODE
        $ErrorActionPreference = $prev
    } finally {
        if ($held) { try { $mutex.ReleaseMutex() } catch { } }
        $mutex.Dispose()
    }
    $failed = @($lines | Where-Object { $_ -like 'FAIL *' } | ForEach-Object { $_.Substring(5) })
    $result = @($lines | Where-Object { $_ -like 'RESULT *' } | Select-Object -First 1)
    $notReady = @($lines | Where-Object { $_ -match '^(ENV_NOT_READY|LAB_)' })
    return @{ exit = $exit; failed = $failed; result = $(if ($result.Count -gt 0) { $result[0] } else { '' }); notReady = $notReady; lines = $lines }
}

$plain = $null
$overall = 0
try {
    $cred = Import-Clixml -LiteralPath $credFile
    if ($cred -isnot [pscredential]) { Write-Output 'CREDENTIAL_FILE_NOT_PSCREDENTIAL'; exit 1 }
    $plain = $cred.GetNetworkCredential().Password
    [Environment]::SetEnvironmentVariable('KS_LAB_USER', $cred.UserName, 'Process')
    [Environment]::SetEnvironmentVariable('KS_LAB_PWD', $plain, 'Process')
    [Environment]::SetEnvironmentVariable('KS_LAB_SCHEMA', $Schema, 'Process')
    [Environment]::SetEnvironmentVariable('KS_LAB_PORT', [string]$Port, 'Process')
    $real = Build-Harness (Join-Path $RepositoryRoot 'App_Code') 'real.exe'
    if (-not $real.ok) { Write-Output ('COMPILE_FAILED: ' + $real.log); exit 1 }
    $total = 0
    foreach ($variant in @('true', 'false')) {
        $r = Invoke-Variant $real.exe $variant
        if ($r.notReady.Count -gt 0 -or $r.result -eq '') { Write-Output ('NOT_RUN variant=' + $variant + ': ' + ($r.notReady -join ' ; ')); $overall = 1; continue }
        Write-Output ('TreatTinyAsBoolean=' + $variant + ' -> ' + $r.result)
        foreach ($name in $r.failed) { Write-Output ('  FAIL ' + $name); $total++ }
        if ($r.exit -ne 0 -and $r.failed.Count -eq 0) { Write-Output ('  HARNESS_EXIT_' + $r.exit + '_WITHOUT_A_FAILED_CHECK'); $total++ }
    }
    if ($total -gt 0) { $overall = 1 }

    if (-not $SkipMutations -and $overall -eq 0) {
        $mutantsFile = Join-Path $PSScriptRoot 'PayPalAttemptRepositoryMutants.psd1'
        if (-not (Test-Path -LiteralPath $mutantsFile)) { Write-Output 'MUTANTS_FILE_MISSING'; $overall = 1 }
        else {
            $mutants = @((Import-PowerShellDataFile -LiteralPath $mutantsFile).Mutants)
            if ($mutants.Count -lt 30) { Write-Output ('TOO_FEW_MUTANTS: ' + $mutants.Count); $overall = 1 }
            $survivors = 0
            $ddlMutants = @($mutants | Where-Object { $_.File -eq 'DOCS' })
            $appMutants = @($mutants | Where-Object { $_.File -ne 'DOCS' })
            foreach ($m in $appMutants) {
                $copy = Join-Path $work ('app-' + $m.Name)
                New-Item -ItemType Directory -Path $copy | Out-Null
                Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'App_Code') -Filter *.vb -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $copy }
                $target = Join-Path $copy $m.File
                $text = [IO.File]::ReadAllText($target)
                $occurrence = if ($m.ContainsKey('Occurrence')) { [int]$m.Occurrence } else { 1 }
                $index = -1
                $from = 0
                for ($n = 1; $n -le $occurrence; $n++) {
                    $index = $text.IndexOf($m.Find, $from, [StringComparison]::Ordinal)
                    if ($index -lt 0) { break }
                    $from = $index + $m.Find.Length
                }
                if ($index -lt 0) { Write-Output ('  MUTANT ' + $m.Name + ': ANCORA NON TROVATA all''occorrenza ' + $occurrence + ' (test non valido)'); $survivors++; continue }
                $mutated = $text.Substring(0, $index) + $m.Replace + $text.Substring($index + $m.Find.Length)
                [IO.File]::WriteAllText($target, $mutated, (New-Object Text.UTF8Encoding($false)))
                $b = Build-Harness $copy ('m-' + $m.Name + '.exe')
                if (-not $b.ok) { Write-Output ('  MUTANT ' + $m.Name + ': non compila (' + $b.log + ')'); $survivors++; continue }
                $variants = if ($m.ContainsKey('Both') -and $m.Both) { @('true', 'false') } else { @('true') }
                $killedBy = @()
                $unexpected = @()
                $invalidRun = $false
                foreach ($variant in $variants) {
                    $r = Invoke-Variant $b.exe $variant -FailFast
                    if ($r.notReady.Count -gt 0 -or $r.result -eq '') { $invalidRun = $true; continue }
                    if ($r.failed.Count -gt 0) {
                        $first = $r.failed[0]
                        $matched = $false
                        foreach ($prefix in @($m.ExpectedKill)) { if ($first.StartsWith($prefix, [StringComparison]::Ordinal)) { $matched = $true } }
                        if ($matched) { $killedBy += ($variant + ':' + $first.Substring(0, [Math]::Min(60, $first.Length))) } else { $unexpected += ($variant + ':' + $first.Substring(0, [Math]::Min(80, $first.Length))) }
                    }
                }
                if ($invalidRun) { Write-Output ('  MUTANT ' + $m.Name + ': ESECUZIONE NON VALIDA (LAB non pronto o harness interrotto)'); $survivors++; continue }
                if ($killedBy.Count -gt 0) { Write-Output ('  KILLED ' + $m.Name + ' by ' + ($killedBy -join ', ')) }
                elseif ($unexpected.Count -gt 0) { Write-Output ('  KILLED_BY_UNEXPECTED_CHECK ' + $m.Name + ': ' + ($unexpected -join ', ') + ' (atteso ' + (@($m.ExpectedKill) -join '|') + ')'); $survivors++ }
                else { Write-Output ('  SURVIVED ' + $m.Name); $survivors++ }
            }
            # Mutanti DDL: si muta una copia dello script del docs, si ricrea la tabella (vuota) con quello e si riesegue l'harness; poi si ripristina lo script vero.
            foreach ($m in $ddlMutants) {
                $idx = $ddlForward.IndexOf($m.Find, [StringComparison]::Ordinal)
                if ($idx -lt 0) { Write-Output ('  MUTANT ' + $m.Name + ': ANCORA NON TROVATA nello script forward (test non valido)'); $survivors++; continue }
                $mutatedForward = $ddlForward.Substring(0, $idx) + $m.Replace + $ddlForward.Substring($idx + $m.Find.Length)
                $drop = Invoke-Lab $ddlRollback -Write
                if ($drop -match 'ERROR') { Write-Output ('  MUTANT ' + $m.Name + ': rollback non riuscito (' + $drop.Substring(0, [Math]::Min(160, $drop.Length)) + ')'); $survivors++; continue }
                $made = Invoke-Lab $mutatedForward -Write
                if ($made -match 'ERROR') { Write-Output ('  MUTANT ' + $m.Name + ': il forward mutato non si applica (INVALIDO): ' + $made.Substring(0, [Math]::Min(160, $made.Length))); $survivors++; [void](Invoke-Lab $ddlForward -Write); continue }
                $r = Invoke-Variant $real.exe 'true' -FailFast
                [void](Invoke-Lab $ddlRollback -Write)
                $restored = Invoke-Lab $ddlForward -Write
                if ($restored -match 'ERROR') { Write-Output ('  RESTORE_FAILED after ' + $m.Name); $overall = 1 }
                if ($r.notReady.Count -gt 0 -or $r.result -eq '') { Write-Output ('  MUTANT ' + $m.Name + ': ESECUZIONE NON VALIDA'); $survivors++; continue }
                if ($r.failed.Count -gt 0) {
                    $first = $r.failed[0]
                    $matched = $false
                    foreach ($prefix in @($m.ExpectedKill)) { if ($first.StartsWith($prefix, [StringComparison]::Ordinal)) { $matched = $true } }
                    if ($matched) { Write-Output ('  KILLED ' + $m.Name + ' by ' + $first.Substring(0, [Math]::Min(60, $first.Length))) } else { Write-Output ('  KILLED_BY_UNEXPECTED_CHECK ' + $m.Name + ': ' + $first.Substring(0, [Math]::Min(80, $first.Length)) + ' (atteso ' + (@($m.ExpectedKill) -join '|') + ')'); $survivors++ }
                } else { Write-Output ('  SURVIVED ' + $m.Name); $survivors++ }
            }
            if ($survivors -gt 0) { $overall = 1 }
            Write-Output ('Mutanti: ' + $mutants.Count + ' (DDL ' + $ddlMutants.Count + '), sopravvissuti/non validi: ' + $survivors)
            $verify2 = Invoke-Lab $ddlVerify
            if (-not (Test-VerifyOk $verify2)) { Write-Output ('ATTEMPTS_VERIFY_AFTER_MUTANTS_FAILED: ' + ($verify2.Substring(0, [Math]::Min(300, $verify2.Length)))); $overall = 1 }
        }
    }

    # Nessun residuo sul LAB a fine corsa (sola lettura).
    $res = Invoke-Lab "SELECT (SELECT COUNT(*) FROM paypal_checkout_tentativi WHERE DatabaseScopeKey='KS_TEST_ATT_SCOPE' OR AziendeId IN (9201,9202))+(SELECT COUNT(*) FROM documenti WHERE Id BETWEEN 9201 AND 9260)+(SELECT COUNT(*) FROM pagamentitipo WHERE id IN (9201,9202))+(SELECT COUNT(*) FROM paypal_checkout_azienda WHERE AziendeId IN (9201,9202))+(SELECT COUNT(*) FROM paypal_checkout_account WHERE CredentialKey LIKE 'KS\_TEST\_ATT\_%') AS residue;"
    if ($res -notmatch "residue\s+0\s*$" -and $res -notmatch "residue\r?\n0") { Write-Output ('LAB_RESIDUE_FOUND: ' + $res); $overall = 1 }
} finally {
    foreach ($n in @('KS_LAB_USER', 'KS_LAB_PWD', 'KS_LAB_SCHEMA', 'KS_LAB_PORT')) { [Environment]::SetEnvironmentVariable($n, $null, 'Process') }
    $plain = $null
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
if ($overall -eq 0) { Write-Output 'PAYPAL_ATTEMPT_REPOSITORY_REAL_SCHEMA: PASS' } else { Write-Output 'PAYPAL_ATTEMPT_REPOSITORY_REAL_SCHEMA: FAIL' }
exit $overall
