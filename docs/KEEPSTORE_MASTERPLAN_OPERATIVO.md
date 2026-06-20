# KeepStore Masterplan Operativo

Aggiornato: 2026-06-09

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

### Metodo Codex Token-Safe / One-Shot

- Prima di dare prompt a Codex, ChatGPT deve consolidare piano, scope, file ammessi, vincoli, verifiche, output e criterio A/B/E.
- Evitare prompt esplorativi quando causa e fix sono gia chiari: un task deve avere un solo prompt operativo principale.
- Revisioni successive sono ammesse per blocchi reali, non per perfezionismo documentale o per inseguire il commit documentale appena creato.
- La documentazione deve registrare PR, branch, commit funzionale principale, stato, smoke e decisioni; i commit documentali successivi restano tracciati da Git/PR e non generano automaticamente nuove REV.
- Cleanup branch e housekeeping sono secondari: usarli solo su richiesta esplicita o se sbloccano il flusso. Prima di cancellare branch verificare sempre che non esistano commit assenti da `frontend-rebuild`.
- Se un problema e solo sospetto o non riproducibile, prima fare test manuale mirato; aprire PR diagnostiche solo se il problema torna riproducibile.
- ChatGPT decide piano, ordine e priorita; Codex esegue task piccoli, verificabili e con confini rigidi. Evitare task generici tipo "controlla tutto".
- Priorita: bug bloccanti/regressioni utente, smoke, documentazione minima, poi cleanup. Non consumare token su attivita non funzionali mentre ci sono step piu importanti aperti.

### Ripartenza rapida in nuova chat

- In caso di chat satura o bloccata, aprire una nuova chat e scrivere: "Leggi docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md e riparti dall'ultimo HEAD stabile."
- Il file contiene HEAD stabile, ultimo blocco completato, task corrente, PR aperte/chiuse, vincoli di scope e prossimi step.
- Non consumare token ripetendo tutta la storia: leggere questo masterplan, verificare Git e ripartire dal micro-task successivo.
- Mantenere lo stesso metodo Germano/ChatGPT/Codex: micro-task, branch dedicati, PR verso `frontend-rebuild`, merge controllati e cleanup separati.
- Aggiornare questa sezione dopo ogni blocco importante.

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

Stato di riferimento dopo chiusura blocco email `KeepStoreEmailTemplate`:

- Branch stabile: `frontend-rebuild`
- HEAD stabile: `6fff30eb04811e0b16c5434486ee498796bbf0d7`
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
- Merge PR #132: `3c50d87962f7791bd7424be1fa376377889b90f8`
- Merge PR #133: `1e0bea8fdcf6e623d22b74ab481b763bfcad6a52`
- Merge PR #134: `7d7205871f85fb33a7cd74dbfbc790cb8f435718`
- Merge PR #135: `54f7bea85c817e7d2a37ab42db0e2e61428d3f9d`
- Merge PR #136: `6160bd8f1f81eff63e789ea7f5a15c130be8f4ba`
- Merge PR #137: `08d5b197393c5d8786dc6a6e108c83beadff0445`
- Merge PR #138: `86d9abfe5fd2567c6ab586167230c455a6325a87`
- Merge PR #139: `2d9c11d9df99a3973593d6f7e7109f5517d3501c`
- Merge PR #140: `73ac6bdf2f303e3581c539ae6dcfca9d1a64f969`
- Merge PR #141: `f8c75acd94531ceb7e2a1488bddc5eb5e27704da`
- Merge PR #142: `3e3efd58268597b6ea1ce978e00bf673dd14a783`
- Merge PR #143: `ccb41fc019100e38d2ba01840ac293956a7a0260`
- Merge PR #144: `42dc685c3c7b99fe9d19284f477ff9f26fb5ee20`
- Merge PR #145: `1fe259a44e9d9252a9733a4c721b13d933963d46`
- Merge PR #146: `c999ecd5e890b2e11bd05c204f2738492f086b07`
- Merge PR #147: `5c4ec079528c8d0610a85d66ec766d266f1b6c3b`
- Merge PR #148: `7558e7dbd8a3221425d5b9bc432fcf272c45625e`
- Merge PR #149: `05a43e54821af795ce897f50465405a7cae21bea`
- Merge PR #150: `b41cc367366fd0a2cfb470edc9afb259cbde2c71`
- Merge PR #151: `a5e39aa9ff226af1de7604503489d0d34efbe4a8`
- Merge PR #152: `c0896bfe40c40cc88aabd6944e309a738e37156f`
- Merge PR #153: `5a0e2565fa94b3ab8705842c3e10359d381f46e6`
- Merge PR #154: `1b7e77b2a7ef6cb4f6fcd6f490a3e3d3bad6abea`
- Merge PR #155: `6c3724ba36bc146fe7551a0d1f90676403fd4ad7`
- Merge PR #156: `5718df4067cd73a1ce5e9fb958e5d6b74577f0ca`
- Merge PR #157: `6d103d68df9931bc4f44e28b5c89018dfd86dd29`
- Merge PR #158: `19e5ff8ce9cca198c0458aa0bd5ef70fe5a9bf5d`
- Merge PR #159: `a23f2a6153b57048769dd5b2a6153f2d13ced445`
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
- PR #133 chiusura documentale reset password tokenizzato fase 1
- PR #134 cleanup warning legacy `remind.aspx.vb`
- PR #135 chiusura documentale post cleanup warning reset/remind
- PR #136 account profile validation hardening
- PR #137 account smoke hotfix
- PR #138 account smoke hotfix follow-up
- PR #139 account address defaults
- PR #140 account address/login UX polish
- PR #154 audit e-mail transazionali documentale

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
3. Reminder automatico password disabilitato e trasformato in recupero assistito.
4. Registrazione non deve esporre password in email, URL o sessione.
5. Hash migration, reset tokenizzato e audit gestionale restano task separati.

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

Nota hardening ACCOUNT-PROFILE-1A:

- `my-account-edit.aspx` mantiene layout ONSUS e AccountSidebar invariati.
- Validazioni server-side rafforzate su email, contatti e campi indirizzo profilo.
- Messaggi utente non tecnici confermati; nessun `ex.Message` esposto.
- Query parametrizzate confermate.
- Update profilo vincolato a `LoginId` e `UtentiId` della sessione.
- `datiutente.aspx`, `my-account-address.aspx`, DB/schema, password/reset/remind e gateway non toccati.

Nota hotfix ACCOUNT-SMOKE-HOTFIX-1A:

- `datiutente.aspx?edit=1&tab=addr` gestito con binding legacy protetto e messaggi non tecnici.
- Newsletter footer/modal non blocca piu i submit account/password con validazione HTML5 globale.
- `password.aspx` usa messaggi professionali vicino al form e ValidationGroup dedicato.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota hotfix ACCOUNT-SMOKE-HOTFIX-1C:

- `datiutente.aspx?tab=addr` e `datiutente.aspx?edit=1&tab=addr` protetti dal caso `edit` assente in querystring.
- Submit newsletter footer gestito con evento dedicato e messaggi inline senza validazione HTML5 globale.
- Password/account verificati senza regressioni statiche.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-ADDRESS-1A:

- `my-account-address.aspx` diventa la pagina moderna ONSUS per gestione indirizzi account.
- Visualizza indirizzo principale da `utenti` e sedi alternative da `utentiindirizzi`.
- Evidenzia la sede alternativa predefinita e consente di impostarne una nuova.
- Update predefinito vincolato a `UtenteId` della sessione e transazione con massimo un `Predefinito=1` per utente.
- Carrello non modificato: legge gia `utentiindirizzi.Predefinito` e usa fallback/selezione indirizzo esistenti.
- Nessun DB/schema modificato e nessun SQL schema eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-ADDRESS-LOGIN-UX-1A:

- Rifinitura `my-account-address.aspx`: mantiene una sola `AccountSidebar`, rimuove le azioni duplicate in testata e forza wrapping locale dei valori lunghi nelle card indirizzo.
- `RagioneSociale` e `CognomeNome` dell'indirizzo principale sono esposti come campi distinti.
- `RagioneSocialeA` e `NomeA` delle sedi alternative sono esposti entrambi, senza fallback che nasconda uno dei due valori.
- `login.aspx` aggiunge solo il toggle client-side mostra/nascondi password; `login.aspx.vb` e il flusso auth restano invariati.
- Carrello non modificato: selezione manuale indirizzo e link "modifica indirizzo" restano da verificare/correggere in task separato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-ADDRESS-UX-1C:

- `my-account-address.aspx` viene rifinita come pagina moderna definitiva per gestione sedi alternative account.
- Causa menu sdoppiato: la pagina renderizzava una `AccountSidebar` locale mentre `Page.master` renderizza gia la sidebar globale dentro `.ks-account-shell`; la sidebar locale e stata rimossa.
- Causa valori tagliati: layout a colonne/card troppo stretto dentro la shell account e valori lunghi non sempre in campi full-width; la lista sedi alternative passa a card full-width con wrapping locale.
- L'indirizzo principale espone chiaramente `Ragione Sociale/Cognome` e `Nome`.
- Le sedi alternative espongono chiaramente `RagioneSocialeA` come `Ragione Sociale/Cognome` e `NomeA` come `Nome`.
- Il link operativo principale verso `datiutente.aspx?edit=1&tab=addr` viene rimosso dalla pagina moderna.
- Add/edit sedi alternative viene gestito direttamente in `my-account-address.aspx`, con form server-side, query parametrizzate e `UtenteId` risolto dalla sessione.
- Il salvataggio verifica sempre che l'id sede appartenga all'`UtenteId` corrente.
- La scelta `Imposta come predefinito` resta disponibile e preserva al massimo una sede alternativa predefinita per utente.
- Delete indirizzi non implementato in questa fase; da valutare solo con task dedicato.
- `datiutente.aspx` resta legacy e non viene modificata.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL schema eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-ADDRESS-UX-1E:

- Hotfix visuale post smoke live su `my-account-address.aspx`: i valori indirizzo passano da colonne Bootstrap strette a griglie locali elastiche con wrapping esplicito.
- Causa valori ancora tagliati: alcune righe usavano colonne troppo strette dentro la shell account (`col-md-*`/`col-lg-*`) e header flex con badge, quindi i valori lunghi risultavano compressi anche se wrappabili.
- Indirizzo principale: `Ragione Sociale/Cognome` e `Nome` restano etichette distinte e leggibili, con valori non troncati.
- Sedi alternative: `RagioneSocialeA` e `NomeA` restano etichette distinte e leggibili, con card coerenti fra sede predefinita e sedi successive.
- Nessuna modifica funzionale DB: add/edit, messaggi, badge predefinito e cambio predefinito restano invariati.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL schema eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-PROFILE-FISCAL-LABELS-1A:

- Hotfix visuale/testuale su `my-account-edit.aspx`, sezione "Dati fiscali / intestazione".
- Causa anomalia: i valori erano gia associati ai campi corretti (`RagioneSociale` e `CognomeNome`), ma le label "Ragione sociale" e "Nome / Cognome" non erano coerenti con la convenzione account validata.
- La label di `RagioneSociale` diventa `Ragione Sociale / Cognome`.
- La label di `CognomeNome` diventa `Nome`, mantenendo lo schema legacy senza concatenazioni o inversioni.
- PIVA e Codice Fiscale restano invariati e read-only.
- Nessuna modifica a indirizzi, carrello, login/reset/password flow.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-PROFILE-FISCAL-LABELS-1C:

- Hotfix testuale su `my-account-edit.aspx`, sezione "Dati fiscali / intestazione", dopo smoke live PR #143.
- Diagnosi: il valore sotto la label "Nome" arriva dal campo storico `CognomeNome`, popolato da `vlogin.cognomenome`; nella query locale non esiste un campo `Nome` separato.
- La label di `CognomeNome` diventa `Nome e Cognome`, senza split automatici, concatenazioni nuove o inversioni.
- La label `Ragione Sociale / Cognome` resta associata a `RagioneSociale`.
- PIVA e Codice Fiscale restano invariati e read-only.
- Nessuna modifica a indirizzi, carrello, login/reset/password flow.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-PROFILE-NAME-FIELD-1B:

