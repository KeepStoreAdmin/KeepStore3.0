# PayPal Checkout document payment status

## Current checkpoint

PAYPAL-CHECKOUT-ORDERS-V2-LIVE-1A e PAYPAL-DB-DRIVEN-CREDENTIALS-1A sostituiscono il precedente motore PayPal Express con PayPal Checkout Orders API v2 REST, LIVE-only.

Stato al 2026-09-23: LIVE CONFIGURED / ENABLED. Il codice, le migration, la configurazione DB-driven, OAuth LIVE, account/mapping/metodi e webhook REST sono stati configurati e verificati tecnicamente. Il Product Owner ha scelto di non eseguire un pagamento reale di smoke; pertanto lo stato non viene etichettato LIVE VERIFIED come prova end-to-end di una transazione reale.

PR #270 e PR #271 risultano integrate in frontend-rebuild. Il runtime PayPal di riferimento e b5e75c28e534c28c8fd7d0e9c25f50d28f5c6dc4.

No NVP/SOAP, classic Express Checkout, runtime Sandbox o legacy IPN path resta parte del percorso PayPal attivo. La pagina/app NVP SOAP Webhooks non appartiene alla nuova integrazione REST.

## Authoritative configuration

- paypal_checkout_account identifica un account PayPal business e contiene MerchantId, ClientId, ClientSecret, WebhookId, CredentialKey e stato.
- paypal_checkout_azienda mappa l'esatta coppia AziendeId + PagamentiTipoId verso account, payee email, brand e valuta.
- Client ID, Client Secret e Webhook ID sono caricati esclusivamente dal DB. Nessun fallback PayPal da environment o appSettings.
- Client ID o Client Secret mancanti rendono il checkout non configurato; Webhook ID mancante rende il webhook non configurato.
- Un tenant privo del proprio mapping attivo non eredita configurazioni da altri tenant.
- Lo stesso account puo essere condiviso da piu aziende; aziende differenti possono usare account PayPal distinti.
- Il Client Secret non viene inviato al browser o scritto nei log. La protezione generale at-rest e un task trasversale separato.

Configurazione di riferimento: TAIKUN e WEBAFFARE condividono l'account PayPal configurato, mantenendo mapping tenant distinti. WEBAFFARE usa la payee email paypal@webaffare.it.

## Payment contract

paypalcheckout.aspx crea un Orders v2 order con intent CAPTURE, payee esatto, return/cancel URL canonici e PayPal-Request-Id deterministico persistito.

documenti.OrigineOrdine e autorevole:
- WEB: scritto dal checkout web nello stesso flusso di creazione ordine.
- INTERNO: deve essere scritto dal gestionale desktop nello stesso salvataggio che crea un ordine manuale idoneo.
- NULL o altri valori non abilitano il pagamento successivo come ordine interno.

Le transazioni PayPal sono attempt-aware; esiste un solo CurrentSlot=1 per documento. Retry tecnici riusano gli stessi request ID, mentre un nuovo tentativo volontario su ordine interno richiede riconciliazione autorevole.

paypalreturn.aspx non si fida dei parametri browser: rilegge ordine/capture da PayPal, verifica tenant, documento, importo, valuta, payee e merchant e scrive pagato solo per capture COMPLETED coerente.

paypalrecheck.aspx esegue solo Get Order e non recattura.

Marker documento:
- PP-ORDER:<OrderId>: ordine PayPal creato/approvato/pending, non prova pagamento.
- TXN:<CaptureId>: solo capture autorevole COMPLETED.
- Pagato=1 e StatoPagamentoWeb=2: solo dopo capture COMPLETED verificata.

## Webhook REST LIVE

Il listener pubblico e paypalwebhook.aspx su HTTPS. Le richieste GET del browser sono rifiutate con METHOD_NOT_ALLOWED; PayPal usa POST.

Il webhook della REST app LIVE e stato verificato tramite Webhooks Management API. Il set autorevole contiene:
1. CHECKOUT.ORDER.APPROVED
2. CHECKOUT.PAYMENT-APPROVAL.REVERSED
3. PAYMENT.CAPTURE.COMPLETED
4. PAYMENT.CAPTURE.DENIED
5. PAYMENT.CAPTURE.PENDING

Durante il setup l'evento CHECKOUT.PAYMENT-APPROVAL.REVERSED non risultava selezionabile nella UI Dashboard usata dall'operatore. Il webhook corretto e stato creato nella REST app LIVE, poi l'elenco e stato riconciliato tramite API. Un PATCH successivo ha restituito WEBHOOK_PATCH_REQUEST_NO_CHANGE, cioe il webhook era gia nello stato richiesto; il GET successivo ha confermato tutti e cinque gli eventi.

Il handler verifica la firma PayPal usando il Webhook ID del profilo DB prima delle scritture e processa gli Event ID in modo idempotente.

## Database transition

La migration 20260922_PAYPAL_CHECKOUT_ORDERS_V2_LIVE_1A_* e stata applicata all'installazione autorizzata:
- aggiunta documenti.OrigineOrdine quando assente;
- create paypal_checkout_account, paypal_checkout_azienda, paypal_checkout_transazioni, paypal_checkout_eventi;
- rimossi gli oggetti runtime PayPal Express legacy previsti dalla migration;
- nessun backfill di OrigineOrdine.

La migration 20260923_PAYPAL_DB_DRIVEN_CREDENTIALS_1A_* ha aggiunto a paypal_checkout_account:
- ClientId
- ClientSecret
- WebhookId

Il profilo account, i mapping azienda e i metodi PayPal risultano attivati nell'installazione autorizzata.

## Security and tests

Verifiche completate nel ciclo tecnico:
- OAuth LIVE: HTTP 200.
- Test fake REST: PASS.
- Test fake webhook: PASS.
- Test account condiviso fra due tenant: PASS.
- Test account distinti: PASS.
- Missing Client ID/Secret: fail closed.
- Nessun lookup PayPal runtime da environment/appSettings.
- Precompile ASP.NET Framework 4.8: PASS.
- Secret scan: PASS.
- Webhook REST: cinque eventi confermati via GET autorevole.

Credenziali, OAuth token, Authorization header e payload webhook completi non devono essere loggati o documentati.

## Stato di rilascio

Il gateway e configurato e abilitato LIVE nell'installazione autorizzata.

Non e stata eseguita una transazione reale di smoke per scelta esplicita del Product Owner. Di conseguenza:
- il task web/configurazione puo essere chiuso;
- non dichiarare una transazione reale verificata;
- la dicitura corretta e LIVE CONFIGURED / ENABLED, non LIVE VERIFIED.

Il successivo lavoro PayPal appartiene al gestionale Enzo: nuova schermata Orders v2, gestione account/mapping DB-driven e persistenza OrigineOrdine='INTERNO' per gli ordini manuali idonei.
