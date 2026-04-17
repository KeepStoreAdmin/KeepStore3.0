Partial Class UI_HomeSideBanner
    Inherits System.Web.UI.UserControl

    Public Property BannerOrder As Integer
        Get
            Return 0
        End Get
        Set(ByVal value As Integer)
        End Set
    End Property

    Public Property ExtraCssClass As String
        Get
            Return String.Empty
        End Get
        Set(ByVal value As String)
        End Set
    End Property

    Protected Sub Page_Init(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Init
        Me.Visible = False
    End Sub
End Class
