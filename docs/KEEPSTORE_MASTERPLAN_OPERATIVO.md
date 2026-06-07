# KeepStore Masterplan Operativo

Aggiornato: 2026-06-06

Questo documento e il punto di ripartenza operativo per nuove chat ChatGPT/Codex sul repository `KeepStoreAdmin/KeepStore3.0`.
Non contiene credenziali, token, password, API signature, dati carta o account PayPal reali.

## Contratto operativo Germano / ChatGPT / Codex

### Germano

- Decide priorita e perimetro.
- Autorizza merge, smoke, pagamenti sandbox/live, modifiche DB e modifiche gateway.
- Approva scelte funzionali e grafiche.
- Puo fermare o riorientare i micro-task in qualsiasi momento.

### ChatGPT

- Analizza contesto e report.
- Pianifica micro-task.
- Scrive istruzioni operative per Codex.
- Definisce guardrail.
- Verifica i report Codex.
- Classifica gli esiti come A/B/E.
- Decide il prossimo micro-task da proporre.
- Mantiene aggiornato il masterplan.
- Non deve saltare passaggi o cambiare metodo.

### Codex

- Esegue operativamente nel repository.
- Crea branch dedicati.
- Modifica file entro il perimetro autorizzato.
- Esegue build, precompilazioni, `git diff --check` e smoke test richiesti.
- Apre PR verso la base indicata.
- Non deve cambiare perimetro senza fermarsi.
- Non deve toccare `main`.
- Non deve creare pagamenti, ordini o chiamate gateway senza autorizzazione.
- Riporta esiti in modo preciso.

### Metodo

- Ogni lavoro passa da micro-task.
- Ogni PR passa da verifica B.
- Ogni merge passa da smoke D.
- Ogni cleanup avviene solo dopo smoke A/B.
- Per refactor UI si usa prima audit ONSUS, poi implementazione coerente.
- Niente patch sul vecchio layout quando si cambia grafica/impostazione.
- Usare sempre campi DB esistenti e query/logiche esistenti quando possibile.
- Modifiche strutturali o logiche vecchie richiedono prima analisi impatto e proposta micro-task.

### Nuova chat

- Leggere subito `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`.
- Riprendere da HEAD/stato indicati.
- Mantenere lo stesso metodo Germano/ChatGPT/Codex.
- Non ripetere audit gia conclusi se nel masterplan sono marcati chiusi.

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
Quando si rifattorizza o si adegua una pagina, la priorita visuale e di esperienza utente va data a ONSUS e a una UX moderna 2026.

Principio operativo:

- KeepStore legacy resta fonte dati, contratti, permessi e logica esistente.
- La presentazione deve seguire ONSUS quando offre una struttura piu efficace.
- Le informazioni devono essere chiare, intuitive, sintetiche e leggibili senza percorsi macchinosi.
- Non bisogna replicare automaticamente schermate legacy se il template ONSUS permette una lettura piu moderna.
- Se una logica legacy e vecchia, errata o poco moderna, non va corretta di nascosto dentro un refactor grafico: serve prima analisi impatto e proposta micro-task.
- Germano decide se intervenire subito sulla logica o rimandare.

Quando si rifattorizza una pagina:

- analizzare prima il template ONSUS corrispondente;
- preservare la logica server e i permessi esistenti;
- sostituire la struttura grafica senza cambiare contratti DB o gateway;
- separare chiaramente dati gestionali e stati di pagamento;
- mantenere layout responsive e coerente con `Public/assets/keepstore`;
- modificare `theme-overrides.css` solo per aggiustamenti piccoli e mirati;
- non toccare header, footer, MiniCart, checkout o gateway se non richiesto.

## 3. Stato Git attuale

Stato di riferimento dopo RESET-LOGIN-REDIRECT-1B, merge PR #130 e smoke live finale Germano:

- Branch stabile: `frontend-rebuild`
- HEAD stabile: `e621eca0a110d2b02d4b83afc27716738108a64a`
- Merge PR #98: `12f4fd5ec2dff6c15ee7479e854628bd71dc9ed5`
- Merge PR #100: `f0eeccc12d701268641dc10950bb1253670f86fa`
- Merge PR #101: `7bfd40cb685e0500f427cf4a481516f70038d235`
- Merge PR #102: `919b342bd0d0c9ff7b7bddc0453f99e4efe79fbc`
- Merge PR #103: `8a3efe677fce31c7eb7f590747ac1a7d2cf7197d`
- Merge PR #104: `7279f797be01090b573d514a9a64d5519ebe4489`
- Merge PR #105: `fbafc68ca36b2ba19a9d16d50af05313e3824209`
- Merge PR #107: `a4381b83ec5c617c6dc75022d30580ded5394f62`
- Merge PR #109: `7fe10f0edfbc7b7d5951116697c6654a100ba60f`
- Merge PR #111: `90c13d3bb41ff8d437f3cc9605a736659b04f4ce`
- Merge PR #112: `3d1873f5e3ea071ef187cc906f5d8712a58a09e6`
- Merge PR #117: `f51ab9a4df9afb71760a31db97ed0eac547cd9c3`
- Merge PR #121: `f11cf0b434b9be111d470b995083edf9d18b481b`
- Merge PR #122: `3415094758e4b3cdc38d5284daf1e847695766c4`
- Merge PR #123: `93a186e850caf5195b8bb7b3e21c42e5cf1c15af`
- Merge PR #124: `9d9d56661db0bcf4f6cdfa1dae331db05b7d5f20`
- Merge PR #126: `c5b85354f9f589354d2e08ec14502f6ac5d159c2`
- Merge PR #127: `30be626aeb285f3fa6cb6e6f98bc47ba081edba0`
- Merge PR #128: `687198cf51a8d57f61acc997856ffd2eac7cd9e4`
- Merge PR #130: `e621eca0a110d2b02d4b83afc27716738108a64a`
- `main` invariato: `976e99f17cabc8a5c6a8715463444edfeaadcd91`

