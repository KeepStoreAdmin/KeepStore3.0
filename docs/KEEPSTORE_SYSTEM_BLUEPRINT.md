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
- [11. Database fisici, backup e ruolo multi-azienda](#11-database-fisici-backup-e-ruolo-multi-azienda)
- [12. Funzionalita ecommerce](#12-funzionalita-ecommerce)
- [13. Area account - stato consolidato](#13-area-account---stato-consolidato)
- [14. Login, registrazione e recupero password - audit LOGIN-REGISTER-1A](#14-login-registrazione-e-recupero-password---audit-login-register-1a)
- [15. Registro modifiche tecniche](#15-registro-modifiche-tecniche)
- [16. Debito tecnico e backlog architetturale](#16-debito-tecnico-e-backlog-architetturale)
- [17. Sezione brochure sintetica](#17-sezione-brochure-sintetica)
- [18. Glossario](#18-glossario)
- [19. Regole per aggiornamenti futuri](#19-regole-per-aggiornamenti-futuri)

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
| `login.aspx` | `login.aspx.vb` | Login | mitigato senza hash | `vlogin`, sessione | Messaggio generico, password legacy in chiaro/case-insensitive |
| `registrazione.aspx` | `registrazione.aspx.vb` | Registrazione | mitigata senza hash | `utenti`, `login`, SP legacy | Policy 8-25, no lowercase forzato, no password in email/sessione/URL |
| `registrazioneok.aspx` | `registrazioneok.aspx.vb` | Esito registrazione | mitigato | sessioni post-registrazione | Nessuna password in URL/UI |
| `remind.aspx` | `remind.aspx.vb` | Reset password tokenizzato | fase 1 operativa legacy-compatible | `vlogin`, `login_password_reset_tokens`, email | Email + CF/PIVA, PRG, sent=1 UX, token single-use, hash non implementato |
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

Auditato in LOGIN-REGISTER-1A e mitigato in LOGIN-REGISTER-SECURITY-1. Usa ancora `vlogin`, sessione e confronto password case-insensitive; hash non implementato. I messaggi pubblici di errore sono ora generici per ridurre enumeration tra username inesistente, password errata e utente non attivo.

### 9.13 Registrazione

Auditata in LOGIN-REGISTER-1A e mitigata in LOGIN-REGISTER-SECURITY-1. Crea utente/login con stored procedure legacy, senza schema change e senza hash. La policy visibile e stata allineata a 8-25, il lowercase forzato della password e stato rimosso e i flow post-registrazione basati su password in email/sessione/URL sono stati neutralizzati.

### 9.14 Recupero password

`remind.aspx` e `resetpassword.aspx` gestiscono il reset password tokenizzato fase 1, legacy-compatible e senza hash migration. Il flow richiede email e Codice fiscale oppure Partita IVA, tratta CF/PIVA come alternativi, de-duplica per `LoginId` e genera token solo con un candidato valido. Il token e single-use, scade dopo 30 minuti e nel DB viene salvato solo `TokenHash`. Il reset riuscito aggiorna `login.Password` legacy e `login.DataPassword`; `aziende.ScadenzaPassword` resta invariato. `remind.aspx` usa POST/Redirect/GET, `remind.aspx?sent=1` mostra una card di conferma evidente senza form ambiguo o loader legacy, l'email reset e professionale con riferimenti aziendali e avvertenze anti-phishing, e il redirect post-login esclude `resetpassword.aspx`, `remind.aspx` e URL con token/reset/remind.

### 9.15 Cambio password

`password.aspx` e pagina canonica. Policy server-side 8-25, conferma obbligatoria, nuova diversa dalla vecchia, update centralizzato, `DataPassword` su successo. Hash non implementato.

### 9.16 Logout

`logout.aspx` chiude sessione e gestisce pulizia collegata al carrello. Da completare con audit sessione.

### 9.17 Accesso negato

`accessonegato.aspx` mostra accesso negato e redirecta a default se sessione login presente.

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
| Carrello | da completare | Perimetro sensibile |
| Ordini | parziale | Lista/dettaglio account stabilizzati |
| Documenti | stabile area account | Selector documenti dinamico |
| Pagamenti | parziale/stabilizzato PayPal | PayPal Express NVP stabilizzato; BancaSella legacy |
| Area cliente | consolidata su pagine principali | Sidebar/account shell |
| Wishlist | stabile | AccountSidebar globale |
| Coupon | da completare | Flow coupon legacy da audit |
| Email/notifiche | da completare | Reminder/registrazione hanno debiti security |
| Integrazione gestionale | da completare | Relazione DB/stored procedure/view |

## 13. Area account - stato consolidato

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

## 15. Registro modifiche tecniche

| Data | Task | PR | Commit | File modificati | Sintesi tecnica | Impatto funzionale | Note/debito residuo |
| --- | --- | --- | --- | --- | --- | --- | --- |
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

## 16. Debito tecnico e backlog architetturale

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
- `datiutente.aspx` legacy con errore generico preesistente.
- `datiutente.aspx` con tab/JS legacy e gestione salvataggi/destinazioni.
- Gestione add/edit/delete indirizzi non migrata.
- Cleanup completo sidebar/nav inline legacy su `datiutente.aspx` da completare.
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

## 17. Sezione brochure sintetica

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

## 18. Glossario

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

## 19. Regole per aggiornamenti futuri

Da BLUEPRINT-1A in poi, ogni task con modifica funzionale o audit rilevante deve valutare se aggiornare:

- `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`
- `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md`

Regola pratica:

- Masterplan = operativo/stato avanzamento, task, merge, smoke, cleanup, prossimi step.
- Blueprint = architettura, funzionalita, mappe tecniche, flussi, DB noto, componenti, debiti stabili e conoscenza riusabile.

Se un task cambia una pagina, un flow, una tabella, un componente condiviso, una policy di sicurezza o una integrazione, il blueprint deve essere aggiornato o esplicitamente marcato come non impattato nel report del task.

Quando si lavora su login, registrazione, utenti, indirizzi o documenti, verificare se l'impatto riguarda anche il gestionale e i database condivisi. Quando si lavora sulla registrazione, considerare sempre il registry `city_registry`. Quando si lavora su configurazione clienti/aziende, indirizzamento gestionale o multi-tenant, considerare sempre il registry `connessioni`.
