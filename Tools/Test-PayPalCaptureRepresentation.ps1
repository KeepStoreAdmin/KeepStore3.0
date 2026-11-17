[CmdletBinding()]
param([string]$RepositoryRoot, [switch]$SkipMutants)

# PAYPAL-CAPTURE-REPRESENTATION-1A: il percorso CAPTURE (create, capture, GET di verifica) accetta la rappresentazione DOCUMENTATA da PayPal
# (esempi della specifica ufficiale: niente intent, payee, custom_id, invoice_id, importo di unita) senza indebolire i controlli di tenant, importo e payee.
# (1) comportamento reale: compila il client vero con un harness e un transport finto (nessuna rete; fixture = esempi ufficiali PayPal);
# (2) pin sul sorgente delle tre pagine (return, checkout, webhook): le pagine non sono eseguibili in harness;
# (3) mutazioni: copie del client (e delle pagine) con UNA sola sostituzione ancorata; ogni mutante deve far cadere almeno un controllo
#     (un mutante che non compila e INVALIDO e fa fallire il test).
# Solo ASCII (Windows PowerShell 5.1).
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
if (-not (Test-Path -LiteralPath $vbc)) { $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\vbc.exe' }
$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok) { if ($ok) { $script:pass++; Write-Output ('PASS ' + $name) } else { $script:fail++; Write-Output ('FAIL ' + $name) } }
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-paypal-capture-repr-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

function Invoke-Variant([string]$clientSource, [string]$label) {
    $dir = Join-Path $work $label
    New-Item -ItemType Directory -Path $dir | Out-Null
    $clientFile = Join-Path $dir 'PayPalOrdersV2Client.vb'
    [IO.File]::WriteAllText($clientFile, $clientSource, (New-Object Text.UTF8Encoding($false)))
    $exe = Join-Path $dir 'harness.exe'
    $log = & $vbc /nologo /target:exe /out:$exe /r:System.dll /r:System.Configuration.dll /r:System.Web.dll /r:System.Web.Extensions.dll `
        (Join-Path $RepositoryRoot 'Tools\PayPalCaptureRepresentationHarness.vb') `
        (Join-Path $RepositoryRoot 'App_Code\PayPalCheckoutConfig.vb') `
        $clientFile `
        (Join-Path $RepositoryRoot 'App_Code\PayPalCheckoutSafetyPolicy.vb') 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) {
        return [pscustomobject]@{ Compiled = $false; Ok = $false; Passed = 0; Output = @($log | ForEach-Object { $_.ToString() }) }
    }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $out = @(& $exe 2>&1 | ForEach-Object { $_.ToString() }); $code = $LASTEXITCODE; $ErrorActionPreference = $prev
    $totalLine = $out | Where-Object { $_ -match '^PAYPAL_CAPTURE_REPRESENTATION_TOTAL=(\d+)$' } | Select-Object -Last 1
    $total = 0
    if ($totalLine) { $total = [int]($totalLine -replace '^PAYPAL_CAPTURE_REPRESENTATION_TOTAL=', '') }
    return [pscustomobject]@{ Compiled = $true; Ok = ($code -eq 0 -and $total -gt 0); Passed = $total; Output = $out }
}

function Read-Text([string]$rel) { return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $rel)) }
function Count-Of([string]$text, [string]$needle) { return ([regex]::Matches($text, [regex]::Escape($needle))).Count }

