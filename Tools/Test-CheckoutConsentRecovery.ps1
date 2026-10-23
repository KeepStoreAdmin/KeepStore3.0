[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaseRef = 'b1b2b9d8e27a2a9b42a44d2f99f9b820cb563cc4'
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'Use Windows PowerShell 5.1 / .NET Framework.'}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
if(!$EvidenceDirectory.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase)){throw 'Evidence must be in TEMP, outside webroot.'}
if(Test-Path -LiteralPath $EvidenceDirectory){throw 'Evidence directory must be new.'}
New-Item -ItemType Directory -Path $EvidenceDirectory|Out-Null
$utf8=New-Object Text.UTF8Encoding($false)
$checks=New-Object 'Collections.Generic.List[object]'
function Check([string]$name,[bool]$pass){$checks.Add([pscustomobject]@{Name=$name;Pass=$pass});if(!$pass){throw ('CONSENT_ASSERT: '+$name)}}
function SaveJson([string]$name,$value){[IO.File]::WriteAllText((Join-Path $EvidenceDirectory $name),($value|ConvertTo-Json -Depth 14),$utf8)}
function Source([string]$name){return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $name))}
function BaseSource([string]$name){
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=(Get-Command git.exe -ErrorAction Stop).Source
    $info.WorkingDirectory=$RepositoryRoot;$info.Arguments='show "'+$BaseRef+':'+$name+'"'
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.StandardOutputEncoding=$utf8
    $process=[Diagnostics.Process]::Start($info)
    try{$s=$process.StandardOutput.ReadToEnd();$diagnostic=$process.StandardError.ReadToEnd();$process.WaitForExit();if($process.ExitCode -ne 0){throw 'Base unavailable'};return $s}finally{$process.Dispose()}
}
function Normalize([string]$s){return $s.Replace("`r`n","`n")}
function Render([System.Web.UI.Control]$control){$s=New-Object IO.StringWriter;$w=New-Object System.Web.UI.HtmlTextWriter($s);$control.RenderControl($w);return $s.ToString()}
Add-Type -AssemblyName System.Web
$source=Source 'carrello.aspx';$vb=Source 'carrello.aspx.vb';$base=BaseSource 'carrello.aspx'
Check 'code-behind byte content unchanged' ((Normalize $vb) -ceq (Normalize (BaseSource 'carrello.aspx.vb')))
Check 'external checkout UI unchanged' ((Normalize (Source 'Public/assets/keepstore/js/checkout-ui.js')) -ceq (Normalize (BaseSource 'Public/assets/keepstore/js/checkout-ui.js')))
# Select the inline block containing the validator, without consuming earlier scripts.
$script=@([regex]::Matches($source,'(?s)<script\b[^>]*>(.*?)</script>')|Where-Object {$_.Groups[1].Value.Contains('window.ksValidateCheckoutTermsConsent')})
$baseScript=@([regex]::Matches($base,'(?s)<script\b[^>]*>(.*?)</script>')|Where-Object {$_.Groups[1].Value.Contains('window.ksValidateCheckoutTermsConsent')})
Check 'one existing consent script' ($script.Count -eq 1 -and $baseScript.Count -eq 1)
$scriptText=$script[0].Groups[1].Value
$notes='(?s)function wireOrderNotesLimit\(\).*'
Check 'order notes script unchanged' ((Normalize ([regex]::Match($scriptText,$notes).Value)) -ceq (Normalize ([regex]::Match($baseScript[0].Groups[1].Value,$notes).Value)))
$labelPattern='<asp:Label ID="lblTermsConsentError"[^>]*/>'
$labelMarkup=[regex]::Match($source,$labelPattern).Value
Check 'native error Label contract preserved' ($labelMarkup -ceq [regex]::Match($base,$labelPattern).Value)
$wrapper='<span id="ksTermsConsentFeedback" class="text-danger body-text-3" aria-live="polite">'+$labelMarkup+'</span>'
$without=$source.Replace($script[0].Value,'SCRIPT').Replace($wrapper,$labelMarkup)
$withoutBase=$base.Replace($baseScript[0].Value,'SCRIPT')
Check 'only consent feedback wrapper and consent script changed' ((Normalize $without) -ceq (Normalize $withoutBase))
Check 'checkbox remains initially unchecked, static, without AutoPostBack' ($source.Contains('<asp:CheckBox ID="chkTermsConsent" runat="server" ClientIDMode="Static" />'))
$validator=[regex]::Match($source,'<asp:CustomValidator ID="cvCheckoutTerms"[^>]*/>').Value
Check 'server validator unchanged and client scripting disabled' ($validator -ceq [regex]::Match($base,'<asp:CustomValidator ID="cvCheckoutTerms"[^>]*/>').Value -and $validator.Contains('EnableClientScript="false"') -and $validator.Contains('OnServerValidate="cvCheckoutSubmit_ServerValidate"'))
Check 'server validator invokes authoritative consent' ($vb -match 'Case "cvCheckoutTerms"\s+args.IsValid = TermsConsentAccepted\(\)')
Check 'order submit still independently rejects missing consent' ($vb -match 'If Not TermsConsentAccepted\(\) Then\s+DispatchCheckoutFailure\(CheckoutFailureReason.TermsNotAccepted, "04-checkout-terms"\)\s+Return')
Check 'no new JS transport or submit in consent script' ($scriptText -notmatch '\b(fetch|XMLHttpRequest|requestSubmit|__doPostBack)\b|\.submit\(')
$terms=[regex]::Match($vb,'(?s)    Private Function TermsConsentAccepted\(\) As Boolean.*?    End Function').Value
$native=@'
Imports System
Imports System.IO
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Public Class ConsentNamingScope
    Inherits Panel
    Implements INamingContainer
