Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Security.Principal
Imports System.Text.RegularExpressions
Imports System.Xml

Public Module EmailTransportConnectionVerifier
    Private Const ExitSuccess As Integer = 0
    Private Const ExitConfiguration As Integer = 10
    Private Const ExitProfileUnavailable As Integer = 20
    Private Const ExitCredential As Integer = 21
    Private Const ExitTls As Integer = 30
    Private Const ExitAuthentication As Integer = 31
    Private Const ExitTimeout As Integer = 32
    Private Const ExitTransport As Integer = 33
    Private Const ExitInternal As Integer = 40

    Private NotInheritable Class VerifierOptions
        Public Property AziendaId As Integer
        Public Property Purpose As String
        Public Property ApplicationRoot As String
        Public Property ConnectionStringName As String
        Public Property CredentialRoot As String
    End Class

    Private NotInheritable Class SanitizedTelemetrySink
        Implements IEmailTransportTelemetrySink

        Public Sub Record(ByVal line As String) Implements IEmailTransportTelemetrySink.Record
            ' VerifyConnection already returns the complete sanitized result. The local
            ' administrative runner deliberately creates no secondary log channel.
        End Sub
    End Class

    Public Function Main(ByVal args As String()) As Integer
        Dim correlationId As String = Guid.NewGuid().ToString("N")
        Try
            Dim options As VerifierOptions = ParseOptions(args)
            Dim connectionString As String = LoadConnectionString(options.ApplicationRoot,
                                                                   options.ConnectionStringName)

            Dim databaseIdentity As String = New EmailDatabaseIdentityProvider().GetIdentity(connectionString)
            If Not Regex.IsMatch(databaseIdentity, "^[0-9a-f]{64}$", RegexOptions.CultureInvariant) Then
                Return WriteFailure("TECHNICAL_ERROR", "RESOLVER", "CONFIGURATION",
                                    "EMAIL_VERIFY_DATABASE_IDENTITY_INVALID", correlationId,
                                    ExitConfiguration)
            End If

            Dim transport As New MailKitEmailTransport(New TenantEmailTransportProfileResolver(),
                                                        New DpapiEmailCredentialStore(options.CredentialRoot,
                                                                                     options.ApplicationRoot),
                                                        New MailKitEmailSmtpSessionFactory(),
                                                        New SanitizedTelemetrySink())
            Dim result As EmailConnectionVerificationResult = transport.VerifyConnection(connectionString,
                                                                                           options.AziendaId,
                                                                                           options.Purpose,
                                                                                           correlationId)
            connectionString = Nothing
            databaseIdentity = Nothing
            Return WriteResult(result, correlationId)
        Catch ex As ArgumentException
            Return WriteFailure("TECHNICAL_ERROR", "INVALID_REQUEST", "CONFIGURATION",
                                SafeCode(ex.Message, "EMAIL_VERIFY_CONFIGURATION_INVALID"), correlationId,
                                ExitConfiguration)
        Catch ex As UnauthorizedAccessException
            Return WriteFailure("TECHNICAL_ERROR", "CREDENTIAL", "CREDENTIAL_LOAD",
                                "EMAIL_VERIFY_ACCESS_DENIED", correlationId,
                                ExitCredential)
        Catch
            Return WriteFailure("TECHNICAL_ERROR", "TRANSPORT", "INTERNAL",
                                "EMAIL_VERIFY_INTERNAL_FAILURE", correlationId,
                                ExitInternal)
        End Try
    End Function

    Private Function ParseOptions(ByVal args As String()) As VerifierOptions
        If args Is Nothing OrElse args.Length <> 10 Then Throw New ArgumentException("EMAIL_VERIFY_ARGUMENTS_INVALID")

        Dim values As New Dictionary(Of String, String)(StringComparer.Ordinal)
        For index As Integer = 0 To args.Length - 1 Step 2
            Dim key As String = Convert.ToString(args(index))
            Dim value As String = Convert.ToString(args(index + 1))
            If key <> "--azienda-id" AndAlso
               key <> "--purpose" AndAlso
               key <> "--application-root" AndAlso
               key <> "--connection-string-name" AndAlso
               key <> "--credential-root" Then
                Throw New ArgumentException("EMAIL_VERIFY_ARGUMENT_NOT_ALLOWED")
            End If
            If values.ContainsKey(key) OrElse String.IsNullOrWhiteSpace(value) OrElse HasControlCharacters(value) Then
                Throw New ArgumentException("EMAIL_VERIFY_ARGUMENT_INVALID")
            End If
            values.Add(key, value)
        Next

        Dim aziendaId As Integer
        If Not Integer.TryParse(GetRequired(values, "--azienda-id"), NumberStyles.None,
                                CultureInfo.InvariantCulture, aziendaId) OrElse aziendaId <= 0 Then
            Throw New ArgumentException("EMAIL_VERIFY_AZIENDA_INVALID")
        End If

        Dim purpose As String = GetRequired(values, "--purpose").Trim().ToUpperInvariant()
        If purpose <> "TRANSACTIONAL" AndAlso purpose <> "MARKETING" Then
            Throw New ArgumentException("EMAIL_VERIFY_PURPOSE_INVALID")
        End If

        Dim applicationRoot As String = Path.GetFullPath(GetRequired(values, "--application-root"))
        Dim credentialRoot As String = Path.GetFullPath(GetRequired(values, "--credential-root"))
        If Not Directory.Exists(applicationRoot) OrElse
           Not File.Exists(Path.Combine(applicationRoot, "web.config")) OrElse
           IsPathWithin(credentialRoot, applicationRoot) Then
            Throw New ArgumentException("EMAIL_VERIFY_PATH_INVALID")
        End If

        Dim connectionStringName As String = GetRequired(values, "--connection-string-name").Trim()
        If Not Regex.IsMatch(connectionStringName, "^[A-Za-z0-9_.-]{1,128}$", RegexOptions.CultureInvariant) Then
            Throw New ArgumentException("EMAIL_VERIFY_CONNECTION_NAME_INVALID")
        End If

        Return New VerifierOptions() With {
            .AziendaId = aziendaId,
            .Purpose = purpose,
            .ApplicationRoot = applicationRoot,
            .ConnectionStringName = connectionStringName,
            .CredentialRoot = credentialRoot
        }
    End Function

    Private Function LoadConnectionString(ByVal applicationRoot As String,
                                          ByVal connectionStringName As String) As String
        Dim document As New XmlDocument()
        document.XmlResolver = Nothing
        document.Load(Path.Combine(applicationRoot, "web.config"))

        Dim matches As New List(Of XmlElement)()
        Dim nodes As XmlNodeList = document.SelectNodes("/configuration/connectionStrings/add")
        If nodes IsNot Nothing Then
            For Each node As XmlNode In nodes
                Dim element As XmlElement = TryCast(node, XmlElement)
                If element IsNot Nothing AndAlso
                   String.Equals(element.GetAttribute("name"), connectionStringName, StringComparison.Ordinal) Then
                    matches.Add(element)
                End If
            Next
        End If
        If matches.Count <> 1 Then Throw New ArgumentException("EMAIL_VERIFY_CONNECTION_STRING_NOT_UNIQUE")

        Dim value As String = matches(0).GetAttribute("connectionString")
        If String.IsNullOrWhiteSpace(value) OrElse HasControlCharacters(value) Then
            Throw New ArgumentException("EMAIL_VERIFY_CONNECTION_STRING_INVALID")
        End If
        Return value
    End Function

    Private Function WriteResult(ByVal result As EmailConnectionVerificationResult,
                                 ByVal fallbackCorrelationId As String) As Integer
        If result Is Nothing Then
            Return WriteFailure("TECHNICAL_ERROR", "TRANSPORT", "INTERNAL",
                                "EMAIL_VERIFY_RESULT_NULL", fallbackCorrelationId,
                                ExitInternal)
        End If

        WriteField("STATUS", result.Status.ToString().ToUpperInvariant())
        WriteField("PROFILE_STATE", ToSnakeToken(result.ProfileState.ToString()))
        WriteField("FAILURE_KIND", ToSnakeToken(result.FailureKind.ToString()))
        WriteField("PHASE", ToSnakeToken(result.Phase))
        WriteField("CODE", SafeCode(result.Code, "EMAIL_VERIFY_FAILURE"))
        WriteField("AUTHENTICATION_MODE", ToSnakeToken(result.AuthenticationMode))
        WriteField("SECURITY_MODE", ToSnakeToken(result.SecurityMode))
        WriteField("TIMESTAMP_UTC", result.TimestampUtc.ToUniversalTime().ToString("o", CultureInfo.InvariantCulture))
        WriteField("CORRELATION_ID", SafeCorrelation(result.CorrelationId, fallbackCorrelationId))
        Return MapExitCode(result)
    End Function

    Private Function WriteFailure(ByVal profileState As String,
                                  ByVal failureKind As String,
                                  ByVal phase As String,
                                  ByVal code As String,
                                  ByVal correlationId As String,
                                  ByVal exitCode As Integer) As Integer
        WriteField("STATUS", "FAILED")
        WriteField("PROFILE_STATE", ToSnakeToken(profileState))
        WriteField("FAILURE_KIND", ToSnakeToken(failureKind))
        WriteField("PHASE", ToSnakeToken(phase))
        WriteField("CODE", SafeCode(code, "EMAIL_VERIFY_FAILURE"))
        WriteField("AUTHENTICATION_MODE", "N_A")
        WriteField("SECURITY_MODE", "N_A")
        WriteField("TIMESTAMP_UTC", DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture))
        WriteField("CORRELATION_ID", SafeCorrelation(correlationId, Guid.NewGuid().ToString("N")))
        Return exitCode
    End Function

    Private Function MapExitCode(ByVal result As EmailConnectionVerificationResult) As Integer
        If result.Status = EmailTransportOperationStatus.Succeeded Then Return ExitSuccess
        If result.ProfileState = TenantEmailTransportProfileState.CredentialMissing OrElse
           result.FailureKind = EmailTransportFailureKind.Credential Then Return ExitCredential

        Select Case result.FailureKind
            Case EmailTransportFailureKind.Tls,
                 EmailTransportFailureKind.Certificate,
                 EmailTransportFailureKind.HostnameMismatch
                Return ExitTls
            Case EmailTransportFailureKind.Authentication
                Return ExitAuthentication
            Case EmailTransportFailureKind.Timeout
                Return ExitTimeout
            Case EmailTransportFailureKind.Dns,
                 EmailTransportFailureKind.Tcp,
                 EmailTransportFailureKind.Transport
                Return ExitTransport
            Case EmailTransportFailureKind.InvalidRequest
                Return ExitConfiguration
        End Select

        Select Case result.ProfileState
            Case TenantEmailTransportProfileState.SchemaUnavailable,
                 TenantEmailTransportProfileState.NotConfigured,
                 TenantEmailTransportProfileState.Disabled,
                 TenantEmailTransportProfileState.Ambiguous,
                 TenantEmailTransportProfileState.NotOperational
                Return ExitProfileUnavailable
            Case TenantEmailTransportProfileState.TechnicalError
                Return ExitInternal
            Case Else
                Return ExitProfileUnavailable
        End Select
    End Function

    Private Sub WriteField(ByVal name As String, ByVal value As String)
        Console.Out.WriteLine(name & "=" & SafeOutputValue(value))
    End Sub

    Private Function SafeOutputValue(ByVal value As String) As String
        Dim candidate As String = Convert.ToString(value).Trim()
        If candidate.Length = 0 OrElse candidate.Length > 128 OrElse
           Not Regex.IsMatch(candidate, "^[A-Za-z0-9_.:+-]+$", RegexOptions.CultureInvariant) Then
            Return "N_A"
        End If
        Return candidate
    End Function

    Private Function SafeCode(ByVal value As String, ByVal fallback As String) As String
        Dim candidate As String = Convert.ToString(value).Trim().ToUpperInvariant()
        If Regex.IsMatch(candidate, "^[A-Z0-9_]{3,64}$", RegexOptions.CultureInvariant) Then Return candidate
        Return fallback
    End Function

    Private Function SafeCorrelation(ByVal value As String, ByVal fallback As String) As String
        Dim candidate As String = Convert.ToString(value).Trim()
        If Regex.IsMatch(candidate, "^[A-Za-z0-9-]{8,64}$", RegexOptions.CultureInvariant) Then Return candidate
        Return Convert.ToString(fallback).Trim()
    End Function

    Private Function ToSnakeToken(ByVal value As String) As String
        Dim candidate As String = Convert.ToString(value).Trim()
        If candidate.Length = 0 Then Return "N_A"
        candidate = Regex.Replace(candidate, "([a-z0-9])([A-Z])", "$1_$2", RegexOptions.CultureInvariant)
        candidate = Regex.Replace(candidate, "[^A-Za-z0-9]+", "_", RegexOptions.CultureInvariant)
        candidate = candidate.Trim("_"c).ToUpperInvariant()
        If candidate.Length = 0 OrElse candidate.Length > 64 Then Return "N_A"
        Return candidate
    End Function

    Private Function GetRequired(ByVal values As IDictionary(Of String, String),
                                 ByVal key As String) As String
        Dim value As String = Nothing
        If Not values.TryGetValue(key, value) Then Throw New ArgumentException("EMAIL_VERIFY_ARGUMENT_REQUIRED")
        Return value
    End Function

    Private Function HasControlCharacters(ByVal value As String) As Boolean
        For Each character As Char In Convert.ToString(value)
            If Char.IsControl(character) Then Return True
        Next
        Return False
    End Function

    Private Function IsPathWithin(ByVal candidatePath As String, ByVal parentPath As String) As Boolean
        Dim candidate As String = Path.GetFullPath(candidatePath).TrimEnd(Path.DirectorySeparatorChar) & Path.DirectorySeparatorChar
        Dim parent As String = Path.GetFullPath(parentPath).TrimEnd(Path.DirectorySeparatorChar) & Path.DirectorySeparatorChar
        Return candidate.StartsWith(parent, StringComparison.OrdinalIgnoreCase)
    End Function
End Module
