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
    [regex]::Matches($mutation,'FinalizeExecution\(ctx, activation, execution.Status, activated\)').Count -ne 4){throw 'MUTATION_BOUNDARIES_NOT_ALL_INTEGRATED'}
 if([regex]::Matches($mutation,'Dim activation[\s\S]*?CartTransactionRetryPolicy\.Execute').Count -ne 4){throw 'CANDIDATE_NOT_OUTSIDE_RETRY_BOUNDARIES'}
 if($mutation -notmatch 'If\(clearAll, Nothing, PersistentAnonymousCartMutationActivation\.Prepare\(ctx\)\)'){throw 'CLEAR_MUST_SKIP_ACTIVATION'}
 if($activation -notmatch 'PersistentAnonymousCartOwnerService\.DeriveOwnerToken' -or
    $activation -notmatch 'Array\.Clear\(secret' -or $activation -notmatch 'TryGetCurrentIntentDescriptor' -or
    $activation -notmatch 'AuthorizeAnonymousOwnerTransitionForCurrentIntent'){throw 'SHARED_OWNER_OR_INTENT_CONTRACT_MISSING'}
 if($activation -match '(?i)Session\s*\([^)]*\)\s*=|\.Domain\s*=|KeepStoreLog\.|Trace\.|Request\.QueryString|ViewState|INSERT[\s\S]*?CookieValue[\s\S]*?ExecuteNonQuery'){throw 'ACTIVATION_SECRET_OR_COOKIE_BOUNDARY_VIOLATION'}
 if($activation -match '(?i)CONSUMED''|REVOKED''|SET\s+ExpiresUtc|SET\s+LastActivityUtc'){throw 'LIFECYCLE_OUT_OF_SCOPE'}
 if($activation -match 'DateTime.UtcNow' -or $activation -notmatch 'candidate.CreatedUtc = ReadDatabaseUtc\(connection, transaction\)' -or
    $activation -notmatch 'SELECT UTC_TIMESTAMP\(6\)'){throw 'ACTIVATION_DB_CLOCK_REQUIRED'}
 if($activation -notmatch 'Not context.Response.HeadersWritten' -or $activation -notmatch 'context.Request.IsSecureConnection' -or
    $activation -notmatch 'context.Response IsNot Nothing'){throw 'COOKIE_HEADER_GATE_MISSING'}
 $authorizeAt=$activation.IndexOf('CartMutationIdempotencyService.AuthorizeAnonymousOwnerTransitionForCurrentIntent')
 $stageAt=$activation.IndexOf('StageCookie(context, candidate)')
 $returnAt=$activation.IndexOf('Return True', $stageAt)
 if($authorizeAt -lt 0 -or $stageAt -le $authorizeAt -or $returnAt -le $stageAt){throw 'COOKIE_STAGING_NOT_AFTER_AUTHORIZATION_BEFORE_COMMIT'}
 $finalization=$activation.Substring($activation.IndexOf('Friend Shared Sub FinalizeExecution'),
    $activation.IndexOf('Private Shared Sub RemoveStagedCookie')-$activation.IndexOf('Friend Shared Sub FinalizeExecution'))
 if($finalization -match 'Cookies.Set' -or $activation -match 'PublishAfterCommit' -or
    [regex]::Matches($activation,'Response.Cookies.Set\(').Count -ne 1){throw 'POST_COMMIT_COOKIE_WRITE_FOUND'}
 if($finalization -notmatch 'activated AndAlso candidate IsNot Nothing AndAlso candidate.CookieStaged' -or
    $finalization -notmatch 'MarkCurrentIntentIndeterminate\(context, stagedActivation\)'){throw 'INDETERMINATE_TRANSITION_GATE_MISSING'}
 $resolver=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\PersistentAnonymousCartOwnerService.vb'))
 $owner=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\CartStorefrontOwnerContext.vb'))
 if($resolver -match '(?i)INSERT\s+INTO|UPDATE\s+carrello|DELETE\s+FROM' -or $resolver -notmatch 'PersistentAnonymousCartOwnerState.NOT_FOUND' -or
    $owner -notmatch 'PersistentAnonymousCartOwnerState.ACTIVE' -or $owner -notmatch 'CartStorefrontScopePolicy.BuildAnonymousOwnerToken'){throw 'READ_ONLY_KSC1_FALLBACK_CHANGED'}
 Write-Output 'PASS FOUR_EXISTING_TRANSACTION_BOUNDARIES'
 Write-Output 'PASS CANDIDATE_OUTSIDE_RETRY_CALLBACKS'
 Write-Output 'PASS SHARED_DERIVATION_AND_EXACT_INTENT_DESCRIPTOR'
 Write-Output 'PASS NO_SESSION_LOG_VIEWSTATE_OR_DATABASE_RAW_SECRET'
 Write-Output 'PASS NO_SLIDING_EXPIRY_OR_REVOCATION'
 Write-Output 'PASS SUPPORTED_HEADER_GATE_AND_TRANSACTIONAL_COOKIE_STAGING'
 Write-Output 'PASS NO_POST_COMMIT_COOKIE_WRITE'
 Write-Output 'PASS INDETERMINATE_TRANSITION_ONLY_FOR_STAGED_ACTIVATION'
 Write-Output 'PASS READ_ONLY_NOT_FOUND_KSC1_FALLBACK'
 Write-Output 'PASS ACTIVATION_TIMESTAMPS_FROM_TRANSACTION_DB_CLOCK'
}finally{
 $cs=$null;$x=$null
 $resolved=[IO.Path]::GetFullPath($testDir)
 if(-not $resolved.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'UNSAFE_HARNESS_CLEANUP'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
