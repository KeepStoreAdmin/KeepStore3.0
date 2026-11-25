-- EXPORT-FEED-DB-1A (verify, SOLA LETTURA). Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento.
-- Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini, account o DEFINER (nessuna routine, nessun trigger).
-- Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito per quel database. Mai --force.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa
-- (la sessione conserva variabili e modalita). Anche se l'esecuzione continuasse dopo un errore, ogni passo si autodecide dallo stato reale
-- di information_schema e ognuno e protetto da @ks_go: il forward si puo rilanciare dopo qualunque interruzione.
-- Serve MySQL 8.0.19 o successivo (CHECK applicato, REGEXP_LIKE); non MariaDB. Si ferma se il log binario e attivo in formato STATEMENT.
-- Ogni riga deve avere Esito OK; l'ultima riga EXPORT_FEED_DB_VERIFY_OK compare solo se tutto e OK, altrimenti errore deliberato.

SELECT 'DATABASE_SELECTED' AS Controllo, CASE WHEN DATABASE() IS NOT NULL AND DATABASE() <> '' THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_opt = (SELECT COUNT(*) FROM (
  SELECT 'Separatore' AS n, 'varchar(5)' AS t, '|' AS col_default, 'utf8mb4_0900_ai_ci' AS co
  UNION ALL SELECT 'DelimitatoreTesto' AS n, 'varchar(1)' AS t, '' AS col_default, 'utf8mb4_0900_ai_ci' AS co
  UNION ALL SELECT 'Codifica' AS n, 'varchar(10)' AS t, 'utf-8' AS col_default, 'utf8mb4_0900_ai_ci' AS co
  UNION ALL SELECT 'SeparatoreDecimale' AS n, 'varchar(1)' AS t, '.' AS col_default, 'utf8mb4_0900_ai_ci' AS co
  UNION ALL SELECT 'Intestazione' AS n, 'int' AS t, '1' AS col_default, NULL AS co
  UNION ALL SELECT 'XmlRadice' AS n, 'varchar(40)' AS t, 'prodotti' AS col_default, 'utf8mb4_0900_ai_ci' AS co
  UNION ALL SELECT 'XmlElemento' AS n, 'varchar(40)' AS t, 'prodotto' AS col_default, 'utf8mb4_0900_ai_ci' AS co
  UNION ALL SELECT 'TogliHtml' AS n, 'int' AS t, '1' AS col_default, NULL AS co
  UNION ALL SELECT 'MinutiCache' AS n, 'int' AS t, '60' AS col_default, NULL AS co
  UNION ALL SELECT 'ParolaDisponibile' AS n, 'varchar(40)' AS t, 'Disponibile' AS col_default, 'utf8mb4_0900_ai_ci' AS co
  UNION ALL SELECT 'ParolaInArrivo' AS n, 'varchar(40)' AS t, 'In Arrivo' AS col_default, 'utf8mb4_0900_ai_ci' AS co
  UNION ALL SELECT 'ParolaNonDisponibile' AS n, 'varchar(40)' AS t, 'Non Disponibile' AS col_default, 'utf8mb4_0900_ai_ci' AS co
  UNION ALL SELECT 'SenzaImmagine' AS n, 'int' AS t, '0' AS col_default, NULL AS co
  UNION ALL SELECT 'SenzaEan' AS n, 'int' AS t, '0' AS col_default, NULL AS co
  UNION ALL SELECT 'PrezzoZero' AS n, 'int' AS t, '1' AS col_default, NULL AS co
) e JOIN information_schema.COLUMNS c ON CONVERT(c.COLUMN_NAME USING utf8mb4) COLLATE utf8mb4_bin = CONVERT(e.n USING utf8mb4) COLLATE utf8mb4_bin
  AND c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = 'export'
  AND CONVERT(c.COLUMN_TYPE USING utf8mb4) COLLATE utf8mb4_bin = CONVERT(e.t USING utf8mb4) COLLATE utf8mb4_bin
  AND c.IS_NULLABLE = 'NO'
  AND CONVERT(c.COLUMN_DEFAULT USING utf8mb4) COLLATE utf8mb4_bin <=> CONVERT(e.col_default USING utf8mb4) COLLATE utf8mb4_bin
  AND CONVERT(c.COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin <=> CONVERT(e.co USING utf8mb4) COLLATE utf8mb4_bin);
SELECT 'OPZIONI_TIPO_PREDEFINITO_COLLAZIONE' AS Controllo, CASE WHEN @ks_v_opt = 15 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_tok = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'TokenAccesso'
  AND COLUMN_TYPE = 'varchar(64)' AND CHARACTER_SET_NAME = 'ascii' AND COLLATION_NAME = 'ascii_bin' AND IS_NULLABLE = 'NO' AND EXTRA LIKE '%DEFAULT_GENERATED%');
