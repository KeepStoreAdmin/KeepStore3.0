[CmdletBinding()]
param([string]$RepositoryRoot, [switch]$RunIsolatedDatabase)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\vbc.exe' }
$out = Join-Path ([IO.Path]::GetTempPath()) ('paypal-flow-' + [Guid]::NewGuid().ToString('N') + '.exe')
try {
    & $compiler /nologo /target:exe /out:$out /r:System.dll /r:System.Web.dll `
        (Join-Path $RepositoryRoot 'Tools\PayPalCheckoutFlowHarness.vb') `
        (Join-Path $RepositoryRoot 'App_Code\PayPalWebLaunchContext.vb') `
        (Join-Path $RepositoryRoot 'App_Code\PayPalCheckoutSafetyPolicy.vb')
    if ($LASTEXITCODE -ne 0) { throw 'PAYPAL_FLOW_COMPILE_FAILED' }
    & $out
    if ($LASTEXITCODE -ne 0) { throw 'PAYPAL_FLOW_FAILED' }
} finally {
    Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
}

if ($RunIsolatedDatabase) {
    $library = Join-Path $RepositoryRoot 'Bin\MySql.Data.dll'
    if (-not (Test-Path -LiteralPath $library)) { throw 'PAYPAL_DB_MYSQL_LIBRARY_MISSING' }
    $testDir = Join-Path ([IO.Path]::GetTempPath()) ('paypal-rev3-harness-' + [Guid]::NewGuid().ToString('N'))
    $testDir = [IO.Path]::GetFullPath($testDir)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $testDir.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'PAYPAL_DB_UNSAFE_TEMP_PATH' }
    New-Item -ItemType Directory -Path $testDir -ErrorAction Stop | Out-Null
    try {
        $exe = Join-Path $testDir 'PayPalCheckoutPersistenceHarness.exe'
        Copy-Item -LiteralPath $library -Destination (Join-Path $testDir 'MySql.Data.dll')
        $dependencies = @('Google.Protobuf.dll', 'BouncyCastle.Cryptography.dll',
                'System.Buffers.dll', 'System.Memory.dll', 'System.Runtime.CompilerServices.Unsafe.dll',
                'System.Threading.Tasks.Extensions.dll', 'System.Numerics.Vectors.dll', 'System.Formats.Asn1.dll')
        foreach ($dependency in $dependencies) {
            Copy-Item -LiteralPath (Join-Path $RepositoryRoot (Join-Path 'Bin' $dependency)) -Destination (Join-Path $testDir $dependency)
        }
        $labName = 'ks_paypal_rev3_' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
        $connection = "Server=localhost;Database=$labName;Uid=root;Protocol=pipe;Pipe Name=KS_PAYPAL_REV2_PIPE;"
        $redirects = foreach ($dependency in $dependencies) {
            $assembly = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $testDir $dependency))
            $token = [BitConverter]::ToString($assembly.GetPublicKeyToken()).Replace('-', '').ToLowerInvariant()
            if ($token) {
                '<dependentAssembly><assemblyIdentity name="' + $assembly.Name + '" publicKeyToken="' + $token +
                    '" /><bindingRedirect oldVersion="0.0.0.0-' + $assembly.Version + '" newVersion="' +
                    $assembly.Version + '" /></dependentAssembly>'
            }
        }
        $config = '<configuration><connectionStrings><add name="EntropicConnectionString" connectionString="' +
            $connection + '" /></connectionStrings><runtime><assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">' +
            ($redirects -join '') + '</assemblyBinding></runtime></configuration>'
        [IO.File]::WriteAllText(($exe + '.config'), $config, [Text.Encoding]::UTF8)
        & $compiler /nologo /target:exe /define:PAYPAL_DB_TEST=True /out:$exe `
            /r:System.dll /r:System.Data.dll /r:System.Configuration.dll /r:System.Web.dll /r:System.Web.Extensions.dll /r:$library `
            (Join-Path $RepositoryRoot 'Tools\PayPalCheckoutFlowHarness.vb') `
            (Join-Path $RepositoryRoot 'App_Code\PayPalCheckoutConfig.vb') `
            (Join-Path $RepositoryRoot 'App_Code\PayPalOrdersV2Client.vb') `
            (Join-Path $RepositoryRoot 'App_Code\PayPalCheckoutRepository.vb') `
            (Join-Path $RepositoryRoot 'App_Code\PayPalAttemptPolicy.vb')
        if ($LASTEXITCODE -ne 0) { throw 'PAYPAL_DB_HARNESS_COMPILE_FAILED' }
        & $exe
        if ($LASTEXITCODE -ne 0) { throw 'PAYPAL_DB_HARNESS_FAILED' }
    } finally {
        Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
