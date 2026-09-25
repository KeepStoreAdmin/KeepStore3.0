-- REV2 MODULAR-ARCHITECTURE-FREEZE / CATALOGO MODULI E ASSEGNAZIONI / MySQL 8.0.42.
-- DRAFT NON INSTALLATO E NON PRONTO AL ROLLOUT: non eseguire in questo task.
-- Richiede futuro gate MySQL/ambiente, preflight/verify read-only, backup e allowlist Product Owner.
-- Nessun USE, nome database cliente, seed, grant attivo o copia di valori legacy.
-- SOLO MODELLO: nessun enforcement, seed, acquisto, provisioning o disabilitazione esistente.
-- DirittoUso non deriva da token o menu; configurazione/autorizzazione provider sono nel modulo proprietario.
-- Disabilitazioni future non eliminano dati/listing e non perdono callback pagamento o ordini gia avviati.
-- Validare ModuloCodice non vuoto e LicenzaFine >= LicenzaInizio prima del futuro salvataggio.

CREATE TABLE `moduli_catalogo` (
  `ModuloCodice` VARCHAR(64) NOT NULL DEFAULT '',
  `Nome` VARCHAR(128) NOT NULL DEFAULT '',
  `Descrizione` TEXT NOT NULL DEFAULT (''),
  `Disponibile` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `DataCreazione` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `DataModifica` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`ModuloCodice`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE TABLE `aziende_moduli` (
  `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `AziendeId` INT NOT NULL,
  `ModuloCodice` VARCHAR(64) NOT NULL DEFAULT '',
  `DirittoUso` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `LicenzaInizio` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00',
  `LicenzaFine` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00',
  `StatoContrattuale` VARCHAR(32) NOT NULL DEFAULT '',
  `DataCreazione` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `DataModifica` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UtentiIdModifica` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_azienda_modulo` (`AziendeId`, `ModuloCodice`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
