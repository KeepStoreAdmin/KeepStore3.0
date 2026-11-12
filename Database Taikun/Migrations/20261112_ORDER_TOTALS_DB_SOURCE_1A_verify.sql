-- ORDER-TOTALS-DB-SOURCE-1A (verify). No USE statement: the operator selects the target.
-- Never execute on production under the current mandate. Never use --force.
-- Carrello_Totali (read-only) is the single source of the document total arithmetic: Carrello_Documento calls it to write TotaleDocumento and TotMerce; the web can read the same numbers before the order exists.
-- Applies on top of ORDER-ROUNDING-HALF-UP-1A: the installed Carrello_Documento body must be the rounding body (hash gate).
-- Creates the read-only procedure Carrello_Totali first, then replaces Carrello_Documento so that it calls it.
-- DBA generates an execution copy replacing __KEEPSTORE_ORIGINAL_DEFINER__ (both procedures)
-- with the exact quoted original DEFINER, after SHOW CREATE SHA-256 comparison.
-- Privileges: Carrello_Documento (its DEFINER) must be able to EXECUTE Carrello_Totali and read vCarrello; the web account is not
-- changed in this phase (it calls Carrello_Documento only); a later phase where the web calls Carrello_Totali needs EXECUTE for it.
-- Contract of Carrello_Totali: OUT values are rounded separately, half away from zero, on exact DECIMAL sums; pTotIva is the rounded VAT
-- (goods, shipping, insurance and voucher), not documentipie.TotIva; an empty cart gives zero goods and the costs and voucher still count;
-- a NULL row amount, rate or cost propagates NULL as in the previous body. Single source: TotaleDocumento and TotMerce (not TotImponibile, TotIva).
-- DROP/CREATE is NOT transactional: on any failure restore the protected exact
-- original CREATE of Carrello_Documento, creation metadata and routine-specific grants before reopening checkout;
-- if Carrello_Documento was restored, Carrello_Totali may stay or be dropped.
-- DROP removes the routine-specific grants when automatic_sp_privileges is ON and CREATE regrants only the creator:
-- record the routine grants before, then re-apply and re-verify them after the CREATE, also on success, before reopening checkout.
-- The execution copy is LF text (hashes are over LF). Only the private byte-exact backup restores the previous body byte for byte.
-- Run with mysql batch mode WITHOUT --force; abort on the first error.
-- Required operator attestations are set only after private backup readback, grants
-- verification and exclusive checkout maintenance. They never replace those checks.
SET SESSION group_concat_max_len=4096;
SET @ks_totals_guard=(
 (@KeepStoreRoutineBackupVerified <=> 1) AND (@KeepStoreCheckoutQuiesced <=> 1)
 AND (@@server_uuid <=> @KeepStoreExpectedServerUuid)
 AND (DATABASE() <=> @KeepStoreExpectedDatabase)
 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()
      AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE'
      AND SHA2(ROUTINE_DEFINITION,256) IN('7095b84d5a4f7cf9287d6e581f46d09626fa6e0874fd924f5efe927b52880bad')
      AND SECURITY_TYPE='DEFINER' AND DEFINER=@KeepStoreOriginalDefiner
      AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO' AND CHARACTER_SET_CLIENT='utf8mb4'
      AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci'
      AND DATABASE_COLLATION='utf8mb4_unicode_ci'
      AND IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='CONTAINS SQL' AND ROUTINE_COMMENT='')=1
 AND (SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE()
      AND SPECIFIC_NAME='Carrello_Documento' AND PARAMETER_MODE IN('IN','OUT'))=19
 AND (SELECT SHA2(GROUP_CONCAT(CONCAT_WS(':',ORDINAL_POSITION,PARAMETER_MODE,PARAMETER_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,''),COALESCE(NUMERIC_PRECISION,''),COALESCE(NUMERIC_SCALE,'')) ORDER BY ORDINAL_POSITION SEPARATOR '|'),256)
      FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Documento')='953b867c730f382dfc87975f3bd74a417e3946b3c977ce2075e8043134c6aaaa'
 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()
      AND ROUTINE_NAME='Carrello_Totali' AND ROUTINE_TYPE='PROCEDURE'
      AND SHA2(ROUTINE_DEFINITION,256) IN('68bec9adc80468dc35c73f14ec829e1b958cbc67a1240ceb4752e28cd29e5abc')
      AND SECURITY_TYPE='DEFINER' AND DEFINER=@KeepStoreOriginalDefiner
      AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO' AND CHARACTER_SET_CLIENT='utf8mb4'
      AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci'
      AND DATABASE_COLLATION='utf8mb4_unicode_ci'
      AND IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='READS SQL DATA' AND ROUTINE_COMMENT='')=1
 AND (SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE()
      AND SPECIFIC_NAME='Carrello_Totali' AND PARAMETER_MODE IN('IN','OUT'))=12
 AND (SELECT SHA2(GROUP_CONCAT(CONCAT_WS(':',ORDINAL_POSITION,PARAMETER_MODE,PARAMETER_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,''),COALESCE(NUMERIC_PRECISION,''),COALESCE(NUMERIC_SCALE,'')) ORDER BY ORDINAL_POSITION SEPARATOR '|'),256)
      FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Totali')='ef869b823f7d7dc16305ac7862ef324c1dce34df6398c5bc1bdf743781ac1e60'
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti'
      AND ((COLUMN_NAME='id' AND COLUMN_KEY='PRI' AND EXTRA LIKE '%auto_increment%') OR COLUMN_NAME='NDocumento'))=2
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documentipie'
      AND COLUMN_NAME IN('TotaleDocumento','TotMerce') AND COLUMN_TYPE='double(15,5)')=2
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='vcarrello'
      AND COLUMN_NAME IN('LoginId','Importo','IdIvaRC','ValoreIvaRC','idEsenzioneIva','ValoreEsenzioneIva','Valoreiva'))=7
 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN('documenti','documentipie') AND ENGINE='InnoDB')=2);
SET @ks_totals_guard_sql=IF(@ks_totals_guard,'SELECT ''ORDER_TOTALS_VERIFY_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_TOTALS_MIGRATION_PRECONDITION');
PREPARE ks_totals_guard_stmt FROM @ks_totals_guard_sql;
EXECUTE ks_totals_guard_stmt;
DEALLOCATE PREPARE ks_totals_guard_stmt;
