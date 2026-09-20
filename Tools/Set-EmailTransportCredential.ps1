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

    [string]$ApplicationPoolName = 'KeepStoreSmoke',

    [ValidatePattern('^dpapi-v1:[0-9a-f]{64}:[1-9][0-9]{0,9}:(TRANSACTIONAL|MARKETING):[0-9a-f]{32}$')]
    [string]$CredentialReference,

    [string]$CredentialRoot = 'C:\ProgramData\KeepStore\EmailCredentials'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Security

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'EMAIL_CREDENTIAL_ADMINISTRATOR_REQUIRED'
    }
}

function Get-DatabaseIdentityFromConnectionString([string]$Value, [string]$MySqlAssemblyPath) {
    if ([string]::IsNullOrWhiteSpace($Value)) { throw 'EMAIL_DATABASE_CONFIGURATION_INVALID' }
    if (-not ('MySql.Data.MySqlClient.MySqlConnectionStringBuilder' -as [type])) {
        if (-not (Test-Path -LiteralPath $MySqlAssemblyPath -PathType Leaf)) { throw 'EMAIL_DATABASE_PROVIDER_MISSING' }
        [Reflection.Assembly]::LoadFrom($MySqlAssemblyPath) | Out-Null
    }

    try {
        $builder = New-Object MySql.Data.MySqlClient.MySqlConnectionStringBuilder($Value)
        $server = [Convert]::ToString($builder.Server).Trim().ToLowerInvariant()
        $database = [Convert]::ToString($builder.Database).Trim().ToLowerInvariant()
        if ($server.Length -eq 0 -or $database.Length -eq 0) { throw 'EMAIL_DATABASE_CONFIGURATION_INVALID' }
        $material = $server + '|' + ([uint32]$builder.Port).ToString([Globalization.CultureInfo]::InvariantCulture) + '|' + $database
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($material)))).Replace('-', '').ToLowerInvariant()
        } finally {
            $sha.Dispose()
            $material = $null
        }
    } catch {
        if ($_.Exception.Message -eq 'EMAIL_DATABASE_CONFIGURATION_INVALID') { throw }
        throw 'EMAIL_DATABASE_CONFIGURATION_INVALID'
    } finally {
        $Value = $null
    }
}

function Get-ApplicationDatabaseIdentity([string]$Root, [string]$Name) {
    $webConfigPath = Join-Path ([IO.Path]::GetFullPath($Root)) 'web.config'
    if (-not (Test-Path -LiteralPath $webConfigPath -PathType Leaf)) { throw 'EMAIL_WEB_CONFIG_NOT_FOUND' }
    $configuredValue = $null
    $configuration = $null
    try {
        [xml]$configuration = Get-Content -LiteralPath $webConfigPath -Raw
        $matches = @($configuration.configuration.connectionStrings.add | Where-Object { $_.name -ceq $Name })
        if ($matches.Count -ne 1) { throw 'EMAIL_CONNECTION_STRING_NOT_UNIQUE' }
        $configuredValue = [Convert]::ToString($matches[0].connectionString)
        return Get-DatabaseIdentityFromConnectionString $configuredValue (Join-Path $Root 'Bin\MySql.Data.dll')
    } catch {
        if ($_.Exception.Message -match '^EMAIL_[A-Z0-9_]+$') { throw }
        throw 'EMAIL_WEB_CONFIG_INVALID'
    } finally {
        $configuredValue = $null
        $configuration = $null
    }
}

