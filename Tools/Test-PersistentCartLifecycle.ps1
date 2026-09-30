[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ScratchConfigPath)
$ErrorActionPreference='Stop';$repo=Split-Path -Parent $PSScriptRoot
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testDir=Join-Path $tempBase ('KeepStoreLifecycleHarness-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir|Out-Null
try{
 foreach($dll in Get-ChildItem -LiteralPath (Join-Path $repo 'Bin') -Filter '*.dll' -File){Copy-Item -LiteralPath $dll.FullName -Destination $testDir}
 $exe=Join-Path $testDir 'LifecycleHarness.exe'
 & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe /main:PersistentCartLifecycleHarness "/out:$exe" /r:System.dll /r:System.Web.dll /r:System.Data.dll /r:System.Configuration.dll "/r:$(Join-Path $testDir 'MySql.Data.dll')" `
  (Join-Path $repo 'App_Code\CartStorefrontScopePolicy.vb') (Join-Path $repo 'App_Code\CartMutationIdempotencyService.vb') `
  (Join-Path $repo 'App_Code\PersistentAnonymousCartOwnerService.vb') (Join-Path $repo 'App_Code\PersistentAnonymousCartMutationActivation.vb') `
  (Join-Path $repo 'App_Code\PersistentAnonymousCartLifecycleService.vb') (Join-Path $repo 'App_Code\CartTransactionRetryPolicy.vb') `
  (Join-Path $PSScriptRoot 'PersistentCartMutationActivationHarness.vb') (Join-Path $PSScriptRoot 'PersistentCartLifecycleHarness.vb')
 if($LASTEXITCODE -ne 0){throw 'LIFECYCLE_HARNESS_COMPILE_FAILED'}
 [xml]$x=Get-Content -LiteralPath $ScratchConfigPath -Raw
 if(@($x.configuration.connectionStrings.add).Count -ne 1){throw 'SCRATCH_SINGLE_CONNECTION_REQUIRED'}
 $cs=[string]$x.configuration.connectionStrings.add.connectionString
 # Only stdin; no credentials in process arguments, copied config, or logs.
 $cs | & $exe
 if($LASTEXITCODE -ne 0){throw 'LIFECYCLE_HARNESS_FAILED'}
 $mutation=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\CartMutationService.vb'))
 $life=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\PersistentAnonymousCartLifecycleService.vb'))
 $activation=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\PersistentAnonymousCartMutationActivation.vb'))
 $owner=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\CartStorefrontOwnerContext.vb'))
 foreach($call in @('Prepare\(ctx\)','BeginAttempt\(ctx, conn, transaction, lifecycle\)','Apply\(ctx, conn, transaction, lifecycle, lifecycleBefore\)','FinalizeExecution\(ctx, lifecycle, execution.Status\)')){
  if([regex]::Matches($mutation,'PersistentAnonymousCartLifecycleService\.'+$call).Count -ne 4){throw 'LIFECYCLE_TRANSACTION_BOUNDARY_MISSING'}
 }
 if([regex]::Matches($mutation,'BeginAttempt\(ctx, conn, transaction, lifecycle\)[\s\S]*?ResolveOwnerContext').Count -ne 4){throw 'REGISTRY_GATE_MUST_PRECEDE_MUTATION_OWNER_ROWS'}
 if($activation -match 'DateTime.UtcNow' -or $life -match 'DateTime.UtcNow' -or $activation -notmatch 'SELECT UTC_TIMESTAMP\(6\)'){throw 'DB_CLOCK_CONTRACT_FAILED'}
 if($life -notmatch 'FOR UPDATE' -or $life -notmatch 'expiry <= candidate.DatabaseUtc' -or $life -notmatch 'command.ExecuteNonQuery\(\) <> 1'){throw 'REGISTRY_LOCK_AND_UPDATE_CONTRACT_FAILED'}
 if($owner -notmatch 'PersistentAnonymousCartLifecycleService.HandleReadResolution\(context, persistent\)'){throw 'STALE_COOKIE_CLEANUP_NOT_CONNECTED'}
 if($life -match '(?i)\.Domain\s*=|Session\s*\([^)]*\)\s*=|KeepStoreLog\.|Trace\.|ViewState|Request.QueryString'){throw 'LIFECYCLE_SECRET_OR_COOKIE_BOUNDARY_VIOLATION'}
 Write-Output 'PASS ALL_MUTATION_PATHS_SHARE_REGISTRY_GATE_SNAPSHOT_AND_FINALIZATION'
 Write-Output 'PASS DB_CLOCK_ONLY_AND_SCOPED_REGISTRY_LOCK'
 Write-Output 'PASS RUNTIME_STALE_CLEANUP_CONNECTION_NO_SECRET_PERSISTENCE'
}finally{
 $cs=$null;$x=$null
 $resolved=[IO.Path]::GetFullPath($testDir)
 if(-not $resolved.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'UNSAFE_HARNESS_CLEANUP'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
