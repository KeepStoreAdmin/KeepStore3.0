Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Script.Serialization
Imports MySql.Data.MySqlClient

Partial Class search_suggest
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.Clear()
        Response.ContentType = "application/json; charset=utf-8"
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()

        Dim termRaw As String = Convert.ToString(Request.QueryString("term"))
        If String.IsNullOrWhiteSpace(termRaw) Then
            termRaw = Convert.ToString(Request.QueryString("q"))
        End If

        termRaw = NormalizeTerm(termRaw)
        If termRaw.Length < 2 Then
            WriteJson(New List(Of Object)())
            Return
        End If

        Dim limit As Integer = 10
        Integer.TryParse(Convert.ToString(Request.QueryString("limit")), limit)
        If limit < 1 Then limit = 1
        If limit > 12 Then limit = 12

        Dim sectorId As Integer = 0
        Integer.TryParse(Convert.ToString(Request.QueryString("st")), sectorId)

        Dim results As New List(Of Object)()

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()

                AppendSectorSuggestions(conn, results, termRaw, 3)
                AppendProductSuggestions(conn, results, termRaw, sectorId, limit)
            End Using
        Catch
            results = New List(Of Object)()
        End Try

        WriteJson(results)
    End Sub

    Private Sub AppendSectorSuggestions(ByVal conn As MySqlConnection, ByVal results As List(Of Object), ByVal term As String, ByVal maxItems As Integer)
        Using cmd As New MySqlCommand("SELECT id, Descrizione FROM settori WHERE COALESCE(Abilitato,0)=1 AND Descrizione LIKE @prefix ORDER BY COALESCE(Predefinito,0) DESC, COALESCE(Ordinamento,0) ASC, Descrizione ASC LIMIT " & maxItems.ToString(), conn)
            cmd.Parameters.AddWithValue("@prefix", term & "%")
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    results.Add(New With {
                        .id = SafeInt(reader, "id"),
                        .t = SafeString(reader, "Descrizione"),
                        .label = SafeString(reader, "Descrizione"),
                        .value = SafeString(reader, "Descrizione"),
                        .url = "/articoli.aspx?st=" & SafeInt(reader, "id").ToString(),
                        .type = "Reparto"
                    })
                End While
            End Using
        End Using
    End Sub

    Private Sub AppendProductSuggestions(ByVal conn As MySqlConnection,
                                         ByVal results As List(Of Object),
                                         ByVal term As String,
                                         ByVal sectorId As Integer,
                                         ByVal limit As Integer)
        Dim exactTerm As String = term.ToLowerInvariant()
        Dim prefix As String = term & "%"
        Dim contains As String = "%" & term & "%"

        Dim sql As New StringBuilder()
        sql.Append("SELECT ")
        sql.Append("v.id, v.Codice, v.Ean, v.Descrizione1, IFNULL(v.DescrizioneLunga,'') AS DescrizioneLunga, IFNULL(v.MarcheDescrizione,'') AS MarcheDescrizione, ")
        sql.Append("(CASE ")
        sql.Append(" WHEN LOWER(v.Codice)=@exact THEN 1000")
        sql.Append(" WHEN LOWER(v.Ean)=@exact THEN 980")
        sql.Append(" WHEN LOWER(v.Descrizione1)=@exact THEN 920")
        sql.Append(" WHEN LOWER(CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione1,'')))=@exact THEN 900")
        sql.Append(" WHEN v.Codice LIKE @prefix THEN 860")
        sql.Append(" WHEN v.Ean LIKE @prefix THEN 840")
        sql.Append(" WHEN v.Descrizione1 LIKE @prefix THEN 760")
        sql.Append(" WHEN CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione1,'')) LIKE @prefix THEN 720")
        sql.Append(" WHEN v.Descrizione1 LIKE @contains THEN 620")
        sql.Append(" WHEN v.DescrizioneLunga LIKE @contains THEN 520")
        sql.Append(" WHEN CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione1,'')) LIKE @contains THEN 660")
        sql.Append(" WHEN CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione2,'')) LIKE @contains THEN 560")
        sql.Append(" ELSE 0 END) AS Score ")
        sql.Append("FROM vsuperarticoli v ")
        sql.Append("WHERE COALESCE(v.NListino,1)=@listino ")
        sql.Append("AND (")
        sql.Append(" v.Codice LIKE @contains OR v.Ean LIKE @contains OR v.Descrizione1 LIKE @contains OR v.DescrizioneLunga LIKE @contains ")
        sql.Append(" OR CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione1,'')) LIKE @contains ")
        sql.Append(" OR CONCAT(IFNULL(v.MarcheDescrizione,''),' ',IFNULL(v.Descrizione2,'')) LIKE @contains")
        sql.Append(") ")
        If sectorId > 0 Then
            sql.Append("AND COALESCE(v.SettoriId,0)=@sectorId ")
        End If
        sql.Append("GROUP BY v.id ")
        sql.Append("ORDER BY Score DESC, COALESCE(v.Visite,0) DESC, COALESCE(v.DataCreazione,CURDATE()) DESC, v.id DESC ")
        sql.Append("LIMIT ").Append(limit.ToString())

        Using cmd As New MySqlCommand(sql.ToString(), conn)
            cmd.Parameters.AddWithValue("@exact", exactTerm)
            cmd.Parameters.AddWithValue("@prefix", prefix)
            cmd.Parameters.AddWithValue("@contains", contains)
            cmd.Parameters.AddWithValue("@listino", GetCurrentListino())
            If sectorId > 0 Then
                cmd.Parameters.AddWithValue("@sectorId", sectorId)
            End If

            Using reader As MySqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    Dim id As Integer = SafeInt(reader, "id")
                    Dim code As String = SafeString(reader, "Codice")
                    Dim title As String = SafeString(reader, "Descrizione1")
                    Dim brand As String = SafeString(reader, "MarcheDescrizione")
                    Dim label As String = title
                    If Not String.IsNullOrWhiteSpace(brand) Then
                        label = brand & " - " & title
                    End If

                    Dim meta As String = code
                    If String.IsNullOrWhiteSpace(meta) Then
                        meta = SafeString(reader, "Ean")
                    End If

                    results.Add(New With {
                        .id = id,
                        .t = label,
                        .label = label,
                        .value = label,
                        .meta = meta,
                        .url = "/articolo.aspx?id=" & id.ToString(),
                        .type = "Prodotto"
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
        Dim value As String = If(raw, String.Empty).Trim()
        If value.Length > 60 Then
            value = value.Substring(0, 60)
        End If
        value = Regex.Replace(value, "[^\p{L}\p{Nd}\s\-\+\.,/&'()]", " ")
        value = Regex.Replace(value, "\s+", " ").Trim()
        Return value
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
        Dim n As Integer = 0
        Integer.TryParse(SafeString(reader, fieldName), n)
        Return n
    End Function

    Private Sub WriteJson(ByVal obj As Object)
        Dim js As New JavaScriptSerializer()
        Response.Write(js.Serialize(obj))
        Response.End()
    End Sub
End Class
