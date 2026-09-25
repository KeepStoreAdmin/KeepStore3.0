-- SEO-DISCOVERY-CONFIG-SCHEMA-1A. Solo SELECT; eseguire prima del forward.
-- Ogni Stato deve essere OK. Il database e quello selezionato in SQLyog.

SELECT 'DATABASE_SELECTED' AS Controllo,
       IF(DATABASE() IS NOT NULL AND DATABASE() <> '', 'OK', 'STOP') AS Stato,
       DATABASE() AS DatabaseSelezionato;

SELECT 'MYSQL_8_0_42' AS Controllo,
       IF(VERSION() LIKE '8.0.42%' AND VERSION() NOT LIKE '%MariaDB%', 'OK', 'STOP') AS Stato,
       VERSION() AS Versione;

SELECT 'AZIENDE_PRESENT' AS Controllo,
       IF(COUNT(*) = 1 AND MAX(ENGINE) = 'InnoDB', 'OK', 'STOP') AS Stato,
       MAX(TABLE_COLLATION) AS CollationLegacy
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

SELECT 'FOUR_LEGACY_COLUMNS' AS Controllo,
       IF(COUNT(*) = 4, 'OK', 'STOP') AS Stato
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende'
  AND COLUMN_NAME IN ('google_merchant_id', 'facebook_pixel_id', 'statistiche_visite', 'facebookLink');

SELECT 'AZIENDE_SEO_ABSENT' AS Controllo,
       IF(COUNT(*) = 0, 'OK', 'STOP') AS Stato
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo';

SELECT 'AZIENDE_ID_NO_COLLISIONS' AS Controllo,
       IF(COUNT(*) = 0, 'OK', 'STOP') AS Stato
FROM (SELECT id FROM aziende GROUP BY id HAVING COUNT(*) > 1) AS duplicate_ids;

SELECT 'AZIENDE_ROWS' AS Controllo, COUNT(*) AS NumeroAziende FROM aziende;

-- Il dump Git di riferimento ha PK composta (id,IvaTipo), ENGINE InnoDB,
-- default charset latin1 e singole colonne legacy in utf8mb4_0900_ai_ci.
-- Per questo la nuova tabella usa UNIQUE(AziendeId) ma nessuna FK in questa migration.
