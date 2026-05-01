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

        Dim result As CartAddResult = CartAddService.AddProduct(HttpContext.Current,
                                                                articleId,
                                                                tcId,
                                                                Convert.ToDouble(qty),
                                                                freeShipping,
                                                                "cart_add.aspx")

        If Not result.Success Then
            Try
                KeepStoreLog.Info("cart_add.aspx", "Aggiunta carrello non riuscita id=" & articleId.ToString(CultureInfo.InvariantCulture) & " tcid=" & tcId.ToString(CultureInfo.InvariantCulture) & " msg=" & Convert.ToString(result.Message), HttpContext.Current)
            Catch
            End Try
        End If

        Response.Redirect("carrello.aspx", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
