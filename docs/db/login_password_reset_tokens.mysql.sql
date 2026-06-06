-- KeepStore 3.0 - reset password token table proposal
-- Task: REMIND-RESET-DB-SCRIPT-1A
--
-- Purpose:
--   Prepare the future MySQL table used by the tokenized password reset flow.
--
-- Execution guardrails:
--   - Execute only in the selected customer/company operational database.
--   - Example customer database name: taikun.
--   - Do not execute in the connessioni registry database.
--   - Do not execute in the city_registry database.
--   - Execute only after a verified database backup.
--   - Verify the result with SHOW TABLES and SHOW CREATE TABLE.
--   - Do not manually insert real tokens or user data into this table.
--
-- Scope:
--   - Creates only login_password_reset_tokens if it is missing.
--   - Does not provision database containers or switch database context.
--   - Does not create mandatory foreign keys in phase 1.
--   - Does not modify login.Password.
--   - Does not modify login.DataPassword.
--   - Does not modify aziende.ScadenzaPassword.
--
-- Security notes:
--   - LoginId is a logical indexed reference to login.id.
--   - Clear tokens must exist only in the future reset email link.
--   - The database stores only TokenHash.
--   - Recommended future token duration: 30 minutes. This script only
--     prepares ExpiresAt; application code will set the actual value.
--
-- Compatibility note:
--   - The table uses DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci.
--   - If a target customer database uses an older MySQL version or a different
--     standard collation, Vincenzo should adapt charset/collation before
--     executing the script.
--   - Indexes are defined inside CREATE TABLE IF NOT EXISTS. If the table
--     already exists with a different structure, review manually; do not use
--     destructive automatic workarounds.

CREATE TABLE IF NOT EXISTS login_password_reset_tokens (
    id INT NOT NULL AUTO_INCREMENT,
    LoginId INT NOT NULL,
    TokenHash CHAR(64) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ExpiresAt DATETIME NOT NULL,
    UsedAt DATETIME NULL DEFAULT NULL,
    RevokedAt DATETIME NULL DEFAULT NULL,
    RequestIpHash CHAR(64) NULL DEFAULT NULL,
    UserAgentHash CHAR(64) NULL DEFAULT NULL,
    CreatedBy VARCHAR(50) NOT NULL DEFAULT 'web_remind',
    PRIMARY KEY (id),
    UNIQUE KEY uq_login_password_reset_tokens_tokenhash (TokenHash),
    KEY idx_login_password_reset_tokens_loginid (LoginId),
    KEY idx_login_password_reset_tokens_expiresat (ExpiresAt),
    KEY idx_login_password_reset_tokens_usedat (UsedAt),
    KEY idx_login_password_reset_tokens_loginid_expiresat (LoginId, ExpiresAt)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

-- Non-destructive verification queries.
SHOW TABLES LIKE 'login_password_reset_tokens';
SHOW CREATE TABLE login_password_reset_tokens;
SELECT COUNT(*) FROM login_password_reset_tokens;
