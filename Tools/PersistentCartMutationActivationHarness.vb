Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Reflection
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.SessionState
Imports MySql.Data.MySqlClient

' Harness-only collaborators; no test hooks are compiled into App_Code.
Public Class CartStorefrontOwnerScope
    Public Property DatabaseScopeKey As String
    Public Property CompanyId As Integer
    Public Property LoginId As Integer
    Public Property SessionId As String
    Public Property Listino As Integer
    Public Property OwnerScopeKey As String
    Public Property IsCanonicalMutationHost As Boolean
End Class
Public Class CartStorefrontOwnerContext
    Public Shared Function ResolveForMutation(ctx As HttpContext) As CartStorefrontOwnerScope
        Dim source = TryCast(ctx.Items("SyntheticOwner"), CartStorefrontOwnerScope)
        Return If(PersistentAnonymousCartMutationActivation.CommittedOwner(ctx, source.DatabaseScopeKey, source.CompanyId), source)
    End Function
End Class
Public Class CartStandardBatchMutationRequest
    Public Property ArticleId As Integer
    Public Property RequestedTCId As Integer
    Public Property QuantityDelta As Decimal
End Class
Public Class CartQuantityMutationRequest
    Public Property CartRowId As Integer
    Public Property Quantity As Decimal
End Class
Public Class KeepStoreLog
    Public Shared Sub Info(a As String, b As String, ctx As HttpContext)
    End Sub
End Class
Friend Class LocalPostWorker
    Inherits SimpleWorkerRequest
    Private ReadOnly _verb As String
    Private ReadOnly _secure As Boolean
    Public Sub New(verb As String, Optional secure As Boolean = True)
        MyBase.New("/", AppDomain.CurrentDomain.BaseDirectory, "test.aspx", "", New StringWriter())
        _verb = verb
        _secure = secure
    End Sub
    Public Overrides Function GetHttpVerbName() As String
        Return _verb
    End Function
    Public Overrides Function IsSecure() As Boolean
        Return _secure
    End Function
End Class

