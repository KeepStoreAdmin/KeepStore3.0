[CmdletBinding()]
param()
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
    $args+=@(Get-ChildItem -LiteralPath (Join-Path $root 'App_Code') -Filter '*.vb' -File | ForEach-Object {$_.FullName})
    $args+=@(Join-Path $root 'search_suggest.aspx.vb')
    $args+=@(Join-Path $PSScriptRoot 'SearchSuggestCommercialContextHarness.vb')
    $baselinePath=Join-Path $work 'BaselinePromotionCatalog.vb'
    $journal.Add($baselinePath)
    $baseline=@(& git -C $root show '0363e53e:App_Code/StorefrontPromotionCatalogProvider.vb')
    if($LASTEXITCODE -ne 0){throw 'BASELINE_SOURCE_UNAVAILABLE'}
    [IO.File]::WriteAllText($baselinePath,(($baseline -join [Environment]::NewLine).Replace('Public Module StorefrontPromotionCatalogProvider','Public Module SearchSuggestBaselinePromotionCatalogProvider')))
    $args+=@($baselinePath)
    & (Join-Path $framework 'vbc.exe') @args
    if($LASTEXITCODE -ne 0){throw 'SEARCH_SUGGEST_COMPILE_FAILED'}
    foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $root 'Bin') -Filter '*.dll' -File)){
        $destination=Join-Path $work $file.Name
        $journal.Add($destination)
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    [IO.File]::WriteAllText((Join-Path $work 'resources.json'),($journal|ConvertTo-Json))
    & $exe
    if($LASTEXITCODE -ne 0){throw 'SEARCH_SUGGEST_HARNESS_FAILED'}
    Write-Output 'SEARCH_SUGGEST_SYNTHETIC_SUITE=PASS'
} finally {
    if(Test-Path -LiteralPath $work){
        $resolved=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $work).Path)
        if(-not $resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or $resolved -eq $tempBase.TrimEnd('\')){throw 'UNSAFE_CLEANUP'}
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Write-Output 'SEARCH_SUGGEST_OWN_TEMP_CLEANUP=PASS'
}
