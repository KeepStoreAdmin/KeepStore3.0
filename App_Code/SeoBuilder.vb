Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Data.Common
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

' NOTE:
' - Questo file deve esistere UNA sola volta dentro /App_Code.
' - NON devono esserci copie tipo SeoBuilder_fix.vb, SeoBuilder_old.vb, ecc., altrimenti si innescano conflitti/compilazioni multiple.

Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    Private Const Q As Char = ChrW(34)   ' "
    Private Const BS As Char = ChrW(92)  ' \

    ' ===========================
    ' JSON string escaping (safe for JSON-LD)
    ' ===========================
    Public Shared Function JsonEscape(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim sb As New StringBuilder(value.Length + 16)

        For Each ch As Char In value
            Select Case ch
                Case Q
                    sb.Append(BS).Append(Q)
                Case BS
                    sb.Append(BS).Append(BS)
                Case ControlChars.Back
                    sb.Append(BS).Append("b")
                Case ControlChars.FormFeed
                    sb.Append(BS).Append("f")
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

    ' ===========================
    ' META / OG helpers
    ' ===========================
    Public Shared Sub AddOrReplaceMeta(ByVal page As Page, ByVal name As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrEmpty(name) Then Return

        Dim existing As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                existing = m
                Exit For
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlMeta()
            existing.Name = name
            page.Header.Controls.Add(existing)
        End If

        existing.Content = If(content, "")
    End Sub

    Public Shared Sub AddOrReplaceMetaProperty(ByVal page As Page, ByVal prop As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrEmpty(prop) Then Return

        Dim existing As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
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
            page.Header.Controls.Add(existing)
        End If

        existing.Content = If(content, "")
    End Sub

    Public Shared Sub SetCanonical(ByVal page As Page, ByVal canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrEmpty(canonicalUrl) Then Return

        Dim existing As HtmlLink = Nothing
        For Each c As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(c, HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = l.Attributes("rel")
                If Not String.IsNullOrEmpty(rel) AndAlso String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    existing = l
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlLink()
            existing.Attributes("rel") = "canonical"
            page.Header.Controls.Add(existing)
        End If

        existing.Href = canonicalUrl
    End Sub

    Public Shared Sub ApplyOpenGraph(ByVal page As Page,
                                    ByVal title As String,
                                    ByVal description As String,
                                    ByVal canonicalUrl As String,
                                    ByVal imageUrl As String)

        AddOrReplaceMetaProperty(page, "og:type", "website")
        AddOrReplaceMetaProperty(page, "og:title", If(title, ""))
        AddOrReplaceMetaProperty(page, "og:description", If(description, ""))
        AddOrReplaceMetaProperty(page, "og:url", If(canonicalUrl, ""))

        If Not String.IsNullOrEmpty(imageUrl) Then
            AddOrReplaceMetaProperty(page, "og:image", imageUrl)
        End If

        AddOrReplaceMeta(page, "twitter:card", If(String.IsNullOrEmpty(imageUrl), "summary", "summary_large_image"))
        AddOrReplaceMeta(page, "twitter:title", If(title, ""))
        AddOrReplaceMeta(page, "twitter:description", If(description, ""))
        If Not String.IsNullOrEmpty(imageUrl) Then
            AddOrReplaceMeta(page, "twitter:image", imageUrl)
        End If
    End Sub

    ' ===========================
    ' JSON-LD builders
    ' ===========================
    ' Ritorna il tag <script type="application/ld+json">...</script>
    Public Shared Function BuildHomeJsonLd(ByVal page As Page,
                                          ByVal title As String,
                                          ByVal description As String,
                                          ByVal canonicalUrl As String,
                                          ByVal logoUrl As String) As String

        Dim baseUrl As String = GetBaseUrl(page)
        If String.IsNullOrEmpty(baseUrl) Then baseUrl = canonicalUrl

        Dim orgId As String = CombineUrl(baseUrl, "#organization")
        Dim websiteId As String = CombineUrl(baseUrl, "#website")
        Dim webpageId As String = CombineUrl(canonicalUrl, "#webpage")
        Dim logoId As String = CombineUrl(baseUrl, "#logo")
        Dim searchTarget As String = CombineUrl(baseUrl, "articoli.aspx?q={search_term_string}")

        Dim json As New StringBuilder(2048)
        json.Append("{").Append(Q).Append("@context").Append(Q).Append(":").Append(Q).Append("https://schema.org").Append(Q).Append(",")
        json.Append(Q).Append("@graph").Append(Q).Append(":[")

        ' Organization
        json.Append("{")
        json.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Organization").Append(Q).Append(",")
        json.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append(",")
        json.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(GetSiteName())).Append(Q)

        If Not String.IsNullOrEmpty(logoUrl) Then
            json.Append(",").Append(Q).Append("logo").Append(Q).Append(":{")
            json.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q)
            json.Append("}")
        End If

        json.Append("},")

        ' Logo (ImageObject)
        If Not String.IsNullOrEmpty(logoUrl) Then
            json.Append("{")
            json.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ImageObject").Append(Q).Append(",")
            json.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append(",")
            json.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoUrl)).Append(Q)
            json.Append("},")
        End If

        ' WebSite + SearchAction
        json.Append("{")
        json.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("WebSite").Append(Q).Append(",")
        json.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(websiteId)).Append(Q).Append(",")
        json.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl)).Append(Q).Append(",")
        json.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(GetSiteName())).Append(Q).Append(",")
        json.Append(Q).Append("publisher").Append(Q).Append(":{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append("},")
        json.Append(Q).Append("potentialAction").Append(Q).Append(":{")
        json.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("SearchAction").Append(Q).Append(",")
        json.Append(Q).Append("target").Append(Q).Append(":").Append(Q).Append(JsonEscape(searchTarget)).Append(Q).Append(",")
        json.Append(Q).Append("query-input").Append(Q).Append(":").Append(Q).Append("required name=search_term_string").Append(Q)
        json.Append("}")
        json.Append("},")

        ' WebPage
        json.Append("{")
        json.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("WebPage").Append(Q).Append(",")
        json.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(webpageId)).Append(Q).Append(",")
        json.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(canonicalUrl)).Append(Q).Append(",")
        json.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(title)).Append(Q).Append(",")
        json.Append(Q).Append("description").Append(Q).Append(":").Append(Q).Append(JsonEscape(description)).Append(Q).Append(",")
        json.Append(Q).Append("isPartOf").Append(Q).Append(":{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(websiteId)).Append(Q).Append("}")
        json.Append("}")

        json.Append("]}")
        Return "<script type=" & Q & "application/ld+json" & Q & ">" & json.ToString() & "</script>"
    End Function

    ' ===========================
    ' JSON-LD injection helper
    ' ===========================
    Public Shared Sub SetJsonLdOnMaster(ByVal page As Page, ByVal jsonLdScript As String)
        If page Is Nothing Then Return

        ' Preferred: strongly-typed interface
        Dim mp As MasterPage = page.Master
        If mp IsNot Nothing Then
            Dim seoMp As ISeoMaster = TryCast(mp, ISeoMaster)
            If seoMp IsNot Nothing Then
                seoMp.SeoJsonLd = jsonLdScript
                Return
            End If

            ' Fallback: literal in master head
            Dim ctrl As Control = mp.FindControl("litSeoJsonLd")
            Dim lit As Literal = TryCast(ctrl, Literal)
            If lit IsNot Nothing Then
                lit.Text = jsonLdScript
            End If
        End If
    End Sub

    ' ===========================
    ' Utilities
    ' ===========================
    Private Shared Function GetBaseUrl(ByVal page As Page) As String
        Try
            If page Is Nothing OrElse page.Request Is Nothing OrElse page.Request.Url Is Nothing Then Return ""
            Dim u As Uri = page.Request.Url
            Dim baseUrl As String = u.Scheme & "://" & u.Authority & "/"
            Return baseUrl
        Catch
            Return ""
        End Try
    End Function

    Private Shared Function CombineUrl(ByVal baseUrl As String, ByVal relativeOrFragment As String) As String
        If String.IsNullOrEmpty(baseUrl) Then Return relativeOrFragment
        If String.IsNullOrEmpty(relativeOrFragment) Then Return baseUrl

        If relativeOrFragment.StartsWith("#") Then
            Dim b As String = baseUrl.TrimEnd("/"c)
            Return b & relativeOrFragment
        End If

        If baseUrl.EndsWith("/"c) Then
            Return baseUrl & relativeOrFragment.TrimStart("/"c)
        End If
        Return baseUrl & "/" & relativeOrFragment.TrimStart("/"c)
    End Function

    ' Se nel progetto esiste una Session/Config con nome sito, puoi adattare qui senza toccare altre parti.
    Private Shared Function GetSiteName() As String
        Try
            ' Preferenza: web.config appSettings
            Dim v As String = ConfigurationManager.AppSettings("SiteName")
            If Not String.IsNullOrEmpty(v) Then Return v
        Catch
        End Try
        Return "KeepStore"
    End Function

End Class
