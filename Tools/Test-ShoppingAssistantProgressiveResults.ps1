[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PlaywrightModulePath,
    [Parameter(Mandatory=$true)][string]$BrowserExecutable,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [switch]$CatalogHandoffOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'WINDOWS_POWERSHELL_51_REQUIRED'}
$root=Split-Path -Parent $PSScriptRoot
$output=[IO.Path]::GetFullPath($EvidenceDirectory)
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if(-not $output.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or $output -eq $tempBase.TrimEnd('\')){throw 'EVIDENCE_MUST_BE_SCOPED_TEMP_DIRECTORY'}
if(-not (Test-Path -LiteralPath $PlaywrightModulePath) -or -not (Test-Path -LiteralPath $BrowserExecutable)){throw 'EXISTING_BROWSER_RUNTIME_REQUIRED_NO_INSTALL'}
[void][IO.Directory]::CreateDirectory($output)
$payload=Join-Path $output 'server-payloads.json'
$serverLog=Join-Path $output 'server-tests.log'
if($CatalogHandoffOnly){
    # Compile the actual URL builder; System.Web performs real query decoding and URL encoding.
    # The resolved sector is an input attested by the unchanged taxonomy contract, not a database fixture.
    Add-Type -AssemblyName System.Web
    $source=Get-Content -LiteralPath (Join-Path $root 'articoli.aspx.vb') -Raw
    $method=[regex]::Match($source,'(?ms)^    Private Shared Function BuildCatalogGuideHandoffUrl\(.*?^    End Function').Value
    if(-not $method -or $source -notmatch 'If\(taxonomy IsNot Nothing AndAlso taxonomy.IsCoherent, taxonomy.SectorId, 0\)'){throw 'HANDOFF_REAL_SOURCE_MISSING'}
    $code=@"
Imports System
Imports System.Text
Imports System.Web
Imports System.Text.RegularExpressions
Imports System.Globalization
Public Class CatalogHandoffSourceHarness
$($method.Replace('Private Shared Function','Public Shared Function'))
End Class
"@
    Add-Type -TypeDefinition $code -Language VisualBasic -ReferencedAssemblies @('System.dll','System.Web.dll')
    $cases=@(
        @{name='Tech-root';raw='q=SSD+1+TB&st=7';sector=7;q='SSD 1 TB';st='7';home='/Default.aspx'},
        @{name='Tech-virtual';raw='q=SSD+1+TB&st=7';sector=7;q='SSD 1 TB';st='7';home='/shop/Default.aspx'},
        @{name='Food-root';raw='q=olio+da+1+litro&st=7';sector=7;q='olio da 1 litro';st='7';home='/Default.aspx'},
        @{name='Food-virtual';raw='q=olio+da+1+litro&st=7';sector=7;q='olio da 1 litro';st='7';home='/shop/Default.aspx'},
        @{name='normalized';raw='q=++SSD++1+++TB++';sector=0;q='SSD 1 TB';st=$null},
        @{name='unicode-nfc';raw='q=caffe%CC%80';sector=0;q="caff$([char]0x00e8)";st=$null},
        @{name='encoded-query';raw='q=SSD+%26+USB%2BC';sector=0;q='SSD & USB+C';st=$null},
        @{name='max80';raw=('q='+('x'*80));sector=0;q=('x'*80);st=$null},
        @{name='no-query';raw='st=7';sector=7},
        @{name='empty';raw='q=';sector=0},
        @{name='whitespace';raw='q=+++';sector=0},
        @{name='short';raw='q=x';sector=0},
        @{name='over80';raw=('q='+('x'*81));sector=0},
        @{name='duplicate-query';raw='q=SSD&q=Olio';sector=7},
        @{name='duplicate-query-case';raw='q=SSD&Q=Olio';sector=7},
        @{name='duplicate-sector';raw='q=SSD&st=7&st=7';sector=7},
        @{name='empty-sector';raw='q=SSD&st=';sector=0},
        @{name='zero-sector';raw='q=SSD&st=0';sector=0},
        @{name='negative-sector';raw='q=SSD&st=-7';sector=7},
        @{name='noncanonical-sector';raw='q=SSD&st=07';sector=7},
        @{name='overflow-sector';raw='q=SSD&st=2147483648';sector=7},
        @{name='unknown-sector';raw='q=SSD&st=99';sector=0},
        @{name='incoherent-sector';raw='q=SSD&st=7';sector=0},
        @{name='bare-sector';raw='q=SSD&st';sector=0},
        @{name='malformed-escape';raw='q=SSD%zz';sector=0},
        @{name='invalid-utf8';raw='q=SSD%ff';sector=0},
        @{name='control';raw='q=SSD%00x';sector=0},
        @{name='private-not-forwarded';raw='q=SSD&st=7&listino=99&owner=private&IVA=0';sector=7;q='SSD';st='7'},
        @{name='html-as-text';raw='q=%3Cimg+src%3Dx%3E';sector=0;q='<img src=x>';st=$null}
    )
    $results=@(foreach($case in $cases){
        $targetHome=if($case.ContainsKey('home')){$case.home}else{'/Default.aspx'}
        $request=New-Object System.Web.HttpRequest('', 'https://fixture.invalid/shop/articoli.aspx', $case.raw)
        # An unhosted HttpRequest uses the process ANSI codepage; use the UTF-8 parser
        # configured by web.config.example. RawUrl still comes from the real request object.
        $values=[Web.HttpUtility]::ParseQueryString($case.raw,[Text.Encoding]::UTF8)
        $url=[CatalogHandoffSourceHarness]::BuildCatalogGuideHandoffUrl($targetHome,$values,$case.sector,$request.RawUrl)
        $expected=$targetHome+'#KsLocalAiSearch130'
        if($case.ContainsKey('q')){
            $expected=$targetHome+'?guide=catalog-v1&guide_q='+[Web.HttpUtility]::UrlEncode($case.q)
            if($case.st){$expected+='&guide_st='+$case.st}
            $expected+='#KsLocalAiSearch130'
        }
        if($url -cne $expected){throw ('HANDOFF_URL_FAILED '+$case.name)}
        [pscustomobject]@{name=$case.name;url=$url;expectedQuery=$(if($case.ContainsKey('q')){$case.q}else{$null});status='PASS'}
    })
    [pscustomobject]@{assertions=$results.Count;cases=$results;mode='VERBATIM_VB_SYSTEM_WEB_NO_DATABASE';sourceSha256=(Get-FileHash -LiteralPath (Join-Path $root 'articoli.aspx.vb')).Hash}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $payload -Encoding UTF8
    Write-Output ('CATALOG_HANDOFF_SERVER=PASS; ASSERTIONS='+$results.Count)
}else{
    & (Join-Path $PSScriptRoot 'Test-SearchSuggestCommercialContext.ps1') -GuidedPayloadPath $payload *> $serverLog
    if(-not (Select-String -LiteralPath $serverLog -Pattern '^SEARCH_SUGGEST_SYNTHETIC_SUITE=PASS$' -Quiet)){throw 'COMMERCIAL_CONTRACT_SUITE_FAILED'}
}
$node=(Get-Command node -CommandType Application -ErrorAction Stop).Source
if($CatalogHandoffOnly){
    & $node (Join-Path $PSScriptRoot 'ShoppingAssistantProgressiveResults.test.js') $root $PlaywrightModulePath $BrowserExecutable $output $payload --catalog-handoff-only
}else{
    & $node (Join-Path $PSScriptRoot 'ShoppingAssistantProgressiveResults.test.js') $root $PlaywrightModulePath $BrowserExecutable $output $payload
}
if($LASTEXITCODE -ne 0){throw 'PROGRESSIVE_BROWSER_SUITE_FAILED'}
$journal=Get-Content -LiteralPath (Join-Path $output 'resource-journal.json') -Raw | ConvertFrom-Json
if(-not $journal.browserClosed){throw 'BROWSER_CLEANUP_NOT_ATTESTED'}
Write-Output 'SHOPPING_PROGRESSIVE_SUITE=PASS; HTTP_UPSTREAM=0; DATABASE_CONNECTIONS=0'
Write-Output 'OWN_BROWSER_CONTEXTS_CLOSED=PASS; EVIDENCE_RETAINED=YES; NO_SERVICE_STARTED'
