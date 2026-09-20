[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStore-EmailCoreHarness-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null

function Assert-Check([bool]$Condition, [string]$Code) {
    if (-not $Condition) { throw $Code }
    Write-Output ('PASS ' + $Code)
}

try {
    & (Join-Path $PSScriptRoot 'Restore-EmailTransportDependencies.ps1') -DestinationBin (Join-Path $repo 'Bin') -VerifyOnly

    $manifestPath = Join-Path $repo 'Dependencies\EmailTransport\dependency-manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Assert-Check (@($manifest.packages).Count -eq 10) 'DEPENDENCY_PACKAGE_COUNT'
    Assert-Check (@($manifest.packages | Where-Object { $null -ne $_.asset }).Count -eq 9) 'DEPENDENCY_RUNTIME_ASSET_COUNT'

    $runtimeFiles = @(
        'App_Code\TenantEmailTransportContracts.vb',
        'App_Code\TenantEmailTransportProfileResolver.vb',
        'App_Code\EmailCredentialStore.vb',
        'App_Code\MailKitEmailTransport.vb',
        'App_Code\TenantEmailDeliveryService.vb'
    )
    $runtimeText = ($runtimeFiles | ForEach-Object { Get-Content -LiteralPath (Join-Path $repo $_) -Raw }) -join "`n"
    Assert-Check ($runtimeText -notmatch '(?i)SecureSocketOptions\.Auto|SecureSocketOptions\.None') 'NO_TLS_AUTO_OR_PLAINTEXT'
    Assert-Check ($runtimeText -match 'SecureSocketOptions\.StartTls' -and $runtimeText -match 'SecureSocketOptions\.SslOnConnect') 'EXPLICIT_TLS_MAPPINGS'
    Assert-Check ($runtimeText -notmatch '(?i)ServerCertificateValidationCallback\s*=\s*Function\([^\r\n]+\)\s*True') 'NO_PERMISSIVE_CERT_CALLBACK'
    Assert-Check ($runtimeText -notmatch '(?i)\bSession\s*\(|\bViewState\s*\(|\bRequest\.QueryString|\bResponse\.Write') 'NO_SECRET_WEB_STATE_CHANNELS'
    Assert-Check ($runtimeText -notmatch '(?i)INSERT\s+INTO|UPDATE\s+aziende_email_transport|DELETE\s+FROM|DROP\s+TABLE|ALTER\s+TABLE') 'RUNTIME_READ_ONLY_PROFILE_ACCESS'

    $vbc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $exe = Join-Path $tempRoot 'EmailTransportRuntimeCoreHarness.exe'
    $references = @(
        'System.dll', 'System.Core.dll', 'System.Data.dll', 'System.Web.dll', 'System.Configuration.dll', 'System.Security.dll',
        (Join-Path $repo 'Bin\MySql.Data.dll'),
        (Join-Path $repo 'Bin\MailKit.dll'),
        (Join-Path $repo 'Bin\MimeKit.dll'),
        (Join-Path $repo 'Bin\BouncyCastle.Cryptography.dll'),
        (Join-Path $repo 'Bin\System.Formats.Asn1.dll'),
        (Join-Path $repo 'Bin\System.Buffers.dll'),
        (Join-Path $repo 'Bin\System.Memory.dll'),
        (Join-Path $repo 'Bin\System.Numerics.Vectors.dll'),
        (Join-Path $repo 'Bin\System.Runtime.CompilerServices.Unsafe.dll'),
        (Join-Path $repo 'Bin\System.Threading.Tasks.Extensions.dll')
    )
    $arguments = @('/nologo', '/target:exe', '/optionstrict-', ('/out:' + $exe), ('/reference:' + ($references -join ',')))
    $arguments += $runtimeFiles | ForEach-Object { Join-Path $repo $_ }
    $arguments += Join-Path $repo 'Tools\EmailTransportRuntimeCoreHarness.vb'
    & $vbc @arguments
    if ($LASTEXITCODE -ne 0) { throw ('EMAIL_CORE_HARNESS_COMPILE_' + $LASTEXITCODE) }

    foreach ($file in @('MailKit.dll','MimeKit.dll','BouncyCastle.Cryptography.dll','System.Formats.Asn1.dll','System.Buffers.dll','System.Memory.dll','System.Numerics.Vectors.dll','System.Runtime.CompilerServices.Unsafe.dll','System.Threading.Tasks.Extensions.dll','MySql.Data.dll')) {
        Copy-Item -LiteralPath (Join-Path $repo ('Bin\' + $file)) -Destination (Join-Path $tempRoot $file)
    }

    $output = & $exe
    if ($LASTEXITCODE -ne 0) { throw ('EMAIL_CORE_HARNESS_RUN_' + $LASTEXITCODE) }
    $output | Write-Output
    Assert-Check (($output -join "`n") -match 'EMAIL_TRANSPORT_RUNTIME_CORE_PASS checks=56') 'HARNESS_56_CHECKS'
    Assert-Check (($output -join "`n") -match 'PROVISIONING_MODEL=SIMPLIFIED_ADMIN_TOOL') 'SIMPLIFIED_PROVISIONING_EXPLICIT'

    & (Join-Path $PSScriptRoot 'Test-EmailTransportCredentialProvisioning.ps1')

    Assert-Check ($runtimeText -match 'Class TenantEmailDeliveryService') 'CENTRAL_FACADE_COMPILED'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
