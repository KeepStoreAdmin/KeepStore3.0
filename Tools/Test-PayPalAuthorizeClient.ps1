[CmdletBinding()]
param([string]$RepositoryRoot, [switch]$SkipMutants)

# PAYPAL-AUTHORIZE-CLIENT-1A (fase P1 del progetto pay-first): prove del client PayPal per AUTHORIZE, incasso dell'autorizzazione e annullo.
# (1) comportamento reale: compila il client vero con un harness e un transport finto (nessuna rete, fixture dagli esempi ufficiali PayPal);
# (2) mutazioni: copie del client con UNA sola sostituzione ancorata; ogni mutante deve far cadere almeno un controllo (un mutante che non compila e INVALIDO e fa fallire il test).
# Solo ASCII (Windows PowerShell 5.1).
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
if (-not (Test-Path -LiteralPath $vbc)) { $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\vbc.exe' }
$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok) { if ($ok) { $script:pass++; Write-Output ('PASS ' + $name) } else { $script:fail++; Write-Output ('FAIL ' + $name) } }
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-paypal-authorize-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

function Invoke-Variant([string]$clientSource, [string]$label) {
    $dir = Join-Path $work $label
    New-Item -ItemType Directory -Path $dir | Out-Null
    $clientFile = Join-Path $dir 'PayPalOrdersV2Client.vb'
    [IO.File]::WriteAllText($clientFile, $clientSource, (New-Object Text.UTF8Encoding($false)))
    $exe = Join-Path $dir 'harness.exe'
    $log = & $vbc /nologo /target:exe /out:$exe /r:System.dll /r:System.Configuration.dll /r:System.Web.dll /r:System.Web.Extensions.dll `
        (Join-Path $RepositoryRoot 'Tools\PayPalAuthorizeHarness.vb') `
        (Join-Path $RepositoryRoot 'App_Code\PayPalCheckoutConfig.vb') `
        $clientFile `
        (Join-Path $RepositoryRoot 'App_Code\PayPalCheckoutSafetyPolicy.vb') 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) {
        return [pscustomobject]@{ Compiled = $false; Ok = $false; Passed = 0; Output = @($log | ForEach-Object { $_.ToString() }) }
    }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $out = @(& $exe 2>&1 | ForEach-Object { $_.ToString() }); $code = $LASTEXITCODE; $ErrorActionPreference = $prev
    $totalLine = $out | Where-Object { $_ -match '^PAYPAL_AUTHORIZE_TOTAL=(\d+)$' } | Select-Object -Last 1
    $total = 0
    if ($totalLine) { $total = [int]($totalLine -replace '^PAYPAL_AUTHORIZE_TOTAL=', '') }
    return [pscustomobject]@{ Compiled = $true; Ok = ($code -eq 0 -and $total -gt 0); Passed = $total; Output = $out }
}

try {
    $clientText = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code\PayPalOrdersV2Client.vb'))
    $base = Invoke-Variant $clientText 'real'
    if (-not $base.Compiled) {
        Check 'BEHAVIOR_COMPILES_WITH_THE_REAL_CLIENT' $false
        $base.Output | Select-Object -First 25 | ForEach-Object { Write-Output $_ }
    } else {
        Check 'BEHAVIOR_COMPILES_WITH_THE_REAL_CLIENT' $true
        $failedLine = @($base.Output | Where-Object { $_ -like 'FAIL *' }) | Select-Object -First 1
        if ($failedLine) { Write-Output $failedLine }
        Check ('BEHAVIOR_ALL_CHECKS_PASS (' + $base.Passed + ')') $base.Ok
        if ($base.Passed -lt 120) { Check 'BEHAVIOR_RAN_AT_LEAST_120_CHECKS' $false }
    }

    # --- mutazioni sul client (ancoraggio esatto; Occurrence = n-esima occorrenza, 1 se omessa) ---
    $mutants = @()
    $mutantsFile = Join-Path $PSScriptRoot 'PayPalAuthorizeMutants.psd1'
    if (Test-Path -LiteralPath $mutantsFile) { $mutants = @((Import-PowerShellDataFile -LiteralPath $mutantsFile).Mutants) }
    if (-not $SkipMutants) { Check ('MUTANTS_FILE_PRESENT_WITH_AT_LEAST_20 (' + $mutants.Count + ')') ($mutants.Count -ge 20) }
    if (-not $SkipMutants -and $base.Compiled) {
        foreach ($m in $mutants) {
            $occurrence = 1
            if ($m.ContainsKey('Occurrence')) { $occurrence = [int]$m.Occurrence }
            $idx = -1
            $from = 0
            for ($k = 1; $k -le $occurrence; $k++) {
                $idx = $clientText.IndexOf([string]$m.Find, $from, [StringComparison]::Ordinal)
                if ($idx -lt 0) { break }
                $from = $idx + 1
            }
            if ($idx -lt 0) { Check ('MUTANT_' + $m.Name + '_ANCHOR_PRESENT') $false; continue }
            $mutated = $clientText.Substring(0, $idx) + [string]$m.Replace + $clientText.Substring($idx + ([string]$m.Find).Length)
            $res = Invoke-Variant $mutated ('m' + $m.Name)
            if (-not $res.Compiled) { Check ('MUTANT_' + $m.Name + '_COMPILES_(INVALID_MUTANT)') $false; continue }
            Check ('MUTATION_DETECTED_' + $m.Name) (-not $res.Ok)
        }
    }
} finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
Write-Output ('PAYPAL_AUTHORIZE_CLIENT_TOTAL pass=' + $pass + ' fail=' + $fail)
if ($fail -gt 0) { exit 1 }
