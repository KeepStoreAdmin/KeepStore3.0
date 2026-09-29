-- STOREFRONT-PERSISTENT-ANONYMOUS-CART-REGISTRY-MIGRATION-1A
-- READ ONLY. Run every statement; execute forward only when every Esito is OK.
-- Select each destination database explicitly outside this script. Structural STOP
-- means do not run the data section below; a missing table is never permission to install.

SELECT 'DATABASE_SELECTED' AS Controllo,
       CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Esito;

SELECT 'MYSQL_VERSION_CHECK_ENFORCED' AS Controllo, VERSION() AS Versione,
       CASE WHEN VERSION() NOT LIKE '%MariaDB%'
                 AND CAST(SUBSTRING_INDEX(VERSION(), '.', 1) AS UNSIGNED) = 8
                 AND (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(VERSION(), '.', 2), '.', -1) AS UNSIGNED) > 0
                      OR CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(VERSION(), '.', 3), '.', -1) AS UNSIGNED) >= 16)
            THEN 'OK' ELSE 'STOP' END AS Esito;

SELECT 'EXACT_COLLATION_AVAILABLE' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.COLLATIONS
WHERE COLLATION_NAME = 'utf8mb4_0900_bin'
  AND CHARACTER_SET_NAME = 'utf8mb4' AND PAD_ATTRIBUTE = 'NO PAD';

SELECT 'CARRELLO_INNODB' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello'
  AND TABLE_TYPE = 'BASE TABLE' AND ENGINE = 'InnoDB';

SELECT 'SESSIONID_ORIGINAL_COLUMN' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello'
  AND COLUMN_NAME = 'SessionId' AND COLUMN_TYPE = 'varchar(50)'
  AND CHARACTER_SET_NAME = 'utf8mb4' AND COLLATION_NAME = 'utf8mb4_0900_ai_ci'
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

SELECT 'REGISTRY_ABSENT' AS Controllo,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello_anonimo_persistenza';

SELECT 'VCARRELLO_PRESENT' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vcarrello' AND TABLE_TYPE = 'VIEW';

SELECT 'AZIENDE_INNODB' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende'
  AND TABLE_TYPE = 'BASE TABLE' AND ENGINE = 'InnoDB';

SELECT 'AZIENDE_COMPOSITE_PK' AS Controllo,
       CASE WHEN GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',') = 'id,IvaTipo'
                 AND COUNT(*) = 2 AND SUM(NON_UNIQUE = 0) = 2
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende' AND INDEX_NAME = 'PRIMARY';

-- Data section: run only after every structural result above is OK.
-- Counts only; no SessionId, account, product, or customer value is returned.
SELECT 'SESSIONID_DATA_SAFETY' AS Controllo,
       COUNT(*) AS CarrelloRighePreflight,
       COALESCE(SUM(SessionId IS NOT NULL AND CHAR_LENGTH(SessionId) > 50), 0) AS Oltre50,
       COALESCE(SUM(SessionId IS NOT NULL AND LENGTH(SessionId) <> CHAR_LENGTH(SessionId)), 0) AS NonAscii,
       COALESCE(SUM(SessionId IS NOT NULL AND LENGTH(SessionId) > 0
                    AND RIGHT(BINARY SessionId, 1) = 0x20), 0) AS SpazioFinale,
       CASE WHEN COALESCE(SUM(SessionId IS NOT NULL AND CHAR_LENGTH(SessionId) > 50), 0) = 0
                 AND COALESCE(SUM(SessionId IS NOT NULL
                                  AND LENGTH(SessionId) <> CHAR_LENGTH(SessionId)), 0) = 0
                 AND COALESCE(SUM(SessionId IS NOT NULL AND LENGTH(SessionId) > 0
                                  AND RIGHT(BINARY SessionId, 1) = 0x20), 0) = 0
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM carrello;

SELECT 'SESSIONID_FORMATS' AS Controllo,
       COALESCE(SUM(SessionId IS NOT NULL AND SessionId <> ''
                    AND BINARY LEFT(SessionId, 5) = BINARY 'ksc1_'), 0) AS Ksc1Righe,
       COALESCE(SUM(SessionId IS NOT NULL AND SessionId <> ''
                    AND BINARY LEFT(SessionId, 5) = BINARY 'ksc2_'), 0) AS Ksc2Righe,
       COALESCE(SUM(SessionId IS NOT NULL AND SessionId <> ''
                    AND BINARY LEFT(SessionId, 5) <> BINARY 'ksc1_'
                    AND BINARY LEFT(SessionId, 5) <> BINARY 'ksc2_'), 0) AS AltriFormatiRighe,
       CASE WHEN COALESCE(SUM(SessionId IS NOT NULL AND SessionId <> ''
                                  AND BINARY LEFT(SessionId, 5) = BINARY 'ksc2_'), 0) = 0
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM carrello;

SELECT 'SESSIONID_CASE_COLLISIONS' AS Controllo, COUNT(*) AS GruppiCollisione,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM (
  SELECT 1
  FROM carrello
  WHERE SessionId IS NOT NULL AND SessionId <> ''
  GROUP BY SessionId COLLATE utf8mb4_0900_as_ci
  HAVING COUNT(DISTINCT BINARY SessionId) > 1
) AS collisioni;