function Get-ApplicationPoolIdentitySid([string]$PoolName) {
    $assemblyPath = Join-Path $env:windir 'System32\inetsrv\Microsoft.Web.Administration.dll'
    if (-not (Test-Path -LiteralPath $assemblyPath -PathType Leaf)) { throw 'EMAIL_IIS_ADMINISTRATION_UNAVAILABLE' }
    [Reflection.Assembly]::LoadFrom($assemblyPath) | Out-Null
    $manager = New-Object Microsoft.Web.Administration.ServerManager
    $account = $null
    try {
        $pool = $manager.ApplicationPools[$PoolName]
        if ($null -eq $pool) { throw 'EMAIL_APPLICATION_POOL_NOT_FOUND' }
        $identityType = [Convert]::ToString($pool.ProcessModel.IdentityType)
        switch ($identityType) {
            'ApplicationPoolIdentity' { $account = 'IIS AppPool\' + $PoolName }
            'LocalSystem' { $account = 'NT AUTHORITY\SYSTEM' }
            'LocalService' { $account = 'NT AUTHORITY\LOCAL SERVICE' }
            'NetworkService' { $account = 'NT AUTHORITY\NETWORK SERVICE' }
            'SpecificUser' {
                $account = [Convert]::ToString($pool.ProcessModel.UserName)
                if ([string]::IsNullOrWhiteSpace($account)) { throw 'EMAIL_APPLICATION_POOL_IDENTITY_INVALID' }
            }
            default { throw 'EMAIL_APPLICATION_POOL_IDENTITY_UNSUPPORTED' }
        }
        return (New-Object Security.Principal.NTAccount($account)).Translate([Security.Principal.SecurityIdentifier])
    } catch {
        if ($_.Exception.Message -match '^EMAIL_[A-Z0-9_]+$') { throw }
        throw 'EMAIL_APPLICATION_POOL_IDENTITY_UNRESOLVED'
    } finally {
        $account = $null
        if ($manager) { $manager.Dispose() }
    }
}

function Get-RequiredStoreSids([Security.Principal.SecurityIdentifier]$PoolSid) {
    $values = New-Object 'Collections.Generic.List[Security.Principal.SecurityIdentifier]'
    $values.Add((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    $values.Add((New-Object Security.Principal.SecurityIdentifier('S-1-5-18')))
    if (-not ($values | Where-Object { $_.Value -eq $PoolSid.Value })) { $values.Add($PoolSid) }
    return @($values)
}

function New-ProtectedDirectoryAcl([Security.Principal.SecurityIdentifier[]]$Sids) {
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    foreach ($sid in $Sids) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit),
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule) | Out-Null
    }
    return $acl
}

function New-ProtectedFileAcl([Security.Principal.SecurityIdentifier[]]$Sids) {
    $acl = New-Object Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    foreach ($sid in $Sids) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            [Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule) | Out-Null
    }
    return $acl
}

function Test-ProtectedAcl([Security.AccessControl.FileSystemSecurity]$Acl, [Security.Principal.SecurityIdentifier[]]$Sids) {
    if (-not $Acl.AreAccessRulesProtected) { return $false }
    $rules = @($Acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    if ($rules.Count -ne $Sids.Count) { return $false }
    foreach ($rule in $rules) {
        if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
            (($rule.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) -ne [Security.AccessControl.FileSystemRights]::FullControl) -or
            -not ($Sids | Where-Object { $_.Value -eq $rule.IdentityReference.Value })) { return $false }
    }
    return $true
}

function Initialize-CredentialRoot([string]$Root, [string]$WebRoot, [Security.Principal.SecurityIdentifier[]]$Sids) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $webFull = [IO.Path]::GetFullPath($WebRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (($rootFull + [IO.Path]::DirectorySeparatorChar).StartsWith($webFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'EMAIL_CREDENTIAL_ROOT_INSIDE_WEBROOT'
    }

    $created = -not (Test-Path -LiteralPath $rootFull -PathType Container)
    if ($created) { [IO.Directory]::CreateDirectory($rootFull) | Out-Null }
    $current = Get-Acl -LiteralPath $rootFull
    if (-not (Test-ProtectedAcl $current $Sids)) {
        $hasChildren = $null -ne (Get-ChildItem -LiteralPath $rootFull -Force | Select-Object -First 1)
        if (-not $created -and $hasChildren) { throw 'EMAIL_CREDENTIAL_ROOT_ACL_REVIEW_REQUIRED' }
        Set-Acl -LiteralPath $rootFull -AclObject (New-ProtectedDirectoryAcl $Sids)
    }
    return $rootFull
}

function New-RandomToken {
    $bytes = New-Object byte[] 16
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
        return ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
        $rng.Dispose()
    }
}

