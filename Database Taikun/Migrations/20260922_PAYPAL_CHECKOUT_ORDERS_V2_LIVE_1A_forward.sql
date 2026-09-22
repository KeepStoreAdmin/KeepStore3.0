-- PAYPAL-CHECKOUT-ORDERS-V2-LIVE-1A / forward
-- Eseguire soltanto dopo preflight OK e backup verificato.
START TRANSACTION;

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
  PRIMARY KEY (`Id`), UNIQUE KEY `UX_paypal_checkout_tx_document` (`DocumentiId`),
  UNIQUE KEY `UX_paypal_checkout_tx_order` (`PayPalOrderId`), UNIQUE KEY `UX_paypal_checkout_tx_capture` (`PayPalCaptureId`),
  UNIQUE KEY `UX_paypal_checkout_tx_create_request` (`CreateRequestId`), UNIQUE KEY `UX_paypal_checkout_tx_capture_request` (`CaptureRequestId`),
  KEY `IX_paypal_checkout_tx_company` (`AziendeId`), KEY `IX_paypal_checkout_tx_account` (`PayPalAccountId`),
  CONSTRAINT `FK_paypal_checkout_tx_account` FOREIGN KEY (`PayPalAccountId`) REFERENCES `paypal_checkout_account` (`Id`)
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

CREATE TABLE `paypal_checkout_legacy_audit` (
  `Id` bigint NOT NULL AUTO_INCREMENT, `LegacySource` varchar(64) NOT NULL, `LegacyId` bigint DEFAULT NULL,
  `DocumentiId` int DEFAULT NULL, `AziendeId` int DEFAULT NULL, `ExternalReferenceMasked` varchar(80) DEFAULT NULL,
  `Stato` varchar(60) DEFAULT NULL, `Esito` varchar(255) DEFAULT NULL, `OccurredAt` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`), KEY `IX_paypal_legacy_audit_document` (`DocumentiId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `paypal_checkout_legacy_audit` (`LegacySource`,`LegacyId`,`DocumentiId`,`AziendeId`,`ExternalReferenceMasked`,`Stato`,`Esito`,`OccurredAt`)
SELECT 'transaction',id,DocumentiId,AziendeId,CASE WHEN COALESCE(TransactionId,'')='' THEN NULL ELSE CONCAT(LEFT(TransactionId,6),'...',RIGHT(TransactionId,4)) END,Stato,ShortMessage,DataAggiornamento
FROM `paypal_express_transazioni`;
INSERT INTO `paypal_checkout_legacy_audit` (`LegacySource`,`LegacyId`,`DocumentiId`,`AziendeId`,`ExternalReferenceMasked`,`Stato`,`Esito`,`OccurredAt`)
SELECT 'log',id,DocumentiId,AziendeId,TokenMasked,Esito,Messaggio,DataCreazione FROM `paypal_express_log`;
INSERT INTO `paypal_checkout_legacy_audit` (`LegacySource`,`LegacyId`,`DocumentiId`,`ExternalReferenceMasked`,`Stato`,`OccurredAt`)
SELECT 'ipn_event',id,idDocumento,CASE WHEN COALESCE(idTransazione,'')='' THEN NULL ELSE CONCAT(LEFT(idTransazione,6),'...',RIGHT(idTransazione,4)) END,Stato_Transazione,Data_Evento
FROM `payment_event`;

DROP VIEW IF EXISTS `vpaypal_express_azienda`;
DROP TABLE IF EXISTS `payment_event`;
DROP TABLE IF EXISTS `paypal_express_log`;
DROP TABLE IF EXISTS `paypal_express_transazioni`;
DROP TABLE IF EXISTS `paypal_express_impostazioni_azienda`;
COMMIT;
