[CmdletBinding()]
param([string]$RepositoryRoot)
# ORDER-ROUNDING-HALF-UP-1A: static source checks of the four migration files (no database connection).
# The behavioural proof (document total and goods total rounded once, half away from zero, on exact DECIMAL sums) runs on the
# local LAB with Tools/Test-OrderSqlMatrixLab.ps1 (cases R01-R12 plus the whole matrix) and Tools/Test-OrderConcurrencyLab.ps1.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$checks = 0
function Assert-Contract([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw ('ORDER_ROUNDING_TEST_FAILED: ' + $Name) }
    $script:checks++
}
$prefix = '20261112_ORDER_ROUNDING_HALF_UP_1A_'
function Read-Raw([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-Contract (Test-Path -LiteralPath $path -PathType Leaf) ('file exists: ' + $RelativePath)
    [IO.File]::ReadAllText($path)
}
function Read-Create([string]$Sql) {
    $match = [regex]::Match($Sql.Replace([string][char]13, ''), '(?s)(CREATE DEFINER=__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE.*?\n[ \t]*END)\s*\n\$\$\s*\nDELIMITER ;')
    Assert-Contract $match.Success 'complete CREATE extracted'
    $match.Groups[1].Value
}
function Get-BodyHash([string]$Create) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Create.Substring($Create.IndexOf('BEGIN'))))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
}

# Hash of the P0b body this migration applies on top of, and the signature fingerprint pinned by every gate.
$p0bHash = '1383f81ce006011456e053946847d1151f573b5cdd6183a96f635c73407cb8da'
$signatureHash = '953b867c730f382dfc87975f3bd74a417e3946b3c977ce2075e8043134c6aaaa'

$suffixes = @('preflight', 'forward', 'verify', 'rollback')
$files = @{}
foreach ($suffix in $suffixes) {
    $text = Read-Raw ('Database Taikun/Migrations/' + $prefix + $suffix + '.sql')
    Assert-Contract (-not $text.Contains([string][char]13)) ($suffix + ': LF line endings only')
    Assert-Contract (-not ($text -match '[^\x09\x0A\x20-\x7E]')) ($suffix + ': ASCII only')
    Assert-Contract (-not ($text -match '(?m)[ \t]+$')) ($suffix + ': no trailing whitespace')
    Assert-Contract ($text.EndsWith("`n") -and -not $text.EndsWith("`n`n")) ($suffix + ': single final newline')
    $files[$suffix] = $text
}
$preflight = $files['preflight']; $forward = $files['forward']; $verify = $files['verify']; $rollback = $files['rollback']

$p0bCreate = Read-Create (Read-Raw 'Database Taikun/Migrations/20261112_ORDER_DOCUMENT_NUMBER_OUT_P0B_1A_forward.sql')
Assert-Contract ((Get-BodyHash $p0bCreate) -ceq $p0bHash) 'the base body is the integrated P0b body'
$fixed = Read-Create $forward
$restored = Read-Create $rollback
Assert-Contract ($restored -ceq $p0bCreate) 'rollback restores the exact P0b body'

