Imports System
Imports System.Text
Imports System.Data
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Web
Imports MySql.Data.MySqlClient

Partial Class search
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        Dim rawSearchTerm As String = Convert.ToString(Request.Form("search"))
        Dim searchTerm As String = SanitizeSearchTerm(rawSearchTerm)

        ' Colore link in base all'azienda
        Dim colore As String = "Black"
        Dim aziendaId As Integer = 0
        If Session("AziendaID") IsNot Nothing Then
            Integer.TryParse(Session("AziendaID").ToString(), aziendaId)
        End If

        Select Case aziendaId
            Case 1
                colore = "#E12825"
            Case 2
                colore = "#FF8C00"
        End Select

        Response.ContentType = "text/html; charset=utf-8"

        Dim sb As New StringBuilder()
        sb.AppendLine("<ul style=""margin-left:0px;"">")

        Dim suggestions As DataTable = Nothing
        Dim products As DataTable = Nothing

        If Not String.IsNullOrEmpty(searchTerm) Then
            Dim words As List(Of String) = SplitWords(searchTerm)

            If words.Count > 0 Then
                Try
                    LoadSearchData(words, suggestions, products)
                Catch ex As Exception
                    ' Se qualcosa va storto sul DB, mostriamo comunque un messaggio decente
                    suggestions = New DataTable()
                    products = New DataTable()
                End Try
            End If
        End If

        ' Suggerimenti "Forse cercavi..."
        If suggestions IsNot Nothing AndAlso suggestions.Rows.Count > 0 Then
            sb.AppendLine("<li style=""height:25px; background-color:#d3d3d3;""><div style=""position:relative;width:500px;top:0px;left:0px;""><a style=""font-size:13px;font-weight:bold;color:#666;background: transparent none repeat scroll;text-decoration: none"">Forse cercavi</a></div></li>")

            For Each row As DataRow In suggestions.Rows
                Dim qString As String = Convert.ToString(row("QString"))
                Dim urlSug As String = "articoli.aspx?q=" & HttpUtility.UrlEncode(qString)
                Dim textSug As String = HttpUtility.HtmlEncode(qString)

                sb.AppendLine(
                    "<li style=""height:20px;""><div style=""margin-top:-4px;position:relative;width:500px;top:0px;left:0px;vertical-align:middle;"">" &
                    "<a href=""" & urlSug & """ style=""font-weight:bold; text-align:left; color:" & colore & ";background: transparent none repeat scroll;text-decoration: none;"" >" &
                    textSug &
                    "</a></div></li>"
                )
            Next
        End If

        ' Prodotti
        If products IsNot Nothing AndAlso products.Rows.Count > 0 Then
            sb.AppendLine("<li style=""height:25px; background-color:#d3d3d3;""><div style=""position:relative;width:500px;top:0px;left:0px;""><a style=""font-size:13px;font-weight:bold;color:#666;background: transparent none repeat scroll;text-decoration: none;  vertical-align:middle;"">Prodotti</a></div></li>")

            For Each row As DataRow In products.Rows
                Dim id As String = Convert.ToString(row("id"))
                Dim tcid As String = Convert.ToString(row("TCid"))
                Dim descrizione As String = Convert.ToString(row("Descrizione1"))
                If descrizione.Length > 200 Then
                    descrizione = descrizione.Substring(0, 200) & "..."
                End If
                Dim nomeFoto As String = Convert.ToString(row("Img1"))

                Dim hrefProd As String = "articolo.aspx?id=" & HttpUtility.UrlEncode(id) & "&TCid=" & HttpUtility.UrlEncode(tcid)
                Dim descrHtml As String = HttpUtility.HtmlEncode(descrizione)
                Dim imgSrc As String = "Public/foto/" & HttpUtility.UrlEncode(nomeFoto)

                sb.AppendLine(
                    "<li><div style=""position:relative;width:500px;top:0px;left:0px;"">" &
                    "<div style=""position: absolute;width:50px;top:0px;left:0px;""><img style=""height:40px;width:40px border-width: 0px;"" width=""40px"" src=""" & imgSrc & """></div> " &
                    "<div style=""width:440px;position: absolute; top: 0px; left:60px; right: 0px; text-align:left;"">" &
                    "<a href=""" & hrefProd & """ style=""font-weight:bold;color:" & colore & ";background: transparent none repeat scroll;text-decoration: none"" >" &
                    descrHtml &
                    "</a></div></div></li>"
                )
            Next
        End If

        ' Messaggio finale: tutti i risultati / nessun risultato
        Dim searchTermForDisplay As String = HttpUtility.HtmlEncode(searchTerm)

        If String.IsNullOrEmpty(searchTerm) Then
            sb.AppendLine("<li style=""height:25px;background-color:#d3d3d3;""><div style=""position:relative;width:500px;top:0px;left:0px;""><a style=""font-size:12px;font-weight:bold;color:#666;background: transparent none repeat scroll;text-decoration: none"">Nessun risultato</a></div></li>")
        Else
            If products IsNot Nothing AndAlso products.Rows.Count > 0 Then
                Dim urlAll As String = "articoli.aspx?q=" & HttpUtility.UrlEncode(searchTerm)
                sb.AppendLine(
                    "<li style=""height:25px;background-color:#d3d3d3;""><div style=""position:relative;width:500px;top:0px;left:0px;"">" &
                    "<a href=""" & urlAll & """ style=""font-size:15px;font-weight:bold;color:#666;background: transparent none repeat scroll;text-decoration: none"">" &
                    "Visualizza tutti i risultati per """ & searchTermForDisplay & """" &
                    "</a></div></li>"
                )
            Else
                sb.AppendLine(
                    "<li style=""height:25px;background-color:#d3d3d3;""><div style=""position:relative;width:500px;top:0px;left:0px;"">" &
                    "<a style=""font-size:12px;font-weight:bold;color:#666;background: transparent none repeat scroll;text-decoration: none"">" &
                    "Nessun risultato per """ & searchTermForDisplay & """" &
                    "</a></div></li>"
                )
            End If
        End If

        sb.AppendLine("</ul>")

        Response.Write(sb.ToString())
    End Sub

    Private Function SanitizeSearchTerm(raw As String) As String
        If String.IsNullOrWhiteSpace(raw) Then
            Return String.Empty
        End If

        Dim cleaned As String = raw.Trim()

        ' Stessa logica di prima, ma qui è solo per "pulizia" estetica, non per sicurezza
        cleaned = cleaned.Replace("'", String.Empty)
        cleaned = cleaned.Replace("*", String.Empty)
        cleaned = cleaned.Replace("&", String.Empty)
        cleaned = cleaned.Replace("#", String.Empty)
        cleaned = cleaned.Replace(vbCr, " ").Replace(vbLf, " ")

        ' Evitiamo ricerche assurde gigantesche
        If cleaned.Length > 100 Then
            cleaned = cleaned.Substring(0, 100)
        End If

        Return cleaned
    End Function

    Private Function SplitWords(term As String) As List(Of String)
        Dim result As New List(Of String)()

        If String.IsNullOrWhiteSpace(term) Then
            Return result
        End If

        Dim parts As String() = term.Split(New Char() {" "c, vbTab}, StringSplitOptions.RemoveEmptyEntries)
        For Each p As String In parts
            Dim w As String = p.Trim()
            If w.Length > 0 Then
                result.Add(w)
            End If
        Next

        Return result
    End Function

    Private Sub LoadSearchData(words As List(Of String), ByRef suggestions As DataTable, ByRef products As DataTable)
        suggestions = New DataTable()
        products = New DataTable()

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(connString)
            conn.Open()

            ' Gestione eventuale "compressione" tabella query_string (ogni 50 ricerche)
            MaybeCompressQueryString(conn)

            ' SUGGERIMENTI (conteggia_querystring)
            Using cmdSug As New MySqlCommand()
                cmdSug.Connection = conn
                Dim sbSug As New StringBuilder()
                sbSug.Append("SELECT QString, Conteggio FROM conteggia_querystring WHERE 1=1")

                cmdSug.Parameters.Clear()

                For i As Integer = 0 To words.Count - 1
                    Dim paramName As String = "?w" & i.ToString()
                    sbSug.Append(" AND QString LIKE " & paramName)
                    cmdSug.Parameters.AddWithValue(paramName, "%" & words(i) & "%")
                Next

                Dim maxSug As Integer = If(words.Count > 1, 5, 4)
                sbSug.Append(" ORDER BY Conteggio LIMIT " & maxSug.ToString())

                cmdSug.CommandText = sbSug.ToString()

                Using daSug As New MySqlDataAdapter(cmdSug)
                    daSug.Fill(suggestions)
                End Using
            End Using

            ' PRODOTTI (varticoligiacenze)
            Using cmdProd As New MySqlCommand()
                cmdProd.Connection = conn
                Dim sbProd As New StringBuilder()
                sbProd.Append("SELECT id, TCid, Descrizione1, Img1, Giacenza, Visite, Codice FROM varticoligiacenze WHERE 1=1")

                cmdProd.Parameters.Clear()

                For i As Integer = 0 To words.Count - 1
                    Dim paramName As String = "?p" & i.ToString()
                    sbProd.Append(" AND (Descrizione1 LIKE " & paramName & " OR Codice LIKE " & paramName & ")")
                    cmdProd.Parameters.AddWithValue(paramName, "%" & words(i) & "%")
                Next

                sbProd.Append(" ORDER BY Giacenza DESC LIMIT 6")

                cmdProd.CommandText = sbProd.ToString()

                Using daProd As New MySqlDataAdapter(cmdProd)
                    daProd.Fill(products)
                End Using
            End Using
        End Using
    End Sub

    Private Sub MaybeCompressQueryString(conn As MySqlConnection)
        Try
            Dim count As Integer = 0

            ' Conteggio righe in query_string
            Using cmdCount As New MySqlCommand("SELECT COUNT(*) AS RECORD_COUNT FROM query_string", conn)
                Dim obj As Object = cmdCount.ExecuteScalar()
                If obj IsNot Nothing AndAlso obj IsNot DBNull.Value Then
                    Integer.TryParse(obj.ToString(), count)
                End If
            End Using

            If count <= 0 OrElse (count Mod 50) <> 0 Then
                Exit Sub
            End If

            ' Carico i dati aggregati da conteggia_querystring
            Dim elenco As New List(Of KeyValuePair(Of String, Integer))()

            Using cmdSel As New MySqlCommand("SELECT QString, Conteggio FROM conteggia_querystring", conn)
                Using dr As MySqlDataReader = cmdSel.ExecuteReader()
                    While dr.Read()
                        Dim qs As String = dr("QString").ToString()
                        Dim c As Integer = 0
                        Integer.TryParse(dr("Conteggio").ToString(), c)
                        elenco.Add(New KeyValuePair(Of String, Integer)(qs, c))
                    End While
                End Using
            End Using

            ' Svuoto la tabella query_string
            Using cmdDel As New MySqlCommand("DELETE FROM query_string", conn)
                cmdDel.ExecuteNonQuery()
            End Using

            ' Re-inserisco i valori aggregati
            If elenco.Count > 0 Then
                Using cmdIns As New MySqlCommand("INSERT INTO query_string (QString, Conteggio) VALUES (?s, ?c)", conn)
                    cmdIns.Parameters.Add("?s", MySqlDbType.VarChar)
                    cmdIns.Parameters.Add("?c", MySqlDbType.Int32)

                    For Each item As KeyValuePair(Of String, Integer) In elenco
                        cmdIns.Parameters("?s").Value = item.Key
                        cmdIns.Parameters("?c").Value = item.Value
                        cmdIns.ExecuteNonQuery()
                    Next
                End Using
            End If

        Catch ex As Exception
            ' Errori sulla parte statistica non devono bloccare la ricerca
        End Try
    End Sub

End Class
