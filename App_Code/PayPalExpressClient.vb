Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Net
Imports System.Text
Imports System.Web

Public Class PayPalExpressResponse
    Public Property Ack As String
    Public Property Token As String
    Public Property PayerId As String
    Public Property Amount As Decimal
    Public Property CurrencyCode As String
    Public Property Custom As String
    Public Property InvoiceNumber As String
    Public Property PaymentStatus As String
    Public Property TransactionId As String
    Public Property ErrorCode As String
    Public Property ShortMessage As String

    Public ReadOnly Property IsSuccess As Boolean
        Get
            Return String.Equals(Ack, "Success", StringComparison.OrdinalIgnoreCase) OrElse
                   String.Equals(Ack, "SuccessWithWarning", StringComparison.OrdinalIgnoreCase)
        End Get
    End Property

    Public ReadOnly Property IsCompletedPayment As Boolean
        Get
            Return String.Equals(PaymentStatus, "Completed", StringComparison.OrdinalIgnoreCase) OrElse
                   String.Equals(PaymentStatus, "Processed", StringComparison.OrdinalIgnoreCase) OrElse
                   String.Equals(PaymentStatus, "Eseguito", StringComparison.OrdinalIgnoreCase)
        End Get
    End Property

    Public ReadOnly Property IsPendingPayment As Boolean
        Get
            Return String.Equals(PaymentStatus, "Pending", StringComparison.OrdinalIgnoreCase) OrElse
                   String.Equals(PaymentStatus, "In-Progress", StringComparison.OrdinalIgnoreCase)
        End Get
    End Property
End Class

