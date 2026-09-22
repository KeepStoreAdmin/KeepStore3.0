-- Rollback ammesso solo prima di dati Orders v2 reali.
SELECT 'NEW_RUNTIME_DATA_EMPTY' AS Controllo,
CASE WHEN (SELECT COUNT(*) FROM paypal_checkout_transazioni)=0 AND (SELECT COUNT(*) FROM paypal_checkout_eventi)=0 THEN 'OK' ELSE 'STOP' END AS Esito;
SELECT 'LEGACY_AUDIT_AVAILABLE' AS Controllo,
CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_legacy_audit';