- Rettifica funzionale post diagnosi schema: `utenti.Nome` non esiste nello schema versionato, quindi non viene inventato ne usato.
- Il campo reale per la label `Nome` resta lo storico `CognomeNome`, letto da `utenti.CognomeNome` con fallback compatibile su `vlogin.cognomenome`.
- `RagioneSociale` resta il campo per la label `Ragione Sociale / Cognome`.
- `my-account-edit.aspx` riallinea la label fiscale a `Nome`, lasciando PIVA e Codice Fiscale invariati e read-only.
- `myaccount.aspx` separa nel riquadro `Profilo` `Ragione Sociale / Cognome` e `Nome`, senza fallback che fonda i due valori.
- Nessuno split automatico, nessuna concatenazione nuova e nessuna inversione dei campi legacy.
- Nessuna modifica a DB/schema, nessun SQL di modifica, nessuna modifica indirizzi/carrello/login/reset/password.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun percorso legacy immagini introdotto.

Chiusura blocco ACCOUNT-PROFILE-ADDRESS-CLOSE-1A:

- Blocco account profilo/indirizzi chiuso dopo PR #136, #137, #138, #139, #140, #141, #142, #143, #144 e #145.
- Smoke live finale Germano su ACCOUNT-PROFILE-NAME-FIELD: login OK; `my-account-edit.aspx` OK; sezione "Dati fiscali / intestazione" OK; `Ragione Sociale / Cognome` da `RagioneSociale` OK; `Nome` da `CognomeNome` OK; PIVA/CF invariati e read-only OK; salvataggio profilo campo non critico OK; `myaccount.aspx` OK; riquadro `Profilo` con `Ragione Sociale / Cognome` e `Nome` OK; `my-account-address.aspx` senza regressioni visive; anomalie: no.
- `myaccount.aspx`: dashboard account stabile, quick links coerenti, sezione `Profilo` allineata con `RagioneSociale` e `CognomeNome` separati.
- `my-account-edit.aspx`: dettagli account stabili, validazioni server-side profilo consolidate, PIVA/CF read-only invariati, salvataggio profilo campo non critico verificato live.
- `my-account-address.aspx`: pagina moderna autonoma per indirizzi; indirizzo principale e sedi alternative visibili; add/edit sede alternativa funzionanti; scelta predefinito funzionante; reload mantiene il predefinito; massimo un predefinito; valori non tagliati; label `Ragione Sociale/Cognome` e `Nome` coerenti.
- `datiutente.aspx`: non e piu il percorso operativo principale per gestione indirizzi account, resta legacy/compatibilita e non crasha sui percorsi verificati.
- `login.aspx`: toggle mostra/nascondi password verificato, backend login non modificato.
- Newsletter/footer/password: fix precedenti non regrediti, password/account non bloccati dalla newsletter.
- Nessuna modifica DB/schema, nessun SQL eseguito, nessuna tabella creata.
- Nessun percorso legacy `Public/Images/` introdotto; per nuovi asset resta la regola `/Public/assets/images/...`.
- Prossimo blocco operativo: `CART-ADDRESS-SELECTION-1A`.

Comportamento finale area profilo:

- `myaccount.aspx`: dashboard stabile con riquadro `Profilo` separato tra `Ragione Sociale / Cognome` da `RagioneSociale` e `Nome` da `CognomeNome`.
- Click `Modifica dati`: porta a `my-account-edit.aspx`.
- `my-account-edit.aspx`: pagina profilo ONSUS visibile e coerente con area account.
- Sezioni presenti: dati accesso/profilo, dati fiscali read-only, contatti, indirizzo fatturazione.
- Sezione "Dati fiscali / intestazione": `Ragione Sociale / Cognome` da `RagioneSociale`, `Nome` da `CognomeNome`.
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

- layout ONSUS/UX 2026 moderno e autonomo;
- `Page.master.vb` include `my-account-address.aspx` tra le pagine con `body.ks-page-account`;
- AccountSidebar globale visibile/usabile;
- voce `Indirizzi` active/current corretta;
- nav inline legacy `.myaccount-nav` rimossa/non visibile;
- nessuna doppia sidebar visibile;
- card indirizzo fatturazione presente;
- card contatti/destinazioni presente;
- sedi alternative visibili;
- add indirizzo funzionante;
- edit indirizzo funzionante;
- scelta predefinito funzionante;
- reload mantiene il predefinito;
- massimo un predefinito;
- valori non tagliati;
- label `Ragione Sociale/Cognome` e `Nome` coerenti;
- `datiutente.aspx` resta legacy/compatibilita, non percorso operativo principale per indirizzi account;
- delete indirizzi non implementato in questa fase, da valutare solo con task dedicato;
- nessuna modifica DB/schema e nessun SQL eseguito.

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
- Reminder trasformato in recupero assistito.
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
- Reminder automatico password disabilitato e sostituito dal reset tokenizzato fase 1.
- Registrazione non espone password in email/URL/sessione.
- Hash migration ancora non implementata.
- Reset tokenizzato fase 1 operativo e validato live.

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

Prossimo step:

- Implementazione runtime reset tokenizzato fase 1 su branch dedicato, senza hash e mantenendo i guardrail legacy gia documentati.

### Reset tokenizzato - runtime fase 1 avviato

REMIND-RESET-IMPLEMENT-1E avvia l'implementazione runtime legacy-compatible su branch dedicato.

Stato previsto:

- DB `taikun` gia predisposto con tabella `login_password_reset_tokens`.
- Reminder convertito a richiesta reset tokenizzata anti-enumeration.
- Nuova pagina reset password anonima con token monouso e scadenza 30 minuti.
- Reset riuscito aggiorna `login.Password` legacy e `login.DataPassword`.
- Hash password rimandato a task separato.
- Smoke runtime richiesti prima di merge.

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
- Nessun DB schema modificato; PR #126 resta da smoke finale.

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

REMIND-RESET-SENT-UX-1B migliora lo stato di conferma `remind.aspx?sent=1`.

- La GET `sent=1` mostra una card di conferma evidente in alto, subito sotto il titolo `Recupero accesso`.
- Il form email + CF/PIVA viene nascosto nello stato di conferma e i campi vengono puliti server-side.
- Loader, testi operativi e immagini loader non vengono renderizzati su GET normale o `sent=1`.
- Le azioni disponibili sono `Vai al login` e `Effettua una nuova richiesta`, con nuova richiesta verso `remind.aspx` pulito.
- Il messaggio resta generico e anti-enumeration.
- PRG/F5 invariato: la GET `sent=1` non genera token/email.
- Nessun DB/schema modificato.

### Reset tokenizzato - fase 1 chiusa

REMIND-RESET-FINAL-CLOSE-1B registra la chiusura funzionale e documentale del blocco reset password tokenizzato fase 1.

PR completate:

- PR #126 merged: implementazione reset password tokenizzato fase 1 legacy-compatible.
- PR #127 merged: primo hotfix POST/Redirect/GET su `remind.aspx`.
- PR #128 merged: PRG definitivo e email reset professionale con riferimenti aziendali e avvertenze anti-phishing.
- PR #130 merged: fix redirect post-login dopo reset.
- PR #132 merged: UX finale `remind.aspx?sent=1` con card conferma evidente, form non ambiguo e loader/testi operazione rimossi.
- PR #133 merged: chiusura documentale reset password tokenizzato fase 1.
- PR #134 merged: cleanup warning legacy `BC42024` in `remind.aspx.vb` con rimozione di codice email legacy disabilitato.

Smoke live finale Germano:

- Reset password via link email OK.
- Cambio password OK.
- Login con nuova password OK.
- Redirect post-login verso pagina sicura OK.
- Nessun ritorno a `resetpassword.aspx`.
- URL finale senza token.
- PRG/F5 `remind.aspx` OK.
- Nessuna seconda email su F5.
- Email reset professionale OK, con riferimenti aziendali e avvertenze anti-phishing.
- `remind.aspx?sent=1` mostra card conferma evidente.
- Form nascosto/non dominante su `sent=1`.
- Loader/testi `Operazione in corso` assenti.
- Nessuna immagine loader rotta.
- Nessuna anomalia finale comunicata.

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
- Email reset professionale con riferimenti aziendali e avvertenze anti-phishing.
- `remind.aspx` usa PRG/F5 sicuro e lo stato `sent=1` ha UX chiara.
- `resetpassword.aspx` include toggle mostra/nascondi password client-side.
- Redirect post-login sanificato: `resetpassword.aspx`, `remind.aspx` e URL con token/reset/remind sono esclusi da `ReturnUrl` e redirect sessione.
- Fallback sicuro post-login: `myaccount.aspx`.
- Hash password non implementato; rimandato a task futuro.

Stato finale post-cleanup warning:

