# PAYPAL-AUTHORIZE-CLIENT-1A: mutanti del client (una sostituzione ancorata ciascuno). Occurrence = n-esima occorrenza (1 se omessa). Solo ASCII.
@{ Mutants = @(
    @{ Name = 'M01_INTENT_STAYS_CAPTURE'; Find = '{"intent", "AUTHORIZE"}'; Replace = '{"intent", "CAPTURE"}' }
    @{ Name = 'M02_FINAL_CAPTURE_FALSE'; Find = 'body("final_capture") = True'; Replace = 'body("final_capture") = False' }
    @{ Name = 'M03_FINAL_CAPTURE_OMITTED'; Find = 'body("final_capture") = True'; Replace = 'Dim omittedFinal As Boolean = True' }
    @{ Name = 'M04_CAPTURE_BODY_WITHOUT_AMOUNT'; Find = '{"amount", New Dictionary(Of String, Object) From {{"currency_code", currency}'; Replace = '{"amount_x", New Dictionary(Of String, Object) From {{"currency_code", currency}' }
    @{ Name = 'M05_AUTHORIZE_WITHOUT_PREFER'; Find = 'requestId, "{}", 201, False, True, True)'; Replace = 'requestId, "{}", 201, False, False, True)' }
    @{ Name = 'M06_VOID_USES_GET'; Find = 'SendPayment("POST", "/v2/payments/authorizations/" & Uri.EscapeDataString(authorizationId) & "/void"'; Replace = 'SendPayment("GET", "/v2/payments/authorizations/" & Uri.EscapeDataString(authorizationId) & "/void"' }
    @{ Name = 'M07_VOID_WRONG_PATH'; Find = '& "/void", requestId'; Replace = '& "/voidx", requestId' }
    @{ Name = 'M08_PENDING_IS_CAPTURABLE'; Find = 'Not String.Equals(auth.Status, "CREATED", StringComparison.Ordinal) Then Return False'; Replace = 'Not (String.Equals(auth.Status, "CREATED", StringComparison.Ordinal) OrElse auth.Status = "PENDING") Then Return False' }
    @{ Name = 'M09_202_207_ARE_SUCCESS'; Find = '(expectedStatus = 201 AndAlso response.StatusCode = 200)'; Replace = '(expectedStatus = 201 AndAlso (response.StatusCode = 200 OrElse response.StatusCode = 202 OrElse response.StatusCode = 207))' }
    @{ Name = 'M10_ORDER_ID_NOT_COMPARED'; Find = 'If Not String.Equals(result.Snapshot.OrderId, orderId, StringComparison.Ordinal) Then'; Replace = 'If False Then' }
    @{ Name = 'M11_AUTHORIZATION_ID_NOT_COMPARED'; Find = '(Not String.IsNullOrEmpty(expectedAuthorizationId) AndAlso Not String.Equals(auth.Id, expectedAuthorizationId, StringComparison.Ordinal))'; Replace = 'False' }
    @{ Name = 'M12_REFERENCE_ID_NOT_CHECKED'; Find = 'If FieldDiffers(snapshot.ReferenceId, ExpectedAttemptReferenceId(attempt), False, False) Then Return "REFERENCE_ID"'; Replace = '''reference id not checked' }
    @{ Name = 'M13_AUTHORIZATION_CURRENCY_NOT_CHECKED'; Find = 'If Not String.Equals(auth.Currency, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) Then Return "CURRENCY"'; Replace = '''currency not checked' }
    @{ Name = 'M14_INVALID_CAPTURE_AMOUNT_TOLERATED'; Find = 'If Not capture.AmountValid OrElse capture.Amount <> Math.Round(expectedAmount, 2, MidpointRounding.AwayFromZero) Then Return "AMOUNT"'; Replace = 'If capture.AmountValid AndAlso capture.Amount <> Math.Round(expectedAmount, 2, MidpointRounding.AwayFromZero) Then Return "AMOUNT"' }
    @{ Name = 'M15_ORDER_CAPTURE_AMOUNT_NOT_CHECKED'; Find = 'If Not snapshot.CaptureAmountValid OrElse snapshot.CaptureAmount <> Math.Round(attempt.Amount, 2, MidpointRounding.AwayFromZero) Then Return "CAPTURE_AMOUNT"'; Replace = '''capture amount not checked' }
    @{ Name = 'M16_CAPTURE_WITHOUT_ID_ACCEPTED'; Find = 'If result.Capture Is Nothing OrElse Not IsExternalIdValid(result.Capture.Id) OrElse String.IsNullOrEmpty(result.Capture.Status) Then'; Replace = 'If result.Capture Is Nothing Then' }
    @{ Name = 'M17_VOID_200_ANY_STATUS'; Find = 'String.Equals(result.Authorization.Status, "VOIDED", StringComparison.Ordinal) Then'; Replace = 'True Then' }
    @{ Name = 'M18_CONFLICT_ISSUES_DEFINITIVE'; Find = 'Case "PREVIOUSLY_CAPTURED", '; Replace = 'Case "NEVER_MATCHING_X", ' }
    @{ Name = 'M19_NOTSENT_IGNORED_ORDERS'; Find = 'If result.NotSent Then Return False'; Replace = '''notsent ignored' }
    @{ Name = 'M20_NOTSENT_IGNORED_PAYMENTS'; Find = 'If result.NotSent Then Return False'; Replace = '''notsent ignored'; Occurrence = 2 }
    @{ Name = 'M21_EXPIRY_IGNORED'; Find = 'Return TryParseUtc(auth.ExpirationTime, expiration) AndAlso expiration > nowUtc'; Replace = 'Return True' }
    @{ Name = 'M22_PENDING_COUNTS_AS_PAID'; Find = 'Return capture IsNot Nothing AndAlso String.Equals(capture.Status, "COMPLETED", StringComparison.Ordinal)'; Replace = 'Return capture IsNot Nothing AndAlso (capture.Status = "COMPLETED" OrElse capture.Status = "PENDING")' }
    @{ Name = 'M23_VOID_ID_NOT_VALIDATED'; Find = 'If Not IsExternalIdValid(authorizationId) Then Return PaymentsFailure("AUTHORIZATION_ID_INVALID")'; Replace = '''id not validated'; Occurrence = 3 }
    @{ Name = 'M24_CAPTURE_ID_NOT_VALIDATED'; Find = 'If Not IsExternalIdValid(authorizationId) Then Return PaymentsFailure("AUTHORIZATION_ID_INVALID")'; Replace = '''id not validated'; Occurrence = 2 }
    @{ Name = 'M25_NO_CONTENT_LENGTH_ZERO'; Find = 'request.ContentLength = 0'; Replace = '''no content length' }
    @{ Name = 'M26_ORDER_AMOUNT_VALUE_NOT_COMPARED'; Find = 'If Not snapshot.OrderAmountValid OrElse snapshot.Amount <> Math.Round(attempt.Amount, 2, MidpointRounding.AwayFromZero) Then Return "AMOUNT"'; Replace = 'If Not snapshot.OrderAmountValid Then Return "AMOUNT"' }
    @{ Name = 'M27_APPROVED_ORDER_NOT_STRICT'; Find = 'CheckAuthorizeOrderCommon(attempt, cfg, expectedOrderId, snapshot, True)'; Replace = 'CheckAuthorizeOrderCommon(attempt, cfg, expectedOrderId, snapshot, False)' }
    @{ Name = 'M28_TENANT_NOT_CHECKED'; Find = 'If cfg.AziendeId <> attempt.AziendeId OrElse cfg.PagamentiTipoId <> attempt.PagamentiTipoId Then Return "TENANT"'; Replace = '''tenant not checked' }
    @{ Name = 'M29_FINAL_CAPTURE_FALSE_TOLERATED'; Find = 'If capture.FinalCapturePresent AndAlso Not capture.FinalCapture Then Return "FINAL_CAPTURE"'; Replace = '''final capture not checked' }
    @{ Name = 'M30_UP_LINK_NOT_COMPARED'; Find = 'Not String.Equals(capture.UpAuthorizationId, expectedAuthorizationId, StringComparison.Ordinal) Then Return "AUTHORIZATION_ID"'; Replace = 'False Then Return "AUTHORIZATION_ID"' }
    @{ Name = 'M31_OAUTH_STATUS_DROPPED'; Find = 'If Not token.Success Then Return Failure(token.ErrorCode, token.StatusCode)'; Replace = 'If Not token.Success Then Return Failure(token.ErrorCode)' }
    @{ Name = 'M32_ISSUE_DROPPED_FROM_ERROR'; Find = 'If safe Then value &= ":" & issue'; Replace = '''issue dropped' }
    @{ Name = 'M33_CAPTURE_INVOICE_NEVER_SENT'; Find = 'If invoice.Length > 0 Then body("invoice_id") = invoice'; Replace = '''invoice never sent' }
    @{ Name = 'M34_GARBAGE_EXPIRATION_TOLERATED'; Find = 'If Not String.IsNullOrEmpty(auth.ExpirationTime) AndAlso Not TryParseUtc(auth.ExpirationTime, expiration) Then Return "EXPIRATION"'; Replace = '''expiration not checked' }
    @{ Name = 'M35_UNIT_COUNT_NOT_CHECKED'; Find = 'If snapshot.PurchaseUnitCount > 1 OrElse (strict AndAlso snapshot.PurchaseUnitCount <> 1) Then Return "UNIT_COUNT"'; Replace = '''unit count not checked' }
    @{ Name = 'M36_ANY_AUTHORIZATION_STATUS_KNOWN'; Find = 'Case "CREATED", "CAPTURED", "DENIED", "PARTIALLY_CAPTURED", "VOIDED", "PENDING"'; Replace = 'Case "CREATED", "CAPTURED", "DENIED", "PARTIALLY_CAPTURED", "VOIDED", "PENDING", "WEIRD"' }
    @{ Name = 'M37_409_NOT_UNCERTAIN'; Find = 'OrElse statusCode = 409 OrElse statusCode >= 500'; Replace = 'OrElse statusCode >= 500' }
    @{ Name = 'M38_INCOMPLETE_SUCCESS_NOT_UNCERTAIN'; Find = 'Return statusCode = 200 OrElse statusCode = 201 OrElse statusCode = 204'; Replace = 'Return False' }
    @{ Name = 'M39_AUTHORIZATION_COUNT_NOT_CHECKED'; Find = 'If result.Snapshot.AuthorizationCount <> 1 OrElse authorization Is Nothing'; Replace = 'If authorization Is Nothing' }
    @{ Name = 'M40_APPROVAL_LINK_NOT_REQUIRED'; Find = 'If String.IsNullOrEmpty(snapshot.ApprovalUrl) Then Return "APPROVAL_URL"'; Replace = '''approval link not required' }
) }
