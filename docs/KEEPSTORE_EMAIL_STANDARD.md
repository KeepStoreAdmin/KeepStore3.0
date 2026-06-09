# KeepStore Email Standard

Documento interno per audit e standardizzazione delle email transazionali Taikun/KeepStore.

Ultimo aggiornamento: 2026-06-09.

## 1. Scope e guardrail

Questo documento e progettuale. Non implementa runtime, non modifica template applicativi e non autorizza invii reali.

Guardrail permanenti:

- non inserire password, token, TokenHash, connection string, cookie, session id, IP, email reali cliente, CF/PIVA reali o dati ordine reali;
- non copiare contenuti o brand dei fornitori usati come benchmark;
- non usare percorsi legacy immagini del vecchio sito;
- usare logo azienda da DB quando disponibile, normalizzando eventuali path relativi verso URL pubblico sicuro;
- distinguere sempre stato ordine, stato pagamento e stato spedizione;
- non dichiarare "pagamento ricevuto" se il documento/gateway non conferma davvero il pagamento;
- non inventare testi legali: se mancano condizioni, recesso, garanzia o privacy, registrarli come requisito da validare.

## 2. Mappa invii email attuali

| Evento | File/funzione | Trigger | Destinatario | Oggetto attuale | HTML/plain | Dati usati | Tabelle/campi usati | Problemi | Priorita | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Conferma ordine/preventivo | `ordine.aspx.vb`, `SendEmail(n, documento, id, Descrizione_Coupon)` | Dopo creazione documento da `Carrello_Documento` e commit transazione | `Session("LoginEmail")`; BCC azienda | `Conferma {documento} dal sito {AziendaNome}` | Solo HTML concatenato | Testata da `vdocumenticompleta`, righe da `vdocumentirighe`, sessioni azienda/utente | `documenti`, `documentirighe`, `documentipie`, `pagamentitipo`, `vdocumenticompleta`, `vdocumentirighe`, `utentiindirizzi` | Layout legacy, stringhe concatenate, footer legale storico, nessuna variante chiara bonifico/contrassegno/gateway, logo non usato, nessuna plain text | Alta | Trigger reale identificato in `ordine.aspx.vb` righe 428-432 e 663-840. |
| Reset password tokenizzato | `App_Code/PasswordResetTokenService.vb`, `RequestReset` + `SendResetEmail` | POST valido da `remind.aspx` con email + CF/PIVA | Email account deterministico | `Reimposta la password del tuo account {azienda}` | HTML + plain text alternative views | Token chiaro solo nel link email; DB salva `TokenHash`; dati azienda da DB/sessione | `vlogin`, `login_password_reset_tokens`, `aziende` | Template gia professionale ma non usa ancora logo DB; standard da riallineare al motore unico futuro | Media | Flusso gia moderno: anti-enumeration, token monouso, scadenza 30 minuti. |
| Reset password completato | Non trovato | Dopo `resetpassword.aspx` completato | n/a | n/a | n/a | n/a | `login.Password`, `login.DataPassword` aggiornati dal flow reset | Email di conferma reset completato mancante | Media | Da introdurre in `EMAIL-AUTH-1A` dopo valutazione sicurezza. |
| Cambio password area account | Non trovato in `password.aspx.vb` | Cambio password riuscito da area account | n/a | n/a | n/a | n/a | `login.Password`, `login.DataPassword` | Email di sicurezza mancante | Media | Da introdurre in `EMAIL-AUTH-1A`, senza riportare password. |
| Registrazione account | `registrazione.aspx.vb`, `Email("Conferma registrazione al sito ", 1)` | Dopo `AggiungiUtente(codice)` | Email form registrazione; BCC azienda | `Conferma registrazione al sito {AziendaNome}` | Solo HTML concatenato | Campi form registrazione e sessioni azienda | `utenti`, `login`, stored procedure legacy `Newutenti`/`Newlogin`; dati form | Layout legacy, troppi dati personali nel corpo, footer legale storico, nessuna plain text, non centralizzata | Alta | Il blocco LOGIN-REGISTER ha gia rimosso esposizione password, ma il template resta legacy. |
| Profilo aggiornato | `registrazione.aspx.vb`, `Email("Profilo aggiornato sul sito ", 2)` | Aggiornamento profilo legacy | Email form/account; BCC azienda | `Profilo aggiornato sul sito {AziendaNome}` | Solo HTML concatenato | Campi form profilo | `utenti`, `login` | Riusa lo stesso metodo registrazione; possibile email eccessiva per aggiornamento profilo | Bassa/Media | Da valutare se rientra nelle transazionali utili o se dismettere. |
| Documento/fattura/proforma via email | `documenti.aspx.vb`, `stampaClick` / `GridView1_RowCommand` | Click `pdf2mail` su lista documenti | Non inviato dal sito in quel punto | n/a | n/a | Inserisce richiesta in tabella coda | `inviadocumenti`, view `vdatiinviadocumenti`, `aziende`, `login`, `tipodocumenti` | Handoff a processo esterno/gestionale da confermare; nessun `MailMessage` nel sito | Media | La coda contiene documento richiesto; invio reale non trovato nel runtime web. |
| Cambio stato ordine | Non trovato nel runtime web | n/a | n/a | n/a | n/a | Stato da documenti/documentistati | `documenti.StatiId`, `documentistati`, `vdocumenti` | Invio mancante o gestito esternamente | Alta | Da verificare con gestionale/Vincenzo. |
| Spedizione/tracking/evasione | Non trovato nel runtime web | n/a | n/a | n/a | n/a | Tracking visualizzato in account/documento | `documenti.Tracking`, `documentipie.Tracking`, `vettori.Link_Tracking` | Email tracking mancante o gestita esternamente | Alta | Il sito visualizza tracking ma non invia notifica dedicata. |
| Pagamento PayPal/carta/Banca Sella | Non trovato come email dedicata | Gateway aggiorna stato pagamento; conferma ordine resta generica | n/a | n/a | n/a | Stato pagamento da `documenti`, gateway tables | `documenti.Pagato`, `StatoPagamentoWeb`, `IdTransazione`, `paypal_express_transazioni`, `bancasella_ordini_pagati` | Mancano varianti email "pagato", "in verifica", "fallito" | Alta | Da implementare senza toccare gateway core. |
| Contatto cliente | `Contattaci.aspx.vb` | Invio form contatti | Email azienda | Oggetto form | HTML | Campi form contatto | `aziende` per contatti | Fuori scope ordine/auth; utile come riferimento SMTP | Bassa | Non e transazionale ordine/account principale. |