function New-CredentialReference([string]$DatabaseIdentityValue, [int]$CompanyId, [string]$PurposeValue, [string]$Token) {
    return 'dpapi-v1:' + $DatabaseIdentityValue + ':' + $CompanyId.ToString([Globalization.CultureInfo]::InvariantCulture) + ':' + $PurposeValue + ':' + $Token
}

function Assert-ReferenceScope([string]$Reference, [string]$DatabaseIdentityValue, [int]$CompanyId, [string]$PurposeValue) {
    $pattern = '^dpapi-v1:([0-9a-f]{64}):([1-9][0-9]{0,9}):(TRANSACTIONAL|MARKETING):([0-9a-f]{32})$'
    $match = [regex]::Match($Reference, $pattern)
    if (-not $match.Success -or
        $match.Groups[1].Value -cne $DatabaseIdentityValue -or
        [int]$match.Groups[2].Value -ne $CompanyId -or
        $match.Groups[3].Value -cne $PurposeValue) {
        throw 'EMAIL_CREDENTIAL_REFERENCE_SCOPE_INVALID'
    }
    return $match.Groups[4].Value
}

function Convert-SecureValueToBytes([Security.SecureString]$Value) {
    $pointer = [IntPtr]::Zero
    $textValue = $null
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
        $textValue = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        return [Text.Encoding]::UTF8.GetBytes($textValue)
    } finally {
        $textValue = $null
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    }
}

function Test-SecureValuesEqual([Security.SecureString]$First, [Security.SecureString]$Second) {
    $firstBytes = Convert-SecureValueToBytes $First
    $secondBytes = Convert-SecureValueToBytes $Second
    try {
        $difference = $firstBytes.Length -bxor $secondBytes.Length
        $length = [Math]::Max($firstBytes.Length, $secondBytes.Length)
        for ($index = 0; $index -lt $length; $index++) {
            $left = if ($index -lt $firstBytes.Length) { $firstBytes[$index] } else { 0 }
            $right = if ($index -lt $secondBytes.Length) { $secondBytes[$index] } else { 0 }
            $difference = $difference -bor ($left -bxor $right)
        }
        return $difference -eq 0
    } finally {
        [Array]::Clear($firstBytes, 0, $firstBytes.Length)
        [Array]::Clear($secondBytes, 0, $secondBytes.Length)
    }
}

function Get-Entropy([string]$Reference) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('KeepStore.EmailCredential.v1|' + $Reference))
    } finally {
        $sha.Dispose()
    }
}

function Protect-CredentialValue([Security.SecureString]$Value, [string]$Reference) {
    $clearBytes = Convert-SecureValueToBytes $Value
    $protectedBytes = $null
    try {
        if ($clearBytes.Length -eq 0) { throw 'EMAIL_CREDENTIAL_EMPTY' }
        $protectedBytes = [Security.Cryptography.ProtectedData]::Protect(
            $clearBytes,
            (Get-Entropy $Reference),
            [Security.Cryptography.DataProtectionScope]::LocalMachine)
        $header = [Text.Encoding]::ASCII.GetBytes('KSEMAIL1')
        $envelope = New-Object byte[] ($header.Length + $protectedBytes.Length)
        [Buffer]::BlockCopy($header, 0, $envelope, 0, $header.Length)
        [Buffer]::BlockCopy($protectedBytes, 0, $envelope, $header.Length, $protectedBytes.Length)
        return $envelope
    } finally {
        [Array]::Clear($clearBytes, 0, $clearBytes.Length)
        if ($protectedBytes) { [Array]::Clear($protectedBytes, 0, $protectedBytes.Length) }
    }
}

