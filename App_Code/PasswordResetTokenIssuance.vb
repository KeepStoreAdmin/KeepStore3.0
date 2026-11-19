Option Strict On
Option Explicit On

Imports System
Imports System.Data
Imports System.Globalization
Imports MySql.Data.MySqlClient

' AUTH-RESET-ISSUE-LOCK-1C: emissione di un codice di recupero della password, sotto blocco. Modulo autonomo (nessuna dipendenza dal web).
' Regole (.ai-review/auth-reset-issue-lock-1c/decisione.md):
' - In UNA transazione: si blocca la riga dell'accesso, si rilegge la sua e-mail, la si confronta con quella a cui il codice verra spedito;
'   solo se coincidono si annullano i codici pendenti dell'accesso e si inserisce quello nuovo. Cosi un cambio dell'e-mail in corso o appena
'   confermato non lascia nascere un codice valido verso il vecchio indirizzo (il cambio, a sua volta, annulla i codici gia emessi).
' - Il confronto si fa QUI e non in SQL, con la stessa regola di "Dati account" (spazi attorno e maiuscole non contano, gli accenti si):
'   la colonna dell'e-mail non distingue gli accenti e considererebbe uguali due indirizzi diversi.
' - Gli errori del database (attesa del blocco scaduta, stallo, impronta duplicata) si propagano dopo il rollback: chi chiama li registra e
'   non invia nulla. L'attesa del blocco e breve e vale solo per questa operazione.
Public NotInheritable Class PasswordResetTokenIssuance
    Private Sub New()
    End Sub

    Public Const LockWaitSeconds As Integer = 5
    Public Const TokenHashLength As Integer = 64

    ' Stessa regola del profilo: uguali se, tolti gli spazi attorno, coincidono senza distinguere le maiuscole. Due vuoti NON sono uguali.
    Public Shared Function EmailMatches(ByVal lockedEmail As String, ByVal expectedEmail As String) As Boolean
        Dim locked As String = If(lockedEmail, String.Empty).Trim()
        Dim expected As String = If(expectedEmail, String.Empty).Trim()
        If locked.Length = 0 OrElse expected.Length = 0 Then Return False
        Return String.Equals(locked, expected, StringComparison.OrdinalIgnoreCase)
    End Function

    Private Shared Function IsTokenHash(ByVal value As String) As Boolean
        If value Is Nothing OrElse value.Length <> TokenHashLength Then Return False
        For Each ch As Char In value
            If Not ((ch >= "0"c AndAlso ch <= "9"c) OrElse (ch >= "a"c AndAlso ch <= "f"c)) Then Return False
        Next
        Return True
    End Function

    Private Shared Function OptionalHash(ByVal value As Object) As Object
        If value Is Nothing OrElse value Is DBNull.Value Then Return DBNull.Value
        Dim text As String = Convert.ToString(value, CultureInfo.InvariantCulture)
        Return If(String.IsNullOrWhiteSpace(text), CType(DBNull.Value, Object), text)
    End Function

    Private Shared Sub RestoreLockWait(ByVal conn As MySqlConnection, ByVal previousWait As Integer)
        If previousWait <= 0 Then Return
        Try
            Using restore As New MySqlCommand("SET SESSION innodb_lock_wait_timeout = " & previousWait.ToString(CultureInfo.InvariantCulture), conn)
                restore.ExecuteNonQuery()
            End Using
        Catch
            ' La connessione puo essere gia inutilizzabile: l'errore principale, se c'e, e quello che conta.
        End Try
    End Sub

    ' True = il codice e stato inserito (e i pendenti dell'accesso annullati). False = nessuna scrittura: l'accesso non esiste, non e abilitato
    ' o non ha piu quell'e-mail. La transazione e aperta e chiusa qui: conn deve essere aperta e senza transazioni in corso.
    Public Shared Function TryIssue(ByVal conn As MySqlConnection, ByVal loginId As Integer, ByVal expectedEmail As String, ByVal tokenHash As String,
                                    ByVal ipHash As Object, ByVal userAgentHash As Object) As Boolean
        If conn Is Nothing OrElse conn.State <> ConnectionState.Open Then Throw New ArgumentException("Open connection required.")
        If Not IsTokenHash(tokenHash) Then Throw New ArgumentException("Invalid token hash.")
        If loginId <= 0 OrElse If(expectedEmail, String.Empty).Trim().Length = 0 Then Return False

        Dim previousWait As Integer = 0
        Using readWait As New MySqlCommand("SELECT @@SESSION.innodb_lock_wait_timeout", conn)
            previousWait = Convert.ToInt32(readWait.ExecuteScalar(), CultureInfo.InvariantCulture)
        End Using
        Using setWait As New MySqlCommand("SET SESSION innodb_lock_wait_timeout = " & LockWaitSeconds.ToString(CultureInfo.InvariantCulture), conn)
            setWait.ExecuteNonQuery()
        End Using

        Try
            Using tx As MySqlTransaction = conn.BeginTransaction()
                Dim found As Boolean = False
                Dim enabled As Boolean = False
                Dim lockedEmail As String = String.Empty
                Using lockLogin As New MySqlCommand("SELECT Email, Abilitato FROM login WHERE id = @loginId FOR UPDATE", conn, tx)
                    lockLogin.Parameters.Add("@loginId", MySqlDbType.Int32).Value = loginId
                    Using reader As MySqlDataReader = lockLogin.ExecuteReader()
                        If reader.Read() Then
                            found = True
                            lockedEmail = If(reader.IsDBNull(0), String.Empty, Convert.ToString(reader.GetValue(0), CultureInfo.InvariantCulture))
                            enabled = Not reader.IsDBNull(1) AndAlso Convert.ToInt32(reader.GetValue(1), CultureInfo.InvariantCulture) = 1
                        End If
                    End Using
                End Using
                If Not found OrElse Not enabled OrElse Not EmailMatches(lockedEmail, expectedEmail) Then
                    tx.Rollback()
                    Return False
                End If

                Using revoke As New MySqlCommand("UPDATE login_password_reset_tokens SET RevokedAt = NOW() WHERE LoginId = @loginId AND UsedAt IS NULL AND RevokedAt IS NULL", conn, tx)
                    revoke.Parameters.Add("@loginId", MySqlDbType.Int32).Value = loginId
                    revoke.ExecuteNonQuery()
                End Using
                Using insert As New MySqlCommand("INSERT INTO login_password_reset_tokens " &
                                                 "(LoginId, TokenHash, CreatedAt, ExpiresAt, UsedAt, RevokedAt, RequestIpHash, UserAgentHash, CreatedBy) " &
                                                 "VALUES (@loginId, @tokenHash, NOW(), DATE_ADD(NOW(), INTERVAL 30 MINUTE), NULL, NULL, @ipHash, @userAgentHash, 'web_remind')", conn, tx)
                    insert.Parameters.Add("@loginId", MySqlDbType.Int32).Value = loginId
                    insert.Parameters.Add("@tokenHash", MySqlDbType.VarChar, TokenHashLength).Value = tokenHash
                    insert.Parameters.Add("@ipHash", MySqlDbType.VarChar, TokenHashLength).Value = OptionalHash(ipHash)
                    insert.Parameters.Add("@userAgentHash", MySqlDbType.VarChar, TokenHashLength).Value = OptionalHash(userAgentHash)
                    insert.ExecuteNonQuery()
                End Using
                tx.Commit()
                Return True
            End Using
        Finally
            RestoreLockWait(conn, previousWait)
        End Try
    End Function
End Class
