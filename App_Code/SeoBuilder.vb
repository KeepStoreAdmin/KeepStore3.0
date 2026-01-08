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

' ============================================================
' SeoBuilder.vb
' - Compatibile VB 2012 / .NET 4.x / Option Strict On
' - NON usa interfacce (evita conflitti tipo ISeoMaster duplicata)
' - Canonical senza HtmlLink.Rel (usa Attributes("rel"))
' - JSON-LD Home: usa i 3 ID richiesti:
'     Data_Dipartimenti (categorie)
'     Data_UltimiArrivi (ultimi arrivi)
'     sdsPiuAcquistati (più acquistati)
' ============================================================
Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' Entry-point: chiamalo da Default.aspx.vb (es. Page_PreRender)
    Public Shared Sub ApplyHomeSeo(ByVal page As Page)
        If page Is Nothing OrElse page.Request Is Nothing Then Exit Sub
        If page.Header Is Nothing Then Exit Sub

        Dim baseUrl As String = page.Request.Url.Scheme & "://" & page.Request.Url.Authority
        Dim canonical As String = baseUrl & VirtualPathUtility.ToAbsolute("~/")

        EnsureCanonical(page, canonical)

        Dim jsonLd As String = BuildHomeJsonLd(page, baseUrl, canonical)
        If String.IsNullOrWhiteSpace(jsonLd) Then Exit Sub

        InjectJsonLdIntoHead(page, jsonLd)
    End Sub

    ' =========================
    ' Canonical
    ' =========================
    Private Shared Sub EnsureCanonical(ByVal page As Page, ByVal canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        Dim found As HtmlLink = Nothing

        For Each ctrl As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(ctrl, HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = Convert.ToString(l.Attributes("rel"))
                If String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
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

        found.Href = canonicalUrl
    End Sub

    ' =========================
    ' JSON-LD injection
    ' =========================
    Private Shared Sub InjectJsonLdIntoHead(ByVal page As Page, ByVal json As String)
        Dim payload As String = json

        ' Se non è già un <script>, lo wrappo correttamente (escape VB: "" )
        If payload.IndexOf("<script", StringComparison.OrdinalIgnoreCase) < 0 Then
            payload = "<script type=""application/ld+json"">" & payload & "</script>"
        End If

        ' 1) prova Literal in master/page: litSeoJsonLd
        Dim lit As Literal = TryCast(FindControlDeep(page, "litSeoJsonLd"), Literal)
        If lit IsNot Nothing Then
            lit.Text = payload
            Exit Sub
        End If

        ' 2) fallback: aggiungo un Literal nel <head>
        Dim l2 As New Literal()
        l2.Text = payload
        page.Header.Controls.Add(l2)
    End Sub

    ' =========================
    ' Home JSON-LD builder
    ' =========================
    Private Shared Function BuildHomeJsonLd(ByVal page As Page, ByVal baseUrl As String, ByVal canonicalUrl As String) As String
        ' Recupero i DataView (tollerante: può essere SqlDataSource o controllo databound con DataSourceID)
        Dim dvCats As DataView = TrySelectDataView(page, "Data_Dipartimenti")
        Dim dvNew As DataView = TrySelectDataView(page, "Data_UltimiArrivi")
        Dim dvBest As DataView = TrySelectDataView(page, "sdsPiuAcquistati")

        ' Se non ho nulla, non genero JSON-LD (non devo rompere nulla)
        If (dvCats Is Nothing OrElse dvCats.Count = 0) AndAlso (dvNew Is Nothing OrElse dvNew.Count = 0) AndAlso (dvBest Is Nothing OrElse dvBest.Count = 0) Then
            Return String.Empty
        End If

        Dim siteName As String = SafeString(page.Title)
        If String.IsNullOrWhiteSpace(siteName) Then siteName = page.Request.Url.Host

        Dim sb As New StringBuilder(4096)

        sb.Append("{")
        sb.Append("""@context"":""https://schema.org"",")
        sb.Append("""@graph"":[")

        ' WebSite
        sb.Append("{")
        sb.Append("""@type"":""WebSite"",")
        sb.Append("""@id"":""").Append(JsonEscape(canonicalUrl)).Append("#website"",")
        sb.Append("""url"":""").Append(JsonEscape(canonicalUrl)).Append(""",")
        sb.Append("""name"":""").Append(JsonEscape(siteName)).Append("""")
        sb.Append("},")

        ' WebPage (Home)
        sb.Append("{")
        sb.Append("""@type"":""WebPage"",")
        sb.Append("""@id"":""").Append(JsonEscape(canonicalUrl)).Append("#webpage"",")
        sb.Append("""url"":""").Append(JsonEscape(canonicalUrl)).Append(""",")
        sb.Append("""name"":""").Append(JsonEscape(siteName)).Append("""")
        sb.Append("},")

        ' BreadcrumbList (Home)
        sb.Append("{")
        sb.Append("""@type"":""BreadcrumbList"",")
        sb.Append("""@id"":""").Append(JsonEscape(canonicalUrl)).Append("#breadcrumb"",")
        sb.Append("""itemListElement"":[")
        sb.Append("{")
        sb.Append("""@type"":""ListItem"",")
        sb.Append("""position"":1,")
        sb.Append("""name"":""Home"",")
        sb.Append("""item"":""").Append(JsonEscape(canonicalUrl)).Append("""")
        sb.Append("}")
        sb.Append("]")
        sb.Append("}")

        ' ItemList Categorie
        Dim catsJson As String = BuildCategoryItemList(dvCats, baseUrl, canonicalUrl)
        If Not String.IsNullOrWhiteSpace(catsJson) Then
            sb.Append(",")
            sb.Append(catsJson)
        End If

        ' ItemList Ultimi Arrivi
        Dim newJson As String = BuildProductItemList(dvNew, baseUrl, canonicalUrl, "Ultimi arrivi", "#ultimi-arrivi")
        If Not String.IsNullOrWhiteSpace(newJson) Then
            sb.Append(",")
            sb.Append(newJson)
        End If

        ' ItemList Più Acquistati
        Dim bestJson As String = BuildProductItemList(dvBest, baseUrl, canonicalUrl, "Più acquistati", "#piu-acquistati")
        If Not String.IsNullOrWhiteSpace(bestJson) Then
            sb.Append(",")
            sb.Append(bestJson)
        End If

        sb.Append("]}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildCategoryItemList(ByVal dv As DataView, ByVal baseUrl As String, ByVal canonicalUrl As String) As String
        If dv Is Nothing OrElse dv.Count = 0 Then Return String.Empty

        Dim sb As New StringBuilder(1024)

        sb.Append("{")
        sb.Append("""@type"":""ItemList"",")
        sb.Append("""@id"":""").Append(JsonEscape(canonicalUrl)).Append("#categorie"",")
        sb.Append("""name"":""Categorie"",")
        sb.Append("""itemListElement"":[")

        Dim pos As Integer = 0
        For Each r As DataRowView In dv
            Dim catId As String = FirstExisting(r, "TCId", "Id", "ID", "CodCategoria", "cod_categoria", "codice")
            Dim catName As String = FirstExisting(r, "Descrizione", "Descrizione1", "Categoria", "Nome", "name")

            If String.IsNullOrWhiteSpace(catName) Then
                ' Se non ho nemmeno un nome, salto (non devo inventare)
                Continue For
            End If

            pos += 1
            If pos > 30 Then Exit For

            Dim url As String = baseUrl & VirtualPathUtility.ToAbsolute("~/articoli.aspx") & "?ct=" & HttpUtility.UrlEncode(SafeString(catId)) & "&st=1"

            If pos > 1 Then sb.Append(",")

            sb.Append("{")
            sb.Append("""@type"":""ListItem"",")
            sb.Append("""position"":").Append(pos).Append(",")
            sb.Append("""name"":""").Append(JsonEscape(catName)).Append(""",")
            sb.Append("""item"":""").Append(JsonEscape(url)).Append("""")
            sb.Append("}")
        Next

        sb.Append("]")
        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildProductItemList(ByVal dv As DataView, ByVal baseUrl As String, ByVal canonicalUrl As String, ByVal listName As String, ByVal idSuffix As String) As String
        If dv Is Nothing OrElse dv.Count = 0 Then Return String.Empty

        Dim sb As New StringBuilder(2048)

        sb.Append("{")
        sb.Append("""@type"":""ItemList"",")
        sb.Append("""@id"":""").Append(JsonEscape(canonicalUrl)).Append(JsonEscape(idSuffix)).Append(""",")
        sb.Append("""name"":""").Append(JsonEscape(listName)).Append(""",")
        sb.Append("""itemListElement"":[")

        Dim pos As Integer = 0
        For Each r As DataRowView In dv
            Dim code As String = FirstExisting(r, "Codice", "codice", "CodArticolo", "cod_articolo", "SKU", "sku")
            Dim d1 As String = FirstExisting(r, "Descrizione1", "descrizione1", "Titolo", "titolo", "Nome", "name")
            Dim d2 As String = FirstExisting(r, "Descrizione2", "descrizione2", "Sottotitolo", "sottotitolo")
            Dim taglia As String = FirstExisting(r, "taglia", "Taglia")
            Dim colore As String = FirstExisting(r, "colore", "Colore")

            Dim name As String = SafeString(d1)
            If Not String.IsNullOrWhiteSpace(d2) Then name = name & " " & SafeString(d2)
            If Not String.IsNullOrWhiteSpace(taglia) Then name = name & " " & SafeString(taglia)
            If Not String.IsNullOrWhiteSpace(colore) Then name = name & " " & SafeString(colore)
            name = name.Trim()

            If String.IsNullOrWhiteSpace(name) Then Continue For

            pos += 1
            If pos > 20 Then Exit For

            Dim url As String = baseUrl & VirtualPathUtility.ToAbsolute("~/articolo.aspx") & "?cod_articolo=" & HttpUtility.UrlEncode(SafeString(code)) & "&st=1"

            ' Prezzo: preferisco promo se InOfferta vero e prezzo promo presente
            Dim inOfferta As Boolean = ToBool(FirstExisting(r, "InOfferta", "inOfferta", "Promo", "promo", "Offerta", "offerta"))
            Dim price As Nullable(Of Decimal) = Nothing

            If inOfferta Then
                price = FirstDecimal(r, "PrezzoPromoIvato", "prezzopromoivato", "PrezzoPromo", "prezzopromo")
            End If
            If Not price.HasValue Then
                price = FirstDecimal(r, "PrezzoIvato", "prezzoivato", "Prezzo", "prezzo")
            End If

            If pos > 1 Then sb.Append(",")

            sb.Append("{")
            sb.Append("""@type"":""ListItem"",")
            sb.Append("""position"":").Append(pos).Append(",")
            sb.Append("""item"":{")
            sb.Append("""@type"":""Product"",")
            sb.Append("""name"":""").Append(JsonEscape(name)).Append(""",")
            If Not String.IsNullOrWhiteSpace(code) Then
                sb.Append("""sku"":""").Append(JsonEscape(code)).Append(""",")
            End If
            sb.Append("""url"":""").Append(JsonEscape(url)).Append("""")

            ' Offers solo se ho un prezzo valido
            If price.HasValue AndAlso price.Value > 0D Then
                sb.Append(",")
                sb.Append("""offers"":{")
                sb.Append("""@type"":""Offer"",")
                sb.Append("""url"":""").Append(JsonEscape(url)).Append(""",")
                sb.Append("""priceCurrency"":""EUR"",")
                sb.Append("""price"":""").Append(price.Value.ToString("0.00", CultureInfo.InvariantCulture)).Append("""")
                sb.Append("}")
            End If

            sb.Append("}") ' item
            sb.Append("}") ' listitem
        Next

        sb.Append("]")
        sb.Append("}")
        Return sb.ToString()
    End Function

    ' =========================
    ' Data extraction helpers
    ' =========================
    Private Shared Function TrySelectDataView(ByVal page As Page, ByVal id As String) As DataView
        If page Is Nothing OrElse String.IsNullOrWhiteSpace(id) Then Return Nothing

        Dim c As Control = FindControlDeep(page, id)

        ' 1) Diretto: SqlDataSource
        Dim sds As SqlDataSource = TryCast(c, SqlDataSource)
        If sds IsNot Nothing Then
            Return SelectToDataView(sds)
        End If

        ' 2) Se è un controllo databound, provo a risalire al DataSourceID
        Dim dbc As IDataBoundControl = TryCast(c, IDataBoundControl)
        If dbc IsNot Nothing Then
            Dim dsId As String = dbc.DataSourceID
            If Not String.IsNullOrWhiteSpace(dsId) Then
                Dim c2 As Control = FindControlDeep(page, dsId)
                Dim sds2 As SqlDataSource = TryCast(c2, SqlDataSource)
                If sds2 IsNot Nothing Then
                    Return SelectToDataView(sds2)
                End If
            End If
        End If

        Return Nothing
    End Function

    Private Shared Function SelectToDataView(ByVal sds As SqlDataSource) As DataView
        Try
            Dim result As IEnumerable = sds.Select(DataSourceSelectArguments.Empty)
            Dim dv As DataView = TryCast(result, DataView)
            If dv IsNot Nothing Then Return dv

            Dim dt As DataTable = TryCast(result, DataTable)
            If dt IsNot Nothing Then Return dt.DefaultView
        Catch
            ' Degrado silenzioso: niente eccezioni in pagina
        End Try

        Return Nothing
    End Function

    Private Shared Function FindControlDeep(ByVal page As Page, ByVal id As String) As Control
        If page Is Nothing OrElse String.IsNullOrWhiteSpace(id) Then Return Nothing

        Dim c As Control = page.FindControl(id)
        If c IsNot Nothing Then Return c

        If page.Master IsNot Nothing Then
            c = page.Master.FindControl(id)
            If c IsNot Nothing Then Return c
        End If

        ' Ricerca ricorsiva nell'albero controlli
        Return FindControlRecursive(page, id)
    End Function

    Private Shared Function FindControlRecursive(ByVal root As Control, ByVal id As String) As Control
        If root Is Nothing Then Return Nothing
        For Each child As Control In root.Controls
            If child IsNot Nothing AndAlso String.Equals(child.ID, id, StringComparison.Ordinal) Then
                Return child
            End If
            Dim found As Control = FindControlRecursive(child, id)
            If found IsNot Nothing Then Return found
        Next
        Return Nothing
    End Function

    Private Shared Function FirstExisting(ByVal r As DataRowView, ParamArray names() As String) As String
        If r Is Nothing OrElse r.DataView Is Nothing OrElse r.DataView.Table Is Nothing Then Return String.Empty
        Dim t As DataTable = r.DataView.Table

        For Each n As String In names
            If Not String.IsNullOrWhiteSpace(n) AndAlso t.Columns.Contains(n) Then
                Dim o As Object = r(n)
                If o IsNot Nothing AndAlso o IsNot DBNull.Value Then
                    Return Convert.ToString(o)
                End If
            End If
        Next

        Return String.Empty
    End Function

    Private Shared Function FirstDecimal(ByVal r As DataRowView, ParamArray names() As String) As Nullable(Of Decimal)
        Dim s As String = FirstExisting(r, names)
        If String.IsNullOrWhiteSpace(s) Then Return Nothing

        Dim d As Decimal
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), d) Then Return d

        Return Nothing
    End Function

    Private Shared Function ToBool(ByVal s As String) As Boolean
        If String.IsNullOrWhiteSpace(s) Then Return False
        Dim v As String = s.Trim()

        If String.Equals(v, "1", StringComparison.OrdinalIgnoreCase) Then Return True
        If String.Equals(v, "true", StringComparison.OrdinalIgnoreCase) Then Return True
        If String.Equals(v, "si", StringComparison.OrdinalIgnoreCase) Then Return True
        If String.Equals(v, "sì", StringComparison.OrdinalIgnoreCase) Then Return True
        If String.Equals(v, "yes", StringComparison.OrdinalIgnoreCase) Then Return True

        Return False
    End Function

    Private Shared Function SafeString(ByVal s As String) As String
        If s Is Nothing Then Return String.Empty
        Return s.Trim()
    End Function

    ' =========================
    ' JSON escape (CORRETTO VB)
    ' =========================
    Public Shared Function JsonEscape(ByVal value As String) As String
        If value Is Nothing Then Return String.Empty

        Dim sb As New StringBuilder(value.Length + 16)

        For Each ch As Char In value
            Select Case ch
                Case """"c
                    ' \"  -> backslash + quote
                    sb.Append("\")
                    sb.Append(""""c)

                Case "\"c
                    ' \\  -> due backslash
                    sb.Append("\\")

                Case ControlChars.Back
                    sb.Append("\b")

                Case ControlChars.FormFeed
                    sb.Append("\f")

                Case ControlChars.Lf
                    sb.Append("\n")

                Case ControlChars.Cr
                    sb.Append("\r")

                Case ControlChars.Tab
                    sb.Append("\t")

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

End Class
