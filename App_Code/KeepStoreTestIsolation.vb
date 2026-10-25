Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Security.AccessControl
Imports System.Security.Principal
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Hosting
Imports System.Xml

Friend Enum KeepStoreIsolationMode
    Native = 0
    Capture = 1
    Denied = 2
End Enum

Friend NotInheritable Class KeepStoreIsolationIdentity
    Public Machine As String
    Public SiteId As String
    Public ApplicationId As String
    Public Pool As String
    Public PhysicalPath As String
    Public PoolSid As String
    Public ExpectedCaptureDirectory As String
End Class

Friend NotInheritable Class KeepStoreIsolationDescriptor
    Public Machine As String
    Public SiteId As String
    Public ApplicationId As String
    Public Pool As String
    Public PhysicalPath As String
    Public CaptureDirectory As String
End Class

Friend Interface IKeepStoreTestReceiptSink
    Sub Capture(ByVal request As EmailTransportRequest)
End Interface

Friend Interface IKeepStoreIsolationEnvironment
    Function ReadMarker() As String
    Function ReadIdentity() As KeepStoreIsolationIdentity
    Function ReadDescriptor(ByVal identity As KeepStoreIsolationIdentity) As KeepStoreIsolationDescriptor
    Function OpenSink(ByVal identity As KeepStoreIsolationIdentity,
                      ByVal descriptor As KeepStoreIsolationDescriptor) As IKeepStoreTestReceiptSink
End Interface

Friend NotInheritable Class KeepStoreIsolationDecision
    Public ReadOnly Mode As KeepStoreIsolationMode
    Public ReadOnly Code As String
    Public ReadOnly Sink As IKeepStoreTestReceiptSink

    Public Sub New(ByVal value As KeepStoreIsolationMode, ByVal reason As String,
                   Optional ByVal receiptSink As IKeepStoreTestReceiptSink = Nothing)
        Mode = value
        Code = reason
        Sink = receiptSink
    End Sub
End Class

