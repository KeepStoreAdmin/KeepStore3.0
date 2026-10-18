# KeepStore — START_HERE

Checkpoint breve: 2026-10-18. Parola chiave: **KS-RIPRENDI**. Metodo e autorita: [AGENTS](../AGENTS.md); questo file non autorizza operazioni.

## Stato verificato e lavoro corrente

- Repository: `KeepStoreAdmin/KeepStore3.0`; copia canonica `C:\KeepStoreWeb\KeepStore3.0\`; stable `frontend-rebuild`.
- Ultima integrazione source: PR #359 su `frontend-rebuild`, FF-only dalla base #358 `e5a8b309c7dc7f4c171a15b080bc22cc897e0d59`; runtime originario `be1033112bd5ad3acce4d21480800da612fe59e2`, seguito dal solo commit documentale di chiusura. SHA finale e stato MERGED/CLOSED da Git, senza commit ricorsivi per inserire il proprio SHA. Review indipendente A e deroga PO 2026-10-18: **SOURCE INTEGRATION ONLY**. #358 conserva review A/smoke IIS 28/28; #357 conserva 19/19 e limiti accettati. Nessuna pubblicazione produzione attestata; le deroghe #354/#355/#356 non si estendono a KS-C02.
- `main` / `origin/main` protetti: `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Sincronizzazione locale post #359 A; staging vuoto, web.config/quattro cancellazioni/54 untracked protetti. Ricontrollare gli stati variabili alla ripartenza, non assumere eterni questi conteggi.
- Ultimo task performance chiuso: `HOME-DB-OPEN-LATENCY-1A`, A / INTEGRATED (#352). #351 diagnostica anch'essa integrata. Review A e smoke Integration 6/6 PASS, rollback PASS; dettaglio/limiti nel [Masterplan](KEEPSTORE_MASTERPLAN_OPERATIVO.md).
- Ultimo batch shopping chiuso: `SHOPPING-MOBILE-EXCELLENCE-1A`, #355 A / INTEGRATED con deroga smoke Integration; review REV1 A, F01 focus risolto e prove fixture preservate. #354 e le sue prove rimangono chiuse nello storico.
- Ultimo micro-task account: `ACCOUNT-SESSION-REVOCATION-1A`, KS-C02 / APAT-F01 MEDIUM, **CHIUSO A / SOURCE INTEGRATION ONLY** (#359). Runtime invariato rispetto allo SHA revisionato: solo `Page.master.vb`, rivalidazione in Init e revoca terminale prima dei POST. Review indipendente A; baseline 6/6, suite System.Web 207/207 e precompile safe PASS gia acquisiti, non ripetuti. **Smoke IIS 0/8 NON ESEGUITO**, blocco permessi `web.config`, deroga esplicita PO per la sola integrazione source. Nessun PASS IIS, browser, login reale, deploy o certificazione KS-C02 complessiva; evidenze/limiti nel Masterplan.
- Ultimo task header: `HEADER-SEARCH-CONTINUITY-1A`, PR #360, **CHIUSO A / SOURCE INTEGRATION ONLY**. Base `ffab4224a3c8c1ccf0d8072cc3cf1f47fa25c5c5`, runtime approvato immutato `0916a1ddcb0c6e0cc2c479c83381e1c4af942e18`, review indipendente ChatGPT A #5564548438. Autorizzazione PO 2026-10-18: un solo commit docs-only figlio diretto, integrazione FF-only; SHA finale/stato dal Git reale. Evidenze riutilizzate: **418/418 PASS**, 108 scenari Tech/Food, Chrome reale su fixture offline ai cinque viewport: **10/10 PASS**. Non certificano IIS, DB, dispositivi fisici o WCAG completa.
- **WAIVER-PR360 — SOURCE INTEGRATION ONLY**: **PRECOMPILE ASP.NET 4.8 NON ESEGUITA**, ExecutionPolicy prima dell'avvio del compilatore; **SMOKE IIS NON ESEGUITO**, nessuna prova applicazione/endpoint effettivo. Nessun bypass o cambio policy. Prima del deploy obbligatori compilazione compatibile .NET Framework 4.8, smoke applicativo ricerca header, verifica reale desktop/mobile sui due tenant e regressioni pertinenti. Deroga esclusivamente per `frontend-rebuild`, non produzione; nessuna deroga precedente (#359 inclusa) estesa. Runtime futuro smoke: solo `Public/assets/keepstore/js/ks-page-flags.js` e `Page.master`, non installati. Nessun server/IIS/DB o altro task. `SECURITY-DB-CREDENTIALS-HARDENING-1A` PIANIFICATO / NON AVVIATO.
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

- `SECURITY-DB-CREDENTIALS-HARDENING-1A`: **PIANIFICATO / NON AVVIATO**, fase conclusiva sicurezza/SEO. Account dedicati per sito, privilegi minimi verificati, protezione segreti e migrazione graduale con backup/rollback/test; Taikun e Webaffare mantengono database condiviso e isolamento applicativo aziende. Credenziali gia esposte: rotazione prioritaria anticipata con autorizzazione separata. Nessun intervento strutturale alle connessioni nei micro-task funzionali.

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
