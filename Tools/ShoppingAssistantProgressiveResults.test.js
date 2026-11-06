/* Offline contract/browser certification. All HTTP is fulfilled or aborted locally.
   No IIS, database, account login, external model, dependency install or persistent browser profile. */
'use strict';
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict'), cp = require('node:child_process');
const [root, playwrightModule, chrome, evidence, serverPath] = process.argv.slice(2);
const regressionsOnly = process.argv.includes('--rev1-regressions-only');
const mediaOnly = process.argv.includes('--rev2-media-only');
const handoffOnly = process.argv.includes('--catalog-handoff-only');
const decisionOnly = process.argv.includes('--decision-journey-only');
const advisorOnly = process.argv.includes('--advisor-only');
const advisorQualityOnly = process.argv.includes('--advisor-quality-rev1-only');
const advisorBaselineOnly = process.argv.includes('--advisor-baseline-visual-only');
const baselineVisualOnly = process.argv.includes('--decision-baseline-visual-only') || advisorBaselineOnly;
const decisionBase = advisorBaselineOnly || advisorOnly ? '21dee2e4fa3ec89d0d5c2cc643b7b19409bde963' : 'bb89975eaed397b2ac35b3de058c6627e459173b';
if (!root || !playwrightModule || !chrome || !evidence || !serverPath) throw new Error('EXPLICIT_FIXTURE_PATHS_REQUIRED');
function baselineSource(file) { return cp.execFileSync('git',['show',decisionBase+':'+file],{cwd:root,encoding:'utf8'}); }
function sourceApi(source) { const sandbox={module:{exports:{}},URL,URLSearchParams};require('node:vm').runInNewContext(source,sandbox);return sandbox.module.exports; }
const api = baselineVisualOnly ? sourceApi(baselineSource('Public/assets/keepstore/js/ks-shopping-guide.js')) : require(path.join(root, 'Public/assets/keepstore/js/ks-shopping-guide.js'));
const serverEvidence = JSON.parse(fs.readFileSync(serverPath, 'utf8').replace(/^\uFEFF/,''));
const advisorFixturePath = process.argv.includes('--advisor-fixtures') ? process.argv[process.argv.indexOf('--advisor-fixtures') + 1] : '';
const advisorEvidence = advisorOnly && advisorFixturePath ? JSON.parse(fs.readFileSync(advisorFixturePath,'utf8').replace(/^\uFEFF/,'')) : null;
const advisorServer = advisorEvidence ? advisorEvidence.fixtures : [];
if(advisorOnly && (!Array.isArray(advisorServer) || !advisorServer.length)) throw new Error('REAL_VB_ADVISOR_FIXTURES_REQUIRED');
// Handoff exercises transport/UI, not commercial pricing: this response is explicitly synthetic.
const server = handoffOnly ? [{scenario:'synthetic-handoff-only', expectedList:'not-resolved', payload:{
  ok:true, mode:'guided', recent:false, query:'SKU120', total:1, catalogUrl:'articoli.aspx?q=SKU120',
  guided:{version:1,criteria:{q:'SKU120',st:0,pmin:'0',pmax:'0',disponibile:false,ordinamento:''},displayLabel:'Prezzi visualizzati IVA inclusa',returnedCount:1,selectionLimited:true,limit:6},
  suggestions:[{id:120,TCId:42,url:'articolo.aspx?id=120&TCId=42',title:'Prodotto sintetico',code:'SKU120',ean:'',brand:'',category:'',image:'',image_fallback:'',price:'12,20 €',priceValue:12.2,availability:7,isOffer:false,isRefurbished:false}]
}}] : serverEvidence;
const playwright = require(playwrightModule);
const report = { assertions: 0, checks: [], viewports: mediaOnly ? [390,1365] : [360,390,430,768,1024,1365], renderMs: [], screenshots: [],
  suite: advisorOnly ? 'Catalog-driven advisor v2 delta only' : baselineVisualOnly ? 'Immutable decision baseline visuals only' : decisionOnly ? 'Decision journey delta only' : handoffOnly ? 'Catalog handoff delta only' : mediaOnly ? 'REV2 media only' : regressionsOnly ? 'REV1 regression reproduction' : 'Full client suite including decision journey', startedUtc: new Date().toISOString(),
  serverFixtures: server.map(x => ({scenario:x.scenario, expectedList:x.expectedList})), network: 'intercepted; no upstream continuation',
  limitations: ['synthetic HTML rendering, no ASP.NET request execution', 'no MySQL/IIS/login/production/TTFB/INP certification',
    'tenant/list provenance and variant ownership are checked by the real-source VB harness with synthetic I/O; the browser cannot authenticate arbitrary plausible price or stock values'] };
const journal = { resources: [], browserClosed: false, contextsClosed: 0 };
const record = (name, value = true) => { assert.ok(value, name); report.assertions++; report.checks.push(name); };
const clone = value => JSON.parse(JSON.stringify(value));
const read = file => baselineVisualOnly&&['Default.aspx','Public/assets/keepstore/js/ks-shopping-guide.js'].includes(file) ? baselineSource(file) : fs.readFileSync(path.join(root, file), 'utf8');
const sha256 = data => require('node:crypto').createHash('sha256').update(data).digest('hex');
report.sources = ['Default.aspx','Public/assets/keepstore/js/ks-shopping-guide.js','search_suggest.aspx.vb','Tools/ShoppingAssistantProgressiveResults.test.js','Tools/Test-ShoppingAssistantProgressiveResults.ps1', ...(handoffOnly?['articoli.aspx','articoli.aspx.vb']:[])]
  .map(file=>({file,sha256:sha256(read(file))}));
