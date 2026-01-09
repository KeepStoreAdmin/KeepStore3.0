' App_Code/SeoBuilder.vb
Option Strict On
Option Explicit On

Imports System
Imports System.Data
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' =========================================================
    ' API "stabile" (retrocompatibile)
    ' Questi metodi DEVONO esistere perché sono chiamati dalle pagine.
    ' =========================================================

    ' 1) Chiamata attuale (da Default.aspx.vb): SeoBuilder.ApplyHomeSeo(Me.Page)
    Public Shared Sub ApplyHomeSeo(ByVal page As Page)
        If page Is Nothing Then Return

        Dim canonical As String = GetHomeCanonicalUrl(page)
        Dim title As String = SafeString(page.Title)
        If String.IsNullOrWhiteSpace(title) Then
            title = GetCompanyNameFallback()
        End If

        Dim descr As String = GetDefaultHomeDescription()
        Dim logoUrl As String = GetLogoUrl(page)

        ' Canonical + Meta base
        EnsureCanonical(page, canonical)
        EnsureMetaName(page, "description", descr)
        EnsureMetaName(page, "robots", "index,follow")

        ' OpenGraph base (sempre utile)
        ApplyOpenGraph(page, canonical, title, descr, logoUrl, Nothing)

        ' JSON-LD avanzato Home (usa DataSource esistenti se presenti)
        Dim jsonLd As String = BuildHomeJsonLd(page, title, descr, canonical, logoUrl)
        SetJsonLdOnMaster(page, jsonLd)
    End Sub

    ' 2) Chiamata che avevi in una variante precedente
    Public Shared Function BuildHomeJsonLd(ByVal page As Page,
                                          ByVal pageTitle As String,
                                          ByVal description As String,
                                          ByVal canonicalUrl As String,
                                          ByVal logoUrl As String) As String

        Dim baseUrl As String = GetBaseUrl(page)

        Dim sb As New StringBuilder(8192)
        sb.Append("{")
        sb.Append("""@context"":""https://schema.org"",")
        sb.Append("""@graph"":[")

        ' Organization
        Dim orgId As String = baseUrl & "/#org"
        Dim siteId As String = baseUrl & "/#website"
        Dim pageId As String = canonicalUrl & "#webpage"

        sb.Append("{")
        sb.Append("""@type"":""Organization"",")
        sb.Append("""@id"":""").Append(JsonEscape(orgId)).Append(""",")
        sb.Append("""name"":""").Append(JsonEscape(GetCompanyNameFallback())).Append("""")
        If Not String.IsNullOrWhiteSpace(logoUrl) Then
            sb.Append(",""logo"":{")
            sb.Append("""@type"":""ImageObject"",")
            sb.Append("""url"":""").Append(JsonEscape(logoUrl)).Append("""")
            sb.Append("}")
        End If
        sb.Append("},")

        ' WebSite + SearchAction
        sb.Append("{")
        sb.Append("""@type"":""WebSite"",")
        sb.Append("""@id"":""").Append(JsonEscape(siteId)).Append(""",")
        sb.Append("""url"":""").Append(JsonEscape(baseUrl & "/")).Append(""",")
        sb.Append("""name"":""").Append(JsonEscape(GetCompanyNameFallback())).Append(""",")
        sb.Append("""potentialAction"":{")
        sb.Append("""@type"":""SearchAction"",")
        sb.Append("""target"":""").Append(JsonEscape(baseUrl & "/articoli.aspx?q={search_term_string}")).Append(""",")
        sb.Append("""query-input"":""required name=search_term_string""")
        sb.Append("}")
        sb.Append("},")

        ' WebPage (Home)
        sb.Append("{")
        sb.Append("""@type"":""WebPage"",")
        sb.Append("""@id"":""").Append(JsonEscape(pageId)).Append(""",")
        sb.Append("""url"":""").Append(JsonEscape(canonicalUrl)).Append(""",")
        sb.Append("""name"":""").Append(JsonEscape(pageTitle)).Append(""",")
        sb.Append("""description"":""").Append(JsonEscape(description)).Append(""",")
        sb.Append("""isPartOf"":{""@id"":""").Append(JsonEscape(siteId)).Append("""},")
        sb.Append("""about"":{""@id"":""").Append(JsonEscape(orgId)).Append("""}")
        sb.Append("}")

        ' ItemList: categorie
        Dim catList As List(Of JsonItem) = ReadCategoryItemsFromDataSource(page, "Data_Dipartimenti", baseUrl)
        If catList.Count > 0 Then
            sb.Append(",")
            AppendItemList(sb, canonicalUrl & "#categories", "Categorie", catList)
        End If

        ' ItemList: Ultimi Arrivi (ID richiesto: Data_UltimiArrivi; fallback comune: SdsNewArticoli)
        Dim latest As List(Of JsonItem) = ReadProductItemsFromDataSource(page, "Data_UltimiArrivi", baseUrl, 12)
        If latest.Count = 0 Then
            latest = ReadProductItemsFromDataSource(page, "SdsNewArticoli", baseUrl, 12)
        End If
        If latest.Count > 0 Then
            sb.Append(",")
            AppendItemList(sb, canonicalUrl & "#latest", "Ultimi arrivi", latest)
        End If

        ' ItemList: Più acquistati (ID richiesto: sdsPiuAcquistati)
        Dim top As List(Of JsonItem) = ReadProductItemsFromDataSource(page, "sdsPiuAcquistati", baseUrl, 12)
        If top.Count > 0 Then
            sb.Append(",")
            AppendItemList(sb, canonicalUrl & "#top", "Più acquistati", top)
        End If

        sb.Append("]}")
        Return EnsureJsonLdScriptTag(sb.ToString())
    End Function

    ' 3) Chiamata che avevi in una variante precedente
    Public Shared Sub SetJsonLdOnMaster(ByVal page As Page, ByVal jsonLdScriptOrJson As String)
        If page Is Nothing Then Return

        Dim script As String = EnsureJsonLdScriptTag(jsonLdScriptOrJson)

        ' prova su Master
        Dim lit As Literal = Nothing
        If page.Master IsNot Nothing Then
            lit = TryCast(FindControlRecursive(page.Master, "litSeoJsonLd"), Literal)
        End If

        ' fallback: prova su Page
        If lit Is Nothing Then
            lit = TryCast(FindControlRecursive(page, "litSeoJsonLd"), Literal)
        End If

        If lit IsNot Nothing Then
            lit.Text = script
            Return
        End If

        ' fallback: inietta in <head runat="server">
        If page.Header IsNot Nothing Then
            page.Header.Controls.Add(New LiteralControl(script))
        End If
    End Sub

    ' =========================================================
    ' Canonical / Meta / OpenGraph
    ' =========================================================

    Public Shared Sub EnsureCanonical(ByVal page As Page, ByVal canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrWhiteSpace(canonicalUrl) Then Return

        Dim existing As HtmlLink = Nothing
        For Each c As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(c, HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = SafeString(l.Attributes("rel"))
                If rel.Equals("canonical", StringComparison.OrdinalIgnoreCase) Then
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

    Public Shared Sub EnsureMetaName(ByVal page As Page, ByVal metaName As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrWhiteSpace(metaName) Then Return
        If content Is Nothing Then content = ""

        Dim found As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing AndAlso SafeString(m.Name).Equals(metaName, StringComparison.OrdinalIgnoreCase) Then
                found = m
                Exit For
            End If
        Next

        If found Is Nothing Then
            Dim m As New HtmlMeta()
            m.Name = metaName
            m.Content = content
            page.Header.Controls.Add(m)
        Else
            found.Content = content
        End If
    End Sub

    Public Shared Sub EnsureMetaProperty(ByVal page As Page, ByVal propName As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrWhiteSpace(propName) Then Return
        If content Is Nothing Then content = ""

        Dim found As HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing Then
                Dim p As String = SafeString(m.Attributes("property"))
                If p.Equals(propName, StringComparison.OrdinalIgnoreCase) Then
                    found = m
                    Exit For
                End If
            End If
        Next

        If found Is Nothing Then
            Dim m As New HtmlMeta()
            m.Attributes("property") = propName
            m.Content = content
            page.Header.Controls.Add(m)
        Else
            found.Content = content
        End If
    End Sub

    Public Shared Sub ApplyOpenGraph(ByVal page As Page,
                                    ByVal canonicalUrl As String,
                                    ByVal title As String,
                                    ByVal description As String,
                                    ByVal imageUrl As String,
                                    ByVal siteName As String)

        If page Is Nothing OrElse page.Header Is Nothing Then Return

        EnsureMetaProperty(page, "og:url", canonicalUrl)
        EnsureMetaProperty(page, "og:type", "website")
        EnsureMetaProperty(page, "og:title", title)
        EnsureMetaProperty(page, "og:description", description)

        If Not String.IsNullOrWhiteSpace(imageUrl) Then
            EnsureMetaProperty(page, "og:image", imageUrl)
        End If

        If String.IsNullOrWhiteSpace(siteName) Then
            siteName = GetCompanyNameFallback()
        End If
        EnsureMetaProperty(page, "og:site_name", siteName)
    End Sub

    ' =========================================================
    ' JSON-LD helpers
    ' =========================================================

    Private Shared Sub AppendItemList(ByVal sb As StringBuilder,
                                      ByVal listId As String,
                                      ByVal listName As String,
                                      ByVal items As List(Of JsonItem))

        sb.Append("{")
        sb.Append("""@type"":""ItemList"",")
        sb.Append("""@id"":""").Append(JsonEscape(listId)).Append(""",")
        sb.Append("""name"":""").Append(JsonEscape(listName)).Append(""",")
        sb.Append("""itemListElement"":[")

        For i As Integer = 0 To items.Count - 1
            If i > 0 Then sb.Append(",")
            Dim it As JsonItem = items(i)
            sb.Append("{")
            sb.Append("""@type"":""ListItem"",")
            sb.Append("""position"":").Append((i + 1).ToString(CultureInfo.InvariantCulture)).Append(",")
            sb.Append("""item"":{")
            sb.Append("""@type"":""").Append(JsonEscape(it.SchemaType)).Append(""",")
            sb.Append("""name"":""").Append(JsonEscape(it.Name)).Append(""",")
            sb.Append("""url"":""").Append(JsonEscape(it.Url)).Append("""")

            If Not String.IsNullOrWhiteSpace(it.ImageUrl) Then
                sb.Append(",""image"":""").Append(JsonEscape(it.ImageUrl)).Append("""")
            End If
            If Not String.IsNullOrWhiteSpace(it.Sku) Then
                sb.Append(",""sku"":""").Append(JsonEscape(it.Sku)).Append("""")
            End If

            If it.Price.HasValue Then
                sb.Append(",""offers"":{")
                sb.Append("""@type"":""Offer"",")
                sb.Append("""priceCurrency"":""EUR"",")
                sb.Append("""price"":""").Append(it.Price.Value.ToString("0.00", CultureInfo.InvariantCulture)).Append("""")
                sb.Append("}")
            End If

            sb.Append("}") ' item
            sb.Append("}") ' ListItem
        Next

        sb.Append("]") ' itemListElement
        sb.Append("}")
    End Sub

    Private Shared Function ReadCategoryItemsFromDataSource(ByVal page As Page, ByVal dataSourceId As String, ByVal baseUrl As String) As List(Of JsonItem)
        Dim list As New List(Of JsonItem)()

        Dim dv As DataView = SelectDataView(page, dataSourceId)
        If dv Is Nothing Then Return list

        Dim max As Integer = Math.Min(dv.Count, 24)
        For i As Integer = 0 To max - 1
            Dim row As DataRowView = dv(i)
            Dim id As Long = GetLong(row, "id", "CategorieId", "catid")
            Dim name As String = GetString(row, "descrizione", "Descrizione", "nome", "Name", "titolo", "Titolo")
            If String.IsNullOrWhiteSpace(name) Then Continue For

            Dim url As String
            If id > 0 Then
                url = baseUrl & "/articoli.aspx?ct=" & id.ToString(CultureInfo.InvariantCulture)
            Else
                url = baseUrl & "/articoli.aspx"
            End If

            list.Add(New JsonItem With {.SchemaType = "Thing", .Name = name.Trim(), .Url = url})
        Next

        Return list
    End Function

    Private Shared Function ReadProductItemsFromDataSource(ByVal page As Page, ByVal dataSourceId As String, ByVal baseUrl As String, ByVal max As Integer) As List(Of JsonItem)
        Dim list As New List(Of JsonItem)()

        Dim dv As DataView = SelectDataView(page, dataSourceId)
        If dv Is Nothing Then Return list

        Dim take As Integer = Math.Min(dv.Count, Math.Max(1, max))
        For i As Integer = 0 To take - 1
            Dim row As DataRowView = dv(i)

            Dim name As String = GetString(row, "Descrizione1", "descrizione1", "Descrizione", "descrizione", "titolo", "Titolo", "name", "Nome")
            If String.IsNullOrWhiteSpace(name) Then Continue For

            Dim sku As String = GetString(row, "Codice", "codice", "sku", "SKU")
            Dim artId As Long = GetLong(row, "Articoliid", "ArticoliId", "id", "ID")
            Dim tcId As Long = GetLong(row, "TCId", "tcid")

            Dim url As String
            If artId > 0 AndAlso tcId > 0 Then
                url = baseUrl & "/articolo.aspx?id=" & artId.ToString(CultureInfo.InvariantCulture) & "&TCId=" & tcId.ToString(CultureInfo.InvariantCulture)
            ElseIf artId > 0 Then
                url = baseUrl & "/articolo.aspx?id=" & artId.ToString(CultureInfo.InvariantCulture)
            ElseIf tcId > 0 Then
                url = baseUrl & "/articolo.aspx?TCId=" & tcId.ToString(CultureInfo.InvariantCulture)
            Else
                url = baseUrl & "/articolo.aspx"
            End If

            Dim img As String = GetString(row, "img1", "Img1", "immagine", "Immagine", "foto", "Foto")
            Dim imgUrl As String = Nothing
            If Not String.IsNullOrWhiteSpace(img) Then
                ' percorso standard progetto
                imgUrl = baseUrl & "/Public/images/articoli/" & img.Trim().TrimStart("/"c)
            Else
                imgUrl = baseUrl & "/Public/images/nofoto.gif"
            End If

            Dim price As Decimal? = GetBestPrice(row)

            list.Add(New JsonItem With {
                .SchemaType = "Product",
                .Name = name.Trim(),
                .Url = url,
                .ImageUrl = imgUrl,
                .Sku = sku,
                .Price = price
            })
        Next

        Return list
    End Function

    Private Shared Function GetBestPrice(ByVal row As DataRowView) As Decimal?
        ' Strategia robusta:
        ' - se esiste InOfferta e prezzoPromoIvato / prezzoPromo, usa quello
        ' - altrimenti prezzoIvato / prezzo
        Dim inOfferta As Boolean = GetBool(row, "InOfferta", "inofferta", "promo", "Promo")

        Dim pPromoI As Decimal? = GetDecimal(row, "PrezzoPromoIvato", "prezzopromoivato", "PromoIvato")
        Dim pPromo As Decimal? = GetDecimal(row, "prezzoPromo", "PrezzoPromo", "Promo")

        Dim pI As Decimal? = GetDecimal(row, "PrezzoIvato", "prezzoivato")
        Dim p As Decimal? = GetDecimal(row, "Prezzo", "prezzo")

        If inOfferta Then
            If pPromoI.HasValue AndAlso pPromoI.Value > 0D Then Return pPromoI
            If pPromo.HasValue AndAlso pPromo.Value > 0D Then Return pPromo
        End If

        If pI.HasValue AndAlso pI.Value > 0D Then Return pI
        If p.HasValue AndAlso p.Value > 0D Then Return p
        Return Nothing
    End Function

    Private Shared Function SelectDataView(ByVal page As Page, ByVal dataSourceId As String) As DataView
        If page Is Nothing OrElse String.IsNullOrWhiteSpace(dataSourceId) Then Return Nothing

        Dim ctrl As Control = FindControlRecursive(page, dataSourceId)
        Dim sds As SqlDataSource = TryCast(ctrl, SqlDataSource)
        If sds Is Nothing Then Return Nothing

        Try
            Dim o As Object = sds.Select(DataSourceSelectArguments.Empty)
            Return TryCast(o, DataView)
        Catch
            Return Nothing
        End Try
    End Function

    Public Shared Function EnsureJsonLdScriptTag(ByVal jsonOrScript As String) As String
        If String.IsNullOrWhiteSpace(jsonOrScript) Then Return ""
        Dim s As String = jsonOrScript.Trim()
        If s.StartsWith("<script", StringComparison.OrdinalIgnoreCase) Then
            Return s
        End If
        Return "<script type=""application/ld+json"">" & s & "</script>"
    End Function

    ' JSON string escaping “safe” per VB 2012
    Public Shared Function JsonEscape(ByVal value As String) As String
        If value Is Nothing Then Return ""

        Dim sb As New StringBuilder(value.Length + 16)

        For Each ch As Char In value
            Select Case AscW(ch)
                Case 34 ' "
                    sb.Append("\"c) : sb.Append(""""c)
                Case 92 ' \
                    sb.Append("\"c) : sb.Append("\"c)
                Case 8 ' backspace
                    sb.Append("\"c) : sb.Append("b"c)
                Case 12 ' formfeed
                    sb.Append("\"c) : sb.Append("f"c)
                Case 10 ' lf
                    sb.Append("\"c) : sb.Append("n"c)
                Case 13 ' cr
                    sb.Append("\"c) : sb.Append("r"c)
                Case 9 ' tab
                    sb.Append("\"c) : sb.Append("t"c)
                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 Then
                        sb.Append("\u")
                        sb.Append(code.ToString("x4", CultureInfo.InvariantCulture))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function

    ' =========================================================
    ' Control finding
    ' =========================================================

    Public Shared Function FindControlRecursive(ByVal root As Control, ByVal id As String) As Control
        If root Is Nothing OrElse String.IsNullOrWhiteSpace(id) Then Return Nothing

        Dim c As Control = root.FindControl(id)
        If c IsNot Nothing Then Return c

        For Each child As Control In root.Controls
            Dim found As Control = FindControlRecursive(child, id)
            If found IsNot Nothing Then Return found
        Next

        Return Nothing
    End Function

    ' =========================================================
    ' URL / fallback helpers
    ' =========================================================

    Private Shared Function GetBaseUrl(ByVal page As Page) As String
        Dim ctx As HttpContext = HttpContext.Current
        If ctx Is Nothing OrElse ctx.Request Is Nothing Then Return ""

        Dim req As HttpRequest = ctx.Request
        Dim scheme As String = If(req.IsSecureConnection, "https", "http")
        Dim host As String = req.Url.Host
        Dim port As Integer = req.Url.Port

        Dim isDefaultPort As Boolean = (scheme = "http" AndAlso port = 80) OrElse (scheme = "https" AndAlso port = 443)
        If isDefaultPort Then
            Return scheme & "://" & host
        End If
        Return scheme & "://" & host & ":" & port.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Shared Function GetHomeCanonicalUrl(ByVal page As Page) As String
        Dim baseUrl As String = GetBaseUrl(page)
        If String.IsNullOrWhiteSpace(baseUrl) Then Return "/"
        Return baseUrl & "/"
    End Function

    Private Shared Function GetLogoUrl(ByVal page As Page) As String
        ' Prova a leggere da Session (se Page.master.vb la valorizza)
        Dim ctx As HttpContext = HttpContext.Current
        Dim baseUrl As String = GetBaseUrl(page)

        If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing Then
            Dim s As String = SafeString(TryCast(ctx.Session("logo"), Object))
            If Not String.IsNullOrWhiteSpace(s) Then
                ' se è già assoluto
                If s.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse s.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
                    Return s
                End If
                ' se è relativo
                If s.StartsWith("/", StringComparison.Ordinal) Then
                    Return baseUrl & s
                End If
                Return baseUrl & "/" & s
            End If
        End If

        ' fallback
        If Not String.IsNullOrWhiteSpace(baseUrl) Then
            Return baseUrl & "/Public/images/logo.png"
        End If
        Return "/Public/images/logo.png"
    End Function

    Private Shared Function GetCompanyNameFallback() As String
        Dim ctx As HttpContext = HttpContext.Current
        If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing Then
            Dim rs As String = SafeString(TryCast(ctx.Session("ragionesociale"), Object))
            If Not String.IsNullOrWhiteSpace(rs) Then Return rs.Trim()
        End If
        Return "KeepStore"
    End Function

    Private Shared Function GetDefaultHomeDescription() As String
        ' descrizione “safe” (non dipende da tabelle DB)
        Dim name As String = GetCompanyNameFallback()
        Return name & " - Catalogo online, offerte e nuovi arrivi. Spedizione rapida e assistenza clienti."
    End Function

    Private Shared Function SafeString(ByVal o As Object) As String
        If o Is Nothing Then Return ""
        Return Convert.ToString(o, CultureInfo.InvariantCulture)
    End Function

    ' =========================================================
    ' DataRowView safe getters
    ' =========================================================

    Private Shared Function HasCol(ByVal row As DataRowView, ByVal colName As String) As Boolean
        If row Is Nothing OrElse row.DataView Is Nothing OrElse row.DataView.Table Is Nothing Then Return False
        Return row.DataView.Table.Columns.Contains(colName)
    End Function

    Private Shared Function GetString(ByVal row As DataRowView, ByVal ParamArray names() As String) As String
        For Each n As String In names
            If Not String.IsNullOrWhiteSpace(n) AndAlso HasCol(row, n) Then
                Dim o As Object = row(n)
                If o IsNot Nothing AndAlso o IsNot DBNull.Value Then
                    Dim s As String = Convert.ToString(o, CultureInfo.InvariantCulture)
                    If Not String.IsNullOrWhiteSpace(s) Then Return s
                End If
            End If
        Next
        Return ""
    End Function

    Private Shared Function GetLong(ByVal row As DataRowView, ByVal ParamArray names() As String) As Long
        For Each n As String In names
            If Not String.IsNullOrWhiteSpace(n) AndAlso HasCol(row, n) Then
                Dim o As Object = row(n)
                If o IsNot Nothing AndAlso o IsNot DBNull.Value Then
                    Dim s As String = Convert.ToString(o, CultureInfo.InvariantCulture)
                    Dim v As Long
                    If Long.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, v) Then Return v
                End If
            End If
        Next
        Return 0L
    End Function

    Private Shared Function GetDecimal(ByVal row As DataRowView, ByVal ParamArray names() As String) As Decimal?
        For Each n As String In names
            If Not String.IsNullOrWhiteSpace(n) AndAlso HasCol(row, n) Then
                Dim o As Object = row(n)
                If o IsNot Nothing AndAlso o IsNot DBNull.Value Then
                    Dim v As Decimal
                    If TypeOf o Is Decimal Then
                        v = DirectCast(o, Decimal)
                        Return v
                    End If
                    Dim s As String = Convert.ToString(o, CultureInfo.InvariantCulture)
                    If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, v) Then Return v
                End If
            End If
        Next
        Return Nothing
    End Function

    Private Shared Function GetBool(ByVal row As DataRowView, ByVal ParamArray names() As String) As Boolean
        For Each n As String In names
            If Not String.IsNullOrWhiteSpace(n) AndAlso HasCol(row, n) Then
                Dim o As Object = row(n)
                If o IsNot Nothing AndAlso o IsNot DBNull.Value Then
                    If TypeOf o Is Boolean Then Return DirectCast(o, Boolean)
                    Dim s As String = Convert.ToString(o, CultureInfo.InvariantCulture).Trim()
                    If s = "1" OrElse s.Equals("true", StringComparison.OrdinalIgnoreCase) Then Return True
                End If
            End If
        Next
        Return False
    End Function

    ' =========================================================
    ' Internal model
    ' =========================================================

    Private Class JsonItem
        Public Property SchemaType As String
        Public Property Name As String
        Public Property Url As String
        Public Property ImageUrl As String
        Public Property Sku As String
        Public Property Price As Decimal?
    End Class

End Class
