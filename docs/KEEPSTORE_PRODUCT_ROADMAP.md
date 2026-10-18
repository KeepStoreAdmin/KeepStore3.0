# KeepStore — PRODUCT_ROADMAP

Unica roadmap di prodotto vigente, 2026-10-18. Metodo/autorita in [AGENTS](../AGENTS.md), stato breve in [START_HERE](KEEPSTORE_START_HERE.md), task e prove nel [Masterplan](KEEPSTORE_MASTERPLAN_OPERATIVO.md). Le vecchie scalette nei Blueprint, benchmark e Masterplan sono storiche, non ordini concorrenti. Git/codice e prove reali prevalgono sulle etichette documentali.

## Priorita e lettura degli stati

Mandato PO: **PRIMA ecommerce funzionale, affidabile, moderno, bello e navigabile da smartphone, lungo tutto il percorso fino all'ordine. POI rifinimenti, performance non bloccanti, SEO avanzata, integrazioni e automazioni.** Sicurezza, correttezza commerciale, integrita ordine e pagamento, HTTPS e SEO tecnica indispensabile rimangono gate di rilascio, non polish. HOME adattiva e assistente sono requisiti approvati: non implicano sistemi gia implementati o chiamate AI autorizzate.

P0 = gate di affidabilita/rilascio; P1 = outcome cliente core; P2 = evoluzione post-core. `PARZIALE` indica componenti integrati ma outcome non certificato; `GATE APERTO` prova/prerequisito non attestato; `TARGET` requisito futuro; `DIFFERITO` nessuna esecuzione corrente. Un task chiuso A non completa una pagina o tutti i tenant. Feature-batch sotto sono proposte di perimetro con 2-4 criteri collegati, NON manifest/implementazioni gia autorizzati.

## Fonti tracciabili

- S1: mandato Product Owner `CANONICAL-DOCS-REORG-1A`, 2026-10-15, acquisito nel checkpoint Masterplan omonimo e in questa roadmap.
- S2: codice sullo stable #352 `b14113767d115e6b5596f0eab3c048c62928c751`, ispezione locale mirata 2026-10-15; non collaudo runtime nuovo.
- S3: checkpoint Masterplan e storia Git/PR; prove storiche con data/limiti, non test ripetuti da questa riconciliazione.
- S4: [System Blueprint](KEEPSTORE_SYSTEM_BLUEPRINT.md), [AI/search](KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md), [runbook carrello](PERSISTENT_ANONYMOUS_CART_DEPLOYMENT_RUNBOOK.md), [PayPal status](paypal-document-payment-status.md), [Email Standard](KEEPSTORE_EMAIL_STANDARD.md), [Modular Blueprint](KEEPSTORE_MODULAR_PLATFORM_BLUEPRINT.md). Specifiche non equivalgono a rollout.
- S5: [Navigation UX Benchmark](KEEPSTORE_NAVIGATION_UX_BENCHMARK.md), fonti storiche 2026-10-09 e riferimenti PO acquisiti 2026-10-15 senza nuove visite; non nuove osservazioni browser.

## A. CORE SHOPPING EXPERIENCE

### KS-A01 — Percorso shopping continuo

