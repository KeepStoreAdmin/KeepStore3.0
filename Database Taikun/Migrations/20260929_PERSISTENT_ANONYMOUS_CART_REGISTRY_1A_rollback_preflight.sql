-- STOREFRONT-PERSISTENT-ANONYMOUS-CART-REGISTRY-MIGRATION-1A / READ ONLY.
-- Every Esito must be OK. Run data section only after structural OK.
-- Zero rows do not prove that no process can start writing ksc2: verify the
-- runtime is still the pre-ksc2 release before any separately authorized rollback.

SELECT 'DATABASE_SELECTED' AS Controllo,
       CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Esito;

SELECT 'REGISTRY_EXISTS' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello_anonimo_persistenza'
  AND TABLE_TYPE = 'BASE TABLE';

SELECT 'SESSIONID_MIGRATED' AS Controllo,
       CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello'
  AND COLUMN_NAME = 'SessionId' AND COLUMN_TYPE = 'varchar(50)'
  AND COLLATION_NAME = 'utf8mb4_0900_bin' AND IS_NULLABLE = 'YES';

-- Data section: no owner value or token is returned.
SELECT 'REGISTRY_EMPTY' AS Controllo, COUNT(*) AS Righe,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM carrello_anonimo_persistenza;

SELECT 'NO_KSC2_ROWS' AS Controllo,
       COALESCE(SUM(SessionId IS NOT NULL AND SessionId <> ''
                    AND BINARY LEFT(SessionId, 5) = BINARY 'ksc2_'), 0) AS Ksc2Righe,
       CASE WHEN COALESCE(SUM(SessionId IS NOT NULL AND SessionId <> ''
                                  AND BINARY LEFT(SessionId, 5) = BINARY 'ksc2_'), 0) = 0
            THEN 'OK' ELSE 'STOP' END AS Esito
FROM carrello;
