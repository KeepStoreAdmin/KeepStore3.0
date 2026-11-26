# Feed per i comparatori: cosa deve fare Enzo, passo per passo

Pagina di consegna per Enzo (`EXPORT-FEED-GESTIONALE-1A`, manuale del progetto: [audit feed](KEEPSTORE_FEED_COMPARATORI_AUDIT_2026_11_25.md)). Qui trovi **solo azioni**, nell'ordine in cui vanno fatte, ciascuna con il risultato atteso. Il codice del gestionale non e stato toccato: il repository del gestionale e stato letto in sola lettura e i frammenti VB sono **modelli** da adattare al tuo `SalvaDati`. Disegni delle maschere (arancione = nuovo, rosso tratteggiato = tolto): [1 elenco](images/feed-comparatori/1-elenco-export.jpg), [2 scheda Generale](images/feed-comparatori/2-scheda-generale.jpg), [3 colonne del file](images/feed-comparatori/3-colonne-del-file.jpg).

## Le tre regole che non si discutono
1. **La tabella `export` e le routine esistenti (`Newexport`, `Modexport`, `Delexport`, `Newexport_filtri`) non cambiano.** Il gestionale attuale continua a salvare i feed come oggi.
2. **Mai aggiungere colonne a `export` e a `export_opzioni`.** `AggiungiDati` passa tutte le colonne di `Select * from ...` per posizione: una colonna in piu rompe il salvataggio (il disegno precedente di questa migrazione lo faceva: e stato scartato). Le opzioni future vanno in un'altra tabella.
3. **Le routine nuove hanno la loro riga in `sysparametristored`** (la scrive lo script `dati`): senza, il gestionale nuovo le chiama senza parametri e fallisce senza messaggio.

## Chi fa che cosa, in quale ordine
| Fase | Chi | Che cosa | Quando e finita |
|---|---|---|---|
| 1 | il PO | Script del database su **taikun** (database sorgente) e riavvio del gestionale su taikun | `EXPORT_FEED_DB_VERIFY_OK` |
| 2 | Enzo | Nuove maschere, provate su taikun | checklist della fase 2 tutta verde |
| 3 | Enzo | Per **ogni altro database**: preflight, programma di confronto, controllo dello script, esecuzione, privilegi, script `dati`, `verify`, riavvio | `EXPORT_FEED_DB_VERIFY_OK` su quel database |
| 4 | il PO | Pubblicazione del sito (`feed.aspx`) | fuori da questa pagina |
| 5 | Enzo | Collaudo finale con un feed reale | checklist della fase 5 |

Il gestionale e **un solo programma per tutti i database**: la versione nuova va rilasciata su un database solo dopo la fase 3 di quel database; il controllo del passo 2.0 la rende innocua dove le tabelle mancano. Il gestionale **vecchio** continua a funzionare su un database allineato (la tabella `export` non e cambiata).

## Fase 1 - Database sorgente (lo fa il PO, tu aspetti)
Il PO esegue, su taikun e solo dopo il suo si, gli script di [EXPORT_FEED_DB_SCRIPTS](EXPORT_FEED_DB_SCRIPTS.md) nell'ordine `preflight` -> `forward` -> `verify`, poi riavvia il gestionale (`CheckParametri` legge `sysparametristored` una volta per processo). Che cosa crea, campo per campo: [EXPORT_FEED_DB_TABLES](EXPORT_FEED_DB_TABLES.md). **Quando il PO ti dice che taikun e fatto vai alla fase 2 e alla fase 3.**

## Fase 2 - Le maschere del gestionale

### 2.0 Controllo all'apertura (difesa contro un database non allineato)
All'apertura di `frmSettaggiExport` e `frmSettaggiExportGest`:
```sql
SELECT (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_opzioni','export_colonne','export_stato')) AS Tabelle,
       (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME IN ('Newexport_opzioni','Newexport_colonne','Dupexport','Modexport_codice')) AS Routine,
       (SELECT COUNT(*) FROM sysparametristored WHERE NomeStore IN ('Newexport_opzioni','Newexport_colonne','Dupexport','Modexport_codice')) AS Registro;
```
Il risultato atteso e **3, 4, 32**. Se la query fallisce (`GetDatatable` restituisce `Nothing`) o i numeri sono diversi: messaggio «Database non aggiornato per i feed: chiedere l'allineamento (e riavviare il gestionale)» e maschera in sola lettura o chiusa. Senza questo controllo l'elenco resta vuoto e la scheda va in errore.
Inoltre, prima di ogni `AggiungiDati` azzera `LastError`: se una routine torna `False` senza testo, mostra «riavviare il gestionale» (il registro dei parametri e vecchio di processo).

