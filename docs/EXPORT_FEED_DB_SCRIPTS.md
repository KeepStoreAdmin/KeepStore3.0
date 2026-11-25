# Script della migrazione `EXPORT-FEED-DB-1A` (quattro, nell'ordine di esecuzione)

Testo unico, identico per ogni database KeepStore. Contesto, ordine di esecuzione, significato dei campi e limiti: [EXPORT_FEED_DB_TABLES](EXPORT_FEED_DB_TABLES.md). I quattro script stanno qui, in blocchi, e non come file `.sql` del repository (il repository e pubblico e la guardia dei segreti non ammette file `.sql` nuovi senza una deroga nominale del PO): si copiano nello strumento (SQLyog) uno alla volta. `Tools/Test-ExportFeedDb.ps1` legge **questi blocchi** e li esegue sul LAB.

## 20261125_EXPORT_FEED_DB_1A_preflight.sql

```sql
-- EXPORT-FEED-DB-1A (preflight, SOLA LETTURA). Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento.
-- Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini, account o DEFINER (nessuna routine, nessun trigger).
-- Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito per quel database. Mai --force.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa
-- (la sessione conserva variabili e modalita). Anche se l'esecuzione continuasse dopo un errore, ogni passo si autodecide dallo stato reale
-- di information_schema e ognuno e protetto da @ks_go: il forward si puo rilanciare dopo qualunque interruzione.
-- Serve MySQL 8.0.19 o successivo (CHECK applicato, REGEXP_LIKE); non MariaDB. Si ferma se il log binario e attivo in formato STATEMENT.
-- Esito atteso: una riga con EXPORT_FEED_DB_PREFLIGHT_OK; qualunque STOP = errore deliberato, non procedere.

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_ck_version = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_ck_binlog = IF(@@global.log_bin = 1 AND (@@global.binlog_format = 'STATEMENT' OR @@session.binlog_format = 'STATEMENT'), 0, 1);
SET @ks_ck_export = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'ID' AND DATA_TYPE = 'int' AND COLUMN_TYPE NOT LIKE '%unsigned%' AND COLUMN_KEY = 'PRI' AND EXTRA LIKE '%auto_increment%') = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND ENGINE = 'InnoDB') = 1, 1, 0);
SET @ks_go = IF(@ks_ck_version = 1 AND @ks_ck_binlog = 1 AND @ks_ck_export = 1, 1, 0);
SELECT DATABASE() AS BaseDati, @@server_uuid AS ServerUuid, VERSION() AS Versione, @@global.log_bin AS LogBin, @@global.binlog_format AS FormatoBinlog,
       (SELECT COUNT(*) FROM `export`) AS FeedEsistenti,
       @ks_ck_version AS VersioneOk, @ks_ck_binlog AS BinlogOk, @ks_ck_export AS TabellaExportOk;
SELECT 'STATO_OGGETTI' AS Controllo,
       (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME IN ('Separatore', 'DelimitatoreTesto', 'Codifica', 'SeparatoreDecimale', 'Intestazione', 'XmlRadice', 'XmlElemento', 'TogliHtml', 'MinutiCache', 'ParolaDisponibile', 'ParolaInArrivo', 'ParolaNonDisponibile', 'SenzaImmagine', 'SenzaEan', 'PrezzoZero', 'TokenAccesso')) AS ColonneNuoveGiaPresenti_su_16,
       (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_stato', 'export_colonne')) AS TabelleNuoveGiaPresenti_su_2;
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_DB_PREFLIGHT_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_PRECONDITION');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
```

## 20261125_EXPORT_FEED_DB_1A_forward.sql

