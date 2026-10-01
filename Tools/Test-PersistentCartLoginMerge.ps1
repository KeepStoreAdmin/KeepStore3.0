[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ScratchConfigPath)
$ErrorActionPreference='Stop';$repo=Split-Path -Parent $PSScriptRoot
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testDir=Join-Path $tempBase ('KeepStoreLoginMergeHarness-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir|Out-Null
try{
 foreach($dll in Get-ChildItem -LiteralPath (Join-Path $repo 'Bin') -Filter '*.dll' -File){Copy-Item -LiteralPath $dll.FullName -Destination $testDir}
 $exe=Join-Path $testDir 'LoginMergeHarness.exe'
 $sources=@('App_Code\CartStorefrontScopePolicy.vb','App_Code\CartMutationIdempotencyService.vb',
  'App_Code\PersistentAnonymousCartOwnerService.vb','App_Code\PersistentAnonymousCartMutationActivation.vb',
  'App_Code\CartTransactionRetryPolicy.vb','App_Code\CartOwnershipService.vb',
  'App_Code\PersistentAnonymousCartLoginMergeService.vb','Tools\PersistentCartLoginMergeHarness.vb')|ForEach-Object{Join-Path $repo $_}
 & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$exe" /r:System.dll /r:System.Web.dll /r:System.Data.dll /r:System.Configuration.dll "/r:$(Join-Path $testDir 'MySql.Data.dll')" $sources
 if($LASTEXITCODE -ne 0){throw 'LOGIN_MERGE_HARNESS_COMPILE_FAILED'}
 [xml]$config=Get-Content -LiteralPath $ScratchConfigPath -Raw
 if(@($config.configuration.connectionStrings.add).Count -ne 1){throw 'SCRATCH_SINGLE_CONNECTION_REQUIRED'}
 $cs=[string]$config.configuration.connectionStrings.add.connectionString
 # Secrets go only through stdin; no copied configuration or process arguments.
 $cs | & $exe
 if($LASTEXITCODE -ne 0){throw 'LOGIN_MERGE_HARNESS_FAILED'}
 $ownership=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\CartOwnershipService.vb'))
 $helper=[IO.File]::ReadAllText((Join-Path $repo 'App_Code\PersistentAnonymousCartLoginMergeService.vb'))
 $master=[IO.File]::ReadAllText((Join-Path $repo 'Page.master.vb'))
 $login=[IO.File]::ReadAllText((Join-Path $repo 'login.aspx.vb'))
 $logout=[IO.File]::ReadAllText((Join-Path $repo 'logout.aspx.vb'))
 if($master -notmatch 'CartOwnershipService.MergeAnonymousCartIntoAccount' -or $login -match 'MergeAnonymousCartIntoAccount'){throw 'LOGIN_ENTRY_POINT_CHANGED'}
 if($ownership -notmatch 'LoadOwnedRows\(conn, transaction, attemptLoginId\)[\s\S]*?\.Acquire\([\s\S]*?AppendAnonymousRows\(conn, transaction, persistent.OwnerToken[\s\S]*?AppendAnonymousRows\(conn, transaction, attemptSessionId'){throw 'LOGIN_LOCK_ORDER_FAILED'}
 if($ownership -notmatch 'Value = row.SessionId' -or $ownership -notmatch 'BuildAnonymousOwnerToken'){throw 'MULTI_SOURCE_OWNER_BOUNDARY_FAILED'}
 if($helper -notmatch 'Request.Cookies\(PersistentAnonymousCartOwnerService.CookieName\)' -or $helper -notmatch 'TryDecodeCookie' -or $helper -notmatch 'DeriveOwnerToken' -or $helper -notmatch 'Array.Clear\(secret'){throw 'LOGIN_COOKIE_BOUNDARY_FAILED'}
 if($ownership -notmatch 'If execution.Succeeded[\s\S]*?CleanupCookie' -or $helper -notmatch 'status <> CartTransactionExecutionStatus.Succeeded'){throw 'POST_COMMIT_COOKIE_BOUNDARY_FAILED'}
 if($logout -match 'PersistentAnonymousCart|ksc2_|DeriveOwnerToken|INSERT INTO carrello'){throw 'LOGOUT_PERSISTENT_CART_REGRESSION'}
 if($helper -match '\.Domain\s*=|Session\(|ViewState|Request.QueryString|ex.Message'){throw 'SECRET_PERSISTENCE_BOUNDARY_FAILED'}
 Write-Output 'PASS LOGIN_ENTRY_POINT_LOCK_ORDER_MULTI_SOURCE_AND_POST_COMMIT_COOKIE'
 Write-Output 'PASS LOGOUT_NO_PERSISTENT_COOKIE_OR_ANONYMOUS_CART_CREATION'
 Write-Output 'PASS SHARED_DERIVATION_NO_SECRET_PERSISTENCE'
}finally{
 $cs=$null;$config=$null
 $resolved=[IO.Path]::GetFullPath($testDir)
 if(-not $resolved.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'UNSAFE_HARNESS_CLEANUP'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
