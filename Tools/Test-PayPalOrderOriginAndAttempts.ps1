[CmdletBinding()]
param([string]$RepositoryRoot)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
function Source([string]$Path) { Get-Content -LiteralPath (Join-Path $RepositoryRoot $Path) -Raw }
function Assert([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "PAYPAL_REV2_FAILED: $Name" }
    "PASS $Name"
}
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\vbc.exe' }
$out = Join-Path ([IO.Path]::GetTempPath()) ('paypal-rev2-policy-' + [Guid]::NewGuid().ToString('N') + '.exe')
try {
    & $compiler /nologo /target:exe /out:$out /r:System.dll `
        (Join-Path $RepositoryRoot 'Tools\PayPalOrderPolicyHarness.vb') `
        (Join-Path $RepositoryRoot 'App_Code\InternalOrderRemotePaymentPolicy.vb') `
        (Join-Path $RepositoryRoot 'App_Code\PayPalAttemptPolicy.vb')
    if ($LASTEXITCODE -ne 0) { throw 'PAYPAL_REV2_HARNESS_COMPILE_FAILED' }
    & $out
    if ($LASTEXITCODE -ne 0) { throw 'PAYPAL_REV2_HARNESS_FAILED' }
} finally {
    Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
}
$forward = Source 'Database Taikun\Migrations\20260922_PAYPAL_CHECKOUT_ORDERS_V2_LIVE_1A_forward.sql'
$verify = Source 'Database Taikun\Migrations\20260922_PAYPAL_CHECKOUT_ORDERS_V2_LIVE_1A_verify.sql'
$repo = Source 'App_Code\PayPalCheckoutRepository.vb'
$checkout = Source 'paypalcheckout.aspx.vb'
$return = Source 'paypalreturn.aspx.vb'
$webhook = Source 'paypalwebhook.aspx.vb'
$order = Source 'ordine.aspx.vb'
$detail = Source 'documentidettaglio.aspx.vb'
$list = Source 'documenti.aspx.vb'
$sella = Source 'bancasella.aspx.vb'
$static = @()
$static += Assert ($forward.Contains('`TentativoNo` int NOT NULL') -and $forward.Contains('`CurrentSlot` tinyint(1) DEFAULT NULL')) 'attempt columns'
$static += Assert ($forward.Contains('UX_paypal_checkout_tx_attempt') -and $forward.Contains('UX_paypal_checkout_tx_current') -and -not $forward.Contains('UX_paypal_checkout_tx_document`')) 'one current slot'
$static += Assert ($forward.Contains('OrigineOrdine') -and $order.Contains("OrigineOrdine='WEB'")) 'origin written with order'
$static += Assert ($order.Contains('cmdOrigin') -and $order.Contains('conn, trns') -and $order.Contains('OrderDurableIdempotencyService.Complete')) 'origin and idempotency same transaction'
$static += Assert ($checkout.Contains('PayPalWebLaunchContext.BeginPayPal') -and $checkout.Contains('PayPalWebLaunchContext.BindPayPalAttempt') -and $order.Contains('PayPalWebLaunchContext.Issue')) 'trusted web launch and bounded technical retry'
$static += Assert ($checkout.Contains('InternalOrderRemotePaymentPolicy.CanPayNow') -and $detail.Contains('InternalOrderRemotePaymentPolicy.CanPayNow') -and $sella.Contains('InternalOrderRemotePaymentPolicy.CanPayNow')) 'shared internal policy'
$static += Assert ($list.Contains('Return "none"') -and $list.Contains('InternalOrderRemotePaymentPolicy.CanPayNow')) 'list no unknown fallback'
$static += Assert ($repo.Contains('FOR UPDATE') -and $repo.Contains('CurrentSlot=NULL,Stato=''SUPERSEDED''')) 'locked supersede'
$static += Assert ($repo.Contains('"-" & attemptNo.ToString') -and $repo.Contains('BuildRequestId("CAPTURE"')) 'request ids per attempt'
$static += Assert ($return.Contains('LoadTransactionForOrder(rawOrderId)') -and $return.Contains('If Not tx.IsCurrent Then RedirectResult')) 'old return no capture'
$static += Assert ($webhook.Contains('If Not tx.IsCurrent') -and $webhook.Contains('TryBeginCapture(tx)')) 'old approved webhook no capture'
$static += Assert ($repo.Contains('Not currentSlot AndAlso normalized <> "COMPLETED"') -and $repo.Contains('COALESCE(Pagato,0)=0')) 'historical completion only'
$static += Assert (-not $forward.Contains('CREATE TABLE `paypal_checkout_legacy_audit`') -and -not $forward.Contains('INSERT INTO `paypal_checkout_legacy_audit`')) 'zero legacy audit migration'
$static += Assert ($verify.Contains('COUNT(*)=4') -and $verify.Contains('COUNT(DISTINCT INDEX_NAME)=6')) 'verify final schema'
$static += Assert ($sella.Contains('PayPalWebLaunchContext.Consume') -and $sella.Contains('requestedAmount')) 'Sella initial web gate'
$static += Assert (-not ($checkout + $return + $webhook + $repo -match 'SetExpressCheckout|DoExpressCheckoutPayment|EC-TOKEN')) 'zero Express runtime'
"PAYPAL_REV2_STATIC_TOTAL=$($static.Count)"
