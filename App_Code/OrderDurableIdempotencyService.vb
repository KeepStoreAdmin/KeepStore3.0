Imports System
Imports System.Collections.Generic
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
    Public Property AziendaId As Integer
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

    Public Shared Function TryNormalizePayloadFingerprint(ByVal value As String,
                                                          ByRef normalized As String) As Boolean
        normalized = Convert.ToString(value).Trim().ToLowerInvariant()
        If Not IsFingerprintValid(normalized) Then
            normalized = String.Empty
            Return False
        End If
        Return True
    End Function

    Public Shared Function ComputeCartFingerprint(ByVal connection As MySqlConnection,
                                                  ByVal transaction As MySqlTransaction,
                                                  ByVal loginId As Long,
                                                  ByVal lockForUpdate As Boolean) As String
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        If loginId <= 0 Then Throw New ArgumentOutOfRangeException("loginId")
        If lockForUpdate AndAlso transaction Is Nothing Then Throw New ArgumentNullException("transaction")

        Dim values As New List(Of Object)()
        Dim sql As String =
            "SELECT ArticoliId, COALESCE(TCId,-1) AS TCId, COALESCE(Codice,'') AS Codice, " &
            "COALESCE(Descrizione1,'') AS Descrizione1, COALESCE(Qnt,0) AS Qnt, " &
            "COALESCE(NListino,0) AS NListino, COALESCE(Prezzo,0) AS Prezzo, " &
            "COALESCE(PrezzoIvato,0) AS PrezzoIvato, COALESCE(OfferteDettaglioId,0) AS OfferteDettaglioId, " &
            "COALESCE(Prodotto_Gratis,0) AS Prodotto_Gratis, COALESCE(IdIvaRC,-1) AS IdIvaRC, " &
            "COALESCE(ValoreIvaRC,0) AS ValoreIvaRC, COALESCE(IdEsenzioneIva,-1) AS IdEsenzioneIva, " &
            "COALESCE(ValoreEsenzioneIva,0) AS ValoreEsenzioneIva " &
            "FROM carrello WHERE LoginId=?loginId " &
            "ORDER BY ArticoliId, COALESCE(TCId,-1), ID"
        If lockForUpdate Then sql &= " FOR UPDATE"

        Using command As New MySqlCommand(sql, connection, transaction)
            command.Parameters.Add("?loginId", MySqlDbType.Int64).Value = loginId
            Using reader As MySqlDataReader = command.ExecuteReader()
                Dim rowCount As Integer = 0
                While reader.Read()
                    rowCount += 1
                    For index As Integer = 0 To reader.FieldCount - 1
                        values.Add(If(reader.IsDBNull(index), Nothing, reader.GetValue(index)))
                    Next
                End While
                values.Insert(0, rowCount)
            End Using
        End Using

        Return ComputePayloadFingerprint(values.ToArray())
    End Function

    Public Shared Function TryReadCompleted(ByVal connection As MySqlConnection,
                                            ByVal requestId As String,
                                            ByVal loginId As Long,
                                            ByVal aziendaId As Integer) As OrderDurableIdempotencyRecord
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        Dim normalized As String = String.Empty
        If loginId <= 0 OrElse aziendaId <= 0 OrElse Not TryNormalizeRequestId(requestId, normalized) Then
            Return RejectedRecord()
        End If

        Dim record As OrderDurableIdempotencyRecord = LoadRecord(connection, Nothing, normalized, False)
        If record Is Nothing Then Return Nothing
        If record.LoginId <> loginId OrElse record.AziendaId <> aziendaId OrElse
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
                                    ByVal aziendaId As Integer,
                                    ByVal tipoDocumentiId As Integer,
                                    ByVal payloadFingerprint As String) As OrderDurableIdempotencyRecord
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        If transaction Is Nothing Then Throw New ArgumentNullException("transaction")

        Dim normalized As String = String.Empty
        If loginId <= 0 OrElse aziendaId <= 0 OrElse tipoDocumentiId <= 0 OrElse
           Not TryNormalizeRequestId(requestId, normalized) OrElse
           Not IsFingerprintValid(payloadFingerprint) Then
            Return RejectedRecord()
        End If
        If Not IsLoginOwnedByCompany(connection, transaction, loginId, aziendaId) Then Return RejectedRecord()

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
                .AziendaId = aziendaId,
                .TipoDocumentiId = tipoDocumentiId,
                .PayloadFingerprint = payloadFingerprint
            }
        Catch ex As MySqlException
            If ex.Number <> 1062 Then Throw
        End Try

        Dim existing As OrderDurableIdempotencyRecord = LoadRecord(connection, transaction, normalized, True)
        If existing Is Nothing OrElse
           existing.LoginId <> loginId OrElse existing.AziendaId <> aziendaId OrElse
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
                               ByVal aziendaId As Integer,
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
            "AND PayloadFingerprint=?payloadFingerprint AND Stato=?pendingState " &
            "AND EXISTS (SELECT 1 FROM documenti d INNER JOIN vlogin v " &
            "ON v.id=?loginId AND v.utentiid=d.UtentiId AND v.AziendeID=?aziendaId " &
            "WHERE d.id=?documentiId AND d.AziendeId=?aziendaId)",
            connection, transaction)
            command.Parameters.Add("?documentoMemorizzato", MySqlDbType.Int64).Value = documentoMemorizzato
            command.Parameters.Add("?documentiId", MySqlDbType.Int64).Value = documentiId
            command.Parameters.Add("?completedState", MySqlDbType.VarChar, 16).Value = CompletedState
            command.Parameters.Add("?requestId", MySqlDbType.VarChar, 32).Value = requestId
            command.Parameters.Add("?loginId", MySqlDbType.Int64).Value = loginId
            command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = aziendaId
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
                                        ByVal aziendaId As Integer,
                                        ByVal tipoDocumentiId As Integer,
                                        ByVal payloadFingerprint As String)
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        If transaction Is Nothing Then Throw New ArgumentNullException("transaction")

        Using command As New MySqlCommand(
            "UPDATE ordini_web_idempotenza SET Stato=?retryState, " &
            "DataCompletamento=CURRENT_TIMESTAMP(6) " &
            "WHERE RequestId=?requestId AND LoginId=?loginId AND TipoDocumentiId=?tipoDocumentiId " &
            "AND PayloadFingerprint=?payloadFingerprint AND Stato=?pendingState " &
            "AND DocumentoMemorizzato IS NULL AND DocumentiId IS NULL " &
            "AND EXISTS (SELECT 1 FROM vlogin v WHERE v.id=?loginId AND v.AziendeID=?aziendaId)",
            connection, transaction)
            command.Parameters.Add("?retryState", MySqlDbType.VarChar, 16).Value = RetryRequiredState
            command.Parameters.Add("?requestId", MySqlDbType.VarChar, 32).Value = requestId
            command.Parameters.Add("?loginId", MySqlDbType.Int64).Value = loginId
            command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = aziendaId
            command.Parameters.Add("?tipoDocumentiId", MySqlDbType.Int32).Value = tipoDocumentiId
            command.Parameters.Add("?payloadFingerprint", MySqlDbType.VarChar, 64).Value = payloadFingerprint
            command.Parameters.Add("?pendingState", MySqlDbType.VarChar, 16).Value = PendingState
            If command.ExecuteNonQuery() <> 1 Then Throw New DataException("Durable checkout retry state was not persisted.")
        End Using
    End Sub

    ''' <summary>
    ''' Persists a terminal retry marker after the checkout transaction has
    ''' rolled back. A completed request is never downgraded and an owner or
    ''' payload collision remains fail-closed.
    ''' </summary>
    Public Shared Function RecordRetryRequired(ByVal connection As MySqlConnection,
                                               ByVal requestId As String,
                                               ByVal loginId As Long,
                                               ByVal aziendaId As Integer,
                                               ByVal tipoDocumentiId As Integer,
                                               ByVal payloadFingerprint As String) As Boolean
        If connection Is Nothing OrElse connection.State <> ConnectionState.Open Then Return False

        Dim normalized As String = String.Empty
        If loginId <= 0 OrElse aziendaId <= 0 OrElse tipoDocumentiId <= 0 OrElse
           Not TryNormalizeRequestId(requestId, normalized) OrElse
           Not IsFingerprintValid(payloadFingerprint) Then Return False

        Dim recoveryTransaction As MySqlTransaction = Nothing
        Try
            recoveryTransaction = connection.BeginTransaction(IsolationLevel.ReadCommitted)
            If Not IsLoginOwnedByCompany(connection, recoveryTransaction, loginId, aziendaId) Then
                recoveryTransaction.Rollback()
                Return False
            End If

            Dim existing As OrderDurableIdempotencyRecord =
                LoadRecord(connection, recoveryTransaction, normalized, True)
            If existing Is Nothing Then
                Using insertCommand As New MySqlCommand(
                    "INSERT INTO ordini_web_idempotenza " &
                    "(RequestId, LoginId, TipoDocumentiId, PayloadFingerprint, Stato, DataCreazione, DataCompletamento) " &
                    "VALUES (?requestId, ?loginId, ?tipoDocumentiId, ?payloadFingerprint, ?retryState, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6))",
                    connection, recoveryTransaction)
                    insertCommand.Parameters.Add("?requestId", MySqlDbType.VarChar, 32).Value = normalized
                    insertCommand.Parameters.Add("?loginId", MySqlDbType.Int64).Value = loginId
                    insertCommand.Parameters.Add("?tipoDocumentiId", MySqlDbType.Int32).Value = tipoDocumentiId
                    insertCommand.Parameters.Add("?payloadFingerprint", MySqlDbType.VarChar, 64).Value = payloadFingerprint
                    insertCommand.Parameters.Add("?retryState", MySqlDbType.VarChar, 16).Value = RetryRequiredState
                    If insertCommand.ExecuteNonQuery() <> 1 Then
                        recoveryTransaction.Rollback()
                        Return False
                    End If
                End Using
            Else
                If existing.LoginId <> loginId OrElse existing.AziendaId <> aziendaId OrElse
                   existing.TipoDocumentiId <> tipoDocumentiId OrElse
                   Not String.Equals(existing.PayloadFingerprint, payloadFingerprint, StringComparison.Ordinal) OrElse
                   existing.Status = OrderDurableClaimStatus.CompletedReplay Then
                    recoveryTransaction.Rollback()
                    Return False
                End If

                If existing.Status <> OrderDurableClaimStatus.RetryRequired Then
                    MarkRetryRequired(
                        connection, recoveryTransaction, normalized, loginId, aziendaId,
                        tipoDocumentiId, payloadFingerprint)
                End If
            End If

            recoveryTransaction.Commit()
            Return True
        Catch
            If recoveryTransaction IsNot Nothing Then
                Try
                    recoveryTransaction.Rollback()
                Catch
                End Try
            End If
            Return False
        Finally
            If recoveryTransaction IsNot Nothing Then recoveryTransaction.Dispose()
        End Try
    End Function

    Private Shared Function LoadRecord(ByVal connection As MySqlConnection,
                                       ByVal transaction As MySqlTransaction,
                                       ByVal requestId As String,
                                       ByVal lockForUpdate As Boolean) As OrderDurableIdempotencyRecord
        Dim sql As String =
            "SELECT i.RequestId, i.LoginId, i.TipoDocumentiId, i.PayloadFingerprint, i.Stato, " &
            "i.DocumentoMemorizzato, i.DocumentiId, " &
            "COALESCE(d.AziendeId, v.AziendeID, 0) AS AziendaId " &
            "FROM ordini_web_idempotenza i " &
            "LEFT JOIN documenti d ON d.id=i.DocumentiId " &
            "LEFT JOIN vlogin v ON v.id=i.LoginId " &
            "WHERE i.RequestId=?requestId LIMIT 1"
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
                    .AziendaId = Convert.ToInt32(reader("AziendaId"), CultureInfo.InvariantCulture),
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

    Private Shared Function IsLoginOwnedByCompany(ByVal connection As MySqlConnection,
                                                  ByVal transaction As MySqlTransaction,
                                                  ByVal loginId As Long,
                                                  ByVal aziendaId As Integer) As Boolean
        Using command As New MySqlCommand(
            "SELECT utentiid, COALESCE(listino,0) AS listino " &
            "FROM vlogin WHERE id=?loginId AND AziendeID=?aziendaId",
            connection, transaction)
            command.Parameters.Add("?loginId", MySqlDbType.Int64).Value = loginId
            command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = aziendaId
            Dim rows As New List(Of OrderLogicalIdentityRow)()
            Using reader As MySqlDataReader = command.ExecuteReader()
                While reader.Read()
                    rows.Add(New OrderLogicalIdentityRow() With {
                        .UserId = Convert.ToInt64(reader("utentiid"), CultureInfo.InvariantCulture),
                        .PriceListId = Convert.ToInt32(reader("listino"), CultureInfo.InvariantCulture)
                    })
                End While
            End Using

            Dim resolvedUserId As Long = 0
            Dim resolvedPriceListId As Integer = 0
            Return OrderLogicalIdentityResolver.TryResolve(rows, resolvedUserId, resolvedPriceListId)
        End Using
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
