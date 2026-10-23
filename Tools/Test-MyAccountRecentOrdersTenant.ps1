[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaseRef = '4582271a750da47375fa8e0eb995ef7149935eab',
    [switch]$BaselineOnly
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 / .NET Framework.' }
if (!$RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory)
if (!$EvidenceDirectory.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)) { throw 'Evidence requires a new TEMP directory.' }
[void][IO.Directory]::CreateDirectory($EvidenceDirectory)
$utf8 = New-Object Text.UTF8Encoding($false)
$checks = New-Object 'Collections.Generic.List[object]'
function Check([string]$Name,[bool]$Pass) { $checks.Add([pscustomobject]@{Name=$Name;Pass=$Pass}); if (!$Pass) { throw ('RECENT_ORDERS_ASSERT: '+$Name) } }
function Source([string]$Path) { [IO.File]::ReadAllText((Join-Path $RepositoryRoot $Path)).Replace("`r`n","`n") }
function BaseSource([string]$Path,[switch]$ViewOnly) {
    $info=New-Object Diagnostics.ProcessStartInfo; $info.FileName=(Get-Command git.exe).Source
    $info.WorkingDirectory=$RepositoryRoot; $info.Arguments='show "'+$BaseRef+':'+$Path+'"'
    if($ViewOnly){$info.Arguments='grep -i -E "CREATE.*VIEW .vdocumenti. AS" "'+$BaseRef+'" -- "'+$Path+'"'}
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true; $info.StandardOutputEncoding=$utf8
    $p=[Diagnostics.Process]::Start($info)
    try { $text=$p.StandardOutput.ReadToEnd(); $null=$p.StandardError.ReadToEnd(); $p.WaitForExit(); if($p.ExitCode){throw 'Base source unavailable'}; return $text.Replace("`r`n","`n") } finally {$p.Dispose()}
}
function Method([string]$Text,[string]$Name,[string]$Kind='Function') {
    $m=[regex]::Match($Text,'(?ms)^    (?:Protected|Private) '+$Kind+' '+$Name+'\(.*?^    End '+$Kind)
    if(!$m.Success){throw ('Method unavailable: '+$Name)}; return $m.Value
}
function DataSourceContract([string]$Text) {
    $m=[regex]::Match($Text,'(?s)<asp:SqlDataSource ID="sdsRecentOrders".*?</asp:SqlDataSource>'); if(!$m.Success){throw 'Recent orders datasource unavailable'}
    $sql=[Net.WebUtility]::HtmlDecode([regex]::Match($m.Value,'SelectCommand="([^"]+)"').Groups[1].Value)
    $parameters=@([regex]::Matches($m.Value,'<asp:SessionParameter\s+([^>]+)/>')|ForEach-Object{[xml]$x=('<p '+$_.Groups[1].Value+'/>'); [pscustomobject]@{Name=[string]$x.p.Name;Field=[string]$x.p.SessionField;Type=[string]$x.p.Type}})
    return [pscustomobject]@{Sql=$sql;Parameters=$parameters}
}
$base=BaseSource 'myaccount.aspx'; $candidate=Source 'myaccount.aspx'; $master=Source 'Page.master.vb'; $code=Source 'myaccount.aspx.vb'
$before=DataSourceContract $base; $after=DataSourceContract $candidate
Check 'Baseline has owner but no document company predicate' ($before.Sql.Contains('vdocumenti.UtentiId = ?UtentiId') -and !$before.Sql.Contains('vdocumenti.AziendeId'))
if($BaselineOnly){Check 'Baseline run precedes runtime patch' ($candidate -ceq $base)} else {
    $restored=$candidate.Replace(' AND vdocumenti.AziendeId = ?AziendaId','').Replace('                        <asp:SessionParameter Name="AziendaId" SessionField="AuthenticatedAziendaID" Type="Int32" />'+"`n",'')
    Check 'Only company predicate and typed authenticated parameter changed' ($restored -ceq $base)
    Check 'Conjunctive tenant predicate before ordering and limit' ($after.Sql -match 'UtentiId = \?UtentiId AND vdocumenti.AziendeId = \?AziendaId AND vdocumenti.TipoDocumentiId = 4 ORDER BY vdocumenti.ID DESC LIMIT 5$')
    Check 'Two typed session parameters with no defaults' ($after.Parameters.Count -eq 2 -and @($after.Parameters|Where-Object{$_.Type -ne 'Int32'}).Count -eq 0 -and $after.Parameters[1].Field -ceq 'AuthenticatedAziendaID')
}
foreach($path in @('myaccount.aspx.vb','Page.master.vb','documenti.aspx.vb','App_Code/StorefrontCommercialIsolationPolicy.vb')) { Check ('Unchanged '+$path) ((Source $path) -ceq (BaseSource $path)) }
$ddl=BaseSource 'Database Taikun/KeepStore.sql' -ViewOnly
$view=[regex]::Match($ddl,'(?im)^.*CREATE[^\r\n]*VIEW `vdocumenti` AS ([^\r\n]+)').Groups[1].Value
Check 'Versioned view exposes document owner and company without row scope' ($view.Contains('`documenti`.`AziendeId` AS `AziendeId`') -and $view.Contains('`documenti`.`UtentiId` AS `UtentiId`') -and $view -notmatch '(?i)\bwhere\b|current_user|@')
$ddl=$null; $view=$null
Check 'Master resolves tenant during Init before data binding' ($master -match '(?s)Protected Sub Page_Init.*?LeggiAzienda\(\)' -and $master.Contains('EnsureAuthenticatedStorefrontScope(resolvedTenant.CompanyId, resolvedTenant.DefaultPriceListId)'))
Check 'Master retains host/session mismatch revocation' ($master.Contains('StorefrontCommercialIsolationPolicy.ShouldClearAuthentication(') -and $master.Contains('RejectAuthenticatedRequestWithoutTenant()'))
Check 'Anonymous dashboard still redirects' ($code -match '(?s)If Me.Session\("LoginId"\) Is Nothing Then.*?Response.Redirect\("accessonegato.aspx", True\)')
Check 'Detail link unchanged' ($candidate.Contains('Eval("Id", "documentidettaglio.aspx?id={0}")'))
$authMethods=@((Method $master 'CurrentLoginIdSafe'),(Method $master 'ClearStorefrontAuthenticationState' 'Sub'),(Method $master 'RejectStorefrontAuthentication' 'Sub'),(Method $master 'EnsureAuthenticatedStorefrontScope' 'Sub')) -join "`n"
# Only the test extraction substitutes the connection setting and I/O types.
# The actual guard statements, session hydration and rejection remain unchanged.
$authMethods=$authMethods.Replace('Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString','Dim connectionString As String = String.Empty')
$paymentMethods=@('GetPaymentStatusLabel','GetPaymentStatusCssClass','GetPaymentStatusDescription','SafePaymentMessage','SafeStatusText','SafeInt','TruncateText')|ForEach-Object{Method $code $_}
$vb=@'
Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Data
Imports System.Data.Common
Imports System.IO
Imports System.Web
Imports System.Web.SessionState
Imports System.Web.UI
Imports System.Web.UI.WebControls
Public Class NativeSource
    Inherits SqlDataSource
    Protected Overrides Function GetDbProviderFactory() As DbProviderFactory
        Return MySql.Data.MySqlClient.MySqlClientFactory.Instance
    End Function
