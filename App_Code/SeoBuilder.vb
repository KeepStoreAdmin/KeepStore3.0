Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

' SeoBuilder: utility class for SEO meta tags + JSON-LD generation (VB.NET / .NET 4.x compatible)
Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    Private Const Q As String = """" ' double quote character (")
    Private Const BS As String = "\"  ' backslash character (\)

    ' -----------------------------
    ' JSON helpers
    ' -----------------------------
    Public Shared Function JsonEscape(ByVal s As String) As String
        If s Is Nothing Then Return String.Empty

        Dim sb As New StringBuilder(Math.Max(16, s.Length + 8))

        For Each ch As Char In s
            Select Case ch
                Case """"c
                    sb.Append(BS).Append(Q)
                Case "\"c
                    sb.Append(BS).Append(BS)
                Case ControlChars.Cr
                    sb.Append(BS).Append("r")
                Case ControlChars.Lf
                    sb.Append(BS).Append("n")
                Case ControlChars.Tab
                    sb.Append(BS).Append("t")
                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 Then
                        sb.Append(BS).Append("u").Append(code.ToString("x4"))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function

    ' -----------------------------
    ' <head> helpers
    ' -----------------------------
    Public Shared Sub EnsureCanonical(ByVal page As Page, ByVal canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrEmpty(canonicalUrl) Then Return

        Dim head As HtmlHead = page.Header
        Dim existing As HtmlLink = Nothing

        For Each c As Control In head.Controls
            Dim lnk As HtmlLink = TryCast(c, HtmlLink)
            If lnk IsNot Nothing Then
                Dim rel As String = Nothing
                If lnk.Attributes IsNot Nothing Then rel = lnk.Attributes("rel")
                If Not String.IsNullOrEmpty(rel) AndAlso String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    existing = lnk
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlLink()
            existing.Attributes("rel") = "canonical"
            head.Controls.Add(existing)
        End If

        existing.Href = canonicalUrl
    End Sub

    Public Shared Sub EnsureMetaName(ByVal page As Page, ByVal name As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrEmpty(name) Then Return
        If content Is Nothing Then content = String.Empty

        Dim head As HtmlHead = page.Header
        Dim existing As HtmlMeta = Nothing

        For Each c As Control In head.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                existing = m
                Exit For
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlMeta()
            existing.Name = name
            head.Controls.Add(existing)
        End If

        existing.Content = content
    End Sub

    Public Shared Sub EnsureMetaProperty(ByVal page As Page, ByVal prop As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrEmpty(prop) Then Return
        If content Is Nothing Then content = String.Empty

        Dim head As HtmlHead = page.Header
        Dim existing As HtmlMeta = Nothing

        For Each c As Control In head.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing Then
                Dim p As String = m.Attributes("property")
                If Not String.IsNullOrEmpty(p) AndAlso String.Equals(p, prop, StringComparison.OrdinalIgnoreCase) Then
                    existing = m
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlMeta()
            existing.Attributes("property") = prop
            head.Controls.Add(existing)
        End If

        existing.Content = content
    End Sub

    Public Shared Sub ApplyOpenGraphBasic(ByVal page As Page,
                                         ByVal pageUrl As String,
                                         ByVal title As String,
                                         ByVal description As String,
                                         ByVal imageUrl As String,
                                         Optional ByVal locale As String = "it_IT")
        EnsureMetaProperty(page, "og:type", "website")
        EnsureMetaProperty(page, "og:url", pageUrl)
        EnsureMetaProperty(page, "og:title", title)
        EnsureMetaProperty(page, "og:description", description)
        If Not String.IsNullOrEmpty(imageUrl) Then EnsureMetaProperty(page, "og:image", imageUrl)
        If Not String.IsNullOrEmpty(locale) Then EnsureMetaProperty(page, "og:locale", locale)

        EnsureMetaName(page, "twitter:card", If(String.IsNullOrEmpty(imageUrl), "summary", "summary_large_image"))
        EnsureMetaName(page, "twitter:title", title)
        EnsureMetaName(page, "twitter:description", description)
        If Not String.IsNullOrEmpty(imageUrl) Then EnsureMetaName(page, "twitter:image", imageUrl)
    End Sub

    ' -----------------------------
    ' JSON-LD builders (safe-by-default)
    ' -----------------------------
    Public Shared Function BuildHomeJsonLd(ByVal baseUrl As String,
                                          ByVal pageUrl As String,
                                          ByVal siteName As String,
                                          ByVal logoUrl As String,
                                          Optional ByVal organizationName As String = Nothing,
                                          Optional ByVal telephone As String = Nothing,
                                          Optional ByVal email As String = Nothing) As String

        If String.IsNullOrEmpty(organizationName) Then organizationName = siteName

        Dim orgId As String = baseUrl.TrimEnd("/"c) & "/#organization"
        Dim logoId As String = baseUrl.TrimEnd("/"c) & "/#logo"
        Dim websiteId As String = baseUrl.TrimEnd("/"c) & "/#website"
        Dim webpageId As String = pageUrl.TrimEnd("/"c) & "/#webpage"

        Dim sb As New StringBuilder(2048)

        sb.Append("{")
        sb.Append(Q).Append("@context").Append(Q).Append(":").Append(Q).Append("https://schema.org").Append(Q).Append(",")
        sb.Append(Q).Append("@graph").Append(Q).Append(":").Append("[")

        ' ImageObject logo (optional)
        If Not String.IsNullOrEmpty(logoUrl) Then
            sb.Append("{")
            sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ImageObject").Append(Q).Append(",")
            sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append(",")
            sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoUrl)).Append(Q)
            sb.Append("},")
        End If

        ' Organization
        sb.Append("{")
        sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Organization").Append(Q).Append(",")
        sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append(",")
        sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(organizationName)).Append(Q).Append(",")
        sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl)).Append(Q)

        If Not String.IsNullOrEmpty(logoUrl) Then
            sb.Append(",").Append(Q).Append("logo").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append("}")
        End If
        If Not String.IsNullOrEmpty(email) Then
            sb.Append(",").Append(Q).Append("email").Append(Q).Append(":").Append(Q).Append(JsonEscape(email)).Append(Q)
        End If
        If Not String.IsNullOrEmpty(telephone) Then
            sb.Append(",").Append(Q).Append("telephone").Append(Q).Append(":").Append(Q).Append(JsonEscape(telephone)).Append(Q)
        End If
        sb.Append("},")

        ' WebSite
        sb.Append("{")
        sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("WebSite").Append(Q).Append(",")
        sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(websiteId)).Append(Q).Append(",")
        sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl)).Append(Q).Append(",")
        sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(siteName)).Append(Q).Append(",")
        sb.Append(Q).Append("publisher").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append("}")
        sb.Append("},")

        ' WebPage
        sb.Append("{")
        sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("WebPage").Append(Q).Append(",")
        sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(webpageId)).Append(Q).Append(",")
        sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(pageUrl)).Append(Q).Append(",")
        sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(siteName)).Append(Q).Append(",")
        sb.Append(Q).Append("isPartOf").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(websiteId)).Append(Q).Append("}")
        sb.Append("}")

        sb.Append("]")
        sb.Append("}")

        Return sb.ToString()
    End Function

    ' -----------------------------
    ' Injection helper
    ' -----------------------------
    Public Shared Sub TrySetMasterJsonLd(ByVal page As Page, ByVal jsonLd As String)
        If page Is Nothing Then Return

        Dim m As Object = page.Master
        Dim seoMaster As ISeoMaster = TryCast(m, ISeoMaster)
        If seoMaster IsNot Nothing Then
            seoMaster.SeoJsonLd = jsonLd
            Return
        End If

        ' Fallback: try to find literal in master
        If m IsNot Nothing Then
            Dim lit As Control = m.FindControl("litSeoJsonLd")
            Dim l As Literal = TryCast(lit, Literal)
            If l IsNot Nothing Then
                l.Text = jsonLd
            End If
        End If
    End Sub

End Class