## 3. Fonti dati reali per email ordine

### 3.1 Documento e numerazione

Fonte primaria:

- `documenti.id`;
- `documenti.NDocumento`;
- `documenti.Bis`;
- `documenti.DataDocumento`;
- `documenti.NProtocollo`;
- `documenti.DataProtocollo`;
- `documenti.TipoDocumentiId`;
- `vdocumenticompleta`;
- `vstampadocumento`.

Il numero ordine web va composto usando campi esistenti e regole gia usate nel dettaglio/documento. Non inventare formati nuovi senza task dedicato.

### 3.2 Cliente e indirizzi

Fonti:

- `utenti`;
- `login`;
- `documenti.Utente`;
- `documenti.SedeLegale`;
- `documenti.DestinazioneMerci`;
- `utentiindirizzi`;
- campi `RagioneSociale`, `CognomeNome`, `Email`, `Piva`, `CodiceFiscale`, `Indirizzo`, `Cap`, `Citta`, `Provincia`, `Telefono`.

Nota privacy: nelle email standard usare solo dati necessari all'evento. Evitare riepiloghi anagrafici troppo estesi se non richiesti.

### 3.3 Righe prodotto

Fonti:

- `documentirighe`;
- `vdocumentirighe`;
- `vstampadocumento`.

Campi utili:

- codice/EAN se utile;
- descrizione prodotto;
- quantita;
- prezzo;
- imponibile/importo;
- IVA;
- eventuale omaggio/sconto se gia presente nelle righe.