- Runtime reset tokenizzato chiuso.
- UX `remind.aspx?sent=1` chiusa.
- Redirect post-login sicuro chiuso.
- Email reset professionale chiusa.
- Documentazione finale chiusa.
- Cleanup warning legacy `remind.aspx.vb` chiuso.
- Reset behavior invariato.
- PRG/F5 invariato.
- Anti-enumeration invariata.
- Regola email + CF oppure email + PIVA invariata.
- Nessun vecchio invio password via email ripristinato.

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
- Warning legacy di precompile in `remind.aspx.vb` chiusi da REMIND-CLEANUP-WARNINGS-1A con rimozione di codice email legacy disabilitato e import inutilizzati.
- Cleanup limitato a codice morto/variabili inutilizzate: nessuna modifica funzionale a reset tokenizzato, PRG/F5, anti-enumeration o regola email + CF/PIVA.
- Errori JS legacy su `registrazione.aspx` da valutare in task separato.
- `datiutente.aspx` resta legacy/compatibilita con tab/JS e gestione salvataggi/destinazioni non piu percorso operativo principale per indirizzi account.
- `my-account-address.aspx` e stabile come pagina moderna autonoma per indirizzi account; add/edit sedi alternative e scelta predefinito sono verificati live.
- Delete indirizzi resta da valutare solo con task dedicato.
- `CART-ADDRESS-SELECTION-1A` corregge il debito carrello indirizzi: la dropdown spedizione fa postback, la scelta manuale viene salvata in sessione per il flusso corrente, l'ID selezionato viene validato contro `UtenteId` e il rebind non deve piu sovrascrivere la scelta manuale con il predefinito.
- Il default carrello resta `utentiindirizzi.Predefinito = 1` quando presente, con fallback all'indirizzo principale `utenti` se non ci sono sedi alternative predefinite.
- Il riepilogo indirizzo spedizione viene aggiornato dalla scelta corrente; in caso di indirizzo non valido/non appartenente all'utente si torna al default sicuro con messaggio utente non tecnico.
- La modifica inline legacy indirizzo nel carrello viene stabilizzata sostituendo le azioni rotte con link sicuri a `my-account-address.aspx`; la gestione add/edit indirizzi resta nella pagina account moderna.
- Nessun gateway/pagamento, costo, totale, DB/schema o SQL viene modificato da `CART-ADDRESS-SELECTION-1A`.
- `CART-ADDRESS-SELECTION-1B` estende la stessa PR #147 con UX carrello piu vicina a ONSUS: riferimento a `Public/assets/keepstore/shop-cart.html` e `checkout.html`, card indirizzo selezionato piu chiara, badge predefinito/manuale, micro-copy locale di controllo CAP/citta/provincia, trust box sobrie e riepilogo piu rassicurante.
- Gli accorgimenti "AI-style" restano euristici locali: nessuna API esterna, nessun modello, nessun invio dati, nessuna modifica DB. Sono solo suggerimenti e micro-copy basati sui campi indirizzo gia presenti nella pagina.
- Anche nell'estensione UX restano invariati gateway, pagamenti, costi, sconti, IVA, totali e flusso ordine.
- `CART-ADDRESS-SELECTION-1D` corregge i residui emersi nello smoke live post-merge: stato selezione indirizzo reso visibile anche accanto alla dropdown, link gestione indirizzi reso diretto verso `/my-account-address.aspx`, pannello legacy inline destinazione escluso dal rendering della pagina carrello.
- Il follow-up 1D resta confinato a UI/UX carrello e documentazione: nessuna modifica a gateway/pagamenti, costi, totali, DB/schema, SQL o flussi account gia chiusi.
- PR #148 e mergiata con merge commit `7558e7dbd8a3221425d5b9bc432fcf272c45625e`; cleanup branch `task/cart-address-selection-1d` completato.
- Smoke live `CART-ADDRESS-SELECTION-1F` conferma carrello moderno, badge predefinito, scelta indirizzo diverso, riepilogo aggiornato, link gestione indirizzi e pannello legacy non raggiungibile; nessun gateway avviato nello smoke base.
- `CART-INLINE-ADDRESS-PAYPAL-RETURN-1A` introduce il passo successivo: add/edit indirizzi alternativi inline nel carrello, link area account solo secondario, euristiche locali di qualita indirizzo, audit statico del ritorno PayPal post-pagamento e continuita chat nel masterplan.
- Diagnosi PayPal del task 1A: il CTA problematico "Torna indietro" e nel nostro `documentidettaglio.aspx` come `javascript:history.back()`; non appartiene al gateway PayPal. Va sostituito con destinazioni sicure senza modificare credenziali, importi, cattura pagamento o stato gateway.
- `CART-INLINE-ADDRESS-PAYPAL-RETURN-1A` non modifica DB/schema/SQL, gateway core, importi gateway, calcoli prezzi, sconti, spedizione, IVA o totali documento.
- `CART-INLINE-ADDRESS-CITYREGISTRY-STEP-1A` si e fermato con Esito B per assenza dello schema completo del DB separato `city_registry` nel dump locale `Database Taikun/KeepStore.sql`; nessun codice e stato modificato in quel passaggio.
- `CART-INLINE-ADDRESS-CITYREGISTRY-STEP-1B` riprende con schema reale `city_registry` fornito da dump separato e verificato in sola lettura: tabelle `cities`, `postcode_codes`, `provinces`, `countries` e campi CAP/citta/provincia richiesti risultano disponibili alla connessione applicativa.
- Il carrello ora usa lookup server-side parametrizzato su `city_registry.postcode_codes`, `city_registry.cities` e `city_registry.provinces` per guidare CAP -> citta/provincia nel form add/edit indirizzo inline; citta e provincia restano non editabili manualmente quando risolte dal CAP.
- Se un CAP corrisponde a piu citta, il form mostra una dropdown e il salvataggio richiede una scelta coerente; se il CAP non e riconosciuto, il salvataggio viene bloccato con messaggio utente non tecnico.
- Durante add/edit indirizzo inline, le azioni non pertinenti del carrello/checkout vengono bloccate lato UI e lato server finche l'utente salva o annulla.
- Il checkout carrello introduce un vero step finale `Conferma`: il pulsante nella fase spedizione/pagamento porta prima al riepilogo finale, mentre l'avvio del flusso ordine/gateway resta consentito solo dal pulsante finale nello step `Conferma`.
- `CART-INLINE-ADDRESS-CITYREGISTRY-STEP-1B` non modifica DB/schema/SQL, gateway core, importi gateway, calcoli prezzi, sconti, spedizione, IVA, totali documento, login/reset/password o area account chiusa.
- PR #149 e mergiata con merge commit `05a43e54821af795ce897f50465405a7cae21bea`; PR #150 e mergiata con merge commit `b41cc367366fd0a2cfb470edc9afb259cbde2c71`.
- `CART-ADDRESS-SELECTION`, `CART-INLINE-ADDRESS-PAYPAL-RETURN` e `CART-INLINE-ADDRESS-CITYREGISTRY-STEP` sono chiusi come blocco unico carrello/indirizzi/CAP/step `Conferma`.
- Smoke live `CART-INLINE-ADDRESS-CITYREGISTRY-STEP-1D` completato con esito A: login OK, carrello aperto, layout ONSUS stabile, indirizzo predefinito e indirizzo manuale selezionabili, riepilogo aggiornato, add/edit inline funzionanti, CAP con lookup `city_registry`, multi-citta gestita, citta/provincia bloccate quando il CAP e riconosciuto, azioni bloccate durante edit, step `Conferma` attivo, gateway avviabile solo dal pulsante finale, nessuna anomalia rilevata.
- `documentidettaglio.aspx` non usa piu `history.back()` per il CTA post-pagamento coinvolto dal blocco: le CTA post-PayPal/post-documento restano su destinazioni sicure.
- Durante tutto il blocco non sono stati modificati gateway PayPal/BancaSella, core checkout, costi, sconti, spedizione, IVA, totali documento, DB/schema, SQL, login/reset/password o area account gia chiusa.
- Stato finale carrello/checkout: `carrello.aspx` stabile per UI carrello, selezione indirizzi, add/edit inline e step `Conferma`; il core pagamenti/gateway resta separato e va trattato solo con task dedicati.
- Non riaprire il blocco carrello/indirizzi/CAP/step `Conferma` salvo bug live verificato.
- `ORDER-CONFIRMATION-UX-1A` modernizza `documentidettaglio.aspx` come pagina post-acquisto/dettaglio ordine compatibile: hero stile e-commerce ONSUS/Taikun, messaggio "Grazie per il tuo ordine" solo nel contesto post-conferma o rientro pagamento, dati ordine principali, stampa ordine, copia numero ordine, CTA sicure, card pagamento/spedizione/fatturazione/riepilogo/prossimi passi/supporto e timeline locale.
- Il riferimento UX fornito da Germano viene usato solo come ispirazione generica post-acquisto: nessun brand/testo/asset dello screenshot, nessuna immagine esterna, nessuna API AI o tracking esterno introdotto.
- File coinvolti da `ORDER-CONFIRMATION-UX-1A`: `documentidettaglio.aspx`, `documentidettaglio.aspx.vb`, `Public/assets/keepstore/css/order-ui.css`, `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`, `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md`.
- `ORDER-CONFIRMATION-UX-1A` non modifica gateway core PayPal/BancaSella/IwBank, credenziali, endpoint, autorizzazione/cattura, importi inviati ai gateway, calcolo prezzi, sconti, spedizione, IVA, totale documento, generazione ordine/documento, DB/schema o SQL.
- PR #152 e mergiata con merge commit `c0896bfe40c40cc88aabd6944e309a738e37156f`; smoke live post-merge resta da eseguire senza pagamento reale.
- `CART-SESSION-TIMEOUT-1A` registra una anomalia live su `carrello.aspx`: se una sessione utente scade mentre la pagina resta aperta, un refresh/F5 puo portare a pagina bianca o stato incoerente prima dei binding del carrello/checkout.
- Fix previsto in `CART-SESSION-TIMEOUT-1A`: guard server-side iniziale su sessione ASP.NET ricreata da cookie scaduto, redirect sicuro a `login.aspx?ReturnUrl=carrello.aspx&sessionExpired=1`, messaggio utente non tecnico su login e blocco degli eventi sensibili del carrello quando la sessione e scaduta.
- `CART-SESSION-TIMEOUT-1A` non modifica gateway core, PayPal/BancaSella, importi gateway, calcolo prezzi, sconti, spedizione, IVA, totali documento, generazione ordine/documento, DB/schema o SQL.
- Smoke live richiesto dopo eventuale merge: carrello con sessione valida, simulazione o attesa timeout, F5 senza pagina bianca, redirect/messaggio sessione scaduta, login con ritorno al carrello se previsto, nessun gateway avviato.
- PR #153 e mergiata con merge commit `5a0e2565fa94b3ab8705842c3e10359d381f46e6`; cleanup branch `task/cart-session-timeout-1a` completato. Lo smoke live mirato session timeout resta da eseguire da Germano senza pagamento reale.
- Smoke live `CART-SESSION-TIMEOUT-1C` completato con esito A: sessione valida OK, sessione scaduta + F5 senza pagina bianca, redirect controllato a login con messaggio chiaro e `ReturnUrl`, rientro al carrello funzionante, postback protetti, add/edit indirizzo, CAP/`city_registry`, step `Conferma` e `documentidettaglio.aspx` verificati; nessun gateway, pagamento, ordine o dato sensibile coinvolto.
- `CART-UX-SUMMARY-STEPPER-TIMEOUT-1A` risolve le anomalie residue del carrello: un solo riepilogo visibile `Riepilogo ordine`, riepilogo tecnico legacy mantenuto solo per le label server-side, stepper superiore navigabile in modo coerente tra `Carrello`, `Spedizione e checkout` e `Conferma` senza avviare gateway, timeout sessione standardizzato a 30 minuti in `web.config` e in `carrello.aspx.vb`.
- Il task resta confinato a UX carrello, gestione sessione e documentazione: nessuna modifica a gateway PayPal/BancaSella, core checkout, costi, sconti, spedizione, IVA, totali documento, generazione ordine/documento, DB/schema, SQL, login/reset/password o area account gia chiusa.
- Smoke live `CART-UX-SUMMARY-STEPPER-TIMEOUT-1C = B`: carrello/riepilogo, stepper normale, timeout/sessionExpired, add/edit indirizzo, CAP/`city_registry` e `documentidettaglio.aspx` risultano OK; resta da correggere il lock coerente durante add/edit indirizzo, per impedire stepper e azioni carrello/checkout finche l'utente salva o annulla.
- `CART-ADD-EDIT-LOCK-1A` registra il follow-up mirato: durante add/edit indirizzo inline il checkout entra in stato lock, con UI disabilitata e guard server-side centralizzata su stepper, procedi ordine, conferma/gateway, righe carrello, coupon, cambio indirizzo, spedizione e pagamento.
- Lo stesso task corregge il logo header desktop/mobile: sorgente `Aziende.LogoWeb`, path pubblico `/Public/assets/images/logo/{LogoWeb}`, nome file sanificato, fallback interno `logo.svg` nella stessa cartella e nessun path legacy `Public/Images/`.
- `FOOTER-LOGOWEB-1A` completa la standardizzazione logo iniziata con PR #156: anche il footer usa `Aziende.LogoWeb`, path `/Public/assets/images/logo/{LogoWeb}`, nome file sanificato e fallback interno controllato; nessun carrello, gateway, totale, DB/schema o SQL modificato.
- Smoke live `CART-LOGO-LOCK-FINAL-1C = B`: logo header/footer OK, carrello normale OK, stepper/procedi/gateway lock OK, CAP/sessione OK; residua solo anomalia dei controlli quantita `+/-` che cambiano valore a video durante add/edit indirizzo.
- `CART-ADD-EDIT-QTY-LOCK-1A` corregge il residuo: durante add/edit indirizzo anche il quantity stepper `+/-` e l'input quantita sono inibiti lato UI, mentre il guard server-side continua a bloccare ogni update riga.
- Anomalia live `ACCESS-DENIED-PAGE-404`: richiesta `/accessonegato.aspx` restituisce 404 ASP.NET "Impossibile trovare la risorsa" invece di una pagina utente coerente. La causa locale e una pagina legacy non canonica rispetto al code-behind esistente e al deploy live; `ACCESS-DENIED-PAGE-1A` ripristina una pagina runtime mirata per accesso negato/sessione non valida, senza modificare carrello, logo, gateway, totali, DB/schema o web.config.
- Smoke live `CART-ADD-EDIT-QTY-LOCK-1C = A`: carrello normale, quantity `+/-`, pulsante Aggiorna, riepilogo unico `Riepilogo ordine`, add/edit indirizzo, microcopy, lock stepper/procedi/aggiorna, blocco click `+/-` e input quantita durante add/edit, ripristino con Annulla/Salva, CAP/`city_registry`, session timeout + F5 e `documentidettaglio.aspx` tutti OK. Step `Conferma` non avvia gateway da solo, gateway solo da pulsante finale Conferma; logo header desktop, header mobile e footer OK; nessun 404 logo, errore 500, stack trace, loop redirect o pagamento reale.
- Smoke live `ACCESS-DENIED-PAGE-1C = A`: `/accessonegato.aspx` apre correttamente, non mostra piu il 404 ASP.NET, usa layout sito, titolo `Accesso non consentito` o equivalente, messaggio non tecnico, CTA `Accedi` verso `login.aspx`, CTA home verso `Default.aspx`/home, nessun loop redirect, `ReturnUrl=carrello.aspx` gestito con pagina richiesta locale, `ReturnUrl` esterno non produce redirect esterno, nessun open redirect evidente, homepage/carrello/documentidettaglio e logo header/footer OK.
- Blocco carrello/session timeout/riepilogo/stepper/add-edit/quantity lock/logo/accessonegato chiuso live su HEAD stabile `a23f2a6153b57048769dd5b2a6153f2d13ced445`.
- Gli smoke finali non hanno modificato gateway, PayPal/BancaSella, totali, costi, spedizione, IVA, sconti, DB/schema, SQL, `web.config` o sistema email runtime.
- `EMAIL-ENGINE-1A` e il prossimo blocco operativo consigliato.
- `EMAIL-SYSTEM-AUDIT-1A` apre il blocco e-mail transazionali Taikun/KeepStore, solo documentale e senza runtime: audit invii esistenti, fonti DB ordine/pagamento/spedizione/logo, benchmark sintetico fornitori, standard template e roadmap micro-task futuri.
- Manuale creato: `docs/KEEPSTORE_EMAIL_STANDARD.md`. Contiene mappa invii attuali, dati DB reali, standard HTML/plain text, varianti bonifico/contrassegno/PayPal/carta/Banca Sella, oggetti consigliati e roadmap `EMAIL-ENGINE`, `EMAIL-ORDER-CONFIRMATION`, `EMAIL-BANKTRANSFER`, `EMAIL-COD`, `EMAIL-ORDER-STATUS`, `EMAIL-AUTH`, preview/test e deliverability.
- Benchmark sintetico recepito: email chiare su stato pagamento, importi, causale bonifico, pagamento alla consegna, CTA sicure, riepilogo ordine completo, layout table-based 600/640 px, logo azienda da DB e nessun asset esterno/legacy.
- Audit iniziale conferma che la conferma ordine parte da `ordine.aspx.vb`, il reset password tokenizzato da `App_Code/PasswordResetTokenService.vb`, registrazione/profilo da `registrazione.aspx.vb`; cambio password, reset completato, cambio stato ordine e tracking/spedizione non risultano inviati dal runtime web auditato.
- `documenti.aspx` inserisce richieste in `inviadocumenti`; invio reale documento/fattura/proforma da gestionale/processo esterno resta da confermare con Vincenzo.
- Nessun codice runtime, CSS, DB/schema, SQL, gateway, carrello/checkout, login/reset/registrazione o template applicativo viene modificato da `EMAIL-SYSTEM-AUDIT-1A`.
- `EMAIL-ENGINE-1A` introduce la fondazione runtime `App_Code/KeepStoreEmailTemplate.vb`: renderer HTML table-based + plain text, logo da `Aziende.LogoWeb` con path `/Public/assets/images/logo/{LogoWeb}` e fallback interno `logo.svg`, subject helper e microcopy pagamento/spedizione.
- Primo invio runtime migrato: NON MIGRATO. Gli invii legacy in `ordine.aspx.vb`, `registrazione.aspx.vb` e `App_Code/PasswordResetTokenService.vb` restano invariati in questo task.
- `EMAIL-ENGINE-1A` non modifica SMTP, `web.config`, appSettings, connection string, DB/schema, SQL, gateway, carrello/checkout, calcolo importi/totali/costi, login/reset/registrazione runtime o sistema email runtime esistente.
- Prossimo passo consigliato dopo merge/verifica di `EMAIL-ENGINE-1A`: `EMAIL-ORDER-CONFIRMATION-1A`, migrazione controllata della sola conferma ordine usando il renderer condiviso, senza modificare gateway o totali.
- `LOCAL-ASSET-UNTRACKED-CLEANUP-1A = B`: dopo merge `EMAIL-ENGINE-1B` la working tree locale era sporca solo per asset non tracciati sotto `Public/assets/images/...`; 684 asset non referenziati sono stati spostati in quarantena fuori repository in `C:\KeepStoreWeb\_untracked_assets_quarantine\20260609-2352`, con manifest dedicato, senza cancellare file tracciati e senza commit.
- `REFERENCED-ASSETS-DECISION-1A`: i 22 asset rimasti sono stati versionati perche referenziati da runtime attivo o template inclusi nel repository (`coupon*.aspx`, `carrello.aspx`, `documenti.aspx.vb`, `SiteHeader.ascx.vb`, template mailing/eBay legacy). Gli ulteriori 78 asset locali extra non referenziati, ricomparsi fuori dal perimetro dei 22, sono stati spostati in quarantena separata `C:\KeepStoreWeb\_untracked_assets_quarantine\referenced-assets-extra-20260610-0007`.
- Stato atteso dopo `REFERENCED-ASSETS-DECISION-1A`: working tree pulita, nessun codice runtime modificato, nessun DB/schema/SQL, gateway, carrello, email engine, `web.config`, header/footer/logo o `Page.master` modificati. Prossimo task operativo resta `EMAIL-ORDER-CONFIRMATION-1A`.
- `EMAIL-ORDER-CONFIRMATION-1A` parte da base HEAD `78acd2585c9135f30054b633bac9ec6ea6aaae7f` e migra la sola email conferma ordine/preventivo in `ordine.aspx.vb` al renderer standard `App_Code/KeepStoreEmailTemplate.vb`.
- Trigger, timing, destinatario cliente, BCC azienda, mittente, SMTP, credenziali SMTP e condizioni di invio restano invariati; non vengono introdotti invii duplicati o anticipati.
- Il subject usa gli helper standard: conferma ordine generica oppure variante bonifico quando il metodo pagamento esistente indica bonifico. Il vecchio body HTML resta come fallback se il renderer fallisce.
- Il nuovo body usa HTML table-based e plain text, logo aziendale da `Aziende.LogoWeb` tramite sessione azienda gia popolata, riepilogo documento, cliente/indirizzi gia disponibili, righe, importi gia calcolati, pagamento, spedizione e CTA sicura al dettaglio documento.
- Le varianti pagamento supportate usano microcopy standard per bonifico, PayPal/carta/online, contrassegno e pagamento generico; non viene dichiarato pagamento ricevuto senza conferma gia presente nel flusso.
- `EMAIL-ORDER-CONFIRMATION-1A` non modifica gateway PayPal/BancaSella, carrello/checkout, importi, costi, IVA, spedizione, sconti, generazione ordine/documento, DB/schema, SQL, `web.config`, connection string, appSettings o impostazioni SMTP.
- Prossimo task: `EMAIL-ORDER-CONFIRMATION-1B` review/merge PR.
- `EMAIL-ORDER-CONFIRMATION-1C = B`: smoke live parziale su ordine test/preventivo con bonifico ha confermato e-mail ricevuta e subject coerente, ma il sorgente MIME risultava errato: HTML dentro una parte `text/plain` e plain text separato.
- `EMAIL-ORDER-CONFIRMATION-MIME-1A` corregge solo MIME/AlternateViews della conferma ordine/preventivo: plain text come `text/plain; charset=utf-8`, HTML come `text/html; charset=utf-8`, senza modificare trigger, destinatario, subject, SMTP, ordine, gateway, totali, DB/schema o `web.config`.
- Backlog futuro: `EMAIL-LEGACY-SENDS-CLEANUP-1A` per mappare e bonificare i vecchi invii e-mail legacy dopo stabilizzazione dei nuovi flussi ordine/registrazione/reset, senza rimuovere codice legacy in task MIME.
- `EMAIL-ORDER-CONFIRMATION-MIME-1C = B`: nuovo smoke live conferma MIME corretto, `text/plain` e `text/html` OK, caratteri italiani/euro OK, ordine/preventivo creato, email ricevuta una sola volta, righe/quantita/importi/pagamento bonifico OK e nessuna falsa dichiarazione di pagamento ricevuto. Restano da rifinire subject con numero/data, data ordine nel corpo, logo email non visibile, CTA `Visualizza ordine` che passa da typo `/accesonegato.aspx` e layout email da arricchire.
- `EMAIL-ORDER-CONFIRMATION-POLISH-1A` rifinisce solo subject/data/logo/CTA/layout della conferma ordine: logo email multi-azienda da `Aziende.LogoWeb` con URL assoluto HTTPS, CTA protetta via `login.aspx?ReturnUrl=...`, correzione typo `accesonegato.aspx`, hero/blocchi riepilogo/prossimi passi piu ricchi e data ordine pulita. Trigger, destinatario, mittente, SMTP, ordine, gateway, totali, DB/schema e `web.config` restano invariati.
- Backlog `EMAIL-LEGACY-SENDS-CLEANUP-1A` confermato: mappare e bonificare vecchi invii ordine/registrazione/reset solo dopo stabilizzazione dei nuovi flussi basati su `KeepStoreEmailTemplate`.
- `EMAIL-ORDER-CONFIRMATION-POLISH-1C = A`: smoke funzionale OK su ordine test bonifico, email ricevuta con MIME corretto, subject/logo/CTA/layout migliorati; nessun pagamento reale, gateway o cliente reale coinvolto.
- `EMAIL-ORDER-CONFIRMATION-PRO-1A` completa la rifinitura professionale della conferma ordine: causale bonifico `Pagamento ordine n. ... del ...`, foto prodotto ottimizzata con `_nomefile` se disponibile sotto asset pubblici moderni, tabella prodotti con codice/EAN/descrizione/quantita/prezzo unitario/totale riga, footer azienda da `Aziende`, vettori deduplicati da `vettori.Descrizione`/`vettori.Informazioni`, prezzi prodotto coerenti con flag IVA cliente e nota IVA spostata fuori dal blocco importi.
- Scope invariato per `EMAIL-ORDER-CONFIRMATION-PRO-1A`: trigger, destinatario, mittente, BCC, SMTP, ordine/documento, gateway, PayPal/BancaSella, importi/totali/costi/IVA reali, DB/schema, SQL e `web.config` non vengono modificati.
- Backlog `EMAIL-LEGACY-SENDS-CLEANUP-1A` resta aperto: mappare successivamente vecchi invii dopo ordine e registrazione nuovo cliente, poi disattivarli/rimuoverli solo quando il nuovo sistema email e stabile.
- `EMAIL-ORDER-CONFIRMATION-PRO-1C = B`: smoke live su ordine test 190 ha confermato email ricevuta, MIME corretto, subject corretto, causale bonifico corretta, tabella prodotti presente, importi coerenti, footer aziendale, CTA funzionante e vettore deduplicato; restano anomalie di rifinitura su copy CTA, nota legale documento vendita, font/leggibilita, riepilogo ordine e foto mancanti per le prime due righe prodotto.
- `EMAIL-ORDER-CONFIRMATION-FINAL-POLISH-1A` interviene solo su `ordine.aspx.vb`, `App_Code/KeepStoreEmailTemplate.vb` e documentazione per CTA copy, nota legale, tipografia email-safe, riepilogo ordine piu leggibile e risoluzione foto prodotto piu robusta con candidati `Img1..Img6` da articolo.
- Scope invariato per `EMAIL-ORDER-CONFIRMATION-FINAL-POLISH-1A`: nessun gateway, PayPal/BancaSella, carrello/checkout, totali/costi/IVA/spedizione/sconti reali, generazione/stato ordine-documento, DB/schema, SQL, `web.config`, SMTP, header/footer/logo sito o vecchi invii email rimossi.
- `EMAIL-ORDER-CONFIRMATION-FINAL-POLISH-1C = B`: smoke live su ordine test 192 ha confermato email complessivamente rifinita, ma le prime due righe prodotto risultavano ancora senza foto mentre una terza riga mostrava correttamente immagine assoluta HTTPS da `/Public/assets/images/articoli/`; il renderer email era corretto, la risoluzione candidati immagine restava incompleta.
- `EMAIL-ORDER-CONFIRMATION-PRODUCT-IMAGES-1A` corregge solo la risoluzione foto prodotto della conferma ordine: candidati da `vdocumentirighe.Img1`, immagini variante tramite `articoli_tagliecolori.immaginiId` / `immagini.Immagine1..Immagine6`, poi `articoli.Img1..Img6`; priorita alla versione compressa `_nomefile`, fallback al nome originale, nome file sanificato e segmento URL encodato, nessun codice prodotto hardcoded, nessun base64/allegato/path legacy.
- Scope invariato per `EMAIL-ORDER-CONFIRMATION-PRODUCT-IMAGES-1A`: nessun gateway, PayPal/BancaSella, carrello/checkout, totali/costi/IVA/spedizione/sconti reali, generazione/stato ordine-documento, DB/schema, SQL, `web.config`, SMTP, header/footer/logo sito, layout generale email o vecchi invii email rimossi.
- `EMAIL-ORDER-CONFIRMATION-ARUBA-COMPAT-1A` registra anomalia live su ordine test 197: Hotmail/Outlook legge correttamente la conferma ordine, mentre Aruba Webmail comprime la tabella prodotti e spezza verticalmente le intestazioni perche il layout usa troppe colonne affiancate; anche il riepilogo superiore rischia compressione.
- Fix previsto: sostituire la tabella prodotti a 7 colonne con product card email-safe table-based, foto fissa e dettagli label/value; rendere il riepilogo superiore e il riepilogo ordine label/value verticali. Scope invariato: nessun SMTP, MIME, subject, causale bonifico, gateway, DB/schema, checkout/sessione, query immagini, prezzi, IVA, spedizione o totali modificati.
- `ORDER-NOTES-LIMIT-1A` registra anomalia live durante invio ordine: note checkout troppo lunghe causano errore tecnico DB `Data too long for column 'pNoteSpedizione' at row 1`. PR #173 su branch `task/order-notes-limit-1a`, commit iniziale `8d7fdc34293e6797cbe97751bf0d669ccf37e490`, merged e confermata post-smoke. Fonte DB verificata: stored procedure `carrello_Documento`, parametro `pNoteSpedizione VARCHAR(255)`, salvato in `documenti.NoteEsterne` senza modifica schema. Fix implementato: limite UI 255 caratteri su `txtNoteSpedizione` in `carrello.aspx`, contatore/hint, validazione server-side in `carrello.aspx.vb` prima della creazione ordine e guard difensivo in `ordine.aspx.vb` prima di stored procedure, email e gateway. Smoke `CART-CHECKOUT-SMOKE-1D = A`: incolla oltre limite bloccato/limitato a 255, contatore `255 / 255`, nessun errore tecnico; nessun troncamento silenzioso. Scope invariato: nessuna modifica DB/schema, gateway, prezzi, IVA, SMTP o template email.
- REV1 documentale PR #173 registrata con commit `d64961b1fe04f4a539d5605e3a34ddf27eedab19`: integrazione documentale dopo review bloccata; PR tecnicamente conforme, documentazione integrata e pronta per nuova review/merge `ORDER-NOTES-LIMIT-1B`, poi smoke manuale note ordine.
- Checkbox consenso condizioni: PR #169 storica non mergiata e sostituita da PR #174; PR #169 va chiusa come superseded e non mergiata.
- `CART-TERMS-CONSENT-1B` / PR #174 su branch `task/cart-terms-consent-1b`, commit funzionale `3b20195aca524c06cd13e7f4a88cac84af96dc8e`, merge commit `e837206c2c31e1ab7e9282f0a6bbe5aa3a4effd0`: sostituisce PR #169 non recuperata per conflitti con PR #173 su `carrello.aspx` / `carrello.aspx.vb` e per asset CSS/JS fuori scope. Regola: consenso condizioni vendita obbligatorio prima di creare ordine, gateway o email; preservato fix PR #173 limite note ordine 255, contatore/hint, validazione server-side e guard difensiva. Smoke `CART-CHECKOUT-SMOKE-1D = A`: checkbox visibile, testo corretto, link `condizioni-vendita.aspx` OK, pagina condizioni leggibile, blocco UI senza consenso OK, nessun ordine/gateway/email senza consenso, carrello preservato, con consenso pulsante/flusso abilitato senza completare ordine, nessun errore tecnico o JS console. Prossimo step: cleanup sicuro branch gia mergiati, poi valutare PR #171 diagnostica sessione post-ordine solo se il problema logout/sessione e ancora riproducibile.
- Checkout note ordine + consenso condizioni e chiuso con smoke A: PR #173 e PR #174 sono merged e validate live; PR #169 chiusa come superseded. Test manuale sessione/logout post-ordine: esito A, problema non riproducibile ora; PR #171 resta backlog non attivo e non va ripresa finche il problema non torna riproducibile.
- Backlog `EMAIL-HOTMAIL-DELIVERY-DELAY-1A`: non modificare SMTP/template in questo task. Analisi rinviata a disponibilita `.eml` Hotmail o persistenza ritardo; confrontare `.eml` Aruba e Hotmail, `Date`, catena `Received`, SPF/DKIM/DMARC, SCL/spam/quarantena e copie/BCC gestore.
- `EMAIL-AUTH-TEMPLATE-1A` / PR #175 su branch `task/email-auth-template-1a`, commit funzionale `6f11e652f5b20d78dbdaac46da808edebd774568`, migra gli invii registrazione nuovo cliente e aggiornamento profilo legacy da `registrazione.aspx.vb` al renderer condiviso `App_Code/KeepStoreEmailTemplate.vb`. Destinatari, BCC aziendale, mittente e SMTP/config esistenti restano invariati; non vengono inserite password nel body, non sono previsti invii duplicati e il vecchio body HTML hardcoded viene sostituito da HTML/plain text standard. Reset/remind password, email ordine, DB/schema, SQL, gateway, carrello/checkout, prezzi/IVA/totali, `web.config`, appSettings e connection string restano fuori scope. Prossimo step dopo PR: smoke controllato registrazione/profilo, senza invii live o utenti live non autorizzati.
- `EMAIL-PASSWORD-TEMPLATE-1A` / PR #176 su branch `task/email-password-template-1a`, commit funzionale `49ee7888f10eddcbe65b96ba257b94657bc9d880`, migra il rendering dell'email reset/remind password tokenizzato da `App_Code/PasswordResetTokenService.vb` al renderer condiviso `App_Code/KeepStoreEmailTemplate.vb`. Il flow tokenizzato resta invariato: generazione, salvataggio, scadenza, validazione, consumo token, destinatario, mittente, SMTP/config e anti-enumerazione non cambiano; nessuna password viene inserita nel body, registrazione/profilo ed email ordine restano fuori scope. Prossimo step: review/merge PR #176, poi smoke statico o runtime solo con SMTP sink/test.
- Blocco email account/auth/password chiuso: PR #175 e PR #176 mergeate; smoke statico registrazione/profilo `EMAIL-AUTH-SMOKE-1A = A` e smoke statico reset/remind `EMAIL-PASSWORD-TEMPLATE-1C = A`. Nessuna email live inviata, nessun utente live creato, nessuna password reale resettata. SMTP/config, DB/schema, gateway, carrello/checkout, prezzi/IVA ed email ordine restano invariati; il token flow reset password preserva generation, validation, expiry, storage/consume e anti-enumerazione. Rendering runtime non eseguito per assenza di ambiente test autorizzato con SMTP sink; eventuale smoke runtime futuro richiede DB test, account test e SMTP sink.
- `EMAIL-LEGACY-SENDS-CLEANUP-1A` / PR #177 su branch `task/email-legacy-sends-cleanup-1a`: inventario controllato residui email legacy dopo migrazione ordine, registrazione/profilo e reset/remind a `KeepStoreEmailTemplate`. Commit funzionale non necessario: nessun codice runtime rimosso perche gli elementi rimasti sono trasporto SMTP vivo (`MailMessage`/`SmtpClient`), fallback legacy ordine prudenziale ancora attivo se il renderer fallisce, invii contatto/main fuori scope o import non bloccanti. SMTP/config, destinatari, BCC/mittente, token flow, ordine, DB/schema, gateway, carrello/checkout, prezzi/IVA e documenti runtime restano invariati. La PR registra l'esito di cleanup controllato; smoke runtime resta ammesso solo con SMTP sink/test.
- `EMAIL-MAIN-CONTACT-CLEANUP-1A` / PR #178 su branch `task/email-main-contact-cleanup-1a`, commit funzionale `f5132b24413dd91b3c29a74317468559fe856c89`, mette in sicurezza solo l'invio contatto legacy di `main.aspx.vb`: body raw HTML eliminato a favore di `KeepStoreEmailTemplate`, From utente non piu usato come mittente diretto, Reply-To utente preservato, destinatario aziendale e SMTP/config invariati, `ex.Message` non piu esposto all'utente. `Contattaci.aspx.vb`, ordine, registrazione/profilo, reset/remind, DB/schema, gateway, carrello/checkout, prezzi/IVA e `web.config` restano fuori scope. Prossimo step eventuale: `EMAIL-CONTATTI-TEMPLATE-1A`.
- `EMAIL-CONTATTI-TEMPLATE-1A` / PR #179 su branch `task/email-contatti-template-1a`, commit funzionale `fe75c8874fca5d9ae6ecf436f76c3f51a1c085f6`, migra il rendering dell'email contatto di `Contattaci.aspx.vb` al renderer condiviso `KeepStoreEmailTemplate`. Restano preservati destinatario aziendale, mittente aziendale, Reply-To utente, subject `[Contatto sito]`, SMTP/config, logging e messaggi utente non tecnici; `main.aspx.vb`, ordine, registrazione/profilo, reset/remind, DB/schema, gateway, carrello/checkout, prezzi/IVA e `web.config` restano fuori scope. Prossimo step: review/merge PR #179 e smoke statico post-merge.
- Blocco email `KeepStoreEmailTemplate` chiuso: email ordine, PR #175 registrazione/profilo, PR #176 reset/remind password con token flow preservato, PR #178 contatto legacy `main.aspx.vb` e PR #179 `Contattaci.aspx.vb` sono completate e validate con smoke statici A dove richiesto. Nessuna email live inviata, nessun utente live creato, nessuna password reale resettata; SMTP/config, DB/schema, gateway, carrello/checkout, prezzi/IVA e `main` restano invariati. Rendering/runtime non eseguito per assenza di ambiente autorizzato con SMTP sink; eventuale smoke runtime futuro richiede DB test, account test e SMTP sink.
- `ACCOUNT-DATIUTENTE-VALIDATION-1A` / PR #180 su branch `task/account-datiutente-validation-1a`, commit funzionale `82c85d13d73128824613018f3975b22fe9165569`, hardenizza la pagina legacy `datiutente.aspx`: verifica login/sessione preservata e rafforzata, ownership update utente vincolata a `LoginId`/`UtentiId`, update indirizzi vincolati a `UtenteId`, validazioni server-side minime su email, fatturazione, CAP/provincia/contatti e destinazione alternativa, messaggi errore non tecnici. File runtime modificato: `datiutente.aspx.vb`; documentazione aggiornata. PR #180 mergeata; non sono stati modificati DB/schema/stored procedure, checkout/carrello/ordine, gateway, email/template, `web.config`, `registrazione.aspx`, `myaccount.aspx`, `my-account-edit.aspx` o `my-account-address.aspx`; nessun dato cliente reale e stato modificato.
- `ACCOUNT-DATIUTENTE-UI-1A` / PR #181 su branch `task/account-datiutente-ui-1a`, commit funzionale `bd26979e7d9572fe03a864aa6de18ec6f862dbfc`, sistema solo la resa UI della pagina legacy `datiutente.aspx` dopo smoke manuale B leggero visivo: card ponte "Gestione dati account", CTA coerenti verso `my-account-edit.aspx`, `my-account-address.aspx` e `myaccount.aspx`, sezione legacy incapsulata in card moderna e fix CSS dedicato per non mostrare wrapper FormView vuoti. PR #181 mergeata; logica dati hardenizzata da PR #180 preservata, nessun cambio DB/schema/stored procedure, checkout/carrello/ordine, gateway, email/template, `web.config`, `registrazione.aspx` o pagine account moderne; nessun dato cliente reale modificato.
- `ACCOUNT-DATIUTENTE-UI-FIX-1A` / PR #182 su branch `task/account-datiutente-ui-fix-1a`, commit funzionale `a0023fbc7b27e06a2f82aea49c475576b7fcdb38`, rimuove il blocco legacy duplicato fuori layout rimasto visibile dopo PR #181: breadcrumb legacy, intestazione "Dati di accesso / account" e tab duplicati "Dettagli account" / "Indirizzi" non sono piu renderizzati fuori dalla card moderna. Restano solo la UI account centrale e la sezione legacy incapsulata; `datiutente.aspx.vb` e la logica dati PR #180 restano invariati. Nessun cambio DB/schema/stored procedure, checkout/carrello/ordine, gateway, email/template, `web.config`, `registrazione.aspx` o pagine account moderne; nessun dato cliente reale modificato. PR #182 mergeata su `frontend-rebuild` con HEAD post-merge `d5df0a85fec9b071da3a2aa1bf1b749038d98824`.
- `ACCOUNT-AREA-LEGACY-DUPLICATES-1A`: audit statico post-merge PR #182 su `myaccount.aspx`, `my-account-edit.aspx`, `my-account-address.aspx`, `datiutente.aspx`, `AccountSidebar.ascx` e CSS account. Non risultano duplicati legacy evidenti fuori layout ne sidebar/nav inline visibili da correggere; i vecchi selettori CSS `wrap-sidebar-account` non risultano agganciati al markup account ispezionato. Nessun branch o fix applicativo aggiuntivo creato; logica dati/login/sessione/ownership, checkout/carrello/ordine, DB/schema/SP, gateway ed email/template invariati. Prossimo step: smoke manuale UI area account.
- Blocco Area Cliente UI/datiutente chiuso con smoke manuale A: accesso anonimo a `datiutente.aspx` protetto senza dati personali visibili; accesso loggato coerente, blocco legacy duplicato non piu visibile; link `my-account-edit.aspx`, `my-account-address.aspx` e `myaccount.aspx` funzionanti; `myaccount.aspx`, `my-account-edit.aspx`, `my-account-address.aspx` e `carrello.aspx` OK. Nessun dato cliente reale modificato; checkout/carrello/ordine/gateway/email/DB/schema/SP non toccati.
- `ACCOUNT-ADDRESS-ORDER-GUARD-1A` chiuso: PR #183 mergeata con guard difensiva in `ordine.aspx.vb` su `Session("SCEGLIINDIRIZZO")`. `Nothing`, vuoto o `0` mantengono il flusso storico; valori > 0 richiedono ownership parametrizzata `Id=?Id AND UtenteId=?UtentiId`; indirizzi invalidi, stale o non appartenenti bloccano prima di `Carrello_Documento` con redirect generico `carrello.aspx?addresserror=1`, senza ordine, gateway, email o svuotamento carrello. Smoke statico post-merge `ACCOUNT-ADDRESS-ORDER-GUARD-1C = A`; smoke runtime rimandato a ambiente sicuro con account test, carrello test, gateway non reale e SMTP sink. Carrello, DB/schema/SP, gateway/pagamenti, email/template, prezzi/IVA/totali/documenti e dati cliente reali restano invariati.
- `CART-ADDRESS-ERROR-MESSAGE-1A` / PR #185 su branch `task/cart-address-error-message-1a`, commit funzionale `d3b5de9097328b8b28b6729d899d36e1402e6508`, mergeata e validata con smoke `SMOKE CART ADDRESS ERROR: A`: `carrello.aspx?addresserror=1` mostra un alert fisso e non tecnico sul carrello ("L'indirizzo di spedizione selezionato non è più valido. Seleziona nuovamente l'indirizzo e conferma l'ordine.") usando il canale messaggi indirizzo gia presente. Il valore querystring non viene riflesso in HTML; nessun cambio a `ordine.aspx.vb`, `Carrello_Documento`, DB/schema/SP, gateway/pagamenti, email/template, prezzi/IVA/totali/righe o dati cliente reali.
- `CART-LEGACY-DUPLICATE-AUDIT-FIX-1A` / PR #186 su branch `task/cart-legacy-duplicate-audit-fix-1a`, commit funzionale `38cdab5a76c305940d8735cbf21b3ecc96406959`, mergeata e validata con smoke `SMOKE CART CHECKOUT UI: A`: corregge un duplicato UI in `carrello.aspx`, dove durante lo step checkout il wrapper principale `CartItemsWrap` restava visibile mentre venivano renderizzati shell checkout e riepilogo laterale. Fix applicato in `carrello.aspx.vb`: `CartItemsWrap` viene nascosto con `d-none` solo quando `tOrdine`/checkout e visibile e ripristinato nello step carrello. Restano preservati controlli server, ID, postback, scelta indirizzo, note ordine, consenso condizioni e pulsanti checkout/conferma. Nessun cambio a `ordine.aspx.vb`, `Carrello_Documento`, DB/schema/SP, gateway/pagamenti, email/template, prezzi/IVA/totali/righe o asset legacy `Public/Images/`.
- Blocco carrello/checkout UI chiuso con smoke manuale A: PR #185 mergeata con `SMOKE CART ADDRESS ERROR: A` e messaggio `addresserror=1` visibile, singolo, generico e non tecnico; PR #186 mergeata con `SMOKE CART CHECKOUT UI: A`, duplicato checkout confermato e risolto nascondendo `CartItemsWrap` solo quando `tOrdine`/checkout e visibile. In fase carrello normale resta una sola lista prodotti; in checkout non compaiono due carrelli/listati prodotti. Scelta indirizzo, note ordine, consenso condizioni, pulsanti checkout/conferma, riepilogo, prezzi/IVA/totali/righe restano preservati; ordine/gateway/email, DB/schema/SP e asset legacy `Public/Images/` non modificati. Nessun ordine reale creato, nessun gateway reale avviato e nessuna email live inviata.
- `LOGIN-PASSWORD-TOGGLE-1A` chiuso: PR #184 mergeata e smoke manuale A su `login.aspx`; il toggle custom resta l'unico controllo visibile e il reveal nativo browser e nascosto in modo mirato. `login.aspx.vb`, logica auth, sessione/cookie, registrazione/reset/remind, DB/schema/SP, checkout/carrello/ordine/gateway ed email/template restano invariati.
- `AUTH-LEGACY-DUPLICATE-AUDIT-FIX-1A` / PR #187 su branch `task/auth-legacy-duplicate-audit-fix-1a`, commit funzionale `52d9fd15e1fd1796f45e335542670d84736378ed`, completa audit mirato di `login.aspx`, `registrazione.aspx`, `remind.aspx` e `resetpassword.aspx`: nessuna doppia form login, registrazione, remind o reset rilevata. `login.aspx` conserva un solo toggle custom gia stabilizzato; `resetpassword.aspx` aveva toggle custom sui due campi nuova/conferma password senza nascondere il reveal nativo browser. Fix applicato solo in CSS inline di `resetpassword.aspx`: `::-ms-reveal` e `::-ms-clear` nascosti in modo mirato su `tbPasswordNuova` e `tbPasswordConferma`. Nessun cambio a code-behind, login/auth server-side, sessioni/cookie, logica registrazione, reset token, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali o asset legacy `Public/Images/`. Prossimo step: review/merge PR #187 e smoke manuale UI login/reset senza utenti live o email live.
- `RESET-PASSWORD-TOKEN-GUARD-1A` / PR #188 su branch `task/reset-password-token-guard-1a`, commit funzionale `748a23e1102677ca1395795bdca18955c059af91`, corregge la `NullReferenceException` in `resetpassword.aspx` quando il parametro `token` e mancante, vuoto o non valido. Causa: `CurrentToken()` chiamava `.Trim()` su `Request.QueryString("token")` potenzialmente `Nothing`; il fix rende `CurrentToken()` null-safe e fa gestire a `LoadResetState()` token assenti/vuoti con pannello controllato e messaggio generico non tecnico. Restano invariati generazione, validazione, scadenza, storage e consumo token, hashing/password algorithm, login/auth, sessioni/cookie, registrazione, remind generation, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali. Prossimo step: review/merge PR #188 e smoke manuale reset password con token assente, vuoto, invalido e valido test.
- Blocco reset password token guard chiuso con `SMOKE RESET TOKEN: A`: PR #187 mergeata per fix UI reveal/toggle password reset e PR #188 mergeata per guard null-safe su `resetpassword.CurrentToken()`. Verificati manualmente `resetpassword.aspx`, `resetpassword.aspx?token=` e token non valido senza errore server, stack trace o dettagli tecnici; il messaggio resta controllato e il form reset non e utilizzabile senza token valido. Login/auth/sessioni/cookie, registrazione/remind/generazione token, reset token validation/consume, `PasswordResetTokenService.vb`, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali restano invariati; nessun debug abilitato e nessun asset legacy `Public/Images/` introdotto. Il path legacy preesistente `Public/Images/` in `registrazione.aspx` resta backlog separato.
- `REGISTRATION-LEGACY-ASSET-PATH-1A` / PR #189 su branch `task/registration-legacy-asset-path-1a`, commit funzionale `65645745cd5c3789e2d2b90623af2a60e0b827ac`, rimuove l'unico path legacy immagine in `registrazione.aspx`: `Public/Images/loghi_agevolazione.jpg`, non presente nel repository e fuori dallo schema asset KeepStore 3.0. REV1: il fallback generico `/Public/assets/images/placeholder.svg` e stato rifiutato perche degradava la UI; il path finale usa l'asset reale e coerente `/Public/assets/images/coupon/Struttura/sconto_50px.png`. Restano invariati form registrazione, controlli server, ID, eventi, validatori, code-behind, login/auth/sessioni/cookie, salvataggi, email/password, reset/remind/token, DB/schema/SP, carrello/ordine/gateway/prezzi/totali. Prossimo step: review/merge PR #189 e smoke manuale registrazione UI senza utenti live o email live.
- Blocco `REGISTRATION-LEGACY-ASSET-PATH` chiuso con `SMOKE REGISTRATION UI: A`: PR #189 mergeata, REV1 applicata e validata manualmente. La pagina registrazione apre senza errori; il blocco "LISTINI AGEVOLATI" non mostra placeholder o immagine mancante, l'icona sconto `/Public/assets/images/coupon/Struttura/sconto_50px.png` e visibile e coerente, la form registrazione resta normale. Nessun utente reale creato, nessuna email live inviata; logica registrazione/auth/sessioni/email/DB, reset/remind/token, carrello/ordine/gateway/prezzi/totali e asset legacy `Public/Images/` restano invariati/non introdotti.
- `LEGACY-ASSET-PATH-AUDIT-FIX-1A` / PR #190 su branch `task/legacy-asset-path-audit-fix-1a`, commit funzionale `8aad9f697aa0f5161c22eb59552df25da2aebda0`: audit mirato dei riferimenti runtime `Public/Images/` in `.aspx`, `.ascx`, `.master`, CSS e JS. Fix applicato solo al caso semplice e decorativo `coupon_esito_acquisto.aspx`, dove `Public/Images/servizio_clienti.jpg` e stato sostituito con l'asset esistente `/Public/assets/images/headphone-2.svg`. Backlog non corretto per assenza di equivalente moderno certo o per rischio funzionale: `carrello.aspx` (`Ok.png`, `Remove.png`, `interrogativo.png`, commento `StepCarrello1.png`), `coupon_dettagli.aspx` (`Acquistati.png`, `Visite.png`), `coupon_utente.aspx` (`Pagato.png`, `Paga_Ora.png`), `articolix.aspx` (`WhatsApp-Symbolo.png`, `spazio_vuoto.gif`, `selection.gif`, `aggiungiMultiplo.png`), `documenti.aspx` (`close_pop.png`, `Ok.png`, `calendar_icon.gif`), `promo_in_scadenza.aspx` (`angolo.png`, `promoSpGratis.png`, `angolo_x.png`), `wishlist.aspx` (`aggiungiMultiplo.png`) e `rettificaMagazzino.aspx` (`back.jpg`, `bollinoPromoVetrina.png`, `selection.gif`, `aggiungiMultiplo.png`). Nessun cambio a DB/schema/SP, auth/sessioni/cookie, registrazione/reset/remind/token, email/template, carrello/ordine/gateway/prezzi/totali; prossimo step review/merge PR #190.
- `CART-DISCOUNT-LEGACY-ICONS-1A` / PR #192 su branch `task/cart-discount-legacy-icons-1a`, commit funzionale `a5876359a9ed23b5f479ac824ecf693b16c1b1f2`, sostituisce solo le due icone legacy del feedback buono sconto in `carrello.aspx`: `Public/Images/Ok.png` -> `/Public/assets/images/ico/modalok.svg` e `Public/Images/Remove.png` -> `/Public/assets/images/ico/modalno.svg`. Restano fuori scope e invariati `Public/Images/interrogativo.png` e il commento legacy `Public/Images/StepCarrello1.png`; PR #191 e tutti i file coupon non toccati. Nessun cambio a logica carrello/buoni sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP o auth/sessioni/cookie. Prossimo step: review/merge PR #192 e smoke carrello/buono sconto se disponibile.
- `CART-DISCOUNT-FIELD-UX-1A` / PR #193 su branch `task/cart-discount-field-ux-1a`, commit funzionale `376898aea8c483e2087442cad43aca08dfd7d335`, corregge la leggibilita del campo buono sconto dopo smoke manuale post-PR #192: il pannello in `carrello.aspx` ora espone titolo `Hai un codice sconto?`, microcopy, placeholder `Inserisci codice sconto`, bottone `Applica` e layout responsive coerente con i riferimenti ONSUS `shop-cart.html` e `checkout.html`. I controlli server, ID, postback e feedback OK/KO restano preservati con `/Public/assets/images/ico/modalok.svg` e `/Public/assets/images/ico/modalno.svg`; PR #191/coupon non toccata. Nessun cambio a logica buoni sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP o auth/sessioni/cookie. Prossimo step: review/merge PR #193 e smoke manuale desktop/mobile su carrello e buono sconto.
- `CART-CHECKOUT-UX-SMOKE-FIX-1A` / PR #194 su branch `task/cart-checkout-ux-smoke-fix-1a`, commit funzionale `715bcbf6882f51c90200a9d12a451283ab249091`, nasce da smoke reale `SMOKE CART DISCOUNT UX: B` post-PR #193: coupon non visibile, pulsanti scuri poco leggibili e step spedizione/checkout troppo compresso. Causa tecnica: `cart-ui.css` non era caricato da `carrello.aspx` e il CSS ONSUS globale rendeva il bottone `.ip-discount-code .tf-btn` assoluto; quindi le regole cart-specific di PR #193 non arrivavano al runtime. Fix applicato solo a UI: link a `cart-ui.css` nella pagina carrello, bottone coupon riportato a layout flex normale, contrasto bottoni carrello e spacing checkout/section grid migliorati secondo `shop-cart.html` e `checkout.html`. PR #191/coupon non toccati; nessun cambio a logica carrello/sconto, prezzi/IVA/totali/righe, ordine/gateway/email/DB/schema/SP/auth/sessioni. Prossimo step: review/merge PR #194 e nuovo smoke manuale desktop/mobile senza inviare ordine.
- REV1 `CART-CHECKOUT-UX-SMOKE-FIX-1C` su PR #194, commit funzionale `f19e9ae6f643ca92b5ceaad8c48410e6da304e91`, riordina realmente carrello, checkout e conferma dopo nuovo smoke B: titolo step dinamico (`Il tuo carrello`, `Spedizione e checkout`, `Conferma ordine`), layout carrello con coupon e riepilogo stabile a destra, bottoni secondari leggibili, sidebar checkout stile ONSUS applicata fuori dallo scope `.s-shoping-cart`, stato codice sconto non interattivo in checkout e conferma finale con sola CTA primaria `Invia ordine con obbligo di pagamento`. Nessun cambio a code-behind, logica sconto, prezzi/IVA/totali/righe, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie o PR #191/coupon. Prossimo step: smoke manuale desktop/mobile PR #194 aggiornato.
- REV2 `CART-CHECKOUT-UX-SMOKE-FIX-1D` su PR #194, commit funzionale `1734e1ef8d5c2a78d87db6cf71b1bdf32176308d`, chiude il nuovo smoke B reale sui tre step: il blocco `CartActionsWrap` con `Panel_BuoniSconto` era ancora dentro `CartItemsWrap`, che il code-behind nasconde negli step checkout/conferma; ora il pannello sconto/riepilogo/azioni e fratello del wrapper prodotti, quindi lo stesso controllo server coupon resta unico e visibile anche nello step checkout. CSS REV2 scoped a `.ks-cart-page`: step 1 prodotti + coupon + riepilogo + azioni; step 2 mostra coupon inseribile/validabile e nasconde riepilogo/azioni carrello duplicati; step 3 nasconde il support panel e conserva solo la CTA finale `Invia ordine con obbligo di pagamento`. Cache bust `cart-ui.css` aggiornato. Nessun cambio a code-behind, ID/eventi/validatori, logica sconto, prezzi/IVA/totali/righe, spedizione/pagamento, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie; PR #191/coupon resta sospesa e non toccata. Prossimo step: smoke manuale desktop/mobile PR #194 REV2 senza inviare ordine.
- REV3 `CART-CHECKOUT-UX-SMOKE-FIX-1E` su PR #194, commit funzionale `4ef5407b9871a0d18ad29b1bac00d74da5b4c28b`, rifinisce definitivamente lo smoke B REV2: font minimi allineati a ONSUS, card con padding 20-28px, step 1 con coupon + riepilogo importi + azioni dentro container, step 2 con coupon ancora inseribile/validabile, box indirizzo piu compatto e riepilogo prodotti con miniatura/nome/qta/prezzo, step 3 gerarchia finale con sola CTA primaria `Invia ordine con obbligo di pagamento`. La modifica resta limitata a `carrello.aspx` per cache bust e `cart-ui.css`; nessun cambio a controlli server, ID/eventi/validatori, code-behind, logica sconto, prezzi/IVA/totali/righe, checkout business logic, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie. PR #191 e tutti i file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale desktop/mobile PR #194 REV3 senza inviare ordine.
- REV4 `CART-CHECKOUT-UX-SMOKE-FIX-1F` su PR #194, commit funzionale `32308a1eb5caebada8fcf7e5e38475514d13e31b`, corregge i tre problemi reali dello smoke REV3: doppio incremento quantita causato da due handler JS attivi (`cart-ui.js` + `checkout-ui.js`), coupon step 2 non percepibile perche rimasto nel support panel fuori dal contenuto checkout, lista indirizzi generata in chiaro dal vecchio enhancer JS. Fix chirurgico: `cart-ui.js` lascia gli stepper carrello `.ks-wg-quantity` al solo handler `checkout-ui.js`, `checkout-ui.js` sposta l'unico `CartActionsWrap` nello slot visibile `CheckoutCouponSlot` dello step 2 senza duplicare controlli server, e disabilita la lista card indirizzi mantenendo la select compatta `LstScegliIndirizzo`. Nessun cambio a controlli server, ID/eventi/validatori, code-behind, logica sconto/indirizzi, prezzi/IVA/totali/righe, checkout business logic, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale PR #194 REV4 su +/-, coupon step 2 e indirizzi compatti senza inviare ordine.
- REV5 `CART-CHECKOUT-UX-SMOKE-FIX-1G` su PR #194, commit funzionale `b2681ee51c008fa078ef55206948d31cf52efa33`, corregge la causa reale del coupon ancora assente nello step 2: `Panel_BuoniSconto.Visible` dipendeva da `TableConteggi.Visible`, quindi quando il riepilogo conteggi non era renderizzato il pannello con `TB_BuonoSconto`, `BT_ApplicaBuonoSconto` e feedback non arrivava proprio nell'HTML. La visibilita dell'input sconto e ora separata dal riepilogo conteggi: viene mostrato se i buoni sono abilitati, il carrello ha articoli e lo step corrente non e conferma; lo step 3 resta senza input sconto. Nessun cambio a `TB_BuonoSconto_TextChanged`, eventi/ID, sessioni sconto, calcoli sconto, prezzi/IVA/totali/righe, indirizzi, quantita REV4, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale PR #194 REV5 su step 1/2/3 coupon senza inviare ordine.
- REV6/FINAL `CART-CHECKOUT-UX-FINAL-ALIGN-1A` su PR #194, commit funzionale `bd4ee5ed5e0895ac32560aca1f9caa68cd6ae0a7`, riallinea il carrello al modello ONSUS verificato su `shop-cart.html` e `checkout.html`: step 1 focalizzato su prodotti, quantita, prezzi e totale articoli/subtotale prodotti, senza input coupon o costi checkout anticipati; step 2 con l'unico pannello coupon reale (`TB_BuonoSconto`, `BT_ApplicaBuonoSconto`, feedback) spostato nello slot checkout; step 3 senza coupon e senza CTA `Procedi con l'ordine`, lasciando la CTA finale `Invia ordine con obbligo di pagamento`. La visibilita server del pannello sconto ora richiede lo step checkout e non conferma. Corretto anche il blocco runtime post-`Applica`: gli helper SEO di `carrello.aspx.vb` non aggiungono piu controlli a `Header.Controls` quando il `<head>` contiene blocchi inline, evitando l'errore "Impossibile modificare la raccolta Controls". Nessun cambio a calcoli sconto, prezzi/IVA/totali/righe, indirizzi, quantita REV4, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale finale PR #194 sui tre step e click `Applica`, senza inviare ordine.
- REV7 `CART-CHECKOUT-ORDER-FINAL-UX-1A` su PR #194, commit funzionale `97b19096cb88a996b91b65827cf45e9f3cfe22f2`, chiude l'allineamento UI dopo smoke `SMOKE CART CHECKOUT FINAL: B`: step 1 resta focalizzato su prodotti, quantita, prezzi e totale articoli; nello step 2 il pannello coupon reale viene collocato dopo `Pagamento` e prima di `Dati fatturazione`, con titolo `Codice sconto`, microcopy dedicata, input `TB_BuonoSconto`, bottone `Applica` e feedback OK/KO stilato; la sidebar mostra solo lo stato del codice. `Dati fatturazione` e piu compatto e i font checkout/carrello sono leggermente aumentati. `ordine.aspx` diventa pagina post-submit leggibile e stampabile per ordini non-gateway: hero `Ordine inviato`, numero/data/stato, azioni stampa/area cliente/continua acquisti, riepilogo cliente, indirizzi, metodo, righe prodotti, totali, prossimi passi e CSS print. Redirect gateway/coupon esistenti preservati; nessun cambio a calcoli sconto, prezzi/IVA/totali/righe, spedizione, pagamento, gateway, email/template, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Runtime live non eseguito: prossimo step smoke manuale finale PR #194 senza creare ordine reale, gateway o email.
- REV8 `CART-CHECKOUT-ORDER-FINAL-UX-1B` su PR #194, commit funzionale `31ea74597b58951523bd265e6d4e545dff82f9b6`, corregge l'unico residuo dello smoke `SMOKE CART CHECKOUT ORDER REV7: B`: dopo cambio step il browser restava in basso per ripristino scroll WebForms (`MaintainScrollPositionOnPostBack=True`). Fix solo client in `checkout-ui.js`: i click sui controlli di transizione step registrano lo step atteso in `sessionStorage`; al nuovo rendering, se lo step e cambiato, la viewport viene riportata in alto su `.ks-cart-page`/`.checkout-status` con scroll immediato. Azioni minori nello stesso step, come coupon, quantita e cambio spedizione/pagamento, non vengono marcate come transizione. Layout step 1/2/3, posizione coupon, ricevuta ordine stampabile, sconti, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie restano invariati. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale finale REV8 sui passaggi step senza inviare ordine.
- REV9 `CART-CHECKOUT-ORDER-FINAL-UX-1C` su PR #194, commit funzionale `1866451e5db60a066cc2441583ff68315be61fe4`, corregge i residui dello smoke `SMOKE CART CHECKOUT REV8: B`: coupon ghost nello step 1, informazioni coupon duplicate nello step 2, scroll ancora instabile verso conferma e CTA mobile troppo anticipata. Causa: `GV_BuoniSconti` era fratello del pannello coupon reale e restava renderizzato fuori card quando `Panel_BuoniSconto` veniva spostato; la sidebar checkout aveva anche un box separato `Codice sconto`. Fix: il GridView descrittivo del buono ora vive dentro `Panel_BuoniSconto`, il box coupon sidebar viene rimosso lasciando solo la riga economica `Sconto`, lo scroll step usa piu tentativi postback, e su mobile la stessa area azioni finale viene spostata dopo il riepilogo ordine tramite slot dedicato senza duplicare `btInviaOrdine`. Nessun cambio a logica sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale finale REV9 senza inviare ordine.
- REV10 `CART-CHECKOUT-ORDER-FINAL-UX-1D` su PR #194, commit funzionale `e2e028dc171f8508cc0609b45677258fbe3f23d8`, corregge il residuo dello smoke `SMOKE CART CHECKOUT REV9: B`: su mobile nello step `Conferma` il modulo CTA finale veniva sovrapposto dal riepilogo ordine. Causa: il wrapper checkout restava un flex row custom anche sotto breakpoint mobile, mentre lo slot mobile della CTA era un flex item dopo la sidebar. Fix solo CSS mobile: `tf-checkout-wrap`, contenuto checkout, sidebar, riepilogo e slot CTA vengono forzati nel normale flow verticale, con larghezza 100%, `position: static`, `clear: both`, margini adeguati e puntamento attivo; lo stesso `btInviaOrdine` resta unico e viene solo spostato dallo script REV9. Desktop, step 1/2, coupon, scroll, ricevuta ordine, logica sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie restano invariati. Prossimo step: smoke manuale mobile REV10 senza inviare ordine.
- REV11 `ORDER-RECEIPT-POLISH-1A` su PR #194, commit funzionale `41994ea64063b33beb533fe030c5572a86816505`, rifinisce `ordine.aspx` dopo conferma utente che carrello/checkout REV10 funzionano: bottoni ricevuta riallineati al brand ONSUS/Taikun, bottone `Stampa ordine` primario rosso, azioni secondarie outline/light, layout web della ricevuta piu ordinato e intestazione aziendale stampabile in cima al documento. I dati azienda arrivano da `LoadOrderEmailBrandData(conn)` / tabella `Aziende` con fallback sessione gia esistente; il logo usa `Aziende.LogoWeb` tramite helper `KeepStoreEmailLogo` su `/Public/assets/images/logo/{LogoWeb}`. CSS print nasconde header/menu/footer/newsletter/bottoni e mantiene logo, dati azienda, riferimento ordine, articoli, indirizzi, metodo, importi e assistenza. Nessun cambio a creazione ordine, calcoli, prezzi/IVA/totali/righe, spedizione, pagamento, gateway, email/template, DB/schema/SP, auth/sessioni/cookie, carrello/checkout o PR #191/coupon. Prossimo step: smoke manuale `ordine.aspx` web + stampa/anteprima senza creare nuovo ordine, gateway o email.
- REV12 `CART-EMPTY-STATE-CLEANUP-1A` su PR #194, commit funzionale `1795dab6603fb2048810a02dd1e7c15f8cd45455`, parte da `SMOKE ORDER RECEIPT REV11: A` confermato dall'utente e non tocca piu `ordine.aspx`. Risolve il duplicato/stato legacy del carrello vuoto standardizzando `CartEmptyPanel` come unica card moderna: classe pagina `ks-cart-is-empty`, bottoni `Sfoglia il catalogo` primario brand e `Torna alla home` secondario, CSS responsive scoped e guard UI server-side su `CartItemsWrap`, `CartActionsWrap`, `CartSummaryColumn`, coupon e checkout quando `numero = 0`. Carrello pieno, step 1/2/3, coupon step 2, mobile CTA conferma, scroll step, quantita, indirizzi, prezzi/IVA/totali/righe, ordine/gateway/email/template, DB/schema/SP, auth/sessioni/cookie e PR #191/coupon restano invariati. Prossimo step: smoke manuale carrello vuoto desktop/mobile e regressione carrello pieno senza inviare ordine.
- REV13 `CART-EMPTY-STATE-CLEANUP-1B` su PR #194, commit funzionale `417497d5d6a844c5e9abc33c1c20eaae1efca07d`, corregge il residuo di `SMOKE CART EMPTY REV12: B`: sopra la card moderna restavano il conteggio `0 articoli nel carrello` e la nota prezzi, cioe informazione legacy fuori layout. Il code-behind nasconde `lblArticoli`, `lblPresenti` e `lblPrezzi` quando `numero = 0` e li ripristina a carrello pieno; il CSS scoped `.ks-cart-page.ks-cart-is-empty` impedisce la ricomparsa del blocco heading/meta empty fuori card. La card moderna resta l'unica comunicazione di carrello vuoto; bottoni, desktop/mobile, carrello pieno, step 1/2/3, mobile CTA, `ordine.aspx` REV11, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie e PR #191/coupon restano invariati. Prossimo step: smoke manuale carrello vuoto REV13 e regressione carrello pieno.
- REV14 `CART-EMPTY-STATE-CLEANUP-1C` su PR #194, commit funzionale `faace786eb4810a49e1d616c0171f1eebac4ffff`, corregge il residuo di `SMOKE CART EMPTY REV13: B`: il titolo esterno statico `Il tuo carrello` dentro `.heading-section` restava visibile sopra la card moderna. Fix solo CSS scoped: `.ks-cart-page.ks-cart-is-empty .heading-section { display: none; }`, con cache bust REV14. A carrello pieno il titolo resta preservato; a carrello vuoto rimangono solo stepper e card moderna. Nessun cambio a logica carrello, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie, `ordine.aspx` REV11 o PR #191/coupon. Prossimo step: smoke manuale carrello vuoto REV14 e regressione carrello pieno.
- REV15 `CART-COUPON-APPLY-STATE-1A` su PR #194, commit funzionale `35e4abacce2e3b248978b7d78257bc50171bd6e3`, disabilita lo stesso bottone `BT_ApplicaBuonoSconto` quando `Session("BuonoSconto_id")` indica un coupon gia applicato e lo riabilita dopo `Elimina codice`/rimozione coupon. Causa: il lock UI indirizzi poteva rieseguire lo stato dei controlli e lasciare `Applica` attivo dopo postback pur con buono valido. Fix solo UI server-side con `SyncCouponUiState()` e CSS disabled scoped: nessun nuovo bottone, nessuna duplicazione controlli, nessun cambio a verifica coupon, calcoli sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon dedicati restano sospesi/non toccati. Prossimo step: smoke manuale REV15 su applica/elimina codice senza inviare ordine.
- `CART-RECENTLY-VIEWED-1A` su branch `task/cart-recently-viewed-1a`, commit funzionale `c0e8cbeaf697805426f993ce3fd67028fc391bb6`, aggiunge in `carrello.aspx` un blocco ONSUS-style `Visti di recente` / consigliati sotto carrello e checkout, escluso dallo step `Conferma`. La fonte e il tracking reale gia esistente `ks_recent*` di scheda prodotto/home; se non ci sono dati recenti validi il blocco resta nascosto, senza prodotti statici ONSUS o immagini demo. La query usa solo prodotti reali disponibili da `vsuperarticoli`, massimo 8, esclude gli articoli gia nel carrello e propone solo CTA `Vedi prodotto` verso scheda articolo, senza add-to-cart diretto. Nessun cambio a `ordine.aspx`, gateway, email/template, auth/sessioni/cookie, DB/schema/SP, prezzi/IVA/totali/righe/spedizione/pagamento o PR #191/coupon; PR #194 non viene riaperta. Prossimo step: review/merge nuova PR e smoke manuale utente su carrello, checkout e conferma senza creare ordine.
- REV2 `CART-RECENTLY-VIEWED-1B` su PR #195, commit funzionale `fbbb184d4e670c2ba869f7e09eee973c36972d4c`, nasce dallo smoke utente `SMOKE CART RECENTLY PR195: B`: il modulo non compariva in step 1/2 perche REV1 mostrava solo recenti reali e restava nascosta quando `ks_recent*` era vuoto, non leggibile, tutto escluso perche gia in carrello o senza prodotti validi. La pipeline ora e: prima recenti reali con titolo `Visti di recente`; se non producono item, fallback reale `Potrebbe interessarti anche` basato sugli articoli nel carrello, con categoria/tipologia/marca/settore da `vsuperarticoli`, massimo 8, esclusione prodotti gia nel carrello, immagini helper moderne e CTA solo `Vedi prodotto`. Se neppure il fallback trova prodotti reali il modulo resta nascosto senza statici/demo. Step 1 e step 2 mostrano il blocco se ci sono item; step `Conferma` resta senza raccomandazioni. Nessun cambio a `ordine.aspx`, gateway, email/template, auth/sessioni/cookie, DB/schema/SP, prezzi/IVA/totali/righe/spedizione/pagamento o PR #191/coupon; PR #194 non viene riaperta. Prossimo step: review/merge PR #195 aggiornata e smoke manuale su recenti/fallback senza creare ordine.
- Regola ecommerce permanente: il carrello e il checkout vanno valutati anche come superfici commerciali, non solo grafiche. Futuri micro-task potranno aggiungere correlati, accessori, cross-sell, upsell, bundle e raccomandazioni piu intelligenti, ma sempre da dati reali, con esclusione prodotti gia in carrello, senza dati statici demo e senza alterare calcoli/gateway. SEO/AI search e Google/AI discovery richiedono dati prodotto leggibili, URL canonici e in futuro structured data dedicati, da trattare in task separati.
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

