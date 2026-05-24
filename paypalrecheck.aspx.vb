Imports System
Imports System.Globalization

Partial Class paypalrecheck
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

        Dim result As PayPalPendingRecheckResult = PayPalPaymentState.RecheckPendingPayment(documentId, utentiId)
        If result Is Nothing OrElse result.DocumentId <= 0 Then
            SafeRedirect("accessonegato.aspx")
            Return
        End If

        SafeRedirect("documentidettaglio.aspx?id=" & result.DocumentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=" & result.PayReturn)
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
