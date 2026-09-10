Imports System
Imports System.Data
Imports System.Diagnostics
Imports System.Globalization
Imports System.Security.Cryptography
Imports System.Threading
Imports MySql.Data.MySqlClient

Public Enum CartTransactionPhase
    BeforeTransaction = 0
    TransactionActive = 1
    CommitStarted = 2
    CommitSucceeded = 3
End Enum

Public Enum CartTransactionRollbackStatus
    NotRequired = 0
    Succeeded = 1
    Failed = 2
    BestEffortSucceeded = 3
    BestEffortFailed = 4
End Enum

Public Enum CartTransactionExecutionStatus
    Succeeded = 0
    Failed = 1
    Indeterminate = 2
End Enum

Public NotInheritable Class CartTransactionWorkResult(Of TResult)
    Private ReadOnly _shouldCommit As Boolean
    Private ReadOnly _value As TResult

    Private Sub New(ByVal shouldCommit As Boolean, ByVal value As TResult)
        _shouldCommit = shouldCommit
        _value = value
    End Sub

    Public ReadOnly Property ShouldCommit As Boolean
        Get
            Return _shouldCommit
        End Get
    End Property

    Public ReadOnly Property Value As TResult
        Get
            Return _value
        End Get
    End Property

    Public Shared Function Commit(ByVal value As TResult) As CartTransactionWorkResult(Of TResult)
        Return New CartTransactionWorkResult(Of TResult)(True, value)
    End Function

    Public Shared Function Abort(ByVal value As TResult) As CartTransactionWorkResult(Of TResult)
        Return New CartTransactionWorkResult(Of TResult)(False, value)
    End Function
End Class

Public NotInheritable Class CartTransactionExecutionResult(Of TResult)
    Public Property Status As CartTransactionExecutionStatus
    Public Property Value As TResult
    Public Property Attempts As Integer
    Public Property MySqlNumber As Integer
    Public Property Phase As CartTransactionPhase
    Public Property RollbackStatus As CartTransactionRollbackStatus
    Public Property DurationMilliseconds As Long

    Public ReadOnly Property Succeeded As Boolean
        Get
            Return Status = CartTransactionExecutionStatus.Succeeded
        End Get
    End Property

    Public ReadOnly Property IsIndeterminate As Boolean
        Get
            Return Status = CartTransactionExecutionStatus.Indeterminate
        End Get
    End Property
End Class

