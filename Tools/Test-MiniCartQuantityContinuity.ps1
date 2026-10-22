[CmdletBinding()]
param([string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'MINICART_REQUIRES_PS51'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\')
if(!$EvidenceDirectory.StartsWith($tempRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)){throw 'MINICART_INVALID_OUTPUT'}
$utf8=New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$work=Join-Path $tempRoot ('ks-mini-compile-'+[Guid]::NewGuid().ToString('N'))
$checks=New-Object 'Collections.Generic.List[object]'
function Check([string]$name,[bool]$ok){$checks.Add([pscustomobject]@{Name=$name;Pass=$ok});if(!$ok){throw ('MINICART_ASSERT: '+$name)}}
function Json([string]$file,$value){[IO.File]::WriteAllText((Join-Path $EvidenceDirectory $file),($value|ConvertTo-Json -Depth 15),$utf8)}
function Method-Map([string]$source){
 $map=@{}
 foreach($m in [regex]::Matches($source,'(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:ReadOnly )?(?:Function|Sub|Property) (\w+)\b.*?^    End (?:Function|Sub|Property)')){$map[$m.Groups[1].Value]=$m.Value}
 return $map
}
try{
 New-Item -ItemType Directory -Path $EvidenceDirectory,$work|Out-Null
 Add-Type -AssemblyName System.Web
 Add-Type -AssemblyName Microsoft.VisualBasic
 $mini=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Public/ui/controls/MiniCart.ascx.vb'))
 $markup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Public/ui/controls/MiniCart.ascx'))
 $cart=Method-Map ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CartMutationIdempotencyService.vb')))
 $read=Method-Map ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CartAuthoritativeReadModel.vb')))
 $nativeNames=@('CreateRequestId','BuildNativeSetActionValue','BuildSetQuantityPayload','NormalizeTCId','BuildRemoveRowPayload','BuildNativeRemoveRowActionValue','BuildClearCartPayload','BuildNativeClearCartActionValue')
 foreach($name in $nativeNames){if(!$cart.ContainsKey($name)){throw ('MINICART_NATIVE_METHOD: '+$name)}}
 $native="Imports System`nImports System.Globalization`nImports System.Web`nPublic Class CartMutationIdempotencyService`n"+(($nativeNames|ForEach-Object{$cart[$_]})-join "`n")+@'

    Public Shared Function GetOrCreateProgressiveRequestId(context As HttpContext, slot As String, operation As String, payload As String) As String
        Throw New InvalidOperationException("Synthetic fixture must use stateless native IDs.")
    End Function
End Class
'@
 $reader=@'
Imports System
Imports System.Data
Imports System.Globalization
Imports System.Web
Public Class CartAuthoritativeReadModel
    Private _items As DataTable
    Public Shared Fixture As CartAuthoritativeReadModel
    Public Sub New(rows As DataTable)
        _items=rows
    End Sub
    Public Shared Function GetCurrent(context As HttpContext) As CartAuthoritativeReadModel
        Return Fixture
    End Function
    Public ReadOnly Property HasOwner As Boolean
        Get
            Return True
        End Get
    End Property
'@
 $reader+="`n"+((@('TotalQuantity','TotalNet','TotalGross','GetAllItems','GetMiniCartItems','SumLineAmount','CopyRows','ReadColumn','SafeDecimal')|ForEach-Object{if(!$read.ContainsKey($_)){throw ('MINICART_READ_METHOD: '+$_)};$read[$_]})-join "`n")+"`nEnd Class"
 $fixture=@'
Imports System
Imports System.Data
Imports System.Collections.Generic
Imports System.Web
Imports System.Web.UI.WebControls
Partial Public Class MiniCart
    Protected lblMiniCartTotale As New Label()
    Protected phMiniCartEmpty As New PlaceHolder()
    Protected phMiniCartList As New PlaceHolder()
    Protected phMiniMoreItems As New PlaceHolder()
    Protected litMiniMoreItems As New Literal()
    Protected litMiniClearCart As New Literal()
    Protected rptMiniCart As New Repeater()
    Public Sub FixtureBind(rows As DataTable)
        CartAuthoritativeReadModel.Fixture=New CartAuthoritativeReadModel(rows)
        StatelessActionRequestIds=True
        BindMiniCart()
        RenderClearCartAction()
    End Sub
    Public Function FixtureQuantity(row As DataRow) As String
        Return RenderQuantityControl(row.Table.DefaultView(row.Table.Rows.IndexOf(row)))
    End Function
    Public Function FixtureMore() As String
        Return If(phMiniMoreItems.Visible,litMiniMoreItems.Text,"")
    End Function
    Public Function FixtureTotal() As String
        Return lblMiniCartTotale.Text
    End Function
    Public Function FixtureClear() As String
        Return litMiniClearCart.Text
    End Function
    Public Function FixtureModel() As CartAuthoritativeReadModel
        Return CartAuthoritativeReadModel.Fixture
    End Function
End Class
Public Class ThemeManager
    Public Shared Function ProductImageUrl(value As Object) As String
        Return "/fixture-product.svg"
    End Function
End Class
Public Class UiPriceFormatter
    Public Shared Function FormatStorefrontAmount(value As Decimal) As String
        Return value.ToString("N2",System.Globalization.CultureInfo.GetCultureInfo("it-IT"))
    End Function
End Class
'@
 $compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
 $options=New-Object CodeDom.Compiler.CompilerParameters
 $options.GenerateInMemory=$true;$options.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
 $options.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($work,$false)
 @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll','System.Web.dll')|ForEach-Object{[void]$options.ReferencedAssemblies.Add($_)}
 $compiled=$compiler.CompileAssemblyFromSource($options,[string[]]@($mini,$native,$reader,$fixture))
 if($compiled.Errors.HasErrors){throw ('MINICART_COMPILE: '+(($compiled.Errors|Where-Object{!$_.IsWarning}|ForEach-Object{'line '+$_.Line+': '+$_.ErrorText})-join '; '))}
 $control=[Activator]::CreateInstance($compiled.CompiledAssembly.GetType('MiniCart',$true))
 function Table {
  $dt=New-Object Data.DataTable
  @('id','ArticoliId','TCId')|ForEach-Object{[void]$dt.Columns.Add($_,[int])}
  @('Qnt','Prezzo','PrezzoIvato','Importo','ImportoIvato')|ForEach-Object{[void]$dt.Columns.Add($_,[decimal])}
  [void]$dt.Columns.Add('Descrizione1',[string]);[void]$dt.Columns.Add('Img1',[string])
  return ,$dt
 }
 function Add-Row($table,[int]$rowId,[int]$article,[int]$tcid,[decimal]$qty,[decimal]$price,[string]$name){
  $row=$table.NewRow();$row.id=$rowId;$row.ArticoliId=$article;$row.TCId=$tcid;$row.Qnt=$qty;$row.Prezzo=$price;$row.PrezzoIvato=$price*1.22;$row.Importo=$price*$qty;$row.ImportoIvato=$price*1.22*$qty;$row.Descrizione1=$name;$row.Img1='fixture-product.svg';[void]$table.Rows.Add($row);return $row
 }
 $probe=Table;$row=Add-Row $probe 1 101 7 2 10 'Prodotto "sicuro" <tag> & altro'
 $control.FixtureBind($probe);$html=$control.FixtureQuantity($row)
 Check 'real VB editor and exact identity' ($html.Contains("data-ks-id='101'") -and $html.Contains("data-ks-tcid='7'") -and $html.Contains("data-ks-quantity='2'"))
 $encoded=[regex]::Match($html,"name='ksCartAction' value='([^']*)'").Groups[1].Value
 $action=[Web.HttpUtility]::ParseQueryString([Web.HttpUtility]::HtmlDecode($encoded))
 Check 'real native cart-set field mapping' ($action['operation'] -eq 'cart-set' -and $action['id'] -eq '101' -and $action['tcid'] -eq '7' -and $action['qtyField'] -eq 'ksMiniQty_1' -and $html.Contains("form='ksNativeCartForm'"))
 Check 'native GUID and fresh stateless ID' ($action['requestId'] -match '^[a-f0-9]{32}$' -and $control.FixtureQuantity($row) -ne $html)
 Check 'product labels HTML encoded' (!$html.Contains('<tag>') -and $html.Contains('&lt;tag>') -and $html.Contains('&quot;sicuro&quot;'))
 $invalid=@(@{q=1.5;id=1;a=101},@{q=0;id=1;a=101},@{q=10000;id=1;a=101},@{q=2;id=0;a=101},@{q=2;id=1;a=0})
 foreach($case in $invalid){$t=Table;$r=Add-Row $t $case.id $case.a 7 $case.q 10 'Non standard';$control.FixtureBind($t);Check ('unsupported row readonly '+$case.q+':'+$case.id+':'+$case.a) ($control.FixtureQuantity($r).Contains('ks-mini-quantity-readonly'))}
 $duplicate=Table;$r=Add-Row $duplicate 100 101 7 2 10 'Duplicato';1..10|ForEach-Object{[void](Add-Row $duplicate (100+$_) (1000+$_) -1 1 5 'Altro')};[void](Add-Row $duplicate 1 101 7 1 10 'Duplicato nascosto')
 $control.FixtureBind($duplicate)
 Check 'duplicates including row beyond visible10 readonly' ($control.FixtureQuantity($r).Contains('ks-mini-quantity-readonly'))
 Check 'hidden row count boundaries' ([int]$compiled.CompiledAssembly.GetType('MiniCart').GetMethod('HiddenRowCount').Invoke($null,@(12,10)) -eq 2 -and [int]$compiled.CompiledAssembly.GetType('MiniCart').GetMethod('HiddenRowCount').Invoke($null,@(9,10)) -eq 0)
 $zero=Table;$r=Add-Row $zero 1 101 0 2 10 'Senza variante';$control.FixtureBind($zero)
 Check 'unselected variant normalized consistently' ($control.FixtureQuantity($r).Contains("data-ks-tcid='-1'"))
 $template=[regex]::Match($markup,'(?s)<ItemTemplate>(.*?)</ItemTemplate>').Groups[1].Value
 function Materialize($table){
  $control.FixtureBind($table)
  $shown=$control.FixtureModel().GetMiniCartItems(10)
  $parts=New-Object 'Collections.Generic.List[string]'
  foreach($r in $shown.Rows){
   $item=[regex]::Replace($template,'(?s)<%#\s*(.*?)\s*%>',[Text.RegularExpressions.MatchEvaluator]{param($m)
    $expression=$m.Groups[1].Value
    if($expression -eq 'RenderQuantityControl(Container.DataItem)'){return $control.FixtureQuantity($r)}
    if($expression.StartsWith('BuildRemoveCartActionValue')){return $control.BuildRemoveCartActionValue($r.id)}
    if($expression.StartsWith('GetProductUrl')){return ('/articolo.aspx?id='+$r.ArticoliId+'&amp;TCid='+$r.TCId)}
    if($expression.StartsWith('GetProductImg')){return '/fixture-product.svg'}
    if($expression.StartsWith('Server.HtmlEncode')){return [Web.HttpUtility]::HtmlEncode($r.Descrizione1)}
    if($expression.StartsWith('GetUnitPriceText')){return $control.GetUnitPriceText($r.Prezzo,$r.PrezzoIvato)}
    if($expression.StartsWith('GetLineTotalText')){return $control.GetLineTotalText($r.Importo,$r.ImportoIvato)}
    throw ('MINICART_UNKNOWN_BINDING: '+$expression)
   });$parts.Add($item)
  }
  $shell=[regex]::Replace($markup,'(?s)<%@.*?%>','')
  $shell=[regex]::Replace($shell,'(?s)<asp:PlaceHolder ID="phMiniCartEmpty".*?</asp:PlaceHolder>','')
  $shell=[regex]::Replace($shell,'(?s)<asp:Repeater\b.*?</asp:Repeater>',($parts-join "`n"))
  $shell=$shell.Replace('<asp:Literal ID="litMiniClearCart" runat="server" />',$control.FixtureClear())
  $shell=$shell.Replace('<asp:Literal ID="litMiniMoreItems" runat="server" />',$control.FixtureMore())
  if(!$control.FixtureMore()){$shell=[regex]::Replace($shell,'(?s)<asp:PlaceHolder ID="phMiniMoreItems".*?</asp:PlaceHolder>','')}
  $shell=[regex]::Replace($shell,'<asp:Label ID="lblMiniCartTotale"[^>]*/>',$control.FixtureTotal())
  $shell=[regex]::Replace($shell,'</?asp:PlaceHolder\b[^>]*>','')
  if($shell -match '<asp:|<%'){throw 'MINICART_UNMATERIALIZED_MARKUP'}
  return $shell
 }
 $fixtures=New-Object 'Collections.Generic.List[object]'
 foreach($tenant in @(@{Name='Tech';base=100;tcid=7;price=10},@{Name='Food';base=500;tcid=-1;price=3.25})){
  $rows=Table
  1..12|ForEach-Object{[void](Add-Row $rows (100+$_) ($tenant.base+$_) $tenant.tcid $(if($_ -eq 12){2}else{1}) $tenant.price ($tenant.Name+' prodotto '+$_))}
  $before=Materialize $rows;$model=$control.FixtureModel()
  Check ($tenant.Name+' full cart total and >10 notice') ($before.Contains('Mostrate 10 di 12 righe.') -and $before.Contains('Righe aggiuntive nel carrello completo: 2.') -and $model.TotalQuantity -eq 13 -and $model.TotalNet -eq $tenant.price*13 -and $model.TotalGross -eq $tenant.price*13*1.22)
  $items=@($rows.Rows|ForEach-Object{@{id=[string]$_.ArticoliId;tcid=[string]$_.TCId;qty=[decimal]$_.Qnt}})
  $changed=$rows.Copy();$changed.Rows[11].Qnt=3;$changed.Rows[11].Importo=$tenant.price*3;$changed.Rows[11].ImportoIvato=$tenant.price*3*1.22
  $after=Materialize $changed
  $afterItems=@($changed.Rows|ForEach-Object{@{id=[string]$_.ArticoliId;tcid=[string]$_.TCId;qty=[decimal]$_.Qnt}})
  $fixtures.Add([pscustomobject]@{Name=$tenant.Name;Id=[string]($tenant.base+12);Tcid=[string]$tenant.tcid;Before=$before;After=$after;BeforeResponse=@{ok=$true;cart=@{count=13;items=$items};miniCartHtml=$before};AfterResponse=@{ok=$true;cart=@{count=14;items=$afterItems};miniCartHtml=$after}})
 }
 Json 'fixtures.json' ($fixtures.ToArray())
 Json 'unit-report.json' @{Result='PASS';Checks=$checks.ToArray();Count=$checks.Count;Limits='Full real MiniCart VB plus extracted native/readmodel methods. DB access and theme/amount formatting mocked. Actual ASCX shell materialized; no WebForms lifecycle/IIS/MySQL certification.'}
 $browserScript=@'
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const [root,dir]=process.argv.slice(2),req=createRequire('C:/Users/Taikun/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/entry.cjs');
const {chromium}=req('playwright'),fixtures=JSON.parse(await fs.readFile(path.join(dir,'fixtures.json'),'utf8'));
const checks=[],errors=[],missing=[],blocked=[];
function check(name,pass){checks.push({Name:name,Pass:!!pass});if(!pass)throw Error(name)}
const css=['fonts/font.css','icons/icomoon/style.css','css/bootstrap.min.css','css/keepstore.css','css/keepstore-overrides.css','css/ks-ui.css','css/styles.css','css/minicart-ui.css','css/theme-overrides.css'];
const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
try{
 async function fixture(f,width,mode='success',js=true){
  const ctx=await browser.newContext({viewport:{width,height:844},isMobile:width<600,hasTouch:width<600,javaScriptEnabled:js,offline:true,serviceWorkers:'block'});
  const origin='https://mini-'+f.Name.toLowerCase()+'.invalid';let nativeBody='',posts=0,gets=0;
  const html='<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+css.map(p=>'<link rel="stylesheet" href="/Public/assets/keepstore/'+p+'">').join('')+(!js?'<style>#ksMiniCartCanvas{visibility:visible!important;transform:none!important}</style>':'')+'</head><body><button data-bs-toggle="offcanvas" data-bs-target="#ksMiniCartCanvas" data-ks-cart-count>13</button><span id="ksCartStateReconcile" data-ks-cart-state-endpoint="/cart_state_async.aspx" hidden></span>'+f.Before+'<form id="ksNativeCartForm" method="post" action="/cart_add.aspx"><input type="hidden" name="csrfToken" value="synthetic-only-csrf"><input type="hidden" name="ReturnUrl" value="/fixture"></form>'+(js?'<script src="/Public/assets/keepstore/js/bootstrap.min.js"></script><script src="/Public/assets/keepstore/js/keepstore-cart-state.js"></script><script src="/Public/assets/keepstore/js/ks-minicart-quantity.js"></script>':'')+'</body></html>';
  await ctx.route('**/*',async route=>{
   const request=route.request(),url=new URL(request.url());
   if(url.origin!==origin){blocked.push(url.origin+url.pathname);return route.abort()}
   if(url.pathname==='/fixture')return route.fulfill({contentType:'text/html',body:html});
   if(url.pathname==='/cart_add.aspx'){nativeBody=request.postData()||'';return route.fulfill({status:303,headers:{location:'/fixture'}})}
   if(url.pathname==='/fixture-product.svg')return route.fulfill({contentType:'image/svg+xml',body:'<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120"><rect width="120" height="120" rx="12" fill="#dfe8f0"/><text x="60" y="67" text-anchor="middle" font-size="18">'+f.Name+'</text></svg>'});
   const file=path.resolve(root,'.'+decodeURIComponent(url.pathname));
   if(!file.toLowerCase().startsWith(path.resolve(root).toLowerCase()+path.sep)){blocked.push(url.pathname);return route.abort()}
   try{const body=await fs.readFile(file),ext=path.extname(file);return route.fulfill({body,contentType:ext==='.css'?'text/css':ext==='.js'?'application/javascript':ext==='.woff2'?'font/woff2':ext==='.woff'?'font/woff':'application/octet-stream'})}catch{missing.push(url.pathname);return route.abort()}
  });
  if(js)await ctx.addInitScript(({before,after,mode})=>{
   const realFetch=window.fetch.bind(window);window.__miniTrace={posts:[],gets:[]};
   const realTimeout=window.setTimeout.bind(window);window.setTimeout=function(fn,ms,...args){return realTimeout(fn,mode==='timeout'&&ms===10000?30:ms,...args)};
   window.fetch=function(raw,options={}){
    const url=new URL(raw,location.href);
    if(url.pathname==='/cart_add.aspx'){
     window.__miniTrace.posts.push({body:options.body,method:options.method,redirect:options.redirect,credentials:options.credentials});
     if(mode==='network')return Promise.reject(new TypeError('synthetic network failure'));
     if(mode==='timeout')return new Promise((resolve,reject)=>options.signal.addEventListener('abort',()=>reject(new DOMException('aborted','AbortError'))));
     return new Promise(resolve=>realTimeout(()=>resolve({type:mode==='csrf'?'basic':'opaqueredirect',status:mode==='csrf'?403:0}),40));
    }
    if(url.pathname==='/cart_state_async.aspx'){
     window.__miniTrace.gets.push({method:options.method,credentials:options.credentials,cache:options.cache,url:url.href});
     if(mode==='snapshot-error')return Promise.resolve({ok:false,status:503});
     let payload=mode==='success'?after:before;
     if(mode==='removed'){
      payload=JSON.parse(JSON.stringify(before));
      const holder=document.createElement('div');holder.innerHTML=payload.miniCartHtml;
      const editor=holder.querySelector('[data-ks-mini-quantity]'),id=editor.getAttribute('data-ks-id'),tcid=editor.getAttribute('data-ks-tcid');
      editor.closest('.ks-mini-cart-item').remove();payload.miniCartHtml=holder.innerHTML;
      payload.cart.items=payload.cart.items.filter(item=>item.id!==id||item.tcid!==tcid);payload.cart.count=payload.cart.items.reduce((sum,item)=>sum+item.qty,0);
     }
     return Promise.resolve({ok:true,status:200,json:()=>Promise.resolve(mode==='invalid-response'?{ok:true,cart:{count:1,items:[]},miniCartHtml:'bad'}:payload)});
    }
    return realFetch(raw,options);
   };
  },{before:f.BeforeResponse,after:f.AfterResponse,mode});
  const page=await ctx.newPage();page.setDefaultTimeout(8000);page.setDefaultNavigationTimeout(10000);page.on('pageerror',e=>errors.push(String(e)));
  await page.goto(origin+'/fixture',{waitUntil:'networkidle'});
  if(js){await page.locator('[data-bs-toggle="offcanvas"]').click();await page.waitForFunction(()=>document.getElementById('ksMiniCartCanvas').classList.contains('show'));await page.waitForTimeout(250)}
  return {ctx,page,origin,nativeBody:()=>nativeBody};
 }
 const selector=f=>'[data-ks-mini-quantity][data-ks-id="'+f.Id+'"][data-ks-tcid="'+f.Tcid+'"]';
 for(const f of fixtures){
  for(const width of [390,1365]){
   const test=await fixture(f,width),{page,ctx}=test;
   try{
    const target=page.locator(selector(f)),input=target.locator('[data-ks-mini-quantity-input]'),button=target.locator('[data-ks-mini-update]');
    check(f.Name+' '+width+' only10 rows and hidden notice',await page.locator('.ks-mini-cart-item').count()===10&&(await page.locator('.ks-mini-more-items').innerText()).includes('10 di 12'));
    const metric=await page.evaluate(()=>{const c=document.getElementById('ksMiniCartCanvas'),b=c.querySelector('.offcanvas-body'),footer=c.querySelector('.ks-mini-cart-footer');return {overflow:document.documentElement.scrollWidth>innerWidth+1||c.scrollWidth>c.clientWidth+1,footer:footer.getBoundingClientRect().bottom<=innerHeight+1,scroll:b.scrollHeight>b.clientHeight,font:[document.body,c.querySelector('[data-ks-mini-quantity-input]'),c.querySelector('.ks-mini-quantity-editor label')].map(e=>getComputedStyle(e).fontFamily),targets:[...c.querySelectorAll('[data-ks-mini-update],[data-ks-mini-quantity-input],.ks-mini-remove,.ks-mini-cart-close')].map(e=>({w:e.getBoundingClientRect().width,h:e.getBoundingClientRect().height}))}});
    check(f.Name+' '+width+' mobile targets/footer/overflow',!metric.overflow&&metric.footer&&metric.scroll&&metric.targets.every(v=>v.w>=43.9&&v.h>=43.9));
    check(f.Name+' '+width+' globalArialfont',metric.font.every(font=>/^Arial\s*,\s*sans-serif$/i.test(font)));
    await input.fill('3');await input.focus();await page.evaluate(()=>{document.querySelector('#ksMiniCartCanvas .offcanvas-body').scrollTop=35});
    await input.press('Enter');await page.evaluate(()=>document.querySelector('[data-ks-mini-update]').click());
    await page.waitForFunction(()=>document.querySelector('[data-ks-mini-quantity-status]').getAttribute('data-state')==='saved');
    const trace=await page.evaluate(()=>window.__miniTrace),body=new URLSearchParams(trace.posts[0].body),action=new URLSearchParams(body.get('ksCartAction'));
    check(f.Name+' '+width+' exact native POST2to3 single mutation',trace.posts.length===1&&trace.gets.length===1&&body.get(action.get('qtyField'))==='3'&&action.get('id')===f.Id&&action.get('tcid')===f.Tcid&&action.get('operation')==='cart-set'&&body.get('csrfToken')==='synthetic-only-csrf'&&trace.posts[0].redirect==='manual');
    check(f.Name+' '+width+' authoritative snapshot and counters',await target.locator('[data-ks-mini-quantity-input]').inputValue()==='3'&&(await page.locator('[data-ks-cart-count]').innerText())==='14');
    const restored=await page.evaluate(()=>({focus:document.activeElement.hasAttribute('data-ks-mini-quantity-input'),scroll:document.querySelector('#ksMiniCartCanvas .offcanvas-body').scrollTop,open:document.getElementById('ksMiniCartCanvas').classList.contains('show')}));
    check(f.Name+' '+width+' drawer focus and scroll continuity',restored.focus&&Math.abs(restored.scroll-35)<=1&&restored.open);
    await target.locator('[data-ks-mini-update]').click();await page.waitForTimeout(30);
    check(f.Name+' '+width+' unchanged quantity noPOST',(await page.evaluate(()=>window.__miniTrace.posts.length))===1);
    await page.screenshot({path:path.join(dir,f.Name+'-'+width+'.png'),fullPage:true});
   }finally{await ctx.close()}
  }
 }
 for(const width of [360,430]){const {ctx,page}=await fixture(fixtures[0],width);try{check('responsive '+width,await page.evaluate(()=>{const c=document.getElementById('ksMiniCartCanvas'),f=c.querySelector('.ks-mini-cart-footer');return document.documentElement.scrollWidth<=innerWidth+1&&c.scrollWidth<=c.clientWidth+1&&f.getBoundingClientRect().bottom<=innerHeight+1}));}finally{await ctx.close()}}
 for(const mode of ['stock','csrf','network','timeout','snapshot-error','invalid-response','request-invalid','removed']){
  console.log('MiniCart negative: '+mode);
  const f=fixtures[0],{ctx,page}=await fixture(f,390,mode);
  try{
   const target=page.locator(selector(f));await target.locator('[data-ks-mini-quantity-input]').fill('3');
   if(mode==='request-invalid')await target.locator('[data-ks-mini-update]').evaluate(e=>e.value=e.value.replace(/requestId=[^&]+/,'requestId=invalid'));
   if(mode==='removed'){await target.locator('[data-ks-mini-quantity-input]').focus();await target.locator('[data-ks-mini-quantity-input]').press('Enter');}
   else await target.locator('[data-ks-mini-update]').click();
   await page.waitForFunction(()=>document.querySelector('[data-ks-mini-quantity-status]').getAttribute('data-state')==='error');
   const trace=await page.evaluate(()=>window.__miniTrace);
   check(mode+' nofalse success or POST retry',trace.posts.length===(mode==='request-invalid'?0:1)&&!await page.locator('[data-ks-mini-quantity-status]').evaluate(e=>e.getAttribute('data-state')==='saved'));
   if(mode==='removed')check('removed editor restores focus to fullcart action',await page.evaluate(()=>document.activeElement.hasAttribute('data-ks-cart-full-link')));
   else if(mode!=='stock'){check(mode+' uncertain/denied blocks unsafe retry',await page.locator('[data-ks-mini-update]').first().isDisabled())}
  }finally{await ctx.close()}
 }
 console.log('MiniCart native no-JS actions');
 const f=fixtures[0],native=await fixture(f,390,'native',false);
 try{
  const target=native.page.locator(selector(f));
  await target.locator('[data-ks-mini-quantity-input]').focus();
  await target.locator('[data-ks-mini-quantity-input]').press('Enter');
  await native.page.waitForTimeout(50);
  check('noJS Enter draft cannot submit unrelated shared-form actions',native.nativeBody()==='');
  await target.locator('[data-ks-mini-quantity-input]').fill('3');
  await Promise.all([native.page.waitForURL('**/fixture'),target.locator('[data-ks-mini-update]').click()]);
  const body=new URLSearchParams(native.nativeBody()),action=new URLSearchParams(body.get('ksCartAction'));
  check('noJS native form POST identity csrf and named input',action.get('operation')==='cart-set'&&action.get('id')===f.Id&&action.get('tcid')===f.Tcid&&body.get(action.get('qtyField'))==='3'&&body.get('csrfToken')==='synthetic-only-csrf');
  await native.page.locator('[data-ks-mini-quantity-input]').first().fill('nonnumeric draft');
  await native.page.locator('.ks-mini-remove').first().click();
  check('invalid MiniCart draft doesnot block native removal',new URLSearchParams(new URLSearchParams(native.nativeBody()).get('ksCartAction')).get('operation')==='cart-remove-row');
  await native.page.locator('[data-ks-mini-quantity-input]').first().fill('nonnumeric draft');
  await native.page.locator('.ks-mini-cart-toolbar button').click();
  check('invalid MiniCart draft doesnot block native clear',new URLSearchParams(new URLSearchParams(native.nativeBody()).get('ksCartAction')).get('operation')==='cart-clear');
 }finally{await native.ctx.close()}
 check('no browser errors/external requests or missing assets',errors.length===0&&missing.length===0&&blocked.length===0);
 const report={Result:'PASS',Chrome:browser.version(),Checks:checks,Count:checks.length,Errors:errors,Missing:missing,Blocked:blocked,Limits:'Offline routed synthetic hosts and mocked POST/GET transport. Real MiniCart renderer/materializedASCX, realCSS/Bootstrap/newJS/cart-stateAPI. NoIIS/MySQL,stockengine,CSRFengine,idempotencystore,login orproduction certification. Native no-JS form actions/303/Enter tested with drawer made visible by fixture CSS; existing JS-dependent drawer opening is not certified as no-JS navigation.'};
 await fs.writeFile(path.join(dir,'browser-report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({Result:report.Result,Count:report.Count,Chrome:report.Chrome}));
}catch(error){await fs.writeFile(path.join(dir,'browser-failure.json'),JSON.stringify({error:String(error),checks,errors,missing,blocked},null,2));throw error}finally{await browser.close()}
'@
 [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'browser-harness.mjs'),$browserScript,$utf8)
 $node=(Get-Command node -ErrorAction Stop).Source
 & $node (Join-Path $EvidenceDirectory 'browser-harness.mjs') $RepositoryRoot $EvidenceDirectory
 if($LASTEXITCODE -ne 0){throw 'MINICART_BROWSER_FAILED'}
 $browserReport=Get-Content -LiteralPath (Join-Path $EvidenceDirectory 'browser-report.json') -Raw|ConvertFrom-Json
 Json 'test-report.json' @{Result='PASS';UnitChecks=$checks.Count;BrowserChecks=$browserReport.Count;EvidenceDirectory=$EvidenceDirectory;Limits='Synthetic/offline only. ReadModel DB access and transport mocked; no live operational writes or certification.'}
 Write-Output ('PASS MiniCart: '+$checks.Count+' VB/native + '+$browserReport.Count+' browser checks; '+$EvidenceDirectory)
}finally{
 if(Test-Path -LiteralPath $work){$resolved=[IO.Path]::GetFullPath($work);if(!$resolved.StartsWith($tempRoot+'\ks-mini-compile-',[StringComparison]::OrdinalIgnoreCase)){throw 'MINICART_UNSAFE_CLEANUP'};Remove-Item -LiteralPath $resolved -Recurse -Force}
}