- Batch correttivo corrente `HEADER-SEARCH-CONTINUITY-1A`, KS-A01 / KS-B01, mandato PO 2026-10-18: concorrenza suggest A->B->A, stati/contratto delle risposte, invio unico Codice/EAN/fallback e lifecycle tastiera/touch dell'header. Base esatta `ffab4224a3c8c1ccf0d8072cc3cf1f47fa25c5c5`; runtime limitato a `ks-page-flags.js` e cache-buster in `Page.master`, nessun backend/commerciale. **418 controlli deterministici e 10 configurazioni Chrome su fixture Tech/Food PASS**; rete offline, cinque larghezze 360/390/430/768/1365, non IIS o tenant reali. Precompile NON ESEGUITA per policy Windows (compilatore non avviato), nessun cambio alle protezioni. Consegna PR DRAFT, review nuova patch e gate applicativo ancora separati: macro-percorso PARZIALE, nessun merge/deploy autorizzato. Evidenze e limiti nel Masterplan; non riapre le PR #315/#326/#327/#349/#354/#355 o #359.
- Fonte/data: mandato PO `CORE-SHOPPING-CONTINUITY-1A` acquisito 2026-10-15, base #353 `8fdeebe7e269ef40a7113bb0cb922d420b5f34dc`, S2/S3. Priorita P1; requisito PARZIALE, batch #354 CHIUSO A / INTEGRATED con deroga autorizzata allo smoke Integration (NON ESEGUITO), non certificazione completa del percorso.
- CURRENT: HOME, header/menu/search, listing quattro viste, facet, PDP, compare e CTA esistono; navigazione #315-#327, filtri #328-#336, confronto #337-#340 e ViewState #349 hanno chiusure circoscritte. Non full parity ONSUS, non collaudo completo di ogni pagina/dispositivo.
- TARGET: cliente trova il prodotto, comprende informazioni/condizioni e raggiunge il carrello senza interruzioni, da smartphone e desktop, su cataloghi diversi.
- FEATURE-BATCH proposto `CORE-SHOPPING-CONTINUITY-1A`: (1) HOME -> ricerca/menu -> catalogo con contesto preservato; (2) facet/zero-results -> PDP/compare con destinazioni reali; (3) CTA/quantita -> carrello con feedback comprensibile. AC: nessun dead-end, filtro perso, controllo irraggiungibile o prezzo non autorevole nei percorsi concordati; stessa semantica mobile/desktop.
- Dipendenze/gate: scenario e manifest approvati, fixture pertinenti e browser disponibile; Design Gate se occorre UI. Prove: S3/S5, da riusare senza riaprire task chiusi; i soli gap riprodotti entrano nel futuro batch, niente audit generale o nuovo motore commerciale.
- Evidenza del batch: race/debounce e messaggio di errore nella ricerca HOME riprodotti e corretti, senza cambiare endpoint/ranking o contratti commerciali. PR #354 REV1: errore applicativo HTTP 200/payload invalido distinto da zero-results, pending immediato senza vecchi prodotti durante il debounce; 90 controlli mirati isolati PASS, review REV1 pendente. I precedenti 174 controlli e precompile safe PASS non sono rieseguiti integralmente; fixture browser del primo commit ai cinque viewport, non smoke IIS/E2E o certificazione visuale dell'intero storefront. Nessun gap aggiuntivo dimostrato nelle boundary URL/carrello esaminate; i percorsi live restano da collaudare con autorizzazione specifica, non dichiarati completi. Nessun nuovo task B/C o performance avviato.

### KS-A02 — Disponibilita, prezzi, promo e identita prodotto coerenti

- Fonte/data: S2/S3/S4, 2026-10-15. P0 correttezza commerciale; stato INTEGRATO nei perimetri noti / GATE finali APERTI.
- CURRENT: price context VAT #304-#308, snapshot compare #338-#340, stock netto condiviso #341, precheck batch #342 e feedback #343. Quantita finale aggregata id+TCId, riduzioni/remove/clear e verifica definitiva ordine restano contratti distinti; il precheck non prenota stock. Ricondizionato esclusivamente flag numerico =1 (#334/#335), mai settore.
- TARGET/AC del batch proposto `COMMERCIAL-SURFACE-PARITY-1A`: (1) stesso id+TCId/listino/IVA/promo nelle superfici reali; (2) nessun dato NotVerified spacciato per attuale o CTA compare per indisponibili; (3) errori stock 422 distinti da tecnici 5xx e nessun batch parziale. Non alterare condizioni commerciali per correggere grafica.
- Dipendenze: fixture/tenant e autorizzazione per ogni eventuale mutazione. Prove S3: #341 smoke PO A; #342 269 controlli dichiarati PASS ma smoke IIS isolato NON CERTIFICATO, integrata per deroga; #343 deroga smoke NON ESEGUITO. Collaudo controllato residuo non sostituito da queste etichette, senza ripetere le suite immutate.

## B. PREMIUM ONSUS + MOBILE EXCELLENCE

### KS-B01 — Esperienza premium accessibile, non sola leggerezza

