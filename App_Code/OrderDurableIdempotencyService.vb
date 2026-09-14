Imports System
Imports System.Data
Imports System.Globalization
Imports System.Security.Cryptography
Imports System.Text
Imports MySql.Data.MySqlClient

Public Enum OrderDurableClaimStatus
    NewClaim = 0
    CompletedReplay = 1
    RetryRequired = 2
    Rejected = 3
End Enum

Public NotInheritable Class OrderDurableIdempotencyRecord
    Public Property Status As OrderDurableClaimStatus
    Public Property RequestId As String
    Public Property LoginId As Long
    Public Property TipoDocumentiId As Integer
    Public Property PayloadFingerprint As String
    Public Property DocumentoMemorizzato As Long
    Public Property DocumentiId As Long
End Class

Public NotInheritable Class OrderDurableIdempotencyService
    Public Const TableName As String = "ordini_web_idempotenza"
    Public Const PendingState As String = "PENDING"
    Public Const CompletedState As String = "COMPLETED"
    Public Const RetryRequiredState As String = "RETRY_REQUIRED"
    Public Const TechnicalErrorMessage As String = "Non è stato possibile confermare l'ordine. Il carrello è rimasto invariato. Riprova tra qualche istante."

    Private Sub New()
    End Sub

    Public Shared Function CreateRequestId() As String
        Return Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture)
    End Function

    Public Shared Function TryNormalizeRequestId(ByVal value As String, ByRef normalized As String) As Boolean
        normalized = String.Empty
        If String.IsNullOrWhiteSpace(value) OrElse value.Length <> 32 Then Return False

        Dim parsed As Guid
        If Not Guid.TryParseExact(value, "N", parsed) Then Return False
        normalized = parsed.ToString("N", CultureInfo.InvariantCulture)
        Return String.Equals(value, normalized, StringComparison.OrdinalIgnoreCase)
    End Function

    Public Shared Function ComputePayloadFingerprint(ParamArray ByVal values() As Object) As String
        Dim canonical As New StringBuilder()
        If values IsNot Nothing Then
            For Each value As Object In values
                Dim current As String = NormalizeFingerprintValue(value)
                canonical.Append(current.Length.ToString(CultureInfo.InvariantCulture))
                canonical.Append(":"c)
                canonical.Append(current)
                canonical.Append("|"c)
            Next
        End If

        Using hasher As SHA256 = SHA256.Create()
            Dim digest() As Byte = hasher.ComputeHash(Encoding.UTF8.GetBytes(canonical.ToString()))
            Dim result As New StringBuilder(digest.Length * 2)
            For Each current As Byte In digest
                result.Append(current.ToString("x2", CultureInfo.InvariantCulture))
            Next
            Return result.ToString()
        End Using
    End Function

    Public Shared Function TryReadCompleted(ByVal connection As MySqlConnection,
                                            ByVal requestId As String,
                                            ByVal loginId As Long) As OrderDurableIdempotencyRecord
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        Dim normalized As String = String.Empty
        If loginId <= 0 OrElse Not TryNormalizeRequestId(requestId, normalized) Then
            Return RejectedRecord()
        End If

        Dim record As OrderDurableIdempotencyRecord = LoadRecord(connection, Nothing, normalized, False)
        If record Is Nothing Then Return Nothing
        If record.LoginId <> loginId OrElse
           (record.Status <> OrderDurableClaimStatus.CompletedReplay AndAlso
            record.Status <> OrderDurableClaimStatus.RetryRequired) Then
            Return RejectedRecord()
        End If
        Return record
    End Function

    Public Shared Function TryClaim(ByVal connection As MySqlConnection,
                                    ByVal transaction As MySqlTransaction,
                                    ByVal requestId As String,
                                    ByVal loginId As Long,
                                    ByVal tipoDocumentiId As Integer,
                                    ByVal payloadFingerprint As String) As OrderDurableIdempotencyRecord
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        If transaction Is Nothing Then Throw New ArgumentNullException("transaction")

        Dim normalized As String = String.Empty
        If loginId <= 0 OrElse tipoDocumentiId <= 0 OrElse
           Not TryNormalizeRequestId(requestId, normalized) OrElse
           Not IsFingerprintValid(payloadFingerprint) Then
            Return RejectedRecord()
        End If

        Try
            Using command As New MySqlCommand(
                "INSERT INTO ordini_web_idempotenza " &
                "(RequestId, LoginId, TipoDocumentiId, PayloadFingerprint, Stato, DataCreazione) " &
                "VALUES (?requestId, ?loginId, ?tipoDocumentiId, ?payloadFingerprint, ?stato, CURRENT_TIMESTAMP(6))",
                connection, transaction)
                command.Parameters.Add("?requestId", MySqlDbType.VarChar, 32).Value = normalized
                command.Parameters.Add("?loginId", MySqlDbType.Int64).Value = loginId
                command.Parameters.Add("?tipoDocumentiId", MySqlDbType.Int32).Value = tipoDocumentiId
                command.Parameters.Add("?payloadFingerprint", MySqlDbType.VarChar, 64).Value = payloadFingerprint
                command.Parameters.Add("?stato", MySqlDbType.VarChar, 16).Value = PendingState
                If command.ExecuteNonQuery() <> 1 Then Throw New DataException("Durable checkout claim was not inserted.")
            End Using

            Return New OrderDurableIdempotencyRecord() With {
                .Status = OrderDurableClaimStatus.NewClaim,
                .RequestId = normalized,
                .LoginId = loginId,
                .TipoDocumentiId = tipoDocumentiId,
                .PayloadFingerprint = payloadFingerprint
            }
        Catch ex As MySqlException
            If ex.Number <> 1062 Then Throw
        End Try

        Dim existing As OrderDurableIdempotencyRecord = LoadRecord(connection, transaction, normalized, True)
        If existing Is Nothing OrElse
           existing.LoginId <> loginId OrElse
           existing.TipoDocumentiId <> tipoDocumentiId OrElse
           Not String.Equals(existing.PayloadFingerprint, payloadFingerprint, StringComparison.Ordinal) OrElse
           (existing.Status <> OrderDurableClaimStatus.CompletedReplay AndAlso
            existing.Status <> OrderDurableClaimStatus.RetryRequired) Then
            Return RejectedRecord()
        End If
        Return existing
    End Function

    Public Shared Sub Complete(ByVal connection As MySqlConnection,
                               ByVal transaction As MySqlTransaction,
                               ByVal requestId As String,
                               ByVal loginId As Long,
                               ByVal tipoDocumentiId As Integer,
                               ByVal payloadFingerprint As String,
                               ByVal documentoMemorizzato As Long,
                               ByVal documentiId As Long)
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        If transaction Is Nothing Then Throw New ArgumentNullException("transaction")
        If documentoMemorizzato <= 0 OrElse documentiId <= 0 Then Throw New ArgumentOutOfRangeException("documentiId")

        Using command As New MySqlCommand(
            "UPDATE ordini_web_idempotenza SET " &
            "DocumentoMemorizzato=?documentoMemorizzato, DocumentiId=?documentiId, " &
            "Stato=?completedState, DataCompletamento=CURRENT_TIMESTAMP(6) " &
            "WHERE RequestId=?requestId AND LoginId=?loginId AND TipoDocumentiId=?tipoDocumentiId " &
            "AND PayloadFingerprint=?payloadFingerprint AND Stato=?pendingState",
            connection, transaction)
            command.Parameters.Add("?documentoMemorizzato", MySqlDbType.Int64).Value = documentoMemorizzato
            command.Parameters.Add("?documentiId", MySqlDbType.Int64).Value = documentiId
            command.Parameters.Add("?completedState", MySqlDbType.VarChar, 16).Value = CompletedState
            command.Parameters.Add("?requestId", MySqlDbType.VarChar, 32).Value = requestId
            command.Parameters.Add("?loginId", MySqlDbType.Int64).Value = loginId
            command.Parameters.Add("?tipoDocumentiId", MySqlDbType.Int32).Value = tipoDocumentiId
            command.Parameters.Add("?payloadFingerprint", MySqlDbType.VarChar, 64).Value = payloadFingerprint
            command.Parameters.Add("?pendingState", MySqlDbType.VarChar, 16).Value = PendingState
            If command.ExecuteNonQuery() <> 1 Then Throw New DataException("Durable checkout completion was not persisted.")
        End Using
    End Sub

    Public Shared Sub MarkRetryRequired(ByVal connection As MySqlConnection,
                                        ByVal transaction As MySqlTransaction,
                                        ByVal requestId As String,
                                        ByVal loginId As Long,
                                        ByVal tipoDocumentiId As Integer,
                                        ByVal payloadFingerprint As String)
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        If transaction Is Nothing Then Throw New ArgumentNullException("transaction")

        Using command As New MySqlCommand(
            "UPDATE ordini_web_idempotenza SET Stato=?retryState, " &
            "DataCompletamento=CURRENT_TIMESTAMP(6) " &
            "WHERE RequestId=?requestId AND LoginId=?loginId AND TipoDocumentiId=?tipoDocumentiId " &
            "AND PayloadFingerprint=?payloadFingerprint AND Stato=?pendingState " &
            "AND DocumentoMemorizzato IS NULL AND DocumentiId IS NULL",
            connection, transaction)
            command.Parameters.Add("?retryState", MySqlDbType.VarChar, 16).Value = RetryRequiredState
            command.Parameters.Add("?requestId", MySqlDbType.VarChar, 32).Value = requestId
            command.Parameters.Add("?loginId", MySqlDbType.Int64).Value = loginId
            command.Parameters.Add("?tipoDocumentiId", MySqlDbType.Int32).Value = tipoDocumentiId
            command.Parameters.Add("?payloadFingerprint", MySqlDbType.VarChar, 64).Value = payloadFingerprint
            command.Parameters.Add("?pendingState", MySqlDbType.VarChar, 16).Value = PendingState
            If command.ExecuteNonQuery() <> 1 Then Throw New DataException("Durable checkout retry state was not persisted.")
        End Using
    End Sub

    Private Shared Function LoadRecord(ByVal connection As MySqlConnection,
                                       ByVal transaction As MySqlTransaction,
                                       ByVal requestId As String,
                                       ByVal lockForUpdate As Boolean) As OrderDurableIdempotencyRecord
        Dim sql As String =
            "SELECT RequestId, LoginId, TipoDocumentiId, PayloadFingerprint, Stato, " &
            "DocumentoMemorizzato, DocumentiId FROM ordini_web_idempotenza " &
            "WHERE RequestId=?requestId LIMIT 1"
        If lockForUpdate Then sql &= " FOR UPDATE"

        Using command As New MySqlCommand(sql, connection, transaction)
            command.Parameters.Add("?requestId", MySqlDbType.VarChar, 32).Value = requestId
            Using reader As MySqlDataReader = command.ExecuteReader()
                If Not reader.Read() Then Return Nothing

                Dim state As String = Convert.ToString(reader("Stato"), CultureInfo.InvariantCulture)
                Dim status As OrderDurableClaimStatus = OrderDurableClaimStatus.Rejected
                If String.Equals(state, CompletedState, StringComparison.Ordinal) Then
                    status = OrderDurableClaimStatus.CompletedReplay
                ElseIf String.Equals(state, RetryRequiredState, StringComparison.Ordinal) Then
                    status = OrderDurableClaimStatus.RetryRequired
                End If

                Return New OrderDurableIdempotencyRecord() With {
                    .Status = status,
                    .RequestId = Convert.ToString(reader("RequestId"), CultureInfo.InvariantCulture),
                    .LoginId = Convert.ToInt64(reader("LoginId"), CultureInfo.InvariantCulture),
                    .TipoDocumentiId = Convert.ToInt32(reader("TipoDocumentiId"), CultureInfo.InvariantCulture),
                    .PayloadFingerprint = Convert.ToString(reader("PayloadFingerprint"), CultureInfo.InvariantCulture),
                    .DocumentoMemorizzato = If(reader.IsDBNull(reader.GetOrdinal("DocumentoMemorizzato")), 0L, Convert.ToInt64(reader("DocumentoMemorizzato"), CultureInfo.InvariantCulture)),
                    .DocumentiId = If(reader.IsDBNull(reader.GetOrdinal("DocumentiId")), 0L, Convert.ToInt64(reader("DocumentiId"), CultureInfo.InvariantCulture))
                }
            End Using
        End Using
    End Function

    Private Shared Function RejectedRecord() As OrderDurableIdempotencyRecord
        Return New OrderDurableIdempotencyRecord() With {.Status = OrderDurableClaimStatus.Rejected}
    End Function

    Private Shared Function IsFingerprintValid(ByVal value As String) As Boolean
        If String.IsNullOrEmpty(value) OrElse value.Length <> 64 Then Return False
        For Each current As Char In value
            If Not ((current >= "0"c AndAlso current <= "9"c) OrElse (current >= "a"c AndAlso current <= "f"c)) Then Return False
        Next
        Return True
    End Function

    Private Shared Function NormalizeFingerprintValue(ByVal value As Object) As String
        If value Is Nothing OrElse value Is DBNull.Value Then Return "<null>"
        If TypeOf value Is Decimal Then Return DirectCast(value, Decimal).ToString("G29", CultureInfo.InvariantCulture)
        If TypeOf value Is Double Then Return DirectCast(value, Double).ToString("R", CultureInfo.InvariantCulture)
        If TypeOf value Is Single Then Return DirectCast(value, Single).ToString("R", CultureInfo.InvariantCulture)
        If TypeOf value Is DateTime Then Return DirectCast(value, DateTime).ToUniversalTime().Ticks.ToString(CultureInfo.InvariantCulture)
        If TypeOf value Is IFormattable Then Return DirectCast(value, IFormattable).ToString(Nothing, CultureInfo.InvariantCulture)
        Return Convert.ToString(value, CultureInfo.InvariantCulture)
    End Function
End Class
