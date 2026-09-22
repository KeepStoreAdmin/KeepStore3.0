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
        Dim owner As OrderStorefrontIdentity = OrderStorefrontContext.Resolve(HttpContext.Current)
        If owner Is Nothing OrElse Not owner.IsComplete OrElse owner.UtentiId <> utentiId Then RedirectTerminal("accessonegato.aspx") : Return
        Dim doc As PayPalPaymentDocumentInfo = PayPalPaymentState.LoadDocumentForUser(documentId, utentiId)
        If doc Is Nothing OrElse Not doc.Exists Then RedirectTerminal("accessonegato.aspx") : Return
        If doc.Pagato = 1 Then RedirectResult(documentId, "ok") : Return
        If doc.PaymentOnline <> PayPalPaymentState.PAYPAL_ONLINE_VALUE OrElse doc.TotalDocument <= 0D Then Fail(documentId, "Documento non idoneo al pagamento PayPal") : Return
        Dim isWeb As Boolean = String.Equals(doc.OrigineOrdine, "WEB", StringComparison.OrdinalIgnoreCase)
        If isWeb Then
            If Not PayPalWebLaunchContext.BeginPayPal(HttpContext.Current, documentId, owner) Then RedirectTerminal("accessonegato.aspx") : Return
        ElseIf Not InternalOrderRemotePaymentPolicy.CanPayNow(doc.OrigineOrdine, True, doc.AziendeId = owner.CompanyId,
            doc.ValidOrderType, doc.Pagato, doc.DocumentState, doc.PaymentState, doc.PaymentOnline,
            doc.AllowLaterPayment, doc.HasGatewayAuthorization, doc.TotalDocument) Then
            RedirectTerminal("accessonegato.aspx") : Return
        End If
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForDocument(documentId)
        If cfg Is Nothing OrElse cfg.AziendeId <> doc.AziendeId OrElse cfg.PagamentiTipoId <> doc.PagamentiTipoId OrElse Not PayPalCheckoutSafetyPolicy.CanUseLiveCheckout(HttpContext.Current, cfg) Then
            Fail(documentId, "Configurazione PayPal Checkout non disponibile") : Return
        End If
        Dim client As New PayPalOrdersV2Client(cfg)
        Dim tx As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.EnsureTransaction(doc, cfg)
        If tx Is Nothing OrElse Not tx.Exists OrElse Not tx.IsCurrent OrElse tx.AziendeId <> doc.AziendeId OrElse
           tx.PagamentiTipoId <> doc.PagamentiTipoId OrElse tx.PayPalAccountId <> cfg.AccountId OrElse
           tx.Importo <> Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero) OrElse
           Not String.Equals(tx.Valuta, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) OrElse
           Not String.Equals(tx.PayeeEmail, cfg.PayeeEmail, StringComparison.OrdinalIgnoreCase) OrElse
           Not String.Equals(tx.MerchantId, cfg.MerchantId, StringComparison.Ordinal) Then
            Fail(documentId, "Impossibile inizializzare il pagamento PayPal") : Return
        End If
        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(HttpContext.Current)
        Dim returnUrl As String = StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenant, "/paypalreturn.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&action=return")
        Dim cancelUrl As String = StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenant, "/paypalreturn.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&action=cancel")
        If String.IsNullOrWhiteSpace(returnUrl) OrElse String.IsNullOrWhiteSpace(cancelUrl) Then Fail(documentId, "Host PayPal Checkout non valido") : Return
        If isWeb AndAlso Not PayPalWebLaunchContext.BindPayPalAttempt(HttpContext.Current, documentId, owner,
            tx.TentativoNo, tx.CreateRequestId, client.BuildCreateOrderPayload(doc, returnUrl, cancelUrl)) Then
            RedirectTerminal("accessonegato.aspx") : Return
        End If
        If Not String.IsNullOrWhiteSpace(tx.PayPalOrderId) Then
            Dim details As PayPalOrdersV2Result = client.GetOrder(tx.PayPalOrderId)
            If details Is Nothing OrElse Not details.Success OrElse
               Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, details.Snapshot, tx.Importo, tx.Valuta) Then
                Fail(documentId, "Riconciliazione PayPal non disponibile") : Return
            End If
            If String.Equals(details.Snapshot.CaptureStatus, "COMPLETED", StringComparison.OrdinalIgnoreCase) Then
                If PayPalCheckoutRepository.ApplyAuthoritativeState(tx, details.Snapshot, String.Empty) Then
                    If isWeb Then PayPalWebLaunchContext.FinishPayPal(HttpContext.Current, documentId, owner)
                    RedirectResult(documentId, "ok")
                Else
                    Fail(documentId, "Sincronizzazione pagamento non riuscita")
                End If
                Return
            End If
            If String.Equals(details.Snapshot.CaptureStatus, "PENDING", StringComparison.OrdinalIgnoreCase) Then
                If Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, details.Snapshot, String.Empty) Then Fail(documentId, "Sincronizzazione pagamento non riuscita") : Return
                If isWeb Then PayPalWebLaunchContext.FinishPayPal(HttpContext.Current, documentId, owner)
                RedirectResult(documentId, "ko") : Return
            End If
            If String.Equals(details.Snapshot.Status, "APPROVED", StringComparison.OrdinalIgnoreCase) Then
                If Not PayPalCheckoutRepository.TryBeginCapture(tx) Then Fail(documentId, "Capture PayPal non disponibile") : Return
                Dim captured As PayPalOrdersV2Result = client.CaptureOrder(tx.PayPalOrderId, tx.CaptureRequestId)
                If captured Is Nothing OrElse Not captured.Success OrElse
                   Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc, cfg, tx.PayPalOrderId, captured.Snapshot, tx.Importo, tx.Valuta) OrElse
                   Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, captured.Snapshot, String.Empty) Then
                    Fail(documentId, "Verifica capture PayPal non riuscita") : Return
                End If
                If isWeb Then PayPalWebLaunchContext.FinishPayPal(HttpContext.Current, documentId, owner)
                RedirectResult(documentId, If(String.Equals(captured.Snapshot.CaptureStatus, "COMPLETED", StringComparison.OrdinalIgnoreCase), "ok", "ko")) : Return
            End If
            If Not isWeb AndAlso (String.Equals(tx.Stato, "CANCELED", StringComparison.OrdinalIgnoreCase) OrElse
                                   String.Equals(tx.Stato, "FAILED", StringComparison.OrdinalIgnoreCase) OrElse
                                   String.Equals(tx.Stato, "DENIED", StringComparison.OrdinalIgnoreCase) OrElse
                                   String.Equals(tx.Stato, "DECLINED", StringComparison.OrdinalIgnoreCase) OrElse
                                   String.Equals(tx.Stato, "VOIDED", StringComparison.OrdinalIgnoreCase) OrElse
                                   String.Equals(details.Snapshot.Status, "VOIDED", StringComparison.OrdinalIgnoreCase)) Then
                tx = PayPalCheckoutRepository.StartNextAttempt(doc, cfg, tx, details.Snapshot)
                If tx Is Nothing OrElse Not tx.Exists OrElse Not tx.IsCurrent Then Fail(documentId, "Nuovo tentativo PayPal non disponibile") : Return
                If Not String.IsNullOrWhiteSpace(tx.PayPalOrderId) Then Fail(documentId, "Tentativo PayPal concorrente in corso") : Return
            ElseIf PayPalCheckoutSafetyPolicy.IsTrustedApprovalUrl(details.Snapshot.ApprovalUrl) Then
                ' La risposta HTTP del redirect potrebbe perdersi: per pochi minuti
                ' e consentito soltanto recuperare questo stesso order/attempt.
                RedirectTerminal(details.Snapshot.ApprovalUrl) : Return
            Else
                Fail(documentId, "Ordine PayPal non riutilizzabile") : Return
            End If
        End If
        Dim response As PayPalOrdersV2Result = client.CreateOrder(doc, tx.CreateRequestId, returnUrl, cancelUrl)
        If response Is Nothing OrElse Not response.Success OrElse Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc, cfg, response.Snapshot.OrderId, response.Snapshot, tx.Importo, tx.Valuta) OrElse Not PayPalCheckoutSafetyPolicy.IsTrustedApprovalUrl(response.Snapshot.ApprovalUrl) Then
            Fail(documentId, "Creazione pagamento PayPal non riuscita") : Return
        End If
        If Not PayPalCheckoutRepository.RecordOrderCreated(tx, response.Snapshot) Then Fail(documentId, "Persistenza pagamento PayPal non riuscita") : Return
        RedirectTerminal(response.Snapshot.ApprovalUrl)
    End Sub

    Private Sub Fail(ByVal documentId As Integer, ByVal message As String)
        ' Un errore di trasporto puo avere un esito remoto ambiguo: non dichiararlo
        ' fallito e non sbloccare un nuovo attempt senza GET autorevole.
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