if(baselineVisualOnly)report.baselineRef=decisionBase;
report.serverPayloadSha256 = sha256(fs.readFileSync(serverPath));
report.sourceBytes = {guide:Buffer.byteLength(read('Public/assets/keepstore/js/ks-shopping-guide.js')),markup:Buffer.byteLength(read('Default.aspx'))};
if(advisorOnly){
  report.advisorFixtureProvenance={path:advisorFixturePath,sha256:sha256(fs.readFileSync(advisorFixturePath)),fixtureNames:advisorServer.map(x=>x.name),source:'actual VB endpoint builder with synthetic I/O; see companion PowerShell harness'};
  report.baselineSourceBytes={ref:decisionBase,guide:Buffer.byteLength(baselineSource('Public/assets/keepstore/js/ks-shopping-guide.js')),markup:Buffer.byteLength(baselineSource('Default.aspx'))};
}
function artifact(name, data) { const file=path.join(evidence,name); fs.writeFileSync(file,data); if(!journal.resources.includes(file))journal.resources.push(file); return file; }
function briefFrom(url) {
  const p = new URL(url).searchParams;
  return {q:p.get('q'),st:Number(p.get('st')||0),pmin:p.get('pmin')||'0',pmax:p.get('pmax')||'0',disponibile:p.get('disponibile')==='1',ordinamento:p.get('ordinamento')||''};
}
function advisorSpec(raw) {
  const u = new URL(raw.includes('://') ? raw : 'https://tenant1.invalid/search_suggest.aspx?' + raw.replace(/^\?/,''));
  const p=u.searchParams;
  const brief=briefFrom(u.href);brief.q=brief.q||'';
  return {brief,criteria:JSON.parse(p.get('criteria')||'[]'),skipped:JSON.parse(p.get('skipped')||'[]'),receipts:JSON.parse(p.get('receipts')||'[]')};
}
function advisorSignature(raw) {
  const s=advisorSpec(raw);
  return JSON.stringify({brief:s.brief,criteria:s.criteria.map(c=>({attributeId:c.attributeId,operator:c.operator,value:c.value,priority:c.priority})),skipped:[...s.skipped].sort()});
}
function advisorPayload(url, config) {
  const matching=advisorServer.filter(x=>advisorSignature(x.queryString)===advisorSignature(url));
  const row=config.advisorScenario ? matching.find(x=>x.name===config.advisorScenario) : matching[0];
  if(!row)throw new Error('NO_REAL_VB_FIXTURE_FOR_REQUEST '+new URL(url).search);
  const response=clone(row.response);
  if(config.mutate)config.mutate(response);
  return response;
}
function payload(url, options = {}) {
  const base = new URL('./',url), paths = api.urls(base.href, new URL('search_suggest.aspx',base).href), b=briefFrom(url);
  const original = clone((server[options.scenario||0]||server[0]).payload), row=original.suggestions[0];
  const count=options.empty?0:(options.count===undefined?3:options.count), food=options.food, prefix=food?'Olio extra vergine di oliva':'Notebook compatto';
  original.query=b.q; original.normalized_query=b.q; original.catalogUrl=api.catalogURL(b,paths).href;
  original.guided.criteria=b; original.guided.returnedCount=count; original.total=count;
  original.suggestions=Array.from({length:count},(_,i)=>Object.assign({},row,{
    id:120+i, TCId:42+i, url:'articolo.aspx?id='+(120+i)+'&TCId='+(42+i),
    title:(options.long?'Prodotto con descrizione lunga '.repeat(8):prefix)+' '+(i+1),
    code:i===0?b.q:'DEMO'+i, ean:'800000000012'+i, brand:i===2?'':(food?'Frantoio esempio':'Marca esempio'),
    category:i===2?'':(food?'Oli alimentari':'Computer'), image:'',image_fallback:'',
    availability:i===2&&!b.disponibile?null:7, isOffer:i===1, isRefurbished:false
  }));
  if(options.mutate)options.mutate(original);
  return original;
}
const moduleSource=read('Public/assets/keepstore/js/ks-shopping-guide.js');
const homeSource=read('Public/assets/keepstore/js/home-default.js');
const markup=read('Default.aspx');
const guidemarkup=markup.slice(markup.indexOf('    <section id="KsLocalAiSearch130"'),markup.indexOf('    <asp:Panel ID="HomePriceDisplayNote"'));
const decisionStyle=(/<style\b[^>]*id="ksShoppingDecisionStyles"[^>]*>[\s\S]*?<\/style>/.exec(markup)||[''])[0];
record('real section isolated',guidemarkup.includes('data-ks-guide-results')&&!guidemarkup.includes('HomePriceDisplayNote'));
const styles=['bootstrap.min.css','keepstore.css','keepstore-overrides.css','styles.css','theme-overrides.css'];
const assets=new Map(styles.map(name=>['css/'+name,read('Public/assets/keepstore/css/'+name)]));
assets.set('js/ks-shopping-guide.js',moduleSource);assets.set('js/home-default.js',homeSource);
if(handoffOnly)for(const name of ['catalog-ui.css','catalog-filters-ui.css','catalog-product-flow.css'])assets.set('css/'+name,read('Public/assets/keepstore/css/'+name));
function html(directory,kind,mode) {
  const food=kind==='Food', sectors=food?[[7,'Alimentari'],[8,'Dispensa']]:[[7,'Informatica'],[8,'Accessori']];
  let block=guidemarkup.replace(/<%=\s*ResolveUrl\("~\/([^"]*)"\)\s*%>/g,(_,s)=>directory+s);
  block=block.replace(/<asp:Repeater ID="rptHomeAiExamples"[\s\S]*?<\/asp:Repeater>/g,sectors.map(([id,label])=>'<button type="button" data-ks-guide-department="articoli.aspx?st='+id+'" aria-pressed="false">'+label+'</button>').join(''));
  block=block.replace(/<asp:Repeater ID="rptHomeAiQuickLinks"[\s\S]*?<\/asp:Repeater>/g,sectors.map(([id,label])=>'<a href="articoli.aspx?st='+id+'">'+label+'</a>').join(''));
  if(mode==='no-departments')block=block.replace(/<asp:Panel ID="HomeAiExamplesPanel"[\s\S]*?<\/asp:Panel>/,'');
  block=block.replace(/<asp:Panel[^>]*CssClass="([^"]*)"[^>]*>/g,'<div class="$1">').replace(/<\/asp:Panel>/g,'</div>');
  assert.ok(!block.includes('<%')&&!block.includes('<asp:'));
  return '<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Fixture '+kind+'</title>'+
    styles.map(n=>'<link rel="stylesheet" href="'+directory+'Public/assets/keepstore/css/'+n+'">').join('')+decisionStyle+
    '</head><body class="ks-page-home"><form id="form1"><header class="container"><a class="ks-guide-entry" href="#KsLocalAiSearch130">Guida agli acquisti</a></header><main>'+block+'</main></form>'+
    (mode==='missing'?'':'<script src="'+directory+'Public/assets/keepstore/js/ks-shopping-guide.js"></script>')+
    '<script src="'+directory+'Public/assets/keepstore/js/home-default.js"></script></body></html>';
}
if(!mediaOnly&&!handoffOnly&&!baselineVisualOnly&&!advisorOnly){
const paths=api.urls('https://tenant1.invalid/store/','/store/search_suggest.aspx');
for(const raw of ['iPhone 15','SSD 1 TB','olio da 1 litro','8000000000120','SKU-500'])record('product is not command '+raw,api.parseCommand(raw).kind==='unknown');
for(const raw of ['massimo 1.000 euro','massimo 1,000 euro','fino a 1e3 euro','massimo -5 euro','massimo 0 euro'])record('ambiguous amount clarified '+raw,api.parseCommand(raw).kind==='clarify');
record('comma decimal explicit',api.parseCommand('massimo 500,50 euro').patch.pmax==='500.5');
record('dot decimal explicit',api.parseCommand('fino a 500.50 euro').patch.pmax==='500.5');
for(const raw of ['solo disponibili','includi non disponibili','senza limite di prezzo','prima i meno costosi','ordina per pertinenza'])record('controlled grammar '+raw,api.parseCommand(raw).kind==='patch');
record('undo command',api.parseCommand('annulla').kind==='annulla');record('reset command',api.parseCommand('ricomincia').kind==='ricomincia');
record('combined limit accepted',api.queryText('x'.repeat(40),'y'.repeat(39)).length===80);
assert.throws(()=>api.queryText('x'.repeat(41),'y'.repeat(39)));record('combined limit rejected without truncation');
const pureBrief=Object.assign(api.blank(),{q:'SKU120'}), pureURL=api.requestURL(pureBrief,paths), pure=payload(pureURL);
record('real server metadata contract accepted',api.validate(server[0].payload,pureBrief,paths).items.length===1);
record('server equal prices independent fixture lists',new Set(server.map(x=>x.payload.suggestions[0].price)).size===1 && new Set(server.map(x=>x.expectedList)).size===4);
record('server sample metadata excludes commercial identifiers',server.every(x=>Object.keys(x.payload.guided).sort().join(',')==='criteria,displayLabel,limit,returnedCount,selectionLimited,version'));
const invalid = [
 ['missing metadata',p=>delete p.guided],['metadata version',p=>p.guided.version=2],['metadata criteria',p=>p.guided.criteria.st=77],
 ['metadata oversized',p=>p.guided.displayLabel='x'.repeat(101)],['invented fiscal label',p=>p.guided.displayLabel='Prezzo migliore'],
 ['metadata tenant leak',p=>p.guided.company=1],['wrong count',p=>p.total=1000],['global count claim',p=>p.guided.selectionLimited=false],
 ['too many results',p=>p.suggestions=Array(7).fill(p.suggestions[0])],['duplicate pair',p=>p.suggestions[1]=clone(p.suggestions[0])],
 ['missing price',p=>delete p.suggestions[0].price],['invalid price',p=>p.suggestions[0].priceValue=0],['partial stock',p=>delete p.suggestions[0].availability],
 ['cross origin PDP',p=>p.suggestions[0].url='https://external.invalid/articolo.aspx?id=120&TCId=42'],
 ['bad variant',p=>p.suggestions[0].TCId=-2],['mismatched variant URL',p=>p.suggestions[0].url='articolo.aspx?id=120&TCId=43'],
 ['duplicate PDP key',p=>p.suggestions[0].url+='&id=120'],['PDP query injection',p=>p.suggestions[0].url+='&owner=3'],
 ['wrong catalog filter',p=>p.catalogUrl+='&listino=1'],['oversized title',p=>p.suggestions[0].title='x'.repeat(501)]
];
for(const [name,mutate] of invalid){const p=clone(pure);mutate(p);assert.throws(()=>api.validate(p,pureBrief,paths));record('schema rejects '+name);}
const variant=clone(pure);variant.suggestions[1].id=120;variant.suggestions[1].url='articolo.aspx?id=120&TCId=43';
record('same article distinct variants retained',api.validate(variant,pureBrief,paths).items.length===3);
record('same-origin virtual request',new URL(pureURL).pathname==='/store/search_suggest.aspx');
record('no commercial identity from browser',!/[?&](?:owner|listino|azienda|login|recent|tcid)=/i.test(pureURL));
const baselineHome=cp.execFileSync('git',['show','f39958753a017ee3a7dee6141339e93918010399:Public/assets/keepstore/js/home-default.js'],{cwd:root,encoding:'utf8'}).replace(/\r\n/g,'\n');
const stripBridge=s=>s.replace(/\r\n/g,'\n').replace(/  \/\/ (?:This guide prepares catalog navigation only;|Page-scoped module;)[\s\S]*?(?=  function initHome\(\))/,'');
record('Swiper menu recent controllers byte preserved',stripBridge(homeSource)===stripBridge(baselineHome));
record('no nested form in section',!/<form\b/i.test(guidemarkup));
record('readonly session directive preserved',/EnableSessionState="ReadOnly"/i.test(read('search_suggest.aspx')));
}
// Two-pixel RGBA PNG, constructed entirely in memory; no operational image file.
function syntheticPNG() {
  const chunk=(type,data)=>{
    const bytes=Buffer.concat([Buffer.from(type),data]);let crc=0xffffffff;
    for(const byte of bytes){crc^=byte;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}
    const size=Buffer.alloc(4),sum=Buffer.alloc(4);size.writeUInt32BE(data.length);sum.writeUInt32BE((crc^0xffffffff)>>>0);
    return Buffer.concat([size,bytes,sum]);
  };
  const header=Buffer.alloc(13);header.writeUInt32BE(2,0);header.writeUInt32BE(1,4);header[8]=8;header[9]=6;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),
    chunk('IDAT',require('node:zlib').deflateSync(Buffer.from([0,20,100,180,255,180,100,20,255]))),chunk('IEND',Buffer.alloc(0))]);
}
const mediaPNG=syntheticPNG();
let browser;
async function fixture(options={}) {
  const directory=options.directory||'/', kind=options.kind||'Tech', host=options.scenario>=2?'tenant2.invalid':'tenant1.invalid';
  const context=await browser.newContext({viewport:{width:options.width||390,height:1000},hasTouch:(options.width||390)<=430,serviceWorkers:'block',javaScriptEnabled:options.js!==false,reducedMotion:'reduce'});
  const page=await context.newPage(), requests=[], receiptHeaders=[],pageErrors=[], blocked=[], apiErrors=[], mediaRequests=[], transport=[], payloadBytes=[];
  const config={...options};
  page.on('pageerror',e=>pageErrors.push(e.message));
  await page.addInitScript(({ignoreAbort,fastTimeout,initFailure})=>{
    window.__privacy={storage:0,cookies:0,beacons:0,logs:0,fetch:[],aborts:0,recent:0,submits:0};
    for(const name of ['getItem','setItem','removeItem','clear'])Storage.prototype[name]=function(){window.__privacy.storage++;throw new Error('STORAGE_FORBIDDEN');};
    Object.defineProperty(document,'cookie',{configurable:true,get(){window.__privacy.cookies++;throw new Error('COOKIE_READ_FORBIDDEN');},set(){window.__privacy.cookies++;throw new Error('COOKIE_WRITE_FORBIDDEN');}});
    navigator.sendBeacon=()=>{window.__privacy.beacons++;return false;};
    for(const name of ['log','info','warn','error'])console[name]=()=>{window.__privacy.logs++;};
    window.KeepStoreRecentlyViewed={render(){window.__privacy.recent++;}};
    document.addEventListener('submit',e=>{window.__privacy.submits++;e.preventDefault();});
    const realFetch=window.fetch.bind(window);
    window.fetch=(url,opts)=>{window.__privacy.fetch.push({url:String(url),credentials:opts.credentials,cache:opts.cache});if(opts.signal)opts.signal.addEventListener('abort',()=>window.__privacy.aborts++);return realFetch(url,ignoreAbort?{...opts,signal:undefined}:opts);};
    const measuredFetch=window.fetch;
    window.fetch=(...args)=>{window.__fixtureStarted=performance.now();return measuredFetch(...args);};
    document.addEventListener('DOMContentLoaded',()=>{
      const root=document.getElementById('KsLocalAiSearch130');
      if(!root)return;
      new MutationObserver(()=>{
        if(root.getAttribute('data-ks-guide-state')==='results'&&window.__fixtureStarted){
          window.__fixtureRender={ms:performance.now()-window.__fixtureStarted,sectionNodes:root.querySelectorAll('*').length,cards:root.querySelectorAll('.ks-guide-card').length};
          window.__fixtureStarted=0;
        }
      }).observe(root,{subtree:true,childList:true,attributes:true,attributeFilter:['data-ks-guide-state']});
    });
    if(fastTimeout){const timer=window.setTimeout.bind(window);window.setTimeout=(fn,ms,...args)=>timer(fn,ms===8000?80:ms,...args);}
    if(initFailure)window.AbortController=undefined;
  },{ignoreAbort:!!options.ignoreAbort,fastTimeout:!!options.fastTimeout,initFailure:options.mode==='failure'});
  await context.route('**/*',async route=>{
    const req=route.request(),url=new URL(req.url());
    transport.push({origin:url.origin,path:url.pathname,method:req.method(),type:req.resourceType()});
    try{
      if(options.mediaTest&&req.resourceType()==='image'){
        mediaRequests.push({url:req.url(),method:req.method()});
        if(url.origin!==('https://'+host)){blocked.push(url.origin);await route.abort();return;}
        const exists=(config.mediaAssets||[]).includes(url.pathname);
        await route.fulfill({status:exists?200:404,headers:{'Cache-Control':'no-store'},contentType:exists?'image/png':'text/plain',body:exists?mediaPNG:'Synthetic missing image'});return;
      }
      if(url.origin!==('https://'+host)){blocked.push(url.origin);await route.abort();return;}
      if(url.pathname===directory+'Default.aspx'){await route.fulfill({contentType:'text/html; charset=utf-8',body:html(directory,kind,options.mode)});return;}
      const assetKey=url.pathname.slice((directory+'Public/assets/keepstore/').length);
      if(url.pathname.startsWith(directory+'Public/assets/keepstore/')&&assets.has(assetKey)){
        await route.fulfill({contentType:assetKey.endsWith('.js')?'application/javascript; charset=utf-8':'text/css; charset=utf-8',body:assets.get(assetKey)});return;
      }
      if(url.pathname===directory+'search_suggest.aspx'){
        requests.push(req.url());
        const receiptHeader=req.headers()['x-keepstore-advisor-criteria'];receiptHeaders.push(receiptHeader?JSON.parse(receiptHeader):[]);
        const current={...config};
        if(current.delay)await new Promise(resolve=>setTimeout(resolve,current.delay));
        if(current.offline){await route.abort('internetdisconnected');return;}
        if(current.html){await route.fulfill({contentType:'text/html',body:'<html>synthetic unavailable</html>'});return;}
        if(options.advisor&&current.status===403){await route.fulfill({status:403,contentType:'application/json',body:'{"ok":false,"error":"synthetic_context_unavailable"}'});return;}
        let response=options.advisor && url.searchParams.get('mode')==='guided2' ? advisorPayload(req.url(),current) : payload(req.url(),{...current,food:kind==='Food'});
        payloadBytes.push({request:Buffer.byteLength(req.url()),response:Buffer.byteLength(current.raw||JSON.stringify(response))});
        await route.fulfill({status:current.status||200,contentType:'application/json',body:current.raw||JSON.stringify(response)});return;
      }
      if(url.pathname===directory+'articoli.aspx'&&options.catalogFirst){
        await route.fulfill({contentType:'text/html; charset=utf-8',body:catalogHtml(directory,options.catalogTarget,options.queryText)});return;
      }
      if(url.pathname===directory+'articolo.aspx'||url.pathname===directory+'articoli.aspx'){
        await route.fulfill({contentType:'text/html',body:'<p>Offline navigation target</p>'});return;
      }
      // Referenced theme media/fonts remain blocked; no operational asset is read.
      blocked.push(url.pathname);await route.abort();
    }catch(e){apiErrors.push(e.message);}
  });
  await page.goto('https://'+host+(options.catalogFirst ? directory+'articoli.aspx?q=fixture' : directory+'Default.aspx'+(options.search||'')+(options.search?'#KsLocalAiSearch130':'')));
  const state=()=>page.locator('#KsLocalAiSearch130').getAttribute('data-ks-guide-state');
  const wait=async value=>{await page.waitForFunction(v=>document.getElementById('KsLocalAiSearch130').getAttribute('data-ks-guide-state')===v,value,{timeout:6000});};
  const submit=async(q='SKU120')=>{await page.locator('#ksGuideQuery').fill(q);await page.locator('[data-ks-guide-prepare]').click();await wait(config.empty?'empty':config.status===403||config.status===421?'context-invalid':config.status||config.raw||config.html||config.offline?'error':'results');};
  const refine=async cmd=>{await page.locator('#ksGuideCommand').fill(cmd);await page.locator('[data-ks-guide-apply]').click();await wait('results');};
  const privacy=async()=>{const p=await page.evaluate(()=>window.__privacy);record('memory-only privacy '+kind+' '+options.width,p.storage+p.cookies+p.beacons+p.logs+p.submits===0);record('fetch session/no-store policy',p.fetch.every(x=>x.credentials==='same-origin'&&x.cache==='no-store'));record('network contains only brief allowlist',p.fetch.every(x=>Array.from(new URL(x.url).searchParams.keys()).every(k=>['q','st','pmin','pmax','disponibile','ordinamento','limit','mode',...(options.advisor?['criteria','skipped','receipts']:[])].includes(k))));record('no external request attempted',transport.every(x=>x.origin==='https://'+host));record('no mutative HTTP attempted',transport.every(x=>x.method==='GET'));record('no application page error',pageErrors.length===0);record('HOME recent render hook preserved',p.recent>0);};
  const screenshot=async(name,selector='#KsLocalAiSearch130')=>{const file=path.join(evidence,name+'.png');await page.locator(selector).screenshot({path:file,animations:'disabled'});journal.resources.push(file);report.screenshots.push(file);};
  const close=async()=>{await context.close();journal.contextsClosed++;};
  return {context,page,config,requests,receiptHeaders,pageErrors,blocked,apiErrors,mediaRequests,transport,payloadBytes,state,wait,submit,refine,privacy,screenshot,close};
}
async function run() {
  if(process.argv.includes('--need-to-choice-only')){
    report.suite='Need-to-choice delta only';
    browser=await playwright.chromium.launch({executablePath:chrome,headless:true});report.browser=await browser.version();
    await needToChoiceRegressions(); report.status='PASS';return;
  }
  browser=await playwright.chromium.launch({executablePath:chrome,headless:!handoffOnly,args:['--disable-background-networking','--disable-component-update','--no-first-run']});
  report.browser=await browser.version();
  if(advisorOnly){await advisorRegressions();report.status='PASS';return;}
  if(baselineVisualOnly){
    report.viewports=[390,1365];
    for(const width of report.viewports){const f=await fixture({width});try{await f.submit();await f.page.locator('[data-ks-guide-compare-key]').nth(0).check();await f.page.locator('[data-ks-guide-compare-key]').nth(1).check();await f.screenshot('baseline-Tech-'+width+'-workspace');await f.privacy();}finally{await f.close();}}
    report.status='PASS';return;
  }
  if(decisionOnly){await decisionRegressions();report.status='PASS';return;}
  if(handoffOnly){await catalogHandoffRegressions();report.status='PASS';return;}
  if(mediaOnly){await mediaRegressions();report.status='PASS';return;}
  await rev1Regressions();
  if(regressionsOnly){report.status='PASS';return;}
  await mediaRegressions();
  await decisionRegressions();
  for(const kind of ['Tech','Food'])for(const width of report.viewports){
    const scenario=(report.viewports.indexOf(width)+(kind==='Food'?2:0))%4;
    const f=await fixture({kind,width,scenario,long:width===360});
    try{
      record('startup zero requests '+kind+width,f.requests.length===0);
      await f.page.locator('#ksGuideQuery').focus();await f.page.locator('#ksGuideQuery').fill(kind==='Food'?'olio da 1 litro':'SSD 1 TB');
      record('typing/focus zero requests '+kind+width,f.requests.length===0);
      const start=performance.now();await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('results');report.renderMs.push({kind,width,ms:Math.round((performance.now()-start)*100)/100});
      record('one explicit request '+kind+width,f.requests.length===1);
      record('results preserve triggering focus '+kind+width,await f.page.locator('[data-ks-guide-prepare]').evaluate(e=>e===document.activeElement));
      record('three grounded cards '+kind+width,await f.page.locator('.ks-guide-card').count()===3);
      (report.domSamples ||= []).push({kind,width,...await f.page.evaluate(()=>window.__fixtureRender)});
      record('uniform known criteria do not cause an irrelevant question '+kind+width,await f.page.locator('.ks-guide-question').count()===0);
      record('subset count copy '+kind+width,(await f.page.locator('[data-ks-guide-results]').innerText()).includes('Non è il totale del catalogo'));
      record('no misleading food or ranking claims '+kind+width,!/migliore per te|allergen|confidenza|probabilità|garantit/i.test(await f.page.locator('[data-ks-guide-results]').innerText()));
      await f.refine('solo disponibili');record('availability request '+kind+width,new URL(f.requests.at(-1)).searchParams.get('disponibile')==='1');
      await f.refine('massimo 500,50 euro');record('budget request '+kind+width,new URL(f.requests.at(-1)).searchParams.get('pmax')==='500.5');
      await f.refine('prima i meno costosi');record('ordering request '+kind+width,new URL(f.requests.at(-1)).searchParams.get('ordinamento')==='p_basso');
      const before=f.requests.length;await f.page.locator('[data-ks-guide-undo]').click();await f.wait('results');
      record('undo fresh request '+kind+width,f.requests.length===before+1&&!new URL(f.requests.at(-1)).searchParams.has('ordinamento'));
      await f.page.locator('[data-ks-guide-compare-key]').nth(0).check();await f.page.locator('[data-ks-guide-compare-key]').nth(1).check();
      record('compare two current items '+kind+width,await f.page.locator('.ks-guide-compare-item').count()===2);
      await f.page.locator('[data-ks-guide-compare-key]').nth(2).check();
      record('compare three with missing data '+kind+width,await f.page.locator('.ks-guide-compare-item').count()===3&&(await f.page.locator('[data-ks-guide-comparison]').innerText()).includes('Dato non disponibile'));
      record('comparison row/column semantics '+kind+width,await f.page.locator('.ks-guide-compare-grid tbody th[scope="row"]').count()>=7&&await f.page.locator('.ks-guide-compare-item[scope="col"]').count()===3);
      if(width>=768){const tops=await f.page.locator('.ks-guide-price').evaluateAll(items=>items.map(e=>e.getBoundingClientRect().top));record('card price rows align '+kind+width,Math.abs(tops[0]-tops[1])<1);}
      const dims=await f.page.evaluate(()=>({w:innerWidth,doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,targets:[...document.querySelectorAll('#KsLocalAiSearch130 button:not([disabled]),#KsLocalAiSearch130 a,#KsLocalAiSearch130 .ks-guide-check')].filter(e=>e.getClientRects().length).map(e=>({tag:e.tagName,h:e.getBoundingClientRect().height}))}));
      record('no page horizontal overflow '+kind+width,dims.doc<=dims.w+1&&dims.body<=dims.w+1);
      record('44px applicable touch targets '+kind+width,dims.targets.every(x=>x.h>=43.9));
      if([360,390,768,1365].includes(width))await f.screenshot(kind+'-'+width+'-compare');
      const catalog=await f.page.getByRole('link',{name:'Continua nel catalogo con queste preferenze'}).getAttribute('href');
      record('catalog exact confirmed criteria '+kind+width,new URL(catalog).searchParams.get('pmax')==='500.5'&&new URL(catalog).searchParams.get('disponibile')==='1');
      const pdp=await f.page.getByRole('link',{name:'Vai alla scheda e acquista',exact:true}).first().getAttribute('href');
      record('PDP identity '+kind+width,new URL(pdp).searchParams.get('id')==='120'&&new URL(pdp).searchParams.get('TCId')==='42');
      await f.privacy();
      const destination=width===390||width===1365?'Vai alla scheda e acquista':'Continua nel catalogo con queste preferenze';
      await f.page.getByRole('link',{name:destination,exact:true}).first().click();
      record('complete flow navigation '+kind+width+' '+server[scenario].scenario,new URL(f.page.url()).pathname===(destination==='Vai alla scheda e acquista'?'/articolo.aspx':'/articoli.aspx'));
    }finally{await f.close();}
  }
  // Real serialized endpoint samples, all four commercial fixture contexts, virtual path.
  for(let scenario=0;scenario<4;scenario++){
    const f=await fixture({scenario,directory:'/shop/',count:1,mutate:p=>Object.assign(p,clone(server[scenario].payload))});
    try{await f.submit();record('real endpoint JSON renders '+scenario,await f.page.locator('.ks-guide-card').count()===1);
      record('virtual-directory request '+scenario,new URL(f.requests[0]).pathname==='/shop/search_suggest.aspx');
      await f.page.getByRole('link',{name:'Vai alla scheda e acquista',exact:true}).click();
      record('explicit PDP navigation '+scenario,new URL(f.page.url()).pathname==='/shop/articolo.aspx');
    }finally{await f.close();}
  }
  const flow=await fixture();
  try{
    await flow.submit();
    await flow.page.locator('#ksGuideCommand').fill('massimo 1.000 euro');const n=flow.requests.length;
    await flow.page.locator('[data-ks-guide-apply]').click();
    record('ambiguous command no request',flow.requests.length===n&&(await flow.page.locator('[data-ks-guide-status]').innerText()).includes('senza separatori'));
    await flow.page.locator('#ksGuideCommand').fill('iPhone 15');await flow.page.locator('[data-ks-guide-apply]').click();
    record('unknown command does not replace query',flow.requests.length===n&&(await flow.page.locator('#ksGuideQuery').inputValue())==='SKU120');
    await flow.page.locator('[data-ks-guide-new-query]').click();await flow.wait('results');
    record('explicit new query accepted',new URL(flow.requests.at(-1)).searchParams.get('q')==='iPhone 15');
    await flow.page.locator('#ksGuideQuery').fill('x'.repeat(50));await flow.page.locator('#ksGuideDetail').fill('y'.repeat(40));
    await flow.page.locator('[data-ks-guide-prepare]').click();
    record('UI combined 80 limit no request',flow.requests.length===n+1&&await flow.page.locator('#ksGuideQuery').getAttribute('aria-invalid')==='true');
    await flow.page.locator('#ksGuideDetail').fill('');await flow.page.locator('#ksGuideQuery').fill('SKU IME');
    await flow.page.locator('#ksGuideQuery').dispatchEvent('keydown',{key:'Enter',isComposing:true,keyCode:229});
    record('IME no submit',flow.requests.length===n+1);
    await flow.page.locator('#ksGuideQuery').press('Enter');await flow.wait('results');
    record('Enter explicit search',flow.requests.length===n+2);
    await flow.page.locator('[data-ks-guide-prepare]').focus();await flow.page.keyboard.press('Tab');
    record('keyboard focus visible',await flow.page.evaluate(()=>getComputedStyle(document.activeElement).outlineStyle!=='none'));
    await flow.page.locator('[data-ks-guide-department]').nth(1).click();
    record('department immediately clears prices',await flow.page.locator('.ks-guide-price').count()===0);
    await flow.page.locator('[data-ks-guide-prepare]').click();await flow.wait('results');
    record('real department id only',new URL(flow.requests.at(-1)).searchParams.get('st')==='7');
    for(let i=1;i<=10;i++)await flow.refine('massimo '+(200+i)+' euro');
    for(let i=0;i<8;i++){await flow.page.locator('[data-ks-guide-undo]').click();await flow.wait('results');}
    record('history bounded eight briefs',await flow.page.locator('[data-ks-guide-undo]').isDisabled());
    await flow.page.locator('[data-ks-guide-reset]').click();
    record('reset clears prices and controls',await flow.page.locator('.ks-guide-price').count()===0&&(await flow.page.locator('#ksGuideQuery').inputValue())==='');
    await flow.privacy();
  }finally{await flow.close();}
  const race=await fixture({ignoreAbort:true,delay:220});
  try{
    await race.page.locator('#ksGuideQuery').fill('Request A');
    await race.page.locator('[data-ks-guide-prepare]').dispatchEvent('click');await race.page.locator('[data-ks-guide-prepare]').dispatchEvent('click');
    await race.page.waitForFunction(()=>window.__privacy.fetch.length===1);
    record('double click coalesced',race.requests.length===1);
    race.config.delay=10;
    await race.page.locator('#ksGuideQuery').fill('Request B');await race.page.locator('[data-ks-guide-prepare]').click();await race.wait('results');
    await new Promise(resolve=>setTimeout(resolve,280));
    record('late A ignored despite abort ignored',(await race.page.locator('.ks-guide-reason').first().innerText()).includes('Corrispondenza')&&new URL(await race.page.getByRole('link',{name:'Continua nel catalogo con queste preferenze'}).getAttribute('href')).searchParams.get('q')==='Request B');
    race.config.delay=120;await race.page.locator('#ksGuideQuery').fill('Request reset');await race.page.locator('[data-ks-guide-prepare]').click();await race.page.locator('[data-ks-guide-reset]').click();
    await new Promise(resolve=>setTimeout(resolve,170));record('reset blocks late response',await race.page.locator('.ks-guide-price').count()===0);
    await race.privacy();
  }finally{await race.close();}
  for(const failure of [{status:400},{status:403},{status:421},{status:429},{status:503},{offline:true},{html:true},{raw:'{broken'},{raw:JSON.stringify({ok:true})},{raw:' '.repeat(65537)},{delay:220,fastTimeout:true}]){
    const f=await fixture(failure);
    try{
      await f.page.locator('#ksGuideQuery').fill('SKU120');await f.page.locator('[data-ks-guide-prepare]').click();
      await f.wait(failure.status===403||failure.status===421?'context-invalid':'error');
      record('failure hides offers '+Object.keys(failure).join('/')+' '+(failure.status||''),await f.page.locator('.ks-guide-price').count()===0);
      record('error distinct from no results '+(failure.status||'body/network'),!(await f.page.locator('[data-ks-guide-status]').innerText()).includes('non ha restituito risultati'));
      if(failure.status===503)await f.screenshot('error-503');
      await f.privacy();
    }finally{await f.close();}
  }
  const empty=await fixture({empty:true});
  try{
    await empty.submit();await empty.screenshot('empty');
    record('empty no automatic relaxation',empty.requests.length===1);
    empty.config.empty=false;await empty.page.locator('[data-ks-guide-prepare]').click();await empty.wait('results');
    await empty.refine('solo disponibili');empty.config.empty=true;
    await empty.page.locator('[data-ks-guide-prepare]').click();await empty.wait('empty');const n=empty.requests.length;
    record('recovery names only availability',/Includi anche i non disponibili/.test(await empty.page.locator('[data-ks-guide-recovery]').innerText()));
    empty.config.empty=false;await empty.page.getByRole('button',{name:'Applica questa modifica'}).click();await empty.wait('results');
    record('recovery explicit single constraint',empty.requests.length===n+1&&!new URL(empty.requests.at(-1)).searchParams.has('disponibile'));
  }finally{await empty.close();}
  const loading=await fixture({delay:1000});
  try{await loading.page.locator('#ksGuideQuery').fill('SKU120');await loading.page.locator('[data-ks-guide-prepare]').click();await loading.wait('loading');
    record('loading state announces actual activity',await loading.page.locator('#KsLocalAiSearch130').getAttribute('aria-busy')==='true');
    await loading.screenshot('loading');await loading.page.locator('[data-ks-guide-reset]').click();
  }finally{await loading.close();}
  const context=await fixture();
  try{
    await context.submit();await context.page.locator('[data-ks-guide-compare-key]').nth(0).check();await context.page.locator('[data-ks-guide-compare-key]').nth(1).check();
    await context.page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true})));
    record('BFCache clears offer/compare',await context.state()==='context-invalid'&&await context.page.locator('.ks-guide-price,.ks-guide-compare-item').count()===0);
    record('BFCache no automatic refresh',context.requests.length===1);
    await context.page.getByRole('button',{name:'Aggiorna la selezione'}).click();await context.wait('results');
    await context.page.evaluate(()=>window.dispatchEvent(new Event('blur')));
    record('possible other-tab context change invalidates',await context.state()==='context-invalid'&&context.requests.length===2);
  }finally{await context.close();}
  const bounded=await fixture({count:6});
  try{
    await bounded.submit();record('six result ceiling rendered',await bounded.page.locator('.ks-guide-card').count()===6);
    for(let i=0;i<3;i++)await bounded.page.locator('[data-ks-guide-compare-key]').nth(i).check();
    await bounded.page.locator('[data-ks-guide-compare-key]').nth(3).click();
    record('fourth comparison refused',await bounded.page.locator('[data-ks-guide-compare-key]:checked').count()===3&&await bounded.page.locator('.ks-guide-compare-item').count()===3);
    await bounded.refine('massimo 200 euro');record('refinement clears comparison',await bounded.page.locator('.ks-guide-compare-item').count()===0);
    await bounded.page.getByRole('button',{name:'Rimuovi Massimo: 200 €',exact:true}).click();await bounded.wait('results');
    record('budget chip removes only explicit budget',!new URL(bounded.requests.at(-1)).searchParams.has('pmax'));
    record('removed chip leaves predictable focus',await bounded.page.locator('[data-ks-guide-prepare]').evaluate(e=>e===document.activeElement));
    record('defaults are informational not fake remove actions',await bounded.page.locator('.ks-guide-chip-default').count()===4);
    await bounded.refine('prima i meno costosi');await bounded.refine('ordina per pertinenza');
    record('relevance restores server default',!new URL(bounded.requests.at(-1)).searchParams.has('ordinamento'));
    await bounded.refine('solo disponibili');await bounded.refine('includi non disponibili');
    record('availability removed explicitly',!new URL(bounded.requests.at(-1)).searchParams.has('disponibile'));
    await bounded.refine('massimo 300 euro');await bounded.refine('senza limite di prezzo');
    record('price limit removed explicitly',!new URL(bounded.requests.at(-1)).searchParams.has('pmax'));
    await bounded.page.getByRole('button',{name:'Rimuovi Ricerca: SKU120',exact:true}).click();
    record('query chip removes results and query',await bounded.page.locator('.ks-guide-price').count()===0&&(await bounded.page.locator('#ksGuideQuery').inputValue())==='');
    await bounded.page.locator('[data-ks-guide-undo]').click();await bounded.wait('results');
    record('undo query removal fetches fresh',new URL(bounded.requests.at(-1)).searchParams.get('q')==='SKU120');
    await bounded.page.evaluate(()=>window.dispatchEvent(new Event('resize')));
    await new Promise(resolve=>setTimeout(resolve,200));const n=bounded.requests.length;
    await bounded.page.locator('[data-ks-guide-prepare]').click();await bounded.wait('results');
    record('idempotent HOME resize initialization',bounded.requests.length===n+1);
    await bounded.privacy();
  }finally{await bounded.close();}
  const images=await fixture({mutate:p=>{p.suggestions[0].image='Public/assets/images/articoli/synthetic-missing.jpg';p.suggestions[0].image_fallback='Public/assets/images/articoli/synthetic-fallback.jpg';}});
  try{await images.submit();await images.page.waitForFunction(()=>document.querySelector('.ks-guide-card .ks-guide-media').textContent.includes('Immagine non disponibile'));
    record('broken image fallback terminates locally',images.blocked.filter(x=>x.includes('synthetic-')).length===2);
    const n=images.requests.length;await images.page.locator('#ksGuideQuery').fill('bozza diversa');
    await images.page.locator('[data-ks-guide-command="solo disponibili"]').click();
    record('refinement does not discard draft',images.requests.length===n&&(await images.page.locator('#ksGuideQuery').inputValue())==='bozza diversa');
  }finally{await images.close();}
  const hostile=await fixture({mutate:p=>{p.suggestions[0].title='<img src=x onerror=window.pwn=1>';p.suggestions[0].image='https://external.invalid/private.jpg';p.suggestions[0].brand='<script>bad()</script>';}});
  try{await hostile.submit();record('XSS rendered as text',await hostile.page.locator('.ks-guide-card').first().locator('h4').innerText()==='<img src=x onerror=window.pwn=1>'&&await hostile.page.evaluate(()=>!window.pwn));
    record('external image neutral fallback',hostile.blocked.every(x=>!x.includes('external.invalid')));
    await hostile.page.getByRole('link',{name:'Continua nel catalogo con queste preferenze'}).click();
    record('explicit catalog navigation',new URL(hostile.page.url()).pathname==='/articoli.aspx');
  }finally{await hostile.close();}
  for(const mode of ['missing','failure','no-js']){
    const f=await fixture({mode,js:mode!=='no-js'});
    try{record('fallback fields disabled/hidden '+mode,await f.page.locator('[data-ks-guide-fields]').evaluate(e=>e.disabled&&e.hidden)&&!await f.page.locator('[data-ks-guide-fields]').isVisible());
      record('fallback catalog/departments usable '+mode,await f.page.getByRole('link',{name:'Esplora tutto il catalogo'}).isVisible()&&await f.page.locator('.ks-guide-fallback-departments a').count()===2&&f.requests.length===0);
    }finally{await f.close();}
  }
  for(const rel of ['Public/assets/keepstore/js/home-default.js','Public/assets/keepstore/css/theme-overrides.css']){
    const before=cp.execFileSync('git',['show','f39958753a017ee3a7dee6141339e93918010399:'+rel],{cwd:root});
    (report.bytes ||= []).push({file:rel,base:Buffer.byteLength(before.toString().replace(/\r\n/g,'\n')),candidate:Buffer.byteLength(read(rel).replace(/\r\n/g,'\n'))});
  }
  report.bytes.push({file:'Public/assets/keepstore/js/ks-shopping-guide.js',base:0,candidate:Buffer.byteLength(moduleSource.replace(/\r\n/g,'\n'))});
  report.maximumCards=6;report.storage='zero';report.status='PASS';
}
async function needToChoiceRegressions() {
  const brief=api.blank();
  for(const [raw,q] of [['Cerco SSD 1 TB','SSD 1 TB'],['Mi serve olio da 1 litro','olio da 1 litro'],['Vorrei SKU-500','SKU-500'],['Cerco non ricondizionato','non ricondizionato']])record('literal need '+raw,api.interpretNeed(raw).query===q);
  record('model numbers not budget',!api.interpretNeed('Cerco iPhone 15 500 GB').patch.pmax);
  record('cost need changes ordering',api.interpretNeed('Cerco SSD; spendere meno').patch.ordinamento==='p_basso');
  record('availability need changes selection',api.interpretNeed('Cerco SSD; escludere indisponibili').patch.disponibile===true);
  record('budget contradiction explicit',api.interpretNeed('Cerco SSD; massimo 100 euro; massimo 200 euro').conflicts.length===1);
  for(const raw of ['Ho bisogno di stampante compatibile; 500 pagine/mese; consumabili economici','Cerco olio senza allergeni; ingredienti certificati'])record('specific unsupported requirement '+raw,api.interpretNeed(raw).limits.length>0);
  const mixed=[{priceValue:10,price:'10 €',availability:2},{priceValue:20,price:'20 €',availability:0}];
  record('stock question from actual difference',api.chooseQuestion(mixed,brief,[]).key==='stock');
  record('price question from actual difference',api.chooseQuestion(mixed.map(x=>({...x,availability:2})),brief,[]).key==='budget');
  record('uniform data no question',api.chooseQuestion([mixed[0],mixed[0]],brief,[])===null);
  record('one candidate no fabricated comparison',api.chooseQuestion([mixed[0]],brief,[])===null);
  record('skipped question not repeated',api.chooseQuestion(mixed,brief,['stock']).key!=='stock');
  for(const kind of ['Tech','Food'])for(const width of report.viewports)for(const preference of ['prima i meno costosi','solo disponibili']){
    const scenario=(kind==='Food'?2:0)+report.viewports.indexOf(width)%2, q=kind==='Food'?'olio da 1 litro':'SSD 1 TB';
    const f=await fixture({kind,width,scenario,directory:width===430?'/shop/':'/',mutate:p=>p.suggestions.forEach((x,i)=>{x.priceValue=10+i;x.price=(10+i)+',00 €';x.availability=7;})});
    try{
      await f.page.locator('#ksGuideGoal').fill('Cerco '+q+'; '+preference);
      if(width<=430)await f.page.locator('[data-ks-guide-understand]').tap();else await f.page.locator('[data-ks-guide-understand]').click();
      record('understanding never searches '+kind+width+preference,f.requests.length===0);
      await f.page.getByRole('button',{name:'Usa questa proposta nel brief',exact:true}).click();
      record('proposal no request and no rewrite '+kind+width+preference,f.requests.length===0&&await f.page.locator('#ksGuideQuery').inputValue()===q);
      await f.page.locator('[data-ks-guide-prepare]').press('Enter');await f.wait('results');
      const request=new URL(f.requests[0]);record('counterfactual confirmed criteria '+kind+width+preference,f.requests.length===1&&(preference==='solo disponibili'?request.searchParams.get('disponibile')==='1':request.searchParams.get('ordinamento')==='p_basso'));
      record('full goal never transmitted '+kind+width,!request.searchParams.has('goal')&&request.searchParams.get('q')===q);
      const dims=await f.page.evaluate(()=>({width:innerWidth,actual:document.documentElement.scrollWidth}));record('need no overflow '+kind+width,dims.actual<=dims.width+1);
      if(preference==='solo disponibili')await f.screenshot('need-'+kind+'-'+width);
      await f.privacy();
    }finally{await f.close();}
  }
  const unknown=await fixture();try{
    await unknown.page.locator('#ksGuideGoal').fill('Organizzare un evento');await unknown.page.locator('[data-ks-guide-understand]').click();
    record('unknown need real taxonomy clarification',unknown.requests.length===0&&await unknown.page.locator('[data-ks-guide-interpretation] button').count()>0);
    await unknown.page.locator('[data-ks-guide-interpretation] button').first().click();
    record('taxonomy choice proposes actual family without fetch',unknown.requests.length===0&&(await unknown.page.locator('#ksGuideQuery').inputValue()).length>0);
    await unknown.page.locator('[data-ks-guide-prepare]').click();await unknown.wait('results');
    const target=await unknown.page.locator('.ks-guide-product-cta').first().getAttribute('href');
    record('family journey exact variant PDP',new URL(target).searchParams.get('id')==='120'&&new URL(target).searchParams.get('TCId')==='42');
    await unknown.privacy();
  }finally{await unknown.close();}
  for(const goal of ['Cerco stampante; 500 pagine/mese; consumabili economici','Cerco olio; ingredienti e allergeni non documentati']){
    const f=await fixture();try{
      await f.page.locator('#ksGuideGoal').fill(goal);await f.page.locator('[data-ks-guide-understand]').click();
      record('unsupported need specific before search '+goal,f.requests.length===0&&(await f.page.locator('[data-ks-guide-interpretation]').innerText()).includes(goal.split('; ')[1]));
      await f.page.getByRole('button',{name:'Continua sui soli criteri supportati',exact:true}).click();
      record('unsupported continuation still a draft '+goal,f.requests.length===0);
      await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('results');
      record('specific missing requirement retained in shortlist '+goal,(await f.page.locator('.ks-guide-card').first().innerText()).includes(goal.split('; ')[1]));
      await f.privacy();
    }finally{await f.close();}
  }
  const pending=await fixture();try{
    await pending.page.locator('#ksGuideGoal').fill('Cerco SSD; solo disponibili');
    await pending.page.locator('[data-ks-guide-understand]').click();await pending.page.getByRole('button',{name:'Usa questa proposta nel brief',exact:true}).click();
    await pending.page.locator('[data-ks-guide-prepare]').click();await pending.wait('results');
    await pending.page.getByRole('button',{name:'Rimuovi Solo disponibili',exact:true}).click();await pending.wait('results');
    await pending.page.locator('[data-ks-guide-understand]').click();await pending.page.getByRole('button',{name:'Usa questa proposta nel brief',exact:true}).click();
    const n=pending.requests.length;
    record('reproposed criterion remains a draft',await pending.page.locator('[data-ks-guide-draft-review]').getAttribute('aria-label')==='Brief da confermare');
    await pending.page.locator('[data-ks-guide-command="prima i meno costosi"]').click();
    record('unconfirmed proposed criteria cannot be overwritten',pending.requests.length===n);
    await pending.page.locator('[data-ks-guide-prepare]').click();await pending.wait('results');
    record('reproposed criterion applies only on confirmation',pending.requests.length===n+1&&new URL(pending.requests.at(-1)).searchParams.get('disponibile')==='1');
    await pending.page.locator('#ksGuideGoal').fill('Cerco SSD; senza limite di prezzo');
    await pending.page.locator('[data-ks-guide-understand]').click();await pending.page.getByRole('button',{name:'Usa questa proposta nel brief',exact:true}).click();
    record('unlimited proposal leaves a valid empty budget',await pending.page.locator('#ksGuideBudget').inputValue()==='');
    await pending.page.locator('[data-ks-guide-prepare]').click();await pending.wait('results');
    record('unlimited proposal confirms without a price filter',!new URL(pending.requests.at(-1)).searchParams.has('pmax'));
    await pending.privacy();
  }finally{await pending.close();}
}
async function decisionRegressions() {
  const paths=api.urls('https://tenant1.invalid/store/','/store/search_suggest.aspx');
  const plain=Object.assign(api.blank(),{q:'SKU120'}), raw=payload(api.requestURL(plain,paths));
  const old=sourceApi(baselineSource('Public/assets/keepstore/js/ks-shopping-guide.js'));
  record('decision helpers available',typeof api.evidence==='function'&&typeof api.decision==='function');
  record('scoped decision style included',decisionStyle.includes('#KsLocalAiSearch130'));
  const constraints=[
    ['over maximum',{pmax:'100'},p=>p.suggestions.forEach(x=>{x.priceValue=122;x.price='122,00 €';})],
    ['under minimum',{pmin:'200'},p=>p.suggestions.forEach(x=>{x.priceValue=122;x.price='122,00 €';})],
    ['unavailable while required',{disponibile:true},p=>p.suggestions[0].availability=0],
    ['unknown availability while required',{disponibile:true},p=>p.suggestions[0].availability=null]
  ];
  for(const [name,patch,mutate] of constraints){
    const brief=Object.assign({},plain,patch), response=payload(api.requestURL(brief,paths),{mutate});
    record('baseline reproduces unverified constraint '+name,old.validate(response,brief,paths).items.length===3);
    assert.throws(()=>api.validate(response,brief,paths));record('candidate fails closed on '+name);
  }
  const item=api.validate(raw,plain,paths).items[0];
  record('numeric display price retained for current comparison',item.priceValue===raw.suggestions[0].priceValue);
  record('exact code is verified evidence',api.evidence(item,plain).exactCode===true);
  const match=api.evidence({...item,title:'Notebook SSD compatto',brand:'Marca esempio',category:'Computer'}, {...plain,q:'SSD allergeni'});
  record('visible term matched with evidence',match.matched.some(x=>x.term.toLowerCase()==='ssd'));
  record('unsupported term explicitly unverified',match.unverified.some(x=>x.toLowerCase()==='allergeni'));
  record('no suitability inferred from text',!('compatible' in match)&&!('recommended' in match));
  const samples=[{...item,key:'120:42',priceValue:100,price:'100,00 €',availability:0},{...item,key:'121:43',priceValue:150,price:'150,00 €',availability:7},{...item,key:'122:44',priceValue:100,price:'100,00 €',availability:null}];
  const choice=api.decision(samples);
  record('minimum limited to current comparison',choice.minimum===100&&choice.lowest.length===2&&choice.lowest.includes('120:42')&&choice.lowest.includes('122:44'));
  record('comparison exposes factual differences only',Array.isArray(choice.differences)&&choice.differences.length>0);
  const equal=api.decision(samples.map(x=>({...x,priceValue:100,price:'100,00 €'})));
  record('equal prices keep ties instead of invented winner',equal.lowest.length===3);
  report.decisionBaseline={ref:decisionBase,reproducedConstraintGaps:constraints.length,proof:'same synthetic guided responses passed old validator and are refused by candidate'};
  report.decisionMatrix=[];
  for(const kind of ['Tech','Food'])for(const width of report.viewports){
    const scenario=(report.viewports.indexOf(width)+(kind==='Food'?2:0))%4;
    const directory=[390,768,1024].includes(width)?'/shop/':'/';
    const f=await fixture({kind,width,scenario,directory,count:3,mutate:p=>p.suggestions.forEach((x,i)=>{x.priceValue=[122,100,150][i];x.price=['122,00 €','100,00 €','150,00 €'][i];})});
    try{
      const goal=kind==='Food'?'Preparare una cena per gli ospiti':'Organizzare il lavoro in mobilità';
      const query=kind==='Food'?'olio da 1 litro':'SSD 1 TB';
      await f.page.locator('#ksGuideGoal').fill(goal);
      await f.page.locator('#ksGuideQuery').fill(query);
      await f.page.locator('#ksGuideBudget').fill('200,50');
      record('goal/query/budget drafting sends nothing '+kind+width,f.requests.length===0);
      if(width<=430)await f.page.locator('[data-ks-guide-prepare]').tap();else await f.page.locator('[data-ks-guide-prepare]').press('Enter');
      await f.wait('results');
      const sent=new URL(f.requests[0]);
      record('one complete brief request '+kind+width,f.requests.length===1&&sent.searchParams.get('q')===query&&sent.searchParams.get('pmax')==='200.5');
      record('goal is local only '+kind+width,!decodeURIComponent(sent.href).includes(goal)&&!sent.searchParams.has('goal'));
      record('goal review accessible '+kind+width,await f.page.locator('#ksGuideGoal').evaluate(x=>!!document.querySelector('label[for="'+x.id+'"]'))&&await f.page.locator('#ksGuideBudget').evaluate(x=>!!document.querySelector('label[for="'+x.id+'"]')));
      record('confirmed query unchanged by goal '+kind+width,await f.page.locator('#ksGuideQuery').inputValue()===query);
      for(let i=0;i<3;i++)await f.page.locator('[data-ks-guide-compare-key]').nth(i).check();
      record('workspace compares current response '+kind+width,await f.page.locator('.ks-guide-compare-item').count()===3);
      const workspace=await f.page.locator('[data-ks-guide-comparison]').innerText();
      record('workspace explains evidence and limits '+kind+width,/Corrispondenze verificate/.test(workspace)&&/Da verificare/.test(workspace));
      record('no global best or suitability claim '+kind+width,!/migliore del catalogo|migliore per te|compatibilità garantita|senza allergeni|risparmi il/i.test(workspace));
      const dimensions=await f.page.evaluate(()=>({width:innerWidth,document:document.documentElement.scrollWidth,targets:[...document.querySelectorAll('#KsLocalAiSearch130 button,#KsLocalAiSearch130 a,#KsLocalAiSearch130 .ks-guide-check')].filter(x=>x.getClientRects().length&&!x.disabled).map(x=>({height:x.getBoundingClientRect().height,width:x.getBoundingClientRect().width}))}));
      record('decision no horizontal page overflow '+kind+width,dimensions.document<=dimensions.width+1);
      record('decision touch targets '+kind+width,dimensions.targets.every(x=>x.height>=43.9&&x.width>=43.9));
      record('polite status and keyboard focus available '+kind+width,await f.page.locator('[data-ks-guide-status]').getAttribute('aria-live')==='polite');
      await f.screenshot('decision-'+kind+'-'+width+'-workspace');
      if(width===390){await f.screenshot('decision-'+kind+'-390-brief','#KsLocalAiSearch130 .ks-ai130-brain');await f.screenshot('decision-'+kind+'-390-comparison','[data-ks-guide-comparison]');}
      const previous=f.requests.length;
      await f.page.locator('.ks-guide-compare-item').nth(1).getByRole('button',{name:/Rimuovi dal confronto/}).press('Enter');
      record('remove comparison restores associated product focus '+kind+width,await f.page.locator('.ks-guide-compare-item').count()===2&&await f.page.locator('[data-ks-guide-compare-key="121:43"]').evaluate(x=>x===document.activeElement)&&f.requests.length===previous);
      await f.page.getByRole('button',{name:'Correggi una preferenza',exact:true}).press('Enter');
      record('correct preference clears stale snapshot and focuses budget '+kind+width,await f.page.locator('.ks-guide-price,.ks-guide-compare-item').count()===0&&await f.page.locator('#ksGuideBudget').evaluate(x=>x===document.activeElement)&&f.requests.length===previous);
      await f.page.locator('#ksGuideGoal').fill(goal+' domani');
      record('goal edit immediately removes commercial snapshot '+kind+width,await f.page.locator('.ks-guide-price,.ks-guide-compare-item').count()===0&&f.requests.length===previous);
      await f.page.locator('[data-ks-guide-command="solo disponibili"]').click();
      record('goal draft guarded from implicit confirmation '+kind+width,f.requests.length===previous&&await f.page.locator('#ksGuideGoal').inputValue()===goal+' domani');
      await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('results');
      record('explicit revised goal triggers one fresh result '+kind+width,f.requests.length===previous+1&&new URL(f.requests.at(-1)).searchParams.get('q')===query);
      const pdp=await f.page.locator('.ks-guide-card').first().getByRole('link',{name:'Vai alla scheda e acquista',exact:true}).getAttribute('href');
      record('exact variant conversion path '+kind+width,new URL(pdp).pathname===directory+'articolo.aspx'&&new URL(pdp).searchParams.get('id')==='120'&&new URL(pdp).searchParams.get('TCId')==='42');
      const contact=f.page.getByRole('link',{name:/contatt/i}).filter({hasText:/commercial|contatt/i});
      record('commercial contact uses existing page '+kind+width,await contact.count()>0&&(await contact.first().getAttribute('href')).endsWith('Contattaci.aspx'));
      await f.privacy();
      report.decisionMatrix.push({kind,width,scenario:server[scenario].scenario,directory,input:width<=430?'touch tap':'keyboard Enter',requests:f.requests.length,status:'PASS'});
    }finally{await f.close();}
  }
  for(const count of [0,1,2,3,6]){
    const f=await fixture({count,empty:count===0});
    try{await f.submit();record('decision exact result cardinality '+count,await f.page.locator('.ks-guide-card').count()===count&&f.requests.length===1);if(count===0)await f.screenshot('decision-empty');await f.privacy();}finally{await f.close();}
  }
  const ambiguous=await fixture();
  try{
    await ambiguous.page.locator('#ksGuideGoal').fill('Vorrei qualcosa di adatto alla mia esigenza');
    await ambiguous.page.locator('#ksGuideGoal').press('Enter');
    record('goal textarea Enter does not send a request',ambiguous.requests.length===0);
    await ambiguous.page.locator('[data-ks-guide-prepare]').click();
    record('ambiguous goal asks for clarification without rewriting query',ambiguous.requests.length===0&&await ambiguous.page.locator('#ksGuideQuery').inputValue()===''&&await ambiguous.page.locator('.ks-guide-card').count()===0);
    await ambiguous.screenshot('decision-goal-clarification');
    await ambiguous.page.locator('#ksGuideQuery').fill('SKU120');
    for(const value of ['1.000','1,000','1e3','-5','0','500 euro']){
      await ambiguous.page.locator('#ksGuideBudget').fill(value);await ambiguous.page.locator('[data-ks-guide-prepare]').click();
      record('invalid budget requires correction '+value,ambiguous.requests.length===0&&await ambiguous.page.locator('.ks-guide-price').count()===0);
    }
    await ambiguous.page.locator('#ksGuideBudget').fill('500.50');await ambiguous.page.locator('[data-ks-guide-prepare]').click();await ambiguous.wait('results');
    record('valid explicit budget accepted after correction',ambiguous.requests.length===1&&new URL(ambiguous.requests[0]).searchParams.get('pmax')==='500.5');
    const n=ambiguous.requests.length;await ambiguous.page.locator('#ksGuideBudget').fill('600');
    await ambiguous.page.locator('[data-ks-guide-command="solo disponibili"]').click();
    record('budget draft retained and snapshot cleared',ambiguous.requests.length===n&&await ambiguous.page.locator('#ksGuideBudget').inputValue()==='600'&&await ambiguous.page.locator('.ks-guide-price').count()===0);
    await ambiguous.privacy();
  }finally{await ambiguous.close();}
  for(const [name,mutate] of [
    ['foreign tenant URL',p=>p.suggestions[0].url='https://tenant2.invalid/articolo.aspx?id=120&TCId=42'],
    ['variant identity mismatch',p=>p.suggestions[0].url='articolo.aspx?id=120&TCId=999'],
    ['unvalidated output envelope',p=>delete p.guided],
    ['noncommercial numeric price',p=>p.suggestions[0].priceValue=-10]
  ]){
    const f=await fixture({mutate});
    try{await f.page.locator('#ksGuideQuery').fill('SKU120');await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('error');record('negative commercial response hidden '+name,await f.page.locator('.ks-guide-card,.ks-guide-compare-item').count()===0&&f.requests.length===1);if(name==='unvalidated output envelope')await f.screenshot('decision-error');await f.privacy();}finally{await f.close();}
  }
  const claims=await fixture({mutate:p=>{p.suggestions[0].reason='Compatibilità garantita, senza allergeni';p.suggestions[0].recommendation='<img src=x onerror=window.unsupported=1>';}});
  try{await claims.submit();record('unknown provider claims never rendered',!/Compatibilità garantita|senza allergeni/.test(await claims.page.locator('[data-ks-guide-results]').innerText())&&await claims.page.evaluate(()=>!window.unsupported));await claims.privacy();}finally{await claims.close();}
  const punctuation=await fixture();
  try{await punctuation.submit('???');record('punctuation query cannot become positive evidence',(await punctuation.page.locator('.ks-guide-card').first().innerText()).includes('Corrispondenza da verificare'));await punctuation.privacy();}finally{await punctuation.close();}
  const unavailable=await fixture({mutate:p=>{p.suggestions[0].availability=0;p.suggestions[1].availability=null;p.suggestions[2].availability=-1;}});
  try{await unavailable.submit();record('no purchase promise for zero unknown or negative stock',await unavailable.page.locator('.ks-guide-card').getByRole('link',{name:'Scopri questo prodotto',exact:true}).count()===3&&await unavailable.page.locator('.ks-guide-card').getByRole('link',{name:'Vai alla scheda e acquista',exact:true}).count()===0);record('unavailable variant still has exact PDP discovery link',new URL(await unavailable.page.locator('.ks-guide-card').first().getByRole('link',{name:'Scopri questo prodotto',exact:true}).getAttribute('href')).searchParams.get('TCId')==='42');await unavailable.privacy();}finally{await unavailable.close();}
  const recovery=await fixture({empty:true});
  try{
    await recovery.page.locator('#ksGuideQuery').fill('SKU120');await recovery.page.locator('#ksGuideBudget').fill('200');
    await recovery.page.locator('[data-ks-guide-sector="7"]').click();await recovery.page.locator('[data-ks-guide-prepare]').click();await recovery.wait('empty');
    record('empty budget/reparto never relax automatically',recovery.requests.length===1);
    await recovery.page.getByRole('button',{name:'Applica questa modifica',exact:true}).press('Enter');await recovery.wait('empty');
    let latest=briefFrom(recovery.requests.at(-1));
    record('empty recovery removes only budget after explicit action',recovery.requests.length===2&&latest.pmax==='0'&&latest.st===7&&latest.q==='SKU120');
    record('recovery holds stable keyboard focus',await recovery.page.locator('[data-ks-guide-prepare]').evaluate(x=>x===document.activeElement));
    await recovery.page.locator('[data-ks-guide-undo]').click();await recovery.wait('empty');latest=briefFrom(recovery.requests.at(-1));
    record('recovery reversible using fresh authoritative request',recovery.requests.length===3&&latest.pmax==='200'&&latest.st===7);
    await recovery.privacy();
  }finally{await recovery.close();}
  const fresh=await fixture({delay:250,ignoreAbort:true});
  try{
    await fresh.page.locator('#ksGuideQuery').fill('Prima ricerca');await fresh.page.locator('[data-ks-guide-prepare]').click();
    await fresh.page.waitForFunction(()=>window.__privacy.fetch.length===1);
    await fresh.page.locator('#ksGuideGoal').fill('Obiettivo ancora in bozza');
    record('goal edit aborts outstanding request',await fresh.page.evaluate(()=>window.__privacy.aborts===1));
    await new Promise(resolve=>setTimeout(resolve,300));
    record('late response cannot repopulate edited goal',await fresh.page.locator('.ks-guide-price').count()===0&&fresh.requests.length===1);
    fresh.config.delay=0;await fresh.page.locator('[data-ks-guide-prepare]').click();await fresh.wait('results');
    await fresh.page.locator('[data-ks-guide-compare-key]').nth(0).check();await fresh.page.locator('[data-ks-guide-compare-key]').nth(1).check();
    await fresh.page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true})));
    record('decision BFCache discards snapshot without fetch',await fresh.state()==='context-invalid'&&await fresh.page.locator('.ks-guide-price,.ks-guide-compare-item').count()===0&&fresh.requests.length===2);
    fresh.config.mutate=p=>p.suggestions.forEach(x=>{x.availability=0;});
    await fresh.page.getByRole('button',{name:'Aggiorna la selezione',exact:true}).click();await fresh.wait('results');
    record('explicit refresh replaces old stock and comparison',fresh.requests.length===3&&(await fresh.page.locator('.ks-guide-card').first().innerText()).includes('Non disponibile')&&await fresh.page.locator('.ks-guide-compare-item').count()===0);
    await fresh.privacy();
  }finally{await fresh.close();}
  report.decisionLimits=['source validation and all browser responses are synthetic', 'plausible cross-tenant prices, alien variant membership and stock freshness require authoritative server resolver evidence; no browser authenticity claim', 'no real account, IIS/MySQL, purchase, email or external AI call'];
}
async function rev1Regressions() {
  const failures=[];
  const check=(name,value)=>{if(value)record('REV1 '+name);else failures.push(name);};
  const focused=(f,selector)=>f.page.locator(selector).evaluate(e=>e===document.activeElement);
  const fetchCount=f=>f.page.evaluate(()=>window.__privacy.fetch.length);
  const activate=async(f,locator,key)=>{await locator.focus();await f.page.keyboard.press(key);};
  // Every case starts with a real confirmed brief; no state injection or mocked init.
  for(const directory of ['/', '/shop/'])for(const draft of ['product','detail','department','combined','split']){
    const f=await fixture({directory});
    try{
      await f.submit('SSD originale');await f.refine('massimo 200 euro');
      const product=draft==='split'?'SSD':draft==='product'||draft==='combined'?'NUOVO PRODOTTO':'SSD originale';
      const detail=draft==='split'?'originale':draft==='detail'||draft==='combined'?'nuovo dettaglio':'';
      const sector=draft==='department'||draft==='combined'?7:0;
      if(product!=='SSD originale')await f.page.locator('#ksGuideQuery').fill(product);
      if(detail)await f.page.locator('#ksGuideDetail').fill(detail);
      if(sector)await f.page.locator('[data-ks-guide-sector="7"]').click();
      const n=await fetchCount(f), label=directory+' '+draft;
      check('draft preview agrees with separate fields '+label,/da confermare/i.test(await f.page.locator('[data-ks-guide-draft-review]').innerText()));
      check('draft preview accessible name agrees '+label,/non ancora confermat|da confermare|bozza/i.test(await f.page.locator('[data-ks-guide-draft-review]').getAttribute('aria-label')));
      await activate(f,f.page.getByRole('button',{name:'Rimuovi Massimo: 200 €',exact:true}),draft==='detail'?'Space':'Enter');
      check('draft fields retained '+label,await f.page.locator('#ksGuideQuery').inputValue()===product&&await f.page.locator('#ksGuideDetail').inputValue()===detail);
      check('draft department retained '+label,await f.page.locator('[data-ks-guide-sector="'+sector+'"]').getAttribute('aria-pressed')==='true');
      check('draft removal no implicit fetch '+label,await fetchCount(f)===n);
      check('draft budget unchanged '+label,await f.page.getByRole('button',{name:'Rimuovi Massimo: 200 €',exact:true}).count()===1);
      check('draft confirmation explained '+label,(await f.page.locator('[data-ks-guide-status]').innerText()).includes('Mostra i prodotti'));
      // The identical guard must also cover quick commands, including a split product/detail
      // whose concatenation is unchanged. It is still an unconfirmed form edit.
      await f.page.locator('[data-ks-guide-command="solo disponibili"]').click();
      check('command respects same draft guard '+label,await fetchCount(f)===n&&await f.page.locator('#ksGuideDetail').inputValue()===detail);
      if(await fetchCount(f)===n){
        await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('results');
        const applied=briefFrom(f.requests.at(-1));
        check('explicit draft confirmation '+label,applied.q===[product,detail].filter(Boolean).join(' ')&&applied.st===sector&&applied.pmax==='200'&&!applied.disponibile);
        await f.page.locator('[data-ks-guide-undo]').click();await f.wait('results');
        const previous=briefFrom(f.requests.at(-1));
        check('blocked action adds no history '+label,previous.q==='SSD originale'&&previous.st===0&&previous.pmax===(draft==='split'?'0':'200'));
      }
      await f.privacy();
    }finally{await f.close();}
  }
  for(const directory of ['/', '/shop/'])for(const key of ['Enter','Space']){
    const f=await fixture({directory,mutate:p=>{if(!p.guided.criteria.disponibile)p.suggestions[1].availability=0;}});
    try{
      const label=directory+' '+key;
      await f.submit();
      await f.page.locator('[data-ks-guide-compare-key]').nth(0).check();await f.page.locator('[data-ks-guide-compare-key]').nth(1).check();
      const n=await fetchCount(f);
      await activate(f,f.page.getByRole('button',{name:'Svuota confronto',exact:true}),key);
      check('clear comparison focus '+label,await focused(f,'[data-ks-guide-compare-key="120:42"]'));
      check('clear comparison local only '+label,await f.page.locator('[data-ks-guide-compare-key]:checked').count()===0&&await f.page.locator('.ks-guide-compare-item').count()===0&&await fetchCount(f)===n);
      await activate(f,f.page.getByRole('button',{name:'Salta',exact:true}),key);
      check('skip stable focus '+label,await focused(f,'#ksGuideCommand'));
      check('skip no request '+label,await fetchCount(f)===n&&await f.page.locator('.ks-guide-question').count()===0);
      await f.refine('massimo 200 euro');
      await f.page.locator('[data-ks-guide-sector="7"]').click();await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('results');
      check('availability question selected '+label,(await f.page.locator('.ks-guide-question').innerText()).includes('disponibili'));
      f.config.delay=250;
      await activate(f,f.page.getByRole('button',{name:'Scegli questa preferenza',exact:true}),key);
      check('availability stable focus '+label,await focused(f,'#ksGuideCommand'));
      await f.page.locator('#ksGuideQuery').focus();await f.wait('results');
      check('availability response respects moved focus '+label,await focused(f,'#ksGuideQuery')&&briefFrom(f.requests.at(-1)).disponibile);
      f.config.delay=0;f.config.empty=true;
      await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('empty');
      f.config.empty=false;f.config.delay=250;
      await activate(f,f.page.getByRole('button',{name:'Applica questa modifica',exact:true}),key);
      check('empty recovery stable focus '+label,await focused(f,'[data-ks-guide-prepare]'));
      await f.page.locator('#ksGuideQuery').focus();await f.wait('results');
      check('empty response respects moved focus '+label,await focused(f,'#ksGuideQuery')&&!briefFrom(f.requests.at(-1)).disponibile);
      await f.page.locator('#ksGuideCommand').fill('Nuova ricerca esplicita');await f.page.locator('[data-ks-guide-apply]').click();
      await activate(f,f.page.locator('[data-ks-guide-new-query]'),key);
      check('new query stable focus '+label,await focused(f,'[data-ks-guide-prepare]'));
      await f.page.locator('#ksGuideQuery').focus();await f.wait('results');
      check('new query response respects moved focus '+label,await focused(f,'#ksGuideQuery')&&briefFrom(f.requests.at(-1)).q==='Nuova ricerca esplicita');
      f.config.delay=0;f.config.status=503;
      await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('error');
      f.config.status=0;f.config.delay=250;
      await activate(f,f.page.getByRole('button',{name:'Riprova',exact:true}),key);
      check('retry stable focus '+label,await focused(f,'[data-ks-guide-prepare]'));
      await f.page.locator('#ksGuideQuery').focus();await f.wait('results');
      check('retry response respects moved focus '+label,await focused(f,'#ksGuideQuery'));
      await f.privacy();
    }finally{await f.close();}
  }
  report.rev1Failures=failures;
  assert.equal(failures.length,0,'REV1 regressions: '+failures.join('; '));
}
async function mediaRegressions() {
  const failures=[];
  const check=(name,value)=>{if(value)record('REV2 '+name);else failures.push(name);};
  const product='/Public/assets/images/articoli/', host='https://tenant1.invalid';
  report.mediaCases=[];report.mediaRejected=[];
  for(const directory of ['/', '/shop/']){
    const scoped=directory+product.slice(1), url=host+directory+'search_suggest.aspx?q=SKU120&mode=guided&limit=6';
    const paths=api.urls(host+directory,directory+'search_suggest.aspx'), brief=briefFrom(url);
    const positives=[
      {name:'canonical full',image:product+'product.webp',fallback:'',expected:[scoped+'product.webp'],available:[scoped+'product.webp']},
      {name:'app scoped',image:scoped+'product.webp',fallback:'',expected:[scoped+'product.webp'],available:[scoped+'product.webp']},
      {name:'absolute app scoped',image:host+scoped+'product.webp',fallback:'',expected:[scoped+'product.webp'],available:[scoped+'product.webp']},
      {name:'relative app asset',image:'Public/assets/images/articoli/product.webp',fallback:'',expected:[scoped+'product.webp'],available:[scoped+'product.webp']},
      {name:'canonical thumbnail',image:product+'_product.webp',fallback:product+'product.webp',expected:[scoped+'_product.webp'],available:[scoped+'_product.webp',scoped+'product.webp']},
      {name:'fallback only',image:'',fallback:product+'product.webp',expected:[scoped+'product.webp'],available:[scoped+'product.webp']},
      {name:'thumbnail missing full available',image:product+'_missing.webp',fallback:product+'product.webp',expected:[scoped+'_missing.webp',scoped+'product.webp'],available:[scoped+'product.webp']},
      {name:'both files missing',image:product+'_missing.webp',fallback:product+'missing.webp',expected:[scoped+'_missing.webp',scoped+'missing.webp'],available:[],placeholder:true},
      {name:'both fields empty',image:'',fallback:'',expected:[],available:[],placeholder:true},
      {name:'encoded spaces unicode',image:product+'caff%C3%A8%20blu%20%E6%9D%AF.png',fallback:'',expected:[scoped+'caff%C3%A8%20blu%20%E6%9D%AF.png'],available:[scoped+'caff%C3%A8%20blu%20%E6%9D%AF.png']},
      {name:'encoded thumbnail',image:product+'_caff%C3%A8%20blu.png',fallback:'',expected:[scoped+'_caff%C3%A8%20blu.png'],available:[scoped+'_caff%C3%A8%20blu.png']},
      {name:'encoded filename punctuation',image:product+'sconto%2050%25%20%23blu.png',fallback:'',expected:[scoped+'sconto%2050%25%20%23blu.png'],available:[scoped+'sconto%2050%25%20%23blu.png']}
    ];
    // Distinct URLs prevent the decoded-image memory cache from hiding requests between cases.
    positives.forEach((sample,i)=>{
      const unique=value=>value.replace(/\.(webp|png)$/,'-case'+i+'.$1');
      sample.image=unique(sample.image);sample.fallback=unique(sample.fallback);
      sample.expected=sample.expected.map(unique);sample.available=sample.available.map(unique);
    });
    const negatives=[
      'https://external.invalid'+product+'product.webp','//external.invalid'+product+'product.webp',
      '/other'+product+'product.webp','/shop-other'+product+'product.webp',
      'https://user:password@tenant1.invalid'+scoped+'product.webp','https://@tenant1.invalid'+scoped+'product.webp',
      'javascript:alert(1)','data:image/png;base64,AA==','file:///tmp/product.png','blob:'+host+'/image.png',
      scoped+'product.webp?x=1',scoped+'product.webp?',scoped+'product.webp#x',scoped+'product.webp#',
      scoped+'../articoli/product.webp',scoped+'./product.webp',scoped+'%2e%2e/articoli/product.webp',
      scoped+'%2E/product.webp',scoped+'%252e%252e/product.webp',scoped+'sub%2fproduct.webp',
      scoped+'sub%5cproduct.webp',scoped+'sub%252fproduct.webp',scoped+'%00product.webp',scoped+'%0aproduct.webp',
      scoped+'sub/../../articoli/product.webp','/other/../'+scoped.slice(1)+'product.webp',
      scoped+'product..webp',scoped+'product.svg',scoped+'product.aspx',scoped+'product.webp.aspx',
      scoped+'product.p%6Eg',scoped+'product.png%20',scoped+'product%3astream.png',scoped+'%C0%AFproduct.webp',
      scoped+'product%GG.webp',scoped+'product.webp/extra.png',product+'sub/product.webp',
      scoped.replace('/images/','/images-else/')+'product.webp',scoped.replace('/Public/','/%50ublic/')+'product.webp',
      scoped+'product\\.webp',scoped+'pro\tduct.webp'
    ];
    if(directory!=='/')negatives.push('/Public/assets/images/marche/logo.png','/Public/assets/images/product.png',host+product+'product.webp');
    for(const sample of positives)for(const field of ['image','image_fallback']){
      // validate is the actual public module entry point and uses the same imageURL for both fields.
      const value=sample.image||sample.fallback;
      const p=payload(url,{count:1,mutate:p=>{p.suggestions[0].image='';p.suggestions[0].image_fallback='';p.suggestions[0][field]=value;}});
      const row=api.validate(p,brief,paths).items[0], actual=field==='image'?row.image:row.fallback;
      const expected=value?host+(value.startsWith(host)?new URL(value).pathname:value.startsWith(product)?directory+value.slice(1):new URL(value,host+directory).pathname):'';
      check('module positive '+directory+' '+sample.name+' '+field,actual===expected);
    }
    for(const raw of negatives)for(const field of ['image','image_fallback']){
      const p=payload(url,{count:1,mutate:p=>{p.suggestions[0].image='';p.suggestions[0].image_fallback='';p.suggestions[0][field]=raw;}});
      const row=api.validate(p,brief,paths).items[0];
      check('module rejects '+directory+' '+field+' '+raw,(field==='image'?row.image:row.fallback)==='');
    }
    for(const width of [390,1365]){
      const f=await fixture({directory,width,mediaTest:true,count:1});
      try{
        for(const sample of positives){
          f.config.count=1;f.config.mediaAssets=sample.available;
          f.config.mutate=p=>{p.suggestions[0].image=sample.image;p.suggestions[0].image_fallback=sample.fallback;};
          f.mediaRequests.length=0;await f.submit();
          await f.page.locator('.ks-guide-media').first().scrollIntoViewIfNeeded();
          await f.page.waitForFunction(()=>{
            const media=document.querySelector('.ks-guide-media'),img=media.querySelector('img');
            return img?img.complete&&img.naturalWidth>0:media.textContent==='Immagine non disponibile';
          },undefined,{timeout:6000});
          const actual=await f.page.locator('.ks-guide-media').first().evaluate(e=>{
            const img=e.querySelector('img');return {src:img?img.currentSrc:'',naturalWidth:img?img.naturalWidth:0,placeholder:e.textContent==='Immagine non disponibile'};
          });
          const requested=f.mediaRequests.map(x=>new URL(x.url).pathname), label=directory+' '+width+' '+sample.name;
          check('browser decoded image '+label,sample.placeholder?actual.placeholder&&actual.naturalWidth===0:!actual.placeholder&&actual.naturalWidth>0&&actual.src===host+sample.expected.at(-1));
          check('exact media requests '+label,JSON.stringify(requested)===JSON.stringify(sample.expected)&&f.mediaRequests.every(x=>x.method==='GET'&&new URL(x.url).origin===host&&new URL(x.url).pathname.startsWith(scoped)));
          report.mediaCases.push({directory,width,name:sample.name,...actual,requested});
        }
        // Six rejected rows at a time; DOM rejection also catches images below the lazy-load viewport.
        for(let start=0;start<negatives.length;start+=6){
          const batch=negatives.slice(start,start+6);f.config.count=batch.length;f.config.mediaAssets=[];
          f.config.mutate=p=>p.suggestions.forEach((row,i)=>{row.image=batch[i];row.image_fallback=batch[i];});
          f.mediaRequests.length=0;await f.submit();
          await f.page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
          check('hostile media no img/request '+directory+' '+width+' '+start,await f.page.locator('.ks-guide-media img').count()===0&&f.mediaRequests.length===0);
          report.mediaRejected.push({directory,width,inputs:batch,requests:f.mediaRequests.slice()});
        }
        // One focused integration check: existing draft and focus behaviour with decoded images.
        f.config.count=2;f.config.mediaAssets=[scoped+'product.webp'];
        f.config.mutate=p=>p.suggestions.forEach(row=>{row.image=product+'product.webp';row.image_fallback='';});
        await f.submit();await f.refine('massimo 200 euro');
        const n=await f.page.evaluate(()=>window.__privacy.fetch.length);
        await f.page.locator('#ksGuideQuery').fill('Bozza con immagini');
        await f.page.getByRole('button',{name:'Rimuovi Massimo: 200 €',exact:true}).press('Enter');
        check('draft unchanged in media flow '+directory+' '+width,await f.page.locator('#ksGuideQuery').inputValue()==='Bozza con immagini'&&await f.page.evaluate(()=>window.__privacy.fetch.length)===n);
        await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('results');
        await f.page.locator('[data-ks-guide-compare-key]').nth(0).check();await f.page.locator('[data-ks-guide-compare-key]').nth(1).check();
        await f.page.getByRole('button',{name:'Svuota confronto',exact:true}).press('Space');
        check('focus unchanged in media flow '+directory+' '+width,await f.page.locator('[data-ks-guide-compare-key]').first().evaluate(e=>e===document.activeElement));
        await f.privacy();
      }finally{await f.close();}
    }
  }
  report.mediaFailures=failures;assert.equal(failures.length,0,'REV2 media regressions: '+failures.join('; '));
}
function catalogHtml(directory,target,query) {
  const source=read('articoli.aspx'), encode=s=>String(s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  let toolbar=source.slice(source.indexOf('                    <div class="tf-shop-control'),source.indexOf('                    <div id="ksActiveFilters"'));
  let empty=/<EmptyDataTemplate>([\s\S]*?)<\/EmptyDataTemplate>/.exec(source)[1];
  function controls(s) {
    return s.replace(/<asp:DropDownList\b([^>]*)>([\s\S]*?)<\/asp:DropDownList>/g,(_,attrs,items)=>{
      const label=/aria-label="([^"]*)"/.exec(attrs),css=/CssClass="([^"]*)"/.exec(attrs);
      return '<select class="'+css[1]+'" aria-label="'+label[1]+'">'+items.replace(/<asp:ListItem Value="([^"]*)" Text="([^"]*)"><\/asp:ListItem>/g,'<option value="$1">$2</option>')+'</select>';
    }).replace(/<asp:Label\b([^>]*?)\/>/g,(_,attrs)=>/Visible="false"/.test(attrs)?'':encode((/Text="([^"]*)"/.exec(attrs)||[])[1]))
      .replace(/<asp:PlaceHolder\b[^>]*>/g,'').replace(/<\/asp:PlaceHolder>/g,'')
      .replace(/<asp:Literal ID="litEmptySearchQuery"[^>]*\/>/g,encode(query))
      .replace(/<asp:Literal ID="litEmptySearchLinks"[^>]*\/>/g,'')
      .replace(/<%=\s*Server.HtmlEncode\(CatalogShoppingGuideUrl\)\s*%>/g,encode(target))
      .replace(/<%=\s*Server.HtmlEncode\(ClearCatalogFiltersUrl\)\s*%>/g,directory+'articoli.aspx');
  }
  toolbar=controls(toolbar);empty=controls(empty);
  assert.ok(toolbar.includes('Guida agli acquisti')&&!/<asp:|<%/.test(toolbar+empty),'REAL_CATALOG_CONTROLS_MATERIALIZED');
  const scoped=/<style>([\s\S]*?)<\/style>/.exec(source)[1], names=[...styles,'catalog-ui.css','catalog-filters-ui.css','catalog-product-flow.css'];
  return '<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+
    names.map(n=>'<link rel="stylesheet" href="'+directory+'Public/assets/keepstore/css/'+n+'">').join('')+'<style>'+scoped+'</style></head><body><form id="form1"><main><section id="ksCatalogPage" class="flat-content ks-catalog-page"><div class="container"><div class="content-area">'+toolbar+empty+'</div></div></section></main></form></body></html>';
}
async function catalogHandoffRegressions() {
  const departments=new Map([[0,'Tutti i reparti'],[7,'Informatica'],[8,'Accessori']]);
  const valid='?guide=catalog-v1&guide_q=SSD+1+TB&guide_st=7';
  record('ordinary HOME ignores catalog q/st',api.catalogHandoff('?q=SSD&st=7',departments).kind==='none');
  record('ordinary HOME empty URL unchanged',api.catalogHandoff('',departments).kind==='none');
  record('explicit contract imports only draft',api.catalogHandoff(valid,departments).kind==='draft');
  record('whitespace normalized',api.catalogHandoff('?guide=catalog-v1&guide_q=++SSD+++1+TB++',departments).q==='SSD 1 TB');
  record('Unicode normalized NFC',api.catalogHandoff('?guide=catalog-v1&guide_q=caffe%CC%80',departments).q==='caffè');
  record('80 characters accepted',api.catalogHandoff('?guide=catalog-v1&guide_q='+'x'.repeat(80),departments).q.length===80);
  const bad=[
    '?guide=catalog-v1','?guide=catalog-v1&guide_q=','?guide=catalog-v1&guide_q=+++','?guide=catalog-v1&guide_q=x',
    '?guide=catalog-v1&guide_q='+'x'.repeat(81),'?guide=catalog-v1&guide_q=SSD%zz','?guide=catalog-v1&guide_q=SSD%ff',
    '?guide=catalog-v1&guide_q=SSD%00x','?guide=catalog-v1&guide_q=SSD%0ax','?guide=catalog-v1&guide_q=SSD\ud800',
    '?guide=catalog-v1&guide_q=SSD&guide_q=Olio','?guide=catalog-v1&guide=catalog-v1&guide_q=SSD',
    valid+'&guide_st=7',valid+'&owner=private',valid+'&listino=99',valid+'&q=OTHER',valid+'&GUIDE_Q=OTHER',
    '?guide=unknown&guide_q=SSD','?guide_q=SSD','?guide_st=7',
    ...['','0','-7','07','2147483648','7x'].map(x=>'?guide=catalog-v1&guide_q=SSD&guide_st='+x)
  ];
  for(let i=0;i<bad.length;i++)record('malformed/duplicate contract rejected '+i,api.catalogHandoff(bad[i],departments).kind==='invalid');
  const unavailable=api.catalogHandoff('?guide=catalog-v1&guide_q=SSD&guide_st=99',departments);
  record('unavailable sector retained as unresolved',unavailable.kind==='draft'&&unavailable.st===99&&unavailable.sectorUnavailable);
  for(const row of serverEvidence.cases){
    const url=new URL(row.url,'https://tenant1.invalid'), parsed=api.catalogHandoff(url.search,departments);
    record('actual VB to JS contract '+row.name,row.expectedQuery ? parsed.kind==='draft'&&parsed.q===row.expectedQuery : parsed.kind==='none');
  }
  report.serverAssertions=serverEvidence.assertions;
  report.scope=process.argv.includes('--handoff-fallback-only')?'residual fallback only':'complete handoff delta';
  const baseline=cp.execFileSync('git',['show','773131cf932dfcc5dfbad843011cb668611c03f5:articoli.aspx'],{cwd:root,encoding:'utf8'}).replace(/\r\n/g,'\n');
  const current=read('articoli.aspx').replace(/\r\n/g,'\n'), empty=s=>/<EmptyDataTemplate>([\s\S]*?)<\/EmptyDataTemplate>/.exec(s)[1];
  record('existing empty-state/reset/suggestions byte preserved',empty(current).replace(/^.*class="tf-btn btn-line ks-catalog-guide-link".*\n/m,'')===empty(baseline));
  record('all four catalog view IDs preserved',['tabgrid-1','tabgrid-2','tablist-1','tablist-2'].every(id=>current.includes('data-ks-layout="'+id+'"')));
  record('server builder has no per-card I/O',!/(?:MySql|ExecuteReader|ExecuteScalar|HttpWebRequest)/.test(/Private Shared Function BuildCatalogGuideHandoffUrl[\s\S]*?End Function/.exec(read('articoli.aspx.vb'))[0]));
  report.performance={beforeModuleBytes:Buffer.byteLength(cp.execFileSync('git',['show','773131cf932dfcc5dfbad843011cb668611c03f5:Public/assets/keepstore/js/ks-shopping-guide.js'],{cwd:root,encoding:'utf8'}).replace(/\r\n/g,'\n')),
    afterModuleBytes:Buffer.byteLength(moduleSource.replace(/\r\n/g,'\n')),normalization:'UTF8, LF for both samples',startupSnapshotRequests:0,confirmationSnapshotRequests:1,liveTimings:'not measured'};
  report.limitations.push('Catalog controls are materialized from actual ASPX, URL builder runs real VB/System.Web; no full WebForms lifecycle, MySQL, physical devices or screen-reader certification.',
    'Commercial JSON is a synthetic transport fixture; earlier commercial resolver evidence is reused, not rerun.');
  if(!process.argv.includes('--handoff-fallback-only')){
  for(const kind of ['Tech','Food'])for(const width of report.viewports){
    const directory=[390,768].includes(width)?'/shop/':'/', row=serverEvidence.cases.find(x=>x.name===kind+(directory==='/'?'-root':'-virtual'));
    const f=await fixture({kind,width,directory,scenario:kind==='Food'?2:0,catalogFirst:true,catalogTarget:row.url,queryText:row.expectedQuery});
    try{
      const targets=f.page.locator('.ks-catalog-guide-link');
      record('two contextual entries '+kind+width,await targets.count()===2);
      record('same real server handoff '+kind+width,(await targets.evaluateAll(a=>a.map(x=>x.getAttribute('href')))).every(x=>x===row.url));
      record('four existing views '+kind+width,await f.page.locator('[data-ks-layout]').count()===4);
      record('existing Reset/catalog entries '+kind+width,await f.page.getByRole('link',{name:'Reset filtri',exact:true}).count()===1&&await f.page.getByRole('link',{name:'Vai al catalogo',exact:true}).count()===1);
      const boxes=await targets.evaluateAll(a=>a.map(x=>({w:x.getBoundingClientRect().width,h:x.getBoundingClientRect().height})));
      record('44x44 real clickable entries '+kind+width,boxes.every(x=>x.w>=44&&x.h>=44));
      record('catalog no horizontal overflow '+kind+width,await f.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
      await targets.first().focus();
      await f.page.keyboard.press('Tab');await f.page.keyboard.press('Shift+Tab');
      (report.catalogFocus ||= []).push({kind,width,...await targets.first().evaluate(x=>({active:x===document.activeElement,visible:x.matches(':focus-visible'),outline:getComputedStyle(x).outline}))});
      record('catalog focus visible '+kind+width,await targets.first().evaluate(x=>x===document.activeElement&&getComputedStyle(x).outlineStyle!=='none'&&parseFloat(getComputedStyle(x).outlineWidth)>0));
      if([390,1365].includes(width)){const file=path.join(evidence,kind+'-'+width+'-catalog.png');await f.page.screenshot({path:file,fullPage:true});report.screenshots.push(file);journal.resources.push(file);}
      await f.page.getByRole('link',{name:width===390?'Aiutami a trovare il prodotto':'Guida agli acquisti',exact:true}).press('Enter');
      await f.page.waitForFunction(()=>document.getElementById('KsLocalAiSearch130')?.getAttribute('data-ks-guide-bound')==='1');
      record('root/virtual navigation and anchor '+kind+width,new URL(f.page.url()).pathname===directory+'Default.aspx'&&new URL(f.page.url()).hash==='#KsLocalAiSearch130');
      record('import visible and unconfirmed '+kind+width,await f.page.locator('#ksGuideQuery').inputValue()===row.expectedQuery&&await f.state()==='editing'&&await f.page.locator('[data-ks-guide-summary]').isHidden()&&await f.page.locator('[data-ks-guide-handoff]').isVisible());
      record('offered sector imported '+kind+width,await f.page.locator('[data-ks-guide-sector="7"]').getAttribute('aria-pressed')==='true');
      await f.page.locator('#ksGuideQuery').focus();await f.page.locator('#ksGuideDetail').fill('portatile');await f.page.locator('#ksGuideDetail').fill('');
      await f.page.evaluate(()=>{const r=document.getElementById('KsLocalAiSearch130');KeepStoreShoppingGuide.init(r);KeepStoreShoppingGuide.init(r);});
      record('arrival/focus/typing/reinit no fetch '+kind+width,f.requests.length===0&&await f.page.locator('.ks-guide-card').count()===0);
      record('guide no horizontal overflow '+kind+width,await f.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
      if([390,1365].includes(width))await f.screenshot(kind+'-'+width+'-imported-draft');
      await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('results');
      record('one explicit authoritative request '+kind+width,f.requests.length===1&&new URL(f.requests[0]).searchParams.get('q')===row.expectedQuery&&new URL(f.requests[0]).searchParams.get('st')==='7'&&new URL(f.requests[0]).pathname===directory+'search_suggest.aspx');
      record('request omits handoff and private fields '+kind+width,Array.from(new URL(f.requests[0]).searchParams.keys()).every(k=>!/^guide|owner|listino|account|iva$/i.test(k)));
      await f.privacy();
    }finally{await f.close();}
  }
  for(const search of ['', '?q=ordinary&st=7',...bad.filter((_,i)=>[1,4,5,6,7,10,11,12,13,17,23].includes(i))]){
    const f=await fixture({search});
    try{
      record('HOME malformed/ordinary draft remains empty '+search,await f.page.locator('#ksGuideQuery').inputValue()===''&&await f.page.locator('.ks-guide-card').count()===0&&f.requests.length===0);
      const imported=api.catalogHandoff(search,departments).kind!=='none';
      record('only explicit invalid handoff gets notice '+search,await f.page.locator('[data-ks-guide-handoff]').isVisible()===imported);
      await f.page.locator('#ksGuideQuery').fill('Scelta manuale');record('manual editing no automatic request '+search,f.requests.length===0);
      await f.privacy();
    }finally{await f.close();}
  }
  for(const mode of [undefined,'no-departments']){
    const f=await fixture({search:'?guide=catalog-v1&guide_q=SSD&guide_st=99',mode});
    try{
      record('unavailable sector query kept '+mode,await f.page.locator('#ksGuideQuery').inputValue()==='SSD'&&await f.page.locator('[data-ks-guide-department][aria-pressed="true"]').count()===0);
      await f.page.locator('[data-ks-guide-prepare]').click();
      record('unavailable sector blocks implicit fallback '+mode,f.requests.length===0&&(await f.page.locator('[data-ks-guide-status]').innerText()).includes('Scegli un reparto'));
      await (mode?f.page.getByRole('button',{name:'Usa tutti i reparti',exact:true}):f.page.getByRole('button',{name:'Tutti i reparti',exact:true})).press('Enter');
      record('explicit all-departments choice still no request '+mode,f.requests.length===0);
      await f.page.locator('[data-ks-guide-prepare]').click();await f.wait('results');
      record('explicit sector choice respected '+mode,f.requests.length===1&&!new URL(f.requests[0]).searchParams.has('st'));
      await f.privacy();
    }finally{await f.close();}
  }
  const reset=await fixture({search:valid});
  try{
    await reset.page.locator('[data-ks-guide-reset]').click();
    await reset.page.evaluate(()=>{KeepStoreShoppingGuide.init(document.getElementById('KsLocalAiSearch130'));window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true}));});
    record('reset/reinit/BFCache never reimports or fetches',await reset.page.locator('#ksGuideQuery').inputValue()===''&&reset.requests.length===0&&await reset.page.locator('[data-ks-guide-handoff]').isHidden());
    await reset.privacy();
  }finally{await reset.close();}
  }
  for(const config of [{js:false},{mode:'missing'},{mode:'failure'}]){
    const f=await fixture({...config,search:valid,directory:'/shop/'});
    try{
      (report.fallbackDiagnostics ||= []).push({config,visible:await f.page.getByRole('link',{name:'Esplora tutto il catalogo',exact:true}).isVisible(),links:await f.page.locator('.ks-guide-fallback-departments a').count(),disabled:await f.page.locator('[data-ks-guide-fields]').isDisabled(),attributes:await f.page.locator('[data-ks-guide-fields]').evaluate(x=>({disabled:x.disabled,hidden:x.hidden})),requests:f.requests.length});
      record('no JS/module/init fallback survives '+JSON.stringify(config),await f.page.getByRole('link',{name:'Esplora tutto il catalogo',exact:true}).isVisible()&&await f.page.locator('.ks-guide-fallback-departments a').count()===2&&await f.page.locator('[data-ks-guide-fields]').evaluate(x=>x.disabled&&x.hidden)&&await f.page.locator('#ksGuideQuery').isDisabled()&&f.requests.length===0);
      await f.page.getByRole('link',{name:'Esplora tutto il catalogo',exact:true}).click();
      record('no-JS virtual-directory catalog works '+JSON.stringify(config),new URL(f.page.url()).pathname==='/shop/articoli.aspx');
    }finally{await f.close();}
  }
  const safe=await fixture({search:'?guide=catalog-v1&guide_q='+encodeURIComponent('<img src=x>')});
  try{record('import is text, never markup',await safe.page.locator('#ksGuideQuery').inputValue()==='<img src=x>'&&await safe.page.locator('[data-ks-guide-fields] img').count()===0&&safe.requests.length===0);await safe.privacy();}finally{await safe.close();}
}
async function advisorRegressions() {
  record('explicit advisor API available',typeof api.validateAdvisor==='function'&&typeof api.requestAdvisorURL==='function');
  const paths=api.urls('https://tenant1.invalid/','/search_suggest.aspx');
  const valid=advisorServer.filter(x=>x.response&&x.response.ok===true);
  record('actual endpoint fixtures include both synthetic scopes',valid.some(x=>advisorSpec(x.queryString).brief.st===7)&&valid.some(x=>advisorSpec(x.queryString).brief.st===8));
  report.advisorPayloads=[];
  for(const row of valid){
    const s=advisorSpec(row.queryString), result=api.validateAdvisor(row.response,s.brief,paths,s.criteria,s.skipped);
    record('actual VB endpoint response accepted '+row.name,result.items.length===row.response.suggestions.length);
    record('hard requirements never unknown/violated '+row.name,row.response.suggestions.every(p=>p.evaluations.every(e=>e.priority!=='hard'||e.status==='SATISFIED')));
    report.advisorPayloads.push({name:row.name,requestBytes:Buffer.byteLength(row.queryString),responseBytes:Buffer.byteLength(JSON.stringify(row.response)),returned:result.items.length,criteria:s.criteria,question:row.response.guided.question&&row.response.guided.question.attributeId,scope:row.response.guided.selectionScope,exhaustive:row.response.guided.exhaustive});
  }
  const multisource=valid.find(x=>x.response.suggestions.some(p=>p.values.some(v=>v.evidenceStatus==='known'&&v.sourceField.length>40)));
  record('real four-field provenance accepted within80chars',!!multisource&&multisource.response.suggestions.some(p=>p.values.some(v=>v.evidenceStatus==='known'&&v.sourceField.split(',').length===4&&v.sourceField.length<=80)));
  const initialFor=st=>valid.find(x=>{const s=advisorSpec(x.queryString);return s.brief.st===st&&s.brief.q==='scelta'&&s.criteria.length===0&&s.skipped.length===0&&x.response.suggestions.length>1&&x.response.guided.question;});
  const initialTech=initialFor(7),initialFood=initialFor(8);
  record('both sectors have actual useful initial question',!!initialTech&&!!initialFood);
  record('same query different scope selects different attribute',initialTech.response.guided.question.attributeId!==initialFood.response.guided.question.attributeId);
  const s=advisorSpec(initialTech.queryString);
  const invalid=[
    ['wrong protocol version',p=>p.guided.version=1],
    ['wrong scoped criteria',p=>p.guided.criteria.st=99],
    ['unknown question attribute',p=>p.guided.question.attributeId='not-authorized'],
    ['unobserved question option',p=>p.guided.question.options[0].value='not-observed'],
    ['commercial metadata injection',p=>p.guided.tenant=1],
    ['oversized product array',p=>p.suggestions=Array.from({length:7},()=>clone(p.suggestions[0]))],
    ['cross-origin product URL',p=>p.suggestions[0].url='https://outside.invalid/articolo.aspx?id=1&TCId=1'],
    ['invalid variant identity',p=>p.suggestions[0].TCId=-2],
    ['unbounded title',p=>p.suggestions[0].title='x'.repeat(501)],
    ['unbounded attribute dictionary',p=>p.guided.attributes=Array.from({length:100},()=>clone(p.guided.attributes[0]))]
  ];
  for(const [name,mutate] of invalid){const p=clone(initialTech.response);mutate(p);assert.throws(()=>api.validateAdvisor(p,s.brief,paths,s.criteria,s.skipped));record('advisor rejects '+name);}
  const hardEvidence=valid.find(x=>advisorSpec(x.queryString).criteria.some(c=>c.priority==='hard')&&x.response.suggestions.length>0);
  record('actual hard evidence fixture present',!!hardEvidence);
  const hs=advisorSpec(hardEvidence.queryString);
  for(const [name,mutate] of [
    ['hard unknown evaluation',p=>p.suggestions[0].evaluations.find(e=>e.priority==='hard').status='UNKNOWN'],
    ['evaluation evidence mismatch',p=>p.suggestions[0].evaluations.find(e=>e.priority==='hard').evidenceRef='unrelated-proof'],
    ['missing hard fact',p=>{const e=p.suggestions[0].evaluations.find(x=>x.priority==='hard');p.suggestions[0].values=p.suggestions[0].values.filter(v=>v.attributeId!==e.attributeId);}]
  ]){const p=clone(hardEvidence.response);mutate(p);assert.throws(()=>api.validateAdvisor(p,hs.brief,paths,hs.criteria,hs.skipped));record('advisor rejects '+name);}
  const wire=api.requestAdvisorURL(s.brief,paths,[],[]);
  record('explicit isolated mode in request',new URL(wire).searchParams.get('mode')==='guided2');
  record('request contains no client commercial authority',!/[?&](?:owner|tenant|listino|iva|azienda|login|dictionary)=/i.test(wire));
  const activate=async(f,row,send=true)=>{
    const spec=advisorSpec(row.queryString);
    await f.page.locator('[data-ks-guide-mode="guided2"]').click();
    await f.page.locator('#ksGuideQuery').fill(spec.brief.q);
    await f.page.locator('[data-ks-guide-sector="'+spec.brief.st+'"]').click();
    if(send){await f.page.locator('[data-ks-guide-prepare]').click();await f.wait(row.response.suggestions.length?'results':'empty');}
  };
  const settle=async(f)=>{await f.page.waitForFunction(()=>['results','empty','error','context-invalid'].includes(document.getElementById('KsLocalAiSearch130').getAttribute('data-ks-guide-state')),{},{timeout:6000});};
  const addCriterion=async(f,c)=>{
    const requestsBefore=f.requests.length;
    const details=f.page.locator('[data-ks-advisor-panel] details');
    if(!await details.evaluate(x=>x.open))await details.locator('summary').press('Enter');
    await f.page.locator('#ksAdvisorAttribute').selectOption(c.attributeId);
    await f.page.locator('#ksAdvisorOperator').selectOption(c.operator);
    if(await f.page.locator('#ksAdvisorNumber').isVisible())await f.page.locator('#ksAdvisorNumber').fill(c.value);
    else await f.page.locator('#ksAdvisorValue').selectOption(c.value);
    await f.page.locator('#ksAdvisorPriority').selectOption(c.priority);
    record('typed criterion draft never searches',f.requests.length===requestsBefore);
    await f.page.locator('[data-ks-advisor-add]').press('Enter');await settle(f);
  };
  const sample=async(f,name)=>{
    (report.advisorRuns ||= []).push({name,requests:f.requests.length,payloadBytes:f.payloadBytes,...await f.page.evaluate(()=>({render:window.__fixtureRender,guideHeight:document.getElementById('KsLocalAiSearch130').getBoundingClientRect().height,scrollWidth:document.documentElement.scrollWidth,viewport:innerWidth}))});
    record('all fixture requests resolved '+name,f.apiErrors.length===0);await f.privacy();
  };
  if(!advisorQualityOnly){
  for(const [kind,row] of [['Tech',initialTech],['Food',initialFood]])for(const width of report.viewports){
    const f=await fixture({advisor:true,kind,width,advisorScenario:row.name});
    try{
      record('v1 remains default '+kind+width,await f.page.locator('[data-ks-guide-mode="guided"]').getAttribute('aria-pressed')==='true');
      await activate(f,row,false);
      record('mode, typing and scope never search '+kind+width,f.requests.length===0);
      await f.page.locator('#ksGuideGoal').fill('Obiettivo locale senza dati personali');
      await (width<=430?f.page.locator('[data-ks-guide-prepare]').tap():f.page.locator('[data-ks-guide-prepare]').press('Enter'));
      await f.wait('results');
      record('one confirmed request '+kind+width,f.requests.length===1);
      record('free objective remains local '+kind+width,!decodeURIComponent(f.requests[0]).includes('Obiettivo'));
      record('real shortlist count '+kind+width,await f.page.locator('.ks-guide-card').count()===row.response.suggestions.length);
      record('one useful question '+kind+width,await f.page.locator('[data-ks-advisor-option]').count()===row.response.guided.question.options.length);
      record('live status semantics '+kind+width,await f.page.locator('[data-ks-guide-status]').getAttribute('role')==='status'&&await f.page.locator('[data-ks-guide-status]').getAttribute('aria-live')==='polite');
      record('page never horizontally overflows '+kind+width,await f.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
      record('no markup from product data '+kind+width,await f.page.locator('[data-ks-guide-results] script,[data-ks-guide-results] iframe,[data-ks-guide-results] [onerror]').count()===0);
      const targetMetrics=await f.page.locator('[data-ks-guide-mode], [data-ks-advisor-option], [data-ks-guide-prepare]').evaluateAll(es=>es.filter(e=>e.getBoundingClientRect().height>0).map(e=>({text:e.textContent.trim(),height:e.getBoundingClientRect().height,width:e.getBoundingClientRect().width})));
      record('primary and question touch targets at least 44px '+kind+width,targetMetrics.every(m=>m.height>=44&&m.width>=44));
      await f.screenshot('advisor-'+kind+'-'+width);
      if([390,1365].includes(width))await f.screenshot('advisor-'+kind+'-'+width+'-results','[data-ks-guide-results]');
      await sample(f,kind+' '+width);
    }finally{await f.close();}
  }
  const hardOrSoft=valid.filter(x=>{const a=advisorSpec(x.queryString);return a.brief.st===7&&a.brief.q==='scelta'&&a.criteria.length===1&&a.skipped.length===0;});
  record('real hard and soft confirmation fixtures present',hardOrSoft.some(x=>advisorSpec(x.queryString).criteria[0].priority==='hard')&&hardOrSoft.some(x=>advisorSpec(x.queryString).criteria[0].priority==='soft'));
  for(const priority of ['hard','soft']){
    const row=hardOrSoft.find(x=>advisorSpec(x.queryString).criteria[0].priority===priority),f=await fixture({advisor:true,width:390});
    try{
      await activate(f,initialTech);const count=f.requests.length;
      const criterion=advisorSpec(row.queryString).criteria[0];
      if(priority==='soft'){await f.page.locator('[data-ks-advisor-option="'+criterion.value+'"]').press('Enter');await settle(f);}
      else await addCriterion(f,criterion);
      record('explicit '+priority+' confirms exactly one request',f.requests.length===count+1);
      record('confirmed typed '+priority+' retained',advisorSpec(f.requests.at(-1)).criteria[0].priority===priority);
      record('dynamic action retains logical keyboard focus '+priority,await f.page.evaluate(()=>document.activeElement!==document.body));
      record('hard or soft exact server shortlist '+priority,await f.page.locator('.ks-guide-card').count()===row.response.suggestions.length);
      await f.screenshot('advisor-Tech-'+priority);await sample(f,priority);
    }finally{await f.close();}
  }
  const manualHard=advisorSpec(hardOrSoft.find(x=>advisorSpec(x.queryString).criteria[0].priority==='hard').queryString).criteria[0];
  for(const change of ['query','sector-chip']){
    const f=await fixture({advisor:true,width:390});
    try{
      await activate(f,initialTech);await addCriterion(f,manualHard);f.config.status=403;
      if(change==='query'){await f.page.locator('#ksGuideQuery').fill('altra scelta');record('new query explicitly confirms removal of old requirements',(await f.page.locator('[data-ks-guide-prepare]').innerText()).includes('senza i requisiti precedenti'));await f.page.locator('[data-ks-guide-prepare]').click();}
      else await f.page.locator('[data-ks-guide-chips] button').filter({hasText:/^Reparto:/}).click();
      await f.wait('context-invalid');
      const sent=advisorSpec(f.requests.at(-1));
      record(change+' clears previous criteria and skips before sending',sent.criteria.length===0&&sent.skipped.length===0&&(change==='query'?sent.brief.q==='altra scelta':sent.brief.st===0));
      f.config.status=0;await f.page.locator('[data-ks-guide-undo]').press('Enter');await f.wait('results');
      const restored=advisorSpec(f.requests.at(-1));
      record(change+' undo restores scoped criteria with a fresh request',f.requests.length===4&&restored.brief.q==='scelta'&&restored.brief.st===7&&JSON.stringify(restored.criteria)===JSON.stringify([manualHard]));
      await sample(f,change+' request-only403 and undo');
    }finally{await f.close();}
  }
  const softAfterHard=await fixture({advisor:true,width:390});
  try{
    await activate(softAfterHard,initialTech);await addCriterion(softAfterHard,manualHard);
    const question=softAfterHard.page.locator('[data-ks-advisor-option]').first(),id=await question.getAttribute('data-ks-advisor-attribute');
    record('manual priority remains hard for targeted question probe',await softAfterHard.page.locator('#ksAdvisorPriority').inputValue()==='hard');
    softAfterHard.config.status=403;await question.press('Enter');await softAfterHard.wait('context-invalid');
    const criteria=advisorSpec(softAfterHard.requests.at(-1)).criteria;
    record('preference question never inherits hidden manual hard priority',criteria.find(c=>c.attributeId===id).priority==='soft'&&criteria.find(c=>c.attributeId===manualHard.attributeId).priority==='hard');
    await sample(softAfterHard,'question always soft request-only403');
  }finally{await softAfterHard.close();}
  const skippedRow=valid.find(x=>{const a=advisorSpec(x.queryString);return a.brief.st===7&&a.brief.q==='scelta'&&a.criteria.length===0&&a.skipped.includes(initialTech.response.guided.question.attributeId);});
  record('actual skipped question fixture present',!!skippedRow);
  for(const action of ['skip','indifferent','unknown']){
    const f=await fixture({advisor:true,width:390});
    try{
      await activate(f,initialTech);const before=f.requests.length;
      await f.page.locator('[data-ks-advisor-'+action+']').press('Enter');await settle(f);
      record(action+' triggers one explicit recalculation',f.requests.length===before+1);
      record(action+' suppresses old question in same context',await f.page.locator('[data-ks-advisor-option][data-ks-advisor-attribute="'+initialTech.response.guided.question.attributeId+'"]').count()===0);
      record(action+' retains logical keyboard focus',await f.page.evaluate(()=>document.activeElement!==document.body));
      await sample(f,action);
    }finally{await f.close();}
  }
  for(const name of ['tech-hard-empty','tech-truncated-empty']){
    const row=valid.find(x=>x.name===name),f=await fixture({advisor:true,width:390});
    record('actual empty/relaxation endpoint fixture '+name,!!row&&row.response.suggestions.length===0&&row.response.guided.actions.length>0);
    try{
      await activate(f,initialTech);f.config.advisorScenario=name;
      if(name==='tech-hard-empty'){
        const c=advisorSpec(row.queryString).criteria[0],before=f.requests.length;
        await f.page.locator('[data-ks-advisor-panel] details summary').press('Enter');
        await f.page.locator('#ksAdvisorAttribute').selectOption(c.attributeId);
        for(const invalid of ['1e3','-1','1000000001','3.1234567']){
          await f.page.locator('#ksAdvisorNumber').fill(invalid);await f.page.locator('[data-ks-advisor-add]').click();
          record('invalid numeric threshold stays local '+invalid,f.requests.length===before&&await f.page.locator('#ksAdvisorNumber').inputValue()===invalid);
        }
      }
      await addCriterion(f,advisorSpec(row.queryString).criteria[0]);
      record('empty hard constraints never suggest products '+name,await f.page.locator('.ks-guide-card').count()===0);
      record('server reason visible '+name,(await f.page.locator('[data-ks-guide-results]').innerText()).includes(row.response.guided.summary));
      if(name==='tech-truncated-empty')record('truncated scope explicitly incomplete',(await f.page.locator('[data-ks-guide-results]').innerText()).includes('incompleta'));
      const before=f.requests.length;await f.page.waitForTimeout(80);
      record('relaxation never automatic '+name,f.requests.length===before);
      await f.screenshot('advisor-'+name);f.config.advisorScenario=initialTech.name;
      await f.page.locator('[data-ks-advisor-relax]').first().press('Enter');await f.wait('results');
      record('explicit relaxation removes only confirmed criterion '+name,f.requests.length===before+1&&advisorSpec(f.requests.at(-1)).criteria.length===0);
      await sample(f,name+' explicit numeric threshold');
    }finally{await f.close();}
  }
  const taxonomyRow=valid.find(x=>x.name==='taxonomy-only'),taxonomy=await fixture({advisor:true,width:390});
  try{
    record('actual taxonomy-only fixture present',!!taxonomyRow);
    await taxonomy.page.locator('[data-ks-guide-mode="guided2"]').click();await taxonomy.page.locator('[data-ks-guide-prepare]').click();
    record('empty query without explicit scope does not fetch',taxonomy.requests.length===0);
    await activate(taxonomy,taxonomyRow);
    record('empty query with explicit taxonomy makes one scoped request',taxonomy.requests.length===1&&advisorSpec(taxonomy.requests[0]).brief.q===''&&advisorSpec(taxonomy.requests[0]).brief.st===7);
    await sample(taxonomy,'empty query explicit scope');
  }finally{await taxonomy.close();}
  const singleton=await fixture({advisor:true,width:390,advisorScenario:'tech-singleton'});
  try{await activate(singleton,initialTech);record('singleton never asks unnecessary question',await singleton.page.locator('.ks-guide-card').count()===1&&await singleton.page.locator('[data-ks-advisor-option]').count()===0);await sample(singleton,'singleton');}finally{await singleton.close();}
  const comparison=await fixture({advisor:true,width:390});
  try{
    await activate(comparison,initialTech);
    const sources=comparison.page.locator('.ks-guide-card details').first();
    record('product evidence uses closed native disclosure',await sources.count()===1&&!await sources.evaluate(x=>x.open));
    await sources.locator('summary').press('Enter');
    record('keyboard reveals actual source excerpts',await sources.evaluate(x=>x.open)&&(await sources.innerText()).includes(initialTech.response.suggestions[0].values.find(x=>x.evidenceStatus==='known').evidenceText));
    await sources.locator('summary').press('Enter');
    await comparison.page.locator('[data-ks-guide-compare-key]').nth(0).check();await comparison.page.locator('[data-ks-guide-compare-key]').nth(1).check();
    record('advisor retains two-product comparison',await comparison.page.locator('[data-ks-guide-comparison] table').count()===1&&await comparison.page.locator('[data-ks-guide-compare-key]:checked').count()===2);
    record('comparison includes typed technical attribute',(await comparison.page.locator('[data-ks-guide-comparison]').innerText()).includes(initialTech.response.guided.attributes.find(a=>a.type==='number').label));
    record('comparison remains contained at mobile width',await comparison.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    await comparison.screenshot('advisor-Tech-comparison','[data-ks-guide-comparison]');await sample(comparison,'typed comparison');
    await comparison.page.getByRole('link',{name:'Vai alla scheda e acquista',exact:true}).first().press('Enter');
    record('explicit PDP navigation preserves real variant identity',comparison.page.url()===new URL(initialTech.response.suggestions[0].url,'https://tenant1.invalid/').href);
  }finally{await comparison.close();}
  const isolated=await fixture({advisor:true,width:390,directory:'/shop/',scenario:2,advisorScenario:'commercial-2-anon'});
  try{
    await activate(isolated,initialTech);
    record('second synthetic context stays in its virtual directory',new URL(isolated.requests[0]).host==='tenant2.invalid'&&new URL(isolated.requests[0]).pathname==='/shop/search_suggest.aspx');
    record('second context uses its exact server response',await isolated.page.locator('.ks-guide-card').count()===valid.find(x=>x.name==='commercial-2-anon').response.suggestions.length);
    await sample(isolated,'second context virtual directory');
  }finally{await isolated.close();}
  const scope=await fixture({advisor:true,width:390});
  try{
    await activate(scope,initialTech);
    await addCriterion(scope,advisorSpec(hardOrSoft.find(x=>advisorSpec(x.queryString).criteria[0].priority==='hard').queryString).criteria[0]);
    const before=scope.requests.length,oldQuestion=initialTech.response.guided.question.attributeId;
    await scope.page.locator('[data-ks-guide-sector="8"]').tap();
    record('scope change clears old cards without request',scope.requests.length===before&&await scope.page.locator('.ks-guide-card').count()===0);
    record('scope change clears dictionary and questions',await scope.page.locator('[data-ks-advisor-option]').count()===0&&await scope.page.locator('#ksAdvisorAttribute option[value="'+oldQuestion+'"]').count()===0);
    record('scope change clears confirmed typed criteria',await scope.page.locator('[data-ks-advisor-criteria] button').count()===0);
    await scope.page.locator('[data-ks-guide-prepare]').tap();await scope.wait('results');
    record('new scope gets food question',await scope.page.locator('[data-ks-guide-results]').innerText().then(x=>x.includes(initialFood.response.guided.question.label)));
    record('new scope never sends previous typed criteria',advisorSpec(scope.requests.at(-1)).criteria.length===0&&advisorSpec(scope.requests.at(-1)).skipped.length===0);
    await scope.page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true})));
    record('BFCache event invalidates stale commercial evidence',await scope.page.locator('.ks-guide-card').count()===0&&scope.requests.length===before+1);
    await sample(scope,'scope and simulated BFCache event');
  }finally{await scope.close();}
  const pending=await fixture({advisor:true,width:390,delay:350,ignoreAbort:true});
  try{
    await activate(pending,initialTech,false);await pending.page.locator('[data-ks-guide-prepare]').click();
    await pending.page.waitForFunction(()=>window.__privacy.fetch.length===1);
    await pending.page.locator('#ksGuideQuery').fill('bozza nuova');
    await pending.page.waitForTimeout(450);
    record('late response cannot replace draft',await pending.page.locator('#ksGuideQuery').inputValue()==='bozza nuova'&&await pending.page.locator('.ks-guide-card').count()===0);
    record('pending edit aborts transport generation',await pending.page.evaluate(()=>window.__privacy.aborts>0));
    await sample(pending,'late response and draft');
  }finally{await pending.close();}
  for(const fault of [{status:403},{raw:'{"ok":true,"mode":"guided2"}'},{mutate:p=>p.guided.version=9}]){
    const f=await fixture({advisor:true,width:390,...fault});
    try{await activate(f,initialTech,false);await f.page.locator('[data-ks-guide-prepare]').click();await f.wait(fault.status?'context-invalid':'error');record('fault clears recommendations '+JSON.stringify(fault),await f.page.locator('.ks-guide-card').count()===0);await sample(f,'fault '+(fault.status||'schema'));}finally{await f.close();}
  }
  const v1=await fixture({advisor:true,width:390});
  try{
    await activate(v1,initialTech);await v1.page.locator('[data-ks-guide-mode="guided"]').press('Enter');
    record('mode switch clears v2 facts',await v1.page.locator('.ks-guide-card').count()===0&&await v1.page.locator('[data-ks-advisor-panel]').isHidden());
    await v1.submit();record('v1 still sends original mode and limit',new URL(v1.requests.at(-1)).searchParams.get('mode')==='guided'&&new URL(v1.requests.at(-1)).searchParams.get('limit')==='6');
    record('v1 keeps result behavior',await v1.page.locator('.ks-guide-card').count()===3);await sample(v1,'v1 mode compatibility');
  }finally{await v1.close();}
  for(const options of [{js:false},{mode:'missing'},{mode:'failure'}]){
    const f=await fixture({advisor:true,width:390,...options});
    try{record('no JS/module/init retains catalog fallback '+JSON.stringify(options),await f.page.getByRole('link',{name:'Esplora tutto il catalogo',exact:true}).isVisible()&&f.requests.length===0&&await f.page.locator('[data-ks-guide-fields]').evaluate(x=>x.disabled&&x.hidden));await f.page.getByRole('link',{name:'Esplora tutto il catalogo',exact:true}).click();record('fallback catalog navigation works '+JSON.stringify(options),new URL(f.page.url()).pathname==='/articoli.aspx');}finally{await f.close();}
  }
  }
  // REV1: actual compiled endpoint fixtures; GET responses are intercepted.
  // Receipt cryptography is exercised in VB; routing does not pretend to be IIS.
  const hiddenRow=valid.find(x=>x.name==='rev1-hidden');
  const hidden=await fixture({advisor:true,width:390,advisorScenario:hiddenRow.name});
  try{await activate(hidden,initialTech);record('REV1-A hidden HTML creates no technical fact/question',await hidden.page.locator('[data-ks-advisor-option]').count()===0&&!(await hidden.page.locator('[data-ks-guide-results]').innerText()).includes('Memoria installata'));await sample(hidden,'REV1 hidden');}finally{await hidden.close();}
  for(const width of [390,1365]){
    const mixedRow=valid.find(x=>x.name==='rev1-mixed'),f=await fixture({advisor:true,width,advisorScenario:mixedRow.name});
    try{
      await f.page.locator('[data-ks-guide-mode="guided2"]').click();await f.page.locator('#ksGuideQuery').fill('scelta');await f.page.locator('[data-ks-guide-prepare]').press('Enter');await f.wait('results');
      const mixedState=await f.page.evaluate(()=>({questions:document.querySelectorAll('[data-ks-advisor-option]').length,disabled:document.querySelector('[data-ks-advisor-controls]').disabled}));
      record('REV1-B mixed pool has no technical question '+width+' '+JSON.stringify(mixedState),mixedState.questions===0&&mixedState.disabled);
      const count=f.requests.length;await f.page.locator('[data-ks-advisor-taxonomy]').press('Enter');
      record('REV1-B taxonomy action focuses existing control no fetch '+width,f.requests.length===count&&await f.page.evaluate(()=>document.activeElement.matches('[data-ks-guide-sector]')));
      f.config.advisorScenario=initialFood.name;await f.page.locator('[data-ks-guide-sector="8"]').press('Enter');
      record('REV1-B taxonomy choice is draft until confirmed '+width,f.requests.length===count&&await f.page.locator('.ks-guide-card').count()===0);
      await f.page.locator('[data-ks-guide-prepare]').press('Enter');await f.wait('results');
        record('REV1-B chosen family has own question and no old filters '+width,(await f.page.locator('[data-ks-guide-results]').innerText()).includes(initialFood.response.guided.question.label)&&advisorSpec(f.requests.at(-1)).criteria.length===0&&f.receiptHeaders.at(-1).length===0);
      await f.screenshot('rev1-taxonomy-'+width);await sample(f,'REV1 mixed to scoped '+width);
    }finally{await f.close();}
  }
  const missingCriterion=advisorSpec(valid.find(x=>x.name==='rev1-budget-empty').queryString).criteria[0];
  for(const [name,commandText] of [['rev1-budget-empty','massimo 1 euro'],['rev1-availability-missing','solo disponibili']]){
    for(const width of [390,1365]){
      const f=await fixture({advisor:true,width});
      try{
        await activate(f,initialTech);await addCriterion(f,missingCriterion);
        record('REV1-C confirmed criterion sends application receipt only in header '+name+width,f.receiptHeaders.at(-1).length===1&&f.receiptHeaders.at(-1)[0].attributeId===missingCriterion.attributeId&&!new URL(f.requests.at(-1)).searchParams.has('receipts'));
        f.config.advisorScenario=name;await f.page.locator('#ksGuideCommand').fill(commandText);await f.page.locator('[data-ks-guide-apply]').press('Enter');await f.wait('empty');
        record('REV1-C valid unavailable criterion yields normal empty not error '+name+width,(await f.state())==='empty'&&await f.page.locator('[data-ks-advisor-criteria] button').count()===1&&(await f.page.locator('[data-ks-guide-results]').innerText()).includes('non è valutabile'));
        record('REV1-C no selectable old definition or product '+name+width,await f.page.locator('.ks-guide-card').count()===0&&await f.page.locator('#ksAdvisorAttribute option[value="'+missingCriterion.attributeId+'"]').count()===0);
        const sent=advisorSpec(f.requests.at(-1));record('REV1-C filters retain criterion and receipt '+name+width,sent.criteria.length===1&&f.receiptHeaders.at(-1).length===1);
        await f.screenshot(name+'-'+width);
        const before=f.requests.length;f.config.advisorScenario=name==='rev1-budget-empty'?'rev1-empty-removed':'rev1-availability-removed';
        await f.page.locator('[data-ks-advisor-criteria] button').press('Enter');await f.wait(name==='rev1-budget-empty'?'empty':'results');
        record('REV1-C explicit chip removal clears only selected constraint '+name+width,f.requests.length===before+1&&advisorSpec(f.requests.at(-1)).criteria.length===0&&f.receiptHeaders.at(-1).length===0&&advisorSpec(f.requests.at(-1)).brief.pmax===sent.brief.pmax&&advisorSpec(f.requests.at(-1)).brief.disponibile===sent.brief.disponibile);
        record('REV1-C chip removal keeps visible logical focus '+name+width,await f.page.evaluate(()=>document.activeElement!==document.body));
        await sample(f,'REV1 recovery '+name+width);
      }finally{await f.close();}
    }
  }
  for(const [name,mutate] of [['cross-family source',p=>p.suggestions[0].family='8/801/8001/0/0'],['unavailable known fact',p=>p.guided.attributes.find(a=>a.id===p.suggestions[0].values[0].attributeId).available=false],['opaque receipt shape',p=>p.guided.attributes[0].receipt='<script>']]){
    const p=clone(initialTech.response);mutate(p);assert.throws(()=>api.validateAdvisor(p,s.brief,paths,s.criteria,s.skipped));record('REV1 browser rejects '+name);
  }
  const changedScope=await fixture({advisor:true,width:390});
  try{
    await activate(changedScope,initialTech);await addCriterion(changedScope,missingCriterion);changedScope.config.status=409;
    await changedScope.page.locator('#ksGuideCommand').fill('solo disponibili');await changedScope.page.locator('[data-ks-guide-apply]').press('Enter');await changedScope.wait('context-invalid');
    record('REV1-C changed scope preserves requirement until explicit reconfirmation',advisorSpec(changedScope.requests.at(-1)).criteria.length===1&&await changedScope.page.locator('[data-ks-advisor-reconfirm]').isVisible());
    const before=changedScope.requests.length;changedScope.config.status=0;changedScope.config.advisorScenario='rev1-availability-removed';
    await changedScope.page.locator('[data-ks-advisor-reconfirm]').press('Enter');await changedScope.wait('results');
    record('REV1-C reconfirmation is exactly one fresh request without previous-scope grant',changedScope.requests.length===before+1&&advisorSpec(changedScope.requests.at(-1)).criteria.length===0&&changedScope.receiptHeaders.at(-1).length===0);
    await sample(changedScope,'REV1 changed scope confirmation');
  }finally{await changedScope.close();}
  report.limitations.push('BFCache checked by persisted lifecycle event, not actual browser history cache restoration; no assistive technology or physical device certification');
}
(async()=>{
  try{await run();console.log('SHOPPING_PROGRESSIVE_ASSERTIONS='+report.assertions+'; BROWSER='+report.browser);}
  catch(error){report.status='FAIL';report.failure={name:error.name,message:error.message,stack:error.stack};console.error('SHOPPING_PROGRESSIVE_FAILED='+error.message);process.exitCode=1;}
  finally{if(browser){await browser.close();journal.browserClosed=true;}report.completedUtc=new Date().toISOString();artifact('browser-report.json',JSON.stringify(report,null,2));artifact('resource-journal.json',JSON.stringify(journal,null,2));}
})();
