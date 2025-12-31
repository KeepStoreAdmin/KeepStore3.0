
Partial Class lista_coupon
    Inherits System.Web.UI.Page

    Public cont_clock As Integer = 0

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        SqlDataCoupon.SelectCommand = "SELECT * FROM vsupercoupon WHERE ((DATEDIFF(CURDATE(),DataInizio)>=0) AND (DATEDIFF(CURDATE(),DataFine)<=0))"
        sdsDocumenti.SelectParameters.Clear()
        If Request.QueryString("search") <> "" Then
            SqlDataCoupon.SelectCommand = SqlDataCoupon.SelectCommand + " AND (Titolo LIKE '%@search%')"
            SqlDataCoupon.SelectParameters.Add("@search", Request.QueryString("search"))
        End If

        'Nel caso di filtro su categoria
        If Val(Request.QueryString("ct")) > 0 Then
            SqlDataCoupon.SelectCommand = SqlDataCoupon.SelectCommand + " AND (idCategoria=@ct)"
            SqlDataCoupon.SelectParameters.Add("@ct", Request.QueryString("ct"))
        End If

        SqlDataCoupon.DataBind()
    End Sub
End Class