Public NotInheritable Class CartTransactionRetryPolicy
    Public Const MaximumAttempts As Integer = 3
    Public Const MaximumElapsedMilliseconds As Integer = 20000
    Private Const LockWaitSessionCommand As String = "SET SESSION innodb_lock_wait_timeout = 5"

    <ThreadStatic>
    Private Shared _activeBoundaryDepth As Integer

    Private Sub New()
    End Sub

    Public Shared Function Execute(Of TResult)(
        ByVal connectionString As String,
        ByVal isolationLevel As IsolationLevel,
        ByVal logicalOperation As String,
        ByVal correlationId As String,
        ByVal work As Func(Of MySqlConnection, MySqlTransaction, CartTransactionWorkResult(Of TResult))) As CartTransactionExecutionResult(Of TResult)

        If String.IsNullOrWhiteSpace(connectionString) Then Throw New ArgumentException("A connection string is required.", "connectionString")
        If work Is Nothing Then Throw New ArgumentNullException("work")
        If _activeBoundaryDepth <> 0 Then Throw New InvalidOperationException("Nested cart transaction retry boundaries are not allowed.")

        Dim safeOperation As String = NormalizeLogicalOperation(logicalOperation)
        Dim safeCorrelationId As String = NormalizeCorrelationId(correlationId)
        Dim stopwatch As Stopwatch = Stopwatch.StartNew()
        Dim lastResult As CartTransactionExecutionResult(Of TResult) = Nothing

        _activeBoundaryDepth += 1
        Try
            For attempt As Integer = 1 To MaximumAttempts
                If attempt > 1 AndAlso stopwatch.ElapsedMilliseconds >= MaximumElapsedMilliseconds Then
                    If lastResult Is Nothing Then
                        lastResult = CreateResult(Of TResult)(CartTransactionExecutionStatus.Failed, Nothing, attempt - 1,
                                                              -1, CartTransactionPhase.BeforeTransaction,
                                                              CartTransactionRollbackStatus.NotRequired, stopwatch.ElapsedMilliseconds)
                    End If
                    LogDecision(safeCorrelationId, safeOperation, attempt - 1, lastResult.MySqlNumber,
                                lastResult.Phase, lastResult.RollbackStatus, "budget-exhausted", stopwatch.ElapsedMilliseconds)
                    Return lastResult
                End If

                Dim phase As CartTransactionPhase = CartTransactionPhase.BeforeTransaction
                Dim sessionConfigured As Boolean = False
                Dim conn As MySqlConnection = Nothing
                Dim transaction As MySqlTransaction = Nothing
                Try
                    conn = New MySqlConnection(connectionString)
                    conn.Open()
                    Using sessionCommand As New MySqlCommand(LockWaitSessionCommand, conn)
                        sessionCommand.CommandType = CommandType.Text
                        sessionCommand.ExecuteNonQuery()
                    End Using
                    sessionConfigured = True

                    transaction = conn.BeginTransaction(isolationLevel)
                    phase = CartTransactionPhase.TransactionActive

                    Dim workResult As CartTransactionWorkResult(Of TResult) = work(conn, transaction)
                    If workResult Is Nothing Then Throw New InvalidOperationException("The cart transaction work returned no result.")

                    If Not workResult.ShouldCommit Then
                        Dim abortRollback As CartTransactionRollbackStatus = RollbackExplicit(transaction)
                        lastResult = CreateResult(CartTransactionExecutionStatus.Failed, workResult.Value, attempt, -1,
                                                  phase, abortRollback, stopwatch.ElapsedMilliseconds)
                        LogDecision(safeCorrelationId, safeOperation, attempt, -1, phase, abortRollback,
                                    "business-abort", stopwatch.ElapsedMilliseconds)
                        Return lastResult
                    End If

                    phase = CartTransactionPhase.CommitStarted
                    transaction.Commit()
                    phase = CartTransactionPhase.CommitSucceeded

                    lastResult = CreateResult(CartTransactionExecutionStatus.Succeeded, workResult.Value, attempt, -1,
                                              phase, CartTransactionRollbackStatus.NotRequired, stopwatch.ElapsedMilliseconds)
                    LogDecision(safeCorrelationId, safeOperation, attempt, -1, phase,
                                CartTransactionRollbackStatus.NotRequired, "committed", stopwatch.ElapsedMilliseconds)
                    Return lastResult
                Catch ex As Exception
                    Dim mysqlNumber As Integer = GetMySqlErrorNumber(ex)
                    Dim rollbackStatus As CartTransactionRollbackStatus = CartTransactionRollbackStatus.NotRequired

                    If transaction IsNot Nothing AndAlso phase = CartTransactionPhase.TransactionActive Then
                        If mysqlNumber = 1213 Then
                            rollbackStatus = RollbackBestEffort(transaction)
                        Else
                            rollbackStatus = RollbackExplicit(transaction)
                        End If
                    ElseIf transaction IsNot Nothing AndAlso phase = CartTransactionPhase.CommitStarted AndAlso
                           (mysqlNumber = 1213 OrElse mysqlNumber = 1205) Then
                        If mysqlNumber = 1213 Then
                            rollbackStatus = RollbackBestEffort(transaction)
                        Else
                            rollbackStatus = RollbackExplicit(transaction)
                        End If
                    End If

                    Dim commitIndeterminate As Boolean = phase = CartTransactionPhase.CommitStarted AndAlso
                        mysqlNumber <> 1213 AndAlso mysqlNumber <> 1205
                    Dim retryable As Boolean = sessionConfigured AndAlso
                        (phase = CartTransactionPhase.TransactionActive OrElse phase = CartTransactionPhase.CommitStarted) AndAlso
                        (mysqlNumber = 1213 OrElse
                         (mysqlNumber = 1205 AndAlso rollbackStatus = CartTransactionRollbackStatus.Succeeded))

                    If commitIndeterminate Then
                        lastResult = CreateResult(Of TResult)(CartTransactionExecutionStatus.Indeterminate, Nothing, attempt,
                                                              mysqlNumber, phase, rollbackStatus, stopwatch.ElapsedMilliseconds)
                        LogDecision(safeCorrelationId, safeOperation, attempt, mysqlNumber, phase, rollbackStatus,
                                    "commit-indeterminate", stopwatch.ElapsedMilliseconds)
                        Return lastResult
                    End If

                    If retryable AndAlso attempt < MaximumAttempts Then
                        Dim delayMilliseconds As Integer = CalculateBackoffMilliseconds(attempt)
                        If stopwatch.ElapsedMilliseconds + delayMilliseconds < MaximumElapsedMilliseconds Then
                            LogDecision(safeCorrelationId, safeOperation, attempt, mysqlNumber, phase, rollbackStatus,
                                        "retry-planned", stopwatch.ElapsedMilliseconds)
                            Thread.Sleep(delayMilliseconds)
                            Continue For
                        End If
                    End If

                    Dim decision As String = If(retryable, "retry-exhausted", "not-retryable")
                    lastResult = CreateResult(Of TResult)(CartTransactionExecutionStatus.Failed, Nothing, attempt,
                                                          mysqlNumber, phase, rollbackStatus, stopwatch.ElapsedMilliseconds)
                    LogDecision(safeCorrelationId, safeOperation, attempt, mysqlNumber, phase, rollbackStatus,
                                decision, stopwatch.ElapsedMilliseconds)
                    Return lastResult
                Finally
                    DisposeTransactionSafely(transaction, safeCorrelationId, safeOperation, attempt,
                                             phase, stopwatch.ElapsedMilliseconds)
                    DisposeConnectionSafely(conn, safeCorrelationId, safeOperation, attempt,
                                            phase, stopwatch.ElapsedMilliseconds)
                End Try
            Next

            If lastResult IsNot Nothing Then Return lastResult
            Return CreateResult(Of TResult)(CartTransactionExecutionStatus.Failed, Nothing, MaximumAttempts,
                                             -1, CartTransactionPhase.BeforeTransaction,
                                             CartTransactionRollbackStatus.NotRequired, stopwatch.ElapsedMilliseconds)
        Finally
            _activeBoundaryDepth -= 1
            stopwatch.Stop()
        End Try
    End Function

    Public Shared Function IsWhitelistedTransient(ByVal ex As Exception) As Boolean
        Dim number As Integer = GetMySqlErrorNumber(ex)
        Return number = 1213 OrElse number = 1205
    End Function

    Public Shared Function GetMySqlErrorNumber(ByVal ex As Exception) As Integer
        Dim mysqlException As MySqlException = TryCast(ex, MySqlException)
        If mysqlException Is Nothing Then Return -1
        Return mysqlException.Number
    End Function

    Private Shared Function RollbackExplicit(ByVal transaction As MySqlTransaction) As CartTransactionRollbackStatus
        Try
            transaction.Rollback()
            Return CartTransactionRollbackStatus.Succeeded
        Catch rollbackError As Exception
            Trace.TraceWarning("cart-transaction-retry rollback failed")
            Return CartTransactionRollbackStatus.Failed
        End Try
    End Function

    Private Shared Function RollbackBestEffort(ByVal transaction As MySqlTransaction) As CartTransactionRollbackStatus
        Try
            transaction.Rollback()
            Return CartTransactionRollbackStatus.BestEffortSucceeded
        Catch rollbackError As Exception
            Trace.TraceWarning("cart-transaction-retry best-effort rollback unavailable")
            Return CartTransactionRollbackStatus.BestEffortFailed
        End Try
    End Function

    Private Shared Sub DisposeTransactionSafely(ByVal transaction As MySqlTransaction,
                                                ByVal correlationId As String,
                                                ByVal logicalOperation As String,
                                                ByVal attempt As Integer,
                                                ByVal phase As CartTransactionPhase,
                                                ByVal durationMilliseconds As Long)
        If transaction Is Nothing Then Return
        Try
            transaction.Dispose()
        Catch disposeError As Exception
            LogDecision(correlationId, logicalOperation, attempt, -1, phase,
                        CartTransactionRollbackStatus.NotRequired,
                        "transaction-dispose-failed", durationMilliseconds)
        End Try
    End Sub

    Private Shared Sub DisposeConnectionSafely(ByVal connection As MySqlConnection,
                                               ByVal correlationId As String,
                                               ByVal logicalOperation As String,
                                               ByVal attempt As Integer,
                                               ByVal phase As CartTransactionPhase,
                                               ByVal durationMilliseconds As Long)
        If connection Is Nothing Then Return
        Try
            connection.Dispose()
        Catch disposeError As Exception
            LogDecision(correlationId, logicalOperation, attempt, -1, phase,
                        CartTransactionRollbackStatus.NotRequired,
                        "connection-dispose-failed", durationMilliseconds)
        End Try
    End Sub

    Private Shared Function CalculateBackoffMilliseconds(ByVal completedAttempt As Integer) As Integer
        Dim baseDelay As Integer = If(completedAttempt <= 1, 50, 100)
        Dim maximumJitter As Integer = If(completedAttempt <= 1, 50, 100)
        Return baseDelay + NextJitter(maximumJitter)
    End Function

    Private Shared Function NextJitter(ByVal inclusiveMaximum As Integer) As Integer
        If inclusiveMaximum <= 0 Then Return 0
        Dim bytes(3) As Byte
        Using generator As RandomNumberGenerator = RandomNumberGenerator.Create()
            generator.GetBytes(bytes)
        End Using
        Dim positiveValue As UInteger = BitConverter.ToUInt32(bytes, 0)
        Return CInt(positiveValue Mod CUInt(inclusiveMaximum + 1))
    End Function

    Private Shared Function CreateResult(Of TResult)(ByVal status As CartTransactionExecutionStatus,
                                                      ByVal value As TResult,
                                                      ByVal attempts As Integer,
                                                      ByVal mysqlNumber As Integer,
                                                      ByVal phase As CartTransactionPhase,
                                                      ByVal rollbackStatus As CartTransactionRollbackStatus,
                                                      ByVal durationMilliseconds As Long) As CartTransactionExecutionResult(Of TResult)
        Return New CartTransactionExecutionResult(Of TResult) With {
            .Status = status,
            .Value = value,
            .Attempts = attempts,
            .MySqlNumber = mysqlNumber,
            .Phase = phase,
            .RollbackStatus = rollbackStatus,
            .DurationMilliseconds = durationMilliseconds
        }
    End Function

    Private Shared Function NormalizeCorrelationId(ByVal value As String) As String
        Dim parsed As Guid
        If Guid.TryParse(value, parsed) Then Return parsed.ToString("D", CultureInfo.InvariantCulture)
        Return "none"
    End Function

    Private Shared Function NormalizeLogicalOperation(ByVal value As String) As String
        If String.IsNullOrWhiteSpace(value) Then Return "cart-transaction"
        Dim chars As New Text.StringBuilder()
        For Each current As Char In value.Trim().ToLowerInvariant()
            If (current >= "a"c AndAlso current <= "z"c) OrElse
               (current >= "0"c AndAlso current <= "9"c) OrElse current = "-"c Then
                chars.Append(current)
            End If
            If chars.Length >= 48 Then Exit For
        Next
        If chars.Length = 0 Then Return "cart-transaction"
        Return chars.ToString()
    End Function

    Private Shared Sub LogDecision(ByVal correlationId As String,
                                   ByVal logicalOperation As String,
                                   ByVal attempt As Integer,
                                   ByVal mysqlNumber As Integer,
                                   ByVal phase As CartTransactionPhase,
                                   ByVal rollbackStatus As CartTransactionRollbackStatus,
                                   ByVal decision As String,
                                   ByVal durationMilliseconds As Long)
        Dim message As String =
            "correlation=" & correlationId &
            " operation=" & logicalOperation &
            " attempt=" & attempt.ToString(CultureInfo.InvariantCulture) &
            " mysql=" & mysqlNumber.ToString(CultureInfo.InvariantCulture) &
            " phase=" & phase.ToString() &
            " rollback=" & rollbackStatus.ToString() &
            " decision=" & decision &
            " durationMs=" & durationMilliseconds.ToString(CultureInfo.InvariantCulture)
        KeepStoreLog.Info("cart-transaction-retry", message, Nothing)
    End Sub
End Class
