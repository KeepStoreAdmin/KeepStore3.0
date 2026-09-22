Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Web
Imports System.Web.Script.Serialization

Partial Class paypalwebhook
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.ContentType = "text/plain"
        If Not String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then Finish(405, "METHOD_NOT_ALLOWED") : Return
        If Not Request.IsSecureConnection OrElse Request.Url Is Nothing OrElse Not String.Equals(Request.Url.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) Then Finish(403, "HTTPS_REQUIRED") : Return
        Dim raw As String
        Using reader As New StreamReader(Request.InputStream)
            raw = reader.ReadToEnd()
        End Using
        If raw.Length = 0 OrElse raw.Length > 1048576 Then Finish(400, "INVALID_EVENT") : Return
        Dim serializer As New JavaScriptSerializer()
        Dim eventData As IDictionary(Of String, Object)
        Try
            eventData = TryCast(serializer.DeserializeObject(raw), IDictionary(Of String, Object))
        Catch
            Finish(400, "INVALID_EVENT") : Return
        End Try
        If eventData Is Nothing Then Finish(400, "INVALID_EVENT") : Return
        Dim eventId As String = SafeExternal(ReadString(eventData, "id"))
        Dim eventType As String = ReadString(eventData, "event_type").ToUpperInvariant()
        If eventId = String.Empty OrElse Not IsSupportedEvent(eventType) Then Finish(202, "IGNORED") : Return
        Dim resource As IDictionary(Of String, Object) = ReadDictionary(eventData, "resource")
        If resource Is Nothing Then Finish(400, "INVALID_RESOURCE") : Return
        Dim captureId As String = String.Empty
        Dim orderId As String = ResolveOrderId(eventType, resource, captureId)
        If orderId = String.Empty Then Finish(400, "ORDER_ID_REQUIRED") : Return
        Dim tx As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForExternalReference(If(orderId <> String.Empty, orderId, captureId))
        If tx Is Nothing OrElse Not tx.Exists Then Finish(202, "UNKNOWN_TRANSACTION") : Return
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForDocument(tx.DocumentiId)
        If cfg Is Nothing OrElse cfg.AziendeId <> tx.AziendeId OrElse cfg.AccountId <> tx.PayPalAccountId OrElse Not cfg.IsWebhookConfigured Then Finish(403, "CONFIGURATION_UNAVAILABLE") : Return
        Dim verification As PayPalWebhookVerificationResult = New PayPalOrdersV2Client(cfg).VerifyWebhookSignature(
            Request.Headers("PAYPAL-TRANSMISSION-ID"), Request.Headers("PAYPAL-TRANSMISSION-TIME"), Request.Headers("PAYPAL-CERT-URL"),
            Request.Headers("PAYPAL-AUTH-ALGO"), Request.Headers("PAYPAL-TRANSMISSION-SIG"), raw)
        If verification Is Nothing OrElse Not verification.Success Then Finish(400, "SIGNATURE_REJECTED") : Return

        If eventType = "CHECKOUT.ORDER.APPROVED" Then
            ProcessApprovedOrder(tx, cfg, eventId)
            raw = String.Empty
            Return
        End If

        If eventType = "CHECKOUT.PAYMENT-APPROVAL.REVERSED" Then
            Dim reversedDoc As PayPalPaymentDocumentInfo = PayPalPaymentState.LoadDocumentForPayment(tx.DocumentiId)
            If Not MatchesOrderResource(tx, cfg, reversedDoc, resource) Then Finish(409, "EVENT_MISMATCH") : Return
            Dim reversed As New PayPalOrderSnapshot With {.OrderId = orderId, .Status = "FAILED"}
            If Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, reversed, eventId) Then Finish(500, "STATE_UPDATE_FAILED") : Return
            raw = String.Empty
            Finish(200, "OK")
            Return
        End If

        Dim snapshot As PayPalOrderSnapshot = BuildSnapshot(resource, orderId, captureId, eventType)
        If Not MatchesTransaction(tx, cfg, snapshot) Then Finish(409, "EVENT_MISMATCH") : Return
        If Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, snapshot, eventId) Then Finish(500, "STATE_UPDATE_FAILED") : Return
        raw = String.Empty
        Finish(200, "OK")
    End Sub

    Private Sub ProcessApprovedOrder(ByVal tx As PayPalCheckoutTransactionInfo,
                                     ByVal cfg As PayPalCheckoutConfig,
                                     ByVal eventId As String)
        Dim doc As PayPalPaymentDocumentInfo = PayPalPaymentState.LoadDocumentForPayment(tx.DocumentiId)
        If doc Is Nothing OrElse Not doc.Exists OrElse doc.AziendeId <> tx.AziendeId OrElse doc.PagamentiTipoId <> tx.PagamentiTipoId Then Finish(409, "DOCUMENT_MISMATCH") : Return
        Dim client As New PayPalOrdersV2Client(cfg)
        Dim details As PayPalOrdersV2Result = client.GetOrder(tx.PayPalOrderId)
        If details Is Nothing OrElse Not details.Success OrElse Not PayPalOrdersV2Client.ValidateSnapshot(doc, cfg, tx.PayPalOrderId, details.Snapshot) Then Finish(409, "ORDER_MISMATCH") : Return
        Dim authoritative As PayPalOrderSnapshot = details.Snapshot
        If Not String.Equals(authoritative.CaptureStatus, "COMPLETED", StringComparison.OrdinalIgnoreCase) AndAlso
           Not String.Equals(authoritative.CaptureStatus, "PENDING", StringComparison.OrdinalIgnoreCase) Then
            If Not String.Equals(authoritative.Status, "APPROVED", StringComparison.OrdinalIgnoreCase) Then Finish(409, "ORDER_NOT_APPROVED") : Return
            Dim capture As PayPalOrdersV2Result = client.CaptureOrder(tx.PayPalOrderId, tx.CaptureRequestId)
            If capture Is Nothing OrElse Not capture.Success OrElse Not PayPalOrdersV2Client.ValidateSnapshot(doc, cfg, tx.PayPalOrderId, capture.Snapshot) Then Finish(409, "CAPTURE_MISMATCH") : Return
            authoritative = capture.Snapshot
        End If
        If Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, authoritative, eventId) Then Finish(500, "STATE_UPDATE_FAILED") : Return
        Finish(200, "OK")
    End Sub

    Private Shared Function IsSupportedEvent(ByVal eventType As String) As Boolean
        Return eventType = "CHECKOUT.ORDER.APPROVED" OrElse eventType = "CHECKOUT.PAYMENT-APPROVAL.REVERSED" OrElse
               eventType = "PAYMENT.CAPTURE.COMPLETED" OrElse eventType = "PAYMENT.CAPTURE.PENDING" OrElse eventType = "PAYMENT.CAPTURE.DENIED"
    End Function

    Private Shared Function ResolveOrderId(ByVal eventType As String,
                                           ByVal resource As IDictionary(Of String, Object),
                                           ByRef captureId As String) As String
        If eventType = "CHECKOUT.ORDER.APPROVED" Then Return SafeExternal(ReadString(resource, "id"))
        If eventType = "CHECKOUT.PAYMENT-APPROVAL.REVERSED" Then Return SafeExternal(ReadString(resource, "order_id"))
        captureId = SafeExternal(ReadString(resource, "id"))
        Dim related As IDictionary(Of String, Object) = ReadDictionary(ReadDictionary(resource, "supplementary_data"), "related_ids")
        Return SafeExternal(ReadString(related, "order_id"))
    End Function

    Private Shared Function MatchesOrderResource(ByVal tx As PayPalCheckoutTransactionInfo,
                                                  ByVal cfg As PayPalCheckoutConfig,
                                                  ByVal doc As PayPalPaymentDocumentInfo,
                                                  ByVal resource As IDictionary(Of String, Object)) As Boolean
        If tx Is Nothing OrElse cfg Is Nothing OrElse doc Is Nothing OrElse Not doc.Exists OrElse
           tx.AziendeId <> cfg.AziendeId OrElse tx.AziendeId <> doc.AziendeId OrElse tx.PagamentiTipoId <> doc.PagamentiTipoId OrElse
           Not String.Equals(SafeExternal(ReadString(resource, "order_id")), tx.PayPalOrderId, StringComparison.Ordinal) Then Return False
        Dim units As IList = ReadList(resource, "purchase_units")
        If units Is Nothing OrElse units.Count <> 1 Then Return False
        Dim unit As IDictionary(Of String, Object) = TryCast(units(0), IDictionary(Of String, Object))
        Return unit IsNot Nothing AndAlso
               String.Equals(ReadString(unit, "reference_id"), PayPalOrdersV2Client.ExpectedReferenceId(doc), StringComparison.Ordinal) AndAlso
               String.Equals(ReadString(unit, "custom_id"), PayPalOrdersV2Client.ExpectedCustomId(doc), StringComparison.Ordinal) AndAlso
               String.Equals(ReadString(unit, "invoice_id"), PayPalOrdersV2Client.ExpectedInvoiceId(doc), StringComparison.Ordinal)
    End Function

    Private Shared Function BuildSnapshot(ByVal resource As IDictionary(Of String, Object), ByVal orderId As String, ByVal captureId As String, ByVal eventType As String) As PayPalOrderSnapshot
        Dim amount As IDictionary(Of String, Object) = ReadDictionary(resource, "amount")
        Dim payee As IDictionary(Of String, Object) = ReadDictionary(resource, "payee")
        Dim value As Decimal = 0D
        Decimal.TryParse(ReadString(amount, "value"), NumberStyles.Number, CultureInfo.InvariantCulture, value)
        Dim state As String = If(eventType.EndsWith("COMPLETED", StringComparison.Ordinal), "COMPLETED", If(eventType.EndsWith("PENDING", StringComparison.Ordinal), "PENDING", "DENIED"))
        Return New PayPalOrderSnapshot With {.OrderId = orderId, .CaptureId = captureId, .CaptureStatus = state, .Amount = value,
            .CurrencyCode = ReadString(amount, "currency_code"), .PayeeEmail = ReadString(payee, "email_address"), .MerchantId = ReadString(payee, "merchant_id")}
    End Function

    Private Shared Function MatchesTransaction(ByVal tx As PayPalCheckoutTransactionInfo, ByVal cfg As PayPalCheckoutConfig, ByVal snapshot As PayPalOrderSnapshot) As Boolean
        Return snapshot IsNot Nothing AndAlso snapshot.OrderId = tx.PayPalOrderId AndAlso snapshot.Amount = Math.Round(tx.Importo, 2, MidpointRounding.AwayFromZero) AndAlso
            String.Equals(snapshot.CurrencyCode, tx.Valuta, StringComparison.OrdinalIgnoreCase) AndAlso
            String.Equals(snapshot.PayeeEmail, tx.PayeeEmail, StringComparison.OrdinalIgnoreCase) AndAlso
            String.Equals(snapshot.MerchantId, tx.MerchantId, StringComparison.Ordinal) AndAlso
            String.Equals(cfg.PayeeEmail, tx.PayeeEmail, StringComparison.OrdinalIgnoreCase) AndAlso String.Equals(cfg.MerchantId, tx.MerchantId, StringComparison.Ordinal)
    End Function

    Private Shared Function ReadDictionary(ByVal data As IDictionary(Of String, Object), ByVal key As String) As IDictionary(Of String, Object)
        If data Is Nothing OrElse Not data.ContainsKey(key) Then Return Nothing
        Return TryCast(data(key), IDictionary(Of String, Object))
    End Function

    Private Shared Function ReadList(ByVal data As IDictionary(Of String, Object), ByVal key As String) As IList
        If data Is Nothing OrElse Not data.ContainsKey(key) Then Return Nothing
        Return TryCast(data(key), IList)
    End Function

    Private Shared Function ReadString(ByVal data As IDictionary(Of String, Object), ByVal key As String) As String
        If data Is Nothing OrElse Not data.ContainsKey(key) OrElse data(key) Is Nothing Then Return String.Empty
        Return Convert.ToString(data(key), CultureInfo.InvariantCulture).Trim()
    End Function

    Private Shared Function SafeExternal(ByVal value As String) As String
        Return PayPalPaymentState.SanitizeExternalId(value)
    End Function

    Private Sub Finish(ByVal statusCode As Integer, ByVal value As String)
        Response.StatusCode = statusCode
        Response.Write(value)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
