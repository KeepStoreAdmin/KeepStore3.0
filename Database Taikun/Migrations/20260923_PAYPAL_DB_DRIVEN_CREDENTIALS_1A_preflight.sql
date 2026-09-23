-- Read-only preflight. Run against the explicitly selected installation database.
-- READY: all three columns absent; ALREADY_COMPLIANT: all three match exactly.
-- STOP: missing Orders v2 account table or partial/incompatible schema.
SELECT DATABASE() AS SelectedDatabase,
       CASE WHEN DATABASE() IS NULL THEN 'STOP' ELSE 'OK' END AS DatabaseStatus;

SELECT CASE
         WHEN COUNT(*)=0 THEN 'STOP'
         WHEN SUM(COLUMN_NAME IN ('Id','NomeProfilo','CredentialKey','MerchantId','Attivo','Note','CreatedAt','UpdatedAt'))<>8 THEN 'STOP'
         ELSE 'OK'
       END AS OrdersV2AccountStatus
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_account';

SELECT CASE
         WHEN COUNT(*)=0 THEN 'READY'
         WHEN COUNT(*)=3 AND
              SUM(COLUMN_NAME='ClientId' AND DATA_TYPE='varchar' AND CHARACTER_MAXIMUM_LENGTH=255 AND IS_NULLABLE='YES')=1 AND
              SUM(COLUMN_NAME='ClientSecret' AND DATA_TYPE='varchar' AND CHARACTER_MAXIMUM_LENGTH=512 AND IS_NULLABLE='YES')=1 AND
              SUM(COLUMN_NAME='WebhookId' AND DATA_TYPE='varchar' AND CHARACTER_MAXIMUM_LENGTH=128 AND IS_NULLABLE='YES')=1
           THEN 'ALREADY_COMPLIANT'
         ELSE 'STOP'
       END AS CredentialColumnsStatus
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_account'
  AND COLUMN_NAME IN ('ClientId','ClientSecret','WebhookId');
