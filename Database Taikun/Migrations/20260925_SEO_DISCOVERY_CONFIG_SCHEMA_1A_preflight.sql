-- SEO-DISCOVERY-CONFIG-SCHEMA-1A REV2. SOLO SELECT. DRAFT NON INSTALLATO.
-- Eseguire soltanto in futuro, dopo review MySQL/ambiente e allowlist Product Owner.
-- Ogni Stato deve essere OK; un SELECT STOP non blocca automaticamente il DDL.

SELECT 'DATABASE_SELECTED' AS Controllo,
       IF(DATABASE() IS NOT NULL AND DATABASE() <> '', 'OK', 'STOP') AS Stato,
       DATABASE() AS DatabaseSelezionato;

SELECT 'MYSQL_8_0_42' AS Controllo,
       IF(VERSION() LIKE '8.0.42%' AND VERSION() NOT LIKE '%MariaDB%', 'OK', 'STOP') AS Stato,
       VERSION() AS Versione;

SELECT 'AZIENDE_PRESENT' AS Controllo,
       IF(COUNT(*) = 1 AND MAX(ENGINE) = 'InnoDB', 'OK', 'STOP') AS Stato
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende' AND TABLE_TYPE = 'BASE TABLE';

SELECT 'AZIENDE_PK_LEGACY' AS Controllo,
       IF(GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) = 'id,IvaTipo', 'OK', 'STOP') AS Stato
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende' AND INDEX_NAME = 'PRIMARY';

SELECT 'AZIENDE_ID_TYPE' AS Controllo,
       IF(COUNT(*) = 1 AND MAX(DATA_TYPE) = 'int' AND MAX(IS_NULLABLE) = 'NO', 'OK', 'STOP') AS Stato
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende' AND COLUMN_NAME = 'id';

SELECT 'AZIENDE_SEO_ABSENT' AS Controllo,
       IF(COUNT(*) = 0, 'OK', 'STOP') AS Stato
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo';

SELECT 'AZIENDE_ID_NO_COLLISIONS' AS Controllo,
       IF(COUNT(*) = 0, 'OK', 'STOP') AS Stato
FROM (SELECT id FROM aziende GROUP BY id HAVING COUNT(*) > 1) AS duplicate_ids;

SELECT 'AZIENDE_ROWS' AS Controllo, COUNT(*) AS NumeroAziende FROM aziende;

-- Nessuna FK su aziende(id): PK legacy composta (id,IvaTipo).
