<#
.SYNOPSIS
Runs one explicit, bounded cleanup batch for one configured database and company.
.DESCRIPTION
Use Windows PowerShell on the installation/server. Read an existing protected
web.config; do not put a connection string or credential on the command line.
There is no database discovery, public endpoint, or automatic scheduling.
Exit 1 means anomalies/errors require attention; residual terminal rows are kept.
Repeat healthy batches explicitly until CandidatesExamined=0. Scheduling and
the deployment allowlist remain a separate Product Owner decision.
.EXAMPLE
.\Tools\Invoke-PersistentCartRegistryCleanup.ps1 -ConfigPath C:\Site\web.config -CompanyId 1 -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [Parameter(Mandatory=$true)][ValidateRange(1,2147483647)][int]$CompanyId,
    [ValidateRange(1,1000)][int]$BatchSize=100,
    [switch]$Apply
)
$ErrorActionPreference='Stop'
if(-not $Apply){Write-Output 'CLEANUP_APPLY_REQUIRED';exit 2}
$repo=Split-Path -Parent $PSScriptRoot
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$work=Join-Path $tempBase ('KeepStoreCleanupRunner-'+[Guid]::NewGuid().ToString('N'))
$code=2
try{
    [xml]$config=Get-Content -LiteralPath $ConfigPath -Raw
    $setting=@($config.configuration.connectionStrings.add|Where-Object{$_.name -eq 'EntropicConnectionString'})
    if($setting.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$setting[0].connectionString)){throw 'CLEANUP_CONFIG_INVALID'}
    $cs=[string]$setting[0].connectionString
    New-Item -ItemType Directory -Path $work|Out-Null
    foreach($dll in Get-ChildItem -LiteralPath (Join-Path $repo 'Bin') -Filter '*.dll' -File){Copy-Item -LiteralPath $dll.FullName -Destination $work}
    $exe=Join-Path $work 'CleanupRunner.exe'
    $sources=@('App_Code\PersistentAnonymousCartCleanupService.vb','App_Code\CartTransactionRetryPolicy.vb','Tools\PersistentCartCleanupRunner.vb')|ForEach-Object{Join-Path $repo $_}
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$exe" /r:System.dll /r:System.Web.dll /r:System.Data.dll "/r:$(Join-Path $work 'MySql.Data.dll')" $sources
    if($LASTEXITCODE -ne 0){throw 'CLEANUP_RUNNER_COMPILE_FAILED'}
    $cs | & $exe $CompanyId $BatchSize
    $code=$LASTEXITCODE
}catch{
    Write-Output 'CLEANUP_RUNNER_FAILED'
    $code=2
}finally{
    $cs=$null;$setting=$null;$config=$null
    $resolved=[IO.Path]::GetFullPath($work)
    if(-not $resolved.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'UNSAFE_RUNNER_CLEANUP'}
    if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
exit $code
