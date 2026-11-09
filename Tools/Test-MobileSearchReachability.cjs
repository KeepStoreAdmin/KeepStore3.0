'use strict';
// Isolated Framework/Chrome gate: no IIS, database, or operational configuration.
const fs = require('fs'), path = require('path'), os = require('os');
const cp = require('child_process'), assert = require('assert');
const root = path.resolve(__dirname, '..');
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'ks-mobile-search-rev2-'));
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const write = (p, text) => fs.writeFileSync(path.join(work, p), text);
const header = read('Public/ui/controls/SiteHeader.ascx');
const server = read('Public/ui/controls/SiteHeader.ascx.vb');
const dispatch = server.slice(server.indexOf('    Private Sub DispatchNativeMobileSearch()'), server.indexOf('    Protected Sub Page_PreRender'));
const mobile = header.slice(header.indexOf('    <div class="ks-mobile-search-area">'), header.indexOf('    <div class="ks-guide-mobile-entry'));
assert.equal((header.match(/ID="tbCercaMobile"/g) || []).length, 1);
assert.equal((header.match(/data-ks-search-form="mobile"/g) || []).length, 1);
assert(!mobile.includes('runat="server" ClientIDMode="Static" type="submit"'));
const master = read('Page.master');
assert(master.indexOf('id="ksMobileSearchForm"') > master.indexOf('</form>'));
fs.mkdirSync(path.join(work, 'bin'));
write('Gate.vb', `Imports System
Imports System.IO
Imports System.Web
Imports System.Web.Hosting
Imports System.Threading
Public Class CaptureWorker
 Inherits SimpleWorkerRequest
 Public Done As New ManualResetEvent(False)
 Public Status As Integer = 200
 Public Location As String = ""
 Public Sub New(query As String, output As TextWriter)
  MyBase.New("articoli.aspx", query, output)
 End Sub
 Public Overrides Sub SendStatus(code As Integer, description As String)
  Status=code
  MyBase.SendStatus(code,description)
 End Sub
 Public Overrides Sub SendKnownResponseHeader(index As Integer, value As String)
  If index=HttpWorkerRequest.HeaderLocation Then Location=value
  MyBase.SendKnownResponseHeader(index,value)
 End Sub
 Public Overrides Sub EndOfRequest()
  MyBase.EndOfRequest()
  Done.Set()
 End Sub
End Class
Public Class GateHost
 Inherits MarshalByRefObject
 Public Function Run(query As String) As String()
  Dim output As New StringWriter()
  Dim worker As New CaptureWorker(query,output)
  HttpRuntime.ProcessRequest(worker)
  If Not worker.Done.WaitOne(15000) Then Throw New Exception("PIPELINE_TIMEOUT")
  Return New String(){worker.Status.ToString(),worker.Location,output.ToString()}
 End Function
End Class`);
write('web.config', '<configuration><system.web><compilation targetFramework="4.8"/><httpRuntime targetFramework="4.8"/><customErrors mode="Off"/><trust level="Full"/></system.web></configuration>');
write('header.ascx', `<%@ Control Language="VB" %>
<script runat="server">
Protected Sub Loaded(sender As Object,e As EventArgs) Handles Me.Load
 product_cat_mobile.Items.Add(New ListItem("Tutti i settori",""))
 product_cat_mobile.Items.Add(New ListItem("Tenant fixture","articoli.aspx?st=2"))
 product_cat_mobile.Items.Add(New ListItem("Categoria fixture","articoli.aspx?st=2&ct=96"))
 Dim value As String=Request.QueryString("tenant")
 System.IO.File.AppendAllText(System.IO.Path.Combine(HttpRuntime.AppDomainAppPath,"events.txt"),"BOUND" & vbLf)
 DispatchNativeMobileSearch()
End Sub
${dispatch}
</script>${mobile.replace('ID="tbCercaMobile"', 'ID="tbCercaMobile" Text="lampada"')}`);
write('articoli.aspx', `<%@ Page Language="VB" %><%@ Register Src="header.ascx" TagPrefix="ks" TagName="Header" %>
<script runat="server">
Protected Sub Loaded(sender As Object,e As EventArgs) Handles Me.LoadComplete
 System.IO.File.AppendAllText(System.IO.Path.Combine(HttpRuntime.AppDomainAppPath,"events.txt"),"LOAD_COMPLETE" & vbLf)
End Sub
</script><!doctype html><html><head><meta name="viewport" content="width=device-width"/></head><body>
<form id="form1" runat="server"><header class="ks-header-ui"><div style="height:64px">Logo / Account / Carrello / Menu</div><ks:Header ID="headerUi" runat="server"/><a href="/Default.aspx#guide">Guida agli acquisti</a></header><asp:Button runat="server" ID="unrelated" Text="Other"/></form>
<form id="ksMobileSearchForm" method="get" action="/articoli.aspx"><input type="hidden" name="ksms" value="1"/></form></body></html>`);
const cases = [
 {text:'lampada', scope:'articoli.aspx?st=2', expected:'/articoli.aspx?st=2&q=lampada'},
 {text:'  caffè & tè  ', scope:'articoli.aspx?st=2&ct=96', expected:'/articoli.aspx?st=2&ct=96&q=caff%c3%a8+%26+t%c3%a8'},
 {text:'', scope:'articoli.aspx?st=2', expected:'/articoli.aspx?st=2'},
 {text:'lampada', scope:'https://evil.invalid/articoli.aspx', expected:'/articoli.aspx?q=lampada'},
 {text:'lampada', scope:'//evil.invalid', expected:'/articoli.aspx?q=lampada'},
 {text:'x'.repeat(90), scope:'', expected:'/articoli.aspx?q='+'x'.repeat(80)}
];
write('cases.json', JSON.stringify(cases.map(c=>'ksms=1&'+new URLSearchParams({'headerUi$tbCercaMobile':c.text,'headerUi$product_cat_mobile':c.scope}))));
write('render.ps1', `param([string]$FixtureRoot)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Web
Add-Type -Path (Join-Path $FixtureRoot 'bin/Gate.dll')
$gate=[System.Web.Hosting.ApplicationHost]::CreateApplicationHost([GateHost], '/', ($FixtureRoot+'\\'))
$first=$gate.Run('')
[IO.File]::WriteAllText((Join-Path $FixtureRoot 'rendered.html'),$first[2])
$results=@()
foreach($query in (Get-Content -Raw (Join-Path $FixtureRoot 'cases.json')|ConvertFrom-Json)) {
 $before=@(Get-Content (Join-Path $FixtureRoot 'events.txt')).Count
 $r=$gate.Run($query)
 $events=@(Get-Content (Join-Path $FixtureRoot 'events.txt')|Select-Object -Skip $before|ForEach-Object { $_.ToString() })
 $results+=@{status=$r[0];location=$r[1];events=$events}
}
[IO.File]::WriteAllText((Join-Path $FixtureRoot 'server-results.json'),(ConvertTo-Json -Depth 5 -InputObject $results))`);
const framework = path.join(process.env.WINDIR, 'Microsoft.NET/Framework64/v4.0.30319');
cp.execFileSync(path.join(framework,'vbc.exe'), ['/nologo','/target:library','/out:'+path.join(work,'bin/Gate.dll'),'/reference:System.Web.dll',path.join(work,'Gate.vb')], {windowsHide:true});
cp.execFileSync('powershell.exe',['-NoProfile','-ExecutionPolicy','RemoteSigned','-File',path.join(work,'render.ps1'),work],{windowsHide:true,timeout:60000});
const results=JSON.parse(fs.readFileSync(path.join(work,'server-results.json'),'utf8'));
results.forEach((r,i)=>{assert.equal(r.status,'302');assert.equal(r.location,cases[i].expected);assert.deepEqual(r.events,['BOUND']);});
const html=fs.readFileSync(path.join(work,'rendered.html'),'utf8');
const css=['bootstrap.min.css','styles.css','theme-overrides.css'].map(f=>read('Public/assets/keepstore/css/'+f)).join('\n');
const controller=read('Public/assets/keepstore/js/ks-page-flags.js');
const moduleRoot=process.env.KS_PLAYWRIGHT_MODULE || 'C:/Users/Taikun/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
const {chromium}=require(moduleRoot);
(async()=>{const localServer=require('http').createServer((req,res)=>{
 const u=new URL(req.url,'http://localhost');
 if(u.pathname==='/search_suggest.aspx'){
  res.writeHead(200,{'content-type':'application/json'});
  return res.end(JSON.stringify({ok:true,suggestions:[{id:123,title:'Lampada fixture',url:'/articolo.aspx?id=123',price:12.5}],strong:{canRedirect:false}}));
 }
 if(u.pathname==='/articoli.aspx'&&u.searchParams.has('ksms')){
  const scope=u.searchParams.get('headerUi$product_cat_mobile');let dest='/articoli.aspx'+(scope==='articoli.aspx?st=2'?'?st=2':scope==='articoli.aspx?st=2&ct=96'?'?st=2&ct=96':'');
  const q=(u.searchParams.get('headerUi$tbCercaMobile')||'').trim().slice(0,80);if(q)dest+=(dest.includes('?')?'&':'?')+'q='+encodeURIComponent(q);
  res.writeHead(302,{location:dest});return res.end();
 }
 res.writeHead(200,{'content-type':'text/html'});res.end(u.pathname==='/fixture'?html:'<p>captured</p>');
});await new Promise(resolve=>localServer.listen(0,'127.0.0.1',resolve));
const origin='http://127.0.0.1:'+localServer.address().port;
const browser=await chromium.launch({executablePath:process.env.KS_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});let checks=results.length;try{
for(const tenant of ['taikun','webaffare'])for(const js of [false,true])for(const scenario of ['new-click','new-enter','same-click','same-enter','scope-only','empty-scope','tampered','unrelated']){
 console.log('CASE '+tenant+' JS='+js+' '+scenario);
 const ctx=await browser.newContext({javaScriptEnabled:js,viewport:{width:390,height:844}}),nav=[];
 const p=await ctx.newPage();p.on('request',req=>{if(req.isNavigationRequest()&&new URL(req.url()).pathname!='/fixture')nav.push({url:req.url(),method:req.method()});});await p.goto(origin+'/fixture');
 if(js){await p.addStyleTag({content:css});await p.addScriptTag({content:controller});}
 const input=p.locator('#tbCercaMobile'),select=p.locator('#product_cat_mobile');
 const expectedText=scenario==='empty-scope'?'':scenario.startsWith('new-')?'nuova lampada':'lampada';
 if(!scenario.startsWith('same-')&&scenario!=='scope-only')await input.fill(expectedText);
 await select.selectOption('articoli.aspx?st=2');
 assert.equal(await input.evaluate(e=>e.form.id),'ksMobileSearchForm');
 if(scenario==='scope-only')await select.selectOption('articoli.aspx?st=2&ct=96');
 if(scenario==='tampered'){await select.evaluate(e=>e.add(new Option('tampered','https://evil.invalid/articoli.aspx')));await select.selectOption('https://evil.invalid/articoli.aspx');}
 if(scenario==='unrelated')await p.locator('#unrelated').focus();
 await Promise.all([p.waitForURL(u=>u.pathname!='/fixture'),scenario==='unrelated'?p.locator('#unrelated').evaluate(e=>e.form.requestSubmit(e)):scenario.endsWith('enter')?input.press('Enter'):p.locator('#btnSearchMobile').click()]);
 if(scenario==='unrelated'){assert.equal(nav.length,1);assert.equal(nav[0].method,'POST');}
 else {assert.equal(nav.length,js?1:2);nav.forEach(n=>{assert.equal(n.method,'GET');assert.equal(new URL(n.url).origin,origin);assert(!new URL(n.url).searchParams.has('__VIEWSTATE'));});
  const final=new URL(nav.at(-1).url);assert.equal(final.searchParams.get('q')||'',expectedText);assert(!final.searchParams.has('ksms'));assert.equal(final.searchParams.get('ct'),scenario==='scope-only'?'96':null);
 }
 checks++;await ctx.close();
}
for(const activation of ['keyboard','click']){
 const ctx=await browser.newContext({viewport:{width:390,height:844}});const p=await ctx.newPage();await p.goto(origin+'/fixture');await p.addStyleTag({content:css});await p.addScriptTag({content:controller});
 const input=p.locator('#tbCercaMobile');await input.fill('lampada');await input.press('a');
 const option=p.locator('#ksSearchSuggestMobile .ks-suggest-item');await option.waitFor({state:'visible'});
 if(activation==='keyboard'){await input.press('ArrowDown');assert(await input.getAttribute('aria-activedescendant'));await input.press('Enter');}else await option.click();
 await p.waitForURL('**/articolo.aspx?id=123');checks++;await ctx.close();
}
for(const width of [360,390,430,768,1024,1365]){
 const ctx=await browser.newContext({viewport:{width,height:900}});const p=await ctx.newPage();await p.setContent(html);await p.addStyleTag({content:css});
 assert.equal(await p.locator('[data-ks-search-form="mobile"]').count(),1);
 assert.equal(await p.locator('.ks-mobile-search-area').isVisible(),width<768);
 if(width<768){const rect=await p.locator('#btnSearchMobile').boundingBox();assert(rect.width>=44&&rect.height>=44);assert(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
 await p.screenshot({path:path.join(work,'search-'+width+'.png')});checks++;await ctx.close();
}
console.log(JSON.stringify({result:'PASS',checks,serverPipeline:'Actual System.Web 4.8; redirect before LoadComplete',browser:'Chrome fixture; JS/no-JS; two synthetic tenants',runtime:'IIS/MySQL Home/catalog/PDP/cart NOT EXERCISED',artifacts:work}));
}finally{await browser.close();await new Promise(resolve=>localServer.close(resolve));}})().catch(e=>{console.error(e);process.exitCode=1;});
