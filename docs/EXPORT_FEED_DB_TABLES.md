# Dati dei feed: colonne nuove di `export` e due tabelle nuove

`EXPORT-FEED-DB-1A` (task 2 del progetto feed, [manuale](KEEPSTORE_FEED_COMPARATORI_AUDIT_2026_11_25.md)). Questa pagina serve al PO (che applica gli script **solo su `taikun`**) e a Enzo (il cui programma di allineamento li porta sugli altri database). Un solo testo, identico per ogni database: nessun nome di database, cliente, dominio, account o `DEFINER`; nessuna routine e nessun trigger.

**Stato: script NON applicati a nessun database reale.** Provati sul LAB locale da `Tools/Test-ExportFeedDb.ps1` (script reali, ripresa dopo ogni interruzione, 20 mutazioni). Il sito e il gestionale attuali non cambiano: `Newexport`, `Modexport` e `Delexport` usano colonne nominate e continuano a funzionare con la firma di oggi.

## 1. Che cosa fa
- Aggiunge a `export` quindici colonne di opzione (tutte con valore predefinito) e il **codice del link** `TokenAccesso`, creato **dal database** (48 caratteri esadecimali maiuscoli, `HEX(RANDOM_BYTES(24))`), con indice unico e controllo di formato. I feed che ci sono gia ricevono un codice distinto.
- Crea `export_colonne` (le colonne del file, una riga per colonna) e `export_stato` (cosa ha fatto il sito: ultima generazione, ultima richiesta, righe, errore). Entrambe si cancellano da sole quando si cancella il feed (chiave esterna con cancellazione a catena).
- **Non tocca** `exportcampi`, `export_filtri`, le routine del gestionale, ne alcun dato esistente. La riga `CategoriaPercorso` di `exportcampi` la aggiunge il task del motore, quando il motore la sa scrivere nel file.

## 2. Come si esegue (SQLyog, un database alla volta, solo dopo il si del PO per quel database)
I quattro script stanno in [EXPORT_FEED_DB_SCRIPTS](EXPORT_FEED_DB_SCRIPTS.md), un blocco ciascuno (non sono file `.sql` del repository: il repository e pubblico). Tutti gli script iniziano senza `USE`: si sceglie il database nello strumento. Attivare **Halt Execution of Queries on Error** e, dopo qualunque STOP o errore, chiudere la connessione prima di rilanciare (la sessione conserva le variabili).
1. `20261125_EXPORT_FEED_DB_1A_preflight.sql` (sola lettura): deve dare `EXPORT_FEED_DB_PREFLIGHT_OK`. Mostra database, server, versione e numero di feed: controllare che sia il database voluto. Si ferma se la versione e inferiore a MySQL 8.0.19, se e MariaDB, se il registro binario e attivo in formato `STATEMENT` (i codici sarebbero diversi sulla replica) o se `export` non e come atteso.
2. `20261125_EXPORT_FEED_DB_1A_forward.sql`: otto passi (`-- STEP 1` ... `-- STEP 8`); alla fine `EXPORT_FEED_DB_FORWARD_OK`. **Si puo rilanciare dopo qualunque interruzione**: ogni passo guarda lo stato reale del database e salta quello che c'e gia.
3. `20261125_EXPORT_FEED_DB_1A_verify.sql` (sola lettura): tutte le righe `OK` e, in fondo, `EXPORT_FEED_DB_VERIFY_OK`; altrimenti errore deliberato.
4. **Ritorno indietro:** `20261125_EXPORT_FEED_DB_1A_rollback.sql`, preceduto nella stessa scheda da `SET @KeepStoreConfirmDropFeedData=1;`. Cancella le due tabelle, i codici e le quindici colonne: **dati che un uso successivo avra scritto**; senza la conferma si ferma.

Perche cinque passi per il codice: un solo `ALTER` con questo valore predefinito fallisce (ERROR 1674, misurato sul LAB). L'ordine e: colonna senza predefinito, **predefinito creato dal database**, riempimento dei feed esistenti, poi non nullo + unico + controllo. Il predefinito viene prima del riempimento, cosi un feed creato mentre la migrazione gira riceve gia il suo codice.

## 3. Colonne nuove di `export` (nomi con soli caratteri ASCII)
Tutte `NOT NULL`; le colonne di testo hanno `utf8mb4` / `utf8mb4_0900_ai_ci`. `export` e `latin1` per default: solo le colonne nuove sono utf8mb4.

