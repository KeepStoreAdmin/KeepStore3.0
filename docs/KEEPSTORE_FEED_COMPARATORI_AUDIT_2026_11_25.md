# KS-H04 — Feed per i comparatori di prezzo: audit e proposta (2026-11-25)

Stato: **AUDIT E PROPOSTA, nessuna modifica al codice o al database.** Richiesta del PO del 2026-11-25. Sorgenti lette: `export.aspx.vb`, `export_csv.aspx.vb`, `export_amazon.aspx.vb` (questo repository, dopo la PR 684), le maschere del gestionale `frmSettaggiExport`, `frmSettaggiExportGest`, `frmExportArticoli` (`KeepStoreRepo`, sola lettura) e le tabelle `export`, `export_filtri`, `exportcampi`, `export_amazon` sul LAB (specchio di taikun del 2026-11-17, sola lettura, nessuna password riportata qui). Nessun nome di cliente o di comparatore specifico e nessun valore di password in questo file: il repository e pubblico.

## 1. Come funziona oggi

- Nel gestionale si crea una riga di **Impostazioni Export**: descrizione, password, listino, IVA inclusa o esclusa, giacenza minima, spese di spedizione, vettore, azienda (dominio), tipo file (txt o csv), flag Google e Amazon, «tutto in minuscolo», **elenco ordinato dei campi** (scelti da `exportcampi`, 44 voci) e filtri di merciologia o di singolo articolo (`export_filtri`).
- Il «link generato» **non e un file in una cartella**: e l'indirizzo di una pagina del sito (`export.aspx` per txt, `export_csv.aspx` per csv) con `id`, `pwd` e `comparatore` nell'indirizzo. Il comparatore la richiama e **il sito costruisce il file al momento**, riga per riga, dal database.
- La cartella `Public/Export` contiene 51 nomi di file statici storici (59 file) che il flusso attuale **non usa**: sono residui.
- Nel LAB: 56 feed, 53 abilitati, 28 csv, 20 txt, 8 senza tipo; 4.328 articoli esportabili sul listino principale. Non sono solo comparatori: molti sono **feed per rivenditori e dropshipping** (listini 6-9, su un secondo dominio dell'azienda).

## 2. Difetti verificati (con prova)

1. **Il feed contiene un solo prodotto.** `export.aspx.vb` chiama `Response.End()` dentro il ciclo, dopo la prima riga (presente dal primo caricamento, 2026-01-01). Provato sul LAB con tre feed reali: intestazione + 1 riga ciascuno.
2. **I feed csv vanno in errore (302 verso InternalError).** `export_csv.aspx.vb` legge le colonne con un dizionario che distingue le maiuscole (`row("Valore")`, la colonna e `valore`): causa **molto probabile** (letta nel codice, errore riprodotto sul LAB, non ancora isolata con una traccia). 28 feed su 56.
3. **`#DescrizioneLungaHtml#`** (usato da feed reali) non e riconosciuto: il testo letterale `#DescrizioneLungaHtml#` finisce nel file.
4. **`Abilitato` e ignorato** dalla pagina (un feed disabilitato risponde lo stesso); stessa cosa per i flag Google e Amazon e per `Tipo` (conta solo `&google=1` nell'indirizzo).
5. **Sicurezza di accesso.** Password corta o banale (40 su 56 sotto 8 caratteri, 5 identiche), in chiaro nel database e **nell'indirizzo** (finisce nei registri dei comparatori), `id` progressivo, nessun limite ai tentativi. Con la PR 684 l'iniezione SQL e chiusa; resta `export_csv.aspx.vb` con valori interi concatenati (non sfruttabile oggi, da uniformare).
6. **`export_amazon.aspx` senza autenticazione:** `fase=1` mostra la configurazione, `fase=3` esegue un `UPDATE` con testo concatenato dalla richiesta (iniezione con scrittura) e senza `fase` produce un file con `formatString` e `header` presi dall'indirizzo. Il gestionale non lo richiama (ricerca nel repository: nessuna occorrenza), quindi lo usa un programma esterno oppure nessuno. Amazon ha sostituito MWS con SP-API (il Blueprint lo classifica gia come legacy; la data di chiusura di MWS non e stata verificata qui).
7. **Prestazioni.** Ogni richiesta rilegge tutta la vista `vsuperarticoli`; per ogni riga si aprono **una o due connessioni in piu** (secondo prezzo, spedizione gratis) e le connessioni non sempre si chiudono. Con 4.300 articoli e un comparatore che passa piu volte al giorno e un costo evitabile.
8. **Qualita del file.** Indirizzi e immagini con `http://`; titoli con entita HTML (`&agrave;`) anche nei csv; nessuna quotatura csv (si sostituisce `|` con `/`); decimali con punto fissi nel txt; `CampoVuoto2/3` scrivono il valore del primo; resti di debug (`ArtID = 15143`). Il formato Google ha intestazioni in italiano, disponibilita `Disponibile` invece di `in_stock`, condizione `nuovo` invece di `new`, prezzo senza valuta.

## 3. Che cosa chiedono oggi i comparatori (fonti ufficiali, lette il 2026-11-25)

| Comparatore | Formato | Campi essenziali |
|---|---|---|
| idealo | CSV con intestazione (anche XML/JSON) | `sku`, `title`, `url` (RFC 3986), `price` (IVA inclusa, senza simbolo), `delivery` (tempi precisi in giorni lavorativi), almeno un `deliveryCosts_<vettore>`, consigliati `eans`, `brand`, `categoryPath`, `hans`; dal 2026-09-28 `brand` non e piu obbligatorio; ricondizionati o usati marcati |
| Google Shopping | TSV o XML, nomi in inglese | `id` (max 50), `title` (max 150), `description`, `link`, `image_link`, `availability` (`in_stock`, `out_of_stock`, `preorder`, `backorder`), `price` con valuta (`49.99 EUR`, IVA inclusa fuori da USA e Canada), `gtin`/`brand`, `condition`, `shipping` (paese, servizio, prezzo); prezzo e disponibilita devono coincidere con la scheda e con il checkout; prezzo 0 vietato |
| Kelkoo | testo con separatore o XML | tutte le righe con lo stesso numero di campi (campo vuoto = separatore presente); campi obbligatori nella specifica Kelkoo (da scaricare con l'account) |
| PriceRunner / PriceSpy | CSV o XML | id, titolo, descrizione, marca, prezzo, costo spedizione, tempi di consegna, giacenza, categoria, link, immagine, EAN |
| Trovaprezzi e altri italiani | txt o csv a colonne fisse | **specifica da richiedere all'account manager**: non trovata una pagina pubblica ufficiale; il formato oggi in uso (Settore, Categoria, Tipologia, Gruppo, Ean, Codice, Titolo, Marca, Peso, Prezzo, Descrizione, Spese, Link, Disponibilita, Giacenza, immagini) funziona da anni e va conservato come modello |

## 4. Decisione proposta: **si tiene l'idea, si rifa il motore**

L'idea e giusta (un generatore configurabile per destinatario, con elenco campi e filtri, alimentato dai dati autorevoli del database) e serve a 56 destinatari, non solo ai comparatori. Si cambia il modo in cui e costruita:

- **Un solo motore** per txt, csv e tsv, con **modelli pronti** per destinatario (idealo, Google, Kelkoo, PriceRunner, Trovaprezzi e altri) e un modello «personalizzato» che mantiene la logica attuale dei campi `#Nome#`.
- **File pronto e riusato**: il sito genera il file, lo conserva (`App_Data`, fuori dal webroot pubblico) e lo riserve finche non e piu vecchio di N minuti (predefinito 60); la richiesta che trova il file scaduto lo rigenera con un blocco, senza dipendere da uno scheduler. Il comparatore riceve subito il file, il database non viene riletto a ogni richiesta.
- **Accesso con codice lungo casuale** (`TokenAccesso`) al posto di `id` + password; i vecchi indirizzi `id` + `pwd` **restano validi** durante la transizione. Nessuna password nei registri.
- **Rispetto di `Abilitato`**, `https`, UTF-8 senza entita nei csv, csv quotato a norma, valuta e disponibilita nei modi richiesti dal destinatario, prezzi dalla stessa fonte del sito (listino, promozione, IVA), giacenza e disponibilita coerenti col sito.
- **Controllo**: numero di righe, righe scartate (senza EAN, prezzo 0, senza immagine) e ultimo errore visibili nel gestionale.
- **Google Merchant Center** e gia in coda come `GOOGLE-MERCHANT-CENTER-FEED-1A` (roadmap): usera lo stesso motore con il modello Google, senza un secondo generatore.

## 5. Piano a task (nessuno avviato; ordine proposto)

| # | Task | Livello | Contenuto | Dipende da |
|---|---|---|---|---|
| 1 | `EXPORT-FEED-REPAIR-1A` | L (feed con prezzi) | Togliere `Response.End` dal ciclo, isolare e correggere l'errore dei csv, `#DescrizioneLungaHtml#`, rispetto di `Abilitato`, chiusura connessioni, `https`; test sul LAB con confronto riga per riga col formato attuale | niente |
| 2 | `EXPORT-AMAZON-ACCESS-1A` | S | Chiudere `export_amazon.aspx` (risposta di rifiuto) oppure proteggerlo; dopo la risposta del PO su Amazon | decisione PO |
| 3 | `EXPORT-FEED-ENGINE-1A` | L | Motore unico, modelli, file riusato, token; richiede i campi nuovi nel database | 1 e Enzo |
| 4 | Gestionale (Enzo) | — | Vedi sezione 6 | 3 |
| 5 | `GOOGLE-MERCHANT-CENTER-FEED-1A` | M | Modello Google sul motore | 3 |

## 6. Per Enzo — database e maschere del gestionale (proposta, non applicata)

Tutte le modifiche al database vanno scritte **una volta sola**, standard, provate su taikun (regola dello schema unico). Nomi con sole lettere ASCII, cifre e underscore.

**Tabella `export`, colonne nuove** (nome, tipo, predefinito, NULL, significato):

| Nome | Tipo | Predefinito | NULL | Significato |
|---|---|---|---|---|
| `TokenAccesso` | `varchar(64)`, indice unico | nessuno | si | codice lungo casuale per l'indirizzo del feed; generato dal gestionale al salvataggio |
| `Modello` | `varchar(30)` | `personalizzato` | no | modello del destinatario (idealo, google, kelkoo, pricerunner, trovaprezzi, personalizzato) |
| `MinutiCache` | `int` | `60` | no | minuti per cui il file pronto resta valido |
| `UltimaGenerazioneUtc` | `datetime` | nessuno | si | ultima generazione del file (scritta dal sito) |
| `UltimeRighe` | `int` | nessuno | si | righe dell'ultima generazione (scritta dal sito) |
| `UltimeScartate` | `int` | nessuno | si | righe scartate (scritta dal sito) |
| `UltimoAccessoUtc` | `datetime` | nessuno | si | ultima richiesta ricevuta (scritta dal sito) |
| `UltimoErrore` | `varchar(200)` | nessuno | si | ultimo errore, senza dati sensibili (scritta dal sito) |

Le colonne `Google`, `Amazon`, `NoVettoreSuGratis` e `Tipo` restano: i flag Google e Amazon vengono sostituiti dal `Modello` ma non si cancellano. `exportcampi` riceve campi nuovi (`Condizione`, `Marca` gia presente; `CategoriaPercorso` con separatore ` > `, `TempoConsegna`, `AltreImmagini`, `Brand`/`CodiceProduttore` solo se esiste il dato, altrimenti si omettono).

**Maschera `Settaggio Export Web` (elenco):** colonne nuove `Modello`, `Ultimo accesso`, `Righe`, `Ultimo errore`; filtro rapido sui feed non letti da molto tempo (candidati alla chiusura); la password non si mostra piu nell'elenco.

**Maschera `Settaggi Export (Gestione)`:** scelta del **modello** (riempie in automatico elenco campi, separatore, formato prezzo e disponibilita); indirizzo `https` con il codice e pulsanti **Copia link** e **Anteprima prime 20 righe**; **Genera nuovo codice** (invalida il vecchio indirizzo, con avviso); i campi «Giorni di spedizione» e «Spese di spedizione» restano ma con spiegazione; avviso se manca EAN o immagine nel campione.

**Strumento:** la griglia Janus non ha piu assistenza: queste modifiche si possono fare cosi come sono oppure su una griglia supportata, scelta di Enzo. Il sito non dipende dalla griglia.

## 7. Decisioni che servono dal PO

1. **Amazon:** il programma che sincronizza Amazon (voce di menu «Amazon» del gestionale) e ancora in uso? Se no, `export_amazon.aspx` si chiude subito.
2. **Quali dei 53 feed abilitati sono ancora letti?** Il sito non ha mai registrato gli accessi: dal task 3 lo fara; nel frattempo si possono disabilitare solo quelli noti come chiusi.
3. **Transizione:** i vecchi indirizzi con `id` e `pwd` restano validi finche non si avvisano i destinatari (proposta). 

CONSEGNA SERVER SOSPESA.
