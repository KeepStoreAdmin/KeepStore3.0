-- ROUTINE-DIAGNOSTIC-READONLY-1A. Read-only diagnosis of the order routines of the SELECTED database.
-- Standard and universal: the same text runs on every KeepStore database; it names no database, customer, domain or template.
-- The target is the database the operator has selected (DATABASE()). Nothing is written and no customer, order or document data is read.
-- Output: one grid (key, value): identity and version, presence of Carrello_Documento and Carrello_Totali, definer, length and SHA-256 of the body,
-- creation metadata, parameter signature, relevant tables and columns, triggers and grants.
SELECT CONVERT('01 info' USING utf8mb4) COLLATE utf8mb4_unicode_ci AS k,
       CONVERT(CONCAT_WS(' | ', DATABASE(), VERSION(), @@server_uuid, @@global.sql_mode) USING utf8mb4) COLLATE utf8mb4_unicode_ci AS v
UNION ALL
SELECT CONVERT(CONCAT('02 conteggio ', n.nome) USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(COUNT(r.ROUTINE_NAME) USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM (SELECT 'Carrello_Documento' AS nome UNION ALL SELECT 'Carrello_Totali') n
LEFT JOIN information_schema.ROUTINES r
  ON r.ROUTINE_NAME = n.nome AND r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_TYPE = 'PROCEDURE'
GROUP BY n.nome
UNION ALL
SELECT CONVERT(CONCAT('03 routine ', ROUTINE_NAME) USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(CONCAT_WS(' | ', CONCAT('definer=', DEFINER), CONCAT('security=', SECURITY_TYPE),
              CONCAT('len=', CHAR_LENGTH(ROUTINE_DEFINITION)), CONCAT('sha=', SHA2(ROUTINE_DEFINITION, 256)),
              CONCAT('sha_lf=', SHA2(REPLACE(ROUTINE_DEFINITION, CHAR(13), ''), 256)),
              CONCAT('modificata=', LAST_ALTERED), CONCAT('sql_mode=', SQL_MODE),
              CONCAT('cs=', CHARACTER_SET_CLIENT, '/', COLLATION_CONNECTION, '/', DATABASE_COLLATION)) USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_NAME IN ('Carrello_Documento', 'Carrello_Totali')
UNION ALL
SELECT CONVERT('04 parametri Carrello_Documento' USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(CONCAT_WS(' | ', COUNT(*),
              SHA2(GROUP_CONCAT(CONCAT_WS(':', ORDINAL_POSITION, PARAMETER_MODE, PARAMETER_NAME, DATA_TYPE,
                   COALESCE(CHARACTER_MAXIMUM_LENGTH, ''), COALESCE(NUMERIC_PRECISION, ''), COALESCE(NUMERIC_SCALE, ''))
                   ORDER BY ORDINAL_POSITION SEPARATOR '|'), 256)) USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM information_schema.PARAMETERS
WHERE SPECIFIC_SCHEMA = DATABASE() AND SPECIFIC_NAME = 'Carrello_Documento' AND PARAMETER_MODE IN ('IN', 'OUT')
UNION ALL
SELECT CONVERT(CONCAT('05 tabella ', TABLE_NAME) USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(CONCAT_WS(' | ', TABLE_TYPE, ENGINE) USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) IN ('documenti', 'documentipie', 'controllaarrotondamento', 'carrello', 'vcarrello')
UNION ALL
SELECT CONVERT(CONCAT('06 colonna ', TABLE_NAME, '.', COLUMN_NAME) USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(COLUMN_TYPE USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND ((LOWER(TABLE_NAME) = 'documentipie' AND COLUMN_NAME IN ('TotMerce', 'TotImponibile', 'TotIva', 'TotaleDocumento'))
    OR (LOWER(TABLE_NAME) = 'documenti' AND COLUMN_NAME IN ('Arrotondamento', 'NDocumento'))
    OR LOWER(TABLE_NAME) = 'controllaarrotondamento')
UNION ALL
SELECT CONVERT(CONCAT('07 trigger ', TRIGGER_NAME) USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(CONCAT_WS(' | ', EVENT_OBJECT_TABLE, ACTION_TIMING, EVENT_MANIPULATION) USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = DATABASE() AND LOWER(EVENT_OBJECT_TABLE) IN ('documenti', 'documentipie', 'documentirighe')
UNION ALL
SELECT CONVERT(CONCAT('08 permessi routine ', Routine_name) USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(CONCAT_WS(' | ', CONCAT(User, '@', Host), Proc_priv) USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM mysql.procs_priv
WHERE Db = DATABASE() AND Routine_name IN ('Carrello_Documento', 'Carrello_Totali')
UNION ALL
SELECT CONVERT('09 permessi database (Execute)' USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(CONCAT_WS(' | ', CONCAT(User, '@', Host), CONCAT('Execute=', Execute_priv)) USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM mysql.db
WHERE Db = DATABASE()
;
