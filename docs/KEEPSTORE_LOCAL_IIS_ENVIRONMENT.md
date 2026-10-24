# KeepStore 3.0 — Mappa ambienti IIS e test locale

## Aggiornamento prevalente — 2026-10-25, login A e carrello runtime

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
