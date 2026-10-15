# KeepStore — START_HERE

Checkpoint breve: 2026-10-15. Parola chiave: **KS-RIPRENDI**. Metodo e autorita: [AGENTS](../AGENTS.md); questo file non autorizza operazioni.

## Stato verificato e lavoro corrente

- Repository: `KeepStoreAdmin/KeepStore3.0`; copia canonica `C:\KeepStoreWeb\KeepStore3.0\`; stable `frontend-rebuild`.
- Ultimo stable locale/GitHub verificato: `5e31cbd6ef24c34a191117dad9d16971e85d43b3`, PR #355 MERGED/CLOSED, due commit lineari da #354 `7ef9482e6795403cad7587313c1593aa16d7251f`; sync locale post #355 A. Smoke Integration #355 NON ESEGUITO per deroga PO specifica registrata nella PR; nessuna pubblicazione #355 attestata. #354 conserva la propria deroga e la dichiarazione PO di pubblicazione/funzionalita, non verifica indipendente.
- `main` / `origin/main` protetti: `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Sincronizzazione locale post #352 A; staging vuoto, web.config/quattro cancellazioni/54 untracked protetti. Ricontrollare gli stati variabili alla ripartenza, non assumere eterni questi conteggi.
- Ultimo task performance chiuso: `HOME-DB-OPEN-LATENCY-1A`, A / INTEGRATED (#352). #351 diagnostica anch'essa integrata. Review A e smoke Integration 6/6 PASS, rollback PASS; dettaglio/limiti nel [Masterplan](KEEPSTORE_MASTERPLAN_OPERATIVO.md).
- Ultimo batch shopping chiuso: `SHOPPING-MOBILE-EXCELLENCE-1A`, #355 A / INTEGRATED con deroga smoke Integration; review REV1 A, F01 focus risolto e prove fixture preservate. #354 e le sue prove rimangono chiuse nello storico.
- Task corrente autorizzato: `ORDER-JOURNEY-CONTINUITY-1A`, KS-C01, branch `task/order-journey-continuity-1a`, base #355. Solo presentazione: descrizioni consegna/pagamento dal draft e dai controlli server corrispondenti, errore lettura distinto dal carrello vuoto, conferma ordine distinta dall'incasso. Tre runtime; core ordine/auth/prezzi/stock/SQL e JS/CSS invariati. Test isolati/precompile/browser fixture acquisiti nel Masterplan; A tecnico / B complessivo per review e gate applicativo NON ESEGUITO. Commit/PR da Git, non SHA auto-inseriti.
- Prossimo task runtime autorizzato oltre al batch corrente: **NESSUNO**. Candidato KS-C02 `ACCOUNT-JOURNEY-READINESS-1A`, NON AVVIATO dopo chiusura/decisione PO; nessuna autorizzazione a ordini, gateway, DB o server.
- REV1 #356: F01 righe stale/read fallita riprodotto su controlli System.Web isolati e corretto nel solo VB presentazionale; 95 test mirati e precompile safe PASS, Session/contratti invariati. A tecnico REV1 / B complessivo per review REV1 e gate applicativo NON ESEGUITO; nessun merge autorizzato.
- PR aperte preesistenti rilevate: #129, #170, #171, #191; non sono task attivi o nuove autorizzazioni. #170/#171 riguardano diagnosi post-ordine storica, #191 coupon differiti, #129 chiusura reset storica: riconciliare solo se diventano pertinenti, senza cleanup automatico.

## Source, Integration, produzione: tre stati distinti

| Ambito | Evidenza acquisita | Cosa NON certifica |
| --- | --- | --- |
| Source integrated #351/#352 | SHA stabile verificato, locale allineato | File pubblicati su tutte le istanze IIS |
| Integration tested #352 | Sei GET, due tenant, una Open e dieci Fill nei loader strumentati; TTFB warm medio 5.470,462 / 5.498,777 ms | Benchmark simultaneo A/B, parita commerciale completa con baseline storica, browser visuale o ogni tenant |
| Production deployed/verified | Per #352 DA VERIFICARE; nessun deploy da questa riconciliazione | Non dedurre da Git, smoke locale o cartella canonica |

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
