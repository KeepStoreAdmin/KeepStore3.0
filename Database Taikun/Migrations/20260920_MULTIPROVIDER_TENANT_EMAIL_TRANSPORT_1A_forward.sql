-- MULTIPROVIDER-TENANT-EMAIL-TRANSPORT-1A - idempotent schema proposal
-- This migration creates configuration structure only. It copies no legacy secret,
-- enables no tenant, and sends no message.
-- Execute only after explicit Product Owner authorization and a fully OK preflight.

DELIMITER $$
DROP PROCEDURE IF EXISTS `__ks_email_transport_profile_forward_guard`$$
CREATE PROCEDURE `__ks_email_transport_profile_forward_guard`()
SQL SECURITY INVOKER
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.TABLES
                 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport') THEN
    CREATE TABLE `aziende_email_transport` (
      `AziendeId` int NOT NULL,
      `ProviderKind` varchar(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `Host` varchar(255) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
      `Port` smallint unsigned NOT NULL,
      `SecurityMode` varchar(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `AuthenticationMode` varchar(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `Username` varchar(320) NOT NULL,
      `CredentialReference` varchar(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `FromAddress` varchar(320) NOT NULL,
      `FromDisplayName` varchar(255) NOT NULL,
      `ReplyToAddress` varchar(320) DEFAULT NULL,
      `EnvelopeFromAddress` varchar(320) DEFAULT NULL,
      `TimeoutSeconds` smallint unsigned NOT NULL DEFAULT 30,
      `Enabled` tinyint(1) NOT NULL DEFAULT 0,
      `VerificationStatus` varchar(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'NOT_VERIFIED',
      `LastVerifiedAtUtc` datetime(6) DEFAULT NULL,
      `LastVerificationCode` varchar(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
      `CreatedAtUtc` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      `UpdatedAtUtc` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
      PRIMARY KEY (`AziendeId`),
      CONSTRAINT `FK_aziende_email_transport_azienda`
        FOREIGN KEY (`AziendeId`) REFERENCES `aziende` (`id`)
        ON UPDATE CASCADE ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      COMMENT='KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v1';
  ELSEIF NOT (
      (SELECT ENGINE FROM information_schema.TABLES
       WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')='InnoDB'
      AND (SELECT TABLE_COMMENT FROM information_schema.TABLES
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')=
          'KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v1'
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')=19
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
             AND COLUMN_NAME IN ('AziendeId','ProviderKind','Host','Port','SecurityMode',
                                 'AuthenticationMode','Username','CredentialReference',
                                 'FromAddress','FromDisplayName','ReplyToAddress',
                                 'EnvelopeFromAddress','TimeoutSeconds','Enabled',
                                 'VerificationStatus','LastVerifiedAtUtc',
                                 'LastVerificationCode','CreatedAtUtc','UpdatedAtUtc'))=19
      AND EXISTS (SELECT 1 FROM information_schema.STATISTICS
                  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                    AND INDEX_NAME='PRIMARY' AND COLUMN_NAME='AziendeId'
                    AND SEQ_IN_INDEX=1 AND NON_UNIQUE=0)
      AND EXISTS (SELECT 1 FROM information_schema.KEY_COLUMN_USAGE
                  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                    AND COLUMN_NAME='AziendeId'
                    AND REFERENCED_TABLE_NAME='aziende' AND REFERENCED_COLUMN_NAME='id')
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='EMAIL_TRANSPORT_PROFILE_SCHEMA_CONFLICT';
  END IF;
END$$
CALL `__ks_email_transport_profile_forward_guard`()$$
DROP PROCEDURE `__ks_email_transport_profile_forward_guard`$$
DELIMITER ;
