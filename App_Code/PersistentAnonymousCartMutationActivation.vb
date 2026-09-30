Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient

Friend NotInheritable Class PersistentCartActivationCandidate
    Friend Property Source As CartStorefrontOwnerScope
    Friend Property Target As CartStorefrontOwnerScope
    Friend Property CookieValue As String
    Friend Property CreatedUtc As DateTime
    Friend Property ExpiresUtc As DateTime
End Class

Friend NotInheritable Class PersistentCartActivationSnapshot
    Friend Property Fingerprint As String
    Friend Property RowCount As Integer
End Class

' This boundary is mutation-only. The existing owner service remains a pure reader.
Friend NotInheritable Class PersistentAnonymousCartMutationActivation
    Private Const CandidateItemKey As String = "KeepStore:PersistentCart:ActivationCandidate"
    Private Const CommittedOwnerItemKey As String = "KeepStore:PersistentCart:CommittedOwner"
    Private Const AnonymousPredicate As String = "COALESCE(LoginId,0)<=0 AND BINARY SessionId=@owner"

    Private Sub New()
    End Sub

    ' Called BEFORE Execute/retry, not from the transaction callback. The encoded
    ' secret is request-local only; neither it nor the raw bytes enter Session/DB.
    Friend Shared Function Prepare(ByVal context As HttpContext) As PersistentCartActivationCandidate
        If context Is Nothing OrElse context.Request Is Nothing OrElse
           Not String.Equals(context.Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then Return Nothing
        Dim source As CartStorefrontOwnerScope = CartStorefrontOwnerContext.ResolveForMutation(context)
        If source Is Nothing OrElse source.LoginId <> 0 OrElse
           Not IsOwnerToken(source.SessionId, "ksc1_") Then Return Nothing
        Dim operation As String = Nothing, payload As String = Nothing
        If Not CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(context, operation, payload) Then Return Nothing
        Select Case operation
            Case "cart-add", "pdp-bundle", "cart-set", "cart-set-row", "cart-set-batch", "cart-remove-row"
            Case Else
                Return Nothing
        End Select
        ' A __Host- cookie cannot establish ownership over insecure transport.
        If Not context.Request.IsSecureConnection Then Return Nothing
        Dim existing As PersistentCartActivationCandidate = TryCast(context.Items(CandidateItemKey), PersistentCartActivationCandidate)
        If existing IsNot Nothing Then
            If Not String.Equals(existing.Source.OwnerScopeKey, source.OwnerScopeKey, StringComparison.Ordinal) Then
                Throw New InvalidOperationException("Persistent cart activation source changed.")
            End If
            Return existing
        End If
        Dim secret(31) As Byte
        Try
            Using generator As RandomNumberGenerator = RandomNumberGenerator.Create()
                generator.GetBytes(secret)
            End Using
            Dim ownerToken As String = PersistentAnonymousCartOwnerService.DeriveOwnerToken(
                source.DatabaseScopeKey, source.CompanyId, secret)
            Dim now As DateTime = DateTime.UtcNow
            now = New DateTime(now.Ticks - (now.Ticks Mod TimeSpan.TicksPerSecond), DateTimeKind.Utc)
            Dim candidate As New PersistentCartActivationCandidate With {
                .Source = source,
                .Target = New CartStorefrontOwnerScope With {
                    .DatabaseScopeKey = source.DatabaseScopeKey, .CompanyId = source.CompanyId,
                    .LoginId = 0, .SessionId = ownerToken, .Listino = source.Listino,
                    .IsCanonicalMutationHost = source.IsCanonicalMutationHost,
                    .OwnerScopeKey = CartStorefrontScopePolicy.BuildOwnerScopeKey(
                        source.DatabaseScopeKey, source.CompanyId, 0, ownerToken)},
                .CookieValue = "v2." & Convert.ToBase64String(secret).TrimEnd("="c).Replace("+", "-").Replace("/", "_"),
                .CreatedUtc = now, .ExpiresUtc = now.AddDays(30)}
            context.Items(CandidateItemKey) = candidate
            Return candidate
        Finally
            Array.Clear(secret, 0, secret.Length)
        End Try
    End Function

    ' Exclude only ownership and volatile timestamps. A no-op quantity SET that
    ' merely rewrites DataOra is not a real mutation; commercial changes are.
    Friend Shared Function Capture(ByVal connection As MySqlConnection,
                                  ByVal transaction As MySqlTransaction,
                                  ByVal candidate As PersistentCartActivationCandidate) As PersistentCartActivationSnapshot
        If candidate Is Nothing Then Return Nothing
        Dim count As Integer = 0
        Dim serialized As New StringBuilder()
        Using command As New MySqlCommand("SELECT * FROM carrello WHERE " & AnonymousPredicate & " ORDER BY ID FOR UPDATE", connection, transaction)
            command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = candidate.Source.SessionId
            Using reader As MySqlDataReader = command.ExecuteReader()
                While reader.Read()
                    count += 1
                    For index As Integer = 0 To reader.FieldCount - 1
                        Dim name As String = reader.GetName(index)
                        If String.Equals(name, "DataOra", StringComparison.OrdinalIgnoreCase) OrElse
                           String.Equals(name, "SessionId", StringComparison.OrdinalIgnoreCase) OrElse
                           String.Equals(name, "LoginId", StringComparison.OrdinalIgnoreCase) Then Continue For
                        Dim value As String = If(reader.IsDBNull(index), Nothing, Convert.ToString(reader.GetValue(index), CultureInfo.InvariantCulture))
                        serialized.Append(name.Length).Append(":"c).Append(name).Append("="c)
                        If value Is Nothing Then
                            serialized.Append("null;")
                        Else
                            serialized.Append(value.Length).Append(":"c).Append(value).Append(";"c)
                        End If
                    Next
                    serialized.Append("|"c)
                End While
            End Using
        End Using
        Using sha As SHA256 = SHA256.Create()
            Return New PersistentCartActivationSnapshot With {
                .RowCount = count,
                .Fingerprint = Convert.ToBase64String(sha.ComputeHash(Encoding.UTF8.GetBytes(serialized.ToString())))}
        End Using
    End Function

    Friend Shared Function Activate(ByVal context As HttpContext,
                                   ByVal connection As MySqlConnection,
                                   ByVal transaction As MySqlTransaction,
                                   ByVal candidate As PersistentCartActivationCandidate,
                                   ByVal before As PersistentCartActivationSnapshot) As Boolean
        If candidate Is Nothing OrElse before Is Nothing Then Return False
        Dim current As CartStorefrontOwnerScope = CartStorefrontOwnerContext.ResolveForMutation(context)
        If current Is Nothing OrElse Not String.Equals(current.OwnerScopeKey, candidate.Source.OwnerScopeKey, StringComparison.Ordinal) Then
            Throw New InvalidOperationException("Persistent cart activation owner mismatch.")
        End If
        Dim after As PersistentCartActivationSnapshot = Capture(connection, transaction, candidate)
        If after.RowCount <= 0 OrElse String.Equals(before.Fingerprint, after.Fingerprint, StringComparison.Ordinal) Then Return False
        If CountRows(connection, transaction, candidate.Target.SessionId) <> 0 Then
            Throw New InvalidOperationException("Persistent cart activation target is not empty.")
        End If
        Using command As New MySqlCommand(
            "INSERT INTO carrello_anonimo_persistenza " &
            "(AziendeId,OwnerToken,Status,CreatedUtc,LastActivityUtc,ExpiresUtc,ConsumedUtc,RevokedUtc) " &
            "VALUES (@company,@owner,'ACTIVE',@created,@created,@expires,NULL,NULL)", connection, transaction)
            command.Parameters.Add("@company", MySqlDbType.Int32).Value = candidate.Source.CompanyId
            command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = candidate.Target.SessionId
            command.Parameters.Add("@created", MySqlDbType.DateTime).Value = candidate.CreatedUtc
            command.Parameters.Add("@expires", MySqlDbType.DateTime).Value = candidate.ExpiresUtc
            If command.ExecuteNonQuery() <> 1 Then Throw New InvalidOperationException("Persistent cart registry insert failed.")
        End Using
        Using command As New MySqlCommand("UPDATE carrello SET SessionId=@target WHERE " & AnonymousPredicate, connection, transaction)
            command.Parameters.Add("@target", MySqlDbType.VarChar, 50).Value = candidate.Target.SessionId
            command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = candidate.Source.SessionId
            If command.ExecuteNonQuery() <> after.RowCount Then Throw New InvalidOperationException("Persistent cart rekey count mismatch.")
        End Using
        If CountRows(connection, transaction, candidate.Source.SessionId) <> 0 OrElse
           CountRows(connection, transaction, candidate.Target.SessionId) <> after.RowCount Then
            Throw New InvalidOperationException("Persistent cart rekey verification failed.")
        End If
        Using command As New MySqlCommand(
            "SELECT COUNT(*) FROM carrello_anonimo_persistenza WHERE AziendeId=@company AND BINARY OwnerToken=@owner " &
            "AND Status='ACTIVE' AND ConsumedUtc IS NULL AND RevokedUtc IS NULL", connection, transaction)
            command.Parameters.Add("@company", MySqlDbType.Int32).Value = candidate.Source.CompanyId
            command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = candidate.Target.SessionId
            If Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture) <> 1 Then
                Throw New InvalidOperationException("Persistent cart registry verification failed.")
            End If
        End Using
        Dim operation As String = Nothing, payload As String = Nothing
        If Not CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(context, operation, payload) OrElse
           Not CartMutationIdempotencyService.AuthorizeAnonymousOwnerTransitionForCurrentIntent(
               context, operation, payload, candidate.Target) Then
            Throw New InvalidOperationException("Persistent cart intent transition was rejected.")
        End If
        Return True
    End Function

    ' Caller supplies true only for this attempt's activation AND a certain commit.
    Friend Shared Sub PublishAfterCommit(ByVal context As HttpContext,
                                       ByVal candidate As PersistentCartActivationCandidate,
                                       ByVal succeeded As Boolean,
                                       ByVal activated As Boolean)
        If Not succeeded OrElse Not activated OrElse candidate Is Nothing Then Return
        context.Items(CommittedOwnerItemKey) = candidate.Target
        Dim cookie As New HttpCookie(PersistentAnonymousCartOwnerService.CookieName, candidate.CookieValue) With {
            .Path = "/", .Secure = True, .HttpOnly = True, .SameSite = SameSiteMode.Lax,
            .Expires = candidate.ExpiresUtc}
        context.Response.Cookies.Set(cookie)
    End Sub

    Friend Shared Function CommittedOwner(ByVal context As HttpContext,
                                         ByVal databaseScope As String,
                                         ByVal companyId As Integer) As CartStorefrontOwnerScope
        Dim owner As CartStorefrontOwnerScope = TryCast(context.Items(CommittedOwnerItemKey), CartStorefrontOwnerScope)
        If owner Is Nothing OrElse owner.LoginId <> 0 OrElse owner.CompanyId <> companyId OrElse
           Not String.Equals(owner.DatabaseScopeKey, databaseScope, StringComparison.OrdinalIgnoreCase) Then Return Nothing
        Return owner
    End Function

    Private Shared Function CountRows(ByVal connection As MySqlConnection,
                                     ByVal transaction As MySqlTransaction,
                                     ByVal ownerToken As String) As Integer
        Using command As New MySqlCommand("SELECT COUNT(*) FROM carrello WHERE " & AnonymousPredicate, connection, transaction)
            command.Parameters.Add("@owner", MySqlDbType.VarChar, 50).Value = ownerToken
            Return Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture)
        End Using
    End Function

    Private Shared Function IsOwnerToken(ByVal value As String, ByVal prefix As String) As Boolean
        If value Is Nothing OrElse value.Length <> 48 OrElse Not value.StartsWith(prefix, StringComparison.Ordinal) Then Return False
        For index As Integer = prefix.Length To value.Length - 1
            Dim ch As Char = value(index)
            If Not ((ch >= "A"c AndAlso ch <= "Z"c) OrElse (ch >= "a"c AndAlso ch <= "z"c) OrElse
                    (ch >= "0"c AndAlso ch <= "9"c) OrElse ch = "-"c OrElse ch = "_"c) Then Return False
        Next
        Return True
    End Function
End Class
