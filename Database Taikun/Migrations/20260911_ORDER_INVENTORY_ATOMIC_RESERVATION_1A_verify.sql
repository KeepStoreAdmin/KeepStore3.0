USE `taikun`;
SELECT
    DATABASE() AS DatabaseSelezionato,
    CASE
        WHEN DATABASE() = 'taikun' THEN 'OK'
        ELSE 'STOP'
    END AS EsitoDatabase;

-- ORDER-INVENTORY-ATOMIC-RESERVATION-1A read-only verification
-- Baseline fingerprint (SHA2(ROUTINE_DEFINITION,256)):
-- Carrello_Documento = a3e831a40e998c139b58b739a9392d5878da827af3648b0011b9ae84f6995004
-- Carrello_Documento_WebV1 = recalculated after installation of the renamed web-only routine
SELECT ROUTINE_NAME, ROUTINE_TYPE, DATA_TYPE,
       SHA2(ROUTINE_DEFINITION,256) AS definition_sha256,
       CASE WHEN ROUTINE_NAME = 'Carrello_Documento'
                  AND SHA2(ROUTINE_DEFINITION,256) = 'a3e831a40e998c139b58b739a9392d5878da827af3648b0011b9ae84f6995004'
            THEN 1
            WHEN ROUTINE_NAME = 'Carrello_Documento' THEN 0
            ELSE NULL END AS historical_fingerprint_matches,
       ROUTINE_DEFINITION LIKE '%COMMIT%' AS contains_commit,
       ROUTINE_DEFINITION LIKE '%ROLLBACK%' AS contains_rollback,
       ROUTINE_DEFINITION LIKE '%MagazziniID=1%' AS contains_warehouse_1,
       ROUTINE_DEFINITION LIKE '%articoli_giacenze%' AS references_inventory,
       ROUTINE_DEFINITION REGEXP 'UPDATE[[:space:]]+articoli_giacenze' AS updates_inventory,
       ROUTINE_DEFINITION LIKE '%WEB ONLY - inventory reserved by caller in the same transaction%' AS has_web_only_contract
FROM information_schema.routines
WHERE ROUTINE_SCHEMA = 'taikun'
  AND ROUTINE_NAME IN ('Carrello_Documento','Carrello_Documento_WebV1')
ORDER BY ROUTINE_NAME;

SELECT SPECIFIC_NAME AS ROUTINE_NAME, ORDINAL_POSITION, PARAMETER_MODE, PARAMETER_NAME,
       DTD_IDENTIFIER
FROM information_schema.parameters
WHERE SPECIFIC_SCHEMA = 'taikun'
  AND SPECIFIC_NAME = 'Carrello_Documento_WebV1'
ORDER BY ORDINAL_POSITION;

SELECT ROUTINE_NAME AS UnexpectedLegacyWebProcedure
FROM information_schema.routines
WHERE ROUTINE_SCHEMA = 'taikun'
  AND ROUTINE_NAME = 'Carrello_Documento_InventoryV1';

SELECT COUNT(*) AS inventory_unique_key_count
FROM information_schema.statistics
WHERE TABLE_SCHEMA = 'taikun'
  AND TABLE_NAME = 'articoli_giacenze'
  AND INDEX_NAME = 'idxTC'
  AND NON_UNIQUE = 0;

SELECT COUNT(*) AS inventory_required_columns
FROM information_schema.columns
WHERE TABLE_SCHEMA = 'taikun'
  AND TABLE_NAME = 'articoli_giacenze'
  AND COLUMN_NAME IN ('MagazziniId','ArticoliId','TCid','Giacenza','Impegnata');
