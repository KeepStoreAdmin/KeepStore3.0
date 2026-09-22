-- Rollback ammesso solo prima di dati Orders v2 reali.
SELECT 'NEW_RUNTIME_DATA_EMPTY' AS Controllo,
CASE WHEN (SELECT COUNT(*) FROM paypal_checkout_transazioni)=0 AND (SELECT COUNT(*) FROM paypal_checkout_eventi)=0 THEN 'OK' ELSE 'STOP' END AS Esito;
SELECT 'ORIGIN_COLUMN_EMPTY' AS Controllo,
CASE WHEN (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()
           AND TABLE_NAME='documenti' AND COLUMN_NAME='OrigineOrdine'
           AND COLUMN_COMMENT='PAYPAL_ORDERS_V2_ORIGIN_20260922')=0
     OR COUNT(*)=0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM documenti WHERE OrigineOrdine IS NOT NULL;
SELECT 'ORIGIN_MIGRATION_OWNERSHIP' AS Controllo,
CASE WHEN COUNT(*)=1 THEN 'MIGRATION_OWNED' ELSE 'EXISTING_EQUIVALENT' END AS Esito
FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti'
AND COLUMN_NAME='OrigineOrdine' AND COLUMN_COMMENT='PAYPAL_ORDERS_V2_ORIGIN_20260922';
SELECT 'LEGACY_OBJECTS_ABSENT' AS Controllo,
CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN
('payment_event','paypal_express_impostazioni_azienda','paypal_express_log','paypal_express_transazioni','vpaypal_express_azienda');