End Class
Public Class ConsentRenderPage
    Inherits Page
    Public Overrides Sub VerifyRenderingInServerForm(control As Control)
        ' Rendering-only fixture, not a page request or an order.
    End Sub
End Class
Public Class ConsentNativeFixture
    Private chkTermsConsent As CheckBox
    Public Function Accepted(mode As Integer) As Boolean
        chkTermsConsent = If(mode < 0, Nothing, New CheckBox With {.Checked = mode > 0})
        Return TermsConsentAccepted()
    End Function
    Public Function SendLink(id As String, text As String, css As String, clientClick As String, group As String) As String
        Dim page As New ConsentRenderPage With {.EnableEventValidation = False}
        Dim form As New HtmlForm With {.ID = "form1"}
        page.Controls.Add(form)
        Dim scope As New ConsentNamingScope With {.ID = "MainContent"}
        form.Controls.Add(scope)
        Dim validator As New CustomValidator With {.ID = "cvCheckoutTerms", .ValidationGroup = group, .EnableClientScript = False, .Display = ValidatorDisplay.None}
        scope.Controls.Add(validator)
        page.Validators.Add(validator)
        Dim link As New LinkButton With {.ID = id, .Text = text, .CssClass = css, .OnClientClick = clientClick, .CausesValidation = True, .ValidationGroup = group}
        scope.Controls.Add(link)
        Dim output As New StringWriter
        link.RenderControl(New HtmlTextWriter(output))
        Return output.ToString()
    End Function
