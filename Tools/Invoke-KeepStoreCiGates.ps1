[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory=$true)][ValidateSet('push','pull_request')][string]$EventName,
    [Parameter(Mandatory=$true)][string]$RefName,
    [Parameter(Mandatory=$true)][string]$CandidateSha,
    [string]$BaseSha
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path.TrimEnd('\')
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion -lt [version]'5.1' -or
    [IntPtr]::Size -ne 8) { throw 'CI_REQUIRES_WINDOWS_POWERSHELL_51_X64' }
$powershell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Invoke-CiGit([string[]]$Arguments) {
    # Never forward diff contents, Git credentials or native diagnostics to CI logs.
    $result = @(& git -C $RepositoryRoot @Arguments 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'CI_GIT_VALIDATION_FAILED' }
    return $result
}

function Resolve-CiCommit([string]$Sha) {
    if ($Sha -cnotmatch '^[0-9a-f]{40}$' -or $Sha -eq ('0' * 40)) { throw 'CI_INVALID_COMMIT' }
    $resolved = @(Invoke-CiGit @('rev-parse','--verify',($Sha+'^{commit}')))
    if ($resolved.Count -ne 1 -or $resolved[0] -cne $Sha) { throw 'CI_COMMIT_NOT_AVAILABLE' }
    return $Sha
}

function Invoke-CiGate([string]$Name, [string]$ScriptName, [string[]]$Arguments) {
    $script = Join-Path $RepositoryRoot ('Tools\' + $ScriptName)
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw ('CI_GATE_MISSING_' + $Name) }
    # A child process isolates explicit exit statements and stale LASTEXITCODE.
    & $powershell -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File $script @Arguments
    if ($LASTEXITCODE -ne 0) { throw ('CI_GATE_FAILED_' + $Name) }
    Write-Output ('CI_GATE_PASS=' + $Name)
}

$top = @(Invoke-CiGit @('rev-parse','--show-toplevel'))
if ($top.Count -ne 1 -or [IO.Path]::GetFullPath($top[0]).TrimEnd('\') -ine $RepositoryRoot) {
    throw 'CI_REPOSITORY_ROOT_MISMATCH'
}
$candidate = Resolve-CiCommit $CandidateSha
$head = @(Invoke-CiGit @('rev-parse','HEAD'))
if ($head.Count -ne 1 -or $head[0] -cne $candidate) { throw 'CI_CHECKOUT_SHA_MISMATCH' }
$null = Invoke-CiGit @('diff','--quiet','HEAD','--')
$null = Invoke-CiGit @('diff','--cached','--quiet','HEAD','--')

if ($EventName -eq 'pull_request') {
    # The workflow checks out PR head, never the synthetic merge tree.
    $base = Resolve-CiCommit $BaseSha
} elseif ($RefName -cmatch '^task/[A-Za-z0-9._/-]+$') {
    # Scan the whole task even after a second push, not only its last commit.
    $mergeBase = @(Invoke-CiGit @('merge-base','origin/frontend-rebuild',$candidate))
    if ($mergeBase.Count -ne 1) { throw 'CI_BASE_UNAVAILABLE' }
    $base = Resolve-CiCommit $mergeBase[0]
} elseif ($RefName -ceq 'frontend-rebuild') {
    # Comparing a stable push against the updated remote ref would scan nothing.
    $base = Resolve-CiCommit $BaseSha
} else {
    throw 'CI_BRANCH_OUTSIDE_SCOPE'
}
$null = Invoke-CiGit @('merge-base','--is-ancestor',$base,$candidate)
$merges = @(Invoke-CiGit @('rev-list','--min-parents=2',($base+'..'+$candidate)))
if ($merges.Count -ne 0) { throw 'CI_NONLINEAR_CANDIDATE' }
$null = Invoke-CiGit @('diff','--check',$base,$candidate,'--')
Write-Output ('CI_GIT_PASS base=' + $base + ' candidate=' + $candidate)

Invoke-CiGate 'SECRETS' 'Test-DatabaseSecretsGuard.ps1' @('-RepositoryRoot',$RepositoryRoot,'-BaseRef',$base)
Invoke-CiGate 'CART_CONSISTENCY' 'Test-CartConsistency.ps1' @()
Invoke-CiGate 'PRECOMPILE' 'Test-KeepStorePrecompileSafe.ps1' @('-RepositoryRoot',$RepositoryRoot)
Write-Output 'KEEPSTORE_SOURCE_GATES_PASS'
