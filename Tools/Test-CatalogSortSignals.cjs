// Focused SOURCE/System.Web + SQLite/Chrome fixture; no operational database.
const fs=require('fs'),path=require('path'),cp=require('child_process'),assert=require('assert/strict');
const root=path.resolve(__dirname,'..'),dir=process.env.KS_EVIDENCE,base=process.env.KS_BASELINE;
if(!dir||!base||!/^[0-9a-f]{40}$/.test(base))throw Error('Explicit baseline/TEMP evidence required');
if(!path.resolve(dir).startsWith(path.resolve(process.env.TEMP)+path.sep)||fs.existsSync(dir))throw Error('New external TEMP required');
fs.mkdirSync(dir,{recursive:true});
const read=p=>fs.readFileSync(path.join(root,p),'utf8').replace(/\r\n/g,'\n');
const old=p=>cp.execFileSync('git',['show',base+':'+p],{cwd:root,encoding:'utf8',maxBuffer:12e6}).replace(/\r\n/g,'\n');
const checks=[];function check(ok,name){checks.push({name,pass:!!ok});if(!ok){fs.writeFileSync(path.join(dir,'failed-checks.json'),JSON.stringify(checks,null,2));throw Error(name)}}
const match=(s,r)=>{const m=s.match(r);assert(m,r);return m[0]};
const method=(s,n)=>match(s,new RegExp('^ *(?:(?:Private|Public|Protected) )?(?:Shared )?(?:Sub|Function) '+n+'\\b[\\s\\S]*?^ *End (?:Sub|Function)','m'));
const before=old('articoli.aspx.vb'),after=read('articoli.aspx.vb'),oldMarkup=old('articoli.aspx'),markup=read('articoli.aspx');
const oldRecent=' ORDER BY id DESC, PrezzoPromo ASC, PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC';
const recent=' ORDER BY (CatalogCreatedDate IS NULL OR CatalogCreatedDate > CURDATE()) ASC, CatalogCreatedDate DESC, id DESC';
const oldVisits=' ORDER BY visite DESC, PrezzoPromo ASC, PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC';
check(after.replace('vsuperarticoli.DataCreazione AS CatalogCreatedDate, ','').replace(recent,oldRecent).replace(oldVisits+', id DESC',oldVisits)===before,'only approved projection and two sort lines change');
check(markup.replaceAll('Inseriti di recente','Novita').replaceAll('Più visualizzati','Popolarita')===oldMarkup,'only four label texts change in markup');
for(const p of ['Public/assets/keepstore/js/catalog-product-flow.js','App_Code/StorefrontEffectivePriceSqlBuilder.vb'])
 check(read(p)===old(p),p+' unchanged');