| Nome | Tipo | Predefinito | Significato |
| --- | --- | --- | --- |
| `TokenAccesso` | `varchar(64)` ascii `ascii_bin`, indice unico | creato dal database (48 car.) | codice del link `feed.aspx?c=...`; «Nuovo codice» = `UPDATE export SET TokenAccesso = DEFAULT WHERE ID = ...` |
| `Separatore` | `varchar(5)` | `\|` | separatore dei campi (txt, csv, tsv) |
| `DelimitatoreTesto` | `varchar(1)` | vuoto | virgolette attorno ai testi (vuoto = mai) |
| `Codifica` | `varchar(10)` | `utf-8` | codifica del file |
| `SeparatoreDecimale` | `varchar(1)` | `.` | `.` oppure `,` |
| `Intestazione` | `int` | `1` | 1 = prima riga con i titoli |
| `XmlRadice`, `XmlElemento` | `varchar(40)` | `prodotti`, `prodotto` | solo XML |
| `TogliHtml` | `int` | `1` | 1 = toglie i tag dai testi lunghi |
| `MinutiCache` | `int` | `60` | validita del file pronto |
| `ParolaDisponibile`, `ParolaInArrivo`, `ParolaNonDisponibile` | `varchar(40)` | `Disponibile`, `In Arrivo`, `Non Disponibile` | parole scritte nel campo disponibilita |
| `SenzaImmagine`, `SenzaEan`, `PrezzoZero` | `int` | `0`, `0`, `1` | 1 = scarta il prodotto |

I valori ammessi (per esempio `.` o `,` nel separatore decimale, `MinutiCache` positivo) li valida il motore, con ripiego sui predefiniti: il database non ha controlli su questi campi.

## 4. `export_stato` (scritta dal sito, letta dal gestionale)
`ExportId` `int` non nullo, chiave primaria e chiave esterna verso `export(ID)` con cancellazione a catena; `UltimaGenerazioneUtc`, `UltimaRichiestaUtc` `datetime` (possono essere vuoti); `UltimeRighe`, `UltimeScartate` `int` (possono essere vuoti); `UltimoErrore` `varchar(200)` (puo essere vuoto, senza dati sensibili). La riga di un feed nasce **alla prima scrittura del sito**: l'elenco del gestionale deve leggerla con `LEFT JOIN`, altrimenti nasconde i feed mai generati. Tenerla separata da `export` serve a due cose verificabili: il salvataggio del gestionale (`Modexport`) non compete con le scritture del sito sulla stessa riga, e la configurazione puo restare in sola lettura per il sito.

## 5. `export_colonne`
`Id` `int` automatico, chiave; `ExportId` `int` non nullo, chiave esterna verso `export(ID)` con cancellazione a catena; `Posizione` `int` non nullo (unica insieme a `ExportId`); `TitoloColonna` `varchar(60)`, `Campo` `varchar(40)` (vuoto = valore fisso), `Prefisso` e `Suffisso` `varchar(40)`, `ValoreFisso` `varchar(100)`, `SeVuoto` `varchar(100)`, tutti non nulli con predefinito vuoto; `MassimoCaratteri` `int` (puo essere vuoto). **Riordinare:** scambiare due `Posizione` direttamente collide con l'unicita: si usa una posizione temporanea libera dentro la stessa transazione.

## 6. Privilegi (li da il programma di Enzo, non questi script)
L'account del sito ha gia `SELECT` su `export`. Servono: `SELECT` su `export_colonne` e `SELECT`, `INSERT`, `UPDATE` su `export_stato`. Non servono privilegi di scrittura sulla configurazione. Il gestionale ha gia accesso a `export`.

## 7. Per Enzo: una domanda e due avvertenze
- **Domanda (la sola aperta):** il programma di allineamento esegue **lo script** sugli altri database o confronta gli schemi e crea le colonne? Se confronta gli schemi, il predefinito `HEX(RANDOM_BYTES(24))` su una tabella con righe cade nell'ERROR 1674; se lo copia come testo fisso, tutti i feed avrebbero lo stesso codice (ma l'indice unico lo rifiuta: l'errore e rumoroso, mai silenzioso). Per gli altri database va lanciato **lo script** (anche piu volte: e ripetibile).
- Il gestionale oggi legge `Select * from Export` (elenco e scheda): finche non applica il layout del task del gestionale vedra le colonne nuove (tra cui il codice) nella griglia.
- Esistono due difetti **preesistenti** non toccati qui: `Newexport` restituisce `MAX(id)` e non l'identificativo della propria riga (due creazioni contemporanee possono confondersi), e `Delexport` cancella solo la riga di `export` e lascia le righe di `export_filtri` (orfane; `export_filtri` non ha nemmeno un indice su `ExportId`). Vanno nel task del gestionale e in quello del motore.

## 8. Limiti di prova
Provato su MySQL 8.0.46 del LAB con registro binario disattivato: **non** su 8.0.42, **non** con registro binario attivo (l'arresto con `STATEMENT` e provato sostituendo i valori nella condizione), **non** con replica, **non** con SQLyog. Il preflight stampa versione e impostazioni: se l'esito sul database di destinazione e diverso dal LAB, fermarsi e dirlo.