### 2.1 Elenco (`frmSettaggiExport`, disegno 1)
1. Sostituisci la query dell'elenco con questa (i feed mai letti non hanno la riga di stato: per questo `LEFT JOIN`):
```sql
SELECT e.ID, e.Descrizione, e.Tipo, e.Abilitato, e.NListino, e.IvaTipo, e.Giacenza, e.Azienda,
       o.Id AS OpzioniId, o.TokenAccesso,
       s.UltimaGenerazioneUtc, s.UltimaRichiestaUtc, s.UltimeRighe, s.UltimeScartate, s.UltimoErrore
FROM export e
LEFT JOIN export_opzioni o ON o.ExportId = e.ID
LEFT JOIN export_stato s ON s.ExportId = e.ID
ORDER BY e.Descrizione
```
(usa i nomi di colonna di `export` che la tua query attuale gia legge: sono invariati).
2. Colonne **nuove** (sola lettura): `Formato` (= `Tipo`), `Ultimo accesso` (= `UltimaRichiestaUtc` convertita dall'UTC all'ora locale), `Righe` (= `UltimeRighe`), `Ultimo errore` (frase ricavata da `UltimoErrore`, tabella in appendice A).
3. Colonne **tolte** dall'elenco: Password, Sp. Spedizione, Giorni Sped., Id Vettore, NListino2, Tutto in minusc., Google, Amazon, No Vettore Su.
4. Pulsante **Duplica**: seleziona la riga, conferma, chiama `Dupexport` dentro una transazione (passo 2.5), poi ricarica l'elenco posizionandoti sul nuovo feed (spento, nome con `_copia`).
5. Atteso: l'elenco mostra i feed esistenti; un feed mai letto ha «Ultimo accesso» vuoto e «Mai letto da questo feed»; uno con `Abilitato = 0` mostra «Disabilitato».

