' /App_Code/SeoBuilder.vb
' ============================================================
' SEO Builder (KeepStore 3.0) - WebForms safe (VB.NET)
' - Canonical, Meta, OpenGraph, JSON-LD
' - Compatibilità: espone i metodi chiamati da Default.aspx.vb:
'     BuildHomeJsonLd(...)
'     SetJsonLdOnMaster(...)
' - FIX: nessuna dichiarazione ISeoMaster qui (evita conflitti BC30175)
' ============================================================

Imports System
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.UI.HtmlControls

Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' ============================================================
    ' ENTRYPOINTS (compatibili con le chiamate esistenti)
    ' ============================================================

    ' Alcune parti del progetto chiamano:
    '   SeoBuilder.ApplyHomeSeo(Me.Page)
    Public Shared Sub ApplyHomeSeo(ByVal page As Page)
        If page Is Nothing Then Return

        Dim canonical As String = BuildHomeCanonical(page)
        Dim title As String = BuildHomeTitle(page)
        Dim description As String = BuildHomeDescription(page)

        ApplyBasicSeo(page, title, description, canonical)
        ApplyOpenGraph(page, title, description, canonical, Nothing)

        Dim jsonLd As String = BuildHomeJsonLd(page, title, description, canonical, Nothing)
        SetJsonLdOnMaster(page, jsonLd)
    End Sub

    ' ============================================================
    ' METODI RICHIESTI DAL TUO Default.aspx.vb (FIRME ESATTE)
    ' ============================================================

    ' Default.aspx.vb chiama:
    '   SeoBuilder.BuildHomeJsonLd(Me, pageTitle, descr, canonical, logoUrl)
    ' Deve ritornare una stringa JSON (non necessariamente <script>).
    Public Shared Function BuildHomeJsonLd(ByVal page As Page,
                                          ByVal pageTitle As String,
                                          ByVal description As String,
                                          ByVal canonicalUrl As String,
                                          ByVal logoUrl As String) As String

        If page Is Nothing Then Return ""

        Dim baseUrl As String = GetBaseUrl(page)
        Dim siteName As String = GetSiteName(page)
        Dim searchTarget As String = baseUrl & "articoli.aspx?q={search_term_string}"

        If String.IsNullOrWhiteSpace(canonicalUrl) Then
            canonicalUrl = BuildHomeCanonical(page)
        End If

        Dim sb As New StringBuilder(4096)

        sb.Append("{")
        sb.Append("""@context"":""https://schema.org"",")
        sb.Append("""@graph"":[")

        ' Organization
        sb.Append("{")
        sb.Append("""@type"":""Organization"",")
        sb.Append("""@id"":""" & JsonString(baseUrl & "#org") & """,")
        sb.Append("""name"":" & JsonString(If(String.IsNullOrWhiteSpace(siteName), "KeepStore", siteName)) & ",")
        sb.Append("""url"":""" & JsonString(baseUrl) & """")

        If Not String.IsNullOrWhiteSpace(logoUrl) Then
            sb.Append(",""logo"":{""@type"":""ImageObject"",""url"":""" & JsonString(logoUrl.Trim()) & """}")
        End If

        sb.Append("},")

        ' WebSite + SearchAction
        sb.Append("{")
        sb.Append("""@type"":""WebSite"",")
        sb.Append("""@id"":""" & JsonString(baseUrl & "#website") & """,")
        sb.Append("""url"":""" & JsonString(baseUrl) & """,")
        sb.Append("""name"":" & JsonString(If(String.IsNullOrWhiteSpace(siteName), "KeepStore", siteName)) & ",")
        sb.Append("""potentialAction"":[{")
        sb.Append("""@type"":""SearchAction"",")
        sb.Append("""target"":""" & JsonString(searchTarget) & """,")
        sb.Append("""query-input"":""required name=search_term_string""")
        sb.Append("}]")
        sb.Append("},")

        ' WebPage
        sb.Append("{")
        sb.Append("""@type"":""WebPage"",")
        sb.Append("""@id"":""" & JsonString(canonicalUrl.Trim() & "#webpage") & """,")
        sb.Append("""url"":""" & JsonString(canonicalUrl.Trim()) & """,")

        Dim safeTitle As String = If(String.IsNullOrWhiteSpace(pageTitle), BuildHomeTitle(page), pageTitle).Trim()
        Dim safeDescr As String = If(String.IsNullOrWhiteSpace(description), BuildHomeDescription(page), description).Trim()

        sb.Append("""name"":" & JsonString(safeTitle) & ",")
        sb.Append("""description"":" & JsonString(safeDescr) & ",")
        sb.Append("""isPartOf"":{""@id"":""" & JsonString(baseUrl & "#website") & """}")
        sb.Append("},")

        ' BreadcrumbList (Home)
        sb.Append("{")
        sb.Append("""@type"":""BreadcrumbList"",")
        sb.Append("""@id"":""" & JsonString(canonicalUrl.Trim() & "#breadcrumb") & """,")
        sb.Append("""itemListElement"":[")
        sb.Append("{""@type"":""ListItem"",""position"":1,""name"":""Home"",""item"":""" & JsonString(baseUrl) & """}")
        sb.Append("]")
        sb.Append("}")

        sb.Append("]}")
        Return sb.ToString()
    End Function

    ' Default.aspx.vb chiama:
    '   SeoBuilder.SetJsonLdOnMaster(Me, jsonLdScript)
    ' Qui accettiamo sia JSON puro che <script type="application/ld+json">...</script>
    Public Shared Sub SetJsonLdOnMaster(ByVal page As Page, ByVal jsonLdOrScript As String)
        If page Is Nothing Then Return
        If String.IsNullOrWhiteSpace(jsonLdOrScript) Then Return
        If page.Master Is Nothing Then Return

        Dim jsonOnly As String = ExtractJsonFromPossibleScript(jsonLdOrScript)

        ' 1) Provo a settare una property "SeoJsonLd" se presente in MasterPage (senza interfacce, evita conflitti)
        Try
            CallByName(page.Master, "SeoJsonLd", CallType.Set, jsonOnly)
            Return
        Catch
            ' master non ha la property
        End Try

        ' 2) Fallback: Literal litSeoJsonLd (se presente)
        Dim lit As Literal = TryCast(page.Master.FindControl("litSeoJsonLd"), Literal)
        If lit IsNot Nothing Then
            lit.Text = "<script type=""application/ld+json"">" & jsonOnly & "</script>"
        End If
    End Sub

    ' ============================================================
    ' SEO BASE
    ' ============================================================

    Public Shared Sub ApplyBasicSeo(ByVal page As Page, ByVal title As String, ByVal description As String, ByVal canonicalUrl As String)
        If page Is Nothing Then Return

        If Not String.IsNullOrWhiteSpace(title) Then
            page.Title = title.Trim()
        End If

        If Not String.IsNullOrWhiteSpace(description) Then
            UpsertMetaName(page, "description", description.Trim())
        End If

        UpsertMetaName(page, "robots", "index,follow")

        If Not String.IsNullOrWhiteSpace(canonicalUrl) Then
            UpsertCanonical(page, canonicalUrl.Trim())
        End If
    End Sub

    Public Shared Sub ApplyOpenGraph(ByVal page As Page, ByVal title As String, ByVal description As String, ByVal canonicalUrl As String, ByVal imageUrl As String)
        If page Is Nothing Then Return

        If Not String.IsNullOrWhiteSpace(title) Then UpsertMetaProperty(page, "og:title", title.Trim())
        If Not String.IsNullOrWhiteSpace(description) Then UpsertMetaProperty(page, "og:description", description.Trim())
        If Not String.IsNullOrWhiteSpace(canonicalUrl) Then UpsertMetaProperty(page, "og:url", canonicalUrl.Trim())

        UpsertMetaProperty(page, "og:type", "website")

        If Not String.IsNullOrWhiteSpace(imageUrl) Then
            UpsertMetaProperty(page, "og:image", imageUrl.Trim())
        End If
    End Sub

    ' ============================================================
    ' META / CANONICAL UPSERT
    ' ============================================================

    Private Shared Sub UpsertCanonical(ByVal page As Page, ByVal canonicalUrl As String)
        If page.Header Is Nothing Then Return

        For Each c As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(c, HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = Convert.ToString(l.Attributes("rel"))
                If String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    l.Href = canonicalUrl
                    Return
                End If
            End If
        Next

        Dim link As New HtmlLink()
        link.Attributes("rel") = "canonical"
        link.Href = canonicalUrl
        page.Header.Controls.Add(link)
    End Sub

    Private Shared Sub UpsertMetaName(ByVal page As Page, ByVal metaName As String, ByVal content As String)
        If page.Header Is Nothing Then Return

        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, metaName, StringComparison.OrdinalIgnoreCase) Then
                m.Content = content
                Return
            End If
        Next

        Dim meta As New HtmlMeta()
        meta.Name = metaName
        meta.Content = content
        page.Header.Controls.Add(meta)
    End Sub

    Private Shared Sub UpsertMetaProperty(ByVal page As Page, ByVal prop As String, ByVal content As String)
        If page.Header Is Nothing Then Return

        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing Then
                Dim p As String = Convert.ToString(m.Attributes("property"))
                If String.Equals(p, prop, StringComparison.OrdinalIgnoreCase) Then
                    m.Content = content
                    Return
                End If
            End If
        Next

        Dim meta As New HtmlMeta()
        meta.Attributes("property") = prop
        meta.Content = content
        page.Header.Controls.Add(meta)
    End Sub

    ' ============================================================
    ' HOME BUILDERS (no DB)
    ' ============================================================

    Private Shared Function BuildHomeCanonical(ByVal page As Page) As String
        Dim baseUrl As String = GetBaseUrl(page)
        Dim path As String = page.Request.Url.AbsolutePath

        If path IsNot Nothing AndAlso path.EndsWith("/Default.aspx", StringComparison.OrdinalIgnoreCase) Then
            Return baseUrl
        End If

        Return page.Request.Url.GetLeftPart(UriPartial.Path)
    End Function

    Private Shared Function BuildHomeTitle(ByVal page As Page) As String
        Dim siteName As String = GetSiteName(page)
        Return siteName & " | Vendita online"
    End Function

    Private Shared Function BuildHomeDescription(ByVal page As Page) As String
        Dim siteName As String = GetSiteName(page)
        Return "Acquista online su " & siteName & ": catalogo prodotti, offerte e promozioni. Spedizioni rapide e assistenza."
    End Function

    Private Shared Function GetSiteName(ByVal page As Page) As String
        Try
            Dim s As Object = page.Session("RagioneSociale")
            If s IsNot Nothing Then
                Dim v As String = Convert.ToString(s)
                If Not String.IsNullOrWhiteSpace(v) Then Return v.Trim()
            End If
        Catch
        End Try

        Dim host As String = page.Request.Url.Host
        If String.IsNullOrWhiteSpace(host) Then host = "KeepStore"
        Return host
    End Function

    Private Shared Function GetBaseUrl(ByVal page As Page) As String
        Dim u As Uri = page.Request.Url
        Return u.Scheme & "://" & u.Authority & "/"
    End Function

    ' ============================================================
    ' SCRIPT/JSON helper
    ' ============================================================

    Private Shared Function ExtractJsonFromPossibleScript(ByVal jsonLdOrScript As String) As String
        Dim s As String = jsonLdOrScript.Trim()

        If s.StartsWith("<script", StringComparison.OrdinalIgnoreCase) Then
            Dim gt As Integer = s.IndexOf(">")
            If gt >= 0 Then
                Dim endTag As Integer = s.LastIndexOf("</script>", StringComparison.OrdinalIgnoreCase)
                If endTag > gt Then
                    Return s.Substring(gt + 1, endTag - (gt + 1)).Trim()
                End If
            End If
        End If

        Return s
    End Function

    ' ============================================================
    ' JSON helpers
    ' ============================================================

    Private Shared Function JsonString(ByVal value As String) As String
        Return """" & JsonEscape(value) & """"
    End Function

    Public Shared Function JsonEscape(ByVal s As String) As String
        If s Is Nothing Then Return ""

        Dim sb As New StringBuilder(s.Length + 32)
        For i As Integer = 0 To s.Length - 1
            Dim ch As Char = s.Chars(i)
            Select Case ch
                Case """"c : sb.Append("\""")
                Case "\"c : sb.Append("\\")
                Case "/"c : sb.Append("\/")
                Case ControlChars.Back : sb.Append("\b")
                Case ControlChars.FormFeed : sb.Append("\f")
                Case ControlChars.Lf : sb.Append("\n")
                Case ControlChars.Cr : sb.Append("\r")
                Case ControlChars.Tab : sb.Append("\t")
                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 OrElse code > 126 Then
                        sb.Append("\u")
                        sb.Append(code.ToString("x4"))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next
        Return sb.ToString()
    End Function

End Class
