-- PAYPAL-CHECKOUT-ORDERS-V2-LIVE-1A / forward
-- Eseguire soltanto dopo preflight OK e backup verificato.
-- MySQL DDL effettua commit impliciti: backup/preflight sono obbligatori.
-- Se il campo equivalente esiste, non viene alterato. La migration marca solo
-- il campo creato da essa, cosi il rollback non rimuove campi preesistenti.
SET @ks_origin_exists = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti' AND COLUMN_NAME='OrigineOrdine');
SET @ks_origin_sql = IF(@ks_origin_exists=0,
  'ALTER TABLE `documenti` ADD COLUMN `OrigineOrdine` varchar(16) NULL COMMENT ''PAYPAL_ORDERS_V2_ORIGIN_20260922''',
  'DO 0');
PREPARE ks_origin_stmt FROM @ks_origin_sql;
EXECUTE ks_origin_stmt;
DEALLOCATE PREPARE ks_origin_stmt;

CREATE TABLE `paypal_checkout_account` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `NomeProfilo` varchar(100) NOT NULL,
  `CredentialKey` varchar(64) NOT NULL,
  `MerchantId` varchar(128) NOT NULL,
  `Attivo` tinyint(1) NOT NULL DEFAULT 0,
  `Note` varchar(500) DEFAULT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id`), UNIQUE KEY `UX_paypal_checkout_account_credential` (`CredentialKey`),
  CONSTRAINT `CK_paypal_checkout_account_credential` CHECK (`CredentialKey` REGEXP '^[A-Z][A-Z0-9_]{2,63}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `paypal_checkout_azienda` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `AziendeId` int NOT NULL,
  `PagamentiTipoId` int NOT NULL,
  `PayPalAccountId` int NOT NULL,
  `PayeeEmail` varchar(254) NOT NULL,
  `BrandName` varchar(127) NOT NULL,
  `CurrencyCode` char(3) NOT NULL,
  `Attivo` tinyint(1) NOT NULL DEFAULT 0,
  `Note` varchar(500) DEFAULT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id`), UNIQUE KEY `UX_paypal_checkout_azienda_payment` (`AziendeId`,`PagamentiTipoId`),
  KEY `IX_paypal_checkout_azienda_account` (`PayPalAccountId`),
  CONSTRAINT `FK_paypal_checkout_azienda_account` FOREIGN KEY (`PayPalAccountId`) REFERENCES `paypal_checkout_account` (`Id`),
  CONSTRAINT `CK_paypal_checkout_azienda_currency` CHECK (`CurrencyCode` REGEXP '^[A-Z]{3}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `paypal_checkout_transazioni` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `DocumentiId` int NOT NULL,
  `TentativoNo` int NOT NULL,
  `CurrentSlot` tinyint(1) DEFAULT NULL,
  `AziendeId` int NOT NULL,
  `PagamentiTipoId` int NOT NULL,
  `PayPalAccountId` int NOT NULL,
  `PayPalOrderId` varchar(100) DEFAULT NULL,
  `PayPalCaptureId` varchar(100) DEFAULT NULL,
  `Stato` varchar(40) NOT NULL,
  `Importo` decimal(15,2) NOT NULL,
  `Valuta` char(3) NOT NULL,
  `PayeeEmail` varchar(254) NOT NULL,
  `MerchantId` varchar(128) NOT NULL,
  `CreateRequestId` varchar(80) NOT NULL,
  `CaptureRequestId` varchar(80) NOT NULL,
  `UltimoEsito` varchar(255) DEFAULT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id`), UNIQUE KEY `UX_paypal_checkout_tx_attempt` (`DocumentiId`,`TentativoNo`),
  UNIQUE KEY `UX_paypal_checkout_tx_current` (`DocumentiId`,`CurrentSlot`),
  UNIQUE KEY `UX_paypal_checkout_tx_order` (`PayPalOrderId`), UNIQUE KEY `UX_paypal_checkout_tx_capture` (`PayPalCaptureId`),
  UNIQUE KEY `UX_paypal_checkout_tx_create_request` (`CreateRequestId`), UNIQUE KEY `UX_paypal_checkout_tx_capture_request` (`CaptureRequestId`),
  KEY `IX_paypal_checkout_tx_company` (`AziendeId`), KEY `IX_paypal_checkout_tx_account` (`PayPalAccountId`),
  CONSTRAINT `FK_paypal_checkout_tx_account` FOREIGN KEY (`PayPalAccountId`) REFERENCES `paypal_checkout_account` (`Id`),
  CONSTRAINT `CK_paypal_checkout_tx_slot` CHECK (`CurrentSlot` IS NULL OR `CurrentSlot`=1),
  CONSTRAINT `CK_paypal_checkout_tx_attempt` CHECK (`TentativoNo`>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `paypal_checkout_eventi` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `EventId` varchar(100) NOT NULL,
  `TransazioniId` bigint NOT NULL,
  `EventType` varchar(80) NOT NULL,
  `CaptureId` varchar(100) DEFAULT NULL,
  `Stato` varchar(40) NOT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id`), UNIQUE KEY `UX_paypal_checkout_event_event` (`EventId`),
  KEY `IX_paypal_checkout_event_tx` (`TransazioniId`),
  CONSTRAINT `FK_paypal_checkout_event_tx` FOREIGN KEY (`TransazioniId`) REFERENCES `paypal_checkout_transazioni` (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP VIEW IF EXISTS `vpaypal_express_azienda`;
DROP TABLE IF EXISTS `payment_event`;
DROP TABLE IF EXISTS `paypal_express_log`;
DROP TABLE IF EXISTS `paypal_express_transazioni`;
DROP TABLE IF EXISTS `paypal_express_impostazioni_azienda`;
