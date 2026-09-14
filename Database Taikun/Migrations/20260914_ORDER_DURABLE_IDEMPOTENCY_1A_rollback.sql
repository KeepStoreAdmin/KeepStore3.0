-- ORDER-DURABLE-IDEMPOTENCY-1A - guarded rollback
-- Execute only after rollback_preflight returned OK.

DELIMITER $$
DROP PROCEDURE IF EXISTS `__ks_order_idempotency_rollback_guard`$$
CREATE PROCEDURE `__ks_order_idempotency_rollback_guard`()
SQL SECURITY INVOKER
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
             WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordini_web_idempotenza') THEN
    IF EXISTS (SELECT 1 FROM `ordini_web_idempotenza` LIMIT 1) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ORDER_IDEMPOTENCY_ROLLBACK_HAS_HISTORY';
    ELSE
      DROP TABLE `ordini_web_idempotenza`;
    END IF;
  END IF;
END$$
CALL `__ks_order_idempotency_rollback_guard`()$$
DROP PROCEDURE `__ks_order_idempotency_rollback_guard`$$
DELIMITER ;
