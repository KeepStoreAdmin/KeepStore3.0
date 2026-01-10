Imports System
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

' ======================================================================================
' SeoBuilder.vb
' - SEO / OpenGraph / JSON-LD helper for ASP.NET WebForms (.NET 4.x)
' - VB.NET ONLY (VB 2012 compiler friendly)
' - Does NOT require any custom interface on the MasterPage.
' - Injects JSON-LD via <asp:Literal ID="litSeoJsonLd" runat="server" /> in Page.master.
' ======================================================================================
Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' --------------------------
    ' PUBLIC: High level helpers
    ' --------------------------

    ' Backward-compatible wrapper (some pages may call this name).
    Public Shared Sub ApplyHomeSeo(page As Page)
        Dim title As String = If(page IsNot Nothing, page.Title, String.Empty)
        Dim canonical As String = GetCanonicalUrlFromRequest(page)
        Dim descr As String = If(String.IsNullOrWhiteSpace(title), "", title)
        Dim logo As String = ""
        ApplyHomeSeo(page, title, descr, canonical, logo)
    End Sub

    Public Shared Sub ApplyHomeSeo(page As Page, pageTitle As String, description As String, canonicalUrl As String, logoUrl As String)
        If page Is Nothing Then Return

        If Not String.IsNullOrWhiteSpace(pageTitle) Then
            page.Title = pageTitle
        End If

        canonicalUrl = NormalizeUrl(canonicalUrl)

        EnsureCanonical(page, canonicalUrl)
        EnsureMetaName(page, "description", description)
        EnsureMetaName(page, "robots", "index,follow,max-snippet:-1,max-image-preview:large,max-video-preview:-1")

        ApplyOpenGraph(page,
                       ogType:="website",
                       title:=page.Title,
                       description:=description,
                       url:=canonicalUrl,
                       imageUrl:=logoUrl)

        Dim jsonLd As String = BuildHomeJsonLd(page, page.Title, description, canonicalUrl, logoUrl)
        SetJsonLdOnMaster(page, jsonLd)
    End Sub

    ' Home JSON-LD (safe minimal @graph). Returns JSON ONLY (no <script>).
    Public Shared Function BuildHomeJsonLd(page As Page, pageTitle As String, description As String, canonicalUrl As String, logoUrl As String) As String
        Dim baseUrl As String = GetBaseUrlFromRequest(page)
        Dim siteName As String = GetSiteNameFromSession(page)

        Dim orgId As String = baseUrl.TrimEnd("/"c) & "#organization"
        Dim websiteId As String = baseUrl.TrimEnd("/"c) & "#website"
        Dim webpageId As String = NormalizeUrl(canonicalUrl).TrimEnd("/"c) & "#webpage"

        Dim sb As New StringBuilder(2048)
        sb.Append("{""@context"":""https://schema.org"",""@graph"":[")

        ' Organization
        sb.Append("{""@type"":""Organization""")
        sb.Append(",""@id"":""").Append(JsonEscape(orgId)).Append("""")
        sb.Append(",""name"":""").Append(JsonEscape(siteName)).Append("""")
        sb.Append(",""url"":""").Append(JsonEscape(baseUrl)).Append("""")
        If Not String.IsNullOrWhiteSpace(logoUrl) Then
            sb.Append(",""logo"":{ ""@type"":""ImageObject"",""url"":""").Append(JsonEscape(NormalizeUrl(logoUrl))).Append(""" }")
        End If
        sb.Append("}")

        sb.Append(",")

        ' WebSite
        sb.Append("{""@type"":""WebSite""")
        sb.Append(",""@id"":""").Append(JsonEscape(websiteId)).Append("""")
        sb.Append(",""url"":""").Append(JsonEscape(baseUrl)).Append("""")
        sb.Append(",""name"":""").Append(JsonEscape(siteName)).Append("""")
        sb.Append(",""publisher"":{ ""@id"":""").Append(JsonEscape(orgId)).Append(""" }")
        ' SearchAction (points to articoli.aspx?q={search_term_string} if available)
        Dim searchTarget As String = baseUrl.TrimEnd("/"c) & "/articoli.aspx?q={search_term_string}"
        sb.Append(",""potentialAction"":{ ""@type"":""SearchAction"",""target"":""").Append(JsonEscape(searchTarget)).Append(""",""query-input"":""required name=search_term_string"" }")
        sb.Append("}")

        sb.Append(",")

        ' WebPage
        sb.Append("{""@type"":""WebPage""")
        sb.Append(",""@id"":""").Append(JsonEscape(webpageId)).Append("""")
        sb.Append(",""url"":""").Append(JsonEscape(NormalizeUrl(canonicalUrl))).Append("""")
        sb.Append(",""name"":""").Append(JsonEscape(pageTitle)).Append("""")
        If Not String.IsNullOrWhiteSpace(description) Then
            sb.Append(",""description"":""").Append(JsonEscape(description)).Append("""")
        End If
        sb.Append(",""isPartOf"":{ ""@id"":""").Append(JsonEscape(websiteId)).Append(""" }")
        sb.Append(",""about"":{ ""@id"":""").Append(JsonEscape(orgId)).Append(""" }")
        sb.Append("}")

        sb.Append("]}")
        Return sb.ToString()
    End Function

    ' Product JSON-LD (returns JSON ONLY, no <script>). Provide as many fields as you have.
    Public Shared Function BuildProductJsonLd(productUrl As String,
                                              productName As String,
                                              productDescription As String,
                                              sku As String,
                                              imageUrl As String,
                                              price As Nullable(Of Decimal),
                                              currency As String,
                                              availabilityUrl As String) As String

        productUrl = NormalizeUrl(productUrl)
        imageUrl = NormalizeUrl(imageUrl)

        Dim sb As New StringBuilder(2048)
        sb.Append("{""@context"":""https://schema.org"",""@type"":""Product""")

        If Not String.IsNullOrWhiteSpace(productUrl) Then
            sb.Append(",""url"":""").Append(JsonEscape(productUrl)).Append("""")
        End If
        If Not String.IsNullOrWhiteSpace(productName) Then
            sb.Append(",""name"":""").Append(JsonEscape(productName)).Append("""")
        End If
        If Not String.IsNullOrWhiteSpace(productDescription) Then
            sb.Append(",""description"":""").Append(JsonEscape(productDescription)).Append("""")
        End If
        If Not String.IsNullOrWhiteSpace(sku) Then
            sb.Append(",""sku"":""").Append(JsonEscape(sku)).Append("""")
        End If
        If Not String.IsNullOrWhiteSpace(imageUrl) Then
            sb.Append(",""image"":[""").Append(JsonEscape(imageUrl)).Append("""]")
        End If

        If price.HasValue AndAlso price.Value > 0D Then
            Dim cur As String = If(String.IsNullOrWhiteSpace(currency), "EUR", currency.Trim().ToUpperInvariant())
            sb.Append(",""offers"":{ ""@type"":""Offer""")
            sb.Append(",""priceCurrency"":""").Append(JsonEscape(cur)).Append("""")
            sb.Append(",""price"":""").Append(price.Value.ToString("0.00", CultureInfo.InvariantCulture)).Append("""")
            If Not String.IsNullOrWhiteSpace(productUrl) Then
                sb.Append(",""url"":""").Append(JsonEscape(productUrl)).Append("""")
            End If
            If Not String.IsNullOrWhiteSpace(availabilityUrl) Then
                sb.Append(",""availability"":""").Append(JsonEscape(availabilityUrl)).Append("""")
            End If
            sb.Append("}")
        End If

        sb.Append("}")
        Return sb.ToString()
    End Function

    ' --------------------------
    ' PUBLIC: Meta + Canonical
    ' --------------------------

    Public Shared Sub EnsureCanonical(page As Page, canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return

        canonicalUrl = NormalizeUrl(canonicalUrl)
        If String.IsNullOrWhiteSpace(canonicalUrl) Then Return

        Dim existing As HtmlLink = Nothing
        For Each c As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(c, HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = If(l.Attributes("rel"), "")
                If String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    existing = l
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            Dim link As New HtmlLink()
            link.Attributes("rel") = "canonical"
            link.Href = canonicalUrl
            page.Header.Controls.Add(link)
        Else
            existing.Href = canonicalUrl
        End If
    End Sub

    Public Shared Sub EnsureMetaName(page As Page, name As String, content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrWhiteSpace(name) Then Return

        Dim existing As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                existing = m
                Exit For
            End If
        Next

        If existing Is Nothing Then
            Dim m As New HtmlMeta()
            m.Name = name
            m.Content = If(content, "")
            page.Header.Controls.Add(m)
        Else
            existing.Content = If(content, "")
        End If
    End Sub

    ' property="og:*" meta tags (uses HtmlMeta with Attributes("property")).
    Public Shared Sub EnsureMetaProperty(page As Page, prop As String, content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrWhiteSpace(prop) Then Return

        Dim existing As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing Then
                Dim p As String = If(m.Attributes("property"), "")
                If String.Equals(p, prop, StringComparison.OrdinalIgnoreCase) Then
                    existing = m
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            Dim m As New HtmlMeta()
            m.Attributes("property") = prop
            m.Content = If(content, "")
            page.Header.Controls.Add(m)
        Else
            existing.Content = If(content, "")
        End If
    End Sub

    Public Shared Sub ApplyOpenGraph(page As Page, ogType As String, title As String, description As String, url As String, imageUrl As String)
        If page Is Nothing Then Return

        EnsureMetaProperty(page, "og:type", If(ogType, "website"))
        If Not String.IsNullOrWhiteSpace(title) Then EnsureMetaProperty(page, "og:title", title)
        If Not String.IsNullOrWhiteSpace(description) Then EnsureMetaProperty(page, "og:description", description)
        If Not String.IsNullOrWhiteSpace(url) Then EnsureMetaProperty(page, "og:url", NormalizeUrl(url))
        If Not String.IsNullOrWhiteSpace(imageUrl) Then EnsureMetaProperty(page, "og:image", NormalizeUrl(imageUrl))
    End Sub

    ' --------------------------
    ' PUBLIC: JSON-LD injection
    ' --------------------------

    ' Accepts JSON ONLY (recommended). If you pass a <script> tag, it will be used as-is.
    Public Shared Sub SetJsonLdOnMaster(page As Page, jsonOrScript As String)
        If page Is Nothing Then Return

        Dim lit As Literal = TryCast(FindControlRecursive(page.Master, "litSeoJsonLd"), Literal)
        If lit Is Nothing Then
            ' Fallback: try Page.Header (still works without master literal)
            If page.Header IsNot Nothing Then
                InjectJsonLdIntoHeader(page, jsonOrScript)
            End If
            Return
        End If

        If String.IsNullOrWhiteSpace(jsonOrScript) Then
            lit.Text = ""
            Return
        End If

        Dim txt As String = jsonOrScript.Trim()
        If txt.StartsWith("<script", StringComparison.OrdinalIgnoreCase) Then
            lit.Text = txt
        Else
            lit.Text = "<script type=""application/ld+json"">" & txt & "</script>"
        End If
    End Sub

    ' --------------------------
    ' INTERNAL helpers
    ' --------------------------

    Private Shared Sub InjectJsonLdIntoHeader(page As Page, jsonOrScript As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return

        ' Remove any previous JSON-LD script we injected (by id)
        Dim toRemove As Control = Nothing
        For Each c As Control In page.Header.Controls
            Dim s As HtmlGenericControl = TryCast(c, HtmlGenericControl)
            If s IsNot Nothing AndAlso String.Equals(s.TagName, "script", StringComparison.OrdinalIgnoreCase) Then
                Dim t As String = If(s.Attributes("type"), "")
                Dim id As String = If(s.Attributes("id"), "")
                If String.Equals(id, "jsonld", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(t, "application/ld+json", StringComparison.OrdinalIgnoreCase) Then
                    toRemove = c
                    Exit For
                End If
            End If
        Next
        If toRemove IsNot Nothing Then page.Header.Controls.Remove(toRemove)

        Dim json As String = jsonOrScript
        If String.IsNullOrWhiteSpace(json) Then Return

        Dim scriptTag As New HtmlGenericControl("script")
        scriptTag.Attributes("type") = "application/ld+json"
        scriptTag.Attributes("id") = "jsonld"

        Dim txt As String = json.Trim()
        If txt.StartsWith("<script", StringComparison.OrdinalIgnoreCase) Then
            ' If they already provided a full script, just output as literal control.
            Dim lit As New Literal()
            lit.Text = txt
            page.Header.Controls.Add(lit)
        Else
            scriptTag.InnerHtml = txt
            page.Header.Controls.Add(scriptTag)
        End If
    End Sub

    Private Shared Function FindControlRecursive(root As Control, id As String) As Control
        If root Is Nothing OrElse String.IsNullOrEmpty(id) Then Return Nothing
        Dim c As Control = root.FindControl(id)
        If c IsNot Nothing Then Return c

        For Each child As Control In root.Controls
            c = FindControlRecursive(child, id)
            If c IsNot Nothing Then Return c
        Next

        Return Nothing
    End Function

    Private Shared Function GetBaseUrlFromRequest(page As Page) As String
        Try
            If page Is Nothing OrElse page.Request Is Nothing OrElse page.Request.Url Is Nothing Then Return ""
            Dim u As Uri = page.Request.Url
            Dim portPart As String = If(u.IsDefaultPort, "", ":" & u.Port.ToString(CultureInfo.InvariantCulture))
            Return u.Scheme & "://" & u.Host & portPart
        Catch
            Return ""
        End Try
    End Function

    Private Shared Function GetCanonicalUrlFromRequest(page As Page) As String
        Try
            If page Is Nothing OrElse page.Request Is Nothing OrElse page.Request.Url Is Nothing Then Return ""
            Return page.Request.Url.GetLeftPart(UriPartial.Path)
        Catch
            Return ""
        End Try
    End Function

    Private Shared Function GetSiteNameFromSession(page As Page) As String
        Try
            If page Is Nothing OrElse page.Session Is Nothing Then Return "KeepStore"
            Dim s As Object = page.Session("AziendaNome")
            Dim name As String = If(TryCast(s, String), "")
            If String.IsNullOrWhiteSpace(name) Then name = "KeepStore"
            Return name
        Catch
            Return "KeepStore"
        End Try
    End Function

    Public Shared Function NormalizeUrl(url As String) As String
        If String.IsNullOrWhiteSpace(url) Then Return ""
        Return url.Trim()
    End Function
    
    Public Shared Function BuildSimplePageJsonLd(pageTitle As String,
                                             pageDescription As String,
                                             canonicalUrl As String,
                                             pageType As String) As String
    Dim t As String = If(String.IsNullOrWhiteSpace(pageType), "WebPage", pageType.Trim())
    Dim name As String = If(pageTitle, "").Trim()
    Dim descr As String = If(pageDescription, "").Trim()
    Dim url As String = NormalizeUrl(canonicalUrl)

    Dim sb As New StringBuilder()
    sb.Append("{")
    sb.Append("""@context"":""https://schema.org"",")
    sb.Append("""@type"":""").Append(JsonEscape(t)).Append(""",")
    sb.Append("""name"":""").Append(JsonEscape(name)).Append("""")

    If Not String.IsNullOrWhiteSpace(descr) Then
        sb.Append(",").Append("""description"":""").Append(JsonEscape(descr)).Append("""")
    End If
    If Not String.IsNullOrWhiteSpace(url) Then
        sb.Append(",").Append("""url"":""").Append(JsonEscape(url)).Append("""")
    End If

    sb.Append("}")
    Return sb.ToString()
    End Function

    ' JSON string escape safe for schema.org payloads.
    Public Shared Function JsonEscape(value As String) As String
    If String.IsNullOrEmpty(value) Then Return ""

    Dim sb As New StringBuilder(value.Length + 16)

    For Each ch As Char In value
        Select Case ch

            Case "\"c
                ' JSON escape for a backslash character => "\\"
                sb.Append("\"c).Append("\"c)

            Case """"c
                ' JSON escape for a quote character => "\""
                sb.Append("\"c).Append(""""c)

            Case ControlChars.Cr
                sb.Append("\r")

            Case ControlChars.Lf
                sb.Append("\n")

            Case ControlChars.Tab
                sb.Append("\t")

            Case ControlChars.Back
                sb.Append("\b")

            Case ControlChars.FormFeed
                sb.Append("\f")

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

End Class
