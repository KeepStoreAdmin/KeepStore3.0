[CmdletBinding()]
param([string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'LOGIN_GUARD_REQUIRES_PS51'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
if(!$EvidenceDirectory.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Test-Path $EvidenceDirectory)){throw 'NEW_TEMP_EVIDENCE_REQUIRED'}
New-Item -ItemType Directory -Path $EvidenceDirectory|Out-Null
$utf8=New-Object Text.UTF8Encoding($false)
$checks=New-Object 'Collections.Generic.List[object]'
function Check($name,[bool]$ok){$checks.Add(@{Name=$name;Pass=$ok});if(!$ok){throw ('LOGIN_GUARD_ASSERT: '+$name)}}
function Read-Source($path){return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace("`r`n","`n")}
function Base-Source($path){$s=(git -C $RepositoryRoot show ('743e4d4aa47a7b184249224e8c05b4dc444a24c2:'+$path)) -join "`n";if($LASTEXITCODE -ne 0){throw 'BASE_UNAVAILABLE'};return $s}
function Methods($text){$map=@{};foreach($m in [regex]::Matches($text,'(?ms)^[ \t]*(?:Private|Protected|Public) (?:Shared |Overrides )?(?:Function|Sub) (\w+)\b.*?^[ \t]*End (?:Function|Sub)')){$map[$m.Groups[1].Value]=$m.Value};return $map}
$page=Read-Source 'login.aspx.vb';$master=Read-Source 'Page.master.vb';$oldPage=Base-Source 'login.aspx.vb';$oldMaster=Base-Source 'Page.master.vb'
$pm=Methods $page;$mm=Methods $master;$op=Methods $oldPage;$om=Methods $oldMaster
foreach($pair in @(@{Old=$op;New=$pm;Allowed=@('Page_Load','btnLogin_Click','EseguiLogin')},@{Old=$om;New=$mm;Allowed=@('Page_Load','Page_PreRender','Login')})){
    foreach($n in $pair.Old.Keys){if($pair.Allowed -notcontains $n){Check ('unchanged '+$n) (($pair.Old[$n] -replace '\s+',' ').Trim() -ceq ($pair.New[$n] -replace '\s+',' ').Trim())}}
}
foreach($n in @('btnLogin_Click','EseguiLogin')){Check ('only guard prefix in '+$n) (($pm[$n].Replace('        If Not EnsureLoginPostOrigin() Then Return False','').Replace('        If Not EnsureLoginPostOrigin() Then Return','') -replace '\s+',' ').Trim() -ceq ($op[$n] -replace '\s+',' ').Trim())}
Check 'only guard prefix in master Login' (($mm.Login.Replace('        If Not EnsureLoginPostOrigin() Then Return','') -replace '\s+',' ').Trim() -ceq ($om.Login -replace '\s+',' ').Trim())
Check 'guard never performs tenant query, config, session mutation or forwarded trust' (($mm.EnsureLoginPostOrigin+$mm.TryParseLoginSource+$mm.RejectLoginPost) -notmatch 'StorefrontSeoTenantContext.Resolve|MySql|ConnectionStrings|Session\(|X-Forwarded')
Check 'baseline has no new explicit guard; no live exploit claimed' ($oldPage -notmatch 'EnsureLoginPostOrigin' -and $oldMaster -notmatch 'EnsureLoginPostOrigin')
foreach($path in @('login.aspx','Page.master','Global.asax','App_Code/PostLoginReturnUrlPolicy.vb','App_Code/StorefrontCanonicalHostPolicy.vb')){Check ('protected source unchanged '+$path) ((git -C $RepositoryRoot hash-object -- $path) -eq (git -C $RepositoryRoot rev-parse ('HEAD:'+$path)))}
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName Microsoft.VisualBasic
$support=@'
Imports System
Imports System.IO
Imports System.Data
Imports System.Collections.Generic
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.SessionState
Imports System.Web.UI
Imports System.Web.UI.WebControls
Public Class Probe
    Public Shared Queries, Opens, Audits, Merges, Clears, Reads As Integer
    Public Shared Company As Integer
    Public Shared Sql As String
    Public Shared Sub Reset(companyId As Integer)
        Queries=0:Opens=0:Audits=0:Merges=0:Clears=0:Reads=0:Company=companyId:Sql=""
    End Sub
End Class
Public Class HeaderWorker
    Inherits SimpleWorkerRequest
    Private uri As Uri
    Private verb As String
    Private origins, referrers As String()
    Public Headers As New Dictionary(Of String,String)(StringComparer.OrdinalIgnoreCase)
    Public Sub New(target As String,appPath As String,method As String,originHeaders As String(),refererHeaders As String(),output As TextWriter)
        MyBase.New(appPath,"C:\synthetic-login-only\",If(appPath="/",New Uri(target).AbsolutePath.TrimStart("/"c),New Uri(target).AbsolutePath.Substring(appPath.Length).TrimStart("/"c)),New Uri(target).Query.TrimStart("?"c),output)
        uri=New Uri(target):verb=method:origins=originHeaders:referrers=refererHeaders
    End Sub
    Public Overrides Function GetHttpVerbName() As String
        Return verb
    End Function
    Public Overrides Function GetServerName() As String
        Return uri.Host
    End Function
    Public Overrides Function GetLocalPort() As Integer
        Return uri.Port
    End Function
    Public Overrides Function IsSecure() As Boolean
        Return uri.Scheme="https"
    End Function
    Public Overrides Function GetKnownRequestHeader(index As Integer) As String
        If index=HttpWorkerRequest.HeaderHost Then Return uri.Authority
        If index=HttpWorkerRequest.HeaderReferer AndAlso referrers IsNot Nothing Then Return String.Join(",",referrers)
        Return Nothing
    End Function
    Public Overrides Function GetUnknownRequestHeaders() As String()()
        Dim values As New List(Of String())()
        If origins IsNot Nothing Then
            ' Model the comma-joined header representation; duplicate wire lines are not IIS-tested.
            values.Add(New String(){"Origin",String.Join(",",origins)})
        End If
        Return values.ToArray()
    End Function
    Public Overrides Sub SendKnownResponseHeader(index As Integer,value As String)
        Headers(HttpWorkerRequest.GetKnownResponseHeaderName(index))=value
    End Sub
    Public Overrides Sub SendUnknownResponseHeader(name As String,value As String)
        Headers(name)=value
    End Sub
End Class
Public Class TrackedTextBox
    Inherits TextBox
    Public Overrides Property Text As String
        Get
            Probe.Reads+=1
            Return MyBase.Text
        End Get
        Set(value As String)
            MyBase.Text=value
        End Set
    End Property
End Class
Public Class ScriptSink
    Public Sub RegisterClientScriptBlock(t As Type,key As String,value As String)
    End Sub
End Class
Public Class RedirectTransport
    Public Shared Sub Apply(response As HttpResponse,url As String,endResponse As Boolean)
        ' The unhosted fixture lacks ASP.NET browser/config transport. Keep the actual policy target,
        ' status and Location, replacing only HttpResponse.Redirect's hosting-dependent transport.
        response.RedirectLocation=url
        response.StatusCode=302
    End Sub
    Public Shared Sub CompleteRequest()
        ' HttpApplication's pipeline step manager exists only in a hosted application.
        ' Caller returns, sticky refusal, response state and Render remain real code.
    End Sub
End Class
Public Class PageInfo
    Public IsValid As Boolean=True
    Public ClientScript As New ScriptSink()
End Class
Public Class Frame
    Inherits Control
    Implements INamingContainer
    Public Shadows ReadOnly Property Context As HttpContext
        Get
            Return HttpContext.Current
        End Get
    End Property
    Public ReadOnly Property Request As HttpRequest
        Get
            Return Context.Request
        End Get
    End Property
    Public ReadOnly Property Response As HttpResponse
        Get
            Return Context.Response
        End Get
    End Property
    Public ReadOnly Property Session As HttpSessionState
        Get
            Return Context.Session
        End Get
    End Property
    Public Shadows Page As New PageInfo()
    Public Master As Object
    Public IsPostBack As Boolean=True
    Protected Overrides Sub Render(writer As HtmlTextWriter)
        writer.Write("SYNTHETIC_LOGIN_PAGE")
    End Sub
End Class
Public Class FakeConnection
    Implements IDisposable
    Public Sub New(Optional cs As String="synthetic-only")
    End Sub
    Public Sub Open()
        Probe.Opens+=1
    End Sub
    Public Sub Close()
    End Sub
    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub
End Class
Public Class FakeParameters
    Public Sub Clear()
    End Sub
    Public Sub AddWithValue(key As String,value As Object)
    End Sub
End Class
Public Class FakeCommand
    Implements IDisposable
    Public Parameters As New FakeParameters()
    Public Connection As FakeConnection
    Public CommandType As CommandType
    Public CommandText As String
    Public Function ExecuteReader() As FakeReader
        Probe.Queries+=1:Probe.Sql=CommandText
        Return New FakeReader()
    End Function
    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub
End Class
Public Class FakeReader
    Implements IDisposable
    Public ReadOnly Property HasRows As Boolean
        Get
            Return True
        End Get
    End Property
    Public Function Read() As Boolean
        Return True
    End Function
    Default Public ReadOnly Property Item(name As String) As Object
        Get
            Select Case name.ToLowerInvariant()
                Case "password" : Return "SYNTHETIC-CONTROL"
                Case "aziendeid" : Return Probe.Company
                Case "listino" : Return If(Probe.Company=1,1,10)
                Case "id" : Return 42
                Case "utentiid" : Return 142
                Case "email" : Return "fixture@example.invalid"
                Case "cognomenome" : Return "Synthetic"
                Case "ultimoaccesso","datapassword" : Return Date.Today
                Case "ivatipo" : Return 2
                Case "idesenzioneiva","valoreesenzioneiva" : Return -1
                Case "descrizioneesenzioneiva" : Return ""
                Case "abilitatoivareversecharge","genera_html_mail","scadenzapassword" : Return 0
                Case Else : Return 1
            End Select
        End Get
    End Property
    Public Sub Close()
    End Sub
    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub
End Class
Public Class LoginAccessAuditRecorder
    Public Shared Sub TryRecordSuccessfulLogin(context As HttpContext,id As Integer)
        Probe.Audits+=1
    End Sub
    Public Shared Sub ClearAuthenticationMarker(context As HttpContext)
        Probe.Clears+=1
    End Sub
End Class
Public Class KeepStoreLog
    Public Shared Sub [Error](area As String,message As String,ex As Exception,context As HttpContext)
    End Sub
End Class
Public Class CatalogAsyncCartSupport
    Public Shared Function GetOrCreateCsrfToken(context As HttpContext) As String
        Return "SYNTHETIC-NON-AUTH-TOKEN"
    End Function
End Class
Public Class Outcome
    Public Status, Queries, Opens, Audits, Merges, Clears, Reads, Cookies, LoginId, Listino As Integer
    Public Body, Allow, Cache, Location, Target, Sql, Username As String
    Public ErrorHandled As Boolean
    Public ErrorHook As Boolean
End Class
'@
$masterWrapper=@'
Imports System
Imports System.Data
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Text
Imports System.Text.RegularExpressions
Public Class PageMaster
    Inherits Frame
    Private Const GenericLoginFailureMessage As String="Accesso non riuscito. Verifica le credenziali o contatta il supporto."
    Private Const LoginPostRejectionKey As String="KeepStore.Login.PostOriginRejected"
    Private Const LoginPostErrorHandlerKey As String="KeepStore.Login.RejectionErrorHandler"
    Private Const LoginPostRejectionMessage As String="Richiesta di accesso non consentita."
    Private _priceDisplayCompanyId As Integer
    Private conn As New FakeConnection()
    Private cmd As New FakeCommand()
    Public litNativeCartSecurityFields As New Literal()
    Public Sub SetTenant(id As Integer)
        _priceDisplayCompanyId=id
    End Sub
    Public Sub AggiornaDati()
        Probe.Merges+=1
    End Sub
    Public Sub RestoreAnonymousPriceDisplayState()
    End Sub
    Public Sub ApplyAuthenticatedPriceDisplayState(a As Object,b As Object,c As Object,d As Object,e As Object)
        Session("IvaTipo")=a
    End Sub
    Private Sub ExpireLegacyPasswordCookie()
    End Sub
    Private Sub ApplyThemeTagging()
    End Sub
    Private Sub ApplySupportEmail()
    End Sub
    Private Function CurrentLoginIdSafe() As Integer
        Return StorefrontCommercialIsolationPolicy.PositiveInteger(Session("LoginId"))
    End Function
    Public Sub CallLoad()
        Page_Load(Nothing,EventArgs.Empty)
    End Sub
__METHODS__
End Class
'@
$pageWrapper=@'
Imports System
Imports System.Data
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Public Class Login
    Inherits Frame
    Private Const GenericLoginFailureMessage As String="Accesso non riuscito. Verifica le credenziali o contatta il supporto."
    Private Const SessionExpiredMessage As String="La sessione e' scaduta per inattivita. Accedi di nuovo per continuare dal carrello."
    Public tbUsername As New TrackedTextBox() With {.ID="tbUsername"}
    Public tbPassword As New TrackedTextBox() With {.ID="tbPassword"}
    Public lblLogin As New Label() With {.ID="lblLogin"}
    Public Sub New()
        Controls.Add(tbUsername):Controls.Add(tbPassword):Controls.Add(lblLogin)
    End Sub
    Public Sub CallInit()
__INIT__
    End Sub
    Public Sub CallLoad()
        Page_Load(Nothing,EventArgs.Empty)
    End Sub
    Public Sub CallClick()
        btnLogin_Click(Nothing,EventArgs.Empty)
    End Sub
__METHODS__
End Class
'@
$runner=@'
Imports System
Imports System.IO
Imports System.Collections.Generic
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.SessionState
Public Class Runner
    Public Function Run(target As String,app As String,method As String,origins As String(),referrers As String(),flow As String,goodCredentials As Boolean,validForm As Boolean,existingLogin As Boolean,postBack As Boolean) As Outcome
        Dim transport As New StringWriter()
        Dim worker As New HeaderWorker(target,app,method,origins,referrers,transport)
        Dim context As New HttpContext(worker)
        context.ApplicationInstance=New HttpApplication()
        SessionStateUtility.AddHttpSessionStateToContext(context,New HttpSessionStateContainer("SYNTHETIC",New SessionStateItemCollection(),New HttpStaticObjectsCollection(),20,True,HttpCookieMode.UseCookies,SessionStateMode.InProc,False))
        HttpContext.Current=context
        Dim identities As New List(Of StorefrontSeoTenantIdentity) From {
            StorefrontCanonicalHostPolicy.CreateTenant(1,"Tech","Tech","https://tech.invalid/","https://alias.tech.invalid/","",1),
            StorefrontCanonicalHostPolicy.CreateTenant(2,"Food","Food","https://food.invalid/","https://alias.food.invalid/","",10)}
        Dim tenant=StorefrontCanonicalHostPolicy.SelectExactTenant(identities,context.Request.Url.DnsSafeHost,False)
        Dim company As Integer=If(tenant Is Nothing,0,tenant.CompanyId)
        Probe.Reset(company)
        Dim session=context.Session
        session("AziendaID")=company:session("AziendaNome")="Fixture":session("Listino")=If(company=1,1,10)
        session("Page")=If(app="/","/articoli.aspx","/shop/articoli.aspx")
        If existingLogin Then session("LoginId")=77:session("LoginID")=77
        Dim master As New PageMaster():master.SetTenant(company):master.IsPostBack=postBack
        Dim page As New Login():page.Master=master:page.IsPostBack=postBack:page.Page.IsValid=validForm
        Dim actualPage As New System.Web.UI.Page():actualPage.Controls.Add(master):actualPage.Controls.Add(page)
        context.Handler=actualPage
        GetType(System.Web.UI.Page).GetMethod("SetIntrinsics",Reflection.BindingFlags.Instance Or Reflection.BindingFlags.NonPublic,Nothing,New Type(){GetType(HttpContext),GetType(Boolean)},Nothing).Invoke(actualPage,New Object(){context,False})
        page.tbUsername.Text="SYNTHETIC-USER":page.tbPassword.Text=If(goodCredentials,"synthetic-control","SYNTHETIC-WRONG")
        If flow="legacy-caller" Then
            master.Controls.Add(New TrackedTextBox() With {.ID="tbUsername",.Text="SYNTHETIC-USER"})
            master.Controls.Add(New TrackedTextBox() With {.ID="tbPassword",.Text=If(goodCredentials,"synthetic-control","SYNTHETIC-WRONG")})
            master.Controls.Add(New Label() With {.ID="lblLogin"})
        End If
        Select Case flow
            Case "page" : page.CallInit():page.CallLoad():page.CallClick()
            Case "legacy" : master.Login("SYNTHETIC-USER",If(goodCredentials,"synthetic-control","SYNTHETIC-WRONG"))
            Case "legacy-caller" : master.CallLoad()
            Case "get" : page.CallInit():page.CallLoad()
            Case "page-error" : page.CallInit()
            Case "legacy-error" : master.Login("SYNTHETIC-USER","synthetic-control")
        End Select
        Dim wasRejected=context.Items("KeepStore.Login.PostOriginRejected") IsNot Nothing
        Dim errorFlow=flow.EndsWith("-error",StringComparison.Ordinal)
        Dim errorHandled As Boolean=False
        If errorFlow Then
            ' Execute System.Web's real Page.HandleError after Init/refusal; no subsequent Render.
            ' The exception models MAC failure classification, not generation/decryption of ViewState.
            Dim failure As New HttpException("Invalid viewstate MAC",New InvalidOperationException("SYNTHETIC-MAC-FAILURE"))
            errorHandled=CBool(GetType(System.Web.UI.Page).GetMethod("HandleError",Reflection.BindingFlags.Instance Or Reflection.BindingFlags.NonPublic).Invoke(actualPage,New Object(){failure}))
        ElseIf wasRejected Then
            context.Response.StatusCode=200:context.Response.RedirectLocation="/must-not-win"
            page.CallLoad():page.CallClick():master.CallLoad():master.Login("SYNTHETIC-USER","synthetic-control")
        End If
        Dim output As New StringWriter()
        If errorFlow Then
            ' HandleError exits the failing lifecycle without Render, as on ASP.NET.
        ElseIf flow="page" OrElse flow="get" Then
            page.RenderControl(New HtmlTextWriter(output))
        Else
            master.RenderControl(New HtmlTextWriter(output))
        End If
        Dim result As New Outcome With {.Status=context.Response.StatusCode,.Queries=Probe.Queries,.Opens=Probe.Opens,.Audits=Probe.Audits,.Merges=Probe.Merges,.Clears=Probe.Clears,.Reads=Probe.Reads,.Cookies=context.Response.Cookies.Count,.LoginId=StorefrontCommercialIsolationPolicy.PositiveInteger(session("LoginId")),.Listino=StorefrontCommercialIsolationPolicy.PositiveInteger(session("Listino")),.Body=output.ToString(),.Location=context.Response.RedirectLocation,.Target=Convert.ToString(session("Page")),.Sql=Probe.Sql,.ErrorHandled=errorHandled,.ErrorHook=context.Items("KeepStore.Login.RejectionErrorHandler") IsNot Nothing}
        context.Response.Write(output.ToString())
        context.Response.Flush()
        If errorFlow Then result.Body=transport.ToString()
        result.Allow=If(worker.Headers.ContainsKey("Allow"),worker.Headers("Allow"),"")
        result.Cache=If(worker.Headers.ContainsKey("Cache-Control"),worker.Headers("Cache-Control"),"")
        Return result
    End Function
End Class
'@
$compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
try{
    function Compile($pageMap,$masterMap,[bool]$candidate){
        $masterMethods=@($masterMap.Login)
        $load=$masterMap.Page_Load
        $end=$load.IndexOf("        'Scadenza password")
        if($end -lt 0){throw 'LEGACY_LOAD_BOUNDARY_MISSING'}
        $masterMethods+=($load.Substring(0,$end)+"    End Sub")
        if($candidate){foreach($n in @('IsLoginPostRejected','RejectLoginPost','HandleRejectedLoginError','RenderRejectedLoginPost','Render','TryParseLoginSource','LoginSourceMatches','EnsureLoginPostOrigin')){$masterMethods+=$masterMap[$n]}}
        $pageMethods=@();foreach($n in @('ResolveAndConsumePostLoginTarget','CurrentLoginIdSafe','ClearInvalidLoginSession','Page_Load','btnLogin_Click','EseguiLogin')){$pageMethods+=$pageMap[$n]}
        if($candidate){foreach($n in @('EnsureLoginPostOrigin','Page_Init','Render')){$pageMethods+=$pageMap[$n]}}
        $m=$masterWrapper.Replace('__METHODS__',($masterMethods -join "`n"))
        $p=$pageWrapper.Replace('__METHODS__',($pageMethods -join "`n")).Replace('__INIT__',$(if($candidate){'        Page_Init(Nothing,EventArgs.Empty)'}else{''}))
        # DB/audit/cart boundaries and the unhosted redirect/pipeline transport are synthetic.
        # Guard, authentication branches/returns, response state and refusal Render execute unchanged.
        # No operational configuration is read; CompleteRequest is never treated as terminal proof.
        $sources=@($support,$m,$p,$runner)|ForEach-Object{
            $source=[regex]::Replace($_,' Handles [^\r\n]+','').Replace('MySqlConnection','FakeConnection').Replace('MySqlCommand','FakeCommand').Replace('MySqlDataReader','FakeReader').Replace('ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString','"synthetic-only"').Replace('Response.Redirect(','RedirectTransport.Apply(Response,')
            [regex]::Replace($source,'\bContext\.ApplicationInstance\.CompleteRequest\(\)','RedirectTransport.CompleteRequest()',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
        $sources+=@('StorefrontCanonicalHostPolicy.vb','StorefrontCommercialIsolationPolicy.vb','PostLoginReturnUrlPolicy.vb','LegacyPromotionRoutePolicy.vb')|ForEach-Object{Read-Source ('App_Code/'+$_)}
        $options=New-Object CodeDom.Compiler.CompilerParameters
        $options.GenerateInMemory=$true;$options.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
        @('System.dll','System.Core.dll','System.Data.dll','System.Web.dll','System.Configuration.dll')|ForEach-Object{[void]$options.ReferencedAssemblies.Add($_)}
        $compiled=$compiler.CompileAssemblyFromSource($options,[string[]]$sources)
        if($compiled.Errors.HasErrors){throw (($compiled.Errors|Where-Object{!$_.IsWarning}|ForEach-Object{'line '+$_.Line+': '+$_.ErrorText}) -join '; ')}
        return [Activator]::CreateInstance($compiled.CompiledAssembly.GetType('Runner'))
    }
    $candidate=Compile $pm $mm $true;$baseline=Compile $op $om $false
    $outcomes=New-Object 'Collections.Generic.List[object]'
    foreach($tenant in @('tech','food')){foreach($alias in @('','alias.')){foreach($app in @('/','/shop')){
        $authority='https://'+$alias+$tenant+'.invalid';$path=if($app -eq '/'){'/login.aspx'}else{'/shop/login.aspx'};$target=$authority+$path
        $cases=@(
            @{Name='origin';Origin=@($authority);Referer=$null;Status=302},
            @{Name='case insensitive origin';Origin=@($authority.ToUpperInvariant());Referer=$null;Status=302},
            @{Name='referer fallback';Origin=$null;Referer=@($authority+$path+'?mr=1,2');Status=302},
            @{Name='both consistent';Origin=@($authority);Referer=@($authority+'/shop');Status=302},
            @{Name='explicit default port';Origin=@($authority+':443');Referer=$null;Status=302},
            @{Name='foreign';Origin=@('https://evil.invalid');Referer=@($authority+$path);Status=403},
            @{Name='other tenant';Origin=@('https://'+$(if($tenant -eq 'tech'){'food'}else{'tech'})+'.invalid');Referer=$null;Status=403},
            @{Name='same tenant different host';Origin=@('https://'+$(if($alias -eq ''){'alias.'}else{''})+$tenant+'.invalid');Referer=$null;Status=403},
            @{Name='deceptive suffix';Origin=@($authority+'.evil.invalid');Referer=$null;Status=403},
            @{Name='scheme';Origin=@($authority.Replace('https:','http:'));Referer=$null;Status=403},
            @{Name='port';Origin=@($authority+':444');Referer=$null;Status=403},
            @{Name='missing both';Origin=$null;Referer=$null;Status=403},
            @{Name='empty origin';Origin=@('');Referer=@($authority+$path);Status=403},
            @{Name='null origin';Origin=@('null');Referer=@($authority+$path);Status=403},
            @{Name='multiple origin';Origin=@($authority,$authority);Referer=$null;Status=403},
            @{Name='comma origin';Origin=@($authority+','+$authority);Referer=$null;Status=403},
            @{Name='space origin';Origin=@($authority+' '+$authority);Referer=$null;Status=403},
            @{Name='malformed';Origin=@('://');Referer=@($authority+$path);Status=403},
            @{Name='userinfo';Origin=@('https://user@'+$alias+$tenant+'.invalid');Referer=$null;Status=403},
            @{Name='backslash';Origin=@($authority.Replace('//','\\'));Referer=$null;Status=403},
            @{Name='dot path';Origin=@($authority+'/.');Referer=$null;Status=403},
            @{Name='encoded dot';Origin=@($authority+'/%2e');Referer=$null;Status=403},
            @{Name='origin slash';Origin=@($authority+'/');Referer=$null;Status=403},
            @{Name='contradictory referer';Origin=@($authority);Referer=@('https://evil.invalid/page');Status=403},
            # System.Web omits an empty known Referer header; the valid Origin remains authoritative.
            @{Name='empty known referer normalized absent';Origin=@($authority);Referer=@('');Status=302},
            @{Name='multiple referer';Origin=$null;Referer=@($authority+'/one',$authority+'/two');Status=403},
            @{Name='joined referer';Origin=$null;Referer=@($authority+'/one,'+$authority+'/two');Status=403},
            @{Name='relative referer';Origin=$null;Referer=@('/login.aspx');Status=403},
            @{Name='encoded authority';Origin=@($authority.Replace($tenant,'%'+$tenant));Referer=$null;Status=403}
        )
        foreach($flow in @('page','legacy','legacy-caller')){foreach($case in $cases){
            $name=$tenant+'/'+$alias+$app+'/'+$flow+'/'+$case.Name
            $r=$candidate.Run($target,$app,'POST',[string[]]$case.Origin,[string[]]$case.Referer,$flow,$true,$true,$false,$true)
            Check ($name+' status') ($r.Status -eq $case.Status)
            if($case.Status -eq 403){
                Check ($name+' zero login effects including later events') ($r.Queries -eq 0 -and $r.Opens -eq 0 -and $r.Audits -eq 0 -and $r.Merges -eq 0 -and $r.Cookies -eq 0 -and $r.LoginId -eq 0 -and $r.Reads -eq 0 -and $r.Clears -eq 0)
                Check ($name+' generic final no-store response') ($r.Body -eq 'Richiesta di accesso non consentita.' -and $r.Cache -match 'no-store' -and [string]::IsNullOrEmpty($r.Location))
            }else{
                $b=$baseline.Run($target,$app,'POST',[string[]]$case.Origin,[string[]]$case.Referer,$flow,$true,$true,$false,$true)
                Check ($name+' baseline successful flow retained once') ($r.Queries -eq 1 -and $r.Audits -eq 1 -and $r.Merges -eq 1 -and $r.LoginId -eq $b.LoginId -and $r.Listino -eq $b.Listino -and $r.Queries -eq $b.Queries -and $r.Audits -eq $b.Audits -and $r.Merges -eq $b.Merges -and $r.Cookies -eq $b.Cookies -and $r.Location -eq $b.Location -and !$r.ErrorHook)
                Check ($name+' tenant SQL retained') ($r.Sql -match 'AziendeID=\?')
            }
            $outcomes.Add(@{Case=$name;Status=$r.Status;Queries=$r.Queries;Audits=$r.Audits;Merges=$r.Merges})
        }}
        foreach($flow in @('page','legacy')){foreach($method in @('GET','HEAD','PUT','DELETE')){
            $r=$candidate.Run($target,$app,$method,@($authority),$null,$flow,$true,$true,$true,$true)
            Check ($tenant+$alias+$app+$flow+$method+' 405 Allow and preserved valid identity') ($r.Status -eq 405 -and $r.Allow -match 'POST' -and $r.LoginId -eq 77 -and $r.Queries -eq 0 -and $r.Audits -eq 0 -and $r.Merges -eq 0 -and $r.Cookies -eq 0 -and $r.Reads -eq 0 -and $r.Clears -eq 0 -and $r.Body -eq 'Richiesta di accesso non consentita.' -and $r.Cache -match 'no-store')
        }}
        $r=$candidate.Run($target,$app,'POST',@('null'),@($authority+$path),'page',$true,$true,$true,$false)
        Check ($tenant+$alias+$app+' malformed postback rejected before Load') ($r.Status -eq 403 -and $r.LoginId -eq 77 -and $r.Clears -eq 0 -and $r.Target -match 'articoli.aspx' -and $r.Queries -eq 0)
        foreach($flow in @('page-error','legacy-error')){
            $r=$candidate.Run($target,$app,'POST',@('null'),$null,$flow,$true,$true,$true,$true)
            Check ($tenant+$alias+$app+$flow+' real Page.HandleError retains rejection without Render') ($r.ErrorHandled -and $r.ErrorHook -and $r.Status -eq 403 -and $r.Body -eq 'Richiesta di accesso non consentita.' -and $r.Cache -match 'no-store' -and [string]::IsNullOrEmpty($r.Location))
            Check ($tenant+$alias+$app+$flow+' error after rejection preserves identity and has no login effects') ($r.LoginId -eq 77 -and $r.Queries -eq 0 -and $r.Opens -eq 0 -and $r.Reads -eq 0 -and $r.Audits -eq 0 -and $r.Merges -eq 0 -and $r.Cookies -eq 0 -and $r.Clears -eq 0)
        }
        foreach($flow in @('page','legacy')){
            $r=$candidate.Run($target,$app,'POST',@($authority),$null,$flow,$false,$true,$false,$true)
            $b=$baseline.Run($target,$app,'POST',@($authority),$null,$flow,$false,$true,$false,$true)
            Check ($tenant+$alias+$app+$flow+' wrong credentials unchanged') ($r.Status -eq $b.Status -and $r.Queries -eq 1 -and $r.Audits -eq 0 -and $r.Merges -eq 0 -and $r.LoginId -eq 0 -and $r.Cookies -eq 0 -and !$r.ErrorHook)
        }
        $r=$candidate.Run($target,$app,'POST',@($authority),$null,'page',$true,$false,$false,$true)
        Check ($tenant+$alias+$app+' invalid form remains non-authenticating') ($r.Status -eq 200 -and $r.Queries -eq 0 -and $r.Reads -eq 0)
        foreach($logged in @($false,$true)){foreach($navigationMethod in @('GET','HEAD')){
            $r=$candidate.Run($target,$app,$navigationMethod,$null,$null,'get',$true,$true,$logged,$false)
            $b=$baseline.Run($target,$app,$navigationMethod,$null,$null,'get',$true,$true,$logged,$false)
            Check ($tenant+$alias+$app+$logged+' normal '+$navigationMethod+' retains baseline') ($r.Status -eq $b.Status -and $r.Location -eq $b.Location -and $r.Body -eq $b.Body -and $r.Queries -eq 0)
        }}
    }}}
    foreach($authority in @('https://tech.invalid:8443','http://food.invalid:8080')){foreach($flow in @('page','legacy','legacy-caller')){
        $r=$candidate.Run(($authority+'/login.aspx'),'/','POST',@($authority),$null,$flow,$true,$true,$false,$true)
        $b=$baseline.Run(($authority+'/login.aspx'),'/','POST',@($authority),$null,$flow,$true,$true,$false,$true)
        Check ($authority+$flow+' current non-default origin remains valid') ($r.Status -eq 302 -and $r.LoginId -eq $b.LoginId -and $r.Listino -eq $b.Listino -and $r.Location -eq $b.Location -and $r.Queries -eq 1 -and $r.Audits -eq 1 -and $r.Merges -eq 1)
    }}
    foreach($tenant in @('tech','food')){foreach($flow in @('page','legacy','legacy-caller')){foreach($useReferer in @($false,$true)){
        $authority='https://'+$tenant+'.invalid.'
        $origin=if($useReferer){$null}else{@($authority)};$referer=if($useReferer){@($authority+'/login.aspx')}else{$null}
        $r=$candidate.Run(($authority+'/login.aspx'),'/','POST',[string[]]$origin,[string[]]$referer,$flow,$true,$true,$false,$true)
        Check ($tenant+$flow+$useReferer+' exact terminal-dot origin admitted') ($r.Status -eq 302 -and $r.Queries -eq 1 -and $r.Audits -eq 1 -and $r.Merges -eq 1)
        $r=$candidate.Run(($authority+'/login.aspx'),'/','POST',@($authority.TrimEnd('.')),$null,$flow,$true,$true,$false,$true)
        Check ($tenant+$flow+$useReferer+' terminal dot never aliases a different browser origin') ($r.Status -eq 403 -and $r.Queries -eq 0 -and $r.Reads -eq 0)
    }}}
    $r=$candidate.Run('https://unknown.invalid/login.aspx','/','POST',@('https://unknown.invalid'),$null,'page',$true,$true,$false,$true)
    Check 'unresolved tenant fails closed with no lookup' ($r.Status -eq 403 -and $r.Queries -eq 0)
    $b=$baseline.Run('https://tech.invalid/login.aspx','/','POST',@('https://evil.invalid'),$null,'page',$true,$true,$false,$true)
    Check 'baseline source boundary lacks origin refusal; not live CSRF exploit' ($b.Queries -eq 1 -and $b.Audits -eq 1)
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'test-report.json'),(@{Result='PASS';Checks=$checks.Count;ChecksDetail=$checks;Cases=$outcomes;Classification='Source-evidenced hardening; no operational CSRF exploit';Limits='Real compiled candidate/baseline methods and System.Web requests/responses/session/controls, authoritative host/return policies; DB/audit/cart, redirect/pipeline transport and page scaffolding synthetic, master Load limited to auth prefix; duplicate wire headers represented as comma-joined values, empty known Referer omitted by System.Web; not full IIS lifecycle';PageSha256=(Get-FileHash (Join-Path $RepositoryRoot 'login.aspx.vb')).Hash;MasterSha256=(Get-FileHash (Join-Path $RepositoryRoot 'Page.master.vb')).Hash}|ConvertTo-Json -Depth 12),$utf8)
    Write-Output ('LOGIN_POST_ORIGIN '+$checks.Count+'/'+$checks.Count+' PASS')
}catch{throw $_.Exception.GetBaseException().ToString()}finally{$compiler.Dispose()}
