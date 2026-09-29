-- DRAFT NON INSTALLATO
-- NON ESEGUIRE SENZA REVIEW CHATGPT E ALLOWLIST PRODUCT OWNER.
-- Eseguire soltanto dopo preflight interamente OK e backup autorizzato.
-- DDL con commit impliciti: ALTER e CREATE non sono una transazione atomica.
-- ALGORITHM=COPY blocca le scritture su carrello: non e zero downtime.
-- Nessun runtime ksc2 puo essere attivato finche verify non e interamente OK.

ALTER TABLE `carrello`
  MODIFY COLUMN `SessionId` VARCHAR(50)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NULL DEFAULT NULL,
  ALGORITHM=COPY,
  LOCK=SHARED;

-- ACTIVE scaduti: pulizia futura. CONSUMED/REVOKED: tombstone anti-replay.
-- Conservare i tombstone almeno per l'intera finestra utile dei vecchi cookie;
-- poi pulirli a batch con gli indici dedicati. Nessuna pulizia in questa migration.
CREATE TABLE `carrello_anonimo_persistenza` (
  `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `AziendeId` INT NOT NULL,
  `OwnerToken` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `Status` VARCHAR(8) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `CreatedUtc` DATETIME(6) NOT NULL,
  `LastActivityUtc` DATETIME(6) NOT NULL,
  `ExpiresUtc` DATETIME(6) NOT NULL,
  `ConsumedUtc` DATETIME(6) DEFAULT NULL,
  `RevokedUtc` DATETIME(6) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UX_carrello_anonimo_persistenza_tenant_owner` (`AziendeId`, `OwnerToken`),
  KEY `IX_carrello_anonimo_persistenza_cleanup` (`Status`, `ExpiresUtc`, `Id`),
  KEY `IX_carrello_anonimo_persistenza_consumed` (`Status`, `ConsumedUtc`, `Id`),
  KEY `IX_carrello_anonimo_persistenza_revoked` (`Status`, `RevokedUtc`, `Id`),
  CONSTRAINT `CK_carrello_anonimo_persistenza_tenant` CHECK (`AziendeId` > 0),
  CONSTRAINT `CK_carrello_anonimo_persistenza_owner`
    CHECK (CHAR_LENGTH(`OwnerToken`) = 48
       AND REGEXP_LIKE(`OwnerToken`, '^ksc2_[A-Za-z0-9_-]{43}$', 'c')),
  CONSTRAINT `CK_carrello_anonimo_persistenza_status`
    CHECK (`Status` IN ('ACTIVE', 'CONSUMED', 'REVOKED')),
  CONSTRAINT `CK_carrello_anonimo_persistenza_expiry`
    CHECK (`ExpiresUtc` > `LastActivityUtc`),
  CONSTRAINT `CK_carrello_anonimo_persistenza_terminal`
    CHECK ((`Status` = 'ACTIVE' AND `ConsumedUtc` IS NULL AND `RevokedUtc` IS NULL)
        OR (`Status` = 'CONSUMED' AND `ConsumedUtc` IS NOT NULL AND `RevokedUtc` IS NULL)
        OR (`Status` = 'REVOKED' AND `ConsumedUtc` IS NULL AND `RevokedUtc` IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin;
