# PAYPAL-CAPTURE-REPRESENTATION-1A: mutanti del client (una sostituzione ancorata ciascuno). Occurrence = n-esima occorrenza (1 se omessa). Solo ASCII.
# Ogni mutante deve far cadere almeno un controllo dell'harness Tools\PayPalCaptureRepresentationHarness.vb; uno che non compila e INVALIDO.
# Mutanti equivalenti NON inclusi (provati): il controllo di cattura di CheckOrderAgainstAttempt (ripete HasMatchingCapture della forma stretta con lo stesso importo)
# e il conteggio unita di CheckCaptureResponse (ripetuto da CheckOrderUnitFieldsIfPresent per piu unita e da CAPTURE_COUNT per zero).
@{ Mutants = @(
    # --- chiamata CaptureOrder / CreateOrder ---
    @{ Name = 'M01_CAPTURE_ORDER_ID_NOT_COMPARED'; Find = 'If result.Success AndAlso Not String.Equals(orderId, result.Snapshot.OrderId, StringComparison.Ordinal) Then'; Replace = 'If False Then' }
    @{ Name = 'M02_CREATE_WITHOUT_PREFER'; Find = 'preferRepresentation:=True, includeIssue:=True)'; Replace = 'preferRepresentation:=False, includeIssue:=True)' }
    @{ Name = 'M03_CAPTURE_WITHOUT_PREFER'; Find = 'preferRepresentation:=True, includeIssue:=True)'; Replace = 'preferRepresentation:=False, includeIssue:=True)'; Occurrence = 2 }
    @{ Name = 'M04_CAPTURE_ISSUE_DROPPED'; Find = 'preferRepresentation:=True, includeIssue:=True)'; Replace = 'preferRepresentation:=True, includeIssue:=False)'; Occurrence = 2 }
    @{ Name = 'M05_INCOMPLETE_CAPTURE_ACCEPTED'; Find = 'If result.Success AndAlso (result.Snapshot.CaptureCount <> 1 OrElse'; Replace = 'If False AndAlso (result.Snapshot.CaptureCount <> 1 OrElse' }
    @{ Name = 'M06_CREATE_LINK_NOT_REQUIRED'; Find = 'ElseIf created.Success AndAlso String.IsNullOrEmpty(created.Snapshot.ApprovalUrl) Then'; Replace = 'ElseIf False Then' }
    @{ Name = 'M07_CREATE_ID_NOT_VALIDATED'; Find = 'If created.Success AndAlso Not IsExternalIdValid(created.Snapshot.OrderId) Then'; Replace = 'If False Then' }
    # --- CaptureOrderVerified ---
    @{ Name = 'M08_TENANT_PRECHECK_REMOVED'; Find = 'If _config.AziendeId <> doc.AziendeId OrElse _config.PagamentiTipoId <> doc.PagamentiTipoId Then Return Failure("TENANT_MISMATCH")'; Replace = '''tenant precheck removed' }
    @{ Name = 'M09_RESPONSE_CHECK_SKIPPED'; Find = 'If reason.Length > 0 Then Return WithheldOrder(captured, "CAPTURE_RESPONSE_" & reason)'; Replace = '''response check skipped' }
    @{ Name = 'M10_FAILED_GET_CONTINUES'; Find = 'If readback Is Nothing OrElse Not readback.Success Then'; Replace = 'If readback Is Nothing Then' }
    @{ Name = 'M11_READBACK_IS_LENIENT'; Find = 'reason = CheckOrderAgainstAttempt(doc, _config, orderId, readback.Snapshot, attemptAmount, attemptCurrency)'; Replace = 'reason = CheckCaptureResponse(doc, _config, orderId, readback.Snapshot, attemptAmount, attemptCurrency)' }
    @{ Name = 'M12_READBACK_CAPTURE_COUNT_NOT_REQUIRED'; Find = 'If reason.Length = 0 AndAlso readback.Snapshot.CaptureCount <> 1 Then reason = "CAPTURE_COUNT"'; Replace = '''capture count not required' }
    @{ Name = 'M13_READBACK_CAPTURE_ID_NOT_COMPARED'; Find = 'If reason.Length = 0 AndAlso Not String.Equals(captured.Snapshot.CaptureId, readback.Snapshot.CaptureId, StringComparison.Ordinal) Then reason = "CAPTURE_ID"'; Replace = '''capture id not compared' }
    @{ Name = 'M14_FAILURE_KEEPS_THE_POST_SNAPSHOT'; Find = '.NotSent = source IsNot Nothing AndAlso source.NotSent, .Snapshot = New PayPalOrderSnapshot()}'; Replace = '.NotSent = source IsNot Nothing AndAlso source.NotSent, .Snapshot = If(source Is Nothing, New PayPalOrderSnapshot(), source.Snapshot)}' }
    @{ Name = 'M15_FAILURE_MARKED_NOT_SENT'; Find = '.NotSent = source IsNot Nothing AndAlso source.NotSent,'; Replace = '.NotSent = True,' }
    @{ Name = 'M16_FAILURE_LOSES_THE_STATUS'; Find = '.StatusCode = If(source Is Nothing, 0, source.StatusCode),'; Replace = '.StatusCode = 0,' }
    @{ Name = 'M17_SUCCESS_RETURNS_THE_POST_SNAPSHOT'; Find = '.StatusCode = captured.StatusCode, .Snapshot = readback.Snapshot}'; Replace = '.StatusCode = captured.StatusCode, .Snapshot = captured.Snapshot}' }
    @{ Name = 'M18_CALL_FAILURE_PASSED_THROUGH'; Find = 'Then Return WithheldOrder(captured, If(captured Is Nothing, "CAPTURE_NO_RESULT", captured.ErrorCode))'; Replace = 'Then Return captured' }
    # --- validatore stretto (wrapper e motivo) ---
    @{ Name = 'M19_STRICT_PAYEE_NOT_COMPARED'; Find = 'If Not String.Equals(snapshot.PayeeEmail, cfg.PayeeEmail, StringComparison.OrdinalIgnoreCase) Then Return "PAYEE"'; Replace = '''payee not compared' }
    @{ Name = 'M20_STRICT_MERCHANT_NOT_COMPARED'; Find = 'If Not String.Equals(snapshot.MerchantId, cfg.MerchantId, StringComparison.Ordinal) Then Return "MERCHANT"'; Replace = '''merchant not compared' }
    @{ Name = 'M21_STRICT_PAYMENT_TYPE_NOT_COMPARED'; Find = 'If cfg.AziendeId <> doc.AziendeId OrElse cfg.PagamentiTipoId <> doc.PagamentiTipoId Then Return "TENANT"'; Replace = 'If cfg.AziendeId <> doc.AziendeId Then Return "TENANT"' }
    @{ Name = 'M22_STRICT_INTENT_NOT_REQUIRED'; Find = 'If Not String.Equals(snapshot.Intent, "CAPTURE", StringComparison.OrdinalIgnoreCase) Then Return "INTENT"'; Replace = '''intent not required' }
    @{ Name = 'M23_STRICT_AMOUNT_NOT_COMPARED'; Find = 'If snapshot.Amount <> Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero) Then Return "AMOUNT"'; Replace = '''amount not compared' }
    @{ Name = 'M24_STRICT_TWO_CAPTURES_ALLOWED'; Find = 'If snapshot.CaptureCount > 1 Then Return "CAPTURE_COUNT"'; Replace = '''two captures allowed' }
    @{ Name = 'M25_ATTEMPT_AMOUNT_NOT_COMPARED'; Find = 'If attemptAmount <> Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero) Then Return "ATTEMPT_AMOUNT"'; Replace = '''attempt amount not compared' }
    @{ Name = 'M26_ATTEMPT_CURRENCY_NOT_COMPARED'; Find = 'If Not String.Equals(attemptCurrency, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) Then Return "ATTEMPT_CURRENCY"'; Replace = '''attempt currency not compared' }
    @{ Name = 'M27_STRICT_WRAPPER_ACCEPTS_EVERYTHING'; Find = 'Return CheckOrderSnapshotStrict(doc, cfg, expectedOrderId, snapshot).Length = 0'; Replace = 'Return True' }
    @{ Name = 'M28_ATTEMPT_WRAPPER_ACCEPTS_EVERYTHING'; Find = 'Return CheckOrderAgainstAttempt(doc, cfg, expectedOrderId, snapshot, attemptAmount, attemptCurrency).Length = 0'; Replace = 'Return True' }
    # --- controllo lenient della risposta di capture ---
    @{ Name = 'M29_RESPONSE_CAPTURE_AMOUNT_NOT_COMPARED'; Find = 'OrElse snapshot.CaptureAmount <> Math.Round(attemptAmount, 2, MidpointRounding.AwayFromZero) Then Return "CAPTURE_AMOUNT"'; Replace = 'Then Return "CAPTURE_AMOUNT"' }
    @{ Name = 'M30_RESPONSE_CAPTURE_CURRENCY_NOT_COMPARED'; Find = 'If Not String.Equals(snapshot.CaptureCurrencyCode, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) Then Return "CAPTURE_CURRENCY"'; Replace = '''capture currency not compared' }
    @{ Name = 'M31_RESPONSE_CAPTURE_ID_NOT_VALIDATED'; Find = 'If Not IsExternalIdValid(snapshot.CaptureId) Then Return "CAPTURE_ID"'; Replace = '''capture id not validated' }
    @{ Name = 'M32_RESPONSE_CAPTURE_COUNT_NOT_CHECKED'; Find = 'If snapshot.CaptureCount <> 1 Then Return "CAPTURE_COUNT"'; Replace = '''capture count not checked' }
    @{ Name = 'M33_RESPONSE_ORDER_ID_NOT_COMPARED'; Find = 'If Not IsExternalIdValid(expectedOrderId) OrElse Not String.Equals(snapshot.OrderId, expectedOrderId, StringComparison.Ordinal) Then Return "ORDER_ID"'; Replace = '''order id not compared' }
    @{ Name = 'M34_RESPONSE_CAPTURE_INVOICE_NOT_COMPARED'; Find = 'If FieldDiffers(snapshot.CaptureInvoiceId, ExpectedInvoiceId(doc), False, False) Then Return "CAPTURE_INVOICE_ID"'; Replace = '''capture invoice not compared' }
    @{ Name = 'M35_RESPONSE_CAPTURE_CUSTOM_NOT_COMPARED'; Find = 'If FieldDiffers(snapshot.CaptureCustomId, ExpectedCustomId(doc), False, False) Then Return "CAPTURE_CUSTOM_ID"'; Replace = '''capture custom not compared' }
    @{ Name = 'M36_RESPONSE_STATUS_ANY'; Find = 'If Not IsCaptureStatusSupported(snapshot.CaptureStatus) Then Return "CAPTURE_STATUS"'; Replace = '''capture status not checked' }
    @{ Name = 'M37_RESPONSE_TENANT_NOT_CHECKED'; Find = 'If cfg.AziendeId <> doc.AziendeId OrElse cfg.PagamentiTipoId <> doc.PagamentiTipoId Then Return "TENANT"'; Replace = '''tenant not checked'; Occurrence = 2 }
    @{ Name = 'M38_RESPONSE_ATTEMPT_AMOUNT_NOT_COMPARED'; Find = 'If attemptAmount <> Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero) Then Return "ATTEMPT_AMOUNT"'; Replace = '''attempt amount not compared'; Occurrence = 2 }
    # --- campi di unita (presente e diverso => rifiuto) ---
    @{ Name = 'M39_UNIT_INTENT_NOT_COMPARED'; Find = 'If FieldDiffers(snapshot.Intent, "CAPTURE", False, True) Then Return "INTENT"'; Replace = '''intent not compared' }
    @{ Name = 'M40_UNIT_REFERENCE_NOT_COMPARED'; Find = 'If FieldDiffers(snapshot.ReferenceId, ExpectedReferenceId(doc), False, False) Then Return "REFERENCE_ID"'; Replace = '''reference not compared' }
    @{ Name = 'M41_UNIT_CUSTOM_NOT_COMPARED'; Find = 'If FieldDiffers(snapshot.CustomId, ExpectedCustomId(doc), False, False) Then Return "CUSTOM_ID"'; Replace = '''custom not compared' }
    @{ Name = 'M42_UNIT_INVOICE_NOT_COMPARED'; Find = 'If FieldDiffers(snapshot.InvoiceId, ExpectedInvoiceId(doc), False, False) Then Return "INVOICE_ID"'; Replace = '''invoice not compared' }
    @{ Name = 'M43_UNIT_AMOUNT_VALUE_NOT_COMPARED'; Find = 'If Not snapshot.OrderAmountValid OrElse snapshot.Amount <> Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero) Then Return "AMOUNT"'; Replace = 'If Not snapshot.OrderAmountValid Then Return "AMOUNT"' }
    @{ Name = 'M44_UNIT_CURRENCY_NOT_COMPARED'; Find = 'If Not String.Equals(snapshot.CurrencyCode, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) Then Return "CURRENCY"'; Replace = '''currency not compared'; Occurrence = 2 }
    @{ Name = 'M45_UNIT_PAYEE_NOT_COMPARED'; Find = 'If FieldDiffers(snapshot.PayeeEmail, cfg.PayeeEmail, False, True) Then Return "PAYEE"'; Replace = '''payee not compared' }
    @{ Name = 'M46_UNIT_MERCHANT_NOT_COMPARED'; Find = 'If FieldDiffers(snapshot.MerchantId, cfg.MerchantId, False, False) Then Return "MERCHANT"'; Replace = '''merchant not compared' }
    @{ Name = 'M47_UNIT_TWO_UNITS_ALLOWED'; Find = 'If snapshot.PurchaseUnitCount > 1 Then Return "UNIT_COUNT"'; Replace = '''two units allowed' }
    # --- controllo della creazione ---
    @{ Name = 'M48_CREATE_STATE_NOT_CHECKED'; Find = 'If createdStatus.Length > 0 AndAlso createdStatus <> "CREATED" AndAlso createdStatus <> "PAYER_ACTION_REQUIRED" Then Return "STATE"'; Replace = '''state not checked' }
    @{ Name = 'M49_CREATE_WITH_CAPTURE_ALLOWED'; Find = 'If snapshot.CaptureCount <> 0 OrElse snapshot.AuthorizationCount <> 0 Then Return "STATE"'; Replace = '''capture allowed' }
    @{ Name = 'M50_CREATE_APPROVAL_NOT_REQUIRED'; Find = 'If Not String.IsNullOrEmpty(snapshot.ApprovalUrl) Then Return String.Empty'; Replace = 'Return String.Empty' }
    @{ Name = 'M51_CREATE_ORDER_ID_NOT_VALIDATED'; Find = 'If Not IsExternalIdValid(snapshot.OrderId) Then Return "ORDER_ID"'; Replace = '''order id not validated' }
    # --- parser ---
    @{ Name = 'M52_CAPTURE_INVOICE_NOT_PARSED'; Find = 'snapshot.CaptureInvoiceId = ReadString(capture, "invoice_id")'; Replace = '''capture invoice not parsed' }
    @{ Name = 'M53_CAPTURE_CUSTOM_NOT_PARSED'; Find = 'snapshot.CaptureCustomId = ReadString(capture, "custom_id")'; Replace = '''capture custom not parsed' }
) }
