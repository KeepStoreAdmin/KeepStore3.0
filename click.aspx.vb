Imports System
Imports System.Data
Imports MySql.Data.MySqlClient

Partial Class click
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        ' --- Anti-cache per un endpoint di redirect/tracking ---
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()
        Response.Cache.SetExpires(DateTime.UtcNow.AddMinutes(-1))

        ' --- 1) Validazione input: id deve essere numerico ---
        Dim idPubblicita As Integer = 0
        If Not Integer.TryParse(Request.QueryString("id"), idPubblicita) OrElse idPubblicita <= 0 Then
            SafeGoHome()
            Return
        End If

        ' --- 2) Contesto sessione (Azienda / Utente) ---
        Dim aziendaId As Integer = 0
        If Session("AziendaID") IsNot Nothing Then
            Integer.TryParse(Session("AziendaID").ToString(), aziendaId)
        ElseIf Session("aziendaId") IsNot Nothing Then
            Integer.TryParse(Session("aziendaId").ToString(), aziendaId)
        End If

        Dim utenteId As Integer = -1
        If Session("UtentiId") IsNot Nothing Then
            Integer.TryParse(Session("UtentiId").ToString(), utenteId)
        End If
        If utenteId <= 0 Then utenteId = -1

        Dim ipUtente As String = Convert.ToString(Request.UserHostAddress)
        If String.IsNullOrWhiteSpace(ipUtente) Then
            ipUtente = Convert.ToString(Request.ServerVariables("REMOTE_ADDR"))
        End If

        Dim oggi As Date = Date.Today
        Dim oggiSql As String = oggi.ToString("yyyy-MM-dd")

        Dim connStr As String = ""
        If ConfigurationManager.ConnectionStrings("EntropicConnectionString") IsNot Nothing Then
            connStr = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        End If

        If String.IsNullOrEmpty(connStr) Then
            SafeGoHome()
            Return
        End If

        Dim redirectUrl As String = ""

        Try
            Using conn As New MySqlConnection(connStr)
                conn.Open()

                ' --- 3) Leggo il link DAL DB (non da QueryString) e applico filtri minimi ---
                '     Nota: "riduce" l'abuso come open-redirect perché:
                '     - non accetta un link arbitrario in input
                '     - (se disponibile) vincola l'id all'azienda della sessione
                '     - richiede banner abilitato e in finestra di pubblicazione
                Using cmdGet As New MySqlCommand(
                    "SELECT link " &
                    "FROM pubblicitav2 " &
                    "WHERE id=@id " &
                    "  AND abilitato=1 " &
                    "  AND (@aziendaId=0 OR id_Azienda=@aziendaId) " &
                    "  AND (data_inizio_pubblicazione IS NULL OR data_inizio_pubblicazione <= @oggi) " &
                    "  AND (data_fine_pubblicazione  IS NULL OR data_fine_pubblicazione  >= @oggi) " &
                    "LIMIT 1;", conn)

                    cmdGet.Parameters.AddWithValue("@id", idPubblicita)
                    cmdGet.Parameters.AddWithValue("@aziendaId", aziendaId)
                    cmdGet.Parameters.AddWithValue("@oggi", oggiSql)

                    Dim rawLink As Object = cmdGet.ExecuteScalar()
                    redirectUrl = NormalizeAndValidateRedirectUrl(rawLink)
                End Using

                If String.IsNullOrEmpty(redirectUrl) Then
                    SafeGoHome()
                    Return
                End If

                ' --- 4) Anti-duplicazione click: 1 click al giorno per IP + banner ---
                Dim alreadyClicked As Integer = 0
                Using cmdExists As New MySqlCommand(
                    "SELECT COUNT(1) " &
                    "FROM pubblicita_click " &
                    "WHERE data_click=@oggi AND ip_utente=@ip AND id_pubblicita=@id;", conn)

                    cmdExists.Parameters.AddWithValue("@oggi", oggiSql)
                    cmdExists.Parameters.AddWithValue("@ip", ipUtente)
                    cmdExists.Parameters.AddWithValue("@id", idPubblicita)

                    Dim o As Object = cmdExists.ExecuteScalar()
                    If o IsNot Nothing Then
                        Integer.TryParse(o.ToString(), alreadyClicked)
                    End If
                End Using

                If alreadyClicked = 0 Then

                    Using cmdIns As New MySqlCommand(
                        "INSERT INTO pubblicita_click (id_utente, ip_utente, id_pubblicita, data_click) " &
                        "VALUES (@utente, @ip, @id, @oggi);", conn)

                        cmdIns.Parameters.AddWithValue("@utente", utenteId)
                        cmdIns.Parameters.AddWithValue("@ip", ipUtente)
                        cmdIns.Parameters.AddWithValue("@id", idPubblicita)
                        cmdIns.Parameters.AddWithValue("@oggi", oggiSql)
                        cmdIns.ExecuteNonQuery()
                    End Using

                    Using cmdUpd As New MySqlCommand(
                        "UPDATE pubblicitav2 " &
                        "SET numero_click_attuale = numero_click_attuale + 1 " &
                        "WHERE id=@id;", conn)

                        cmdUpd.Parameters.AddWithValue("@id", idPubblicita)
                        cmdUpd.ExecuteNonQuery()
                    End Using

                End If

            End Using

        Catch ex As Exception
            ' Hardening: non esporre dettagli a video; in futuro qui si può loggare l'errore.
            SafeGoHome()
            Return
        End Try

        ' --- 5) Redirect finale ---
        Response.Redirect(redirectUrl, False)
        Context.ApplicationInstance.CompleteRequest()

    End Sub

    Private Sub SafeGoHome()
        Response.Redirect("~/Default.aspx", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    ' Normalizzazione e validazione URL per ridurre vettori XSS / redirect non sicuri
    Private Function NormalizeAndValidateRedirectUrl(ByVal linkObj As Object) As String
        If linkObj Is Nothing OrElse Convert.IsDBNull(linkObj) Then Return ""

        Dim raw As String = Convert.ToString(linkObj).Trim()
        If raw = "" OrElse raw = "#" Then Return ""

        Dim lower As String = raw.ToLowerInvariant()
        If lower.StartsWith("javascript:") OrElse lower.StartsWith("data:") OrElse lower.StartsWith("vbscript:") Then
            Return ""
        End If

        ' URL interni consentiti
        If raw.StartsWith("~/") Then
            Return ResolveUrl(raw)
        End If
        If raw.StartsWith("/") Then
            Return raw
        End If

        ' URL assoluti esterni: solo http/https
        Dim uri As Uri = Nothing
        If Uri.TryCreate(raw, UriKind.Absolute, uri) Then
            If uri.Scheme = Uri.UriSchemeHttp OrElse uri.Scheme = Uri.UriSchemeHttps Then
                Return uri.ToString()
            End If
            Return ""
        End If

        ' Se manca lo schema, provo con https:// (più sicuro di http://)
        Dim candidate As String = "https://" & raw
        If Uri.TryCreate(candidate, UriKind.Absolute, uri) Then
            If uri.Scheme = Uri.UriSchemeHttps OrElse uri.Scheme = Uri.UriSchemeHttp Then
                Return uri.ToString()
            End If
        End If

        Return ""
    End Function

End Class
