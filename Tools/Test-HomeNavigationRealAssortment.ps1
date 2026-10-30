[CmdletBinding()]
param([string]$RepositoryRoot, [Parameter(Mandatory=$true)][string]$EvidenceDirectory, [string]$NodePath='node', [switch]$CategoryDeltaOnly, [switch]$Browser)
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
 $directClass=[regex]::Match($vb,'(?ms)^    Private NotInheritable Class HomeDirectCategory\b.*?^    End Class').Value
 $methods=@('BuildHomeNavigationAssortmentSql','LoadHomeNavigationAssortment','FilterHomeAssortmentSectors','SelectHomeAssortmentBrands','FilterBrandRows','SelectHomeDirectCategories','SafeText','RenderHomeSectorMedia','HomeSectorInitial')|ForEach-Object {Method $vb $_}
 $taxonomy=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CatalogTaxonomyResolver.vb')) -replace '(?m)^(Option .*|Imports .*)\r?\n',''
 $breadcrumb=[regex]::Match([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/ProductStructuredDataBuilder.vb')),'(?ms)^Public NotInheritable Class StorefrontBreadcrumbItem\b.*?^End Class').Value
 $providerStub="Public Module CatalogMenuProvider`nPublic Function LoadCatalogMenuCached() As List(Of CatalogMenuSector)`nThrow New InvalidOperationException(""UNEXPECTED_GLOBAL_PROVIDER_READ"")`nEnd Function`nEnd Module`n"
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
 $code="Imports System`nImports System.Data`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Web`nImports System.Text.RegularExpressions`n"+(@($models,$breadcrumb,$providerStub,$taxonomy,$standins,$directClass,$selection,($methods -join "`n"),'End Class') -join "`n")
 Add-Type -AssemblyName Microsoft.VisualBasic
 Add-Type -AssemblyName System.Web
 $compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
 $parameters=New-Object CodeDom.Compiler.CompilerParameters
 $parameters.GenerateInMemory=$true;$parameters.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict-'
 foreach($a in @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll','System.Web.dll')){[void]$parameters.ReferencedAssemblies.Add($a)}
 $compiled=$compiler.CompileAssemblyFromSource($parameters,$code)
 if($compiled.Errors.HasErrors){throw ('VB_COMPILE '+(($compiled.Errors|ForEach-Object {$_.ErrorText}) -join '; '))}
 $type=$compiled.CompiledAssembly.GetType('HomeNavigationFixture',$true)
 $sectorType=$compiled.CompiledAssembly.GetType('CatalogMenuSector',$true)
 $flags=[Reflection.BindingFlags]'Public,NonPublic,Instance,Static'
 $page=[Activator]::CreateInstance($type)
 function Call($name,[object[]]$arguments){for($i=0;$i -lt $arguments.Count;$i++){if($null -ne $arguments[$i]){$arguments[$i]=$arguments[$i].PSObject.BaseObject}};return ,$type.GetMethod($name,$flags).Invoke($page,$arguments)}
 $sql=Call 'BuildHomeNavigationAssortmentSql' @()
 [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'query.sql'),$sql)
 $runner=@'
const fs=require('fs'),{DatabaseSync}=require('node:sqlite');
const sql=fs.readFileSync(process.argv[2],'utf8'),db=new DatabaseSync(':memory:');
db.exec('CREATE TABLE marche(id INTEGER PRIMARY KEY,Descrizione TEXT,img TEXT,link TEXT,Ordinamento INTEGER,Abilitato INTEGER);CREATE TABLE vsuperarticoli(id INTEGER,NListino INTEGER,SettoriId INTEGER,CategorieId INTEGER,MarcheId INTEGER,Vetrina INTEGER,Giacenza INTEGER,Prezzo REAL);');
const brand=db.prepare('INSERT INTO marche VALUES(?,?,?,?,?,?)');
for(let id=1;id<=45;id++)brand.run(id,'Brand '+id,(id>=25&&id<=27?'invalid-':'valid-')+id+'.svg','articoli.aspx?mr='+id,id,id===29?0:1);
const product=db.prepare('INSERT INTO vsuperarticoli VALUES(?,?,?,?,?,0,0,0)');
for(let s=1;s<=20;s++)product.run(s,1,s,s*100+1,30);
for(let b=25;b<=40;b++){product.run(100+b,1,1,101,b);product.run(100+b,1,1,101,b);}
product.run(900,1,21,2101,999); // Missing brand must not hide a navigable sector/category.
for(const cat of [201,202,203])product.run(cat,10,2,cat,1);
for(const cat of [501,502,503,504,505,506,507,508,510,511,512,513,514,515])product.run(cat,10,5,cat,2);
product.run(901,10,5,501,2); // Repeated membership does not duplicate a link.
product.run(902,77,1,0,30); // Navigable sector, no category.
product.run(903,10,99,9901,2); // No enabled sector in provider.
const q=db.prepare(sql),out={};for(const list of [1,10,77,99])out[list]=q.all({listino:list});
fs.writeFileSync(process.argv[3],JSON.stringify(out));db.close();
'@
 [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'sql-fixture.cjs'),$runner)
 & $NodePath (Join-Path $EvidenceDirectory 'sql-fixture.cjs') (Join-Path $EvidenceDirectory 'query.sql') (Join-Path $EvidenceDirectory 'sql-results.json')
 if($LASTEXITCODE -ne 0){throw 'SYNTHETIC_SQL_FAILED'}
 $data=Get-Content -LiteralPath (Join-Path $EvidenceDirectory 'sql-results.json') -Raw|ConvertFrom-Json
 function Table($list){$t=New-Object Data.DataTable;foreach($column in @('SectorId','CategoryId','id','Descrizione','img','link','BrandOrder')){[void]$t.Columns.Add($column,$(if($column -in @('SectorId','CategoryId','id','BrandOrder')){[int]}else{[string]}))};foreach($row in @($data.PSObject.Properties[[string]$list].Value)){$r=$t.NewRow();foreach($c in $t.Columns){$v=$row.($c.ColumnName);$r[$c.ColumnName]=if($null -eq $v){[DBNull]::Value}else{$v}};$t.Rows.Add($r)};return ,$t}
 $listType=[Collections.Generic.List[object]].GetGenericTypeDefinition().MakeGenericType($sectorType)
 $source=[Activator]::CreateInstance($listType)
 foreach($id in 30..1){$s=[Activator]::CreateInstance($sectorType);$s.Id=$id;$s.Descrizione='Sector '+$id;$s.DefaultUrl='articoli.aspx?st='+$id;$source.Add($s)}
 function Ids($items){return (@($items|ForEach-Object {$_.Id}) -join ',')}
 function Field($nav,$name){return ,$nav.GetType().GetField($name).GetValue($nav)}
 if(!$CategoryDeltaOnly){foreach($list in @(1,10,99,10,1)){
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
 }
 # Category delta: same compiled methods/SQLite transport, with the real pure taxonomy resolver.
 $page.Db.Fail=$false
 $categoryType=$compiled.CompiledAssembly.GetType('CatalogMenuCategory',$true)
 function Tree([string]$tenant){
  $tree=[Activator]::CreateInstance($listType)
  foreach($id in 30..1){$s=[Activator]::CreateInstance($sectorType);$s.Id=$id;$s.Descrizione=if($tenant -eq 'Tech'){'Componenti '+$id}else{'Dispensa '+$id};$s.DefaultUrl='articoli.aspx?st='+$id
   foreach($offset in 1..15){if($id -eq 5 -and $offset -in @(7,8)){continue};$c=[Activator]::CreateInstance($categoryType);$c.Id=$id*100+$offset;$c.SettoriId=$id;$c.Descrizione=if($tenant -eq 'Tech'){'Accessori '+$c.Id}else{'Alimenti e prodotti '+$c.Id};$c.DefaultUrl='articoli.aspx?st='+$id+'&ct='+$c.Id
    if($id -eq 5){switch($offset){2 {$c.SettoriId=999} 3 {$c.DefaultUrl='https://example.invalid/'} 4 {$c.DefaultUrl='articoli.aspx?st=2&ct=504'} 5 {$c.Descrizione=' '} 10 {$c.Descrizione='Alimenti & <b>bevande</b>'}}}
    $s.Categories.Add($c);if($id -eq 5 -and $offset -eq 1){$s.Categories.Add($c)}
   };$tree.Add($s)
  };return ,$tree
 }
 $fixtures=New-Object 'Collections.Generic.List[object]'
 foreach($list in @(1,10,77,99,10,1)){
  $tenant=if($list -eq 1){'Tech'}else{'Food'};$tree=Tree $tenant;$beforeTree=@($tree|ForEach-Object {($_.Id.ToString()+':'+(Ids $_.Categories))}) -join '|'
  $page.Listino=$list;$page.Db.Data=Table $list;$beforeReads=$page.Db.Reads;$rows=Call 'LoadHomeNavigationAssortment' @()
  $filtered=Call 'FilterHomeAssortmentSectors' @($tree,$rows);$categories=Call 'SelectHomeDirectCategories' @($filtered,$rows,8)
  $expected=if($list -eq 1){'2101,2001,1901,1801,1701,1601,1501,1401'}elseif($list -eq 10){'501,201,506,202,510,203,511,512'}else{''}
  Check "category membership/round-robin/editorial order list$list/$beforeReads" ((Ids $categories) -eq $expected)
  Check "category single typed read list$list/$beforeReads" ($page.Db.Reads -eq $beforeReads+1 -and $page.Db.Parameter -eq $list)
  Check "category unique IDs/max8 list$list/$beforeReads" ($categories.Count -le 8 -and @($categories|Group-Object Id|Where-Object {$_.Count -gt 1}).Count -eq 0)
  $resolve=$compiled.CompiledAssembly.GetType('CatalogTaxonomyResolver').GetMethods()|Where-Object {$_.Name -eq 'Resolve' -and $_.GetParameters().Count -eq 4}
  foreach($c in $categories){$ctx=$resolve.Invoke($null,@($filtered,$c.SectorId,$c.Id,''));Check "authoritative pair and URL $list/$($c.Id)/$beforeReads" ($ctx.IsCoherent -and $c.DefaultUrl -eq $ctx.CategoryUrl -and $c.Name -eq $ctx.CategoryName -and $c.SectorName -eq $ctx.SectorName)}
  Check "provider tree not mutated list$list/$beforeReads" ($beforeTree -eq (@($tree|ForEach-Object {($_.Id.ToString()+':'+(Ids $_.Categories))}) -join '|'))
  Check "hard limit even when caller asks more list$list/$beforeReads" ((Call 'SelectHomeDirectCategories' @($filtered,$rows,99)).Count -le 8)
  if($list -eq 10){Check 'disabled/absent/malformed categories excluded' (@($categories|Where-Object {$_.Id -in @(502,503,504,505,507,508,9901)}).Count -eq 0);Check 'taxonomy normalizes label' (@($categories|Where-Object {$_.Id -eq 510})[0].Name -eq 'Alimenti & bevande')}
  if($list -eq 1){Check 'eight different sectors when present' (@($categories|Select-Object -ExpandProperty SectorId -Unique).Count -eq 8)}
  if($fixtures.Count -lt 4){$fixtures.Add([pscustomobject]@{Name=if($list -eq 1){'Tech'}elseif($list -eq 10){'Food'}else{'Empty'+$list};Sectors=(Field (Call 'BuildHomeEditorialNavigation' (,$filtered)) 'MainSectors');Categories=$categories})}
 }
 $page.Db.Fail=$true;$page.Listino=1;$failedRows=Call 'LoadHomeNavigationAssortment' @()
 Check 'category read error omits all unverified links' ((Call 'SelectHomeDirectCategories' @((Tree 'Tech'),$failedRows,8)).Count -eq 0)
 Check 'category null tree and zero limit empty' ((Call 'SelectHomeDirectCategories' @($null,(Table 1),8)).Count -eq 0 -and (Call 'SelectHomeDirectCategories' @((Tree 'Tech'),(Table 1),0)).Count -eq 0)
 $bind=Method $vb 'BindHome';$selector=Method $vb 'SelectHomeDirectCategories';$markup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx'))
 Check 'category binding and omission follows actual rows' ($bind.Contains('SelectHomeDirectCategories(realSectors, navigationAssortment)') -and $bind.Contains('HomeDirectCategoriesSection.Visible = (directCategories.Count > 0)'))
 Check 'category taxonomy uses tree overload, no per-link I/O/cache' ($selector.Contains('CatalogTaxonomyResolver.Resolve(source, sector.Id, category.Id, String.Empty)') -and $selector -notmatch 'MySql|LoadCatalogMenu|\.Cache|SafeTableQuery')
 Check 'category extends existing single query' ($sql.Contains('COALESCE(v.CategorieId,0) AS CategoryId') -and [regex]::Matches($bind,'LoadHomeNavigationAssortment\(').Count -eq 1)
 $baseMarkup=(git -C $RepositoryRoot show 'c2bb83a1614b7c57cc99b017471ffac868b2a6b0:Default.aspx') -join "`n"
 if($LASTEXITCODE -ne 0){throw 'CATEGORY_BASE_MARKUP_UNAVAILABLE'}
 $withoutDelta=[regex]::Replace($markup,'(?s)    <style id="ksHomeDirectCategoryStyles">.*?</style>\r?\n','')
 $withoutDelta=[regex]::Replace($withoutDelta,'(?s)    <section id="HomeDirectCategoriesSection".*?</section>\r?\n\r?\n','')
 Check 'all preceding markup and sector cards unchanged' ($withoutDelta.Replace("`r`n","`n").TrimEnd() -ceq $baseMarkup.TrimEnd())
 $baseVb=(git -C $RepositoryRoot show 'c2bb83a1614b7c57cc99b017471ffac868b2a6b0:Default.aspx.vb') -join "`n"
 if($LASTEXITCODE -ne 0){throw 'CATEGORY_BASE_VB_UNAVAILABLE'}
 $baseSelection=[regex]::Match($baseVb,'(?ms)^    Private NotInheritable Class HomeEditorialNavigation.*?(?=^    Protected Function HomeSectorMicrocopy)').Value
 Check 'editorial distribution source and prior standalone harness remain unchanged' (($selection -replace '\s+',' ') -ceq ($baseSelection -replace '\s+',' '))
 $browserFixtures=New-Object 'Collections.Generic.List[object]'
 function Fragment($id,$items){$m=[regex]::Match($markup,'(?s)<section id="'+$id+'"[^>]*>.*?</section>');if(!$m.Success){throw 'CATEGORY_SECTION_MISSING'};if($items.Count -eq 0){return ''};$html=[regex]::Replace($m.Value,'(?s)<asp:Repeater\b[^>]*>.*?<ItemTemplate>(.*?)</ItemTemplate>.*?</asp:Repeater>',[Text.RegularExpressions.MatchEvaluator]{param($repeat);$parts=foreach($item in $items){[regex]::Replace($repeat.Groups[1].Value,'(?s)<%#(.*?)%>',[Text.RegularExpressions.MatchEvaluator]{param($binding);$expr=$binding.Groups[1].Value.Trim();switch -Regex ($expr){'^SafeText\(ResolveUrl' {return [string](Call 'SafeText' @([Web.VirtualPathUtility]::ToAbsolute($item.DefaultUrl,'/shop')))} '^SafeText\(Eval\("(Name|SectorName|Descrizione)"\)\)$' {return [string](Call 'SafeText' @($item.($Matches[1])))} '^Eval\("DefaultUrl"\)$' {return [string]$item.DefaultUrl} '^RenderHomeSectorMedia' {return [string](Call 'RenderHomeSectorMedia' @($item.ImgUrl,$item.Descrizione))} default {throw 'UNSUPPORTED_CATEGORY_BINDING'}}})};return ($parts -join '')});$html=$html.Replace(' runat="server"','').Replace(' visible="false"','');if($html -match '<asp:|<%'){throw 'UNMATERIALIZED_CATEGORY_BINDING'};return $html}
 foreach($f in $fixtures){$before=Fragment 'HomeMainCategoriesSection' $f.Sectors;$direct=Fragment 'HomeDirectCategoriesSection' $f.Categories;$browserFixtures.Add([pscustomobject]@{Name=$f.Name;Before=$before;After=($before+$direct);Expected=@($f.Categories|ForEach-Object {[pscustomobject]@{Id=$_.Id;SectorId=$_.SectorId;Name=$_.Name;SectorName=$_.SectorName;Url=[Web.VirtualPathUtility]::ToAbsolute($_.DefaultUrl,'/shop')}})})}
 $browserFixtures|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'browser-fixtures.json') -Encoding UTF8
 $browserRunner=@'
'use strict';
const fs=require('fs'),path=require('path'),http=require('http');
const {chromium}=require(path.resolve(path.dirname(process.execPath),'../node_modules/playwright'));
const root=__dirname,repo=process.argv[2],theme=path.join(repo,'Public/assets/keepstore'),served=path.join(root,'served');
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'browser-fixtures.json'),'utf8').replace(/^\uFEFF/,''));
const aspx=fs.readFileSync(path.join(repo,'Default.aspx'),'utf8'),master=fs.readFileSync(path.join(repo,'Page.master'),'utf8');
const styles=[...aspx.substring(0,aspx.indexOf('</asp:Content>',aspx.indexOf('ContentPlaceHolderID="HeadContent"'))).matchAll(/<style\b[^>]*>[\s\S]*?<\/style>/g)].map(x=>x[0]);
const slot=master.indexOf('<asp:ContentPlaceHolder ID="HeadContent"'),end=master.indexOf('</head>');
if(slot<0||end<slot)throw Error('MASTER_CSS_ORDER_MISSING');
const files=new Map(),copied=new Set(),results=[],requests=[],unavailableCssAssets=[],missingRequestedAssets=[],allowed=new Set(['.css','.woff','.woff2','.ttf','.otf','.eot','.svg','.png','.jpg','.jpeg','.gif','.webp']);
function check(name,pass,data){results.push({name,pass:!!pass,data});if(!pass)throw Error(name);}
function copyAsset(relative){const abs=path.resolve(theme,relative);if(!abs.startsWith(path.resolve(theme)+path.sep)||!allowed.has(path.extname(abs).toLowerCase()))throw Error('ASSET_NOT_ALLOWLISTED');if(copied.has(abs))return;copied.add(abs);if(!fs.existsSync(abs)){unavailableCssAssets.push(relative);return;}let current=abs;while(current!==theme){if(fs.lstatSync(current).isSymbolicLink())throw Error('ASSET_SYMLINK');current=path.dirname(current);}const rel=path.relative(theme,abs).split(path.sep).join('/'),dest=path.join(served,rel);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(abs,dest);files.set('/shop/assets/'+rel,dest);if(path.extname(abs).toLowerCase()==='.css'){const css=fs.readFileSync(abs,'utf8');for(const m of css.matchAll(/url\(\s*(['"]?)(.*?)\1\s*\)/g)){const raw=m[2].split(/[?#]/)[0];if(!raw||/^(data:|https?:|\/\/)/i.test(raw))continue;copyAsset(path.relative(theme,path.resolve(path.dirname(abs),decodeURIComponent(raw))));}}}
function links(part){return [...part.matchAll(/ThemeManager\.Asset\("([^"]+\.css)"\)/g)].map(m=>{copyAsset(m[1]);return '<link rel="stylesheet" href="/shop/assets/'+m[1]+'">';}).join('');}
const leading=links(master.substring(0,slot)),trailing=links(master.substring(slot,end)),pages=new Map();
for(const f of fixtures){for(const state of ['Before','After']){const css=state==='Before'?styles.filter(x=>!x.includes('ksHomeDirectCategoryStyles')):styles;pages.set('/shop/'+f.Name+'-'+state+'.html','<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+leading+css.join('')+trailing+'</head><body class="ks-page-home"><main id="ksHomePage" class="ks-home-main">'+f[state]+'</main></body></html>');}}
let browser,server,origin,result='B',error=null;
(async()=>{try{
server=http.createServer((req,res)=>{const u=new URL(req.url,'http://127.0.0.1');requests.push({method:req.method,path:u.pathname});if(!['GET','HEAD'].includes(req.method)){res.writeHead(405).end();return;}if(pages.has(u.pathname)){res.setHeader('Content-Type','text/html; charset=utf-8');res.end(pages.get(u.pathname));return;}if(u.pathname==='/shop/articoli.aspx'){res.setHeader('Content-Type','text/html; charset=utf-8');res.end('<!doctype html><title>Catalogo sintetico</title><h1>Destinazione categoria sintetica</h1>');return;}const file=files.get(u.pathname);if(!file){if(u.pathname.startsWith('/shop/assets/'))missingRequestedAssets.push(u.pathname);res.writeHead(404).end();return;}const ext=path.extname(file).toLowerCase();res.setHeader('Content-Type',ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':ext==='.woff2'?'font/woff2':ext==='.woff'?'font/woff':'application/octet-stream');res.end(fs.readFileSync(file));});
await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});check('server loopback only',server.address().address==='127.0.0.1');origin='http://127.0.0.1:'+server.address().port;
browser=await chromium.launchPersistentContext(path.join(root,'browser-profile'),{executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:false,serviceWorkers:'block',args:['--no-proxy-server']});
await browser.route('**/*',route=>{const r=route.request(),u=new URL(r.url());if(u.origin!==origin||!['GET','HEAD'].includes(r.method()))return route.abort();return route.continue();});
const p=await browser.newPage();
async function stable(){await p.evaluate(()=>document.fonts.ready);}
async function sectorRects(){return p.locator('.ks-home-category-card').evaluateAll(nodes=>nodes.map(e=>{const r=e.getBoundingClientRect();return {href:e.getAttribute('href'),x:r.x,y:r.y,width:r.width,height:r.height};}));}
for(const f of fixtures){for(const width of [390,1365]){const label=f.Name+'/'+width;await p.setViewportSize({width,height:950});await p.goto(origin+'/shop/'+f.Name+'-Before.html',{waitUntil:'load'});await stable();const before=await sectorRects();await p.goto(origin+'/shop/'+f.Name+'-After.html',{waitUntil:'load'});await stable();const after=await sectorRects();check(label+' existing sector geometry/links unchanged',JSON.stringify(before)===JSON.stringify(after));check(label+' no page overflow',await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));check(label+' no nested links',await p.locator('a a').count()===0);const group=p.locator('.ks-home-direct-categories'),anchors=p.locator('.ks-home-direct-category-link');if(f.Expected.length===0){check(label+' empty category block fully omitted',await group.count()===0&&await p.locator('#ksHomeDirectCategoriesTitle').count()===0);continue;}
check(label+' region/heading',await group.getAttribute('aria-labelledby')==='ksHomeDirectCategoriesTitle'&&await p.locator('#ksHomeDirectCategoriesTitle').innerText()==='Esplora le categorie');check(label+' count',await anchors.count()===f.Expected.length&&f.Expected.length<=8);
for(let i=0;i<f.Expected.length;i++){const a=anchors.nth(i),expected=f.Expected[i];await a.scrollIntoViewIfNeeded();const state=await a.evaluate(e=>{const r=e.getBoundingClientRect(),hit=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return {href:e.getAttribute('href'),width:r.width,height:r.height,text:[...e.children].map(x=>x.textContent),hit:e===hit||e.contains(hit)};});check(label+' link/labels '+i,state.href===expected.Url&&state.text[0]===expected.Name&&state.text[1]===expected.SectorName,state);check(label+' actual target44 '+i,state.width>=44&&state.height>=44&&state.hit,state);}
await p.locator('.ks-home-category-card').last().focus();for(let i=0;i<f.Expected.length;i++){await p.keyboard.press('Tab');const state=await anchors.nth(i).evaluate(e=>({focused:document.activeElement===e,visible:e.matches(':focus-visible'),outline:getComputedStyle(e).outlineStyle,outlineWidth:parseFloat(getComputedStyle(e).outlineWidth),transition:getComputedStyle(e).transitionProperty,duration:getComputedStyle(e).transitionDuration,main:getComputedStyle(e).getPropertyValue('--main'),newStyle:!!document.getElementById('ksHomeDirectCategoryStyles')}));check(label+' keyboard/focus '+i,state.focused&&state.visible&&state.outline!=='none'&&state.outlineWidth>=3,state);}
await anchors.first().focus();await anchors.first().scrollIntoViewIfNeeded();await group.screenshot({path:path.join(root,f.Name+'-'+width+'.png')});
await anchors.first().click();await p.waitForURL(origin+f.Expected[0].Url);check(label+' click destination',new URL(p.url()).pathname==='/shop/articoli.aspx');await p.goBack({waitUntil:'load'});await p.locator('.ks-home-direct-category-link').first().focus();await p.keyboard.press('Enter');await p.waitForURL(origin+f.Expected[0].Url);check(label+' enter destination',new URL(p.url()).searchParams.get('ct')===String(f.Expected[0].Id));
}}
check('all assets used by delta available',missingRequestedAssets.length===0,missingRequestedAssets);check('no mutative HTTP requests',requests.every(r=>['GET','HEAD'].includes(r.method)));result='A';
}catch(e){error=String(e.message).split('\n')[0];}finally{if(browser)await browser.close();if(server){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}fs.writeFileSync(path.join(root,'browser-report.json'),JSON.stringify({result,error,passed:results.filter(x=>x.pass).length,failed:results.filter(x=>!x.pass).length,checks:results,scope:'Headed Chrome390/1365, Tech/Food/empty fixtures; actual CSS order and materialized ASPX subset. Static loopback, synthetic catalog destination only; no IIS/MySQL/application JS or ecommerce requests.',temporaryServerClosed:true},null,2));console.log(JSON.stringify({result,error,checks:results.length,pass:results.filter(x=>x.pass).length}));if(result!=='A')process.exitCode=1;}})();
'@
 [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'browser-qa.cjs'),$browserRunner)
 if($Browser){try{& $NodePath (Join-Path $EvidenceDirectory 'browser-qa.cjs') $RepositoryRoot;if($LASTEXITCODE -ne 0){throw 'CATEGORY_BROWSER_QA_FAILED'}}finally{foreach($leaf in @('served','browser-profile')){$target=[IO.Path]::GetFullPath((Join-Path $EvidenceDirectory $leaf));if($target -ne ($EvidenceDirectory.TrimEnd('\')+'\'+$leaf)){throw 'CATEGORY_CLEANUP_TARGET_INVALID'};if(Test-Path -LiteralPath $target){if((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'CATEGORY_CLEANUP_REPARSE'};Remove-Item -LiteralPath $target -Recurse -Force}}}}
 $report=[pscustomobject]@{Passed=$checks.Count;Failed=0;CategoryDeltaOnly=[bool]$CategoryDeltaOnly;Checks=$checks;Scope='Actual VB selector/loader/query and pure taxonomy resolver; SQL on SQLite synthetic view, DB transport/logo existence simulated. ASPX subset bindings materialized with actual VB helpers; full WebForms/IIS lifecycle not certified.';SourceSha256=(Get-FileHash -LiteralPath (Join-Path $RepositoryRoot 'Default.aspx.vb')).Hash}
 $report|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'test-report.json') -Encoding UTF8
 Write-Output ('HOME_NAVIGATION_ASSORTMENT_PASS='+$checks.Count)
}finally{if($compiler){$compiler.Dispose()}}