End Class
Public Class BoundCommand
    Public Sql As String
    Public Captured As Boolean
    Public Names As New List(Of String)
    Public Values As New List(Of Object)
    Public Types As New List(Of String)
    Public Provider As String
    Public NullCancellation As Boolean
End Class
Public Class BindingProbe
    Public Shared Sub Context(values As Hashtable)
        Dim context As New HttpContext(New HttpRequest("", "https://synthetic.invalid/myaccount.aspx", ""), New HttpResponse(New StringWriter()))
        If values IsNot Nothing Then
            Dim state As New HttpSessionStateContainer("SYNTHETIC_SESSION",New SessionStateItemCollection(),New HttpStaticObjectsCollection(),20,True,HttpCookieMode.UseCookies,SessionStateMode.InProc,False)
            SessionStateUtility.AddHttpSessionStateToContext(context,state)
            For Each entry As DictionaryEntry In values
                If entry.Value IsNot Nothing Then context.Session(CStr(entry.Key))=entry.Value
            Next
        End If
        HttpContext.Current=context
    End Sub
    Public Shared Function Bind(sql As String,names As String(),fields As String()) As BoundCommand
        Dim result As New BoundCommand With {.Sql=sql}
        Using source As New NativeSource()
            source.ID="sdsRecentOrders"
            source.ConnectionString=String.Empty
            source.ProviderName="MySql.Data.MySqlClient"
            source.SelectCommand=sql
            For i As Integer=0 To names.Length-1
                source.SelectParameters.Add(New SessionParameter(names(i),TypeCode.Int32,fields(i)))
            Next
            result.NullCancellation=source.CancelSelectOnNullParameter
            AddHandler source.Selecting, Sub(sender As Object,e As SqlDataSourceSelectingEventArgs)
                result.Captured=True
                result.Provider=e.Command.GetType().FullName
                For Each parameter As DbParameter In e.Command.Parameters
                    result.Names.Add(parameter.ParameterName)
                    result.Values.Add(If(Convert.IsDBNull(parameter.Value),Nothing,parameter.Value))
                    result.Types.Add(parameter.DbType.ToString())
                Next
                ' Cancel before SqlDataSource can open any connection or execute SQL.
                e.Cancel=True
            End Sub
            source.Select(DataSourceSelectArguments.Empty)
        End Using
        Return result
    End Function
