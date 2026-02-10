Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Web
Imports System.Web.Script.Serialization
Imports MySql.Data.MySqlClient

Public Class SearchSuggest
    Implements IHttpHandler

    Public ReadOnly Property IsReusable() As Boolean Implements IHttpHandler.IsReusable
        Get
            Return False
        End Get
    End Property

    Public Sub ProcessRequest(context As HttpContext) Implements IHttpHandler.ProcessRequest
        context.Response.ContentType = "application/json; charset=utf-8"
        context.Response.Cache.SetCacheability(HttpCacheability.NoCache)
        context.Response.Cache.SetNoStore()

        Dim q As String = Convert.ToString(context.Request("q"))
        q = NormalizeQuery(q, 60)

        Dim limit As Integer = 10
        Integer.TryParse(Convert.ToString(context.Request("limit")), limit)
        If limit < 1 Then limit = 1
        If limit > 20 Then limit = 20

        Dim list As New List(Of Object)()

        If q.Length < 2 Then
            WriteJson(context, list)
            Return
        End If

        ' 1) Keywords (ks_keywords) - autocomplete
        Try
            Using cn As New MySqlConnection(GetConnString())
                cn.Open()

                Using cmd As New MySqlCommand("SELECT word, counter FROM ks_keywords WHERE word LIKE @p ORDER BY counter DESC, word ASC LIMIT @lim;", cn)
                    cmd.Parameters.AddWithValue("@p", q & "%")
                    cmd.Parameters.AddWithValue("@lim", limit)

                    Using rd = cmd.ExecuteReader()
                        While rd.Read()
                            Dim w As String = SafeStr(rd, 0)
                            If w <> "" Then
                                list.Add(New With {
                                    .t = w,
                                    .url = "/articoli.aspx?q=" & HttpUtility.UrlEncode(w),
                                    .type = "Suggerimento"
                                })
                            End If
                        End While
                    End Using
                End Using

                ' 2) Products (articoli) - top matches
                Using cmd2 As New MySqlCommand("SELECT id, Codice, Descrizione1 FROM articoli WHERE (Codice LIKE @pfx OR Ean LIKE @pfx OR Descrizione1 LIKE @like) ORDER BY (CASE WHEN Codice LIKE @pfx THEN 2 WHEN Ean LIKE @pfx THEN 2 ELSE 0 END) DESC, id DESC LIMIT @lim;", cn)
                    cmd2.Parameters.AddWithValue("@pfx", q & "%")
                    cmd2.Parameters.AddWithValue("@like", "%" & q & "%")
                    cmd2.Parameters.AddWithValue("@lim", limit)

                    Using rd2 = cmd2.ExecuteReader()
                        While rd2.Read()
                            Dim id As Integer = SafeInt(rd2, 0)
                            Dim codice As String = SafeStr(rd2, 1)
                            Dim desc1 As String = SafeStr(rd2, 2)
                            Dim label As String = TrimProductLabel(codice, desc1)

                            list.Add(New With {
                                .t = label,
                                .url = "/articolo.aspx?id=" & id.ToString(),
                                .type = "Prodotto"
                            })
                        End While
                    End Using
                End Using

            End Using
        Catch ex As Exception
            ' Fail closed: return empty json, no error leak
            list = New List(Of Object)()
        End Try

        WriteJson(context, list)
    End Sub

    Private Shared Sub WriteJson(ctx As HttpContext, obj As Object)
        Dim js As New JavaScriptSerializer()
        ctx.Response.Write(js.Serialize(obj))
    End Sub

    Private Shared Function GetConnString() As String
        Dim cs = ConfigurationManager.ConnectionStrings("taikun")
        If cs Is Nothing OrElse String.IsNullOrEmpty(cs.ConnectionString) Then
            Return ConfigurationManager.ConnectionStrings(0).ConnectionString
        End If
        Return cs.ConnectionString
    End Function

    Private Shared Function NormalizeQuery(q As String, maxLen As Integer) As String
        If q Is Nothing Then Return ""
        q = q.Trim()
        If q.Length > maxLen Then q = q.Substring(0, maxLen)
        Return q
    End Function

    Private Shared Function SafeStr(r As IDataRecord, idx As Integer) As String
        If r.IsDBNull(idx) Then Return ""
        Return Convert.ToString(r.GetValue(idx))
    End Function

    Private Shared Function SafeInt(r As IDataRecord, idx As Integer) As Integer
        If r.IsDBNull(idx) Then Return 0
        Dim o = r.GetValue(idx)
        Dim n As Integer = 0
        Integer.TryParse(Convert.ToString(o), n)
        Return n
    End Function

    Private Shared Function TrimProductLabel(codice As String, descr As String) As String
        Dim s As String = ""
        If codice IsNot Nothing AndAlso codice <> "" Then s = codice & " - "
        If descr IsNot Nothing Then s &= descr
        If s.Length > 80 Then s = s.Substring(0, 80) & "…"
        Return s.Trim()
    End Function
End Class
