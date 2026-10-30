[CmdletBinding()]
param([string]$RepositoryRoot, [Parameter(Mandatory=$true)][string]$EvidenceDirectory, [string]$NodePath='node')
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'HOME_ASSORTMENT_REQUIRES_POWERSHELL_51'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
if(!$EvidenceDirectory.StartsWith($tempRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)){throw 'HOME_ASSORTMENT_REQUIRES_NEW_TEMP_DIRECTORY'}
$checks=New-Object 'Collections.Generic.List[object]'
function Check($name,[bool]$pass){$checks.Add([pscustomobject]@{Name=$name;Pass=$pass});if(!$pass){throw ('HOME_ASSORTMENT_ASSERT '+$name)}}
function Method($source,$name){$m=[regex]::Match($source,'(?ms)^    (?:Private|Protected) (?:Shared )?(?:Function|Sub) '+$name+'\b.*?^    End (?:Function|Sub)');if(!$m.Success){throw ('METHOD_MISSING '+$name)};return $m.Value}
New-Item -ItemType Directory -Path $EvidenceDirectory|Out-Null
$compiler=$null
try {
 $vb=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx.vb'))
 $provider=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CatalogMenuProvider.vb'))
 $models=[regex]::Match($provider,'(?s)Public Class CatalogMenuSector.*?(?=Public Module CatalogMenuProvider)').Value
 $selection=[regex]::Match($vb,'(?ms)^    Private NotInheritable Class HomeEditorialNavigation.*?(?=^    Protected Function HomeSectorMicrocopy)').Value
 $methods=@('BuildHomeNavigationAssortmentSql','LoadHomeNavigationAssortment','FilterHomeAssortmentSectors','SelectHomeAssortmentBrands','FilterBrandRows')|ForEach-Object {Method $vb $_}
 # The real VB selection, query builder and loader are compiled verbatim. Only DB transport and
 # logo file existence are substituted; no ASP.NET request, MySQL, IIS or operational assets are used.
 $standins=@'
Public Class FixtureDb
 Public Data As DataTable
 Public Reads As Integer
 Public Parameter As Object
 Public Sql As String
 Public Fail As Boolean
End Class
Public Class FixtureConnection
 Public Db As FixtureDb
 Public State As ConnectionState = ConnectionState.Closed
 Public Sub Open()
  State = ConnectionState.Open
 End Sub
End Class
Public Enum MySqlDbType
 Int32
End Enum
Public Class FixtureParameter
 Public Value As Object
End Class
Public Class FixtureParameters
 Public Item As New FixtureParameter()
 Public Function Add(name As String, kind As MySqlDbType) As FixtureParameter
  If name <> "@listino" OrElse kind <> MySqlDbType.Int32 Then Throw New Exception("PARAMETER_CONTRACT")
  Return Item
 End Function
End Class
Public Class MySqlCommand
 Implements IDisposable
 Public Parameters As New FixtureParameters()
 Public Sql As String
 Public Connection As FixtureConnection
 Public Sub New(text As String, conn As FixtureConnection)
  Sql=text : Connection=conn
 End Sub
 Public Sub Dispose() Implements IDisposable.Dispose
 End Sub
End Class
Public Class MySqlDataAdapter
 Implements IDisposable
 Private Command As MySqlCommand
 Public Sub New(cmd As MySqlCommand)
  Command=cmd
 End Sub
 Public Sub Fill(target As DataTable)
  Dim db = Command.Connection.Db
  db.Reads += 1 : db.Parameter=Command.Parameters.Item.Value : db.Sql=Command.Sql
  If db.Fail Then Throw New Exception("PRIVATE_TRANSPORT_DETAIL_MUST_NOT_ESCAPE")
  target.Merge(db.Data.Copy())
 End Sub
 Public Sub Dispose() Implements IDisposable.Dispose
 End Sub
End Class
Public Class HomeNavigationFixture
 Public Db As New FixtureDb()
 Public Listino As Integer
 Public LastError As String
 Public Invalidations As Integer
 Private Class HomeQueryConnectionLease
  Implements IDisposable
  Public Connection As FixtureConnection
  Public Sub Dispose() Implements IDisposable.Dispose
  End Sub
 End Class
 Private Function AcquireHomeQueryLease() As HomeQueryConnectionLease
  Return New HomeQueryConnectionLease With {.Connection=New FixtureConnection With {.Db=Db}}
 End Function
 Private Function GetCurrentListino() As Integer
  Return Listino
 End Function
 Private Sub InvalidateHomeQueryConnection()
  Invalidations += 1
 End Sub
 Private Sub ReportHomeError(context As String, ex As Exception)
  LastError=context & ":" & ex.Message
 End Sub
 Private Function ResolveBrandImage(value As Object) As String
  Dim text=Convert.ToString(value)
  Return If(text.StartsWith("valid-",StringComparison.Ordinal), "/synthetic/" & text, "")
 End Function
'@
 $code="Imports System`nImports System.Data`nImports System.Collections.Generic`nImports System.Globalization`n"+$models+$standins+"`n"+$selection+"`n"+($methods -join "`n")+"`nEnd Class"
 Add-Type -AssemblyName Microsoft.VisualBasic
 $compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
 $parameters=New-Object CodeDom.Compiler.CompilerParameters
 $parameters.GenerateInMemory=$true;$parameters.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict-'
 foreach($a in @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll')){[void]$parameters.ReferencedAssemblies.Add($a)}
 $compiled=$compiler.CompileAssemblyFromSource($parameters,$code)
 if($compiled.Errors.HasErrors){throw ('VB_COMPILE '+(($compiled.Errors|ForEach-Object {$_.ErrorText}) -join '; '))}
 $type=$compiled.CompiledAssembly.GetType('HomeNavigationFixture',$true)
 $sectorType=$compiled.CompiledAssembly.GetType('CatalogMenuSector',$true)
 $flags=[Reflection.BindingFlags]'Public,NonPublic,Instance,Static'
 $page=[Activator]::CreateInstance($type)
 function Call($name,[object[]]$arguments){return ,$type.GetMethod($name,$flags).Invoke($page,$arguments)}
 $sql=Call 'BuildHomeNavigationAssortmentSql' @()
 [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'query.sql'),$sql)
 $runner=@'
const fs=require('fs'),{DatabaseSync}=require('node:sqlite');
const sql=fs.readFileSync(process.argv[2],'utf8'),db=new DatabaseSync(':memory:');
db.exec('CREATE TABLE marche(id INTEGER PRIMARY KEY,Descrizione TEXT,img TEXT,link TEXT,Ordinamento INTEGER,Abilitato INTEGER);CREATE TABLE vsuperarticoli(id INTEGER,NListino INTEGER,SettoriId INTEGER,MarcheId INTEGER,Vetrina INTEGER,Giacenza INTEGER,Prezzo REAL);');
const brand=db.prepare('INSERT INTO marche VALUES(?,?,?,?,?,?)');
for(let id=1;id<=45;id++)brand.run(id,'Brand '+id,(id>=25&&id<=27?'invalid-':'valid-')+id+'.svg','articoli.aspx?mr='+id,id,id===29?0:1);
const product=db.prepare('INSERT INTO vsuperarticoli VALUES(?,?,?,?,0,0,0)');
for(let s=1;s<=20;s++)product.run(s,1,s,30);
for(let b=25;b<=40;b++){product.run(100+b,1,1,b);product.run(100+b,1,1,b);}
product.run(900,1,21,999); // A missing brand must not hide an otherwise navigable sector.
product.run(901,10,2,1);product.run(902,10,5,2);
const q=db.prepare(sql),out={};for(const list of [1,10,99])out[list]=q.all({listino:list});
fs.writeFileSync(process.argv[3],JSON.stringify(out));db.close();
'@
 [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'sql-fixture.cjs'),$runner)
 & $NodePath (Join-Path $EvidenceDirectory 'sql-fixture.cjs') (Join-Path $EvidenceDirectory 'query.sql') (Join-Path $EvidenceDirectory 'sql-results.json')
 if($LASTEXITCODE -ne 0){throw 'SYNTHETIC_SQL_FAILED'}
 $data=Get-Content -LiteralPath (Join-Path $EvidenceDirectory 'sql-results.json') -Raw|ConvertFrom-Json
 function Table($list){$t=New-Object Data.DataTable;foreach($column in @('SectorId','id','Descrizione','img','link','BrandOrder')){[void]$t.Columns.Add($column,$(if($column -in @('SectorId','id','BrandOrder')){[int]}else{[string]}))};foreach($row in @($data.PSObject.Properties[[string]$list].Value)){$r=$t.NewRow();foreach($c in $t.Columns){$v=$row.($c.ColumnName);$r[$c.ColumnName]=if($null -eq $v){[DBNull]::Value}else{$v}};$t.Rows.Add($r)};return ,$t}
 $listType=[Collections.Generic.List[object]].GetGenericTypeDefinition().MakeGenericType($sectorType)
 $source=[Activator]::CreateInstance($listType)
 foreach($id in 30..1){$s=[Activator]::CreateInstance($sectorType);$s.Id=$id;$s.Descrizione='Sector '+$id;$s.DefaultUrl='articoli.aspx?st='+$id;$source.Add($s)}
 function Ids($items){return (@($items|ForEach-Object {$_.Id}) -join ',')}
 function Field($nav,$name){return ,$nav.GetType().GetField($name).GetValue($nav)}
 foreach($list in @(1,10,99,10,1)){
  $page.Listino=$list;$page.Db.Data=Table $list;$before=$page.Db.Reads
  $rows=Call 'LoadHomeNavigationAssortment' @()
  Check "single aggregate read list$list/$before" ($page.Db.Reads -eq $before+1 -and $page.Db.Parameter -is [int] -and $page.Db.Parameter -eq $list -and $page.Db.Sql -ceq $sql)
  $sectors=Call 'FilterHomeAssortmentSectors' @($source,$rows)
  $expected=if($list -eq 1){21..1 -join ','}elseif($list -eq 10){'5,2'}else{''}
  Check "catalog membership and provider order list$list/$before" ((Ids $sectors) -ceq $expected)
  Check "shared provider not mutated list$list/$before" ((Ids $source) -ceq (30..1 -join ','))
  $nav=Call 'BuildHomeEditorialNavigation' (,$sectors)
  Check "main/editorial limits list$list/$before" ((Field $nav 'MainSectors').Count -eq [Math]::Min($sectors.Count,12) -and (Field $nav 'HeroSectors').Count -eq [Math]::Min($sectors.Count,9) -and (Field $nav 'SearchSectors').Count -eq [Math]::Min($sectors.Count,5))
  Check "secondary distribution list$list/$before" ((Field $nav 'CollectionSectors').Count -eq $(if($list -eq 1){3}else{0}) -and (Field $nav 'BottomSectors').Count -eq $(if($list -eq 1){3}else{0}))
  if($list -eq 1){Check 'secondary consecutive identities' ((Ids (Field $nav 'CollectionSectors')) -eq '9,8,7' -and (Ids (Field $nav 'BottomSectors')) -eq '6,5,4')}
  $brands=Call 'SelectHomeAssortmentBrands' (,$rows)
  $visible=Call 'FilterBrandRows' @($brands,12)
  $expectedBrands=if($list -eq 1){(@(28)+@(30..40)) -join ','}elseif($list -eq 10){'1,2'}else{''}
  Check "eligible ordered logos beyond old24 list$list/$before" ((@($visible.Rows|ForEach-Object {$_['id']}) -join ',') -eq $expectedBrands)
  Check "brand limit and no duplicate identities list$list/$before" ($visible.Rows.Count -le 12 -and @($brands.Rows|Group-Object id|Where-Object {$_.Count -gt 1}).Count -eq 0)
  Check "brand URL/data retained list$list/$before" (@($visible.Rows|Where-Object {$_['link'] -ne ('articoli.aspx?mr='+$_['id'])}).Count -eq 0)
 }
 $page.Db.Fail=$true;$page.Listino=1;$rows=Call 'LoadHomeNavigationAssortment' @()
 Check 'read failure distinct from empty assortment' ($null -eq $rows)
 Check 'read failure preserves all provider navigation' ((Ids (Call 'FilterHomeAssortmentSectors' @($source,$rows))) -eq (Ids $source))
 Check 'read failure does not expose unverified brands' ((Call 'SelectHomeAssortmentBrands' (,$rows)).Rows.Count -eq 0)
 Check 'error sanitized and connection invalidated' ($page.Invalidations -eq 1 -and $page.LastError -eq 'HomeNavigationAssortment:HOME_NAVIGATION_ASSORTMENT_READ_FAILED')
 $before=$page.Db.Reads;$page.Listino=0;[void](Call 'LoadHomeNavigationAssortment' @());Check 'invalid context never reads another list' ($page.Db.Reads -eq $before)
 $bind=Method $vb 'BindHome';$loader=Method $vb 'LoadHomeNavigationAssortment'
 Check 'single per-request membership load wired before editorial selection' ([regex]::Matches($bind,'LoadHomeNavigationAssortment\(').Count -eq 1 -and $bind.IndexOf('FilterHomeAssortmentSectors(') -lt $bind.IndexOf('BuildHomeEditorialNavigation('))
 Check 'brand filtering precedes final12 and preliminary24 removed' ($bind.Contains('FilterBrandRows(SelectHomeAssortmentBrands(navigationAssortment), 12)') -and !$vb.Contains('GetBrands(24)'))
 Check 'typed authoritative list parameter no cache' ($loader.Contains('GetCurrentListino()') -and $loader.Contains('MySqlDbType.Int32') -and !$loader.Contains('Cache') -and (Method $vb 'GetCurrentListino').Contains('_priceDisplayContext.PriceListId'))
 Check 'ordinary catalog uses same view and list constraint' ($sql.Contains('FROM vsuperarticoli v') -and $sql.Contains('WHERE v.NListino=@listino') -and $sql -notmatch 'Vetrina|Giacenza|Prezzo|Disponibil|LIMIT|TCId')
 $markup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx'))
 Check 'empty brand section omitted and full catalog links retained' ($bind.Contains('HomeBrandsSection.Visible = Not IsTableEmpty(brandRows)') -and $markup.Contains('href="articoli.aspx"'))
 $report=[pscustomobject]@{Passed=$checks.Count;Failed=0;Checks=$checks;Scope='Actual VB query builder/loader/selection methods; SQL executed on SQLite synthetic view, DB transport and logo existence simulated. No MySQL/IIS/browser, commercial or production certification.';SourceSha256=(Get-FileHash -LiteralPath (Join-Path $RepositoryRoot 'Default.aspx.vb')).Hash}
 $report|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'test-report.json') -Encoding UTF8
 Write-Output ('HOME_NAVIGATION_ASSORTMENT_PASS='+$checks.Count)
}finally{if($compiler){$compiler.Dispose()}}
