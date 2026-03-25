Imports System
Imports System.Web

Partial Class cart_add
    Inherits AntiCsrfPage

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim articleId As Integer = 0
        Integer.TryParse(Convert.ToString(Request.QueryString("id")), articleId)

        If articleId <= 0 Then
            Response.Redirect("carrello.aspx", False)
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        Dim tcId As Integer = -1
        Integer.TryParse(Convert.ToString(Request.QueryString("TCid")), tcId)

        Dim qty As Decimal = 1D
        Decimal.TryParse(Convert.ToString(Request.QueryString("qty")), qty)
        If qty <= 0D Then qty = 1D

        Session("Carrello_ArticoloId") = articleId.ToString()
        Session("Carrello_TCId") = tcId.ToString()
        Session("Carrello_Quantita") = qty.ToString(System.Globalization.CultureInfo.InvariantCulture)
        Session("Carrello_Pagina") = If(Request.UrlReferrer IsNot Nothing, Request.UrlReferrer.PathAndQuery, "Default.aspx")

        Response.Redirect("aggiungi.aspx", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
