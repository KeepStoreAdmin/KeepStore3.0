Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Data.Common
Imports System.Globalization
Imports System.Linq
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.UI

Partial Public Class home_runtime_feed
    Inherits Page

    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.Clear()
        Response.Charset = "utf-8"
        Response.ContentType = "application/json"
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()

        Dim payload As New Dictionary(Of String, Object)()

        Try
            Dim mode As String = Convert.ToString(Request("mode")).Trim().ToLowerInvariant()
            If String.IsNullOrWhiteSpace(mode) Then mode = "all"

            payload("ok") = True
            Select Case mode
                Case "menu"
                    payload("menu") = BuildMenuPayload()
                Case "languages"
                    payload("languages") = BuildLanguages()
                Case "banners"
                    payload("banners") = LoadBannerPayload()
                Case "deals"
                    payload("deals") = LoadDeals(ReadInt(Request("limit"), 8))
                Case "sections"
                    payload("sections") = BuildSectionsPayload()
                Case "products"
                    payload("products") = LoadProductsByIds(ParseIds(Request("ids")))
                Case Else
                    payload("menu") = BuildMenuPayload()
                    payload("languages") = BuildLanguages()
                    payload("banners") = LoadBannerPayload()
                    payload("deals") = LoadDeals(8)
                    payload("sections") = BuildSectionsPayload()
            End Select
        Catch ex As Exception
            payload.Clear()
            payload("ok") = False
            payload("error") = ex.Message
        End Try

        Dim serializer As New JavaScriptSerializer()
        serializer.MaxJsonLength = Integer.MaxValue
        Response.Write(serializer.Serialize(payload))
        Response.End()
    End Sub

    Private Function BuildMenuPayload() As List(Of Dictionary(Of String, Object))
        Dim sectors As DataTable = ExecuteQuery("SELECT id, Descrizione, Img, Ordinamento, Predefinito FROM settori WHERE COALESCE(Abilitato,0)=1 ORDER BY COALESCE(Predefinito,0) DESC, COALESCE(Ordinamento,999999) ASC, Descrizione ASC")
        Dim categories As DataTable = ExecuteQuery("SELECT id, SettoriId, Descrizione, Ordinamento FROM categorie WHERE COALESCE(Abilitato,1)=1 ORDER BY SettoriId ASC, Ordinamento ASC, Descrizione ASC")
        Dim tipologies As DataTable = ExecuteQuery("SELECT id, CategorieId, Descrizione, Ordinamento FROM tipologie WHERE COALESCE(Abilitato,1)=1 ORDER BY CategorieId ASC, Ordinamento ASC, Descrizione ASC")

        Dim categoryBySector = categories.AsEnumerable().GroupBy(Function(r) ReadInt(r("SettoriId"), 0)).ToDictionary(Function(g) g.Key, Function(g) g.ToList())
        Dim tipsByCategory = tipologies.AsEnumerable().GroupBy(Function(r) ReadInt(r("CategorieId"), 0)).ToDictionary(Function(g) g.Key, Function(g) g.ToList())
        Dim outList As New List(Of Dictionary(Of String, Object))()

        For Each row As DataRow In sectors.Rows
            Dim sectorId As Integer = ReadInt(row("id"), 0)
            Dim entry As New Dictionary(Of String, Object)()
            entry("id") = sectorId
            entry("title") = CleanText(row("Descrizione"))
            entry("url") = "articoli.aspx?st=" & sectorId.ToString(CultureInfo.InvariantCulture)
            entry("image") = NormalizeSectorImage(row("Img"))
            Dim categoryList As New List(Of Dictionary(Of String, Object))()
            Dim catRows As List(Of DataRow) = Nothing
            If categoryBySector.TryGetValue(sectorId, catRows) Then
                For Each cat As DataRow In catRows.Take(12)
                    Dim catId As Integer = ReadInt(cat("id"), 0)
                    Dim catEntry As New Dictionary(Of String, Object)()
                    catEntry("id") = catId
                    catEntry("title") = CleanText(cat("Descrizione"))
                    catEntry("url") = "articoli.aspx?st=" & sectorId.ToString(CultureInfo.InvariantCulture) & "&ct=" & catId.ToString(CultureInfo.InvariantCulture)
                    Dim tipList As New List(Of Dictionary(Of String, Object))()
                    Dim tipRows As List(Of DataRow) = Nothing
                    If tipsByCategory.TryGetValue(catId, tipRows) Then
                        For Each tip As DataRow In tipRows.Take(14)
                            Dim tipId As Integer = ReadInt(tip("id"), 0)
                            tipList.Add(New Dictionary(Of String, Object) From {
                                {"id", tipId},
                                {"title", CleanText(tip("Descrizione"))},
                                {"url", "articoli.aspx?st=" & sectorId.ToString(CultureInfo.InvariantCulture) & "&ct=" & catId.ToString(CultureInfo.InvariantCulture) & "&tp=" & tipId.ToString(CultureInfo.InvariantCulture)}
                            })
                        Next
                    End If
                    catEntry("tipologies") = tipList
                    categoryList.Add(catEntry)
                Next
            End If
            entry("categories") = categoryList
            outList.Add(entry)
        Next

        Return outList
    End Function

    Private Function BuildLanguages() As List(Of Dictionary(Of String, Object))
        Dim activeCode As String = Convert.ToString(Request("lang"))
        If String.IsNullOrWhiteSpace(activeCode) Then activeCode = Convert.ToString(Session("Lingua"))
        If String.IsNullOrWhiteSpace(activeCode) Then activeCode = "it"
        activeCode = activeCode.Trim().ToLowerInvariant()

        Return New List(Of Dictionary(Of String, Object)) From {
            New Dictionary(Of String, Object) From {{"code", "it"}, {"title", "Italiano"}, {"active", activeCode.StartsWith("it")}},
            New Dictionary(Of String, Object) From {{"code", "en"}, {"title", "English"}, {"active", activeCode.StartsWith("en")}}
        }
    End Function

    Private Function LoadBannerPayload() As List(Of Dictionary(Of String, Object))
        Dim result As New List(Of Dictionary(Of String, Object))()
        Dim table As DataTable = Nothing
        Dim queries As String() = {
            "SELECT ID, Posizione, Ordinamento, Descrizione, Immagine, Link, Target, 'banner' AS SourceKind FROM bannerv2 WHERE COALESCE(Immagine,'')<>'' ORDER BY Posizione ASC, Ordinamento ASC LIMIT 30",
            "SELECT ID, Posizione, Ordinamento, Descrizione, Immagine, Link, Target, 'banner' AS SourceKind FROM banner WHERE COALESCE(Immagine,'')<>'' ORDER BY Posizione ASC, Ordinamento ASC LIMIT 30",
            "SELECT id AS ID, 0 AS Posizione, id AS Ordinamento, caption AS Descrizione, image AS Immagine, link AS Link, '' AS Target, 'slideshow' AS SourceKind FROM slideshow_new WHERE COALESCE(image,'')<>'' ORDER BY id DESC LIMIT 20"
        }

        For Each sql As String In queries
            Try
                table = ExecuteQuery(sql)
            Catch
                table = Nothing
            End Try
            If table IsNot Nothing AndAlso table.Rows.Count > 0 Then Exit For
        Next

        If table Is Nothing Then Return result

        For Each row As DataRow In table.Rows
            Dim image As String = If(String.Equals(SafeString(row("SourceKind")), "slideshow", StringComparison.OrdinalIgnoreCase),
                                     NormalizeSlideshowImage(row("Immagine")),
                                     NormalizeBannerImage(row("Immagine")))
            If String.IsNullOrWhiteSpace(image) Then Continue For
            result.Add(New Dictionary(Of String, Object) From {
                {"id", ReadInt(row("ID"), 0)},
                {"position", SafeString(row("Posizione"))},
                {"title", CleanText(row("Descrizione"))},
                {"image", image},
                {"url", SafeUrl(row("Link"), String.Empty)},
                {"target", SafeString(row("Target"))}
            })
        Next

        Return result
    End Function

    Private Function BuildSectionsPayload() As Dictionary(Of String, Object)
        Dim payload As New Dictionary(Of String, Object)()
        Dim recentIds As List(Of Integer) = ParseIds(Request("recent"))

        Dim offerte As List(Of Dictionary(Of String, Object)) = LoadProductCards("WHERE v.NListino = 1 AND COALESCE(v.InOfferta,0)<>0 AND COALESCE(v.Disponibilita,0) > 0", "ORDER BY RAND()", 160)
        Dim evidenza As List(Of Dictionary(Of String, Object)) = LoadProductCards("WHERE v.NListino = 1 AND COALESCE(v.Vetrina,0)<>0 AND COALESCE(v.Disponibilita,0) > 0", "ORDER BY RAND()", 160)
        Dim nuovi As List(Of Dictionary(Of String, Object)) = LoadProductCards("WHERE v.NListino = 1 AND v.DataCreazione IS NOT NULL AND COALESCE(v.Disponibilita,0) > 0", "ORDER BY v.DataCreazione DESC, RAND()", 160)
        Dim best As List(Of Dictionary(Of String, Object)) = LoadProductCards("WHERE v.NListino = 1 AND COALESCE(v.Disponibilita,0) > 0", "ORDER BY COALESCE(v.visite,0) DESC, RAND()", 160)
        Dim top20 As List(Of Dictionary(Of String, Object)) = LoadProductCards("WHERE v.NListino = 1 AND COALESCE(v.Disponibilita,0) > 0", "ORDER BY COALESCE(v.visite,0) DESC, RAND()", 160)
        Dim topselling As List(Of Dictionary(Of String, Object)) = LoadTopSellingCards(160)
        Dim recent As List(Of Dictionary(Of String, Object)) = If(recentIds IsNot Nothing AndAlso recentIds.Count > 0, LoadProductsByIds(recentIds.Take(32).ToList()), LoadProductCards("WHERE v.NListino = 1 AND COALESCE(v.Disponibilita,0) > 0", "ORDER BY COALESCE(v.visite,0) DESC, RAND()", 40))
        Dim combined As List(Of Dictionary(Of String, Object)) = MergeCardLists(offerte, evidenza, nuovi, best, top20, topselling, recent)

        payload("offerte") = offerte
        payload("evidenza") = evidenza
        payload("nuovi") = nuovi
        payload("best") = best
        payload("top20") = top20
        payload("topselling") = topselling
        payload("recent") = recent
        Dim deals As List(Of Dictionary(Of String, Object)) = LoadDeals(16)
        payload("deals") = deals
        payload("viewed") = MergeCardLists(recent, top20, best, topselling)
        payload("combined") = MergeCardLists(combined, deals)
        Return payload
    End Function

    Private Function LoadDeals(ByVal limit As Integer) As List(Of Dictionary(Of String, Object))
        Return LoadProductCards("WHERE v.NListino = 1 AND COALESCE(v.InOfferta,0)<>0 AND COALESCE(NULLIF(v.PrezzoPromoIvato,0),0)>0 AND COALESCE(v.Disponibilita,0) > 0", "ORDER BY RAND()", Math.Max(4, limit))
    End Function

    Private Function LoadProductsByIds(ByVal ids As List(Of Integer)) As List(Of Dictionary(Of String, Object))
        If ids Is Nothing OrElse ids.Count = 0 Then Return New List(Of Dictionary(Of String, Object))()
        Dim whereClause As String = "WHERE v.NListino = 1 AND COALESCE(v.Disponibilita,0) > 0 AND v.id IN (" & String.Join(",", ids.Select(Function(n) n.ToString(CultureInfo.InvariantCulture))) & ")"
        Dim cards As List(Of Dictionary(Of String, Object)) = LoadProductCards(whereClause, "ORDER BY FIELD(v.id," & String.Join(",", ids.Select(Function(n) n.ToString(CultureInfo.InvariantCulture))) & ")", ids.Count)
        Return cards
    End Function

    Private Function LoadProductCards(ByVal whereClause As String, ByVal orderClause As String, ByVal limit As Integer) As List(Of Dictionary(Of String, Object))
        Dim sql As New StringBuilder()
        sql.Append("SELECT DISTINCT v.id, v.Codice, v.Ean, v.Descrizione1, v.DescrizioneLunga, v.MarcheDescrizione, v.CategorieDescrizione, v.SettoriDescrizione, ")
        sql.Append("v.Img1, v.Img2, v.Img3, v.Img4, i.Immagine1, i.Immagine2, i.Immagine3, i.Immagine4, i.Immagine5, i.Immagine6, ")
        sql.Append("v.Prezzo, v.PrezzoIvato, v.PrezzoPromo, v.PrezzoPromoIvato, COALESCE(v.InOfferta,0) AS InOfferta, COALESCE(v.Vetrina,0) AS Vetrina, COALESCE(v.visite,0) AS Visite, ")
        sql.Append("COALESCE(v.Disponibilita,0) AS Disponibilita, COALESCE(v.Giacenza,0) AS Giacenza, v.OfferteDataFine, v.DataCreazione ")
        sql.Append("FROM vsuperarticoli v LEFT JOIN immagini i ON i.id = v.id ")
        sql.Append(whereClause)
        sql.Append(" ")
        sql.Append(orderClause)
        sql.Append(" LIMIT ")
        sql.Append(Math.Max(1, limit).ToString(CultureInfo.InvariantCulture))

        Dim table As DataTable = ExecuteQuery(sql.ToString())
        Dim output As New List(Of Dictionary(Of String, Object))()
        Dim seen As New HashSet(Of Integer)()
        For Each row As DataRow In table.Rows
            Dim item As Dictionary(Of String, Object) = MapProductRow(row)
            If item Is Nothing Then Continue For
            Dim id As Integer = ReadInt(item("id"), 0)
            If id <= 0 OrElse seen.Contains(id) Then Continue For
            seen.Add(id)
            output.Add(item)
        Next
        Return output
    End Function

    Private Function MapProductRow(ByVal row As DataRow) As Dictionary(Of String, Object)
        Dim id As Integer = ReadInt(row("id"), 0)
        Dim imgs As List(Of String) = CollectImages(row)
        Dim priceCurrent As Decimal = ReadDec(If(ReadDec(row("PrezzoPromoIvato"), 0D) > 0D, row("PrezzoPromoIvato"), row("PrezzoIvato")), 0D)
        If priceCurrent <= 0D Then priceCurrent = ReadDec(If(ReadDec(row("PrezzoPromo"), 0D) > 0D, row("PrezzoPromo"), row("Prezzo")), 0D)
        Dim priceOld As Decimal = ReadDec(If(ReadDec(row("PrezzoIvato"), 0D) > 0D, row("PrezzoIvato"), row("Prezzo")), 0D)
        Dim available As Integer = Math.Max(0, ReadInt(row("Disponibilita"), ReadInt(row("Giacenza"), 0)))
        Dim sold As Integer = Math.Max(0, ReadInt(If(row.Table.Columns.Contains("SoldQty"), row("SoldQty"), 0), 0))
        Dim salePercent As Integer = 0
        If priceOld > 0D AndAlso priceCurrent > 0D AndAlso priceOld > priceCurrent Then
            salePercent = CInt(Math.Round(((priceOld - priceCurrent) / priceOld) * 100D, MidpointRounding.AwayFromZero))
        End If

        If id <= 0 Then Return Nothing
        If String.IsNullOrWhiteSpace(CleanText(row("Descrizione1"))) Then Return Nothing
        If imgs.Count = 0 Then Return Nothing
        If priceCurrent <= 0D Then Return Nothing

        Dim item As New Dictionary(Of String, Object)()
        item("id") = id
        item("url") = "articolo.aspx?id=" & id.ToString(CultureInfo.InvariantCulture)
        item("title") = CleanText(row("Descrizione1"))
        item("brand") = CleanText(row("MarcheDescrizione"))
        item("category") = CleanText(If(String.IsNullOrWhiteSpace(CleanText(row("CategorieDescrizione"))), row("SettoriDescrizione"), row("CategorieDescrizione")))
        item("price") = FormatPrice(priceCurrent)
        item("oldPrice") = If(priceOld > priceCurrent AndAlso priceOld > 0D, FormatPrice(priceOld), String.Empty)
        item("available") = available
        item("sold") = sold
        item("salePercent") = salePercent
        item("dealEnds") = FormatDateIso(row("OfferteDataFine"))
        item("images") = imgs
        item("image") = If(imgs.Count > 0, imgs(0), String.Empty)
        item("preview") = BuildPreviewVariant(If(imgs.Count > 0, imgs(0), String.Empty))
        item("isPromo") = (ReadInt(row("InOfferta"), 0) <> 0)
        item("isVetrina") = (ReadInt(row("Vetrina"), 0) <> 0)
        item("visits") = ReadInt(row("Visite"), 0)
        Return item
    End Function

    Private Function CollectImages(ByVal row As DataRow) As List(Of String)
        Dim output As New List(Of String)()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim names As String() = {"Img1", "Img2", "Img3", "Img4", "Immagine1", "Immagine2", "Immagine3", "Immagine4", "Immagine5", "Immagine6"}
        For Each name As String In names
            If Not row.Table.Columns.Contains(name) Then Continue For
            Dim url As String = NormalizeArticleImage(row(name))
            If String.IsNullOrWhiteSpace(url) Then Continue For
            If seen.Add(url) Then output.Add(url)
            If output.Count >= 5 Then Exit For
        Next
        Return output
    End Function

    Private Function BuildPreviewVariant(ByVal raw As String) As String
        Dim url As String = NormalizeArticleImage(raw)
        If String.IsNullOrWhiteSpace(url) Then Return String.Empty
        Dim q As Integer = url.IndexOf("?"c)
        Dim baseUrl As String = If(q >= 0, url.Substring(0, q), url)
        Dim suffix As String = If(q >= 0, url.Substring(q), String.Empty)
        Dim dot As Integer = baseUrl.LastIndexOf("."c)
        If dot > 0 Then
            Dim candidate As String = baseUrl.Substring(0, dot) & "_" & baseUrl.Substring(dot) & suffix
            Return candidate
        End If
        Return url
    End Function


    Private Function LoadTopSellingCards(ByVal limit As Integer) As List(Of Dictionary(Of String, Object))
        Dim sql As New StringBuilder()
        sql.Append("SELECT DISTINCT v.id, v.Codice, v.Ean, v.Descrizione1, v.DescrizioneLunga, v.MarcheDescrizione, v.CategorieDescrizione, v.SettoriDescrizione, ")
        sql.Append("v.Img1, v.Img2, v.Img3, v.Img4, i.Immagine1, i.Immagine2, i.Immagine3, i.Immagine4, i.Immagine5, i.Immagine6, ")
        sql.Append("v.Prezzo, v.PrezzoIvato, v.PrezzoPromo, v.PrezzoPromoIvato, COALESCE(v.InOfferta,0) AS InOfferta, COALESCE(v.Vetrina,0) AS Vetrina, COALESCE(v.visite,0) AS Visite, ")
        sql.Append("COALESCE(v.Disponibilita,0) AS Disponibilita, COALESCE(v.Giacenza,0) AS Giacenza, v.OfferteDataFine, v.DataCreazione, COALESCE(s.QntTot,0) AS SoldQty ")
        sql.Append("FROM vsuperarticoli v ")
        sql.Append("LEFT JOIN immagini i ON i.id = v.id ")
        sql.Append("LEFT JOIN (SELECT dr.ArticoliId AS articoli_id, SUM(IFNULL(dr.Qnt,0)) AS QntTot FROM documentirighe dr INNER JOIN documenti d ON d.id = dr.DocumentiId WHERE dr.TipoRiga = 'A' GROUP BY dr.ArticoliId) s ON s.articoli_id = v.id ")
        sql.Append("WHERE v.NListino = 1 AND COALESCE(v.Disponibilita,0) > 0 ")
        sql.Append("ORDER BY COALESCE(s.QntTot,0) DESC, COALESCE(v.visite,0) DESC, RAND() LIMIT ")
        sql.Append(Math.Max(1, limit).ToString(CultureInfo.InvariantCulture))

        Dim table As DataTable = ExecuteQuery(sql.ToString())
        Dim output As New List(Of Dictionary(Of String, Object))()
        For Each row As DataRow In table.Rows
            output.Add(MapProductRow(row))
        Next
        Return output
    End Function


    Private Function MergeCardLists(ParamArray lists() As List(Of Dictionary(Of String, Object))) As List(Of Dictionary(Of String, Object))
        Dim output As New List(Of Dictionary(Of String, Object))()
        Dim seen As New HashSet(Of Integer)()
        For Each list As List(Of Dictionary(Of String, Object)) In lists
            If list Is Nothing Then Continue For
            For Each item As Dictionary(Of String, Object) In list
                If item Is Nothing Then Continue For
                Dim id As Integer = ReadInt(item("id"), 0)
                If id <= 0 OrElse seen.Contains(id) Then Continue For
                seen.Add(id)
                output.Add(item)
            Next
        Next
        Return output
    End Function

    Private Function ParseIds(ByVal raw As String) As List(Of Integer)
        Dim result As New List(Of Integer)()
        Dim seen As New HashSet(Of Integer)()
        For Each token As String In Convert.ToString(raw).Split(","c)
            Dim value As Integer
            If Integer.TryParse(token.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, value) AndAlso value > 0 Then
                If Not seen.Contains(value) Then
                    seen.Add(value)
                    result.Add(value)
                End If
            End If
        Next
        Return result
    End Function

    Private Function NormalizeSectorImage(ByVal raw As Object) As String
        Dim value As String = SafeString(raw).Replace("\", "/")
        If String.IsNullOrWhiteSpace(value) Then Return String.Empty
        If value.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse value.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse value.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then Return value
        Dim fileName As String = IO.Path.GetFileName(value)
        If String.IsNullOrWhiteSpace(fileName) Then Return String.Empty
        Return "/Public/assets/images/settori/" & fileName
    End Function

    Private Function NormalizeBannerImage(ByVal raw As Object) As String
        Dim value As String = SafeString(raw).Replace("\", "/")
        If String.IsNullOrWhiteSpace(value) Then Return String.Empty
        If value.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse value.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse value.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then Return value
        If value.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then Return ResolveUrl(value)
        Dim fileName As String = IO.Path.GetFileName(value)
        If String.IsNullOrWhiteSpace(fileName) Then Return String.Empty
        Return ResolveUrl("~/Public/assets/images/banner/" & fileName)
    End Function

    Private Function NormalizeSlideshowImage(ByVal raw As Object) As String
        Dim value As String = SafeString(raw).Replace("\", "/")
        If String.IsNullOrWhiteSpace(value) Then Return String.Empty
        If value.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse value.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse value.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then Return value
        If value.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then Return ResolveUrl(value)
        Dim fileName As String = IO.Path.GetFileName(value)
        If String.IsNullOrWhiteSpace(fileName) Then Return String.Empty
        Return ResolveUrl("~/Public/assets/images/slideshows/" & fileName)
    End Function

    Private Function NormalizeArticleImage(ByVal raw As Object) As String
        Return ThemeManager.ProductImageUrl(raw)
    End Function

    Private Function CleanText(ByVal raw As Object) As String
        Dim text As String = HttpUtility.HtmlDecode(Convert.ToString(raw)).Trim()
        If String.IsNullOrWhiteSpace(text) Then Return String.Empty
        text = text.Replace(ChrW(160), " "c)
        text = text.Replace(ChrW(&H2013), "-"c)
        text = text.Replace(ChrW(&H2014), "-"c)
        text = Regex.Replace(text, "\s+", " ").Trim()
        text = Regex.Replace(text, "^[\-,:;\s]+|[\-,:;\s]+$", "").Trim()
        Return text
    End Function

    Private Function FormatPrice(ByVal value As Decimal) As String
        If value <= 0D Then Return String.Empty
        Return value.ToString("N2", ItCulture)
    End Function

    Private Function FormatDateIso(ByVal raw As Object) As String
        Dim dt As DateTime
        If DateTime.TryParse(Convert.ToString(raw), ItCulture, DateTimeStyles.None, dt) Then Return dt.ToString("yyyy-MM-dd")
        If DateTime.TryParse(Convert.ToString(raw), CultureInfo.InvariantCulture, DateTimeStyles.None, dt) Then Return dt.ToString("yyyy-MM-dd")
        Return String.Empty
    End Function

    Private Function SafeString(ByVal raw As Object) As String
        Return Convert.ToString(raw).Trim()
    End Function

    Private Function ReadInt(ByVal raw As Object, ByVal fallback As Integer) As Integer
        Dim n As Integer
        If Integer.TryParse(Convert.ToString(raw), NumberStyles.Integer, CultureInfo.InvariantCulture, n) Then Return n
        Return fallback
    End Function

    Private Function ReadDec(ByVal raw As Object, ByVal fallback As Decimal) As Decimal
        Dim n As Decimal
        Dim text As String = Convert.ToString(raw).Trim()
        If String.IsNullOrWhiteSpace(text) Then Return fallback
        If text.Contains(",") AndAlso (Not text.Contains(".") OrElse text.LastIndexOf(","c) > text.LastIndexOf("."c)) Then
            If Decimal.TryParse(text, NumberStyles.Any, ItCulture, n) Then Return Math.Round(n, 2, MidpointRounding.AwayFromZero)
        End If
        If Decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, n) Then Return Math.Round(n, 2, MidpointRounding.AwayFromZero)
        If Decimal.TryParse(text, NumberStyles.Any, ItCulture, n) Then Return Math.Round(n, 2, MidpointRounding.AwayFromZero)
        Return fallback
    End Function

    Private Function SafeUrl(ByVal raw As Object, ByVal fallback As String) As String
        Dim url As String = SafeString(raw)
        If String.IsNullOrWhiteSpace(url) Then url = fallback
        If String.IsNullOrWhiteSpace(url) Then Return String.Empty
        If url.StartsWith("javascript:", StringComparison.OrdinalIgnoreCase) Then url = fallback
        Return url
    End Function

    Private Function ExecuteQuery(ByVal sql As String) As DataTable
        Dim table As New DataTable()
        Dim factory As DbProviderFactory = Nothing
        Using conn As DbConnection = OpenConnection(factory)
            Using cmd As DbCommand = conn.CreateCommand()
                cmd.CommandText = sql
                cmd.CommandType = CommandType.Text
                Using reader As DbDataReader = cmd.ExecuteReader()
                    table.Load(reader)
                End Using
            End Using
        End Using
        Return table
    End Function

    Private Function OpenConnection(ByRef factory As DbProviderFactory) As DbConnection
        Dim cs As ConnectionStringSettings = PickConnectionString()
        If cs Is Nothing OrElse String.IsNullOrWhiteSpace(cs.ConnectionString) Then Throw New InvalidOperationException("Connection string non trovata.")
        factory = ResolveFactory(cs)
        If factory Is Nothing Then Throw New InvalidOperationException("Provider database non disponibile.")
        Dim conn As DbConnection = factory.CreateConnection()
        conn.ConnectionString = cs.ConnectionString
        conn.Open()
        Return conn
    End Function

    Private Function PickConnectionString() As ConnectionStringSettings
        Dim preferred As ConnectionStringSettings = Nothing
        For Each cs As ConnectionStringSettings In ConfigurationManager.ConnectionStrings
            If cs Is Nothing Then Continue For
            Dim name As String = Convert.ToString(cs.Name)
            Dim conn As String = Convert.ToString(cs.ConnectionString)
            If String.IsNullOrWhiteSpace(conn) Then Continue For
            If String.Equals(name, "LocalSqlServer", StringComparison.OrdinalIgnoreCase) Then Continue For
            Dim probe As String = conn.ToLowerInvariant()
            If probe.Contains("server=") AndAlso probe.Contains("database=") Then
                If probe.Contains("uid=") OrElse probe.Contains("user id=") OrElse probe.Contains("port=") OrElse Convert.ToString(cs.ProviderName).ToLowerInvariant().Contains("mysql") Then
                    Return cs
                End If
                If preferred Is Nothing Then preferred = cs
            End If
        Next
        Return preferred
    End Function

    Private Function ResolveFactory(ByVal cs As ConnectionStringSettings) As DbProviderFactory
        Dim provider As String = Convert.ToString(cs.ProviderName)
        If String.IsNullOrWhiteSpace(provider) Then
            Dim probe As String = Convert.ToString(cs.ConnectionString).ToLowerInvariant()
            provider = If(probe.Contains("uid=") OrElse probe.Contains("user id=") OrElse probe.Contains("port="), "MySql.Data.MySqlClient", "System.Data.SqlClient")
        End If

        Try
            Return DbProviderFactories.GetFactory(provider)
        Catch
        End Try

        If String.Equals(provider, "MySql.Data.MySqlClient", StringComparison.OrdinalIgnoreCase) Then
            Dim t As Type = Type.GetType("MySql.Data.MySqlClient.MySqlClientFactory, MySql.Data")
            If t IsNot Nothing Then
                Dim fld = t.GetField("Instance")
                If fld IsNot Nothing Then Return TryCast(fld.GetValue(Nothing), DbProviderFactory)
            End If
        End If

        Return Nothing
    End Function
End Class
