-- ORDER-DURABLE-IDEMPOTENCY-1A - forward
-- Precondition: preflight returned OK, not ALREADY_COMPLIANT.

CREATE TABLE `ordini_web_idempotenza` (
  `RequestId` varchar(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `LoginId` bigint NOT NULL,
  `TipoDocumentiId` int NOT NULL,
  `PayloadFingerprint` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `DocumentoMemorizzato` bigint DEFAULT NULL,
  `DocumentiId` bigint DEFAULT NULL,
  `Stato` varchar(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `DataCreazione` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `DataCompletamento` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`RequestId`),
  KEY `IX_ordini_web_idempotenza_owner` (`LoginId`,`DataCreazione`),
  KEY `IX_ordini_web_idempotenza_stato` (`Stato`,`DataCreazione`)
) ENGINE=InnoDB DEFAULT CHARSET=ascii COLLATE=ascii_bin;
