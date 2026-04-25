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

    Private Const DefaultLimit As Integer = 8
    Private Const MaxLimit As Integer = 24

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
        serializer.MaxJsonLength = 2097152

        Try
            Dim rawQuery As String = CleanQuery(Convert.ToString(context.Request("q")))
            Dim limit As Integer = SafeInt(context.Request("limit"), DefaultLimit)
            If limit < 1 Then limit = DefaultLimit
            If limit > MaxLimit Then limit = MaxLimit

            Dim nListino As Integer = SafeInt(GetSessionValue(context, "NListino"), 1)
            If nListino <= 0 Then nListino = 1

            Dim ivaTipo As Integer = SafeInt(GetSessionValue(context, "IvaTipo"), 2)
            Dim budgetMax As Nullable(Of Decimal) = ExtractBudget(rawQuery)
            Dim terms As List(Of String) = Tokenize(rawQuery)

            Dim items As List(Of Dictionary(Of String, Object)) = SearchCatalog(context, rawQuery, terms, nListino, ivaTipo, budgetMax, Math.Max(limit * 5, 40), True)
            If items.Count = 0 AndAlso terms.Count > 1 Then
                items = SearchCatalog(context, rawQuery, terms, nListino, ivaTipo, budgetMax, Math.Max(limit * 7, 60), False)
            End If

            If items.Count > limit Then items = items.GetRange(0, limit)

            Dim payload As New Dictionary(Of String, Object)()
            payload("ok") = True
            payload("mode") = "database"
            payload("query") = rawQuery
            payload("count") = items.Count
            payload("nListino") = nListino
            payload("items") = items
            context.Response.Write(serializer.Serialize(payload))
        Catch ex As Exception
            context.Response.StatusCode = 200
            Dim payload As New Dictionary(Of String, Object)()
            payload("ok") = False
            payload("mode") = "database"
            payload("error") = "Catalog search unavailable"
            payload("items") = New List(Of Dictionary(Of String, Object))()
            context.Response.Write(serializer.Serialize(payload))
        End Try
    End Sub

    Private Function SearchCatalog(ByVal context As HttpContext, ByVal rawQuery As String, ByVal terms As List(Of String), ByVal nListino As Integer, ByVal ivaTipo As Integer, ByVal budgetMax As Nullable(Of Decimal), ByVal candidateLimit As Integer, ByVal requireAllTerms As Boolean) As List(Of Dictionary(Of String, Object))
        Dim candidates As New List(Of CatalogCandidate)()
        Dim cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If cs Is Nothing OrElse String.IsNullOrEmpty(cs.ConnectionString) Then Return New List(Of Dictionary(Of String, Object))()

        Using conn As New MySqlConnection(cs.ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text
                cmd.CommandText = BuildSql(terms, requireAllTerms, candidateLimit)
                cmd.Parameters.AddWithValue("@NListino", nListino)
                For i As Integer = 0 To terms.Count - 1
                    cmd.Parameters.AddWithValue("@t" & i.ToString(), "%" & terms(i) & "%")
                Next

                Using rd As MySqlDataReader = cmd.ExecuteReader(CommandBehavior.CloseConnection)
                    While rd.Read()
                        Dim title As String = FieldText(rd, "Descrizione1")
                        If String.IsNullOrEmpty(title) Then Continue While

                        Dim id As Integer = FieldInt(rd, "id", 0)
                        If id <= 0 Then Continue While

                        Dim tcid As Integer = FieldInt(rd, "TCid", -1)
                        Dim priceValue As Decimal = EffectivePrice(rd, ivaTipo)
                        Dim score As Integer = ScoreRow(rd, rawQuery, terms, budgetMax, priceValue)
                        If score <= 0 AndAlso terms.Count > 0 Then Continue While

                        Dim item As New Dictionary(Of String, Object)()
                        item("id") = id
                        item("tcid") = tcid
                        item("title") = title
                        item("description") = ShortText(HtmlToText(FieldText(rd, "Descrizione2") & " " & FieldText(rd, "DescrizioneLunga")), 180)
                        item("code") = FieldText(rd, "Codice")
                        item("ean") = FieldText(rd, "Ean")
                        item("brand") = FieldText(rd, "MarcheDescrizione")
                        item("sector") = FieldText(rd, "SettoriDescrizione")
                        item("category") = BestCategory(rd)
                        item("availability") = FieldDecimal(rd, "Disponibilita", 0D)
                        item("reconditioned") = (FieldInt(rd, "Ricondizionato", 0) = 1)
                        item("promo") = (FieldInt(rd, "InOfferta", 0) = 1)
                        item("priceValue") = priceValue
                        item("price") = FormatEuro(priceValue)
                        item("imageUrl") = NormalizeImage(FieldText(rd, "Img1"))
                        item("url") = ProductUrl(id, tcid)
                        item("reason") = ReasonFor(rd, terms, budgetMax, priceValue)
                        item("score") = score
                        candidates.Add(New CatalogCandidate(score, item))
                    End While
                End Using
            End Using
        End Using

        candidates.Sort(Function(a As CatalogCandidate, b As CatalogCandidate) b.Score.CompareTo(a.Score))

        Dim output As New List(Of Dictionary(Of String, Object))()
        Dim seen As New Dictionary(Of String, Boolean)(StringComparer.OrdinalIgnoreCase)
        For Each c As CatalogCandidate In candidates
            Dim key As String = Convert.ToString(c.Item("id"))
            If Not seen.ContainsKey(key) Then
                seen(key) = True
                output.Add(c.Item)
            End If
        Next
        Return output
    End Function

    Private Function BuildSql(ByVal terms As List(Of String), ByVal requireAllTerms As Boolean, ByVal candidateLimit As Integer) As String
        Dim fields As String = "COALESCE(Descrizione1,''), COALESCE(Descrizione2,''), COALESCE(DescrizioneLunga,''), COALESCE(DescrizioneHTML,''), COALESCE(Codice,''), COALESCE(Ean,''), COALESCE(MarcheDescrizione,''), COALESCE(SettoriDescrizione,''), COALESCE(CategorieDescrizione,''), COALESCE(TipologieDescrizione,''), COALESCE(GruppiDEscrizione,''), COALESCE(SottogruppiDescrIZione,'')"
        Dim sql As New System.Text.StringBuilder()
        sql.Append("SELECT id, Codice, Ean, Descrizione1, Descrizione2, DescrizioneLunga, DescrizioneHTML, Vetrina, MarcheDescrizione, SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, GruppiDEscrizione AS GruppiDescrizione, SottogruppiDescrIZione AS SottogruppiDescrizione, Img1, Img2, Img3, Img4, DataCreazione, visite, Export, Ricondizionato, Disponibilita, TCid, NListino, Prezzo, PrezzoIvato, InOfferta, PrezzoPromo, PrezzoPromoIvato ")
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

        sql.Append("ORDER BY IFNULL(InOfferta,0) DESC, IFNULL(Disponibilita,0) DESC, IFNULL(Vetrina,0) DESC, IFNULL(visite,0) DESC, DataCreazione DESC, id DESC ")
        sql.Append("LIMIT ").Append(Math.Max(1, Math.Min(candidateLimit, 120)).ToString())
        Return sql.ToString()
    End Function

    Private Function ScoreRow(ByVal rd As MySqlDataReader, ByVal rawQuery As String, ByVal terms As List(Of String), ByVal budgetMax As Nullable(Of Decimal), ByVal priceValue As Decimal) As Integer
        Dim hayTitle As String = Norm(FieldText(rd, "Descrizione1"))
        Dim hayCode As String = Norm(FieldText(rd, "Codice") & " " & FieldText(rd, "Ean"))
        Dim hayTax As String = Norm(FieldText(rd, "MarcheDescrizione") & " " & FieldText(rd, "SettoriDescrizione") & " " & FieldText(rd, "CategorieDescrizione") & " " & FieldText(rd, "TipologieDescrizione") & " " & FieldText(rd, "GruppiDescrizione") & " " & FieldText(rd, "SottogruppiDescrizione"))
        Dim hayDesc As String = Norm(FieldText(rd, "Descrizione2") & " " & FieldText(rd, "DescrizioneLunga") & " " & HtmlToText(FieldText(rd, "DescrizioneHTML")))
        Dim raw As String = Norm(rawQuery)
        Dim score As Integer = 0

        If raw.Length > 2 AndAlso (hayTitle.Contains(raw) OrElse hayDesc.Contains(raw)) Then score += 60
        For Each term As String In terms
            If hayTitle.Contains(term) Then score += 22
            If hayCode.Contains(term) Then score += 18
            If hayTax.Contains(term) Then score += 14
            If hayDesc.Contains(term) Then score += 8
        Next

        If FieldInt(rd, "InOfferta", 0) = 1 Then score += 9
        If FieldDecimal(rd, "Disponibilita", 0D) > 0D Then score += 8
        If FieldInt(rd, "Vetrina", 0) = 1 Then score += 6
        If ContainsAny(raw, New String() {"ricondizionato", "ricondizionati", "usato", "usati"}) AndAlso FieldInt(rd, "Ricondizionato", 0) = 1 Then score += 18
        If ContainsAny(raw, New String() {"compatibile", "compatibili"}) AndAlso ContainsAny(hayTitle & " " & hayDesc, New String() {"compatibile", "compatibili"}) Then score += 10

        If budgetMax.HasValue AndAlso priceValue > 0D Then
            If priceValue <= budgetMax.Value Then
                score += 18
            ElseIf priceValue > (budgetMax.Value * 1.15D) Then
                score -= 35
            End If
        End If

        If priceValue <= 0D Then score -= 8
        Return score
    End Function

    Private Function ReasonFor(ByVal rd As MySqlDataReader, ByVal terms As List(Of String), ByVal budgetMax As Nullable(Of Decimal), ByVal priceValue As Decimal) As String
        Dim reasons As New List(Of String)()
        If budgetMax.HasValue AndAlso priceValue > 0D AndAlso priceValue <= budgetMax.Value Then reasons.Add("entro budget")
        If FieldInt(rd, "InOfferta", 0) = 1 Then reasons.Add("in offerta")
        If FieldDecimal(rd, "Disponibilita", 0D) > 0D Then reasons.Add("disponibile")
        If FieldInt(rd, "Ricondizionato", 0) = 1 Then reasons.Add("ricondizionato")
        If Not String.IsNullOrEmpty(FieldText(rd, "MarcheDescrizione")) Then reasons.Add(FieldText(rd, "MarcheDescrizione"))
        If reasons.Count = 0 AndAlso Not String.IsNullOrEmpty(BestCategory(rd)) Then reasons.Add(BestCategory(rd))
        If reasons.Count = 0 Then Return "pertinente alla ricerca"
        Return String.Join(" · ", reasons.ToArray())
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
        Dim values As String() = New String() {FieldText(rd, "TipologieDescrizione"), FieldText(rd, "CategorieDescrizione"), FieldText(rd, "GruppiDescrizione"), FieldText(rd, "SettoriDescrizione")}
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

    Private Function ExtractBudget(ByVal q As String) As Nullable(Of Decimal)
        Dim text As String = Convert.ToString(q).ToLowerInvariant().Replace("€", " euro")
        Dim rx As New System.Text.RegularExpressions.Regex("(?:sotto|entro|massimo|max|fino a|non oltre|meno di)\s*(\d{1,6}(?:[\.,]\d{1,2})?)")
        Dim m As System.Text.RegularExpressions.Match = rx.Match(text)
        If Not m.Success Then Return Nothing
        Dim raw As String = m.Groups(1).Value.Replace(".", "").Replace(",", ".")
        Dim value As Decimal
        If Decimal.TryParse(raw, Globalization.NumberStyles.Any, Globalization.CultureInfo.InvariantCulture, value) Then Return value
        Return Nothing
    End Function

    Private Function Tokenize(ByVal value As String) As List(Of String)
        Dim text As String = Norm(value)
        Dim stopWords As New Dictionary(Of String, Boolean)(StringComparer.OrdinalIgnoreCase)
        For Each sw As String In New String() {"cerco", "cerca", "trovami", "voglio", "vorrei", "serve", "servono", "per", "con", "senza", "sotto", "entro", "massimo", "max", "fino", "euro", "eur", "prezzo", "budget", "prodotto", "articolo", "un", "una", "uno", "di", "da", "del", "della", "dello", "dei", "le", "la", "il", "lo", "gli", "ai", "al", "alla", "alle", "mi", "me"}
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
            If out.Count >= 8 Then Exit For
        Next
        Return out
    End Function

    Private Function Norm(ByVal value As String) As String
        Dim text As String = Convert.ToString(value).ToLowerInvariant()
        text = text.Replace("à", "a").Replace("è", "e").Replace("é", "e").Replace("ì", "i").Replace("ò", "o").Replace("ù", "u")
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
        If text.Length > 160 Then text = text.Substring(0, 160)
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

    Private Class CatalogCandidate
        Public Score As Integer
        Public Item As Dictionary(Of String, Object)

        Public Sub New(ByVal scoreValue As Integer, ByVal itemValue As Dictionary(Of String, Object))
            Score = scoreValue
            Item = itemValue
        End Sub
    End Class
End Class
