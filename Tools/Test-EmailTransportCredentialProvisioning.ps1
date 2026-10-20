[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Security

$toolPath = Join-Path $PSScriptRoot 'Set-EmailTransportCredential.ps1'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStore-EmailProvisioning-' + [Guid]::NewGuid().ToString('N'))
$resourceRecord = Join-Path ([IO.Path]::GetTempPath()) ('email-provisioning-resources-' + [Guid]::NewGuid().ToString('N') + '.json')
$resourceState = [ordered]@{ Directory = $temporaryRoot; Children = @('application\web.config','credential.bin','atomic temporary envelope files'); State = 'PLANNED' }
[IO.File]::WriteAllText($resourceRecord, (ConvertTo-Json -InputObject $resourceState -Depth 3))
$passed = 0

function Assert-Check([bool]$Condition, [string]$Code) {
    if (-not $Condition) { throw $Code }
    $script:passed += 1
    Write-Output ('PASS ' + $Code)
}

function New-SyntheticSecureValue([string]$Value) {
    $secureValue = New-Object Security.SecureString
    foreach ($character in $Value.ToCharArray()) { $secureValue.AppendChar($character) }
    $secureValue.MakeReadOnly()
    return $secureValue
}

try {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($toolPath, [ref]$tokens, [ref]$errors)
    Assert-Check ($errors.Count -eq 0) 'PROVISIONING_POWERSHELL_PARSE'

    $parameterNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    Assert-Check (-not ($parameterNames | Where-Object { $_ -match '(?i)password|secret|databaseidentity' })) 'NO_SECRET_OR_DATABASE_IDENTITY_ARGUMENT'

    $toolText = Get-Content -LiteralPath $toolPath -Raw
    Assert-Check (([regex]::Matches($toolText, "Read-Host[^\r\n]+-AsSecureString")).Count -eq 2) 'MASKED_INPUT_AND_CONFIRMATION'
    Assert-Check ($toolText -notmatch '(?i)HttpListener|New-Website|New-WebApplication|Start-Website|Restart-WebAppPool|Recycle|ServerManager\.Sites\.Add') 'NO_ENDPOINT_LISTENER_OR_IIS_MUTATION'
    Assert-Check ($toolText -notmatch '(?i)MySqlConnection\s*\(|\.Open\s*\(') 'NO_DATABASE_CONNECTION'
    Assert-Check ($toolText -match 'DataProtectionScope\]::LocalMachine') 'DPAPI_LOCAL_MACHINE'

    # The real entrypoint is guarded: loading helpers never prompts, changes ACLs or reads IIS.
    . $toolPath -AziendaId 1 -Purpose 'TRANSACTIONAL' -ApplicationRoot $temporaryRoot

    $assemblyPath = Join-Path $repo 'Bin\MySql.Data.dll'
    $identityA = Get-DatabaseIdentityFromConnectionString 'Server=fixture-a.invalid;Port=3306;Database=store_a;' $assemblyPath
    $identityARepeat = Get-DatabaseIdentityFromConnectionString 'Database=store_a;Server=FIXTURE-A.INVALID;Port=3306;' $assemblyPath
    $identityB = Get-DatabaseIdentityFromConnectionString 'Server=fixture-a.invalid;Port=3306;Database=store_b;' $assemblyPath
    Assert-Check ($identityA -ceq $identityARepeat -and $identityA -cne $identityB) 'DATABASE_IDENTITY_DERIVED_AND_ISOLATED'

    $tokenA = ('a' * 32)
    $tokenB = ('b' * 32)
    $referenceA1 = New-CredentialReference $identityA 1 'TRANSACTIONAL' $tokenA
    $referenceA2 = New-CredentialReference $identityA 2 'TRANSACTIONAL' $tokenA
    $referenceB1 = New-CredentialReference $identityB 1 'TRANSACTIONAL' $tokenA
    $referenceMarketing = New-CredentialReference $identityA 1 'MARKETING' $tokenB
    Assert-Check ((Assert-ReferenceScope $referenceA1 $identityA 1 'TRANSACTIONAL') -ceq $tokenA) 'REFERENCE_SCOPE_VALID'
    Assert-Check ($referenceA1 -cne $referenceA2) 'REFERENCE_TENANT_ISOLATION'
    Assert-Check ($referenceA1 -cne $referenceB1) 'REFERENCE_DATABASE_ISOLATION'
    Assert-Check ($referenceA1 -cne $referenceMarketing) 'REFERENCE_PURPOSE_ISOLATION'

    $first = New-SyntheticSecureValue 'fixture-value-one'
    $same = New-SyntheticSecureValue 'fixture-value-one'
    $different = New-SyntheticSecureValue 'fixture-value-two'
    try {
        Assert-Check (Test-SecureValuesEqual $first $same) 'CONFIRMATION_MATCH'
        Assert-Check (-not (Test-SecureValuesEqual $first $different)) 'CONFIRMATION_MISMATCH_FAIL_CLOSED'
        $envelope = Protect-CredentialValue $first $referenceA1
        Assert-Check ([Text.Encoding]::ASCII.GetString($envelope, 0, 8) -ceq 'KSEMAIL1') 'ENVELOPE_HEADER'
        Assert-Check (-not ([Text.Encoding]::UTF8.GetString($envelope).Contains('fixture-value-one'))) 'NO_CLEAR_SECRET_IN_ENVELOPE'
    } finally {
        $first.Dispose()
        $same.Dispose()
        $different.Dispose()
    }

    $poolSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $requiredSids = Get-RequiredStoreSids $poolSid
    $directoryAcl = New-ProtectedDirectoryAcl $requiredSids
    Assert-Check (Test-ProtectedAcl $directoryAcl $requiredSids) 'EXPECTED_PROTECTED_ACL_MODEL'

    [IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
    $application = Join-Path $temporaryRoot 'application'
    [IO.Directory]::CreateDirectory($application) | Out-Null
    $configuration = '<configuration><connectionStrings><clear/><add name="unrelated" connectionString="Server=other.invalid;Database=other;" providerName="MySql.Data.MySqlClient"/><add name="EntropicConnectionString" connectionString="Server=fixture-a.invalid;Port=3306;Database=store_a;" providerName="MySql.Data.MySqlClient"/></connectionStrings></configuration>'
    [IO.File]::WriteAllText((Join-Path $application 'web.config'), $configuration)
    Assert-Check ((Get-ApplicationDatabaseIdentity $application 'EntropicConnectionString') -ceq $identityA) 'CONFIGURATION_READER_PRESERVES_DATABASE_IDENTITY'
    $missingRejected = $false
    try { Get-ApplicationDatabaseIdentity $application 'missing' | Out-Null } catch { $missingRejected = $_.Exception.Message -match '^EMAIL_[A-Z0-9_]+$' }
    Assert-Check $missingRejected 'MISSING_NAMED_CONFIGURATION_FAILS_CLOSED'
    $credentialPath = Join-Path $temporaryRoot 'credential.bin'
    $script:aclApplications = 0
    $mockAcl = { param($TargetPath, $TargetAcl) $script:aclApplications += 1 }
    Write-CredentialEnvelopeAtomic $credentialPath ([byte[]](1, 2, 3)) $requiredSids $mockAcl
    Write-CredentialEnvelopeAtomic $credentialPath ([byte[]](4, 5, 6)) $requiredSids $mockAcl
    $residue = @(Get-ChildItem -LiteralPath $temporaryRoot -File | Where-Object { $_.Extension -in @('.tmp', '.bak') })
    Assert-Check (([IO.File]::ReadAllBytes($credentialPath) -join ',') -eq '4,5,6' -and $residue.Count -eq 0 -and $script:aclApplications -eq 4) 'ATOMIC_CREATE_REPLACE_AND_CLEANUP'

    Assert-Check ($toolText -notmatch '(?i)Write-(Output|Host|Verbose|Debug|Information)[^\r\n]*(secure|cleartext|configuredValue|connectionString)') 'NO_SECRET_OUTPUT_CHANNEL'
    Assert-Check (([IO.Path]::GetFullPath('C:\ProgramData\KeepStore\EmailCredentials') + '\').StartsWith(([IO.Path]::GetFullPath($repo) + '\'), [StringComparison]::OrdinalIgnoreCase) -eq $false) 'DEFAULT_ROOT_OUTSIDE_REPOSITORY'
    Write-Output ('EMAIL_CREDENTIAL_PROVISIONING_PASS checks=' + $passed)
} finally {
    $resolved = [IO.Path]::GetFullPath($temporaryRoot)
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) { throw 'UNSAFE_PROVISIONING_TEST_CLEANUP' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    $resourceState.State = 'CLEANED'
    [IO.File]::WriteAllText($resourceRecord, (ConvertTo-Json -InputObject $resourceState -Depth 3))
}
