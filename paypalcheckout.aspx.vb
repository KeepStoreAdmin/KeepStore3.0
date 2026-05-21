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

        If doc.PaymentOnline <> PayPalPaymentState.PAYPAL_ONLINE_VALUE Then
            SafeKo(documentId, "PayPal: pagamento non coerente con il documento")
            Return
        End If

        If doc.TotalDocument <= 0D Then
            SafeKo(documentId, "PayPal: totale documento non valido")
            Return
        End If

        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.Load()
        If cfg Is Nothing OrElse Not cfg.HasClientId OrElse Not cfg.HasClientSecret Then
            SafeKo(documentId, "PayPal: configurazione REST assente")
            Return
        End If

        If Not cfg.IsSandbox Then
            SafeKo(documentId, "PayPal: ambiente REST sandbox non configurato")
            Return
        End If

        ' PAYPAL-FLOW-4B is a sandbox-safe launcher skeleton only.
        ' No REST order is created here until capture/return handling is implemented.
        SafeKo(documentId, "PayPal: creazione ordine REST non ancora implementata")
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

    Private Sub SafeRedirect(ByVal url As String)
        Try
            Response.Redirect(url, False)
            Context.ApplicationInstance.CompleteRequest()
        Catch
        End Try
    End Sub
End Class
