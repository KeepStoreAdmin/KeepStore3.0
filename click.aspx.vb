Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Globalization

Partial Class click
    Inherits System.Web.UI.Page

    Private Const FALLBACK_URL As String = "~/Default.aspx"

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        ' ===========================
        ' INPUT HARDENING (id)
        ' ===========================
        Dim id_pubblicita As Integer = 0
        If Not Integer.TryParse(Request.QueryString("id"), id_pubblicita) OrElse id_pubblicita <= 0 Then
            SafeRedirect(ResolveUrl(FALLBACK_URL))
            Return
        End If

        ' IP utente (compatibile con reverse proxy: usa il primo X-Forwarded-For se presente)
        Dim ip_utente As String = GetClientIp()

        ' Nel caso l'utente non sia loggato
        Dim id_utente As Integer = 0
        If Me.Session("UtentiId") IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Me.Session("UtentiId")), id_utente)
        End If
        If (id_utente <= 0) Then
            id_utente = -1
        End If

        Dim DataOdierna As String = Date.Today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)

        Dim params As New Dictionary(Of String, String)
        params.Add("@dataOdierna", DataOdierna)
        params.Add("@ipUtente", ip_utente)
        params.Add("@idPubblicità", id_pubblicita.ToString(CultureInfo.InvariantCulture))
        params.Add("@UtenteId", id_utente.ToString(CultureInfo.InvariantCulture))

        ' ===========================
        ' CLICK TRACKING (1 click / ip / giorno)
        ' ===========================
        Dim drClicks = ExecuteQueryGetDataReader("id", "pubblicita_click",
            "WHERE (data_click=@dataOdierna) AND (ip_utente=@ipUtente) AND (id_pubblicita=@idPubblicità)",
            params)

        Dim pubblicitaClickExists As Boolean = (drClicks IsNot Nothing AndAlso drClicks.Count > 0)

        If Not pubblicitaClickExists Then
            ExecuteInsert("pubblicita_click", "id_utente,ip_utente,id_pubblicita,data_click",
                          "@UtenteId, @ipUtente, @idPubblicità, @dataOdierna", params)

            ExecuteUpdate("pubblicitaV2", "numero_click_attuale=numero_click_attuale+1",
                          "WHERE id = @idPubblicità", params)
        End If

        ' ===========================
        ' RECUPERO LINK + SAFE REDIRECT
        ' ===========================
        Dim drLink = ExecuteQueryGetDataReader("link", "pubblicitav2", "WHERE id = @idPubblicità LIMIT 1", params)

        Dim rawLink As String = ""
        Try
            If drLink IsNot Nothing AndAlso drLink.Count > 0 Then
                If drLink(0) IsNot Nothing AndAlso drLink(0).ContainsKey("link") AndAlso drLink(0)("link") IsNot Nothing AndAlso Not IsDBNull(drLink(0)("link")) Then
                    rawLink = drLink(0)("link").ToString()
                End If
            End If
        Catch
            rawLink = ""
        End Try

        Dim redirectUrl As String = BuildSafeRedirectUrl(rawLink)

        If String.IsNullOrEmpty(redirectUrl) Then
            redirectUrl = ResolveUrl(FALLBACK_URL)
        End If

        SafeRedirect(redirectUrl)
    End Sub

    ' ===========================
    ' SAFE REDIRECT (riduce open redirect / XSS)
    ' - consente SOLO:
    '   * URL assoluti http/https
    '   * URL relativi (/ oppure ~/)
    ' - blocca javascript:, data:, vbscript:, CRLF, URL vuoti
    ' ===========================
    Private Function BuildSafeRedirectUrl(ByVal rawLink As String) As String
        If String.IsNullOrWhiteSpace(rawLink) Then Return ""

        Dim s As String = rawLink.Trim()

        ' prevenzione header injection
        If s.Contains(vbCr) OrElse s.Contains(vbLf) Then Return ""

        If s = "#" Then
            Return ResolveUrl(FALLBACK_URL)
        End If

        ' URL relativi (interni)
        If s.StartsWith("/") OrElse s.StartsWith("~/") Then
            If s.StartsWith("~/") Then
                Return ResolveUrl(s)
            End If
            Return s
        End If

        ' Blocca schemi pericolosi espliciti
        Dim lower As String = s.ToLowerInvariant()
        If lower.StartsWith("javascript:") OrElse lower.StartsWith("data:") OrElse lower.StartsWith("vbscript:") Then
            Return ""
        End If

        ' Assoluto già completo
        Dim uri As Uri = Nothing
        If Uri.TryCreate(s, UriKind.Absolute, uri) Then
            If uri.Scheme = Uri.UriSchemeHttp OrElse uri.Scheme = Uri.UriSchemeHttps Then
                Return uri.ToString()
            End If
            Return ""
        End If

        ' Se manca lo schema, prova ad aggiungere http:// (mantiene la compatibilità con i dati legacy)
        If Uri.TryCreate("http://" & s, UriKind.Absolute, uri) Then
            If uri.Scheme = Uri.UriSchemeHttp OrElse uri.Scheme = Uri.UriSchemeHttps Then
                Return uri.ToString()
            End If
        End If

        Return ""
    End Function

    Private Sub SafeRedirect(ByVal url As String)
        ' Evita ThreadAbortException: Redirect(False) + CompleteRequest()
        Response.Redirect(url, False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Function GetClientIp() As String
        Try
            Dim xff As String = Request.Headers("X-Forwarded-For")
            If Not String.IsNullOrWhiteSpace(xff) Then
                Dim parts As String() = xff.Split(","c)
                If parts IsNot Nothing AndAlso parts.Length > 0 Then
                    Dim candidate As String = parts(0).Trim()
                    If candidate.Length > 0 AndAlso candidate.Length <= 45 Then
                        Return candidate
                    End If
                End If
            End If
        Catch
        End Try

        Return Convert.ToString(Request.UserHostAddress)
    End Function

    Protected Function ExecuteInsert(ByVal table As String, ByVal fields As String, Optional ByVal values As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "INSERT INTO " & table & " (" & fields & ") VALUES (" & values & ")"
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteDelete(ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "DELETE FROM " & table & " " & wherePart
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & " " & wherePart
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim conn As New MySqlConnection
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not String.IsNullOrEmpty(connectionString) Then
                conn.ConnectionString = connectionString
                conn.Open()

                Dim cmd As New MySqlCommand
                cmd.Connection = conn
                cmd.CommandText = sqlString

                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        If paramName = "?parPrezzo" OrElse paramName = "?parPrezzoIvato" Then
                            cmd.Parameters.Add(paramName, MySqlDbType.Double).Value = Convert.ToDecimal(params(paramName), CultureInfo.InvariantCulture)
                        Else
                            cmd.Parameters.AddWithValue(paramName, params(paramName))
                        End If
                    Next
                End If

                If isStoredProcedure Then
                    cmd.CommandType = CommandType.StoredProcedure
                    cmd.Parameters.AddWithValue("?parRetVal", "0")
                    cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
                Else
                    cmd.CommandType = CommandType.Text
                End If

                cmd.ExecuteNonQuery()
                cmd.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
    End Function

    Protected Sub ExecuteStoredProcedure(ByVal storedProcedure As String, Optional ByVal params As Dictionary(Of String, String) = Nothing)
        ExecuteNonQuery(True, storedProcedure, params)
    End Sub

    Protected Function ExecuteQueryGetDataReader(ByVal fields As String, ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As List(Of Dictionary(Of String, Object))
        Dim sqlString As String = "SELECT " & fields & " FROM " & table & " " & wherePart
        Dim dr As MySqlDataReader
        Dim result As New List(Of Dictionary(Of String, Object))
        Dim conn As New MySqlConnection
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not String.IsNullOrEmpty(connectionString) Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd = New MySqlCommand With {
                    .Connection = conn,
                    .CommandType = CommandType.Text,
                    .CommandText = sqlString
                }
                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If
                dr = cmd.ExecuteReader()

                While dr.Read()
                    Dim row As New Dictionary(Of String, Object)()

                    ' Per ogni colonna nella riga, aggiungi la colonna al dizionario
                    For i As Integer = 0 To dr.FieldCount - 1
                        Dim columnName As String = dr.GetName(i)
                        Dim value As Object = dr.GetValue(i)
                        row.Add(columnName, value)
                    Next

                    result.Add(row)
                End While

                dr.Close()
                dr.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
        Return result
    End Function

End Class
