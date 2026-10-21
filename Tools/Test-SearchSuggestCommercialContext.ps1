[CmdletBinding()]
param([switch]$BaselineCandidate, [string]$GuidedPayloadPath = '')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'WINDOWS_POWERSHELL_51_REQUIRED'}
$root=Split-Path -Parent $PSScriptRoot
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$work=Join-Path $tempBase ('ks-suggest-commercial-'+[Guid]::NewGuid().ToString('N'))
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$exe=Join-Path $work 'Harness.exe'
$journal=New-Object 'System.Collections.Generic.List[string]'
try {
    [void][IO.Directory]::CreateDirectory($work)
    $journal.Add($exe)
    $journal.Add((Join-Path $work 'resources.json'))
    [IO.File]::WriteAllText((Join-Path $work 'resources.json'),($journal|ConvertTo-Json))
    $references=@('System.dll','System.Core.dll','System.Data.dll','System.Configuration.dll','System.Web.dll','System.Web.Extensions.dll','System.Xml.dll','System.Xml.Linq.dll','System.Drawing.dll','System.Net.Http.dll','System.Runtime.Serialization.dll','System.ServiceModel.dll')
    $args=@('/nologo','/target:exe','/optioninfer+','/main:SearchSuggestCommercialContextHarness',('/out:'+$exe),'/imports:Microsoft.VisualBasic,System,System.Collections,System.Collections.Generic,System.Data,System.Linq,System.Web,System.Configuration')
    foreach($r in $references){$args+=('/reference:'+(Join-Path $framework $r))}
    foreach($r in @(Get-ChildItem -LiteralPath (Join-Path $root 'Bin') -Filter '*.dll' -File)){$args+=('/reference:'+$r.FullName)}
    $args+=@(Get-ChildItem -LiteralPath (Join-Path $root 'App_Code') -Filter '*.vb' -File | Where-Object {-not $BaselineCandidate -or $_.Name -ne 'SearchSuggestCommercialSupport.vb'} | ForEach-Object {$_.FullName})
    if($BaselineCandidate){
        foreach($sourcePath in @('App_Code/SearchSuggestCommercialSupport.vb','search_suggest.aspx.vb')){
            $candidatePath=Join-Path $work ([IO.Path]::GetFileName($sourcePath))
            $candidate=@(& git -C $root show ('c624db0343b4f38b42ba49651c2c503d46a8e837:'+$sourcePath))
            if($LASTEXITCODE -ne 0){throw 'REVIEW_CANDIDATE_UNAVAILABLE'}
            [IO.File]::WriteAllText($candidatePath,($candidate -join [Environment]::NewLine))
            $journal.Add($candidatePath)
            $args+=@($candidatePath)
        }
    }else{$args+=@(Join-Path $root 'search_suggest.aspx.vb')}
    $args+=@(Join-Path $PSScriptRoot 'SearchSuggestCommercialContextHarness.vb')
    $baselinePath=Join-Path $work 'BaselinePromotionCatalog.vb'
    $journal.Add($baselinePath)
    $baseline=@(& git -C $root show '0363e53e:App_Code/StorefrontPromotionCatalogProvider.vb')
    if($LASTEXITCODE -ne 0){throw 'BASELINE_SOURCE_UNAVAILABLE'}
    [IO.File]::WriteAllText($baselinePath,(($baseline -join [Environment]::NewLine).Replace('Public Module StorefrontPromotionCatalogProvider','Public Module SearchSuggestBaselinePromotionCatalogProvider')))
    $args+=@($baselinePath)
    # Use the unchanged master method itself to construct fiscal fixture state.
    # Only page/tenant/carrier I/O prerequisites belong to this synthetic shell.
    $masterSource=[IO.File]::ReadAllText((Join-Path $root 'Page.master.vb'))
    $masterMethod=[regex]::Match($masterSource,'(?ms)^    Public Sub ApplyAuthenticatedPriceDisplayState\(.*?^    End Sub').Value
    if(-not $masterMethod){throw 'MASTER_FISCAL_METHOD_UNAVAILABLE'}
    $masterFixture=@'
Public NotInheritable Class SearchSuggestMasterFiscalFixture
    Private _priceDisplayCompanyId As Integer
    Private _priceDisplayTenantMode As StorefrontVatDisplayMode = StorefrontVatDisplayMode.VatIncluded
    Public Sub New(ByVal company As Integer)
        _priceDisplayCompanyId = company
    End Sub
    Private ReadOnly Property Session As System.Web.SessionState.HttpSessionState
        Get
            Return System.Web.HttpContext.Current.Session
        End Get
    End Property
    Private Sub RequirePriceDisplayTenant()
        If CInt(Session("AziendaID")) <> _priceDisplayCompanyId Then Throw New Exception("Fixture tenant mismatch")
    End Sub
    Private Function CurrentLoginIdSafe() As Integer
        Return StorefrontCommercialIsolationPolicy.PositiveInteger(Session("LoginId"))
    End Function
    Private Function TenantCarrierVatDefault() As Decimal
        Return 0D
    End Function
'@
    $masterPath=Join-Path $work 'MasterFiscalFixture.vb'
    [IO.File]::WriteAllText($masterPath,$masterFixture+[Environment]::NewLine+$masterMethod+[Environment]::NewLine+'End Class')
    $journal.Add($masterPath)
    $args+=@($masterPath)
    # Execute the real header URL functions with a synthetic DOM boundary.
    # No network, DOM runtime or dependency installation is involved.
    $callerScript=@'
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[2], 'utf8');
const names = ['selectedUrlParams','selectedCatalogBase','buildSuggestUrl','safeSearchUrl'];
const snippets = names.map(name => {
  const start = source.indexOf('  function ' + name + '(');
  const end = source.indexOf('\n  function ', start + 3);
  if (start < 0 || end < 0) throw new Error('HEADER_FUNCTION_UNAVAILABLE:' + name);
  return source.slice(start, end);
}).join('\n');
const fixture = { URL, window: { location: new URL('https://tenant2.invalid/Default.aspx') },
  SEARCH_ENDPOINT: '/search_suggest.aspx', selectFromRoot: root => ({value:root.selected}), readMergedRecent: () => [120] };
