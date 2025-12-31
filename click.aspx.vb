Imports System
Imports System.Data
Imports System.Configuration
Imports MySql.Data.MySqlClient

Partial Class click
    Inherits System.Web.UI.Page

    Private ReadOnly Property ConnString As String
        Get
            Dim cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If cs Is Nothing Then Return ""
            Return cs.ConnectionString
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        ' 1) Validazione ID banner
        Dim bannerId As Integer = 0
        If Not Integer.TryParse(Convert.ToString(Request.QueryString("id")), bannerId) OrElse bannerId <= 0 Then
            SafeRedirect("~/Default.aspx")
            Exit Sub
        End If

        ' 2) IP utente (max 45 per IPv6)
        Dim userIp As String = Convert.ToString(Request.UserHostAddress)
        If userIp Is Nothing Then userIp = ""
        userIp = userIp.Trim()
        If userIp.Length > 45 Then userIp = userIp.Substring(0, 45)

        ' 3) Utente (se non loggato -> -1)
        Dim utentiId As Integer = -1
        If Not Integer.TryParse(Convert.ToString(Session("UtentiId")), utentiId) OrElse utentiId <= 0 Then
            utentiId = -1
        End If

        ' 4) Azienda (se non presente in sessione -> 0, non blocco)
        Dim aziendaId As Integer = 0
        Integer.TryParse(Convert.ToString(Session("AziendaID")), aziendaId)

        ' 5) Leggo link banner dal DB + verifico che il banner sia attivo
        Dim linkRaw As String = Nothing

        Try
            Dim cs As String = ConnString
            If String.IsNullOrWhiteSpace(cs) Then
                SafeRedirect("~/Default.aspx")
                Exit Sub
            End If

            Using conn As New MySqlConnection(cs)
                conn.Open()

                ' Leggo il link SOLO da DB (ignoro qualunque parametro "link" in QueryString)
                ' Nota: filtro su aziendaId solo se disponibile (aziendaId=0 -> non filtro)
                Using cmdLink As New MySqlCommand("
                    SELECT link
                    FROM pubblicitaV2
                    WHERE id = @id
                      AND abilitato = 1
                      AND (@aziendaId = 0 OR id_Azienda = @aziendaId)
                      AND data_inizio_pubblicazione <= CURDATE()
                      AND data_fine_pubblicazione >= CURDATE()
                    LIMIT 1;", conn)

                    cmdLink.Parameters.Add("@id", MySqlDbType.Int32).Value = bannerId
                    cmdLink.Parameters.Add("@aziendaId", MySqlDbType.Int32).Value = aziendaId

                    Dim obj = cmdLink.ExecuteScalar()
                    If obj IsNot Nothing AndAlso Not Convert.IsDBNull(obj) Then
                        linkRaw = Convert.ToString(obj)
                    End If
                End Using

                ' Se non ho un link valido -> home
                If String.IsNullOrWhiteSpace(linkRaw) OrElse linkRaw.Trim() = "#" Then
                    SafeRedirect("~/Default.aspx")
                    Exit Sub
                End If

                ' 6) Check "già cliccato oggi" (stesso IP, stesso banner)
                Dim alreadyClicked As Boolean = False
                Using cmdCheck As New MySqlCommand("
                    SELECT 1
                    FROM pubblicita_click
                    WHERE data_click = CURDATE()
                      AND ip_utente = @ip
                      AND id_pubblicita = @id
                    LIMIT 1;", conn)

                    cmdCheck.Parameters.Add("@ip", MySqlDbType.VarChar, 45).Value = userIp
                    cmdCheck.Parameters.Add("@id", MySqlDbType.Int32).Value = bannerId

                    Dim chk = cmdCheck.ExecuteScalar()
                    alreadyClicked = (chk IsNot Nothing)
                End Using

                ' 7) Se non cliccato: inserisco click + incremento contatore (transazione)
                If Not alreadyClicked Then
                    Using tr = conn.BeginTransaction()
                        Try
                            Using cmdIns As New MySqlCommand("
                                INSERT INTO pubblicita_click (id_utente, ip_utente, id_pubblicita, data_click)
                                VALUES (@utenteId, @ip, @id, CURDATE());", conn, tr)

                                cmdIns.Parameters.Add("@utenteId", MySqlDbType.Int32).Value = utentiId
                                cmdIns.Parameters.Add("@ip", MySqlDbType.VarChar, 45).Value = userIp
                                cmdIns.Parameters.Add("@id", MySqlDbType.Int32).Value = bannerId
                                cmdIns.ExecuteNonQuery()
                            End Using

                            Using cmdUpd As New MySqlCommand("
                                UPDATE pubblicitaV2
                                SET numero_click_attuale = numero_click_attuale + 1
                                WHERE id = @id;", conn, tr)

                                cmdUpd.Parameters.Add("@id", MySqlDbType.Int32).Value = bannerId
                                cmdUpd.ExecuteNonQuery()
                            End Using

                            tr.Commit()
                        Catch
                            Try : tr.Rollback() : Catch : End Try
                            ' Non blocco il redirect se fallisce la statistica
                        End Try
                    End Using
                End If
            End Using

        Catch
            SafeRedirect("~/Default.aspx")
            Exit Sub
        End Try

        ' 8) Redirect sicuro (anti open-redirect su schemi pericolosi)
        Dim finalUrl As String = NormalizeRedirectUrl(linkRaw)
        If String.IsNullOrWhiteSpace(finalUrl) Then
            SafeRedirect("~/Default.aspx")
            Exit Sub
        End If

        SafeRedirect(finalUrl)
    End Sub

    ' Consente solo:
    ' - link interni tipo "/qualcosa"
    ' - link assoluti http/https
    ' Blocca javascript:, data:, file:, ecc.
    Private Function NormalizeRedirectUrl(ByVal raw As String) As String
        If String.IsNullOrWhiteSpace(raw) Then Return ""

        Dim s As String = raw.Trim()

        ' Evito CR/LF (header injection)
        s = s.Replace(vbCr, "").Replace(vbLf, "")

        If s = "#" Then Return ""

        ' Link interno (opzionale ma utile)
        If s.StartsWith("/") Then
            Return s
        End If

        ' Se manca lo schema, mantengo compatibilità col tuo legacy: prefisso http://
        Dim candidate As String = s
        If Not candidate.Contains("://") Then
            candidate = "http://" & candidate
        End If

        Dim uri As Uri = Nothing
        If Not Uri.TryCreate(candidate, UriKind.Absolute, uri) Then Return ""

        If uri.Scheme <> Uri.UriSchemeHttp AndAlso uri.Scheme <> Uri.UriSchemeHttps Then Return ""

        If String.IsNullOrWhiteSpace(uri.Host) Then Return ""

        ' Blocca userinfo tipo user:pass@host
        If Not String.IsNullOrEmpty(uri.UserInfo) Then Return ""

        Return uri.AbsoluteUri
    End Function

    Private Sub SafeRedirect(ByVal urlOrAppRelative As String)
        Dim target As String = urlOrAppRelative
        If String.IsNullOrWhiteSpace(target) Then
            target = "~/Default.aspx"
        End If

        If target.StartsWith("~/") Then
            target = ResolveUrl(target)
        End If

        Response.Redirect(target, False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

End Class