# The forward body is the P0b body with exactly these edits (re-implemented here, independently of the generator).
$t = "`t"
$rate = 'IF((pUtenteAbilitatoRC=1) AND (pIdIvaRC>-1),pValoreIvaRC,IF(pidEsenzioneIva>-1,pValoreEsenzioneIva,parValoreIva))'
$expected = $p0bCreate
function Edit-Once([string]$Text, [string]$Old, [string]$New) {
    Assert-Contract (([regex]::Matches($Text, [regex]::Escape($Old))).Count -eq 1) ('single anchor in the P0b body: ' + $Old.Substring(0, [Math]::Min(48, $Old.Length)))
    return $Text.Replace($Old, $New)
}
$decl = "${t}DECLARE${t}totiva DOUBLE(15,3) DEFAULT 0;"
$loop = "${t}${t}${t}SET totiva=totiva+IF((pUtenteAbilitatoRC=1) AND (pIdIvaRC>-1),pImporto*pValoreIvaRC/100,IF(pidEsenzioneIva>-1,pImporto*pValoreEsenzioneIva/100,pImporto*parValoreIva/100));"
$ship = "${t}SET totiva=totiva+(pCostoSpedizione*pIvaVettore/100)+(pCostoAssicurazione*pIvaVettore/100);"
$tot = "${t}SET totdoc=ROUND(imponibile,2)+ROUND(totiva,2);"
$declAdd = "`n${t}DECLARE impExact DECIMAL(40,8) DEFAULT 0;`n${t}DECLARE ivaExact DECIMAL(48,18) DEFAULT 0;`n${t}DECLARE totExact DECIMAL(48,18) DEFAULT 0;"
$loopAdd = "`n${t}${t}${t}SET impExact=impExact+CAST(pImporto AS DECIMAL(24,8));`n${t}${t}${t}SET ivaExact=ivaExact+CAST(pImporto AS DECIMAL(24,8))*CAST($rate AS DECIMAL(12,8))*0.01;"
$shipAdd = "`n${t}SET ivaExact=ivaExact+(CAST(pCostoSpedizione AS DECIMAL(24,8))+CAST(pCostoAssicurazione AS DECIMAL(24,8)))*CAST(pIvaVettore AS DECIMAL(12,8))*0.01;"
$totAdd = "`n${t}SET totExact=impExact+ivaExact+CAST(pCostoSpedizione AS DECIMAL(24,8))+CAST(pCostoAssicurazione AS DECIMAL(24,8))+CAST(pCostoPagamento AS DECIMAL(24,8))+CAST(pArrotondamento AS DECIMAL(24,8))+CAST(pBuonoScontoTotale AS DECIMAL(24,8))+CAST(pBuonoScontoTotale AS DECIMAL(24,8))*CAST(pBuonoScontoValoreIva AS DECIMAL(12,8))*0.01;"
$expected = Edit-Once $expected $decl ($decl + $declAdd)
$expected = Edit-Once $expected $loop ($loop + $loopAdd)
$expected = Edit-Once $expected $ship ($ship + $shipAdd)
$expected = Edit-Once $expected $tot ($tot + $totAdd)
$expected = Edit-Once $expected "${t}${t}TotaleDocumento=totdoc+pCostoSpedizione+pCostoAssicurazione+pCostoPagamento+pArrotondamento+pBuonoScontoTotale+((pBuonoScontoTotale/100)*pBuonoScontoValoreIva)," "${t}${t}TotaleDocumento=ROUND(totExact,2),"
$expected = Edit-Once $expected "${t}${t}TotMerce=ROUND(imponibile,2)," "${t}${t}TotMerce=ROUND(impExact,2),"
Assert-Contract ($fixed -ceq $expected) 'forward body = P0b body with exactly the seven rounding edits'

# Semantics: the footer is rounded once on exact DECIMAL sums; precision is not lost before the single rounding.
Assert-Contract ($fixed.Contains('TotaleDocumento=ROUND(totExact,2),') -and $fixed.Contains('TotMerce=ROUND(impExact,2),')) 'total and goods total rounded once from exact sums'
Assert-Contract (-not $fixed.Contains('TotaleDocumento=totdoc') -and -not $fixed.Contains('TotMerce=ROUND(imponibile')) 'no footer total left on DOUBLE arithmetic'
Assert-Contract ($fixed.Contains('DECLARE impExact DECIMAL(40,8)') -and $fixed.Contains('DECLARE ivaExact DECIMAL(48,18)') -and $fixed.Contains('DECLARE totExact DECIMAL(48,18)')) 'accumulators wide enough: 8 + 8 + 2 decimals for VAT'
Assert-Contract (-not $fixed.Contains('DECIMAL(9,3)') -and -not $fixed.Contains('DECIMAL(24,8) DEFAULT')) 'no truncating rate cast or narrow accumulator'
$exactLines = @($fixed -split "`n" | Where-Object { $_ -match '^\s*SET (impExact|ivaExact|totExact)=' })
Assert-Contract ($exactLines.Count -eq 4) 'four exact-arithmetic statements (two per-row, shipping VAT, total)'
Assert-Contract (-not ($exactLines -match '/\s*100')) 'no division in the exact statements (multiplication by the exact literal 0.01)'
Assert-Contract (-not ($exactLines -match '(?i)\bROUND\(')) 'no rounding before the single final ROUND'
Assert-Contract (([regex]::Matches($fixed, '(?i)\bROUND\(')).Count -eq (([regex]::Matches($p0bCreate, '(?i)\bROUND\(')).Count + 1)) 'ROUND count: the unused totdoc line stays, one new ROUND on the exact total'
Assert-Contract ($fixed.Contains('SELECT NDocumento INTO ndoc FROM documenti WHERE id=IdDocumento;')) 'P0b number read-back preserved'
Assert-Contract ($fixed.IndexOf('INSERT INTO controllaArrotondamento') -lt $fixed.IndexOf('BUONOSCONTO')) 'queue insert still precedes the voucher row (order preserved)'
Assert-Contract (-not ($fixed -match '(?im)^\s*(START TRANSACTION|COMMIT|ROLLBACK)\s*;')) 'caller transaction boundary preserved'
$header = $fixed.Substring(0, $fixed.IndexOf('BEGIN'))
Assert-Contract (([regex]::Matches($header, '\b(?:IN|OUT)\s+\w+')).Count -eq 19) '19 parameter modes preserved'
$parameterMatches = [regex]::Matches($header, '\b(IN|OUT)\s+(\w+)\s+(INT|DOUBLE|VARCHAR)(?:\((\d+)(?:,(\d+))?\))')
Assert-Contract ($parameterMatches.Count -eq 19) 'signature rebuilt from 19 header parameters'
$signatureParts = @()
$position = 0
foreach ($parameter in $parameterMatches) {
    $position++
    $detail = switch ($parameter.Groups[3].Value) {
        'INT' { 'int::10:0' }
        'DOUBLE' { 'double::' + $parameter.Groups[4].Value + ':' + $parameter.Groups[5].Value }
        'VARCHAR' { 'varchar:' + $parameter.Groups[4].Value + '::' }
    }
    $signatureParts += ($position.ToString() + ':' + $parameter.Groups[1].Value + ':' + $parameter.Groups[2].Value + ':' + $detail)
}
$signatureSha = [Security.Cryptography.SHA256]::Create()
try { $signatureComputed = [BitConverter]::ToString($signatureSha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($signatureParts -join '|')))).Replace('-', '').ToLowerInvariant() } finally { $signatureSha.Dispose() }
Assert-Contract ($signatureComputed -ceq $signatureHash) 'pinned signature fingerprint equals the CREATE header signature (unchanged)'