### 3.4 Totali e costi

Fonte primaria:

- `documentipie.TotImponibile`;
- `documentipie.TotIva`;
- `documentipie.TotaleDocumento`;
- `documentipie.CostoSpedizione`;
- `documentipie.CostoAssicurazione`;
- `documentipie.CostoPagamento`;
- `documentipie.TotSconto`;
- `documentipie.TotSpese`;
- `documentipie.TotMerce`;
- `documentipie.ScontoMerce`;
- `documentipie.ScontoServizi`.

Non ricalcolare totali nelle email: leggere i valori gia persistiti dal documento.

### 3.5 Pagamento

Fonti:

- `documenti.PagamentiTipoId`;
- `pagamentitipo.Descrizione`;
- `pagamentitipo.Informazioni`;
- `pagamentitipo.Contrassegno`;
- `pagamentitipo.OnLine`;
- `pagamentitipo.Banca`;
- `pagamentitipo.img`;
- `pagamentitipo.CostoPercentuale`;
- `pagamentitipo.CostoFisso`;
- `pagamentitipo.CostoMassimo`;
- `pagamentitipo.FE_Pagamento`;
- `documenti.Pagato`;
- `documenti.StatoPagamentoWeb`;
- `documenti.DataStatoPagamentoWeb`;
- `documenti.UltimoEsitoPagamentoWeb`;
- `documenti.IdTransazione`.

Gateway correlati:

- PayPal: `paypal_express_transazioni` e helper `PayPalPaymentState`;
- Banca Sella: `bancasella_impostazioni_azienda`, `bancasella_ordini_pagati`, `bancasella_log`.

Regola: indicare pagamento ricevuto solo se `Pagato=1` oppure stato pagamento web realmente confermato. Per stati pendenti usare "in verifica" o "in attesa".

### 3.6 Spedizione e tracking

Fonti:

- `documentipie.VettoriId`;
- `vettori.Descrizione`;
- `vettori.Informazioni`;
- `vettori.Link_Tracking`;
- `documenti.Tracking`;
- `documentipie.Tracking`;
- `documentipie.CostoSpedizione`;
- `documentipie.CostoAssicurazione`.

Il tracking va inserito solo se disponibile e va trasformato in link sicuro solo tramite template `vettori.Link_Tracking` gia previsto o URL https/http sanificato.

### 3.7 Azienda, logo e coordinate bonifico

Fonti azienda:

- `aziende.RagioneSociale`;
- `aziende.CognomeNome`;
- `aziende.Indirizzo`;
- `aziende.Cap`;
- `aziende.Citta`;
- `aziende.Provincia`;
- `aziende.Telefono`;
- `aziende.email`;
- `aziende.Piva`;
- `aziende.Iban`;
- `aziende.SwiftCode`;
- `aziende.NomeBanca`;
- `aziende.URL1`;
- `aziende.URL2`;
- `aziende.Logo`;
- `aziende.LogoWeb`;
- `aziende.Condizioni_vendita`;
- `aziende.Condizioni_privacy`;
- `aziende.Smtp`, `User_smtp`, `Password_smtp` come configurazione SMTP, mai da stampare o loggare.

Altre fonti bancarie presenti nello schema:

- tabelle/procedure legate a `banche`, `conti`, `Clienti_Contabili` e `Fornitori_Contabili` risultano presenti nel dump;
- per la prima fase email bonifico usare come fonte candidata `aziende.Iban`, `aziende.NomeBanca`, `aziende.SwiftCode`, salvo conferma gestionale;
- se serve conto specifico per tipo pagamento, verificare con Vincenzo prima di implementare.

## 4. Standard template Taikun

### 4.1 Layout HTML

Standard proposto:

