Imports System
Imports System.Globalization
Imports System.Web

Partial Class paypalreturn
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If IsPostBack Then Return

        Dim documentId As Integer = GetQueryInt("id")
        Dim actionName As String = GetQueryString("action", 20)
        If actionName = "" Then actionName = GetQueryString("status", 20)

        Dim loginId As Integer = PayPalPaymentState.GetSessionInt("LoginId", 0)
        Dim utentiId As Integer = PayPalPaymentState.GetSessionInt("UtentiId", 0)

        If loginId <= 0 OrElse utentiId <= 0 Then
            SafeRedirect("login.aspx")
            Return
        End If

        Dim doc As PayPalPaymentDocumentInfo = PayPalPaymentState.LoadDocumentForUser(documentId, utentiId)
        If doc Is Nothing OrElse Not doc.Exists Then
            SafeRedirect("accessonegato.aspx")
            Return
        End If

        If doc.Pagato = 1 Then
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ok")
            Return
        End If

        If doc.PaymentOnline <> PayPalPaymentState.PAYPAL_ONLINE_VALUE Then
            PayPalPaymentState.MarkFailed(documentId, "PayPal: pagamento non coerente con il documento")
            PayPalExpressRepository.RecordOutcome(doc, "PayPalReturn", "KO", "PayPal: pagamento non coerente con il documento")
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        If String.Equals(actionName, "cancel", StringComparison.OrdinalIgnoreCase) Then
            Dim cancelToken As String = GetQueryString("token", 100)
            If cancelToken = "" Then cancelToken = PayPalPaymentState.ExtractExpressToken(doc.TransactionId)
            PayPalPaymentState.MarkCanceled(documentId, "PayPal Express: pagamento annullato dall'utente")
            PayPalExpressRepository.MarkTransactionCanceled(doc, cancelToken, "PayPal Express: pagamento annullato dall'utente")
            PayPalExpressRepository.RecordOutcome(doc, "PayPalReturnCancel", "CANCELED", "PayPal Express: pagamento annullato dall'utente", cancelToken)
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        If String.Equals(actionName, "return", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(actionName, "ok", StringComparison.OrdinalIgnoreCase) Then
            HandleReturn(documentId, doc)
            Return
        End If

        PayPalPaymentState.MarkFailed(documentId, "PayPal Express: rientro pagamento non valido")
        PayPalExpressRepository.RecordOutcome(doc, "PayPalReturn", "KO", "PayPal Express: rientro pagamento non valido")
        SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
    End Sub

    Private Sub HandleReturn(ByVal documentId As Integer, ByVal doc As PayPalPaymentDocumentInfo)
        Dim token As String = GetQueryString("token", 80)
        Dim payerId As String = GetQueryString("PayerID", 80)

        If token = "" OrElse payerId = "" Then
            PayPalPaymentState.MarkFailed(documentId, "PayPal Express: token o PayerID assente")
            PayPalExpressRepository.RecordOutcome(doc, "PayPalReturn", "KO", "PayPal Express: token o PayerID assente", token)
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        Dim expectedToken As String = PayPalPaymentState.ExtractExpressToken(doc.TransactionId)
        If expectedToken = "" OrElse Not String.Equals(expectedToken, token, StringComparison.Ordinal) Then
            PayPalPaymentState.MarkFailed(documentId, "PayPal Express: token non coerente con il documento")
            PayPalExpressRepository.RecordOutcome(doc, "PayPalReturn", "KO", "PayPal Express: token non coerente con il documento", token)
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForDocument(documentId)
        If cfg Is Nothing OrElse Not cfg.IsExpressConfigured Then
            PayPalPaymentState.MarkFailed(documentId, "PayPal Express: configurazione assente")
            PayPalExpressRepository.RecordOutcome(doc, "PayPalReturn", "KO", "PayPal Express: configurazione assente", token)
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        If cfg.IsLive AndAlso Not cfg.AllowLive Then
            PayPalPaymentState.MarkFailed(documentId, "PayPal Express: ambiente live non autorizzato")
            PayPalExpressRepository.RecordOutcome(doc, "PayPalReturn", "KO", "PayPal Express: ambiente live non autorizzato", token)
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        Dim client As New PayPalExpressClient(cfg)
        Dim details As PayPalExpressResponse = client.GetExpressCheckoutDetails(token)
        If details Is Nothing OrElse Not details.IsSuccess Then
            PayPalPaymentState.MarkFailed(documentId, BuildApiFailureMessage("PayPal Express Get", details))
            PayPalExpressRepository.RecordOutcome(doc, "GetExpressCheckoutDetails", "KO", BuildApiFailureMessage("PayPal Express Get", details), token, If(details Is Nothing, Nothing, details.ErrorCode))
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        If Not ValidateDetails(documentId, doc, cfg, token, payerId, details) Then
            PayPalPaymentState.MarkFailed(documentId, "PayPal Express: dettagli pagamento non coerenti")
            PayPalExpressRepository.RecordOutcome(doc, "GetExpressCheckoutDetails", "KO", "PayPal Express: dettagli pagamento non coerenti", token)
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        Dim payment As PayPalExpressResponse = client.DoExpressCheckoutPayment(doc, token, payerId)
        If payment Is Nothing OrElse Not payment.IsSuccess Then
            PayPalPaymentState.MarkFailed(documentId, BuildApiFailureMessage("PayPal Express Do", payment))
            PayPalExpressRepository.RecordPaymentResult(doc, "FAILED", token, payerId, payment)
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        If payment.IsCompletedPayment AndAlso Not String.IsNullOrWhiteSpace(payment.TransactionId) Then
            PayPalPaymentState.MarkCompleted(documentId, payment.TransactionId, "PayPal Express OK: " & ShortTransaction(payment.TransactionId))
            PayPalExpressRepository.RecordPaymentResult(doc, "COMPLETED", token, payerId, payment)
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ok")
            Return
        End If

        If payment.IsPendingPayment Then
            Dim pendingId As String = If(String.IsNullOrWhiteSpace(payment.TransactionId), token, payment.TransactionId)
            PayPalPaymentState.MarkPendingWithExpressTransaction(documentId, BuildPendingPaymentMessage(payment), pendingId)
            PayPalExpressRepository.RecordPaymentResult(doc, "PENDING", token, payerId, payment)
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ok")
            Return
        End If

        PayPalPaymentState.MarkFailed(documentId, "PayPal Express: pagamento non completato")
        PayPalExpressRepository.RecordPaymentResult(doc, "FAILED", token, payerId, payment)
        SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
    End Sub

    Private Function ValidateDetails(ByVal documentId As Integer, ByVal doc As PayPalPaymentDocumentInfo, ByVal cfg As PayPalCheckoutConfig, ByVal token As String, ByVal payerId As String, ByVal details As PayPalExpressResponse) As Boolean
        If details Is Nothing Then Return False
        If Not String.IsNullOrWhiteSpace(details.Token) AndAlso Not String.Equals(details.Token.Trim(), token, StringComparison.Ordinal) Then Return False
        If String.IsNullOrWhiteSpace(details.PayerId) OrElse Not String.Equals(details.PayerId.Trim(), payerId, StringComparison.Ordinal) Then Return False
        If Not String.Equals(details.CurrencyCode, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) Then Return False
        If details.Amount <> Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero) Then Return False
        If Not String.Equals(details.Custom, documentId.ToString(CultureInfo.InvariantCulture), StringComparison.Ordinal) Then Return False
        If Not String.Equals(details.InvoiceNumber, PayPalExpressClient.ExpectedInvoiceNumber(doc), StringComparison.OrdinalIgnoreCase) Then Return False
        Return True
    End Function

    Private Function BuildPendingPaymentMessage(ByVal response As PayPalExpressResponse) As String
        If response IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(response.PendingReason) Then
            Return "PayPal Express: pagamento pending (" & PayPalPaymentState.SanitizeOutcome(response.PendingReason) & ")"
        End If

        Return "PayPal Express: pagamento pending"
    End Function

    Private Function GetQueryInt(ByVal key As String) As Integer
        Try
            Dim parsed As Integer
            If Integer.TryParse(Convert.ToString(Request.QueryString(key)), parsed) Then Return parsed
        Catch
        End Try

        Return 0
    End Function

    Private Function GetQueryString(ByVal key As String, ByVal maxLen As Integer) As String
        Try
            Dim value As String = Convert.ToString(Request.QueryString(key))
            If value Is Nothing Then Return ""
            value = value.Trim()
            If value.Length > maxLen Then value = value.Substring(0, maxLen)
            Return value
        Catch
        End Try

        Return ""
    End Function

    Private Function BuildApiFailureMessage(ByVal prefix As String, ByVal result As PayPalExpressResponse) As String
        If result Is Nothing Then Return prefix & ": risposta assente"

        Dim code As String = If(result.ErrorCode, "").Trim()
        Dim shortMessage As String = If(result.ShortMessage, "").Trim()
        If code <> "" AndAlso shortMessage <> "" Then Return prefix & " KO " & code & " " & shortMessage
        If code <> "" Then Return prefix & " KO " & code
        If shortMessage <> "" Then Return prefix & " KO " & shortMessage
        Return prefix & " KO"
    End Function

    Private Function ShortTransaction(ByVal transactionId As String) As String
        If transactionId Is Nothing Then Return ""
        Dim clean As String = PayPalPaymentState.SanitizeTransactionId(transactionId)
        If clean.StartsWith(PayPalPaymentState.EXPRESS_TRANSACTION_PREFIX, StringComparison.Ordinal) Then
            clean = clean.Substring(PayPalPaymentState.EXPRESS_TRANSACTION_PREFIX.Length)
        End If
        If clean.Length <= 12 Then Return clean
        Return clean.Substring(0, 12)
    End Function

    Private Sub SafeRedirect(ByVal url As String)
        Try
            Response.Redirect(url, False)
            Context.ApplicationInstance.CompleteRequest()
        Catch
        End Try
    End Sub
End Class
