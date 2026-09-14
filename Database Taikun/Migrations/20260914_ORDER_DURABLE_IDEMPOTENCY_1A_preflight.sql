-- ORDER-DURABLE-IDEMPOTENCY-1A - read-only preflight
-- Run in the explicitly selected KeepStore database.

SELECT 'DatabaseSelected' AS CheckName,
       CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Result;

SELECT 'CanonicalDependencies' AS CheckName,
       CASE WHEN
           (SELECT COUNT(*) FROM information_schema.ROUTINES
            WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE')=1
           AND
           (SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('carrello','documenti') AND ENGINE='InnoDB')=2
       THEN 'OK' ELSE 'STOP' END AS Result;

SET @ks_grantee := CONCAT(QUOTE(SUBSTRING_INDEX(CURRENT_USER(),'@',1)), '@', QUOTE(SUBSTRING_INDEX(CURRENT_USER(),'@',-1)));
SELECT 'RequiredPrivileges' AS CheckName,
       CASE WHEN
           (EXISTS (SELECT 1 FROM information_schema.USER_PRIVILEGES
                    WHERE GRANTEE=@ks_grantee AND PRIVILEGE_TYPE='CREATE')
            OR EXISTS (SELECT 1 FROM information_schema.SCHEMA_PRIVILEGES
                       WHERE GRANTEE=@ks_grantee AND TABLE_SCHEMA=DATABASE() AND PRIVILEGE_TYPE='CREATE'))
           AND
           (EXISTS (SELECT 1 FROM information_schema.USER_PRIVILEGES
                    WHERE GRANTEE=@ks_grantee AND PRIVILEGE_TYPE='DROP')
            OR EXISTS (SELECT 1 FROM information_schema.SCHEMA_PRIVILEGES
                       WHERE GRANTEE=@ks_grantee AND TABLE_SCHEMA=DATABASE() AND PRIVILEGE_TYPE='DROP'))
       THEN 'OK' ELSE 'STOP' END AS Result;

SELECT 'IdempotencyTableState' AS CheckName,
       CASE
           WHEN NOT EXISTS (SELECT 1 FROM information_schema.TABLES
                            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza') THEN 'OK'
           WHEN (SELECT ENGINE FROM information_schema.TABLES
                 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza')='InnoDB'
                AND (SELECT COUNT(*) FROM information_schema.COLUMNS
                     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza'
                       AND COLUMN_NAME IN ('RequestId','LoginId','TipoDocumentiId','PayloadFingerprint','DocumentoMemorizzato','DocumentiId','Stato','DataCreazione','DataCompletamento'))=9
                AND EXISTS (SELECT 1 FROM information_schema.STATISTICS
                            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza'
                              AND INDEX_NAME='PRIMARY' AND COLUMN_NAME='RequestId' AND SEQ_IN_INDEX=1)
           THEN 'ALREADY_COMPLIANT'
           ELSE 'STOP'
       END AS Result;
