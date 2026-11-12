[CmdletBinding()]
param([string]$RepositoryRoot)
# ORDER-DOCUMENT-NUMBER-OUT-P0B-1A: static source checks of the four migration files (no database connection).
# The behavioural proof (OUT number = number stored by the trigger, application lookup finds one document) runs on the
# local LAB with Tools/Test-OrderConcurrencyLab.ps1 (scenario P0) and Tools/Test-OrderSqlMatrixLab.ps1.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$checks = 0
function Assert-Contract([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw ('ORDER_DOCNUM_OUT_TEST_FAILED: ' + $Name) }
    $script:checks++
}
$prefix = '20261112_ORDER_DOCUMENT_NUMBER_OUT_P0B_1A_'
function Read-Raw([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-Contract (Test-Path -LiteralPath $path -PathType Leaf) ('file exists: ' + $RelativePath)
    [IO.File]::ReadAllText($path)
}
function Read-Migration([string]$Suffix) { Read-Raw ('Database Taikun/Migrations/' + $prefix + $Suffix + '.sql') }
function Read-Create([string]$Sql) {
    $match = [regex]::Match($Sql, '(?s)(CREATE DEFINER=__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE.*?\n[ \t]*END)\s*\n\$\$\s*\nDELIMITER ;')
    Assert-Contract $match.Success 'complete CREATE extracted'
    $match.Groups[1].Value
}
function Get-BodyHash([string]$Create) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Create.Substring($Create.IndexOf('BEGIN'))))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
}

# Hashes of the integrated P1 state (installed text with trailing spaces, and the clean text of the P1 forward file).
$p1InstalledHash = '2436eb55d8a1186e5064afb38c9afd1e506614330a1f594ca0abec47283666d8'
$p1CleanHash = '1ef49a40b5c9e1aee3f8f9352b528973de42150cdf1f31316ce1c47edac84487'
$anchor = "`t`tSELECT last_insert_id() INTO IdDocumento;"
$added = "`t`tSELECT NDocumento INTO ndoc FROM documenti WHERE id=IdDocumento;"

$suffixes = @('preflight', 'forward', 'verify', 'rollback')
$files = @{}
foreach ($suffix in $suffixes) {
    $text = Read-Migration $suffix
    Assert-Contract (-not $text.Contains([string][char]13)) ($suffix + ': LF line endings only')
    Assert-Contract (-not ($text -match '[^\x09\x0A\x20-\x7E]')) ($suffix + ': ASCII only')
    Assert-Contract (-not ($text -match '(?m)[ \t]+$')) ($suffix + ': no trailing whitespace')
    Assert-Contract ($text.EndsWith("`n") -and -not $text.EndsWith("`n`n")) ($suffix + ': single final newline')
    $files[$suffix] = $text
}
$preflight = $files['preflight']; $forward = $files['forward']; $verify = $files['verify']; $rollback = $files['rollback']

$p1Forward = Read-Raw 'Database Taikun/Migrations/20261027_ORDER_VAT_ID_SEMANTICS_P1_1A_forward.sql'
$p1Create = Read-Create $p1Forward.Replace([string][char]13, '')
Assert-Contract ((Get-BodyHash $p1Create) -ceq $p1CleanHash) 'hash method reproduces the integrated P1 gate hash'

$fixed = Read-Create $forward
$restored = Read-Create $rollback
Assert-Contract ($restored -ceq $p1Create) 'rollback restores the exact P1 body'
Assert-Contract (([regex]::Matches($p1Create, [regex]::Escape($anchor))).Count -eq 1) 'one insertion anchor in the P1 body'
Assert-Contract ($fixed -ceq $p1Create.Replace($anchor, $anchor + "`n" + $added)) 'forward body = P1 body plus exactly one statement'
Assert-Contract (([regex]::Matches($fixed, [regex]::Escape($added))).Count -eq 1) 'read-back statement present once'
Assert-Contract ($fixed.IndexOf($anchor) -lt $fixed.IndexOf($added)) 'read-back follows the INSERT identity read'
Assert-Contract ($fixed.IndexOf($added) -lt $fixed.IndexOf('INSERT INTO documentirighe')) 'read-back precedes every later write'
Assert-Contract ($fixed.IndexOf($added) -lt $fixed.IndexOf('SET DocumentoMemorizzato=ndoc;')) 'read-back precedes the OUT assignment'
Assert-Contract (([regex]::Matches($fixed, [regex]::Escape('SET DocumentoMemorizzato=ndoc;'))).Count -eq 1) 'one OUT assignment, unchanged'
Assert-Contract (-not ($added -match '(?i)max\(|round\(|\+\s*1')) 'added statement reads, never computes a number'
Assert-Contract ((([regex]::Matches($fixed, '(?i)max\(')).Count) -eq (([regex]::Matches($p1Create, '(?i)max\(')).Count)) 'no new numbering computation introduced'
Assert-Contract (-not ($fixed -match '(?im)^\s*(START TRANSACTION|COMMIT|ROLLBACK)\s*;')) 'caller transaction boundary preserved'
$header = $fixed.Substring(0, $fixed.IndexOf('BEGIN'))
Assert-Contract (([regex]::Matches($header, '\b(?:IN|OUT)\s+\w+')).Count -eq 19) '19 parameter modes preserved'