Branch PayPal/config/document detail/my orders/account dashboard/account profile gia mergiati e, dove previsto, puliti:

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
- PR #94 ONSUS my orders list refactor
- PR #95 stato filter fix, superato dal fix definitivo successivo
- PR #96 documenti filters GET fix
- PR #98 ONSUS account dashboard refactor
- PR #100 ONSUS account profile refactor
- PR #101 account sidebar root-level links fix
- PR #102 account sidebar active/current fix
- PR #103 masterplan update after account profile closure
- PR #104 masterplan sidebar inline debt correction
- PR #105 account sidebar inline cleanup phase 1 simple pages
- PR #107 account address ONSUS read-only refactor
- PR #109 account documenti sidebar cleanup phase 2 with dynamic document selector
- PR #111 account password canonical flow
- PR #112 account password confirmation validation hotfix
- PR #117 login/registrazione/reminder immediate security mitigations
- PR #121 feedback Germano su reset token, gestionale e `aziende.ScadenzaPassword`
- PR #122 masterplan post PR #121 closure alignment
- PR #123 script DB idempotente `login_password_reset_tokens` versionato, non eseguito
- PR #124 handoff operativo Vincenzo per script DB reset tokenizzato

## 4. Roadmap sintetica

### Pagamenti

1. Stabilizzare PayPal Express in sandbox.
2. Ottenere almeno un esito sandbox `Completed` con buyer Personal distinto dal merchant Business.
3. Verificare recheck pending con `GetTransactionDetails`.
4. Definire gestione amministrativa pending/paymentreview.
5. Preparare cifratura credenziali condivisa tra gestionale e sito.
6. Solo dopo sandbox completa, pianificare eventuale abilitazione live controllata.

### UI account/documenti

1. Continuare refactor ONSUS sulle pagine area account non ancora migrate.
2. Separare sempre:
   - stato ordine;
   - stato pagamento.
3. Mantenere dashboard, lista ordini e dettaglio ordine coerenti tra loro.
4. Aggiungere smoke desktop/mobile per ogni refactor.
5. Evitare azioni gateway dirette nelle liste: il retry pagamento resta nel dettaglio ordine salvo task dedicato.
6. Stato area account gia stabilizzata:
   - `documentidettaglio.aspx`: stabile;
   - `documenti.aspx`: stabile con AccountSidebar globale e selector documenti dinamico;
   - `myaccount.aspx`: stabile;
   - `my-account-edit.aspx`: stabile.
   - `wishlist.aspx`: stabile;
   - `my-account-address.aspx`: stabile read-only ONSUS.
   - `password.aspx`: stabile come pagina canonica cambio password.
   - `cambiapassword.aspx`: legacy redirect controllato verso `password.aspx`.

### Documentazione

1. Aggiornare questo masterplan dopo merge importanti.
2. Aggiungere note operative per smoke PayPal sandbox.
3. Mantenere documenti tecnici senza secret.

### Sicurezza login/registrazione/reminder

1. LOGIN-REGISTER-SECURITY-1 e chiuso lato codice con PR #117.
2. Login, registrazione e reminder sono mitigati senza schema change e senza hash migration.
3. Reminder automatico password disabilitato; recupero assistito superato dal reset tokenizzato fase 1.
4. Registrazione non deve esporre password in email, URL o sessione.
5. Hash migration e audit gestionale restano task separati.

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

## 7. Stato My Orders / documenti.aspx

MY-ORDERS-1 e chiuso.
ACCOUNT-SIDEBAR-INLINE-CLEANUP-2B su `documenti.aspx` e chiuso.

Esiti principali:

- MY-ORDERS-1A audit ONSUS: A.
- MY-ORDERS-1B/1C refactor lista ONSUS: completato.
- PR #94 merge commit: `b3970df0838a805adb6db6d4eb1adfc1126582b4`.
- MY-ORDERS-1D filtro stato: superato dalla correzione successiva.
- PR #95 merge commit: `c96fe7ef95574831d9874a497df85c283c31099b`.
- MY-ORDERS-1E fix definitivo filtri GET: completato.
- PR #96 merge commit: `41a709b22ce37bf6b1669f52b690824082e4ebc1`.
- Smoke MY-ORDERS-1E-D: A.
- Cleanup branch MY-ORDERS: completato.
- PR #109 merge commit: `7fe10f0edfbc7b7d5951116697c6654a100ba60f`.
- Branch task PR #109: `task/account-sidebar-inline-cleanup-2b-documenti`.
- Cleanup branch PR #109 completato: branch locale e remoto rimossi.

Comportamento finale `documenti.aspx`:

- layout ONSUS account/orders;
- `Page.master.vb` include `documenti.aspx` tra le pagine con `body.ks-page-account`;
- AccountSidebar globale visibile/usabile;
- voce Ordini/Documenti active/current corretta con una sola voce `active` e un solo `aria-current`;
- nav inline legacy `.myaccount-nav` rimossa/non visibile;
- nessuna doppia sidebar visibile;
- selector dinamico `sdsTipo` mantenuto/ripristinato;
- `asp:Repeater rTipo` mantenuto con `DataSourceID="sdsTipo"`;
- `LinkButton lbTipoDocumento` mantenuto con attributo `tipoDocumento`, `tipoDocumentoClick` e `preRenderClick`;
- hardcoding esclusivo `t=4/2/1` eliminato;
- tipi documento extra non esclusi;
- colonne: Numero, Data, Totale, Metodo pagamento, Stato ordine, Stato pagamento, Azione;
- Azione solo `Dettaglio`;
- azione Dettaglio invariata;
- nessun Pay Now diretto in lista;
- nessun link PayPal/BancaSella/gateway diretto in lista;
- nessun Pay Now/gateway diretto introdotto;
- tracking non in Azione;
- filtri GET validati;
- filtro `Inviato`: OK;
- filtro `ultimo mese`: OK;
- filtro `In lavorazione`: OK;
- combinazione `Inviato + ultimo mese`: OK;
- mobile `390x844`: OK;
- nessun ordine, pagamento o gateway chiamato nello smoke.
- `documenti.aspx.vb` invariato.

File modificati da ACCOUNT-SIDEBAR-INLINE-CLEANUP-2B:

- `Page.master.vb`
- `documenti.aspx`

File non modificati:

- `documenti.aspx.vb`
- `documentidettaglio.aspx`
- `documentidettaglio.aspx.vb`
- `datiutente.aspx`
- `datiutente.aspx.vb`
- `datiutente-ui.js`
- `password.aspx`
- `password.aspx.vb`
- `cambiapassword.aspx`
- `cambiapassword.aspx.vb`
- `myaccount.aspx`
- `my-account-edit.aspx`
- `my-account-address.aspx`
- `wishlist.aspx`
- `web.config`
- markup `Page.master`
- DB/schema/dump SQL
- checkout/carrello/gateway/pagamenti
- asset ONSUS originali

