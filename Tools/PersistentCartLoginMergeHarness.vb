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
Imports System.Web.Hosting
Imports System.Web.SessionState
Imports MySql.Data.MySqlClient

' Harness-only collaborators. Real ownership SQL, registry, cookie and retry code.
Public Class CartStorefrontOwnerScope
    Public Property DatabaseScopeKey As String
    Public Property CompanyId As Integer
    Public Property LoginId As Integer
    Public Property SessionId As String
    Public Property Listino As Integer
    Public Property OwnerScopeKey As String
    Public Property IsCanonicalMutationHost As Boolean
    Public ReadOnly Property IsAuthenticated As Boolean
        Get
            Return LoginId > 0
        End Get
    End Property
End Class
Public Class CartStorefrontOwnerContext
    Public Shared Function ResolveForMutation(ctx As HttpContext) As CartStorefrontOwnerScope
        Return TryCast(ctx.Items("SyntheticOwner"), CartStorefrontOwnerScope)
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
    Public Shared CleanupFailures As Integer
    Public Shared Sub Info(category As String, message As String, ctx As HttpContext)
        If message = "persistent-login-cookie-cleanup-deferred" Then CleanupFailures += 1
    End Sub
End Class
Public Class CartAuthoritativeReadModel
    Public Shared Invalidations As Integer
    Public Shared Sub Invalidate(ctx As HttpContext)
        Invalidations += 1
    End Sub
End Class
Public Class CartPriceRevalidationResult
    Public Property HasBlockingError As Boolean
    Public Property HasTechnicalError As Boolean
    Public Property HasChanges As Boolean
    Public Property ErrorMessage As String
End Class
Public Class CartPriceRevalidationHelper
    Public Shared Mode As String
    Public Shared Calls As Integer
    Public Shared Function RevalidateCurrentCart(ctx As HttpContext, conn As MySqlConnection, tx As MySqlTransaction,
        loginId As Integer, sessionId As String, listino As Integer, a As Boolean, b As Boolean,
        unused As Object, c As Boolean) As CartPriceRevalidationResult
        Calls += 1
        If Mode = "blocking" Then Return New CartPriceRevalidationResult With {.HasBlockingError = True}
        If Mode = "deadlock" AndAlso Calls = 1 Then
            Using cmd As New MySqlCommand("SIGNAL SQLSTATE '40001' SET MYSQL_ERRNO=1213", conn, tx)
                cmd.ExecuteNonQuery()
            End Using
        End If
        Using cmd As New MySqlCommand("UPDATE carrello SET Prezzo=10,PrezzoIvato=12.2,NListino=@listino WHERE LoginId=@login", conn, tx)
            cmd.Parameters.AddWithValue("@login", loginId) : cmd.Parameters.AddWithValue("@listino", listino)
            cmd.ExecuteNonQuery()
        End Using
        Return New CartPriceRevalidationResult With {.HasChanges = True}
    End Function
    Public Shared Sub StoreResultInSession(ctx As HttpContext, result As CartPriceRevalidationResult)
        ctx.Items("SyntheticRevalidationResult") = result
    End Sub
End Class
Friend Class LoginCookieWorker
    Inherits SimpleWorkerRequest
    Private ReadOnly _cookie As String
    Public Sub New(cookie As String)
        MyBase.New("/", AppDomain.CurrentDomain.BaseDirectory, "test.aspx", "", New StringWriter())
        _cookie = cookie
    End Sub
    Public Overrides Function GetHttpVerbName() As String
        Return "POST"
    End Function
    Public Overrides Function IsSecure() As Boolean
        Return True
    End Function
    Public Overrides Function GetKnownRequestHeader(index As Integer) As String
        If index = HttpWorkerRequest.HeaderCookie AndAlso _cookie IsNot Nothing Then
            Return PersistentAnonymousCartOwnerService.CookieName & "=" & _cookie
        End If
        Return MyBase.GetKnownRequestHeader(index)
    End Function
End Class

