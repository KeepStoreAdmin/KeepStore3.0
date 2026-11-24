Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Security.Cryptography
Imports System.Text
Imports System.Threading
Imports MySql.Data.MySqlClient

' AUTH-ATTEMPT-LIMIT-1A: limite ai tentativi sulla password (accesso, cambio password, cambio e-mail). Servizio AUTONOMO: non conosce pagine,
' sessione, configurazione ne registri (li usa lo strato KeepStoreAuthAttemptLimitWeb). Decisione: .ai-review/auth-attempt-limit-1a/decisione.md.
' Regole:
' - La tabella login_attempt_limits (docs/AUTH_ATTEMPT_LIMIT_TABLE.md) e NUOVA: non tocca login, utenti, routine o gestionale. Si toglie con DROP TABLE.
' - Ogni controllo e una PRENOTAZIONE atomica fatta PRIMA di confrontare la password, su una connessione PROPRIA (mai dentro la transazione della pagina:
'   un annullamento della pagina non deve cancellare l'errore). La prenotazione vale come errore presunto: il successo azzera, un'uscita senza confronto la restituisce.
' - 5 errori in 15 minuti => blocco di 15 minuti; ricadute entro 24 ore dal blocco => 30 e 60 minuti (tetto). Mai blocco permanente. Un rifiuto non scrive nulla.
' - Tutto il tempo e quello del DATABASE (UTC_TIMESTAMP()); l'orologio del sito serve solo alla sospensione dopo un errore della tabella.
' - Nessun metodo lancia eccezioni verso la pagina: tabella assente = spento (ricontrollo dopo 5 minuti); altro errore = si lascia passare (Inactive).
' - Mai nome utente, password o indirizzo nel database o nei messaggi: la chiave e un'impronta SHA-256.

Public Enum AttemptLimitDecision
    Allowed = 0
    Blocked = 1
    Inactive = 2
End Enum

