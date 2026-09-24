Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Collections.Specialized
Imports System.Configuration
Imports System.Globalization
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Threading
Imports System.Web
Imports System.Web.Script.Serialization

' Inactive foundation: callers must supply the authoritative, public SEO state.
' No product, price, promotion, network, or scheduling logic belongs here.
Public Enum IndexNowConfigurationStatus
    NotConfigured
    Disabled
    Invalid
    Ready
End Enum

Public NotInheritable Class IndexNowHostConfiguration
    Public Property Status As IndexNowConfigurationStatus
    Public Property CanonicalHost As String
    Public Property KeyLocation As String
    Public Property Key As String
End Class

Public NotInheritable Class IndexNowCandidate
    Public Property Url As String
    Public Property Fingerprint As String
End Class

Public NotInheritable Class IndexNowPendingChange
    Public Property Url As String
    Public Property Operation As String
    Public Property TargetFingerprint As String
    Public Property Revision As String
    Public Property CreatedUtc As DateTime
    Public Property UpdatedUtc As DateTime
    Public Property AttemptCount As Integer
    Public Property NextAttemptUtc As Nullable(Of DateTime)
End Class

Public NotInheritable Class IndexNowStateDocument
    Public Property Version As Integer
    Public Property Host As String
    Public Property Baseline As Dictionary(Of String, String)
    Public Property Pending As Dictionary(Of String, IndexNowPendingChange)
End Class

