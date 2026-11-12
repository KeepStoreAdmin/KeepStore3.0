-- ORDER-ROUNDING-HALF-UP-1A (preflight). No USE statement: the operator selects the target.
-- Never execute on production under the current mandate. Never use --force.
-- Document total and goods total are rounded once, half away from zero, on exact DECIMAL sums (PO rule: amounts to the cent, third digit 5-9 rounds up); DOUBLE ROUND and DOUBLE(15,3) SET rounding no longer decide the footer.
-- Applies on top of ORDER-DOCUMENT-NUMBER-OUT-P0B-1A: the installed body must be the P0b body (hash gate).
-- DBA generates an execution copy replacing __KEEPSTORE_ORIGINAL_DEFINER__
-- with the exact quoted original DEFINER, after SHOW CREATE SHA-256 comparison.
-- DROP/CREATE is NOT transactional: on any failure restore the protected exact
-- original CREATE, creation metadata and routine-specific grants before reopening checkout.
-- DROP removes the routine-specific grants when automatic_sp_privileges is ON and CREATE regrants only the creator:
-- record the routine grants before, then re-apply and re-verify them after the CREATE, also on success, before reopening checkout.
-- The execution copy is LF text (hashes are over LF). Only the private byte-exact backup restores the previous body byte for byte.
-- Run with mysql batch mode WITHOUT --force; abort on the first error.
-- Required operator attestations are set only after private backup readback, grants
-- verification and exclusive checkout maintenance. They never replace those checks.
SET SESSION group_concat_max_len=4096;
SET @ks_round_guard=(
 (@KeepStoreRoutineBackupVerified <=> 1) AND (@KeepStoreCheckoutQuiesced <=> 1)
 AND (@@server_uuid <=> @KeepStoreExpectedServerUuid)
 AND (DATABASE() <=> @KeepStoreExpectedDatabase)
 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()
      AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE'
      AND SHA2(ROUTINE_DEFINITION,256) IN('1383f81ce006011456e053946847d1151f573b5cdd6183a96f635c73407cb8da')
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
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documentipie'
      AND COLUMN_NAME IN('TotaleDocumento','TotMerce') AND COLUMN_TYPE='double(15,5)')=2
 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN('documenti','documentipie') AND ENGINE='InnoDB')=2);
SET @ks_round_guard_sql=IF(@ks_round_guard,'SELECT ''ORDER_ROUNDING_PREFLIGHT_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_ROUNDING_MIGRATION_PRECONDITION');
PREPARE ks_round_guard_stmt FROM @ks_round_guard_sql;
EXECUTE ks_round_guard_stmt;
DEALLOCATE PREPARE ks_round_guard_stmt;