Smoke finale ACCOUNT-SIDEBAR-INLINE-CLEANUP-2H:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Login PROVA OK.
- `documenti.aspx` desktop OK.
- Redirect previsto a `documenti.aspx?t=4`.
- `body.ks-page-account` presente.
- AccountSidebar visibile/usabile.
- Ordini/Documenti active/current con 1 `active` e 1 `aria-current`.
- `.myaccount-nav` assente/non visibile.
- Nessuna doppia sidebar visibile.
- Selector dinamico `sdsTipo` presente e recepito.
- Hardcoding esclusivo `t=4/2/1` assente.
- Tipi documento visibili da datasource:
  - Preventivo
  - Ordine
  - D.D.T.
  - Fattura Immediata
  - Fattura Differita
  - Nota di Credito
- Tipi extra non esclusi.
- `t=4`, `t=2`, `t=1` verificati solo lista/read-only.
- `t=18` verificato con redirect sicuro a `t=4`, nessun errore.
- Lista documenti/stato vuoto OK.
- Azione Dettaglio presente dove ci sono righe, ma nessun dettaglio aperto.
- Pay Now/gateway diretto assente.
- Mobile `390x844` OK.
- Nessun overflow orizzontale grave.
- Nessun errore ASP.NET/MySQL/Object reference/500.
- Nessun PayPal, BancaSella, gateway, carrello, checkout o ordine invocato.
- Password non modificata.
- Dati utente non modificati.
- Dati sensibili non esposti.

Regola UX confermata:

- la lista ordini mostra lo stato pagamento senza obbligare l'utente ad aprire dettagli tecnici;
- il retry pagamento resta nel dettaglio ordine;
- stato ordine e stato pagamento restano concetti separati.

## 8. Stato Account Dashboard / myaccount.aspx

ACCOUNT-DASHBOARD-1 e chiuso.

Esiti principali:

- ACCOUNT-DASHBOARD-1A audit ONSUS `my-account.html`: B, pronto con note.
- ACCOUNT-DASHBOARD-1B refactor dashboard ONSUS: completato.
- PR #98 merge commit: `12f4fd5ec2dff6c15ee7479e854628bd71dc9ed5`.
- Smoke ACCOUNT-DASHBOARD-1B-D: A.
- Cleanup branch ACCOUNT-DASHBOARD-1: completato.

Comportamento finale `myaccount.aspx`:

- layout ONSUS account/dashboard;
- sidebar account coerente con l'area account;
- hero/saluto con fallback sicuro;
- card Profilo con dati essenziali;
- card Indirizzi con indirizzo principale o fallback;
- card Ordini recenti, massimo 5 righe;
- ordini recenti con Stato ordine e Stato pagamento visibili;
- link `Dettaglio` verso `documentidettaglio.aspx?id=<id>`;
- link `Vedi tutti gli ordini` verso `documenti.aspx?t=4`;
- nessun Pay Now diretto;
- nessun link PayPal/BancaSella/gateway diretto;
- mobile `390x844`: OK;
- nessun errore server, MySql, Object reference o BC30002 nello smoke.

Stato area account stabilizzata per funzionalita principali:

- `documentidettaglio.aspx`: stabile con layout ONSUS e stato pagamento separato;
- `documenti.aspx`: stabile con layout ONSUS, AccountSidebar globale, selector documenti dinamico, filtri GET validati e azione solo Dettaglio;
- `myaccount.aspx`: stabile con dashboard ONSUS, profilo, indirizzi e ordini recenti;
- `my-account-edit.aspx`: stabile con profilo ONSUS, salvataggio campi contatto validato e AccountSidebar condivisa coerente.
- `wishlist.aspx`: stabile con AccountSidebar globale e nav inline legacy rimossa/non visibile nella fase 1 cleanup.
- `my-account-address.aspx`: stabile read-only ONSUS, con AccountSidebar globale e gestione indirizzi legacy rimandata.
- `password.aspx`: stabile come pagina canonica cambio password, dentro shell account con AccountSidebar globale.
- `cambiapassword.aspx`: legacy redirect controllato verso `password.aspx`.
- AccountSidebar condivisa validata.
- Cleanup sidebar fase 1 chiuso.
- Cleanup documenti fase 2 chiuso.
- Consolidamento password chiuso con hotfix.

Nota: questa stabilizzazione non equivale al cleanup completo di tutte le nav/sidebar inline legacy presenti nelle pagine account. Quel debito UI resta separato.

## 9. Stato Account Profile / my-account-edit.aspx

ACCOUNT-PROFILE-1B e chiuso.

Esiti principali:

- PR #100 merge commit: `f0eeccc12d701268641dc10950bb1253670f86fa`.
- PR #100 ha introdotto il profilo account ONSUS su `my-account-edit.aspx`.
- PR #101 merge commit: `7bfd40cb685e0500f427cf4a481516f70038d235`.
- PR #101 ha corretto i link root-level della sidebar account.
- PR #102 merge commit: `919b342bd0d0c9ff7b7bddc0453f99e4efe79fbc`.
- PR #102 ha corretto lo stato active/current della sidebar account.
- Smoke finale ACCOUNT-PROFILE-1B-T: A.
- Cleanup branch ACCOUNT-PROFILE-1B: completato.

Comportamento finale area profilo:

- `myaccount.aspx`: dashboard stabile.
- Click `Modifica dati`: porta a `my-account-edit.aspx`.
- `my-account-edit.aspx`: pagina profilo ONSUS visibile e coerente con area account.
- Sezioni presenti: dati accesso/profilo, dati fiscali read-only, contatti, indirizzo fatturazione.
- Username read-only.
- Email con limite coerente a 50 caratteri.
- Campi opzionali `Telefono`, `Cellulare`, `Fax` svuotabili.
- Update `login.Email` ristretto al login corrente.
- Salvataggio, svuotamento e ripristino `Fax` validati.
- Pulsante `Annulla` validato.
- Mobile `390x844`: validato.

Sidebar condivisa AccountSidebar finale:

- Link root-level:
  - `/myaccount.aspx`
  - `/my-account-edit.aspx`
  - `/my-account-address.aspx`
  - `/documenti.aspx`
  - `/wishlist.aspx`
  - `/password.aspx`
  - `/logout.aspx`
- Nessun link `Public/ui/controls/...` nella sidebar condivisa `AccountSidebar`.
- Active/current della sidebar condivisa corretto con una sola voce `active` e un solo `aria-current="page"` per pagina.
- Validato su dashboard, dettagli account, indirizzi, ordini, wishlist e password.
- Non affermare che tutte le sidebar/nav inline legacy dell'area account siano gia state rimosse.

