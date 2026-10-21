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

    Private _commercial As SearchSuggestCommercialSupport
    Private Const DefaultLimit As Integer = 8
    Private Const MaxLimit As Integer = 96
    Private Const AiScoreThreshold As Integer = 1800
    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Private Class SearchFilters
        Public Property SettoreId As Integer
        Public Property CategoriaId As Integer
        Public Property TipologiaId As Integer
        Public Property GruppoId As Integer
        Public Property SottoGruppoId As Integer
        Public Property MarcaId As Integer
        Public Property CampaignId As Integer
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
        Public Property ExactMatches As Integer
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

        Response.TrySkipIisCustomErrors = True
        Response.SuppressFormsAuthenticationRedirect = True
        Try
            If Request.HttpMethod <> "GET" Then Throw New SearchSuggestCommercialException("method_not_allowed", 405)
            If String.Equals(Request.Headers("Sec-Fetch-Site"), "cross-site", StringComparison.OrdinalIgnoreCase) Then
                Throw New SearchSuggestCommercialException("forbidden", 403)
            End If
            _commercial = New SearchSuggestCommercialSupport(Context)
            Dim filters As SearchFilters = ReadFilters()
            Dim guided As Boolean = filters.Mode = "guided"
            Dim query As String = If(guided, ReadGuidedQuery(), NormalizeQuery(SafeRequestValue("q")))
            Dim limit As Integer = If(guided, ReadGuidedLimit(), Math.Max(1, Math.Min(MaxLimit, ReadInt(SafeRequestValue("limit"), DefaultLimit))))
            Dim recentIds As New List(Of Integer)()
            If Not guided Then
                recentIds = ParseIds(SafeRequestValue("recent"))
                If recentIds.Count = 0 Then recentIds = ParseIds(ReadCookieValue("ks_recent"))
            End If

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
        Catch ex As SearchSuggestCommercialException
            Response.StatusCode = ex.Status
            payload("ok") = False
            payload("code") = ex.Code
            payload("catalogUrl") = "articoli.aspx"
            payload("error") = "Contesto commerciale non disponibile. Continua nel catalogo."
        Catch ex As Exception
            Response.StatusCode = 503
            payload("code") = "commercial_unavailable"
            payload("catalogUrl") = "articoli.aspx"
            payload("ok") = False
            payload("error") = "Servizio suggerimenti temporaneamente non disponibile."
        End Try

        Dim serializer As New JavaScriptSerializer()
        serializer.MaxJsonLength = Integer.MaxValue
        Response.Write(serializer.Serialize(payload))
        If Context.ApplicationInstance IsNot Nothing Then Context.ApplicationInstance.CompleteRequest()
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
        output("catalogUrl") = BuildCatalogUrl(String.Empty, filters)
        output("total") = 0
        output("quickLinks") = BuildQuickLinks(String.Empty, New List(Of SuggestItem)(), Nothing)

        If recentIds Is Nothing OrElse recentIds.Count = 0 Then Return output

        Dim parameters As New List(Of SearchSuggestParameter)()
        Dim sql As New StringBuilder()
        AppendSelect(sql, False)
        sql.Append(_commercial.CatalogFrom() & " AND v.id IN (")
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
        output("quickLinks") = BuildQuickLinks(String.Empty, mapped, Nothing)
        Return output
    End Function

    Private Function BuildSearchResult(ByVal query As String, ByVal filters As SearchFilters, ByVal limit As Integer) As Dictionary(Of String, Object)
        ' Guided requests keep product words literal; only explicit filters constrain offers.
        Dim guided As Boolean = filters.Mode = "guided"
        If guided Then limit = Math.Min(6, limit)
        Dim intent As QueryIntent = If(guided,
            New QueryIntent With {.Original = query, .SearchText = query, .Tokens = ExtractTokens(query), .IntentName = "guided", .Summary = String.Empty},
            InterpretQuery(query))
        Dim aiMode As Boolean = String.Equals(Convert.ToString(filters.Mode), "ai", StringComparison.OrdinalIgnoreCase)
        If filters.MaxPrice <= 0D AndAlso intent.MaxPrice > 0D Then filters.MaxPrice = intent.MaxPrice
        If filters.MinPrice <= 0D AndAlso intent.MinPrice > 0D Then filters.MinPrice = intent.MinPrice
        If intent.WantsAvailable Then filters.SoloDisponibili = True
        If intent.WantsPromo Then filters.SoloPromo = True
        If intent.WantsRefurbished Then filters.SoloRicondizionati = True

        Dim tokens As List(Of String) = intent.Tokens
        If tokens.Count = 0 Then tokens = ExtractTokens(query)
        If tokens.Count = 0 Then tokens.Add(NormalizeSearchText(query))
        Dim scoringTokens As List(Of String) = ExpandSearchTokens(tokens, query)
        If scoringTokens.Count = 0 Then scoringTokens = tokens

        Dim parameters As New List(Of SearchSuggestParameter)()
        Dim normalizedQuery As String = If(guided, query, NormalizeQuery(intent.SearchText)).ToLowerInvariant()
        If String.IsNullOrWhiteSpace(normalizedQuery) Then normalizedQuery = NormalizeQuery(query).ToLowerInvariant()

        Dim likeQuery As String = EscapeLikeValue(normalizedQuery)
        parameters.Add(New SearchSuggestParameter("@qExact", normalizedQuery))
        parameters.Add(New SearchSuggestParameter("@qPrefix", likeQuery & "%"))
        parameters.Add(New SearchSuggestParameter("@qContains", "%" & likeQuery & "%"))
        parameters.Add(New SearchSuggestParameter("@qWord", "% " & likeQuery & "%"))

        For i As Integer = 0 To scoringTokens.Count - 1
            Dim tokenValue As String = scoringTokens(i)
            Dim likeToken As String = EscapeLikeValue(tokenValue)
            parameters.Add(New SearchSuggestParameter("@t" & i.ToString(CultureInfo.InvariantCulture), tokenValue))
            parameters.Add(New SearchSuggestParameter("@tc" & i.ToString(CultureInfo.InvariantCulture), "%" & likeToken & "%"))
            parameters.Add(New SearchSuggestParameter("@tp" & i.ToString(CultureInfo.InvariantCulture), likeToken & "%"))
            parameters.Add(New SearchSuggestParameter("@tw" & i.ToString(CultureInfo.InvariantCulture), "% " & likeToken & "%"))
        Next

        Dim sql As New StringBuilder()
        AppendSelect(sql, True, BuildScoreExpression(scoringTokens, intent))
        sql.Append(_commercial.CatalogFrom())
        sql.Append(" AND (")
        sql.Append("LOWER(COALESCE(v.Codice,'')) = @qExact OR LOWER(COALESCE(v.Ean,'')) = @qExact OR LOWER(COALESCE(v.Descrizione1,'')) = @qExact OR ")
        sql.Append("LOWER(COALESCE(v.Codice,'')) LIKE @qPrefix OR LOWER(COALESCE(v.Ean,'')) LIKE @qPrefix OR LOWER(COALESCE(v.Descrizione1,'')) LIKE @qPrefix OR ")
        sql.Append("LOWER(CONCAT(' ', COALESCE(v.Codice,''))) LIKE @qWord OR LOWER(CONCAT(' ', COALESCE(v.Ean,''))) LIKE @qWord OR LOWER(CONCAT(' ', COALESCE(v.Descrizione1,''))) LIKE @qWord OR ")
        sql.Append("LOWER(CONCAT(' ', COALESCE(v.MarcheDescrizione,''), ' ', COALESCE(v.Descrizione1,''))) LIKE @qWord OR ")
        sql.Append("LOWER(COALESCE(v.Descrizione1,'')) LIKE @qContains OR LOWER(COALESCE(v.Descrizione2,'')) LIKE @qContains OR LOWER(COALESCE(v.DescrizioneLunga,'')) LIKE @qContains OR LOWER(COALESCE(v.DescrizioneHTML,'')) LIKE @qContains OR ")
        sql.Append("LOWER(CONCAT(' ', COALESCE(v.MarcheDescrizione,''), ' ', COALESCE(v.SettoriDescrizione,''), ' ', COALESCE(v.CategorieDescrizione,''), ' ', COALESCE(v.TipologieDescrizione,''), ' ', COALESCE(v.GruppiDEscrizione,''), ' ', COALESCE(v.SottogruppiDescrIZione,''))) LIKE @qContains ")
        For i As Integer = 0 To scoringTokens.Count - 1
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
        If aiMode Then sql.Append(" AND (" & BuildScoreExpression(scoringTokens, intent) & ") >= " & AiScoreThreshold.ToString(CultureInfo.InvariantCulture))
        sql.Append(BuildOrderBy(filters))
        sql.Append(" LIMIT ")
        sql.Append(limit.ToString(CultureInfo.InvariantCulture))

        Dim table As DataTable = ExecuteQuery(sql.ToString(), parameters)
        Dim mapped As List(Of SuggestItem) = MapSuggestions(table, query, intent)
        If aiMode Then
            mapped = mapped.Where(Function(item) item.Score >= AiScoreThreshold OrElse _
                                                item.MatchKind.StartsWith("exact", StringComparison.OrdinalIgnoreCase) OrElse _
                                                item.MatchKind.StartsWith("prefix", StringComparison.OrdinalIgnoreCase)).ToList()
        End If
        mapped = mapped.Take(limit).ToList()

        Dim strong As New Dictionary(Of String, Object) From {{"canRedirect", False}, {"redirectUrl", String.Empty}, {"articleId", 0}, {"matchKind", String.Empty}}
        If mapped.Count = 1 AndAlso mapped(0).ExactMatches = 1 Then
            If mapped(0).MatchKind = "exact-code" OrElse mapped(0).MatchKind = "exact-ean" Then
                strong("canRedirect") = True
                strong("redirectUrl") = mapped(0).Url
                strong("articleId") = mapped(0).Id
                strong("matchKind") = mapped(0).MatchKind
            End If
        ElseIf mapped.Count > 1 AndAlso mapped(0).ExactMatches = 1 Then
            If (mapped(0).MatchKind = "exact-code" OrElse mapped(0).MatchKind = "exact-ean") AndAlso mapped(0).Score >= mapped(1).Score + 2000 Then
                strong("canRedirect") = True
                strong("redirectUrl") = mapped(0).Url
                strong("articleId") = mapped(0).Id
                strong("matchKind") = mapped(0).MatchKind
            End If
        End If

        Dim result As New Dictionary(Of String, Object) From {
            {"query", query},
            {"normalized_query", intent.SearchText},
            {"recent", False},
            {"suggestions", mapped.Select(Function(item) SerializeItem(item)).ToList()},
            {"rank_ids", mapped.Select(Function(item) item.Id).ToList()},
            {"facets", BuildFacets(mapped)},
            {"strong", strong},
            {"intelligence", SerializeIntent(intent, filters, mapped.Count)},
            {"mode", filters.Mode},
            {"expanded_tokens", scoringTokens},
            {"minimumScore", If(aiMode, AiScoreThreshold, 0)},
            {"total", mapped.Count},
            {"catalogUrl", BuildCatalogUrl(If(String.IsNullOrWhiteSpace(intent.SearchText), query, intent.SearchText), filters)},
            {"quickLinks", BuildQuickLinks(query, mapped, intent)}
        }
        If guided Then
            result("guided") = New Dictionary(Of String, Object) From {
                {"version", 1}, {"displayLabel", _commercial.PriceContext.DisplayLabel},
                {"returnedCount", mapped.Count}, {"selectionLimited", True}, {"limit", limit},
                {"criteria", New Dictionary(Of String, Object) From {
                    {"q", query}, {"st", filters.SettoreId},
                    {"pmin", filters.MinPrice.ToString("0.############################", CultureInfo.InvariantCulture)},
                    {"pmax", filters.MaxPrice.ToString("0.############################", CultureInfo.InvariantCulture)},
                    {"disponibile", filters.SoloDisponibili}, {"ordinamento", If(filters.Sort, String.Empty)}
                }}
            }
        End If
        Return result
    End Function

    Private Sub AppendSelect(ByVal sql As StringBuilder, ByVal includeRank As Boolean, Optional ByVal rankExpr As String = "")
        sql.Append("SELECT DISTINCT v.id, v.NListino AS SuggestPriceList, v.Codice, v.Ean, v.Descrizione1, v.Descrizione2, v.DescrizioneLunga, v.DescrizioneHTML, ")
        sql.Append("v.MarcheDescrizione, v.SettoriDescrizione, v.CategorieDescrizione, v.TipologieDescrizione, v.GruppiDEscrizione, v.SottogruppiDescrIZione, ")
        sql.Append("v.Img1, v.Img2, v.Img3, v.Img4, v.Immagine1, v.Immagine2, v.Immagine3, v.Immagine4, v.Immagine5, v.Immagine6, ")
        sql.Append("v.SuggestPrice AS PrezzoFinale, v.Prezzo, v.PrezzoIvato, v.IdIvaRC, v.ValoreIvaRC, v.Giacenza, v.Impegnata, v.InOrdine, v.ScortaMinima, v.SuggestMultiplicity, ")
        sql.Append("v.SuggestAvailable AS Disponibilita, v.SuggestOffer AS InOfferta, COALESCE(v.Vetrina,0) AS Vetrina, COALESCE(v.visite,0) AS Visite, ")
        sql.Append("COALESCE(v.Ricondizionato,0) AS Ricondizionato, COALESCE(v.NoteRicondizionato,'') AS NoteRicondizionato, 0 AS SpeditoGratis, v.SuggestTC AS TCid, v.DataCreazione ")
        If includeRank Then
            sql.Append(", ")
            sql.Append(If(String.IsNullOrWhiteSpace(rankExpr), "0", rankExpr))
            sql.Append(" AS RankScore, SUM(CASE WHEN LOWER(TRIM(COALESCE(v.Codice,'')))=@qExact OR LOWER(TRIM(COALESCE(v.Ean,'')))=@qExact THEN 1 ELSE 0 END) OVER() AS ExactMatches ")
            Return
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
        sb.Append("WHEN LOWER(CONCAT(' ', COALESCE(v.MarcheDescrizione,''), ' ', COALESCE(v.Descrizione1,''), ' ', COALESCE(v.Descrizione2,''))) LIKE @qContains THEN 4300000 ")
        sb.Append("WHEN LOWER(CONCAT(' ', COALESCE(v.SettoriDescrizione,''), ' ', COALESCE(v.CategorieDescrizione,''), ' ', COALESCE(v.TipologieDescrizione,''), ' ', COALESCE(v.Descrizione1,''))) LIKE @qContains THEN 3900000 ")
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
            sb.Append("WHEN LOWER(CONCAT(' ',COALESCE(v.SettoriDescrizione,''),' ',COALESCE(v.CategorieDescrizione,''),' ',COALESCE(v.TipologieDescrizione,''),' ',COALESCE(v.Descrizione1,''))) LIKE @tw").Append(n).Append(" THEN 5000 ")
            sb.Append("WHEN LOWER(CONCAT(' ',COALESCE(v.MarcheDescrizione,''),' ',COALESCE(v.Descrizione1,''),' ',COALESCE(v.Descrizione2,''))) LIKE @tc").Append(n).Append(" THEN 3600 ")
            sb.Append("WHEN LOWER(COALESCE(v.Descrizione1,'')) LIKE @tc").Append(n).Append(" THEN 2600 ")
            sb.Append("WHEN LOWER(COALESCE(v.DescrizioneLunga,'')) LIKE @tc").Append(n).Append(" THEN 1800 ")
            sb.Append("WHEN LOWER(COALESCE(v.MarcheDescrizione,'')) LIKE @tc").Append(n).Append(" THEN 1600 ")
            sb.Append("WHEN LOWER(CONCAT(' ',COALESCE(v.SettoriDescrizione,''),' ',COALESCE(v.CategorieDescrizione,''),' ',COALESCE(v.TipologieDescrizione,''),' ',COALESCE(v.GruppiDEscrizione,''),' ',COALESCE(v.SottogruppiDescrIZione,''))) LIKE @tc").Append(n).Append(" THEN 1500 ")
            sb.Append("ELSE 0 END)")
        Next
        ' Tie-breaker only: never let commercial boosts outrank textual relevance bands.
        sb.Append(" + (CASE WHEN v.SuggestAvailable > 0 THEN 600 ELSE 0 END)")
        sb.Append(" + (CASE WHEN v.SuggestOffer <> 0 THEN 450 ELSE 0 END)")
        sb.Append(" + (CASE WHEN COALESCE(v.Vetrina,0) <> 0 THEN 250 ELSE 0 END)")
        sb.Append(" + LEAST(COALESCE(v.visite,0),999)")
        sb.Append(")")
        Return sb.ToString()
    End Function

    Private Function BuildOrderBy(ByVal filters As SearchFilters) As String
        Dim sort As String = Convert.ToString(If(filters Is Nothing, String.Empty, filters.Sort)).ToLowerInvariant()
        Select Case sort
            Case "price-asc", "prezzo-asc", "p_basso"
                Return " ORDER BY (PrezzoFinale IS NULL OR PrezzoFinale<=0) ASC, PrezzoFinale ASC, RankScore DESC, v.SuggestAvailable DESC, v.id DESC"
            Case "price-desc", "prezzo-desc", "p_alto"
                Return " ORDER BY (PrezzoFinale IS NULL OR PrezzoFinale<=0) ASC, PrezzoFinale DESC, RankScore DESC, v.SuggestAvailable DESC, v.id DESC"
            Case "promo", "offerte", "p_offerta"
                Return " ORDER BY v.SuggestOffer DESC, RankScore DESC, PrezzoFinale ASC, v.SuggestAvailable DESC, v.id DESC"
            Case "available", "disponibili", "p_disponibilita"
                Return " ORDER BY v.SuggestAvailable DESC, RankScore DESC, PrezzoFinale ASC, v.SuggestOffer DESC, v.id DESC"
            Case "new", "novita", "p_recenti"
                Return " ORDER BY v.DataCreazione DESC, RankScore DESC, v.SuggestAvailable DESC, v.id DESC"
            Case Else
                Return " ORDER BY RankScore DESC, v.SuggestAvailable DESC, v.SuggestOffer DESC, COALESCE(v.Vetrina,0) DESC, COALESCE(v.visite,0) DESC, PrezzoFinale ASC, v.id DESC"
        End Select
    End Function

    Private Sub AppendFilterClauses(ByVal sql As StringBuilder, ByVal parameters As List(Of SearchSuggestParameter), ByVal filters As SearchFilters, ByVal aliasName As String)
        If filters Is Nothing Then Return
        Dim a As String = If(String.IsNullOrWhiteSpace(aliasName), String.Empty, aliasName.Trim() & ".")

        AppendIntFilter(sql, parameters, filters.SettoreId, a & "SettoriId", "@st")
        AppendIntFilter(sql, parameters, filters.CategoriaId, a & "CategorieId", "@ct")
        AppendIntFilter(sql, parameters, filters.TipologiaId, a & "TipologieId", "@tpfilter")
        AppendIntFilter(sql, parameters, filters.GruppoId, a & "GruppiId", "@gr")
        AppendIntFilter(sql, parameters, filters.SottoGruppoId, a & "SottoGrupPIId", "@sg")
        AppendIntFilter(sql, parameters, filters.MarcaId, a & "MarcheId", "@mr")

        _commercial.VerifyCandidateProjection(sql.ToString(), parameters)
        If filters.SoloPromo Then sql.Append(" AND " & a & "SuggestHasPromotion <> 0")
        If filters.SoloDisponibili Then sql.Append(" AND " & a & "SuggestAvailable > 0")
        If filters.SoloRicondizionati Then sql.Append(" AND COALESCE(" & a & "Ricondizionato,0) = 1")

        If filters.MinPrice > 0D Then
            sql.Append(" AND " & a & "SuggestPrice >= @minPrice")
            If parameters IsNot Nothing Then parameters.Add(New SearchSuggestParameter("@minPrice", filters.MinPrice))
        End If
        If filters.MaxPrice > 0D Then
            sql.Append(" AND " & a & "SuggestPrice <= @maxPrice")
            If parameters IsNot Nothing Then parameters.Add(New SearchSuggestParameter("@maxPrice", filters.MaxPrice))
        End If
    End Sub

    Private Sub AppendIntFilter(ByVal sql As StringBuilder, ByVal parameters As List(Of SearchSuggestParameter), ByVal value As Integer, ByVal fieldName As String, ByVal paramName As String)
        If value <= 0 Then Return
        sql.Append(" AND ")
        sql.Append(fieldName)
        sql.Append(" = ")
        sql.Append(paramName)
        If parameters IsNot Nothing Then parameters.Add(New SearchSuggestParameter(paramName, value))
    End Sub

    Private Function MapSuggestions(ByVal table As DataTable, ByVal query As String, ByVal intent As QueryIntent) As List(Of SuggestItem)
        Dim results As New List(Of SuggestItem)()
        If table Is Nothing Then Return results

        _commercial.VerifyRows(table)
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
            item.ExactMatches = If(table.Columns.Contains("ExactMatches"), ReadInt(row("ExactMatches"), 0), 0)
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
            item.IsRefurbished = ReadInt(row("Ricondizionato"), 0) = 1
            item.FreeShipping = If(row.Table.Columns.Contains("SpeditoGratis"), ReadInt(row("SpeditoGratis"), 0) <> 0, False)
            item.TcId = If(row.Table.Columns.Contains("TCid"), SafeString(row("TCid")), String.Empty)
            If ReadInt(item.TcId, -1) > 0 Then item.Url &= "&TCId=" & ReadInt(item.TcId, -1).ToString(CultureInfo.InvariantCulture)
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
            {"id", item.Id}, {"TCId", ReadInt(item.TcId, -1)}, {"url", item.Url}, {"title", item.Title}, {"description", item.Description},
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
        If intent IsNot Nothing AndAlso intent.Tokens IsNot Nothing AndAlso intent.Tokens.Count > 0 Then
            parts.Add("termini: " & String.Join(", ", intent.Tokens.Take(3).ToArray()))
        End If
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
            If filters.CampaignId > 0 Then args.Add("pid=" & filters.CampaignId.ToString(CultureInfo.InvariantCulture))
            If filters.SoloDisponibili Then args.Add("disponibile=1")
            If filters.SoloRicondizionati Then args.Add("ricondizionato=1")
            If filters.MinPrice > 0D Then args.Add("pmin=" & filters.MinPrice.ToString(CultureInfo.InvariantCulture))
            If filters.MaxPrice > 0D Then args.Add("pmax=" & filters.MaxPrice.ToString(CultureInfo.InvariantCulture))
            If Not String.IsNullOrWhiteSpace(filters.Sort) Then args.Add("ordinamento=" & HttpUtility.UrlEncode(CatalogSort(filters.Sort)))
        End If
        If args.Count > 0 Then url.Append("?").Append(String.Join("&", args))
        Return url.ToString()
    End Function

    Private Function EmptyFacets() As Dictionary(Of String, Object)
        Return New Dictionary(Of String, Object) From {{"brands", New List(Of Object)()}, {"categories", New List(Of Object)()}}
    End Function

    Private Function SerializeIntent(ByVal intent As QueryIntent, ByVal filters As SearchFilters, ByVal count As Integer) As Dictionary(Of String, Object)
        Dim summary As String = "Ho interpretato la richiesta come ricerca " & intent.IntentName & "."
        If intent.MaxPrice > 0D OrElse filters.MaxPrice > 0D Then summary &= " Budget massimo: " & UiPriceFormatter.FormatStorefrontAmount(If(filters.MaxPrice > 0D, filters.MaxPrice, intent.MaxPrice), 0) & "."
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
        Dim stopWords As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {"il", "la", "lo", "le", "gli", "un", "una", "uno", "di", "da", "a", "e", "o", "in", "con", "per", "del", "della", "dello", "dei", "degli", "prodotto", "prodotti", "cerca", "cerco", "trova", "voglio", "serve", "servono", "mi", "hai", "avete", "buon", "buona", "economico", "economica"}
        Return normalized.Split(" "c).Select(Function(t) t.Trim()).Where(Function(t) t.Length >= 2 AndAlso Not stopWords.Contains(t)).Distinct(StringComparer.OrdinalIgnoreCase).Take(8).ToList()
    End Function

    Private Function ExpandSearchTokens(ByVal tokens As List(Of String), ByVal raw As String) As List(Of String)
        Dim expanded As New List(Of String)()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim source As New List(Of String)()

        If tokens IsNot Nothing Then source.AddRange(tokens)
        source.AddRange(ExtractTokens(raw))

        For Each token As String In source
            AddExpandedToken(expanded, seen, token)
            AddExpandedToken(expanded, seen, SingularizeToken(token))
            For Each synonym As String In SearchSynonyms(token)
                AddExpandedToken(expanded, seen, synonym)
            Next
        Next

        Return expanded.Take(18).ToList()
    End Function

    Private Sub AddExpandedToken(ByVal target As List(Of String), ByVal seen As HashSet(Of String), ByVal value As String)
        If target Is Nothing OrElse seen Is Nothing Then Return
        Dim token As String = NormalizeSearchText(value)
        If token.Length < 2 Then Return
        If seen.Contains(token) Then Return
        seen.Add(token)
        target.Add(token)
    End Sub

    Private Function SingularizeToken(ByVal value As String) As String
        Dim token As String = NormalizeSearchText(value)
        If token.Length > 4 AndAlso (token.EndsWith("i", StringComparison.OrdinalIgnoreCase) OrElse token.EndsWith("e", StringComparison.OrdinalIgnoreCase)) Then
            Return token.Substring(0, token.Length - 1)
        End If
        Return token
    End Function

    Private Function SearchSynonyms(ByVal value As String) As List(Of String)
        Dim token As String = NormalizeSearchText(value)
        Dim result As New List(Of String)()

        Select Case token
            Case "smartphone", "cellulare", "cellulari", "telefono", "telefoni", "telefonia"
                result.AddRange(New String() {"smartphone", "cellulare", "telefono", "galaxy", "iphone", "android"})
            Case "pc", "computer", "desktop"
                result.AddRange(New String() {"pc", "computer", "desktop", "tower"})
            Case "portatile", "portatili", "notebook", "laptop"
                result.AddRange(New String() {"notebook", "portatile", "laptop", "computer"})
            Case "monitor", "schermo", "display"
                result.AddRange(New String() {"monitor", "schermo", "display"})
            Case "gaming", "gamer"
                result.AddRange(New String() {"gaming", "gamer", "game"})
            Case "toner", "cartuccia", "cartucce", "inchiostro", "drum", "tamburo"
                result.AddRange(New String() {"toner", "cartuccia", "inchiostro", "drum", "tamburo", "stampante"})
            Case "stampante", "stampanti", "printer", "ufficio"
                result.AddRange(New String() {"stampante", "printer", "toner", "cartuccia", "laser"})
            Case "cavo", "cavi"
                result.AddRange(New String() {"cavo", "hdmi", "usb", "type c", "usb c", "adattatore"})
            Case "usb", "usb c", "type c", "typec"
                result.AddRange(New String() {"usb", "usb c", "type c", "adattatore", "hub"})
            Case "hdmi"
                result.AddRange(New String() {"hdmi", "cavo", "adattatore"})
            Case "alimentatore", "caricatore", "charger", "power"
                result.AddRange(New String() {"alimentatore", "caricatore", "charger", "power", "usb c"})
            Case "ricondizionato", "ricondizionati", "refurbished", "usato"
                result.AddRange(New String() {"ricondizionato", "ricondizionati", "refurbished", "usato", "garantito"})
            Case "memoria", "ram", "storage", "archiviazione"
                result.AddRange(New String() {"memoria", "ram", "gb", "storage", "ssd", "archiviazione"})
        End Select

        Return result
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
        Dim modes As String() = Request.QueryString.GetValues("mode")
        If modes IsNot Nothing AndAlso modes.Any(Function(value) String.Equals(value, "guided", StringComparison.OrdinalIgnoreCase)) Then
            Return ReadGuidedFilters()
        End If
        Dim minimum As String = ReadAliasedFilter(AddressOf NormalizePriceFilter, "pmin", "min")
        Dim maximum As String = ReadAliasedFilter(AddressOf NormalizePriceFilter, "pmax", "max")
        Dim filters As New SearchFilters() With {
            .SettoreId = ReadInt(SafeRequestValue("st"), 0),
            .CategoriaId = ReadInt(SafeRequestValue("ct"), 0),
            .TipologiaId = ReadInt(SafeRequestValue("tp"), 0),
            .GruppoId = ReadInt(SafeRequestValue("gr"), 0),
            .SottoGruppoId = ReadInt(SafeRequestValue("sg"), 0),
            .MarcaId = ReadInt(SafeRequestValue("mr"), 0),
            .CampaignId = ReadInt(SafeRequestValue("pid"), 0),
            .SoloPromo = (ReadInt(SafeRequestValue("inpromo"), 0) <> 0 OrElse ReadInt(SafeRequestValue("promo"), 0) <> 0 OrElse ReadInt(SafeRequestValue("pid"), 0) > 0),
            .SoloDisponibili = (ReadAliasedFilter(AddressOf NormalizeAvailabilityFilter, "disponibile", "available", "disponibili") = "1"),
            .SoloRicondizionati = (ReadInt(SafeRequestValue("refurbished"), 0) <> 0 OrElse ReadInt(SafeRequestValue("ricondizionato"), 0) <> 0),
            .MinPrice = If(minimum.Length = 0, 0D, Decimal.Parse(minimum, CultureInfo.InvariantCulture)),
            .MaxPrice = If(maximum.Length = 0, 0D, Decimal.Parse(maximum, CultureInfo.InvariantCulture)),
            .Sort = ReadAliasedFilter(AddressOf NormalizeSortFilter, "ordinamento", "sort"),
            .Mode = SafeRequestValue("mode")
        }
        If filters.MinPrice > 0D AndAlso filters.MaxPrice > 0D AndAlso filters.MinPrice > filters.MaxPrice Then
            Throw New SearchSuggestCommercialException("invalid_filters", 400)
        End If
        Return filters
    End Function

    Private Function ReadGuidedQuery() As String
        Dim value As String = Regex.Replace(If(Request.QueryString("q"), String.Empty), "[\x00-\x1f\x7f\s]+", " ").Trim()
        If value.Length < 2 OrElse value.Length > 80 Then Throw New SearchSuggestCommercialException("invalid_query", 400)
        Return value
    End Function

    Private Function ReadGuidedLimit() As Integer
        Dim raw As String = Request.QueryString("limit")
        If raw Is Nothing Then Return 6
        Dim value As Integer
        If Not Regex.IsMatch(raw, "^[1-6]$") OrElse Not Integer.TryParse(raw, value) Then Throw New SearchSuggestCommercialException("invalid_filters", 400)
        Return value
    End Function

    Private Function ReadGuidedFilters() As SearchFilters
        Dim allowed As New HashSet(Of String)(StringComparer.Ordinal) From {"q", "st", "pmin", "pmax", "disponibile", "ordinamento", "limit", "mode"}
        For Each key As String In Request.QueryString.AllKeys
            If key Is Nothing OrElse Not allowed.Contains(key) OrElse Request.QueryString.GetValues(key).Length <> 1 Then
                Throw New SearchSuggestCommercialException("invalid_filters", 400)
            End If
        Next
        ReadGuidedQuery()
        ReadGuidedLimit()
        Dim sector As Integer = 0
        Dim rawSector As String = Request.QueryString("st")
        If rawSector IsNot Nothing AndAlso (Not Regex.IsMatch(rawSector, "^[1-9][0-9]{0,9}$") OrElse Not Integer.TryParse(rawSector, sector)) Then
            Throw New SearchSuggestCommercialException("invalid_filters", 400)
        End If
        Dim minimum As String = ReadAliasedFilter(AddressOf NormalizePriceFilter, "pmin")
        Dim maximum As String = ReadAliasedFilter(AddressOf NormalizePriceFilter, "pmax")
        Dim sort As String = If(Request.QueryString("ordinamento"), String.Empty)
        If sort <> String.Empty AndAlso sort <> "p_basso" Then Throw New SearchSuggestCommercialException("invalid_filters", 400)
        Dim filters As New SearchFilters With {
            .Mode = "guided", .SettoreId = sector, .Sort = sort,
            .SoloDisponibili = ReadAliasedFilter(AddressOf NormalizeAvailabilityFilter, "disponibile") = "1",
            .MinPrice = If(minimum.Length = 0, 0D, Decimal.Parse(minimum, CultureInfo.InvariantCulture)),
            .MaxPrice = If(maximum.Length = 0, 0D, Decimal.Parse(maximum, CultureInfo.InvariantCulture))
        }
        If filters.MinPrice > 0D AndAlso filters.MaxPrice > 0D AndAlso filters.MinPrice > filters.MaxPrice Then Throw New SearchSuggestCommercialException("invalid_filters", 400)
        Return filters
    End Function

    Private Function ReadAliasedFilter(ByVal normalize As Func(Of String, String), ParamArray keys As String()) As String
        Dim selected As String = Nothing
        For Each key As String In keys
            Dim values As String() = Request.QueryString.GetValues(key)
            If values Is Nothing Then Continue For
            For Each value As String In values
                If String.IsNullOrWhiteSpace(value) Then Continue For
                Dim effective As String = normalize(value.Trim())
                If selected IsNot Nothing AndAlso Not String.Equals(selected, effective, StringComparison.Ordinal) Then
                    Throw New SearchSuggestCommercialException("invalid_filters", 400)
                End If
                selected = effective
            Next
        Next
        Return If(selected, String.Empty)
    End Function

    Private Function NormalizeAvailabilityFilter(ByVal raw As String) As String
        If raw <> "0" AndAlso raw <> "1" Then
            Throw New SearchSuggestCommercialException("invalid_filters", 400)
        End If
        Return raw
    End Function

    Private Function NormalizePriceFilter(ByVal raw As String) As String
        Dim value As Decimal
        If raw.Length > 64 OrElse Not Regex.IsMatch(raw, "^[0-9]+(?:[.,][0-9]+)?$", RegexOptions.CultureInvariant) OrElse
           Not Decimal.TryParse(raw.Replace(",", "."), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, value) Then
            Throw New SearchSuggestCommercialException("invalid_filters", 400)
        End If
        Return value.ToString("0.############################", CultureInfo.InvariantCulture)
    End Function

    Private Function NormalizeSortFilter(ByVal raw As String) As String
        Select Case raw.ToLowerInvariant()
            Case "price-asc", "prezzo-asc", "p_basso", "price-desc", "prezzo-desc", "p_alto",
                 "promo", "offerte", "p_offerta", "new", "novita", "p_recenti",
                 "available", "disponibili", "p_disponibilita", "popularity", "p_popolarita"
                Return CatalogSort(raw)
            Case Else
                Throw New SearchSuggestCommercialException("invalid_filters", 400)
        End Select
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
        Return If(text.Length > 80, text.Substring(0, 80).Trim(), text)
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
        Return ThemeManager.ProductThumbnailImageUrl(raw)
    End Function

    Private Function NormalizeMediaUrl(ByVal raw As Object) As String
        Return ThemeManager.ProductImageUrl(raw)
    End Function

    Private Function BuildQuickLinks(ByVal query As String, ByVal items As List(Of SuggestItem), ByVal intent As QueryIntent) As List(Of Dictionary(Of String, Object))
        Dim output As New List(Of Dictionary(Of String, Object))()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

        If intent IsNot Nothing AndAlso intent.Tokens IsNot Nothing Then
            For Each token As String In intent.Tokens.Take(4)
                AddQuickLink(output, seen, token, "articoli.aspx?q=" & HttpUtility.UrlEncode(token))
            Next
        End If

        If items IsNot Nothing Then
            For Each item As SuggestItem In items
                If item Is Nothing Then Continue For
                If Not String.IsNullOrWhiteSpace(item.Brand) AndAlso Not String.IsNullOrWhiteSpace(item.Category) Then
                    AddQuickLink(output, seen, item.Brand & " " & item.Category, "articoli.aspx?q=" & HttpUtility.UrlEncode(item.Brand & " " & item.Category))
                End If
                If Not String.IsNullOrWhiteSpace(item.Department) Then
                    AddQuickLink(output, seen, item.Department, "articoli.aspx?q=" & HttpUtility.UrlEncode(item.Department))
                End If
                If Not String.IsNullOrWhiteSpace(item.Category) Then
                    AddQuickLink(output, seen, item.Category, "articoli.aspx?q=" & HttpUtility.UrlEncode(item.Category))
                End If
                If output.Count >= 8 Then Exit For
            Next
        End If

        If output.Count < 6 Then
            For Each item As Dictionary(Of String, String) In LoadPopularQuickLinks(8 - output.Count)
                AddQuickLink(output, seen, item("label"), item("url"))
            Next
        End If

        Return output.Take(8).ToList()
    End Function

    Private Sub AddQuickLink(ByVal output As List(Of Dictionary(Of String, Object)), ByVal seen As HashSet(Of String), ByVal label As String, ByVal url As String)
        Dim text As String = NormalizeQuery(label)
        If String.IsNullOrWhiteSpace(text) OrElse text.Length < 2 Then Return
        If seen.Contains(text) Then Return
        seen.Add(text)
        output.Add(New Dictionary(Of String, Object) From {
            {"label", text},
            {"url", If(String.IsNullOrWhiteSpace(url), "articoli.aspx?q=" & HttpUtility.UrlEncode(text), url)}
        })
    End Sub

    Private Function LoadPopularQuickLinks(ByVal limit As Integer) As List(Of Dictionary(Of String, String))
        ' Empty/recent requests may always reach the real catalog; no invented
        ' sector examples and no second unverified commercial query.
        Return New List(Of Dictionary(Of String, String))()
    End Function

    Private Function CatalogSort(ByVal sort As String) As String
        Select Case Convert.ToString(sort).ToLowerInvariant()
            Case "price-asc", "prezzo-asc", "p_basso" : Return "p_basso"
            Case "price-desc", "prezzo-desc", "p_alto" : Return "p_alto"
            Case "promo", "offerte", "p_offerta" : Return "p_offerta"
            Case "new", "novita", "p_recenti" : Return "p_recenti"
            Case "available", "disponibili", "p_disponibilita" : Return "p_disponibilita"
            Case Else : Return "p_popolarita"
        End Select
    End Function

    Private Function FormatPrice(ByVal value As Decimal) As String
        If value <= 0D Then Return String.Empty
        Return UiPriceFormatter.FormatStorefrontAmount(value)
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

    Private Function ExecuteQuery(ByVal sql As String, ByVal parameters As List(Of SearchSuggestParameter)) As DataTable
        Return _commercial.Execute(sql, parameters)
    End Function
End Class
