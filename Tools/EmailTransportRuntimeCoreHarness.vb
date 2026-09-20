Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Text
Imports MailKit.Security
Imports MimeKit

Public Module KeepStoreLog
    Public Sub Info(ByVal source As String, ByVal message As String, ByVal context As Object)
    End Sub
End Module

Public NotInheritable Class HarnessIdentityProvider
    Implements IEmailDatabaseIdentityProvider

    Public Function GetIdentity(ByVal connectionString As String) As String Implements IEmailDatabaseIdentityProvider.GetIdentity
        If String.Equals(connectionString, "db-b", StringComparison.Ordinal) Then Return New String("b"c, 64)
        Return New String("a"c, 64)
    End Function
End Class

Public NotInheritable Class HarnessProfileSource
    Implements IEmailTransportProfileSource

    Public Property ResultFactory As Func(Of String, Integer, String, EmailTransportProfileSourceResult)
    Public Property LoadCount As Integer

    Public Function Load(ByVal connectionString As String,
                         ByVal aziendaId As Integer,
                         ByVal purpose As String) As EmailTransportProfileSourceResult Implements IEmailTransportProfileSource.Load
        LoadCount += 1
        Return ResultFactory(connectionString, aziendaId, purpose)
    End Function
End Class

Public NotInheritable Class HarnessReadyResolver
    Implements ITenantEmailTransportProfileResolver

    Public Property Profile As TenantEmailTransportProfile
    Public Property ForcedState As Nullable(Of TenantEmailTransportProfileState)
    Public Property NormalResolveCount As Integer
    Public Property VerificationResolveCount As Integer

    Public Function Resolve(ByVal connectionString As String,
                            ByVal aziendaId As Integer,
                            ByVal purpose As String) As TenantEmailTransportProfileResolution Implements ITenantEmailTransportProfileResolver.Resolve
        NormalResolveCount += 1
        Return ResolveCore()
    End Function

    Public Function ResolveForVerification(ByVal connectionString As String,
                                           ByVal aziendaId As Integer,
                                           ByVal purpose As String) As TenantEmailTransportProfileResolution Implements ITenantEmailTransportProfileResolver.ResolveForVerification
        VerificationResolveCount += 1
        Return ResolveCore()
    End Function

    Private Function ResolveCore() As TenantEmailTransportProfileResolution
        If ForcedState.HasValue Then
            Return TenantEmailTransportProfileResolution.Create(ForcedState.Value, "HARNESS_PROFILE_STATE", New String("a"c, 64))
        End If
        Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.Ready, "PROFILE_READY", Profile.DatabaseIdentity, Profile)
    End Function
End Class

Public NotInheritable Class HarnessCredentialStore
    Implements IEmailCredentialStore

    Public Property State As EmailCredentialState = EmailCredentialState.Found
    Public Property Secret As String = "synthetic-secret"

    Public Function Read(ByVal credentialReference As String,
                         ByVal databaseIdentity As String,
                         ByVal aziendaId As Integer,
                         ByVal purpose As String) As EmailCredentialReadResult Implements IEmailCredentialStore.Read
        Dim result As New EmailCredentialReadResult() With {.State = State, .Code = "HARNESS_CREDENTIAL"}
        If State = EmailCredentialState.Found Then result.SetSecret(Encoding.UTF8.GetBytes(Secret))
        Return result
    End Function
End Class

Public NotInheritable Class HarnessTelemetry
    Implements IEmailTransportTelemetrySink

    Public ReadOnly Lines As New List(Of String)()

    Public Sub Record(ByVal line As String) Implements IEmailTransportTelemetrySink.Record
        Lines.Add(line)
    End Sub
End Class

Public NotInheritable Class HarnessSmtpSessionFactory
    Implements IEmailSmtpSessionFactory

    Public Property FailurePhase As String
    Public Property FailureKind As EmailTransportFailureKind
    Public ReadOnly Sessions As New List(Of HarnessSmtpSession)()

    Public Function Create() As IEmailSmtpSession Implements IEmailSmtpSessionFactory.Create
        Dim value As New HarnessSmtpSession() With {.FailurePhase = FailurePhase, .FailureKind = FailureKind}
        Sessions.Add(value)
        Return value
    End Function
End Class

