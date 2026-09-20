-- MULTIPROVIDER-TENANT-EMAIL-TRANSPORT-1A - read-only preflight
-- Run only in an explicitly authorized KeepStore database.

SELECT '01_DatabaseSelected' AS CheckName,
       CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Result;

SELECT '02_AziendeDependency' AS CheckName,
       CASE WHEN
           EXISTS (SELECT 1 FROM information_schema.TABLES
                   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende' AND ENGINE='InnoDB')
           AND EXISTS (SELECT 1 FROM information_schema.COLUMNS
                       WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende'
                         AND COLUMN_NAME='id' AND DATA_TYPE='int' AND IS_NULLABLE='NO')
       THEN 'OK' ELSE 'STOP' END AS Result;

SET @ks_email_grantee := CONCAT(QUOTE(SUBSTRING_INDEX(CURRENT_USER(),'@',1)), '@', QUOTE(SUBSTRING_INDEX(CURRENT_USER(),'@',-1)));
SELECT '03_RequiredPrivileges' AS CheckName,
       CASE WHEN
           (EXISTS (SELECT 1 FROM information_schema.USER_PRIVILEGES
                    WHERE GRANTEE=@ks_email_grantee AND PRIVILEGE_TYPE IN ('ALL PRIVILEGES','CREATE'))
            OR EXISTS (SELECT 1 FROM information_schema.SCHEMA_PRIVILEGES
                       WHERE GRANTEE=@ks_email_grantee AND TABLE_SCHEMA=DATABASE()
                         AND PRIVILEGE_TYPE IN ('ALL PRIVILEGES','CREATE')))
           AND
           (EXISTS (SELECT 1 FROM information_schema.USER_PRIVILEGES
                    WHERE GRANTEE=@ks_email_grantee AND PRIVILEGE_TYPE IN ('ALL PRIVILEGES','DROP'))
            OR EXISTS (SELECT 1 FROM information_schema.SCHEMA_PRIVILEGES
                       WHERE GRANTEE=@ks_email_grantee AND TABLE_SCHEMA=DATABASE()
                         AND PRIVILEGE_TYPE IN ('ALL PRIVILEGES','DROP')))
       THEN 'OK' ELSE 'STOP' END AS Result;

SELECT '04_ProfileTableState' AS CheckName,
       CASE
           WHEN NOT EXISTS (SELECT 1 FROM information_schema.TABLES
                            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')
           THEN 'OK'
           WHEN (SELECT ENGINE FROM information_schema.TABLES
                 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')='InnoDB'
                AND (SELECT TABLE_COMMENT FROM information_schema.TABLES
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')=
                    'KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v1'
                AND (SELECT COUNT(*) FROM information_schema.COLUMNS
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')=19
                AND (SELECT COUNT(*) FROM information_schema.COLUMNS
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                       AND COLUMN_NAME IN ('AziendeId','ProviderKind','Host','Port','SecurityMode',
                                           'AuthenticationMode','Username','CredentialReference',
                                           'FromAddress','FromDisplayName','ReplyToAddress',
                                           'EnvelopeFromAddress','TimeoutSeconds','Enabled',
                                           'VerificationStatus','LastVerifiedAtUtc',
                                           'LastVerificationCode','CreatedAtUtc','UpdatedAtUtc'))=19
                AND EXISTS (SELECT 1 FROM information_schema.STATISTICS
                            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                              AND INDEX_NAME='PRIMARY' AND COLUMN_NAME='AziendeId'
                              AND SEQ_IN_INDEX=1 AND NON_UNIQUE=0)
                AND EXISTS (SELECT 1 FROM information_schema.KEY_COLUMN_USAGE
                            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                              AND COLUMN_NAME='AziendeId'
                              AND REFERENCED_TABLE_NAME='aziende' AND REFERENCED_COLUMN_NAME='id')
           THEN 'ALREADY_COMPLIANT'
           ELSE 'STOP'
       END AS Result;

SELECT '05_LegacySecretBoundary' AS CheckName,
       CASE WHEN
           EXISTS (SELECT 1 FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende' AND COLUMN_NAME='Password_smtp')
           AND NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                             AND COLUMN_NAME IN ('Password','Password_smtp','AccessToken','RefreshToken','SecretValue'))
       THEN 'OK' ELSE 'STOP' END AS Result;
