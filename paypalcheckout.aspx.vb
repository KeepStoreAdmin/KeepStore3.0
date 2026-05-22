Imports System
Imports System.Globalization
Imports System.Web

Partial Class paypalcheckout
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If IsPostBack Then Return

        Dim documentId As Integer = GetQueryInt("id")
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
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture))
            Return
        End If

        If doc.PaymentState = 1 AndAlso PayPalPaymentState.IsExpressInProgressMarker(doc.TransactionId) Then
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        If doc.PaymentOnline <> PayPalPaymentState.PAYPAL_ONLINE_VALUE Then
            SafeKo(documentId, "PayPal: pagamento non coerente con il documento")
            Return
        End If

        If doc.TotalDocument <= 0D Then
            SafeKo(documentId, "PayPal: totale documento non valido")
            Return
        End If

        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.Load()
        If cfg Is Nothing OrElse Not cfg.IsExpressConfigured Then
            SafeKo(documentId, "PayPal Express: configurazione assente")
            Return
        End If

        If cfg.IsLive AndAlso Not cfg.AllowLive Then
            SafeKo(documentId, "PayPal Express: ambiente live non autorizzato")
            Return
        End If

        If Not cfg.CanCallApi Then
            SafeKo(documentId, "PayPal Express: configurazione non pronta")
            Return
        End If

        PayPalPaymentState.MarkPending(documentId, "PayPal Express: richiesta avvio pagamento")

        Dim client As New PayPalExpressClient(cfg)
        Dim setResult As PayPalExpressResponse = client.SetExpressCheckout(doc, BuildPayPalReturnUrl(documentId, "return"), BuildPayPalReturnUrl(documentId, "cancel"))
        If setResult Is Nothing OrElse Not setResult.IsSuccess OrElse String.IsNullOrWhiteSpace(setResult.Token) Then
            SafeKo(documentId, BuildApiFailureMessage("PayPal Express Set", setResult))
            Return
        End If

        PayPalPaymentState.MarkPendingWithExpressToken(documentId, "PayPal Express: token avvio pagamento creato", setResult.Token)
        SafeRedirect(client.BuildApprovalUrl(setResult.Token))
    End Sub

    Private Sub SafeKo(ByVal documentId As Integer, ByVal message As String)
        PayPalPaymentState.MarkFailed(documentId, message)
        SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
    End Sub

    Private Function GetQueryInt(ByVal key As String) As Integer
        Try
            Dim parsed As Integer
            If Integer.TryParse(Convert.ToString(Request.QueryString(key)), parsed) Then Return parsed
        Catch
        End Try

        Return 0
    End Function

    Private Function BuildPayPalReturnUrl(ByVal documentId As Integer, ByVal actionName As String) As String
        Dim baseUrl As String = "https://www.taikun.it"
        Try
            If Request IsNot Nothing AndAlso Request.Url IsNot Nothing Then
                baseUrl = Request.Url.GetLeftPart(UriPartial.Authority)
            End If
        Catch
        End Try

        Return baseUrl.TrimEnd("/"c) &
               "/paypalreturn.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) &
               "&action=" & HttpUtility.UrlEncode(actionName)
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

    Private Sub SafeRedirect(ByVal url As String)
        Try
            Response.Redirect(url, False)
            Context.ApplicationInstance.CompleteRequest()
        Catch
        End Try
    End Sub
End Class
