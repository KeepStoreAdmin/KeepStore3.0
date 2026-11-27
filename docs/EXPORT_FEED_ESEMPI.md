# EXPORT_FEED_ESEMPI - tre feed di esempio come dati (FEED-EXAMPLES-1A)

Stato: **SOURCE, script provati solo sul database LAB, non applicati a nessun database reale** (26/11/2026; esempio Google reso conforme dal task `GOOGLE-MERCHANT-CENTER-FEED-1A`). Per collegare l'esempio Google a Merchant Center vedi [GOOGLE_MERCHANT_CENTER_COLLEGAMENTO](GOOGLE_MERCHANT_CENTER_COLLEGAMENTO.md). Il motore va pubblicato sul server (`App_Code/KeepStoreFeedEngine.vb`) prima di usare i campi nuovi: senza, il feed Google risponde con un errore di configurazione (campo sconosciuto). CONSEGNA SERVER SOSPESA.

## 1. Che cosa fa
Crea, **per ogni azienda idonea**, tre feed di esempio **disabilitati** con le colonne richieste dalle specifiche di Google Merchant Center, Trovaprezzi / 7Pixel e idealo. Sono dati normali del gestionale (tabelle `export`, `export_opzioni`, `export_colonne`): il PO li **duplica** (pulsante Duplica) per fare il suo feed, oppure li **cancella**. Il motore non conosce nessun comparatore. Nessun feed esistente viene toccato.

