-- PAYPAL-CHECKOUT-ORDERS-V2-LIVE-1A / verify read-only
SELECT 'NEW_TABLES' AS Controllo, CASE WHEN COUNT(*)=5 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN
('paypal_checkout_account','paypal_checkout_azienda','paypal_checkout_transazioni','paypal_checkout_eventi','paypal_checkout_legacy_audit');
SELECT 'LEGACY_RUNTIME_SCHEMA_REMOVED' AS Controllo, CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN
('payment_event','paypal_express_impostazioni_azienda','paypal_express_log','paypal_express_transazioni','vpaypal_express_azienda');
SELECT 'ACCOUNT_HAS_NO_SECRET_COLUMNS' AS Controllo,
CASE WHEN SUM(LOWER(COLUMN_NAME) REGEXP 'secret|password|signature|token')=0 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_account';
SELECT 'TENANT_UNIQUE' AS Controllo, CASE WHEN COUNT(DISTINCT INDEX_NAME)=1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_azienda' AND INDEX_NAME='UX_paypal_checkout_azienda_payment';
SELECT 'TRANSACTION_UNIQUES' AS Controllo, CASE WHEN COUNT(DISTINCT INDEX_NAME)=4 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_transazioni'
AND INDEX_NAME IN ('UX_paypal_checkout_tx_document','UX_paypal_checkout_tx_order','UX_paypal_checkout_tx_capture','UX_paypal_checkout_tx_create_request');
SELECT 'EVENT_IDEMPOTENCY' AS Controllo, CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS Esito
FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_eventi' AND INDEX_NAME='UX_paypal_checkout_event_event';
SELECT 'CONFIGURATION_STATUS' AS Controllo, COUNT(*) AS ProfiliAccount, SUM(Attivo=1) AS ProfiliAttivi FROM paypal_checkout_account;
SELECT 'TENANT_STATUS' AS Controllo, COUNT(*) AS AziendeConfigurate, SUM(Attivo=1) AS AziendeAttive FROM paypal_checkout_azienda;
SELECT 'READY_FOR_LIVE_CONFIGURATION' AS Stato;
