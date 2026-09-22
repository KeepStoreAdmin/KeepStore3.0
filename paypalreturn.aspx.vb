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
        If doc.Pagato = 1 Then CloseWebLaunch(doc) : RedirectResult(documentId, "ok") : Return
        If doc.PaymentOnline <> PayPalPaymentState.PAYPAL_ONLINE_VALUE Then Fail(documentId, "Metodo di pagamento non coerente") : Return
        Dim actionName As String = Convert.ToString(Request.QueryString("action")).Trim()
        Dim rawOrderId As String = Convert.ToString(Request.QueryString("token"))
        Dim tx As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder(rawOrderId)
        If tx Is Nothing OrElse Not tx.Exists OrElse tx.DocumentiId <> documentId OrElse tx.AziendeId <> doc.AziendeId OrElse
           Not PayPalOrdersV2Client.IsReturnOrderTokenValid(rawOrderId, tx.PayPalOrderId) Then
            RedirectResult(documentId, "ko") : Return
        End If
        If String.Equals(actionName, "cancel", StringComparison.OrdinalIgnoreCase) Then
            If tx.IsCurrent Then PayPalCheckoutRepository.MarkCanceled(tx)
            CloseWebLaunch(doc)
            RedirectResult(documentId, "ko") : Return
        End If
        If Not String.Equals(actionName, "return", StringComparison.OrdinalIgnoreCase) Then Fail(documentId, "Rientro PayPal non valido") : Return
        If Not PayPalOrdersV2Client.IsReturnOrderTokenValid(rawOrderId, tx.PayPalOrderId) Then Fail(documentId, "Riferimento PayPal mancante o non coerente") : Return
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForDocument(documentId)
        If cfg Is Nothing OrElse cfg.AccountId <> tx.PayPalAccountId OrElse Not PayPalCheckoutSafetyPolicy.CanUseLiveCheckout(HttpContext.Current, cfg) Then Fail(documentId, "Configurazione PayPal Checkout non disponibile") : Return
        Dim client As New PayPalOrdersV2Client(cfg)
        Dim details As PayPalOrdersV2Result = client.GetOrder(tx.PayPalOrderId)
        If details Is Nothing OrElse Not details.Success OrElse Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, details.Snapshot, tx.Importo, tx.Valuta) Then
            Fail(documentId, "Approvazione PayPal non verificata") : Return
        End If
        If String.Equals(details.Snapshot.CaptureStatus, "COMPLETED", StringComparison.OrdinalIgnoreCase) Then
            If PayPalCheckoutRepository.ApplyAuthoritativeState(tx, details.Snapshot, String.Empty) Then
                CloseWebLaunch(doc)
                RedirectResult(documentId, "ok")
            Else
                Fail(documentId, "Sincronizzazione pagamento non riuscita")
            End If
            Return
        End If
        If String.Equals(details.Snapshot.CaptureStatus, "PENDING", StringComparison.OrdinalIgnoreCase) Then
            If Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, details.Snapshot, String.Empty) Then Fail(documentId, "Sincronizzazione pagamento non riuscita") : Return
            CloseWebLaunch(doc)
            RedirectResult(documentId, "ko")
            Return
        End If
        If Not tx.IsCurrent Then RedirectResult(documentId, "ko") : Return
        If Not String.Equals(details.Snapshot.Status, "APPROVED", StringComparison.OrdinalIgnoreCase) Then Fail(documentId, "Ordine PayPal non approvato") : Return
        If Not PayPalCheckoutRepository.TryBeginCapture(tx) Then RedirectResult(documentId, "ko") : Return
        Dim capture As PayPalOrdersV2Result = client.CaptureOrder(tx.PayPalOrderId, tx.CaptureRequestId)
        If capture Is Nothing OrElse Not capture.Success OrElse Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, capture.Snapshot, tx.Importo, tx.Valuta) Then Fail(documentId, "Capture PayPal non verificata") : Return
        If Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, capture.Snapshot, String.Empty) Then Fail(documentId, "Aggiornamento pagamento non riuscito") : Return
        CloseWebLaunch(doc)
        If String.Equals(capture.Snapshot.CaptureStatus, "COMPLETED", StringComparison.OrdinalIgnoreCase) Then RedirectResult(documentId, "ok") Else RedirectResult(documentId, "ko")
    End Sub

    Private Sub CloseWebLaunch(ByVal doc As PayPalPaymentDocumentInfo)
        If doc Is Nothing OrElse Not String.Equals(doc.OrigineOrdine, "WEB", StringComparison.OrdinalIgnoreCase) Then Return
        Dim owner As OrderStorefrontIdentity = OrderStorefrontContext.Resolve(HttpContext.Current)
        If owner IsNot Nothing AndAlso owner.IsComplete Then PayPalWebLaunchContext.FinishPayPal(HttpContext.Current, doc.DocumentId, owner)
    End Sub

    Private Sub Fail(ByVal documentId As Integer, ByVal message As String)
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
