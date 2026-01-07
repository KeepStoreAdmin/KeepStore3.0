Option Strict On
Option Explicit On

Imports System
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Imports System.Web.Script.Serialization

' ============================================================
' SeoBuilder.vb
' - VB.NET compatibile con .NET 4.x / VB 2012
' - Option Strict ON (no late binding / no conversioni implicite)
' - Helper SEO: meta, canonical, OpenGraph/Twitter, JSON-LD
'
' NOTE IMPORTANTE:
' - L'interfaccia ISeoMaster DEVE esistere UNA SOLA VOLTA nel progetto.
' - In questo file NON la dichiariamo per evitare conflitti (BC30175).
' ============================================================

' ============================================================
' Helper "globali" richiamabili anche SENZA prefisso da code-behind
' (evita BC30451 se Default.aspx.vb chiama AddOrReplaceMetaName ecc.)
' ============================================================
Public Module SeoHelpers

    Public Function SafeSessionString(ByVal key As String, ByVal defaultValue As String) As String
        Try
            Dim ctx As HttpContext = HttpContext.Current
            If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return defaultValue
            Dim o As Object = ctx.Session(key)
            If o Is Nothing Then Return defaultValue
            Dim s As String = Convert.ToString(o)
            If String.IsNullOrEmpty(s) Then Return defaultValue
            Return s
        Catch
            Return defaultValue
        End Try
    End Function

    Public Sub AddOrReplaceMetaName(ByVal name As String, ByVal content As String, Optional ByVal page As Page = Nothing)
        If page Is Nothing Then page = TryCast(HttpContext.Current.Handler, Page)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        SeoBuilder.AddOrReplaceMetaName(page, name, content)
    End Sub

    Public Sub AddOrReplaceMetaProperty(ByVal prop As String, ByVal content As String, Optional ByVal page As Page = Nothing)
        If page Is Nothing Then page = TryCast(HttpContext.Current.Handler, Page)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        SeoBuilder.AddOrReplaceMetaProperty(page, prop, content)
    End Sub

    Public Sub AddOrReplaceCanonical(ByVal canonicalUrl As String, Optional ByVal page As Page = Nothing)
        If page Is Nothing Then page = TryCast(HttpContext.Current.Handler, Page)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        SeoBuilder.AddOrReplaceCanonical(page, canonicalUrl)
    End Sub

    Public Sub AddOrReplaceJsonLd(ByVal jsonOrScript As String, Optional ByVal page As Page = Nothing)
        If page Is Nothing Then page = TryCast(HttpContext.Current.Handler, Page)
        If page Is Nothing Then Exit Sub
        SeoBuilder.AddOrReplaceJsonLd(page, jsonOrScript)
    End Sub

End Module

