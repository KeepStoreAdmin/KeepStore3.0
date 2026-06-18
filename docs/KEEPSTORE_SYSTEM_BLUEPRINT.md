# KeepStore System Blueprint

Documento tecnico permanente del progetto KeepStore 3.0.

## 1. Frontespizio tecnico

| Campo | Valore |
| --- | --- |
| Nome documento | `KEEPSTORE_SYSTEM_BLUEPRINT.md` |
| Progetto | KeepStore 3.0 |
| Repository | `KeepStoreAdmin/KeepStore3.0` |
| Branch stabile di riferimento | `frontend-rebuild` |
| HEAD iniziale | `9ee45ed5fb8f08b79bad29519d42d0c6d0958668` |
| Data creazione | 2026-06-05 |
| Documento operativo correlato | `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md` |

Scopo del documento: raccogliere la conoscenza tecnica stabile su architettura, pagine, componenti, flussi, dati, funzionalita ecommerce, debito tecnico e storico evolutivo di KeepStore 3.0.

Relazione con il masterplan: il masterplan resta il riferimento operativo per task, priorita, merge, smoke e stato avanzamento. Questo blueprint e il riferimento architetturale/funzionale, pensato per programmatori, manutentori, IA e responsabili tecnici/gestionali.

## 2. Regole di manutenzione del blueprint

- Aggiornare il blueprint quando vengono aggiunte, rimosse o modificate funzionalita rilevanti.
- Distinguere sempre tra architettura stabile, debito tecnico e storico modifiche.
- Non duplicare inutilmente il masterplan: qui vanno conoscenza tecnica stabile e mappe funzionali.
- Non inserire segreti, token, password, hash, cookie, session id, connection string, dati personali o transaction id completi.
- Usare riferimenti tecnici sanificati e, quando necessario, valori mascherati.
- Mantenere sezioni leggibili sia da persone sia da IA.
- Aggiornare l'indice quando si aggiungono sezioni principali.
- Usare date, task-id, PR e commit quando disponibili.
- Se una informazione non e ancora verificata, marcarla come "da completare con audit dedicato".

### 2.1 Metodo operativo Codex Token-Safe / One-Shot

- Il lavoro Codex deve partire da prompt unici e consolidati: branch, HEAD atteso, file ammessi, divieti, verifiche, output sintetico e criterio A/B/E devono essere gia definiti da ChatGPT.
- Evitare cicli esplorativi e task generici quando il problema e chiaro; Codex e esecutore di micro-task verificabili, non consulente continuo.
- Non creare loop documentali: un documento registra commit funzionale principale, PR, branch, stato, smoke e decisioni; il commit documentale che chiude una REV non deve essere richiesto come prerequisito di una nuova REV automatica.
- Prima di aprire PR diagnostiche su problemi sospetti, fare test manuale mirato. Se il problema non e riproducibile, resta backlog non attivo.
- Cleanup branch e housekeeping si fanno solo se richiesti o se sbloccano il lavoro; prima di cancellare branch verificare che non esistano commit assenti da `frontend-rebuild`.
- Priorita operativa: bug bloccanti e regressioni utente, smoke, documentazione minima, poi cleanup. Non consumare token su attivita non funzionali se ci sono blocchi piu importanti.
- Esempio corrente: checkout note ordine + consenso condizioni chiuso e validato live; PR #171 sessione/logout post-ordine resta backlog non attivo perche il test manuale ha dato esito A e il problema non e riproducibile ora.

## 3. Indice

