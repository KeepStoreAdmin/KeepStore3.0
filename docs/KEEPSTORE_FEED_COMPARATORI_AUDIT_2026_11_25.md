# KS-H04 — Feed per comparatori e canali: audit, progetto e programma dei task (2026-11-25)

Stato: **PROGETTO APPROVATO NEI PRINCIPI DAL PO (2026-11-25), NESSUN TASK ANCORA AVVIATO, nessuna modifica al codice o al database in questa voce.** Sorgenti lette: `export.aspx.vb`, `export_csv.aspx.vb`, `export_amazon.aspx.vb` (dopo la PR 684), le maschere del gestionale `frmSettaggiExport`, `frmSettaggiExportGest`, `frmExportArticoli` (`KeepStoreRepo`, sola lettura), le tabelle `export`, `export_filtri`, `exportcampi`, `export_amazon`, `aziende` sul LAB (specchio di taikun, sola lettura) e le fonti pubbliche dei comparatori elencate in fondo. Nessun nome di cliente o valore di password in questo file: il repository e pubblico.

## 1. Decisioni del PO (2026-11-25)

1. **Cartella dei file pronti:** `Public/assets/images/export` (gia creata sul server online). `Public/Export` e vecchia e non si usa piu.
2. **Formati:** CSV, TXT e TSV (testo con separatore scelto) **e XML**.
3. **Tutti i link e le immagini nel feed usano `https://`.**
4. **Il server non deve essere inchiodato dalle richieste dei comparatori:** il motore va riprogettato (sezione 4).
5. **Nessun comparatore preimpostato nel programma.** Il PO deve poter creare al momento qualunque feed (oggi Trovaprezzi, domani un altro nome): ogni destinatario e **solo un feed con le sue colonne e le sue opzioni**, creato da zero o duplicando un altro. Gli esempi pronti (Google, Trovaprezzi, idealo) sono **righe di dati** che si duplicano e si cancellano, non codice.
6. **Google Merchant Center:** si studia la loro specifica e si prepara un feed di esempio conforme (task dedicato).
7. **Amazon:** il PO ha aperto un progetto separato (con ChatGPT e Claude Code). In questo programma Amazon **si toglie**: `export_amazon.aspx` si chiude e dalle maschere del gestionale sparisce tutto cio che riguarda Amazon. Il PO riportera le informazioni del progetto Amazon e si uniranno in questo manuale.
8. **Maschere del gestionale:** disegno consegnato come immagini JPEG (cartella `docs/images/feed-comparatori/`), nello stile griglia Janus, semplice, da dare a Enzo.
9. **Studiare un task dedicato per il Pixel di Meta** (campo gia presente in `aziende`) e, piu avanti, una **funzione tipo «feed manager/connettore»** (regole sui feed, canali).

## 2. Come funziona oggi (fatti)

- Nel gestionale si crea una riga di **Impostazioni Export**: descrizione, password, listino, IVA, giacenza minima, spese di spedizione, vettore, azienda (dominio), tipo (txt o csv), flag Google e Amazon, **elenco ordinato dei campi** (scelti da `exportcampi`, 44 voci), filtri di merciologia o articolo (`export_filtri`).
- Il «link generato» **non e un file in una cartella**: e l'indirizzo di una pagina (`export.aspx` per txt, `export_csv.aspx` per csv) con `id`, la password e il nome del comparatore. Il comparatore la richiama e **il sito costruisce il file a ogni richiesta**, riga per riga.
- LAB: 56 feed, 53 abilitati, 28 csv, 20 txt, 8 senza tipo; 4.328 articoli esportabili. Molti feed sono per rivenditori e dropshipping, non solo comparatori.
- `Public/Export` contiene 59 file storici che il flusso attuale non usa.

## 3. Difetti verificati (con prova sul LAB)

