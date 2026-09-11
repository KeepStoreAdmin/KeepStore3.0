-- ORDER-INVENTORY-ATOMIC-RESERVATION-1A rollback
-- Pre-check: the target must exist; the historical procedure is never touched.
SELECT ROUTINE_NAME AS ProcedureToRemove
FROM information_schema.routines
WHERE ROUTINE_SCHEMA = DATABASE()
  AND ROUTINE_NAME = 'Carrello_Documento_WebV1';

DROP PROCEDURE `Carrello_Documento_WebV1`;
