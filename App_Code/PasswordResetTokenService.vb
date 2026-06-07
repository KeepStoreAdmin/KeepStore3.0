Imports System
Imports System.Configuration
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

Public Module PasswordResetTokenService
    Private Const TokenBytesLength As Integer = 32
    Private Const TokenLifetimeMinutes As Integer = 30
    Private Const MinPasswordLength As Integer = 8
    Private Const MaxPasswordLength As Integer = 25
    Private Const GenericResetMessage As String = "Se i dati inseriti sono corretti riceverai le istruzioni per completare il reset della password."

    Private Class PasswordResetCompanyInfo
        Public Property Name As String
        Public Property Email As String
        Public Property WebsiteUrl As String
        Public Property Phone As String
        Public Property Address As String
        Public Property City As String
        Public Property Province As String
        Public Property ZipCode As String
        Public Property VatNumber As String
    End Class

    Public Function GenericRequestMessage() As String
        Return GenericResetMessage
    End Function

    Public Sub RequestReset(ByVal email As String, ByVal fiscalCodeOrVat As String, ByVal page As Page)
        Dim cleanEmail As String = Convert.ToString(email).Trim()
        Dim cleanFiscalCodeOrVat As String = NormalizeFiscalCodeOrVat(fiscalCodeOrVat)
        If cleanEmail = "" OrElse cleanFiscalCodeOrVat = "" OrElse page Is Nothing Then Return

        Try
            Using conn As New MySqlConnection(GetConnectionString())
                conn.Open()

                Dim loginId As Integer = 0
                Dim destinationEmail As String = ""
                Dim displayName As String = ""
                Dim companyInfo As PasswordResetCompanyInfo = Nothing
                If Not TryFindDeterministicAccount(conn, cleanEmail, cleanFiscalCodeOrVat, page, loginId, destinationEmail, displayName, companyInfo) Then
                    Return
                End If

                Dim ipHash As String = HashOptional(GetClientIp(page))
                Dim userAgentHash As String = HashOptional(Convert.ToString(page.Request.UserAgent))
                Dim clearToken As String = GenerateToken()
                Dim tokenHash As String = Sha256Hex(clearToken)

                Using tx As MySqlTransaction = conn.BeginTransaction()
                    RevokeActiveTokens(conn, tx, loginId)
                    InsertToken(conn, tx, loginId, tokenHash, ipHash, userAgentHash)
                    tx.Commit()
                End Using

                Try
                    SendResetEmail(page, destinationEmail, displayName, clearToken, companyInfo)
                Catch ex As Exception
                    Try
                        Using tx As MySqlTransaction = conn.BeginTransaction()
                            RevokeActiveTokens(conn, tx, loginId)
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

    Private Function TryFindDeterministicAccount(ByVal conn As MySqlConnection,
                                                 ByVal email As String,
                                                 ByVal fiscalCodeOrVat As String,
                                                 ByVal page As Page,
                                                 ByRef loginId As Integer,
                                                 ByRef destinationEmail As String,
                                                 ByRef displayName As String,
                                                 ByRef companyInfo As PasswordResetCompanyInfo) As Boolean
        loginId = 0
        destinationEmail = ""
        displayName = ""
        companyInfo = Nothing

        Dim aziendaId As Integer = 0
        Try
            Integer.TryParse(Convert.ToString(page.Session("AziendaID")), aziendaId)
        Catch
            aziendaId = 0
        End Try

        If aziendaId <= 0 Then
            aziendaId = ResolveAziendaIdFromHost(conn, page)
        End If

        Dim sql As String = "SELECT id, MIN(email) AS email, MIN(cognomenome) AS cognomenome, MIN(AziendeID) AS AziendeID FROM vlogin " &
                            "WHERE UPPER(email)=UPPER(@email) " &
                            "AND Abilitato=1 AND UtentiAbilitato=1 " &
                            "AND (UPPER(REPLACE(REPLACE(COALESCE(CodiceFiscale,''), ' ', ''), CHAR(9), ''))=@fiscalCodeOrVat " &
                            "OR UPPER(REPLACE(REPLACE(COALESCE(Piva,''), ' ', ''), CHAR(9), ''))=@fiscalCodeOrVat)"
        If aziendaId > 0 Then
            sql &= " AND AziendeID=@aziendaId"
        End If
        sql &= " GROUP BY id LIMIT 2"

        Dim matchedAziendaId As Integer = 0

        Using cmd As New MySqlCommand(sql, conn)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@email", email)
            cmd.Parameters.AddWithValue("@fiscalCodeOrVat", fiscalCodeOrVat)
            If aziendaId > 0 Then
                cmd.Parameters.AddWithValue("@aziendaId", aziendaId)
            End If

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                Dim matches As Integer = 0
                While dr.Read()
                    matches += 1
                    If matches = 1 Then
                        Integer.TryParse(Convert.ToString(dr("id")), loginId)
                        destinationEmail = Convert.ToString(dr("email")).Trim()
                        displayName = Convert.ToString(dr("cognomenome")).Trim()
                        Integer.TryParse(Convert.ToString(dr("AziendeID")), matchedAziendaId)
                    End If
                End While

                If matches <> 1 Then Return False
            End Using
        End Using

        If matchedAziendaId > 0 Then
            companyInfo = LoadCompanyInfo(conn, matchedAziendaId)
        End If

        Return loginId > 0 AndAlso destinationEmail <> ""
    End Function

    Private Function LoadCompanyInfo(ByVal conn As MySqlConnection, ByVal aziendaId As Integer) As PasswordResetCompanyInfo
        If aziendaId <= 0 Then Return Nothing

        Const sql As String = "SELECT RagioneSociale, CognomeNome, email, URL1, URL2, Telefono, Indirizzo, Citta, Provincia, Cap, Piva " &
                              "FROM aziende WHERE id=@aziendaId LIMIT 1"

        Using cmd As New MySqlCommand(sql, conn)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@aziendaId", aziendaId)

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                If Not dr.Read() Then Return Nothing

                Dim info As New PasswordResetCompanyInfo()
                info.Name = FirstNonEmpty(Convert.ToString(dr("RagioneSociale")), Convert.ToString(dr("CognomeNome")))
                info.Email = Convert.ToString(dr("email")).Trim()
                info.WebsiteUrl = FirstNonEmpty(Convert.ToString(dr("URL1")), Convert.ToString(dr("URL2")))
                info.Phone = Convert.ToString(dr("Telefono")).Trim()
                info.Address = Convert.ToString(dr("Indirizzo")).Trim()
                info.City = Convert.ToString(dr("Citta")).Trim()
                info.Province = Convert.ToString(dr("Provincia")).Trim()
                info.ZipCode = Convert.ToString(dr("Cap")).Trim()
                info.VatNumber = Convert.ToString(dr("Piva")).Trim()
                Return info
            End Using
        End Using
    End Function

    Private Function NormalizeFiscalCodeOrVat(ByVal value As String) As String
        Dim raw As String = Convert.ToString(value).Trim()
        If raw = "" Then Return ""

        Dim sb As New StringBuilder(raw.Length)
        For Each ch As Char In raw
            If Not Char.IsWhiteSpace(ch) Then
                sb.Append(Char.ToUpperInvariant(ch))
            End If
        Next

        Return sb.ToString()
    End Function

    Private Function ResolveAziendaIdFromHost(ByVal conn As MySqlConnection, ByVal page As Page) As Integer
        Dim host As String = NormalizeHost(GetRequestHost(page))
        If host = "" Then Return 0

        Dim wwwHost As String = If(host.StartsWith("www.", StringComparison.OrdinalIgnoreCase), host.Substring(4), "www." & host)

        Const sql As String = "SELECT id FROM aziende " &
                              "WHERE LOWER(REPLACE(REPLACE(TRIM(TRAILING '/' FROM COALESCE(URL1,'')), 'http://', ''), 'https://', '')) IN (@host, @wwwHost) " &
                              "OR LOWER(REPLACE(REPLACE(TRIM(TRAILING '/' FROM COALESCE(URL2,'')), 'http://', ''), 'https://', '')) IN (@host, @wwwHost) " &
                              "LIMIT 2"

        Using cmd As New MySqlCommand(sql, conn)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@host", host)
            cmd.Parameters.AddWithValue("@wwwHost", wwwHost)

            Dim resolvedId As Integer = 0
            Dim matches As Integer = 0
            Using dr As MySqlDataReader = cmd.ExecuteReader()
                While dr.Read()
                    matches += 1
                    If matches = 1 Then
                        Integer.TryParse(Convert.ToString(dr("id")), resolvedId)
                    End If
                End While
            End Using

            If matches = 1 Then Return resolvedId
        End Using

        Return 0
    End Function

    Private Function GetRequestHost(ByVal page As Page) As String
        Try
            If page Is Nothing OrElse page.Request Is Nothing OrElse page.Request.Url Is Nothing Then Return ""
            Return Convert.ToString(page.Request.Url.Host)
        Catch
            Return ""
        End Try
    End Function

    Private Function NormalizeHost(ByVal value As String) As String
        Dim host As String = Convert.ToString(value).Trim().ToLowerInvariant()
        If host.StartsWith("http://", StringComparison.OrdinalIgnoreCase) Then host = host.Substring(7)
        If host.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then host = host.Substring(8)
        host = host.TrimEnd("/"c)
        Return host
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

    Private Sub SendResetEmail(ByVal page As Page, ByVal destinationEmail As String, ByVal displayName As String, ByVal clearToken As String, ByVal companyInfo As PasswordResetCompanyInfo)
        Dim ctx As HttpContext = HttpContext.Current
        Dim aziendaNome As String = FirstNonEmpty(If(companyInfo Is Nothing, "", companyInfo.Name), SessionString(ctx, "AziendaNome"), "KeepStore")
        Dim aziendaEmail As String = FirstNonEmpty(If(companyInfo Is Nothing, "", companyInfo.Email), SessionString(ctx, "AziendaEmail"))
        Dim smtpHost As String = SessionString(ctx, "smtp")
        Dim userSmtp As String = SessionString(ctx, "User_smtp")
        Dim passSmtp As String = SessionString(ctx, "Password_smtp")
        Dim resetUrl As String = BuildResetUrl(page, clearToken)

        If aziendaEmail = "" OrElse smtpHost = "" Then
            Throw New InvalidOperationException("SMTP reset password non configurato.")
        End If

        Using msg As New MailMessage()
            msg.From = New MailAddress(aziendaEmail, aziendaNome)
            msg.To.Add(New MailAddress(destinationEmail))
            msg.Subject = "Reimposta la password del tuo account " & aziendaNome
            msg.SubjectEncoding = Encoding.UTF8
            msg.BodyEncoding = Encoding.UTF8

            Dim plainBody As String = BuildResetPlainText(aziendaNome, displayName, resetUrl)
            Dim htmlBody As String = BuildResetHtmlBody(aziendaNome, displayName, resetUrl, companyInfo)

            msg.Body = htmlBody
            msg.IsBodyHtml = True
            msg.AlternateViews.Add(AlternateView.CreateAlternateViewFromString(plainBody, Encoding.UTF8, "text/plain"))
            msg.AlternateViews.Add(AlternateView.CreateAlternateViewFromString(htmlBody, Encoding.UTF8, "text/html"))

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

    Private Function BuildResetPlainText(ByVal companyName As String, ByVal displayName As String, ByVal resetUrl As String) As String
        Dim name As String = FirstNonEmpty(displayName, "cliente")
        Dim sb As New StringBuilder()
        sb.AppendLine("Gentile " & name & ",")
        sb.AppendLine()
        sb.AppendLine("abbiamo ricevuto una richiesta di reset password per il tuo account " & companyName & ".")
        sb.AppendLine("Per impostare una nuova password usa il link seguente entro " & TokenLifetimeMinutes.ToString() & " minuti:")
        sb.AppendLine(resetUrl)
        sb.AppendLine()
        sb.AppendLine("Se non hai richiesto tu il reset, ignora questa email: la password attuale resta invariata.")
        sb.AppendLine()
        sb.AppendLine("Grazie,")
        sb.AppendLine(companyName)
        Return sb.ToString()
    End Function

    Private Function BuildResetHtmlBody(ByVal companyName As String, ByVal displayName As String, ByVal resetUrl As String, ByVal companyInfo As PasswordResetCompanyInfo) As String
        Dim safeCompanyName As String = HtmlText(companyName)
        Dim safeName As String = HtmlText(FirstNonEmpty(displayName, "cliente"))
        Dim safeUrl As String = HttpUtility.HtmlAttributeEncode(resetUrl)
        Dim footer As String = BuildCompanyFooter(companyInfo)

        Return "<!doctype html>" &
               "<html><body style='margin:0;padding:0;background:#f4f6f8;font-family:Arial,Helvetica,sans-serif;color:#1f2933;'>" &
               "<table role='presentation' width='100%' cellspacing='0' cellpadding='0' style='background:#f4f6f8;padding:24px 0;'>" &
               "<tr><td align='center'>" &
               "<table role='presentation' width='100%' cellspacing='0' cellpadding='0' style='max-width:620px;background:#ffffff;border:1px solid #dde3ea;border-radius:6px;'>" &
               "<tr><td style='padding:28px 32px 12px 32px;border-bottom:1px solid #edf1f5;'>" &
               "<div style='font-size:20px;font-weight:bold;color:#111827;'>" & safeCompanyName & "</div>" &
               "<div style='font-size:13px;color:#6b7280;margin-top:6px;'>Reset password account</div>" &
               "</td></tr>" &
               "<tr><td style='padding:28px 32px;'>" &
               "<p style='margin:0 0 16px 0;font-size:15px;line-height:1.55;'>Gentile " & safeName & ",</p>" &
               "<p style='margin:0 0 16px 0;font-size:15px;line-height:1.55;'>abbiamo ricevuto una richiesta di reset password per il tuo account.</p>" &
               "<p style='margin:0 0 24px 0;font-size:15px;line-height:1.55;'>Il link resta valido per " & TokenLifetimeMinutes.ToString() & " minuti.</p>" &
               "<p style='margin:0 0 24px 0;'><a href='" & safeUrl & "' style='display:inline-block;background:#1f5eff;color:#ffffff;text-decoration:none;font-weight:bold;font-size:15px;padding:12px 20px;border-radius:4px;'>Reimposta la password</a></p>" &
               "<p style='margin:0 0 8px 0;font-size:13px;line-height:1.5;color:#4b5563;'>Se il pulsante non funziona, copia e incolla questo indirizzo nel browser:</p>" &
               "<p style='margin:0 0 20px 0;font-size:12px;line-height:1.45;color:#374151;word-break:break-all;'>" & HtmlText(resetUrl) & "</p>" &
               "<p style='margin:0;font-size:13px;line-height:1.5;color:#4b5563;'>Se non hai richiesto tu il reset, ignora questa email: la password attuale resta invariata.</p>" &
               "</td></tr>" &
               "<tr><td style='padding:18px 32px;background:#f8fafc;border-top:1px solid #edf1f5;font-size:12px;line-height:1.5;color:#6b7280;'>" &
               footer &
               "</td></tr>" &
               "</table>" &
               "</td></tr>" &
               "</table>" &
               "</body></html>"
    End Function

    Private Function BuildCompanyFooter(ByVal companyInfo As PasswordResetCompanyInfo) As String
        If companyInfo Is Nothing Then
            Return "Comunicazione automatica di servizio. Non rispondere con dati sensibili a questa email."
        End If

        Dim parts As New System.Collections.Generic.List(Of String)()
        Dim companyName As String = FirstNonEmpty(companyInfo.Name, "KeepStore")
        parts.Add("<strong>" & HtmlText(companyName) & "</strong>")

        Dim addressLine As String = BuildAddressLine(companyInfo)
        If addressLine <> "" Then parts.Add(HtmlText(addressLine))

        If companyInfo.Phone <> "" Then parts.Add("Telefono: " & HtmlText(companyInfo.Phone))
        If companyInfo.Email <> "" Then parts.Add("Email: " & HtmlText(companyInfo.Email))
        If companyInfo.WebsiteUrl <> "" Then
            Dim webUrl As String = NormalizeWebsiteUrl(companyInfo.WebsiteUrl)
            parts.Add("Sito: <a href='" & HttpUtility.HtmlAttributeEncode(webUrl) & "' style='color:#1f5eff;text-decoration:none;'>" & HtmlText(companyInfo.WebsiteUrl) & "</a>")
        End If
        If companyInfo.VatNumber <> "" Then parts.Add("P.IVA: " & HtmlText(companyInfo.VatNumber))

        parts.Add("Comunicazione automatica di servizio. Non rispondere con dati sensibili a questa email.")
        Return String.Join("<br/>", parts.ToArray())
    End Function

    Private Function BuildAddressLine(ByVal companyInfo As PasswordResetCompanyInfo) As String
        Dim location As String = ""
        If companyInfo.ZipCode <> "" Then location &= companyInfo.ZipCode
        If companyInfo.City <> "" Then location = FirstNonEmpty(location & " " & companyInfo.City, companyInfo.City)
        If companyInfo.Province <> "" Then location &= " (" & companyInfo.Province & ")"

        If companyInfo.Address <> "" AndAlso location <> "" Then Return companyInfo.Address & " - " & location
        Return FirstNonEmpty(companyInfo.Address, location)
    End Function

    Private Function FirstNonEmpty(ParamArray values As String()) As String
        If values Is Nothing Then Return ""

        For Each value As String In values
            Dim cleanValue As String = Convert.ToString(value).Trim()
            If cleanValue <> "" Then Return cleanValue
        Next

        Return ""
    End Function

    Private Function HtmlText(ByVal value As String) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Private Function NormalizeWebsiteUrl(ByVal value As String) As String
        Dim url As String = Convert.ToString(value).Trim()
        If url = "" Then Return ""
        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then Return url
        Return "https://" & url
    End Function

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