' ============================================================
' SeoBuilder core
' ============================================================
Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' ---------------------------
    ' JSON escaping (VB corretto)
    ' ---------------------------
    Public Shared Function JsonEscape(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim sb As New StringBuilder(value.Length + 16)

        For Each ch As Char In value
            Select Case ch
                Case """"c
                    ' \"  -> backslash + quote
                    sb.Append(ChrW(92)).Append(""""c)

                Case ChrW(92) ' backslash \
                    ' \\  -> backslash + backslash
                    sb.Append(ChrW(92)).Append(ChrW(92))

                Case ChrW(8)  ' backspace
                    sb.Append(ChrW(92)).Append("b"c)

                Case ChrW(12) ' form feed
                    sb.Append(ChrW(92)).Append("f"c)

                Case ChrW(10) ' LF
                    sb.Append(ChrW(92)).Append("n"c)

                Case ChrW(13) ' CR
                    sb.Append(ChrW(92)).Append("r"c)

                Case ChrW(9)  ' TAB
                    sb.Append(ChrW(92)).Append("t"c)

                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 Then
                        sb.Append("\u").Append(code.ToString("x4"))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function

    Private Shared Function SafeTrim(ByVal s As String) As String
        If s Is Nothing Then Return ""
        Return s.Trim()
    End Function

    Public Shared Function SafeSessionString(ByVal page As Page, ByVal key As String, ByVal defaultValue As String) As String
        Try
            If page Is Nothing OrElse page.Session Is Nothing Then Return defaultValue
            Dim o As Object = page.Session(key)
            If o Is Nothing Then Return defaultValue
            Dim s As String = Convert.ToString(o)
            If String.IsNullOrEmpty(s) Then Return defaultValue
            Return s
        Catch
            Return defaultValue
        End Try
    End Function

    ' ---------------------------
    ' URL helpers
    ' ---------------------------
    Private Shared Function ToAbsoluteUrl(ByVal page As Page, ByVal baseUrl As String, ByVal urlOrPath As String) As String
        Dim u As String = SafeTrim(urlOrPath)
        If u = "" Then Return ""

        If u.StartsWith("http://", StringComparison.OrdinalIgnoreCase) _
           OrElse u.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return u
        End If

        If u.StartsWith("//") Then
            Return "https:" & u
        End If

        ' ~/
        If u.StartsWith("~/", StringComparison.Ordinal) Then
            Dim rel As String = u.Substring(2)
            If Not baseUrl.EndsWith("/", StringComparison.Ordinal) Then baseUrl &= "/"
            Return baseUrl & rel
        End If

        ' /path
        If u.StartsWith("/", StringComparison.Ordinal) Then
            Dim root As String = baseUrl
            If root.EndsWith("/", StringComparison.Ordinal) Then
                root = root.Substring(0, root.Length - 1)
            End If
            Return root & u
        End If

        ' relative
        If Not baseUrl.EndsWith("/", StringComparison.Ordinal) Then baseUrl &= "/"
        Return baseUrl & u
    End Function

    ' ---------------------------
    ' HEAD tag helpers
    ' ---------------------------
    Public Shared Sub AddOrReplaceMetaName(ByVal page As Page, ByVal name As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        Dim n As String = SafeTrim(name)
        If n = "" Then Exit Sub

        Dim found As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, n, StringComparison.OrdinalIgnoreCase) Then
                found = m
                Exit For
            End If
        Next

        If found Is Nothing Then
            found = New HtmlMeta()
            found.Name = n
            page.Header.Controls.Add(found)
        End If

        found.Content = SafeTrim(content)
    End Sub

    Public Shared Sub AddOrReplaceMetaProperty(ByVal page As Page, ByVal prop As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        Dim p As String = SafeTrim(prop)
        If p = "" Then Exit Sub

        Dim found As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing Then
                Dim a As String = m.Attributes("property")
                If Not String.IsNullOrEmpty(a) AndAlso String.Equals(a, p, StringComparison.OrdinalIgnoreCase) Then
                    found = m
                    Exit For
                End If
            End If
        Next

        If found Is Nothing Then
            found = New HtmlMeta()
            found.Attributes("property") = p
            page.Header.Controls.Add(found)
        End If

        found.Content = SafeTrim(content)
    End Sub

    Public Shared Sub AddOrReplaceCanonical(ByVal page As Page, ByVal canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        Dim url As String = SafeTrim(canonicalUrl)
        If url = "" Then Exit Sub

        Dim found As HtmlLink = Nothing
        For Each c As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(c, HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = l.Attributes("rel")
                If Not String.IsNullOrEmpty(rel) AndAlso String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    found = l
                    Exit For
                End If
            End If
        Next

        If found Is Nothing Then
            found = New HtmlLink()
            found.Attributes("rel") = "canonical"
            page.Header.Controls.Add(found)
        End If

        found.Href = url
    End Sub

    Public Shared Sub ApplyOpenGraphAndTwitter(ByVal page As Page,
                                              ByVal canonicalUrl As String,
                                              ByVal titleText As String,
                                              ByVal descriptionText As String,
                                              ByVal imageUrl As String,
                                              ByVal siteName As String)

        Dim t As String = SafeTrim(titleText)
        Dim d As String = SafeTrim(descriptionText)
        Dim c As String = SafeTrim(canonicalUrl)
        Dim img As String = SafeTrim(imageUrl)
        Dim sn As String = SafeTrim(siteName)

        If sn = "" Then sn = "TAIKUN.IT"

        AddOrReplaceMetaProperty(page, "og:type", "website")
        AddOrReplaceMetaProperty(page, "og:locale", "it_IT")
        AddOrReplaceMetaProperty(page, "og:site_name", sn)

        If t <> "" Then AddOrReplaceMetaProperty(page, "og:title", t)
        If d <> "" Then AddOrReplaceMetaProperty(page, "og:description", d)
        If c <> "" Then AddOrReplaceMetaProperty(page, "og:url", c)

        If img <> "" Then
            AddOrReplaceMetaProperty(page, "og:image", img)
            AddOrReplaceMetaName(page, "twitter:card", "summary_large_image")
            AddOrReplaceMetaName(page, "twitter:image", img)
        Else
            AddOrReplaceMetaName(page, "twitter:card", "summary")
        End If

        If t <> "" Then AddOrReplaceMetaName(page, "twitter:title", t)
        If d <> "" Then AddOrReplaceMetaName(page, "twitter:description", d)
    End Sub

    ' ---------------------------
    ' JSON-LD injection
    ' ---------------------------
    Public Shared Sub AddOrReplaceJsonLd(ByVal page As Page, ByVal jsonOrScript As String)
        If page Is Nothing Then Exit Sub
        Dim s As String = If(jsonOrScript, "").Trim()
        If s = "" Then Exit Sub

        Dim payload As String = s
        If s.IndexOf("<script", StringComparison.OrdinalIgnoreCase) < 0 Then
            ' VB: le virgolette vanno raddoppiate, NON si usa \" nel literal
            payload = "<script type=""application/ld+json"">" & s & "</script>"
        End If

        ' Usa ISeoMaster SE presente (deve essere definita altrove una sola volta)
        Dim master As MasterPage = page.Master
        If master IsNot Nothing Then
            Try
                Dim typed As ISeoMaster = TryCast(master, ISeoMaster)
                If typed IsNot Nothing Then
                    typed.SeoJsonLd = payload
                    Exit Sub
                End If
            Catch
                ' ignore
            End Try
        End If

        If master IsNot Nothing Then
            Dim ctl As Control = master.FindControl("litSeoJsonLd")
            Dim lit As Literal = TryCast(ctl, Literal)
            If lit IsNot Nothing Then
                lit.Text = payload
            End If
        End If
    End Sub

    ' ---------------------------
    ' HOME JSON-LD (stabile, senza presupposti DB)
    ' ---------------------------
    Public Shared Function BuildHomeJsonLd(ByVal page As Page,
                                          ByVal baseUrl As String,
                                          ByVal canonicalUrl As String,
                                          ByVal titleText As String,
                                          ByVal descriptionText As String,
                                          ByVal ogImageUrl As String) As String

        Dim b As String = SafeTrim(baseUrl)
        If b = "" Then
            b = page.Request.Url.GetLeftPart(UriPartial.Authority) & page.ResolveUrl("~/")
        End If
        If Not b.EndsWith("/", StringComparison.Ordinal) Then b &= "/"

        Dim canonical As String = SafeTrim(canonicalUrl)
        If canonical = "" Then canonical = b

        Dim companyName As String = SafeSessionString(page, "AziendaNome", "TAIKUN.IT")
        Dim logoUrl As String = SafeSessionString(page, "AziendaLogo", "")
        Dim descr As String = SafeTrim(descriptionText)

        Dim absLogo As String = ToAbsoluteUrl(page, b, If(logoUrl, ""))
        Dim absOg As String = ToAbsoluteUrl(page, b, If(ogImageUrl, ""))

        If absOg = "" Then absOg = absLogo

        Dim orgId As String = b & "#organization"
        Dim webSiteId As String = b & "#website"
        Dim webPageId As String = canonical & "#webpage"

        Dim root As New Dictionary(Of String, Object)()
        root("@context") = "https://schema.org"

        Dim graph As New List(Of Object)()

        ' Organization
        Dim org As New Dictionary(Of String, Object)()
        org("@type") = "Organization"
        org("@id") = orgId
        org("name") = companyName
        org("url") = b
        If absLogo <> "" Then
            Dim logo As New Dictionary(Of String, Object)()
            logo("@type") = "ImageObject"
            logo("@id") = b & "#logo"
            logo("url") = absLogo
            logo("contentUrl") = absLogo
            logo("caption") = companyName & " logo"
            logo("inLanguage") = "it-IT"
            graph.Add(logo)

            org("logo") = New Dictionary(Of String, Object)() From {{"@id", b & "#logo"}}
            org("image") = New Dictionary(Of String, Object)() From {{"@id", b & "#logo"}}
        End If
        graph.Add(org)

        ' WebSite + SearchAction
        Dim website As New Dictionary(Of String, Object)()
        website("@type") = "WebSite"
        website("@id") = webSiteId
        website("url") = b
        website("name") = companyName
        website("inLanguage") = "it-IT"
        website("publisher") = New Dictionary(Of String, Object)() From {{"@id", orgId}}

        Dim search As New Dictionary(Of String, Object)()
        search("@type") = "SearchAction"
        search("target") = b & "articoli.aspx?q={search_term_string}"
        search("query-input") = "required name=search_term_string"
        website("potentialAction") = search

        graph.Add(website)

        ' WebPage (Home)
        Dim webpage As New Dictionary(Of String, Object)()
        webpage("@type") = "WebPage"
        webpage("@id") = webPageId
        webpage("url") = canonical
        webpage("name") = SafeTrim(titleText)
        If descr <> "" Then webpage("description") = descr
        webpage("inLanguage") = "it-IT"
        webpage("isPartOf") = New Dictionary(Of String, Object)() From {{"@id", webSiteId}}
        webpage("about") = New Dictionary(Of String, Object)() From {{"@id", orgId}}
        If absOg <> "" Then
            webpage("primaryImageOfPage") = New Dictionary(Of String, Object)() From {{"@id", b & "#ogimage"}}
            Dim ogImg As New Dictionary(Of String, Object)()
            ogImg("@type") = "ImageObject"
            ogImg("@id") = b & "#ogimage"
            ogImg("url") = absOg
            ogImg("contentUrl") = absOg
            ogImg("caption") = companyName
            ogImg("inLanguage") = "it-IT"
            graph.Add(ogImg)
        End If
        graph.Add(webpage)

        ' Breadcrumb (Home)
        Dim bc As New Dictionary(Of String, Object)()
        bc("@type") = "BreadcrumbList"
        bc("@id") = canonical & "#breadcrumb"

        Dim items As New List(Of Object)()
        Dim li1 As New Dictionary(Of String, Object)()
        li1("@type") = "ListItem"
        li1("position") = 1
        li1("name") = "Home"
        li1("item") = canonical
        items.Add(li1)

        bc("itemListElement") = items
        graph.Add(bc)

        root("@graph") = graph

        Dim ser As New JavaScriptSerializer()
        ser.MaxJsonLength = Integer.MaxValue
        Return ser.Serialize(root)
    End Function

End Class
