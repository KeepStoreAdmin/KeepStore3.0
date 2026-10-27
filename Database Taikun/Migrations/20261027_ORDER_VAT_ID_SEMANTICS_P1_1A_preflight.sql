-- ORDER-VAT-ID-SEMANTICS-P1-1A. No USE statement: the operator selects the target.
-- Never execute on production under the current mandate. Never use --force.
-- DBA generates an execution copy replacing __KEEPSTORE_ORIGINAL_DEFINER__
-- with the exact quoted original DEFINER, after SHOW CREATE SHA-256 comparison.
-- DROP/CREATE is NOT transactional: on any failure restore the protected exact
-- original CREATE, creation metadata and routine-specific grants before reopening checkout.
-- ORDER_VAT_ID_PREFLIGHT_A. Run with mysql batch mode WITHOUT --force; abort on the first error.
-- Required operator attestations are set only after private backup readback, grants
-- verification and exclusive checkout maintenance. They never replace those checks.
SET @ks_vat_guard=(
 (@KeepStoreRoutineBackupVerified <=> 1) AND (@KeepStoreCheckoutQuiesced <=> 1)
 AND (@@server_uuid <=> @KeepStoreExpectedServerUuid)
 AND (DATABASE() <=> @KeepStoreExpectedDatabase)
 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()
      AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE'
      AND SHA2(ROUTINE_DEFINITION,256) IN('6d50508d402d4f35e5a8918825a5e6b66b5cfdcf5e4cf5fc41697b5535b6af23','1d1bfdbeb988f546968e5a5e9a56198dd6ccb1ad1d76de3139ea0f876c199519')
      AND SECURITY_TYPE='DEFINER' AND DEFINER=@KeepStoreOriginalDefiner
      AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO' AND CHARACTER_SET_CLIENT='utf8mb4'
      AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci'
      AND DATABASE_COLLATION='utf8mb4_unicode_ci')=1
 AND (SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE()
      AND SPECIFIC_NAME='Carrello_Documento' AND PARAMETER_MODE IN('IN','OUT'))=19);
SET @ks_vat_guard_sql=IF(@ks_vat_guard,'SELECT ''ORDER_VAT_ID_PREFLIGHT_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_VAT_MIGRATION_PRECONDITION');
PREPARE ks_vat_guard_stmt FROM @ks_vat_guard_sql;
EXECUTE ks_vat_guard_stmt;
DEALLOCATE PREPARE ks_vat_guard_stmt;