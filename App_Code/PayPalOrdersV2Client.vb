Option Strict On
Option Explicit On

Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Net
Imports System.Text
Imports System.Web.Script.Serialization

Public Class PayPalHttpRequestData
    Public Property Method As String
    Public Property Url As String
    Public Property ContentType As String
    Public Property Authorization As String
    Public Property RequestId As String
    Public Property Body As String
End Class

Public Class PayPalHttpResponseData
    Public Property StatusCode As Integer
    Public Property Body As String
End Class

Public Interface IPayPalHttpTransport
    Function Send(ByVal request As PayPalHttpRequestData) As PayPalHttpResponseData
End Interface

Public Class PayPalHttpWebRequestTransport
    Implements IPayPalHttpTransport

    Public Function Send(ByVal data As PayPalHttpRequestData) As PayPalHttpResponseData Implements IPayPalHttpTransport.Send
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
        Dim request As HttpWebRequest = DirectCast(WebRequest.Create(data.Url), HttpWebRequest)
        request.Method = data.Method
        request.ContentType = data.ContentType
        request.Accept = "application/json"
        request.Timeout = 20000
        request.ReadWriteTimeout = 20000
        request.AllowAutoRedirect = False
        If Not String.IsNullOrWhiteSpace(data.Authorization) Then request.Headers(HttpRequestHeader.Authorization) = data.Authorization
        If Not String.IsNullOrWhiteSpace(data.RequestId) Then request.Headers("PayPal-Request-Id") = data.RequestId
        If Not String.IsNullOrEmpty(data.Body) Then
            Dim bytes() As Byte = Encoding.UTF8.GetBytes(data.Body)
            request.ContentLength = bytes.Length
            Using stream As Stream = request.GetRequestStream()
                stream.Write(bytes, 0, bytes.Length)
            End Using
        End If
        Try
            Using response As HttpWebResponse = DirectCast(request.GetResponse(), HttpWebResponse)
                Return ReadResponse(response)
            End Using
        Catch ex As WebException
            Dim response As HttpWebResponse = TryCast(ex.Response, HttpWebResponse)
            If response Is Nothing Then Return New PayPalHttpResponseData With {.StatusCode = 0, .Body = String.Empty}
            Using response
                Return ReadResponse(response)
            End Using
        End Try
    End Function

    Private Shared Function ReadResponse(ByVal response As HttpWebResponse) As PayPalHttpResponseData
        Dim body As String = String.Empty
        Using stream As Stream = response.GetResponseStream()
            If stream IsNot Nothing Then
                Using reader As New StreamReader(stream, Encoding.UTF8)
                    body = reader.ReadToEnd()
                End Using
            End If
        End Using
        Return New PayPalHttpResponseData With {.StatusCode = CInt(response.StatusCode), .Body = body}
    End Function
End Class

Public Class PayPalOrderSnapshot
    Public Property OrderId As String
    Public Property Status As String
    Public Property Intent As String
    Public Property ReferenceId As String
    Public Property CustomId As String
    Public Property InvoiceId As String
    Public Property Amount As Decimal
    Public Property CurrencyCode As String
    Public Property PayeeEmail As String
    Public Property MerchantId As String
    Public Property CaptureId As String
    Public Property CaptureStatus As String
    Public Property ApprovalUrl As String
End Class

Public Class PayPalOrdersV2Result
    Public Property Success As Boolean
    Public Property StatusCode As Integer
    Public Property ErrorCode As String
    Public Property Snapshot As PayPalOrderSnapshot
End Class

Public Class PayPalAccessTokenResult
    Public Property Success As Boolean
    Public Property StatusCode As Integer
    Public Property AccessToken As String
    Public Property ErrorCode As String
End Class

Public Class PayPalWebhookVerificationResult
    Public Property Success As Boolean
    Public Property StatusCode As Integer
    Public Property VerificationStatus As String
    Public Property ErrorCode As String
End Class