- REV1 #355: F01 focus corretto con priorita al trigger Filtri e fallback utilizzabile per sostituzione/desktop; nessun nuovo listener o cambiamento commerciale. Review REV1 A e test focus mirati su fixture browser Tech/Food PASS; #355 MERGED/CLOSED con deroga PO specifica allo smoke Integration NON ESEGUITO. Sync locale A; nessuna attestazione production deployed (dettaglio Masterplan).
- Fonte/data: S1/S5 e mandato PO `SHOPPING-MOBILE-EXCELLENCE-1A`, 2026-10-15, base #354 `7ef9482e6795403cad7587313c1593aa16d7251f`. P1; macro-requisito PARZIALE, batch CHIUSO A / INTEGRATED #355 con deroga circoscritta; nessuna certificazione visuale universale.
- CURRENT: componenti ONSUS adattati, card/menu/offcanvas e checkout migliorati da task chiusi; benchmark storico e limiti dei browser/test nel Masterplan. #349 ha prova funzionale HTTP ma non browser visuale.
- TARGET: grafica moderna/premium coerente fra pagine, leggibilita, touch e feedback; nessuna funzione persa per assomigliare alla demo. Riferimenti PO: ONSUS/varianti HOME, bytecno.it, prezzoforte.it, e-stayon.com, Mollie trends; repertorio storico IKEA/Decathlon/MediaWorld/Baymard/W3C preservato, non osservazioni nuove.
- FEATURE-BATCH proposto `SHOPPING-MOBILE-EXCELLENCE-1A`: (1) contenuti/CTA e stati leggibili; (2) focus/tastiera/touch/scroll senza blocchi; (3) continuita layout fra listing/PDP/cart. AC progressivi 360/390/430, tablet e desktop, browser/dispositivi dichiarati, immagini contain/assenza overflow pertinente, nessuna funzione essenziale hover-only. Pochi viewport non certificano tutti i telefoni.
- Dipendenze/prove: Design Gate AGENTS, fixture di almeno due merceologie, screenshot/browser reali per i gate visuali. Benchmark e test sintetici non diventano certificazione UX end-to-end o incremento conversione misurato.
- Evidenza batch: canvas originale con focus/Tab/Escape/ARIA/scroll e breakpoint 1200 coerente, CTA card 44px preservando allineamenti/quattro viste, unica buybox PDP con stepper 48px ed etichette, spedizione dopo quantita/CTA senza nuova sticky. Sei runtime, MiniCart/servizi invariati. Browser reale su fixture Tech/Food: sei larghezze, 48 configurazioni listing, PDP/MiniCart e lifecycle simulato; screenshot prima/dopo. Precompile safe e contratti statici PASS. Nessun IIS/DB o acquisto certificato; dettaglio e limiti nel Masterplan.

## C. ORDER-TO-CONFIRMATION

### KS-C01 — Carrello, checkout e conferma senza esiti ambigui

- Chiusura prevalente 2026-10-16: #356 MERGED/CLOSED a `f287b7371b334aaa24f83cff6775ac5c42803db8`, FF-only, review REV1 A e deroga PO specifica allo smoke Integration NON ESEGUITO. Il seguente mandato/test rimane storico; il batch non e piu attivo e non certifica il macro-percorso completo.
- REV1 #356: F01 corretto nella sola presentazione anche con righe ViewState positive e lettura non verificabile; avviso e blocco visuale finale, senza alterare Session, ownership o regole ordine. 95 test isolati mirati e precompile safe PASS; review REV1 e gate applicativo pendenti, non certificazione IIS/E2E (Masterplan).
- Mandato PO 2026-10-15: `ORDER-JOURNEY-CONTINUITY-1A` ATTIVO, base #355 `5e31cbd6ef24c34a191117dad9d16971e85d43b3`. A tecnico / B complessivo per review e gate applicativo NON ESEGUITO. Delta: metodi effettivi verificabili nel riepilogo, errore lettura distinto da vuoto, conferma distinta da pagamento; nessun nuovo checkout o intervento transazionale. Autenticazione, invio ordine e incasso reali NON CERTIFICATI dalle fixture. Evidenze/limiti nel Masterplan; nessuna deroga automatica, merge o pubblicazione.
- Fonte/data: S1/S3/S4, 2026-10-15. P0/P1; PARZIALE con gate di collaudo/release.
- CURRENT: carrello owner-scoped, persistenza/merge login, spedizione/soglia e indirizzi, checkout/ordine idempotente e conferme hanno implementazioni; autorizzazioni mutative non si estendono a nuovi test. Un ordine/documento creato non equivale a pagamento incassato.
- TARGET/AC del batch proposto `ORDER-JOURNEY-CONTINUITY-1A`: (1) anonimo -> login -> carrello senza perdita/duplicazione; (2) spedizione/pagamento/indirizzi/totali -> riepilogo modificabile; (3) invio -> un unico esito terminale osservabile -> conferma/account. Nessun fallback silenzioso verso documenti, duplicazione ordine o email su replay/rollback.
- Dipendenze: gate D/G, target e operazioni autorizzati, fixture ripristinabili; gateway/auth/DB separati se richiedono modifiche o test rischiosi. Prove S3: chiusure checkout/ordine e smoke PO circoscritti; idempotenza transazionale ordine non elimina il debito distinto dei registri carrello Session/InProc (`CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A`, E/differito).

