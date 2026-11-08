[CmdletBinding()]
param([string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceDirectory,
      [string]$PlaywrightModule,[string]$ChromeExecutable)
$ErrorActionPreference='Stop'
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
if(!$EvidenceDirectory.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path $EvidenceDirectory)){throw 'NEW_TEMP_EVIDENCE_REQUIRED'}
[void][IO.Directory]::CreateDirectory($EvidenceDirectory)
$utf=New-Object Text.UTF8Encoding($false)
function ReadSource($p){[IO.File]::ReadAllText((Join-Path $RepositoryRoot $p))}
function Method($s,$n){$m=[regex]::Match($s,'(?ms)^    (?:(?:Private|Public|Protected) )?(?:Shared )?(?:Function|Sub) '+$n+'\b.*?^    End (?:Function|Sub)');if(!$m.Success){throw ('METHOD_MISSING '+$n)};return $m.Value.Replace('Private Function','Public Function')}
$page=ReadSource 'articoli.aspx.vb';$theme=ReadSource 'App_Code/ThemeManager.vb'
$methods=@('BuildCatalogCategoryUrl','TryReadPromotionCampaignId','GetSafeReturnUrl','ParseUrlQuery','BuildUrlWithQuery','changeUrlGetParam','RemoveActiveFilterFromUrl','ClearCatalogFiltersFromUrl','BuildCatalogDealsToggleUrl','BuildCatalogRefurbishedToggleUrl','BuildCatalogPriceRangeUrl','BuildCatalogPageUrl')|ForEach-Object{Method $page $_}
$themeMethods=@('CatalogFilterUrlById','CatalogResultsUrl','HtmlAttr','SafeCurrentPathAndQuery','CleanFilterKey','CleanIdPart')|ForEach-Object{Method $theme $_}
$vb=@'
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Script.Serialization
Public Module ThemeManager
@@THEME@@
End Module
Public Class DecodedRequestFixture
 Public QueryString As Collections.Specialized.NameValueCollection
 Public Url As Uri
End Class
Public Module RequestInput
 Public Current As DecodedRequestFixture
End Module
Public Class PageFixture
 Public ReadOnly Property Request As DecodedRequestFixture
  Get
   Return RequestInput.Current
  End Get
 End Property
