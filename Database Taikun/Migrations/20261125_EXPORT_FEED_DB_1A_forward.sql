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