Public NotInheritable Class StorefrontIndexNowFoundation
    Private Const SchemaVersion As Integer = 1
    Private Const MaximumStateBytes As Long = 16L * 1024L * 1024L
    Private ReadOnly _root As String

    Public Sub New()
        Me.New(HttpContext.Current.Server.MapPath("~/App_Data/IndexNow"))
    End Sub

    Public Sub New(ByVal stateDirectory As String)
        If String.IsNullOrWhiteSpace(stateDirectory) Then Throw New ArgumentException("INDEXNOW_STATE_DIRECTORY_REQUIRED")
        _root = Path.GetFullPath(stateDirectory)
    End Sub

    Public Shared Function ResolveConfiguration(ByVal tenant As StorefrontSeoTenantIdentity) As IndexNowHostConfiguration
        Return ResolveConfiguration(tenant, ConfigurationManager.AppSettings)
    End Function

    ' The overload allows isolated tests; production always reads the existing app settings.
    Public Shared Function ResolveConfiguration(ByVal tenant As StorefrontSeoTenantIdentity,
                                                ByVal settings As NameValueCollection) As IndexNowHostConfiguration
        Dim result As New IndexNowHostConfiguration() With {.Status = IndexNowConfigurationStatus.NotConfigured}
        Dim host As String = ValidatedHost(tenant)
        If host.Length = 0 OrElse settings Is Nothing Then Return result
        result.CanonicalHost = host
        Try
        Dim prefix As String = "KeepStore.IndexNow."
        Dim enabled As String = settings(prefix & "Enabled." & host)
        If enabled Is Nothing Then Return result
        If String.Equals(enabled, "false", StringComparison.OrdinalIgnoreCase) Then
            result.Status = IndexNowConfigurationStatus.Disabled
            Return result
        End If
        If Not String.Equals(enabled, "true", StringComparison.OrdinalIgnoreCase) Then
            result.Status = IndexNowConfigurationStatus.Invalid
            Return result
        End If
        Dim key As String = settings(prefix & "Key." & host)
        Dim keyLocation As String = settings(prefix & "KeyLocation." & host)
        Dim location As Uri = Nothing
        If Not IsValidKey(key) OrElse
           Not Uri.TryCreate(keyLocation, UriKind.Absolute, location) OrElse location Is Nothing OrElse
           Not String.Equals(location.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) OrElse
           Not String.Equals(StorefrontCanonicalHostPolicy.NormalizeHost(location.DnsSafeHost), host, StringComparison.Ordinal) OrElse
           Not String.IsNullOrEmpty(location.UserInfo) OrElse location.Fragment.Length > 0 OrElse
           location.Query.Length > 0 OrElse
           Uri.UnescapeDataString(location.AbsolutePath).IndexOf("..", StringComparison.Ordinal) >= 0 OrElse
           Uri.UnescapeDataString(location.AbsolutePath).IndexOf("\", StringComparison.Ordinal) >= 0 OrElse
           Not location.AbsolutePath.EndsWith(".txt", StringComparison.OrdinalIgnoreCase) Then
            result.Status = IndexNowConfigurationStatus.Invalid
            Return result
        End If
        result.Key = key
        result.KeyLocation = location.AbsoluteUri
        result.Status = IndexNowConfigurationStatus.Ready
        Return result
        Catch ex As Exception
            result.Key = Nothing
            result.KeyLocation = Nothing
            result.Status = IndexNowConfigurationStatus.Invalid
            Return result
        End Try
    End Function

    Public Shared Function IsValidKey(ByVal key As String) As Boolean
        If key Is Nothing OrElse key.Length < 8 OrElse key.Length > 128 Then Return False
        For Each ch As Char In key
            If Not ((ch >= "a"c AndAlso ch <= "z"c) OrElse
                    (ch >= "A"c AndAlso ch <= "Z"c) OrElse
                    (ch >= "0"c AndAlso ch <= "9"c) OrElse ch = "-"c) Then Return False
        Next
        Return True
    End Function

    Public Shared Function TryCreateCandidate(ByVal tenant As StorefrontSeoTenantIdentity,
                                               ByVal canonicalUrl As String,
                                               ByVal fingerprint As String,
                                               ByVal isIndexable As Boolean,
                                               ByRef candidate As IndexNowCandidate) As Boolean
        candidate = Nothing
        If Not isIndexable OrElse ValidatedHost(tenant).Length = 0 OrElse
           Not IsValidFingerprint(fingerprint) OrElse String.IsNullOrWhiteSpace(canonicalUrl) Then Return False
        Dim uri As Uri = Nothing
        If Not Uri.TryCreate(canonicalUrl, UriKind.Absolute, uri) OrElse uri Is Nothing Then Return False
        If Not String.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) OrElse
           Not String.Equals(StorefrontCanonicalHostPolicy.NormalizeHost(uri.DnsSafeHost), tenant.CanonicalHost, StringComparison.Ordinal) OrElse
           Not String.IsNullOrEmpty(uri.UserInfo) OrElse uri.Fragment.Length > 0 OrElse
           canonicalUrl.IndexOf("#", StringComparison.Ordinal) >= 0 OrElse
           canonicalUrl.IndexOf("..", StringComparison.Ordinal) >= 0 OrElse
           StorefrontCanonicalHostPolicy.IsNoIndexPath(uri.AbsolutePath) Then Return False
        Dim rebuilt As String = StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenant, uri.PathAndQuery)
        If Not String.Equals(canonicalUrl, rebuilt, StringComparison.Ordinal) Then Return False
        candidate = New IndexNowCandidate() With {.Url = canonicalUrl, .Fingerprint = fingerprint.ToLowerInvariant()}
        Return True
    End Function

    ' Input MUST be the complete current public URL set for this host. Partial scans
    ' cannot distinguish an omitted URL from a deletion and must not call this API.
    Public Function TryReconcile(ByVal tenant As StorefrontSeoTenantIdentity,
                                 ByVal completeCurrent As IEnumerable(Of IndexNowCandidate),
                                 ByRef pendingCount As Integer,
                                 ByRef failureCode As String) As Boolean
        pendingCount = 0
        failureCode = String.Empty
        Dim host As String = ValidatedHost(tenant)
        If host.Length = 0 OrElse completeCurrent Is Nothing Then
            failureCode = "INDEXNOW_INPUT_INVALID"
            Return False
        End If
        Dim current As New Dictionary(Of String, String)(StringComparer.Ordinal)
        For Each item As IndexNowCandidate In completeCurrent
            Dim checked As IndexNowCandidate = Nothing
            If item Is Nothing OrElse Not TryCreateCandidate(tenant, item.Url, item.Fingerprint, True, checked) Then
                failureCode = "INDEXNOW_INPUT_INVALID"
                Return False
            End If
            If current.ContainsKey(checked.Url) Then
                failureCode = "INDEXNOW_INPUT_DUPLICATE"
                Return False
            End If
            current.Add(checked.Url, checked.Fingerprint)
        Next
        Return WithHostLock(host, Function(state)
                                      Dim now As DateTime = DateTime.UtcNow
                                      For Each pair As KeyValuePair(Of String, String) In current
                                          Dim oldFingerprint As String = Nothing
                                          Dim hasBaseline As Boolean = state.Baseline.TryGetValue(pair.Key, oldFingerprint)
                                          Dim existing As IndexNowPendingChange = Nothing
                                          Dim hasPending As Boolean = state.Pending.TryGetValue(pair.Key, existing)
                                          If hasBaseline AndAlso String.Equals(oldFingerprint, pair.Value, StringComparison.Ordinal) AndAlso Not hasPending Then Continue For
                                          Dim operation As String = If(hasBaseline, "Updated", "Added")
                                          If hasPending AndAlso String.Equals(existing.Operation, operation, StringComparison.Ordinal) AndAlso
                                             String.Equals(existing.TargetFingerprint, pair.Value, StringComparison.Ordinal) Then Continue For
                                          state.Pending(pair.Key) = NewPending(pair.Key, operation, pair.Value, now)
                                      Next
                                      Dim known As New HashSet(Of String)(state.Baseline.Keys, StringComparer.Ordinal)
                                      known.UnionWith(state.Pending.Keys)
                                      For Each url As String In known
                                          If current.ContainsKey(url) Then Continue For
                                          Dim existing As IndexNowPendingChange = Nothing
                                          If state.Pending.TryGetValue(url, existing) AndAlso String.Equals(existing.Operation, "Deleted", StringComparison.Ordinal) Then Continue For
                                          state.Pending(url) = NewPending(url, "Deleted", Nothing, now)
                                      Next
                                      Return True
                                  End Function, pendingCount, failureCode)
    End Function

    Public Function TryAcknowledge(ByVal tenant As StorefrontSeoTenantIdentity,
                                    ByVal canonicalUrl As String,
                                    ByVal revision As String,
                                    ByRef acknowledged As Boolean,
                                    ByRef failureCode As String) As Boolean
        acknowledged = False
        failureCode = String.Empty
        Dim host As String = ValidatedHost(tenant)
        Dim parsed As Uri = Nothing
        If host.Length = 0 OrElse String.IsNullOrEmpty(revision) OrElse
           Not Uri.TryCreate(canonicalUrl, UriKind.Absolute, parsed) OrElse parsed Is Nothing OrElse
           Not String.Equals(StorefrontCanonicalHostPolicy.NormalizeHost(parsed.DnsSafeHost), host, StringComparison.Ordinal) Then
            failureCode = "INDEXNOW_INPUT_INVALID"
            Return False
        End If
        Dim count As Integer = 0
        Dim didAck As Boolean = False
        Dim success As Boolean = WithHostLock(host, Function(state)
                                                         Dim item As IndexNowPendingChange = Nothing
                                                         If Not state.Pending.TryGetValue(canonicalUrl, item) OrElse
                                                            Not String.Equals(item.Revision, revision, StringComparison.Ordinal) Then Return False
                                                         If String.Equals(item.Operation, "Deleted", StringComparison.Ordinal) Then
                                                             state.Baseline.Remove(canonicalUrl)
                                                         Else
                                                             state.Baseline(canonicalUrl) = item.TargetFingerprint
                                                         End If
                                                         state.Pending.Remove(canonicalUrl)
                                                         didAck = True
                                                         Return True
                                                     End Function, count, failureCode)
        acknowledged = didAck
        Return success
    End Function

    Public Function TryReadState(ByVal tenant As StorefrontSeoTenantIdentity,
                                  ByRef state As IndexNowStateDocument,
                                  ByRef failureCode As String) As Boolean
        state = Nothing
        failureCode = String.Empty
        Dim host As String = ValidatedHost(tenant)
        If host.Length = 0 Then
            failureCode = "INDEXNOW_INPUT_INVALID"
            Return False
        End If
        Dim count As Integer = 0
        Dim snapshot As IndexNowStateDocument = Nothing
        Dim success As Boolean = WithHostLock(host, Function(loaded)
                                                         snapshot = loaded
                                                         Return False
                                                     End Function, count, failureCode)
        state = snapshot
        Return success
    End Function

    Public Function StateFilePath(ByVal tenant As StorefrontSeoTenantIdentity) As String
        Dim host As String = ValidatedHost(tenant)
        If host.Length = 0 Then Throw New ArgumentException("INDEXNOW_HOST_INVALID")
        Using sha As SHA256 = SHA256.Create()
            Dim bytes As Byte() = sha.ComputeHash(Encoding.UTF8.GetBytes(host))
            Return Path.Combine(_root, BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant() & ".json")
        End Using
    End Function

    Private Function WithHostLock(ByVal host As String,
                                  ByVal action As Func(Of IndexNowStateDocument, Boolean),
                                  ByRef pendingCount As Integer,
                                  ByRef failureCode As String) As Boolean
        Try
            Directory.CreateDirectory(_root)
            Dim tenant As New StorefrontSeoTenantIdentity() With {.CanonicalHost = host, .CanonicalBaseUrl = "https://" & host}
            Dim filePath As String = StateFilePath(tenant)
            Dim lockPath As String = filePath & ".lock"
            Dim lockStream As FileStream = Nothing
            For attempt As Integer = 0 To 79
                Try
                    lockStream = New FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None)
                    Exit For
                Catch ex As IOException
                    If attempt = 79 Then Throw
                    Thread.Sleep(25)
                End Try
            Next
            Using lockStream
                Dim state As IndexNowStateDocument = LoadState(filePath, host)
                Dim changed As Boolean = action(state)
                If changed Then SaveState(filePath, state)
                pendingCount = state.Pending.Count
            End Using
            Return True
        Catch ex As InvalidDataException
            failureCode = "INDEXNOW_STATE_CORRUPT"
        Catch ex As IOException
            failureCode = "INDEXNOW_STATE_IO"
        Catch ex As UnauthorizedAccessException
            failureCode = "INDEXNOW_STATE_ACCESS"
        Catch ex As Exception
            failureCode = "INDEXNOW_STATE_ERROR"
        End Try
        Return False
    End Function

    Private Shared Function LoadState(ByVal filePath As String, ByVal host As String) As IndexNowStateDocument
        If Not File.Exists(filePath) Then
            Return New IndexNowStateDocument() With {
                .Version = SchemaVersion, .Host = host,
                .Baseline = New Dictionary(Of String, String)(StringComparer.Ordinal),
                .Pending = New Dictionary(Of String, IndexNowPendingChange)(StringComparer.Ordinal)
            }
        End If
        If New FileInfo(filePath).Length > MaximumStateBytes Then Throw New InvalidDataException()
        Dim loaded As IndexNowStateDocument = Nothing
        Try
            Dim json As String = File.ReadAllText(filePath, Encoding.UTF8)
            Dim serializer As New JavaScriptSerializer() With {.MaxJsonLength = CInt(MaximumStateBytes)}
            loaded = serializer.Deserialize(Of IndexNowStateDocument)(json)
        Catch ex As Exception
            Throw New InvalidDataException("INDEXNOW_STATE_CORRUPT")
        End Try
        If loaded Is Nothing OrElse loaded.Version <> SchemaVersion OrElse
           Not String.Equals(loaded.Host, host, StringComparison.Ordinal) OrElse
           loaded.Baseline Is Nothing OrElse loaded.Pending Is Nothing Then Throw New InvalidDataException()
        For Each pair As KeyValuePair(Of String, String) In loaded.Baseline
            If Not IsValidStateUrl(pair.Key, host) OrElse Not IsValidFingerprint(pair.Value) Then Throw New InvalidDataException()
        Next
        For Each pair As KeyValuePair(Of String, IndexNowPendingChange) In loaded.Pending
            If Not IsValidStateUrl(pair.Key, host) OrElse pair.Value Is Nothing OrElse
               Not String.Equals(pair.Key, pair.Value.Url, StringComparison.Ordinal) OrElse
               String.IsNullOrEmpty(pair.Value.Revision) OrElse
               (pair.Value.Operation <> "Added" AndAlso pair.Value.Operation <> "Updated" AndAlso pair.Value.Operation <> "Deleted") OrElse
               (pair.Value.Operation <> "Deleted" AndAlso Not IsValidFingerprint(pair.Value.TargetFingerprint)) Then Throw New InvalidDataException()
        Next
        Return loaded
    End Function

    Private Shared Sub SaveState(ByVal filePath As String, ByVal state As IndexNowStateDocument)
        Dim tempPath As String = filePath & "." & Guid.NewGuid().ToString("N") & ".tmp"
        Try
            Dim serializer As New JavaScriptSerializer() With {.MaxJsonLength = CInt(MaximumStateBytes)}
            Dim data As Byte() = Encoding.UTF8.GetBytes(serializer.Serialize(state))
            If data.LongLength > MaximumStateBytes Then Throw New IOException("INDEXNOW_STATE_TOO_LARGE")
            Using output As New FileStream(tempPath, FileMode.CreateNew, FileAccess.Write, FileShare.None)
                output.Write(data, 0, data.Length)
                output.Flush(True)
            End Using
            If File.Exists(filePath) Then
                File.Replace(tempPath, filePath, Nothing)
            Else
                File.Move(tempPath, filePath)
            End If
        Finally
            If File.Exists(tempPath) Then File.Delete(tempPath)
        End Try
    End Sub

    Private Shared Function NewPending(ByVal url As String, ByVal operation As String,
                                       ByVal fingerprint As String, ByVal now As DateTime) As IndexNowPendingChange
        Return New IndexNowPendingChange() With {
            .Url = url, .Operation = operation, .TargetFingerprint = fingerprint,
            .Revision = Guid.NewGuid().ToString("N"), .CreatedUtc = now, .UpdatedUtc = now,
            .AttemptCount = 0, .NextAttemptUtc = Nothing
        }
    End Function

    Private Shared Function IsValidFingerprint(ByVal value As String) As Boolean
        If value Is Nothing OrElse value.Length <> 64 Then Return False
        For Each ch As Char In value
            If Not ((ch >= "0"c AndAlso ch <= "9"c) OrElse (ch >= "a"c AndAlso ch <= "f"c) OrElse
                    (ch >= "A"c AndAlso ch <= "F"c)) Then Return False
        Next
        Return True
    End Function

    Private Shared Function ValidatedHost(ByVal tenant As StorefrontSeoTenantIdentity) As String
        If tenant Is Nothing OrElse String.IsNullOrWhiteSpace(tenant.CanonicalHost) Then Return String.Empty
        Dim host As String = StorefrontCanonicalHostPolicy.NormalizeHost(tenant.CanonicalHost)
        Dim uri As Uri = Nothing
        If Not Uri.TryCreate(tenant.CanonicalBaseUrl, UriKind.Absolute, uri) OrElse uri Is Nothing OrElse
           Not String.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) OrElse
           Not String.Equals(uri.DnsSafeHost, host, StringComparison.OrdinalIgnoreCase) OrElse
           Not String.Equals(tenant.CanonicalHost, host, StringComparison.Ordinal) Then Return String.Empty
        Return host
    End Function

    Private Shared Function IsValidStateUrl(ByVal url As String, ByVal host As String) As Boolean
        Dim uri As Uri = Nothing
        Return Uri.TryCreate(url, UriKind.Absolute, uri) AndAlso uri IsNot Nothing AndAlso
               String.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(StorefrontCanonicalHostPolicy.NormalizeHost(uri.DnsSafeHost), host, StringComparison.Ordinal) AndAlso
               uri.UserInfo.Length = 0 AndAlso uri.Fragment.Length = 0
    End Function
End Class
