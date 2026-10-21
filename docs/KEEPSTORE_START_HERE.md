# KeepStore — START_HERE

Checkpoint breve: 2026-10-21. Parola chiave: **KS-RIPRENDI**. Metodo e autorita: [AGENTS](../AGENTS.md); questo file non autorizza operazioni.

## Stato verificato e lavoro corrente

- Checkpoint 2026-10-21: #365 **CHIUSA A / SOURCE INTEGRATED**, stable/base `f39958753a017ee3a7dee6141339e93918010399`; review A [5592875346](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/365#pullrequestreview-5592875346), autorizzazione [6303795610](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/365#issuecomment-6303795610), closeout [6303869293](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/365#issuecomment-6303869293). #364 gia integrata; main `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariato. Nessun deploy implicito.
- Task corrente `SHOPPING-ASSISTANT-PROGRESSIVE-RESULTS-1A` **REV1**, branch `task/shopping-assistant-progressive-results-1a`, [PR #366 DRAFT](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/366). **A tecnico locale REV1 / review indipendente pendente**, KS-F01 PARZIALE. Profilo EXCEPTIONAL; richiesta PO Astra/xhigh, modello/livello effettivi non esposti e non attestati. Un commit REV1 figlio di `ed359cd68bee07b73c762ab8f4f267701073fa44`; sette file MODIFIED incrementali, 16 percorsi cumulativi (13 MODIFIED, 3 ADDED). [Manifest, prove e limiti REV1](KEEPSTORE_MASTERPLAN_OPERATIVO.md#pr-366-rev1--bozza-focus-e-riferimenti-2026-10-21); SHA finale dal Git/rapporto. Backend, CSS e configurazioni invariati dalla revisione precedente.
- Suggest autonomo Session ReadOnly: connessione canonica senza tentativi, tenant/listino/fiscalita validati per request e account read-only; proiezione qty=1 condivisa col catalogo per prezzo/range/sort prima del LIMIT. Promo membership e soglie distinte dal prezzo unitario, id+TCId coerenti, errori distinti da vuoti, nessuna nuova persistenza.
- REV1 storica #365: normalizzazione fiscale della coppia esenzione/aliquota come la master; `Export<>0` nella sorgente comune; raccordo URL header reale con `disponibile`/`pmin`/`pmax`/`ordinamento` e alias, conflitti HTTP400; deduplica dei fatti necessari dopo tutti i join, immagini incluse, prima di molteplicita e LIMIT. Duplicati equivalenti ammessi, fatti incompatibili rifiutati.
- Guida progressiva: massimo sei risultati, preferenze rimovibili, comandi finiti, otto snapshot del solo brief, motivazioni fondate sul payload, domanda facoltativa, recupero esplicito dal vuoto e confronto effimero di 2-3 prodotti. `mode=guided` conserva il testo e accetta solo vincoli espliciti; prezzo/stock/IVA restano autorevoli server-side. Nessun LLM o nuovo archivio.
- REV1 #366: controllo comune preserva bozza prodotto/dettaglio/reparto prima di chip/affinamenti; focus assegnato durante le azioni dinamiche, mai al completamento asincrono. **655/655** controlli client/contratto offline PASS, cinque viewport e root/virtual directory; prima della correzione riprodotti i due finding. **Riusati**, dopo verifica sorgenti/prerequisiti, 616 server e precompile safe4.8 354 input PASS. Il precedente `suite.log` 439 e intermedio; `browser-report.json` 453 certifica il candidato iniziale, non REV1. SQL/MySQL, login reali, IIS e produzione NON ESEGUITI.
- Onsus: ZIP verificato al percorso mirror e SHA autorizzati, tre HTML letti senza estrazione; fonti ecommerce aggiornate nel [repertorio canonico](KEEPSTORE_NAVIGATION_UX_BENCHMARK.md#repertorio-aggiornato-2026-10-21--pr-366-rev1). Nessun rendering Onsus o test interattivo dei retailer attestato.
- CI NON CONFIGURATA, nessuna deroga #365 ereditata. Prossimo passo unico: review indipendente ChatGPT del commit pubblicato; nessun task successivo avviato. Consegna server sospesa prevalente sull'handoff ordinario AGENTS.
- Standard segreti #363 preservato, solo contratto connessione applicato: DPAPI/RSA CURRENT, KSAES2 TARGET; nessuna rotazione o configurazione operativa. Esposizioni pregresse: decisione PO invariata, nessuna scansione/bonifica ripetuta o blocco di funzioni indipendenti.
- `TENANT-RELEASE-PACKAGE-1A` SOSPESO PER DECISIONE PO: manifest/rilevatore/guida conservati, nessuna raccolta o pacchetto. Nessun DB, server, IIS, SMTP, ordine o deploy da questo batch. Nessun nuovo pannello Enzo richiesto.

### Storico precedente al batch A (non task o autorizzazione attuale)

- Repository: `KeepStoreAdmin/KeepStore3.0`; copia canonica `C:\KeepStoreWeb\KeepStore3.0\`; stable `frontend-rebuild`.
- Ultima integrazione source: PR #360 MERGED/CLOSED su `frontend-rebuild`, FF-only `ffab4224 -> 0916a1dd -> 3b1581d45fa7e782dd189060fa3b2d32050943d6`, verificato come base locale/remota del nuovo task. **WAIVER-PR360 SOURCE INTEGRATION ONLY**: compilazione 4.8 e smoke applicativo della #360 NON ESEGUITI nel suo closeout, restano gate pre-deploy; nessuna produzione attestata. Le evidenze e le deroghe delle PR precedenti conservano il proprio perimetro, senza estensioni automatiche.
- `main` / `origin/main` protetti: `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Sincronizzazione locale post #359 A; staging vuoto, web.config/quattro cancellazioni/54 untracked protetti. Ricontrollare gli stati variabili alla ripartenza, non assumere eterni questi conteggi.
- Ultimo task performance chiuso: `HOME-DB-OPEN-LATENCY-1A`, A / INTEGRATED (#352). #351 diagnostica anch'essa integrata. Review A e smoke Integration 6/6 PASS, rollback PASS; dettaglio/limiti nel [Masterplan](KEEPSTORE_MASTERPLAN_OPERATIVO.md).
- Ultimo batch shopping chiuso: `SHOPPING-MOBILE-EXCELLENCE-1A`, #355 A / INTEGRATED con deroga smoke Integration; review REV1 A, F01 focus risolto e prove fixture preservate. #354 e le sue prove rimangono chiuse nello storico.
- Ultimo micro-task account: `ACCOUNT-SESSION-REVOCATION-1A`, KS-C02 / APAT-F01 MEDIUM, **CHIUSO A / SOURCE INTEGRATION ONLY** (#359). Runtime invariato rispetto allo SHA revisionato: solo `Page.master.vb`, rivalidazione in Init e revoca terminale prima dei POST. Review indipendente A; baseline 6/6, suite System.Web 207/207 e precompile safe PASS gia acquisiti, non ripetuti. **Smoke IIS 0/8 NON ESEGUITO**, blocco permessi `web.config`, deroga esplicita PO per la sola integrazione source. Nessun PASS IIS, browser, login reale, deploy o certificazione KS-C02 complessiva; evidenze/limiti nel Masterplan.
- Ultimo task header: `HEADER-SEARCH-CONTINUITY-1A`, PR #360, **CHIUSO A / SOURCE INTEGRATION ONLY**. Base `ffab4224a3c8c1ccf0d8072cc3cf1f47fa25c5c5`, runtime approvato immutato `0916a1ddcb0c6e0cc2c479c83381e1c4af942e18`, review indipendente ChatGPT A #5564548438. Autorizzazione PO 2026-10-18: un solo commit docs-only figlio diretto, integrazione FF-only; SHA finale/stato dal Git reale. Evidenze riutilizzate: **418/418 PASS**, 108 scenari Tech/Food, Chrome reale su fixture offline ai cinque viewport: **10/10 PASS**. Non certificano IIS, DB, dispositivi fisici o WCAG completa.
- Task corrente `HOME-ADAPTIVE-SHOPPING-1A`, KS-E01 fase 1, base `3b1581d45fa7e782dd189060fa3b2d32050943d6`, branch `task/home-adaptive-shopping-1a`: implementato / **A tecnico locale**, consegna PR DRAFT per review. Introduzione tenant solo senza hero valida, unica griglia reparti adattata a pochi valori, pannello generico non duplicato e neutro, trust senza descrizione ripetuta; recenti e contratti commerciali invariati. **244/244** asserzioni su metodi WebForms compilati, **70/70** configurazioni Chrome offline Tech/Food ai cinque viewport, precompile completa ASP.NET 4.8 con configurazione sintetica **PASS**. Non certifica applicazione IIS, endpoint, DB o tenant reali; non completa KS-E01. Manifest: quattro runtime e questi tre manuali; dettaglio/limiti nel Masterplan. Nessun merge o deploy autorizzato.
- REV2 #361, mandato PO 2026-10-19, figlia del candidato originario `4b203b8663572a4f2c83114a47570cc0130dbca3`: resolver marchi solo locale sotto `/Public/assets/images/marche/`, riferimenti validati e mancanti omessi; eliminati HEAD/cache di rete, senza modifiche commerciali. **127/127 verifiche differenziali sul codice compilato, zero tentativi HTTP e nuova precompile safe ASP.NET 4.8 PASS**; evidenze originarie riusate solo nel perimetro invariato. Review A originaria non estesa automaticamente alla REV2: nuova review mirata e smoke IIS ancora pendenti. PO attesta chiave effettiva `KeepStore.Diagnostics.HomeStageTiming.Enabled` assente (default OFF); esclusivita `KeepStoreIntegrationPool` **UNKNOWN**, nessuna elevazione. Futuro smoke temporaneo: **sei file**, quattro runtime #361 revisionata, `ks-page-flags.js` stable #360 e `App_Code/HomeServerStageTiming.vb` stable; il vecchio mandato a cinque file e superato. Helper assente su Integration: aggiunta temporanea e successiva rimozione; cinque originali da ripristinare. Nessuna installazione/GET IIS, merge o deploy effettuati dalla REV2.
- **WAIVER-PR360 — SOURCE INTEGRATION ONLY**: **PRECOMPILE ASP.NET 4.8 NON ESEGUITA**, ExecutionPolicy prima dell'avvio del compilatore; **SMOKE IIS NON ESEGUITO**, nessuna prova applicazione/endpoint effettivo. Nessun bypass o cambio policy. Prima del deploy obbligatori compilazione compatibile .NET Framework 4.8, smoke applicativo ricerca header, verifica reale desktop/mobile sui due tenant e regressioni pertinenti. Deroga esclusivamente per `frontend-rebuild`, non produzione; nessuna deroga precedente (#359 inclusa) estesa. Il successivo smoke combinato #361, ancora NON ESEGUITO, include i due runtime #360 gia previsti (`ks-page-flags.js` e `Page.master`), senza estendere il manifest Git #361. Nessun server/IIS/DB o altro task. `SECURITY-DB-CREDENTIALS-HARDENING-1A` PIANIFICATO / NON AVVIATO.
- #356 `ORDER-JOURNEY-CONTINUITY-1A`: MERGED/CLOSED, due commit lineari da #355 e deroga PO specifica allo smoke Integration NON ESEGUITO. Le prove REV1 (95 test mirati, precompile safe, Session/contratti invariati) restano acquisite, non attestano E2E ordine.
- PR aperte preesistenti rilevate: #129, #170, #171, #191; non sono task attivi o nuove autorizzazioni. #170/#171 riguardano diagnosi post-ordine storica, #191 coupon differiti, #129 chiusura reset storica: riconciliare solo se diventano pertinenti, senza cleanup automatico.

## Source, Integration, produzione: tre stati distinti

| Ambito | Evidenza acquisita | Cosa NON certifica |
| --- | --- | --- |
| Source integration #360, WAIVER-PR360 | Review A, autorizzazione PO FF-only; identita finale dal Git | Compilazione 4.8 e smoke IIS NON ESEGUITI; nessuna pubblicazione |
| Integration tested #352 (storico; #359: 0/8 NON ESEGUITO, deroga PO) | Sei GET, due tenant, una Open e dieci Fill nei loader strumentati; TTFB warm medio 5.470,462 / 5.498,777 ms | Benchmark simultaneo A/B, parita commerciale completa con baseline storica, browser visuale o ogni tenant |
| Production deployed/verified | #360 e #359 NON DEPLOYATE da questi closeout; #352 DA VERIFICARE | Non dedurre da Git, smoke locale o cartella canonica |

Dipendenza release HOME: `App_Code/HomeServerStageTiming.vb` della #351, oltre a `Default.aspx.vb`; diagnostica disattivata per default. Copiare il solo file modificato quando manca l'helper puo rompere la compilazione. Pacchetto reale sempre dal delta fra commit installato e release autorizzata, non da questa lista esemplificativa.

## Gate e limiti da non perdere

- Residuo HOME warm circa 3,2 s: diagnosi read-only A, attribuzione componente B, strumentazione proposta NON IMPLEMENTATA / DIFFERITA. HEAD/cold separato, NON AVVIATO. #352 non si riapre.
- Batch continuity: 174 controlli isolati (40 ricerca, 32 URL/handler VB reali, 70 boundary client carrello, 32 quattro viste), precompile safe PASS; browser integrato su sola fixture statica a 360/390/430/768/1365, risposte sintetiche senza DB. NON certifica HOME completa, tenant reali, screen reader o percorso mutativo IIS. Nessun Apply/GET IIS o acquisto eseguito; smoke applicativo richiede target/operazioni autorizzati.
- #342 stock precheck: review/test sintetici A, smoke IIS isolato NON CERTIFICATO, integrazione per deroga PO. #343 feedback e #345 pool HOME: smoke IIS non eseguito per deroga specifica. Non promuoverli a PASS e non estendere le deroghe.
- #349 sostituisce #346: runtime identico, 687 controlli sintetici e 38 smoke HTTP/WebForms PASS; browser visuale NON ESEGUITO. #350: 153 sintetici e 86 HTTP/WebForms PASS; codice reale verificato, EAN separato non eseguito. Sono limiti storici distinti da una certificazione completa delle pagine.
- Varianti `articoli_tagliecolori` restano disabilitate. Collaudo finale reale con abilitazione 1 e contesto autenticato obbligatorio ma NON AVVIATO; fixture/DB/ordini/gateway richiedono autorizzazioni dedicate. Le 39 simulazioni compare non lo sostituiscono.
- PayPal Orders v2: checkpoint 2026-09-23 LIVE CONFIGURED / ENABLED e OAuth verificato; pagamento reale end-to-end NON ATTESTATO, non LIVE VERIFIED. BancaSella ha gate proprio. Stato documento/ordine non significa incasso.
- Rollout carrello persistente per tenant non certificato globalmente: foundation DB, configurazioni, file aggiunti App_Code, privacy/cleanup e rollback nel runbook. Nessun DDL implicito.
- Sicurezza auth/hash legacy, replay Session/InProc, verifica stock residua, consumer e-mail esterno e provisioning degli altri tenant sono rischi/gate da valutare prima del rilascio secondo roadmap, non tutti rinviabili come polish. Non dichiarare HOME/catalogo/PDP/checkout/account/ecommerce completi.

- `SECURITY-DB-CREDENTIALS-HARDENING-1A`: stato corrente prevalente in testa; il vecchio stato PIANIFICATO/NON AVVIATO e superato per il solo Batch A software. Protezione operativa, account/grant/TLS, migrazione e revoca restano separati e NON AVVIATI; database condiviso e contratti aziende/listini invariati. Nessuna operazione operativa o nuova richiesta di bonifica delle esposizioni storiche da questo checkpoint.

## Ambienti: usare lo storico senza rifare discovery generica

Il [manuale IIS](KEEPSTORE_LOCAL_IIS_ENVIRONMENT.md) e una fotografia 2026-10-13: i suoi stati #346 OPEN e mapping ancora sconosciuto sono superati dai checkpoint successivi del Masterplan. Ultimo mapping acquisito: KeepStoreIntegration `C:\Temp\KeepStoreIntegration\site`, pool `KeepStoreIntegrationPool`, HTTPS loopback/SNI :18443 per host tenant; KeepStoreSmoke punta alla copia canonica, listener :8443 distinto. Mapping/SNI attestati per lo smoke #352. Questo task documentale non interroga IIS.

Integration usa il DB remoto condiviso Taikun, non un database di test isolato. Loopback, nome Integration e TLS non rendono sicure mutazioni o GET con effetti collaterali. Riutilizzare le attestazioni ancora valide, verificare soltanto cambiamenti/gate residui e runtime effettivamente servito prima di una futura richiesta autorizzata. Dopo rollback lo stable Git non equivale al runtime Integration installato.

## Indice ragionato e autorita

Inventario dei documenti di ingresso root e di tutti i file in `docs/` alla base #352; classi per scopo, non nuove attestazioni di completamento. Root `web.config.snippet.txt` e frammento configurativo storico, non manuale operativo ne autorizzazione a sovrascrivere web.config. Licenze, log, dump e documenti sotto `Doc/` non sono nuovi canonici: `Doc/Security/` conserva checklist storiche, `Doc/AI/AGENTS.md` ha scope locale e non sostituisce il root AGENTS.

| Documento | Classe | Scopo e stato |
| --- | --- | --- |
| [README](../README.md) | CURRENT OPERATIONS | Ingresso essenziale, non altra norma |
| [AGENTS](../AGENTS.md) | CANONICAL PROCESS | Regole permanenti e autorizzazioni |
| [START_HERE](KEEPSTORE_START_HERE.md) | CURRENT OPERATIONS | Bootstrap, checkpoint breve, indice |
| [PRODUCT_ROADMAP](KEEPSTORE_PRODUCT_ROADMAP.md) | PRODUCT REQUIREMENTS | Unica roadmap vigente; CURRENT/TARGET e gate |
| [Masterplan](KEEPSTORE_MASTERPLAN_OPERATIVO.md) | CURRENT OPERATIONS + HISTORICAL | Task, prove e archivio con checkpoint prevalente |
| [System Blueprint](KEEPSTORE_SYSTEM_BLUEPRINT.md) | TECHNICAL BLUEPRINT | Architettura/contratti; stati datati non sono roadmap |
| [AI Assisted Search](KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md) | TECHNICAL BLUEPRINT | CURRENT deterministico, TARGET conversazionale/LLM separato |
| [Modular Platform](KEEPSTORE_MODULAR_PLATFORM_BLUEPRINT.md) | TECHNICAL BLUEPRINT | Progettazione moduli/draft NON INSTALLATI; priorita subordinate alla roadmap |
| [Navigation UX Benchmark](KEEPSTORE_NAVIGATION_UX_BENCHMARK.md) | BENCHMARK | Fonti/osservazioni datate, nuove fonti PO da verificare |
| [Manuale IIS](KEEPSTORE_LOCAL_IIS_ENVIRONMENT.md) | SPECIALIST RUNBOOK | Snapshot infrastrutturale; aggiornamenti nel checkpoint prevalente |
| [Persistent cart deployment](PERSISTENT_ANONYMOUS_CART_DEPLOYMENT_RUNBOOK.md) | SPECIALIST RUNBOOK | Release/DB/cleanup/rollback per tenant, non attestazione rollout |
| [PayPal Enzo](PAYPAL_CHECKOUT_ORDERS_V2_GESTIONALE_ENZO.md) | SPECIALIST RUNBOOK | Contratto pannello Orders v2 e ordine interno; pannello non dichiarato completato |
| [PayPal document status](paypal-document-payment-status.md) | SPECIALIST RUNBOOK | Stato/contratto corrente PayPal, LIVE configured non E2E verified |
| [Email Standard](KEEPSTORE_EMAIL_STANDARD.md) | SPECIALIST RUNBOOK | Contratti invio/rendering; web cutover e gate tenant distinti |
| [Email Enzo](MULTIPROVIDER_TENANT_EMAIL_CONFIG_ENZO.md) | SPECIALIST RUNBOOK | Pannello BOZZA TECNICA, provisioning manuale e consumer esterno non certificato |
| [Reset DB Vincenzo](REMIND_RESET_DB_MANUALE_VINCENZO.md) | SPECIALIST RUNBOOK | Schema/provisioning reset per destinatario autorizzato, non hash migration |
| [Payment final summary](payment-workstream-final-summary.md) | HISTORICAL/SUPERSEDED | Vecchio workstream, avviso prevalente PayPal |
| [Payment confirmation policy](payment-confirmation-policy.md) | HISTORICAL + PRODUCT PROPOSAL | Proposta PAY-2; validare contro contratto ordine/gateway attuale, non nuova implementazione |
| [Frontend final summary](frontend-workstream-final-summary.md) | HISTORICAL/SUPERSEDED | Snapshot di workstream, non full parity attuale |
| [Template implementation plan](keepstore-template-implementation-plan.md) | HISTORICAL/SUPERSEDED | Piano originario UI, non roadmap vigente |
| [Catalog manual checklist](catalog-manual-test-checklist.md) | SPECIALIST RUNBOOK | Checklist, non risultati live gia acquisiti |
| [Catalog ProductCard guardrails](catalog-product-card-guardrails.md) | SPECIALIST RUNBOOK | Contratto card; leggere con commercial context corrente |
| [Home card guardrails](home-card-componentization-guardrails.md) | SPECIALIST RUNBOOK | Componenti HOME, non adattivita completa |
| [Image asset handling](image-asset-handling.md) | SPECIALIST RUNBOOK | Gestione asset; protezione locali resta in AGENTS |
| [ProductCard release checklist](product-card-release-checklist.md) | SPECIALIST RUNBOOK | Checklist rilascio card, non deploy certificato |
| [Product detail data contract](product-detail-data-contract.md) | TECHNICAL BLUEPRINT | Contratto dati PDP da leggere con resolver attuali |
| [Product detail UI plan](product-detail-ui-plan.md) | HISTORICAL + PRODUCT PROPOSAL | Piano UI originario, non riapre task PDP chiusi |
| [Local PDP preview](local-product-detail-preview-setup.md) | HISTORICAL/SUPERSEDED | Setup preview storico, non mapping IIS attuale |

## Ripartenza e manutenzione

Seguire KS-RIPRENDI di AGENTS: verifica fatti disponibili, leggi ingresso/roadmap e fonti pertinenti, riconcilia differenze senza nuove autorizzazioni implicite, presenta stato e ONE-SHOT proponibile. Se GitHub manca, dichiarare il limite e distinguere ref locali dall'attualita remota.

Aggiornare questo checkpoint quando cambiano stable, task attivo, gate o deploy verificato; registrare prove/task nel Masterplan, requisiti/priorita solo nella roadmap, contratti nei Blueprint e regole solo in AGENTS. Dopo commit/PR usare Git per l'identita esatta del task (nessun ciclo di commit per auto-inserire il proprio SHA). Dopo merge/deploy autorizzati riconciliare lo stato senza cancellare lo storico. Questa riconciliazione non richiede file runtime da copiare sul server.
