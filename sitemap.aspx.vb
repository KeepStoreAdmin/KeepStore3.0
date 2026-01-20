Imports System
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Configuration
Imports System.Globalization

' STEP32 - Sitemap generator (static pages baseline)
' - Generates a valid XML sitemap at /sitemap.aspx
' - Uses current host (Request.Url) as base
' - Indexable URLs only (no account/cart/checkout)
' - Extendable via web.config AppSettings (optional)

Partial Public Class sitemap
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        ' Always serve XML
        Response.Clear()
        Response.ContentType = "application/xml"
        Response.ContentEncoding = Encoding.UTF8

        ' Light caching (best-effort)
        Try
            Response.Cache.SetCacheability(HttpCacheability.Public)
            Response.Cache.SetMaxAge(TimeSpan.FromHours(1))
            Response.Cache.SetExpires(DateTime.UtcNow.AddHours(1))
        Catch
        End Try

        Dim baseUrl As String = GetBaseUrl()
        Dim now As String = DateTime.UtcNow.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)

        Dim sb As New StringBuilder()
        sb.Append("<?xml version=""1.0"" encoding=""UTF-8""?>")
        sb.Append(vbCrLf)
        sb.Append("<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">")
        sb.Append(vbCrLf)

        ' 1) Static pages (safe defaults)
        Dim pages As String() = GetStaticPagesDefault()
        Dim changefreq As String = GetAppSetting("KeepStore.Sitemap.ChangeFreqDefault", "weekly")
        Dim priority As String = GetAppSetting("KeepStore.Sitemap.PriorityDefault", "0.6")

        Dim home As String = GetAppSetting("KeepStore.Sitemap.Home", "default.aspx")
        AddUrl(sb, baseUrl, home, now, "daily", "1.0")

        For Each p As String In pages
            If String.IsNullOrWhiteSpace(p) Then Continue For
            AddUrl(sb, baseUrl, p.Trim(), now, changefreq, priority)
        Next

        ' 2) Articoli listing (canonical listing page)
        ' Ensure only clean, indexable base URL (no filters)
        AddUrl(sb, baseUrl, "articoli.aspx", now, "daily", "0.9")

        ' NOTE: Product detail URLs are typically generated from DB.
        ' We intentionally do NOT enumerate products here to avoid wrong URLs.
        ' When you are ready, we can extend this to include:
        ' - category pages (ct)
        ' - brand pages (mr)
        ' - product pages (articolo.aspx?id=...)
        ' based on your real DB tables/queries.

        sb.Append("</urlset>")
        sb.Append(vbCrLf)

        Response.Write(sb.ToString())
        Response.End()
    End Sub

    Private Function GetBaseUrl() As String
        Try
            Dim u As Uri = Request.Url
            If u Is Nothing Then Return "https://www.taikun.it/"
            Dim left As String = u.GetLeftPart(UriPartial.Authority)
            If Not left.EndsWith("/") Then left &= "/"
            Return left
        Catch
            Return "https://www.taikun.it/"
        End Try
    End Function

    Private Function GetStaticPagesDefault() As String()
        ' Optional override from web.config:
        ' <add key="KeepStore.Sitemap.StaticPages" value="about.aspx;contact.aspx;privacy.aspx;faq.aspx" />
        Dim s As String = GetAppSetting("KeepStore.Sitemap.StaticPages", "")
        If Not String.IsNullOrWhiteSpace(s) Then
            Return s.Split(";"c)
        End If

        ' Safe defaults: include only pages typically present and public.
        ' If some do not exist, it is not harmful for sitemap consumers, but it is better to keep it accurate.
        Return New String() {
            "about.aspx",
            "contact.aspx",
            "privacy.aspx",
            "faq.aspx"
        }
    End Function

    Private Function GetAppSetting(ByVal key As String, ByVal defaultValue As String) As String
        Try
            Dim v As String = ConfigurationManager.AppSettings(key)
            If String.IsNullOrEmpty(v) Then Return defaultValue
            Return v.Trim()
        Catch
            Return defaultValue
        End Try
    End Function

    Private Sub AddUrl(ByVal sb As StringBuilder, ByVal baseUrl As String, ByVal relative As String, ByVal lastmod As String, ByVal changefreq As String, ByVal priority As String)
        Try
            Dim loc As String = CombineUrl(baseUrl, relative)

            sb.Append("  <url>")
            sb.Append(vbCrLf)
            sb.Append("    <loc>")
            sb.Append(HttpUtility.HtmlEncode(loc))
            sb.Append("</loc>")
            sb.Append(vbCrLf)
            sb.Append("    <lastmod>")
            sb.Append(lastmod)
            sb.Append("</lastmod>")
            sb.Append(vbCrLf)
            sb.Append("    <changefreq>")
            sb.Append(HttpUtility.HtmlEncode(changefreq))
            sb.Append("</changefreq>")
            sb.Append(vbCrLf)
            sb.Append("    <priority>")
            sb.Append(HttpUtility.HtmlEncode(priority))
            sb.Append("</priority>")
            sb.Append(vbCrLf)
            sb.Append("  </url>")
            sb.Append(vbCrLf)
        Catch
        End Try
    End Sub

    Private Function CombineUrl(ByVal baseUrl As String, ByVal relative As String) As String
        Try
            Dim r As String = relative
            If String.IsNullOrEmpty(r) Then Return baseUrl
            If r.StartsWith("/") Then r = r.Substring(1)
            Return baseUrl & r
        Catch
            Return baseUrl
        End Try
    End Function

End Class
