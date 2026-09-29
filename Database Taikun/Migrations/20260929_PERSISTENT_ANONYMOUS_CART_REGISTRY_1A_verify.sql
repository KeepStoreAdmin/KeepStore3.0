-- STOREFRONT-PERSISTENT-ANONYMOUS-CART-REGISTRY-MIGRATION-1A / READ ONLY.
-- All Esito values must be OK. Compare CarrelloRigheVerify with the preflight
-- count captured for this same database; no current row count is hardcoded.
-- Stop after a structural STOP: direct SELECTs below require both objects.

SELECT 'DATABASE_SELECTED' AS Controllo,
       CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Esito;

SELECT 'SESSIONID_EXACT_COLUMN' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello'
  AND COLUMN_NAME = 'SessionId' AND COLUMN_TYPE = 'varchar(50)'
  AND CHARACTER_SET_NAME = 'utf8mb4' AND COLLATION_NAME = 'utf8mb4_0900_bin'
  AND IS_NULLABLE = 'YES' AND COLUMN_DEFAULT IS NULL;

SELECT 'SESSIONID_OWNER_INDEX' AS Controllo,
       CASE WHEN GROUP_CONCAT(CONCAT(SEQ_IN_INDEX, ':', COLUMN_NAME, ':', NON_UNIQUE,
                                   ':', COALESCE(SUB_PART, 0), ':', INDEX_TYPE)
                              ORDER BY SEQ_IN_INDEX SEPARATOR '|') =
                     '1:SessionId:1:0:BTREE|2:id:1:0:BTREE'
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello'
  AND INDEX_NAME = 'IX_carrello_SessionId_ID';

SELECT 'REGISTRY_INNODB' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello_anonimo_persistenza'
  AND TABLE_TYPE = 'BASE TABLE' AND ENGINE = 'InnoDB';

SELECT 'REGISTRY_COLUMNS_EXACT' AS Controllo,
       CASE WHEN COUNT(*) = 9 AND SUM(
         (COLUMN_NAME = 'Id' AND COLUMN_TYPE = 'bigint unsigned'
           AND IS_NULLABLE = 'NO' AND EXTRA = 'auto_increment')
         OR (COLUMN_NAME = 'AziendeId' AND COLUMN_TYPE = 'int' AND IS_NULLABLE = 'NO')
         OR (COLUMN_NAME = 'OwnerToken' AND COLUMN_TYPE = 'varchar(50)'
           AND IS_NULLABLE = 'NO' AND COLLATION_NAME = 'utf8mb4_0900_bin')
         OR (COLUMN_NAME = 'Status' AND COLUMN_TYPE = 'varchar(8)'
           AND IS_NULLABLE = 'NO' AND COLLATION_NAME = 'utf8mb4_0900_bin')
         OR (COLUMN_NAME IN ('CreatedUtc', 'LastActivityUtc', 'ExpiresUtc')
           AND COLUMN_TYPE = 'datetime(6)' AND IS_NULLABLE = 'NO')
         OR (COLUMN_NAME IN ('ConsumedUtc', 'RevokedUtc')
           AND COLUMN_TYPE = 'datetime(6)' AND IS_NULLABLE = 'YES')
       ) = 9 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello_anonimo_persistenza';

SELECT 'REGISTRY_PRIMARY_KEY' AS Controllo,
       CASE WHEN GROUP_CONCAT(CONCAT(SEQ_IN_INDEX, ':', COLUMN_NAME, ':', NON_UNIQUE)
                              ORDER BY SEQ_IN_INDEX SEPARATOR '|') = '1:Id:0'
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello_anonimo_persistenza'
  AND INDEX_NAME = 'PRIMARY';

SELECT 'REGISTRY_TENANT_OWNER_UNIQUE' AS Controllo,
       CASE WHEN GROUP_CONCAT(CONCAT(SEQ_IN_INDEX, ':', COLUMN_NAME, ':', NON_UNIQUE)
                              ORDER BY SEQ_IN_INDEX SEPARATOR '|') =
                     '1:AziendeId:0|2:OwnerToken:0'
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello_anonimo_persistenza'
  AND INDEX_NAME = 'UX_carrello_anonimo_persistenza_tenant_owner';

