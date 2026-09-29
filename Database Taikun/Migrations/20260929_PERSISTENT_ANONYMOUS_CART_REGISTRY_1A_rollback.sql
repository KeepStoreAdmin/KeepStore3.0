-- ESEGUIRE SOLO DOPO ROLLBACK PREFLIGHT OK E AUTORIZZAZIONE CHATGPT.
-- Fermarsi se un solo controllo del rollback_preflight non e OK.
-- Confermare runtime pre-ksc2, registry vuota, zero righe ksc2 e backup.
-- Registry non vuota, ksc2 presente, schema sconosciuto o runtime ksc2 attivo:
-- STOP e analisi manuale; nessun recovery automatico.
-- DDL con commit impliciti: l'eventuale ALTER e il DROP non sono atomici.
-- Le guardie sotto ripetono i controlli dei dati e dello schema; un valore NULL
-- non e SQL eseguibile e fa fallire PREPARE. Fermarsi al primo errore SQL.

SET @ks_pa_rollback_state = (
  SELECT CASE
           WHEN COUNT(*) = 1 AND MAX(COLUMN_TYPE) = 'varchar(50)'
             AND MAX(CHARACTER_SET_NAME) = 'utf8mb4'
             AND MAX(IS_NULLABLE) = 'YES' AND MAX(COLUMN_DEFAULT) IS NULL
             AND MAX(COLLATION_NAME) = 'utf8mb4_0900_ai_ci'
             THEN 'PARTIAL_REGISTRY_ONLY'
           WHEN COUNT(*) = 1 AND MAX(COLUMN_TYPE) = 'varchar(50)'
             AND MAX(CHARACTER_SET_NAME) = 'utf8mb4'
             AND MAX(IS_NULLABLE) = 'YES' AND MAX(COLUMN_DEFAULT) IS NULL
             AND MAX(COLLATION_NAME) = 'utf8mb4_0900_bin'
             THEN 'FULL_FOUNDATION_PRE_RUNTIME'
           ELSE 'STOP'
         END
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello'
    AND COLUMN_NAME = 'SessionId'
);

SET @ks_pa_registry_empty = (SELECT COUNT(*) = 0 FROM `carrello_anonimo_persistenza`);
SET @ks_pa_no_ksc2 = (
  SELECT COALESCE(SUM(`SessionId` IS NOT NULL AND `SessionId` <> ''
                      AND BINARY LEFT(`SessionId`, 5) = BINARY 'ksc2_'), 0) = 0
  FROM `carrello`
);

-- FULL: copy back; PARTIAL: DO 0, senza copia inutile. Ogni altro stato: STOP.
SET @ks_pa_rollback_sql = CASE
  WHEN @ks_pa_registry_empty = 1 AND @ks_pa_no_ksc2 = 1
       AND @ks_pa_rollback_state = 'FULL_FOUNDATION_PRE_RUNTIME'
    THEN 'ALTER TABLE `carrello` MODIFY COLUMN `SessionId` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL, ALGORITHM=COPY, LOCK=SHARED'
  WHEN @ks_pa_registry_empty = 1 AND @ks_pa_no_ksc2 = 1
       AND @ks_pa_rollback_state = 'PARTIAL_REGISTRY_ONLY'
    THEN 'DO 0'
  ELSE NULL
END;
PREPARE ks_pa_rollback_stmt FROM @ks_pa_rollback_sql;
EXECUTE ks_pa_rollback_stmt;
DEALLOCATE PREPARE ks_pa_rollback_stmt;

-- Recheck after the optional copy: do not drop a registry if carrello remains
-- migrated or data appeared. DROP is plain (no IF EXISTS), only when safe.
SET @ks_pa_drop_sql = CASE
  WHEN (SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'carrello'
          AND COLUMN_NAME = 'SessionId' AND COLUMN_TYPE = 'varchar(50)'
          AND CHARACTER_SET_NAME = 'utf8mb4' AND COLLATION_NAME = 'utf8mb4_0900_ai_ci'
          AND IS_NULLABLE = 'YES' AND COLUMN_DEFAULT IS NULL) = 1
       AND (SELECT COUNT(*) FROM `carrello_anonimo_persistenza`) = 0
       AND (SELECT COALESCE(SUM(`SessionId` IS NOT NULL AND `SessionId` <> ''
                                AND BINARY LEFT(`SessionId`, 5) = BINARY 'ksc2_'), 0)
            FROM `carrello`) = 0
    THEN 'DROP TABLE `carrello_anonimo_persistenza`'
  ELSE NULL
END;
PREPARE ks_pa_drop_stmt FROM @ks_pa_drop_sql;
EXECUTE ks_pa_drop_stmt;
DEALLOCATE PREPARE ks_pa_drop_stmt;

SET @ks_pa_rollback_state = NULL, @ks_pa_registry_empty = NULL,
    @ks_pa_no_ksc2 = NULL, @ks_pa_rollback_sql = NULL, @ks_pa_drop_sql = NULL;