### KS-C02 — Account, autenticazione e handoff gestionale affidabili

- Checkpoint PO 2026-10-18: #359 `ACCOUNT-SESSION-REVOCATION-1A` / APAT-F01 MEDIUM **CHIUSO A / SOURCE INTEGRATION ONLY**, FF-only da #358 `e5a8b309c7dc7f4c171a15b080bc22cc897e0d59`, runtime revisionato `be1033112bd5ad3acce4d21480800da612fe59e2` invariato e solo chiusura documentale aggiunta; SHA finale dal Git reale. Review indipendente A, baseline 6/6, candidata System.Web 207/207 e precompile safe PASS gia acquisiti, senza ripetizione. **Smoke IIS 0/8 NON ESEGUITO** per permessi `web.config`; deroga esplicita PO alla sola integrazione source, nessun PASS IIS o deploy. #358 mantiene F01 chiuso con 28/28, #357 F02/F03 con 19/19 e limiti accettati. Nessuna compromissione di altri owner dimostrata; KS-C02 resta PARZIALE e autenticato reale non certificato.
- Fonte/data: S3/S4, 2026-10-15. P0 sicurezza, P1 percorso account; PARZIALE / rischi DA VERIFICARE prima del rilascio.
- CURRENT: login contestuale, reset tokenizzato, profilo/indirizzi/documenti/email con task integrati. Debito storico password legacy in chiaro/hash migration e copertura anti-CSRF auth non dichiarati risolti dal reset tokenizzato; verificare stato corrente e impatto, non rinviarli come dettaglio estetico. Account sintetici non certificano autenticato reale.
- TARGET/AC del batch proposto `ACCOUNT-JOURNEY-READINESS-1A`: (1) accesso/ritorno allo shopping e logout coerenti; (2) profilo/indirizzi/documenti solo owner+azienda; (3) reset e conferme comprensibili senza segreti esposti. Sicurezza auth che impedisce rilascio richiede task/gate dedicato, non un fix implicito nello styling.
- Dipendenze/prove: [manuale reset Vincenzo](REMIND_RESET_DB_MANUALE_VINCENZO.md), [email Enzo](MULTIPROVIDER_TENANT_EMAIL_CONFIG_ENZO.md), [PayPal Enzo](PAYPAL_CHECKOUT_ORDERS_V2_GESTIONALE_ENZO.md). Schermate/procedure future distinte da pannelli implementati; `OrigineOrdine='INTERNO'` nel salvataggio gestionale e consumer esterno `inviadocumenti` restano handoff/gate specifici. Email web Taikun TRANSACTIONAL ha smoke PO A; non certifica altri tenant, consumer esterno o OAuth2 SMTP, ancora NON OPERATIVO.

## D. PAYMENT AND RELEASE SAFETY GATES

### KS-D01 — PayPal: configurato LIVE non significa incasso verificato

