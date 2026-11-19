Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports MySql.Data.MySqlClient

' AUTH-STAY-SIGNED-IN-2A, fase 1: servizio di "Resta collegato". NESSUN CHIAMANTE in questa fase: il sito non cambia comportamento.
' Regole (decisione del task, .ai-review/auth-stay-signed-in-2a/decisione.md):
' - Nel cookie del browser sta un codice casuale di 32 byte (formato "v1." + base64url); nel database solo la sua impronta SHA-256, legata a
'   database e azienda. Il codice e stabile per dispositivo (nessuna rotazione): vale fino alla scadenza o alla revoca.
' - CredentialStamp = HMAC-SHA256 con chiave il codice del cookie su database, azienda, accesso, utente, nome utente, password e data della
'   password come sono nel database: se uno di questi cambia (dal sito, dal gestionale o direttamente), il dispositivo non vale piu.
' - Durata: 30 giorni dall'ultimo uso; il rinnovo avviene al massimo una volta ogni 24 ore; tutto il tempo e quello del database (UTC).
' - Ogni errore del database (tabella assente compresa) = "non disponibile", mai un'eccezione verso la pagina, e sospensione di 5 minuti.
' - Solo primitive del framework (generatore casuale, SHA-256, HMAC-SHA256). Mai password, codici o impronte nei registri.
' Tabella: docs/STAY_SIGNED_IN_DEVICES_TABLE.md (login_remembered_devices), creata dal PO; finche manca il servizio resta inerte.

Public Enum StaySignedInOutcome
    Restored = 1
    NoToken = 2
    Unknown = 3
    Refused = 4
    Unavailable = 5
End Enum

Public NotInheritable Class StaySignedInAccount
    Public Property LoginId As Integer
    Public Property UtentiId As Integer
    Public Property AziendeId As Integer
    Public Property UserName As String = String.Empty
    Public Property StoredSecret As String = String.Empty
    Public Property PasswordDate As String = String.Empty
    Public Property Enabled As Boolean
End Class

Public NotInheritable Class StaySignedInRow
    Public Property Found As Boolean
    Public Property Id As Long
    Public Property LoginId As Integer
    Public Property AziendeId As Integer
    Public Property CredentialStamp As String = String.Empty
    Public Property Revoked As Boolean
    Public Property NotExpired As Boolean
    Public Property NeedsRenew As Boolean
End Class

' Fase 2: che cosa fare del dispositivo ricordato in questa richiesta.
Public Enum StaySignedInRestoreStep
    None = 0
    Restore = 1
    Regenerate = 2
    Blocked = 3
End Enum

' Fase 2: le chiavi di sessione che l'accesso scrive e la rivalidazione del master non idrata.
Public NotInheritable Class StaySignedInProfile
    Public Property Email As Object
    Public Property DisplayName As Object
    Public Property LastAccess As Object
    Public Property PriceListEnabled As Integer
    Public Property MailHtml As Object
    Public Property PasswordDate As Object
    Public Property CanOrder As Object
End Class