vm.createContext(fixture);
vm.runInContext(snippets, fixture);
const cases = [
  ['canonical','disponibile=1&pmin=121.995&pmax=122.005&ordinamento=p_basso', 'p_basso'],
  ['legacy','available=1&min=121.995&max=122.005&sort=price-asc', 'p_basso'],
  ['plural','disponibili=1&pmin=121.995&pmax=122.005&ordinamento=p_alto', 'p_alto'],
  ['recent-sort','disponibile=1&ordinamento=p_recenti', 'p_recenti'],
  ['availability-sort','disponibile=1&ordinamento=p_disponibilita', 'p_disponibilita'],
  ['promotion-sort','disponibile=1&ordinamento=p_offerta', 'p_offerta'],
  ['popularity-sort','disponibile=1&ordinamento=p_popolarita', 'p_popolarita'],
  ['equivalent-aliases','disponibile=1&available=1&pmin=121.995&min=121.995&ordinamento=p_basso&sort=price-asc', 'p_basso'],
  ['conflict-availability','disponibile=0&available=1','reject'],
  ['conflict-min','pmin=100&min=90','reject'],
  ['fractional-conflict-min','pmin=121.995&min=122.000','reject'],
  ['conflict-max','pmax=100&max=110','reject'],
  ['conflict-sort','ordinamento=p_basso&sort=price-desc','reject'],
  ['inverted-bounds','pmin=130&pmax=120','reject'],
  ['invalid-availability','disponibile=2','reject'],
  ['invalid-min','pmin=invalid','reject'],
  ['invalid-sort','ordinamento=unknown','reject']
];
const results = cases.map(([name,params,sort]) => ({name,sort,
  url:fixture.buildSuggestUrl({selected:'/articoli.aspx?st=7&'+params}, 'SKU120', 1, false),
  recentUrl:fixture.buildSuggestUrl({selected:'/articoli.aspx?st=7&'+params}, '', 8, true)}));
fs.writeFileSync(process.argv[3],JSON.stringify(results),'utf8');
'@
    $callerScriptPath=Join-Path $work 'HeaderCallerFixture.js'
    $callerUrlsPath=Join-Path $work 'HeaderCallerUrls.json'
    [IO.File]::WriteAllText($callerScriptPath,$callerScript)
    $journal.Add($callerScriptPath)
    $journal.Add($callerUrlsPath)
    $node=(Get-Command node -CommandType Application -ErrorAction Stop).Source
    & $node $callerScriptPath (Join-Path $root 'Public/assets/keepstore/js/ks-page-flags.js') $callerUrlsPath
    if($LASTEXITCODE -ne 0){throw 'HEADER_CALLER_FIXTURE_FAILED'}
    [IO.File]::WriteAllText((Join-Path $work 'resources.json'),($journal|ConvertTo-Json))
    & (Join-Path $framework 'vbc.exe') @args
    if($LASTEXITCODE -ne 0){throw 'SEARCH_SUGGEST_COMPILE_FAILED'}
    foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $root 'Bin') -Filter '*.dll' -File)){
        $destination=Join-Path $work $file.Name
        $journal.Add($destination)
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    [IO.File]::WriteAllText((Join-Path $work 'resources.json'),($journal|ConvertTo-Json))
    if($BaselineCandidate){& $exe $callerUrlsPath '--review-candidate'}elseif($GuidedPayloadPath){& $exe $callerUrlsPath $GuidedPayloadPath}else{& $exe $callerUrlsPath}
    if($LASTEXITCODE -ne 0){throw 'SEARCH_SUGGEST_HARNESS_FAILED'}
    if($BaselineCandidate){Write-Output 'SEARCH_SUGGEST_CANDIDATE_REPRODUCTION=PASS'}else{Write-Output 'SEARCH_SUGGEST_SYNTHETIC_SUITE=PASS'}
} finally {
    if(Test-Path -LiteralPath $work){
        $resolved=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $work).Path)
        if(-not $resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or $resolved -eq $tempBase.TrimEnd('\')){throw 'UNSAFE_CLEANUP'}
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Write-Output 'SEARCH_SUGGEST_OWN_TEMP_CLEANUP=PASS'
}
