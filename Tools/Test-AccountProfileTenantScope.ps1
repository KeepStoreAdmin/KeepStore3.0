[CmdletBinding()]
param([string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'PROFILE_TEST_REQUIRES_PS51'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
if(!$EvidenceDirectory.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)){throw 'NEW_TEMP_EVIDENCE_REQUIRED'}
[void][IO.Directory]::CreateDirectory($EvidenceDirectory)
$utf8=New-Object Text.UTF8Encoding($false)
$checks=New-Object 'Collections.Generic.List[object]'
function Check($name,[bool]$pass){$checks.Add(@{Name=$name;Pass=$pass});if(!$pass){throw ('PROFILE_ASSERT: '+$name)}}
function Source($path){[IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace("`r`n","`n")}
function Baseline($path){$s=(git -C $RepositoryRoot show ('390e529ac8021c5cb87b73b7519e9136c9a3c5ee:'+$path)) -join "`n";if($LASTEXITCODE -ne 0){throw 'PROFILE_BASE_UNAVAILABLE'};return $s}
function Methods($text){$m=@{};foreach($x in [regex]::Matches($text,'(?ms)^[ \t]*(?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) (\w+)\b.*?^[ \t]*End (?:Function|Sub)')){$m[$x.Groups[1].Value]=$x.Value};return $m}
$candidate=Source 'my-account-edit.aspx.vb';$baseline=Baseline 'my-account-edit.aspx.vb'
$new=Methods $candidate;$old=Methods $baseline
foreach($name in $old.Keys){if($name -notin @('LoadProfileData','btnSave_Click')){Check ('unchanged '+$name) (($old[$name] -replace '\s+',' ').Trim() -ceq ($new[$name] -replace '\s+',' ').Trim())}}
Check 'hidden owner stays display-only' ($candidate -notmatch '(?i)(?:SafeInt|Parse|Convert).*hidUtentiId\.Value' -and @([regex]::Matches($candidate,'hidUtentiId\.Value')).Count -eq 1)
foreach($path in @('my-account-edit.aspx','Page.master.vb','login.aspx.vb','App_Code/StorefrontSeoTenantContext.vb','App_Code/StorefrontCommercialIsolationPolicy.vb')){Check ('read-only dependency '+$path) ((git -C $RepositoryRoot hash-object -- $path) -eq (git -C $RepositoryRoot rev-parse ('HEAD:'+$path)))}
Check 'scope guard has no resolver or authentication query' ($new.CurrentProfileScope -notmatch '\.Resolve\(|New MySql|SELECT|Execute')
Check 'all candidate SQL parameters have explicit native types' ($candidate -notmatch 'AddWithValue')
$master=Methods (Source 'Page.master.vb')
$scopeMethod=$master.CurrentAuthenticatedScopeKey
if(!$scopeMethod){throw 'MASTER_SCOPE_CONTRACT_MISSING'}
$markup=Source 'my-account-edit.aspx'
$controls=@([regex]::Matches($markup,'<asp:(TextBox|HiddenField|Panel|Literal)\s+ID="([^"]+)"'))
$fields=@($controls|ForEach-Object{'    Public '+$_.Groups[2].Value+' As New '+$_.Groups[1].Value+'() With {.ID="'+$_.Groups[2].Value+'"}'}) -join "`n"
$constructor='    Public Sub New()'+"`n"+(@($controls|ForEach-Object{'        Controls.Add('+$_.Groups[2].Value+')'}) -join "`n")+"`n    End Sub"

# SQLite is isolated/in-memory. This adapter changes only unsupported MySQL syntax, never predicates.
# FOR UPDATE is recorded and stripped: real InnoDB locking/protocol remain an explicit release gate.
$nodeCode=@'
const {DatabaseSync}=require('node:sqlite'),readline=require('node:readline');let db;
function reset(){if(db)db.close();db=new DatabaseSync(':memory:');
db.exec(`CREATE TABLE utenti(Id INTEGER PRIMARY KEY,AziendeId INTEGER,Abilitato INTEGER,Codice INTEGER,RagioneSociale TEXT,CognomeNome TEXT,Piva TEXT,CodiceFiscale TEXT,Email TEXT,Indirizzo TEXT,Cap TEXT,Citta TEXT,Provincia TEXT,Nazione TEXT,Telefono TEXT,Cellulare TEXT,Fax TEXT);
CREATE TABLE login(id INTEGER PRIMARY KEY,UtentiId INTEGER,Abilitato INTEGER,UserName TEXT,Email TEXT,CognomeNome TEXT,UltimoAccesso TEXT);
CREATE VIEW vlogin AS SELECT l.*,u.AziendeId,u.CognomeNome AS UtentiCognomeNome,u.Abilitato AS UtentiAbilitato FROM login l LEFT JOIN utenti u ON l.UtentiId=u.Id;
CREATE TABLE logoperazioni(id INTEGER PRIMARY KEY,UtentiId INTEGER);
CREATE TRIGGER synthetic_user_update AFTER UPDATE ON utenti BEGIN INSERT INTO logoperazioni(UtentiId) VALUES(NEW.Id); END;`);
for(const [company,user,login] of [[1,701,101],[2,702,202]]){
db.prepare('INSERT INTO utenti VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)').run(user,company,1,user,'SYNTHETIC-COMPANY-'+company,'SYNTHETIC-NAME-'+company,'SYNTHETIC-VAT','SYNTHETIC-TAX','fixture'+company+'@example.invalid','SYNTHETIC-ADDRESS','00100','SYNTHETIC-CITY','RM','IT','+39 123','456','789');
db.prepare('INSERT INTO login VALUES(?,?,?,?,?,?,?)').run(login,user,1,'SYNTHETIC-LOGIN-'+company,'fixture'+company+'@example.invalid','SYNTHETIC-LOGIN-NAME','2026-10-24 10:00:00');}
db.prepare('INSERT INTO login SELECT 303,UtentiId,Abilitato,UserName,Email,CognomeNome,UltimoAccesso FROM login WHERE id=101').run();return {ok:true};}
function translate(sql){let q=sql.replace(/ FOR UPDATE\s*$/i,'');
const m=q.match(/^UPDATE (\w+) (\w+) INNER JOIN (\w+) (\w+) ON (.*?) SET (.*?) WHERE (.*)$/i);
if(m){const set=m[6].replace(new RegExp('\\b'+m[2]+'\\.(\\w+)(?=\\s*=)','g'),'$1');q=`UPDATE ${m[1]} AS ${m[2]} SET ${set} FROM ${m[3]} AS ${m[4]} WHERE (${m[5]}) AND (${m[7]})`;}
return q;}
function request(x){switch(x.op){
case 'reset':return reset();case 'begin':db.exec('BEGIN');return {ok:true};case 'commit':db.exec('COMMIT');return {ok:true};case 'rollback':db.exec('ROLLBACK');return {ok:true};
case 'snapshot':return {users:db.prepare('SELECT * FROM utenti ORDER BY Id').all(),logins:db.prepare('SELECT * FROM login ORDER BY id').all(),logs:db.prepare('SELECT * FROM logoperazioni ORDER BY id').all()};
case 'mutate':{
 const id=x.id; switch(x.kind){case 'disable-login':db.prepare('UPDATE login SET Abilitato=0 WHERE id=?').run(id);break;case 'disable-user':db.prepare('UPDATE utenti SET Abilitato=0 WHERE Id=?').run(x.user);break;case 'reassign-owner':db.prepare('UPDATE login SET UtentiId=? WHERE id=?').run(x.otherUser,id);break;case 'move-company':db.prepare('UPDATE utenti SET AziendeId=? WHERE Id=?').run(x.otherCompany,x.user);break;case 'delete-login':db.prepare('DELETE FROM login WHERE id=?').run(id);break;case 'delete-user':db.prepare('DELETE FROM utenti WHERE Id=?').run(x.user);break;default:throw Error('UNKNOWN_MUTATION');}return {ok:true};}
case 'query':{const q=translate(x.sql),statement=db.prepare(q);statement.setAllowUnknownNamedParameters(true);const p={};for(const [k,v]of Object.entries(x.parameters))p[k.replace(/^[@?]/,'')]=v;
return /^SELECT/i.test(q)?{rows:statement.all(p)}:{changes:Number(statement.run(p).changes)};}
case 'close':if(db)db.close();return {ok:true};default:throw Error('UNKNOWN_OPERATION');}}
readline.createInterface({input:process.stdin,crlfDelay:Infinity}).on('line',line=>{try{const x=JSON.parse(line),r=request(x);process.stdout.write(JSON.stringify(r)+'\n');if(x.op==='close')process.exit(0);}catch(e){process.stdout.write(JSON.stringify({error:String(e.message)})+'\n');}});
'@
$support=@'
Imports System
Imports System.IO
Imports System.Data
Imports System.Diagnostics
Imports System.Collections.Generic
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.SessionState
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.Script.Serialization
Imports MySql.Data.MySqlClient
Public Class Fixture
    Public Shared Process As Process
    Public Shared Json As New JavaScriptSerializer() With {.MaxJsonLength=8388608}
    Public Shared ConnectionString As String
    Public Shared DatabaseScope As String="SYNTHETIC-DATABASE-SCOPE"
    Public Shared Reads, Writes, Opens, Begins, Commits, Rollbacks As Integer
    Public Shared BeforeBegin, During As String
    Public Shared FailureUpdate, OverrideUpdate, OverrideCount As Integer
    Public Shared SqlLog As New List(Of Object)()
    Public Shared Company, UserId, LoginId As Integer
    Public Shared MatchedConnection, SettingsPreserved As Boolean
    Public Shared Sub Start(node As String,code As String,directory As String)
        Dim info As New ProcessStartInfo(node,"--experimental-sqlite -e ""eval(Buffer.from(process.env.PROFILE_FIXTURE_SOURCE,'base64').toString('utf8'))""")
        info.WorkingDirectory=directory:info.UseShellExecute=False:info.CreateNoWindow=True
        info.RedirectStandardInput=True:info.RedirectStandardOutput=True:info.RedirectStandardError=True
        info.EnvironmentVariables("PROFILE_FIXTURE_SOURCE")=Convert.ToBase64String(Text.Encoding.UTF8.GetBytes(code))
        Process=Diagnostics.Process.Start(info)
    End Sub
    Public Shared Function Send(op As String,Optional sql As String=Nothing,Optional parameters As Object=Nothing) As Dictionary(Of String,Object)
        Dim message As New Dictionary(Of String,Object) From {{"op",op},{"sql",sql},{"parameters",parameters}}
        Process.StandardInput.WriteLine(Json.Serialize(message)):Process.StandardInput.Flush()
        Dim line=Process.StandardOutput.ReadLine()
        If line Is Nothing Then Throw New InvalidOperationException("SYNTHETIC-WORKER-EXIT")
        Dim result=Json.Deserialize(Of Dictionary(Of String,Object))(line)
        If result.ContainsKey("error") Then Throw New InvalidOperationException("SYNTHETIC-SQL-ERROR: " & CStr(result("error")))
        Return result
    End Function
    Public Shared Sub Mutate(kind As String)
        Dim message As New Dictionary(Of String,Object) From {{"op","mutate"},{"kind",kind},{"id",LoginId},{"user",UserId},{"otherUser",If(UserId=701,702,701)},{"otherCompany",3-Company}}
        Process.StandardInput.WriteLine(Json.Serialize(message)):Process.StandardInput.Flush()
        Dim result=Json.Deserialize(Of Dictionary(Of String,Object))(Process.StandardOutput.ReadLine())
        If result.ContainsKey("error") Then Throw New InvalidOperationException("SYNTHETIC-MUTATION-ERROR")
    End Sub
    Public Shared Sub Reset(companyId As Integer,mode As Boolean)
        Send("reset"):Company=companyId:UserId=If(companyId=1,701,702):LoginId=If(companyId=1,101,202)
        ConnectionString="Server=synthetic.invalid;Port=3307;Database=SYNTHETIC-FIXTURE;Character Set=utf8mb4;SslMode=VerifyFull;UseAffectedRows=" & mode.ToString()
        Reads=0:Writes=0:Opens=0:Begins=0:Commits=0:Rollbacks=0:BeforeBegin="":During="":FailureUpdate=0:OverrideUpdate=0:OverrideCount=0:MatchedConnection=False:SettingsPreserved=True:SqlLog.Clear()
    End Sub
    Public Shared Sub StopWorker()
        If Process Is Nothing Then Return
        Try
            If Not Process.HasExited Then Send("close")
            If Not Process.WaitForExit(5000) Then Process.Kill()
        Finally
            Process.Dispose():Process=Nothing
        End Try
    End Sub
End Class
Public Class FixtureConnection
    Implements IDisposable
    Public ReadOnly Settings As MySqlConnectionStringBuilder
    Public Sub New(connectionString As String)
        Settings=New MySqlConnectionStringBuilder(connectionString)
    End Sub
    Public Sub Open()
        Fixture.Opens+=1
    End Sub
    Public Function BeginTransaction() As FixtureTransaction
        If Fixture.BeforeBegin<>"" Then Fixture.Mutate(Fixture.BeforeBegin)
        Fixture.MatchedConnection=Not Settings.UseAffectedRows
        Dim original As New MySqlConnectionStringBuilder(Fixture.ConnectionString)
        For Each key As String In original.Keys
            If Not String.Equals(key.Replace(" ",""),"useaffectedrows",StringComparison.OrdinalIgnoreCase) AndAlso
               Not Object.Equals(original(key),Settings(key)) Then Fixture.SettingsPreserved=False
        Next
        Fixture.Send("begin"):Fixture.Begins+=1
        Return New FixtureTransaction()
    End Function
    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub
End Class
Public Class FixtureTransaction
    Implements IDisposable
    Private finished As Boolean
    Public Sub Commit()
        Fixture.Send("commit"):Fixture.Commits+=1:finished=True
    End Sub
    Public Sub Dispose() Implements IDisposable.Dispose
        If Not finished Then Fixture.Send("rollback"):Fixture.Rollbacks+=1:finished=True
    End Sub
End Class
Public Class FixtureCommand
    Implements IDisposable
    Private native As MySqlCommand
    Private connection As FixtureConnection
    Private transaction As FixtureTransaction
    Public Sub New(sql As String,c As FixtureConnection,Optional t As FixtureTransaction=Nothing)
        native=New MySqlCommand(sql):connection=c:transaction=t
    End Sub
    Public ReadOnly Property Parameters As MySqlParameterCollection
        Get
            Return native.Parameters
        End Get
    End Property
    Private Function Execute() As Dictionary(Of String,Object)
        Dim parameters As New Dictionary(Of String,Object)(),types As New Dictionary(Of String,String)()
        For Each p As MySqlParameter In native.Parameters
            parameters(p.ParameterName)=p.Value:types(p.ParameterName)=p.MySqlDbType.ToString()
        Next
        Dim read=native.CommandText.StartsWith("SELECT",StringComparison.OrdinalIgnoreCase)
        Fixture.SqlLog.Add(New With {.Sql=native.CommandText,.Parameters=parameters,.Types=types,.Transaction=transaction IsNot Nothing})
        If read Then
            Fixture.Reads+=1
        Else
            Fixture.Writes+=1
            If Fixture.Writes=Fixture.FailureUpdate Then Throw New InvalidOperationException("SYNTHETIC-SECOND-UPDATE-FAILURE")
        End If
        Dim result=Fixture.Send("query",native.CommandText,parameters)
        If Not read AndAlso Fixture.Writes=1 AndAlso Fixture.During<>"" Then
            Select Case Fixture.During
                Case "marker" : HttpContext.Current.Items.Remove("KeepStore.Authentication.ValidatedScope")
                Case "owner" : HttpContext.Current.Session("UtentiId")=If(Fixture.UserId=701,702,701)
                Case "company" : HttpContext.Current.Session("AuthenticatedAziendaID")=3-Fixture.Company
                Case "listino" : HttpContext.Current.Session("Listino")=99
            End Select
        End If
        Return result
    End Function
    Public Function ExecuteReader() As FixtureReader
        Return New FixtureReader(Execute())
    End Function
    Public Function ExecuteNonQuery() As Integer
        Dim result=Execute()
        If Fixture.Writes=Fixture.OverrideUpdate Then Return Fixture.OverrideCount
        Return Convert.ToInt32(result("changes"))
    End Function
    Public Sub Dispose() Implements IDisposable.Dispose
        native.Dispose()
    End Sub
End Class
Public Class FixtureReader
    Implements IDisposable
    Private rows As Object()
    Private position As Integer=-1
    Public Sub New(result As Dictionary(Of String,Object))
        rows=DirectCast(result("rows"),Collections.ArrayList).ToArray()
    End Sub
    Public Function Read() As Boolean
        position+=1:Return position<rows.Length
    End Function
    Default Public ReadOnly Property Item(name As String) As Object
        Get
            Dim row=DirectCast(rows(position),Dictionary(Of String,Object))
            Return If(row.ContainsKey(name),row(name),DBNull.Value)
        End Get
    End Property
    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub
End Class
Public Class ProfileFrame
    Inherits Control
    Implements INamingContainer
    Public Shadows ReadOnly Property Context As HttpContext
        Get
            Return HttpContext.Current
        End Get
    End Property
    Public ReadOnly Property Session As HttpSessionState
        Get
            Return Context.Session
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
    Public ReadOnly Property Server As HttpServerUtility
        Get
            Return Context.Server
        End Get
    End Property
    Public IsPostBack As Boolean
    Public Title As String="SYNTHETIC"
End Class
Public Class StorefrontSeoTenantContext
    Public Shared Function ConfiguredDatabaseScopeKey() As String
        Return Fixture.DatabaseScope
    End Function
End Class
Public Class RedirectTransport
    Public Shared Sub Apply(response As HttpResponse,target As String,terminate As Boolean)
        response.StatusCode=302:response.RedirectLocation=target
    End Sub
End Class
'@
$scopeClass=@'
Imports System
Imports System.Web
Public Class ScopeMaster
    Inherits ProfileFrame
    Private Function CurrentLoginIdSafe() As Integer
        Return StorefrontCommercialIsolationPolicy.PositiveInteger(Session("LoginId"))
    End Function
__SCOPE_METHOD__
    Public Function Stamp(companyId As Integer) As String
        Return CurrentAuthenticatedScopeKey(companyId)
    End Function
End Class
'@
$probe=@'
    Public Sub Submit()
        btnSave_Click(Nothing,EventArgs.Empty)
    End Sub
    Public Sub Navigate()
        Page_Load(Nothing,EventArgs.Empty)
    End Sub
'@
$runner=@'
Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.SessionState
Public Class Runner
    Public Sub Start(node As String,code As String,directory As String)
        Fixture.Start(node,code,directory)
    End Sub
    Public Sub Finish()
        Fixture.StopWorker()
    End Sub
    Public Function Replay(company As Integer,sql As String,parameters As String,mutation As String) As String
        Fixture.Reset(company,False)
        If mutation<>"" Then Fixture.Mutate(mutation)
        Dim before=Fixture.Send("snapshot")
        Dim result=Fixture.Send("query",sql,Fixture.Json.Deserialize(Of Dictionary(Of String,Object))(parameters))
        Return Fixture.Json.Serialize(New With {.Before=before,.After=Fixture.Send("snapshot"),.Result=result})
    End Function
    Public Function Run(candidate As Boolean,company As Integer,scenario As String,affected As Boolean) As String
        Fixture.Reset(company,affected)
        Dim requestedScenario=scenario
        Dim reading=scenario="read" OrElse scenario.StartsWith("read/",StringComparison.Ordinal)
        If scenario.StartsWith("read/",StringComparison.Ordinal) Then scenario=scenario.Substring(5)
        Dim context As New HttpContext(New SimpleWorkerRequest("/","C:\synthetic-profile-only\","my-account-edit.aspx","",New StringWriter()))
        HttpContext.Current=context
        SessionStateUtility.AddHttpSessionStateToContext(context,New HttpSessionStateContainer("SYNTHETIC",New SessionStateItemCollection(),New HttpStaticObjectsCollection(),20,True,HttpCookieMode.UseCookies,SessionStateMode.InProc,False))
        Dim session=context.Session
        session("LoginId")=Fixture.LoginId:session("UtentiId")=Fixture.UserId:session("AziendaID")=company:session("AuthenticatedAziendaID")=company:session("Listino")=If(company=1,1,10)
        Dim tenant=StorefrontCanonicalHostPolicy.CreateTenant(company,"SYNTHETIC","SYNTHETIC","https://fixture.invalid/","","",If(company=1,1,10))
        context.Items("KeepStore.StorefrontSeoTenant")=tenant
        Dim stamp As New ScopeMaster()
        context.Items("KeepStore.Authentication.ValidatedScope")=stamp.Stamp(company)
        Select Case scenario
            Case "absent-session" : session.Clear()
            Case "absent-marker" : context.Items.Remove("KeepStore.Authentication.ValidatedScope")
            Case "wrong-marker" : context.Items("KeepStore.Authentication.ValidatedScope")="SYNTHETIC-WRONG"
            Case "wrong-owner" : session("UtentiId")=If(company=1,702,701):context.Items("KeepStore.Authentication.ValidatedScope")=stamp.Stamp(company)
            Case "other-company" : session("LoginId")=If(company=1,202,101):session("UtentiId")=If(company=1,702,701):context.Items("KeepStore.Authentication.ValidatedScope")=stamp.Stamp(company)
            Case "company-marker" : session("AuthenticatedAziendaID")=3-company
            Case "company-session" : session("AziendaID")=3-company
            Case "missing-tenant" : context.Items.Remove("KeepStore.StorefrontSeoTenant")
            Case "invalid-listino" : session("Listino")=0
            Case "revoked-marker" : session.Remove("AuthenticatedAziendaID")
            Case "bad-login" : session("LoginId")="1 OR 1=1"
            Case "bad-owner" : session("UtentiId")="2147483648"
            Case "mismatched-db" : Fixture.DatabaseScope="SYNTHETIC-OTHER-DATABASE"
            Case "missing-db" : Fixture.DatabaseScope=""
            Case "same-owner-second-login" : session("LoginId")=303:context.Items("KeepStore.Authentication.ValidatedScope")=stamp.Stamp(company)
            Case "disable-login","disable-user","delete-login","delete-user","reassign-owner","move-company" : Fixture.Mutate(scenario)
            Case "before-lock-disable","before-lock-reassign" : Fixture.BeforeBegin=If(scenario="before-lock-disable","disable-login","reassign-owner")
            Case "during-marker","during-owner","during-company","during-listino" : Fixture.During=scenario.Substring(7)
            Case "second-update-error" : Fixture.FailureUpdate=2
            Case "first-zero","first-two","first-negative","second-zero","second-two" : Fixture.OverrideUpdate=If(scenario.StartsWith("first"),1,2):Fixture.OverrideCount=If(scenario.EndsWith("zero"),0,If(scenario.EndsWith("negative"),-1,2))
        End Select
        Dim before=Fixture.Send("snapshot")
        Dim instance As Object=If(candidate,DirectCast(New ProfileCandidate(),Object),New ProfileBaseline())
        instance.hidUtentiId.Value=If(scenario="hidden-owner",If(company=1,702,701).ToString(),Fixture.UserId.ToString())
        instance.txtEmail.Text=If(scenario="unchanged","fixture" & company.ToString() & "@example.invalid","updated" & company.ToString() & "@example.invalid")
        instance.txtTelefono.Text=If(scenario="unchanged","+39 123","+39 987")
        instance.txtCellulare.Text=If(scenario="unchanged","456",""):instance.txtFax.Text=If(scenario="unchanged","789","")
        ' Blank address inputs keep existing values through the real MergeText contract.
        If scenario="invalid-email" Then instance.txtEmail.Text="SYNTHETIC-NOT-EMAIL"
        If scenario="invalid-phone" Then instance.txtTelefono.Text="SYNTHETIC-NOT-PHONE"
        If scenario="long-email" Then instance.txtEmail.Text=New String("x"c,51) & "@example.invalid"
        If reading Then
            For Each control As System.Web.UI.Control In DirectCast(instance,ProfileFrame).Controls
                Dim text=TryCast(control,System.Web.UI.WebControls.TextBox)
                If text IsNot Nothing Then text.Text=""
            Next
            instance.Navigate()
        Else
            instance.Submit()
        End If
        Dim displayed As New Dictionary(Of String,Object)()
        For Each control As System.Web.UI.Control In DirectCast(instance,ProfileFrame).Controls
            Dim text=TryCast(control,System.Web.UI.WebControls.TextBox)
            If text IsNot Nothing Then displayed(control.ID)=text.Text
        Next
        Dim result As New Dictionary(Of String,Object) From {
            {"Scenario",requestedScenario},{"Candidate",candidate},{"Company",company},{"Before",before},{"After",Fixture.Send("snapshot")},{"Displayed",displayed},
            {"Reads",Fixture.Reads},{"Writes",Fixture.Writes},{"Opens",Fixture.Opens},{"Begins",Fixture.Begins},{"Commits",Fixture.Commits},{"Rollbacks",Fixture.Rollbacks},
            {"Sql",Fixture.SqlLog.ToArray()},{"Success",instance.pnlMessage.CssClass="alert alert-success mb-4"},{"Message",instance.litMessage.Text},
            {"Email",instance.txtEmail.Text},{"ProfileVisible",instance.pnlProfile.Visible},{"Status",context.Response.StatusCode},{"Location",context.Response.RedirectLocation},
            {"MatchedConnection",Fixture.MatchedConnection},{"SettingsPreserved",Fixture.SettingsPreserved},{"LoginId",Convert.ToString(session("LoginId"))},{"UserId",Convert.ToString(session("UtentiId"))},{"Listino",Convert.ToString(session("Listino"))}}
        Fixture.DatabaseScope="SYNTHETIC-DATABASE-SCOPE"
        Return Fixture.Json.Serialize(result)
    End Function
End Class
'@
function Materialize($text,$name){
    $text=$text.Replace('Partial Class my_account_edit',('Public Class '+$name)).Replace('Inherits System.Web.UI.Page','Inherits ProfileFrame')
    $text=[regex]::Replace($text,' Handles [^\r\n]+','')
    $text=$text.Replace('ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString','Fixture.ConnectionString')
    foreach($t in @('Connection','Transaction','Command','DataReader')){$replacement=@{Connection='Connection';Transaction='Transaction';Command='Command';DataReader='Reader'}[$t];$text=[regex]::Replace($text,('\bMySql'+$t+'\b'),('Fixture'+$replacement))}
    $text=$text.Replace('Response.Redirect(','RedirectTransport.Apply(Response,')
    $at=$text.LastIndexOf('End Class');return $text.Substring(0,$at)+$fields+"`n"+$constructor+"`n"+$probe+"`nEnd Class"
}
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Web.Extensions
$mysql=Join-Path $RepositoryRoot 'Bin\MySql.Data.dll';[void][Reflection.Assembly]::LoadFrom($mysql)
$compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
$runnerInstance=$null
try{
    $options=New-Object CodeDom.Compiler.CompilerParameters
    $options.GenerateInMemory=$true;$options.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    $options.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($EvidenceDirectory,$false)
    foreach($r in @('System.dll','System.Core.dll','System.Data.dll','System.Web.dll','System.Web.Extensions.dll','System.Configuration.dll',$mysql)){[void]$options.ReferencedAssemblies.Add($r)}
    $sources=@($support,$scopeClass.Replace('__SCOPE_METHOD__',$scopeMethod),(Materialize $candidate 'ProfileCandidate'),(Materialize $baseline 'ProfileBaseline'),$runner,(Source 'App_Code/StorefrontCanonicalHostPolicy.vb'),(Source 'App_Code/StorefrontCommercialIsolationPolicy.vb'))
    $compiled=$compiler.CompileAssemblyFromSource($options,[string[]]$sources)
    if($compiled.Errors.HasErrors){throw (($compiled.Errors|Where-Object{!$_.IsWarning}|ForEach-Object{'line '+$_.Line+': '+$_.ErrorText}) -join '; ')}
    $runnerInstance=[Activator]::CreateInstance($compiled.CompiledAssembly.GetType('Runner'))
    $runnerInstance.Start((Get-Command node.exe -ErrorAction Stop).Source,$nodeCode,$EvidenceDirectory)
    $results=New-Object 'Collections.Generic.List[object]'
    function Run([bool]$new,[int]$company,[string]$scenario,[bool]$mode=$false){$json=$runnerInstance.Run($new,$company,$scenario,$mode);$r=$json|ConvertFrom-Json;$results.Add($r);return $r}
    foreach($company in @(1,2)){foreach($mode in @($false,$true)){
        foreach($case in @('save','unchanged','hidden-owner')){
            $b=Run $false $company $case $mode;$r=Run $true $company $case $mode
            Check ($company.ToString()+$mode+$case+' preserves success and complete data') ($r.Success -and $r.Commits -eq 1 -and $r.Writes -eq 2 -and ($r.After|ConvertTo-Json -Depth 8 -Compress) -ceq ($b.After|ConvertTo-Json -Depth 8 -Compress))
            Check ($company.ToString()+$mode+$case+' lock before two updates and same query budget') ($r.Sql[0].Sql -match 'FOR UPDATE$' -and $r.Sql[0].Transaction -and $r.Sql[1].Transaction -and $r.Sql[2].Transaction -and $r.Reads -eq $b.Reads -and $r.Reads -eq 2 -and $r.MatchedConnection -and $r.SettingsPreserved)
            Check ($company.ToString()+$mode+$case+' commercial session preserved') ($r.LoginId -eq $b.LoginId -and $r.UserId -eq $b.UserId -and $r.Listino -eq $b.Listino)
            foreach($q in $r.Sql){foreach($p in $q.Types.PSObject.Properties){Check ($case+' typed '+$p.Name) ($p.Value -eq $(if($p.Name -in @('@LoginId','@UtentiId','@AziendaId')){'Int32'}else{'VarChar'}))}}
        }
        $r=Run $true $company 'read' $mode;$b=Run $false $company 'read' $mode
        Check ($company.ToString()+$mode+' authorized full projection matches baseline') (($r.Displayed|ConvertTo-Json -Compress) -ceq ($b.Displayed|ConvertTo-Json -Compress) -and $r.Reads -eq 1 -and $r.Writes -eq 0 -and $r.Begins -eq 0)
        foreach($case in @('absent-session','absent-marker','wrong-marker','company-marker','company-session','missing-tenant','invalid-listino','revoked-marker','bad-login','bad-owner','mismatched-db','missing-db')){
            $r=Run $true $company $case $mode
            Check ($company.ToString()+$mode+$case+' no profile IO') (!$r.Success -and $r.Reads -eq 0 -and $r.Writes -eq 0 -and $r.Opens -eq 0 -and ($r.Before|ConvertTo-Json -Depth 8 -Compress) -ceq ($r.After|ConvertTo-Json -Depth 8 -Compress))
            $read=Run $true $company ('read/'+$case) $mode
            Check ($company.ToString()+$mode+$case+' read also fails before IO') ($read.Reads -eq 0 -and $read.Writes -eq 0 -and $read.Opens -eq 0 -and $read.Email -eq '')
        }
        foreach($case in @('other-company','wrong-owner','disable-login','disable-user','delete-login','delete-user','reassign-owner','move-company','before-lock-disable','before-lock-reassign')){
            $r=Run $true $company $case $mode
            Check ($company.ToString()+$mode+$case+' SQL rejects tuple before update') (!$r.Success -and $r.Writes -eq 0 -and $r.Commits -eq 0 -and $r.Rollbacks -eq 1)
            if($case -notlike 'before-lock-*'){
                $read=Run $true $company ('read/'+$case) $mode
                Check ($company.ToString()+$mode+$case+' profile read also scoped') (!$read.ProfileVisible -and $read.Reads -eq 1 -and $read.Writes -eq 0)
            }
        }
        foreach($case in @('second-update-error','first-zero','first-two','first-negative','second-zero','second-two','during-marker','during-owner','during-company','during-listino')){
            $r=Run $true $company $case $mode
            Check ($company.ToString()+$mode+$case+' full rollback and no success') (!$r.Success -and $r.Commits -eq 0 -and $r.Rollbacks -eq 1 -and ($r.Before|ConvertTo-Json -Depth 8 -Compress) -ceq ($r.After|ConvertTo-Json -Depth 8 -Compress))
        }
        foreach($case in @('invalid-email','invalid-phone','long-email')){
            $r=Run $true $company $case $mode;$b=Run $false $company $case $mode
            Check ($company.ToString()+$mode+$case+' validation message retained without writes') (!$r.Success -and $r.Message -ceq $b.Message -and $r.Writes -eq 0 -and $r.Commits -eq 0)
        }
    }}
    $b=Run $false 1 'same-owner-second-login';$r=Run $true 1 'same-owner-second-login'
    Check 'multiple login rows per same owner retain exact current login' ($r.Success -and ($r.After|ConvertTo-Json -Depth 8 -Compress) -ceq ($b.After|ConvertTo-Json -Depth 8 -Compress))
    foreach($company in @(1,2)){
        $r=Run $true $company 'save'
        foreach($q in @($r.Sql[0],$r.Sql[1],$r.Sql[2])){
            foreach($field in @('@LoginId','@UtentiId','@AziendaId')){
                $params=@{};foreach($p in $q.Parameters.PSObject.Properties){$params[$p.Name]=$p.Value}
                $params[$field]=if($field -eq '@LoginId'){if($company -eq 1){202}else{101}}elseif($field -eq '@UtentiId'){if($company -eq 1){702}else{701}}else{3-$company}
                $replay=$runnerInstance.Replay($company,$q.Sql,($params|ConvertTo-Json -Compress),'')|ConvertFrom-Json
                $rejected=if($q.Sql.StartsWith('SELECT')){@($replay.Result.rows).Count -eq 0}else{$replay.Result.changes -eq 0}
                Check ($company.ToString()+$q.Sql.Substring(0,6)+$field+' emitted predicate rejects mismatched tuple independently') ($rejected -and ($replay.Before|ConvertTo-Json -Depth 8 -Compress) -ceq ($replay.After|ConvertTo-Json -Depth 8 -Compress))
            }
            foreach($mutation in @('disable-login','disable-user','delete-login','delete-user','move-company','reassign-owner')){
                $replay=$runnerInstance.Replay($company,$q.Sql,($q.Parameters|ConvertTo-Json -Compress),$mutation)|ConvertFrom-Json
                $rejected=if($q.Sql.StartsWith('SELECT')){@($replay.Result.rows).Count -eq 0}else{$replay.Result.changes -eq 0}
                Check ($company.ToString()+$q.Sql.Substring(0,6)+$mutation+' emitted predicate rejects revocation independently') ($rejected -and ($replay.Before|ConvertTo-Json -Depth 8 -Compress) -ceq ($replay.After|ConvertTo-Json -Depth 8 -Compress))
            }
        }
    }
    $b=Run $false 1 'other-company';Check 'baseline missing SQL tenant barrier characterized, not live exploit' ($b.Success -and $b.Writes -eq 2)
    $b=Run $false 1 'wrong-owner';Check 'baseline missing SQL session-owner barrier characterized' ($b.Success -and $b.Writes -eq 2)
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'test-report.json'),(@{Result='PASS';Checks=$checks.Count;Details=$checks;Cases=$results;Provider=[MySql.Data.MySqlClient.MySqlCommand].Assembly.GetName().Version.ToString();RuntimeHash=(Get-FileHash -LiteralPath (Join-Path $RepositoryRoot 'my-account-edit.aspx.vb')).Hash;Limits='Compiled real candidate/baseline methods; real System.Web controls/session, native MySql commands/parameters/builder; connection/transaction/reader IO adapted to isolated in-memory SQLite. UPDATE JOIN syntax translated without changing predicates; FOR UPDATE recorded/removed, no actual InnoDB locking or found-row protocol certification. Master scope-key method real, prior validation/configuration synthetic; no IIS/MySQL operational or personal data.'}|ConvertTo-Json -Depth 18),$utf8)
    Write-Output ('ACCOUNT_PROFILE_TENANT '+$checks.Count+'/'+$checks.Count+' PASS')
}finally{if($null -ne $runnerInstance){$runnerInstance.Finish()};$compiler.Dispose()}
