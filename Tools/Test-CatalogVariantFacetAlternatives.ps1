[CmdletBinding()]
param([string]$RepositoryRoot,[string]$EvidenceDirectory,[string]$NodePath,[switch]$GateOnly)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'FRAMEWORK48_POWERSHELL51_REQUIRED'}
if(-not $RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
if(-not $NodePath){$NodePath=@(Get-Command node.exe -CommandType Application -ErrorAction Stop)[0].Source}
if(-not $EvidenceDirectory){$EvidenceDirectory=Join-Path $env:TEMP ('ks-variant-alternatives-'+[guid]::NewGuid().ToString('N'))}
if(Test-Path -LiteralPath $EvidenceDirectory){throw 'NEW_TEMP_EVIDENCE_REQUIRED'}
if(-not [IO.Path]::GetFullPath($EvidenceDirectory).StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase)){throw 'TEMP_ONLY'}
New-Item -ItemType Directory -Path $EvidenceDirectory|Out-Null
$utf=New-Object Text.UTF8Encoding($false)
function Save($p,$s){[IO.File]::WriteAllText((Join-Path $EvidenceDirectory $p),$s,$utf)}
$base='103c4840bae2964fc1d0c0d1c1dad0089da9c407'
$baseline=@(& git -C $RepositoryRoot show ($base+':articoli.aspx.vb')) -join [Environment]::NewLine
if($LASTEXITCODE){throw 'BASELINE_MISSING'}
$candidate=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articoli.aspx.vb'))
# Reuse #432's compiled Framework host/scaffold only, never execute its old matrix.
$prior=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Tools\Test-CatalogVariantFacetParity.ps1'))
$method=[regex]::Match($prior,'(?ms)^function Method\(.*?^\}').Value
if(-not $method){throw 'FRAMEWORK_METHOD_EXTRACTOR_MISSING'}
Invoke-Expression $method
$start=$prior.IndexOf('$hostCode=@''');$end=$prior.IndexOf('$allResults=@{}')
if($start -lt 0 -or $end -le $start){throw 'FRAMEWORK_SCAFFOLD_BOUNDARY_CHANGED'}
$prefix=$prior.Substring($start,$end-$start)
$io=[regex]::Match($prior,"(?ms)^\x24io=@'\r?\n(.*?)^'@").Groups[1].Value
$io=$io.Replace('Public ConnectionString As String','Public ConnectionString As String'+[Environment]::NewLine+'  Public State As ConnectionState=ConnectionState.Closed')
$io=$io.Replace('  Public Sub Close()','  Public Sub Dispose()'+[Environment]::NewLine+'  End Sub'+[Environment]::NewLine+'  Public Sub Close()')
$io=$io.Replace('If ConnectionString<>"SYNTHETIC_NO_IO" Then Throw New Exception("NO_DATABASE_ALLOWED")','If ConnectionString<>"SYNTHETIC_NO_IO" Then Throw New Exception("NO_DATABASE_ALLOWED")'+[Environment]::NewLine+'   State=ConnectionState.Open')
$io=$io.Replace('Public Class SyntheticParameters','Public Class SyntheticParameters'+[Environment]::NewLine+'  Public Values As New Dictionary(Of String,Object)')
$io=$io.Replace('Public Sub AddWithValue(n As String,v As Object)','Public Sub AddWithValue(n As String,v As Object)'+[Environment]::NewLine+'   Values(n.TrimStart("?"c))=If(v Is DBNull.Value,Nothing,v)')
$fill=@'
  Public Sub Fill(dt As DataTable)
   Dim context=HttpContext.Current,items=DirectCast(context.Items("menuSql"),List(Of Object))
   Dim serializer As New System.Web.Script.Serialization.JavaScriptSerializer()
   Dim request As New Dictionary(Of String,Object)
   request("sql")=cmd.CommandText:request("parameters")=cmd.Parameters.Values
   request("arrivalsJoin")=context.Items("arrivalsJoin")
   Dim name=Guid.NewGuid().ToString("N"),root=System.Web.HttpRuntime.AppDomainAppPath
   Dim input=System.IO.Path.Combine(root,"io-"+name+".json"),output=System.IO.Path.Combine(root,"rows-"+name+".json")
   System.IO.File.WriteAllText(input,serializer.Serialize(request))
   Dim info As New System.Diagnostics.ProcessStartInfo()
   info.FileName=System.Configuration.ConfigurationManager.AppSettings("NodePath")
   info.Arguments="""" & System.Configuration.ConfigurationManager.AppSettings("SqlScript") & """ """ & input & """ """ & output & """"
   info.UseShellExecute=False:info.CreateNoWindow=True:info.RedirectStandardError=True
   Using child=System.Diagnostics.Process.Start(info)
    Dim errorText=child.StandardError.ReadToEnd()
    If Not child.WaitForExit(15000) OrElse child.ExitCode<>0 Then
     request("error")=errorText:items.Add(request)
     Throw New Exception("SYNTHETIC_SQL_FAILED")
    End If
   End Using
   Dim rows=DirectCast(serializer.DeserializeObject(System.IO.File.ReadAllText(output)),Object())
   dt.Columns.Add("id",GetType(Integer)):dt.Columns.Add("descrizione",GetType(String))
   For Each raw As Object In rows
    Dim row=DirectCast(raw,Dictionary(Of String,Object))
    dt.Rows.Add(Convert.ToInt32(row("id")),Convert.ToString(row("descrizione")))
   Next
   request("rows")=rows:items.Add(request)
   DirectCast(context.Items("events"),List(Of String)).Add("DROPDOWN_REAL_SQL_AFTER_CANDIDATES")
  End Sub
