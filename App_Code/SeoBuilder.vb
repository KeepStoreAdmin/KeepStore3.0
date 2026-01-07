Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.UI.HtmlControls
Imports MySql.Data.MySqlClient

' ==========================================================
' SeoBuilder.vb
' - NON dichiara l'interfaccia ISeoMaster (sta nel file ISeoMaster.vb)
' - Fix stringhe VB (niente \"), fix canonical (HtmlLink non ha .Rel), fix JsonEscape (Char)
' - JSON-LD Home "avanzato": Organization + WebSite + WebPage + Breadcrumb
'   + tentativo di categorie/prodotti reali da vsuperarticoli (fail-safe)
' ==========================================================
Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' ----------------------------
    ' API pubblica (usata da Default.aspx.vb)
    ' ----------------------------
    Public Shared Function BuildHomeJsonLd(ByVal page As Page,
                                           ByVal titleText As String,
                                           ByVal descriptionText As String,
                                           ByVal canonicalUrl As String,
                                           ByVal ogImageUrl As String) As String

        Dim baseUrl As String = ""
        Try
            If page IsNot Nothing AndAlso page.Request IsNot Nothing AndAlso page.Request.Url IsNot Nothing Then
                baseUrl = page.Request.Url.GetLeftPart(UriPartial.Authority)
            End If
        Catch
        End Try

        If String.IsNullOrWhiteSpace(canonicalUrl) Then
            canonicalUrl = CombineUrl(baseUrl, "/")
        End If

        Dim siteName As String = ExtractSiteName(titleText)
        Dim descr As String = If(descriptionText, "").Trim()

        Dim categories As List(Of CatItem) = TryGetCategoriesFromVsuperarticoli()
        Dim products As List(Of ProdItem) = TryGetProductsFromVsuperarticoli()

        Dim sb As New StringBuilder(4096)

        sb.Append("{")
        sb.Append("""@context"":""https://schema.org"",")
        sb.Append("""@graph"":[")

        ' Organization
        sb.Append("{")
        sb.Append("""@type"":""Organization"",")
        sb.Append("""@id"":""" & JsonEscape(CombineUrl(baseUrl, "/#organization")) & """,")
        sb.Append("""name"":""" & JsonEscape(siteName) & """,")
        sb.Append("""url"":""" & JsonEscape(baseUrl) & """")

        Dim logoAbs As String = NormalizeAbsoluteUrl(baseUrl, ogImageUrl)
        If Not String.IsNullOrWhiteSpace(logoAbs) Then
            sb.Append(",""logo"":{")
            sb.Append("""@type"":""ImageObject"",")
            sb.Append("""url"":""" & JsonEscape(logoAbs) & """")
            sb.Append("}")
        End If
        sb.Append("},")

        ' WebSite + SearchAction
        sb.Append("{")
        sb.Append("""@type"":""WebSite"",")
        sb.Append("""@id"":""" & JsonEscape(CombineUrl(baseUrl, "/#website")) & """,")
        sb.Append("""url"":""" & JsonEscape(baseUrl) & """,")
        sb.Append("""name"":""" & JsonEscape(siteName) & """,")
        sb.Append("""publisher"":{""@id"":""" & JsonEscape(CombineUrl(baseUrl, "/#organization")) & """},")
        sb.Append("""potentialAction"":{")
        sb.Append("""@type"":""SearchAction"",")
        sb.Append("""target"":""" & JsonEscape(CombineUrl(baseUrl, "/articoli.aspx?q={search_term_string}")) & """,")
        sb.Append("""query-input"":""required name=search_term_string""")
        sb.Append("}")
        sb.Append("},")

        ' WebPage (Home)
        sb.Append("{")
        sb.Append("""@type"":""WebPage"",")
        sb.Append("""@id"":""" & JsonEscape(canonicalUrl & "#webpage") & """,")
        sb.Append("""url"":""" & JsonEscape(canonicalUrl) & """,")
        sb.Append("""name"":""" & JsonEscape(If(titleText, siteName)) & """,")
        sb.Append("""description"":""" & JsonEscape(descr) & """,")
        sb.Append("""isPartOf"":{""@id"":""" & JsonEscape(CombineUrl(baseUrl, "/#website")) & """}")
        sb.Append("},")

        ' BreadcrumbList (Home)
        sb.Append("{")
        sb.Append("""@type"":""BreadcrumbList"",")
        sb.Append("""@id"":""" & JsonEscape(canonicalUrl & "#breadcrumb") & """,")
        sb.Append("""itemListElement"":[")
        sb.Append("{")
        sb.Append("""@type"":""ListItem"",")
        sb.Append("""position"":1,")
        sb.Append("""name"":""Home"",")
        sb.Append("""item"":""" & JsonEscape(canonicalUrl) & """")
        sb.Append("}")
        sb.Append("]")
        sb.Append("}")

        ' ItemList categorie (se disponibili)
        If categories IsNot Nothing AndAlso categories.Count > 0 Then
            sb.Append(",{")
            sb.Append("""@type"":""ItemList"",")
            sb.Append("""@id"":""" & JsonEscape(canonicalUrl & "#categories") & """,")
            sb.Append("""name"":""Categorie"",")
            sb.Append("""itemListElement"":[")
            For i As Integer = 0 To categories.Count - 1
                If i > 0 Then sb.Append(",")
                Dim c As CatItem = categories(i)
                Dim url As String = CombineUrl(baseUrl, "/articoli.aspx?ct=" & c.Id.ToString(CultureInfo.InvariantCulture))
                sb.Append("{")
                sb.Append("""@type"":""ListItem"",")
                sb.Append("""position"":" & (i + 1).ToString(CultureInfo.InvariantCulture) & ",")
                sb.Append("""name"":""" & JsonEscape(c.Name) & """,")
                sb.Append("""item"":""" & JsonEscape(url) & """")
                sb.Append("}")
            Next
            sb.Append("]")
            sb.Append("}")
        End If

        ' ItemList prodotti (se disponibili)
        If products IsNot Nothing AndAlso products.Count > 0 Then
            sb.Append(",{")
            sb.Append("""@type"":""ItemList"",")
            sb.Append("""@id"":""" & JsonEscape(canonicalUrl & "#products") & """,")
            sb.Append("""name"":""Prodotti in evidenza"",")
            sb.Append("""itemListElement"":[")
            For i As Integer = 0 To products.Count - 1
                If i > 0 Then sb.Append(",")
                Dim p As ProdItem = products(i)
                Dim pUrl As String = CombineUrl(baseUrl, "/articolo.aspx?id=" & p.Id.ToString(CultureInfo.InvariantCulture))

                sb.Append("{")
                sb.Append("""@type"":""ListItem"",")
                sb.Append("""position"":" & (i + 1).ToString(CultureInfo.InvariantCulture) & ",")
                sb.Append("""item"":{")
                sb.Append("""@type"":""Product"",")
                sb.Append("""@id"":""" & JsonEscape(pUrl) & """,")
                sb.Append("""name"":""" & JsonEscape(p.Name) & """,")
                sb.Append("""url"":""" & JsonEscape(pUrl) & """")

                If Not String.IsNullOrWhiteSpace(p.Sku) Then
                    sb.Append(",""sku"":""" & JsonEscape(p.Sku) & """")
                End If

                If Not String.IsNullOrWhiteSpace(p.Gtin13) Then
                    sb.Append(",""gtin13"":""" & JsonEscape(p.Gtin13) & """")
                End If

                If Not String.IsNullOrWhiteSpace(p.Brand) Then
                    sb.Append(",""brand"":{""@type"":""Brand"",""name"":""" & JsonEscape(p.Brand) & """}")
                End If

                If Not String.IsNullOrWhiteSpace(p.ImageUrl) Then
                    sb.Append(",""image"":""" & JsonEscape(NormalizeAbsoluteUrl(baseUrl, p.ImageUrl)) & """")
                End If

                If p.Price.HasValue Then
                    sb.Append(",""offers"":{")
                    sb.Append("""@type"":""Offer"",")
                    sb.Append("""priceCurrency"":""EUR"",")
                    sb.Append("""price"":""" & p.Price.Value.ToString("0.##", CultureInfo.InvariantCulture) & """,")
                    sb.Append("""availability"":""https://schema.org/InStock""")
                    sb.Append("}")
                End If

                sb.Append("}") ' item(Product)
                sb.Append("}") ' ListItem
            Next
            sb.Append("]")
            sb.Append("}")
        End If

        sb.Append("]") ' @graph
        sb.Append("}") ' root

        Return sb.ToString()
    End Function

    Public Shared Sub SetJsonLdOnMaster(ByVal page As Page, ByVal jsonLdOrScript As String)
        If page Is Nothing Then Exit Sub

        Dim s As String = If(jsonLdOrScript, "").Trim()
        If String.IsNullOrWhiteSpace(s) Then Exit Sub

        Dim payload As String = s
        If s.IndexOf("<script", StringComparison.OrdinalIgnoreCase) < 0 Then
            payload = "<script type=""application/ld+json"">" & s & "</script>"
        End If

        ' 1) Se la Master implementa ISeoMaster, usa il contratto
        Try
            Dim m As ISeoMaster = TryCast(page.Master, ISeoMaster)
            If m IsNot Nothing Then
                m.SeoJsonLd = payload
                Exit Sub
            End If
        Catch
        End Try

        ' 2) Altrimenti cerca un Literal "litSeoJsonLd" e scrivilo lì
        Dim lit As Literal = Nothing
        Try
            Dim c As Control = FindControlRecursive(page, "litSeoJsonLd")
            lit = TryCast(c, Literal)
        Catch
        End Try

        If lit IsNot Nothing Then
            lit.Text = payload
            Exit Sub
        End If

        ' 3) Fallback: inietta in <head>
        Try
            If page.Header IsNot Nothing Then
                page.Header.Controls.Add(New LiteralControl(payload))
            End If
        Catch
        End Try
    End Sub

    ' ----------------------------
    ' Query reali (fail-safe) da vsuperarticoli
    ' ----------------------------
    Private Shared Function TryGetCategoriesFromVsuperarticoli() As List(Of CatItem)
        Dim outList As New List(Of CatItem)()

        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If String.IsNullOrWhiteSpace(cs) Then Return outList

            Using conn As New MySqlConnection(cs)
                conn.Open()

                Dim sql As String =
                    "SELECT DISTINCT CategorieId AS Id, CategorieDescrizione AS Nome " &
                    "FROM vsuperarticoli " &
                    "WHERE CategorieId IS NOT NULL AND CategorieId <> 0 " &
                    "AND CategorieDescrizione IS NOT NULL AND CategorieDescrizione <> '' " &
                    "ORDER BY Nome ASC LIMIT 12"

                Using cmd As New MySqlCommand(sql, conn)
                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            Dim id As Integer = 0
                            If Not r.IsDBNull(0) Then Integer.TryParse(r(0).ToString(), id)
                            Dim nome As String = If(r.IsDBNull(1), "", Convert.ToString(r(1)))
                            nome = nome.Trim()

                            If id > 0 AndAlso nome <> "" Then
                                outList.Add(New CatItem With {.Id = id, .Name = nome})
                            End If
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' Fail-safe
        End Try

        Return outList
    End Function

    Private Shared Function TryGetProductsFromVsuperarticoli() As List(Of ProdItem)
        Dim outList As New List(Of ProdItem)()

        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If String.IsNullOrWhiteSpace(cs) Then Return outList

            Using conn As New MySqlConnection(cs)
                conn.Open()

                ' Nota: COALESCE/NULLIF riducono il rischio di colonne vuote
                Dim sql As String =
                    "SELECT id, " &
                    "COALESCE(NULLIF(DescrizioneLunga,''), NULLIF(DescrizioneBreve,''), NULLIF(Descrizione1,''), NULLIF(Descrizione,''), NULLIF(Codice,'')) AS Nome, " &
                    "NULLIF(Codice,'') AS Sku, " &
                    "NULLIF(Ean,'') AS Ean, " &
                    "NULLIF(MarcheDescrizione,'') AS Brand, " &
                    "PrezzoIvato AS Prezzo, " &
                    "NULLIF(img1,'') AS Img " &
                    "FROM vsuperarticoli " &
                    "WHERE id IS NOT NULL AND id <> 0 " &
                    "ORDER BY id DESC LIMIT 8"

                Using cmd As New MySqlCommand(sql, conn)
                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            Dim id As Integer = 0
                            If Not r.IsDBNull(0) Then Integer.TryParse(r(0).ToString(), id)
                            If id <= 0 Then Continue While

                            Dim nome As String = If(r.IsDBNull(1), "", Convert.ToString(r(1))).Trim()
                            If nome = "" Then nome = "Prodotto " & id.ToString(CultureInfo.InvariantCulture)

                            Dim sku As String = If(r.IsDBNull(2), "", Convert.ToString(r(2))).Trim()
                            Dim ean As String = If(r.IsDBNull(3), "", Convert.ToString(r(3))).Trim()
                            Dim brand As String = If(r.IsDBNull(4), "", Convert.ToString(r(4))).Trim()

                            Dim priceVal As Nullable(Of Decimal) = Nothing
                            If Not r.IsDBNull(5) Then
                                Dim tmp As Decimal
                                If Decimal.TryParse(r(5).ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, tmp) Then
                                    priceVal = tmp
                                ElseIf Decimal.TryParse(r(5).ToString(), NumberStyles.Any, CultureInfo.CurrentCulture, tmp) Then
                                    priceVal = tmp
                                End If
                            End If

                            Dim img As String = If(r.IsDBNull(6), "", Convert.ToString(r(6))).Trim()

                            outList.Add(New ProdItem With {
                                .Id = id,
                                .Name = nome,
                                .Sku = sku,
                                .Gtin13 = ean,
                                .Brand = brand,
                                .Price = priceVal,
                                .ImageUrl = img
                            })
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' Se la query "ricca" fallisce per colonne non presenti, degradazione controllata:
            Try
                Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                Using conn As New MySqlConnection(cs)
                    conn.Open()
                    Dim sql2 As String = "SELECT id, NULLIF(Codice,'') AS Nome FROM vsuperarticoli WHERE id IS NOT NULL AND id<>0 ORDER BY id DESC LIMIT 8"
                    Using cmd2 As New MySqlCommand(sql2, conn)
                        Using r2 As MySqlDataReader = cmd2.ExecuteReader()
                            While r2.Read()
                                Dim id As Integer = 0
                                If Not r2.IsDBNull(0) Then Integer.TryParse(r2(0).ToString(), id)
                                If id <= 0 Then Continue While
                                Dim nome As String = If(r2.IsDBNull(1), "", Convert.ToString(r2(1))).Trim()
                                If nome = "" Then nome = "Prodotto " & id.ToString(CultureInfo.InvariantCulture)
                                outList.Add(New ProdItem With {.Id = id, .Name = nome})
                            End While
                        End Using
                    End Using
                End Using
            Catch
            End Try
        End Try

        Return outList
    End Function

    ' ----------------------------
    ' Helpers
    ' ----------------------------
    Private Shared Function ExtractSiteName(ByVal titleText As String) As String
        Dim t As String = If(titleText, "").Trim()
        If t = "" Then Return "TAIKUN.IT"

        ' Se c'è un separatore tipico, prendi la parte a sinistra (nome brand)
        Dim p As Integer = t.IndexOf("|"c)
        If p > 0 Then Return t.Substring(0, p).Trim()

        p = t.IndexOf("-"c)
        If p > 0 Then Return t.Substring(0, p).Trim()

        Return t
    End Function

    Private Shared Function CombineUrl(ByVal baseUrl As String, ByVal path As String) As String
        If String.IsNullOrWhiteSpace(baseUrl) Then Return If(path, "")
        Dim b As String = baseUrl.TrimEnd("/"c)
        Dim p As String = If(path, "/").Trim()
        If Not p.StartsWith("/", StringComparison.OrdinalIgnoreCase) Then p = "/" & p
        Return b & p
    End Function

    Private Shared Function NormalizeAbsoluteUrl(ByVal baseUrl As String, ByVal urlOrPath As String) As String
        Dim s As String = If(urlOrPath, "").Trim()
        If s = "" Then Return ""

        If s.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse s.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return s
        End If

        If s.StartsWith("~/", StringComparison.OrdinalIgnoreCase) Then
            s = s.Substring(1) ' -> "/..."
        End If

        If s.StartsWith("/", StringComparison.OrdinalIgnoreCase) Then
            Return CombineUrl(baseUrl, s)
        End If

        Return CombineUrl(baseUrl, "/" & s)
    End Function

    Public Shared Function JsonEscape(ByVal value As String) As String
        If value Is Nothing Then Return ""

        Dim sb As New StringBuilder(value.Length + 32)

        For Each ch As Char In value
            Dim code As Integer = AscW(ch)

            Select Case code
                Case 34 ' "
                    sb.Append("\""")
                Case 92 ' \
                    sb.Append("\\")
                Case 8 ' backspace
                    sb.Append("\b")
                Case 12 ' formfeed
                    sb.Append("\f")
                Case 10 ' lf
                    sb.Append("\n")
                Case 13 ' cr
                    sb.Append("\r")
                Case 9 ' tab
                    sb.Append("\t")
                Case Else
                    ' Controlli e separatori unicode "problematici"
                    If code < 32 OrElse code = 8232 OrElse code = 8233 Then
                        sb.Append("\u")
                        sb.Append(code.ToString("x4"))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function

    Private Shared Function FindControlRecursive(ByVal root As Control, ByVal id As String) As Control
        If root Is Nothing OrElse String.IsNullOrEmpty(id) Then Return Nothing

        Dim c As Control = root.FindControl(id)
        If c IsNot Nothing Then Return c

        For Each child As Control In root.Controls
            Dim found As Control = FindControlRecursive(child, id)
            If found IsNot Nothing Then Return found
        Next

        Return Nothing
    End Function

    ' DTO interni
    Private Class CatItem
        Public Property Id As Integer
        Public Property Name As String
    End Class

    Private Class ProdItem
        Public Property Id As Integer
        Public Property Name As String
        Public Property Sku As String
        Public Property Gtin13 As String
        Public Property Brand As String
        Public Property Price As Nullable(Of Decimal)
        Public Property ImageUrl As String
    End Class

End Class
