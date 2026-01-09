Imports System
Imports System.Data
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

' ============================================================
' App_Code/SeoBuilder.vb
' Utility SEO + JSON-LD per WebForms (VB.NET)
'
' NOTE IMPORTANTI
' - Non dichiarare interfacce qui dentro (es. ISeoMaster), per evitare conflitti
'   quando esistono già altre definizioni in App_Code.
' - Metodi pubblici mantenuti compatibili con Default.aspx.vb (BuildHomeJsonLd / SetJsonLdOnMaster).
' ============================================================

Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' -------------------------
    ' ENTRY POINT (HOME)
    ' -------------------------

    Public Shared Sub ApplyHomeSeo(page As Page)
        If page Is Nothing Then Return

        Dim canonical As String = BuildHomeCanonical(page)
        Dim title As String = BuildHomeTitle(page)
        Dim descr As String = BuildHomeDescription(page)

        ApplyBasicSeo(page, title, descr, canonical)
        ApplyOpenGraph(page, title, descr, canonical, Nothing)

        Dim logoUrl As String = GetLogoUrlAbsolute(page)
        Dim jsonLd As String = BuildHomeJsonLd(page, title, descr, canonical, logoUrl)
        SetJsonLdOnMaster(page, jsonLd)
    End Sub

    ' -------------------------
    ' PUBLIC API richiesto da Default.aspx.vb
    ' -------------------------

    ' Ritorna SOLO il JSON (senza <script>), così Default.aspx.vb può gestire l'injection.
    Public Shared Function BuildHomeJsonLd(page As Page, pageTitle As String, fullDescription As String, canonicalUrl As String, logoUrl As String) As String
        Try
            Return BuildHomeJsonLdAdvanced(page, pageTitle, fullDescription, canonicalUrl, logoUrl)
        Catch
            ' fallback minimo (mai rompere la pagina)
            Return BuildHomeJsonLdMinimal(page)
        End Try
    End Function

    ' Inietta JSON-LD nella master (litSeoJsonLd o property SeoJsonLd) oppure nella <head>.
    ' Accetta JSON puro e lo wrappa nel tag <script type="application/ld+json">.
    Public Shared Sub SetJsonLdOnMaster(page As Page, jsonLd As String)
        If page Is Nothing Then Return

        If String.IsNullOrWhiteSpace(jsonLd) Then
            InjectJsonLdIntoMaster(page, "")
            Return
        End If

        Dim script As String = "<script type=\"application/ld+json\">" & jsonLd & "</script>"
        InjectJsonLdIntoMaster(page, script)
    End Sub

    ' -------------------------
    ' SEO BASE
    ' -------------------------

    Public Shared Sub ApplyBasicSeo(page As Page, title As String, description As String, canonicalUrl As String)
        If page Is Nothing Then Return

        If Not String.IsNullOrWhiteSpace(title) Then
            page.Title = title.Trim()
        End If

        If Not String.IsNullOrWhiteSpace(description) Then
            UpsertMeta(page, "description", description.Trim())
        End If

        ' Robots: per la HOME index,follow
        UpsertMeta(page, "robots", "index,follow")

        If Not String.IsNullOrWhiteSpace(canonicalUrl) Then
            UpsertCanonical(page, canonicalUrl.Trim())
        End If
    End Sub

    Public Shared Sub ApplyOpenGraph(page As Page, title As String, description As String, canonicalUrl As String, imageUrl As String)
        If page Is Nothing Then Return

        If Not String.IsNullOrWhiteSpace(title) Then
            UpsertMetaProperty(page, "og:title", title.Trim())
            UpsertMetaProperty(page, "twitter:title", title.Trim())
        End If

        If Not String.IsNullOrWhiteSpace(description) Then
            UpsertMetaProperty(page, "og:description", description.Trim())
            UpsertMetaProperty(page, "twitter:description", description.Trim())
        End If

        If Not String.IsNullOrWhiteSpace(canonicalUrl) Then
            UpsertMetaProperty(page, "og:url", canonicalUrl.Trim())
        End If

        UpsertMetaProperty(page, "og:type", "website")
        UpsertMetaProperty(page, "twitter:card", "summary_large_image")

        If Not String.IsNullOrWhiteSpace(imageUrl) Then
            UpsertMetaProperty(page, "og:image", imageUrl.Trim())
            UpsertMetaProperty(page, "twitter:image", imageUrl.Trim())
        End If
    End Sub

    Private Shared Sub UpsertMeta(page As Page, name As String, content As String)
        If page.Header Is Nothing Then Return

        Dim found As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                found = m
                Exit For
            End If
        Next

        If found Is Nothing Then
            found = New HtmlMeta()
            found.Name = name
            page.Header.Controls.Add(found)
        End If

        found.Content = If(content, "")
    End Sub

    Private Shared Sub UpsertMetaProperty(page As Page, prop As String, content As String)
        If page.Header Is Nothing Then Return

        Dim found As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing Then
                Dim p As String = If(m.Attributes("property"), "")
                If String.Equals(p, prop, StringComparison.OrdinalIgnoreCase) Then
                    found = m
                    Exit For
                End If
            End If
        Next

        If found Is Nothing Then
            found = New HtmlMeta()
            found.Attributes("property") = prop
            page.Header.Controls.Add(found)
        End If

        found.Content = If(content, "")
    End Sub

    Private Shared Sub UpsertCanonical(page As Page, href As String)
        If page.Header Is Nothing Then Return

        Dim found As HtmlLink = Nothing
        For Each c As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(c, HtmlLink)
            If l IsNot Nothing AndAlso String.Equals(l.Rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                found = l
                Exit For
            End If
        Next

        If found Is Nothing Then
            found = New HtmlLink()
            found.Rel = "canonical"
            page.Header.Controls.Add(found)
        End If

        found.Href = If(href, "")
    End Sub

    ' -------------------------
    ' JSON-LD: HOME (ADVANCED)
    ' -------------------------

    Private Shared Function BuildHomeJsonLdAdvanced(page As Page, pageTitle As String, fullDescription As String, canonicalUrl As String, logoUrl As String) As String

        Dim baseUrl As String = GetBaseUrl(page)
        If String.IsNullOrWhiteSpace(canonicalUrl) Then canonicalUrl = BuildHomeCanonical(page)

        Dim siteName As String = SafeSessionString(page, "RagioneSociale")
        If String.IsNullOrWhiteSpace(siteName) Then siteName = SafeSessionString(page, "AziendaNome")
        If String.IsNullOrWhiteSpace(siteName) Then siteName = "KeepStore"

        Dim title As String = If(String.IsNullOrWhiteSpace(pageTitle), siteName, pageTitle)
        Dim descr As String = If(String.IsNullOrWhiteSpace(fullDescription), BuildHomeDescription(page), fullDescription)

        ' IvaTipo: 2 = ivato (come logica sito)
        Dim ivaTipo As Integer = SafeSessionInt(page, "IvaTipo", 0)

        ' URL search interno (assumiamo q)
        Dim searchTarget As String = baseUrl & "articoli.aspx?q={search_term_string}"

        ' IDs per @graph
        Dim orgId As String = baseUrl & "#organization"
        Dim websiteId As String = baseUrl & "#website"
        Dim webpageId As String = canonicalUrl.TrimEnd("/"c) & "#webpage"
        Dim breadcrumbId As String = canonicalUrl.TrimEnd("/"c) & "#breadcrumb"

        Dim sb As New StringBuilder(8192)
        sb.Append("{\"@context\":\"https://schema.org\",\"@graph\":[")

        Dim first As Boolean = True

        ' 1) Organization
        AppendGraphNode(sb, first, BuildOrganizationNodeJson(siteName, baseUrl, orgId, logoUrl))

        ' 2) WebSite
        AppendGraphNode(sb, first, BuildWebSiteNodeJson(siteName, baseUrl, websiteId, orgId, searchTarget))

        ' 3) WebPage
        AppendGraphNode(sb, first, BuildWebPageNodeJson(title, descr, canonicalUrl, webpageId, websiteId, orgId))

        ' 4) BreadcrumbList (Home)
        AppendGraphNode(sb, first, BuildHomeBreadcrumbNodeJson(siteName, canonicalUrl, breadcrumbId, webpageId))

        ' Raccolta categorie e prodotti dalla pagina
        Dim catDv As DataView = TrySelectDataView(page, "SdsHeroCats")

        Dim prodNodes As New List(Of String)()
        Dim featuredIds As New List(Of String)()
        Dim newIds As New List(Of String)()
        Dim bestIds As New List(Of String)()
        Dim prodDedup As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase) ' key=@id

        CollectProductsFromDataSource(page, "SdsArticoliInVetrina", 12, ivaTipo, prodNodes, featuredIds, prodDedup)
        CollectProductsFromDataSource(page, "SdsNewArticoli", 12, ivaTipo, prodNodes, newIds, prodDedup)
        CollectProductsFromDataSource(page, "sdsPiuAcquistati", 12, ivaTipo, prodNodes, bestIds, prodDedup)

        ' 5) Product nodes
        For Each pjson As String In prodNodes
            AppendGraphNode(sb, first, pjson)
        Next

        ' 6) Category ItemList
        If catDv IsNot Nothing AndAlso catDv.Count > 0 Then
            AppendGraphNode(sb, first, BuildCategoriesItemListJson(catDv, baseUrl, canonicalUrl))
        End If

        ' 7) Product ItemLists
        If featuredIds.Count > 0 Then
            AppendGraphNode(sb, first, BuildProductsItemListJson("Prodotti in vetrina", canonicalUrl.TrimEnd("/"c) & "#featured", featuredIds))
        End If

        If newIds.Count > 0 Then
            AppendGraphNode(sb, first, BuildProductsItemListJson("Nuovi arrivi", canonicalUrl.TrimEnd("/"c) & "#new", newIds))
        End If

        If bestIds.Count > 0 Then
            AppendGraphNode(sb, first, BuildProductsItemListJson("I più venduti", canonicalUrl.TrimEnd("/"c) & "#bestsellers", bestIds))
        End If

        sb.Append("]}")
        Return sb.ToString()

    End Function

    Private Shared Sub AppendGraphNode(sb As StringBuilder, ByRef first As Boolean, json As String)
        If sb Is Nothing OrElse String.IsNullOrWhiteSpace(json) Then Return
        If Not first Then sb.Append(",")
        sb.Append(json)
        first = False
    End Sub

    Private Shared Function BuildOrganizationNodeJson(siteName As String, baseUrl As String, orgId As String, logoUrl As String) As String
        Dim sb As New StringBuilder(512)
        sb.Append("{\"@type\":\"Organization\"")
        sb.Append(",\"@id\":\"").Append(JsonEscape(orgId)).Append("\"")
        sb.Append(",\"name\":\"").Append(JsonEscape(siteName)).Append("\"")
        sb.Append(",\"url\":\"").Append(JsonEscape(baseUrl)).Append("\"")

        If Not String.IsNullOrWhiteSpace(logoUrl) Then
            sb.Append(",\"logo\":{\"@type\":\"ImageObject\",\"url\":\"").Append(JsonEscape(logoUrl)).Append("\"}")
        End If

        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildWebSiteNodeJson(siteName As String, baseUrl As String, websiteId As String, orgId As String, searchTarget As String) As String
        Dim sb As New StringBuilder(768)
        sb.Append("{\"@type\":\"WebSite\"")
        sb.Append(",\"@id\":\"").Append(JsonEscape(websiteId)).Append("\"")
        sb.Append(",\"url\":\"").Append(JsonEscape(baseUrl)).Append("\"")
        sb.Append(",\"name\":\"").Append(JsonEscape(siteName)).Append("\"")
        sb.Append(",\"publisher\":{\"@id\":\"").Append(JsonEscape(orgId)).Append("\"}")

        If Not String.IsNullOrWhiteSpace(searchTarget) Then
            sb.Append(",\"potentialAction\":{\"@type\":\"SearchAction\",\"target\":\"")
            sb.Append(JsonEscape(searchTarget)).Append("\",\"query-input\":\"required name=search_term_string\"}")
        End If

        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildWebPageNodeJson(title As String, descr As String, canonicalUrl As String, webpageId As String, websiteId As String, orgId As String) As String
        Dim sb As New StringBuilder(768)
        sb.Append("{\"@type\":[\"WebPage\"],")
        sb.Append("\"@id\":\"").Append(JsonEscape(webpageId)).Append("\"")
        sb.Append(",\"url\":\"").Append(JsonEscape(canonicalUrl)).Append("\"")
        sb.Append(",\"name\":\"").Append(JsonEscape(title)).Append("\"")
        sb.Append(",\"description\":\"").Append(JsonEscape(descr)).Append("\"")
        sb.Append(",\"isPartOf\":{\"@id\":\"").Append(JsonEscape(websiteId)).Append("\"}")
        sb.Append(",\"about\":{\"@id\":\"").Append(JsonEscape(orgId)).Append("\"}")
        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildHomeBreadcrumbNodeJson(siteName As String, canonicalUrl As String, breadcrumbId As String, webpageId As String) As String
        Dim sb As New StringBuilder(512)
        sb.Append("{\"@type\":\"BreadcrumbList\"")
        sb.Append(",\"@id\":\"").Append(JsonEscape(breadcrumbId)).Append("\"")
        sb.Append(",\"itemListElement\":[")
        sb.Append("{\"@type\":\"ListItem\",\"position\":1,\"name\":\"")
        sb.Append(JsonEscape(siteName)).Append("\",\"item\":{\"@id\":\"")
        sb.Append(JsonEscape(webpageId)).Append("\"}}")
        sb.Append("]}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildCategoriesItemListJson(dv As DataView, baseUrl As String, canonicalUrl As String) As String
        Dim sb As New StringBuilder(2048)
        sb.Append("{\"@type\":\"ItemList\"")
        sb.Append(",\"@id\":\"").Append(JsonEscape(canonicalUrl.TrimEnd("/"c) & "#categories")).Append("\"")
        sb.Append(",\"name\":\"Categorie\"")
        sb.Append(",\"itemListElement\":[")

        Dim max As Integer = Math.Min(12, dv.Count)
        For i As Integer = 0 To max - 1
            Dim row As DataRowView = dv(i)
            Dim id As String = GetRowString(row, "id")
            Dim name As String = GetRowString(row, "descrizione")
            Dim url As String = baseUrl & "articoli.aspx?ct=" & HttpUtility.UrlEncode(id)

            If i > 0 Then sb.Append(",")
            sb.Append("{\"@type\":\"ListItem\",\"position\":").Append(i + 1)
            sb.Append(",\"name\":\"").Append(JsonEscape(name)).Append("\"")
            sb.Append(",\"item\":\"").Append(JsonEscape(url)).Append("\"}")
        Next

        sb.Append("]}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildProductsItemListJson(listName As String, listId As String, productIds As List(Of String)) As String
        Dim sb As New StringBuilder(4096)
        sb.Append("{\"@type\":\"ItemList\"")
        sb.Append(",\"@id\":\"").Append(JsonEscape(listId)).Append("\"")
        sb.Append(",\"name\":\"").Append(JsonEscape(listName)).Append("\"")
        sb.Append(",\"itemListElement\":[")

        Dim pos As Integer = 0
        For Each pid As String In productIds
            pos += 1
            If pos > 24 Then Exit For
            If pos > 1 Then sb.Append(",")
            sb.Append("{\"@type\":\"ListItem\",\"position\":").Append(pos)
            sb.Append(",\"item\":{\"@id\":\"").Append(JsonEscape(pid)).Append("\"}}")
        Next

        sb.Append("]}")
        Return sb.ToString()
    End Function

    Private Shared Sub CollectProductsFromDataSource(page As Page, dataSourceId As String, maxItems As Integer, ivaTipo As Integer, prodNodes As List(Of String), listIds As List(Of String), dedup As Dictionary(Of String, String))
        Dim dv As DataView = TrySelectDataView(page, dataSourceId)
        If dv Is Nothing OrElse dv.Count = 0 Then Return

        Dim take As Integer = Math.Min(maxItems, dv.Count)
        For i As Integer = 0 To take - 1
            Dim row As DataRowView = dv(i)

            Dim artId As String = GetRowString(row, "ArticoliId")
            If String.IsNullOrWhiteSpace(artId) Then artId = GetRowString(row, "articoliId")

            Dim tcId As String = GetRowString(row, "TCId")
            If String.IsNullOrWhiteSpace(tcId) Then tcId = GetRowString(row, "tcid")

            If String.IsNullOrWhiteSpace(artId) Then Continue For

            Dim prodUrl As String = GetBaseUrl(page) & "articolo.aspx?id=" & HttpUtility.UrlEncode(artId)
            If Not String.IsNullOrWhiteSpace(tcId) Then
                prodUrl &= "&tc=" & HttpUtility.UrlEncode(tcId)
            End If

            Dim prodId As String = prodUrl

            If Not dedup.ContainsKey(prodId) Then
                Dim pjson As String = BuildProductNodeJson(page, row, prodId, prodUrl, ivaTipo)
                If Not String.IsNullOrWhiteSpace(pjson) Then
                    dedup(prodId) = "1"
                    prodNodes.Add(pjson)
                End If
            End If

            listIds.Add(prodId)
        Next

    End Sub

    Private Shared Function BuildProductNodeJson(page As Page, row As DataRowView, prodId As String, prodUrl As String, ivaTipo As Integer) As String
        Dim name As String = GetRowString(row, "Descrizione1")
        If String.IsNullOrWhiteSpace(name) Then name = GetRowString(row, "descrizione1")

        Dim sku As String = GetRowString(row, "Codice")
        If String.IsNullOrWhiteSpace(sku) Then sku = GetRowString(row, "codice")

        Dim img1 As String = GetRowString(row, "img1")
        Dim imgUrl As String = BuildProductImageAbsolute(page, img1)

        Dim inOfferta As Integer = SafeInt(GetRowString(row, "inOfferta"), 0)

        Dim price As Decimal = 0D
        Dim priceNormal As Decimal = 0D
        Dim pricePromo As Decimal = 0D

        If ivaTipo = 2 Then
            priceNormal = ParseDecimal(GetRowString(row, "PrezzoIvato"))
            pricePromo = ParseDecimal(GetRowString(row, "PrezzoPromoIvato"))
        Else
            priceNormal = ParseDecimal(GetRowString(row, "Prezzo"))
            pricePromo = ParseDecimal(GetRowString(row, "PrezzoPromo"))
        End If

        If inOfferta = 1 AndAlso pricePromo > 0D Then
            price = pricePromo
        Else
            price = priceNormal
        End If

        Dim sb As New StringBuilder(1024)
        sb.Append("{\"@type\":\"Product\"")
        sb.Append(",\"@id\":\"").Append(JsonEscape(prodId)).Append("\"")
        sb.Append(",\"url\":\"").Append(JsonEscape(prodUrl)).Append("\"")

        If Not String.IsNullOrWhiteSpace(name) Then
            sb.Append(",\"name\":\"").Append(JsonEscape(name)).Append("\"")
        End If

        If Not String.IsNullOrWhiteSpace(imgUrl) Then
            sb.Append(",\"image\":[\"").Append(JsonEscape(imgUrl)).Append("\"]")
        End If

        If Not String.IsNullOrWhiteSpace(sku) Then
            sb.Append(",\"sku\":\"").Append(JsonEscape(sku)).Append("\"")
        End If

        If price > 0D Then
            sb.Append(",\"offers\":{\"@type\":\"Offer\",\"url\":\"")
            sb.Append(JsonEscape(prodUrl)).Append("\",\"priceCurrency\":\"EUR\",\"price\":\"")
            sb.Append(price.ToString("0.00", CultureInfo.InvariantCulture)).Append("\"}")
        End If

        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildProductImageAbsolute(page As Page, img1 As String) As String
        Dim baseUrl As String = GetBaseUrl(page)

        If String.IsNullOrWhiteSpace(img1) Then
            Return baseUrl & "Public/images/nofoto.gif"
        End If

        img1 = img1.Trim()

        If img1.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse img1.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return img1
        End If

        If img1.StartsWith("~/") Then
            Return baseUrl & img1.Substring(2)
        End If

        If img1.StartsWith("/") Then
            Return baseUrl.TrimEnd("/"c) & img1
        End If

        ' default: percorso immagini articoli
        Return baseUrl & "Public/images/articoli/" & img1.TrimStart("/"c)
    End Function

    Private Shared Function TrySelectDataView(page As Page, controlId As String) As DataView
        Try
            If page Is Nothing OrElse String.IsNullOrWhiteSpace(controlId) Then Return Nothing

            Dim ctrl As Control = FindControlDeep(page, controlId)
            If ctrl Is Nothing Then Return Nothing

            Dim sds As SqlDataSource = TryCast(ctrl, SqlDataSource)
            If sds Is Nothing Then Return Nothing

            Dim res As IEnumerable = sds.Select(DataSourceSelectArguments.Empty)
            Dim dv As DataView = TryCast(res, DataView)
            If dv IsNot Nothing Then Return dv

            Dim dt As DataTable = TryCast(res, DataTable)
            If dt IsNot Nothing Then Return dt.DefaultView

        Catch
        End Try

        Return Nothing
    End Function

    Private Shared Function FindControlDeep(root As Control, id As String) As Control
        If root Is Nothing OrElse String.IsNullOrWhiteSpace(id) Then Return Nothing

        Dim direct As Control = root.FindControl(id)
        If direct IsNot Nothing Then Return direct

        For Each c As Control In root.Controls
            Dim found As Control = FindControlDeep(c, id)
            If found IsNot Nothing Then Return found
        Next

        Return Nothing
    End Function

    Private Shared Function GetRowString(row As DataRowView, col As String) As String
        Try
            If row Is Nothing OrElse row.Row Is Nothing OrElse row.Row.Table Is Nothing Then Return ""
            If Not row.Row.Table.Columns.Contains(col) Then Return ""
            Dim o As Object = row(col)
            If o Is Nothing OrElse o Is DBNull.Value Then Return ""
            Return Convert.ToString(o)
        Catch
            Return ""
        End Try
    End Function

    ' -------------------------
    ' JSON-LD: HOME (MINIMAL)
    ' -------------------------

    Private Shared Function BuildHomeJsonLdMinimal(page As Page) As String
        Dim baseUrl As String = GetBaseUrl(page)
        Dim siteName As String = SafeSessionString(page, "RagioneSociale")
        If String.IsNullOrWhiteSpace(siteName) Then siteName = SafeSessionString(page, "AziendaNome")
        If String.IsNullOrWhiteSpace(siteName) Then siteName = "KeepStore"

        Dim sb As New StringBuilder(1024)
        sb.Append("{\"@context\":\"https://schema.org\",\"@type\":[\"WebSite\"],")
        sb.Append("\"name\":\"").Append(JsonEscape(siteName)).Append("\",")
        sb.Append("\"url\":\"").Append(JsonEscape(baseUrl)).Append("\"}")
        Return sb.ToString()
    End Function

    ' -------------------------
    ' Helpers URL / Session
    ' -------------------------

    Private Shared Function BuildHomeCanonical(page As Page) As String
        Dim baseUrl As String = GetBaseUrl(page)
        Return baseUrl
    End Function

    Private Shared Function BuildHomeTitle(page As Page) As String
        Dim name As String = SafeSessionString(page, "RagioneSociale")
        If String.IsNullOrWhiteSpace(name) Then name = SafeSessionString(page, "AziendaNome")
        If String.IsNullOrWhiteSpace(name) Then name = "KeepStore"
        Return name
    End Function

    Private Shared Function BuildHomeDescription(page As Page) As String
        Dim descr As String = SafeSessionString(page, "AziendaDescrizione")
        If String.IsNullOrWhiteSpace(descr) Then
            descr = "Catalogo online: elettronica, informatica, telefonia e accessori. Offerte e nuovi arrivi."
        End If

        descr = descr.Trim()
        If descr.Length > 160 Then descr = descr.Substring(0, 160)
        Return descr
    End Function

    Private Shared Function GetBaseUrl(page As Page) As String
        Dim req As HttpRequest = Nothing
        Try
            req = page.Request
        Catch
        End Try

        If req Is Nothing OrElse req.Url Is Nothing Then
            Return "https://www.taikun.it/"
        End If

        Dim u As Uri = req.Url
        Dim baseUrl As String = u.Scheme & "://" & u.Authority & req.ApplicationPath
        If Not baseUrl.EndsWith("/") Then baseUrl &= "/"
        Return baseUrl
    End Function

    Private Shared Function SafeSessionString(page As Page, key As String) As String
        Try
            If page Is Nothing OrElse page.Session Is Nothing Then Return ""
            Dim o As Object = page.Session(key)
            If o Is Nothing Then Return ""
            Return Convert.ToString(o)
        Catch
            Return ""
        End Try
    End Function

    Private Shared Function SafeSessionInt(page As Page, key As String, defaultValue As Integer) As Integer
        Try
            Dim s As String = SafeSessionString(page, key)
            If String.IsNullOrWhiteSpace(s) Then Return defaultValue
            Dim v As Integer
            If Integer.TryParse(s, v) Then Return v
        Catch
        End Try
        Return defaultValue
    End Function

    Private Shared Function SafeInt(s As String, defaultValue As Integer) As Integer
        Dim v As Integer
        If Integer.TryParse(s, v) Then Return v
        Return defaultValue
    End Function

    Private Shared Function ParseDecimal(s As String) As Decimal
        If String.IsNullOrWhiteSpace(s) Then Return 0D

        Dim d As Decimal
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.CurrentCulture, d) Then Return d

        ' fallback: sostituisci virgola/punto
        s = s.Replace(",", ".")
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d

        Return 0D
    End Function

    Private Shared Function GetLogoUrlAbsolute(page As Page) As String
        Dim og As String = SafeSessionString(page, "AziendaOgImage")
        If Not String.IsNullOrWhiteSpace(og) Then
            Return ToAbsoluteUrl(page, og)
        End If

        Dim logo As String = SafeSessionString(page, "AziendaLogo")
        If String.IsNullOrWhiteSpace(logo) Then Return ""
        Return ToAbsoluteUrl(page, logo)
    End Function

    Private Shared Function ToAbsoluteUrl(page As Page, url As String) As String
        If String.IsNullOrWhiteSpace(url) Then Return ""
        url = url.Trim()

        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return url
        End If

        Dim baseUrl As String = GetBaseUrl(page).TrimEnd("/"c)

        If url.StartsWith("~/") Then
            Return baseUrl & "/" & url.Substring(2)
        End If

        If url.StartsWith("/") Then
            Return baseUrl & url
        End If

        Return baseUrl & "/" & url
    End Function

    ' -------------------------
    ' Injection JSON-LD nella master
    ' -------------------------

    Private Shared Sub InjectJsonLdIntoMaster(page As Page, scriptTag As String)
        Try
            If page Is Nothing Then Return

            Dim masterObj As Object = page.Master

            ' 1) Property SeoJsonLd (se esiste)
            If masterObj IsNot Nothing Then
                Try
                    CallByName(masterObj, "SeoJsonLd", CallType.Set, scriptTag)
                    Return
                Catch
                End Try
            End If

            ' 2) Literal litSeoJsonLd
            Dim lit As Literal = TryCast(FindControlDeep(page, "litSeoJsonLd"), Literal)
            If lit IsNot Nothing Then
                lit.Text = scriptTag
                Return
            End If

            ' 3) Fallback: Header
            If page.Header IsNot Nothing Then
                page.Header.Controls.Add(New LiteralControl(scriptTag))
            End If

        Catch
        End Try
    End Sub

    ' -------------------------
    ' JSON Escape (centralizzato)
    ' -------------------------

    Public Shared Function JsonEscape(value As String) As String
        If value Is Nothing Then Return ""

        Dim sb As New StringBuilder(value.Length + 16)
        For Each ch As Char In value
            Select Case ch
                Case "\\"c
                    sb.Append("\\\\")
                Case "\""c
                    sb.Append("\\\"")
                Case "/"c
                    sb.Append("\\/")
                Case vbBack
                    sb.Append("\\b")
                Case vbFormFeed
                    sb.Append("\\f")
                Case vbLf
                    sb.Append("\\n")
                Case vbCr
                    sb.Append("\\r")
                Case vbTab
                    sb.Append("\\t")
                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 Then
                        sb.Append("\\u").Append(code.ToString("x4"))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function

End Class
