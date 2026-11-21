# Loghi dei pagamenti: provenienza e regole d'uso

Cartella dei file: `Public/assets/images/pagamenti/`. Richiesta del PO del 2026-11-19: «fai un check online e trovami i nuovi loghi e li mettiamo nella cartella e li pubblichiamo online»; il 2026-11-19 il PO ha autorizzato lo scaricamento di Mastercard, Maestro e PayPal dai siti ufficiali accettando le loro condizioni d'uso («Si, scarica»).

**Stato (2026-11-21, `PAYMENT-LOGOS-1A`):** il piede di pagina mostra i marchi sotto il testo «Metodi di pagamento», solo per i metodi davvero nominati per l'azienda dell'host: carta nominata = Visa e Mastercard; PayPal nominato = PayPal; nessun marchio per i metodi senza gateway. Nomi, file e misure stanno soltanto in `App_Code/KeepStorePaymentBrands.vb`. La scheda prodotto non ha ancora un blocco proprio (`PAYMENT-LOGOS-1B`).

**Decisione del PO del 2026-11-21 sui circuiti:** alla domanda «Posso mostrare Visa e Mastercard per OGNI azienda che ha la carta Banca Sella attiva sul sito?» il PO ha risposto «Sì, per tutte»: ogni azienda con la carta Banca Sella attiva accetta Visa e Mastercard, e quel metodo e sempre una carta. Se un'azienda avra circuiti diversi servira un dato per azienda (oggi non esiste).

## File ufficiali scaricati il 2026-11-19 (copiati senza alcuna modifica)

| File nella cartella | Marchio | File originale | Fonte ufficiale | Condizioni |
| --- | --- | --- | --- | --- |
| `mastercard.svg` | Mastercard, Simbolo (due cerchi, senza scritta) | `ma_symbol.svg` nell'archivio `mc_symbol_SVG.zip` | Centro del marchio Mastercard, pagina «Download Artwork» (`mastercard.com/brandcenter`) | Accettato il «Download Artwork Agreement» della pagina |
| `visa.svg` | Visa, scritta bianca su riquadro blu | `Visa.svg` | Pagina «Metodi di pagamento» del gestore dei pagamenti del PO (Fabrick / Banca Sella, `fabrick.com/it-it/prodotti/payment-gateway/pagamenti/`), scaricato il 2026-11-19 | Indicazione del PO: «procedi direttamente, avendo Banca Sella e avendo firmato il contratto con loro». E la resa del gestore, non il file del centro del marchio Visa |
| `paypal-logo-2024.png` | PayPal, scritta nera (logo 2024) | `PayPal-Logo-Black-RGB.png` nell'archivio `PayPal-Logo-Black-2024.zip` | Area stampa ufficiale PayPal, «Media Resources» (`newsroom.paypal-corp.com`) | Materiale dell'area stampa; la pagina per i negozianti non e piu raggiungibile |
| `paypal-monogram-2024.png` | PayPal, monogramma a colori (2024) | `PayPal-Monogram-FullColor-RGB.png` nell'archivio `PayPal-Monogram-Logo-2024.zip` | Stessa area stampa PayPal | Come sopra |

Controlli fatti prima di copiarli: archivi estratti in una cartella isolata; i due SVG non contengono script, collegamenti esterni ne contenuto attivo; ogni file copiato e identico all'originale (impronta SHA-256 confrontata).

## Decisioni del PO del 2026-11-19 (sera)
- **Maestro tolto:** «Il circuito Maestro e in fase di dismissione: Mastercard ha interrotto l'emissione di nuove carte Maestro dal 1 luglio 2023 [...] inserisci solo i loghi che sono attuali e non cose vecchie». Il file `maestro.svg` e stato rimosso; le carte di debito Mastercard sono coperte dal simbolo Mastercard.
- **File vecchi tolti dal PO:** `master.svg`, `paypal.svg`, `discover.svg` e il vecchio `visa.svg` li ha rimossi lui dalla cartella.
- **Immagini dei tipi di pagamento:** il PO ha messo nella cartella le immagini usate dal gestionale per i tipi di pagamento (per esempio `bonifico.jpg`, `contrassegno.jpg`, `credito.jpg`, `paypal.jpg`): le carica lui dal gestionale, restano fuori dal controllo di versione come le altre immagini caricate (articoli, marche) e non vanno toccate. Il carrello le mostra gia tramite il campo `Img` del tipo di pagamento.
- **Circuiti:** fonte indicata dal PO, pagina «Metodi di pagamento» di Fabrick: il gestore prevede per le carte Visa, Mastercard, American Express, Diners Club e JCB, piu portafogli e metodi alternativi. Quella pagina elenca cio che il gestore PUO attivare, non cio che e attivo sul contratto: nel sito si mostrano Visa, Mastercard e PayPal; gli altri solo quando il PO li attiva.

## Regole d'uso (dai siti dei marchi)
- **Mai modificare** colori, proporzioni o forma; non aggiungere effetti, ombre o cornici. Si puo solo ridimensionare mantenendo le proporzioni.
- **Spazio libero** attorno a ogni marchio (Mastercard: almeno un quarto della larghezza di un cerchio).
- **Parita:** tutti i marchi dei pagamenti con la stessa evidenza (stessa altezza visiva, stessa riga, stessa frequenza); nessuno piu piccolo degli altri.
- **Solo se attivo:** un marchio si mostra soltanto se il metodo e davvero accettato dal negozio.
- **Sfondo:** `mastercard.svg` e la versione per sfondi chiari; `paypal-logo-2024.png` e la scritta nera per sfondi chiari; `visa.svg` ha il proprio riquadro blu.

## Che cosa manca (richiede un passaggio del PO)
- **Visa, file del centro del marchio:** oggi si usa la resa del gestore (`visa.svg`). Il file ufficiale Visa (`globalclient.visa.com/brand-mark`) richiede un modulo con i dati del titolare: se il PO lo compila, si sostituisce il file.
- **PagoBANCOMAT / BANCOMAT Pay, PostePay:** nessuna pagina pubblica di download; i file si chiedono alla banca o ad Axerve.
- **American Express, Apple Pay, Google Pay, Satispay, Klarna, Scalapay:** pagine ufficiali disponibili, ma i marchi vanno mostrati solo con il metodo attivo (contratto in essere).
- **Circuiti del contratto Banca Sella per il sito:** da leggere sul contratto o nel pannello della banca (di solito Visa, Mastercard, Maestro; altri su richiesta).