1. **Ogni feed contiene un solo prodotto:** `export.aspx.vb` chiama `Response.End()` dentro il ciclo, dopo la prima riga (dal primo caricamento, 2026-01-01). Provato con tre feed: intestazione + 1 riga.
2. **I feed csv vanno in errore (302 verso la pagina di errore):** `export_csv.aspx.vb` legge le colonne con un dizionario che distingue le maiuscole; causa molto probabile letta nel codice, errore riprodotto, non ancora isolato con una traccia. 28 feed su 56.
3. `#DescrizioneLungaHtml#` non e riconosciuto (il testo letterale finisce nel file); `Abilitato`, `Tipo` e i flag Google e Amazon sono ignorati dalla pagina.
4. Password corte e in chiaro (40 su 56 sotto 8 caratteri, 5 identiche), nel link e nel database; `id` progressivo; nessun limite ai tentativi. La PR 684 ha chiuso l'iniezione SQL di `export.aspx`.
5. **Prestazioni:** ogni richiesta rilegge la vista `vsuperarticoli` e apre una o due connessioni in piu **per ogni riga** (secondo prezzo, spedizione gratis); alcune non si chiudono. Con 4.300 articoli e piu comparatori e un costo evitabile.
6. Qualita del file: link e immagini `http://`; entita HTML (`&agrave;`) anche nei csv; nessuna quotatura csv; `CampoVuoto2/3` scrivono il valore del primo; resti di debug.
7. `export_amazon.aspx`: senza autenticazione, `UPDATE` con testo concatenato (iniezione con scrittura), mostra la configurazione; il gestionale non lo richiama.

## 4. Progetto: un motore a feed liberi, veloce e protetto

### 4.1 Principi
- **Il feed e un dato**, non codice: il motore non conosce nessun comparatore. Ogni colonna del file e una riga di configurazione.
- **Una sola scrittura per tutti i database** (regola dello schema unico): migrazione e codice standard, nessun nome di cliente o dominio.
- **Il database resta la fonte** di listino, prezzo, promozione, IVA e giacenza (stesse viste del sito); il motore legge e formatta, non ricalcola.

### 4.2 Come si evita di inchiodare il server
1. **Il file e generato una volta e riusato.** Il sito costruisce il file in una cartella di appoggio e lo conserva in `Public/assets/images/export` con un nome casuale lungo (non indovinabile). Le richieste dei comparatori **non toccano il database**: si legge il file gia pronto.
2. **Una sola richiesta lo rigenera.** Quando il file e piu vecchio di `MinutiCache` (predefinito 60), la prima richiesta ottiene un blocco (`GET_LOCK` nel database) e lo rigenera; **le altre ricevono subito il file vecchio** (nessuna attesa, nessun doppio lavoro). Se la generazione fallisce, resta il file precedente e si registra l'errore.
3. **Generazione in una sola interrogazione** per tutto il catalogo, con prezzo, secondo prezzo, spedizione gratis e fascia di peso gia nel risultato (nessuna interrogazione per riga, nessuna connessione aperta nel ciclo), scritta **a flusso** su un file temporaneo e poi rinominata (il comparatore non legge mai un file a meta).
4. **Risposta leggera:** `Last-Modified`/`ETag` e risposta `304` quando il comparatore ripassa e il file non e cambiato; compressione.
5. **Limiti:** limite ai tentativi con codice sbagliato (stesso meccanismo di `login_attempt_limits`), una sola generazione alla volta per feed, tetto di tempo e di righe.
6. **Obiettivi misurati nel task del motore** (sul LAB, 4.328 articoli): generazione completa sotto 10 secondi, risposta dal file sotto 50 millisecondi, **100 richieste in parallelo senza nessuna interrogazione al database**.
Il file si puo comunicare anche come indirizzo diretto del file; il percorso della pagina `feed.aspx` aggiunge controllo di `Abilitato`, registro degli accessi e limite ai tentativi.

### 4.3 Accesso
Codice lungo casuale (`TokenAccesso`, creato dal **database** con `RANDOM_BYTES`, quindi nessun codice scritto dal web o dal gestionale), link `https://<dominio>/feed.aspx?c=<codice>`; pulsante **Nuovo codice** (il precedente smette di funzionare). I vecchi link con `id` e password (`export.aspx`, `export_csv.aspx`) **restano validi finche la casella «Link vecchio attivo» e accesa**: passano dallo stesso motore e dallo stesso file, con il limite ai tentativi. `Abilitato` vale davvero.

