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
