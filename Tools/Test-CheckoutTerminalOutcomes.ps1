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

function Read-Source([string]$RelativePath) {
    Get-Content -LiteralPath (Join-Path $RepositoryRoot $RelativePath) -Raw
}

$dispatcher = Read-Source 'App_Code\CheckoutTerminalOutcomeDispatcher.vb'
$recovery = Read-Source 'App_Code\CheckoutFailureRecoveryService.vb'
$cart = Read-Source 'carrello.aspx.vb'
$cartMarkup = Read-Source 'carrello.aspx'
$order = Read-Source 'ordine.aspx.vb'
$availability = Read-Source 'App_Code\OrderInventoryAvailabilityService.vb'
$idempotency = Read-Source 'App_Code\OrderDurableIdempotencyService.vb'
$checkoutUi = Read-Source 'Public\assets\keepstore\js\checkout-ui.js'
$readModel = Read-Source 'App_Code\CartAuthoritativeReadModel.vb'
$snapshot = Read-Source 'App_Code\CartStateSnapshotProvider.vb'
$master = Read-Source 'Page.master.vb'
$miniCart = Read-Source 'Public\ui\controls\MiniCart.ascx.vb'
$submitHandler = [regex]::Match(
    $cart,
    'Protected Sub btInviaOrdine_Click\([^\r\n]*\)(?<body>[\s\S]*?)\r?\n\s*End Sub').Groups['body'].Value

$results = @()

# 1. Il controllo finale deve generare davvero l'evento server previsto.
$results += Assert-Contract (
    $cartMarkup.Contains('ID="btInviaOrdine"') -and
    $cartMarkup.Contains('OnClientClick="return ksValidateCheckoutTermsConsent();"') -and
    $cart.Contains('Protected Sub btInviaOrdine_Click') -and
    $cart.Contains('Handles btInviaOrdine.Click')
) '01 handler invocato dal submit finale'

# 2. Un validator invalido viene classificato e trasferito via PRG a feedback accessibile.
$results += Assert-Contract (
    $cart.Contains('Private Function TryGetCheckoutValidationFailure') -and
    $cart.Contains('Page.Validate(CHECKOUT_SUBMIT_VALIDATION_GROUP)') -and
    $cart.Contains('groupedValidator.IsValid Then Continue For') -and
    $cart.Contains('Protected Sub cvCheckoutSubmit_ServerValidate') -and
    $submitHandler.Contains('If TryGetCheckoutValidationFailure(validationReason) Then') -and
    $submitHandler.Contains('DispatchCheckoutFailure(validationReason, "04-checkout-validation")') -and
    $cartMarkup.Contains('CausesValidation="true" ValidationGroup="checkoutSubmit" ID="btInviaOrdine"') -and
    ([regex]::Matches($cartMarkup, '<asp:CustomValidator[^>]+ValidationGroup="checkoutSubmit"').Count -eq 4) -and
    $cartMarkup.Contains('ID="vsCheckoutSubmit"') -and
    $cart.Contains('CheckoutFailureRecoveryService.TryConsumeFailure') -and
    $cartMarkup.Contains('ID="pnlCheckoutSubmitError"') -and
    $cartMarkup.Contains('role="alert"') -and
    $cartMarkup.Contains('tabindex="-1"')
) '02 Page.IsValid false mostra errore accessibile'

# 3. Il consenso e' verificato sia prima del postback sia sul server e torna alla conferma.
$results += Assert-Contract (
    $cartMarkup.Contains('window.ksValidateCheckoutTermsConsent = function ()') -and
    $cartMarkup.Contains("if (checkbox && !checkbox.checked)") -and
    $cart.Contains('If Not TermsConsentAccepted() Then') -and
    $cart.Contains('CheckoutFailureReason.TermsNotAccepted') -and
    $recovery.Contains('Accetta le Condizioni Generali di Vendita prima di confermare l''ordine.') -and
    $cart.Contains('Case Else') -and
    $cart.Contains('SetCheckoutStep("confirm")')
) '03 termini mancanti restano sulla conferma con messaggio'

# 4. La spedizione viene rivalidata anche al POST finale.
$shippingValidation = [regex]::Match(
    $cart,
    'Private Function ValidateCheckoutBeforeConfirm\(\) As Boolean(?<body>[\s\S]*?)End Function').Groups['body'].Value
