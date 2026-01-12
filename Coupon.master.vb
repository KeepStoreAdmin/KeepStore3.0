Partial Class Coupon
    Protected cont_settori As Integer = 0
    Inherits System.Web.UI.MasterPage
    Implements ISeoMaster

    Private _seoJsonLd As String = ""

    Public Property SeoJsonLd As String Implements ISeoMaster.SeoJsonLd
        Get
            Return _seoJsonLd
        End Get
        Set(value As String)
            _seoJsonLd = If(value, "")
            If litSeoJsonLd IsNot Nothing Then
                litSeoJsonLd.Text = _seoJsonLd
            End If
        End Set
    End Property

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        If Not Page.IsPostBack Then
            If litYear IsNot Nothing Then
                litYear.Text = DateTime.Now.Year.ToString()
            End If
        End If
    End Sub

    Protected Sub Page_PreRender(sender As Object, e As EventArgs) Handles Me.PreRender
        If litSeoJsonLd IsNot Nothing Then
            litSeoJsonLd.Text = SeoJsonLd
        End If
    End Sub

End Class