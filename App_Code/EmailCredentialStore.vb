Imports System
Imports System.Globalization
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web

Public NotInheritable Class EmailCredentialReadResult
    Implements IDisposable

    Private _secretBytes As Byte()
    Public Property State As EmailCredentialState
    Public Property Code As String

    Friend Sub SetSecret(ByVal value As Byte())
        If value Is Nothing Then Return
        _secretBytes = DirectCast(value.Clone(), Byte())
    End Sub

    Friend Function UseSecret(Of TResult)(ByVal callback As Func(Of String, TResult)) As TResult
        If State <> EmailCredentialState.Found OrElse _secretBytes Is Nothing OrElse callback Is Nothing Then
            Throw New InvalidOperationException("EMAIL_CREDENTIAL_NOT_AVAILABLE")
        End If

        Dim secret As String = Encoding.UTF8.GetString(_secretBytes)
        Try
            Return callback(secret)
        Finally
            secret = Nothing
        End Try
    End Function

    Public Sub Dispose() Implements IDisposable.Dispose
        If _secretBytes IsNot Nothing Then
            Array.Clear(_secretBytes, 0, _secretBytes.Length)
            _secretBytes = Nothing
        End If
    End Sub
End Class

Public Interface IEmailCredentialStore
    Function Read(ByVal credentialReference As String,
                  ByVal databaseIdentity As String,
                  ByVal aziendaId As Integer,
                  ByVal purpose As String) As EmailCredentialReadResult
End Interface

Friend NotInheritable Class EmailCredentialReferenceParts
    Public Property DatabaseIdentity As String
    Public Property AziendaId As Integer
    Public Property Purpose As String
    Public Property Token As String
End Class

