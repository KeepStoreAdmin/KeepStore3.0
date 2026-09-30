[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = Join-Path $tempBase ('KeepStoreCartIntentTransition-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $testRoot 'CartIntentOwnerTransitionHarness.exe'

New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" `
        /r:System.dll /r:System.Web.dll `
        (Join-Path $repoRoot 'App_Code\CartStorefrontScopePolicy.vb') `
        (Join-Path $repoRoot 'App_Code\CartMutationIdempotencyService.vb') `
        (Join-Path $PSScriptRoot 'CartIntentOwnerTransitionHarness.vb')
    if ($LASTEXITCODE -ne 0) { throw 'CART_INTENT_TRANSITION_COMPILE_FAILED' }
    & $executable
    if ($LASTEXITCODE -ne 0) { throw 'CART_INTENT_TRANSITION_FAILED' }

    $source = [IO.File]::ReadAllText((Join-Path $repoRoot 'App_Code\CartMutationIdempotencyService.vb'))
    if ($source -notmatch 'FixedTimeEquals\(existing\.PayloadFingerprint' -or
        $source -notmatch 'FixedTimeEquals\(existing\.TransitionOwnerScopeHash' -or
        $source -notmatch 'FixedTimeEquals\(existing\.Fingerprint') {
        throw 'DIGEST_COMPARISON_NOT_FIXED_TIME'
    }
    if ($source -match '(?i)Response\.Cookies|Set-Cookie|MySqlConnection|MySqlCommand|INSERT\s+INTO|UPDATE\s+carrello') {
        throw 'TRANSITION_SIDE_EFFECT_FOUND'
    }
    Write-Output 'PASS FIXED_TIME_DIGEST_COMPARISON'
    Write-Output 'PASS NO_COOKIE_OR_DATABASE_SIDE_EFFECT'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $testRoot).Path)
        if (-not $resolved.StartsWith($tempBase + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'UNSAFE_HARNESS_CLEANUP_PATH'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
