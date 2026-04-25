Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Data.Common
Imports System.Globalization
Imports System.IO
Imports System.Linq
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.Script.Serialization
Imports System.Web.UI

Partial Public Class search_suggest
    Inherits Page

    Private Const DefaultLimit As Integer = 8
    Private Const MaxLimit As Integer = 96
    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Private Class SearchFilters
        Public Property SettoreId As Integer
        Public Property CategoriaId As Integer
        Public Property TipologiaId As Integer
        Public Property GruppoId As Integer
        Public Property SottoGruppoId As Integer
        Public Property MarcaId As Integer
        Public Property ProdottoId As Integer
        Public Property SoloPromo As Boolean
        Public Property SoloDisponibili As Boolean
        Public Property SoloRicondizionati As Boolean
        Public Property MinPrice As Decimal
        Public Property MaxPrice As Decimal
        Public Property Sort As String
        Public Property Mode As String
    End Class

    Private Class QueryIntent
        Public Property Original As String
        Public Property SearchText As String
        Public Property Tokens As List(Of String)
        Public Property MaxPrice As Decimal
        Public Property MinPrice As Decimal
        Public Property WantsPromo As Boolean
        Public Property WantsAvailable As Boolean
        Public Property WantsRefurbished As Boolean
        Public Property IntentName As String
        Public Property Summary As String
    End Class

    Private Class SuggestItem
        Public Property Id As Integer
        Public Property Url As String
        Public Property Title As String
        Public Property Description As String
        Public Property Code As String
        Public Property Ean As String
        Public Property Brand As String
        Public Property Category As String
        Public Property Department As String
        Public Property Price As String
        Public Property PriceValue As Decimal
        Public Property Score As Integer
        Public Property MatchKind As String
        Public Property Image As String
        Public Property ImageFallback As String
        Public Property Availability As Decimal
        Public Property IsOffer As Boolean
        Public Property IsRefurbished As Boolean
        Public Property FreeShipping As Boolean
        Public Property TcId As String
        Public Property Reason As String
        Public Property Badges As List(Of String)
    End Class

    Private Class FacetItem
        Public Property Label As String
        Public Property Value As String
        Public Property Count As Integer
    End Class

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.Clear()
        Response.Charset = "utf-8"
        Response.ContentType = "application/json"
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()

        Dim payload As New Dictionary(Of String, Object)()

        Try
            Dim query As String = NormalizeQuery(SafeRequestValue("q"))
            Dim filters As SearchFilters = ReadFilters()
            Dim limit As Integer = Math.Max(1, Math.Min(MaxLimit, ReadInt(SafeRequestValue("limit"), DefaultLimit)))
            Dim recentIds As List(Of Integer) = ParseIds(SafeRequestValue("recent"))

            Dim result As Dictionary(Of String, Object)
            If String.IsNullOrWhiteSpace(query) OrElse query.Length < 2 Then
                result = BuildRecentResult(recentIds, filters, limit)
            Else
                result = BuildSearchResult(query, filters, limit)
            End If

            payload("ok") = True
            For Each kvp As KeyValuePair(Of String, Object) In result
                payload(kvp.Key) = kvp.Value
            Next
        Catch ex As Exception
            payload("ok") = False
            payload("error") = ex.Message
        End Try

        Dim serializer As New JavaScriptSerializer()
        serializer.MaxJsonLength = Integer.MaxValue
        Response.Write(serializer.Serialize(payload))
        Response.End()
    End Sub

    Private Function BuildRecentResult(ByVal recentIds As List(Of Integer), ByVal filters As SearchFilters, ByVal limit As Integer) As Dictionary(Of String, Object)
        Dim output As New Dictionary(Of String, Object)()
        output("query") = String.Empty
        output("recent") = True
        output("suggestions") = New List(Of Dictionary(Of String, Object))()
        output("rank_ids") = New List(Of Integer)()
        output("facets") = EmptyFacets()
        output("strong") = New Dictionary(Of String, Object) From {{"canRedirect", False}, {"redirectUrl", String.Empty}}
        output("intelligence") = New Dictionary(Of String, Object) From {{"summary", "Mostro gli ultimi articoli visitati o il fallback catalogo."}}
        output("total") = 0

        If recentIds Is Nothing OrElse recentIds.Count = 0 Then Return output

        Dim parameters As New List(Of DbParameterSpec)()
        Dim sql As New StringBuilder()
        AppendSelect(sql, False)
        sql.Append(" FROM vsuperarticoli v LEFT JOIN immagini i ON i.id = v.id WHERE COALESCE(v.NListino,1)=1 AND v.id IN (")
        sql.Append(String.Join(",", recentIds.Select(Function(n) n.ToString(CultureInfo.InvariantCulture))))
        sql.Append(")")
        AppendFilterClauses(sql, parameters, filters, "v")
        sql.Append(" ORDER BY FIELD(v.id,")
        sql.Append(String.Join(",", recentIds.Select(Function(n) n.ToString(CultureInfo.InvariantCulture))))
        sql.Append(") LIMIT ")
        sql.Append(limit.ToString(CultureInfo.InvariantCulture))

        Dim table As DataTable = ExecuteQuery(sql.ToString(), parameters)
        Dim mapped As List(Of SuggestItem) = MapSuggestions(table, String.Empty, Nothing).Take(limit).ToList()

        output("suggestions") = mapped.Select(Function(item) SerializeItem(item)).ToList()
        output("rank_ids") = mapped.Select(Function(item) item.Id).ToList()
        output("facets") = BuildFacets(mapped)
        output("total") = mapped.Count
        Return output
    End Function

    Private Function BuildSearchResult(ByVal query As String, ByVal filters As SearchFilters, ByVal limit As Integer) As Dictionary(Of String, Object)
        Dim intent As QueryIntent = InterpretQuery(query)
        If filters.MaxPrice <= 0D AndAlso intent.MaxPrice > 0D Then filters.MaxPrice = intent.MaxPrice
        If filters.MinPrice <= 0D AndAlso intent.MinPrice > 0D Then filters.MinPrice = intent.MinPrice
        If intent.WantsAvailable Then filters.SoloDisponibili = True
        If intent.WantsPromo Then filters.SoloPromo = True
        If intent.WantsRefurbished Then filters.SoloRicondizionati = True

        Dim tokens As List(Of String) = intent.Tokens
        If tokens.Count = 0 Then tokens = ExtractTokens(query)
        If tokens.Count = 0 Then tokens.Add(NormalizeSearchText(query))

        Dim parameters As New List(Of DbParameterSpec)()
        Dim normalizedQuery As String = NormalizeQuery(intent.SearchText).ToLowerInvariant()
        If String.IsNullOrWhiteSpace(normalizedQuery) Then normalizedQuery = NormalizeQuery(query).ToLowerInvariant()

        Dim likeQuery As String = EscapeLikeValue(normalizedQuery)
        parameters.Add(New DbParameterSpec("@qExact", normalizedQuery))
        parameters.Add(New DbParameterSpec("@qPrefix", likeQuery & "%"))
        parameters.Add(New DbParameterSpec("@qContains", "%" & likeQuery & "%"))
        parameters.Add(New DbParameterSpec("@qWord", "% " & likeQuery & "%"))

        For i As Integer = 0 To tokens.Count - 1
            Dim tokenValue As String = tokens(i)
            Dim likeToken As String = EscapeLikeValue(tokenValue)
            parameters.Add(New DbParameterSpec("@t" & i.ToString(CultureInfo.InvariantCulture), tokenValue))
            parameters.Add(New DbParameterSpec("@tc" & i.ToString(CultureInfo.InvariantCulture), "%" & likeToken & "%"))
            parameters.Add(New DbParameterSpec("@tp" & i.ToString(CultureInfo.InvariantCulture), likeToken & "%"))
            parameters.Add(New DbParameterSpec("@tw" & i.ToString(CultureInfo.InvariantCulture), "% " & likeToken & "%"))
        Next

        Dim sql As New StringBuilder()
        AppendSelect(sql, True, BuildScoreExpression(tokens, intent))
        sql.Append(" FROM vsuperarticoli v LEFT JOIN immagini i ON i.id = v.id WHERE COALESCE(v.NListino,1)=1 ")
        sql.Append(" AND (")
        sql.Append("LOWER(COALESCE(v.Codice,'')) = @qExact OR LOWER(COALESCE(v.Ean,'')) = @qExact OR LOWER(COALESCE(v.Descrizione1,'')) = @qExact OR ")
        sql.Append("LOWER(COALESCE(v.Codice,'')) LIKE @qPrefix OR LOWER(COALESCE(v.Ean,'')) LIKE @qPrefix OR LOWER(COALESCE(v.Descrizione1,'')) LIKE @qPrefix OR ")
        sql.Append("LOWER(CONCAT(' ', COALESCE(v.Codice,''))) LIKE @qWord OR LOWER(CONCAT(' ', COALESCE(v.Ean,''))) LIKE @qWord OR LOWER(CONCAT(' ', COALESCE(v.Descrizione1,''))) LIKE @qWord OR ")
        sql.Append("LOWER(CONCAT(' ', COALESCE(v.MarcheDescrizione,''), ' ', COALESCE(v.Descrizione1,''))) LIKE @qWord OR ")
        sql.Append("LOWER(COALESCE(v.Descrizione1,'')) LIKE @qContains OR LOWER(COALESCE(v.Descrizione2,'')) LIKE @qContains OR LOWER(COALESCE(v.DescrizioneLunga,'')) LIKE @qContains OR LOWER(COALESCE(v.DescrizioneHTML,'')) LIKE @qContains OR ")
        sql.Append("LOWER(CONCAT(' ', COALESCE(v.MarcheDescrizione,''), ' ', COALESCE(v.SettoriDescrizione,''), ' ', COALESCE(v.CategorieDescrizione,''), ' ', COALESCE(v.TipologieDescrizione,''), ' ', COALESCE(v.GruppiDEscrizione,''), ' ', COALESCE(v.SottogruppiDescrIZione,''))) LIKE @qContains ")
        For i As Integer = 0 To tokens.Count - 1
            sql.Append(" OR LOWER(COALESCE(v.Codice,'')) LIKE @tc").Append(i.ToString(CultureInfo.InvariantCulture))
            sql.Append(" OR LOWER(COALESCE(v.Ean,'')) LIKE @tc").Append(i.ToString(CultureInfo.InvariantCulture))
            sql.Append(" OR LOWER(COALESCE(v.Descrizione1,'')) LIKE @tc").Append(i.ToString(CultureInfo.InvariantCulture))
            sql.Append(" OR LOWER(COALESCE(v.Descrizione2,'')) LIKE @tc").Append(i.ToString(CultureInfo.InvariantCulture))
            sql.Append(" OR LOWER(COALESCE(v.DescrizioneLunga,'')) LIKE @tc").Append(i.ToString(CultureInfo.InvariantCulture))
            sql.Append(" OR LOWER(COALESCE(v.DescrizioneHTML,'')) LIKE @tc").Append(i.ToString(CultureInfo.InvariantCulture))
            sql.Append(" OR LOWER(CONCAT(' ', COALESCE(v.MarcheDescrizione,''), ' ', COALESCE(v.SettoriDescrizione,''), ' ', COALESCE(v.CategorieDescrizione,''), ' ', COALESCE(v.TipologieDescrizione,''), ' ', COALESCE(v.GruppiDEscrizione,''), ' ', COALESCE(v.SottogruppiDescrIZione,''))) LIKE @tc").Append(i.ToString(CultureInfo.InvariantCulture))
        Next
        sql.Append(")")
        AppendFilterClauses(sql, parameters, filters, "v")
        sql.Append(BuildOrderBy(filters))
        sql.Append(" LIMIT ")
        sql.Append(Math.Max(limit, If(String.Equals(filters.Mode, "marketplace", StringComparison.OrdinalIgnoreCase), 36, 60)).ToString(CultureInfo.InvariantCulture))

        Dim table As DataTable = ExecuteQuery(sql.ToString(), parameters)
        Dim mapped As List(Of SuggestItem) = MapSuggestions(table, query, intent)
        mapped = mapped.Take(limit).ToList()

        Dim strong As New Dictionary(Of String, Object) From {{"canRedirect", False}, {"redirectUrl", String.Empty}, {"articleId", 0}, {"matchKind", String.Empty}}
        If mapped.Count = 1 Then
            If mapped(0).MatchKind = "exact-code" OrElse mapped(0).MatchKind = "exact-ean" Then
                strong("canRedirect") = True
                strong("redirectUrl") = mapped(0).Url
                strong("articleId") = mapped(0).Id
                strong("matchKind") = mapped(0).MatchKind
            End If
        ElseIf mapped.Count > 1 Then
            If (mapped(0).MatchKind = "exact-code" OrElse mapped(0).MatchKind = "exact-ean") AndAlso mapped(0).Score >= mapped(1).Score + 2000 Then
                strong("canRedirect") = True
                strong("redirectUrl") = mapped(0).Url
                strong("articleId") = mapped(0).Id
                strong("matchKind") = mapped(0).MatchKind
            End If
        End If

        Return New Dictionary(Of String, Object) From {
            {"query", query},
            {"normalized_query", intent.SearchText},
            {"recent", False},
            {"suggestions", mapped.Select(Function(item) SerializeItem(item)).ToList()},
            {"rank_ids", mapped.Select(Function(item) item.Id).ToList()},
            {"facets", BuildFacets(mapped)},
            {"strong", strong},
            {"intelligence", SerializeIntent(intent, filters, mapped.Count)},
            {"total", mapped.Count},
            {"catalogUrl", BuildCatalogUrl(query, filters)}
        }
    End Function

    Private Sub AppendSelect(ByVal sql As StringBuilder, ByVal includeRank As Boolean, Optional ByVal rankExpr As String = "")
        sql.Append("SELECT DISTINCT v.id, v.Codice, v.Ean, v.Descrizione1, v.Descrizione2, v.DescrizioneLunga, v.DescrizioneHTML, ")
        sql.Append("v.MarcheDescrizione, v.SettoriDescrizione, v.CategorieDescrizione, v.TipologieDescrizione, v.GruppiDEscrizione, v.SottogruppiDescrIZione, ")
        sql.Append("v.Img1, v.Img2, v.Img3, v.Img4, i.Immagine1, i.Immagine2, i.Immagine3, i.Immagine4, i.Immagine5, i.Immagine6, ")
        sql.Append("COALESCE(NULLIF(v.PrezzoPromoIvato,0), NULLIF(v.PrezzoIvato,0), NULLIF(v.PrezzoPromo,0), v.Prezzo, 0) AS PrezzoFinale, ")
        sql.Append("COALESCE(v.Disponibilita,0) AS Disponibilita, COALESCE(v.InOfferta,0) AS InOfferta, COALESCE(v.Vetrina,0) AS Vetrina, COALESCE(v.visite,0) AS Visite, ")
        sql.Append("COALESCE(v.Ricondizionato,0) AS Ricondizionato, COALESCE(v.NoteRicondizionato,'') AS NoteRicondizionato, COALESCE(v.SpeditoGratis,0) AS SpeditoGratis, COALESCE(v.TCid,'') AS TCid, v.DataCreazione ")
        If includeRank Then
            sql.Append(", ")
            sql.Append(If(String.IsNullOrWhiteSpace(rankExpr), "0", rankExpr))
            sql.Append(" AS RankScore ")
        End If
    End Sub

    Private Function BuildScoreExpression(ByVal tokens As List(Of String), ByVal intent As QueryIntent) As String
        Dim sb As New StringBuilder()
        sb.Append("(")
        ' Marketplace-grade rank bands. Keep these aligned with articoli.aspx.vb.
        sb.Append("(CASE ")
        sb.Append("WHEN LOWER(TRIM(COALESCE(v.Codice,''))) = @qExact THEN 10000000 ")
        sb.Append("WHEN LOWER(TRIM(COALESCE(v.Ean,''))) = @qExact THEN 9900000 ")
        sb.Append("WHEN LOWER(TRIM(COALESCE(v.Descrizione1,''))) = @qExact THEN 9800000 ")
        sb.Append("WHEN LOWER(TRIM(COALESCE(v.Codice,''))) LIKE @qPrefix OR LOWER(CONCAT(' ', COALESCE(v.Codice,''))) LIKE @qWord THEN 8800000 ")
        sb.Append("WHEN LOWER(TRIM(COALESCE(v.Ean,''))) LIKE @qPrefix OR LOWER(CONCAT(' ', COALESCE(v.Ean,''))) LIKE @qWord THEN 8700000 ")
        sb.Append("WHEN LOWER(TRIM(COALESCE(v.Descrizione1,''))) LIKE @qPrefix OR LOWER(CONCAT(' ', COALESCE(v.Descrizione1,''))) LIKE @qWord THEN 8600000 ")
        sb.Append("WHEN LOWER(CONCAT(' ', COALESCE(v.MarcheDescrizione,''), ' ', COALESCE(v.Descrizione1,''))) LIKE @qWord THEN 8200000 ")
        sb.Append("WHEN LOWER(COALESCE(v.Descrizione1,'')) LIKE @qContains THEN 3600000 ")
        sb.Append("WHEN LOWER(COALESCE(v.DescrizioneLunga,'')) LIKE @qContains THEN 2600000 ")
        sb.Append("WHEN LOWER(COALESCE(v.MarcheDescrizione,'')) LIKE @qContains THEN 2400000 ")
        sb.Append("WHEN LOWER(COALESCE(v.Descrizione2,'')) LIKE @qContains THEN 1800000 ")
        sb.Append("WHEN LOWER(COALESCE(v.DescrizioneHTML,'')) LIKE @qContains THEN 1200000 ")
        sb.Append("ELSE 0 END) ")
        For i As Integer = 0 To tokens.Count - 1
            Dim n As String = i.ToString(CultureInfo.InvariantCulture)
            sb.Append(" + (CASE ")
            sb.Append("WHEN LOWER(COALESCE(v.Codice,'')) = @t").Append(n).Append(" THEN 9000 ")
            sb.Append("WHEN LOWER(COALESCE(v.Ean,'')) = @t").Append(n).Append(" THEN 8800 ")
            sb.Append("WHEN LOWER(COALESCE(v.Descrizione1,'')) = @t").Append(n).Append(" THEN 8600 ")
            sb.Append("WHEN LOWER(COALESCE(v.Codice,'')) LIKE @tp").Append(n).Append(" OR LOWER(CONCAT(' ',COALESCE(v.Codice,''))) LIKE @tw").Append(n).Append(" THEN 6200 ")
            sb.Append("WHEN LOWER(COALESCE(v.Ean,'')) LIKE @tp").Append(n).Append(" OR LOWER(CONCAT(' ',COALESCE(v.Ean,''))) LIKE @tw").Append(n).Append(" THEN 6000 ")
            sb.Append("WHEN LOWER(COALESCE(v.Descrizione1,'')) LIKE @tp").Append(n).Append(" OR LOWER(CONCAT(' ',COALESCE(v.Descrizione1,''))) LIKE @tw").Append(n).Append(" THEN 5800 ")
            sb.Append("WHEN LOWER(CONCAT(' ',COALESCE(v.MarcheDescrizione,''),' ',COALESCE(v.Descrizione1,''))) LIKE @tw").Append(n).Append(" THEN 5200 ")
            sb.Append("WHEN LOWER(COALESCE(v.Descrizione1,'')) LIKE @tc").Append(n).Append(" THEN 2600 ")
            sb.Append("WHEN LOWER(COALESCE(v.DescrizioneLunga,'')) LIKE @tc").Append(n).Append(" THEN 1800 ")
            sb.Append("WHEN LOWER(COALESCE(v.MarcheDescrizione,'')) LIKE @tc").Append(n).Append(" THEN 1600 ")
            sb.Append("ELSE 0 END)")
        Next
        ' Tie-breaker only: never let commercial boosts outrank textual relevance bands.
        sb.Append(" + (CASE WHEN COALESCE(v.Disponibilita,0) > 0 THEN 600 ELSE 0 END)")
        sb.Append(" + (CASE WHEN COALESCE(v.InOfferta,0) <> 0 THEN 450 ELSE 0 END)")
        sb.Append(" + (CASE WHEN COALESCE(v.Vetrina,0) <> 0 THEN 250 ELSE 0 END)")
        sb.Append(" + LEAST(COALESCE(v.visite,0),999)")
        sb.Append(")")
        Return sb.ToString()
    End Function

    Private Function BuildOrderBy(ByVal filters As SearchFilters) As String
        Dim sort As String = Convert.ToString(If(filters Is Nothing, String.Empty, filters.Sort)).ToLowerInvariant()
        Select Case sort
            Case "price-asc", "prezzo-asc"
                Return " ORDER BY PrezzoFinale ASC, RankScore DESC, COALESCE(v.Disponibilita,0) DESC, v.id DESC"
            Case "price-desc", "prezzo-desc"
                Return " ORDER BY PrezzoFinale DESC, RankScore DESC, COALESCE(v.Disponibilita,0) DESC, v.id DESC"
            Case "promo", "offerte"
                Return " ORDER BY COALESCE(v.InOfferta,0) DESC, RankScore DESC, PrezzoFinale ASC, COALESCE(v.Disponibilita,0) DESC, v.id DESC"
            Case "available", "disponibili"
                Return " ORDER BY COALESCE(v.Disponibilita,0) DESC, RankScore DESC, PrezzoFinale ASC, COALESCE(v.InOfferta,0) DESC, v.id DESC"
            Case "new", "novita"
                Return " ORDER BY v.DataCreazione DESC, RankScore DESC, COALESCE(v.Disponibilita,0) DESC, v.id DESC"
            Case Else
                Return " ORDER BY RankScore DESC, COALESCE(v.Disponibilita,0) DESC, COALESCE(v.InOfferta,0) DESC, COALESCE(v.Vetrina,0) DESC, COALESCE(v.visite,0) DESC, PrezzoFinale ASC, v.id DESC"
        End Select
    End Function

    Private Sub AppendFilterClauses(ByVal sql As StringBuilder, ByVal parameters As List(Of DbParameterSpec), ByVal filters As SearchFilters, ByVal aliasName As String)
        If filters Is Nothing Then Return
        Dim a As String = If(String.IsNullOrWhiteSpace(aliasName), String.Empty, aliasName.Trim() & ".")

        AppendIntFilter(sql, parameters, filters.SettoreId, a & "SettoriId", "@st")
        AppendIntFilter(sql, parameters, filters.CategoriaId, a & "CategorieId", "@ct")
        AppendIntFilter(sql, parameters, filters.TipologiaId, a & "TipologieId", "@tpfilter")
        AppendIntFilter(sql, parameters, filters.GruppoId, a & "GruppiId", "@gr")
        AppendIntFilter(sql, parameters, filters.SottoGruppoId, a & "SottoGrupPIId", "@sg")
        AppendIntFilter(sql, parameters, filters.MarcaId, a & "MarcheId", "@mr")
        AppendIntFilter(sql, parameters, filters.ProdottoId, a & "id", "@pid")

        If filters.SoloPromo Then sql.Append(" AND COALESCE(" & a & "InOfferta,0) <> 0")
        If filters.SoloDisponibili Then sql.Append(" AND COALESCE(" & a & "Disponibilita,0) > 0")
        If filters.SoloRicondizionati Then sql.Append(" AND COALESCE(" & a & "Ricondizionato,0) <> 0")

        If filters.MinPrice > 0D Then
            sql.Append(" AND COALESCE(NULLIF(" & a & "PrezzoPromoIvato,0), NULLIF(" & a & "PrezzoIvato,0), NULLIF(" & a & "PrezzoPromo,0), " & a & "Prezzo, 0) >= @minPrice")
            If parameters IsNot Nothing Then parameters.Add(New DbParameterSpec("@minPrice", filters.MinPrice))
        End If
        If filters.MaxPrice > 0D Then
            sql.Append(" AND COALESCE(NULLIF(" & a & "PrezzoPromoIvato,0), NULLIF(" & a & "PrezzoIvato,0), NULLIF(" & a & "PrezzoPromo,0), " & a & "Prezzo, 0) <= @maxPrice")
            If parameters IsNot Nothing Then parameters.Add(New DbParameterSpec("@maxPrice", filters.MaxPrice))
        End If
    End Sub

    Private Sub AppendIntFilter(ByVal sql As StringBuilder, ByVal parameters As List(Of DbParameterSpec), ByVal value As Integer, ByVal fieldName As String, ByVal paramName As String)
        If value <= 0 Then Return
        sql.Append(" AND ")
        sql.Append(fieldName)
        sql.Append(" = ")
        sql.Append(paramName)
        If parameters IsNot Nothing Then parameters.Add(New DbParameterSpec(paramName, value))
    End Sub

    Private Function MapSuggestions(ByVal table As DataTable, ByVal query As String, ByVal intent As QueryIntent) As List(Of SuggestItem)
        Dim results As New List(Of SuggestItem)()
        If table Is Nothing Then Return results

        For Each row As DataRow In table.Rows
            Dim code As String = SafeString(row("Codice"))
            Dim ean As String = SafeString(row("Ean"))
            Dim title As String = SafeString(row("Descrizione1"))
            Dim brand As String = SafeString(row("MarcheDescrizione"))
            Dim cat As String = SafeString(row("CategorieDescrizione"))
            If String.IsNullOrWhiteSpace(cat) Then cat = SafeString(row("TipologieDescrizione"))
            If String.IsNullOrWhiteSpace(cat) Then cat = SafeString(row("SettoriDescrizione"))

            Dim item As New SuggestItem()
            item.Id = ReadInt(row("id"), 0)
            item.Url = "articolo.aspx?id=" & item.Id.ToString(CultureInfo.InvariantCulture)
            item.Title = title
            item.Description = MakeShortDescription(SafeString(row("Descrizione2")), SafeString(row("DescrizioneLunga")), SafeString(row("DescrizioneHTML")))
            item.Code = code
            item.Ean = ean
            item.Brand = brand
            item.Category = cat
            item.Department = SafeString(row("SettoriDescrizione"))
            item.PriceValue = ReadDec(row("PrezzoFinale"), 0D)
            item.Price = FormatPrice(item.PriceValue)
            item.Score = If(row.Table.Columns.Contains("RankScore"), ReadInt(row("RankScore"), 0), 0)
            item.MatchKind = DetectMatchKind(code, ean, title, brand, query)
            item.Availability = ReadDec(row("Disponibilita"), 0D)
            item.IsOffer = ReadInt(row("InOfferta"), 0) <> 0
            item.IsRefurbished = ReadInt(row("Ricondizionato"), 0) <> 0
            item.FreeShipping = If(row.Table.Columns.Contains("SpeditoGratis"), ReadInt(row("SpeditoGratis"), 0) <> 0, False)
            item.TcId = If(row.Table.Columns.Contains("TCid"), SafeString(row("TCid")), String.Empty)
            Dim images As List(Of String) = CollectImages(row)
            item.ImageFallback = If(images.Count > 0, images(0), String.Empty)
            item.Image = BuildPreviewVariant(item.ImageFallback)
            If String.IsNullOrWhiteSpace(item.Image) Then item.Image = item.ImageFallback
            item.Badges = BuildBadges(item, intent)
            item.Reason = BuildReason(item, intent)
            results.Add(item)
        Next

        Return results
    End Function

    Private Function SerializeItem(ByVal item As SuggestItem) As Dictionary(Of String, Object)
        Return New Dictionary(Of String, Object) From {
            {"id", item.Id}, {"url", item.Url}, {"title", item.Title}, {"description", item.Description},
            {"code", item.Code}, {"ean", item.Ean}, {"brand", item.Brand}, {"category", item.Category}, {"department", item.Department},
            {"price", item.Price}, {"priceValue", item.PriceValue}, {"image", item.Image}, {"image_fallback", item.ImageFallback},
            {"matchKind", item.MatchKind}, {"score", item.Score}, {"availability", item.Availability},
            {"isOffer", item.IsOffer}, {"isRefurbished", item.IsRefurbished}, {"freeShipping", item.FreeShipping}, {"tcId", item.TcId}, {"reason", item.Reason}, {"badges", item.Badges}
        }
    End Function

    Private Function BuildBadges(ByVal item As SuggestItem, ByVal intent As QueryIntent) As List(Of String)
        Dim badges As New List(Of String)()
        If item.IsOffer Then badges.Add("Promo")
        If item.Availability > 0D Then badges.Add("Disponibile")
        If item.IsRefurbished Then badges.Add("Ricondizionato")
        If item.FreeShipping Then badges.Add("Spedizione gratis")
        If intent IsNot Nothing AndAlso intent.MaxPrice > 0D AndAlso item.PriceValue > 0D AndAlso item.PriceValue <= intent.MaxPrice Then badges.Add("Budget ok")
        If badges.Count = 0 Then badges.Add("Catalogo")
        Return badges.Take(4).ToList()
    End Function

    Private Function BuildReason(ByVal item As SuggestItem, ByVal intent As QueryIntent) As String
        Dim parts As New List(Of String)()
        If item.MatchKind.StartsWith("exact", StringComparison.OrdinalIgnoreCase) Then parts.Add("corrispondenza esatta")
        If item.Availability > 0D Then parts.Add("disponibile")
        If item.IsOffer Then parts.Add("in offerta")
        If item.IsRefurbished Then parts.Add("ricondizionato")
        If item.FreeShipping Then parts.Add("spedizione gratis")
        If intent IsNot Nothing AndAlso intent.MaxPrice > 0D AndAlso item.PriceValue > 0D AndAlso item.PriceValue <= intent.MaxPrice Then parts.Add("entro budget")
        If parts.Count = 0 Then parts.Add("pertinente per descrizione, marca o categoria")
        Return "Consigliato per " & String.Join(", ", parts.Take(4)) & "."
    End Function

    Private Function BuildFacets(ByVal items As List(Of SuggestItem)) As Dictionary(Of String, Object)
        Dim brands = items.Where(Function(i) Not String.IsNullOrWhiteSpace(i.Brand)).GroupBy(Function(i) i.Brand).Select(Function(g) New Dictionary(Of String, Object) From {{"label", g.Key}, {"value", g.Key}, {"count", g.Count()}}).OrderByDescending(Function(x) CInt(x("count"))).Take(8).ToList()
        Dim categories = items.Where(Function(i) Not String.IsNullOrWhiteSpace(i.Category)).GroupBy(Function(i) i.Category).Select(Function(g) New Dictionary(Of String, Object) From {{"label", g.Key}, {"value", g.Key}, {"count", g.Count()}}).OrderByDescending(Function(x) CInt(x("count"))).Take(8).ToList()
        Return New Dictionary(Of String, Object) From {{"brands", brands}, {"categories", categories}}
    End Function

    Private Function BuildCatalogUrl(ByVal query As String, ByVal filters As SearchFilters) As String
        Dim url As New StringBuilder("articoli.aspx")
        Dim args As New List(Of String)()
        If Not String.IsNullOrWhiteSpace(query) Then args.Add("q=" & HttpUtility.UrlEncode(query))
        If filters IsNot Nothing Then
            If filters.SettoreId > 0 Then args.Add("st=" & filters.SettoreId.ToString(CultureInfo.InvariantCulture))
            If filters.CategoriaId > 0 Then args.Add("ct=" & filters.CategoriaId.ToString(CultureInfo.InvariantCulture))
            If filters.TipologiaId > 0 Then args.Add("tp=" & filters.TipologiaId.ToString(CultureInfo.InvariantCulture))
            If filters.GruppoId > 0 Then args.Add("gr=" & filters.GruppoId.ToString(CultureInfo.InvariantCulture))
            If filters.SottoGruppoId > 0 Then args.Add("sg=" & filters.SottoGruppoId.ToString(CultureInfo.InvariantCulture))
            If filters.MarcaId > 0 Then args.Add("mr=" & filters.MarcaId.ToString(CultureInfo.InvariantCulture))
            If filters.SoloPromo Then args.Add("inpromo=1")
            If filters.SoloDisponibili Then args.Add("available=1")
            If filters.SoloRicondizionati Then args.Add("ricondizionato=1")
            If filters.MinPrice > 0D Then args.Add("min=" & filters.MinPrice.ToString(CultureInfo.InvariantCulture))
            If filters.MaxPrice > 0D Then args.Add("max=" & filters.MaxPrice.ToString(CultureInfo.InvariantCulture))
            If Not String.IsNullOrWhiteSpace(filters.Sort) Then args.Add("sort=" & HttpUtility.UrlEncode(filters.Sort))
        End If
        If args.Count > 0 Then url.Append("?").Append(String.Join("&", args))
        Return url.ToString()
    End Function

    Private Function EmptyFacets() As Dictionary(Of String, Object)
        Return New Dictionary(Of String, Object) From {{"brands", New List(Of Object)()}, {"categories", New List(Of Object)()}}
    End Function

    Private Function SerializeIntent(ByVal intent As QueryIntent, ByVal filters As SearchFilters, ByVal count As Integer) As Dictionary(Of String, Object)
        Dim summary As String = "Ho interpretato la richiesta come ricerca " & intent.IntentName & "."
        If intent.MaxPrice > 0D OrElse filters.MaxPrice > 0D Then summary &= " Budget massimo: " & If(filters.MaxPrice > 0D, filters.MaxPrice, intent.MaxPrice).ToString("C0", ItCulture) & "."
        If filters.SoloDisponibili Then summary &= " Priorita ai prodotti disponibili."
        If filters.SoloPromo Then summary &= " Priorita alle offerte."
        If filters.SoloRicondizionati Then summary &= " Filtro ricondizionati attivo."
        summary &= " Articoli coerenti analizzati: " & count.ToString(CultureInfo.InvariantCulture) & "."
        Return New Dictionary(Of String, Object) From {{"intent", intent.IntentName}, {"tokens", intent.Tokens}, {"summary", summary}, {"maxPrice", If(filters.MaxPrice > 0D, filters.MaxPrice, intent.MaxPrice)}, {"minPrice", If(filters.MinPrice > 0D, filters.MinPrice, intent.MinPrice)}}
    End Function

    Private Function InterpretQuery(ByVal raw As String) As QueryIntent
        Dim original As String = NormalizeQuery(raw)
        Dim text As String = original.ToLowerInvariant()
        Dim intent As New QueryIntent()
        intent.Original = original
        intent.SearchText = original
        intent.Tokens = New List(Of String)()
        intent.IntentName = "catalogo"

        Dim maxMatch As Match = Regex.Match(text, "(?:sotto|entro|max|massimo|fino a|meno di|non oltre)\s*(?:€|euro)?\s*(\d+(?:[\.,]\d+)?)", RegexOptions.IgnoreCase)
        If Not maxMatch.Success Then maxMatch = Regex.Match(text, "(\d+(?:[\.,]\d+)?)\s*(?:€|euro)\s*(?:max|massimo|entro)?", RegexOptions.IgnoreCase)
        If maxMatch.Success Then
            intent.MaxPrice = ParseDecimal(maxMatch.Groups(1).Value, 0D)
            text = text.Replace(maxMatch.Value.ToLowerInvariant(), " ")
        End If

        Dim minMatch As Match = Regex.Match(text, "(?:da|oltre|min|minimo)\s*(?:€|euro)?\s*(\d+(?:[\.,]\d+)?)", RegexOptions.IgnoreCase)
        If minMatch.Success Then
            intent.MinPrice = ParseDecimal(minMatch.Groups(1).Value, 0D)
            text = text.Replace(minMatch.Value.ToLowerInvariant(), " ")
        End If

        intent.WantsPromo = Regex.IsMatch(text, "\b(offerta|offerte|promo|sconto|scontato|occasion[ei])\b", RegexOptions.IgnoreCase)
        intent.WantsAvailable = Regex.IsMatch(text, "\b(disponibile|disponibili|subito|pronta consegna|magazzino)\b", RegexOptions.IgnoreCase)
        intent.WantsRefurbished = Regex.IsMatch(text, "\b(ricondizionato|ricondizionati|refurbished|usato garantito)\b", RegexOptions.IgnoreCase)

        If Regex.IsMatch(text, "\b(custodia|cover|pellicola|vetro|proteggi|protezione|smartphone|samsung|iphone)\b", RegexOptions.IgnoreCase) Then intent.IntentName = "protezione smartphone"
        If Regex.IsMatch(text, "\b(toner|cartuccia|inchiostro|stampante|pantum|hp|brother|canon|epson)\b", RegexOptions.IgnoreCase) Then intent.IntentName = "stampa e consumabili"
        If Regex.IsMatch(text, "\b(notebook|computer|pc|desktop|ssd|ram|monitor|windows)\b", RegexOptions.IgnoreCase) Then intent.IntentName = "pc e notebook"
        If Regex.IsMatch(text, "\b(cavo|adattatore|hub|usb|usb-c|hdmi|alimentatore|caricatore)\b", RegexOptions.IgnoreCase) Then intent.IntentName = "cavi e accessori"

        text = Regex.Replace(text, "\b(sotto|entro|max|massimo|fino|meno|oltre|euro|eur|con|per|il|la|lo|le|gli|un|una|uno|di|da|a|e|o|in|solo|cerca|cerco|trova|voglio|prodotto|prodotti|disponibile|disponibili|offerta|offerte|promo|ricondizionato|ricondizionati)\b", " ", RegexOptions.IgnoreCase)
        intent.SearchText = Regex.Replace(text, "\s+", " ").Trim()
        If String.IsNullOrWhiteSpace(intent.SearchText) Then intent.SearchText = original
        intent.Tokens = ExtractTokens(intent.SearchText)
        Return intent
    End Function

    Private Function ExtractTokens(ByVal value As String) As List(Of String)
        Dim normalized As String = NormalizeSearchText(value)
        Dim stopWords As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {"il", "la", "lo", "le", "gli", "un", "una", "uno", "di", "da", "a", "e", "o", "in", "con", "per", "del", "della", "dello", "dei", "degli", "prodotto", "prodotti", "cerca", "trova"}
        Return normalized.Split(" "c).Select(Function(t) t.Trim()).Where(Function(t) t.Length >= 2 AndAlso Not stopWords.Contains(t)).Distinct(StringComparer.OrdinalIgnoreCase).Take(8).ToList()
    End Function

    Private Function StartsWithWord(ByVal value As String, ByVal term As String) As Boolean
        Dim v As String = NormalizeSearchText(value)
        Dim t As String = NormalizeSearchText(term)
        If String.IsNullOrWhiteSpace(v) OrElse String.IsNullOrWhiteSpace(t) Then Return False
        Return v.StartsWith(t, StringComparison.OrdinalIgnoreCase) OrElse v.Contains(" " & t)
    End Function

    Private Function ContainsNormalized(ByVal value As String, ByVal term As String) As Boolean
        Dim v As String = NormalizeSearchText(value)
        Dim t As String = NormalizeSearchText(term)
        If String.IsNullOrWhiteSpace(v) OrElse String.IsNullOrWhiteSpace(t) Then Return False
        Return v.Contains(t)
    End Function

    Private Function DetectMatchKind(ByVal code As String, ByVal ean As String, ByVal title As String, ByVal brand As String, ByVal query As String) As String
        Dim q As String = NormalizeSearchText(query)
        If String.IsNullOrWhiteSpace(q) Then Return "recent"
        If NormalizeSearchText(code) = q Then Return "exact-code"
        If NormalizeSearchText(ean) = q Then Return "exact-ean"
        If NormalizeSearchText(title) = q Then Return "exact-title"
        If StartsWithWord(code, q) Then Return "prefix-code"
        If StartsWithWord(ean, q) Then Return "prefix-ean"
        If StartsWithWord(title, q) Then Return "prefix-title"
        If StartsWithWord(brand & " " & title, q) Then Return "prefix-brand-title"
        If ContainsNormalized(title, q) Then Return "contains-title"
        If ContainsNormalized(brand, q) Then Return "contains-brand"
        Return "contains"
    End Function

    Private Function ReadFilters() As SearchFilters
        Return New SearchFilters() With {
            .SettoreId = ReadInt(SafeRequestValue("st"), 0),
            .CategoriaId = ReadInt(SafeRequestValue("ct"), 0),
            .TipologiaId = ReadInt(SafeRequestValue("tp"), 0),
            .GruppoId = ReadInt(SafeRequestValue("gr"), 0),
            .SottoGruppoId = ReadInt(SafeRequestValue("sg"), 0),
            .MarcaId = ReadInt(SafeRequestValue("mr"), 0),
            .ProdottoId = ReadInt(SafeRequestValue("pid"), 0),
            .SoloPromo = (ReadInt(SafeRequestValue("inpromo"), 0) <> 0 OrElse ReadInt(SafeRequestValue("promo"), 0) <> 0),
            .SoloDisponibili = (ReadInt(SafeRequestValue("available"), 0) <> 0 OrElse ReadInt(SafeRequestValue("disponibili"), 0) <> 0),
            .SoloRicondizionati = (ReadInt(SafeRequestValue("refurbished"), 0) <> 0 OrElse ReadInt(SafeRequestValue("ricondizionato"), 0) <> 0),
            .MinPrice = ReadDecParam(SafeRequestValue("min"), 0D),
            .MaxPrice = ReadDecParam(SafeRequestValue("max"), 0D),
            .Sort = SafeRequestValue("sort"),
            .Mode = SafeRequestValue("mode")
        }
    End Function

    Private Function SafeRequestValue(ByVal key As String) As String
        If String.IsNullOrWhiteSpace(key) OrElse Request Is Nothing Then Return String.Empty
        Try
            Dim value As String = Request.QueryString(key)
            If value Is Nothing Then value = Request.Form(key)
            If value Is Nothing Then value = Request(key)
            Return If(value, String.Empty)
        Catch
            Return String.Empty
        End Try
    End Function

    Private Function ParseIds(ByVal raw As String) As List(Of Integer)
        Dim result As New List(Of Integer)()
        Dim seen As New HashSet(Of Integer)()
        Dim text As String = If(raw, String.Empty)
        For Each token As String In text.Split(","c)
            Dim value As Integer
            If Integer.TryParse(token.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, value) AndAlso value > 0 Then
                If Not seen.Contains(value) Then seen.Add(value) : result.Add(value)
            End If
        Next
        Return result
    End Function

    Private Function ReadCookieValue(ByVal name As String) As String
        Dim cookie = Request.Cookies(name)
        If cookie Is Nothing Then Return String.Empty
        Return Convert.ToString(cookie.Value)
    End Function

    Private Function NormalizeQuery(ByVal value As String) As String
        If value Is Nothing Then Return String.Empty
        Dim decoded As String = HttpUtility.HtmlDecode(value)
        Dim text As String = If(decoded, String.Empty).Trim()
        text = Regex.Replace(text, "\s+", " ").Trim()
        Return text
    End Function

    Private Function NormalizeSearchText(ByVal value As String) As String
        Dim text As String = NormalizeQuery(value).ToLowerInvariant()
        text = text.Normalize(NormalizationForm.FormD)
        text = Regex.Replace(text, "[\u0300-\u036f]", String.Empty)
        text = Regex.Replace(text, "[^a-z0-9]+", " ").Trim()
        text = Regex.Replace(text, "\s+", " ").Trim()
        Return text
    End Function

    Private Function EscapeLikeValue(ByVal value As String) As String
        Return Convert.ToString(value).Replace("\", "\\").Replace("%", "\%").Replace("_", "\_")
    End Function

    Private Function MakeShortDescription(ByVal d2 As String, ByVal lunga As String, ByVal html As String) As String
        Dim value As String = If(Not String.IsNullOrWhiteSpace(d2), d2, If(Not String.IsNullOrWhiteSpace(lunga), lunga, html))
        value = Regex.Replace(HttpUtility.HtmlDecode(Regex.Replace(value, "<[^>]+>", " ")), "\s+", " ").Trim()
        If value.Length > 180 Then value = value.Substring(0, 177).Trim() & "..."
        Return value
    End Function

    Private Function CollectImages(ByVal row As DataRow) As List(Of String)
        Dim output As New List(Of String)()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim names As String() = {"Img1", "Img2", "Img3", "Img4", "Immagine1", "Immagine2", "Immagine3", "Immagine4", "Immagine5", "Immagine6"}
        For Each name As String In names
            If Not row.Table.Columns.Contains(name) Then Continue For
            Dim url As String = NormalizeMediaUrl(row(name))
            If String.IsNullOrWhiteSpace(url) Then Continue For
            If seen.Add(url) Then output.Add(url)
            If output.Count >= 5 Then Exit For
        Next
        Return output
    End Function

    Private Function BuildPreviewVariant(ByVal raw As String) As String
        Dim url As String = NormalizeMediaUrl(raw)
        If String.IsNullOrWhiteSpace(url) Then Return String.Empty
        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse url.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then Return url

        Dim fileName As String = Path.GetFileName(url)
        If String.IsNullOrWhiteSpace(fileName) OrElse fileName.StartsWith("_", StringComparison.OrdinalIgnoreCase) Then Return url

        Dim slash As Integer = url.LastIndexOf("/"c)
        Dim dir As String = If(slash >= 0, url.Substring(0, slash), "/Public/images/articoli")
        Dim candidate As String = dir.TrimEnd("/"c) & "/_" & fileName
        If VirtualFileExists(candidate) Then Return candidate

        Dim defaultCandidate As String = "/Public/images/articoli/_" & fileName
        If Not String.Equals(defaultCandidate, candidate, StringComparison.OrdinalIgnoreCase) AndAlso VirtualFileExists(defaultCandidate) Then Return defaultCandidate

        Return url
    End Function

    Private Function VirtualFileExists(ByVal virtualUrl As String) As Boolean
        Try
            If String.IsNullOrWhiteSpace(virtualUrl) Then Return False
            Dim probe As String = virtualUrl
            If probe.StartsWith("/", StringComparison.OrdinalIgnoreCase) Then probe = "~" & probe
            Dim physical As String = HostingEnvironment.MapPath(probe)
            Return Not String.IsNullOrWhiteSpace(physical) AndAlso File.Exists(physical)
        Catch
            Return False
        End Try
    End Function

    Private Function NormalizeMediaUrl(ByVal raw As Object) As String
        Dim value As String = SafeString(raw).Replace("\", "/")
        If String.IsNullOrWhiteSpace(value) Then Return String.Empty
        If value.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse value.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse value.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then Return value
        If value.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then Return ResolveUrl(value)
        If value.StartsWith("/", StringComparison.OrdinalIgnoreCase) Then Return value
        If value.IndexOf("/"c) >= 0 Then Return "/" & value.TrimStart("/"c)
        Return ResolveUrl("~/Public/images/articoli/" & value)
    End Function

    Private Function FormatPrice(ByVal value As Decimal) As String
        If value <= 0D Then Return String.Empty
        Return value.ToString("N2", ItCulture)
    End Function

    Private Function ReadInt(ByVal raw As Object, ByVal fallback As Integer) As Integer
        Dim n As Integer
        If Integer.TryParse(Convert.ToString(raw), NumberStyles.Integer, CultureInfo.InvariantCulture, n) Then Return n
        Return fallback
    End Function

    Private Function ParseDecimal(ByVal raw As String, ByVal fallback As Decimal) As Decimal
        Return ReadDecParam(raw, fallback)
    End Function

    Private Function ReadDecParam(ByVal raw As Object, ByVal fallback As Decimal) As Decimal
        Dim rawText As String = Convert.ToString(raw)
        Dim text As String = If(rawText, String.Empty).Trim()
        Dim n As Decimal
        If String.IsNullOrWhiteSpace(text) Then Return fallback
        If text.Contains(",") AndAlso (Not text.Contains(".") OrElse text.LastIndexOf(","c) > text.LastIndexOf("."c)) Then
            If Decimal.TryParse(text, NumberStyles.Any, ItCulture, n) Then Return Math.Round(n, 2, MidpointRounding.AwayFromZero)
        End If
        If Decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, n) Then Return Math.Round(n, 2, MidpointRounding.AwayFromZero)
        If Decimal.TryParse(text, NumberStyles.Any, ItCulture, n) Then Return Math.Round(n, 2, MidpointRounding.AwayFromZero)
        Return fallback
    End Function

    Private Function ReadDec(ByVal raw As Object, ByVal fallback As Decimal) As Decimal
        Return ReadDecParam(raw, fallback)
    End Function

    Private Function SafeString(ByVal raw As Object) As String
        Dim value As String = Convert.ToString(raw)
        Return If(value, String.Empty).Trim()
    End Function

    Private Function ExecuteQuery(ByVal sql As String, ByVal parameters As List(Of DbParameterSpec)) As DataTable
        Dim table As New DataTable()
        Dim factory As DbProviderFactory = Nothing
        Using conn As DbConnection = OpenConnection(factory)
            Using cmd As DbCommand = conn.CreateCommand()
                cmd.CommandText = sql
                cmd.CommandType = CommandType.Text
                AddParameters(cmd, parameters)
                Using reader As DbDataReader = cmd.ExecuteReader()
                    table.Load(reader)
                End Using
            End Using
        End Using
        Return table
    End Function

    Private Sub AddParameters(ByVal cmd As DbCommand, ByVal parameters As List(Of DbParameterSpec))
        If parameters Is Nothing Then Return
        For Each spec As DbParameterSpec In parameters
            Dim p As DbParameter = cmd.CreateParameter()
            p.ParameterName = spec.Name
            p.Value = If(spec.Value, DBNull.Value)
            cmd.Parameters.Add(p)
        Next
    End Sub

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
                If probe.Contains("uid=") OrElse probe.Contains("user id=") OrElse probe.Contains("port=") OrElse Convert.ToString(cs.ProviderName).ToLowerInvariant().Contains("mysql") Then Return cs
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

    Private Class DbParameterSpec
        Public Sub New(ByVal name As String, ByVal value As Object)
            Me.Name = name
            Me.Value = value
        End Sub
        Public Property Name As String
        Public Property Value As Object
    End Class
End Class
