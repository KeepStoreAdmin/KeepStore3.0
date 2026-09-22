Imports System
Imports System.Globalization
Imports System.Web

Partial Class paypalcheckout
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If IsPostBack Then Return
        Dim documentId As Integer = QueryInt("id")
        Dim utentiId As Integer = PayPalPaymentState.GetSessionInt("UtentiId", 0)
        If PayPalPaymentState.GetSessionInt("LoginId", 0) <= 0 OrElse utentiId <= 0 Then RedirectTerminal("login.aspx") : Return
        Dim doc As PayPalPaymentDocumentInfo = PayPalPaymentState.LoadDocumentForUser(documentId, utentiId)
        If doc Is Nothing OrElse Not doc.Exists Then RedirectTerminal("accessonegato.aspx") : Return
        If doc.Pagato = 1 Then RedirectResult(documentId, "ok") : Return
        If doc.PaymentOnline <> PayPalPaymentState.PAYPAL_ONLINE_VALUE OrElse doc.TotalDocument <= 0D Then Fail(documentId, "Documento non idoneo al pagamento PayPal") : Return
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForDocument(documentId)
        If cfg Is Nothing OrElse cfg.AziendeId <> doc.AziendeId OrElse cfg.PagamentiTipoId <> doc.PagamentiTipoId OrElse Not PayPalCheckoutSafetyPolicy.CanUseLiveCheckout(HttpContext.Current, cfg) Then
            Fail(documentId, "Configurazione PayPal Checkout non disponibile") : Return
        End If
        Dim tx As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.EnsureTransaction(doc, cfg)
        If tx Is Nothing OrElse Not tx.Exists OrElse tx.AziendeId <> doc.AziendeId OrElse tx.PayPalAccountId <> cfg.AccountId Then
            Fail(documentId, "Impossibile inizializzare il pagamento PayPal") : Return
        End If
        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(HttpContext.Current)
        Dim returnUrl As String = StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenant, "/paypalreturn.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&action=return")
        Dim cancelUrl As String = StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenant, "/paypalreturn.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&action=cancel")
        If String.IsNullOrWhiteSpace(returnUrl) OrElse String.IsNullOrWhiteSpace(cancelUrl) Then Fail(documentId, "Host PayPal Checkout non valido") : Return
        Dim response As PayPalOrdersV2Result = New PayPalOrdersV2Client(cfg).CreateOrder(doc, tx.CreateRequestId, returnUrl, cancelUrl)
        If response Is Nothing OrElse Not response.Success OrElse Not PayPalOrdersV2Client.ValidateSnapshot(doc, cfg, response.Snapshot.OrderId, response.Snapshot) OrElse Not PayPalCheckoutSafetyPolicy.IsTrustedApprovalUrl(response.Snapshot.ApprovalUrl) Then
            Fail(documentId, "Creazione pagamento PayPal non riuscita") : Return
        End If
        If Not PayPalCheckoutRepository.RecordOrderCreated(tx, response.Snapshot) Then Fail(documentId, "Persistenza pagamento PayPal non riuscita") : Return
        RedirectTerminal(response.Snapshot.ApprovalUrl)
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
