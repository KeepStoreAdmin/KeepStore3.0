# Script della migrazione `EXPORT-FEED-DB-2A` (cinque)

Testo unico, identico per ogni database KeepStore. Sostituisce la migrazione `EXPORT-FEED-DB-1A` (mai applicata a nessun database reale: le colonne in piu in `export` avrebbero rotto il salvataggio del gestionale attuale, che passa tutte le colonne di `Select * from export` per posizione). Contesto, ordine di esecuzione, significato dei campi e limiti: [EXPORT_FEED_DB_TABLES](EXPORT_FEED_DB_TABLES.md); uso da parte del gestionale: [EXPORT_FEED_GESTIONALE_ENZO](EXPORT_FEED_GESTIONALE_ENZO.md). **Quale script, dove:** sul database sorgente (taikun) il PO esegue `preflight` -> `forward` -> `verify`. Su ogni altro database, dopo che il programma di allineamento ha portato le tabelle e le routine, si esegue `dati` (che non crea ne sostituisce tabelle o routine: scrive soltanto i dati che un confronto di strutture non porta) e poi `verify`; il `forward` intero non va rilanciato su un database gia allineato, perche ricreerebbe le routine con l'account di chi lo esegue. `rollback` annulla tutto (conferma esplicita). I cinque script stanno qui, in blocchi di una pagina dei documenti (non sono file `.sql` del repository: la guardia dei segreti del repository pubblico non li ammette senza deroga nominativa); `Tools/Test-ExportFeedDb.ps1` li estrae da questa pagina ed esegue gli script REALI sul LAB.

## 20261126_EXPORT_FEED_DB_2A_preflight.sql

```sql
-- EXPORT-FEED-DB-2A (preflight, SOLA LETTURA).
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento.
-- Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini o account; nessun DEFINER (il proprietario delle routine e chi esegue lo script).
-- Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito per quel database. Mai --force.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa
-- (la sessione conserva variabili e modalita). I passi su tabelle si autodecidono dallo stato reale di information_schema; le routine (CREATE/DROP PROCEDURE non si
-- possono eseguire con PREPARE, ERROR 1295) non hanno la guardia @ks_go: il preflight e il cancello, lo script va eseguito solo dopo un preflight OK e con l'arresto sull'errore.
-- Serve MySQL 8.0.19 o successivo (CHECK applicato, REGEXP_LIKE, alias di riga nell'INSERT); non MariaDB. Si ferma se il log binario e attivo in formato STATEMENT.
-- Esito atteso: una riga con EXPORT_FEED_DB_PREFLIGHT_OK; qualunque STOP = errore deliberato, non procedere. Stampa anche chi esegue lo script (sara il proprietario delle routine nuove:
-- deve essere lo stesso account delle routine esistenti del gestionale) e le routine con gli stessi nomi gia presenti (lo script le sostituisce).

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_ck_version = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_ck_binlog = IF(@@global.log_bin = 1 AND (@@global.binlog_format = 'STATEMENT' OR @@session.binlog_format = 'STATEMENT'), 0, 1);
SET @ks_ck_export = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'ID' AND DATA_TYPE = 'int' AND COLUMN_TYPE NOT LIKE '%unsigned%' AND COLUMN_KEY = 'PRI' AND EXTRA LIKE '%auto_increment%') = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND ENGINE = 'InnoDB') = 1, 1, 0);
SET @ks_go = IF(@ks_ck_version = 1 AND @ks_ck_binlog = 1 AND @ks_ck_export = 1, 1, 0);
SELECT DATABASE() AS BaseDati, @@server_uuid AS ServerUuid, VERSION() AS Versione, @@global.log_bin AS LogBin, @@global.binlog_format AS FormatoBinlog, CURRENT_USER() AS AccountCheEsegue,
       (SELECT COUNT(*) FROM `export`) AS FeedEsistenti, @ks_ck_version AS VersioneOk, @ks_ck_binlog AS BinlogOk, @ks_ck_export AS TabellaExportOk;
SELECT 'STATO_OGGETTI' AS Controllo,
       (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_opzioni', 'export_stato', 'export_colonne')) AS TabelleNuoveGiaPresenti_su_3,
       (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice')) AS RoutineConNomeUgualeGiaPresenti_su_4,
       (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sysparametristored') AS RegistroParametriPresente_su_1,
       (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'exportcampi') AS ExportcampiPresente_su_1,
       (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME IN ('TokenAccesso', 'Separatore', 'DelimitatoreTesto', 'Codifica', 'SeparatoreDecimale', 'Intestazione', 'XmlRadice', 'XmlElemento', 'TogliHtml', 'MinutiCache', 'ParolaDisponibile', 'ParolaInArrivo', 'ParolaNonDisponibile', 'SenzaImmagine', 'SenzaEan', 'PrezzoZero')) AS ColonneNuoveInExport_su_0_atteso;
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sysparametristored') = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'exportcampi') = 1, 'SELECT ''EXPORT_FEED_DB_PREFLIGHT_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_PRECONDITION');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
```

## 20261126_EXPORT_FEED_DB_2A_forward.sql