Public NotInheritable Class KeepStoreStaySignedIn
    Private Sub New()
    End Sub

    Public Const CookieName As String = "__Host-KeepStoreStay"
    Public Const TableName As String = "login_remembered_devices"
    Public Const LifetimeDays As Integer = 30
    Public Const RenewAfterHours As Integer = 24
    Public Const MaxDevicesPerLogin As Integer = 10
    Public Const SuspendMinutes As Integer = 5
    Public Const SecretLength As Integer = 32
    Private Const CookiePrefix As String = "v1."
    Private Const TokenTag As String = "KeepStoreStay/v1/token"
    Private Const StampTag As String = "KeepStoreStay/v1/stamp"

    Private Shared ReadOnly SuspendLock As New Object()
    Private Shared _suspendedUntilUtc As DateTime = DateTime.MinValue

    ' ---------------------------------------------------------------- funzioni pure

    Public Shared Function CreateSecret() As Byte()
        Dim secret(SecretLength - 1) As Byte
        Using generator As New RNGCryptoServiceProvider()
            generator.GetBytes(secret)
        End Using
        Return secret
    End Function

    Public Shared Function FormatCookieValue(ByVal secret As Byte()) As String
        If secret Is Nothing OrElse secret.Length <> SecretLength Then Throw New ArgumentException("Invalid stay-signed-in secret")
        Return CookiePrefix & Convert.ToBase64String(secret).TrimEnd("="c).Replace("+"c, "-"c).Replace("/"c, "_"c)
    End Function

    ' Formato rigido: "v1." + 43 caratteri base64url (32 byte). Ogni altra forma = False.
    Public Shared Function TryParseCookieValue(ByVal value As String, ByRef secret As Byte()) As Boolean
        secret = Nothing
        If value Is Nothing OrElse value.Length <> CookiePrefix.Length + 43 OrElse Not value.StartsWith(CookiePrefix, StringComparison.Ordinal) Then Return False
        Dim body As String = value.Substring(CookiePrefix.Length)
        For Each ch As Char In body
            If Not ((ch >= "a"c AndAlso ch <= "z"c) OrElse (ch >= "A"c AndAlso ch <= "Z"c) OrElse (ch >= "0"c AndAlso ch <= "9"c) OrElse ch = "-"c OrElse ch = "_"c) Then Return False
        Next
        Try
            Dim decoded As Byte() = Convert.FromBase64String(body.Replace("-"c, "+"c).Replace("_"c, "/"c) & "=")
            If decoded.Length <> SecretLength Then Return False
            ' Una sola scrittura per ogni codice: il valore deve essere quello che FormatCookieValue produrrebbe.
            If Not String.Equals(FormatCookieValue(decoded), value, StringComparison.Ordinal) Then Return False
            secret = decoded
            Return True
        Catch
            Return False
        End Try
    End Function

    ' Serializzazione non ambigua: ogni campo e preceduto dalla sua lunghezza (4 byte, big-endian).
    Private Shared Sub WriteField(ByVal stream As MemoryStream, ByVal bytes As Byte())
        Dim length As Integer = bytes.Length
        stream.WriteByte(CByte((length >> 24) And &HFF))
        stream.WriteByte(CByte((length >> 16) And &HFF))
        stream.WriteByte(CByte((length >> 8) And &HFF))
        stream.WriteByte(CByte(length And &HFF))
        stream.Write(bytes, 0, length)
    End Sub

    Private Shared Sub WriteText(ByVal stream As MemoryStream, ByVal text As String)
        WriteField(stream, Encoding.UTF8.GetBytes(If(text, String.Empty)))
    End Sub

    Private Shared Function ToHex(ByVal bytes As Byte()) As String
        Dim builder As New StringBuilder(bytes.Length * 2)
        For Each b As Byte In bytes
            builder.Append(b.ToString("x2", CultureInfo.InvariantCulture))
        Next
        Return builder.ToString()
    End Function

    Private Shared Function NormalizeScope(ByVal databaseScope As String) As String
        Return If(databaseScope, String.Empty).Trim().ToLowerInvariant()
    End Function

    ' Impronta del codice custodita nel database: legata a database e azienda, cosi lo stesso codice non vale altrove.
    Public Shared Function ComputeTokenHash(ByVal databaseScope As String, ByVal companyId As Integer, ByVal secret As Byte()) As String
        If NormalizeScope(databaseScope).Length = 0 OrElse companyId <= 0 OrElse secret Is Nothing OrElse secret.Length <> SecretLength Then
            Throw New ArgumentException("Invalid stay-signed-in token input")
        End If
        Using stream As New MemoryStream()
            WriteText(stream, TokenTag)
            WriteText(stream, NormalizeScope(databaseScope))
            WriteText(stream, companyId.ToString(CultureInfo.InvariantCulture))
            WriteField(stream, secret)
            Using sha As SHA256 = SHA256.Create()
                Return ToHex(sha.ComputeHash(stream.ToArray()))
            End Using
        End Using
    End Function

    ' Impronta di controllo dell'identita e delle credenziali COME SONO nel database (password esatta, non normalizzata).
    Public Shared Function ComputeCredentialStamp(ByVal secret As Byte(), ByVal databaseScope As String, ByVal account As StaySignedInAccount) As String
        If secret Is Nothing OrElse secret.Length <> SecretLength OrElse account Is Nothing OrElse NormalizeScope(databaseScope).Length = 0 Then
            Throw New ArgumentException("Invalid stay-signed-in stamp input")
        End If
        Using stream As New MemoryStream()
            WriteText(stream, StampTag)
            WriteText(stream, NormalizeScope(databaseScope))
            WriteText(stream, account.AziendeId.ToString(CultureInfo.InvariantCulture))
            WriteText(stream, account.LoginId.ToString(CultureInfo.InvariantCulture))
            WriteText(stream, account.UtentiId.ToString(CultureInfo.InvariantCulture))
            WriteText(stream, If(account.UserName, String.Empty).ToUpperInvariant())
            WriteText(stream, If(account.StoredSecret, String.Empty))
            WriteText(stream, If(account.PasswordDate, String.Empty))
            Using hmac As New HMACSHA256(secret)
                Return ToHex(hmac.ComputeHash(stream.ToArray()))
            End Using
        End Using
    End Function

    Public Shared Function ConstantTimeEquals(ByVal first As String, ByVal second As String) As Boolean
        If first Is Nothing OrElse second Is Nothing OrElse first.Length <> second.Length Then Return False
        Dim difference As Integer = 0
        For i As Integer = 0 To first.Length - 1
            difference = difference Or (Convert.ToInt32(first.Chars(i)) Xor Convert.ToInt32(second.Chars(i)))
        Next
        Return difference = 0
    End Function

    ' Decisione sul ripristino. revokeReason non vuoto = la riga va annullata con quel motivo.
    Public Shared Function Decide(ByVal row As StaySignedInRow, ByVal account As StaySignedInAccount, ByVal companyId As Integer,
                                  ByVal expectedStamp As String, ByRef revokeReason As String) As StaySignedInOutcome
        revokeReason = String.Empty
        If row Is Nothing OrElse Not row.Found Then Return StaySignedInOutcome.Unknown
        If row.Revoked OrElse Not row.NotExpired Then Return StaySignedInOutcome.Refused
        If companyId <= 0 OrElse row.AziendeId <> companyId Then
            revokeReason = "account"
            Return StaySignedInOutcome.Refused
        End If
        If account Is Nothing OrElse Not account.Enabled OrElse account.LoginId <> row.LoginId OrElse account.AziendeId <> companyId OrElse account.UtentiId <= 0 Then
            revokeReason = "account"
            Return StaySignedInOutcome.Refused
        End If
        If String.IsNullOrEmpty(expectedStamp) OrElse Not ConstantTimeEquals(row.CredentialStamp, expectedStamp) Then
            revokeReason = "credentials"
            Return StaySignedInOutcome.Refused
        End If
        Return StaySignedInOutcome.Restored
    End Function

    ' Fase 2, decisione pura: il ripristino si tenta solo su una GET, fuori da accesso, uscita, ordine e pagamento, con la funzione accesa.
    ' Il ripristino avviene SOLO in una sessione il cui identificativo e stato creato dal sito (richiesta senza cookie di sessione):
    ' se il browser porta un cookie di sessione, prima si cambia sessione (Regenerate); se il cambio e gia stato tentato e il cookie
    ' di sessione c'e ancora, non si ripristina (Blocked).
    Public Shared Function DecideRestoreStep(ByVal enabled As Boolean, ByVal httpMethod As String, ByVal scriptPathLower As String,
                                             ByVal isCheckoutPath As Boolean, ByVal hasDeviceCookie As Boolean,
                                             ByVal hasSessionCookie As Boolean, ByVal hasHopCookie As Boolean,
                                             ByVal skippedInThisSession As Boolean) As StaySignedInRestoreStep
        If Not enabled OrElse Not hasDeviceCookie OrElse skippedInThisSession Then Return StaySignedInRestoreStep.None
        If Not String.Equals(httpMethod, "GET", StringComparison.Ordinal) Then Return StaySignedInRestoreStep.None
        Dim path As String = If(scriptPathLower, String.Empty)
        If path.Length = 0 OrElse isCheckoutPath OrElse path.EndsWith("/logout.aspx", StringComparison.Ordinal) OrElse
           path.EndsWith("/login.aspx", StringComparison.Ordinal) OrElse path.EndsWith("/accessonegato.aspx", StringComparison.Ordinal) Then
            Return StaySignedInRestoreStep.None
        End If
        If hasSessionCookie Then Return If(hasHopCookie, StaySignedInRestoreStep.Blocked, StaySignedInRestoreStep.Regenerate)
        Return StaySignedInRestoreStep.Restore
    End Function

    ' Destinazione del cambio di sessione: solo un percorso locale del sito, mai un altro host.
    Public Shared Function LocalRedirectTarget(ByVal rawUrl As String) As String
        Dim value As String = If(rawUrl, String.Empty)
        If value.Length = 0 OrElse value.Chars(0) <> "/"c Then Return "/"
        If value.Length > 1 AndAlso (value.Chars(1) = "/"c OrElse value.Chars(1) = "\"c) Then Return "/"
        For Each ch As Char In value
            If Convert.ToInt32(ch) < 32 OrElse ch = "\"c Then Return "/"
        Next
        Return value
    End Function

    ' ---------------------------------------------------------------- disponibilita della tabella (fase 2)

    Public Const AvailabilityMinutes As Integer = 5
    Private Shared ReadOnly AvailabilityLock As New Object()
    Private Shared _availabilityUntilUtc As DateTime = DateTime.MinValue
    Private Shared _available As Boolean = False

    Public Shared Sub ResetAvailability()
        SyncLock AvailabilityLock
            _availabilityUntilUtc = DateTime.MinValue
            _available = False
        End SyncLock
    End Sub

    ' La tabella esiste con tutte le colonne che il servizio usa. Il risultato vale 5 minuti; ogni errore = non disponibile.
    Public Shared Function IsAvailable(ByVal connectionString As String) As Boolean
        If String.IsNullOrWhiteSpace(connectionString) Then Return False
        SyncLock AvailabilityLock
            If DateTime.UtcNow < _availabilityUntilUtc Then Return _available
        End SyncLock
        Dim found As Boolean = False
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Using command As New MySqlCommand("SELECT id, LoginId, AziendeId, TokenHash, CredentialStamp, CreatedUtc, LastUsedUtc, ExpiresUtc, RevokedUtc, RevokeReason " &
                                                  "FROM login_remembered_devices LIMIT 0", connection)
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        found = reader.FieldCount = 10
                    End Using
                End Using
            End Using
        Catch
            found = False
        End Try
        SyncLock AvailabilityLock
            _available = found
            _availabilityUntilUtc = DateTime.UtcNow.AddMinutes(AvailabilityMinutes)
        End SyncLock
        Return found
    End Function

    ' Le chiavi di sessione dell'accesso per l'utente GIA verificato (accesso, azienda e utente devono coincidere). Nothing = non piu valido.
    Public Shared Function LoadSessionProfile(ByVal connectionString As String, ByVal loginId As Integer, ByVal companyId As Integer, ByVal userId As Integer) As StaySignedInProfile
        If String.IsNullOrWhiteSpace(connectionString) OrElse loginId <= 0 OrElse companyId <= 0 OrElse userId <= 0 Then Return Nothing
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Const sql As String = "SELECT DISTINCT email, CognomeNome, UltimoAccesso, COALESCE(AbilitaListino,0), genera_html_mail, DataPassword, CanOrder FROM vlogin " &
                                      "WHERE id=?loginId AND AziendeId=?aziendaId AND UtentiId=?utentiId AND Abilitato=1 AND UtentiAbilitato=1 LIMIT 2"
                Using command As New MySqlCommand(sql, connection)
                    command.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
                    command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = companyId
                    command.Parameters.Add("?utentiId", MySqlDbType.Int32).Value = userId
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        If Not reader.Read() Then Return Nothing
                        Dim profile As New StaySignedInProfile()
                        profile.Email = reader(0)
                        profile.DisplayName = reader(1)
                        profile.LastAccess = reader(2)
                        profile.PriceListEnabled = Convert.ToInt32(reader(3), CultureInfo.InvariantCulture)
                        profile.MailHtml = reader(4)
                        profile.PasswordDate = reader(5)
                        profile.CanOrder = reader(6)
                        If reader.Read() Then Return Nothing
                        Return profile
                    End Using
                End Using
            End Using
        Catch
            Return Nothing
        End Try
    End Function

    ' ---------------------------------------------------------------- sospensione dopo un errore del database

    Public Shared Function IsSuspended() As Boolean
        SyncLock SuspendLock
            Return DateTime.UtcNow < _suspendedUntilUtc
        End SyncLock
    End Function

    Public Shared Sub ResetSuspension()
        SyncLock SuspendLock
            _suspendedUntilUtc = DateTime.MinValue
        End SyncLock
    End Sub

    Private Shared Sub Suspend()
        SyncLock SuspendLock
            _suspendedUntilUtc = DateTime.UtcNow.AddMinutes(SuspendMinutes)
        End SyncLock
    End Sub

    ' ---------------------------------------------------------------- accesso ai dati

    ' L'accesso com'e nel database, per quell'azienda. Una riga esatta, altrimenti Nothing.
    Public Shared Function LoadAccount(ByVal connection As MySqlConnection, ByVal loginId As Integer, ByVal companyId As Integer) As StaySignedInAccount
        If loginId <= 0 OrElse companyId <= 0 Then Return Nothing
        Const sql As String = "SELECT DISTINCT id, COALESCE(UtentiId,0), COALESCE(AziendeId,0), COALESCE(UserName,''), COALESCE(Password,''), " &
                              "COALESCE(DATE_FORMAT(DataPassword,'%Y-%m-%d %H:%i:%s'),''), COALESCE(Abilitato,0), COALESCE(UtentiAbilitato,0) " &
                              "FROM vlogin WHERE id=?loginId AND AziendeId=?aziendaId LIMIT 2"
        Dim found As StaySignedInAccount = Nothing
        Using command As New MySqlCommand(sql, connection)
            command.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
            command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = companyId
            Using reader As MySqlDataReader = command.ExecuteReader()
                If Not reader.Read() Then Return Nothing
                found = New StaySignedInAccount()
                found.LoginId = Convert.ToInt32(reader(0), CultureInfo.InvariantCulture)
                found.UtentiId = Convert.ToInt32(reader(1), CultureInfo.InvariantCulture)
                found.AziendeId = Convert.ToInt32(reader(2), CultureInfo.InvariantCulture)
                found.UserName = Convert.ToString(reader(3), CultureInfo.InvariantCulture)
                found.StoredSecret = Convert.ToString(reader(4), CultureInfo.InvariantCulture)
                found.PasswordDate = Convert.ToString(reader(5), CultureInfo.InvariantCulture)
                found.Enabled = Convert.ToInt32(reader(6), CultureInfo.InvariantCulture) = 1 AndAlso Convert.ToInt32(reader(7), CultureInfo.InvariantCulture) = 1
                If reader.Read() Then Return Nothing
            End Using
        End Using
        Return found
    End Function

    Private Shared Function LoadRow(ByVal connection As MySqlConnection, ByVal tokenHash As String) As StaySignedInRow
        Dim row As New StaySignedInRow()
        Const sql As String = "SELECT id, LoginId, AziendeId, CredentialStamp, (RevokedUtc IS NOT NULL), (ExpiresUtc > UTC_TIMESTAMP()), " &
                              "(LastUsedUtc <= UTC_TIMESTAMP() - INTERVAL ?ore HOUR) FROM login_remembered_devices WHERE TokenHash=?hash"
        Using command As New MySqlCommand(sql, connection)
            command.Parameters.Add("?ore", MySqlDbType.Int32).Value = RenewAfterHours
            command.Parameters.Add("?hash", MySqlDbType.VarChar, 64).Value = tokenHash
            Using reader As MySqlDataReader = command.ExecuteReader()
                If Not reader.Read() Then Return row
                row.Found = True
                row.Id = Convert.ToInt64(reader(0), CultureInfo.InvariantCulture)
                row.LoginId = Convert.ToInt32(reader(1), CultureInfo.InvariantCulture)
                row.AziendeId = Convert.ToInt32(reader(2), CultureInfo.InvariantCulture)
                row.CredentialStamp = Convert.ToString(reader(3), CultureInfo.InvariantCulture)
                row.Revoked = Convert.ToInt32(reader(4), CultureInfo.InvariantCulture) <> 0
                row.NotExpired = Convert.ToInt32(reader(5), CultureInfo.InvariantCulture) <> 0
                row.NeedsRenew = Convert.ToInt32(reader(6), CultureInfo.InvariantCulture) <> 0
            End Using
        End Using
        Return row
    End Function

    Private Shared Function RevokeRow(ByVal connection As MySqlConnection, ByVal rowId As Long, ByVal reason As String) As Integer
        Using command As New MySqlCommand("UPDATE login_remembered_devices SET RevokedUtc=UTC_TIMESTAMP(), RevokeReason=?motivo WHERE id=?id AND RevokedUtc IS NULL", connection)
            command.Parameters.Add("?motivo", MySqlDbType.VarChar, 20).Value = SafeReason(reason)
            command.Parameters.Add("?id", MySqlDbType.Int64).Value = rowId
            Return command.ExecuteNonQuery()
        End Using
    End Function

    Private Shared Function RenewRow(ByVal connection As MySqlConnection, ByVal rowId As Long) As Integer
        Using command As New MySqlCommand("UPDATE login_remembered_devices SET LastUsedUtc=UTC_TIMESTAMP(), ExpiresUtc=UTC_TIMESTAMP() + INTERVAL ?giorni DAY " &
                                          "WHERE id=?id AND RevokedUtc IS NULL AND ExpiresUtc > UTC_TIMESTAMP() AND LastUsedUtc <= UTC_TIMESTAMP() - INTERVAL ?ore HOUR", connection)
            command.Parameters.Add("?giorni", MySqlDbType.Int32).Value = LifetimeDays
            command.Parameters.Add("?id", MySqlDbType.Int64).Value = rowId
            command.Parameters.Add("?ore", MySqlDbType.Int32).Value = RenewAfterHours
            Return command.ExecuteNonQuery()
        End Using
    End Function

    Private Shared Function SafeReason(ByVal reason As String) As String
        Dim builder As New StringBuilder()
        For Each ch As Char In If(reason, String.Empty).ToLowerInvariant()
            If (ch >= "a"c AndAlso ch <= "z"c) AndAlso builder.Length < 20 Then builder.Append(ch)
        Next
        Return If(builder.Length = 0, "other", builder.ToString())
    End Function

    ' Ricorda questo dispositivo per l'accesso indicato. Restituisce il valore del cookie, oppure "" (nessun cookie va emesso).
    Public Shared Function Issue(ByVal connectionString As String, ByVal databaseScope As String, ByVal companyId As Integer, ByVal loginId As Integer) As String
        If String.IsNullOrWhiteSpace(connectionString) OrElse NormalizeScope(databaseScope).Length = 0 OrElse companyId <= 0 OrElse loginId <= 0 OrElse IsSuspended() Then Return String.Empty
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Dim account As StaySignedInAccount = LoadAccount(connection, loginId, companyId)
                If account Is Nothing OrElse Not account.Enabled OrElse account.UtentiId <= 0 Then Return String.Empty
                Dim secret As Byte() = CreateSecret()
                Dim tokenHash As String = ComputeTokenHash(databaseScope, companyId, secret)
                Dim stamp As String = ComputeCredentialStamp(secret, databaseScope, account)

                ' Pulizia delle righe scadute di questo accesso e limite dei dispositivi (i piu vecchi si annullano).
                Using cleanup As New MySqlCommand("DELETE FROM login_remembered_devices WHERE LoginId=?loginId AND ExpiresUtc <= UTC_TIMESTAMP()", connection)
                    cleanup.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
                    cleanup.ExecuteNonQuery()
                End Using
                Dim active As Integer
                Using count As New MySqlCommand("SELECT COUNT(*) FROM login_remembered_devices WHERE LoginId=?loginId AND RevokedUtc IS NULL", connection)
                    count.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
                    active = Convert.ToInt32(count.ExecuteScalar(), CultureInfo.InvariantCulture)
                End Using
                If active >= MaxDevicesPerLogin Then
                    Using limit As New MySqlCommand("UPDATE login_remembered_devices SET RevokedUtc=UTC_TIMESTAMP(), RevokeReason='limit' " &
                                                    "WHERE LoginId=?loginId AND RevokedUtc IS NULL ORDER BY LastUsedUtc ASC, id ASC LIMIT ?quanti", connection)
                        limit.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
                        limit.Parameters.Add("?quanti", MySqlDbType.Int32).Value = active - MaxDevicesPerLogin + 1
                        limit.ExecuteNonQuery()
                    End Using
                End If
                Using insert As New MySqlCommand("INSERT INTO login_remembered_devices (LoginId, AziendeId, TokenHash, CredentialStamp, CreatedUtc, LastUsedUtc, ExpiresUtc) " &
                                                 "VALUES (?loginId, ?aziendaId, ?hash, ?stamp, UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP() + INTERVAL ?giorni DAY)", connection)
                    insert.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
                    insert.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = companyId
                    insert.Parameters.Add("?hash", MySqlDbType.VarChar, 64).Value = tokenHash
                    insert.Parameters.Add("?stamp", MySqlDbType.VarChar, 64).Value = stamp
                    insert.Parameters.Add("?giorni", MySqlDbType.Int32).Value = LifetimeDays
                    If insert.ExecuteNonQuery() <> 1 Then Return String.Empty
                End Using
                Return FormatCookieValue(secret)
            End Using
        Catch
            Suspend()
            Return String.Empty
        End Try
    End Function

    ' Riconosce il dispositivo. Restored = account valido (da passare alla rivalidazione di sempre); renewed = il cookie va riemesso con la nuova scadenza.
    Public Shared Function TryRestore(ByVal connectionString As String, ByVal databaseScope As String, ByVal companyId As Integer, ByVal cookieValue As String,
                                      ByRef account As StaySignedInAccount, ByRef renewed As Boolean) As StaySignedInOutcome
        account = Nothing
        renewed = False
        Dim secret As Byte() = Nothing
        If Not TryParseCookieValue(cookieValue, secret) Then Return StaySignedInOutcome.NoToken
        If String.IsNullOrWhiteSpace(connectionString) OrElse NormalizeScope(databaseScope).Length = 0 OrElse companyId <= 0 OrElse IsSuspended() Then Return StaySignedInOutcome.Unavailable
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Dim row As StaySignedInRow = LoadRow(connection, ComputeTokenHash(databaseScope, companyId, secret))
                Dim found As StaySignedInAccount = Nothing
                Dim expectedStamp As String = String.Empty
                If row.Found AndAlso Not row.Revoked AndAlso row.NotExpired Then
                    found = LoadAccount(connection, row.LoginId, companyId)
                    If found IsNot Nothing Then expectedStamp = ComputeCredentialStamp(secret, databaseScope, found)
                End If
                Dim revokeReason As String = String.Empty
                Dim outcome As StaySignedInOutcome = Decide(row, found, companyId, expectedStamp, revokeReason)
                If revokeReason.Length > 0 Then RevokeRow(connection, row.Id, revokeReason)
                If outcome <> StaySignedInOutcome.Restored Then Return outcome
                If row.NeedsRenew Then renewed = RenewRow(connection, row.Id) = 1
                account = found
                Return StaySignedInOutcome.Restored
            End Using
        Catch
            Suspend()
            account = Nothing
            renewed = False
            Return StaySignedInOutcome.Unavailable
        End Try
    End Function

    ' Uso durante una sessione gia collegata: rinnova la scadenza (al massimo ogni 24 ore) solo se il dispositivo e di QUELL'accesso.
    ' True = scadenza rinnovata, il cookie va riemesso.
    Public Shared Function Touch(ByVal connectionString As String, ByVal databaseScope As String, ByVal companyId As Integer, ByVal loginId As Integer, ByVal cookieValue As String) As Boolean
        Dim secret As Byte() = Nothing
        If Not TryParseCookieValue(cookieValue, secret) OrElse String.IsNullOrWhiteSpace(connectionString) OrElse NormalizeScope(databaseScope).Length = 0 OrElse
           companyId <= 0 OrElse loginId <= 0 OrElse IsSuspended() Then Return False
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Dim row As StaySignedInRow = LoadRow(connection, ComputeTokenHash(databaseScope, companyId, secret))
                If Not row.Found OrElse row.Revoked OrElse Not row.NotExpired OrElse row.LoginId <> loginId OrElse row.AziendeId <> companyId OrElse Not row.NeedsRenew Then Return False
                Return RenewRow(connection, row.Id) = 1
            End Using
        Catch
            Suspend()
            Return False
        End Try
    End Function

    ' Uscita o sostituzione: annulla il dispositivo di questo cookie. Vale anche senza sessione. True = una riga annullata.
    Public Shared Function Revoke(ByVal connectionString As String, ByVal databaseScope As String, ByVal companyId As Integer, ByVal cookieValue As String, ByVal reason As String) As Boolean
        Dim secret As Byte() = Nothing
        If Not TryParseCookieValue(cookieValue, secret) OrElse String.IsNullOrWhiteSpace(connectionString) OrElse NormalizeScope(databaseScope).Length = 0 OrElse
           companyId <= 0 OrElse IsSuspended() Then Return False
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Dim row As StaySignedInRow = LoadRow(connection, ComputeTokenHash(databaseScope, companyId, secret))
                If Not row.Found OrElse row.Revoked Then Return False
                Return RevokeRow(connection, row.Id, reason) = 1
            End Using
        Catch
            Suspend()
            Return False
        End Try
    End Function

    ' Cambio della password dal sito: annulla tutti i dispositivi di quell'accesso. Restituisce quante righe ha annullato.
    Public Shared Function RevokeAllForLogin(ByVal connectionString As String, ByVal loginId As Integer, ByVal reason As String) As Integer
        If String.IsNullOrWhiteSpace(connectionString) OrElse loginId <= 0 OrElse IsSuspended() Then Return 0
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Using command As New MySqlCommand("UPDATE login_remembered_devices SET RevokedUtc=UTC_TIMESTAMP(), RevokeReason=?motivo WHERE LoginId=?loginId AND RevokedUtc IS NULL", connection)
                    command.Parameters.Add("?motivo", MySqlDbType.VarChar, 20).Value = SafeReason(reason)
                    command.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
                    Return command.ExecuteNonQuery()
                End Using
            End Using
        Catch
            Suspend()
            Return 0
        End Try
    End Function
End Class
