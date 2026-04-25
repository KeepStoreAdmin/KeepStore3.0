<%@ WebHandler Language="VB" Class="KsAiCatalogSearch" %>

Imports System
Imports System.Web
Imports System.Web.SessionState
Imports System.Web.Script.Serialization
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Data
Imports MySql.Data.MySqlClient

Public Class KsAiCatalogSearch
    Implements IHttpHandler, IReadOnlySessionState

    Private Const DefaultLimit As Integer = 12
    Private Const MaxLimit As Integer = 36

    Public ReadOnly Property IsReusable As Boolean Implements IHttpHandler.IsReusable
        Get
            Return False
        End Get
    End Property

    Public Sub ProcessRequest(ByVal context As HttpContext) Implements IHttpHandler.ProcessRequest
        context.Response.ContentType = "application/json; charset=utf-8"
        context.Response.Cache.SetCacheability(HttpCacheability.NoCache)
        context.Response.Cache.SetNoStore()

        Dim serializer As New JavaScriptSerializer()
        serializer.MaxJsonLength = 4194304

        Try
            Dim rawQuery As String = CleanQuery(Convert.ToString(context.Request("q")))
            If String.IsNullOrEmpty(rawQuery) Then rawQuery = "catalogo KeepStore"

            Dim limit As Integer = SafeInt(context.Request("limit"), DefaultLimit)
            If limit < 1 Then limit = DefaultLimit
            If limit > MaxLimit Then limit = MaxLimit

            Dim nListino As Integer = SafeInt(GetSessionValue(context, "NListino"), 1)
            If nListino <= 0 Then nListino = 1

            Dim ivaTipo As Integer = SafeInt(GetSessionValue(context, "IvaTipo"), 2)
            Dim sortMode As String = SafeSort(Convert.ToString(context.Request("sort")))
            Dim explicitPriceMin As Nullable(Of Decimal) = RequestDecimal(context, "priceMin")
            Dim explicitPriceMax As Nullable(Of Decimal) = RequestDecimal(context, "priceMax")
            Dim queryBudgetMax As Nullable(Of Decimal) = ExtractBudgetMax(rawQuery)
            Dim priceMax As Nullable(Of Decimal) = explicitPriceMax
            If Not priceMax.HasValue AndAlso queryBudgetMax.HasValue Then priceMax = queryBudgetMax

            Dim filterInStock As Boolean = RequestFlag(context, "inStock") OrElse ContainsAny(Norm(rawQuery), New String() {"disponibile", "disponibili", "pronta consegna", "magazzino"})
            Dim filterPromo As Boolean = RequestFlag(context, "promo") OrElse ContainsAny(Norm(rawQuery), New String() {"offerta", "offerte", "promo", "sconto", "scontato"})
            Dim filterRefurbished As Boolean = RequestFlag(context, "refurbished") OrElse ContainsAny(Norm(rawQuery), New String() {"ricondizionato", "ricondizionati", "usato", "usati"})
            Dim brandFilter As String = CleanShort(Convert.ToString(context.Request("brand")), 60)
            Dim categoryFilter As String = CleanShort(Convert.ToString(context.Request("category")), 80)

            Dim terms As List(Of String) = Tokenize(rawQuery)
            Dim intentTags As List(Of String) = DetectIntentTags(rawQuery)
            Dim candidateLimit As Integer = Math.Max(limit * 7, 80)

            Dim candidates As List(Of CatalogCandidate) = SearchCatalog(context, rawQuery, terms, nListino, ivaTipo, explicitPriceMin, priceMax, filterInStock, filterPromo, filterRefurbished, brandFilter, categoryFilter, candidateLimit, True)
            If candidates.Count = 0 AndAlso terms.Count > 1 Then
                candidates = SearchCatalog(context, rawQuery, terms, nListino, ivaTipo, explicitPriceMin, priceMax, filterInStock, filterPromo, filterRefurbished, brandFilter, categoryFilter, Math.Max(candidateLimit, 120), False)
            End If

            SortCandidates(candidates, sortMode)

            Dim output As New List(Of Dictionary(Of String, Object))()
            Dim seen As New Dictionary(Of String, Boolean)(StringComparer.OrdinalIgnoreCase)
            For Each c As CatalogCandidate In candidates
                Dim key As String = Convert.ToString(c.Item("id"))
                If Not seen.ContainsKey(key) Then
                    seen(key) = True
                    output.Add(c.Item)
                    If output.Count >= limit Then Exit For
                End If
            Next

            Dim parsed As New Dictionary(Of String, Object)()
            parsed("terms") = terms
            parsed("intentTags") = intentTags
            parsed("sort") = sortMode
            parsed("priceMin") = If(explicitPriceMin.HasValue, CType(explicitPriceMin.Value, Object), Nothing)
            parsed("priceMax") = If(priceMax.HasValue, CType(priceMax.Value, Object), Nothing)
            parsed("inStock") = filterInStock
            parsed("promo") = filterPromo
            parsed("refurbished") = filterRefurbished
            parsed("brand") = brandFilter
            parsed("category") = categoryFilter

            Dim payload As New Dictionary(Of String, Object)()
            payload("ok") = True
            payload("mode") = "marketplace"
            payload("query") = rawQuery
            payload("count") = output.Count
            payload("candidateCount") = candidates.Count
            payload("nListino") = nListino
            payload("parsed") = parsed
            payload("facets") = BuildFacets(candidates)
            payload("suggestions") = BuildSuggestions(rawQuery, intentTags, output)
            payload("summary") = BuildSummary(rawQuery, intentTags, output.Count, priceMax, filterInStock, filterPromo, filterRefurbished)
            payload("items") = output
            context.Response.Write(serializer.Serialize(payload))
        Catch ex As Exception
            context.Response.StatusCode = 200
            Dim payload As New Dictionary(Of String, Object)()
            payload("ok") = False
            payload("mode") = "marketplace"
            payload("error") = "Catalog marketplace search unavailable"
            payload("items") = New List(Of Dictionary(Of String, Object))()
            context.Response.Write(serializer.Serialize(payload))
        End Try
    End Sub

    Private Function SearchCatalog(ByVal context As HttpContext, ByVal rawQuery As String, ByVal terms As List(Of String), ByVal nListino As Integer, ByVal ivaTipo As Integer, ByVal priceMin As Nullable(Of Decimal), ByVal priceMax As Nullable(Of Decimal), ByVal filterInStock As Boolean, ByVal filterPromo As Boolean, ByVal filterRefurbished As Boolean, ByVal brandFilter As String, ByVal categoryFilter As String, ByVal candidateLimit As Integer, ByVal requireAllTerms As Boolean) As List(Of CatalogCandidate)
        Dim candidates As New List(Of CatalogCandidate)()
        Dim cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If cs Is Nothing OrElse String.IsNullOrEmpty(cs.ConnectionString) Then Return candidates

        Using conn As New MySqlConnection(cs.ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text
                cmd.CommandText = BuildSql(terms, filterInStock, filterPromo, filterRefurbished, brandFilter, categoryFilter, requireAllTerms, candidateLimit)
                cmd.Parameters.AddWithValue("@NListino", nListino)
                For i As Integer = 0 To terms.Count - 1
                    cmd.Parameters.AddWithValue("@t" & i.ToString(), "%" & terms(i) & "%")
                Next
                If Not String.IsNullOrEmpty(brandFilter) Then cmd.Parameters.AddWithValue("@brand", "%" & brandFilter & "%")
                If Not String.IsNullOrEmpty(categoryFilter) Then cmd.Parameters.AddWithValue("@category", "%" & categoryFilter & "%")

                Using rd As MySqlDataReader = cmd.ExecuteReader(CommandBehavior.CloseConnection)
                    While rd.Read()
                        Dim title As String = FieldText(rd, "Descrizione1")
                        If String.IsNullOrEmpty(title) Then Continue While

                        Dim id As Integer = FieldInt(rd, "id", 0)
                        If id <= 0 Then Continue While

                        Dim priceValue As Decimal = EffectivePrice(rd, ivaTipo)
                        If priceMin.HasValue AndAlso priceValue > 0D AndAlso priceValue < priceMin.Value Then Continue While
                        If priceMax.HasValue AndAlso priceValue > 0D AndAlso priceValue > priceMax.Value * 1.35D Then Continue While

                        Dim score As Integer = ScoreRow(rd, rawQuery, terms, priceMin, priceMax, priceValue, filterInStock, filterPromo, filterRefurbished)
                        If score <= 0 AndAlso terms.Count > 0 Then Continue While

                        Dim tcid As Integer = FieldInt(rd, "TCid", -1)
                        Dim item As New Dictionary(Of String, Object)()
                        item("id") = id
                        item("tcid") = tcid
                        item("title") = title
                        item("description") = ShortText(HtmlToText(FieldText(rd, "Descrizione2") & " " & FieldText(rd, "DescrizioneLunga") & " " & FieldText(rd, "DescrizioneHTML")), 190)
                        item("code") = FieldText(rd, "Codice")
                        item("ean") = FieldText(rd, "Ean")
                        item("brand") = FieldText(rd, "MarcheDescrizione")
                        item("sector") = FieldText(rd, "SettoriDescrizione")
                        item("category") = BestCategory(rd)
                        item("group") = FieldText(rd, "GruppiDescrizione")
                        item("subgroup") = FieldText(rd, "SottogruppiDescrizione")
                        item("availability") = FieldDecimal(rd, "Disponibilita", 0D)
                        item("stock") = FieldDecimal(rd, "Giacenza", 0D)
                        item("reconditioned") = (FieldInt(rd, "Ricondizionato", 0) = 1)
                        item("promo") = (FieldInt(rd, "InOfferta", 0) = 1)
                        item("freeShipping") = (FieldInt(rd, "SpeditoGratis", 0) = 1)
                        item("priceValue") = priceValue
                        item("price") = FormatEuro(priceValue)
                        item("imageUrl") = NormalizeImage(FieldText(rd, "Img1"))
                        item("url") = ProductUrl(id, tcid)
                        item("reason") = ReasonFor(rd, rawQuery, terms, priceMin, priceMax, priceValue)
                        item("badges") = BadgesFor(rd, priceMin, priceMax, priceValue)
                        item("score") = score
                        item("visits") = FieldInt(rd, "visite", 0)
                        item("created") = FieldText(rd, "DataCreazione")

                        candidates.Add(New CatalogCandidate(score, priceValue, FieldDecimal(rd, "Disponibilita", 0D), FieldInt(rd, "InOfferta", 0), FieldDate(rd, "DataCreazione"), item))
                    End While
                End Using
            End Using
        End Using

        Return candidates
    End Function

    Private Function BuildSql(ByVal terms As List(Of String), ByVal filterInStock As Boolean, ByVal filterPromo As Boolean, ByVal filterRefurbished As Boolean, ByVal brandFilter As String, ByVal categoryFilter As String, ByVal requireAllTerms As Boolean, ByVal candidateLimit As Integer) As String
        Dim fields As String = "COALESCE(Descrizione1,''), COALESCE(Descrizione2,''), COALESCE(DescrizioneLunga,''), COALESCE(DescrizioneHTML,''), COALESCE(Codice,''), COALESCE(Ean,''), COALESCE(MarcheDescrizione,''), COALESCE(SettoriDescrizione,''), COALESCE(CategorieDescrizione,''), COALESCE(TipologieDescrizione,''), COALESCE(GruppiDEscrizione,''), COALESCE(SottogruppiDescrIZione,'')"
        Dim sql As New System.Text.StringBuilder()
        sql.Append("SELECT id, Codice, Ean, Descrizione1, Descrizione2, DescrizioneLunga, DescrizioneHTML, Vetrina, MarcheDescrizione, SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, GruppiDEscrizione AS GruppiDescrizione, SottogruppiDescrIZione AS SottogruppiDescrizione, Img1, Img2, Img3, Img4, DataCreazione, visite, Export, Ricondizionato, NoteRicondizionato, Giacenza, Disponibilita, Impegnata, TCid, NListino, Prezzo, PrezzoIvato, SpeditoGratis, InOfferta, PrezzoPromo, PrezzoPromoIvato ")
        sql.Append("FROM vsuperarticoli WHERE id > 0 AND NListino = @NListino AND IFNULL(Export,0) = 1 AND IFNULL(Descrizione1,'') <> '' ")

        If terms IsNot Nothing AndAlso terms.Count > 0 Then
            If requireAllTerms Then
                For i As Integer = 0 To terms.Count - 1
                    sql.Append(" AND CONCAT_WS(' ', ").Append(fields).Append(") LIKE @t").Append(i.ToString()).Append(" ")
                Next
            Else
                sql.Append(" AND (")
                For i As Integer = 0 To terms.Count - 1
                    If i > 0 Then sql.Append(" OR ")
                    sql.Append("CONCAT_WS(' ', ").Append(fields).Append(") LIKE @t").Append(i.ToString())
                Next
                sql.Append(") ")
            End If
        Else
            sql.Append(" AND (IFNULL(Vetrina,0)=1 OR IFNULL(InOfferta,0)=1 OR IFNULL(Disponibilita,0)>0) ")
        End If

        If filterInStock Then sql.Append(" AND IFNULL(Disponibilita,0) > 0 ")
        If filterPromo Then sql.Append(" AND IFNULL(InOfferta,0) = 1 ")
        If filterRefurbished Then sql.Append(" AND IFNULL(Ricondizionato,0) = 1 ")
        If Not String.IsNullOrEmpty(brandFilter) Then sql.Append(" AND IFNULL(MarcheDescrizione,'') LIKE @brand ")
        If Not String.IsNullOrEmpty(categoryFilter) Then
            sql.Append(" AND CONCAT_WS(' ', COALESCE(SettoriDescrizione,''), COALESCE(CategorieDescrizione,''), COALESCE(TipologieDescrizione,''), COALESCE(GruppiDEscrizione,''), COALESCE(SottogruppiDescrIZione,'')) LIKE @category ")
        End If

        sql.Append("ORDER BY IFNULL(InOfferta,0) DESC, IFNULL(Disponibilita,0) DESC, IFNULL(Vetrina,0) DESC, IFNULL(visite,0) DESC, DataCreazione DESC, id DESC ")
        sql.Append("LIMIT ").Append(Math.Max(1, Math.Min(candidateLimit, 180)).ToString())
        Return sql.ToString()
    End Function

    Private Function ScoreRow(ByVal rd As MySqlDataReader, ByVal rawQuery As String, ByVal terms As List(Of String), ByVal priceMin As Nullable(Of Decimal), ByVal priceMax As Nullable(Of Decimal), ByVal priceValue As Decimal, ByVal filterInStock As Boolean, ByVal filterPromo As Boolean, ByVal filterRefurbished As Boolean) As Integer
        Dim title As String = FieldText(rd, "Descrizione1")
        Dim code As String = FieldText(rd, "Codice")
        Dim ean As String = FieldText(rd, "Ean")
        Dim hayTitle As String = Norm(title)
        Dim hayCode As String = Norm(code & " " & ean)
        Dim hayTax As String = Norm(FieldText(rd, "MarcheDescrizione") & " " & FieldText(rd, "SettoriDescrizione") & " " & FieldText(rd, "CategorieDescrizione") & " " & FieldText(rd, "TipologieDescrizione") & " " & FieldText(rd, "GruppiDescrizione") & " " & FieldText(rd, "SottogruppiDescrizione"))
        Dim hayDesc As String = Norm(FieldText(rd, "Descrizione2") & " " & FieldText(rd, "DescrizioneLunga") & " " & HtmlToText(FieldText(rd, "DescrizioneHTML")) & " " & FieldText(rd, "NoteRicondizionato"))
        Dim raw As String = Norm(rawQuery)
        Dim score As Integer = 0

        If raw.Length > 2 Then
            If Norm(code) = raw OrElse Norm(ean) = raw Then score += 140
            If hayTitle = raw Then score += 100
            If hayTitle.Contains(raw) Then score += 68
            If hayDesc.Contains(raw) Then score += 36
        End If

        For Each term As String In terms
            If Norm(code) = term OrElse Norm(ean) = term Then score += 70
            If hayTitle.StartsWith(term & " ") OrElse hayTitle.Contains(" " & term & " ") Then score += 28
            If hayTitle.Contains(term) Then score += 22
            If hayCode.Contains(term) Then score += 24
            If hayTax.Contains(term) Then score += 16
            If hayDesc.Contains(term) Then score += 8
        Next

        If FieldInt(rd, "InOfferta", 0) = 1 Then score += If(filterPromo, 22, 9)
        If FieldDecimal(rd, "Disponibilita", 0D) > 0D Then score += If(filterInStock, 22, 8)
        If FieldInt(rd, "Vetrina", 0) = 1 Then score += 6
        If FieldInt(rd, "SpeditoGratis", 0) = 1 Then score += 5
        If FieldInt(rd, "Ricondizionato", 0) = 1 Then score += If(filterRefurbished OrElse ContainsAny(raw, New String() {"ricondizionato", "ricondizionati", "usato", "usati"}), 24, 1)
        If ContainsAny(raw, New String() {"compatibile", "compatibili"}) AndAlso ContainsAny(hayTitle & " " & hayDesc, New String() {"compatibile", "compatibili"}) Then score += 14
        If ContainsAny(raw, New String() {"protezione", "proteggi", "custodia", "cover", "pellicola", "vetro"}) AndAlso ContainsAny(hayTitle & " " & hayTax, New String() {"custodia", "cover", "case", "pellicola", "vetro", "protezione"}) Then score += 18
        If ContainsAny(raw, New String() {"toner", "cartuccia", "stampante", "stampanti"}) AndAlso ContainsAny(hayTitle & " " & hayTax, New String() {"toner", "cartuccia", "ink", "stampante", "pantum", "hp", "brother", "canon", "epson"}) Then score += 18
        If ContainsAny(raw, New String() {"notebook", "pc", "computer"}) AndAlso ContainsAny(hayTitle & " " & hayTax, New String() {"notebook", "pc", "computer", "lenovo", "dell", "hp", "ssd", "ram"}) Then score += 16
        If ContainsAny(raw, New String() {"usb", "type c", "tipo c", "hdmi", "cavo", "adattatore", "hub"}) AndAlso ContainsAny(hayTitle & " " & hayTax, New String() {"usb", "type", "tipo", "hdmi", "cavo", "adattatore", "hub"}) Then score += 16

        If priceMin.HasValue AndAlso priceValue > 0D Then
            If priceValue >= priceMin.Value Then score += 5 Else score -= 20
        End If
        If priceMax.HasValue AndAlso priceValue > 0D Then
            If priceValue <= priceMax.Value Then
                score += 22
            ElseIf priceValue <= priceMax.Value * 1.15D Then
                score += 2
            Else
                score -= 34
            End If
        End If

        If priceValue <= 0D Then score -= 8
        Return score
    End Function

    Private Sub SortCandidates(ByVal candidates As List(Of CatalogCandidate), ByVal sortMode As String)
        candidates.Sort(Function(a As CatalogCandidate, b As CatalogCandidate)
            Select Case sortMode
                Case "price_asc"
                    Dim pa As Decimal = If(a.Price > 0D, a.Price, Decimal.MaxValue)
                    Dim pb As Decimal = If(b.Price > 0D, b.Price, Decimal.MaxValue)
                    Dim cmp As Integer = pa.CompareTo(pb)
                    If cmp <> 0 Then Return cmp
                    Return b.Score.CompareTo(a.Score)
                Case "price_desc"
                    Dim cmpPriceDesc As Integer = b.Price.CompareTo(a.Price)
                    If cmpPriceDesc <> 0 Then Return cmpPriceDesc
                    Return b.Score.CompareTo(a.Score)
                Case "promo"
                    Dim cmpPromo As Integer = b.Promo.CompareTo(a.Promo)
                    If cmpPromo <> 0 Then Return cmpPromo
                    Return b.Score.CompareTo(a.Score)
                Case "available"
                    Dim cmpAvailability As Integer = b.Availability.CompareTo(a.Availability)
                    If cmpAvailability <> 0 Then Return cmpAvailability
                    Return b.Score.CompareTo(a.Score)
                Case "newest"
                    Dim cmpCreated As Integer = b.CreatedAt.CompareTo(a.CreatedAt)
                    If cmpCreated <> 0 Then Return cmpCreated
                    Return b.Score.CompareTo(a.Score)
                Case Else
                    Return b.Score.CompareTo(a.Score)
            End Select
        End Function)
    End Sub

    Private Function ReasonFor(ByVal rd As MySqlDataReader, ByVal rawQuery As String, ByVal terms As List(Of String), ByVal priceMin As Nullable(Of Decimal), ByVal priceMax As Nullable(Of Decimal), ByVal priceValue As Decimal) As String
        Dim reasons As New List(Of String)()
        If priceMax.HasValue AndAlso priceValue > 0D AndAlso priceValue <= priceMax.Value Then reasons.Add("entro budget")
        If priceMin.HasValue AndAlso priceValue > 0D AndAlso priceValue >= priceMin.Value Then reasons.Add("sopra budget minimo")
        If FieldInt(rd, "InOfferta", 0) = 1 Then reasons.Add("in offerta")
        If FieldDecimal(rd, "Disponibilita", 0D) > 0D Then reasons.Add("disponibile")
        If FieldInt(rd, "SpeditoGratis", 0) = 1 Then reasons.Add("spedizione gratis")
        If FieldInt(rd, "Ricondizionato", 0) = 1 Then reasons.Add("ricondizionato")
        If Not String.IsNullOrEmpty(FieldText(rd, "MarcheDescrizione")) Then reasons.Add(FieldText(rd, "MarcheDescrizione"))
        If reasons.Count = 0 AndAlso Not String.IsNullOrEmpty(BestCategory(rd)) Then reasons.Add(BestCategory(rd))
        If reasons.Count = 0 Then Return "pertinente alla ricerca marketplace"
        Return String.Join(" · ", reasons.ToArray())
    End Function

    Private Function BadgesFor(ByVal rd As MySqlDataReader, ByVal priceMin As Nullable(Of Decimal), ByVal priceMax As Nullable(Of Decimal), ByVal priceValue As Decimal) As List(Of String)
        Dim badges As New List(Of String)()
        If FieldInt(rd, "InOfferta", 0) = 1 Then badges.Add("Offerta")
        If FieldDecimal(rd, "Disponibilita", 0D) > 0D Then badges.Add("Disponibile")
        If FieldInt(rd, "SpeditoGratis", 0) = 1 Then badges.Add("Sped. gratis")
        If FieldInt(rd, "Ricondizionato", 0) = 1 Then badges.Add("Ricondizionato")
        If priceMax.HasValue AndAlso priceValue > 0D AndAlso priceValue <= priceMax.Value Then badges.Add("Budget OK")
        Return badges
    End Function

    Private Function BuildFacets(ByVal candidates As List(Of CatalogCandidate)) As Dictionary(Of String, Object)
        Dim facets As New Dictionary(Of String, Object)()
        facets("brands") = TopCounts(candidates, "brand", 8)
        facets("categories") = TopCounts(candidates, "category", 8)
        facets("sectors") = TopCounts(candidates, "sector", 6)
        Return facets
    End Function

    Private Function TopCounts(ByVal candidates As List(Of CatalogCandidate), ByVal field As String, ByVal maxItems As Integer) As List(Of Dictionary(Of String, Object))
        Dim counts As New Dictionary(Of String, Integer)(StringComparer.OrdinalIgnoreCase)
        For Each c As CatalogCandidate In candidates
            If c.Item.ContainsKey(field) Then
                Dim value As String = Convert.ToString(c.Item(field)).Trim()
                If Not String.IsNullOrEmpty(value) Then
                    If Not counts.ContainsKey(value) Then counts(value) = 0
                    counts(value) += 1
                End If
            End If
        Next
        Dim keys As New List(Of String)(counts.Keys)
        keys.Sort(Function(a As String, b As String) counts(b).CompareTo(counts(a)))
        Dim out As New List(Of Dictionary(Of String, Object))()
        For Each key As String In keys
            Dim item As New Dictionary(Of String, Object)()
            item("label") = key
            item("count") = counts(key)
            out.Add(item)
            If out.Count >= maxItems Then Exit For
        Next
        Return out
    End Function

    Private Function BuildSuggestions(ByVal rawQuery As String, ByVal intentTags As List(Of String), ByVal items As List(Of Dictionary(Of String, Object))) As List(Of String)
        Dim out As New List(Of String)()
        Dim normalized As String = Norm(rawQuery)
        If ContainsAny(normalized, New String() {"custodia", "cover", "pellicola", "vetro", "samsung"}) Then out.Add("Aggiungi modello esatto: Galaxy S26, A15, iPhone, ecc.")
        If ContainsAny(normalized, New String() {"toner", "cartuccia", "stampante"}) Then out.Add("Aggiungi marca e modello stampante per migliorare la compatibilita")
        If ContainsAny(normalized, New String() {"notebook", "pc"}) Then out.Add("Filtra per RAM, SSD, ricondizionato o fascia prezzo")
        If ContainsAny(normalized, New String() {"usb", "cavo", "adattatore"}) Then out.Add("Specifica connettore: USB-C, HDMI, Lightning, RJ45")
        If out.Count = 0 Then out.Add("Prova con marca, codice, EAN, budget o categoria")
        Return out
    End Function

    Private Function BuildSummary(ByVal rawQuery As String, ByVal intentTags As List(Of String), ByVal count As Integer, ByVal priceMax As Nullable(Of Decimal), ByVal filterInStock As Boolean, ByVal filterPromo As Boolean, ByVal filterRefurbished As Boolean) As String
        Dim parts As New List(Of String)()
        If intentTags.Count > 0 Then parts.Add("ho riconosciuto " & String.Join(", ", intentTags.ToArray()))
        If priceMax.HasValue Then parts.Add("budget massimo " & FormatEuro(priceMax.Value))
        If filterInStock Then parts.Add("priorita ai disponibili")
        If filterPromo Then parts.Add("priorita alle offerte")
        If filterRefurbished Then parts.Add("solo/priority ricondizionato")
        If count > 0 Then
            Return "La classifica combina pertinenza testuale, codice/EAN, tassonomia, prezzo, disponibilita e promozioni" & If(parts.Count > 0, "; " & String.Join("; ", parts.ToArray()), "") & "."
        End If
        Return "Non ho trovato risultati forti con i vincoli attuali" & If(parts.Count > 0, "; " & String.Join("; ", parts.ToArray()), "") & "."
    End Function

    Private Function DetectIntentTags(ByVal value As String) As List(Of String)
        Dim text As String = Norm(value)
        Dim tags As New List(Of String)()
        If ContainsAny(text, New String() {"custodia", "cover", "case", "vetro", "pellicola", "protezione", "proteggi", "smartphone", "samsung", "iphone"}) Then tags.Add("protezione smartphone")
        If ContainsAny(text, New String() {"toner", "cartuccia", "cartucce", "stampante", "stampanti", "pantum", "hp", "brother", "canon", "epson"}) Then tags.Add("stampa e consumabili")
        If ContainsAny(text, New String() {"notebook", "pc", "computer", "monitor", "ssd", "ram", "lenovo", "dell"}) Then tags.Add("pc e notebook")
        If ContainsAny(text, New String() {"usb", "type c", "tipo c", "cavo", "adattatore", "hub", "hdmi", "alimentatore"}) Then tags.Add("cavi e accessori")
        If ContainsAny(text, New String() {"offerta", "offerte", "promo", "sconto"}) Then tags.Add("offerte")
        If ContainsAny(text, New String() {"ricondizionato", "ricondizionati", "usato"}) Then tags.Add("ricondizionato")
        If ContainsAny(text, New String() {"disponibile", "disponibili", "magazzino"}) Then tags.Add("disponibilita")
        Return tags
    End Function

    Private Function EffectivePrice(ByVal rd As MySqlDataReader, ByVal ivaTipo As Integer) As Decimal
        Dim promo As Boolean = (FieldInt(rd, "InOfferta", 0) = 1)
        If ivaTipo = 1 Then
            If promo AndAlso FieldDecimal(rd, "PrezzoPromo", 0D) > 0D Then Return FieldDecimal(rd, "PrezzoPromo", 0D)
            Return FieldDecimal(rd, "Prezzo", 0D)
        End If
        If promo AndAlso FieldDecimal(rd, "PrezzoPromoIvato", 0D) > 0D Then Return FieldDecimal(rd, "PrezzoPromoIvato", 0D)
        Return FieldDecimal(rd, "PrezzoIvato", 0D)
    End Function

    Private Function BestCategory(ByVal rd As MySqlDataReader) As String
        Dim values As String() = New String() {FieldText(rd, "TipologieDescrizione"), FieldText(rd, "CategorieDescrizione"), FieldText(rd, "GruppiDescrizione"), FieldText(rd, "SottogruppiDescrizione"), FieldText(rd, "SettoriDescrizione")}
        For Each v As String In values
            If Not String.IsNullOrEmpty(v) Then Return v
        Next
        Return ""
    End Function

    Private Function ProductUrl(ByVal id As Integer, ByVal tcid As Integer) As String
        If tcid > 0 Then Return "articolo.aspx?id=" & id.ToString() & "&TCid=" & tcid.ToString()
        Return "articolo.aspx?id=" & id.ToString()
    End Function

    Private Function NormalizeImage(ByVal value As String) As String
        Dim img As String = Convert.ToString(value).Trim()
        If String.IsNullOrEmpty(img) Then Return "Public/foto/nofoto.gif"
        If img.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse img.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse img.StartsWith("/", StringComparison.OrdinalIgnoreCase) Then Return img
        If img.StartsWith("Public/", StringComparison.OrdinalIgnoreCase) Then Return img
        If img.StartsWith("foto/", StringComparison.OrdinalIgnoreCase) Then Return "Public/" & img
        Return "Public/foto/" & img
    End Function

    Private Function FormatEuro(ByVal value As Decimal) As String
        If value <= 0D Then Return ""
        Return value.ToString("N2", Globalization.CultureInfo.GetCultureInfo("it-IT")) & " €"
    End Function

    Private Function ExtractBudgetMax(ByVal q As String) As Nullable(Of Decimal)
        Dim text As String = Convert.ToString(q).ToLowerInvariant().Replace("€", " euro")
        Dim rx As New System.Text.RegularExpressions.Regex("(?:sotto|entro|massimo|max|fino a|non oltre|meno di)\s*(\d{1,6}(?:[\.,]\d{1,2})?)")
        Dim m As System.Text.RegularExpressions.Match = rx.Match(text)
        If Not m.Success Then Return Nothing
        Dim raw As String = m.Groups(1).Value.Replace(".", "").Replace(",", ".")
        Dim value As Decimal
        If Decimal.TryParse(raw, Globalization.NumberStyles.Any, Globalization.CultureInfo.InvariantCulture, value) Then Return value
        Return Nothing
    End Function

    Private Function RequestDecimal(ByVal context As HttpContext, ByVal key As String) As Nullable(Of Decimal)
        Dim raw As String = Convert.ToString(context.Request(key)).Trim()
        If String.IsNullOrEmpty(raw) Then Return Nothing
        raw = raw.Replace("€", "").Replace(" ", "").Replace(".", "").Replace(",", ".")
        Dim value As Decimal
        If Decimal.TryParse(raw, Globalization.NumberStyles.Any, Globalization.CultureInfo.InvariantCulture, value) Then Return value
        Return Nothing
    End Function

    Private Function RequestFlag(ByVal context As HttpContext, ByVal key As String) As Boolean
        Dim raw As String = Convert.ToString(context.Request(key)).Trim().ToLowerInvariant()
        Return raw = "1" OrElse raw = "true" OrElse raw = "yes" OrElse raw = "on"
    End Function

    Private Function SafeSort(ByVal value As String) As String
        Dim v As String = Convert.ToString(value).Trim().ToLowerInvariant()
        Select Case v
            Case "price_asc", "price_desc", "promo", "available", "newest"
                Return v
            Case Else
                Return "relevance"
        End Select
    End Function

    Private Function Tokenize(ByVal value As String) As List(Of String)
        Dim text As String = Norm(value)
        Dim stopWords As New Dictionary(Of String, Boolean)(StringComparer.OrdinalIgnoreCase)
        For Each sw As String In New String() {"cerco", "cerca", "trovami", "voglio", "vorrei", "serve", "servono", "per", "con", "senza", "sotto", "entro", "massimo", "max", "fino", "meno", "oltre", "euro", "eur", "prezzo", "budget", "prodotto", "articolo", "articoli", "un", "una", "uno", "di", "da", "del", "della", "dello", "dei", "le", "la", "il", "lo", "gli", "ai", "al", "alla", "alle", "mi", "me", "come", "marketplace"}
            stopWords(sw) = True
        Next
        Dim out As New List(Of String)()
        For Each part As String In text.Split(" "c)
            Dim term As String = part.Trim()
            If term.Length >= 2 AndAlso Not stopWords.ContainsKey(term) Then
                Dim numericOnly As Boolean = True
                For i As Integer = 0 To term.Length - 1
                    If Not Char.IsDigit(term.Chars(i)) Then numericOnly = False
                Next
                If Not numericOnly Then out.Add(term)
            End If
            If out.Count >= 10 Then Exit For
        Next
        Return out
    End Function

    Private Function Norm(ByVal value As String) As String
        Dim text As String = Convert.ToString(value).ToLowerInvariant()
        text = text.Replace("à", "a").Replace("è", "e").Replace("é", "e").Replace("ì", "i").Replace("ò", "o").Replace("ù", "u")
        text = text.Replace("type-c", "type c").Replace("usb-c", "usb c")
        text = System.Text.RegularExpressions.Regex.Replace(text, "[^a-z0-9]+", " ")
        text = System.Text.RegularExpressions.Regex.Replace(text, "\s+", " ").Trim()
        Return text
    End Function

    Private Function HtmlToText(ByVal value As String) As String
        Dim text As String = Convert.ToString(value)
        If String.IsNullOrEmpty(text) Then Return ""
        text = System.Text.RegularExpressions.Regex.Replace(text, "<[^>]+>", " ")
        Return HttpUtility.HtmlDecode(text)
    End Function

    Private Function ShortText(ByVal value As String, ByVal maxLen As Integer) As String
        Dim text As String = System.Text.RegularExpressions.Regex.Replace(Convert.ToString(value), "\s+", " ").Trim()
        If text.Length <= maxLen Then Return text
        Return text.Substring(0, maxLen).Trim() & "..."
    End Function

    Private Function CleanQuery(ByVal value As String) As String
        Dim text As String = Convert.ToString(value)
        text = HttpUtility.HtmlDecode(text)
        text = System.Text.RegularExpressions.Regex.Replace(text, "\s+", " ").Trim()
        If text.Length > 180 Then text = text.Substring(0, 180)
        Return text
    End Function

    Private Function CleanShort(ByVal value As String, ByVal maxLen As Integer) As String
        Dim text As String = CleanQuery(value)
        If text.Length > maxLen Then text = text.Substring(0, maxLen)
        Return text
    End Function

    Private Function ContainsAny(ByVal value As String, ByVal words As String()) As Boolean
        Dim text As String = Convert.ToString(value)
        For Each w As String In words
            If text.IndexOf(w, StringComparison.OrdinalIgnoreCase) >= 0 Then Return True
        Next
        Return False
    End Function

    Private Function GetSessionValue(ByVal context As HttpContext, ByVal key As String) As Object
        Try
            If context IsNot Nothing AndAlso context.Session IsNot Nothing Then Return context.Session(key)
        Catch ex As Exception
        End Try
        Return Nothing
    End Function

    Private Function SafeInt(ByVal value As Object, ByVal fallback As Integer) As Integer
        Dim n As Integer
        If value IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(value), n) Then Return n
        Return fallback
    End Function

    Private Function FieldText(ByVal rd As IDataRecord, ByVal name As String) As String
        Try
            Dim ordinal As Integer = rd.GetOrdinal(name)
            If rd.IsDBNull(ordinal) Then Return ""
            Return Convert.ToString(rd.GetValue(ordinal)).Trim()
        Catch ex As Exception
            Return ""
        End Try
    End Function

    Private Function FieldInt(ByVal rd As IDataRecord, ByVal name As String, ByVal fallback As Integer) As Integer
        Try
            Dim ordinal As Integer = rd.GetOrdinal(name)
            If rd.IsDBNull(ordinal) Then Return fallback
            Dim n As Integer
            If Integer.TryParse(Convert.ToString(rd.GetValue(ordinal)), n) Then Return n
        Catch ex As Exception
        End Try
        Return fallback
    End Function

    Private Function FieldDecimal(ByVal rd As IDataRecord, ByVal name As String, ByVal fallback As Decimal) As Decimal
        Try
            Dim ordinal As Integer = rd.GetOrdinal(name)
            If rd.IsDBNull(ordinal) Then Return fallback
            Dim n As Decimal
            If Decimal.TryParse(Convert.ToString(rd.GetValue(ordinal)), Globalization.NumberStyles.Any, Globalization.CultureInfo.InvariantCulture, n) Then Return n
            If Decimal.TryParse(Convert.ToString(rd.GetValue(ordinal)), Globalization.NumberStyles.Any, Globalization.CultureInfo.GetCultureInfo("it-IT"), n) Then Return n
        Catch ex As Exception
        End Try
        Return fallback
    End Function

    Private Function FieldDate(ByVal rd As IDataRecord, ByVal name As String) As DateTime
        Try
            Dim ordinal As Integer = rd.GetOrdinal(name)
            If rd.IsDBNull(ordinal) Then Return DateTime.MinValue
            Dim d As DateTime
            If DateTime.TryParse(Convert.ToString(rd.GetValue(ordinal)), d) Then Return d
        Catch ex As Exception
        End Try
        Return DateTime.MinValue
    End Function

    Private Class CatalogCandidate
        Public Score As Integer
        Public Price As Decimal
        Public Availability As Decimal
        Public Promo As Integer
        Public CreatedAt As DateTime
        Public Item As Dictionary(Of String, Object)

        Public Sub New(ByVal scoreValue As Integer, ByVal priceValue As Decimal, ByVal availabilityValue As Decimal, ByVal promoValue As Integer, ByVal createdValue As DateTime, ByVal itemValue As Dictionary(Of String, Object))
            Score = scoreValue
            Price = priceValue
            Availability = availabilityValue
            Promo = promoValue
            CreatedAt = createdValue
            Item = itemValue
        End Sub
    End Class
End Class
