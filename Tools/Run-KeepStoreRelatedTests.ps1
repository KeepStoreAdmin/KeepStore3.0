[CmdletBinding()]
param(
    [string]$BaseRef = 'origin/frontend-rebuild',
    [int]$Parallel = 4,
    [int]$TimeoutSec = 480,
    [string[]]$Tests,
    [switch]$ListOnly,
    [switch]$Wide
)

# Esegue SOLO i test pertinenti ai file cambiati, in parallelo, e separa i fallimenti noti della stable da quelli nuovi.
# Mappa: file cambiato (rispetto a $BaseRef, piu i nuovi file in Tools) -> i Tools\Test-*.ps1 che ne citano il nome; un test cambiato gira da se. I file citati da molti test (Page.master, articoli.aspx...)
# sono 'hub': per quelli conta solo cio che il diff ha TOLTO (le righe che un test puo fissare: buster, regole, markup). -Wide usa invece il solo nome del file (piu test, piu lento).
# Fallimenti noti: Tools\known-baseline-failures.txt (una riga per test: Nome # motivo, verificati sulla stable). Un test noto che fallisce e BASELINE; uno che passa e segnalato.
# Esce con 1 solo se un test NON noto fallisce. Node (per i test .cjs) e risolto dal pacchetto OpenAI.Codex. Un solo browser per test: il parallelismo e sicuro.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.
# Uso:  powershell -NoProfile -File Tools\Run-KeepStoreRelatedTests.ps1 [-BaseRef origin/frontend-rebuild] [-Parallel 4]   (in background)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$toolsDir = Join-Path $repo 'Tools'

$known = @{}
$knownFile = Join-Path $toolsDir 'known-baseline-failures.txt'
if (Test-Path -LiteralPath $knownFile) {
    foreach ($l in (Get-Content -LiteralPath $knownFile)) {
        if ($l -match '^\s*(Test-[A-Za-z0-9]+)\b') { $known[$Matches[1]] = $l.Trim() }
    }
}

