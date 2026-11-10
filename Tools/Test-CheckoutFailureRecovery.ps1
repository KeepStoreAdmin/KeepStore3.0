[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [switch]$ListinoAuthorityOnly,
    [switch]$OrderRecoveryNavigationOnly,
    [switch]$CommercialProfileOnly,
    [switch]$AllowCommercialProfileDelta,
    [string]$EvidenceDirectory,
    [string]$BaselineRef = '161b8d517082dd4e458f8f9d7974332c8475bb53'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

if($OrderRecoveryNavigationOnly){
    if($ListinoAuthorityOnly -or $CommercialProfileOnly){throw 'ONE_FOCUSED_SUITE_AT_A_TIME'}
    if(!$EvidenceDirectory -or $BaselineRef -cnotmatch '^[0-9a-f]{40}$'){throw 'RECOVERY_NAVIGATION_BASE_AND_EVIDENCE_REQUIRED'}
    if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'RECOVERY_NAVIGATION_REQUIRES_FRAMEWORK_POWERSHELL'}
    $evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
    if(!$evidence.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'NEW_TEMP_EVIDENCE_DIRECTORY_REQUIRED'}
    [void][IO.Directory]::CreateDirectory($evidence)
    $utf8=New-Object Text.UTF8Encoding($false)
    Add-Type -AssemblyName System.Web,System.Web.Extensions
    $checks=New-Object 'Collections.Generic.List[object]'
    function RecoveryCheck([string]$name,[bool]$pass){$checks.Add([pscustomobject]@{name=$name;pass=$pass});if(!$pass){throw ('RECOVERY_NAVIGATION_FAILED '+$name)}}
    function RecoverySource([string]$file){[IO.File]::ReadAllText((Join-Path $RepositoryRoot $file))}
    function RecoveryBase([string]$file){$v=(& git -C $RepositoryRoot show ($BaselineRef+':'+$file)) -join [char]10;if($LASTEXITCODE){throw 'RECOVERY_NAVIGATION_BASE_UNAVAILABLE'};return $v}
    function RecoveryMethod([string]$s,[string]$name){$m=[regex]::Match($s,'(?ms)^    Private Sub '+$name+'\(\).*?^    End Sub');if(!$m.Success){throw ('RECOVERY_METHOD_MISSING '+$name)};return $m.Value}
    function RecoveryNormalize([string]$s){$s.Replace(([string][char]13+[char]10),[string][char]10).TrimEnd([char[]]@(13,10))}
    $order=RecoveryNormalize (RecoverySource 'ordine.aspx.vb');$baseline=RecoveryNormalize (RecoveryBase 'ordine.aspx.vb')
    $names=@('ShowCompletedOrderReceiptUnavailable','ShowIndeterminateOrderOutcome')
    $baseMethods=@();$candidateMethods=@();$withoutBase=$baseline;$withoutCandidate=$order
    $addition=@'
        Me.Panel2.Controls.Add(New LiteralControl(
            "<div class=""ks-order-actions""><a class=""tf-btn ks-order-btn-secondary"" href=""" &
            HttpUtility.HtmlAttributeEncode(ResolveUrl("~/documenti.aspx?t=4")) &
            """>I miei ordini</a></div>"))
'@
    $addition=RecoveryNormalize $addition
    foreach($name in $names){
        $old=RecoveryMethod $baseline $name;$new=RecoveryMethod $order $name
        RecoveryCheck ($name+' only native navigation addition') ($new.Replace($addition+[char]10,'') -ceq $old)
        $baseMethods+=$old;$candidateMethods+=$new
        $withoutBase=$withoutBase.Replace($old,'');$withoutCandidate=$withoutCandidate.Replace($new,'')
    }
    RecoveryCheck 'all source outside two methods identical' ($withoutBase -ceq $withoutCandidate)
    foreach($file in @('ordine.aspx','documenti.aspx','documenti.aspx.vb')){
        RecoveryCheck ($file+' unchanged') ((RecoveryNormalize (RecoverySource $file)) -ceq (RecoveryNormalize (RecoveryBase $file)))
    }
    $history=RecoverySource 'documenti.aspx.vb';$historyMarkup=RecoverySource 'documenti.aspx'
    RecoveryCheck 'anonymous history guard redirects before document loading' ($history -match '(?s)If Session\("LoginId"\) Is Nothing.*?Response.Redirect\("accessonegato.aspx", True\).*?Exit Sub')
    RecoveryCheck 'history complete owner/company identity guard' ($history -match '(?s)If CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity.IsComplete Then\s+Response.Redirect\("accessonegato.aspx", True\)')
    RecoveryCheck 'history markup owner AND company predicates' ($historyMarkup -match '\(\x60vdocumenti\x60\.\x60UtentiId\x60 = \?UtentiId\) AND \(\x60vdocumenti\x60\.\x60AziendeId\x60 = \?AziendaId\)')
    RecoveryCheck 'history dynamic SQL owner AND company predicates' ($history -match '\x60vdocumenti\x60\.\x60UtentiId\x60=' -and $history -match 'AND \(\x60vdocumenti\x60\.\x60AziendeId\x60=' -and $history.Contains('CurrentOrderIdentity.UtentiId') -and $history.Contains('CurrentOrderIdentity.CompanyId'))
    $markup=RecoverySource 'ordine.aspx'
    $panel=[regex]::Match($markup,'<asp:Panel\b[^>]*ID="Panel2"[^>]*>').Value
    RecoveryCheck 'real Panel2 alert live role and focus attributes preserved' ($panel.Contains('role="alert"') -and $panel.Contains('aria-live="assertive"') -and $panel.Contains('tabindex="-1"'))
    $harness=@"
Imports System
Imports System.IO
Imports System.Collections.Generic
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.Hosting
Imports System.Web.Script.Serialization
Public Class NavigationWorker
    Inherits SimpleWorkerRequest
    Private ReadOnly TenantHost As String
    Public Sub New(ByVal tenant As String)
        MyBase.New("ordine.aspx", "", New StringWriter())
        TenantHost = tenant & ".fixture.invalid"
    End Sub
    Public Overrides Function GetServerName() As String
        Return TenantHost
    End Function
End Class
Public MustInherit Class RecoveryPage
    Inherits Page
    Public Panel1 As New Panel()
    Public Panel2 As New Panel()
    Public Sub New()
        AppRelativeVirtualPath = "~/ordine.aspx"
        Panel1.ID = "Panel1"
        Panel1.Controls.Add(New LiteralControl("HIDDEN_RECEIPT_SENTINEL"))
        Panel2.ID = "Panel2"
        Panel2.ClientIDMode = ClientIDMode.Static
        Panel2.Visible = False
        Panel2.Attributes("role") = "alert"
        Panel2.Attributes("aria-live") = "assertive"
        Panel2.Attributes("tabindex") = "-1"
        Panel2.Controls.Add(New LiteralControl("STALE_NOTICE_SENTINEL"))
        Controls.Add(Panel1)
        Controls.Add(Panel2)
    End Sub
    Public MustOverride Sub ShowOutcome(ByVal method As String)
End Class
Public Class BaselineRecoveryPage
    Inherits RecoveryPage
$($baseMethods -join [Environment]::NewLine)
    Public Overrides Sub ShowOutcome(ByVal method As String)
        If method = "ShowCompletedOrderReceiptUnavailable" Then
            ShowCompletedOrderReceiptUnavailable()
        Else
            ShowIndeterminateOrderOutcome()
        End If
    End Sub
End Class
Public Class CandidateRecoveryPage
    Inherits RecoveryPage
$($candidateMethods -join [Environment]::NewLine)
    Public Overrides Sub ShowOutcome(ByVal method As String)
        If method = "ShowCompletedOrderReceiptUnavailable" Then
            ShowCompletedOrderReceiptUnavailable()
        Else
            ShowIndeterminateOrderOutcome()
        End If
    End Sub
End Class
Public Class RecoveryNavigationHost
    Inherits MarshalByRefObject
    Public Function RenderAll() As String
        Dim fixtures As New List(Of Object)()
        For Each tenant As String In New String() {"taikun", "webaffare"}
            For Each method As String In New String() {"ShowCompletedOrderReceiptUnavailable", "ShowIndeterminateOrderOutcome"}
                For Each version As String In New String() {"baseline", "candidate"}
                    HttpContext.Current = New HttpContext(New NavigationWorker(tenant))
                    Dim page As RecoveryPage = If(version = "baseline", CType(New BaselineRecoveryPage(), RecoveryPage), New CandidateRecoveryPage())
                    page.ShowOutcome(method)
                    Dim output As New StringWriter()
                    Dim writer As New HtmlTextWriter(output)
                    page.Panel1.RenderControl(writer)
                    page.Panel2.RenderControl(writer)
                    fixtures.Add(New With {.Tenant=tenant, .Method=method, .Version=version, .AppPath=HostingEnvironment.ApplicationVirtualPath, .ExpectedUrl=page.ResolveUrl("~/documenti.aspx?t=4"), .Panel1Visible=page.Panel1.Visible, .Panel2Visible=page.Panel2.Visible, .Html=output.ToString()})
                    page.Dispose()
                    HttpContext.Current = Nothing
                Next
            Next
        Next
        Return New JavaScriptSerializer().Serialize(fixtures)
    End Function
    Public Overrides Function InitializeLifetimeService() As Object
        Return Nothing
    End Function
End Class
"@
    $vb=Join-Path $evidence 'RecoveryNavigationHarness.vb';$dll=Join-Path $evidence 'RecoveryNavigationHarness.dll'
    [IO.File]::WriteAllText($vb,$harness,$utf8)
    $framework=Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319'
    & (Join-Path $framework 'vbc.exe') /nologo /target:library /optionstrict+ /optionexplicit+ /out:$dll /reference:System.dll,System.Core.dll,System.Web.dll,System.Web.Extensions.dll $vb
    if($LASTEXITCODE){throw 'RECOVERY_NAVIGATION_COMPILE_FAILED'}
    Add-Type -Path $dll
    $fixtures=@()
    foreach($app in @('/', '/qa-shop')){
        $appRoot=Join-Path $evidence $(if($app -eq '/'){'root-app'}else{'virtual-app'})
        [void][IO.Directory]::CreateDirectory((Join-Path $appRoot 'bin'))
        [void][IO.Directory]::CreateDirectory((Join-Path $appRoot 'cache'))
        Copy-Item -LiteralPath $dll -Destination (Join-Path $appRoot 'bin\RecoveryNavigationHarness.dll')
        $cache=[System.Security.SecurityElement]::Escape((Join-Path $appRoot 'cache'))
        [IO.File]::WriteAllText((Join-Path $appRoot 'web.config'),('<configuration><connectionStrings><clear/></connectionStrings><system.web><compilation targetFramework="4.8" tempDirectory="'+$cache+'"/><httpRuntime targetFramework="4.8"/></system.web></configuration>'),$utf8)
        $hostGate=[System.Web.Hosting.ApplicationHost]::CreateApplicationHost([RecoveryNavigationHost],$app,($appRoot+'\'))
        $rendered=$hostGate.RenderAll()|ConvertFrom-Json
        $fixtures+=$rendered
    }
    foreach($f in $fixtures){
        $label=$f.Tenant+' '+$f.AppPath+' '+$f.Method+' '+$f.Version
        RecoveryCheck ($label+' Panel1 hidden and Panel2 visible') (!$f.Panel1Visible -and $f.Panel2Visible)
        RecoveryCheck ($label+' only Panel2 rendered without stale receipt') (!$f.Html.Contains('HIDDEN_RECEIPT_SENTINEL') -and !$f.Html.Contains('STALE_NOTICE_SENTINEL') -and $f.Html.Contains('id="Panel2"'))
        if($f.Version -eq 'candidate'){
            $expected=$f.AppPath.TrimEnd('/')+'/documenti.aspx?t=4'
            RecoveryCheck ($label+' application-relative canonical URL') ($f.ExpectedUrl -ceq $expected -and $f.Html.Contains('href="'+$expected+'"'))
            RecoveryCheck ($label+' one native same-context action') (([regex]::Matches($f.Html,'<a\b')).Count -eq 1 -and $f.Html -match '<div class="ks-order-actions"><a class="tf-btn ks-order-btn-secondary" href="[^"]+">I miei ordini</a></div>' -and $f.Html -notmatch 'onclick|__doPostBack|javascript:|target=|formaction=|documentId=')
            $old=@($fixtures|Where-Object {$_.Tenant -eq $f.Tenant -and $_.AppPath -eq $f.AppPath -and $_.Method -eq $f.Method -and $_.Version -eq 'baseline'})[0]
            RecoveryCheck ($label+' all previous rendered content preserved') (([regex]::Replace($f.Html,'<div class="ks-order-actions">.*?</div>','')) -ceq $old.Html)
        }else{
            RecoveryCheck ($label+' baseline has no accessible recovery link') ($f.Html -notmatch '<a\b')
        }
    }
    [IO.File]::WriteAllText((Join-Path $evidence 'fixtures.json'),($fixtures|ConvertTo-Json -Depth 6),$utf8)
    [IO.File]::WriteAllText((Join-Path $evidence 'source-server-checks.json'),($checks|ConvertTo-Json -Depth 5),$utf8)
    $browser=@'
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const [root,dir]=process.argv.slice(2);
const req=createRequire(path.join(path.dirname(process.execPath),'../node_modules/entry.cjs'));
const {chromium}=req('playwright');
const all=JSON.parse(await fs.readFile(path.join(dir,'fixtures.json'),'utf8'));
const cases=all.filter(f=>f.Version==='candidate'&&((f.Tenant==='taikun'&&f.AppPath==='/')||(f.Tenant==='webaffare'&&f.AppPath==='/qa-shop')));
const style=(await fs.readFile(path.join(root,'ordine.aspx'),'utf8')).match(/<style\b[^>]*>([\s\S]*?)<\/style>/i)[1];
const css=['fonts/font.css','icons/icomoon/style.css','css/bootstrap.min.css','css/keepstore.css','css/keepstore-overrides.css','css/ks-ui.css','css/styles.css','css/cart-ui.css','css/theme-overrides.css'];
const checks=[],metrics=[],requests=[],blocked=[];
function check(name,pass){checks.push({name,pass:!!pass});if(!pass)throw Error(name)}
const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
try{
 for(const width of [360,390,430,1365])for(const f of cases){
  const context=await browser.newContext({viewport:{width,height:844},javaScriptEnabled:false,offline:true,serviceWorkers:'block'});
  const page=await context.newPage(),origin='https://'+f.Tenant+'.fixture.invalid',nav=[];
  const html='<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+css.map(p=>'<link rel="stylesheet" href="/Public/assets/keepstore/'+p+'">').join('')+'<style>'+style+'</style></head><body><section class="tf-sp-2 ks-order-receipt-page"><div class="container"><div class="ks-order-receipt-shell">'+f.Html+'</div></div></section></body></html>';
  await context.route('**/*',async route=>{
   const r=route.request(),u=new URL(r.url());
   if(u.origin!==origin||r.method()!=='GET'){blocked.push(u.pathname);return route.abort()}
   if(u.pathname==='/fixture')return route.fulfill({contentType:'text/html',body:html});
   if(u.pathname===f.ExpectedUrl.split('?')[0]){
    nav.push({method:r.method(),url:u.pathname+u.search});requests.push({tenant:f.Tenant,width,...nav.at(-1)});
    return route.fulfill({contentType:'text/html',body:'<!doctype html><title>Destinazione fixture, storico reale NON esercitato</title>'});
   }
   const file=path.resolve(root,'.'+u.pathname),allow=path.resolve(root,'Public/assets/keepstore')+path.sep;
   if(!file.toLowerCase().startsWith(allow.toLowerCase())){blocked.push(u.pathname);return route.abort()}
   try{return route.fulfill({body:await fs.readFile(file),contentType:u.pathname.endsWith('.css')?'text/css':'application/octet-stream'})}catch{blocked.push(u.pathname);return route.abort()}
  });
  try{
   const name=f.Tenant+' '+width+' '+f.Method;
   await page.goto(origin+'/fixture',{waitUntil:'load'});await page.evaluate(()=>document.fonts.ready);
   check(name+' Panel1 absent',await page.locator('#Panel1').count()===0);
   const link=page.locator('#Panel2 .ks-order-actions a');
   check(name+' native link visible',await link.isVisible());
   check(name+' exact URL',await link.getAttribute('href')===f.ExpectedUrl);
   const box=await link.boundingBox();
   check(name+' touch at least44x44',!!box&&box.width>=44&&box.height>=44);
   check(name+' no horizontal overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
   await page.mouse.move(0,0);await page.waitForTimeout(220);
   const normal=await link.evaluate(e=>{const s=getComputedStyle(e);return {bg:s.backgroundColor,border:s.borderColor,outline:s.outlineStyle}});
   await page.locator('#Panel2').focus();await page.keyboard.press('Tab');
   check(name+' keyboard reaches native anchor',await link.evaluate(e=>e===document.activeElement));
   await page.waitForTimeout(220);
   const focused=await link.evaluate(e=>{const s=getComputedStyle(e);return {bg:s.backgroundColor,border:s.borderColor,outline:s.outlineStyle}});
   check(name+' visible focus feedback',focused.bg!==normal.bg||focused.border!==normal.border||!['none','hidden'].includes(focused.outline));
   metrics.push({name,width,target:box,normal,focused});
   if(f.Method==='ShowIndeterminateOrderOutcome')check(name+' warning preserved',(await page.locator('#Panel2').innerText()).includes("Non ripetere l'invio"));
   if((f.Tenant==='taikun'&&f.Method==='ShowCompletedOrderReceiptUnavailable')||(f.Tenant==='webaffare'&&f.Method==='ShowIndeterminateOrderOutcome'))await page.screenshot({path:path.join(dir,f.Tenant+'-'+width+'.png'),fullPage:true});
   await Promise.all([page.waitForURL(origin+f.ExpectedUrl),page.keyboard.press('Enter')]);
   check(name+' Enter produces one GET',nav.length===1&&nav[0].method==='GET'&&nav[0].url===f.ExpectedUrl);
   await page.goto(origin+'/fixture',{waitUntil:'load'});await link.click();
   await page.waitForURL(origin+f.ExpectedUrl);
   check(name+' click produces one GET',nav.length===2&&nav.every(r=>r.method==='GET'&&r.url===f.ExpectedUrl));
  }finally{await context.close()}
 }
 check('all unexpected/outbound/POST requests blocked and absent',blocked.length===0);
 await fs.writeFile(path.join(dir,'browser.json'),JSON.stringify({result:'PASS CHROME FIXTURE ONLY',checks,metrics,requests,blocked,limits:['IIS/DB/authentication/real tenants not exercised','Destination GET intercepted and fulfilled as fixture; no real history loaded','Actual extracted VB methods rendered through isolated System.Web; full Master Page not exercised']},null,2));
 console.log('RECOVERY_NAVIGATION_BROWSER_PASS checks='+checks.length+' cases='+metrics.length+' nativeGET='+requests.length);
}finally{await browser.close()}
'@
    $js=Join-Path $evidence 'browser.mjs';[IO.File]::WriteAllText($js,$browser,$utf8)
    & node $js $RepositoryRoot $evidence
    if($LASTEXITCODE){throw 'RECOVERY_NAVIGATION_BROWSER_FAILED'}
    Write-Output ('RECOVERY_NAVIGATION_SOURCE_SERVER_PASS checks='+$checks.Count+' fixtures='+$fixtures.Count+' evidence='+$evidence)
    return
}


if($CommercialProfileOnly){
    if($ListinoAuthorityOnly){throw 'ONE_FOCUSED_SUITE_AT_A_TIME'}
    if(!$EvidenceDirectory -or $BaselineRef -cnotmatch '^[0-9a-f]{40}$'){throw 'G6_EXPLICIT_BASE_AND_EVIDENCE_REQUIRED'}
    $evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
    if(!$evidence.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'NEW_TEMP_EVIDENCE_DIRECTORY_REQUIRED'}
    [void][IO.Directory]::CreateDirectory($evidence)
    $utf8=New-Object Text.UTF8Encoding($false)
    function G6Source([string]$file){[IO.File]::ReadAllText((Join-Path $RepositoryRoot $file))}
    function G6Original([string]$file){$s=(& git -C $RepositoryRoot show ($BaselineRef+':'+$file)) -join "`n";if($LASTEXITCODE){throw 'G6_BASELINE_UNAVAILABLE'};return $s}
    function G6Method([string]$source,[string]$name){$m=[regex]::Match($source,'(?ms)^\s*(?:Public|Private|Protected) (?:Shared )?(?:Function|Sub) '+$name+'\b.*?^\s*End (?:Function|Sub)');if(!$m.Success){throw ('G6_METHOD_MISSING '+$name)};return $m.Value}
    function G6Check([string]$name,[bool]$value){if(!$value){throw ('G6_SOURCE_FAILED '+$name)};Write-Output ('PASS SOURCE '+$name)}
    $master=G6Source 'Page.master.vb';$order=G6Source 'ordine.aspx.vb';$cart=G6Source 'carrello.aspx.vb';$durable=G6Source 'App_Code/OrderDurableIdempotencyService.vb';$dispatcher=G6Source 'App_Code/CheckoutTerminalOutcomeDispatcher.vb'
    $capture=G6Method $cart 'TryCaptureAuthoritativeCheckoutDraft'
    $captureGuard=[regex]::Match($capture,'(?ms)^        Dim commercialProfileFingerprint As String.*?^        End If').Value
    $orderGuard=[regex]::Match($order,'(?ms)^                Dim currentCommercialProfile As String.*?^                End If').Value
    G6Check 'guard exists before fiscal restore and transaction' ($orderGuard.Length -gt 0 -and $order.IndexOf($orderGuard) -gt $order.IndexOf('If Not CheckoutDraftService.ValidateAuthoritativeSelections(') -and $order.IndexOf($orderGuard) -lt $order.IndexOf('Session("AbilitatoIvaReverseCharge") = checkoutDraft.ReverseChargeVat') -and $order.IndexOf($orderGuard) -lt $order.IndexOf('trns = conn.BeginTransaction('))
    G6Check 'capture validates profile before seal and binds same field' ($captureGuard.Length -gt 0 -and $capture.IndexOf($captureGuard) -lt $capture.IndexOf('CheckoutDraftService.Seal(') -and $capture.Contains('.CommercialProfileFingerprint = commercialProfileFingerprint'))
    $identitySource=G6Source 'App_Code/OrderStorefrontContext.vb'
    $identityClass=[regex]::Match($identitySource,'(?ms)^Public NotInheritable Class OrderStorefrontIdentity.*?^End Class').Value
    $factory=G6Method (G6Source 'Tools/CheckoutDraftTelemetryHarness.vb') 'ValidDraft'
    $durableMethods=@('CreateRequestId','ComputePayloadFingerprint','NormalizeFingerprintValue','TryNormalizeRequestId','TryNormalizePayloadFingerprint','IsFingerprintValid')|ForEach-Object {G6Method $durable $_}
    $masterMethods=@('EnsureAuthenticatedStorefrontScope','ApplyAuthenticatedPriceDisplayState','CurrentAuthenticatedScopeKey','CurrentLoginIdSafe','RequirePriceDisplayTenant','TenantCarrierVatDefault','RestoreAnonymousPriceDisplayState','ClearStorefrontAuthenticationState','RejectStorefrontAuthentication')|ForEach-Object {G6Method $master $_}
    $masterCode=($masterMethods -join "`n").Replace('MySqlConnection','ProfileAuthConnection').Replace('MySqlCommand','ProfileAuthCommand').Replace('MySqlDataReader','ProfileAuthReader')
    $oldMaster=G6Original 'Page.master.vb'
    G6Check 'only authenticated hydration changes in master' (($master.Replace((G6Method $master 'EnsureAuthenticatedStorefrontScope'),'') -replace '\r\n',"`n").Trim() -ceq ($oldMaster.Replace((G6Method $oldMaster 'EnsureAuthenticatedStorefrontScope'),'') -replace '\r\n',"`n").Trim())
    $baselineMaster=(G6Method $oldMaster 'EnsureAuthenticatedStorefrontScope').Replace('EnsureAuthenticatedStorefrontScope','EnsureBaselineAuthenticatedScope').Replace('MySqlConnection','ProfileAuthConnection').Replace('MySqlCommand','ProfileAuthCommand').Replace('MySqlDataReader','ProfileAuthReader')
    foreach($methodName in @('ApplyAuthenticatedPriceDisplayState','CurrentAuthenticatedScopeKey','CurrentLoginIdSafe','RequirePriceDisplayTenant','TenantCarrierVatDefault','RestoreAnonymousPriceDisplayState','ClearStorefrontAuthenticationState','RejectStorefrontAuthentication')){
        G6Check ('unchanged master authority '+$methodName) (((G6Method $master $methodName) -replace '\r\n',"`n") -ceq ((G6Method $oldMaster $methodName) -replace '\r\n',"`n"))
    }
    foreach($file in @('App_Code/StorefrontPriceDisplayContextProvider.vb','App_Code/OrderStorefrontContext.vb','App_Code/CartPriceRevalidationHelper.vb','App_Code/OrderDurableIdempotencyService.vb','App_Code/CheckoutFailureRecoveryService.vb','App_Code/CheckoutTerminalOutcomeDispatcher.vb')){
        G6Check ('unchanged authority '+$file) (((G6Source $file) -replace '\r\n',"`n").Trim() -ceq ((G6Original $file) -replace '\r\n',"`n").Trim())
    }
    $template=@'
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text
Imports System.Security.Cryptography
Imports System.Web
Imports System.Web.SessionState
Imports System.Web.UI
Imports System.Configuration
Imports MySql.Data.MySqlClient
IDENTITY_CLASS
Public Class CheckoutAddressSnapshot
End Class
Public Module CheckoutAddressService
 Public Function TryResolve(c As MySqlConnection,t As MySqlTransaction,i As OrderStorefrontIdentity,a As Integer,ByRef r As CheckoutAddressSnapshot) As Boolean
  Throw New InvalidOperationException("UNEXPECTED_ADDRESS_IO")
 End Function
End Module
Public Class OrderDurableIdempotencyService
DURABLE_METHODS
End Class
Public Module ProfileIo
 Public Row As Dictionary(Of String,Object), Bag As SessionStateItemCollection, Queries As Integer, CarrierReads As Integer, Writes As Integer, FiscalRestores As Integer
 Public Sub NewRequest(company As Integer)
  Dim context As New HttpContext(New HttpRequest("","https://profile-fixture.invalid/ordine.aspx",""),New HttpResponse(New System.IO.StringWriter))
  SessionStateUtility.AddHttpSessionStateToContext(context,New HttpSessionStateContainer("synthetic",Bag,New HttpStaticObjectsCollection,20,False,HttpCookieMode.UseCookies,SessionStateMode.InProc,False))
  HttpContext.Current=context:Queries=0:CarrierReads=0:Writes=0:FiscalRestores=0
  StorefrontPriceDisplayContextProvider.SetTenantDefaults(context,company,If(company=1,1,10),2)
 End Sub
 Public Sub Configure(company As Integer,Optional legacy As Boolean=False)
  Bag=New SessionStateItemCollection:NewRequest(company)
  Row=New Dictionary(Of String,Object) From {{"id",42},{"AziendeID",company},{"listino",If(company=1,4,13)},{"utentiid",101},{"utentitipoid",3},{"IvaTipo",2},{"IdEsenzioneIva",7},{"ValoreEsenzioneIva",10D},{"DescrizioneEsenzioneIva","sintetica"},{"AbilitatoIvaReverseCharge",0}}
  Dim s=HttpContext.Current.Session:s("AziendaID")=company:s("LoginId")=42:s("UtentiId")=If(legacy,0,101):s("AuthenticatedAziendaID")=If(legacy,0,company):s("Listino")=99:s("IvaTipo")=1:s("IdEsenzioneIva")=2:s("Iva_Utente")=5D:s("AbilitatoIvaReverseCharge")=1
 End Sub
 Public Function Identity(company As Integer) As OrderStorefrontIdentity
  Return New OrderStorefrontIdentity With {.DatabaseScopeKey="source-profile-fixture",.CompanyId=company,.LoginId=42,.UtentiId=101,.PriceListId=CInt(HttpContext.Current.Session("Listino"))}
 End Function
End Module
Public Class ProfileAuthConnection
 Implements IDisposable
 Public Sub New(value As String)
 End Sub
 Public Sub Open()
 End Sub
 Public Sub Dispose() Implements IDisposable.Dispose
 End Sub
End Class
Public Class ProfileParameters
 Public Values As New Dictionary(Of String,Object)
 Public Sub AddWithValue(key As String,value As Object)
  Values(key)=value
 End Sub
End Class
Public Class ProfileAuthCommand
 Implements IDisposable
 Public Parameters As New ProfileParameters
 Public Sub New(sql As String,c As ProfileAuthConnection)
  If Not sql.Contains("FROM vlogin") OrElse Not sql.Contains("Abilitato=1 AND UtentiAbilitato=1") Then Throw New InvalidOperationException("UNEXPECTED_AUTH_QUERY")
 End Sub
 Public Function ExecuteReader() As ProfileAuthReader
  ProfileIo.Queries+=1:Return New ProfileAuthReader With {.Parameters=Parameters}
 End Function
 Public Sub Dispose() Implements IDisposable.Dispose
 End Sub
End Class
Public Class ProfileAuthReader
 Implements IDisposable
 Public Parameters As ProfileParameters
 Private consumed As Boolean
 Public Function Read() As Boolean
  If consumed Then Return False
  consumed=True:Return CInt(ProfileIo.Row("id"))=CInt(Parameters.Values("@loginId")) AndAlso CInt(ProfileIo.Row("AziendeID"))=CInt(Parameters.Values("@companyId"))
 End Function
 Default Public ReadOnly Property Item(key As String) As Object
  Get
   Return ProfileIo.Row(key)
  End Get
 End Property
 Public Sub Dispose() Implements IDisposable.Dispose
 End Sub
End Class
Public Module LoginAccessAuditRecorder
 Public Sub ClearAuthenticationMarker(context As HttpContext)
 End Sub
End Module
Public Module KeepStoreLog
 Public Sub [Error](scope As String,message As String,failure As Exception,context As HttpContext)
 End Sub
End Module
Public Module StorefrontSeoTenantContext
 Public Function ConfiguredDatabaseScopeKey() As String
  Return "source-profile-fixture"
 End Function
End Module
Public Module CheckoutDurableTelemetry
 Public Sub Write(context As HttpContext,request As String,phase As String,outcome As String,failure As Exception,idempotency As String,transaction As String,checkpoint As String)
 End Sub
End Module
Public Enum CheckoutTerminalOutcome
ENUM_VALUES
End Enum
Public Class CheckoutTerminalOutcomeDispatcher
 Public Shared Function Dispatch(context As HttpContext,outcome As CheckoutTerminalOutcome,Optional token As String="") As Boolean
  If context.Items("KeepStore:CheckoutTerminalOutcome") IsNot Nothing Then Return False
  context.Items("KeepStore:CheckoutTerminalOutcome")=outcome.ToString():context.Response.StatusCode=303:context.Response.RedirectLocation=ResolveTarget(outcome,token):Return True
 End Function
DISPATCH_TARGET
End Class
Public Class MasterProfileFixture
 Private Const AuthenticatedScopeRequestKey As String="KeepStore.Authentication.ValidatedScope"
 Private _priceDisplayCompanyId As Integer,_priceDisplayDefaultListId As Integer,_storefrontAuthenticationRevoked As Boolean
 Private _priceDisplayTenantMode As StorefrontVatDisplayMode=StorefrontVatDisplayMode.VatIncluded
 Private _priceDisplayCarrierVat As Nullable(Of Decimal)
 Public ReadOnly Property Session As HttpSessionState
  Get
   Return HttpContext.Current.Session
  End Get
 End Property
 Public Sub New(company As Integer)
  _priceDisplayCompanyId=company:_priceDisplayDefaultListId=If(company=1,1,10)
 End Sub
 Private Function IvaVettoreDefault(company As Integer) As Decimal
  ProfileIo.CarrierReads+=1:Return 22D
 End Function
 Public Sub Validate()
  EnsureAuthenticatedStorefrontScope(_priceDisplayCompanyId,_priceDisplayDefaultListId)
 End Sub
 Public Sub ValidateBaseline()
  EnsureBaselineAuthenticatedScope(_priceDisplayCompanyId,_priceDisplayDefaultListId)
 End Sub
MASTER_METHODS
BASELINE_MASTER_METHOD
End Class
Public Class CartProfileFixture
 Private Const CHECKOUT_REQUEST_VIEWSTATE_KEY As String="CheckoutRequestId"
 Public ViewState As New StateBag, Captured As String
ENSURE_REQUEST
 Public Function NextRequest(oldRequest As String) As String
  ViewState(CHECKOUT_REQUEST_VIEWSTATE_KEY)=oldRequest:EnsureCheckoutRequestId():Return Convert.ToString(ViewState(CHECKOUT_REQUEST_VIEWSTATE_KEY))
 End Function
 Public Function Capture(identity As OrderStorefrontIdentity) As Boolean
  Dim failureReason As CheckoutFailureReason=CheckoutFailureReason.CartInvalid
CAPTURE_GUARD
  Captured=commercialProfileFingerprint:Return True
 End Function
End Class
Public Class OrderProfileFixture
 Public Sub Execute(checkoutDraft As CheckoutDraftState,orderIdentity As OrderStorefrontIdentity,checkoutRequestId As String)
ORDER_GUARD
  HttpContext.Current.Session("AbilitatoIvaReverseCharge")=checkoutDraft.ReverseChargeVat
  HttpContext.Current.Session("Iva_Vettori")=checkoutDraft.CarrierVat
  ProfileIo.FiscalRestores+=1:ProfileIo.Writes+=1
 End Sub
 Private Sub ShowDurableCheckoutTechnicalFailure()
  HttpContext.Current.Items("source-failure-rendered")=True
 End Sub
ORDER_DISPATCH
End Class
Public Module CommercialProfileCases
 Private passed As Integer
 Private Sub ValidateMaster(company As Integer)
  Dim master As New MasterProfileFixture(company):master.Validate()
 End Sub
 Private Sub ExecuteOrder(draft As CheckoutDraftState,owner As OrderStorefrontIdentity,request As String)
  Dim page As New OrderProfileFixture:page.Execute(draft,owner,request)
 End Sub
 Private Sub Check(name As String,ok As Boolean)
  If Not ok Then Throw New InvalidOperationException("G6_FAILED "+name)
  passed+=1:Console.WriteLine("PASS "+name)
 End Sub
 Private Function Hash64(value As String) As String
  Return OrderDurableIdempotencyService.ComputePayloadFingerprint(value)
 End Function
VALID_DRAFT_FACTORY
 Private Function NewDraft(owner As OrderStorefrontIdentity,request As String) As CheckoutDraftState
  Dim draft=ValidDraft(owner,request,72)
  Dim cart As New CartProfileFixture
  If Not cart.Capture(owner) Then Return Nothing
  draft.CommercialProfileFingerprint=cart.Captured:Return CheckoutDraftService.Seal(draft)
 End Function
 Private Sub Initial(company As Integer,ByRef draft As CheckoutDraftState,ByRef owner As OrderStorefrontIdentity)
  ProfileIo.Configure(company):Dim master As New MasterProfileFixture(company):master.Validate():owner=ProfileIo.Identity(company)
  draft=NewDraft(owner,Guid.NewGuid().ToString("N")):CheckoutDraftService.Store(HttpContext.Current,draft)
 End Sub
 Public Sub Main()
  For Each company As Integer In New Integer(){1,2}
   ProfileIo.Configure(company):Dim baseline As New MasterProfileFixture(company):baseline.ValidateBaseline()
   Check("baseline stale normal profile reproduced "+company.ToString(),CInt(HttpContext.Current.Session("Listino"))=99 AndAlso CInt(HttpContext.Current.Session("Iva_Utente"))=5 AndAlso CInt(HttpContext.Current.Session("AbilitatoIvaReverseCharge"))=1 AndAlso ProfileIo.Queries=1)
   For Each legacy As Boolean In New Boolean(){False,True}
    ProfileIo.Configure(company,legacy):Dim master As New MasterProfileFixture(company):master.Validate()
    Dim s=HttpContext.Current.Session
    Check("T3 verified list and both aliases "+company.ToString()+legacy.ToString(),CInt(s("Listino"))=If(company=1,4,13) AndAlso CInt(s("listino"))=CInt(s("Listino")))
    Check("T3 normalized fiscal state",CInt(s("IvaTipo"))=2 AndAlso CInt(s("IdEsenzioneIva"))=7 AndAlso CDec(s("Iva_Utente"))=10D AndAlso CInt(s("AbilitatoIvaReverseCharge"))=0)
    Check("T3 owner unchanged or legacy hydrated",CInt(s("LoginId"))=42 AndAlso CInt(s("UtentiId"))=101 AndAlso CInt(s("AuthenticatedAziendaID"))=company)
    Check("T3 one existing query",ProfileIo.Queries=1):master.Validate():Check("T3 same request reuses validated result",ProfileIo.Queries=1)
   Next
   ProfileIo.Configure(company):ProfileIo.Row("IdEsenzioneIva")=-1:Dim noExemption As New MasterProfileFixture(company):noExemption.Validate()
   Check("T3 existing carrier default read without override",CDec(HttpContext.Current.Session("Iva_Utente"))=-1D AndAlso CDec(HttpContext.Current.Session("Iva_Vettori"))=22D AndAlso ProfileIo.Queries=1 AndAlso ProfileIo.CarrierReads=1)
   noExemption.Validate():Check("T3 same request caches carrier default",ProfileIo.Queries=1 AndAlso ProfileIo.CarrierReads=1)
   For Each change As String In New String(){"list","mode","exemption","vat","rc","remove-override"}
    Dim draft As CheckoutDraftState=Nothing,owner As OrderStorefrontIdentity=Nothing:Initial(company,draft,owner)
    Select Case change
     Case "list":ProfileIo.Row("listino")=17
     Case "mode":ProfileIo.Row("IvaTipo")=1
     Case "exemption":ProfileIo.Row("IdEsenzioneIva")=8
     Case "vat":ProfileIo.Row("ValoreEsenzioneIva")=0D
     Case "rc":ProfileIo.Row("AbilitatoIvaReverseCharge")=1
     Case "remove-override":ProfileIo.Row("IdEsenzioneIva")=-1:ProfileIo.Row("ValoreEsenzioneIva")=DBNull.Value
    End Select
    ProfileIo.NewRequest(company):ValidateMaster(company):owner=ProfileIo.Identity(company)
    Dim read As CheckoutDraftState=Nothing
    Check("T1 sealed draft remains readable for final comparison "+change+company.ToString(),CheckoutDraftService.TryRead(HttpContext.Current,owner,draft.RequestId,draft.Fingerprint,read))
    Check("T1 stale retry rejected "+change,Not CheckoutDraftService.TryReadSelectionForRetry(HttpContext.Current,owner,read) AndAlso read Is Nothing)
    ExecuteOrder(draft,owner,draft.RequestId)
    Check("T1 stopped before fiscal restore and side effects "+change,ProfileIo.Writes=0 AndAlso ProfileIo.FiscalRestores=0)
    Check("T1 real retirement and existing cart target "+change,CheckoutFailureRecoveryService.IsRetiredRequest(HttpContext.Current,draft.RequestId) AndAlso HttpContext.Current.Response.RedirectLocation="carrello.aspx?checkoutfailed=1#pnlCheckoutSubmitError")
    Dim flash As CheckoutFailureFlash=Nothing:Check("T1 CartChanged recovery",CheckoutFailureRecoveryService.TryConsumeFailure(HttpContext.Current,flash) AndAlso flash.Reason=CheckoutFailureReason.CartChanged)
    Dim request=New CartProfileFixture().NextRequest(draft.RequestId):Check("T1 retired token rotates",request<>draft.RequestId AndAlso Not CheckoutFailureRecoveryService.IsRetiredRequest(HttpContext.Current,request))
    Dim fresh=NewDraft(owner,request):CheckoutDraftService.Store(HttpContext.Current,fresh):Check("T1 new checkout can resume",CheckoutDraftService.TryReadSelectionForRetry(HttpContext.Current,owner,read) AndAlso read.RequestId=request)
    Check("T1 no added profile queries",ProfileIo.Queries=1)
    Check("T1 existing carrier normalization read",ProfileIo.CarrierReads=If(change="remove-override",1,0))
   Next
   Dim original As CheckoutDraftState=Nothing,identity As OrderStorefrontIdentity=Nothing:Initial(company,original,identity)
   Dim cloned As CheckoutDraftState=Nothing:Check("T2 copy retains profile",CheckoutDraftService.TryRead(HttpContext.Current,identity,original.RequestId,original.Fingerprint,cloned) AndAlso cloned.CommercialProfileFingerprint=original.CommercialProfileFingerprint)
   ProfileIo.NewRequest(company):ValidateMaster(company):identity=ProfileIo.Identity(company)
   Check("T2 unchanged profile retry",CheckoutDraftService.TryReadSelectionForRetry(HttpContext.Current,identity,cloned))
   ExecuteOrder(original,identity,original.RequestId):Check("T2 unchanged profile passes final gate",ProfileIo.FiscalRestores=1 AndAlso ProfileIo.Writes=1 AndAlso Not CheckoutFailureRecoveryService.IsRetiredRequest(HttpContext.Current,original.RequestId))
   For Each fault As String In New String(){"v4","missing","empty","altered","malformed","uppercase"}
    Initial(company,original,identity):CheckoutDraftService.TryRead(HttpContext.Current,identity,original.RequestId,original.Fingerprint,cloned)
    Select Case fault
     Case "v4":cloned.Version=4
     Case "missing":cloned.CommercialProfileFingerprint=Nothing:CheckoutDraftService.Seal(cloned)
     Case "empty":cloned.CommercialProfileFingerprint="":CheckoutDraftService.Seal(cloned)
     Case "altered":cloned.CommercialProfileFingerprint=New String("a"c,64)
     Case "malformed":cloned.CommercialProfileFingerprint="invalid":CheckoutDraftService.Seal(cloned)
     Case "uppercase":cloned.CommercialProfileFingerprint=cloned.CommercialProfileFingerprint.ToUpperInvariant():CheckoutDraftService.Seal(cloned)
    End Select
    HttpContext.Current.Session("KeepStore:CheckoutDraft:Current")=cloned
    Dim result As CheckoutDraftState=Nothing
    Check("T4 invalid draft read false "+fault,Not CheckoutDraftService.TryRead(HttpContext.Current,identity,original.RequestId,"",result) AndAlso result Is Nothing)
    Check("T4 invalid draft retry false "+fault,Not CheckoutDraftService.TryReadSelectionForRetry(HttpContext.Current,identity,result) AndAlso result Is Nothing)
   Next
   Initial(company,original,identity):HttpContext.Current.Items.Remove("KeepStore.PriceDisplay.ValidatedTenant"):StorefrontPriceDisplayContextProvider.Invalidate(HttpContext.Current)
   Check("T4 unavailable profile prevents capture",Not New CartProfileFixture().Capture(identity))
   Check("T4 unavailable profile prevents retry",Not CheckoutDraftService.TryReadSelectionForRetry(HttpContext.Current,identity,cloned))
   ExecuteOrder(original,identity,original.RequestId):Check("T4 unavailable profile stops order",ProfileIo.Writes=0 AndAlso ProfileIo.FiscalRestores=0 AndAlso CheckoutFailureRecoveryService.IsRetiredRequest(HttpContext.Current,original.RequestId))
   Initial(company,original,identity):ProfileIo.Row("DescrizioneEsenzioneIva")="solo descrizione cambiata":ProfileIo.NewRequest(company):ValidateMaster(company)
   Check("description deliberately excluded",CheckoutDraftService.TryReadSelectionForRetry(HttpContext.Current,identity,cloned))
  Next
  Dim d As CheckoutDraftState=Nothing,i As OrderStorefrontIdentity=Nothing:Initial(1,d,i)
  Dim originalCulture=CultureInfo.CurrentCulture
  For Each name As String In New String(){"it-IT","en-US","fr-FR"}
   Threading.Thread.CurrentThread.CurrentCulture=CultureInfo.GetCultureInfo(name)
   Check("invariant culture "+name,CheckoutDraftService.ComputeCommercialProfileFingerprint(StorefrontPriceDisplayContextProvider.GetCurrent(HttpContext.Current),i)=d.CommercialProfileFingerprint)
  Next
  Threading.Thread.CurrentThread.CurrentCulture=originalCulture
  Dim profile=StorefrontPriceDisplayContextProvider.GetCurrent(HttpContext.Current)
  Check("normalized equivalent decimal scale",CheckoutDraftService.ComputeCommercialProfileFingerprint(New StorefrontPriceDisplayContext(1,i.PriceListId,True,profile.DisplayMode,10.00D,7,"different text",False),i)=d.CommercialProfileFingerprint)
  Dim zero=CheckoutDraftService.ComputeCommercialProfileFingerprint(New StorefrontPriceDisplayContext(1,i.PriceListId,True,profile.DisplayMode,0D,7,"",False),i)
  Dim absent=CheckoutDraftService.ComputeCommercialProfileFingerprint(New StorefrontPriceDisplayContext(1,i.PriceListId,True,profile.DisplayMode,Nothing,7,"",False),i)
  Check("zero override distinct from absent",zero<>absent)
  Check("missing identity rejected",CheckoutDraftService.ComputeCommercialProfileFingerprint(profile,Nothing)="")
  Dim other As New OrderStorefrontIdentity With {.DatabaseScopeKey=i.DatabaseScopeKey,.CompanyId=2,.LoginId=i.LoginId,.UtentiId=i.UtentiId,.PriceListId=i.PriceListId}
  Check("profile company mismatch rejected",CheckoutDraftService.ComputeCommercialProfileFingerprint(profile,other)="")
  other.CompanyId=1:other.PriceListId=99
  Check("profile list mismatch rejected",CheckoutDraftService.ComputeCommercialProfileFingerprint(profile,other)="")
  Check("anonymous profile rejected",CheckoutDraftService.ComputeCommercialProfileFingerprint(New StorefrontPriceDisplayContext(1,i.PriceListId,False,profile.DisplayMode,Nothing,-1,"",False),i)="")
  For Each fault As String In New String(){"owner","tenant","list"}
   ProfileIo.Configure(1)
   Select Case fault
    Case "owner":ProfileIo.Row("utentiid")=999
    Case "tenant":ProfileIo.Row("AziendeID")=2
    Case "list":ProfileIo.Row("listino")=0
   End Select
   Dim denied As Boolean=False
   Try
    ValidateMaster(1)
   Catch ex As HttpException
    denied=ex.GetHttpCode()=403
   End Try
   Check("T3 invalid verified scope rejected "+fault,denied AndAlso CInt(If(HttpContext.Current.Session("LoginId"),0))=0)
  Next
  Console.WriteLine("G6_COMMERCIAL_PROFILE_PASS="+passed.ToString())
 End Sub
End Module
'@
    $template=$template.Replace('IDENTITY_CLASS',$identityClass).Replace('DURABLE_METHODS',($durableMethods -join "`n")).Replace('MASTER_METHODS',$masterCode).Replace('BASELINE_MASTER_METHOD',$baselineMaster).Replace('ENSURE_REQUEST',(G6Method $cart 'EnsureCheckoutRequestId')).Replace('CAPTURE_GUARD',$captureGuard).Replace('ORDER_GUARD',$orderGuard).Replace('ORDER_DISPATCH',(G6Method $order 'DispatchDurableCheckoutFailure')).Replace('DISPATCH_TARGET',(G6Method $dispatcher 'ResolveTarget')).Replace('ENUM_VALUES',([regex]::Match($dispatcher,'(?s)Public Enum CheckoutTerminalOutcome(.*?)End Enum').Groups[1].Value)).Replace('VALID_DRAFT_FACTORY',$factory)
    $vb=Join-Path $evidence 'CommercialProfile.vb';$exe=Join-Path $evidence 'CommercialProfile.exe';[IO.File]::WriteAllText($vb,$template,$utf8)
    $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe';$mysql=Join-Path $RepositoryRoot 'Bin/MySql.Data.dll'
    $shared=@('CheckoutDraftService.vb','CheckoutFailureRecoveryService.vb','StorefrontPriceDisplayContext.vb','StorefrontPriceDisplayContextProvider.vb','StorefrontCommercialIsolationPolicy.vb')|ForEach-Object{Join-Path $RepositoryRoot ('App_Code/'+$_)}
    $compiled=@(& $compiler /nologo /target:exe /main:CommercialProfileCases ("/out:"+$exe) ("/r:"+$mysql) /r:System.dll,System.Core.dll,System.Web.dll,System.Data.dll,System.Configuration.dll $vb $shared 2>&1)
    [IO.File]::WriteAllLines((Join-Path $evidence 'compile.log'),[string[]]$compiled,$utf8);if($LASTEXITCODE){throw 'G6_COMPILE_FAILED'}
    Copy-Item -LiteralPath $mysql -Destination (Join-Path $evidence 'MySql.Data.dll')
    [IO.File]::WriteAllText(($exe+'.config'),'<configuration><connectionStrings><add name="EntropicConnectionString" connectionString="KS-DBCFG-FIXTURE-profile" /></connectionStrings></configuration>',$utf8)
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$exe;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $process=[Diagnostics.Process]::Start($start)
    try{$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();$process.WaitForExit();$status=$process.ExitCode;$output=@(($stdout.Result+"`n"+$stderr.Result) -split '\r?\n')}finally{$process.Dispose()}
    [IO.File]::WriteAllLines((Join-Path $evidence 'cases.log'),[string[]]$output,$utf8)
    if($status -ne 0 -or !($output -match '^G6_COMMERCIAL_PROFILE_PASS=')){throw 'G6_CASES_FAILED'}
    $count=@($output|Where-Object{$_ -match '^PASS '}).Count
    [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),(@{Result='PASS SOURCE';Checks=$count;Base=$BaselineRef;RealSource='master scope/hydration/normalization, draft service v5, profile capture/final gate, request rotation, recovery retirement and dispatcher target';Io='vlogin and carrier default read fixtures; SQL selections not executed; transaction/gateway/email/document not executed; HTTP completion and telemetry isolated';NoAdditionalProfileQueries='one existing vlogin read; same-request marker reused; existing optional carrier VAT lookup counted and cached separately';DescriptionExcluded=$true}|ConvertTo-Json -Depth 5),$utf8)
    Write-Output ('G6_COMMERCIAL_PROFILE_PASS checks='+$count)
    exit 0
}

if($ListinoAuthorityOnly){
    # Reuse the real-method extraction, vbc and System.Web session-fixture approach
    # of this harness and Test-RegOrderSql8Compatibility. No existing suite is run.
    $ErrorActionPreference='Stop'
    if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'WINDOWS_POWERSHELL_51_REQUIRED'}
    if(!$EvidenceDirectory){throw 'NEW_TEMP_EVIDENCE_DIRECTORY_REQUIRED'}
    $evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
    if(!$evidence.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'NEW_TEMP_EVIDENCE_DIRECTORY_REQUIRED'}
    [void][IO.Directory]::CreateDirectory($evidence)
    if($BaselineRef -cnotmatch '^[0-9a-f]{40}$'){throw 'EXACT_BASELINE_REQUIRED'}
    $utf8=New-Object Text.UTF8Encoding($false)
    function Source([string]$file){[IO.File]::ReadAllText((Join-Path $RepositoryRoot $file))}
    function Original([string]$file){$s=(& git -C $RepositoryRoot show ($BaselineRef+':'+$file)) -join "`n";if($LASTEXITCODE){throw 'BASELINE_UNAVAILABLE'};return $s}
    function Method([string]$s,[string]$name){$m=[regex]::Match($s,'(?ms)^\s*(?:Public|Private|Protected) (?:Shared )?(?:Function|Sub) '+$name+'\b.*?^\s*End (?:Function|Sub)');if(!$m.Success){throw ('SOURCE_METHOD_MISSING '+$name)};return $m.Value}
    function OrderBlock([string]$s){$a=$s.IndexOf('                If Not isLegacyCouponFlow Then');$b=$s.IndexOf('                CheckoutFailureRecoveryService.TracePhase(', $s.IndexOf('                End If', $s.IndexOf('If priceRevalidation.HasChanges Then',$a))+22);if($a -lt 0 -or $b -lt $a){throw 'ORDER_BLOCK_MISSING'};return $s.Substring($a,$b-$a)}
    function Flat([string]$s){return ($s -replace '\r\n',"`n").Trim()}
    $order=Source 'ordine.aspx.vb';$cart=Source 'carrello.aspx.vb';$oldOrder=Original 'ordine.aspx.vb';$oldCart=Original 'carrello.aspx.vb'
    $block=OrderBlock $order;$oldBlock=OrderBlock $oldOrder;$handler=Method $cart 'rPromo_ItemDataBound';$oldHandler=Method $oldCart 'rPromo_ItemDataBound'
    $scopeOrder=$order.Replace($block,'');$scopeCart=$cart.Replace($handler,'')
    if($AllowCommercialProfileDelta){
        # G6 is exercised separately above. Remove only its exact additive guards
        # when asserting that the G1 revalidation and badge remain unchanged.
        if($BaselineRef -cne '14f2ef440cac25d54b5ec2dc1aba79adc5f51442'){throw 'G6_EXACT_BASE_REQUIRED'}
        $expectedOrder=@'
                Dim currentCommercialProfile As String = CheckoutDraftService.ComputeCommercialProfileFingerprint(
                    StorefrontPriceDisplayContextProvider.GetCurrent(HttpContext.Current), orderIdentity)
                If String.IsNullOrEmpty(currentCommercialProfile) OrElse
                   Not String.Equals(currentCommercialProfile, checkoutDraft.CommercialProfileFingerprint, StringComparison.Ordinal) Then
                    DispatchDurableCheckoutFailure(
                        checkoutRequestId, CheckoutFailureReason.CartChanged, "ValidateCommercialProfile")
                    Exit Sub
                End If
'@
        $expectedCapture=@'
        Dim commercialProfileFingerprint As String = CheckoutDraftService.ComputeCommercialProfileFingerprint(
            StorefrontPriceDisplayContextProvider.GetCurrent(HttpContext.Current), identity)
        If String.IsNullOrEmpty(commercialProfileFingerprint) Then
            failureReason = CheckoutFailureReason.CartChanged
            Return False
        End If
'@
        $scopeOrder=$scopeOrder.Replace("`r`n","`n");$scopeCart=$scopeCart.Replace("`r`n","`n")
        $expectedOrder=$expectedOrder.Replace("`r`n","`n");$expectedCapture=$expectedCapture.Replace("`r`n","`n")
        if(!$scopeOrder.Contains($expectedOrder) -or !$scopeCart.Contains($expectedCapture)){throw 'G6_EXACT_GUARDS_REQUIRED'}
        $scopeOrder=$scopeOrder.Replace($expectedOrder+"`n`n",'')
        $scopeCart=$scopeCart.Replace($expectedCapture+"`n",'').Replace('            .CommercialProfileFingerprint = commercialProfileFingerprint,'+"`n",'')
    }
    if((Flat $scopeOrder) -cne (Flat $oldOrder.Replace($oldBlock,'')) -or (Flat $scopeCart) -cne (Flat $oldCart.Replace($oldHandler,''))){throw 'RUNTIME_SCOPE_EXPANDED'}
    foreach($file in @('Page.master','App_Code/StorefrontPriceDisplayContextProvider.vb','App_Code/StorefrontPriceDisplayContext.vb','App_Code/StorefrontCommercialIsolationPolicy.vb','App_Code/OrderStorefrontContext.vb','App_Code/CartPriceRevalidationHelper.vb','App_Code/OrderDurableIdempotencyService.vb','App_Code/CheckoutFailureRecoveryService.vb','App_Code/CheckoutTerminalOutcomeDispatcher.vb','App_Code/ProductPromotionEligibilityResolver.vb','App_Code/ProductPromotionDisplayHelper.vb')){
        if((Flat (Source $file)) -cne (Flat (Original $file))){throw ('AUTHORITY_CHANGED '+$file)}
    }
    if($order.IndexOf($block) -ge $order.IndexOf('Using cmd As New MySqlCommand("Carrello_Documento"') -or $order.IndexOf('SendEmail(', $order.IndexOf($block)) -lt $order.IndexOf($block)+$block.Length){throw 'SIDE_EFFECT_ORDER_CHANGED'}
    $price=Source 'App_Code/CartPriceRevalidationHelper.vb';$resolver=Source 'App_Code/ProductPromotionEligibilityResolver.vb';$durable=Source 'App_Code/OrderDurableIdempotencyService.vb';$dispatcher=Source 'App_Code/CheckoutTerminalOutcomeDispatcher.vb'
    $priceTypes=$price.Substring($price.IndexOf('Public Class CartPriceRevalidationChange'),$price.IndexOf('Friend Class CartPriceRevalidationRow')-$price.IndexOf('Public Class CartPriceRevalidationChange'))
    $eligibilityTypes=$resolver.Substring($resolver.IndexOf('Public Class ProductPromotionEligibilityContext'),$resolver.IndexOf('Public Module ProductPromotionEligibilityResolver')-$resolver.IndexOf('Public Class ProductPromotionEligibilityContext'))
    $contexts=([regex]::Matches($resolver,'(?ms)^    Public Function CreateContext\b.*?^    End Function')|ForEach-Object {$_.Value}) -join "`n"
    $constants=([regex]::Matches($price,'(?m)^    Public Const (?:SessionMessageKey|SessionChangedKey|GenericChangedMessage|GenericTechnicalErrorMessage).*')|ForEach-Object {$_.Value}) -join "`n"
    $priceMethods=@('StoreResultInSession','BuildMessageHtml','PriceChanged','FormatCurrencyIt')|ForEach-Object {Method $price $_}
    $template=@'
Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Configuration
Imports System.Text
Imports System.Web
Imports System.Web.SessionState
Imports System.Web.UI
Imports System.Web.UI.WebControls
PRICE_TYPES
ELIGIBILITY_TYPES
Public Module Io
 Public Events As New List(Of String), PriceCalls As Integer, LastList As Integer, PromoCalls As Integer, Documents As Integer, Gateways As Integer, Emails As Integer, Confirmations As Integer
 Public ExpectedCompany As Integer, ExpectedList As Integer, RetryPersists As Boolean=True, Failure As Boolean, Changed As Boolean, OfferAllowed As Boolean=True, PromoTechnical As Boolean
 Public Sub Reset()
  Events.Clear():PriceCalls=0:LastList=0:PromoCalls=0:Documents=0:Gateways=0:Emails=0:Confirmations=0:RetryPersists=True:Failure=False:Changed=False:OfferAllowed=True:PromoTechnical=False
 End Sub
End Module
Public Class FixtureTransaction
 Public Sub Rollback()
  Io.Events.Add("rollback")
 End Sub
 Public Sub Dispose()
  Io.Events.Add("dispose")
 End Sub
 Public Sub Commit()
  Io.Events.Add("commit")
 End Sub
End Class
Public Class OrderIdentityFixture
 Public CompanyId As Integer,PriceListId As Integer
End Class
Public Class OrderPageFixture
 Public isLegacyCouponFlow As Boolean=False
 Public orderIdentity As New OrderIdentityFixture
 Public LoginId As Integer=42,TipoDoc As Integer=4
 Public checkoutRequestId As String="11111111111111111111111111111111",payloadFingerprint As String="synthetic-payload"
 Public conn As New Object,trns As FixtureTransaction=New FixtureTransaction
 Private Function GetSessionInt(key As String,Optional fallback As Integer=0) As Integer
  Dim parsed As Integer:Return If(Integer.TryParse(Convert.ToString(HttpContext.Current.Session(key)),parsed),parsed,fallback)
 End Function
 Public Sub Execute()
ORDER_BLOCK
  ' Observable boundary only: never execute a document, gateway, email or order.
  Io.Documents+=1:Io.Gateways+=1:Io.Emails+=1:Io.Confirmations+=1
 End Sub
End Class
Public Module CartPriceRevalidationHelper
PRICE_CONSTANTS
 Private ReadOnly PriceCulture As CultureInfo=CultureInfo.GetCultureInfo("it-IT")
 Public Function RevalidateCurrentCart(context As HttpContext,conn As Object,trns As Object,login As Integer,sessionId As String,listino As Integer,a As Boolean,b As Boolean,unused As Object) As CartPriceRevalidationResult
  Io.PriceCalls+=1:Io.LastList=listino
  Dim result As New CartPriceRevalidationResult With {.HasBlockingError=Io.Failure,.HasTechnicalError=Io.Failure,.ErrorMessage=GenericTechnicalErrorMessage}
  If Io.Changed Then result.Changes.Add(New CartPriceRevalidationChange With {.ArticleId=901,.OldPriceIvato=12.2D,.NewPriceIvato=13.42D})
  Return result
 End Function
PRICE_METHODS
End Module
Public Module OrderDurableIdempotencyService
NORMALIZE_REQUEST
 Public Function RecordRetryRequired(conn As Object,request As String,login As Integer,company As Integer,tipo As Integer,payload As String) As Boolean
  Io.Events.Add("retry-after-rollback"):Return Io.RetryPersists
 End Function
 Public Sub MarkRetryRequired(conn As Object,trns As Object,request As String,login As Integer,company As Integer,tipo As Integer,payload As String)
  Io.Events.Add("mark-retry")
 End Sub
End Module
Public Enum CheckoutTerminalOutcome
ENUM_VALUES
End Enum
Public Module CheckoutTerminalOutcomeDispatcher
 Public Function Dispatch(context As HttpContext,outcome As CheckoutTerminalOutcome,Optional token As String="") As Boolean
  If context.Items("KeepStore:CheckoutTerminalOutcome") IsNot Nothing Then Return False
  context.Items("KeepStore:CheckoutTerminalOutcome")=outcome.ToString()
  context.Response.StatusCode=303:context.Response.RedirectLocation=ResolveTarget(outcome,token)
  Io.Events.Add("dispatch"):Return True
 End Function
RESOLVE_TARGET
End Module
Public Module CheckoutDurableTelemetry
 Public Sub Write(context As HttpContext,request As String,phase As String,outcome As String,failure As Exception,idempotency As String,transaction As String,checkpoint As String)
 End Sub
End Module
Public Module KeepStoreLog
 Public Sub [Error](scope As String,message As String,ex As Exception,context As HttpContext)
 End Sub
End Module
Public Module StorefrontSeoTenantContext
 Public Function ConfiguredDatabaseScopeKey() As String
  Return "isolated-source-fixture"
 End Function
End Module
Public Module ProductPromotionEligibilityResolver
CONTEXT_METHODS
SESSION_INT
FIRST_POSITIVE
 Public Function Resolve(batch As ProductPromotionEligibilityBatch,article As Integer,tc As Integer,quantity As Decimal,net As Decimal,gross As Decimal) As ProductPromotionEligibilityResult
  Throw New InvalidOperationException("UNEXPECTED_BATCH_IO")
 End Function
 Public Function Resolve(connection As String,context As ProductPromotionEligibilityContext,article As Integer,tc As Integer,quantity As Decimal,net As Decimal,gross As Decimal) As ProductPromotionEligibilityResult
  Io.PromoCalls+=1
  Dim result As New ProductPromotionEligibilityResult With {.BasePriceNet=net,.BasePriceGross=gross}
  If Io.PromoTechnical Then Throw New InvalidOperationException("synthetic read failure")
  If Io.OfferAllowed AndAlso context.CompanyId=Io.ExpectedCompany AndAlso context.Listino=Io.ExpectedList AndAlso article=901 AndAlso tc=5 Then result.AuthorizedOffers.Add(New ProductPromotionEligibilityOffer With {.OfferId=11,.OfferDetailId=101,.QntMinima=2,.PriceNet=8D,.PriceGross=9.76D})
  Return result
 End Function
End Module
Public Class PromoPageFixture
 Public ReadOnly Property Session As HttpSessionState
  Get
   Return HttpContext.Current.Session
  End Get
 End Property
SESSION_GETTER
SAFE_INT
SAFE_INT_TEXT
READ_DECIMAL
PROMO_HANDLER
 Public Function Display(Optional detail As Integer=101,Optional tc As Integer=5) As Label
  Dim table As New DataTable
  table.Columns.Add("ID",GetType(Integer)):table.Columns.Add("TCid",GetType(Integer)):table.Columns.Add("OfferteDettagliId",GetType(Integer)):table.Columns.Add("Prezzo",GetType(Decimal)):table.Columns.Add("PrezzoIvato",GetType(Decimal))
  table.Rows.Add(901,tc,detail,10D,12.2D)
  Dim item As New RepeaterItem(0,ListItemType.Item):item.DataItem=table.DefaultView(0)
  Dim label As New Label With {.ID="lblOfferta",.Visible=True}:item.Controls.Add(label)
  rPromo_ItemDataBound(Nothing,New RepeaterItemEventArgs(item)):Return label
 End Function
End Class
Public Module ListinoAuthorityCases
 Private passed As Integer,failed As Integer
 Private Sub Check(name As String,valid As Boolean)
  If valid Then
   passed+=1:Console.WriteLine("PASS "+name)
  Else
   failed+=1:Console.WriteLine("FAIL "+name)
  End If
 End Sub
 Private Function Configure(company As Integer,list As Object,authenticated As Boolean,Optional tenant As Boolean=True) As HttpContext
  Io.Reset():Io.ExpectedCompany=company:Io.ExpectedList=If(company=1,If(authenticated,4,1),If(authenticated,13,10))
  Dim context As New HttpContext(New HttpRequest("","https://fixture.invalid/ordine.aspx",""),New HttpResponse(New System.IO.StringWriter))
  SessionStateUtility.AddHttpSessionStateToContext(context,New HttpSessionStateContainer("synthetic",New SessionStateItemCollection,New HttpStaticObjectsCollection,20,True,HttpCookieMode.UseCookies,SessionStateMode.InProc,False))
  HttpContext.Current=context:context.Session("AziendaID")=company:context.Session("Listino")=list:context.Session("LoginId")=If(authenticated,42,0):context.Session("AuthenticatedAziendaID")=If(authenticated,company,0):context.Session("UtentiId")=If(authenticated,101,0):context.Session("IvaTipo")=2
  If tenant Then StorefrontPriceDisplayContextProvider.SetTenantDefaults(context,company,If(company=1,1,10),2)
  Return context
 End Function
 Private Sub Denied(name As String,company As Integer,list As Object,Optional tenant As Boolean=True,Optional anonymous As Boolean=False,Optional identityCompany As Integer=0,Optional identityList As Integer=0,Optional sessionCompany As Integer=0)
  Dim context=Configure(company,list,Not anonymous,tenant),order As New OrderPageFixture
  order.orderIdentity.CompanyId=If(identityCompany>0,identityCompany,company):order.orderIdentity.PriceListId=If(identityList>0,identityList,If(company=1,4,13))
  If sessionCompany>0 Then context.Session("AziendaID")=sessionCompany
  order.Execute()
  Check(name+"/no-revalidation",Io.PriceCalls=0)
  Check(name+"/no-document-email-gateway-confirmation",Io.Documents+Io.Emails+Io.Gateways+Io.Confirmations=0)
  Check(name+"/rollback-retry-dispatch",String.Join(",",Io.Events.ToArray())="rollback,dispose,retry-after-rollback,dispatch")
  Check(name+"/technical-feedback-and-retirement",Convert.ToString(context.Session("CartPriceRevalidationMessage"))=HttpUtility.HtmlEncode(CartPriceRevalidationHelper.GenericTechnicalErrorMessage) AndAlso CheckoutFailureRecoveryService.IsRetiredRequest(context,order.checkoutRequestId))
  Check(name+"/existing-terminal-target",context.Response.StatusCode=303 AndAlso context.Response.RedirectLocation="carrello.aspx?pricechanged=1")
 End Sub
 Public Sub Main()
  For Each company As Integer In New Integer(){1,2}
   For Each authenticated As Boolean In New Boolean(){False,True}
    Dim list=If(company=1,If(authenticated,4,1),If(authenticated,13,10)),context=Configure(company,list,authenticated),promo=New PromoPageFixture().Display()
    Check("valid/"+company.ToString()+"/"+authenticated.ToString()+"/promo",promo.Visible AndAlso promo.Text.Contains("9,76") AndAlso Io.PromoCalls=1)
    If authenticated Then
     Dim order As New OrderPageFixture:order.orderIdentity.CompanyId=company:order.orderIdentity.PriceListId=list:order.Execute()
     Check("valid/order/"+company.ToString(),Io.PriceCalls=1 AndAlso Io.LastList=list AndAlso Io.Documents=1 AndAlso Io.Events.Count=0)
    Else
     Denied("anonymous/order/"+company.ToString(),company,list,True,True)
    End If
   Next
   For Each bad As Object In New Object(){Nothing,0,-3,"invalid","10.5",DBNull.Value}
    Dim name="invalid-list/"+company.ToString()+"/"+Convert.ToString(bad,CultureInfo.InvariantCulture)
    Denied(name,company,bad)
    Configure(company,bad,True):Dim label=New PromoPageFixture().Display():Check(name+"/badge-hidden-no-read",Not label.Visible AndAlso Io.PromoCalls=0)
   Next
   Denied("missing-provider/"+company.ToString(),company,Io.ExpectedList,False)
   Configure(company,If(company=1,4,13),True,False):Check("missing-provider/badge",Not New PromoPageFixture().Display().Visible AndAlso Io.PromoCalls=0)
   Denied("wrong-order-company/"+company.ToString(),company,If(company=1,4,13),True,False,99)
   Denied("wrong-checkout-list/"+company.ToString(),company,If(company=1,4,13),True,False,0,99)
   Denied("wrong-session-tenant/order/"+company.ToString(),company,If(company=1,4,13),True,False,0,0,99)
   Dim ctx=Configure(company,If(company=1,4,13),True):ctx.Session("AziendaID")=99
   Check("wrong-session-tenant/provider",StorefrontPriceDisplayContextProvider.GetCurrent(ctx) Is Nothing)
   Check("wrong-session-tenant/badge",Not New PromoPageFixture().Display().Visible AndAlso Io.PromoCalls=0)
  Next
  Dim cached=Configure(1,4,True):StorefrontPriceDisplayContextProvider.GetCurrent(cached):cached.Session("AziendaID")=2
  Check("cached-context-company/badge",Not New PromoPageFixture().Display().Visible AndAlso Io.PromoCalls=0)
  cached=Configure(1,4,True):StorefrontPriceDisplayContextProvider.GetCurrent(cached):cached.Session("UtentiId")=0
  Check("inconsistent-promotion-auth/badge",Not New PromoPageFixture().Display().Visible AndAlso Io.PromoCalls=0)
  Configure(2,13,True):Io.OfferAllowed=False:Check("unauthorized-offer/badge",Not New PromoPageFixture().Display().Visible)
  Configure(2,13,True):Io.PromoTechnical=True:Check("technical-offer-read/badge",Not New PromoPageFixture().Display().Visible)
  Configure(2,13,True):Check("wrong-detail/badge",Not New PromoPageFixture().Display(999).Visible)
  Configure(2,13,True):Check("wrong-variant/badge",Not New PromoPageFixture().Display(101,6).Visible)
  Dim net=Configure(2,13,True):net.Session("IvaTipo")=1:Check("net-vat-mode-preserved/badge",New PromoPageFixture().Display().Text.Contains("8,00"))
  Dim retry=Configure(2,Nothing,True),page As New OrderPageFixture:page.orderIdentity.CompanyId=2:page.orderIdentity.PriceListId=13:Io.RetryPersists=False:page.Execute()
  Check("retry-write-failure/session-retired",CheckoutFailureRecoveryService.IsRetiredRequest(retry,page.checkoutRequestId) AndAlso Io.Documents=0 AndAlso Io.Events.Contains("retry-after-rollback"))
  Configure(2,13,True):page=New OrderPageFixture:page.orderIdentity.CompanyId=2:page.orderIdentity.PriceListId=13:Io.Changed=True:page.Execute()
  Check("normal-price-change/commit-retry",String.Join(",",Io.Events.ToArray())="mark-retry,commit,dispose,dispatch" AndAlso Io.Documents=0)
  Configure(1,1,True):page=New OrderPageFixture:page.orderIdentity.CompanyId=1:page.orderIdentity.PriceListId=1:page.Execute()
  Check("verified-list-one-still-valid",Io.PriceCalls=1 AndAlso Io.LastList=1 AndAlso Io.Documents=1)
  Configure(2,13,True):page=New OrderPageFixture:page.orderIdentity.CompanyId=2:page.orderIdentity.PriceListId=13:Io.Failure=True:page.Execute()
  Check("existing-revalidation-technical-failure",String.Join(",",Io.Events.ToArray())="rollback,dispose,retry-after-rollback,dispatch" AndAlso Io.Documents=0)
  Console.WriteLine("LISTINO_AUTHORITY_PASSED="+passed.ToString()+";FAILED="+failed.ToString())
  Environment.ExitCode=If(failed=0,0,1)
 End Sub
End Module
'@
    $template=$template.Replace('PRICE_TYPES',$priceTypes).Replace('ELIGIBILITY_TYPES',$eligibilityTypes).Replace('PRICE_CONSTANTS',$constants).Replace('PRICE_METHODS',($priceMethods -join "`n")).Replace('NORMALIZE_REQUEST',((Method $durable 'TryNormalizeRequestId').Replace('Public Shared Function','Public Function'))).Replace('ENUM_VALUES',([regex]::Match($dispatcher,'(?s)Public Enum CheckoutTerminalOutcome(.*?)End Enum').Groups[1].Value)).Replace('RESOLVE_TARGET',((Method $dispatcher 'ResolveTarget').Replace('Private Shared Function','Private Function'))).Replace('CONTEXT_METHODS',$contexts).Replace('SESSION_INT',(Method $resolver 'SessionInt')).Replace('FIRST_POSITIVE',(Method $resolver 'FirstPositive')).Replace('SESSION_GETTER',(Method $cart 'GetSessionInt')).Replace('SAFE_INT_TEXT',(Method $cart 'SafeIntFromText')).Replace('SAFE_INT',(Method $cart 'SafeInt')).Replace('READ_DECIMAL',(Method $cart 'TryReadDatabaseDecimal'))
    $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $shared=@('StorefrontPriceDisplayContext.vb','StorefrontPriceDisplayContextProvider.vb','StorefrontCommercialIsolationPolicy.vb','ProductPromotionDisplayHelper.vb','UiPriceFormatter.vb','CheckoutFailureRecoveryService.vb')|ForEach-Object{Join-Path $RepositoryRoot ('App_Code/'+$_)}
    $results=@()
    foreach($variant in @('baseline','candidate')){
        $vb=Join-Path $evidence ($variant+'.vb');$exe=Join-Path $evidence ($variant+'.exe')
        [IO.File]::WriteAllText($vb,$template.Replace('ORDER_BLOCK',$(if($variant -eq 'baseline'){$oldBlock}else{$block})).Replace('PROMO_HANDLER',$(if($variant -eq 'baseline'){$oldHandler}else{$handler})),$utf8)
        $compilation=@(& $compiler /nologo /target:exe /main:ListinoAuthorityCases ("/out:"+$exe) /r:System.dll,System.Core.dll,System.Web.dll,System.Data.dll,System.Configuration.dll $vb $shared 2>&1)
        if($LASTEXITCODE){[IO.File]::WriteAllLines((Join-Path $evidence ($variant+'-compile.log')),[string[]]$compilation,$utf8);throw ('LISTINO_COMPILE_FAILED '+$variant)}
        [IO.File]::WriteAllText(($exe+'.config'),'<configuration><connectionStrings><add name="EntropicConnectionString" connectionString="KS-DBCFG-FIXTURE-listino" /></connectionStrings></configuration>',$utf8)
        $output=@(& $exe 2>&1|ForEach-Object{$_.ToString()});$code=$LASTEXITCODE
        [IO.File]::WriteAllLines((Join-Path $evidence ($variant+'.log')),[string[]]$output,$utf8)
        $fixedBaseline=$oldBlock.Contains('StorefrontPriceDisplayContextProvider.GetCurrent(')
        if(($variant -eq 'candidate' -or $fixedBaseline) -and $code -ne 0){throw ('LISTINO_EXECUTION_FAILED '+$variant)}
        if($variant -eq 'baseline' -and !$fixedBaseline -and ($code -ne 1 -or !($output -match '^FAIL invalid-list/.*/no-revalidation'))){throw ('LISTINO_BASELINE_COUNTEREXAMPLE_MISSING '+$variant)}
        $results+=@{Variant=$variant;Passes=@($output|Where-Object{$_ -match '^PASS '}).Count;Failures=@($output|Where-Object{$_ -match '^FAIL '}).Count}
    }
    [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),(@{Result='PASS SOURCE';Base=$BaselineRef;Variants=$results;RealSource='provider/context/policy, page methods and revalidation block, price feedback, recovery retirement, promo display helper; dispatcher target';Io='transaction, durable database write, resolver data and HTTP completion replaced; no IIS/MySQL/gateway/email; post-gate effects are counters';Scope='two G1 targets; exact G6 additions allowed only by explicit switch and exact base; unchanged authorities checked'}|ConvertTo-Json -Depth 6),$utf8)
    $results|ForEach-Object{Write-Output ('LISTINO_AUTHORITY '+$_.Variant+' passes='+$_.Passes+' failures='+$_.Failures)}
    exit 0
}

$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$harnessPath = Join-Path $PSScriptRoot 'CheckoutFailureRecoveryHarness.vb'
$logicalResolverPath = Join-Path $RepositoryRoot 'App_Code\OrderLogicalIdentityResolver.vb'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreCheckoutRecovery-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $tempRoot 'CheckoutFailureRecoveryHarness.exe'

function Read-RepoFile([string]$relativePath) {
    $path = Join-Path $RepositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ('REQUIRED_FILE_MISSING=' + $path)
    }
    return [IO.File]::ReadAllText($path)
}

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw ('CHECKOUT_FAILURE_RECOVERY_SOURCE_FAILED=' + $code) }
    Write-Output ('PASS SOURCE_' + $code)
}

function Get-VbMethod([string]$source, [string]$signature) {
    $pattern = '(?is)' + [regex]::Escape($signature) + '[\s\S]*?\r?\n\s*End (?:Function|Sub)'
    return [regex]::Match($source, $pattern).Value
}

foreach ($required in @($compiler, $harnessPath, $logicalResolverPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw ('REQUIRED_FILE_MISSING=' + $required)
    }
}

$recovery = Read-RepoFile 'App_Code\CheckoutFailureRecoveryService.vb'
$dispatcher = Read-RepoFile 'App_Code\CheckoutTerminalOutcomeDispatcher.vb'
$durable = Read-RepoFile 'App_Code\OrderDurableIdempotencyService.vb'
$logicalResolver = Read-RepoFile 'App_Code\OrderLogicalIdentityResolver.vb'
$orderContext = Read-RepoFile 'App_Code\OrderStorefrontContext.vb'
$cart = Read-RepoFile 'carrello.aspx.vb'
$cartMarkup = Read-RepoFile 'carrello.aspx'
$order = Read-RepoFile 'ordine.aspx.vb'
$readModel = Read-RepoFile 'App_Code\CartAuthoritativeReadModel.vb'
$miniCart = Read-RepoFile 'Public\ui\controls\MiniCart.ascx.vb'
$master = Read-RepoFile 'Page.master.vb'

$verifyAccount = Get-VbMethod $orderContext 'Public Shared Function VerifyAccount'
$loginOwnership = Get-VbMethod $durable 'Private Shared Function IsLoginOwnedByCompany'
$retireAndDispatch = Get-VbMethod $recovery 'Public Shared Function RetireAndDispatch'
$consumeFailure = Get-VbMethod $recovery 'Public Shared Function TryConsumeFailure'
$recordRetry = Get-VbMethod $durable 'Public Shared Function RecordRetryRequired'
$generateToken = Get-VbMethod $cart 'Private Function GenerateCheckoutToken'
$showFailure = Get-VbMethod $cart 'Private Sub ShowCheckoutFailureFromSession'

Assert-Source (
    $verifyAccount -match '(?i)SELECT\s+DISTINCT\s+utentiid\s*,\s*COALESCE\s*\(\s*listino\s*,\s*0\s*\)' -and
    $verifyAccount -notmatch '(?i)SELECT\s+COUNT\s*\('
) '01_VERIFY_ACCOUNT_COLLAPSES_IDENTICAL_PHYSICAL_ROWS'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($loginOwnership) -and
    $loginOwnership.Contains('OrderLogicalIdentityResolver.TryResolve') -and
    $loginOwnership -match '(?i)SELECT\s+utentiid\s*,\s*COALESCE\s*\(\s*listino\s*,\s*0\s*\)' -and
    $loginOwnership -notmatch '(?i)SELECT\s+COUNT\s*\(' -and
    $logicalResolver.Contains('row.UserId <= 0 OrElse row.PriceListId <= 0') -and
    $logicalResolver.Contains('row.UserId <> userId OrElse row.PriceListId <> priceListId')
) '02_IDEMPOTENCY_OWNER_CHECK_USES_LOGICAL_IDENTITY'

Assert-Source (
    $recovery.Contains('Public Shared Function RetireAndDispatch') -and
    $recovery.Contains('Public Shared Sub RetireRequest') -and
    $recovery.Contains('Public Shared Function IsRetiredRequest') -and
    $recovery.Contains('Public Shared Function TryConsumeFailure') -and
    $recovery.Contains('Public Shared Sub TracePhase') -and
    $recovery.Contains('Public Shared Function GetCorrelationId')
) '03_RECOVERY_SERVICE_EXPOSES_REQUIRED_CONTROL_FLOW'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($retireAndDispatch) -and
    $retireAndDispatch.IndexOf('RetireRequest', [StringComparison]::Ordinal) -ge 0 -and
    $retireAndDispatch.IndexOf('CheckoutTerminalOutcome.CheckoutFailure', [StringComparison]::Ordinal) -gt
        $retireAndDispatch.IndexOf('RetireRequest', [StringComparison]::Ordinal) -and
    $retireAndDispatch -match '(?i)Session'
) '04_FAILURE_RETIRES_THEN_STORES_SERVER_SIDE_AND_DISPATCHES'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($consumeFailure) -and
    $consumeFailure -match '(?i)Session' -and
    $consumeFailure -match '(?i)Remove|Nothing' -and
    $consumeFailure -notmatch '(?i)Request\.QueryString'
) '05_FAILURE_MESSAGE_IS_ONE_TIME_AND_NOT_QUERY_CONTROLLED'

Assert-Source (
    $dispatcher.Contains('CheckoutFailure') -and
    $dispatcher.Contains('carrello.aspx?checkoutfailed=1#pnlCheckoutSubmitError') -and
    $cartMarkup.Contains('ID="pnlCheckoutSubmitError"') -and
    $dispatcher.Contains('response.StatusCode = 303') -and
    $dispatcher.Contains('context.ApplicationInstance.CompleteRequest()')
) '06_FAILURE_OUTCOME_USES_TERMINAL_HTTP_303_PRG'

Assert-Source (
    $cart.Contains('CheckoutFailureRecoveryService.TryConsumeFailure') -and
    $cart.Contains('CheckoutFailureRecoveryService.RetireAndDispatch') -and
    $cart.Contains('CheckoutFailureRecoveryService.IsRetiredRequest') -and
    $cart.Contains('EnsureCheckoutRequestId()') -and
    $order.Contains('CheckoutFailureRecoveryService.IsRetiredRequest')
) '07_CART_CONSUMES_FLASH_ROTATES_REQUEST_AND_BLOCKS_RETIRED'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($recordRetry) -and
    $recordRetry.Contains('RetryRequiredState') -and
    $order.Contains('OrderDurableIdempotencyService.RecordRetryRequired') -and
    $order.Contains('CheckoutFailureRecoveryService.RetireAndDispatch')
) '08_POSTCLAIM_FAILURE_RECORDS_RETRY_BEFORE_RECOVERY'

$procedureIndex = $order.IndexOf('Carrello_Documento', [StringComparison]::Ordinal)
$completeIndex = $order.IndexOf('OrderDurableIdempotencyService.Complete(', $procedureIndex, [StringComparison]::Ordinal)
$commitIndex = $order.IndexOf('trns.Commit()', $completeIndex, [StringComparison]::Ordinal)
$emailIndex = $order.IndexOf('SendEmail(', $commitIndex, [StringComparison]::Ordinal)
Assert-Source (
    $procedureIndex -ge 0 -and $completeIndex -gt $procedureIndex -and
    $commitIndex -gt $completeIndex -and $emailIndex -gt $commitIndex
) '09_PROCEDURE_COMPLETE_COMMIT_EMAIL_ORDERING'

Assert-Source (
    $cart.Contains('Case "cvCheckoutShippingMethod"') -and
    $cart.Contains('Case "cvCheckoutPaymentMethod"') -and
    $cart.Contains('Seleziona un metodo di spedizione') -and
    $cart.Contains('Seleziona un metodo di pagamento')
) '10_SHIPPING_AND_PAYMENT_FAIL_BEFORE_DISPATCH'

Assert-Source (
    $order.Contains('record.AziendaId') -or
    ($order.Contains('receiptAziendaId') -and $order.Contains('LoadOrderEmailBrandData'))
) '11_EMAIL_BRANDING_USES_PERSISTED_COMPANY'

Assert-Source (
    $cartMarkup.Contains('TypeName="CartAuthoritativeReadDataSource" SelectMethod="SelectStandardItems"') -and
    $miniCart.Contains('CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)') -and
    $master.Contains('CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)') -and
    $readModel.Contains('KeepStore:CartAuthoritativeReadModel:Current')
) '12_CART_PAGE_MINICART_HEADER_SHARE_READ_MODEL'

$catchIndex = $order.IndexOf('Catch ex As Exception', $commitIndex, [StringComparison]::Ordinal)
$postCommitIndex = $order.IndexOf('If commitCompleted Then', $catchIndex, [StringComparison]::Ordinal)
$inventoryCatchIndex = $order.IndexOf('FindInventoryAvailabilityException(ex)', $catchIndex, [StringComparison]::Ordinal)
Assert-Source (
    $catchIndex -ge 0 -and $postCommitIndex -gt $catchIndex -and
    $inventoryCatchIndex -gt $postCommitIndex -and
    $order.Contains('CheckoutFailureRecoveryService.RetireRequest(HttpContext.Current, checkoutRequestId)') -and
    ([regex]::Matches($order, 'OrderDurableIdempotencyService\.RecordRetryRequired\s*\(').Count -ge 3)
) '13_POSTCOMMIT_FIRST_AND_FAILED_REQUESTS_RETIRED_DURABLY'

Assert-Source (
    # Zero is the existing missing-method sentinel; negative pickup IDs remain valid.
    $order.Contains('If Vettore = 0 Then') -and
    $order.Contains('CheckoutFailureReason.ShippingMethodMissing') -and
    $order.Contains('If Pagamento <= 0 Then') -and
    $order.Contains('CheckoutFailureReason.PaymentMethodMissing') -and
    $order.IndexOf('Dim completedBeforeWork As OrderDurableIdempotencyRecord', [StringComparison]::Ordinal) -lt
        $order.IndexOf('If Vettore = 0 Then', [StringComparison]::Ordinal)
) '14_ORDER_SIDE_SELECTIONS_FAIL_SPECIFIC_BEFORE_CLAIM'

Assert-Source (
    $order.Contains('checkoutRequestId, "08-storefront-context", "resolved"') -and
    -not $order.Contains('String.Empty, "08-storefront-context", "resolved"') -and
    -not [string]::IsNullOrWhiteSpace($generateToken) -and
    $generateToken.Contains('normalizedRequestId, "08-storefront-context", "resolved"') -and
    -not $generateToken.Contains('ViewState(CHECKOUT_REQUEST_VIEWSTATE_KEY), CultureInfo.InvariantCulture),' + [Environment]::NewLine + '        "08-storefront-context"')
) '15_TRACE_USES_ONE_REQUEST_CORRELATION'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($showFailure) -and
    $showFailure.Contains('SetCheckoutStep("checkout")') -and
    $showFailure.Contains('tOrdine.Visible = True') -and
    $showFailure.Contains('ShowCheckoutSubmitError(failure.Message, False)') -and
    $order.Contains('CheckoutFailureReason.ShippingAddressInvalid') -and
    $order.Contains('CheckoutFailureReason.OrderNotesInvalid') -and
    -not $order.Contains('CheckoutTerminalOutcomeDispatcher.Dispatch(HttpContext.Current, CheckoutTerminalOutcome.AddressError)') -and
    -not $order.Contains('CheckoutTerminalOutcomeDispatcher.Dispatch(HttpContext.Current, CheckoutTerminalOutcome.NotesError)')
) '16_CORRECTION_FAILURE_REOPENS_CHECKOUT_CONTROLS'

$firstLoginRequired = $order.IndexOf('CheckoutTerminalOutcome.LoginRequired', [StringComparison]::Ordinal)
$secondLoginRequired = $order.IndexOf(
    'CheckoutTerminalOutcome.LoginRequired',
    $firstLoginRequired + 1,
    [StringComparison]::Ordinal)
$firstExtract = $order.LastIndexOf(
    'TryExtractCheckoutRequestIdForRetirement',
    $firstLoginRequired,
    [StringComparison]::Ordinal)
$secondExtract = $order.LastIndexOf(
    'TryExtractCheckoutRequestIdForRetirement',
    $secondLoginRequired,
    [StringComparison]::Ordinal)
Assert-Source (
    $order.Contains('Private Function TryExtractCheckoutRequestIdForRetirement') -and
    $firstLoginRequired -ge 0 -and $secondLoginRequired -gt $firstLoginRequired -and
    $firstExtract -ge 0 -and $firstExtract -lt $firstLoginRequired -and
    $secondExtract -gt $firstLoginRequired -and $secondExtract -lt $secondLoginRequired -and
    ([regex]::Matches($order, 'RetireRequest\(HttpContext\.Current,\s*(?:expiredRequestId|invalidIdentityRequestId)\)').Count -eq 2)
) '17_LOGIN_TIMEOUT_AND_PARTIAL_IDENTITY_RETIRE_OLD_REQUEST'

$completedLookupIndex = $order.IndexOf('Dim completedBeforeWork As OrderDurableIdempotencyRecord', [StringComparison]::Ordinal)
$notesValidationIndex = $order.IndexOf('If OrderNotesAreTooLong(Note) Then', [StringComparison]::Ordinal)
$claimIndex = $order.IndexOf('OrderDurableIdempotencyService.TryClaim(', [StringComparison]::Ordinal)
Assert-Source (
    $completedLookupIndex -ge 0 -and
    $notesValidationIndex -gt $completedLookupIndex -and
    $claimIndex -gt $notesValidationIndex
) '18_COMPLETED_REPLAY_PRECEDES_SESSION_VALIDATION_AND_NEW_CLAIM'

Assert-Source (
    -not $recovery.Contains('MaxRetiredRequestIds') -and
    -not $recovery.Contains('RemoveAt(0)') -and
    $recovery.Contains('ids.Add(normalized)')
) '19_RETIRED_REQUESTS_ARE_NOT_REACTIVATED_BY_EVICTION'

$invalidTokenBranch = Get-VbMethod $order 'Private Function TryExtractCheckoutRequestIdForRetirement'
Assert-Source (
    -not [string]::IsNullOrWhiteSpace($invalidTokenBranch) -and
    $invalidTokenBranch.Contains('MachineKey.Unprotect') -and
    $invalidTokenBranch.Contains('parts.Length <> 8') -and
    $invalidTokenBranch.Contains('"v4"') -and
    $order.Contains('RetireRequest(HttpContext.Current, invalidTokenRequestId)')
) '20_INVALID_AUTHENTIC_TOKEN_IS_RETIRED_BEFORE_CART_REVIEW'

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" $logicalResolverPath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'CHECKOUT_FAILURE_RECOVERY_HARNESS_COMPILE_FAILED' }

    $harnessOutput = @(& $executable 2>&1 | ForEach-Object { $_.ToString() })
    $harnessExit = $LASTEXITCODE
    $harnessOutput | Write-Output
    if ($harnessExit -ne 0) { throw 'CHECKOUT_FAILURE_RECOVERY_HARNESS_FAILED' }

    $scenarioPasses = @($harnessOutput | Where-Object { $_ -match '^PASS\s+\d{2}_' })
    if ($scenarioPasses.Count -ne 20) {
        throw ('CHECKOUT_FAILURE_RECOVERY_EXPECTED_20_SCENARIOS_ACTUAL_' + $scenarioPasses.Count)
    }
    if (@($harnessOutput | Where-Object { $_ -match '^FAIL\s+' }).Count -ne 0) {
        throw 'CHECKOUT_FAILURE_RECOVERY_REPORTED_FAILURE'
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = (Resolve-Path -LiteralPath $tempRoot).Path
        $allowedRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $resolvedTemp.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'UNSAFE_TEMP_CLEANUP_PATH'
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'PASS CHECKOUT_FAILURE_RECOVERY_20_COMPILED_SCENARIOS'