```sql
-- EXPORT-FEED-DB-1A (forward). Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento.
-- Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini, account o DEFINER (nessuna routine, nessun trigger).
-- Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito per quel database. Mai --force.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa
-- (la sessione conserva variabili e modalita). Anche se l'esecuzione continuasse dopo un errore, ogni passo si autodecide dallo stato reale
-- di information_schema e ognuno e protetto da @ks_go: il forward si puo rilanciare dopo qualunque interruzione.
-- Serve MySQL 8.0.19 o successivo (CHECK applicato, REGEXP_LIKE); non MariaDB. Si ferma se il log binario e attivo in formato STATEMENT.
-- Passi (ognuno contrassegnato da una riga '-- STEP n'; il test li usa per simulare un'interruzione dopo ciascuno):
--   1 colonne di opzione di export; 2-5 TokenAccesso (colonna NULL, predefinito, riempimento, vincoli); 6 export_stato; 7 export_colonne; 8 controllo finale.
-- Il codice del link lo crea il database (HEX(RANDOM_BYTES(24)): 48 caratteri esadecimali maiuscoli). Un solo ALTER con questo predefinito fallisce (ERROR 1674),
-- per questo il codice si crea in cinque passi; il predefinito e impostato PRIMA del riempimento, cosi una riga creata nel frattempo riceve gia il suo codice.
-- Non tocca exportcampi, export_filtri, Newexport, Modexport, Delexport: il gestionale e il sito attuali continuano a funzionare.
-- Ritorno indietro: il rollback di questa migrazione (cancella anche i codici e lo stato: chiede una conferma esplicita).

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_ck_version = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_ck_binlog = IF(@@global.log_bin = 1 AND (@@global.binlog_format = 'STATEMENT' OR @@session.binlog_format = 'STATEMENT'), 0, 1);
SET @ks_ck_export = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'ID' AND DATA_TYPE = 'int' AND COLUMN_TYPE NOT LIKE '%unsigned%' AND COLUMN_KEY = 'PRI' AND EXTRA LIKE '%auto_increment%') = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND ENGINE = 'InnoDB') = 1, 1, 0);
SET @ks_go = IF(@ks_ck_version = 1 AND @ks_ck_binlog = 1 AND @ks_ck_export = 1, 1, 0);
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_DB_FORWARD_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_PRECONDITION');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 1 OPZIONI: quindici colonne con predefinito (le routine del gestionale usano colonne nominate e non cambiano)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME IN ('Separatore', 'DelimitatoreTesto', 'Codifica', 'SeparatoreDecimale', 'Intestazione', 'XmlRadice', 'XmlElemento', 'TogliHtml', 'MinutiCache', 'ParolaDisponibile', 'ParolaInArrivo', 'ParolaNonDisponibile', 'SenzaImmagine', 'SenzaEan', 'PrezzoZero')) = 0, 'ALTER TABLE `export`
 ADD COLUMN Separatore varchar(5) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''|'',
 ADD COLUMN DelimitatoreTesto varchar(1) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '''',
 ADD COLUMN Codifica varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''utf-8'',
 ADD COLUMN SeparatoreDecimale varchar(1) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''.'',
 ADD COLUMN Intestazione int NOT NULL DEFAULT 1,
 ADD COLUMN XmlRadice varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''prodotti'',
 ADD COLUMN XmlElemento varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''prodotto'',
 ADD COLUMN TogliHtml int NOT NULL DEFAULT 1,
 ADD COLUMN MinutiCache int NOT NULL DEFAULT 60,
 ADD COLUMN ParolaDisponibile varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''Disponibile'',
 ADD COLUMN ParolaInArrivo varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''In Arrivo'',
 ADD COLUMN ParolaNonDisponibile varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''Non Disponibile'',
 ADD COLUMN SenzaImmagine int NOT NULL DEFAULT 0,
 ADD COLUMN SenzaEan int NOT NULL DEFAULT 0,
 ADD COLUMN PrezzoZero int NOT NULL DEFAULT 1', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 2 CODICE: colonna senza predefinito (NULL)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'TokenAccesso') = 0, 'ALTER TABLE `export` ADD COLUMN TokenAccesso varchar(64) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 3 CODICE: PREDEFINITO creato dal database, prima del riempimento
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'TokenAccesso' AND EXTRA NOT LIKE '%DEFAULT_GENERATED%') = 1, 'ALTER TABLE `export` ALTER COLUMN TokenAccesso SET DEFAULT (HEX(RANDOM_BYTES(24)))', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 4 CODICE: riempimento dei feed esistenti (un codice distinto per riga)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'TokenAccesso') = 1, 'UPDATE `export` SET TokenAccesso = HEX(RANDOM_BYTES(24)) WHERE ID > 0 AND (TokenAccesso IS NULL OR TokenAccesso = '''')', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 5 CODICE: non nullo, unico, formato controllato
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'TokenAccesso' AND IS_NULLABLE = 'YES') = 1, 'ALTER TABLE `export` MODIFY COLUMN TokenAccesso varchar(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (HEX(RANDOM_BYTES(24)))', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND INDEX_NAME = 'uk_export_token_accesso') = 0, 'ALTER TABLE `export` ADD UNIQUE KEY uk_export_token_accesso (TokenAccesso)', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND CONSTRAINT_NAME = 'ck_export_token_accesso') = 0, 'ALTER TABLE `export` ADD CONSTRAINT ck_export_token_accesso CHECK (CHAR_LENGTH(TokenAccesso) = 48 AND REGEXP_LIKE(TokenAccesso, ''^[0-9A-F]{48}$'', ''c''))', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 6 STATO: export_stato (scritta dal sito; la configurazione resta in sola lettura per il sito)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_stato') = 0, 'CREATE TABLE export_stato (
  ExportId int NOT NULL,
  UltimaGenerazioneUtc datetime NULL DEFAULT NULL,
  UltimaRichiestaUtc datetime NULL DEFAULT NULL,
  UltimeRighe int NULL DEFAULT NULL,
  UltimeScartate int NULL DEFAULT NULL,
  UltimoErrore varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  PRIMARY KEY (ExportId),
  CONSTRAINT fk_export_stato_export FOREIGN KEY (ExportId) REFERENCES `export` (ID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 7 COLONNE: export_colonne (le colonne del file, una riga per colonna)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne') = 0, 'CREATE TABLE export_colonne (
  Id int NOT NULL AUTO_INCREMENT,
  ExportId int NOT NULL,
  Posizione int NOT NULL,
  TitoloColonna varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '''',
  Campo varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '''',
  Prefisso varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '''',
  Suffisso varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '''',
  ValoreFisso varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '''',
  MassimoCaratteri int NULL DEFAULT NULL,
  SeVuoto varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '''',
  PRIMARY KEY (Id),
  UNIQUE KEY uk_export_colonne_posizione (ExportId, Posizione),
  CONSTRAINT fk_export_colonne_export FOREIGN KEY (ExportId) REFERENCES `export` (ID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 8 CONTROLLO FINALE minimo (il controllo completo e lo script verify)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME IN ('Separatore', 'DelimitatoreTesto', 'Codifica', 'SeparatoreDecimale', 'Intestazione', 'XmlRadice', 'XmlElemento', 'TogliHtml', 'MinutiCache', 'ParolaDisponibile', 'ParolaInArrivo', 'ParolaNonDisponibile', 'SenzaImmagine', 'SenzaEan', 'PrezzoZero', 'TokenAccesso')) = 16 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_stato', 'export_colonne')) = 2, 'SELECT ''EXPORT_FEED_DB_FORWARD_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_FORWARD');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
```

