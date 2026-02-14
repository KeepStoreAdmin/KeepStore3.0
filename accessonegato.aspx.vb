
Partial Class accessonegato
    Inherits System.Web.UI.Page

    Protected Sub Page_LoadComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.LoadComplete
        If Not Me.Session("LoginId") Is Nothing Then
            Me.Response.Redirect("default.aspx")
        End If
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - Accesso Negato"
        Me.lblSito.Text = Me.Session("AziendaNome")
        Me.lblUrl.Text = Me.Session("AziendaUrl")
    End Sub
End Class