### 2.2 Scheda Generale (`frmSettaggiExportGest`, disegno 2)
1. **Formato file** al posto di «Tipo Export»: aggiungi alla lista `TSV` e `XML` (oggi ci sono `TXT` e `CSV`); si salva in `Tipo` in maiuscolo come oggi.
2. Nuova casella **Solo articoli disponibili**: accesa = scrive `1` nel campo giacenza minima; spenta = `-1` (tutti); chi vuole un'altra soglia scrive il numero nel campo. All'apertura la casella e accesa se la giacenza vale 1 o piu.
3. **Nota fissa** accanto al listino (`cmbListini`, campo `NListino`): «Prezzo: offerta per 1 pz se presente, altrimenti prezzo del listino scelto». E la regola vera del feed: per ogni articolo il feed pubblica il prezzo offerta per 1 pezzo **se in quel momento e in promozione per quel listino** (promozione valida oggi, per il listino e l'azienda, non riservata a un utente), **altrimenti il prezzo standard di quel listino**; mai prezzi a scaglioni; IVA come da `IvaTipo`; arrotondato al centesimo. `NListino2` serve solo al campo `#Prezzo2#`. La valuta (` EUR`) e il suffisso della colonna del prezzo.
4. Nuovo gruppo **Opzioni del file** (quindici campi, valori e predefiniti in appendice B).
5. Nuovo gruppo **Link e controllo del feed** (passo 2.5).
6. **Tolti** da questa scheda: Password, Url generato (sostituito dal link), Testo Formattato e Lista Campi (passano alla scheda Colonne del file), logo Google, logo Amazon, casella «Disabilita Vettore se la spedizione e gratis».
7. Le schede **Dettaglio** e **Merciologia Selezionata** non cambiano: la scelta degli articoli resta come oggi (`export_filtri`).

### 2.3 Scheda nuova «Colonne del file» (disegno 3)
Va inserita tra Generale e Dettaglio. Una griglia, una riga per colonna: `Titolo colonna`, `Campo` (uno dei campi di `exportcampi`, oppure vuoto = valore fisso), `Prefisso`, `Suffisso`, `Valore fisso`, `Max car.`, `Se vuoto scrivi`; pulsanti Su, Giu, Elimina colonna, Aggiungi valore fisso; a sinistra l'elenco dei campi (`Select * from exportcampi order by NomeCampo`, ora con `CategoriaPercorso`); sotto la **riga di esempio** (prima riga del file, in sola lettura).
1. Apertura: `Select * from export_colonne where ExportId=<id> order by Posizione`.
2. **Se non ci sono righe** (feed creato dal gestionale vecchio) leggi `FormatString` di `export` e riempi la griglia **come fa il sito** (stessa regola di `ParseLegacyFormat`):
   - dividi sulla barra `|`, togli gli spazi, scarta i pezzi vuoti;
   - un pezzo che e **esattamente** `#X#` con `X` presente in `exportcampi` diventa una riga con `Campo` = `X`;
   - **ogni altro pezzo** (testo fisso, oppure un modello con piu campi come `#Settore# > #Categoria#`) va in `Valore fisso`, con `Campo` vuoto: il sito sostituisce i `#Campo#` anche li;
   - `Titolo colonna` = il pezzo senza i `#` (eccezione: `Descrizione1` ha titolo `Titolo`); prefisso, suffisso e «se vuoto» vuoti; massimo caratteri vuoto;
   - titolo oltre 60 caratteri o valore fisso oltre 100: non salvare e dillo.
   **Feed `CSV` storico**: oggi il sito, per un feed senza colonne, pubblica con separatore `;` e testo tra virgolette `"`; appena esistono colonne salvate usa le opzioni. Quindi, per un feed `CSV` con separatore `|` e delimitatore vuoto, la maschera deve **mostrare e salvare `;` e `"`** nelle opzioni: altrimenti aprire e salvare senza toccare nulla cambierebbe il file del comparatore.
   Prova: apri e salva un feed storico senza modifiche; l'**anteprima** deve dare le stesse righe di prima (cambia solo l'impronta nel nome del file, che fa rigenerare il file: e normale).
3. Al salvataggio ricomponi anche `FormatString` dalla **sorgente** di ogni riga (`#Campo#` per una colonna con campo, il testo di `Valore fisso` altrimenti), separate da `|`: il vecchio controllo la vuole non vuota e il gestionale vecchio continua a vederla coerente. Se un feed ha gia colonne, il gestionale vecchio che ne modifica la `FormatString` non cambia il file: le colonne prevalgono.
4. Atteso: un feed nuovo con 3 colonne, riaperto, mostra le stesse 3 colonne nello stesso ordine.

### 2.4 Come si salva (la parte delicata: stessa transazione, un solo commit)
Ordine fisso. **Leggi ogni id prima della chiamata successiva** (`ValorePar` e una variabile globale).
1. `NewExport` / `ModExport` come oggi (la riga di `export`).
2. `Newexport_opzioni`: inserisce **o aggiorna** le opzioni (una riga per `ExportId`); il valore di `TokenAccesso` e **ignorato** (passa stringa vuota); un `DBNull` vale il predefinito.
3. `Delete from export_colonne where ExportId=<id>`, poi `Newexport_colonne` per ogni riga della griglia (`Posizione` 1, 2, 3...: due uguali sono rifiutate).
4. I filtri come oggi.
5. Ogni errore: `RollBackTrns` e messaggio; nessun dato a meta.

