[CmdletBinding()]
param([string]$RepositoryRoot, [Parameter(Mandatory=$true)][string]$EvidenceDirectory, [switch]$BrowserOnly, [string]$ReuseBrowserFixtures)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'HOME_DISCOVERY_REQUIRES_PS51' }
if (!$RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\')
if (!$EvidenceDirectory.StartsWith($tempRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)) { throw 'HOME_DISCOVERY_INVALID_OUTPUT' }
$node = (Get-Command node -ErrorAction Stop).Source
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$checks = New-Object 'Collections.Generic.List[object]'
$baselineRef='d509ef15b4abd681739d894f1ac2a9ed4b22e843'
function Check([string]$name, [bool]$ok) { $checks.Add([pscustomobject]@{Name=$name;Pass=$ok}); if (!$ok) { throw ('HOME_DISCOVERY_ASSERT: '+$name) } }
function Write-Json([string]$name, $value) { [IO.File]::WriteAllText((Join-Path $EvidenceDirectory $name),($value|ConvertTo-Json -Depth 16),$utf8) }
function Methods([string]$text) {
    $map=@{}
    foreach ($m in [regex]::Matches($text,'(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) (\w+)\b.*?^    End (?:Function|Sub)')) {
        $n=$m.Groups[1].Value; if (!$map.ContainsKey($n)) { $map[$n]=@() }; $map[$n]+=$m.Value
    }
    return $map
}
function Stable([string]$html) { [regex]::Replace($html,'(?i)(requestId=|data-ks-request-id='')[a-f0-9]{32}','$1FIXTURE_REQUEST_ID') }
function Write-BrowserQa([string]$markup, $browser) {
    $discoveryStyle=[regex]::Match($markup,'(?s)<style id="ksHomeCatalogDiscoveryStyles">(.*?)</style>').Value
    $css=[regex]::Replace(($discoveryStyle -replace '(?s)^<style[^>]*>|</style>$',''),'/\*.*?\*/','')
    $selectors=@([regex]::Matches($css,'([^{}]+)\{[^{}]*\}')|ForEach-Object{$_.Groups[1].Value -split ','})
    Check 'discovery CSS selectors remain scoped to the new section' ($selectors.Count -gt 0 -and @($selectors|Where-Object{!$_.Contains('.ks-home-catalog-discovery')}).Count -eq 0)
    Check 'discovery CSS marker belongs only to the new section' ([regex]::Matches($markup,'class="[^"]*\bks-home-catalog-discovery\b[^"]*"').Count -eq 1 -and $markup -match '<section id="HomeCatalogDiscoverySection"[^>]*\bks-home-catalog-discovery\b')
    $baselineMarkup=(git -C $RepositoryRoot show ($baselineRef+':Default.aspx')) -join [Environment]::NewLine
    if($LASTEXITCODE -ne 0){throw 'HOME_DISCOVERY_BASE_MARKUP_UNAVAILABLE'}
    $unaffected=[regex]::Replace($markup,'(?s)<asp:Content ID="cntDiscoveryHead".*?</asp:Content>','')
    $unaffected=[regex]::Replace($unaffected,'(?s)<section id="HomeCatalogDiscoverySection".*?</section>','')
    Check 'existing HOME markup remains unchanged outside discovery and scoped head styles' (($unaffected -replace '\s+',' ').Trim() -ceq ($baselineMarkup -replace '\s+',' ').Trim())
    # Emit a self-contained QA runner. Its child viewports load only repository styles/local assets.
    # No application JS, token, network endpoint or operational form transport is installed.
    $master=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Page.master'))
    $headEnd=$master.IndexOf('</head>')
    $headSlot=$master.IndexOf('<asp:ContentPlaceHolder ID="HeadContent"')
    Check 'fixture follows the real master HeadContent and stylesheet order' ($headSlot -ge 0 -and $headEnd -gt $headSlot)
    function StyleLinks([string]$part) {
        ([regex]::Matches($part,'ThemeManager\.Asset\("([^"]+\.css)"\)')|ForEach-Object {
            '<link rel="stylesheet" href="'+([Uri](Join-Path $RepositoryRoot ('Public/assets/keepstore/'+$_.Groups[1].Value))).AbsoluteUri+'">'
        }) -join ''
    }
    $links=StyleLinks $master.Substring(0,$headSlot)
    $trailingLinks=StyleLinks $master.Substring($headSlot,$headEnd-$headSlot)
    $section=[regex]::Match($markup,'(?s)<section id="HomeCatalogDiscoverySection".*?</section>').Value
    $browserPages=@(foreach($f in $browser){
        $cards=$f.Html
        $fragment=[regex]::Replace($section,'(?s)<asp:Repeater\b.*?</asp:Repeater>',[Text.RegularExpressions.MatchEvaluator]{param($m) return $cards})
        $fragment=$fragment.Replace(' runat="server"','').Replace(' visible="false"','')
        $assetBase=([Uri]($RepositoryRoot+'\')).AbsoluteUri.TrimEnd('/')
        $fragment=$fragment.Replace('/Public/assets/',$assetBase+'/Public/assets/')
        [pscustomobject]@{Name=$f.Name;Html=('<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+$links+$discoveryStyle+$trailingLinks+'</head><body class="ks-page-home"><main id="ksHomePage" class="ks-home-main">'+$fragment+'</main><form id="ksNativeCartForm" method="post" action="about:blank"></form></body></html>')}
    })
    $runner=@'
<!doctype html><html lang="it"><head><meta charset="utf-8"><title>HOME catalog discovery - offline Chrome QA</title><style>body{margin:0;font:14px Arial;background:#e8edf2}header{padding:10px;background:#fff;position:sticky;top:0;z-index:2}iframe{border:0;background:#fff;display:block;height:950px}#frames{padding:0}.offscreen{position:absolute;left:-100000px;top:0}pre{white-space:pre-wrap;font-size:12px}a{margin-right:12px}</style></head><body><header><b>HOME-CATALOG-DISCOVERY-1A - fixture offline</b><div id="nav"></div><details><summary id="status">Chrome QA in corso</summary><pre id="report"></pre></details></header><div id="frames"></div><script>
const fixtures=FIXTURES_JSON,widths=[360,390,430,768,1365],results=[],frames=[];
const params=new URLSearchParams(location.search);let chosen=params.get('tenant')||'Tech',chosenWidth=Number(params.get('width')||390);
for(const f of fixtures){for(const width of widths){const frame=document.createElement('iframe');frame.width=width;frame.dataset.name=f.Name;frame.dataset.width=width;frame.title=f.Name+' '+width+' CSS px';frame.srcdoc=f.Html;if(f.Name!==chosen||width!==chosenWidth)frame.className='offscreen';document.getElementById('frames').append(frame);frames.push(frame)}const link=document.createElement('button');link.type='button';link.textContent=f.Name;link.addEventListener('click',()=>{chosen=f.Name;showSelection()});document.getElementById('nav').append(link)}
for(const width of widths){const a=document.createElement('button');a.type='button';a.textContent=width+'px';a.addEventListener('click',()=>{chosenWidth=width;showSelection()});document.getElementById('nav').append(a)}
function showSelection(){for(const f of frames)f.className=f.dataset.name===chosen&&Number(f.dataset.width)===chosenWidth?'':'offscreen';document.body.dataset.selected=chosen+' '+chosenWidth}
function check(name,pass,detail){if(params.get('gate')==='failed'&&!(name.endsWith('catalog touch target')||(name.includes('1365 CSS px')&&name.endsWith('buy target and focus'))))return;results.push({name,pass:!!pass,detail})}
window.addEventListener('load',async()=>{try{for(const frame of frames){const d=frame.contentDocument,w=frame.contentWindow;await d.fonts.ready;const label=frame.title,cards=[...d.querySelectorAll('.card-product')],buy=[...d.querySelectorAll('.js-ks-cart-link')],catalog=d.querySelector('.flat-title a');check(label+' exact child viewport',w.innerWidth===Number(frame.dataset.width),w.innerWidth);check(label+' eight rendered cards',cards.length===8,cards.length);check(label+' no horizontal overflow',d.documentElement.scrollWidth<=w.innerWidth+1,{scroll:d.documentElement.scrollWidth,viewport:w.innerWidth});check(label+' neutral title and catalog link',d.querySelector('h5')?.textContent==='Dal nostro catalogo'&&catalog?.getAttribute('href')==='articoli.aspx');const r=catalog.getBoundingClientRect();check(label+' catalog touch target',r.height>=44&&r.width>=44,{height:r.height,width:r.width});catalog.focus();check(label+' catalog focusable',d.activeElement===catalog);check(label+' native form and identity',buy.length===8&&buy.every(b=>b.form?.method==='post'&&b.value.includes('qty=1')&&b.value.includes('tcid=-1')));const b=buy[0],br=b.getBoundingClientRect();b.focus();check(label+' buy target and focus',br.width>=24&&br.height>=24&&d.activeElement===b,{width:br.width,height:br.height});check(label+' placeholder loaded',Array.from(d.images).every(i=>i.complete&&i.naturalWidth>0));check(label+' long title retained',d.querySelector('.ks-card-title')?.textContent.length>80);check(label+' static native path works with no child scripts',d.scripts.length===0&&buy.every(b=>b.getAttribute('form')==='ksNativeCartForm'));}document.getElementById('status').textContent=results.every(r=>r.pass)?'PASS '+results.length+'/'+results.length:'FAIL '+results.filter(r=>!r.pass).length+'/'+results.length;document.getElementById('report').textContent=JSON.stringify({result:results.every(r=>r.pass)?'PASS':'FAIL',browser:navigator.userAgent,limits:'Offline child CSS viewports; not physical devices, full page, IIS or MySQL. Native form transport is synthetic.',checks:results},null,2);document.body.dataset.qaResult=results.every(r=>r.pass)?'PASS':'FAIL';}catch(e){document.getElementById('status').textContent='ERROR '+e.message;document.getElementById('report').textContent=e.stack}});
</script></body></html>
'@
    $runner=$runner.Replace('FIXTURES_JSON',($browserPages|ConvertTo-Json -Depth 4 -Compress))
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'chrome-qa.html'),$runner,$utf8)
}

New-Item -ItemType Directory -Path $EvidenceDirectory | Out-Null
if($BrowserOnly){
    $reuse=[IO.Path]::GetFullPath($ReuseBrowserFixtures)
    if(!$reuse.StartsWith($tempRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or !(Test-Path -LiteralPath $reuse -PathType Leaf)){throw 'HOME_DISCOVERY_REUSE_FIXTURE_INVALID'}
    $loaded=Get-Content -LiteralPath $reuse -Raw|ConvertFrom-Json
    $browser=@($loaded)
    if($browser.Count -ne 2 -or (@($browser.Name|Sort-Object) -join ',') -ne 'Food,Tech'){throw 'HOME_DISCOVERY_REUSE_TENANTS_INVALID'}
    $markup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx'))
    Write-BrowserQa $markup $browser
    Write-Json 'markup-report.json' @{Result='PASS';Checks=$checks.Count;ChecksDetail=$checks;ReusedBrowserFixtures=$reuse;SqlAndVbTestsRerun=$false}
    Write-Output ('HOME_DISCOVERY_MARKUP_PASS checks='+$checks.Count+'; fixture cards reused; SQL/VB suite not rerun')
    exit 0
}
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName Microsoft.VisualBasic
# Explicit offline hosting boundary: reflect the real local placeholder's presence in its request cache.
$request=New-Object System.Web.HttpRequest('','http://fixture.invalid/Default.aspx','')
$response=New-Object System.Web.HttpResponse((New-Object IO.StringWriter))
[System.Web.HttpContext]::Current=New-Object System.Web.HttpContext($request,$response)
[System.Web.HttpContext]::Current.Items['ks_product_placeholder_exists']=[IO.File]::Exists((Join-Path $RepositoryRoot 'Public/assets/images/img/placeholder.svg'))
$source=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx.vb'))
$base=(git -C $RepositoryRoot show ($baselineRef+':Default.aspx.vb')) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) { throw 'HOME_DISCOVERY_BASE_UNAVAILABLE' }
$map=Methods $source; $oldMap=Methods $base
$cart=Methods ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CartMutationIdempotencyService.vb')))
$cartCode="Imports System`nImports System.Globalization`nImports System.Web`nPublic Class CartMutationIdempotencyService`n"+((@('CreateRequestId','BuildNativeActionValue','NormalizeTCId')|ForEach-Object{$cart[$_]}) -join [Environment]::NewLine)+"`nEnd Class"
$shared=@('StorefrontPriceDisplayContext.vb','UiPriceFormatter.vb','AvailabilityDisplayHelper.vb','ThemeManager.vb','UiData.vb','StorefrontEffectivePriceSqlBuilder.vb')|ForEach-Object{[IO.File]::ReadAllText((Join-Path $RepositoryRoot ('App_Code/'+$_)))}
$inventory=Methods ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/OrderInventoryAvailabilityService.vb')))
$shared+=('Imports System'+[Environment]::NewLine+'Public Class OrderInventoryAvailabilityService'+[Environment]::NewLine+$inventory.CalculateNetAvailableQuantity[0]+[Environment]::NewLine+'End Class')
$compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
try {
    function Compile-Home($methods, [string]$name, [bool]$candidate) {
        $names=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $queue=New-Object 'Collections.Generic.Queue[string]'
        @('RenderGridCard','EmptyProductsTable','GetCatalogFallbackPool','GetNewArrivalsPool','GetIncomingPool','GetBestSellerPool','ReservedWhereClause','AvailabilityWhereClause','BuildHomeCommercialActivitySql')|ForEach-Object{$queue.Enqueue($_)}
        if ($candidate) { $queue.Enqueue('LoadHomeCatalogDiscovery') }
        while ($queue.Count) {
            $n=$queue.Dequeue(); if (!$names.Add($n)) { continue }
            if (!$methods.ContainsKey($n)) { throw ('HOME_DISCOVERY_MISSING_METHOD: '+$n) }
            if ($n -eq 'TryLoadProducts') { continue }
            foreach ($body in $methods[$n]) { foreach ($call in [regex]::Matches($body,'\b(\w+)\s*\(')) {
                $d=$call.Groups[1].Value; if ($methods.ContainsKey($d) -and !$names.Contains($d)) { $queue.Enqueue($d) }
            } }
        }
        $bodies=foreach ($n in $names) {
            if ($n -eq 'TryLoadProducts') {
                $loader=$methods[$n][0]; $boundary=$loader.IndexOf('        Try'+[Environment]::NewLine)
                if ($boundary -lt 0) { throw 'HOME_DISCOVERY_SQL_BOUNDARY_MISSING' }
                # Compile the real SQL builder. Replace only connection/adapter I/O; no DB is opened.
                $loader.Substring(0,$boundary)+"        LastSql=sql.ToString()`n        SqlReads+=1`n        If FailRead Then Return Nothing`n        Return If(FixtureRows,EmptyProductsTable())`n    End Function"
            } else { $methods[$n] }
        }
        $wrapper=@'
    Private ReadOnly ItCulture As CultureInfo=CultureInfo.GetCultureInfo("it-IT")
    Private _priceDisplayContext As StorefrontPriceDisplayContext
    Public LastSql As String
    Public SqlReads As Integer
    Public FailRead As Boolean
    Public FixtureRows As DataTable
    Public Sub Configure(company As Integer, listino As Integer, authenticated As Boolean, included As Boolean)
        _priceDisplayContext=New StorefrontPriceDisplayContext(company,listino,authenticated,If(included,StorefrontVatDisplayMode.VatIncluded,StorefrontVatDisplayMode.VatExcluded),Nothing,-1,"",False)
    End Sub
    Public Function Table() As DataTable
        Dim rows As DataTable=EmptyProductsTable()
        If Not rows.Columns.Contains("TCid") Then rows.Columns.Add("TCid",GetType(Integer))
        Return rows
    End Function
    Public Function Card(row As DataRow) As String
        Return RenderGridCard(row.Table.DefaultView(row.Table.Rows.IndexOf(row)))
    End Function
    Public Function Sql(pool As String) As String
        Select Case pool
            Case "catalog" : GetCatalogFallbackPool(8)
            Case "new" : GetNewArrivalsPool(60)
            Case "incoming" : GetIncomingPool(60)
            Case "rank" : GetBestSellerPool(120)
        End Select
        Return LastSql
    End Function
'@
        if ($candidate) { $wrapper+=[Environment]::NewLine+@'
    Public Function Discover(a As DataTable,b As DataTable,c As DataTable,d As DataTable) As DataTable
        Return LoadHomeCatalogDiscovery(a,b,c,d)
    End Function
'@ }
        $code="Imports System`nImports System.Data`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Text`nImports System.Text.RegularExpressions`nImports System.Web`nPublic Class "+$name+[Environment]::NewLine+($bodies -join [Environment]::NewLine)+[Environment]::NewLine+$wrapper+[Environment]::NewLine+'End Class'
        $parameters=New-Object CodeDom.Compiler.CompilerParameters
        $parameters.GenerateInMemory=$true; $parameters.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
        @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll','System.Web.dll','System.Configuration.dll')|ForEach-Object{[void]$parameters.ReferencedAssemblies.Add($_)}
        $compiled=$compiler.CompileAssemblyFromSource($parameters,[string[]](@($code,$cartCode)+$shared))
        if ($compiled.Errors.HasErrors) { throw ('HOME_DISCOVERY_COMPILE: '+(($compiled.Errors|Where-Object{!$_.IsWarning}|ForEach-Object{'line '+$_.Line+': '+$_.ErrorText}) -join '; ')) }
        return [Activator]::CreateInstance($compiled.CompiledAssembly.GetType($name,$true))
    }
    $new=Compile-Home $map 'CandidateHomeDiscovery' $true; $old=Compile-Home $oldMap 'BaselineHomeDiscovery' $false
    $new.Configure(101,1,$false,$true); $old.Configure(101,1,$false,$true)
    Check 'baseline source identifies first-visit gap; no live defect claimed' ($oldMap.BindHome[0] -notmatch 'GetCatalogFallbackPool|LoadHomeCatalogDiscovery')
    foreach ($pool in @('new','incoming','rank')) { Check ($pool+' SQL byte-equivalent to stable') ($new.Sql($pool) -ceq $old.Sql($pool)) }
    Write-Json 'queries.json' @{Candidate=$new.Sql('catalog');Baseline=$old.Sql('catalog')}
    $table=$new.Table()
    $schema=@($table.Columns|ForEach-Object{[pscustomobject]@{name=$_.ColumnName;type=$(if($_.DataType -eq [string] -or $_.DataType -eq [DateTime]){'TEXT'}else{'NUMERIC'})}})+@([pscustomobject]@{name='NListino';type='NUMERIC'})
    Write-Json 'schema.json' $schema
    $sqlScript=@'
const fs=require('node:fs'),path=require('node:path'),{DatabaseSync}=require('node:sqlite');
const dir=process.argv[2],q=JSON.parse(fs.readFileSync(path.join(dir,'queries.json'),'utf8')),schema=JSON.parse(fs.readFileSync(path.join(dir,'schema.json'),'utf8'));
const db=new DatabaseSync(':memory:'),checks=[],fixtures=[];
function check(name,ok){checks.push({Name:name,Pass:!!ok});if(!ok)throw Error('HOME_DISCOVERY_SQL_ASSERT: '+name)}
db.function('GREATEST',(a,b)=>Math.max(a,b));db.function('CURDATE',()=>'2026-10-23');
db.exec('CREATE TABLE vsuperarticoli('+schema.map(c=>'"'+c.name+'" '+c.type).join(',')+');CREATE TABLE articoli(id INTEGER PRIMARY KEY,Abilitato INTEGER);CREATE TABLE articoli_giacenze(ArticoliId INTEGER,TCId INTEGER,MagazziniId INTEGER,Giacenza NUMERIC,Disponibilita NUMERIC,Impegnata NUMERIC)');
const cols=schema.map(c=>c.name),insert=db.prepare('INSERT INTO vsuperarticoli('+cols.join(',')+') VALUES('+cols.map(()=>'?').join(',')+')'),stock=db.prepare('INSERT INTO articoli_giacenze VALUES(?,?,?,?,?,?)');
function product(id,over={},inventory=true,wh=1){const r={id,TCid:-1,NListino:1,Codice:'SKU'+id,Descrizione1:'Prodotto '+id,Descrizione2:'',DescrizioneLunga:'',Img1:'fixture.svg',Img2:'',Img3:'',Img4:'',Abilitato:1,Vetrina:1,DataCreazione:'2025-01-01',Visite:0,Giacenza:5,Disponibilita:999,Impegnata:0,Prezzo:10,PrezzoIvato:12.2,InOrdine:0,DisplayPromoSnapshotReady:1,...over};db.prepare('INSERT OR IGNORE INTO articoli VALUES(?,?)').run(id,r.Abilitato);insert.run(...cols.map(c=>r[c]??null));if(inventory)stock.run(id,r.TCid,wh,r.Giacenza,r.Disponibilita,r.Impegnata)}
function run(sql,listino=1){const values={listino,ksRcEnabled:0,ksHasVatOverride:0,ksVatOverride:0};return db.prepare(sql).all(Object.fromEntries([...new Set(sql.match(/@[A-Za-z][A-Za-z0-9]*/g)||[])].map(k=>[k.slice(1),values[k.slice(1)]])))}
function reset(){db.exec('DELETE FROM vsuperarticoli;DELETE FROM articoli;DELETE FROM articoli_giacenze')}
for(const sector of ['Tech','Food'])for(const count of [1,2,8,12]){reset();for(let n=1;n<=count;n++)product(n,{Descrizione1:sector==='Tech'?'Computer professionale con descrizione molto lunga per controllare la leggibilita e la scheda prodotto':'Prodotto alimentare con descrizione molto lunga e dettagli del formato confezione',Descrizione2:sector+' '+n,Img1:n===1?null:'fixture.svg',Prezzo:sector==='Tech'?100:20,PrezzoIvato:sector==='Tech'?122:24.4});const rows=run(q.Candidate);check(sector+' '+count+' cap and article uniqueness',rows.length===Math.min(count,8)&&new Set(rows.map(r=>r.id)).size===rows.length);check(sector+' '+count+' deterministic order',rows.map(r=>r.id).join(',')===Array.from({length:Math.min(count,8)},(_,i)=>count-i).join(','));if(count<=8)check(sector+' '+count+' image absent remains eligible',rows.some(r=>r.id===1));if(count===8)fixtures.push({name:sector,company:sector==='Tech'?101:202,listino:1,rows})}
reset();product(1,{Giacenza:1,Impegnata:1});check('reserved stock excluded despite misleading Disponibilita',run(q.Candidate).length===0);check('baseline dormant pool would admit reserved stock',run(q.Baseline).length===1);
reset();product(1,{Giacenza:1.5,Impegnata:0.6});check('net fractional remainder below initial unit excluded',run(q.Candidate).length===0);
reset();product(1,{Giacenza:2.5,Impegnata:1.5});check('net exactly initial unit qualifies',run(q.Candidate)[0]?.Disponibilita===1);
reset();product(1,{Giacenza:9},true,2);check('other warehouse never lends stock',run(q.Candidate).length===0);
reset();product(1,{},false);check('missing web warehouse row fails closed without view fallback',run(q.Candidate).length===0);
reset();product(1,{TCid:2,Giacenza:0});stock.run(1,3,1,20,20,0);check('another variant never lends stock',run(q.Candidate).length===0);
reset();product(1);stock.run(1,-1,1,5,5,0);check('ambiguous duplicate stock identity fails closed',run(q.Candidate).length===0);
for(const tc of [0,-2]){reset();product(1,{TCid:tc});check('unsupported TCId '+tc+' excluded before renderer normalization',run(q.Candidate).length===0)}
reset();for(let tc=1;tc<=40;tc++)product(100,{TCid:tc,Giacenza:tc===1?0:5});for(let id=1;id<=9;id++)product(id);let rows=run(q.Candidate);check('eligible variant chosen after net filter but before LIMIT eight',rows.length===8&&rows[0].id===100&&rows[0].TCid===2&&new Set(rows.map(r=>r.id)).size===8);check('repeated selection stable',JSON.stringify(rows)===JSON.stringify(run(q.Candidate)));
for(const [label,over] of [['disabled',{Abilitato:0}],['Vetrina zero',{Vetrina:0}],['Vetrina null',{Vetrina:null}],['foreign listino',{NListino:99}],['zero price',{Prezzo:0,PrezzoIvato:0}],['negative price',{Prezzo:-1,PrezzoIvato:-1}],['null stock',{Giacenza:null,Impegnata:null}],['negative net',{Giacenza:1,Impegnata:5}]]){reset();product(1,over);check(label+' excluded',run(q.Candidate).length===0)}
reset();product(1,{NListino:1,Prezzo:100,PrezzoIvato:122});product(1,{NListino:10,Prezzo:200,PrezzoIvato:244},false);for(const listino of [1,10,1])check('alternating authoritative listino '+listino,run(q.Candidate,listino)[0]?.Prezzo===(listino===1?100:200));
reset();check('empty catalog produces zero cards',run(q.Candidate).length===0);
fs.writeFileSync(path.join(dir,'sql-report.json'),JSON.stringify({Result:'PASS',Checks:checks.length,ChecksDetail:checks,Backend:'SQLite in memory; actual VB-emitted SQL, not MySQL certification'},null,2));fs.writeFileSync(path.join(dir,'fixtures.json'),JSON.stringify(fixtures,null,2));
'@
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'sql-fixture.cjs'),$sqlScript,$utf8)
    & $node (Join-Path $EvidenceDirectory 'sql-fixture.cjs') $EvidenceDirectory
    if ($LASTEXITCODE -ne 0) { throw 'HOME_DISCOVERY_SQL_FAILED' }
    $sqlReport=Get-Content (Join-Path $EvidenceDirectory 'sql-report.json') -Raw|ConvertFrom-Json
    foreach ($c in $sqlReport.ChecksDetail) { Check $c.Name $c.Pass }
    function Rows($items) {
        $t=$new.Table()
        foreach ($item in @($items)) { $r=$t.NewRow(); foreach ($col in $t.Columns) {
            $value=$item.($col.ColumnName); if ($null -eq $value) { continue }
            if ($col.DataType -eq [DateTime]) { $r[$col.ColumnName]=[DateTime]::Parse([string]$value,[Globalization.CultureInfo]::InvariantCulture) }
            else { $r[$col.ColumnName]=[Convert]::ChangeType($value,$col.DataType,[Globalization.CultureInfo]::InvariantCulture) }
        }; $t.Rows.Add($r) }; return ,$t
    }
    $fixtures=Get-Content (Join-Path $EvidenceDirectory 'fixtures.json') -Raw|ConvertFrom-Json
    $browser=New-Object 'Collections.Generic.List[object]'
    foreach ($f in $fixtures) {
        $new.Configure($f.company,$f.listino,$false,$true); $old.Configure($f.company,$f.listino,$false,$true)
        $t=Rows $f.rows; $empty=$new.Table(); $new.FixtureRows=$t
        foreach ($section in 0..3) {
            $args=@($empty,$empty,$empty,$empty); $args[$section]=$t; $before=$new.SqlReads
            Check ($f.name+' selection '+$section+' suppresses discovery and its SQL read') ($new.Discover($args[0],$args[1],$args[2],$args[3]).Rows.Count -eq 0 -and $new.SqlReads -eq $before)
        }
        $before=$new.SqlReads; $discovered=$new.Discover($empty,$empty,$empty,$empty)
        Check ($f.name+' all four empty invokes exactly one pool read') ($discovered.Rows.Count -eq 8 -and $new.SqlReads -eq ($before+1))
        $new.FailRead=$true; $before=$new.SqlReads
        Check ($f.name+' failed external read returns empty section') ($new.Discover($empty,$empty,$empty,$empty).Rows.Count -eq 0 -and $new.SqlReads -eq ($before+1))
        $new.FailRead=$false; $new.FixtureRows=$empty
        Check ($f.name+' zero rows returns empty section') ($new.Discover($empty,$empty,$empty,$empty).Rows.Count -eq 0)
        $new.FixtureRows=$t
        $html=($t.Rows|ForEach-Object{$new.Card($_)}) -join ''
        Check ($f.name+' existing ThemeManager placeholder rendered') ($html -match 'Immagine%20non%20disponibile|placeholder\.svg|Immagine%20prodotto%20non%20disponibile')
        Check ($f.name+' native buy/PDP URLs and initial quantity retained') ($html -match 'cart_add\.aspx\?id=' -and $html -match 'TCid=-1' -and $html -match 'qty=1' -and $html -match 'articolo\.aspx\?id=')
        foreach ($auth in @($false,$true)) { foreach ($included in @($false,$true)) {
            $new.Configure($f.company,$f.listino,$auth,$included); $old.Configure($f.company,$f.listino,$auth,$included)
            Check ($f.name+' renderer parity auth='+$auth+' VATincluded='+$included) ((Stable ($new.Card($t.Rows[0]))) -ceq (Stable ($old.Card($t.Rows[0]))))
        } }
        $new.Configure($f.company,$f.listino,$false,$true)
        $t.Rows[0]['TCid']=7
        Check ($f.name+' positive variant survives native action') ($new.Card($t.Rows[0]) -match 'TCid=7')
        $t.Rows[0]['TCid']=-1
        $browser.Add([pscustomobject]@{Name=$f.name;Count=$t.Rows.Count;Html=$html})
    }
    $markup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx'))
    Check 'neutral section uses existing grid renderer and native catalog link' ($markup -match '(?s)HomeCatalogDiscoverySection.*?Dal nostro catalogo.*?Esplora tutto il catalogo.*?ks-home-product-grid.*?RenderGridCard')
    Check 'snapshot populated before new grid binding' ($map.BindHome[0] -match '(?s)LoadHomeCatalogDiscovery\(dealRows, featuredRows, bestRows, recentRows\).*?PopulatePromotionDisplaySnapshot\(discoveryRows\).*?rptHomeCatalogDiscovery.DataBind')
    Check 'empty section hidden and composition/price note includes discovery' ($map.BindHome[0] -match 'HomeCatalogDiscoverySection.Visible = Not IsTableEmpty\(discoveryRows\)' -and $map.BindHome[0] -match '(?s)HomePriceDisplayNote.Visible =.*?Not IsTableEmpty\(discoveryRows\).*?ApplyHomeComposition\(HomePriceDisplayNote.Visible\)')
    $before=$base; $after=$source
    foreach ($method in @('BindHome','GetCatalogFallbackPool','QueryProducts','TryLoadProducts','LoadHomeCatalogDiscovery')) {
        foreach ($body in @($oldMap[$method])) { if ($body) { $before=$before.Replace($body,'') } }
        foreach ($body in @($map[$method])) { if ($body) { $after=$after.Replace($body,'') } }
    }
    Check 'all other HOME methods unchanged including renderers, snapshots and composition' (($before -replace '\s+',' ').Trim() -ceq ($after -replace '\s+',' ').Trim())
    Write-Json 'browser-fixtures.json' $browser
    Write-BrowserQa $markup $browser
    Write-Json 'test-report.json' @{Result='PASS';Checks=$checks.Count;ChecksDetail=$checks;Baseline=$baselineRef;OperationalDatabaseAccess=$false;ExternalBoundary='Connection/adapter read replaced; production failure contract simulated';Metrics=@{DiscoveryInactivePoolReads=0;DiscoveryActivePoolReads=1;MaximumCards=8;MeasuredMySqlLatency=$false;PromotionResolverCost='Existing snapshot, unchanged; not measured as MySQL queries'}}
    Write-Output ('HOME_CATALOG_DISCOVERY '+$checks.Count+'/'+$checks.Count+' PASS')
} finally { $compiler.Dispose() }
