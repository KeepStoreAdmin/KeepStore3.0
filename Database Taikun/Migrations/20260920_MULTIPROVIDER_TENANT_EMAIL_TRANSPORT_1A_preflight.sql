-- MULTIPROVIDER-TENANT-EMAIL-CONFIG-CONTRACT-REV1 - read-only preflight
-- Run once per explicitly authorized KeepStore database. It performs no DDL/DML.

SELECT '01_DatabaseSelected' AS CheckName,
       CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Result;

SELECT '02_AziendeDependency' AS CheckName,
       CASE WHEN
           EXISTS (SELECT 1 FROM information_schema.TABLES
                   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende' AND ENGINE='InnoDB')
           AND EXISTS (SELECT 1 FROM information_schema.COLUMNS
                       WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende'
                         AND COLUMN_NAME='id' AND COLUMN_TYPE='int' AND IS_NULLABLE='NO')
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
                    'KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v2'
                AND (SELECT COUNT(*) FROM information_schema.COLUMNS
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')=21
                AND (SELECT COUNT(*) FROM information_schema.COLUMNS
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                       AND COLUMN_NAME IN ('EmailTransportId','AziendeId','Purpose','ProviderKind','Host','Port',
                                           'SecurityMode','AuthenticationMode','Username','CredentialReference',
                                           'FromAddress','FromDisplayName','ReplyToAddress','EnvelopeFromAddress',
                                           'TimeoutSeconds','Enabled','VerificationStatus','LastVerifiedAtUtc',
                                           'LastVerificationCode','CreatedAtUtc','UpdatedAtUtc'))=21
                AND (SELECT COUNT(*) FROM information_schema.COLUMNS
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                       AND (
                            (COLUMN_NAME='EmailTransportId' AND COLUMN_TYPE='bigint unsigned' AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
                         OR (COLUMN_NAME='AziendeId' AND COLUMN_TYPE='int' AND IS_NULLABLE='NO')
                         OR (COLUMN_NAME='Purpose' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
                         OR (COLUMN_NAME='ProviderKind' AND COLUMN_TYPE='varchar(32)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
                         OR (COLUMN_NAME='Host' AND COLUMN_TYPE='varchar(253)' AND IS_NULLABLE='NO' AND CHARACTER_SET_NAME='ascii')
                         OR (COLUMN_NAME='Port' AND COLUMN_TYPE='smallint unsigned' AND IS_NULLABLE='NO')
                         OR (COLUMN_NAME='SecurityMode' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
                         OR (COLUMN_NAME='AuthenticationMode' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
                         OR (COLUMN_NAME='Username' AND COLUMN_TYPE='varchar(254)' AND IS_NULLABLE='NO' AND COLLATION_NAME='utf8mb4_bin')
                         OR (COLUMN_NAME='CredentialReference' AND COLUMN_TYPE='varchar(512)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
                         OR (COLUMN_NAME='FromAddress' AND COLUMN_TYPE='varchar(254)' AND IS_NULLABLE='NO' AND COLLATION_NAME='utf8mb4_bin')
                         OR (COLUMN_NAME='FromDisplayName' AND COLUMN_TYPE='varchar(255)' AND IS_NULLABLE='NO' AND COLLATION_NAME='utf8mb4_unicode_ci')
                         OR (COLUMN_NAME='ReplyToAddress' AND COLUMN_TYPE='varchar(254)' AND IS_NULLABLE='YES' AND COLLATION_NAME='utf8mb4_bin')
                         OR (COLUMN_NAME='EnvelopeFromAddress' AND COLUMN_TYPE='varchar(254)' AND IS_NULLABLE='YES' AND COLLATION_NAME='utf8mb4_bin')
                         OR (COLUMN_NAME='TimeoutSeconds' AND COLUMN_TYPE='smallint unsigned' AND IS_NULLABLE='NO' AND COLUMN_DEFAULT='30')
                         OR (COLUMN_NAME='Enabled' AND COLUMN_TYPE='tinyint(1)' AND IS_NULLABLE='NO' AND COLUMN_DEFAULT='0')
                         OR (COLUMN_NAME='VerificationStatus' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLUMN_DEFAULT='NOT_VERIFIED' AND COLLATION_NAME='ascii_bin')
                         OR (COLUMN_NAME='LastVerifiedAtUtc' AND COLUMN_TYPE='datetime(6)' AND IS_NULLABLE='YES')
                         OR (COLUMN_NAME='LastVerificationCode' AND COLUMN_TYPE='varchar(64)' AND IS_NULLABLE='YES' AND COLLATION_NAME='ascii_bin')
                         OR (COLUMN_NAME='CreatedAtUtc' AND COLUMN_TYPE='datetime(6)' AND IS_NULLABLE='NO')
                         OR (COLUMN_NAME='UpdatedAtUtc' AND COLUMN_TYPE='datetime(6)' AND IS_NULLABLE='NO' AND EXTRA LIKE '%on update CURRENT_TIMESTAMP(6)%')
                       ))=21
                AND (SELECT COUNT(*) FROM information_schema.STATISTICS
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                       AND INDEX_NAME='PRIMARY')=1
                AND EXISTS (SELECT 1 FROM information_schema.STATISTICS
                            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                              AND INDEX_NAME='PRIMARY' AND COLUMN_NAME='EmailTransportId'
                              AND SEQ_IN_INDEX=1 AND NON_UNIQUE=0)
                AND (SELECT COUNT(*) FROM information_schema.STATISTICS
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                       AND INDEX_NAME='UX_aziende_email_transport_owner_purpose')=2
                AND (SELECT COUNT(*) FROM information_schema.STATISTICS
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                       AND INDEX_NAME='UX_aziende_email_transport_owner_purpose'
                       AND NON_UNIQUE=0
                       AND ((SEQ_IN_INDEX=1 AND COLUMN_NAME='AziendeId')
                            OR (SEQ_IN_INDEX=2 AND COLUMN_NAME='Purpose')))=2
                AND EXISTS (SELECT 1 FROM information_schema.KEY_COLUMN_USAGE
                            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                              AND CONSTRAINT_NAME='FK_aziende_email_transport_azienda'
                              AND COLUMN_NAME='AziendeId'
                              AND REFERENCED_TABLE_NAME='aziende' AND REFERENCED_COLUMN_NAME='id')
                AND (SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                       AND CONSTRAINT_NAME='FK_aziende_email_transport_azienda')=1
           THEN 'ALREADY_COMPLIANT'
           ELSE 'STOP'
       END AS Result;

SELECT '05_LegacyBoundary' AS CheckName,
       CASE WHEN
           EXISTS (SELECT 1 FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende' AND COLUMN_NAME='Password_smtp')
           AND NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                             AND COLUMN_NAME IN ('Password','Password_smtp','AccessToken','RefreshToken','SecretValue'))
       THEN 'OK' ELSE 'STOP' END AS Result;