- HTML table-based, compatibile Outlook/Gmail/mobile;
- larghezza massima 600/640 px;
- CSS inline essenziale;
- nessun CSS esterno obbligatorio;
- nessun font esterno necessario;
- logo in alto da `aziende.LogoWeb` o `aziende.Logo`;
- box stato evento;
- sezioni/card ordinate: ordine, pagamento, spedizione, prodotti, riepilogo importi, prossimi passi, assistenza;
- footer aziendale con dati venditore e link utili;
- immagini solo assolute sicure oppure CID se supportato in task futuro;
- versione plain text sempre presente.

### 4.2 Regole logo

Priorita proposta:

1. `aziende.LogoWeb` se valorizzato.
2. `aziende.Logo` se valorizzato.
3. fallback testuale con nome azienda.

Se il valore DB e un path relativo, normalizzarlo con base URL pubblica azienda/sito. Non usare percorsi legacy immagini del vecchio sito e non hardcodare asset di fornitori.

### 4.3 Plain text

Ogni email deve avere una versione plain text con:

- saluto;
- stato evento;
- numero ordine o azione account;
- riepilogo essenziale;
- link principali in chiaro;
- assistenza;
- footer aziendale compatto.

## 5. Varianti transazionali

### 5.1 Ordine pagato online

Contenuti:

- numero ordine;
- data ordine;
- stato pagamento: ricevuto solo se confermato, altrimenti in verifica;
- metodo pagamento;
- riepilogo prodotti e importi;
- indirizzo spedizione/fatturazione;
- CTA sicure: vedi ordine, continua acquisti, assistenza.

### 5.2 PayPal

Se `pagamentitipo.OnLine=2`:

- indicare PayPal come metodo;
- se confermato, "Pagamento ricevuto tramite PayPal";
- se non confermato, "Pagamento in verifica";
- non rimandare al gateway se il pagamento e gia concluso;
- non riportare transaction id completi salvo policy sicura e gia visibile nel sistema.

### 5.3 Carta/Banca Sella

Se `pagamentitipo.OnLine=3` o pagamento carta correlato:

- indicare pagamento con carta/Banca Sella;
- distinguere ricevuto, in verifica, non riuscito o in attesa;
- non mostrare codici gateway completi se non gia autorizzati.

### 5.4 Bonifico bancario

Contenuti obbligatori:

- ordine ricevuto e in attesa di pagamento;
- importo da pagare da `documentipie.TotaleDocumento`;
- beneficiario da `aziende.RagioneSociale` o campo confermato;
- banca da `aziende.NomeBanca` o fonte confermata;
- IBAN da `aziende.Iban`;
- BIC/SWIFT da `aziende.SwiftCode` se presente;
- causale con numero ordine;
- avviso che preparazione/spedizione partono dopo accredito o convalida;
- link area ordini.

### 5.5 Contrassegno/contanti

Contenuti:

- conferma ordine;
- pagamento alla consegna o ritiro;
- eventuale costo contrassegno da `documentipie.CostoPagamento` o regole vettore/pagamento;
- corriere/ritiro se disponibile;
- importo totale;
- eventuale conferma telefonica solo se policy Taikun la prevede.

### 5.6 Cambio stato ordine, spedizione e tracking

Contenuti:

- stato nuovo da `documentistati`;
- numero ordine;
- tracking se disponibile;
- corriere/vettore;
- prossimi passi;
- link dettaglio ordine.

### 5.7 Reset password

Gia presente in fase 1. Standard futuro:

- link valido una sola volta;
- scadenza chiara;
- sezione "Non hai richiesto tu?";
- avvertenze anti-phishing;
- nessuna password in email;
- logo/footer standard.

### 5.8 Cambio password

Da aggiungere:

- conferma modifica password;
- avviso sicurezza;
- istruzione a contattare assistenza se non e stata richiesta dall'utente;
- nessuna password o dettaglio tecnico.

### 5.9 Registrazione

Da riallineare:

- benvenuto;
- dati account minimali;
- link login/area account;
- assistenza;
- nessun riepilogo eccessivo di dati personali;
- nessuna password.

## 6. Oggetti email consigliati