Aziende idonee: `aziende.id` presente una volta, `URL1` non vuoto e presente **una sola volta** fra tutti gli URL1/URL2 (stessa regola con cui il motore sceglie l'azienda), `ListinoDefault` maggiore di 0. Le altre sono elencate come saltate. Ogni esempio si chiama `ESEMPIO <comparatore> (azienda <id>)`: se esiste gia una riga con quel nome (anche creata da altri) viene **saltata e mai adottata**.

Valori comuni degli esempi: abilitato **no**; listino = `ListinoDefault` dell'azienda; prezzi **IVA inclusa** (`IvaTipo` = 2: 1 = senza IVA, 2 = con IVA); solo articoli disponibili (giacenza minima 1); articoli senza immagine scartati; prezzo zero scartato; file valido 60 minuti; vettore = vettore web abilitato predefinito dell'azienda (0 se manca); spese fisse 0 e giorni di spedizione 0 (**da completare**).

## 2. Chi li esegue e in che ordine
1. **Il PO**, un database alla volta: blocco `20261126_EXPORT_FEED_ESEMPI_campi.sql` (atteso `EXPORT_FEED_CAMPI_OK`: registra quattro campi nel gestionale), poi `20261126_EXPORT_FEED_ESEMPI_esempi.sql` (atteso `EXPORT_FEED_ESEMPI_OK`), poi `20261126_EXPORT_FEED_ESEMPI_verify.sql` (atteso `EXPORT_FEED_ESEMPI_VERIFY_OK`). Per tornare indietro: `20261126_EXPORT_FEED_ESEMPI_rollback.sql` e `20261126_EXPORT_FEED_ESEMPI_campi_rollback.sql`, ognuno preceduto dalla sua conferma.
2. In SQLyog attivare **Halt Execution of Queries on Error**; dopo un errore chiudere la connessione prima di rilanciare (la sessione conserva le tabelle temporanee).
3. Privilegi dell'account che esegue: `SELECT` su `aziende`, `vettori`, `vettoricosti`, `export_stato`, `export_filtri`, `sysparametristored`; `SELECT`, `INSERT` su `export`, `export_opzioni`, `export_colonne`, `exportcampi` (e `DELETE` su `export` e `exportcampi` solo per i rollback); `CREATE TEMPORARY TABLES`.
4. Prerequisito: la struttura dei feed (tabelle `export_opzioni`, `export_colonne`, `export_stato`) gia presente; senza, lo script si ferma prima di scrivere.
5. Gli altri database: il programma di Enzo porta lo schema; i dati (esempi compresi) sono righe, quindi lo stesso script si lancia anche li, dopo il si del PO. Gli esempi sono dati opzionali: nessun database ne ha bisogno per funzionare.

## 3. Prima di abilitare un esempio (checklist)
- [ ] **Vettore**: nel gestionale scegliere il vettore dell'azienda con le fasce di costo (altrimenti la colonna delle spese resta vuota: `verify` lo segnala).
- [ ] **Giorni di spedizione**: oggi 0 (idealo scrive «0 giorni lavorativi»): mettere il valore reale.
- [ ] **idealo**: rinominare la colonna `deliveryCosts_dhl` con il vettore reale scelto fra quelli ammessi (`deutsche_post`, `dhl`, `dhl_go_green`, `download`, `dpd`, `fedex`, `german_express_logistics`, `gls`, `gls_think_green`, `hermes`, `pick_point`, `spedition`, `tnt`, `trans_o_flex`, `ups`).
- [ ] **Trovaprezzi / 7Pixel**: le intestazioni sono **da confermare** con l'account manager (la specifica non e pubblica).
- [ ] **Google**: motore aggiornato sul server, blocco `campi` lanciato, **titoli** letti nell'anteprima (quelli urlati diventano «Parola Parola»; sigle come `USB` diventano `Usb`: e il prezzo della regola senza elenchi; vedi il punto 1 delle note), poi la guida di collegamento. Non compilare `aziende.google_merchant_id` per il feed: serve al sondaggio Google Customer Reviews dopo l'ordine (vedi la guida).
- [ ] Controllare l'**anteprima** (le prime 20 righe) prima di comunicare il link.

## 4. Colonne (fonte di ogni scelta)
| Esempio | File | Colonne in ordine |
|---|---|---|
| Google Merchant | TSV (tabulazione), UTF-8, prima riga di intestazione | `id`, `title` (150, campo `TitoloNormalizzato`), `description` (5000, `#TitoloNormalizzato#. #DescrizioneSoloTesto#`), `link`, `image_link`, `availability` (`in_stock` / `out_of_stock`), `price` (`12.34 EUR`), `condition` (`new` / `refurbished`), `brand` (70), `gtin` (campo `EanValido`, vuoto se non valido), `mpn` (70, campo `Codice`), `product_type` (750), `shipping` (`IT::Standard:5.90 EUR`) |
| Trovaprezzi / 7Pixel | TXT con `|`, UTF-8, intestazione | Nome, Marca, Descrizione (testo semplice), Prezzo, Codice interno, Link, Disponibilita, Categoria, Immagine, Codice produttore, EAN (solo se valido), Spese di spedizione, Peso |
| idealo | CSV con `,` e virgolette `"`, UTF-8, intestazione | `sku`, `brand`, `title`, `categoryPath`, `url`, `eans` (solo se valido), `hans`, `description` (testo semplice), `price`, `deliveryCosts_dhl`, `delivery`, `imageUrl` |

Fonti (lette il 26/11/2026): Google, support.google.com/merchants/answer/7052112 (attributi), /14989239 (file con tabulazione: prima riga di intestazione, stesso numero di tabulazioni in ogni riga); idealo, idealo.github.io/csv-importer/en/csv/ (attributi, separatore `,`, UTF-8, `.` come decimale, valori multipli con `;`); Trovaprezzi / 7Pixel: nessuna specifica pubblica (fonte di seconda mano nell'audit dei feed). La descrizione e un modello titolo + testo semplice (mai vuota: se manca il testo lungo resta il titolo). **Campi nuovi del motore** (sono dati generici, nessun comparatore nel codice): `CondizioneInglese` (`refurbished` se l'articolo e ricondizionato, altrimenti `new`), `EanValido` (l'EAN solo se ha 8, 12, 13 o 14 cifre senza spazi ne trattini, cifra di controllo GS1 corretta, non tutto zero, e un prefisso ammesso: non `02`, `04`, `2`, `98`, `99`), `DescrizioneSoloTesto` (testo lungo senza commenti, script, stile e tag, entita decodificate una volta) e `TitoloNormalizzato` (se il titolo non ha nessuna lettera minuscola, ogni parola senza cifre diventa maiuscola iniziale; altrimenti resta com'e). I campi esistenti (`Condizione`, `Ean`, `DescrizioneLunga`, `Descrizione1`) non cambiano: i feed gia in uso restano identici. Il prezzo e l'offerta per 1 pezzo valida oggi, altrimenti il listino (stessa regola della scheda articolo, decisione del PO 2026-11-25). Le spese sono per articolo (fascia di peso del vettore, oppure 0 se il listino ha la spedizione gratis).

## 5. Limiti dichiarati (non cambiano che cosa fa lo script)
1. **Google e il tutto maiuscolo** (FEED-TITLES-1B, 27/11/2026): quasi tutto il catalogo e scritto «CATEGORIA IN MAIUSCOLO + dettagli». `TitoloNormalizzato` ricompone un titolo "urlato", cioe senza nessuna minuscola oppure con almeno il 60% di maiuscole contando solo le parole senza cifre di 5 o piu lettere (1.566 titoli su 1.680 esportabili del listino 1; un titolo normale come `Cavo HDMI SSD LED 2m` resta com'e). Ogni parola si ricompone per segmenti (spazio, `-`, `/`) con la maiuscola sulla prima lettera: `USB`, `HDMI`, `SSD`, `HP`, `TP-LINK`, `AC/DC` diventano `Usb`, `Hdmi`, `Ssd`, `Hp`, `Tp-Link`, `Ac/Dc`; i codici modello con cifre restano interi e una parola con una minuscola (`MagSafe`) resta. Limite: circa 114 titoli (testa urlata + coda mista, per esempio le candele) non raggiungono il 60% e restano. Soglia e regola sono scelte tecniche, non una prova di accettazione di Google.
2. **Google e gli identificativi**: circa 70 articoli su 1.569 (63 per lunghezza o caratteri, 7 per cifra di controllo, 4 per prefisso) non hanno un GTIN valido: il `gtin` resta vuoto e Google chiede allora brand e `mpn`. L'esempio scrive `mpn` = `Codice` (decisione del PO 2026-11-25: `Codice` e il codice produttore): **non provato** che ogni `Codice` sia un vero codice del produttore. `identifier_exists` non viene scritto. 14 valori di EAN compaiono su articoli diversi: Google puo segnalarli.
3. **Google, virgolette e testo**: 549 titoli contengono `"` (146 fra quelli esportabili). `TitoloNormalizzato` le sistema SEMPRE: una virgoletta dopo una cifra e un pollice e diventa `″` (U+2033) se il feed e utf-8 o xml (in iso-8859-1 e windows-1252 resta `"`: mai un punto interrogativo); le altre sono citazioni e diventano `« »` a coppie, oppure `'` se sono in numero dispari. `DescrizioneSoloTesto` e gli altri campi NON si toccano (la usano anche gli esempi Trovaprezzi e idealo): le virgolette dentro il corpo della descrizione restano, da controllare nella diagnostica. Una chiusura dopo cifra (`"Techno1"`) e letta come pollici. Le descrizioni lunghe con HTML (7 su 1.569) e le entita (78) sono ripulite da `DescrizioneSoloTesto`; il testo letterale `<2kg` resta.
4. **Specifiche non verificabili**: intestazioni e decimale di Trovaprezzi / 7Pixel; uso delle virgolette in idealo (non dichiarato: si usa lo standard CSV); regole di Google applicate solo come pubblicate, senza prova dentro Merchant Center.
5. Provato su MySQL 8.0.46 del LAB (registro binario spento), non sul gestionale vero (solo le routine `Dupexport` e le tabelle sul LAB).
6. Gli esempi non sono pubblici finche disabilitati; la risposta del sito per un feed disabilitato e 404 (la configurazione resta in cache fino a 60 secondi).

## 20261126_EXPORT_FEED_ESEMPI_campi.sql

```sql
-- EXPORT-FEED-ESEMPI (campi): registra in exportcampi i quattro campi nuovi del motore (CondizioneInglese, EanValido, DescrizioneSoloTesto, TitoloNormalizzato).
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento. Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini
-- o account; nessun DEFINER. Lo esegue il Product Owner, un database alla volta, PRIMA di usare gli esempi dal gestionale. Il motore del sito capisce i campi anche senza questa riga: serve soltanto perche il gestionale li proponga.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa (la sessione conserva variabili e tabelle temporanee).
-- Serve MySQL 8.0.19 o successivo (non MariaDB). Gli esempi si creano DISABILITATI e non si abilitano da soli.
-- Aggiunge solo le righe assenti (una transazione), non tocca altro. Esito atteso: EXPORT_FEED_CAMPI_OK. Ripetibile.

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_go = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_go = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'exportcampi') = 1 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'exportcampi' AND COLUMN_NAME = 'NomeCampo' AND COLUMN_TYPE = 'varchar(20)' AND COLUMN_KEY = 'PRI') = 1, 1, 0);
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_CAMPI_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_CAMPI_STRUTTURA');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

START TRANSACTION;
INSERT INTO exportcampi (NomeCampo) SELECT v.n FROM (SELECT 'CondizioneInglese' AS n UNION ALL SELECT 'EanValido' AS n UNION ALL SELECT 'DescrizioneSoloTesto' AS n UNION ALL SELECT 'TitoloNormalizzato' AS n) v WHERE @ks_go = 1 AND NOT EXISTS (SELECT 1 FROM exportcampi e WHERE e.NomeCampo = v.n);
SET @ks_s = IF((SELECT COUNT(*) FROM exportcampi WHERE NomeCampo IN ('CondizioneInglese', 'EanValido', 'DescrizioneSoloTesto', 'TitoloNormalizzato')) = 4, 'SELECT ''EXPORT_FEED_CAMPI_CONTROLLO_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_CAMPI_CONTROLLO');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
COMMIT;
SELECT 'EXPORT_FEED_CAMPI_OK' AS Esito, (SELECT COUNT(*) FROM exportcampi) AS CampiInTutto;
```

## 20261126_EXPORT_FEED_ESEMPI_esempi.sql

```sql
-- EXPORT-FEED-ESEMPI (esempi): crea per ogni azienda idonea tre feed di esempio DISABILITATI (Google Merchant, Trovaprezzi 7Pixel, idealo).
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento. Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini
-- o account; nessun DEFINER. Lo esegue il Product Owner, un database alla volta, dopo il suo si esplicito. Non tocca nessun feed esistente: un feed con la stessa descrizione viene saltato (mai adottato). Ripetibile.
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa (la sessione conserva variabili e tabelle temporanee).
-- Serve MySQL 8.0.19 o successivo (non MariaDB). Gli esempi si creano DISABILITATI e non si abilitano da soli.
-- Aziende idonee: id unico, URL1 non vuoto e presente UNA sola volta fra tutti URL1 e URL2, ListinoDefault > 0; le altre sono elencate come saltate. Una sola transazione, controllo PRIMA del COMMIT.
-- Esito atteso: EXPORT_FEED_ESEMPI_OK. Poi: lanciare verify, completare gli esempi nel gestionale (vettore, giorni, nome della colonna delle spese di idealo) e abilitarli SOLO dopo.

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_go = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_go = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export', 'export_opzioni', 'export_colonne', 'export_stato', 'aziende', 'vettori', 'vettoricosti') AND ENGINE = 'InnoDB') = 7 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_filtri', 'sysparametristored')) = 2 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME IN ('ID', 'Descrizione', 'Password', 'FormatString', 'NListino', 'NListino2', 'IvaTipo', 'Giacenza', 'SpeseSpedizione', 'GiorniSpedizione', 'Azienda', 'Tipo', 'IdVettore', 'Tutto_in_minuscolo', 'Google', 'Amazon', 'NoVettoreSuGratis', 'Abilitato')) = 18 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende' AND COLUMN_NAME IN ('id', 'URL1', 'URL2', 'ListinoDefault')) = 4 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vettori' AND COLUMN_NAME IN ('id', 'AziendeId', 'Abilitato', 'Web', 'Predefinito', 'Ordinamento')) = 6 AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni') = 'Id,ExportId,TokenAccesso,Separatore,DelimitatoreTesto,Codifica,SeparatoreDecimale,Intestazione,XmlRadice,XmlElemento,TogliHtml,MinutiCache,ParolaDisponibile,ParolaInArrivo,ParolaNonDisponibile,SenzaImmagine,SenzaEan,PrezzoZero' AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME, ' ', COLUMN_TYPE) ORDER BY ORDINAL_POSITION SEPARATOR ',') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne') = 'Id int,ExportId int,Posizione int,TitoloColonna varchar(60),Campo varchar(40),Prefisso varchar(40),Suffisso varchar(40),ValoreFisso varchar(100),MassimoCaratteri int,SeVuoto varchar(100)', 1, 0);
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_ESEMPI_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_ESEMPI_STRUTTURA');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

SET SESSION group_concat_max_len = 1000000;
DROP TEMPORARY TABLE IF EXISTS ks_ex_tipo, ks_ex_col, ks_ex_colsig, ks_ex_az, ks_ex_atteso, ks_ex_nuovi, ks_ex_trovato;
CREATE TEMPORARY TABLE ks_ex_tipo (Chiave CHAR(1) NOT NULL PRIMARY KEY, Ordine INT NOT NULL, Descrizione VARCHAR(60) NOT NULL, Tipo CHAR(3) NOT NULL, Separatore VARCHAR(5) NOT NULL, DelimitatoreTesto VARCHAR(1) NOT NULL, Codifica VARCHAR(10) NOT NULL, SeparatoreDecimale VARCHAR(1) NOT NULL, Intestazione INT NOT NULL, TogliHtml INT NOT NULL, MinutiCache INT NOT NULL, ParolaDisponibile VARCHAR(40) NOT NULL, ParolaInArrivo VARCHAR(40) NOT NULL, ParolaNonDisponibile VARCHAR(40) NOT NULL, SenzaImmagine INT NOT NULL, SenzaEan INT NOT NULL, PrezzoZero INT NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_tipo VALUES
('G', 1, 'ESEMPIO Google Merchant', 'tsv', '|', '', 'utf-8', '.', 1, 1, 60, 'in_stock', 'out_of_stock', 'out_of_stock', 1, 0, 1),
('T', 2, 'ESEMPIO Trovaprezzi 7Pixel', 'txt', '|', '', 'utf-8', '.', 1, 1, 60, 'Disponibile', 'In arrivo', 'Non disponibile', 1, 0, 1),
('I', 3, 'ESEMPIO idealo', 'csv', ',', '"', 'utf-8', '.', 1, 1, 60, 'Disponibile', 'In arrivo', 'Non disponibile', 1, 0, 1);
CREATE TEMPORARY TABLE ks_ex_col (Chiave CHAR(1) NOT NULL, Posizione INT NOT NULL, TitoloColonna VARCHAR(60) NOT NULL, Campo VARCHAR(40) NOT NULL, Prefisso VARCHAR(40) NOT NULL, Suffisso VARCHAR(40) NOT NULL, ValoreFisso VARCHAR(100) NOT NULL, MassimoCaratteri INT NULL, SeVuoto VARCHAR(100) NOT NULL, PRIMARY KEY (Chiave, Posizione)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_col VALUES
('G', 1, 'id', 'Id', '', '', '', NULL, ''),
('G', 2, 'title', 'TitoloNormalizzato', '', '', '', 150, ''),
('G', 3, 'description', '', '', '', '#TitoloNormalizzato#. #DescrizioneSoloTesto#', 5000, ''),
('G', 4, 'link', 'Link', '', '', '', NULL, ''),
('G', 5, 'image_link', 'UrlImgBig', '', '', '', NULL, ''),
('G', 6, 'availability', 'Disponibilita', '', '', '', NULL, ''),
('G', 7, 'price', 'Prezzo', '', ' EUR', '', NULL, ''),
('G', 8, 'condition', 'CondizioneInglese', '', '', '', NULL, ''),
('G', 9, 'brand', 'Marca', '', '', '', 70, ''),
('G', 10, 'gtin', 'EanValido', '', '', '', NULL, ''),
('G', 11, 'mpn', 'Codice', '', '', '', 70, ''),
('G', 12, 'product_type', 'CategoriaPercorso', '', '', '', 750, ''),
('G', 13, 'shipping', 'CostoSpedizioneProdo', 'IT::Standard:', ' EUR', '', NULL, ''),
('T', 1, 'Nome', 'Descrizione1', '', '', '', NULL, ''),
('T', 2, 'Marca', 'Marca', '', '', '', NULL, ''),
('T', 3, 'Descrizione', '', '', '', '#Descrizione1#. #DescrizioneSoloTesto#', NULL, ''),
('T', 4, 'Prezzo', 'Prezzo', '', '', '', NULL, ''),
('T', 5, 'Codice interno', 'Id', '', '', '', NULL, ''),
('T', 6, 'Link', 'Link', '', '', '', NULL, ''),
('T', 7, 'Disponibilita', 'Disponibilita', '', '', '', NULL, ''),
('T', 8, 'Categoria', 'CategoriaPercorso', '', '', '', NULL, ''),
('T', 9, 'Immagine', 'UrlImgBig', '', '', '', NULL, ''),
('T', 10, 'Codice produttore', 'Codice', '', '', '', NULL, ''),
('T', 11, 'EAN', 'EanValido', '', '', '', NULL, ''),
('T', 12, 'Spese di spedizione', 'CostoSpedizioneProdo', '', '', '', NULL, ''),
('T', 13, 'Peso', 'Peso', '', '', '', NULL, ''),
('I', 1, 'sku', 'Id', '', '', '', NULL, ''),
('I', 2, 'brand', 'Marca', '', '', '', NULL, ''),
('I', 3, 'title', 'Descrizione1', '', '', '', NULL, ''),
('I', 4, 'categoryPath', 'CategoriaPercorso', '', '', '', NULL, ''),
('I', 5, 'url', 'Link', '', '', '', NULL, ''),
('I', 6, 'eans', 'EanValido', '', '', '', NULL, ''),
('I', 7, 'hans', 'Codice', '', '', '', NULL, ''),
('I', 8, 'description', '', '', '', '#Descrizione1#. #DescrizioneSoloTesto#', NULL, ''),
('I', 9, 'price', 'Prezzo', '', '', '', NULL, ''),
('I', 10, 'deliveryCosts_dhl', 'CostoSpedizioneProdo', '', '', '', NULL, ''),
('I', 11, 'delivery', 'GiorniSpedizione', '', ' giorni lavorativi', '', NULL, ''),
('I', 12, 'imageUrl', 'UrlImgBig', '', '', '', NULL, '');
CREATE TEMPORARY TABLE ks_ex_colsig (Chiave CHAR(1) NOT NULL PRIMARY KEY, NCol INT NOT NULL, FormatString VARCHAR(3000) NOT NULL, ColFirma CHAR(32) NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_colsig SELECT c.Chiave, COUNT(*), GROUP_CONCAT(IF(c.Campo <> '', CONCAT('#', c.Campo, '#'), c.ValoreFisso) ORDER BY c.Posizione SEPARATOR '|'), MD5(GROUP_CONCAT(CONCAT_WS(CHAR(31), c.Posizione, c.TitoloColonna, c.Campo, c.Prefisso, c.Suffisso, c.ValoreFisso, IFNULL(c.MassimoCaratteri, '~'), c.SeVuoto) ORDER BY c.Posizione SEPARATOR '~~')) FROM ks_ex_col c GROUP BY c.Chiave;
CREATE TEMPORARY TABLE ks_ex_az (AziendaId INT NOT NULL PRIMARY KEY, Dominio VARCHAR(100) NOT NULL, Listino INT NOT NULL, IdVettore INT NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_az SELECT a.id, TRIM(a.URL1), a.ListinoDefault, COALESCE((SELECT v.id FROM vettori v WHERE v.AziendeId = a.id AND v.Abilitato = 1 AND v.Web = 1 ORDER BY v.Predefinito DESC, v.Ordinamento, v.id LIMIT 1), 0) FROM aziende a WHERE a.id > 0 AND TRIM(COALESCE(a.URL1, '')) <> '' AND CHAR_LENGTH(TRIM(a.URL1)) <= 100 AND COALESCE(a.ListinoDefault, 0) > 0 AND (SELECT COUNT(*) FROM aziende b WHERE b.id = a.id) = 1 AND (SELECT COUNT(*) FROM aziende b WHERE LOWER(TRIM(b.URL1)) = LOWER(TRIM(a.URL1)) OR LOWER(TRIM(b.URL2)) = LOWER(TRIM(a.URL1))) = 1;
CREATE TEMPORARY TABLE ks_ex_atteso (AziendaId INT NOT NULL, Chiave CHAR(1) NOT NULL, Ordine INT NOT NULL, Descrizione VARCHAR(100) NOT NULL, Tipo CHAR(3) NOT NULL, Dominio VARCHAR(100) NOT NULL, Listino INT NOT NULL, IdVettore INT NOT NULL, FormatString VARCHAR(3000) NOT NULL, NCol INT NOT NULL, ColFirma CHAR(32) NOT NULL, ExportFirma CHAR(32) NOT NULL, OpzFirma CHAR(32) NOT NULL, Presente INT NOT NULL DEFAULT 0, PRIMARY KEY (AziendaId, Chiave)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_atteso (AziendaId, Chiave, Ordine, Descrizione, Tipo, Dominio, Listino, IdVettore, FormatString, NCol, ColFirma, ExportFirma, OpzFirma) SELECT a.AziendaId, t.Chiave, t.Ordine, CONCAT(t.Descrizione, ' (azienda ', a.AziendaId, ')'), t.Tipo, a.Dominio, a.Listino, a.IdVettore, s.FormatString, s.NCol, s.ColFirma, MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(CONCAT(t.Descrizione, ' (azienda ', a.AziendaId, ')') AS CHAR), '~'), IFNULL(CAST('' AS CHAR), '~'), IFNULL(CAST(s.FormatString AS CHAR), '~'), IFNULL(CAST(a.Listino AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(2 AS CHAR), '~'), IFNULL(CAST(CAST(1 AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(CAST(0 AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(a.Dominio AS CHAR), '~'), IFNULL(CAST(t.Tipo AS CHAR), '~'), IFNULL(CAST(a.IdVettore AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'))), MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(t.Separatore AS CHAR), '~'), IFNULL(CAST(t.DelimitatoreTesto AS CHAR), '~'), IFNULL(CAST(t.Codifica AS CHAR), '~'), IFNULL(CAST(t.SeparatoreDecimale AS CHAR), '~'), IFNULL(CAST(t.Intestazione AS CHAR), '~'), IFNULL(CAST('prodotti' AS CHAR), '~'), IFNULL(CAST('prodotto' AS CHAR), '~'), IFNULL(CAST(t.TogliHtml AS CHAR), '~'), IFNULL(CAST(t.MinutiCache AS CHAR), '~'), IFNULL(CAST(t.ParolaDisponibile AS CHAR), '~'), IFNULL(CAST(t.ParolaInArrivo AS CHAR), '~'), IFNULL(CAST(t.ParolaNonDisponibile AS CHAR), '~'), IFNULL(CAST(t.SenzaImmagine AS CHAR), '~'), IFNULL(CAST(t.SenzaEan AS CHAR), '~'), IFNULL(CAST(t.PrezzoZero AS CHAR), '~'))) FROM ks_ex_az a JOIN ks_ex_tipo t JOIN ks_ex_colsig s ON s.Chiave = t.Chiave;
UPDATE ks_ex_atteso x SET x.Presente = IF(EXISTS (SELECT 1 FROM `export` e WHERE e.Descrizione = x.Descrizione), 1, 0);

-- SCRITTURA: una transazione; i tre INSERT e il controllo sono sullo stesso insieme di feed nuovi (id maggiore del massimo letto prima).
START TRANSACTION;
SET @ks_max = (SELECT COALESCE(MAX(ID), 0) FROM `export`);
INSERT INTO `export` (Descrizione, Password, FormatString, NListino, NListino2, IvaTipo, Giacenza, SpeseSpedizione, GiorniSpedizione, Azienda, Tipo, IdVettore, Tutto_in_minuscolo, Google, Amazon, NoVettoreSuGratis, Abilitato)
SELECT x.Descrizione, '', x.FormatString, x.Listino, 0, 2, 1, 0, 0, x.Dominio, x.Tipo, x.IdVettore, 0, 0, 0, 0, 0 FROM ks_ex_atteso x WHERE @ks_go = 1 AND x.Presente = 0 ORDER BY x.AziendaId, x.Ordine;
CREATE TEMPORARY TABLE ks_ex_nuovi (ExportId INT NOT NULL PRIMARY KEY, Chiave CHAR(1) NOT NULL, Descrizione VARCHAR(100) NOT NULL, NCol INT NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_nuovi SELECT e.ID, x.Chiave, x.Descrizione, x.NCol FROM `export` e JOIN ks_ex_atteso x ON x.Descrizione = e.Descrizione WHERE @ks_go = 1 AND x.Presente = 0 AND e.ID > @ks_max AND COALESCE(e.Abilitato, 0) = 0;
INSERT INTO export_opzioni (ExportId, Separatore, DelimitatoreTesto, Codifica, SeparatoreDecimale, Intestazione, XmlRadice, XmlElemento, TogliHtml, MinutiCache, ParolaDisponibile, ParolaInArrivo, ParolaNonDisponibile, SenzaImmagine, SenzaEan, PrezzoZero)
SELECT n.ExportId, t.Separatore, t.DelimitatoreTesto, t.Codifica, t.SeparatoreDecimale, t.Intestazione, 'prodotti', 'prodotto', t.TogliHtml, t.MinutiCache, t.ParolaDisponibile, t.ParolaInArrivo, t.ParolaNonDisponibile, t.SenzaImmagine, t.SenzaEan, t.PrezzoZero FROM ks_ex_nuovi n JOIN ks_ex_tipo t ON t.Chiave = n.Chiave ORDER BY n.ExportId;
INSERT INTO export_colonne (ExportId, Posizione, TitoloColonna, Campo, Prefisso, Suffisso, ValoreFisso, MassimoCaratteri, SeVuoto)
SELECT n.ExportId, c.Posizione, c.TitoloColonna, c.Campo, c.Prefisso, c.Suffisso, c.ValoreFisso, c.MassimoCaratteri, c.SeVuoto FROM ks_ex_nuovi n JOIN ks_ex_col c ON c.Chiave = n.Chiave ORDER BY n.ExportId, c.Posizione;
-- CONTROLLO PRIMA DEL COMMIT: ogni feed nuovo ha UNA riga di opzioni con codice valido (48 esadecimali maiuscoli), tutte le sue colonne, e resta disabilitato. Se no: arresto, la connessione chiusa annulla tutto.
SET @ks_s = IF((SELECT COUNT(*) FROM ks_ex_nuovi n WHERE (SELECT COUNT(*) FROM export_opzioni o WHERE o.ExportId = n.ExportId AND o.TokenAccesso REGEXP '^[0-9A-F]{48}$') <> 1 OR (SELECT COUNT(*) FROM export_colonne k WHERE k.ExportId = n.ExportId) <> n.NCol OR (SELECT COALESCE(e.Abilitato, 0) FROM `export` e WHERE e.ID = n.ExportId) <> 0) = 0, 'SELECT ''EXPORT_FEED_ESEMPI_CONTROLLO_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_ESEMPI_CONTROLLO');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
COMMIT;

-- ESITO (una tabella temporanea non si puo citare due volte nella stessa interrogazione: i conteggi passano da variabili)
SET @ks_creati = (SELECT COUNT(*) FROM ks_ex_nuovi);
SET @ks_presenti = (SELECT COUNT(*) FROM ks_ex_atteso WHERE Presente = 1);
SET @ks_idonee = (SELECT COUNT(*) FROM ks_ex_az);
SELECT 'EXPORT_FEED_ESEMPI_OK' AS Esito, @ks_creati AS Creati, @ks_presenti AS GiaPresentiSaltati, @ks_idonee AS AziendeIdonee, (SELECT COUNT(*) FROM aziende) - @ks_idonee AS AziendeSaltate;
SELECT n.ExportId, n.Descrizione FROM ks_ex_nuovi n ORDER BY n.ExportId;
SELECT a.id AS AziendaSaltata FROM aziende a WHERE a.id NOT IN (SELECT z.AziendaId FROM ks_ex_az z) ORDER BY a.id;
```

## 20261126_EXPORT_FEED_ESEMPI_verify.sql

```sql
-- EXPORT-FEED-ESEMPI (verify): solo lettura. Dice quali esempi ci sono, se sono intatti e che cosa manca prima di abilitarli.
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento. Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini
-- o account; nessun DEFINER. Lo esegue il Product Owner dopo esempi, e ogni volta che completa un esempio. Non scrive nulla nelle tabelle del database (usa solo tabelle temporanee).
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa (la sessione conserva variabili e tabelle temporanee).
-- Serve MySQL 8.0.19 o successivo (non MariaDB). Gli esempi si creano DISABILITATI e non si abilitano da soli.
-- Righe ATTENZIONE = da completare, non errori. Il verdetto EXPORT_FEED_ESEMPI_VERIFY_OK dice solo che la struttura e gli esempi presenti sono coerenti.

SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_go = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_go = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export', 'export_opzioni', 'export_colonne', 'export_stato', 'aziende', 'vettori', 'vettoricosti') AND ENGINE = 'InnoDB') = 7 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_filtri', 'sysparametristored')) = 2 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME IN ('ID', 'Descrizione', 'Password', 'FormatString', 'NListino', 'NListino2', 'IvaTipo', 'Giacenza', 'SpeseSpedizione', 'GiorniSpedizione', 'Azienda', 'Tipo', 'IdVettore', 'Tutto_in_minuscolo', 'Google', 'Amazon', 'NoVettoreSuGratis', 'Abilitato')) = 18 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende' AND COLUMN_NAME IN ('id', 'URL1', 'URL2', 'ListinoDefault')) = 4 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vettori' AND COLUMN_NAME IN ('id', 'AziendeId', 'Abilitato', 'Web', 'Predefinito', 'Ordinamento')) = 6 AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni') = 'Id,ExportId,TokenAccesso,Separatore,DelimitatoreTesto,Codifica,SeparatoreDecimale,Intestazione,XmlRadice,XmlElemento,TogliHtml,MinutiCache,ParolaDisponibile,ParolaInArrivo,ParolaNonDisponibile,SenzaImmagine,SenzaEan,PrezzoZero' AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME, ' ', COLUMN_TYPE) ORDER BY ORDINAL_POSITION SEPARATOR ',') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne') = 'Id int,ExportId int,Posizione int,TitoloColonna varchar(60),Campo varchar(40),Prefisso varchar(40),Suffisso varchar(40),ValoreFisso varchar(100),MassimoCaratteri int,SeVuoto varchar(100)', 1, 0);
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_ESEMPI_VERIFY_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_ESEMPI_VERIFY_STRUTTURA');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

SET SESSION group_concat_max_len = 1000000;
DROP TEMPORARY TABLE IF EXISTS ks_ex_tipo, ks_ex_col, ks_ex_colsig, ks_ex_az, ks_ex_atteso, ks_ex_nuovi, ks_ex_trovato;
CREATE TEMPORARY TABLE ks_ex_tipo (Chiave CHAR(1) NOT NULL PRIMARY KEY, Ordine INT NOT NULL, Descrizione VARCHAR(60) NOT NULL, Tipo CHAR(3) NOT NULL, Separatore VARCHAR(5) NOT NULL, DelimitatoreTesto VARCHAR(1) NOT NULL, Codifica VARCHAR(10) NOT NULL, SeparatoreDecimale VARCHAR(1) NOT NULL, Intestazione INT NOT NULL, TogliHtml INT NOT NULL, MinutiCache INT NOT NULL, ParolaDisponibile VARCHAR(40) NOT NULL, ParolaInArrivo VARCHAR(40) NOT NULL, ParolaNonDisponibile VARCHAR(40) NOT NULL, SenzaImmagine INT NOT NULL, SenzaEan INT NOT NULL, PrezzoZero INT NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_tipo VALUES
('G', 1, 'ESEMPIO Google Merchant', 'tsv', '|', '', 'utf-8', '.', 1, 1, 60, 'in_stock', 'out_of_stock', 'out_of_stock', 1, 0, 1),
('T', 2, 'ESEMPIO Trovaprezzi 7Pixel', 'txt', '|', '', 'utf-8', '.', 1, 1, 60, 'Disponibile', 'In arrivo', 'Non disponibile', 1, 0, 1),
('I', 3, 'ESEMPIO idealo', 'csv', ',', '"', 'utf-8', '.', 1, 1, 60, 'Disponibile', 'In arrivo', 'Non disponibile', 1, 0, 1);
CREATE TEMPORARY TABLE ks_ex_col (Chiave CHAR(1) NOT NULL, Posizione INT NOT NULL, TitoloColonna VARCHAR(60) NOT NULL, Campo VARCHAR(40) NOT NULL, Prefisso VARCHAR(40) NOT NULL, Suffisso VARCHAR(40) NOT NULL, ValoreFisso VARCHAR(100) NOT NULL, MassimoCaratteri INT NULL, SeVuoto VARCHAR(100) NOT NULL, PRIMARY KEY (Chiave, Posizione)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_col VALUES
('G', 1, 'id', 'Id', '', '', '', NULL, ''),
('G', 2, 'title', 'TitoloNormalizzato', '', '', '', 150, ''),
('G', 3, 'description', '', '', '', '#TitoloNormalizzato#. #DescrizioneSoloTesto#', 5000, ''),
('G', 4, 'link', 'Link', '', '', '', NULL, ''),
('G', 5, 'image_link', 'UrlImgBig', '', '', '', NULL, ''),
('G', 6, 'availability', 'Disponibilita', '', '', '', NULL, ''),
('G', 7, 'price', 'Prezzo', '', ' EUR', '', NULL, ''),
('G', 8, 'condition', 'CondizioneInglese', '', '', '', NULL, ''),
('G', 9, 'brand', 'Marca', '', '', '', 70, ''),
('G', 10, 'gtin', 'EanValido', '', '', '', NULL, ''),
('G', 11, 'mpn', 'Codice', '', '', '', 70, ''),
('G', 12, 'product_type', 'CategoriaPercorso', '', '', '', 750, ''),
('G', 13, 'shipping', 'CostoSpedizioneProdo', 'IT::Standard:', ' EUR', '', NULL, ''),
('T', 1, 'Nome', 'Descrizione1', '', '', '', NULL, ''),
('T', 2, 'Marca', 'Marca', '', '', '', NULL, ''),
('T', 3, 'Descrizione', '', '', '', '#Descrizione1#. #DescrizioneSoloTesto#', NULL, ''),
('T', 4, 'Prezzo', 'Prezzo', '', '', '', NULL, ''),
('T', 5, 'Codice interno', 'Id', '', '', '', NULL, ''),
('T', 6, 'Link', 'Link', '', '', '', NULL, ''),
('T', 7, 'Disponibilita', 'Disponibilita', '', '', '', NULL, ''),
('T', 8, 'Categoria', 'CategoriaPercorso', '', '', '', NULL, ''),
('T', 9, 'Immagine', 'UrlImgBig', '', '', '', NULL, ''),
('T', 10, 'Codice produttore', 'Codice', '', '', '', NULL, ''),
('T', 11, 'EAN', 'EanValido', '', '', '', NULL, ''),
('T', 12, 'Spese di spedizione', 'CostoSpedizioneProdo', '', '', '', NULL, ''),
('T', 13, 'Peso', 'Peso', '', '', '', NULL, ''),
('I', 1, 'sku', 'Id', '', '', '', NULL, ''),
('I', 2, 'brand', 'Marca', '', '', '', NULL, ''),
('I', 3, 'title', 'Descrizione1', '', '', '', NULL, ''),
('I', 4, 'categoryPath', 'CategoriaPercorso', '', '', '', NULL, ''),
('I', 5, 'url', 'Link', '', '', '', NULL, ''),
('I', 6, 'eans', 'EanValido', '', '', '', NULL, ''),
('I', 7, 'hans', 'Codice', '', '', '', NULL, ''),
('I', 8, 'description', '', '', '', '#Descrizione1#. #DescrizioneSoloTesto#', NULL, ''),
('I', 9, 'price', 'Prezzo', '', '', '', NULL, ''),
('I', 10, 'deliveryCosts_dhl', 'CostoSpedizioneProdo', '', '', '', NULL, ''),
('I', 11, 'delivery', 'GiorniSpedizione', '', ' giorni lavorativi', '', NULL, ''),
('I', 12, 'imageUrl', 'UrlImgBig', '', '', '', NULL, '');
CREATE TEMPORARY TABLE ks_ex_colsig (Chiave CHAR(1) NOT NULL PRIMARY KEY, NCol INT NOT NULL, FormatString VARCHAR(3000) NOT NULL, ColFirma CHAR(32) NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_colsig SELECT c.Chiave, COUNT(*), GROUP_CONCAT(IF(c.Campo <> '', CONCAT('#', c.Campo, '#'), c.ValoreFisso) ORDER BY c.Posizione SEPARATOR '|'), MD5(GROUP_CONCAT(CONCAT_WS(CHAR(31), c.Posizione, c.TitoloColonna, c.Campo, c.Prefisso, c.Suffisso, c.ValoreFisso, IFNULL(c.MassimoCaratteri, '~'), c.SeVuoto) ORDER BY c.Posizione SEPARATOR '~~')) FROM ks_ex_col c GROUP BY c.Chiave;
CREATE TEMPORARY TABLE ks_ex_az (AziendaId INT NOT NULL PRIMARY KEY, Dominio VARCHAR(100) NOT NULL, Listino INT NOT NULL, IdVettore INT NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_az SELECT a.id, TRIM(a.URL1), a.ListinoDefault, COALESCE((SELECT v.id FROM vettori v WHERE v.AziendeId = a.id AND v.Abilitato = 1 AND v.Web = 1 ORDER BY v.Predefinito DESC, v.Ordinamento, v.id LIMIT 1), 0) FROM aziende a WHERE a.id > 0 AND TRIM(COALESCE(a.URL1, '')) <> '' AND CHAR_LENGTH(TRIM(a.URL1)) <= 100 AND COALESCE(a.ListinoDefault, 0) > 0 AND (SELECT COUNT(*) FROM aziende b WHERE b.id = a.id) = 1 AND (SELECT COUNT(*) FROM aziende b WHERE LOWER(TRIM(b.URL1)) = LOWER(TRIM(a.URL1)) OR LOWER(TRIM(b.URL2)) = LOWER(TRIM(a.URL1))) = 1;
CREATE TEMPORARY TABLE ks_ex_atteso (AziendaId INT NOT NULL, Chiave CHAR(1) NOT NULL, Ordine INT NOT NULL, Descrizione VARCHAR(100) NOT NULL, Tipo CHAR(3) NOT NULL, Dominio VARCHAR(100) NOT NULL, Listino INT NOT NULL, IdVettore INT NOT NULL, FormatString VARCHAR(3000) NOT NULL, NCol INT NOT NULL, ColFirma CHAR(32) NOT NULL, ExportFirma CHAR(32) NOT NULL, OpzFirma CHAR(32) NOT NULL, Presente INT NOT NULL DEFAULT 0, PRIMARY KEY (AziendaId, Chiave)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_atteso (AziendaId, Chiave, Ordine, Descrizione, Tipo, Dominio, Listino, IdVettore, FormatString, NCol, ColFirma, ExportFirma, OpzFirma) SELECT a.AziendaId, t.Chiave, t.Ordine, CONCAT(t.Descrizione, ' (azienda ', a.AziendaId, ')'), t.Tipo, a.Dominio, a.Listino, a.IdVettore, s.FormatString, s.NCol, s.ColFirma, MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(CONCAT(t.Descrizione, ' (azienda ', a.AziendaId, ')') AS CHAR), '~'), IFNULL(CAST('' AS CHAR), '~'), IFNULL(CAST(s.FormatString AS CHAR), '~'), IFNULL(CAST(a.Listino AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(2 AS CHAR), '~'), IFNULL(CAST(CAST(1 AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(CAST(0 AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(a.Dominio AS CHAR), '~'), IFNULL(CAST(t.Tipo AS CHAR), '~'), IFNULL(CAST(a.IdVettore AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'))), MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(t.Separatore AS CHAR), '~'), IFNULL(CAST(t.DelimitatoreTesto AS CHAR), '~'), IFNULL(CAST(t.Codifica AS CHAR), '~'), IFNULL(CAST(t.SeparatoreDecimale AS CHAR), '~'), IFNULL(CAST(t.Intestazione AS CHAR), '~'), IFNULL(CAST('prodotti' AS CHAR), '~'), IFNULL(CAST('prodotto' AS CHAR), '~'), IFNULL(CAST(t.TogliHtml AS CHAR), '~'), IFNULL(CAST(t.MinutiCache AS CHAR), '~'), IFNULL(CAST(t.ParolaDisponibile AS CHAR), '~'), IFNULL(CAST(t.ParolaInArrivo AS CHAR), '~'), IFNULL(CAST(t.ParolaNonDisponibile AS CHAR), '~'), IFNULL(CAST(t.SenzaImmagine AS CHAR), '~'), IFNULL(CAST(t.SenzaEan AS CHAR), '~'), IFNULL(CAST(t.PrezzoZero AS CHAR), '~'))) FROM ks_ex_az a JOIN ks_ex_tipo t JOIN ks_ex_colsig s ON s.Chiave = t.Chiave;
UPDATE ks_ex_atteso x SET x.Presente = IF(EXISTS (SELECT 1 FROM `export` e WHERE e.Descrizione = x.Descrizione), 1, 0);
CREATE TEMPORARY TABLE ks_ex_trovato (ExportId INT NOT NULL PRIMARY KEY, AziendaId INT NOT NULL, Chiave CHAR(1) NOT NULL, Descrizione VARCHAR(100) NOT NULL, Abilitato INT NOT NULL, Identico INT NOT NULL, ConStato INT NOT NULL, ConFiltri INT NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_trovato SELECT e.ID, x.AziendaId, x.Chiave, x.Descrizione, COALESCE(e.Abilitato, 0), IF(MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(e.Descrizione AS CHAR), '~'), IFNULL(CAST(e.Password AS CHAR), '~'), IFNULL(CAST(e.FormatString AS CHAR), '~'), IFNULL(CAST(e.NListino AS CHAR), '~'), IFNULL(CAST(e.NListino2 AS CHAR), '~'), IFNULL(CAST(e.IvaTipo AS CHAR), '~'), IFNULL(CAST(CAST(e.Giacenza AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(CAST(e.SpeseSpedizione AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(e.GiorniSpedizione AS CHAR), '~'), IFNULL(CAST(e.Azienda AS CHAR), '~'), IFNULL(CAST(e.Tipo AS CHAR), '~'), IFNULL(CAST(e.IdVettore AS CHAR), '~'), IFNULL(CAST(e.Tutto_in_minuscolo AS CHAR), '~'), IFNULL(CAST(e.Google AS CHAR), '~'), IFNULL(CAST(e.Amazon AS CHAR), '~'), IFNULL(CAST(e.NoVettoreSuGratis AS CHAR), '~'), IFNULL(CAST(e.Abilitato AS CHAR), '~'))) = x.ExportFirma AND (SELECT MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(o.Separatore AS CHAR), '~'), IFNULL(CAST(o.DelimitatoreTesto AS CHAR), '~'), IFNULL(CAST(o.Codifica AS CHAR), '~'), IFNULL(CAST(o.SeparatoreDecimale AS CHAR), '~'), IFNULL(CAST(o.Intestazione AS CHAR), '~'), IFNULL(CAST(o.XmlRadice AS CHAR), '~'), IFNULL(CAST(o.XmlElemento AS CHAR), '~'), IFNULL(CAST(o.TogliHtml AS CHAR), '~'), IFNULL(CAST(o.MinutiCache AS CHAR), '~'), IFNULL(CAST(o.ParolaDisponibile AS CHAR), '~'), IFNULL(CAST(o.ParolaInArrivo AS CHAR), '~'), IFNULL(CAST(o.ParolaNonDisponibile AS CHAR), '~'), IFNULL(CAST(o.SenzaImmagine AS CHAR), '~'), IFNULL(CAST(o.SenzaEan AS CHAR), '~'), IFNULL(CAST(o.PrezzoZero AS CHAR), '~'))) FROM export_opzioni o WHERE o.ExportId = e.ID) = x.OpzFirma AND (SELECT MD5(GROUP_CONCAT(CONCAT_WS(CHAR(31), k.Posizione, k.TitoloColonna, k.Campo, k.Prefisso, k.Suffisso, k.ValoreFisso, IFNULL(k.MassimoCaratteri, '~'), k.SeVuoto) ORDER BY k.Posizione SEPARATOR '~~')) FROM export_colonne k WHERE k.ExportId = e.ID) = x.ColFirma, 1, 0), IF(EXISTS (SELECT 1 FROM export_stato st WHERE st.ExportId = e.ID), 1, 0), IF(EXISTS (SELECT 1 FROM export_filtri f WHERE f.ExportId = e.ID), 1, 0) FROM `export` e JOIN ks_ex_atteso x ON x.Descrizione = e.Descrizione;

-- Una tabella temporanea non si puo citare due volte nella stessa interrogazione: ogni conteggio passa da una variabile.
SET @ks_n_idonee = (SELECT COUNT(*) FROM ks_ex_az);
SET @ks_n_mancano = (SELECT COUNT(*) FROM ks_ex_atteso WHERE Presente = 0);
SET @ks_n_modificati = (SELECT COUNT(*) FROM ks_ex_trovato WHERE Identico = 0);
SET @ks_n_vettore = (SELECT COUNT(*) FROM ks_ex_trovato t JOIN `export` e ON e.ID = t.ExportId WHERE t.Abilitato = 1 AND (COALESCE(e.IdVettore, 0) = 0 OR NOT EXISTS (SELECT 1 FROM vettoricosti vc WHERE vc.VettoriId = e.IdVettore)));
SET @ks_n_giorni = (SELECT COUNT(*) FROM ks_ex_trovato t JOIN `export` e ON e.ID = t.ExportId WHERE t.Abilitato = 1 AND t.Chiave = 'I' AND COALESCE(e.GiorniSpedizione, 0) = 0);
SET @ks_n_campi = (SELECT COUNT(*) FROM exportcampi WHERE NomeCampo IN ('CondizioneInglese', 'EanValido', 'DescrizioneSoloTesto', 'TitoloNormalizzato'));
SET @ks_n_incompleti = (SELECT COUNT(*) FROM ks_ex_trovato t WHERE (SELECT COUNT(*) FROM export_opzioni o WHERE o.ExportId = t.ExportId) <> 1 OR (SELECT COUNT(*) FROM export_colonne k WHERE k.ExportId = t.ExportId) = 0);
SET @ks_n_registro = (SELECT COUNT(*) FROM sysparametristored WHERE NomeStore IN ('Newexport_opzioni', 'Newexport_colonne', 'Dupexport', 'Modexport_codice'));
SELECT 'Controllo' AS Controllo, 'Esito' AS Esito
UNION ALL SELECT 'aziende_idonee', IF(@ks_n_idonee > 0, 'OK', 'ATTENZIONE nessuna azienda idonea')
UNION ALL SELECT 'esempi_presenti', IF(@ks_n_mancano = 0, 'OK', CONCAT('ATTENZIONE mancano ', @ks_n_mancano, ' esempi (lancia esempi)'))
UNION ALL SELECT 'esempi_non_modificati', IF(@ks_n_modificati = 0, 'OK', CONCAT('INFO ', @ks_n_modificati, ' esempi modificati dal PO (normale dopo il completamento)'))
UNION ALL SELECT 'abilitati_senza_vettore_con_fasce', IF(@ks_n_vettore = 0, 'OK', 'ATTENZIONE esempio abilitato senza vettore o senza fasce di costo: la colonna spedizione resta vuota')
UNION ALL SELECT 'abilitati_con_giorni_zero', IF(@ks_n_giorni = 0, 'OK', 'ATTENZIONE idealo abilitato con 0 giorni lavorativi')
UNION ALL SELECT 'campi_registrati_nel_gestionale', IF(@ks_n_campi = 4, 'OK', 'ATTENZIONE i quattro campi nuovi non sono in exportcampi: lanciare il blocco campi prima di usare gli esempi dal gestionale')
UNION ALL SELECT 'registro_gestionale_feed', IF(@ks_n_registro = 32, 'OK', 'ATTENZIONE registro dei parametri incompleto (script dati dei feed)')
UNION ALL SELECT 'esempi_senza_opzioni_o_colonne', IF(@ks_n_incompleti = 0, 'OK', 'KO esempio senza opzioni o senza colonne');
SELECT IF(@ks_n_incompleti = 0, 'EXPORT_FEED_ESEMPI_VERIFY_OK', 'EXPORT_FEED_ESEMPI_VERIFY_KO') AS Verdetto;
SELECT t.ExportId, t.Descrizione, IF(t.Abilitato = 1, 'abilitato', 'disabilitato') AS Stato, IF(t.Identico = 1, 'intatto', 'modificato') AS Contenuto, IF(t.ConStato = 1, 'letto dal sito', 'mai letto') AS Uso FROM ks_ex_trovato t ORDER BY t.ExportId;
```

## 20261126_EXPORT_FEED_ESEMPI_rollback.sql

```sql
-- EXPORT-FEED-ESEMPI (rollback): cancella SOLO gli esempi ancora intatti.
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento. Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini
-- o account; nessun DEFINER. Lo esegue il Product Owner dopo il si esplicito. Va preceduto, nella stessa scheda, da: SET @KeepStoreConfirmDeleteExamples = 1;
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa (la sessione conserva variabili e tabelle temporanee).
-- Serve MySQL 8.0.19 o successivo (non MariaDB). Gli esempi si creano DISABILITATI e non si abilitano da soli.
-- Un feed si cancella soltanto se TUTTO coincide con la definizione di questo testo (campi di export, opzioni e colonne, impronta MD5), e' DISABILITATO, non ha nessuna riga di stato (mai letto dal sito)
-- e nessun filtro. Un esempio modificato, abilitato, letto o con filtri NON si cancella: lo si toglie dal gestionale. Gli altri feed non vengono mai toccati.

SET @ks_ok = IF(@KeepStoreConfirmDeleteExamples = 1, 1, 0);
SET @ks_s = IF(@ks_ok = 1, 'SELECT ''EXPORT_FEED_ESEMPI_ROLLBACK_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_ESEMPI_ROLLBACK_CONFERMA_MANCANTE');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
SET @ks_ver = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @ks_go = IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_ver, '.', 1) AS UNSIGNED) * 10000 + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_ver, '.', 2), '.', -1) AS UNSIGNED) * 100 + CAST(SUBSTRING_INDEX(@ks_ver, '.', -1) AS UNSIGNED) >= 80019, 1, 0);
SET @ks_go = IF(@ks_go = 1 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export', 'export_opzioni', 'export_colonne', 'export_stato', 'aziende', 'vettori', 'vettoricosti') AND ENGINE = 'InnoDB') = 7 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_filtri', 'sysparametristored')) = 2 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export' AND COLUMN_NAME IN ('ID', 'Descrizione', 'Password', 'FormatString', 'NListino', 'NListino2', 'IvaTipo', 'Giacenza', 'SpeseSpedizione', 'GiorniSpedizione', 'Azienda', 'Tipo', 'IdVettore', 'Tutto_in_minuscolo', 'Google', 'Amazon', 'NoVettoreSuGratis', 'Abilitato')) = 18 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aziende' AND COLUMN_NAME IN ('id', 'URL1', 'URL2', 'ListinoDefault')) = 4 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vettori' AND COLUMN_NAME IN ('id', 'AziendeId', 'Abilitato', 'Web', 'Predefinito', 'Ordinamento')) = 6 AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_opzioni') = 'Id,ExportId,TokenAccesso,Separatore,DelimitatoreTesto,Codifica,SeparatoreDecimale,Intestazione,XmlRadice,XmlElemento,TogliHtml,MinutiCache,ParolaDisponibile,ParolaInArrivo,ParolaNonDisponibile,SenzaImmagine,SenzaEan,PrezzoZero' AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME, ' ', COLUMN_TYPE) ORDER BY ORDINAL_POSITION SEPARATOR ',') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_colonne') = 'Id int,ExportId int,Posizione int,TitoloColonna varchar(60),Campo varchar(40),Prefisso varchar(40),Suffisso varchar(40),ValoreFisso varchar(100),MassimoCaratteri int,SeVuoto varchar(100)', 1, 0);
SET @ks_s = IF(@ks_go = 1, 'SELECT ''EXPORT_FEED_ESEMPI_ROLLBACK_STRUTTURA_OK'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_ESEMPI_ROLLBACK_STRUTTURA');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;

SET SESSION group_concat_max_len = 1000000;
DROP TEMPORARY TABLE IF EXISTS ks_ex_tipo, ks_ex_col, ks_ex_colsig, ks_ex_az, ks_ex_atteso, ks_ex_nuovi, ks_ex_trovato;
CREATE TEMPORARY TABLE ks_ex_tipo (Chiave CHAR(1) NOT NULL PRIMARY KEY, Ordine INT NOT NULL, Descrizione VARCHAR(60) NOT NULL, Tipo CHAR(3) NOT NULL, Separatore VARCHAR(5) NOT NULL, DelimitatoreTesto VARCHAR(1) NOT NULL, Codifica VARCHAR(10) NOT NULL, SeparatoreDecimale VARCHAR(1) NOT NULL, Intestazione INT NOT NULL, TogliHtml INT NOT NULL, MinutiCache INT NOT NULL, ParolaDisponibile VARCHAR(40) NOT NULL, ParolaInArrivo VARCHAR(40) NOT NULL, ParolaNonDisponibile VARCHAR(40) NOT NULL, SenzaImmagine INT NOT NULL, SenzaEan INT NOT NULL, PrezzoZero INT NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_tipo VALUES
('G', 1, 'ESEMPIO Google Merchant', 'tsv', '|', '', 'utf-8', '.', 1, 1, 60, 'in_stock', 'out_of_stock', 'out_of_stock', 1, 0, 1),
('T', 2, 'ESEMPIO Trovaprezzi 7Pixel', 'txt', '|', '', 'utf-8', '.', 1, 1, 60, 'Disponibile', 'In arrivo', 'Non disponibile', 1, 0, 1),
('I', 3, 'ESEMPIO idealo', 'csv', ',', '"', 'utf-8', '.', 1, 1, 60, 'Disponibile', 'In arrivo', 'Non disponibile', 1, 0, 1);
CREATE TEMPORARY TABLE ks_ex_col (Chiave CHAR(1) NOT NULL, Posizione INT NOT NULL, TitoloColonna VARCHAR(60) NOT NULL, Campo VARCHAR(40) NOT NULL, Prefisso VARCHAR(40) NOT NULL, Suffisso VARCHAR(40) NOT NULL, ValoreFisso VARCHAR(100) NOT NULL, MassimoCaratteri INT NULL, SeVuoto VARCHAR(100) NOT NULL, PRIMARY KEY (Chiave, Posizione)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_col VALUES
('G', 1, 'id', 'Id', '', '', '', NULL, ''),
('G', 2, 'title', 'TitoloNormalizzato', '', '', '', 150, ''),
('G', 3, 'description', '', '', '', '#TitoloNormalizzato#. #DescrizioneSoloTesto#', 5000, ''),
('G', 4, 'link', 'Link', '', '', '', NULL, ''),
('G', 5, 'image_link', 'UrlImgBig', '', '', '', NULL, ''),
('G', 6, 'availability', 'Disponibilita', '', '', '', NULL, ''),
('G', 7, 'price', 'Prezzo', '', ' EUR', '', NULL, ''),
('G', 8, 'condition', 'CondizioneInglese', '', '', '', NULL, ''),
('G', 9, 'brand', 'Marca', '', '', '', 70, ''),
('G', 10, 'gtin', 'EanValido', '', '', '', NULL, ''),
('G', 11, 'mpn', 'Codice', '', '', '', 70, ''),
('G', 12, 'product_type', 'CategoriaPercorso', '', '', '', 750, ''),
('G', 13, 'shipping', 'CostoSpedizioneProdo', 'IT::Standard:', ' EUR', '', NULL, ''),
('T', 1, 'Nome', 'Descrizione1', '', '', '', NULL, ''),
('T', 2, 'Marca', 'Marca', '', '', '', NULL, ''),
('T', 3, 'Descrizione', '', '', '', '#Descrizione1#. #DescrizioneSoloTesto#', NULL, ''),
('T', 4, 'Prezzo', 'Prezzo', '', '', '', NULL, ''),
('T', 5, 'Codice interno', 'Id', '', '', '', NULL, ''),
('T', 6, 'Link', 'Link', '', '', '', NULL, ''),
('T', 7, 'Disponibilita', 'Disponibilita', '', '', '', NULL, ''),
('T', 8, 'Categoria', 'CategoriaPercorso', '', '', '', NULL, ''),
('T', 9, 'Immagine', 'UrlImgBig', '', '', '', NULL, ''),
('T', 10, 'Codice produttore', 'Codice', '', '', '', NULL, ''),
('T', 11, 'EAN', 'EanValido', '', '', '', NULL, ''),
('T', 12, 'Spese di spedizione', 'CostoSpedizioneProdo', '', '', '', NULL, ''),
('T', 13, 'Peso', 'Peso', '', '', '', NULL, ''),
('I', 1, 'sku', 'Id', '', '', '', NULL, ''),
('I', 2, 'brand', 'Marca', '', '', '', NULL, ''),
('I', 3, 'title', 'Descrizione1', '', '', '', NULL, ''),
('I', 4, 'categoryPath', 'CategoriaPercorso', '', '', '', NULL, ''),
('I', 5, 'url', 'Link', '', '', '', NULL, ''),
('I', 6, 'eans', 'EanValido', '', '', '', NULL, ''),
('I', 7, 'hans', 'Codice', '', '', '', NULL, ''),
('I', 8, 'description', '', '', '', '#Descrizione1#. #DescrizioneSoloTesto#', NULL, ''),
('I', 9, 'price', 'Prezzo', '', '', '', NULL, ''),
('I', 10, 'deliveryCosts_dhl', 'CostoSpedizioneProdo', '', '', '', NULL, ''),
('I', 11, 'delivery', 'GiorniSpedizione', '', ' giorni lavorativi', '', NULL, ''),
('I', 12, 'imageUrl', 'UrlImgBig', '', '', '', NULL, '');
CREATE TEMPORARY TABLE ks_ex_colsig (Chiave CHAR(1) NOT NULL PRIMARY KEY, NCol INT NOT NULL, FormatString VARCHAR(3000) NOT NULL, ColFirma CHAR(32) NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_colsig SELECT c.Chiave, COUNT(*), GROUP_CONCAT(IF(c.Campo <> '', CONCAT('#', c.Campo, '#'), c.ValoreFisso) ORDER BY c.Posizione SEPARATOR '|'), MD5(GROUP_CONCAT(CONCAT_WS(CHAR(31), c.Posizione, c.TitoloColonna, c.Campo, c.Prefisso, c.Suffisso, c.ValoreFisso, IFNULL(c.MassimoCaratteri, '~'), c.SeVuoto) ORDER BY c.Posizione SEPARATOR '~~')) FROM ks_ex_col c GROUP BY c.Chiave;
CREATE TEMPORARY TABLE ks_ex_az (AziendaId INT NOT NULL PRIMARY KEY, Dominio VARCHAR(100) NOT NULL, Listino INT NOT NULL, IdVettore INT NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_az SELECT a.id, TRIM(a.URL1), a.ListinoDefault, COALESCE((SELECT v.id FROM vettori v WHERE v.AziendeId = a.id AND v.Abilitato = 1 AND v.Web = 1 ORDER BY v.Predefinito DESC, v.Ordinamento, v.id LIMIT 1), 0) FROM aziende a WHERE a.id > 0 AND TRIM(COALESCE(a.URL1, '')) <> '' AND CHAR_LENGTH(TRIM(a.URL1)) <= 100 AND COALESCE(a.ListinoDefault, 0) > 0 AND (SELECT COUNT(*) FROM aziende b WHERE b.id = a.id) = 1 AND (SELECT COUNT(*) FROM aziende b WHERE LOWER(TRIM(b.URL1)) = LOWER(TRIM(a.URL1)) OR LOWER(TRIM(b.URL2)) = LOWER(TRIM(a.URL1))) = 1;
CREATE TEMPORARY TABLE ks_ex_atteso (AziendaId INT NOT NULL, Chiave CHAR(1) NOT NULL, Ordine INT NOT NULL, Descrizione VARCHAR(100) NOT NULL, Tipo CHAR(3) NOT NULL, Dominio VARCHAR(100) NOT NULL, Listino INT NOT NULL, IdVettore INT NOT NULL, FormatString VARCHAR(3000) NOT NULL, NCol INT NOT NULL, ColFirma CHAR(32) NOT NULL, ExportFirma CHAR(32) NOT NULL, OpzFirma CHAR(32) NOT NULL, Presente INT NOT NULL DEFAULT 0, PRIMARY KEY (AziendaId, Chiave)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_atteso (AziendaId, Chiave, Ordine, Descrizione, Tipo, Dominio, Listino, IdVettore, FormatString, NCol, ColFirma, ExportFirma, OpzFirma) SELECT a.AziendaId, t.Chiave, t.Ordine, CONCAT(t.Descrizione, ' (azienda ', a.AziendaId, ')'), t.Tipo, a.Dominio, a.Listino, a.IdVettore, s.FormatString, s.NCol, s.ColFirma, MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(CONCAT(t.Descrizione, ' (azienda ', a.AziendaId, ')') AS CHAR), '~'), IFNULL(CAST('' AS CHAR), '~'), IFNULL(CAST(s.FormatString AS CHAR), '~'), IFNULL(CAST(a.Listino AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(2 AS CHAR), '~'), IFNULL(CAST(CAST(1 AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(CAST(0 AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(a.Dominio AS CHAR), '~'), IFNULL(CAST(t.Tipo AS CHAR), '~'), IFNULL(CAST(a.IdVettore AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'), IFNULL(CAST(0 AS CHAR), '~'))), MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(t.Separatore AS CHAR), '~'), IFNULL(CAST(t.DelimitatoreTesto AS CHAR), '~'), IFNULL(CAST(t.Codifica AS CHAR), '~'), IFNULL(CAST(t.SeparatoreDecimale AS CHAR), '~'), IFNULL(CAST(t.Intestazione AS CHAR), '~'), IFNULL(CAST('prodotti' AS CHAR), '~'), IFNULL(CAST('prodotto' AS CHAR), '~'), IFNULL(CAST(t.TogliHtml AS CHAR), '~'), IFNULL(CAST(t.MinutiCache AS CHAR), '~'), IFNULL(CAST(t.ParolaDisponibile AS CHAR), '~'), IFNULL(CAST(t.ParolaInArrivo AS CHAR), '~'), IFNULL(CAST(t.ParolaNonDisponibile AS CHAR), '~'), IFNULL(CAST(t.SenzaImmagine AS CHAR), '~'), IFNULL(CAST(t.SenzaEan AS CHAR), '~'), IFNULL(CAST(t.PrezzoZero AS CHAR), '~'))) FROM ks_ex_az a JOIN ks_ex_tipo t JOIN ks_ex_colsig s ON s.Chiave = t.Chiave;
UPDATE ks_ex_atteso x SET x.Presente = IF(EXISTS (SELECT 1 FROM `export` e WHERE e.Descrizione = x.Descrizione), 1, 0);
CREATE TEMPORARY TABLE ks_ex_trovato (ExportId INT NOT NULL PRIMARY KEY, AziendaId INT NOT NULL, Chiave CHAR(1) NOT NULL, Descrizione VARCHAR(100) NOT NULL, Abilitato INT NOT NULL, Identico INT NOT NULL, ConStato INT NOT NULL, ConFiltri INT NOT NULL) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
INSERT INTO ks_ex_trovato SELECT e.ID, x.AziendaId, x.Chiave, x.Descrizione, COALESCE(e.Abilitato, 0), IF(MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(e.Descrizione AS CHAR), '~'), IFNULL(CAST(e.Password AS CHAR), '~'), IFNULL(CAST(e.FormatString AS CHAR), '~'), IFNULL(CAST(e.NListino AS CHAR), '~'), IFNULL(CAST(e.NListino2 AS CHAR), '~'), IFNULL(CAST(e.IvaTipo AS CHAR), '~'), IFNULL(CAST(CAST(e.Giacenza AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(CAST(e.SpeseSpedizione AS DECIMAL(15,3)) AS CHAR), '~'), IFNULL(CAST(e.GiorniSpedizione AS CHAR), '~'), IFNULL(CAST(e.Azienda AS CHAR), '~'), IFNULL(CAST(e.Tipo AS CHAR), '~'), IFNULL(CAST(e.IdVettore AS CHAR), '~'), IFNULL(CAST(e.Tutto_in_minuscolo AS CHAR), '~'), IFNULL(CAST(e.Google AS CHAR), '~'), IFNULL(CAST(e.Amazon AS CHAR), '~'), IFNULL(CAST(e.NoVettoreSuGratis AS CHAR), '~'), IFNULL(CAST(e.Abilitato AS CHAR), '~'))) = x.ExportFirma AND (SELECT MD5(CONCAT_WS(CHAR(31), IFNULL(CAST(o.Separatore AS CHAR), '~'), IFNULL(CAST(o.DelimitatoreTesto AS CHAR), '~'), IFNULL(CAST(o.Codifica AS CHAR), '~'), IFNULL(CAST(o.SeparatoreDecimale AS CHAR), '~'), IFNULL(CAST(o.Intestazione AS CHAR), '~'), IFNULL(CAST(o.XmlRadice AS CHAR), '~'), IFNULL(CAST(o.XmlElemento AS CHAR), '~'), IFNULL(CAST(o.TogliHtml AS CHAR), '~'), IFNULL(CAST(o.MinutiCache AS CHAR), '~'), IFNULL(CAST(o.ParolaDisponibile AS CHAR), '~'), IFNULL(CAST(o.ParolaInArrivo AS CHAR), '~'), IFNULL(CAST(o.ParolaNonDisponibile AS CHAR), '~'), IFNULL(CAST(o.SenzaImmagine AS CHAR), '~'), IFNULL(CAST(o.SenzaEan AS CHAR), '~'), IFNULL(CAST(o.PrezzoZero AS CHAR), '~'))) FROM export_opzioni o WHERE o.ExportId = e.ID) = x.OpzFirma AND (SELECT MD5(GROUP_CONCAT(CONCAT_WS(CHAR(31), k.Posizione, k.TitoloColonna, k.Campo, k.Prefisso, k.Suffisso, k.ValoreFisso, IFNULL(k.MassimoCaratteri, '~'), k.SeVuoto) ORDER BY k.Posizione SEPARATOR '~~')) FROM export_colonne k WHERE k.ExportId = e.ID) = x.ColFirma, 1, 0), IF(EXISTS (SELECT 1 FROM export_stato st WHERE st.ExportId = e.ID), 1, 0), IF(EXISTS (SELECT 1 FROM export_filtri f WHERE f.ExportId = e.ID), 1, 0) FROM `export` e JOIN ks_ex_atteso x ON x.Descrizione = e.Descrizione;

SET @ks_trovati = (SELECT COUNT(*) FROM ks_ex_trovato);
START TRANSACTION;
DELETE e FROM `export` e JOIN ks_ex_trovato t ON t.ExportId = e.ID WHERE @ks_go = 1 AND @ks_ok = 1 AND t.Identico = 1 AND t.Abilitato = 0 AND t.ConStato = 0 AND t.ConFiltri = 0 AND COALESCE(e.Abilitato, 0) = 0;
COMMIT;
SET @ks_rimasti = (SELECT COUNT(*) FROM ks_ex_trovato t JOIN `export` e ON e.ID = t.ExportId);
SELECT 'EXPORT_FEED_ESEMPI_ROLLBACK_OK' AS Esito, @ks_trovati AS Trovati, @ks_trovati - @ks_rimasti AS Cancellati, @ks_rimasti AS Rimasti;
SELECT t.ExportId, t.Descrizione, IF(t.Identico = 0, 'modificato', IF(t.Abilitato = 1, 'abilitato', IF(t.ConStato = 1, 'letto dal sito', IF(t.ConFiltri = 1, 'con filtri', 'cancellato')))) AS Motivo FROM ks_ex_trovato t ORDER BY t.ExportId;
```

## 20261126_EXPORT_FEED_ESEMPI_campi_rollback.sql

```sql
-- EXPORT-FEED-ESEMPI (campi_rollback): toglie da exportcampi i quattro campi nuovi.
-- Nessuna istruzione USE: l'operatore sceglie il database di destinazione nello strumento. Un solo testo, identico per ogni database KeepStore: non nomina database, clienti, domini
-- o account; nessun DEFINER. Lo esegue il Product Owner dopo il si esplicito. Va preceduto, nella stessa scheda, da: SET @KeepStoreConfirmDeleteFields = 1;
-- SQLyog: attivare 'Halt Execution of Queries on Error' e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare qualcosa (la sessione conserva variabili e tabelle temporanee).
-- Serve MySQL 8.0.19 o successivo (non MariaDB). Gli esempi si creano DISABILITATI e non si abilitano da soli.
-- Cancella soltanto le quattro righe CondizioneInglese, EanValido, DescrizioneSoloTesto, TitoloNormalizzato. Il motore continua a capirle nei feed che le usano; il gestionale non le propone piu.

SET @ks_ok = IF(@KeepStoreConfirmDeleteFields = 1, 1, 0);
SET @ks_s = IF(@ks_ok = 1, 'SELECT ''EXPORT_FEED_CAMPI_ROLLBACK_START'' AS Esito', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_CAMPI_ROLLBACK_CONFERMA_MANCANTE');
PREPARE ks_st FROM @ks_s;
EXECUTE ks_st;
DEALLOCATE PREPARE ks_st;
START TRANSACTION;
DELETE FROM exportcampi WHERE @ks_ok = 1 AND NomeCampo IN ('CondizioneInglese', 'EanValido', 'DescrizioneSoloTesto', 'TitoloNormalizzato');
COMMIT;
SELECT 'EXPORT_FEED_CAMPI_ROLLBACK_OK' AS Esito, (SELECT COUNT(*) FROM exportcampi) AS CampiInTutto;
```

CONSEGNA SERVER SOSPESA.