$newHash = Get-BodyHash $fixed
Assert-Contract ($newHash -cne $p0bHash) 'new body hash differs from the P0b hash'
Assert-Contract ((Get-BodyHash $restored) -ceq $p0bHash) 'restored body hash equals the P0b hash'

# Hash gates: P0b state before the forward, new state before the rollback, each file's final gate on the resulting state.
Assert-Contract ($preflight.Contains($p0bHash) -and -not $preflight.Contains($newHash)) 'preflight admits only the P0b hash'
Assert-Contract ($verify.Contains($newHash) -and -not $verify.Contains($p0bHash)) 'verify admits only the new hash'
$forwardDrop = $forward.IndexOf('DROP PROCEDURE')
$forwardBefore = $forward.Substring(0, $forwardDrop)
$forwardAfter = $forward.Substring($forward.IndexOf('DELIMITER ;'))
Assert-Contract ($forwardDrop -gt 0 -and $forwardBefore.Contains($p0bHash) -and -not $forwardBefore.Contains($newHash)) 'forward guard before DROP requires the P0b body'
Assert-Contract ($forwardAfter.Contains($newHash) -and -not $forwardAfter.Contains($p0bHash)) 'forward final gate requires the new body'
$rollbackDrop = $rollback.IndexOf('DROP PROCEDURE')
$rollbackBefore = $rollback.Substring(0, $rollbackDrop)
$rollbackAfter = $rollback.Substring($rollback.IndexOf('DELIMITER ;'))
Assert-Contract ($rollbackDrop -gt 0 -and $rollbackBefore.Contains($newHash) -and -not $rollbackBefore.Contains($p0bHash)) 'rollback guard before DROP requires the new body'
Assert-Contract ($rollbackAfter.Contains($p0bHash) -and -not $rollbackAfter.Contains($newHash)) 'rollback final gate requires the P0b body'

