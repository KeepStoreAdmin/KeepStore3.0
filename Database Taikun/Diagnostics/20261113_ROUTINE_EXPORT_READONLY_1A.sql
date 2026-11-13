-- ROUTINE-EXPORT-READONLY-1A. Read-only export of the exact text of the stored procedure Carrello_Documento of the SELECTED database.
-- Standard and universal: the same text runs on every KeepStore database; it names no database, customer, domain or template.
-- The target is the database the operator has selected (DATABASE()). Nothing is written and no customer, order or document data is read.
-- Output: one grid. Row A = metadata, row B = lengths and SHA-256 of the whole text, rows C = the text in chunks of 240 characters
-- with CR/LF/TAB shown as {CR} {LF} {TAB}, each with its length and MD5. Tools/Rebuild-KeepStoreRoutineExport.ps1 rebuilds and verifies it.
SELECT CONVERT('A meta' USING utf8mb4) COLLATE utf8mb4_unicode_ci AS k,
       CONVERT(CONCAT_WS(' | ', DATABASE(), VERSION(), CONCAT('definer=', r.DEFINER), CONCAT('security=', r.SECURITY_TYPE),
              CONCAT('sql_mode=', r.SQL_MODE), CONCAT('cs=', r.CHARACTER_SET_CLIENT, '/', r.COLLATION_CONNECTION, '/', r.DATABASE_COLLATION),
              CONCAT('deterministic=', r.IS_DETERMINISTIC), CONCAT('data=', r.SQL_DATA_ACCESS), CONCAT('commento=[', r.ROUTINE_COMMENT, ']'),
              CONCAT('creata=', r.CREATED), CONCAT('modificata=', r.LAST_ALTERED)) USING utf8mb4) COLLATE utf8mb4_unicode_ci AS v
FROM information_schema.ROUTINES r
WHERE r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_NAME = 'Carrello_Documento' AND r.ROUTINE_TYPE = 'PROCEDURE'
UNION ALL
SELECT CONVERT('B totale' USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(CONCAT_WS(' | ', CONCAT('len=', CHAR_LENGTH(r.ROUTINE_DEFINITION)),
              CONCAT('cr=', CHAR_LENGTH(r.ROUTINE_DEFINITION) - CHAR_LENGTH(REPLACE(r.ROUTINE_DEFINITION, CHAR(13), ''))),
              CONCAT('lf=', CHAR_LENGTH(r.ROUTINE_DEFINITION) - CHAR_LENGTH(REPLACE(r.ROUTINE_DEFINITION, CHAR(10), ''))),
              CONCAT('sha=', SHA2(r.ROUTINE_DEFINITION, 256)),
              CONCAT('sha_lf=', SHA2(REPLACE(r.ROUTINE_DEFINITION, CHAR(13), ''), 256))) USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM information_schema.ROUTINES r
WHERE r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_NAME = 'Carrello_Documento' AND r.ROUTINE_TYPE = 'PROCEDURE'
UNION ALL
SELECT CONVERT(CONCAT('C ', LPAD(nums.n, 3, '0')) USING utf8mb4) COLLATE utf8mb4_unicode_ci,
       CONVERT(CONCAT_WS(' | ', CHAR_LENGTH(SUBSTRING(r.ROUTINE_DEFINITION, nums.n * 240 + 1, 240)),
              MD5(SUBSTRING(r.ROUTINE_DEFINITION, nums.n * 240 + 1, 240)),
              CONCAT('[', REPLACE(REPLACE(REPLACE(SUBSTRING(r.ROUTINE_DEFINITION, nums.n * 240 + 1, 240), CHAR(13), '{CR}'), CHAR(10), '{LF}'), CHAR(9), '{TAB}'), ']')) USING utf8mb4) COLLATE utf8mb4_unicode_ci
FROM information_schema.ROUTINES r
JOIN (SELECT a.d + 10 * b.d + 100 * c.d AS n
      FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a,
           (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b,
           (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c) nums
  ON nums.n * 240 < CHAR_LENGTH(r.ROUTINE_DEFINITION)
WHERE r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_NAME = 'Carrello_Documento' AND r.ROUTINE_TYPE = 'PROCEDURE'
ORDER BY k;
