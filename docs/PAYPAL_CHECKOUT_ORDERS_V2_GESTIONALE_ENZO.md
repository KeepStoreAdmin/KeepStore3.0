# PayPal Checkout - Impostazioni Azienda

## Scopo

Contratto per la nuova schermata gestionale che sostituisce integralmente la UI PayPal Express. Il sorgente desktop non è in questo repository: questo documento specifica dati, query, validazioni e comportamento senza inventare modifiche al gestionale.

## Sezione Conto PayPal LIVE

Campi visibili:

- Nome profilo;
- Tecnologia: `PayPal Checkout - Orders API v2`;
- Chiave logica del profilo (`CredentialKey`), senza dipendenze da environment o `web.config`;
- Merchant ID, eventualmente mascherato fuori dalla modalità amministrativa;
- Client ID;
- Client Secret: campo password/write-only, mai restituito in edit;
- Webhook ID;
- Credenziali API: `Configurate` / `Non configurate`, senza mostrare il Client Secret;
- Webhook: `Configurato` / `Non configurato`;
- Stato attivo/inattivo;
- Ambiente fisso: `LIVE`;
- Ultima verifica e relativo esito sanitizzato;
- pulsante `Verifica ora`.

La tabella autorevole è `paypal_checkout_account`. Insert e update gestiscono `NomeProfilo`, `CredentialKey`, `MerchantId`, `ClientId`, `ClientSecret`, `WebhookId`, `Attivo` e `Note`. `CredentialKey` deve rispettare `^[A-Z][A-Z0-9_]{2,63}$` ed essere univoca. Il Client Secret viene scritto nel database senza mai mostrarne il valore: in edit il campo resta vuoto, vuoto significa non sostituire e la sostituzione richiede un'azione esplicita. Non includere il segreto in letture UI, audit, log o export. La protezione generale a riposo rimane un task separato.

`Verifica ora` deve verificare struttura e presenza dei campi del profilo DB tramite un endpoint amministrativo futuro autenticato e auditato; non deve restituire i valori, creare ordini, acquisire pagamenti o diventare un test LIVE implicito.

## Sezione Aziende collegate

Colonne:

- Azienda;
- Tipo pagamento;
- Email PayPal;
- Brand checkout;
- Valuta;
- Attivo.

Configurazione approvata:

| Azienda | Email PayPal | Brand checkout | Valuta |
| --- | --- | --- | --- |
| TAIKUN | `info@taikun.it` | `TAIKUN` | `EUR` |
| WEBAFFARE | `info@webaffare.it` | `WEBAFFARE` | `EUR` |

Entrambe le righe puntano allo stesso `PayPalAccountId`, ma restano distinte per `AziendeId + PagamentiTipoId`. Il gestionale legge `aziende`, `pagamentitipo`, `paypal_checkout_account` e `paypal_checkout_azienda`; non deduce aziende compatibili e non copia configurazioni fra tenant.

Insert/update richiedono azienda esistente, tipo pagamento con `OnLine=2`, account attivo, email valida, brand non vuoto, valuta ISO a tre lettere e unicità della coppia azienda/pagamento. Un errore mostra un messaggio operativo senza query, credenziali o dati tecnici sensibili.

Pulsanti previsti: `Nuovo collegamento`, `Salva`, `Disattiva`, `Annulla`, `Verifica configurazione`. La disattivazione è logica; la cancellazione è vietata quando esistono transazioni.

## Regole vincolanti

- Nessuna seconda schermata Express, NVP/SOAP, password API o signature legacy.
- Nessun Client Secret visibile, copiabile, esportabile, registrato nei log o inviato al browser; la persistenza riservata è limitata al profilo DB.
- Nessun fallback globale o cross-tenant.
- `AccountPaypal` storico non alimenta il runtime Orders v2.
- La schermata può dichiarare `Configurata` solo dopo migration, dati del profilo DB completi e verify; non può dichiarare `LIVE VERIFIED` senza smoke reale separatamente autorizzato.

## Ordine interno con pagamento remoto

