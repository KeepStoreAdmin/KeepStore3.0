Imports System
Imports System.Web

Partial Class SiteHeader
    Inherits System.Web.UI.UserControl

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If Not Page.IsPostBack Then
            BindLogo()
        End If
    End Sub

    Private Sub BindLogo()
        ' Regola logo (template-friendly):
        ' 1) Se esiste Session("AziendaLogo") o Session("LogoWeb"), usa quello (supporta percorsi relativi o assoluti)
        ' 2) Altrimenti fallback al logo del template (assets)

        Dim logoUrl As String = TryCast(Session("AziendaLogo"), String)
        If String.IsNullOrWhiteSpace(logoUrl) Then
            logoUrl = TryCast(Session("LogoWeb"), String)
        End If

        If String.IsNullOrWhiteSpace(logoUrl) Then
            ' Fallback template
            logoUrl = ThemeManager.Asset("images/logo/logo.webp")
        End If

        ' Normalizza (assicurati che sia URL valido)
        logoUrl = NormalizeUrl(logoUrl)

        If imgLogo IsNot Nothing Then imgLogo.ImageUrl = logoUrl
        If imgLogoMobile IsNot Nothing Then imgLogoMobile.ImageUrl = logoUrl
        If imgLogoDrawer IsNot Nothing Then imgLogoDrawer.ImageUrl = logoUrl
    End Sub

    Private Function NormalizeUrl(ByVal url As String) As String
        If String.IsNullOrWhiteSpace(url) Then Return url

        Dim u As String = url.Trim()

        ' Se è già assoluto
        If u.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse u.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return u
        End If

        ' Se è relativo senza / iniziale, rendilo application-relative
        If Not u.StartsWith("/", StringComparison.OrdinalIgnoreCase) AndAlso Not u.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
            u = "/" & u
        End If

        ' Risolvi ~
        If u.StartsWith("~") Then
            Return ResolveUrl(u)
        End If

        Return u
    End Function
End Class
