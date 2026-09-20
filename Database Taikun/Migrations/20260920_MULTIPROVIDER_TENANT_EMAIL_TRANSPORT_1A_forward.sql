-- MULTIPROVIDER-TENANT-EMAIL-CONFIG-CONTRACT-REV1 - idempotent schema contract
-- Creates one shared profile table per explicitly authorized KeepStore database.
-- It copies no legacy values or secrets, creates no profile, enables no tenant,
-- and sends no message. Run only after a fully OK preflight and a backup.

DELIMITER $$
DROP PROCEDURE IF EXISTS `__ks_email_transport_forward_guard`$$
CREATE PROCEDURE `__ks_email_transport_forward_guard`()
SQL SECURITY INVOKER
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.TABLES
                 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport') THEN
    CREATE TABLE `aziende_email_transport` (
      `EmailTransportId` bigint unsigned NOT NULL AUTO_INCREMENT,
      `AziendeId` int NOT NULL,
      `Purpose` varchar(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `ProviderKind` varchar(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `Host` varchar(253) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
      `Port` smallint unsigned NOT NULL,
      `SecurityMode` varchar(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `AuthenticationMode` varchar(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `Username` varchar(254) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
      `CredentialReference` varchar(512) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `FromAddress` varchar(254) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
      `FromDisplayName` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
      `ReplyToAddress` varchar(254) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
      `EnvelopeFromAddress` varchar(254) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
      `TimeoutSeconds` smallint unsigned NOT NULL DEFAULT 30,
      `Enabled` tinyint(1) NOT NULL DEFAULT 0,
      `VerificationStatus` varchar(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'NOT_VERIFIED',
      `LastVerifiedAtUtc` datetime(6) DEFAULT NULL,
      `LastVerificationCode` varchar(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
      `CreatedAtUtc` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      `UpdatedAtUtc` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
      PRIMARY KEY (`EmailTransportId`),
      UNIQUE KEY `UX_aziende_email_transport_owner_purpose` (`AziendeId`,`Purpose`),
      CONSTRAINT `FK_aziende_email_transport_azienda`
        FOREIGN KEY (`AziendeId`) REFERENCES `aziende` (`id`)
        ON UPDATE CASCADE ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      COMMENT='KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v2';
  ELSEIF NOT (
      (SELECT ENGINE FROM information_schema.TABLES
       WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')='InnoDB'
      AND (SELECT TABLE_COMMENT FROM information_schema.TABLES
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')=
          'KeepStore MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v2'
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport')=21
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
             AND COLUMN_NAME IN ('EmailTransportId','AziendeId','Purpose','ProviderKind','Host','Port',
                                 'SecurityMode','AuthenticationMode','Username','CredentialReference',
                                 'FromAddress','FromDisplayName','ReplyToAddress','EnvelopeFromAddress',
                                 'TimeoutSeconds','Enabled','VerificationStatus','LastVerifiedAtUtc',
                                 'LastVerificationCode','CreatedAtUtc','UpdatedAtUtc'))=21
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
             AND (
                  (COLUMN_NAME='EmailTransportId' AND COLUMN_TYPE='bigint unsigned' AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
               OR (COLUMN_NAME='AziendeId' AND COLUMN_TYPE='int' AND IS_NULLABLE='NO')
               OR (COLUMN_NAME='Purpose' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
               OR (COLUMN_NAME='ProviderKind' AND COLUMN_TYPE='varchar(32)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
               OR (COLUMN_NAME='Host' AND COLUMN_TYPE='varchar(253)' AND IS_NULLABLE='NO' AND CHARACTER_SET_NAME='ascii')
               OR (COLUMN_NAME='Port' AND COLUMN_TYPE='smallint unsigned' AND IS_NULLABLE='NO')
               OR (COLUMN_NAME='SecurityMode' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
               OR (COLUMN_NAME='AuthenticationMode' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
               OR (COLUMN_NAME='Username' AND COLUMN_TYPE='varchar(254)' AND IS_NULLABLE='NO' AND COLLATION_NAME='utf8mb4_bin')
               OR (COLUMN_NAME='CredentialReference' AND COLUMN_TYPE='varchar(512)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
               OR (COLUMN_NAME='FromAddress' AND COLUMN_TYPE='varchar(254)' AND IS_NULLABLE='NO' AND COLLATION_NAME='utf8mb4_bin')
               OR (COLUMN_NAME='FromDisplayName' AND COLUMN_TYPE='varchar(255)' AND IS_NULLABLE='NO' AND COLLATION_NAME='utf8mb4_unicode_ci')
               OR (COLUMN_NAME='ReplyToAddress' AND COLUMN_TYPE='varchar(254)' AND IS_NULLABLE='YES' AND COLLATION_NAME='utf8mb4_bin')
               OR (COLUMN_NAME='EnvelopeFromAddress' AND COLUMN_TYPE='varchar(254)' AND IS_NULLABLE='YES' AND COLLATION_NAME='utf8mb4_bin')
               OR (COLUMN_NAME='TimeoutSeconds' AND COLUMN_TYPE='smallint unsigned' AND IS_NULLABLE='NO' AND COLUMN_DEFAULT='30')
               OR (COLUMN_NAME='Enabled' AND COLUMN_TYPE='tinyint(1)' AND IS_NULLABLE='NO' AND COLUMN_DEFAULT='0')
               OR (COLUMN_NAME='VerificationStatus' AND COLUMN_TYPE='varchar(24)' AND IS_NULLABLE='NO' AND COLUMN_DEFAULT='NOT_VERIFIED' AND COLLATION_NAME='ascii_bin')
               OR (COLUMN_NAME='LastVerifiedAtUtc' AND COLUMN_TYPE='datetime(6)' AND IS_NULLABLE='YES')
               OR (COLUMN_NAME='LastVerificationCode' AND COLUMN_TYPE='varchar(64)' AND IS_NULLABLE='YES' AND COLLATION_NAME='ascii_bin')
               OR (COLUMN_NAME='CreatedAtUtc' AND COLUMN_TYPE='datetime(6)' AND IS_NULLABLE='NO')
               OR (COLUMN_NAME='UpdatedAtUtc' AND COLUMN_TYPE='datetime(6)' AND IS_NULLABLE='NO' AND EXTRA LIKE '%on update CURRENT_TIMESTAMP(6)%')
             ))=21
      AND (SELECT COUNT(*) FROM information_schema.STATISTICS
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
             AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)=1
      AND EXISTS (SELECT 1 FROM information_schema.STATISTICS
                  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                    AND INDEX_NAME='PRIMARY' AND COLUMN_NAME='EmailTransportId'
                    AND SEQ_IN_INDEX=1 AND NON_UNIQUE=0)
      AND (SELECT COUNT(*) FROM information_schema.STATISTICS
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
             AND INDEX_NAME='UX_aziende_email_transport_owner_purpose')=2
      AND (SELECT COUNT(*) FROM information_schema.STATISTICS
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
             AND INDEX_NAME='UX_aziende_email_transport_owner_purpose'
             AND NON_UNIQUE=0
             AND ((SEQ_IN_INDEX=1 AND COLUMN_NAME='AziendeId')
                  OR (SEQ_IN_INDEX=2 AND COLUMN_NAME='Purpose')))=2
      AND EXISTS (SELECT 1 FROM information_schema.KEY_COLUMN_USAGE
                  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
                    AND CONSTRAINT_NAME='FK_aziende_email_transport_azienda'
                    AND COLUMN_NAME='AziendeId'
                    AND REFERENCED_TABLE_NAME='aziende' AND REFERENCED_COLUMN_NAME='id')
      AND (SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
           WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'
             AND CONSTRAINT_NAME='FK_aziende_email_transport_azienda')=1
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='EMAIL_TRANSPORT_PROFILE_SCHEMA_CONFLICT';
  END IF;
END$$
CALL `__ks_email_transport_forward_guard`()$$
DROP PROCEDURE `__ks_email_transport_forward_guard`$$
DELIMITER ;
