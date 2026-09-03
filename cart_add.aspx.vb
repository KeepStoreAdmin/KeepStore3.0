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

        Dim freeShipping As Integer = 0
        Integer.TryParse(Convert.ToString(Request.QueryString("pg")), freeShipping)

        ' Endpoint quick-add: normalizza i parametri e rientra nel flusso storico
        ' di aggiungi.aspx, che gestisce listino, offerte, merge quantità e Newcarrello.
        Session("Carrello_ArticoloId") = articleId.ToString(CultureInfo.InvariantCulture)
        Session("Carrello_TCId") = tcId.ToString(CultureInfo.InvariantCulture)
        Session("Carrello_Quantita") = qty.ToString(CultureInfo.InvariantCulture)
        Session("ProdottoGratis") = freeShipping.ToString(CultureInfo.InvariantCulture)
        Dim cartReturnUrl As String = StorefrontReturnUrlPolicy.FirstValidShoppingReturnUrl(
            HttpContext.Current,
            Convert.ToString(Request.QueryString("ReturnUrl")),
            If(Request.UrlReferrer IsNot Nothing, Request.UrlReferrer.AbsoluteUri, String.Empty),
            Convert.ToString(Session("Carrello_Pagina")))
        Session("Carrello_Pagina") = If(cartReturnUrl <> String.Empty, cartReturnUrl, "/articoli.aspx")

        Dim redirectUrl As String = "aggiungi.aspx?id=" & articleId.ToString(CultureInfo.InvariantCulture) &
                                    "&TCid=" & tcId.ToString(CultureInfo.InvariantCulture) &
                                    "&qty=" & qty.ToString(CultureInfo.InvariantCulture)
        If freeShipping <> 0 Then
            redirectUrl &= "&pg=" & freeShipping.ToString(CultureInfo.InvariantCulture)
        End If

        Response.Redirect(redirectUrl, False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
