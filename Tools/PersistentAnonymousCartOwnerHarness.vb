Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient

Module PersistentAnonymousCartOwnerHarness
    Private _passed As Integer

    Private Sub AssertState(ByVal actual As PersistentAnonymousCartOwnerResolution,
                            ByVal expected As PersistentAnonymousCartOwnerState,
                            ByVal code As String)
        If actual.State <> expected Then Throw New Exception(code & " FAILED")
        _passed += 1
        Console.WriteLine("PASS " & code)
    End Sub

    Private Sub AssertTrue(ByVal condition As Boolean, ByVal code As String)
        If Not condition Then Throw New Exception(code & " FAILED")
        _passed += 1
        Console.WriteLine("PASS " & code)
    End Sub

    Private Function CookieFor(ByVal seed As Byte) As String
        Dim secret(31) As Byte
        For index As Integer = 0 To secret.Length - 1
            secret(index) = CByte((CInt(seed) + index) Mod 256)
        Next
        Return "v2." & Convert.ToBase64String(secret).TrimEnd("="c).Replace("+", "-").Replace("/", "_")
    End Function

    Private Function TokenFor(ByVal cookie As String, ByVal scope As String, ByVal companyId As Integer) As String
        Dim raw As Byte() = Convert.FromBase64String(cookie.Substring(3).Replace("-", "+").Replace("_", "/") & "=")
        Try
            Return PersistentAnonymousCartOwnerService.DeriveOwnerToken(scope, companyId, raw)
        Finally
            Array.Clear(raw, 0, raw.Length)
        End Try
    End Function

    Private Sub Execute(ByVal connection As MySqlConnection, ByVal sql As String)
        Using command As New MySqlCommand(sql, connection)
            command.ExecuteNonQuery()
        End Using
    End Sub

    Private Sub InsertRow(ByVal connection As MySqlConnection, ByVal companyId As Integer,
                          ByVal token As String, ByVal status As String, ByVal expiryDays As Integer)
        Const sql As String = "INSERT INTO `carrello_anonimo_persistenza` " &
                              "(`AziendeId`,`OwnerToken`,`Status`,`CreatedUtc`,`LastActivityUtc`,`ExpiresUtc`,`ConsumedUtc`,`RevokedUtc`) " &
                              "VALUES (@company,@token,@status,UTC_TIMESTAMP(6)-INTERVAL 2 DAY," &
                              "UTC_TIMESTAMP(6)-INTERVAL 1 DAY,UTC_TIMESTAMP(6)+INTERVAL @days DAY," &
                              "IF(@status='CONSUMED',UTC_TIMESTAMP(6),NULL)," &
                              "IF(@status='REVOKED',UTC_TIMESTAMP(6),NULL))"
        Using command As New MySqlCommand(sql, connection)
            command.Parameters.Add("@company", MySqlDbType.Int32).Value = companyId
            command.Parameters.Add("@token", MySqlDbType.VarChar, 50).Value = token
            command.Parameters.Add("@status", MySqlDbType.VarChar, 8).Value = status
            command.Parameters.Add("@days", MySqlDbType.Int32).Value = expiryDays
            command.ExecuteNonQuery()
        End Using
    End Sub

    Private Function ReadTimes(ByVal connection As MySqlConnection, ByVal token As String) As String
        Using command As New MySqlCommand(
            "SELECT CONCAT(DATE_FORMAT(`LastActivityUtc`,'%Y-%m-%d %H:%i:%s.%f'),'|'," &
            "DATE_FORMAT(`ExpiresUtc`,'%Y-%m-%d %H:%i:%s.%f')) " &
            "FROM `carrello_anonimo_persistenza` WHERE `OwnerToken`=@token", connection)
            command.Parameters.Add("@token", MySqlDbType.VarChar, 50).Value = token
            Return Convert.ToString(command.ExecuteScalar())
        End Using
    End Function

    Sub Main()
        Dim admin As String = "Server=localhost;Protocol=pipe;Pipe Name=KS_CART_OWNER_PIPE;Uid=root;SslMode=None;Connection Timeout=5;"
        Dim databaseName As String = "ks_cart_owner_" & Guid.NewGuid().ToString("N").Substring(0, 12)
        Dim secondDatabaseName As String = "ks_cart_owner_" & Guid.NewGuid().ToString("N").Substring(0, 12)
        Using server As New MySqlConnection(admin)
            server.Open()
            Using command As New MySqlCommand("SELECT @@datadir", server)
                Dim dataDirectory As String = Convert.ToString(command.ExecuteScalar())
                If dataDirectory.IndexOf("KeepStore_PersistentCart_Scratch_1A_", StringComparison.OrdinalIgnoreCase) < 0 Then
                    Throw New Exception("SCRATCH_SERVER_NOT_CONFIRMED")
                End If
            End Using
            Execute(server, "CREATE DATABASE `" & databaseName & "` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin")
            Try
                Execute(server, "CREATE DATABASE `" & secondDatabaseName & "` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin")
                Dim lab As String = admin & "Database=" & databaseName & ";"
                Using connection As New MySqlConnection(lab)
                    connection.Open()
                    Execute(connection, "CREATE TABLE `carrello_anonimo_persistenza` (" &
                        "`Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY," &
                        "`AziendeId` INT NOT NULL," &
                        "`OwnerToken` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL," &
                        "`Status` VARCHAR(8) NOT NULL," &
                        "`CreatedUtc` DATETIME(6) NOT NULL,`LastActivityUtc` DATETIME(6) NOT NULL," &
                        "`ExpiresUtc` DATETIME(6) NOT NULL,`ConsumedUtc` DATETIME(6) NULL,`RevokedUtc` DATETIME(6) NULL," &
                        "UNIQUE KEY `UX_tenant_owner` (`AziendeId`,`OwnerToken`))")

                    Dim scope As String = "synthetic-db-scope-a"
                    Dim cookie As String = CookieFor(11)
                    Dim token As String = TokenFor(cookie, scope, 1)
                    Dim request As New HttpRequest(String.Empty, "https://localhost/", String.Empty)
                    Dim response As New HttpResponse(New StringWriter())
                    Dim context As New HttpContext(request, response)
                    AssertState(PersistentAnonymousCartOwnerService.Resolve(context, scope, 1),
                                PersistentAnonymousCartOwnerState.NO_COOKIE, "HTTP_NO_COOKIE")
                    AssertTrue(response.Cookies.Count = 0, "HTTP_READ_NO_PERSISTENT_SET_COOKIE")
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(Nothing, scope, 1, lab),
                                PersistentAnonymousCartOwnerState.NO_COOKIE, "NO_COOKIE")
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue("v2.invalid", scope, 1, lab),
                                PersistentAnonymousCartOwnerState.MALFORMED_COOKIE, "MALFORMED_COOKIE")
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue("v2." & New String("A"c, 43) & "=", scope, 1, lab),
                                PersistentAnonymousCartOwnerState.MALFORMED_COOKIE, "PADDING_REJECTED")
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie.Substring(0, 45) & "B", scope, 1, lab),
                                PersistentAnonymousCartOwnerState.MALFORMED_COOKIE, "NONCANONICAL_BASE64_REJECTED")
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie, scope, 1, lab),
                                PersistentAnonymousCartOwnerState.NOT_FOUND, "NOT_FOUND")
                    InsertRow(connection, 1, token, "ACTIVE", 10)
                    Dim before As String = ReadTimes(connection, token)
                    Dim active As PersistentAnonymousCartOwnerResolution =
                        PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie, scope, 1, lab)
                    AssertState(active, PersistentAnonymousCartOwnerState.ACTIVE, "ACTIVE_UNEXPIRED")
                    AssertTrue(String.Equals(active.OwnerToken, token, StringComparison.Ordinal), "ACTIVE_EXACT_OWNER")
                    AssertTrue(ReadTimes(connection, token) = before, "READ_NO_ACTIVITY_OR_EXPIRY_WRITE")
                    AssertTrue(token.Length = 48 AndAlso token.StartsWith("ksc2_", StringComparison.Ordinal) AndAlso
                               CartStorefrontScopePolicy.IsAnonymousOwnerToken(token), "KSC2_FORMAT")
                    AssertTrue(Not String.Equals(TokenFor(cookie, scope, 2), token, StringComparison.Ordinal),
                               "COMPANY_SEPARATION")
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie, scope, 2, lab),
                                PersistentAnonymousCartOwnerState.NOT_FOUND, "CROSS_COMPANY_NOT_FOUND")
                    Dim companyTwoToken As String = TokenFor(cookie, scope, 2)
                    InsertRow(connection, 2, companyTwoToken, "ACTIVE", 10)
                    Dim companyTwo As PersistentAnonymousCartOwnerResolution =
                        PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie, scope, 2, lab)
                    AssertState(companyTwo, PersistentAnonymousCartOwnerState.ACTIVE, "SECOND_COMPANY_ACTIVE")
                    AssertTrue(Not String.Equals(companyTwo.OwnerToken, token, StringComparison.Ordinal),
                               "ACTIVE_COMPANIES_HAVE_DISTINCT_OWNERS")
                    AssertTrue(Not String.Equals(TokenFor(cookie, "synthetic-db-scope-b", 1), token, StringComparison.Ordinal),
                               "DATABASE_SCOPE_SEPARATION")
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie, "synthetic-db-scope-b", 1, lab),
                                PersistentAnonymousCartOwnerState.NOT_FOUND, "CROSS_DATABASE_SCOPE_NOT_FOUND")
                    Dim secondLab As String = admin & "Database=" & secondDatabaseName & ";"
                    Using secondConnection As New MySqlConnection(secondLab)
                        secondConnection.Open()
                        Execute(secondConnection, "CREATE TABLE `carrello_anonimo_persistenza` (" &
                            "`Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY," &
                            "`AziendeId` INT NOT NULL," &
                            "`OwnerToken` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL," &
                            "`Status` VARCHAR(8) NOT NULL," &
                            "`CreatedUtc` DATETIME(6) NOT NULL,`LastActivityUtc` DATETIME(6) NOT NULL," &
                            "`ExpiresUtc` DATETIME(6) NOT NULL,`ConsumedUtc` DATETIME(6) NULL,`RevokedUtc` DATETIME(6) NULL," &
                            "UNIQUE KEY `UX_tenant_owner` (`AziendeId`,`OwnerToken`))")
                        Dim databaseTwoToken As String = TokenFor(cookie, "synthetic-db-scope-b", 1)
                        InsertRow(secondConnection, 1, databaseTwoToken, "ACTIVE", 10)
                        Dim databaseTwo As PersistentAnonymousCartOwnerResolution =
                            PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie, "synthetic-db-scope-b", 1, secondLab)
                        AssertState(databaseTwo, PersistentAnonymousCartOwnerState.ACTIVE, "SECOND_DATABASE_ACTIVE")
                        AssertTrue(Not String.Equals(databaseTwo.OwnerToken, token, StringComparison.Ordinal),
                                   "ACTIVE_DATABASES_HAVE_DISTINCT_OWNERS")
                        AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie, scope, 1, secondLab),
                                    PersistentAnonymousCartOwnerState.NOT_FOUND, "CROSS_DATABASE_REGISTRY_ISOLATED")
                    End Using

                    Dim expiredCookie As String = CookieFor(22)
                    InsertRow(connection, 1, TokenFor(expiredCookie, scope, 1), "ACTIVE", -1)
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(expiredCookie, scope, 1, lab),
                                PersistentAnonymousCartOwnerState.EXPIRED, "EXPIRED")
                    Dim consumedCookie As String = CookieFor(33)
                    InsertRow(connection, 1, TokenFor(consumedCookie, scope, 1), "CONSUMED", 10)
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(consumedCookie, scope, 1, lab),
                                PersistentAnonymousCartOwnerState.CONSUMED, "CONSUMED")
                    Dim revokedCookie As String = CookieFor(44)
                    InsertRow(connection, 1, TokenFor(revokedCookie, scope, 1), "REVOKED", 10)
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(revokedCookie, scope, 1, lab),
                                PersistentAnonymousCartOwnerState.REVOKED, "REVOKED")
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(cookie, scope, 1,
                                admin & "Database=nonexistent_synthetic_registry;"),
                                PersistentAnonymousCartOwnerState.TECHNICAL_ERROR, "TECHNICAL_ERROR_FAIL_CLOSED")

                    Dim caseCookie As String = CookieFor(55)
                    Dim caseToken As String = TokenFor(caseCookie, scope, 1)
                    Dim flipped As Char = If(caseToken(5) >= "A"c AndAlso caseToken(5) <= "Z"c,
                                             Char.ToLowerInvariant(caseToken(5)), Char.ToUpperInvariant(caseToken(5)))
                    Dim altered As String = caseToken.Substring(0, 5) & flipped & caseToken.Substring(6)
                    InsertRow(connection, 1, altered, "ACTIVE", 10)
                    AssertState(PersistentAnonymousCartOwnerService.ResolveCookieValue(caseCookie, scope, 1, lab),
                                PersistentAnonymousCartOwnerState.NOT_FOUND, "CASE_SENSITIVE_LOOKUP")

                    Dim ksc1 As String = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(scope, 1, "synthetic-session")
                    AssertTrue(CartStorefrontScopePolicy.IsAnonymousOwnerToken(ksc1) AndAlso
                               ksc1 = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(scope, 1, "synthetic-session"),
                               "KSC1_BASELINE_UNCHANGED")
                    AssertTrue(CartStorefrontScopePolicy.BuildOwnerScopeKey(scope, 1, 0, token).Contains("anonymous:ksc2_"),
                               "KSC2_OWNER_SCOPE_ACCEPTED")
                    AssertTrue(CartStorefrontScopePolicy.BuildOwnerScopeKey(scope, 1, 71, token).EndsWith("login:71"),
                               "AUTHENTICATED_SCOPE_UNCHANGED")
                End Using
            Finally
                Execute(server, "DROP DATABASE `" & databaseName & "`")
                Execute(server, "DROP DATABASE IF EXISTS `" & secondDatabaseName & "`")
            End Try
        End Using
        Console.WriteLine("SCRATCH_CASES_PASS=" & _passed.ToString())
    End Sub
End Module
