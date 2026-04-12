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

Partial Public Class search_suggest
    Inherits Page

    Private Const DefaultLimit As Integer = 8
    Private Const MaxLimit As Integer = 60
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
    End Class

    Private Class SuggestItem
        Public Property Id As Integer
        Public Property Url As String
        Public Property Title As String
        Public Property Brand As String
        Public Property Category As String
        Public Property Price As String
        Public Property Score As Integer
        Public Property MatchKind As String
        Public Property Image As String
        Public Property ImageFallback As String
    End Class

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.Clear()
        Response.Charset = "utf-8"
        Response.ContentType = "application/json"
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()

        Dim payload As New Dictionary(Of String, Object)()

        Try
            Dim query As String = NormalizeQuery(Request("q"))
            Dim filters As SearchFilters = ReadFilters()
            Dim limit As Integer = Math.Max(1, Math.Min(MaxLimit, ReadInt(Request("limit"), DefaultLimit)))
            Dim recentIds As List(Of Integer) = ParseIds(Request("recent"))
            If recentIds.Count = 0 Then recentIds = ParseIds(ReadCookieValue("ks_recent"))

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
        output("strong") = New Dictionary(Of String, Object) From {
            {"canRedirect", False},
            {"redirectUrl", String.Empty}
        }

        If recentIds Is Nothing OrElse recentIds.Count = 0 Then Return output

        Dim sql As New StringBuilder()
        sql.Append("SELECT DISTINCT v.id, v.Codice, v.Ean, v.Descrizione1, v.DescrizioneLunga, v.MarcheDescrizione, v.CategorieDescrizione, v.SettoriDescrizione, ")
        sql.Append("v.Img1, v.Img2, v.Img3, v.Img4, i.Immagine1, i.Immagine2, i.Immagine3, i.Immagine4, i.Immagine5, i.Immagine6, ")
        sql.Append("COALESCE(NULLIF(v.PrezzoPromoIvato,0), NULLIF(v.PrezzoIvato,0), NULLIF(v.PrezzoPromo,0), v.Prezzo, 0) AS PrezzoFinale, ")
        sql.Append("COALESCE(v.Disponibilita,0) AS Disponibilita, COALESCE(v.InOfferta,0) AS InOfferta, COALESCE(v.Vetrina,0) AS Vetrina, COALESCE(v.visite,0) AS Visite ")
        sql.Append("FROM vsuperarticoli v LEFT JOIN immagini i ON i.id = v.id WHERE v.NListino = 1 AND v.id IN (")
        sql.Append(String.Join(",", recentIds.Select(Function(n) n.ToString(CultureInfo.InvariantCulture))))
        sql.Append(")")
        AppendFilterClauses(sql, Nothing, filters, "v")
        sql.Append(" ORDER BY FIELD(v.id,")
        sql.Append(String.Join(",", recentIds.Select(Function(n) n.ToString(CultureInfo.InvariantCulture))))
        sql.Append(") LIMIT ")
        sql.Append(limit.ToString(CultureInfo.InvariantCulture))

        Dim table As DataTable = ExecuteQuery(sql.ToString(), Nothing)
        Dim mapped As List(Of SuggestItem) = MapSuggestions(table, String.Empty)

        output("suggestions") = mapped.Select(Function(item) SerializeItem(item)).ToList()
        output("rank_ids") = mapped.Select(Function(item) item.Id).ToList()
        Return output
    End Function

    Private Function BuildSearchResult(ByVal query As String, ByVal filters As SearchFilters, ByVal limit As Integer) As Dictionary(Of String, Object)
        Dim normalizedQuery As String = NormalizeSearchText(query)
        Dim qExact As String = normalizedQuery
        Dim qPrefix As String = normalizedQuery & "%"
        Dim qContains As String = "%" & normalizedQuery & "%"
        Dim qWord As String = "% " & normalizedQuery & "%"

        Dim parameters As New List(Of DbParameterSpec) From {
            New DbParameterSpec("@qExact", qExact),
            New DbParameterSpec("@qPrefix", qPrefix),
            New DbParameterSpec("@qContains", qContains),
            New DbParameterSpec("@qWord", qWord)
        }

        Dim scoreExpr As String = String.Join(" + ", New String() {
            "(CASE WHEN LOWER(TRIM(COALESCE(v.Codice,''))) = @qExact THEN 100000 ELSE 0 END)",
            "(CASE WHEN LOWER(TRIM(COALESCE(v.Ean,''))) = @qExact THEN 99000 ELSE 0 END)",
            "(CASE WHEN LOWER(TRIM(COALESCE(v.Descrizione1,''))) = @qExact THEN 97000 ELSE 0 END)",
            "(CASE WHEN LOWER(TRIM(COALESCE(v.Codice,''))) LIKE @qPrefix THEN 82000 ELSE 0 END)",
            "(CASE WHEN LOWER(TRIM(COALESCE(v.Ean,''))) LIKE @qPrefix THEN 81000 ELSE 0 END)",
            "(CASE WHEN LOWER(TRIM(COALESCE(v.Descrizione1,''))) LIKE @qPrefix THEN 80000 ELSE 0 END)",
            "(CASE WHEN LOWER(CONCAT(' ', TRIM(COALESCE(v.Codice,'')))) LIKE @qWord THEN 76000 ELSE 0 END)",
            "(CASE WHEN LOWER(CONCAT(' ', TRIM(COALESCE(v.Ean,'')))) LIKE @qWord THEN 75000 ELSE 0 END)",
            "(CASE WHEN LOWER(CONCAT(' ', TRIM(COALESCE(v.Descrizione1,'')))) LIKE @qWord THEN 74000 ELSE 0 END)",
            "(CASE WHEN LOWER(CONCAT(' ', TRIM(COALESCE(v.MarcheDescrizione,'')), ' ', TRIM(COALESCE(v.Descrizione1,'')))) LIKE @qWord THEN 70000 ELSE 0 END)",
            "(CASE WHEN LOWER(COALESCE(v.Descrizione1,'')) LIKE @qContains THEN 35000 ELSE 0 END)",
            "(CASE WHEN LOWER(COALESCE(v.DescrizioneLunga,'')) LIKE @qContains THEN 22000 ELSE 0 END)",
            "(CASE WHEN LOWER(COALESCE(v.MarcheDescrizione,'')) LIKE @qContains THEN 18000 ELSE 0 END)",
            "(CASE WHEN COALESCE(v.Disponibilita,0) > 0 THEN 300 ELSE 0 END)",
            "(CASE WHEN COALESCE(v.InOfferta,0) <> 0 THEN 100 ELSE 0 END)",
            "(CASE WHEN COALESCE(v.Vetrina,0) <> 0 THEN 35 ELSE 0 END)",
            "LEAST(COALESCE(v.visite,0),999)"
        })

        Dim sql As New StringBuilder()
        sql.Append("SELECT DISTINCT v.id, v.Codice, v.Ean, v.Descrizione1, v.DescrizioneLunga, v.MarcheDescrizione, v.CategorieDescrizione, v.SettoriDescrizione, ")
        sql.Append("v.Img1, v.Img2, v.Img3, v.Img4, i.Immagine1, i.Immagine2, i.Immagine3, i.Immagine4, i.Immagine5, i.Immagine6, ")
        sql.Append("COALESCE(NULLIF(v.PrezzoPromoIvato,0), NULLIF(v.PrezzoIvato,0), NULLIF(v.PrezzoPromo,0), v.Prezzo, 0) AS PrezzoFinale, ")
        sql.Append("COALESCE(v.Disponibilita,0) AS Disponibilita, COALESCE(v.InOfferta,0) AS InOfferta, COALESCE(v.Vetrina,0) AS Vetrina, COALESCE(v.visite,0) AS Visite, ")
        sql.Append(scoreExpr)
        sql.Append(" AS RankScore FROM vsuperarticoli v LEFT JOIN immagini i ON i.id = v.id WHERE v.NListino = 1 AND (")
        sql.Append("LOWER(COALESCE(v.Codice,'')) = @qExact OR LOWER(COALESCE(v.Ean,'')) = @qExact OR LOWER(COALESCE(v.Descrizione1,'')) = @qExact OR ")
        sql.Append("LOWER(COALESCE(v.Codice,'')) LIKE @qPrefix OR LOWER(COALESCE(v.Ean,'')) LIKE @qPrefix OR LOWER(COALESCE(v.Descrizione1,'')) LIKE @qPrefix OR ")
        sql.Append("LOWER(CONCAT(' ', COALESCE(v.Codice,''))) LIKE @qWord OR LOWER(CONCAT(' ', COALESCE(v.Ean,''))) LIKE @qWord OR LOWER(CONCAT(' ', COALESCE(v.Descrizione1,''))) LIKE @qWord OR ")
        sql.Append("LOWER(CONCAT(' ', COALESCE(v.MarcheDescrizione,''), ' ', COALESCE(v.Descrizione1,''))) LIKE @qWord OR ")
        sql.Append("LOWER(COALESCE(v.Descrizione1,'')) LIKE @qContains OR LOWER(COALESCE(v.DescrizioneLunga,'')) LIKE @qContains OR LOWER(COALESCE(v.MarcheDescrizione,'')) LIKE @qContains")
        sql.Append(")")
        AppendFilterClauses(sql, parameters, filters, "v")
        sql.Append(" ORDER BY RankScore DESC, COALESCE(v.Disponibilita,0) DESC, COALESCE(v.InOfferta,0) DESC, COALESCE(v.Vetrina,0) DESC, v.id DESC LIMIT ")
        sql.Append(Math.Max(limit, 60).ToString(CultureInfo.InvariantCulture))

        Dim table As DataTable = ExecuteQuery(sql.ToString(), parameters)
        Dim mapped As List(Of SuggestItem) = MapSuggestions(table, query)
        mapped = mapped.Take(limit).ToList()

        Dim strong As New Dictionary(Of String, Object) From {
            {"canRedirect", False},
            {"redirectUrl", String.Empty},
            {"articleId", 0},
            {"matchKind", String.Empty}
        }

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
            {"recent", False},
            {"suggestions", mapped.Select(Function(item) SerializeItem(item)).ToList()},
            {"rank_ids", mapped.Select(Function(item) item.Id).ToList()},
            {"strong", strong}
        }
    End Function

    Private Sub AppendFilterClauses(ByVal sql As StringBuilder, ByVal parameters As List(Of DbParameterSpec), ByVal filters As SearchFilters, ByVal aliasName As String)
        If filters Is Nothing Then Return
        Dim a As String = If(String.IsNullOrWhiteSpace(aliasName), String.Empty, aliasName.Trim() & ".")

        AppendIntFilter(sql, parameters, filters.SettoreId, a & "SettoriId", "@st")
        AppendIntFilter(sql, parameters, filters.CategoriaId, a & "CategorieId", "@ct")
        AppendIntFilter(sql, parameters, filters.TipologiaId, a & "TipologieId", "@tp")
        AppendIntFilter(sql, parameters, filters.GruppoId, a & "GruppiId", "@gr")
        AppendIntFilter(sql, parameters, filters.SottoGruppoId, a & "SottoGruppiId", "@sg")
        AppendIntFilter(sql, parameters, filters.MarcaId, a & "MarcheId", "@mr")
        AppendIntFilter(sql, parameters, filters.ProdottoId, a & "id", "@pid")

        If filters.SoloPromo Then
            sql.Append(" AND COALESCE(" & a & "InOfferta,0) <> 0")
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

    Private Function MapSuggestions(ByVal table As DataTable, ByVal query As String) As List(Of SuggestItem)
        Dim results As New List(Of SuggestItem)()
        If table Is Nothing Then Return results

        For Each row As DataRow In table.Rows
            Dim code As String = SafeString(row("Codice"))
            Dim ean As String = SafeString(row("Ean"))
            Dim title As String = SafeString(row("Descrizione1"))
            Dim brand As String = SafeString(row("MarcheDescrizione"))
            Dim cat As String = SafeString(row("CategorieDescrizione"))
            If String.IsNullOrWhiteSpace(cat) Then cat = SafeString(row("SettoriDescrizione"))

            Dim item As New SuggestItem()
            item.Id = ReadInt(row("id"), 0)
            item.Url = "articolo.aspx?id=" & item.Id.ToString(CultureInfo.InvariantCulture)
            item.Title = title
            item.Brand = brand
            item.Category = cat
            item.Price = FormatPrice(ReadDec(row("PrezzoFinale"), 0D))
            item.Score = If(row.Table.Columns.Contains("RankScore"), ReadInt(row("RankScore"), 0), 0)
            item.MatchKind = DetectMatchKind(code, ean, title, brand, query)
            Dim images As List(Of String) = CollectImages(row)
            item.ImageFallback = If(images.Count > 0, images(0), String.Empty)
            item.Image = BuildPreviewVariant(item.ImageFallback)
            If String.IsNullOrWhiteSpace(item.Image) Then item.Image = item.ImageFallback
            results.Add(item)
        Next

        Return results
    End Function

    Private Function SerializeItem(ByVal item As SuggestItem) As Dictionary(Of String, Object)
        Return New Dictionary(Of String, Object) From {
            {"id", item.Id},
            {"url", item.Url},
            {"title", item.Title},
            {"brand", item.Brand},
            {"category", item.Category},
            {"price", item.Price},
            {"image", item.Image},
            {"image_fallback", item.ImageFallback},
            {"matchKind", item.MatchKind},
            {"score", item.Score}
        }
    End Function

    Private Function DetectMatchKind(ByVal code As String, ByVal ean As String, ByVal title As String, ByVal brand As String, ByVal query As String) As String
        Dim q As String = NormalizeSearchText(query)
        If String.IsNullOrWhiteSpace(q) Then Return "recent"
        If NormalizeSearchText(code) = q Then Return "exact-code"
        If NormalizeSearchText(ean) = q Then Return "exact-ean"
        If NormalizeSearchText(title) = q Then Return "exact-title"
        If NormalizeSearchText(code).StartsWith(q) Then Return "prefix-code"
        If NormalizeSearchText(ean).StartsWith(q) Then Return "prefix-ean"
        If NormalizeSearchText(title).StartsWith(q) Then Return "prefix-title"
        If NormalizeSearchText(brand & " " & title).Contains(q) Then Return "contains-brand-title"
        Return "contains"
    End Function

    Private Function ReadFilters() As SearchFilters
        Return New SearchFilters() With {
            .SettoreId = ReadInt(Request("st"), 0),
            .CategoriaId = ReadInt(Request("ct"), 0),
            .TipologiaId = ReadInt(Request("tp"), 0),
            .GruppoId = ReadInt(Request("gr"), 0),
            .SottoGruppoId = ReadInt(Request("sg"), 0),
            .MarcaId = ReadInt(Request("mr"), 0),
            .ProdottoId = ReadInt(Request("pid"), 0),
            .SoloPromo = (ReadInt(Request("inpromo"), 0) <> 0)
        }
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

    Private Function ReadCookieValue(ByVal name As String) As String
        Dim cookie = Request.Cookies(name)
        If cookie Is Nothing Then Return String.Empty
        Return Convert.ToString(cookie.Value)
    End Function

    Private Function NormalizeQuery(ByVal value As String) As String
        Dim text As String = HttpUtility.HtmlDecode(Convert.ToString(value)).Trim()
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
        Return url
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

    Private Function ReadDec(ByVal raw As Object, ByVal fallback As Decimal) As Decimal
        Dim text As String = Convert.ToString(raw).Trim()
        Dim n As Decimal
        If String.IsNullOrWhiteSpace(text) Then Return fallback
        If text.Contains(",") AndAlso (Not text.Contains(".") OrElse text.LastIndexOf(","c) > text.LastIndexOf("."c)) Then
            If Decimal.TryParse(text, NumberStyles.Any, ItCulture, n) Then Return Math.Round(n, 2, MidpointRounding.AwayFromZero)
        End If
        If Decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, n) Then Return Math.Round(n, 2, MidpointRounding.AwayFromZero)
        If Decimal.TryParse(text, NumberStyles.Any, ItCulture, n) Then Return Math.Round(n, 2, MidpointRounding.AwayFromZero)
        Return fallback
    End Function

    Private Function SafeString(ByVal raw As Object) As String
        Return Convert.ToString(raw).Trim()
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

    Private Class DbParameterSpec
        Public Sub New(ByVal name As String, ByVal value As Object)
            Me.Name = name
            Me.Value = value
        End Sub
        Public Property Name As String
        Public Property Value As Object
    End Class
End Class