foreach ($sql in @($preflight, $forward, $verify, $rollback)) {
    Assert-Contract ($sql.Contains('KEEPSTORE_STOP_ROUNDING_MIGRATION_PRECONDITION')) 'executable fail-closed precondition'
    Assert-Contract ($sql.Contains('@KeepStoreRoutineBackupVerified') -and $sql.Contains('@KeepStoreCheckoutQuiesced')) 'external backup and checkout gates required'
    Assert-Contract ($sql.Contains('@KeepStoreExpectedServerUuid') -and $sql.Contains('@KeepStoreExpectedDatabase')) 'explicit target identity required'
    Assert-Contract ($sql.Contains('DEFINER=@KeepStoreOriginalDefiner')) 'original DEFINER required'
    Assert-Contract ($sql.Contains("SQL_MODE='NO_AUTO_VALUE_ON_ZERO'") -and $sql.Contains("CHARACTER_SET_CLIENT='utf8mb4'") -and $sql.Contains("DATABASE_COLLATION='utf8mb4_unicode_ci'")) 'creation metadata gate preserved'
    Assert-Contract ($sql.Contains($signatureHash)) 'gate pins the full parameter signature fingerprint'
    Assert-Contract ($sql.Contains("IS_DETERMINISTIC='NO'") -and $sql.Contains("SQL_DATA_ACCESS='CONTAINS SQL'") -and $sql.Contains("ROUTINE_COMMENT=''")) 'gate pins routine characteristics outside the body'
    Assert-Contract ($sql.Contains("COLUMN_KEY='PRI'") -and $sql.Contains("COLUMN_NAME='NDocumento'") -and $sql.Contains("TABLE_NAME IN('documenti','documentipie')") -and $sql.Contains("ENGINE='InnoDB'")) 'gate attests the documenti and documentipie schema'
    Assert-Contract ($sql.Contains("COLUMN_NAME IN('TotaleDocumento','TotMerce') AND COLUMN_TYPE='double(15,5)'")) 'gate attests the footer column types the rounded values are stored in'
    Assert-Contract ($sql.Contains('SET SESSION group_concat_max_len=4096;')) 'signature fingerprint immune to GROUP_CONCAT truncation'
    Assert-Contract ($sql.Contains('automatic_sp_privileges') -and $sql.Contains('also on success')) 'header requires routine grants to be re-verified also after a successful forward'
    Assert-Contract ($sql.Contains('the installed body must be the P0b body')) 'header states the dependency on the P0b migration'
    Assert-Contract ($sql.Contains('-- Never execute on production under the current mandate. Never use --force.')) 'production and --force warning present'
    Assert-Contract (-not ($sql -match '(?im)^\s*(USE\s|GRANT\s|REVOKE\s|ALTER\s+USER\s|CREATE\s+(VIEW|TABLE|USER)\s|SET\s+GLOBAL\s)')) 'no implicit target or other schema/account changes'
    Assert-Contract (-not ($sql -match '(?i)\bpassword\b|\bpwd\b|connection ?string')) 'no credential-like text'
}
foreach ($sql in @($forward, $rollback)) {
    Assert-Contract (([regex]::Matches($sql, '__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE')).Count -eq 1) 'one explicit original-DEFINER substitution'
    Assert-Contract ($sql.Contains('SET SESSION sql_mode=@ks_round_initial_sql_mode;') -and $sql.Contains('SET SESSION collation_connection=@ks_round_initial_collation;')) 'session settings restored on successful batch'
    Assert-Contract (([regex]::Matches($sql, 'DROP PROCEDURE Carrello_Documento;')).Count -eq 1) 'one DROP, no other object dropped'
}
foreach ($readOnly in @(@('preflight', $preflight), @('verify', $verify))) {
    $code = [regex]::Replace([string]$readOnly[1], '(?m)^--.*$', '')
    Assert-Contract (-not ($code -match '(?i)\b(DROP|CREATE|ALTER|INSERT|UPDATE|DELETE)\b')) ($readOnly[0] + ' is read-only (comments excluded)')
}

# Rounding stays in the database: the secret guard names the source-only files; the application keeps its own display math untouched here.
$guard = Read-Raw 'Tools/Test-DatabaseSecretsGuard.ps1'
foreach ($suffix in $suffixes) {
    Assert-Contract ($guard.Contains('Database Taikun/Migrations/' + $prefix + $suffix + '.sql')) ('secret guard names the source-only migration: ' + $suffix)
}
$matrix = Read-Raw 'Tools/Test-OrderSqlMatrixLab.ps1'
foreach ($case in @('R01', 'R02', 'R05', 'R06', 'R07', 'R08', 'R10', 'R11', 'R12')) {
    Assert-Contract ($matrix.Contains("Case '$case'")) ('matrix case present: ' + $case)
}
Assert-Contract ($matrix.Contains('$total = Round2 ($imp + $vatRaw')) 'matrix oracle rounds the exact total once'

[pscustomobject]@{ result = 'A'; checks = $checks; databaseConnections = 0; bodyHashP0b = $p0bHash; bodyHashNew = $newHash; scope = 'migration/source checks only; behavioural proof on the local LAB' } | ConvertTo-Json