# --- pin sul sorgente: chi chiama che cosa dopo l'addebito (ritorna i risultati; li stampa solo con prefisso vuoto) ---
function Run-Pins([string]$return, [string]$checkout, [string]$webhook, [string]$client, [string]$prefix) {
    $r = [ordered]@{}
    $call = 'CaptureOrderVerified(doc, tx.PayPalOrderId, tx.CaptureRequestId, tx.Importo, tx.Valuta)'
    $r['PIN01_RETURN_USES_THE_VERIFIED_CAPTURE_WITH_THE_PERSISTED_REQUEST_ID'] = (Count-Of $return ('client.' + $call)) -eq 1
    $r['PIN02_CHECKOUT_USES_THE_VERIFIED_CAPTURE_WITH_THE_PERSISTED_REQUEST_ID'] = (Count-Of $checkout ('client.' + $call)) -eq 1
    $r['PIN03_WEBHOOK_USES_THE_VERIFIED_CAPTURE_WITH_THE_PERSISTED_REQUEST_ID'] = (Count-Of $webhook ('client.' + $call)) -eq 1
    $r['PIN04_NO_PAGE_CALLS_THE_BARE_CAPTURE'] = -not (($return + $checkout + $webhook) -match '\.CaptureOrder\(')
    $r['PIN05_PAGES_REVALIDATE_THE_VERIFIED_SNAPSHOT_WITH_THE_STRICT_VALIDATOR'] = $return.Contains('ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, capture.Snapshot, tx.Importo, tx.Valuta)') -and $checkout.Contains('ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, captured.Snapshot, tx.Importo, tx.Valuta)') -and $webhook.Contains('ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, capture.Snapshot, tx.Importo, tx.Valuta)')
    $r['PIN06_CHECKOUT_CHECKS_THE_CREATE_RESPONSE_WITH_THE_LENIENT_CHECK'] = ($checkout.Contains('CheckCreatedOrder(doc, cfg, response.Snapshot, tx.Importo, tx.Valuta)')) -and -not ($checkout -match 'ValidateSnapshot(AgainstAttempt)?\([^\r\n]*response\.Snapshot')
    $r['PIN07_THE_AUTHORITATIVE_REPRESENTATION_GATE_IS_GONE'] = -not $client.Contains('HasAuthoritativeRepresentation')
    $r['PIN08_FAILURES_AFTER_THE_CAPTURE_LOG_THE_REASON'] = $return.Contains('DescribeFailure(capture)') -and $checkout.Contains('DescribeFailure(captured)') -and $checkout.Contains('DescribeFailure(response)') -and $webhook.Contains('DescribeFailure(capture)')
    $r['PIN09_PAGES_APPLY_THE_VERIFIED_SNAPSHOT'] = $return.Contains('ApplyAuthoritativeState(tx, capture.Snapshot, String.Empty)') -and $checkout.Contains('ApplyAuthoritativeState(tx, captured.Snapshot, String.Empty)') -and $webhook.Contains('authoritative = capture.Snapshot')
    $r['PIN10_SENDORDER_SIGNATURE_UNCHANGED_FOR_THE_P1_ANCHORS'] = $client.Contains('Optional ByVal requireRepresentation As Boolean = False,') -and $client.Contains('Optional ByVal preferRepresentation As Boolean = False,') -and $client.Contains('Optional ByVal includeIssue As Boolean = False) As PayPalOrdersV2Result')
    $h = $client.IndexOf('Public Function CaptureOrderVerified(', [StringComparison]::Ordinal)
    $c1 = -1
    $g1 = -1
    if ($h -ge 0) { $c1 = $client.IndexOf('CaptureOrder(orderId, requestId)', $h, [StringComparison]::Ordinal) }
    if ($c1 -ge 0) { $g1 = $client.IndexOf('GetOrder(orderId)', $c1, [StringComparison]::Ordinal) }
    $r['PIN11_GET_COMES_AFTER_THE_CAPTURE_IN_THE_HELPER'] = ($h -ge 0) -and ($c1 -gt $h) -and ($g1 -gt $c1)
    $r['PIN12_SUCCESS_IS_REQUIRED_BEFORE_ANYTHING_IS_APPLIED'] = $return.Contains('capture Is Nothing OrElse Not capture.Success OrElse') -and $checkout.Contains('captured Is Nothing OrElse Not captured.Success OrElse') -and $webhook.Contains('capture Is Nothing OrElse Not capture.Success OrElse')
    if ($prefix -eq '') { foreach ($k in $r.Keys) { Check $k ([bool]$r[$k]) } }
    return $r
}

