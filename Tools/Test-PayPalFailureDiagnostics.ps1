[CmdletBinding()]
param([string]$RepositoryRoot)

# PAYPAL-FAIL-DIAGNOSTICS-1A: ogni fallimento del percorso PayPal lascia una riga di registro con il MOTIVO (e, per le chiamate a PayPal, lo stato HTTP e il codice di errore
# sicuro), invece di rimandare in silenzio al dettaglio ordine. Il 16/11/2026 un ordine di prova e rimasto senza schermata PayPal e senza alcuna traccia.
# Prove: (1) pin del sorgente delle tre pagine; (2) comportamento reale degli aiuti (compila tutta App_Code); (3) mutazioni. Solo ASCII (Windows PowerShell 5.1).
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok) { if ($ok) { $script:pass++; Write-Output ('PASS ' + $name) } else { $script:fail++; Write-Output ('FAIL ' + $name) } }
function Read([string]$rel) { return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $rel)) }
function Body([string]$text, [string]$signature) {
    $i = $text.IndexOf($signature, [StringComparison]::Ordinal)
    if ($i -lt 0) { return '' }
    $j = $text.IndexOf('End Sub', $i, [StringComparison]::Ordinal)
    if ($j -lt 0) { return '' }
    return $text.Substring($i, $j - $i)
}
function Count([string]$text, [string]$needle) { return ([regex]::Matches($text, [regex]::Escape($needle))).Count }

function Run-Pins([string]$checkout, [string]$return, [string]$webhook, [string]$state, [string]$client, [string]$prefix) {
    $r = @{}
    $r['SD01_CHECKOUT_FAIL_LOGS_THE_REASON'] = (Body $checkout 'Private Sub Fail(').Contains('PayPalPaymentState.LogCheckoutFailure(')
    $r['SD02_RETURN_FAIL_LOGS_THE_REASON'] = (Body $return 'Private Sub Fail(').Contains('PayPalPaymentState.LogCheckoutFailure(')
    $r['SD03_WEBHOOK_FINISH_LOGS_NON_OK'] = ((Body $webhook 'Private Sub Finish(').Contains('KeepStoreLog.Info("paypal-webhook"')) -and ((Body $webhook 'Private Sub Finish(').Contains('statusCode'))
    $r['SD04_CHECKOUT_PAYPAL_CALLS_DESCRIBE_THE_FAILURE'] = (Count $checkout 'DescribeFailure(') -ge 3
    $r['SD05_RETURN_PAYPAL_CALLS_DESCRIBE_THE_FAILURE'] = (Count $return 'DescribeFailure(') -ge 2
    $r['SD06_HELPERS_EXIST'] = $state.Contains('Public Sub LogCheckoutFailure(') -and $client.Contains('Public Shared Function DescribeFailure(')
    $log = Body $state 'Public Sub LogCheckoutFailure('
    $r['SD07_NO_SECRET_IN_THE_LOG_LINE'] = ($log.Length -gt 0) -and -not ($log -match 'ClientSecret|AccessToken|Authorization|\.Body|Password')
    $r['SD08_FAIL_STILL_REDIRECTS_WITH_KO'] = (Body $checkout 'Private Sub Fail(').Contains('RedirectResult(documentId, "ko")') -and (Body $return 'Private Sub Fail(').Contains('RedirectResult(documentId, "ko")')
    foreach ($k in ($r.Keys | Sort-Object)) { Check ($prefix + $k) $r[$k] }
    return $r
}

$checkout = Read 'paypalcheckout.aspx.vb'
$return = Read 'paypalreturn.aspx.vb'
$webhook = Read 'paypalwebhook.aspx.vb'
$state = Read 'App_Code\PayPalPaymentState.vb'
$client = Read 'App_Code\PayPalOrdersV2Client.vb'
$null = Run-Pins $checkout $return $webhook $state $client ''

