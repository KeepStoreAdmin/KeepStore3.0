-- ORDER-DURABLE-IDEMPOTENCY-1A - read-only verification

SELECT '01_DatabaseSelected' AS CheckName,
       CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Result;

SELECT '02_TableExists' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza';

SELECT '03_EngineInnoDB' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza' AND ENGINE='InnoDB';

SELECT '04_RequestIdDefinition' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza'
  AND COLUMN_NAME='RequestId' AND DATA_TYPE='varchar' AND CHARACTER_MAXIMUM_LENGTH=32
  AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin';

SELECT '05_RequestIdPrimaryKey' AS CheckName,
       CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza'
  AND INDEX_NAME='PRIMARY' AND COLUMN_NAME='RequestId' AND SEQ_IN_INDEX=1 AND NON_UNIQUE=0;

SELECT '06_RequiredColumns' AS CheckName,
       CASE WHEN COUNT(*)=9 THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza'
  AND COLUMN_NAME IN ('RequestId','LoginId','TipoDocumentiId','PayloadFingerprint','DocumentoMemorizzato','DocumentiId','Stato','DataCreazione','DataCompletamento');

SELECT '07_OwnerIndex' AS CheckName,
       CASE WHEN GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX)='LoginId,DataCreazione' THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza'
  AND INDEX_NAME='IX_ordini_web_idempotenza_owner';

SELECT '08_StateIndex' AS CheckName,
       CASE WHEN GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX)='Stato,DataCreazione' THEN 'OK' ELSE 'STOP' END AS Result
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza'
  AND INDEX_NAME='IX_ordini_web_idempotenza_stato';

SELECT '09_RowInvariants' AS CheckName,
       CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'STOP' END AS Result
FROM `ordini_web_idempotenza`
WHERE `Stato` NOT IN ('PENDING','COMPLETED','RETRY_REQUIRED')
   OR (`Stato`='PENDING' AND (`DocumentoMemorizzato` IS NOT NULL OR `DocumentiId` IS NOT NULL OR `DataCompletamento` IS NOT NULL))
   OR (`Stato`='RETRY_REQUIRED' AND (`DocumentoMemorizzato` IS NOT NULL OR `DocumentiId` IS NOT NULL OR `DataCompletamento` IS NULL))
   OR (`Stato`='COMPLETED' AND (`DocumentoMemorizzato` IS NULL OR `DocumentiId` IS NULL OR `DataCompletamento` IS NULL));
