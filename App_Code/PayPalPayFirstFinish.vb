Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Web

' PAYPAL-PAY-FIRST-ORDER-1A (P3a2 del progetto pay-first, docs/PAYPAL_PAY_FIRST_DESIGN.md): incasso dell'autorizzazione DOPO il commit dell'ordine, fuori dal lock
' di ordine.aspx. Il servizio NON usa HttpContext (client e configurazione sono parametri) ed e riprendibile: ogni chiamata parte dallo stato durevole del tentativo
' (DOC_COMMITTED, CAPTURING, CAPTURE_REFUSED, COMPLETED), quindi un rinfresco della pagina o un recupero non ripetono mai un effetto gia avvenuto.
' Regole: nessuna chiamata a PayPal con una riga del tentativo bloccata; incassa soltanto COMPLETED; dopo ogni esito incerto si rilegge lo stato su PayPal;
' il documento si registra come pagato SOLO dopo il GET dell'ordine validato (la risposta di capture da sola non basta); chi ottiene True da RecordCaptureResult(completed)
' e l'unico che invia l'e-mail (al massimo una volta, come oggi).

Public Enum PayFirstFinishOutcome
    Completed = 1
    InVerification = 2
    Refused = 3
    Manual = 4
    Technical = 5
End Enum

Public NotInheritable Class PayFirstFinishResult
    Public Property Outcome As PayFirstFinishOutcome
    Public Property Reason As String = String.Empty
    Public Property FirstCompletion As Boolean
    Public Property DocumentId As Integer
End Class