try {
    $clientText = Read-Text 'App_Code\PayPalOrdersV2Client.vb'
    $returnText = Read-Text 'paypalreturn.aspx.vb'
    $checkoutText = Read-Text 'paypalcheckout.aspx.vb'
    $webhookText = Read-Text 'paypalwebhook.aspx.vb'

    $base = Invoke-Variant $clientText 'real'
    if (-not $base.Compiled) {
        Check 'BEHAVIOR_COMPILES_WITH_THE_REAL_CLIENT' $false
        $base.Output | Select-Object -First 25 | ForEach-Object { Write-Output $_ }
    } else {
        Check 'BEHAVIOR_COMPILES_WITH_THE_REAL_CLIENT' $true
        $failedLine = @($base.Output | Where-Object { $_ -like 'FAIL *' }) | Select-Object -First 1
        if ($failedLine) { Write-Output $failedLine }
        Check ('BEHAVIOR_ALL_CHECKS_PASS (' + $base.Passed + ')') $base.Ok
        if ($base.Passed -lt 130) { Check 'BEHAVIOR_RAN_AT_LEAST_130_CHECKS' $false }
    }

    $null = Run-Pins $returnText $checkoutText $webhookText $clientText ''

    # --- mutazioni sul client (ancoraggio esatto; Occurrence = n-esima occorrenza, 1 se omessa) ---
    $mutants = @()
    $mutantsFile = Join-Path $PSScriptRoot 'PayPalCaptureRepresentationMutants.psd1'
    if (Test-Path -LiteralPath $mutantsFile) { $mutants = @((Import-PowerShellDataFile -LiteralPath $mutantsFile).Mutants) }
    if (-not $SkipMutants) { Check ('MUTANTS_FILE_PRESENT_WITH_AT_LEAST_35 (' + $mutants.Count + ')') ($mutants.Count -ge 35) }
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

        # --- mutazioni sulle pagine (pin): ogni alterazione deve far cadere almeno un pin ---
        $pageMutants = @(
            @{ n = 'P01_RETURN_BACK_TO_THE_BARE_CAPTURE'; k = 'return'; f = 'client.CaptureOrderVerified(doc, tx.PayPalOrderId, tx.CaptureRequestId, tx.Importo, tx.Valuta)'; r = 'client.CaptureOrder(tx.PayPalOrderId, tx.CaptureRequestId)' },
            @{ n = 'P02_CHECKOUT_FRESH_REQUEST_ID_ON_CAPTURE'; k = 'checkout'; f = 'client.CaptureOrderVerified(doc, tx.PayPalOrderId, tx.CaptureRequestId, tx.Importo, tx.Valuta)'; r = 'client.CaptureOrderVerified(doc, tx.PayPalOrderId, tx.CreateRequestId, tx.Importo, tx.Valuta)' },
            @{ n = 'P03_WEBHOOK_BACK_TO_THE_BARE_CAPTURE'; k = 'webhook'; f = 'client.CaptureOrderVerified(doc, tx.PayPalOrderId, tx.CaptureRequestId, tx.Importo, tx.Valuta)'; r = 'client.CaptureOrder(tx.PayPalOrderId, tx.CaptureRequestId)' },
            @{ n = 'P04_RETURN_DROPS_THE_SUCCESS_FLAG'; k = 'return'; f = 'capture Is Nothing OrElse Not capture.Success OrElse'; r = 'capture Is Nothing OrElse' },
            @{ n = 'P04B_RETURN_DROPS_THE_STRICT_REVALIDATION'; k = 'return'; f = ' OrElse Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, capture.Snapshot, tx.Importo, tx.Valuta) Then'; r = ' Then' },
            @{ n = 'P04C_CHECKOUT_DROPS_THE_SUCCESS_FLAG'; k = 'checkout'; f = 'captured Is Nothing OrElse Not captured.Success OrElse'; r = 'captured Is Nothing OrElse' },
            @{ n = 'P04D_CHECKOUT_DROPS_THE_STRICT_REVALIDATION'; k = 'checkout'; f = 'Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, captured.Snapshot, tx.Importo, tx.Valuta) OrElse'; r = '' },
            @{ n = 'P04E_WEBHOOK_DROPS_THE_SUCCESS_FLAG'; k = 'webhook'; f = 'capture Is Nothing OrElse Not capture.Success OrElse'; r = 'capture Is Nothing OrElse' },
            @{ n = 'P04F_WEBHOOK_DROPS_THE_STRICT_REVALIDATION'; k = 'webhook'; f = ' OrElse Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, capture.Snapshot, tx.Importo, tx.Valuta) Then'; r = ' Then' },
            @{ n = 'P05_CHECKOUT_CREATE_STRICT_AGAIN'; k = 'checkout'; f = 'CheckCreatedOrder(doc, cfg, response.Snapshot, tx.Importo, tx.Valuta)'; r = 'ValidateSnapshotAgainstAttempt(doc, cfg, response.Snapshot.OrderId, response.Snapshot, tx.Importo, tx.Valuta)' },
            @{ n = 'P06_RETURN_DROPS_THE_REASON_FROM_THE_LOG'; k = 'return'; f = 'DescribeFailure(capture)'; r = 'String.Empty' },
            @{ n = 'P07_CHECKOUT_APPLIES_THE_RAW_RESPONSE'; k = 'checkout'; f = 'ApplyAuthoritativeState(tx, captured.Snapshot, String.Empty)'; r = 'ApplyAuthoritativeState(tx, details.Snapshot, String.Empty)' },
            @{ n = 'P08_WEBHOOK_APPLIES_THE_DETAILS_BEFORE_THE_CAPTURE'; k = 'webhook'; f = 'authoritative = capture.Snapshot'; r = 'authoritative = details.Snapshot' }
        )
        foreach ($pm in $pageMutants) {
            $texts = @{ return = $returnText; checkout = $checkoutText; webhook = $webhookText }
            $t = $texts[$pm.k]
            $at = $t.IndexOf([string]$pm.f, [StringComparison]::Ordinal)
            if ($at -lt 0) { Check ('PAGE_MUTANT_' + $pm.n + '_ANCHOR_PRESENT') $false; continue }
            $texts[$pm.k] = $t.Substring(0, $at) + [string]$pm.r + $t.Substring($at + ([string]$pm.f).Length)
            $res = Run-Pins $texts.return $texts.checkout $texts.webhook $clientText 'mut:'
            $killed = @($res.Values | Where-Object { -not $_ }).Count -gt 0
            Check ('MUTATION_DETECTED_' + $pm.n) $killed
        }
    }
} finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
Write-Output ('PAYPAL_CAPTURE_REPRESENTATION_TOTAL pass=' + $pass + ' fail=' + $fail)
if ($fail -gt 0) { exit 1 }
