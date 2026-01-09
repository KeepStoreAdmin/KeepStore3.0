Option Strict On
Option Explicit On

Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Data
Imports System.Text
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.UI.HtmlControls

' ============================================================
' SeoBuilder.vb
' - Compatibilità VB.NET (.NET 4.x / VB 2012)
' - Nessuna interfaccia (evita duplicati tipo ISeoMaster)
' - JSON-LD Home: tenta di leggere categorie/prodotti dai DataSource
'   già presenti in Default.aspx (o dai controlli che li usano).
' ============================================================

Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' ------------------------------------------------------------
    ' API pubblica (usata da Default.aspx.vb)
    ' ------------------------------------------------------------

    ' NOTA: questa signature è quella che il tuo Default.aspx.vb sta usando
    ' (vedi errore: SeoBuilder.BuildHomeJsonLd(Me, pageTitle, descr, canonical, logoUrl))
    Public Shared Function BuildHomeJsonLd(ByVal page As Page,
                                           ByVal pageTitle As String,
                                           ByVal descr As String,
                                           ByVal canonicalUrl As String,
                                           ByVal logoUrl As String) As String

        Dim baseUrl As String = GetBaseUrl(page)
        Dim canonicalAbs As String = ToAbsoluteUrl(page, canonicalUrl)

        ' Raccolta dati (best-effort) da controlli/DataSource esistenti
        Dim dvCats As DataView = FirstNonEmptyDataView(page,
            New String() {"Data_Dipartimenti", "SdsHeroCats", "rptHeroCats"})

        Dim dvNew As DataView = FirstNonEmptyDataView(page,
            New String() {"Data_UltimiArrivi", "Repeat_Lista_Nuovi_Arrivi", "SdsNewArticoli", "SdsArticoliInVetrina"})

        Dim dvBest As DataView = FirstNonEmptyDataView(page,
            New String() {"sdsPiuAcquistati", "DataList1", "rptPiuAcquistati"})

        Dim hostName As String = TryGetHostName(page)
        Dim siteName As String = If(String.IsNullOrWhiteSpace(hostName), "Sito e-commerce", hostName)

        ' @graph
        Dim graph As New List(Of Object)()

        Dim orgId As String = baseUrl.TrimEnd("/"c) & "#organization"
        Dim webSiteId As String = baseUrl.TrimEnd("/"c) & "#website"
        Dim webPageId As String = canonicalAbs & "#webpage"

        ' Organization
        Dim org As New Dictionary(Of String, Object)()
        org("@type") = "Organization"
        org("@id") = orgId
        org("name") = siteName
        org("url") = baseUrl

        Dim logoAbs As String = ToAbsoluteUrl(page, logoUrl)
        If Not String.IsNullOrWhiteSpace(logoAbs) Then
            Dim logo As New Dictionary(Of String, Object)()
            logo("@type") = "ImageObject"
            logo("url") = logoAbs
            org("logo") = logo
        End If
        graph.Add(org)

        ' WebSite
        Dim website As New Dictionary(Of String, Object)()
        website("@type") = "WebSite"
        website("@id") = webSiteId
        website("url") = baseUrl
        website("name") = siteName
        website("publisher") = New Dictionary(Of String, Object)() From {{"@id", orgId}}
        graph.Add(website)

        ' WebPage (Home)
        Dim webpage As New Dictionary(Of String, Object)()
        webpage("@type") = "WebPage"
        webpage("@id") = webPageId
        webpage("url") = canonicalAbs
        webpage("isPartOf") = New Dictionary(Of String, Object)() From {{"@id", webSiteId}}
        webpage("about") = New Dictionary(Of String, Object)() From {{"@id", orgId}}

        If Not String.IsNullOrWhiteSpace(pageTitle) Then
            webpage("name") = pageTitle
        End If
        If Not String.IsNullOrWhiteSpace(descr) Then
            webpage("description") = descr
        End If
        graph.Add(webpage)

        ' BreadcrumbList (Home)
        Dim crumbs As New Dictionary(Of String, Object)()
        crumbs("@type") = "BreadcrumbList"
        crumbs("@id") = canonicalAbs & "#breadcrumb"
        crumbs("itemListElement") = New List(Of Object)() From {
            New Dictionary(Of String, Object)() From {
                {"@type", "ListItem"},
                {"position", 1},
                {"name", "Home"},
                {"item", canonicalAbs}
            }
        }
        graph.Add(crumbs)

        ' ItemList categorie
        Dim catList As Dictionary(Of String, Object) = BuildCategoryItemList(page, dvCats, canonicalAbs)
        If catList IsNot Nothing Then
            graph.Add(catList)
        End If

        ' ItemList prodotti (ultimi arrivi)
        Dim newList As Dictionary(Of String, Object) = BuildProductItemList(page, dvNew, canonicalAbs, "Ultimi arrivi", "#ultimi-arrivi", 12)
        If newList IsNot Nothing Then
            graph.Add(newList)
        End If

        ' ItemList prodotti (più acquistati)
        Dim bestList As Dictionary(Of String, Object) = BuildProductItemList(page, dvBest, canonicalAbs, "Più acquistati", "#piu-acquistati", 12)
        If bestList IsNot Nothing Then
            graph.Add(bestList)
        End If

        Dim root As New Dictionary(Of String, Object)()
        root("@context") = "https://schema.org"
        root("@graph") = graph

        Return SerializeJson(root)
    End Function

    ' NOTA: questa Sub è quella che il tuo Default.aspx.vb sta usando
    ' (vedi errore: SeoBuilder.SetJsonLdOnMaster(Me, jsonLdScript))
    Public Shared Sub SetJsonLdOnMaster(ByVal page As Page, ByVal jsonLdOrScript As String)
        If page Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(jsonLdOrScript) Then Exit Sub

        Dim payload As String = EnsureJsonLdScriptTag(jsonLdOrScript)

        ' 1) Preferenza: Literal in MasterPage <asp:Literal ID="litSeoJsonLd" ... />
        Dim lit As Literal = TryCast(FindControlRecursive(page.Master, "litSeoJsonLd"), Literal)
        If lit IsNot Nothing Then
            lit.Text = payload
            Exit Sub
        End If

        ' 2) Fallback: aggiunge direttamente in <head>
        If page.Header IsNot Nothing Then
            ' Evita duplicati sullo stesso ciclo pagina
            Dim existing As Control = FindControlRecursive(page.Header, "litSeoJsonLdFallback")
            If existing IsNot Nothing Then
                Dim litExisting As Literal = TryCast(existing, Literal)
                If litExisting IsNot Nothing Then
                    litExisting.Text = payload
                    Exit Sub
                End If
            End If

            Dim l As New Literal()
            l.ID = "litSeoJsonLdFallback"
            l.Text = payload
            page.Header.Controls.Add(l)
        End If
    End Sub

    ' ------------------------------------------------------------
    ' Helpers SEO base (meta/canonical/OpenGraph)
    ' ------------------------------------------------------------

    Public Shared Sub EnsureCanonical(ByVal page As Page, ByVal canonicalUrl As String)
        If page Is Nothing Then Exit Sub
        If page.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(canonicalUrl) Then Exit Sub

        Dim absUrl As String = ToAbsoluteUrl(page, canonicalUrl)

        ' cerca link rel=canonical già esistente
        For Each c As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(c, HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = Convert.ToString(l.Attributes("rel"))
                If String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    l.Href = absUrl
                    Exit Sub
                End If
            End If
        Next

        Dim canon As New HtmlLink()
        canon.Attributes("rel") = "canonical"
        canon.Href = absUrl
        page.Header.Controls.Add(canon)
    End Sub

    Private Shared Sub EnsureMeta(ByVal page As Page, ByVal name As String, ByVal content As String)
        If page Is Nothing Then Exit Sub
        If page.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(name) Then Exit Sub
        If String.IsNullOrWhiteSpace(content) Then Exit Sub

        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing Then
                If String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                    m.Content = content
                    Exit Sub
                End If
            End If
        Next

        Dim meta As New HtmlMeta()
        meta.Name = name
        meta.Content = content
        page.Header.Controls.Add(meta)
    End Sub

    Private Shared Sub EnsureMetaProperty(ByVal page As Page, ByVal prop As String, ByVal content As String)
        If page Is Nothing Then Exit Sub
        If page.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(prop) Then Exit Sub
        If String.IsNullOrWhiteSpace(content) Then Exit Sub

        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing Then
                Dim p As String = Convert.ToString(m.Attributes("property"))
                If String.Equals(p, prop, StringComparison.OrdinalIgnoreCase) Then
                    m.Content = content
                    Exit Sub
                End If
            End If
        Next

        Dim meta As New HtmlMeta()
        meta.Attributes("property") = prop
        meta.Content = content
        page.Header.Controls.Add(meta)
    End Sub

    Public Shared Sub ApplyOpenGraph(ByVal page As Page,
                                    ByVal title As String,
                                    ByVal descr As String,
                                    ByVal canonicalUrl As String,
                                    ByVal imageUrl As String)

        If page Is Nothing Then Exit Sub
        If page.Header Is Nothing Then Exit Sub

        Dim canonAbs As String = ToAbsoluteUrl(page, canonicalUrl)
        Dim imgAbs As String = ToAbsoluteUrl(page, imageUrl)

        EnsureMetaProperty(page, "og:type", "website")
        If Not String.IsNullOrWhiteSpace(title) Then EnsureMetaProperty(page, "og:title", title)
        If Not String.IsNullOrWhiteSpace(descr) Then EnsureMetaProperty(page, "og:description", descr)
        If Not String.IsNullOrWhiteSpace(canonAbs) Then EnsureMetaProperty(page, "og:url", canonAbs)
        If Not String.IsNullOrWhiteSpace(imgAbs) Then EnsureMetaProperty(page, "og:image", imgAbs)

        ' Twitter Card (minimale)
        EnsureMeta(page, "twitter:card", If(String.IsNullOrWhiteSpace(imgAbs), "summary", "summary_large_image"))
        If Not String.IsNullOrWhiteSpace(title) Then EnsureMeta(page, "twitter:title", title)
        If Not String.IsNullOrWhiteSpace(descr) Then EnsureMeta(page, "twitter:description", descr)
        If Not String.IsNullOrWhiteSpace(imgAbs) Then EnsureMeta(page, "twitter:image", imgAbs)
    End Sub

    ' ------------------------------------------------------------
    ' JSON-LD builders (ItemList categorie/prodotti)
    ' ------------------------------------------------------------

    Private Shared Function BuildCategoryItemList(ByVal page As Page, ByVal dv As DataView, ByVal canonicalAbs As String) As Dictionary(Of String, Object)
        If dv Is Nothing OrElse dv.Count = 0 Then Return Nothing

        Dim listItems As New List(Of Object)()
        Dim pos As Integer = 1

        For Each drv As DataRowView In dv
            If pos > 24 Then Exit For

            Dim name As String = GetStringField(drv, "descrizione", "Descrizione", "nome", "Nome", "name", "Name", "titolo", "Titolo")
            If String.IsNullOrWhiteSpace(name) Then Continue For

            Dim ct As Integer = GetIntField(drv, "ct", "CT", "CategoriaId", "categoriaid", "id", "ID")
            Dim st As Integer = GetIntField(drv, "st", "ST", "SettoreId", "settoreid", "id_settore", "Id_Settore", "settore", "Settore")

            Dim rel As String = BuildCategoryRelativeUrl(st, ct)
            If String.IsNullOrWhiteSpace(rel) Then Continue For

            Dim url As String = CombineAbsolute(GetBaseUrl(page), rel)

            Dim item As New Dictionary(Of String, Object)()
            item("@type") = "ListItem"
            item("position") = pos
            item("item") = New Dictionary(Of String, Object)() From {
                {"@id", url},
                {"name", name}
            }

            listItems.Add(item)
            pos += 1
        Next

        If listItems.Count = 0 Then Return Nothing

        Dim catList As New Dictionary(Of String, Object)()
        catList("@type") = "ItemList"
        catList("@id") = canonicalAbs & "#categorie"
        catList("name") = "Categorie"
        catList("itemListElement") = listItems
        Return catList
    End Function

    Private Shared Function BuildProductItemList(ByVal page As Page,
                                                ByVal dv As DataView,
                                                ByVal canonicalAbs As String,
                                                ByVal listName As String,
                                                ByVal anchor As String,
                                                ByVal maxItems As Integer) As Dictionary(Of String, Object)

        If dv Is Nothing OrElse dv.Count = 0 Then Return Nothing

        Dim listItems As New List(Of Object)()
        Dim pos As Integer = 1

        For Each drv As DataRowView In dv
            If pos > maxItems Then Exit For

            Dim name As String = GetStringField(drv, "descrizione", "Descrizione", "nome", "Nome", "name", "Name", "titolo", "Titolo")
            If String.IsNullOrWhiteSpace(name) Then Continue For

            Dim id As Integer = GetIntField(drv, "ArticoliId", "articoliid", "id", "ID")
            Dim tcId As Integer = GetIntField(drv, "TCId", "tcid", "TC", "tc")
            If tcId = 0 Then tcId = -1

            Dim relUrl As String = ""
            If id > 0 Then
                relUrl = "articolo.aspx?id=" & id.ToString() & "&TCId=" & tcId.ToString()
            Else
                Dim cod As String = GetStringField(drv, "cod", "Cod", "cod_articolo", "Cod_Articolo", "codice", "Codice")
                If Not String.IsNullOrWhiteSpace(cod) Then
                    relUrl = "articolo.aspx?cod=" & HttpUtility.UrlEncode(cod)
                End If
            End If

            If String.IsNullOrWhiteSpace(relUrl) Then Continue For
            Dim url As String = CombineAbsolute(GetBaseUrl(page), relUrl)

            Dim prod As New Dictionary(Of String, Object)()
            prod("@type") = "Product"
            prod("name") = name
            prod("url") = url

            Dim img As String = GetStringField(drv, "img", "Img", "immagine", "Immagine", "foto", "Foto", "Img1", "img1", "foto1", "Foto1")
            Dim imgAbs As String = NormalizeImageUrl(page, img)
            If Not String.IsNullOrWhiteSpace(imgAbs) Then
                prod("image") = imgAbs
            End If

            Dim item As New Dictionary(Of String, Object)()
            item("@type") = "ListItem"
            item("position") = pos
            item("item") = prod

            listItems.Add(item)
            pos += 1
        Next

        If listItems.Count = 0 Then Return Nothing

        Dim pl As New Dictionary(Of String, Object)()
        pl("@type") = "ItemList"
        pl("@id") = canonicalAbs & anchor
        pl("name") = listName
        pl("itemListElement") = listItems
        Return pl
    End Function

    Private Shared Function BuildCategoryRelativeUrl(ByVal st As Integer, ByVal ct As Integer) As String
        ' Su webaffare.it (legacy) i link categoria risultano tipicamente: articoli.aspx?st=X&ct=Y
        If st > 0 AndAlso ct > 0 Then
            Return "articoli.aspx?st=" & st.ToString() & "&ct=" & ct.ToString()
        End If

        ' fallback (se il datasource restituisce solo uno dei due)
        If ct > 0 Then
            Return "articoli.aspx?ct=" & ct.ToString()
        End If
        If st > 0 Then
            Return "articoli.aspx?st=" & st.ToString()
        End If
        Return ""
    End Function

    ' ------------------------------------------------------------
    ' DataSource helpers
    ' ------------------------------------------------------------

    Private Shared Function FirstNonEmptyDataView(ByVal page As Page, ByVal ids As String()) As DataView
        If ids Is Nothing Then Return Nothing
        For Each id As String In ids
            Dim dv As DataView = TrySelectDataView(page, id)
            If dv IsNot Nothing AndAlso dv.Count > 0 Then Return dv
        Next
        Return Nothing
    End Function

    Private Shared Function TrySelectDataView(ByVal page As Page, ByVal idOrControl As String) As DataView
        If page Is Nothing Then Return Nothing
        If String.IsNullOrWhiteSpace(idOrControl) Then Return Nothing

        ' 1) cerca un SqlDataSource con questo ID
        Dim ds As SqlDataSource = TryCast(FindControlRecursive(page, idOrControl), SqlDataSource)
        If ds Is Nothing Then ds = TryCast(FindControlRecursive(page.Master, idOrControl), SqlDataSource)

        If ds IsNot Nothing Then
            Return SelectToDataView(ds)
        End If

        ' 2) se l'ID è un controllo (Repeater/DataList/ListView) che usa DataSourceID,
        '    risolve il relativo DataSource e lo seleziona.
        Dim ctrl As Control = FindControlRecursive(page, idOrControl)
        If ctrl Is Nothing Then ctrl = FindControlRecursive(page.Master, idOrControl)
        If ctrl Is Nothing Then Return Nothing

        Dim prop = ctrl.GetType().GetProperty("DataSourceID")
        If prop Is Nothing Then Return Nothing

        Dim dsid As String = TryCast(prop.GetValue(ctrl, Nothing), String)
        If String.IsNullOrWhiteSpace(dsid) Then Return Nothing

        Dim ds2 As SqlDataSource = TryCast(FindControlRecursive(page, dsid), SqlDataSource)
        If ds2 Is Nothing Then ds2 = TryCast(FindControlRecursive(page.Master, dsid), SqlDataSource)
        If ds2 Is Nothing Then Return Nothing

        Return SelectToDataView(ds2)
    End Function

    Private Shared Function SelectToDataView(ByVal ds As SqlDataSource) As DataView
        If ds Is Nothing Then Return Nothing
        Try
            Dim data As IEnumerable = TryCast(ds.Select(DataSourceSelectArguments.Empty), IEnumerable)
            Dim dv As DataView = TryCast(data, DataView)
            If dv IsNot Nothing Then Return dv

            Dim dt As DataTable = TryCast(data, DataTable)
            If dt IsNot Nothing Then Return dt.DefaultView

        Catch
            ' Best-effort: non blocca la pagina se il datasource non è selezionabile in quel momento
        End Try
        Return Nothing
    End Function

    Private Shared Function FindControlRecursive(ByVal root As Control, ByVal id As String) As Control
        If root Is Nothing Then Return Nothing
        If String.IsNullOrEmpty(id) Then Return Nothing

        Dim direct As Control = root.FindControl(id)
        If direct IsNot Nothing Then Return direct

        For Each child As Control In root.Controls
            Dim found As Control = FindControlRecursive(child, id)
            If found IsNot Nothing Then Return found
        Next

        Return Nothing
    End Function

    ' ------------------------------------------------------------
    ' Utility URL / JSON
    ' ------------------------------------------------------------

    Private Shared Function GetBaseUrl(ByVal page As Page) As String
        If page Is Nothing OrElse HttpContext.Current Is Nothing Then Return ""
        Dim req As HttpRequest = HttpContext.Current.Request
        Dim uri As Uri = req.Url
        Dim baseUrl As String = uri.Scheme & "://" & uri.Authority & req.ApplicationPath
        If Not baseUrl.EndsWith("/"c) Then baseUrl &= "/"
        Return baseUrl
    End Function

    Private Shared Function TryGetHostName(ByVal page As Page) As String
        Try
            If HttpContext.Current Is Nothing OrElse HttpContext.Current.Request Is Nothing Then Return ""
            Return HttpContext.Current.Request.Url.Host
        Catch
            Return ""
        End Try
    End Function

    Private Shared Function CombineAbsolute(ByVal baseUrl As String, ByVal relativeOrAbs As String) As String
        If String.IsNullOrWhiteSpace(relativeOrAbs) Then Return baseUrl
        If relativeOrAbs.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse relativeOrAbs.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return relativeOrAbs
        End If
        If relativeOrAbs.StartsWith("/"c) Then
            Return baseUrl.TrimEnd("/"c) & relativeOrAbs
        End If
        Return baseUrl.TrimEnd("/"c) & "/" & relativeOrAbs.TrimStart("/"c)
    End Function

    Public Shared Function ToAbsoluteUrl(ByVal page As Page, ByVal url As String) As String
        If String.IsNullOrWhiteSpace(url) Then Return ""
        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return url
        End If
        Dim baseUrl As String = GetBaseUrl(page)
        Return CombineAbsolute(baseUrl, url)
    End Function

    Private Shared Function NormalizeImageUrl(ByVal page As Page, ByVal img As String) As String
        If String.IsNullOrWhiteSpace(img) Then Return ""

        Dim trimmed As String = img.Trim()
        If trimmed.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse trimmed.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return trimmed
        End If

        If trimmed.StartsWith("/"c) Then
            Return CombineAbsolute(GetBaseUrl(page), trimmed)
        End If

        ' Se è un filename, prova il percorso standard immagini prodotto
        If trimmed.IndexOf("/"c) < 0 AndAlso trimmed.IndexOf("\"c) < 0 Then
            Return CombineAbsolute(GetBaseUrl(page), "Public/images/articoli/" & trimmed)
        End If

        Return CombineAbsolute(GetBaseUrl(page), trimmed)
    End Function

    Private Shared Function EnsureJsonLdScriptTag(ByVal jsonLdOrScript As String) As String
        Dim t As String = jsonLdOrScript.Trim()
        If t.StartsWith("<script", StringComparison.OrdinalIgnoreCase) Then Return t
        Return "<script type=""application/ld+json"">" & t & "</script>"
    End Function

    Private Shared Function SerializeJson(ByVal obj As Object) As String
        Dim jss As New JavaScriptSerializer()
        jss.MaxJsonLength = Integer.MaxValue
        Return jss.Serialize(obj)
    End Function

    ' Mantengo JsonEscape PUBLIC perché spesso torna utile anche altrove;
    ' qui è corretta (niente escape C# con \" o char costanti errate).
    Public Shared Function JsonEscape(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim sb As New StringBuilder(value.Length + 16)

        For Each ch As Char In value
            Select Case ch
                Case """"c
                    sb.Append("\\""") ' => \"
                Case "\"c
                    sb.Append("\\")   ' => \\
                Case ChrW(8) ' backspace
                    sb.Append("\b")
                Case ChrW(12) ' form feed
                    sb.Append("\f")
                Case ChrW(10) ' \n
                    sb.Append("\n")
                Case ChrW(13) ' \r
                    sb.Append("\r")
                Case ChrW(9) ' \t
                    sb.Append("\t")
                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 Then
                        sb.Append("\u")
                        sb.Append(code.ToString("x4"))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function

    Private Shared Function GetStringField(ByVal drv As DataRowView, ByVal ParamArray names() As String) As String
        If drv Is Nothing OrElse names Is Nothing Then Return ""
        For Each n As String In names
            If String.IsNullOrWhiteSpace(n) Then Continue For
            If HasColumn(drv, n) Then
                Dim o As Object = drv(n)
                If o IsNot Nothing AndAlso o IsNot DBNull.Value Then
                    Return Convert.ToString(o)
                End If
            End If
        Next
        Return ""
    End Function

    Private Shared Function GetIntField(ByVal drv As DataRowView, ByVal ParamArray names() As String) As Integer
        If drv Is Nothing OrElse names Is Nothing Then Return 0
        For Each n As String In names
            If String.IsNullOrWhiteSpace(n) Then Continue For
            If HasColumn(drv, n) Then
                Dim o As Object = drv(n)
                If o IsNot Nothing AndAlso o IsNot DBNull.Value Then
                    Dim s As String = Convert.ToString(o)
                    Dim v As Integer = 0
                    If Integer.TryParse(s, v) Then Return v
                End If
            End If
        Next
        Return 0
    End Function

    Private Shared Function HasColumn(ByVal drv As DataRowView, ByVal name As String) As Boolean
        If drv Is Nothing OrElse drv.DataView Is Nothing OrElse drv.DataView.Table Is Nothing Then Return False
        If drv.DataView.Table.Columns.Contains(name) Then Return True

        ' fallback case-insensitive
        For Each col As DataColumn In drv.DataView.Table.Columns
            If String.Equals(col.ColumnName, name, StringComparison.OrdinalIgnoreCase) Then Return True
        Next
        Return False
    End Function

End Class