$results += Assert-Contract (
    $cart.Contains('If Not ValidateCheckoutBeforeConfirm() Then') -and
    $shippingValidation.Contains('tbVettoriId') -and
    $shippingValidation.Contains('Seleziona un metodo di spedizione prima di rivedere l''ordine.') -and
    $cart.Contains('CheckoutFailureReason.ShippingMethodMissing') -and
    $order.Contains('If Vettore <= 0 Then')
) '04 spedizione mancante mostra istruzione visibile'

# 5. Il pagamento viene rivalidato anche al POST finale.
$results += Assert-Contract (
    $cart.Contains('If Not ValidateCheckoutBeforeConfirm() Then') -and
    $shippingValidation.Contains('tbPagamenti') -and
    $shippingValidation.Contains('Seleziona un metodo di pagamento prima di rivedere l''ordine.') -and
    $cart.Contains('CheckoutFailureReason.PaymentMethodMissing') -and
    $order.Contains('If Pagamento <= 0 Then')
) '05 pagamento mancante mostra istruzione visibile'

# 6. TipoDocumento assente non puo' diventare un ritorno muto al carrello.
$missingDocumentType = [regex]::Match(
    $order,
    'If TipoDoc <= 0 Then(?<body>[\s\S]*?)End If').Groups['body'].Value
$results += Assert-Contract (
    $missingDocumentType.Contains('RouteCurrentInventoryFailureToCart') -and
    $missingDocumentType.Contains('ReturnToCartWithReviewMessage') -and
    $missingDocumentType.Contains('I dati necessari per confermare l''ordine sono incompleti.')
) '06 TipoDocumento mancante termina con messaggio'

# 7. Un carrello vuoto e' respinto prima del token e anche nel secondo gate transazionale.
$results += Assert-Contract (
    $cart.Contains('checkoutCart.GetAllItems().Rows.Count = 0') -and
    $cart.Contains('Il carrello è vuoto. Aggiungi almeno un articolo prima di inviare l''ordine.') -and
    $order.Contains('If Not drCart.HasRows Then') -and
    $order.Contains('ReturnToCartWithReviewMessage("Il carrello è vuoto.')
) '07 carrello vuoto non crea ordine e mostra errore'

# 8. Lo stock viene controllato prima di token, claim, documento ed e-mail.
$finalPost = [regex]::Match(
    $cart,
    'If shouldSendOrder AndAlso Not _cartPriceRevalidationBlockedThisRequest Then(?<body>[\s\S]*?)End If').Groups['body'].Value
$inspectIndex = $order.IndexOf('OrderInventoryAvailabilityService.InspectCurrentCart(conn, trns', [StringComparison]::Ordinal)
$procedureIndex = $order.IndexOf('cmd.ExecuteNonQuery()', $inspectIndex, [StringComparison]::Ordinal)
$results += Assert-Contract (
    $dispatcher.Contains('Return "carrello.aspx?stockerror=1#ksCartStockError"') -and
    $finalPost.IndexOf('TryDispatchCurrentCheckoutStockFailure()', [StringComparison]::Ordinal) -ge 0 -and
    $finalPost.IndexOf('TryDispatchCurrentCheckoutStockFailure()', [StringComparison]::Ordinal) -lt
        $finalPost.IndexOf('SendOrder()', [StringComparison]::Ordinal) -and
    $inspectIndex -ge 0 -and $procedureIndex -gt $inspectIndex -and
    $availability.Contains('CommercialCode')
) '08 stock insufficiente torna al carrello senza documento'

# 9. Una variazione commerciale e' persistita come feedback e instradata esplicitamente.
$results += Assert-Contract (
    $dispatcher.Contains('Return "carrello.aspx?pricechanged=1"') -and
    $order.Contains('CartPriceRevalidationHelper.StoreResultInSession') -and
    $order.Contains('CheckoutTerminalOutcome.PriceChanged') -and
    $order.Contains('OrderDurableIdempotencyService.MarkRetryRequired')
) '09 prezzo cambiato richiede revisione senza duplicare'

# 10. La sessione scaduta conserva il carrello e usa una destinazione distinta.
$results += Assert-Contract (
    $submitHandler.Contains('If GetLoginIdSafe(0) <= 0 Then') -and
    $cart.Contains('/carrello.aspx?loginrequired=1#ksCartLoginRequired') -and
    $submitHandler.IndexOf('If GetLoginIdSafe(0) <= 0 Then', [StringComparison]::Ordinal) -lt
        $submitHandler.IndexOf('If Not ValidateCheckoutSubmitCsrfToken() Then', [StringComparison]::Ordinal) -and
    $dispatcher.Contains('Case CheckoutTerminalOutcome.LoginRequired') -and
    $dispatcher.Contains('Return "carrello.aspx?loginrequired=1#ksCartLoginRequired"')
) '10 login scaduto termina su loginrequired'

