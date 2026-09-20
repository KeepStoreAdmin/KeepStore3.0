Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Net
Imports System.Net.Security
Imports System.Net.Sockets
Imports System.Security.Authentication
Imports System.Security.Cryptography.X509Certificates
Imports System.Text
Imports System.Text.RegularExpressions
Imports MailKit.Net.Smtp
Imports MailKit.Security
Imports MimeKit

Public NotInheritable Class EmailSmtpAdapterException
    Inherits Exception

    Private ReadOnly _failureKind As EmailTransportFailureKind
    Private ReadOnly _safeCode As String

    Public Sub New(ByVal kind As EmailTransportFailureKind, ByVal code As String)
        MyBase.New("EMAIL_TRANSPORT_ADAPTER_FAILURE")
        _failureKind = kind
        _safeCode = code
    End Sub

    Public ReadOnly Property FailureKind As EmailTransportFailureKind
        Get
            Return _failureKind
        End Get
    End Property

    Public ReadOnly Property SafeCode As String
        Get
            Return _safeCode
        End Get
    End Property
End Class

Public Interface IEmailSmtpSession
    Inherits IDisposable

    Sub ConfigureTimeout(ByVal timeoutMilliseconds As Integer)
    Sub Connect(ByVal host As String, ByVal port As Integer, ByVal options As SecureSocketOptions)
    Sub Authenticate(ByVal username As String, ByVal secret As String)
    Sub Send(ByVal message As MimeMessage, ByVal envelopeFromAddress As String)
    ReadOnly Property IsConnected As Boolean
    ReadOnly Property LastTlsFailureKind As EmailTransportFailureKind
    Sub Disconnect(ByVal sendQuit As Boolean)
End Interface

Public Interface IEmailSmtpSessionFactory
    Function Create() As IEmailSmtpSession
End Interface

Public NotInheritable Class MailKitEmailSmtpSessionFactory
    Implements IEmailSmtpSessionFactory

    Public Function Create() As IEmailSmtpSession Implements IEmailSmtpSessionFactory.Create
        Return New MailKitEmailSmtpSession()
    End Function
End Class

Public NotInheritable Class MailKitEmailSmtpSession
    Implements IEmailSmtpSession

    Private ReadOnly _client As SmtpClient
    Private _lastTlsFailureKind As EmailTransportFailureKind

    Public Sub New()
        _client = New SmtpClient()
        _client.CheckCertificateRevocation = True
        _client.ServerCertificateValidationCallback = AddressOf ValidateCertificate
    End Sub

    Public Sub ConfigureTimeout(ByVal timeoutMilliseconds As Integer) Implements IEmailSmtpSession.ConfigureTimeout
        _client.Timeout = timeoutMilliseconds
    End Sub

    Public Sub Connect(ByVal host As String,
                       ByVal port As Integer,
                       ByVal options As SecureSocketOptions) Implements IEmailSmtpSession.Connect
        _lastTlsFailureKind = EmailTransportFailureKind.None
        _client.Connect(host, port, options)
    End Sub

    Public Sub Authenticate(ByVal username As String, ByVal secret As String) Implements IEmailSmtpSession.Authenticate
        _client.AuthenticationMechanisms.Remove("XOAUTH2")
        _client.AuthenticationMechanisms.Remove("OAUTHBEARER")
        _client.Authenticate(username, secret)
    End Sub

    Public Sub Send(ByVal message As MimeMessage,
                    ByVal envelopeFromAddress As String) Implements IEmailSmtpSession.Send
        If message Is Nothing Then Throw New ArgumentNullException("message")

        Dim recipients As New List(Of MailboxAddress)()
        AddRecipients(recipients, message.To)
        AddRecipients(recipients, message.Cc)
        AddRecipients(recipients, message.Bcc)
        If recipients.Count = 0 Then Throw New InvalidOperationException("EMAIL_RECIPIENT_REQUIRED")

        Dim senderAddress As String = Convert.ToString(envelopeFromAddress).Trim()
        If senderAddress = String.Empty AndAlso message.From.Mailboxes.GetEnumerator().MoveNext() Then
            For Each mailbox As MailboxAddress In message.From.Mailboxes
                senderAddress = mailbox.Address
                Exit For
            Next
        End If
        If senderAddress = String.Empty Then Throw New InvalidOperationException("EMAIL_ENVELOPE_FROM_REQUIRED")

        _client.Send(message, New MailboxAddress(String.Empty, senderAddress), recipients)
    End Sub

    Public ReadOnly Property IsConnected As Boolean Implements IEmailSmtpSession.IsConnected
        Get
            Return _client.IsConnected
        End Get
    End Property

    Public ReadOnly Property LastTlsFailureKind As EmailTransportFailureKind Implements IEmailSmtpSession.LastTlsFailureKind
        Get
            Return _lastTlsFailureKind
        End Get
    End Property

    Public Sub Disconnect(ByVal sendQuit As Boolean) Implements IEmailSmtpSession.Disconnect
        _client.Disconnect(sendQuit)
    End Sub

    Public Sub Dispose() Implements IDisposable.Dispose
        _client.Dispose()
    End Sub

    Private Function ValidateCertificate(ByVal sender As Object,
                                         ByVal certificate As X509Certificate,
                                         ByVal chain As X509Chain,
                                         ByVal sslPolicyErrors As SslPolicyErrors) As Boolean
        If sslPolicyErrors = SslPolicyErrors.None Then Return True
        If (sslPolicyErrors And SslPolicyErrors.RemoteCertificateNameMismatch) <> 0 Then
            _lastTlsFailureKind = EmailTransportFailureKind.HostnameMismatch
        Else
            _lastTlsFailureKind = EmailTransportFailureKind.Certificate
        End If
        Return False
    End Function

    Private Shared Sub AddRecipients(ByVal target As IList(Of MailboxAddress),
                                     ByVal source As InternetAddressList)
        For Each mailbox As MailboxAddress In source.Mailboxes
            target.Add(mailbox)
        Next
    End Sub
