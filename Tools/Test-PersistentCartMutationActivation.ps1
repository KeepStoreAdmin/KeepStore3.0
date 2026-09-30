[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ScratchConfigPath)
$ErrorActionPreference='Stop';$repo=Split-Path -Parent $PSScriptRoot
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testDir=Join-Path $tempBase ('KeepStoreActivationHarness-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir|Out-Null
try{
 foreach($dll in Get-ChildItem -LiteralPath (Join-Path $repo 'Bin') -Filter '*.dll' -File){Copy-Item -LiteralPath $dll.FullName -Destination $testDir}
 $exe=Join-Path $testDir 'ActivationHarness.exe'
 & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$exe" /r:System.dll /r:System.Web.dll /r:System.Data.dll /r:System.Configuration.dll "/r:$(Join-Path $testDir 'MySql.Data.dll')" `
  (Join-Path $repo 'App_Code\CartStorefrontScopePolicy.vb') (Join-Path $repo 'App_Code\CartMutationIdempotencyService.vb') `
  (Join-Path $repo 'App_Code\PersistentAnonymousCartOwnerService.vb') (Join-Path $repo 'App_Code\PersistentAnonymousCartMutationActivation.vb') `
  (Join-Path $repo 'App_Code\CartTransactionRetryPolicy.vb') (Join-Path $PSScriptRoot 'PersistentCartMutationActivationHarness.vb')
 if($LASTEXITCODE -ne 0){throw 'ACTIVATION_HARNESS_COMPILE_FAILED'}
 [xml]$x=Get-Content -LiteralPath $ScratchConfigPath -Raw
 if(@($x.configuration.connectionStrings.add).Count -ne 1){throw 'SCRATCH_SINGLE_CONNECTION_REQUIRED'}
 $cs=[string]$x.configuration.connectionStrings.add.connectionString
 # Configuration flows over stdin, never an argument, log, or copied config file.
 $cs | & $exe
 if($LASTEXITCODE -ne 0){throw 'ACTIVATION_HARNESS_FAILED'}
 $mutation=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\CartMutationService.vb'))
 $activation=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\PersistentAnonymousCartMutationActivation.vb'))
 if([regex]::Matches($mutation,'Dim activation As PersistentCartActivationCandidate').Count -ne 4 -or
    [regex]::Matches($mutation,'PublishAfterCommit\(ctx, activation, True, activated\)').Count -ne 4){throw 'MUTATION_BOUNDARIES_NOT_ALL_INTEGRATED'}
 if([regex]::Matches($mutation,'Dim activation[\s\S]*?CartTransactionRetryPolicy\.Execute').Count -ne 4){throw 'CANDIDATE_NOT_OUTSIDE_RETRY_BOUNDARIES'}
 if($mutation -notmatch 'If\(clearAll, Nothing, PersistentAnonymousCartMutationActivation\.Prepare\(ctx\)\)'){throw 'CLEAR_MUST_SKIP_ACTIVATION'}
 if($activation -notmatch 'PersistentAnonymousCartOwnerService\.DeriveOwnerToken' -or
    $activation -notmatch 'Array\.Clear\(secret' -or $activation -notmatch 'TryGetCurrentIntentDescriptor' -or
    $activation -notmatch 'AuthorizeAnonymousOwnerTransitionForCurrentIntent'){throw 'SHARED_OWNER_OR_INTENT_CONTRACT_MISSING'}
 if($activation -match '(?i)Session\s*\([^)]*\)\s*=|\.Domain\s*=|KeepStoreLog\.|Trace\.|Request\.QueryString|ViewState|INSERT[\s\S]*?CookieValue[\s\S]*?ExecuteNonQuery'){throw 'ACTIVATION_SECRET_OR_COOKIE_BOUNDARY_VIOLATION'}
 if($activation -match '(?i)CONSUMED''|REVOKED''|SET\s+ExpiresUtc|SET\s+LastActivityUtc'){throw 'LIFECYCLE_OUT_OF_SCOPE'}
 Write-Output 'PASS FOUR_EXISTING_TRANSACTION_BOUNDARIES'
 Write-Output 'PASS CANDIDATE_OUTSIDE_RETRY_CALLBACKS'
 Write-Output 'PASS SHARED_DERIVATION_AND_EXACT_INTENT_DESCRIPTOR'
 Write-Output 'PASS NO_SESSION_LOG_VIEWSTATE_OR_DATABASE_RAW_SECRET'
 Write-Output 'PASS NO_SLIDING_EXPIRY_OR_REVOCATION'
}finally{
 $cs=$null;$x=$null
 $resolved=[IO.Path]::GetFullPath($testDir)
 if(-not $resolved.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'UNSAFE_HARNESS_CLEANUP'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
