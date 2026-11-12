[CmdletBinding()]
param([string]$RepositoryRoot)
# ORDER-TOTALS-DB-SOURCE-1A: static source checks of the four migration files (no database connection).
# Behavioural proof on the local LAB: Tools/Test-OrderSqlMatrixLab.ps1 -TotaliProcedure (Carrello_Totali = footer, every case),
# -FooterDump (footers before and after identical) and Tools/Test-OrderConcurrencyLab.ps1.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$checks = 0
function Assert-Contract([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw ('ORDER_TOTALS_TEST_FAILED: ' + $Name) }
    $script:checks++
}
$prefix = '20261112_ORDER_TOTALS_DB_SOURCE_1A_'
function Read-Raw([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-Contract (Test-Path -LiteralPath $path -PathType Leaf) ('file exists: ' + $RelativePath)
    [IO.File]::ReadAllText($path)
}
function Read-Create([string]$Sql, [string]$Name) {
    $pattern = '(?s)(CREATE DEFINER=__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE `' + $Name + '`.*?\n[ \t]*END)\s*\n\$\$\s*\nDELIMITER ;'
    $match = [regex]::Match($Sql.Replace([string][char]13, ''), $pattern)
    Assert-Contract $match.Success ('complete CREATE extracted: ' + $Name)
    $match.Groups[1].Value
}
function Get-Sha256([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Get-BodyHash([string]$Create) { Get-Sha256 ($Create.Substring($Create.IndexOf("`nBEGIN") + 1)) }

# Pinned state before the migration (rounding body) and the signature of Carrello_Documento (unchanged).
$roundHash = '9dc04290e8cdd4f377d462dca63bb063aa711dce389a547636733dc8441fd6ef'
$docSignatureHash = '953b867c730f382dfc87975f3bd74a417e3946b3c977ce2075e8043134c6aaaa'

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

$roundCreate = Read-Create (Read-Raw 'Database Taikun/Migrations/20261112_ORDER_ROUNDING_HALF_UP_1A_forward.sql') 'Carrello_Documento'
Assert-Contract ((Get-BodyHash $roundCreate) -ceq $roundHash) 'the base body is the integrated rounding body'
$newDoc = Read-Create $forward 'Carrello_Documento'
$restored = Read-Create $rollback 'Carrello_Documento'
$totali = Read-Create $forward 'Carrello_Totali'
Assert-Contract ($restored -ceq $roundCreate) 'rollback restores the exact rounding body'
Assert-Contract (-not $rollback.Contains('PROCEDURE `Carrello_Totali`')) 'rollback does not recreate Carrello_Totali'

# Carrello_Documento = rounding body minus the in-loop exact accumulation, with a call to Carrello_Totali (re-implemented independently).
$t = "`t"
$rate = 'IF((pUtenteAbilitatoRC=1) AND (pIdIvaRC>-1),pValoreIvaRC,IF(pidEsenzioneIva>-1,pValoreEsenzioneIva,parValoreIva))'
$declAdd = "`n${t}DECLARE impExact DECIMAL(40,8) DEFAULT 0;`n${t}DECLARE ivaExact DECIMAL(48,18) DEFAULT 0;`n${t}DECLARE totExact DECIMAL(48,18) DEFAULT 0;"
$loopAdd = "`n${t}${t}${t}SET impExact=impExact+CAST(pImporto AS DECIMAL(24,8));`n${t}${t}${t}SET ivaExact=ivaExact+CAST(pImporto AS DECIMAL(24,8))*CAST($rate AS DECIMAL(12,8))*0.01;"
$shipAdd = "`n${t}SET ivaExact=ivaExact+(CAST(pCostoSpedizione AS DECIMAL(24,8))+CAST(pCostoAssicurazione AS DECIMAL(24,8)))*CAST(pIvaVettore AS DECIMAL(12,8))*0.01;"
$totAdd = "`n${t}SET totExact=impExact+ivaExact+CAST(pCostoSpedizione AS DECIMAL(24,8))+CAST(pCostoAssicurazione AS DECIMAL(24,8))+CAST(pCostoPagamento AS DECIMAL(24,8))+CAST(pArrotondamento AS DECIMAL(24,8))+CAST(pBuonoScontoTotale AS DECIMAL(24,8))+CAST(pBuonoScontoTotale AS DECIMAL(24,8))*CAST(pBuonoScontoValoreIva AS DECIMAL(12,8))*0.01;"
$callLine = "`n${t}CALL Carrello_Totali(pLoginId,pCostoAssicurazione,pCostoSpedizione,pArrotondamento,pCostoPagamento,pUtenteAbilitatoRC,pIvaVettore,pBuonoScontoTotale,pBuonoScontoValoreIva,impTot,ivaTot,docTot);"
function Edit-Once([string]$Text, [string]$Old, [string]$New) {
    Assert-Contract (([regex]::Matches($Text, [regex]::Escape($Old))).Count -eq 1) ('single anchor in the rounding body: ' + $Old.Substring(0, [Math]::Min(48, $Old.Replace("`n", ' ').Length)).Replace("`n", ' '))
    return $Text.Replace($Old, $New)
}
$expected = $roundCreate
$expected = Edit-Once $expected $declAdd "`n${t}DECLARE impTot DECIMAL(15,2);`n${t}DECLARE ivaTot DECIMAL(15,2);`n${t}DECLARE docTot DECIMAL(15,2);"
$expected = Edit-Once $expected $loopAdd ''
$expected = Edit-Once $expected $shipAdd ''
$expected = Edit-Once $expected $totAdd $callLine
$expected = Edit-Once $expected "${t}${t}TotaleDocumento=ROUND(totExact,2)," "${t}${t}TotaleDocumento=docTot,"
$expected = Edit-Once $expected "${t}${t}TotMerce=ROUND(impExact,2)," "${t}${t}TotMerce=impTot,"
Assert-Contract ($newDoc -ceq $expected) 'Carrello_Documento = rounding body with exactly the six refactor edits'
Assert-Contract (-not ($newDoc -match 'impExact|ivaExact|totExact')) 'no exact accumulation left in Carrello_Documento'
Assert-Contract (([regex]::Matches($newDoc, 'CALL Carrello_Totali\(')).Count -eq 1) 'one call to Carrello_Totali'
Assert-Contract ($newDoc.IndexOf('CALL Carrello_Totali(') -lt $newDoc.IndexOf('INSERT INTO documentipie')) 'Totali is read before the footer is written'
Assert-Contract ($newDoc.IndexOf('CALL Carrello_Totali(') -lt $newDoc.IndexOf('DELETE FROM carrello')) 'Totali is read before the cart is consumed'
Assert-Contract ($newDoc.Contains('SELECT NDocumento INTO ndoc FROM documenti WHERE id=IdDocumento;') -and $newDoc.Contains('TotImponibile=Imponibile+pCostoSpedizione,') -and $newDoc.Contains('TotIva=totiva,')) 'P0b read-back, TotImponibile and TotIva unchanged'
Assert-Contract ($newDoc.IndexOf('INSERT INTO controllaArrotondamento') -lt $newDoc.IndexOf('BUONOSCONTO')) 'queue insert still precedes the voucher row'
Assert-Contract (-not ($newDoc -match '(?im)^\s*(START TRANSACTION|COMMIT|ROLLBACK)\s*;')) 'caller transaction boundary preserved'

# Carrello_Totali: read-only, exact DECIMAL, same effective-rate expression as the order loop, NULL parity.
$totaliHeader = $totali.Substring(0, $totali.IndexOf("`nBEGIN"))
$totaliBody = $totali.Substring($totali.IndexOf("`nBEGIN") + 1)
Assert-Contract ($totaliHeader.Contains('READS SQL DATA') -and $totaliHeader.Contains('SQL SECURITY DEFINER')) 'read-only characteristic and explicit DEFINER security'
Assert-Contract (-not ($totaliBody -match '(?i)\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|CALL|REPLACE|TRUNCATE|START|COMMIT|ROLLBACK)\b') -and -not ($totaliBody -match 'SET\s+@')) 'Carrello_Totali body has no write, call, transaction or session-variable statement'
Assert-Contract (-not ($totaliBody -match '(?i)DOUBLE|FLOAT|/\s*100|\bROUND\(\s*[a-z]+\s*\)')) 'no DOUBLE arithmetic, no division, no unary ROUND'
Assert-Contract (([regex]::Matches($totaliBody, 'FROM vCarrello')).Count -eq 1 -and $totaliBody.Contains('WHERE LoginId=pLoginId;')) 'one read of vCarrello filtered by the login'
$effRate = 'IF((pUtenteAbilitatoRC=1) AND (IdIvaRC>-1),ValoreIvaRC,IF(idEsenzioneIva>-1,ValoreEsenzioneIva,Valoreiva))'
Assert-Contract (([regex]::Matches($totaliBody, [regex]::Escape($effRate))).Count -eq 2) 'the effective-rate expression (RC, then exemption, then ordinary) used for COUNT and for the SUM cast'
Assert-Contract ($totaliBody.Contains('CAST(Importo AS DECIMAL(24,8))*CAST(' + $effRate + ' AS DECIMAL(12,8))*0.01')) 'row VAT = amount x rate x 0.01 on exact DECIMAL'
Assert-Contract ($totaliBody.Contains('IF righe=0 THEN') -and $totaliBody.Contains('ELSEIF righeImporto<righe THEN') -and $totaliBody.Contains('ELSEIF righeAliquota<righe THEN')) 'empty cart and NULL propagation handled explicitly'
Assert-Contract ($totaliBody.Contains('SET pTotMerce=ROUND(impExact,2);') -and $totaliBody.Contains('SET pTotale=ROUND(totExact,2);') -and $totaliBody.Contains('SET pTotIva=ROUND(ivaExact+buonoIva,2);')) 'three OUT values rounded once from exact sums'
Assert-Contract ($totaliBody.Contains('DECLARE impExact DECIMAL(40,8);') -and $totaliBody.Contains('DECLARE ivaRighe DECIMAL(48,18);') -and $totaliBody.Contains('DECLARE ivaExact DECIMAL(48,18);') -and $totaliBody.Contains('DECLARE totExact DECIMAL(48,18);')) 'accumulators wide enough (8 + 8 + 2 decimals for VAT)'
$totaliSumExpected = 'SET totExact=impExact+ivaExact+CAST(pCostoSpedizione AS DECIMAL(24,8))+CAST(pCostoAssicurazione AS DECIMAL(24,8))+CAST(pCostoPagamento AS DECIMAL(24,8))+CAST(pArrotondamento AS DECIMAL(24,8))+CAST(pBuonoScontoTotale AS DECIMAL(24,8))+buonoIva;'
Assert-Contract ($totaliBody.Contains($totaliSumExpected)) 'exact total = goods + VAT + shipping + insurance + payment + rounding + voucher + voucher VAT'

# Signature fingerprints rebuilt from the headers (same method as information_schema.PARAMETERS reports them).
function Get-SignatureHash([string]$Header) {
    $matches = [regex]::Matches($Header, '\b(IN|OUT)\s+(\w+)\s+(INT|DOUBLE|VARCHAR|DECIMAL)(?:\((\d+)(?:,(\d+))?\))')
    $parts = @(); $position = 0
    foreach ($m in $matches) {
        $position++
        $detail = switch ($m.Groups[3].Value) {
            'INT' { 'int::10:0' }
            'DOUBLE' { 'double::' + $m.Groups[4].Value + ':' + $m.Groups[5].Value }
            'VARCHAR' { 'varchar:' + $m.Groups[4].Value + '::' }
            'DECIMAL' { 'decimal::' + $m.Groups[4].Value + ':' + $m.Groups[5].Value }
        }
        $parts += ($position.ToString() + ':' + $m.Groups[1].Value + ':' + $m.Groups[2].Value + ':' + $detail)
    }
    return @{ Count = $parts.Count; Hash = (Get-Sha256 ($parts -join '|')) }
}
$docHeader = $newDoc.Substring(0, $newDoc.IndexOf("`nBEGIN"))
$docSig = Get-SignatureHash $docHeader
Assert-Contract ($docSig.Count -eq 19 -and $docSig.Hash -ceq $docSignatureHash) 'Carrello_Documento signature unchanged (19 parameters)'
$totSig = Get-SignatureHash $totaliHeader
Assert-Contract ($totSig.Count -eq 12) 'Carrello_Totali has 12 parameters (9 IN, 3 OUT)'
Assert-Contract ([regex]::Matches($totaliHeader, '\bOUT\s+').Count -eq 3 -and $totaliHeader.Contains('OUT pTotMerce DECIMAL(15,2), OUT pTotIva DECIMAL(15,2), OUT pTotale DECIMAL(15,2))')) 'three DECIMAL(15,2) OUT values'
$totSignatureHash = $totSig.Hash

$docHash = Get-BodyHash $newDoc
$totHash = Get-BodyHash $totali
Assert-Contract ($docHash -cne $roundHash) 'new Carrello_Documento hash differs from the rounding hash'
Assert-Contract ((Get-BodyHash $restored) -ceq $roundHash) 'restored body hash equals the rounding hash'

# Hash gates in the right states.
Assert-Contract ($preflight.Contains($roundHash) -and -not $preflight.Contains($docHash) -and -not $preflight.Contains($totHash)) 'preflight admits only the rounding body'
Assert-Contract ($preflight.Contains("ROUTINE_NAME='Carrello_Totali')=0")) 'preflight requires Carrello_Totali to be absent'
Assert-Contract ($verify.Contains($docHash) -and $verify.Contains($totHash) -and -not $verify.Contains($roundHash)) 'verify admits only the new Documento and the Totali body'
$firstDrop = $forward.IndexOf('DROP PROCEDURE')
$forwardBefore = $forward.Substring(0, $firstDrop)
$forwardAfter = $forward.Substring($forward.LastIndexOf('DELIMITER ;'))
Assert-Contract ($firstDrop -gt 0 -and $forwardBefore.Contains($roundHash) -and -not $forwardBefore.Contains($docHash) -and $forwardBefore.Contains("ROUTINE_NAME='Carrello_Totali')=0")) 'forward guard before the first DROP requires the rounding body and no Totali'
Assert-Contract ($forward.IndexOf('PROCEDURE `Carrello_Totali`') -lt $firstDrop) 'Carrello_Totali is created before Carrello_Documento is dropped'
Assert-Contract ($forwardAfter.Contains($docHash) -and $forwardAfter.Contains($totHash) -and $forwardAfter.Contains($totSignatureHash) -and -not $forwardAfter.Contains($roundHash)) 'forward final gate requires both new bodies and the Totali signature'
$rollbackDrop = $rollback.IndexOf('DROP PROCEDURE')
$rollbackBefore = $rollback.Substring(0, $rollbackDrop)
$rollbackAfter = $rollback.Substring($rollback.LastIndexOf('DELIMITER ;'))
Assert-Contract ($rollbackDrop -gt 0 -and $rollbackBefore.Contains($docHash) -and $rollbackBefore.Contains($totHash) -and -not $rollbackBefore.Contains($roundHash)) 'rollback guard before the first DROP requires both new bodies'
Assert-Contract ($rollbackAfter.Contains($roundHash) -and -not $rollbackAfter.Contains($docHash) -and $rollbackAfter.Contains("ROUTINE_NAME='Carrello_Totali')=0")) 'rollback final gate requires the rounding body and no Totali'
Assert-Contract ($rollback.IndexOf('DROP PROCEDURE Carrello_Documento;') -lt $rollback.IndexOf('DROP PROCEDURE Carrello_Totali;')) 'rollback restores Carrello_Documento before dropping Carrello_Totali'

foreach ($sql in @($preflight, $forward, $verify, $rollback)) {
    Assert-Contract ($sql.Contains('KEEPSTORE_STOP_TOTALS_MIGRATION_PRECONDITION')) 'executable fail-closed precondition'
    Assert-Contract ($sql.Contains('@KeepStoreRoutineBackupVerified') -and $sql.Contains('@KeepStoreCheckoutQuiesced')) 'external backup and checkout gates required'
    Assert-Contract ($sql.Contains('@KeepStoreExpectedServerUuid') -and $sql.Contains('@KeepStoreExpectedDatabase')) 'explicit target identity required'
    Assert-Contract ($sql.Contains('DEFINER=@KeepStoreOriginalDefiner')) 'original DEFINER required'
    Assert-Contract ($sql.Contains("SQL_MODE='NO_AUTO_VALUE_ON_ZERO'") -and $sql.Contains("CHARACTER_SET_CLIENT='utf8mb4'") -and $sql.Contains("DATABASE_COLLATION='utf8mb4_unicode_ci'")) 'creation metadata gate preserved'
    Assert-Contract ($sql.Contains($docSignatureHash)) 'gate pins the Carrello_Documento signature fingerprint'
    Assert-Contract ($sql.Contains("IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='CONTAINS SQL' AND ROUTINE_COMMENT=''")) 'gate pins the Carrello_Documento characteristics'
    Assert-Contract ($sql.Contains("COLUMN_KEY='PRI'") -and $sql.Contains("COLUMN_NAME='NDocumento'") -and $sql.Contains("TABLE_NAME IN('documenti','documentipie')") -and $sql.Contains("ENGINE='InnoDB'")) 'gate attests the documenti and documentipie schema'
    Assert-Contract ($sql.Contains("COLUMN_NAME IN('TotaleDocumento','TotMerce') AND COLUMN_TYPE='double(15,5)'")) 'gate attests the footer column types'
    Assert-Contract ($sql.Contains("TABLE_NAME='vcarrello'") -and $sql.Contains("COLUMN_NAME IN('LoginId','Importo','IdIvaRC','ValoreIvaRC','idEsenzioneIva','ValoreEsenzioneIva','Valoreiva'))=7")) 'gate attests the vCarrello columns Carrello_Totali reads'
    Assert-Contract ($sql.Contains('SET SESSION group_concat_max_len=4096;')) 'signature fingerprint immune to GROUP_CONCAT truncation'
    Assert-Contract ($sql.Contains('automatic_sp_privileges') -and $sql.Contains('also on success')) 'header requires routine grants to be re-verified also after a successful forward'
    Assert-Contract ($sql.Contains('the installed Carrello_Documento body must be the rounding body')) 'header states the dependency on the rounding migration'
    Assert-Contract ($sql.Contains('-- Privileges: Carrello_Documento (its DEFINER) must be able to EXECUTE Carrello_Totali and read vCarrello') -and $sql.Contains('Contract of Carrello_Totali')) 'header documents the privileges and the contract'
    Assert-Contract ($sql.Contains('-- Never execute on production under the current mandate. Never use --force.')) 'production and --force warning present'
    Assert-Contract (-not ($sql -match '(?im)^\s*(USE\s|GRANT\s|REVOKE\s|ALTER\s+USER\s|CREATE\s+(VIEW|TABLE|USER)\s|SET\s+GLOBAL\s)')) 'no implicit target or other schema/account changes'
    Assert-Contract (-not ($sql -match '(?i)\bpassword\b|\bpwd\b|connection ?string')) 'no credential-like text'
}
foreach ($sql in @($verify, $forwardAfter, $rollbackBefore)) {
    Assert-Contract ($sql.Contains($totSignatureHash) -and $sql.Contains("SQL_DATA_ACCESS='READS SQL DATA'") -and $sql.Contains("PARAMETER_MODE IN('IN','OUT'))=12")) 'gates that expect Carrello_Totali pin its signature, READS SQL DATA and 12 parameters'
}
Assert-Contract (([regex]::Matches($forward, '__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE')).Count -eq 2) 'forward: one explicit original-DEFINER substitution per procedure'
Assert-Contract (([regex]::Matches($rollback, '__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE')).Count -eq 1) 'rollback: one explicit original-DEFINER substitution'
foreach ($sql in @($forward, $rollback)) {
    Assert-Contract ($sql.Contains('SET SESSION sql_mode=@ks_totals_initial_sql_mode;') -and $sql.Contains('SET SESSION collation_connection=@ks_totals_initial_collation;')) 'session settings restored on successful batch'
}
Assert-Contract (([regex]::Matches($forward, 'DROP PROCEDURE Carrello_Documento;')).Count -eq 1 -and -not $forward.Contains('DROP PROCEDURE Carrello_Totali')) 'forward: one DROP, of Carrello_Documento only'
Assert-Contract (([regex]::Matches($rollback, 'DROP PROCEDURE ')).Count -eq 2) 'rollback: two DROPs, the two procedures only'
foreach ($readOnly in @(@('preflight', $preflight), @('verify', $verify))) {
    $code = [regex]::Replace([string]$readOnly[1], '(?m)^--.*$', '')
    Assert-Contract (-not ($code -match '(?i)\b(DROP|CREATE|ALTER|INSERT|UPDATE|DELETE)\b')) ($readOnly[0] + ' is read-only (comments excluded)')
}

# Tooling: secret guard names the source-only files; the matrix checks Carrello_Totali = footer and can dump the footers.
$guard = Read-Raw 'Tools/Test-DatabaseSecretsGuard.ps1'
foreach ($suffix in $suffixes) {
    Assert-Contract ($guard.Contains('Database Taikun/Migrations/' + $prefix + $suffix + '.sql')) ('secret guard names the source-only migration: ' + $suffix)
}
$matrix = Read-Raw 'Tools/Test-OrderSqlMatrixLab.ps1'
Assert-Contract ($matrix.Contains('[string]$TotaliProcedure') -and $matrix.Contains('function Check-Totali') -and $matrix.Contains('[string]$FooterDump')) 'matrix tool: Totali equality check and footer dump'
foreach ($case in @('R13', 'R14', 'R15')) { Assert-Contract ($matrix.Contains("Case '$case'")) ('matrix case present: ' + $case) }
# The footer column is DOUBLE: the equality with the exact DECIMAL(15,2) result must tolerate binary noise (1e-6) and nothing coarser, never a strict decimal equality and never a half-cent tolerance.
Assert-Contract ($matrix.Contains('[Math]::Abs([decimal]$a - [decimal]$b) -le [decimal]0.000001')) 'matrix tool: Totali = footer compares with a 1e-6 tolerance (DOUBLE column noise), not exactly and not at half a cent'
Assert-Contract (-not ($matrix.Contains('([decimal]$a -eq [decimal]$b)'))) 'matrix tool: no strict decimal equality left in the Totali check'

[pscustomobject]@{ result = 'A'; checks = $checks; databaseConnections = 0; bodyHashRounding = $roundHash; bodyHashDocumento = $docHash; bodyHashTotali = $totHash; signatureHashTotali = $totSignatureHash; scope = 'migration/source checks only; behavioural proof on the local LAB' } | ConvertTo-Json