# 11. Il token CSRF del submit e' owner/request-bound e il rifiuto e' HTTP 403.
$results += Assert-Contract (
    $cart.Contains('MachineKey.Protect(clearBytes, CHECKOUT_SUBMIT_CSRF_PURPOSE)') -and
    $cart.Contains('MachineKey.Unprotect(protectedBytes, CHECKOUT_SUBMIT_CSRF_PURPOSE)') -and
    $cart.Contains('If Not ValidateCheckoutSubmitCsrfToken() Then') -and
    $cart.Contains('Response.StatusCode = 403') -and
    $cart.Contains('Response.StatusDescription = "Forbidden"')
) '11 CSRF invalido termina con HTTP 403'

# 12. RequestId alterata non supera normalizzazione, MachineKey e confronto owner-bound.
$results += Assert-Contract (
    $cart.Contains('TryNormalizeRequestId(requestId, normalizedRequestId)') -and
    $cart.Contains('ViewState(CHECKOUT_REQUEST_VIEWSTATE_KEY)') -and
    $order.Contains('MachineKey.Unprotect(protectedBytes, CHECKOUT_TOKEN_PURPOSE)') -and
    $order.Contains('TryNormalizeRequestId(parts(requestIndex), normalized)') -and
    $order.Contains('If Not TryValidateCheckoutToken(orderIdentity, checkoutRequestId')
) '12 RequestId alterata fallisce chiusa'

# 13. Un payload diverso viene annullato prima del claim e torna con messaggio.
$results += Assert-Contract (
    $order.Contains('Not String.Equals(payloadFingerprint, checkoutPayloadFingerprint') -and
    $order.Contains('Dim mismatchRetryPersisted As Boolean = False') -and
    $order.Contains('ReturnToCartAfterPayloadMismatch(checkoutRequestId)') -and
    $order.Contains('Il carrello è cambiato rispetto alla richiesta precedente.')
) '13 payload differente esegue rollback con messaggio'

# 14. Doppio click: guardia browser e unica chiave durevole protetta dal ViewState.
$results += Assert-Contract (
    $checkoutUi.Contains('function preventDoubleSubmit()') -and
    $checkoutUi.Contains('if (locked)') -and
    $checkoutUi.Contains('e.preventDefault()') -and
    $cart.Contains('EnsureCheckoutRequestId()') -and
    $order.Contains('OrderDurableIdempotencyService.TryClaim(')
) '14 doppio click usa una sola richiesta durevole'

# 15. Il replay completato riconsegna lo stesso documento tramite token protetto.
$completedReplay = [regex]::Match(
    $order,
    'If completedBeforeWork IsNot Nothing Then(?<body>[\s\S]*?)If TipoDoc <= 0 Then').Groups['body'].Value
$results += Assert-Contract (
    $completedReplay.Contains('OrderDurableClaimStatus.CompletedReplay') -and
    $completedReplay.Contains('PayloadFingerprint') -and
    $completedReplay.Contains('RedirectToOrderConfirmation(checkoutRequestId, orderIdentity)') -and
    $dispatcher.Contains('Return "ordine.aspx?c="')
) '15 replay restituisce lo stesso documento'

# 16. Timeout/deadlock o commit ambiguo terminano con reconcile oppure stato neutro e tombstone.
$transactionMarkerIndex = $order.IndexOf('commitAttempted = True', [StringComparison]::Ordinal)
$orderCatchStart = $order.IndexOf('Catch ex As Exception', $transactionMarkerIndex, [StringComparison]::Ordinal)
$orderCatchEnd = $order.IndexOf('Finally', $orderCatchStart, [StringComparison]::Ordinal)
$orderCatch = ''
if ($orderCatchStart -ge 0 -and $orderCatchEnd -gt $orderCatchStart) {
    $orderCatch = $order.Substring($orderCatchStart, $orderCatchEnd - $orderCatchStart)
}
$results += Assert-Contract (
    $orderCatch.Contains('If trns IsNot Nothing Then') -and
    $orderCatch.Contains('trns.Rollback()') -and
    $orderCatch.Contains('TryReconcileCompletedOrder') -and
    $orderCatch.Contains('ShowIndeterminateOrderOutcome()') -and
    $orderCatch.Contains('CheckoutFailureRecoveryService.RetireRequest') -and
    $orderCatch.Contains('OrderDurableIdempotencyService.RecordRetryRequired') -and
    $idempotency.Contains('RetryRequiredState')
) '16 deadlock timeout e commit ambiguo hanno esito terminale'

