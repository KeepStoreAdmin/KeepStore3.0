'use strict';
// Four evidence levels: synthetic tenant data, real System.Web lifecycle,
// Chrome on rendered candidate header, and IIS (never exercised here).
const fs=require('fs'),path=require('path'),os=require('os'),cp=require('child_process'),assert=require('assert');
const {chromium}=require('playwright'); // normal Node resolution; NODE_PATH may be set by the runner
const root=path.resolve(__dirname,'..'),work=fs.mkdtempSync(path.join(os.tmpdir(),'ks-mobile-search-qa-'));
const read=p=>fs.readFileSync(path.join(root,p),'utf8');const write=(p,s)=>fs.writeFileSync(path.join(work,p),s);
const header=read('Public/ui/controls/SiteHeader.ascx'),server=read('Public/ui/controls/SiteHeader.ascx.vb'),master=read('Page.master'),masterServer=read('Page.master.vb');
function sub(source,start){const a=source.indexOf(start),b=source.indexOf('\n    End Sub',a);assert(a>=0&&b>a,start);return source.slice(a,b+12);}
const dispatch=sub(server,'    Private Sub DispatchNativeMobileSearch()').replace('        If Not String.Equals(Request.HttpMethod','        TraceEvent("NATIVE_DISPATCH")\n        If Not String.Equals(Request.HttpMethod').replace('        Response.Redirect(target, True)','        TraceEvent("NATIVE_REDIRECT")\n        Response.Redirect(target, True)');
const wiring=sub(masterServer,'    Private Sub WireHeaderEvents()');
const cerca=masterServer.slice(masterServer.indexOf('    Public Sub Cerca()'),masterServer.indexOf("    ' IVA VETTORE DEFAULT")).replace('    Private Sub Cerca(ByVal preferMobile As Boolean)','    Private Sub Cerca(ByVal preferMobile As Boolean)\n        TraceEvent("SEARCH_DISPATCH")').replace('    Protected Sub tbCercaMobile_TextChanged(ByVal sender As Object, ByVal e As System.EventArgs)','    Protected Sub tbCercaMobile_TextChanged(ByVal sender As Object, ByVal e As System.EventArgs)\n        TraceEvent("MOBILE_TEXT_CHANGED")');
const click=sub(masterServer,'    Protected Sub btnSearch_ServerClick(');
const tenants={taikun:{company:1,sector:11,category:111,other:12,title:'Taikun Tech',product:123},webaffare:{company:2,sector:22,category:222,other:23,title:'Webaffare Food',product:456}};
const scope=t=>`articoli.aspx?st=${t.sector}&ct=${t.category}`;
const tenantScope=(t,value)=>assert.equal(value,scope(t),'Tenant scope mismatch');
const styles=Array.from(master.matchAll(/ThemeManager\.Asset\("([^"\n]+\.css)"\)/g),m=>m[1]);
assert.notEqual(scope(tenants.taikun),scope(tenants.webaffare));assert.equal((header.match(/data-ks-search-form="mobile"/g)||[]).length,1);
const native=master.match(/<form id="ksMobileSearchForm"[\s\S]*?<\/form>/)[0].replace('<%= ResolveUrl("~/articoli.aspx") %>','/articoli.aspx');
fs.mkdirSync(path.join(work,'bin'));
write('Gate.vb',`Imports System
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.Hosting
Imports System.Threading
Public Class CaptureWorker
 Inherits SimpleWorkerRequest
 Public Done As New ManualResetEvent(False)
 Public Status As Integer=200
 Public Location As String=""
 Private Verb As String
 Private Payload As Byte()
 Public Sub New(page As String,query As String,verb As String,body As String,output As TextWriter)
  MyBase.New(page,query,output)
  Me.Verb=verb:Payload=Encoding.UTF8.GetBytes(body)
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
Public Class GateHost
 Inherits MarshalByRefObject
 Public Function Run(page As String,query As String,verb As String,body As String) As String()
  Dim output As New StringWriter(),w As New CaptureWorker(page,query,verb,body,output)
  HttpRuntime.ProcessRequest(w)
  If Not w.Done.WaitOne(20000) Then Throw New Exception("PIPELINE_TIMEOUT")
  Return New String(){w.Status.ToString(),w.Location,output.ToString()}
 End Function
End Class`);
write('web.config','<configuration><system.web><compilation targetFramework="4.8"/><httpRuntime targetFramework="4.8"/><customErrors mode="Off"/><trust level="Full"/></system.web></configuration>');
const trace=`Private Sub TraceEvent(value As String)
 System.IO.File.AppendAllText(System.IO.Path.Combine(HttpRuntime.AppDomainAppPath,"events.txt"),value & vbLf)
End Sub`;
write('header.ascx',header.replace(/^<%@[^\n]+\n/,'<%@ Control Language="VB" AutoEventWireup="false" %>\n')+`<script runat="server">
${trace}
Protected Sub FixtureLoad(sender As Object,e As EventArgs) Handles Me.Load
 TraceEvent("HEADER_LOAD")
 If Not IsPostBack Then
  Dim food As Boolean=Request.QueryString("tenant")="webaffare"
  Dim sid As Integer=If(food,22,11),cid As Integer=If(food,222,111),other As Integer=If(food,23,12)
  Dim title As String=If(food,"Webaffare Food","Taikun Tech")
  For Each ddl As DropDownList In New DropDownList(){product_cat,product_cat_mobile}
   ddl.Items.Add(New ListItem("Tutti i settori",""))
   ddl.Items.Add(New ListItem(title,"articoli.aspx?st=" & sid))
   ddl.Items.Add(New ListItem(title & " / Categoria","articoli.aspx?st=" & sid & "&ct=" & cid))
   ddl.Items.Add(New ListItem("Altro " & title,"articoli.aspx?st=" & other))
   ddl.SelectedIndex=2
  Next
  tbCercaMobile.Text="lampada"
  mvLogin.SetActiveView(vwLoginOff)
  imgLogo.ImageUrl="/fixture-logo.svg":imgLogo.AlternateText=title
  imgLogoMobile.ImageUrl="/fixture-logo.svg":imgLogoMobile.AlternateText=title
  imgLogoDrawer.ImageUrl="/fixture-logo.svg":imgLogoDrawer.AlternateText=title
  litSupportPhoneTop.Text=title:litSupportPhoneHeader.Text=title
  TraceEvent("BOUND_COMPANY_" & If(food,"2","1"))
  DispatchNativeMobileSearch()
 End If
End Sub
Protected Sub rptNavSettoriMobile_ItemDataBound(sender As Object,e As RepeaterItemEventArgs)
End Sub
Protected Sub rptNavCategorieMobile_ItemDataBound(sender As Object,e As RepeaterItemEventArgs)
End Sub
Protected Function MobileSectorMediaClass(value As Object) As String
 Return "ks-mobile-sector-media"
End Function
Protected Function RenderMobileSectorImage(value As Object,label As Object) As String
 Return ""
End Function
${dispatch}
</script>`);
write('fixture.master',`<%@ Master Language="VB" %><%@ Register Src="header.ascx" TagPrefix="ks" TagName="Header" %>
<script runat="server">
${trace}
Private _headerEventsWired As Boolean=False
Private Function FindCtrl(Of T As Control)(id As String) As T
 Return TryCast(FindRecursive(Me,id),T)
End Function
Private Function FindRecursive(c As Control,id As String) As Control
 If c.ID=id Then Return c
 For Each child As Control In c.Controls
  Dim found As Control=FindRecursive(child,id)
  If found IsNot Nothing Then Return found
 Next
 Return Nothing
End Function
Protected Sub FixtureInit(sender As Object,e As EventArgs) Handles Me.Init
 WireHeaderEvents()
End Sub
Protected Sub OtherClick(sender As Object,e As EventArgs)
 TraceEvent("UNRELATED_CLICK")
End Sub
Protected Sub FixtureComplete(sender As Object,e As EventArgs) Handles Me.LoadComplete
 TraceEvent("MASTER_PRE_RENDER")
End Sub
${wiring}
${cerca}
${click}
</script><!doctype html><html><head><meta name="viewport" content="width=device-width"/></head><body>
<form id="form1" runat="server"><ks:Header ID="headerUi" runat="server"/><asp:Button ID="unrelated" runat="server" Text="Other" OnClick="OtherClick"/><asp:ContentPlaceHolder ID="Body" runat="server"/></form>${native}</body></html>`);
// MasterPage does not expose LoadComplete: observe that event on the actual Page.
let fixtureMaster=fs.readFileSync(path.join(work,'fixture.master'),'utf8').replace('Handles Me.LoadComplete','Handles Me.PreRender');write('fixture.master',fixtureMaster);
for(const page of ['Default.aspx','articoli.aspx','articolo.aspx','carrello.aspx'])write(page,`<%@ Page Language="VB" MasterPageFile="fixture.master" %><asp:Content ID="content" ContentPlaceHolderID="Body" runat="server"><script runat="server">Protected Sub Done(sender As Object,e As EventArgs) Handles Me.LoadComplete
System.IO.File.AppendAllText(System.IO.Path.Combine(HttpRuntime.AppDomainAppPath,"events.txt"),"PAGE_LOAD_COMPLETE" & vbLf)
End Sub</script><main data-page="${page}">Fixture ${page}</main></asp:Content>`);
write('render.ps1',`param([string]$FixtureRoot)
$ErrorActionPreference='Stop';Add-Type -AssemblyName System.Web;Add-Type -Path (Join-Path $FixtureRoot 'bin/Gate.dll')
$gate=[System.Web.Hosting.ApplicationHost]::CreateApplicationHost([GateHost], '/', ($FixtureRoot+'\\'))
$results=@();$redirects=@();$controls=@()
foreach($tenant in @('taikun','webaffare')){
 $r=$gate.Run('articoli.aspx',('tenant='+$tenant),'GET','')
 if($r[0] -ne '200'){[IO.File]::WriteAllText((Join-Path $FixtureRoot 'compile-failure.html'),$r[2]);throw 'FRAMEWORK_RENDER_FAILED'}
 [IO.File]::WriteAllText((Join-Path $FixtureRoot ('rendered-'+$tenant+'.html')),$r[2])
 foreach($page in @('Default.aspx','articolo.aspx','carrello.aspx')){
  $render=$gate.Run($page,('tenant='+$tenant),'GET','');if($render[0] -ne '200'){throw 'PAGE_WRAPPER_RENDER_FAILED'}
  [IO.File]::WriteAllText((Join-Path $FixtureRoot ('rendered-'+$tenant+'-'+$page+'.html')),$render[2])
 }
 $mobileName=[regex]::Match($r[2],'<input[^>]*name="([^"]*tbCercaMobile)"').Groups[1].Value
 $scopeName=[regex]::Match($r[2],'<select[^>]*name="([^"]*product_cat_mobile)"').Groups[1].Value
 $buttonName=[regex]::Match($r[2],'<input[^>]*name="([^"]*unrelated)"').Groups[1].Value
 if(!$mobileName -or !$scopeName -or !$buttonName){throw 'CONTROL_NAMES_MISSING'}
 $fields=[regex]::Matches($r[2],'<input[^>]*type="hidden"[^>]*>')
 $body=@()
 foreach($f in $fields){$n=[regex]::Match($f.Value,'name="([^"]+)"').Groups[1].Value;$v=[regex]::Match($f.Value,'value="([^"]*)"').Groups[1].Value;if($n){$body+=([Web.HttpUtility]::UrlEncode([Web.HttpUtility]::HtmlDecode($n))+'='+[Web.HttpUtility]::UrlEncode([Web.HttpUtility]::HtmlDecode($v)))}}
 # Only fields associated with form1: ksms belongs to the external GET form.
 $body=@($body|Where-Object{$_ -notmatch '^ksms='});$body+=([Web.HttpUtility]::UrlEncode($buttonName)+'=Other')
 $before=@(Get-Content (Join-Path $FixtureRoot 'events.txt')).Count
 $post=$gate.Run('articoli.aspx',('tenant='+$tenant),'POST',($body -join '&'))
 $events=@([IO.File]::ReadAllLines((Join-Path $FixtureRoot 'events.txt'))|Select-Object -Skip $before|ForEach-Object{$_.ToString()})
 $results+=@{tenant=$tenant;status=$post[0];location=$post[1];events=$events;mobileFieldsAbsent=(($body -join '&') -notmatch 'tbCercaMobile|product_cat_mobile')}
 # Positive instrumentation control: forcibly posting the external field must execute the copied legacy handlers.
 $before=@([IO.File]::ReadAllLines((Join-Path $FixtureRoot 'events.txt'))).Count
 $control=$gate.Run('articoli.aspx',('tenant='+$tenant),'POST',(($body -join '&')+'&'+[Web.HttpUtility]::UrlEncode($mobileName)+'=changed'))
 $controlEvents=@([IO.File]::ReadAllLines((Join-Path $FixtureRoot 'events.txt'))|Select-Object -Skip $before|ForEach-Object{$_.ToString()})
 $controls+=@{tenant=$tenant;status=$control[0];location=$control[1];events=$controlEvents}
 $sid=if($tenant -eq 'taikun'){11}else{22};$cid=if($tenant -eq 'taikun'){111}else{222}
 $otherScope=if($tenant -eq 'taikun'){'articoli.aspx?st=22&ct=222'}else{'articoli.aspx?st=11&ct=111'}
 foreach($case in @(@{name='own-scope';scope=('articoli.aspx?st='+$sid+'&ct='+$cid);q='lampada'},@{name='other-tenant';scope=$otherScope;q='lampada'},@{name='external';scope='https://invalid.example/';q='lampada'},@{name='empty';scope='';q=''},@{name='encoded';scope=('articoli.aspx?st='+$sid+'&ct='+$cid);q=' A&B + luce '})){
  $before=@([IO.File]::ReadAllLines((Join-Path $FixtureRoot 'events.txt'))).Count
  $query='tenant='+$tenant+'&ksms=1&'+[Web.HttpUtility]::UrlEncode($scopeName)+'='+[Web.HttpUtility]::UrlEncode($case.scope)+'&'+[Web.HttpUtility]::UrlEncode($mobileName)+'='+[Web.HttpUtility]::UrlEncode($case.q)
  $get=$gate.Run('articoli.aspx',$query,'GET','')
  $getEvents=@([IO.File]::ReadAllLines((Join-Path $FixtureRoot 'events.txt'))|Select-Object -Skip $before|ForEach-Object{$_.ToString()})
  $redirects+=@{tenant=$tenant;case=$case.name;status=$get[0];location=$get[1];events=$getEvents}
 }
}
[IO.File]::WriteAllText((Join-Path $FixtureRoot 'postbacks.json'),(ConvertTo-Json -Depth 6 -InputObject $results))
[IO.File]::WriteAllText((Join-Path $FixtureRoot 'redirects.json'),(ConvertTo-Json -Depth 6 -InputObject $redirects))
[IO.File]::WriteAllText((Join-Path $FixtureRoot 'controls.json'),(ConvertTo-Json -Depth 6 -InputObject $controls))
`);
const framework=path.join(process.env.WINDIR,'Microsoft.NET/Framework64/v4.0.30319');
cp.execFileSync(path.join(framework,'vbc.exe'),['/nologo','/target:library','/out:'+path.join(work,'bin/Gate.dll'),'/reference:System.Web.dll',path.join(work,'Gate.vb')],{windowsHide:true,stdio:"inherit"});
cp.execFileSync('powershell.exe',['-NoProfile','-ExecutionPolicy','RemoteSigned','-File',path.join(work,'render.ps1'),work],{windowsHide:true,stdio:"inherit",timeout:90000});
const posts=JSON.parse(fs.readFileSync(path.join(work,'postbacks.json'),'utf8'));
posts.forEach(p=>{assert.equal(p.status,'200');assert.equal(p.location,'');assert(p.mobileFieldsAbsent);assert(p.events.includes('UNRELATED_CLICK'),JSON.stringify(p));assert(p.events.includes('PAGE_LOAD_COMPLETE'));for(const forbidden of ['MOBILE_TEXT_CHANGED','SEARCH_DISPATCH','NATIVE_DISPATCH','NATIVE_REDIRECT'])assert(!p.events.includes(forbidden),forbidden);});
const controls=JSON.parse(fs.readFileSync(path.join(work,'controls.json'),'utf8'));
controls.forEach(p=>{assert(p.events.includes('MOBILE_TEXT_CHANGED'));assert(p.events.includes('SEARCH_DISPATCH'));assert(p.location);});
const redirects=JSON.parse(fs.readFileSync(path.join(work,'redirects.json'),'utf8'));
redirects.forEach(r=>{assert.equal(r.status,'302');assert(r.events.includes('NATIVE_REDIRECT'));assert(!r.events.includes('PAGE_LOAD_COMPLETE'));const u=new URL(r.location,'http://fixture');const t=tenants[r.tenant];assert.equal(u.pathname,'/articoli.aspx');assert(!u.searchParams.has('ksms'));if(['own-scope','encoded'].includes(r.case)){assert.equal(u.searchParams.get('st'),String(t.sector));assert.equal(u.searchParams.get('ct'),String(t.category));}else assert(!u.searchParams.has('st'));assert.equal(u.searchParams.get('q'),r.case==='empty'?null:r.case==='encoded'?'A&B + luce':'lampada');});
// Mutation oracle: substituting another tenant's expected scope must fail this test, not pass silently.
for(const key of Object.keys(tenants))assert.throws(()=>tenantScope(tenants[key],scope(tenants[key==='taikun'?'webaffare':'taikun'])));
(async()=>{let browser;const checks=[],navigation=[],limits=['IIS application/master and database not exercised','Tenant binding/logo/menu data are synthetic, real candidate header markup is compiled unchanged','Browser native GET destination is simulated; local System.Web unrelated POST events are executed'];function check(n,v){assert(v,n);checks.push(n);}
const http=require('http').createServer((req,res)=>{const u=new URL(req.url,'http://localhost');const key=req.headers.host.startsWith('webaffare.')?'webaffare':'taikun',t=tenants[key];
if(u.pathname.startsWith('/Public/assets/keepstore/')){const file=path.resolve(root,'.'+u.pathname);if(!file.startsWith(path.join(root,'Public/assets/keepstore')+path.sep)||!fs.existsSync(file)){res.writeHead(404);return res.end();}const ext=path.extname(file),types={'.css':'text/css','.js':'application/javascript','.woff':'font/woff','.woff2':'font/woff2','.ttf':'font/ttf','.svg':'image/svg+xml'};res.writeHead(200,{'content-type':types[ext]||'application/octet-stream'});return res.end(fs.readFileSync(file));}
if(u.pathname==='/fixture-logo.svg'){res.writeHead(200,{'content-type':'image/svg+xml'});return res.end(`<svg xmlns="http://www.w3.org/2000/svg" width="150" height="40"><text x="0" y="28">${t.title}</text></svg>`);}
if(u.pathname==='/Public/assets/images/headphone-2.svg'){res.writeHead(200,{'content-type':'image/svg+xml'});return res.end(fs.readFileSync(path.join(root,u.pathname.slice(1))));}
if(u.pathname==='/search_suggest.aspx'){res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify({ok:true,suggestions:[{id:t.product,title:t.title+' fixture',url:'/articolo.aspx?id='+t.product}],strong:{canRedirect:false}}));}
if(u.pathname==='/articoli.aspx'&&u.searchParams.has('ksms')){const selected=u.searchParams.get('ctl00$headerUi$product_cat_mobile');const allowed=['',`articoli.aspx?st=${t.sector}`,scope(t),`articoli.aspx?st=${t.other}`];let dest='/'+(allowed.includes(selected)&&selected?selected:'articoli.aspx');const q=(u.searchParams.get('ctl00$headerUi$tbCercaMobile')||'').trim().slice(0,80);if(q)dest+=(dest.includes('?')?'&':'?')+'q='+encodeURIComponent(q);res.writeHead(302,{location:dest});return res.end();}
res.writeHead(200,{'content-type':'text/html'});const links=styles.map(f=>`<link rel="stylesheet" href="/Public/assets/keepstore/${f}">`).join('');const scripts=['bootstrap.min.js','ks-page-flags.js'].map(f=>`<script src="/Public/assets/keepstore/js/${f}"></script>`).join('');res.end(u.pathname==='/fixture'?fs.readFileSync(path.join(work,'rendered-'+key+'.html'),'utf8').replace('</head>',links+'</head>').replace('</body>',scripts+'</body>'):'<p>Fixture navigation captured</p>');});await new Promise(r=>http.listen(0,'127.0.0.1',r));const port=http.address().port;
try{console.log('CHROME_START '+work);browser=await chromium.launch({channel:process.env.KS_BROWSER_CHANNEL||'chrome',headless:true,args:['--no-proxy-server']});
for(const [key,t]of Object.entries(tenants))for(const js of [false,true])for(const width of [360,390,430,768,1024,1365]){
const origin=`http://${key}.localhost:${port}`,ctx=await browser.newContext({javaScriptEnabled:js,viewport:{width,height:950}}),p=await ctx.newPage();await ctx.route('**/*',r=>{if(!r.request().url().startsWith(origin+'/'))return r.abort();return r.continue();});p.setDefaultTimeout(7000);await p.goto(origin+'/fixture',{waitUntil:'load',timeout:10000});
check(key+width+js+' unique',await p.locator('[data-ks-search-form="mobile"]').count()===1);check(key+width+js+' mobile visibility',await p.locator('.ks-mobile-search-area').isVisible()===(width<768));check(key+width+js+' desktop visibility',await p.locator('[data-ks-search-form="desktop"]').isVisible()===(width>=768));check(key+width+js+' preselected scope',await p.locator('#product_cat_mobile').inputValue()===scope(t));check(key+width+js+' overflow',await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
check('unique IDs',await p.evaluate(()=>{const ids=Array.from(document.querySelectorAll('[id]')).map(e=>e.id);return new Set(ids).size===ids.length;}));
check('native POST ownership',await p.evaluate(()=>{const fields=Array.from(new FormData(document.querySelector('#form1')).keys());return !fields.some(n=>/tbCercaMobile|product_cat_mobile/.test(n));}));
check('header controls do not overlap',await p.evaluate(()=>{const header=document.querySelector('.inner-header'),visible=e=>e.getBoundingClientRect().width>0,logo=Array.from(header.querySelectorAll('.logo-site img')).find(visible),search=Array.from(document.querySelectorAll('[data-ks-search-form]')).find(visible),right=header.querySelector('.header-right'),a=logo.getBoundingClientRect(),b=search.getBoundingClientRect(),c=right.getBoundingClientRect(),hit=(x,y)=>x.left<y.right-1&&x.right>y.left+1&&x.top<y.bottom-1&&x.bottom>y.top+1;return !hit(a,b)&&!hit(b,c);}));
if(width<768){check('search between icons and guide',await p.evaluate(()=>{const a=document.querySelector('.inner-header').getBoundingClientRect(),b=document.querySelector('.ks-mobile-search-area').getBoundingClientRect(),c=document.querySelector('.ks-guide-mobile-entry').getBoundingClientRect();return a.bottom<=b.top+1&&b.bottom<=c.top+1;}));if(js){await p.locator('#tbCercaMobile').focus();await p.keyboard.press('Tab');check('keyboard search button',await p.locator('#btnSearchMobile').evaluate(e=>e===document.activeElement));}}
tenantScope(t,await p.locator('#product_cat_mobile').inputValue());
if(width<768){const b=await p.locator('#btnSearchMobile').boundingBox();check('touch',b.width>=44&&b.height>=44);check('correct form',await p.locator('#tbCercaMobile').evaluate(e=>e.form.id==='ksMobileSearchForm'));}
if(width<1200){if(js){const menu=p.locator('[data-bs-target="#mobileMenu"]');await menu.click();await p.locator('#mobileMenu.show').waitFor();await p.keyboard.press('Escape');await p.waitForFunction(()=>!document.querySelector('.offcanvas-backdrop')&&!document.querySelector('#mobileMenu').classList.contains('show')&&!document.querySelector('#mobileMenu').classList.contains('hiding'));check('menu focus return',await menu.evaluate(e=>e===document.activeElement));await menu.focus();await p.keyboard.press('Enter');await p.locator('#mobileMenu.show').waitFor();await p.locator('#mobileMenu [data-bs-dismiss="offcanvas"]').click();await p.waitForFunction(()=>!document.querySelector('.offcanvas-backdrop')&&!document.querySelector('#mobileMenu').classList.contains('show')&&!document.querySelector('#mobileMenu').classList.contains('hiding'));check('menu close button and focus',await menu.evaluate(e=>e===document.activeElement));}else check('no-JS menu accessible',await p.locator('#mobileMenu').isVisible());}
await p.evaluate(()=>document.fonts.ready);await p.screenshot({animations:'disabled',timeout:10000,path:path.join(work,`${key}-${width}-${js}.png`)});await ctx.close();}
// Differential browser requests use disjoint scopes; the other tenant's scope must be rejected.
for(const [key,t]of Object.entries(tenants))for(const js of [false,true])for(const action of ['click','enter','scope-only','cross-tenant']){
if(js&&action==='cross-tenant')continue; // Scope membership is a server check; JS URL construction is not a tenant authority.
const origin=`http://${key}.localhost:${port}`,ctx=await browser.newContext({javaScriptEnabled:js,viewport:{width:390,height:950}}),p=await ctx.newPage(),nav=[];p.on('request',r=>{if(r.isNavigationRequest()&&new URL(r.url()).pathname!='/fixture')nav.push(r.url());});p.setDefaultTimeout(7000);await p.goto(origin+'/fixture',{waitUntil:'load',timeout:10000});const input=p.locator('#tbCercaMobile');await input.fill('lampada');if(action==='scope-only')await p.selectOption('#product_cat_mobile',`articoli.aspx?st=${t.other}`);if(action==='cross-tenant'){const other=tenants[key==='taikun'?'webaffare':'taikun'];await p.locator('#product_cat_mobile').evaluate((e,v)=>e.add(new Option('wrong tenant',v)),scope(other));await p.selectOption('#product_cat_mobile',scope(other));}
await Promise.all([p.waitForURL(u=>u.pathname!='/fixture'),action==='enter'?input.press('Enter'):p.locator('#btnSearchMobile').click()]);const final=new URL(p.url());check('one intent',nav.length===(js?1:2));check('query',final.searchParams.get('q')==='lampada');if(action==='cross-tenant')check('cross-tenant rejected',!final.searchParams.has('st'));else check('tenant destination',final.searchParams.get('st')===String(action==='scope-only'?t.other:t.sector));navigation.push({tenant:key,js,action,final:final.pathname+final.search});await ctx.close();}
for(const [key,t]of Object.entries(tenants))for(const activation of ['click','keyboard']){const ctx=await browser.newContext({viewport:{width:390,height:950}}),p=await ctx.newPage();const origin=`http://${key}.localhost:${port}`;p.setDefaultTimeout(7000);await p.goto(origin+'/fixture',{waitUntil:'load',timeout:10000});const input=p.locator('#tbCercaMobile');await input.fill('lampada');await input.press('a');const option=p.locator('#ksSearchSuggestMobile .ks-suggest-item');await option.waitFor();const box=await option.boundingBox();check('suggest within viewport',box.x>=0&&box.x+box.width<=390);if(activation==='keyboard'){await input.press('ArrowDown');await input.press('Enter');}else await option.click();await p.waitForURL('**/articolo.aspx?id='+t.product);check('tenant PDP target',new URL(p.url()).searchParams.get('id')===String(t.product));await ctx.close();}
const report={result:'PASS QA SOURCE/LOCAL WEBFORMS/CHROME FIXTURE',checks:checks.length,tenants,postbacks:posts,instrumentationControls:controls,serverRedirects:redirects,navigation,headerSource:'Full candidate ASCX compiled; only directive replaced with inline fixture bindings',levels:{A:'Synthetic tenant scopes/logo and Node redirect/suggest simulations',B:'Actual Framework4.8 ApplicationHost, ViewState-bearing unrelated POST, copied master handlers wired and event traces',C:'Chrome on rendered full candidate header + candidate CSS/JS/Bootstrap',D:'IIS NOT EXERCISED'},limits,artifacts:work};write('qa-report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}finally{if(browser)await browser.close();await new Promise(r=>http.close(r));}})().catch(e=>{console.error(e);console.error('ARTIFACTS='+work);process.exitCode=1;});
