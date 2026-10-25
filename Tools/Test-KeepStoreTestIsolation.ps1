[CmdletBinding()]
param([string]$RepositoryRoot, [Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'ISOLATION_TEST_REQUIRES_PS51'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
if($EvidenceDirectory.StartsWith($RepositoryRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'EVIDENCE_MUST_BE_OUTSIDE_REPOSITORY'}
[IO.Directory]::CreateDirectory($EvidenceDirectory)|Out-Null
$work=Join-Path ([IO.Path]::GetTempPath()) ('KeepStore-IsolationFixture-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work)|Out-Null
$utf8=New-Object Text.UTF8Encoding($false)
$vbc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$roleBefore=[Environment]::GetEnvironmentVariable('KEEPSTORE_TEST_ISOLATION','Process')
function Write-Fixture([string]$name,[string]$text){[IO.File]::WriteAllText((Join-Path $work $name),$text,$utf8)}
try {
    $app=Join-Path $work 'application'
    foreach($folder in @($app,(Join-Path $app 'bin'),(Join-Path $app 'App_Code'),(Join-Path $work 'compile-cache'))){[IO.Directory]::CreateDirectory($folder)|Out-Null}
    $bridge=@'
Imports System
Imports System.IO
Imports System.Threading
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.Compilation
Public Class IsolationPipelineBridge
    Inherits MarshalByRefObject
    Public Overrides Function InitializeLifetimeService() As Object
        Return Nothing
    End Function
    Public Function Run(page As String, verb As String, marker As String) As String
        Environment.SetEnvironmentVariable("KEEPSTORE_TEST_ISOLATION", marker, EnvironmentVariableTarget.Process)
        Dim output As New StringWriter()
        Dim worker As New IsolationWorker(page, verb, output)
        HttpRuntime.ProcessRequest(worker)
        If Not worker.Done.WaitOne(30000) Then Throw New Exception("PIPELINE_TIMEOUT")
        Dim state As Type = BuildManager.GetType("FixtureMutationState", True)
        Dim writes As Integer = CInt(state.GetField("Writes").GetValue(Nothing))
        Return worker.Status.ToString() & "|" & writes.ToString() & "|" & If(output.ToString().Contains("SYNTHETIC_APPLICATION_EXECUTED"), "BODY", "NO_BODY")
    End Function
End Class
Public Class IsolationWorker
    Inherits SimpleWorkerRequest
    Private ReadOnly _verb As String
    Public ReadOnly Done As New ManualResetEvent(False)
    Public Status As Integer = 200
    Public Sub New(page As String, verb As String, output As TextWriter)
        MyBase.New(page, "", output)
        _verb=verb
    End Sub
    Public Overrides Function GetHttpVerbName() As String
        Return _verb
    End Function
    Public Overrides Function GetServerName() As String
        Return "spoofed-smoke.fixture.invalid"
    End Function
    Public Overrides Function GetKnownRequestHeader(index As Integer) As String
        If index=HeaderHost Then Return "spoofed-smoke.fixture.invalid:8443"
        Return MyBase.GetKnownRequestHeader(index)
    End Function
    Public Overrides Function GetUnknownRequestHeaders() As String()()
        Return New String()(){New String(){"KEEPSTORE_TEST_ISOLATION","SMOKE"},New String(){"APP_POOL_ID","fixture-pool"},New String(){"X-Forwarded-Host","smoke.fixture.invalid"}}
    End Function
    Public Overrides Sub SendStatus(code As Integer, description As String)
        Status=code
    End Sub
    Public Overrides Sub EndOfRequest()
        MyBase.EndOfRequest()
        Done.Set()
    End Sub
End Class
'@
    Write-Fixture 'Bridge.vb' $bridge
    & $vbc /nologo /target:library /optionstrict+ ('/out:'+(Join-Path $work 'IsolationBridge.dll')) /reference:System.dll,System.Web.dll (Join-Path $work 'Bridge.vb')
    if($LASTEXITCODE -ne 0){throw 'BRIDGE_COMPILE_FAILED'}
    Copy-Item -LiteralPath (Join-Path $work 'IsolationBridge.dll') -Destination (Join-Path $app 'bin\IsolationBridge.dll')
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'Global.asax') -Destination (Join-Path $app 'Global.asax')
    foreach($name in @('KeepStoreTestIsolation.vb','TenantEmailTransportContracts.vb')){Copy-Item -LiteralPath (Join-Path $RepositoryRoot ('App_Code\'+$name)) -Destination (Join-Path $app ('App_Code\'+$name))}
    $stubs=@'
Imports System
Imports System.Web
Public Class StorefrontSeoTenantIdentity
End Class
Public Class StorefrontSeoTenantContext
    Public Shared Function Resolve(context As HttpContext) As StorefrontSeoTenantIdentity
        Return New StorefrontSeoTenantIdentity()
    End Function
End Class
Public Class StorefrontCanonicalHostPolicy
    Public Shared Function BuildCanonicalRedirect(url As Uri, local As Boolean, tenant As StorefrontSeoTenantIdentity) As String
        Return Nothing
    End Function
    Public Shared Function IsNoIndexPath(path As String) As Boolean
        Return False
    End Function
End Class
Public Class FixtureMutationState
    Public Shared Writes As Integer
End Class
'@
    [IO.File]::WriteAllText((Join-Path $app 'App_Code\UnrelatedSeoStubs.vb'),$stubs,$utf8)
    [IO.File]::WriteAllText((Join-Path $app 'mutate.aspx'),'<%@ Page Language="VB" %><script runat="server">Sub Page_Load(sender As Object,e As EventArgs)' + [Environment]::NewLine + 'FixtureMutationState.Writes += 1 : Response.Write("SYNTHETIC_APPLICATION_EXECUTED")' + [Environment]::NewLine + 'End Sub</script>',$utf8)
    $cache=[Security.SecurityElement]::Escape((Join-Path $work 'compile-cache'))
    [IO.File]::WriteAllText((Join-Path $app 'web.config'),('<configuration><system.web><compilation debug="false" targetFramework="4.8" tempDirectory="'+$cache+'"/><httpRuntime targetFramework="4.8"/><customErrors mode="On"/></system.web></configuration>'),$utf8)

    # Reuse existing SMTP/profile/credential doubles, without executing the old suite.
    $existing=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Tools\EmailTransportRuntimeCoreHarness.vb'))
    $boundary=$existing.IndexOf('Public Module EmailTransportRuntimeCoreHarness',[StringComparison]::Ordinal)
    if($boundary -lt 0){throw 'EMAIL_DOUBLES_BOUNDARY_MISSING'}
    Write-Fixture 'ExistingEmailDoubles.vb' $existing.Substring(0,$boundary)
    $harness=@'
Imports System
Imports System.IO
Imports System.Xml
Imports System.Web.Hosting
Imports System.Reflection
Imports System.Collections.Generic
Imports System.Security.AccessControl
Imports System.Security.Principal
Imports MimeKit
Imports MailKit.Security
Friend Class FixtureSink
    Implements IKeepStoreTestReceiptSink
    Public Fail As Boolean
    Public Captures As Integer
    Public LastReceipt As String
    Public Sub Capture(request As EmailTransportRequest) Implements IKeepStoreTestReceiptSink.Capture
        Captures+=1
        If Fail Then Throw New IOException("SYNTHETIC_SINK_FAILURE")
        LastReceipt=KeepStoreFileTestReceiptSink.BuildReceipt(request)
    End Sub
End Class
Friend Class FixtureEnvironment
    Implements IKeepStoreIsolationEnvironment
    Public Marker As String="SMOKE"
    Public Identity As KeepStoreIsolationIdentity
    Public Descriptor As KeepStoreIsolationDescriptor
    Public Sink As New FixtureSink()
    Public IdentityReads, DescriptorReads, SinkOpens As Integer
    Public FailIdentity, FailDescriptor, FailSink, NullSink As Boolean
    Public Sub New()
        Identity=New KeepStoreIsolationIdentity() With {.Machine="fixture-machine",.SiteId="7",.ApplicationId="/LM/W3SVC/7/ROOT",.Pool="fixture-pool",.PhysicalPath="C:\fixture\application",.PoolSid="S-1-5-82-1-2-3-4-5",.ExpectedCaptureDirectory="C:\fixture\captures"}
        Descriptor=New KeepStoreIsolationDescriptor() With {.Machine=Identity.Machine,.SiteId=Identity.SiteId,.ApplicationId=Identity.ApplicationId,.Pool=Identity.Pool,.PhysicalPath=Identity.PhysicalPath,.CaptureDirectory=Identity.ExpectedCaptureDirectory}
    End Sub
    Public Function ReadMarker() As String Implements IKeepStoreIsolationEnvironment.ReadMarker
        Return Marker
    End Function
    Public Function ReadIdentity() As KeepStoreIsolationIdentity Implements IKeepStoreIsolationEnvironment.ReadIdentity
        IdentityReads+=1
        If FailIdentity Then Throw New UnauthorizedAccessException("SYNTHETIC_IDENTITY")
        Return Identity
    End Function
    Public Function ReadDescriptor(identity As KeepStoreIsolationIdentity) As KeepStoreIsolationDescriptor Implements IKeepStoreIsolationEnvironment.ReadDescriptor
        DescriptorReads+=1
        If FailDescriptor Then Throw New UnauthorizedAccessException("SYNTHETIC_DESCRIPTOR")
        Return Descriptor
    End Function
    Public Function OpenSink(identity As KeepStoreIsolationIdentity, descriptor As KeepStoreIsolationDescriptor) As IKeepStoreTestReceiptSink Implements IKeepStoreIsolationEnvironment.OpenSink
        SinkOpens+=1
        If FailSink Then Throw New IOException("SYNTHETIC_SINK")
        If NullSink Then Return Nothing
        Return Sink
    End Function
End Class
Public Module IsolationHarness
    Private ReadOnly Checks As New List(Of String)()
    Private Sub Check(value As Boolean,name As String)
        If Not value Then Throw New Exception("ASSERT_"+name)
        Checks.Add(name)
    End Sub
    Public Sub Main(args As String())
        Try
            Environment.SetEnvironmentVariable(KeepStoreTestIsolation.ActivationVariable,Nothing,EnvironmentVariableTarget.Process)
            TestPolicy()
            TestDescriptorAndAcl()
            TestCaptureAndFacade(args(0))
            TestNativeBoundary()
            TestPipeline(args(1))
            File.WriteAllLines(args(2),Checks.ToArray())
            Console.WriteLine("KEEPSTORE_TEST_ISOLATION_PASS checks="+Checks.Count.ToString())
        Catch ex As Exception
            Console.WriteLine("ISOLATION_FAILURE type="+ex.GetType().Name+" code="+If(ex.Message.StartsWith("ASSERT_",StringComparison.Ordinal),ex.Message,"SYNTHETIC_TEST_FAILURE"))
            Console.WriteLine("ISOLATION_FAILURE_LAST_CHECK="+If(Checks.Count=0,"NONE",Checks(Checks.Count-1))+" method="+If(ex.TargetSite Is Nothing,"NONE",ex.TargetSite.Name))
            Environment.ExitCode=1
        Finally
            Environment.SetEnvironmentVariable(KeepStoreTestIsolation.ActivationVariable,Nothing,EnvironmentVariableTarget.Process)
        End Try
    End Sub
    Private Sub TestPolicy()
        For Each marker As String In New String(){Nothing,""}
            Dim env As New FixtureEnvironment() With {.Marker=marker,.FailIdentity=True,.FailDescriptor=True,.FailSink=True}
            Dim d=KeepStoreTestIsolation.Evaluate(env)
            Check(d.Mode=KeepStoreIsolationMode.Native,"NATIVE_UNMARKED_"+If(marker Is Nothing,"NULL","EMPTY"))
            Check(env.IdentityReads=0 AndAlso env.DescriptorReads=0 AndAlso env.SinkOpens=0,"NATIVE_NO_ATTESTATION_IO_"+If(marker Is Nothing,"NULL","EMPTY"))
        Next
        For Each marker As String In New String(){"smoke"," SMOKE","SMOKE ","ON"," ","PRODUCTION"}
            Dim env As New FixtureEnvironment() With {.Marker=marker}
            Check(KeepStoreTestIsolation.Evaluate(env).Mode=KeepStoreIsolationMode.Denied,"INVALID_MARKER_"+Checks.Count.ToString())
            Check(env.IdentityReads=0 AndAlso env.DescriptorReads=0 AndAlso env.SinkOpens=0,"INVALID_MARKER_NO_IO_"+Checks.Count.ToString())
        Next
        Dim valid As New FixtureEnvironment()
        Check(KeepStoreTestIsolation.Evaluate(valid).Mode=KeepStoreIsolationMode.Capture,"EXACT_BINDING_CAPTURE")
        Check(valid.IdentityReads=1 AndAlso valid.DescriptorReads=1 AndAlso valid.SinkOpens=1,"CAPTURE_SINGLE_ATTESTATION")
        Dim mutations As New List(Of Action(Of FixtureEnvironment)) From {
            Sub(e) e.Identity=Nothing,
            Sub(e) e.Identity.Machine="",
            Sub(e) e.Identity.SiteId="0",
            Sub(e) e.Identity.ApplicationId="/LM/W3SVC/8/ROOT",
            Sub(e) e.Identity.ApplicationId="/LM/W3SVC/7/ROOT/subapp",
            Sub(e) e.Identity.Pool="",
            Sub(e) e.Identity.PhysicalPath="",
            Sub(e) e.Identity.PoolSid="S-1-5-21-1-2-3-4",
            Sub(e) e.Identity.ExpectedCaptureDirectory=Nothing,
            Sub(e) e.Descriptor=Nothing,
            Sub(e) e.Descriptor.Machine="another-machine",
            Sub(e) e.Descriptor.SiteId="8",
            Sub(e) e.Descriptor.ApplicationId="/LM/W3SVC/8/ROOT",
            Sub(e) e.Descriptor.Pool="another-pool",
            Sub(e) e.Descriptor.PhysicalPath="C:\another\application",
            Sub(e) e.Descriptor.CaptureDirectory="C:\outside",
            Sub(e) e.FailIdentity=True,
            Sub(e) e.FailDescriptor=True,
            Sub(e) e.FailSink=True,
            Sub(e) e.NullSink=True}
        For Each mutate In mutations
            Dim env As New FixtureEnvironment()
            mutate(env)
            Dim d=KeepStoreTestIsolation.Evaluate(env)
            Check(d.Mode=KeepStoreIsolationMode.Denied,"INVALID_ATTESTATION_"+Checks.Count.ToString())
            Dim writes As Integer=0
            Try
                KeepStoreTestIsolation.EnforceRequest(Nothing,d)
                writes+=1
            Catch ex As System.Web.HttpException
                Check(ex.GetHttpCode()=503,"DENIAL_HTTP_STATUS_"+Checks.Count.ToString())
            End Try
            Check(writes=0,"ZERO_SIMULATED_MUTATIONS_"+Checks.Count.ToString())
        Next
        For Each d In New KeepStoreIsolationDecision(){New KeepStoreIsolationDecision(KeepStoreIsolationMode.Native,"NATIVE"),KeepStoreTestIsolation.Evaluate(New FixtureEnvironment())}
            KeepStoreTestIsolation.EnforceRequest(Nothing,d)
            Check(True,"READY_REQUEST_NOT_BLOCKED_"+Checks.Count.ToString())
        Next
    End Sub
    Private Sub TestDescriptorAndAcl()
        Dim valid="<testIsolation version=""1"" mode=""SMOKE"" machine=""fixture-machine"" siteId=""7"" applicationId=""/LM/W3SVC/7/ROOT"" pool=""fixture-pool"" physicalPath=""C:\fixture\application"" captureDirectory=""C:\fixture\captures""/>"
        Dim doc As New XmlDocument() With {.XmlResolver=Nothing}
        doc.LoadXml(valid)
        Dim d=KeepStoreServerIsolationEnvironment.ParseDescriptor(doc)
        Check(d.SiteId="7" AndAlso d.Machine="fixture-machine","DESCRIPTOR_STRICT_PARSE")
        For Each xmlText As String In New String(){valid.Replace("version=""1""","version=""2"""),valid.Replace(" mode=""SMOKE""",""),valid.Replace("siteId=","unknown="),valid.Replace("/>","><unexpected/></testIsolation>")}
            Dim invalid As New XmlDocument() With {.XmlResolver=Nothing}
            invalid.LoadXml(xmlText)
            Dim rejected As Boolean=False
            Try
                KeepStoreServerIsolationEnvironment.ParseDescriptor(invalid)
            Catch ex As InvalidDataException
                rejected=True
            End Try
            Check(rejected,"INVALID_DESCRIPTOR_"+Checks.Count.ToString())
        Next
        Dim pool="S-1-5-82-1-2-3-4-5"
        Dim admin As New SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,Nothing)
        Dim systemSid As New SecurityIdentifier(WellKnownSidType.LocalSystemSid,Nothing)
        Dim everyone As New SecurityIdentifier(WellKnownSidType.WorldSid,Nothing)
        Dim acl As New DirectorySecurity()
        Dim nullAcl As New DirectorySecurity()
        nullAcl.SetSecurityDescriptorSddlForm("O:BAG:BAD:NO_ACCESS_CONTROL")
        Check(Not KeepStoreIsolationFileTrust.HasTrustedWriters(nullAcl,pool,False),"NULL_DACL_FAILS_CLOSED")
        acl.SetOwner(admin)
        acl.AddAccessRule(New FileSystemAccessRule(admin,FileSystemRights.FullControl,AccessControlType.Allow))
        acl.AddAccessRule(New FileSystemAccessRule(systemSid,FileSystemRights.FullControl,AccessControlType.Allow))
        acl.AddAccessRule(New FileSystemAccessRule(New SecurityIdentifier(pool),FileSystemRights.ReadAndExecute,AccessControlType.Allow))
        Check(KeepStoreIsolationFileTrust.HasTrustedWriters(acl,pool,False),"ADMIN_OWNER_POOL_READ_ALLOWED")
        acl.AddAccessRule(New FileSystemAccessRule(everyone,FileSystemRights.Write,AccessControlType.Allow))
        Check(Not KeepStoreIsolationFileTrust.HasTrustedWriters(acl,pool,False),"WORLD_WRITABLE_DESCRIPTOR_DENIED")
        acl.RemoveAccessRuleAll(New FileSystemAccessRule(everyone,FileSystemRights.Write,AccessControlType.Allow))
        acl.AddAccessRule(New FileSystemAccessRule(New SecurityIdentifier(pool),FileSystemRights.Write,AccessControlType.Allow))
        Check(Not KeepStoreIsolationFileTrust.HasTrustedWriters(acl,pool,False),"POOL_CANNOT_WRITE_DESCRIPTOR")
        Check(KeepStoreIsolationFileTrust.HasTrustedWriters(acl,pool,True),"POOL_MAY_WRITE_CAPTURE_DIRECTORY")
        acl.AddAccessRule(New FileSystemAccessRule(New SecurityIdentifier(pool),FileSystemRights.ChangePermissions,AccessControlType.Allow))
        Check(Not KeepStoreIsolationFileTrust.HasTrustedWriters(acl,pool,True),"POOL_CANNOT_CHANGE_CAPTURE_ACL")
        acl.SetOwner(New SecurityIdentifier(pool))
        Check(Not KeepStoreIsolationFileTrust.HasTrustedWriters(acl,pool,True),"POOL_CANNOT_OWN_ATTESTATION_DIRECTORY")
    End Sub
    Private Function Request(classification As String) As TenantEmailDeliveryRequest
        Dim r As New TenantEmailDeliveryRequest() With {.AziendaId=1,.CorrelationId="SYNTHETIC-ISOLATION-1A",.Classification=classification,.Subject="SYNTHETIC_SUBJECT",.HtmlBody="<p>SYNTHETIC_BODY</p>",.PlainTextBody="SYNTHETIC_BODY"}
        r.ToRecipients.Add(New TenantEmailRecipient() With {.Address="to@fixture.invalid",.DisplayName="SYNTHETIC_NAME"})
        r.CcRecipients.Add(New TenantEmailRecipient() With {.Address="cc@fixture.invalid",.DisplayName=String.Empty})
        r.BccRecipients.Add(New TenantEmailRecipient() With {.Address="bcc@fixture.invalid",.DisplayName=String.Empty})
        r.ReplyToRecipients.Add(New TenantEmailRecipient() With {.Address="reply@fixture.invalid",.DisplayName=String.Empty})
        Return r
    End Function
    Private Sub TestCaptureAndFacade(directory As String)
        For Each classification In New String(){TenantEmailMessageClassifications.AccountRegistration,TenantEmailMessageClassifications.AccountProfileUpdated,TenantEmailMessageClassifications.OrderConfirmation,TenantEmailMessageClassifications.PasswordReset,TenantEmailMessageClassifications.ContactRequest,TenantEmailMessageClassifications.DocumentDelivery}
            Dim env As New FixtureEnvironment()
            Dim d=KeepStoreTestIsolation.Evaluate(env)
            Dim native As New HarnessCaptureTransport() With {.ThrowOnDeliver=True}
            Dim facade As New TenantEmailDeliveryService(native,"SYNTHETIC_UNUSED",d,False)
            Dim result=facade.Deliver(Request(classification))
            Check(result.Status=EmailTransportOperationStatus.Succeeded AndAlso result.Code="CAPTURED_TEST_ONLY" AndAlso result.Phase="test-capture","FACADE_CAPTURE_STATUS_"+classification)
            Check(native.DeliverCount=0 AndAlso env.Sink.Captures=1,"FACADE_NO_NATIVE_DELIVERY_"+classification)
            Check(env.Sink.LastReceipt.Contains("toCount=1") AndAlso env.Sink.LastReceipt.Contains("ccCount=1") AndAlso env.Sink.LastReceipt.Contains("bccCount=1"),"TO_CC_BCC_CAPTURE_"+classification)
            Dim adminCopy=classification=TenantEmailMessageClassifications.AccountRegistration OrElse classification=TenantEmailMessageClassifications.AccountProfileUpdated OrElse classification=TenantEmailMessageClassifications.OrderConfirmation
            Check(env.Sink.LastReceipt.Contains("administrativeCopyRequested="+adminCopy.ToString()),"ADMIN_COPY_SUPPRESSED_"+classification)
            Check(Not env.Sink.LastReceipt.Contains("@") AndAlso Not env.Sink.LastReceipt.Contains("SYNTHETIC_BODY") AndAlso Not env.Sink.LastReceipt.Contains("SYNTHETIC_SUBJECT") AndAlso Not env.Sink.LastReceipt.Contains("SYNTHETIC_NAME"),"RECEIPT_HAS_NO_MESSAGE_OR_PERSONAL_DATA_"+classification)
            Dim connection=CStr(GetType(TenantEmailDeliveryService).GetField("_connectionString",BindingFlags.NonPublic Or BindingFlags.Instance).GetValue(facade))
            Check(connection=String.Empty,"CAPTURE_NO_CONNECTION_VALUE_"+classification)
        Next
        Dim defaults As New FixtureEnvironment()
        Dim tenants As New FixtureEnvironment()
        For Each company As Integer In New Integer(){1,2}
            Dim tenantRequest=Request(TenantEmailMessageClassifications.AccountRegistration)
            tenantRequest.AziendaId=company
            tenantRequest.ToRecipients(0).Address="tenant-"+company.ToString()+"@fixture.invalid"
            tenantRequest.Subject="SYNTHETIC_TENANT_"+company.ToString()
            Dim tenantResult=New TenantEmailDeliveryService(Nothing,Nothing,KeepStoreTestIsolation.Evaluate(tenants),True).Deliver(tenantRequest)
            Check(tenantResult.Code="CAPTURED_TEST_ONLY","TWO_TENANT_CAPTURE_"+company.ToString())
            Check(Not tenants.Sink.LastReceipt.Contains("@") AndAlso Not tenants.Sink.LastReceipt.Contains("SYNTHETIC_TENANT_"),"TWO_TENANT_NO_MESSAGE_LEAK_"+company.ToString())
        Next
        Check(tenants.Sink.Captures=2,"TWO_TENANT_INDEPENDENT_CAPTURES")
        Dim defaultFacade As New TenantEmailDeliveryService(Nothing,Nothing,KeepStoreTestIsolation.Evaluate(defaults),True)
        Check(defaultFacade.Deliver(Request(TenantEmailMessageClassifications.AccountRegistration)).Code="CAPTURED_TEST_ONLY","DEFAULT_CONSTRUCTOR_SELECTION_CORE")
        Dim broken As New FixtureEnvironment()
        Dim brokenDecision=KeepStoreTestIsolation.Evaluate(broken)
        broken.Sink.Fail=True
        Dim unused As New HarnessCaptureTransport()
        Dim failed=New TenantEmailDeliveryService(unused,"SYNTHETIC_UNUSED",brokenDecision,False).Deliver(Request(TenantEmailMessageClassifications.AccountRegistration))
        Check(failed.Status<>EmailTransportOperationStatus.Succeeded AndAlso failed.Code="TEST_CAPTURE_UNAVAILABLE","BROKEN_SINK_CAPTURE_FAILED")
        Check(unused.DeliverCount=0,"BROKEN_SINK_NO_SMTP_FALLBACK")
        Dim contact As New FixtureEnvironment()
        Dim contactRequest=Request(TenantEmailMessageClassifications.ContactRequest)
        contactRequest.ToRecipients.Clear()
        Dim contactResult=New TenantEmailDeliveryService(Nothing,Nothing,KeepStoreTestIsolation.Evaluate(contact),True).Deliver(contactRequest)
        Check(contactResult.Code="CAPTURED_TEST_ONLY" AndAlso contact.Sink.LastReceipt.Contains("primaryFromProfileRequested=True"),"PROFILE_RECIPIENT_NEVER_RESOLVED_IN_CAPTURE")
        Using message As New MimeMessage()
            message.To.Add(New MailboxAddress("SYNTHETIC_NAME","to@fixture.invalid"))
            message.Cc.Add(New MailboxAddress("","cc@fixture.invalid"))
            message.Bcc.Add(New MailboxAddress("","bcc@fixture.invalid"))
            message.Subject="SYNTHETIC_SUBJECT"
            message.Body=New TextPart("plain") With {.Text="SYNTHETIC_BODY"}
            Dim text=KeepStoreFileTestReceiptSink.BuildReceipt(New EmailTransportRequest() With {.Message=message,.AdministrativeCopyFromProfileReplyTo=True})
            KeepStoreFileTestReceiptSink.WriteReceipt(directory,text)
            Dim files=System.IO.Directory.GetFiles(directory,"capture-*.txt")
            Check(files.Length=1,"RECEIPT_FILE_CREATED")
            Check(File.ReadAllText(files(0))=text AndAlso Not text.Contains("@") AndAlso Not text.Contains("BODY"),"FILE_HAS_ONLY_RECEIPT_METADATA")
        End Using
    End Sub
    Private Sub TestNativeBoundary()
        Dim ready As New HarnessReadyResolver() With {.Profile=New TenantEmailTransportProfile(New String("a"c,64),1,1,"TRANSACTIONAL","SMTP","smtp.fixture.invalid",587,EmailSecurityMode.StartTls,EmailAuthenticationMode.Password,"SYNTHETIC_USER","SYNTHETIC_REFERENCE","from@fixture.invalid","SYNTHETIC_NAME","admin@fixture.invalid","bounce@fixture.invalid",10)}
        Dim credentials As New HarnessCredentialStore()
        Dim sessions As New HarnessSmtpSessionFactory()
        Dim native As New MailKitEmailTransport(ready,credentials,sessions,New HarnessTelemetry())
        Environment.SetEnvironmentVariable(KeepStoreTestIsolation.ActivationVariable,"SMOKE",EnvironmentVariableTarget.Process)
        Using message As New MimeMessage()
            message.To.Add(New MailboxAddress("","to@fixture.invalid"))
            message.Subject="SYNTHETIC_SUBJECT"
            message.Body=New TextPart("plain") With {.Text="SYNTHETIC_BODY"}
            Check(native.Deliver(New EmailTransportRequest() With {.Message=message,.AziendaId=1,.Purpose="TRANSACTIONAL",.CorrelationId="SYNTHETIC-ISOLATION-1A"}).Code="TEST_NATIVE_SMTP_FORBIDDEN","DIRECT_NATIVE_DELIVERY_DENIED")
            Check(native.VerifyConnection("SYNTHETIC_UNUSED",1,"TRANSACTIONAL","SYNTHETIC-ISOLATION-1A").Code="TEST_NATIVE_SMTP_FORBIDDEN","DIRECT_NATIVE_VERIFY_DENIED")
        End Using
        Check(ready.NormalResolveCount=0 AndAlso ready.VerificationResolveCount=0 AndAlso credentials.ReadCount=0 AndAlso sessions.Sessions.Count=0,"NATIVE_BYPASS_ZERO_PROFILE_CREDENTIAL_AND_SMTP")
        Dim defaultFacade As New TenantEmailDeliveryService()
        Check(defaultFacade.Deliver(Request(TenantEmailMessageClassifications.AccountRegistration)).Status<>EmailTransportOperationStatus.Succeeded,"PUBLIC_DEFAULT_CONSTRUCTOR_FAILS_WITHOUT_ATTESTATION")
        Dim injected As New HarnessCaptureTransport()
        Dim injectedFacade As New TenantEmailDeliveryService(injected,"SYNTHETIC_UNUSED")
        Check(injectedFacade.Deliver(Request(TenantEmailMessageClassifications.AccountRegistration)).Status<>EmailTransportOperationStatus.Succeeded AndAlso injected.DeliverCount=0,"PUBLIC_INJECTION_CANNOT_BYPASS_TEST_ATTESTATION")
        Dim denied As Boolean=False
        Try
            Dim session=New MailKitEmailSmtpSessionFactory().Create()
        Catch ex As InvalidOperationException
            denied=ex.Message="TEST_NATIVE_SMTP_FORBIDDEN"
        End Try
        Check(denied,"NATIVE_FACTORY_DENIED")
        denied=False
        Try
            Dim session As New MailKitEmailSmtpSession()
        Catch ex As InvalidOperationException
            denied=ex.Message="TEST_NATIVE_SMTP_FORBIDDEN"
        End Try
        Check(denied,"NATIVE_SESSION_CONSTRUCTOR_DENIED")
        Environment.SetEnvironmentVariable(KeepStoreTestIsolation.ActivationVariable,Nothing,EnvironmentVariableTarget.Process)
        Using session As New MailKitEmailSmtpSession()
            Environment.SetEnvironmentVariable(KeepStoreTestIsolation.ActivationVariable,"SMOKE",EnvironmentVariableTarget.Process)
            For Each operation As Action In New Action(){Sub() session.Connect("127.0.0.1",0,SecureSocketOptions.StartTls),Sub() session.Authenticate("SYNTHETIC_USER","SYNTHETIC_VALUE"),Sub() session.Send(New MimeMessage(),"from@fixture.invalid")}
                denied=False
                Try
                    operation()
                Catch ex As InvalidOperationException
                    denied=ex.Message="TEST_NATIVE_SMTP_FORBIDDEN"
                End Try
                Check(denied,"PREEXISTING_NATIVE_SESSION_GUARD_"+Checks.Count.ToString())
            Next
            Check(Not session.IsConnected,"NO_NATIVE_CONNECTION")
        End Using
        Environment.SetEnvironmentVariable(KeepStoreTestIsolation.ActivationVariable,Nothing,EnvironmentVariableTarget.Process)
        Using message As New MimeMessage()
            message.To.Add(New MailboxAddress("","to@fixture.invalid"))
            message.Subject="SYNTHETIC_SUBJECT"
            message.Body=New TextPart("plain") With {.Text="SYNTHETIC_BODY"}
            Dim result=native.Deliver(New EmailTransportRequest() With {.Message=message,.AziendaId=1,.Purpose="TRANSACTIONAL",.AdministrativeCopyFromProfileReplyTo=True,.CorrelationId="SYNTHETIC-ISOLATION-1A"})
            Check(result.Code="EMAIL_SENT" AndAlso result.Status=EmailTransportOperationStatus.Succeeded,"UNMARKED_NATIVE_CONTRACT_PRESERVED_WITH_FAKE_SMTP")
        End Using
        Check(ready.NormalResolveCount=1 AndAlso credentials.ReadCount=1 AndAlso sessions.Sessions.Count=1 AndAlso sessions.Sessions(0).SendCount=1,"UNMARKED_NATIVE_DEPENDENCY_COUNTS")
        Check(sessions.Sessions(0).BccAddresses.Contains("admin@fixture.invalid"),"UNMARKED_NATIVE_ADMIN_COPY_PRESERVED")
    End Sub
    Private Sub TestPipeline(app As String)
        Dim bridge=DirectCast(ApplicationHost.CreateApplicationHost(GetType(IsolationPipelineBridge),"/",app),IsolationPipelineBridge)
        Dim denied=bridge.Run("mutate.aspx","POST","SMOKE")
        Check(denied="503|0|NO_BODY","REAL_SYSTEMWEB_POST_ABORTS_BEFORE_PAGE_LOAD")
        denied=bridge.Run("mutate.aspx","GET","SMOKE")
        Check(denied="503|0|NO_BODY","REAL_SYSTEMWEB_GET_ABORTS_BEFORE_PAGE_LOAD")
        denied=bridge.Run("mutate.aspx","POST","INVALID")
        Check(denied="503|0|NO_BODY","REAL_SYSTEMWEB_INVALID_MARKER_ABORTS")
        Dim allowed=bridge.Run("mutate.aspx","POST",Nothing)
        Check(allowed="200|1|BODY","REAL_SYSTEMWEB_NATIVE_POST_UNCHANGED_DESPITE_SPOOFED_HEADERS")
        allowed=bridge.Run("mutate.aspx","GET",Nothing)
        Check(allowed="200|2|BODY","REAL_SYSTEMWEB_NATIVE_GET_UNCHANGED")
        Environment.SetEnvironmentVariable(KeepStoreTestIsolation.ActivationVariable,Nothing,EnvironmentVariableTarget.Process)
    End Sub
End Module
'@
    Write-Fixture 'IsolationHarness.vb' $harness
    $frameworkRefs=@('System.dll','System.Core.dll','System.Data.dll','System.Web.dll','System.Configuration.dll','System.Security.dll','System.Xml.dll')
    $dependencies=@('MySql.Data.dll','MailKit.dll','MimeKit.dll','BouncyCastle.Cryptography.dll','System.Formats.Asn1.dll','System.Buffers.dll','System.Memory.dll','System.Numerics.Vectors.dll','System.Runtime.CompilerServices.Unsafe.dll','System.Threading.Tasks.Extensions.dll')
    $references=@($frameworkRefs)+@($dependencies|ForEach-Object {Join-Path $RepositoryRoot ('Bin\'+$_)})+@(Join-Path $work 'IsolationBridge.dll')
    $sources=@('App_Code\TenantEmailTransportContracts.vb','App_Code\TenantEmailTransportProfileResolver.vb','App_Code\EmailCredentialStore.vb','App_Code\MailKitEmailTransport.vb','App_Code\TenantEmailDeliveryService.vb','App_Code\KeepStoreTestIsolation.vb')|ForEach-Object {Join-Path $RepositoryRoot $_}
    $sources+=@(Join-Path $work 'ExistingEmailDoubles.vb')
    $sources+=@(Join-Path $work 'IsolationHarness.vb')
    & $vbc /nologo /target:exe /optionstrict+ /main:IsolationHarness ('/out:'+(Join-Path $work 'IsolationHarness.exe')) ('/reference:'+($references -join ',')) $sources
    if($LASTEXITCODE -ne 0){throw 'ISOLATION_HARNESS_COMPILE_FAILED'}
    foreach($dependency in $dependencies){
        Copy-Item -LiteralPath (Join-Path $RepositoryRoot ('Bin\'+$dependency)) -Destination (Join-Path $work $dependency)
        Copy-Item -LiteralPath (Join-Path $RepositoryRoot ('Bin\'+$dependency)) -Destination (Join-Path $app ('bin\'+$dependency))
    }
    $receipts=Join-Path $work 'synthetic-receipts'
    [IO.Directory]::CreateDirectory($receipts)|Out-Null
    $checkList=Join-Path $EvidenceDirectory 'isolation-checks.txt'
    $output=@(& (Join-Path $work 'IsolationHarness.exe') $receipts ($app+'\') $checkList)
    $exitCode=$LASTEXITCODE
    $output|Write-Output
    if($exitCode -ne 0){throw 'ISOLATION_HARNESS_FAILED'}
    $count=[regex]::Match(($output -join [Environment]::NewLine),'KEEPSTORE_TEST_ISOLATION_PASS checks=(\d+)')
    if(!$count.Success -or [int]$count.Groups[1].Value -lt 100){throw 'ISOLATION_CHECKS_MISSING'}
    $report=[ordered]@{result='PASS';checks=[int]$count.Groups[1].Value;scope='Actual policy, facade, native transport and Global.asax; synthetic metadata/ACL/SMTP/data boundaries';pipeline='Real System.Web hosting, actual Global.asax and guard, synthetic mutation page; unrelated SEO stubs';limits=@('No IIS identity or privileged descriptor provisioned','Trusted filesystem decisions tested with synthetic ACL models; no operational activation','SMTP/profile/credential collaborators faked; no real send or database','Receipt files contain counts and test code only');operationalConfigurationCopies=0;testActivationOnIis=$false}
    $report|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'isolation-report.json') -Encoding UTF8
} finally {
    if([Environment]::GetEnvironmentVariable('KEEPSTORE_TEST_ISOLATION','Process') -cne $roleBefore){throw 'TEST_MUST_NOT_CHANGE_PARENT_ACTIVATION'}
    if(Test-Path -LiteralPath $work){
        $resolved=[IO.Path]::GetFullPath($work)
        $tempPrefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
        if(!$resolved.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notmatch '^KeepStore-IsolationFixture-[0-9a-f]{32}$'){throw 'UNSAFE_TEST_CLEANUP'}
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
