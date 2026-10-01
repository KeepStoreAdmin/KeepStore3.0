[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ScratchConfigPath)
$ErrorActionPreference='Stop';$repo=Split-Path -Parent $PSScriptRoot
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$work=Join-Path $tempBase ('KeepStoreCleanupHarness-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work|Out-Null
try{
    foreach($dll in Get-ChildItem -LiteralPath (Join-Path $repo 'Bin') -Filter '*.dll' -File){Copy-Item -LiteralPath $dll.FullName -Destination $work}
    $exe=Join-Path $work 'CleanupHarness.exe'
    $sources=@('App_Code\PersistentAnonymousCartCleanupService.vb','App_Code\CartTransactionRetryPolicy.vb','Tools\PersistentCartRegistryCleanupHarness.vb')|ForEach-Object{Join-Path $repo $_}
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$exe" /r:System.dll /r:System.Web.dll /r:System.Data.dll "/r:$(Join-Path $work 'MySql.Data.dll')" $sources
    if($LASTEXITCODE -ne 0){throw 'CLEANUP_HARNESS_COMPILE_FAILED'}
    [xml]$config=Get-Content -LiteralPath $ScratchConfigPath -Raw
    $setting=@($config.configuration.connectionStrings.add|Where-Object{$_.name -eq 'EntropicConnectionString'})
    if($setting.Count -ne 1){throw 'SCRATCH_CONFIG_INVALID'}
    $cs=[string]$setting[0].connectionString
    $cs | & $exe
    if($LASTEXITCODE -ne 0){throw 'CLEANUP_HARNESS_FAILED'}
    $source=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\PersistentAnonymousCartCleanupService.vb'))
    if($source -notmatch 'TABLE_SCHEMA=DATABASE\(\)' -or $source -notmatch 'COALESCE\(LoginId,0\)<=0 AND BINARY SessionId=@owner' -or $source -notmatch 'UTC_TIMESTAMP\(6\)'){throw 'CLEANUP_SCOPE_GUARD_FAILED'}
    if($source -match 'Request\.|Response\.|Cookies|Session\(|ViewState|ex.Message|SIGNAL|CREATE TABLE|DROP TABLE'){throw 'CLEANUP_RUNTIME_OR_FAULT_HOOK_FOUND'}
    if($source -notmatch 'CartTransactionRetryPolicy.Execute' -or $source -notmatch 'FOR UPDATE' -or $source -notmatch 'Order BY id FOR UPDATE'){throw 'CLEANUP_TRANSACTION_BOUNDARY_FAILED'}
    Write-Output 'PASS CLEANUP_DATABASE_COMPANY_OWNER_AND_UTC_BOUNDARY'
    Write-Output 'PASS NO_RUNTIME_ENTRYPOINT_OR_TEST_FAULT_HOOK'
    Write-Output 'PASS SHARED_RETRY_AND_REGISTRY_CART_LOCK_ORDER'
}finally{
    $cs=$null;$setting=$null;$config=$null
    $resolved=[IO.Path]::GetFullPath($work)
    if(-not $resolved.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'UNSAFE_HARNESS_CLEANUP'}
    if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
