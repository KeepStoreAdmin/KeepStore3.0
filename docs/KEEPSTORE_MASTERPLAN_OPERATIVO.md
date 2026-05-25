# KeepStore Masterplan Operativo

Aggiornato: 2026-05-25

Questo documento e il punto di ripartenza operativo per nuove chat ChatGPT/Codex sul repository `KeepStoreAdmin/KeepStore3.0`.
Non contiene credenziali, token, password, API signature, dati carta o account PayPal reali.

## 1. Metodo ChatGPT + Codex

### Ruoli

- ChatGPT mantiene la direzione funzionale, la sequenza dei task e i criteri di accettazione.
- Codex lavora su branch dedicati, legge il codice prima di modificare, applica patch piccole e produce PR verso `frontend-rebuild`.
- Ogni task deve avere una modalita chiara: implementazione, verifica sola lettura, merge controllato, smoke, cleanup.

### Regole operative

- Branch base ordinario: `frontend-rebuild`.
- Non lavorare su `main` e non aprire PR verso `main`.
- Usare branch `task/<nome-task>`.
- Ogni implementazione termina con:
  - diff circoscritto;
  - precompilazione ASP.NET quando richiesta;
  - `git diff --check`;
  - commit;
  - push;
  - PR verso `frontend-rebuild`.
- Ogni verifica PR e in sola lettura:
  - niente commit;
  - niente push;
  - niente merge;
  - niente ordini o pagamenti.
- Ogni merge deve confermare:
  - PR open;
  - base corretta;
  - compare corretto;
  - head commit atteso;
  - `mergeable=true`;
  - `mergeable_state=clean`;
  - PR non verso `main`;
  - `main == origin/main`.
- Dopo merge:
  - aggiornare locale `frontend-rebuild` da origin;
  - confermare `HEAD == origin/frontend-rebuild`;
  - confermare working tree pulita.

### Sicurezza

- Non inserire secret nel repository.
- Non stampare password, API signature, client secret, token completi o NVP completi.
- Non usare account PayPal reale.
- Non inserire dati carta reali.
- Non chiamare gateway live salvo autorizzazione esplicita in task dedicato.
- Non modificare DB/dump SQL salvo task DB esplicito con backup.

## 2. Regola ONSUS per refactor UI

ONSUS e il riferimento grafico principale per i refactor UI del frontend KeepStore.

Quando si rifattorizza una pagina:

- analizzare prima il template ONSUS corrispondente;
- preservare la logica server e i permessi esistenti;
- sostituire la struttura grafica senza cambiare contratti DB o gateway;
- separare chiaramente dati gestionali e stati di pagamento;
- mantenere layout responsive e coerente con `Public/assets/keepstore`;
- modificare `theme-overrides.css` solo per aggiustamenti piccoli e mirati;
- non toccare header, footer, MiniCart, checkout o gateway se non richiesto.

## 3. Stato Git attuale

Stato di riferimento dopo DOC-DETAIL-2C:

- Branch stabile: `frontend-rebuild`
- HEAD stabile: `7df0d843ede8e8eb2e7676831f24773fb5796fb0`
- Merge PR #92: `7df0d843ede8e8eb2e7676831f24773fb5796fb0`
- `main` invariato rispetto a `origin/main` al momento dei task recenti.

Branch PayPal/config/document detail gia mergiati e, dove previsto, puliti:

- PR #81 PayPal state contract and sandbox-safe launcher skeleton
- PR #82 PayPal post-order routing to launcher
- PR #83 PayPal Express Checkout NVP implementation
- PR #84 DB-backed PayPal Express configuration
- PR #85 v3 clean schema alignment
- PR #86 fixed internal PayPal NVP version
- PR #87 transaction currency fix
- PR #88 cancel transaction state fix
- PR #89 PendingReason/ReasonCode tracking
- PR #90 pending transaction recheck
- PR #91 ONSUS document detail refactor
- PR #92 hide empty Pay Now card

## 4. Roadmap sintetica

### Pagamenti

1. Stabilizzare PayPal Express in sandbox.
2. Ottenere almeno un esito sandbox `Completed` con buyer Personal distinto dal merchant Business.
3. Verificare recheck pending con `GetTransactionDetails`.
4. Definire gestione amministrativa pending/paymentreview.
5. Preparare cifratura credenziali condivisa tra gestionale e sito.
6. Solo dopo sandbox completa, pianificare eventuale abilitazione live controllata.

### UI account/documenti

1. Continuare refactor ONSUS sulle pagine area account.
2. Separare sempre:
   - stato ordine;
   - stato pagamento.
3. Rifinire lista "I miei ordini" per allinearla al dettaglio ordine.
4. Aggiungere smoke desktop/mobile per ogni refactor.

### Documentazione

1. Aggiornare questo masterplan dopo merge importanti.
2. Aggiungere note operative per smoke PayPal sandbox.
3. Mantenere documenti tecnici senza secret.

## 5. Stato PayPal

### Decisione tecnica

KeepStore usa PayPal Express Checkout classico NVP:

- `SetExpressCheckout`
- `GetExpressCheckoutDetails`
- `DoExpressCheckoutPayment`
- `GetTransactionDetails` per recheck pending

Non usare REST Orders API v2 nel flusso attuale.
Non usare `_xclick` come checkout principale.
Non usare `ipn.aspx.vb` come autorita primaria.

### Configurazione

PayPal Express e multi-azienda e legge configurazione da DB tramite `vpaypal_express_azienda`.

Schema runtime definitivo:

- `ApiUsername`
- `ApiPasswordProtetta`
- `ApiSignatureProtetta`
- `BusinessAccount`
- `Environment`
- `CurrencyCode`
- `AllowLive`
- `Attivo`

