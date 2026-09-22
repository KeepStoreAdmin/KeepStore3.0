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
        If eventId = String.Empty OrElse (eventType <> "PAYMENT.CAPTURE.COMPLETED" AndAlso eventType <> "PAYMENT.CAPTURE.PENDING" AndAlso eventType <> "PAYMENT.CAPTURE.DENIED") Then Finish(202, "IGNORED") : Return
        Dim resource As IDictionary(Of String, Object) = ReadDictionary(eventData, "resource")
        Dim captureId As String = SafeExternal(ReadString(resource, "id"))
        Dim related As IDictionary(Of String, Object) = ReadDictionary(ReadDictionary(resource, "supplementary_data"), "related_ids")
        Dim orderId As String = SafeExternal(ReadString(related, "order_id"))
        Dim tx As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForExternalReference(If(orderId <> String.Empty, orderId, captureId))
        If tx Is Nothing OrElse Not tx.Exists Then Finish(202, "UNKNOWN_TRANSACTION") : Return
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForDocument(tx.DocumentiId)
        If cfg Is Nothing OrElse cfg.AziendeId <> tx.AziendeId OrElse cfg.AccountId <> tx.PayPalAccountId OrElse Not cfg.IsWebhookConfigured Then Finish(403, "CONFIGURATION_UNAVAILABLE") : Return
        Dim verification As PayPalWebhookVerificationResult = New PayPalOrdersV2Client(cfg).VerifyWebhookSignature(
            Request.Headers("PAYPAL-TRANSMISSION-ID"), Request.Headers("PAYPAL-TRANSMISSION-TIME"), Request.Headers("PAYPAL-CERT-URL"),
            Request.Headers("PAYPAL-AUTH-ALGO"), Request.Headers("PAYPAL-TRANSMISSION-SIG"), eventData)
        If verification Is Nothing OrElse Not verification.Success Then Finish(400, "SIGNATURE_REJECTED") : Return
        Dim snapshot As PayPalOrderSnapshot = BuildSnapshot(resource, orderId, captureId, eventType)
        If Not MatchesTransaction(tx, cfg, snapshot) Then Finish(409, "EVENT_MISMATCH") : Return
        If Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, snapshot, eventId) Then Finish(500, "STATE_UPDATE_FAILED") : Return
        raw = String.Empty
        Finish(200, "OK")
    End Sub

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