function Write-CredentialEnvelopeAtomic([string]$Path,
                                        [byte[]]$Envelope,
                                        [Security.Principal.SecurityIdentifier[]]$Sids,
                                        [scriptblock]$ApplyAcl) {
    if ($null -eq $ApplyAcl) {
        $ApplyAcl = { param($TargetPath, $TargetAcl) Set-Acl -LiteralPath $TargetPath -AclObject $TargetAcl }
    }
    $temporaryPath = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    $backupPath = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.bak'
    try {
        [IO.File]::WriteAllBytes($temporaryPath, $Envelope)
        & $ApplyAcl $temporaryPath (New-ProtectedFileAcl $Sids)
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [IO.File]::Replace($temporaryPath, $Path, $backupPath)
        } else {
            [IO.File]::Move($temporaryPath, $Path)
        }
        & $ApplyAcl $Path (New-ProtectedFileAcl $Sids)
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
        if (Test-Path -LiteralPath $backupPath) { Remove-Item -LiteralPath $backupPath -Force }
    }
}

$firstValue = $null
$secondValue = $null
$envelope = $null
try {
    Assert-Administrator
    $applicationFull = [IO.Path]::GetFullPath($ApplicationRoot)
    $databaseIdentity = Get-ApplicationDatabaseIdentity $applicationFull $ConnectionStringName
    $poolSid = Get-ApplicationPoolIdentitySid $ApplicationPoolName
    $requiredSids = Get-RequiredStoreSids $poolSid
    $root = Initialize-CredentialRoot $CredentialRoot $applicationFull $requiredSids

    if ([string]::IsNullOrWhiteSpace($CredentialReference)) {
        $CredentialReference = New-CredentialReference $databaseIdentity $AziendaId $Purpose (New-RandomToken)
    }
    $token = Assert-ReferenceScope $CredentialReference $databaseIdentity $AziendaId $Purpose

    $firstValue = Read-Host 'Credenziale SMTP/app password' -AsSecureString
    $secondValue = Read-Host 'Conferma credenziale SMTP/app password' -AsSecureString
    if ($firstValue.Length -eq 0 -or $secondValue.Length -eq 0) { throw 'EMAIL_CREDENTIAL_EMPTY' }
    if (-not (Test-SecureValuesEqual $firstValue $secondValue)) { throw 'EMAIL_CREDENTIAL_CONFIRMATION_MISMATCH' }

    $credentialDirectory = Join-Path $root (Join-Path $databaseIdentity (Join-Path $AziendaId.ToString([Globalization.CultureInfo]::InvariantCulture) $Purpose))
    [IO.Directory]::CreateDirectory($credentialDirectory) | Out-Null
    Set-Acl -LiteralPath $credentialDirectory -AclObject (New-ProtectedDirectoryAcl $requiredSids)
    $credentialPath = Join-Path $credentialDirectory ($token + '.bin')

    $envelope = Protect-CredentialValue $firstValue $CredentialReference
    Write-CredentialEnvelopeAtomic $credentialPath $envelope $requiredSids $null

    Write-Output ('CREDENTIAL_REFERENCE=' + $CredentialReference)
    Write-Output 'CREDENTIAL_STORE_RESULT=CONFIGURED'
} catch {
    $safeCode = [Convert]::ToString($_.Exception.Message)
    if ($safeCode -notmatch '^EMAIL_[A-Z0-9_]+$') { $safeCode = 'EMAIL_CREDENTIAL_PROVISIONING_FAILED' }
    Write-Error $safeCode
    exit 1
} finally {
    if ($envelope) { [Array]::Clear($envelope, 0, $envelope.Length) }
    if ($firstValue) { $firstValue.Dispose() }
    if ($secondValue) { $secondValue.Dispose() }
}
