Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
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

        ' Parametro standard per autocomplete: term (fallback q)
        Dim termRaw As String = ""
        If Request.QueryString("term") IsNot Nothing Then termRaw = Request.QueryString("term")
        If String.IsNullOrEmpty(termRaw) AndAlso Request.QueryString("q") IsNot Nothing Then termRaw = Request.QueryString("q")

        termRaw = If(termRaw, "").Trim()

        If termRaw.Length = 0 Then
            Response.Write("[]")
            Response.End()
            Return
        End If

        ' Hardening base per evitare input troppo lunghi / caratteri anomali
        If termRaw.Length > 60 Then termRaw = termRaw.Substring(0, 60)
        termRaw = Regex.Replace(termRaw, "[^0-9A-Za-zÀ-ÿ\s\-\+\.,/]", " ")
        termRaw = Regex.Replace(termRaw, "\s+", " ").Trim()

        Dim listino As Integer = 0
        If Session("Listino") IsNot Nothing Then
            Integer.TryParse(Session("Listino").ToString(), listino)
        End If
        If listino <= 0 Then listino = 1

        Dim results As New List(Of Object)()

        Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Dim sql As String =
            "SELECT a.id, a.Codice, a.Descrizione1 " &
            "FROM varticoligiacenze a " &
            "LEFT JOIN articoli_listini al ON al.ArticoliId = a.id AND al.NListino = ?listino " &
            "WHERE (a.Descrizione1 LIKE ?term OR a.Codice LIKE ?term) " &
            "ORDER BY a.Visite DESC " &
            "LIMIT 10;"

        Try
            Using cn As New MySqlConnection(cs)
                cn.Open()

                Using cmd As New MySqlCommand(sql, cn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.AddWithValue("?listino", listino)
                    cmd.Parameters.AddWithValue("?term", "%" & termRaw & "%")

                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            Dim id As Integer = 0
                            Integer.TryParse(Convert.ToString(r("id")), id)

                            Dim codice As String = Convert.ToString(r("Codice"))
                            Dim descr As String = Convert.ToString(r("Descrizione1"))

                            Dim label As String = (codice & " - " & descr).Trim()
                            Dim value As String = (codice & " " & descr).Trim()

                            results.Add(New With {
                                .id = id,
                                .codice = codice,
                                .descrizione = descr,
                                .label = label,
                                .value = value
                            })
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' In caso di errore DB, ritorna lista vuota (endpoint "best effort")
            results = New List(Of Object)()
        End Try

        Dim js As New JavaScriptSerializer()
        Response.Write(js.Serialize(results))
        Response.End()

    End Sub

End Class