Smoke finale ACCOUNT-PROFILE-1B-T:

- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Nessun errore ASP.NET/MySQL/Object reference/500.
- Nessun gateway/carrello/checkout/ordine invocato.
- Password non modificata.
- Dati sensibili non esposti.

Follow-up password:

- `ACCOUNT-PASSWORD-AUDIT-1A`: chiuso.
- `ACCOUNT-PASSWORD-SECURITY-1B`: chiuso con PR #111.
- `ACCOUNT-PASSWORD-SECURITY-1I`: hotfix chiusa con PR #112.
- Hash/migrazione password non implementati: richiedono audit login/registrazione/reset password separato.

## 10. Stato Account Address / my-account-address.aspx

ACCOUNT-ADDRESS-1B e chiuso.

Esiti principali:

- PR #107 merge commit: `a4381b83ec5c617c6dc75022d30580ded5394f62`.
- Branch task: `task/account-address-1b-onsus-readonly`.
- Cleanup branch completato: branch locale e remoto rimossi.

File modificati da ACCOUNT-ADDRESS-1B:

- `Page.master.vb`
- `my-account-address.aspx`

File non modificati:

- `my-account-address.aspx.vb`
- `datiutente.aspx`
- `datiutente.aspx.vb`
- `datiutente-ui.js`
- `documenti.aspx`
- `password.aspx`
- `cambiapassword.aspx`
- `documentidettaglio.aspx`
- `web.config`
- markup `Page.master`
- DB/schema/dump SQL
- checkout/carrello/gateway/pagamenti
- asset ONSUS originali

Comportamento finale `my-account-address.aspx`:

- layout ONSUS/UX 2026 read-only;
- `Page.master.vb` include `my-account-address.aspx` tra le pagine con `body.ks-page-account`;
- AccountSidebar globale visibile/usabile;
- voce `Indirizzi` active/current corretta;
- nav inline legacy `.myaccount-nav` rimossa/non visibile;
- nessuna doppia sidebar visibile;
- card indirizzo fatturazione presente;
- card contatti/destinazioni presente;
- `EmptyDataTemplate` presente;
- link legacy mantenuti:
  - `datiutente.aspx?edit=1`
  - `datiutente.aspx?edit=1&tab=addr`
- pagina confermata read-only;
- nessun add/edit/delete diretto indirizzi introdotto;
- nessun salvataggio introdotto;
- query/DB/salvataggi invariati.

Smoke finale ACCOUNT-ADDRESS-1B-D:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Login PROVA OK.
- `my-account-address.aspx` desktop OK.
- `body.ks-page-account` presente.
- AccountSidebar visibile/usabile.
- `Indirizzi` active/current.
- `.myaccount-nav` assente/non visibile.
- Nessuna doppia sidebar visibile.
- Card indirizzo e card contatti/destinazioni presenti.
- Link legacy verificati senza salvataggi.
- Mobile `390x844` OK.
- Nessun errore ASP.NET/MySQL/Object reference/500.
- Nessun PayPal, BancaSella, gateway, carrello, checkout o ordine invocato.
- Password non modificata.
- Dati utente non modificati.
- Dati sensibili non esposti.

Debito residuo indirizzi:

- `datiutente.aspx` resta legacy con tab/JS e gestione destinazioni.
- Non e stata migrata la gestione add/edit/delete indirizzi.
- Le destinazioni alternative restano nel pannello legacy.
- Eventuale migrazione della gestione indirizzi richiede audit/task dedicato e autorizzazione Germano.

## 11. Debito UI residuo sidebar inline account

SIDEBAR-DOC-AUDIT-1A ha confermato che la nota Codex post DOCS-4 era reale/parziale. ACCOUNT-SIDEBAR-INLINE-CLEANUP fase 1 e chiuso, ma il cleanup completo di tutte le nav/sidebar inline legacy account non e ancora concluso.

- `Page.master` renderizza la sidebar condivisa `AccountSidebar` in `ks-account-aside`.
- `AccountSidebar` condivisa e corretta e validata:
  - link root-level OK;
  - active/current dinamico OK;
  - target password attuale: `/password.aspx`;
  - mapping legacy presente per `datiutente.aspx`, `documentidettaglio.aspx` e `cambiapassword.aspx`.
- Diverse pagine account contengono ancora nav/sidebar inline legacy nel `MainContent`, in particolare strutture tipo `myaccount-nav`.
- Alcune nav inline hanno `active` hardcoded.
- Alcune pagine contengono ancora link legacy verso `datiutente.aspx`.
- Impatto funzionale attuale: medio, non bloccante sul profilo, ma da non ignorare prima dei prossimi refactor account.

### Fase 1 cleanup sidebar inline account chiusa

ACCOUNT-SIDEBAR-INLINE-CLEANUP fase 1 e chiuso.

Esiti principali:

- PR #105 merge commit: `fbafc68ca36b2ba19a9d16d50af05313e3824209`.
- Branch task: `task/account-sidebar-inline-cleanup-1b-simple-pages`.
- Cleanup branch completato: branch locale e remoto rimossi.

Perimetro chiuso in fase 1:

- `Page.master.vb` abilita `body.ks-page-account` solo sulle tre pagine fase 1:
  - `myaccount.aspx`
  - `my-account-edit.aspx`
  - `wishlist.aspx`
- `AccountSidebar` globale ora e visibile/usabile sulle tre pagine.
- Nav inline legacy rimossa/non visibile su:
  - `myaccount.aspx`
  - `my-account-edit.aspx`
  - `wishlist.aspx`
- Active/current corretto sulle tre pagine.
- Nessuna doppia sidebar visibile.
- Layout desktop e mobile validato.

Smoke finale ACCOUNT-SIDEBAR-INLINE-CLEANUP-1F:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Desktop OK su `myaccount.aspx`, `my-account-edit.aspx`, `wishlist.aspx`.
- Mobile `390x844` OK sulle stesse tre pagine.
- Nessun errore ASP.NET/MySQL/Object reference/500.
- Nessun gateway/carrello/checkout/ordine invocato.
- Password non modificata.
- Dati profilo non modificati.
- Dati sensibili non esposti.

Pagine escluse dalla fase 1:

- `documenti.aspx`
- `password.aspx`
- `datiutente.aspx`
- `cambiapassword.aspx`
- `documentidettaglio.aspx`

### Fase 2 cleanup documenti chiusa

ACCOUNT-SIDEBAR-INLINE-CLEANUP-2B su `documenti.aspx` e chiuso.