Public NotInheritable Class KeepStoreAuthAttemptLimit
    Private Sub New()
    End Sub

    Public Const ScopeLogin As Integer = 1
    Public Const ScopeCurrentPassword As Integer = 2
    Public Const ScopeUnknownUser As Integer = 3
    Public Const MaxFailures As Integer = 5
    Public Const WindowMinutes As Integer = 15
    Public Const StrikeHours As Integer = 24
    Public Const CleanupEvery As Integer = 50
    Public Const CleanupRows As Integer = 200
    Public Const CleanupAfterHours As Integer = 48
    Public Const SuspendMinutes As Integer = 5
    Public Const TableName As String = "login_attempt_limits"

    Private Const MySqlTableMissing As Integer = 1146
    Private Const MySqlDeadlock As Integer = 1213
    Private Const MySqlLockWait As Integer = 1205

    Private Shared ReadOnly StateLock As New Object()
    Private Shared _suspendedUntilUtc As DateTime = DateTime.MinValue
    Private Shared _notice As String = String.Empty
    Private Shared _writes As Integer = 0
    Private Shared _lastError As String = String.Empty

    ' Impronta della chiave: SHA-256 esadecimale minuscola di "v1|scopo|chiave". La chiave e il LoginId (scopi 1 e 2) o il nome digitato in minuscolo
    ' invariante (scopo 3). Non dipende da collation, cultura o maiuscole del nome.
    Public Shared Function ComputeKeyHash(ByVal scope As Integer, ByVal key As String) As String
        Dim text As String = "v1|" & scope.ToString(CultureInfo.InvariantCulture) & "|" & If(key, String.Empty)
        Using sha As SHA256 = SHA256.Create()
            Dim hash As Byte() = sha.ComputeHash(Encoding.UTF8.GetBytes(text))
            Dim builder As New StringBuilder(64)
            For Each b As Byte In hash
                builder.Append(b.ToString("x2", CultureInfo.InvariantCulture))
            Next
            Return builder.ToString()
        End Using
    End Function

    Public Shared Function NormalizeUnknownName(ByVal typed As String) As String
        Return If(typed, String.Empty).Trim().ToLowerInvariant()
    End Function

    Public Shared Function IsSuspended() As Boolean
        SyncLock StateLock
            Return DateTime.UtcNow < _suspendedUntilUtc
        End SyncLock
    End Function

    ' Una sola segnalazione per volta ("table-missing" o "degraded"), da registrare a cura dello strato web; vuota se non c'e nulla da dire.
    Public Shared Function TakeNotice() As String
        SyncLock StateLock
            Dim result As String = _notice
            _notice = String.Empty
            Return result
        End SyncLock
    End Function

    ' Solo per le prove: tipo e numero MySQL dell'ultimo errore (mai testi di errore, che potrebbero contenere valori).
    Public Shared Function LastErrorForTests() As String
        SyncLock StateLock
            Return _lastError
        End SyncLock
    End Function

    Private Shared Sub Remember(ByVal ex As Exception)
        Dim mysql As MySqlException = TryCast(ex, MySqlException)
        SyncLock StateLock
            _lastError = ex.GetType().Name & If(mysql IsNot Nothing, " " & mysql.Number.ToString(CultureInfo.InvariantCulture), String.Empty)
        End SyncLock
    End Sub

    Public Shared Sub ResetStateForTests()
        SyncLock StateLock
            _suspendedUntilUtc = DateTime.MinValue
            _notice = String.Empty
            _writes = 0
            _lastError = String.Empty
        End SyncLock
    End Sub

    Private Shared Sub Suspend(ByVal notice As String)
        SyncLock StateLock
            _suspendedUntilUtc = DateTime.UtcNow.AddMinutes(SuspendMinutes)
            If _notice.Length = 0 Then _notice = notice
        End SyncLock
    End Sub

    Private Shared Sub NoteDegraded()
        SyncLock StateLock
            If _notice.Length = 0 Then _notice = "degraded"
        End SyncLock
    End Sub

    Private Shared Function ValidInput(ByVal connectionString As String, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String) As Boolean
        Return Not String.IsNullOrWhiteSpace(connectionString) AndAlso companyId > 0 AndAlso scope >= ScopeLogin AndAlso scope <= ScopeUnknownUser AndAlso Not String.IsNullOrEmpty(key)
    End Function

    Private Shared Function IsTableMissing(ByVal ex As Exception) As Boolean
        Dim mysql As MySqlException = TryCast(ex, MySqlException)
        Return mysql IsNot Nothing AndAlso mysql.Number = MySqlTableMissing
    End Function

    Private Shared Function IsRetryable(ByVal ex As Exception) As Boolean
        Dim mysql As MySqlException = TryCast(ex, MySqlException)
        Return mysql IsNot Nothing AndAlso (mysql.Number = MySqlDeadlock OrElse mysql.Number = MySqlLockWait)
    End Function

    ' Prenota un tentativo. Allowed = si puo confrontare la password (e poi chiamare Succeed o Fail, oppure Release se non si confronta);
    ' Blocked = rifiutare senza confrontare; Inactive = funzione non attiva o degradata, nessuna prenotazione, si procede come prima.
    Public Shared Function Reserve(ByVal connectionString As String, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String) As AttemptLimitDecision
        If Not ValidInput(connectionString, companyId, scope, key) OrElse IsSuspended() Then Return AttemptLimitDecision.Inactive
        Dim hash As String = ComputeKeyHash(scope, key)
        Dim attempt As Integer = 0
        While True
            attempt += 1
            Try
                Dim decision As AttemptLimitDecision = ReserveOnce(connectionString, companyId, scope, hash)
                CleanupSometimes(connectionString)
                Return decision
            Catch ex As Exception
                Remember(ex)
                If IsTableMissing(ex) Then
                    Suspend("table-missing")
                    Return AttemptLimitDecision.Inactive
                End If
                If attempt < 3 AndAlso IsRetryable(ex) Then Continue While
                NoteDegraded()
                Return AttemptLimitDecision.Inactive
            End Try
        End While
        Return AttemptLimitDecision.Inactive
    End Function

    Private Shared Function ReserveOnce(ByVal connectionString As String, ByVal companyId As Integer, ByVal scope As Integer, ByVal hash As String) As AttemptLimitDecision
        Using connection As New MySqlConnection(connectionString)
            connection.Open()
            ' La riga si crea FUORI dalla transazione (autocommit): un INSERT IGNORE dentro la transazione lascia un blocco condiviso sulla chiave e,
            ' con richieste simultanee, la successiva SELECT ... FOR UPDATE andrebbe in stallo (errore 1213) lasciando passare i tentativi.
            Using insert As New MySqlCommand(
                "INSERT IGNORE INTO login_attempt_limits (AziendeId, ScopeCode, KeyHash, FailCount, WindowStartUtc, UpdatedUtc) " &
                "VALUES (?aziendaId, ?scope, ?hash, 0, UTC_TIMESTAMP(), UTC_TIMESTAMP())", connection)
                AddKey(insert, companyId, scope, hash)
                insert.ExecuteNonQuery()
            End Using
            Using transaction As MySqlTransaction = connection.BeginTransaction()
                Dim failCount As Integer = 0
                Dim blocked As Boolean = False
                Dim blockExpired As Boolean = False
                Dim windowExpired As Boolean = False
                Using select1 As New MySqlCommand(
                    "SELECT FailCount, (BlockedUntilUtc IS NOT NULL AND BlockedUntilUtc > UTC_TIMESTAMP()), " &
                    "(BlockedUntilUtc IS NOT NULL AND BlockedUntilUtc <= UTC_TIMESTAMP()), " &
                    "(WindowStartUtc + INTERVAL " & WindowMinutes.ToString(CultureInfo.InvariantCulture) & " MINUTE <= UTC_TIMESTAMP()) " &
                    "FROM login_attempt_limits WHERE AziendeId = ?aziendaId AND ScopeCode = ?scope AND KeyHash = ?hash FOR UPDATE", connection, transaction)
                    AddKey(select1, companyId, scope, hash)
                    Using reader As MySqlDataReader = select1.ExecuteReader()
                        If Not reader.Read() Then
                            reader.Close()
                            transaction.Rollback()
                            Return AttemptLimitDecision.Inactive
                        End If
                        failCount = Convert.ToInt32(reader(0), CultureInfo.InvariantCulture)
                        blocked = Convert.ToInt32(reader(1), CultureInfo.InvariantCulture) = 1
                        blockExpired = Convert.ToInt32(reader(2), CultureInfo.InvariantCulture) = 1
                        windowExpired = Convert.ToInt32(reader(3), CultureInfo.InvariantCulture) = 1
                    End Using
                End Using

                If blocked Then
                    transaction.Commit()
                    Return AttemptLimitDecision.Blocked
                End If

                Dim reset As Boolean = blockExpired OrElse windowExpired
                If Not reset AndAlso failCount >= MaxFailures Then
                    transaction.Commit()
                    Return AttemptLimitDecision.Blocked
                End If

                Using update As New MySqlCommand(
                    "UPDATE login_attempt_limits SET " &
                    "FailCount = " & If(reset, "1", "FailCount + 1") & ", " &
                    If(reset, "WindowStartUtc = UTC_TIMESTAMP(), BlockedUntilUtc = NULL, ", String.Empty) &
                    "UpdatedUtc = UTC_TIMESTAMP() " &
                    "WHERE AziendeId = ?aziendaId AND ScopeCode = ?scope AND KeyHash = ?hash", connection, transaction)
                    AddKey(update, companyId, scope, hash)
                    update.ExecuteNonQuery()
                End Using
                transaction.Commit()
                Return AttemptLimitDecision.Allowed
            End Using
        End Using
    End Function

    ' Il confronto ha avuto successo: l'errore presunto e annullato e la progressione riparte da zero.
    Public Shared Sub Succeed(ByVal connectionString As String, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String)
        RunOutcome(connectionString, companyId, scope, key,
            "UPDATE login_attempt_limits SET FailCount = 0, BlockedUntilUtc = NULL, StrikeLevel = 0, StrikeExpiresUtc = NULL, UpdatedUtc = UTC_TIMESTAMP() " &
            "WHERE AziendeId = ?aziendaId AND ScopeCode = ?scope AND KeyHash = ?hash")
    End Sub

    ' Il confronto e fallito: se la soglia e raggiunta scatta il blocco (15, 30, 60 minuti). Un blocco gia attivo non si allunga.
    Public Shared Sub Fail(ByVal connectionString As String, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String)
        RunOutcome(connectionString, companyId, scope, key,
            "UPDATE login_attempt_limits SET " &
            "BlockedUntilUtc = UTC_TIMESTAMP() + INTERVAL ELT(IF(StrikeExpiresUtc IS NOT NULL AND StrikeExpiresUtc <= UTC_TIMESTAMP(), 0, StrikeLevel) + 1, 15, 30, 60) MINUTE, " &
            "StrikeLevel = LEAST(IF(StrikeExpiresUtc IS NOT NULL AND StrikeExpiresUtc <= UTC_TIMESTAMP(), 0, StrikeLevel) + 1, 2), " &
            "StrikeExpiresUtc = UTC_TIMESTAMP() + INTERVAL " & StrikeHours.ToString(CultureInfo.InvariantCulture) & " HOUR, " &
            "UpdatedUtc = UTC_TIMESTAMP() " &
            "WHERE AziendeId = ?aziendaId AND ScopeCode = ?scope AND KeyHash = ?hash " &
            "AND FailCount >= " & MaxFailures.ToString(CultureInfo.InvariantCulture) & " AND (BlockedUntilUtc IS NULL OR BlockedUntilUtc <= UTC_TIMESTAMP())")
    End Sub

    ' Nessun confronto e avvenuto (uscita prima del controllo): la prenotazione si restituisce.
    Public Shared Sub Release(ByVal connectionString As String, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String)
        RunOutcome(connectionString, companyId, scope, key,
            "UPDATE login_attempt_limits SET FailCount = GREATEST(FailCount - 1, 0), UpdatedUtc = UTC_TIMESTAMP() " &
            "WHERE AziendeId = ?aziendaId AND ScopeCode = ?scope AND KeyHash = ?hash AND (BlockedUntilUtc IS NULL OR BlockedUntilUtc <= UTC_TIMESTAMP())")
    End Sub

    ' Un recupero password completato dal titolare (codice ricevuto per e-mail) toglie il blocco dell'accesso di quel LoginId.
    Public Shared Sub ClearLogin(ByVal connectionString As String, ByVal loginId As Integer)
        If String.IsNullOrWhiteSpace(connectionString) OrElse loginId <= 0 OrElse IsSuspended() Then Return
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Using command As New MySqlCommand("DELETE FROM login_attempt_limits WHERE ScopeCode = ?scope AND KeyHash = ?hash", connection)
                    command.Parameters.Add("?scope", MySqlDbType.Int32).Value = ScopeLogin
                    command.Parameters.Add("?hash", MySqlDbType.VarChar, 64).Value = ComputeKeyHash(ScopeLogin, loginId.ToString(CultureInfo.InvariantCulture))
                    command.ExecuteNonQuery()
                End Using
            End Using
        Catch ex As Exception
            If IsTableMissing(ex) Then Suspend("table-missing") Else NoteDegraded()
        End Try
    End Sub

    Private Shared Sub RunOutcome(ByVal connectionString As String, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String, ByVal sql As String)
        If Not ValidInput(connectionString, companyId, scope, key) OrElse IsSuspended() Then Return
        Dim hash As String = ComputeKeyHash(scope, key)
        Dim attempt As Integer = 0
        While True
            attempt += 1
            Try
                Using connection As New MySqlConnection(connectionString)
                    connection.Open()
                    Using command As New MySqlCommand(sql, connection)
                        AddKey(command, companyId, scope, hash)
                        command.ExecuteNonQuery()
                    End Using
                End Using
                Return
            Catch ex As Exception
                Remember(ex)
                If IsTableMissing(ex) Then
                    Suspend("table-missing")
                    Return
                End If
                If attempt < 3 AndAlso IsRetryable(ex) Then Continue While
                NoteDegraded()
                Return
            End Try
        End While
    End Sub

    Private Shared Sub AddKey(ByVal command As MySqlCommand, ByVal companyId As Integer, ByVal scope As Integer, ByVal hash As String)
        command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = companyId
        command.Parameters.Add("?scope", MySqlDbType.Int32).Value = scope
        command.Parameters.Add("?hash", MySqlDbType.VarChar, 64).Value = hash
    End Sub

    ' Pulizia senza pianificatore: una scrittura ogni CleanupEvery toglie al massimo CleanupRows righe vecchie e mai un blocco ancora attivo.
    Private Shared Sub CleanupSometimes(ByVal connectionString As String)
        Dim run As Boolean
        SyncLock StateLock
            _writes += 1
            run = (_writes Mod CleanupEvery = 0)
        End SyncLock
        If Not run Then Return
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Using command As New MySqlCommand(
                    "DELETE FROM login_attempt_limits WHERE UpdatedUtc < UTC_TIMESTAMP() - INTERVAL " & CleanupAfterHours.ToString(CultureInfo.InvariantCulture) & " HOUR " &
                    "AND (BlockedUntilUtc IS NULL OR BlockedUntilUtc < UTC_TIMESTAMP()) ORDER BY UpdatedUtc LIMIT " & CleanupRows.ToString(CultureInfo.InvariantCulture), connection)
                    command.ExecuteNonQuery()
                End Using
            End Using
        Catch
            NoteDegraded()
        End Try
    End Sub
End Class
