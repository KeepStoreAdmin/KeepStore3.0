[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

function Assert-Contract([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "CHECKOUT_TERMINAL_OUTCOME_FAILED: $Name" }
    [pscustomobject]@{ Test = $Name; Result = 'PASS' }
}

$dispatcher = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'App_Code\CheckoutTerminalOutcomeDispatcher.vb') -Raw
$cart = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'carrello.aspx.vb') -Raw
$cartMarkup = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'carrello.aspx') -Raw
$order = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'ordine.aspx.vb') -Raw
$orderMarkup = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'ordine.aspx') -Raw
$availability = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'App_Code\OrderInventoryAvailabilityService.vb') -Raw

$results = @()
$results += Assert-Contract (
    $dispatcher.Contains('Return "carrello.aspx?stockerror=1#ksCartStockError"') -and
    -not ([regex]::Match($dispatcher, 'Case CheckoutTerminalOutcome\.StockFailure(?<body>[\s\S]*?)Case CheckoutTerminalOutcome\.LoginRequired').Groups['body'].Value -match 'documenti\.aspx')
) 'stock failure never targets documenti.aspx'

$results += Assert-Contract (
    $dispatcher.Contains('If context.Items(OutcomeItemKey) IsNot Nothing Then Return False') -and
    $dispatcher.Contains('response.StatusCode = 303') -and
    $dispatcher.Contains('context.ApplicationInstance.CompleteRequest()')
) 'first terminal outcome wins with HTTP 303'

$finalPost = [regex]::Match($cart, 'If shouldSendOrder AndAlso Not _cartPriceRevalidationBlockedThisRequest Then(?<body>[\s\S]*?)End If').Groups['body'].Value
$results += Assert-Contract (
    $finalPost.IndexOf('TryDispatchCurrentCheckoutStockFailure()', [StringComparison]::Ordinal) -ge 0 -and
    $finalPost.IndexOf('TryDispatchCurrentCheckoutStockFailure()', [StringComparison]::Ordinal) -lt $finalPost.IndexOf('SendOrder()', [StringComparison]::Ordinal) -and
    $finalPost.Contains('Then Return')
) 'final POST stops before ordine.aspx when stock is insufficient'

$results += Assert-Contract (
    -not ($order -match 'SafeRedirect\("documenti\.aspx"\)') -and
    -not ($order -match 'Dispatch\([^\r\n]*documenti\.aspx')
) 'checkout errors have no documenti.aspx fallback'

$results += Assert-Contract (
    $cart.Contains('RedirectToOrdineWithQuery("C="') -and
    $order.Contains('GetExactCaseQueryString(ORDER_CONFIRMATION_TOKEN_QS_KEY, 1024)') -and
    $order.Contains('String.Equals(actualKey, key, StringComparison.Ordinal)') -and
    -not ($order -match 'GetQueryString\(ORDER_CONFIRMATION_TOKEN_QS_KEY')
) 'legacy C flag cannot be mistaken for lowercase confirmation token c'

$results += Assert-Contract (
    $cart.Contains('GetLoginIdSafe(0)') -and
    $availability.Contains('WHERE c.LoginId=?loginId') -and
    $availability.Contains('ORDER BY c.ArticoliId') -and
    $availability.Contains('CommercialCode') -and
    $availability.Contains('For Each line As OrderInventoryReservationLine In _lines')
) 'owner-scoped stock check returns every commercial code'

$results += Assert-Contract (
    $cart.Contains('String.Equals(Request.QueryString("stockerror"), "1"') -and
    $cart.Contains('TryReevaluateCurrentOrderInventoryFailure(message, refreshedLineKeys, technicalFailure)') -and
    $cart.Contains('ks-order-inventory-alert__code') -and
    $cart.Contains('HttpUtility.HtmlEncode(line.CommercialCode)') -and
    $cart.Contains('Aggiorna carrello') -and
    $cart.Contains('ks-cart-inventory-error') -and
    $cartMarkup.Contains('id="ksCartStockError"') -and
    $cartMarkup.Contains('aria-live="assertive"')
) 'stock page re-evaluates, explains and highlights current cart lines'

$inspectIndex = $order.IndexOf('OrderInventoryAvailabilityService.InspectCurrentCart(conn, trns', [StringComparison]::Ordinal)
$procedureIndex = $order.IndexOf('cmd.ExecuteNonQuery()', $inspectIndex, [StringComparison]::Ordinal)
$completeIndex = $order.IndexOf('OrderDurableIdempotencyService.Complete(', $procedureIndex, [StringComparison]::Ordinal)
$emailIndex = $order.IndexOf('SendEmail(', $completeIndex, [StringComparison]::Ordinal)
$results += Assert-Contract (
    $inspectIndex -ge 0 -and
    $procedureIndex -gt $inspectIndex -and
    $completeIndex -gt $procedureIndex -and
    $emailIndex -gt $completeIndex
) 'inventory failure precedes document, idempotency completion and email'

$results += Assert-Contract (
    $order.Contains('RedirectToOrderConfirmation(checkoutRequestId, LoginId)') -and
    $dispatcher.Contains('Case CheckoutTerminalOutcome.OrderConfirmation') -and
    $dispatcher.Contains('Return "ordine.aspx?c="')
) 'valid PRG confirmation remains available'

$completedReplay = [regex]::Match($order, 'If completedBeforeWork IsNot Nothing Then(?<body>[\s\S]*?)If TipoDoc <= 0 Then').Groups['body'].Value
$results += Assert-Contract (
    $completedReplay.Contains('OrderDurableClaimStatus.CompletedReplay') -and
    $completedReplay.Contains('PayloadFingerprint') -and
    $completedReplay.Contains('RedirectToOrderConfirmation(checkoutRequestId, LoginId)')
) 'completed replay returns the same protected confirmation path'

$spinnerFunction = [regex]::Match($cartMarkup, 'window\.ksValidateCheckoutTermsConsent\s*=\s*function\s*\(\)\s*\{(?<body>[\s\S]*?)\n\s*\};').Groups['body'].Value
$results += Assert-Contract (
    $dispatcher.Contains('Case CheckoutTerminalOutcome.LoginRequired') -and
    $dispatcher.Contains('Return "accessonegato.aspx"') -and
    -not ($spinnerFunction -match 'documenti\.aspx|window\.location|location\.href|location\.replace') -and
    -not ($orderMarkup -match 'documenti\.aspx\?t=4')
) 'login stays distinct and spinner cannot choose a checkout destination'

$results | Format-Table -AutoSize
