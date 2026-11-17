# PayPal «l'ordine si salva solo se il pagamento va a buon fine» - attivazione (17/11/2026)

Runbook di PO ed Enzo per attivare il progetto [PAYPAL_PAY_FIRST_DESIGN](PAYPAL_PAY_FIRST_DESIGN.md). Stato: **SOURCE INTEGRATED, non pubblicato**; le fasi P1-P3b sono nel Masterplan. **Con il flag a 1 (oggi su tutti i database) il sito si comporta come prima**: non c'e nulla da fare finche non decidi di attivare. CONSEGNA SERVER SOSPESA.

## 1. Che cosa fa, in una riga
Con `pagamentitipo.ConfermaOrdinePrimaPagamento = 0` su un metodo PayPal, il cliente approva su PayPal e **PayPal riserva l'importo (autorizzazione, nessun addebito)**; solo allora il database crea l'ordine (e il suo numero); subito dopo il sito incassa l'autorizzazione e segna l'ordine pagato; l'e-mail «ordine ricevuto» parte solo allora. Annullo, rifiuto o abbandono prima dell'ordine: **nessun numero consumato, nessun ordine, nessun addebito**, carrello intatto. Con flag 1, preventivi e coupon: tutto come oggi.

## 2. Prerequisiti (tutti, prima di mettere il flag a 0 su un database)
1. **Tabella dei tentativi** creata sul database: script `preflight`, `forward`, `verify` in [PAYPAL_PAY_FIRST_ATTEMPTS_TABLE](PAYPAL_PAY_FIRST_ATTEMPTS_TABLE.md). La esegui tu su `taikun`; il programma di allineamento di Enzo la porta sugli altri database. Se manca, il pay-first non parte (il checkout si ferma con un messaggio, senza creare ordini).
2. **Totali del carrello**: la routine `Carrello_Totali` (migrazioni `ORDER_ROUNDING_HALF_UP_1A` e `ORDER_TOTALS_DB_SOURCE_1A`) presente sul database.
3. **PayPal gia collaudato con il flag a 1**: almeno un pagamento reale di importo minimo dal percorso di oggi (vedi [runbook del primo pagamento](PAYPAL_CHECKOUT_FIRST_LIVE_PAYMENT_RUNBOOK.md)). Il pay-first usa la stessa configurazione (`paypal_checkout_account` e `paypal_checkout_azienda`).
4. **Webhook PayPal**: nel pannello sviluppatori PayPal, oltre agli eventi di oggi (`CHECKOUT.ORDER.APPROVED`, `CHECKOUT.PAYMENT-APPROVAL.REVERSED`, `PAYMENT.CAPTURE.COMPLETED`, `PAYMENT.CAPTURE.PENDING`, `PAYMENT.CAPTURE.DENIED`) vanno aggiunti **`PAYMENT.CAPTURE.DECLINED`, `PAYMENT.AUTHORIZATION.CREATED`, `PAYMENT.AUTHORIZATION.VOIDED`**. Senza, il sito funziona ma un incasso fatto a mano dal pannello o un annullo esterno non si riconciliano da soli.
5. **File pubblicati insieme** (nell'ordine): `App_Code`: `PayPalOrdersV2Client.vb`, `PayPalPaymentAttemptStates.vb`, `PayPalPaymentAttempts.vb`, `PayPalPayFirst.vb`, `PayPalPayFirstFinish.vb`, `PayPalPayFirstRecovery.vb`, `PayPalCheckoutRepository.vb`, `PayPalPaymentState.vb`, `StorefrontCanonicalHostPolicy.vb`, `StorefrontReturnUrlPolicy.vb`; poi le pagine `paypalpay.aspx`, `paypalpay.aspx.vb`, `paypalcheckout.aspx.vb`, `paypalreturn.aspx.vb`, `paypalwebhook.aspx.vb`, `ordine.aspx.vb`. Un pacchetto parziale non e ammesso (`ordine.aspx.vb` usa le classi nuove).
6. **Hai accettato il rischio residuo** ([progetto, punto 5](PAYPAL_PAY_FIRST_DESIGN.md)): un'autorizzazione valida che PayPal poi non incassa lascia un documento **non pagato** (`StatoPagamentoWeb = 3`, nessun addebito) da annullare a mano.
7. **Verifica del flag sui database** (sola lettura; se ritorna righe, il pay-first si attiva SUBITO alla pubblicazione su quel database):
```sql
SELECT id, AziendeID, Descrizione, ConfermaOrdinePrimaPagamento, PermettiPagamentoSuccessivo, InviaEmailOrdinePrimaPagamento
FROM pagamentitipo WHERE OnLine = 2 AND ConfermaOrdinePrimaPagamento = 0;
```

## 3. Attivazione (un solo metodo, un solo database, prima)
1. Dopo la pubblicazione, nel gestionale: Tipi di Pagamento -> riga «PayPal ON-LINE» dell'azienda di prova -> `ConfermaOrdinePrimaPagamento = 0`, `PermettiPagamentoSuccessivo = 0`, `InviaEmailOrdinePrimaPagamento = 0` (riga «PayPal bloccante» del manuale [payment-confirmation-policy](payment-confirmation-policy.md)); Salva. Il primo flag e quello che conta; gli altri due sono coerenti con «nessun Paga ora» e «e-mail solo dopo il pagamento».
2. Ordine di prova **di importo minimo, con un tuo account PayPal reale**. Esito atteso: schermata PayPal -> ritorno -> pagina di conferma con il numero; e-mail «ordine ricevuto»; nel gestionale l'ordine e **pagato**. Prova anche: **annulla su PayPal** (carrello intatto, nessun ordine, nessun numero consumato) e **chiudi il browser dopo l'approvazione** (nessun ordine; l'autorizzazione si libera da sola).
3. Controlli sul database dopo la prova (sola lettura):
```sql
SELECT Id, Stato, Importo, DocumentiId, UltimoEsito, CreatedAt, UpdatedAt
FROM paypal_checkout_tentativi ORDER BY Id DESC LIMIT 10;
-- atteso per l'ordine di prova: COMPLETED con DocumentiId e PayPalCaptureId
SELECT d.Id, d.NDocumento, d.Pagato, d.StatoPagamentoWeb, d.UltimoEsitoPagamentoWeb
FROM documenti d INNER JOIN paypal_checkout_tentativi t ON t.DocumentiId = d.Id ORDER BY d.Id DESC LIMIT 10;
-- atteso: Pagato = 1, StatoPagamentoWeb = 2
```
4. **Marcia indietro**: rimetti `ConfermaOrdinePrimaPagamento = 1` nella stessa riga e salva; il sito torna al percorso di oggi subito (nessuna pubblicazione). I tentativi gia aperti si chiudono da soli.

## 4. Controllo periodico (finche non ti fidi)
```sql
-- Tentativi fermi da oltre 10 minuti (non conclusi): da guardare, normalmente nessuno.
SELECT Id, Stato, StatoPrecedente, DocumentiId, UltimoEsito, UpdatedAt
FROM paypal_checkout_tentativi
WHERE Stato IN ('CAPTURING','CAPTURE_REFUSED','VOIDING','UNKNOWN') AND UpdatedAt < NOW() - INTERVAL 10 MINUTE;
-- Ordini creati ma non pagati (incasso rifiutato o in verifica): il cliente puo ripetere dal dettaglio ordine, altrimenti da annullare a mano.
SELECT d.Id, d.NDocumento, d.StatoPagamentoWeb, d.UltimoEsitoPagamentoWeb, t.Stato
FROM documenti d INNER JOIN paypal_checkout_tentativi t ON t.DocumentiId = d.Id WHERE COALESCE(d.Pagato,0) = 0;
-- Incassi senza ordine (orfani): da rimborsare o abbinare a mano.
SELECT Id, PayPalCaptureId, UltimoEsito, UpdatedAt FROM paypal_checkout_tentativi WHERE Stato = 'CAPTURED_ORPHAN';
```

## 5. Per Enzo
- **Obbligatorio:** portare la tabella `paypal_checkout_tentativi` sugli altri database (dopo `paypal_checkout_azienda` e `paypal_checkout_account`, da cui dipende per chiave esterna) con il programma di allineamento. Nessuno schermo nuovo e necessario: le tre colonne di politica sono in fondo alla griglia «Tipi di Pagamento».
- **Facoltativo:** didascalie e caselle di spunta per le tre colonne e i valori predefiniti nell'evento di inserimento `jDatiPag_AddingRecord`.
- Un ordine pay-first compare nel gestionale **solo dopo** l'autorizzazione PayPal; per qualche secondo puo risultare non pagato (`StatoPagamentoWeb = 1`, «PayPal: autorizzato, incasso in corso»). Se l'incasso e rifiutato resta non pagato (`StatoPagamentoWeb = 3`): non evadere, annullare.

## 6. Limiti noti e da decidere
- **Mai provato con PayPal reale:** forma esatta delle risposte di authorize, capture e annullo; durata di conservazione del `PayPal-Request-Id`; effetto di un `invoice_id` diverso all'incasso (c'e il ritentativo senza). Si sapra solo con il primo pagamento reale.
- **E-mail:** parte solo se l'incasso lo chiude la pagina del cliente; se lo chiude il webhook (cliente uscito dal browser) l'ordine e pagato ma l'e-mail non parte (l'invio usa la sessione del cliente).
- **Pixel pubblicitario:** non parte mai dopo l'ordine (difetto preesistente: la risposta e un redirect).
- **Conservazione:** nessuna pulizia automatica delle righe vecchie di `paypal_checkout_tentativi`; da decidere prima di una lunga attivazione.
- **Autorizzazioni abbandonate:** si liberano quando lo stesso cliente torna a pagare e comunque scadono da sole (tre giorni garantiti da PayPal); non c'e un lavoro periodico.
- **Secret PayPal** in chiaro in `paypal_checkout_account` (debito noto, fuori da questo progetto).
