USE `taikun`;
SELECT DATABASE() AS DatabaseSelezionato,
       CASE WHEN DATABASE()='taikun' THEN 'OK' ELSE 'STOP' END AS EsitoDatabase;

SELECT ROUTINE_NAME, ROUTINE_TYPE,
       SHA2(ROUTINE_DEFINITION,256) AS definition_sha256,
       CASE WHEN ROUTINE_NAME='Carrello_Documento'
                  AND SHA2(ROUTINE_DEFINITION,256)='42d3078e7198c56a06880ce0f8fb56f827ee30a495de3a52408a00e67c1cf168'
            THEN 1 ELSE 0 END AS new_fingerprint_matches,
       ROUTINE_DEFINITION LIKE '%MagazziniId=1%' AS contains_warehouse_1,
       ROUTINE_DEFINITION LIKE '%Giacenza%Impegnata%' AS contains_availability_formula,
       ROUTINE_DEFINITION REGEXP 'UPDATE[[:space:]]+articoli_giacenze' AS updates_inventory,
       ROUTINE_DEFINITION LIKE '%GROUP BY ArticoliId, TCId%' AS aggregates_inventory_keys,
       ROUTINE_DEFINITION LIKE '%ORDER BY ArticoliId, TCId%' AS orders_inventory_keys,
       ROUTINE_DEFINITION LIKE '%ORDER_INVENTORY_UNAVAILABLE%' AS has_stable_unavailable_signal,
       ROUTINE_DEFINITION LIKE '%ORDER_INVENTORY_INVALID%' AS has_stable_invalid_signal,
       ROUTINE_DEFINITION LIKE '%ORDER_INVENTORY_EMPTY_CART%' AS has_empty_cart_signal,
       ROUTINE_DEFINITION NOT LIKE '%COMMIT%' AS no_commit,
       ROUTINE_DEFINITION NOT LIKE '%ROLLBACK%' AS no_rollback,
       ROUTINE_DEFINITION NOT LIKE '%START TRANSACTION%' AS no_start_transaction,
       ROUTINE_DEFINITION NOT LIKE '%AUTOCOMMIT%' AS no_autocommit
FROM information_schema.routines
WHERE ROUTINE_SCHEMA='taikun' AND ROUTINE_NAME='Carrello_Documento';

SELECT SPECIFIC_NAME AS ROUTINE_NAME, ORDINAL_POSITION, PARAMETER_MODE, PARAMETER_NAME, DTD_IDENTIFIER
FROM information_schema.parameters
WHERE SPECIFIC_SCHEMA='taikun' AND SPECIFIC_NAME='Carrello_Documento'
ORDER BY ORDINAL_POSITION;

SELECT ROUTINE_NAME AS UnexpectedAlternativeProcedure
FROM information_schema.routines
WHERE ROUTINE_SCHEMA='taikun'
  AND ROUTINE_NAME IN ('Carrello_Documento_WebV1','Carrello_Documento_InventoryV1');
