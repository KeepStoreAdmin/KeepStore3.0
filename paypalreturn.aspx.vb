Imports System
Imports System.Globalization

Partial Class paypalreturn
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If IsPostBack Then Return

        Dim documentId As Integer = GetQueryInt("id")
        Dim status As String = Convert.ToString(Request.QueryString("status"))
        If status Is Nothing Then status = ""
        status = status.Trim()

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
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ok")
            Return
        End If

        If doc.PaymentOnline <> PayPalPaymentState.PAYPAL_ONLINE_VALUE Then
            PayPalPaymentState.MarkFailed(documentId, "PayPal: pagamento non coerente con il documento")
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        If String.Equals(status, "cancel", StringComparison.OrdinalIgnoreCase) Then
            PayPalPaymentState.MarkCanceled(documentId, "PayPal: pagamento annullato dall'utente")
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        If String.Equals(status, "ok", StringComparison.OrdinalIgnoreCase) Then
            PayPalPaymentState.MarkFailed(documentId, "PayPal: verifica pagamento non disponibile")
            SafeRedirect("documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=ko")
            Return
        End If

        PayPalPaymentState.MarkFailed(documentId, "PayPal: pagamento non completato")
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

    Private Sub SafeRedirect(ByVal url As String)
        Try
            Response.Redirect(url, False)
            Context.ApplicationInstance.CompleteRequest()
        Catch
        End Try
    End Sub
End Class
