-- MULTIPROVIDER-TENANT-EMAIL-CONFIG-CONTRACT-REV1 - read-only rollback preflight

SET @ks_email_rollback_preflight_sql := CASE
  WHEN NOT EXISTS (SELECT 1 FROM information_schema.TABLES
                   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')
  THEN 'SELECT ''RollbackProfileState'' AS CheckName, ''ALREADY_ABSENT'' AS Result'
  WHEN NOT EXISTS (SELECT 1 FROM information_schema.TABLES
                   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                     AND ENGINE='InnoDB'
                     AND TABLE_COMMENT='KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v2')
  THEN 'SELECT ''RollbackProfileState'' AS CheckName, ''STOP_SCHEMA_MISMATCH'' AS Result'
  ELSE 'SELECT ''RollbackProfileState'' AS CheckName, CASE WHEN COUNT(*)=0 THEN ''OK'' ELSE ''STOP_HAS_PROFILES'' END AS Result FROM `aziende_email_transport`'
END;
PREPARE ks_email_rollback_preflight_statement FROM @ks_email_rollback_preflight_sql;
EXECUTE ks_email_rollback_preflight_statement;
DEALLOCATE PREPARE ks_email_rollback_preflight_statement;
