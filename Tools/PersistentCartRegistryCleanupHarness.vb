Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Reflection
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient

' Test-only memory sink. The real SQL and existing retry policy are compiled unchanged.
Public NotInheritable Class KeepStoreLog
    Public Shared ReadOnly Messages As New List(Of String)()
    Public Shared Sub Info(area As String, message As String, Optional context As HttpContext = Nothing)
        Messages.Add(message)
    End Sub
End Class

Public Module PersistentCartRegistryCleanupHarness
    Private NotInheritable Class Fixture
        Friend Company As Integer
        Friend Owner As String
        Friend Id As Long
    End Class
    Private ReadOnly Fixtures As New List(Of Fixture)()
    Private ReadOnly RowIds As New List(Of Long)()
    Private ReadOnly CheckCodes As New HashSet(Of String)(StringComparer.Ordinal)
    Private _passed As Integer
    Private _cs As String

    Private Sub Check(code As String, ok As Boolean)
        CheckCodes.Add(code)
        If Not ok Then Throw New InvalidOperationException(code)
        _passed += 1 : Console.WriteLine("PASS " & code)
    End Sub
    Private Function Sql(connection As MySqlConnection, text As String, Optional f As Fixture = Nothing,
                         Optional transaction As MySqlTransaction = Nothing) As Object
        Using command As New MySqlCommand(text, connection, transaction)
            If f IsNot Nothing Then
                command.Parameters.AddWithValue("@company", f.Company)
                command.Parameters.AddWithValue("@owner", f.Owner)
                command.Parameters.AddWithValue("@id", f.Id)
            End If
            Return command.ExecuteScalar()
        End Using
    End Function
    Private Function Create(connection As MySqlConnection, company As Integer, status As String, expired As Boolean,
                            Optional owner As String = Nothing) As Fixture
        If owner Is Nothing Then
            Using sha = SHA256.Create()
                owner = "ksc2_" & Convert.ToBase64String(sha.ComputeHash(Encoding.UTF8.GetBytes(Guid.NewGuid().ToString("N")))).
                    TrimEnd("="c).Replace("+", "-").Replace("/", "_")
            End Using
        End If
        Dim f As New Fixture With {.Company = company, .Owner = owner}
        Using command As New MySqlCommand(
            "INSERT INTO carrello_anonimo_persistenza " &
            "(AziendeId,OwnerToken,Status,CreatedUtc,LastActivityUtc,ExpiresUtc,ConsumedUtc,RevokedUtc) " &
            "VALUES (@company,@owner,@status,UTC_TIMESTAMP(6)-INTERVAL 4 DAY,UTC_TIMESTAMP(6)-INTERVAL 3 DAY," &
            If(expired, "UTC_TIMESTAMP(6)-INTERVAL 1 DAY,", "UTC_TIMESTAMP(6)+INTERVAL 30 DAY,") &
            "IF(@status='CONSUMED',UTC_TIMESTAMP(6)-INTERVAL 2 DAY,NULL)," &
            "IF(@status='REVOKED',UTC_TIMESTAMP(6)-INTERVAL 2 DAY,NULL))", connection)
            command.Parameters.AddWithValue("@company", company) : command.Parameters.AddWithValue("@owner", owner)
            command.Parameters.AddWithValue("@status", status) : command.ExecuteNonQuery()
            f.Id = command.LastInsertedId
        End Using
        Fixtures.Add(f) : Return f
    End Function
    Private Function Seed(connection As MySqlConnection, f As Fixture, Optional login As Integer = 0) As Long
        Using command As New MySqlCommand(
            "INSERT INTO carrello (LoginId,SessionId,ArticoliId,TCId,Qnt,NListino,Prezzo,PrezzoIvato) " &
            "VALUES (@login,@owner,1,-1,1,1,10,12.2)", connection)
            command.Parameters.AddWithValue("@login", login) : command.Parameters.AddWithValue("@owner", f.Owner)
            command.ExecuteNonQuery() : RowIds.Add(command.LastInsertedId) : Return command.LastInsertedId
        End Using
    End Function
    Private Function Exists(connection As MySqlConnection, f As Fixture) As Boolean
        Return Convert.ToInt32(Sql(connection, "SELECT COUNT(*) FROM carrello_anonimo_persistenza " &
            "WHERE AziendeId=@company AND OwnerToken=@owner AND Id=@id", f), CultureInfo.InvariantCulture) = 1
    End Function
    Private Function Rows(connection As MySqlConnection, f As Fixture) As Integer
        Return Convert.ToInt32(Sql(connection, "SELECT COUNT(*) FROM carrello WHERE COALESCE(LoginId,0)<=0 " &
            "AND BINARY SessionId=@owner", f), CultureInfo.InvariantCulture)
    End Function
    Private Function Fingerprint(connection As MySqlConnection, f As Fixture) As String
        Return Convert.ToString(Sql(connection, "SELECT CONCAT(Status,'|',CreatedUtc,'|',LastActivityUtc,'|',ExpiresUtc,'|'," &
            "COALESCE(ConsumedUtc,''),'|',COALESCE(RevokedUtc,'')) FROM carrello_anonimo_persistenza " &
            "WHERE AziendeId=@company AND OwnerToken=@owner AND Id=@id", f), CultureInfo.InvariantCulture)
    End Function
    Private Sub FaultTest(connection As MySqlConnection, number As Integer, retry As Boolean)
        Dim f = Create(connection, 4, "ACTIVE", True) : Seed(connection, f)
        Dim attempts As Integer = 0
        Dim result = CartTransactionRetryPolicy.Execute(Of PersistentCartCleanupOutcome)(
            _cs, IsolationLevel.ReadCommitted, "cleanup-scratch-test", "none",
            Function(c As MySqlConnection, tx As MySqlTransaction)
                attempts += 1
                Dim outcome = PersistentAnonymousCartCleanupService.CleanOwnerAttempt(c, tx, f.Company, f.Id, f.Owner, False)
                If Not retry OrElse attempts = 1 Then
                    ' SQL fault is strictly in this harness, AFTER both real deletions.
                    Sql(c, "SIGNAL SQLSTATE '40001' SET MYSQL_ERRNO=" & number.ToString(CultureInfo.InvariantCulture), Nothing, tx)
                End If
                Return outcome
            End Function)
        If retry Then
            Check("RETRY_" & number.ToString() & "_REAL_POLICY", result.Succeeded AndAlso result.Attempts = 2 AndAlso attempts = 2)
            Check("RETRY_" & number.ToString() & "_ONE_DELETION", Not Exists(connection, f) AndAlso Rows(connection, f) = 0 AndAlso result.Value.DeletedRows = 1)
        Else
            Check("FAILURE_ROLLBACK_REPORTED", Not result.Succeeded AndAlso result.RollbackStatus = CartTransactionRollbackStatus.Succeeded)
            Check("FAILURE_RESTORES_CART_AND_REGISTRY", Exists(connection, f) AndAlso Rows(connection, f) = 1)
        End If
    End Sub

    Public Function Main() As Integer
        AddHandler AppDomain.CurrentDomain.AssemblyResolve, Function(sender, args)
            Dim name = New AssemblyName(args.Name).Name
            If Not System.Text.RegularExpressions.Regex.IsMatch(name, "\A[A-Za-z0-9_.-]+\z") Then Return Nothing
            Dim file = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, name & ".dll")
            Return If(IO.File.Exists(file), Assembly.LoadFrom(file), Nothing)
        End Function
        Dim connection As MySqlConnection = Nothing, verified As Boolean = False
        Dim code As Integer = 0
        Try
            _cs = Console.ReadLine()
            Dim builder As New MySqlConnectionStringBuilder(_cs)
            If builder.Server <> "127.0.0.1" OrElse builder.Port <> 3307UI OrElse builder.Database <> "ks_integration" Then
                Throw New InvalidOperationException("SCRATCH_ONLY")
            End If
            connection = New MySqlConnection(_cs) : connection.Open()
            Check("SCRATCH_PORT", Convert.ToInt32(Sql(connection, "SELECT @@port"), CultureInfo.InvariantCulture) = 3307)
            Check("SCRATCH_DATADIR", Convert.ToString(Sql(connection, "SELECT @@datadir")).Replace("/", "\").
                StartsWith("C:\Temp\KeepStoreIntegration\mysql\data\", StringComparison.OrdinalIgnoreCase))
            verified = True
            Check("EMPTY_FIXTURE_BASELINE", Convert.ToInt32(Sql(connection, "SELECT COUNT(*) FROM carrello")) = 0 AndAlso
                Convert.ToInt32(Sql(connection, "SELECT COUNT(*) FROM carrello_anonimo_persistenza")) = 0)
            Dim live = Create(connection, 1, "ACTIVE", False) : Seed(connection, live)
            Dim emptyActive = Create(connection, 1, "ACTIVE", True)
            Dim expiredActive = Create(connection, 1, "ACTIVE", True)
            Seed(connection, expiredActive) : Seed(connection, expiredActive)
            Dim accountRow = Seed(connection, expiredActive, 880001)
            Dim liveConsumed = Create(connection, 1, "CONSUMED", False)
            Dim emptyConsumed = Create(connection, 1, "CONSUMED", True)
            Dim residualConsumed = Create(connection, 1, "CONSUMED", True) : Seed(connection, residualConsumed)
            Dim liveRevoked = Create(connection, 1, "REVOKED", False)
            Dim emptyRevoked = Create(connection, 1, "REVOKED", True)
            Dim residualRevoked = Create(connection, 1, "REVOKED", True) : Seed(connection, residualRevoked)
            Dim collision = Create(connection, 1, "ACTIVE", True) : Seed(connection, collision)
            Dim otherCompany = Create(connection, 2, "ACTIVE", False, collision.Owner)
            Dim liveBefore = Fingerprint(connection, live), consumedBefore = Fingerprint(connection, liveConsumed)
            Dim revokedBefore = Fingerprint(connection, liveRevoked), otherBefore = Fingerprint(connection, otherCompany)
            Dim result = PersistentAnonymousCartCleanupService.RunBatch(_cs, 1)
            Console.WriteLine("BATCH_COUNTERS active=" & result.ActiveExpiredProcessed.ToString() &
                " consumed=" & result.ConsumedDeleted.ToString() & " revoked=" & result.RevokedDeleted.ToString() &
                " anomalies=" & result.Anomalies.ToString() & " errors=" & result.Errors.ToString())
            Check("DEFAULT_BATCH_100", PersistentAnonymousCartCleanupService.DefaultBatchSize = 100)
            Check("ACTIVE_UNEXPIRED_UNTOUCHED", Fingerprint(connection, live) = liveBefore AndAlso Rows(connection, live) = 1)
            Check("ACTIVE_EXPIRED_EMPTY_DELETED", Not Exists(connection, emptyActive))
            Check("ACTIVE_CART_AND_REGISTRY_DELETED", Not Exists(connection, expiredActive) AndAlso Rows(connection, expiredActive) = 0)
            Check("ACCOUNT_ROW_PRESERVED", Convert.ToInt32(Sql(connection, "SELECT COUNT(*) FROM carrello WHERE id=" & accountRow.ToString() & " AND LoginId=880001")) = 1)
            Check("CONSUMED_UNEXPIRED_UNTOUCHED", Fingerprint(connection, liveConsumed) = consumedBefore)
            Check("CONSUMED_EXPIRED_EMPTY_DELETED", Not Exists(connection, emptyConsumed))
            Check("CONSUMED_RESIDUAL_PRESERVED", Exists(connection, residualConsumed) AndAlso Rows(connection, residualConsumed) = 1)
            Check("REVOKED_UNEXPIRED_UNTOUCHED", Fingerprint(connection, liveRevoked) = revokedBefore)
            Check("REVOKED_EXPIRED_EMPTY_DELETED", Not Exists(connection, emptyRevoked))
            Check("REVOKED_RESIDUAL_PRESERVED", Exists(connection, residualRevoked) AndAlso Rows(connection, residualRevoked) = 1)
            Check("CROSS_COMPANY_COLLISION_FAIL_CLOSED", Exists(connection, collision) AndAlso Rows(connection, collision) = 1 AndAlso
                Fingerprint(connection, otherCompany) = otherBefore)
            Check("STRUCTURED_COUNTERS", result.ActiveExpiredProcessed = 2 AndAlso result.ActiveCartRowsDeleted = 2 AndAlso
                result.ConsumedDeleted = 1 AndAlso result.RevokedDeleted = 1 AndAlso result.Anomalies = 3 AndAlso result.Errors = 0 AndAlso result.CandidatesExamined = 7)
            Check("ANOMALY_LOG_SANITIZED", KeepStoreLog.Messages.Contains("CLEANUP_OWNER_ANOMALY_PRESERVED"))
            Dim remainingBefore = Fingerprint(connection, residualConsumed) & Fingerprint(connection, residualRevoked) & Fingerprint(connection, collision)
            Dim second = PersistentAnonymousCartCleanupService.RunBatch(_cs, 1)
            Check("SECOND_RUN_NO_DELETIONS", second.ActiveExpiredProcessed = 0 AndAlso second.ActiveCartRowsDeleted = 0 AndAlso
                second.ConsumedDeleted = 0 AndAlso second.RevokedDeleted = 0 AndAlso second.Errors = 0 AndAlso second.Anomalies = 3)
            Check("SECOND_RUN_RESIDUALS_UNCHANGED", remainingBefore = Fingerprint(connection, residualConsumed) & Fingerprint(connection, residualRevoked) & Fingerprint(connection, collision))
            For index As Integer = 1 To 3
                Create(connection, 3, "ACTIVE", True)
            Next
            Dim limited = PersistentAnonymousCartCleanupService.RunBatch(_cs, 3, 2)
            Check("BATCH_LIMIT_TWO", limited.CandidatesExamined = 2 AndAlso limited.ActiveExpiredProcessed = 2 AndAlso limited.Errors = 0)
            Dim last = PersistentAnonymousCartCleanupService.RunBatch(_cs, 3, 2)
            Check("BATCH_REMAINDER_ONE", last.CandidatesExamined = 1 AndAlso last.ActiveExpiredProcessed = 1)
            Check("EMPTY_SECOND_RUN_NOOP", PersistentAnonymousCartCleanupService.RunBatch(_cs, 3, 2).CandidatesExamined = 0)
            Dim untouched = CartTransactionRetryPolicy.Execute(Of PersistentCartCleanupOutcome)(
                _cs, IsolationLevel.ReadCommitted, "cleanup-recheck", "none",
                Function(c As MySqlConnection, tx As MySqlTransaction)
                    Return PersistentAnonymousCartCleanupService.CleanOwnerAttempt(c, tx, 1, live.Id, live.Owner, False)
                End Function)
            Check("EXPIRY_RECHECK_AFTER_LOCK", untouched.Succeeded AndAlso untouched.Value.Kind = PersistentCartCleanupKind.Skipped AndAlso Fingerprint(connection, live) = liveBefore)
            Dim wrongCompany = CartTransactionRetryPolicy.Execute(Of PersistentCartCleanupOutcome)(
                _cs, IsolationLevel.ReadCommitted, "cleanup-scope", "none",
                Function(c As MySqlConnection, tx As MySqlTransaction)
                    Return PersistentAnonymousCartCleanupService.CleanOwnerAttempt(c, tx, 2, live.Id, live.Owner, False)
                End Function)
            Check("EXACT_COMPANY_ID_OWNER_SCOPE", wrongCompany.Succeeded AndAlso wrongCompany.Value.Kind = PersistentCartCleanupKind.Skipped AndAlso Exists(connection, live))
            FaultTest(connection, 1644, False)
            FaultTest(connection, 1213, True)
            FaultTest(connection, 1205, True)
            Dim invalidInput As Boolean = False
            Try
                PersistentAnonymousCartCleanupService.RunBatch(_cs, 0)
            Catch ex As ArgumentException
                invalidInput = True
            End Try
            Check("INVALID_COMPANY_FAILS_BEFORE_CONNECTION", invalidInput)
            invalidInput = False
            Try
                PersistentAnonymousCartCleanupService.RunBatch(_cs, 1, 1001)
            Catch ex As ArgumentException
                invalidInput = True
            End Try
            Check("UNBOUNDED_BATCH_REJECTED", invalidInput)
            For Each message In KeepStoreLog.Messages
                For Each f In Fixtures
                    If message.Contains(f.Owner) Then Throw New InvalidOperationException("OWNER_LEAK_IN_LOG")
                Next
                If message.Contains(_cs) OrElse (builder.Password.Length > 0 AndAlso message.Contains(builder.Password)) Then
                    Throw New InvalidOperationException("SECRET_LEAK_IN_LOG")
                End If
            Next
            Check("NO_OWNER_OR_SECRET_IN_LOGS", True)
            Console.WriteLine("CLEANUP_HARNESS_PASS=" & _passed.ToString(CultureInfo.InvariantCulture))
        Catch ex As Exception
            Console.WriteLine("CLEANUP_HARNESS_FAILED TYPE=" & ex.GetType().Name)
            If TypeOf ex Is InvalidOperationException AndAlso CheckCodes.Contains(ex.Message) Then
                Console.WriteLine("CHECK=" & ex.Message)
            End If
            code = 1
        Finally
            If verified AndAlso connection IsNot Nothing AndAlso connection.State = ConnectionState.Open Then
                Try
                    For Each rowId In RowIds
                        Sql(connection, "DELETE FROM carrello WHERE id=" & rowId.ToString(CultureInfo.InvariantCulture))
                    Next
                    For Each f In Fixtures
                        Sql(connection, "DELETE FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND OwnerToken=@owner AND Id=@id", f)
                    Next
                    Check("SCRATCH_FIXTURES_REMOVED", Convert.ToInt32(Sql(connection, "SELECT COUNT(*) FROM carrello")) = 0 AndAlso
                        Convert.ToInt32(Sql(connection, "SELECT COUNT(*) FROM carrello_anonimo_persistenza")) = 0)
                Catch
                    Console.WriteLine("SCRATCH_FIXTURE_CLEANUP_FAILED") : code = 1
                End Try
            End If
            If connection IsNot Nothing Then connection.Dispose()
            _cs = Nothing
        End Try
        Return code
    End Function
End Module
