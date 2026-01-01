Imports System
Imports System.Data
Imports System.Configuration
Imports MySql.Data.MySqlClient

Partial Class click
    Inherits System.Web.UI.Page

    ' Limite attuale nel DB: pubblicita_click.ip_utente è varchar(15) -> IPv4.
    Private Const IP_MAX_LEN As Integer = 15

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        ' Evita cache su endpoint di redirect/tracking
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()

        Try
            ' 1) Validazione parametro ID
            Dim id_pubblicita As Integer = 0
            If Not Integer.TryParse(Request.QueryString("id"), id_pubblicita) OrElse id_pubblicita <= 0 Then
                RedirectToHome()
                Return
            End If

            ' 2) Riduzione rischio open-redirect: richiedo che la sessione azienda sia presente
            Dim aziendaId As Integer = 0
            If Session("AziendaID") IsNot Nothing Then
                Integer.TryParse(Session("AziendaID").ToString(), aziendaId)
            End If

            If aziendaId <= 0 Then
                ' Se manca la sessione, non permetto redirect esterni
                RedirectToHome()
                Return
            End If

            ' Utente (se non loggato = -1)
            Dim id_utente As Integer = -1
            If Session("UtentiId") IsNot Nothing Then
                Dim tmp As Integer = 0
                If Integer.TryParse(Session("UtentiId").ToString(), tmp) AndAlso tmp > 0 Then
                    id_utente = tmp
                End If
            End If

            ' Data odierna in formato compatibile
            Dim dataOdierna As String = Date.Today.ToString("yyyy-MM-dd")

            ' IP (compatibile con varchar(15))
            Dim ip_utente As String = NormalizeIpForDb(Request.UserHostAddress)

            ' 3) Recupero link SOLO se banner valido/attivo per questa azienda
            Dim bannerParams As New Dictionary(Of String, Object) From {
                {"@idPubblicita", id_pubblicita},
                {"@AziendaID", aziendaId}
            }

            Dim bannerSql As String =
                "SELECT link " &
                "FROM pubblicitav2 " &
                "WHERE id = @idPubblicita " &
                "  AND abilitato = 1 " &
                "  AND id_Azienda = @AziendaID " &
                "  AND (data_inizio_pubblicazione IS NULL OR data_inizio_pubblicazione <= CURDATE()) " &
                "  AND (data_fine_pubblicazione IS NULL OR data_fine_pubblicazione >= CURDATE()) " &
                "  AND ((numero_click_attuale <= limite_click) OR (limite_click = -1)) " &
                "  AND ((numero_impressioni_attuale <= limite_impressioni) OR (limite_impressioni = -1)) " &
                "LIMIT 1"

            Dim bannerRows As List(Of Dictionary(Of String, Object)) = ExecuteQueryGetDataReader(bannerSql, bannerParams)
            If bannerRows Is Nothing OrElse bannerRows.Count = 0 Then
                RedirectToHome()
                Return
            End If

            Dim rawLink As String = Convert.ToString(bannerRows(0)("link"))
            Dim safeRedirectUrl As String = BuildSafeRedirectUrl(rawLink)

            If String.IsNullOrEmpty(safeRedirectUrl) Then
                RedirectToHome()
                Return
            End If

            ' 4) Tracking click (1 volta al giorno per IP + banner)
            Dim clickParams As New Dictionary(Of String, Object) From {
                {"@dataOdierna", dataOdierna},
                {"@ipUtente", ip_utente},
                {"@idPubblicita", id_pubblicita}
            }

            Dim clickExistsSql As String =
                "SELECT id FROM pubblicita_click " &
                "WHERE data_click = @dataOdierna " &
                "  AND ip_utente = @ipUtente " &
                "  AND id_pubblicita = @idPubblicita " &
                "LIMIT 1"

            Dim clickRows As List(Of Dictionary(Of String, Object)) = ExecuteQueryGetDataReader(clickExistsSql, clickParams)
            Dim clickAlreadyLogged As Boolean = (clickRows IsNot Nothing AndAlso clickRows.Count > 0)

            If Not clickAlreadyLogged Then
                ' Inserimento click
                clickParams.Add("@UtenteId", id_utente)

                Dim insertSql As String =
                    "INSERT INTO pubblicita_click (id_utente, ip_utente, id_pubblicita, data_click) " &
                    "VALUES (@UtenteId, @ipUtente, @idPubblicita, @dataOdierna)"

                ExecuteNonQuery(insertSql, clickParams)

                ' Incremento contatore click sul banner
                Dim updateSql As String =
                    "UPDATE pubblicitav2 SET numero_click_attuale = numero_click_attuale + 1 " &
                    "WHERE id = @idPubblicita"

                ExecuteNonQuery(updateSql, bannerParams)
            End If

            ' 5) Redirect finale
            Response.Redirect(safeRedirectUrl, False)
            Context.ApplicationInstance.CompleteRequest()

        Catch ex As Exception
            ' Non esporre errori: rimando alla Home
            RedirectToHome()
        End Try

    End Sub

    ' ==========================
    ' Helpers sicurezza
    ' ==========================

    Private Sub RedirectToHome()
        Response.Redirect(ResolveUrl("~/Default.aspx"), False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    ' Normalizza IP per DB varchar(15):
    ' - Gestisce IPv4-mapped IPv6 (::ffff:1.2.3.4)
    ' - Trunca in sicurezza se troppo lungo
    Private Function NormalizeIpForDb(ByVal ip As String) As String
        If ip Is Nothing Then Return ""
        Dim s As String = ip.Trim()

        If s = "" Then Return ""

        ' IPv4-mapped IPv6 -> prendo l'ultima parte dopo l'ultimo ":"
        If s.Contains(":") AndAlso s.Contains(".") Then
            Dim lastColon As Integer = s.LastIndexOf(":"c)
            If lastColon >= 0 AndAlso lastColon < s.Length - 1 Then
                Dim candidate As String = s.Substring(lastColon + 1).Trim()
                If candidate.Length > 0 Then
                    s = candidate
                End If
            End If
        End If

        If s.Length > IP_MAX_LEN Then
            s = s.Substring(0, IP_MAX_LEN)
        End If

        Return s
    End Function

    ' Consente:
    ' - URL relativi interni: "/" o "~/" (li risolve sul sito)
    ' - URL assoluti http/https (qualsiasi dominio esterno)
    ' Blocca:
    ' - javascript:, data:, vbscript:
    ' - CR/LF (header injection)
    Private Function BuildSafeRedirectUrl(ByVal raw As String) As String
        If raw Is Nothing Then Return ""
        Dim s As String = raw.Trim()

        If s = "" OrElse s = "#" Then Return ""

        ' blocco CRLF
        If s.Contains(vbCr) OrElse s.Contains(vbLf) Then Return ""

        Dim lower As String = s.ToLowerInvariant()
        If lower.StartsWith("javascript:") OrElse lower.StartsWith("data:") OrElse lower.StartsWith("vbscript:") Then
            Return ""
        End If

        ' Link interni
        If s.StartsWith("/") OrElse s.StartsWith("~/") Then
            Return ResolveUrl(s)
        End If

        ' Non permetto URL schemaless tipo //example.com
        If s.StartsWith("//") Then Return ""

        ' Se manca schema, compatibilità: aggiungo http:// come nel tuo codice attuale
        Dim uri As Uri = Nothing
        If Not Uri.TryCreate(s, UriKind.Absolute, uri) Then
            If Uri.TryCreate("http://" & s, UriKind.Absolute, uri) Then
                s = uri.ToString()
            Else
                Return ""
            End If
        End If

        If uri.Scheme <> Uri.UriSchemeHttp AndAlso uri.Scheme <> Uri.UriSchemeHttps Then
            Return ""
        End If

        Return uri.ToString()
    End Function

    ' ==========================
    ' Helpers DB (MySQL)
    ' ==========================

    Private Function GetConnectionString() As String
        Dim cs As String = ""
        If ConfigurationManager.ConnectionStrings("EntropicConnectionString") IsNot Nothing Then
            cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        End If
        Return If(cs Is Nothing, "", cs)
    End Function

    Private Sub ExecuteNonQuery(ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, Object) = Nothing)
        Dim cs As String = GetConnectionString()
        If String.IsNullOrEmpty(cs) Then Exit Sub

        Using conn As New MySqlConnection(cs)
            conn.Open()
            Using cmd As New MySqlCommand(sqlString, conn)
                cmd.CommandType = CommandType.Text

                If params IsNot Nothing Then
                    For Each k As String In params.Keys
                        cmd.Parameters.AddWithValue(k, params(k))
                    Next
                End If

                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

    Private Function ExecuteQueryGetDataReader(ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, Object) = Nothing) As List(Of Dictionary(Of String, Object))
        Dim cs As String = GetConnectionString()
        Dim result As New List(Of Dictionary(Of String, Object))()

        If String.IsNullOrEmpty(cs) Then Return result

        Using conn As New MySqlConnection(cs)
            conn.Open()
            Using cmd As New MySqlCommand(sqlString, conn)
                cmd.CommandType = CommandType.Text

                If params IsNot Nothing Then
                    For Each k As String In params.Keys
                        cmd.Parameters.AddWithValue(k, params(k))
                    Next
                End If

                Using dr As MySqlDataReader = cmd.ExecuteReader()
                    While dr.Read()
                        Dim row As New Dictionary(Of String, Object)()
                        For i As Integer = 0 To dr.FieldCount - 1
                            row.Add(dr.GetName(i), dr.GetValue(i))
                        Next
                        result.Add(row)
                    End While
                End Using
            End Using
        End Using

        Return result
    End Function

End Class