End Class
'@
# Auth-only I/O adapter: no MySQL factory or socket exists on this path.
$vb+="`n"+@'
Public Class MySqlConnection
    Implements IDisposable
    Public Sub New(setting As String)
    End Sub
    Public Sub Open()
    End Sub
    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub
End Class
Public Class FixtureParameters
    Inherits Dictionary(Of String,Object)
    Public Sub AddWithValue(name As String,value As Object)
        Me(name)=value
    End Sub
End Class
Public Class MySqlCommand
    Implements IDisposable
    Public Parameters As New FixtureParameters()
    Private sql As String
    Public Sub New(text As String,connection As MySqlConnection)
        sql=text
    End Sub
    Public Function ExecuteReader() As MySqlDataReader
        If Not sql.Contains("WHERE id=@loginId AND AziendeID=@companyId AND Abilitato=1 AND UtentiAbilitato=1") Then Throw New Exception("Unexpected auth lookup")
        Dim login As Integer=Convert.ToInt32(Parameters("@loginId")),company As Integer=Convert.ToInt32(Parameters("@companyId"))
        Return New MySqlDataReader(login,company)
    End Function
    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub
End Class
Public Class MySqlDataReader
    Implements IDisposable
    Private row As New Dictionary(Of String,Object)(StringComparer.OrdinalIgnoreCase)
    Private consumed As Boolean
    Public Sub New(login As Integer,company As Integer)
        If (login=1101 AndAlso company=1) OrElse (login=2202 AndAlso company=2) Then
            row("id")=login:row("AziendeID")=company:row("utentiid")=If(company=1,701,702):row("listino")=If(company=1,1,10)
            row("utentitipoid")=1:row("IvaTipo")=1:row("IdEsenzioneIva")=-1:row("ValoreEsenzioneIva")=DBNull.Value:row("DescrizioneEsenzioneIva")="":row("AbilitatoIvaReverseCharge")=0
        End If
    End Sub
    Public Function Read() As Boolean
        If consumed Then Return False
        consumed=True:Return row.Count>0
    End Function
    Default Public ReadOnly Property Item(key As String) As Object
        Get
            Return row(key)
        End Get
    End Property
    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub
End Class
Public Class LoginAccessAuditRecorder
    Public Shared Sub ClearAuthenticationMarker(context As HttpContext)
    End Sub
End Class
Public Class StorefrontPriceDisplayContextProvider
    Public Shared Sub Invalidate(context As HttpContext)
    End Sub
End Class
Public Class KeepStoreLog
    Public Shared Sub [Error](area As String,message As String,errorValue As Object,context As HttpContext)
    End Sub