Esiti principali:

- PR #109 merge commit: `7fe10f0edfbc7b7d5951116697c6654a100ba60f`.
- Branch task: `task/account-sidebar-inline-cleanup-2b-documenti`.
- Cleanup branch completato: branch locale e remoto rimossi.

Perimetro chiuso in fase 2:

- `Page.master.vb` abilita `body.ks-page-account` anche su `documenti.aspx`.
- AccountSidebar globale visibile/usabile su `documenti.aspx`.
- Voce Ordini/Documenti active/current corretta.
- Nav inline legacy `.myaccount-nav` rimossa/non visibile.
- Nessuna doppia sidebar visibile.
- Selector dinamico `sdsTipo` mantenuto/ripristinato.
- `asp:Repeater rTipo` mantenuto con `DataSourceID="sdsTipo"`.
- `LinkButton lbTipoDocumento` mantenuto con `tipoDocumento`, `tipoDocumentoClick` e `preRenderClick`.
- Hardcoding esclusivo `t=4/2/1` eliminato.
- Tipi documento extra non esclusi.
- Lista documenti invariata.
- Azione Dettaglio invariata.
- Nessun Pay Now/gateway diretto introdotto.
- `documenti.aspx.vb` invariato.

Smoke finale ACCOUNT-SIDEBAR-INLINE-CLEANUP-2H:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Desktop e mobile `390x844` OK.
- `t=4`, `t=2`, `t=1` verificati solo lista/read-only.
- `t=18` verificato con redirect sicuro a `t=4`, nessun errore.
- Tipi documento visibili da datasource: Preventivo, Ordine, D.D.T., Fattura Immediata, Fattura Differita, Nota di Credito.
- Nessun dettaglio ordine aperto.
- Nessun PayPal, BancaSella, gateway, carrello, checkout o ordine invocato.
- Password e dati utente non modificati.
- Dati sensibili non esposti.

### Consolidamento password account chiuso

ACCOUNT-PASSWORD-SECURITY-1B e chiuso. ACCOUNT-PASSWORD-SECURITY-1I hotfix e chiuso.

Esiti principali:

- PR #111 merge commit: `90c13d3bb41ff8d437f3cc9605a736659b04f4ce`.
- Branch task PR #111: `task/account-password-security-1b-canonical-flow`.
- Cleanup branch PR #111 completato: branch locale e remoto rimossi.
- PR #112 merge commit: `3d1873f5e3ea071ef187cc906f5d8712a58a09e6`.
- Branch task PR #112: `task/account-password-security-1i-confirm-hotfix`.
- Cleanup branch PR #112 completato: branch locale e remoto rimossi.

File modificati da ACCOUNT-PASSWORD-SECURITY-1B / PR #111:

- `Page.master.vb`
- `password.aspx`
- `password.aspx.vb`
- `cambiapassword.aspx`
- `cambiapassword.aspx.vb`
- `datiutente.aspx`

File modificati da ACCOUNT-PASSWORD-SECURITY-1I / PR #112:

- `password.aspx.vb`

File non modificati:

- `datiutente.aspx.vb`
- `datiutente-ui.js`
- `login.aspx`
- registrazione/reset password
- `web.config`
- markup `Page.master`
- DB/schema/dump SQL
- checkout/carrello/gateway/pagamenti
- pagine account stabilizzate non previste
- asset ONSUS originali

Comportamento finale password:

- `password.aspx` e la pagina canonica per cambio password account.
- `cambiapassword.aspx` e legacy redirect controllato verso `password.aspx`.
- I link "Cambia password" in `datiutente.aspx` puntano a `password.aspx`.
- Il redirect scadenza password in `Page.master.vb` punta a `password.aspx`.
- `password.aspx` e dentro la shell account con `body.ks-page-account`.
- AccountSidebar globale visibile/usabile su `password.aspx`.
- Voce Cambia password active/current corretta.
- Nav inline legacy `.myaccount-nav` rimossa/non visibile.
- Nessuna doppia sidebar visibile.
- Diagnostica tecnica legacy rimossa/disabilitata.
- Nessun `ex.Message`, stack, path, identity o dettaglio tecnico a schermo.
- Confronto vecchia password case-sensitive.
- Policy server-side:
  - minimo 8 caratteri;
  - massimo 25 caratteri;
  - conferma obbligatoria;
  - nuova password diversa dalla vecchia.
- Query parametrizzate.
- `DataPassword` aggiornata solo su cambio password valido e riuscito.
- Hash implementato: no.
- DB schema modificato: no.
- Login/registrazione/reset password non modificati.

Hotfix ACCOUNT-PASSWORD-SECURITY-1I:

- Smoke post-merge PR #111 aveva dato E sul caso conferma non coincidente.
- Problema rilevato: conferma non coincidente aggiornava la password.
- Hotfix PR #112 circoscritta a `password.aspx.vb`.
- Update DB centralizzato dopo validazioni.
- Conferma non coincidente gestita server-side.
- Guard SQL con confronto case-sensitive: `BINARY @newpwd = BINARY @confirmpwd`.
- Nessun update `Password` se:
  - vecchia password errata;
  - nuova password troppo corta;
  - conferma non coincidente;
  - nuova uguale alla vecchia.
- Nessun update `DataPassword` nei casi falliti.
- `DataPassword` aggiornata solo su successo.
- Diagnostica tecnica assente.
- Hash non implementato.
- DB schema non modificato.

Smoke finale ACCOUNT-PASSWORD-SECURITY-1L:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Login iniziale PROVA OK.
- `password.aspx` loggato OK.
- `body.ks-page-account` presente.
- AccountSidebar visibile/usabile.
- Cambia password active/current.
- `.myaccount-nav` assente/non visibile.
- Nessuna doppia sidebar visibile.
- Negativo A, vecchia password errata: OK, nessun update inatteso.
- Negativo B, nuova password troppo corta: OK.
- Negativo C, conferma non coincidente: OK.
- Negativo D, nuova uguale alla vecchia: OK.
- Test positivo controllato: OK.
- Login finale PROVA riuscito.
- Password finale in stato noto conforme.
- Redirect loop assente.
- `cambiapassword.aspx` redirect controllato confermato.
- `datiutente.aspx`: errore generico legacy/preesistente, nessun salvataggio.
- Nessun errore server/browser bloccante.
- Nessun PayPal, BancaSella, gateway, carrello, checkout o ordine invocato.
- Nessun dettaglio ordine aperto.
- Dati profilo/indirizzi non modificati.
- Dati sensibili non esposti.

