[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaseRef = 'd7596e65d96d0843f98623fa773b92f525a6524f'
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'Run with Windows PowerShell 5.1 (System.Web).'}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
if(!$EvidenceDirectory.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase)){throw 'Evidence must be outside webroot in TEMP.'}
if(Test-Path -LiteralPath $EvidenceDirectory){throw 'Evidence directory must be new.'}
$utf8=New-Object Text.UTF8Encoding($false)
New-Item -ItemType Directory -Path $EvidenceDirectory | Out-Null
Add-Type -AssemblyName System.Web
$checks=New-Object 'Collections.Generic.List[object]'
function Check([string]$name,[bool]$pass){$checks.Add([pscustomobject]@{Name=$name;Pass=$pass});if(!$pass){throw ('NOTICE_ASSERT: '+$name)}}
function SaveJson([string]$name,$value){[IO.File]::WriteAllText((Join-Path $EvidenceDirectory $name),($value|ConvertTo-Json -Depth 14),$utf8)}
function ReadSource([string]$name){return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $name))}
function PanelBlock([string]$source,[string]$id){
    $pattern='(?s)<asp:Panel\b(?=[^>]*\bID="'+[regex]::Escape($id)+'")[^>]*>.*?</asp:Panel>'
    $matches=[regex]::Matches($source,$pattern)
    if($matches.Count -ne 1){throw ('Expected one panel: '+$id)}
    return $matches[0].Value
}
function Ancestors([string]$source,[string]$target){
    # Inspect real markup hierarchy, removing server expressions before tokenizing.
    $source=[regex]::Replace($source,'(?s)<%.*?%>|<!--.*?-->','')
    $stack=New-Object 'Collections.Generic.List[object]'
    foreach($m in [regex]::Matches($source,'<(?<close>/)?(?<tag>[a-zA-Z][\w:-]*)\b(?<attrs>[^>]*?)(?<self>/)?>')){
        $tag=$m.Groups['tag'].Value.ToLowerInvariant();$attrs=$m.Groups['attrs'].Value
        if($m.Groups['close'].Success){
            for($i=$stack.Count-1;$i -ge 0;$i--){if($stack[$i].Tag -eq $tag){$stack.RemoveRange($i,$stack.Count-$i);break}}
            continue
        }
        $id=[regex]::Match($attrs,'(?i)\bid="([^"]*)"').Groups[1].Value
        if($id -eq $target){return @($stack.ToArray())}
        if(!$m.Groups['self'].Success -and $tag -notmatch '^(area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr)$'){
            $stack.Add([pscustomobject]@{Tag=$tag;Id=$id;Attributes=$attrs})
        }
    }
    throw ('Missing markup control: '+$target)
}
function RenderPanel([string]$block,[bool]$enabled,[hashtable]$literals,[string]$summary=''){
    # Real System.Web Panel renders Visible=false as no DOM. Only its inner Literal
    # payload/ValidationSummary are materialized synthetic values, not a live checkout.
    $opening=[regex]::Match($block,'^<asp:Panel\b([^>]*)>')
    $attrs=@{};foreach($a in [regex]::Matches($opening.Groups[1].Value,'([\w:-]+)="([^"]*)"')){$attrs[$a.Groups[1].Value]=$a.Groups[2].Value}
    $panel=New-Object System.Web.UI.WebControls.Panel
    $panel.ID=$attrs['ID'];$panel.CssClass=$attrs['CssClass'];$panel.Visible=($attrs['Visible'] -ne 'false')
    foreach($key in $attrs.Keys){if($key -notin @('ID','CssClass','Visible','runat','ClientIDMode')){$panel.Attributes[$key]=$attrs[$key]}}
    if($enabled){$panel.Visible=$true}
    if(!$panel.Visible){
        $empty=New-Object IO.StringWriter;$hiddenWriter=New-Object System.Web.UI.HtmlTextWriter($empty)
        $panel.RenderControl($hiddenWriter);return $empty.ToString()
    }
    $inner=$block.Substring($opening.Length,$block.Length-$opening.Length-12)
    foreach($id in $literals.Keys){$inner=[regex]::Replace($inner,'<asp:Literal\b(?=[^>]*\bID="'+$id+'")[^>]*/>',[string]$literals[$id])}
    $inner=[regex]::Replace($inner,'<asp:ValidationSummary\b[^>]*/>',$summary)
    if($inner -match '<asp:'){throw 'Unsupported control in notice materializer'}
    $panel.Controls.Add((New-Object System.Web.UI.LiteralControl($inner)))
    $writer=New-Object IO.StringWriter;$html=New-Object System.Web.UI.HtmlTextWriter($writer)
    $panel.RenderControl($html);return $writer.ToString()
}
$source=ReadSource 'carrello.aspx';$vb=ReadSource 'carrello.aspx.vb'
$base=(& git -C $RepositoryRoot show ($BaseRef+':carrello.aspx')) -join "`n"
if($LASTEXITCODE -ne 0){throw 'Base unavailable'}
$base=$base.Replace("`r`n","`n");$source=$source.Replace("`r`n","`n")
$ids=@('pnlCartPriceRevalidation','pnlCheckoutSubmitError','pnlOrderInventoryAvailability')
$blocks=@{}
$recoveryPath=@(Ancestors $source 'pnlCartRecovery')
foreach($id in $ids){
    $blocks[$id]=PanelBlock $source $id
    Check ($id+' unchanged server markup/content/ARIA/Visible') ($blocks[$id] -ceq (PanelBlock $base $id))
    $parents=@(Ancestors $source $id)
    Check ($id+' shares recovery ancestry') (($parents|ConvertTo-Json -Compress) -ceq ($recoveryPath|ConvertTo-Json -Compress))
    Check ($id+' outside hidden cart and checkout panels') (@($parents|Where-Object {$_.Id -in @('CartItemsWrap','CartActionsWrap','CartSummaryColumn','tOrdine','pnlCheckoutConfirm') -or $_.Attributes -match 'd-none|\bhidden\s*=|ks-cart-step-cart-body|Visible="false"'}).Count -eq 0)
    Check ($id+' initially not rendered by real Panel') ((RenderPanel $blocks[$id] $false @{}).Length -eq 0)
}
$withoutNew=$source;$withoutOld=$base
foreach($id in $ids){$withoutNew=$withoutNew.Replace($blocks[$id],'');$withoutOld=$withoutOld.Replace((PanelBlock $base $id),'')}
$anchor='<span id="ksCartStockError" aria-hidden="true"></span>'
Check 'stock PRG anchor unique and preserved' (([regex]::Matches($source,[regex]::Escape($anchor))).Count -eq 1)
$withoutNew=$withoutNew.Replace($anchor,'');$withoutOld=$withoutOld.Replace($anchor,'')
Check 'only relocation; every other markup/control/CTA unchanged' (($withoutNew -replace '\s','') -ceq ($withoutOld -replace '\s',''))
Check 'baseline outside CartItemsWrap; hidden-parent premise not confirmed' (@(Ancestors $base 'pnlCheckoutSubmitError'|Where-Object {$_.Id -eq 'CartItemsWrap'}).Count -eq 0)
Check 'baseline in product stage column; candidate common placement is deliberate' (@(Ancestors $base 'pnlCheckoutSubmitError'|Where-Object {$_.Attributes -match 'class="ks-cart-stage-products"'}).Count -eq 1)
Check 'ValidationSummary group contract retained' ($blocks['pnlCheckoutSubmitError'] -match 'ID="vsCheckoutSubmit"[^>]*ValidationGroup="checkoutSubmit"')
Check 'server submit focus retained' ($vb -match "var e=document.getElementById\('pnlCheckoutSubmitError'\);if\(e\)\{e.focus\(\);\}")
Check 'server stock focus retained' ($vb -match "var e=document.getElementById\('pnlOrderInventoryAvailability'\);if\(e\)\{e.focus\(\);\}")
Check 'PRG address shipping payment route retained' ($vb -match '(?s)Case CheckoutFailureReason.ShippingAddressInvalid,\s*CheckoutFailureReason.ShippingMethodMissing,\s*CheckoutFailureReason.PaymentMethodMissing\s*SetCheckoutStep\("checkout"\)')
Check 'step hides item body; test must keep this behavior' ($vb -match 'CartItemsWrap.Attributes\("class"\) = css.Trim\(\)')
$prefix=$source.Substring(0,$source.IndexOf('<asp:Panel ID="pnlCartRecovery"'))
$sectionStart=$prefix.LastIndexOf('<section ');$prefix=$prefix.Substring($sectionStart)
$prefix=[regex]::Replace($prefix,'(?s)<%.*?%>','')
$prefix=[regex]::Replace($prefix,'(?s)<asp:LinkButton\b[^>]*ID="([^"]*)"[^>]*>(.*?)</asp:LinkButton>','<button type="button" id="$1" class="link body-text-3 ks-checkout-step-link">$2</button>')
$prefix=[regex]::Replace($prefix,'(?s)<asp:Label\b[^>]*>.*?</asp:Label>','')
# Use the real outer ancestry and headings; step title/intro below are fixture values.
$prefix=[regex]::Replace($prefix,'<h3 class="heading">.*?</h3>','<h3 class="heading">Fixture checkout</h3>')
$prefix=[regex]::Replace($prefix,'<p class="ks-cart-step-intro">.*?</p>','<p class="ks-cart-step-intro">Controlla i dati prima di procedere.</p>')
$fixtures=New-Object 'Collections.Generic.List[object]'
foreach($theme in @('Tech','Food')){
    $product=if($theme -eq 'Tech'){'Kit tastiera e mouse'}else{'Confezione alimentare assortita'}
    $encoded=[System.Web.HttpUtility]::HtmlEncode($product+' <test> & dettagli')
    foreach($step in @('cart','checkout','confirm')){
        foreach($scenario in @('none','address','shipping','payment','technical','conditions','stock','all')){
            $messages=@{address='Verifica la destinazione di spedizione.';shipping='Seleziona un metodo di spedizione.';payment='Seleziona un metodo di pagamento.';technical='Invio non completato. Riprova dopo aver verificato i dati.'}
            $submit=$scenario -in @('address','shipping','payment','technical','all')
            $price=$scenario -in @('conditions','all');$stock=$scenario -in @('stock','all')
            $msg=if($messages.ContainsKey($scenario)){$messages[$scenario]}else{'Controlla i dati prima di riprovare.'}
            $summary=if($submit){'<div id="vsCheckoutSubmit" class="mt-2">Controlla prima di riprovare:<ul><li>'+[System.Web.HttpUtility]::HtmlEncode($msg)+'</li></ul></div>'}else{''}
            $html=$prefix.Replace('ks-cart-modern ','ks-cart-modern ks-cart-step-'+$step+' ')
            foreach($id in $ids){
                $visible=if($id -eq $ids[0]){$price}elseif($id -eq $ids[1]){$submit}else{$stock}
                $values=@{litCartPriceRevalidation='Condizioni aggiornate per '+$encoded+'. Controlla gli importi prima di continuare.';litCheckoutSubmitError=[System.Web.HttpUtility]::HtmlEncode($msg);litOrderInventoryAvailability='<p class="ks-order-inventory-alert__lead">Disponibilità variata per '+$encoded+'.</p><ul class="ks-order-inventory-alert__items"><li class="ks-order-inventory-alert__item"><span class="ks-order-inventory-alert__code">SYNTHETIC-ITEM</span><span class="ks-order-inventory-alert__quantity">Richiesti<strong>3</strong></span><span class="ks-order-inventory-alert__quantity ks-order-inventory-alert__quantity--available">Disponibili<strong>1</strong></span></li></ul><p class="ks-order-inventory-alert__action">Controlla la quantità nel carrello.</p>'}
                $html+=RenderPanel $blocks[$id] $visible $values $summary
            }
            $html+=$anchor+'<div id="CartItemsWrap" class="row g-4 ks-cart-step-cart-body'+$(if($step -ne 'cart'){' d-none'}else{''})+'"><div class="col-12">'+$encoded+'</div></div></div></section>'
            $html+='<section class="ks-cart-page ks-cart-modern ks-checkout-shell ks-checkout-modern ks-cart-step-'+$step+'"><div class="container"><div class="ks-shipping-section"><label for="fixtureAddress">Indirizzo (fixture)</label><input id="fixtureAddress" value="Destinazione sintetica"></div><div class="ks-final-confirm-section">Riepilogo sintetico '+$encoded+'</div><button type="button" id="fixtureContinue" class="tf-btn">'+$(if($step -eq 'confirm'){'Invia ordine (fixture)'}else{'Continua (fixture)'})+'</button></div></section>'
            $fixtures.Add([pscustomobject]@{Theme=$theme;Step=$step;Scenario=$scenario;Html=$html;Submit=$submit;Price=$price;Stock=$stock})
        }
    }
}
SaveJson 'unit-report.json' @{Result='PASS';Count=$checks.Count;Checks=$checks.ToArray()}
SaveJson 'fixtures.json' $fixtures.ToArray()
$browser=@'
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const [root,dir]=process.argv.slice(2);
const req=createRequire(path.join(path.dirname(process.execPath),'../node_modules/entry.cjs'));
const {chromium}=req('playwright');
const fixtures=JSON.parse(await fs.readFile(path.join(dir,'fixtures.json'),'utf8'));
const checks=[],errors=[],missing=[],blocked=[];
function check(name,pass){checks.push({Name:name,Pass:!!pass});if(!pass)throw Error(name)}
const css=['fonts/font.css','icons/icomoon/style.css','css/bootstrap.min.css','css/keepstore.css','css/keepstore-overrides.css','css/ks-ui.css','css/styles.css','css/cart-ui.css','css/theme-overrides.css'];
const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
try{
 for(const width of [360,390,430,1365])for(const f of fixtures){
  const context=await browser.newContext({viewport:{width,height:844},isMobile:width<600,hasTouch:width<600,offline:true,serviceWorkers:'block'});
  const page=await context.newPage();page.on('pageerror',e=>errors.push(String(e)));
  const origin='https://checkout-'+f.Theme.toLowerCase()+'.invalid';
  await context.route('**/*',async route=>{
   const u=new URL(route.request().url());
   if(u.origin!==origin||route.request().method()!=='GET'){blocked.push(u.origin+u.pathname);return route.abort()}
   if(u.pathname==='/fixture')return route.fulfill({contentType:'text/html',body:'<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+css.map(p=>'<link rel="stylesheet" href="/Public/assets/keepstore/'+p+'">').join('')+'</head><body>'+f.Html+'</body></html>'});
   const file=path.resolve(root,'.'+decodeURIComponent(u.pathname));
   if(!file.toLowerCase().startsWith(path.resolve(root).toLowerCase()+path.sep)){blocked.push(u.pathname);return route.abort()}
   try{const ext=path.extname(file);return route.fulfill({body:await fs.readFile(file),contentType:ext==='.css'?'text/css':ext==='.woff2'?'font/woff2':ext==='.woff'?'font/woff':'application/octet-stream'})}catch{missing.push(u.pathname);return route.abort()}
  });
  try{
   await page.goto(origin+'/fixture',{waitUntil:'load'});await page.evaluate(()=>document.fonts.ready);
   const name=f.Theme+' '+width+' '+f.Step+' '+f.Scenario;
   const expected={pnlCheckoutSubmitError:f.Submit,pnlCartPriceRevalidation:f.Price,pnlOrderInventoryAvailability:f.Stock};
   for(const [id,show] of Object.entries(expected)){
    check(name+' '+id+' server visibility',await page.locator('#'+id).count()===(show?1:0));
    if(show){
     const state=await page.locator('#'+id).evaluate(e=>{
      let visible=true;for(let n=e;n;n=n.parentElement){const c=getComputedStyle(n);if(n.hidden||c.display==='none'||c.visibility==='hidden'||c.visibility==='collapse'||Number(c.opacity)===0)visible=false}
      const r=e.getBoundingClientRect();return {visible:visible&&r.width>0&&r.height>0,readable:e.innerText.trim().length>20,overflow:e.scrollWidth>e.clientWidth+1,font:parseFloat(getComputedStyle(e).fontSize)};
     });
     check(name+' '+id+' no hidden ancestor and readable',state.visible&&state.readable&&!state.overflow&&state.font>=12);
     if(id!=='pnlCartPriceRevalidation'){
      // Execute the existing server focus contract against the actual rendered ID.
      await page.evaluate(id=>{const e=document.getElementById(id);if(e)e.focus()},id);
      check(name+' '+id+' focus reachable',await page.evaluate(id=>document.activeElement.id===id,id));
     }
    }
   }
   check(name+' unique IDs, no raw server tags, no horizontal overflow',await page.evaluate(()=>{const ids=[...document.querySelectorAll('[id]')].map(e=>e.id);return new Set(ids).size===ids.length&&!document.querySelector('asp\\:panel,asp\\:literal')&&document.documentElement.scrollWidth<=innerWidth+1}));
   check(name+' existing step body remains hidden outside cart',await page.locator('#CartItemsWrap').isVisible()===(f.Step==='cart'));
   if(f.Scenario==='none'){
    await page.locator('#fixtureContinue').click();await page.locator('#lnkCheckoutStep1').focus();
    check(name+' normal CTA and keyboard step reachable',await page.evaluate(()=>document.activeElement.id==='lnkCheckoutStep1')&&await page.locator('#fixtureContinue').isVisible());
   }
   if(f.Scenario==='all'&&(width===390||width===1365))await page.screenshot({path:path.join(dir,f.Theme+'-'+width+'-'+f.Step+'.png'),fullPage:true});
  }finally{await context.close()}
 }
 check('no runtime errors, external requests, mutations or missing assets',errors.length===0&&missing.length===0&&blocked.length===0);
 const report={Result:'PASS',Count:checks.length,Chrome:browser.version(),Checks:checks,Errors:errors,Missing:missing,Blocked:blocked,Limits:'Real source panel ancestry/attributes and CSS; real System.Web Panel Visible rendering. Literal/ValidationSummary payloads, steps, products, CTA and navigation are synthetic; no WebForms lifecycle, PRG/session, order/payment, IIS or MySQL runtime certification.'};
 await fs.writeFile(path.join(dir,'browser-report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({Result:report.Result,Count:report.Count,Chrome:report.Chrome}));
}catch(e){await fs.writeFile(path.join(dir,'browser-failure.json'),JSON.stringify({Error:String(e),Checks:checks,Errors:errors,Missing:missing,Blocked:blocked},null,2));throw e}finally{await browser.close()}
'@
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'browser-harness.mjs'),$browser,$utf8)
$node=(Get-Command node -ErrorAction Stop).Source
& $node (Join-Path $EvidenceDirectory 'browser-harness.mjs') $RepositoryRoot $EvidenceDirectory
if($LASTEXITCODE -ne 0){throw 'NOTICE_BROWSER_FAILED'}
$report=Get-Content (Join-Path $EvidenceDirectory 'browser-report.json') -Raw|ConvertFrom-Json
SaveJson 'test-report.json' @{Result='PASS';SourceChecks=$checks.Count;BrowserChecks=$report.Count;Fixtures=$fixtures.Count;Widths=@(360,390,430,1365);Limits='Synthetic source/render/browser checks only; no live services.'}
Write-Output ('PASS notices: '+$checks.Count+' source/server-panel + '+$report.Count+' Chrome checks; '+$EvidenceDirectory)
