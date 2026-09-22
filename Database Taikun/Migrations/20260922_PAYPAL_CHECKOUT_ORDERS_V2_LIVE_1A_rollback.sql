-- Eseguire soltanto dopo rollback-preflight OK e autorizzazione esplicita.
-- DDL MySQL non e transazionale. Eseguire solo dopo rollback-preflight OK.
CREATE TABLE `payment_event` (
  `id` int NOT NULL AUTO_INCREMENT, `idDocumento` int DEFAULT 0, `Data_Evento` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `idTransazione` varchar(30) DEFAULT NULL, `Stato_Transazione` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
CREATE TABLE `paypal_express_impostazioni_azienda` (
  `id` int NOT NULL AUTO_INCREMENT, `AziendeId` int NOT NULL, `PagamentiTipoId` int NOT NULL,
  `NomeProfilo` varchar(100) NOT NULL, `Attivo` tinyint(1) NOT NULL DEFAULT 0,
  `Environment` enum('sandbox','live') NOT NULL DEFAULT 'sandbox', `ApiUsername` varchar(255) DEFAULT NULL,
  `ApiPasswordProtetta` text, `ApiSignatureProtetta` text, `BusinessAccount` varchar(255) DEFAULT NULL,
  `CurrencyCode` char(3) NOT NULL DEFAULT 'EUR', `AllowLive` tinyint(1) NOT NULL DEFAULT 0, `Note` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `UX_paypal_express_company_payment` (`AziendeId`,`PagamentiTipoId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `paypal_express_transazioni` (
  `id` bigint NOT NULL AUTO_INCREMENT, `DocumentiId` int DEFAULT NULL, `AziendeId` int DEFAULT NULL, `PagamentiTipoId` int DEFAULT NULL,
  `Token` varchar(120) DEFAULT NULL, `PayerId` varchar(120) DEFAULT NULL, `TransactionId` varchar(120) DEFAULT NULL,
  `Stato` varchar(40) DEFAULT NULL, `Ack` varchar(40) DEFAULT NULL, `PaymentStatus` varchar(60) DEFAULT NULL,
  `PendingReason` varchar(100) DEFAULT NULL, `ReasonCode` varchar(100) DEFAULT NULL, `Importo` decimal(15,2) DEFAULT NULL,
  `Valuta` char(3) DEFAULT NULL, `ErrorCode` varchar(40) DEFAULT NULL, `ShortMessage` varchar(255) DEFAULT NULL,
  `DataCreazione` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, `DataAggiornamento` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `IX_paypal_express_document` (`DocumentiId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `paypal_express_log` (
  `id` bigint NOT NULL AUTO_INCREMENT, `DocumentiId` int DEFAULT NULL, `AziendeId` int DEFAULT NULL,
  `Evento` varchar(80) DEFAULT NULL, `Esito` varchar(40) DEFAULT NULL, `Messaggio` varchar(255) DEFAULT NULL,
  `TokenMasked` varchar(80) DEFAULT NULL, `ErrorCode` varchar(40) DEFAULT NULL, `DataCreazione` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `IX_paypal_express_log_document` (`DocumentiId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE OR REPLACE VIEW `vpaypal_express_azienda` AS
SELECT c.*,p.OnLine FROM paypal_express_impostazioni_azienda c INNER JOIN pagamentitipo p ON p.Id=c.PagamentiTipoId;
DROP TABLE `paypal_checkout_eventi`;
DROP TABLE `paypal_checkout_transazioni`;
DROP TABLE `paypal_checkout_azienda`;
DROP TABLE `paypal_checkout_account`;
SET @ks_origin_owned = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti' AND COLUMN_NAME='OrigineOrdine'
    AND COLUMN_COMMENT='PAYPAL_ORDERS_V2_ORIGIN_20260922');
SET @ks_origin_sql = IF(@ks_origin_owned=1,
  'ALTER TABLE `documenti` DROP COLUMN `OrigineOrdine`', 'DO 0');
PREPARE ks_origin_stmt FROM @ks_origin_sql;
EXECUTE ks_origin_stmt;
DEALLOCATE PREPARE ks_origin_stmt;