## 12. Stato Login / Registrazione / Reminder

LOGIN-REGISTER-SECURITY-1 e chiuso lato codice.

Esiti principali:

- PR #117 merged.
- Merge commit PR #117: `f51ab9a4df9afb71760a31db97ed0eac547cd9c3`.
- Branch task: `task/login-register-security-1b-no-schema`.
- Cleanup branch LOGIN-REGISTER-SECURITY-1I completato: branch locale e remoto rimossi.
- Smoke post-merge LOGIN-REGISTER-SECURITY-1H: A.

File modificati da PR #117:

- `Page.master.vb`
- `login.aspx.vb`
- `registrazione.aspx`
- `registrazione.aspx.vb`
- `registrazioneok.aspx`
- `remind.aspx`
- `remind.aspx.vb`

File esclusi/non modificati:

- `password.aspx`
- `password.aspx.vb`
- `cambiapassword.aspx`
- `cambiapassword.aspx.vb`
- `datiutente.aspx`
- `datiutente.aspx.vb`
- `web.config`
- markup `Page.master`
- DB/schema/dump SQL
- gateway/pagamenti
- carrello/checkout/ordini
- asset ONSUS originali

Mitigazioni applicate:

- Login enumeration ridotta con messaggio generico unico.
- Reminder trasformato prima in recupero assistito e poi in reset tokenizzato fase 1.
- Reminder non promette azioni non eseguite.
- Reminder non invia password esistente.
- Reminder non invia email reale.
- Reminder non fa enumeration.
- Registrazione non invia password in email.
- Password in URL rimossa/neutralizzata.
- Password in sessione rimossa/neutralizzata.
- Policy registrazione allineata a 8-25.
- Lowercase forzato password rimosso.
- Diagnostica tecnica rimossa.
- Hash implementato: no.
- DB schema modificato: no.
- `password.aspx` invariata/stabile.

Smoke post-merge LOGIN-REGISTER-SECURITY-1H:

- Ambiente: `https://www.taikun.it/`.
- Utente test PROVA: login OK, senza password nei report.
- Login negativo con messaggio generico OK.
- Reminder assistito OK.
- Submit reminder sicuro con dato fittizio.
- Registrazione read-only OK.
- `registrazioneok.aspx` OK, nessun `passw=`.
- `password.aspx` invariata/stabile.
- Nessuna password in URL/email/UI.
- Nessuna diagnostica tecnica.
- Nessun errore ASP.NET/MySQL/Object reference/500.
- Restano due errori JS legacy/preesistenti su `remind.aspx` e `registrazione.aspx`, non bloccanti.
- Nessun gateway/carrello/checkout/ordine invocato.
- Nessuna password modificata.
- Nessun utente creato.
- Nessuna email reale inviata.
- Nessun dato sensibile esposto.

Stato finale area sicurezza/login:

- Cambio password canonico gia stabile su `password.aspx`.
- Login/registrazione/reminder ora mitigati senza hash.
- Reminder automatico password disabilitato e sostituito dal reset tokenizzato fase 1 legacy-compatible.
- Registrazione non espone password in email/URL/sessione.
- Hash migration ancora non implementata.
- Reset tokenizzato fase 1 operativo; hash migration rimandata a task futuro.

### Reset tokenizzato - progettazione DB chiusa

REMIND-RESET-DB-REVIEW-1 e chiuso a livello documentale/progettuale.

Esiti principali:

- PR #121 merged e chiusa.
- Merge commit PR #121: `f11cf0b434b9be111d470b995083edf9d18b481b`.
- Branch task PR #121: `task/remind-reset-db-review-1g-germano-feedback`.
- Cleanup branch PR #121 completato con esito A: branch locale e remoto rimossi.

File aggiornati da PR #121:

- `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md`
- `docs/REMIND_RESET_DB_MANUALE_VINCENZO.md`

Stato finale PR #121:

- Manuale Vincenzo aggiornato solo a livello progettuale.
- Blueprint aggiornato solo a livello progettuale.
- Feedback Germano integrato su gestionale, tabella `login`, `login.Password`, `login.DataPassword`, `aziende.ScadenzaPassword`, relazione `login.DataPassword + aziende.ScadenzaPassword`, strategia legacy-compatible, rollout multi-azienda e futura UI JANUS token reset.
- Nessun codice runtime modificato.
- Nessun DB modificato.
- Nessuna tabella `login_password_reset_tokens` creata.
- Nessuno script SQL eseguito.
- Nessun reset tokenizzato implementato.
- Nessun hash implementato.
- Nessun dato sensibile esposto.

Prossimo step consigliato:

- Preparare uno script DB idempotente e controllato per `login_password_reset_tokens`, senza eseguirlo, da verificare con Vincenzo prima di qualunque modifica DB.

### Reset tokenizzato - script DB preparato

REMIND-RESET-DB-SCRIPT-1A e avviato/preparato a livello documentale.

Esito previsto del task:

- Script SQL creato in `docs/db/login_password_reset_tokens.mysql.sql`.
- Script pensato per revisione Vincenzo ed esecuzione controllata sui singoli DB cliente/azienda.
- Script non eseguito.
- DB non modificato.
- Nessuna tabella `login_password_reset_tokens` creata da Codex.
- Nessuna modifica runtime login/registrazione/reminder/password.
- Nessuna modifica a `connessioni` o `city_registry`.

Prossimo step:

- Review/approvazione dello script SQL con Germano/Vincenzo prima di qualunque esecuzione DB o implementazione runtime.

### Reset tokenizzato - handoff Vincenzo preparato

REMIND-RESET-DB-HANDOFF-1A prepara la consegna operativa dello script DB a Vincenzo.

Stato:

- Manuale Vincenzo aggiornato con appendice operativa per `docs/db/login_password_reset_tokens.mysql.sql`.
- Script SQL gia versionato e non modificato da questo handoff.
- Script SQL non eseguito.
- DB non modificato.
- Nessuna tabella `login_password_reset_tokens` creata da Codex.
- Nessuna modifica runtime login/registrazione/reminder/password.
- Nessuna modifica a `connessioni` o `city_registry`.

Gate successivo:

- Germano approva la consegna operativa.
- Vincenzo approva ed eventualmente esegue lo script sul DB cliente/azienda corretto, dopo backup e verifica tecnica.
- Solo dopo conferma creazione tabella e verifica post-esecuzione si puo aprire il task runtime reset tokenizzato fase 1.