@@PAGE@@
End Class
Module Cases
 Dim checks As Integer
 Sub Check(ok As Boolean,label As String)
  If Not ok Then Throw New Exception(label)
  checks+=1
 End Sub
 Sub SetRequest(q As String,Optional path As String="/articoli.aspx")
  Dim request As New HttpRequest("","https://fixture.invalid"+path+"?"+q,q)
  request.ContentEncoding=Text.Encoding.UTF8
  HttpContext.Current=New HttpContext(request,New HttpResponse(New IO.StringWriter))
  RequestInput.Current=New DecodedRequestFixture With {.Url=New Uri("https://fixture.invalid"+path+"?"+q),.QueryString=HttpUtility.ParseQueryString(q,Text.Encoding.UTF8)}
 End Sub
 Sub Main(args As String())
  Try
  Dim f As New PageFixture
  For Each path In New String(){"/articoli.aspx","/store/articoli.aspx"}
   For Each value In New String(){"notebook","caffe e te","caff"+ChrW(232)+" qualit"+ChrW(224),"& + % # "" ' < > |",New String("x"c,80),"  ricerca con spazi  "}
    SetRequest("q="+HttpUtility.UrlEncode(value)+"&st=1&ct=2&mr=1%7C7&pg=5&inpromo=1&pid=9",path)
    Dim url=f.BuildCatalogCategoryUrl(3,4),q=HttpUtility.ParseQueryString(url.Substring(url.IndexOf("?"c)+1))
    Check(q("q")=value,"search roundtrip: "+value+" -> "+q("q")+" input="+f.Request.QueryString("q")+" URL="+url):Check(q.GetValues("q").Length=1,"one q")
    Check(q("st")="3" AndAlso q("ct")="4" AndAlso q("inpromo")="1" AndAlso q("pid")="9","taxonomy/promo")
    Check(q("mr") Is Nothing AndAlso q("pg") Is Nothing AndAlso Not url.Contains("#"),"no stale facet/page/anchor")
    Check(Not url.Contains("<") AndAlso Not url.Contains("""") AndAlso Not url.Contains("'"),"URL safe before HTML encoding")
   Next
   For Each value In New String(){""," ",vbTab}
    SetRequest("q="+HttpUtility.UrlEncode(value),path):Check(f.BuildCatalogCategoryUrl(3,4)="articoli.aspx?st=3&ct=4","empty search unchanged")
   Next
   SetRequest("q=word&inpromo=1&pid=bad",path):Check(Not f.BuildCatalogCategoryUrl(3,0).Contains("pid="),"invalid campaign unchanged")
   For Each key In New String(){"mr","tp","gr","sg"}
    SetRequest(key+"=1&pg=5&q=x",path)
    Dim added=HttpUtility.HtmlDecode(ThemeManager.CatalogFilterUrlById(key,"7")),u As New Uri("https://fixture.invalid"+added),q=HttpUtility.ParseQueryString(u.Query)
    Check(q(key)="1|7" AndAlso q("pg") Is Nothing,"multiselect add/page reset")
    Check(u.Fragment="#ksCatalogResults" AndAlso u.AbsolutePath=path,"native anchor/virtual path")
    SetRequest(u.Query.TrimStart("?"c),path)
    Dim removed=HttpUtility.HtmlDecode(ThemeManager.CatalogFilterUrlById(key,"1"))
    Check(HttpUtility.ParseQueryString(New Uri("https://fixture.invalid"+removed).Query)(key)="7","multiselect remove")
    Check(ThemeManager.CatalogResultsUrl(removed)=removed,"anchor idempotent")
   Next
   SetRequest("q=word&mr=1%7C7&pg=3&inpromo=1&pid=9",path)
   Dim current=HttpContext.Current.Request.Url.AbsoluteUri
   Check(f.ClearCatalogFiltersFromUrl(current).IndexOf("q=")<0 AndAlso Not f.ClearCatalogFiltersFromUrl(current).Contains("#"),"clear removes q no anchor")
   Check(Not f.BuildCatalogPageUrl(2).Contains("#"),"paging no anchor")
   Dim chip=ThemeManager.CatalogResultsUrl(f.RemoveActiveFilterFromUrl(current,"mr=1"))
   Check(HttpUtility.ParseQueryString(New Uri(chip).Query)("mr")="7" AndAlso New Uri(chip).Fragment="#ksCatalogResults","single chip")
   For Each url In New String(){f.BuildCatalogDealsToggleUrl(current,True),f.BuildCatalogDealsToggleUrl(current,False),f.BuildCatalogRefurbishedToggleUrl(current,True),f.BuildCatalogRefurbishedToggleUrl(current,False),f.BuildCatalogPriceRangeUrl("9","11"),f.changeUrlGetParam(current,"disponibile","1")}
    Dim anchored=ThemeManager.CatalogResultsUrl(url)
    Dim anchoredUri As New Uri(New Uri("https://fixture.invalid"),anchored),plainUri As New Uri(New Uri("https://fixture.invalid"),url)
    Check(anchoredUri.Query=plainUri.Query AndAlso anchoredUri.Fragment="#ksCatalogResults","server params unchanged")
   Next
  Next
  Check(ThemeManager.CatalogResultsUrl("articoli.aspx?q=a%23b#old")="articoli.aspx?q=a%23b#ksCatalogResults","replace fragment not encoded hash")
  IO.File.WriteAllText(args(0),New JavaScriptSerializer().Serialize(New With {.checks=checks,.result="PASS compiled SOURCE",.iis="NOT EXECUTED",.mysql="NOT EXECUTED"}))
  Console.WriteLine("CATALOG_SEARCH_CONTEXT_PASS="+checks.ToString())
  Catch ex As Exception
   Console.Error.WriteLine(ex.ToString()):Environment.ExitCode=1
  End Try
 End Sub
End Module
'@
$file=Join-Path $EvidenceDirectory 'Cases.vb';$exe=Join-Path $EvidenceDirectory 'Cases.exe'
[IO.File]::WriteAllText($file,$vb.Replace('@@PAGE@@',($methods -join "`n")).Replace('@@THEME@@',($themeMethods -join "`n")),$utf)
$compiler=Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$output=@(& $compiler /nologo /optioninfer+ /target:exe /main:Cases ("/out:"+$exe) /r:System.dll,System.Core.dll,System.Web.dll,System.Web.Extensions.dll $file 2>&1)
$output|Set-Content (Join-Path $EvidenceDirectory 'compile.log');if($LASTEXITCODE){throw 'COMPILE_FAILED'}
[IO.File]::WriteAllText(($exe+'.config'),'<configuration><system.web><globalization requestEncoding="utf-8" responseEncoding="utf-8" fileEncoding="utf-8" /></system.web></configuration>',$utf)
& $exe (Join-Path $EvidenceDirectory 'result.json');if($LASTEXITCODE){throw 'CASES_FAILED'}
# Call-site guards: shared redirect, reset, normalization, pager and PDP stay unmodified.
$base=(@(git -C $RepositoryRoot show '514919b1d4e65076c799f1a0e32678cc00081169:articoli.aspx.vb') -join "`n")
foreach($name in @('RedirectIfChanged','NormalizeCatalogPromotionNavigation','SyncCatalogPriceRangeNavigation','ClearCatalogFiltersFromUrl','BuildCatalogPageUrl')){
 if((Method $base $name).Replace("`r`n","`n").Trim() -cne (Method $page $name).Replace("`r`n","`n").Trim()){throw ('EXCLUDED_METHOD_CHANGED '+$name)}
}
if([regex]::Matches((ReadSource 'articoli.aspx'),'id="ksCatalogResults"').Count -ne 1){throw 'TARGET_NOT_UNIQUE'}
foreach($line in @('RedirectIfChanged(newUrl, False)','RedirectIfChanged(cleanAnchorUrl)','RedirectIfChanged(resetPageUrl, False)','RedirectIfChanged(ClearCatalogFiltersFromUrl(GetSafeReturnUrl()))')){if(!$page.Contains($line)){throw ('EXCLUDED_CALL_CHANGED '+$line)}}
'PASS SOURCE excluded-navigation guards'
if((Method $base 'CaricaArticoli').Replace("`r`n","`n").Trim() -cne (Method $page 'CaricaArticoli').Replace("`r`n","`n").Trim()){throw 'COMMERCIAL_QUERY_OR_FACET_CHANGED'}
foreach($name in @('CheckBoxFilter_CheckedChanged','Drop_Ordinamento_SelectedIndexChanged','Drop_Filtra_Taglia_SelectedIndexChanged','Drop_Filtra_Colore_SelectedIndexChanged','CheckBox_Disponibile_CheckedChanged','btnCatalogPriceApply_Click','rptActiveFilters_ItemCommand','AddActiveFilter','BindActiveFilters')){
 if(!(Method $page $name).Contains('ThemeManager.CatalogResultsUrl(')){throw ('FILTER_CALLSITE_MISSING '+$name)}
}
if(!$PlaywrightModule -or !$ChromeExecutable){'BROWSER_NON_ESEGUITO: explicit existing Playwright module and Chrome required';return}
$browser=@'
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [root,modulePath,chrome,out]=process.argv.slice(2),pw=require(modulePath);
(async()=>{const browser=await pw.chromium.launch({executablePath:chrome,headless:true});let checks=0;
try{for(const width of [390,1365]){const context=await browser.newContext({viewport:{width,height:900},javaScriptEnabled:false});
const requests=[];const css=fs.readFileSync(path.join(root,'Public/assets/keepstore/css/catalog-product-flow.css'),'utf8');
const source=fs.readFileSync(path.join(root,'articoli.aspx'),'utf8');assert.equal((source.match(/id="ksCatalogResults"/g)||[]).length,1);
// Presentation fixture only: fixed header modeled at 120px, not the IIS master.
const html=`<!doctype html><meta charset="utf-8"><style>${css}body{margin:0}main{padding-top:150px}header{position:fixed;top:0;height:120px;background:white;width:100%;z-index:10}.spacer{height:1200px}.after{height:1600px}</style><header>Testata sintetica</header><main id="ksCatalogPage"><a id="filter" href="/articoli.aspx?mr=1%7C7#ksCatalogResults">Filtra</a><div class="spacer"></div><div id="ksCatalogResults" class="tf-shop-control flex-wrap gap-10">Risultati catalogo</div><div class="after"></div></main>`;
await context.route('**/*',route=>{requests.push(route.request().url());return route.fulfill({contentType:'text/html',body:html});});
const page=await context.newPage();await page.goto('https://fixture.invalid/articoli.aspx');await page.locator('#filter').click();
await page.waitForURL('**/*#ksCatalogResults');const bounds=await page.locator('#ksCatalogResults').boundingBox();
assert(bounds.y>=120&&bounds.y<900);checks++;assert(requests.every(url=>!url.includes('#')));checks++;
assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);checks++;
await page.screenshot({path:path.join(out,'anchor-'+width+'.png')});await context.close();}
fs.writeFileSync(path.join(out,'browser.json'),JSON.stringify({result:'PASS presentation Chrome no-JS',checks,viewports:[390,1365],limitations:'Modeled fixed header only; not full WebForms/IIS/master or MySQL runtime'},null,2));
console.log('CHROME_PRESENTATION_PASS='+checks);
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
'@
$browserFile=Join-Path $EvidenceDirectory 'browser.cjs';[IO.File]::WriteAllText($browserFile,$browser,$utf)
& node $browserFile $RepositoryRoot $PlaywrightModule $ChromeExecutable $EvidenceDirectory
if($LASTEXITCODE){throw 'BROWSER_PRESENTATION_FAILED'}
