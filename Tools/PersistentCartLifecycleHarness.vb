Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Reflection
Imports System.Security.Cryptography
Imports System.Web
Imports System.Web.SessionState
Imports MySql.Data.MySqlClient

' Supply a real incoming Cookie header: ASP.NET rebuilds Request.Cookies when
' staged response cookies are removed. Mutating Request.Cookies is not equivalent.
Friend Class LifecycleCookieWorker
    Inherits LocalPostWorker
    Private ReadOnly _cookie As String
    Public Sub New(verb As String, cookie As String)
        MyBase.New(verb)
        _cookie = cookie
    End Sub
    Public Overrides Function GetKnownRequestHeader(index As Integer) As String
        If index = HttpWorkerRequest.HeaderCookie Then Return PersistentAnonymousCartOwnerService.CookieName & "=" & _cookie
        Return MyBase.GetKnownRequestHeader(index)
    End Function
End Class

' Uses the existing activation harness's synthetic scope/worker collaborators.
' No production fault hook, operational DB, or cookie/credential output.
Module PersistentCartLifecycleHarness
    Private _passed As Integer
    Private _connectionString As String
    Private ReadOnly _owners As New HashSet(Of String)(StringComparer.Ordinal)
    Private Class Fixture
        Public Owner As CartStorefrontOwnerScope
        Public Cookie As String
        Public Context As HttpContext
    End Class
    Private Class Registry
        Public Status As String
        Public Created As DateTime
        Public Activity As DateTime
        Public Expiry As DateTime
        Public Revoked As Boolean
        Public Consumed As Boolean
        Public ReadOnly Property Digest As String
            Get
                Return Status & "|" & Created.Ticks & "|" & Activity.Ticks & "|" & Expiry.Ticks & "|" & Revoked & "|" & Consumed
            End Get
        End Property
    End Class
    Private Sub Check(code As String, condition As Boolean)
        If Not condition Then Throw New InvalidOperationException(code)
        _passed += 1 : Console.WriteLine("PASS " & code)
    End Sub
    Private Function NewContext(f As Fixture, Optional verb As String = "POST") As HttpContext
        Dim ctx As New HttpContext(New LifecycleCookieWorker(verb, f.Cookie))
        Dim container As New HttpSessionStateContainer(Guid.NewGuid().ToString("N"), New SessionStateItemCollection(),
            New HttpStaticObjectsCollection(), 20, True, HttpCookieMode.UseCookies, SessionStateMode.InProc, False)
        SessionStateUtility.AddHttpSessionStateToContext(ctx, container)
        ctx.Items("SyntheticOwner") = f.Owner
        HttpContext.Current = ctx
        Return ctx
    End Function
    Private Sub Params(cmd As MySqlCommand, f As Fixture)
        cmd.Parameters.AddWithValue("@owner", f.Owner.SessionId)
        cmd.Parameters.AddWithValue("@company", f.Owner.CompanyId)
    End Sub
    Private Sub Execute(conn As MySqlConnection, tx As MySqlTransaction, f As Fixture, sql As String)
        Using cmd As New MySqlCommand(sql, conn, tx)
            Params(cmd, f) : cmd.ExecuteNonQuery()
        End Using
    End Sub
    Private Function ReadRegistry(conn As MySqlConnection, f As Fixture) As Registry
        Using cmd As New MySqlCommand("SELECT Status,CreatedUtc,LastActivityUtc,ExpiresUtc,RevokedUtc,ConsumedUtc " &
                                     "FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND BINARY OwnerToken=@owner", conn)
            Params(cmd, f)
            Using r = cmd.ExecuteReader()
                If Not r.Read() Then Return Nothing
                Return New Registry With {.Status = r.GetString(0), .Created = Utc(r.GetDateTime(1)),
                    .Activity = Utc(r.GetDateTime(2)), .Expiry = Utc(r.GetDateTime(3)), .Revoked = Not r.IsDBNull(4), .Consumed = Not r.IsDBNull(5)}
            End Using
        End Using
    End Function
    Private Function Utc(value As DateTime) As DateTime
        Return DateTime.SpecifyKind(value, DateTimeKind.Utc)
    End Function
    Private Function Rows(conn As MySqlConnection, f As Fixture) As Integer
        Using cmd As New MySqlCommand("SELECT COUNT(*) FROM carrello WHERE COALESCE(LoginId,0)<=0 AND BINARY SessionId=@owner", conn)
            Params(cmd, f) : Return Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture)
        End Using
    End Function
    Private Function CreateFixture(conn As MySqlConnection, Optional rows As Integer = 1,
                                   Optional status As String = "ACTIVE", Optional expired As Boolean = False) As Fixture
        Dim secret(31) As Byte, cookie As String, owner As String
        Try
            Using rng = RandomNumberGenerator.Create() : rng.GetBytes(secret) : End Using
            cookie = "v2." & Convert.ToBase64String(secret).TrimEnd("="c).Replace("+", "-").Replace("/", "_")
            owner = PersistentAnonymousCartOwnerService.DeriveOwnerToken("synthetic-lifecycle", 1, secret)
        Finally
            Array.Clear(secret, 0, secret.Length)
        End Try
        _owners.Add(owner)
        Dim f As New Fixture With {.Cookie = cookie, .Owner = New CartStorefrontOwnerScope With {
            .DatabaseScopeKey = "synthetic-lifecycle", .CompanyId = 1, .LoginId = 0, .SessionId = owner,
            .Listino = 1, .IsCanonicalMutationHost = True,
            .OwnerScopeKey = CartStorefrontScopePolicy.BuildOwnerScopeKey("synthetic-lifecycle", 1, 0, owner)}}
        f.Context = NewContext(f)
        Using cmd As New MySqlCommand("INSERT INTO carrello_anonimo_persistenza " &
            "(AziendeId,OwnerToken,Status,CreatedUtc,LastActivityUtc,ExpiresUtc,ConsumedUtc,RevokedUtc) " &
            "VALUES (@company,@owner,@status,UTC_TIMESTAMP(6)-INTERVAL 3 DAY,UTC_TIMESTAMP(6)-INTERVAL 2 DAY," &
            "UTC_TIMESTAMP(6)+INTERVAL @days DAY,IF(@status='CONSUMED',UTC_TIMESTAMP(6)-INTERVAL 1 DAY,NULL)," &
            "IF(@status='REVOKED',UTC_TIMESTAMP(6)-INTERVAL 1 DAY,NULL))", conn)
            Params(cmd, f) : cmd.Parameters.AddWithValue("@status", status) : cmd.Parameters.AddWithValue("@days", If(expired, -1, 5))
            cmd.ExecuteNonQuery()
        End Using
        For i = 1 To rows : Mutate(conn, Nothing, f, "add") : Next
        Return f
    End Function
    Private Sub Mutate(conn As MySqlConnection, tx As MySqlTransaction, f As Fixture, kind As String)
        Select Case kind
            Case "add"
                Execute(conn, tx, f, "INSERT INTO carrello (LoginId,SessionId,ArticoliId,TCId,Qnt,Prezzo,PrezzoIvato) VALUES (0,@owner,1,-1,1,10,12.2)")
            Case "quantity"
                Execute(conn, tx, f, "UPDATE carrello SET Qnt=Qnt+1 WHERE BINARY SessionId=@owner")
            Case "commercial"
                Execute(conn, tx, f, "UPDATE carrello SET Prezzo=9,PrezzoIvato=10.98,OfferteDettaglioId=1 WHERE BINARY SessionId=@owner")
            Case "noop"
                Execute(conn, tx, f, "UPDATE carrello SET DataOra=UTC_TIMESTAMP(6) WHERE BINARY SessionId=@owner")
            Case "remove"
                Execute(conn, tx, f, "DELETE FROM carrello WHERE BINARY SessionId=@owner ORDER BY ID LIMIT 1")
            Case "clear"
                Execute(conn, tx, f, "DELETE FROM carrello WHERE BINARY SessionId=@owner")
        End Select
    End Sub
    Private Function Resolve(f As Fixture) As PersistentAnonymousCartOwnerResolution
        Return PersistentAnonymousCartOwnerService.ResolveCookieValue(f.Cookie, f.Owner.DatabaseScopeKey, f.Owner.CompanyId, _connectionString)
    End Function
    Private Sub CookieFlags(code As String, ctx As HttpContext, f As Fixture, deleted As Boolean, expiry As DateTime)
        Check(code & "_ONE_COOKIE", ctx.Response.Cookies.Count = 1)
        Dim cookie = ctx.Response.Cookies(PersistentAnonymousCartOwnerService.CookieName)
        Check(code & "_COOKIE_FLAGS", cookie.Path = "/" AndAlso cookie.Secure AndAlso cookie.HttpOnly AndAlso
              cookie.SameSite = SameSiteMode.Lax AndAlso String.IsNullOrEmpty(cookie.Domain))
        Check(code & "_COOKIE_EXPIRY", If(deleted, cookie.Expires < expiry, cookie.Expires = expiry AndAlso cookie.Value = f.Cookie))
    End Sub
    Private Sub Scenario(conn As MySqlConnection, code As String, kind As String, initial As Integer,
                         Optional outcome As CartTransactionExecutionStatus = CartTransactionExecutionStatus.Succeeded,
                         Optional dbCommitted As Boolean = True)
        Dim f = CreateFixture(conn, initial), ctx = f.Context
        Dim original = ReadRegistry(conn, f), candidate = PersistentAnonymousCartLifecycleService.Prepare(ctx)
        Dim effective = Not (kind = "noop" OrElse (kind = "clear" AndAlso initial = 0))
        Dim revoke = effective AndAlso (kind = "clear" OrElse (kind = "remove" AndAlso initial = 1))
        Dim lower = PersistentAnonymousCartMutationActivation.ReadDatabaseUtc(conn, Nothing)
        Using tx = conn.BeginTransaction(IsolationLevel.Serializable)
            Dim before = PersistentAnonymousCartLifecycleService.BeginAttempt(ctx, conn, tx, candidate)
            Mutate(conn, tx, f, kind)
            Check(code & "_EFFECTIVE", PersistentAnonymousCartLifecycleService.Apply(ctx, conn, tx, candidate, before) = effective)
            Check(code & "_STAGED_BEFORE_COMMIT", candidate.CookieStaged = effective AndAlso ctx.Response.Cookies.Count = If(effective, 1, 0))
            If dbCommitted AndAlso outcome <> CartTransactionExecutionStatus.Failed Then tx.Commit() Else tx.Rollback()
        End Using
        Dim upper = PersistentAnonymousCartMutationActivation.ReadDatabaseUtc(conn, Nothing)
        PersistentAnonymousCartLifecycleService.FinalizeExecution(ctx, candidate, outcome)
        Dim current = ReadRegistry(conn, f)
        If effective AndAlso dbCommitted AndAlso outcome <> CartTransactionExecutionStatus.Failed Then
            Check(code & "_DB_CLOCK", candidate.DatabaseUtc >= lower AndAlso candidate.DatabaseUtc <= upper AndAlso
                  current.Activity = candidate.DatabaseUtc AndAlso current.Expiry = candidate.DatabaseUtc.AddDays(30) AndAlso current.Created = original.Created)
            Check(code & "_REGISTRY_STATE", current.Status = If(revoke, "REVOKED", "ACTIVE") AndAlso current.Revoked = revoke AndAlso Not current.Consumed)
            If revoke Then
                Using cmd As New MySqlCommand("SELECT COUNT(*) FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND BINARY OwnerToken=@owner " &
                                             "AND RevokedUtc=LastActivityUtc AND ExpiresUtc>LastActivityUtc", conn)
                    Params(cmd, f) : Check(code & "_TOMBSTONE_CHECK", Convert.ToInt32(cmd.ExecuteScalar()) = 1)
                End Using
            End If
        Else
            Check(code & "_REGISTRY_UNCHANGED", current.Digest = original.Digest)
        End If
        Dim cookieExpected = effective AndAlso outcome <> CartTransactionExecutionStatus.Failed AndAlso
                             Not (outcome = CartTransactionExecutionStatus.Indeterminate AndAlso revoke)
        Check(code & "_COOKIE_DECISION", ctx.Response.Cookies.Count = If(cookieExpected, 1, 0))
        If cookieExpected Then CookieFlags(code, ctx, f, revoke, candidate.ExpiresUtc)
        If outcome = CartTransactionExecutionStatus.Failed OrElse Not dbCommitted Then
            Check(code & "_ACTIVE_RECOVERABLE", Resolve(f).State = PersistentAnonymousCartOwnerState.ACTIVE AndAlso Rows(conn, f) = initial)
            Check(code & "_INCOMING_COOKIE_RETAINED", ctx.Request.Cookies(PersistentAnonymousCartOwnerService.CookieName).Value = f.Cookie)
        End If
        If outcome = CartTransactionExecutionStatus.Indeterminate AndAlso revoke Then
            PersistentAnonymousCartLifecycleService.HandleReadResolution(ctx, Resolve(f))
            Check(code & "_SAME_RESPONSE_CANNOT_DELETE", ctx.Response.Cookies.Count = 0)
            Dim nextRequest = NewContext(f, "GET")
            PersistentAnonymousCartLifecycleService.HandleReadResolution(nextRequest, Resolve(f))
            Check(code & "_NEXT_GET_REGISTRY_AUTHORITY", nextRequest.Response.Cookies.Count = If(dbCommitted, 1, 0))
        End If
    End Sub
    Private Sub ReadScenario(conn As MySqlConnection, state As PersistentAnonymousCartOwnerState)
        Dim f = CreateFixture(conn, 1, If(state = PersistentAnonymousCartOwnerState.CONSUMED, "CONSUMED",
            If(state = PersistentAnonymousCartOwnerState.REVOKED, "REVOKED", "ACTIVE")), state = PersistentAnonymousCartOwnerState.EXPIRED)
        If state = PersistentAnonymousCartOwnerState.NOT_FOUND Then
            Execute(conn, Nothing, f, "DELETE FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND BINARY OwnerToken=@owner")
        ElseIf state = PersistentAnonymousCartOwnerState.MALFORMED_COOKIE Then
            f.Cookie = "v2.invalid"
        End If
        Dim original = ReadRegistry(conn, f), ctx = NewContext(f, "GET"), resolution = Resolve(f)
        Check(state.ToString() & "_RESOLVED", resolution.State = state)
        PersistentAnonymousCartLifecycleService.HandleReadResolution(ctx, resolution)
        Dim current = ReadRegistry(conn, f)
        Check(state.ToString() & "_READ_NO_DML", If(original Is Nothing, current Is Nothing, current IsNot Nothing AndAlso current.Digest = original.Digest))
        If state = PersistentAnonymousCartOwnerState.ACTIVE Then
            Check("ACTIVE_GET_NO_SET_COOKIE", ctx.Response.Cookies.Count = 0 AndAlso PersistentAnonymousCartLifecycleService.Prepare(ctx) Is Nothing)
        Else
            CookieFlags(state.ToString(), ctx, f, True, PersistentAnonymousCartMutationActivation.ReadDatabaseUtc(conn, Nothing))
            Check(state.ToString() & "_FALLBACK_KSC1", resolution.OwnerToken Is Nothing AndAlso
                  CartStorefrontScopePolicy.BuildAnonymousOwnerToken(f.Owner.DatabaseScopeKey, 1, ctx.Session.SessionID).StartsWith("ksc1_", StringComparison.Ordinal))
        End If
    End Sub
    Private Sub RegistryGate(conn As MySqlConnection, code As String, status As String, expired As Boolean, missing As Boolean)
        Dim f = CreateFixture(conn, 1, status, expired), originalRows = Rows(conn, f)
        If missing Then Execute(conn, Nothing, f, "DELETE FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND BINARY OwnerToken=@owner")
        Dim original = ReadRegistry(conn, f), candidate = PersistentAnonymousCartLifecycleService.Prepare(f.Context), reached As Boolean = False
        Dim execution = CartTransactionRetryPolicy.Execute(Of Boolean)(_connectionString, IsolationLevel.Serializable, "lifecycle-gate-harness", Guid.NewGuid().ToString(),
            Function(c As MySqlConnection, tx As MySqlTransaction) As CartTransactionWorkResult(Of Boolean)
                PersistentAnonymousCartLifecycleService.BeginAttempt(f.Context, c, tx, candidate)
                reached = True : Mutate(c, tx, f, "add")
                Return CartTransactionWorkResult(Of Boolean).Commit(True)
            End Function)
        PersistentAnonymousCartLifecycleService.FinalizeExecution(f.Context, candidate, execution.Status)
        Dim current = ReadRegistry(conn, f)
        Check(code & "_FAIL_CLOSED_BEFORE_MUTATION", Not reached AndAlso execution.Status = CartTransactionExecutionStatus.Failed AndAlso Rows(conn, f) = originalRows)
        Check(code & "_NO_REGISTRY_COOKIE_CHANGE", f.Context.Response.Cookies.Count = 0 AndAlso
              If(original Is Nothing, current Is Nothing, current IsNot Nothing AndAlso current.Digest = original.Digest))
    End Sub
    Private Sub CookieFailure(conn As MySqlConnection, kind As String)
        Dim f = CreateFixture(conn), original = ReadRegistry(conn, f), candidate = PersistentAnonymousCartLifecycleService.Prepare(f.Context)
        Dim cookies = f.Context.Response.Cookies
        Dim ro = GetType(Collections.Specialized.NameObjectCollectionBase).GetProperty("IsReadOnly", BindingFlags.NonPublic Or BindingFlags.Instance)
        Dim execution As CartTransactionExecutionResult(Of Boolean), failed As Boolean = False
        ro.SetValue(cookies, True, Nothing)
        Try
            execution = CartTransactionRetryPolicy.Execute(Of Boolean)(_connectionString, IsolationLevel.Serializable, "lifecycle-cookie-failure", Guid.NewGuid().ToString(),
                Function(c As MySqlConnection, tx As MySqlTransaction) As CartTransactionWorkResult(Of Boolean)
                    Dim before = PersistentAnonymousCartLifecycleService.BeginAttempt(f.Context, c, tx, candidate)
                    Mutate(c, tx, f, kind)
                    Try
                        PersistentAnonymousCartLifecycleService.Apply(f.Context, c, tx, candidate, before)
                    Catch ex As NotSupportedException
                        failed = True : Throw
                    End Try
                    Return CartTransactionWorkResult(Of Boolean).Commit(True)
                End Function)
        Finally
            ro.SetValue(cookies, False, Nothing)
        End Try
        PersistentAnonymousCartLifecycleService.FinalizeExecution(f.Context, candidate, execution.Status)
        Check("COOKIE_FAILURE_" & kind & "_ROLLBACK", failed AndAlso execution.Status = CartTransactionExecutionStatus.Failed AndAlso
              ReadRegistry(conn, f).Digest = original.Digest AndAlso Rows(conn, f) = 1 AndAlso f.Context.Response.Cookies.Count = 0)
    End Sub
    Private Sub RetryLifecycle(conn As MySqlConnection, kind As String)
        Dim f = CreateFixture(conn), candidate = PersistentAnonymousCartLifecycleService.Prepare(f.Context), attempts As Integer = 0
        Dim execution = CartTransactionRetryPolicy.Execute(Of Boolean)(_connectionString, IsolationLevel.Serializable, "lifecycle-retry-harness", Guid.NewGuid().ToString(),
            Function(c As MySqlConnection, tx As MySqlTransaction) As CartTransactionWorkResult(Of Boolean)
                attempts += 1
                Dim before = PersistentAnonymousCartLifecycleService.BeginAttempt(f.Context, c, tx, candidate)
                Check("RETRY_" & kind & "_INCOMING_COOKIE_" & attempts, f.Context.Request.Cookies(PersistentAnonymousCartOwnerService.CookieName).Value = f.Cookie)
                Mutate(c, tx, f, kind)
                PersistentAnonymousCartLifecycleService.Apply(f.Context, c, tx, candidate, before)
                If attempts = 1 Then
                    Using cmd As New MySqlCommand("SIGNAL SQLSTATE '40001' SET MYSQL_ERRNO=1213, MESSAGE_TEXT='Synthetic lifecycle retry'", c, tx)
                        cmd.ExecuteNonQuery()
                    End Using
                End If
                Return CartTransactionWorkResult(Of Boolean).Commit(True)
            End Function)
        PersistentAnonymousCartLifecycleService.FinalizeExecution(f.Context, candidate, execution.Status)
        Check("RETRY_" & kind & "_COMPLETED_ONCE", execution.Succeeded AndAlso execution.Attempts = 2 AndAlso
              Rows(conn, f) = If(kind = "clear", 0, 2) AndAlso ReadRegistry(conn, f).Status = If(kind = "clear", "REVOKED", "ACTIVE"))
        CookieFlags("RETRY_" & kind, f.Context, f, kind = "clear", candidate.ExpiresUtc)
    End Sub
    Sub Main()
        AddHandler AppDomain.CurrentDomain.AssemblyResolve, Function(sender, args)
            Dim file = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, New AssemblyName(args.Name).Name & ".dll")
            Return If(IO.File.Exists(file), Assembly.LoadFrom(file), Nothing)
        End Function
        Try
            Dim input = Console.ReadLine(), builder As New MySqlConnectionStringBuilder(input)
            If builder.Server <> "127.0.0.1" OrElse builder.Port <> 3307 OrElse builder.Database <> "ks_integration" Then Throw New InvalidOperationException("SCRATCH_ONLY_REQUIRED")
            _connectionString = input : input = Nothing
            Using conn As New MySqlConnection(_connectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT @@datadir", conn)
                    Check("ISOLATED_SCRATCH_DATADIR", Convert.ToString(cmd.ExecuteScalar()).Replace("/", "\").StartsWith("C:\Temp\KeepStoreIntegration\mysql\data", StringComparison.OrdinalIgnoreCase))
                End Using
                Scenario(conn, "ACTIVE_ADD", "add", 1)
                Scenario(conn, "ACTIVE_QUANTITY", "quantity", 1)
                Scenario(conn, "COMMERCIAL_CHANGE", "commercial", 1)
                Scenario(conn, "NOOP_NO_SLIDE", "noop", 1)
                Scenario(conn, "REMOVE_RESIDUAL_REFRESH", "remove", 2)
                Scenario(conn, "REMOVE_LAST_REVOKE", "remove", 1)
                Scenario(conn, "CLEAR_REVOKE", "clear", 2)
                Scenario(conn, "CLEAR_EMPTY_NOOP", "clear", 0)
                Scenario(conn, "ROLLBACK_REFRESH", "add", 1, CartTransactionExecutionStatus.Failed, False)
                Scenario(conn, "ROLLBACK_REVOKE", "clear", 1, CartTransactionExecutionStatus.Failed, False)
                Scenario(conn, "INDETERMINATE_REFRESH_COMMITTED", "add", 1, CartTransactionExecutionStatus.Indeterminate, True)
                Scenario(conn, "INDETERMINATE_REFRESH_ROLLED_BACK", "add", 1, CartTransactionExecutionStatus.Indeterminate, False)
                Scenario(conn, "INDETERMINATE_REVOKE_COMMITTED", "clear", 1, CartTransactionExecutionStatus.Indeterminate, True)
                Scenario(conn, "INDETERMINATE_REVOKE_ROLLED_BACK", "clear", 1, CartTransactionExecutionStatus.Indeterminate, False)
                For Each state In New PersistentAnonymousCartOwnerState() {PersistentAnonymousCartOwnerState.ACTIVE,
                    PersistentAnonymousCartOwnerState.REVOKED, PersistentAnonymousCartOwnerState.EXPIRED,
                    PersistentAnonymousCartOwnerState.NOT_FOUND, PersistentAnonymousCartOwnerState.CONSUMED,
                    PersistentAnonymousCartOwnerState.MALFORMED_COOKIE}
                    ReadScenario(conn, state)
                Next
                RegistryGate(conn, "REVOKED_GATE", "REVOKED", False, False)
                RegistryGate(conn, "CONSUMED_GATE", "CONSUMED", False, False)
                RegistryGate(conn, "EXPIRED_GATE", "ACTIVE", True, False)
                RegistryGate(conn, "MISSING_GATE", "ACTIVE", False, True)
                CookieFailure(conn, "add") : CookieFailure(conn, "clear")
                RetryLifecycle(conn, "add") : RetryLifecycle(conn, "clear")
                Dim f = CreateFixture(conn), ctx = NewContext(f, "GET"), technical = PersistentAnonymousCartOwnerService.ResolveCookieValue(f.Cookie, f.Owner.DatabaseScopeKey, 1, Nothing)
                Dim unavailable As Boolean = False
                Try
                    PersistentAnonymousCartLifecycleService.HandleReadResolution(ctx, technical)
                Catch ex As HttpException
                    unavailable = ex.GetHttpCode() = 503
                End Try
                Check("TECHNICAL_ERROR_503_NO_COOKIE_DELETE", unavailable AndAlso ctx.Response.Cookies.Count = 0)
                PersistentAnonymousCartLifecycleService.HandleReadResolution(ctx, New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.NO_COOKIE))
                Check("NO_COOKIE_GET_NO_SET_COOKIE", ctx.Response.Cookies.Count = 0)
                ctx.Response.Flush()
                PersistentAnonymousCartLifecycleService.HandleReadResolution(ctx, New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.NOT_FOUND))
                Check("HEADERS_SENT_CLEANUP_SKIPPED", ctx.Response.HeadersWritten AndAlso ctx.Response.Cookies.Count = 0)
                f.Owner.LoginId = 42
                Check("AUTHENTICATED_NO_LIFECYCLE", PersistentAnonymousCartLifecycleService.Prepare(NewContext(f)) Is Nothing)
            End Using
        Catch ex As Exception
            Dim e = ex
            While e.InnerException IsNot Nothing : e = e.InnerException : End While
            Console.WriteLine("FAIL TYPE=" & e.GetType().Name & " CODE=" & If(Text.RegularExpressions.Regex.IsMatch(e.Message, "^[A-Z0-9_]+$"), e.Message, "LIFECYCLE_HARNESS_FAILED"))
            Environment.ExitCode = 1
        Finally
            If _connectionString IsNot Nothing Then
                Using conn As New MySqlConnection(_connectionString)
                    conn.Open()
                    For Each owner In _owners
                        Using cmd As New MySqlCommand("DELETE FROM carrello WHERE COALESCE(LoginId,0)<=0 AND BINARY SessionId=@owner; " &
                            "DELETE FROM carrello_anonimo_persistenza WHERE AziendeId=1 AND BINARY OwnerToken=@owner", conn)
                            cmd.Parameters.AddWithValue("@owner", owner) : cmd.ExecuteNonQuery()
                        End Using
                    Next
                End Using
            End If
            _connectionString = Nothing
        End Try
        If Environment.ExitCode = 0 Then Console.WriteLine("TOTAL_PASS=" & _passed)
    End Sub
End Module