- Fonte/data: S3/S4, checkpoint 2026-09-23 riconciliato 2026-10-15. P0 per release che offre PayPal; GATE APERTO end-to-end.
- CURRENT: Orders API v2 REST LIVE, credenziali DB-driven, OAuth LIVE HTTP 200 e webhook configurati secondo checkpoint; nessun pagamento reale E2E attestato. NVP/Express/Sandbox e vecchio summary non sono contratto corrente. Nessuna nuova verifica gateway svolta ora.
- TARGET/AC del batch proposto `PAYPAL-LIVE-RELEASE-GATE-1A`: (1) tenant/merchant/importo/valuta e autorizzazione esatti; (2) capture autorevole COMPLETED e ritorno/cancel coerenti; (3) webhook firma/replay e stato documento senza doppio incasso/ordine. Soltanto prove esplicitamente autorizzate permettono l'etichetta LIVE VERIFIED.
- Dipendenze/prove: [contratto corrente](paypal-document-payment-status.md), System Blueprint 5.8.1 e manuale Enzo; configurazione/specifica pannello non equivale a pannello completato. Nessuna credenziale nei documenti o fallback cross-tenant, nessun pagamento attivato da questa roadmap.

### KS-D02 — BancaSella: gate indipendente

- Fonte/data: S3/S4, riconciliazione 2026-10-15. P0 se offerto; stato storico implementato, certificazione attuale per release/tenant DA VERIFICARE.
- CURRENT: launcher/callback/return e gestione documento documentati nel [summary storico](payment-workstream-final-summary.md). Non eredita prove OAuth/capture PayPal.
- TARGET/AC del batch proposto `SELLA-RELEASE-GATE-1A`: (1) importo/valuta/merchant e correlazione documento; (2) esito autorevole server-to-server e ritorni coerenti; (3) replay/errori/stato pagamento senza falsa conferma d'incasso. Verificare capture/webhook o callback secondo il contratto effettivo del gateway, non imporre i nomi API PayPal.
- Dipendenze/prove: ambiente/config e autorizzazione dedicati, contratto ordine corrente; test finanziari reali non impliciti. Eventuali gap sicurezza/pagamento bloccanti non sono post-core.

### KS-D03 — Rollout carrello persistente e prerequisiti per tenant

- Fonte/data: S3/S4, runbook 2026-10-01, riconciliazione 2026-10-15. P0 per rollout; INTEGRATED / NOT GLOBALLY PRODUCTION-CERTIFIED.
- CURRENT: #297-#299 integrate, cookie tecnico 30 giorni e privacy; registry DB/cleanup/provisioning restano prerequisiti di installazione, non autorizzazione globale.
- TARGET/AC del batch proposto `PERSISTENT-CART-TENANT-ROLLOUT-1A`: (1) schema/indici e HTTPS/config della sola destinazione; (2) cookie/persistenza/merge login/privacy senza rinnovo su letture; (3) cleanup bounded/scheduler soltanto se autorizzato e backup/rollback verificabili. Inventario di database non e allowlist di deployment.
- Dipendenze/prove: [runbook specialistico](PERSISTENT_ANONYMOUS_CART_DEPLOYMENT_RUNBOOK.md), autorizzazione per target e mutazioni; nessun DDL, scheduler, ordine o pagamento automatico.

## E. ADAPTIVE MULTI-MERCHANDISE HOME

### KS-E01 — HOME adattiva a cataloghi realmente diversi