`documenti.OrigineOrdine` e la fonte autorevole della provenienza. La migration Orders v2 aggiunge `VARCHAR(16) NULL` solo se il campo non esiste gia. Il gestionale desktop, non presente in questo repository, deve scrivere `INTERNO` **nello stesso salvataggio che crea manualmente un nuovo ordine**. Non dedurre `INTERNO` da `Ordine_Web=0`, dall'assenza di `ordini_web_idempotenza` o dalla presenza di PayPal. Non effettuare backfill dei documenti storici. Le importazioni Amazon/eBay non sono ordini interni; se il canale non e certo, lasciare `NULL` finche una fonte autorevole non sara disponibile.

Sequenza per la vendita a distanza/telefonica:

1. Selezionare cliente e azienda/vetrina corretti. Verificare l'associazione del cliente al suo account web: il nuovo `documenti.UtentiId` deve essere proprio l'`UtentiId` che l'account usa nella medesima `AziendeId`.
2. Creare un documento di tipo **ORDINE** abilitato al web e all'impegno di quantita (`tipodocumenti.Web=1`, `Abilitato=1`, `ImpegnaQnt=1`), non preventivo/fattura o documento annullato.
3. Salvare `documenti.OrigineOrdine='INTERNO'` al momento della creazione. Il checkout sito scrive invece `WEB` nella transazione dell'ordine; il gestionale non deve sovrascriverlo.
4. Scegliere il `PagamentiTipoId` della stessa azienda con `pagamentitipo.OnLine=2` per PayPal oppure `OnLine=3` per Banca Sella. Il metodo deve avere `PermettiPagamentoSuccessivo=1`; la coppia azienda/metodo PayPal deve disporre della propria configurazione Orders v2 completa e attiva.
5. Salvare `documenti.Pagato=0` e `StatoPagamentoWeb=0` (non avviato), senza `bancasella_ordini_pagati.codiceAutorizzazione`. Il totale in `documentipie.TotaleDocumento` deve essere positivo.
6. Il cliente autenticato nella vetrina corretta vede il proprio ordine nell'area personale e il solo comando pertinente: `Paga con PayPal` oppure `Paga con carta`. Il comando resta disponibile per un ordine interno non pagato; un tentativo PayPal gia in corso viene prima riconciliato, non duplicato.
7. Solo la conferma autorevole del gateway aggiorna `Pagato=1`. Una creazione ordine PayPal, una approvazione browser, un EC-TOKEN o un rientro non sono prove di pagamento.

Query di verifica gestionale, parametrizzata con ID di documento e azienda risolti dal contesto autenticato (mai da testo libero di un URL):

```sql
SELECT d.Id, d.AziendeId, d.UtentiId, d.TipoDocumentiId,
       d.OrigineOrdine, d.PagamentiTipoId, d.Pagato,
       d.StatoPagamentoWeb, d.StatiId,
       td.Web, td.Abilitato, td.ImpegnaQnt,
       p.OnLine, p.PermettiPagamentoSuccessivo,
       pie.TotaleDocumento
FROM documenti d
JOIN tipodocumenti td ON td.Id=d.TipoDocumentiId
JOIN pagamentitipo p ON p.Id=d.PagamentiTipoId
JOIN documentipie pie ON pie.DocumentiId=d.Id
WHERE d.Id=@DocumentiId AND d.AziendeId=@AziendeId;
```

`NULL`, `UNKNOWN`, `WEB`, `AMAZON`, `EBAY` o qualsiasi provenienza diversa da `INTERNO` non abilitano il pagamento successivo nell'area cliente. L'ordine WEB mantiene il proprio lancio gateway **solo nel checkout iniziale**. La lista documenti conserva il badge generico dello stato saldato/non saldato; non equivale a un invito a pagare.

I quattro oggetti nuovi sono `paypal_checkout_account`, `paypal_checkout_azienda`, `paypal_checkout_transazioni` e `paypal_checkout_eventi`. Non migrare credenziali o storico Express in queste tabelle; `paypal_checkout_legacy_audit` non fa parte dello schema finale.
