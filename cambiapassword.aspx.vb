Partial Class cambiapassword
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("LoginId") Is Nothing Then
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        Response.Redirect("password.aspx", True)
    End Sub
End Class
