[CmdletBinding()]
param([string]$RepositoryRoot, [string]$RuntimeEvidencePath, [string]$LabSqlOutputPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$checks = 0
function Assert-Contract([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw ('ORDER_VAT_ID_TEST_FAILED: ' + $Name) }
    $script:checks++
}
function Read-Migration([string]$Suffix) {
    [IO.File]::ReadAllText((Join-Path $RepositoryRoot ('Database Taikun/Migrations/20261027_ORDER_VAT_ID_SEMANTICS_P1_1A_' + $Suffix + '.sql'))).Replace([string][char]13, '')
}
function Read-Create([string]$Sql) {
    $match = [regex]::Match($Sql, '(?s)(CREATE DEFINER=__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE.*?\n[ \t]*END)\s*\n\$\$\s*\nDELIMITER ;')
    Assert-Contract $match.Success 'complete CREATE extracted'
    $match.Groups[1].Value
}
function Normalize-Body([string]$Sql) {
    ([regex]::Replace(([regex]::Replace($Sql, '(?s)/\*.*?\*/', '')), '\s+', ' ')).Trim()
}

function Get-SyntheticRegimeSql {
    # Run only in batch mode without --force, with exclusive access to this
    # existing synthetic LAB. Every procedure CALL and fixture update rolls back.
    # No login, connection string or database connection is created by this script.
@'
USE keepstore_regorder_lab_20261025;
SET @ks_test_lab=(@@server_uuid='1167ebae-d0c0-11f1-b348-9c7bef540c10' AND @@port=13317 AND DATABASE()='keepstore_regorder_lab_20261025' AND (SELECT COUNT(*) FROM carrello)=0 AND (SELECT COUNT(*) FROM iva WHERE (id=1 AND Valore=22) OR(id IN(701,702) AND Valore=0))=3);
SET @ks_test_guard=IF(@ks_test_lab,'SELECT ''VAT_SYNTHETIC_TARGET_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_WRONG_SYNTHETIC_TARGET');
PREPARE ks_test FROM @ks_test_guard;EXECUTE ks_test;DEALLOCATE PREPARE ks_test;
USE keepstore_regorder_lab_20261025;
START TRANSACTION;
SET @before_docs=(SELECT COUNT(*) FROM documenti),@before_reserved=(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1),@before_number=(SELECT COALESCE(MAX(NDocumento),0) FROM documenti WHERE TipoDocumentiId=4 AND YEAR(DataDocumento)=YEAR(CURDATE()));
SET @addr=(SELECT UtentiIndirizziId FROM vlogin WHERE id=19832);
UPDATE utenti SET AbilitatoIvaReverseCharge=0,idEsenzioneIva=0 WHERE Id=1;
INSERT INTO carrello(LoginId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva)
VALUES(19832,1,-1,'KS-LAB-ARTICLE','KS TEST VAT ID',2,1,10,12.2,701,0,'KS TEST RC',-1,-1,'KS TEST EXEMPT');
CALL Carrello_Documento(19832,4,1,1,@addr,0,0,0,0,'KS SYNTHETIC ROLLBACK VAT ordinary',0,22,1,'','',0,1,22,@doc_number);
SET @created=(SELECT MAX(id) FROM documenti WHERE UtentiId=1);
SELECT 'SQL_CASE',JSON_OBJECT('case','ordinary','idCorrect',r.iva=1,'dictionaryCorrect',i.id=1 AND i.Valore=22,'unitNet',r.prezzo=10,'quantity',r.Qnt=2,'net',r.importo=20,'viewGross',ROUND(v.ImportoIvato,2)=24.4,'viewUnitGross',ROUND(v.PrezzoIvato,2)=12.2,'footerTax',ROUND(p.TotIva,2)=4.4,'footerTotal',ROUND(p.TotaleDocumento,2)=24.4,'oneDocument',(SELECT COUNT(*) FROM documenti)=@before_docs+1,'number',@doc_number=@before_number+1,'tenant',d.AziendeId=1 AND d.Listino=1,'reserved',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=@before_reserved+2,'physical',(SELECT Giacenza FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=100,'cartConsumed',(SELECT COUNT(*) FROM carrello WHERE LoginId=19832)=0)
FROM documentirighe r JOIN documenti d ON d.id=r.DocumentiId JOIN documentipie p ON p.DocumentiId=d.id JOIN iva i ON i.id=r.iva JOIN vdocumentirighe v ON v.id=r.id WHERE d.id=@created;
ROLLBACK;
SELECT 'SQL_ROLLBACK',JSON_OBJECT('case','ordinary','documentsRestored',(SELECT COUNT(*) FROM documenti)=@before_docs,'reservationRestored',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=@before_reserved,'cartEmpty',(SELECT COUNT(*) FROM carrello)=0);
START TRANSACTION;
SET @before_docs=(SELECT COUNT(*) FROM documenti),@before_reserved=(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1),@before_number=(SELECT COALESCE(MAX(NDocumento),0) FROM documenti WHERE TipoDocumentiId=4 AND YEAR(DataDocumento)=YEAR(CURDATE()));
SET @addr=(SELECT UtentiIndirizziId FROM vlogin WHERE id=19832);
UPDATE utenti SET AbilitatoIvaReverseCharge=1,idEsenzioneIva=0 WHERE Id=1;
INSERT INTO carrello(LoginId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva)
VALUES(19832,1,-1,'KS-LAB-ARTICLE','KS TEST VAT ID',2,1,10,10,701,0,'KS TEST RC',-1,-1,'KS TEST EXEMPT');
CALL Carrello_Documento(19832,4,1,1,@addr,0,0,0,0,'KS SYNTHETIC ROLLBACK VAT reverse-charge',1,22,1,'','',0,1,22,@doc_number);
SET @created=(SELECT MAX(id) FROM documenti WHERE UtentiId=1);
SELECT 'SQL_CASE',JSON_OBJECT('case','reverse-charge','idCorrect',r.iva=701,'dictionaryCorrect',i.id=701 AND i.Valore=0,'unitNet',r.prezzo=10,'quantity',r.Qnt=2,'net',r.importo=20,'viewGross',ROUND(v.ImportoIvato,2)=20,'viewUnitGross',ROUND(v.PrezzoIvato,2)=10,'footerTax',ROUND(p.TotIva,2)=0,'footerTotal',ROUND(p.TotaleDocumento,2)=20,'oneDocument',(SELECT COUNT(*) FROM documenti)=@before_docs+1,'number',@doc_number=@before_number+1,'tenant',d.AziendeId=1 AND d.Listino=1,'reserved',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=@before_reserved+2,'physical',(SELECT Giacenza FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=100,'cartConsumed',(SELECT COUNT(*) FROM carrello WHERE LoginId=19832)=0)
FROM documentirighe r JOIN documenti d ON d.id=r.DocumentiId JOIN documentipie p ON p.DocumentiId=d.id JOIN iva i ON i.id=r.iva JOIN vdocumentirighe v ON v.id=r.id WHERE d.id=@created;
ROLLBACK;
SELECT 'SQL_ROLLBACK',JSON_OBJECT('case','reverse-charge','documentsRestored',(SELECT COUNT(*) FROM documenti)=@before_docs,'reservationRestored',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=@before_reserved,'cartEmpty',(SELECT COUNT(*) FROM carrello)=0);
START TRANSACTION;
SET @before_docs=(SELECT COUNT(*) FROM documenti),@before_reserved=(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1),@before_number=(SELECT COALESCE(MAX(NDocumento),0) FROM documenti WHERE TipoDocumentiId=4 AND YEAR(DataDocumento)=YEAR(CURDATE()));
SET @addr=(SELECT UtentiIndirizziId FROM vlogin WHERE id=19833);
UPDATE utenti SET AbilitatoIvaReverseCharge=0,idEsenzioneIva=702 WHERE Id=2;
INSERT INTO carrello(LoginId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva)
VALUES(19833,1,-1,'KS-LAB-ARTICLE','KS TEST VAT ID',2,10,12,12,701,0,'KS TEST RC',702,0,'KS TEST EXEMPT');
CALL Carrello_Documento(19833,4,2,2,@addr,0,0,0,0,'KS SYNTHETIC ROLLBACK VAT exemption',0,22,1,'','',0,1,22,@doc_number);
SET @created=(SELECT MAX(id) FROM documenti WHERE UtentiId=2);
SELECT 'SQL_CASE',JSON_OBJECT('case','exemption','idCorrect',r.iva=702,'dictionaryCorrect',i.id=702 AND i.Valore=0,'unitNet',r.prezzo=12,'quantity',r.Qnt=2,'net',r.importo=24,'viewGross',ROUND(v.ImportoIvato,2)=24,'viewUnitGross',ROUND(v.PrezzoIvato,2)=12,'footerTax',ROUND(p.TotIva,2)=0,'footerTotal',ROUND(p.TotaleDocumento,2)=24,'oneDocument',(SELECT COUNT(*) FROM documenti)=@before_docs+1,'number',@doc_number=@before_number+1,'tenant',d.AziendeId=2 AND d.Listino=10,'reserved',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=@before_reserved+2,'physical',(SELECT Giacenza FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=100,'cartConsumed',(SELECT COUNT(*) FROM carrello WHERE LoginId=19833)=0)
FROM documentirighe r JOIN documenti d ON d.id=r.DocumentiId JOIN documentipie p ON p.DocumentiId=d.id JOIN iva i ON i.id=r.iva JOIN vdocumentirighe v ON v.id=r.id WHERE d.id=@created;
ROLLBACK;
SELECT 'SQL_ROLLBACK',JSON_OBJECT('case','exemption','documentsRestored',(SELECT COUNT(*) FROM documenti)=@before_docs,'reservationRestored',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=@before_reserved,'cartEmpty',(SELECT COUNT(*) FROM carrello)=0);
START TRANSACTION;
SET @before_docs=(SELECT COUNT(*) FROM documenti),@before_reserved=(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1),@before_number=(SELECT COALESCE(MAX(NDocumento),0) FROM documenti WHERE TipoDocumentiId=4 AND YEAR(DataDocumento)=YEAR(CURDATE()));
SET @addr=(SELECT UtentiIndirizziId FROM vlogin WHERE id=19832);
UPDATE utenti SET AbilitatoIvaReverseCharge=1,idEsenzioneIva=702 WHERE Id=1;
INSERT INTO carrello(LoginId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva)
VALUES(19832,1,-1,'KS-LAB-ARTICLE','KS TEST VAT ID',2,1,10,10,701,0,'KS TEST RC',702,0,'KS TEST EXEMPT');
CALL Carrello_Documento(19832,4,1,1,@addr,0,0,0,0,'KS SYNTHETIC ROLLBACK VAT rc-precedes-exemption',1,22,1,'','',0,1,22,@doc_number);
SET @created=(SELECT MAX(id) FROM documenti WHERE UtentiId=1);
SELECT 'SQL_CASE',JSON_OBJECT('case','rc-precedes-exemption','idCorrect',r.iva=701,'dictionaryCorrect',i.id=701 AND i.Valore=0,'unitNet',r.prezzo=10,'quantity',r.Qnt=2,'net',r.importo=20,'viewGross',ROUND(v.ImportoIvato,2)=20,'viewUnitGross',ROUND(v.PrezzoIvato,2)=10,'footerTax',ROUND(p.TotIva,2)=0,'footerTotal',ROUND(p.TotaleDocumento,2)=20,'oneDocument',(SELECT COUNT(*) FROM documenti)=@before_docs+1,'number',@doc_number=@before_number+1,'tenant',d.AziendeId=1 AND d.Listino=1,'reserved',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=@before_reserved+2,'physical',(SELECT Giacenza FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=100,'cartConsumed',(SELECT COUNT(*) FROM carrello WHERE LoginId=19832)=0)
FROM documentirighe r JOIN documenti d ON d.id=r.DocumentiId JOIN documentipie p ON p.DocumentiId=d.id JOIN iva i ON i.id=r.iva JOIN vdocumentirighe v ON v.id=r.id WHERE d.id=@created;
ROLLBACK;
SELECT 'SQL_ROLLBACK',JSON_OBJECT('case','rc-precedes-exemption','documentsRestored',(SELECT COUNT(*) FROM documenti)=@before_docs,'reservationRestored',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=@before_reserved,'cartEmpty',(SELECT COUNT(*) FROM carrello)=0);
SELECT 'OLD_COUNTEREXAMPLE',701<>0 AND 702<>0 AND (SELECT COUNT(*) FROM iva WHERE id=0)=0;

'@
}

$preflight = Read-Migration 'preflight'
$forward = Read-Migration 'forward'
$verify = Read-Migration 'verify'
$rollback = Read-Migration 'rollback'
$fixed = Read-Create $forward
$original = Read-Create $rollback
$old = 'iva=IF((pUtenteAbilitatoRC=1) AND (pIdIvaRC>-1),pValoreIvaRC,IF(pidEsenzioneIva>-1,pValoreEsenzioneIva,parIva)),'
$new = 'iva=IF((pUtenteAbilitatoRC=1) AND (pIdIvaRC>-1),pIdIvaRC,IF(pidEsenzioneIva>-1,pidEsenzioneIva,parIva)),'
Assert-Contract (([regex]::Matches($original, [regex]::Escape($old))).Count -eq 1) 'one original assignment'
Assert-Contract ($fixed -ceq $original.Replace($old, $new)) 'exactly two ID operands changed; all other SQL identical'
Assert-Contract (-not $fixed.Contains($old)) 'percentage operands not persisted as VAT IDs'
Assert-Contract (([regex]::Matches($fixed, [regex]::Escape($new))).Count -eq 1) 'one fixed assignment, RC then exemption then ordinary'
$header = $fixed.Substring(0, $fixed.IndexOf('BEGIN'))
Assert-Contract (([regex]::Matches($header, '\b(?:IN|OUT)\s+\w+')).Count -eq 19) '19 parameter modes preserved'
$historical = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Database Taikun/Migrations/20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_forward.sql'))
$historicalBody = $historical.Substring($historical.IndexOf('BEGIN'), $historical.LastIndexOf('END$$') + 3 - $historical.IndexOf('BEGIN'))
Assert-Contract ((Normalize-Body $original.Substring($original.IndexOf('BEGIN'))) -ceq (Normalize-Body $historicalBody)) 'rollback preserves existing inventory procedure, excluding comments only'
Assert-Contract ($fixed.Contains('SET totiva=totiva+IF((pUtenteAbilitatoRC=1) AND (pIdIvaRC>-1),pImporto*pValoreIvaRC/100,IF(pidEsenzioneIva>-1,pImporto*pValoreEsenzioneIva/100,pImporto*parValoreIva/100));')) 'percentage formula preserved'
Assert-Contract (-not ($fixed -match '(?im)^\s*(START TRANSACTION|COMMIT|ROLLBACK)\s*;')) 'caller transaction boundary preserved'
$sha = [Security.Cryptography.SHA256]::Create()
try {
    $beforeHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($original.Substring($original.IndexOf('BEGIN'))))).Replace('-', '').ToLowerInvariant()
    $afterHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($fixed.Substring($fixed.IndexOf('BEGIN'))))).Replace('-', '').ToLowerInvariant()
} finally { $sha.Dispose() }
Assert-Contract ($preflight.Contains($beforeHash)) 'preflight hashes full original body'
Assert-Contract ($verify.Contains($afterHash)) 'verify hashes full fixed body'
Assert-Contract ($forward.IndexOf($beforeHash) -lt $forward.IndexOf('DROP PROCEDURE')) 'original body guard precedes DROP'
Assert-Contract ($rollback.IndexOf($afterHash) -lt $rollback.IndexOf('DROP PROCEDURE')) 'rollback refuses unrelated installed body'
foreach ($sql in @($preflight, $forward, $verify, $rollback)) {
    Assert-Contract ($sql.Contains('KEEPSTORE_STOP_VAT_MIGRATION_PRECONDITION')) 'executable fail-closed precondition'
    Assert-Contract ($sql.Contains('@KeepStoreRoutineBackupVerified') -and $sql.Contains('@KeepStoreCheckoutQuiesced')) 'external backup and checkout gates required'
    Assert-Contract ($sql.Contains('@KeepStoreExpectedServerUuid') -and $sql.Contains('@KeepStoreExpectedDatabase')) 'explicit target identity required'
    Assert-Contract ($sql.Contains('DEFINER=@KeepStoreOriginalDefiner')) 'original DEFINER required'
    Assert-Contract ($sql.Contains("SQL_MODE='NO_AUTO_VALUE_ON_ZERO'") -and $sql.Contains("CHARACTER_SET_CLIENT='utf8mb4'") -and $sql.Contains("DATABASE_COLLATION='utf8mb4_unicode_ci'")) 'creation metadata gate preserved'
    Assert-Contract (-not ($sql -match '(?im)^\s*(USE\s|GRANT\s|REVOKE\s|ALTER\s+USER\s|CREATE\s+(VIEW|TABLE|USER)\s|SET\s+GLOBAL\s)')) 'no implicit target or other schema/account changes'
}
foreach ($sql in @($forward, $rollback)) {
    Assert-Contract (([regex]::Matches($sql, '__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE')).Count -eq 1) 'one explicit original-DEFINER substitution'
    Assert-Contract ($sql.Contains('SET SESSION sql_mode=@ks_vat_initial_sql_mode;') -and $sql.Contains('SET SESSION collation_connection=@ks_vat_initial_collation;')) 'session settings restored on successful batch'
}

$syntheticSql = Get-SyntheticRegimeSql
Assert-Contract (([regex]::Matches($syntheticSql,'(?m)^CALL Carrello_Documento\(')).Count -eq 4) 'four actual procedure calls in generated LAB tests'
Assert-Contract (([regex]::Matches($syntheticSql,'(?m)^ROLLBACK;')).Count -eq 4) 'all four SQL cases roll back'
Assert-Contract (-not ($syntheticSql -match '(?im)^\s*COMMIT;')) 'generated tests never commit'
Assert-Contract ($syntheticSql.Contains('KEEPSTORE_STOP_WRONG_SYNTHETIC_TARGET')) 'generated SQL rejects other target or fixture state'
if($LabSqlOutputPath){
    if(-not [IO.Path]::IsPathRooted($LabSqlOutputPath)){throw 'LAB_SQL_OUTPUT_MUST_BE_ABSOLUTE'}
    $destination=[IO.Path]::GetFullPath($LabSqlOutputPath)
    if($destination.StartsWith([IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'LAB_SQL_OUTPUT_MUST_BE_OUTSIDE_REPOSITORY'}
    [IO.File]::WriteAllText($destination,$syntheticSql,(New-Object Text.UTF8Encoding($false)))
}

$runtimeChecks = 0
if ($RuntimeEvidencePath) {
    $runtime = Get-Content -LiteralPath $RuntimeEvidencePath -Raw | ConvertFrom-Json
    Assert-Contract (($runtime.installedBodySha256 -cin @($afterHash, '2436eb55d8a1186e5064afb38c9afd1e506614330a1f594ca0abec47283666d8')) -and $runtime.normalizedInstalledBodySha256 -ceq $afterHash) 'runtime fixed body matches source after trailing-whitespace-only serialization'
    foreach ($case in $runtime.assertions) {
        Assert-Contract ([bool]$case.pass) ('runtime ' + $case.name)
        $runtimeChecks++
    }
    Assert-Contract ($runtimeChecks -gt 0) 'runtime evidence not empty'
}
[pscustomobject]@{ result = 'A'; checks = $checks; runtimeChecks = $runtimeChecks; databaseConnections = 0; scope = 'migration/source checks; optional independently captured LAB evidence' } | ConvertTo-Json
