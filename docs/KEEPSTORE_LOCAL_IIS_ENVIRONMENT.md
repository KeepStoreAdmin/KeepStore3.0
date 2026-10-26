# KeepStore 3.0 — Mappa ambienti IIS e test locale

## REV1 prevalente — 2026-10-26, carrello A e prosecuzione pagamento B

Stesso laboratorio 40390/:18843 e MySQL isolato :13317, nessun provisioning o nuova attestazione generale. Prima dei POST confermati dal pool UUID/schema/porta/TLS e marcatore; Edge via pipe con TLS rigoroso e traffico limitato ai due host locali. Staging temporaneo dei tre soli sorgenti candidati (CartPriceRevalidationHelper.vb, articoli.aspx.vb, carrello.aspx). REV1 delle due sdsPromo: 38 nuovi controlli/9 SQL CTE read-only e precompile safe PASS; prove precedenti riusate, non ripetute. Standard Repeater1 e spedizione gratuita gvArticoliGratis entrambi GET 200, quantita 2/netto 10/lordo 12,20/subtotale 24,40. Promozioni positive coperte da CTE/handler/helper reali con I/O simulato, non da offerte persistenti nel browser.

Continua con spedizione e pagamento -> HTTP 500/MySQL 1055 su vpagamentitipo.UtenteId, datasource sdsPagamenti fuori REV1 e lasciata immutata. Zero ordini/POST finali/replay; nessuna certificazione di documento, origine WEB, numerazione, IVA/spedizione finali o isolamento ordine. Righe proprie 3722/3723 rimosse via UI e tre campi temporanei spedizione gratis ripristinati; zero carrelli/documenti/righe, progressivo 1, stock 100/impegno 0, cliente 20560 e catture 3 preservati. Tre sorgenti e configurazione diagnostica lab ripristinati con hash/ACL/date/attributi verificati; probe/profilo propri rimossi e browser chiuso, nessun servizio/sito preesistente o TEMP storico toccato. [Ricevute e limite B](KEEPSTORE_MASTERPLAN_OPERATIVO.md#rev1--due-sdspromo-e-prosecuzione-checkout). Canonica sul candidato per stessa PR DRAFT; main/Smoke/produzione invariati, CONSEGNA SERVER SOSPESA. Il checkpoint seguente precede questa REV1.

## Ripresa SQL — 2026-10-26, candidato verificato e checkout fermo su nuovo 1055

REGORDER-SQL8-COMPAT-1A riusa il laboratorio esistente e le attestazioni IPv4/IPv6/email, senza riprovisionare o modificare schema/SQL mode. Continuita verificata prima delle scritture dal pool reale: UUID lab, 127.0.0.1:13317, data directory/TLS e marcatore SMOKE; Edge strict TLS via pipe su :18843, nessun fallback pubblico. Staging temporaneo esclusivo di CartPriceRevalidationHelper.vb e articoli.aspx.vb, con backup hash/ACL/date. Catalogo corretto: 21 GET 200 Taikun/Webaffare e prezzi/range coerenti; 230 controlli dedicati con 16 SQL CTE read-only, 23 scenari carrello e precompile safe PASS. Dataset browser un solo articolo, paginazione multi-articolo coperta dalle CTE, non da un DB operativo esteso.

PROVA utente 1/login 19832 autenticato con il deposito fixture protetto; cliente registrato 20560/19834 intatto. Add nativo riga 3721/quantita 2 PASS; GET carrello 500/MySQL 1055 su Giacenza, nuovo blocco fuori manifest. Nessun checkout finale/ordine o invio email; sola riga test rimossa tramite MiniCart. Stato finale: zero carrelli/documenti/righe, progressivo 1, stock 100/impegno 0, catture 3. Nessun recupero di password dal DB eseguito dopo il rifiuto del controllo automatico, nessun bypass o reset credenziali. [Dettaglio del confine B](KEEPSTORE_MASTERPLAN_OPERATIVO.md#regorder-sql8-compat-1a--2026-10-26).

Due sorgenti lab e configurazione diagnostica ripristinati dopo le prove; probe e profilo propri rimossi, browser chiuso. La copia IIS torna alla baseline, mentre i file canonici mantengono il candidato per review: nessuna consegna permanente al laboratorio o ai siti pubblicati. Smoke/prod/main invariati; nessun nuovo test registrazione/SMTP/provisioning, nessun ordine/pagamento reale. CONSEGNA SERVER SOSPESA; i checkpoint sotto sono antecedenti.

## Esito prevalente — 2026-10-26, registrazione A e ordine B nel laboratorio

REGISTRATION-ORDER-LAB-RUNTIME-1A riusa sito/pool 40390 e MySQL 8.0.46 :13317, senza nuovo provisioning. Browser Edge via pipe e TLS rigoroso, solo host Taikun/Webaffare :18843 con peer 127.0.0.1. Prima dei POST verificati UUID `1167ebae-d0c0-11f1-b348-9c7bef540c10`, DB sintetico e TLS; IPv6 on-link di controllo senza rifiuto locale, tentativo del pool negato 10013. Nessuna modifica route/firewall globale, Smoke o produzione.

Registrazione cliente sintetico 20560/login 19834, rifiuto duplicato, area cliente e nuova cattura email A; geografia WCF servita solo da fixture SOAP loopback temporanea. Completati esclusivamente lookup/dati articolo e tre colonne legacy pagamento mancanti nel DB lab secondo contratto versionato. Il resolver carrello fallisce MySQL 3065 e annulla l'aggiunta: zero carrelli/documenti/righe, stock 100/impegno 0 e progressivo 1. Catalogo HTTP 500/MySQL 1055; nessun allentamento sql_mode o fix sorgente. Indici nominati del merge anonimo assenti e recensioni con CREATE negato restano limiti della fixture/privilegi; nessun nuovo grant. Checkout/ordine e isolamento del documento NON COLLAUDATI. [Matrice e difetti circoscritti](KEEPSTORE_MASTERPLAN_OPERATIVO.md#registration-order-lab-runtime-1a--2026-10-26).

Configurazione lab ripristinata a hash/ACL/date/attributi iniziali, incluso customErrors ed esclusione endpoint SOAP temporaneo; sonda rimossa, browser/listener chiusi e due profili propri eliminati. Non riprendere la registrazione presumendo il servizio geografico temporaneo ancora attivo. Fixture/account sintetici e audit conservati, nessuna manipolazione di documenti/counter; residuo TEMP storico non toccato. Cinque soli manuali, nessun commit/PR/deploy. Pubblicazione App_Code parziale e accessibilita Taikun riferite dal PO, non verificate qui; ULTERIORI CONSEGNE SERVER SOSPESE. Il blocco sotto conserva la sola predisposizione antecedente.

## Aggiornamento prevalente — 2026-10-26, laboratorio predisposto e attestato A

Chiusura ADMIN-RESUME: `ISOLATED_LAB_IIS_DB_EMAIL_ATTESTED` in `C:/Temp/KeepStoreLabFinalize-20261026-04283ea9/final-attestation.json`. Riutilizzate le prove dal pool reale dei due host: DB TLS/read/write/rollback, DB sistema negato, egress IPv4 negato 10013, SMTP nativo rifiutato e due catture a soli conteggi; negativo descrittore 503 con ripristino. IPv6 NetworkUnreachable 10051 e assenza default route, distinto da enforcement su IPv6 routabile. GET login finali 200 con form e TLS rigoroso per Taikun/Webaffare; fingerprint IIS di Smoke, configurazione cifrata e sorgenti lab invariati. Completate solo fixture di presentazione e FK Iva vettore verso iva.Id=1/Valore=22. Sonda temporanea rimossa; sito/pool lab Started, nessun autostart impostato. Nessuna registrazione, login autenticato nuovo, checkout o ordine eseguiti in questa ripresa. Operazioni finali eseguite direttamente con normale UAC dopo autorizzazione PO, senza altri comandi manuali o bypass.

Nuove risorse effettive: `KeepStoreRegOrderLab-20261025`, site ID 40390, pool `KeepStoreRegOrderLabPool-20261025`, root `C:/Temp/KeepStoreRegOrderLab-20261025/site`, binding esclusivo `127.0.0.1:18843:` HTTPS. Nuovo MySQL 8.0.46 locale :13317, data directory separata, DB `keepstore_regorder_lab_20261025` e tre tabelle geografiche sintetiche. Account web DML/EXECUTE solo lab e SELECT geografici, REQUIRE SSL; nessun privilegio globale. Audit separato SELECT sintetico/SHUTDOWN, nessun servizio Windows installato. CA dedicata verificata dal Connector; niente fallback TLS o modifiche al trust store.

Configurazione privata derivata dal template pubblico, connessione cifrata con chiave temporanea dedicata al solo lab; nessuna chiave/configurazione operativa copiata. Marcatore SMOKE di processo, descrittore `C:/ProgramData/KeepStore/TestIsolation/site-40390.xml` e due regole outbound limitate al nuovo pool/programma MySQL. Estensione PO esplicita: sola DACL parent `C:/ProgramData/KeepStore`, rimozione dell'ACE Users Write ereditata e protezione, senza propagazione ai figli; backup/rollback conservati. Il primo bootstrap fallito e stato ripristinato, la REV1 amministrativa e riuscita.

Storico dei due tentativi: primo avvio con TLS/identita/config A, poi FileNotFoundException per BouncyCastle.Crypto 1.9.0.0; sito/pool fermati e descrittore ripristinato. Dipendenza ufficiale gia dichiarata dal Connector ripristinata solo nel nuovo Bin, identita/hash/firma strong-name verificati, 18 DLL preesistenti intatte. Connessione .NET VerifyCA/lettura DB e rifiuto di CA sintetica errata PASS; precompile lab PASS; firma NuGet non dichiarata validata. La ripresa r1 passa l'isolamento ma incontra un redirect errore al GET login: completate le fixture sintetiche, GET finali A e attestazione chiusa come sopra. Le ricevute B sono conservate come storico, non blocker attivi. [Matrice e rollback](KEEPSTORE_MASTERPLAN_OPERATIVO.md#keepstore-isolated-regorder-lab-1a--2026-10-25).

KeepStoreSmoke esistente (id 2, HTTP :8090 / HTTPS :8443) e DB condiviso non modificati. Nessuna nuova esecuzione dei gate login/carrello; nessun deploy. Il blocco seguente conserva il primo preflight, superato dal checkpoint sopra.

## Storico primo preflight — 2026-10-25, laboratorio B amministrativo

Mandato KEEPSTORE-ISOLATED-REGORDER-LAB-1A: nuovo laboratorio MySQL/IIS distinto, non riconfigurazione di KeepStoreSmoke :8443. #390 MERGED/CLOSED e stable locale/origin `8b17b29254df8f71d3e1c08578ca8af9f123d7eb`; MySQL 8.0.46 portabile gia disponibile. Nessuna istanza, directory dati, configurazione, credenziale, sito/pool, binding, ACL, descrittore o regola rete nuovi creati.

Il processo Windows corrente non e elevato; appcmd list site KeepStoreSmoke /text:id in sola lettura termina con exit 5, accesso insufficiente a redirection.config. W3SVC/WAS attivi non sostituiscono questo prerequisito. Nessun tentativo di modificare privilegi/policy o aggirare la lettura negata. Riprendere lo stesso mandato in contesto amministrativo Windows autorizzato per provisioning e confinamento rete; isolamento DB/email/gateway e collaudi mutativi ancora B/NON ESEGUITI. [Matrice ed evidenze](KEEPSTORE_MASTERPLAN_OPERATIVO.md#keepstore-isolated-regorder-lab-1a--2026-10-25).

KeepStoreSmoke e DB condiviso preservati; zero connessioni DB, richieste HTTP, registrazioni, carrelli o ordini di questo task. Login/carrello precedenti riusati senza ripetizioni. Nessuna attivazione #390 sul pool esistente. Coupon/Groupon STANDBY, SOMEC escluso, CONSEGNA SERVER SOSPESA.

## Checkpoint acquisito — 2026-10-25, login A e carrello runtime

Il PO chiude A tecnico LOGIN-IIS-COMPATIBILITY-GATE-1A per Taikun/PROVA sulle prove browser pregresse (27/27, cinque POST negativi; Referer contraddittorio wire-only). Nessuna riapertura #386 o ripetizione del gate. CART-RUNTIME-CONTINUITY-1A: Playwright/Edge reale via pipe, contesti isolati, strict TLS 1.3 e serverAddr 127.0.0.1:8443; 87/87 asserzioni su inserimento, quantita carrello/MiniCart, netto/lordo, rimozione e migrazione anonimo -> PROVA. Carrello iniziale/finale vuoto, due sole righe test rimosse; nessun ordine/email/pagamento.

KeepStoreSmoke :8443 non isola il DB operativo condiviso: [autorizzazione permanente TEST/PROVA e precauzioni](KEEPSTORE_MASTERPLAN_OPERATIVO.md#autorizzazione-po-ai-test-applicativi-testprova), [matrice e limiti](KEEPSTORE_MASTERPLAN_OPERATIVO.md#chiusura-login-e-cart-runtime-continuity-1a--2026-10-25). Nessun cambio IIS/certificati/configurazioni/SQL diretto. Gli snapshot sotto sono storici; Webaffare account/carrello, casi non provati e produzione non certificati. Browser propri chiusi e profili preesistenti preservati; directory TEMP propria ancora presente, cancellazione ricorsiva rifiutata dalla revisione automatica (blocked by policy). Nessun bypass; residuo B di pulizia distinto dal collaudo carrello A. Log automatici conservati. CONSEGNA SERVER SOSPESA.

## Storico superato — 2026-10-24, LOGIN-IIS-COMPATIBILITY-GATE-1A

Il corpo successivo conserva lo snapshot 2026-10-13. #388/#386 sono SOURCE INTEGRATED; base locale/remota `55ed4f2bf207c24088ce8f827177f7a4019b38ac`. Il PO conferma ora che KeepStoreSmoke :8443 serve direttamente `C:\KeepStoreWeb\KeepStore3.0` e che la sessione osservata e TEST/PROVA. KeepStoreIntegration :18443 resta distinto. Mapping acquisito come attestazione PO, non lettura automatica: appcmd negato su redirection.config e UI IIS non navigabile non dimostrano indisponibilita del sito.

Il PO attesta login PROVA riuscito e redirect a `https://www.taikun.it:8443/Default.aspx`; profilo Edge separato e host-resolver-rules verso loopback come riportati nel mandato. Ora eseguiti direttamente **30/30 casi HTTP + 2/2 approfondimenti validator PASS** sui due tenant, 40 richieste curl con TLS Schannel rigoroso/--resolve/nessun proxy o redirect seguito. Navigazione login GET/HEAD, origini rifiutate con ViewState invalido, Origin valido/fallback Referer con credenziali sintetiche errate e validazione campi vuoti: [matrice e limiti](KEEPSTORE_MASTERPLAN_OPERATIVO.md#evidenze-e-confini-della-sessione). Nessun bypass TLS o cambio certificati.

La scheda iniziale mostrava intestazione autenticata e MiniCart vuoto; nuova navigazione login e rinnovo della HOME mostrano ora sessione non autenticata senza logout dell'agente. Timeout configurato 30 minuti; causa/momento non determinati. Richiesto nuovo accesso PROVA nella scheda pronta con ReturnUrl=/compare.aspx; ReturnUrl autenticato, isolamento account e continuita carrello popolato restano B. Non trasformare il login attestato o il verde HTTP anonimo in attestazione release.

Il consenso PO consente test applicativi TEST/PROVA e fixture reversibili secondo la fonte unica [autorizzazione e limiti](KEEPSTORE_MASTERPLAN_OPERATIVO.md#autorizzazione-po-ai-test-applicativi-testprova). Il DB resta condiviso con produzione: niente dati reali, SQL diretto, cambio IIS/configurazione, deploy, addebiti/gateway live, notifiche a terzi o effetti irreversibili. La deroga supera solo il divieto generale di mutazioni applicative di test nello snapshot sotto; conservare PROVA e audit. In questa sessione nessuna mutazione ecommerce, ordine, mail/SMS o pagamento dell'agente. CONSEGNA SERVER SOSPESA.

Stato: ricognizione 2026-10-13; osservazioni da screenshot del Product Owner e dichiarazioni esplicite, non certificazione automatica del runtime. Fonte del metodo: AGENTS.md; roadmap/gate: docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md. Questo documento e' una scheda infrastrutturale consultabile prima di richiedere nuove schermate o bloccare gli smoke.

## 1. Distinguere sempre le macchine

- **PC sviluppo:** `DESKTOP-07S82HU` (nome visibile nello screenshot IIS del 2026-10-13). Repository/working copy canonica `C:\KeepStoreWeb\KeepStore3.0` (Product Owner). ASP.NET WebForms VB.NET .NET Framework 4.8 / MySQL; codice Git non coincide automaticamente con un deployment IIS.
- **Altra macchina IIS mostrata negli screenshot precedenti:** `WIN-AI9AID55ODN` (nome visibile). Ospita i siti `keepstore.it`, `taikun.it`, `webaffare.it`, `somec.eu`, `panificiosannino`, Default Web Site e siti FTP. NON confondere il suo IIS con quello del PC di sviluppo. Nome macchina e ruolo di produzione da confermare prima di operazioni server.
- Su `WIN-AI9AID55ODN` gli screenshot mostrano percorsi IIS: `keepstore.it` -> `C:\inetpub\wwwroot\www.keepstore.it`; `taikun.it` -> `C:\inetpub\wwwroot\www.taikun.it`; `webaffare.it` -> `C:\inetpub\wwwroot\www.webaffare.it`; `somec.eu` -> `C:\inetpub\wwwroot\www.somec.eu`; `panificiosannino` -> `C:\inetpub\wwwroot\www.panificiosannino.it\Public`. Per `keepstore.it` e' visibile application pool `keepstore.it` e autenticazione percorso pass-through. Questi sono fatti fotografati, non una verifica completa dei siti o dei binding.
- Il Product Owner pubblica manualmente i file runtime approvati dal repository nella cartella IIS del sito destinazione; merge Git non implica deploy. Prima di copiare controllare macchina, physical path, manifest e backup.

## 2. IIS sul PC sviluppo — screenshot 2026-10-13

Sono presenti come **siti IIS distinti**: `Default Web Site`, `KeepStoreIntegration`, `KeepStoreSmoke`. Quest'ultimo e' anche un sito, non soltanto un pool.

Per il sito **KeepStoreIntegration**, la finestra *Binding sito* mostra quattro binding locali, senza hostname valorizzato nella vista:
- `http` / `127.0.0.1:18090`
- `https` / `127.0.0.1:18443`
- `http` / `[::1]:18090`
- `https` / `[::1]:18443`

Gli indirizzi `127.0.0.1` e `::1` sono loopback: non assumere raggiungibilita' esterna. Questi binding NON sono quelli della porta `8443`.

Pool presenti e avviati nello screenshot, tutti CLR **v4.0**, pipeline **Integrata** e identita' **ApplicationPoolIdentity**, con conteggio applicazioni mostrato:
- `.NET v4.5`: 0; `.NET v4.5 Classic`: 0 (pipeline *Classica*); `DefaultAppPool`: 1;
- `KeepStoreIntegrationPool`: 1; `KeepStoreSmoke`: 1.

Attenzione: la precedente frase “tutti pipeline Integrata” ha un'eccezione: `.NET v4.5 Classic` e' in modalita' Classica. Non dedurre dai nomi dei pool il mapping certo sito -> pool: manca screenshot *Impostazioni di base* di ciascun sito.

## 3. Endpoint tenant-aware sulla porta 8443

Il Product Owner conferma che sul PC di sviluppo funzionano:
- `https://www.taikun.it:8443/Default.aspx`: stesso codice aggiornato del repository locale, **Azienda 1** nel database Taikun;
- `https://www.webaffare.it:8443/`: stesso codice aggiornato del repository locale, **Azienda 2** nello **stesso database Taikun**.

Sono due contesti applicativi/tenant sullo stesso database, NON due database isolati. La descrizione precedente di Webaffare come ASPX vecchie era stata corretta esplicitamente dal Product Owner e NON deve essere ripetuta. Le due HOME viste negli screenshot hanno branding differente, ma gli screenshot non certificano file/commit effettivamente serviti.

Il binding `:8443` non compare nella finestra binding di `KeepStoreIntegration` pubblicata il 2026-10-13. Serve identificare il sito/servizio che termina `:8443` e se usa proxy/rewrite/hosts/risoluzione locale; non dedurre che `KeepStoreIntegration :18443` e `www.taikun.it :8443` abbiano la stessa directory o applicazione.

## 4. Stato test e limiti — no regressioni documentali

- Evidenze storiche gia' in **System Blueprint** (circa sezione runtime/browser) e **Masterplan**: browser reale `https://localhost:8443`, viewport mobile/desktop, smoke HTTP e POST di ricerca WebForms, anche `https://www.taikun.it:8443`. Non ripetere la discovery generale o chiedere gli stessi screenshot se queste evidenze restano attuali.
- `HOME-TTFB-PERFORMANCE-VERIFY-1A` resta **B ambientale**: il tentativo Codex di leggere `applicationHost.config` ha restituito `UnauthorizedAccessException`; nessuna GET autorizzata allora e nessuna misura TTFB. Questo NON dimostra che il browser non funzioni.
- `PR #346` (HEADER-DESKTOP-MENU-VIEWSTATE-DEDUPLICATION-1A) e' **OPEN/DRAFT**, review indipendente A sul codice; reale smoke GET/postback, event validation e prova visuale ANCORA NON ESEGUITI al checkpoint. Nessuna deroga implicita, nessun merge o deploy.
- Database Taikun sulle due host `:8443` condiviso e potenzialmente operativo: non qualificare come test isolato, non avviare DML/DDL, ordini, pagamenti, e-mail, carrelli mutativi o postback non certificati read-only. La porta loopback da sola non dimostra un DB isolato.

## 5. Procedura di preflight per il prossimo smoke (read-only)

1. Riutilizzare il presente documento e i checkpoint prima di ogni nuova richiesta screenshot; verificare quale macchina si sta interrogando.
2. Verificare via IIS Manager (lettura, senza cambiare nulla) *Siti > Impostazioni di base* per `KeepStoreIntegration` e `KeepStoreSmoke`, annotando app pool e percorso fisico; se necessari identificare binding di `KeepStoreSmoke` e sito/servizio proprietario di `:8443`.
3. Correlare percorso IIS ai file effettivamente distribuiti rispetto al manifest/commit Git richiesto; nessuna sovrascrittura per accertarlo.
4. Accertare destinazione e permessi DB senza diffondere connection string, password o segreti. `applicationHost.config` protetto non e' requisito per il browser se un amministratore puo' attestare il mapping con informazioni IIS gia' visibili.
5. Verificare singoli GET/postback e loro effetti collaterali nel codice/dipendenze prima di consentire richiesta HTTP; usare allowlist della macchina/host/operazione autorizzata. Nessun avvio/riavvio sito, cambio binding/app pool, elevazione automatica o DB test senza autorizzazione separata.
6. Dopo preflight PASS: prima smoke limitato PR #346 (HTML GET, POST ricerca non mutativa, event validation, scope/menu su desktop/mobile), poi eventuale campagna TTFB separata. Se una verifica critica resta sconosciuta: STOP B con blocker preciso, senza degradare il gate.

## 6. Regola operativa permanente

Non dichiarare “IIS locale non esiste”, “Codex non ha browser” o “8443 non funziona” sulla base del solo accesso negato a `applicationHost.config`: distinguere **disponibilita' endpoint**, **permesso lettura configurazione IIS**, **mapping runtime**, **isolamento DB**, **sicurezza della singola richiesta** e **browser interattivo**. I dati osservati negli screenshot NON sostituiscono la certificazione dei prerequisiti mancanti.
