[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TestRoot,
    [string]$ConsumerProbePath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'DBCFG_TEST_WINDOWS_POWERSHELL_51_REQUIRED' }
if ((Get-ExecutionPolicy) -ne 'RemoteSigned') { throw 'DBCFG_TEST_PROCESS_REMOTESIGNED_REQUIRED' }
. (Join-Path $PSScriptRoot 'Import-KeepStoreConfigurationReader.ps1')
Import-KeepStoreConfigurationReader
. (Join-Path $PSScriptRoot 'Set-DatabaseProtectedConfiguration.ps1')
Add-Type -AssemblyName System.Security

$testBase = [IO.Path]::GetFullPath($TestRoot)
$allowedBase = [IO.Path]::GetFullPath('C:\Temp\KeepStoreDbConfigHardening1A') + '\'
if (-not ($testBase + '\').StartsWith($allowedBase, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $testBase -PathType Container)) { throw 'DBCFG_TEST_ROOT_NOT_AUTHORIZED' }
$runPath = Join-Path $testBase ('native-' + [Guid]::NewGuid().ToString('N'))
$resourceRecord = Join-Path $testBase ('native-resources-' + [Guid]::NewGuid().ToString('N') + '.json')
$resources = New-Object Collections.Generic.List[object]
$assertions = 0
$keyObjects = New-Object Collections.Generic.List[object]
$synthetic = 'Server=fixture.invalid;Database=synthetic;User Id=synthetic;Password=KS-DBCFG-FIXTURE-ONLY;Pooling=false'
$providerName = 'KeepStoreSyntheticRsa'
$keyName = 'KS-DBCFG-TEST-' + [Guid]::NewGuid().ToString('D')
$wrongKeyName = 'KS-DBCFG-TEST-' + [Guid]::NewGuid().ToString('D')

function Record-Resource([string]$Kind, [string]$Name) {
    $resources.Add([pscustomobject]@{ Kind = $Kind; Name = $Name; State = 'PLANNED' })
    [IO.File]::WriteAllText($resourceRecord, (ConvertTo-Json -InputObject @($resources.ToArray()) -Depth 4))
}
function Assert-True([bool]$Value, [string]$Label) {
    if (-not $Value) { throw ('DBCFG_TEST_FAILED_' + $Label) }
    $script:assertions++
}
function Assert-Rejected([scriptblock]$Action, [string]$Label) {
    $rejected = $false
    try { & $Action | Out-Null } catch {
        $rejected = $true
        if ($_.Exception.ToString().Contains('KS-DBCFG-FIXTURE-ONLY')) { throw 'DBCFG_TEST_SECRET_IN_EXCEPTION' }
        if ($_.Exception.Message -notmatch 'DBCFG_[A-Z0-9_]+') { throw ('DBCFG_TEST_UNEXPECTED_ERROR_' + $Label) }
    }
    Assert-True $rejected $Label
}
function Write-Fixture([string]$Name, [string]$Body) {
    $directory = Join-Path $runPath $Name
    Record-Resource 'Directory' $directory
    [void][IO.Directory]::CreateDirectory($directory)
    $path = Join-Path $directory 'web.config'
    Record-Resource 'File' $path
    [IO.File]::WriteAllText($path, $Body, (New-Object Text.UTF8Encoding($false)))
    return $path
}
function Get-FixtureXml([string]$ConnectionBody, [string]$Container = $keyName) {
    return '<configuration><configProtectedData><providers><add name="' + $providerName + '" type="System.Configuration.RsaProtectedConfigurationProvider, System.Configuration, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" keyContainerName="' + $Container + '" useMachineContainer="false" useOAEP="false" /></providers></configProtectedData><connectionStrings><clear/>' + $ConnectionBody + '</connectionStrings></configuration>'
}
function New-TestKey([string]$Name) {
    Record-Resource 'CurrentUserRsaKey' $Name
    $csp = New-Object Security.Cryptography.CspParameters
    $csp.KeyContainerName = $Name
    $key = New-Object Security.Cryptography.RSACryptoServiceProvider(2048, $csp)
    $key.PersistKeyInCsp = $true
    $keyObjects.Add($key)
    return $key
}
function Write-ProtectedBytes([string]$Path, [byte[]]$Bytes) {
    Record-Resource 'DpapiFile' $Path
    [IO.File]::WriteAllBytes($Path, [Security.Cryptography.ProtectedData]::Protect($Bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
}
function Make-Recovery([string]$Path, $Key, [string]$Prefix) {
    $backup = Join-Path $runPath ($Prefix + '-config.dpapi')
    $recovery = Join-Path $runPath ($Prefix + '-key.dpapi')
    Write-ProtectedBytes $backup ([IO.File]::ReadAllBytes($Path))
    $keyBytes = [Text.Encoding]::UTF8.GetBytes($Key.ToXmlString($true))
    try { Write-ProtectedBytes $recovery $keyBytes } finally { [Array]::Clear($keyBytes, 0, $keyBytes.Length) }
    return @{ EncryptedBackupPath = $backup; EncryptedRecoveryKeyPath = $recovery }
}

$completed = $false
try {
    Record-Resource 'Directory' $runPath
    [void][IO.Directory]::CreateDirectory($runPath)
    $key = New-TestKey $keyName
    $wrongKey = New-TestKey $wrongKeyName
    $entry = '<add name="EntropicConnectionString" providerName="MySql.Data.MySqlClient" connectionString="' + $synthetic + '" />'
    $other = '<add name="taikun" providerName="MySql.Data.MySqlClient" connectionString="Server=other.invalid;Database=other;User Id=other" />'
    $plain = Write-Fixture 'plain' (Get-FixtureXml ($other + $entry))
    Assert-True ([KeepStoreConfigurationReader]::ReadConnectionStringFromFile($plain) -ceq $synthetic) 'NAMED_ORDER'
    Assert-True ([KeepStoreConfigurationReader]::ReadConnectionString((Split-Path -Parent $plain)) -ceq $synthetic) 'APPLICATION_ROOT'
    $aliasOnly = Write-Fixture 'alias' (Get-FixtureXml $other)
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($aliasOnly) } 'NO_ALIAS_FALLBACK'
    $empty = Write-Fixture 'empty' (Get-FixtureXml '')
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($empty) } 'NO_POSITION_FALLBACK'
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile((Join-Path $runPath 'missing.config')) } 'MISSING_FILE'
    $zero = Write-Fixture 'zero' ''
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($zero) } 'EMPTY_FILE'
    $malformed = Write-Fixture 'malformed' '<configuration><connectionStrings>'
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($malformed) } 'MALFORMED_XML'
    $invalidProvider = Write-Fixture 'provider' (Get-FixtureXml ($entry.Replace('MySql.Data.MySqlClient', 'System.Data.SqlClient')))
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($invalidProvider) } 'WRONG_PROVIDER'
    $invalidValue = Write-Fixture 'invalid-value' (Get-FixtureXml ($entry.Replace($synthetic, 'InvalidKeyword=KS-DBCFG-FIXTURE-ONLY')))
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($invalidValue) } 'INVALID_SYNTAX'
    $blankValue = Write-Fixture 'blank-value' (Get-FixtureXml ($entry.Replace($synthetic, '')))
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($blankValue) } 'BLANK_CONNECTION'
    $implicitServer = Write-Fixture 'implicit-server' (Get-FixtureXml ($entry.Replace($synthetic, 'Database=synthetic;User Id=synthetic')))
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($implicitServer) } 'NO_IMPLICIT_SERVER'
    $external = Write-Fixture 'external' '<configuration><connectionStrings configSource="connections.config" /></configuration>'
    $externalPath = Join-Path (Split-Path -Parent $external) 'connections.config'
    Record-Resource 'File' $externalPath
    [IO.File]::WriteAllText($externalPath, ('<connectionStrings>' + $entry + '</connectionStrings>'))
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($external) } 'EXTERNAL_ORIGIN'
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($plain, ' EntropicConnectionString') } 'INVALID_NAME'
    # A name available only through machine.config cannot be used as a target entry.
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($empty, 'LocalSqlServer') } 'INHERITED_ENTRY'

    $parameters = @{ ConfigPath = $plain; ProviderName = $providerName; KeyContainerName = $keyName; KeyScope = 'CurrentUser' }
    $before = [IO.File]::ReadAllBytes($plain)
    $result = Invoke-KeepStoreDatabaseProtection @parameters
    Assert-True ($result.Status -eq 'VERIFIED' -and -not $result.Changed) 'DEFAULT_VERIFY'
    Assert-True ([Convert]::ToBase64String($before) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($plain))) 'DEFAULT_NO_WRITE'
    $protectionScript = Join-Path $PSScriptRoot 'Set-DatabaseProtectedConfiguration.ps1'
    $windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $cliOutput = @(& $windowsPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File $protectionScript -ConfigPath $plain -ProviderName $providerName -KeyContainerName $keyName)
    Assert-True ($LASTEXITCODE -eq 0 -and -not (($cliOutput -join ' ').Contains('KS-DBCFG-FIXTURE-ONLY'))) 'CLI_DEFAULT'
    Assert-True ([Convert]::ToBase64String($before) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($plain))) 'CLI_NO_WRITE'
    Assert-Rejected { Invoke-KeepStoreDatabaseProtection -ProviderName $providerName -KeyContainerName $keyName } 'EXPLICIT_TARGET'
    Assert-Rejected { Invoke-KeepStoreDatabaseProtection @parameters -Apply } 'APPLY_REQUIRES_RECOVERY'
    $recovery = Make-Recovery $plain $key 'primary'
    $badRecovery = Make-Recovery $plain $wrongKey 'wrong'
    Assert-Rejected { Invoke-KeepStoreDatabaseProtection @parameters -Apply @badRecovery } 'RECOVERY_KEY_MISMATCH'
    $mismatchingBackup = Join-Path $runPath 'mismatching-config.dpapi'
    Write-ProtectedBytes $mismatchingBackup ([Text.Encoding]::UTF8.GetBytes('<configuration />'))
    $badBackup = $recovery.Clone()
    $badBackup.EncryptedBackupPath = $mismatchingBackup
    Assert-Rejected { Invoke-KeepStoreDatabaseProtection @parameters -Apply @badBackup } 'BACKUP_MISMATCH'
    $wrongScope = $parameters.Clone()
    $wrongScope.KeyScope = 'LocalMachine'
    Assert-Rejected { Invoke-KeepStoreDatabaseProtection @wrongScope } 'SCOPE_MISMATCH'
    $incompatibleProviderConfig = Write-Fixture 'incompatible-protection-provider' ((Get-FixtureXml $entry).Replace('System.Configuration.RsaProtectedConfigurationProvider,', 'System.Configuration.DpapiProtectedConfigurationProvider,'))
    $incompatibleProviderParameters = $parameters.Clone()
    $incompatibleProviderParameters.ConfigPath = $incompatibleProviderConfig
    Assert-Rejected { Invoke-KeepStoreDatabaseProtection @incompatibleProviderParameters } 'NON_RSA_PROTECTION_PROVIDER'
    $corruptRecoveryPath = Join-Path $runPath 'corrupt-recovery.dpapi'
    Record-Resource 'DpapiFile' $corruptRecoveryPath
    [IO.File]::WriteAllBytes($corruptRecoveryPath, [byte[]]@(1, 2, 3, 4))
    $corruptRecovery = $recovery.Clone()
    $corruptRecovery.EncryptedRecoveryKeyPath = $corruptRecoveryPath
    Assert-Rejected { Invoke-KeepStoreDatabaseProtection @parameters -Apply @corruptRecovery } 'RECOVERY_DECRYPT_REQUIRED'
    Assert-True ([Convert]::ToBase64String($before) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($plain))) 'FAILED_PREREQUISITES_NO_WRITE'
    $result = Invoke-KeepStoreDatabaseProtection @parameters -Apply @recovery
    Assert-True ($result.Status -eq 'PROTECTED' -and $result.Changed) 'NATIVE_RSA_APPLY'
    Assert-True ([KeepStoreConfigurationReader]::ReadConnectionStringFromFile($plain) -ceq $synthetic) 'NATIVE_RSA_READ'
    Assert-True (-not [IO.File]::ReadAllText($plain).Contains('KS-DBCFG-FIXTURE-ONLY')) 'NO_PLAINTEXT_SECTION'
    $protectedBefore = [IO.File]::ReadAllBytes($plain)
    $result = Invoke-KeepStoreDatabaseProtection @parameters -Apply
    Assert-True ($result.Status -eq 'ALREADY_PROTECTED' -and -not $result.Changed) 'IDEMPOTENT_APPLY'
    Assert-True ([Convert]::ToBase64String($protectedBefore) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($plain))) 'IDEMPOTENT_BYTES'
    $wrongProtected = Write-Fixture 'wrong-key' ([IO.File]::ReadAllText($plain).Replace($keyName, $wrongKeyName))
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($wrongProtected) } 'WRONG_RSA_KEY'
    $absentName = 'KS-DBCFG-TEST-' + [Guid]::NewGuid().ToString('D')
    Record-Resource 'CurrentUserRsaKey' $absentName
    $missingProtected = Write-Fixture 'missing-key' ([IO.File]::ReadAllText($plain).Replace($keyName, $absentName))
    # RSA decrypt must fail rather than return clear text or another configuration.
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($missingProtected) } 'MISSING_RSA_KEY'
    # Reader preflights UseExistingKey before native decryption: absence stays absence.
    $missingCsp = New-Object Security.Cryptography.CspParameters
    $missingCsp.KeyContainerName = $absentName
    $missingCsp.Flags = [Security.Cryptography.CspProviderFlags]::UseExistingKey
    $unexpectedKey = $false
    try { $missingKey = New-Object Security.Cryptography.RSACryptoServiceProvider($missingCsp); $unexpectedKey = $true; $missingKey.PersistKeyInCsp = $false; $missingKey.Dispose() } catch { }
    Assert-True (-not $unexpectedKey) 'MISSING_KEY_NOT_CREATED'
    $corruptText = [IO.File]::ReadAllText($plain) -replace '(<CipherValue>)[^<]+', '${1}AAAA'
    $corrupt = Write-Fixture 'corrupt' $corruptText
    Assert-Rejected { [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($corrupt) } 'CORRUPT_CIPHERTEXT'
    $incompatible = $parameters.Clone()
    $incompatible.ProviderName = 'OtherDedicatedProvider'
    Assert-Rejected { Invoke-KeepStoreDatabaseProtection @incompatible } 'INCOMPATIBLE_PROVIDER'

    # Restore a deleted synthetic user key solely from the protected recovery bytes.
    $key.PersistKeyInCsp = $false
    $key.Dispose()
    $restoreBytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($recovery.EncryptedRecoveryKeyPath), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    try {
        $csp = New-Object Security.Cryptography.CspParameters
        $csp.KeyContainerName = $keyName
        $restoredKey = New-Object Security.Cryptography.RSACryptoServiceProvider($csp)
        $restoredKey.PersistKeyInCsp = $true
        $restoredKey.FromXmlString([Text.Encoding]::UTF8.GetString($restoreBytes))
        $keyObjects.Add($restoredKey)
    } finally { [Array]::Clear($restoreBytes, 0, $restoreBytes.Length) }
    Assert-True ([KeepStoreConfigurationReader]::ReadConnectionStringFromFile($plain) -ceq $synthetic) 'KEY_RECOVERY'
    $restoredConfig = Write-Fixture 'config-recovery' '<configuration />'
    $restoredBytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($recovery.EncryptedBackupPath), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    try { [IO.File]::WriteAllBytes($restoredConfig, $restoredBytes) } finally { [Array]::Clear($restoredBytes, 0, $restoredBytes.Length) }
    Assert-True ([KeepStoreConfigurationReader]::ReadConnectionStringFromFile($restoredConfig) -ceq $synthetic) 'CONFIG_RECOVERY'

    $rollbackConfig = Write-Fixture 'rollback' (Get-FixtureXml $entry)
    $rollbackRecovery = Make-Recovery $rollbackConfig $restoredKey 'rollback'
    $rollbackBefore = [IO.File]::ReadAllBytes($rollbackConfig)
    $rollbackMeta = Get-Item -LiteralPath $rollbackConfig
    $rollbackAcl = (Get-Acl -LiteralPath $rollbackConfig).Sddl
    # Replace only the I/O boundary in this test scope; execute the real catch/rollback.
    $savedWriter = ${function:Save-KeepStoreProtectedConfiguration}
    function Save-KeepStoreProtectedConfiguration($Configuration) {
        [IO.File]::WriteAllText($Configuration.FilePath, 'SYNTHETIC_PARTIAL_WRITE')
        throw 'SYNTHETIC_IO_FAILURE'
    }
    try {
        Assert-Rejected { Invoke-KeepStoreDatabaseProtection -ConfigPath $rollbackConfig -ProviderName $providerName -KeyContainerName $keyName -Apply @rollbackRecovery } 'FAILURE_ROLLBACK'
    } finally { ${function:Save-KeepStoreProtectedConfiguration} = $savedWriter }
    Assert-True ([Convert]::ToBase64String($rollbackBefore) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($rollbackConfig))) 'ROLLBACK_BYTES'
    Assert-True ((Get-Acl -LiteralPath $rollbackConfig).Sddl -ceq $rollbackAcl) 'ROLLBACK_ACL'
    $afterMeta = Get-Item -LiteralPath $rollbackConfig
    Assert-True ($afterMeta.Attributes -eq $rollbackMeta.Attributes -and $afterMeta.CreationTimeUtc -eq $rollbackMeta.CreationTimeUtc -and $afterMeta.LastWriteTimeUtc -eq $rollbackMeta.LastWriteTimeUtc) 'ROLLBACK_METADATA'

    if (-not [string]::IsNullOrWhiteSpace($ConsumerProbePath)) {
        $probe = [IO.Path]::GetFullPath($ConsumerProbePath)
        if (-not ($probe.StartsWith($testBase + '\', [StringComparison]::OrdinalIgnoreCase)) -or -not (Test-Path -LiteralPath $probe -PathType Leaf)) { throw 'DBCFG_TEST_PROBE_PATH_INVALID' }
        & $probe -PlainConfigPath $restoredConfig -ProtectedConfigPath $plain
        if (-not $?) { throw 'DBCFG_TEST_CONSUMER_PROBE_FAILED' }
        $assertions++
    }
    $completed = $true
} catch {
    $code = [string]$_.Exception.Message
    Write-Verbose ('DBCFG_TEST_FAILURE_TYPE=' + $_.Exception.GetType().Name + ';LINE=' + $_.InvocationInfo.ScriptLineNumber)
    $baseError = $_.Exception.GetBaseException()
    $baseCode = if ($baseError.Message -cmatch '^[A-Z][A-Z0-9_]+$') { $baseError.Message } else { 'REDACTED' }
    Write-Verbose ('DBCFG_TEST_FAILURE_BASE=' + $baseError.GetType().Name + ';CODE=' + $baseCode)
    Write-Verbose $_.ScriptStackTrace
    if ($_.Exception -is [Management.Automation.ParseException]) {
        foreach ($parseError in @($_.Exception.Errors | Select-Object -First 3)) {
            Write-Verbose ('DBCFG_TEST_PARSE=' + $parseError.ErrorId + ';FILE=' + [IO.Path]::GetFileName($parseError.Extent.File) + ';LINE=' + $parseError.Extent.StartLineNumber)
        }
    }
    if ($code -notmatch '^DBCFG_[A-Z0-9_]+$') { $code = 'DBCFG_TEST_FAILED' }
    throw $code
} finally {
    $cleanupFailed = $false
    foreach ($ownedKey in $keyObjects) {
        try { $ownedKey.PersistKeyInCsp = $false; $ownedKey.Dispose() } catch { }
    }
    foreach ($resource in $resources) {
        if ($resource.Kind -eq 'CurrentUserRsaKey') {
            try {
                $cleanupCsp = New-Object Security.Cryptography.CspParameters
                $cleanupCsp.KeyContainerName = $resource.Name
                $cleanupCsp.Flags = [Security.Cryptography.CspProviderFlags]::UseExistingKey
                $cleanupKey = New-Object Security.Cryptography.RSACryptoServiceProvider($cleanupCsp)
                $cleanupKey.PersistKeyInCsp = $false
                $cleanupKey.Dispose()
            } catch { }
            try {
                $verifyCsp = New-Object Security.Cryptography.CspParameters
                $verifyCsp.KeyContainerName = $resource.Name
                $verifyCsp.Flags = [Security.Cryptography.CspProviderFlags]::UseExistingKey
                $remainingKey = New-Object Security.Cryptography.RSACryptoServiceProvider($verifyCsp)
                $remainingKey.PersistKeyInCsp = $false
                $remainingKey.Dispose()
                $cleanupFailed = $true
            } catch { }
        }
    }
    $resolvedRun = [IO.Path]::GetFullPath($runPath)
    if (-not $resolvedRun.StartsWith($testBase + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'DBCFG_TEST_CLEANUP_PATH_INVALID' }
    if (Test-Path -LiteralPath $resolvedRun) { Remove-Item -LiteralPath $resolvedRun -Recurse -Force }
    if (Test-Path -LiteralPath $resolvedRun) { $cleanupFailed = $true }
    foreach ($resource in $resources) { $resource.State = if ($cleanupFailed) { 'CLEANUP_FAILED' } else { 'CLEANED' } }
    [IO.File]::WriteAllText($resourceRecord, (ConvertTo-Json -InputObject @($resources.ToArray()) -Depth 4))
    if ($cleanupFailed) { throw 'DBCFG_TEST_CLEANUP_FAILED' }
}
if ($completed) {
    [pscustomobject]@{ Status = 'PASS'; Assertions = $assertions; NativeRsa = $true; Recovery = $true; Cleanup = $true; ResourceRecord = $resourceRecord }
}