const schema=old('Database Taikun/KeepStore.sql');
check(/CREATE TABLE\s+`articoli`\s*\([\s\S]*?`DataCreazione` date/i.test(schema),'article date is DATE in versioned source');
check(/VIEW `vsuperarticoli` AS[^\n]*`articoli`\.`DataCreazione` AS `DataCreazione`/.test(schema),'versioned view exposes original article date');
check(/CREATE PROCEDURE `Modarticoli`[\s\S]*?parDataCreazione DATE[\s\S]*?`DataCreazione` = parDataCreazione/.test(schema),'Modarticoli can rewrite supplied date');
const items=m=>[...m.matchAll(/<asp:ListItem Value="([^"]*)" Text="([^"]*)"/g)].filter(x=>['','P_basso','P_alto','P_offerta','P_disponibilita','P_recenti','P_popolarita','P_codice','P_descrizione'].includes(x[1])).map(x=>({value:x[1],text:x[2]}));
function sortHtml(m){const start=m.indexOf('<div class="tf-control-sort type-sort-by ks-sort-control">');assert(start>=0);let depth=0;for(const x of m.slice(start).matchAll(/<\/?div\b[^>]*>/g)){depth+=x[0].startsWith('</')?-1:1;if(!depth)return m.slice(start,start+x.index+x[0].length)}throw Error('sort container missing')}
const baseItems=items(oldMarkup),newItems=items(markup);
check(baseItems.length===9&&JSON.stringify(baseItems.map(x=>x.value))===JSON.stringify(newItems.map(x=>x.value)),'all nine technical values/indices unchanged');
let vb=`Imports System
Imports System.IO
Imports System.Text
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.Hosting
Imports System.Web.SessionState
Imports System.Web.Script.Serialization
Public Module ThemeManager
${method(read('App_Code/ThemeManager.vb'),'CatalogResultsUrl')}
End Module
`;
for(const [version,s,m]of[['Baseline',before,oldMarkup],['Candidate',after,markup]]){
 const projection=match(s,/^        Dim strSelect As String =\n[\s\S]*?^            BuildCatalogArrivalsJoinSql\(\)/m);
 const sort=match(s,/^        Dim sortSql As String = String.Empty\n[\s\S]*?(?=^        Me.sdsArticoli.SelectCommand =)/m);
 const candidates=match(s,/^        If TC = 1 AndAlso catalogTagliaCandidateSql.Length = 0[\s\S]*?(?=^        Dim sortSql)/m);
 const price=match(s,/^    strSelect = "SELECT " & displayPriceSql.*$/m);
 const normalize=match(s,/^Dim sortValue As String =.*\nIf sortValue.StartsWith.*$/m);
 const options=items(m).map(x=>'Drop_Ordinamento.Items.Add(New ListItem("'+x.text.replaceAll('"','""')+'","'+x.value+'"))').join('\n');
 vb+=`Public Class ${version}Probe
 Inherits Page
 Private WithEvents Drop_Ordinamento As New DropDownList With {.ID="Drop_Ordinamento",.CssClass="ks-toolbar-native-select",.AutoPostBack=True}
 Private sdsArticoli As New SqlDataSource
 Public Target As String
 Public Sub New()
  AppRelativeVirtualPath="~/articoli.aspx"
  Dim bind As Reflection.MethodInfo=GetType(Page).GetMethod("SetIntrinsics",Reflection.BindingFlags.NonPublic Or Reflection.BindingFlags.Instance,Nothing,New Type(){GetType(HttpContext)},Nothing)
  bind.Invoke(Me,New Object(){HttpContext.Current})
  ${options}
 End Sub
 Public Function Queries(value As String,TC As Integer,userCerca As String) As Object
  Drop_Ordinamento.SelectedValue=value
  Dim promotionTcSelect As String="",promotionMainJoin As String=""
  Dim searchScoreSql As String=If(userCerca="","0 AS SearchScore","(100 + COALESCE(vsuperarticoli.visite,0)) AS SearchScore")
  Dim effectiveBaseGrossSql As String=StorefrontEffectivePriceSqlBuilder.BuildEffectiveGrossExpression("vsuperarticoli.Prezzo","vsuperarticoli.PrezzoIvato","vsuperarticoli.IdIvaRC","vsuperarticoli.ValoreIvaRC","?ksRcEnabled","?ksHasVatOverride","?ksVatOverride")
  Dim effectivePromoGrossSql As String=StorefrontEffectivePriceSqlBuilder.BuildEffectiveGrossExpression("vsuperarticoli.PrezzoPromo","vsuperarticoli.PrezzoPromoIvato","vsuperarticoli.IdIvaRC","vsuperarticoli.ValoreIvaRC","?ksRcEnabled","?ksHasVatOverride","?ksVatOverride")
${projection}
  Dim strWhere As String=" AND vsuperarticoli.MarcheId=?BrandId"
  Dim catalogTagliaCandidateSql As String="",catalogColoreCandidateSql As String=""
  Dim displayPriceSql As String="vsuperarticoli.PrezzoIvato",quantityOneJoin As String=""
${normalize}
  If sortValue="p_basso" OrElse sortValue="p_alto" Then
${price}
  End If
${candidates}
${sort}
  Me.sdsArticoli.SelectCommand=BuildCatalogListingSql(strSelect,strWhere,sortSql)
  Return New With {.sql=sdsArticoli.SelectCommand,.projection=strSelect,.whereSql=strWhere,.sort=sortSql,.taglia=catalogTagliaCandidateSql,.colore=catalogColoreCandidateSql,.arrivals=BuildCatalogArrivalsJoinSql()}
 End Function
 Public Function Choose(value As String) As Object
  Drop_Ordinamento.SelectedValue=value:Session("Articoli_PageIndex")=8
  Drop_Ordinamento_SelectedIndexChanged(Me,EventArgs.Empty)
  Dim writer As New StringWriter
  Drop_Ordinamento.RenderControl(New HtmlTextWriter(writer))
  Return New With {.url=Target,.pageIndex=Session("Articoli_PageIndex"),.native=writer.ToString()}
 End Function
 Private Sub RedirectIfChanged(url As String,Optional endResponse As Boolean=True)
  Target=url
 End Sub
${['BuildCatalogRowRankSql','BuildCatalogListingSql','BuildCatalogArrivalsJoinSql','changeUrlDependingFromDropDownList','changeUrlGetParam','GetSafeReturnUrl','Drop_Ordinamento_SelectedIndexChanged'].map(n=>method(s,n)).join('\n')}
End Class
`;
}
vb+=`Public Class Worker
 Inherits SimpleWorkerRequest
 Public Sub New()
  MyBase.New("articoli.aspx","st=2&ct=3&q=fixture&inpromo=1&pid=9&page=2&pg=3&p=4",New StringWriter)
 End Sub
 Public Overrides Function GetServerName() As String
  Return "sort.fixture.invalid"
 End Function
End Class
Public Class Host
 Inherits MarshalByRefObject
 Public Function Run() As String
  Dim result As New List(Of Object)
  For Each version As String In New String(){"Baseline","Candidate"}
   For Each value As String In New String(){"","P_basso","P_alto","P_offerta","P_disponibilita","P_recenti","P_popolarita","P_codice","P_descrizione","search","tc-recent","tc-visits"}
    Dim c As New HttpContext(New Worker):HttpContext.Current=c
    SessionStateUtility.AddHttpSessionStateToContext(c,New HttpSessionStateContainer("fixture",New SessionStateItemCollection,New HttpStaticObjectsCollection,20,True,HttpCookieMode.UseCookies,SessionStateMode.InProc,False))
    Dim sort As String=If(value="search","",If(value="tc-recent","P_recenti",If(value="tc-visits","P_popolarita",value)))
    Dim data As Object,nav As Object
    If version="Baseline" Then
     Dim p As New BaselineProbe
     data=p.Queries(sort,If(value.StartsWith("tc-"),1,0),If(value="search","fixture","")):nav=p.Choose(sort):p.Dispose()
    Else
     Dim p As New CandidateProbe
     data=p.Queries(sort,If(value.StartsWith("tc-"),1,0),If(value="search","fixture","")):nav=p.Choose(sort):p.Dispose()
    End If
    result.Add(New With {.version=version,.key=value,.data=data,.navigation=nav})
   Next
  Next
  Return New JavaScriptSerializer With {.MaxJsonLength=4000000}.Serialize(result)
 End Function
 Public Overrides Function InitializeLifetimeService() As Object
  Return Nothing
 End Function
End Class
`;
vb=vb.replace('Return New JavaScriptSerializer With {.MaxJsonLength=4000000}.Serialize(result)','Dim serializer As New JavaScriptSerializer With {.MaxJsonLength=4000000}\n  Return serializer.Serialize(result)');
fs.writeFileSync(path.join(dir,'SortSignals.vb'),vb);
const ps=`$ErrorActionPreference='Stop'
$d=$env:KS_EVIDENCE;$r=$env:KS_REPO
& "$env:windir\\Microsoft.NET\\Framework64\\v4.0.30319\\vbc.exe" /nologo /target:library /optionstrict+ /out:"$d\\SortSignals.dll" /r:System.dll,System.Core.dll,System.Web.dll,System.Web.Extensions.dll "$r\\App_Code\\StorefrontEffectivePriceSqlBuilder.vb" "$d\\SortSignals.vb"
if($LASTEXITCODE){throw 'COMPILE_FAILED'}
$app=Join-Path $d 'app';[void][IO.Directory]::CreateDirectory((Join-Path $app 'bin'));[void][IO.Directory]::CreateDirectory((Join-Path $app 'cache'))
Copy-Item -LiteralPath (Join-Path $d 'SortSignals.dll') -Destination (Join-Path $app 'bin\\SortSignals.dll')
$cache=[Security.SecurityElement]::Escape((Join-Path $app 'cache'))
[IO.File]::WriteAllText((Join-Path $app 'web.config'),('<configuration><connectionStrings><clear/></connectionStrings><system.web><compilation targetFramework="4.8" tempDirectory="'+$cache+'"/><httpRuntime targetFramework="4.8"/></system.web></configuration>'))
Add-Type -Path (Join-Path $d 'SortSignals.dll')
$h=[System.Web.Hosting.ApplicationHost]::CreateApplicationHost([Host],'/store',($app+'\\'))
try{[IO.File]::WriteAllText((Join-Path $d 'queries.json'),$h.Run(),(New-Object Text.UTF8Encoding($false)))}catch{$e=$_.Exception;while($null-ne$e){Write-Output ($e.GetType().FullName+': '+$e.Message);$e=$e.InnerException};throw}
`;
fs.writeFileSync(path.join(dir,'run.ps1'),ps);
cp.execFileSync('C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe',['-NoProfile','-ExecutionPolicy','RemoteSigned','-File',path.join(dir,'run.ps1')],{env:{...process.env,KS_REPO:root},stdio:'inherit',timeout:90000});
const packets=JSON.parse(fs.readFileSync(path.join(dir,'queries.json'),'utf8'));
const {DatabaseSync}=require('node:sqlite'),db=new DatabaseSync(':memory:');
db.function('CURDATE',()=> '2026-11-11');db.function('IF',(c,a,b)=>c?a:b);db.function('CONCAT',{varargs:true},(...a)=>a.some(v=>v==null)?null:a.join(''));db.function('CONVERT',(v,t)=>v);
const definitions=[[101,'2026-11-10',8,10],[999,'2020-01-01',8,10],[102,'2026-11-11',5,10],[103,'2026-11-11',5,10],[104,'2026-11-12',3,10],[105,null,3,10],[106,'2026-11-09',10,10],[107,'2026-11-08',10,10],[108,'2026-11-07',10,5]];
const variants=[{id:11,ArticoliId:101,TagliaId:1,ColoreId:1},{id:12,ArticoliId:101,TagliaId:2,ColoreId:2}],rows=[];
for(const list of [1,10])for(const [id,date,visits,price]of definitions)for(const tc of id===101?[11,12]:[-1]){
 rows.push({id,DataCreazione:date,visite:visits,TCid:tc,NListino:list,ArticoliListiniId:rows.length+1000,Prezzo:price+(list===10?2:0),PrezzoIvato:(price+(list===10?2:0))*1.22,Codice:'X'+id,Ean:'',Descrizione1:'Articolo '+id,Descrizione2:'',DescrizioneLunga:'',IdIvaRC:-1,ValoreIvaRC:0,Img1:null,Img2:null,Img3:null,Img4:null,MarcheDescrizione:'Fixture',Disponibilita:1,Giacenza:5,InOrdine:0,Impegnata:0,InOfferta:0,SettoriDescrizione:'Fixture',CategorieDescrizione:'Fixture',TipologieDescrizione:'Fixture',GruppiDescrizione:'Fixture',SottogruppiDescrizione:'Fixture',Marche_img:null,PrezzoPromo:null,PrezzoPromoIvato:null,MarcheId:1,CategorieId:3,TipologieId:1,Ricondizionato:0,Vetrina:0,OfferteDettagliId:0});
}
const lit=v=>v==null?'NULL':typeof v==='number'?String(v):"'"+String(v).replaceAll("'","''")+"'";
function table(name,rs){const cols=Object.keys(rs[0]);return name+'('+cols.join(',')+') AS (VALUES '+rs.map(r=>'('+cols.map(k=>lit(r[k])).join(',')+')').join(',')+')'}
const cte='WITH '+[table('vsuperarticoli',rows),table('articoli',definitions.map(r=>({id:r[0],Img5:null,Img6:null}))),table('articoli_tagliecolori',variants),table('taglie',[{id:1,descrizione:'S'},{id:2,descrizione:'M'}]),table('colori',[{id:1,descrizione:'Rosso'},{id:2,descrizione:'Blu'}])].join(',')+' ';
function execute(packet,list=1,key='sql',suffix=''){
 let sql=packet.data[key].replace(packet.data.arrivals,' LEFT JOIN (SELECT NULL AS articoliid,NULL AS arrivi WHERE 0) arrivi ON arrivi.articoliid=vsuperarticoli.id').replace(/,CHAR\)/g,", 'CHAR')").replace(/\?([A-Za-z]\w*)/g,':$1');
 const stmt=db.prepare(cte+sql+suffix);stmt.setAllowUnknownNamedParameters(true);
 return stmt.all({NListino:list,BrandId:1,ksRcEnabled:0,ksHasVatOverride:0,ksVatOverride:null});
}
for(const p of packets.filter(p=>p.version==='Candidate')){
 const b=packets.find(b=>b.version==='Baseline'&&b.key===p.key);
 check(p.navigation.url===b.navigation.url&&p.navigation.pageIndex===0,p.key+' actual handler URL/paging unchanged');
 check(p.data.whereSql===b.data.whereSql,p.key+' WHERE unchanged');
 check((p.data.projection.match(/AS CatalogCreatedDate/g)||[]).length===1,p.key+' qualified date alias unique');
 if(!['P_recenti','P_popolarita','tc-recent','tc-visits'].includes(p.key))
  check(p.data.sql.replace('vsuperarticoli.DataCreazione AS CatalogCreatedDate, ','')===b.data.sql,p.key+' other sort/default/SearchScore SQL unchanged');
 const result=execute(p);
 check(result.length===9&&new Set(result.map(r=>r.id)).size===9,p.key+' wrapper keeps one coherent row per article');
 if(p.key.startsWith('tc-'))for(const key of ['taglia','colore']){
  const candidates=execute(p,1,key);check(candidates.length===10&&candidates.every(r=>'CatalogCreatedDate'in r),p.key+' #433 '+key+' candidates execute without alias collision');
 }
}
const latest=packets.find(p=>p.version==='Candidate'&&p.key==='P_recenti'),popular=packets.find(p=>p.version==='Candidate'&&p.key==='P_popolarita');
for(const list of [1,10]){
 const ids=execute(latest,list).map(r=>r.id),expected=[103,102,101,106,107,108,999,104,105];
 check(JSON.stringify(ids)===JSON.stringify(expected),'list '+list+' real date order, tie, future, NULL');
 const pages=[...execute(latest,list,'sql',' LIMIT 5 OFFSET 0'),...execute(latest,list,'sql',' LIMIT 5 OFFSET 5')].map(r=>r.id);
 check(JSON.stringify(ids)===JSON.stringify(pages),'list '+list+' deterministic order across two pages');
 const p=execute(popular,list).map(r=>r.id);check(p.indexOf(107)<p.indexOf(106)&&p[0]===108,'list '+list+' visits tie ID plus existing price priority retained');
}
const browserStart=checks.length;
async function browserChecks(){
 const {createRequire}=require('module'),req=createRequire(path.join(path.dirname(process.execPath),'../node_modules/entry.cjs')),pw=req('playwright');
 const source=read('Public/assets/keepstore/js/catalog-product-flow.js');
 const start=source.indexOf('  function initializeCatalogSort()'),end=source.indexOf('  // Re-run after UpdatePanel',start);
 const controller=source.slice(start,end);
 const selected={};for(const p of packets.filter(p=>p.version==='Candidate'))selected[p.key]=p.navigation;
 const styles=['bootstrap.min.css','styles.css','keepstore.css','keepstore-overrides.css','ks-ui.css','catalog-ui.css','catalog-filters-ui.css','catalog-product-flow.css','theme-overrides.css'];
 const browser=await pw.chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});const navs=[];
 try{for(const width of [390,1365]){
  const ctx=await browser.newContext({viewport:{width,height:950},offline:true,serviceWorkers:'block'}),page=await ctx.newPage();
  await ctx.route('**/*',route=>{
   const r=route.request(),u=new URL(r.url());if(u.hostname!=='sort.fixture.invalid'||r.method()!=='GET')throw Error('Unexpected I/O');
   if(u.pathname.startsWith('/Public/'))return route.fulfill({body:fs.readFileSync(path.join(root,u.pathname)),contentType:'text/css'});
   navs.push({width,url:u.href,method:r.method()});
   const raw=u.searchParams.get('ordinamento')||'',value=raw.split('|').at(-1),key=selected[value]?value:'';
   const html=sortHtml(markup).replace(/<asp:DropDownList\b[\s\S]*?<\/asp:DropDownList>/,selected[key].native);
   const script='const urls='+JSON.stringify(Object.fromEntries(Object.entries(selected).map(([k,v])=>[k,v.url])))+';window.__doPostBack=function(target){window.lastTarget=target;location.assign(urls[document.getElementById("Drop_Ordinamento").value]);};'+controller+';initializeCatalogSort();';
   return route.fulfill({contentType:'text/html',body:'<!doctype html><meta charset="utf-8">'+styles.map(s=>'<link rel="stylesheet" href="/Public/assets/keepstore/css/'+s+'">').join('')+'<main id="ksCatalogPage"><div class="container"><form>'+html+'</form></div></main><script>'+script+'</script>'});
  });
  await page.goto('http://sort.fixture.invalid/store/articoli.aspx?st=2&ct=3&q=fixture&inpromo=1&pid=9&page=2&pg=3&p=4');
  for(const [value,label]of[['P_recenti','Inseriti di recente'],['P_popolarita','Più visualizzati']]){
   check(await page.locator('#Drop_Ordinamento option[value="'+value+'"]').textContent()===label,width+' native exact label '+value);
   await page.locator('.ks-sort-trigger').click();const option=page.locator('[data-ks-sort-value="'+value+'"]');
   check(await option.textContent()===label,width+' custom exact label '+value);
   await option.click();await page.waitForURL(selected[value].url);
   check(await page.locator('#Drop_Ordinamento').inputValue()===value&&await page.locator('.ks-sort-trigger-value').textContent()===label,width+' native/custom synchronized '+value);
   const u=new URL(page.url());check(u.searchParams.get('ordinamento')===newItems.findIndex(x=>x.value===value)+'|'+value&&u.searchParams.get('q')==='fixture'&&u.searchParams.get('pid')==='9'&&!u.searchParams.has('pg')&&u.hash==='#ksCatalogResults',width+' generated handler GET contract '+value);
  }
  check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),width+' selector no overflow');
  await page.screenshot({path:path.join(dir,'sort-'+width+'.png')});await ctx.close();
 }}finally{await browser.close();db.close()}
 fs.writeFileSync(path.join(dir,'report.json'),JSON.stringify({result:'PASS SOURCE ONLY',checks,sourceSqlChecks:browserStart,browserChecks:checks.length-browserStart,packets:packets.length,navs,sqlAdapter:['SQLite CTE in memory','fixed CURDATE','named parameters and IF/CONCAT/CONVERT functions','exact empty arrivals join replacement'],limits:['No MySQL/IIS, no decimal/dialect/performance certification','Compiled VB query composition/handlers with synthetic context and price-sort expression; not full CaricaArticoli execution','Browser __doPostBack transport replaced by GET to actual compiled handler output; no real WebForms POST']},null,2));
 console.log('SORT_SIGNALS_PASS sourceSql='+browserStart+' browser='+(checks.length-browserStart)+' packets='+packets.length);
}
browserChecks().catch(e=>{console.error(e);process.exitCode=1});
