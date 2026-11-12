-- ORDER-DOCUMENT-NUMBER-OUT-P0B-1A (preflight). No USE statement: the operator selects the target.
-- Never execute on production under the current mandate. Never use --force.
-- OUT DocumentoMemorizzato must be the NDocumento the database really stored (trigger SettaProssimoDocumento assigns it from the shared counter group); one statement re-reads it right after the INSERT.
-- DBA generates an execution copy replacing __KEEPSTORE_ORIGINAL_DEFINER__
-- with the exact quoted original DEFINER, after SHOW CREATE SHA-256 comparison.
-- DROP/CREATE is NOT transactional: on any failure restore the protected exact
-- original CREATE, creation metadata and routine-specific grants before reopening checkout.
-- DROP removes the routine-specific grants when automatic_sp_privileges is ON and CREATE regrants only the creator:
-- record the routine grants before, then re-apply and re-verify them after the CREATE, also on success, before reopening checkout.
-- Only the private byte-exact backup restores the P1 text byte for byte; the rollback file restores its clean text.
-- Run with mysql batch mode WITHOUT --force; abort on the first error.
-- Required operator attestations are set only after private backup readback, grants
-- verification and exclusive checkout maintenance. They never replace those checks.
SET SESSION group_concat_max_len=4096;
SET @ks_docnum_guard=(
 (@KeepStoreRoutineBackupVerified <=> 1) AND (@KeepStoreCheckoutQuiesced <=> 1)
 AND (@@server_uuid <=> @KeepStoreExpectedServerUuid)
 AND (DATABASE() <=> @KeepStoreExpectedDatabase)
 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()
      AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE'
      AND SHA2(ROUTINE_DEFINITION,256) IN('2436eb55d8a1186e5064afb38c9afd1e506614330a1f594ca0abec47283666d8','1ef49a40b5c9e1aee3f8f9352b528973de42150cdf1f31316ce1c47edac84487')
      AND SECURITY_TYPE='DEFINER' AND DEFINER=@KeepStoreOriginalDefiner
      AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO' AND CHARACTER_SET_CLIENT='utf8mb4'
      AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci'
      AND DATABASE_COLLATION='utf8mb4_unicode_ci'
      AND IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='CONTAINS SQL' AND ROUTINE_COMMENT='')=1
 AND (SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE()
      AND SPECIFIC_NAME='Carrello_Documento' AND PARAMETER_MODE IN('IN','OUT'))=19
 AND (SELECT SHA2(GROUP_CONCAT(CONCAT_WS(':',ORDINAL_POSITION,PARAMETER_MODE,PARAMETER_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,''),COALESCE(NUMERIC_PRECISION,''),COALESCE(NUMERIC_SCALE,'')) ORDER BY ORDINAL_POSITION SEPARATOR '|'),256)
      FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Documento')='953b867c730f382dfc87975f3bd74a417e3946b3c977ce2075e8043134c6aaaa'
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti'
      AND ((COLUMN_NAME='id' AND COLUMN_KEY='PRI' AND EXTRA LIKE '%auto_increment%') OR COLUMN_NAME='NDocumento'))=2
 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti' AND ENGINE='InnoDB')=1);
SET @ks_docnum_guard_sql=IF(@ks_docnum_guard,'SELECT ''ORDER_DOCNUM_OUT_PREFLIGHT_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_DOCNUM_MIGRATION_PRECONDITION');
PREPARE ks_docnum_guard_stmt FROM @ks_docnum_guard_sql;
EXECUTE ks_docnum_guard_stmt;
DEALLOCATE PREPARE ks_docnum_guard_stmt;