```sql
-- EXPORT-FEED-DB-2A (forward).
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento.
-- Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini o account; nessun DEFINER (il proprietario delle routine e chi esegue lo script).
-- Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito per quel database. Mai --force.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa
-- (la sessione conserva variabili e modalita). I passi su tabelle si autodecidono dallo stato reale di information_schema; le routine (CREATE/DROP PROCEDURE non si
-- possono eseguire con PREPARE, ERROR 1295) non hanno la guardia @ks_go: il preflight e il cancello, lo script va eseguito solo dopo un preflight OK e con l'arresto sull'errore.
-- Serve MySQL 8.0.19 o successivo (CHECK applicato, REGEXP_LIKE, alias di riga nell'INSERT); non MariaDB. Si ferma se il log binario e attivo in formato STATEMENT.
-- Passi (ognuno contrassegnato da una riga '-- STEP n'; il test li usa per simulare un'interruzione dopo ciascuno):
--   1 export_opzioni (codice del link creato dal database, opzioni con predefinito); 2 una riga per ogni feed esistente; 3 export_stato; 4 export_colonne; 5 voce CategoriaPercorso di exportcampi;
--   6 quattro routine NUOVE (solo aggiuntive: nessuna routine esistente cambia); 7 righe di sysparametristored delle quattro routine (stessa regola di AggiornaDb del gestionale); 8 controllo finale.
-- La tabella export NON cambia: il gestionale attuale continua a funzionare identico (salva passando tutte le colonne di 'Select * from export' per posizione).
-- Ripetibile dopo qualunque interruzione. Ritorno indietro: lo script rollback (cancella anche i codici e lo stato: chiede una conferma esplicita).

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_ck_version = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_ck_binlog = IF(@@global.log_bin = 1 AND (@@global.binlog_format = 'STATEMENT' OR @@session.binlog_format = 'STATEMENT'), 0, 1);
SET @ks_ck_export = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'ID' AND DATA_TYPE = 'int' AND COLUMN_TYPE NOT LIKE '%unsigned%' AND COLUMN_KEY = 'PRI' AND EXTRA LIKE '%auto_increment%') = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND ENGINE = 'InnoDB') = 1, 1, 0);
SET @ks_go = IF(@ks_ck_version = 1 AND @ks_ck_binlog = 1 AND @ks_ck_export = 1, 1, 0);
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_DB_FORWARD_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_PRECONDITION');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 1 OPZIONI: export_opzioni (Id, ExportId unico, TokenAccesso con predefinito creato dal database, 15 opzioni)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni') = 0, 'CREATE TABLE export_opzioni (
  Id int NOT NULL AUTO_INCREMENT,
  ExportId int NOT NULL,
  TokenAccesso varchar(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (HEX(RANDOM_BYTES(24))),
  Separatore varchar(5) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''|'',
  DelimitatoreTesto varchar(1) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '''',
  Codifica varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''utf-8'',
  SeparatoreDecimale varchar(1) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''.'',
  Intestazione int NOT NULL DEFAULT 1,
  XmlRadice varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''prodotti'',
  XmlElemento varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''prodotto'',
  TogliHtml int NOT NULL DEFAULT 1,
  MinutiCache int NOT NULL DEFAULT 60,
  ParolaDisponibile varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''Disponibile'',
  ParolaInArrivo varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''In Arrivo'',
  ParolaNonDisponibile varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT ''Non Disponibile'',
  SenzaImmagine int NOT NULL DEFAULT 0,
  SenzaEan int NOT NULL DEFAULT 0,
  PrezzoZero int NOT NULL DEFAULT 1,
  PRIMARY KEY (Id),
  UNIQUE KEY uk_export_opzioni_exportid (ExportId),
  UNIQUE KEY uk_export_opzioni_token (TokenAccesso),
  CONSTRAINT fk_export_opzioni_export FOREIGN KEY (ExportId) REFERENCES `export` (ID) ON DELETE CASCADE,
  CONSTRAINT ck_export_opzioni_token CHECK (CHAR_LENGTH(TokenAccesso) = 48 AND REGEXP_LIKE(TokenAccesso, ''^[0-9A-F]{48}$'', ''c''))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 2 RIEMPIMENTO: una riga per ogni feed che non l'ha (il codice lo crea il database, distinto per riga)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni') = 1, 'INSERT INTO export_opzioni (ExportId) SELECT e.ID FROM `export` e WHERE NOT EXISTS (SELECT 1 FROM export_opzioni o WHERE o.ExportId = e.ID) ORDER BY e.ID', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 3 STATO: export_stato (scritta dal sito; la configurazione resta in sola lettura per il sito)
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

-- STEP 4 COLONNE: export_colonne (le colonne del file, una riga per colonna)
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

-- STEP 5 CAMPO: la voce CategoriaPercorso del selettore dei campi (exportcampi)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'exportcampi') = 1, 'INSERT INTO exportcampi (NomeCampo) SELECT ''CategoriaPercorso'' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM exportcampi WHERE NomeCampo = ''CategoriaPercorso'')', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 6 ROUTINE: quattro routine nuove (le routine esistenti Newexport, Modexport, Delexport, Newexport_filtri non cambiano)
DELIMITER $$

-- Newexport_opzioni: inserisce o aggiorna le opzioni di UN feed (una riga per ExportId). Non scrive MAI il codice del link: un parametro NULL vale il predefinito della colonna.
-- Convenzione del gestionale (AggiungiDati): colonne dalla seconda all'ultima di export_opzioni, in ordine di tabella, poi l'OUT parRetVal (= Id della riga).
DROP PROCEDURE IF EXISTS `Newexport_opzioni`$$
CREATE PROCEDURE `Newexport_opzioni`(
  IN parExportId int,
  IN parTokenAccesso varchar(64) CHARACTER SET utf8mb4,
  IN parSeparatore varchar(5) CHARACTER SET utf8mb4,
  IN parDelimitatoreTesto varchar(1) CHARACTER SET utf8mb4,
  IN parCodifica varchar(10) CHARACTER SET utf8mb4,
  IN parSeparatoreDecimale varchar(1) CHARACTER SET utf8mb4,
  IN parIntestazione int,
  IN parXmlRadice varchar(40) CHARACTER SET utf8mb4,
  IN parXmlElemento varchar(40) CHARACTER SET utf8mb4,
  IN parTogliHtml int,
  IN parMinutiCache int,
  IN parParolaDisponibile varchar(40) CHARACTER SET utf8mb4,
  IN parParolaInArrivo varchar(40) CHARACTER SET utf8mb4,
  IN parParolaNonDisponibile varchar(40) CHARACTER SET utf8mb4,
  IN parSenzaImmagine int,
  IN parSenzaEan int,
  IN parPrezzoZero int,
  OUT parRetVal int
)
BEGIN
  INSERT INTO export_opzioni (ExportId, Separatore, DelimitatoreTesto, Codifica, SeparatoreDecimale, Intestazione, XmlRadice, XmlElemento, TogliHtml, MinutiCache, ParolaDisponibile, ParolaInArrivo, ParolaNonDisponibile, SenzaImmagine, SenzaEan, PrezzoZero)
  VALUES (parExportId, IFNULL(parSeparatore, DEFAULT(Separatore)), IFNULL(parDelimitatoreTesto, DEFAULT(DelimitatoreTesto)), IFNULL(parCodifica, DEFAULT(Codifica)), IFNULL(parSeparatoreDecimale, DEFAULT(SeparatoreDecimale)), IFNULL(parIntestazione, DEFAULT(Intestazione)), IFNULL(parXmlRadice, DEFAULT(XmlRadice)), IFNULL(parXmlElemento, DEFAULT(XmlElemento)), IFNULL(parTogliHtml, DEFAULT(TogliHtml)), IFNULL(parMinutiCache, DEFAULT(MinutiCache)), IFNULL(parParolaDisponibile, DEFAULT(ParolaDisponibile)), IFNULL(parParolaInArrivo, DEFAULT(ParolaInArrivo)), IFNULL(parParolaNonDisponibile, DEFAULT(ParolaNonDisponibile)), IFNULL(parSenzaImmagine, DEFAULT(SenzaImmagine)), IFNULL(parSenzaEan, DEFAULT(SenzaEan)), IFNULL(parPrezzoZero, DEFAULT(PrezzoZero))) AS nuovo
  ON DUPLICATE KEY UPDATE Separatore = nuovo.Separatore, DelimitatoreTesto = nuovo.DelimitatoreTesto, Codifica = nuovo.Codifica, SeparatoreDecimale = nuovo.SeparatoreDecimale, Intestazione = nuovo.Intestazione, XmlRadice = nuovo.XmlRadice, XmlElemento = nuovo.XmlElemento, TogliHtml = nuovo.TogliHtml, MinutiCache = nuovo.MinutiCache, ParolaDisponibile = nuovo.ParolaDisponibile, ParolaInArrivo = nuovo.ParolaInArrivo, ParolaNonDisponibile = nuovo.ParolaNonDisponibile, SenzaImmagine = nuovo.SenzaImmagine, SenzaEan = nuovo.SenzaEan, PrezzoZero = nuovo.PrezzoZero;
  SELECT Id INTO parRetVal FROM export_opzioni WHERE ExportId = parExportId;
END$$

-- Newexport_colonne: una colonna del file; il gestionale cancella le righe del feed e le reinserisce (come per export_filtri). parRetVal = Id della riga.
DROP PROCEDURE IF EXISTS `Newexport_colonne`$$
CREATE PROCEDURE `Newexport_colonne`(
  IN parExportId int,
  IN parPosizione int,
  IN parTitoloColonna varchar(60) CHARACTER SET utf8mb4,
  IN parCampo varchar(40) CHARACTER SET utf8mb4,
  IN parPrefisso varchar(40) CHARACTER SET utf8mb4,
  IN parSuffisso varchar(40) CHARACTER SET utf8mb4,
  IN parValoreFisso varchar(100) CHARACTER SET utf8mb4,
  IN parMassimoCaratteri int,
  IN parSeVuoto varchar(100) CHARACTER SET utf8mb4,
  OUT parRetVal int
)
BEGIN
  INSERT INTO export_colonne (ExportId, Posizione, TitoloColonna, Campo, Prefisso, Suffisso, ValoreFisso, MassimoCaratteri, SeVuoto)
  VALUES (parExportId, parPosizione, IFNULL(parTitoloColonna, ''), IFNULL(parCampo, ''), IFNULL(parPrefisso, ''), IFNULL(parSuffisso, ''), IFNULL(parValoreFisso, ''), parMassimoCaratteri, IFNULL(parSeVuoto, ''));
  SET parRetVal = LAST_INSERT_ID();
END$$

-- Dupexport: copia un feed (riga di export, opzioni, colonne, filtri) con un nuovo codice del link e Abilitato = 0. parRetVal = ID del nuovo feed, -1 se l'origine non esiste.
-- Da chiamare dentro la transazione del gestionale.
DROP PROCEDURE IF EXISTS `Dupexport`$$
CREATE PROCEDURE `Dupexport`(IN parId int, OUT parRetVal int)
BEGIN
  DECLARE vNuovo int DEFAULT 0;
  SET parRetVal = -1;
  INSERT INTO `export` (Descrizione, `Password`, FormatString, NListino, IvaTipo, Giacenza, SpeseSpedizione, GiorniSpedizione, Azienda, Tipo, IdVettore, NListino2, Tutto_in_minuscolo, Google, Amazon, NoVettoreSuGratis, Abilitato)
  SELECT LEFT(CONCAT(IFNULL(Descrizione, ''), '_copia'), 150), `Password`, FormatString, NListino, IvaTipo, Giacenza, SpeseSpedizione, GiorniSpedizione, Azienda, Tipo, IdVettore, NListino2, Tutto_in_minuscolo, Google, Amazon, NoVettoreSuGratis, 0
  FROM `export` WHERE ID = parId;
  IF ROW_COUNT() = 1 THEN
    SET vNuovo = LAST_INSERT_ID();
    INSERT INTO export_opzioni (ExportId, Separatore, DelimitatoreTesto, Codifica, SeparatoreDecimale, Intestazione, XmlRadice, XmlElemento, TogliHtml, MinutiCache, ParolaDisponibile, ParolaInArrivo, ParolaNonDisponibile, SenzaImmagine, SenzaEan, PrezzoZero)
    SELECT vNuovo, Separatore, DelimitatoreTesto, Codifica, SeparatoreDecimale, Intestazione, XmlRadice, XmlElemento, TogliHtml, MinutiCache, ParolaDisponibile, ParolaInArrivo, ParolaNonDisponibile, SenzaImmagine, SenzaEan, PrezzoZero FROM export_opzioni WHERE ExportId = parId;
    INSERT INTO export_opzioni (ExportId)
    SELECT vNuovo FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM export_opzioni WHERE ExportId = vNuovo);
    INSERT INTO export_colonne (ExportId, Posizione, TitoloColonna, Campo, Prefisso, Suffisso, ValoreFisso, MassimoCaratteri, SeVuoto)
    SELECT vNuovo, Posizione, TitoloColonna, Campo, Prefisso, Suffisso, ValoreFisso, MassimoCaratteri, SeVuoto FROM export_colonne WHERE ExportId = parId;
    INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId)
    SELECT vNuovo, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId FROM export_filtri WHERE ExportId = parId;
    SET parRetVal = vNuovo;
  END IF;
END$$

-- Modexport_codice: nuovo codice del link (il precedente smette di valere). Il nome comincia con Mod: il gestionale riceve False se il feed non ha la riga delle opzioni.
-- L'UPDATE e l'ultima istruzione (le righe modificate sono il risultato di ExecuteNonQuery).
DROP PROCEDURE IF EXISTS `Modexport_codice`$$
CREATE PROCEDURE `Modexport_codice`(IN parId int, OUT parRetVal int)
BEGIN
  SET parRetVal = parId;
  UPDATE export_opzioni SET TokenAccesso = DEFAULT WHERE ExportId = parId;
END$$

DELIMITER ;

-- STEP 7 REGISTRO: le righe di sysparametristored delle quattro routine, generate da information_schema nell'ordine dei parametri (come AggiornaDb); si cancellano e
-- riscrivono SOLO quelle delle quattro routine. Il gestionale carica il registro una volta per processo: dopo lo script va riavviato.
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sysparametristored') = 1, 'DELETE FROM sysparametristored WHERE NomeStore IN (''Newexport_opzioni'', ''Newexport_colonne'', ''Dupexport'', ''Modexport_codice'')', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sysparametristored') = 1, 'INSERT INTO sysparametristored (NomeStore, NomeParametro, Tipo, Lunghezza, Direzione) SELECT SPECIFIC_NAME, PARAMETER_NAME, DATA_TYPE, CAST(REPLACE(COALESCE(NULLIF(REGEXP_REPLACE(DTD_IDENTIFIER, ''[^0-9,]'', ''''), ''''), ''-1''), '','', ''.'') AS DECIMAL(15,3)), PARAMETER_MODE FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA = DATABASE() AND SPECIFIC_NAME IN (''Newexport_opzioni'', ''Newexport_colonne'', ''Dupexport'', ''Modexport_codice'') ORDER BY SPECIFIC_NAME, ORDINAL_POSITION', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 8 CONTROLLO FINALE minimo (il controllo completo e lo script verify)
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_opzioni', 'export_stato', 'export_colonne')) = 3 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice')) = 4 AND (SELECT COUNT(*) FROM `export` e WHERE NOT EXISTS (SELECT 1 FROM export_opzioni o WHERE o.ExportId = e.ID)) = 0, 'SELECT ''EXPORT_FEED_DB_FORWARD_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_FORWARD');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
```

