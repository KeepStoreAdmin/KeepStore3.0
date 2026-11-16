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
    Public Property Prefer As String
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
#If PAYPAL_WEBHOOK_HARNESS Then
        Throw New InvalidOperationException("NETWORK_DISABLED_IN_WEBHOOK_HARNESS")
#Else
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
        If Not String.IsNullOrWhiteSpace(data.Prefer) Then request.Headers("Prefer") = data.Prefer
        If Not String.IsNullOrEmpty(data.Body) Then
            Dim bytes() As Byte = Encoding.UTF8.GetBytes(data.Body)
            request.ContentLength = bytes.Length
            Using stream As Stream = request.GetRequestStream()
                stream.Write(bytes, 0, bytes.Length)
            End Using
        ElseIf String.Equals(data.Method, "POST", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(data.Method, "PUT", StringComparison.OrdinalIgnoreCase) Then
            ' Una POST senza corpo (annullo di un'autorizzazione) dichiara esplicitamente Content-Length: 0 (prova su loopback nell'harness di P1).
            request.ContentLength = 0
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
#End If
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
    Public Property PurchaseUnitCount As Integer
    Public Property Amount As Decimal
    Public Property CurrencyCode As String
    Public Property OrderAmountValid As Boolean
    Public Property PayeeEmail As String
    Public Property MerchantId As String
    Public Property CaptureId As String
    Public Property CaptureStatus As String
    Public Property CaptureCount As Integer
    Public Property CaptureAmount As Decimal
    Public Property CaptureCurrencyCode As String
    Public Property CaptureAmountValid As Boolean
    Public Property ApprovalUrl As String
    ' PAYPAL-AUTHORIZE-CLIENT-1A (P1): importo di unita presente (anche se non valido), autorizzazioni dell'ordine.
    Public Property OrderAmountPresent As Boolean
    Public Property AuthorizationCount As Integer
    Public Property Authorization As PayPalAuthorizationSnapshot
End Class

' Tentativo di pagamento PayPal creato PRIMA del documento (pay-first): nessun numero ordine esiste ancora, il riferimento e l'id durevole del tentativo.
Public Class PayPalAttemptInfo
    Public Property AziendeId As Integer
    Public Property PagamentiTipoId As Integer
    Public Property AttemptId As Long
    Public Property Amount As Decimal
End Class

Public Class PayPalAuthorizationSnapshot
    Public Property Id As String
    Public Property Status As String
    Public Property Amount As Decimal
    Public Property Currency As String
    Public Property AmountPresent As Boolean
    Public Property AmountValid As Boolean
    Public Property InvoiceId As String
    Public Property CustomId As String
    Public Property ExpirationTime As String
    Public Property PayeeEmail As String
    Public Property MerchantId As String
End Class

Public Class PayPalCaptureSnapshot
    Public Property Id As String
    Public Property Status As String
    Public Property Amount As Decimal
    Public Property Currency As String
    Public Property AmountPresent As Boolean
    Public Property AmountValid As Boolean
    Public Property FinalCapturePresent As Boolean
    Public Property FinalCapture As Boolean
    Public Property InvoiceId As String
    Public Property UpAuthorizationId As String
End Class

Public Class PayPalOrdersV2Result
    Public Property Success As Boolean
    Public Property StatusCode As Integer
    Public Property ErrorCode As String
    Public Property Snapshot As PayPalOrderSnapshot
    ' Vero se il fallimento e avvenuto PRIMA di inviare la chiamata (id o tentativo non validi, configurazione, OAuth): nessun effetto remoto possibile.
    Public Property NotSent As Boolean
End Class

Public Class PayPalPaymentsResult
    Public Property Success As Boolean
    Public Property StatusCode As Integer
    Public Property ErrorCode As String
    Public Property NotSent As Boolean
    Public Property Authorization As PayPalAuthorizationSnapshot
    Public Property Capture As PayPalCaptureSnapshot
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

#If PAYPAL_WEBHOOK_HARNESS Then
    ' Compiled only by the isolated QA harness. No request, header, query string,
    ' application setting or production build can enable the fake transport.
    Friend Shared WebhookHarnessTransportFactory As Func(Of IPayPalHttpTransport)

    Private Shared Function DefaultTransport() As IPayPalHttpTransport
        If WebhookHarnessTransportFactory Is Nothing Then Throw New InvalidOperationException("WEBHOOK_FAKE_TRANSPORT_REQUIRED")
        Return WebhookHarnessTransportFactory()
    End Function
#Else
    Private Shared Function DefaultTransport() As IPayPalHttpTransport
        Return New PayPalHttpWebRequestTransport()
    End Function
#End If

    Public Sub New(ByVal config As PayPalCheckoutConfig)
        Me.New(config, DefaultTransport())
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
        Return SendOrder("POST", "/v2/checkout/orders", requestId,
                         BuildCreateOrderPayload(doc, returnUrl, cancelUrl), 201, True)
    End Function

    Public Function BuildCreateOrderPayload(ByVal doc As PayPalPaymentDocumentInfo,
                                            ByVal returnUrl As String,
                                            ByVal cancelUrl As String) As String
        If doc Is Nothing OrElse _config Is Nothing Then Return String.Empty
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
        Return _serializer.Serialize(payload)
    End Function

    Public Function GetOrder(ByVal orderId As String) As PayPalOrdersV2Result
        If Not IsExternalIdValid(orderId) Then Return Failure("ORDER_ID_INVALID")
        Return SendOrder("GET", "/v2/checkout/orders/" & Uri.EscapeDataString(orderId), String.Empty, String.Empty, 200)
    End Function

    Public Function CaptureOrder(ByVal orderId As String, ByVal requestId As String) As PayPalOrdersV2Result
        If Not IsExternalIdValid(orderId) Then Return Failure("ORDER_ID_INVALID")
        Dim result As PayPalOrdersV2Result = SendOrder("POST", "/v2/checkout/orders/" & Uri.EscapeDataString(orderId) & "/capture", requestId, "{}", 201, True)
        If result.Success AndAlso (result.Snapshot.CaptureCount <> 1 OrElse Not result.Snapshot.CaptureAmountValid OrElse
                                   Not IsExternalIdValid(result.Snapshot.CaptureId) OrElse
                                   Not IsCaptureStatusSupported(result.Snapshot.CaptureStatus)) Then
            result.Success = False
            result.ErrorCode = "CAPTURE_REPRESENTATION_INCOMPLETE"
        End If
        Return result
    End Function

    ' ---------------------------------------------------------------------------------------------------------------------------------
    ' PAYPAL-AUTHORIZE-CLIENT-1A (P1 del progetto pay-first, docs/PAYPAL_PAY_FIRST_DESIGN.md): autorizza, incassa l'autorizzazione, annulla.
    ' Codice inerte: nessun chiamante finche non arriva P3. Il percorso CAPTURE di sopra non cambia.
    ' ---------------------------------------------------------------------------------------------------------------------------------
    Public Function BuildCreateAuthorizeOrderPayload(ByVal attempt As PayPalAttemptInfo,
                                                     ByVal returnUrl As String,
                                                     ByVal cancelUrl As String) As String
        If _config Is Nothing OrElse Not IsAttemptUsable(attempt) Then Return String.Empty
        If attempt.AziendeId <> _config.AziendeId OrElse attempt.PagamentiTipoId <> _config.PagamentiTipoId Then Return String.Empty
        Dim unit As New Dictionary(Of String, Object) From {
            {"reference_id", ExpectedAttemptReferenceId(attempt)},
            {"custom_id", ExpectedAttemptCustomId(attempt)},
            {"invoice_id", ExpectedAttemptInvoiceId(attempt)},
            {"amount", New Dictionary(Of String, Object) From {{"currency_code", _config.CurrencyCode}, {"value", Money(attempt.Amount)}}},
            {"payee", New Dictionary(Of String, Object) From {{"email_address", _config.PayeeEmail}}}
        }
        Dim experience As New Dictionary(Of String, Object) From {
            {"brand_name", _config.BrandName}, {"return_url", returnUrl}, {"cancel_url", cancelUrl}, {"user_action", "PAY_NOW"}
        }
        Dim payload As New Dictionary(Of String, Object) From {
            {"intent", "AUTHORIZE"},
            {"purchase_units", New Object() {unit}},
            {"payment_source", New Dictionary(Of String, Object) From {{"paypal", New Dictionary(Of String, Object) From {{"experience_context", experience}}}}}
        }
        Return _serializer.Serialize(payload)
    End Function

    Public Function CreateAuthorizeOrder(ByVal attempt As PayPalAttemptInfo,
                                         ByVal requestId As String,
                                         ByVal returnUrl As String,
                                         ByVal cancelUrl As String) As PayPalOrdersV2Result
        If Not IsAttemptUsable(attempt) Then Return Failure("ATTEMPT_INVALID")
        If _config Is Nothing OrElse attempt.AziendeId <> _config.AziendeId OrElse attempt.PagamentiTipoId <> _config.PagamentiTipoId Then Return Failure("TENANT_MISMATCH")
        Dim result As PayPalOrdersV2Result = SendOrder("POST", "/v2/checkout/orders", requestId,
                                                       BuildCreateAuthorizeOrderPayload(attempt, returnUrl, cancelUrl), 201, False, True, True)
        If result.Success AndAlso Not IsExternalIdValid(result.Snapshot.OrderId) Then
            result.Success = False
            result.ErrorCode = "ORDER_ID_INVALID"
        End If
        Return result
    End Function

    ' Autorizza l'ordine approvato dal cliente (fondi riservati, NON incassati). Successo a livello di chiamata: HTTP 200/201, stesso id ordine,
    ' una sola autorizzazione con id e importo leggibili. Il giudizio commerciale e di CheckAuthorizeResponse e del GET dell'ordine.
    Public Function AuthorizeOrder(ByVal orderId As String, ByVal requestId As String) As PayPalOrdersV2Result
        If Not IsExternalIdValid(orderId) Then Return Failure("ORDER_ID_INVALID")
        Dim result As PayPalOrdersV2Result = SendOrder("POST", "/v2/checkout/orders/" & Uri.EscapeDataString(orderId) & "/authorize", requestId, "{}", 201, False, True, True)
        If Not result.Success Then Return result
        If Not String.Equals(result.Snapshot.OrderId, orderId, StringComparison.Ordinal) Then
            result.Success = False
            result.ErrorCode = "ORDER_ID_MISMATCH"
            Return result
        End If
        Dim authorization As PayPalAuthorizationSnapshot = result.Snapshot.Authorization
        If result.Snapshot.AuthorizationCount <> 1 OrElse authorization Is Nothing OrElse Not IsExternalIdValid(authorization.Id) OrElse
           Not authorization.AmountValid OrElse String.IsNullOrEmpty(authorization.Status) Then
            result.Success = False
            result.ErrorCode = "AUTHORIZE_REPRESENTATION_INCOMPLETE"
        End If
        Return result
    End Function

    Public Function GetAuthorization(ByVal authorizationId As String) As PayPalPaymentsResult
        If Not IsExternalIdValid(authorizationId) Then Return PaymentsFailure("AUTHORIZATION_ID_INVALID")
        Dim failure As PayPalPaymentsResult = Nothing
        Dim response As PayPalHttpResponseData = SendPayment("GET", "/v2/payments/authorizations/" & Uri.EscapeDataString(authorizationId), String.Empty, String.Empty, False, failure)
        If response Is Nothing Then Return failure
        Dim result As New PayPalPaymentsResult With {.StatusCode = response.StatusCode, .Authorization = ParseAuthorization(response.Body)}
        If response.StatusCode = 200 Then
            If result.Authorization Is Nothing OrElse Not IsExternalIdValid(result.Authorization.Id) OrElse String.IsNullOrEmpty(result.Authorization.Status) Then
                result.ErrorCode = "AUTHORIZATION_REPRESENTATION_INCOMPLETE"
            ElseIf Not String.Equals(result.Authorization.Id, authorizationId, StringComparison.Ordinal) Then
                result.ErrorCode = "AUTHORIZATION_ID_MISMATCH"
            Else
                result.Success = True
            End If
        Else
            result.ErrorCode = ReadSafeErrorWithIssue(response.Body, "PAYPAL_API_FAILED")
        End If
        Return result
    End Function

    ' Incassa l'autorizzazione: importo esplicito (arrotondato al centesimo), final_capture sempre vero, invoice_id facoltativo (vuoto = omesso).
    Public Function CaptureAuthorization(ByVal authorizationId As String,
                                         ByVal requestId As String,
                                         ByVal amount As Decimal,
                                         ByVal currencyCode As String,
                                         ByVal invoiceId As String) As PayPalPaymentsResult
        If Not IsExternalIdValid(authorizationId) Then Return PaymentsFailure("AUTHORIZATION_ID_INVALID")
        Dim rounded As Decimal = Math.Round(amount, 2, MidpointRounding.AwayFromZero)
        Dim currency As String = Convert.ToString(currencyCode).Trim().ToUpperInvariant()
        If rounded <= 0D OrElse currency.Length <> 3 Then Return PaymentsFailure("CAPTURE_AMOUNT_INVALID")
        Dim invoice As String = Convert.ToString(invoiceId).Trim()
        If invoice.Length > 0 AndAlso Not IsInvoiceIdValid(invoice) Then Return PaymentsFailure("INVOICE_ID_INVALID")
        Dim body As New Dictionary(Of String, Object) From {
            {"amount", New Dictionary(Of String, Object) From {{"currency_code", currency}, {"value", Money(rounded)}}}
        }
        If invoice.Length > 0 Then body("invoice_id") = invoice
        body("final_capture") = True
        Dim failure As PayPalPaymentsResult = Nothing
        Dim response As PayPalHttpResponseData = SendPayment("POST", "/v2/payments/authorizations/" & Uri.EscapeDataString(authorizationId) & "/capture", requestId, _serializer.Serialize(body), True, failure)
        If response Is Nothing Then Return failure
        Dim result As New PayPalPaymentsResult With {.StatusCode = response.StatusCode, .Capture = ParseCapture(response.Body)}
        If response.StatusCode = 200 OrElse response.StatusCode = 201 Then
            If result.Capture Is Nothing OrElse Not IsExternalIdValid(result.Capture.Id) OrElse String.IsNullOrEmpty(result.Capture.Status) Then
                result.ErrorCode = "CAPTURE_REPRESENTATION_INCOMPLETE"
            Else
                result.Success = True
            End If
        Else
            result.ErrorCode = ReadSafeErrorWithIssue(response.Body, "PAYPAL_API_FAILED")
        End If
        Return result
    End Function

    ' Annulla l'autorizzazione. 204 = annullata; 200 conta solo se la rappresentazione dice VOIDED per l'id atteso.
    Public Function VoidAuthorization(ByVal authorizationId As String, ByVal requestId As String) As PayPalPaymentsResult
        If Not IsExternalIdValid(authorizationId) Then Return PaymentsFailure("AUTHORIZATION_ID_INVALID")
        Dim failure As PayPalPaymentsResult = Nothing
        Dim response As PayPalHttpResponseData = SendPayment("POST", "/v2/payments/authorizations/" & Uri.EscapeDataString(authorizationId) & "/void", requestId, String.Empty, True, failure)
        If response Is Nothing Then Return failure
        Dim result As New PayPalPaymentsResult With {.StatusCode = response.StatusCode}
        If response.StatusCode = 204 Then
            result.Success = True
        ElseIf response.StatusCode = 200 Then
            result.Authorization = ParseAuthorization(response.Body)
            If result.Authorization IsNot Nothing AndAlso String.Equals(result.Authorization.Id, authorizationId, StringComparison.Ordinal) AndAlso
               String.Equals(result.Authorization.Status, "VOIDED", StringComparison.Ordinal) Then
                result.Success = True
            Else
                result.ErrorCode = "VOID_REPRESENTATION_MISMATCH"
            End If
        Else
            result.ErrorCode = ReadSafeErrorWithIssue(response.Body, "PAYPAL_API_FAILED")
        End If
        Return result
    End Function

    Public Function VerifyWebhookSignature(ByVal transmissionId As String,
                                           ByVal transmissionTime As String,
                                           ByVal certUrl As String,
                                           ByVal authAlgo As String,
                                           ByVal transmissionSignature As String,
                                           ByVal rawWebhookEvent As String) As PayPalWebhookVerificationResult
        Dim result As New PayPalWebhookVerificationResult()
        If _config Is Nothing OrElse Not _config.IsWebhookConfigured Then result.ErrorCode = "WEBHOOK_CONFIGURATION_UNAVAILABLE" : Return result
        Dim verificationBody As String = BuildWebhookVerificationPayload(transmissionId, transmissionTime, certUrl, authAlgo, transmissionSignature, _config.WebhookId, rawWebhookEvent)
        If verificationBody = String.Empty Then result.ErrorCode = "WEBHOOK_EVENT_INVALID" : Return result
        Dim token As PayPalAccessTokenResult = GetAccessToken()
        If Not token.Success Then result.ErrorCode = token.ErrorCode : Return result
        Dim response As PayPalHttpResponseData = SafeSend(New PayPalHttpRequestData With {
            .Method = "POST", .Url = PayPalCheckoutConfig.LiveApiBaseUrl & "/v1/notifications/verify-webhook-signature",
            .ContentType = "application/json", .Authorization = "Bearer " & token.AccessToken,
            .Body = verificationBody})
        result.StatusCode = response.StatusCode
        result.VerificationStatus = ReadString(Parse(response.Body), "verification_status").ToUpperInvariant()
        result.Success = response.StatusCode = 200 AndAlso result.VerificationStatus = "SUCCESS"
        If Not result.Success Then result.ErrorCode = ReadSafeError(response.Body, "WEBHOOK_VERIFICATION_FAILED")
        Return result
    End Function

    Public Shared Function BuildWebhookVerificationPayload(ByVal transmissionId As String,
                                                            ByVal transmissionTime As String,
                                                            ByVal certUrl As String,
                                                            ByVal authAlgo As String,
                                                            ByVal transmissionSignature As String,
                                                            ByVal webhookId As String,
                                                            ByVal rawWebhookEvent As String) As String
        If String.IsNullOrWhiteSpace(rawWebhookEvent) Then Return String.Empty
        Dim serializer As New JavaScriptSerializer()
        Try
            If TryCast(serializer.DeserializeObject(rawWebhookEvent), IDictionary(Of String, Object)) Is Nothing Then Return String.Empty
        Catch
            Return String.Empty
        End Try
        Dim sentinel As String = "__KEEPSTORE_PAYPAL_RAW_EVENT_" & Guid.NewGuid().ToString("N") & "__"
        Dim payload As New Dictionary(Of String, Object) From {
            {"transmission_id", transmissionId}, {"transmission_time", transmissionTime}, {"cert_url", certUrl},
            {"auth_algo", authAlgo}, {"transmission_sig", transmissionSignature}, {"webhook_id", webhookId},
            {"webhook_event", sentinel}
        }
        Dim serialized As String = serializer.Serialize(payload)
        Dim encodedSentinel As String = serializer.Serialize(sentinel)
        If Not serialized.Contains(encodedSentinel) Then Return String.Empty
        Return serialized.Replace(encodedSentinel, rawWebhookEvent)
    End Function

    Public Shared Function IsReturnOrderTokenValid(ByVal rawToken As String, ByVal persistedOrderId As String) As Boolean
        Dim candidate As String = Convert.ToString(rawToken).Trim()
        Return IsExternalIdValid(candidate) AndAlso String.Equals(candidate, Convert.ToString(persistedOrderId), StringComparison.Ordinal)
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
               snapshot.PurchaseUnitCount = 1 AndAlso snapshot.OrderAmountValid AndAlso
               String.Equals(snapshot.OrderId, expectedOrderId, StringComparison.Ordinal) AndAlso
               String.Equals(snapshot.Intent, "CAPTURE", StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(snapshot.ReferenceId, ExpectedReferenceId(doc), StringComparison.Ordinal) AndAlso
               String.Equals(snapshot.CustomId, ExpectedCustomId(doc), StringComparison.Ordinal) AndAlso
               String.Equals(snapshot.InvoiceId, ExpectedInvoiceId(doc), StringComparison.Ordinal) AndAlso
               snapshot.Amount = Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero) AndAlso
               String.Equals(snapshot.CurrencyCode, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(snapshot.PayeeEmail, cfg.PayeeEmail, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(snapshot.MerchantId, cfg.MerchantId, StringComparison.Ordinal) AndAlso
               snapshot.CaptureCount <= 1 AndAlso
               (snapshot.CaptureCount = 0 AndAlso Not String.Equals(snapshot.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase) OrElse
                HasMatchingCapture(snapshot, doc.TotalDocument, cfg.CurrencyCode))
    End Function

    Public Shared Function ValidateSnapshotAgainstAttempt(ByVal doc As PayPalPaymentDocumentInfo,
                                                          ByVal cfg As PayPalCheckoutConfig,
                                                          ByVal expectedOrderId As String,
                                                          ByVal snapshot As PayPalOrderSnapshot,
                                                          ByVal attemptAmount As Decimal,
                                                          ByVal attemptCurrency As String) As Boolean
        Return ValidateSnapshot(doc, cfg, expectedOrderId, snapshot) AndAlso
               attemptAmount = Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero) AndAlso
               String.Equals(attemptCurrency, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) AndAlso
               (snapshot.CaptureCount = 0 OrElse HasMatchingCapture(snapshot, attemptAmount, attemptCurrency))
    End Function

    ' Descrizione sicura di un esito negativo per il registro: stato HTTP e codice di errore (nome PayPal o codice interno su una riga).
    ' Mai corpo della risposta, token, intestazioni o credenziali.
    Public Shared Function DescribeFailure(ByVal result As PayPalOrdersV2Result) As String
        If result Is Nothing Then Return "result=none"
        Dim code As String = Convert.ToString(result.ErrorCode).Replace(vbCr, " ").Replace(vbLf, " ").Trim()
        If code.Length > 80 Then code = code.Substring(0, 80)
        If code.Length = 0 Then code = "none"
        Return "http=" & result.StatusCode.ToString(CultureInfo.InvariantCulture) & " code=" & code
    End Function

    Public Shared Function HasMatchingCapture(ByVal snapshot As PayPalOrderSnapshot,
                                              ByVal expectedAmount As Decimal,
                                              ByVal expectedCurrency As String) As Boolean
        Return snapshot IsNot Nothing AndAlso snapshot.CaptureCount = 1 AndAlso snapshot.CaptureAmountValid AndAlso
               IsExternalIdValid(snapshot.CaptureId) AndAlso IsCaptureStatusSupported(snapshot.CaptureStatus) AndAlso
               snapshot.CaptureAmount = Math.Round(expectedAmount, 2, MidpointRounding.AwayFromZero) AndAlso
               String.Equals(snapshot.CaptureCurrencyCode, expectedCurrency, StringComparison.OrdinalIgnoreCase)
    End Function

    ' ----- P1 pay-first: riferimenti attesi del tentativo e validatori (restituiscono il MOTIVO del rifiuto, vuoto = valido) -----
    Public Shared Function ExpectedAttemptReferenceId(ByVal attempt As PayPalAttemptInfo) As String
        Return "KS-A-" & attempt.AziendeId.ToString(CultureInfo.InvariantCulture) & "-" & attempt.AttemptId.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Shared Function ExpectedAttemptCustomId(ByVal attempt As PayPalAttemptInfo) As String
        Return "KS-ATT-" & attempt.AziendeId.ToString(CultureInfo.InvariantCulture) & "-" & attempt.AttemptId.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Shared Function ExpectedAttemptInvoiceId(ByVal attempt As PayPalAttemptInfo) As String
        Return "KS-AINV-" & attempt.AziendeId.ToString(CultureInfo.InvariantCulture) & "-" & attempt.AttemptId.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Shared Function IsAttemptUsable(ByVal attempt As PayPalAttemptInfo) As Boolean
        Return attempt IsNot Nothing AndAlso attempt.AziendeId > 0 AndAlso attempt.PagamentiTipoId > 0 AndAlso attempt.AttemptId > 0 AndAlso
               Math.Round(attempt.Amount, 2, MidpointRounding.AwayFromZero) > 0D
    End Function

    ' Un campo e in disaccordo se presente e diverso; se assente lo e solo quando e obbligatorio.
    Private Shared Function FieldDiffers(ByVal actual As String, ByVal expected As String, ByVal required As Boolean, ByVal ignoreCase As Boolean) As Boolean
        If String.IsNullOrEmpty(actual) Then Return required
        Return Not String.Equals(actual, expected, If(ignoreCase, StringComparison.OrdinalIgnoreCase, StringComparison.Ordinal))
    End Function

    Private Shared Function CheckAuthorizeOrderCommon(ByVal attempt As PayPalAttemptInfo,
                                                      ByVal cfg As PayPalCheckoutConfig,
                                                      ByVal expectedOrderId As String,
                                                      ByVal snapshot As PayPalOrderSnapshot,
                                                      ByVal strict As Boolean) As String
        If attempt Is Nothing OrElse cfg Is Nothing OrElse snapshot Is Nothing Then Return "INPUT"
        If cfg.AziendeId <> attempt.AziendeId OrElse cfg.PagamentiTipoId <> attempt.PagamentiTipoId Then Return "TENANT"
        If Not IsAttemptUsable(attempt) Then Return "ATTEMPT"
        If Not IsExternalIdValid(expectedOrderId) OrElse Not String.Equals(snapshot.OrderId, expectedOrderId, StringComparison.Ordinal) Then Return "ORDER_ID"
        If snapshot.PurchaseUnitCount > 1 OrElse (strict AndAlso snapshot.PurchaseUnitCount <> 1) Then Return "UNIT_COUNT"
        If FieldDiffers(snapshot.Intent, "AUTHORIZE", strict, True) Then Return "INTENT"
        If FieldDiffers(snapshot.ReferenceId, ExpectedAttemptReferenceId(attempt), strict, False) Then Return "REFERENCE_ID"
        If FieldDiffers(snapshot.CustomId, ExpectedAttemptCustomId(attempt), strict, False) Then Return "CUSTOM_ID"
        If FieldDiffers(snapshot.InvoiceId, ExpectedAttemptInvoiceId(attempt), strict, False) Then Return "INVOICE_ID"
        If snapshot.OrderAmountPresent Then
            If Not snapshot.OrderAmountValid OrElse snapshot.Amount <> Math.Round(attempt.Amount, 2, MidpointRounding.AwayFromZero) Then Return "AMOUNT"
            If Not String.Equals(snapshot.CurrencyCode, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) Then Return "CURRENCY"
        ElseIf strict Then
            Return "AMOUNT"
        End If
        If FieldDiffers(snapshot.PayeeEmail, cfg.PayeeEmail, strict, True) Then Return "PAYEE"
        If FieldDiffers(snapshot.MerchantId, cfg.MerchantId, strict, False) Then Return "MERCHANT"
        Return String.Empty
    End Function

    ' Risposta di creazione dell'ordine AUTHORIZE: bastano id, stato e link di approvazione; i campi di unita, se presenti, devono coincidere.
    Public Shared Function CheckCreatedAuthorizeOrder(ByVal attempt As PayPalAttemptInfo,
                                                      ByVal cfg As PayPalCheckoutConfig,
                                                      ByVal expectedOrderId As String,
                                                      ByVal snapshot As PayPalOrderSnapshot) As String
        Dim reason As String = CheckAuthorizeOrderCommon(attempt, cfg, expectedOrderId, snapshot, False)
        If reason.Length > 0 Then Return reason
        If Not (String.Equals(snapshot.Status, "CREATED", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(snapshot.Status, "PAYER_ACTION_REQUIRED", StringComparison.OrdinalIgnoreCase)) Then Return "STATE"
        If snapshot.AuthorizationCount <> 0 OrElse snapshot.CaptureCount <> 0 Then Return "STATE"
        If String.IsNullOrEmpty(snapshot.ApprovalUrl) Then Return "APPROVAL_URL"
        Return String.Empty
    End Function

    ' GET dell'ordine al rientro del cliente: tutti i campi sono obbligatori. APPROVED = da autorizzare; COMPLETED = gia autorizzato (rinfresco o ripresa).
    Public Shared Function CheckApprovedAuthorizeOrder(ByVal attempt As PayPalAttemptInfo,
                                                       ByVal cfg As PayPalCheckoutConfig,
                                                       ByVal expectedOrderId As String,
                                                       ByVal snapshot As PayPalOrderSnapshot) As String
        Dim reason As String = CheckAuthorizeOrderCommon(attempt, cfg, expectedOrderId, snapshot, True)
        If reason.Length > 0 Then Return reason
        If String.Equals(snapshot.Status, "APPROVED", StringComparison.OrdinalIgnoreCase) Then
            If snapshot.AuthorizationCount <> 0 OrElse snapshot.CaptureCount <> 0 Then Return "STATE"
            Return String.Empty
        End If
        If Not String.Equals(snapshot.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase) OrElse snapshot.AuthorizationCount <> 1 Then Return "STATE"
        Dim sub1 As String = CheckAuthorizationSnapshot(attempt, cfg, snapshot.Authorization, String.Empty, False)
        If sub1.Length > 0 Then Return "AUTHORIZATION_" & sub1
        If snapshot.CaptureCount > 1 Then Return "CAPTURE_COUNT"
        If snapshot.CaptureCount = 1 Then
            If Not IsExternalIdValid(snapshot.CaptureId) Then Return "CAPTURE_ID"
            If Not IsCaptureStatusRecognized(snapshot.CaptureStatus) Then Return "CAPTURE_STATUS"
            If Not snapshot.CaptureAmountValid OrElse snapshot.CaptureAmount <> Math.Round(attempt.Amount, 2, MidpointRounding.AwayFromZero) Then Return "CAPTURE_AMOUNT"
            If Not String.Equals(snapshot.CaptureCurrencyCode, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) Then Return "CAPTURE_CURRENCY"
        End If
        Return String.Empty
    End Function

    Public Shared Function ValidateApprovedAuthorizeOrder(ByVal attempt As PayPalAttemptInfo,
                                                          ByVal cfg As PayPalCheckoutConfig,
                                                          ByVal expectedOrderId As String,
                                                          ByVal snapshot As PayPalOrderSnapshot) As Boolean
        Return CheckApprovedAuthorizeOrder(attempt, cfg, expectedOrderId, snapshot).Length = 0
    End Function

    ' Risposta di authorize (rappresentazione minima della specifica): stesso ordine richiesto, una sola autorizzazione coerente; i campi di unita,
    ' se presenti, devono coincidere. L'autorizzazione da incassare va riletta dal GET dell'ordine validato (CheckApprovedAuthorizeOrder).
    Public Shared Function CheckAuthorizeResponse(ByVal attempt As PayPalAttemptInfo,
                                                  ByVal cfg As PayPalCheckoutConfig,
                                                  ByVal expectedOrderId As String,
                                                  ByVal snapshot As PayPalOrderSnapshot) As String
        If attempt Is Nothing OrElse cfg Is Nothing OrElse snapshot Is Nothing Then Return "INPUT"
        If cfg.AziendeId <> attempt.AziendeId OrElse cfg.PagamentiTipoId <> attempt.PagamentiTipoId Then Return "TENANT"
        If Not IsAttemptUsable(attempt) Then Return "ATTEMPT"
        If Not IsExternalIdValid(expectedOrderId) OrElse Not String.Equals(snapshot.OrderId, expectedOrderId, StringComparison.Ordinal) Then Return "ORDER_ID"
        If snapshot.PurchaseUnitCount <> 1 Then Return "UNIT_COUNT"
        If FieldDiffers(snapshot.ReferenceId, ExpectedAttemptReferenceId(attempt), False, False) Then Return "REFERENCE_ID"
        If FieldDiffers(snapshot.CustomId, ExpectedAttemptCustomId(attempt), False, False) Then Return "CUSTOM_ID"
        If FieldDiffers(snapshot.InvoiceId, ExpectedAttemptInvoiceId(attempt), False, False) Then Return "INVOICE_ID"
        If Not String.IsNullOrEmpty(snapshot.Status) AndAlso Not String.Equals(snapshot.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase) Then Return "STATE"
        If snapshot.AuthorizationCount <> 1 OrElse snapshot.Authorization Is Nothing Then Return "AUTHORIZATION"
        Dim sub1 As String = CheckAuthorizationSnapshot(attempt, cfg, snapshot.Authorization, String.Empty, False)
        If sub1.Length > 0 Then Return "AUTHORIZATION_" & sub1
        Return String.Empty
    End Function

    ' Autorizzazione (risposta di authorize, GET autorizzazione o GET ordine). requireFull = GET autorizzazione: invoice, payee e merchant obbligatori.
    ' expectedAuthorizationId (non vuoto) lega l'autorizzazione a quella gia validata nel GET dell'ordine.
    Public Shared Function CheckAuthorizationSnapshot(ByVal attempt As PayPalAttemptInfo,
                                                      ByVal cfg As PayPalCheckoutConfig,
                                                      ByVal auth As PayPalAuthorizationSnapshot,
                                                      ByVal expectedAuthorizationId As String,
                                                      ByVal requireFull As Boolean) As String
        If attempt Is Nothing OrElse cfg Is Nothing OrElse auth Is Nothing Then Return "INPUT"
        If cfg.AziendeId <> attempt.AziendeId OrElse cfg.PagamentiTipoId <> attempt.PagamentiTipoId Then Return "TENANT"
        If Not IsAttemptUsable(attempt) Then Return "ATTEMPT"
        If Not IsExternalIdValid(auth.Id) OrElse (Not String.IsNullOrEmpty(expectedAuthorizationId) AndAlso Not String.Equals(auth.Id, expectedAuthorizationId, StringComparison.Ordinal)) Then Return "AUTHORIZATION_ID"
        If Not IsAuthorizationStatusKnown(auth.Status) Then Return "STATUS"
        If Not auth.AmountPresent OrElse Not auth.AmountValid OrElse auth.Amount <> Math.Round(attempt.Amount, 2, MidpointRounding.AwayFromZero) Then Return "AMOUNT"
        If Not String.Equals(auth.Currency, cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) Then Return "CURRENCY"
        If FieldDiffers(auth.InvoiceId, ExpectedAttemptInvoiceId(attempt), requireFull, False) Then Return "INVOICE_ID"
        If FieldDiffers(auth.CustomId, ExpectedAttemptCustomId(attempt), False, False) Then Return "CUSTOM_ID"
        If FieldDiffers(auth.PayeeEmail, cfg.PayeeEmail, requireFull, True) Then Return "PAYEE"
        If FieldDiffers(auth.MerchantId, cfg.MerchantId, requireFull, False) Then Return "MERCHANT"
        Dim expiration As DateTime
        If Not String.IsNullOrEmpty(auth.ExpirationTime) AndAlso Not TryParseUtc(auth.ExpirationTime, expiration) Then Return "EXPIRATION"
        Return String.Empty
    End Function

    ' Solo CREATED (non PENDING, DENIED, VOIDED, CAPTURED...) e non scaduta; una scadenza presente ma illeggibile e non incassabile.
    Public Shared Function IsAuthorizationCapturable(ByVal auth As PayPalAuthorizationSnapshot, ByVal nowUtc As DateTime) As Boolean
        If auth Is Nothing OrElse Not String.Equals(auth.Status, "CREATED", StringComparison.Ordinal) Then Return False
        If String.IsNullOrEmpty(auth.ExpirationTime) Then Return True
        Dim expiration As DateTime
        Return TryParseUtc(auth.ExpirationTime, expiration) AndAlso expiration > nowUtc
    End Function

    ' Incasso di un'autorizzazione: id, stato riconosciuto; importo, valuta, invoice, final_capture e link `up` se presenti devono coincidere.
    Public Shared Function CheckCaptureSnapshot(ByVal expectedAmount As Decimal,
                                                ByVal expectedCurrency As String,
                                                ByVal expectedInvoiceId As String,
                                                ByVal expectedAuthorizationId As String,
                                                ByVal capture As PayPalCaptureSnapshot) As String
        If capture Is Nothing Then Return "INPUT"
        If Not IsExternalIdValid(capture.Id) Then Return "CAPTURE_ID"
        If Not IsCaptureStatusRecognized(capture.Status) Then Return "STATUS"
        If capture.AmountPresent Then
            If Not capture.AmountValid OrElse capture.Amount <> Math.Round(expectedAmount, 2, MidpointRounding.AwayFromZero) Then Return "AMOUNT"
            If Not String.Equals(capture.Currency, expectedCurrency, StringComparison.OrdinalIgnoreCase) Then Return "CURRENCY"
        End If
        If Not String.IsNullOrEmpty(expectedInvoiceId) AndAlso Not String.IsNullOrEmpty(capture.InvoiceId) AndAlso
           Not String.Equals(capture.InvoiceId, expectedInvoiceId, StringComparison.Ordinal) Then Return "INVOICE_ID"
        If capture.FinalCapturePresent AndAlso Not capture.FinalCapture Then Return "FINAL_CAPTURE"
        If Not String.IsNullOrEmpty(expectedAuthorizationId) AndAlso Not String.IsNullOrEmpty(capture.UpAuthorizationId) AndAlso
           Not String.Equals(capture.UpAuthorizationId, expectedAuthorizationId, StringComparison.Ordinal) Then Return "AUTHORIZATION_ID"
        Return String.Empty
    End Function

    ' Riconoscere uno stato non significa considerarlo pagato: solo COMPLETED.
    Public Shared Function IsCaptureCompleted(ByVal capture As PayPalCaptureSnapshot) As Boolean
        Return capture IsNot Nothing AndAlso String.Equals(capture.Status, "COMPLETED", StringComparison.Ordinal)
    End Function

    ' Esito incerto = non si sa se PayPal ha eseguito: prima di decidere si rilegge lo stato su PayPal (mai «fallito» a occhio).
    Public Shared Function IsOutcomeUncertain(ByVal statusCode As Integer, ByVal success As Boolean) As Boolean
        If success Then Return False
        If statusCode = 0 OrElse statusCode = 202 OrElse statusCode = 207 OrElse statusCode = 409 OrElse statusCode >= 500 Then Return True
        Return statusCode = 200 OrElse statusCode = 201 OrElse statusCode = 204
    End Function

    Public Shared Function IsOutcomeUncertain(ByVal result As PayPalOrdersV2Result) As Boolean
        If result Is Nothing Then Return True
        If result.Success Then Return False
        If result.NotSent Then Return False
        If IsStateConflictCode(result.ErrorCode) Then Return True
        Return IsOutcomeUncertain(result.StatusCode, False)
    End Function

    Public Shared Function IsOutcomeUncertain(ByVal result As PayPalPaymentsResult) As Boolean
        If result Is Nothing Then Return True
        If result.Success Then Return False
        If result.NotSent Then Return False
        If IsStateConflictCode(result.ErrorCode) Then Return True
        Return IsOutcomeUncertain(result.StatusCode, False)
    End Function

    ' Un 422 che dice «gia fatto» prova che un effetto e avvenuto (per esempio dopo un timeout): serve la rilettura, non un fallimento.
    ' Nella specifica letta compaiono PREVIOUSLY_CAPTURED e PREVIOUS_REQUEST_IN_PROGRESS; gli altri nomi sono prudenza (peggio: una rilettura in piu).
    Public Shared Function IsStateConflictCode(ByVal errorCode As String) As Boolean
        Dim code As String = If(errorCode, String.Empty)
        Dim cut As Integer = code.LastIndexOf(":"c)
        If cut < 0 Then Return False
        Select Case code.Substring(cut + 1)
            Case "PREVIOUSLY_CAPTURED", "ORDER_ALREADY_AUTHORIZED", "ORDER_ALREADY_CAPTURED", "AUTHORIZATION_ALREADY_CAPTURED", "DUPLICATE_INVOICE_ID", "PREVIOUS_REQUEST_IN_PROGRESS"
                Return True
        End Select
        Return False
    End Function

    Private Shared Function IsAuthorizationStatusKnown(ByVal status As String) As Boolean
        Select Case Convert.ToString(status)
            Case "CREATED", "CAPTURED", "DENIED", "PARTIALLY_CAPTURED", "VOIDED", "PENDING"
                Return True
        End Select
        Return False
    End Function

    Private Shared Function IsCaptureStatusRecognized(ByVal status As String) As Boolean
        Select Case Convert.ToString(status).Trim().ToUpperInvariant()
            Case "COMPLETED", "PENDING", "DECLINED", "FAILED", "DENIED", "REFUNDED", "PARTIALLY_REFUNDED"
                Return True
        End Select
        Return False
    End Function

    Private Shared Function TryParseUtc(ByVal value As String, ByRef result As DateTime) As Boolean
        Return DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal Or DateTimeStyles.AssumeUniversal, result)
    End Function

    Private Shared Function IsInvoiceIdValid(ByVal value As String) As Boolean
        If String.IsNullOrEmpty(value) OrElse value.Length > 127 Then Return False
        For Each ch As Char In value
            If Not Char.IsLetterOrDigit(ch) AndAlso ch <> "-"c AndAlso ch <> "_"c AndAlso ch <> "."c Then Return False
        Next
        Return True
    End Function

    Private Shared Function PaymentsFailure(ByVal code As String, Optional ByVal statusCode As Integer = 0) As PayPalPaymentsResult
        Return New PayPalPaymentsResult With {.Success = False, .NotSent = True, .StatusCode = statusCode, .ErrorCode = code}
    End Function

    ' Chiamata verso /v2/payments: restituisce la risposta, oppure Nothing con `failure` valorizzato quando l'OAuth fallisce (nessuna chiamata finanziaria partita).
    Private Function SendPayment(ByVal method As String,
                                 ByVal path As String,
                                 ByVal requestId As String,
                                 ByVal body As String,
                                 ByVal preferRepresentation As Boolean,
                                 ByRef failure As PayPalPaymentsResult) As PayPalHttpResponseData
        Dim token As PayPalAccessTokenResult = GetAccessToken()
        If Not token.Success Then
            failure = PaymentsFailure(token.ErrorCode, token.StatusCode)
            Return Nothing
        End If
        failure = Nothing
        Return SafeSend(New PayPalHttpRequestData With {
            .Method = method, .Url = PayPalCheckoutConfig.LiveApiBaseUrl & path, .ContentType = "application/json",
            .Authorization = "Bearer " & token.AccessToken, .RequestId = requestId,
            .Prefer = If(preferRepresentation, "return=representation", String.Empty), .Body = body})
    End Function

    Private Function SendOrder(ByVal method As String,
                               ByVal path As String,
                               ByVal requestId As String,
                               ByVal body As String,
                               ByVal expectedStatus As Integer,
                               Optional ByVal requireRepresentation As Boolean = False,
                               Optional ByVal preferRepresentation As Boolean = False,
                               Optional ByVal includeIssue As Boolean = False) As PayPalOrdersV2Result
        Dim token As PayPalAccessTokenResult = GetAccessToken()
        If Not token.Success Then Return Failure(token.ErrorCode, token.StatusCode)
        Dim response As PayPalHttpResponseData = SafeSend(New PayPalHttpRequestData With {
            .Method = method, .Url = PayPalCheckoutConfig.LiveApiBaseUrl & path, .ContentType = "application/json",
            .Authorization = "Bearer " & token.AccessToken, .RequestId = requestId,
            .Prefer = If(requireRepresentation OrElse preferRepresentation, "return=representation", String.Empty), .Body = body})
        Dim result As New PayPalOrdersV2Result With {.StatusCode = response.StatusCode, .Snapshot = ParseSnapshot(response.Body)}
        Dim acceptedStatus As Boolean = response.StatusCode = expectedStatus OrElse (expectedStatus = 201 AndAlso response.StatusCode = 200)
        result.Success = acceptedStatus AndAlso result.Snapshot IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(result.Snapshot.OrderId)
        If result.Success AndAlso requireRepresentation AndAlso Not HasAuthoritativeRepresentation(result.Snapshot) Then result.Success = False
        If Not result.Success Then result.ErrorCode = If(includeIssue, ReadSafeErrorWithIssue(response.Body, "PAYPAL_API_FAILED"), ReadSafeError(response.Body, "PAYPAL_API_FAILED"))
        Return result
    End Function

    Private Shared Function HasAuthoritativeRepresentation(ByVal snapshot As PayPalOrderSnapshot) As Boolean
        Return snapshot IsNot Nothing AndAlso snapshot.Intent <> String.Empty AndAlso snapshot.ReferenceId <> String.Empty AndAlso
               snapshot.PurchaseUnitCount = 1 AndAlso snapshot.OrderAmountValid AndAlso snapshot.CaptureCount <= 1 AndAlso
               snapshot.CustomId <> String.Empty AndAlso snapshot.InvoiceId <> String.Empty AndAlso snapshot.Amount > 0D AndAlso
               snapshot.CurrencyCode <> String.Empty AndAlso snapshot.PayeeEmail <> String.Empty AndAlso snapshot.MerchantId <> String.Empty AndAlso
               (snapshot.CaptureCount = 0 OrElse snapshot.CaptureAmountValid)
    End Function

    Private Shared Function IsCaptureStatusSupported(ByVal value As String) As Boolean
        Dim status As String = Convert.ToString(value).Trim().ToUpperInvariant()
        Return status = "COMPLETED" OrElse status = "PENDING" OrElse status = "DENIED" OrElse status = "DECLINED" OrElse status = "FAILED"
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
        snapshot.PurchaseUnitCount = If(units Is Nothing, 0, units.Count)
        If units IsNot Nothing AndAlso units.Count > 0 Then
            Dim unit As IDictionary(Of String, Object) = AsDictionary(units(0))
            snapshot.ReferenceId = ReadString(unit, "reference_id")
            snapshot.CustomId = ReadString(unit, "custom_id")
            snapshot.InvoiceId = ReadString(unit, "invoice_id")
            snapshot.OrderAmountPresent = HasValue(unit, "amount")
            snapshot.OrderAmountValid = ReadAmount(ReadDictionary(unit, "amount"), snapshot.Amount, snapshot.CurrencyCode)
            Dim payee As IDictionary(Of String, Object) = ReadDictionary(unit, "payee")
            snapshot.PayeeEmail = ReadString(payee, "email_address")
            snapshot.MerchantId = ReadString(payee, "merchant_id")
            Dim payments As IDictionary(Of String, Object) = ReadDictionary(unit, "payments")
            Dim authorizations As IList = ReadList(payments, "authorizations")
            snapshot.AuthorizationCount = If(authorizations Is Nothing, 0, authorizations.Count)
            If authorizations IsNot Nothing AndAlso authorizations.Count > 0 Then snapshot.Authorization = ParseAuthorizationObject(AsDictionary(authorizations(0)))
            Dim captures As IList = ReadList(payments, "captures")
            snapshot.CaptureCount = If(captures Is Nothing, 0, captures.Count)
            If captures IsNot Nothing AndAlso captures.Count > 0 Then
                Dim capture As IDictionary(Of String, Object) = AsDictionary(captures(0))
                snapshot.CaptureId = ReadString(capture, "id")
                snapshot.CaptureStatus = ReadString(capture, "status")
                snapshot.CaptureAmountValid = ReadAmount(ReadDictionary(capture, "amount"), snapshot.CaptureAmount, snapshot.CaptureCurrencyCode)
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

    Private Function ParseAuthorization(ByVal json As String) As PayPalAuthorizationSnapshot
        Return ParseAuthorizationObject(Parse(json))
    End Function

    Private Function ParseAuthorizationObject(ByVal data As IDictionary(Of String, Object)) As PayPalAuthorizationSnapshot
        If data Is Nothing Then Return Nothing
        Dim auth As New PayPalAuthorizationSnapshot With {
            .Id = ReadString(data, "id"), .Status = ReadString(data, "status").ToUpperInvariant(),
            .InvoiceId = ReadString(data, "invoice_id"), .CustomId = ReadString(data, "custom_id"),
            .ExpirationTime = ReadString(data, "expiration_time"), .AmountPresent = HasValue(data, "amount")}
        auth.AmountValid = ReadAmount(ReadDictionary(data, "amount"), auth.Amount, auth.Currency)
        Dim payee As IDictionary(Of String, Object) = ReadDictionary(data, "payee")
        auth.PayeeEmail = ReadString(payee, "email_address")
        auth.MerchantId = ReadString(payee, "merchant_id")
        Return auth
    End Function

    Private Function ParseCapture(ByVal json As String) As PayPalCaptureSnapshot
        Dim data As IDictionary(Of String, Object) = Parse(json)
        If data Is Nothing Then Return Nothing
        Dim capture As New PayPalCaptureSnapshot With {
            .Id = ReadString(data, "id"), .Status = ReadString(data, "status").ToUpperInvariant(),
            .InvoiceId = ReadString(data, "invoice_id"), .AmountPresent = HasValue(data, "amount"),
            .FinalCapturePresent = HasValue(data, "final_capture"), .UpAuthorizationId = ReadUpAuthorizationId(ReadList(data, "links"))}
        capture.AmountValid = ReadAmount(ReadDictionary(data, "amount"), capture.Amount, capture.Currency)
        If capture.FinalCapturePresent Then capture.FinalCapture = ReadBoolean(data, "final_capture")
        Return capture
    End Function

    ' Id dell'autorizzazione dal link `up` del capture (.../v2/payments/authorizations/<id>); vuoto se assente o di altra natura.
    Private Shared Function ReadUpAuthorizationId(ByVal links As IList) As String
        If links Is Nothing Then Return String.Empty
        Const marker As String = "/v2/payments/authorizations/"
        For Each item As Object In links
            Dim link As IDictionary(Of String, Object) = AsDictionary(item)
            If Not String.Equals(ReadString(link, "rel"), "up", StringComparison.OrdinalIgnoreCase) Then Continue For
            Dim href As String = ReadString(link, "href")
            Dim at As Integer = href.IndexOf(marker, StringComparison.Ordinal)
            If at < 0 Then Continue For
            Dim rest As String = href.Substring(at + marker.Length)
            Dim stop1 As Integer = rest.IndexOfAny(New Char() {"/"c, "?"c, "#"c})
            Return If(stop1 < 0, rest, rest.Substring(0, stop1)).Trim()
        Next
        Return String.Empty
    End Function

    Private Shared Function HasValue(ByVal data As IDictionary(Of String, Object), ByVal key As String) As Boolean
        Return data IsNot Nothing AndAlso data.ContainsKey(key) AndAlso data(key) IsNot Nothing
    End Function

    Private Shared Function ReadBoolean(ByVal data As IDictionary(Of String, Object), ByVal key As String) As Boolean
        If Not HasValue(data, key) Then Return False
        If TypeOf data(key) Is Boolean Then Return CBool(data(key))
        Return String.Equals(Convert.ToString(data(key), CultureInfo.InvariantCulture), "true", StringComparison.OrdinalIgnoreCase)
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

    Private Shared Function ReadAmount(ByVal amount As IDictionary(Of String, Object), ByRef value As Decimal, ByRef currency As String) As Boolean
        value = 0D
        currency = ReadString(amount, "currency_code").ToUpperInvariant()
        Return currency.Length = 3 AndAlso
               Decimal.TryParse(ReadString(amount, "value"), NumberStyles.AllowLeadingSign Or NumberStyles.AllowDecimalPoint,
                                CultureInfo.InvariantCulture, value) AndAlso
               value > 0D AndAlso Decimal.Round(value, 2) = value
    End Function

    Private Function ReadSafeError(ByVal json As String, ByVal fallback As String) As String
        Dim data As IDictionary(Of String, Object) = Parse(json)
        Dim value As String = ReadString(data, "name")
        If String.IsNullOrWhiteSpace(value) Then value = fallback
        If value.Length > 80 Then value = value.Substring(0, 80)
        Return value
    End Function

    ' Nome dell'errore PayPal piu, se presente, il primo `details[0].issue` (es. UNPROCCESSABLE_ENTITY:AUTHORIZATION_EXPIRED). Solo per i metodi P1.
    Private Function ReadSafeErrorWithIssue(ByVal json As String, ByVal fallback As String) As String
        Dim data As IDictionary(Of String, Object) = Parse(json)
        Dim value As String = ReadString(data, "name")
        If String.IsNullOrWhiteSpace(value) Then value = fallback
        Dim details As IList = ReadList(data, "details")
        If details IsNot Nothing AndAlso details.Count > 0 Then
            Dim issue As String = ReadString(AsDictionary(details(0)), "issue")
            Dim safe As Boolean = issue.Length > 0 AndAlso issue.Length <= 60
            For Each ch As Char In issue
                If Not (ch >= "A"c AndAlso ch <= "Z"c) AndAlso Not (ch >= "0"c AndAlso ch <= "9"c) AndAlso ch <> "_"c Then safe = False
            Next
            If safe Then value &= ":" & issue
        End If
        If value.Length > 80 Then value = value.Substring(0, 80)
        Return value
    End Function

    ' Fallimento prima di inviare la chiamata (id non valido, configurazione, OAuth): nessun effetto remoto. statusCode = stato OAuth se noto.
    Private Shared Function Failure(ByVal code As String, Optional ByVal statusCode As Integer = 0) As PayPalOrdersV2Result
        Return New PayPalOrdersV2Result With {.Success = False, .NotSent = True, .StatusCode = statusCode, .ErrorCode = code, .Snapshot = New PayPalOrderSnapshot()}
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