'@
$io=[regex]::Replace($io,'(?ms)  Public Sub Fill\(dt As DataTable\).*?^  End Sub',$fill.TrimEnd())
$io=$io.Replace('Throw New InvalidOperationException("SEARCH_NOT_IN_FIXTURE")','Return New List(Of String) From {s}')
$prefix=[regex]::Replace($prefix,"(?ms)^\x24io=@'\r?\n.*?^'@",('$io=@'''+[Environment]::NewLine+$io+"'@"))
$scaffold=[regex]::Match($prior,"(?ms)^\x24scaffold=@'\r?\n(.*?)^'@").Groups[1].Value
$scaffold=$scaffold.Replace('Private events As New List(Of String)()','Private events As New List(Of String)()'+[Environment]::NewLine+'Private catalogSideFiltersBound As Boolean')
$scaffold=$scaffold.Replace(' events.Add("INIT")',' events.Add("INIT")'+[Environment]::NewLine+' HttpContext.Current.Items("menuSql")=New List(Of Object)()'+[Environment]::NewLine+' HttpContext.Current.Items("arrivalsJoin")=BuildCatalogArrivalsJoinSql()')
$scaffold=$scaffold.Replace(' r("commands")=commands:r("parameters")=parameters',' r("commands")=commands:r("parameters")=parameters'+[Environment]::NewLine+' r("menuSql")=HttpContext.Current.Items("menuSql")'+[Environment]::NewLine+' r("tagliaOptions")=OptionsOf(Drop_Filtra_Taglia):r("coloreOptions")=OptionsOf(Drop_Filtra_Colore)')
$scaffold=[regex]::Replace($scaffold,'(?ms)Private Function ShouldDeferCatalogSideFilters\(\) As Boolean.*?End Function',(Method $baseline 'ShouldDeferCatalogSideFilters'))
$scaffold+=@'

Private Function OptionsOf(list As DropDownList) As Object
 Dim values As New List(Of String)
 For Each item As ListItem In list.Items
  values.Add(item.Value)
 Next
 Return values
End Function
Protected Sub FixtureDeferred(sender As Object,e As EventArgs) Handles Me.PreRender
 If ShouldDeferCatalogSideFilters() Then
  BindDeferredCatalogSideFilters()
  BindDeferredCatalogSideFilters()
 End If
