[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$compiler = Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    $compiler = Join-Path $env:windir 'Microsoft.NET\Framework\v4.0.30319\vbc.exe'
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'PAYPAL_TEST_COMPILER_NOT_FOUND' }

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStore-PayPalSafety-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
$executable = Join-Path $temporaryRoot 'PayPalProductionSafetyHarness.exe'
$passed = 0

function Assert-Check([bool]$Condition, [string]$Code) {
    if (-not $Condition) { throw $Code }
    $script:passed += 1
    Write-Output ('PASS ' + $Code)
}

try {
    $policyPath = Join-Path $repo 'App_Code\PayPalProductionSafetyPolicy.vb'
    $harnessPath = Join-Path $repo 'Tools\PayPalProductionSafetyHarness.vb'
    $arguments = @(
        '/nologo', '/quiet', '/target:exe', '/optionstrict+', '/optionexplicit+',
        '/main:PayPalProductionSafetyHarness', ('/out:' + $executable),
        ('/reference:' + (Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\System.dll')),
        ('/reference:' + (Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\System.Web.dll')),
        $policyPath, $harnessPath
    )
    & $compiler @arguments
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw 'PAYPAL_TEST_BUILD_FAILED'
    }

    $runtimeOutput = @(& $executable)
    Assert-Check ($LASTEXITCODE -eq 0 -and ($runtimeOutput -join "`n") -match 'PAYPAL_PRODUCTION_SAFETY_PASS checks=7') '08_POLICY_MATRIX'

    $config = Get-Content -LiteralPath (Join-Path $repo 'App_Code\PayPalCheckoutConfig.vb') -Raw
    $repository = Get-Content -LiteralPath (Join-Path $repo 'App_Code\PayPalExpressRepository.vb') -Raw
    $cart = Get-Content -LiteralPath (Join-Path $repo 'carrello.aspx.vb') -Raw
    $checkout = Get-Content -LiteralPath (Join-Path $repo 'paypalcheckout.aspx.vb') -Raw
    $returnPage = Get-Content -LiteralPath (Join-Path $repo 'paypalreturn.aspx.vb') -Raw
    $paymentState = Get-Content -LiteralPath (Join-Path $repo 'App_Code\PayPalPaymentState.vb') -Raw

    Assert-Check ($config -match 'CanCallApiForRequest' -and
                  $config -match 'PayPalProductionSafetyPolicy\.IsApiCallAllowed') '09_CONFIG_USES_CENTRAL_POLICY'
    Assert-Check ($repository -match 'LoadConfigForCompanyPayment' -and
                  $config -match 'LoadForCompanyPayment') '10_TENANT_PAYMENT_CONFIG_RESOLVED'
    Assert-Check ($cart -match 'gvPagamento_RowDataBound' -and
                  $cart -match 'e\.Row\.Visible = False' -and
                  $cart -match 'cfg\.CanCallApiForRequest\(HttpContext\.Current\)') '11_UNSAFE_PAYPAL_NOT_SELECTABLE'
    Assert-Check ($cart -match 'IsAuthoritativePaymentValid[\s\S]+PayPalPaymentState\.PAYPAL_ONLINE_VALUE[\s\S]+CanCallApiForRequest') '12_TAMPERED_SELECTION_BLOCKED'

    $checkoutGate = $checkout.IndexOf('CanCallApiForRequest', [StringComparison]::Ordinal)
    $checkoutCall = $checkout.IndexOf('SetExpressCheckout', [StringComparison]::Ordinal)
    Assert-Check ($checkoutGate -ge 0 -and $checkoutCall -gt $checkoutGate) '13_CHECKOUT_GATE_PRECEDES_SET'
    $returnGate = $returnPage.IndexOf('CanCallApiForRequest', [StringComparison]::Ordinal)
    $returnCall = $returnPage.IndexOf('GetExpressCheckoutDetails', [StringComparison]::Ordinal)
    Assert-Check ($returnGate -ge 0 -and $returnCall -gt $returnGate) '14_RETURN_GATE_PRECEDES_GET_DO'
    $recheckGate = $paymentState.IndexOf('CanCallApiForRequest', [StringComparison]::Ordinal)
    $recheckCall = $paymentState.IndexOf('GetTransactionDetails', [StringComparison]::Ordinal)
    Assert-Check ($recheckGate -ge 0 -and $recheckCall -gt $recheckGate) '15_RECHECK_GATE_PRECEDES_API'

    Assert-Check ($paymentState -match 'MarkPendingWithExpressToken[\s\S]+MarkPendingWithTransaction' -and
                  $paymentState -match 'MarkCompleted[\s\S]+Pagato=1' -and
                  $paymentState -notmatch 'BuildExpressTokenValue[\s\S]{0,300}Pagato=1') '16_EC_TOKEN_NEVER_MARKS_PAID'
    Assert-Check ($cart -match 'PaymentOnline.+PAYPAL_ONLINE_VALUE Then Return True' -and
                  $cart -match 'If SafeIntFromDb\(DataBinder\.Eval\(e\.Row\.DataItem, "OnLine"\), 0\) <> PayPalPaymentState\.PAYPAL_ONLINE_VALUE Then Return') '17_OTHER_PAYMENT_METHODS_UNCHANGED'
    $harnessSources = (Get-Content -LiteralPath $policyPath -Raw) + "`n" +
                      (Get-Content -LiteralPath $harnessPath -Raw)
    Assert-Check ($harnessSources -notmatch '(?i)paypal\.com|HttpWebRequest|WebClient|HttpClient') '18_NO_NETWORK_IN_HARNESS'

    Write-Output ('PAYPAL_PRODUCTION_SAFETY_TEST_PASS checks=' + $passed)
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        [IO.Directory]::Delete([IO.Path]::GetFullPath($temporaryRoot), $true)
    }
}