## 20261126_EXPORT_FEED_DB_2A_dati.sql

```sql
-- EXPORT-FEED-DB-2A (dati).
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento.
-- Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini o account; nessun DEFINER (il proprietario delle routine e chi esegue lo script).
-- Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito per quel database. Mai --force.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa
-- (la sessione conserva variabili e modalita). I passi su tabelle si autodecidono dallo stato reale di information_schema; le routine (CREATE/DROP PROCEDURE non si
-- possono eseguire con PREPARE, ERROR 1295) non hanno la guardia @ks_go: il preflight e il cancello, lo script va eseguito solo dopo un preflight OK e con l'arresto sull'errore.
-- Serve MySQL 8.0.19 o successivo (CHECK applicato, REGEXP_LIKE, alias di riga nell'INSERT); non MariaDB. Si ferma se il log binario e attivo in formato STATEMENT.
-- Per un database la cui STRUTTURA (le tre tabelle e le quattro routine) e gia stata portata dal programma di allineamento. NON crea ne sostituisce tabelle o routine
-- (il forward le ricreerebbe con l'account di chi lo esegue). Scrive soltanto: 1 una riga di opzioni per ogni feed che non l'ha (le righe esistenti non si toccano); 2 la voce CategoriaPercorso di exportcampi;
-- 3 le righe di sysparametristored delle quattro routine (in una transazione). TUTTI i controlli vengono PRIMA di qualunque scrittura: tabelle, routine, ordine delle colonne e firma completa dei parametri
-- (nome, direzione, ordine) confrontata con l'elenco scritto in questo testo; se qualcosa differisce lo script si ferma senza scrivere nulla (anche se il programma di allineamento ha cambiato un parametro).
-- Esito atteso: EXPORT_FEED_DB_DATI_OK. Ripetibile. Va eseguito con lo stesso account delle routine esistenti, poi si lancia verify.

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_ck_version = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_ck_binlog = IF(@@global.log_bin = 1 AND (@@global.binlog_format = 'STATEMENT' OR @@session.binlog_format = 'STATEMENT'), 0, 1);
SET @ks_ck_export = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'ID' AND DATA_TYPE = 'int' AND COLUMN_TYPE NOT LIKE '%unsigned%' AND COLUMN_KEY = 'PRI' AND EXTRA LIKE '%auto_increment%') = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND ENGINE = 'InnoDB') = 1, 1, 0);
SET @ks_go = IF(@ks_ck_version = 1 AND @ks_ck_binlog = 1 AND @ks_ck_export = 1, 1, 0);
SET @ks_go = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_opzioni', 'export_stato', 'export_colonne', 'sysparametristored', 'exportcampi') AND ENGINE = 'InnoDB') = 5 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_NAME IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice')) = 4 AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni') = 'Id,ExportId,TokenAccesso,Separatore,DelimitatoreTesto,Codifica,SeparatoreDecimale,Intestazione,XmlRadice,XmlElemento,TogliHtml,MinutiCache,ParolaDisponibile,ParolaInArrivo,ParolaNonDisponibile,SenzaImmagine,SenzaEan,PrezzoZero' AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME, ' ', COLUMN_TYPE) ORDER BY ORDINAL_POSITION SEPARATOR ',') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne') = 'Id int,ExportId int,Posizione int,TitoloColonna varchar(60),Campo varchar(40),Prefisso varchar(40),Suffisso varchar(40),ValoreFisso varchar(100),MassimoCaratteri int,SeVuoto varchar(100)' AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME, ' ', COLUMN_TYPE) ORDER BY ORDINAL_POSITION SEPARATOR ',') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_stato') = 'ExportId int,UltimaGenerazioneUtc datetime,UltimaRichiestaUtc datetime,UltimeRighe int,UltimeScartate int,UltimoErrore varchar(200)' AND (SELECT COUNT(*) FROM (SELECT SPECIFIC_NAME AS n, GROUP_CONCAT(CONCAT(PARAMETER_NAME, ':', PARAMETER_MODE) ORDER BY ORDINAL_POSITION SEPARATOR ',') AS g FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA = DATABASE() AND SPECIFIC_NAME IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice') GROUP BY SPECIFIC_NAME) s WHERE (s.n, s.g) IN (('Newexport_opzioni', 'parExportId:IN,parTokenAccesso:IN,parSeparatore:IN,parDelimitatoreTesto:IN,parCodifica:IN,parSeparatoreDecimale:IN,parIntestazione:IN,parXmlRadice:IN,parXmlElemento:IN,parTogliHtml:IN,parMinutiCache:IN,parParolaDisponibile:IN,parParolaInArrivo:IN,parParolaNonDisponibile:IN,parSenzaImmagine:IN,parSenzaEan:IN,parPrezzoZero:IN,parRetVal:OUT'), ('Newexport_colonne', 'parExportId:IN,parPosizione:IN,parTitoloColonna:IN,parCampo:IN,parPrefisso:IN,parSuffisso:IN,parValoreFisso:IN,parMassimoCaratteri:IN,parSeVuoto:IN,parRetVal:OUT'), ('Dupexport', 'parId:IN,parRetVal:OUT'), ('Modexport_codice', 'parId:IN,parRetVal:OUT'))) = 4, 1, 0);
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_DB_DATI_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_DATI_STRUTTURA');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 1 RIEMPIMENTO: una riga di opzioni per ogni feed che non l'ha (il codice lo crea il database); le righe esistenti non si toccano
SET @ks_s = IF(@ks_go = 1, 'INSERT INTO export_opzioni (ExportId) SELECT e.ID FROM `export` e WHERE NOT EXISTS (SELECT 1 FROM export_opzioni o WHERE o.ExportId = e.ID) ORDER BY e.ID', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 2 CAMPO: la voce CategoriaPercorso del selettore dei campi (exportcampi)
SET @ks_s = IF(@ks_go = 1, 'INSERT INTO exportcampi (NomeCampo) SELECT ''CategoriaPercorso'' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM exportcampi WHERE NomeCampo = ''CategoriaPercorso'')', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- STEP 3 REGISTRO: le righe di sysparametristored delle SOLE quattro routine, cancellate e riscritte in una transazione (l'elenco dei parametri e gia stato verificato sopra)
START TRANSACTION;
SET @ks_s = IF(@ks_go = 1, 'DELETE FROM sysparametristored WHERE NomeStore IN (''Newexport_opzioni'', ''Newexport_colonne'', ''Dupexport'', ''Modexport_codice'')', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_s = IF(@ks_go = 1, 'INSERT INTO sysparametristored (NomeStore, NomeParametro, Tipo, Lunghezza, Direzione) SELECT SPECIFIC_NAME, PARAMETER_NAME, DATA_TYPE, CAST(REPLACE(COALESCE(NULLIF(REGEXP_REPLACE(DTD_IDENTIFIER, ''[^0-9,]'', ''''), ''''), ''-1''), '','', ''.'') AS DECIMAL(15,3)), PARAMETER_MODE FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA = DATABASE() AND SPECIFIC_NAME IN (''Newexport_opzioni'', ''Newexport_colonne'', ''Dupexport'', ''Modexport_codice'') ORDER BY SPECIFIC_NAME, ORDINAL_POSITION', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
COMMIT;

-- STEP 4 CONTROLLO FINALE
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM `export` e WHERE NOT EXISTS (SELECT 1 FROM export_opzioni o WHERE o.ExportId = e.ID)) = 0 AND (SELECT COUNT(*) FROM exportcampi WHERE NomeCampo = 'CategoriaPercorso') = 1 AND (SELECT COUNT(*) FROM sysparametristored WHERE NomeStore IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice')) = 32 AND (SELECT COUNT(*) FROM (SELECT NomeStore AS n, GROUP_CONCAT(CONCAT(NomeParametro, ':', Direzione) ORDER BY id SEPARATOR ',') AS g FROM sysparametristored WHERE NomeStore IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice') GROUP BY NomeStore) s WHERE (s.n, s.g) IN (('Newexport_opzioni', 'parExportId:IN,parTokenAccesso:IN,parSeparatore:IN,parDelimitatoreTesto:IN,parCodifica:IN,parSeparatoreDecimale:IN,parIntestazione:IN,parXmlRadice:IN,parXmlElemento:IN,parTogliHtml:IN,parMinutiCache:IN,parParolaDisponibile:IN,parParolaInArrivo:IN,parParolaNonDisponibile:IN,parSenzaImmagine:IN,parSenzaEan:IN,parPrezzoZero:IN,parRetVal:OUT'), ('Newexport_colonne', 'parExportId:IN,parPosizione:IN,parTitoloColonna:IN,parCampo:IN,parPrefisso:IN,parSuffisso:IN,parValoreFisso:IN,parMassimoCaratteri:IN,parSeVuoto:IN,parRetVal:OUT'), ('Dupexport', 'parId:IN,parRetVal:OUT'), ('Modexport_codice', 'parId:IN,parRetVal:OUT'))) = 4, 'SELECT ''EXPORT_FEED_DB_DATI_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_DATI');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
```

