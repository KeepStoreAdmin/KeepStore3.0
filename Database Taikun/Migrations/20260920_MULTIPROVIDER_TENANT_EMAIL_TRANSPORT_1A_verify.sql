-- MULTIPROVIDER-TENANT-EMAIL-TRANSPORT-1A - read-only verification

SELECT '01_DatabaseSelected' AS CheckName,
       CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Result;

SELECT '02_TableExists' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport';

SELECT '03_EngineInnoDB' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport' AND ENGINE='InnoDB';

SELECT '04_SchemaVersion' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND TABLE_COMMENT='KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v1';

SELECT '05_RequiredColumns' AS CheckName,
       CASE WHEN COUNT(*)=19 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND COLUMN_NAME IN ('AziendeId','ProviderKind','Host','Port','SecurityMode',
                      'AuthenticationMode','Username','CredentialReference',
                      'FromAddress','FromDisplayName','ReplyToAddress',
                      'EnvelopeFromAddress','TimeoutSeconds','Enabled',
                      'VerificationStatus','LastVerifiedAtUtc',
                      'LastVerificationCode','CreatedAtUtc','UpdatedAtUtc');

SELECT '06_CriticalColumnDefinitions' AS CheckName,
       CASE WHEN COUNT(*)=10 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND (
       (COLUMN_NAME='AziendeId' AND COLUMN_TYPE='int' AND IS_NULLABLE='NO')
    OR (COLUMN_NAME='ProviderKind' AND COLUMN_TYPE='varchar(32)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
    OR (COLUMN_NAME='Host' AND COLUMN_TYPE='varchar(255)' AND IS_NULLABLE='NO')
    OR (COLUMN_NAME='Port' AND COLUMN_TYPE='smallint unsigned' AND IS_NULLABLE='NO')
    OR (COLUMN_NAME='SecurityMode' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
    OR (COLUMN_NAME='AuthenticationMode' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
    OR (COLUMN_NAME='CredentialReference' AND COLUMN_TYPE='varchar(255)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
    OR (COLUMN_NAME='TimeoutSeconds' AND COLUMN_TYPE='smallint unsigned' AND IS_NULLABLE='NO' AND COLUMN_DEFAULT='30')
    OR (COLUMN_NAME='Enabled' AND COLUMN_TYPE='tinyint(1)' AND IS_NULLABLE='NO' AND COLUMN_DEFAULT='0')
    OR (COLUMN_NAME='VerificationStatus' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLUMN_DEFAULT='NOT_VERIFIED')
  );

SELECT '07_OwnerPrimaryKey' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
  AND INDEX_NAME='PRIMARY' AND COLUMN_NAME='AziendeId'
  AND SEQ_IN_INDEX=1 AND NON_UNIQUE=0;

SELECT '08_OwnerForeignKey' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
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
WHERE `ProviderKind` NOT IN ('CustomSmtp','Aruba','Google','Microsoft','Libero','Virgilio')
   OR `SecurityMode` NOT IN ('StartTls','ImplicitTls')
   OR `AuthenticationMode` NOT IN ('Password','AppPassword','OAuth2')
   OR `Host`='' OR `Port`=0
   OR `Username`='' OR `CredentialReference`=''
   OR `FromAddress`=''
   OR `FromDisplayName`=''
   OR `TimeoutSeconds`<5 OR `TimeoutSeconds`>300
   OR (`Enabled`=1 AND `VerificationStatus`<>'VERIFIED');

SELECT '11_ProfilesInitiallyDisabled' AS CheckName,
       CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'STOP' END AS Result
FROM `aziende_email_transport`
WHERE `Enabled`<>0;