### 4.4 Colonne libere
Ogni colonna ha: **titolo** (il nome che il destinatario si aspetta, es. `title`, `price`, `sku`), **campo** del magazzino oppure **valore fisso**, **prefisso e suffisso** (es. ` EUR` dopo il prezzo, `IT::Standard:` davanti alla spedizione), **massimo di caratteri**, **valore se vuoto**. Opzioni del file: separatore, testo tra virgolette, codifica, separatore decimale, riga di intestazione, per XML nome della radice e dell'elemento, togli i tag HTML, parole della disponibilita (Disponibile / In arrivo / Non disponibile, es. `in_stock`, `preorder`, `out_of_stock`), cosa fare con prodotti senza immagine, senza EAN o a prezzo zero. I feed esistenti (`FormatString` con `#Campo#|#Campo#`) **non si convertono**: il motore li legge come elenco di colonne con titolo uguale al campo.
In XML ogni colonna e un elemento con il titolo come nome (per Google RSS 2.0 il titolo puo contenere il prefisso `g:` e la radice puo dichiarare lo spazio dei nomi); il motore verifica che i nomi siano XML validi e fa l'escape dei testi.

### 4.5 Dati nuovi (proposta per Enzo, tutti con nomi ASCII semplici)
**Tabella `export` — colonne nuove** (nome, tipo, predefinito, NULL, significato). `Tipo` (`char(3)`) resta e accetta anche `tsv` e `xml`.

| Nome | Tipo | Predefinito | NULL | Significato |
|---|---|---|---|---|
| `TokenAccesso` | `varchar(64)`, indice unico | creato dal database | si | codice del link nuovo |
| `LinkVecchioAttivo` | `int` | `1` | no | 1 = accetta ancora id e password |
| `Separatore` | `varchar(5)` | `\|` | no | separatore dei campi (txt/csv/tsv) |
| `DelimitatoreTesto` | `varchar(1)` | vuoto | no | virgolette attorno ai testi (vuoto = mai) |
| `Codifica` | `varchar(10)` | `utf-8` | no | codifica del file |
| `SeparatoreDecimale` | `varchar(1)` | `.` | no | `.` oppure `,` |
| `Intestazione` | `int` | `1` | no | 1 = prima riga con i titoli |
| `XmlRadice` | `varchar(40)` | `prodotti` | no | solo XML |
| `XmlElemento` | `varchar(40)` | `prodotto` | no | solo XML |
| `TogliHtml` | `int` | `1` | no | 1 = toglie i tag dai testi lunghi |
| `MinutiCache` | `int` | `60` | no | validita del file pronto |
| `ParolaDisponibile`, `ParolaInArrivo`, `ParolaNonDisponibile` | `varchar(40)` | `Disponibile`, `In Arrivo`, `Non Disponibile` | no | parole scritte nel campo disponibilita |
| `SenzaImmagine`, `SenzaEan`, `PrezzoZero` | `int` | `0`, `0`, `1` | no | 1 = scarta il prodotto |
| `UltimaGenerazioneUtc`, `UltimaRichiestaUtc` | `datetime` | nessuno | si | scritte dal sito |
| `UltimeRighe`, `UltimeScartate` | `int` | nessuno | si | scritte dal sito |
| `UltimoErrore` | `varchar(200)` | nessuno | si | scritta dal sito, senza dati sensibili |

**Tabella nuova `export_colonne`:** `Id` (`int`, automatico, chiave), `ExportId` (`int`, non nullo, indice), `Posizione` (`int`, non nullo, unico con `ExportId`), `TitoloColonna` (`varchar(60)`), `Campo` (`varchar(40)`, vuoto = valore fisso), `Prefisso`, `Suffisso` (`varchar(40)`), `ValoreFisso` (`varchar(100)`), `MassimoCaratteri` (`int`, NULL), `SeVuoto` (`varchar(100)`).
**`exportcampi`:** si aggiungono `Condizione` e `CategoriaPercorso` (Settore > Categoria > Tipologia > Gruppo). Il tempo di consegna si ottiene con `GiorniSpedizione` piu un suffisso (es. ` giorni lavorativi`). **Codice produttore:** il magazzino ha un solo codice (`Codice`); finche non esiste un campo dedicato si usa quello (decisione aperta, sezione 7).
**Nessuna colonna rimossa:** `Google`, `Amazon`, `NoVettoreSuGratis` restano nel database (non si cancellano dati), spariscono dalle maschere. `Password` resta per il link vecchio.

