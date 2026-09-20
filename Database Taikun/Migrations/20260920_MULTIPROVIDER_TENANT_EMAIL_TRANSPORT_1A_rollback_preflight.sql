-- MULTIPROVIDER-TENANT-EMAIL-TRANSPORT-1A - read-only rollback preflight

SET @ks_email_rollback_preflight_sql := IF(
  EXISTS (SELECT 1 FROM information_schema.TABLES
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'),
  'SELECT ''RollbackProfileState'' AS CheckName, CASE WHEN COUNT(*)=0 THEN ''OK'' ELSE ''STOP_HAS_PROFILES'' END AS Result FROM `aziende_email_transport`',
  'SELECT ''RollbackProfileState'' AS CheckName, ''ALREADY_ABSENT'' AS Result'
);
PREPARE ks_email_rollback_preflight_statement FROM @ks_email_rollback_preflight_sql;
EXECUTE ks_email_rollback_preflight_statement;
DEALLOCATE PREPARE ks_email_rollback_preflight_statement;
