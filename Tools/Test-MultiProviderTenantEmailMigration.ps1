[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$migrationRoot = Join-Path $repoRoot 'Database Taikun\Migrations'
$prefix = '20260920_MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A'
$paths = @{
    Preflight = Join-Path $migrationRoot ($prefix + '_preflight.sql')
    Forward = Join-Path $migrationRoot ($prefix + '_forward.sql')
    Verify = Join-Path $migrationRoot ($prefix + '_verify.sql')
    RollbackPreflight = Join-Path $migrationRoot ($prefix + '_rollback_preflight.sql')
    Rollback = Join-Path $migrationRoot ($prefix + '_rollback.sql')
}

function Assert-Check([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}

foreach ($path in $paths.Values) {
    Assert-Check (Test-Path -LiteralPath $path) ('FILE_PRESENT_' + [IO.Path]::GetFileName($path))
}

$all = ($paths.Values | ForEach-Object { [IO.File]::ReadAllText($_) }) -join "`n"
$forward = [IO.File]::ReadAllText($paths.Forward)
$verify = [IO.File]::ReadAllText($paths.Verify)
$rollback = [IO.File]::ReadAllText($paths.Rollback)

Assert-Check ($all -notmatch '(?im)^\s*USE\s+`') 'NO_DATABASE_NAME_DIRECTIVE'
Assert-Check ($all -notmatch '(?i)taikun|webaffare|gmail\.com|outlook\.com|libero\.it|virgilio\.it') 'NO_TENANT_OR_ENDPOINT_HARDCODE'
Assert-Check ($all -notmatch '(?i)(password|access[_ ]?token|refresh[_ ]?token|secretvalue)\s*=\s*[''\"]') 'NO_SECRET_LITERAL'
Assert-Check ($forward -match 'CREATE TABLE `aziende_email_transport`') 'PROFILE_TABLE_CREATED'
Assert-Check ($forward -match '`AziendeId` int NOT NULL') 'TENANT_OWNER_REQUIRED'
Assert-Check ($forward -match '`SecurityMode` varchar\(24\)') 'SECURITY_MODE_EXPLICIT'
Assert-Check ($forward -match '`AuthenticationMode` varchar\(24\)') 'AUTH_MODE_EXPLICIT'
Assert-Check ($forward -match '`CredentialReference` varchar\(255\)') 'SECRET_REFERENCE_ONLY'
Assert-Check ($forward -match "COMMENT='KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v1'") 'SCHEMA_VERSION_MARKER'
Assert-Check ($forward -match '`Username` varchar\(320\) NOT NULL' -and $forward -match '`FromDisplayName` varchar\(255\) NOT NULL') 'REQUIRED_SENDER_IDENTITY'
Assert-Check ($forward -match '`Enabled` tinyint\(1\) NOT NULL DEFAULT 0') 'NEW_PROFILES_DISABLED'
Assert-Check ($forward -notmatch '(?i)INSERT\s+INTO|UPDATE\s+`?aziende`?|Password_smtp') 'NO_LEGACY_SECRET_COPY_OR_DML'
Assert-Check ($verify -match "'StartTls','ImplicitTls'" -and $verify -match "'Password','AppPassword','OAuth2'") 'PROFILE_ENUM_CONTRACT_VERIFIED'
Assert-Check ($verify -match 'Enabled`=1 AND `VerificationStatus`<>''VERIFIED''') 'ENABLED_REQUIRES_VERIFIED'
Assert-Check ($rollback -match 'EMAIL_TRANSPORT_ROLLBACK_HAS_PROFILES') 'ROLLBACK_FAILS_WITH_PROFILES'
Assert-Check ($rollback -match 'DROP TABLE `aziende_email_transport`') 'ROLLBACK_REMOVES_ONLY_PROFILE_TABLE'

Write-Output 'PASS MULTIPROVIDER_TENANT_EMAIL_MIGRATION_PROPOSAL'