End Sub
'@
$prefix=[regex]::Replace($prefix,"(?ms)^\x24scaffold=@'\r?\n.*?^'@",('$scaffold=@'''+[Environment]::NewLine+$scaffold+[Environment]::NewLine+"'@"))
$prefix=$prefix.Replace("'RedirectIfChanged');Function=","'RedirectIfChanged','BindDeferredCatalogSideFilters');Function=")
$prefix=$prefix.Replace('$body=$scaffold+', '$body=(([regex]::Matches($s,''(?m)^    Private catalog(?:Taglia|Colore)CandidateSql As String.*$'')|ForEach-Object Value) -join [Environment]::NewLine)+[Environment]::NewLine+$scaffold+')
$prefix=$prefix.Replace('<asp:Literal ID="output" runat="server"/>','<asp:Panel ID="ksFilters" runat="server"/><asp:FormView ID="FormView1" runat="server"/><asp:DataList ID="DataList1" runat="server"/><asp:DataList ID="DataList2" runat="server"/><asp:DataList ID="DataList3" runat="server"/><asp:DataList ID="DataList4" runat="server"/><asp:Literal ID="output" runat="server"/>')
# Add only non-secret test process paths; no config is copied from the application.
$prefix=$prefix.Replace('<configuration><connectionStrings>',('<configuration><appSettings><add key="NodePath" value="'+[Security.SecurityElement]::Escape($NodePath)+'"/><add key="SqlScript" value="'+[Security.SecurityElement]::Escape((Join-Path $EvidenceDirectory 'fixture-sql.cjs'))+'"/></appSettings><connectionStrings>'))
# Reuse the prior SELECT dialect adapter, replace its nonunique rows completely.
$js=[regex]::Match($prior,"(?ms)^\x24sqlTest=@'\r?\n(.*?)^'@").Groups[1].Value
$js=$js.Substring(0,$js.IndexOf('function execute('))
$js=[regex]::Replace($js,'(?m)^const root=.*$',"const request=JSON.parse(fs.readFileSync(process.argv[2])),root=path.dirname(process.argv[2]);")
$seeds=@'
const variants=[
 {id:11,ArticoliId:101,TagliaId:1,ColoreId:1},{id:21,ArticoliId:102,TagliaId:2,ColoreId:1},
 {id:31,ArticoliId:103,TagliaId:1,ColoreId:1},{id:32,ArticoliId:103,TagliaId:2,ColoreId:2},
 {id:41,ArticoliId:104,TagliaId:1,ColoreId:2},{id:51,ArticoliId:105,TagliaId:1,ColoreId:1},
 {id:61,ArticoliId:106,TagliaId:1,ColoreId:1},{id:71,ArticoliId:107,TagliaId:1,ColoreId:1},
 {id:81,ArticoliId:109,TagliaId:1,ColoreId:1},{id:82,ArticoliId:109,TagliaId:2,ColoreId:1},
 {id:91,ArticoliId:110,TagliaId:1,ColoreId:1},{id:92,ArticoliId:110,TagliaId:2,ColoreId:2},
 {id:101,ArticoliId:111,TagliaId:3,ColoreId:1}];
