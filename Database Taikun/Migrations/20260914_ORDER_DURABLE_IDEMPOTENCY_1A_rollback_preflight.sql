-- ORDER-DURABLE-IDEMPOTENCY-1A - read-only rollback preflight

SET @ks_rollback_preflight_sql := IF(
  EXISTS (SELECT 1 FROM information_schema.TABLES
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza'),
  'SELECT ''RollbackTableState'' AS CheckName, CASE WHEN COUNT(*)=0 THEN ''OK'' ELSE ''STOP_HAS_HISTORY'' END AS Result FROM `ordini_web_idempotenza`',
  'SELECT ''RollbackTableState'' AS CheckName, ''ALREADY_ABSENT'' AS Result'
);
PREPARE ks_rollback_preflight_statement FROM @ks_rollback_preflight_sql;
EXECUTE ks_rollback_preflight_statement;
DEALLOCATE PREPARE ks_rollback_preflight_statement;