SELECT 'CODICE_COLONNA_ASCII_BIN_NON_NULLA_PREDEFINITO_DEL_DATABASE' AS Controllo, CASE WHEN @ks_v_tok = 1 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_uk = (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND INDEX_NAME = 'uk_export_token_accesso' AND COLUMN_NAME = 'TokenAccesso' AND NON_UNIQUE = 0 AND SEQ_IN_INDEX = 1);
SELECT 'CODICE_INDICE_UNICO' AS Controllo, CASE WHEN @ks_v_uk = 1 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_ck = (SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'ck_export_token_accesso');
SELECT 'CODICE_VINCOLO_CHECK' AS Controllo, CASE WHEN @ks_v_ck = 1 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_badtok = (SELECT COUNT(*) FROM `export` WHERE CHAR_LENGTH(TokenAccesso) <> 48 OR TokenAccesso NOT REGEXP '^[0-9A-F]+$');
SELECT 'CODICI_LUNGHEZZA_E_FORMATO' AS Controllo, CASE WHEN @ks_v_badtok = 0 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_dist = (SELECT COUNT(*) - COUNT(DISTINCT TokenAccesso) FROM `export`);
SELECT 'CODICI_DISTINTI' AS Controllo, CASE WHEN @ks_v_dist = 0 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_stato = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_stato'
  AND ((COLUMN_NAME = 'ExportId' AND COLUMN_TYPE = 'int' AND IS_NULLABLE = 'NO' AND COLUMN_KEY = 'PRI')
    OR (COLUMN_NAME IN ('UltimaGenerazioneUtc', 'UltimaRichiestaUtc') AND COLUMN_TYPE = 'datetime' AND IS_NULLABLE = 'YES')
    OR (COLUMN_NAME IN ('UltimeRighe', 'UltimeScartate') AND COLUMN_TYPE = 'int' AND IS_NULLABLE = 'YES')
    OR (COLUMN_NAME = 'UltimoErrore' AND COLUMN_TYPE = 'varchar(200)' AND IS_NULLABLE = 'YES' AND COLLATION_NAME = 'utf8mb4_0900_ai_ci')));
SELECT 'STATO_COLONNE_6' AS Controllo, CASE WHEN @ks_v_stato = 6 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_stato') = 6 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_fk1 = (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'export_stato' AND REFERENCED_TABLE_NAME = 'export' AND DELETE_RULE = 'CASCADE');
SELECT 'STATO_CHIAVE_ESTERNA_CASCATA' AS Controllo, CASE WHEN @ks_v_fk1 = 1 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_col = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne'
  AND ((COLUMN_NAME = 'Id' AND COLUMN_TYPE = 'int' AND IS_NULLABLE = 'NO' AND COLUMN_KEY = 'PRI' AND EXTRA LIKE '%auto_increment%')
    OR (COLUMN_NAME IN ('ExportId', 'Posizione') AND COLUMN_TYPE = 'int' AND IS_NULLABLE = 'NO')
    OR (COLUMN_NAME = 'TitoloColonna' AND COLUMN_TYPE = 'varchar(60)' AND IS_NULLABLE = 'NO' AND COLLATION_NAME = 'utf8mb4_0900_ai_ci')
    OR (COLUMN_NAME IN ('Campo', 'Prefisso', 'Suffisso') AND COLUMN_TYPE = 'varchar(40)' AND IS_NULLABLE = 'NO' AND COLLATION_NAME = 'utf8mb4_0900_ai_ci')
    OR (COLUMN_NAME IN ('ValoreFisso', 'SeVuoto') AND COLUMN_TYPE = 'varchar(100)' AND IS_NULLABLE = 'NO' AND COLLATION_NAME = 'utf8mb4_0900_ai_ci')
    OR (COLUMN_NAME = 'MassimoCaratteri' AND COLUMN_TYPE = 'int' AND IS_NULLABLE = 'YES')));
SELECT 'COLONNE_COLONNE_10' AS Controllo, CASE WHEN @ks_v_col = 10 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne') = 10 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_pos = (SELECT GROUP_CONCAT(CONCAT(SEQ_IN_INDEX, ':', COLUMN_NAME, ':', NON_UNIQUE) ORDER BY SEQ_IN_INDEX SEPARATOR '|') FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne' AND INDEX_NAME = 'uk_export_colonne_posizione');
SELECT 'COLONNE_POSIZIONE_UNICA' AS Controllo, CASE WHEN @ks_v_pos = '1:ExportId:0|2:Posizione:0' THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_v_fk2 = (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne' AND REFERENCED_TABLE_NAME = 'export' AND DELETE_RULE = 'CASCADE');
SELECT 'COLONNE_CHIAVE_ESTERNA_CASCATA' AS Controllo, CASE WHEN @ks_v_fk2 = 1 THEN 'OK' ELSE 'STOP' END AS Esito;
SET @ks_s = IF(@ks_v_opt = 15 AND @ks_v_tok = 1 AND @ks_v_uk = 1 AND @ks_v_ck = 1 AND @ks_v_badtok = 0 AND @ks_v_dist = 0 AND @ks_v_stato = 6 AND @ks_v_fk1 = 1 AND @ks_v_col = 10 AND @ks_v_pos = '1:ExportId:0|2:Posizione:0' AND @ks_v_fk2 = 1,
  'SELECT ''EXPORT_FEED_DB_VERIFY_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_VERIFY');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
