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
