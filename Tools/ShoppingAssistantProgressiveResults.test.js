/* Offline contract/browser certification. All HTTP is fulfilled or aborted locally.
   No IIS, database, account login, external model, dependency install or persistent browser profile. */
'use strict';
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict'), cp = require('node:child_process');
const [root, playwrightModule, chrome, evidence, serverPath] = process.argv.slice(2);
const regressionsOnly = process.argv.includes('--rev1-regressions-only');
if (!root || !playwrightModule || !chrome || !evidence || !serverPath) throw new Error('EXPLICIT_FIXTURE_PATHS_REQUIRED');
const api = require(path.join(root, 'Public/assets/keepstore/js/ks-shopping-guide.js'));
const server = JSON.parse(fs.readFileSync(serverPath, 'utf8'));
const playwright = require(playwrightModule);
const report = { assertions: 0, checks: [], viewports: [360,390,430,768,1365], renderMs: [], screenshots: [],
  suite: regressionsOnly ? 'REV1 regression reproduction' : 'REV1 full client suite', startedUtc: new Date().toISOString(),
  serverFixtures: server.map(x => ({scenario:x.scenario, expectedList:x.expectedList})), network: 'intercepted; no upstream continuation',
  limitations: ['synthetic HTML rendering, no ASP.NET request execution', 'no MySQL/IIS/login/production/TTFB/INP certification'] };
const journal = { resources: [], browserClosed: false, contextsClosed: 0 };
const record = (name, value = true) => { assert.ok(value, name); report.assertions++; report.checks.push(name); };
const clone = value => JSON.parse(JSON.stringify(value));
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const sha256 = data => require('node:crypto').createHash('sha256').update(data).digest('hex');
report.sources = ['Default.aspx','Public/assets/keepstore/js/ks-shopping-guide.js','Tools/ShoppingAssistantProgressiveResults.test.js']
  .map(file=>({file,sha256:sha256(fs.readFileSync(path.join(root,file)))}));
