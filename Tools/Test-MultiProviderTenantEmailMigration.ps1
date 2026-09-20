[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$migrationRoot = Join-Path $repoRoot 'Database Taikun\Migrations'
$prefix = '20260920_MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A'
$paths = [ordered]@{
    Preflight = Join-Path $migrationRoot ($prefix + '_preflight.sql')
    Forward = Join-Path $migrationRoot ($prefix + '_forward.sql')
    Verify = Join-Path $migrationRoot ($prefix + '_verify.sql')
    RollbackPreflight = Join-Path $migrationRoot ($prefix + '_rollback_preflight.sql')
    Rollback = Join-Path $migrationRoot ($prefix + '_rollback.sql')
}
$enzoPath = Join-Path $repoRoot 'docs\MULTIPROVIDER_TENANT_EMAIL_CONFIG_ENZO.md'

function Assert-Check([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}

foreach ($path in $paths.Values) {
    Assert-Check (Test-Path -LiteralPath $path) ('FILE_PRESENT_' + [IO.Path]::GetFileName($path))
}
Assert-Check (Test-Path -LiteralPath $enzoPath) 'FILE_PRESENT_ENZO_CONTRACT'

$all = ($paths.Values | ForEach-Object { [IO.File]::ReadAllText($_) }) -join "`n"
$preflight = [IO.File]::ReadAllText($paths.Preflight)
$forward = [IO.File]::ReadAllText($paths.Forward)
$verify = [IO.File]::ReadAllText($paths.Verify)
$rollbackPreflight = [IO.File]::ReadAllText($paths.RollbackPreflight)
$rollback = [IO.File]::ReadAllText($paths.Rollback)
$enzo = [IO.File]::ReadAllText($enzoPath)

Assert-Check ($all -notmatch '(?im)^\s*USE\s+`') 'NO_DATABASE_NAME_DIRECTIVE'
Assert-Check ($all -notmatch '(?i)taikun|webaffare|gmail\.com|outlook\.com|libero\.it|virgilio\.it') 'NO_TENANT_OR_ENDPOINT_HARDCODE'
Assert-Check ($all -notmatch '(?i)(password|access[_ ]?token|refresh[_ ]?token|secretvalue)\s*=\s*[''\"]') 'NO_SECRET_LITERAL'
Assert-Check ($forward -match 'CREATE TABLE `aziende_email_transport`') 'PROFILE_TABLE_CREATED_ONCE_PER_DATABASE'
Assert-Check ($forward -match '`EmailTransportId` bigint unsigned NOT NULL AUTO_INCREMENT') 'TECHNICAL_PRIMARY_KEY_COLUMN'
Assert-Check ($forward -match 'PRIMARY KEY \(`EmailTransportId`\)') 'TECHNICAL_PRIMARY_KEY'
Assert-Check ($forward -match '`AziendeId` int NOT NULL') 'TENANT_OWNER_REQUIRED'
Assert-Check ($forward -match '`Purpose` varchar\(24\).*NOT NULL') 'PURPOSE_REQUIRED'
Assert-Check ($forward -match 'UNIQUE KEY `UX_aziende_email_transport_owner_purpose` \(`AziendeId`,`Purpose`\)') 'OWNER_PURPOSE_UNIQUE'
Assert-Check ($forward -match 'FOREIGN KEY \(`AziendeId`\) REFERENCES `aziende` \(`id`\)') 'OWNER_FOREIGN_KEY'
Assert-Check ($forward -match '`Host` varchar\(253\)') 'DNS_HOST_253'
Assert-Check ($forward -match '`Username` varchar\(254\)' -and
             $forward -match '`FromAddress` varchar\(254\)' -and
             $forward -match '`ReplyToAddress` varchar\(254\)' -and
             $forward -match '`EnvelopeFromAddress` varchar\(254\)') 'MAIL_IDENTITIES_254'
Assert-Check ($forward -match '`CredentialReference` varchar\(512\)') 'SECRET_REFERENCE_512'
Assert-Check ($forward -match '`FromDisplayName` varchar\(255\) CHARACTER SET utf8mb4') 'DISPLAY_NAME_UNICODE'
Assert-Check ($forward -match '`SecurityMode` varchar\(24\)' -and $forward -notmatch '(?i)\bENUM\s*\(') 'CONTROLLED_TEXT_NOT_ENUM'
Assert-Check ($forward -match "COMMENT='KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v2'") 'SCHEMA_VERSION_MARKER_V2'
Assert-Check ($forward -match '`Enabled` tinyint\(1\) NOT NULL DEFAULT 0') 'NEW_PROFILES_DEFAULT_DISABLED'
Assert-Check ($forward -notmatch '(?im)^\s*(INSERT|UPDATE|DELETE|REPLACE)\b|Password_smtp') 'NO_PROFILE_DML_OR_LEGACY_SECRET_COPY'
Assert-Check ($verify -match "'TRANSACTIONAL','MARKETING'" -and
             $verify -match "'STARTTLS','IMPLICIT_TLS'" -and
             $verify -match "'PASSWORD','APP_PASSWORD','OAUTH2'") 'CONTROLLED_VALUES_VERIFIED'
Assert-Check ($verify -match 'TimeoutSeconds`<5 OR `TimeoutSeconds`>300') 'TIMEOUT_RANGE_VERIFIED'
Assert-Check ($verify -match 'Enabled`=1 AND \(`VerificationStatus`<>''VERIFIED'' OR `LastVerifiedAtUtc` IS NULL\)') 'ENABLED_REQUIRES_SUCCESSFUL_VERIFICATION'
Assert-Check ($rollbackPreflight -match 'STOP_HAS_PROFILES') 'ROLLBACK_PREFLIGHT_BLOCKS_PROFILES'
Assert-Check ($rollback -match 'EMAIL_TRANSPORT_ROLLBACK_HAS_PROFILES') 'ROLLBACK_FAILS_WITH_PROFILES'
Assert-Check ($rollback -match 'DROP TABLE `aziende_email_transport`') 'ROLLBACK_REMOVES_ONLY_EMPTY_PROFILE_TABLE'
Assert-Check ($preflight -match 'ALREADY_COMPLIANT' -and $forward -match 'EMAIL_TRANSPORT_PROFILE_SCHEMA_CONFLICT') 'IDEMPOTENT_OR_FAILS_CLOSED'

foreach ($token in @('CUSTOM_SMTP','ARUBA','GOOGLE','MICROSOFT','LIBERO','VIRGILIO',
                      'TRANSACTIONAL','MARKETING','CredentialReference','MAIL FROM','RCPT TO','DATA')) {
    Assert-Check ($enzo -match [regex]::Escape($token)) ('ENZO_CONTRACT_' + $token.Replace(' ', '_'))
}
Assert-Check (@($enzo -split "`r?`n" | Where-Object { $_ -match '^# ' }).Count -eq 1) 'ENZO_SINGLE_H1'
Assert-Check ($enzo -match 'Azienda 1.*TRANSACTIONAL' -and $enzo -match 'Azienda 2.*TRANSACTIONAL') 'SANITIZED_TWO_TENANT_EXAMPLES'
Assert-Check ($enzo -match 'preflight' -and $enzo -match 'backup' -and $enzo -match 'rollback') 'PER_DATABASE_DEPLOYMENT_CHECKLIST'

Write-Output 'PASS MULTIPROVIDER_TENANT_EMAIL_CONFIG_CONTRACT_REV1'