### Reset tokenizzato - gate DB taikun completato

REMIND-RESET-DB-GATE-1A registra l'esito comunicato da Germano per l'esecuzione manuale controllata su SQLyog Ultimate 64.

Esito DB `taikun`:

- Backup confermato.
- Tabella `login_password_reset_tokens` creata manualmente.
- `SHOW TABLES` OK.
- `SHOW CREATE TABLE` coerente.
- `COUNT(*) = 0` subito dopo la creazione.
- Nessuna anomalia comunicata.
- Nessun dato/token reale inserito.
- Runtime reset tokenizzato non era ancora implementato al momento del gate DB; fase 1 completata successivamente.
- Codex non ha eseguito SQL e non ha modificato DB.

Step successivo completato:

- Implementazione runtime reset tokenizzato fase 1 completata e mergiata, senza hash e mantenendo i guardrail legacy gia documentati.

### Reset tokenizzato - runtime fase 1 avviato

REMIND-RESET-IMPLEMENT-1E ha avviato e chiuso l'implementazione runtime legacy-compatible su branch dedicato.

Stato finale:

- DB `taikun` gia predisposto con tabella `login_password_reset_tokens`.
- Reminder convertito a richiesta reset tokenizzata anti-enumeration.
- Nuova pagina reset password anonima con token monouso e scadenza 30 minuti.
- Reset riuscito aggiorna `login.Password` legacy e `login.DataPassword`.
- Hash password rimandato a task separato.
- Smoke runtime e smoke live finale Germano superati.

### Reset tokenizzato - disambiguazione account

REMIND-RESET-IMPLEMENT-1I aggiorna il runtime PR #126 per rendere deterministico il reset in presenza di email duplicate.

- `remind.aspx` richiede email e Codice fiscale o Partita IVA.
- Il runtime usa email, CF/PIVA normalizzato e contesto URL/AziendaId quando determinabile.
- Il campo CF/PIVA e alternativo: il valore inserito puo corrispondere a `CodiceFiscale` oppure a `Piva`, senza richiedere entrambi.
- La ricerca viene de-duplicata per `LoginId`: piu righe `vlogin` dello stesso account contano come un solo candidato.
- Se la ricerca produce zero candidati non viene generato alcun token.
- Se la ricerca produce un solo candidato valido viene generato un solo token.
- Se la ricerca resta ambigua con candidati multipli distinti per `LoginId` non viene generato alcun token.
- Nessuna scelta arbitraria del primo record e nessuna email con link multipli.
- Nessun dato fiscale, azienda o tipo utente viene salvato nel token, inserito nel link o scritto nei log.
- Nessun DB schema modificato; PR #126 mergiata e smoke finale superato.

### Reset tokenizzato - UX reset password

REMIND-RESET-UX-1A aggiorna `resetpassword.aspx` sul ramo PR #126.

- Aggiunto toggle mostra/nascondi password sui campi nuova password e conferma nuova password.
- I campi restano mascherati di default.
- Il toggle e client-side, accessibile da tastiera e non invia submit accidentali.
- Nessuna password viene salvata in JavaScript globale, storage, cookie o log.
- Nessun DB/schema modificato e nessuna logica token/password server-side modificata.

### Reset tokenizzato - refresh sicuro remind

REMIND-RESET-POST-REFRESH-1A corregge `remind.aspx` con pattern POST/Redirect/GET.

- Dopo una richiesta reset processata, la pagina redirige a `remind.aspx?sent=1`.
- Il messaggio post-redirect resta generico e anti-enumeration.
- Refresh/F5 ricarica solo la GET e non reinvia il POST.
- Nessun dato email, fiscale o token viene salvato in querystring.
- Nessun DB/schema modificato e nessuna logica token/password server-side modificata.

REMIND-RESET-POST-REFRESH-1C rafforza il comportamento live di `remind.aspx` e migliora la qualita della comunicazione email reset.

- Il redirect post-submit usa una risposta 303 verso `remind.aspx?sent=1`, con `CompleteRequest()` e uscita immediata dal click handler.
- `sent=1` e gestito come GET di conferma generica e non genera token/email, anche in caso di POST artificiale verso la stessa querystring.
- Il template email reset e HTML professionale con versione testuale alternativa, CTA, fallback link, nota sicurezza e footer aziendale.
- Le avvertenze anti-phishing esplicite sono presenti in HTML e plain text: non condividere il link, nessuna richiesta password via email, nessuna password inclusa nella mail.
- I dati azienda per mittente/footer vengono letti dalla tabella reale `aziende` quando associabili all'account, con fallback alle sessioni legacy.
- Il token in chiaro resta solo nel link email; nessun token, hash, password, CF/PIVA o dato personale viene inserito nei log o nei documenti.
- Nessun DB/schema modificato e nessun hash implementato.

RESET-LOGIN-REDIRECT-1A corregge il redirect post-login dopo reset password.

- `resetpassword.aspx`, `remind.aspx` e URL contenenti token/reset/remind non sono destinazioni valide per `ReturnUrl` o `Pagina_visitata`.
- I redirect post-login accettano solo URL relative interne sicure e rifiutano URL assolute esterne.
- Se la destinazione non e sicura, il fallback post-login e `myaccount.aspx`.
- La master non salva piu pagine reset/remind come ultima pagina visitata e pulisce sessioni di redirect legacy non sicure.
- Nessun DB/schema modificato e nessun hash implementato.

### Reset tokenizzato - fase 1 chiusa

REMIND-RESET-FINAL-CLOSE-1A registra la chiusura funzionale del blocco reset password tokenizzato fase 1.

PR completate:

- PR #126 merged: implementazione reset password tokenizzato fase 1 legacy-compatible.
- PR #127 merged: primo hotfix POST/Redirect/GET su `remind.aspx`.
- PR #128 merged: PRG definitivo e email reset professionale con riferimenti aziendali e avvertenze anti-phishing.
- PR #130 merged: fix redirect post-login dopo reset.

Smoke live finale Germano:

- Reset password via link email OK.
- Cambio password OK.
- Login con nuova password OK.
- Redirect post-login verso pagina sicura OK.
- Nessun ritorno a `resetpassword.aspx`.
- URL finale senza token.
- PRG/F5 `remind.aspx` OK.
- Email reset professionale OK, con riferimenti aziendali e avvertenze anti-phishing.
- Nessuna anomalia comunicata.

Comportamento finale fase 1:

