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
$config = Read-Source 'App_Code\PayPalCheckoutConfig.vb'
$state = Read-Source 'App_Code\PayPalPaymentState.vb'
$checkout = Read-Source 'paypalcheckout.aspx.vb'
$returnPage = Read-Source 'paypalreturn.aspx.vb'
$recheck = Read-Source 'paypalrecheck.aspx.vb'
$webhook = Read-Source 'paypalwebhook.aspx.vb'
$safety = Read-Source 'App_Code\PayPalCheckoutSafetyPolicy.vb'
$verifyMigration = Read-Source 'Database Taikun\Migrations\20260922_PAYPAL_CHECKOUT_ORDERS_V2_LIVE_1A_verify.sql'
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
$results += Assert-Check ($repository.Contains('String.Equals(storedState, "COMPLETED"') -and $repository.Contains('normalized <> "COMPLETED"')) '38 monotonic completed state'
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
$results += Assert-Check ($repository.Contains('a.ClientId,a.ClientSecret,a.WebhookId') -and
    $repository.Contains('.ClientId = Convert.ToString(dr("ClientId"))') -and
    $repository.Contains('.ClientSecret = Convert.ToString(dr("ClientSecret"))') -and
    $repository.Contains('.WebhookId = Convert.ToString(dr("WebhookId"))')) '53a account credentials loaded from database'
$results += Assert-Check (-not (($config + $repository) -match 'HydrateServerCredentials|ReadServerSetting|Environment\.GetEnvironmentVariable|ConfigurationManager\.AppSettings') -and
    $config.Contains('Not String.IsNullOrWhiteSpace(ClientId)') -and
    $config.Contains('Not String.IsNullOrWhiteSpace(ClientSecret)')) '53b no PayPal environment fallback'
$results += Assert-Check ($client.Contains('PAYMENT.CAPTURE.COMPLETED') -eq $false -and $webhook.Contains('PAYMENT.CAPTURE.COMPLETED')) '54 webhook event scope'
$results += Assert-Check ($client.Contains('request.Headers("Prefer") = data.Prefer') -and $client.Contains('"return=representation"')) '55 Prefer representation transport'
$results += Assert-Check ($client.Contains('BuildWebhookVerificationPayload') -and $client.Contains('serialized.Replace(encodedSentinel, rawWebhookEvent)')) '56 raw webhook verification contract'
$results += Assert-Check ($webhook.Contains('Request.Headers("PAYPAL-TRANSMISSION-SIG"), raw)') -and -not $webhook.Contains('Request.Headers("PAYPAL-TRANSMISSION-SIG"), eventData)')) '57 raw event passed unchanged'
$results += Assert-Check ($returnPage.Contains('Not PayPalOrdersV2Client.IsReturnOrderTokenValid(rawOrderId, tx.PayPalOrderId) Then') -and $returnPage.IndexOf('IsReturnOrderTokenValid(rawOrderId, tx.PayPalOrderId)', [StringComparison]::Ordinal) -lt $returnPage.IndexOf('client.GetOrder', [StringComparison]::Ordinal)) '58 mandatory return token before API'
$results += Assert-Check ($webhook.Contains('CHECKOUT.ORDER.APPROVED') -and $webhook.Contains('ProcessApprovedOrder')) '59 approved webhook recovery'
$results += Assert-Check ($webhook.Contains('CaptureOrder(tx.PayPalOrderId, tx.CaptureRequestId)')) '60 approved uses persisted capture request id'
$results += Assert-Check ($webhook.Contains('CHECKOUT.PAYMENT-APPROVAL.REVERSED') -and $webhook.Contains('.Status = "FAILED"')) '61 approval reversed fails closed'
$verifyIndex = $webhook.IndexOf('If verification Is Nothing OrElse Not verification.Success', [StringComparison]::Ordinal)
$firstDmlIndex = $webhook.IndexOf('ApplyAuthoritativeState', [StringComparison]::Ordinal)
$results += Assert-Check ($verifyIndex -ge 0 -and $firstDmlIndex -gt $verifyIndex) '62 zero webhook DML before signature success'
$results += Assert-Check ($verifyMigration.Contains('COUNT(DISTINCT INDEX_NAME)=6') -and $verifyMigration.Contains('UX_paypal_checkout_tx_current') -and $verifyMigration.Contains('UX_paypal_checkout_tx_capture_request')) '63 all six transaction uniques verified'
$results += Assert-Check ($webhook.Contains('LoadDocumentForPayment') -and $webhook.Contains('ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId')) '64 approved full authoritative validation'
$ingressIndex = $webhook.IndexOf('CanUseLiveWebhook(HttpContext.Current)', [StringComparison]::Ordinal)
$transportIndex = $webhook.IndexOf('VerifyWebhookSignature(', [StringComparison]::Ordinal)
$results += Assert-Check ($ingressIndex -ge 0 -and $transportIndex -gt $ingressIndex -and $firstDmlIndex -gt $ingressIndex) '65 live ingress rejected before PayPal transport and DML'
$results += Assert-Check ($safety.Contains('If Not HasSafeLiveIngress(context) Then Return False') -and $safety.Contains('CanUseLiveWebhookIngress') -and -not $safety.Contains('ingressTenant.CompanyId = cfg.AziendeId')) '66 shared webhook ingress does not require order-tenant host'

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
    $dynamicTotalLine = $dynamic | Where-Object { $_ -match '^PAYPAL_ORDERS_V2_TOTAL=(\d+)$' } | Select-Object -Last 1
    if (-not $dynamicTotalLine) { throw 'PAYPAL_ORDERS_V2_TOTAL_MISSING' }
    $dynamicTotal = [int]($dynamicTotalLine -replace '^PAYPAL_ORDERS_V2_TOTAL=', '')
} finally { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
$results | Format-Table -AutoSize
"PAYPAL_ORDERS_V2_STATIC_TOTAL=$($results.Count)"
"PAYPAL_ORDERS_V2_TOTAL=$($results.Count + $dynamicTotal)"
