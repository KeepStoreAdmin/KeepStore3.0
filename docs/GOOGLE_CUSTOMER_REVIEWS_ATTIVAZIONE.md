# GOOGLE_CUSTOMER_REVIEWS_ATTIVAZIONE - attivazione del sondaggio di Recensioni dei clienti su Google

Task `GCR-OPTIN-1A` (27/11/2026). Stato: **SOURCE, nulla pubblicato**. Il badge e fuori da questo task. Le regole di Google citate sono quelle lette il 27/11/2026 (Aiuto di Merchant Center: «Integrazione del modulo di attivazione del sondaggio»).

## Che cosa faceva prima (due difetti)

1. **Non veniva mai mostrata.** La pagina `documentidettaglio.aspx.vb` la mostrava solo se la sessione conteneva `GCR_ShowOptIn_DocId`, ma quel valore non e scritto da nessuna parte dal 21/2/2026 (lo scriveva `pagamento.aspx.vb`, tolto da una riscrittura).
2. **La CSP del sito la bloccava.** L'intestazione `Content-Security-Policy` ammette solo il sito stesso: lo script `https://apis.google.com/js/platform.js` e la finestra `https://www.google.com/shopping/customerreviews/optin` venivano rifiutati dal browser (misurato in un browser vero il 27/11/2026).

## Come funziona ora

- Il checkout, subito dopo la creazione di un **ordine** (tipo 4, mai un preventivo), scrive nella sessione un marcatore `azienda:utente:documento` (`KeepStore:GCR:Pending`, al massimo 20).
- Lo snippet compare in due punti, solo con il marcatore per quel documento, quell'utente e quell'azienda: la **ricevuta di `ordine.aspx`** (bonifico, contrassegno, PayPal con pagamento anticipato) e **`documentidettaglio.aspx` al ritorno da PayPal o Banca Sella** (`payreturn=ok`: il parametro da solo non basta, serve il marcatore). Il marcatore si toglie dopo aver costruito lo snippet: una ricarica della pagina non riapre la finestra.
- La CSP si allarga **solo su quella pagina**, con `script-src` (stesse fonti di prima piu `https://apis.google.com`) e `frame-src` (`'self' data: blob:` piu `https://www.google.com`); le altre pagine hanno la CSP di sempre, identica. Codice in `App_Code/KeepStoreContentSecurityPolicy.vb`.
- Dati: ID Merchant da `aziende.google_merchant_id` dell'**azienda del documento** (solo cifre, fino a 20); e-mail dell'acquirente; paese `utentiindirizzi.NazioneA` (due lettere ISO; se manca o non e valido **non si emette nulla**); data di consegna stimata = data del documento + 5 giorni. Senza ID, e-mail o paese validi, niente snippet e niente cambio di CSP. Nessuna tabella nuova, nessuna migrazione.

## Da fare quando si pubblica (per il PO)

1. Copiare sul server, dal GitHub aggiornato: `App_Code/KeepStoreContentSecurityPolicy.vb`, `App_Code/KeepStoreGoogleCustomerReviews.vb`, `App_Code/KeepStoreSecurity.vb`, `ordine.aspx`, `ordine.aspx.vb`, `documentidettaglio.aspx.vb` (i file nuovi prima degli altri).
2. In Merchant Center: **Recensioni dei clienti su Google**, integrazione di attivazione: dopo un ordine vero con un cliente che accetta, Google la riconosce e il pannello smette di chiederla. L'**ID Merchant** per azienda e gia nel database (taikun 5522591374; webaffare ha il suo, di 8 cifre: va attivato nel suo Merchant Center).
3. **Prova con un ordine vero** (bonifico o contrassegno): sulla pagina «Ordine ricevuto» deve comparire la finestra di Google; sul sorgente della pagina c'e lo script. Con la console del browser aperta non devono esserci messaggi «violates the following Content Security Policy». Poi un ordine con PayPal o carta e il ritorno sul documento.
4. **Privacy (decide il PO):** lo snippet carica una finestra di Google che riceve l'e-mail dell'acquirente quando la pagina si apre, prima che il cliente scelga; il sondaggio parte solo se il cliente accetta. L'informativa privacy va aggiornata di conseguenza.

## Limiti

- La finestra visibile **non e stata vista su un ordine vero**: in un browser vero con la CSP nuova lo script parte e il frame si crea senza violazioni; Google non la mostra per un ordine finto su `localhost`.
- Un pagamento PayPal catturato in stato PENDING (esito `ko`) e un ritorno da Banca Sella su un altro host dell'azienda (altra sessione) non mostrano l'opt-in.
- Data di consegna fissa +5 giorni; `products` (GTIN) e badge non inclusi.
- Il marcatore resta in sessione anche per un ordine finito in `ko` (pagamento fallito): chi riscrive `payreturn=ok` sul proprio ordine appena creato, nella stessa sessione, vede la finestra (e il suo ordine, la sua sessione, al massimo 20 voci). Una data documento non valida ripiega su oggi.
- `www.webaffare.it` risponde senza `Content-Security-Policy` (versione diversa del sito o configurazione): su quel sito lo snippet non e bloccato; la causa non e stata verificata.
- Un paese ISO a due lettere ma non assegnato (`AA`) passa il controllo.

CONSEGNA SERVER SOSPESA.