__TERMS__
End Class
'@
$native=$native.Replace('__TERMS__',$terms)
$compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
$options=New-Object CodeDom.Compiler.CompilerParameters
$options.GenerateInMemory=$true
$options.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($EvidenceDirectory,$false)
@('System.dll','System.Web.dll')|ForEach-Object {[void]$options.ReferencedAssemblies.Add($_)}
$compiled=$compiler.CompileAssemblyFromSource($options,[string[]]@($native))
if($compiled.Errors.HasErrors){throw (($compiled.Errors|Where-Object {!$_.IsWarning}|ForEach-Object {$_.ErrorText})-join '; ')}
$fixture=[Activator]::CreateInstance($compiled.CompiledAssembly.GetType('ConsentNativeFixture',$true))
Check 'real TermsConsentAccepted: null rejected' (!$fixture.Accepted(-1))
Check 'real TermsConsentAccepted: unchecked rejected' (!$fixture.Accepted(0))
Check 'real TermsConsentAccepted: checked accepted' ($fixture.Accepted(1))
$sendMarkup=[regex]::Match($source,'(?s)<asp:LinkButton\b(?=[^>]*ID="btInviaOrdine")[^>]*>(.*?)</asp:LinkButton>').Value
function Attr([string]$s,[string]$n){return [regex]::Match($s,'\b'+$n+'="([^"]*)"').Groups[1].Value}
$send=$fixture.SendLink((Attr $sendMarkup 'ID'),([regex]::Match($sendMarkup,'>(.*?)</asp:LinkButton>').Groups[1].Value),(Attr $sendMarkup 'CssClass'),(Attr $sendMarkup 'OnClientClick'),(Attr $sendMarkup 'ValidationGroup'))
Check 'real LinkButton retains validation return and native postback' ($send.Contains('return ksValidateCheckoutTermsConsent();') -and $send.Contains('WebForm_DoPostBackWithOptions') -and $send.Contains('checkoutSubmit'))
$consentStart=$source.IndexOf('<div class="ks-checkout-consent"')
$consent=$source.Substring($consentStart,$source.IndexOf($sendMarkup)-$consentStart).Trim()
Check 'consent markup extracted' ($consent.Contains($labelMarkup))
$checkboxMarkup=[regex]::Match($consent,'<asp:CheckBox[^>]*/>').Value
$checkbox=New-Object System.Web.UI.WebControls.CheckBox
$checkbox.ID=Attr $checkboxMarkup 'ID';$checkbox.ClientIDMode=[System.Web.UI.ClientIDMode]::Static
$cbHtml=Render $checkbox
Check 'real CheckBox renders the static ID on the input, not a span' ($cbHtml -match '<input[^>]*id="chkTermsConsent"[^>]*type="checkbox"' -and $cbHtml -notmatch '<span|checked=|onchange=')
$fixtures=New-Object 'Collections.Generic.List[object]'
foreach($theme in @('Tech','Food')){foreach($labelVisible in @($true,$false)){
    $label=New-Object System.Web.UI.WebControls.Label
    $label.ID=Attr $labelMarkup 'ID';$label.ClientIDMode=[System.Web.UI.ClientIDMode]::Static
    $label.EnableViewState=$false;$label.CssClass=Attr $labelMarkup 'CssClass';$label.Visible=$labelVisible
    $labelHtml=Render $label
    Check ('native Label Visible='+$labelVisible+' '+$theme) (($labelVisible -and $labelHtml.Contains('<span id="lblTermsConsentError"')) -or (!$labelVisible -and $labelHtml.Length -eq 0))
    $html=$consent.Replace($checkboxMarkup,$cbHtml).Replace($labelMarkup,$labelHtml)
    $fixtures.Add([pscustomobject]@{Theme=$theme;LabelVisible=$labelVisible;Actions='<div class="ks-checkout-actions">'+$html+$send+'</div>'})
}}
SaveJson 'fixtures.json' $fixtures.ToArray()
# Server expressions only for the unrelated notes counter are materialized as a missing fixture control.
$scriptText=$scriptText.Replace('<%= txtNoteSpedizione.ClientID %>','fixtureNotesAbsent')
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'consent-inline.js'),$scriptText,$utf8)
SaveJson 'unit-report.json' @{Result='PASS';Count=$checks.Count;Checks=$checks.ToArray()}
$browser=@'
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const [root,dir]=process.argv.slice(2),req=createRequire(path.join(path.dirname(process.execPath),'../node_modules/entry.cjs'));
const {chromium}=req('playwright');
const fixtures=JSON.parse(await fs.readFile(path.join(dir,'fixtures.json'),'utf8'));
const script=await fs.readFile(path.join(dir,'consent-inline.js'),'utf8');
const checks=[],errors=[],missing=[],blocked=[];
function check(name,pass){checks.push({Name:name,Pass:!!pass});if(!pass)throw Error(name)}
const css=['fonts/font.css','icons/icomoon/style.css','css/bootstrap.min.css','css/keepstore.css','css/keepstore-overrides.css','css/ks-ui.css','css/styles.css','css/cart-ui.css','css/theme-overrides.css'];
const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
function documentHtml(f){return '<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+css.map(p=>'<link rel="stylesheet" href="/Public/assets/keepstore/'+p+'">').join('')+'</head><body><form id="form1" method="post" action="/fixture"><input type="hidden" name="__EVENTTARGET"><section id="tOrdine" class="ks-cart-page ks-cart-modern ks-checkout-shell ks-checkout-modern ks-cart-step-confirm"><div class="container"><h1>Conferma '+f.Theme+' (fixture)</h1><div class="ks-checkout-stage-main"><div class="ks-final-confirm-section"><div id="FinalCheckoutActionsInlineSlot" class="ks-final-actions-inline-slot">'+f.Actions+'</div><div id="spinner_caricamento" style="display:none">Invio sintetico</div></div><div id="FinalCheckoutActionsMobileSlot" class="ks-final-actions-mobile-slot" aria-hidden="true"></div></div></div></section><span id="fixtureHint">Indicazione sintetica</span><button type="button" id="fixtureAfter">Controllo successivo</button></form><script>'+script+'</script><script src="/Public/assets/keepstore/js/checkout-ui.js"></script></body></html>'}
try{
 for(const width of [360,390,430,1365])for(const f of fixtures){
  const context=await browser.newContext({viewport:{width,height:1000},isMobile:width<600,hasTouch:width<600,offline:true,serviceWorkers:'block'});
  const page=await context.newPage(),origin='https://consent-'+f.Theme.toLowerCase()+'.invalid';let posts=0;
  page.on('pageerror',e=>errors.push(String(e)));
  await page.addInitScript(()=>{
   window.fixtureLoads=[];window.Sys={WebForms:{PageRequestManager:{getInstance:()=>({add_endRequest:fn=>window.fixtureLoads.push(fn)})}}};
   window.fixturePostbacks=0;window.fixtureOptions=[];window.fixtureChangeBindings=0;
   const add=EventTarget.prototype.addEventListener;
   EventTarget.prototype.addEventListener=function(type,fn,options){if(this===document&&type==='change'&&String(fn).includes('chkTermsConsent'))window.fixtureChangeBindings++;return add.call(this,type,fn,options)};
   // Native LinkButton output is real; the WebForms dispatcher/transport is explicitly synthetic.
   window.WebForm_PostBackOptions=function(...args){this.args=args};
   window.WebForm_DoPostBackWithOptions=function(options){window.fixturePostbacks++;window.fixtureOptions.push(options.args);document.querySelector('[name="__EVENTTARGET"]').value=options.args[0];document.getElementById('form1').requestSubmit()};
  });
  await context.route('**/*',async route=>{
   const request=route.request(),u=new URL(request.url());
   if(u.origin!==origin){blocked.push(u.origin+u.pathname);return route.abort()}
   if(u.pathname==='/fixture'){
    if(request.method()==='POST'){posts++;check(f.Theme+' '+width+' native event target',new URLSearchParams(request.postData()).get('__EVENTTARGET')==='MainContent$btInviaOrdine')}
    else if(request.method()!=='GET'){blocked.push(request.method());return route.abort()}
    return route.fulfill({contentType:'text/html',body:documentHtml(f)});
   }
   if(request.method()!=='GET'){blocked.push(request.method()+u.pathname);return route.abort()}
   const file=path.resolve(root,'.'+decodeURIComponent(u.pathname));
   if(!file.toLowerCase().startsWith(path.resolve(root).toLowerCase()+path.sep)){blocked.push(u.pathname);return route.abort()}
   try{return route.fulfill({body:await fs.readFile(file),contentType:file.endsWith('.css')?'text/css':file.endsWith('.js')?'text/javascript':'application/octet-stream'})}catch{missing.push(u.pathname);return route.abort()}
  });
  try{
   await page.goto(origin+'/fixture',{waitUntil:'load'});await page.evaluate(()=>document.fonts.ready);
   const name=f.Theme+' '+width+' label='+f.LabelVisible,cb=page.locator('#chkTermsConsent'),send=page.locator('[id$="btInviaOrdine"]');
   const initial=await cb.evaluate(e=>({checked:e.checked,invalid:e.getAttribute('aria-invalid'),described:e.getAttribute('aria-describedby'),tag:e.tagName,labels:[...e.labels].map(l=>l.htmlFor)}));
   check(name+' native initial state and legal label',!initial.checked&&!initial.invalid&&!initial.described&&initial.tag==='INPUT'&&initial.labels.includes('chkTermsConsent'));
   check(name+' legal links preserved',await page.locator('.ks-checkout-consent a').evaluateAll(es=>es.map(e=>e.getAttribute('href')).join('|'))==='condizioni-vendita.aspx|condizioni-vendita.aspx#diritto-recesso|privacy.aspx');
   check(name+' real checkout UI moves actions at mobile breakpoint',await send.evaluate(e=>!!e.closest('#FinalCheckoutActionsMobileSlot'))===(width<768));
   await cb.evaluate(e=>e.setAttribute('aria-describedby','fixtureHint'));
   await send.click();
   let invalid=await cb.evaluate(e=>({invalid:e.getAttribute('aria-invalid'),described:e.getAttribute('aria-describedby'),focus:document.activeElement===e}));
   check(name+' missing consent focus and ARIA',invalid.invalid==='true'&&invalid.described==='fixtureHint ksTermsConsentFeedback'&&invalid.focus);
   check(name+' existing error text visible',await page.locator('#ksTermsConsentFeedback').innerText()==='Per proseguire devi accettare le Condizioni Generali di Vendita.');
   check(name+' no POST dispatcher or spinner on failed validation',posts===0&&await page.evaluate(()=>fixturePostbacks===0&&getComputedStyle(document.getElementById('spinner_caricamento')).display==='none'));
   check(name+' accessible error description',await cb.getAttribute('aria-describedby')==='fixtureHint ksTermsConsentFeedback');
   await send.click();check(name+' repeated failure no duplicated description',await cb.getAttribute('aria-describedby')==='fixtureHint ksTermsConsentFeedback'&&posts===0);
   await cb.check();
   check(name+' immediate correction clears only managed ARIA and message',await cb.evaluate(e=>!e.hasAttribute('aria-invalid')&&e.getAttribute('aria-describedby')==='fixtureHint'&&document.getElementById('ksTermsConsentFeedback').textContent===''));
   check(name+' selection does not post or show spinner',posts===0&&await page.evaluate(()=>fixturePostbacks===0&&getComputedStyle(document.getElementById('spinner_caricamento')).display==='none'));
   await cb.uncheck();check(name+' unchecking alone does not prematurely mark invalid',!await cb.getAttribute('aria-invalid')&&posts===0);
   // Moving the actual nodes across both breakpoints preserves the input, feedback and focus contract.
   await page.setViewportSize({width:width<768?1365:390,height:1000});
   await send.click();check(name+' validation follows moved footer',await cb.evaluate(e=>document.activeElement===e&&e.getAttribute('aria-invalid')==='true'));
   await cb.check();
   await page.setViewportSize({width,height:1000});
   // Re-run the actual inline initializer: the document change handler must remain singular.
   await page.evaluate(code=>{(0,eval)(code);(0,eval)(code)},script);
   check(name+' repeated initializer has one delegated change handler',await page.evaluate(()=>fixtureChangeBindings===1));
   // A new server-materialized control tree replaces the old one, as after an async refresh.
   await page.evaluate(actions=>{
    const inline=document.getElementById('FinalCheckoutActionsInlineSlot');
    document.querySelector('.ks-checkout-actions').remove();inline.innerHTML=actions;
    for(const load of fixtureLoads)load();
   },f.Actions);
   await send.click();await cb.check();
   check(name+' replacement and endRequest correction without rebind',await cb.evaluate(e=>!e.hasAttribute('aria-invalid')&&!e.hasAttribute('aria-describedby')&&document.getElementById('ksTermsConsentFeedback').textContent==='')&&await page.evaluate(()=>fixtureChangeBindings===1)&&posts===0);
   await cb.uncheck();await send.click();
   check(name+' keyboard focus on checkbox after replacement',await cb.evaluate(e=>document.activeElement===e));
   await page.keyboard.press('Space');
   check(name+' keyboard correction and normal accessible state',await cb.isChecked()&&!await cb.getAttribute('aria-invalid'));
   await page.keyboard.press('Tab');
   check(name+' legal links reachable after checkbox',await page.evaluate(()=>document.activeElement.getAttribute('href')==='condizioni-vendita.aspx'));
   const layout=await page.evaluate(()=>{
    const e=document.getElementById('chkTermsConsent'),r=e.getBoundingClientRect(),ids=[...document.querySelectorAll('[id]')].map(e=>e.id);
    return {fits:document.documentElement.scrollWidth<=innerWidth+1,unique:new Set(ids).size===ids.length,visible:r.width>0&&r.height>0};
   });
   check(name+' unique IDs, visible control, no horizontal overflow',layout.fits&&layout.unique&&layout.visible);
   if(f.LabelVisible&&(width===390||width===1365)){
    await cb.uncheck();await send.click();await page.screenshot({path:path.join(dir,f.Theme+'-'+width+'-error.png'),fullPage:true});await cb.check();
   }
   // Observe the real spinner function and the single native dispatcher before the synthetic navigation.
   await page.evaluate(()=>{window.fixtureSpinners=0;const original=visualizza_spinner_caricamento;window.visualizza_spinner_caricamento=function(){fixtureSpinners++;original()};window.fixtureSubmitSnapshot=null;document.getElementById('form1').addEventListener('submit',()=>{fixtureSubmitSnapshot={spinners:fixtureSpinners,calls:fixturePostbacks,hidden:getComputedStyle(document.querySelector('[id$="btInviaOrdine"]')).display==='none',group:fixtureOptions[0][3]};sessionStorage.setItem('consentSnapshot',JSON.stringify(fixtureSubmitSnapshot))})});
   await Promise.all([page.waitForNavigation({waitUntil:'load'}),send.click()]);
   await page.waitForFunction(()=>sessionStorage.getItem('consentSnapshot'));
   const snapshot=await page.evaluate(()=>JSON.parse(sessionStorage.getItem('consentSnapshot')));
   check(name+' valid consent exactly one POST, one spinner, same server validation group',posts===1&&snapshot.spinners===1&&snapshot.calls===1&&snapshot.hidden&&snapshot.group==='checkoutSubmit');
   await page.waitForLoadState('load');
   check(name+' full synthetic postback starts unchecked and unmarked',!await cb.isChecked()&&!await cb.getAttribute('aria-invalid')&&await page.evaluate(()=>fixtureChangeBindings===1));
  }finally{await context.close()}
 }
 check('no script errors, operational requests or missing assets',errors.length===0&&blocked.length===0&&missing.length===0);
 const report={Result:'PASS',Count:checks.length,Chrome:browser.version(),Configurations:16,Checks:checks,Errors:errors,Blocked:blocked,Missing:missing,Limits:'Real System.Web CheckBox/Label/LinkButton rendering, inline source and checkout-ui.js. Dispatch, server response, Sys endRequest and page layout are synthetic; no full WebForms lifecycle, real validation group execution, PRG/session, order/payment, IIS or database certification.'};
 await fs.writeFile(path.join(dir,'browser-report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({Result:report.Result,Count:report.Count,Chrome:report.Chrome}));
}catch(e){await fs.writeFile(path.join(dir,'browser-failure.json'),JSON.stringify({Error:String(e),Checks:checks,Errors:errors,Blocked:blocked,Missing:missing},null,2));throw e}finally{await browser.close()}
'@
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'browser-harness.mjs'),$browser,$utf8)
$node=(Get-Command node -ErrorAction Stop).Source
& $node (Join-Path $EvidenceDirectory 'browser-harness.mjs') $RepositoryRoot $EvidenceDirectory
if($LASTEXITCODE -ne 0){throw 'CONSENT_BROWSER_FAILED'}
$report=Get-Content -LiteralPath (Join-Path $EvidenceDirectory 'browser-report.json') -Raw|ConvertFrom-Json
SaveJson 'test-report.json' @{Result='PASS';SourceNativeChecks=$checks.Count;BrowserChecks=$report.Count;Configurations=16;Widths=@(360,390,430,1365);Limits='SOURCE ONLY; native control rendering plus synthetic browser/postback transport. No operational services.'}
Write-Output ('PASS consent: '+$checks.Count+' source/native + '+$report.Count+' Chrome checks; '+$EvidenceDirectory)