Public NotInheritable Class KeepStoreTestIsolation
    Public Const ActivationVariable As String = "KEEPSTORE_TEST_ISOLATION"
    Public Const CaptureCode As String = "CAPTURED_TEST_ONLY"

    Private Sub New()
    End Sub

    Friend Shared Function ResolveCurrent() As KeepStoreIsolationDecision
        Return Evaluate(New KeepStoreServerIsolationEnvironment())
    End Function

    Friend Shared Function Evaluate(ByVal environment As IKeepStoreIsolationEnvironment) As KeepStoreIsolationDecision
        Try
            If environment Is Nothing Then Return Denied("TEST_ENVIRONMENT_UNAVAILABLE")
            Dim marker As String = environment.ReadMarker()
            ' Unmarked production never reads IIS identity, descriptors, sinks or credentials here.
            If String.IsNullOrEmpty(marker) Then
                Return New KeepStoreIsolationDecision(KeepStoreIsolationMode.Native, "NATIVE")
            End If
            If Not String.Equals(marker, "SMOKE", StringComparison.Ordinal) Then Return Denied("TEST_MARKER_INVALID")

            Dim identity As KeepStoreIsolationIdentity = environment.ReadIdentity()
            If identity Is Nothing OrElse
               String.IsNullOrWhiteSpace(identity.Machine) OrElse
               Not Regex.IsMatch(Convert.ToString(identity.SiteId), "^[1-9][0-9]{0,9}$") OrElse
               String.IsNullOrWhiteSpace(identity.Pool) OrElse
               Not String.Equals(identity.ApplicationId, "/LM/W3SVC/" & identity.SiteId & "/ROOT", StringComparison.OrdinalIgnoreCase) OrElse
               String.IsNullOrWhiteSpace(identity.PhysicalPath) OrElse
               Not Regex.IsMatch(Convert.ToString(identity.PoolSid), "^S-1-5-82-[0-9-]+$") Then
                Return Denied("TEST_IDENTITY_INVALID")
            End If

            Dim descriptor As KeepStoreIsolationDescriptor = environment.ReadDescriptor(identity)
            If descriptor Is Nothing OrElse
               Not String.Equals(descriptor.Machine, identity.Machine, StringComparison.OrdinalIgnoreCase) OrElse
               Not String.Equals(descriptor.SiteId, identity.SiteId, StringComparison.Ordinal) OrElse
               Not String.Equals(descriptor.ApplicationId, identity.ApplicationId, StringComparison.OrdinalIgnoreCase) OrElse
               Not String.Equals(descriptor.Pool, identity.Pool, StringComparison.Ordinal) OrElse
               Not SameDirectory(descriptor.PhysicalPath, identity.PhysicalPath) OrElse
               Not SameDirectory(descriptor.CaptureDirectory, identity.ExpectedCaptureDirectory) Then
                Return Denied("TEST_BINDING_INVALID")
            End If
            Dim sink As IKeepStoreTestReceiptSink = environment.OpenSink(identity, descriptor)
            If sink Is Nothing Then Return Denied("TEST_SINK_UNAVAILABLE")
            Return New KeepStoreIsolationDecision(KeepStoreIsolationMode.Capture, CaptureCode, sink)
        Catch
            Return Denied("TEST_ATTESTATION_UNAVAILABLE")
        End Try
    End Function

    Private Shared Function Denied(ByVal code As String) As KeepStoreIsolationDecision
        Return New KeepStoreIsolationDecision(KeepStoreIsolationMode.Denied, code)
    End Function

    Friend Shared Function SameDirectory(ByVal first As String, ByVal second As String) As Boolean
        If String.IsNullOrWhiteSpace(first) OrElse String.IsNullOrWhiteSpace(second) Then Return False
        Return String.Equals(Path.GetFullPath(first).TrimEnd(Path.DirectorySeparatorChar),
                             Path.GetFullPath(second).TrimEnd(Path.DirectorySeparatorChar),
                             StringComparison.OrdinalIgnoreCase)
    End Function

    Public Shared Sub DemandRequestReady(ByVal context As HttpContext)
        EnforceRequest(context, ResolveCurrent())
    End Sub

    Friend Shared Sub EnforceRequest(ByVal context As HttpContext, ByVal decision As KeepStoreIsolationDecision)
        If decision IsNot Nothing AndAlso decision.Mode <> KeepStoreIsolationMode.Denied Then Return
        If context Is Nothing Then Throw New HttpException(503, "TEST_ISOLATION_NOT_READY")
        context.Response.Clear()
        context.Response.StatusCode = 503
        context.Response.TrySkipIisCustomErrors = True
        context.Response.Cache.SetNoStore()
        context.Response.ContentType = "text/plain; charset=utf-8"
        context.Response.Write("TEST_ISOLATION_NOT_READY")
        ' End aborts the handler; CompleteRequest alone would not stop Page_Load.
        ' The Global.asax caller is deliberately outside its legacy swallowing Catch.
        context.Response.End()
        Throw New HttpException(503, "TEST_ISOLATION_NOT_READY")
    End Sub

    Friend Shared Function NativeSmtpAllowed() As Boolean
        Try
            Return String.IsNullOrEmpty(Environment.GetEnvironmentVariable(ActivationVariable, EnvironmentVariableTarget.Process))
        Catch
            Return False
        End Try
    End Function

    Friend Shared Sub DemandNativeSmtp()
        If Not NativeSmtpAllowed() Then Throw New InvalidOperationException("TEST_NATIVE_SMTP_FORBIDDEN")
    End Sub

    Friend Shared Function TestDeliveryResult(ByVal code As String,
                                             Optional ByVal captured As Boolean = False) As EmailDeliveryResult
        Return New EmailDeliveryResult() With {
            .Status = If(captured, EmailTransportOperationStatus.Succeeded, EmailTransportOperationStatus.Rejected),
            .ProfileState = TenantEmailTransportProfileState.NotOperational,
            .FailureKind = If(captured, EmailTransportFailureKind.None, EmailTransportFailureKind.NotOperational),
            .Phase = If(captured, "test-capture", "test-isolation"),
            .Code = code,
            .AuthenticationMode = "N/A",
            .SecurityMode = "NO_SMTP",
            .TimestampUtc = DateTime.UtcNow,
            .CorrelationId = String.Empty
        }
    End Function

    Friend Shared Function TestVerificationRejected() As EmailConnectionVerificationResult
        Return New EmailConnectionVerificationResult() With {
            .Status = EmailTransportOperationStatus.Rejected,
            .ProfileState = TenantEmailTransportProfileState.NotOperational,
            .FailureKind = EmailTransportFailureKind.NotOperational,
            .Phase = "test-isolation",
            .Code = "TEST_NATIVE_SMTP_FORBIDDEN",
            .AuthenticationMode = "N/A",
            .SecurityMode = "NO_SMTP",
            .TimestampUtc = DateTime.UtcNow,
            .CorrelationId = String.Empty
        }
    End Function
End Class

