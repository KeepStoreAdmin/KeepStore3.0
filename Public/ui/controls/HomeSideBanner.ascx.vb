Partial Class UI_HomeSideBanner
    Inherits System.Web.UI.UserControl

    Public Property BannerOrder As Integer
    Public Property ExtraCssClass As String

    Protected Sub Page_Init(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Init
        Me.Visible = False
    End Sub
End Class