# Signature fingerprint pinned in every gate (mode, name, base type, length, precision, scale of the 19 parameters, as
# information_schema.PARAMETERS reports them: display widths are ignored), rebuilt here from the CREATE header.
$signatureHash = '953b867c730f382dfc87975f3bd74a417e3946b3c977ce2075e8043134c6aaaa'
$parameterMatches = [regex]::Matches($header, '\b(IN|OUT)\s+(\w+)\s+(INT|DOUBLE|VARCHAR)(?:\((\d+)(?:,(\d+))?\))')
Assert-Contract ($parameterMatches.Count -eq 19) 'signature rebuilt from 19 header parameters'
$signatureParts = @()
$position = 0
foreach ($parameter in $parameterMatches) {
    $position++
    $type = $parameter.Groups[3].Value
    $detail = switch ($type) {
        'INT' { 'int::10:0' }
        'DOUBLE' { 'double::' + $parameter.Groups[4].Value + ':' + $parameter.Groups[5].Value }
        'VARCHAR' { 'varchar:' + $parameter.Groups[4].Value + '::' }
    }
    $signatureParts += ($position.ToString() + ':' + $parameter.Groups[1].Value + ':' + $parameter.Groups[2].Value + ':' + $detail)
}
$signatureSha = [Security.Cryptography.SHA256]::Create()
try { $signatureComputed = [BitConverter]::ToString($signatureSha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($signatureParts -join '|')))).Replace('-', '').ToLowerInvariant() } finally { $signatureSha.Dispose() }
Assert-Contract ($signatureComputed -ceq $signatureHash) 'pinned signature fingerprint equals the CREATE header signature'

$p0bHash = Get-BodyHash $fixed
Assert-Contract ($p0bHash -cne $p1CleanHash -and $p0bHash -cne $p1InstalledHash) 'new body hash differs from the P1 hashes'
Assert-Contract ((Get-BodyHash $restored) -ceq $p1CleanHash) 'restored body hash equals the P1 clean hash'

# Hash gates: P1 state before the forward, P0b state before the rollback, each file's final gate on the resulting state.
Assert-Contract ($preflight.Contains($p1InstalledHash) -and $preflight.Contains($p1CleanHash) -and -not $preflight.Contains($p0bHash)) 'preflight admits only the two P1 hashes'
Assert-Contract ($verify.Contains($p0bHash) -and -not $verify.Contains($p1InstalledHash) -and -not $verify.Contains($p1CleanHash)) 'verify admits only the P0b hash'
$forwardDrop = $forward.IndexOf('DROP PROCEDURE')
$forwardBefore = $forward.Substring(0, $forwardDrop)
$forwardAfter = $forward.Substring($forward.IndexOf('DELIMITER ;'))
Assert-Contract ($forwardDrop -gt 0 -and $forwardBefore.Contains($p1InstalledHash) -and $forwardBefore.Contains($p1CleanHash) -and -not $forwardBefore.Contains($p0bHash)) 'forward guard before DROP requires the P1 body'
Assert-Contract ($forwardAfter.Contains($p0bHash) -and -not $forwardAfter.Contains($p1InstalledHash) -and -not $forwardAfter.Contains($p1CleanHash)) 'forward final gate requires the P0b body'
$rollbackDrop = $rollback.IndexOf('DROP PROCEDURE')
$rollbackBefore = $rollback.Substring(0, $rollbackDrop)
$rollbackAfter = $rollback.Substring($rollback.IndexOf('DELIMITER ;'))
Assert-Contract ($rollbackDrop -gt 0 -and $rollbackBefore.Contains($p0bHash) -and -not $rollbackBefore.Contains($p1CleanHash)) 'rollback guard before DROP requires the P0b body'
Assert-Contract ($rollbackAfter.Contains($p1InstalledHash) -and $rollbackAfter.Contains($p1CleanHash) -and -not $rollbackAfter.Contains($p0bHash)) 'rollback final gate requires the P1 body'

