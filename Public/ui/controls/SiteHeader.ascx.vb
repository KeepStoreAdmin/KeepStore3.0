Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

Partial Class SiteHeader
    Inherits System.Web.UI.UserControl

    Private Const DefaultLogoVirtual As String = "~/Public/assets/images/logo/logo.webp"
    Private Const DefaultMobileLogoVirtual As String = "~/Public/assets/images/logo/logo-mobile.webp"
    Private Const DefaultFaviconVirtual As String = "~/Public/assets/images/favicons/favicon.ico"
    Private Const DefaultAppleTouchIconVirtual As String = "~/Public/assets/images/favicons/apple-touch-icon.png"
    Private Const DefaultFavicon32Virtual As String = "~/Public/assets/images/favicons/favicon-32x32.png"
    Private Const DefaultFavicon16Virtual As String = "~/Public/assets/images/favicons/favicon-16x16.png"
    Private Const LoginVirtual As String = "/login.aspx"
    Private Const MyAccountVirtual As String = "/myaccount.aspx"

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        BindLogo()
        BindAccountLinks()
        RegisterHeadIconsScript()
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As EventArgs) Handles Me.PreRender
        BindAccountLinks()
    End Sub

    Private Sub BindAccountLinks()
        Dim isLogged As Boolean = False
        Dim loginIdVal As Integer = 0

        If Session("LoginId") IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(Session("LoginId")), loginIdVal) AndAlso loginIdVal > 0 Then
            isLogged = True
        ElseIf Session("LoginID") IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(Session("LoginID")), loginIdVal) AndAlso loginIdVal > 0 Then
            isLogged = True
        End If

        Dim accountUrl As String = If(isLogged, ResolveUrl("~/myaccount.aspx"), ResolveUrl("~/login.aspx"))

        If lnkAccount IsNot Nothing Then
            lnkAccount.HRef = accountUrl
            lnkAccount.Attributes("href") = accountUrl
        End If
        If lnkAccountMobile IsNot Nothing Then
            lnkAccountMobile.HRef = accountUrl
            lnkAccountMobile.Attributes("href") = accountUrl
        End If
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

        If lower.Contains("/public/assets/images/favicons/") Then
            Dim logoFile As String = Path.GetFileName(u)
            If Not String.IsNullOrWhiteSpace(logoFile) Then
                u = "/Public/assets/images/logo/" & logoFile
            End If
            lower = u.ToLowerInvariant()
        End If
        If lower.Contains("/public/assets/images/logo/") Then
            u = ReplaceInsensitive(u, "/Public/assets/images/logo/", "/Public/assets/images/logo/")
            lower = u.ToLowerInvariant()
        End If
        If lower.Contains("/public/images/") Then
            u = ReplaceInsensitive(u, "/Public/images/", "/Public/assets/images/logo/")
            lower = u.ToLowerInvariant()
        End If
        If lower.StartsWith("images/logo/", StringComparison.OrdinalIgnoreCase) OrElse
           lower.StartsWith("logo/", StringComparison.OrdinalIgnoreCase) OrElse
           lower.StartsWith("images/favicons/", StringComparison.OrdinalIgnoreCase) OrElse
           lower.StartsWith("favicons/", StringComparison.OrdinalIgnoreCase) Then
            Dim logoFile As String = Path.GetFileName(u)
            If Not String.IsNullOrWhiteSpace(logoFile) Then
                u = "/Public/assets/images/logo/" & logoFile
            End If
        End If
        If lower.Contains("/public/assets/images/") AndAlso Not lower.Contains("/public/assets/images/logo/") AndAlso Not lower.Contains("/public/assets/images/favicons/") Then
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

    Private Sub RegisterHeadIconsScript()
        If Page Is Nothing Then Return

        Dim script As String = BuildHeadIconsScript()
        If String.IsNullOrWhiteSpace(script) Then Return

        Dim sm As ScriptManager = ScriptManager.GetCurrent(Page)
        If sm IsNot Nothing Then
            ScriptManager.RegisterStartupScript(Page, Page.GetType(), "ksHeadIcons", script, True)
        Else
            Page.ClientScript.RegisterStartupScript(Page.GetType(), "ksHeadIcons", script, True)
        End If
    End Sub

    Private Function BuildHeadIconsScript() As String
        Dim links As New List(Of String)()

        links.Add(BuildHeadLinkScript("icon", ResolveUrl(DefaultFaviconVirtual), "", "image/x-icon"))
        links.Add(BuildHeadLinkScript("shortcut icon", ResolveUrl(DefaultFaviconVirtual), "", "image/x-icon"))

        If FileExistsVirtual(DefaultAppleTouchIconVirtual) Then
            links.Add(BuildHeadLinkScript("apple-touch-icon", ResolveUrl(DefaultAppleTouchIconVirtual), "", "image/png"))
        End If
        If FileExistsVirtual(DefaultFavicon32Virtual) Then
            links.Add(BuildHeadLinkScript("icon", ResolveUrl(DefaultFavicon32Virtual), "32x32", "image/png"))
        End If
        If FileExistsVirtual(DefaultFavicon16Virtual) Then
            links.Add(BuildHeadLinkScript("icon", ResolveUrl(DefaultFavicon16Virtual), "16x16", "image/png"))
        End If

        Dim sb As New StringBuilder()
        Dim hasCommands As Boolean = False
        sb.AppendLine("(function(){")
        sb.AppendLine("function ksUpsertHeadLink(rel, href, sizes, type){")
        sb.AppendLine("if(!href){return;}")
        sb.AppendLine("var head=document.head||document.getElementsByTagName('head')[0];")
        sb.AppendLine("if(!head){return;}")
        sb.AppendLine("var links=head.getElementsByTagName('link');")
        sb.AppendLine("var match=null;")
        sb.AppendLine("var desiredSizes=sizes||'';")
        sb.AppendLine("for(var i=0;i<links.length;i++){")
        sb.AppendLine("var current=links[i];")
        sb.AppendLine("var currentRel=(current.getAttribute('rel')||'').toLowerCase();")
        sb.AppendLine("var currentSizes=current.getAttribute('sizes')||'';")
        sb.AppendLine("if(currentRel===String(rel||'').toLowerCase() && currentSizes===desiredSizes){match=current;break;}")
        sb.AppendLine("}")
        sb.AppendLine("if(!match){match=document.createElement('link');head.appendChild(match);}")
        sb.AppendLine("match.setAttribute('rel', rel);")
        sb.AppendLine("match.setAttribute('href', href);")
        sb.AppendLine("if(desiredSizes){match.setAttribute('sizes', desiredSizes);}else{match.removeAttribute('sizes');}")
        sb.AppendLine("if(type){match.setAttribute('type', type);}else{match.removeAttribute('type');}")
        sb.AppendLine("}")
        For Each cmd As String In links
            If Not String.IsNullOrWhiteSpace(cmd) Then
                sb.AppendLine(cmd)
                hasCommands = True
            End If
        Next
        If Not hasCommands Then Return String.Empty
        sb.AppendLine("})();")
        Return sb.ToString()
    End Function

    Private Function BuildHeadLinkScript(ByVal rel As String, ByVal href As String, ByVal sizes As String, ByVal mimeType As String) As String
        If String.IsNullOrWhiteSpace(href) Then Return String.Empty
        Return "ksUpsertHeadLink('" & Js(rel) & "','" & Js(href) & "','" & Js(sizes) & "','" & Js(mimeType) & "');"
    End Function

    Private Function Js(ByVal value As String) As String
        Return HttpUtility.JavaScriptStringEncode(If(value, String.Empty))
    End Function

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