Scelte definitive:

- niente dipendenza runtime da `VersioneApi`;
- niente dipendenza runtime da `CredenzialiProtette`;
- niente alias intermedi nella view;
- `DEFAULT_PAYPAL_NVP_VERSION = "204.0"` in `PayPalCheckoutConfig.vb`;
- `VERSION=204.0` per Set/Get/Do/Recheck.

### Stato pagamento KeepStore

Campi documento usati:

- `Pagato`
- `IdTransazione`
- `StatoPagamentoWeb`
- `DataStatoPagamentoWeb`
- `UltimoEsitoPagamentoWeb`

Mapping operativo:

- `0` o `NULL`: non avviato
- `1`: in attesa / in verifica PayPal
- `2`: pagato
- `3`: non completato / errore
- `4`: annullato dall'utente
- `5`: fallback legacy / in verifica

Regola vincolante:

- `Pagato=1` solo dopo `DoExpressCheckoutPayment` verificato con ACK success e `PaymentStatus=Completed`, oppure dopo recheck `GetTransactionDetails` che conferma stato completed su TransactionID gia esistente.
- Non richiamare `DoExpressCheckoutPayment` su transazione gia creata.

### Token e TransactionID

Convenzione:

- token Express temporaneo: `EC-TOKEN:<token>` in `documenti.IdTransazione`;
- transazione completata: `TXN:<transactionId>` in `documenti.IdTransazione`.

Nei log/report:

- token sempre mascherato;
- transaction id sempre mascherato se mostrato;
- nessuna query NVP completa.

### Stato sandbox recente

Smoke principali:

- SetExpressCheckout sandbox: stabile, token creato, redirect sandbox OK.
- Cancel sandbox: stabile, documento `StatoPagamentoWeb=4`, retry Pay Now consentito se policy legacy lo permette.
- Transazione cancel: `paypal_express_transazioni.Stato=CANCELED`.
- Pending sandbox: stabile con `PaymentStatus=Pending`, `PendingReason=paymentreview`, `Pagato=0`, `StatoPagamentoWeb=1`, Pay Now non visibile.
- Recheck pending: implementato con `GetTransactionDetails`, senza richiamare Do.

Documenti PayPal di riferimento:

- `167333` / ordine `162`: pending `paymentreview` con recheck.
- `167334` / ordine `163`: pending `paymentreview`.
- `167336` / ordine `165`: canceled, retry PayPal disponibile.

## 6. Stato Document Detail

La pagina `documentidettaglio.aspx` e stata rifattorizzata con struttura ONSUS.

Concetti separati:

- Stato ordine: stato gestionale/documento, per esempio `Inviato`.
- Stato pagamento: derivato da `Pagato`, `StatoPagamentoWeb`, `UltimoEsitoPagamentoWeb` e motivazioni PayPal salvate.

Blocchi principali:

- breadcrumb Home / Account / Ordini / Dettaglio;
- overview ordine;
- card Stato ordine;
- card Stato pagamento;
- card Spedizione, pagamento e tracking;
- card indirizzi;
- card Prodotti;
- card Riepilogo;
- card Paga adesso, solo se esiste un'azione reale.

### Pay Now

Stato dopo PR #92:

- pending PayPal `StatoPagamentoWeb=1`: nessun link Pay Now/PayPal e nessuna card vuota `Paga adesso`;
- canceled PayPal `StatoPagamentoWeb=4`: card visibile solo se retry ammesso e contiene link reale a `paypalcheckout.aspx?id=<documentId>`;
- documento pagato: card non visibile;
- BancaSella: URL/logica invariati, cambia solo la visibilita del contenitore.

Smoke DOC-DETAIL-2C-D:

- `167334`: pending, card `Paga adesso` non visibile.
- `167333`: pending, card `Paga adesso` non visibile.
- `167336`: canceled, card visibile con link reale PayPal retry.
- mobile `390x844`: nessuna card vuota e nessun overflow sui casi principali.

## 7. Prossimi step consigliati

### Immediati

1. Merge e cleanup del branch `task/docs-1-masterplan-operativo`.
2. Continuare con smoke/cleanup dei branch document detail rimasti.
3. Decidere prossimo task PayPal:
   - retry sandbox per ottenere `Completed`;
   - oppure UI/admin per pending review.

### PayPal Express

1. Riprovare pagamento sandbox con buyer Personal distinto dal merchant Business.
2. Se PayPal restituisce ancora `Pending`:
   - confermare `PendingReason`;
   - non impostare `Pagato=1`;
   - usare recheck.
3. Se PayPal restituisce `Completed`:
   - `Pagato=1`;
   - `StatoPagamentoWeb=2`;
   - `IdTransazione=TXN:<transactionId>`;
   - transazione `COMPLETED`;
   - Pay Now non visibile.

### UI

1. Refactor ONSUS della lista ordini.
2. Mostrare nella lista ordini anche lo stato pagamento, separato dallo stato ordine.
3. Verificare casi:
   - pending PayPal;
   - canceled PayPal;
   - failed PayPal;
   - BancaSella;
   - bonifico/contanti;
   - documento pagato.

## 8. Guardrail permanenti

- Non toccare `main` senza task esplicito.
- Non creare PR verso `main`.
- Non modificare DB/dump SQL senza backup e task DB dedicato.
- Non modificare gateway PayPal/BancaSella in task UI.
- Non creare ordini o pagamenti senza autorizzazione esplicita.
- Non chiamare PayPal live senza task dedicato e consenso esplicito.
- Non inserire o stampare secret.
- Non esporre token o transaction id completi in UI/log/report.
- Non confondere stato ordine con stato pagamento.