End Class

Public NotInheritable Class KeepStoreEmailTransportTelemetrySink
    Implements IEmailTransportTelemetrySink

    Public Sub Record(ByVal line As String) Implements IEmailTransportTelemetrySink.Record
        KeepStoreLog.Info("email-transport-core", Convert.ToString(line), Nothing)
    End Sub
End Class

Friend NotInheritable Class EmailTransportExecutionOutcome
    Public Property Status As EmailTransportOperationStatus
    Public Property ProfileState As TenantEmailTransportProfileState
    Public Property FailureKind As EmailTransportFailureKind
    Public Property Phase As String
    Public Property Code As String
    Public Property AuthenticationMode As String
    Public Property SecurityMode As String
    Public Property TimestampUtc As DateTime
    Public Property CorrelationId As String
End Class

Public NotInheritable Class MailKitEmailTransport
    Implements IEmailTransport

    Private Shared ReadOnly SafeCorrelationPattern As New Regex("^[A-Za-z0-9-]{8,64}$", RegexOptions.CultureInvariant Or RegexOptions.Compiled)
    Private ReadOnly _resolver As ITenantEmailTransportProfileResolver
    Private ReadOnly _credentialStore As IEmailCredentialStore
    Private ReadOnly _sessionFactory As IEmailSmtpSessionFactory
    Private ReadOnly _telemetry As IEmailTransportTelemetrySink

    Public Sub New()
        Me.New(New TenantEmailTransportProfileResolver(),
               New DpapiEmailCredentialStore(),
               New MailKitEmailSmtpSessionFactory(),
               New KeepStoreEmailTransportTelemetrySink())
    End Sub

    Public Sub New(ByVal resolver As ITenantEmailTransportProfileResolver,
                   ByVal credentialStore As IEmailCredentialStore,
                   ByVal sessionFactory As IEmailSmtpSessionFactory,
                   ByVal telemetry As IEmailTransportTelemetrySink)
        If resolver Is Nothing Then Throw New ArgumentNullException("resolver")
        If credentialStore Is Nothing Then Throw New ArgumentNullException("credentialStore")
        If sessionFactory Is Nothing Then Throw New ArgumentNullException("sessionFactory")
        If telemetry Is Nothing Then Throw New ArgumentNullException("telemetry")
        _resolver = resolver
        _credentialStore = credentialStore
        _sessionFactory = sessionFactory
        _telemetry = telemetry
    End Sub

    Public Function Deliver(ByVal request As EmailTransportRequest) As EmailDeliveryResult Implements IEmailTransport.Deliver
        Dim correlationId As String = NormalizeCorrelationId(If(request Is Nothing, Nothing, request.CorrelationId))
        If request Is Nothing OrElse request.Message Is Nothing Then
            Dim invalid As EmailTransportExecutionOutcome = FailureOutcome(TenantEmailTransportProfileState.TechnicalError,
                                                                           EmailTransportFailureKind.InvalidRequest,
                                                                           "request-validation",
                                                                           "EMAIL_REQUEST_INVALID",
                                                                           correlationId)
            Record(invalid, "delivery")
            Return ToDeliveryResult(invalid)
        End If

        Dim outcome As EmailTransportExecutionOutcome = ExecuteDelivery(request.ConnectionString,
                                                                        request.AziendaId,
                                                                        request.Purpose,
                                                                        correlationId,
                                                                        request.Message)
        Record(outcome, "delivery")
        Return ToDeliveryResult(outcome)
    End Function

    Public Function VerifyConnection(ByVal connectionString As String,
                                     ByVal aziendaId As Integer,
                                     ByVal purpose As String,
                                     ByVal correlationId As String) As EmailConnectionVerificationResult Implements IEmailTransport.VerifyConnection
        Dim normalizedCorrelation As String = NormalizeCorrelationId(correlationId)
        Dim outcome As EmailTransportExecutionOutcome = ExecuteVerification(connectionString,
                                                                            aziendaId,
                                                                            purpose,
                                                                            normalizedCorrelation)
        Record(outcome, "verification")
        Return ToVerificationResult(outcome)
    End Function

    Private Function ExecuteDelivery(ByVal connectionString As String,
                                     ByVal aziendaId As Integer,
                                     ByVal purpose As String,
                                     ByVal correlationId As String,
                                     ByVal message As MimeMessage) As EmailTransportExecutionOutcome
        Return ExecuteResolved(_resolver.Resolve(connectionString, aziendaId, purpose), correlationId, message)
    End Function

    Private Function ExecuteVerification(ByVal connectionString As String,
                                         ByVal aziendaId As Integer,
                                         ByVal purpose As String,
                                         ByVal correlationId As String) As EmailTransportExecutionOutcome
        Return ExecuteResolved(_resolver.ResolveForVerification(connectionString, aziendaId, purpose), correlationId, Nothing)
    End Function

    Private Function ExecuteResolved(ByVal resolution As TenantEmailTransportProfileResolution,
                                     ByVal correlationId As String,
                                     ByVal message As MimeMessage) As EmailTransportExecutionOutcome
        If resolution Is Nothing OrElse resolution.State <> TenantEmailTransportProfileState.Ready OrElse resolution.Profile Is Nothing Then
            Dim stateValue As TenantEmailTransportProfileState = If(resolution Is Nothing, TenantEmailTransportProfileState.TechnicalError, resolution.State)
            Dim codeValue As String = If(resolution Is Nothing, "PROFILE_RESOLUTION_NULL", resolution.Code)
            Dim kind As EmailTransportFailureKind = If(stateValue = TenantEmailTransportProfileState.NotOperational,
                                                        EmailTransportFailureKind.NotOperational,
                                                        EmailTransportFailureKind.Resolver)
            Return FailureOutcome(stateValue, kind, "profile-resolution", codeValue, correlationId)
        End If

        Dim profile As TenantEmailTransportProfile = resolution.Profile
        If profile.AuthenticationMode = EmailAuthenticationMode.OAuth2 Then
            Return FailureOutcome(TenantEmailTransportProfileState.NotOperational,
                                  EmailTransportFailureKind.NotOperational,
                                  "profile-validation",
                                  "OAUTH2_NOT_OPERATIONAL",
                                  correlationId,
                                  profile)
        End If

        Using credential As EmailCredentialReadResult = _credentialStore.Read(profile.CredentialReference,
                                                                               profile.DatabaseIdentity,
                                                                               profile.AziendaId,
                                                                               profile.Purpose)
            If credential Is Nothing OrElse credential.State <> EmailCredentialState.Found Then
                Dim credentialCode As String = If(credential Is Nothing, "CREDENTIAL_RESULT_NULL", credential.Code)
                Dim profileState As TenantEmailTransportProfileState = If(credential IsNot Nothing AndAlso credential.State = EmailCredentialState.Missing,
                                                                           TenantEmailTransportProfileState.CredentialMissing,
                                                                           TenantEmailTransportProfileState.TechnicalError)
                Return FailureOutcome(profileState,
                                      EmailTransportFailureKind.Credential,
                                      "credential-load",
                                      credentialCode,
                                      correlationId,
                                      profile)
            End If

            Dim session As IEmailSmtpSession = Nothing
            Dim phase As String = "session-create"
            Try
                session = _sessionFactory.Create()
                session.ConfigureTimeout(profile.TimeoutSeconds * 1000)

                phase = "tls-connect"
                session.Connect(profile.Host, profile.Port, ToSocketOptions(profile.SecurityMode))

                phase = "authentication"
                credential.UseSecret(Of Boolean)(Function(secret As String) As Boolean
                                                      session.Authenticate(profile.Username, secret)
                                                      Return True
                                                  End Function)

                If message IsNot Nothing Then
                    phase = "message-send"
                    ApplyAuthoritativeSender(message, profile)
                    session.Send(message, profile.EnvelopeFromAddress)
                End If

                Return SuccessOutcome(If(message Is Nothing, "EMAIL_CONNECTION_VERIFIED", "EMAIL_SENT"),
                                      correlationId,
                                      profile,
                                      If(message Is Nothing, "authenticated", "sent"))
            Catch ex As EmailSmtpAdapterException
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, ex.FailureKind, phase, SafeCode(ex.SafeCode, "SMTP_ADAPTER_FAILURE"), correlationId, profile)
            Catch ex As SocketException
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, ClassifySocket(ex), phase, If(ClassifySocket(ex) = EmailTransportFailureKind.Dns, "SMTP_DNS_FAILURE", "SMTP_TCP_FAILURE"), correlationId, profile)
            Catch ex As MailKit.Security.AuthenticationException
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, EmailTransportFailureKind.Authentication, phase, "SMTP_AUTH_REJECTED", correlationId, profile)
            Catch ex As SslHandshakeException
                Dim tlsKind As EmailTransportFailureKind = If(session Is Nothing OrElse session.LastTlsFailureKind = EmailTransportFailureKind.None,
                                                               EmailTransportFailureKind.Tls,
                                                               session.LastTlsFailureKind)
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, tlsKind, phase, TlsCode(tlsKind), correlationId, profile)
            Catch ex As System.Security.Authentication.AuthenticationException
                Dim tlsKind As EmailTransportFailureKind = If(session Is Nothing OrElse session.LastTlsFailureKind = EmailTransportFailureKind.None,
                                                               EmailTransportFailureKind.Tls,
                                                               session.LastTlsFailureKind)
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, tlsKind, phase, TlsCode(tlsKind), correlationId, profile)
            Catch ex As TimeoutException
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, EmailTransportFailureKind.Timeout, phase, "SMTP_TIMEOUT", correlationId, profile)
            Catch ex As OperationCanceledException
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, EmailTransportFailureKind.Timeout, phase, "SMTP_TIMEOUT", correlationId, profile)
            Catch ex As NotSupportedException
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, EmailTransportFailureKind.Tls, phase, "SMTP_TLS_REQUIRED", correlationId, profile)
            Catch ex As SmtpCommandException
                Dim smtpKind As EmailTransportFailureKind = If(phase = "authentication", EmailTransportFailureKind.Authentication, EmailTransportFailureKind.Transport)
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, smtpKind, phase, If(smtpKind = EmailTransportFailureKind.Authentication, "SMTP_AUTH_REJECTED", "SMTP_COMMAND_REJECTED"), correlationId, profile)
            Catch ex As SmtpProtocolException
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, EmailTransportFailureKind.Transport, phase, "SMTP_PROTOCOL_FAILURE", correlationId, profile)
            Catch ex As IOException
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, EmailTransportFailureKind.Transport, phase, "SMTP_IO_FAILURE", correlationId, profile)
            Catch
                Return FailureOutcome(TenantEmailTransportProfileState.Ready, EmailTransportFailureKind.Transport, phase, "SMTP_TRANSPORT_FAILURE", correlationId, profile)
            Finally
                If session IsNot Nothing Then
                    Try
                        If session.IsConnected Then session.Disconnect(True)
                    Catch
                    End Try
                    session.Dispose()
                End If
            End Try
        End Using
    End Function

    Private Shared Sub ApplyAuthoritativeSender(ByVal message As MimeMessage,
                                                ByVal profile As TenantEmailTransportProfile)
        message.From.Clear()
        message.From.Add(New MailboxAddress(profile.FromDisplayName, profile.FromAddress))
        If message.ReplyTo.Count = 0 AndAlso Not String.IsNullOrWhiteSpace(profile.ReplyToAddress) Then
            message.ReplyTo.Add(New MailboxAddress(String.Empty, profile.ReplyToAddress))
        End If
    End Sub

    Private Shared Function ToSocketOptions(ByVal securityMode As EmailSecurityMode) As SecureSocketOptions
        If securityMode = EmailSecurityMode.StartTls Then Return SecureSocketOptions.StartTls
        If securityMode = EmailSecurityMode.ImplicitTls Then Return SecureSocketOptions.SslOnConnect
        Throw New NotSupportedException("EMAIL_SECURITY_MODE_NOT_SUPPORTED")
    End Function

    Private Shared Function ClassifySocket(ByVal ex As SocketException) As EmailTransportFailureKind
        Select Case ex.SocketErrorCode
            Case SocketError.HostNotFound, SocketError.NoData, SocketError.TryAgain, SocketError.NoRecovery
                Return EmailTransportFailureKind.Dns
            Case Else
                Return EmailTransportFailureKind.Tcp
        End Select
    End Function

    Private Shared Function TlsCode(ByVal kind As EmailTransportFailureKind) As String
        If kind = EmailTransportFailureKind.HostnameMismatch Then Return "SMTP_TLS_HOSTNAME_MISMATCH"
        If kind = EmailTransportFailureKind.Certificate Then Return "SMTP_TLS_CERTIFICATE_REJECTED"
        Return "SMTP_TLS_FAILURE"
    End Function

    Private Shared Function NormalizeCorrelationId(ByVal value As String) As String
        Dim candidate As String = Convert.ToString(value).Trim()
        If SafeCorrelationPattern.IsMatch(candidate) Then Return candidate
        Return Guid.NewGuid().ToString("N")
    End Function

    Private Shared Function SafeCode(ByVal value As String, ByVal fallback As String) As String
        Dim candidate As String = Convert.ToString(value).Trim()
        If Regex.IsMatch(candidate, "^[A-Z0-9_]{3,64}$", RegexOptions.CultureInvariant) Then Return candidate
        Return fallback
    End Function

    Private Shared Function SuccessOutcome(ByVal code As String,
                                           ByVal correlationId As String,
                                           ByVal profile As TenantEmailTransportProfile,
                                           ByVal phase As String) As EmailTransportExecutionOutcome
        Return New EmailTransportExecutionOutcome() With {
            .Status = EmailTransportOperationStatus.Succeeded,
            .ProfileState = TenantEmailTransportProfileState.Ready,
            .FailureKind = EmailTransportFailureKind.None,
            .Phase = phase,
            .Code = code,
            .AuthenticationMode = profile.AuthenticationMode.ToString(),
            .SecurityMode = profile.SecurityMode.ToString(),
            .TimestampUtc = DateTime.UtcNow,
            .CorrelationId = correlationId
        }
    End Function

    Private Shared Function FailureOutcome(ByVal profileState As TenantEmailTransportProfileState,
                                           ByVal failureKind As EmailTransportFailureKind,
                                           ByVal phase As String,
                                           ByVal code As String,
                                           ByVal correlationId As String,
                                           Optional ByVal profile As TenantEmailTransportProfile = Nothing) As EmailTransportExecutionOutcome
        Return New EmailTransportExecutionOutcome() With {
            .Status = If(profileState = TenantEmailTransportProfileState.SchemaUnavailable OrElse
                         profileState = TenantEmailTransportProfileState.NotConfigured OrElse
                         profileState = TenantEmailTransportProfileState.Disabled OrElse
                         profileState = TenantEmailTransportProfileState.CredentialMissing OrElse
                         profileState = TenantEmailTransportProfileState.NotOperational,
                         EmailTransportOperationStatus.Rejected,
                         EmailTransportOperationStatus.Failed),
            .ProfileState = profileState,
            .FailureKind = failureKind,
            .Phase = phase,
            .Code = SafeCode(code, "EMAIL_TRANSPORT_FAILURE"),
            .AuthenticationMode = If(profile Is Nothing, "N/A", profile.AuthenticationMode.ToString()),
            .SecurityMode = If(profile Is Nothing, "N/A", profile.SecurityMode.ToString()),
            .TimestampUtc = DateTime.UtcNow,
            .CorrelationId = correlationId
        }
    End Function

    Private Sub Record(ByVal outcome As EmailTransportExecutionOutcome, ByVal operationName As String)
        _telemetry.Record(EmailTransportTelemetry.Format(outcome, operationName))
    End Sub

    Private Shared Function ToDeliveryResult(ByVal value As EmailTransportExecutionOutcome) As EmailDeliveryResult
        Return New EmailDeliveryResult() With {
            .Status = value.Status,
            .ProfileState = value.ProfileState,
            .FailureKind = value.FailureKind,
            .Phase = value.Phase,
            .Code = value.Code,
            .AuthenticationMode = value.AuthenticationMode,
            .SecurityMode = value.SecurityMode,
            .TimestampUtc = value.TimestampUtc,
            .CorrelationId = value.CorrelationId
        }
    End Function

    Private Shared Function ToVerificationResult(ByVal value As EmailTransportExecutionOutcome) As EmailConnectionVerificationResult
        Return New EmailConnectionVerificationResult() With {
            .Status = value.Status,
            .ProfileState = value.ProfileState,
            .FailureKind = value.FailureKind,
            .Phase = value.Phase,
            .Code = value.Code,
            .AuthenticationMode = value.AuthenticationMode,
            .SecurityMode = value.SecurityMode,
            .TimestampUtc = value.TimestampUtc,
            .CorrelationId = value.CorrelationId
        }
    End Function