if (-not $Tests -or $Tests.Count -eq 0) {
    $changed = @(& git diff --name-only $BaseRef 2>$null) + @(& git ls-files --others --exclude-standard -- Tools 2>$null)
    # le 4 cancellazioni tracked volute della copia canonica non sono modifiche del task
    $intentional = @('App_Data/Logs/analytics-get-20260120.log', 'App_Data/Logs/cambiapassword.log', 'Database Taikun/KeepStore.sql', 'Public/assets/keepstore/README.md')
    $changed = @($changed | Where-Object { $_ -and ($intentional -notcontains $_) } | Sort-Object -Unique)
    $allTests = @(Get-ChildItem -LiteralPath $toolsDir -Filter 'Test-*.ps1' | ForEach-Object { $_.Name })
    $texts = @{}
    foreach ($t in $allTests) { $texts[$t] = [IO.File]::ReadAllText((Join-Path $toolsDir $t)) }
    $sel = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($c in $changed) {
        $leaf = Split-Path -Leaf $c
        if ($leaf -like 'Test-*.ps1') { [void]$sel.Add($leaf); continue }
        if ($c -like 'docs/*' -or $leaf -like '*.md') { continue }
        $citing = @($allTests | Where-Object { $texts[$_].IndexOf($leaf, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
        if ($Wide -or $citing.Count -le 12) { $citing | ForEach-Object { [void]$sel.Add($_) }; continue }
        # file hub: i test che contengono una riga TOLTA dal diff (almeno 14 caratteri, le 80 piu lunghe)
        $removed = @(& git diff -U0 $BaseRef -- $c 2>$null | Where-Object { $_ -match '^-(?!--)' } | ForEach-Object { $_.Substring(1).Trim() } | Where-Object { $_.Length -ge 14 } | Sort-Object Length -Descending | Select-Object -First 80)
        foreach ($t in $citing) { foreach ($line in $removed) { if ($texts[$t].Contains($line)) { [void]$sel.Add($t); break } } }
    }
    $Tests = @($sel | Sort-Object)
} else {
    $Tests = @($Tests | ForEach-Object { $_ -split ',' } | Where-Object { $_ } | ForEach-Object { $_.Trim() } | ForEach-Object { if ($_ -like '*.ps1') { $_ } else { $_ + '.ps1' } })
}
Write-Output ('RELATED_TESTS=' + $Tests.Count)
if ($ListOnly -or $Tests.Count -eq 0) { $Tests | ForEach-Object { Write-Output ('  ' + $_) }; exit 0 }

$nodeDir = $null
$pkg = @(Get-AppxPackage -Name 'OpenAI.Codex')
if ($pkg.Count -gt 0) { $cand = Join-Path $pkg[0].InstallLocation 'app\resources\cua_node\bin'; if (Test-Path -LiteralPath $cand) { $nodeDir = $cand } }
if ($nodeDir) { $env:PATH = $nodeDir + ';' + $env:PATH }

$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-related-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$queue = New-Object 'System.Collections.Generic.Queue[string]'
foreach ($t in $Tests) { $queue.Enqueue($t) }
$running = @()
$results = @()
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
    while ($queue.Count -gt 0 -and $running.Count -lt $Parallel) {
        $t = $queue.Dequeue()
        $name = [IO.Path]::GetFileNameWithoutExtension($t)
        $log = Join-Path $work ($name + '.log')
        $evArg = ''
        if ([IO.File]::ReadAllText((Join-Path $toolsDir $t)) -match '(?s)Mandatory\s*=\s*\$true\)\]\s*\[string\]\$EvidenceDirectory') { $evArg = ' -EvidenceDirectory "' + (Join-Path $work ('ev-' + $name)) + '"' }
        $argLine = '-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -Command "& ''' + (Join-Path $toolsDir $t) + '''' + $evArg + '"'
        $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError ($log + '.err')
        $null = $p.Handle   # tiene vivo l'handle: senza, ExitCode torna nullo con l'output rediretto
        $running += [pscustomobject]@{ Name = $name; Proc = $p; Log = $log; Start = [Diagnostics.Stopwatch]::StartNew() }
    }
    Start-Sleep -Milliseconds 500
    $still = @()
    foreach ($r in $running) {
        if ($r.Proc.HasExited) {
            $results += [pscustomobject]@{ Name = $r.Name; Exit = $r.Proc.ExitCode; Sec = [int]$r.Start.Elapsed.TotalSeconds; Log = $r.Log }
        } elseif ($r.Start.Elapsed.TotalSeconds -gt $TimeoutSec) {
            try { $r.Proc.Kill() } catch { }
            $results += [pscustomobject]@{ Name = $r.Name; Exit = 124; Sec = [int]$r.Start.Elapsed.TotalSeconds; Log = $r.Log }
        } else { $still += $r }
    }
    $running = $still
}

$newFail = 0
foreach ($r in ($results | Sort-Object Name)) {
    $status = 'PASS'
    if ($r.Exit -ne 0) { if ($known.ContainsKey($r.Name)) { $status = 'BASELINE' } else { $status = 'FAIL'; $newFail++ } }
    elseif ($known.ContainsKey($r.Name)) { $status = 'PASS (era noto come fallito: aggiornare known-baseline-failures.txt)' }
    Write-Output ('{0,-9} {1,-46} exit={2} {3}s' -f $status, $r.Name, $r.Exit, $r.Sec)
    if ($status -eq 'FAIL') {
        $first = @(Get-Content -LiteralPath $r.Log | Where-Object { $_ -and $_ -notmatch '^PASS ' } | Select-Object -First 2)
        $first | ForEach-Object { Write-Output ('          ' + $_.Substring(0, [Math]::Min(150, $_.Length))) }
        Write-Output ('          log: ' + $r.Log)
    }
}
Write-Output ('RELATED_TESTS_DONE total=' + $results.Count + ' new_failures=' + $newFail + ' seconds=' + [int]$sw.Elapsed.TotalSeconds)
if ($newFail -gt 0) { exit 1 }
exit 0