# 17. Le eccezioni annidate vengono attraversate prima di classificare lo stock.
$results += Assert-Contract (
    $order.Contains('Private Function FindInventoryAvailabilityException') -and
    $order.Contains('Private Function IsCanonicalInventoryFailure') -and
    ([regex]::Matches($order, 'current = current\.InnerException').Count -ge 2) -and
    $order.Contains('Dim availabilityError As OrderInventoryAvailabilityException = FindInventoryAvailabilityException(ex)')
) '17 eccezione annidata viene classificata correttamente'

# 18. L'e-mail parte dopo COMMIT e il suo errore non riapre la transazione.
$completeIndex = $order.IndexOf('OrderDurableIdempotencyService.Complete(', $procedureIndex, [StringComparison]::Ordinal)
$commitIndex = $order.IndexOf('trns.Commit()', $completeIndex, [StringComparison]::Ordinal)
$emailIndex = $order.IndexOf('SendEmail(', $commitIndex, [StringComparison]::Ordinal)
$sendEmailBody = [regex]::Match(
    $order,
    'Public Sub SendEmail\((?<body>[\s\S]*?)\n\s*End Sub').Groups['body'].Value
$results += Assert-Contract (
    $completeIndex -gt $procedureIndex -and
    $commitIndex -gt $completeIndex -and
    $emailIndex -gt $commitIndex -and
    $sendEmailBody.Contains('Catch ex As Exception') -and
    $sendEmailBody.Contains('KeepStoreLog.Error')
) '18 errore email post-COMMIT non duplica ordine'

# 19. Ogni fallback to cart o catch del submit produce una destinazione/messaggio osservabile.
$results += Assert-Contract (
    $cart.Contains('Private Sub ShowCheckoutSubmitError') -and
    $cart.Contains("document.getElementById('pnlCheckoutSubmitError')") -and
    $cart.Contains('LogCheckoutSubmitFailure(ex, "pre-dispatch")') -and
    $cart.Contains('LogCheckoutSubmitFailure(ex, "order-token")') -and
    -not $cart.Contains('mantengo logica originale: nessun messaggio utente') -and
    $order.Contains('Private Sub LogDurableCheckoutFailure') -and
    $order.Contains('LogDurableCheckoutFailure(ex, "transaction")') -and
    $order.Contains('Checkout confirmation failed. phase=') -and
    $order.Contains('Private Sub ReturnToCartWithReviewMessage') -and
    $recovery.Contains('Public Shared Function RetireAndDispatch') -and
    $dispatcher.Contains('carrello.aspx?checkoutfailed=1#pnlCheckoutSubmitError') -and
    (Read-Source 'ordine.aspx').Contains('ID="Panel2" runat="server" ClientIDMode="Static" Visible="false" role="alert"') -and
    $dispatcher.Contains('response.StatusCode = 303') -and
    $dispatcher.Contains('context.ApplicationInstance.CompleteRequest()')
) '19 nessun ramo terminale resta silenzioso'

# 20. Pagina, MiniCart e header proiettano lo stesso read model request-scoped.
$results += Assert-Contract (
    $cartMarkup.Contains('TypeName="CartAuthoritativeReadDataSource" SelectMethod="SelectStandardItems"') -and
    $miniCart.Contains('CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)') -and
    $master.Contains('CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)') -and
    $snapshot.Contains('CartAuthoritativeReadModel.GetCurrent(context)') -and
    $readModel.Contains('Private Const RequestCacheKey As String = "KeepStore:CartAuthoritativeReadModel:Current"')
) '20 pagina MiniCart e header restano coerenti'

# 21. La destinazione ordine deve essere app-relative e accettata dalla policy locale.
$results += Assert-Contract (
    ([regex]::Matches($cart, 'VirtualPathUtility\.ToAbsolute\("~/ordine\.aspx"\)').Count -eq 2) -and
    -not $cart.Contains('Dim url As String = "ordine.aspx?t="') -and
    $cart.Contains('If String.IsNullOrWhiteSpace(url) OrElse Not UrlIsLocal(url) Then') -and
    $cart.Contains('"17-processing-redirect", "failure"')
) '21 redirect ordine app-relative supera la policy locale'

if ($results.Count -ne 21) {
    throw "CHECKOUT_TERMINAL_OUTCOME_FAILED: expected 21 checks, got $($results.Count)"
}

$results | Format-Table -AutoSize