Public Class PayPalExpressClient
    Private Const PAYMENT_ACTION As String = "Sale"
    Private ReadOnly _config As PayPalCheckoutConfig

    Public Sub New(ByVal config As PayPalCheckoutConfig)
        _config = config
    End Sub

    Public Function SetExpressCheckout(ByVal doc As PayPalPaymentDocumentInfo, ByVal returnUrl As String, ByVal cancelUrl As String) As PayPalExpressResponse
        Dim fields As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)
        fields("PAYMENTREQUEST_0_PAYMENTACTION") = PAYMENT_ACTION
        fields("PAYMENTREQUEST_0_AMT") = FormatAmount(doc.TotalDocument)
        fields("PAYMENTREQUEST_0_CURRENCYCODE") = _config.CurrencyCode
        fields("PAYMENTREQUEST_0_INVNUM") = BuildInvoiceNumber(doc)
        fields("PAYMENTREQUEST_0_CUSTOM") = doc.DocumentId.ToString(CultureInfo.InvariantCulture)
        fields("RETURNURL") = returnUrl
        fields("CANCELURL") = cancelUrl
        fields("DESC") = BuildDescription(doc)
        fields("LOCALECODE") = "IT"

        If Not String.IsNullOrWhiteSpace(_config.BusinessAccount) Then
            fields("PAYMENTREQUEST_0_SELLERPAYPALACCOUNTID") = _config.BusinessAccount
        End If

        Return CallApi("SetExpressCheckout", fields)
    End Function

    Public Function GetExpressCheckoutDetails(ByVal token As String) As PayPalExpressResponse
        Dim fields As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)
        fields("TOKEN") = token
        Return CallApi("GetExpressCheckoutDetails", fields)
    End Function

    Public Function DoExpressCheckoutPayment(ByVal doc As PayPalPaymentDocumentInfo, ByVal token As String, ByVal payerId As String) As PayPalExpressResponse
        Dim fields As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)
        fields("TOKEN") = token
        fields("PAYERID") = payerId
        fields("PAYMENTREQUEST_0_PAYMENTACTION") = PAYMENT_ACTION
        fields("PAYMENTREQUEST_0_AMT") = FormatAmount(doc.TotalDocument)
        fields("PAYMENTREQUEST_0_CURRENCYCODE") = _config.CurrencyCode
        fields("PAYMENTREQUEST_0_INVNUM") = BuildInvoiceNumber(doc)
        fields("PAYMENTREQUEST_0_CUSTOM") = doc.DocumentId.ToString(CultureInfo.InvariantCulture)
        fields("PAYMENTREQUEST_0_DESC") = BuildDescription(doc)
        Return CallApi("DoExpressCheckoutPayment", fields)
    End Function

    Public Shared Function ExpectedInvoiceNumber(ByVal doc As PayPalPaymentDocumentInfo) As String
        Return BuildInvoiceNumber(doc)
    End Function

    Public Function BuildApprovalUrl(ByVal token As String) As String
        Return _config.RedirectBaseUrl & "?cmd=_express-checkout&token=" & HttpUtility.UrlEncode(token)
    End Function

    Private Function CallApi(ByVal methodName As String, ByVal fields As Dictionary(Of String, String)) As PayPalExpressResponse
        Dim result As New PayPalExpressResponse()

        Try
            EnsureTls12()

            fields("METHOD") = methodName
            fields("VERSION") = _config.Version
            fields("USER") = _config.ApiUsername
            fields("PWD") = _config.ApiPassword
            fields("SIGNATURE") = _config.ApiSignature

            Dim body As String = BuildFormBody(fields)
            Dim bodyBytes As Byte() = Encoding.UTF8.GetBytes(body)

            Dim req As HttpWebRequest = CType(WebRequest.Create(_config.ApiEndpoint), HttpWebRequest)
            req.Method = "POST"
            req.ContentType = "application/x-www-form-urlencoded"
            req.ContentLength = bodyBytes.Length
            req.Timeout = 30000
            req.ReadWriteTimeout = 30000

            Using reqStream As Stream = req.GetRequestStream()
                reqStream.Write(bodyBytes, 0, bodyBytes.Length)
            End Using

            Using resp As HttpWebResponse = CType(req.GetResponse(), HttpWebResponse)
                Using reader As New StreamReader(resp.GetResponseStream(), Encoding.UTF8)
                    Return ParseResponse(reader.ReadToEnd())
                End Using
            End Using
        Catch ex As Exception
            result.Ack = "Failure"
            result.ErrorCode = "LOCAL"
            result.ShortMessage = PayPalPaymentState.SanitizeOutcome(ex.GetType().Name)
        End Try

        Return result
    End Function

    Private Shared Function ParseResponse(ByVal raw As String) As PayPalExpressResponse
        Dim result As New PayPalExpressResponse()
        Dim values = HttpUtility.ParseQueryString(If(raw, ""))

        result.Ack = Convert.ToString(values("ACK"))
        result.Token = Convert.ToString(values("TOKEN"))
        result.PayerId = Convert.ToString(values("PAYERID"))
        result.CurrencyCode = Convert.ToString(values("PAYMENTREQUEST_0_CURRENCYCODE"))
        result.Custom = Convert.ToString(values("PAYMENTREQUEST_0_CUSTOM"))
        result.InvoiceNumber = Convert.ToString(values("PAYMENTREQUEST_0_INVNUM"))
        result.PaymentStatus = Convert.ToString(values("PAYMENTINFO_0_PAYMENTSTATUS"))
        result.TransactionId = Convert.ToString(values("PAYMENTINFO_0_TRANSACTIONID"))
        result.ErrorCode = Convert.ToString(values("L_ERRORCODE0"))
        result.ShortMessage = PayPalPaymentState.SanitizeOutcome(Convert.ToString(values("L_SHORTMESSAGE0")))

        Dim amountText As String = Convert.ToString(values("PAYMENTREQUEST_0_AMT"))
        Dim amount As Decimal
        If Decimal.TryParse(amountText, NumberStyles.Any, CultureInfo.InvariantCulture, amount) Then
            result.Amount = amount
        End If

        Return result
    End Function

    Private Shared Function BuildFormBody(ByVal fields As Dictionary(Of String, String)) As String
        Dim parts As New List(Of String)()
        For Each pair As KeyValuePair(Of String, String) In fields
            parts.Add(HttpUtility.UrlEncode(pair.Key, Encoding.UTF8) & "=" & HttpUtility.UrlEncode(If(pair.Value, ""), Encoding.UTF8))
        Next

        Return String.Join("&", parts.ToArray())
    End Function

    Private Shared Function FormatAmount(ByVal value As Decimal) As String
        Return Math.Round(value, 2, MidpointRounding.AwayFromZero).ToString("0.00", CultureInfo.InvariantCulture)
    End Function

    Private Shared Function BuildInvoiceNumber(ByVal doc As PayPalPaymentDocumentInfo) As String
        If doc.DocumentNumber > 0 AndAlso doc.DocumentDate <> DateTime.MinValue Then
            Return doc.DocumentNumber.ToString(CultureInfo.InvariantCulture) & "/" & doc.DocumentDate.Year.ToString(CultureInfo.InvariantCulture)
        End If

        Return doc.DocumentId.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Shared Function BuildDescription(ByVal doc As PayPalPaymentDocumentInfo) As String
        Return "Ordine KeepStore " & BuildInvoiceNumber(doc)
    End Function

    Private Shared Sub EnsureTls12()
        Try
            Const Tls12Value As SecurityProtocolType = DirectCast(&HC00, SecurityProtocolType)
            ServicePointManager.SecurityProtocol = ServicePointManager.SecurityProtocol Or Tls12Value
        Catch
        End Try
    End Sub
End Class
