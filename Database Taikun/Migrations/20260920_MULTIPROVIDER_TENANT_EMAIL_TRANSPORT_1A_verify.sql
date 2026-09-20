-- MULTIPROVIDER-TENANT-EMAIL-CONFIG-CONTRACT-REV1 - read-only verification

SELECT '01_DatabaseSelected' AS CheckName,
       CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Result;

SELECT '02_TableExists' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport';

SELECT '03_EngineAndVersion' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND ENGINE='InnoDB'
  AND TABLE_COMMENT='KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v2';

SELECT '04_RequiredColumns' AS CheckName,
       CASE WHEN COUNT(*)=21 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND COLUMN_NAME IN ('EmailTransportId','AziendeId','Purpose','ProviderKind','Host','Port',
                      'SecurityMode','AuthenticationMode','Username','CredentialReference',
                      'FromAddress','FromDisplayName','ReplyToAddress','EnvelopeFromAddress',
                      'TimeoutSeconds','Enabled','VerificationStatus','LastVerifiedAtUtc',
                      'LastVerificationCode','CreatedAtUtc','UpdatedAtUtc');

SELECT '05_CriticalColumnDefinitions' AS CheckName,
       CASE WHEN COUNT(*)=21 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.COLUMNS
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
  );

SELECT '06_TechnicalPrimaryKey' AS CheckName,
       CASE WHEN COUNT(*)=1
                  AND (SELECT COUNT(*) FROM information_schema.STATISTICS
                       WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                         AND INDEX_NAME='PRIMARY')=1
            THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND INDEX_NAME='PRIMARY' AND COLUMN_NAME='EmailTransportId'
  AND SEQ_IN_INDEX=1 AND NON_UNIQUE=0;

SELECT '07_OwnerPurposeUnique' AS CheckName,
       CASE WHEN COUNT(*)=2
                  AND (SELECT COUNT(*) FROM information_schema.STATISTICS
                       WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                         AND INDEX_NAME='UX_aziende_email_transport_owner_purpose')=2
            THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND INDEX_NAME='UX_aziende_email_transport_owner_purpose' AND NON_UNIQUE=0
  AND ((SEQ_IN_INDEX=1 AND COLUMN_NAME='AziendeId')
       OR (SEQ_IN_INDEX=2 AND COLUMN_NAME='Purpose'));

SELECT '08_OwnerForeignKey' AS CheckName,
       CASE WHEN COUNT(*)=1
                  AND (SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
                       WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                         AND CONSTRAINT_NAME='FK_aziende_email_transport_azienda')=1
            THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND CONSTRAINT_NAME='FK_aziende_email_transport_azienda'
  AND COLUMN_NAME='AziendeId'
  AND REFERENCED_TABLE_NAME='aziende' AND REFERENCED_COLUMN_NAME='id';

SELECT '09_NoStoredSecrets' AS CheckName,
       CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND COLUMN_NAME IN ('Password','Password_smtp','AccessToken','RefreshToken','SecretValue');

SELECT '10_ProfileInvariants' AS CheckName,
       CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'STOP' END AS Result
FROM `aziende_email_transport`
WHERE `Purpose` NOT IN ('TRANSACTIONAL','MARKETING')
   OR `ProviderKind` NOT IN ('CUSTOM_SMTP','ARUBA','GOOGLE','MICROSOFT','LIBERO','VIRGILIO')
   OR `SecurityMode` NOT IN ('STARTTLS','IMPLICIT_TLS')
   OR `AuthenticationMode` NOT IN ('PASSWORD','APP_PASSWORD','OAUTH2')
   OR TRIM(`Host`)='' OR `Port`=0
   OR TRIM(`Username`)='' OR TRIM(`CredentialReference`)=''
   OR TRIM(`FromAddress`)='' OR TRIM(`FromDisplayName`)=''
   OR `TimeoutSeconds`<5 OR `TimeoutSeconds`>300
   OR `Enabled` NOT IN (0,1)
   OR `VerificationStatus` NOT IN ('NOT_VERIFIED','VERIFIED','FAILED','EXPIRED','REVOKED')
   OR (`Enabled`=1 AND (`VerificationStatus`<>'VERIFIED' OR `LastVerifiedAtUtc` IS NULL))
   OR (`VerificationStatus`='VERIFIED' AND (`LastVerifiedAtUtc` IS NULL OR `LastVerificationCode` IS NULL));

SELECT '11_ProfilesDefaultDisabled' AS CheckName,
       CASE WHEN COLUMN_DEFAULT='0' THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND COLUMN_NAME='Enabled';
