Partial Class Coupon
    Inherits System.Web.UI.MasterPage
    Implements ISeoMaster

    ' (Master dedicata ai flussi Coupon)
    Protected cont_settori As Integer = 0

    Public Property SeoJsonLd As String Implements ISeoMaster.SeoJsonLd

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        If Not Page.IsPostBack Then
            SeoJsonLd = Nothing
        End If
    End Sub

    Protected Sub Page_PreRender(sender As Object, e As EventArgs) Handles Me.PreRender
        If Not String.IsNullOrEmpty(SeoJsonLd) Then
            ' NB: qui si inietta il JSON-LD nel <head> del master Coupon
            litSeoJsonLd.Text = "<script type=""application/ld+json"">" & SeoJsonLd & "</script>"
        Else
            litSeoJsonLd.Text = ""
        End If
    End Sub
End Class