Module PersistentCartMutationActivationHarness
    Private _passed As Integer
    Private _connectionString As String
    Private ReadOnly _tokens As New HashSet(Of String)(StringComparer.Ordinal)
    Private Sub Check(code As String, condition As Boolean)
        If Not condition Then Throw New InvalidOperationException(code)
        _passed += 1 : Console.WriteLine("PASS " & code)
    End Sub
    Private Function Context(operation As String, payload As String, Optional login As Integer = 0, Optional verb As String = "POST", Optional secure As Boolean = True) As HttpContext
        Dim ctx As New HttpContext(New LocalPostWorker(verb, secure))
        HttpContext.Current = ctx
        Dim sessionId = Guid.NewGuid().ToString("N")
        Dim container As New HttpSessionStateContainer(sessionId, New SessionStateItemCollection(),
            New HttpStaticObjectsCollection(), 20, True, HttpCookieMode.UseCookies, SessionStateMode.InProc, False)
        SessionStateUtility.AddHttpSessionStateToContext(ctx, container)
        Dim token = CartStorefrontScopePolicy.BuildAnonymousOwnerToken("synthetic-activation", 1, sessionId)
        _tokens.Add(token)
        ctx.Items("SyntheticOwner") = New CartStorefrontOwnerScope With {
            .DatabaseScopeKey = "synthetic-activation", .CompanyId = 1, .LoginId = login,
            .SessionId = token, .Listino = 1, .IsCanonicalMutationHost = True,
            .OwnerScopeKey = CartStorefrontScopePolicy.BuildOwnerScopeKey("synthetic-activation", 1, login, token)}
        Dim requestId = Guid.NewGuid().ToString("N")
        CartMutationIdempotencyService.RegisterIntent(ctx, requestId, operation, payload)
        CartMutationIdempotencyService.BeginIntent(ctx, requestId, operation, payload)
        ctx.Items("HarnessRequestId") = requestId
        Return ctx
    End Function
    Private Function Prepare(ctx As HttpContext) As PersistentCartActivationCandidate
        Dim candidate = PersistentAnonymousCartMutationActivation.Prepare(ctx)
        If candidate IsNot Nothing Then _tokens.Add(candidate.Target.SessionId)
        Return candidate
    End Function
    Private Function Exec(conn As MySqlConnection, tx As MySqlTransaction, sql As String, owner As String, Optional q As Integer = 1) As Integer
        Using cmd As New MySqlCommand(sql, conn, tx)
            cmd.Parameters.AddWithValue("@owner", owner) : cmd.Parameters.AddWithValue("@quantity", q)
            Return cmd.ExecuteNonQuery()
        End Using
    End Function
    Private Sub Insert(conn As MySqlConnection, tx As MySqlTransaction, owner As String)
        Exec(conn, tx, "INSERT INTO carrello (LoginId,SessionId,ArticoliId,TCId,Qnt) VALUES (0,@owner,1,-1,1)", owner)
    End Sub
    Private Function Count(conn As MySqlConnection, table As String, owner As String) As Integer
        Using cmd As New MySqlCommand("SELECT COUNT(*) FROM " & table & " WHERE BINARY " & If(table = "carrello", "SessionId", "OwnerToken") & "=@owner", conn)
            cmd.Parameters.AddWithValue("@owner", owner)
            Return Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture)
        End Using
    End Function
    Private Sub Scenario(operation As String, mutation As String, expected As Boolean, Optional oldRows As Integer = 1)
        Dim ctx = Context(operation, "synthetic-payload")
        Dim candidate = Prepare(ctx)
        Check(operation & "_CANDIDATE", candidate IsNot Nothing)
        Using conn As New MySqlConnection(_connectionString)
            conn.Open()
            For i = 1 To oldRows : Insert(conn, Nothing, candidate.Source.SessionId) : Next
            Using tx = conn.BeginTransaction(IsolationLevel.Serializable)
                Dim before = PersistentAnonymousCartMutationActivation.Capture(conn, tx, candidate)
                Select Case mutation
                    Case "add" : Insert(conn, tx, candidate.Source.SessionId)
                    Case "set" : Exec(conn, tx, "UPDATE carrello SET Qnt=@quantity WHERE BINARY SessionId=@owner", candidate.Source.SessionId, 2)
                    Case "noop" : Exec(conn, tx, "UPDATE carrello SET Qnt=Qnt WHERE BINARY SessionId=@owner", candidate.Source.SessionId)
                    Case "remove"
                        Exec(conn, tx, "DELETE FROM carrello WHERE BINARY SessionId=@owner ORDER BY ID LIMIT 1", candidate.Source.SessionId)
                End Select
                Dim clockBefore = PersistentAnonymousCartMutationActivation.ReadDatabaseUtc(conn, tx)
                Dim activated = PersistentAnonymousCartMutationActivation.Activate(ctx, conn, tx, candidate, before)
                Dim clockAfter = PersistentAnonymousCartMutationActivation.ReadDatabaseUtc(conn, tx)
                Check(operation & "_ACTIVATION_DB_CLOCK_" & mutation, Not expected OrElse
                      (candidate.CreatedUtc >= clockBefore AndAlso candidate.CreatedUtc <= clockAfter AndAlso candidate.CreatedUtc.Kind = DateTimeKind.Utc))
                Check(operation & "_EFFECTIVE_ACTIVATION_" & mutation, activated = expected)
                Check(operation & "_COOKIE_STAGED_BEFORE_COMMIT_" & mutation,
                      candidate.CookieStaged = expected AndAlso ctx.Response.Cookies.Count = If(expected, 1, 0) AndAlso Not ctx.Response.HeadersWritten)
                tx.Commit()
                PersistentAnonymousCartMutationActivation.FinalizeExecution(ctx, candidate, CartTransactionExecutionStatus.Succeeded, activated)
            End Using
            Check(operation & "_REGISTRY_" & mutation, Count(conn, "carrello_anonimo_persistenza", candidate.Target.SessionId) = If(expected, 1, 0))
            If expected Then
                Check(operation & "_COOKIE_EXACTLY_ONCE_" & mutation, ctx.Response.Cookies.Count = 1)
                Check(operation & "_ALL_OLD_ROWS_ADOPTED_" & mutation, Count(conn, "carrello", candidate.Source.SessionId) = 0)
                Dim cookie = ctx.Response.Cookies(PersistentAnonymousCartOwnerService.CookieName)
                Dim resolution = PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie.Value, candidate.Source.DatabaseScopeKey, 1, _connectionString)
                Check(operation & "_RESOLVES_ACTIVE_" & mutation, resolution.State = PersistentAnonymousCartOwnerState.ACTIVE AndAlso resolution.OwnerToken = candidate.Target.SessionId)
                Check(operation & "_COOKIE_FLAGS_" & mutation, cookie IsNot Nothing AndAlso cookie.Value.Length = 46 AndAlso
                    cookie.Secure AndAlso cookie.HttpOnly AndAlso cookie.SameSite = SameSiteMode.Lax AndAlso cookie.Path = "/" AndAlso String.IsNullOrEmpty(cookie.Domain))
                Check(operation & "_THIRTY_DAYS_" & mutation, candidate.ExpiresUtc - candidate.CreatedUtc = TimeSpan.FromDays(30) AndAlso cookie.Expires = candidate.ExpiresUtc)
                Using cmd As New MySqlCommand("SELECT COUNT(*) FROM carrello_anonimo_persistenza WHERE OwnerToken=@owner AND Status='ACTIVE' AND CreatedUtc=LastActivityUtc AND TIMESTAMPDIFF(SECOND,CreatedUtc,ExpiresUtc)=2592000 AND ConsumedUtc IS NULL AND RevokedUtc IS NULL", conn)
                    cmd.Parameters.AddWithValue("@owner", candidate.Target.SessionId)
                    Check(operation & "_REGISTRY_METADATA_" & mutation, Convert.ToInt32(cmd.ExecuteScalar()) = 1)
                End Using
                Dim requestId = CStr(ctx.Items("HarnessRequestId"))
                CartMutationIdempotencyService.CompleteIntent(ctx, requestId)
                Check(operation & "_PROMOTED_REPLAY_" & mutation, CartMutationIdempotencyService.RegisterIntent(ctx, requestId, operation, "synthetic-payload") = CartMutationIntentDecision.Completed)
                Check(operation & "_CHANGED_PAYLOAD_" & mutation, CartMutationIdempotencyService.RegisterIntent(ctx, requestId, operation, "different") = CartMutationIntentDecision.Collision)
                Check(operation & "_EXISTING_KSC2_NO_CANDIDATE_" & mutation, Prepare(ctx) Is Nothing)
            Else
                Check(operation & "_NO_COOKIE_" & mutation, ctx.Response.Cookies.Count = 0)
            End If
        End Using
    End Sub
    Private Sub RollbackAndRetry(number As Integer)
        Dim ctx = Context("cart-add", "retry-payload")
        Dim candidate = Prepare(ctx)
        Check("CANDIDATE_SAME_REQUEST_" & number, Object.ReferenceEquals(candidate, Prepare(ctx)))
        Using conn As New MySqlConnection(_connectionString)
            conn.Open() : Insert(conn, Nothing, candidate.Source.SessionId)
            Using tx = conn.BeginTransaction()
                Dim before = PersistentAnonymousCartMutationActivation.Capture(conn, tx, candidate)
                Insert(conn, tx, candidate.Source.SessionId)
                Check("ACTIVATION_BEFORE_ROLLBACK_" & number, PersistentAnonymousCartMutationActivation.Activate(ctx, conn, tx, candidate, before))
                tx.Rollback()
            End Using
            PersistentAnonymousCartMutationActivation.FinalizeExecution(ctx, candidate, CartTransactionExecutionStatus.Failed, True)
            Check("ROLLBACK_KSC1_INTACT_" & number, Count(conn, "carrello", candidate.Source.SessionId) = 1)
            Check("ROLLBACK_NO_REGISTRY_" & number, Count(conn, "carrello_anonimo_persistenza", candidate.Target.SessionId) = 0 AndAlso Count(conn, "carrello", candidate.Target.SessionId) = 0)
            Check("ROLLBACK_NO_COOKIE_" & number, ctx.Response.Cookies.Count = 0)
        End Using
        Dim attempts As Integer = 0, activated As Boolean = False
        Dim execution = CartTransactionRetryPolicy.Execute(Of Boolean)(_connectionString, IsolationLevel.Serializable, "activation-harness", Guid.NewGuid().ToString(),
            Function(conn As MySqlConnection, tx As MySqlTransaction) As CartTransactionWorkResult(Of Boolean)
                attempts += 1 : activated = False
                Check("RETRY_SAME_CANDIDATE_" & number & "_" & attempts, Object.ReferenceEquals(candidate, Prepare(ctx)))
                Dim before = PersistentAnonymousCartMutationActivation.Capture(conn, tx, candidate)
                Insert(conn, tx, candidate.Source.SessionId)
                activated = PersistentAnonymousCartMutationActivation.Activate(ctx, conn, tx, candidate, before)
                If attempts = 1 Then
                    Using cmd As New MySqlCommand("SIGNAL SQLSTATE '40001' SET MYSQL_ERRNO=" & number.ToString(CultureInfo.InvariantCulture) & ", MESSAGE_TEXT='Synthetic harness retry'", conn, tx)
                        cmd.ExecuteNonQuery()
                    End Using
                End If
                Return CartTransactionWorkResult(Of Boolean).Commit(activated)
            End Function)
        Check("RETRY_COMPLETED_" & number, execution.Succeeded AndAlso execution.Attempts = 2 AndAlso execution.Value)
        PersistentAnonymousCartMutationActivation.FinalizeExecution(ctx, candidate, execution.Status, activated)
        Check("RETRY_COOKIE_EXACTLY_ONCE_" & number, candidate.CookieStaged AndAlso ctx.Response.Cookies.Count = 1)
        Using conn As New MySqlConnection(_connectionString)
            conn.Open()
            Check("RETRY_ONE_REGISTRY_" & number, Count(conn, "carrello_anonimo_persistenza", candidate.Target.SessionId) = 1)
            Check("RETRY_NO_DUPLICATE_ROWS_" & number, Count(conn, "carrello", candidate.Target.SessionId) = 2)
        End Using
    End Sub

    Private Sub CookieSetFailure()
        Dim ctx = Context("cart-add", "cookie-failure"), candidate = Prepare(ctx)
        Using conn As New MySqlConnection(_connectionString)
            conn.Open() : Insert(conn, Nothing, candidate.Source.SessionId)
        End Using
        ' Harness-only failure injection into the real HttpCookieCollection. No
        ' production hook, mocked activation, or exception after commit is used.
        Dim readOnlyProperty = GetType(Collections.Specialized.NameObjectCollectionBase).GetProperty(
            "IsReadOnly", BindingFlags.NonPublic Or BindingFlags.Instance)
        Dim cookies = ctx.Response.Cookies
        Dim cookieSetFailed As Boolean = False, activated As Boolean = False
        readOnlyProperty.SetValue(cookies, True, Nothing)
        Dim execution As CartTransactionExecutionResult(Of Boolean)
        Try
            execution = CartTransactionRetryPolicy.Execute(Of Boolean)(_connectionString, IsolationLevel.Serializable, "cookie-failure-harness", Guid.NewGuid().ToString(),
                Function(conn As MySqlConnection, tx As MySqlTransaction) As CartTransactionWorkResult(Of Boolean)
                    Dim before = PersistentAnonymousCartMutationActivation.Capture(conn, tx, candidate)
                    Insert(conn, tx, candidate.Source.SessionId)
                    Try
                        activated = PersistentAnonymousCartMutationActivation.Activate(ctx, conn, tx, candidate, before)
                    Catch ex As NotSupportedException
                        cookieSetFailed = True
                        Throw
                    End Try
                    Return CartTransactionWorkResult(Of Boolean).Commit(True)
                End Function)
        Finally
            readOnlyProperty.SetValue(cookies, False, Nothing)
        End Try
        Check("COOKIE_SET_FAILURE_IN_CALLBACK", cookieSetFailed AndAlso execution.Status = CartTransactionExecutionStatus.Failed AndAlso
              execution.Phase = CartTransactionPhase.TransactionActive AndAlso execution.RollbackStatus = CartTransactionRollbackStatus.Succeeded)
        PersistentAnonymousCartMutationActivation.FinalizeExecution(ctx, candidate, execution.Status, activated)
        Check("COOKIE_SET_FAILURE_NO_COOKIE", Not candidate.CookieStaged AndAlso ctx.Response.Cookies.Count = 0)
        Using conn As New MySqlConnection(_connectionString)
            conn.Open()
            Check("COOKIE_SET_FAILURE_ROLLBACK_REGISTRY_ZERO", Count(conn, "carrello_anonimo_persistenza", candidate.Target.SessionId) = 0)
            Check("COOKIE_SET_FAILURE_ROLLBACK_KSC1_INTACT", Count(conn, "carrello", candidate.Source.SessionId) = 1 AndAlso Count(conn, "carrello", candidate.Target.SessionId) = 0)
        End Using
        CartMutationIdempotencyService.AbandonIntent(ctx, CStr(ctx.Items("HarnessRequestId")))
    End Sub

    Private Sub CertainAbort()
        Dim ctx = Context("cart-add", "certain-abort"), candidate = Prepare(ctx)
        Using conn As New MySqlConnection(_connectionString)
            conn.Open() : Insert(conn, Nothing, candidate.Source.SessionId)
        End Using
        Dim activated As Boolean = False
        Dim execution = CartTransactionRetryPolicy.Execute(Of Boolean)(_connectionString, IsolationLevel.Serializable, "certain-abort-harness", Guid.NewGuid().ToString(),
            Function(conn As MySqlConnection, tx As MySqlTransaction) As CartTransactionWorkResult(Of Boolean)
                Dim before = PersistentAnonymousCartMutationActivation.Capture(conn, tx, candidate)
                Insert(conn, tx, candidate.Source.SessionId)
                activated = PersistentAnonymousCartMutationActivation.Activate(ctx, conn, tx, candidate, before)
                Check("CERTAIN_FAILURE_WAS_STAGED", activated AndAlso candidate.CookieStaged AndAlso ctx.Response.Cookies.Count = 1)
                Return CartTransactionWorkResult(Of Boolean).Abort(False)
            End Function)
        PersistentAnonymousCartMutationActivation.FinalizeExecution(ctx, candidate, execution.Status, activated)
        Check("CERTAIN_FAILURE_COOKIE_REMOVAL", execution.Status = CartTransactionExecutionStatus.Failed AndAlso Not candidate.CookieStaged AndAlso ctx.Response.Cookies.Count = 0)
        Using conn As New MySqlConnection(_connectionString)
            conn.Open()
            Check("CERTAIN_FAILURE_KSC1_AND_REGISTRY", Count(conn, "carrello", candidate.Source.SessionId) = 1 AndAlso Count(conn, "carrello_anonimo_persistenza", candidate.Target.SessionId) = 0)
        End Using
        CartMutationIdempotencyService.AbandonIntent(ctx, CStr(ctx.Items("HarnessRequestId")))
    End Sub

    Private Function ReplayContext(original As HttpContext, owner As CartStorefrontOwnerScope) As HttpContext
        Dim ctx As New HttpContext(New LocalPostWorker("POST"))
        Dim items As New SessionStateItemCollection()
        items("KeepStore:CartMutation:Intents") = original.Session("KeepStore:CartMutation:Intents")
        Dim container As New HttpSessionStateContainer(original.Session.SessionID, items,
            New HttpStaticObjectsCollection(), 20, False, HttpCookieMode.UseCookies, SessionStateMode.InProc, False)
        SessionStateUtility.AddHttpSessionStateToContext(ctx, container)
        ctx.Items("SyntheticOwner") = owner
        HttpContext.Current = ctx
        Return ctx
    End Function

    Private Sub IndeterminateOutcome(committed As Boolean)
        Dim code = If(committed, "INDETERMINATE_COMMITTED", "INDETERMINATE_ROLLED_BACK")
        Dim ctx = Context("cart-add", "indeterminate-payload"), candidate = Prepare(ctx)
        Dim activated As Boolean
        Using conn As New MySqlConnection(_connectionString)
            conn.Open() : Insert(conn, Nothing, candidate.Source.SessionId)
            Using tx = conn.BeginTransaction()
                Dim before = PersistentAnonymousCartMutationActivation.Capture(conn, tx, candidate)
                Insert(conn, tx, candidate.Source.SessionId)
                activated = PersistentAnonymousCartMutationActivation.Activate(ctx, conn, tx, candidate, before)
                Check(code & "_STAGED_BEFORE_OUTCOME", activated AndAlso candidate.CookieStaged AndAlso ctx.Response.Cookies.Count = 1)
                ' Simulate the two possible realities of an ambiguous commit, not
                ' a production fault hook or a changed retry policy.
                If committed Then tx.Commit() Else tx.Rollback()
            End Using
            PersistentAnonymousCartMutationActivation.FinalizeExecution(ctx, candidate, CartTransactionExecutionStatus.Indeterminate, activated)
            Check(code & "_COOKIE_KEPT", candidate.CookieStaged AndAlso ctx.Response.Cookies.Count = 1)
            Check(code & "_NO_CERTAIN_OWNER_OVERRIDE", PersistentAnonymousCartMutationActivation.CommittedOwner(ctx, candidate.Source.DatabaseScopeKey, 1) Is Nothing)
            Dim resolution = PersistentAnonymousCartOwnerService.ResolveCookieValue(ctx.Response.Cookies(PersistentAnonymousCartOwnerService.CookieName).Value,
                                                                                   candidate.Source.DatabaseScopeKey, 1, _connectionString)
            Check(code & "_REGISTRY_REALITY", resolution.State = If(committed, PersistentAnonymousCartOwnerState.ACTIVE, PersistentAnonymousCartOwnerState.NOT_FOUND))
            Check(code & "_ROWS", Count(conn, "carrello", candidate.Source.SessionId) = If(committed, 0, 1) AndAlso
                  Count(conn, "carrello", candidate.Target.SessionId) = If(committed, 2, 0))
            Dim replayOwner = If(resolution.State = PersistentAnonymousCartOwnerState.ACTIVE, candidate.Target, candidate.Source)
            If Not committed Then
                Check("KSC1_FALLBACK", resolution.OwnerToken Is Nothing AndAlso replayOwner.SessionId =
                      CartStorefrontScopePolicy.BuildAnonymousOwnerToken(candidate.Source.DatabaseScopeKey, 1, ctx.Session.SessionID))
            End If
            Dim nextRequest = ReplayContext(ctx, replayOwner)
            Dim requestId = CStr(ctx.Items("HarnessRequestId"))
            Check(code & "_REPLAY_INDETERMINATE", CartMutationIdempotencyService.RegisterIntent(nextRequest, requestId, "cart-add", "indeterminate-payload") = CartMutationIntentDecision.Indeterminate)
            Check(code & "_BEGIN_BLOCKED", CartMutationIdempotencyService.BeginIntent(nextRequest, requestId, "cart-add", "indeterminate-payload") = CartMutationIntentDecision.Indeterminate)
            Check(code & "_CHANGED_PAYLOAD_COLLISION", CartMutationIdempotencyService.RegisterIntent(nextRequest, requestId, "cart-add", "different") = CartMutationIntentDecision.Collision)
            Check(code & "_NO_REPLAY_DML", Count(conn, "carrello", candidate.Target.SessionId) = If(committed, 2, 0) AndAlso
                  Count(conn, "carrello_anonimo_persistenza", candidate.Target.SessionId) = If(committed, 1, 0))
        End Using
    End Sub
    Public Sub Main()
        AddHandler AppDomain.CurrentDomain.AssemblyResolve, Function(sender, args)
            Dim name = New AssemblyName(args.Name).Name
            Dim file = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, name & ".dll")
            Return If(IO.File.Exists(file), Assembly.LoadFrom(file), Nothing)
        End Function
        Try
            Dim input As String = Console.ReadLine()
            Dim builder As New MySqlConnectionStringBuilder(input)
            If builder.Server <> "127.0.0.1" OrElse builder.Port <> 3307 OrElse builder.Database <> "ks_integration" Then Throw New InvalidOperationException("SCRATCH_ONLY_REQUIRED")
            _connectionString = input
            input = Nothing
            Scenario("cart-add", "add", True, 2)
            Scenario("pdp-bundle", "add", True, 2)
            Scenario("cart-set", "set", True)
            Scenario("cart-set-row", "set", True)
            Scenario("cart-set-batch", "set", True)
            Scenario("cart-set", "noop", False)
            Scenario("cart-set-row", "noop", False)
            Scenario("cart-set-batch", "noop", False)
            Scenario("cart-remove-row", "remove", True, 2)
            Scenario("cart-remove-row", "remove", False, 1)
            RollbackAndRetry(1213) : RollbackAndRetry(1205)
            CookieSetFailure() : CertainAbort()
            IndeterminateOutcome(True) : IndeterminateOutcome(False)
            Dim read = Context("cart-add", "get", 0, "GET")
            Check("GET_NO_COOKIE", Prepare(read) Is Nothing AndAlso read.Response.Cookies.Count = 0)
            Dim authenticated = Context("cart-add", "authenticated", 42)
            Check("AUTHENTICATED_NO_COOKIE", Prepare(authenticated) Is Nothing AndAlso authenticated.Response.Cookies.Count = 0)
            Check("CLEAR_NO_CANDIDATE", Prepare(Context("cart-clear", "clear")) Is Nothing)
            Dim insecure = Context("cart-add", "insecure", 0, "POST", False)
            Check("INSECURE_NO_COOKIE", Prepare(insecure) Is Nothing AndAlso insecure.Response.Cookies.Count = 0)
            Dim sent = Context("cart-add", "headers-sent")
            sent.Response.Flush()
            Check("HEADERS_WRITTEN_SKIP_ACTIVATION", sent.Response.HeadersWritten AndAlso Prepare(sent) Is Nothing AndAlso sent.Response.Cookies.Count = 0)
            Console.WriteLine("TOTAL_PASS=" & _passed)
        Catch ex As Exception
            Dim e = ex
            While e.InnerException IsNot Nothing : e = e.InnerException : End While
            Console.WriteLine("FAIL TYPE=" & e.GetType().Name & " CODE=" & If(Text.RegularExpressions.Regex.IsMatch(e.Message, "^[A-Z0-9_]+$"), e.Message, "ACTIVATION_HARNESS_FAILED"))
            Environment.ExitCode = 1
        Finally
            If _connectionString IsNot Nothing Then
                Using conn As New MySqlConnection(_connectionString)
                    conn.Open()
                    For Each token In _tokens
                        Exec(conn, Nothing, "DELETE FROM carrello WHERE BINARY SessionId=@owner AND COALESCE(LoginId,0)<=0", token)
                        Exec(conn, Nothing, "DELETE FROM carrello_anonimo_persistenza WHERE BINARY OwnerToken=@owner AND AziendeId=1", token)
                    Next
                End Using
            End If
            _connectionString = Nothing
        End Try
    End Sub
End Module