Modello (sul tuo `SalvaDati`, nomi dei controlli di esempio):
```vb
Dim dtO As DataTable = MyConnection.GetDatatable("Select * from export_opzioni where id=-1")
Dim ro As DataRow = dtO.NewRow
ro("ExportId") = idExport
ro("TokenAccesso") = ""                         ' ignorato dalla routine
ro("Separatore") = txtSeparatore.Text
ro("DelimitatoreTesto") = txtDelimitatore.Text
ro("Codifica") = cmbCodifica.SelectedValue       ' utf-8, iso-8859-1, windows-1252
ro("SeparatoreDecimale") = cmbDecimale.SelectedValue ' "." o ","
ro("Intestazione") = IIf(chIntestazione.Checked, 1, 0)
ro("XmlRadice") = txtXmlRadice.Text
ro("XmlElemento") = txtXmlElemento.Text
ro("TogliHtml") = IIf(chTogliHtml.Checked, 1, 0)
ro("MinutiCache") = numMinuti.Value              ' 15 - 1440
ro("ParolaDisponibile") = txtDisp.Text
ro("ParolaInArrivo") = txtInArrivo.Text
ro("ParolaNonDisponibile") = txtNonDisp.Text
ro("SenzaImmagine") = IIf(chSenzaImmagine.Checked, 1, 0)
ro("SenzaEan") = IIf(chSenzaEan.Checked, 1, 0)
ro("PrezzoZero") = IIf(chScartaPrezzoZero.Checked, 1, 0)
' notnull = False: con True i DBNull diventano -1 anche nelle colonne di testo
If Not AggiungiDati("Newexport_opzioni", ro, False) Then Throw New Exception("Errore Salvataggio Opzioni")

If Not MyConnection.EseguiSqlTrn("Delete from export_colonne where ExportId=" & idExport) Then Throw New Exception(MyConnection.LastError)
Dim dtC As DataTable = MyConnection.GetDatatable("Select * from export_colonne where id=-1")
Dim pos As Integer = 0
For Each g As DataRow In jColonne.DataSource.Rows        ' la griglia "Colonne del file"
    If g.RowState = DataRowState.Deleted Then Continue For
    pos += 1
    Dim rc As DataRow = dtC.NewRow
    rc("ExportId") = idExport : rc("Posizione") = pos
    rc("TitoloColonna") = g("TitoloColonna") : rc("Campo") = g("Campo")
    rc("Prefisso") = g("Prefisso") : rc("Suffisso") = g("Suffisso")
    rc("ValoreFisso") = g("ValoreFisso") : rc("MassimoCaratteri") = g("MassimoCaratteri")
    rc("SeVuoto") = g("SeVuoto")
    If Not AggiungiDati("Newexport_colonne", rc, True) Then Throw New Exception("Errore Salvataggio Colonne")
Next
```
Controlla gli esiti anche della `Delete` dei filtri (come nel modello): oggi non lo e. Se `OpenTransaction` fallisce `SalvaDati` prosegue senza transazione e `CommitTrns` ignora gli errori: dopo il commit **rileggi la riga di opzioni salvata** (`Select * from export_opzioni where ExportId=<id>`) e mostra un errore se non c'e.

