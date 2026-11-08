// Chrome presentation fixture: real controller and CSS; no IIS/MySQL or commerce I/O.
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const root = path.resolve(__dirname, '..');
const pw = require(process.env.KS_PLAYWRIGHT_MODULE);
const source = fs.readFileSync(path.join(root, 'Public/assets/keepstore/js/catalog-ui.js'), 'utf8');
const controller = source.slice(source.indexOf('  function setupCatalogFilterDialog()'), source.indexOf('  function bindFilterTriggers()'));
const css = fs.readFileSync(path.join(root, 'Public/assets/keepstore/css/catalog-filters-ui.css'), 'utf8');
const evidence = process.env.KS_EVIDENCE;
if (!evidence) throw Error('KS_EVIDENCE required outside repository');
fs.mkdirSync(evidence, {recursive:true});
let checks = 0;
function check(value, label) { assert(value, label); checks++; }
const initial = '/store/articoli.aspx?q=caff%C3%A8%20%26%20t%C3%A8&st=2&ct=3&tp=8&inpromo=1&pid=9&pg=3&page=2&p=4&rimuovi=mr&ordine=p_alto&righe=24';
function html() {
 return `<!doctype html><meta charset="utf-8"><style>${css}
 body{margin:0}#ksCatalogFiltersPanel{background:white;padding:12px;box-sizing:border-box;width:min(100%,360px)}
 #ksCatalogFiltersPanel a{display:block;padding:12px}#overlay-filter.show{display:block}
 @media(max-width:1199.98px){#ksCatalogFiltersPanel:not(.show){display:none}}
 </style><form id="form1"><main id="ksCatalogPage"><button type="button" id="filterShop">Filtri</button>
 <div id="ksCatalogFiltersPanel" tabindex="-1"><button type="button" class="close-filter">X</button>
 ${['mr','tp','gr','sg'].map(k=>[1,7].map(v=>`<a id="${k}${v}" href="?${k}=${v}" data-ks-batch-key="${k}" data-ks-batch-value="${v}">${k} ${v}</a>`).join('')).join('')}
 <a id="deals" href="?inpromo=" aria-label="Offerte attivo" data-ks-batch-key="inpromo" data-ks-batch-value="1"><span>Offerte</span><small>Attivo</small></a>
 <a id="refurb" href="?ricondizionato=1" data-ks-batch-key="ricondizionato" data-ks-batch-value="1">Ricondizionati</a>
 <span data-ks-batch-key="disponibile" data-ks-batch-value="1"><input id="available" type="checkbox" onclick="window.posts++"><label for="available">Disponibili</label></span>
 ${['taglia','colore'].map(k=>`<select id="${k}" data-ks-batch-key="${k}" onchange="window.posts++"><option value="0">Tutti</option><option value="17">Opzione</option></select>`).join('')}
 <button class="ks-catalog-price-apply" type="button">Prezzo</button><p id="ksBatchPriceHint" data-ks-batch-price-hint hidden role="status">Applica o annulla prima del prezzo</p>
 <div data-ks-batch-actions hidden class="ks-filter-batch-actions"><button type="button" class="tf-btn" data-ks-batch-apply>Applica</button><button type="button" class="tf-btn" data-ks-batch-cancel>Annulla</button></div>
 <a id="reset" href="/store/articoli.aspx?st=2">Reset filtri</a></div></main></form><div id="overlay-filter"></div>`;
}
(async()=>{
 const browser = await pw.chromium.launch({executablePath:process.env.KS_CHROME,headless:true});
 try {
 for (const width of [390,430,1365]) {
  const context = await browser.newContext({viewport:{width,height:950}}), page = await context.newPage();
  let requests=[]; await page.route('**/*', r=>{requests.push(r.request().url());return r.fulfill({contentType:'text/html',body:html()});});
  async function load(url=initial) { await page.goto('https://tenant.fixture'+url);await page.evaluate(()=>{window.posts=0;}); await page.addScriptTag({content:controller+'\nsetupCatalogFilterDialog();'});requests=[]; }
  await load();
  if(width===1365){
   check(await page.locator('[data-ks-batch-actions]').isHidden(),'desktop hidden');
   await page.locator('#available').check();await page.locator('#taglia').selectOption('17');
   check(await page.evaluate(()=>window.posts)===2,'desktop native handlers');
  } else {
   await page.locator('#filterShop').click();
   check(await page.locator('.close-filter').evaluate(n=>n===document.activeElement),'initial focus');
   await page.locator('.close-filter').press('Shift+Tab');
   check(await page.locator('#reset').evaluate(n=>n===document.activeElement),'focus trap');
   await page.locator('#mr1').click(); await page.locator('#mr7').press('Space');await page.locator('#gr1').press('Enter');
   await page.locator('#available').check();await page.locator('#taglia').selectOption('17');await page.locator('#colore').selectOption('17');await page.locator('#refurb').click();
   check(requests.length===0 && await page.evaluate(()=>window.posts)===0,'selection no I/O/postback');
   check(await page.locator('.ks-catalog-price-apply').isDisabled(),'price pending disabled');
   check(await page.locator('#mr7').getAttribute('aria-checked')==='true','aria selection');
   check(await page.locator('[data-ks-batch-apply]').innerText()==='Applica filtri (9)','active option count');
   check((await page.locator('[data-ks-batch-apply]').boundingBox()).height>=44,'touch size');
   await page.locator('[data-ks-batch-apply]').click();await page.waitForURL('**/*#ksCatalogResults');
   let url=new URL(page.url());check(requests.length===1,'one GET');
   check(url.host==='tenant.fixture' && url.pathname==='/store/articoli.aspx','same host/virtual directory');
   check(url.searchParams.get('mr')==='1|7' && url.searchParams.get('tp')==='8' && url.searchParams.get('gr')==='1','multi facet and untouched tp');
   check(url.searchParams.get('q')==='caffè & tè' && url.searchParams.get('pid')==='9' && url.searchParams.get('ordine')==='p_alto' && url.searchParams.get('righe')==='24' && url.searchParams.get('ct')==='3','context preserved');
   check(['pg','page','p','rimuovi'].every(k=>!url.searchParams.has(k)) && url.hash==='#ksCatalogResults','paging and anchor');
   check(url.searchParams.get('taglia')==='1|17' && url.searchParams.get('colore')==='1|17' && url.searchParams.get('disponibile')==='1','native option contracts');
   for(const close of ['[data-ks-batch-cancel]','.close-filter','Escape','breakpoint']){
    await load();await page.locator('#filterShop').click();await page.locator('#mr1').click();await page.locator('#available').check();
    if(close==='Escape') await page.keyboard.press('Escape'); else if(close==='breakpoint') await page.setViewportSize({width:1365,height:950}); else await page.locator(close).click();
    await page.locator('[data-ks-batch-actions]').waitFor({state:'hidden'});
    check(await page.locator('[data-ks-batch-actions]').isHidden() && !await page.locator('#available').isChecked(),'discard '+close);
    check(!await page.locator('.ks-catalog-price-apply').isDisabled(),'price restored '+close);
    check(await page.locator('#available').getAttribute('onclick')==='window.posts++','handler restored '+close);
    if(close!=='breakpoint') check(await page.locator('#filterShop').evaluate(n=>n===document.activeElement),'return focus '+close);
    await page.setViewportSize({width,height:950});
   }
   await load();await page.locator('#filterShop').click();await page.locator('#deals').click();
   check(await page.locator('#deals small').isHidden() && await page.locator('#deals').getAttribute('aria-label')==='Offerte','toggle description synchronized');
   await page.locator('[data-ks-batch-apply]').click();await page.waitForURL('**/*#ksCatalogResults');
   check(!new URL(page.url()).searchParams.has('pid') && !new URL(page.url()).searchParams.has('inpromo'),'deals clears pid');
   await load();await page.locator('#filterShop').click();await page.locator('#mr1').click();await page.locator('#mr1').click();
   check(!await page.locator('.ks-catalog-price-apply').isDisabled(),'reverted selection enables price');
   await page.locator('[data-ks-batch-apply]').click();check(requests.length===0,'unchanged closes without GET');
   await page.locator('#filterShop').click();await page.locator('#mr1').click();await page.evaluate(()=>document.getElementById('overlay-filter').click());
   check(await page.locator('[data-ks-batch-actions]').isHidden(),'overlay discard');
   await page.locator('#filterShop').click();check(await page.locator('#mr1').getAttribute('aria-checked')==='false','reopen original');
   check(await page.locator('#reset').getAttribute('href')==='/store/articoli.aspx?st=2','reset unchanged');
   check(!await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),'no overflow');
   await page.screenshot({path:path.join(evidence,'batch-'+width+'.png')});
  }
  await context.close();
 }
 const context=await browser.newContext({javaScriptEnabled:false,viewport:{width:390,height:950}}),page=await context.newPage();
 await page.route('**/*',r=>r.fulfill({contentType:'text/html',body:html()}));await page.goto('https://tenant.fixture/store/articoli.aspx');
 check(await page.locator('[data-ks-batch-actions]').isHidden(),'no JS batch hidden');
 check(await page.locator('#mr1').getAttribute('href')==='?mr=1','no JS native URL');await context.close();
 fs.writeFileSync(path.join(evidence,'result.json'),JSON.stringify({result:'PASS SOURCE Chrome presentation fixture',checks,viewports:[390,430,1365],iis:'NOT EXECUTED',mysql:'NOT EXECUTED'},null,2));console.log('PASS '+checks);
 } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
