[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$AziendaId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('TRANSACTIONAL', 'MARKETING')]
    [string]$Purpose,

    [string]$ApplicationRoot = (Split-Path -Parent $PSScriptRoot),

    [string]$ConnectionStringName = 'EntropicConnectionString',

    [string]$CredentialRoot = 'C:\ProgramData\KeepStore\EmailCredentials'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$script:EmailVerifierExitCodes = [ordered]@{
    Success = 0
    ConfigurationInvalid = 10
    ProfileUnavailable = 20
    CredentialUnavailable = 21
    TlsOrCertificate = 30
    Authentication = 31
    Timeout = 32
    Transport = 33
    Internal = 40
}

function Test-EmailVerifierAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-EmailVerifierFailure([string]$Code, [int]$ExitCode, [string]$CorrelationId) {
    $safeCode = [Convert]::ToString($Code).Trim().ToUpperInvariant()
    if ($safeCode -notmatch '^[A-Z0-9_]{3,64}$') { $safeCode = 'EMAIL_VERIFY_INTERNAL_FAILURE' }
    $safeCorrelation = [Convert]::ToString($CorrelationId).Trim()
    if ($safeCorrelation -notmatch '^[A-Za-z0-9-]{8,64}$') { $safeCorrelation = [Guid]::NewGuid().ToString('N') }

    [Console]::Out.WriteLine('STATUS=FAILED')
    [Console]::Out.WriteLine('PROFILE_STATE=TECHNICAL_ERROR')
    [Console]::Out.WriteLine('FAILURE_KIND=INVALID_REQUEST')
    [Console]::Out.WriteLine('PHASE=CONFIGURATION')
    [Console]::Out.WriteLine('CODE=' + $safeCode)
    [Console]::Out.WriteLine('AUTHENTICATION_MODE=N_A')
    [Console]::Out.WriteLine('SECURITY_MODE=N_A')
    [Console]::Out.WriteLine('TIMESTAMP_UTC=' + [DateTime]::UtcNow.ToString('o'))
    [Console]::Out.WriteLine('CORRELATION_ID=' + $safeCorrelation)
    return $ExitCode
}

function Get-EmailVerifierCompiler {
    $candidates = @(
        (Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'),
        (Join-Path $env:windir 'Microsoft.NET\Framework\v4.0.30319\vbc.exe')
    )
    $compiler = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($compiler)) { throw 'EMAIL_VERIFY_COMPILER_NOT_FOUND' }
    return $compiler
}