Public NotInheritable Class HarnessSmtpSession
    Implements IEmailSmtpSession

    Public Property FailurePhase As String
    Public Property FailureKind As EmailTransportFailureKind
    Public Property Options As SecureSocketOptions
    Public Property TimeoutMilliseconds As Integer
    Public Property ConnectCount As Integer
    Public Property AuthenticateCount As Integer
    Public Property SendCount As Integer
    Public Property DisconnectCount As Integer
    Public Property SecretObserved As String
    Private _connected As Boolean

    Public Sub ConfigureTimeout(ByVal timeoutMillisecondsValue As Integer) Implements IEmailSmtpSession.ConfigureTimeout
        TimeoutMilliseconds = timeoutMillisecondsValue
    End Sub

    Public Sub Connect(ByVal host As String,
                       ByVal port As Integer,
                       ByVal optionsValue As SecureSocketOptions) Implements IEmailSmtpSession.Connect
        ConnectCount += 1
        Options = optionsValue
        ThrowIf("connect")
        _connected = True
    End Sub

    Public Sub Authenticate(ByVal username As String, ByVal secret As String) Implements IEmailSmtpSession.Authenticate
        AuthenticateCount += 1
        SecretObserved = secret
        ThrowIf("authenticate")
    End Sub

    Public Sub Send(ByVal message As MimeMessage,
                    ByVal envelopeFromAddress As String) Implements IEmailSmtpSession.Send
        SendCount += 1
        ThrowIf("send")
    End Sub

    Public ReadOnly Property IsConnected As Boolean Implements IEmailSmtpSession.IsConnected
        Get
            Return _connected
        End Get
    End Property

    Public ReadOnly Property LastTlsFailureKind As EmailTransportFailureKind Implements IEmailSmtpSession.LastTlsFailureKind
        Get
            If FailureKind = EmailTransportFailureKind.Certificate OrElse FailureKind = EmailTransportFailureKind.HostnameMismatch Then Return FailureKind
            Return EmailTransportFailureKind.None
        End Get
    End Property

    Public Sub Disconnect(ByVal sendQuit As Boolean) Implements IEmailSmtpSession.Disconnect
        DisconnectCount += 1
        _connected = False
    End Sub

    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub

    Private Sub ThrowIf(ByVal phase As String)
        If String.Equals(FailurePhase, phase, StringComparison.Ordinal) Then
            Throw New EmailSmtpAdapterException(FailureKind, "HARNESS_" & FailureKind.ToString().ToUpperInvariant())
        End If
    End Sub
End Class

