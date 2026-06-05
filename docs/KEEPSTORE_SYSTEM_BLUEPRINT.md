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
- [11. Funzionalita ecommerce](#11-funzionalita-ecommerce)
- [12. Area account - stato consolidato](#12-area-account---stato-consolidato)
- [13. Login, registrazione e recupero password - audit LOGIN-REGISTER-1A](#13-login-registrazione-e-recupero-password---audit-login-register-1a)
- [14. Registro modifiche tecniche](#14-registro-modifiche-tecniche)
- [15. Debito tecnico e backlog architetturale](#15-debito-tecnico-e-backlog-architetturale)
- [16. Sezione brochure sintetica](#16-sezione-brochure-sintetica)
- [17. Glossario](#17-glossario)
- [18. Regole per aggiornamenti futuri](#18-regole-per-aggiornamenti-futuri)

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

La sicurezza password e stata consolidata nel flow account, ma hash/migrazione password non sono ancora implementati. Login, registrazione e recupero password restano legacy e richiedono un piano separato.

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
| `carrello.aspx` | `carrello.aspx.vb` | Carrello | da completare con audit dedicato | `carrello`, sessione, login | Non toccare senza task checkout |
| `ordine.aspx` | `ordine.aspx.vb` | Checkout/ordine | da completare con audit dedicato | ordine, pagamento, spedizione | Perimetro sensibile |
| `pagamento.aspx` | `pagamento.aspx.vb` | Pagamento legacy | da completare con audit dedicato | documenti/pagamenti | Perimetro gateway |
| `paypalcheckout.aspx` | `paypalcheckout.aspx.vb` | PayPal Express launcher | stabilizzato lato PayPal | PayPal NVP, documenti | Non invocare senza task |
| `paypalreturn.aspx` | `paypalreturn.aspx.vb` | Return PayPal | stabilizzato lato PayPal | token, transaction state | Non invocare senza task |
| `paypalrecheck.aspx` | `paypalrecheck.aspx.vb` | Recheck pending PayPal | stabilizzato lato PayPal | `GetTransactionDetails` | Non invocare senza task |
| `documentidettaglio.aspx` | `documentidettaglio.aspx.vb` | Dettaglio documento/ordine | stabile ONSUS | documento, righe, pagamento | Pay Now solo se azione reale |
| `documenti.aspx` | `documenti.aspx.vb` | Lista documenti/ordini | stabile ONSUS account | `sdsTipo`, documenti | Selector dinamico |
| `myaccount.aspx` | `myaccount.aspx.vb` | Dashboard account | stabile ONSUS | profilo, indirizzi, ordini recenti | AccountSidebar |
| `my-account-edit.aspx` | `my-account-edit.aspx.vb` | Profilo account | stabile ONSUS | login/utente/contatti | Salvataggi validati |
| `my-account-address.aspx` | `my-account-address.aspx.vb` | Indirizzi account read-only | stabile read-only ONSUS | indirizzo fatturazione/destinazioni | Gestione legacy rimandata |
| `wishlist.aspx` | `wishlist.aspx.vb` | Wishlist utente | stabile account | wishlist/prodotti | AccountSidebar globale |
| `password.aspx` | `password.aspx.vb` | Cambio password canonico | stabile account | `login.Password`, `DataPassword` | Hash non implementato |
| `cambiapassword.aspx` | `cambiapassword.aspx.vb` | Redirect legacy cambio password | stabile redirect | sessione login | Redirect verso `password.aspx` |
| `datiutente.aspx` | `datiutente.aspx.vb` | Dati utente legacy | legacy | profilo, indirizzi, destinazioni | Errore generico preesistente da audit |
| `login.aspx` | `login.aspx.vb` | Login | legacy auditato | `vlogin`, sessione | Password legacy in chiaro/case-insensitive |
| `registrazione.aspx` | `registrazione.aspx.vb` | Registrazione | legacy auditato | `utenti`, `login`, SP legacy | Policy non allineata |
| `registrazioneok.aspx` | `registrazioneok.aspx.vb` | Esito registrazione | legacy auditato | sessioni post-registrazione | Possibile parametro password nel flow coupon |
| `remind.aspx` | `remind.aspx.vb` | Recupero credenziali legacy | legacy auditato | `vlogin`, email | Da sostituire con reset tokenizzato |
| `accessonegato.aspx` | `accessonegato.aspx.vb` | Accesso negato | legacy semplice | sessione | Redirect se login presente |
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

Da completare con audit dedicato. Area sensibile: non modificare senza task carrello/checkout.

### 9.5 Checkout

Da completare con audit dedicato. Area sensibile: ordini, documenti, pagamento, spedizione.

### 9.6 Pagamenti

PayPal Express NVP e stato stabilizzato con token `EC-TOKEN` e transazioni `TXN` mascherate nei report. BancaSella resta legacy. Non invocare gateway senza task dedicato.

### 9.7 Area account

Area progressivamente stabilizzata con shell account ONSUS, `body.ks-page-account` e `AccountSidebar` globale su pagine consolidate.

### 9.8 Documenti/ordini

`documenti.aspx` lista documenti/ordini con selector dinamico `sdsTipo`; `documentidettaglio.aspx` dettaglio documento/ordine con stato ordine e stato pagamento separati.

### 9.9 Profilo utente

`my-account-edit.aspx` e pagina profilo ONSUS stabilizzata. `datiutente.aspx` resta legacy per parti non migrate.

### 9.10 Indirizzi

`my-account-address.aspx` e read-only ONSUS. Add/edit/delete indirizzi restano legacy in `datiutente.aspx` e richiedono audit separato.

### 9.11 Wishlist

`wishlist.aspx` stabilizzata con AccountSidebar globale.

### 9.12 Login

Legacy auditato in LOGIN-REGISTER-1A. Usa `vlogin`, sessione e confronto password case-insensitive; hash non implementato.

### 9.13 Registrazione

Legacy auditata in LOGIN-REGISTER-1A. Crea utente/login con stored procedure legacy e policy password non allineata al cambio password canonico.

### 9.14 Recupero password

`remind.aspx` e legacy: recupera/invia credenziali esistenti. Da sostituire con reset tokenizzato.

### 9.15 Cambio password

`password.aspx` e pagina canonica. Policy server-side 8-25, conferma obbligatoria, nuova diversa dalla vecchia, update centralizzato, `DataPassword` su successo. Hash non implementato.

### 9.16 Logout

`logout.aspx` chiude sessione e gestisce pulizia collegata al carrello. Da completare con audit sessione.

### 9.17 Accesso negato

`accessonegato.aspx` mostra accesso negato e redirecta a default se sessione login presente.

## 10. Database e tabelle

Non riportare valori sensibili. Documentare solo nomi tabelle/campi e relazioni funzionali. Non inserire connection string, password, hash, token, cookie, session id o dati personali.

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

## 11. Funzionalita ecommerce

| Funzionalita | Stato iniziale | Note |
| --- | --- | --- |
| Catalogo | da completare | Pagine `articoli.aspx`, `articolo.aspx` |
| Ricerca | da completare | Include suggest/search |
| Settori/categorie | da completare | App_Code e menu home collegati |
| Prodotto | da completare | Product detail e product card |
| Promozioni/prezzi | da completare | Promo, listini, coupon |
| Carrello | da completare | Perimetro sensibile |
| Ordini | parziale | Lista/dettaglio account stabilizzati |
| Documenti | stabile area account | Selector documenti dinamico |
| Pagamenti | parziale/stabilizzato PayPal | PayPal Express NVP stabilizzato; BancaSella legacy |
| Area cliente | consolidata su pagine principali | Sidebar/account shell |
| Wishlist | stabile | AccountSidebar globale |
| Coupon | da completare | Flow coupon legacy da audit |
| Email/notifiche | da completare | Reminder/registrazione hanno debiti security |
| Integrazione gestionale | da completare | Relazione DB/stored procedure/view |

## 12. Area account - stato consolidato

- `myaccount.aspx`: stabile.
- `my-account-edit.aspx`: stabile.
- `my-account-address.aspx`: stabile read-only ONSUS.
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

- `datiutente.aspx` resta legacy con tab/JS e gestione salvataggi/destinazioni.
- Gestione add/edit/delete indirizzi non migrata.
- Cleanup completo sidebar/nav inline legacy non ancora concluso su `datiutente.aspx`.

## 13. Login, registrazione e recupero password - audit LOGIN-REGISTER-1A

Esito audit: A.

| Campo | Valore |
| --- | --- |
| Branch analizzato | `frontend-rebuild` |
| HEAD analizzato | `9ee45ed5fb8f08b79bad29519d42d0c6d0958668` |
| Tipo audit | read-only |
| File modificati | nessuno |
| DB/gateway/carrello/checkout/ordine invocati | no |

### 13.1 Rischi principali

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

### 13.2 File analizzati

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

### 13.3 Meccanismo password rilevato

- Hash implementato: no.
- Password legacy in chiaro: si.
- Login: confronto password case-insensitive.
- Registrazione: password salvata lower-case.
- Recupero password: invio credenziali esistenti, non reset tokenizzato.
- Cambio password canonico: `password.aspx`, case-sensitive, policy 8-25, `DataPassword` aggiornata su successo.
- `cambiapassword.aspx`: redirect controllato verso `password.aspx`.

### 13.4 Session key rilevate

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

### 13.5 Tabella rischi audit

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

### 13.6 Piano consigliato audit

Opzione consigliata: B, migrazione hash progressiva, preceduta da micro-task preparatorio controllato.

Sequenza suggerita:

1. `LOGIN-REGISTER-SECURITY-1B`
2. `PASSWORD-HASH-AUDIT-2A`
3. `SECURITY-PASSWORD-HASH-2A`
4. `REMIND-RESET-1A`
5. `REGISTRATION-UX-1A`

## 14. Registro modifiche tecniche

| Data | Task | PR | Commit | File modificati | Sintesi tecnica | Impatto funzionale | Note/debito residuo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-05-29 | ACCOUNT-PROFILE-1B | #100/#101/#102 | `f0eeccc...`, `7bfd40c...`, `919b342...` | account profile/sidebar | Profilo account ONSUS e sidebar root/active | Profilo stabilizzato | Cleanup inline non completo all'epoca |
| 2026-05-29 | ACCOUNT-ADDRESS-1B | #107 | `a4381b83ec5c617c6dc75022d30580ded5394f62` | `Page.master.vb`, `my-account-address.aspx` | Indirizzi read-only ONSUS | Pagina indirizzi stabile | Add/edit/delete rimandati |
| 2026-05-29 | ACCOUNT-SIDEBAR-INLINE-CLEANUP-2B | #109 | `7fe10f0edfbc7b7d5951116697c6654a100ba60f` | `Page.master.vb`, `documenti.aspx` | AccountSidebar globale su documenti e selector dinamico | Lista documenti stabile | Nessun gateway diretto |
| 2026-05-29 | ACCOUNT-PASSWORD-SECURITY-1B | #111 | `90c13d3bb41ff8d437f3cc9605a736659b04f4ce` | password flow/account link | `password.aspx` canonica e redirect legacy | Cambio password stabilizzato | Hash non implementato |
| 2026-05-29 | ACCOUNT-PASSWORD-SECURITY-1I | #112 | `3d1873f5e3ea071ef187cc906f5d8712a58a09e6` | `password.aspx.vb` | Hotfix validazioni atomiche conferma password | Nessun update su validazioni fallite | Login/register legacy da audit |
| 2026-06-05 | LOGIN-REGISTER-1A | audit | n/a | nessuno | Audit read-only login/registrazione/remind | Rischi legacy mappati | Hash migration da pianificare |
| 2026-06-05 | BLUEPRINT-1A | da aprire | da aprire | `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` | Creazione blueprint tecnico permanente | Nuova base documentale stabile | Da mantenere in parallelo al masterplan |

## 15. Debito tecnico e backlog architetturale

- Hash/migrazione password non implementati.
- Audit hash/login/registrazione/reset da fare.
- `remind.aspx` da sostituire con reset tokenizzato.
- Registrazione da allineare a policy password unica.
- Login da normalizzare rispetto a confronto password e messaggi utente.
- Gestione password via email/sessione/URL da eliminare.
- `AntiCsrfPage` da valutare sulle auth pages e sulle pagine con azioni state-changing.
- Rigenerazione sessione post-login da verificare/implementare.
- `datiutente.aspx` legacy con errore generico preesistente.
- `datiutente.aspx` con tab/JS legacy e gestione salvataggi/destinazioni.
- Gestione add/edit/delete indirizzi non migrata.
- Cleanup completo sidebar/nav inline legacy su `datiutente.aspx` da completare.
- `LOGIN-REGISTER-SECURITY-1B` da decidere.
- `PASSWORD-HASH-AUDIT-2A` da pianificare.
- Integrazione gestionale da considerare prima di modifiche DB/hash.

## 16. Sezione brochure sintetica

Questa sezione raccoglie materiale prudente e riusabile per una brochure tecnica o commerciale sintetica. Non contiene promesse non verificate.

### 16.1 Punti di forza ecommerce

- Piattaforma ecommerce collegata a logiche gestionali KeepStore.
- Area cliente con dashboard, profilo, ordini/documenti, wishlist e cambio password.
- Supporto documenti/ordini con stati ordine e pagamento separati.
- Integrazione pagamenti PayPal Express NVP stabilizzata in modalita controllata.
- Architettura WebForms consolidata e progressivamente modernizzata con template ONSUS.

### 16.2 Funzionalita chiave

- Catalogo prodotti e ricerca.
- Schede prodotto.
- Carrello e checkout.
- Area account.
- Documenti/ordini e dettaglio ordine.
- Wishlist.
- Coupon/promozioni.
- Email/notifiche legacy.
- Integrazione con database gestionale.

### 16.3 Caratteristiche distintive

- Refactoring progressivo senza rompere i contratti gestionali esistenti.
- Separazione tra stato ordine e stato pagamento.
- AccountSidebar condivisa e navigazione account coerente.
- Documentazione operativa e blueprint tecnico mantenuti in parallelo.

### 16.4 Vantaggi operativi

- Continuita su codice legacy.
- Migrazioni graduali e verificabili.
- Smoke test desktop/mobile sui refactor principali.
- Guardrail forti su DB, pagamenti, carrello e dati sensibili.

### 16.5 Automazioni

Da completare con audit dedicato. Sono presenti flussi automatici/legacy collegati a email, carrello, PayPal recheck e gestione sessione.

### 16.6 Integrazione gestionale

La piattaforma web usa dati e contratti collegati al gestionale KeepStore. Ogni modifica a DB, password, documenti, ordini o indirizzi deve valutare compatibilita gestionale.

### 16.7 Area cliente

Area cliente modernizzata nelle pagine principali: dashboard, profilo, indirizzi read-only, documenti, wishlist e cambio password.

### 16.8 Documenti/ordini

Lista documenti con selector dinamico e dettaglio ordine con stato ordine/pagamento separato. Retry pagamento gestito nel dettaglio quando previsto, non nella lista.

### 16.9 Sicurezza e sviluppo evolutivo

Il cambio password account e stabilizzato, ma hash/migrazione password, reset tokenizzato e normalizzazione login/registrazione sono backlog prioritari.

## 17. Glossario

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

## 18. Regole per aggiornamenti futuri

Da BLUEPRINT-1A in poi, ogni task con modifica funzionale o audit rilevante deve valutare se aggiornare:

- `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`
- `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md`

Regola pratica:

- Masterplan = operativo/stato avanzamento, task, merge, smoke, cleanup, prossimi step.
- Blueprint = architettura, funzionalita, mappe tecniche, flussi, DB noto, componenti, debiti stabili e conoscenza riusabile.

Se un task cambia una pagina, un flow, una tabella, un componente condiviso, una policy di sicurezza o una integrazione, il blueprint deve essere aggiornato o esplicitamente marcato come non impattato nel report del task.