## 20261125_EXPORT_FEED_DB_1A_verify.sql

```sql
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
```

## 20261125_EXPORT_FEED_DB_1A_rollback.sql

```sql
-- EXPORT-FEED-DB-1A (rollback). Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento.
-- Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini, account o DEFINER (nessuna routine, nessun trigger).
-- Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito per quel database. Mai --force.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa
-- (la sessione conserva variabili e modalita). Anche se l'esecuzione continuasse dopo un errore, ogni passo si autodecide dallo stato reale
-- di information_schema e ognuno e protetto da @ks_go: il forward si puo rilanciare dopo qualunque interruzione.
-- Serve MySQL 8.0.19 o successivo (CHECK applicato, REGEXP_LIKE); non MariaDB. Si ferma se il log binario e attivo in formato STATEMENT.
-- RITORNO INDIETRO. Cancella export_colonne, export_stato, i codici dei link (TokenAccesso) e le quindici colonne di opzione: dati che un uso successivo avra scritto.
-- Per questo si ferma se l'operatore non scrive prima, nella STESSA scheda: SET @KeepStoreConfirmDropFeedData=1;
-- Non tocca exportcampi, export_filtri ne le routine del gestionale. Si puo rilanciare dopo qualunque interruzione (ogni passo guarda lo stato reale).

SET @ks_go = IF((@KeepStoreConfirmDropFeedData <=> 1), 1, 0);
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_DB_ROLLBACK_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_ROLLBACK_NEEDS_CONFIRM');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 1 export_colonne
SET @ks_s = IF(@ks_go = 1, 'DROP TABLE IF EXISTS export_colonne', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 2 export_stato
SET @ks_s = IF(@ks_go = 1, 'DROP TABLE IF EXISTS export_stato', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 3 vincolo CHECK del codice
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND CONSTRAINT_NAME = 'ck_export_token_accesso') = 1, 'ALTER TABLE `export` DROP CHECK ck_export_token_accesso', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 4 indice unico del codice
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND INDEX_NAME = 'uk_export_token_accesso') > 0, 'ALTER TABLE `export` DROP INDEX uk_export_token_accesso', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 5 colonne nuove di export (solo quelle presenti, in un solo ALTER)
SELECT GROUP_CONCAT(CONCAT('DROP COLUMN `', COLUMN_NAME, '`') ORDER BY ORDINAL_POSITION SEPARATOR ', ') INTO @ks_cols FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME IN ('Separatore', 'DelimitatoreTesto', 'Codifica', 'SeparatoreDecimale', 'Intestazione', 'XmlRadice', 'XmlElemento', 'TogliHtml', 'MinutiCache', 'ParolaDisponibile', 'ParolaInArrivo', 'ParolaNonDisponibile', 'SenzaImmagine', 'SenzaEan', 'PrezzoZero', 'TokenAccesso');
SET @ks_s = IF(@ks_go = 1 AND @ks_cols IS NOT NULL, CONCAT('ALTER TABLE `export` ', @ks_cols), 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_DB_ROLLBACK_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_ROLLBACK');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
```