Module PersistentCartLoginMergeHarness
    Private _passed As Integer
    Private _cs As String
    Private _scratchVerified As Boolean
    Private _nextLogin As Integer = 1700000000
    Private ReadOnly _owners As New HashSet(Of String)(StringComparer.Ordinal)
    Private ReadOnly _logins As New HashSet(Of Integer)()
    Private Class Fixture
        Public Account As CartStorefrontOwnerScope
        Public Cookie As String
        Public Persistent As String
        Public Legacy As String
        Public Context As HttpContext
    End Class
    Private Sub Check(code As String, ok As Boolean)
        If Not ok Then Throw New InvalidOperationException(code)
        _passed += 1 : Console.WriteLine("PASS " & code)
    End Sub
    Private Function Context(f As Fixture) As HttpContext
        Dim ctx As New HttpContext(New LoginCookieWorker(f.Cookie))
        Dim sessionId As String = Guid.NewGuid().ToString("N")
        SessionStateUtility.AddHttpSessionStateToContext(ctx, New HttpSessionStateContainer(sessionId,
            New SessionStateItemCollection(), New HttpStaticObjectsCollection(), 20, True,
            HttpCookieMode.UseCookies, SessionStateMode.InProc, False))
        ctx.Items("SyntheticOwner") = f.Account : HttpContext.Current = ctx
        f.Legacy = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(f.Account.DatabaseScopeKey, f.Account.CompanyId, sessionId)
        _owners.Add(f.Legacy)
        Return ctx
    End Function
    Private Function Sql(conn As MySqlConnection, sqlText As String, Optional f As Fixture = Nothing,
                         Optional tx As MySqlTransaction = Nothing) As Object
        Using cmd As New MySqlCommand(sqlText, conn, tx)
            If f IsNot Nothing Then
                cmd.Parameters.AddWithValue("@owner", f.Persistent)
                cmd.Parameters.AddWithValue("@legacy", f.Legacy)
                cmd.Parameters.AddWithValue("@company", f.Account.CompanyId)
                cmd.Parameters.AddWithValue("@login", f.Account.LoginId)
            End If
            Return cmd.ExecuteScalar()
        End Using
    End Function
    Private Function Create(conn As MySqlConnection, Optional state As String = "ACTIVE", Optional expired As Boolean = False) As Fixture
        _nextLogin += 1 : _logins.Add(_nextLogin)
        Dim f As New Fixture With {.Account = New CartStorefrontOwnerScope With {
            .DatabaseScopeKey = "synthetic-login", .CompanyId = 1, .LoginId = _nextLogin, .SessionId = "",
            .Listino = 2, .IsCanonicalMutationHost = True,
            .OwnerScopeKey = CartStorefrontScopePolicy.BuildOwnerScopeKey("synthetic-login", 1, _nextLogin, "")}}
        Dim secret(31) As Byte
        Try
            Using rng = RandomNumberGenerator.Create() : rng.GetBytes(secret) : End Using
            f.Cookie = "v2." & Convert.ToBase64String(secret).TrimEnd("="c).Replace("+", "-").Replace("/", "_")
            f.Persistent = PersistentAnonymousCartOwnerService.DeriveOwnerToken(f.Account.DatabaseScopeKey, 1, secret)
        Finally
            Array.Clear(secret, 0, secret.Length)
        End Try
        _owners.Add(f.Persistent) : f.Context = Context(f)
        If state <> "NOT_FOUND" Then
            Sql(conn, "INSERT INTO carrello_anonimo_persistenza (AziendeId,OwnerToken,Status,CreatedUtc,LastActivityUtc,ExpiresUtc,ConsumedUtc,RevokedUtc) " &
                "VALUES (@company,@owner,'" & state & "',UTC_TIMESTAMP(6)-INTERVAL 3 DAY,UTC_TIMESTAMP(6)-INTERVAL 2 DAY," &
                "UTC_TIMESTAMP(6)" & If(expired, "-INTERVAL 1 DAY,", "+INTERVAL 5 DAY,") &
                If(state = "CONSUMED", "UTC_TIMESTAMP(6)", "NULL") & "," & If(state = "REVOKED", "UTC_TIMESTAMP(6)", "NULL") & ")", f)
        End If
        CartPriceRevalidationHelper.Mode = "" : CartPriceRevalidationHelper.Calls = 0
        Return f
    End Function
    Private Function Seed(conn As MySqlConnection, f As Fixture, source As String, quantity As Decimal,
                          Optional article As Integer = 1) As Integer
        Dim login As Integer = If(source = "account", f.Account.LoginId, 0)
        Dim token As String = If(source = "account", "", If(source = "legacy", f.Legacy, f.Persistent))
        Using cmd As New MySqlCommand("INSERT INTO carrello (LoginId,SessionId,ArticoliId,TCId,Qnt,NListino,Prezzo,PrezzoIvato) " &
            "VALUES (@login,@token,@article,-1,@q,1,999,999)", conn)
            cmd.Parameters.AddWithValue("@login", login) : cmd.Parameters.AddWithValue("@token", token)
            cmd.Parameters.AddWithValue("@q", quantity) : cmd.Parameters.AddWithValue("@article", article)
            cmd.ExecuteNonQuery()
            Return CInt(cmd.LastInsertedId)
        End Using
    End Function
    Private Function Merge(f As Fixture) As CartOwnershipMergeResult
        Return CartOwnershipService.ExecuteMerge(f.Context, f.Account.LoginId, f.Account.Listino, _cs)
    End Function
    Private Function Count(conn As MySqlConnection, f As Fixture, predicate As String) As Integer
        Return Convert.ToInt32(Sql(conn, "SELECT COUNT(*) FROM carrello WHERE " & predicate, f), CultureInfo.InvariantCulture)
    End Function
    Private Function Quantity(conn As MySqlConnection, f As Fixture) As Decimal
        Return Convert.ToDecimal(Sql(conn, "SELECT COALESCE(SUM(Qnt),0) FROM carrello WHERE LoginId=@login", f), CultureInfo.InvariantCulture)
    End Function
    Private Function Status(conn As MySqlConnection, f As Fixture) As String
        Return Convert.ToString(Sql(conn, "SELECT Status FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND OwnerToken=@owner", f))
    End Function
    Private Function ExpiredCookie(ctx As HttpContext) As Boolean
        Dim cookie = ctx.Response.Cookies(PersistentAnonymousCartOwnerService.CookieName)
        Return cookie IsNot Nothing AndAlso cookie.Expires < DateTime.UtcNow AndAlso cookie.Path = "/" AndAlso
            cookie.Secure AndAlso cookie.HttpOnly AndAlso cookie.SameSite = SameSiteMode.Lax AndAlso String.IsNullOrEmpty(cookie.Domain)
    End Function
    Private Sub Success(conn As MySqlConnection, f As Fixture, expected As Decimal, code As String)
        Check(code & "_SUCCESS", Merge(f).Succeeded)
        Check(code & "_QUANTITY", Quantity(conn, f) = expected)
        Check(code & "_SOURCES_EMPTY", Count(conn, f, "BINARY SessionId=@owner OR BINARY SessionId=@legacy") = 0)
        Check(code & "_CONSUMED", Status(conn, f) = "CONSUMED")
        Check(code & "_COOKIE_EXPIRED", ExpiredCookie(f.Context))
        Check(code & "_AUTHORITATIVE_PRICES", Count(conn, f, "LoginId=@login AND (Prezzo<>10 OR PrezzoIvato<>12.2 OR NListino<>2 OR SessionId<>'')") = 0)
        Check(code & "_TOMBSTONE", Convert.ToInt32(Sql(conn, "SELECT COUNT(*) FROM carrello_anonimo_persistenza " &
            "WHERE OwnerToken=@owner AND AziendeId=@company AND ConsumedUtc=LastActivityUtc " &
            "AND RevokedUtc IS NULL AND ExpiresUtc=ConsumedUtc+INTERVAL 30 DAY", f)) = 1)
    End Sub
    Private Sub RegistryFailure(conn As MySqlConnection, duplicate As Boolean, Optional inconsistent As Boolean = False)
        Dim f = Create(conn) : Seed(conn, f, "persistent", 1) : Seed(conn, f, "legacy", 2)
        Dim outcome = CartTransactionRetryPolicy.Execute(Of CartOwnershipMergeResult)(_cs, IsolationLevel.Serializable,
            "synthetic-registry-failure", "none",
            Function(c As MySqlConnection, t As MySqlTransaction) As CartTransactionWorkResult(Of CartOwnershipMergeResult)
                ' Temporary table is visible only to this scratch connection; no runtime fault hook.
                Sql(c, "CREATE TEMPORARY TABLE carrello_anonimo_persistenza (AziendeId INT,OwnerToken VARCHAR(50)" &
                    If(duplicate OrElse inconsistent, ",Status VARCHAR(8),ConsumedUtc DATETIME(6),RevokedUtc DATETIME(6),ExpiresUtc DATETIME(6)", "") & ")", Nothing, t)
                Try
                    If duplicate Then
                        For i As Integer = 1 To 2
                            Sql(c, "INSERT INTO carrello_anonimo_persistenza VALUES (@company,@owner,'ACTIVE',NULL,NULL,UTC_TIMESTAMP(6)+INTERVAL 5 DAY)", f, t)
                        Next
                    ElseIf inconsistent Then
                        Sql(c, "INSERT INTO carrello_anonimo_persistenza VALUES (@company,@owner,'CONSUMED',NULL,NULL,UTC_TIMESTAMP(6)+INTERVAL 5 DAY)", f, t)
                    End If
                    Return CartOwnershipService.MergeAttempt(f.Context, f.Account.LoginId, c, t)
                Finally
                    Sql(c, "DROP TEMPORARY TABLE carrello_anonimo_persistenza", Nothing, t)
                End Try
            End Function)
        Dim code As String = If(inconsistent, "INCONSISTENT_REGISTRY", If(duplicate, "DUPLICATE_REGISTRY", "REGISTRY_DB_ERROR"))
        Check(code & "_FAILED", Not outcome.Succeeded AndAlso Not outcome.IsIndeterminate)
        Check(code & "_NO_FALLBACK", Quantity(conn, f) = 0 AndAlso Count(conn, f, "BINARY SessionId=@legacy") = 1)
        Check(code & "_ACTIVE_PRESERVED", Status(conn, f) = "ACTIVE" AndAlso Count(conn, f, "BINARY SessionId=@owner") = 1)
        Check(code & "_COOKIE_RETAINED", f.Context.Response.Cookies.Count = 0)
        If Not duplicate AndAlso Not inconsistent Then Check(code & "_MYSQL_1054", outcome.MySqlNumber = 1054)
    End Sub
    Private Sub Ambiguous(conn As MySqlConnection, committed As Boolean)
        Dim f = Create(conn) : Seed(conn, f, "persistent", 2)
        Using tx = conn.BeginTransaction(IsolationLevel.Serializable)
            Dim work = CartOwnershipService.MergeAttempt(f.Context, f.Account.LoginId, conn, tx)
            Check("AMBIGUOUS_WORK_COMPLETE", work.ShouldCommit)
            If committed Then tx.Commit() Else tx.Rollback()
        End Using
        PersistentAnonymousCartLoginMergeService.CleanupCookie(f.Context, True, CartTransactionExecutionStatus.Indeterminate)
        Check("INDETERMINATE_COOKIE_RETAINED", f.Context.Response.Cookies.Count = 0)
        Check("INDETERMINATE_DB_TRUTH", Status(conn, f) = If(committed, "CONSUMED", "ACTIVE"))
        f.Context = Context(f)
        Check("INDETERMINATE_NEXT_REQUEST_SUCCESS", Merge(f).Succeeded)
        Check("INDETERMINATE_NO_DUPLICATION", Quantity(conn, f) = 2 AndAlso Status(conn, f) = "CONSUMED")
    End Sub
    Public Function Main() As Integer
        AddHandler AppDomain.CurrentDomain.AssemblyResolve, Function(sender, args)
            Dim name = New AssemblyName(args.Name).Name
            If Not System.Text.RegularExpressions.Regex.IsMatch(name, "^[A-Za-z0-9_.-]+$") Then Return Nothing
            Dim file = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, name & ".dll")
            Return If(IO.File.Exists(file), Assembly.LoadFrom(file), Nothing)
        End Function
        _cs = Console.ReadLine()
        Try
            Dim builder As New MySqlConnectionStringBuilder(_cs)
            If builder.Server <> "127.0.0.1" OrElse builder.Port <> 3307 OrElse builder.Database <> "ks_integration" Then Throw New InvalidOperationException("SCRATCH_ONLY")
            Using conn As New MySqlConnection(_cs)
                conn.Open()
                Check("SCRATCH_DATADIR", Convert.ToString(Sql(conn, "SELECT @@datadir")).Replace("/", "\").StartsWith("C:\Temp\KeepStoreIntegration\mysql\data", StringComparison.OrdinalIgnoreCase))
                _scratchVerified = True
                Check("SCRATCH_CART_BASELINE_EMPTY", Convert.ToInt32(Sql(conn, "SELECT COUNT(*) FROM carrello")) = 0)
                Check("SCRATCH_REGISTRY_BASELINE_EMPTY", Convert.ToInt32(Sql(conn, "SELECT COUNT(*) FROM carrello_anonimo_persistenza")) = 0)
                Dim f = Create(conn) : Seed(conn, f, "persistent", 2) : Success(conn, f, 2, "EMPTY_ACCOUNT_ACTIVE_TRANSFER")
                f = Create(conn) : Seed(conn, f, "persistent", 2)
                Dim accountRow = Seed(conn, f, "account", 3)
                Success(conn, f, 5, "ACCOUNT_DEDUP")
                Check("ACCOUNT_CANONICAL_PREFERRED", Convert.ToInt32(Sql(conn, "SELECT MIN(ID) FROM carrello WHERE LoginId=@login", f)) = accountRow)
                f = Create(conn) : Seed(conn, f, "persistent", 1, 1) : Seed(conn, f, "persistent", 2, 2) : Seed(conn, f, "account", 3)
                Success(conn, f, 6, "MULTIPLE_KSC2_ROWS") : Check("TWO_ARTICLE_KEYS", Count(conn, f, "LoginId=@login") = 2)
                f = Create(conn) : Seed(conn, f, "persistent", 2) : Seed(conn, f, "legacy", 3) : Seed(conn, f, "account", 4)
                Success(conn, f, 9, "MULTI_SOURCE")
                Dim first = Merge(f)
                Check("SAME_REQUEST_CACHE", Object.ReferenceEquals(first, Merge(f)) AndAlso Quantity(conn, f) = 9)
                f.Context = Context(f) : Check("SECOND_REQUEST_CONSUMED_NOOP", Merge(f).Succeeded AndAlso Quantity(conn, f) = 9)
                Check("CONSUMED_NOOP_COOKIE_EXPIRED", ExpiredCookie(f.Context))
                f = Create(conn) : f.Cookie = Nothing : f.Context = Context(f) : Seed(conn, f, "legacy", 2)
                Check("KSC1_ONLY", Merge(f).Succeeded AndAlso Quantity(conn, f) = 2 AndAlso Status(conn, f) = "ACTIVE")
                Check("NO_COOKIE_NO_SET_COOKIE", f.Context.Response.Cookies.Count = 0)
                f = Create(conn) : Success(conn, f, 0, "ACTIVE_EMPTY_CONSUMED")
                For Each stale As String In New String() {"CONSUMED", "REVOKED", "EXPIRED", "NOT_FOUND", "MALFORMED"}
                    f = Create(conn, If(stale = "EXPIRED" OrElse stale = "MALFORMED", "ACTIVE", stale), stale = "EXPIRED")
                    Seed(conn, f, "persistent", 5) : Seed(conn, f, "legacy", 2)
                    If stale = "MALFORMED" Then f.Cookie = "v2.invalid" : f.Context = Context(f) : Seed(conn, f, "legacy", 2)
                    Check(stale & "_KSC1_SUCCESS", Merge(f).Succeeded AndAlso Quantity(conn, f) = 2)
                    Check(stale & "_NO_KSC2_RECLAIM", Count(conn, f, "BINARY SessionId=@owner") = 1)
                    Check(stale & "_COOKIE_EXPIRED", ExpiredCookie(f.Context))
                Next
                RegistryFailure(conn, False, True) : RegistryFailure(conn, False) : RegistryFailure(conn, True)
                f = Create(conn) : Seed(conn, f, "account", 3) : Seed(conn, f, "persistent", 2) : Seed(conn, f, "legacy", 1)
                CartPriceRevalidationHelper.Mode = "blocking"
                Check("REVALIDATION_ROLLBACK", Not Merge(f).Succeeded AndAlso Quantity(conn, f) = 3 AndAlso Count(conn, f, "BINARY SessionId=@owner OR BINARY SessionId=@legacy") = 2 AndAlso Status(conn, f) = "ACTIVE")
                Check("REVALIDATION_COOKIE_RETAINED", f.Context.Response.Cookies.Count = 0)
                f = Create(conn) : Seed(conn, f, "account", 9999999D) : Seed(conn, f, "persistent", 9999999D)
                Check("MERGE_FAILURE_ROLLBACK", Not Merge(f).Succeeded AndAlso Quantity(conn, f) = 9999999D AndAlso Status(conn, f) = "ACTIVE")
                f = Create(conn) : Seed(conn, f, "persistent", 2)
                Dim propertyInfo = GetType(System.Collections.Specialized.NameObjectCollectionBase).GetProperty("IsReadOnly", BindingFlags.Instance Or BindingFlags.NonPublic)
                propertyInfo.SetValue(f.Context.Response.Cookies, True, Nothing)
                Try
                    Check("COOKIE_FAILURE_STILL_SUCCESS", Merge(f).Succeeded AndAlso Quantity(conn, f) = 2 AndAlso Status(conn, f) = "CONSUMED")
                    Check("COOKIE_FAILURE_SANITIZED_LOG", KeepStoreLog.CleanupFailures = 1)
                Finally
                    propertyInfo.SetValue(f.Context.Response.Cookies, False, Nothing)
                End Try
                f.Context = Context(f) : Check("COOKIE_FAILURE_NEXT_REQUEST_CLEANUP", Merge(f).Succeeded AndAlso ExpiredCookie(f.Context) AndAlso Quantity(conn, f) = 2)
                Ambiguous(conn, False) : Ambiguous(conn, True)
                f = Create(conn) : Seed(conn, f, "account", 3) : Seed(conn, f, "persistent", 2)
                CartPriceRevalidationHelper.Mode = "deadlock"
                Success(conn, f, 5, "DEADLOCK_RETRY") : Check("DEADLOCK_TWO_ATTEMPTS", CartPriceRevalidationHelper.Calls = 2)
                f = Create(conn) : Seed(conn, f, "persistent", 5)
                f.Account.CompanyId = 2 : f.Context = Context(f) : Seed(conn, f, "legacy", 2)
                Check("CROSS_COMPANY_NO_RECLAIM", Merge(f).Succeeded AndAlso Quantity(conn, f) = 2 AndAlso Count(conn, f, "BINARY SessionId=@owner") = 1)
                Dim secret As Byte() = Nothing
                Try
                    Check("CROSS_DB_COOKIE_DECODE", PersistentAnonymousCartOwnerService.TryDecodeCookie(f.Cookie, secret))
                    Check("CROSS_DATABASE_OWNER_DIFFERS", PersistentAnonymousCartOwnerService.DeriveOwnerToken("synthetic-other-db", 1, secret) <> f.Persistent)
                Finally
                    If secret IsNot Nothing Then Array.Clear(secret, 0, secret.Length)
                End Try
                f = Create(conn) : f.Account.IsCanonicalMutationHost = False : Seed(conn, f, "legacy", 1)
                Check("INVALID_SCOPE_FAIL_CLOSED", Not Merge(f).Succeeded AndAlso Quantity(conn, f) = 0)
                Check("ZERO_DOCUMENTS", Convert.ToInt32(Sql(conn, "SELECT COUNT(*) FROM documenti")) = 0)
                Check("ZERO_ORDER_IDEMPOTENCY", Convert.ToInt32(Sql(conn, "SELECT COUNT(*) FROM ordini_web_idempotenza")) = 0)
                Check("ZERO_REAL_ACCOUNTS", Convert.ToInt32(Sql(conn, "SELECT COUNT(*) FROM login")) = 0)
            End Using
            Console.WriteLine("TOTAL_LOGIN_MERGE_PASS=" & _passed) : Return 0
        Catch ex As Exception
            Console.WriteLine("FAIL LOGIN_MERGE TYPE=" & ex.GetType().Name)
            If TypeOf ex Is MySqlException Then Console.WriteLine("DIAGNOSTIC MYSQL=" & DirectCast(ex, MySqlException).Number)
            Dim loadError As FileLoadException = TryCast(ex, FileLoadException)
            If loadError IsNot Nothing AndAlso loadError.FileName IsNot Nothing Then
                Console.WriteLine("DIAGNOSTIC ASSEMBLY=" & New AssemblyName(loadError.FileName).Name)
                Console.WriteLine("DIAGNOSTIC VERSION=" & New AssemblyName(loadError.FileName).Version.ToString())
            End If
            If TypeOf ex Is InvalidOperationException AndAlso System.Text.RegularExpressions.Regex.IsMatch(ex.Message, "^[A-Z0-9_]+$") Then Console.WriteLine("CODE=" & ex.Message)
            Return 1
        Finally
            If _scratchVerified Then
                Using conn As New MySqlConnection(_cs)
                    conn.Open()
                    For Each owner As String In _owners
                        Using cmd As New MySqlCommand("DELETE FROM carrello WHERE COALESCE(LoginId,0)<=0 AND BINARY SessionId=@owner; " &
                            "DELETE FROM carrello_anonimo_persistenza WHERE BINARY OwnerToken=@owner", conn)
                            cmd.Parameters.AddWithValue("@owner", owner) : cmd.ExecuteNonQuery()
                        End Using
                    Next
                    For Each login As Integer In _logins
                        Using cmd As New MySqlCommand("DELETE FROM carrello WHERE LoginId=@login", conn)
                            cmd.Parameters.AddWithValue("@login", login) : cmd.ExecuteNonQuery()
                        End Using
                    Next
                End Using
            End If
            _cs = Nothing
        End Try
    End Function
End Module
