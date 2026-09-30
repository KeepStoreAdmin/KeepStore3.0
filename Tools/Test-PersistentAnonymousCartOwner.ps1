[CmdletBinding()]
param([switch]$NoDatabase)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testDir = Join-Path $tempRoot ('KeepStorePersistentOwnerHarness-' + [Guid]::NewGuid().ToString('N'))
$testDir = [IO.Path]::GetFullPath($testDir)
if (-not $testDir.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'UNSAFE_HARNESS_PATH'
}
$dependencies = @(
    'MySql.Data.dll', 'Google.Protobuf.dll', 'BouncyCastle.Cryptography.dll',
    'System.Buffers.dll', 'System.Memory.dll', 'System.Runtime.CompilerServices.Unsafe.dll',
    'System.Threading.Tasks.Extensions.dll', 'System.Numerics.Vectors.dll', 'System.Formats.Asn1.dll'
)

New-Item -ItemType Directory -Path $testDir | Out-Null
try {
    foreach ($dependency in $dependencies) {
        Copy-Item -LiteralPath (Join-Path $repo ('Bin\' + $dependency)) -Destination (Join-Path $testDir $dependency)
    }
    $exe = Join-Path $testDir 'PersistentAnonymousCartOwnerHarness.exe'
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$exe" `
        /r:System.dll /r:System.Web.dll /r:System.Configuration.dll `
        "/r:$(Join-Path $testDir 'MySql.Data.dll')" `
        (Join-Path $repo 'App_Code\PersistentAnonymousCartOwnerService.vb') `
        (Join-Path $repo 'App_Code\CartStorefrontScopePolicy.vb') `
        (Join-Path $PSScriptRoot 'PersistentAnonymousCartOwnerHarness.vb')
    if ($LASTEXITCODE -ne 0) { throw 'PERSISTENT_OWNER_HARNESS_COMPILE_FAILED' }
    if (-not $NoDatabase) {
        & $exe
        if ($LASTEXITCODE -ne 0) { throw 'PERSISTENT_OWNER_HARNESS_FAILED' }
    } else {
        Write-Output 'PASS PERSISTENT_OWNER_HARNESS_COMPILE_ONLY_NO_DATABASE'
    }

    $ownerContext = [IO.File]::ReadAllText((Join-Path $repo 'App_Code\CartStorefrontOwnerContext.vb'))
    $service = [IO.File]::ReadAllText((Join-Path $repo 'App_Code\PersistentAnonymousCartOwnerService.vb'))
    if ($ownerContext -notmatch 'If loginId > 0 Then[\s\S]*?Else[\s\S]*?PersistentAnonymousCartOwnerService\.Resolve') {
        throw 'AUTHENTICATED_PATH_NOT_ISOLATED'
    }
    if ($ownerContext -notmatch 'TECHNICAL_ERROR Then[\s\S]*?Throw New HttpException\(503') {
        throw 'TECHNICAL_ERROR_NOT_FAIL_CLOSED'
    }
    if ($ownerContext -notmatch 'BuildAnonymousOwnerToken\(') { throw 'KSC1_FALLBACK_MISSING' }
    if ($service -match '(?i)Response\.Cookies|Set-Cookie|\.Cookies\.Add|\.Cookies\.Set|\bUPDATE\s+carrello_anonimo_persistenza\b|\bINSERT\s+INTO\s+carrello_anonimo_persistenza\b') {
        throw 'PURE_READ_CONTRACT_VIOLATION'
    }
    Write-Output 'PASS AUTHENTICATED_FLOW_UNCHANGED'
    Write-Output 'PASS TECHNICAL_ERROR_FAIL_CLOSED'
    Write-Output 'PASS KSC1_FALLBACK_PRESENT'
    Write-Output 'PASS NO_PERSISTENT_SET_COOKIE_OR_REGISTRY_DML'
}
finally {
    if (Test-Path -LiteralPath $testDir) {
        $resolved = (Resolve-Path -LiteralPath $testDir).Path
        if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'UNSAFE_HARNESS_CLEANUP_PATH'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