Public NotInheritable Class DpapiEmailCredentialStore
    Implements IEmailCredentialStore

    Public Const DefaultRoot As String = "C:\ProgramData\KeepStore\EmailCredentials"
    Private Const ReferencePrefix As String = "dpapi-v1"
    Private Shared ReadOnly Header As Byte() = Encoding.ASCII.GetBytes("KSEMAIL1")
    Private Shared ReadOnly ReferencePattern As New Regex("^dpapi-v1:([0-9a-f]{64}):([1-9][0-9]{0,9}):(TRANSACTIONAL|MARKETING):([0-9a-f]{32})$", RegexOptions.CultureInvariant Or RegexOptions.Compiled)

    Private ReadOnly _rootPath As String
    Private ReadOnly _webRootPath As String

    Public Sub New()
        Me.New(DefaultRoot)
    End Sub

    Public Sub New(ByVal rootPath As String)
        Me.New(rootPath, Convert.ToString(HttpRuntime.AppDomainAppPath))
    End Sub

    Friend Sub New(ByVal rootPath As String, ByVal webRootPath As String)
        If String.IsNullOrWhiteSpace(rootPath) Then Throw New ArgumentException("EMAIL_CREDENTIAL_ROOT_REQUIRED", "rootPath")
        _rootPath = Path.GetFullPath(rootPath)
        _webRootPath = Convert.ToString(webRootPath)
    End Sub

    Public Function Read(ByVal credentialReference As String,
                         ByVal databaseIdentity As String,
                         ByVal aziendaId As Integer,
                         ByVal purpose As String) As EmailCredentialReadResult Implements IEmailCredentialStore.Read
        Dim result As New EmailCredentialReadResult()
        Dim parts As EmailCredentialReferenceParts = Nothing
        If Not TryParseReference(credentialReference, parts) Then
            result.State = EmailCredentialState.Invalid
            result.Code = "CREDENTIAL_REFERENCE_INVALID"
            Return result
        End If

        If Not String.Equals(parts.DatabaseIdentity, Convert.ToString(databaseIdentity).Trim().ToLowerInvariant(), StringComparison.Ordinal) OrElse
           parts.AziendaId <> aziendaId OrElse
           Not String.Equals(parts.Purpose, Convert.ToString(purpose).Trim().ToUpperInvariant(), StringComparison.Ordinal) Then
            result.State = EmailCredentialState.Invalid
            result.Code = "CREDENTIAL_SCOPE_MISMATCH"
            Return result
        End If

        If Not IsRootOutsideWebApplication(_rootPath, _webRootPath) Then
            result.State = EmailCredentialState.Unavailable
            result.Code = "CREDENTIAL_ROOT_NOT_EXTERNAL"
            Return result
        End If

        Dim credentialPath As String
        Try
            credentialPath = BuildCredentialPath(_rootPath, parts)
        Catch
            result.State = EmailCredentialState.Invalid
            result.Code = "CREDENTIAL_PATH_INVALID"
            Return result
        End Try

        If Not File.Exists(credentialPath) Then
            result.State = EmailCredentialState.Missing
            result.Code = "CREDENTIAL_FILE_MISSING"
            Return result
        End If

        Dim protectedBytes As Byte() = Nothing
        Dim clearBytes As Byte() = Nothing
        Try
            Dim envelope As Byte() = File.ReadAllBytes(credentialPath)
            If envelope.Length <= Header.Length OrElse Not HasHeader(envelope) Then
                result.State = EmailCredentialState.Invalid
                result.Code = "CREDENTIAL_FORMAT_INVALID"
                Return result
            End If

            protectedBytes = New Byte(envelope.Length - Header.Length - 1) {}
            Buffer.BlockCopy(envelope, Header.Length, protectedBytes, 0, protectedBytes.Length)
            clearBytes = ProtectedData.Unprotect(protectedBytes, BuildEntropy(credentialReference), DataProtectionScope.LocalMachine)
            If clearBytes Is Nothing OrElse clearBytes.Length = 0 OrElse Array.IndexOf(clearBytes, CByte(0)) >= 0 Then
                result.State = EmailCredentialState.Invalid
                result.Code = "CREDENTIAL_PAYLOAD_INVALID"
                Return result
            End If

            result.State = EmailCredentialState.Found
            result.Code = "CREDENTIAL_FOUND"
            result.SetSecret(clearBytes)
            Return result
        Catch ex As CryptographicException
            result.State = EmailCredentialState.Invalid
            result.Code = "CREDENTIAL_DPAPI_INVALID"
            Return result
        Catch ex As UnauthorizedAccessException
            result.State = EmailCredentialState.Unavailable
            result.Code = "CREDENTIAL_ACCESS_DENIED"
            Return result
        Catch ex As IOException
            result.State = EmailCredentialState.Unavailable
            result.Code = "CREDENTIAL_IO_UNAVAILABLE"
            Return result
        Catch
            result.State = EmailCredentialState.Unavailable
            result.Code = "CREDENTIAL_UNAVAILABLE"
            Return result
        Finally
            If protectedBytes IsNot Nothing Then Array.Clear(protectedBytes, 0, protectedBytes.Length)
            If clearBytes IsNot Nothing Then Array.Clear(clearBytes, 0, clearBytes.Length)
        End Try
    End Function

    Friend Shared Function CreateReference(ByVal databaseIdentity As String,
                                           ByVal aziendaId As Integer,
                                           ByVal purpose As String,
                                           ByVal token As String) As String
        Return ReferencePrefix & ":" & Convert.ToString(databaseIdentity).Trim().ToLowerInvariant() & ":" &
               aziendaId.ToString(CultureInfo.InvariantCulture) & ":" &
               Convert.ToString(purpose).Trim().ToUpperInvariant() & ":" &
               Convert.ToString(token).Trim().ToLowerInvariant()
    End Function

    Friend Shared Function ProtectForFixture(ByVal secretBytes As Byte(),
                                             ByVal credentialReference As String) As Byte()
        If secretBytes Is Nothing OrElse secretBytes.Length = 0 Then Throw New ArgumentException("EMAIL_CREDENTIAL_SECRET_REQUIRED", "secretBytes")
        Dim protectedBytes As Byte() = ProtectedData.Protect(secretBytes, BuildEntropy(credentialReference), DataProtectionScope.LocalMachine)
        Try
            Dim envelope(Header.Length + protectedBytes.Length - 1) As Byte
            Buffer.BlockCopy(Header, 0, envelope, 0, Header.Length)
            Buffer.BlockCopy(protectedBytes, 0, envelope, Header.Length, protectedBytes.Length)
            Return envelope
        Finally
            Array.Clear(protectedBytes, 0, protectedBytes.Length)
        End Try
    End Function

    Friend Shared Function TryParseReference(ByVal value As String,
                                             ByRef parts As EmailCredentialReferenceParts) As Boolean
        parts = Nothing
        Dim match As Match = ReferencePattern.Match(Convert.ToString(value).Trim())
        If Not match.Success Then Return False

        Dim parsedAziendaId As Integer
        If Not Integer.TryParse(match.Groups(2).Value, NumberStyles.None, CultureInfo.InvariantCulture, parsedAziendaId) OrElse parsedAziendaId <= 0 Then Return False

        parts = New EmailCredentialReferenceParts() With {
            .DatabaseIdentity = match.Groups(1).Value,
            .AziendaId = parsedAziendaId,
            .Purpose = match.Groups(3).Value,
            .Token = match.Groups(4).Value
        }
        Return True
    End Function

    Friend Shared Function BuildCredentialPath(ByVal rootPath As String,
                                               ByVal parts As EmailCredentialReferenceParts) As String
        If parts Is Nothing Then Throw New ArgumentNullException("parts")
        Dim rootFull As String = Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar) & Path.DirectorySeparatorChar
        Dim candidate As String = Path.GetFullPath(Path.Combine(rootFull,
                                                                parts.DatabaseIdentity,
                                                                parts.AziendaId.ToString(CultureInfo.InvariantCulture),
                                                                parts.Purpose,
                                                                parts.Token & ".bin"))
        If Not candidate.StartsWith(rootFull, StringComparison.OrdinalIgnoreCase) Then Throw New InvalidOperationException("EMAIL_CREDENTIAL_PATH_ESCAPE")
        Return candidate
    End Function

    Private Shared Function IsRootOutsideWebApplication(ByVal rootPath As String,
                                                        ByVal webRootPath As String) As Boolean
        Try
            Dim webRoot As String = Convert.ToString(webRootPath)
            If String.IsNullOrWhiteSpace(webRoot) Then Return True
            Dim webFull As String = Path.GetFullPath(webRoot).TrimEnd(Path.DirectorySeparatorChar) & Path.DirectorySeparatorChar
            Dim rootFull As String = Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar) & Path.DirectorySeparatorChar
            Return Not rootFull.StartsWith(webFull, StringComparison.OrdinalIgnoreCase)
        Catch
            Return False
        End Try
    End Function

    Private Shared Function HasHeader(ByVal envelope As Byte()) As Boolean
        For index As Integer = 0 To Header.Length - 1
            If envelope(index) <> Header(index) Then Return False
        Next
        Return True
    End Function

    Private Shared Function BuildEntropy(ByVal credentialReference As String) As Byte()
        Using digest As SHA256 = SHA256.Create()
            Return digest.ComputeHash(Encoding.UTF8.GetBytes("KeepStore.EmailCredential.v1|" & Convert.ToString(credentialReference)))
        End Using
    End Function
End Class
