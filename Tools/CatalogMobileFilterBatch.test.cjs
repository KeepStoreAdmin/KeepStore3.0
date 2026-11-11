// Chrome presentation fixture: real controller and CSS; no IIS/MySQL or commerce I/O.
if (process.env.KS_DEPARTMENTS_ONLY === '1') {
 departmentsOnly().catch(e=>{console.error(e);process.exitCode=1;});
} else {
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
const markup = fs.readFileSync(path.join(root, 'articoli.aspx'), 'utf8');
for (const id of ['Drop_Filtra_Taglia', 'Drop_Filtra_Colore']) {
 check(new RegExp('<asp:Label\\b[^>]*AssociatedControlID="'+id+'"[^>]*>').test(markup), 'WebForms label '+id);
}
check((markup.match(/id="ksBatchStatus"/g)||[]).length===1, 'unique status id');
check(/id="ksBatchStatus"[^>]*class="visually-hidden"[^>]*role="status"[^>]*aria-live="polite"[^>]*aria-atomic="true"/.test(markup), 'persistent polite atomic status');
check(!/id="ksBatchPriceHint"[^>]*(?:role="status"|aria-live)/.test(markup), 'price hint not a second live region');
const cp = require('child_process');
const plan = fs.readFileSync(path.join(root, 'docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md'), 'utf8');
const oldPlan = cp.execFileSync('git', ['show','85cb83c20c0a5689ce1d7d8d7d11e096888e9254:docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md'],{encoding:'utf8',maxBuffer:4*1024*1024});
const normalize = s=>s.replace(/\r\n/g,'\n').trim();
const newSectionEnd = plan.indexOf('\n## ', plan.indexOf('KS-CATALOG-MOBILE-FILTER-BATCH-1A'));
check(newSectionEnd>0 && normalize(plan.slice(newSectionEnd))===normalize(oldPlan.slice(oldPlan.indexOf('\n## '))), 'historical Masterplan exact baseline');
check(plan.includes('462/462 controlli PASS') && !plan.includes('462/476 controlli PASS'), 'historical count restored');
const initial = '/store/articoli.aspx?q=caff%C3%A8%20%26%20t%C3%A8&st=2&ct=3&tp=8&inpromo=1&pid=9&pg=3&page=2&p=4&rimuovi=mr&ordine=p_alto&righe=24';
function html() {
 return `<!doctype html><meta charset="utf-8"><style>${css}
 body{margin:0}#ksCatalogFiltersPanel{background:white;padding:12px;box-sizing:border-box;width:min(100%,360px)}
 .visually-hidden{position:absolute!important;width:1px!important;height:1px!important;padding:0!important;margin:-1px!important;overflow:hidden!important;clip:rect(0,0,0,0)!important;white-space:nowrap!important;border:0!important}
 #ksCatalogFiltersPanel a{display:block;padding:12px}#overlay-filter.show{display:block}
 @media(max-width:1199.98px){#ksCatalogFiltersPanel:not(.show){display:none}}
 </style><form id="form1"><main id="ksCatalogPage"><button type="button" id="filterShop">Filtri</button>
 <div id="ksCatalogFiltersPanel" tabindex="-1"><button type="button" class="close-filter">X</button>
 ${['mr','tp','gr','sg'].map(k=>[1,7].map(v=>`<a id="${k}${v}" href="?${k}=${v}" data-ks-batch-key="${k}" data-ks-batch-value="${v}">${k} ${v}</a>`).join('')).join('')}
 <a id="deals" href="?inpromo=" aria-label="Offerte attivo" data-ks-batch-key="inpromo" data-ks-batch-value="1"><span>Offerte</span><small>Attivo</small></a>
 <a id="refurb" href="?ricondizionato=1" data-ks-batch-key="ricondizionato" data-ks-batch-value="1">Ricondizionati</a>
 <span data-ks-batch-key="disponibile" data-ks-batch-value="1"><input id="available" type="checkbox" onclick="window.posts++"><label for="available">Disponibili</label></span>
 ${['taglia','colore'].map(k=>`<label for="${k}">${k}</label><select id="${k}" data-ks-batch-key="${k}" onchange="window.posts++"><option value="0">Tutti</option><option value="17">Opzione</option></select>`).join('')}
 <button class="ks-catalog-price-apply" type="button">Prezzo</button><p id="ksBatchPriceHint" data-ks-batch-price-hint hidden>Applica o annulla prima del prezzo</p>
 <div id="ksBatchStatus" class="visually-hidden" role="status" aria-live="polite" aria-atomic="true"></div>
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
   check(await page.locator('#ksBatchStatus').textContent()==='2 opzioni selezionate.', 'initial count announcement');
   check((await page.locator('#ksBatchStatus').boundingBox()).height===1, 'status visually hidden without display none');
   check(await page.locator('#ksCatalogFiltersPanel [role="status"]').count()===1,'one panel live region');
   check(await page.locator('.close-filter').evaluate(n=>n===document.activeElement),'initial focus');
   await page.locator('.close-filter').press('Shift+Tab');
   check(await page.locator('#reset').evaluate(n=>n===document.activeElement),'focus trap');
   await page.locator('#mr1').click(); await page.locator('#mr7').press('Space');await page.locator('#gr1').press('Enter');
   await page.locator('#available').check();await page.locator('#taglia').selectOption('17');await page.locator('#colore').selectOption('17');await page.locator('#refurb').click();
   check(requests.length===0 && await page.evaluate(()=>window.posts)===0,'selection no I/O/postback');
   check(await page.locator('.ks-catalog-price-apply').isDisabled(),'price pending disabled');
   check(await page.locator('#ksBatchStatus').textContent()==='9 opzioni selezionate. Applica o annulla le selezioni prima di modificare il prezzo.', 'count and price announcement');
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
    check(await page.locator('#ksBatchStatus').count()===1 && await page.locator('#ksBatchStatus').textContent()==='', 'status retained and cleared '+close);
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
   check(await page.locator('#ksBatchStatus').textContent()==='2 opzioni selezionate.', 'warning removed after reverting');
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
 check(await page.locator('#ksBatchStatus').count()===1 && await page.locator('#ksBatchStatus').textContent()==='', 'no JS empty persistent status');
 check(await page.locator('#mr1').getAttribute('href')==='?mr=1','no JS native URL');await context.close();
 fs.writeFileSync(path.join(evidence,'result.json'),JSON.stringify({result:'PASS SOURCE Chrome presentation fixture',checks,viewports:[390,430,1365],iis:'NOT EXECUTED',mysql:'NOT EXECUTED'},null,2));console.log('PASS '+checks);
 } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
}
async function departmentsOnly() {
 const fs=require('fs'),path=require('path'),cp=require('child_process'),assert=require('assert/strict');
 const root=path.resolve(__dirname,'..'),dir=process.env.KS_EVIDENCE,base=process.env.KS_BASELINE;
 if(!dir||!base||!/^[0-9a-f]{40}$/.test(base))throw Error('Explicit TEMP evidence and baseline required');
 const norm=s=>s.replace(/\r\n/g,'\n'),read=p=>norm(fs.readFileSync(path.join(root,p),'utf8'));
 const old=p=>norm(cp.execFileSync('git',['show',base+':'+p],{cwd:root,encoding:'utf8',maxBuffer:8e6}));
 const checks=[];function check(ok,name){checks.push({name,pass:!!ok});assert(ok,name)}
 const method=(s,n)=>{const m=s.match(new RegExp('^ *?(?:Private|Public|Protected) (?:Shared )?(?:Sub|Function) '+n+'\\b[\\s\\S]*?^ *End (?:Sub|Function)','m'));assert(m,n);return m[0]};
 function panel(s,id){const start=s.indexOf('<asp:Panel ID="'+id+'"');assert(start>=0,id);let depth=0;for(const m of s.slice(start).matchAll(/<\/?asp:Panel\b[^>]*>/g)){depth+=m[0].startsWith('</')?-1:1;if(!depth)return s.slice(start,start+m.index+m[0].length)}throw Error('Panel end '+id)}
 const before=old('articoli.aspx.vb'),after=read('articoli.aspx.vb'),om=old('articoli.aspx'),nm=read('articoli.aspx');
 const nav='BindCatalogCategoryNavigation',cssPath='Public/assets/keepstore/css/catalog-filters-ui.css';
 check(before.replace(method(before,nav),'')===after.replace(method(after,nav),''),'code-behind outside navigation unchanged');
 check((method(after,nav).match(/CatalogMenuProvider.LoadCatalogMenuCached\(\)/g)||[]).length===1,'one provider call');
 check(panel(om,'ksFilters')===panel(nm,'ksFilters'),'entire ksFilters control tree unchanged');
 check(panel(om,'pnlCatalogPriceFilter')===panel(nm,'pnlCatalogPriceFilter'),'price attributes/default button unchanged');
 const tags=s=>[...s.matchAll(/<[\w:]+\b[^>]*runat="server"[^>]*>/g)].map(m=>m[0]).filter(s=>!/\bID="(?:pnlCatalogDepartmentsMobile|litCatalogCategoryNavMobile)"/.test(s)).sort();
 check(JSON.stringify(tags(om))===JSON.stringify(tags(nm)),'all existing server opening tags/IDs/bindings unchanged');
 check(nm.indexOf('pnlCatalogPriceFilter')>nm.indexOf('filtritagliaecolore')&&nm.indexOf('lnkCatalogDeals')>nm.indexOf('pnlCatalogPriceFilter')&&nm.indexOf('lnkCatalogRefurbished')>nm.indexOf('lnkCatalogDeals'),'price/deals/condition after variants');
 check(nm.indexOf('pnlCatalogDepartmentsMobile')>nm.indexOf('class="content-area"')&&nm.indexOf('pnlCatalogDepartmentsMobile')<nm.indexOf('id="ksCatalogResults"'),'standalone mobile panel before results');
 check(panel(nm,'pnlCatalogDepartmentsMobile').includes('ks-catalog-category-nav ks-catalog-departments-mobile d-xl-none'),'shared taxonomy CSS and desktop utility retained');
 for(const p of ['Public/assets/keepstore/js/catalog-ui.js','Public/assets/keepstore/css/catalog-ui.css','App_Code/CatalogMenuProvider.vb','App_Code/ThemeManager.vb'])
  check(read(p)===old(p),p+' unchanged');
 for(const n of ['DeferCatalogSideFiltersForSearch','BindDeferredCatalogSideFilters','HideDeferredCatalogSideFilters','BuildCatalogCategoryUrl'])
  check(method(before,n)===method(after,n),n+' unchanged');
 const provider=read('App_Code/CatalogMenuProvider.vb'),theme=read('App_Code/ThemeManager.vb');
 const types=provider.slice(provider.indexOf('Public Class CatalogMenuSector'),provider.indexOf('Public Module CatalogMenuProvider'));
 const common=['AppendCatalogNavItems','CatalogNavText','BuildCatalogCategoryUrl','TryReadPromotionCampaignId','HA','ShouldDeferCatalogSideFilters','DeferCatalogSideFiltersForSearch','BindDeferredCatalogSideFilters','HideDeferredCatalogSideFilters'];
 function fixtureMarkup(m){
 // Keep the actual parent tree, IDs and DataSourceID. Data-bound templates,
 // price event and inline reset expression are fixture I/O boundaries.
  let side=m.slice(m.indexOf('<div id="ksCatalogFiltersPanel"'),m.indexOf('<div class="content-area">'));
  return '<div class="tf-product-view-content wrapper-control-shop">'+side.replace(/\sOnClick="[^"]*"/g,'').replace(/<%=[\s\S]*?%>/g,'/store/articoli.aspx?st=14').replace(/<ItemTemplate>[\s\S]*?<\/ItemTemplate>/g,'<ItemTemplate><span>Fixture</span></ItemTemplate>')+
   '<div class="content-area">'+(m.includes('pnlCatalogDepartmentsMobile')?panel(m,'pnlCatalogDepartmentsMobile'):'')+
   '<div id="ksCatalogResults"><button type="button" id="filterShop">Filtri</button><p>Risultati fixture</p></div></div></div>';
 }
 let vb=`Imports System
Imports System.IO
Imports System.Data
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Globalization
Imports System.Collections.Generic
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.UI.HtmlControls
Imports System.Web.Hosting
Imports System.Web.Script.Serialization
${types}
Public Module ThemeManager
${method(theme,'CompactText')}
End Module
Public Class CatalogTaxonomyContext
 Public SectorId As Integer=14
 Public CategoryId As Integer=1413
End Class
Public Module CatalogMenuProvider
 Public Calls As Integer
 Public Mode As String
 Public Function LoadCatalogMenuCached() As List(Of CatalogMenuSector)
  Calls+=1
  Dim result As New List(Of CatalogMenuSector)
  If Mode="empty" Then Return result
  If Mode="invalid" Then
   result.Add(Nothing)
   result.Add(New CatalogMenuSector With {.Id=99,.Descrizione=""})
   Return result
  End If
  For i As Integer=1 To 15
   Dim s As New CatalogMenuSector With {.Id=i,.Descrizione=If(HttpContext.Current.Request.QueryString("tenant")="food","Alimentari ","Tecnologia ") & i.ToString() & " & accessori"}
   For j As Integer=1 To 13
    s.Categories.Add(New CatalogMenuCategory With {.Id=i*100+j,.Descrizione="Categoria " & j.ToString() & " <testo>"})
   Next
   result.Add(s)
  Next
  Return result
 End Function
End Module
Public Class FixtureRows
 Public Shared Reads As Integer
 Public Shared Function SelectRows() As DataTable
  Reads+=1
  Dim t As New DataTable
  t.Columns.Add("id",GetType(Integer)):t.Columns.Add("descrizione"):t.Columns.Add("Numero",GetType(Integer))
  t.Rows.Add(1,"Opzione uno",1):t.Rows.Add(7,"Opzione due",1)
  Return t
 End Function
End Class
Public Class FixtureItemTemplate
 Implements ITemplate
 Private ReadOnly Key As String
 Public Sub New(k As String)
  Key=k
 End Sub
 Public Sub InstantiateIn(container As Control) Implements ITemplate.InstantiateIn
  Dim a As New HtmlAnchor
  a.Attributes("class")="ks-filter-option link"
  a.Attributes("data-ks-batch-key")=Key
  AddHandler a.DataBinding,AddressOf Bind
  container.Controls.Add(a)
 End Sub
 Private Sub Bind(sender As Object,e As EventArgs)
  Dim a As HtmlAnchor=DirectCast(sender,HtmlAnchor)
  Dim row As DataRowView=DirectCast(DirectCast(a.NamingContainer,DataListItem).DataItem,DataRowView)
  a.HRef="articoli.aspx?" & Key & "=" & Convert.ToString(row("id"))
  a.Attributes("data-ks-batch-value")=Convert.ToString(row("id"))
  a.InnerText=Convert.ToString(row("descrizione"))
 End Sub
End Class
Public Class FixtureConnection
 Public Shared Opens As Integer
 Public Property ConnectionString As String
 Public Property State As ConnectionState
 Public Sub Open()
  Opens+=1:State=ConnectionState.Open
 End Sub
 Public Sub Close()
  State=ConnectionState.Closed
 End Sub
 Public Sub Dispose()
 End Sub
End Class
Public MustInherit Class ProbePage
 Inherits Page
 Public Sub New()
  AppRelativeVirtualPath="~/fixture.aspx"
 End Sub
 Protected pnlCatalogCategoryNav As Panel, pnlCatalogDepartmentsMobile As Panel
 Protected litCatalogCategoryNav As Literal, litCatalogCategoryNavMobile As Literal
 Protected ksFilters As Panel,filtritagliaecolore As Panel,pnlCatalogPriceFilter As Panel
 Protected FormView1 As FormView
 Protected DataList1 As DataList,DataList2 As DataList,DataList3 As DataList,DataList4 As DataList
 Protected catalogSideFiltersDeferred As Boolean,catalogSideFiltersBound As Boolean
 Protected catalogTagliaCandidateSql As String="",catalogColoreCandidateSql As String=""
 Protected Const CatalogNavInitialSectors As Integer=12,CatalogNavInitialCategories As Integer=10
 Public PhaseReads As Integer
 Protected MustOverride Function Markup() As String
 Protected MustOverride Sub NavigateBind()
 Protected MustOverride Sub Defer()
 Protected MustOverride Sub Finish()
 Protected Function FindId(c As Control,id As String) As Control
  If c.ID=id Then Return c
  For Each child As Control In c.Controls
   Dim found As Control=FindId(child,id)
   If found IsNot Nothing Then Return found
  Next
  Return Nothing
 End Function
 Protected Overrides Sub OnInit(e As EventArgs)
  MyBase.OnInit(e)
  Dim form As New HtmlForm With {.ID="form1"}:Controls.Add(form)
  form.Controls.Add(ParseControl(Markup()))
  For Each id As String In New String(){"sdsMarche","sdsTipologie","sdsGruppo","sdsSottogruppo"}
   form.Controls.Add(New ObjectDataSource("FixtureRows","SelectRows") With {.ID=id})
  Next
  pnlCatalogCategoryNav=DirectCast(FindId(Me,"pnlCatalogCategoryNav"),Panel)
  litCatalogCategoryNav=DirectCast(FindId(Me,"litCatalogCategoryNav"),Literal)
  pnlCatalogDepartmentsMobile=TryCast(FindId(Me,"pnlCatalogDepartmentsMobile"),Panel)
  litCatalogCategoryNavMobile=TryCast(FindId(Me,"litCatalogCategoryNavMobile"),Literal)
  ksFilters=DirectCast(FindId(Me,"ksFilters"),Panel):filtritagliaecolore=DirectCast(FindId(Me,"filtritagliaecolore"),Panel)
  pnlCatalogPriceFilter=DirectCast(FindId(Me,"pnlCatalogPriceFilter"),Panel)
  FormView1=DirectCast(FindId(Me,"FormView1"),FormView)
  DataList1=DirectCast(FindId(Me,"DataList1"),DataList):DataList2=DirectCast(FindId(Me,"DataList2"),DataList)
  DataList3=DirectCast(FindId(Me,"DataList3"),DataList):DataList4=DirectCast(FindId(Me,"DataList4"),DataList)
  DataList1.ItemTemplate=New FixtureItemTemplate("gr"):DataList2.ItemTemplate=New FixtureItemTemplate("mr")
  DataList3.ItemTemplate=New FixtureItemTemplate("tp"):DataList4.ItemTemplate=New FixtureItemTemplate("sg")
 End Sub
 Protected Overrides Sub OnLoad(e As EventArgs)
  MyBase.OnLoad(e):Defer():NavigateBind()
 End Sub
 Protected Overrides Sub OnLoadComplete(e As EventArgs)
  MyBase.OnLoadComplete(e):PhaseReads=FixtureRows.Reads
 End Sub
 Protected Overrides Sub OnPreRender(e As EventArgs)
  Finish():MyBase.OnPreRender(e)
 End Sub
 Protected Function GetCatalogTaxonomyContext() As CatalogTaxonomyContext
  Return New CatalogTaxonomyContext
 End Function
 Protected Sub showFilters(c As FixtureConnection,a As String,b As String)
  filtritagliaecolore.Visible=True
 End Sub
 Public Function Result() As Object
  Return New With {.provider=CatalogMenuProvider.Calls,.desktop=pnlCatalogCategoryNav.Visible,.mobile=(pnlCatalogDepartmentsMobile IsNot Nothing AndAlso pnlCatalogDepartmentsMobile.Visible),.desktopHtml=litCatalogCategoryNav.Text,.mobileHtml=If(litCatalogCategoryNavMobile Is Nothing,"",litCatalogCategoryNavMobile.Text),.filters=ksFilters.Visible,.brands=DataList2.Visible,.price=pnlCatalogPriceFilter.Visible,.phaseReads=PhaseReads,.reads=FixtureRows.Reads,.opens=FixtureConnection.Opens}
 End Function
End Class
`;
 for(const [version,s,m] of [['Baseline',before,om],['Candidate',after,nm]]){
  vb+=`Public Class ${version}Page
 Inherits ProbePage
 Protected Overrides Function Markup() As String
  Return Encoding.UTF8.GetString(Convert.FromBase64String("${Buffer.from(fixtureMarkup(m)).toString('base64')}"))
 End Function
 Protected Overrides Sub NavigateBind()
  BindCatalogCategoryNavigation()
 End Sub
 Protected Overrides Sub Defer()
  DeferCatalogSideFiltersForSearch()
 End Sub
 Protected Overrides Sub Finish()
  If catalogSideFiltersDeferred Then
   If Request.QueryString("results")="1" Then
    BindDeferredCatalogSideFilters()
   Else
    HideDeferredCatalogSideFilters()
   End If
  End If
 End Sub
${[nav,...common].map(n=>method(s,n).replace(/\bMySqlConnection\b/g,'FixtureConnection').replace('ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString','"fixture-no-connection"')).join('\n')}
End Class
`;
 }
 vb+=`Public Class Host
 Inherits MarshalByRefObject
 Public Function Run() As String
  Dim result As New List(Of Object)
  For Each version As String In New String(){"Baseline","Candidate"}
   For Each tenant As String In New String(){"tech","food"}
    For Each mode As String In New String(){"plain","search-results","search-empty","empty","invalid"}
     Dim q As String=If(mode.StartsWith("search"),"&q=caff%26test&inpromo=1&pid=9","")
     Dim sw As New StringWriter
     Dim c As New HttpContext(New SimpleWorkerRequest("fixture.aspx","tenant=" & tenant & "&results=" & If(mode="search-results","1","0") & q,sw))
     HttpContext.Current=c
     CatalogMenuProvider.Calls=0:CatalogMenuProvider.Mode=mode:FixtureRows.Reads=0:FixtureConnection.Opens=0
     Dim page As ProbePage=If(version="Baseline",CType(New BaselinePage,ProbePage),New CandidatePage)
     page.ProcessRequest(c)
     c.Response.Flush()
     result.Add(New With {.version=version,.tenant=tenant,.mode=mode,.data=page.Result(),.body=sw.ToString()})
     page.Dispose()
    Next
   Next
  Next
  Dim serializer As New JavaScriptSerializer With {.MaxJsonLength=4000000}
  Return serializer.Serialize(result)
 End Function
 Public Overrides Function InitializeLifetimeService() As Object
  Return Nothing
 End Function
End Class
`;
 fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'Departments.vb'),vb);
 const ps=`$ErrorActionPreference='Stop'
$dir=$env:KS_EVIDENCE
& "$env:windir\\Microsoft.NET\\Framework64\\v4.0.30319\\vbc.exe" /nologo /target:library /optionstrict+ /out:"$dir\\Departments.dll" /r:System.dll,System.Core.dll,System.Data.dll,System.Web.dll,System.Web.Extensions.dll "$dir\\Departments.vb"
if($LASTEXITCODE){throw 'COMPILE_FAILED'}
$app=Join-Path $dir 'app';[void][IO.Directory]::CreateDirectory((Join-Path $app 'bin'));[void][IO.Directory]::CreateDirectory((Join-Path $app 'cache'))
Copy-Item -LiteralPath (Join-Path $dir 'Departments.dll') -Destination (Join-Path $app 'bin\\Departments.dll')
$cache=[Security.SecurityElement]::Escape((Join-Path $app 'cache'))
[IO.File]::WriteAllText((Join-Path $app 'web.config'),('<configuration><connectionStrings><clear/></connectionStrings><system.web><compilation targetFramework="4.8" tempDirectory="'+$cache+'"/><httpRuntime targetFramework="4.8"/></system.web></configuration>'))
Add-Type -Path (Join-Path $dir 'Departments.dll')
$hosted=[System.Web.Hosting.ApplicationHost]::CreateApplicationHost([Host],'/store',($app+'\\'))
try{[IO.File]::WriteAllText((Join-Path $dir 'server.json'),$hosted.Run(),(New-Object Text.UTF8Encoding($false)))}catch{
 $exception=$_.Exception
 while($null-ne$exception){Write-Output ($exception.GetType().FullName+': '+$exception.Message);$exception=$exception.InnerException}
 throw
}
`;
 fs.writeFileSync(path.join(dir,'run.ps1'),ps);
 cp.execFileSync('C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe',['-NoProfile','-ExecutionPolicy','RemoteSigned','-File',path.join(dir,'run.ps1')],{env:process.env,stdio:'inherit',timeout:90000});
 const rows=JSON.parse(fs.readFileSync(path.join(dir,'server.json'),'utf8'));
 for(const r of rows.filter(r=>r.version==='Candidate')){
  const b=rows.find(b=>b.version==='Baseline'&&b.tenant===r.tenant&&b.mode===r.mode),d=r.data;
  check(d.provider===1&&d.desktopHtml===b.data.desktopHtml&&d.mobileHtml===d.desktopHtml,r.tenant+' '+r.mode+' single read identical HTML');
  check(d.desktop===b.data.desktop&&d.mobile===d.desktop&&!/\bid\s*=/.test(d.desktopHtml),r.tenant+' '+r.mode+' visibility no generated IDs');
  check(['filters','brands','price','phaseReads','reads','opens'].every(k=>d[k]===b.data[k]),r.tenant+' '+r.mode+' deferred visibility/bind counts unchanged');
 }
 const sample=rows.find(r=>r.version==='Candidate'&&r.tenant==='tech'&&r.mode==='search-results');
 check(sample.body.includes('ks-catalog-departments-mobile'),'Framework rendered fixture flushed before Chrome');
 check(sample.data.desktopHtml.includes('q=caff%26test')&&sample.data.desktopHtml.includes('inpromo=1')&&sample.data.desktopHtml.includes('pid=9')&&sample.data.desktopHtml.includes('ks-category-nav-sublink active'),'active category and search/promo URL preserved');
 const searchEmpty=rows.find(r=>r.version==='Candidate'&&r.mode==='search-empty');
 check(!searchEmpty.data.filters&&!searchEmpty.data.brands&&searchEmpty.data.price&&searchEmpty.data.reads===0&&searchEmpty.data.opens===0,'empty search defers brands without hiding price or performing I/O');
 const {createRequire}=require('module'),req=createRequire(path.join(path.dirname(process.execPath),'../node_modules/entry.cjs'));
 const pw=req('playwright'),styles=['bootstrap.min.css','styles.css','keepstore.css','keepstore-overrides.css','ks-ui.css','catalog-ui.css','catalog-filters-ui.css','catalog-product-flow.css'];
 const controller=read('Public/assets/keepstore/js/catalog-ui.js').split('  function setupCatalogFilterDialog()')[1].split('  function bindFilterTriggers()')[0];
 const browser=await pw.chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
 const navs=[],metrics=[];
 try{
  for(const width of [390,1365])for(const js of [false,true]){
   const context=await browser.newContext({viewport:{width,height:950},javaScriptEnabled:js,offline:true,serviceWorkers:'block'}),page=await context.newPage();
   const start='https://catalog.fixture/store/articoli.aspx?st=14&ct=1413&q=caff%26test&inpromo=1&pid=9&pg=3';
   const body='<!doctype html><html lang="it"><head><meta charset="utf-8">'+styles.map(p=>'<link rel="stylesheet" href="/Public/assets/keepstore/css/'+p+'">').join('')+'</head><body><main id="ksCatalogPage" class="flat-content ks-catalog-page"><div class="container">'+sample.body.replace(/<script\b[\s\S]*?<\/script>/gi,'')+'</div></main><div id="overlay-filter"></div></body></html>';
   // sample.body is a complete fragment rendered by a real Framework Page.
   let generated=[];
   await context.route('**/*',async route=>{
    const request=route.request(),url=new URL(request.url());
    if(url.origin!=='https://catalog.fixture'||request.method()!=='GET')throw Error('Unexpected fixture I/O');
    if(url.pathname.startsWith('/Public/')){const file=path.join(root,url.pathname);return route.fulfill({body:fs.readFileSync(file),contentType:'text/css'})}
    generated.push(url.href);navs.push({width,js,url:url.href,method:request.method()});return route.fulfill({contentType:'text/html',body});
   });
   await page.goto(start);
   if(js)await page.addScriptTag({content:'function setupCatalogFilterDialog()'+controller+'\nsetupCatalogFilterDialog();'});
   const mobile=page.locator('.ks-catalog-departments-mobile'),sidebar=page.locator('#ksCatalogFiltersPanel .ks-catalog-category-nav');
   fs.writeFileSync(path.join(dir,'fixture-'+width+'-'+js+'.html'),body);
   check((width===390?await mobile.isVisible():await mobile.isHidden())&&(width===390?await sidebar.isHidden():await sidebar.isVisible()),width+' js='+js+' separate visible taxonomy');
   check(await page.locator('[id]').evaluateAll(nodes=>new Set(nodes.map(n=>n.id)).size===nodes.length),width+' js='+js+' unique DOM IDs');
   check((await page.locator('#ksCatalogFiltersPanel .facet-title').allTextContents()).map(s=>s.trim()).join('|')==='Marche|Tipologie|Gruppi|Sottogruppi|Disponibilita|Varianti|Prezzo|Offerte|Condizione',width+' js='+js+' commercial DOM order');
   if(width===390){
    const summary=mobile.locator(':scope > details > summary');await summary.focus();await page.keyboard.press('Enter');
    check(await mobile.locator(':scope > details').evaluate(e=>e.open), 'native Enter opens js='+js);
    await summary.press('Space');check(!await mobile.locator(':scope > details').evaluate(e=>e.open),'native Space closes js='+js);await summary.press('Enter');
    check((await summary.boundingBox()).height>=44,'summary target >=44 js='+js);
    check(await summary.evaluate(e=>!['none','hidden'].includes(getComputedStyle(e).outlineStyle)),'summary focus visible js='+js);
    const links=mobile.locator('a:visible');const boxes=await links.evaluateAll(nodes=>nodes.map(n=>({w:n.getBoundingClientRect().width,h:n.getBoundingClientRect().height})));
    check(boxes.length>0&&boxes.every(b=>b.w>=44&&b.h>=44),'all visible mobile links >=44 js='+js);
    const nested=mobile.locator('.ks-taxonomy-disclosure-sectors > summary');const wasOpen=await nested.evaluate(e=>e.parentElement.open);await nested.focus();await page.keyboard.press('Enter');
    check(await nested.evaluate(e=>e.parentElement.open)!==wasOpen,'nested disclosure toggles js='+js);await nested.press('Enter');
    check(await mobile.locator('a.active').first().isVisible(),'active sector remains reachable through nested disclosure js='+js);
    await nested.press('Space');await nested.press('Space');
    const category=mobile.locator('a.ks-category-nav-sublink.active');await category.focus();
    check(await category.evaluate(e=>e===document.activeElement),'category keyboard reachable js='+js);
    const sectorUrl=new URL(await mobile.locator('a.ks-category-nav-link.active').getAttribute('href'),start);
    check(sectorUrl.searchParams.get('st')==='14'&&!sectorUrl.searchParams.has('ct')&&sectorUrl.searchParams.get('q')==='caff&test'&&sectorUrl.searchParams.get('pid')==='9','sector URL retains search/promo js='+js);
    if(js){
     await page.locator('#filterShop').click();await page.locator('[data-ks-batch-key="mr"]').first().click();
     check(generated.length===1,'mobile pending selection no navigation');
     await page.locator('[data-ks-batch-cancel]').click();check(generated.length===1,'cancel no navigation');
     await page.locator('#filterShop').click();await page.locator('[data-ks-batch-key="mr"]').first().click();await page.locator('[data-ks-batch-apply]').click();await page.waitForURL('**/*#ksCatalogResults');
     const u=new URL(page.url());check(u.searchParams.get('mr')==='1'&&u.searchParams.get('q')==='caff&test'&&u.searchParams.get('ct')==='1413'&&u.searchParams.get('pid')==='9'&&!u.searchParams.has('pg'),'one batch Apply preserves context');
     await page.goto(start);await page.addScriptTag({content:'function setupCatalogFilterDialog()'+controller+'\nsetupCatalogFilterDialog();'});
     await page.locator('#filterShop').click();const reset=page.locator('.btn-reset');await reset.click();await page.waitForURL('**/articoli.aspx?st=14');
     check(new URL(page.url()).search==='?st=14','native Reset unchanged');
     await page.goto(start);await page.addScriptTag({content:'function setupCatalogFilterDialog()'+controller+'\nsetupCatalogFilterDialog();'});await summary.click();
    }
    await page.screenshot({path:path.join(dir,'candidate-'+width+'-'+js+'.png'),fullPage:true});
    const href=await category.getAttribute('href');await category.press('Enter');await page.waitForURL(u=>u.href.endsWith(href));
    check(new URL(page.url()).searchParams.get('q')==='caff&test'&&new URL(page.url()).searchParams.get('ct')==='1413','native category GET context js='+js);
    await page.goBack();await page.goForward();check(new URL(page.url()).searchParams.get('ct')==='1413','Back/Forward native GET js='+js);
    metrics.push({width,js,summary:await summary.count(),minLinkHeight:Math.min(...boxes.map(b=>b.h))});
   }else{
    check(await sidebar.locator('a.active').first().isVisible(),'desktop active sector visible js='+js);
    check((await page.locator('#ksCatalogFiltersPanel').boundingBox()).width<width/2,'desktop sidebar stays beside content js='+js);
    await page.screenshot({path:path.join(dir,'candidate-'+width+'-'+js+'.png'),fullPage:true});
   }
   check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'no overflow '+width+' js='+js);
   await context.close();
  }
 }finally{await browser.close()}
 fs.writeFileSync(path.join(dir,'result.json'),JSON.stringify({result:'PASS SOURCE/System.Web and Chrome fixture',checks,serverCases:rows.length,metrics,navs,limits:['Provider/table rows/connection I/O replaced with in-memory fixtures; no MySQL/IIS','Page lifecycle uses real control tree and navigation/defer methods; bound templates, price event and reset expression isolated','No commerce results or real authentication exercised']},null,2));
 console.log('DEPARTMENTS_PASS checks='+checks.length+' serverCases='+rows.length);
}