# --- comportamento reale: compila tutta App_Code con un harness minimo ---
$vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-paypal-diag-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $harness = Join-Path $work 'harness.vb'
    $lines = @(
        'Option Strict On', 'Imports System',
        'Module DiagHarness',
        '  Private _f As Integer = 0',
        '  Private Sub C(ByVal n As String, ByVal ok As Boolean)',
        '    If ok Then Console.WriteLine("PASS " & n) Else Console.WriteLine("FAIL " & n) : _f += 1',
        '  End Sub',
        '  Function Main() As Integer',
        '    Dim r As New PayPalOrdersV2Result With {.StatusCode = 422, .ErrorCode = "UNPROCESSABLE_ENTITY"}',
        '    C("B01_DESCRIBES_STATUS_AND_CODE", PayPalOrdersV2Client.DescribeFailure(r) = "http=422 code=UNPROCESSABLE_ENTITY")',
        '    C("B02_NO_RESULT", PayPalOrdersV2Client.DescribeFailure(Nothing) = "result=none")',
        '    Dim dirty As New PayPalOrdersV2Result With {.StatusCode = 400, .ErrorCode = "A" & vbCr & vbLf & "B" & New String("x"c, 300)}',
        '    Dim d As String = PayPalOrdersV2Client.DescribeFailure(dirty)',
        '    C("B03_ONE_LINE_AND_BOUNDED", d.IndexOf(vbCr) < 0 AndAlso d.IndexOf(vbLf) < 0 AndAlso d.Length <= 120)',
        '    Dim thrown As Boolean = False',
        '    Try',
        '      PayPalPaymentState.LogCheckoutFailure("paypal-checkout-diag-test", 123, Nothing, Nothing)',
        '      PayPalPaymentState.LogCheckoutFailure("paypal-checkout-diag-test", 123, "motivo" & vbCrLf & "riga2", "http=500 code=X")',
        '    Catch',
        '      thrown = True',
        '    End Try',
        '    C("B04_LOGGING_NEVER_THROWS", Not thrown)',
        '    Return _f',
        '  End Function',
        'End Module')
    [IO.File]::WriteAllLines($harness, $lines)
    $refs = New-Object System.Collections.ArrayList
    foreach ($d in @(Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'Bin') -Filter *.dll -File)) {
        try { [void][Reflection.AssemblyName]::GetAssemblyName($d.FullName); [void]$refs.Add('/r:' + $d.FullName); Copy-Item -LiteralPath $d.FullName -Destination (Join-Path $work $d.Name) -Force } catch { }
    }
    function Build([string]$appCode, [string]$exeName) {
        $exe = Join-Path $work $exeName
        $files = @(Get-ChildItem -LiteralPath $appCode -Filter *.vb -File | ForEach-Object { $_.FullName })
        $out = & $vbc /nologo /target:exe /out:$exe /imports:System.Collections.Generic,System.Configuration /r:System.dll /r:System.Data.dll /r:System.Configuration.dll /r:System.Web.dll /r:System.Web.Extensions.dll /r:System.Drawing.dll /r:System.Xml.dll /r:System.Xml.Linq.dll /r:System.Core.dll /r:System.Runtime.Serialization.dll /r:System.Security.dll /r:System.Net.Http.dll /r:System.ComponentModel.DataAnnotations.dll @($refs.ToArray()) $harness @files 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { return $null }
        return $exe
    }
    $exe = Build (Join-Path $RepositoryRoot 'App_Code') 'real.exe'
    if ($null -eq $exe) { Check 'BEHAVIOR_COMPILES_WITH_THE_REAL_APP_CODE' $false }
    else {
        Check 'BEHAVIOR_COMPILES_WITH_THE_REAL_APP_CODE' $true
        $outLines = @(& $exe 2>&1 | ForEach-Object { $_.ToString() })
        foreach ($l in $outLines) { if ($l -like 'PASS *') { $script:pass++; Write-Output $l } elseif ($l -like 'FAIL *') { $script:fail++; Write-Output $l } }
        if (@($outLines | Where-Object { $_ -like 'PASS *' -or $_ -like 'FAIL *' }).Count -lt 4) { Check 'BEHAVIOR_RAN_ALL_FOUR_CASES' $false }
    }
} finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }

# --- mutazioni sui pin (ogni alterazione deve far cadere almeno un controllo) ---
$mutants = @(
    @{ n = 'M1_CHECKOUT_FAIL_WITHOUT_LOG'; k = 'checkout'; f = 'PayPalPaymentState.LogCheckoutFailure("paypal-checkout", documentId, message'; r = "' removed(documentId, message" },
    @{ n = 'M2_RETURN_FAIL_WITHOUT_LOG'; k = 'return'; f = 'PayPalPaymentState.LogCheckoutFailure('; r = "' removed(" },
    @{ n = 'M3_WEBHOOK_SILENT'; k = 'webhook'; f = 'KeepStoreLog.Info("paypal-webhook"'; r = "' removed(""paypal-webhook""" },
    @{ n = 'M4_CHECKOUT_NO_DESCRIBE'; k = 'checkout'; f = 'DescribeFailure('; r = 'NoDescribe(' ; all = $true },
    @{ n = 'M5_LOG_LEAKS_BODY'; k = 'state'; f = 'Public Sub LogCheckoutFailure('; r = "Public Sub LogCheckoutFailure(ByVal ClientSecret As String, " }
)
foreach ($m in $mutants) {
    $texts = @{ checkout = $checkout; return = $return; webhook = $webhook; state = $state; client = $client }
    $t = $texts[$m.k]
    if (-not $t.Contains($m.f)) { Check ('MUTANT_' + $m.n + '_ANCHOR_PRESENT') $false; continue }
    $texts[$m.k] = if ($m.ContainsKey('all')) { $t.Replace($m.f, $m.r) } else { $t.Substring(0, $t.IndexOf($m.f, [StringComparison]::Ordinal)) + $m.r + $t.Substring($t.IndexOf($m.f, [StringComparison]::Ordinal) + $m.f.Length) }
    $before = $script:fail
    $res = Run-Pins $texts.checkout $texts.return $texts.webhook $texts.state $texts.client 'mut:'
    $killed = @($res.Values | Where-Object { -not $_ }).Count -gt 0
    # le righe PASS/FAIL dei pin mutati non contano nel totale: si riportano a quelle vere
    $script:fail = $before
    $script:pass = $script:pass - @($res.Values | Where-Object { $_ }).Count
    Check ('MUTATION_DETECTED_' + $m.n) $killed
}
Write-Output ('PAYPAL_FAIL_DIAGNOSTICS_TOTAL pass=' + $pass + ' fail=' + $fail)
if ($fail -gt 0) { exit 1 }
