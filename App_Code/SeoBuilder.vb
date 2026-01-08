Option Strict On
Option Explicit On

Imports System
Imports System.Text
Imports System.Globalization
Imports System.Collections.Generic
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Imports System.Data

' ============================================================
' SeoBuilder.vb
' Utilities SEO + JSON-LD
'
' NOTE IMPORTANTI:
' - Nessuna dipendenza da interfacce (evita conflitti tipo ISeoMaster duplicata).
' - Per Home (Default.aspx): JSON-LD costruito preferendo i dati REALI già usati
'   dalla pagina tramite SqlDataSource (categorie + prodotti).
' - Se un DataSource non è presente o la query fallisce, la sezione JSON-LD viene
'   omessa (fail-safe, nessun errore a runtime).
' ============================================================

Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' ------------------------------------------------------------
    ' Public API
    ' ------------------------------------------------------------

    Public Shared Function BuildHomeJsonLd(page As Page, baseUrl As String, pageUrl As String, siteName As String, description As String) As String
        Dim graph As New List(Of String)()

        Dim orgId As String = baseUrl.TrimEnd("/"c) & "/#organization"
        Dim webSiteId As String = baseUrl.TrimEnd("/"c) & "/#website"
        Dim webPageId As String = pageUrl & "#webpage"

        ' Organization (minimo, robusto)
        graph.Add(BuildOrganizationNode(orgId, baseUrl, siteName))

        ' WebSite
        graph.Add(BuildWebSiteNode(webSiteId, baseUrl, siteName, orgId))

        ' WebPage
        graph.Add(BuildWebPageNode(webPageId, pageUrl, siteName, description, webSiteId))

        ' BreadcrumbList (Home)
        graph.Add(BuildHomeBreadcrumbNode(baseUrl))

        ' ItemList categorie (dipartimenti) - usa Data_Dipartimenti (Default.aspx)
        Dim catNode As String = BuildHomeCategoriesItemList(page, baseUrl)
        If Not String.IsNullOrWhiteSpace(catNode) Then
            graph.Add(catNode)
        End If

        ' ItemList prodotti (ultimi arrivi) - usa Data_UltimiArrivi (Default.aspx)
        Dim prodNewNode As String = BuildHomeProductsItemList(page, baseUrl, "Data_UltimiArrivi", "Ultimi arrivi", "home-products-new", 12)
        If Not String.IsNullOrWhiteSpace(prodNewNode) Then
            graph.Add(prodNewNode)
        End If

        ' ItemList prodotti (più acquistati) - usa sdsPiuAcquistati (Default.aspx)
        Dim prodBestNode As String = BuildHomeProductsItemList(page, baseUrl, "sdsPiuAcquistati", "Più acquistati", "home-products-best", 12)
        If Not String.IsNullOrWhiteSpace(prodBestNode) Then
            graph.Add(prodBestNode)
        End If

        Dim sb As New StringBuilder()
        sb.Append("{")
        sb.Append("""@context"":""https://schema.org"",")
        sb.Append("""@graph"":[")
        For i As Integer = 0 To graph.Count - 1
            If i > 0 Then sb.Append(",")
            sb.Append(graph(i))
        Next
        sb.Append("]}")

        Return sb.ToString()
    End Function

    Public Shared Sub ApplyCanonicalAndMeta(page As Page, canonicalUrl As String, description As String, robots As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        EnsureCanonicalLink(page, canonicalUrl)
        EnsureMeta(page, "description", description)
        EnsureMeta(page, "robots", robots)
    End Sub

    Public Shared Sub ApplyOpenGraph(page As Page, pageUrl As String, title As String, description As String, imageUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        EnsureMetaProperty(page, "og:type", "website")
        EnsureMetaProperty(page, "og:url", pageUrl)
        EnsureMetaProperty(page, "og:title", title)
        EnsureMetaProperty(page, "og:description", description)
        If Not String.IsNullOrWhiteSpace(imageUrl) Then
            EnsureMetaProperty(page, "og:image", imageUrl)
        End If

        EnsureMetaProperty(page, "twitter:card", "summary_large_image")
        EnsureMetaProperty(page, "twitter:title", title)
        EnsureMetaProperty(page, "twitter:description", description)
        If Not String.IsNullOrWhiteSpace(imageUrl) Then
            EnsureMetaProperty(page, "twitter:image", imageUrl)
        End If
    End Sub

    Public Shared Sub SetJsonLdOnMaster(page As Page, jsonLd As String, Optional literalId As String = "litSeoJsonLd")
        If page Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(jsonLd) Then Exit Sub

        Dim master As MasterPage = page.Master
        If master Is Nothing Then Exit Sub

        Dim lit As Literal = TryCast(FindControlRecursive(master, literalId), Literal)
        If lit Is Nothing Then Exit Sub

        lit.Text = EnsureJsonLdScript(jsonLd)
    End Sub

    ' ------------------------------------------------------------
    ' Nodes builders (JSON-LD)
    ' ------------------------------------------------------------

    Private Shared Function BuildOrganizationNode(orgId As String, baseUrl As String, siteName As String) As String
        Dim sb As New StringBuilder()
        sb.Append("{")
        sb.Append("""@type"":""Organization"",")
        sb.Append("""@id"":""") : sb.Append(JsonEscape(orgId)) : sb.Append(""",")
        sb.Append("""name"":""") : sb.Append(JsonEscape(siteName)) : sb.Append(""",")
        sb.Append("""url"":""") : sb.Append(JsonEscape(baseUrl)) : sb.Append("""")
        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildWebSiteNode(webSiteId As String, baseUrl As String, siteName As String, orgId As String) As String
        Dim sb As New StringBuilder()
        sb.Append("{")
        sb.Append("""@type"":""WebSite"",")
        sb.Append("""@id"":""") : sb.Append(JsonEscape(webSiteId)) : sb.Append(""",")
        sb.Append("""url"":""") : sb.Append(JsonEscape(baseUrl)) : sb.Append(""",")
        sb.Append("""name"":""") : sb.Append(JsonEscape(siteName)) : sb.Append(""",")
        sb.Append("""publisher"":{""@id"":""") : sb.Append(JsonEscape(orgId)) : sb.Append("""}")
        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildWebPageNode(webPageId As String, pageUrl As String, title As String, description As String, webSiteId As String) As String
        Dim sb As New StringBuilder()
        sb.Append("{")
        sb.Append("""@type"":""WebPage"",")
        sb.Append("""@id"":""") : sb.Append(JsonEscape(webPageId)) : sb.Append(""",")
        sb.Append("""url"":""") : sb.Append(JsonEscape(pageUrl)) : sb.Append(""",")
        sb.Append("""name"":""") : sb.Append(JsonEscape(title)) : sb.Append(""",")
        If Not String.IsNullOrWhiteSpace(description) Then
            sb.Append("""description"":""") : sb.Append(JsonEscape(description)) : sb.Append(""",")
        End If
        sb.Append("""isPartOf"":{""@id"":""") : sb.Append(JsonEscape(webSiteId)) : sb.Append("""}")
        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildHomeBreadcrumbNode(baseUrl As String) As String
        Dim sb As New StringBuilder()
        sb.Append("{")
        sb.Append("""@type"":""BreadcrumbList"",")
        sb.Append("""@id"":""") : sb.Append(JsonEscape(baseUrl.TrimEnd("/"c) & "/#breadcrumb")) : sb.Append(""",")
        sb.Append("""itemListElement"":[")
        sb.Append("{""@type"":""ListItem"",""position"":1,""name"":""Home"",""item"":""")
        sb.Append(JsonEscape(baseUrl))
        sb.Append("""}")
        sb.Append("]}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildHomeCategoriesItemList(page As Page, baseUrl As String) As String
        Dim dv As DataView = TryGetDataView(page, "Data_Dipartimenti")
        If dv Is Nothing OrElse dv.Table Is Nothing OrElse dv.Table.Rows.Count = 0 Then
            Return String.Empty
        End If

        ' colonne attese in Default.aspx: id, descrizione
        If Not dv.Table.Columns.Contains("id") OrElse Not dv.Table.Columns.Contains("descrizione") Then
            Return String.Empty
        End If

        Dim maxItems As Integer = 12
        Dim count As Integer = Math.Min(maxItems, dv.Table.Rows.Count)

        Dim sb As New StringBuilder()
        sb.Append("{")
        sb.Append("""@type"":""ItemList"",")
        sb.Append("""@id"":""") : sb.Append(JsonEscape(baseUrl.TrimEnd("/"c) & "/#home-categories")) : sb.Append(""",")
        sb.Append("""name"":""Dipartimenti"",")
        sb.Append("""itemListElement"":[")

        Dim pos As Integer = 0
        For i As Integer = 0 To count - 1
            Dim r As DataRow = dv.Table.Rows(i)
            Dim id As String = SafeToString(r("id"))
            Dim name As String = SafeToString(r("descrizione"))
            If String.IsNullOrWhiteSpace(id) OrElse String.IsNullOrWhiteSpace(name) Then
                Continue For
            End If

            pos += 1
            If pos > 1 Then sb.Append(",")

            Dim url As String = baseUrl.TrimEnd("/"c) & "/articoli.aspx?ct=" & HttpUtility.UrlEncode(id)

            sb.Append("{""@type"":""ListItem"",""position"":")
            sb.Append(pos.ToString(CultureInfo.InvariantCulture))
            sb.Append(",""name"":""") : sb.Append(JsonEscape(name)) : sb.Append("""")
            sb.Append(",""url"":""") : sb.Append(JsonEscape(url)) : sb.Append("""}")
        Next

        sb.Append("]}")

        If pos = 0 Then Return String.Empty
        Return sb.ToString()
    End Function

    Private Shared Function BuildHomeProductsItemList(page As Page, baseUrl As String, dataSourceId As String, listName As String, nodeSuffix As String, maxItems As Integer) As String
        Dim dv As DataView = TryGetDataView(page, dataSourceId)
        If dv Is Nothing OrElse dv.Table Is Nothing OrElse dv.Table.Rows.Count = 0 Then
            Return String.Empty
        End If

        ' colonne minime necessarie per costruire URL + nome
        Dim hasCod As Boolean = dv.Table.Columns.Contains("Codice")
        Dim hasArtId As Boolean = dv.Table.Columns.Contains("ArticoliId")
        Dim hasTcId As Boolean = dv.Table.Columns.Contains("TCId")
        Dim hasName As Boolean = dv.Table.Columns.Contains("Descrizione1")

        If Not hasCod OrElse Not hasArtId OrElse Not hasTcId OrElse Not hasName Then
            Return String.Empty
        End If

        Dim count As Integer = Math.Min(Math.Max(1, maxItems), dv.Table.Rows.Count)

        Dim sb As New StringBuilder()
        sb.Append("{")
        sb.Append("""@type"":""ItemList"",")
        sb.Append("""@id"":""") : sb.Append(JsonEscape(baseUrl.TrimEnd("/"c) & "/#" & nodeSuffix)) : sb.Append(""",")
        sb.Append("""name"":""") : sb.Append(JsonEscape(listName)) : sb.Append(""",")
        sb.Append("""itemListElement"":[")

        Dim pos As Integer = 0

        For i As Integer = 0 To count - 1
            Dim r As DataRow = dv.Table.Rows(i)

            Dim codice As String = SafeToString(r("Codice"))
            Dim artId As String = SafeToString(r("ArticoliId"))
            Dim tcId As String = SafeToString(r("TCId"))
            Dim nome As String = SafeToString(r("Descrizione1"))

            If String.IsNullOrWhiteSpace(codice) OrElse String.IsNullOrWhiteSpace(artId) OrElse String.IsNullOrWhiteSpace(tcId) OrElse String.IsNullOrWhiteSpace(nome) Then
                Continue For
            End If

            Dim url As String = baseUrl.TrimEnd("/"c) & "/articolo.aspx?cod=" & HttpUtility.UrlEncode(codice) & "&id=" & HttpUtility.UrlEncode(artId) & "&tc=" & HttpUtility.UrlEncode(tcId)

            ' Immagine
            Dim imageUrl As String = String.Empty
            If dv.Table.Columns.Contains("img1") Then
                Dim img As String = SafeToString(r("img1"))
                If Not String.IsNullOrWhiteSpace(img) Then
                    imageUrl = baseUrl.TrimEnd("/"c) & "/Public/images/articoli/" & Uri.EscapeDataString(img)
                End If
            End If
            If String.IsNullOrWhiteSpace(imageUrl) Then
                imageUrl = baseUrl.TrimEnd("/"c) & "/Public/images/nofoto.gif"
            End If

            ' Marca
            Dim marca As String = String.Empty
            If dv.Table.Columns.Contains("marca") Then
                marca = SafeToString(r("marca"))
            End If

            ' Prezzo + offerta
            Dim price As String = String.Empty
            Dim hasOfferta As Boolean = dv.Table.Columns.Contains("offerta")
            Dim isOfferta As Boolean = False
            If hasOfferta Then
                Dim oVal As String = SafeToString(r("offerta"))
                isOfferta = (oVal = "1")
            End If

            If isOfferta AndAlso dv.Table.Columns.Contains("PrezzoIvatoScontato") Then
                price = ToDecimalInvariantString(r("PrezzoIvatoScontato"))
            End If
            If String.IsNullOrWhiteSpace(price) AndAlso dv.Table.Columns.Contains("PrezzoIvato") Then
                price = ToDecimalInvariantString(r("PrezzoIvato"))
            End If

            ' Quantita
            Dim inStock As Boolean = True
            If dv.Table.Columns.Contains("quantita") Then
                Dim qDec As Decimal
                If TryGetDecimal(r("quantita"), qDec) Then
                    inStock = (qDec > 0D)
                End If
            End If

            ' Product node
            Dim productJson As New StringBuilder()
            productJson.Append("{")
            productJson.Append("""@type"":""Product"",")
            productJson.Append("""name"":""") : productJson.Append(JsonEscape(nome)) : productJson.Append(""",")
            productJson.Append("""url"":""") : productJson.Append(JsonEscape(url)) : productJson.Append(""",")
            productJson.Append("""image"":""") : productJson.Append(JsonEscape(imageUrl)) : productJson.Append(""",")
            productJson.Append("""sku"":""") : productJson.Append(JsonEscape(codice)) : productJson.Append("""")

            If Not String.IsNullOrWhiteSpace(marca) Then
                productJson.Append(",""brand"":{""@type"":""Brand"",""name"":""")
                productJson.Append(JsonEscape(marca))
                productJson.Append("""}")
            End If

            If Not String.IsNullOrWhiteSpace(price) Then
                productJson.Append(",""offers"":{")
                productJson.Append("""@type"":""Offer"",")
                productJson.Append("""url"":""") : productJson.Append(JsonEscape(url)) : productJson.Append(""",")
                productJson.Append("""priceCurrency"":""EUR"",")
                productJson.Append("""price"":""") : productJson.Append(price) : productJson.Append(""",")
                productJson.Append("""availability"":""")
                productJson.Append(If(inStock, "https://schema.org/InStock", "https://schema.org/OutOfStock"))
                productJson.Append("""}")
            End If

            productJson.Append("}")

            pos += 1
            If pos > 1 Then sb.Append(",")

            sb.Append("{""@type"":""ListItem"",""position"":")
            sb.Append(pos.ToString(CultureInfo.InvariantCulture))
            sb.Append(",""item"":")
            sb.Append(productJson.ToString())
            sb.Append("}")
        Next

        sb.Append("]}")

        If pos = 0 Then Return String.Empty
        Return sb.ToString()
    End Function

    ' ------------------------------------------------------------
    ' Meta helpers
    ' ------------------------------------------------------------

    Private Shared Sub EnsureCanonicalLink(p As Page, canonicalUrl As String)
        If p Is Nothing OrElse p.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(canonicalUrl) Then Exit Sub

        Dim found As HtmlLink = Nothing

        For Each c As Control In p.Header.Controls
            Dim l As HtmlLink = TryCast(c, HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = ""
                If l.Attributes("rel") IsNot Nothing Then rel = l.Attributes("rel")
                If String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    found = l
                    Exit For
                End If
            End If
        Next

        If found Is Nothing Then
            found = New HtmlLink()
            p.Header.Controls.Add(found)
        End If

        found.Attributes("rel") = "canonical"
        found.Href = canonicalUrl
    End Sub

    Private Shared Sub EnsureMeta(p As Page, name As String, content As String)
        If p Is Nothing OrElse p.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(name) OrElse String.IsNullOrWhiteSpace(content) Then Exit Sub

        Dim found As HtmlMeta = Nothing
        For Each c As Control In p.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                found = m
                Exit For
            End If
        Next

        If found Is Nothing Then
            found = New HtmlMeta()
            found.Name = name
            p.Header.Controls.Add(found)
        End If

        found.Content = content
    End Sub

    Private Shared Sub EnsureMetaProperty(p As Page, propName As String, content As String)
        If p Is Nothing OrElse p.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(propName) OrElse String.IsNullOrWhiteSpace(content) Then Exit Sub

        Dim found As HtmlMeta = Nothing
        For Each c As Control In p.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing Then
                Dim prop As String = ""
                If m.Attributes("property") IsNot Nothing Then prop = m.Attributes("property")
                If String.Equals(prop, propName, StringComparison.OrdinalIgnoreCase) Then
                    found = m
                    Exit For
                End If
            End If
        Next

        If found Is Nothing Then
            found = New HtmlMeta()
            found.Attributes("property") = propName
            p.Header.Controls.Add(found)
        End If

        found.Content = content
    End Sub

    Private Shared Function EnsureJsonLdScript(s As String) As String
        If String.IsNullOrWhiteSpace(s) Then Return String.Empty

        Dim payload As String = s
        If s.IndexOf("<script", StringComparison.OrdinalIgnoreCase) < 0 Then
            payload = "<script type=""application/ld+json"">" & s & "</script>"
        End If

        Return payload
    End Function

    ' ------------------------------------------------------------
    ' DataSource helpers
    ' ------------------------------------------------------------

    Private Shared Function TryGetDataView(page As Page, dataSourceId As String) As DataView
        If page Is Nothing Then Return Nothing
        If String.IsNullOrWhiteSpace(dataSourceId) Then Return Nothing

        Try
            Dim ctl As Control = FindControlRecursive(page, dataSourceId)
            If ctl Is Nothing Then Return Nothing

            Dim sds As SqlDataSource = TryCast(ctl, SqlDataSource)
            If sds Is Nothing Then Return Nothing

            Dim data As IEnumerable = sds.Select(DataSourceSelectArguments.Empty)
            Dim dv As DataView = TryCast(data, DataView)
            Return dv
        Catch
            Return Nothing
        End Try
    End Function

    Private Shared Function FindControlRecursive(root As Control, id As String) As Control
        If root Is Nothing Then Return Nothing
        If String.Equals(root.ID, id, StringComparison.OrdinalIgnoreCase) Then Return root

        For Each c As Control In root.Controls
            Dim r As Control = FindControlRecursive(c, id)
            If r IsNot Nothing Then Return r
        Next

        Return Nothing
    End Function

    ' ------------------------------------------------------------
    ' JSON helpers
    ' ------------------------------------------------------------

    Public Shared Function JsonEscape(value As String) As String
        If value Is Nothing Then Return ""

        Dim sb As New StringBuilder(value.Length + 16)

        For Each ch As Char In value
            Select Case ch
                Case """"c
                    sb.Append("\\"c)
                    sb.Append(""""c)
                Case "\\"c
                    sb.Append("\\"c)
                    sb.Append("\\"c)
                Case "/"c
                    sb.Append("\\"c)
                    sb.Append("/"c)
                Case ControlChars.Back
                    sb.Append("\\"c)
                    sb.Append("b"c)
                Case ControlChars.FormFeed
                    sb.Append("\\"c)
                    sb.Append("f"c)
                Case ControlChars.Lf
                    sb.Append("\\"c)
                    sb.Append("n"c)
                Case ControlChars.Cr
                    sb.Append("\\"c)
                    sb.Append("r"c)
                Case ControlChars.Tab
                    sb.Append("\\"c)
                    sb.Append("t"c)
                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 OrElse code = &H2028 OrElse code = &H2029 Then
                        sb.Append("\u")
                        sb.Append(code.ToString("x4", CultureInfo.InvariantCulture))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function

    Private Shared Function SafeToString(o As Object) As String
        If o Is Nothing OrElse Convert.IsDBNull(o) Then Return ""
        Return Convert.ToString(o, CultureInfo.InvariantCulture)
    End Function

    Private Shared Function TryGetDecimal(o As Object, ByRef value As Decimal) As Boolean
        value = 0D
        If o Is Nothing OrElse Convert.IsDBNull(o) Then Return False

        If TypeOf o Is Decimal Then
            value = CType(o, Decimal)
            Return True
        End If
        If TypeOf o Is Double Then
            value = Convert.ToDecimal(CType(o, Double), CultureInfo.InvariantCulture)
            Return True
        End If
        If TypeOf o Is Single Then
            value = Convert.ToDecimal(CType(o, Single), CultureInfo.InvariantCulture)
            Return True
        End If
        If TypeOf o Is Integer OrElse TypeOf o Is Long OrElse TypeOf o Is Short Then
            value = Convert.ToDecimal(o, CultureInfo.InvariantCulture)
            Return True
        End If

        Dim s As String = Convert.ToString(o, CultureInfo.InvariantCulture)
        If String.IsNullOrWhiteSpace(s) Then Return False

        Return Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, value)
    End Function

    Private Shared Function ToDecimalInvariantString(o As Object) As String
        Dim d As Decimal
        If Not TryGetDecimal(o, d) Then Return ""
        Return d.ToString("0.00", CultureInfo.InvariantCulture)
    End Function

End Class
