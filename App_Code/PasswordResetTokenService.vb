Imports System
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Data
Imports System.Net
Imports System.Net.Mail
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports MySql.Data.MySqlClient

Public Class PasswordResetTokenInfo
    Public Property LoginId As Integer
End Class

Public Class PasswordResetAccountCandidate
    Public Property LoginId As Integer
    Public Property DestinationEmail As String
    Public Property DisplayName As String
    Public Property Label As String
End Class

Friend Class PasswordResetPendingToken
    Public Property Candidate As PasswordResetAccountCandidate
    Public Property ClearToken As String
End Class

Public Module PasswordResetTokenService
    Private Const TokenBytesLength As Integer = 32
    Private Const TokenLifetimeMinutes As Integer = 30
    Private Const MinPasswordLength As Integer = 8
    Private Const MaxPasswordLength As Integer = 25
    Private Const MaxResetCandidates As Integer = 10
    Private Const GenericResetMessage As String = "Se i dati inseriti sono corretti riceverai le istruzioni per completare il reset della password."

    Public Function GenericRequestMessage() As String
        Return GenericResetMessage
    End Function

    Public Sub RequestReset(ByVal email As String, ByVal page As Page)
        Dim cleanEmail As String = Convert.ToString(email).Trim()
        If cleanEmail = "" OrElse page Is Nothing Then Return

        Try
            Using conn As New MySqlConnection(GetConnectionString())
                conn.Open()

                Dim candidates As List(Of PasswordResetAccountCandidate) = FindResetCandidates(conn, cleanEmail, page)
                If candidates.Count = 0 Then
                    Return
                End If

                If candidates.Count > MaxResetCandidates Then
                    KeepStoreLog.Info("password-reset", "Richiesta reset ignorata: candidati oltre limite sicurezza.", HttpContext.Current)
                    Return
                End If

                Dim ipHash As String = HashOptional(GetClientIp(page))
                Dim userAgentHash As String = HashOptional(Convert.ToString(page.Request.UserAgent))
                Dim pendingTokens As New List(Of PasswordResetPendingToken)()

                Using tx As MySqlTransaction = conn.BeginTransaction()
                    For Each candidate As PasswordResetAccountCandidate In candidates
                        Dim clearToken As String = GenerateToken()
                        Dim tokenHash As String = Sha256Hex(clearToken)

                        RevokeActiveTokens(conn, tx, candidate.LoginId)
                        InsertToken(conn, tx, candidate.LoginId, tokenHash, ipHash, userAgentHash)

                        Dim pending As New PasswordResetPendingToken()
                        pending.Candidate = candidate
                        pending.ClearToken = clearToken
                        pendingTokens.Add(pending)
                    Next
                    tx.Commit()
                End Using

                Try
                    SendResetEmail(page, candidates(0).DestinationEmail, pendingTokens)
                Catch ex As Exception
                    Try
                        Using tx As MySqlTransaction = conn.BeginTransaction()
                            For Each candidate As PasswordResetAccountCandidate In candidates
                                RevokeActiveTokens(conn, tx, candidate.LoginId)
                            Next
                            tx.Commit()
                        End Using
                    Catch
                    End Try

                    KeepStoreLog.Error("password-reset", "Errore invio email reset password", ex, HttpContext.Current)
                End Try
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("password-reset", "Errore richiesta reset password", ex, HttpContext.Current)
        End Try
    End Sub

    Public Function TryValidateToken(ByVal clearToken As String, ByRef info As PasswordResetTokenInfo) As Boolean
        info = Nothing

        If String.IsNullOrWhiteSpace(clearToken) Then Return False

        Dim tokenHash As String = Sha256Hex(clearToken.Trim())

        Try
            Using conn As New MySqlConnection(GetConnectionString())
                conn.Open()

                Using cmd As New MySqlCommand("SELECT LoginId FROM login_password_reset_tokens WHERE TokenHash=@hash AND UsedAt IS NULL AND RevokedAt IS NULL AND ExpiresAt >= NOW() LIMIT 1", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.AddWithValue("@hash", tokenHash)

                    Dim result As Object = cmd.ExecuteScalar()
                    If result Is Nothing OrElse Convert.IsDBNull(result) Then Return False

                    Dim loginId As Integer = 0
                    If Not Integer.TryParse(Convert.ToString(result), loginId) OrElse loginId <= 0 Then Return False

                    info = New PasswordResetTokenInfo()
                    info.LoginId = loginId
                    Return True
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("password-reset", "Errore validazione token reset password", ex, HttpContext.Current)
            Return False
        End Try
    End Function

    Public Function CompleteReset(ByVal clearToken As String, ByVal newPassword As String, ByVal confirmPassword As String, ByRef userMessage As String) As Boolean
        userMessage = ""

        Dim validationMessage As String = ""
        If Not ValidateNewPassword(newPassword, confirmPassword, validationMessage) Then
            userMessage = validationMessage
            Return False
        End If

        If String.IsNullOrWhiteSpace(clearToken) Then
            userMessage = "Il link di reset non e valido o non e piu utilizzabile."
            Return False
        End If

        Dim tokenHash As String = Sha256Hex(clearToken.Trim())

        Try
            Using conn As New MySqlConnection(GetConnectionString())
                conn.Open()

                Using tx As MySqlTransaction = conn.BeginTransaction()
                    Dim loginId As Integer = 0
                    Dim currentPassword As String = ""

                    If Not TryLoadValidTokenForUpdate(conn, tx, tokenHash, loginId, currentPassword) Then
                        tx.Rollback()
                        userMessage = "Il link di reset non e valido o non e piu utilizzabile."
                        Return False
                    End If

                    If String.Equals(currentPassword, newPassword, StringComparison.Ordinal) Then
                        tx.Rollback()
                        userMessage = "La nuova password deve essere diversa da quella attuale."
                        Return False
                    End If

                    If Not UpdateLegacyPassword(conn, tx, loginId, newPassword) Then
                        tx.Rollback()
                        userMessage = "Non e stato possibile completare il reset. Richiedi un nuovo link."
                        Return False
                    End If

                    MarkTokenUsed(conn, tx, tokenHash)
                    RevokeActiveTokens(conn, tx, loginId)

                    tx.Commit()
                    userMessage = "Password aggiornata correttamente. Ora puoi accedere con la nuova password."
                    Return True
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("password-reset", "Errore completamento reset password", ex, HttpContext.Current)
            userMessage = "Errore tecnico durante il reset della password. Richiedi un nuovo link."
            Return False
        End Try
    End Function

    Private Function FindResetCandidates(ByVal conn As MySqlConnection,
                                         ByVal email As String,
                                         ByVal page As Page) As List(Of PasswordResetAccountCandidate)
        Dim candidates As New List(Of PasswordResetAccountCandidate)()
        Dim aziendaId As Integer = 0
        Try
            Integer.TryParse(Convert.ToString(page.Session("AziendaID")), aziendaId)
        Catch
            aziendaId = 0
        End Try

        Dim sql As String = "SELECT id, email, cognomenome FROM vlogin WHERE UPPER(email)=UPPER(@email) AND Abilitato=1 AND UtentiAbilitato=1"
        If aziendaId > 0 Then
            sql &= " AND AziendeID=@aziendaId"
        End If
        sql &= " ORDER BY id LIMIT " & (MaxResetCandidates + 1).ToString()

        Using cmd As New MySqlCommand(sql, conn)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@email", email)
            If aziendaId > 0 Then
                cmd.Parameters.AddWithValue("@aziendaId", aziendaId)
            End If

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                Dim index As Integer = 1
                While dr.Read()
                    Dim candidate As New PasswordResetAccountCandidate()

                    Dim loginId As Integer = 0
                    Integer.TryParse(Convert.ToString(dr("id")), loginId)
                    candidate.LoginId = loginId
                    candidate.DestinationEmail = Convert.ToString(dr("email")).Trim()
                    candidate.DisplayName = Convert.ToString(dr("cognomenome")).Trim()
                    candidate.Label = "Account " & index.ToString()

                    If candidate.LoginId > 0 AndAlso candidate.DestinationEmail <> "" Then
                        candidates.Add(candidate)
                        index += 1
                    End If
                End While
            End Using
        End Using

        Return candidates
    End Function

    Private Sub RevokeActiveTokens(ByVal conn As MySqlConnection, ByVal tx As MySqlTransaction, ByVal loginId As Integer)
        Using cmd As New MySqlCommand("UPDATE login_password_reset_tokens SET RevokedAt=NOW() WHERE LoginId=@loginId AND UsedAt IS NULL AND RevokedAt IS NULL", conn, tx)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@loginId", loginId)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    Private Sub InsertToken(ByVal conn As MySqlConnection,
                            ByVal tx As MySqlTransaction,
                            ByVal loginId As Integer,
                            ByVal tokenHash As String,
                            ByVal ipHash As Object,
                            ByVal userAgentHash As Object)

        Const sql As String = "INSERT INTO login_password_reset_tokens " &
                              "(LoginId, TokenHash, CreatedAt, ExpiresAt, UsedAt, RevokedAt, RequestIpHash, UserAgentHash, CreatedBy) " &
                              "VALUES (@loginId, @tokenHash, NOW(), DATE_ADD(NOW(), INTERVAL 30 MINUTE), NULL, NULL, @ipHash, @userAgentHash, 'web_remind')"

        Using cmd As New MySqlCommand(sql, conn, tx)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@loginId", loginId)
            cmd.Parameters.AddWithValue("@tokenHash", tokenHash)
            cmd.Parameters.AddWithValue("@ipHash", ipHash)
            cmd.Parameters.AddWithValue("@userAgentHash", userAgentHash)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    Private Function TryLoadValidTokenForUpdate(ByVal conn As MySqlConnection,
                                                ByVal tx As MySqlTransaction,
                                                ByVal tokenHash As String,
                                                ByRef loginId As Integer,
                                                ByRef currentPassword As String) As Boolean

        loginId = 0
        currentPassword = ""

        Const sql As String = "SELECT t.LoginId, l.Password " &
                              "FROM login_password_reset_tokens t " &
                              "INNER JOIN login l ON l.id=t.LoginId " &
                              "WHERE t.TokenHash=@hash AND t.UsedAt IS NULL AND t.RevokedAt IS NULL AND t.ExpiresAt >= NOW() " &
                              "LIMIT 1 FOR UPDATE"

        Using cmd As New MySqlCommand(sql, conn, tx)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@hash", tokenHash)

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                If Not dr.Read() Then Return False

                Integer.TryParse(Convert.ToString(dr("LoginId")), loginId)
                currentPassword = Convert.ToString(dr("Password"))
            End Using
        End Using

        Return loginId > 0
    End Function

    Private Function UpdateLegacyPassword(ByVal conn As MySqlConnection, ByVal tx As MySqlTransaction, ByVal loginId As Integer, ByVal newPassword As String) As Boolean
        Using cmd As New MySqlCommand("UPDATE login SET Password=@password, DataPassword=NOW() WHERE id=@loginId", conn, tx)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@password", newPassword)
            cmd.Parameters.AddWithValue("@loginId", loginId)
            Return cmd.ExecuteNonQuery() > 0
        End Using
    End Function

    Private Sub MarkTokenUsed(ByVal conn As MySqlConnection, ByVal tx As MySqlTransaction, ByVal tokenHash As String)
        Using cmd As New MySqlCommand("UPDATE login_password_reset_tokens SET UsedAt=NOW() WHERE TokenHash=@hash AND UsedAt IS NULL AND RevokedAt IS NULL", conn, tx)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@hash", tokenHash)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    Private Function ValidateNewPassword(ByVal newPassword As String, ByVal confirmPassword As String, ByRef message As String) As Boolean
        message = ""

        If String.IsNullOrWhiteSpace(newPassword) OrElse String.IsNullOrWhiteSpace(confirmPassword) Then
            message = "Compila tutti i campi."
            Return False
        End If

        If newPassword.Length < MinPasswordLength Then
            message = "La nuova password deve avere almeno " & MinPasswordLength.ToString() & " caratteri."
            Return False
        End If

        If newPassword.Length > MaxPasswordLength Then
            message = "La nuova password non puo superare " & MaxPasswordLength.ToString() & " caratteri."
            Return False
        End If

        If Not String.Equals(newPassword, confirmPassword, StringComparison.Ordinal) Then
            message = "Le nuove password non coincidono."
            Return False
        End If

        Return True
    End Function

    Private Sub SendResetEmail(ByVal page As Page, ByVal destinationEmail As String, ByVal pendingTokens As List(Of PasswordResetPendingToken))
        If pendingTokens Is Nothing OrElse pendingTokens.Count = 0 Then Return

        Dim ctx As HttpContext = HttpContext.Current
        Dim aziendaNome As String = SessionString(ctx, "AziendaNome")
        Dim aziendaEmail As String = SessionString(ctx, "AziendaEmail")
        Dim smtpHost As String = SessionString(ctx, "smtp")
        Dim userSmtp As String = SessionString(ctx, "User_smtp")
        Dim passSmtp As String = SessionString(ctx, "Password_smtp")

        If aziendaEmail = "" OrElse smtpHost = "" Then
            Throw New InvalidOperationException("SMTP reset password non configurato.")
        End If

        Using msg As New MailMessage()
            msg.From = New MailAddress(aziendaEmail, If(aziendaNome = "", "KeepStore", aziendaNome))
            msg.To.Add(New MailAddress(destinationEmail))
            msg.Subject = "Reset password " & If(aziendaNome = "", "KeepStore", aziendaNome)
            msg.SubjectEncoding = Encoding.UTF8
            msg.BodyEncoding = Encoding.UTF8
            msg.IsBodyHtml = True

            Dim body As New StringBuilder()
            body.Append("<font face='arial' size='2' color='black'>")
            body.Append("Abbiamo ricevuto una richiesta di reset password.<br/>")

            If pendingTokens.Count = 1 Then
                Dim resetUrl As String = BuildResetUrl(page, pendingTokens(0).ClearToken)
                Dim safeUrl As String = HttpUtility.HtmlAttributeEncode(resetUrl)

                body.Append("Per impostare una nuova password usa questo link entro ")
                body.Append(TokenLifetimeMinutes.ToString())
                body.Append(" minuti:<br/><br/>")
                body.Append("<a href='")
                body.Append(safeUrl)
                body.Append("'>Reimposta la password</a>")
            Else
                body.Append("Abbiamo trovato piu account associati a questa email. Scegli l'account per cui vuoi reimpostare la password entro ")
                body.Append(TokenLifetimeMinutes.ToString())
                body.Append(" minuti:<br/><br/>")
                body.Append("<ul>")

                For Each pending As PasswordResetPendingToken In pendingTokens
                    Dim resetUrl As String = BuildResetUrl(page, pending.ClearToken)
                    Dim safeUrl As String = HttpUtility.HtmlAttributeEncode(resetUrl)
                    Dim safeLabel As String = HttpUtility.HtmlEncode(pending.Candidate.Label)

                    body.Append("<li>")
                    body.Append(safeLabel)
                    body.Append(": <a href='")
                    body.Append(safeUrl)
                    body.Append("'>Reimposta password</a>")
                    body.Append("</li>")
                Next

                body.Append("</ul>")
            End If

            body.Append("<br/><br/>Se non hai richiesto tu il reset, ignora questa email.")
            body.Append("</font>")
            msg.Body = body.ToString()

            Using smtp As New SmtpClient(smtpHost)
                smtp.DeliveryMethod = SmtpDeliveryMethod.Network
                If userSmtp <> "" Then
                    smtp.UseDefaultCredentials = False
                    smtp.Credentials = New NetworkCredential(userSmtp, passSmtp)
                End If
                smtp.Send(msg)
            End Using
        End Using
    End Sub

    Private Function BuildResetUrl(ByVal page As Page, ByVal clearToken As String) As String
        Dim relative As String = page.ResolveUrl("~/resetpassword.aspx")
        Dim baseUri As New Uri(page.Request.Url, relative)
        Return baseUri.ToString() & "?token=" & HttpUtility.UrlEncode(clearToken)
    End Function

    Private Function GenerateToken() As String
        Dim bytes(TokenBytesLength - 1) As Byte
        Using rng As New RNGCryptoServiceProvider()
            rng.GetBytes(bytes)
        End Using

        Return Convert.ToBase64String(bytes).TrimEnd("="c).Replace("+"c, "-"c).Replace("/"c, "_"c)
    End Function

    Private Function HashOptional(ByVal value As String) As Object
        If String.IsNullOrWhiteSpace(value) Then
            Return DBNull.Value
        End If

        Return Sha256Hex(value.Trim())
    End Function

    Private Function Sha256Hex(ByVal value As String) As String
        Using sha As SHA256 = SHA256.Create()
            Dim bytes As Byte() = Encoding.UTF8.GetBytes(Convert.ToString(value))
            Dim hash As Byte() = sha.ComputeHash(bytes)
            Dim sb As New StringBuilder(hash.Length * 2)
            For Each b As Byte In hash
                sb.Append(b.ToString("x2"))
            Next
            Return sb.ToString()
        End Using
    End Function

    Private Function GetClientIp(ByVal page As Page) As String
        If page Is Nothing OrElse page.Request Is Nothing Then Return ""

        Dim forwarded As String = Convert.ToString(page.Request.Headers("X-Forwarded-For"))
        If forwarded <> "" Then
            Dim parts As String() = forwarded.Split(","c)
            If parts.Length > 0 Then Return parts(0).Trim()
        End If

        Return Convert.ToString(page.Request.UserHostAddress)
    End Function

    Private Function SessionString(ByVal ctx As HttpContext, ByVal key As String) As String
        Try
            If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return ""
            Return Convert.ToString(ctx.Session(key)).Trim()
        Catch
            Return ""
        End Try
    End Function

    Private Function GetConnectionString() As String
        Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
    End Function
End Module