SELECT 'REGISTRY_CLEANUP_INDEXES' AS Controllo,
       CASE WHEN COUNT(*) = 9 AND COUNT(DISTINCT INDEX_NAME) = 3
                 AND SUM(INDEX_NAME = 'IX_carrello_anonimo_persistenza_cleanup'
                         AND ((SEQ_IN_INDEX = 1 AND COLUMN_NAME = 'Status')
                           OR (SEQ_IN_INDEX = 2 AND COLUMN_NAME = 'ExpiresUtc')
                           OR (SEQ_IN_INDEX = 3 AND COLUMN_NAME = 'Id'))) = 3
                 AND SUM(INDEX_NAME = 'IX_carrello_anonimo_persistenza_consumed'
                         AND ((SEQ_IN_INDEX = 1 AND COLUMN_NAME = 'Status')
                           OR (SEQ_IN_INDEX = 2 AND COLUMN_NAME = 'ConsumedUtc')
                           OR (SEQ_IN_INDEX = 3 AND COLUMN_NAME = 'Id'))) = 3
                 AND SUM(INDEX_NAME = 'IX_carrello_anonimo_persistenza_revoked'
                         AND ((SEQ_IN_INDEX = 1 AND COLUMN_NAME = 'Status')
                           OR (SEQ_IN_INDEX = 2 AND COLUMN_NAME = 'RevokedUtc')
                           OR (SEQ_IN_INDEX = 3 AND COLUMN_NAME = 'Id'))) = 3
                 AND SUM(NON_UNIQUE = 1 AND SUB_PART IS NULL AND INDEX_TYPE = 'BTREE') = 9
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello_anonimo_persistenza'
  AND INDEX_NAME IN ('IX_carrello_anonimo_persistenza_cleanup',
                     'IX_carrello_anonimo_persistenza_consumed',
                     'IX_carrello_anonimo_persistenza_revoked');

SELECT 'REGISTRY_CHECKS_ENFORCED' AS Controllo,
       CASE WHEN COUNT(*) = 5 AND SUM(ENFORCED = 'YES') = 5
                 AND SUM(CONSTRAINT_NAME IN (
                   'CK_carrello_anonimo_persistenza_tenant',
                   'CK_carrello_anonimo_persistenza_owner',
                   'CK_carrello_anonimo_persistenza_status',
                   'CK_carrello_anonimo_persistenza_expiry',
                   'CK_carrello_anonimo_persistenza_terminal')) = 5
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
  AND TABLE_NAME = 'carrello_anonimo_persistenza'
  AND CONSTRAINT_TYPE = 'CHECK';

SELECT 'VCARRELLO_PRESENT' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vcarrello' AND TABLE_TYPE = 'VIEW';

SELECT 'SESSIONID_COMPARISON' AS Controllo,
       CASE WHEN _utf8mb4'a' COLLATE utf8mb4_0900_bin <>
                 _utf8mb4'A' COLLATE utf8mb4_0900_bin
                 AND _utf8mb4'a' COLLATE utf8mb4_0900_bin <>
                     _utf8mb4'a ' COLLATE utf8mb4_0900_bin
            THEN 'OK' ELSE 'STOP' END AS Esito;

-- Data section: run only after every structural result above is OK.
SELECT 'CARRELLO_ROW_COUNT' AS Controllo, COUNT(*) AS CarrelloRigheVerify,
       'CONFRONTARE_CON_PREFLIGHT' AS VerificaOperatore
FROM carrello;

SELECT 'SESSIONID_FORMATS_POST_DDL' AS Controllo,
       COALESCE(SUM(SessionId IS NOT NULL AND SessionId <> ''
                    AND BINARY LEFT(SessionId, 5) = BINARY 'ksc1_'), 0) AS Ksc1Righe,
       COALESCE(SUM(SessionId IS NOT NULL AND SessionId <> ''
                    AND BINARY LEFT(SessionId, 5) = BINARY 'ksc2_'), 0) AS Ksc2Righe,
       CASE WHEN COALESCE(SUM(SessionId IS NOT NULL AND SessionId <> ''
                                  AND BINARY LEFT(SessionId, 5) = BINARY 'ksc2_'), 0) = 0
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM carrello;

SELECT 'REGISTRY_EMPTY_BEFORE_RUNTIME' AS Controllo, COUNT(*) AS Righe,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM carrello_anonimo_persistenza;

-- A view with no rows is also valid; this SELECT confirms that its definition resolves.
SELECT 'VCARRELLO_SELECTABLE' AS Controllo,
       CASE WHEN COUNT(*) <= 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM (SELECT 1 FROM vcarrello LIMIT 1) AS verifica_vista;
