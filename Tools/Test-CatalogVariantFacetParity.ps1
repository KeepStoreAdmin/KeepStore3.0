[CmdletBinding()]
param([string]$RepositoryRoot,[string]$EvidenceDirectory,[string]$NodePath)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'POWERSHELL51_REQUIRED'}
if(-not $RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
if(-not $NodePath){$NodePath=@(Get-Command node.exe -CommandType Application -ErrorAction Stop)[0].Source}
if(-not $EvidenceDirectory){$EvidenceDirectory=Join-Path $env:TEMP ('ks-variant-facet-'+[guid]::NewGuid().ToString('N'))}
if(Test-Path $EvidenceDirectory){throw 'NEW_EVIDENCE_REQUIRED'}
New-Item -ItemType Directory $EvidenceDirectory|Out-Null
$utf=New-Object Text.UTF8Encoding($false)
function Save($p,$s){[IO.File]::WriteAllText((Join-Path $EvidenceDirectory $p),$s,$utf)}
function Method($text,$name,$kind='Function'){
 $m=[regex]::Matches($text,'(?ms)^    (?:Private |Protected |Public )?(?:Shared )?'+$kind+' '+[regex]::Escape($name)+'\b.*?^\s{0,4}End '+$kind+'\b')
 if(-not $m.Count){throw ('METHOD_MISSING '+$name)}
 return ($m|ForEach-Object Value) -join "`r`n"
}
$base='180d2baa7ba5a3fa0c61cd71773bdd4fcb0f6eaf'
$baseline=@(& git -C $RepositoryRoot show ($base+':articoli.aspx.vb')) -join "`r`n"
if($LASTEXITCODE){throw 'BASELINE_UNAVAILABLE'}
$candidate=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articoli.aspx.vb'))
$hostCode=@'
Imports System
Imports System.IO
Imports System.Text
Imports System.Threading
Imports System.Web
Imports System.Web.Hosting
Public Class CaptureWorker
 Inherits SimpleWorkerRequest
 Public Done As New ManualResetEvent(False)
 Public Status As Integer=200, Location As String=""
 Private Verb As String,Payload As Byte()
 Public Sub New(query As String,verb As String,body As String,output As TextWriter)
  MyBase.New("fixture.aspx",query,output):Me.Verb=verb:Payload=Encoding.UTF8.GetBytes(body)
 End Sub
 Public Overrides Function GetHttpVerbName() As String
  Return Verb
 End Function
 Public Overrides Function GetKnownRequestHeader(index As Integer) As String
  If index=HttpWorkerRequest.HeaderContentType Then Return "application/x-www-form-urlencoded"
  If index=HttpWorkerRequest.HeaderContentLength Then Return Payload.Length.ToString()
  Return MyBase.GetKnownRequestHeader(index)
 End Function
 Public Overrides Function GetPreloadedEntityBody() As Byte()
  Return Payload
 End Function
 Public Overrides Function GetTotalEntityBodyLength() As Integer
  Return Payload.Length
 End Function
 Public Overrides Function IsEntireEntityBodyIsPreloaded() As Boolean
  Return True
 End Function
 Public Overrides Sub SendStatus(code As Integer,description As String)
  Status=code:MyBase.SendStatus(code,description)
 End Sub
 Public Overrides Sub SendKnownResponseHeader(index As Integer,value As String)
  If index=HttpWorkerRequest.HeaderLocation Then Location=value
  MyBase.SendKnownResponseHeader(index,value)
 End Sub
 Public Overrides Sub EndOfRequest()
  MyBase.EndOfRequest():Done.Set()
 End Sub
End Class
Public Class FacetHost
 Inherits MarshalByRefObject
 Public Function Run(query As String,verb As String,body As String) As String()
  Dim output As New StringWriter(),worker As New CaptureWorker(query,verb,body,output)
  HttpRuntime.ProcessRequest(worker)
  If Not worker.Done.WaitOne(20000) Then Throw New Exception("PIPELINE_TIMEOUT")
  Return New String(){worker.Status.ToString(),worker.Location,output.ToString()}
 End Function
End Class
'@
Save 'Host.vb' $hostCode
$framework=Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319'
New-Item -ItemType Directory "$EvidenceDirectory\bin"|Out-Null
& "$framework\vbc.exe" /nologo /target:library ("/out:$EvidenceDirectory\bin\Host.dll") ("/reference:$framework\System.Web.dll") "$EvidenceDirectory\Host.vb"
if($LASTEXITCODE){throw 'HOST_COMPILE_FAILED'}
$io=@'
Imports System
Imports System.Data
Imports System.Web
Imports System.Collections.Generic
Public Class ProductPromotionEligibilityContext
 Public CompanyId As Integer,Listino As Integer,CampaignId As Integer,CurrentUserId As Integer
 Public EvaluationDate As Date
 Public IsAuthenticated As Boolean
End Class
Public Class CatalogTaxonomyContext
 Public IsMultiTipology As Boolean,CategoryId As Integer,SectorId As Integer
End Class
Public Class IntelligentSearch
 Public Shared Function ExpandSearchTokens(s As String,n As Integer) As List(Of String)
  Throw New InvalidOperationException("SEARCH_NOT_IN_FIXTURE")
 End Function
End Class
Public Class ThemeManager
 Public Shared Function CatalogResultsUrl(s As String) As String
  Return s
 End Function
End Class
Namespace MySql.Data.MySqlClient
 Public Class MySqlConnection
  Public ConnectionString As String
  Public Sub Open()
   If ConnectionString<>"SYNTHETIC_NO_IO" Then Throw New Exception("NO_DATABASE_ALLOWED")
  End Sub
  Public Sub Close()
  End Sub
  Public Function CreateCommand() As MySqlCommand
   Return New MySqlCommand("",Me)
  End Function
 End Class
 Public Class MySqlCommand
  Implements IDisposable
  Public CommandText As String,Connection As MySqlConnection,CommandType As CommandType
  Public Parameters As New SyntheticParameters()
  Public Sub New(sql As String,connection As MySqlConnection)
   CommandText=sql:Me.Connection=connection
  End Sub
  Public Sub Dispose() Implements IDisposable.Dispose
  End Sub
 End Class
 Public Class SyntheticParameters
  Public Sub AddWithValue(n As String,v As Object)
  End Sub
 End Class
 Public Class MySqlDataAdapter
  Implements IDisposable
  Private cmd As MySqlCommand
  Public Sub New(c As MySqlCommand)
   cmd=c
  End Sub
  Public Sub Fill(dt As DataTable)
   DirectCast(HttpContext.Current.Items("events"),List(Of String)).Add("DROPDOWN_IO_AFTER_SQL")
   dt.Columns.Add("id",GetType(Integer)):dt.Columns.Add("descrizione",GetType(String))
   dt.Rows.Add(1,"S / Rosso"):dt.Rows.Add(2,"M / Blu")
  End Sub
  Public Sub Dispose() Implements IDisposable.Dispose
  End Sub
 End Class
 Public Class MySqlHelper
  Public Shared Function EscapeString(s As String) As String
   Return s.Replace("'","''")
  End Function
 End Class
End Namespace
'@
$scaffold=@'
Private _priceDisplayContext As StorefrontPriceDisplayContext
Private catalogPromotionActive As Boolean,catalogPromotionRequestInvalid As Boolean,catalogPromotionTechnicalError As Boolean,catalogQuantityOnePriceRequired As Boolean
Private catalogPromotionCampaignId As Integer
Private catalogEligibilityContext As New ProductPromotionEligibilityContext()
Private events As New List(Of String)()
Protected Sub FixtureInit(sender As Object,e As EventArgs) Handles Me.Init
 HttpContext.Current.Items("events")=events
 events.Add("INIT")
 Session("TC")=If(Request.QueryString("tc")="0",0,1)
 _priceDisplayContext=New StorefrontPriceDisplayContext(If(Request.QueryString("tenant")="2",2,1),If(Request.QueryString("tenant")="2",10,1),False,If(Request.QueryString("net")="1",StorefrontVatDisplayMode.VatExcluded,StorefrontVatDisplayMode.VatIncluded),Nothing,-1,"",False)
 CheckBox_Disponibile.Checked=Request.QueryString("available")="1"
 Drop_Ordinamento.SelectedValue=If(Request.QueryString("sort"),"")
End Sub
Protected Sub FixtureLoad(sender As Object,e As EventArgs) Handles Me.Load
 events.Add("LOAD postback=" & IsPostBack.ToString() & " taglia=" & Drop_Filtra_Taglia.SelectedValue & " colore=" & Drop_Filtra_Colore.SelectedValue)
End Sub
Protected Sub FixtureFinish(sender As Object,e As EventArgs) Handles Me.PreRenderComplete
 events.Add("PRE_RENDER_COMPLETE")
 Dim r As New Dictionary(Of String,Object)
 r("events")=events:r("postback")=IsPostBack
 r("tagliaCount")=Drop_Filtra_Taglia.Items.Count:r("taglia")=Drop_Filtra_Taglia.SelectedValue
 r("coloreCount")=Drop_Filtra_Colore.Items.Count:r("colore")=Drop_Filtra_Colore.SelectedValue
 Dim commands As New Dictionary(Of String,String),parameters As New Dictionary(Of String,Object)
 For Each s As SqlDataSource In New SqlDataSource(){sdsArticoli,sdsMarche,sdsTipologie,sdsGruppo,sdsSottogruppo}
  commands(s.ID)=s.SelectCommand
  Dim vals As New Dictionary(Of String,Object)
  For Each p As Parameter In s.SelectParameters
   vals(p.Name)=p.DefaultValue
  Next
  parameters(s.ID)=vals
 Next
 r("commands")=commands:r("parameters")=parameters
 r("arrivalsJoin")=BuildCatalogArrivalsJoinSql()
 r("removedSize")=RemoveActiveFilterFromUrl(GetSafeReturnUrl(),"taglia=")
 r("removedColor")=RemoveActiveFilterFromUrl(GetSafeReturnUrl(),"colore=")
 output.Text="<pre id=""packet"">" & Server.HtmlEncode((New System.Web.Script.Serialization.JavaScriptSerializer()).Serialize(r)) & "</pre>"
End Sub
Private Function EnsureCatalogPriceDisplayContext() As Boolean
 events.Add("BEFORE_SQL tagliaCount=" & Drop_Filtra_Taglia.Items.Count & " coloreCount=" & Drop_Filtra_Colore.Items.Count)
 Return True
End Function
Private Sub SyncCatalogSessionFromQuery()
End Sub
Private Sub BindActiveFilters()
End Sub
Private Sub ApplyPagerSettings(b As Boolean)
End Sub
Private Function GetCatalogTaxonomyContext() As CatalogTaxonomyContext
 Return New CatalogTaxonomyContext()
End Function
Private Function ResolvePromotionCatalogActive() As Boolean
 Return False
End Function
Private Function TryReadPromotionCampaignId(ByRef n As Integer) As Boolean
 Return False
End Function
Private Function ResolveCatalogRefurbishedActive() As Boolean
 Return False
End Function
Private Sub ShowPromotionCatalogMessage(s As String)
End Sub
Private Sub TitoloCategoria()
End Sub
Private Function EnsureCatalogPromotionEligibility(n As Integer) As Boolean
 catalogEligibilityContext.CompanyId=_priceDisplayContext.CompanyId:catalogEligibilityContext.Listino=n
 catalogEligibilityContext.EvaluationDate=New Date(2026,11,10)
 Return True
End Function
Private Sub FailCatalogQuantityOnePrices()
 Throw New Exception("PRICE_READ_FAILURE")
End Sub
Private Function ShouldDeferCatalogSideFilters() As Boolean
 Return False
End Function
Private Function NormalizeQuery(s As String,n As Integer) As String
 Return s
End Function
Private Function H(s As String) As String
 Return Server.HtmlEncode(s)
End Function
Private Function IsSameRequestUrl(s As String) As Boolean
 Return s=Request.Url.AbsoluteUri
End Function
'@
$markup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articoli.aspx'))
$ddl=([regex]::Matches($markup,'<asp:DropDownList ID="Drop_Filtra_(?:Taglia|Colore)"[^>]+/>')|ForEach-Object Value) -join "`r`n"
if(([regex]::Matches($ddl,'<asp:DropDownList')).Count -ne 2){throw 'DROPDOWN_MARKUP_MISSING'}
$methods=@{Sub=@('Page_LoadComplete','CaricaArticoli','showFilters','PopulateFilterTCDropdownlist','PopulateDropdownlist','SelectDropDownValueSafe','CopyParams','Drop_Filtra_Taglia_SelectedIndexChanged','Drop_Filtra_Colore_SelectedIndexChanged','RedirectIfChanged');Function=@('IsTcEnabled','QS','IsValidIndexAndValue','SafeIdListFromQuery','BuildInParamsForSds','SqlEscapeLike','ReadCatalogPriceBound','NormalizeCatalogPriceBound','BuildCatalogRowRankSql','BuildCatalogListingSql','BuildCatalogArrivalsJoinSql','BuildCatalogQuantityOneDisplayPriceSql','GetSafeReturnUrl','changeUrlDependingFromDropDownList','changeUrlGetParam','RemoveActiveFilterFromUrl','ParseUrlQuery','BuildUrlWithQuery')}
foreach($label in @('baseline','candidate')){
 $app=Join-Path $EvidenceDirectory $label;New-Item -ItemType Directory "$app\bin","$app\App_Code" -Force|Out-Null
 Copy-Item "$EvidenceDirectory\bin\Host.dll" "$app\bin\Host.dll"
 foreach($f in @('StorefrontPromotionCatalogProvider.vb','StorefrontEffectivePriceSqlBuilder.vb','StorefrontPriceDisplayContext.vb')){Copy-Item "$RepositoryRoot\App_Code\$f" "$app\App_Code\$f"}
 [IO.File]::WriteAllText("$app\App_Code\SyntheticIO.vb",$io,$utf)
 $s=if($label -eq 'baseline'){$baseline}else{$candidate}
 $body=$scaffold+"`r`n";foreach($kind in $methods.Keys){foreach($name in $methods[$kind]){$body+=(Method $s $name $kind)+"`r`n"}}
 $imports=@('System','System.Data','System.Text','System.Text.RegularExpressions','System.Web','System.Web.UI','System.Web.UI.WebControls','System.Collections.Generic','System.Globalization','System.Configuration','MySql.Data.MySqlClient')|ForEach-Object {'<%@ Import Namespace="'+$_+'" %>'}
 $page='<%@ Page Language="VB" EnableSessionState="true" %>'+($imports -join "`r`n")+'<script runat="server">'+$body+'</script><html><head runat="server"><title>Fixture</title></head><body><form runat="server">'+$ddl+'<asp:DropDownList ID="Drop_Ordinamento" runat="server"><asp:ListItem Value=""/><asp:ListItem Value="p_basso"/><asp:ListItem Value="p_alto"/></asp:DropDownList><asp:CheckBox ID="CheckBox_Disponibile" runat="server"/><asp:Panel ID="filtritagliaecolore" runat="server"/><asp:Panel ID="tNavig" runat="server"/><asp:Label ID="lblPrezzi" runat="server"/><asp:Label ID="lblRicerca" runat="server"/><asp:Label ID="lblRisultati" runat="server"/>'
 foreach($id in @('sdsArticoli','sdsMarche','sdsTipologie','sdsGruppo','sdsSottogruppo')){$page+='<asp:SqlDataSource ID="'+$id+'" runat="server" />'}
 $page+='<asp:Button ID="hold" runat="server" Text="Synthetic unrelated postback"/><asp:Literal ID="output" runat="server"/></form></body></html>'
 [IO.File]::WriteAllText("$app\fixture.aspx",$page,$utf)
 [IO.File]::WriteAllText("$app\web.config",'<configuration><connectionStrings><clear/><add name="EntropicConnectionString" connectionString="SYNTHETIC_NO_IO"/></connectionStrings><system.web><compilation targetFramework="4.8"/><httpRuntime targetFramework="4.8"/><customErrors mode="Off"/></system.web></configuration>',$utf)
}
Add-Type -AssemblyName System.Web
Add-Type -Path "$EvidenceDirectory\bin\Host.dll"
$allResults=@{};$postbacks=@()
$queries=@('','taglia=1%7C1','colore=1%7C2','taglia=1%7C1&colore=1%7C2','taglia=0%7C1','taglia=9%7C1','taglia=1%7C999','taglia=1%7C0','taglia=1%7C-1','taglia=1%7C2147483648','taglia=1%7Cbad','taglia=1%7C1%7C2','taglia=1%7C1&taglia=2%7C2','colore=1%7C1&colore=1%7C2',('taglia='+('1'*41)+'%7C1'),'taglia=1%7C1&tc=0','taglia=1%7C1&colore=1%7C1&available=1','taglia=1%7C1&colore=1%7C2&available=1','taglia=1%7C1&pmax=11','taglia=1%7C1&pmin=9&pmax=11','taglia=1%7C1&pmax=13&tenant=2','taglia=1%7C1&pmin=10&net=1','taglia=1%7C1&pmax=11&tenant=2&net=1','taglia=1%7C1&sort=p_basso','taglia=1%7C1&sort=p_alto','mr=1%7C2&tp=1&taglia=1%7C1','colore=1%7C999','taglia=%201%7C1%20','taglia=999999999999999999%7C1')
foreach($label in @('baseline','candidate')){
 $hostObject=[System.Web.Hosting.ApplicationHost]::CreateApplicationHost([FacetHost],'/',((Join-Path $EvidenceDirectory $label)+'\'))
 $cases=@{}
 $seedHtml='';$selectedHtml=''
 foreach($q in $queries){
  $r=$hostObject.Run($q,'GET','');$name='case'+$cases.Count
  Save ($label+'-'+$name+'.html') $r[2]
  if($r[0] -ne '200'){throw ('SYSTEM_WEB_GET_FAILED '+$label+' '+$r[0])}
  $m=[regex]::Match($r[2],'<pre id="packet">(.*?)</pre>','Singleline');if(-not $m.Success){throw 'PACKET_MISSING'}
  $cases[$q]=[System.Web.HttpUtility]::HtmlDecode($m.Groups[1].Value)|ConvertFrom-Json
  if($q -eq ''){$seedHtml=$r[2]}
  if($q -eq 'taglia=1%7C1&colore=1%7C2'){$selectedHtml=$r[2]}
 }
 # Native postbacks use state and event validation from the actual rendered page.
 foreach($target in @('hold','Drop_Filtra_Taglia','Drop_Filtra_Colore')){
 $fields=[System.Web.HttpUtility]::ParseQueryString('')
 $html=if($target -eq 'hold'){$selectedHtml}else{$seedHtml}
 foreach($input in [regex]::Matches($html,'<input[^>]*type="hidden"[^>]*>')){
  $n=[regex]::Match($input.Value,'name="([^"]+)"').Groups[1].Value
  $v=[regex]::Match($input.Value,'value="([^"]*)"').Groups[1].Value
  if($n){$fields[$n]=[System.Web.HttpUtility]::HtmlDecode($v)}
 }
  $fields['__EVENTTARGET']=$target;$fields['__EVENTARGUMENT']=''
  $fields['Drop_Filtra_Taglia']=if($target -eq 'Drop_Filtra_Colore'){'0'}else{'1'}
  $fields['Drop_Filtra_Colore']=if($target -eq 'Drop_Filtra_Taglia'){'0'}else{'2'}
  $fields['CheckBox_Disponibile']='on'
  $r=$hostObject.Run('pg=3&page=2&p=9&available=1','POST',$fields.ToString())
  Save ($label+'-post-'+$target+'.html') $r[2]
  $entry=@{source=$label;target=$target;status=$r[0];location=$r[1]}
  if($target -eq 'hold'){
   if($r[0] -ne '200'){throw 'REAL_POSTBACK_STATE_FAILED'}
   $m=[regex]::Match($r[2],'<pre id="packet">(.*?)</pre>','Singleline')
   $entry.packet=[System.Web.HttpUtility]::HtmlDecode($m.Groups[1].Value)|ConvertFrom-Json
  }else{
   if($r[0] -ne '302'){throw 'MENU_REDIRECT_NOT_OBSERVED'}
   $uri=New-Object Uri($r[1]);$next=$hostObject.Run($uri.Query.TrimStart('?'),'GET','')
   if($next[0] -ne '200'){throw 'REDIRECT_GET_FAILED'}
   $m=[regex]::Match($next[2],'<pre id="packet">(.*?)</pre>','Singleline')
   $entry.next=[System.Web.HttpUtility]::HtmlDecode($m.Groups[1].Value)|ConvertFrom-Json
  }
  $postbacks+=$entry
 }
 # A forged server value must fail native EventValidation, not become authority.
 $fields['__EVENTTARGET']='hold'
 $fields['Drop_Filtra_Taglia']='999';$fields['Drop_Filtra_Colore']='0'
 $tampered=$hostObject.Run('','POST',$fields.ToString())
 Save ($label+'-invalid-post.html') $tampered[2]
 if($tampered[0] -ne '500' -or $tampered[2] -notmatch 'Invalid postback or callback argument|Argomento di postback o callback non valido'){throw 'EVENT_VALIDATION_NOT_ENFORCED'}
 $postbacks+=@{source=$label;target='forged';status=$tampered[0];eventValidationRejected=$true}
 $allResults[$label]=$cases
}
Save 'lifecycle.json' ($allResults|ConvertTo-Json -Depth 12)
Save 'postbacks.json' ($postbacks|ConvertTo-Json -Depth 12)
foreach($q in @('taglia=1%7C1','colore=1%7C2','taglia=1%7C1&colore=1%7C2')){$p=$allResults.baseline[$q];if($p.parameters.sdsArticoli.TagliaId -or $p.parameters.sdsArticoli.ColoreId){throw 'C6_BASELINE_NOT_REPRODUCED'};if($p.tagliaCount -ne 3 -or $p.coloreCount -ne 3){throw 'DROPDOWN_IO_NOT_REACHED'}}
Write-Output ('BASELINE_C6_REPRODUCED '+$EvidenceDirectory)
$checks=New-Object 'Collections.Generic.List[object]'
function Assert([bool]$ok,[string]$name){$checks.Add(@{name=$name;pass=$ok});if(-not $ok){Save 'checks.json' ($checks|ConvertTo-Json -Depth 5);throw ('VARIANT_FACET_ASSERT '+$name)}}
foreach($q in $queries){
 $p=$allResults.candidate[$q];$qs=[System.Web.HttpUtility]::ParseQueryString($q)
 foreach($key in @('taglia','colore')){
  $id=0;$values=$qs.GetValues($key)
  if($qs['tc'] -ne '0' -and $values.Count -eq 1 -and $values[0].Length -le 40){
   $raw=$values[0].Trim();$parts=$raw.Split('|')
   if($parts.Count -eq 2 -and $raw -match '^\d+\|[A-Za-z0-9\-\._% ]+$' -and $parts[1] -cmatch '^[0-9]+$'){
    $parsed=0;if([int]::TryParse($parts[1],[ref]$parsed) -and $parsed -gt 0){$id=$parsed}
   }
  }
  $name=if($key -eq 'taglia'){'TagliaId'}else{'ColoreId'}
  foreach($source in @('sdsArticoli','sdsMarche','sdsTipologie','sdsGruppo','sdsSottogruppo')){
   $actual=$p.parameters.$source.$name
   Assert (($id -eq 0 -and $null -eq $actual) -or ($id -gt 0 -and [int]$actual -eq $id)) ($q+' '+$source+' '+$name)
   Assert ($p.commands.$source.Contains('?'+$name) -eq ($id -gt 0)) ($q+' predicate '+$source+' '+$name)
  }
 }
 $hasVariant=$null -ne $p.parameters.sdsArticoli.TagliaId -or $null -ne $p.parameters.sdsArticoli.ColoreId
 foreach($facet in @('sdsMarche','sdsTipologie','sdsGruppo','sdsSottogruppo')){
  $sql=$p.commands.$facet
  Assert ([regex]::Matches($sql,'\) atc_default ON').Count -eq [int]($hasVariant -or $q.Contains('pmin=') -or $q.Contains('pmax='))) ('single default alias '+$q+'/'+$facet)
  if($hasVariant){Assert ($sql.Contains('atc.id=COALESCE(NULLIF(vsuperarticoli.TCid,0),atc_default.DefaultTCid)')) ('same row normalization '+$q+'/'+$facet)}
 }
}
foreach($q in @('','taglia=1%7C1&tc=0')){
 foreach($source in @('sdsArticoli','sdsMarche','sdsTipologie','sdsGruppo','sdsSottogruppo')){Assert ($allResults.baseline[$q].commands.$source -ceq $allResults.candidate[$q].commands.$source) ('unchanged ordinary/TC off '+$q+'/'+$source)}
}
foreach($q in @('taglia=1%7C1','colore=1%7C2','taglia=1%7C1&colore=1%7C2')){
 $events=$allResults.baseline[$q].events
 Assert ($events[1].StartsWith('LOAD postback=False')) ('real GET LOAD '+$q)
 Assert ($events[2] -eq 'BEFORE_SQL tagliaCount=0 coloreCount=0') ('unbound dropdowns before original SQL '+$q)
 Assert ($events[4] -eq 'DROPDOWN_IO_AFTER_SQL') ('binding after SQL '+$q)
}
foreach($p in $postbacks|Where-Object source -eq 'candidate'){
 if($p.target -eq 'forged'){
  Assert $p.eventValidationRejected 'forged POST rejected by real EventValidation'
 }elseif($p.target -eq 'hold'){
  Assert ($p.packet.postback -and $p.packet.parameters.sdsArticoli.TagliaId -eq '1' -and $p.packet.parameters.sdsArticoli.ColoreId -eq '2') 'actual postback values recovered through ViewState'
 }else{
  $uri=New-Object Uri($p.location);$q=[System.Web.HttpUtility]::ParseQueryString($uri.Query)
  $key=if($p.target -eq 'Drop_Filtra_Taglia'){'taglia'}else{'colore'}
  $expected=if($key -eq 'taglia'){'1|1'}else{'2|2'}
  Assert ($p.status -eq '302' -and $q[$key] -eq $expected) ('real menu event redirect '+$key)
  Assert (-not $q['pg'] -and -not $q['page'] -and -not $q['p']) ('pagination reset '+$key)
  $param=if($key -eq 'taglia'){'TagliaId'}else{'ColoreId'}
  Assert ($null -ne $p.next.parameters.sdsArticoli.$param) ('redirect subsequent GET authority '+$key)
 }
}
foreach($pair in @(@('taglia=1%7C999','removedSize','taglia'),@('colore=1%7C999','removedColor','colore'))){
 $url=$allResults.candidate[$pair[0]].($pair[1]);$uri=New-Object Uri($url)
 Assert (-not ([System.Web.HttpUtility]::ParseQueryString($uri.Query))[$pair[2]]) ('existing removal path '+$pair[2])
 $recovery=$hostObject.Run($uri.Query.TrimStart('?'),'GET','')
 Assert ($recovery[0] -eq '200') ('removed nonexistent filter subsequent GET '+$pair[2])
 $m=[regex]::Match($recovery[2],'<pre id="packet">(.*?)</pre>','Singleline')
 $packet=[System.Web.HttpUtility]::HtmlDecode($m.Groups[1].Value)|ConvertFrom-Json
 Assert ($null -eq $packet.parameters.sdsArticoli.TagliaId -and $null -eq $packet.parameters.sdsArticoli.ColoreId) ('removed nonexistent constraint not hidden '+$pair[2])
}
foreach($q in @('','taglia=1%7C1','colore=1%7C2','taglia=1%7C1&colore=1%7C2')){
 Assert (@($allResults.baseline[$q].events|Where-Object {$_ -eq 'DROPDOWN_IO_AFTER_SQL'}).Count -eq @($allResults.candidate[$q].events|Where-Object {$_ -eq 'DROPDOWN_IO_AFTER_SQL'}).Count) ('no extra dropdown roundtrip '+$q)
}
$oldPost=@($postbacks|Where-Object {$_.source -eq 'baseline' -and $_.target -eq 'hold'})[0].packet
$newPost=@($postbacks|Where-Object {$_.source -eq 'candidate' -and $_.target -eq 'hold'})[0].packet
Assert ($oldPost.commands.sdsArticoli -ceq $newPost.commands.sdsArticoli) 'listing SQL unchanged for the same restored control values'
$withoutMethod='(?ms)^    Public Sub CaricaArticoli\b.*?^    End Sub'
Assert (([regex]::Replace($baseline,$withoutMethod,'')).TrimEnd([char[]]@(13,10)) -ceq ([regex]::Replace($candidate,$withoutMethod,'')).TrimEnd([char[]]@(13,10))) 'all code outside CaricaArticoli unchanged'
Save 'checks.json' ($checks|ConvertTo-Json -Depth 5)
$sqlTest=@'
// SELECT-only in-memory dialect adapter. No MySQL, IIS, filesystem DB or DML/DDL.
const fs=require('node:fs'),path=require('node:path'),{DatabaseSync}=require('node:sqlite');
const root=process.argv[2],p=JSON.parse(fs.readFileSync(path.join(root,'lifecycle.json'))),posts=JSON.parse(fs.readFileSync(path.join(root,'postbacks.json')));
const db=new DatabaseSync(':memory:');db.function('IF',(c,a,b)=>c?a:b);db.function('CONCAT',{varargs:true},(...a)=>a.some(v=>v==null)?null:a.join(''));db.function('MOD',(a,b)=>a%b);db.function('CONVERT',(v,t)=>v);
const checks=[],results=[];
function assert(ok,name){checks.push({name,pass:!!ok});if(!ok)throw Error(name)}
const literal=v=>v==null?'NULL':typeof v==='number'?String(v):"'"+String(v).replaceAll("'","''")+"'";
function table(name,rows){const cols=Object.keys(rows[0]);return name+'('+cols.join(',')+') AS (VALUES '+rows.map(r=>'('+cols.map(c=>literal(r[c])).join(',')+')').join(',')+')'}
const variants=[{id:11,ArticoliId:101,TagliaId:1,ColoreId:1},{id:12,ArticoliId:101,TagliaId:2,ColoreId:2},{id:21,ArticoliId:102,TagliaId:1,ColoreId:1},{id:22,ArticoliId:102,TagliaId:1,ColoreId:1},{id:31,ArticoliId:103,TagliaId:1,ColoreId:2},{id:32,ArticoliId:103,TagliaId:2,ColoreId:1},{id:41,ArticoliId:104,TagliaId:1,ColoreId:1},{id:51,ArticoliId:105,TagliaId:1,ColoreId:1},{id:61,ArticoliId:106,TagliaId:1,ColoreId:1},{id:71,ArticoliId:108,TagliaId:2,ColoreId:2}];
const seed=[[101,11,0,0],[101,12,5,0],[102,21,5,0],[102,22,7,0],[103,31,5,0],[103,32,5,0],[104,0,5,0],[105,null,5,0],[106,-1,5,0],[107,-1,5,0],[108,71,5,5]],rows=[];
for(const list of [1,10])for(const [id,tc,stock,committed] of seed){
 const net=list===1?20:30;
 rows.push({id,TCid:tc,NListino:list,ArticoliListiniId:rows.length+1000,Prezzo:net,PrezzoIvato:net*1.22,Codice:'SYNTHETIC_'+id,Ean:'',Descrizione1:'Synthetic',Descrizione2:'',DescrizioneLunga:'',IdIvaRC:-1,ValoreIvaRC:0,Img1:null,Img2:null,Img3:null,Img4:null,MarcheDescrizione:'Synthetic',Disponibilita:1,Giacenza:stock,InOrdine:0,Impegnata:committed,InOfferta:0,SettoriDescrizione:'Synthetic',CategorieDescrizione:'Synthetic',TipologieDescrizione:'Synthetic',GruppiDescrizione:'Synthetic',SottogruppiDescrizione:'Synthetic',Marche_img:null,PrezzoPromo:null,PrezzoPromoIvato:null,MarcheId:id%2+1,CategorieId:1,TipologieId:1,GruppiId:1,SottoGruppiId:1,OfferteDettagliId:0,Ricondizionato:0,visite:0,Vetrina:0});
}
const ids=[...new Set(seed.map(x=>x[0]))],base=ids.map(id=>({id,MarcheId:id%2+1,TipologieId:1,GruppiId:1,SottoGruppiId:1,CategorieId:1}));
const dim=[{id:1,Descrizione:'Synthetic1',Ordinamento:1},{id:2,Descrizione:'Synthetic2',Ordinamento:2}];
const offers=[{id:201,AziendeId:1,DaListino:1,AListino:1,UtentiId:0,DataInizio:null,DataFine:null,QntMinima:1,Multipli:0,Prezzo:8,Sconto:0,Abilitato:1},{id:202,AziendeId:2,DaListino:10,AListino:10,UtentiId:0,DataInizio:null,DataFine:null,QntMinima:1,Multipli:0,Prezzo:10,Sconto:0,Abilitato:1}];
const cte='WITH '+[
table('vsuperarticoli',rows),table('varticolilistini',rows),table('varticolibase',base),
table('articoli',ids.map(id=>({id,Abilitato:1,NoPromo:0,Img5:null,Img6:null}))),
table('articoli_tagliecolori',variants),table('articoli_listini',rows.map(r=>({ArticoliId:r.id,TCid:r.TCid,NListino:r.NListino}))),
table('offerte',offers),table('offertedettaglio',[{id:301,OfferteId:201,TCId:21},{id:302,OfferteId:202,TCId:21}]),
table('voffertearticoli',[{id:102,OfferteID:201,OfferteDettagliId:301},{id:102,OfferteID:202,OfferteDettagliId:302}]),
...['Marche','tipologie','Gruppi','SottoGruppi'].map(n=>table(n,dim)),
table('taglie',dim.map(d=>({id:d.id,descrizione:d.Descrizione}))),table('colori',dim.map(d=>({id:d.id,descrizione:d.Descrizione})))
].join(',')+' ';
function query(packet,key){
 let sql=packet.commands[key];
 // Arrivals fixture is empty: replace only that exact legacy MySQL aggregation join.
 sql=sql.replace(packet.arrivalsJoin,' LEFT JOIN (SELECT NULL AS articoliid,NULL AS arrivi WHERE 0) arrivi ON arrivi.articoliid=vsuperarticoli.id');
 sql=sql.replace(/GROUP_CONCAT\(DISTINCT ([^()]+?) SEPARATOR '\|'\)/g,"REPLACE(GROUP_CONCAT(DISTINCT $1),',','|')").replace(/,CHAR\)/g,", 'CHAR')").replace(/\?([A-Za-z][A-Za-z0-9_]*)/g,':$1');
 const bindings={};for(const [k,v] of Object.entries(packet.parameters[key]))bindings[k]=v!=null&&/^-?\d+(?:[.,]\d+)?$/.test(v)?Number(v.replace(',','.')):v;
 const statement=db.prepare(cte+sql);statement.setAllowUnknownNamedParameters(true);
 try{return statement.all(bindings)}catch(e){fs.writeFileSync(path.join(root,'sql-failure.txt'),cte+sql+'\n'+e.message);throw e}
}
function execute(packet,name,expected){
 const main=query(packet,'sdsArticoli'),actual=main.map(r=>r.id).sort((a,b)=>a-b);
 assert(new Set(actual).size===actual.length,name+' listing one row per article');
 if(expected)assert(JSON.stringify(actual)===JSON.stringify(expected),name+' exact article set '+JSON.stringify(actual));
 for(const f of ['sdsMarche','sdsTipologie','sdsGruppo','sdsSottogruppo']){
  const facet=query(packet,f);let count=facet.reduce((s,r)=>s+r.Numero,0);
  assert(count===actual.length,name+' DISTINCT facet parity '+f+' '+count+'/'+actual.length);
 }
 results.push({name,ids:actual,main:main.map(r=>({id:r.id,tc:r.TCid,price:r.CatalogDisplayPrice}))});
 return main;
}
execute(p.candidate['taglia=1%7C1&colore=1%7C1&available=1'],'same variant stock',[102,104,105]);
execute(p.candidate['taglia=1%7C1&colore=1%7C2&available=1'],'split variants cannot combine',[103]);
execute(p.candidate['taglia=1%7C1&tc=0'],'TC disabled standard unchanged',[101,102,103,104,105,106,107,108]);
execute(p.candidate['taglia=1%7C999'],'nonexistent size',[]);
execute(p.candidate['colore=1%7C999'],'nonexistent color',[]);
const netBound=query(p.candidate['taglia=1%7C1&pmin=10&net=1'],'sdsArticoli');
assert(netBound.find(r=>r.id===102).TCid===22,'range cannot reuse promotion21 price for variant22 or vice versa');
for(const q of ['taglia=1%7C1&pmax=11','taglia=1%7C1&pmin=9&pmax=11','taglia=1%7C1&pmax=13&tenant=2','taglia=1%7C1&pmax=11&tenant=2&net=1','taglia=1%7C1&pmin=10&net=1']){
 const expected=q.includes('pmin=10')?[101,102,103,104,105]:[102];
 const main=execute(p.candidate[q],q,expected);
 if(expected.length===1)assert(Math.abs(main[0].CatalogDisplayPrice-(q.includes('net=1')?10:q.includes('tenant=2')?12.2:9.76))<0.001,q+' tenant qty1 promo effective price');
}
for(const q of ['taglia=1%7C1&sort=p_basso','taglia=1%7C1&sort=p_alto']){const r=execute(p.candidate[q],q);assert(r.every((v,i)=>i===0||(q.includes('p_basso')?r[i-1].CatalogDisplayPrice<=v.CatalogDisplayPrice:r[i-1].CatalogDisplayPrice>=v.CatalogDisplayPrice)),q+' price ordering unchanged');}
// Explicitly reproduce baseline R2 using a real POST, not manually invoked handlers.
const old=posts.find(r=>r.source==='baseline'&&r.target==='hold').packet;
const oldMain=query(old,'sdsArticoli'),oldFacet=query(old,'sdsMarche');
assert(oldMain.length===1&&oldMain[0].id===103,'baseline POST listing uses exact variant');
assert(oldFacet.reduce((s,r)=>s+r.Numero,0)>oldMain.length,'baseline R2 wrong-variant facet stock counterexample');
execute(posts.find(r=>r.source==='candidate'&&r.target==='hold').packet,'candidate actual POST parity',[103]);
// All invalid and valid GETs execute their actual generated SQL.
for(const [q,packet] of Object.entries(p.candidate)){
 if(q.includes('mr=')){
  const main=query(packet,'sdsArticoli'),facet=query(packet,'sdsMarche');
  assert(main.every(r=>[1,2].includes(r.MarcheId)&&r.TipologieId===1),'OR facet values AND another facet');
  assert(facet.reduce((s,r)=>s+r.Numero,0)===main.length,'multiselect #426 alternatives preserved');
 }else execute(packet,'GET '+q);
}
fs.writeFileSync(path.join(root,'sql-checks.json'),JSON.stringify({dialect:'SQLite SELECT-only in-memory adapter; not MySQL/IIS proof',adaptations:['named parameters','IF/CONCAT/MOD/CONVERT functions','GROUP_CONCAT separator','exact empty-arrivals join'],checks,results},null,2));
console.log('SQL_SYNTHETIC_PASS '+checks.length);
'@
Save 'sql-check.cjs' $sqlTest
& $NodePath (Join-Path $EvidenceDirectory 'sql-check.cjs') $EvidenceDirectory
if($LASTEXITCODE){throw 'SYNTHETIC_SQL_TEST_FAILED'}
$sqlChecks=Get-Content (Join-Path $EvidenceDirectory 'sql-checks.json') -Raw|ConvertFrom-Json
Save 'report.json' (@{result='PASS SOURCE / isolated System.Web / synthetic SQL';baseline=$base;checks=$checks.Count;sqlChecks=$sqlChecks.checks.Count;getRequests=2*$queries.Count;postRequests=$postbacks.Count;redirectGetRequests=4;recoveryGetRequests=2;limits=@('No IIS/MySQL or operational data','SQLite adapter does not certify MySQL dialect/performance/decimal semantics','Synthetic dropdown I/O enumerates declared fixture values, not live option cardinality','C5 incompatible combinations remain removable zero-results','No full storefront lifecycle or production certification')}|ConvertTo-Json -Depth 6)
Write-Output ('VARIANT_FACET_PASS '+$checks.Count+' SOURCE/WEBFORMS '+$sqlChecks.checks.Count+' SQL')
