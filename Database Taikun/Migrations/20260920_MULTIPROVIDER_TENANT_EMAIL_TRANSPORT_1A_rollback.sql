-- MULTIPROVIDER-TENANT-EMAIL-TRANSPORT-1A - guarded and idempotent rollback
-- Execute only after rollback_preflight returned OK or ALREADY_ABSENT.

DELIMITER $$
DROP PROCEDURE IF EXISTS `__ks_email_transport_profile_rollback_guard`$$
CREATE PROCEDURE `__ks_email_transport_profile_rollback_guard`()
SQL SECURITY INVOKER
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
             WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport') THEN
    IF EXISTS (SELECT 1 FROM `aziende_email_transport` LIMIT 1) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='EMAIL_TRANSPORT_ROLLBACK_HAS_PROFILES';
    ELSE
      DROP TABLE `aziende_email_transport`;
    END IF;
  END IF;
END$$
CALL `__ks_email_transport_profile_rollback_guard`()$$
DROP PROCEDURE `__ks_email_transport_profile_rollback_guard`$$
DELIMITER ;