Friend NotInheritable Class KeepStoreTestCaptureTransport
    Implements IEmailTransport

    Private ReadOnly _decision As KeepStoreIsolationDecision

    Public Sub New(ByVal decision As KeepStoreIsolationDecision)
        _decision = decision
    End Sub

    Public Function Deliver(ByVal request As EmailTransportRequest) As EmailDeliveryResult Implements IEmailTransport.Deliver
        If _decision Is Nothing OrElse _decision.Mode <> KeepStoreIsolationMode.Capture OrElse _decision.Sink Is Nothing Then
            Return KeepStoreTestIsolation.TestDeliveryResult("TEST_ISOLATION_NOT_READY")
        End If
        If request Is Nothing OrElse request.Message Is Nothing Then
            Return KeepStoreTestIsolation.TestDeliveryResult("TEST_CAPTURE_REQUEST_INVALID")
        End If
        Try
            _decision.Sink.Capture(request)
            Return KeepStoreTestIsolation.TestDeliveryResult(KeepStoreTestIsolation.CaptureCode, True)
        Catch
            Return KeepStoreTestIsolation.TestDeliveryResult("TEST_CAPTURE_UNAVAILABLE")
        End Try
    End Function

    Public Function VerifyConnection(ByVal connectionString As String, ByVal aziendaId As Integer,
                                     ByVal purpose As String, ByVal correlationId As String) As EmailConnectionVerificationResult Implements IEmailTransport.VerifyConnection
        Return KeepStoreTestIsolation.TestVerificationRejected()
    End Function
End Class

Friend NotInheritable Class KeepStoreServerIsolationEnvironment
    Implements IKeepStoreIsolationEnvironment

    Public Function ReadMarker() As String Implements IKeepStoreIsolationEnvironment.ReadMarker
        Return Environment.GetEnvironmentVariable(KeepStoreTestIsolation.ActivationVariable, EnvironmentVariableTarget.Process)
    End Function

    Public Function ReadIdentity() As KeepStoreIsolationIdentity Implements IKeepStoreIsolationEnvironment.ReadIdentity
        If Not HostingEnvironment.IsHosted Then Return Nothing
        Dim applicationId As String = Convert.ToString(HttpRuntime.AppDomainAppId)
        Dim match As Match = Regex.Match(applicationId, "^/LM/W3SVC/([1-9][0-9]{0,9})/ROOT$", RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant)
        If Not match.Success Then Return Nothing
        Dim pool As String = Environment.GetEnvironmentVariable("APP_POOL_ID", EnvironmentVariableTarget.Process)
        If String.IsNullOrWhiteSpace(pool) Then Return Nothing
        Dim expectedSid As SecurityIdentifier =
            DirectCast(New NTAccount("IIS APPPOOL", pool).Translate(GetType(SecurityIdentifier)), SecurityIdentifier)
        Using current As WindowsIdentity = WindowsIdentity.GetCurrent()
            If current.User Is Nothing OrElse Not current.User.Equals(expectedSid) Then Return Nothing
        End Using
        Return New KeepStoreIsolationIdentity() With {
            .Machine = Environment.MachineName,
            .SiteId = match.Groups(1).Value,
            .ApplicationId = applicationId,
            .Pool = pool,
            .PhysicalPath = HostingEnvironment.ApplicationPhysicalPath,
            .PoolSid = expectedSid.Value,
            .ExpectedCaptureDirectory = Path.Combine(IsolationRoot(), "captures", "site-" & match.Groups(1).Value)
        }
    End Function

    Private Shared Function IsolationRoot() As String
        Return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "KeepStore", "TestIsolation")
    End Function

    Public Function ReadDescriptor(ByVal identity As KeepStoreIsolationIdentity) As KeepStoreIsolationDescriptor Implements IKeepStoreIsolationEnvironment.ReadDescriptor
        Dim root As String = IsolationRoot()
        KeepStoreIsolationFileTrust.DemandDirectory(Path.GetDirectoryName(root), identity.PoolSid, False)
        KeepStoreIsolationFileTrust.DemandDirectory(root, identity.PoolSid, False)
        Dim descriptorPath As String = Path.Combine(root, "site-" & identity.SiteId & ".xml")
        KeepStoreIsolationFileTrust.DemandFile(descriptorPath, identity.PoolSid)
        Dim settings As New XmlReaderSettings() With {.DtdProcessing = DtdProcessing.Prohibit, .XmlResolver = Nothing, .MaxCharactersInDocument = 16384}
        Using input As New FileStream(descriptorPath, FileMode.Open, FileAccess.Read, FileShare.Read)
            If input.Length > 16384 Then Throw New InvalidDataException("TEST_DESCRIPTOR_INVALID")
            Using reader As XmlReader = XmlReader.Create(input, settings)
                Dim document As New XmlDocument() With {.XmlResolver = Nothing}
                document.Load(reader)
                Dim descriptor As KeepStoreIsolationDescriptor = ParseDescriptor(document)
                Dim expectedCapture As String = Path.Combine(root, "captures", "site-" & identity.SiteId)
                If Not KeepStoreTestIsolation.SameDirectory(descriptor.CaptureDirectory, expectedCapture) Then
                    Throw New InvalidDataException("TEST_CAPTURE_PATH_INVALID")
                End If
                Return descriptor
            End Using
        End Using
    End Function

    Friend Shared Function ParseDescriptor(ByVal document As XmlDocument) As KeepStoreIsolationDescriptor
        Dim element As XmlElement = document.DocumentElement
        If element Is Nothing OrElse element.Name <> "testIsolation" OrElse element.Attributes.Count <> 8 OrElse
           element.GetAttribute("version") <> "1" OrElse element.GetAttribute("mode") <> "SMOKE" OrElse
           element.HasChildNodes Then Throw New InvalidDataException("TEST_DESCRIPTOR_INVALID")
        Dim allowed As New HashSet(Of String)(StringComparer.Ordinal) From {
            "version", "mode", "machine", "siteId", "applicationId", "pool", "physicalPath", "captureDirectory"}
        For Each attribute As XmlAttribute In element.Attributes
            If Not allowed.Contains(attribute.Name) OrElse String.IsNullOrWhiteSpace(attribute.Value) Then
                Throw New InvalidDataException("TEST_DESCRIPTOR_INVALID")
            End If
        Next
        Return New KeepStoreIsolationDescriptor() With {
            .Machine = element.GetAttribute("machine"), .SiteId = element.GetAttribute("siteId"),
            .ApplicationId = element.GetAttribute("applicationId"), .Pool = element.GetAttribute("pool"),
            .PhysicalPath = element.GetAttribute("physicalPath"), .CaptureDirectory = element.GetAttribute("captureDirectory")}
    End Function

    Public Function OpenSink(ByVal identity As KeepStoreIsolationIdentity,
                             ByVal descriptor As KeepStoreIsolationDescriptor) As IKeepStoreTestReceiptSink Implements IKeepStoreIsolationEnvironment.OpenSink
        KeepStoreIsolationFileTrust.DemandDirectory(Path.GetDirectoryName(descriptor.CaptureDirectory), identity.PoolSid, False)
        Dim sink As New KeepStoreFileTestReceiptSink(descriptor.CaptureDirectory, identity.PoolSid)
        sink.Probe()
        Return sink
    End Function
