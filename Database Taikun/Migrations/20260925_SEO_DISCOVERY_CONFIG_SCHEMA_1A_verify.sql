-- SEO-DISCOVERY-CONFIG-SCHEMA-1A. Solo SELECT; eseguire subito dopo il forward
-- e prima della copia manuale dei quattro valori legacy. Ogni Stato deve essere OK.

SELECT 'TABLE_PRESENT_INNODB_UTF8MB4' AS Controllo,
       IF(COUNT(*) = 1 AND MAX(ENGINE) = 'InnoDB' AND MAX(TABLE_COLLATION) = 'utf8mb4_0900_ai_ci', 'OK', 'STOP') AS Stato
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo' AND TABLE_TYPE = 'BASE TABLE';

SELECT 'COLUMN_MANIFEST_193' AS Controllo,
       IF(COUNT(*) = 193
          AND SUM(CRC32(CONCAT(LPAD(ORDINAL_POSITION, 3, '0'), ':', COLUMN_NAME))) = 420414212908,
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

SELECT 'CORE_COLUMN_TYPES' AS Controllo,
       IF(SUM(COLUMN_NAME = 'Id' AND DATA_TYPE = 'bigint' AND EXTRA LIKE '%auto_increment%') = 1
          AND SUM(COLUMN_NAME = 'AziendeId' AND DATA_TYPE = 'int') = 1
          AND SUM(COLUMN_NAME = 'AltriSocialJson' AND DATA_TYPE = 'json') = 1
          AND SUM(COLUMN_NAME = 'ExtraProviderConfigJson' AND DATA_TYPE = 'json') = 1
          AND SUM(COLUMN_NAME = 'SecretsCryptoVersion' AND DATA_TYPE = 'smallint') = 1, 'OK', 'STOP') AS Stato
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo';

SELECT 'TYPE_GROUPS' AS Controllo,
       IF(SUM(DATA_TYPE = 'bigint') = 1 AND SUM(DATA_TYPE = 'int') = 2
          AND SUM(DATA_TYPE = 'smallint') = 2 AND SUM(DATA_TYPE = 'tinyint') = 1
          AND SUM(DATA_TYPE = 'varchar') = 75 AND SUM(DATA_TYPE = 'char') = 2
          AND SUM(DATA_TYPE = 'text') = 82 AND SUM(DATA_TYPE = 'longtext') = 1
          AND SUM(DATA_TYPE = 'json') = 2 AND SUM(DATA_TYPE = 'datetime') = 25,
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

SELECT 'DEFAULTS_AND_EMPTY_JSON' AS Controllo,
       IF((SELECT COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo' AND COLUMN_NAME = 'ConfigVersion') = '1'
          AND (SELECT COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo' AND COLUMN_NAME = 'SecretsCryptoVersion') = '0'
          AND (SELECT COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende_seo' AND COLUMN_NAME = 'GoogleOAuthAccessTokenExpiresAt') = '1000-01-01 00:00:00'
          AND (SELECT COUNT(*) FROM aziende_seo WHERE JSON_TYPE(AltriSocialJson) <> 'OBJECT' OR JSON_LENGTH(AltriSocialJson) <> 0
                      OR JSON_TYPE(ExtraProviderConfigJson) <> 'OBJECT' OR JSON_LENGTH(ExtraProviderConfigJson) <> 0) = 0,
          'OK', 'STOP') AS Stato;

SELECT 'NO_AUTO_LEGACY_COPY' AS Controllo,
       IF(COUNT(*) = 0, 'OK', 'STOP') AS Stato
FROM aziende_seo
WHERE GoogleMerchantId <> '' OR MetaPixelId <> '' OR TrackingScriptLegacy <> '' OR FacebookUrl <> '';

SELECT 'NO_INITIAL_SECRETS' AS Controllo,
       IF(COUNT(*) = 0, 'OK', 'STOP') AS Stato
FROM aziende_seo
WHERE SecretsCryptoVersion <> 0 OR SecretsKeyId <> '';

-- Il checksum di nome + posizione delle 193 colonne e derivato staticamente
-- dal forward. Questo verify non espone valori legacy o credenziali.