End Class

Public NotInheritable Class EmailTransportTelemetry
    Private Sub New()
    End Sub

    Friend Shared Function Format(ByVal outcome As EmailTransportExecutionOutcome,
                                  ByVal operationName As String) As String
        If outcome Is Nothing Then Return "operation=unknown status=Failed phase=unknown code=EMAIL_TRANSPORT_RESULT_NULL"
        Return "operation=" & SafeToken(operationName) &
               " status=" & outcome.Status.ToString() &
               " profileState=" & outcome.ProfileState.ToString() &
               " failure=" & outcome.FailureKind.ToString() &
               " phase=" & SafeToken(outcome.Phase) &
               " code=" & SafeToken(outcome.Code) &
               " auth=" & SafeToken(outcome.AuthenticationMode) &
               " tls=" & SafeToken(outcome.SecurityMode) &
               " timestamp=" & outcome.TimestampUtc.ToString("o") &
               " correlation=" & SafeToken(outcome.CorrelationId)
    End Function

    Private Shared Function SafeToken(ByVal value As String) As String
        Dim candidate As String = Convert.ToString(value).Trim()
        If candidate.Length > 80 Then candidate = candidate.Substring(0, 80)
        Dim safe As New StringBuilder(candidate.Length)
        For Each character As Char In candidate
            If Char.IsLetterOrDigit(character) OrElse character = "_"c OrElse character = "-"c OrElse character = "."c Then
                safe.Append(character)
            Else
                safe.Append("_"c)
            End If
        Next
        Return safe.ToString()
    End Function
End Class