foreach ($sql in @($preflight, $forward, $verify, $rollback)) {
    Assert-Contract ($sql.Contains('KEEPSTORE_STOP_DOCNUM_MIGRATION_PRECONDITION')) 'executable fail-closed precondition'
    Assert-Contract ($sql.Contains('@KeepStoreRoutineBackupVerified') -and $sql.Contains('@KeepStoreCheckoutQuiesced')) 'external backup and checkout gates required'
    Assert-Contract ($sql.Contains('@KeepStoreExpectedServerUuid') -and $sql.Contains('@KeepStoreExpectedDatabase')) 'explicit target identity required'
    Assert-Contract ($sql.Contains('DEFINER=@KeepStoreOriginalDefiner')) 'original DEFINER required'
    Assert-Contract ($sql.Contains("SQL_MODE='NO_AUTO_VALUE_ON_ZERO'") -and $sql.Contains("CHARACTER_SET_CLIENT='utf8mb4'") -and $sql.Contains("DATABASE_COLLATION='utf8mb4_unicode_ci'")) 'creation metadata gate preserved'
    Assert-Contract ($sql.Contains($signatureHash)) 'gate pins the full parameter signature fingerprint'
    Assert-Contract ($sql.Contains("IS_DETERMINISTIC='NO'") -and $sql.Contains("SQL_DATA_ACCESS='CONTAINS SQL'") -and $sql.Contains("ROUTINE_COMMENT=''")) 'gate pins routine characteristics outside the body'
    Assert-Contract ($sql.Contains("COLUMN_KEY='PRI'") -and $sql.Contains("COLUMN_NAME='NDocumento'") -and $sql.Contains("ENGINE='InnoDB'")) 'gate attests the documenti schema the read-back depends on'
    Assert-Contract ($sql.Contains('SET SESSION group_concat_max_len=4096;')) 'signature fingerprint immune to GROUP_CONCAT truncation'
    Assert-Contract ($sql.Contains('automatic_sp_privileges') -and $sql.Contains('also on success')) 'header requires routine grants to be re-verified also after a successful forward'
    Assert-Contract ($sql.Contains('-- Never execute on production under the current mandate. Never use --force.')) 'production and --force warning present'
    Assert-Contract (-not ($sql -match '(?im)^\s*(USE\s|GRANT\s|REVOKE\s|ALTER\s+USER\s|CREATE\s+(VIEW|TABLE|USER)\s|SET\s+GLOBAL\s)')) 'no implicit target or other schema/account changes'
    Assert-Contract (-not ($sql -match '(?i)\bpassword\b|\bpwd\b|connection ?string')) 'no credential-like text'
}
foreach ($sql in @($forward, $rollback)) {
    Assert-Contract (([regex]::Matches($sql, '__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE')).Count -eq 1) 'one explicit original-DEFINER substitution'
    Assert-Contract ($sql.Contains('SET SESSION sql_mode=@ks_docnum_initial_sql_mode;') -and $sql.Contains('SET SESSION collation_connection=@ks_docnum_initial_collation;')) 'session settings restored on successful batch'
    Assert-Contract (([regex]::Matches($sql, 'DROP PROCEDURE Carrello_Documento;')).Count -eq 1) 'one DROP, no other object dropped'
}
foreach ($readOnly in @(@('preflight', $preflight), @('verify', $verify))) {
    $code = [regex]::Replace([string]$readOnly[1], '(?m)^--.*$', '')
    Assert-Contract (-not ($code -match '(?i)\b(DROP|CREATE|ALTER|INSERT|UPDATE|DELETE)\b')) ($readOnly[0] + ' is read-only (comments excluded)')
}

# The numbering rule stays in the database: the application takes the number from the procedure OUT parameter and looks the
# document up with it; the web-side "next number" prediction (tracking only, a separate cleanup candidate) is not used by live code.
$guard = Read-Raw 'Tools/Test-DatabaseSecretsGuard.ps1'
foreach ($suffix in $suffixes) {
    Assert-Contract ($guard.Contains('Database Taikun/Migrations/' + $prefix + $suffix + '.sql')) ('secret guard names the source-only migration: ' + $suffix)
}
$page = Read-Raw 'ordine.aspx.vb'
Assert-Contract ($page.Contains('Dim pOut As New MySqlParameter("?DocumentoMemorizzato", MySqlDbType.Int64)') -and $page.Contains('Long.TryParse(pOut.Value.ToString(), NumDoc)')) 'document number taken from the procedure OUT parameter'
Assert-Contract ($page.Contains('AND NDocumento=?NumDoc') -and $page.Contains('cmdDoc.Parameters.Add("?NumDoc", MySqlDbType.Int64).Value = NumDoc')) 'document lookup uses the number the procedure returned'
$liveTrackingUses = @($page -split "`n" | Where-Object { $_ -match 'numDoc_tracking' -and $_.TrimStart() -notmatch "^'" })
Assert-Contract ($liveTrackingUses.Count -eq 2) 'web-side next-number prediction only declared and assigned, never used by live code'

[pscustomobject]@{ result = 'A'; checks = $checks; databaseConnections = 0; bodyHashP0b = $p0bHash; bodyHashP1Clean = $p1CleanHash; scope = 'migration/source checks only; behavioural proof on the local LAB' } | ConvertTo-Json