- Reset tokenizzato operativo e legacy-compatible.
- `remind.aspx` richiede email e Codice fiscale oppure Partita IVA.
- CF/PIVA sono alternativi, non cumulativi.
- La ricerca de-duplica per `LoginId`.
- Zero candidati o candidati multipli distinti: nessun token generato.
- Un candidato valido: un solo token generato.
- Token single-use con scadenza 30 minuti.
- Il DB salva solo `TokenHash`; il token chiaro resta solo nel link email.
- Reset riuscito aggiorna `login.Password` legacy e `login.DataPassword`.
- `aziende.ScadenzaPassword` invariato.
- `resetpassword.aspx` include toggle mostra/nascondi password client-side.
- `remind.aspx` usa PRG/F5 sicuro.
- Redirect post-login sanificato: `resetpassword.aspx`, `remind.aspx` e URL con token/reset/remind sono esclusi da `ReturnUrl` e redirect sessione.
- Fallback sicuro post-login: `myaccount.aspx`.
- Hash password non implementato; rimandato a task futuro.

### Debito residuo dopo consolidamento password

- Hash/migrazione password non implementati.
- Audit hash/login/registrazione/reset password da fare in task separato.
- Password legacy ancora in chiaro nel DB.
- Login usa ancora meccanismo legacy, non hash.
- Reminder fase 1 ora tokenizzato e legacy-compatible; hash migration non implementata.
- Tabella `login_password_reset_tokens` creata manualmente su DB `taikun`; rollout su eventuali altri DB cliente/azienda ancora da gestire separatamente.
- Script DB idempotente per `login_password_reset_tokens` preparato a livello repository e gia eseguito manualmente su `taikun` da Germano/Vincenzo, non da Codex.
- Registrazione va ulteriormente modernizzata lato UX e sicurezza.
- `AntiCsrfPage` non ancora applicato ai flussi auth.
- Hash/salt/versione algoritmo non presenti.
- Serve coordinamento con Vincenzo/gestionale prima di modifiche DB.
- Warning legacy di precompile in `remind.aspx.vb` da valutare in task separato non urgente.
- Errori JS legacy su `registrazione.aspx` da valutare in task separato.
- `datiutente.aspx` resta legacy con errore generico preesistente, tab/JS e gestione salvataggi/destinazioni.
- `my-account-address.aspx` e stabile read-only ONSUS dopo ACCOUNT-ADDRESS-1B, ma la gestione add/edit/delete indirizzi resta legacy in `datiutente.aspx`.
- La gestione add/edit/delete indirizzi non e stata migrata.
- Il cleanup completo sidebar/nav inline legacy account non e ancora concluso per `datiutente.aspx`.
- `ACCOUNT-PROFILE-1B` resta chiuso.
- `ACCOUNT-SIDEBAR-INLINE-CLEANUP fase 1` resta chiuso.
- `ACCOUNT-SIDEBAR-INLINE-CLEANUP fase 2 documenti` resta chiuso.
- `ACCOUNT-ADDRESS-1B` resta chiuso.
- `ACCOUNT-PASSWORD-SECURITY-1B` resta chiuso.
- `ACCOUNT-PASSWORD-SECURITY-1I` resta chiuso.
- `LOGIN-REGISTER-SECURITY-1` resta chiuso.

Task consigliato separato per eventuale proseguimento:

- `ACCOUNT-SIDEBAR-INLINE-CLEANUP-3A`: eventuale audit/cleanup delle sidebar inline legacy residue solo dopo audit datiutente, nella pagina:
  - `datiutente.aspx`
- Obiettivo: decidere con Germano se rimuovere, nascondere o riallineare le nav inline legacy, mantenendo `AccountSidebar` condivisa come fonte di navigazione account.
- Vincolo: non modificare dati utente o salvataggi legacy senza autorizzazione Germano.

## 13. Prossimi step consigliati

### Immediati

1. Revocare/cambiare la password dell'utente MySQL temporaneo usato nello smoke, se ancora attivo.
2. Eliminare eventuali variabili ambiente temporanee di smoke.
3. Eliminare o lasciare scadere eventuali link reset test residui.
4. PASSWORD-HASH-SCHEMA-2B / PASSWORD-HASH-MIGRATION-2C: futuro task hash password.
5. GESTIONALE-PASSWORD-AUDIT-1A / JANUS-PASSWORD-RESET-1A: futuro task gestionale Janus per reset/hash.
6. REMIND-RESET-WARNINGS-CLEANUP-1A: eventuale cleanup warning legacy `remind.aspx.vb`, task separato non urgente.
7. REGISTRATION-POLICY-1A o REGISTRATION-UX-1A: modernizzazione registrazione.
8. AUTH-CSRF-AUDIT-1A: audit `AntiCsrfPage` sui flussi auth.
9. AUTH-JS-LEGACY-AUDIT-1A: audit errori JS legacy residui.
10. ACCOUNT-ADDRESS-2A solo se Germano autorizza audit/migrazione della gestione indirizzi legacy.
11. DATIUTENTE-LEGACY-AUDIT-1A per errore generico, tab/JS legacy e salvataggi/destinazioni.
10. ACCOUNT-SIDEBAR-INLINE-CLEANUP-3A solo dopo audit datiutente.
11. Decidere prossimo task PayPal:
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

1. REGISTRATION-UX-1A: modernizzazione registrazione, se Germano la prioritizza.
2. ACCOUNT-ADDRESS-2A solo se Germano autorizza audit/migrazione della gestione indirizzi legacy.
3. DATIUTENTE-LEGACY-AUDIT-1A: errore generico preesistente, tab/JS legacy, salvataggi e destinazioni.
4. ACCOUNT-SIDEBAR-INLINE-CLEANUP-3A solo dopo audit datiutente.
5. Proseguire altra pagina account secondo priorita Germano.
6. Per ogni refactor UI:
   - audit ONSUS prima;
   - micro-task implementativo dopo;
   - smoke desktop/mobile;
   - nessuna patch sul vecchio layout quando si cambia impostazione grafica.

## 14. Guardrail permanenti

- Non toccare `main` senza task esplicito.
- Non creare PR verso `main`.
- Non modificare DB/dump SQL senza backup e task DB dedicato.
- Non modificare gateway PayPal/BancaSella in task UI.
- Non creare ordini o pagamenti senza autorizzazione esplicita.
- Non chiamare PayPal live senza task dedicato e consenso esplicito.
- Non inserire o stampare secret.
- Non esporre token o transaction id completi in UI/log/report.
- Non confondere stato ordine con stato pagamento.
