Imports System
Imports System.Globalization
Imports System.Web

Partial Class paypalreturn
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If IsPostBack Then Return
        Dim documentId As Integer = QueryInt("id")
        Dim utentiId As Integer = PayPalPaymentState.GetSessionInt("UtentiId", 0)
        If PayPalPaymentState.GetSessionInt("LoginId", 0) <= 0 OrElse utentiId <= 0 Then RedirectTerminal("login.aspx") : Return
        Dim doc As PayPalPaymentDocumentInfo = PayPalPaymentState.LoadDocumentForUser(documentId, utentiId)
        If doc Is Nothing OrElse Not doc.Exists Then RedirectTerminal("accessonegato.aspx") : Return
        If doc.Pagato = 1 Then RedirectResult(documentId, "ok") : Return
        If doc.PaymentOnline <> PayPalPaymentState.PAYPAL_ONLINE_VALUE Then Fail(documentId, "Metodo di pagamento non coerente") : Return
        Dim tx As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForDocument(documentId)
        If tx Is Nothing OrElse Not tx.Exists OrElse tx.AziendeId <> doc.AziendeId OrElse String.IsNullOrWhiteSpace(tx.PayPalOrderId) Then Fail(documentId, "Transazione PayPal non trovata") : Return
        Dim actionName As String = Convert.ToString(Request.QueryString("action")).Trim()
        Dim rawOrderId As String = Convert.ToString(Request.QueryString("token"))
        If String.Equals(actionName, "cancel", StringComparison.OrdinalIgnoreCase) Then
            If Not String.IsNullOrWhiteSpace(rawOrderId) AndAlso Not PayPalOrdersV2Client.IsReturnOrderTokenValid(rawOrderId, tx.PayPalOrderId) Then Fail(documentId, "Riferimento PayPal non coerente") : Return
            PayPalCheckoutRepository.MarkCanceled(tx)
            RedirectResult(documentId, "ko") : Return
        End If
        If Not String.Equals(actionName, "return", StringComparison.OrdinalIgnoreCase) Then Fail(documentId, "Rientro PayPal non valido") : Return
        If Not PayPalOrdersV2Client.IsReturnOrderTokenValid(rawOrderId, tx.PayPalOrderId) Then Fail(documentId, "Riferimento PayPal mancante o non coerente") : Return
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForDocument(documentId)
        If cfg Is Nothing OrElse cfg.AccountId <> tx.PayPalAccountId OrElse Not PayPalCheckoutSafetyPolicy.CanUseLiveCheckout(HttpContext.Current, cfg) Then Fail(documentId, "Configurazione PayPal Checkout non disponibile") : Return
        Dim client As New PayPalOrdersV2Client(cfg)
        Dim details As PayPalOrdersV2Result = client.GetOrder(tx.PayPalOrderId)
        If details Is Nothing OrElse Not details.Success OrElse Not PayPalOrdersV2Client.ValidateSnapshot(doc, cfg, tx.PayPalOrderId, details.Snapshot) Then
            Fail(documentId, "Approvazione PayPal non verificata") : Return
        End If
        If String.Equals(details.Snapshot.CaptureStatus, "COMPLETED", StringComparison.OrdinalIgnoreCase) Then
            If PayPalCheckoutRepository.ApplyAuthoritativeState(tx, details.Snapshot, String.Empty) Then RedirectResult(documentId, "ok") Else Fail(documentId, "Sincronizzazione pagamento non riuscita")
            Return
        End If
        If String.Equals(details.Snapshot.CaptureStatus, "PENDING", StringComparison.OrdinalIgnoreCase) Then
            PayPalCheckoutRepository.ApplyAuthoritativeState(tx, details.Snapshot, String.Empty)
            RedirectResult(documentId, "ko")
            Return
        End If
        If Not String.Equals(details.Snapshot.Status, "APPROVED", StringComparison.OrdinalIgnoreCase) Then Fail(documentId, "Ordine PayPal non approvato") : Return
        Dim capture As PayPalOrdersV2Result = client.CaptureOrder(tx.PayPalOrderId, tx.CaptureRequestId)
        If capture Is Nothing OrElse Not capture.Success OrElse Not PayPalOrdersV2Client.ValidateSnapshot(doc, cfg, tx.PayPalOrderId, capture.Snapshot) Then Fail(documentId, "Capture PayPal non verificata") : Return
        If Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, capture.Snapshot, String.Empty) Then Fail(documentId, "Aggiornamento pagamento non riuscito") : Return
        If String.Equals(capture.Snapshot.CaptureStatus, "COMPLETED", StringComparison.OrdinalIgnoreCase) Then RedirectResult(documentId, "ok") Else RedirectResult(documentId, "ko")
    End Sub

    Private Sub Fail(ByVal documentId As Integer, ByVal message As String)
        PayPalPaymentState.MarkFailed(documentId, message)
        RedirectResult(documentId, "ko")
    End Sub

    Private Sub RedirectResult(ByVal documentId As Integer, ByVal outcome As String)
        RedirectTerminal("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=" & outcome)
    End Sub

    Private Function QueryInt(ByVal key As String) As Integer
        Dim parsed As Integer
        Integer.TryParse(Convert.ToString(Request.QueryString(key)), parsed)
        Return parsed
    End Function

    Private Sub RedirectTerminal(ByVal url As String)
        Response.Redirect(url, False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
