[CmdletBinding()]
param([string]$RepositoryRoot)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\vbc.exe' }
$library = Join-Path $RepositoryRoot 'Bin\MySql.Data.dll'
$labRoot = 'C:\Temp\ks-paypal-rev2-mysql-lab'
$engine = Join-Path $labRoot 'engine\mysql-8.0.46-winx64\bin'
$mysql = Join-Path $engine 'mysql.exe'
$mysqld = Join-Path $engine 'mysqld.exe'
$mysqladmin = Join-Path $engine 'mysqladmin.exe'
$dataDirectory = Join-Path $labRoot 'data'
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempDirectory = Join-Path $tempRoot ('ks-paypal-webhook-' + [Guid]::NewGuid().ToString('N'))
$appDirectory = Join-Path $tempDirectory 'app'
$binDirectory = Join-Path $appDirectory 'bin'
$pipeName = 'KS_PAYPAL_WEBHOOK_PIPE'
$serverProcess = $null
$ownedPipe = $false
$labName = 'ks_paypal_webhook_' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
$expectedDataDirectory = [IO.Path]::GetFullPath($dataDirectory).TrimEnd('\')

function Assert-LabFile([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'WEBHOOK_LAB_FILE_MISSING' }
}
function Escape-Xml([string]$text) { return [Security.SecurityElement]::Escape($text) }

Assert-LabFile $compiler
Assert-LabFile $library
Assert-LabFile $mysql
Assert-LabFile $mysqld
Assert-LabFile $mysqladmin
if (-not (Test-Path -LiteralPath $dataDirectory -PathType Container)) { throw 'WEBHOOK_ISOLATED_DATA_DIRECTORY_MISSING' }
if (-not $tempDirectory.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'WEBHOOK_UNSAFE_TEMP_PATH' }
New-Item -ItemType Directory -Path $binDirectory -Force | Out-Null
try {
    $serverProcess = Start-Process -FilePath $mysqld -PassThru -WindowStyle Hidden -ArgumentList @(
        '--no-defaults',
        ('--basedir=' + (Join-Path $labRoot 'engine\mysql-8.0.46-winx64')),
        ('--datadir=' + $dataDirectory),
        '--skip-networking', '--enable-named-pipe', ('--socket=' + $pipeName), '--mysqlx=OFF',
        ('--log-error=' + (Join-Path $tempDirectory 'mysql-lab.err')))
    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 500
        if ($serverProcess.HasExited) { throw 'WEBHOOK_ISOLATED_MYSQL_EXITED' }
        $actualDataDirectory = $null
        $mysqlExitCode = -1
        try {
            $actualDataDirectory = & $mysql --no-defaults --protocol=pipe --socket=$pipeName -uroot -N -s --execute='SELECT @@datadir' 2>$null
            $mysqlExitCode = $LASTEXITCODE
        } catch {
            # The named pipe can be unavailable while the isolated server starts.
        }
        if ($mysqlExitCode -eq 0 -and $actualDataDirectory) {
            $actualResolved = [IO.Path]::GetFullPath(([string]$actualDataDirectory).Trim()).TrimEnd('\','/')
            if (-not [string]::Equals($actualResolved, $expectedDataDirectory, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'WEBHOOK_ISOLATED_DATADIR_MISMATCH'
            }
            $ready = $true
            $ownedPipe = $true
            break
        }
    }
    if (-not $ready) { throw 'WEBHOOK_ISOLATED_MYSQL_NOT_READY' }

    $migrationDatabase = 'ks_paypal_credentials_' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
    $migrationPrefix = Join-Path $RepositoryRoot 'Database Taikun\Migrations\20260923_PAYPAL_DB_DRIVEN_CREDENTIALS_1A_'
    $migrationArgs = @('--no-defaults','--protocol=pipe',('--socket=' + $pipeName),'-uroot','-N','-s')
    try {
        & $mysql @migrationArgs -e ("CREATE DATABASE ``$migrationDatabase`` CHARACTER SET utf8mb4")
        if ($LASTEXITCODE -ne 0) { throw 'CREDENTIAL_MIGRATION_LAB_CREATE_FAILED' }
        & $mysql @migrationArgs $migrationDatabase -e 'CREATE TABLE paypal_checkout_account (Id int PRIMARY KEY, NomeProfilo varchar(100), CredentialKey varchar(64), MerchantId varchar(128), Attivo tinyint, Note varchar(500), CreatedAt timestamp DEFAULT CURRENT_TIMESTAMP, UpdatedAt timestamp DEFAULT CURRENT_TIMESTAMP); INSERT INTO paypal_checkout_account (Id,NomeProfilo,CredentialKey,MerchantId,Attivo,Note) VALUES (1,''Synthetic'',''PAYPAL_LAB'',''LAB-MERCHANT'',0,''preserve'')'
        if ($LASTEXITCODE -ne 0) { throw 'CREDENTIAL_MIGRATION_LAB_SEED_FAILED' }
        $preflight = Get-Content -LiteralPath ($migrationPrefix + 'preflight.sql') -Raw | & $mysql @migrationArgs $migrationDatabase
        if ($LASTEXITCODE -ne 0 -or @($preflight | Where-Object { $_ -match '^READY$' }).Count -ne 1) { throw 'CREDENTIAL_MIGRATION_PREFLIGHT_FAILED' }
        Get-Content -LiteralPath ($migrationPrefix + 'forward.sql') -Raw | & $mysql @migrationArgs $migrationDatabase
        if ($LASTEXITCODE -ne 0) { throw 'CREDENTIAL_MIGRATION_FORWARD_FAILED' }
        $verify = Get-Content -LiteralPath ($migrationPrefix + 'verify.sql') -Raw | & $mysql @migrationArgs $migrationDatabase
        if ($LASTEXITCODE -ne 0 -or @($verify | Where-Object { $_ -match '^OK$' }).Count -ne 2) { throw 'CREDENTIAL_MIGRATION_VERIFY_FAILED' }
        $secondPreflight = Get-Content -LiteralPath ($migrationPrefix + 'preflight.sql') -Raw | & $mysql @migrationArgs $migrationDatabase
        if ($LASTEXITCODE -ne 0 -or @($secondPreflight | Where-Object { $_ -match '^ALREADY_COMPLIANT$' }).Count -ne 1) { throw 'CREDENTIAL_MIGRATION_IDEMPOTENCY_FAILED' }
        $preserved = & $mysql @migrationArgs $migrationDatabase -e "SELECT COUNT(*) FROM paypal_checkout_account WHERE Id=1 AND Note='preserve' AND Attivo=0 AND ClientId IS NULL AND ClientSecret IS NULL AND WebhookId IS NULL"
        if ($LASTEXITCODE -ne 0 -or ([string]$preserved).Trim() -ne '1') { throw 'CREDENTIAL_MIGRATION_PRESERVATION_FAILED' }
        'CREDENTIAL_MIGRATION_LAB=PASS'
    } finally {
        if ($migrationDatabase -match '^ks_paypal_credentials_[0-9a-f]{12}$') {
            & $mysql @migrationArgs -e ("DROP DATABASE IF EXISTS ``$migrationDatabase``") 2>$null | Out-Null
        }
    }

    $dependencies = @('MySql.Data.dll','Google.Protobuf.dll','BouncyCastle.Cryptography.dll',
        'System.Buffers.dll','System.Memory.dll','System.Runtime.CompilerServices.Unsafe.dll',
        'System.Threading.Tasks.Extensions.dll','System.Numerics.Vectors.dll','System.Formats.Asn1.dll')
    foreach ($dependency in $dependencies) {
        $source = Join-Path (Join-Path $RepositoryRoot 'Bin') $dependency
        Assert-LabFile $source
        Copy-Item -LiteralPath $source -Destination (Join-Path $binDirectory $dependency)
    }
    $redirects = foreach ($dependency in $dependencies) {
        $assembly = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $binDirectory $dependency))
        $token = [BitConverter]::ToString($assembly.GetPublicKeyToken()).Replace('-', '').ToLowerInvariant()
        if ($token) {
            '<dependentAssembly><assemblyIdentity name="' + $assembly.Name + '" publicKeyToken="' + $token +
                '" /><bindingRedirect oldVersion="0.0.0.0-' + $assembly.Version + '" newVersion="' +
                $assembly.Version + '" /></dependentAssembly>'
        }
    }
    $connection = 'Server=localhost;Database=' + $labName + ';Uid=root;Protocol=pipe;Pipe Name=' + $pipeName + ';Pooling=false;'
    $config = '<configuration><connectionStrings><add name="EntropicConnectionString" connectionString="' +
        (Escape-Xml $connection) + '" /></connectionStrings><system.web><compilation debug="false" targetFramework="4.8" />' +
        '<customErrors mode="Off" /></system.web><runtime><assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">' +
        ($redirects -join '') + '</assemblyBinding></runtime></configuration>'
    [IO.File]::WriteAllText((Join-Path $appDirectory 'web.config'), $config, [Text.Encoding]::UTF8)
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'paypalwebhook.aspx') -Destination (Join-Path $appDirectory 'paypalwebhook.aspx')
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'paypalwebhook.aspx.vb') -Destination (Join-Path $appDirectory 'paypalwebhook.aspx.vb')
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'paypalreturn.aspx.vb') -Destination (Join-Path $appDirectory 'paypalreturn.aspx.vb')
    [IO.File]::WriteAllText((Join-Path $appDirectory 'paypalreturn.aspx'),
        '<%@ Page Language="VB" AutoEventWireup="false" CodeFile="paypalreturn.aspx.vb" Inherits="paypalreturn" EnableViewState="false" ValidateRequest="true" %>',
        [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText((Join-Path $appDirectory 'seed.aspx'),
        '<%@ Page Language="VB" AutoEventWireup="false" CodeFile="seed.aspx.vb" Inherits="seed" %>',
        [Text.Encoding]::UTF8)
    $seedSource = @'
Partial Public Class seed
    Inherits System.Web.UI.Page
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Session("LoginId") = 501
        Session("UtentiId") = 101
        Response.Write("SEED")
    End Sub
End Class
'@
    [IO.File]::WriteAllText((Join-Path $appDirectory 'seed.aspx.vb'), $seedSource, [Text.Encoding]::UTF8)

    $assemblyPath = Join-Path $binDirectory 'PayPalWebhookFlowHarness.dll'
    $sources = @(
        'Tools\PayPalWebhookFlowHarness.vb',
        'App_Code\PayPalCheckoutConfig.vb',
        'App_Code\PayPalCheckoutRepository.vb',
        'App_Code\PayPalOrdersV2Client.vb',
        'App_Code\PayPalPaymentState.vb',
        'App_Code\PayPalCheckoutSafetyPolicy.vb',
        'App_Code\StorefrontCanonicalHostPolicy.vb',
        'App_Code\StorefrontSeoTenantContext.vb',
        'App_Code\PayPalAttemptPolicy.vb') | ForEach-Object { Join-Path $RepositoryRoot $_ }
    & $compiler /nologo /target:library /define:PAYPAL_WEBHOOK_HARNESS=True /out:$assemblyPath `
        /r:System.dll /r:System.Core.dll /r:System.Data.dll /r:System.Configuration.dll `
        /r:System.Web.dll /r:System.Web.Extensions.dll /r:$library $sources
    if ($LASTEXITCODE -ne 0) { throw 'WEBHOOK_FLOW_COMPILE_FAILED' }

    $runnerPath = Join-Path $binDirectory 'PayPalWebhookFlowRunner.exe'
    & $compiler /nologo /target:exe /define:PAYPAL_WEBHOOK_RUNNER=True /out:$runnerPath `
        /r:System.dll /r:System.Web.dll /r:$assemblyPath (Join-Path $RepositoryRoot 'Tools\PayPalWebhookFlowHarness.vb')
    if ($LASTEXITCODE -ne 0) { throw 'WEBHOOK_FLOW_RUNNER_COMPILE_FAILED' }

    & $runnerPath $appDirectory
    $runnerExit = $LASTEXITCODE
    $cleanupQuery = "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='" + $labName + "'"
    $remainingLab = & $mysql --no-defaults --protocol=pipe --socket=$pipeName -uroot -N -s -e $cleanupQuery 2>$null
    if ($LASTEXITCODE -ne 0 -or ([string]$remainingLab).Trim() -ne '0') { throw 'WEBHOOK_LAB_DATABASE_NOT_CLEAN' }
    'WEBHOOK_LAB_DATABASE_CLEAN=PASS'
    if ($runnerExit -ne 0) { throw 'WEBHOOK_FLOW_FAILED' }
} finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        if ($ownedPipe) { & $mysqladmin --no-defaults --protocol=pipe --socket=$pipeName -uroot shutdown 2>$null | Out-Null }
        if (-not $serverProcess.WaitForExit(10000)) { Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue }
    }
    if (Test-Path -LiteralPath $tempDirectory -PathType Container) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempDirectory)
        if ($resolvedTemp.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolvedTemp) -like 'ks-paypal-webhook-*') {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