Public Module EmailTransportRuntimeCoreHarness
    Private _passed As Integer

    Public Sub Main()
        TestResolverMatrix()
        TestCredentialMatrixAndDpapi()
        TestTransportMatrix()
        TestLegacyEmptyTableGate()
        Console.WriteLine("EMAIL_TRANSPORT_RUNTIME_CORE_PASS checks=" & _passed.ToString())
        Console.WriteLine("PROVISIONING_MODEL=SIMPLIFIED_ADMIN_TOOL")
    End Sub

    Private Sub TestResolverMatrix()
        Dim source As New HarnessProfileSource()
        Dim resolver As New TenantEmailTransportProfileResolver(source, New HarnessIdentityProvider())

        source.ResultFactory = Function(c, a, p) SourceResult(False, False)
        Assert(resolver.Resolve("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.SchemaUnavailable, "01_SCHEMA_UNAVAILABLE")

        source.ResultFactory = Function(c, a, p) SourceResult(True, False)
        Assert(resolver.Resolve("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.NotConfigured, "02_EMPTY_TABLE")

        source.ResultFactory = Function(c, a, p) SourceResult(True, False, ValidRecord(a, p, False, c))
        Assert(resolver.Resolve("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.Disabled, "03_DISABLED")

        source.ResultFactory = Function(c, a, p) SourceResult(True, False, ValidRecord(a, p, True, c, "NOT_VERIFIED"))
        Assert(resolver.Resolve("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.NotOperational, "03A_SEND_REJECTS_NOT_VERIFIED")

        source.ResultFactory = Function(c, a, p) SourceResult(True, False, ValidRecord(a, p, False, c, "NOT_VERIFIED"))
        Assert(resolver.ResolveForVerification("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.Ready, "03B_VERIFICATION_ACCEPTS_DISABLED_NOT_VERIFIED")

        Dim placeholder As TenantEmailTransportProfileRecord = ValidRecord(1, "TRANSACTIONAL", False, "db-a", "NOT_VERIFIED")
        placeholder.CredentialReference = "credential-pending"
        source.ResultFactory = Function(c, a, p) SourceResult(True, False, placeholder)
        Assert(resolver.ResolveForVerification("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.CredentialMissing, "03C_VERIFICATION_REJECTS_PLACEHOLDER")

        Dim revoked As TenantEmailTransportProfileRecord = ValidRecord(1, "TRANSACTIONAL", False, "db-a", "REVOKED")
        source.ResultFactory = Function(c, a, p) SourceResult(True, False, revoked)
        Assert(resolver.ResolveForVerification("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.NotOperational, "03D_VERIFICATION_REJECTS_REVOKED_STATE")

        source.ResultFactory = Function(c, a, p) SourceResult(True, False, ValidRecord(a, p, True, c))
        Dim tenantA = resolver.Resolve("db-a", 1, "TRANSACTIONAL")
        Dim tenantB = resolver.Resolve("db-a", 2, "TRANSACTIONAL")
        Assert(tenantA.State = TenantEmailTransportProfileState.Ready AndAlso tenantA.Profile.AziendaId = 1, "04_TENANT_A")
        Assert(tenantB.State = TenantEmailTransportProfileState.Ready AndAlso tenantB.Profile.AziendaId = 2, "05_TENANT_B")
        Assert(tenantA.Profile.DatabaseIdentity = tenantB.Profile.DatabaseIdentity AndAlso tenantA.Profile.AziendaId <> tenantB.Profile.AziendaId, "06_SAME_DB_DIFFERENT_TENANTS")

        Dim otherDatabase = resolver.Resolve("db-b", 1, "TRANSACTIONAL")
        Assert(otherDatabase.State = TenantEmailTransportProfileState.Ready AndAlso otherDatabase.Profile.DatabaseIdentity <> tenantA.Profile.DatabaseIdentity, "07_DATABASE_ISOLATION")

        source.ResultFactory = Function(c, a, p) SourceResult(True, False, ValidRecord(a, p, True, c), ValidRecord(a, p, True, c))
        Assert(resolver.Resolve("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.Ambiguous, "08_DUPLICATE_FAIL_CLOSED")

        source.ResultFactory = Function(c, a, p) SourceResult(True, False, ValidRecord(a, p, True, c))
        Dim transactional = resolver.Resolve("db-a", 1, "TRANSACTIONAL")
        Dim marketing = resolver.Resolve("db-a", 1, "MARKETING")
        Assert(transactional.Profile.Purpose = "TRANSACTIONAL" AndAlso marketing.Profile.Purpose = "MARKETING", "09_PURPOSE_ISOLATION")

        Dim missingReference As TenantEmailTransportProfileRecord = ValidRecord(1, "TRANSACTIONAL", True, "db-a")
        missingReference.CredentialReference = String.Empty
        source.ResultFactory = Function(c, a, p) SourceResult(True, False, missingReference)
        Assert(resolver.Resolve("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.CredentialMissing, "10_CREDENTIAL_REFERENCE_MISSING")

        Dim oauth As TenantEmailTransportProfileRecord = ValidRecord(1, "TRANSACTIONAL", True, "db-a")
        oauth.AuthenticationMode = "OAUTH2"
        source.ResultFactory = Function(c, a, p) SourceResult(True, False, oauth)
        Assert(resolver.Resolve("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.NotOperational, "11_OAUTH2_NOT_OPERATIONAL")

        Dim technicalCalls As Integer = 0
        source.ResultFactory = Function(c, a, p)
                                   technicalCalls += 1
                                   If technicalCalls = 1 Then Return SourceResult(True, True)
                                   Return SourceResult(True, False, ValidRecord(a, p, True, c))
                               End Function
        Assert(resolver.Resolve("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.TechnicalError AndAlso
               resolver.Resolve("db-a", 1, "TRANSACTIONAL").State = TenantEmailTransportProfileState.Ready,
               "12_TECHNICAL_ERROR_NOT_CACHED")
    End Sub

    Private Sub TestCredentialMatrixAndDpapi()
        Dim root As String = Path.Combine(Path.GetTempPath(), "KeepStore-EmailCredentialHarness-" & Guid.NewGuid().ToString("N"))
        Dim databaseIdentity As String = New String("a"c, 64)
        Dim reference As String = DpapiEmailCredentialStore.CreateReference(databaseIdentity, 1, "TRANSACTIONAL", New String("c"c, 32))
        Dim parts As EmailCredentialReferenceParts = Nothing
        Assert(DpapiEmailCredentialStore.TryParseReference(reference, parts), "13_REFERENCE_VALID")

        Dim credentialPath As String = DpapiEmailCredentialStore.BuildCredentialPath(root, parts)
        Directory.CreateDirectory(Path.GetDirectoryName(credentialPath))
        Dim synthetic As Byte() = Encoding.UTF8.GetBytes("synthetic-dpapi-secret")
        Try
            Dim envelope As Byte() = DpapiEmailCredentialStore.ProtectForFixture(synthetic, reference)
            File.WriteAllBytes(credentialPath, envelope)
            Assert(Not Encoding.UTF8.GetString(envelope).Contains("synthetic-dpapi-secret"), "14_SECRET_NOT_CLEAR_ON_DISK")

            Dim store As New DpapiEmailCredentialStore(root, Directory.GetCurrentDirectory())
            Using found As EmailCredentialReadResult = store.Read(reference, databaseIdentity, 1, "TRANSACTIONAL")
                If found.State <> EmailCredentialState.Found Then
                    Throw New InvalidOperationException("DPAPI_STATE_" & found.State.ToString() & "_" & found.Code)
                End If
                Dim matches As Boolean = found.UseSecret(Of Boolean)(Function(value) String.Equals(value, "synthetic-dpapi-secret", StringComparison.Ordinal))
                Assert(found.State = EmailCredentialState.Found AndAlso matches, "15_DPAPI_LOCAL_MACHINE_ROUNDTRIP")
            End Using
            Using missing As EmailCredentialReadResult = store.Read(DpapiEmailCredentialStore.CreateReference(databaseIdentity, 1, "TRANSACTIONAL", New String("d"c, 32)), databaseIdentity, 1, "TRANSACTIONAL")
                Assert(missing.State = EmailCredentialState.Missing, "16_CREDENTIAL_FILE_MISSING")
            End Using
            Using invalidScope As EmailCredentialReadResult = store.Read(reference, databaseIdentity, 2, "TRANSACTIONAL")
                Assert(invalidScope.State = EmailCredentialState.Invalid, "17_CREDENTIAL_SCOPE_INVALID")
            End Using
            Assert(Not Path.GetFullPath(credentialPath).StartsWith(Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory), StringComparison.OrdinalIgnoreCase), "18_SECRET_OUTSIDE_WEBROOT")
        Finally
            Array.Clear(synthetic, 0, synthetic.Length)
            If Directory.Exists(root) Then Directory.Delete(root, True)
        End Try
    End Sub

    Private Sub TestTransportMatrix()
        Dim credential As New HarnessCredentialStore()

        Dim startFactory As New HarnessSmtpSessionFactory()
        Dim startTelemetry As New HarnessTelemetry()
        Dim startResolver As New HarnessReadyResolver() With {.Profile = Profile(EmailSecurityMode.StartTls, EmailAuthenticationMode.Password)}
        Dim startTransport As New MailKitEmailTransport(startResolver, credential, startFactory, startTelemetry)
        Dim startResult = startTransport.VerifyConnection("unused", 1, "TRANSACTIONAL", "corr-starttls")
        Assert(startResult.Status = EmailTransportOperationStatus.Succeeded AndAlso startFactory.Sessions(0).Options = SecureSocketOptions.StartTls, "19_STARTTLS_EXPLICIT")
        Assert(startFactory.Sessions(0).SendCount = 0 AndAlso startFactory.Sessions(0).DisconnectCount = 1, "20_VERIFY_NO_MAIL_COMMANDS_AND_QUIT")
        Assert(startResolver.VerificationResolveCount = 1 AndAlso startResolver.NormalResolveCount = 0, "20A_VERIFY_USES_ADMIN_RESOLUTION_ONLY")

        Dim implicitFactory As New HarnessSmtpSessionFactory()
        Dim implicitTransport As MailKitEmailTransport = BuildTransport(Profile(EmailSecurityMode.ImplicitTls, EmailAuthenticationMode.AppPassword), credential, implicitFactory, New HarnessTelemetry())
        Dim implicitResult = implicitTransport.VerifyConnection("unused", 1, "TRANSACTIONAL", "corr-implicit")
        Assert(implicitResult.Status = EmailTransportOperationStatus.Succeeded AndAlso implicitFactory.Sessions(0).Options = SecureSocketOptions.SslOnConnect, "21_IMPLICIT_TLS_EXPLICIT")

        AssertFailure(EmailTransportFailureKind.Tls, "22_SERVER_WITHOUT_TLS")
        AssertFailure(EmailTransportFailureKind.Certificate, "23_CERTIFICATE_REJECTED")
        AssertFailure(EmailTransportFailureKind.HostnameMismatch, "24_HOSTNAME_MISMATCH")
        AssertFailure(EmailTransportFailureKind.Authentication, "25_AUTHENTICATION_REJECTED", "authenticate")
        AssertFailure(EmailTransportFailureKind.Timeout, "26_TIMEOUT")

        credential.State = EmailCredentialState.Invalid
        Dim invalidCredentialFactory As New HarnessSmtpSessionFactory()
        Dim invalidCredentialTransport = BuildTransport(Profile(EmailSecurityMode.StartTls, EmailAuthenticationMode.Password), credential, invalidCredentialFactory, New HarnessTelemetry())
        Dim invalidCredentialResult = invalidCredentialTransport.VerifyConnection("unused", 1, "TRANSACTIONAL", "corr-invalid")
        Assert(invalidCredentialResult.FailureKind = EmailTransportFailureKind.Credential AndAlso invalidCredentialFactory.Sessions.Count = 0, "27_INVALID_CREDENTIAL_FAILS_BEFORE_CONNECT")
        credential.State = EmailCredentialState.Found

        Dim deliveryFactory As New HarnessSmtpSessionFactory()
        Dim deliveryTelemetry As New HarnessTelemetry()
        Dim deliveryResolver As New HarnessReadyResolver() With {.Profile = Profile(EmailSecurityMode.StartTls, EmailAuthenticationMode.Password)}
        Dim deliveryTransport As New MailKitEmailTransport(deliveryResolver, credential, deliveryFactory, deliveryTelemetry)
        Dim message As New MimeMessage()
        message.To.Add(New MailboxAddress("Recipient", "recipient@example.invalid"))
        message.Subject = "synthetic"
        message.Body = New TextPart("plain") With {.Text = "synthetic"}
        Dim result = deliveryTransport.Deliver(New EmailTransportRequest() With {.ConnectionString = "unused", .AziendaId = 1, .Purpose = "TRANSACTIONAL", .CorrelationId = "corr-delivery", .Message = message})
        Assert(result.Status = EmailTransportOperationStatus.Succeeded AndAlso deliveryFactory.Sessions(0).SendCount = 1, "28_SINGLE_SEND_NO_RETRY")
        Assert(deliveryResolver.NormalResolveCount = 1 AndAlso deliveryResolver.VerificationResolveCount = 0, "28A_DELIVERY_CANNOT_USE_ADMIN_RESOLUTION")
        Assert(Not String.Join("|", deliveryTelemetry.Lines.ToArray()).Contains(credential.Secret) AndAlso
               Not String.Join("|", deliveryTelemetry.Lines.ToArray()).Contains("recipient@example.invalid"), "29_SANITIZED_TELEMETRY")
    End Sub

    Private Sub TestLegacyEmptyTableGate()
        Dim source As New HarnessProfileSource()
        source.ResultFactory = Function(c, a, p) SourceResult(True, False)
        Dim resolver As New TenantEmailTransportProfileResolver(source, New HarnessIdentityProvider())
        Dim factory As New HarnessSmtpSessionFactory()
        Dim transport As New MailKitEmailTransport(resolver, New HarnessCredentialStore(), factory, New HarnessTelemetry())
        Dim result = transport.VerifyConnection("db-a", 1, "TRANSACTIONAL", "corr-empty")
        Assert(result.ProfileState = TenantEmailTransportProfileState.NotConfigured AndAlso factory.Sessions.Count = 0, "30_EMPTY_TABLE_LEGACY_UNTOUCHED")
    End Sub

    Private Sub AssertFailure(ByVal kind As EmailTransportFailureKind,
                              ByVal code As String,
                              Optional ByVal phase As String = "connect")
        Dim factory As New HarnessSmtpSessionFactory() With {.FailureKind = kind, .FailurePhase = phase}
        Dim transport = BuildTransport(Profile(EmailSecurityMode.StartTls, EmailAuthenticationMode.Password), New HarnessCredentialStore(), factory, New HarnessTelemetry())
        Dim result = transport.VerifyConnection("unused", 1, "TRANSACTIONAL", "corr-failure")
        Assert(result.FailureKind = kind AndAlso factory.Sessions(0).SendCount = 0, code)
    End Sub

    Private Function BuildTransport(ByVal profileValue As TenantEmailTransportProfile,
                                    ByVal credential As IEmailCredentialStore,
                                    ByVal factory As IEmailSmtpSessionFactory,
                                    ByVal telemetry As IEmailTransportTelemetrySink) As MailKitEmailTransport
        Return New MailKitEmailTransport(New HarnessReadyResolver() With {.Profile = profileValue}, credential, factory, telemetry)
    End Function

    Private Function Profile(ByVal security As EmailSecurityMode,
                             ByVal authentication As EmailAuthenticationMode) As TenantEmailTransportProfile
        Return New TenantEmailTransportProfile(New String("a"c, 64),
                                               1,
                                               1,
                                               "TRANSACTIONAL",
                                               "CUSTOM_SMTP",
                                               "smtp.example.invalid",
                                               If(security = EmailSecurityMode.StartTls, 587, 465),
                                               security,
                                               authentication,
                                               "synthetic-user",
                                               DpapiEmailCredentialStore.CreateReference(New String("a"c, 64), 1, "TRANSACTIONAL", New String("c"c, 32)),
                                               "sender@example.invalid",
                                               "Synthetic",
                                               "reply@example.invalid",
                                               "envelope@example.invalid",
                                               30)
    End Function

    Private Function ValidRecord(ByVal aziendaId As Integer,
                                 ByVal purpose As String,
                                 ByVal enabled As Boolean,
                                 ByVal connectionString As String,
                                 Optional ByVal verificationStatus As String = "VERIFIED") As TenantEmailTransportProfileRecord
        Dim identity As String = If(String.Equals(connectionString, "db-b", StringComparison.Ordinal), New String("b"c, 64), New String("a"c, 64))
        Return New TenantEmailTransportProfileRecord() With {
            .EmailTransportId = aziendaId,
            .AziendaId = aziendaId,
            .Purpose = purpose,
            .ProviderKind = "CUSTOM_SMTP",
            .Host = "smtp.example.invalid",
            .Port = 587,
            .SecurityMode = "STARTTLS",
            .AuthenticationMode = "PASSWORD",
            .Username = "synthetic-user",
            .CredentialReference = DpapiEmailCredentialStore.CreateReference(identity, aziendaId, purpose, New String("c"c, 32)),
            .FromAddress = "sender@example.invalid",
            .FromDisplayName = "Synthetic",
            .ReplyToAddress = "reply@example.invalid",
            .EnvelopeFromAddress = "envelope@example.invalid",
            .TimeoutSeconds = 30,
            .Enabled = enabled,
            .VerificationStatus = verificationStatus,
            .LastVerifiedAtUtc = If(String.Equals(verificationStatus, "VERIFIED", StringComparison.Ordinal), New Nullable(Of DateTime)(DateTime.UtcNow), Nothing),
            .LastVerificationCode = If(String.Equals(verificationStatus, "VERIFIED", StringComparison.Ordinal), "SYNTHETIC_OK", String.Empty)
        }
    End Function

    Private Function SourceResult(ByVal schemaAvailable As Boolean,
                                  ByVal technicalFailure As Boolean,
                                  ParamArray ByVal records() As TenantEmailTransportProfileRecord) As EmailTransportProfileSourceResult
        Dim result As New EmailTransportProfileSourceResult() With {.SchemaAvailable = schemaAvailable, .TechnicalFailure = technicalFailure}
        If records IsNot Nothing Then
            For Each record In records
                result.Records.Add(record)
            Next
        End If
        Return result
    End Function

    Private Sub Assert(ByVal condition As Boolean, ByVal code As String)
        If Not condition Then Throw New InvalidOperationException(code)
        _passed += 1
        Console.WriteLine("PASS " & code)
    End Sub
End Module
