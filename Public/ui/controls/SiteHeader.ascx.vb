Imports System
Imports System.IO
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

Partial Class SiteHeader
    Inherits System.Web.UI.UserControl

    Private Const DefaultLogoVirtual As String = "~/Public/assets/images/logo/logo.webp"
    Private Const DefaultMobileLogoVirtual As String = "~/Public/assets/images/logo/logo-mobile.webp"
    Private Const DefaultFaviconVirtual As String = "~/Public/assets/images/logo/favicon.ico"
    Private Const DefaultAppleTouchIconVirtual As String = "~/Public/assets/images/logo/apple-touch-icon.png"
    Private Const DefaultFavicon32Virtual As String = "~/Public/assets/images/logo/favicon-32x32.png"
    Private Const DefaultFavicon16Virtual As String = "~/Public/assets/images/logo/favicon-16x16.png"

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        BindLogo()
        EnsureHeadIcons()
    End Sub

    Private Sub BindLogo()
        Dim desktopLogo As String = TryCast(Session("AziendaLogo"), String)
        If String.IsNullOrWhiteSpace(desktopLogo) Then
            desktopLogo = TryCast(Session("LogoWeb"), String)
        End If
        If String.IsNullOrWhiteSpace(desktopLogo) Then
            desktopLogo = DefaultLogoVirtual
        End If

        Dim mobileLogo As String = TryCast(Session("AziendaLogoMobile"), String)
        If String.IsNullOrWhiteSpace(mobileLogo) Then
            mobileLogo = TryCast(Session("LogoWebMobile"), String)
        End If
        If String.IsNullOrWhiteSpace(mobileLogo) Then
            If FileExistsVirtual(DefaultMobileLogoVirtual) Then
                mobileLogo = DefaultMobileLogoVirtual
            Else
                mobileLogo = desktopLogo
            End If
        End If

        desktopLogo = NormalizeLogoUrl(desktopLogo)
        mobileLogo = NormalizeLogoUrl(mobileLogo)

        If imgLogo IsNot Nothing Then imgLogo.ImageUrl = desktopLogo
        If imgLogoMobile IsNot Nothing Then imgLogoMobile.ImageUrl = mobileLogo
        If imgLogoDrawer IsNot Nothing Then imgLogoDrawer.ImageUrl = mobileLogo
    End Sub

    Private Function NormalizeLogoUrl(ByVal url As String) As String
        Dim u As String = If(url, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(u) Then
            Return ResolveUrl(DefaultLogoVirtual)
        End If

        u = u.Replace("\", "/")

        If u.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           u.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
           u.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then
            Return u
        End If

        Dim lower As String = u.ToLowerInvariant()

        If lower.Contains("/public/assets/keepstore/images/") Then
            u = ReplaceInsensitive(u, "/Public/assets/keepstore/images/", "/Public/assets/images/")
        End If
        If lower.Contains("/public/assets/keepstore/img/") Then
            u = ReplaceInsensitive(u, "/Public/assets/keepstore/img/", "/Public/assets/images/")
        End If
        If lower.Contains("/public/images/") Then
            u = ReplaceInsensitive(u, "/Public/images/", "/Public/assets/images/logo/")
        End If
        If lower.StartsWith("images/logo/", StringComparison.OrdinalIgnoreCase) OrElse lower.StartsWith("logo/", StringComparison.OrdinalIgnoreCase) Then
            Dim logoFile As String = Path.GetFileName(u)
            If Not String.IsNullOrWhiteSpace(logoFile) Then
                u = "/Public/assets/images/logo/" & logoFile
            End If
        End If
        If lower.Contains("/public/assets/images/") AndAlso Not lower.Contains("/public/assets/images/logo/") Then
            Dim fileName As String = Path.GetFileName(u)
            If Not String.IsNullOrWhiteSpace(fileName) Then
                u = "/Public/assets/images/logo/" & fileName
            End If
        End If

        If Not u.Contains("/") AndAlso Not u.Contains("~") Then
            u = "/Public/assets/images/logo/" & u.TrimStart("/"c)
        End If

        If u.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
            Return ResolveUrl(u)
        End If

        If Not u.StartsWith("/", StringComparison.OrdinalIgnoreCase) Then
            u = "/" & u.TrimStart("/"c)
        End If

        Return u
    End Function

    Private Sub EnsureHeadIcons()
        If Page Is Nothing OrElse Page.Header Is Nothing Then Return

        EnsureLink("icon", ResolveUrl(DefaultFaviconVirtual))
        EnsureLink("shortcut icon", ResolveUrl(DefaultFaviconVirtual))

        If FileExistsVirtual(DefaultAppleTouchIconVirtual) Then
            EnsureLink("apple-touch-icon", ResolveUrl(DefaultAppleTouchIconVirtual))
        End If
        If FileExistsVirtual(DefaultFavicon32Virtual) Then
            EnsureLink("icon", ResolveUrl(DefaultFavicon32Virtual), "32x32", "image/png")
        End If
        If FileExistsVirtual(DefaultFavicon16Virtual) Then
            EnsureLink("icon", ResolveUrl(DefaultFavicon16Virtual), "16x16", "image/png")
        End If
    End Sub

    Private Sub EnsureLink(ByVal rel As String, ByVal href As String, Optional ByVal sizes As String = "", Optional ByVal mimeType As String = "")
        If Page Is Nothing OrElse Page.Header Is Nothing Then Return

        Dim existing As HtmlLink = Nothing
        For Each ctrl As Control In Page.Header.Controls
            Dim link As HtmlLink = TryCast(ctrl, HtmlLink)
            If link Is Nothing Then Continue For
            Dim currentRel As String = Convert.ToString(link.Attributes("rel"))
            Dim currentSizes As String = Convert.ToString(link.Attributes("sizes"))
            If String.Equals(currentRel, rel, StringComparison.OrdinalIgnoreCase) Then
                If String.IsNullOrWhiteSpace(sizes) OrElse String.Equals(currentSizes, sizes, StringComparison.OrdinalIgnoreCase) Then
                    existing = link
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlLink()
            Page.Header.Controls.Add(existing)
        End If

        existing.Attributes("rel") = rel
        existing.Href = href

        If String.IsNullOrWhiteSpace(sizes) Then
            existing.Attributes.Remove("sizes")
        Else
            existing.Attributes("sizes") = sizes
        End If

        If String.IsNullOrWhiteSpace(mimeType) Then
            existing.Attributes.Remove("type")
        Else
            existing.Attributes("type") = mimeType
        End If
    End Sub

    Private Function FileExistsVirtual(ByVal virtualPath As String) As Boolean
        Try
            Dim physical As String = Server.MapPath(virtualPath)
            Return File.Exists(physical)
        Catch
            Return False
        End Try
    End Function

    Private Function ReplaceInsensitive(ByVal input As String, ByVal search As String, ByVal replacement As String) As String
        Dim idx As Integer = input.IndexOf(search, StringComparison.OrdinalIgnoreCase)
        If idx < 0 Then Return input
        Return input.Substring(0, idx) & replacement & input.Substring(idx + search.Length)
    End Function
End Class
