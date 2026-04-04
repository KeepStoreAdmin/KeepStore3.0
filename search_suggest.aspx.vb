Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Linq
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.Script.Serialization
Imports MySql.Data.MySqlClient

Partial Class search_suggest
    Inherits System.Web.UI.Page

    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Private NotInheritable Class SuggestionResult
        Public Property id As Integer
        Public Property t As String
        Public Property label As String
        Public Property value As String
        Public Property meta As String
        Public Property price As String
        Public Property img As String
        Public Property url As String
        Public Property type As String
        Public Property code As String
        Public Property ean As String
        Public Property score As Integer
        Public Property priority As Integer
    End Class

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.Clear()
        Response.ContentType = "application/json; charset=utf-8"
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()

        Dim rawTerm As String = Convert.ToString(Request.QueryString("term"))
        If String.IsNullOrWhiteSpace(rawTerm) Then
            rawTerm = Convert.ToString(Request.QueryString("q"))
        End If

        Dim term As String = NormalizeTerm(rawTerm)
        If term.Length < 2 Then
            WriteJson(New List(Of Object)())
            Return
        End If

        Dim limit As Integer = 8
        Integer.TryParse(Convert.ToString(Request.QueryString("limit")), limit)
        limit = Math.Max(1, Math.Min(limit, 12))

        Dim sectorId As Integer = 0
        Integer.TryParse(Convert.ToString(Request.QueryString("st")), sectorId)

        Dim results As New List(Of SuggestionResult)()

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Try
                    AppendSectorSuggestions(conn, results, term, Math.Min(3, limit))
                Catch
                End Try
                Try
                    AppendCategorySuggestions(conn, results, term, sectorId, Math.Min(3, limit))
                Catch
                End Try
                Try
                    AppendProductSuggestions(conn, results, term, sectorId, limit)
                Catch
                End Try
            End Using
        Catch
            results = New List(Of SuggestionResult)()
        End Try

        Dim ordered As List(Of SuggestionResult) =
            results.
                GroupBy(Function(item) item.type & "|" & item.id.ToString()).
                Select(Function(group) group.OrderByDescending(Function(item) item.score).
                    ThenBy(Function(item) item.priority).
                    ThenBy(Function(item) item.label).
                    First()).
                OrderByDescending(Function(item) item.score).
                ThenBy(Function(item) item.priority).
                ThenBy(Function(item) item.label).
                Take(limit).
                ToList()

        WriteJson(ordered)
    End Sub

    Private Sub AppendSectorSuggestions(ByVal conn As MySqlConnection,
                                        ByVal results As List(Of SuggestionResult),
                                        ByVal term As String,
                                        ByVal maxItems As Integer)
        Dim sql As String =
            "SELECT id, Descrizione, " &
            "(CASE " &
            "  WHEN LOWER(Descrizione)=@exact THEN 1080 " &
            "  WHEN LOWER(Descrizione) LIKE @prefix THEN 920 " &
            "  WHEN LOWER(Descrizione) LIKE @contains THEN 760 " &
            "  ELSE 0 END) AS Score " &
            "FROM settori " &
            "WHERE COALESCE(Abilitato,0)=1 " &
            "AND (LOWER(Descrizione) LIKE @contains) " &
            "ORDER BY Score DESC, COALESCE(Predefinito,0) DESC, COALESCE(Ordinamento,0) ASC, Descrizione ASC " &
            "LIMIT " & maxItems.ToString()

        Using cmd As New MySqlCommand(sql, conn)
            cmd.Parameters.AddWithValue("@exact", term.ToLowerInvariant())
            cmd.Parameters.AddWithValue("@prefix", term.ToLowerInvariant() & "%")
            cmd.Parameters.AddWithValue("@contains", "%" & term.ToLowerInvariant() & "%")

            Using reader As MySqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    Dim id As Integer = SafeInt(reader, "id")
                    Dim name As String = SafeString(reader, "Descrizione")
                    results.Add(New SuggestionResult With {
                        .id = id,
                        .t = name,
                        .label = name,
                        .value = name,
                        .meta = "Naviga nel reparto",
                        .img = String.Empty,
                        .url = "/articoli.aspx?st=" & id.ToString(),
                        .type = "Reparto",
                        .score = SafeInt(reader, "Score"),
                        .priority = 2
                    })
                End While
            End Using
        End Using
    End Sub

    Private Sub AppendCategorySuggestions(ByVal conn As MySqlConnection,
                                          ByVal results As List(Of SuggestionResult),
                                          ByVal term As String,
                                          ByVal sectorId As Integer,
                                          ByVal maxItems As Integer)
        Dim categorySectorColumn As String = ResolveColumnName(conn, "categorie", "SettoriId", "Id_settore")
        If String.IsNullOrWhiteSpace(categorySectorColumn) Then
            Return
        End If

        Dim sql As New StringBuilder()
        sql.Append("SELECT id, ").Append(categorySectorColumn).Append(" AS SettoriId, Descrizione, ")
        sql.Append("(CASE ")
        sql.Append("  WHEN LOWER(Descrizione)=@exact THEN 1180 ")
        sql.Append("  WHEN LOWER(Descrizione) LIKE @prefix THEN 980 ")
        sql.Append("  WHEN LOWER(Descrizione) LIKE @contains THEN 820 ")
        sql.Append("  ELSE 0 END) AS Score ")
        sql.Append("FROM categorie ")
        sql.Append("WHERE COALESCE(Abilitato,1)=1 ")
        sql.Append("AND LOWER(Descrizione) LIKE @contains ")
        If sectorId > 0 Then
            sql.Append("AND COALESCE(").Append(categorySectorColumn).Append(",0)=@sectorId ")
        End If
        sql.Append("ORDER BY Score DESC, COALESCE(Ordinamento,0) ASC, Descrizione ASC ")
        sql.Append("LIMIT ").Append(maxItems.ToString())

        Using cmd As New MySqlCommand(sql.ToString(), conn)
            cmd.Parameters.AddWithValue("@exact", term.ToLowerInvariant())
            cmd.Parameters.AddWithValue("@prefix", term.ToLowerInvariant() & "%")
            cmd.Parameters.AddWithValue("@contains", "%" & term.ToLowerInvariant() & "%")
            If sectorId > 0 Then
                cmd.Parameters.AddWithValue("@sectorId", sectorId)
            End If

            Using reader As MySqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    Dim categoryId As Integer = SafeInt(reader, "id")
                    Dim categoryName As String = SafeString(reader, "Descrizione")
                    Dim currentSectorId As Integer = SafeInt(reader, "SettoriId")
                    Dim url As String = "/articoli.aspx?ct=" & categoryId.ToString()
                    If currentSectorId > 0 Then
                        url &= "&st=" & currentSectorId.ToString()
                    End If

                    results.Add(New SuggestionResult With {
                        .id = categoryId,
                        .t = categoryName,
                        .label = categoryName,
                        .value = categoryName,
                        .meta = "Apri la categoria",
                        .img = String.Empty,
                        .url = url,
                        .type = "Categoria",
                        .score = SafeInt(reader, "Score"),
                        .priority = 1
                    })
                End While
            End Using
        End Using
    End Sub

    Private Sub AppendProductSuggestions(ByVal conn As MySqlConnection,
                                         ByVal results As List(Of SuggestionResult),
                                         ByVal term As String,
                                         ByVal sectorId As Integer,
                                         ByVal limit As Integer)
        Dim query As String = NormalizeQuery(term, 60)
        Dim exact As String = query.ToLowerInvariant()
        Dim prefix As String = exact & "%"
        Dim contains As String = "%" & exact & "%"
        Dim tokens As List(Of String) = Tokenize(query, 6)
        Dim prezzoIvatoSql As String = BuildPrezzoIvatoSql()
        Dim prezzoPromoIvatoSql As String = BuildPrezzoPromoIvatoSql()
        Dim stockSql As String = "COALESCE(stk.Giacenza, COALESCE(v.Giacenza,0))"
        Dim promoValidSql As String =
            "(COALESCE(v.InOfferta,0)=1 " &
            "AND (v.OfferteDataInizio IS NULL OR CURDATE() >= v.OfferteDataInizio) " &
            "AND (v.OfferteDataFine IS NOT NULL AND CURDATE() <= v.OfferteDataFine) " &
            "AND (v.OfferteDaListino IS NULL OR @listino >= v.OfferteDaListino) " &
            "AND (v.OfferteAListino IS NULL OR @listino <= v.OfferteAListino) " &
            "AND COALESCE(v.OfferteQntMinima,0) <= 1 " &
            "AND (COALESCE(v.OfferteMultipli,0)=0 OR COALESCE(v.OfferteMultipli,0)=1) " &
            "AND " & prezzoPromoIvatoSql & " > 0 " &
            "AND " & prezzoIvatoSql & " > 0 " &
            "AND " & prezzoPromoIvatoSql & " < " & prezzoIvatoSql & ")"

        Dim sql As New StringBuilder()
        sql.Append("SELECT ")
        sql.Append(" v.id, v.Codice, v.Ean, v.Descrizione1, IFNULL(v.Descrizione2,'') AS Descrizione2, ")
        sql.Append(" IFNULL(v.DescrizioneLunga,'') AS DescrizioneLunga, IFNULL(v.MarcheDescrizione,'') AS MarcheDescrizione, ")
        sql.Append(" IFNULL(v.CategorieDescrizione,'') AS CategorieDescrizione, v.Img1, ")
        sql.Append(" ").Append(stockSql).Append(" AS Giacenza, ")
        sql.Append(" COALESCE(aBase.Abilitato,1) AS Abilitato, COALESCE(v.Vetrina,0) AS Vetrina, COALESCE(v.InOfferta,0) AS InOfferta, ")
        sql.Append(" COALESCE(v.Visite,0) AS Visite, COALESCE(v.DataCreazione,CURDATE()) AS DataCreazione, ")
        sql.Append(" ").Append(prezzoIvatoSql).Append(" AS PrezzoIvatoDisplay, ")
        sql.Append(" ").Append(prezzoPromoIvatoSql).Append(" AS PrezzoPromoIvatoDisplay, ")
        sql.Append(" CASE WHEN ").Append(promoValidSql).Append(" THEN ").Append(prezzoPromoIvatoSql).Append(" ELSE ").Append(prezzoIvatoSql).Append(" END AS DisplayPrice, ")
        sql.Append(" (CASE ")
        sql.Append("   WHEN LOWER(v.Codice)=@exact THEN 2200 ")
        sql.Append("   WHEN LOWER(v.Ean)=@exact THEN 2150 ")
        sql.Append("   WHEN LOWER(v.Descrizione1)=@exact THEN 1800 ")
        sql.Append("   WHEN LOWER(CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione1,'')))=@exact THEN 1750 ")
        sql.Append("   WHEN LOWER(v.Codice) LIKE @prefix THEN 1600 ")
        sql.Append("   WHEN LOWER(v.Ean) LIKE @prefix THEN 1580 ")
        sql.Append("   WHEN LOWER(v.Descrizione1) LIKE @prefix THEN 1320 ")
        sql.Append("   WHEN LOWER(CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione1,''))) LIKE @prefix THEN 1280 ")
        sql.Append("   WHEN LOWER(v.Descrizione1) LIKE @contains THEN 980 ")
        sql.Append("   WHEN LOWER(v.DescrizioneLunga) LIKE @contains THEN 860 ")
        sql.Append("   WHEN LOWER(CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione1,''))) LIKE @contains THEN 1120 ")
        sql.Append("   WHEN LOWER(CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione2,''))) LIKE @contains THEN 920 ")
        sql.Append("   ELSE 0 END ")
        For i As Integer = 0 To tokens.Count - 1
            sql.Append(" + (CASE ")
            sql.Append("   WHEN LOWER(v.Codice)=@t").Append(i.ToString()).Append(" THEN 300 ")
            sql.Append("   WHEN LOWER(v.Ean)=@t").Append(i.ToString()).Append(" THEN 280 ")
            sql.Append("   WHEN LOWER(v.Codice) LIKE CONCAT(@t").Append(i.ToString()).Append(", '%') THEN 220 ")
            sql.Append("   WHEN LOWER(v.Ean) LIKE CONCAT(@t").Append(i.ToString()).Append(", '%') THEN 200 ")
            sql.Append("   WHEN LOWER(v.Descrizione1) LIKE CONCAT(@t").Append(i.ToString()).Append(", '%') THEN 180 ")
            sql.Append("   WHEN LOWER(CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione1,''))) LIKE CONCAT('%', @t").Append(i.ToString()).Append(", '%') THEN 150 ")
            sql.Append("   WHEN LOWER(v.DescrizioneLunga) LIKE CONCAT('%', @t").Append(i.ToString()).Append(", '%') THEN 90 ")
            sql.Append("   ELSE 0 END) ")
        Next
        sql.Append(" ) AS Score ")
        sql.Append("FROM vsuperarticoli v ")
        sql.Append("INNER JOIN articoli aBase ON aBase.id = v.id ")
        sql.Append("LEFT JOIN (")
        sql.Append(" SELECT ArticoliId, SUM(COALESCE(Giacenza,0)) AS Giacenza")
        sql.Append(" FROM articoli_giacenze")
        sql.Append(" GROUP BY ArticoliId")
        sql.Append(") stk ON stk.ArticoliId = v.id ")
        sql.Append("WHERE COALESCE(v.NListino,1)=@listino ")
        sql.Append("AND COALESCE(aBase.Abilitato,1)=1 ")
        sql.Append("AND (")
        sql.Append(" LOWER(v.Codice) LIKE @contains ")
        sql.Append(" OR LOWER(v.Ean) LIKE @contains ")
        sql.Append(" OR LOWER(v.Descrizione1) LIKE @contains ")
        sql.Append(" OR LOWER(v.DescrizioneLunga) LIKE @contains ")
        sql.Append(" OR LOWER(CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione1,''))) LIKE @contains ")
        sql.Append(" OR LOWER(CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione2,''))) LIKE @contains ")
        For i As Integer = 0 To tokens.Count - 1
            sql.Append(" OR LOWER(v.Codice)=@t").Append(i.ToString())
            sql.Append(" OR LOWER(v.Ean)=@t").Append(i.ToString())
            sql.Append(" OR LOWER(v.Codice) LIKE CONCAT(@t").Append(i.ToString()).Append(", '%')")
            sql.Append(" OR LOWER(v.Ean) LIKE CONCAT(@t").Append(i.ToString()).Append(", '%')")
            sql.Append(" OR LOWER(v.Descrizione1) LIKE CONCAT('%', @t").Append(i.ToString()).Append(", '%')")
            sql.Append(" OR LOWER(v.DescrizioneLunga) LIKE CONCAT('%', @t").Append(i.ToString()).Append(", '%')")
        Next
        sql.Append(") ")
        If sectorId > 0 Then
            sql.Append("AND COALESCE(v.SettoriId,0)=@sectorId ")
        End If
        sql.Append("ORDER BY Score DESC, CASE WHEN ").Append(stockSql).Append(">0 THEN 1 ELSE 0 END DESC, COALESCE(v.InOfferta,0) DESC, COALESCE(v.Vetrina,0) DESC, COALESCE(v.Visite,0) DESC, COALESCE(v.DataCreazione,CURDATE()) DESC, v.id DESC ")
        sql.Append("LIMIT ").Append(limit.ToString())

        Using cmd As New MySqlCommand(sql.ToString(), conn)
            cmd.Parameters.AddWithValue("@listino", GetCurrentListino())
            cmd.Parameters.AddWithValue("@exact", exact)
            cmd.Parameters.AddWithValue("@prefix", prefix)
            cmd.Parameters.AddWithValue("@contains", contains)
            If sectorId > 0 Then
                cmd.Parameters.AddWithValue("@sectorId", sectorId)
            End If
            For i As Integer = 0 To tokens.Count - 1
                cmd.Parameters.AddWithValue("@t" & i.ToString(), tokens(i).ToLowerInvariant())
            Next

            Using reader As MySqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    Dim id As Integer = SafeInt(reader, "id")
                    Dim title As String = SafeString(reader, "Descrizione1")
                    Dim brand As String = SafeString(reader, "MarcheDescrizione")
                    Dim label As String = title
                    If Not String.IsNullOrWhiteSpace(brand) Then
                        label = brand.Trim() & " - " & title
                    End If

                    Dim metaParts As New List(Of String)()
                    Dim code As String = SafeString(reader, "Codice")
                    Dim ean As String = SafeString(reader, "Ean")
                    Dim category As String = SafeString(reader, "CategorieDescrizione")
                    If Not String.IsNullOrWhiteSpace(code) Then
                        metaParts.Add(code)
                    ElseIf Not String.IsNullOrWhiteSpace(ean) Then
                        metaParts.Add(ean)
                    End If
                    If Not String.IsNullOrWhiteSpace(category) Then metaParts.Add(category)
                    If Not String.IsNullOrWhiteSpace(brand) AndAlso metaParts.Count < 3 Then metaParts.Add(brand)

                    results.Add(New SuggestionResult With {
                        .id = id,
                        .t = label,
                        .label = label,
                        .value = label,
                        .meta = String.Join(" · ", metaParts.ToArray()),
                        .price = FormatPrice(SafeDecimal(reader, "DisplayPrice")),
                        .img = ProductImageThumb(SafeString(reader, "Img1")),
                        .url = "/articolo.aspx?id=" & id.ToString(),
                        .code = code,
                        .ean = ean,
                        .type = "Prodotto",
                        .score = SafeInt(reader, "Score"),
                        .priority = 0
                    })
                End While
            End Using
        End Using
    End Sub

    Private Function GetCurrentListino() As Integer
        Dim listino As Integer = 1
        If Session("Listino") IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Session("Listino")), listino)
        End If
        If listino <= 0 Then listino = 1
        Return listino
    End Function

    Private Function NormalizeTerm(ByVal raw As String) As String
        Dim value As String = NormalizeQuery(raw, 60)
        value = Regex.Replace(value, "[^\p{L}\p{Nd}\s\-\+\.,/&'()]", " ")
        value = Regex.Replace(value, "\s+", " ").Trim()
        Return value
    End Function

    Private Function ProductImageThumb(ByVal value As String) As String
        Dim fileName As String = If(value, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then
            Return String.Empty
        End If

        fileName = Path.GetFileName(fileName.Replace("\", "/"))
        Dim thumbPath As String
        If fileName.StartsWith("_", StringComparison.OrdinalIgnoreCase) Then
            thumbPath = "/Public/assets/images/articoli/" & fileName
            If VirtualFileExists(thumbPath) Then
                Return thumbPath
            End If
            Return String.Empty
        End If

        thumbPath = "/Public/assets/images/articoli/_" & fileName
        If VirtualFileExists(thumbPath) Then
            Return thumbPath
        End If

        Dim fullPath As String = "/Public/assets/images/articoli/" & fileName
        If VirtualFileExists(fullPath) Then
            Return fullPath
        End If

        Return String.Empty
    End Function

    Private Function GetReverseChargeEnabled() As Integer
        Dim flag As Integer = 0
        If Session("AbilitatoIvaReverseCharge") IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Session("AbilitatoIvaReverseCharge")), flag)
        End If
        If flag <> 1 Then flag = 0
        Return flag
    End Function

    Private Function GetCurrentUserIva() As Integer
        Dim ivaUtente As Integer = 0
        If Session("Iva_Utente") IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Session("Iva_Utente")), ivaUtente)
        End If
        If ivaUtente < 0 Then ivaUtente = 0
        Return ivaUtente
    End Function

    Private Function BuildPrezzoIvatoSql() As String
        Dim abilRC As Integer = GetReverseChargeEnabled()
        Dim ivaUtente As Integer = GetCurrentUserIva()

        Return "IF((" & abilRC.ToString(CultureInfo.InvariantCulture) & "=1) AND (COALESCE(v.ValoreIvaRC,-1)>-1)," &
               " (COALESCE(v.Prezzo,0)*((COALESCE(v.ValoreIvaRC,0)/100)+1))," &
               " IF(" & ivaUtente.ToString(CultureInfo.InvariantCulture) & ">0,(COALESCE(v.Prezzo,0)*((" & ivaUtente.ToString(CultureInfo.InvariantCulture) & "/100)+1)),COALESCE(v.PrezzoIvato,0))" &
               " )"
    End Function

    Private Function BuildPrezzoPromoIvatoSql() As String
        Dim abilRC As Integer = GetReverseChargeEnabled()
        Dim ivaUtente As Integer = GetCurrentUserIva()

        Return "IF((" & abilRC.ToString(CultureInfo.InvariantCulture) & "=1) AND (COALESCE(v.ValoreIvaRC,-1)>-1)," &
               " (COALESCE(v.PrezzoPromo,0)*((COALESCE(v.ValoreIvaRC,0)/100)+1))," &
               " IF(" & ivaUtente.ToString(CultureInfo.InvariantCulture) & ">0,(COALESCE(v.PrezzoPromo,0)*((" & ivaUtente.ToString(CultureInfo.InvariantCulture) & "/100)+1)),COALESCE(v.PrezzoPromoIvato,0))" &
               " )"
    End Function

    Private Function SafeDecimal(ByVal reader As IDataRecord, ByVal fieldName As String) As Decimal
        Dim value As Decimal = 0D
        Try
            Dim raw As String = SafeString(reader, fieldName)
            If String.IsNullOrWhiteSpace(raw) Then Return 0D
            If Decimal.TryParse(raw, NumberStyles.Any, ItCulture, value) Then Return value
            If Decimal.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, value) Then Return value
            Dim normalized As String = raw.Replace(".", String.Empty).Replace(",", ".")
            If Decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, value) Then Return value
        Catch
        End Try
        Return 0D
    End Function

    Private Function FormatPrice(ByVal value As Decimal) As String
        If value <= 0D Then
            Return String.Empty
        End If
        Return value.ToString("C2", ItCulture)
    End Function

    Private Function VirtualFileExists(ByVal virtualPath As String) As Boolean
        If String.IsNullOrWhiteSpace(virtualPath) Then
            Return False
        End If

        Try
            Dim candidate As String = virtualPath
            If candidate.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
               candidate.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
               candidate.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then
                Return True
            End If

            If candidate.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
                candidate = candidate.Substring(1)
            End If

            If Not candidate.StartsWith("/") Then
                candidate = "/" & candidate.TrimStart("/"c)
            End If

            Dim physicalPath As String = HostingEnvironment.MapPath("~" & candidate)
            Return Not String.IsNullOrWhiteSpace(physicalPath) AndAlso File.Exists(physicalPath)
        Catch
            Return False
        End Try
    End Function

    Private Function ResolveColumnName(ByVal conn As MySqlConnection, ByVal tableName As String, ParamArray ByVal candidates() As String) As String
        If conn Is Nothing OrElse String.IsNullOrWhiteSpace(tableName) OrElse candidates Is Nothing OrElse candidates.Length = 0 Then
            Return String.Empty
        End If

        Using cmd As New MySqlCommand("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME)=LOWER(@tableName)", conn)
            cmd.Parameters.AddWithValue("@tableName", tableName)
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                Dim columns As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
                While reader.Read()
                    columns.Add(SafeString(reader, "COLUMN_NAME"))
                End While

                For Each candidate As String In candidates
                    If columns.Contains(candidate) Then
                        Return candidate
                    End If
                Next
            End Using
        End Using

        Return String.Empty
    End Function

    Private Function SafeString(ByVal reader As IDataRecord, ByVal fieldName As String) As String
        Try
            Dim ordinal As Integer = reader.GetOrdinal(fieldName)
            If reader.IsDBNull(ordinal) Then Return String.Empty
            Return Convert.ToString(reader.GetValue(ordinal))
        Catch
            Return String.Empty
        End Try
    End Function

    Private Function SafeInt(ByVal reader As IDataRecord, ByVal fieldName As String) As Integer
        Dim value As Integer = 0
        Integer.TryParse(SafeString(reader, fieldName), value)
        Return value
    End Function

    Private Sub WriteJson(ByVal obj As Object)
        Dim js As New JavaScriptSerializer()
        Response.Write(js.Serialize(obj))
        Response.End()
    End Sub
End Class
