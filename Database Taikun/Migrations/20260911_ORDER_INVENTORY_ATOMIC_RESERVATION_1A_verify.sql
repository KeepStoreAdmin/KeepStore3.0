-- ORDER-INVENTORY-ATOMIC-RESERVATION-1A read-only verification
-- Baseline fingerprint (SHA2(ROUTINE_DEFINITION,256)):
-- Carrello_Documento = a3e831a40e998c139b58b739a9392d5878da827af3648b0011b9ae84f6995004
-- Carrello_Documento_InventoryV1 = 6f2dce32dd01c548bf9faebeb3c90424821f4dfadbe2fb52339b9b644d065ca9
SELECT ROUTINE_NAME, ROUTINE_TYPE, DATA_TYPE,
       SHA2(ROUTINE_DEFINITION,256) AS definition_sha256,
       ROUTINE_DEFINITION LIKE '%COMMIT%' AS contains_commit,
       ROUTINE_DEFINITION LIKE '%ROLLBACK%' AS contains_rollback,
       ROUTINE_DEFINITION LIKE '%MagazziniID=1%' AS contains_warehouse_1,
       ROUTINE_DEFINITION LIKE '%articoli_giacenze%' AS references_inventory
FROM information_schema.routines
WHERE ROUTINE_SCHEMA = DATABASE()
  AND ROUTINE_NAME IN ('Carrello_Documento','Carrello_Documento_InventoryV1')
ORDER BY ROUTINE_NAME;

SELECT SPECIFIC_NAME AS ROUTINE_NAME, ORDINAL_POSITION, PARAMETER_MODE, PARAMETER_NAME,
       DTD_IDENTIFIER
FROM information_schema.parameters
WHERE SPECIFIC_SCHEMA = DATABASE()
  AND SPECIFIC_NAME = 'Carrello_Documento_InventoryV1'
ORDER BY ORDINAL_POSITION;

SELECT COUNT(*) AS inventory_unique_key_count
FROM information_schema.statistics
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'articoli_giacenze'
  AND INDEX_NAME = 'idxTC'
  AND NON_UNIQUE = 0;

SELECT COUNT(*) AS inventory_required_columns
FROM information_schema.columns
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'articoli_giacenze'
  AND COLUMN_NAME IN ('MagazziniId','ArticoliId','TCid','Giacenza','Impegnata');