## 20261126_EXPORT_FEED_DB_2A_verify.sql

```sql
-- EXPORT-FEED-DB-2A (verify, SOLA LETTURA).
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento.
-- Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini o account; nessun DEFINER (il proprietario delle routine e chi esegue lo script).
-- Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito per quel database. Mai --force.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa
-- (la sessione conserva variabili e modalita). I passi su tabelle si autodecidono dallo stato reale di information_schema; le routine (CREATE/DROP PROCEDURE non si
-- possono eseguire con PREPARE, ERROR 1295) non hanno la guardia @ks_go: il preflight e il cancello, lo script va eseguito solo dopo un preflight OK e con l'arresto sull'errore.
-- Serve MySQL 8.0.19 o successivo (CHECK applicato, REGEXP_LIKE, alias di riga nell'INSERT); non MariaDB. Si ferma se il log binario e attivo in formato STATEMENT.
-- Stampa una riga Controllo/Esito per ogni verifica e in fondo EXPORT_FEED_DB_VERIFY_OK; se un controllo e KO, errore deliberato.

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_ck_version = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_ck_binlog = IF(@@global.log_bin = 1 AND (@@global.binlog_format = 'STATEMENT' OR @@session.binlog_format = 'STATEMENT'), 0, 1);
SET @ks_ck_export = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'ID' AND DATA_TYPE = 'int' AND COLUMN_TYPE NOT LIKE '%unsigned%' AND COLUMN_KEY = 'PRI' AND EXTRA LIKE '%auto_increment%') = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND ENGINE = 'InnoDB') = 1, 1, 0);
SET @ks_go = IF(@ks_ck_version = 1 AND @ks_ck_binlog = 1 AND @ks_ck_export = 1, 1, 0);
SET @ks_v1 = IF((SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni' AND ENGINE = 'InnoDB' AND TABLE_COLLATION = 'utf8mb4_0900_ai_ci') = 1, 1, 0);
SET @ks_v2 = IF((SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni') = 'Id,ExportId,TokenAccesso,Separatore,DelimitatoreTesto,Codifica,SeparatoreDecimale,Intestazione,XmlRadice,XmlElemento,TogliHtml,MinutiCache,ParolaDisponibile,ParolaInArrivo,ParolaNonDisponibile,SenzaImmagine,SenzaEan,PrezzoZero', 1, 0);
SET @ks_v3 = IF((SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME, '=', COLUMN_DEFAULT) ORDER BY ORDINAL_POSITION SEPARATOR ';') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni' AND COLUMN_NAME IN ('Separatore', 'DelimitatoreTesto', 'Codifica', 'SeparatoreDecimale', 'Intestazione', 'XmlRadice', 'XmlElemento', 'TogliHtml', 'MinutiCache', 'ParolaDisponibile', 'ParolaInArrivo', 'ParolaNonDisponibile', 'SenzaImmagine', 'SenzaEan', 'PrezzoZero')) = 'Separatore=|;DelimitatoreTesto=;Codifica=utf-8;SeparatoreDecimale=.;Intestazione=1;XmlRadice=prodotti;XmlElemento=prodotto;TogliHtml=1;MinutiCache=60;ParolaDisponibile=Disponibile;ParolaInArrivo=In Arrivo;ParolaNonDisponibile=Non Disponibile;SenzaImmagine=0;SenzaEan=0;PrezzoZero=1', 1, 0);
SET @ks_v4 = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni' AND COLUMN_NAME <> 'Id' AND IS_NULLABLE = 'YES') = 0, 1, 0);
SET @ks_v5 = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni' AND COLUMN_NAME = 'TokenAccesso' AND COLUMN_TYPE = 'varchar(64)' AND COLLATION_NAME = 'ascii_bin' AND IS_NULLABLE = 'NO' AND LOWER(COLUMN_DEFAULT) LIKE '%random_bytes%' AND EXTRA LIKE '%DEFAULT_GENERATED%') = 1, 1, 0);
SET @ks_v6 = IF((SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni' AND INDEX_NAME IN ('uk_export_opzioni_exportid', 'uk_export_opzioni_token') AND NON_UNIQUE = 0) = 2, 1, 0);
SET @ks_v7 = IF((SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS c JOIN information_schema.TABLE_CONSTRAINTS t ON t.CONSTRAINT_SCHEMA = c.CONSTRAINT_SCHEMA AND t.CONSTRAINT_NAME = c.CONSTRAINT_NAME WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'export_opzioni' AND t.CONSTRAINT_NAME = 'ck_export_opzioni_token' AND t.ENFORCED = 'YES' AND LOWER(c.CHECK_CLAUSE) LIKE '%char_length%' AND LOWER(c.CHECK_CLAUSE) LIKE '%regexp_like%' AND c.CHECK_CLAUSE LIKE '%48%') = 1, 1, 0);
SET @ks_v8 = IF((SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME IN ('fk_export_opzioni_export', 'fk_export_colonne_export', 'fk_export_stato_export') AND REFERENCED_TABLE_NAME = 'export' AND DELETE_RULE = 'CASCADE') = 3, 1, 0);
SET @ks_v9 = IF((SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne' AND INDEX_NAME = 'uk_export_colonne_posizione' AND NON_UNIQUE = 0) = 2, 1, 0);
SET @ks_v10 = IF((SELECT COUNT(*) FROM `export` e WHERE NOT EXISTS (SELECT 1 FROM export_opzioni o WHERE o.ExportId = e.ID)) = 0, 1, 0);
SET @ks_v11 = IF((SELECT COUNT(*) FROM export_opzioni WHERE CHAR_LENGTH(TokenAccesso) <> 48 OR NOT REGEXP_LIKE(TokenAccesso, '^[0-9A-F]{48}$', 'c')) = 0 AND (SELECT COUNT(DISTINCT TokenAccesso) FROM export_opzioni) = (SELECT COUNT(*) FROM export_opzioni), 1, 0);
SET @ks_v12 = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME IN ('TokenAccesso', 'Separatore', 'DelimitatoreTesto', 'Codifica', 'SeparatoreDecimale', 'Intestazione', 'XmlRadice', 'XmlElemento', 'TogliHtml', 'MinutiCache', 'ParolaDisponibile', 'ParolaInArrivo', 'ParolaNonDisponibile', 'SenzaImmagine', 'SenzaEan', 'PrezzoZero')) = 0, 1, 0);
SET @ks_v13 = IF((SELECT COUNT(*) FROM exportcampi WHERE NomeCampo = 'CategoriaPercorso') = 1, 1, 0);
SET @ks_v14 = IF((SELECT COUNT(*) FROM (SELECT r.SPECIFIC_NAME, COUNT(p.PARAMETER_NAME) AS n FROM information_schema.ROUTINES r JOIN information_schema.PARAMETERS p ON p.SPECIFIC_SCHEMA = r.ROUTINE_SCHEMA AND p.SPECIFIC_NAME = r.SPECIFIC_NAME WHERE r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_TYPE = 'PROCEDURE' GROUP BY r.SPECIFIC_NAME) x WHERE (x.SPECIFIC_NAME, x.n) IN (('Newexport_opzioni', 18), ('Newexport_colonne', 10), ('Dupexport', 2), ('Modexport_codice', 2))) = 4, 1, 0);
SET @ks_v15 = IF((SELECT COUNT(*) FROM information_schema.PARAMETERS p WHERE p.SPECIFIC_SCHEMA = DATABASE() AND p.SPECIFIC_NAME IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice') AND p.PARAMETER_NAME = 'parRetVal' AND p.PARAMETER_MODE = 'OUT' AND p.ORDINAL_POSITION = (SELECT COUNT(*) FROM information_schema.PARAMETERS p2 WHERE p2.SPECIFIC_SCHEMA = p.SPECIFIC_SCHEMA AND p2.SPECIFIC_NAME = p.SPECIFIC_NAME)) = 4, 1, 0);
SET @ks_v16 = IF((SELECT COUNT(*) FROM (SELECT r.NomeStore, GROUP_CONCAT(r.NomeParametro ORDER BY r.id SEPARATOR ',') AS reg FROM sysparametristored r WHERE r.NomeStore IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice') GROUP BY r.NomeStore) a JOIN (SELECT SPECIFIC_NAME AS NomeStore, GROUP_CONCAT(PARAMETER_NAME ORDER BY ORDINAL_POSITION SEPARATOR ',') AS reg FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA = DATABASE() AND SPECIFIC_NAME IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice') GROUP BY SPECIFIC_NAME) b ON b.NomeStore = a.NomeStore AND b.reg = a.reg) = 4, 1, 0);
SET @ks_v17 = IF((SELECT COUNT(*) FROM sysparametristored WHERE NomeStore IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice') AND ((NomeParametro = 'parRetVal' AND Direzione = 'OUT') OR (NomeParametro <> 'parRetVal' AND Direzione = 'IN'))) = (SELECT COUNT(*) FROM sysparametristored WHERE NomeStore IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice')), 1, 0);
SET @ks_v18 = IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME IN ('Newexport', 'Modexport', 'Delexport', 'Newexport_filtri')) = 4, 1, 0);
SET @ks_v19 = IF((SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME, ' ', COLUMN_TYPE) ORDER BY ORDINAL_POSITION SEPARATOR ',') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne') = 'Id int,ExportId int,Posizione int,TitoloColonna varchar(60),Campo varchar(40),Prefisso varchar(40),Suffisso varchar(40),ValoreFisso varchar(100),MassimoCaratteri int,SeVuoto varchar(100)', 1, 0);
SET @ks_v20 = IF((SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME, ' ', COLUMN_TYPE) ORDER BY ORDINAL_POSITION SEPARATOR ',') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_stato') = 'ExportId int,UltimaGenerazioneUtc datetime,UltimaRichiestaUtc datetime,UltimeRighe int,UltimeScartate int,UltimoErrore varchar(200)', 1, 0);
SET @ks_v21 = IF((SELECT COUNT(*) FROM (SELECT TABLE_NAME AS t, INDEX_NAME AS i, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',') AS g, MIN(NON_UNIQUE) AS u FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND INDEX_NAME IN ('uk_export_opzioni_exportid', 'uk_export_opzioni_token', 'uk_export_colonne_posizione') GROUP BY TABLE_NAME, INDEX_NAME) x WHERE (x.t, x.i, x.g, x.u) IN (('export_opzioni', 'uk_export_opzioni_exportid', 'ExportId', 0), ('export_opzioni', 'uk_export_opzioni_token', 'TokenAccesso', 0), ('export_colonne', 'uk_export_colonne_posizione', 'ExportId,Posizione', 0))) = 3, 1, 0);
SET @ks_v22 = IF((SELECT COUNT(*) FROM (SELECT SPECIFIC_NAME AS n, GROUP_CONCAT(CONCAT(PARAMETER_NAME, ':', PARAMETER_MODE) ORDER BY ORDINAL_POSITION SEPARATOR ',') AS g FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA = DATABASE() AND SPECIFIC_NAME IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice') GROUP BY SPECIFIC_NAME) s WHERE (s.n, s.g) IN (('Newexport_opzioni', 'parExportId:IN,parTokenAccesso:IN,parSeparatore:IN,parDelimitatoreTesto:IN,parCodifica:IN,parSeparatoreDecimale:IN,parIntestazione:IN,parXmlRadice:IN,parXmlElemento:IN,parTogliHtml:IN,parMinutiCache:IN,parParolaDisponibile:IN,parParolaInArrivo:IN,parParolaNonDisponibile:IN,parSenzaImmagine:IN,parSenzaEan:IN,parPrezzoZero:IN,parRetVal:OUT'), ('Newexport_colonne', 'parExportId:IN,parPosizione:IN,parTitoloColonna:IN,parCampo:IN,parPrefisso:IN,parSuffisso:IN,parValoreFisso:IN,parMassimoCaratteri:IN,parSeVuoto:IN,parRetVal:OUT'), ('Dupexport', 'parId:IN,parRetVal:OUT'), ('Modexport_codice', 'parId:IN,parRetVal:OUT'))) = 4, 1, 0);
SET @ks_v23 = IF((SELECT COUNT(*) FROM (SELECT NomeStore AS n, GROUP_CONCAT(CONCAT(NomeParametro, ':', Direzione) ORDER BY id SEPARATOR ',') AS g FROM sysparametristored WHERE NomeStore IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice') GROUP BY NomeStore) s WHERE (s.n, s.g) IN (('Newexport_opzioni', 'parExportId:IN,parTokenAccesso:IN,parSeparatore:IN,parDelimitatoreTesto:IN,parCodifica:IN,parSeparatoreDecimale:IN,parIntestazione:IN,parXmlRadice:IN,parXmlElemento:IN,parTogliHtml:IN,parMinutiCache:IN,parParolaDisponibile:IN,parParolaInArrivo:IN,parParolaNonDisponibile:IN,parSenzaImmagine:IN,parSenzaEan:IN,parPrezzoZero:IN,parRetVal:OUT'), ('Newexport_colonne', 'parExportId:IN,parPosizione:IN,parTitoloColonna:IN,parCampo:IN,parPrefisso:IN,parSuffisso:IN,parValoreFisso:IN,parMassimoCaratteri:IN,parSeVuoto:IN,parRetVal:OUT'), ('Dupexport', 'parId:IN,parRetVal:OUT'), ('Modexport_codice', 'parId:IN,parRetVal:OUT'))) = 4, 1, 0);
SELECT 'Controllo' AS Controllo, 'Esito' AS Esito
UNION ALL SELECT 'export_opzioni_innodb_utf8mb4', IF(@ks_v1 = 1, 'OK', 'KO')
UNION ALL SELECT 'export_opzioni_colonne_e_ordine', IF(@ks_v2 = 1, 'OK', 'KO')
UNION ALL SELECT 'export_opzioni_predefiniti', IF(@ks_v3 = 1, 'OK', 'KO')
UNION ALL SELECT 'export_opzioni_non_nulle', IF(@ks_v4 = 1, 'OK', 'KO')
UNION ALL SELECT 'codice_ascii_bin_64_predefinito_database', IF(@ks_v5 = 1, 'OK', 'KO')
UNION ALL SELECT 'indici_unici', IF(@ks_v6 = 1, 'OK', 'KO')
UNION ALL SELECT 'controllo_formato_codice_attivo', IF(@ks_v7 = 1, 'OK', 'KO')
UNION ALL SELECT 'cascata_su_opzioni_colonne_stato', IF(@ks_v8 = 1, 'OK', 'KO')
UNION ALL SELECT 'posizione_unica_per_feed', IF(@ks_v9 = 1, 'OK', 'KO')
UNION ALL SELECT 'ogni_feed_ha_le_opzioni', IF(@ks_v10 = 1, 'OK', 'KO')
UNION ALL SELECT 'codici_validi_e_distinti', IF(@ks_v11 = 1, 'OK', 'KO')
UNION ALL SELECT 'export_senza_colonne_nuove', IF(@ks_v12 = 1, 'OK', 'KO')
UNION ALL SELECT 'campo_categoriapercorso', IF(@ks_v13 = 1, 'OK', 'KO')
UNION ALL SELECT 'routine_e_numero_di_parametri', IF(@ks_v14 = 1, 'OK', 'KO')
UNION ALL SELECT 'ultimo_parametro_out_parretval', IF(@ks_v15 = 1, 'OK', 'KO')
UNION ALL SELECT 'registro_uguale_ai_parametri_nello_stesso_ordine', IF(@ks_v16 = 1, 'OK', 'KO')
UNION ALL SELECT 'registro_direzione_corretta', IF(@ks_v17 = 1, 'OK', 'KO')
UNION ALL SELECT 'routine_esistenti_presenti', IF(@ks_v18 = 1, 'OK', 'KO')
UNION ALL SELECT 'export_colonne_colonne_tipi_e_ordine', IF(@ks_v19 = 1, 'OK', 'KO')
UNION ALL SELECT 'export_stato_colonne_tipi_e_ordine', IF(@ks_v20 = 1, 'OK', 'KO')
UNION ALL SELECT 'indici_per_colonna', IF(@ks_v21 = 1, 'OK', 'KO')
UNION ALL SELECT 'firma_attesa_dei_parametri_delle_routine', IF(@ks_v22 = 1, 'OK', 'KO')
UNION ALL SELECT 'firma_attesa_nel_registro', IF(@ks_v23 = 1, 'OK', 'KO');
-- Informazione, NON e un controllo: proprietario e SQL SECURITY delle routine nuove e di quelle esistenti (il programma di allineamento imposta l'account per ogni database).
SELECT ROUTINE_NAME AS Routine, DEFINER AS Proprietario, SECURITY_TYPE AS SqlSecurity FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME IN ('Newexport', 'Modexport', 'Delexport', 'Newexport_filtri', 'Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice') ORDER BY ROUTINE_NAME;
SET @ks_s = IF(@ks_go = 1 AND (@ks_v1+@ks_v2+@ks_v3+@ks_v4+@ks_v5+@ks_v6+@ks_v7+@ks_v8+@ks_v9+@ks_v10+@ks_v11+@ks_v12+@ks_v13+@ks_v14+@ks_v15+@ks_v16+@ks_v17+@ks_v18+@ks_v19+@ks_v20+@ks_v21+@ks_v22+@ks_v23) = 23, 'SELECT ''EXPORT_FEED_DB_VERIFY_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_VERIFY');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
```

