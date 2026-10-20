[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$ProviderName,
    [string]$KeyContainerName,
    [ValidateSet('CurrentUser', 'LocalMachine')][string]$KeyScope = 'CurrentUser',
    [switch]$Apply,
    [string]$EncryptedBackupPath,
    [string]$EncryptedRecoveryKeyPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Import-KeepStoreConfigurationReader.ps1')

function Save-KeepStoreProtectedConfiguration($Configuration) {
    $Configuration.Save([Configuration.ConfigurationSaveMode]::Modified)
}

function Invoke-KeepStoreDatabaseProtection {
    [CmdletBinding()]
    param(
        [string]$ConfigPath, [string]$ProviderName, [string]$KeyContainerName,
        [ValidateSet('CurrentUser', 'LocalMachine')][string]$KeyScope = 'CurrentUser',
        [switch]$Apply, [string]$EncryptedBackupPath, [string]$EncryptedRecoveryKeyPath
    )
    $rsa = $null
    $recovered = $null
    $original = $null
    $backupPlain = $null
    $recoveryPlain = $null
    $changed = $false
    $target = $null
    try {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw 'DBCFG_TARGET_REQUIRED' }
        if ($ProviderName -notmatch '^[A-Za-z][A-Za-z0-9_.-]{2,100}$' -or $ProviderName -eq 'RsaProtectedConfigurationProvider') { throw 'DBCFG_DEDICATED_PROVIDER_REQUIRED' }
        if ([string]::IsNullOrWhiteSpace($KeyContainerName) -or $KeyContainerName -match '^(NetFrameworkConfigurationKey|iisWasKey|iisConfigurationKey)$') { throw 'DBCFG_DEDICATED_KEY_REQUIRED' }
        Import-KeepStoreConfigurationReader
        Add-Type -AssemblyName System.Security
        $target = [KeepStoreConfigurationReader]::ValidateConfigurationPath($ConfigPath)
        $configuration = [KeepStoreConfigurationReader]::OpenConfiguration($target)
        [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($target) | Out-Null
        $section = $configuration.GetSection('connectionStrings')
        if (-not [string]::IsNullOrEmpty($section.SectionInformation.ConfigSource)) { throw 'DBCFG_EXTERNAL_SOURCE_REJECTED' }
        $providers = $configuration.GetSection('configProtectedData')
        $settings = $providers.Providers[$ProviderName]
        if ($null -eq $settings) { throw 'DBCFG_PROVIDER_MISSING' }
        if ($settings.ElementInformation.Source -ine $target) { throw 'DBCFG_PROVIDER_ORIGIN_INVALID' }
        $providerType = [Type]::GetType($settings.Type, $false)
        if ($providerType -ne [Configuration.RsaProtectedConfigurationProvider]) { throw 'DBCFG_PROVIDER_INCOMPATIBLE' }
        if ($settings.Parameters['keyContainerName'] -cne $KeyContainerName) { throw 'DBCFG_KEY_MISMATCH' }
        $machineValue = $false
        if (-not [bool]::TryParse($settings.Parameters['useMachineContainer'], [ref]$machineValue)) { throw 'DBCFG_SCOPE_REQUIRED' }
        if ($machineValue -ne ($KeyScope -eq 'LocalMachine')) { throw 'DBCFG_SCOPE_MISMATCH' }
        if ($section.SectionInformation.IsProtected -and $section.SectionInformation.ProtectionProvider.Name -cne $ProviderName) { throw 'DBCFG_PROVIDER_INCOMPATIBLE' }

        # UseExistingKey is essential: validation must never create a missing key.
        $csp = New-Object Security.Cryptography.CspParameters
        $csp.KeyContainerName = $KeyContainerName
        $csp.Flags = [Security.Cryptography.CspProviderFlags]::UseExistingKey
        if ($machineValue) { $csp.Flags = $csp.Flags -bor [Security.Cryptography.CspProviderFlags]::UseMachineKeyStore }
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider($csp)
        if (-not $Apply) { return [pscustomobject]@{ Status = 'VERIFIED'; Protected = [bool]$section.SectionInformation.IsProtected; Changed = $false } }
        if ($section.SectionInformation.IsProtected) { return [pscustomobject]@{ Status = 'ALREADY_PROTECTED'; Protected = $true; Changed = $false } }
        if ([string]::IsNullOrWhiteSpace($EncryptedBackupPath) -or [string]::IsNullOrWhiteSpace($EncryptedRecoveryKeyPath)) { throw 'DBCFG_RECOVERY_REQUIRED' }
        $backupPath = [KeepStoreConfigurationReader]::ValidateConfigurationPath($EncryptedBackupPath)
        $recoveryPath = [KeepStoreConfigurationReader]::ValidateConfigurationPath($EncryptedRecoveryKeyPath)
        if ($target -eq $backupPath -or $target -eq $recoveryPath -or $backupPath -eq $recoveryPath) { throw 'DBCFG_RECOVERY_PATH_INVALID' }
        $original = [IO.File]::ReadAllBytes($target)
        $backupPlain = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($backupPath), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        if ([Convert]::ToBase64String($original) -cne [Convert]::ToBase64String($backupPlain)) { throw 'DBCFG_BACKUP_MISMATCH' }
        $recoveryPlain = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($recoveryPath), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $recovered = New-Object Security.Cryptography.RSACryptoServiceProvider
        $recovered.PersistKeyInCsp = $false
        $recovered.FromXmlString([Text.Encoding]::UTF8.GetString($recoveryPlain))
        if ($recovered.PublicOnly -or $recovered.ToXmlString($false) -cne $rsa.ToXmlString($false)) { throw 'DBCFG_RECOVERY_KEY_MISMATCH' }
        $metadata = Get-Item -LiteralPath $target
        $attributes = $metadata.Attributes
        $created = $metadata.CreationTimeUtc
        $written = $metadata.LastWriteTimeUtc
        $accessed = $metadata.LastAccessTimeUtc
        $acl = Get-Acl -LiteralPath $target
        try {
            $section.SectionInformation.ProtectSection($ProviderName)
            $section.SectionInformation.ForceSave = $true
            $changed = $true
            Save-KeepStoreProtectedConfiguration $configuration
            [KeepStoreConfigurationReader]::ReadConnectionStringFromFile($target) | Out-Null
            $check = [KeepStoreConfigurationReader]::OpenConfiguration($target).GetSection('connectionStrings')
            if (-not $check.SectionInformation.IsProtected -or $check.SectionInformation.ProtectionProvider.Name -cne $ProviderName) { throw 'DBCFG_POSTCHECK_FAILED' }
            Set-Acl -LiteralPath $target -AclObject $acl
            [IO.File]::SetAttributes($target, $attributes)
            return [pscustomobject]@{ Status = 'PROTECTED'; Protected = $true; Changed = $true }
        } catch {
            if ($changed) {
                try {
                    if (Test-Path -LiteralPath $target) { [IO.File]::SetAttributes($target, [IO.FileAttributes]::Normal) }
                    [IO.File]::WriteAllBytes($target, $original)
                    Set-Acl -LiteralPath $target -AclObject $acl
                    [IO.File]::SetCreationTimeUtc($target, $created)
                    [IO.File]::SetLastWriteTimeUtc($target, $written)
                    [IO.File]::SetLastAccessTimeUtc($target, $accessed)
                    [IO.File]::SetAttributes($target, $attributes)
                    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($target)) -cne [Convert]::ToBase64String($original)) { throw 'DBCFG_ROLLBACK_FAILED' }
                    $restoredMetadata = Get-Item -LiteralPath $target
                    if ((Get-Acl -LiteralPath $target).Sddl -cne $acl.Sddl -or $restoredMetadata.Attributes -ne $attributes -or $restoredMetadata.CreationTimeUtc -ne $created -or $restoredMetadata.LastWriteTimeUtc -ne $written) { throw 'DBCFG_ROLLBACK_FAILED' }
                } catch { throw 'DBCFG_ROLLBACK_FAILED' }
            }
            throw 'DBCFG_APPLY_FAILED_ROLLED_BACK'
        }
    } catch {
        $code = [string]$_.Exception.Message
        if ($code -notmatch '^DBCFG_[A-Z0-9_]+$') { $code = 'DBCFG_PROTECTION_FAILED' }
        throw $code
    } finally {
        if ($recovered) { $recovered.Dispose() }
        if ($rsa) { $rsa.Dispose() }
        foreach ($buffer in @($original, $backupPlain, $recoveryPlain)) {
            if ($null -ne $buffer) { [Array]::Clear($buffer, 0, $buffer.Length) }
        }
        # CLR strings cannot be reliably wiped; never print or persist decrypted material.
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-KeepStoreDatabaseProtection @PSBoundParameters
}
