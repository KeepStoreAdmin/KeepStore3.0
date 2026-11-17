Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization

' PAYPAL-PAY-FIRST-RECOVERY-1A (P3b del progetto pay-first, docs/PAYPAL_PAY_FIRST_DESIGN.md): recupero. Il tentativo si allinea agli eventi del webhook,
' il dettaglio dell'ordine puo riprendere un incasso fermo e le autorizzazioni abbandonate si annullano. Nessuna funzione usa HttpContext (client e configurazione
' sono parametri) e nessuna annulla un'autorizzazione di un ordine gia creato: l'annullo parte solo da AUTHORIZED (RecordVoidingUnbound).
' Regole: un evento non e una prova per perdere un'autorizzazione (si rilegge PayPal); un incasso su un tentativo senza ordine non si perde (CAPTURED_ORPHAN);
' un tentativo con documento non si tocca mai da qui tranne per registrare l'incasso.
Public NotInheritable Class PayPalPayFirstRecovery
    Private Sub New()
    End Sub

    ' Minuti oltre la scadenza della bozza dopo i quali un tentativo non concluso e considerato abbandonato.
    Public Const AbandonedAfterMinutes As Integer = 5

    Private Shared Sub Log(ByVal text As String)
        Try
            KeepStoreLog.Info("paypal-payfirst", PayPalPaymentAttempts.SanitizeOutcome(text), System.Web.HttpContext.Current)
        Catch
        End Try
    End Sub

    ' ----- webhook: eventi di capture (dopo il percorso esistente, che aggiorna documento e riga PayPal) -----
    ' Restituisce un codice per il registro. Nessuna chiamata a PayPal: l'evento e gia firmato e verificato dal chiamante.
    Public Shared Function SyncAfterCaptureEvent(ByVal orderId As String, ByVal captureId As String, ByVal captureStatus As String) As String
        Dim attempt As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForSystemByOrderId(orderId)
        If attempt Is Nothing Then Return "NO_ATTEMPT"
        Dim status As String = Convert.ToString(captureStatus).Trim().ToUpperInvariant()
        Select Case status
            Case "COMPLETED"
                If String.IsNullOrWhiteSpace(captureId) Then Return "NO_CAPTURE_ID"
                If attempt.Stato = PayPalPaymentAttemptStates.Unknown AndAlso (attempt.StatoPrecedente = PayPalPaymentAttemptStates.DocCommitted OrElse attempt.StatoPrecedente = PayPalPaymentAttemptStates.Capturing) Then
                    ' UNKNOWN esce solo verso lo stato precedente: poi la capture si registra normalmente.
                    If Not PayPalPaymentAttempts.ResolveUnknown(attempt.Id, attempt.AziendeId, attempt.StatoPrecedente, "WEBHOOK_CAPTURE") Then Return "UNKNOWN_NOT_RESOLVED"
                    attempt = PayPalPaymentAttempts.LoadForSystemByOrderId(orderId)
                    If attempt Is Nothing Then Return "NO_ATTEMPT"
                End If
                Select Case attempt.Stato
                    Case PayPalPaymentAttemptStates.DocCommitted, PayPalPaymentAttemptStates.Capturing, PayPalPaymentAttemptStates.CaptureRefused
                        Return If(PayPalPaymentAttempts.RecordCaptureResult(attempt.Id, attempt.AziendeId, captureId, True, "WEBHOOK"), "COMPLETED", "NOT_RECORDED")
                    Case PayPalPaymentAttemptStates.Completed
                        Return "ALREADY_COMPLETED"
                    Case PayPalPaymentAttemptStates.Authorized, PayPalPaymentAttemptStates.Voiding, PayPalPaymentAttemptStates.Voided, PayPalPaymentAttemptStates.Failed, PayPalPaymentAttemptStates.Canceled
                        ' Incasso (dal pannello PayPal o tardivo) su un tentativo SENZA ordine: non si perde, si registra per la riconciliazione manuale.
                        Log("ORPHAN_CAPTURE attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " capture=" & PayPalPaymentState.SanitizeExternalId(captureId))
                        Return If(PayPalPaymentAttempts.RecordOrphanCapture(attempt.Id, attempt.AziendeId, captureId), "ORPHAN_CAPTURE", "NOT_RECORDED")
                End Select
            Case "DENIED", "DECLINED", "FAILED"
                ' Un incasso rifiutato conta solo se e stato avviato (CAPTURING): su DOC_COMMITTED nulla e stato tentato.
                If attempt.Stato = PayPalPaymentAttemptStates.Capturing Then
                    Return If(PayPalPaymentAttempts.RecordCaptureResult(attempt.Id, attempt.AziendeId, String.Empty, False, "WEBHOOK_" & status), "REFUSED", "NOT_RECORDED")
                End If
        End Select
        Return "NO_CHANGE"
    End Function

    ' ----- webhook: eventi di autorizzazione (anche senza riga PayPal: l'ordine puo non esistere ancora) -----
    Public Shared Function HandleAuthorizationEvent(ByVal attempt As PayPalAttemptRecord, ByVal eventType As String, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client) As String
        If attempt Is Nothing Then Return "NO_ATTEMPT"
        Dim type As String = Convert.ToString(eventType).Trim().ToUpperInvariant()
        If type = "PAYMENT.AUTHORIZATION.CREATED" Then Return "IGNORED"
        If type <> "PAYMENT.AUTHORIZATION.VOIDED" Then Return "UNSUPPORTED"
        If attempt.Stato = PayPalPaymentAttemptStates.Unknown AndAlso attempt.StatoPrecedente = PayPalPaymentAttemptStates.Voiding Then
            If Not PayPalPaymentAttempts.ResolveUnknown(attempt.Id, attempt.AziendeId, PayPalPaymentAttemptStates.Voiding, "WEBHOOK_VOIDED") Then Return "UNKNOWN_NOT_RESOLVED"
            attempt = PayPalPaymentAttempts.LoadForOwner(attempt.AttemptKey, attempt.AziendeId, attempt.LoginId)
            If attempt Is Nothing Then Return "NO_ATTEMPT"
        End If
        Select Case attempt.Stato
            Case PayPalPaymentAttemptStates.Voiding
                Return If(PayPalPaymentAttempts.RecordVoided(attempt.Id, attempt.AziendeId), "VOIDED", "NOT_RECORDED")
            Case PayPalPaymentAttemptStates.Authorized
                ' L'evento non e una prova: si rilegge l'autorizzazione su PayPal prima di dichiarare persa.
                If client Is Nothing OrElse cfg Is Nothing OrElse String.IsNullOrEmpty(attempt.PayPalAuthorizationId) Then Return "NO_CHANGE"
                Dim read As PayPalPaymentsResult = client.GetAuthorization(attempt.PayPalAuthorizationId)
                If read Is Nothing OrElse Not read.Success OrElse read.Authorization Is Nothing Then Return "NO_CHANGE"
                Dim remote As String = Convert.ToString(read.Authorization.Status).ToUpperInvariant()
                If remote = "VOIDED" OrElse remote = "EXPIRED" OrElse remote = "DENIED" Then
                    Return If(PayPalPaymentAttempts.RecordAuthorizationLost(attempt.Id, attempt.AziendeId, remote), "AUTHORIZATION_LOST", "NOT_RECORDED")
                End If
        End Select
        Return "NO_CHANGE"
    End Function

    ' ----- dettaglio ordine: ricontrollo di un ordine pay-first (riprende un incasso fermo) -----
    Public Shared Function RecheckDocument(ByVal attempt As PayPalAttemptRecord, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client) As PayPalPendingRecheckResult
        Dim result As New PayPalPendingRecheckResult With {.DocumentId = If(attempt Is Nothing, 0, attempt.DocumentiId)}
        Dim run As PayFirstFinishResult = PayPalPayFirstFinishService.Run(attempt, cfg, client)
        Select Case run.Outcome
            Case PayFirstFinishOutcome.Completed
                result.Success = True
                result.Outcome = "COMPLETED"
                result.PayReturn = "ok"
                Dim reloaded As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(attempt.AttemptKey, attempt.AziendeId, attempt.LoginId)
                result.TransactionId = If(reloaded Is Nothing, String.Empty, reloaded.PayPalCaptureId)
            Case PayFirstFinishOutcome.InVerification
                If run.Reason = "CAPTURE_PENDING" Then
                    result.Success = True
                    result.Outcome = "PENDING"
                    result.PayReturn = "ok"
                Else
                    result.Outcome = "NOT_COMPLETED"
                    result.PayReturn = "ko"
                End If
            Case Else
                result.Outcome = "NOT_COMPLETED"
                result.PayReturn = "ko"
        End Select
        Return result
    End Function

    ' ----- autorizzazioni abbandonate di un proprietario (chiamato quando il cliente torna a pagare) -----
    ' Un tentativo vivo con la bozza scaduta da piu di AbandonedAfterMinutes e senza ordine: AUTHORIZED = annullo dell'autorizzazione (fondi liberati),
    ' CREATING/CREATED = chiuso. Non si tocca la bozza corrente, un tentativo con documento, un altro proprietario o un altro metodo di pagamento.
    Public Shared Function SweepOwner(ByVal aziendeId As Integer, ByVal loginId As Long, ByVal currentDraftRequestId As String, ByVal cfg As PayPalCheckoutConfig,
                                      ByVal client As PayPalOrdersV2Client, ByVal nowUtc As DateTime) As Integer
        If aziendeId <= 0 OrElse loginId <= 0 OrElse cfg Is Nothing OrElse client Is Nothing Then Return 0
        Dim swept As Integer = 0
        For Each a As PayPalAttemptRecord In PayPalPaymentAttempts.ListLiveByOwner(aziendeId, loginId)
            If String.Equals(a.DraftRequestId, currentDraftRequestId, StringComparison.Ordinal) Then Continue For
            If a.DocumentiId > 0 Then Continue For
            If a.AziendeId <> cfg.AziendeId OrElse a.PagamentiTipoId <> cfg.PagamentiTipoId Then Continue For
            If a.DraftExpiresUtc > nowUtc.AddMinutes(-AbandonedAfterMinutes) Then Continue For
            Select Case a.Stato
                Case PayPalPaymentAttemptStates.Authorized
                    If PayPalPayFirstService.VoidAuthorized(a, cfg, client) Then swept += 1
                Case PayPalPaymentAttemptStates.Creating, PayPalPaymentAttemptStates.Created
                    If PayPalPaymentAttempts.RecordFailed(a.Id, a.AziendeId, "DRAFT_EXPIRED") Then swept += 1
            End Select
        Next
        Return swept
    End Function
End Class