const pairs=variants.map(v=>[v.ArticoliId,v.TagliaId,v.ColoreId].join(':'));
assert(new Set(pairs).size===pairs.length,'unique size/color per article');
const seed=[[101,11,5,0],[102,21,5,0],[103,31,5,0],[103,32,5,0],[104,41,5,0],[105,0,5,0],[106,null,5,0],[107,-1,5,0],[108,-1,5,0],[109,81,5,5],[109,82,5,0],[110,91,5,0],[110,92,5,0],[111,101,5,0]],rows=[];
const brand=id=>[101,102,104].includes(id)?1:id===103?3:2;
const category=id=>({105:3,106:4,107:5,108:6,109:2}[id]||1);
'@
$js=[regex]::Replace($js,'(?ms)^const variants=.*?(?=^for\(const list)',$seeds+[Environment]::NewLine)
$js=$js.Replace('MarcheId:id%2+1','MarcheId:brand(id)').Replace('CategorieId:1','CategorieId:1,SettoriId:1')
$js=$js.Replace('CategorieId:1,SettoriId:1','CategorieId:category(id),SettoriId:1').Replace(' const net=list===1?20:30;',' if(id===103 && tc===32 && list===1)continue; const net=list===1?20:30;')
$js=$js.Replace("const dim=[{id:1,Descrizione:'Synthetic1',Ordinamento:1},{id:2,Descrizione:'Synthetic2',Ordinamento:2}];","const dim=[{id:1,Descrizione:'S / Rosso',Ordinamento:1},{id:2,Descrizione:'M / Blu',Ordinamento:2},{id:3,Descrizione:'Disabled',Ordinamento:3}];")
$js=$js.Replace('TCId:21','TCId:91').Replace('id:102,OfferteID:','id:110,OfferteID:')
$js=$js.Replace('descrizione:d.Descrizione','descrizione:d.Descrizione,abilitato:d.id===3?0:1')
$js=$js.Replace('function query(packet,key)','function query(packet)').Replace('packet.commands[key]','packet.sql').Replace('packet.parameters[key]','packet.parameters')
$js=$js.Replace("v.replace(',','.')","String(v).replace(',','.')")
$js=$js.Replace("db.function('CONVERT',(v,t)=>v);","db.function('CONVERT',(v,t)=>v);db.function('LEAST',{varargs:true},(...v)=>Math.min(...v));")
$js=$js.Replace("DescrizioneLunga:'',","DescrizioneLunga:'',DescrizioneHTML:'',Export:1,").Replace('id,MarcheId:brand(id)','id,Codice:"SYNTHETIC_"+id,Ean:"",Descrizione1:"Synthetic",MarcheId:brand(id)')
$js+='fs.writeFileSync(process.argv[3],JSON.stringify(query(request)));'
Save 'fixture-sql.cjs' $js
Invoke-Expression $prefix
$queries=@('mr=1&taglia=1%7C1','mr=1&colore=1%7C1','mr=3','mr=1&taglia=1%7C1&colore=1%7C1')
if(-not $GateOnly){$queries+=@('','mr=1','mr=1&taglia=2%7C2','mr=1&colore=2%7C2','mr=3&taglia=1%7C1&colore=2%7C2','mr=2&available=1&taglia=1%7C1','mr=2&taglia=1%7C1&pmax=11','mr=2&taglia=1%7C1&pmax=13&tenant=2','mr=2&taglia=1%7C1&pmax=9&net=1','mr=2&taglia=1%7C1&pmax=11&net=1&tenant=2','taglia=1%7C999','taglia=1%7C0','taglia=1%7C-1','taglia=1%7C2147483648','taglia=1%7C1&taglia=2%7C2',('taglia='+('1'*41)+'%7C1'),'tc=0&taglia=1%7C1','q=SYNTHETIC&mr=1&taglia=1%7C1','q=SYNTHETIC&mr=3','mr=1%7C3&tp=1&taglia=1%7C1','mr=2&sort=p_basso','mr=2&sort=p_alto')}
if(-not $GateOnly){$queries+=@('mr=3&tenant=2','mr=1&taglia=1%7C1&colore=2%7C2','st=1&ct=2&available=1&taglia=1%7C1','st=1&ct=2&taglia=1%7C1','st=1&ct=3','st=1&ct=4','st=1&ct=5','st=1&ct=6')}
$results=@{};$hosts=@{};$htmls=@{}
function Packet($result,$name){
 Save ($name+'.html') $result[2]
 if($result[0] -ne '200'){throw ('REAL_WEBFORMS_FAILED '+$name)}
 $m=[regex]::Match($result[2],'<pre id="packet">(.*?)</pre>','Singleline')
 if(-not $m.Success){throw 'RENDER_PACKET_MISSING'}
 return [System.Web.HttpUtility]::HtmlDecode($m.Groups[1].Value)|ConvertFrom-Json
}
foreach($label in @('baseline','candidate')){
 $hostObject=[System.Web.Hosting.ApplicationHost]::CreateApplicationHost([FacetHost],'/',((Join-Path $EvidenceDirectory $label)+'\'))
 $hosts[$label]=$hostObject;$cases=@{};$htmls[$label]=@{}
 foreach($q in $queries){$r=$hostObject.Run($q,'GET','');$htmls[$label][$q]=$r[2];$cases[$q]=Packet $r ($label+'-'+$cases.Count)}
 $results[$label]=$cases
}
$checks=New-Object 'Collections.Generic.List[object]'
function Assert([bool]$ok,[string]$name){$checks.Add(@{name=$name;pass=$ok});if(-not $ok){Save 'checks.json' ($checks|ConvertTo-Json -Depth 5);throw ('ALTERNATIVES_ASSERT '+$name)}}
Save 'lifecycle.json' ($results|ConvertTo-Json -Depth 15)
Assert (($results.baseline['mr=1&taglia=1%7C1'].tagliaOptions -join ',') -eq '0,1') 'BASELINE_A_SIZE_SELF_LIMITED'
Assert (($results.baseline['mr=1&colore=1%7C1'].coloreOptions -join ',') -eq '0,1') 'BASELINE_A_COLOR_SELF_LIMITED'
Assert (($results.baseline['mr=3'].tagliaOptions -join ',') -eq '0,1,2') 'BASELINE_B_UNLISTED_VARIANT_OFFERED'
Assert (@($results.baseline['mr=3'].menuSql[0].rows).Count -eq 2) 'baseline menu values actually evaluated SQL'
if($GateOnly){Save 'gate.json' ($checks|ConvertTo-Json -Depth 5);Write-Output ('GATE_A_B_REPRODUCED '+$EvidenceDirectory);return}

foreach($q in $queries){
 $a=$results.baseline[$q];$b=$results.candidate[$q]
 foreach($source in @('sdsArticoli','sdsMarche','sdsTipologie','sdsGruppo','sdsSottogruppo')){
  Assert ($a.commands.$source -ceq $b.commands.$source) ('identical listing/lateral SQL '+$q+'/'+$source)
  Assert (($a.parameters.$source|ConvertTo-Json -Compress) -ceq ($b.parameters.$source|ConvertTo-Json -Compress)) ('identical commercial parameters '+$q+'/'+$source)
 }
 $off=$q.Contains('tc=0')
 Assert (@($b.menuSql).Count -eq $(if($off){0}else{2})) ('two menu reads only, including deferred guard '+$q)
 if(-not $off){
  Assert ($b.tagliaOptions[0] -eq '0' -and $b.coloreOptions[0] -eq '0') ('all option first '+$q)
  foreach($menu in $b.menuSql){
   Assert (-not $menu.sql.Contains('OtherId') -and -not $menu.sql.Contains('tc_candidates.CatalogRowRank=1') -and -not $menu.sql.Contains(') catalog WHERE catalog.CatalogRowRank=1')) ('row candidates no art-only authority or rank truncation '+$q)
   Assert ($menu.sql.Contains('tc_candidates.CatalogTagliaId=tc_ref.id') -or $menu.sql.Contains('tc_candidates.CatalogColoreId=tc_ref.id')) ('actual commercial row option '+$q)
   Assert (-not $menu.parameters.OtherId) ('no OtherId parameter '+$q)
  }
 }
}
function OptionsEqual($q,$size,$color){
 Assert (($results.candidate[$q].tagliaOptions -join ',') -eq $size) ('size alternatives '+$q)
 Assert (($results.candidate[$q].coloreOptions -join ',') -eq $color) ('color alternatives '+$q)
}
OptionsEqual 'mr=1&taglia=1%7C1' '0,1,2' '0,1,2'
OptionsEqual 'mr=1&colore=1%7C1' '0,1,2' '0,1,2'
OptionsEqual 'mr=1&taglia=1%7C1&colore=1%7C1' '0,1,2' '0,1,2'
OptionsEqual 'mr=1&taglia=2%7C2' '0,1,2' '0,1'
OptionsEqual 'mr=1&colore=2%7C2' '0,1' '0,1,2'
OptionsEqual 'mr=3' '0,1' '0,1'
OptionsEqual 'mr=3&tenant=2' '0,1,2' '0,1,2'
OptionsEqual 'mr=1&taglia=1%7C1&colore=2%7C2' '0,1' '0,1,2'
OptionsEqual 'st=1&ct=2&available=1&taglia=1%7C1' '0,2' '0'
OptionsEqual 'st=1&ct=2&taglia=1%7C1' '0,1,2' '0,1'
OptionsEqual 'st=1&ct=3' '0,1' '0,1'
OptionsEqual 'st=1&ct=4' '0,1' '0,1'
OptionsEqual 'st=1&ct=5' '0' '0'
OptionsEqual 'st=1&ct=6' '0' '0'
OptionsEqual 'mr=3&taglia=1%7C1&colore=2%7C2' '0' '0,1'
OptionsEqual 'mr=2&available=1&taglia=1%7C1' '0,1,2' '0,1'
foreach($q in @('mr=2&taglia=1%7C1&pmax=11','mr=2&taglia=1%7C1&pmax=13&tenant=2','mr=2&taglia=1%7C1&pmax=9&net=1','mr=2&taglia=1%7C1&pmax=11&net=1&tenant=2')){OptionsEqual $q '0,1' '0,1'}
OptionsEqual 'q=SYNTHETIC&mr=1&taglia=1%7C1' '0,1,2' '0,1,2'
OptionsEqual 'q=SYNTHETIC&mr=3' '0,1' '0,1'
# The candidate allows valid non-default row92 while never proposing absent row32.
Assert ($results.candidate['mr=2&sort=p_basso'].tagliaOptions -contains '2') 'non-default commercial row selectable'
Assert (-not ($results.candidate[''].tagliaOptions -contains '3')) 'disabled size excluded'
Assert (($results.candidate['tc=0&taglia=1%7C1'].tagliaOptions -join ',') -eq ($results.baseline['tc=0&taglia=1%7C1'].tagliaOptions -join ',')) 'TC disabled unchanged'
function EvaluateMain($packet,$name){
 $request=@{sql=$packet.commands.sdsArticoli;parameters=$packet.parameters.sdsArticoli;arrivalsJoin=$packet.arrivalsJoin}
 Save ($name+'-main.json') ($request|ConvertTo-Json -Depth 8)
 & $NodePath (Join-Path $EvidenceDirectory 'fixture-sql.cjs') (Join-Path $EvidenceDirectory ($name+'-main.json')) (Join-Path $EvidenceDirectory ($name+'-rows.json'))
 if($LASTEXITCODE){throw 'MAIN_SYNTHETIC_SQL_FAILED'}
 $rows=Get-Content (Join-Path $EvidenceDirectory ($name+'-rows.json')) -Raw|ConvertFrom-Json
 foreach($row in $rows){Write-Output $row}
}
foreach($pair in @(@('mr=3&taglia=1%7C1&colore=2%7C2','removedColor'),@('taglia=1%7C999','removedSize'))){
 $packet=$results.candidate[$pair[0]]
 $name='empty'+$checks.Count
 Assert (@(EvaluateMain $packet $name).Count -eq 0) ('actual zero results '+$pair[0])
 $uri=New-Object Uri($packet.($pair[1]))
 $recovery=Packet ($hosts.candidate.Run($uri.Query.TrimStart('?'),'GET','')) ($name+'-recovery')
 Assert (@(EvaluateMain $recovery ($name+'-recovered')).Count -gt 0) ('existing explicit removal recovers results '+$pair[0])
}
# GET/POST use the actual rendered menu values and native ViewState/EventValidation.
$postbacks=@()
foreach($scenario in @(@('mr=1&taglia=1%7C1','Drop_Filtra_Taglia','2','0','taglia','2|2'),@('mr=1&colore=1%7C1','Drop_Filtra_Colore','0','2','colore','2|2'))){
 $fields=[System.Web.HttpUtility]::ParseQueryString('')
 foreach($input in [regex]::Matches($htmls.candidate[$scenario[0]],'<input[^>]*type="hidden"[^>]*>')){
  $n=[regex]::Match($input.Value,'name="([^"]+)"').Groups[1].Value;$v=[regex]::Match($input.Value,'value="([^"]*)"').Groups[1].Value
  if($n){$fields[$n]=[System.Web.HttpUtility]::HtmlDecode($v)}
 }
 $fields['__EVENTTARGET']=$scenario[1];$fields['__EVENTARGUMENT']=''
 $fields['Drop_Filtra_Taglia']=$scenario[2];$fields['Drop_Filtra_Colore']=$scenario[3]
 $r=$hosts.candidate.Run(($scenario[0]+'&pg=3&page=2&p=4'),'POST',$fields.ToString())
 Save ('post-'+$scenario[4]+'.html') $r[2]
 Assert ($r[0] -eq '302') ('direct menu change native POST '+$scenario[4])
 $uri=New-Object Uri($r[1]);$q=[System.Web.HttpUtility]::ParseQueryString($uri.Query)
 Assert ($q[$scenario[4]] -eq $scenario[5]) ('canonical menu URL index/value '+$scenario[4])
 Assert (-not $q['page'] -and -not $q['pg'] -and -not $q['p']) ('menu redirect resets pagination '+$scenario[4])
 $next=Packet ($hosts.candidate.Run($uri.Query.TrimStart('?'),'GET','')) ('redirect-'+$scenario[4])
 Assert (($next.($scenario[4]+'Options')) -contains $scenario[2+$(if($scenario[4] -eq 'colore'){1}else{0})]) ('new value retained after redirect '+$scenario[4])
 $postbacks+=@{target=$scenario[1];status=$r[0];location=$r[1];next=$next}
 $fields['Drop_Filtra_Taglia']='999'
 $bad=$hosts.candidate.Run($scenario[0],'POST',$fields.ToString())
 Assert ($bad[0] -eq '500' -and $bad[2] -match 'Invalid postback or callback argument|Argomento di postback o callback non valido') ('forged value EventValidation '+$scenario[4])
}
Save 'postbacks.json' ($postbacks|ConvertTo-Json -Depth 15)
# The new literal-removal guard must fail closed on absent/duplicate predicates.
foreach($mode in @('missing','duplicate')){
 $app=Join-Path $EvidenceDirectory ('guard-'+$mode);New-Item -ItemType Directory -Path $app|Out-Null
 Copy-Item (Join-Path $EvidenceDirectory 'candidate\*') $app -Recurse
 $page=[IO.File]::ReadAllText((Join-Path $app 'fixture.aspx'))
 $probe=if($mode -eq 'missing'){'strWhere=strWhere.Replace(" AND tc_lookup.TagliaId=?TagliaId","")'}else{'strWhere &= " AND tc_lookup.TagliaId=?TagliaId"'}
 $page=$page.Replace('            Dim tagliaWhere As String =',$probe+[Environment]::NewLine+'            Dim tagliaWhere As String =')
 [IO.File]::WriteAllText((Join-Path $app 'fixture.aspx'),$page,$utf)
 $hostObject=[System.Web.Hosting.ApplicationHost]::CreateApplicationHost([FacetHost],'/',$app+'\')
 $r=$hostObject.Run('taglia=1%7C1','GET','')
 Save ('guard-'+$mode+'.html') $r[2]
 Assert ($r[0] -eq '500' -and $r[2].Contains('Catalog variant candidate predicate mismatch.')) ('literal guard rejects '+$mode)
}
Save 'checks.json' ($checks|ConvertTo-Json -Depth 5)
Save 'report.json' (@{result='PASS SOURCE / isolated WebForms / evaluated synthetic menu SQL';baseline=$base;checks=$checks.Count;gets=2*$queries.Count;postbacks=4;redirectGets=2;guardGets=2;recoveryGets=2;mainSelects=4;fixture='Unique (ArticoliId,TagliaId,ColoreId); every option is evaluated actual generated SQL';reuse='#432 scaffold only, previous811+227 matrix not rerun';limits=@('Not IIS or MySQL proof','SQLite dialect adapter, no decimal/performance certification','Synthetic commercial context/tokenization and DB I/O; no operational data','Deferred binding invoked by fixture PreRender in place of product-I/O completion','Invalid/incompatible selections remain removable; no full page or production certification')}|ConvertTo-Json -Depth 6)
Write-Output ('VARIANT_ALTERNATIVES_PASS '+$checks.Count+' '+$EvidenceDirectory)
