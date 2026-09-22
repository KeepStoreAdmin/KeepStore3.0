[CmdletBinding()]
param([string]$RepositoryRoot)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
function Assert-Check([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "PAYPAL_ORDERS_V2_FAILED: $Name" }
    [pscustomobject]@{ Test = $Name; Result = 'PASS' }
}
function Read-Source([string]$Path) { Get-Content -Raw -LiteralPath (Join-Path $RepositoryRoot $Path) }
$client = Read-Source 'App_Code\PayPalOrdersV2Client.vb'
$repository = Read-Source 'App_Code\PayPalCheckoutRepository.vb'
$state = Read-Source 'App_Code\PayPalPaymentState.vb'
$checkout = Read-Source 'paypalcheckout.aspx.vb'
$returnPage = Read-Source 'paypalreturn.aspx.vb'
$recheck = Read-Source 'paypalrecheck.aspx.vb'
$webhook = Read-Source 'paypalwebhook.aspx.vb'
$safety = Read-Source 'App_Code\PayPalCheckoutSafetyPolicy.vb'
$runtimeFiles = @(
    'App_Code\PayPalCheckoutConfig.vb','App_Code\PayPalCheckoutRepository.vb','App_Code\PayPalOrdersV2Client.vb',
    'App_Code\PayPalCheckoutSafetyPolicy.vb','App_Code\PayPalPaymentState.vb','paypalcheckout.aspx.vb',
    'paypalreturn.aspx.vb','paypalrecheck.aspx.vb','paypalwebhook.aspx.vb','carrello.aspx.vb','ordine.aspx.vb',
    'coupon_opzioni.aspx.vb','Page.master.vb')
$runtime = ($runtimeFiles | ForEach-Object { Read-Source $_ }) -join "`n"
$results = @()
$results += Assert-Check ($client.Contains('/v1/oauth2/token') -and $client.Contains('grant_type=client_credentials')) '33 OAuth contract'
$results += Assert-Check ($client.Contains('/v2/checkout/orders') -and $client.Contains('/capture')) '34 Orders v2 routes'
$results += Assert-Check ($client.Contains('PayPal-Request-Id')) '35 request id header'
$results += Assert-Check ($client.Contains('IPayPalHttpTransport')) '36 fakeable transport'
$results += Assert-Check ($repository.Contains('UNIQUE') -or $repository.Contains('INSERT IGNORE')) '37 duplicate return persistence guard'
$results += Assert-Check ($repository.Contains('String.Equals(tx.Stato, "COMPLETED"') -and $repository.Contains('normalized <> "COMPLETED"')) '38 monotonic completed state'
$results += Assert-Check ($state.Contains('If doc.Pagato = 1 Then') -and $state.Contains('ALREADY_COMPLETED')) '39 recheck completed no recapture'
$results += Assert-Check ($state.Contains('GetOrder(tx.PayPalOrderId)') -and -not $state.Contains('CaptureOrder(')) '40 recheck REST GET only'
$results += Assert-Check ($returnPage.Contains('CaptureOrder(tx.PayPalOrderId, tx.CaptureRequestId)')) '41 deterministic capture retry'
$results += Assert-Check ($returnPage.Contains('ValidateSnapshot') -and $checkout.Contains('ValidateSnapshot')) '42 create and return authoritative validation'
$results += Assert-Check ($webhook.Contains('VerifyWebhookSignature') -and $webhook.Contains('SIGNATURE_REJECTED')) '43 webhook signature verified'
$results += Assert-Check ($webhook.Contains('LoadTransactionForExternalReference') -and $webhook.Contains('ApplyAuthoritativeState')) '44 webhook lookup before DML'
$results += Assert-Check ($repository.Contains('paypal_checkout_eventi') -and $repository.Contains('INSERT IGNORE')) '45 duplicate webhook idempotency'
$results += Assert-Check ($webhook.Contains('MatchesTransaction') -and $webhook.Contains('MerchantId') -and $webhook.Contains('PayeeEmail')) '46 webhook tenant/payee/merchant validation'
$results += Assert-Check ($safety.Contains('Request.IsLocal') -and $safety.Contains('IsLoopback') -and $safety.Contains('IsSecureConnection')) '47 localhost and HTTP blocked'
$results += Assert-Check ($checkout.Contains('StorefrontCanonicalHostPolicy.BuildCanonicalUrl')) '48 authoritative tenant return URLs'
$results += Assert-Check ($state.Contains('PP-ORDER:') -and $state.Contains('TXN:')) '49 payment markers'
$results += Assert-Check ($repository.Contains('Pagato=@pagato') -and $repository.Contains('paid, 1, 0')) '50 paid only from completed capture'
$results += Assert-Check (-not ($runtime -match 'SetExpressCheckout|GetExpressCheckoutDetails|DoExpressCheckoutPayment|api-3t|EC-TOKEN|ApiUsername|ApiPasswordProtetta|ApiSignatureProtetta|sandbox\.paypal\.com')) '51 zero legacy runtime references'
$results += Assert-Check (-not (Test-Path (Join-Path $RepositoryRoot 'ipn.aspx')) -and -not (Test-Path (Join-Path $RepositoryRoot 'ipn.aspx.vb'))) '52 legacy IPN removed'
$results += Assert-Check (-not $runtime.Contains('ClientSecret = "')) '53 no hardcoded secret'
$results += Assert-Check ($client.Contains('PAYMENT.CAPTURE.COMPLETED') -eq $false -and $webhook.Contains('PAYMENT.CAPTURE.COMPLETED')) '54 webhook event scope'

$framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
if (-not (Test-Path $framework)) { $framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\vbc.exe' }
$out = Join-Path ([IO.Path]::GetTempPath()) ('paypal-orders-v2-' + [Guid]::NewGuid().ToString('N') + '.exe')
try {
    & $framework /nologo /target:exe /out:$out /r:System.dll /r:System.Configuration.dll /r:System.Web.dll /r:System.Web.Extensions.dll `
        (Join-Path $RepositoryRoot 'Tools\PayPalOrdersV2Harness.vb') `
        (Join-Path $RepositoryRoot 'App_Code\PayPalCheckoutConfig.vb') `
        (Join-Path $RepositoryRoot 'App_Code\PayPalOrdersV2Client.vb') `
        (Join-Path $RepositoryRoot 'App_Code\PayPalCheckoutSafetyPolicy.vb')
    if ($LASTEXITCODE -ne 0) { throw 'PAYPAL_ORDERS_V2_HARNESS_COMPILE_FAILED' }
    $dynamic = & $out
    if ($LASTEXITCODE -ne 0) { throw 'PAYPAL_ORDERS_V2_HARNESS_FAILED' }
    $dynamic | Write-Output
} finally { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
$results | Format-Table -AutoSize
"PAYPAL_ORDERS_V2_STATIC_TOTAL=$($results.Count)"
"PAYPAL_ORDERS_V2_TOTAL=$($results.Count + 32)"