## 20261126_EXPORT_FEED_DB_2A_rollback.sql

```sql
-- EXPORT-FEED-DB-2A (rollback). ATTENZIONE: cancella i codici dei link, le opzioni, le colonne dei feed e lo stato scritti dopo il forward (dati che un uso successivo avra scritto).
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento.
-- Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini o account; nessun DEFINER (il proprietario delle routine e chi esegue lo script).
-- Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito per quel database. Mai --force.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa
-- (la sessione conserva variabili e modalita). I passi su tabelle si autodecidono dallo stato reale di information_schema; le routine (CREATE/DROP PROCEDURE non si
-- possono eseguire con PREPARE, ERROR 1295) non hanno la guardia @ks_go: il preflight e il cancello, lo script va eseguito solo dopo un preflight OK e con l'arresto sull'errore.
-- Serve MySQL 8.0.19 o successivo (CHECK applicato, REGEXP_LIKE, alias di riga nell'INSERT); non MariaDB. Si ferma se il log binario e attivo in formato STATEMENT.
-- Va preceduto, nella stessa scheda, da:  SET @KeepStoreConfirmDropFeedData=1;   (senza, si ferma). Non tocca export, export_filtri, ne le routine e le righe del gestionale preesistenti.
-- Se la voce CategoriaPercorso di exportcampi esisteva prima del forward, il rollback la toglie comunque (e una voce di questa migrazione).

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_ck_version = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_ck_binlog = IF(@@global.log_bin = 1 AND (@@global.binlog_format = 'STATEMENT' OR @@session.binlog_format = 'STATEMENT'), 0, 1);
SET @ks_ck_export = IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME = 'ID' AND DATA_TYPE = 'int' AND COLUMN_TYPE NOT LIKE '%unsigned%' AND COLUMN_KEY = 'PRI' AND EXTRA LIKE '%auto_increment%') = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND ENGINE = 'InnoDB') = 1, 1, 0);
SET @ks_go = IF(@ks_ck_version = 1 AND @ks_ck_binlog = 1 AND @ks_ck_export = 1, 1, 0);
SET @ks_go = IF(@ks_go = 1 AND @KeepStoreConfirmDropFeedData = 1, 1, 0);
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_DB_ROLLBACK_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_ROLLBACK_CONFIRM');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

-- Le routine nuove (CREATE/DROP PROCEDURE non si possono eseguire con PREPARE: la guardia e l'arresto sull'errore del passo precedente)
DROP PROCEDURE IF EXISTS `Newexport_opzioni`;
DROP PROCEDURE IF EXISTS `Newexport_colonne`;
DROP PROCEDURE IF EXISTS `Dupexport`;
DROP PROCEDURE IF EXISTS `Modexport_codice`;

SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sysparametristored') = 1, 'DELETE FROM sysparametristored WHERE NomeStore IN (''Newexport_opzioni'', ''Newexport_colonne'', ''Dupexport'', ''Modexport_codice'')', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'exportcampi') = 1, 'DELETE FROM exportcampi WHERE NomeCampo = ''CategoriaPercorso''', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_stato') = 1, 'DROP TABLE `export_stato`', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne') = 1, 'DROP TABLE `export_colonne`', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni') = 1, 'DROP TABLE `export_opzioni`', 'DO 0');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_s = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_stato', 'export_colonne', 'export_opzioni')) = 0 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice')) = 0, 'SELECT ''EXPORT_FEED_DB_ROLLBACK_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_DB_ROLLBACK');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
```