## 5. Programma dei task (nessuno avviato; ordine consigliato)

Tutti passano dal flusso canonico (verifica, pacchetto, ChatGPT xhigh, revisore Opus, decisione, codice). Un task = un risultato per il cliente.

| # | Task | Liv. | Risultato | Dipende da |
|---|---|---|---|---|
| 0 | `EXPORT-AMAZON-CLOSE-1A` | S | `export_amazon.aspx` risponde «non disponibile» (410) senza leggere o scrivere nel database: chiusa l'iniezione e l'accesso aperto. Nota per il progetto Amazon del PO su che cosa e stato fatto | niente |
| 1 | `EXPORT-FEED-REPAIR-1A` | L | Sui vecchi link: via `Response.End` dal ciclo, csv corretto, `Abilitato`, `#DescrizioneLungaHtml#`, `https`; il feed torna completo subito, in attesa del motore nuovo | niente |
| 2 | `EXPORT-FEED-DB-1A` | M | Migrazione unica (colonne di `export`, tabella `export_colonne`, due campi in `exportcampi`, creazione del codice nel database), con ritorno indietro e verifica; applicata dal PO su taikun, poi il programma di Enzo | 1 |
| 3 | `EXPORT-FEED-ENGINE-1A` | L | Motore, `feed.aspx`, ponte per i vecchi link, file pronto in `Public/assets/images/export`, blocco unico, `304`, anteprima di 20 righe; prove su LAB con il carico di 100 richieste e le mutazioni | 2 |
| 4 | Gestionale (Enzo) | — | Le tre maschere del disegno, tolti i riferimenti ad Amazon; vedi sezione 6 | 2, 3 |
| 5 | `FEED-EXAMPLES-1A` | S | Tre feed di esempio **come dati** (Google Merchant, Trovaprezzi/7Pixel, idealo) con le colonne richieste dalle loro specifiche; il PO li duplica o li cancella | 3 |
| 6 | `GOOGLE-MERCHANT-CENTER-FEED-1A` | M | Verifica del feed Google contro le loro regole (https, `in_stock`, prezzo con `EUR`, `gtin`, spedizione, prezzi uguali alla scheda), uso di `google_merchant_id` in `aziende`; guida al collegamento in Merchant Center | 5 |
| 7 | `META-PIXEL-1A` | L | Vedi sezione 8 | niente (puo anche precedere) |
| 8 | `FEED-RULES-1A` (idea) | M | «Feed manager»: regole per feed (soglie di prezzo, marca, solo offerte, esclusioni), elenco dei feed mai letti, catalogo Meta e altri canali con lo stesso motore | 3 |

## 6. Maschere del gestionale per Enzo (stile griglia Janus, semplice)

Immagini JPEG: [1 — elenco](images/feed-comparatori/1-elenco-export.jpg), [2 — scheda generale](images/feed-comparatori/2-scheda-generale.jpg), [3 — colonne del file](images/feed-comparatori/3-colonne-del-file.jpg). Il riquadro **arancione** e nuovo, il riquadro **rosso tratteggiato** e tolto.