Public Class PayPalOrdersV2Client
    Private ReadOnly _config As PayPalCheckoutConfig
    Private ReadOnly _transport As IPayPalHttpTransport
    Private ReadOnly _serializer As New JavaScriptSerializer()

    Public Sub New(ByVal config As PayPalCheckoutConfig)
        Me.New(config, New PayPalHttpWebRequestTransport())
    End Sub

    Public Sub New(ByVal config As PayPalCheckoutConfig, ByVal transport As IPayPalHttpTransport)
        _config = config
        _transport = transport
    End Sub

    Public Function GetAccessToken() As PayPalAccessTokenResult
        Dim result As New PayPalAccessTokenResult()
        If _config Is Nothing OrElse Not _config.IsConfigured OrElse _transport Is Nothing Then
            result.ErrorCode = "CONFIGURATION_UNAVAILABLE"
            Return result
        End If
        Dim basic As String = Convert.ToBase64String(Encoding.UTF8.GetBytes(_config.ClientId & ":" & _config.ClientSecret))
        Dim response As PayPalHttpResponseData = SafeSend(New PayPalHttpRequestData With {
            .Method = "POST", .Url = PayPalCheckoutConfig.LiveApiBaseUrl & "/v1/oauth2/token",
            .ContentType = "application/x-www-form-urlencoded", .Authorization = "Basic " & basic,
            .Body = "grant_type=client_credentials"})
        result.StatusCode = response.StatusCode
        If response.StatusCode = 200 Then
            result.AccessToken = ReadString(Parse(response.Body), "access_token")
            result.Success = Not String.IsNullOrWhiteSpace(result.AccessToken)
        End If
        If Not result.Success Then result.ErrorCode = ReadSafeError(response.Body, "OAUTH_FAILED")
        Return result
    End Function

    Public Function CreateOrder(ByVal doc As PayPalPaymentDocumentInfo,
                                ByVal requestId As String,
                                ByVal returnUrl As String,
                                ByVal cancelUrl As String) As PayPalOrdersV2Result
        If doc Is Nothing Then Return Failure("DOCUMENT_REQUIRED")
        Dim unit As New Dictionary(Of String, Object) From {
            {"reference_id", ExpectedReferenceId(doc)},
            {"custom_id", ExpectedCustomId(doc)},
            {"invoice_id", ExpectedInvoiceId(doc)},
            {"amount", New Dictionary(Of String, Object) From {{"currency_code", _config.CurrencyCode}, {"value", Money(doc.TotalDocument)}}},
            {"payee", New Dictionary(Of String, Object) From {{"email_address", _config.PayeeEmail}}}
        }
        Dim experience As New Dictionary(Of String, Object) From {
            {"brand_name", _config.BrandName}, {"return_url", returnUrl}, {"cancel_url", cancelUrl}, {"user_action", "PAY_NOW"}
        }
        Dim payload As New Dictionary(Of String, Object) From {
            {"intent", "CAPTURE"},
            {"purchase_units", New Object() {unit}},
            {"payment_source", New Dictionary(Of String, Object) From {{"paypal", New Dictionary(Of String, Object) From {{"experience_context", experience}}}}}
        }
        Return SendOrder("POST", "/v2/checkout/orders", requestId, _serializer.Serialize(payload), 201)
    End Function

    Public Function GetOrder(ByVal orderId As String) As PayPalOrdersV2Result
        If Not IsExternalIdValid(orderId) Then Return Failure("ORDER_ID_INVALID")
        Return SendOrder("GET", "/v2/checkout/orders/" & Uri.EscapeDataString(orderId), String.Empty, String.Empty, 200)
    End Function

    Public Function CaptureOrder(ByVal orderId As String, ByVal requestId As String) As PayPalOrdersV2Result
        If Not IsExternalIdValid(orderId) Then Return Failure("ORDER_ID_INVALID")
        Return SendOrder("POST", "/v2/checkout/orders/" & Uri.EscapeDataString(orderId) & "/capture", requestId, "{}", 201)
    End Function

    Public Function VerifyWebhookSignature(ByVal transmissionId As String,
                                           ByVal transmissionTime As String,
                                           ByVal certUrl As String,
                                           ByVal authAlgo As String,
                                           ByVal transmissionSignature As String,
                                           ByVal webhookEvent As Object) As PayPalWebhookVerificationResult
        Dim result As New PayPalWebhookVerificationResult()
        If _config Is Nothing OrElse Not _config.IsWebhookConfigured Then result.ErrorCode = "WEBHOOK_CONFIGURATION_UNAVAILABLE" : Return result
        Dim token As PayPalAccessTokenResult = GetAccessToken()
        If Not token.Success Then result.ErrorCode = token.ErrorCode : Return result
        Dim payload As New Dictionary(Of String, Object) From {
            {"transmission_id", transmissionId}, {"transmission_time", transmissionTime}, {"cert_url", certUrl},
            {"auth_algo", authAlgo}, {"transmission_sig", transmissionSignature}, {"webhook_id", _config.WebhookId},
            {"webhook_event", webhookEvent}
        }
        Dim response As PayPalHttpResponseData = SafeSend(New PayPalHttpRequestData With {
            .Method = "POST", .Url = PayPalCheckoutConfig.LiveApiBaseUrl & "/v1/notifications/verify-webhook-signature",
            .ContentType = "application/json", .Authorization = "Bearer " & token.AccessToken,
            .Body = _serializer.Serialize(payload)})
        result.StatusCode = response.StatusCode
        result.VerificationStatus = ReadString(Parse(response.Body), "verification_status").ToUpperInvariant()
        result.Success = response.StatusCode = 200 AndAlso result.VerificationStatus = "SUCCESS"
        If Not result.Success Then result.ErrorCode = ReadSafeError(response.Body, "WEBHOOK_VERIFICATION_FAILED")
        Return result
    End Function

    Public Shared Function ExpectedReferenceId(ByVal doc As PayPalPaymentDocumentInfo) As String
        Return "KS-" & doc.AziendeId.ToString(CultureInfo.InvariantCulture) & "-" & doc.DocumentId.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Shared Function ExpectedCustomId(ByVal doc As PayPalPaymentDocumentInfo) As String
        Return "KS-DOC-" & doc.AziendeId.ToString(CultureInfo.InvariantCulture) & "-" & doc.DocumentId.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Shared Function ExpectedInvoiceId(ByVal doc As PayPalPaymentDocumentInfo) As String
        Return "KS-INV-" & doc.AziendeId.ToString(CultureInfo.InvariantCulture) & "-" & doc.DocumentId.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Shared Function ValidateSnapshot(ByVal doc As PayPalPaymentDocumentInfo,
                                            ByVal cfg As PayPalCheckoutConfig,
                                            ByVal expectedOrderId As String,
                                            ByVal snapshot As PayPalOrderSnapshot) As Boolean
        If doc Is Nothing OrElse cfg Is Nothing OrElse snapshot Is Nothing Then Return False
        Return cfg.AziendeId = doc.AziendeId AndAlso cfg.PagamentiTipoId = doc.PagamentiTipoId AndAlso
               String.Equals(snapshot.OrderId, expectedOrderId, StringComparison.Ordinal) AndAlso
               String.Equals(snapshot.Intent, "CAPTURE", StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(snapshot.ReferenceId, ExpectedReferenceId(doc), StringComparison.Ordinal) AndAlso
               String.Equals(snapshot.CustomId, ExpectedCustomId(doc), StringComparison.Ordinal) AndAlso
               String.Equals(snapshot.InvoiceId, ExpectedInvoiceId(doc), StringComparison.Ordinal) AndAlso
               snapshot.Amount = Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero) AndAlso
               String.Equals(snapshot.CurrencyCode, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(snapshot.PayeeEmail, cfg.PayeeEmail, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(snapshot.MerchantId, cfg.MerchantId, StringComparison.Ordinal)
    End Function

    Private Function SendOrder(ByVal method As String, ByVal path As String, ByVal requestId As String, ByVal body As String, ByVal expectedStatus As Integer) As PayPalOrdersV2Result
        Dim token As PayPalAccessTokenResult = GetAccessToken()
        If Not token.Success Then Return Failure(token.ErrorCode)
        Dim response As PayPalHttpResponseData = SafeSend(New PayPalHttpRequestData With {
            .Method = method, .Url = PayPalCheckoutConfig.LiveApiBaseUrl & path, .ContentType = "application/json",
            .Authorization = "Bearer " & token.AccessToken, .RequestId = requestId, .Body = body})
        Dim result As New PayPalOrdersV2Result With {.StatusCode = response.StatusCode, .Snapshot = ParseSnapshot(response.Body)}
        Dim acceptedStatus As Boolean = response.StatusCode = expectedStatus OrElse (expectedStatus = 201 AndAlso response.StatusCode = 200)
        result.Success = acceptedStatus AndAlso result.Snapshot IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(result.Snapshot.OrderId)
        If Not result.Success Then result.ErrorCode = ReadSafeError(response.Body, "PAYPAL_API_FAILED")
        Return result
    End Function

    Private Function SafeSend(ByVal request As PayPalHttpRequestData) As PayPalHttpResponseData
        Try
            Return _transport.Send(request)
        Catch ex As Exception
            Return New PayPalHttpResponseData With {.StatusCode = 0, .Body = String.Empty}
        End Try
    End Function

    Private Function ParseSnapshot(ByVal json As String) As PayPalOrderSnapshot
        Dim root As IDictionary(Of String, Object) = Parse(json)
        If root Is Nothing Then Return Nothing
        Dim snapshot As New PayPalOrderSnapshot With {
            .OrderId = ReadString(root, "id"), .Status = ReadString(root, "status"), .Intent = ReadString(root, "intent")}
        Dim units As IList = ReadList(root, "purchase_units")
        If units IsNot Nothing AndAlso units.Count > 0 Then
            Dim unit As IDictionary(Of String, Object) = AsDictionary(units(0))
            snapshot.ReferenceId = ReadString(unit, "reference_id")
            snapshot.CustomId = ReadString(unit, "custom_id")
            snapshot.InvoiceId = ReadString(unit, "invoice_id")
            ReadAmount(ReadDictionary(unit, "amount"), snapshot.Amount, snapshot.CurrencyCode)
            Dim payee As IDictionary(Of String, Object) = ReadDictionary(unit, "payee")
            snapshot.PayeeEmail = ReadString(payee, "email_address")
            snapshot.MerchantId = ReadString(payee, "merchant_id")
            Dim payments As IDictionary(Of String, Object) = ReadDictionary(unit, "payments")
            Dim captures As IList = ReadList(payments, "captures")
            If captures IsNot Nothing AndAlso captures.Count > 0 Then
                Dim capture As IDictionary(Of String, Object) = AsDictionary(captures(0))
                snapshot.CaptureId = ReadString(capture, "id")
                snapshot.CaptureStatus = ReadString(capture, "status")
                Dim captureAmount As Decimal = 0D
                Dim captureCurrency As String = String.Empty
                ReadAmount(ReadDictionary(capture, "amount"), captureAmount, captureCurrency)
                If captureAmount > 0D Then snapshot.Amount = captureAmount
                If captureCurrency <> String.Empty Then snapshot.CurrencyCode = captureCurrency
            End If
        End If
        Dim links As IList = ReadList(root, "links")
        If links IsNot Nothing Then
            For Each item As Object In links
                Dim link As IDictionary(Of String, Object) = AsDictionary(item)
                Dim rel As String = ReadString(link, "rel")
                If String.Equals(rel, "payer-action", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(rel, "approve", StringComparison.OrdinalIgnoreCase) Then
                    snapshot.ApprovalUrl = ReadString(link, "href")
                    Exit For
                End If
            Next
        End If
        Return snapshot
    End Function

    Private Function Parse(ByVal json As String) As IDictionary(Of String, Object)
        Try
            Return AsDictionary(_serializer.DeserializeObject(Convert.ToString(json)))
        Catch
            Return Nothing
        End Try
    End Function

    Private Shared Function AsDictionary(ByVal value As Object) As IDictionary(Of String, Object)
        Return TryCast(value, IDictionary(Of String, Object))
    End Function

    Private Shared Function ReadDictionary(ByVal data As IDictionary(Of String, Object), ByVal key As String) As IDictionary(Of String, Object)
        If data Is Nothing OrElse Not data.ContainsKey(key) Then Return Nothing
        Return AsDictionary(data(key))
    End Function

    Private Shared Function ReadList(ByVal data As IDictionary(Of String, Object), ByVal key As String) As IList
        If data Is Nothing OrElse Not data.ContainsKey(key) Then Return Nothing
        Return TryCast(data(key), IList)
    End Function

    Private Shared Function ReadString(ByVal data As IDictionary(Of String, Object), ByVal key As String) As String
        If data Is Nothing OrElse Not data.ContainsKey(key) OrElse data(key) Is Nothing Then Return String.Empty
        Return Convert.ToString(data(key), CultureInfo.InvariantCulture).Trim()
    End Function

    Private Shared Sub ReadAmount(ByVal amount As IDictionary(Of String, Object), ByRef value As Decimal, ByRef currency As String)
        value = 0D
        currency = ReadString(amount, "currency_code").ToUpperInvariant()
        Decimal.TryParse(ReadString(amount, "value"), NumberStyles.Number, CultureInfo.InvariantCulture, value)
    End Sub

    Private Function ReadSafeError(ByVal json As String, ByVal fallback As String) As String
        Dim data As IDictionary(Of String, Object) = Parse(json)
        Dim value As String = ReadString(data, "name")
        If String.IsNullOrWhiteSpace(value) Then value = fallback
        If value.Length > 80 Then value = value.Substring(0, 80)
        Return value
    End Function

    Private Shared Function Failure(ByVal code As String) As PayPalOrdersV2Result
        Return New PayPalOrdersV2Result With {.Success = False, .ErrorCode = code, .Snapshot = New PayPalOrderSnapshot()}
    End Function

    Private Shared Function Money(ByVal value As Decimal) As String
        Return Math.Round(value, 2, MidpointRounding.AwayFromZero).ToString("0.00", CultureInfo.InvariantCulture)
    End Function

    Private Shared Function IsExternalIdValid(ByVal value As String) As Boolean
        Dim candidate As String = Convert.ToString(value).Trim()
        If candidate.Length < 8 OrElse candidate.Length > 100 Then Return False
        For Each ch As Char In candidate
            If Not Char.IsLetterOrDigit(ch) AndAlso ch <> "-"c AndAlso ch <> "_"c Then Return False
        Next
        Return True
    End Function
End Class