report.serverPayloadSha256 = sha256(fs.readFileSync(serverPath));
function artifact(name, data) { const file=path.join(evidence,name); fs.writeFileSync(file,data); if(!journal.resources.includes(file))journal.resources.push(file); return file; }
function briefFrom(url) {
  const p = new URL(url).searchParams;
  return {q:p.get('q'),st:Number(p.get('st')||0),pmin:p.get('pmin')||'0',pmax:p.get('pmax')||'0',disponibile:p.get('disponibile')==='1',ordinamento:p.get('ordinamento')||''};
}
function payload(url, options = {}) {
  const base = new URL('./',url), paths = api.urls(base.href, new URL('search_suggest.aspx',base).href), b=briefFrom(url);
  const original = clone(server[options.scenario||0].payload), row=original.suggestions[0];
  const count=options.empty?0:(options.count||3), food=options.food, prefix=food?'Olio extra vergine di oliva':'Notebook compatto';
  original.query=b.q; original.normalized_query=b.q; original.catalogUrl=api.catalogURL(b,paths).href;
  original.guided.criteria=b; original.guided.returnedCount=count; original.total=count;
  original.suggestions=Array.from({length:count},(_,i)=>Object.assign({},row,{
    id:120+i, TCId:42+i, url:'articolo.aspx?id='+(120+i)+'&TCId='+(42+i),
    title:(options.long?'Prodotto con descrizione lunga '.repeat(8):prefix)+' '+(i+1),
    code:i===0?b.q:'DEMO'+i, ean:'800000000012'+i, brand:i===2?'':(food?'Frantoio esempio':'Marca esempio'),
    category:i===2?'':(food?'Oli alimentari':'Computer'), image:'',image_fallback:'',
    availability:i===2?null:7, isOffer:i===1, isRefurbished:false
  }));
  if(options.mutate)options.mutate(original);
  return original;
}
const moduleSource=read('Public/assets/keepstore/js/ks-shopping-guide.js');
const homeSource=read('Public/assets/keepstore/js/home-default.js');
const markup=read('Default.aspx');
const guidemarkup=markup.slice(markup.indexOf('    <section id="KsLocalAiSearch130"'),markup.indexOf('    <asp:Panel ID="HomePriceDisplayNote"'));
record('real section isolated',guidemarkup.includes('data-ks-guide-results')&&!guidemarkup.includes('HomePriceDisplayNote'));
const styles=['bootstrap.min.css','keepstore.css','keepstore-overrides.css','styles.css','theme-overrides.css'];
const assets=new Map(styles.map(name=>['css/'+name,read('Public/assets/keepstore/css/'+name)]));
assets.set('js/ks-shopping-guide.js',moduleSource);assets.set('js/home-default.js',homeSource);
function html(directory,kind,mode) {
  const food=kind==='Food', sectors=food?[[7,'Alimentari'],[8,'Dispensa']]:[[7,'Informatica'],[8,'Accessori']];
  let block=guidemarkup.replace(/<%=\s*ResolveUrl\("~\/([^"]*)"\)\s*%>/g,(_,s)=>directory+s);
  block=block.replace(/<asp:Repeater ID="rptHomeAiExamples"[\s\S]*?<\/asp:Repeater>/g,sectors.map(([id,label])=>'<button type="button" data-ks-guide-department="articoli.aspx?st='+id+'" aria-pressed="false">'+label+'</button>').join(''));
  block=block.replace(/<asp:Repeater ID="rptHomeAiQuickLinks"[\s\S]*?<\/asp:Repeater>/g,sectors.map(([id,label])=>'<a href="articoli.aspx?st='+id+'">'+label+'</a>').join(''));
  block=block.replace(/<asp:Panel[^>]*CssClass="([^"]*)"[^>]*>/g,'<div class="$1">').replace(/<\/asp:Panel>/g,'</div>');
  assert.ok(!block.includes('<%')&&!block.includes('<asp:'));
  return '<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Fixture '+kind+'</title>'+
    styles.map(n=>'<link rel="stylesheet" href="'+directory+'Public/assets/keepstore/css/'+n+'">').join('')+
    '</head><body class="ks-page-home"><form id="form1"><header class="container"><a class="ks-guide-entry" href="#KsLocalAiSearch130">Guida agli acquisti</a></header><main>'+block+'</main></form>'+
    (mode==='missing'?'':'<script src="'+directory+'Public/assets/keepstore/js/ks-shopping-guide.js"></script>')+
    '<script src="'+directory+'Public/assets/keepstore/js/home-default.js"></script></body></html>';
}
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
let browser;
async function fixture(options={}) {
  const directory=options.directory||'/', kind=options.kind||'Tech', host=options.scenario>=2?'tenant2.invalid':'tenant1.invalid';
  const context=await browser.newContext({viewport:{width:options.width||390,height:1000},serviceWorkers:'block',javaScriptEnabled:options.js!==false,reducedMotion:'reduce'});
  const page=await context.newPage(), requests=[], pageErrors=[], blocked=[], apiErrors=[];
  const config={...options};
  page.on('pageerror',e=>pageErrors.push(e.message));
  await page.addInitScript(({ignoreAbort,fastTimeout,initFailure})=>{
    window.__privacy={storage:0,cookies:0,beacons:0,logs:0,fetch:[],recent:0,submits:0};
    for(const name of ['getItem','setItem','removeItem','clear'])Storage.prototype[name]=function(){window.__privacy.storage++;throw new Error('STORAGE_FORBIDDEN');};
    Object.defineProperty(document,'cookie',{configurable:true,get(){window.__privacy.cookies++;throw new Error('COOKIE_READ_FORBIDDEN');},set(){window.__privacy.cookies++;throw new Error('COOKIE_WRITE_FORBIDDEN');}});
    navigator.sendBeacon=()=>{window.__privacy.beacons++;return false;};
    for(const name of ['log','info','warn','error'])console[name]=()=>{window.__privacy.logs++;};
    window.KeepStoreRecentlyViewed={render(){window.__privacy.recent++;}};
    document.addEventListener('submit',e=>{window.__privacy.submits++;e.preventDefault();});
    const realFetch=window.fetch.bind(window);
    window.fetch=(url,opts)=>{window.__privacy.fetch.push({url:String(url),credentials:opts.credentials,cache:opts.cache});return realFetch(url,ignoreAbort?{...opts,signal:undefined}:opts);};
    const measuredFetch=window.fetch;
    window.fetch=(...args)=>{window.__fixtureStarted=performance.now();return measuredFetch(...args);};
    document.addEventListener('DOMContentLoaded',()=>{
      const root=document.getElementById('KsLocalAiSearch130');
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
    try{
      if(url.origin!==('https://'+host)){blocked.push(url.origin);await route.abort();return;}
      if(url.pathname===directory+'Default.aspx'){await route.fulfill({contentType:'text/html; charset=utf-8',body:html(directory,kind,options.mode)});return;}
      const assetKey=url.pathname.slice((directory+'Public/assets/keepstore/').length);
      if(url.pathname.startsWith(directory+'Public/assets/keepstore/')&&assets.has(assetKey)){
        await route.fulfill({contentType:assetKey.endsWith('.js')?'application/javascript; charset=utf-8':'text/css; charset=utf-8',body:assets.get(assetKey)});return;
      }
      if(url.pathname===directory+'search_suggest.aspx'){
        requests.push(req.url());
        const current={...config};
        if(current.delay)await new Promise(resolve=>setTimeout(resolve,current.delay));
        if(current.offline){await route.abort('internetdisconnected');return;}
        if(current.html){await route.fulfill({contentType:'text/html',body:'<html>synthetic unavailable</html>'});return;}
        let response=payload(req.url(),{...current,food:kind==='Food'});
        await route.fulfill({status:current.status||200,contentType:'application/json',body:current.raw||JSON.stringify(response)});return;
      }
      if(url.pathname===directory+'articolo.aspx'||url.pathname===directory+'articoli.aspx'){
        await route.fulfill({contentType:'text/html',body:'<p>Offline navigation target</p>'});return;
      }
      // Referenced theme media/fonts remain blocked; no operational asset is read.
      blocked.push(url.pathname);await route.abort();
    }catch(e){apiErrors.push(e.message);}
  });
  await page.goto('https://'+host+directory+'Default.aspx');
  const state=()=>page.locator('#KsLocalAiSearch130').getAttribute('data-ks-guide-state');
  const wait=async value=>{await page.waitForFunction(v=>document.getElementById('KsLocalAiSearch130').getAttribute('data-ks-guide-state')===v,value,{timeout:6000});};
  const submit=async(q='SKU120')=>{await page.locator('#ksGuideQuery').fill(q);await page.locator('[data-ks-guide-prepare]').click();await wait(config.empty?'empty':config.status===403||config.status===421?'context-invalid':config.status||config.raw||config.html||config.offline?'error':'results');};
  const refine=async cmd=>{await page.locator('#ksGuideCommand').fill(cmd);await page.locator('[data-ks-guide-apply]').click();await wait('results');};
  const privacy=async()=>{const p=await page.evaluate(()=>window.__privacy);record('memory-only privacy '+kind+' '+options.width,p.storage+p.cookies+p.beacons+p.logs+p.submits===0);record('fetch session/no-store policy',p.fetch.every(x=>x.credentials==='same-origin'&&x.cache==='no-store'));record('network contains only brief allowlist',p.fetch.every(x=>Array.from(new URL(x.url).searchParams.keys()).every(k=>['q','st','pmin','pmax','disponibile','ordinamento','limit','mode'].includes(k))));record('no application page error',pageErrors.length===0);record('HOME recent render hook preserved',p.recent>0);};
  const screenshot=async name=>{const file=path.join(evidence,name+'.png');await page.locator('#KsLocalAiSearch130').screenshot({path:file,animations:'disabled'});journal.resources.push(file);report.screenshots.push(file);};
  const close=async()=>{await context.close();journal.contextsClosed++;};
  return {context,page,config,requests,pageErrors,blocked,apiErrors,state,wait,submit,refine,privacy,screenshot,close};
}
async function run() {
  browser=await playwright.chromium.launch({executablePath:chrome,headless:true,args:['--disable-background-networking','--disable-component-update','--no-first-run']});
  report.browser=await browser.version();
  await rev1Regressions();
  if(regressionsOnly){report.status='PASS';return;}
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
      record('one optional question '+kind+width,await f.page.locator('.ks-guide-question').count()===1);
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
      record('comparison row/column semantics '+kind+width,await f.page.locator('.ks-guide-compare-grid tbody th[scope="row"]').count()===7&&await f.page.locator('.ks-guide-compare-item[scope="col"]').count()===3);
      if(width>=768){const tops=await f.page.locator('.ks-guide-price').evaluateAll(items=>items.map(e=>e.getBoundingClientRect().top));record('card price rows align '+kind+width,Math.abs(tops[0]-tops[1])<1);}
      const dims=await f.page.evaluate(()=>({w:innerWidth,doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,targets:[...document.querySelectorAll('#KsLocalAiSearch130 button:not([disabled]),#KsLocalAiSearch130 a,#KsLocalAiSearch130 .ks-guide-check')].filter(e=>e.getClientRects().length).map(e=>({tag:e.tagName,h:e.getBoundingClientRect().height}))}));
      record('no page horizontal overflow '+kind+width,dims.doc<=dims.w+1&&dims.body<=dims.w+1);
      record('44px applicable touch targets '+kind+width,dims.targets.every(x=>x.h>=43.9));
      if([360,390,768,1365].includes(width))await f.screenshot(kind+'-'+width+'-compare');
      const catalog=await f.page.getByRole('link',{name:'Continua nel catalogo con queste preferenze'}).getAttribute('href');
      record('catalog exact confirmed criteria '+kind+width,new URL(catalog).searchParams.get('pmax')==='500.5'&&new URL(catalog).searchParams.get('disponibile')==='1');
      const pdp=await f.page.getByRole('link',{name:'Vedi prodotto',exact:true}).first().getAttribute('href');
      record('PDP identity '+kind+width,new URL(pdp).searchParams.get('id')==='120'&&new URL(pdp).searchParams.get('TCId')==='42');
      await f.privacy();
      const destination=width===390||width===1365?'Vedi prodotto':'Continua nel catalogo con queste preferenze';
      await f.page.getByRole('link',{name:destination,exact:true}).first().click();
      record('complete flow navigation '+kind+width+' '+server[scenario].scenario,new URL(f.page.url()).pathname===(destination==='Vedi prodotto'?'/articolo.aspx':'/articoli.aspx'));
    }finally{await f.close();}
  }
  // Real serialized endpoint samples, all four commercial fixture contexts, virtual path.
  for(let scenario=0;scenario<4;scenario++){
    const f=await fixture({scenario,directory:'/shop/',count:1,mutate:p=>Object.assign(p,clone(server[scenario].payload))});
    try{await f.submit();record('real endpoint JSON renders '+scenario,await f.page.locator('.ks-guide-card').count()===1);
      record('virtual-directory request '+scenario,new URL(f.requests[0]).pathname==='/shop/search_suggest.aspx');
      await f.page.getByRole('link',{name:'Vedi prodotto',exact:true}).click();
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
    const f=await fixture({directory});
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
      check('availability question selected '+label,(await f.page.locator('.ks-guide-question').innerText()).includes('prodotti disponibili'));
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
(async()=>{
  try{await run();console.log('SHOPPING_PROGRESSIVE_ASSERTIONS='+report.assertions+'; BROWSER='+report.browser);}
  catch(error){report.status='FAIL';report.failure={name:error.name,message:error.message,stack:error.stack};console.error('SHOPPING_PROGRESSIVE_FAILED='+error.message);process.exitCode=1;}
  finally{if(browser){await browser.close();journal.browserClosed=true;}report.completedUtc=new Date().toISOString();artifact('browser-report.json',JSON.stringify(report,null,2));artifact('resource-journal.json',JSON.stringify(journal,null,2));}
})();
