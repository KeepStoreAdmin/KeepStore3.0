-- Read-only; does not expose credential values.
SELECT DATABASE() AS SelectedDatabase,
       CASE WHEN DATABASE() IS NULL THEN 'STOP' ELSE 'OK' END AS DatabaseStatus;

SELECT CASE WHEN COUNT(*)=3 AND
                 SUM(COLUMN_NAME='ClientId' AND DATA_TYPE='varchar' AND CHARACTER_MAXIMUM_LENGTH=255 AND IS_NULLABLE='YES')=1 AND
                 SUM(COLUMN_NAME='ClientSecret' AND DATA_TYPE='varchar' AND CHARACTER_MAXIMUM_LENGTH=512 AND IS_NULLABLE='YES')=1 AND
                 SUM(COLUMN_NAME='WebhookId' AND DATA_TYPE='varchar' AND CHARACTER_MAXIMUM_LENGTH=128 AND IS_NULLABLE='YES')=1
            THEN 'OK' ELSE 'STOP' END AS CredentialColumnsStatus
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_account'
  AND COLUMN_NAME IN ('ClientId','ClientSecret','WebhookId');

SELECT CASE WHEN COUNT(*)=8 THEN 'OK' ELSE 'STOP' END AS PreservedAccountColumnsStatus
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_account'
  AND COLUMN_NAME IN ('Id','NomeProfilo','CredentialKey','MerchantId','Attivo','Note','CreatedAt','UpdatedAt');
