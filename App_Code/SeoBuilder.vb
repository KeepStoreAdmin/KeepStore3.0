Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Text
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.UI
Imports System.Web.UI.HtmlControls

' ============================================================
'  SeoBuilder.vb (KEEPSTORE3)
'  Helper centralizzato per:
'   - Meta tag (robots/description/keywords/og)
'   - Canonical
'   - JSON-LD (iniezione su Page.master tramite ISeoMaster)
'
'  NOTE:
'   - Compatibile con VB 2012 (.NET 4.x)
'   - NON dipende da tabelle/campi DB: qui si lavora su stringhe e Session/Request
' ============================================================

Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' -----------------------------
    ' Helpers base
    ' -----------------------------
    Private Shared Function ResolvePage(ByVal ctx As Object) As Page
        Dim p As Page = TryCast(ctx, Page)
        If p IsNot Nothing Then Return p

        Dim c As Control = TryCast(ctx, Control)
        If c IsNot Nothing Then Return c.Page

        Return Nothing
    End Function

    Private Shared Function Coalesce(ByVal value As String, ByVal fallback As String) As String
        If Not String.IsNullOrEmpty(value) Then Return value
        Return fallback
    End Function

    ' JSON escape robusto (usa JavaScriptSerializer per evitare bug di escaping/virgolette in VB)
    Public Shared Function JsonEscape(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim js As New JavaScriptSerializer()
        Dim json As String = js.Serialize(value) ' -> "..."
        If json.Length >= 2 AndAlso json.StartsWith("""", StringComparison.Ordinal) AndAlso json.EndsWith("""", StringComparison.Ordinal) Then
            Return json.Substring(1, json.Length - 2)
        End If
        Return json
    End Function

    ' Estrae il payload JSON da un eventuale <script type="application/ld+json">...</script>
    ' Utile per compatibilità: alcune pagine passano JSON puro, altre passano già lo script tag.
    Private Shared Function ExtractJsonLdPayload(ByVal raw As String) As String
        If String.IsNullOrWhiteSpace(raw) Then Return ""
        Dim s As String = raw.Trim()

        If s.StartsWith("<script", StringComparison.OrdinalIgnoreCase) Then
            Dim startIdx As Integer = s.IndexOf(">"c)
            Dim endIdx As Integer = s.LastIndexOf("</script>", StringComparison.OrdinalIgnoreCase)
            If startIdx >= 0 AndAlso endIdx > startIdx Then
                Dim inner As String = s.Substring(startIdx + 1, endIdx - (startIdx + 1))
                Return inner.Trim()
            End If
        End If

        Return s
    End Function


    ' -----------------------------
    ' META + CANONICAL
    ' -----------------------------
    Public Shared Sub AddOrReplaceMeta(ByVal ctx As Object, ByVal metaName As String, ByVal metaContent As String)
        Dim page As Page = ResolvePage(ctx)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        Dim found As HtmlMeta = Nothing
        For Each ctrl As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(ctrl, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, metaName, StringComparison.OrdinalIgnoreCase) Then
                found = m
                Exit For
            End If
        Next

        If found Is Nothing Then
            found = New HtmlMeta()
            found.Name = metaName
            page.Header.Controls.Add(found)
        End If

        found.Content = If(metaContent, "")
    End Sub

    ' Compatibility alias.
    ' Some pages call SeoBuilder.AddOrReplaceNameMeta(); in KeepStore it's equivalent to AddOrReplaceMeta()
    ' (i.e., targets <meta name="...">).
    Public Shared Sub AddOrReplaceNameMeta(ByVal ctx As Object, ByVal metaName As String, ByVal metaContent As String)
        AddOrReplaceMeta(ctx, metaName, metaContent)
    End Sub

    Public Shared Sub AddOrReplacePropertyMeta(ByVal ctx As Object, ByVal propertyName As String, ByVal metaContent As String)
        Dim page As Page = ResolvePage(ctx)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        Dim found As HtmlMeta = Nothing
        For Each ctrl As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(ctrl, HtmlMeta)
            If m IsNot Nothing Then
                Dim prop As String = m.Attributes("property")
                If Not String.IsNullOrEmpty(prop) AndAlso String.Equals(prop, propertyName, StringComparison.OrdinalIgnoreCase) Then
                    found = m
                    Exit For
                End If
            End If
        Next

        If found Is Nothing Then
            found = New HtmlMeta()
            found.Attributes("property") = propertyName
            page.Header.Controls.Add(found)
        End If

        found.Content = If(metaContent, "")
    End Sub

    Public Shared Sub SetCanonical(ByVal ctx As Object, ByVal canonicalUrl As String)
        Dim page As Page = ResolvePage(ctx)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        Dim href As String = If(canonicalUrl, "").Trim()
        If href = "" Then Exit Sub

        Dim found As HtmlLink = Nothing
        For Each ctrl As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(ctrl, HtmlLink)
            If l IsNot Nothing AndAlso String.Equals(Convert.ToString(l.Attributes("rel")), "canonical", StringComparison.OrdinalIgnoreCase) Then
                found = l
                Exit For
            End If
        Next

        If found Is Nothing Then
            found = New HtmlLink()
            found.Attributes("rel") = "canonical"
            page.Header.Controls.Add(found)
        End If

        found.Href = href
    End Sub

    ' Utility opzionale: OpenGraph base
    Public Shared Sub ApplyOpenGraph(ByVal ctx As Object, ByVal title As String, ByVal descr As String, ByVal url As String, ByVal imageUrl As String)
        AddOrReplacePropertyMeta(ctx, "og:type", "website")
        AddOrReplacePropertyMeta(ctx, "og:title", Coalesce(title, ""))
        AddOrReplacePropertyMeta(ctx, "og:description", Coalesce(descr, ""))
        AddOrReplacePropertyMeta(ctx, "og:url", Coalesce(url, ""))
        If Not String.IsNullOrEmpty(imageUrl) Then
            AddOrReplacePropertyMeta(ctx, "og:image", imageUrl)
        End If
    End Sub

    ' Manteniamo questo entry-point per compatibilità: alcuni file legacy lo chiamano.
    ' Qui NON imponiamo logiche: l'idea è evitare rotture di compilazione.
    Public Shared Sub ApplyHomeSeo(ByVal ctx As Object)
        ' Intenzionalmente minimal: la SEO HOME è gestita in Default.aspx.vb
        ' (tenuto per compatibilità con vecchi refactor che chiamavano SeoBuilder.ApplyHomeSeo)
    End Sub

    ' -----------------------------
    ' JSON-LD
    ' -----------------------------
    Public Shared Function BuildSimplePageJsonLd(ByVal pageTitle As String, ByVal descr As String, ByVal canonicalUrl As String, ByVal pageType As String) As String
        Dim js As New JavaScriptSerializer()

        Dim obj As New Dictionary(Of String, Object)()
        obj("@context") = "https://schema.org"
        obj("@type") = If(String.IsNullOrEmpty(pageType), "WebPage", pageType)
        obj("name") = If(pageTitle, "")
        obj("url") = If(canonicalUrl, "")
        If Not String.IsNullOrEmpty(descr) Then
            obj("description") = descr
        End If

        Return js.Serialize(obj)
    End Function

    ' Nuova: HOME JSON-LD (richiesta da Default.aspx.vb)
    ' Firma attesa nel progetto: BuildHomeJsonLd(Me, pageTitle, descr, canonical, logoUrl)
    Public Shared Function BuildHomeJsonLd(ByVal ctx As Object, ByVal pageTitle As String, ByVal descr As String, ByVal canonicalUrl As String, ByVal logoUrl As String) As String
        Dim page As Page = ResolvePage(ctx)
        Dim js As New JavaScriptSerializer()

        ' Dati base (senza presupporre campi DB: solo Session/Request se presenti)
        Dim orgName As String = ""
        Dim orgDescr As String = ""
        Dim siteUrl As String = ""

        If page IsNot Nothing Then
            Try
                orgName = TryCast(page.Session("AziendaNome"), String)
                orgDescr = TryCast(page.Session("AziendaDescrizione"), String)
                siteUrl = TryCast(page.Session("AziendaUrl"), String)
            Catch
                ' ignore
            End Try

            If String.IsNullOrEmpty(siteUrl) Then
                Try
                    siteUrl = page.Request.Url.GetLeftPart(UriPartial.Authority) & page.ResolveUrl("~/")
                Catch
                    ' ignore
                End Try
            End If
        End If

        orgName = Coalesce(orgName, "Taikun")
        orgDescr = Coalesce(orgDescr, descr)
        siteUrl = Coalesce(siteUrl, canonicalUrl)

        Dim orgId As String = canonicalUrl.TrimEnd("/"c) & "#organization"
        Dim webSiteId As String = canonicalUrl.TrimEnd("/"c) & "#website"
        Dim webPageId As String = canonicalUrl.TrimEnd("/"c) & "#webpage"

        Dim organization As New Dictionary(Of String, Object)()
        organization("@type") = "Organization"
        organization("@id") = orgId
        organization("name") = orgName
        organization("url") = siteUrl
        If Not String.IsNullOrEmpty(logoUrl) Then
            Dim logo As New Dictionary(Of String, Object)()
            logo("@type") = "ImageObject"
            logo("url") = logoUrl
            organization("logo") = logo
        End If
        If Not String.IsNullOrEmpty(orgDescr) Then
            organization("description") = orgDescr
        End If

        Dim webSite As New Dictionary(Of String, Object)()
        webSite("@type") = "WebSite"
        webSite("@id") = webSiteId
        webSite("url") = siteUrl
        webSite("name") = orgName
        webSite("publisher") = New Dictionary(Of String, Object) From {{"@id", orgId}}

        ' SearchAction (facoltativo, innocuo)
        Dim searchTarget As String = ""
        If page IsNot Nothing Then
            Try
                searchTarget = page.Request.Url.GetLeftPart(UriPartial.Authority) & page.ResolveUrl("~/ricerca.aspx") & "?q={search_term_string}"
            Catch
                searchTarget = ""
            End Try
        End If
        If Not String.IsNullOrEmpty(searchTarget) Then
            Dim searchAction As New Dictionary(Of String, Object)()
            searchAction("@type") = "SearchAction"
            searchAction("target") = searchTarget
            searchAction("query-input") = "required name=search_term_string"
            webSite("potentialAction") = searchAction
        End If

        Dim webPage As New Dictionary(Of String, Object)()
        webPage("@type") = "WebPage"
        webPage("@id") = webPageId
        webPage("url") = canonicalUrl
        webPage("name") = If(pageTitle, orgName)
        If Not String.IsNullOrEmpty(descr) Then
            webPage("description") = descr
        End If
        webPage("isPartOf") = New Dictionary(Of String, Object) From {{"@id", webSiteId}}
        webPage("about") = New Dictionary(Of String, Object) From {{"@id", orgId}}

        ' Breadcrumb minimale
        Dim breadcrumb As New Dictionary(Of String, Object)()
        breadcrumb("@type") = "BreadcrumbList"
        breadcrumb("@id") = canonicalUrl.TrimEnd("/"c) & "#breadcrumb"
        breadcrumb("itemListElement") = New Object() {
            New Dictionary(Of String, Object) From {
                {"@type", "ListItem"},
                {"position", 1},
                {"name", "Home"},
                {"item", canonicalUrl}
            }
        }

        Dim graph As New List(Of Object)()
        graph.Add(organization)
        graph.Add(webSite)
        graph.Add(webPage)
        graph.Add(breadcrumb)

        Dim root As New Dictionary(Of String, Object)()
        root("@context") = "https://schema.org"
        root("@graph") = graph

        Return js.Serialize(root)
    End Function

    ' Iniezione JSON-LD su master (Page.master Implementa ISeoMaster)
    Public Shared Sub SetJsonLdOnMaster(ByVal ctx As Object, ByVal jsonLd As String)
        ApplyJsonLd(ctx, jsonLd)
    End Sub

        Public Shared Sub ApplyJsonLd(ByVal ctx As Object, ByVal jsonLd As String)
        If String.IsNullOrWhiteSpace(jsonLd) Then Exit Sub

        Dim page As Page = ResolvePage(ctx)
        If page Is Nothing Then Exit Sub

        ' Importante:
        ' - Page.master ha già <script type="application/ld+json"> ... </script>
        ' - quindi, se la master implementa ISeoMaster, dobbiamo salvare SOLO JSON (no tag <script>)
        Dim payload As String = ExtractJsonLdPayload(jsonLd)
        If String.IsNullOrWhiteSpace(payload) Then Exit Sub

        Dim master As ISeoMaster = TryCast(page.Master, ISeoMaster)
        If master IsNot Nothing Then
            master.SeoJsonLd = payload
            Exit Sub
        End If

        ' Fallback: se non c'è la master o non implementa ISeoMaster, iniettiamo lo <script> direttamente in <head>
        If page.Header IsNot Nothing Then
            Dim scriptTag As String = "<script type=""application/ld+json"">" & payload & "</script>"
            page.Header.Controls.Add(New LiteralControl(scriptTag))
        End If
    End Sub

    ' -----------------------------
    ' Utility controlli
    ' -----------------------------
    Public Shared Function FindControlRecursive(ByVal ctx As Object, ByVal id As String) As Control
        If String.IsNullOrEmpty(id) Then Return Nothing

        Dim page As Page = ResolvePage(ctx)
        If page IsNot Nothing Then
            Return FindControlRecursiveInternal(page, id)
        End If

        Dim root As Control = TryCast(ctx, Control)
        If root IsNot Nothing Then
            Return FindControlRecursiveInternal(root, id)
        End If

        Return Nothing
    End Function

    Private Shared Function FindControlRecursiveInternal(ByVal root As Control, ByVal id As String) As Control
        If root Is Nothing Then Return Nothing

        ' IMPORTANT:
        ' Evitiamo root.FindControl(id) perché su controlli databound (GridView, Repeater, DataList, ecc.)
        ' può forzare EnsureChildControls/DataBind ed eseguire query premature (parametri non ancora impostati).
        ' Qui la ricerca è intenzionalmente "side-effect free".
        Try
            If Not String.IsNullOrEmpty(root.ID) AndAlso String.Equals(root.ID, id, StringComparison.Ordinal) Then
                Return root
            End If
        Catch
            ' ignore
        End Try

        Try
            For Each child As Control In root.Controls
                Dim found As Control = FindControlRecursiveInternal(child, id)
                If found IsNot Nothing Then Return found
            Next
        Catch
            ' ignore
        End Try

        Return Nothing
    End Function

        ' Aggiunge o aggiorna <meta name="..."> nel tag <head runat="server">
    Public Shared Sub AddOrReplaceNameMeta(ByVal page As System.Web.UI.Page, ByVal name As String, ByVal content As String)
    If page Is Nothing Then Exit Sub
    If page.Header Is Nothing Then Exit Sub
    If String.IsNullOrEmpty(name) Then Exit Sub

    Dim head As System.Web.UI.HtmlControls.HtmlHead = page.Header
    Dim found As System.Web.UI.HtmlControls.HtmlMeta = Nothing

    For Each c As System.Web.UI.Control In head.Controls
        Dim m As System.Web.UI.HtmlControls.HtmlMeta = TryCast(c, System.Web.UI.HtmlControls.HtmlMeta)
        If m IsNot Nothing Then
            If Not String.IsNullOrEmpty(m.Name) AndAlso String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                found = m
                Exit For
            End If
        End If
    Next

    If found Is Nothing Then
        found = New System.Web.UI.HtmlControls.HtmlMeta()
        found.Name = name
        head.Controls.Add(found)
    End If

    found.Content = If(content, String.Empty)
    End Sub

End Class
