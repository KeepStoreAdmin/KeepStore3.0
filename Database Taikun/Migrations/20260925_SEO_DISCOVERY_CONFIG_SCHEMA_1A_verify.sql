-- SEO-DISCOVERY-CONFIG-SCHEMA-1A REV2. SOLO SELECT; DRAFT NON INSTALLATO.
-- Ogni Stato deve essere OK. Verifica soltanto aziende_seo, non i moduli separati.

SELECT 'TABLE_PRESENT_INNODB_UTF8MB4' AS Controllo,
       IF(COUNT(*) = 1 AND MAX(ENGINE) = 'InnoDB' AND MAX(ROW_FORMAT) = 'Dynamic'
          AND MAX(TABLE_COLLATION) = 'utf8mb4_0900_ai_ci', 'OK', 'STOP') AS Stato
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo' AND TABLE_TYPE = 'BASE TABLE';

SELECT 'COLUMN_MANIFEST_30' AS Controllo,
       IF(COUNT(*) = 30
          AND SUM(CRC32(CONCAT(LPAD(ORDINAL_POSITION, 3, '0'), ':', COLUMN_NAME))) = 62524129960,
          'OK', 'STOP') AS Stato
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo';

SELECT 'ZERO_NULLABLE' AS Controllo,
       IF(COUNT(*) = 0, 'OK', 'STOP') AS Stato
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo' AND IS_NULLABLE <> 'NO';

SELECT 'ALL_NON_AUTO_DEFAULTS_PRESENT' AS Controllo,
       IF(COUNT(*) = 0, 'OK', 'STOP') AS Stato
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo'
  AND COLUMN_NAME NOT IN ('Id', 'AziendeId') AND COLUMN_DEFAULT IS NULL;

SELECT 'TYPE_GROUPS' AS Controllo,
       IF(SUM(DATA_TYPE = 'bigint') = 1 AND SUM(DATA_TYPE = 'int') = 2 AND SUM(DATA_TYPE = 'smallint') = 2 AND SUM(DATA_TYPE = 'varchar') = 6 AND SUM(DATA_TYPE = 'char') = 1 AND SUM(DATA_TYPE = 'text') = 13 AND SUM(DATA_TYPE = 'tinyint') = 1 AND SUM(DATA_TYPE = 'datetime') = 4,
          'OK', 'STOP') AS Stato
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo';

SELECT 'KEYS_PK_AND_UNIQUE_AZIENDE' AS Controllo,
       IF(SUM(INDEX_NAME = 'PRIMARY' AND COLUMN_NAME = 'Id' AND NON_UNIQUE = 0) = 1
          AND SUM(INDEX_NAME = 'uq_aziende_seo_aziende' AND COLUMN_NAME = 'AziendeId' AND NON_UNIQUE = 0) = 1
          AND COUNT(*) = 2, 'OK', 'STOP') AS Stato
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo';

SELECT 'ROW_COUNT_MATCHES_AZIENDE' AS Controllo,
       IF((SELECT COUNT(*) FROM aziende_seo) = (SELECT COUNT(*) FROM aziende), 'OK', 'STOP') AS Stato;

SELECT 'NO_DUPLICATE_OR_ORPHAN_AZIENDE' AS Controllo,
       IF((SELECT COUNT(*) FROM (SELECT AziendeId FROM aziende_seo GROUP BY AziendeId HAVING COUNT(*) > 1) AS d) = 0
          AND (SELECT COUNT(*) FROM aziende_seo s LEFT JOIN aziende a ON a.id = s.AziendeId WHERE a.id IS NULL) = 0,
          'OK', 'STOP') AS Stato;

SELECT 'SEO_DEFAULTS_AND_NO_SECRETS' AS Controllo,
       IF((SELECT COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo' AND COLUMN_NAME = 'ConfigVersion') = '1'
          AND (SELECT COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo' AND COLUMN_NAME = 'SecretsCryptoVersion') = '0'
          AND (SELECT COUNT(*) FROM aziende_seo
               WHERE IndexNowEnabled <> 0 OR IndexNowKey <> '' OR SecretsCryptoVersion <> 0
                  OR SecretsKeyId <> '' OR BingWebmasterApiKeyEnc <> ''
                  OR BingOAuthClientSecretEnc <> '' OR BingOAuthAccessTokenEnc <> ''
                  OR BingOAuthRefreshTokenEnc <> '') = 0, 'OK', 'STOP') AS Stato;

SELECT 'NO_PROVIDER_CROSS_MODULE_COLUMNS' AS Controllo,
       IF(COUNT(*) = 0, 'OK', 'STOP') AS Stato
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo'
  AND (COLUMN_NAME LIKE 'Google%' OR COLUMN_NAME LIKE 'Meta%'
       OR COLUMN_NAME LIKE 'TikTok%' OR COLUMN_NAME LIKE 'Amazon%'
       OR COLUMN_NAME LIKE 'Ebay%' OR COLUMN_NAME LIKE 'Facebook%'
       OR COLUMN_NAME LIKE 'Paypal%');

-- Checksum nome+posizione calcolato staticamente dal forward REV2.
