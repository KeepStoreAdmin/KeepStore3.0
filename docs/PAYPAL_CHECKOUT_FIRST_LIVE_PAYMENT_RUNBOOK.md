# PayPal Checkout - pubblicazione e primo pagamento reale (runbook per il PO)

Documento operativo del 16/11/2026, scritto dopo PAYPAL-TINYINT-FLAGS-1A (PR #524, SOURCE). Non autorizza nulla da solo: ogni passo che tocca il server, PayPal o un ordine reale lo esegue e lo decide il PO. Vale per l'installazione con due aziende nello stesso database (Taikun = azienda 1, pagamento 19, tetto 5000; Webaffare = azienda 2, pagamento 12, tetto 1000, stesso account PayPal REST). Tutti i valori sono dati dell'installazione, non del codice.

## 0. Punto di partenza (misurato)
- Verifica di prontezza eseguita dal PO il 16/11/2026 ([PAYPAL_CHECKOUT_READINESS_READONLY](PAYPAL_CHECKOUT_READINESS_READONLY.md)): per entrambe le aziende `ConfigurazioneCompleta = SI`, `MappingAttivo = 1`, `AccountAttivo = 1`, credenziali e webhook presenti, `TentativiRegistrati = 0` (PayPal non e mai stato usato).
- Il carrello non offriva PayPal per un difetto del codice (flag `tinyint(1)` letti come 0). E corretto nel sorgente ma **non e sul server**: finche i file non sono pubblicati nulla cambia per i clienti.
- Mai provato dal vivo: nessun pagamento reale e nessuna sandbox (tolta il 22/09/2026). Il primo pagamento reale e la prima prova completa; il codice e provato con un database vero ma con PayPal simulato.

## 1. Pubblicare i due file (solo App_Code, insieme)
| File | SHA-256 PRIMA (versione difettosa) | SHA-256 DOPO (corretta) |
| --- | --- | --- |
| `App_Code\PayPalCheckoutRepository.vb` | `a6238dfde1a64e60e3b52f2631b6625b29ed7781682150f6490831144160ef36` | `88f59f704183506154a5ac4b5ab17727981296a7e936562d152130da32802f67` |
| `App_Code\PayPalPaymentState.vb` | `8e2f2284284fae8e6ca8b16909198ea2a5dccde5ab4d17b32f533dee5f0c5432` | `f6adfae8e591dc32d3902cc3f8b25a525ba83b30d5a15e416bd1f5f09dac556b` |

Gli hash sono dei file come stanno nella cartella di lavoro `C:\KeepStoreWeb\KeepStore3.0` (fine riga CRLF). Altri file PayPal non cambiano dal 23/09/2026 (il piede di #523 e un'altra consegna e non serve a PayPal).
1. Sul server, calcolare l'hash dei due file attuali: `Get-FileHash <percorso> -Algorithm SHA256`. Se coincide con la colonna PRIMA, procedere. **Se e diverso, fermarsi** e dirmelo: il server ha una versione che non conosco.
2. Copia di sicurezza dei due file (fuori dalla cartella dell'applicazione).
3. Copiare i due file nuovi, ricalcolare l'hash: deve coincidere con la colonna DOPO.
4. Cambiare un file in `App_Code` fa ricompilare e riavviare l'applicazione: farlo in un momento di poco traffico (le sessioni in corso si perdono). Aprire la home e una pagina prodotto: devono caricarsi.
5. Ripristino: rimettere i due file di backup (stessa procedura, controllo hash PRIMA).

## 1bis. Consegna di PAYPAL-CAPTURE-REPRESENTATION-1A (#533): quattro file, in quest'ordine

Senza questa consegna create e capture di PayPal che seguono gli esempi ufficiali sarebbero scartati (misurato). Prima i file di `App_Code`, poi le tre pagine insieme (le pagine usano un metodo nuovo del client).

| Ordine | File | SHA-256 PRIMA (stable `30029c97`) | SHA-256 DOPO |
| --- | --- | --- | --- |
| 1 | `App_Code\PayPalOrdersV2Client.vb` | `23c347f89b3e7aef12aa7d6af793d335ee04cc907d2a0b17cad12cc40328569e` | `e6f6e669327f3349d1d2e3367eb6b84fece2d585983b4819c86119bbc3de884e` |
| 2 | `paypalcheckout.aspx.vb` | `5bb613185980380ebee78d950aaac37770875bc821518e65e6e0c9b3640368db` | `44bbd7ce891fce204b296d12dd99468b36640e47b802dd207b5285365579bda9` |
| 2 | `paypalreturn.aspx.vb` | `d606863b1930b5c3bf1722ba25b2c237d5436e2befabceee2e6d0904cb13eaee` | `2b27150c521d2b1efba8bd9047fa8d41fa5409b9b1afd3fb78207c2f829fba83` |
| 2 | `paypalwebhook.aspx.vb` | `99878475b64533799c6747d519faaf6583911ee09d360f0578c454b35fae317a` | `45d7c4b485741b926c0525a5da4a2ee2c652d4e4d1894fdb5cdd07d30b03a9f7` |

Gli hash sono dei file come stanno nella cartella di lavoro (CRLF). Se il file sul server ha un hash PRIMA diverso, non e la versione di `30029c97` (per esempio mancano gia le correzioni del punto 1): fermarsi e dirmelo. Il client e cumulativo (contiene anche i tipi di P1) ma i file `PayPalCheckoutRepository.vb` e `PayPalPaymentState.vb` del punto 1 devono essere gia al posto loro.

**Cosa guardare nel registro dopo il primo pagamento** (`paypal-checkout.log`, `paypal-webhook.log`): la riga dice lo stato HTTP e un codice. `CAPTURE_RESPONSE_<CAMPO>` = la risposta di cattura non coincide con l'ordine (importo, valuta, id, payee...); `CAPTURE_READBACK_<CAMPO>` = il GET dopo la cattura non e coerente (per esempio `INTENT`, `PAYEE`, `MERCHANT`: **la risposta reale non porta quel campo**) oppure `CAPTURE_READBACK_GET_<stato>` = il GET non e riuscito; in tutti questi casi l'addebito PUO essere avvenuto e il documento resta non pagato: non pagare di nuovo, aprire il dettaglio ordine (ricontrollo) e dirmi riga e ora. Sul create, `check=<CAMPO>` dopo `http=...` dice quale campo della risposta di creazione non coincide (`APPROVAL_HOST` = il link non e di PayPal).

## 2. Prima del pagamento (senza spendere nulla)
a. Schema (sola lettura, database selezionato; tutte le righe devono dare `presente = 1`, l'ultima `4`):
```sql
SELECT 'documenti.OrigineOrdine' AS colonna, COUNT(*) AS presente FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'documenti' AND COLUMN_NAME = 'OrigineOrdine'
UNION ALL SELECT 'pagamentitipo.PermettiPagamentoSuccessivo', COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pagamentitipo' AND COLUMN_NAME = 'PermettiPagamentoSuccessivo'
UNION ALL SELECT 'paypal_checkout_account.ClientId', COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'paypal_checkout_account' AND COLUMN_NAME = 'ClientId'
UNION ALL SELECT 'tabelle paypal_checkout_* (attese 4)', COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('paypal_checkout_account','paypal_checkout_azienda','paypal_checkout_transazioni','paypal_checkout_eventi');
```
b. Pannello PayPal (lo vede solo il PO/Enzo, io no): l'app REST e **LIVE**; il webhook punta a `https://<dominio canonico dell'azienda>/paypalwebhook.aspx` ed e iscritto ai cinque eventi `CHECKOUT.ORDER.APPROVED`, `CHECKOUT.PAYMENT-APPROVAL.REVERSED`, `PAYMENT.CAPTURE.PENDING`, `PAYMENT.CAPTURE.COMPLETED`, `PAYMENT.CAPTURE.DENIED`; l'ID del webhook e quello salvato nel database. **Il webhook e la rete di sicurezza**: se il cliente chiude la scheda o la sessione scade dopo aver approvato su PayPal, la pagina di ritorno rimanda al login e non incassa; e il webhook `CHECKOUT.ORDER.APPROVED` a completare l'incasso.
c. Un conto PayPal **acquirente** diverso da quello venditore (un conto non puo pagare se stesso), con saldo o carta. Un cliente di prova del sito, collegato, della stessa azienda.
d. Sul sito pubblico (HTTPS, dominio canonico: da localhost o dai siti di prova su questo PC, per sicurezza, PayPal LIVE non e mai offerto), con il cliente di prova e un articolo di importo basso e sotto il tetto: **PayPal deve comparire tra i metodi di pagamento del carrello**. Non si crea nessun ordine. Se non compare: rieseguire la verifica di prontezza e controllare importo e tetto, poi dirmelo.

## 3. Primo pagamento reale (Taikun, importo basso)
1. Carrello -> PayPal -> conferma. **Il sito crea l'ordine nel gestionale prima di andare su PayPal** (documento non pagato): e un ordine reale, da gestire alla fine.
2. Pagare con il conto acquirente. Si rientra nel dettaglio dell'ordine con `payreturn=ok`: l'ordine deve risultare pagato.
3. Controllo nel database (sola lettura; sostituire `0` con l'id del documento di prova):
```sql
SET @doc := 0;
SELECT d.id, d.AziendeId, d.PagamentiTipoId, d.OrigineOrdine, d.Pagato, d.StatoPagamentoWeb, d.IdTransazione, d.UltimoEsitoPagamentoWeb, pie.TotaleDocumento
FROM documenti d LEFT JOIN documentipie pie ON pie.DocumentiId = d.id WHERE d.id = @doc;
SELECT t.TentativoNo, CAST(t.CurrentSlot AS SIGNED) AS Corrente, t.Stato, t.Importo, t.Valuta, t.UltimoEsito, t.CreatedAt, t.UpdatedAt
FROM paypal_checkout_transazioni t WHERE t.DocumentiId = @doc ORDER BY t.TentativoNo;
SELECT e.EventType, e.Stato, e.CreatedAt
FROM paypal_checkout_eventi e INNER JOIN paypal_checkout_transazioni t ON t.Id = e.TransazioniId WHERE t.DocumentiId = @doc ORDER BY e.Id;
```
Atteso: `Pagato = 1`, `StatoPagamentoWeb = 2`, `IdTransazione` che comincia con `TXN:`; una transazione `COMPLETED` con `Corrente = 1` e importo uguale al totale; entro pochi minuti anche le righe degli eventi del webhook (almeno `CHECKOUT.ORDER.APPROVED` o `PAYMENT.CAPTURE.COMPLETED`). Nel pannello PayPal le consegne del webhook devono risultare con esito 200.
4. Controllare l'importo addebitato su PayPal: deve essere il totale dell'ordine (le commissioni PayPal reali le paga il venditore).

## 4. Seconda e terza prova (stesso importo basso, con rimborso)
- **Annullo:** nuovo ordine, su PayPal scegliere Annulla: si torna al sito senza addebito, l'ordine resta non pagato (`StatoPagamentoWeb = 4`). Il codice non prevede un nuovo tentativo automatico per gli ordini web: annotare che cosa vede il cliente e se puo riprovare.
- **Rete di sicurezza (facoltativa, consigliata):** nuovo ordine, approvare su PayPal e **chiudere la scheda senza tornare al sito**: entro alcuni minuti l'ordine deve risultare pagato per opera del webhook (stessa SELECT del passo 3.3). Se resta non pagato e l'importo e stato addebitato: vedere il punto 6.
- Ripetere sul sito di Webaffare (azienda 2, tetto 1000, destinatario del pagamento diverso) solo dopo che Taikun e andato bene.

## 5. Chiudere le prove
Il sito **non gestisce rimborsi** (non c'e codice e l'evento di rimborso non e tra quelli iscritti): rimborsare dal pannello PayPal, poi annullare o stornare l'ordine di prova nel gestionale. L'ordine restera `Pagato = 1` nel database finche non lo cambia il gestionale.

## 6. Se qualcosa va storto
- **Addebito ma ordine non pagato:** non pagare di nuovo. Eseguire la SELECT del punto 3.3 e mandarmi id documento, `Stato` e `UltimoEsito` della transazione e gli eventi. Il webhook di norma riconcilia da solo; se non succede si decide insieme (si puo anche rimborsare da PayPal).
- **PayPal non compare / errore dopo il redirect:** controllare i registri `paypal-checkout-repository.log` e `paypal-payment-state.log` nella cartella dei registri dell'applicazione e dirmelo con l'ora.
- **Interruttore di spegnimento immediato (senza file):** nel gestionale, Tipi di Pagamento, togliere la spunta **Web** al metodo PayPal ON-LINE (pagamento 19 per Taikun, 12 per Webaffare): il carrello lo nasconde alla richiesta successiva. Gli ordini PayPal gia creati e non pagati conservano pero il collegamento «Paga ora»: per fermare anche quello, il PO o Enzo disattivano il collegamento azienda/metodo (`UPDATE paypal_checkout_azienda SET Attivo = 0 WHERE AziendeId = <id azienda>;`, un'azienda alla volta; per riattivarlo `Attivo = 1`): senza configurazione attiva nessun pagamento parte. In alternativa si ripristinano i due file (punto 1.5), che pero riportano anche il difetto.

## 7. Monitoraggio dopo l'accensione (prime 48 ore e poi a campione)
```sql
-- capture completata ma documento non pagato: deve restituire zero righe
SELECT t.DocumentiId, t.AziendeId, t.Stato, t.Importo, t.UpdatedAt, d.Pagato, d.StatoPagamentoWeb
FROM paypal_checkout_transazioni t INNER JOIN documenti d ON d.id = t.DocumentiId
WHERE t.Stato = 'COMPLETED' AND COALESCE(d.Pagato, 0) = 0;
-- panoramica per azienda e stato
SELECT t.AziendeId, t.Stato, COUNT(*) AS tentativi, MAX(t.UpdatedAt) AS ultimo
FROM paypal_checkout_transazioni t GROUP BY t.AziendeId, t.Stato ORDER BY t.AziendeId, t.Stato;
-- ordini PayPal fermi da oltre un'ora senza pagamento
SELECT d.id, d.AziendeId, d.DataDocumento, d.StatoPagamentoWeb, d.DataStatoPagamentoWeb
FROM documenti d
WHERE d.StatoPagamentoWeb IN (1, 3) AND COALESCE(d.Pagato, 0) = 0 AND d.DataStatoPagamentoWeb < NOW() - INTERVAL 1 HOUR
  AND d.PagamentiTipoId IN (SELECT id FROM pagamentitipo WHERE OnLine = 2)
ORDER BY d.id DESC LIMIT 50;
```
Un ordine fermo con `StatoPagamentoWeb = 1` e normale per qualche minuto (in attesa) o se il cliente ha abbandonato PayPal; con `3` il pagamento non e andato a buon fine.

## 8. Limiti noti
- Non verificabili da me: valori reali sul server oltre a quelli mostrati dalla verifica, impostazioni del pannello PayPal, opzione del connettore del server (la correzione vale con entrambe).
- Rischio raro e preesistente: un vecchio tentativo di un ordine interno approvato in un'altra scheda puo portare a due incassi; non e coperto.
- Le credenziali PayPal stanno in chiaro nella tabella degli account (finding dello standard dei segreti, fuori da questo task).
- La consegna al server resta sospesa finche il PO non la autorizza. Questo runbook e SOURCE: nessun file e stato pubblicato.
