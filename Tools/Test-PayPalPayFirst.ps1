[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [switch]$SkipMutations,
    [string[]]$OnlyMutants = @(),
    [string]$MysqlRoot = 'C:\Temp\KeepStoreRegOrderLab-20261025\mysql',
    [string]$Schema = 'keepstore_regorder_lab_20261025',
    [int]$Port = 13317
)

# PAYPAL-PAY-FIRST-PAGES-1A (P3a1 del pay-first): prova politica, contesto di sessione, avvio e ritorno del pagamento PayPal PRIMA dell'ordine.
# Compila TUTTA App_Code con Tools\PayPalPayFirstHarness.vb (PayPal FINTO con stato, nessuna rete) e lo esegue contro il database LAB locale con il connettore
# reale e lo schema reale (tabella paypal_checkout_tentativi gia presente: la crea il test di P2). Poi i controlli sul sorgente delle pagine e i mutanti:
# ogni mutante dichiara ExpectedKill (prefissi del PRIMO controllo che deve cadere); un mutante ucciso da un altro controllo non conta.
# Il LAB e solo locale (127.0.0.1): se manca credenziale o server il test dichiara SKIP (mai PASS). Credenziale solo dal deposito DPAPI, nell'ambiente del
# processo figlio, mai in argv, file o output. Esce con 1 se qualunque controllo cade. Solo ASCII (Windows PowerShell 5.1).
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
$ca = Join-Path $MysqlRoot 'data\ca.pem'
$labTool = Join-Path $PSScriptRoot 'Invoke-KeepStoreLabSql.ps1'
$vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
if (-not (Test-Path -LiteralPath $vbc)) { $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\vbc.exe' }

foreach ($needed in @($credFile, $ca, $labTool, $vbc)) {
    if (-not (Test-Path -LiteralPath $needed)) { Write-Output ('SKIP: LAB non disponibile, manca un prerequisito locale (' + (Split-Path -Leaf $needed) + ')'); exit 0 }
}
$reachable = $false
try {
    $tcp = New-Object Net.Sockets.TcpClient
    $async = $tcp.BeginConnect('127.0.0.1', $Port, $null, $null)
    $reachable = $async.AsyncWaitHandle.WaitOne(1500) -and $tcp.Connected
    $tcp.Close()
} catch { $reachable = $false }
if (-not $reachable) { Write-Output 'SKIP: LAB non raggiungibile su 127.0.0.1 (avviarlo con la procedura standard)'; exit 0 }

function Invoke-Lab([string]$Sql) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('ks-paypal-payfirst-' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($tmp, $Sql, (New-Object Text.UTF8Encoding($false)))
    try { return ((& powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labTool -SqlFile $tmp 2>&1) -join "`n") } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

$identity = Invoke-Lab "SELECT @@server_uuid AS u, DATABASE() AS d, (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi') AS tent;"
$row = @(($identity -split "`r?`n") | Where-Object { $_ -match '^[0-9a-f]{8}-[0-9a-f]{4}-' } | Select-Object -First 1)
if ($row.Count -eq 0) { Write-Output 'LAB_PREFLIGHT_UNREADABLE: nessuna scrittura eseguita'; exit 1 }
$cells = $row[0].Split("`t")
if ($cells.Count -lt 3 -or $cells[0] -ne '1167ebae-d0c0-11f1-b348-9c7bef540c10' -or $cells[1] -ne $Schema) { Write-Output 'LAB_IDENTITY_MISMATCH: nessuna scrittura eseguita'; exit 1 }
if ($cells[2] -ne '1') { Write-Output 'SKIP: manca la tabella paypal_checkout_tentativi sul LAB (la crea Test-PayPalAttemptRepositoryRealSchema.ps1)'; exit 0 }

# --- controlli sul sorgente (glue delle pagine e inerzia) ---
$overall = 0
function Test-Source([string]$Name, [bool]$Ok) { if ($Ok) { Write-Output ('PASS ' + $Name) } else { Write-Output ('FAIL ' + $Name); $script:overall = 1 } }
$pf = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code\PayPalPayFirst.vb'))
$ret = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'paypalreturn.aspx.vb'))
$pay = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'paypalpay.aspx.vb'))
$ord = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'ordine.aspx.vb'))
Test-Source 'G01 paypalreturn: il ramo bozza precede il percorso del documento e usa RunReturn' (($ret.IndexOf('PayPalPayFirstGlue.RunReturn', [StringComparison]::Ordinal) -gt 0) -and ($ret.IndexOf('PayPalPayFirstGlue.RunReturn', [StringComparison]::Ordinal) -lt $ret.IndexOf('QueryInt("id")', [StringComparison]::Ordinal)))
Test-Source 'G02 paypalreturn: il ramo bozza si attiva solo con il parametro k' ($ret -match 'Request\.QueryString\("k"\)')
Test-Source 'G03 paypalpay: nessuna regola nella pagina, solo RunStart' (($pay -match 'PayPalPayFirstGlue\.RunStart') -and ($pay -notmatch 'CreateAuthorizeOrder|AuthorizeOrder|VoidAuthorization|CaptureAuthorization'))
Test-Source 'G04 P3a1 e inerte: ordine.aspx non emette il contesto e non lo legge' (($ord -notmatch 'PayPalPayFirst'))
Test-Source 'G05 nessun incasso in P3a1: il servizio non chiama CaptureAuthorization' (($pf -notmatch 'CaptureAuthorization') -and ($pf -notmatch 'CaptureOrder'))
Test-Source 'G06 l''annullo del servizio passa solo da RecordVoidingUnbound e da nessun RecordVoiding generico' (($pf -match 'RecordVoidingUnbound') -and ($pf -notmatch 'RecordVoiding\('))
Test-Source 'G07 il contesto non legge mai la querystring e il servizio non usa pp=1' (($pf -notmatch 'Request\.QueryString') -and ($pf -notmatch '"pp"'))