Public NotInheritable Class PayPalPayFirstFinishService
    Private Sub New()
    End Sub

    Public Const CaptureLeaseSeconds As Integer = 45

    Private Shared Function Done(ByVal outcome As PayFirstFinishOutcome, ByVal reason As String, ByVal documentId As Integer, Optional ByVal first As Boolean = False) As PayFirstFinishResult
        Return New PayFirstFinishResult With {.Outcome = outcome, .Reason = PayPalPaymentAttempts.SanitizeOutcome(reason), .DocumentId = documentId, .FirstCompletion = first}
    End Function

    Private Shared Sub Log(ByVal text As String)
        Try
            KeepStoreLog.Info("paypal-payfirst", PayPalPaymentAttempts.SanitizeOutcome(text), HttpContext.Current)
        Catch
        End Try
    End Sub

    Private Shared Function ToInfo(ByVal attempt As PayPalAttemptRecord) As PayPalAttemptInfo
        Return New PayPalAttemptInfo With {.AziendeId = attempt.AziendeId, .PagamentiTipoId = attempt.PagamentiTipoId, .AttemptId = attempt.Id, .Amount = attempt.Importo}
    End Function

    ' Riferimento di fattura dell'incasso = id del DOCUMENTO (mai il numero ordine: si ripete ogni anno).
    Public Shared Function CaptureInvoiceId(ByVal attempt As PayPalAttemptRecord) As String
        Return "KS-INV-" & attempt.AziendeId.ToString(CultureInfo.InvariantCulture) & "-" & attempt.DocumentiId.ToString(CultureInfo.InvariantCulture)
    End Function

    ' Request id dell'incasso senza invoice_id (corpo diverso = PayPal-Request-Id diverso): deriva dalla chiave del tentativo, stesso schema degli altri.
    Public Shared Function CaptureNoInvoiceRequestId(ByVal attempt As PayPalAttemptRecord) As String
        Return "PPA-" & attempt.AttemptKey & "-N"
    End Function

    Public Shared Function Run(ByVal attempt As PayPalAttemptRecord, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client) As PayFirstFinishResult
        If attempt Is Nothing OrElse cfg Is Nothing OrElse client Is Nothing OrElse Not cfg.IsConfigured OrElse cfg.AziendeId <> attempt.AziendeId OrElse
           cfg.PagamentiTipoId <> attempt.PagamentiTipoId OrElse cfg.AccountId <> attempt.PayPalAccountId Then
            Return Done(PayFirstFinishOutcome.Technical, "FINISH_INPUT", If(attempt Is Nothing, 0, attempt.DocumentiId))
        End If
        Dim current As PayPalAttemptRecord = attempt
        For round As Integer = 1 To 2
            Select Case current.Stato
                Case PayPalPaymentAttemptStates.Completed
                    Return Done(PayFirstFinishOutcome.Completed, "ALREADY_COMPLETED", current.DocumentiId)
                Case PayPalPaymentAttemptStates.CaptureRefused
                    Return FinishRefused(current, cfg, client)
                Case PayPalPaymentAttemptStates.DocCommitted
                    Dim began As PayPalBeginCaptureOutcome = PayPalPaymentAttempts.BeginCapture(current.Id, current.AziendeId)
                    If began = PayPalBeginCaptureOutcome.Started Then Return CaptureStep(current, cfg, client, retry:=False)
                    If began = PayPalBeginCaptureOutcome.DocumentInvalid Then Return Done(PayFirstFinishOutcome.Manual, "DOCUMENT_INVALID", current.DocumentiId)
                    If began = PayPalBeginCaptureOutcome.TechnicalError Then Return Done(PayFirstFinishOutcome.Technical, "BEGIN_CAPTURE", current.DocumentiId)
                    ' NotInState: un altro processo ha gia avviato l'incasso; si rilegge lo stato e si riparte da li.
                    Dim reloaded As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(current.AttemptKey, current.AziendeId, current.LoginId)
                    If reloaded Is Nothing OrElse reloaded.Stato = PayPalPaymentAttemptStates.DocCommitted Then Return Done(PayFirstFinishOutcome.Technical, "BEGIN_CAPTURE_STATE", current.DocumentiId)
                    current = reloaded
                Case PayPalPaymentAttemptStates.Capturing
                    ' Un solo esecutore alla volta riprova un incasso fermo (contratto di locazione): gli altri aspettano.
                    If Not PayPalPaymentAttempts.TryClaimCaptureRetry(current.Id, current.AziendeId, CaptureLeaseSeconds) Then Return Done(PayFirstFinishOutcome.InVerification, "CAPTURE_IN_PROGRESS", current.DocumentiId)
                    Return CaptureStep(current, cfg, client, retry:=True)
                Case Else
                    Return Done(PayFirstFinishOutcome.InVerification, "STATE_" & current.Stato, current.DocumentiId)
            End Select
        Next
        Return Done(PayFirstFinishOutcome.Technical, "FINISH_LOOP", attempt.DocumentiId)
    End Function

    Private Shared Function CaptureStep(ByVal attempt As PayPalAttemptRecord, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client, ByVal retry As Boolean) As PayFirstFinishResult
        Dim info As PayPalAttemptInfo = ToInfo(attempt)
        If String.IsNullOrEmpty(attempt.PayPalAuthorizationId) OrElse String.IsNullOrEmpty(attempt.PayPalOrderId) OrElse attempt.DocumentiId <= 0 Then
            Return Done(PayFirstFinishOutcome.Manual, "ATTEMPT_INCOMPLETE", attempt.DocumentiId)
        End If
        ' Ripresa: PayPal e l'autorita. Se l'incasso e gia avvenuto (risposta persa, processo morto) si registra senza ripeterlo.
        If retry Then
            Dim known As PayFirstFinishResult = ReadAndDecide(attempt, info, cfg, client)
            If known IsNot Nothing Then Return known
        End If
        Dim captured As PayPalPaymentsResult = client.CaptureAuthorization(attempt.PayPalAuthorizationId, attempt.CaptureRequestId, attempt.Importo, cfg.CurrencyCode, CaptureInvoiceId(attempt))
        Return EvaluateCapture(attempt, info, cfg, client, captured, allowInvoiceFallback:=True)
    End Function

    Private Shared Function EvaluateCapture(ByVal attempt As PayPalAttemptRecord, ByVal info As PayPalAttemptInfo, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client,
                                            ByVal captured As PayPalPaymentsResult, ByVal allowInvoiceFallback As Boolean) As PayFirstFinishResult
        If captured Is Nothing OrElse Not captured.Success Then
            If captured IsNot Nothing AndAlso captured.NotSent Then Return Done(PayFirstFinishOutcome.InVerification, "CAPTURE_NOT_SENT", attempt.DocumentiId)
            Dim invoiceIssue As Boolean = captured IsNot Nothing AndAlso Convert.ToString(captured.ErrorCode).ToUpperInvariant().Contains("INVOICE")
            If PayPalOrdersV2Client.IsOutcomeUncertain(captured) OrElse invoiceIssue Then
                ' Esito incerto o rifiuto sul riferimento di fattura: prima si rilegge PayPal (un incasso potrebbe essere avvenuto).
                Dim decided As PayFirstFinishResult = ReadAndDecide(attempt, info, cfg, client)
                If decided IsNot Nothing Then Return decided
                If invoiceIssue AndAlso allowInvoiceFallback Then
                    ' Nessuna capture e autorizzazione ancora valida: stessa autorizzazione, nessun invoice_id, PayPal-Request-Id diverso (il corpo e diverso).
                    Dim again As PayPalPaymentsResult = client.CaptureAuthorization(attempt.PayPalAuthorizationId, CaptureNoInvoiceRequestId(attempt), attempt.Importo, cfg.CurrencyCode, String.Empty)
                    Return EvaluateCapture(attempt, info, cfg, client, again, allowInvoiceFallback:=False)
                End If
                Return Done(PayFirstFinishOutcome.InVerification, "CAPTURE_UNCERTAIN", attempt.DocumentiId)
            End If
            ' Rifiuto definitivo (carta rifiutata, autorizzazione scaduta o annullata, importo): nessun incasso.
            Log("capture refused attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " code=" & If(captured Is Nothing, "none", Convert.ToString(captured.ErrorCode)))
            PayPalPaymentAttempts.RecordCaptureResult(attempt.Id, attempt.AziendeId, String.Empty, False, "CAPTURE_REFUSED")
            Return FinishRefused(PayPalPaymentAttempts.LoadForOwner(attempt.AttemptKey, attempt.AziendeId, attempt.LoginId), cfg, client)
        End If
        Dim capture As PayPalCaptureSnapshot = captured.Capture
        Dim reason As String = PayPalOrdersV2Client.CheckCaptureSnapshot(attempt.Importo, cfg.CurrencyCode, String.Empty, attempt.PayPalAuthorizationId, capture)
        If reason.Length > 0 Then
            Log("capture response check attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " reason=" & reason)
            Dim decided As PayFirstFinishResult = ReadAndDecide(attempt, info, cfg, client, "CAPTURE_RESPONSE_" & reason)
            Return If(decided, Done(PayFirstFinishOutcome.InVerification, "CAPTURE_RESPONSE_" & reason, attempt.DocumentiId))
        End If
        If PayPalOrdersV2Client.IsCaptureCompleted(capture) Then Return ApplyCompleted(attempt, info, cfg, client)
        If String.Equals(capture.Status, "PENDING", StringComparison.Ordinal) Then Return Done(PayFirstFinishOutcome.InVerification, "CAPTURE_PENDING", attempt.DocumentiId)
        ' DECLINED, FAILED, REFUNDED...: non e un incasso.
        PayPalPaymentAttempts.RecordCaptureResult(attempt.Id, attempt.AziendeId, String.Empty, False, "CAPTURE_" & capture.Status)
        Return FinishRefused(PayPalPaymentAttempts.LoadForOwner(attempt.AttemptKey, attempt.AziendeId, attempt.LoginId), cfg, client)
    End Function
    ' Legge l'ordine su PayPal e decide: capture COMPLETED -> registra; PENDING -> in verifica; DECLINED -> rifiuto; nessuna capture -> Nothing (si puo incassare).
    Private Shared Function ReadAndDecide(ByVal attempt As PayPalAttemptRecord, ByVal info As PayPalAttemptInfo, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client,
                                          Optional ByVal unavailableReason As String = "READ_UNAVAILABLE") As PayFirstFinishResult
        Dim order As PayPalOrdersV2Result = client.GetOrder(attempt.PayPalOrderId)
        If order Is Nothing OrElse Not order.Success OrElse order.Snapshot Is Nothing Then Return Done(PayFirstFinishOutcome.InVerification, unavailableReason, attempt.DocumentiId)
        Dim reason As String = PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(info, cfg, attempt.PayPalOrderId, order.Snapshot)
        If reason.Length > 0 Then
            Log("read check failed attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " reason=" & reason)
            Return Done(PayFirstFinishOutcome.Manual, "READ_" & reason, attempt.DocumentiId)
        End If
        If order.Snapshot.CaptureCount = 0 Then Return Nothing
        Select Case Convert.ToString(order.Snapshot.CaptureStatus).ToUpperInvariant()
            Case "COMPLETED"
                Return ApplyCompleted(attempt, info, cfg, client)
            Case "PENDING"
                Return Done(PayFirstFinishOutcome.InVerification, "CAPTURE_PENDING", attempt.DocumentiId)
            Case "DECLINED", "DENIED", "FAILED"
                PayPalPaymentAttempts.RecordCaptureResult(attempt.Id, attempt.AziendeId, String.Empty, False, "CAPTURE_" & Convert.ToString(order.Snapshot.CaptureStatus))
                Return FinishRefused(PayPalPaymentAttempts.LoadForOwner(attempt.AttemptKey, attempt.AziendeId, attempt.LoginId), cfg, client)
        End Select
        Return Done(PayFirstFinishOutcome.InVerification, "CAPTURE_STATE_" & Convert.ToString(order.Snapshot.CaptureStatus), attempt.DocumentiId)
    End Function

    ' Il documento si paga solo con l'ordine riletto su PayPal: capture COMPLETED, importo e valuta del tentativo, una sola capture.
    Private Shared Function ApplyCompleted(ByVal attempt As PayPalAttemptRecord, ByVal info As PayPalAttemptInfo, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client) As PayFirstFinishResult
        Dim order As PayPalOrdersV2Result = client.GetOrder(attempt.PayPalOrderId)
        If order Is Nothing OrElse Not order.Success OrElse order.Snapshot Is Nothing Then Return Done(PayFirstFinishOutcome.InVerification, "APPLY_READ_UNAVAILABLE", attempt.DocumentiId)
        Dim reason As String = PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(info, cfg, attempt.PayPalOrderId, order.Snapshot)
        Dim snapshot As PayPalOrderSnapshot = order.Snapshot
        Dim mismatch As Boolean = reason.Length > 0 OrElse snapshot.CaptureCount <> 1 OrElse Not String.Equals(snapshot.CaptureStatus, "COMPLETED", StringComparison.OrdinalIgnoreCase)
        If Not mismatch Then mismatch = Not PayPalOrdersV2Client.HasMatchingCapture(snapshot, attempt.Importo, cfg.CurrencyCode)
        If mismatch Then
            Log("apply check failed attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " reason=" & If(reason.Length > 0, reason, "CAPTURE_NOT_MATCHING"))
            Return Done(PayFirstFinishOutcome.InVerification, "APPLY_NOT_MATCHING", attempt.DocumentiId)
        End If
        Dim tx As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForDocument(attempt.DocumentiId)
        If tx Is Nothing OrElse Not tx.Exists OrElse Not String.Equals(tx.PayPalOrderId, attempt.PayPalOrderId, StringComparison.Ordinal) Then Return Done(PayFirstFinishOutcome.Manual, "TRANSACTION_ROW_MISSING", attempt.DocumentiId)
        If Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, snapshot, String.Empty) Then Return Done(PayFirstFinishOutcome.InVerification, "APPLY_NOT_RECORDED", attempt.DocumentiId)
        ' True solo per chi fa la transizione vera: e l'unico che invia l'e-mail. Un arresto tra il pagamento e la transizione si chiude al rinfresco (marker identico accettato).
        Dim first As Boolean = PayPalPaymentAttempts.RecordCaptureResult(attempt.Id, attempt.AziendeId, PayPalPaymentState.SanitizeExternalId(snapshot.CaptureId), True, "")
        Return Done(PayFirstFinishOutcome.Completed, If(first, "COMPLETED", "COMPLETED_REPLAY"), attempt.DocumentiId, first)
    End Function

    ' Incasso rifiutato: il documento resta non pagato (StatoPagamentoWeb = 3 con il motivo, da annullare a mano: rischio residuo accettato), nessun addebito;
    ' l'autorizzazione si annulla e, se l'annullo non riesce, resta VOIDING/UNKNOWN per il recupero.
    Private Shared Function FinishRefused(ByVal attempt As PayPalAttemptRecord, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client) As PayFirstFinishResult
        If attempt Is Nothing Then Return Done(PayFirstFinishOutcome.Technical, "REFUSED_NO_ATTEMPT", 0)
        If attempt.DocumentiId > 0 Then PayPalPaymentState.MarkFailed(attempt.DocumentiId, "PayPal Checkout: incasso non riuscito")
        If attempt.Stato = PayPalPaymentAttemptStates.CaptureRefused AndAlso Not String.IsNullOrEmpty(attempt.PayPalAuthorizationId) Then
            If PayPalPaymentAttempts.RecordVoiding(attempt.Id, attempt.AziendeId, "CAPTURE_REFUSED") Then
                Dim voided As PayPalPaymentsResult = client.VoidAuthorization(attempt.PayPalAuthorizationId, attempt.VoidRequestId)
                If voided IsNot Nothing AndAlso voided.Success Then
                    PayPalPaymentAttempts.RecordVoided(attempt.Id, attempt.AziendeId)
                Else
                    Dim reread As PayPalPaymentsResult = client.GetAuthorization(attempt.PayPalAuthorizationId)
                    If reread IsNot Nothing AndAlso reread.Success AndAlso reread.Authorization IsNot Nothing AndAlso String.Equals(reread.Authorization.Status, "VOIDED", StringComparison.Ordinal) Then
                        PayPalPaymentAttempts.RecordVoided(attempt.Id, attempt.AziendeId)
                    Else
                        PayPalPaymentAttempts.RecordUnknown(attempt.Id, attempt.AziendeId, "VOID_UNCERTAIN")
                    End If
                End If
            End If
        End If
        Return Done(PayFirstFinishOutcome.Refused, "CAPTURE_REFUSED", attempt.DocumentiId)
    End Function
End Class