### 2.5 Pulsanti del gruppo «Link e controllo del feed»
| Elemento | Che cosa fa |
|---|---|
| Link (sola lettura) | `https://<Azienda>/feed.aspx?c=<TokenAccesso>`; sostituisce la costruzione del vecchio link (identificativo, password e nome del comparatore) in `cmbAzienda_SelectedIndexChanged` e `cmbTipoExport_SelectedIndexChanged`. Nessun `&google=1`. Per un feed senza riga di opzioni: «si crea al salvataggio». |
| Copia link | copia il testo del link |
| Nuovo codice | conferma («il link attuale smettera di funzionare: avvisare il comparatore»), `Modexport_codice` con `parId` = `ExportId` (restituisce `False` se il feed non ha la riga di opzioni), rilegge `TokenAccesso`; sul sito vale entro 60 secondi |
| Anteprima prime 20 righe | apre `<link>&anteprima=1`: prime 20 righe (xml: 80) del **file pronto**, testo semplice; l'intestazione `X-Feed-Generato` dice quando e stato generato (puo avere fino a `MinutiCache` minuti: mostra l'ora). La prima richiesta di un feed mai letto lo genera (qualche secondo) |
| Duplica (nell'elenco) | `Dupexport` con `parId` = feed da copiare; restituisce l'id del nuovo feed, **-1** se l'origine non esiste; copia feed, opzioni, colonne e filtri con codice nuovo e `Abilitato = 0` |
| Abilitato | `Abilitato = 0` spegne il link entro 60 secondi |
| 4 campi grigi | `UltimaRichiestaUtc` (ultimo accesso), `UltimeRighe`, `UltimeScartate`, `UltimaGenerazioneUtc` (file generato il), `UltimoErrore`: scritti dal sito, sola lettura |

### 2.6 Controlli da fare nella maschera prima di salvare
Sono le stesse regole del motore: se sono sbagliate il feed non si genera e l'errore compare in «Ultimo errore».
- Formato `TXT`, `CSV`, `TSV` o `XML`.
- Separatore di 1 o 2 caratteri e **diverso dal delimitatore**; separatore **diverso dal decimale** se il delimitatore e vuoto; delimitatore vuoto o di 1 carattere; decimale `.` o `,`.
- Codifica `utf-8`, `iso-8859-1` o `windows-1252` (l'xml e sempre utf-8).
- `MinutiCache` tra 15 e 1440 (fuori da questi valori il sito usa 60).
- Per l'xml il titolo di ogni colonna e il nome di un elemento: lettere, cifre, `_`, `.`, `-`; senza spazi, due punti o prefissi; non inizia con `xml`; massimo 60 caratteri.
- Ogni `Campo` e uno dei campi di `exportcampi` oppure vuoto (valore fisso); almeno una colonna.

### 2.7 Amazon: che cosa togliere (senza cancellare dati)
`chAmazon` (casella, logo, handler `chAmazon_CheckedChanged`), il ramo `chAmazon.CheckState` di `SalvaDati` (le colonne `Google`, `Amazon` e `NoVettoreSuGratis` restano in `export` e si continuano a passare con il loro valore), la colonna Amazon dell'elenco, la casella e il logo Google, la casella «Disabilita Vettore se la spedizione e gratis». Il progetto Amazon e a parte.

### 2.8 Collaudo della fase 2 (su taikun, con una copia di prova)
1. Con il gestionale **vecchio**, dopo la fase 1: nuovo feed e modifica salvano (nulla e cambiato per lui).
2. Gestionale nuovo: nuovo feed -> opzioni e colonne salvate; riaprilo e le ritrovi; salvalo di nuovo senza modifiche (stesso `Id` in `export_opzioni`, **stesso codice**).
3. Feed creato dal gestionale vecchio (anche uno `CSV`): aprilo (le colonne appaiono dalla vecchia stringa), salva senza modifiche -> compare la riga di opzioni con un codice e l'**anteprima** da le stesse righe di prima.
4. Duplica, Nuovo codice, Anteprima, Copia link.
5. Cancella un feed dall'elenco: spariscono opzioni, colonne e stato (cascata).
6. Errore a meta salvataggio (due colonne con la stessa posizione): nessun dato a meta.

## Fase 3 - Allineare ogni altro database (tu, con il programma di confronto)
Il tuo programma confronta la **struttura**; i **dati** che servono al gestionale (registro dei parametri, voce `CategoriaPercorso`, una riga di opzioni per ogni feed esistente) non li porta: per questo c'e lo script `dati`. **Non rilanciare il `forward` intero su questi database**: ricreerebbe le quattro routine con l'account di chi lo esegue, al posto di quello che imposta il tuo programma. Per ogni database di destinazione, in quest'ordine:
1. **Preflight sulla destinazione** (prima del confronto): blocco `20261126_EXPORT_FEED_DB_2A_preflight.sql` della pagina [EXPORT_FEED_DB_SCRIPTS](EXPORT_FEED_DB_SCRIPTS.md). Atteso: `EXPORT_FEED_DB_PREFLIGHT_OK` (MySQL 8.0.19 o successivo, tabella `export` come attesa, nessun registro binario in formato `STATEMENT`).
2. **Confronto.** Sorgente = taikun (dopo la fase 1), destinazione = il database. Fai generare lo script di allineamento.
3. **Controlla lo script generato prima di eseguirlo.** Deve contenere **soltanto**: la creazione di `export_opzioni`, `export_colonne`, `export_stato` e delle quattro routine `Newexport_opzioni`, `Newexport_colonne`, `Dupexport`, `Modexport_codice`. **Non deve** toccare `export`, `export_filtri`, `exportcampi`, `sysparametristored`, ne le routine esistenti. Controlla che le tabelle mantengano:
   - `export_opzioni.TokenAccesso`: `varchar(64)`, collation `ascii_bin`, valore predefinito **espressione** `hex(random_bytes(24))` (alcuni programmi di confronto la trasformano in un testo fisso: sarebbe lo stesso codice per tutti i feed), indice unico;
   - indici unici: `export_opzioni(ExportId)`, `export_colonne(ExportId, Posizione)` (in questo ordine di colonne);
   - controllo di formato sul codice (48 caratteri esadecimali maiuscoli);
   - chiavi esterne verso `export(ID)` con `ON DELETE CASCADE` in tutte e tre le tabelle;
   - **ordine e tipo delle colonne** come in taikun (il gestionale passa le colonne per posizione), motore InnoDB, `utf8mb4_0900_ai_ci`;
   - nelle routine: **stessi parametri, nello stesso ordine e con la stessa direzione** (l'ultimo e sempre `parRetVal OUT`).
   Se qualcosa manca o differisce, correggi lo script a mano **oppure** fermati: il giudice finale e `verify` (passo 7).
4. **Esegui** lo script generato (la tua valutazione e il tuo ok).
5. **Privilegi** (li imposti tu, **prima** di `dati` e della prova delle maschere): account del sito: `SELECT` su `export`, `export_opzioni`, `export_colonne`, `export_filtri`, `aziende`; `SELECT`, `INSERT`, `UPDATE` su `export_stato`; nessuna scrittura sulla configurazione. Account del gestionale: lettura e scrittura sulle tre tabelle nuove e `EXECUTE` sulle quattro routine. Account che esegue `dati`: `SELECT`, `INSERT` su `export_opzioni` ed `exportcampi`, `SELECT`, `INSERT`, `DELETE` su `sysparametristored`, e deve **vedere** le quattro routine (e il loro elenco di parametri).
6. **Script `dati`**: blocco `20261126_EXPORT_FEED_DB_2A_dati.sql`, con **lo stesso account delle routine esistenti** (in SQLyog attiva «Halt Execution of Queries on Error»; dopo uno STOP chiudi la connessione prima di rilanciare). Atteso: `EXPORT_FEED_DB_DATI_OK`. Prima di scrivere qualunque cosa controlla tabelle, routine, ordine delle colonne e firma completa dei parametri contro un elenco scritto nel testo: se qualcosa differisce **si ferma senza scrivere** (`KEEPSTORE_STOP_EXPORT_FEED_DB_DATI_STRUTTURA`) e va corretta la struttura (passo 3), non lo script. Si puo rilanciare quante volte serve: non crea righe doppie e non tocca le opzioni gia presenti.
7. **Verifica**: blocco `20261126_EXPORT_FEED_DB_2A_verify.sql`. Atteso: tutte le righe `OK` e `EXPORT_FEED_DB_VERIFY_OK`. In fondo stampa proprietario e SQL SECURITY delle routine nuove e di quelle esistenti: **controlla che siano quelli che il tuo programma assegna** (non e un controllo automatico).
8. **Riavvia tutti i gestionali aperti** (il registro dei parametri si carica una volta per processo).
9. Se qualcosa va storto: `rollback` (blocco `20261126_EXPORT_FEED_DB_2A_rollback.sql`, preceduto nella stessa scheda da `SET @KeepStoreConfirmDropFeedData=1;`) toglie routine, registro, voce di `exportcampi` e le tre tabelle, **anche i codici dei link e lo stato scritti nel frattempo**.
Per taikun la stessa cosa la fa il PO nella fase 1 con `forward` (che crea anche tabelle e routine), al posto dei passi 2-4 e 6.
**Finche esiste un gestionale vecchio in uso**, un feed creato da li non ha la riga di opzioni (e quindi nemmeno il codice): rilancia `dati` (e `verify`) dopo l'uso, oppure rilascia presto la versione nuova.

## Fase 5 - Collaudo finale (dopo la pubblicazione del sito)
1. Crea un feed di prova (Formato TXT, listino scelto, 5 colonne), salva, copia il link e aprilo nel browser: arriva un file con le righe attese; `Anteprima` mostra le prime 20.
2. Tre accessi di seguito al link: il file non cambia e «Ultimo accesso» si aggiorna dopo qualche minuto.
3. Cambia una colonna e salva: entro 60 secondi il link serve il file nuovo.
4. `Nuovo codice`: il vecchio link risponde «non disponibile», il nuovo funziona.
5. `Abilitato = 0`: il link risponde «non disponibile».
6. Cancella il feed di prova.

## Appendice A - Codici di errore e frase da mostrare in «Ultimo errore»
`UltimoErrore` e sempre un codice, mai un messaggio di sistema.
| Codice | Frase |
|---|---|
| `AZIENDA_NON_RISOLTA` | Azienda non riconosciuta: il dominio non corrisponde a nessuna azienda |
| `LISTINO_NON_VALIDO` | Listino non valido |
| `COLONNE_ASSENTI` | Nessuna colonna nel file |
| `CAMPO_SCONOSCIUTO` | Una colonna usa un campo non ammesso |
| `CODIFICA_NON_AMMESSA` | Codifica non ammessa |
| `SEPARATORE_DECIMALE_NON_AMMESSO`, `CONFIG_SEPARATORE_DECIMALE` | Separatore decimale non ammesso |
| `SEPARATORE_NON_AMMESSO` | Separatore dei campi non ammesso |
| `SEPARATORE_UGUALE_DELIMITATORE` | Separatore uguale al delimitatore |
| `DELIMITATORE_NON_AMMESSO` | Delimitatore non ammesso |
| `NOME_XML_NON_VALIDO` | Un titolo di colonna non e valido come nome XML |
| `PROMOZIONI_NON_DISPONIBILI` | Promozioni non leggibili: riprova fra qualche minuto |
| `TETTO_RIGHE`, `TETTO_BYTE`, `TETTO_TEMPO` | File troppo grande: restringi la selezione degli articoli |
| `PUBBLICAZIONE_NON_RIUSCITA`, `CARTELLA_NON_SCRIVIBILE` | Il server non riesce a scrivere il file: avvisare il PO |
| `ERRORE_<tipo>` | Errore tecnico: avvisare il PO |
Dopo un errore il sito riprova solo dopo 5 minuti.

## Appendice B - Le quindici opzioni (tabella `export_opzioni`)
Tutte `NOT NULL`; testo `utf8mb4_0900_ai_ci`. Il significato di ognuna: [EXPORT_FEED_ENGINE](EXPORT_FEED_ENGINE.md).
| Campo | Tipo | Predefinito | Maschera |
|---|---|---|---|
| `Separatore` | varchar(5) | `\|` | Separatore dei campi |
| `DelimitatoreTesto` | varchar(1) | vuoto | Testo tra virgolette |
| `Codifica` | varchar(10) | `utf-8` | Codifica |
| `SeparatoreDecimale` | varchar(1) | `.` | Separatore decimale |
| `Intestazione` | int | 1 | Riga di intestazione |
| `XmlRadice` | varchar(40) | `prodotti` | Solo per XML: nome radice |
| `XmlElemento` | varchar(40) | `prodotto` | nome elemento |
| `TogliHtml` | int | 1 | Testi: togli i tag HTML |
| `MinutiCache` | int | 60 | File valido per (minuti) |
| `ParolaDisponibile` | varchar(40) | `Disponibile` | Disponibile |
| `ParolaInArrivo` | varchar(40) | `In Arrivo` | In arrivo |
| `ParolaNonDisponibile` | varchar(40) | `Non Disponibile` | Non disponibile |
| `SenzaImmagine` | int | 0 | Prodotto senza immagine |
| `SenzaEan` | int | 0 | Prodotto senza EAN |
| `PrezzoZero` | int | 1 | Prezzo a zero |
Le colonne di `export_colonne` e di `export_stato`: [EXPORT_FEED_DB_TABLES](EXPORT_FEED_DB_TABLES.md) §3.

## Appendice C - Difetti gia presenti, non toccati
`Newexport` restituisce `MAX(id)` e non l'id della propria riga (due creazioni contemporanee possono confondersi: le routine nuove usano `LAST_INSERT_ID()`); `Delexport` e la cancellazione dell'elenco non cancellano le righe di `export_filtri` (orfane, innocue); `OpenTransaction` e `CommitTrns` ignorano gli errori. L'`AggiornaDb` rigenera il registro solo per le routine modificate dopo `sysappversion.LastProcedureUpdate`: gli script scrivono le righe nello stesso formato senza toccare `sysappversion`.
