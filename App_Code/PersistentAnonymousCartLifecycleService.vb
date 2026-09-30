Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Friend Enum PersistentCartLifecycleChange
    None
    Refresh
    Revoke
End Enum

Friend NotInheritable Class PersistentCartLifecycleCandidate
    Friend Property Source As CartStorefrontOwnerScope
    Friend Property CookieValue As String
    Friend Property DatabaseUtc As DateTime
    Friend Property ExpiresUtc As DateTime
    Friend Property Change As PersistentCartLifecycleChange
    Friend Property CookieStaged As Boolean
End Class

' No login merge/cleanup scheduler. Reads may expire a stale cookie, never write DB.
Friend NotInheritable Class PersistentAnonymousCartLifecycleService
    Private Const SuppressCleanupKey As String = "KeepStore:PersistentCart:SuppressReadCookieCleanup"

    Private Sub New()
    End Sub

    Friend Shared Function Prepare(ByVal context As HttpContext) As PersistentCartLifecycleCandidate
        If context Is Nothing OrElse context.Request Is Nothing OrElse
           Not String.Equals(context.Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then Return Nothing
        Dim source As CartStorefrontOwnerScope = CartStorefrontOwnerContext.ResolveForMutation(context)
        If source Is Nothing OrElse source.LoginId <> 0 OrElse source.SessionId Is Nothing OrElse
           Not source.SessionId.StartsWith("ksc2_", StringComparison.Ordinal) Then Return Nothing
        Dim incoming As HttpCookie = context.Request.Cookies(PersistentAnonymousCartOwnerService.CookieName)
        Dim secret As Byte() = Nothing
        If incoming Is Nothing OrElse Not PersistentAnonymousCartOwnerService.TryDecodeCookie(incoming.Value, secret) Then
            Throw New InvalidOperationException("Persistent cart lifecycle cookie is unavailable.")
        End If
        Try
            If Not String.Equals(PersistentAnonymousCartOwnerService.DeriveOwnerToken(
                                 source.DatabaseScopeKey, source.CompanyId, secret), source.SessionId, StringComparison.Ordinal) Then
                Throw New InvalidOperationException("Persistent cart lifecycle owner mismatch.")
            End If
            Return New PersistentCartLifecycleCandidate With {.Source = source, .CookieValue = incoming.Value}
        Finally
            Array.Clear(secret, 0, secret.Length)
        End Try
    End Function

    ' Registry lock precedes every cart row lock/mutation for an existing ksc2.
    ' Read the DB clock AFTER acquiring the lock (it may have waited).
    Friend Shared Function BeginAttempt(ByVal context As HttpContext,
                                        ByVal connection As MySqlConnection,
                                        ByVal transaction As MySqlTransaction,
                                        ByVal candidate As PersistentCartLifecycleCandidate) As PersistentCartActivationSnapshot
        If candidate Is Nothing Then Return Nothing
        RemoveStagedCookie(context, candidate)
        candidate.Change = PersistentCartLifecycleChange.None
        If Not PersistentAnonymousCartMutationActivation.CanStageCookie(context) Then
            Throw New InvalidOperationException("Persistent cart lifecycle response is unavailable.")
        End If
        Dim valid As Boolean = False, expiry As DateTime
        Using command As New MySqlCommand(
            "SELECT Status,ConsumedUtc,RevokedUtc,ExpiresUtc FROM carrello_anonimo_persistenza " &
            "WHERE AziendeId=@company AND OwnerToken=@owner FOR UPDATE", connection, transaction)
            AddOwnerParameters(command, candidate)
            Using reader As MySqlDataReader = command.ExecuteReader()
                If reader.Read() Then
                    valid = String.Equals(reader.GetString(0), "ACTIVE", StringComparison.Ordinal) AndAlso
                            reader.IsDBNull(1) AndAlso reader.IsDBNull(2)
                    expiry = DateTime.SpecifyKind(reader.GetDateTime(3), DateTimeKind.Utc)
                    If reader.Read() Then valid = False
                End If
            End Using
        End Using
        candidate.DatabaseUtc = PersistentAnonymousCartMutationActivation.ReadDatabaseUtc(connection, transaction)
        If Not valid OrElse expiry <= candidate.DatabaseUtc Then
            Throw New InvalidOperationException("Persistent cart registry is not active.")
        End If
        Return PersistentAnonymousCartMutationActivation.CaptureOwner(connection, transaction, candidate.Source)
    End Function

    Friend Shared Function Apply(ByVal context As HttpContext,
                                 ByVal connection As MySqlConnection,
                                 ByVal transaction As MySqlTransaction,
                                 ByVal candidate As PersistentCartLifecycleCandidate,
                                 ByVal before As PersistentCartActivationSnapshot) As Boolean
        If candidate Is Nothing OrElse before Is Nothing Then Return False
        Dim after As PersistentCartActivationSnapshot =
            PersistentAnonymousCartMutationActivation.CaptureOwner(connection, transaction, candidate.Source)
        If String.Equals(before.Fingerprint, after.Fingerprint, StringComparison.Ordinal) Then Return False
        candidate.Change = If(before.RowCount > 0 AndAlso after.RowCount = 0,
                              PersistentCartLifecycleChange.Revoke, PersistentCartLifecycleChange.Refresh)
        candidate.ExpiresUtc = candidate.DatabaseUtc.AddDays(30)
        Using command As New MySqlCommand(
            "UPDATE carrello_anonimo_persistenza SET LastActivityUtc=@now,ExpiresUtc=@expires," &
            "Status=@status,RevokedUtc=@revoked,ConsumedUtc=NULL " &
            "WHERE AziendeId=@company AND OwnerToken=@owner AND Status='ACTIVE' " &
            "AND ConsumedUtc IS NULL AND RevokedUtc IS NULL AND ExpiresUtc>@now", connection, transaction)
            AddOwnerParameters(command, candidate)
            command.Parameters.Add("@now", MySqlDbType.DateTime).Value = candidate.DatabaseUtc
            command.Parameters.Add("@expires", MySqlDbType.DateTime).Value = candidate.ExpiresUtc
            Dim revoke As Boolean = candidate.Change = PersistentCartLifecycleChange.Revoke
            command.Parameters.Add("@status", MySqlDbType.VarChar, 8).Value = If(revoke, "REVOKED", "ACTIVE")
            command.Parameters.Add("@revoked", MySqlDbType.DateTime).Value = If(revoke, CType(candidate.DatabaseUtc, Object), DBNull.Value)
            If command.ExecuteNonQuery() <> 1 Then
                Throw New InvalidOperationException("Persistent cart lifecycle update failed.")
            End If
        End Using
        If Not PersistentAnonymousCartMutationActivation.CanStageCookie(context) Then
            Throw New InvalidOperationException("Persistent cart lifecycle cannot stage its cookie.")
        End If
        ' Keep the current value even on expiration: response cookies can be read
        ' back by ASP.NET in this request/retry. Expiry alone deletes it in browsers.
        context.Response.Cookies.Set(NewCookie(candidate.CookieValue,
            If(candidate.Change = PersistentCartLifecycleChange.Revoke, candidate.DatabaseUtc.AddDays(-1), candidate.ExpiresUtc)))
        candidate.CookieStaged = True
        Return True
    End Function

    Friend Shared Sub FinalizeExecution(ByVal context As HttpContext,
                                       ByVal candidate As PersistentCartLifecycleCandidate,
                                       ByVal status As CartTransactionExecutionStatus)
        If candidate Is Nothing Then Return
        If status = CartTransactionExecutionStatus.Succeeded Then Return
        If status = CartTransactionExecutionStatus.Indeterminate AndAlso
           candidate.Change = PersistentCartLifecycleChange.Refresh AndAlso candidate.CookieStaged Then Return
        RemoveStagedCookie(context, candidate)
        If status = CartTransactionExecutionStatus.Indeterminate AndAlso candidate.Change = PersistentCartLifecycleChange.Revoke Then
            ' Do not let same-response read-back turn an ambiguous revoke into a
            ' cookie deletion. A fresh request establishes the registry's reality.
            context.Items(SuppressCleanupKey) = True
        End If
    End Sub

    Friend Shared Sub HandleReadResolution(ByVal context As HttpContext,
                                          ByVal resolution As PersistentAnonymousCartOwnerResolution)
        If resolution Is Nothing OrElse resolution.State = PersistentAnonymousCartOwnerState.TECHNICAL_ERROR Then
            Throw New HttpException(503, "Carrello temporaneamente non disponibile.")
        End If
        Select Case resolution.State
            Case PersistentAnonymousCartOwnerState.MALFORMED_COOKIE, PersistentAnonymousCartOwnerState.NOT_FOUND,
                 PersistentAnonymousCartOwnerState.EXPIRED, PersistentAnonymousCartOwnerState.CONSUMED,
                 PersistentAnonymousCartOwnerState.REVOKED
                If context Is Nothing OrElse context.Items(SuppressCleanupKey) IsNot Nothing OrElse
                   Not PersistentAnonymousCartMutationActivation.CanStageCookie(context) Then Return
                Try
                    context.Response.Cookies.Set(NewCookie(String.Empty, New DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc)))
                Catch
                    ' Header cleanup is best-effort; no registry creation or DML.
                End Try
        End Select
    End Sub

    Private Shared Function NewCookie(ByVal value As String, ByVal expiry As DateTime) As HttpCookie
        Return New HttpCookie(PersistentAnonymousCartOwnerService.CookieName, value) With {
            .Path = "/", .Secure = True, .HttpOnly = True, .SameSite = SameSiteMode.Lax, .Expires = expiry}
    End Function

    Private Shared Sub RemoveStagedCookie(ByVal context As HttpContext,
                                         ByVal candidate As PersistentCartLifecycleCandidate)
        If Not candidate.CookieStaged Then Return
        context.Response.Cookies.Remove(PersistentAnonymousCartOwnerService.CookieName)
        candidate.CookieStaged = False
    End Sub

    Private Shared Sub AddOwnerParameters(ByVal command As MySqlCommand, ByVal candidate As PersistentCartLifecycleCandidate)
        command.Parameters.Add("@company", MySqlDbType.Int32).Value = candidate.Source.CompanyId
        command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = candidate.Source.SessionId
    End Sub
End Class
