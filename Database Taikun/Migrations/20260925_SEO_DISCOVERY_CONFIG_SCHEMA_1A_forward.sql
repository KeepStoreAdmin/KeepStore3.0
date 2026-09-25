-- SEO-DISCOVERY-CONFIG-SCHEMA-1A REV2 / SOLO SEO AVANZATA / MySQL 8.0.42.
-- DRAFT NON INSTALLATO, NON PRONTO AL ROLLOUT. Non eseguire in questo task.
-- Il Core mantiene canonical, robots, sitemap e SEO tecnica anche senza modulo vendibile.
-- Richiede preflight OK, review MySQL/ambiente e allowlist Product Owner futura.
-- CREATE senza IF NOT EXISTS; non migra dati legacy, account o credenziali.

CREATE TABLE `aziende_seo` (
  `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `AziendeId` INT NOT NULL,
  `ConfigVersion` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  `RobotsMode` VARCHAR(32) NOT NULL DEFAULT '',
  `LinguaDefault` VARCHAR(16) NOT NULL DEFAULT '',
  `PaeseDefault` CHAR(2) NOT NULL DEFAULT '',
  `HomeTitleOverride` TEXT NOT NULL DEFAULT (''),
  `HomeMetaDescriptionOverride` TEXT NOT NULL DEFAULT (''),
  `SocialImageOverride` TEXT NOT NULL DEFAULT (''),
  `IndexNowEnabled` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `IndexNowKey` VARCHAR(128) NOT NULL DEFAULT '',
  `IndexNowKeyLocation` TEXT NOT NULL DEFAULT (''),
  `BingWebmasterSiteUrl` TEXT NOT NULL DEFAULT (''),
  `BingWebmasterVerificationMethod` VARCHAR(32) NOT NULL DEFAULT '',
  `BingWebmasterVerificationToken` TEXT NOT NULL DEFAULT (''),
  `BingWebmasterApiKeyEnc` TEXT NOT NULL DEFAULT (''),
  `BingOAuthClientId` VARCHAR(255) NOT NULL DEFAULT '',
  `BingOAuthClientSecretEnc` TEXT NOT NULL DEFAULT (''),
  `BingOAuthAccessTokenEnc` TEXT NOT NULL DEFAULT (''),
  `BingOAuthRefreshTokenEnc` TEXT NOT NULL DEFAULT (''),
  `BingOAuthScopes` TEXT NOT NULL DEFAULT (''),
  `BingOAuthAccessTokenExpiresAt` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00',
  `BingOAuthRefreshTokenExpiresAt` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00',
  `BingOAuthRedirectUri` TEXT NOT NULL DEFAULT (''),
  `SecretsCryptoVersion` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `SecretsKeyId` VARCHAR(128) NOT NULL DEFAULT '',
  `DataCreazione` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `DataModifica` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UtentiIdModifica` INT NOT NULL DEFAULT 0,
  `NoteInterne` TEXT NOT NULL DEFAULT (''),
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_aziende_seo_aziende` (`AziendeId`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- Solo righe vuote/default del modulo SEO. Nessuna copia dei quattro campi legacy.
INSERT INTO `aziende_seo` (`AziendeId`)
SELECT `id` FROM `aziende`;