End Class

Friend NotInheritable Class KeepStoreIsolationFileTrust
    Private Sub New()
    End Sub

    Friend Shared Function HasTrustedWriters(ByVal security As FileSystemSecurity, ByVal poolSid As String,
                                            ByVal allowPoolWrite As Boolean) As Boolean
        Dim raw As New RawSecurityDescriptor(security.GetSecurityDescriptorBinaryForm(), 0)
        If raw.DiscretionaryAcl Is Nothing Then Return False
        For Each entry As GenericAce In raw.DiscretionaryAcl
            Dim common As CommonAce = TryCast(entry, CommonAce)
            If common Is Nothing OrElse common.IsCallback Then Return False
        Next
        Dim owner As SecurityIdentifier = TryCast(security.GetOwner(GetType(SecurityIdentifier)), SecurityIdentifier)
        If owner Is Nothing OrElse Not IsAdministrator(owner) Then Return False
        Dim writeRights As FileSystemRights = FileSystemRights.Write Or
            FileSystemRights.ChangePermissions Or FileSystemRights.TakeOwnership Or FileSystemRights.Delete Or
            FileSystemRights.DeleteSubdirectoriesAndFiles
        For Each entry As FileSystemAccessRule In security.GetAccessRules(True, True, GetType(SecurityIdentifier))
            If entry.AccessControlType <> AccessControlType.Allow OrElse (entry.FileSystemRights And writeRights) = 0 Then Continue For
            Dim sid As SecurityIdentifier = DirectCast(entry.IdentityReference, SecurityIdentifier)
            If IsAdministrator(sid) Then Continue For
            If Not allowPoolWrite OrElse Not String.Equals(sid.Value, poolSid, StringComparison.Ordinal) Then Return False
            If (entry.FileSystemRights And (FileSystemRights.ChangePermissions Or FileSystemRights.TakeOwnership)) <> 0 Then Return False
        Next
        Return True
    End Function

    Private Shared Function IsAdministrator(ByVal sid As SecurityIdentifier) As Boolean
        Return sid.IsWellKnown(WellKnownSidType.BuiltinAdministratorsSid) OrElse sid.IsWellKnown(WellKnownSidType.LocalSystemSid)
    End Function

    Private Shared Sub DemandNoReparse(ByVal target As String)
        Dim current As String = Path.GetFullPath(target)
        While Not String.IsNullOrEmpty(current)
            If (File.GetAttributes(current) And FileAttributes.ReparsePoint) <> 0 Then
                Throw New InvalidDataException("TEST_REPARSE_FORBIDDEN")
            End If
            Dim parent As String = Path.GetDirectoryName(current.TrimEnd(Path.DirectorySeparatorChar))
            If String.Equals(parent, current, StringComparison.OrdinalIgnoreCase) Then Exit While
            current = parent
        End While
    End Sub

    Friend Shared Sub DemandDirectory(ByVal directory As String, ByVal poolSid As String, ByVal allowPoolWrite As Boolean)
        DemandNoReparse(directory)
        If Not HasTrustedWriters(System.IO.Directory.GetAccessControl(directory), poolSid, allowPoolWrite) Then
            Throw New UnauthorizedAccessException("TEST_DIRECTORY_UNTRUSTED")
        End If
    End Sub

    Friend Shared Sub DemandFile(ByVal filename As String, ByVal poolSid As String)
        DemandNoReparse(filename)
        If Not HasTrustedWriters(File.GetAccessControl(filename), poolSid, False) Then
            Throw New UnauthorizedAccessException("TEST_DESCRIPTOR_UNTRUSTED")
        End If
    End Sub
