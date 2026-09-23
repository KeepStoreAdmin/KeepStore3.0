-- Run only after preflight READY, verified backup, and explicit deployment approval.
-- MySQL DDL commits implicitly. Existing rows and columns are not rewritten.
ALTER TABLE `paypal_checkout_account`
  ADD COLUMN `ClientId` varchar(255) NULL,
  ADD COLUMN `ClientSecret` varchar(512) NULL,
  ADD COLUMN `WebhookId` varchar(128) NULL;
