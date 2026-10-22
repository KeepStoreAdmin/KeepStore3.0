[CmdletBinding()]
param([string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'HOME_MERCH_REQUIRES_PS51'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\')
if(!$EvidenceDirectory.StartsWith($tempRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)){throw 'HOME_MERCH_INVALID_OUTPUT'}
$node=(Get-Command node -ErrorAction Stop).Source
$work=Join-Path $tempRoot ('ks-home-merch-compile-'+[Guid]::NewGuid().ToString('N'))
$utf8=New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$checks=New-Object 'Collections.Generic.List[object]'
function Check([string]$name,[bool]$ok){$checks.Add([pscustomobject]@{Name=$name;Pass=$ok});if(!$ok){throw ('HOME_MERCH_ASSERT: '+$name)}}
function Write-Json([string]$name,$value){[IO.File]::WriteAllText((Join-Path $EvidenceDirectory $name),($value|ConvertTo-Json -Depth 14),$utf8)}
function Method-Map([string]$source){
 $map=@{}
 foreach($m in [regex]::Matches($source,'(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) (\w+)\b.*?^    End (?:Function|Sub)')){
  $name=$m.Groups[1].Value;if(!$map.ContainsKey($name)){$map[$name]=@()};$map[$name]+=$m.Value
 };return $map
}
function Stable([string]$html){[regex]::Replace($html,'(?i)(requestId=|data-ks-request-id='')[a-f0-9]{32}','$1FIXTURE_REQUEST_ID')}
try{
 New-Item -ItemType Directory -Path $EvidenceDirectory,$work | Out-Null
 Add-Type -AssemblyName System.Web
 Add-Type -AssemblyName Microsoft.VisualBasic
 $source=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx.vb'))
 $base=(git -C $RepositoryRoot show '77a9e71ede510fbdf3908ee18a29b3ca56a9dd5a:Default.aspx.vb') -join [Environment]::NewLine
 if($LASTEXITCODE -ne 0){throw 'HOME_MERCH_BASE_UNAVAILABLE'}
 $map=Method-Map $source;$oldMap=Method-Map $base
 $cart=Method-Map ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CartMutationIdempotencyService.vb')))
 $cartCode="Imports System`nImports System.Globalization`nImports System.Web`nPublic Class CartMutationIdempotencyService`n"+((@('CreateRequestId','BuildNativeActionValue','NormalizeTCId')|ForEach-Object{$cart[$_]}) -join [Environment]::NewLine)+"`nEnd Class"
 $shared=@('StorefrontPriceDisplayContext.vb','UiPriceFormatter.vb','AvailabilityDisplayHelper.vb','ThemeManager.vb','UiData.vb','StorefrontEffectivePriceSqlBuilder.vb')|ForEach-Object{[IO.File]::ReadAllText((Join-Path $RepositoryRoot ('App_Code/'+$_)))}
 $inventory=Method-Map ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/OrderInventoryAvailabilityService.vb')))
 $shared+=('Imports System'+[Environment]::NewLine+'Public Class OrderInventoryAvailabilityService'+[Environment]::NewLine+$inventory.CalculateNetAvailableQuantity[0]+[Environment]::NewLine+'End Class')
 $compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
 function Compile-Home($methods,[string]$name,[bool]$candidate){
  $names=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  $queue=New-Object 'Collections.Generic.Queue[string]'
  @('RenderGridCard','EmptyProductsTable')|ForEach-Object{$queue.Enqueue($_)}
  if($candidate){@('GetBestSellerPool','GetNewArrivalsPool','GetIncomingPool','BuildHomeCommercialActivitySql','TakeRankedHomeRows','TakeHomeArrivalsRows','AvailabilityWhereClause','ReservedWhereClause')|ForEach-Object{$queue.Enqueue($_)}}
  while($queue.Count){$n=$queue.Dequeue();if(!$names.Add($n)){continue};if(!$methods.ContainsKey($n)){throw ('HOME_MERCH_MISSING_METHOD: '+$n)};if($n -eq 'TryLoadProducts'){continue};foreach($body in $methods[$n]){foreach($call in [regex]::Matches($body,'\b(\w+)\s*\(')){$dependency=$call.Groups[1].Value;if($methods.ContainsKey($dependency) -and !$names.Contains($dependency)){$queue.Enqueue($dependency)}}}}
  $bodies=foreach($n in $names){if($n -eq 'TryLoadProducts'){$loader=$methods[$n][0];$loader.Substring(0,$loader.IndexOf('        Try'+[Environment]::NewLine))+"        LastSql = sql.ToString()`n        Return EmptyProductsTable()`n    End Function"}else{$methods[$n]}}
  $wrapper=@'
    Private ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")
    Private _priceDisplayContext As StorefrontPriceDisplayContext
    Public LastSql As String
    Public Sub Configure(company As Integer, listino As Integer, authenticated As Boolean, included As Boolean)
        _priceDisplayContext = New StorefrontPriceDisplayContext(company, listino, authenticated, If(included, StorefrontVatDisplayMode.VatIncluded, StorefrontVatDisplayMode.VatExcluded), Nothing, -1, "", False)
    End Sub
    Public Function Table() As DataTable
        Dim rows As DataTable = EmptyProductsTable()
        If Not rows.Columns.Contains("TCid") Then rows.Columns.Add("TCid", GetType(Integer))
        Return rows
    End Function
    Public Function Card(row As DataRow) As String
        Return RenderGridCard(row.Table.DefaultView(row.Table.Rows.IndexOf(row)))
    End Function
'@
  if($candidate){$wrapper+=[Environment]::NewLine+@'
    Public Function Sql(name As String) As String
        Select Case name
            Case "rank" : GetBestSellerPool(8)
            Case "new" : GetNewArrivalsPool(60)
            Case "incoming" : GetIncomingPool(60)
        End Select
        Return LastSql
    End Function
    Public Function ActivitySql() As String
        Return BuildHomeCommercialActivitySql()
    End Function
    Public Function Ranked(rows As DataTable) As DataTable
        Return TakeRankedHomeRows(8, New HashSet(Of String)(StringComparer.OrdinalIgnoreCase), New HashSet(Of String)(StringComparer.OrdinalIgnoreCase), rows)
    End Function
    Public Function Arrivals(fresh As DataTable, incoming As DataTable) As DataTable
        Return TakeHomeArrivalsRows(8, New HashSet(Of String)(StringComparer.OrdinalIgnoreCase), New HashSet(Of String)(StringComparer.OrdinalIgnoreCase), fresh, incoming)
    End Function
'@}
  $code="Imports System`nImports System.Data`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Text`nImports System.Text.RegularExpressions`nImports System.Web`nPublic Class "+$name+[Environment]::NewLine+($bodies -join [Environment]::NewLine)+[Environment]::NewLine+$wrapper+[Environment]::NewLine+'End Class'
  $parameters=New-Object CodeDom.Compiler.CompilerParameters
  $parameters.GenerateInMemory=$true;$parameters.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
  $parameters.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($work,$false)
  @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll','System.Web.dll','System.Configuration.dll')|ForEach-Object{[void]$parameters.ReferencedAssemblies.Add($_)}
  $compiled=$compiler.CompileAssemblyFromSource($parameters,[string[]](@($code,$cartCode)+$shared))
  if($compiled.Errors.HasErrors){throw ('HOME_MERCH_COMPILE: '+(($compiled.Errors|Where-Object{!$_.IsWarning}|ForEach-Object{'line '+$_.Line+': '+$_.ErrorText}) -join '; '))}
  return [Activator]::CreateInstance($compiled.CompiledAssembly.GetType($name,$true))
 }
 $new=Compile-Home $map 'CandidateHomeMerch' $true;$old=Compile-Home $oldMap 'BaselineHomeMerch' $false
 $new.Configure(101,1,$false,$true)
 Write-Json 'queries.json' ([ordered]@{rank=$new.Sql('rank');fresh=$new.Sql('new');incoming=$new.Sql('incoming');activity=$new.ActivitySql();clock=@{Today=[DateTime]::Today.ToString('yyyy-MM-dd');Start=[DateTime]::Today.AddMonths(-12).ToString('yyyy-MM-dd')}})
 $table=$new.Table()
 $schema=@($table.Columns|ForEach-Object{[pscustomobject]@{name=$_.ColumnName;type=$(if($_.DataType -eq [string] -or $_.DataType -eq [DateTime]){'TEXT'}else{'NUMERIC'})}})+@([pscustomobject]@{name='NListino';type='NUMERIC'})
 Write-Json 'schema.json' $schema
 $nodeScript=@'
const fs=require('node:fs'),path=require('node:path'),{DatabaseSync}=require('node:sqlite');
const dir=process.argv[2],q=JSON.parse(fs.readFileSync(path.join(dir,'queries.json'),'utf8')),schema=JSON.parse(fs.readFileSync(path.join(dir,'schema.json'),'utf8'));
const today=q.clock.Today, date=n=>{let d=new Date(today+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)}, start=()=>q.clock.Start;
const checks=[],fixtures=[];function check(name,ok){checks.push({Name:name,Pass:!!ok});if(!ok)throw Error('HOME_MERCH_SQL_ASSERT: '+name)}
const db=new DatabaseSync(':memory:');db.function('GREATEST',(a,b)=>Math.max(a,b));db.function('CURDATE',()=>today);db.function('YEAR',d=>Number(String(d).slice(0,4)));
db.exec('CREATE TABLE vsuperarticoli ('+schema.map(c=>'"'+c.name+'" '+c.type).join(',')+');CREATE TABLE articoli(id INTEGER PRIMARY KEY,Abilitato INTEGER);CREATE TABLE articoli_giacenze(ArticoliId INTEGER,Giacenza NUMERIC,Disponibilita NUMERIC,Impegnata NUMERIC);CREATE TABLE documentirighe(id INTEGER PRIMARY KEY,DocumentiId INTEGER,ArticoliId INTEGER,TCid INTEGER,Qnt NUMERIC,TipoRiga TEXT);CREATE TABLE documenti(id INTEGER PRIMARY KEY,AziendeId INTEGER,TipoDocumentiId INTEGER,StatiId INTEGER,DataDocumento TEXT);CREATE TABLE tipodocumenti(id INTEGER PRIMARY KEY,MovimentiTipoId INTEGER,Segno INTEGER,ImpegnaQnt INTEGER);CREATE TABLE movimentitipo(id INTEGER PRIMARY KEY,Descrizione TEXT);CREATE TABLE documentistati(id INTEGER PRIMARY KEY,Descrizione1 TEXT,Abilitato INTEGER);CREATE TABLE tipodocumenticontabili(TipoDocumentiId INTEGER,NotaCreditoClienti INTEGER,NotaCreditoFornitori INTEGER)');
db.exec("INSERT INTO movimentitipo VALUES(73,' Uscita '),(81,'INGRESSO');INSERT INTO documentistati VALUES(11,'Valido',1),(29,'Annullato',1),(31,'Disabilitato',0);INSERT INTO tipodocumenti VALUES(401,73,0,1),(402,73,-1,0),(403,73,-1,1),(404,81,-1,1),(405,73,-1,0),(406,73,0,0);INSERT INTO tipodocumenticontabili VALUES(405,1,0),(405,1,0)");
let docId=0,rowId=0;const doc=db.prepare('INSERT INTO documenti VALUES(?,?,?,?,?)'),line=db.prepare('INSERT INTO documentirighe VALUES(?,?,?,?,?,?)');
function event(company,article,type,qty,ago=-1,tc=-1,state=11){doc.run(++docId,company,type,state,ago===null?null:typeof ago==='string'?ago:date(ago));line.run(++rowId,docId,article,tc,qty,'A')}
const insertProduct=db.prepare('INSERT INTO vsuperarticoli('+schema.map(c=>'"'+c.name+'"').join(',')+') VALUES('+schema.map(()=>'?').join(',')+')'),insertArticle=db.prepare('INSERT OR IGNORE INTO articoli VALUES(?,?)');
function product(company,id,changes={}){const food=company===202;const base=Object.fromEntries(schema.map(c=>[c.name,c.type==='TEXT'?'':0]));Object.assign(base,{id,TCid:-1,Codice:'C'+id,Ean:'EAN'+id,Descrizione1:(food?['Pasta grano duro','Riso integrale bio','Olio extravergine','Farina tipo uno','Caffe arabica','Passata pomodoro','Biscotti avena','Miele acacia','Cioccolato fondente','Legumi misti','Spezie aromatiche','Conserva biologica']:['Router rete mesh','Switch rete gigabit','Cuffie audio wireless','Scheda video professionale','Cavo ethernet schermato','Hub porte multipla','Monitor display professionale','Tastiera meccanica compatta','Mouse laser ergonomico','Access point portatile','Server storage compatto','Webcam panoramica'])[(id%100>=90?id%100-81:id%100-1)%12],Descrizione2:'',Img1:'https://merch-'+(food?'food':'tech')+'.invalid/Public/assets/images/articoli/fixture-'+id+'.jpg',MarcheDescrizione:food?'Alba':'Nova',CategorieDescrizione:food?'Dispensa':'Reti',SettoriDescrizione:food?'Alimentari':'Elettronica',Vetrina:1,Abilitato:1,Attivo:1,Giacenza:5,Disponibilita:5,Prezzo:100,PrezzoIvato:122,DataCreazione:date(-100),NListino:food?10:1,IdIvaRC:-1,ValoreIvaRC:-1,DisplayPromoSnapshotReady:1,DisplayPromoTechnicalError:0,DisplayPromoQtyOnePrice:0,OfferteDataInizio:null,OfferteDataFine:null,DisplayPromoDeadline:null,LastCommercialActivity:null},changes);insertProduct.run(...schema.map(c=>base[c.name]??null));insertArticle.run(id,base.Abilitato);return base}
for(const company of [101,202]){const n=company===101?0:100;
 for(let i=1;i<=9;i++)product(company,n+i);
 event(company,n+1,401,10,-4);event(company,n+1,402,10,-3);
 event(company,n+2,401,10,-2);event(company,n+2,402,4,-1);
 event(company,n+3,402,5);event(company,n+4,403,7);
 event(company,n+5,404,500);event(company,n+5,405,500);event(company,n+5,401,500,-1,-1,29);event(company,n+5,406,500);
 event(company,n+6,401,6,0,11);event(company,n+6,401,4,0,12);event(company,n+6,402,10,0,12);for(let tc=1;tc<=20;tc++)product(company,n+6,{TCid:tc});
 event(company,n+7,402,2,start());event(company,n+7,402,900,date(-800));event(company,n+7,402,900,1);event(company,n+7,402,900,null);event(company,n+7,402,-20);event(company,n+7,402,0);
 event(company,n+8,401,4,-5);event(company,n+8,402,5,-4);event(company,n+9,401,400,-1,-1,31);
 event(999,n+1,401,99999);
 for(const [id,changes] of [[80,{Vetrina:0}],[89,{Giacenza:5,Impegnata:5,Disponibilita:0,InOrdine:3}],[90,{Giacenza:0,Disponibilita:0,InOrdine:5}],[91,{InOrdine:2,DataCreazione:date(-2)}],[92,{DataCreazione:date(-2)}],[93,{DataCreazione:date(-101)}],[94,{DataCreazione:date(1)}],[95,{DataCreazione:null}],[96,{Vetrina:0,DataCreazione:date(-1)}],[97,{NListino:999,DataCreazione:date(-1)}],[98,{Abilitato:0,DataCreazione:date(-1)}],[99,{Prezzo:0,PrezzoIvato:0,DataCreazione:date(-1)}]]){product(company,n+id,changes);if(id===80||id===90)event(company,n+id,401,1000)}
}
for(const company of [101,202]){const n=company===101?0:100;for(let tc=1;tc<=70;tc++){product(company,n+91,{TCid:tc,InOrdine:2,DataCreazione:date(-2)});product(company,n+92,{TCid:tc,DataCreazione:date(-2)})}}
function run(sql,p){const stmt=db.prepare(sql);const keys=[...new Set(sql.match(/@[A-Za-z][A-Za-z0-9]*/g)||[])];return stmt.all(Object.fromEntries(keys.map(k=>[k.slice(1),p[k.slice(1)]])))}
for(const company of [101,202]){const n=company===101?0:100,p={commercialCompany:company,commercialStart:start(),commercialEnd:date(1),homeNewStart:date(-90),homeTodayEnd:date(1),listino:company===101?1:10,ksRcEnabled:0,ksHasVatOverride:0,ksVatOverride:0,closedState:3};
 const scores=run(q.activity,p),score=id=>scores.find(r=>r.ArticoliId===n+id)?.CommercialScore||0;
 check(company+' order 10 / discharge 10 = 10',score(1)===10);check(company+' partial 4 does not add to order 10',score(2)===10);check(company+' direct discharge = 5',score(3)===5);check(company+' simultaneous flags count once',score(4)===7);check(company+' input, credit, cancelled, nonmoving excluded',score(5)===0);check(company+' variants aggregate before maximum',score(6)===10);check(company+' rolling dates, null/future, nonpositive quantities',score(7)===2);check(company+' independent flows deliberately use max not sum',score(8)===5);check(company+' disabled state excluded',score(9)===0);
 const rank=run(q.rank,p),fresh=run(q.fresh,p),incoming=run(q.incoming,p);
 check(company+' ranked article identity, order, Vetrina, stock, company and listino',JSON.stringify(rank.map(r=>r.id))===JSON.stringify([6,2,1,4,3,8,7].map(id=>n+id)));
 check(company+' variants do not crowd out later articles',new Set(rank.map(r=>r.id)).size===rank.length);
 check(company+' real new products only, without incoming duplicates',fresh.length===1&&fresh[0].id===n+92);
 check(company+' incoming stock zero and positive retain authoritative amounts',incoming.length===3&&incoming.some(r=>r.id===n+90&&r.Giacenza===0&&r.InOrdine===5));
 fixtures.push({name:company===101?'Tech':'Food',company,listino:p.listino,rank,fresh,incoming});
}
check('unresolved company fails closed',run(q.activity,{commercialCompany:0,commercialStart:start(),commercialEnd:date(1)}).length===0);
fs.writeFileSync(path.join(dir,'sql-report.json'),JSON.stringify({backend:'SQLite in-memory; actual emitted SQL, GREATEST/CURDATE/YEAR compatibility functions; NOT MySQL certification',checks},null,2));fs.writeFileSync(path.join(dir,'fixtures.json'),JSON.stringify(fixtures,null,2));db.close();process.stdout.write('HOME_MERCH_SQL '+checks.length+'/'+checks.length+' PASS\n');
'@
 [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'sql-fixture.cjs'),$nodeScript,$utf8)
 & $node (Join-Path $EvidenceDirectory 'sql-fixture.cjs') $EvidenceDirectory
 if($LASTEXITCODE -ne 0){throw 'HOME_MERCH_SQL_FIXTURE_FAILED'}
 $sqlReport=Get-Content (Join-Path $EvidenceDirectory 'sql-report.json') -Raw|ConvertFrom-Json
 foreach($c in $sqlReport.checks){$checks.Add($c)}
 function Rows($items){$t=$new.Table();foreach($item in @($items)){$r=$t.NewRow();foreach($col in $t.Columns){$value=$item.($col.ColumnName);if($null -eq $value){continue};if($col.DataType -eq [DateTime]){$r[$col.ColumnName]=[DateTime]::Parse([string]$value,[Globalization.CultureInfo]::InvariantCulture)}else{$r[$col.ColumnName]=[Convert]::ChangeType($value,$col.DataType,[Globalization.CultureInfo]::InvariantCulture)}};$t.Rows.Add($r)};return ,$t}
 $fixtures=Get-Content (Join-Path $EvidenceDirectory 'fixtures.json') -Raw|ConvertFrom-Json
 $browserFixtures=New-Object 'Collections.Generic.List[object]'
 foreach($f in $fixtures){
  $new.Configure($f.company,$f.listino,$false,$true);$old.Configure($f.company,$f.listino,$false,$true)
  $rank=$new.Ranked((Rows $f.rank));$arrivals=$new.Arrivals((Rows $f.fresh),(Rows $f.incoming))
  Check ($f.name+' arrival buckets alternate and contain unique articles') (($arrivals.Rows|ForEach-Object{$_['HomeMerchandisingLabel']}) -join ',' -ceq 'Novità,In arrivo,In arrivo,In arrivo')
  $zero=@($arrivals.Rows|Where-Object{$_['Giacenza'] -le 0})[0];$zeroHtml=$new.Card($zero)
  Check ($f.name+' incoming zero stock is informational: no buy/quickview/compare payload') (!$zeroHtml.Contains('js-ks-cart-link') -and !$zeroHtml.Contains('js-ks-quickview') -and !$zeroHtml.Contains('ksCartAction') -and $zeroHtml.Contains('In arrivo') -and $zeroHtml.Contains('articolo.aspx?id='))
  $reserved=@($arrivals.Rows|Where-Object{$_['Giacenza'] -gt 0 -and $_['Impegnata'] -ge $_['Giacenza']})[0]
  Check ($f.name+' incoming reserved stock also uses the canonical availability guard') (!$new.Card($reserved).Contains('js-ks-cart-link') -and $reserved['HomeInformativeOnly'])
  $positive=@($arrivals.Rows|Where-Object{$_['Giacenza'] -gt 0})[0]
  $withoutBadge=[regex]::Replace($new.Card($positive),"<span class='badge bg-light text-dark mb-8'>.*?</span>",'')
  Check ($f.name+' existing positive-stock prices/IVA/promo/stock/images/CTA markup unchanged') ((Stable $withoutBadge) -ceq (Stable ($old.Card($positive))))
  $new.Configure($f.company,$f.listino,$true,$false);$old.Configure($f.company,$f.listino,$true,$false)
  $withoutBadge=[regex]::Replace($new.Card($positive),"<span class='badge bg-light text-dark mb-8'>.*?</span>",'')
  Check ($f.name+' authenticated VAT-excluded renderer parity') ((Stable $withoutBadge) -ceq (Stable ($old.Card($positive))))
  $new.Configure($f.company,$f.listino,$false,$true)
  $rankHtml=($rank.Rows|ForEach-Object{"<div class='swiper-slide'>"+$new.Card($_)+"</div>"}) -join ''
  $arrivalsHtml=($arrivals.Rows|ForEach-Object{$new.Card($_)}) -join ''
  Check ($f.name+' no public score or numeric sales metadata') (($rankHtml+$arrivalsHtml) -notmatch 'CommercialScore|LastCommercialActivity|data-ks-sold|VendutiAnno|QtaVenduta')
  $browserFixtures.Add([pscustomobject]@{Name=$f.name;RankHtml=$rankHtml;ArrivalsHtml=$arrivalsHtml;RankCount=$rank.Rows.Count;ArrivalsCount=$arrivals.Rows.Count})
 }
 Check 'empty signal pools yield sections with zero rows' ($new.Arrivals($new.Table(),$new.Table()).Rows.Count -eq 0 -and $new.Ranked($new.Table()).Rows.Count -eq 0)
 $critical=@('articoli.aspx','articoli.aspx.vb','articolo.aspx','articolo.aspx.vb','App_Code/AvailabilityDisplayHelper.vb','App_Code/StorefrontEffectivePriceSqlBuilder.vb','App_Code/CartStorefrontScopePolicy.vb','Public/assets/keepstore/js/keepstore-product.js')
 $unchanged=$true;foreach($p in $critical){$before=(git -C $RepositoryRoot show ('77a9e71ede510fbdf3908ee18a29b3ca56a9dd5a:'+$p)) -join "`n";$after=([IO.File]::ReadAllText((Join-Path $RepositoryRoot $p))).Replace("`r",'').TrimEnd([char[]]"`n");if($before.TrimEnd([char[]]"`n") -cne $after){$unchanged=$false}}
 Check 'catalog/PDP/commercial helpers/cart scope/product JS untouched' $unchanged
 Write-Json 'browser-fixtures.json' $browserFixtures
 Write-Json 'test-report.json' ([ordered]@{Result='PASS';Checks=$checks.Count;Backend=$sqlReport.backend;Compiled='real VB methods and baseline renderer';OperationalDatabaseAccess=$false;ChecksDetail=$checks})
 Write-Output ('HOME_MERCH '+$checks.Count+'/'+$checks.Count+' PASS')
}finally{
 if($compiler){$compiler.Dispose()}
 if((Test-Path -LiteralPath $work) -and $work.StartsWith($tempRoot+'\ks-home-merch-compile-',[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath $work -Recurse -Force}
}