function New-EmailVerifierBuild([string]$Root) {
    $applicationFull = [IO.Path]::GetFullPath($Root)
    $runtimeFramework = Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319'
    if (-not (Test-Path -LiteralPath $runtimeFramework -PathType Container)) {
        $runtimeFramework = Join-Path $env:windir 'Microsoft.NET\Framework\v4.0.30319'
    }

    $requiredSources = @(
        'App_Code\TenantEmailTransportContracts.vb',
        'App_Code\TenantEmailTransportProfileResolver.vb',
        'App_Code\EmailCredentialStore.vb',
        'App_Code\MailKitEmailTransport.vb',
        'App_Code\KeepStoreLog.vb',
        'Tools\EmailTransportConnectionVerifier.vb'
    )
    foreach ($relative in $requiredSources) {
        if (-not (Test-Path -LiteralPath (Join-Path $applicationFull $relative) -PathType Leaf)) {
            throw 'EMAIL_VERIFY_SOURCE_MISSING'
        }
    }

    & (Join-Path $applicationFull 'Tools\Restore-EmailTransportDependencies.ps1') `
        -DestinationBin (Join-Path $applicationFull 'Bin') -VerifyOnly *> $null
    if ($LASTEXITCODE -ne 0) { throw 'EMAIL_VERIFY_DEPENDENCIES_INVALID' }

    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStore-EmailVerifier-' + [Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
    $executable = Join-Path $temporaryRoot 'EmailTransportConnectionVerifier.exe'

    try {
        $dependencyFiles = @(
            'MySql.Data.dll',
            'MailKit.dll',
            'MimeKit.dll',
            'BouncyCastle.Cryptography.dll',
            'System.Formats.Asn1.dll',
            'System.Buffers.dll',
            'System.Memory.dll',
            'System.Numerics.Vectors.dll',
            'System.Runtime.CompilerServices.Unsafe.dll',
            'System.Threading.Tasks.Extensions.dll'
        )
        foreach ($file in $dependencyFiles) {
            $source = Join-Path $applicationFull ('Bin\' + $file)
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'EMAIL_VERIFY_DEPENDENCY_MISSING' }
            Copy-Item -LiteralPath $source -Destination (Join-Path $temporaryRoot $file)
        }

        $frameworkReferences = @(
            'System.dll',
            'System.Core.dll',
            'System.Data.dll',
            'System.Xml.dll',
            'System.Web.dll',
            'System.Configuration.dll',
            'System.Security.dll'
        ) | ForEach-Object { Join-Path $runtimeFramework $_ }
        $applicationReferences = $dependencyFiles | ForEach-Object { Join-Path $temporaryRoot $_ }
        $references = @($frameworkReferences) + @($applicationReferences)

        $arguments = @(
            '/nologo',
            '/quiet',
            '/target:exe',
            '/platform:anycpu',
            '/optimize+',
            '/debug-',
            '/optionstrict-',
            '/optionexplicit+',
            '/main:EmailTransportConnectionVerifier',
            ('/out:' + $executable),
            ('/reference:' + ($references -join ','))
        )
        $arguments += $requiredSources | ForEach-Object { Join-Path $applicationFull $_ }

        $compilerOutput = & (Get-EmailVerifierCompiler) @arguments 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executable -PathType Leaf)) {
            $compilerOutput = $null
            throw 'EMAIL_VERIFY_BUILD_FAILED'
        }
        $compilerOutput = $null

        return [pscustomobject]@{
            Root = $temporaryRoot
            Executable = $executable
        }
    } catch {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
        throw
    }
}

function Test-EmailVerifierOutput([string[]]$Lines) {
    if ($null -eq $Lines -or $Lines.Count -ne 9) { return $false }
    $patterns = @(
        '^STATUS=[A-Z_]+$',
        '^PROFILE_STATE=[A-Z0-9_]+$',
        '^FAILURE_KIND=[A-Z0-9_]+$',
        '^PHASE=[A-Z0-9_]+$',
        '^CODE=[A-Z0-9_]{3,64}$',
        '^AUTHENTICATION_MODE=[A-Z0-9_]+$',
        '^SECURITY_MODE=[A-Z0-9_]+$',
        '^TIMESTAMP_UTC=[0-9T:.+-]+Z?$',
        '^CORRELATION_ID=[A-Za-z0-9-]{8,64}$'
    )
    for ($index = 0; $index -lt $patterns.Count; $index++) {
        if ([Convert]::ToString($Lines[$index]) -notmatch $patterns[$index]) { return $false }
    }
    return $true
}

function Invoke-EmailTransportConnectionVerification {
    $correlationId = [Guid]::NewGuid().ToString('N')
    $build = $null
    try {
        if (-not (Test-EmailVerifierAdministrator)) {
            return Write-EmailVerifierFailure 'EMAIL_VERIFY_ADMINISTRATOR_REQUIRED' `
                $script:EmailVerifierExitCodes.ConfigurationInvalid $correlationId
        }

        $applicationFull = [IO.Path]::GetFullPath($ApplicationRoot)
        $credentialFull = [IO.Path]::GetFullPath($CredentialRoot)
        if (-not (Test-Path -LiteralPath (Join-Path $applicationFull 'web.config') -PathType Leaf)) {
            return Write-EmailVerifierFailure 'EMAIL_VERIFY_WEB_CONFIG_NOT_FOUND' `
                $script:EmailVerifierExitCodes.ConfigurationInvalid $correlationId
        }

        $build = New-EmailVerifierBuild $applicationFull
        $rawOutput = @(& $build.Executable `
            '--azienda-id' $AziendaId.ToString([Globalization.CultureInfo]::InvariantCulture) `
            '--purpose' $Purpose `
            '--application-root' $applicationFull `
            '--connection-string-name' $ConnectionStringName `
            '--credential-root' $credentialFull 2>$null)
        $exitCode = $LASTEXITCODE

        if (-not (Test-EmailVerifierOutput $rawOutput)) {
            $rawOutput = $null
            return Write-EmailVerifierFailure 'EMAIL_VERIFY_OUTPUT_INVALID' `
                $script:EmailVerifierExitCodes.Internal $correlationId
        }
        $rawOutput | ForEach-Object { [Console]::Out.WriteLine([Convert]::ToString($_)) }
        return $exitCode
    } catch {
        $safeCode = [Convert]::ToString($_.Exception.Message)
        if ($safeCode -notmatch '^EMAIL_[A-Z0-9_]+$') { $safeCode = 'EMAIL_VERIFY_INTERNAL_FAILURE' }
        return Write-EmailVerifierFailure $safeCode $script:EmailVerifierExitCodes.Internal $correlationId
    } finally {
        if ($null -ne $build -and (Test-Path -LiteralPath $build.Root)) {
            Remove-Item -LiteralPath $build.Root -Recurse -Force
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-EmailTransportConnectionVerification)
}
