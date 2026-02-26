Partial Class my_account_address
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Pagina protetta
        If Session("LoginId") Is Nothing Then
            Session("Pagina_visitata") = Request.Url
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If
    End Sub
End Class
