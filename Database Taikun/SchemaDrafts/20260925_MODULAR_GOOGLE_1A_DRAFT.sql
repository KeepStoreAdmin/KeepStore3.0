-- REV2 MODULAR-ARCHITECTURE-FREEZE / GOOGLE / MySQL 8.0.42.
-- DRAFT NON INSTALLATO E NON PRONTO AL ROLLOUT: non eseguire in questo task.
-- Richiede futuro gate MySQL/ambiente, preflight/verify read-only, backup e allowlist Product Owner.
-- Nessun USE, nome database cliente, seed, grant attivo o copia di valori legacy.
-- aziende_google 1:1 = app/config; grant e account 1:N per azienda.
-- GrantCode, ServiceCode, AccountCode e PrincipalRef devono essere validati non vuoti dal futuro gestionale.
-- Un grant non e automaticamente autorizzato per tutti i servizi: scope, principal e consent si verificano per servizio.
-- Nessuna FK su aziende(id) a causa della PK legacy composta; riferimenti child sono logici in questo draft.

CREATE TABLE `aziende_google` (
  `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `AziendeId` INT NOT NULL,
  `ConfigVersion` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  `GoogleCloudProjectId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleOAuthClientId` VARCHAR(255) NOT NULL DEFAULT '',
  `GoogleOAuthClientSecretEnc` TEXT NOT NULL DEFAULT (''),
  `GoogleOAuthRedirectUri` TEXT NOT NULL DEFAULT (''),
  `GoogleMerchantId` VARCHAR(128) NOT NULL DEFAULT '',
  `SecretsCryptoVersion` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `SecretsKeyId` VARCHAR(128) NOT NULL DEFAULT '',
  `DataCreazione` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `DataModifica` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UtentiIdModifica` INT NOT NULL DEFAULT 0,
  `NoteInterne` TEXT NOT NULL DEFAULT (''),
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_aziende_google_azienda` (`AziendeId`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `aziende_google_grant` (
  `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `AziendeId` INT NOT NULL,
  `GrantCode` VARCHAR(64) NOT NULL DEFAULT '',
  `ServiceCode` VARCHAR(32) NOT NULL DEFAULT '',
  `PrincipalRef` VARCHAR(255) NOT NULL DEFAULT '',
  `GoogleOAuthAccessTokenEnc` TEXT NOT NULL DEFAULT (''),
  `GoogleOAuthRefreshTokenEnc` TEXT NOT NULL DEFAULT (''),
  `GoogleOAuthScopes` TEXT NOT NULL DEFAULT (''),
  `GoogleOAuthAccessTokenExpiresAt` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00',
  `GoogleOAuthRefreshTokenExpiresAt` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00',
  `GoogleServiceAccountEmail` VARCHAR(255) NOT NULL DEFAULT '',
  `GoogleServiceAccountPrivateJsonEnc` LONGTEXT NOT NULL DEFAULT (''),
  `SecretsCryptoVersion` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `SecretsKeyId` VARCHAR(128) NOT NULL DEFAULT '',
  `DataCreazione` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `DataModifica` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UtentiIdModifica` INT NOT NULL DEFAULT 0,
  `NoteInterne` TEXT NOT NULL DEFAULT (''),
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_google_grant` (`AziendeId`, `GrantCode`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `aziende_google_account` (
  `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `AziendeId` INT NOT NULL,
  `ServiceCode` VARCHAR(32) NOT NULL DEFAULT '',
  `AccountCode` VARCHAR(128) NOT NULL DEFAULT '',
  `GrantCode` VARCHAR(64) NOT NULL DEFAULT '',
  `GoogleSearchConsoleProperty` VARCHAR(255) NOT NULL DEFAULT '',
  `GoogleSiteVerificationMethod` VARCHAR(32) NOT NULL DEFAULT '',
  `GoogleSiteVerificationToken` TEXT NOT NULL DEFAULT (''),
  `GoogleMerchantProductDataSourceId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleMerchantPromotionDataSourceId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleMerchantProductReviewDataSourceId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleMerchantMerchantReviewDataSourceId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAnalyticsAccountId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAnalyticsPropertyId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAnalyticsWebDataStreamId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAnalyticsMeasurementId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAnalyticsMeasurementProtocolSecretEnc` TEXT NOT NULL DEFAULT (''),
  `GoogleTagManagerAccountId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleTagManagerContainerId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleTagManagerPublicId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAdsCustomerId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAdsManagerCustomerId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAdsConversionActionId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAdsConversionId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleAdsConversionLabel` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleBusinessProfileAccountId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleBusinessProfileLocationId` VARCHAR(128) NOT NULL DEFAULT '',
  `GoogleBusinessProfilePlaceId` VARCHAR(128) NOT NULL DEFAULT '',
  `YouTubeChannelId` VARCHAR(128) NOT NULL DEFAULT '',
  `SecretsCryptoVersion` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `SecretsKeyId` VARCHAR(128) NOT NULL DEFAULT '',
  `DataCreazione` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `DataModifica` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UtentiIdModifica` INT NOT NULL DEFAULT 0,
  `NoteInterne` TEXT NOT NULL DEFAULT (''),
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_google_account` (`AziendeId`, `ServiceCode`, `AccountCode`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