| Evento | Oggetto consigliato |
| --- | --- |
| Registrazione | `Benvenuto su Taikun: il tuo account e stato creato` |
| Recupero password | `Reimposta la password del tuo account Taikun` |
| Reset password completato | `Password Taikun aggiornata correttamente` |
| Cambio password da area account | `La password del tuo account Taikun e stata modificata` |
| Ordine ricevuto | `Abbiamo ricevuto il tuo ordine Taikun n. {NumeroOrdine}` |
| Ordine pagato PayPal | `Pagamento PayPal ricevuto per l'ordine Taikun n. {NumeroOrdine}` |
| Ordine pagato carta/Banca Sella | `Pagamento ricevuto per l'ordine Taikun n. {NumeroOrdine}` |
| Ordine con bonifico | `Ordine Taikun n. {NumeroOrdine}: istruzioni per il bonifico` |
| Ordine con contrassegno | `Ordine Taikun n. {NumeroOrdine}: pagamento alla consegna` |
| Ordine in preparazione | `Il tuo ordine Taikun n. {NumeroOrdine} e in preparazione` |
| Ordine spedito | `Il tuo ordine Taikun n. {NumeroOrdine} e stato spedito` |
| Tracking disponibile | `Tracking disponibile per il tuo ordine Taikun n. {NumeroOrdine}` |
| Ordine annullato | `Aggiornamento ordine Taikun n. {NumeroOrdine}` |
| Documento/fattura disponibile | `Documento disponibile per l'ordine Taikun n. {NumeroOrdine}` |

## 7. Normativa e contenuti minimi

La conferma ordine deve essere inviata su mezzo durevole, normalmente email, ed essere chiara, archiviabile e non modificabile unilateralmente dal sito.

Contenuti essenziali da prevedere quando applicabili:

- venditore e dati azienda;
- numero e data ordine;
- prodotti, quantita, prezzi;
- IVA, costi, spedizione, assicurazione, pagamento, totale;
- indirizzi spedizione/fatturazione;
- metodo pagamento e stato pagamento corretto;
- metodo spedizione/corriere e tracking se disponibile;
- assistenza;
- link a condizioni di vendita, privacy, recesso/garanzia se gia disponibili.

Non inserire testi legali inventati. Se le condizioni non sono disponibili o non validate, aprire task legale/consulenziale.

## 8. Roadmap implementativa

1. `EMAIL-ENGINE-1A`: helper unico in `App_Code`, generatore HTML + plain text, logo da DB, CSS inline e sanitizzazione.
2. `EMAIL-ORDER-CONFIRMATION-1A`: conferma ordine standard con varianti pagamento e dati ordine reali.
3. `EMAIL-BANKTRANSFER-1A`: istruzioni bonifico, causale e fonti coordinate confermate.
4. `EMAIL-COD-1A`: contrassegno/contanti.
5. `EMAIL-ORDER-STATUS-1A`: cambio stato, spedizione, tracking.
6. `EMAIL-AUTH-1A`: registrazione, reset, cambio password.
7. `EMAIL-PREVIEW-TEST-1A`: preview interna o modalita test senza inviare email reali.
8. `EMAIL-DELIVERABILITY-1A`: audit SPF/DKIM/DMARC, sender, reply-to e test spam, senza modifiche DNS.

## 9. Anomalie e debiti emersi

- Conferma ordine attuale non differenzia chiaramente bonifico, contrassegno, PayPal, carta/Banca Sella.
- Conferma ordine attuale non usa logo DB e non ha plain text.
- Registrazione usa ancora template legacy concatenato e include molti dati personali.
- Cambio password e reset completato non risultano notificati via email.
- Cambio stato/spedizione/tracking non risultano inviati dal runtime web.
- `documenti.aspx` mette in coda richieste su `inviadocumenti`; invio reale da gestionale/processo esterno da confermare.
- `mailconfig` esiste nello schema, ma non risulta usato direttamente dal runtime web auditato.
- Coordinate bonifico: fonti candidate reali presenti in `aziende` e in tabelle contabili/banca, ma va confermata la fonte operativa con Vincenzo prima di implementare.
