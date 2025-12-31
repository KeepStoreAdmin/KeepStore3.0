
Partial Class registrazioneok
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
    End Sub


    Protected Sub Page_PreInit(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreInit
        Try
            If Request.QueryString("state") = "coupon" Then
                Page.MasterPageFile = "Coupon.master"
            Else
                Page.MasterPageFile = "Page.master"
            End If
        Catch
        End Try
    End Sub
End Class