1. Scegliere il prossimo blocco operativo su `frontend-rebuild` pulito.
2. Possibili candidati:
   - EMAIL-ORDER-CONFIRMATION-1A: prossimo blocco consigliato dopo `EMAIL-ENGINE-1A`; migrare la conferma ordine standard con varianti pagamento senza toccare gateway, costi o totali.
   - EMAIL-BANKTRANSFER-1A: istruzioni bonifico dedicate, solo dopo conferma fonti coordinate bancarie.
   - EMAIL-COD-1A: microcopy contrassegno/contanti, senza modificare pagamento reale.
   - ORDER-CONFIRMATION-UX smoke live: verificare la nuova UX post-ordine, senza pagamento reale.
   - AUDIT-FINALE-CHECKOUT-PAGAMENTI-1A: audit separato di checkout/pagamenti/gateway, senza confonderlo con UI carrello.
   - Prossima pagina o area scelta da Germano su branch dedicato.
   - PASSWORD-HASH-SCHEMA-2B / PASSWORD-HASH-MIGRATION-2C: futuro task hash password; hash password non ancora implementato.
   - GESTIONALE-PASSWORD-AUDIT-1A / JANUS-PASSWORD-RESET-1A: audit gestionale Janus per reset/hash.
   - REGISTRATION-POLICY-1A / REGISTRATION-UX-1A: refinement residuo login/registrazione.
   - PR #171 diagnostica sessione/logout post-ordine: non attiva ora; riprendere solo se il problema torna riproducibile con test manuale mirato.
3. Mantenere PayPal, BancaSella, gateway e pagamenti in task separati dal carrello UI.
4. Revocare/cambiare la password dell'utente MySQL temporaneo usato nello smoke, se ancora attivo.
5. Eliminare eventuali variabili ambiente temporanee di smoke.
6. Eliminare o lasciare scadere eventuali link reset test residui.
7. AUTH-CSRF-AUDIT-1A: audit `AntiCsrfPage` sui flussi auth.
8. AUTH-JS-LEGACY-AUDIT-1A: audit errori JS legacy residui.
9. DATIUTENTE-LEGACY-AUDIT-1A per errore generico, tab/JS legacy e salvataggi/destinazioni.

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