# --- compilazione ---
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-paypal-payfirst-' + [Guid]::NewGuid().ToString('N'))
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
    $harness = Join-Path $RepositoryRoot 'Tools\PayPalPayFirstHarness.vb'
    $log = & $vbc /nologo /target:exe /out:$exe /imports:System.Collections.Generic,System.Configuration /r:System.dll /r:System.Data.dll /r:System.Configuration.dll /r:System.Web.dll /r:System.Web.Extensions.dll /r:System.Drawing.dll /r:System.Xml.dll /r:System.Xml.Linq.dll /r:System.Core.dll /r:System.Runtime.Serialization.dll /r:System.Security.dll /r:System.Net.Http.dll /r:System.ComponentModel.DataAnnotations.dll @($compileRefs.ToArray()) $harness @files 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) {
        $first = @($log | Where-Object { $_.ToString() -match 'error' } | Select-Object -First 4 | ForEach-Object { $_.ToString().Substring(0, [Math]::Min(240, $_.ToString().Length)) })
        return @{ ok = $false; exe = $null; log = ($first -join ' | ') }
    }
    [IO.File]::WriteAllText(($exe + '.config'), $configXml, [Text.Encoding]::UTF8)
    return @{ ok = $true; exe = $exe; log = '' }
}

function Invoke-Run([string]$Exe, [switch]$FailFast) {
    $mutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLocalLabSql')
    $held = $false
    try {
        try { $held = $mutex.WaitOne(900000) } catch [System.Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { return @{ exit = 4; failed = @(); result = ''; notReady = @('LAB_BUSY_TIMEOUT'); lines = @() } }
        $argv = @()
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
    $r = Invoke-Run $real.exe
    if ($r.notReady.Count -gt 0 -or $r.result -eq '') { Write-Output ('NOT_RUN: ' + ($r.notReady -join ' ; ') + ' ' + (($r.lines | Select-Object -Last 3) -join ' | ')); $overall = 1 }
    else {
        Write-Output $r.result
        foreach ($name in $r.failed) { Write-Output ('  FAIL ' + $name); $overall = 1 }
        if ($r.exit -ne 0 -and $r.failed.Count -eq 0) { Write-Output ('  HARNESS_EXIT_' + $r.exit + '_WITHOUT_A_FAILED_CHECK'); $overall = 1 }
        foreach ($l in @($r.lines | Where-Object { $_ -like 'EXC *' -or $_ -like 'DETAIL *' })) { Write-Output ('  ' + $l) }
    }

    if (-not $SkipMutations -and $overall -eq 0) {
        $mutantsFile = Join-Path $PSScriptRoot 'PayPalPayFirstMutants.psd1'
        if (-not (Test-Path -LiteralPath $mutantsFile)) { Write-Output 'MUTANTS_FILE_MISSING'; $overall = 1 }
        else {
            $mutants = @((Import-PowerShellDataFile -LiteralPath $mutantsFile).Mutants)
            $OnlyMutants = @($OnlyMutants | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
            if ($OnlyMutants.Count -gt 0) { $mutants = @($mutants | Where-Object { $OnlyMutants -contains $_.Name }) }
            if ($OnlyMutants.Count -eq 0 -and $mutants.Count -lt 30) { Write-Output ('TOO_FEW_MUTANTS: ' + $mutants.Count); $overall = 1 }
            $survivors = 0
            foreach ($m in $mutants) {
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
                $r = Invoke-Run $b.exe -FailFast
                if ($r.notReady.Count -gt 0 -or $r.result -eq '') { Write-Output ('  MUTANT ' + $m.Name + ': ESECUZIONE NON VALIDA (LAB non pronto o harness interrotto)'); $survivors++; continue }
                if ($r.failed.Count -gt 0) {
                    $first = $r.failed[0]
                    $matched = $false
                    foreach ($prefix in @($m.ExpectedKill)) { if ($first.StartsWith($prefix, [StringComparison]::Ordinal)) { $matched = $true } }
                    if ($matched) { Write-Output ('  KILLED ' + $m.Name + ' by ' + $first.Substring(0, [Math]::Min(60, $first.Length))) }
                    else { Write-Output ('  KILLED_BY_UNEXPECTED_CHECK ' + $m.Name + ': ' + $first.Substring(0, [Math]::Min(80, $first.Length)) + ' (atteso ' + (@($m.ExpectedKill) -join '|') + ')'); $survivors++ }
                } else { Write-Output ('  SURVIVED ' + $m.Name); $survivors++ }
                Remove-Item -LiteralPath $copy -Recurse -Force -ErrorAction SilentlyContinue
            }
            if ($survivors -gt 0) { $overall = 1 }
            Write-Output ('Mutanti: ' + $mutants.Count + ', sopravvissuti/non validi: ' + $survivors)
        }
    }

    # Nessun residuo sul LAB a fine corsa (sola lettura).
    $res = Invoke-Lab "SELECT (SELECT COUNT(*) FROM paypal_checkout_tentativi WHERE DatabaseScopeKey='KS_TEST_PF_SCOPE' OR AziendeId IN (9301,9302))+(SELECT COUNT(*) FROM pagamentitipo WHERE id IN (9301,9302))+(SELECT COUNT(*) FROM paypal_checkout_azienda WHERE AziendeId IN (9301,9302))+(SELECT COUNT(*) FROM paypal_checkout_account WHERE CredentialKey='KS_TEST_PF_A') AS residue;"
    if ($res -notmatch "residue\s+0\s*$" -and $res -notmatch "residue\r?\n0") { Write-Output ('LAB_RESIDUE_FOUND: ' + $res); $overall = 1 }
} finally {
    foreach ($n in @('KS_LAB_USER', 'KS_LAB_PWD', 'KS_LAB_SCHEMA', 'KS_LAB_PORT')) { [Environment]::SetEnvironmentVariable($n, $null, 'Process') }
    $plain = $null
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
if ($overall -eq 0) { Write-Output 'PAYPAL_PAY_FIRST: PASS' } else { Write-Output 'PAYPAL_PAY_FIRST: FAIL' }
exit $overall
