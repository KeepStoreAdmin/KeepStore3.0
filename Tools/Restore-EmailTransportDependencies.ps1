[CmdletBinding()]
param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Dependencies\EmailTransport\dependency-manifest.json'),
    [string]$DestinationBin = (Join-Path $PSScriptRoot '..\Bin'),
    [string]$PackageCachePath,
    [switch]$VerifyOnly,
    [switch]$KeepPackageCache
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Code) {
    if ([string]$Actual -cne [string]$Expected) {
        throw $Code
    }
}

$manifestFull = [IO.Path]::GetFullPath($ManifestPath)
$destinationFull = [IO.Path]::GetFullPath($DestinationBin)
$manifest = Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json

Assert-Equal $manifest.schemaVersion 1 'EMAIL_DEPS_MANIFEST_VERSION'
Assert-Equal $manifest.framework 'net48' 'EMAIL_DEPS_FRAMEWORK'
Assert-Equal $manifest.source 'https://api.nuget.org/v3-flatcontainer' 'EMAIL_DEPS_SOURCE'

if ($VerifyOnly) {
    foreach ($package in @($manifest.packages)) {
        if ($null -eq $package.asset) { continue }
        $target = Join-Path $destinationFull ([string]$package.destination)
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            throw ('EMAIL_DEPS_MISSING_' + $package.id)
        }
        Assert-Equal (Get-Item -LiteralPath $target).Length $package.assetBytes ('EMAIL_DEPS_LENGTH_' + $package.id)
        Assert-Equal (Get-Sha256 $target) $package.assetSha256 ('EMAIL_DEPS_HASH_' + $package.id)
    }
    Write-Output ('EMAIL_DEPENDENCIES_VERIFIED count=' + (@($manifest.packages | Where-Object { $null -ne $_.asset }).Count))
    exit 0
}

$ownsCache = [string]::IsNullOrWhiteSpace($PackageCachePath)
if ($ownsCache) {
    $PackageCachePath = Join-Path ([IO.Path]::GetTempPath()) ('KeepStore-EmailDependencies-' + [Guid]::NewGuid().ToString('N'))
}
$cacheFull = [IO.Path]::GetFullPath($PackageCachePath)
[IO.Directory]::CreateDirectory($cacheFull) | Out-Null
[IO.Directory]::CreateDirectory($destinationFull) | Out-Null

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    foreach ($package in @($manifest.packages)) {
        $id = [string]$package.id
        $version = [string]$package.version
        $idLower = $id.ToLowerInvariant()
        $packageFile = Join-Path $cacheFull ($id + '.' + $version + '.nupkg')
        $extractRoot = Join-Path $cacheFull ($id + '.' + $version)
        $uri = ([string]$manifest.source).TrimEnd('/') + '/' + $idLower + '/' + $version + '/' + $idLower + '.' + $version + '.nupkg'

        if (-not (Test-Path -LiteralPath $packageFile -PathType Leaf)) {
            Invoke-WebRequest -Uri $uri -OutFile $packageFile -UseBasicParsing
        }

        Assert-Equal (Get-Item -LiteralPath $packageFile).Length $package.packageBytes ('EMAIL_PACKAGE_LENGTH_' + $id)
        Assert-Equal (Get-Sha256 $packageFile) $package.packageSha256 ('EMAIL_PACKAGE_HASH_' + $id)

        if ($null -eq $package.asset) { continue }

        if (Test-Path -LiteralPath $extractRoot) {
            Remove-Item -LiteralPath $extractRoot -Recurse -Force
        }
        [IO.Compression.ZipFile]::ExtractToDirectory($packageFile, $extractRoot)

        $relativeAsset = ([string]$package.asset).Replace('/', [IO.Path]::DirectorySeparatorChar)
        $sourceAsset = Join-Path $extractRoot $relativeAsset
        if (-not (Test-Path -LiteralPath $sourceAsset -PathType Leaf)) {
            throw ('EMAIL_PACKAGE_ASSET_' + $id)
        }
        Assert-Equal (Get-Item -LiteralPath $sourceAsset).Length $package.assetBytes ('EMAIL_ASSET_LENGTH_' + $id)
        Assert-Equal (Get-Sha256 $sourceAsset) $package.assetSha256 ('EMAIL_ASSET_HASH_' + $id)

        $target = Join-Path $destinationFull ([string]$package.destination)
        $temporaryTarget = $target + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
        $backupTarget = $target + '.' + [Guid]::NewGuid().ToString('N') + '.bak'
        [IO.File]::Copy($sourceAsset, $temporaryTarget, $false)
        try {
            if (Test-Path -LiteralPath $target -PathType Leaf) {
                [IO.File]::Replace($temporaryTarget, $target, $backupTarget)
            } else {
                [IO.File]::Move($temporaryTarget, $target)
            }
        } finally {
            if (Test-Path -LiteralPath $temporaryTarget) {
                Remove-Item -LiteralPath $temporaryTarget -Force
            }
            if (Test-Path -LiteralPath $backupTarget) {
                Remove-Item -LiteralPath $backupTarget -Force
            }
        }
    }

    & $PSCommandPath -ManifestPath $manifestFull -DestinationBin $destinationFull -VerifyOnly
    if ($LASTEXITCODE -ne 0) { throw 'EMAIL_DEPS_POST_VERIFY' }
    Write-Output ('EMAIL_DEPENDENCIES_RESTORED source=official-nuget framework=net48')
} finally {
    if ($ownsCache -and -not $KeepPackageCache -and (Test-Path -LiteralPath $cacheFull)) {
        Remove-Item -LiteralPath $cacheFull -Recurse -Force
    }
}
