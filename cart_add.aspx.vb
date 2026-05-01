Imports System
Imports System.Globalization
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
        If tcId <= 0 Then tcId = -1

        Dim qty As Decimal = 1D
        Dim qtyRaw As String = Convert.ToString(Request.QueryString("qty"))
        If Not Decimal.TryParse(qtyRaw, NumberStyles.Any, CultureInfo.InvariantCulture, qty) Then
            Decimal.TryParse(qtyRaw, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), qty)
        End If
        If qty <= 0D Then qty = 1D

        Session("Carrello_ArticoloId") = articleId.ToString()
        Session("Carrello_TCId") = tcId.ToString()
        Session("Carrello_Quantita") = qty.ToString(System.Globalization.CultureInfo.InvariantCulture)
        Session("Carrello_Pagina") = If(Request.UrlReferrer IsNot Nothing, Request.UrlReferrer.PathAndQuery, "Default.aspx")
        Session("Carrello_SelezioneMultipla") = Nothing
        Session("Carrello_ListaArticoloId") = Nothing

        Response.Redirect("aggiungi.aspx", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