1. **Elenco `Settaggio Export Web`:** colonne `Formato`, `Ultimo accesso`, `Righe`, `Ultimo errore` (le ultime tre solo lettura); tolte dall'elenco Password, Id Vettore, NListino2, Tutto in minuscolo, Google, Amazon, No Vettore; nuovo pulsante **Duplica** (copia il feed con colonne e filtri, nuovo codice, abilitato = no). Il filtro rapido della griglia permette di trovare i feed non letti da tempo.
2. **Scheda `Generale`:** `Tipo Export` diventa `Formato file` (CSV, TXT, TSV, XML); tolti i loghi Google e Amazon e la casella «Disabilita Vettore se la spedizione e gratis»; nuovo gruppo **Opzioni del file** (tutti i campi della tabella 4.5); nuovo gruppo **Link e controllo** con il link `https`, **Copia link**, **Anteprima prime 20 righe**, **Nuovo codice**, i campi di sola lettura e la casella **Link vecchio attivo**. Salvataggio con le stesse routine `NewExport`/`ModExport` aggiornate.
3. **Scheda `Colonne del file` (nuova):** a sinistra la griglia **Campi disponibili** (quella di oggi, con il pulsante «...»), a destra la griglia **Colonne del file** modificabile (`N.`, `Titolo colonna`, `Campo`, `Prefisso`, `Suffisso`, `Valore fisso`, `Max car.`, `Se vuoto scrivi`) con **Su**, **Giu**, **Elimina colonna**, **Aggiungi valore fisso** e una **riga di esempio** in sola lettura. Sostituisce la casella `Testo formattato`; i feed vecchi si mostrano gia divisi in righe.
4. **Scheda `Merciologia Selezionata`:** invariata.
5. **Amazon:** togliere dalle maschere ogni riferimento (casella, logo, colonna dell'elenco, ramo del codice che gestisce `chAmazon`), senza cancellare dati. Il progetto Amazon e a parte.
6. **Strumento:** la griglia Janus non ha piu assistenza ma le modifiche sono ordinarie (griglie e caselle); la scelta di un componente nuovo e di Enzo e non cambia il sito.

## 7. Decisioni ancora aperte (una risposta ciascuna, nessuna blocca i task 0-3)
1. **Codice produttore:** per Trovaprezzi e idealo serve il codice del produttore. Esiste solo `Codice`. Si usa quello (proposta) oppure Enzo aggiunge un campo al magazzino?
2. **File valido 60 minuti:** vanno bene come predefinito (prezzi e giacenze cambiano durante il giorno)?
3. **Feed in uso:** quali dei 53 abilitati sono ancora letti? Il motore nuovo lo registra; fino ad allora nessuno si spegne.

## 8. Pixel di Meta (task dedicato `META-PIXEL-1A`, da studiare)
Stato letto nel codice e nei dati: `aziende.facebook_pixel_id` (`varchar(17)`) esiste e ha un valore in 2 aziende su 2 sul LAB; il sito invia solo **`AddToCart`** (`aggiungi.aspx`) e **`Purchase`** (`ordine.aspx`). Mancano `PageView` su tutte le pagine, `ViewContent` sulla scheda articolo, `Search`, `InitiateCheckout`, `AddPaymentInfo` (eventi standard usati dagli altri negozi, fonte Ecwid sotto). Da studiare nel task: consenso ai cookie prima di caricare il pixel, parametri degli eventi (valuta, valore, identificativi articolo uguali a quelli del feed), Conversions API dal server con identificativo evento per evitare doppi conteggi, e il **catalogo prodotti per Meta** (stesso motore dei feed, due righe di configurazione). Livello L per la privacy; `aziende` ha anche `google_merchant_id`, gia previsto per il task 6.

## 9. Fonti consultate (2026-11-25)
Google Merchant Center: specifica e creazione del file (`support.google.com/merchants/answer/7052112` e `/12631822`: TSV o XML RSS 2.0/Atom, codifica UTF-8, nomi degli attributi in inglese, `price` con valuta, `availability` con valori fissi). idealo (`idealo.github.io/csv-importer`): `sku`, `title`, `url`, `price` IVA inclusa, `delivery`, almeno un `deliveryCosts_*`, consigliati `eans`, `brand`, `categoryPath`. Kelkoo Group (`docs.kelkoogroup.com`): stesso numero di campi in ogni riga, specifica da scaricare con l'account. PriceRunner (Klarna): CSV o XML con id, titolo, marca, prezzo, spedizione, consegna, giacenza, categoria, link, immagine, EAN. **Trovaprezzi e 7Pixel:** formati txt, csv, tsv e xml, separatori `|`, TAB, `$` o `#`; obbligatori nome modello, prezzo, codice interno, spese di spedizione, link all'offerta, albero delle categorie, link all'immagine, codice produttore, peso (se la spedizione e per fasce di peso); il catalogo si pubblica su un indirizzo del proprio sito e si comunica il link (fonte di seconda mano, `avantgrade.com`: le pagine ufficiali `trovaprezzi.it/negozi-online` e `7pixel.it/prodotti` non riportano la specifica tecnica, che si chiede all'account manager). Buone pratiche (merlinwizard.com): nome, marca, descrizione e categoria chiari, EAN, prezzo e prezzo scontato, immagine di qualita, spedizione coerente, niente prodotti non disponibili. Pixel di Meta: Ecwid (`support.ecwid.com`), eventi e Conversions API.

CONSEGNA SERVER SOSPESA.
