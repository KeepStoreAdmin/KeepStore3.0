-- REV2 MODULAR-ARCHITECTURE-FREEZE / TIKTOK SHOP SELLER / MySQL 8.0.42.
-- DRAFT NON INSTALLATO E NON PRONTO AL ROLLOUT: non eseguire in questo task.
-- Richiede futuro gate MySQL/ambiente, preflight/verify read-only, backup e allowlist Product Owner.
-- Nessun USE, nome database cliente, seed, grant attivo o copia di valori legacy.
-- Configurazione account/shop 1:N per AziendeId; separata da TikTok Social, Ads, Creator e Merchant legacy.
-- Environment e ShopId non vuoti prima del salvataggio futuro; UNIQUE evita lo stesso shop duplicato nel tenant.
-- Nessuna tabella prodotto/ordine/listing o token reale; Product/Offer resta nel Core.

CREATE TABLE `aziende_tiktok_shop` (
  `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `AziendeId` INT NOT NULL,
  `ConfigVersion` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  `TikTokShopAbilitato` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `TikTokShopAppKey` VARCHAR(128) NOT NULL DEFAULT '',
  `TikTokShopAppSecretEnc` TEXT NOT NULL DEFAULT (''),
  `TikTokShopServiceId` VARCHAR(128) NOT NULL DEFAULT '',
  `TikTokShopSellerOpenId` VARCHAR(128) NOT NULL DEFAULT '',
  `TikTokShopShopId` VARCHAR(128) NOT NULL DEFAULT '',
  `TikTokShopShopCipher` VARCHAR(255) NOT NULL DEFAULT '',
  `TikTokShopRegion` VARCHAR(32) NOT NULL DEFAULT '',
  `TikTokShopEnvironment` VARCHAR(16) NOT NULL DEFAULT '',
  `TikTokShopAccessTokenEnc` TEXT NOT NULL DEFAULT (''),
  `TikTokShopRefreshTokenEnc` TEXT NOT NULL DEFAULT (''),
  `TikTokShopGrantedScopes` TEXT NOT NULL DEFAULT (''),
  `TikTokShopAccessTokenExpiresAt` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00',
  `TikTokShopRefreshTokenExpiresAt` DATETIME NOT NULL DEFAULT '1000-01-01 00:00:00',
  `SecretsCryptoVersion` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `SecretsKeyId` VARCHAR(128) NOT NULL DEFAULT '',
  `DataCreazione` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `DataModifica` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UtentiIdModifica` INT NOT NULL DEFAULT 0,
  `NoteInterne` TEXT NOT NULL DEFAULT (''),
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_tiktok_shop_tenant` (`AziendeId`, `TikTokShopEnvironment`, `TikTokShopShopId`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
