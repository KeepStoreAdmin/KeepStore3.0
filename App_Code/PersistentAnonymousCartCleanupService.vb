Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Text.RegularExpressions
Imports MySql.Data.MySqlClient

Public NotInheritable Class PersistentCartCleanupResult
    Public Property ActiveExpiredProcessed As Integer
    Public Property ActiveCartRowsDeleted As Integer
    Public Property ConsumedDeleted As Integer
    Public Property RevokedDeleted As Integer
    Public Property Anomalies As Integer
    Public Property Errors As Integer
    Public Property CandidatesExamined As Integer
End Class

Friend Enum PersistentCartCleanupKind
    Skipped
    Active
    Consumed
    Revoked
    Anomaly
End Enum

Friend NotInheritable Class PersistentCartCleanupOutcome
    Friend Property Kind As PersistentCartCleanupKind
    Friend Property DeletedRows As Integer
End Class

' Explicit maintenance only: never called by a storefront request or scheduler.
Public NotInheritable Class PersistentAnonymousCartCleanupService
    Public Const DefaultBatchSize As Integer = 100
    Public Const MaximumBatchSize As Integer = 1000

    Private NotInheritable Class Candidate
        Friend Id As Long
        Friend Owner As String
    End Class

    Private Sub New()
    End Sub

    Public Shared Function RunBatch(ByVal connectionString As String, ByVal companyId As Integer,
                                    Optional ByVal batchSize As Integer = DefaultBatchSize) As PersistentCartCleanupResult
        If String.IsNullOrWhiteSpace(connectionString) OrElse companyId <= 0 OrElse
           batchSize < 1 OrElse batchSize > MaximumBatchSize Then
            Throw New ArgumentException("CLEANUP_INPUT_INVALID")
        End If
        Dim result As New PersistentCartCleanupResult()
        Dim candidates As New List(Of Candidate)()
        Dim ambiguous As New HashSet(Of String)(StringComparer.Ordinal)
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                ' Atomic rollback requires both tables to be transactional.
                Using command As New MySqlCommand(
                    "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=DATABASE() " &
                    "AND TABLE_NAME IN ('carrello','carrello_anonimo_persistenza') AND ENGINE='InnoDB'", connection)
                    If Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture) <> 2 Then
                        Throw New InvalidOperationException("CLEANUP_TRANSACTIONAL_SCHEMA_REQUIRED")
                    End If
                End Using
                Using command As New MySqlCommand(
                    "SELECT Id,OwnerToken FROM carrello_anonimo_persistenza WHERE AziendeId=@company " &
                    "AND Status IN ('ACTIVE','CONSUMED','REVOKED') AND ExpiresUtc<=UTC_TIMESTAMP(6) " &
                    "ORDER BY ExpiresUtc,Id LIMIT @limit", connection)
                    command.Parameters.Add("@company", MySqlDbType.Int32).Value = companyId
                    command.Parameters.Add("@limit", MySqlDbType.Int32).Value = batchSize
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        While reader.Read()
                            candidates.Add(New Candidate With {.Id = reader.GetInt64(0), .Owner = reader.GetString(1)})
                        End While
                    End Using
                End Using
                ' Tokens already bind database + company cryptographically. Detect corrupt
                ' cross-company reuse with ONE non-locking batch read, not an owner scan
                ' under every registry lock. No other company's rows are ever modified.
                If candidates.Count > 0 Then
                    Dim parameters As New List(Of String)()
                    Using command As New MySqlCommand()
                        command.Connection = connection
                        For index As Integer = 0 To candidates.Count - 1
                            Dim name As String = "@token" & index.ToString(CultureInfo.InvariantCulture)
                            parameters.Add(name)
                            command.Parameters.Add(name, MySqlDbType.VarChar, 50).Value = candidates(index).Owner
                        Next
                        command.CommandText = "SELECT OwnerToken FROM carrello_anonimo_persistenza WHERE OwnerToken IN (" &
                            String.Join(",", parameters.ToArray()) & ") GROUP BY OwnerToken HAVING COUNT(*)<>1"
                        Using reader As MySqlDataReader = command.ExecuteReader()
                            While reader.Read()
                                ambiguous.Add(reader.GetString(0))
                            End While
                        End Using
                    End Using
                End If
            End Using
        Catch
            result.Errors = 1
            KeepStoreLog.Info("persistent-cart-cleanup", "CLEANUP_PREFLIGHT_FAILED", Nothing)
            Return result
        End Try

        For Each item As Candidate In candidates
            result.CandidatesExamined += 1
            Dim execution As CartTransactionExecutionResult(Of PersistentCartCleanupOutcome) =
                CartTransactionRetryPolicy.Execute(Of PersistentCartCleanupOutcome)(
                    connectionString, IsolationLevel.ReadCommitted, "persistent-cart-cleanup", Guid.NewGuid().ToString("D"),
                    Function(connection As MySqlConnection, transaction As MySqlTransaction)
                        Return CleanOwnerAttempt(connection, transaction, companyId, item.Id, item.Owner, ambiguous.Contains(item.Owner))
                    End Function)
            If execution.Succeeded AndAlso execution.Value IsNot Nothing Then
                Select Case execution.Value.Kind
                    Case PersistentCartCleanupKind.Active
                        result.ActiveExpiredProcessed += 1
                        result.ActiveCartRowsDeleted += execution.Value.DeletedRows
                    Case PersistentCartCleanupKind.Consumed
                        result.ConsumedDeleted += 1
                    Case PersistentCartCleanupKind.Revoked
                        result.RevokedDeleted += 1
                End Select
            ElseIf execution.Value IsNot Nothing AndAlso execution.Value.Kind = PersistentCartCleanupKind.Anomaly AndAlso
                   execution.RollbackStatus = CartTransactionRollbackStatus.Succeeded Then
                result.Anomalies += 1
                KeepStoreLog.Info("persistent-cart-cleanup", "CLEANUP_OWNER_ANOMALY_PRESERVED", Nothing)
            Else
                ' Includes ambiguous commits: do not report deletion as confirmed or retry it blindly.
                result.Errors += 1
                KeepStoreLog.Info("persistent-cart-cleanup", "CLEANUP_OWNER_FAILED_OR_INDETERMINATE", Nothing)
            End If
        Next
        Return result
    End Function

    Friend Shared Function CleanOwnerAttempt(ByVal connection As MySqlConnection, ByVal transaction As MySqlTransaction,
                                            ByVal companyId As Integer, ByVal registryId As Long, ByVal owner As String,
                                            ByVal ambiguous As Boolean) As CartTransactionWorkResult(Of PersistentCartCleanupOutcome)
        If companyId <= 0 OrElse registryId <= 0 OrElse owner Is Nothing OrElse owner.Length <> 48 OrElse
           Not Regex.IsMatch(owner, "\Aksc2_[A-Za-z0-9_-]{43}\z", RegexOptions.CultureInvariant) Then
            Return Anomaly()
        End If
        Dim status As String = Nothing, expiry As DateTime
        Dim hasConsumed As Boolean, hasRevoked As Boolean
        Using command As New MySqlCommand(
            "SELECT Status,ExpiresUtc,ConsumedUtc,RevokedUtc FROM carrello_anonimo_persistenza " &
            "WHERE AziendeId=@company AND OwnerToken=@owner AND Id=@id FOR UPDATE", connection, transaction)
            AddOwner(command, companyId, registryId, owner)
            Using reader As MySqlDataReader = command.ExecuteReader()
                If Not reader.Read() Then Return Skipped()
                status = reader.GetString(0)
                expiry = DateTime.SpecifyKind(reader.GetDateTime(1), DateTimeKind.Utc)
                hasConsumed = Not reader.IsDBNull(2) : hasRevoked = Not reader.IsDBNull(3)
                If reader.Read() Then Return Anomaly()
            End Using
        End Using
        Dim dbNow As DateTime
        Using command As New MySqlCommand("SELECT UTC_TIMESTAMP(6)", connection, transaction)
            dbNow = DateTime.SpecifyKind(Convert.ToDateTime(command.ExecuteScalar(), CultureInfo.InvariantCulture), DateTimeKind.Utc)
        End Using
        ' Recheck after waiting for the lock: a candidate can have been refreshed or consumed.
        If expiry > dbNow Then Return Skipped()
        If ambiguous OrElse
           Not ((status = "ACTIVE" AndAlso Not hasConsumed AndAlso Not hasRevoked) OrElse
                (status = "CONSUMED" AndAlso hasConsumed AndAlso Not hasRevoked) OrElse
                (status = "REVOKED" AndAlso Not hasConsumed AndAlso hasRevoked)) Then Return Anomaly()

        Dim rowCount As Integer = 0
        ' Same lock order as lifecycle/login: registry first, then anonymous rows by ID.
        ' Valid runtime writers also acquire the registry lock; no valid writer can add
        ' rows to an expired/terminal owner while maintenance holds this lock.
        Using command As New MySqlCommand(
            "SELECT id FROM carrello WHERE COALESCE(LoginId,0)<=0 AND BINARY SessionId=@owner ORDER BY id FOR UPDATE",
            connection, transaction)
            command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = owner
            Using reader As MySqlDataReader = command.ExecuteReader()
                While reader.Read()
                    rowCount += 1
                End While
            End Using
        End Using
        If status <> "ACTIVE" AndAlso rowCount > 0 Then Return Anomaly()
        Dim outcome As New PersistentCartCleanupOutcome()
        If status = "ACTIVE" Then
            Using command As New MySqlCommand(
                "DELETE FROM carrello WHERE COALESCE(LoginId,0)<=0 AND BINARY SessionId=@owner", connection, transaction)
                command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = owner
                outcome.DeletedRows = command.ExecuteNonQuery()
                If outcome.DeletedRows <> rowCount Then Throw New InvalidOperationException("CLEANUP_ROW_COUNT_CHANGED")
            End Using
            outcome.Kind = PersistentCartCleanupKind.Active
        Else
            outcome.Kind = If(status = "CONSUMED", PersistentCartCleanupKind.Consumed, PersistentCartCleanupKind.Revoked)
        End If
        Using command As New MySqlCommand(
            "DELETE FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND OwnerToken=@owner AND Id=@id " &
            "AND Status=@status AND ExpiresUtc<=@now", connection, transaction)
            AddOwner(command, companyId, registryId, owner)
            command.Parameters.Add("@status", MySqlDbType.VarChar, 8).Value = status
            command.Parameters.Add("@now", MySqlDbType.DateTime).Value = dbNow
            If command.ExecuteNonQuery() <> 1 Then Throw New InvalidOperationException("CLEANUP_REGISTRY_DELETE_FAILED")
        End Using
        Return CartTransactionWorkResult(Of PersistentCartCleanupOutcome).Commit(outcome)
    End Function

    Private Shared Function Skipped() As CartTransactionWorkResult(Of PersistentCartCleanupOutcome)
        Return CartTransactionWorkResult(Of PersistentCartCleanupOutcome).Commit(New PersistentCartCleanupOutcome())
    End Function

    Private Shared Function Anomaly() As CartTransactionWorkResult(Of PersistentCartCleanupOutcome)
        Return CartTransactionWorkResult(Of PersistentCartCleanupOutcome).Abort(
            New PersistentCartCleanupOutcome With {.Kind = PersistentCartCleanupKind.Anomaly})
    End Function

    Private Shared Sub AddOwner(ByVal command As MySqlCommand, ByVal companyId As Integer, ByVal registryId As Long, ByVal owner As String)
        command.Parameters.Add("@company", MySqlDbType.Int32).Value = companyId
        command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = owner
        command.Parameters.Add("@id", MySqlDbType.Int64).Value = registryId
    End Sub
End Class
