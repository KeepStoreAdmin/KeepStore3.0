-- PAYPAL-CHECKOUT-ORDERS-V2-LIVE-1A / preflight read-only
SELECT DATABASE() AS DatabaseSelezionato,
       CASE WHEN DATABASE() IS NULL OR DATABASE() = '' THEN 'STOP' ELSE 'OK' END AS Esito;

SELECT 'DOCUMENT_PAYMENT_CONTRACT' AS Controllo,
       CASE WHEN COUNT(*) = 4 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'documenti'
  AND COLUMN_NAME IN ('AziendeId','PagamentiTipoId','Pagato','StatoPagamentoWeb');

SELECT 'DOCUMENT_ORIGIN' AS Controllo,
       CASE WHEN COUNT(*)=0 THEN 'COLUMN_REQUIRED'
            WHEN COUNT(*)=1 AND MAX(DATA_TYPE)='varchar' AND MAX(CHARACTER_MAXIMUM_LENGTH)>=16 AND MAX(IS_NULLABLE)='YES' THEN 'EXISTING_EQUIVALENT'
            ELSE 'STOP' END AS Esito
FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti' AND COLUMN_NAME='OrigineOrdine';

SELECT 'PAYPAL_PAYMENT_METHODS' AS Controllo,
       CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM pagamentitipo WHERE OnLine = 2;

SELECT 'LEGACY_OBJECTS_AUDITED' AS Controllo,
       COUNT(*) AS OggettiLegacy
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('payment_event','paypal_express_impostazioni_azienda','paypal_express_log','paypal_express_transazioni','vpaypal_express_azienda');

SELECT 'NEW_OBJECTS_ABSENT' AS Controllo,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('paypal_checkout_account','paypal_checkout_azienda','paypal_checkout_transazioni','paypal_checkout_eventi','paypal_checkout_legacy_audit');