End Class

Friend NotInheritable Class KeepStoreFileTestReceiptSink
    Implements IKeepStoreTestReceiptSink

    Private ReadOnly _directory As String
    Private ReadOnly _poolSid As String

    Public Sub New(ByVal directory As String, ByVal poolSid As String)
        _directory = directory
        _poolSid = poolSid
    End Sub

    Public Sub Probe()
        KeepStoreIsolationFileTrust.DemandDirectory(_directory, _poolSid, True)
        Dim probePath As String = Path.Combine(_directory, "probe-" & Guid.NewGuid().ToString("N") & ".tmp")
        Using probe As New FileStream(probePath, FileMode.CreateNew, FileAccess.Write, FileShare.None, 1, FileOptions.DeleteOnClose)
            probe.WriteByte(0)
        End Using
    End Sub

    Public Sub Capture(ByVal request As EmailTransportRequest) Implements IKeepStoreTestReceiptSink.Capture
        KeepStoreIsolationFileTrust.DemandDirectory(_directory, _poolSid, True)
        WriteReceipt(_directory, BuildReceipt(request))
    End Sub

    Friend Shared Function BuildReceipt(ByVal request As EmailTransportRequest) As String
        Dim toCount As Integer = 0
        Dim ccCount As Integer = 0
        Dim bccCount As Integer = 0
        For Each item In request.Message.To.Mailboxes
            toCount += 1
        Next
        For Each item In request.Message.Cc.Mailboxes
            ccCount += 1
        Next
        For Each item In request.Message.Bcc.Mailboxes
            bccCount += 1
        Next
        ' No subject, body, address, attachment, tenant/user ID or caller correlation is persisted.
        Return "CAPTURED_TEST_ONLY" & Environment.NewLine &
            "toCount=" & toCount.ToString(CultureInfo.InvariantCulture) & Environment.NewLine &
            "ccCount=" & ccCount.ToString(CultureInfo.InvariantCulture) & Environment.NewLine &
            "bccCount=" & bccCount.ToString(CultureInfo.InvariantCulture) & Environment.NewLine &
            "administrativeCopyRequested=" & request.AdministrativeCopyFromProfileReplyTo.ToString() & Environment.NewLine &
            "primaryFromProfileRequested=" & request.PrimaryRecipientFromProfileReplyTo.ToString()
    End Function

    Friend Shared Sub WriteReceipt(ByVal directory As String, ByVal receipt As String)
        Dim filename As String = Path.Combine(directory, "capture-" & Guid.NewGuid().ToString("N") & ".txt")
        Using output As New FileStream(filename, FileMode.CreateNew, FileAccess.Write, FileShare.None)
            Dim bytes As Byte() = New UTF8Encoding(False).GetBytes(receipt)
            output.Write(bytes, 0, bytes.Length)
        End Using
    End Sub
End Class