End Class
Public Class AuthProbe
    Private _storefrontAuthenticationRevoked As Boolean
    Private Const AuthenticatedScopeRequestKey As String="KeepStore.Authentication.ValidatedScope"
    Private ReadOnly Property Session As HttpSessionState
        Get
            Return HttpContext.Current.Session
        End Get
    End Property
    Private Function CurrentAuthenticatedScopeKey(company As Integer) As String
        Return String.Empty
    End Function
    Private Sub RestoreAnonymousPriceDisplayState()
    End Sub
    Private Sub ApplyAuthenticatedPriceDisplayState(a As Object,b As Object,c As Object,d As Object,e As Object)
    End Sub
    Public Sub Validate(company As Integer,priceList As Integer)
        EnsureAuthenticatedStorefrontScope(company,priceList)
    End Sub
'@
$vb+="`n"+$authMethods+"`nEnd Class`nPublic Class DashboardProbe`n"+($paymentMethods -join "`n")+@'

    Public Function Label(paid As Object,state As Object) As String
        Return GetPaymentStatusLabel(paid,state)
    End Function
    Public Function Description(paid As Object,state As Object,outcome As Object,payment As Object) As String
        Return GetPaymentStatusDescription(paid,state,outcome,payment)
    End Function
End Class
'@
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'NativeHarness.vb'),$vb,$utf8)
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$dll=Join-Path $EvidenceDirectory 'NativeHarness.dll'; $mysql=Join-Path $RepositoryRoot 'Bin\MySql.Data.dll'
& $compiler /nologo /target:library "/out:$dll" /reference:System.Web.dll,System.Data.dll,System.Core.dll "/reference:$mysql" (Join-Path $RepositoryRoot 'App_Code\StorefrontCommercialIsolationPolicy.vb') (Join-Path $EvidenceDirectory 'NativeHarness.vb')
if($LASTEXITCODE){throw 'Native fixture compile failed'}
[void][Reflection.Assembly]::LoadFrom($mysql)
[void][Reflection.Assembly]::LoadFrom($dll)
function Bind($contract) { [BindingProbe]::Bind($contract.Sql,[string[]]@($contract.Parameters|ForEach-Object{$_.Name}),[string[]]@($contract.Parameters|ForEach-Object{$_.Field})) }
$queries=New-Object 'Collections.Generic.List[object]'
foreach($tenant in @(@{Name='Tech';Company=1;User=701;Login=1101;List=1},@{Name='Food';Company=2;User=702;Login=2202;List=10})) {
    $valid=@{LoginId=$tenant.Login;UtentiID=$tenant.User;AziendaID=$tenant.Company;AuthenticatedAziendaID=$tenant.Company;Listino=$tenant.List}
    [BindingProbe]::Context($valid);$b=Bind $before
    Check ($tenant.Name+' baseline native provider binding') ($b.Captured -and $b.Provider -eq 'MySql.Data.MySqlClient.MySqlCommand' -and $b.Types[0] -eq 'Int32')
    $queries.Add([pscustomobject]@{Name=$tenant.Name;Mode='baseline';Sql=$b.Sql;Owner=$tenant.User;Company=$tenant.Company;Names=$b.Names.ToArray();Values=$b.Values.ToArray()})
    if(!$BaselineOnly){
        foreach($mode in @('marked','legacy-empty','legacy-owner')) {
            $s=$valid.Clone(); if($mode -ne 'marked'){$s.Remove('AuthenticatedAziendaID');$s.Remove('Listino');if($mode -eq 'legacy-empty'){$s.Remove('UtentiID')}}
            [BindingProbe]::Context($s);$auth=New-Object AuthProbe;$auth.Validate($tenant.Company,$tenant.List)
            Check ($tenant.Name+' '+$mode+' authenticated identity') ([Web.HttpContext]::Current.Session['AuthenticatedAziendaID'] -eq $tenant.Company -and [Web.HttpContext]::Current.Session['UtentiID'] -eq $tenant.User -and [Web.HttpContext]::Current.Session['Listino'] -eq $tenant.List)
            $bound=Bind $after
            Check ($tenant.Name+' '+$mode+' real MySql Int32 parameters') ($bound.Captured -and $bound.NullCancellation -and $bound.Values.Count -eq 2 -and $bound.Values[0] -eq $tenant.User -and $bound.Values[1] -eq $tenant.Company -and @($bound.Types|Where-Object{$_ -ne 'Int32'}).Count -eq 0)
            $queries.Add([pscustomobject]@{Name=$tenant.Name;Mode=$mode;Sql=$bound.Sql;Owner=$tenant.User;Company=$tenant.Company;Names=$bound.Names.ToArray();Values=$bound.Values.ToArray()})
        }
        foreach($bad in @('other-company','missing-owner','wrong-owner','missing-list','disabled-account')) {
            $s=$valid.Clone();switch($bad){'other-company'{$s.AuthenticatedAziendaID=3-$tenant.Company};'missing-owner'{$s.Remove('UtentiID')};'wrong-owner'{$s.UtentiID=999};'missing-list'{$s.Remove('Listino')};'disabled-account'{$s.LoginId=999}}
            [BindingProbe]::Context($s);$rejected=$false;try{(New-Object AuthProbe).Validate($tenant.Company,$tenant.List)}catch{ $e=$_.Exception.GetBaseException();$rejected=$e -is [Web.HttpException] -and $e.GetHttpCode() -eq 403 }
            Check ($tenant.Name+' master rejects '+$bad) ($rejected -and $null -eq [Web.HttpContext]::Current.Session['AuthenticatedAziendaID'] -and $null -eq [Web.HttpContext]::Current.Session['UtentiID'])
        }
        Check ($tenant.Name+' host change revokes via existing policy') ([StorefrontCommercialIsolationPolicy]::ShouldClearAuthentication($tenant.Company,3-$tenant.Company,$tenant.Login,$tenant.Company))
    }
}
if(!$BaselineOnly){
    foreach($s in @($null,@{},@{UtentiID=701},@{AuthenticatedAziendaID=1})) {
        [BindingProbe]::Context($s);$b=Bind $after
        Check 'Absent/incomplete session remains null without fallback' ($b.NullCancellation -and (!$b.Captured -or @($b.Values|Where-Object{$null -eq $_}).Count -gt 0))
    }
    foreach($field in @('UtentiID','AuthenticatedAziendaID')) {foreach($bad in @('1 OR 1=1','2147483648')){$s=@{UtentiID=701;AuthenticatedAziendaID=1};$s[$field]=$bad;[BindingProbe]::Context($s);$rejected=$false;try{$null=Bind $after}catch{$rejected=$true};Check ('Typed parameter rejects '+$field+' '+$bad) $rejected}}
    $dash=New-Object DashboardProbe
    Check 'Paid status remains authoritative' ($dash.Label(1,0) -eq 'Pagato' -and $dash.Label(0,2) -eq 'Pagato')
    foreach($entry in @(@(1,'In verifica PayPal'),@(3,'Non completato'),@(4,"Annullato dall'utente"),@(5,'In verifica'),@(0,'Non avviato'))) {Check ('Payment state preserved '+$entry[0]) ($dash.Label(0,$entry[0]) -eq $entry[1])}
    Check 'Payment detail fallback preserved' ($dash.Description(0,0,'','Bonifico') -eq 'Metodo: Bonifico')
    Check 'Sensitive payment text still sanitized' ($dash.Description(0,0,'token=SYNTHETIC_TEST','') -eq 'Dettaglio pagamento disponibile nel documento.')
}
$queries|ConvertTo-Json -Depth 6|Set-Content (Join-Path $EvidenceDirectory 'bound-queries.json') -Encoding UTF8
$node=(Get-Command node.exe -ErrorAction Stop).Source
$js=@'
const fs=require('node:fs'),path=require('node:path'),{DatabaseSync}=require('node:sqlite');
const dir=process.argv[2],cases=JSON.parse(fs.readFileSync(path.join(dir,'bound-queries.json'),'utf8').replace(/^\uFEFF/,''));
const db=new DatabaseSync(':memory:'),checks=[],results=[];
function check(name,pass){checks.push({Name:name,Pass:!!pass});if(!pass)throw Error(name);}
db.exec(`CREATE TABLE documenti(Id INTEGER PRIMARY KEY,AziendeId INTEGER,UtentiId INTEGER,TipoDocumentiId INTEGER,NDocumento TEXT,DataDocumento TEXT,TotaleDocumento REAL,StatiDescrizione1 TEXT,StatiDescrizione2 TEXT,PagamentiTipoId INTEGER,Pagato INTEGER,StatoPagamentoWeb INTEGER,UltimoEsitoPagamentoWeb TEXT);
CREATE VIEW vdocumenti AS SELECT * FROM documenti; CREATE TABLE pagamentitipo(id INTEGER PRIMARY KEY,Descrizione TEXT); INSERT INTO pagamentitipo VALUES(1,'Bonifico');`);
const insert=db.prepare('INSERT INTO documenti VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)');
for(const [company,owner,start] of [[1,701,100],[2,702,200]]){
 for(let i=0;i<7;i++)insert.run(start+i,company,owner,4,`SYNTHETIC-${start+i}`,'2026-10-23',100+i,'Stato','Ordine',i%2?1:null,i===6?1:null,i%6,i===5?'SYNTHETIC_esito':null);
 insert.run(9000+company,3-company,owner,4,'FOREIGN','2026-10-23',999,'FOREIGN','',1,0,0,'');
 insert.run(9900+company,company,999,4,'OTHER-OWNER','2026-10-23',999,'','',1,0,0,'');
 insert.run(9800+company,company,owner,5,'OTHER-TYPE','2026-10-23',999,'','',1,0,0,'');
}
for(const c of cases){
 const params={};c.Names.forEach((n,i)=>params[n.replace(/^[?@]/,'')]=c.Values[i]);
 const sql=c.Sql.replace(/\?(\w+)/g,'@$1');const rows=db.prepare(sql).all(params);
 if(c.Mode==='baseline')check(c.Name+' reproduces cross-company row before limit',rows.length===5&&rows[0].NDocumento==='FOREIGN');
 else{
  const start=c.Company===1?100:200,ids=[start+6,start+5,start+4,start+3,start+2];
  check(c.Name+' '+c.Mode+' owner/company filter precedes top five',JSON.stringify(rows.map(r=>r.Id))===JSON.stringify(ids));
  const projection=c.Sql.slice(0,c.Sql.indexOf(' WHERE '));const expected=db.prepare(projection+' WHERE vdocumenti.Id BETWEEN @low AND @high ORDER BY vdocumenti.Id DESC').all({low:start+2,high:start+6});
  check(c.Name+' '+c.Mode+' full order/payment projection preserved',JSON.stringify(rows)===JSON.stringify(expected));
  check(c.Name+' '+c.Mode+' detail identities unchanged',rows.every(r=>Number.isInteger(r.Id)&&r.Id>=start&&r.Id<=start+6));
 }
 results.push({Tenant:c.Name,Mode:c.Mode,Ids:rows.map(r=>r.Id)});
}
if(cases.some(c=>c.Mode!=='baseline')){const c=cases.find(c=>c.Mode!=='baseline');for(const params of [{UtentiId:null,AziendaId:1},{UtentiId:701,AziendaId:null},{UtentiId:0,AziendaId:1},{UtentiId:701,AziendaId:0}]){const rows=db.prepare(c.Sql.replace(/\?(\w+)/g,'@$1')).all(params);check('Null or zero bound identity yields no document',rows.length===0);}}
fs.writeFileSync(path.join(dir,'sql-report.json'),JSON.stringify({Checks:checks,Results:results},null,2));db.close();
'@
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'sql-fixture.cjs'),$js,$utf8)
& $node (Join-Path $EvidenceDirectory 'sql-fixture.cjs') $EvidenceDirectory
if($LASTEXITCODE){throw 'Synthetic SQL characterization failed'}
$sqlReport=Get-Content (Join-Path $EvidenceDirectory 'sql-report.json') -Raw|ConvertFrom-Json
foreach($check in $sqlReport.Checks){Check $check.Name $check.Pass}
$report=[pscustomobject]@{Mode=$(if($BaselineOnly){'Baseline'}else{'Candidate'});Passed=$checks.Count;Failed=@($checks|Where-Object{!$_.Pass}).Count;Checks=$checks;Native='System.Web SqlDataSource/SessionParameter and MySqlCommand; Selecting cancelled before Open';Sql='SQLite synthetic in memory; named-parameter syntax adapted only';Master='Real extracted guard/session logic; database reader, price display side effects and logging replaced by local adapters';Limits='No complete master/page lifecycle, IIS, operational MySQL, login, account or production certification'}
$report|ConvertTo-Json -Depth 7|Set-Content (Join-Path $EvidenceDirectory 'test-report.json') -Encoding UTF8
Write-Output ('MYACCOUNT_RECENT_ORDERS_PASS mode='+$report.Mode+' checks='+$report.Passed)