- [1. Frontespizio tecnico](#1-frontespizio-tecnico)
- [2. Regole di manutenzione del blueprint](#2-regole-di-manutenzione-del-blueprint)
- [3. Indice](#3-indice)
- [4. Executive summary tecnico](#4-executive-summary-tecnico)
- [5. Architettura generale](#5-architettura-generale)
- [6. Struttura cartelle](#6-struttura-cartelle)
- [7. Mappa pagine ASPX](#7-mappa-pagine-aspx)
- [8. Componenti, controlli e moduli](#8-componenti-controlli-e-moduli)
- [9. Flussi logici principali](#9-flussi-logici-principali)
- [10. Database e tabelle](#10-database-e-tabelle)
- [11. Database fisici, backup e ruolo multi-azienda](#11-database-fisici-backup-e-ruolo-multi-azienda)
- [12. Funzionalita ecommerce](#12-funzionalita-ecommerce)
- [13. Area account - stato consolidato](#13-area-account---stato-consolidato)
- [14. Login, registrazione e recupero password - audit LOGIN-REGISTER-1A](#14-login-registrazione-e-recupero-password---audit-login-register-1a)
- [15. Sistema email transazionali](#15-sistema-email-transazionali)
- [16. Registro modifiche tecniche](#16-registro-modifiche-tecniche)
- [17. Debito tecnico e backlog architetturale](#17-debito-tecnico-e-backlog-architetturale)
- [18. Sezione brochure sintetica](#18-sezione-brochure-sintetica)
- [19. Glossario](#19-glossario)
- [20. Regole per aggiornamenti futuri](#20-regole-per-aggiornamenti-futuri)

## 4. Executive summary tecnico

KeepStore 3.0 e una piattaforma ecommerce ASP.NET WebForms / VB.NET con database MySQL, integrata con logiche gestionali KeepStore e con template grafico ONSUS come riferimento per il refactoring UI moderno.

L'obiettivo ecommerce comprende catalogo prodotti, ricerca, schede prodotto, carrello, checkout, documenti/ordini, area cliente, wishlist, coupon, email/notifiche e integrazioni di pagamento. La base tecnologica e legacy ma in progressiva stabilizzazione tramite micro-task controllati su branch `frontend-rebuild`.

Lo stato generale del refactoring e avanzato soprattutto sull'area account:

- dashboard account stabilizzata;
- profilo account stabilizzato;
- indirizzi account portati a vista read-only ONSUS;
- wishlist stabilizzata;
- documenti/ordini stabilizzati con AccountSidebar globale e selector documenti dinamico;
- cambio password consolidato su `password.aspx`;
- `cambiapassword.aspx` ridotto a redirect legacy controllato.

La sicurezza password e stata consolidata nel flow account e LOGIN-REGISTER-SECURITY-1 ha ridotto i rischi immediati su login e registrazione senza schema change. Il reset password tokenizzato fase 1 e operativo in modalita legacy-compatible: email + Codice fiscale oppure Partita IVA, token monouso con `TokenHash`, scadenza 30 minuti, PRG su `remind.aspx`, UX `sent=1` chiara e redirect post-login sanificato. Hash/migrazione password e modernizzazione auth completa restano task separati.

## 5. Architettura generale

### 5.1 Tecnologia backend

- ASP.NET WebForms.
- Code-behind VB.NET.
- Controlli server WebForms, `SqlDataSource`, eventi server e master page.
- Librerie runtime in `Bin`, incluse dipendenze MySQL e componenti legacy.

### 5.2 Frontend/template

- Template ONSUS come riferimento visuale e UX per i refactor.
- Asset KeepStore in `Public/assets`.
- Controlli UI condivisi in `Public/ui/controls`.
- Alcune pagine legacy mantengono markup tabellare e script inline.

### 5.3 Master page

- `Page.master` e master page principale del frontend.
- `Page.master.vb` gestisce tema, dati azienda/sessione, tagging account shell, scadenza password, login legacy master, cart summary e vari helper.
- Il markup `Page.master` non va modificato senza task dedicato.

### 5.4 Controlli utente

- Controlli principali in `Public/ui/controls`.
- `AccountSidebar.ascx` e `AccountSidebar.ascx.vb` sono la navigazione account condivisa.
- `MiniCart.ascx`, `SiteHeader.ascx`, `SiteFooter.ascx`, controlli home e product card compongono parti UI pubbliche.

### 5.5 Gestione sessione

Session key account note:

- `LoginId`, `LoginID`;
- `LoginEmail`;
- `LoginNomeCognome`;
- `LoginUltimoAccesso`;
- `UtentiId`, `UtentiID`;
- `UtentiTipoId`;
- `DataPassword`;
- `ScadenzaPassword`;
- `Inserimento_User`, `Inserimento_Password`;
- `Login_User`, `Login_Password`.

Nota sicurezza: alcune session key legacy possono contenere dati sensibili o riferimenti a password nei flow registrazione/auto-login; non riportare mai valori reali.

Session timeout web standardizzato a 30 minuti: `web.config` dichiara `sessionState timeout="30"` e `carrello.aspx.vb` non deve abbassare il timeout del carrello sotto questo valore. Il flow carrello intercetta sessione scaduta e redirecta a login con messaggio non tecnico e `ReturnUrl` locale.

### 5.6 Gestione accessi

- Accesso account basato su sessione.
- Pagine account verificano `Session("LoginId")` o varianti legacy.
- `accessonegato.aspx` gestisce accesso negato.
- `logout.aspx` chiude sessione e pulisce dati di carrello collegati.
- Da completare con audit dedicato: session fixation, rigenerazione sessione, CSRF esteso e normalizzazione auth.

### 5.7 Database

- Database MySQL.
- Connection string e credenziali non devono essere riportate.
- Tabelle/view note: `login`, `vlogin`, `utenti`, `utentitipo`, `utentiindirizzi`, `utentirapporto`, `pagamentitipo`, `carrello`.
- Il modello fisico distingue tra database ecommerce cliente/azienda, registry citta/CAP e registry connessioni gestionale.
- Il nome del database cliente/azienda non e fisso: cambia in base al cliente/azienda che utilizza KeepStore.

### 5.8 Integrazioni esterne

- PayPal Express Checkout NVP classico.
- BancaSella legacy.
- Email SMTP configurata da dati azienda/sessione.
- Eventuali integrazioni Amazon/eBay/CheckVat presenti nel codice: da completare con audit dedicato.

### 5.9 Deployment/staging/live

- Ambiente smoke ricorrente: `https://www.taikun.it/`.
- Pubblicazione server gestita per file puntuali nei task smoke.
- Non modificare runtime, DB o configurazioni senza task esplicito.

### 5.10 Relazione con gestionale KeepStore

KeepStore web condivide dati e contratti con il gestionale. Le modifiche a DB, password, documenti, ordini, pagamento e indirizzi devono considerare compatibilita gestionale e richiedono audit dedicato.

Il gestionale KeepStore usa l'archivio `connessioni` come primo punto di verifica/indirizzamento. Se il controllo e positivo, il gestionale si collega al database cliente/azienda corretto. Sito e gestionale condividono almeno il database cliente/azienda e il registry citta/CAP. Ogni modifica a login, password, utenti, indirizzi, documenti o ordini puo avere impatto anche sul gestionale.

## 6. Struttura cartelle

| Percorso | Scopo | Note | Stato documentazione |
| --- | --- | --- | --- |
| root pagine ASPX | Pagine WebForms pubbliche, ecommerce e account | Include pagine legacy e refactor ONSUS | inizializzata |
| `App_Code` | Helper, moduli, repository e classi VB condivise | Include sicurezza, PayPal, catalogo, SEO | parziale |
| `App_Data` | Dati applicativi ASP.NET | Da audit dedicato | placeholder |
| `App_WebReferences` | Web references legacy | Include CheckVat | placeholder |
| `Bin` | DLL runtime | Dipendenze MySQL, zip, PDF, controlli | inizializzata |
| `Public` | Asset pubblici e UI moderna | Radice template/asset KeepStore | parziale |
| `Public/ui/controls` | User control condivisi | AccountSidebar, header, footer, product card, MiniCart | inizializzata |
| `Public/assets` | CSS/JS/img template KeepStore/ONSUS | Non modificare asset ONSUS originali senza task | parziale |
| `Public/ui/master` | Master UI pubbliche aggiuntive | Da audit dedicato | placeholder |
| `BancaSella` | Flow pagamento BancaSella | Gateway: non toccare senza task | placeholder |
| `Database Taikun` | Materiale DB/dump locale | Non modificare senza task DB | placeholder |
| `Doc` | Documenti legacy/progetto | Da audit dedicato | placeholder |
| `docs` | Documentazione tecnica operativa | Masterplan e blueprint | inizializzata |
| cartelle template/asset ONSUS | Asset e layout di riferimento ONSUS | Presenti sotto `Public`/asset collegati | parziale |

## 7. Mappa pagine ASPX

| Pagina | Code-behind | Scopo | Stato refactoring | Dati principali | Note |
| --- | --- | --- | --- | --- | --- |
| `Default.aspx` | `Default.aspx.vb` | Home pubblica | da completare con audit dedicato | catalogo/home/sessione | Home ecommerce |
| `articoli.aspx` | `articoli.aspx.vb` | Lista/catalogo prodotti | da completare con audit dedicato | articoli, settori, filtri | Catalogo legacy/modernizzato parziale |
| `articolo.aspx` | `articolo.aspx.vb` | Scheda prodotto | da completare con audit dedicato | prodotto, prezzo, disponibilita | Product detail |
| `carrello.aspx` | `carrello.aspx.vb` | Carrello | stabile UI/indirizzi/Conferma | `carrello`, sessione, login, `utentiindirizzi`, `city_registry` | Gateway/core checkout separati |
| `ordine.aspx` | `ordine.aspx.vb` | Checkout/ordine | da completare con audit dedicato | ordine, pagamento, spedizione | Perimetro sensibile |
| `pagamento.aspx` | `pagamento.aspx.vb` | Pagamento legacy | da completare con audit dedicato | documenti/pagamenti | Perimetro gateway |
| `paypalcheckout.aspx` | `paypalcheckout.aspx.vb` | PayPal Express launcher | stabilizzato lato PayPal | PayPal NVP, documenti | Non invocare senza task |
| `paypalreturn.aspx` | `paypalreturn.aspx.vb` | Return PayPal | stabilizzato lato PayPal | token, transaction state | Non invocare senza task |
| `paypalrecheck.aspx` | `paypalrecheck.aspx.vb` | Recheck pending PayPal | stabilizzato lato PayPal | `GetTransactionDetails` | Non invocare senza task |
| `documentidettaglio.aspx` | `documentidettaglio.aspx.vb` | Dettaglio documento/ordine e conferma post-acquisto | stabile ONSUS + UX conferma | documento, righe, pagamento | Pay Now solo se azione reale; gateway/totali separati |
| `documenti.aspx` | `documenti.aspx.vb` | Lista documenti/ordini | stabile ONSUS account | `sdsTipo`, documenti | Selector dinamico |
| `myaccount.aspx` | `myaccount.aspx.vb` | Dashboard account | stabile ONSUS | profilo, indirizzi, ordini recenti | AccountSidebar |
| `my-account-edit.aspx` | `my-account-edit.aspx.vb` | Profilo account | stabile ONSUS | login/utente/contatti | Salvataggi validati |
| `my-account-address.aspx` | `my-account-address.aspx.vb` | Indirizzi account | stabile ONSUS autonomo | indirizzo fatturazione/destinazioni | Add/edit sedi alternative e predefinito verificati |
| `wishlist.aspx` | `wishlist.aspx.vb` | Wishlist utente | stabile account | wishlist/prodotti | AccountSidebar globale |
| `password.aspx` | `password.aspx.vb` | Cambio password canonico | stabile account | `login.Password`, `DataPassword` | Hash non implementato |
| `cambiapassword.aspx` | `cambiapassword.aspx.vb` | Redirect legacy cambio password | stabile redirect | sessione login | Redirect verso `password.aspx` |
| `datiutente.aspx` | `datiutente.aspx.vb` | Dati utente legacy | legacy | profilo, indirizzi, destinazioni | Errore generico preesistente da audit |
| `login.aspx` | `login.aspx.vb` | Login | mitigato senza hash | `vlogin`, sessione | Messaggio generico, password legacy in chiaro/case-insensitive |
| `registrazione.aspx` | `registrazione.aspx.vb` | Registrazione | mitigata senza hash | `utenti`, `login`, SP legacy | Policy 8-25, no lowercase forzato, no password in email/sessione/URL |
| `registrazioneok.aspx` | `registrazioneok.aspx.vb` | Esito registrazione | mitigato | sessioni post-registrazione | Nessuna password in URL/UI |
| `remind.aspx` | `remind.aspx.vb` | Reset password tokenizzato | fase 1 operativa legacy-compatible | `vlogin`, `login_password_reset_tokens`, email | Email + CF/PIVA, PRG, sent=1 UX, token single-use, hash non implementato |
| `accessonegato.aspx` | `accessonegato.aspx.vb` | Accesso negato/sessione non autorizzata | pagina standard | sessione, `ReturnUrl` locale opzionale | Messaggio non tecnico, CTA login/home, no redirect automatico |
| `logout.aspx` | `logout.aspx.vb` | Logout | legacy semplice | sessione, carrello | Pulisce sessione/carrello |

## 8. Componenti, controlli e moduli

| Componente | Tipo | Scopo | Stato |
| --- | --- | --- | --- |
| `Page.master` | Master page markup | Shell principale frontend | stabile, non modificare senza task |
| `Page.master.vb` | Code-behind master | Theme/sessione/account shell/scadenza password/login legacy/cart | parziale, contiene debiti legacy |
| `AccountSidebar.ascx` | User control | Navigazione account condivisa | validata |
| `AccountSidebar.ascx.vb` | Code-behind controllo | Active/current dinamico, mapping legacy | validata |
| `AntiCsrfPage.vb` | Base page | Token anti-CSRF legato a ViewStateUserKey | esiste, non ereditata dalle auth pages audit |
| `KeepStoreSecurity.vb` | Helper sicurezza | Header/HTTPS helper | da completare con audit dedicato |
| `PayPalCheckoutConfig.vb` | Config PayPal | Config runtime DB PayPal Express | stabilizzato |
| `PayPalExpressClient.vb` | Client PayPal | NVP Express calls | stabilizzato |
| `PayPalExpressRepository.vb` | Repository PayPal | Lettura/scrittura stato PayPal | stabilizzato |
| `PayPalPaymentState.vb` | Stato pagamento | Mapping pagamento web | stabilizzato |
| `MiniCart.ascx` | User control | Mini carrello/header | da completare con audit dedicato |
| `SiteHeader.ascx` | User control | Header pubblico | da completare con audit dedicato |
| `SiteFooter.ascx` | User control | Footer pubblico | da completare con audit dedicato |
| `ProductCard.ascx` | User control | Card prodotto | da completare con audit dedicato |
| `ProductDetailView.ascx` | User control | Vista dettaglio prodotto | da completare con audit dedicato |

## 9. Flussi logici principali

### 9.1 Navigazione pubblica

Da completare con audit dedicato. Include home, header, menu catalogo, ricerca, breadcrumb e footer.

### 9.2 Catalogo prodotti

Da completare con audit dedicato. Pagine principali note: `articoli.aspx`, `articolo.aspx`, controlli product card e menu categorie.

### 9.3 Scheda prodotto

Da completare con audit dedicato. Coinvolge disponibilita, prezzo, add-to-cart, immagini e informazioni prodotto.

### 9.4 Carrello

`carrello.aspx` e modernizzato sul layout ONSUS per UI carrello, scelta indirizzo, add/edit indirizzi alternativi inline e step finale `Conferma`. Gli indirizzi inline restano collegati a `utentiindirizzi`; il lookup CAP/citta/provincia usa `city_registry` con query parametrizzate, citta/provincia bloccate quando il CAP e riconosciuto e gestione multi-citta tramite dropdown. Quando il form add/edit indirizzo e aperto, il checkout entra in stato lock: stepper, procedi ordine, conferma/gateway, righe carrello, quantity stepper `+/-`, input quantita, coupon, cambio indirizzo, spedizione e pagamento sono bloccati lato UI e lato server finche l'utente salva o annulla. Il carrello espone un solo riepilogo visibile `Riepilogo ordine`; le label tecniche legacy restano non visibili e alimentano il riepilogo finale. Lo stepper superiore consente navigazione controllata tra carrello, spedizione/checkout e conferma senza avviare gateway. L'avvio ordine/gateway resta consentito solo dallo step `Conferma`. Gateway core, costi, totali, IVA, spedizione e schema DB non sono stati modificati.

I campi input del checkout devono rispettare le lunghezze reali dei contratti DB/procedure prima di creare documenti o avviare gateway. Per le note ordine web il contratto operativo e `carrello_Documento.pNoteSpedizione VARCHAR(255)`, poi salvato in `documenti.NoteEsterne`: la UI deve impostare limite/hint coerente e il server deve bloccare valori oltre 255 caratteri prima della stored procedure, senza troncamento silenzioso. Gli errori DB come `Data too long` non devono essere esposti all'utente finale; usare messaggi specifici per validazioni note e messaggi generici non tecnici per errori imprevisti.

Il consenso alle condizioni di vendita nel riepilogo finale checkout deve essere esplicito tramite checkbox non preselezionata, con link a `condizioni-vendita.aspx` e blocco sia client-side sia server-side. Senza consenso non devono essere creati ordine/documento, gateway o email e il carrello deve restare preservato. La pagina `condizioni-vendita.aspx` legge il testo da `Aziende.Condizioni_vendita` con query parametrizzata e non modifica DB/schema.

Durante lo step checkout, il wrapper principale del carrello `CartItemsWrap` deve essere nascosto lato UI per evitare doppio rendering con shell checkout e riepilogo laterale; torna visibile nello step carrello. Il fix `CART-LEGACY-DUPLICATE-AUDIT-FIX-1A` / PR #186 e solo di visibilita UI in `carrello.aspx.vb` e non modifica `ordine.aspx.vb`, `Carrello_Documento`, DB/schema/SP, gateway, email/template, prezzi/IVA/totali/righe, note ordine o consenso condizioni.

Il blocco carrello/checkout UI e chiuso con smoke manuali A su PR #185 e PR #186: `addresserror=1` mostra un solo messaggio indirizzo generico non tecnico; in carrello normale resta una sola lista prodotti e in checkout non compaiono due carrelli/listati prodotti. Scelta indirizzo, note ordine, consenso condizioni, pulsanti checkout/conferma, riepilogo, prezzi/IVA/totali/righe, ordine/gateway/email e DB/schema/SP restano invariati; nessun ordine reale, gateway reale o email live sono stati prodotti dagli smoke.

### 9.5 Checkout

Da completare con audit dedicato. Area sensibile: ordini, documenti, pagamento, spedizione.

### 9.6 Pagamenti

PayPal Express NVP e stato stabilizzato con token `EC-TOKEN` e transazioni `TXN` mascherate nei report. BancaSella resta legacy. Non invocare gateway senza task dedicato.

### 9.7 Area account

Area progressivamente stabilizzata con shell account ONSUS, `body.ks-page-account` e `AccountSidebar` globale su pagine consolidate.

### 9.8 Documenti/ordini

`documenti.aspx` lista documenti/ordini con selector dinamico `sdsTipo`; `documentidettaglio.aspx` dettaglio documento/ordine con stato ordine e stato pagamento separati. `ORDER-CONFIRMATION-UX-1A` aggiunge una UX post-acquisto moderna compatibile con lo storico: hero contestuale, dati ordine principali, stampa/copia numero ordine, card informative e timeline locale, senza modificare gateway core, totali, costi, DB/schema o stato pagamento.

### 9.9 Profilo utente

`my-account-edit.aspx` e pagina profilo ONSUS stabilizzata. Il riquadro fiscale usa `RagioneSociale` per `Ragione Sociale / Cognome` e `CognomeNome` per `Nome`; `datiutente.aspx` resta legacy/compatibilita per parti non migrate.

`ACCOUNT-DATIUTENTE-VALIDATION-1A` / PR #180 mantiene `datiutente.aspx` come superficie legacy/compatibilita ma rafforza il code-behind `datiutente.aspx.vb`: update profilo vincolati a `LoginId`/`UtentiId`, update destinazioni vincolati a `UtenteId`, validazioni server-side minime per email, indirizzo fatturazione, CAP/provincia/contatti e indirizzo alternativo, messaggi errore generici senza dettagli tecnici. Non cambia schema DB, stored procedure, checkout, ordine, email/template o pagine account moderne.

`ACCOUNT-DATIUTENTE-UI-1A` / PR #181 migliora solo la resa della pagina legacy `datiutente.aspx` come ponte di compatibilita: card "Gestione dati account", CTA verso `my-account-edit.aspx`, `my-account-address.aspx` e `myaccount.aspx`, sezione legacy incapsulata in una card moderna e CSS dedicato corretto per evitare wrapper FormView vuoti. Non cambia il code-behind hardenizzato da PR #180, DB/schema/SP, checkout, ordine, email/template o pagine account moderne.

`ACCOUNT-DATIUTENTE-UI-FIX-1A` / PR #182 rimuove il blocco legacy duplicato rimasto fuori layout dopo PR #181: breadcrumb legacy, intestazione "Dati di accesso / account" e tab "Dettagli account" / "Indirizzi" fuori contesto non vengono piu renderizzati. Restano la UI moderna centrale e la sezione legacy incapsulata; `datiutente.aspx.vb` e la logica dati PR #180 non cambiano.

`ACCOUNT-AREA-LEGACY-DUPLICATES-1A` conferma post-merge PR #182 che le pagine account principali (`myaccount.aspx`, `my-account-edit.aspx`, `my-account-address.aspx`, `datiutente.aspx`), `AccountSidebar.ascx` e i CSS account non mostrano duplicati legacy evidenti fuori layout. I selettori CSS storici `wrap-sidebar-account` restano non referenziati dal markup account ispezionato; nessun fix applicativo aggiuntivo e nessun branch/PR separato necessari.

`DOCS-ACCOUNT-AREA-UI-CLOSE-1A` chiude il blocco Area Cliente UI/datiutente dopo smoke manuale A: PR #180 hardening `datiutente.aspx.vb`, PR #181 UI `datiutente.aspx` e PR #182 rimozione duplicato legacy risultano mergeate; accesso anonimo protetto, accesso loggato coerente, link area cliente funzionanti e nessun dato cliente reale modificato. Checkout, carrello, ordine, gateway, email, DB/schema/SP restano non toccati.

`ACCOUNT-ADDRESS-ORDER-GUARD-1A` / PR #183 e chiuso con smoke statico A. In `ordine.aspx.vb`, `SCEGLIINDIRIZZO` assente/null/0 resta compatibile con il flusso storico; valori > 0 richiedono ownership parametrizzata `Id=?Id AND UtenteId=?UtentiId`; indirizzi invalidi, stale o non appartenenti bloccano prima di `Carrello_Documento` con redirect generico `carrello.aspx?addresserror=1`, senza ordine, gateway, email o svuotamento carrello. Smoke runtime solo in ambiente sicuro con account test, carrello test, gateway non reale e SMTP sink. DB/schema/SP, carrello, gateway, email/template, prezzi/IVA/totali/documenti e dati cliente reali non cambiano.

`CART-ADDRESS-ERROR-MESSAGE-1A` / PR #185 completa il ritorno utente della guard: `carrello.aspx` accetta solo il flag statico `addresserror=1` e mostra un alert generico non tecnico tramite il messaggio indirizzo gia presente, senza riflettere valori querystring. Non cambia ordine, `Carrello_Documento`, DB/schema/SP, gateway, email/template, prezzi/IVA/totali/righe o dati cliente.

### 9.10 Indirizzi

`my-account-address.aspx` e pagina ONSUS autonoma per indirizzi account: indirizzo principale, sedi alternative, add/edit sede alternativa e scelta predefinito sono stabilizzati. Delete indirizzi resta da valutare con task dedicato. La selezione manuale indirizzo nel carrello e chiusa nel blocco `CART-ADDRESS-SELECTION`; add/edit inline carrello e lookup CAP da `city_registry` sono chiusi nel blocco `CART-INLINE-ADDRESS-CITYREGISTRY-STEP`.

### 9.11 Wishlist

`wishlist.aspx` stabilizzata con AccountSidebar globale.

### 9.12 Login

Auditato in LOGIN-REGISTER-1A e mitigato in LOGIN-REGISTER-SECURITY-1. Usa ancora `vlogin`, sessione e confronto password case-insensitive; hash non implementato. I messaggi pubblici di errore sono ora generici per ridurre enumeration tra username inesistente, password errata e utente non attivo.

`LOGIN-PASSWORD-TOGGLE-1A` / PR #184 interviene solo sulla resa del campo password in `login.aspx`: mantiene il toggle custom mostra/nascondi gia presente e nasconde il reveal nativo del browser per evitare doppio controllo visivo. Non modifica `login.aspx.vb`, autenticazione server-side, sessione/cookie, registrazione, reset/remind, DB/schema/SP, checkout/carrello/ordine/gateway o email/template.

### 9.13 Registrazione

Auditata in LOGIN-REGISTER-1A e mitigata in LOGIN-REGISTER-SECURITY-1. Crea utente/login con stored procedure legacy, senza schema change e senza hash. La policy visibile e stata allineata a 8-25, il lowercase forzato della password e stato rimosso e i flow post-registrazione basati su password in email/sessione/URL sono stati neutralizzati.

### 9.14 Recupero password

`remind.aspx` e `resetpassword.aspx` gestiscono il reset password tokenizzato fase 1, legacy-compatible e senza hash migration. Il flow richiede email e Codice fiscale oppure Partita IVA, tratta CF/PIVA come alternativi, de-duplica per `LoginId` e genera token solo con un candidato valido. Il token e single-use, scade dopo 30 minuti e nel DB viene salvato solo `TokenHash`. Il reset riuscito aggiorna `login.Password` legacy e `login.DataPassword`; `aziende.ScadenzaPassword` resta invariato. `remind.aspx` usa POST/Redirect/GET, `remind.aspx?sent=1` mostra una card di conferma evidente senza form ambiguo o loader legacy, l'email reset e professionale con riferimenti aziendali e avvertenze anti-phishing, e il redirect post-login esclude `resetpassword.aspx`, `remind.aspx` e URL con token/reset/remind.

`AUTH-LEGACY-DUPLICATE-AUDIT-FIX-1A` / PR #187 conferma che `login.aspx`, `registrazione.aspx`, `remind.aspx` e `resetpassword.aspx` non hanno doppie form runtime. Il solo fix UI applicato e su `resetpassword.aspx`: i reveal nativi browser dei campi `tbPasswordNuova` e `tbPasswordConferma` sono nascosti con CSS mirato, lasciando i toggle custom come unico controllo visivo per ciascun campo. Non cambia code-behind, token flow, login/auth, sessioni/cookie, registrazione, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali.

`RESET-PASSWORD-TOKEN-GUARD-1A` / PR #188 corregge la robustezza server-side di `resetpassword.aspx` per token assente, vuoto o non valido. `CurrentToken()` non chiama piu `.Trim()` su un valore potenzialmente `Nothing` e `LoadResetState()` mostra il pannello invalido controllato senza form reset utilizzabile quando il token manca o e vuoto. Il messaggio utente resta generico e non tecnico; generazione, validazione, durata, storage e consumo token restano invariati, cosi come login/auth, sessioni/cookie, registrazione, remind generation, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali.

Chiusura post-smoke: `SMOKE RESET TOKEN: A` conferma che `resetpassword.aspx` senza token, con `token=` vuoto e con token non valido non mostra piu errori server, stack trace o dettagli tecnici. Il form reset resta nascosto/non utilizzabile senza token valido; PR #187 e PR #188 non modificano `PasswordResetTokenService.vb`, login/auth, sessioni/cookie, registrazione/remind, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali. Il path legacy preesistente `Public/Images/` in `registrazione.aspx` resta backlog separato e non appartiene a questo blocco.

`REGISTRATION-LEGACY-ASSET-PATH-1A` / PR #189 rimuove da `registrazione.aspx` l'unico riferimento legacy `Public/Images/loghi_agevolazione.jpg`. REV1 sostituisce il placeholder generico rifiutato con l'asset reale `/Public/assets/images/coupon/Struttura/sconto_50px.png`, gia versionato nel nuovo schema asset e piu coerente con il blocco listini agevolati. La modifica riguarda solo il path dell'immagine decorativa: form, controlli server, ID, eventi, validatori, code-behind registrazione, login/auth/sessioni/cookie, salvataggi, email/password, reset/remind/token, DB/schema/SP, carrello/ordine/gateway/prezzi/totali restano invariati.

Chiusura post-smoke: `SMOKE REGISTRATION UI: A` conferma che la registrazione apre senza errori, il blocco "LISTINI AGEVOLATI" non mostra placeholder/immagine mancante e l'icona sconto finale e coerente. Nessun utente reale creato e nessuna email live inviata; nessuna modifica a logica registrazione/auth/sessioni/email/DB, reset/remind/token, carrello/ordine/gateway/prezzi/totali o asset legacy `Public/Images/`.

`LEGACY-ASSET-PATH-AUDIT-FIX-1A` / PR #190 mantiene la regola KeepStore 3.0 sui nuovi path asset: non introdurre `Public/Images/`, usare solo asset esistenti sotto `/Public/assets/images/...` e non sostituire immagini informative/funzionali con placeholder generici. Il fix sicuro applicato e limitato a `coupon_esito_acquisto.aspx`: il vecchio `Public/Images/servizio_clienti.jpg` viene sostituito da `/Public/assets/images/headphone-2.svg`; gli altri riferimenti legacy emersi in carrello, documenti, coupon, promo, wishlist, articolix e rettifica magazzino restano backlog dedicato per rischio funzionale o assenza di equivalente moderno certo.

`CART-DISCOUNT-LEGACY-ICONS-1A` / PR #192 applica il primo micro-fix non-coupon sui path asset legacy: in `carrello.aspx` le sole icone feedback buono sconto passano da `Public/Images/Ok.png` e `Public/Images/Remove.png` agli asset gia presenti `/Public/assets/images/ico/modalok.svg` e `/Public/assets/images/ico/modalno.svg`. `interrogativo.png` e `StepCarrello1.png` restano backlog separato; PR #191 e coupon restano fuori scope. Nessuna modifica a logica buono sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP o auth/sessioni/cookie.

`CART-DISCOUNT-FIELD-UX-1A` / PR #193 rende il pannello codice sconto di `carrello.aspx` leggibile e riconoscibile senza cambiare logica: titolo `Hai un codice sconto?`, testo guida, placeholder `Inserisci codice sconto`, bottone `Applica`, wrapper `ks-cart-discount-panel` e CSS responsive in `cart-ui.css`, allineati ai pattern ONSUS `shop-cart.html` / `checkout.html`. Il fix preserva `TB_BuonoSconto`, `BT_ApplicaBuonoSconto`, feedback `checkOKBuonoSconto` / `checkNOBuonoSconto`, link annullamento e icone moderne `modalok.svg` / `modalno.svg`; nessun ritorno a `Public/Images/Ok.png` o `Public/Images/Remove.png`. PR #191 e file coupon restano esclusi; logica sconto, prezzi/IVA/totali, righe, checkout/ordine/gateway, email/template, DB/schema/SP e auth/sessioni/cookie restano invariati.

`CART-CHECKOUT-UX-SMOKE-FIX-1A` / PR #194 corregge lo smoke reale B post-PR #193 senza toccare logica: `carrello.aspx` carica esplicitamente `cart-ui.css`, il pannello sconto resta nello stesso controllo WebForms ma le regole cart-specific diventano effettive, il bottone `Applica` non eredita piu il posizionamento assoluto di `.ip-discount-code .tf-btn`, i bottoni scuri del carrello hanno contrasto leggibile e lo step spedizione/checkout riceve spacing/card/grid coerenti con ONSUS `shop-cart.html` e `checkout.html`. Restano invariati ID, eventi, validator, code-behind, logica buono sconto, prezzi/IVA/totali/righe, checkout business logic, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie; PR #191 e file coupon restano sospesi/fuori scope.

REV1 `CART-CHECKOUT-UX-SMOKE-FIX-1C` / PR #194 aggiunge la separazione UI reale dei tre step: titolo dinamico carrello/checkout/conferma, layout carrello `ks-cart-layout` con coupon sotto prodotti e riepilogo stabile, CSS checkout applicato direttamente a `.ks-checkout-shell` (fuori dallo scope `.s-shoping-cart`), stato codice sconto non interattivo in sidebar checkout e conferma finale senza doppia CTA primaria. Rimangono invariati code-behind, logica sconto, checkout business logic, prezzi/IVA/totali/righe, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie e PR #191/coupon.

REV2 `CART-CHECKOUT-UX-SMOKE-FIX-1D` / PR #194 corregge il punto strutturale rimasto: `CartActionsWrap` era ancora figlio di `CartItemsWrap`, che viene nascosto dal code-behind negli step checkout/conferma. Il pannello sconto viene mantenuto con gli stessi controlli server ma reso fratello del wrapper prodotti, cosi lo step 2 puo mostrare il campo coupon inseribile/validabile senza duplicare ID o logica WebForms; nello step 2 CSS nasconde riepilogo/azioni carrello duplicati, nello step 3 nasconde tutto il support panel e lascia solo la CTA finale. Tutte le regole nuove restano scoped a `.ks-cart-page`; nessun cambio a code-behind, ID/eventi/validatori, logica sconto, prezzi/IVA/totali/righe, spedizione/pagamento, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie o PR #191/coupon.

REV3 `CART-CHECKOUT-UX-SMOKE-FIX-1E` / PR #194 applica la rifinitura finale di leggibilita e gerarchia dopo smoke REV2 ancora B: font minimi non sotto 14px, heading step 28-32px desktop, titoli card 18-20px, input/bottoni almeno 14px desktop e 16px mobile, card con padding coerente ONSUS e grid responsive. Step 1 mantiene prodotti full width, coupon e riepilogo importi in due colonne, azioni ordinate nel container; step 2 mantiene coupon inseribile/validabile, indirizzo compatto e riepilogo prodotto con miniatura/nome/qta/prezzo; step 3 nasconde le sezioni operative precedenti e concentra la conferma finale su riepilogo + CTA primaria. Nessun cambio a controlli server, code-behind o business logic.

REV4 `CART-CHECKOUT-UX-SMOKE-FIX-1F` / PR #194 e una correzione chirurgica post-smoke REV3 B. Il doppio incremento quantita era causato da due handler JS attivi sullo stesso stepper (`cart-ui.js` globale in capture e `checkout-ui.js` sul controllo); ora `cart-ui.js` ignora gli stepper carrello `.ks-wg-quantity`, lasciando un solo handler. Il coupon step 2 viene reso realmente visibile spostando lato client l'unico `CartActionsWrap` esistente nello slot `CheckoutCouponSlot`, senza duplicare `TB_BuonoSconto`, `BT_ApplicaBuonoSconto` o feedback. La lista indirizzi lunga generata dal vecchio enhancer JS viene disabilitata: resta la card indirizzo selezionato e la select compatta `LstScegliIndirizzo`. Nessun cambio a code-behind, logica sconto/indirizzi, prezzi, totali, ordine, gateway, email, DB/schema/SP o auth.

REV5 `CART-CHECKOUT-UX-SMOKE-FIX-1G` / PR #194 separa la visibilita dell'input buono sconto dalla visibilita del riepilogo conteggi. La causa dello smoke REV4 B era server-side: `Panel_BuoniSconto.Visible` era legato a `TableConteggi.Visible`, quindi lo step 2 poteva non renderizzare affatto `TB_BuonoSconto`, `BT_ApplicaBuonoSconto` e feedback. La nuova regola mostra l'unico pannello sconto quando i buoni sono abilitati, il carrello ha articoli e lo step non e conferma; step 3 resta senza input. Validazione, eventi, sessioni e calcoli sconto restano invariati.

### 9.15 Cambio password

`password.aspx` e pagina canonica. Policy server-side 8-25, conferma obbligatoria, nuova diversa dalla vecchia, update centralizzato, `DataPassword` su successo. Hash non implementato.

### 9.16 Logout

`logout.aspx` chiude sessione e gestisce pulizia collegata al carrello. Da completare con audit sessione.

### 9.17 Accesso negato

`accessonegato.aspx` e la pagina standard per accesso negato, sessione non autorizzata o area riservata non disponibile. Usa `Page.master`, mostra un messaggio non tecnico, offre CTA sicure verso login e home e accetta solo un eventuale `ReturnUrl` locale sanificato; non deve mostrare dettagli ASP.NET, stack trace o redirect automatici verso se stessa.

## 10. Database e tabelle

Non riportare valori sensibili. Documentare solo nomi tabelle/campi e relazioni funzionali. Non inserire connection string, password, hash, token, cookie, session id, email reali o dati personali.

Il blueprint distingue tre livelli fisici/logici:

- database ecommerce cliente/azienda: database operativo del sito e dei dati cliente/azienda;
- database registry citta/CAP: archivio di supporto per riconoscimento e normalizzazione di citta e CAP;
- database registry connessioni gestionale: archivio di verifica/indirizzamento usato dal gestionale per raggiungere il database cliente/azienda corretto.

I backup disponibili sono fonti tecniche per audit controllati. Non devono essere estratti, importati o analizzati nei task documentali, e non devono mai essere usati per riportare valori reali nel blueprint.

| Tabella/View | Uso noto | Campi chiave noti | Stato |
| --- | --- | --- | --- |
| `login` | Credenziali/sessione utente | `Password`, `DataPassword`, `Username`, `Email`, `Abilitato` | legacy, hash non implementato |
| `vlogin` | View login/utente | `Password`, `Username`, `Email`, `UtentiId`, `UtentiTipoId`, `UtentiAbilitato`, `AziendeID` | usata da login/remind |
| `utenti` | Anagrafica utente | `UtentiId`, dati profilo/fiscali | legacy |
| `utentitipo` | Tipo utente/listino/permessi | `UtentiTipoId`, listino, abilitazioni | legacy |
| `utentiindirizzi` | Indirizzi/destinazioni | indirizzi fatturazione/destinazioni | legacy |
| `utentirapporto` | Rapporto utente/pagamento | pagamento/listino/relazioni | legacy |
| `pagamentitipo` | Tipi pagamento | predefiniti/azienda | legacy |
| `carrello` | Carrello sessione/login | `SessionId`, `LoginId`, righe carrello | sensibile checkout |

Campi chiave gia noti: `Password`, `DataPassword`, `ScadenzaPassword`, `Username`, `Email`, `Abilitato`, `UtentiAbilitato`, `UtentiId`, `UtentiTipoId`, `AziendeID`.

## 11. Database fisici, backup e ruolo multi-azienda

Germano ha fornito tre backup database come materiale tecnico di riferimento. I backup sono presenti nel progetto e nell'area di lavoro Codex, ma non devono essere aperti, estratti, importati o scanditi senza task DB esplicito.

`DB-BACKUP-AUDIT-1A` ha analizzato i tre backup in sola lettura, tramite estrazione temporanea fuori dal repository. Nessun backup e stato importato in MySQL, nessun database e stato ripristinato, nessun dato sensibile e stato riportato e nessun file del repository e stato modificato durante l'audit. I backup sono fonti tecniche per audit controllati, non materiale da esporre.

### 11.1 Backup database analizzati

| File | Ruolo | Stato analisi | Sensibilita | Note |
| --- | --- | --- | --- | --- |
| `taikun_2026-06-05_02-00-02.zip` | DB cliente/azienda ecommerce | OK | alta | 178 tabelle, 29 viste, dati operativi completi |
| `city_registry_2026-06-05_02-00-02.zip` | registry citta/CAP | OK | bassa | 4 tabelle, 1 vista, 5 procedure |
| `connessioni_2026-06-05_02-00-02.zip` | registry connessioni gestionale | OK | alta | 8 tabelle, 1 vista, 1 procedura |

### 11.2 Database cliente/azienda ecommerce

Il backup `taikun_2026-06-05_02-00-02.zip` rappresenta il database cliente/azienda usato dal sito nel caso Taikun. Il nome database rilevato e `taikun`, ma in architettura generale il nome cambia in base al cliente/azienda che utilizza KeepStore.

Il database contiene dati operativi completi, 178 tabelle e 29 viste. Procedure, funzioni e trigger non sono stati rilevati nel dump. Sono presenti foreign key, ma non in modo esteso; molte relazioni sembrano gestite da codice o da logica applicativa legacy. L'audit ha rilevato 27 tabelle senza primary key. La sensibilita e alta.

Tabelle grandi o critiche rilevate:

- `logoperazioni`
- `logmovimentiarticoli`
- `articoli_listini`
- `documentirighe`
- `movimentimagazzino`
- `documenti`
- `carrello`

Aree funzionali rilevate:

- catalogo/articoli;
- listini/prezzi;
- offerte/promozioni;
- giacenze/disponibilita;
- carrello;
- documenti/ordini;
- utenti/login;
- indirizzi;
- pagamenti;
- configurazioni azienda;
- email/notifiche;
- integrazioni marketplace;
- SEO e URL, da approfondire con audit dedicato.

Il sito KeepStore usa un database aziendale specifico, mentre il gestionale puo collegarsi al database corretto dopo verifica/indirizzamento tramite il registry `connessioni`.

### 11.3 Registry citta/CAP

Il backup `city_registry_2026-06-05_02-00-02.zip` rappresenta il registry citta/CAP/province/nazioni. Il database rilevato e `city_registry`. La sensibilita e bassa salvo verifiche future, perche il contenuto atteso e geografico e non personale.

Tabelle rilevate:

- `cities`
- `countries`
- `postcode_codes`
- `provinces`

Vista rilevata:

- `getalldata`

Procedure rilevate:

- `Delcities`
- `Delprovinces`
- `Modprovinces`
- `Newcities`
- `Newprovinces`

Uso dedotto:

- lookup citta/CAP/province/nazioni;
- supporto alla registrazione sito;
- supporto al gestionale.

Le procedure `New*`, `Mod*` e `Del*` sembrano gestionali o di manutenzione e non devono essere invocate dal sito senza audit dedicato.

### 11.4 Registry connessioni gestionale

Il backup `connessioni_2026-06-05_02-00-02.zip` rappresenta il registry connessioni/indirizzamento gestionale. Il database rilevato e `connessioni`. La sensibilita e alta.

Questo archivio e usato dal gestionale KeepStore all'avvio per verificare e indirizzare il collegamento verso il database cliente/azienda corretto. Non riportare mai valori di connessione, host, credenziali, nomi utente, stringhe operative o codici reali.

Tabelle principali rilevate:

- `aziende`
- `aziende_licenze`
- `utenti_aziende`
- `codiciseriali_utenti`
- `serviziabilitati`
- `versioni`
- `_iva`

Vista rilevata:

- `getallaziende`

Procedura rilevata:

- `GetAziende`

L'audit ha rilevato campi di indirizzamento/connessione e codici utente/azienda, senza riportare valori. Qualsiasi modifica a questo database richiede coordinamento con il gestionale e con Vincenzo.

### 11.5 Database e tabelle principali

| Database | Oggetto | Tipo | Area funzionale | Rischio |
| --- | --- | --- | --- | --- |
| `taikun` | `login` | tabella | utenti/password | alto |
| `taikun` | `articoli`, `articoli_listini`, `articoli_giacenze` | tabelle | catalogo/prezzi/giacenze | medio |
| `taikun` | `carrello` | tabella | carrello/sessione | alto |
| `taikun` | `documenti`, `documentirighe`, `documentidestinazioni` | tabelle | ordini/documenti | alto |
| `taikun` | `pagamentitipo`, `payment_event`, `bancasella_*` | tabelle | pagamenti | alto |
| `taikun` | `aziende`, `mailconfig` | tabelle | configurazione/email | alto |
| `city_registry` | `cities`, `postcode_codes`, `provinces`, `countries` | tabelle | citta/CAP | basso |
| `connessioni` | `aziende`, `utenti_aziende`, `aziende_licenze` | tabelle/view | registry gestionale | alto |

### 11.6 Campi sensibili rilevati, senza valori

| Database | Tabella/view | Campo | Categoria rischio | Valore riportato |
| --- | --- | --- | --- | --- |
| `taikun` | `login` | `Password`, `DataPassword`, `UserName`, `email` | password/account | NO |
| `taikun` | `aziende` | campi SMTP/FTP/PayPal/fiscali/contatto | configurazione/segreti/dati azienda | NO |
| `taikun` | `carrello` | `LoginId`, `SessionId` | sessione/carrello | NO |
| `taikun` | `documenti` | campi fiscali/utente | documenti/dati cliente | NO |
| `taikun` | `ks_amazon_data`, `ks_ebay_data`, `data_amazon` | token/secret | integrazioni | NO |
| `connessioni` | `aziende` | `Connessione` | connection registry | NO |
| `connessioni` | `utenti_aziende`, `codiciseriali_utenti` | `CodiceUtente` | indirizzamento/gestionale | NO |

### 11.7 Dipendenze sito/gestionale

| Area | Database coinvolto | Tabelle/view | Usato da sito | Usato da gestionale | Rischio modifica |
| --- | --- | --- | --- | --- | --- |
| login/password | `taikun` | `login` | si | probabile | alto |
| registrazione/citta | `taikun`, `city_registry` | `login`, geografiche | si | si | alto |
| catalogo/listini/giacenze | `taikun` | `articoli*`, `listini*`, `movimentimagazzino` | si | si | alto |
| carrello/checkout | `taikun` | `carrello`, `documenti*` | si | probabile | alto |
| ordini/documenti | `taikun` | `documenti`, `documentirighe` | si | si | alto |
| pagamenti | `taikun` | `pagamentitipo`, `payment_event`, gateway tables | si | possibile | alto |
| multi-azienda | `connessioni` | `aziende`, `getallaziende`, `GetAziende` | no diretto | si | critico |

### 11.8 Focus login/password/hash migration

`login.Password` e `login.DataPassword` sono campi centrali. Nel dump cliente operativo analizzato non sono stati rilevati campi dedicati a hash, salt o versione algoritmo.

Nel backup operativo `taikun_2026-06-05_02-00-02.zip`, l'audit non ha evidenziato `vlogin` / `Newlogin` come oggetti DDL estratti. Tuttavia il file SQL versionato `Database Taikun/KeepStore.sql` contiene riferimenti DDL a `vlogin` e `Newlogin`, e il codice legacy di autenticazione/registrazione li richiama o li presuppone. Per questo motivo la futura hash migration deve includere un audit mirato di coerenza tra dump operativo, schema versionato, codice applicativo e gestionale prima di modificare `login.Password`.

Rischio specifico hash migration: fonte DB operativa e fonte schema versionata potrebbero non essere perfettamente allineate. Prima di introdurre hash, salt o versione algoritmo serve riconciliazione tra backup, file SQL versionato, codice legacy e gestionale.

Qualsiasi hash migration richiede coordinamento con il gestionale e con Vincenzo. Non riportare mai password, hash reali o valori credenziali.

### 11.9 Focus registrazione/city registry

`city_registry` e adatto a lookup citta/CAP/province/nazioni. La registrazione va auditata considerando sia il database cliente/azienda sia il registry citta/CAP. Le procedure `New*`, `Mod*` e `Del*` sembrano da trattare come manutenzione/gestionale e non devono essere invocate dal sito senza audit.

### 11.10 Focus carrello/documenti/ordini

`carrello`, `documenti`, `documentirighe` e `documentidestinazioni` sono tabelle ad alto impatto. Modifiche a checkout e ordini possono impattare gestionale, documenti fiscali e pagamenti.

L'audit DB non ha invocato gateway, non ha letto dati ordine reali e non ha riportato dati ordine/documento.

### 11.11 Rischi principali DB

- Il DB operativo contiene password legacy e campi segreti/configurativi.
- `connessioni` e altamente sensibile per il modello multi-azienda.
- Nel DB cliente non sono stati rilevati campi hash/salt/versione algoritmo.
- Molte relazioni sembrano legacy/applicative piu che basate su foreign key robuste.
- `city_registry` e una dipendenza reale della registrazione.
- Modifiche a login, password, utenti, indirizzi, documenti o ordini richiedono coordinamento con gestionale e Vincenzo.

## 12. Funzionalita ecommerce

| Funzionalita | Stato iniziale | Note |
| --- | --- | --- |
| Catalogo | da completare | Pagine `articoli.aspx`, `articolo.aspx` |
| Ricerca | da completare | Include suggest/search |
| Settori/categorie | da completare | App_Code e menu home collegati |
| Prodotto | da completare | Product detail e product card |
| Promozioni/prezzi | da completare | Promo, listini, coupon |
| Carrello | stabile UI/indirizzi/Conferma | Perimetro sensibile: gateway/core checkout separati |
| Ordini | parziale/stabile UX dettaglio | Lista/dettaglio account stabilizzati; UX conferma ordine moderna su `documentidettaglio.aspx` |
| Documenti | stabile area account | Selector documenti dinamico |
| Pagamenti | parziale/stabilizzato PayPal | PayPal Express NVP stabilizzato; BancaSella legacy |
| Area cliente | consolidata su pagine principali | Sidebar/account shell |
| Wishlist | stabile | AccountSidebar globale |
| Coupon | da completare | Flow coupon legacy da audit |
| Email/notifiche | da completare | Reminder/registrazione hanno debiti security |
| Integrazione gestionale | da completare | Relazione DB/stored procedure/view |

## 13. Area account - stato consolidato

- `myaccount.aspx`: stabile con dashboard e profilo separato tra `RagioneSociale` e `CognomeNome`.
- `my-account-edit.aspx`: stabile con dettagli account, validazioni profilo e campi fiscali read-only allineati.
- `my-account-address.aspx`: stabile ONSUS autonomo per indirizzi account, con add/edit sedi alternative e scelta predefinito.
- `wishlist.aspx`: stabile.
- `documenti.aspx`: stabile con AccountSidebar globale e selector documenti dinamico.
- `documentidettaglio.aspx`: stabile.
- `password.aspx`: stabile come pagina canonica cambio password.
- `cambiapassword.aspx`: legacy redirect controllato.
- AccountSidebar condivisa validata.
- Cleanup sidebar fase 1 chiuso.
- Cleanup documenti fase 2 chiuso.
- Consolidamento password chiuso con hotfix.

Debito residuo account:

- `datiutente.aspx` resta legacy/compatibilita con tab/JS e gestione salvataggi/destinazioni non piu percorso operativo principale per indirizzi account.
- Delete indirizzi resta da valutare solo con task dedicato.
- Carrello indirizzi chiuso: selezione manuale, link gestione indirizzi, add/edit inline, lookup CAP `city_registry` e step `Conferma` sono stabilizzati; gateway/core checkout restano separati.
- Cleanup completo sidebar/nav inline legacy non ancora concluso su `datiutente.aspx`.

## 14. Login, registrazione e recupero password - audit LOGIN-REGISTER-1A

Esito audit: A.

| Campo | Valore |
| --- | --- |
| Branch analizzato | `frontend-rebuild` |
| HEAD analizzato | `9ee45ed5fb8f08b79bad29519d42d0c6d0958668` |
| Tipo audit | read-only |
| File modificati | nessuno |
| DB/gateway/carrello/checkout/ordine invocati | no |

### 14.1 Rischi principali

- Password ancora gestite in chiaro nel flusso legacy login/registrazione/recupero.
- Login ancora case-insensitive sulla password.
- Registrazione salva password in lowercase.
- `remind.aspx` non fa reset sicuro: recupera/invia credenziali esistenti.
- Registrazione e reminder possono inviare password via email.
- Coupon post-registrazione puo comporre URL con parametro password.
- Policy non allineate: registrazione 6-12 caratteri word-only, `password.aspx` 8-25.
- `AntiCsrfPage` esiste ma login/registrazione/remind/password non la ereditano.
- Nessuna rigenerazione esplicita sessione post-login rilevata.
- Messaggi login/reminder troppo specifici, rischio enumeration.
- Diagnostica tecnica ancora presente in alcuni rami legacy registrazione.
- Segreti/config presenti in codice/config ma non riportati.

### 14.2 File analizzati

- `login.aspx` / `login.aspx.vb`
- `registrazione.aspx` / `registrazione.aspx.vb`
- `registrazioneok.aspx`
- `remind.aspx` / `remind.aspx.vb`
- `password.aspx` / `password.aspx.vb`
- `cambiapassword.aspx` / `cambiapassword.aspx.vb`
- `logout.aspx` / `logout.aspx.vb`
- `accessonegato.aspx` / `accessonegato.aspx.vb`
- `Page.master` / `Page.master.vb`
- `web.config`
- `App_Code/AntiCsrfPage.vb`

### 14.3 Meccanismo password rilevato

- Hash implementato: no.
- Password legacy in chiaro: si.
- Login: confronto password case-insensitive.
- Registrazione: password salvata lower-case.
- Recupero credenziali legacy con invio di credenziali esistenti, non reset tokenizzato.
- Cambio password canonico: `password.aspx`, case-sensitive, policy 8-25, `DataPassword` aggiornata su successo.
- `cambiapassword.aspx`: redirect controllato verso `password.aspx`.

### 14.4 Session key rilevate

- `LoginId`
- `LoginID`
- `LoginEmail`
- `LoginNomeCognome`
- `LoginUltimoAccesso`
- `UtentiId`
- `UtentiID`
- `UtentiTipoId`
- `DataPassword`
- `ScadenzaPassword`
- `Inserimento_User`
- `Inserimento_Password`
- `Login_User`
- `Login_Password`

### 14.5 Tabella rischi audit

| Area | Rischio | Nota |
| --- | --- | --- |
| `login.aspx` | alto | Form login legacy, messaggi specifici |
| `login.aspx.vb` | critico | Password chiara/case-insensitive |
| `Page.master.vb` | alto | Login legacy parallelo e gestione sessione/scadenza |
| `registrazione.aspx` | alto | Policy vecchia e layout legacy |
| `registrazione.aspx.vb` | critico | Password lowercase, email/session legacy |
| `registrazioneok.aspx` | critico | Possibile password in URL nel flow coupon |
| `remind.aspx` | critico | Reminder credenziali, non reset |
| `remind.aspx.vb` | critico | Invio password via email |
| `password.aspx` | medio | Canonica stabile, ma senza hash |
| `cambiapassword.aspx` | basso | Redirect controllato |
| CSRF/sessione | medio/alto | Helper presente ma non ereditato dalle auth pages |
| `web.config` | alto gestionale | Segreti/config presenti, non riportati |

### 14.6 Piano consigliato audit

Opzione consigliata: fase D preparatoria senza schema change, seguita da migrazione B progressiva on-login dopo audit gestionale e proposta schema.

Sequenza suggerita:

1. `LOGIN-REGISTER-SECURITY-1B` - chiuso con PR #117
2. `PASSWORD-HASH-AUDIT-2A`
3. `REMIND-RESET-1A`
4. `REGISTRATION-POLICY-1A`
5. `GESTIONALE-PASSWORD-AUDIT-1A`
6. `PASSWORD-HASH-SCHEMA-2B`
7. `PASSWORD-HASH-MIGRATION-2C`

### 14.7 Mitigazione LOGIN-REGISTER-SECURITY-1

LOGIN-REGISTER-SECURITY-1 e chiuso lato codice.

| Campo | Valore |
| --- | --- |
| PR | #117 |
| Merge commit | `f51ab9a4df9afb71760a31db97ed0eac547cd9c3` |
| Branch task | `task/login-register-security-1b-no-schema` |
| Smoke post-merge | LOGIN-REGISTER-SECURITY-1H = A |
| Cleanup branch | LOGIN-REGISTER-SECURITY-1I = A |
| Schema DB modificato | no |
| Hash implementato | no |

File modificati:

- `Page.master.vb`
- `login.aspx.vb`
- `registrazione.aspx`
- `registrazione.aspx.vb`
- `registrazioneok.aspx`
- `remind.aspx`
- `remind.aspx.vb`

Effetti funzionali:

- Login enumeration ridotta con messaggio generico unico.
- Reminder trasformato in recupero assistito.
- Reminder non promette azioni non eseguite, non invia password esistente, non invia email reale e non fa enumeration.
- Registrazione non invia password in email.
- Password in URL rimossa/neutralizzata.
- Password in sessione rimossa/neutralizzata.
- Policy registrazione allineata a 8-25.
- Lowercase forzato password rimosso.
- Diagnostica tecnica rimossa.
- `registrazioneok.aspx` senza password in URL/UI.
- `Page.master.vb` neutralizza i flow post-registrazione basati su password in sessione.

Smoke post-merge:

- Ambiente: `https://www.taikun.it/`.
- Login PROVA OK, senza password nei report.
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

### 14.8 Audit password/hash - PASSWORD-HASH-AUDIT-2A

Esito audit: A.

| Campo | Valore |
| --- | --- |
| Branch analizzato | `frontend-rebuild` |
| HEAD analizzato | `57ea6a2c750f94286afd1d78214f3dbef8f88a7b` |
| Tipo audit | read-only |
| Backup importati | no |
| File repository modificati | nessuno |
| Dati sensibili esposti | no |

Mappa password:

- Fonte principale account: `login.Password`.
- `login.DataPassword` e usato nel ciclo password/scadenza.
- `ScadenzaPassword` risulta su configurazione azienda/sessione e viene usato per redirect scadenza.
- Campi hash/salt/versione gia esistenti: no.
- Reset token/scadenza token rilevati: no.
- Altri campi password/config esistono per SMTP/export/spedizioni e non vanno confusi con password account.

Riconciliazione `vlogin` / `Newlogin`:

| Oggetto | Backup operativo | Schema versionato | Codice legacy | Impatto | Azione |
| --- | --- | --- | --- | --- | --- |
| `vlogin` | non rilevato come DDL estratto nel blueprint/audit backup | si | si, login/reminder/master/registrazione | divergenza fonti | riconciliare prima di hash |
| `Newlogin` | non rilevato come DDL estratto nel blueprint/audit backup | si | si, registrazione | rischio rottura registrazione | audit DB+gestionale |
| `login.Password` | campo legacy centrale | si | si | cleartext legacy | migrazione progressiva |
| `DataPassword` | campo legacy centrale | si | si | scadenza password | aggiornare solo su successo |

Nota: per `vlogin` e `Newlogin` evitare formulazioni assolute. Specificare sempre la fonte: backup operativo, schema versionato o codice legacy.

Flussi auth:

| Flusso | File | DB coinvolto | Meccanismo password | Rischio | Priorita |
| --- | --- | --- | --- | --- | --- |
| Login pagina | `login.aspx.vb` | `vlogin` | confronto legacy case-insensitive | enumeration, no hash | alta |
| Login master | `Page.master.vb` | `vlogin` | confronto legacy case-insensitive | flow parallelo | alta |
| Registrazione | `registrazione.aspx(.vb)` | `utenti`, `login`, `Newlogin`, `vlogin` | password lowercase, email/sessione | critica | alta |
| Reminder | `remind.aspx.vb` | `vlogin` | recupera password esistente | incompatibile con hash | critica |
| Cambio password | `password.aspx.vb` | `login` | update centralizzato legacy | buon punto per hash adapter | alta |
| Logout/protezione | `logout`, `accessonegato`, `Page.master` | sessione/carrello | session clear/abandon | ok, ma carrello collegato | media |

Sintesi tecnica:

- Login legacy usa query parametrizzata su `vlogin`, ma password confrontata in chiaro e case-insensitive.
- I messaggi login pubblici sono stati mitigati in LOGIN-REGISTER-SECURITY-1 con messaggio generico unico.
- Registrazione usa `Newlogin`, controlli duplicati su `vlogin` e policy vecchia 6-12 alfanumerici.
- Registrazione e stata mitigata a policy 8-25, senza lowercase forzato e senza esposizione password in email/sessione/URL.
- I flow post-registrazione basati su password in sessione sono stati neutralizzati in `Page.master.vb`.
- Reminder non recupera/invia piu password esistente: usa reset tokenizzato fase 1 legacy-compatible.
- Token reset/scadenza token sono gestiti dalla tabella `login_password_reset_tokens`.
- `password.aspx.vb` e il punto piu pulito per futuro hash adapter.
- `Page.master` gestisce `DataPassword`/`ScadenzaPassword` e redirect a `password.aspx`.
- Restano da progettare hash migration, coordinamento gestionale e normalizzazione completa auth.

Impatto gestionale/Vincenzo:

- Impatto alto.
- Il gestionale probabilmente legge/scrive `login.Password` o dipende da `vlogin` / `Newlogin`.
- Prima di cambiare schema servono conferme su lettura login, creazione utenti, reset password, scadenza password, sincronizzazione multi-azienda e deploy DB.

Opzioni hash migration:

| Opzione | Descrizione | Pro | Contro | DB | Gestionale | Raccomandazione |
| --- | --- | --- | --- | --- | --- | --- |
| A hard switch | convertire tutto subito | veloce in teoria | altissimo rischio lockout | alto | alto | no |
| B progressiva on-login | aggiungere hash/salt/versione, migrare al login valido | compatibile, controllabile | richiede adapter e periodo transitorio | medio | medio/alto | consigliata dopo fase D |
| C reset forzato | invalidare legacy e reset utenti | sicurezza forte | impatto utenti/assistenza | medio | alto | solo se autorizzato |
| D preparatoria | eliminare email/sessione/URL password e ridurre enumeration senza schema | riduce rischio subito | non risolve hash | basso | basso/medio | parzialmente eseguita con LOGIN-REGISTER-SECURITY-1 |

Conclusione: opzione D preparatoria e stata parzialmente eseguita con LOGIN-REGISTER-SECURITY-1; reset tokenizzato fase 1 e stato completato senza hash. Resta consigliata opzione B progressiva on-login dopo schema/manuale e audit gestionale.

Backlog consigliato post-audit:

- `LOGIN-REGISTER-SECURITY-1B`: chiuso con PR #117.
- `REMIND-RESET-1A`: audit/progettazione reset tokenizzato, completato read-only.
- `REMIND-RESET-BLUEPRINT-1B`: aggiornare Blueprint con progettazione reset.
- `REMIND-RESET-DB-MANUAL-1C`: manuale DB per Vincenzo, tabella token.
- `REMIND-RESET-DB-MANUAL-1D`: verifica manuale con Germano/Vincenzo.
- `REMIND-RESET-IMPLEMENT-1E`: implementazione `remind.aspx` / `resetpassword.aspx` senza hash.
- `REMIND-RESET-SMOKE-1F`: smoke controllato reset tokenizzato.
- `REGISTRATION-POLICY-1A` / `REGISTRATION-UX-1A`: completare modernizzazione registrazione.
- `GESTIONALE-PASSWORD-AUDIT-1A`: verifica con Vincenzo su `login.Password`, `vlogin`, `Newlogin`.
- `PASSWORD-HASH-SCHEMA-2B`: proposta campi DB/manuale per Vincenzo.
- `PASSWORD-HASH-MIGRATION-2C`: adapter legacy/hash e migrazione on-login.
- `AUTH-CSRF-AUDIT-1A`: audit `AntiCsrfPage` sui flussi auth.
- `AUTH-JS-LEGACY-AUDIT-1A`: audit errori JS legacy su `remind.aspx`/`registrazione.aspx`.

### 14.9 Progettazione reset password tokenizzato - REMIND-RESET-1A

Esito audit/progettazione: A.

| Campo | Valore |
| --- | --- |
| Branch analizzato | `frontend-rebuild` |
| HEAD analizzato | `1f61dd721a485080918fcb9ff8ad67e6738d861a` |
| Tipo audit | read-only |
| Backup importati | no |
| DB runtime interrogato | no |
| File repository modificati in audit | nessuno |
| Dati sensibili esposti | no |

Stato attuale reminder:

- `remind.aspx` oggi non invia piu la password esistente.
- Il flow e stato trasformato in reset tokenizzato fase 1 legacy-compatible.
- Il form richiede email e Codice fiscale oppure Partita IVA.
- Il submit non invia password e non fa enumeration.
- `remind.aspx.vb` genera token solo con un candidato valido e mostra sempre risposta generica.
- I metodi email legacy risultano disabilitati con `Exit Sub`.
- I blocchi email storici restano debito legacy da bonificare in task controllato, senza riportare valori sensibili.
- Reset tokenizzato fase 1 implementato e validato live.

Stato invio email:

- Sender reset tokenizzato implementato con email professionale, riferimenti aziendali e avvertenze anti-phishing.
- L'email legacy page-local resta disabilitata.
- L'infrastruttura email non e centralizzata.
- SMTP/config sono presenti nel sistema, ma valori, host, credenziali e destinatari reali non devono essere riportati.
- Ulteriori evoluzioni del sender richiedono audit controllato.

Stato `password.aspx`:

- `password.aspx` e la pagina canonica autenticata per cambio password.
- Policy attuale: minimo 8 caratteri, massimo 25 caratteri.
- Conferma password obbligatoria.
- Nuova password diversa dalla vecchia.
- `DataPassword` aggiornata solo su cambio password valido e riuscito.
- `password.aspx` non va trasformata in pagina reset anonima.
- Il reset futuro deve avere una pagina separata.

Requisiti reset tokenizzato:

- `remind.aspx` resta la pagina di richiesta reset.
- Risposta sempre generica anti-enumeration.
- Se l'account e valido e abilitato, generazione token.
- Invio email con link reset.
- Link verso pagina dedicata `resetpassword.aspx`.
- Utente imposta nuova password nella pagina reset.
- Token monouso, con scadenza breve e invalidazione dopo uso.
- Nessuna password inviata via email.
- Nessuna password in URL.
- Nessuna enumeration.
- Nessun dettaglio tecnico a video.

Pagine fase 1 operative:

| Pagina | Ruolo | Note |
| --- | --- | --- |
| `remind.aspx` | richiesta reset | email + CF/PIVA, risposta generica anti-enumeration, PRG/F5, card `sent=1` |
| `resetpassword.aspx` | pagina reset tokenizzato | token valido, policy password e conferma |
| `resetpassword.aspx.vb` | code-behind reset | verifica token, update legacy password/DataPassword, consumo token |
| pagina esito opzionale | conferma reset | non introdotta nella fase 1 |
| `password.aspx` | cambio password autenticato | resta separata dal reset anonimo |

Proposta DB token:

Nome consigliato tabella: `login_password_reset_tokens`.

Documento tecnico DB preparatorio: `docs/REMIND_RESET_DB_MANUALE_VINCENZO.md`.

Nota: il manuale e nato come proposta per Vincenzo. Dopo gate DB e runtime fase 1, la tabella risulta creata manualmente su `taikun` e il reset tokenizzato e operativo in modalita legacy-compatible. Il rollout su eventuali altri DB cliente/azienda resta separato.

| Campo | Scopo |
| --- | --- |
| `Id` | PK token |
| `LoginId` | riferimento a `login.id` |
| `TokenHash` | hash SHA-256/compatibile del token, unico |
| `CreatedAt` | creazione |
| `ExpiresAt` | scadenza, consigliato 30 minuti |
| `UsedAt` | valorizzato su uso |
| `IsRevoked`, `RevokedAt`, `RevokedReason` | revoca controllata |
| `Attempts` | limite tentativi |
| `RequestIpHash`, `UserAgentHash` | audit sanificato/opzionale |

Note DB:

- Salvare solo hash del token.
- Token in chiaro solo nel link email.
- Scadenza consigliata: 30 minuti.
- Indice univoco su `TokenHash`.
- Indice su `LoginId`.
- Pulizia periodica dei token scaduti.
- Compatibilita MySQL.
- Tabella gia creata manualmente su `taikun`; da creare in ogni altro DB cliente/azienda coinvolto solo con gate dedicato.
- Necessaria approvazione Vincenzo prima di qualunque ulteriore modifica DB.
- Il manuale `docs/REMIND_RESET_DB_MANUALE_VINCENZO.md` dettaglia schema, query indicative, transazione, rollout multi-azienda, rollback e checklist approvazione.
- Revisione Germano preliminare: tabella confermata come proposta per ogni DB cliente/azienda, non per `connessioni` o `city_registry`.
- Revisione Germano preliminare: no FK iniziale consigliata; `LoginId` resta riferimento logico indicizzato verso `login.id`.
- Revisione Germano/fase 1: flow legacy-compatible, quindi reset tokenizzato aggiorna ancora `login.Password` e `login.DataPassword`.
- Revisione Germano preliminare: il gestionale oggi ha dipendenza operativa dalla password in chiaro nella griglia utenti web; questa dipendenza e debito tecnico da chiudere prima della hash migration.
- `aziende.ScadenzaPassword` e policy aziendale in giorni; il reset riuscito aggiorna `login.DataPassword` ma non modifica `aziende.ScadenzaPassword`.
- Logica scadenza da preservare: `login.DataPassword + aziende.ScadenzaPassword`.

Sicurezza token:

- Almeno 256 bit generati da RNG crittografico.
- Storage solo hash token.
- Token monouso.
- Scadenza breve.
- Consumo atomico con `UsedAt IS NULL` e `ExpiresAt >= NOW()`.
- Invalidazione token precedenti opzionale.
- Rate limiting per email/account/IP hash.
- Messaggi generici.
- Logging sicuro senza token/password.
- Nessun token nei log.
- Minimizzare rischio token in referer.
- HTTPS obbligatorio.

Email reset:

- Oggetto generico.
- Link reset.
- Indicazione scadenza token.
- Testo tipo "se non hai richiesto tu il reset, ignora questa email o contatta l'assistenza".
- Nessuna password.
- Nessun dato sensibile.
- Nessun allegato.
- Compatibilita con configurazione SMTP esistente.
- Fallback assistenza se email non configurata.

Anti-enumeration:

- `remind.aspx` deve rispondere sempre con testo generico.
- Nessuna distinzione pubblica tra email inesistente, utente non abilitato o account bloccato.
- Link reset invalido/scaduto con messaggio generico.
- Evitare differenze di tempi eccessive se possibile.
- Nessun dettaglio tecnico a video.

Relazione con hash migration:

- Reset tokenizzato e prerequisito forte per futura hash migration.
- Nella prima fase puo aggiornare ancora `login.Password` legacy.
- In fase hash futura potra scrivere hash/salt/versione tramite adapter.
- Non deve dipendere dal recupero della vecchia password.
- Deve invalidare il token dopo cambio password.
- Deve aggiornare `DataPassword` solo su reset riuscito.

Impatto gestionale/Vincenzo:

- Il gestionale ha funzioni di reset password?
- Il gestionale legge/scrive `login.Password`?
- Il gestionale usa `DataPassword` / `ScadenzaPassword`?
- Il gestionale deve vedere i token?
- Serve una maschera gestionale per revocare token?
- Ci sono procedure o viste coinvolte?
- Deployment DB multi-azienda: come va gestito?
- La tabella token va creata in ogni DB cliente?

Decisioni preliminari Germano:

- Nome tabella confermato: `login_password_reset_tokens`.
- Tabella da creare in ogni DB cliente/azienda che usa il sito.
- Non creare la tabella nel DB `connessioni`.
- Non creare la tabella nel DB `city_registry`.
- No FK iniziale consigliata, salvo futura approvazione esplicita Vincenzo.
- Gestionale oggi con griglia "Accesso Utenti Web" che mostra password in chiaro.
- Fase 1 reset: legacy-compatible, nessun hash.
- Fase 1 reset: aggiornare `login.Password` e `login.DataPassword`.
- `aziende.ScadenzaPassword` governa la scadenza password in giorni.
- Durata token reset indipendente da `aziende.ScadenzaPassword`; consigliati 30 minuti.
- Futura schermata gestionale JANUS token reset utile, ma fuori scope ora.

Opzioni progettuali:

| Opzione | Descrizione | Esito |
| --- | --- | --- |
| A | Reset tokenizzato minimo, legacy password write | valida ma meno pronta per hash |
| B | Reset tokenizzato hash-ready, oggi scrive legacy | consigliata |
| C | Mantenere solo assistenza manuale | sicura ma non risolve UX |
| D | Rinviare reset e fare hash prima | troppo lenta per recupero accesso |

Conclusione: opzione consigliata B. Implementare reset tokenizzato hash-ready, senza hash migration ora, con adapter/struttura compatibile con futura migrazione.

Micro-task futuri:

- `REMIND-RESET-BLUEPRINT-1B`: aggiornare Blueprint con progettazione reset.
- `REMIND-RESET-DB-MANUAL-1C`: manuale DB per Vincenzo, tabella token.
- `REMIND-RESET-DB-MANUAL-1D`: verifica manuale con Germano/Vincenzo.
- `REMIND-RESET-IMPLEMENT-1E`: implementazione `remind.aspx` / `resetpassword.aspx` senza hash.
- `REMIND-RESET-SMOKE-1F`: smoke controllato.
- `PASSWORD-HASH-SCHEMA-2B`: schema hash/salt/versione.
- `PASSWORD-HASH-MIGRATION-2C`: migrazione progressiva.
- `GESTIONALE-RESET-TOKEN-UI-1A`: futura schermata gestionale JANUS per audit/revoca token reset.
- `GESTIONALE-PASSWORD-HASH-UI-1A`: adeguare gestionale per non mostrare o richiedere password in chiaro.

## 15. Sistema email transazionali

Riferimento operativo completo: `docs/KEEPSTORE_EMAIL_STANDARD.md`.

### 15.1 Stato attuale da audit EMAIL-SYSTEM-AUDIT-1A

Il sistema email e misto legacy/moderno:

- conferma ordine/preventivo inviata da `ordine.aspx.vb` tramite `SendEmail`, dopo creazione documento e commit;
- reset password tokenizzato inviato da `App_Code/PasswordResetTokenService.vb`, con HTML + plain text, token monouso e `TokenHash` su DB;
- registrazione e aggiornamento profilo inviano email da `registrazione.aspx.vb` tramite metodo `Email`, con contenuto migrato su `App_Code/KeepStoreEmailTemplate.vb`;
- `documenti.aspx` non invia direttamente documenti/fatture/proforma, ma inserisce richieste in `inviadocumenti`, da completare/verificare con processo esterno o gestionale;
- cambio password area account, reset completato, cambio stato ordine, spedizione/tracking ed email pagamento gateway dedicate non risultano inviate dal runtime web auditato;
- `mailconfig` esiste nello schema, ma non risulta usata direttamente dal runtime web auditato.

`EMAIL-ORDER-CONFIRMATION-1A` migra la conferma ordine/preventivo di `ordine.aspx.vb` al renderer standard `App_Code/KeepStoreEmailTemplate.vb` usando esclusivamente dati gia disponibili nel punto di invio: documento, righe, pagamento, spedizione, indirizzi e importi persistiti. Trigger, destinatario, BCC, SMTP, timing e condizioni di invio restano invariati; gateway, costi, totali, IVA, DB/schema e `web.config` non vengono modificati.

`EMAIL-AUTH-TEMPLATE-1A` migra gli invii registrazione nuovo cliente e aggiornamento profilo legacy di `registrazione.aspx.vb` al renderer standard `App_Code/KeepStoreEmailTemplate.vb`. Restano invariati destinatario, BCC aziendale, mittente e configurazione SMTP esistente; il contenuto passa a HTML/plain text coerente con lo standard email, senza password nel body. Reset/remind password, email ordine, DB/schema, gateway, carrello/checkout, `web.config`, appSettings e connection string restano fuori scope.

`EMAIL-PASSWORD-TEMPLATE-1A` migra il solo rendering dell'email reset/remind password tokenizzato di `App_Code/PasswordResetTokenService.vb` al renderer standard `App_Code/KeepStoreEmailTemplate.vb`. Il link reset continua a essere generato dal flow esistente e viene usato solo nel corpo email; generazione token, `TokenHash`, scadenza 30 minuti, validazione, consumo, revoca, destinatario, mittente, SMTP/config e anti-enumerazione restano invariati. Nessuna password viene inserita nel body; registrazione/profilo, email ordine, DB/schema, gateway, carrello/checkout e `web.config` restano fuori scope.

Il blocco email account/auth/password e chiuso lato static smoke: PR #175 e PR #176 sono mergeate, registrazione/profilo e reset/remind usano `KeepStoreEmailTemplate`, gli smoke statici sono A e non sono stati eseguiti invii live, creazioni utenti live o reset password reali. Il runtime rendering/smoke resta consentito solo in ambiente autorizzato con DB test, account test e SMTP sink; SMTP/config, DB/schema, gateway, carrello/checkout, prezzi/IVA, email ordine e token flow reset restano invariati.

`EMAIL-LEGACY-SENDS-CLEANUP-1A` / PR #177 classifica i residui email dopo la migrazione al template condiviso. `MailMessage` e `SmtpClient` restano trasporto SMTP vivo per ordine, registrazione/profilo e reset/remind; non vanno rimossi finche il trasporto non viene centralizzato in un task dedicato. Il fallback HTML legacy di `ordine.aspx.vb` resta prudenzialmente attivo solo se il renderer ordine fallisce; gli invii `Contattaci.aspx.vb` e `main.aspx.vb` sono fuori scope account/auth/password e l'import non usato in `documenti.aspx.vb` non blocca il runtime. Nessun codice e stato rimosso nel cleanup controllato per evitare cambi funzionali non richiesti.

Il blocco email migrato su `KeepStoreEmailTemplate` e chiuso a livello statico: email ordine, registrazione/profilo PR #175, reset/remind password PR #176, contatto legacy `main.aspx.vb` PR #178 e `Contattaci.aspx.vb` PR #179 usano il renderer condiviso o risultano stabilizzati sullo standard. Gli smoke statici registrazione/profilo, reset/remind, `main.aspx` contatto e `Contattaci.aspx.vb` sono A. Non sono state inviate email live, non sono stati creati utenti live e non sono state resettate password reali; SMTP/config, DB/schema, gateway, carrello/checkout, prezzi/IVA e `main` restano invariati. Eventuali smoke runtime richiedono ambiente autorizzato con DB test, account test e SMTP sink.

### 15.2 Dati DB coinvolti

Fonti dati ordine:

- documento: `documenti`, `vdocumenticompleta`, `vstampadocumento`;
- righe: `documentirighe`, `vdocumentirighe`;
- totali: `documentipie.TotImponibile`, `TotIva`, `TotaleDocumento`, `CostoSpedizione`, `CostoAssicurazione`, `CostoPagamento`, `TotSconto`;
- pagamento: `documenti.PagamentiTipoId`, `documenti.Pagato`, `documenti.StatoPagamentoWeb`, `documenti.IdTransazione`, `pagamentitipo.Descrizione`, `Informazioni`, `Contrassegno`, `OnLine`, `Banca`, `FE_Pagamento`;
- PayPal: `paypal_express_transazioni`;
- Banca Sella: `bancasella_impostazioni_azienda`, `bancasella_ordini_pagati`, `bancasella_log`;
- spedizione/tracking: `documentipie.VettoriId`, `documenti.Tracking`, `documentipie.Tracking`, `vettori.Descrizione`, `vettori.Informazioni`, `vettori.Link_Tracking`;
- azienda/logo: `aziende.RagioneSociale`, `email`, `Telefono`, `Piva`, `URL1`, `URL2`, `Logo`, `LogoWeb`, `Iban`, `SwiftCode`, `NomeBanca`, `Condizioni_vendita`, `Condizioni_privacy`;
- coda documento: `inviadocumenti`, view `vdatiinviadocumenti`.

Le credenziali SMTP restano dati sensibili: documentare solo i nomi campo (`Smtp`, `User_smtp`, `Password_smtp`), mai valori.

### 15.3 Architettura futura proposta

Separare in micro-componenti:

- motore email: helper unico in `App_Code`, invio SMTP, HTML + plain text, sanitizzazione e logging minimo;
- dati ordine: adapter read-only da documento/righe/totali;
- dati pagamento: adapter che traduce `pagamentitipo`, `Pagato`, `StatoPagamentoWeb` e gateway in stato testuale sicuro;
- dati spedizione: adapter vettore/tracking con link sanificati;
- template: layout table-based max 600/640 px, logo da DB, sezioni coerenti, CSS inline;
- preview/test: modalita di anteprima senza inviare email reali;
- log invio: da progettare, se non esiste gia un tracciamento gestionale sufficiente.

### 15.4 Standard funzionale

Ogni email transazionale deve:

- avere oggetto chiaro e specifico;
- distinguere stato ordine, pagamento e spedizione;
- includere solo dati necessari all'evento;
- avere CTA sicure verso ordine, area account, continua acquisti o assistenza;
- avere versione plain text;
- non includere password, token non necessari, dettagli tecnici, stack trace o transaction id completi non autorizzati;
- usare logo azienda da `aziende.LogoWeb` per header desktop/mobile e footer, con path `/Public/assets/images/logo/{LogoWeb}`, nome file sanificato e fallback interno controllato;
- per nuovi invii runtime, usare la fondazione `App_Code/KeepStoreEmailTemplate.vb`: renderer HTML/plain text, subject helper, microcopy pagamento/spedizione e sanitizzazione logo `LogoWeb`;
- negli invii email gli asset devono essere URL assoluti HTTPS; il logo email resta dinamico da `Aziende.LogoWeb`, non hardcoded, e i link a pagine protette devono passare da login con `ReturnUrl` locale sanificato;
- evitare asset esterni non controllati e percorsi legacy immagini del vecchio sito;
- usare solo font email-safe di sistema, senza Google Fonts/CDN o web font esterni;
- per righe prodotto email, usare immagini articolo da asset pubblici moderni con URL assoluto HTTPS, preferendo `_nomefile` compresso se disponibile, poi originale, con fallback robusto da candidati `Img1..Img6` articolo e senza base64 o allegati.
- per compatibilita Aruba/Webmail strette, evitare tabelle prodotto con molte colonne e header compressi; usare product card table-based con foto fissa e dettagli label/value, mantenendo riepiloghi importanti in layout verticale o massimo due colonne robuste.

### 15.5 Roadmap email

Task consigliati:

1. `EMAIL-ENGINE-1A`;
2. `EMAIL-ORDER-CONFIRMATION-1A`;
3. `EMAIL-BANKTRANSFER-1A`;
4. `EMAIL-COD-1A`;
5. `EMAIL-ORDER-STATUS-1A`;
6. `EMAIL-AUTH-TEMPLATE-1A`;
7. `EMAIL-PREVIEW-TEST-1A`;
8. `EMAIL-DELIVERABILITY-1A`.

Non implementare runtime email senza task dedicato e senza conferma delle fonti bonifico/gestionale con Germano/Vincenzo.

## 16. Registro modifiche tecniche

| Data | Task | PR | Commit | File modificati | Sintesi tecnica | Impatto funzionale | Note/debito residuo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-06-17 | CART-CHECKOUT-UX-SMOKE-FIX-1D | #194 | `1734e1ef8d5c2a78d87db6cf71b1bdf32176308d` | `carrello.aspx`, `cart-ui.css`, documentazione | REV2: `CartActionsWrap` fuori da `CartItemsWrap`, coupon visibile anche in checkout, CSS scoped `.ks-cart-page`, support panel nascosto in conferma | Risolve il nuovo smoke B sui tre step senza duplicare controlli server o cambiare logica business | PR aperta aggiornata; smoke manuale desktop/mobile richiesto; PR #191/coupon non toccati; nessun cambio a prezzi/IVA/totali, ordine/gateway, email, DB/schema/SP |
| 2026-06-17 | CART-CHECKOUT-UX-SMOKE-FIX-1E | #194 | `4ef5407b9871a0d18ad29b1bac00d74da5b4c28b` | `carrello.aspx`, `cart-ui.css`, documentazione | REV3: font leggibili ONSUS, step 1 coupon/riepilogo/azioni ordinati, step 2 coupon + indirizzo compatto + prodotti compatti, step 3 gerarchia finale con sola CTA primaria | Rifinitura finale smoke B REV2 senza cambiare logica business o controlli server | PR aperta aggiornata; smoke manuale desktop/mobile richiesto; PR #191/coupon sospesa/non toccata; nessun cambio a prezzi/IVA/totali, ordine/gateway, email, DB/schema/SP |
| 2026-06-18 | CART-CHECKOUT-UX-SMOKE-FIX-1F | #194 | `32308a1eb5caebada8fcf7e5e38475514d13e31b` | `carrello.aspx`, `cart-ui.css`, `cart-ui.js`, `checkout-ui.js`, documentazione | REV4: un solo handler quantita su `.ks-wg-quantity`, coupon step 2 spostato nello slot checkout con gli stessi controlli server, card indirizzi JS disabilitate a favore della select compatta | Corregge smoke REV3 B su +2 quantita, coupon assente in step 2 e lista indirizzi dispersiva | PR aperta aggiornata; smoke manuale richiesto; PR #191/coupon sospesa/non toccata; nessun cambio a logica sconto/indirizzi, prezzi/IVA/totali, ordine/gateway, email, DB/schema/SP |
| 2026-06-18 | CART-CHECKOUT-UX-SMOKE-FIX-1G | #194 | `b2681ee51c008fa078ef55206948d31cf52efa33` | `carrello.aspx.vb`, documentazione | REV5: `Panel_BuoniSconto.Visible` svincolato da `TableConteggi.Visible`; input sconto visibile se buoni abilitati, carrello con articoli e step non conferma | Corregge smoke REV4 B: il pannello sconto non veniva renderizzato nello step 2 | PR aperta aggiornata; smoke manuale richiesto; PR #191/coupon sospesa/non toccata; nessun cambio a validazione/calcoli sconto, prezzi/IVA/totali, ordine/gateway, email, DB/schema/SP |
| 2026-06-17 | CART-CHECKOUT-UX-SMOKE-FIX-1C | #194 | `f19e9ae6f643ca92b5ceaad8c48410e6da304e91` | `carrello.aspx`, `cart-ui.css`, documentazione | REV1: titolo step dinamico, layout carrello/riepilogo piu stabile, CSS checkout applicato a `.ks-checkout-shell`, sidebar riepilogo e CTA finale unica | Risolve il nuovo smoke B su carrello/checkout/conferma senza cambiare business logic | PR aperta aggiornata; smoke manuale desktop/mobile richiesto; PR #191/coupon non toccati; nessun cambio a prezzi/IVA/totali, ordine/gateway, email, DB/schema/SP |
| 2026-06-17 | CART-CHECKOUT-UX-SMOKE-FIX-1A | #194 | `715bcbf6882f51c90200a9d12a451283ab249091` | `carrello.aspx`, `cart-ui.css`, documentazione | Carica `cart-ui.css`, corregge bottone coupon assoluto, contrasto bottoni scuri e spacing checkout | Risolve smoke B su coupon non visibile, pulsanti illeggibili e checkout compresso senza cambiare logica | PR aperta; smoke manuale desktop/mobile richiesto; PR #191/coupon non toccati; nessun cambio a prezzi/IVA/totali, ordine/gateway, email, DB/schema/SP |
| 2026-06-17 | CART-DISCOUNT-FIELD-UX-1A | #193 | `376898aea8c483e2087442cad43aca08dfd7d335` | `carrello.aspx`, `cart-ui.css`, documentazione | Pannello buono sconto reso esplicito con titolo, microcopy, placeholder, bottone `Applica` e layout responsive | Il campo codice sconto diventa visibile e leggibile senza cambiare logica sconto o postback | PR aperta; smoke manuale desktop/mobile richiesto; PR #191/coupon non toccata; nessun cambio a prezzi/IVA/totali, ordine/gateway, email, DB/schema/SP |
| 2026-06-15 | AUTH-LEGACY-DUPLICATE-AUDIT-FIX-1A | #187 | `52d9fd15e1fd1796f45e335542670d84736378ed` | `resetpassword.aspx`, documentazione | Nasconde il reveal nativo browser sui due campi password del reset, preservando i toggle custom | Evita doppio controllo visivo su reset password senza cambiare token flow o auth | PR da review/merge; nessun cambio a code-behind, sessioni/cookie, registrazione, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali |
| 2026-06-15 | CART-LEGACY-DUPLICATE-AUDIT-FIX-1A | #186 | `38cdab5a76c305940d8735cbf21b3ecc96406959` | `carrello.aspx.vb`, documentazione | Nasconde `CartItemsWrap` durante lo step checkout per evitare doppio rendering con shell checkout e riepilogo laterale | Un solo carrello principale visibile nel percorso checkout, preservando controlli server e flussi esistenti | PR mergeata; smoke `SMOKE CART CHECKOUT UI: A`; nessun cambio a ordine, `Carrello_Documento`, DB/schema/SP, gateway, email/template, prezzi/IVA/totali/righe |
| 2026-06-13 | CART-ADDRESS-ERROR-MESSAGE-1A | #185 | `d3b5de9097328b8b28b6729d899d36e1402e6508` | `carrello.aspx.vb`, documentazione | Alert carrello per `addresserror=1` dopo guard indirizzo ordine | L'utente riceve istruzione chiara quando l'indirizzo selezionato non e piu valido | PR mergeata; smoke `SMOKE CART ADDRESS ERROR: A`; nessun valore querystring riflesso, nessun cambio ordine, DB/schema/SP, gateway, email/template, prezzi/IVA/totali/righe |
| 2026-06-13 | LOGIN-PASSWORD-TOGGLE-1A | #184 | `a1851c52dc1fb03af40a94618c068a5168504ff5` | `login.aspx`, documentazione | Nasconde il reveal nativo browser sul campo password login lasciando il toggle custom come unico controllo visibile | Elimina il doppio "Mostra password" senza cambiare login/auth | PR mergeata e smoke manuale A; `login.aspx.vb`, sessione/cookie, registrazione/reset/remind, DB/schema/SP, checkout/gateway/email fuori scope |
| 2026-06-13 | ACCOUNT-ADDRESS-ORDER-GUARD-1A | #183 | `d7ca913aec57a5f5aebb1537ef08de07a71b3124` | `ordine.aspx.vb`, documentazione | Guard ownership su `SCEGLIINDIRIZZO > 0` prima di `Carrello_Documento` | Blocca ordine se l'indirizzo alternativo selezionato non appartiene all'utente o non e valido | PR mergeata; smoke statico A; runtime solo con ambiente sicuro; nessun cambio DB/schema/SP, carrello, gateway, email/template, prezzi/IVA/totali |
| 2026-06-13 | DOCS-ACCOUNT-AREA-UI-CLOSE-1A | n/a | n/a | documentazione | Chiusura Area Cliente UI/datiutente dopo smoke manuale A | PR #180/#181/#182 e audit duplicati confermati chiusi | Nessun codice, DB/schema/SP, checkout/carrello/ordine/gateway/email modificato |
| 2026-06-13 | ACCOUNT-AREA-LEGACY-DUPLICATES-1A | n/a | n/a | documentazione | Audit statico post-merge PR #182 su pagine account, sidebar e CSS | Nessun duplicato legacy evidente residuo fuori layout; nessun fix applicativo aggiuntivo | Smoke manuale UI area account esito A |
| 2026-06-13 | ACCOUNT-DATIUTENTE-UI-FIX-1A | #182 | `a0023fbc7b27e06a2f82aea49c475576b7fcdb38` | `datiutente.aspx`, `Public/assets/keepstore/css/datiutente-ui.css`, documentazione | Rimozione blocco legacy duplicato fuori layout da pagina dati utente | Lascia una sola UI account coerente e mantiene la sezione legacy solo dentro la card moderna | `datiutente.aspx.vb`, DB/schema/SP, checkout/carrello/ordine, email/template, registrazione e pagine account moderne fuori scope; PR mergeata |
| 2026-06-13 | ACCOUNT-DATIUTENTE-UI-1A | #181 | `bd26979e7d9572fe03a864aa6de18ec6f862dbfc` | `datiutente.aspx`, `Public/assets/keepstore/css/datiutente-ui.css`, documentazione | Sistemazione UI pagina legacy dati utente: card ponte account, CTA verso pagine moderne e sezione legacy incapsulata | Rende la pagina compatibile meno vuota/grezza senza cambiare salvataggi o ownership PR #180 | DB/schema/SP, checkout/carrello/ordine, email/template, registrazione e pagine account moderne fuori scope; PR mergeata |
| 2026-06-13 | ACCOUNT-DATIUTENTE-VALIDATION-1A | #180 | `82c85d13d73128824613018f3975b22fe9165569` | `datiutente.aspx.vb`, documentazione | Hardening minimo pagina legacy dati utente: ownership `LoginId`/`UtentiId`, validazioni server-side leggere e messaggi non tecnici | Riduce rischio modifica dati non coerenti o non appartenenti all'utente loggato senza rifare la pagina legacy | DB/schema/SP, checkout/carrello/ordine, email/template, registrazione e pagine account moderne fuori scope; PR mergeata |
| 2026-06-13 | EMAIL-CONTATTI-TEMPLATE-1A | #179 | `fe75c8874fca5d9ae6ecf436f76c3f51a1c085f6` | `Contattaci.aspx.vb`, documentazione | Migrazione body email contatto di `Contattaci.aspx.vb` al renderer standard HTML/plain text | Uniforma il form Contattaci al template email condiviso mantenendo mittente/destinatario/Reply-To e SMTP esistenti | `main.aspx.vb`, ordine, registrazione/profilo, reset/remind, DB/schema, gateway e carrello/checkout fuori scope; invio live non eseguito |
| 2026-06-13 | EMAIL-MAIN-CONTACT-CLEANUP-1A | #178 | `f5132b24413dd91b3c29a74317468559fe856c89` | `main.aspx.vb`, `App_Code/KeepStoreEmailTemplate.vb`, documentazione | Messa in sicurezza invio contatto legacy di `main.aspx.vb`: body su renderer standard, From aziendale, Reply-To utente e messaggio errore non tecnico | Riduce rischio spoofing mittente, HTML raw e leak `ex.Message` senza cambiare SMTP/config | `Contattaci.aspx.vb`, ordine, registrazione/profilo, reset/remind, DB/schema, gateway e carrello/checkout fuori scope; futuro `EMAIL-CONTATTI-TEMPLATE-1A` separato |
| 2026-06-13 | EMAIL-PASSWORD-TEMPLATE-1A | #176 | `49ee7888f10eddcbe65b96ba257b94657bc9d880` | `App_Code/PasswordResetTokenService.vb`, `App_Code/KeepStoreEmailTemplate.vb`, documentazione | Migrazione rendering email reset/remind password tokenizzato al renderer standard HTML/plain text | Email reset piu coerente con lo standard KeepStore senza cambiare il token flow | Smoke statico `EMAIL-PASSWORD-TEMPLATE-1C = A`; generazione/validazione/scadenza/consumo token, SMTP/config, DB/schema, registrazione/profilo, email ordine, gateway e carrello/checkout invariati; smoke runtime solo con SMTP sink/test |
| 2026-06-13 | EMAIL-AUTH-TEMPLATE-1A | #175 | `6f11e652f5b20d78dbdaac46da808edebd774568` | `registrazione.aspx.vb`, `App_Code/KeepStoreEmailTemplate.vb`, documentazione | Migrazione email registrazione/profilo al renderer standard HTML/plain text | Email account/auth piu coerenti e senza body HTML legacy hardcoded | Smoke statico `EMAIL-AUTH-SMOKE-1A = A`; nessun reset/remind, ordine, SMTP/config, DB/schema, gateway, carrello/checkout o `web.config` modificato |
| 2026-06-10 | EMAIL-ORDER-CONFIRMATION-1A | branch PR | pending | `ordine.aspx.vb`, documentazione | Migrazione conferma ordine/preventivo al renderer standard HTML/plain text con microcopy pagamento/spedizione e fallback legacy | Email ordine piu coerente e professionale | Nessun gateway, totale, DB/schema, SMTP o `web.config` modificato; invio live non testato in PR |
| 2026-06-11 | EMAIL-ORDER-CONFIRMATION-PRO-1A | branch PR | pending | `ordine.aspx.vb`, `App_Code/KeepStoreEmailTemplate.vb`, documentazione | Rifinitura conferma ordine: causale bonifico completa, tabella prodotti con foto/codice/EAN/prezzi, footer `Aziende`, vettori deduplicati e caption IVA prodotti | Email ordine piu completa e professionale | Nessun gateway, totale/costo reale, DB/schema, SMTP o `web.config` modificato; smoke live demandato a Germano |
| 2026-06-11 | EMAIL-ORDER-CONFIRMATION-FINAL-POLISH-1A | branch PR | pending | `ordine.aspx.vb`, `App_Code/KeepStoreEmailTemplate.vb`, documentazione | Polish finale email ordine: copy CTA, nota legale documento vendita, font email-safe, riepilogo ordine leggibile e fallback foto articolo `Img1..Img6` | Email conferma ordine piu chiara e robusta | Nessun gateway, totale/costo reale, DB/schema, SMTP, `web.config` o vecchi invii rimossi |
| 2026-06-12 | EMAIL-ORDER-CONFIRMATION-ARUBA-COMPAT-1A | branch PR | pending | `App_Code/KeepStoreEmailTemplate.vb`, documentazione | Compatibilita Aruba Webmail: prodotti in card label/value e riepiloghi verticali invece di tabelle strette multi-colonna | Email conferma ordine piu leggibile in webmail strette senza cambiare dati | Nessun SMTP, MIME, gateway, totale/costo reale, DB/schema, checkout/sessione o `web.config` modificato |
| 2026-06-09 | EMAIL-ENGINE-1A | branch PR | pending | `App_Code/KeepStoreEmailTemplate.vb`, documentazione | Fondazione renderer email HTML/plain text, subject helper, logo `LogoWeb` e microcopy pagamento/spedizione | Base runtime per migrare invii futuri | Nessun invio reale migrato, nessun SMTP/web.config/DB/gateway modificato |
| 2026-06-09 | EMAIL-SYSTEM-AUDIT-1A | branch PR | pending | `docs/KEEPSTORE_EMAIL_STANDARD.md`, masterplan, blueprint | Audit sistema email transazionali e standard Taikun | Base per motore email futuro | Solo docs, nessun runtime/DB/gateway modificato |
| 2026-05-29 | ACCOUNT-PROFILE-1B | #100/#101/#102 | `f0eeccc...`, `7bfd40c...`, `919b342...` | account profile/sidebar | Profilo account ONSUS e sidebar root/active | Profilo stabilizzato | Cleanup inline non completo all'epoca |
| 2026-05-29 | ACCOUNT-ADDRESS-1B | #107 | `a4381b83ec5c617c6dc75022d30580ded5394f62` | `Page.master.vb`, `my-account-address.aspx` | Indirizzi read-only ONSUS | Pagina indirizzi stabile | Add/edit/delete rimandati |
| 2026-05-29 | ACCOUNT-SIDEBAR-INLINE-CLEANUP-2B | #109 | `7fe10f0edfbc7b7d5951116697c6654a100ba60f` | `Page.master.vb`, `documenti.aspx` | AccountSidebar globale su documenti e selector dinamico | Lista documenti stabile | Nessun gateway diretto |
| 2026-05-29 | ACCOUNT-PASSWORD-SECURITY-1B | #111 | `90c13d3bb41ff8d437f3cc9605a736659b04f4ce` | password flow/account link | `password.aspx` canonica e redirect legacy | Cambio password stabilizzato | Hash non implementato |
| 2026-05-29 | ACCOUNT-PASSWORD-SECURITY-1I | #112 | `3d1873f5e3ea071ef187cc906f5d8712a58a09e6` | `password.aspx.vb` | Hotfix validazioni atomiche conferma password | Nessun update su validazioni fallite | Login/register legacy da audit |
| 2026-06-05 | LOGIN-REGISTER-1A | audit | n/a | nessuno | Audit read-only login/registrazione/remind | Rischi legacy mappati | Hash migration da pianificare |
| 2026-06-05 | BLUEPRINT-1A | #114 | `0e030f8...` | `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` | Creazione blueprint tecnico permanente | Nuova base documentale stabile | Da mantenere in parallelo al masterplan |
| 2026-06-05 | BLUEPRINT-1B | #114 | branch PR | `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` | Integrazione backup database cliente/azienda, city registry e connessioni gestionale | Conoscenza architetturale e preparazione audit DB futuri | Nessun backup estratto/importato, nessun dato sensibile esposto |
| 2026-06-05 | DB-BACKUP-AUDIT-1A / DB-BACKUP-BLUEPRINT-1B | documentale | branch PR | `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` | Integrazione mappa sanificata dei tre database KeepStore | Nessun runtime; alta utilita per progettare login/hash/registrazione/gestionale | Nessun backup importato, nessun dato sensibile esposto |
| 2026-06-05 | DB-BACKUP-BLUEPRINT-1C-FIX | documentale | branch PR | `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` | Correzione nota `vlogin` / `Newlogin` | Distingue backup operativo, schema versionato e codice legacy | Nessun file SQL modificato, nessun dato sensibile esposto |
| 2026-06-05 | PASSWORD-HASH-AUDIT-2A / PASSWORD-HASH-BLUEPRINT-2B | documentale | branch PR | `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` | Integrazione audit hash/password, flussi auth legacy e opzioni migrazione | Nessun runtime; base tecnica per mitigazione e futura hash migration | Nessun codice/DB modificato, nessun dato sensibile esposto |
| 2026-06-05 | LOGIN-REGISTER-SECURITY-1B/1H/1I | #117 | `f51ab9a4df9afb71760a31db97ed0eac547cd9c3` | `Page.master.vb`, `login.aspx.vb`, `registrazione.aspx`, `registrazione.aspx.vb`, `registrazioneok.aspx`, `remind.aspx`, `remind.aspx.vb` | Mitigazioni immediate login/registrazione/reminder senza schema change | Riduzione esposizione password e enumeration | Nessun hash, nessun DB change, nessun utente/password/email reale modificato/inviato |
| 2026-06-05 | REMIND-RESET-1A / REMIND-RESET-BLUEPRINT-1B | documentale | branch PR | `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` | Progettazione reset password tokenizzato hash-ready | Nessun runtime; base tecnica per futuro reset sicuro | Nessun codice/DB modificato, nessun dato sensibile esposto |
| 2026-06-05 | REMIND-RESET-DB-MANUAL-1C | documentale | branch PR | `docs/REMIND_RESET_DB_MANUALE_VINCENZO.md`, `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` | Manuale tecnico DB per Vincenzo sulla tabella reset token | Nessun runtime; base per approvazione DB futura | Nessun codice/DB modificato, nessuna tabella creata, nessun dato sensibile esposto |
| 2026-06-05 | REMIND-RESET-DB-REVIEW-1G | documentale | branch PR | `docs/REMIND_RESET_DB_MANUALE_VINCENZO.md`, `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` | Integrazione feedback Germano: strategia legacy-compatible, tabella per DB cliente, no FK iniziale, `aziende.ScadenzaPassword`, futura UI JANUS token reset | Nessun runtime; chiarisce impatto gestionale e scadenza password | Nessun codice/DB modificato, nessuna tabella creata, nessun dato sensibile esposto |
| 2026-06-07 | ACCOUNT-PROFILE-ADDRESS-CLOSE-1A | #136-#145 | `6160bd8...` - `1fe259a...` | account profile/address/login docs | Chiusura blocco account profilo/indirizzi: dashboard profilo, dettagli account, indirizzi autonomi e smoke live finale | Area account profilo/indirizzi stabile | Il follow-up carrello indirizzi e stato poi chiuso nel blocco #147-#150; nessun DB/schema modificato |
| 2026-06-09 | CART-INLINE-ADDRESS-CITYREGISTRY-STEP | #147-#150 | `5c4ec079...` - `b41cc367...` | `carrello.aspx`, `carrello.aspx.vb`, `documentidettaglio.aspx`, docs | Carrello ONSUS con selezione indirizzi, add/edit inline, lookup CAP da `city_registry` e step `Conferma` | Carrello stabile post-smoke live | Nessun gateway/core checkout, costi/totali, DB/schema o SQL modificato |
| 2026-06-09 | ORDER-CONFIRMATION-UX-1A | PR da verificare | branch task | `documentidettaglio.aspx`, `documentidettaglio.aspx.vb`, `Public/assets/keepstore/css/order-ui.css`, docs | Hero conferma ordine, card post-acquisto, stampa/copia numero ordine e timeline locale | Migliora touchpoint post-acquisto e dettaglio storico | Nessun gateway core, totali/costi, DB/schema o SQL modificato; smoke live richiesto |

## 17. Debito tecnico e backlog architetturale

- Hash/migrazione password non implementati.
- Password legacy ancora in chiaro nel DB e nel meccanismo login.
- Assenza campi hash/salt/versione.
- Audit hash/login/registrazione/reset completato in `PASSWORD-HASH-AUDIT-2A`; resta da scegliere la strategia implementativa.
- `vlogin` / `Newlogin` da riconciliare fra backup operativo, schema versionato, codice e gestionale.
- Gestione hash richiede coordinamento con Vincenzo.
- `remind.aspx` sostituito con reset tokenizzato fase 1 legacy-compatible.
- Reminder automatico password disabilitato; reset tokenizzato operativo.
- Tabella token reset creata manualmente su `taikun`; rollout su eventuali altri DB cliente/azienda resta separato.
- Email reset implementata con template professionale e avvertenze anti-phishing.
- Reminder oggi genera token solo con un candidato valido email + CF/PIVA.
- Warning legacy `remind.aspx.vb` da bonificare in task controllato non urgente.
- DB/schema reset tokenizzato approvato ed eseguito manualmente su `taikun`; ulteriori DB richiedono gate dedicato.
- Manuale DB disponibile in `docs/REMIND_RESET_DB_MANUALE_VINCENZO.md` e aggiornato con la chiusura fase 1.
- Gestionale oggi dipendente dalla password web in chiaro; incompatibile con futura hash migration.
- `aziende.ScadenzaPassword` documentato come policy aziendale in giorni; reset tokenizzato non deve modificarlo.
- Relazione scadenza password documentata: `login.DataPassword + aziende.ScadenzaPassword`.
- Futura schermata gestionale JANUS token reset da progettare in `GESTIONALE-RESET-TOKEN-UI-1A`.
- Futura rimozione visualizzazione password in chiaro dal gestionale da progettare in `GESTIONALE-PASSWORD-HASH-UI-1A`.
- Registrazione mitigata, ma da modernizzare lato UX e sicurezza.
- Login mitigato nei messaggi, ma ancora legacy e senza hash.
- Gestione password via email/sessione/URL mitigata in LOGIN-REGISTER-SECURITY-1; mantenere guardrail e completare reset/hash.
- `AntiCsrfPage` da valutare sulle auth pages e sulle pagine con azioni state-changing.
- Rigenerazione sessione post-login da verificare/implementare.
- Errori JS legacy su `remind.aspx`/`registrazione.aspx` da valutare in task separato.
- `datiutente.aspx` legacy/compatibilita con tab/JS e gestione salvataggi/destinazioni.
- Delete indirizzi non migrato; add/edit sedi alternative e predefinito sono ora su `my-account-address.aspx`.
- Carrello indirizzi/CAP/step `Conferma` chiuso con `CART-ADDRESS-SELECTION`, `CART-INLINE-ADDRESS-PAYPAL-RETURN` e `CART-INLINE-ADDRESS-CITYREGISTRY-STEP`; non riaprire salvo bug live verificato. Gateway/core checkout e pagamenti restano task separati.
- Cleanup sidebar/nav inline legacy account verificato da `ACCOUNT-AREA-LEGACY-DUPLICATES-1A`: nessun duplicato evidente residuo fuori layout da correggere.
- `LOGIN-REGISTER-SECURITY-1B`: chiuso con PR #117.
- `REMIND-RESET-1A`: audit/progettazione reset tokenizzato, completato read-only.
- `REMIND-RESET-BLUEPRINT-1B`: aggiornare Blueprint con progettazione reset.
- `REMIND-RESET-DB-MANUAL-1C`: manuale DB per Vincenzo, tabella token.
- `REMIND-RESET-DB-MANUAL-1D`: verifica manuale con Germano/Vincenzo.
- `REMIND-RESET-IMPLEMENT-1E`: implementazione `remind.aspx` / `resetpassword.aspx` senza hash.
- `REMIND-RESET-SMOKE-1F`: smoke controllato.
- `REGISTRATION-POLICY-1A` / `REGISTRATION-UX-1A`: completare modernizzazione registrazione.
- `GESTIONALE-PASSWORD-AUDIT-1A`: verifica con Vincenzo su `login.Password`, `vlogin`, `Newlogin`.
- `GESTIONALE-RESET-TOKEN-UI-1A`: futura griglia JANUS per token reset.
- `GESTIONALE-PASSWORD-HASH-UI-1A`: rimozione dipendenza gestionale da password in chiaro.
- `PASSWORD-HASH-SCHEMA-2B`: proposta campi DB/manuale per Vincenzo.
- `PASSWORD-HASH-MIGRATION-2C`: adapter legacy/hash e migrazione on-login.
- `AUTH-CSRF-AUDIT-1A`: audit `AntiCsrfPage` sui flussi auth.
- `AUTH-JS-LEGACY-AUDIT-1A`: audit errori JS legacy su `remind.aspx`/`registrazione.aspx`.
- Integrazione gestionale da considerare prima di modifiche DB/hash.
- `DB-BACKUP-AUDIT-1A`: audit read-only dei tre backup per mappa tabelle/view/procedure, senza dati sensibili.
- `DB-BACKUP-BLUEPRINT-1B`: aggiornamento blueprint con mappa DB sanificata.
- `DB-MULTITENANT-AUDIT-1A`: audit del modello multi-azienda/multi-database e relazione con `connessioni`.
- `CITY-REGISTRY-AUDIT-1A`: audit citta/CAP usati in registrazione sito e gestionale.
- Task Vincenzo/manuale tecnico: documento operativo per modifiche DB richieste e coordinamento gestionale.

## 18. Sezione brochure sintetica

Questa sezione raccoglie materiale prudente e riusabile per una brochure tecnica o commerciale sintetica. Non contiene promesse non verificate.

### 17.1 Punti di forza ecommerce

- Piattaforma ecommerce collegata a logiche gestionali KeepStore.
- Area cliente con dashboard, profilo, ordini/documenti, wishlist e cambio password.
- Supporto documenti/ordini con stati ordine e pagamento separati.
- Integrazione pagamenti PayPal Express NVP stabilizzata in modalita controllata.
- Architettura WebForms consolidata e progressivamente modernizzata con template ONSUS.

### 17.2 Funzionalita chiave

- Catalogo prodotti e ricerca.
- Schede prodotto.
- Carrello e checkout.
- Area account.
- Documenti/ordini e dettaglio ordine.
- Wishlist.
- Coupon/promozioni.
- Email/notifiche legacy.
- Integrazione con database gestionale.

### 17.3 Caratteristiche distintive

- Refactoring progressivo senza rompere i contratti gestionali esistenti.
- Separazione tra stato ordine e stato pagamento.
- AccountSidebar condivisa e navigazione account coerente.
- Documentazione operativa e blueprint tecnico mantenuti in parallelo.

### 17.4 Vantaggi operativi

- Continuita su codice legacy.
- Migrazioni graduali e verificabili.
- Smoke test desktop/mobile sui refactor principali.
- Guardrail forti su DB, pagamenti, carrello e dati sensibili.

### 17.5 Automazioni

Da completare con audit dedicato. Sono presenti flussi automatici/legacy collegati a email, carrello, PayPal recheck e gestione sessione.

### 17.6 Integrazione gestionale

La piattaforma web usa dati e contratti collegati al gestionale KeepStore. Ogni modifica a DB, password, documenti, ordini o indirizzi deve valutare compatibilita gestionale.

### 17.7 Area cliente

Area cliente modernizzata nelle pagine principali: dashboard, profilo, indirizzi read-only, documenti, wishlist e cambio password.

### 17.8 Documenti/ordini

Lista documenti con selector dinamico e dettaglio ordine con stato ordine/pagamento separato. Retry pagamento gestito nel dettaglio quando previsto, non nella lista.

### 17.9 Sicurezza e sviluppo evolutivo

Il cambio password account e stabilizzato e i flussi login/registrazione/reminder sono oggetto di progressivo consolidamento e riduzione dei rischi legacy. Il reset password tokenizzato fase 1 e operativo e validato live; hash/migrazione password, CSRF auth e ulteriore modernizzazione registrazione restano backlog prioritari.

## 19. Glossario

| Termine | Definizione |
| --- | --- |
| AccountSidebar | Controllo condiviso per navigazione account. |
| ONSUS | Template/linea UX usata come riferimento per refactor moderni. |
| WebForms | Framework ASP.NET a pagine/eventi server usato da KeepStore. |
| code-behind | File VB.NET associato a pagina/controllo ASPX/ASCX. |
| master page | Layout principale condiviso delle pagine WebForms. |
| DataPassword | Campo/sessione usato per data cambio password. |
| ScadenzaPassword | Valore configurativo/sessione per scadenza password. |
| legacy | Codice o flow storico non ancora modernizzato. |
| smoke test | Verifica funzionale mirata su ambiente reale o locale. |
| PR | Pull request GitHub verso branch base. |
| merge commit | Commit creato dal merge non squash/non rebase. |
| hash migration | Migrazione da password legacy in chiaro a password hashata. |

## 20. Regole per aggiornamenti futuri

Da BLUEPRINT-1A in poi, ogni task con modifica funzionale o audit rilevante deve valutare se aggiornare:

- `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`
- `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md`

Regola pratica:

- Masterplan = operativo/stato avanzamento, task, merge, smoke, cleanup, prossimi step.
- Blueprint = architettura, funzionalita, mappe tecniche, flussi, DB noto, componenti, debiti stabili e conoscenza riusabile.

Se un task cambia una pagina, un flow, una tabella, un componente condiviso, una policy di sicurezza o una integrazione, il blueprint deve essere aggiornato o esplicitamente marcato come non impattato nel report del task.

Quando si lavora su login, registrazione, utenti, indirizzi o documenti, verificare se l'impatto riguarda anche il gestionale e i database condivisi. Quando si lavora sulla registrazione, considerare sempre il registry `city_registry`. Quando si lavora su configurazione clienti/aziende, indirizzamento gestionale o multi-tenant, considerare sempre il registry `connessioni`.
