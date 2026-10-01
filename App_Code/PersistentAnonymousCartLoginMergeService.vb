Option Strict On
Option Explicit On

Imports System
Imports System.Web
Imports MySql.Data.MySqlClient

Friend NotInheritable Class PersistentCartLoginSource
    Friend Property OwnerToken As String
    Friend Property DatabaseUtc As DateTime
    Friend Property State As PersistentAnonymousCartOwnerState
    Friend ReadOnly Property IsActive As Boolean
        Get
            Return State = PersistentAnonymousCartOwnerState.ACTIVE
        End Get
    End Property
End Class

' The account has already been locked. No separate connection or anonymous resolver.
Friend NotInheritable Class PersistentAnonymousCartLoginMergeService
    Private Sub New()
    End Sub

    Friend Shared Function Acquire(ByVal context As HttpContext, ByVal connection As MySqlConnection,
                                   ByVal transaction As MySqlTransaction,
                                   ByVal account As CartStorefrontOwnerScope) As PersistentCartLoginSource
        If account Is Nothing OrElse Not account.IsAuthenticated OrElse account.CompanyId <= 0 OrElse
           String.IsNullOrWhiteSpace(account.DatabaseScopeKey) OrElse Not account.IsCanonicalMutationHost Then
            Throw New InvalidOperationException("Invalid cart login scope.")
        End If
        Dim source As New PersistentCartLoginSource With {.State = PersistentAnonymousCartOwnerState.NO_COOKIE}
        Dim incoming As HttpCookie = context.Request.Cookies(PersistentAnonymousCartOwnerService.CookieName)
        If incoming Is Nothing Then Return source
        Dim secret As Byte() = Nothing
        Try
            If Not PersistentAnonymousCartOwnerService.TryDecodeCookie(incoming.Value, secret) Then
                source.State = PersistentAnonymousCartOwnerState.MALFORMED_COOKIE
                Return source
            End If
            source.OwnerToken = PersistentAnonymousCartOwnerService.DeriveOwnerToken(
                account.DatabaseScopeKey, account.CompanyId, secret)
        Finally
            If secret IsNot Nothing Then Array.Clear(secret, 0, secret.Length)
        End Try

        Dim found As Boolean, status As String = Nothing, consumed As Boolean, revoked As Boolean, expires As DateTime
        Using command As New MySqlCommand("SELECT Status,ConsumedUtc,RevokedUtc,ExpiresUtc " &
            "FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND OwnerToken=@owner FOR UPDATE", connection, transaction)
            AddScope(command, account.CompanyId, source.OwnerToken)
            Using reader As MySqlDataReader = command.ExecuteReader()
                found = reader.Read()
                If found Then
                    status = reader.GetString(0) : consumed = Not reader.IsDBNull(1) : revoked = Not reader.IsDBNull(2)
                    expires = DateTime.SpecifyKind(reader.GetDateTime(3), DateTimeKind.Utc)
                    If reader.Read() Then Throw New InvalidOperationException("Duplicate cart login registry.")
                End If
            End Using
        End Using
        source.DatabaseUtc = PersistentAnonymousCartMutationActivation.ReadDatabaseUtc(connection, transaction)
        If Not found Then
            source.State = PersistentAnonymousCartOwnerState.NOT_FOUND
            Return source
        End If
        Select Case status
            Case "ACTIVE"
                If consumed OrElse revoked Then Throw New InvalidOperationException("Inconsistent cart login registry.")
                source.State = If(expires > source.DatabaseUtc, PersistentAnonymousCartOwnerState.ACTIVE,
                                  PersistentAnonymousCartOwnerState.EXPIRED)
            Case "CONSUMED"
                If Not consumed OrElse revoked Then Throw New InvalidOperationException("Inconsistent cart login registry.")
                source.State = PersistentAnonymousCartOwnerState.CONSUMED
            Case "REVOKED"
                If consumed OrElse Not revoked Then Throw New InvalidOperationException("Inconsistent cart login registry.")
                source.State = PersistentAnonymousCartOwnerState.REVOKED
            Case Else
                Throw New InvalidOperationException("Unknown cart login registry state.")
        End Select
        Return source
    End Function

    Friend Shared Sub Consume(ByVal connection As MySqlConnection, ByVal transaction As MySqlTransaction,
                             ByVal source As PersistentCartLoginSource, ByVal companyId As Integer)
        If source Is Nothing OrElse Not source.IsActive Then Return
        Using command As New MySqlCommand("UPDATE carrello_anonimo_persistenza " &
            "SET Status='CONSUMED',ConsumedUtc=@now,RevokedUtc=NULL,LastActivityUtc=@now,ExpiresUtc=@expires " &
            "WHERE AziendeId=@company AND OwnerToken=@owner AND Status='ACTIVE' " &
            "AND ConsumedUtc IS NULL AND RevokedUtc IS NULL AND ExpiresUtc>@now", connection, transaction)
            AddScope(command, companyId, source.OwnerToken)
            command.Parameters.Add("@now", MySqlDbType.DateTime).Value = source.DatabaseUtc
            command.Parameters.Add("@expires", MySqlDbType.DateTime).Value = source.DatabaseUtc.AddDays(30)
            If command.ExecuteNonQuery() <> 1 Then Throw New InvalidOperationException("Cart login registry consumption failed.")
        End Using
        Using command As New MySqlCommand("SELECT Status,ConsumedUtc,RevokedUtc,LastActivityUtc,ExpiresUtc " &
            "FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND OwnerToken=@owner", connection, transaction)
            AddScope(command, companyId, source.OwnerToken)
            Using reader As MySqlDataReader = command.ExecuteReader()
                If Not reader.Read() OrElse reader.GetString(0) <> "CONSUMED" OrElse reader.IsDBNull(1) OrElse
                   Not reader.IsDBNull(2) OrElse reader.GetDateTime(1) <> source.DatabaseUtc OrElse
                   reader.GetDateTime(3) <> source.DatabaseUtc OrElse reader.GetDateTime(4) <> source.DatabaseUtc.AddDays(30) Then
                    Throw New InvalidOperationException("Cart login registry verification failed.")
                End If
                If reader.Read() Then Throw New InvalidOperationException("Duplicate cart login registry.")
            End Using
        End Using
    End Sub

    Friend Shared Sub CleanupCookie(ByVal context As HttpContext, ByVal wasPresent As Boolean,
                                   ByVal status As CartTransactionExecutionStatus)
        If Not wasPresent OrElse status <> CartTransactionExecutionStatus.Succeeded Then Return
        Try
            If Not PersistentAnonymousCartMutationActivation.CanStageCookie(context) Then
                Throw New InvalidOperationException("Cart login cookie response is unavailable.")
            End If
            context.Response.Cookies.Set(New HttpCookie(PersistentAnonymousCartOwnerService.CookieName, String.Empty) With {
                .Path = "/", .Secure = True, .HttpOnly = True, .SameSite = SameSiteMode.Lax,
                .Expires = New DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc)})
        Catch
            ' Post-commit only: never compensate a completed merge or log exception details.
            KeepStoreLog.Info("cart-ownership", "persistent-login-cookie-cleanup-deferred", context)
        End Try
    End Sub

    Private Shared Sub AddScope(ByVal command As MySqlCommand, ByVal companyId As Integer, ByVal owner As String)
        command.Parameters.Add("@company", MySqlDbType.Int32).Value = companyId
        command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = owner
    End Sub
End Class
