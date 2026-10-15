# KeepStore — START_HERE

Checkpoint breve: 2026-10-15. Parola chiave: **KS-RIPRENDI**. Metodo e autorita: [AGENTS](../AGENTS.md); questo file non autorizza operazioni.

## Stato verificato e lavoro corrente

- Repository: `KeepStoreAdmin/KeepStore3.0`; copia canonica `C:\KeepStoreWeb\KeepStore3.0\`; stable `frontend-rebuild`.
- Ultimo stable locale/GitHub verificato: `b14113767d115e6b5596f0eab3c048c62928c751`, PR #352 MERGED/CLOSED, parent `e6831baaaf10d0ac689974437bf64b1a647d6b85`. Due commit originali integrati FF-only dalla base #351 `9eaead27127ec39fdd6f54349ed6fd9243d8cfb9`.
- `main` / `origin/main` protetti: `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Sincronizzazione locale post #352 A; staging vuoto, web.config/quattro cancellazioni/54 untracked protetti. Ricontrollare gli stati variabili alla ripartenza, non assumere eterni questi conteggi.
- Ultimo task runtime chiuso: `HOME-DB-OPEN-LATENCY-1A`, A / INTEGRATED (#352). #351 diagnostica anch'essa integrata. Review A e smoke Integration 6/6 PASS, rollback PASS; dettaglio/limiti nel [Masterplan](KEEPSTORE_MASTERPLAN_OPERATIVO.md).
- Task corrente: `CANONICAL-DOCS-REORG-1A`, solo nove documenti, branch `task/keepstore-canonical-docs-reorg-1a`; consegna per review indipendente, non merge o produzione. Il commit/numero PR della consegna vanno letti da Git/GitHub, non inventati prima del commit.
- Prossimo task runtime realmente autorizzato: **NESSUNO**. Candidato da sottoporre a PO: `CORE-SHOPPING-CONTINUITY-1A`, outcome e gate nella [roadmap](KEEPSTORE_PRODUCT_ROADMAP.md#ks-a01--percorso-shopping-continuo). Non avviarlo con KS-RIPRENDI.
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