- Fonte/data: S1/S2/S4, 2026-10-15. P1 prodotto; CURRENT PARZIALE / TARGET non completato.
- CURRENT: sezioni/dati HOME, tassonomia e contesto commerciale dinamici; non esiste una capability engine generale certificata. `StorefrontCapabilityProfile` non e dichiarato implementato. Ottimizzazioni #345/#352 non completano l'adattivita.
- TARGET/AC del batch proposto `HOME-ADAPTIVE-SHOPPING-1A`: (1) composizione capability-driven da dati reali; (2) banner/branding/prodotti/attributi pertinenti e omissione delle sezioni prive di dati; (3) accesso mobile chiaro a ricerca/catalogo/assistente. Una release per elettronica, food, pitture, moda e altri cataloghi, senza demo o inferenze arbitrarie dalla merceologia.
- Dipendenze/prove: [confine architetturale](KEEPSTORE_SYSTEM_BLUEPRINT.md#home-adattiva-e-assistente--confine-current--target), contratto capability da approvare, resolver invariati. AC multi-tenant con almeno due cataloghi sintetici di merceologie diverse e QA mobile, inclusi assenza attributi/immagini, catalogo piccolo/vuoto e isolamento listino/promo. Nessuna query per card o cache cross-tenant.

## F. SHOPPING ASSISTANT

### KS-F01 — Assistente riconoscibile e conversazione progressiva

- Fonte/data: S1/S2/S4, 2026-10-15. P1 esperienza guidata; CURRENT deterministico / TARGET conversazionale.
- CURRENT: `KsLocalAiSearch130` e `/search_suggest.aspx?mode=ai`, ricerca/ranking locali; non chat LLM. TARGET: assistente visibile con nome KeepStore DA APPROVARE, ispirato alla categoria di esperienza storicamente chiamata Amazon Rufus, non branding copiato o equivalenza funzionale attestata.
- FEATURE-BATCH proposto `SHOPPING-ASSISTANT-GUIDED-ENTRY-1A`: (1) entry point riconoscibile; (2) richiesta naturale e chiarimento guidato quando ambiguo; (3) risultati reali con motivazione fondata e fallback al catalogo. AC: due merceologie, nessun prodotto/compatibilita inventato, prezzi/stock solo autorevoli, mobile accessibile, errori distinti da zero risultati.
- Dipendenze/prove: [contratto AI CURRENT/TARGET](KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md#contratto-prevalente-2026-10-15--assistente-acquisti-current--target), privacy/minimizzazione e nome approvati. Carrello/account/cookie/owner esclusi da AI/RAG; nessuna API esterna o nuova persistenza implicita. Voce, immagini, hybrid search, embeddings, RAG e LLM richiedono decisioni/task successivi; SEO AI crawler distinta. Questo mandato approva il requisito, non l'implementazione del batch.

## G. RELEASE READINESS

### KS-G01 — Pacchetto e stato reale di ogni tenant

- Fonte/data: S1/S3/S4, 2026-10-15. P0 rilascio; GATE APERTO, nessuna produzione globale certificata.
- CURRENT: release source e prove Integration disponibili; inventario dei file realmente pubblicati per ciascun tenant incompleto/DA VERIFICARE. #352 non automaticamente pubblicata; `HomeServerStageTiming.vb` e dipendenza aggiunta da #351, anche quando la diagnostica resta spenta.
- TARGET/AC del batch proposto `TENANT-RELEASE-PACKAGE-1A`: (1) delta added/modified/deleted/renamed fra commit installato/release con dipendenze App_Code/Bin/cache-buster; (2) config/asset per destinazione autorizzata, senza segreti o dump nel pacchetto; (3) backup/rollback e prove funzionali/visuali/commerciali con stato produzione verificato. Trasferimento file semplice e completo verso applicazioni IIS distinte, nessun file runtime dimenticato.
- Dipendenze/prove: policy release AGENTS, runbook pertinenti, mapping/DB/hash target certificati e allowlist PO. Non interrogare o modificare siti/DB da questa roadmap; merge/Integration non autorizzano produzione.

### KS-G02 — Collaudo finale varianti e autenticato

- Fonte/data: decisione PO registrata al gate #339 nel Masterplan, riconciliata 2026-10-15. P0 certificazione finale; DIFFERITO / NON AVVIATO, non cancellato dal post-core.
- CURRENT: `articoli_tagliecolori` disabilitato; 39 simulazioni compare PASS e prove sintetiche commerciali non sostituiscono varianti/autenticato reali.
- TARGET/AC del batch proposto `ECOMMERCE-FINAL-VARIANTS-AUTH-1A`: (1) abilitazione 1 soltanto su target/fixture autorizzati; (2) PDP/catalogo/HOME/search/compare con id+TCId, prezzo/stock distinti e no fallback su variante invalida; (3) carrello/login/quantita/checkout/documenti, anonimo e autenticato, due tenant/listini e mobile/desktop. Pagamenti/e-mail/ordini reali hanno ulteriori autorizzazioni, non ereditate dall'abilitazione varianti.
- Dipendenze/prove: matrice finale completa nel Masterplan, piano ripristino e gate sicurezza D/C. Lasciare disabilitato nel frattempo; nessun cambiamento flag o fixture DB ora.

## H. POST-CORE EVOLUTION

### KS-H01 — Performance residua e HEAD/cold

- Fonte/data: #351/#352 e diagnosi read-only 2026-10-15, S3. P2 non bloccante; DIFFERITO.
- CURRENT: #352 warm TTFB 5.470,462 / 5.498,777 ms; confronto storico -43,24%/-42,21%, non A/B simultaneo o parita commerciale completa certificata. Residuo warm 3.228,240 / 3.261,403 ms localizzato ma non attribuito al componente; diagnosi A, attribuzione B, strumentazione NON IMPLEMENTATA. HEAD iniziali separati, NON AVVIATI.
- TARGET/AC del batch futuro `HOME-WARM-ATTRIBUTION-RESUME-1A`: (1) sola strumentazione minima dei componenti mancanti dopo review; (2) misure autorizzate senza somma di span inclusivi; (3) solo hotspot dimostrato e parita/regressioni pertinenti. HEAD/cold mantiene un perimetro distinto, non un secondo task implicito.
- Dipendenze: core prioritario e nuova autorizzazione diagnostica/Apply; prove esistenti riusate, nessun nuovo benchmark, pooling o caching globale da questa riconciliazione.

### KS-H02 — SEO avanzata, marketplace, automazioni e moduli

- Fonte/data: S1/S4, 2026-10-15. P2; TARGET / progettazione versionata, NON INSTALLATA.
- CURRENT: SEO tecnica di base e resolver Product/Offer esistono; draft modulari non attivano Google/Merchant Center, Amazon/eBay, TikTok Shop, social marketing, licenze, IndexNow autonomo o automazioni AI.
- TARGET/AC del batch futuro `POST-CORE-MODULE-READINESS-1A`: (1) scegliere un solo modulo/outcome e dati autorevoli; (2) configurazione/pannello e dati operativi del dominio separati; (3) consensi/sicurezza/limiti/test tenant e rollback approvati. Integrazioni con rischi indipendenti diventano task separati, non un mega-batch.
- Dipendenze/prove: Blueprint modulare e AI/search, audit specifico quando autorizzato; SEO tecnica indispensabile, HTTPS e correttezza commerciale restano P0, non rinviate insieme al marketing. Recesso digitale B2C, coupon/Groupon, abandoned-cart/privacy e altri requisiti storici restano tracciati nel Masterplan: non attivati o cancellati; rilevanza normativa/commerciale da riesaminare prima della release pertinente.

### KS-H03 — Sicurezza credenziali database, pianificazione conclusiva

- Decisione PO riconfermata 2026-10-18: `SECURITY-DB-CREDENTIALS-HARDENING-1A` **PIANIFICATO / NON AVVIATO**, per la fase conclusiva dedicata a sicurezza e SEO; nessun intervento strutturale alle connessioni durante i micro-task funzionali.
- Perimetro futuro: account dedicati per sito, privilegi minimi verificati sul database necessario, protezione dei segreti e migrazione graduale con backup, rollback e test. Taikun e Webaffare mantengono il database condiviso e l'isolamento applicativo delle aziende; il solo database nella connection string non limita i privilegi dell'account.
- Credenziali gia esposte: rotazione prioritaria anticipata, con autorizzazione separata; non rinviata automaticamente alla fase conclusiva. Nessuna connessione, credenziale, configurazione, utenza/privilegio DB o infrastruttura modificata da #359. Rischi bloccanti per il rilascio restano soggetti ai rispettivi gate.

## Decisione operativa corrente

Checkpoint 2026-10-18: #353-#359 integrate; #359 chiusa A / SOURCE INTEGRATION ONLY con deroga PO specifica allo smoke IIS 0/8 NON ESEGUITO. Runtime revisionato invariato; nessuna certificazione account/sicurezza complessiva o pubblicazione. Nessun task runtime successivo autorizzato; hardening DB pianificato NON AVVIATO, rotazione credenziali esposte anticipabile solo con autorizzazione separata. Nessun accesso HTTP/IIS o DB reale implicito.

## Aggiornamento della roadmap

ID KS-* stabili; non riutilizzarli per requisiti diversi. A ogni decisione modificare CURRENT/TARGET, stato, priorita, dipendenze, AC e riferimento alle prove; preservare in Masterplan la decisione precedente. Un batch completato aggiorna l'evidenza, non promuove automaticamente l'intero macro-perimetro a COMPLETO. Il presente commit non introduce feature, schema o autorizzazioni di rilascio.
