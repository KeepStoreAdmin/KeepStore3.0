# KeepStore Masterplan Operativo

Aggiornato: 2026-10-21

Questo documento conserva task, evidenze e storico del repository KeepStoreAdmin/KeepStore3.0. Per ripartire: [START_HERE](KEEPSTORE_START_HERE.md); per requisiti/priorita vigenti: [PRODUCT_ROADMAP](KEEPSTORE_PRODUCT_ROADMAP.md); per regole permanenti: [AGENTS](../AGENTS.md).
Non contiene credenziali, token, password, API signature, dati carta o account PayPal reali.

## Checkpoint operativo corrente

### TENANT-RELEASE-PACKAGE-1A — offline release readiness, 2026-10-21

Mandato PO corrente: ripresa di KS-G01 **solo offline**, strumenti di pianificazione, confronto Git, fixture sintetiche, documentazione, un commit/push del task branch e PR DRAFT. **CONSEGNA SERVER SOSPESA PER DECISIONE PO**. Nessun target, collector server, pacchetto operativo, configurazione privata, DB, IIS, migrazione, merge o deploy. Base/stable `c8373b08eff0cf9557798802ea4a2d6bfb8e4822`, branch `task/tenant-release-package-1a`; main/origin-main protetti `976e99f17cabc8a5c6a8715463444edfeaadcd91`. DEEP / GPT-6.1 Sol / High richiesti, modello e reasoning effettivi non esposti e non attestabili.

**Closeout prevalente #366:** CHIUSA A / SOURCE INTEGRATED, GitHub merged/closed e Windows allineata allo stable sopra, tre commit lineari, nessun merge commit. Review A [5597700538](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/366#pullrequestreview-5597700538), autorizzazione [6312814490](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/366#issuecomment-6312814490), closeout [6313288175](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/366#issuecomment-6313288175). Le sezioni REV2/REV1 sottostanti conservano gli stati alla consegna, non riaprono review o test. Deroga source-only #366 non ereditata: CI NON CONFIGURATA e MySQL/login reali/IIS/produzione NON ESEGUITI. KS-F01 deterministico integrato; macro-assistente PARZIALE/TARGET.

Manifest autorizzato ed effettivo **7 percorsi**: ADDED `Tools/New-KeepStoreTenantReleasePlan.ps1`, `Tools/Test-KeepStoreTenantReleasePlan.ps1`, `docs/KEEPSTORE_TENANT_RELEASE_RUNBOOK.md`; MODIFIED START_HERE, PRODUCT_ROADMAP, questo Masterplan e SYSTEM_BLUEPRINT. Nessun runtime applicativo o altro Tool modificato. Le tre aggiunte erano assenti; nessun equivalente canonico trovato nei percorsi Tools/docs pertinenti.

Recupero mirato **solo in lettura**: `C:\Temp\KeepStoreReleaseDelivery\20261020-76d97a2c-cb2febd7`, sei file, release storica `76d97a2c...`, allowlist fissa di 84 percorsi (83 per etichetta tenant), 12 coppie espanse e 15 asset secondo il rapporto conservato; nessuna prova del commit installato. Riusati deny-first dei percorsi, hash binari, rifiuto reparse, distinzione differente/assente/identico e gruppi/backup. Collector non eseguito o importato; etichette tenant, remapping logo, inventario statico e istruzioni di raccolta restano storico non autorizzato ora. Hash di integrita rilevati:

| File storico | SHA-256 |
| --- | --- |
| Collect-KeepStoreTenantFiles.ps1 | 31E0B911459217140FC04783C22122FADC59A08B22908AF403AA2FAA7A9B6BB1 |
| collector-selfcheck.json | 2EB6FF1A5EF83E17CB0AC5CEC2E712E54E7D5FEB01FC77DFDE04761D2B77E074 |
| LEGGIMI_CONSEGNA.md | F4EBC9283E14539C3F4FEFB20D8B87A0A5C936AFA382187F598C5DB9A2FFC4BD |
| preparation-report.json | C65A5454ED73DE7868D4790AE0579605059E78168E94703CD652DA29CCCD75D8 |
| release-manifest.csv | B14F668C943220343DE60721B1CD52905955D7177850449D1EB5DF99BD8D2A20 |
| release-manifest.json | 7A176E1777D4E51650A9EBFDB64727E12425B179807FFF05BA8CC44958F458B6 |

Generatore **PLAN ONLY**, PowerShell 5.1/.NET e Git gia presenti, nessuna dipendenza aggiunta. Schema `KeepStore.TenantReleasePlan.v1`, solo `plan.json`/`plan.md` deterministici in TEMP nuova, nessun payload; SHA espliciti e ancestry, raw/NUL Git per spazi/Unicode, blob verificati senza conversioni della working copy. ADDED/MODIFIED/DELETED/RENAMED e tipo cambiato bloccato, origine/destinazione e hash per runtime ammesso; symlink/submodule, collisioni Windows, traversal/tipi ignoti bloccati. Le rinomine sono esatte (100% blob), gli spostamenti modificati restano DELETE+ADD da verificare; configurazioni escluse non lette per similarita. Dipendenze letterali WebForms, coppie, asset statici/CSS e ThemeManager controllate nei blob; classi, codice dinamico, tema attivo, App_Code/Bin e dipendenze transitive restano gate espliciti, nessuna chiusura testuale completa dichiarata.

Il confronto **storico non operativo** `de85cdd4ba8dfe80ec3a9dcf12390480bd1afc42 -> c8373b08eff0cf9557798802ea4a2d6bfb8e4822` conserva **23 Git / 13 runtime / 10 Tools-manuali**, inclusi i due nuovi runtime helper suggest e modulo guida. FROM non attesta installazione. Ogni applicazione ha record indipendente con commit installato/physical path UNKNOWN, autorizzazione assente, compilation/smoke/DB/backup/rollback da verificare, readiness BLOCKED. Nuovi account, segreti e dati cliente non entrano nei report. [Runbook operativo](KEEPSTORE_TENANT_RELEASE_RUNBOOK.md) per lettura piano, inventario futuro, gruppi, backup/rollback file distinto dal DB e stop.

**A tecnico offline, 59/59 controlli PASS**, Windows PowerShell **5.1.26100.9711 Desktop**, Process/RemoteSigned, policy persistenti invariate e fixture rimosse in finally. Evidenze in `C:\Users\Taikun\AppData\Local\Temp\KeepStoreTenantRelease1A-db4a15397bd04ce0955ecefe1385295b\tests-verified`: `test-report.json`, piani sintetici e `historical-363-366/plan.json` / `plan.md`. Coperti A/M/D/R, binari/spazi/Unicode, esclusioni senza lettura, nuovo helper/JS/CSS/cache-buster, tipo/missing/oggetto Git assente, collisioni e case-only, traversal, symlink/submodule, rinomina da privato a runtime bloccata, spostamento modificato D+A, SHA/ancestry, output esistente/in repo rifiutato, determinismo e due applicazioni sintetiche con baseline differenti. Storico 23/13/10, **48 dipendenze dirette presenti nel sorgente**, nessuna mancante nei pattern coperti; sei annotazioni di riferimenti markup/JS dinamici, tema/configurazioni e chiusura globale ancora gate. Target sempre BLOCKED, nessun commit installato attestato. Nessuna precompile applicativa o suite #366 ripetuta.

Il primo avvio 5.1 con policy predefinita si e fermato prima del caricamento; usato il metodo gia autorizzato Process/RemoteSigned. Il giro intermedio da 54 controlli ha evidenziato, alla lettura del piano storico, una falsa dipendenza ricavata da una stringa HTML concatenata in JS; parser ristretto al markup e regressione aggiunta. Il giro da 56 ha confermato la correzione; quello finale da 59 aggiunge isolamento Git senza lazy fetch, blocco puntuale delle collisioni e casi di rinomina. Non e un finding del runtime storefront. Prossimo passo unico: review indipendente ChatGPT della PR DRAFT offline, nessun nuovo task avviato.

### PR #366 REV2 MEDIA — SAPR-F01, 2026-10-21

**A tecnico locale REV2, review differenziale finale pendente sul solo residuo media.** Bozza, focus e repertorio ONSUS della REV1 sono **CHIUSI A** nella [review 5597223920](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/366#pullrequestreview-5597223920), commit `8d32782abfdba3cc672c54ac104c59a33fd6ff33`. Non riaperti, nessuna nuova ricerca ONSUS. Il residuo SAPR-F01 risaliva alla review 5593391408 e non era una regressione REV1.

Stesso branch `task/shopping-assistant-progressive-results-1a`, stessa PR #366 DRAFT: un commit REV2 figlio diretto di `8d32782abfdba3cc672c54ac104c59a33fd6ff33`, push normale. Base/stable `f39958753a017ee3a7dee6141339e93918010399`, main/origin-main `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariati. Profilo EXCEPTIONAL, Astra/xhigh richiesti; modello/livello effettivi non esposti e non attestabili. SHA finale dal Git e rapporto locale, senza alterare il parent approvato.

Manifest incrementale effettivo: **6 MODIFIED**, nessun file aggiunto/rimosso; cumulativo **16 percorsi invariato**, tre commit lineari:

| Percorso | Modifica REV2 |
| --- | --- |
| Default.aspx | Solo cache-buster del modulo guida |
| Public/assets/keepstore/js/ks-shopping-guide.js | Solo funzione imageURL, raccordo canonico e validazione media |
| Tools/ShoppingAssistantProgressiveResults.test.js | Modalita selezionabile media, immagine sintetica e asserzioni prima/dopo |
| docs/KEEPSTORE_START_HERE.md | Stato del residuo e prove riusate |
| docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md | Questo checkpoint ed evidenze |
| docs/KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md | Contratto media root/virtual directory |

Esaminati in sola lettura i tre metodi ThemeManager e il controllo file app-relative. Il solo prefisso root-relative canonico `/Public/assets/images/articoli/` viene ricondotto alla base corrente; `/shop/` richiede `/shop/Public/assets/images/articoli/`, mai la root del dominio. URL gia qualificati non sono duplicati. Unico raccordo per immagine e fallback; nomi codificati e thumbnail preservati, controlli su origine/percorso/estensione e rifiuto delle normalizzazioni elusive prima del parser. ThemeManager, backend/resolver, CSS, configurazioni e dipendenze immutati; modulo identico alla REV1 fuori da imageURL, regressioni bozza/focus versionate identiche. Contratto canonico nel [Blueprint Search](KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md#guida-progressiva--contratto-candidato-2026-10-21).

Evidenze separate in `C:\Users\Taikun\AppData\Local\Temp\KeepStoreShoppingProgressive1A\20261021-rev2-media`:

- `baseline/browser-report.json` e `baseline/media-suite.log`: runtime REV1 immutato, SAPR-F01 riprodotto in Chrome: stessa immagine/thumbnail sintetica caricata a root (`naturalWidth=2`), scartata con base `/shop/` (`naturalWidth=0`, nessun GET). **FAIL atteso**, 164 asserzioni negative sui casi media/mapping/rifiuto; non sono 164 vulnerabilita o incidenti operativi.
- `after/browser-report.json` e `after/media-suite.log`: **373/373 PASS** sul modulo candidato reale, funzioni tramite validate e Chrome **155.0.8059.80**. **48 casi browser** a 390/1365, root e `/shop/`: canonico, gia app-scoped/assoluto/relativo, thumbnail, fallback piena dopo 404, entrambe assenti, spazi/Unicode/punteggiatura codificati. Immagine PNG di due pixel generata in memoria; verificati decodifica (`naturalWidth>0`) e URL/GET effettivi, nessuna richiesta errata alla root o altra applicazione. Trenta gruppi browser di input vietati verificano assenza di img e richieste, oltre ai casi diretti su entrambi i campi.
- Modalita riproducibile del runner Node esistente: stessi cinque percorsi espliciti di repo, Playwright, Chrome, evidenze e payload server, piu `--rev2-media-only`. Nessun nuovo runner/installazione/servizio; rete tutta intercettata, zero upstream/asset operativo/DB. Un controllo bozza e focus nel flusso con immagini PASS; nessuna ripetizione di tutti i percorsi dell'assistente.
- **RIUSATI, non rieseguiti:** 616 server e precompile .NET Framework4.8 354 input, hash sorgenti/harness/wrapper e prerequisiti invariati; Default.aspx differisce solo nel cache-buster. Le **655** prove REV1 restano evidenza dei comportamenti non influenzati, non copertura del precedente caso media mancante. Storico 439/453/655 e repertorio ONSUS preservati, nessun nuovo rendering ONSUS o collaudo server.
- Primo tentativo fixture in `before/` interrotto per attesa di scroll sul nodo img rimosso al 404; casi poi isolati con URL distinti per evitare riuso della cache immagine. Il tentativo non e prova del fix: baseline valida e run finale sono nelle directory indicate sopra. Journal/finally verificati per tutti e tre i run: **9 contesti e 3 browser chiusi**; soli rapporti autorizzati conservati.

Sintassi JS, guard incrementale e diff-check PASS; staging finale vuoto, web.config ignorato con hash/ACL/attributi/date, quattro cancellazioni tracked e 55 untracked/asset preservati. CI **NON CONFIGURATA**, nessuna deroga ereditata o automatismo deploy autorizzato. DB/login reali/IIS/produzione **NON ESEGUITI**; nessuna modifica a configurazioni, merge o deploy. **Consegna server SOSPESA.** Prossimo passo unico: review differenziale finale di SAPR-F01 sul commit REV2; nessun task parallelo o successivo avviato. Le sezioni seguenti conservano gli stati storici; prevale questo checkpoint.

### PR #366 REV1 — bozza, focus e riferimenti, 2026-10-21

Mandato PO circoscritto su `task/shopping-assistant-progressive-results-1a`: un nuovo commit figlio di `ed359cd68bee07b73c762ab8f4f267701073fa44`, push normale e aggiornamento della stessa [PR #366 DRAFT](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/366). Base/stable `f39958753a017ee3a7dee6141339e93918010399`, main `976e99f17cabc8a5c6a8715463444edfeaadcd91`, verificati e invariati. Profilo EXCEPTIONAL, Astra/xhigh richiesti; modello/livello effettivi non esposti e non attestabili. Nessuna deroga CI ereditata, merge o consegna server.

**A tecnico locale REV1; review indipendente ancora pendente.** Il giudizio B sul candidato iniziale riguardava due P2 UX: chip che cancellavano la bozza e pulsanti dinamici che perdevano il focus. Riprodotti prima della modifica al runtime; corretti con guardia condivisa per prodotto/dettaglio/reparto e destinazioni di focus stabili durante l'azione. Anche la stessa frase ridistribuita fra due campi deve essere confermata. Nessuna richiesta, modifica filtri o history quando il controllo blocca l'azione; reset/undo e rimozione intenzionale della ricerca confermata conservati. Confronto, disponibilita, Salta, recupero dal vuoto, retry e nuova ricerca mantengono la continuita da tastiera senza spostamenti al ritorno asincrono. Contratto nel [Blueprint Search](KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md#guida-progressiva--contratto-candidato-2026-10-21).

Manifest REV1 effettivo, **sette MODIFIED**, nessuna aggiunta/cancellazione di file:

| Percorso | Modifica |
| --- | --- |
| Default.aspx | Solo cache-buster di ks-shopping-guide.js |
| Public/assets/keepstore/js/ks-shopping-guide.js | Guardia bozza comune e focus sincrono delle azioni dinamiche |
| Tools/ShoppingAssistantProgressiveResults.test.js | Regressioni prima/dopo e provenienza del rapporto con hash dei sorgenti |
| docs/KEEPSTORE_NAVIGATION_UX_BENCHMARK.md | Repertorio canonico Onsus/ecommerce, fonti e limiti |
| docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md | Questo checkpoint e provenienza delle prove |
| docs/KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md | Contratto bozza/focus e rimando al repertorio |
| docs/KEEPSTORE_START_HERE.md | Stato corrente e unico prossimo gate |

PR cumulativa: **16 percorsi, 13 MODIFIED e 3 ADDED**, due commit lineari dalla base. Backend commerciale/resolver, CSS, dipendenze, configurazioni e wrapper PowerShell invariati in REV1. Configurazione ignorata, quattro cancellazioni tracked e 55 untracked preesistenti preservati; staging finale vuoto. SHA del commit finale e metadati verificati nel rapporto locale/Git reale.

**Prove e provenienza.** Directory separata `C:\Users\Taikun\AppData\Local\Temp\KeepStoreShoppingProgressive1A\20261021-rev1`:

- `before/browser-report.json` e `before/client-suite.log`: regressioni aggiunte eseguite sul runtime ancora identico a `ed359cd6`, **FAIL atteso**, 76 asserzioni negative sui due difetti e percorsi correlati, non 76 finding distinti. Riproduzione solo regressioni tramite argomento `--rev1-regressions-only`; nessuna aspettativa indebolita per il candidato corretto.
- `after/browser-report.json` e `after/client-suite.log`: stessa logica di regressione e suite client completa, **655/655 PASS**, Chrome reale, Tech/Food, viewport 360/390/430/768/1365, root e `/shop/`, Enter/Space e nessun submit WebForms. Bozze separate/combinate, conferma esplicita, undo/history8/reset/chip, focus immediato e utente spostato altrove prima della risposta, race/errori/confronto/fallback. Rete tutta intercettata, zero upstream operativo. Hash dei tre sorgenti client e payload riusato nel rapporto; timestamp distinti, browser e tutti i contesti chiusi.
- **RIUSATI, non rieseguiti:** `20261021/server-tests.log` **616/616 PASS**, relativi quattro payload commerciali sintetici, e `20261021/precompile.log` **PASS Framework4.8, 354 input**. Hash delle sorgenti server/harness/wrapper corrispondenti al rapporto precedente; App_Code, Bin, code-behind, template e runner precompile invariati; differenza Default.aspx limitata al cache-buster. JS reale ricollaudato nella suite client.
- **Storico immutato:** `20261021/suite.log` **439** e un'esecuzione intermedia del wrapper; il successivo `20261021/browser-report.json` **453** e la verifica finale del candidato iniziale. Nessuno dei due e il rapporto REV1 da 655. Le directory e i log precedenti non sono stati sovrascritti.

ZIP Onsus presente nel mirror autorizzato, SHA-256 coincidente, tre HTML letti in memoria senza estrazione/copia. Riferimenti ufficiali, sei retailer e trend Mollie sono raccolti una sola volta nel [repertorio aggiornato](KEEPSTORE_NAVIGATION_UX_BENCHMARK.md#repertorio-aggiornato-2026-10-21--pr-366-rev1), con separazione fra disponibilita, ispezione sorgente, consultazione pubblica e rendering. Nessun nuovo rendering Onsus o collaudo interattivo retailer; la precedente ricerca nei percorsi locali rimane storico.

CI **NON CONFIGURATA**, nessuna deroga automatica; MySQL, login reali, IIS e produzione **NON ESEGUITI**. Nessun DB, configurazione, servizio AI, server, merge o deploy; **consegna server SOSPESA**, nessun file da copiare. Unico prossimo passo: review indipendente del commit REV1 nella PR esistente. Nessun task successivo avviato. Il checkpoint iniziale sotto resta storico delle prove e del manifest precedenti; questa sezione prevale per lo stato corrente.

### SHOPPING-ASSISTANT-PROGRESSIVE-RESULTS-1A — candidato source, 2026-10-21

Mandato PO ONE-SHOT + FEATURE-BATCH + LOCAL-FIRST, **implementazione, test sintetici, un commit, push e PR DRAFT autorizzati**. Profilo EXCEPTIONAL, Astra/xhigh richiesti dal PO; l'ambiente non espone modello/livello effettivi, quindi nessuna selezione inventata. Base esatta `f39958753a017ee3a7dee6141339e93918010399`, branch `task/shopping-assistant-progressive-results-1a`; main/origin-main `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariati. #365 **CHIUSA A / SOURCE INTEGRATED**: review A [5592875346](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/365#pullrequestreview-5592875346), autorizzazione [6303795610](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/365#issuecomment-6303795610), closeout [6303869293](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/365#issuecomment-6303869293). Le sezioni #365/#364 seguenti conservano le evidenze storiche dei candidati; prevale questa chiusura per il loro stato Git.

**A tecnico locale, candidato da review indipendente; KS-F01 PARZIALE.** A-F implementate: brief progressivo con chip espliciti e otto snapshot senza prezzi; comandi finiti e chiarimento degli importi ambigui; massimo sei risultati fondati sui dati server; una domanda facoltativa; recupero dal vuoto modificando un solo vincolo previo click; confronto effimero 2-3 prodotti, tabella accessibile con righe coerenti e scorrimento locale. Nessun LLM o servizio esterno. La grammatica, lo stato e il JSON v1 sono canonici nel [Blueprint Search](KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md#guida-progressiva--contratto-candidato-2026-10-21), non duplicati come altra roadmap.

#### Manifest effettivo esclusivo

| Stato | Percorso | Scopo |
| --- | --- | --- |
| MODIFIED | Default.aspx | Sezione guida, binding esistenti, URL applicativi e script page-scoped |
| MODIFIED | Page.master | Solo cache-buster CSS |
| MODIFIED | Public/assets/keepstore/js/home-default.js | Solo sostituzione controller guida con bridge |
| MODIFIED | Public/assets/keepstore/css/theme-overrides.css | Stili circoscritti, righe card, confronto e reduced-motion |
| MODIFIED | search_suggest.aspx.vb | Raccordo guided e singolo metadata v1 senza query |
| MODIFIED | Tools/SearchSuggestCommercialContextHarness.vb | Estensione casi guided e payload sintetici dai sorgenti reali |
| MODIFIED | Tools/Test-SearchSuggestCommercialContext.ps1 | Output opzionale delle sole fixture pubbliche per il browser |
| MODIFIED | docs/KEEPSTORE_START_HERE.md | Checkpoint e prossimo gate |
| MODIFIED | docs/KEEPSTORE_PRODUCT_ROADMAP.md | KS-F01 e decisione corrente |
| MODIFIED | docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md | Manifest, Design Gate, prove e limiti |
| MODIFIED | docs/KEEPSTORE_SYSTEM_BLUEPRINT.md | Contratti/dependenze architetturali |
| MODIFIED | docs/KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md | Protocollo, stato, grammatica, privacy e CURRENT/TARGET |
| ADDED | Public/assets/keepstore/js/ks-shopping-guide.js | Modulo unico, nessuna dipendenza nuova |
| ADDED | Tools/Test-ShoppingAssistantProgressiveResults.ps1 | Runner nativo PS5.1, runtime esistente e artefatti TEMP |
| ADDED | Tools/ShoppingAssistantProgressiveResults.test.js | Contratti e browser offline sui sorgenti reali |

Totale **15 = 12 MODIFIED + 3 ADDED**, entro il massimo 16. Nessun REMOVED/RENAMED. **Default.aspx.vb invariato**, quattro binding HOME preservati; fuori scope le quattro cancellazioni tracked preesistenti, configurazione locale, asset/untracked. Nessuna modifica a resolver/SQL builder/catalogo/PDP/auth/cart, Bin, database, IIS, AGENTS o installazioni.

#### Design Gate: reference -> benchmark -> KeepStore -> mobile

ZIP `themeforest-4xrKtJ8L-onsus-electronics-ecommerce-html-template.zip` assente nei percorsi mirati verificati, nessuna scansione del PC. Riutilizzate evidenze #364 e ispezionati i tre originali conservati nel Git: `a97a799^:Public/assets/keepstore/index.html`, `shop-default.html`, `compare.html` (ricerca, card prodotto e tabella confronto). Non attestati rendering originale, versione upstream o licenza del package in questa sessione; nessun dato demo/branding importato.

| Aspetto | Fonte autentica / benchmark pubblico consultato 2026-10-21 | Decisione nel candidato |
| --- | --- | --- |
| Preferenze e contesto | ONSUS ricerca e card; Baymard [applied filters](https://baymard.com/research-articles/how-to-design-applied-filters), contenuto pubblico | Brief visibile, chip solo per scelte applicate, valori predefiniti informativi, rimozione e undo espliciti |
| Recupero dal vuoto | Baymard [no search results](https://baymard.com/ecommerce-design-examples/35-no-search-results-page), sola sintesi pubblica | Una modifica preview alla volta, nessuna promessa o rilassamento automatico; errore distinto |
| Aggiornamenti e mobile | W3C [status messages](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html); tabella ONSUS come pattern | ARIA live breve, focus preservato; card 1/2/3 colonne, righe titolo/categoria/prezzo coerenti, confronto con intestazioni e scorrimento locale |

Niente widget flottante, nuova modale, carosello obbligatorio, finto pensiero o claim di conversione/WCAG completa. Gli archivi compare persistenti restano indipendenti; il confronto usa solo i dati gia validati della risposta corrente.

#### Prove reali eseguite e limiti

- **Server: 616/616 PASS** con Windows PowerShell5.1 Desktop, RemoteSigned solo Process; sorgenti reali compilati .NET Framework, I/O sostituito con DataTable/delegati. Incluse le 490 regressioni #365 e 126 verifiche aggiuntive: prodotto letterale/codice/EAN/misure, nessuna estrazione euristica, filtri/tipi/parametri/limit/catalogUrl, metadata fiscale, errori e vuoto. Tenant 1/listino1 e 2/listino10, autenticati sintetici listini4/13, prezzi coincidenti ma provenienza verificata nei parametri effettivi, payload distinti serializzati dal vero endpoint. Zero connessioni DB e login reali; sessioni fixture non attestano autenticazione operativa.
- **Client/contratto: 453/453 PASS**, funzioni reali Node e Chrome **155.0.8059.80**, Tech/Food ai viewport **360/390/430/768/1365**, quattro scenari commerciali sintetici, root e virtual directory. Flusso richiesta/risultati/comandi/undo/PDP/catalogo, schema reale server, chip e limite80, storia8, confronto3/six-card ceiling, dati assenti/varianti, query ignote/importi ambigui, tastiera/IME/focus, righe card/tabella e overflow/touch. Rete interamente intercettata, service worker bloccati; nessun upstream, account o sito operativo.
- Race A lenta/B veloce con abort deliberatamente ignorato, reset pendente, doppio invio, cambio reparto, timeout8s accelerato solo nella fixture, offline, HTTP400/403/421/429/503, HTML/JSON invalido/payload parziale/sovradimensionato, id/TCId/URL incoerenti, XSS testuale e immagini esterne/mancanti. BFCache e possibile cambio scheda rimuovono offerte/confronto, senza refresh automatico. Spy storage/cookie/console/beacon/form e allowlist rete PASS. Fixture di fallback no-JS, modulo assente e prerequisito init mancante PASS.
- **11 screenshot** rappresentativi (Tech/Food, mobile/desktop, confronto, loading, empty, errore); ispezione visiva eseguita su 390/1365 e stati failure. Non certificano HOME IIS completa, screen reader, dispositivi fisici, latenza produzione o contenuti reali. Prima prova interrotta da uso improprio di isDisabled sul fieldset, seconda prova limite4 da check che pretendeva erroneamente il quarto elemento selezionato: corrette le fixture. La verifica visiva ha portato all'allineamento righe e alla tabella confronto, ricollaudati sui sorgenti finali.
- **Precompile safe .NET Framework4.8 PASS, 354 input**, template sintetico, zero configurazioni operative copiate, sanitizer/cleanup PASS. CSS/JS aggiunti sono verificati dal browser reale. Nessuna suite RSA/e-mail/checkout ripetuta. Header browser #365 riusato per codice immutato; wrapper header/filtri rieseguiti nelle regressioni server, controller Swiper/menu/recenti verificato identico fuori bridge.
- Guard incrementale, manifest, diff-check e preservazione registrati nel rapporto finale; il guard considera solo i 15 candidati, non la cronologia. Nessun finding critico noto nel perimetro. MySQL/SQL operativo, IIS, login reali, smoke produzione e configurazioni rimangono **NON ESEGUITI / gate pre-deploy**, non PASS client.

Riproduzione: `Tools/Test-ShoppingAssistantProgressiveResults.ps1` richiede i percorsi espliciti di modulo Playwright gia disponibile, Chrome e directory TEMP dedicata; nessun npm/installazione. Include il runner commerciale e il browser; per la sola verifica UI su payload server gia validati si puo eseguire direttamente il file Node. `Tools/Test-KeepStorePrecompileSafe.ps1` separato. Risorse proprie in journal/finally: **36 contesti chiusi, browser chiuso**, directory temporanee compilatore/harness eliminate; conservati soltanto evidenze autorizzate. Nessun server statico o servizio avviato.

#### Misure locali

Byte UTF-8 normalizzati LF: `home-default.js` **12.612 -> 7.471**; CSS **89.663 -> 94.243**; nuovo modulo **30.977**. Saldo JS/CSS **+30.416 byte** non compressi, una risorsa JS page-scoped, nessuna libreria aggiunta. Nessun fetch guida iniziale/focus/digitazione; un GET per azione confermata, zero chiamate per card o spiegazione, niente prefetch/cache prezzo. Corpo/numero/stringhe limitati; massimo sei card e tre colonne confronto.

Dieci campioni fixture da avvio fetch intercettato a mutazione DOM completata: **11,4-30,6 ms**, media **18,89 ms**, mediana **18,75 ms**; tre card e **102 elementi** nell'intera sezione guida per campione. Misura locale con trasporto sintetico e osservatore di test, non CPU-only, MySQL, TTFB o INP. Ordine e prezzi non sono calcolati dal browser. Risultati non estrapolati a produzione.

#### Futuro rilascio cumulativo — consegna SOSPESA

**Nessun file da copiare ora**, nessun rilevatore/pacchetto/server/deploy. Il mandato PO prevale sull'handoff ordinario AGENTS. Delta runtime di questo candidato dalla base #365: **cinque MODIFIED** (`Default.aspx`, `Page.master`, `search_suggest.aspx.vb`, `Public/assets/keepstore/js/home-default.js`, `Public/assets/keepstore/css/theme-overrides.css`) e **un ADDED** (`Public/assets/keepstore/js/ks-shopping-guide.js`). Tools e manuali non vanno nel webroot.

Per un futuro cumulativo **da stable #363 `de85cdd4`**, unione esatta dei delta #364 + #365 + questo batch: `Default.aspx`; `Page.master`; `Public/ui/controls/SiteHeader.ascx`; `Public/assets/keepstore/css/theme-overrides.css`; `Public/assets/keepstore/js/home-default.js`; `Public/assets/keepstore/js/ks-page-flags.js`; **nuovo** `Public/assets/keepstore/js/ks-shopping-guide.js`; `search_suggest.aspx`; `search_suggest.aspx.vb`; `articoli.aspx.vb`; `App_Code/StorefrontPromotionCatalogProvider.vb`; `App_Code/StorefrontEffectivePriceSqlBuilder.vb`; **nuovo rispetto a #363** `App_Code/SearchSuggestCommercialSupport.vb`. Tredici percorsi runtime, di cui il builder fiscale era gia presente nella base. Questo elenco presuppone quella base effettivamente installata: una base differente richiede il suo delta verificato, non un upload parziale presunto.

Prerequisiti: baseline App_Code/Bin coerente, `Page.master.vb` e `Default.aspx.vb` gia allineati; helper `HomeServerStageTiming.vb`, `StorefrontSeoTenantContext.vb`, `StorefrontPriceDisplayContext.vb`, `StorefrontPriceDisplayContextProvider.vb`, `StorefrontCommercialIsolationPolicy.vb`, `ProductPromotionEligibilityResolver.vb`, `AvailabilityDisplayHelper.vb` e resolver fiscali esistenti. Contratto EntropicConnectionString/MySQL nativo gia configurato, nessuna modifica/copia della configurazione operativa da questo batch, nessun Bin aggiunto. Ordine pagina: modulo guida prima di home-default, cache-buster pertinente JS/CSS; mantenerli coerenti con code-behind guided. Nessun pannello gestionale necessario.

Prima di un futuro rollout autorizzato: review indipendente, decisione CI, target/base/delta attestati, prove MySQL/IIS/tenant autenticate sicure e manifest operativo proprio. Backup dei file effettivamente installati con hash/ACL/attributi/date; rollback dell'intero insieme coerente e rimozione dei soli file nuovi prima assenti. Nessun riavvio IIS globale o modifica DB impliciti. Lo stesso insieme coerente evita di combinare markup nuovo con endpoint vecchio.

Evidenze locali: `C:\Users\Taikun\AppData\Local\Temp\KeepStoreShoppingProgressive1A\20261021` — `candidate-manifest.json`, `server-tests.log`, `server-payloads.json`, `browser-report.json`, PNG, `precompile.log`, `resource-journal.json`, guard e rapporto finale. Sorgenti finali nella copia canonica; SHA e URL PR nel rapporto/Git reale. Workflow GitHub **0**, webhook **0**, nessun hook locale attivo: **CI NON CONFIGURATA**, nessuna deroga #365 ereditata. Prossimo passo unico: **review indipendente ChatGPT della PR DRAFT**; nessun merge, deploy o task successivo avviato.

### SEARCH-SUGGEST-COMMERCIAL-CONTEXT-1A — candidato source, 2026-10-21

Mandato PO CRITICAL / riferimento GPT-6.1 Sol xhigh, ONE-SHOT LOCAL-FIRST. Base `0363e53e661ed00f297052ebe7cff45d630207a2`, branch `task/search-suggest-commercial-context-1a`, main invariato `976e99f17cabc8a5c6a8715463444edfeaadcd91`. #364 **CHIUSA A / SOURCE INTEGRATED**, review 5592073500, autorizzazione 6302358787 e closeout [6302450880](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/364#issuecomment-6302450880) acquisiti. La sua deroga CI/IIS non e estesa a questo candidato. Guida #364 immutata, KS-F01 PARZIALE; consegna server SOSPESA PER DECISIONE PO.

**REV1 consolidata, stessa PR #365 DRAFT:** review indipendente B [5592701492](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/365#pullrequestreview-5592701492) sul candidato `c624db0343b4f38b42ba49651c2c503d46a8e837`. Mandato PO corrente: correggere SSC-F01/F02/F03/F04 nello stesso batch, un commit figlio diretto, senza amend/nuovo branch/nuova PR o merge. Manifest incrementale massimo nove percorsi, tutti gia nel cumulativo di quindici. La review B resta acquisita; l'esito della REV1 richiede review differenziale ChatGPT, senza ripetere audit generali o prove estranee.

**Contratto implementato:** `search_suggest.aspx` autonomo con Session ReadOnly, senza master/lifecycle; unicamente `EntropicConnectionString` e provider MySql.Data.MySqlClient, server/database espliciti, nessuna scansione delle configurazioni o ripiego di provider. `SearchSuggestCommercialSupport` orchestra resolver host-scoped, scalari tenant id/listino/mode, PriceDisplayContext per-request e riscontro vlogin read-only per login/azienda/owner/listino/stato abilitato/fiscale. SSC-F01: il confronto fiscale usa lo stato effettivo di `PageMaster.ApplyAuthenticatedPriceDisplayState`: ID esenzione e aliquota normalizzati come coppia, override soltanto con ID valido; override invalido significa ID=-1/override assente. Modalita IVA e reverse charge conservano i helper esistenti. Marker parziali, account cambiato/disabilitato o contesto non inizializzato sono rifiutati senza downgrade, idratazione, revoca, audit login o mutazioni Session/carrello. Nessun dato commerciale autorevole preso dal client. Nessuna cifratura/configurazione operativa modificata; contratto segreti #363 preservato.

**Proiezione unica:** estratto meccanicamente il solo frammento privato prezzo qty=1 dal catalogo nel builder condiviso. I vecchi join pubblici del catalogo e le due modalita fiscali producono SQL equivalente al baseline; firme preesistenti conservate. Il suggest usa prezzo unitario fiscale/promozionale comune `ROUND(CAST(... AS DECIMAL(38,16)),2)` per selezione/range/sort prima del LIMIT finale, senza pool legacy 80. SSC-F02: la sorgente comune esige `Export<>0` oltre ad articolo abilitato, listino e variante validi, prima di verifica candidati, conteggi, ordinamento e LIMIT; la stessa sorgente copre ricerca, modalita supportate e recenti. Appartenenza a una promo autorizzata (anche futura soglia) separata dal prezzo qty=1 e dal badge unitario; replica SQL della membership riusata con scope riga-listino. Una sola data di valutazione e parametri Decimal/Int32/Date. Parametro `pid` coerente col catalogo: campagna promozionale, non prodotto. SSC-F03: raccordo dall'URL effettivo `selectedUrlParams/buildSuggestUrl` dell'header a ReadFilters, SQL/parametri e catalogUrl: canonici `disponibile`, `pmin`, `pmax`, `ordinamento`; alias supportati preservati, valori equivalenti ammessi e conflitti rifiutati con HTTP400, senza scelta arbitraria o modifiche UI.

SSC-F04: dopo tutti i join, immagini incluse, una proiezione esplicita `DISTINCT` dei soli fatti necessari elimina duplicazioni equivalenti prima dei conteggi finestra di molteplicita per id+TCId+listino, ExactMatches e LIMIT. Campi promo legacy non autorevoli esclusi dalla proiezione, nessun FIRST/MIN/MAX per risolvere conflitti. Prodotti, varianti e listini distinti restano distinti; divergenze dei fatti richiesti, incluse prezzo/IVA/stock, falliscono chiuso. Prima dei filtri commerciali un aggregato intercettabile rifiuta prezzi/stock non verificabili o molteplicita conflittuale fra i candidati testuali/tassonomici. Le righe finali sono verificate con EffectivePriceResolver, un solo ProductPromotionEligibilityBatch e AvailabilityDisplayHelper, senza repricing o filtro tardivo che inventi un vuoto. Identita id+TCId esplicita in selezione, JSON, URL e strong redirect; variante invalida non ricade sul base e corrispondenze esatte multiple non selezionano una variante arbitraria. Nessun claim spedizione gratuita dalla colonna legacy; badge non verificato omesso. Quick links derivano dai risultati correnti; eliminati i fallback elettronici hardcoded. Errori distinti dai vuoti con ok=false/codice sanitizzato/HTTP 4xx o 503, no-store e fallback navigazione al catalogo, senza SQL/eccezioni raw nel JSON. Il client valida TCId contro la URL; debounce/generazioni/Enter e layout non riscritti.

**Manifest effettivo 15 percorsi:** MODIFIED `search_suggest.aspx`, `search_suggest.aspx.vb`, `App_Code/StorefrontPromotionCatalogProvider.vb`, `App_Code/StorefrontEffectivePriceSqlBuilder.vb`, `articoli.aspx.vb` (sola delega meccanica), `Public/assets/keepstore/js/ks-page-flags.js`, `Page.master` (solo cache-buster JS), START_HERE, PRODUCT_ROADMAP, questo Masterplan, SYSTEM_BLUEPRINT e AI_ASSISTED_SEARCH_BLUEPRINT. ADDED `App_Code/SearchSuggestCommercialSupport.vb`, `Tools/Test-SearchSuggestCommercialContext.ps1`, `Tools/SearchSuggestCommercialContextHarness.vb`. Nessuna modifica a Page.master.vb, guida HOME, auth/login, DB/schema, DLL o configurazioni. Futuro rilascio: otto runtime coerenti (incluso nuovo helper e builder condivisi); Tools/documenti non sono file da caricare sul sito. Nessun pacchetto creato o destinazione server autorizzata.

**Prove del candidato originario, storiche:** 156 asserzioni della suite dedicata, sorgenti candidati App_Code e pagina compilati realmente .NET Framework, I/O query e lettura snapshot sostituiti con DataTable/delegati sintetici. Risoluzione fiscale, pricing, promo qty=1 e builder sono quelli reali, non algoritmi alternativi del test. Tenant 1/listino1 e 2/listino10 con prezzi coincidenti e provenienza separata; account con altro listino, owner/azienda diversi, disabilitato/mancante, marker parziali e fiscalita cambiata; IVA inclusa/esclusa/zero/frazionaria e reverse charge, soglie maggiori di uno, variante/duplicati, stock NULL/netto, guasto promo, centesimi e filtri/sort, input ostile e listino client ignorato, recenti e tre modalita. Questi risultati non coprivano automaticamente i quattro controesempi della review. Policy owner reale e predicati SQL date/tenant/listino/campagna ispezionati; query intercettate verificano parametri/tipi, alias e LIMIT finale. **SQL NON ESEGUITO su MySQL**: il caso candidato oltre il pool legacy verifica forma/parametri del comando e righe sintetiche, non un piano o risultato MySQL reale. Date/owner filtrati dal loader SQL restano prove strutturali quando non eseguiti su DB.

**Prove REV1:** quattro controesempi riprodotti sul commit immutabile `c624db03` (9 asserzioni di riproduzione); stessi input verificati corretti sui sorgenti finali, suite dedicata estesa **490/490 PASS**. Fixture fiscali costruite eseguendo il corpo invariato della master: ID -1/0/positivo, NULL/valori invalidi, zero/frazioni, cambi effettivi e controlli account conservati. Matrice pubblicabilita Export 0/NULL/pubblicabile, abilitazione/listino, ricerca/recenti/modalita/strong redirect. Funzioni reali header eseguite offline per generare URL poi letti da ReadFilters reale: disponibilita, prezzi frazionari preservati senza arrotondamento all'ingresso, ordinamenti/alias e conflitti HTTP400 prima dell'I/O prodotti. Proiezione/predicati/tipi/ordine SQL collegati a un modello relazionale sintetico che produce righe e conteggi dai fatti: 102 ripetizioni tecniche ammesse prima di LIMIT/ExactMatches, conflitti prezzi/IVA/stock rifiutati, identita prodotto/variante/listino separate. Metadati necessari diversi restano un'ambiguita conservativa della proiezione richiesta. Nessun fake fisso InvalidCount=0 e presentato come prova dei predicati. **Precompile REV1 sintetica ASP.NET4.8 PASS, 354 input, zero copie operative; cleanup PASS.** Guardia pertinente e preservazione nel rapporto finale. **SQL non eseguito su MySQL**; nessuna connessione DB, login reale, IIS o HTTP applicativo live. Nessuna suite RSA/e-mail/guida ripetuta.

Browser Chrome reale offline: riusati i 30 controlli sui payload header, mobile390/desktop1365, con client invariato; successo, TC coerente/incoerente, vuoto, errore403/503 e fallback catalogo, zero page errors. Nessuna ripetizione delle 216 prove guida. Harness attende transizione Bootstrap e focus stabile; nessun fix UI attribuito a quei tempi di prova. Precompile originaria safe sintetica ASP.NET4.8: 354 input, zero copie configurazioni operative; il primo tentativo senza nuovo helper nell'indice ha rilevato la dipendenza mancante, poi inclusa e verificata. Nuova precompile e guard REV1 riportati sopra. Suite con journal e cleanup della propria directory; Process/RemoteSigned soltanto, policy persistenti preservate.

Evidenze REV1 sanitizzate: `C:\Users\Taikun\AppData\Local\Temp\KeepStoreSearchSuggest1A\20261021-rev1` (riproduzione baseline, suite finale, precompile, guard, manifest/rapporto). Evidenze originarie/browser riusate: `C:\Users\Taikun\AppData\Local\Temp\KeepStoreSearchSuggest1A\20261021-context1a`. Ispezione SQL e sessioni di prova non sono SQL eseguito, login reale, IIS o produzione. Nessun account/DB operativo aperto o nuovo servizio/installazione. Letture runtime pianificate: tenant resolver (cache esistente), al piu una vlogin, un batch promo, un aggregato validita e una query risultati; righe verificate in memoria, quick links senza altre query, nessun N+1. Nessuna latenza DB/TTFB misurata.

CI NON CONFIGURATA, zero workflow/webhook/check/status verificati nuovamente per la REV1; nessuna deroga ereditata. PR #365 mantenuta DRAFT, review B originaria e review differenziale ChatGPT della REV1 PENDENTE; nessun merge/deploy. Il finding listino1/connessione per tentativi e corretto nel candidato nel perimetro dimostrato, non sul server. Prossimo passo: review differenziale della REV1 pubblicata, nessun task successivo o collaudo operativo avviato.

Fonti tecniche consultate 2026-10-21: [Microsoft Session State](https://learn.microsoft.com/en-us/previous-versions/aspnet/ms178581%28v%3Dvs.100%29) per ReadOnly; [MySQL rounding](https://dev.mysql.com/doc/refman/8.0/en/precision-math-rounding.html) per distinzione exact/approximate. Non costituiscono prova di esecuzione del candidato.


### SHOPPING-ASSISTANT-GUIDED-ENTRY-1A — fase guidata PARZIALE

Storico della consegna #364: stati DRAFT/review pendente sotto superati dal closeout acquisito sopra; non riaprire la guida.

Mandato PO 2026-10-20, DEEP / GPT-6.1 Sol / High, LOCAL-FIRST: base stable verificata `de85cdd4ba8dfe80ec3a9dcf12390480bd1afc42`, branch `task/shopping-assistant-guided-entry-1a`, main invariato `976e99f17cabc8a5c6a8715463444edfeaadcd91`. #363 **CHIUSA A / SOURCE INTEGRATED**, review [5591336167](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/363#pullrequestreview-5591336167), closeout [6301374126](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/363#issuecomment-6301374126) e sincronizzazione Windows conclusa. Non si riaprono #361/#362/#363. Le deroghe CI precedenti non valgono per il nuovo candidato.

**Risultato cliente implementato / A tecnico locale:** la sezione HOME esistente `KsLocalAiSearch130` presenta **Guida agli acquisti**, denominazione descrittiva provvisoria approvata; entry header mobile/desktop, richiesta libera e dettaglio facoltativo, scelta dei primi cinque reparti reali gia renderizzati, riepilogo e chiarimento neutro, modifica/reset e CTA `Cerca nel catalogo`. Nessuna seconda sezione, widget flottante o nuova modale. La guida prepara una ricerca, senza dichiarare di aver trovato prodotti: il catalogo mostra i risultati reali e rimane fonte commerciale autorevole. KS-F01 e **PARZIALE**, non assistente conversazionale completo.

**Contratto tecnico:** solo `articoli.aspx?q=...` same-origin, con `st` facoltativo ammesso esclusivamente dalla tassonomia DOM, ID intero positivo Int32; richiesta+dettaglio normalizzati entro 80 caratteri, input minimo due caratteri. Testo utente tramite `textContent`; nessuna inferenza di prodotti, compatibilita, prezzo, stock o promo. La preparazione non effettua fetch/HTTP/DB; rimossi dal solo `home-default.js` il vecchio percorso `initLocalAiSearch`, le sue card e `rememberSearch`. La nuova richiesta non viene scritta in Web Storage, cookie, sessione, DB o nuova telemetria. Recents prodotti, Swiper, menu e ricerca header restano nel proprio contratto; nessun resolver o endpoint commerciale modificato. Senza JavaScript rimangono catalogo e link reparti.

**Manifest effettivo 9 MODIFIED, nessun ADDED:** `Default.aspx`, `Public/assets/keepstore/js/home-default.js`, `Public/assets/keepstore/css/theme-overrides.css`, `Public/ui/controls/SiteHeader.ascx`, `Page.master` (solo cache-buster CSS pertinente), START_HERE, PRODUCT_ROADMAP, questo Masterplan e AI_ASSISTED_SEARCH_BLUEPRINT. `Default.aspx.vb` **IMMUTATO**: preservati i quattro binding server della sezione. Nessuna nuova dipendenza frontend, fixture/script nel repository, configurazione, tabella, libreria o endpoint. Per un futuro rilascio servono i cinque runtime coerenti con base e dipendenze realmente installate: questa lista non e un pacchetto cumulativo pronto per produzione. **Consegna server SOSPESA PER DECISIONE PO**, nessun rilevatore, pacchetto o upload.

#### Design Gate proporzionato e scelta inline

Reference ONSUS autentica disponibile in `C:\KeepStoreWeb\_aspnet_precompile_checkout4_20260520184528\Public\assets\keepstore`: `shop-default.html` righe 66-117 (ricerca/categorie) e area offcanvas da 4834; esaminati anche `index`/`home2`/`home3`/`home4` e `_pop-up.scss` area 665 (100vh). La copia locale consente di esaminare i pattern originali disponibili; versione upstream e licenza non sono state attestate da questo task. Nessun dato/asset demo importato e nessun nome ONSUS aggiunto al runtime custom.

| Aspetto | ONSUS originale | Benchmark attuale | KeepStore corrente | Decisione KeepStore |
| --- | --- | --- | --- | --- |
| Ricerca e navigazione | Ricerca e accesso categorie distinti in `shop-default.html` | Baymard [Search Bar UI](https://baymard.com/blog/search-bar-ui), 2026-10-02: ricerca riconoscibile; [query types](https://baymard.com/research-articles/ecommerce-search-query-types), aggiornato 2026-04-29: richieste con precisione diversa | Header search e catalogo gia operativi; sezione HOME gia esistente | Guida inline complementare, ricerca/catalogo sempre accessibili; nessun secondo motore |
| Mobile e percorso | Offcanvas/popup originali occupano lo schermo e hanno comportamenti propri | [W3C target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html): controllo raggiungibile e dimensioni adeguate | Nuova modalita guidata non richiede un overlay | Nessuna nuova modale; target applicabili >=44px, viewport da 360px, focus e fallback no-JS |
| Stato e chiarimento | Componenti template come riferimento visuale, senza logica commerciale | [W3C status messages](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html): feedback annunciabile senza imporre focus a ogni messaggio | WebForms e tassonomia gia renderizzata; suggest legacy non certificato multi-listino | Domanda neutra senza fingere AI, stato live, riepilogo testuale e CTA esplicita al catalogo autorevole |

Le fonti motivano la scelta locale, non una certificazione universale di conversione o conformita WCAG completa. Nome definitivo, LLM, conversazione, RAG, retrieval e prodotti inline restano TARGET separati.

#### Evidenze e limiti del candidato

- Browser reale tramite `mcp__node_repl__js`, Chrome **155.0.8059.80**, fixture offline **Tech/Food** e viewport **360/390/430/768/1365**: **216/216 controlli PASS**, zero page errors e zero richieste suggest dalla guida. Esercitati ingresso header mobile/desktop, query vuota/specifica/generica, caratteri speciali/Unicode, input lungo, markup/URL injection, `st` invalido, chiarimento, Enter/Tab, modifica/reset (compreso testo nascosto), avanti/indietro e no-JS; ricerca/menu esistenti, overflow e target applicabili verificati. Ogni HTTP della fixture intercettato; nessuna richiesta applicativa live, IIS, DB, login, ordine o pagamento.
- Precompile safe **ASP.NET Framework 4.8, 353 input PASS**, configurazione sintetica dal template, **zero configurazioni operative copiate**, cleanup PASS. Prove precedenti riusate solo per codice invariato. Report e quattro screenshot in `C:\Users\Taikun\AppData\Local\Temp\KeepStoreShoppingGuide1A\20261020-guided-entry1a`, `browser-report.json`.
- Una prima asserzione del menu osservava la transizione Bootstrap prima dello stato `.show`; l'harness e stato corretto per attendere lo stato finale. Il generatore fixture e stato aggiornato per leggere i sorgenti finali anziche una closure precedente; matrice finale interamente rieseguita sui byte finali. Nessun fix runtime attribuito al falso negativo della transizione; dettaglio nel report.
- Prestazioni pertinenti: preparazione guida senza chiamata al vecchio endpoint, nessuna query/connessione DB aggiunta. Byte UTF-8 normalizzati LF: `home-default.js` 14.558 -> 12.611 (-1.947), `theme-overrides.css` 86.292 -> 89.662 (+3.370), saldo +1.423 byte. Non sono state misurate TTFB/LCP o latenza applicativa; non si dichiara un miglioramento runtime misurato.
- Queste prove certificano il comportamento del candidato e dei componenti esercitati nelle fixture; non sono smoke IIS, sessioni/tenant reali, dispositivi fisici o produzione. Un commit e PR DRAFT dopo i gate, identita esatta dal Git; review indipendente **PENDENTE**, nessun merge. **CI NON CONFIGURATA**, nessuna deroga ereditata dalla #363. Prossimo passaggio: review indipendente della PR, nessun task successivo automatico.

#### Finding separato — suggest commerciale legacy

**HIGH / SEPARATE MICRO-TASK**: `search_suggest.aspx.vb` righe 140, 196 e 796 filtra `COALESCE(v.NListino,1)=1`, mentre `articoli.aspx.vb` risolve il contesto commerciale corrente (area 648) e ne usa il parametro listino (area 1097). Il rischio e incoerenza dei suggerimenti commerciali rispetto al catalogo per aziende/listini diversi; non si dichiara un incidente o leakage osservato in runtime. Priorita: correggere e certificare separatamente il suggest prima di dichiararne l'uso commerciale multi-listino corretto. Il nuovo percorso guida **non lo chiama** e non ne espone prezzo/stock/card; il finding non blocca questa UI indipendente e non e corretto fuori manifest. Nessuna nuova PR o implementazione successiva aperta automaticamente.

### KEEPSTORE-SECRET-STANDARD-CONTRACT-1A — decisione PO e storico di consegna

**Storico della consegna #363 precedente al closeout; stato corrente CHIUSA A / SOURCE INTEGRATED come sopra.** Gli stati DRAFT/review pendente seguenti sono superati; nessun deploy e nessuna riapertura del task.

Mandato DOCS-ONLY 2026-10-20: direttiva permanente in AGENTS e [contratto tecnico unico](KEEPSTORE_SECRET_PROTECTION_STANDARD.md), con mappa progressiva senza valori. KSAES2 e TARGET APPROVATO / DA IMPLEMENTARE, non componente gia installato: AES-256-CBC + HMAC-SHA256, chiavi separate, salt/IV casuali, key version e contesto autenticato; dettagli binari/KDF/serializzazione da formalizzare prima dell'implementazione. Password login con hashing dedicato. Nessun nuovo script/provider/libreria, configurazione o migrazione.

CURRENT confermato nel sorgente: EmailCredentialStore usa DPAPI LocalMachine, KSEMAIL1 e riferimenti dpapi-v1, scope database/azienda/scopo; EMAIL_CONNECTION_VERIFIED e esito TLS/AUTH/QUIT SMTP. Tools/KeepStoreConfigurationReader accetta il provider protetto RSA: il futuro adattatore comune dovra includere lettore, wrapper e consumer. Il target web.config preserva EntropicConnectionString tramite ProtectedConfigurationProvider, chiave disponibile prima dell'apertura DB. UI Enzo: stato senza rilettura della password, sostituzione esplicita, vuoto senza modifica, revoca distinta e verifica server-side sanitizzata; specifica, non pannello implementato.

**Closeout acquisito #362: CHIUSA A / SOURCE INTEGRATED**, review differenziale [5586703835](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/362#pullrequestreview-5586703835), autorizzazione [6293980035](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/362#issuecomment-6293980035), closeout [6294285103](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/362#issuecomment-6294285103). FF-only su frontend-rebuild: `32bc8714b081f2ecea5b2ad2d13653c21c764512 -> bae99d300740c377b74a17f42c31a97416de92e5 -> 76d97a2c004f7661b61e66d6f744f1fb7e8d1231`. Stable locale/remoto verificato; main invariato `976e99f17cabc8a5c6a8715463444edfeaadcd91`. CI NON CONFIGURATA, deroga specifica registrata per la sola #362, non estesa. Rapporti closeout in `C:\Temp\KeepStoreDbConfigHardening1A\20261020-rev1-c516f63b\closeout-6e93cbcd`. Prove precedenti riusate nei propri limiti, nessun deploy o cifratura operativa da #362.

**TENANT-RELEASE-PACKAGE-1A SOSPESO PER DECISIONE PO**: manifest, rilevatore e guida conservati in `C:\Temp\KeepStoreReleaseDelivery\20261020-76d97a2c-cb2febd7`. Nessun confronto server richiesto ora, nessuna esecuzione o rigenerazione. Decisione esposizioni pregresse sottostante invariata: niente scansioni/bonifiche/avvisi ripetuti e nessun blocco delle funzionalita indipendenti.

Manifest corrente: AGENTS, START_HERE, PRODUCT_ROADMAP, MASTERPLAN, SYSTEM_BLUEPRINT, runbook DB, manuale e-mail Enzo (7 MODIFIED) e standard segreti (1 ADDED). Un commit e PR DRAFT sul branch `task/keepstore-secret-standard-contract-1a`; review indipendente di questa consegna documentale ancora da svolgere, nessun merge. Verifiche solo documentali: manifest, link/Markdown, distinzione CURRENT/TARGET/DEPLOYED, aggiunte senza valori operativi e diff-check; nessuna build/precompile/RSA/browser/DB.

Prossimo feature-batch: KS-F01 `SHOPPING-ASSISTANT-GUIDED-ENTRY-1A`, NON AVVIATO; nome/privacy e due merceologie restano requisiti del mandato. Nessun nuovo audit o task operativo avviato.

### SECURITY-DB-CREDENTIALS-HARDENING-1A — Batch A software

Storico di consegna: gli stati DRAFT/review pendente delle righe seguenti sono superati dal closeout prevalente sopra.

#### REV1 — DBCFG-GUARD-F01, controllo delle aggiunte private nell'indice Git

Mandato mirato 2026-10-20 sulla stessa **PR #362 DRAFT**, successivo alla [review indipendente 5585799761](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/362#pullrequestreview-5585799761) del candidato `bae99d30`: le esclusioni dalla scansione dei contenuti lasciavano passare una configurazione privata nuova nell'indice. Riproduzione dell'entrypoint precedente: file privato staged, exit **0**; con la correzione exit **1**, codice sanitizzato `PRIVATE_PUBLICATION_PATH`. Si corregge questo finding nuovo nel perimetro autorizzato, senza riaprire finding storici o modificarne la decisione PO sottostante.

Il guard ora controlla i soli metadati delle aggiunte dell'indice rispetto a **base e HEAD**, con parsing **NUL/UTF-8**, rinominazioni disattivate e verifica delle destinazioni `A`, prima dei filtri di lettura del contenuto. Il template consentito e distinto dalle configurazioni private; rimozione del tracking `D` e copia privata locale ignorata restano ammesse. Le prove con il file privato locale bloccato dimostrano che questo controllo non ne legge il contenuto; nessun contenuto privato e incluso nei report.

**Prove REV1 tecnico-locali PASS:** **28 selftest del guard**, **20 casi Git sull'entrypoint reale**, **22 casi ArtifactRoot** e controllo incrementale dei **24 file candidati**. I casi Git comprendono aggiunte private staged, staging forzato, percorsi/case rilevanti, destinazioni delle rinominazioni, confronto indipendente da base/HEAD, rimozione dal tracking, file locale ignorato/bloccato e template ammesso. Conteggi/evidenze finali e SHA dal rapporto `C:\Temp\KeepStoreDbConfigHardening1A\20261020-rev1-c516f63b\final-report.md`/`final-report.json`.

Manifest REV1 esclusivo **5 MODIFIED**: `Tools/Test-DatabaseSecretsGuard.ps1`, `docs/KEEPSTORE_START_HERE.md`, `docs/KEEPSTORE_PRODUCT_ROADMAP.md` (solo sezioni pertinenti), `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`, `docs/KEEPSTORE_DB_CREDENTIALS_HARDENING_RUNBOOK.md`. Manifest cumulativo della PR **25 percorsi invariato**. Un commit REV1 figlio diretto di `bae99d30`, stesso task branch e stessa PR DRAFT; nessun amend/rebase o modifica di stable/main. CI **NON CONFIGURATA**. **Fix tecnico-locale verificato; nuova review differenziale ChatGPT pendente**, nessuna approvazione indipendente anticipata.

RSA, strumenti e-mail, parity, precompile, runtime applicativo e #361 sono **immutati**: prove del Batch A sotto riusate nei limiti originali e **non ripetute**. Non sono state create chiavi RSA per la REV1. `web.config`, configurazioni/ACL operative e stato preesistente protetti; nessun DB, IIS, login, SMTP, rollout, rotazione, merge o deploy. Decisione PO sulle esposizioni pregresse e autorizzazione Process/RemoteSigned restano identiche. Le sezioni successive conservano manifest ed evidenze della consegna Batch A precedente alla REV1.

Mandati PO 2026-10-20: implementazione completa, prove locali sintetiche, un commit, push del solo branch e PR DRAFT verso `frontend-rebuild`; ripresa autorizzata con Windows PowerShell 5.1 Desktop e `RemoteSigned` limitato allo scope Process. Copia canonica `C:\KeepStoreWeb\KeepStore3.0`, branch esistente `task/security-db-credentials-hardening-1a` dalla base esatta `32bc8714b081f2ecea5b2ad2d13653c21c764512`; `main` protetto `976e99f17cabc8a5c6a8715463444edfeaadcd91`. #361 REV2 gia integrata source: i checkpoint HOME sottostanti sono storico antecedente alla chiusura; rapporti e verifiche acquisiti riusati nei propri limiti, senza ripetere collaudi o estenderli al nuovo codice.

**Batch A implementato e testato tecnico-localmente PASS; PR DRAFT da revisionare, nessun merge/deploy.** RSA nativa: **43 asserzioni (42 core + una probe aggregata), 13 check dei consumatori reali**; **45 risorse registrate, 3 chiavi di prova, 0 residui**. Provisioning e-mail offline **21/21 PASS**; verifier offline **7/7 + 33/33 PASS**; parity offline **141/141 + 20/20 fixture PASS**; guard **28 selftest PASS** e controllo incrementale dei **24 file candidati PASS**. Integrazione sintetica **12 check PASS**: installazione da template fail-closed, update con configurazione preservata, untracking senza cancellazione locale, guard positivo/negativo degli artefatti e precompile da export senza `web.config` operativo. Precompile completa ASP.NET Framework 4.8 dal template **353 input PASS**, anche nel percorso export. Commit e URL PR dal Git reale e dal rapporto finale sanitizzato `C:\Temp\KeepStoreDbConfigHardening1A\20261020-resume-967934c1\final-report.md`/`final-report.json`, senza inventare riferimenti prima della consegna. Il precedente arresto per Restricted ha lasciato modifiche annullate e branch preservato; la ripresa non crea un nuovo task.

Manifest esclusivo **25 percorsi: 16 MODIFIED, 8 ADDED, 1 REMOVED-FROM-TRACKING**:

| Operazione | Percorsi |
| --- | --- |
| REMOVED-FROM-TRACKING | `web.config`, mantenuto identico nel filesystem; mai voce di cancellazione sul server |
| MODIFIED | `App_Code/SearchSuggest.vb`; `Tools/Set-EmailTransportCredential.ps1`; `Tools/EmailTransportConnectionVerifier.vb`; `Tools/Invoke-PersistentCartRegistryCleanup.ps1`; `Tools/PersistentCartCleanupRunner.vb`; `Tools/Verify-EmailTransportConnection.ps1`; `Tools/StorefrontCommercialBulkResolutionHarness.vb`; `Tools/Test-StorefrontPromotionParity.ps1`; `Tools/Test-KeepStorePrecompileSafe.ps1`; `Tools/Test-EmailTransportConnectionVerifier.ps1`; `Tools/Test-EmailTransportCredentialProvisioning.ps1`; `docs/KEEPSTORE_START_HERE.md`; `docs/KEEPSTORE_PRODUCT_ROADMAP.md`; `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`; `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md`; `docs/PERSISTENT_ANONYMOUS_CART_DEPLOYMENT_RUNBOOK.md` |
| ADDED | `.gitignore`; `web.config.example`; `Tools/KeepStoreConfigurationReader.vb`; `Tools/Import-KeepStoreConfigurationReader.ps1`; `Tools/Set-DatabaseProtectedConfiguration.ps1`; `Tools/Test-DatabaseProtectedConfiguration.ps1`; `Tools/Test-DatabaseSecretsGuard.ps1`; `docs/KEEPSTORE_DB_CREDENTIALS_HARDENING_RUNBOOK.md` |

Contratti: `EntropicConnectionString` resta canonico. SearchSuggest elimina gli alias/posizioni alternativi; gli strumenti condividono `WebConfigurationManager.OpenMappedWebConfiguration` con target e origine verificati, senza resolver runtime globale. Cleanup: il processo riceve percorso configurazione, azienda e batch, legge internamente il file e non riceve segreti da stdin. RSA esplicita su configurazione predisposta; default di sola verifica, Apply soltanto su fixture sintetiche nel batch. Precompile dal template senza configurazione/chiavi operative; guard incrementale sulle nuove aggiunte e sugli artefatti pubblicabili.

Prove PASS sui candidati effettivi nei limiti sopra: selezione per nome e origine; errori fail-closed; round-trip RSA nativo, chiavi/ciphertext errati, recupero e cleanup; Apply esplicito, idempotenza e failure rollback di bytes/ACL/attributi/date; wrapper/runner compilati e consumatori reali; e-mail/parity offline senza DB/SMTP; precompile ASP.NET Framework 4.8 dal template senza configurazione operativa; guard positivo/negativo, installazione/aggiornamento/untracking sintetici. Preservazione finale dello stato locale, manifest e diff check nel rapporto conclusivo. Nessuna suite grafica/#361 ripetuta. Performance: eventuali costi misurati riguardano soltanto caricamento configurazione locale, nessun miglioramento del sito o del DB dichiarato.

Preflight GitHub acquisito per questo batch: autenticazione disponibile, nessun workflow/webhook/check-run/status/ruleset/deployment rilevato. **CI NON CONFIGURATA**, non PASS. Push autorizzato direttamente dal mandato corrente; nessuna deroga #359/#360/#361 riutilizzata. Dopo PASS tecnico: un commit, push esclusivo task branch, PR DRAFT e review indipendente ChatGPT. Stable e main non vengono modificati dal batch; niente merge o deploy.

Manifest Git e futura pubblicazione sono distinti. Il solo runtime applicativo modificato e `App_Code/SearchSuggest.vb`; template e Tools non costituiscono un pacchetto upload. Nessuna destinazione server o lista di file dichiarata pronta per smoke e autorizzata da questo mandato. Installazione, aggiornamento manuale dei soli file approvati da Germano, altre working copy e recupero nel [runbook DB](KEEPSTORE_DB_CREDENTIALS_HARDENING_RUNBOOK.md). Non riaprire un audit dei processi di pubblicazione gia attestati.

Laboratorio DB, account/grant/TLS, identita application pool e ACL operative, migrazione consumer, revoca credenziali e machineKey **NON AVVIATI / esclusi**. Non sono blocker dell'A tecnico-locale del Batch A. Configurazione operativa e relativo hash/ACL/attributi/date, stato preesistente e asset devono risultare preservati dal rapporto finale; nessuna bonifica o invalidazione segreti dichiarata.

#### Decisione PO 2026-10-20 — esposizioni pregresse

"Le esposizioni pregresse di credenziali e dati già censite non costituiscono
un prerequisito di bonifica per completare il batch software autorizzato
o proseguire attività indipendenti. Non ripetere scansioni dello storico,
richieste di cancellazione/rotazione o avvisi sul medesimo finding.
Nessuna cancellazione o modifica retroattiva è richiesta.
Restano attivi i controlli sulle nuove modifiche, sulla non regressione
e sul rispetto del perimetro operativo. Un problema nuovo con impatto
concreto sul lavoro corrente viene valutato nel suo specifico perimetro.
Le operazioni escluse restano separate e non vengono avviate automaticamente."

#### Ripresa PO 2026-10-20 — esecutore Windows PowerShell 5.1

Autorizzata esclusivamente **RemoteSigned nello scope Process dei processi di lavoro dedicati**, prima del caricamento degli script. Metodo ammesso: `powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File <script-autorizzato>` oppure `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned` nella medesima sessione dedicata. Versione, scope iniziali e policy effettiva del processo esecutore vanno registrati; prima della reimplementazione, caricamento di uno script locale sintetico innocuo poi rimosso.

Nessuna modifica permanente a CurrentUser/LocalMachine/MachinePolicy/UserPolicy, profili o registro; Group Policy prevale. Vietati Bypass, Unrestricted, Invoke-Expression, conversione in inline per eludere blocchi e modifiche ad AMSI/AppLocker/WDAC/antivirus. Il test esecutore non e PASS applicativo. In finally: cleanup delle sole risorse sintetiche registrate, attesa/chiusura dei soli figli creati, terminazione processi dedicati o ripristino del precedente valore Process se la sessione resta aperta; verifica degli scope persistenti invariati, senza impostare Restricted permanentemente come presunto rollback.

Prossimo passo unico del Batch A: **review indipendente ChatGPT della PR DRAFT**, dopo la consegna tecnica. Nessun laboratorio/rollout/revoca o altro task parte automaticamente.

### Checkpoint storico HOME-ADAPTIVE-SHOPPING-1A — KS-E01 fase 1, consegna locale prima della chiusura #361

Mandato PO 2026-10-18: implementazione, test mirati, un commit e PR DRAFT; nessun merge, deploy, IIS o DB. Base locale/remota verificata `3b1581d45fa7e782dd189060fa3b2d32050943d6`, branch `task/home-adaptive-shopping-1a`; main protetto `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Identita commit/PR dal Git reale, senza commit ricorsivi. Manifest esclusivo: `Default.aspx`, `Default.aspx.vb`, `Public/assets/keepstore/css/theme-overrides.css`, `Page.master` (solo cache-buster CSS `20261018-home-adaptive-shopping1a`) e i tre manuali START_HERE/PRODUCT_ROADMAP/Masterplan.

**REV2 — HOME brand asset no-egress, 2026-10-19.** Mandato PO successivo: un nuovo commit sul medesimo branch/PR #361, figlio del candidato originario `4b203b8663572a4f2c83114a47570cc0130dbca3`; nessuna installazione, richiesta IIS o integrazione. Delta REV2 esclusivo: `Default.aspx.vb` e questi tre manuali; manifest cumulativo della PR invariato a sette file. La review sorgente A sul candidato originario non certifica la REV2, che richiede una nuova review mirata.

- Contratto verificato nelle fonti pertinenti: asset operativi locali, nessun requisito documentato individuato che imponga immagini marchio remote. Nessuna lettura DB o verifica dei valori commerciali reali eseguita. `ResolveBrandImage` conserva filename e riferimenti locali root/app-relative alla directory marchi, encoding URL sicuro e formati PNG/JPG/JPEG/WEBP/SVG gia ammessi; rifiuta URL remoti/protocol-relative, traversal anche codificato, controlli, path malformati, estensioni non ammesse e redirect filesystem (reparse point). Verifica esistenza e contenimento fisico prima di emettere il solo URL locale. File/directory mancanti restituiscono assenza, senza placeholder o nomi dedotti.
- Eliminati `RuntimeUrlExistsCached`, HEAD/redirect/cache di rete e import associato, essendo quello dei marchi l'unico chiamante. `BuildRuntimeAssetUrl`, usato anche dal logo SEO, e i resolver di altre immagini restano invariati. `FilterBrandRows` delega tutta la validazione al resolver fail-closed, evitando che il precedente precheck `Path.GetFileName` interrompa il caricamento su valori malformati; query, DataTable sorgente/schema/ordine/limite, brand ID, descrizione e `BrandLink` invariati. Conservata la visibilita `HomeBrandsSection.Visible = Not IsTableEmpty(brandRows)`.
- **127/127 test differenziali PASS** sul tipo HOME realmente compilato, ospitato in System.Web isolato con configurazione sintetica: fixture Tech/Food, forme locali/encoding/estensioni, file e directory assenti, tutti invalidi, piu marchi/limite/ordine/schema/ID/link, URL esterni e redirect tentati, traversal e controlli. Rendering isolato dei marchi vuoti/non vuoti con predicato di visibilita esistente; nessun lifecycle HOME completo o DB reale. Factory HTTP/HTTPS di rifiuto attive nell'AppDomain fixture: **zero tentativi HTTP**, zero GET IIS e zero chiamate DB. Nessun nome/demo marchio aggiunto al runtime.
- **Nuova precompile completa safe ASP.NET 4.8 PASS**, 353 input dal checkout canonico, zero configurazioni operative lette/copiate. Evidenze REV2 in `C:\KeepStoreWeb\PR361-REV2-QA` (risultati, hash sorgente, log compilazione), separate dalle evidenze originali. Confronto rispetto all'HEAD originario: regioni runtime fuori dal resolver/precheck marchi e import di rete **identiche**; lifecycle, SQL/Fill/Open, SEO, prezzi/IVA/promo/stock/TCId/cart-state e card non modificati. Verifica mirata degli altri componenti diretti HOME: nessun altro client HTTP server-side individuato nel percorso ordinario esaminato; risorse richieste dal browser e link navigabili sono casi distinti. Non e una certificazione HTTP del target IIS. Suite originarie 244/17/70 e header 418/10 non ripetute e non trasformate in prove IIS.
- Preflight ambientale separato: mapping/binding acquisiti dal PO, nessuna nuova discovery amministrativa. Il PO attesta **chiave effettiva `KeepStore.Diagnostics.HomeStageTiming.Enabled` assente**, quindi `TryStart` resta OFF per default; attestazione manuale, non lettura automatica di `web.config`. **Esclusivita del pool UNKNOWN**: IIS Manager non espone una finestra gia aperta; nessuna elevazione o cambio permessi tentato. Unica attestazione ambientale residua: `Application Pools > KeepStoreIntegrationPool > Visualizza applicazioni`, verificare che serva soltanto Integration. Nessuna configurazione modificata.
- Il precedente pacchetto a cinque file e **SUPERATO**. Futuro smoke, solo dopo review REV2 positiva e pool esclusivo attestato: sei runtime, quattro della #361 aggiornata (`Default.aspx`, `Default.aspx.vb`, CSS, `Page.master`), script #360 blob `24a78acae852f09cafd93d56a88141e628778a87`, helper stable blob `bca78765aa860596e5251d5dc149e6baeb3b31b0`. L'helper e assente su Integration: aggiungerlo solo temporaneamente e rimuoverlo al rollback; cinque originali da salvare/ripristinare con hash/ACL. Restano da eseguire HOME dei due tenant, browser 390/1365, ricerca #360 e rollback. **IIS smoke NON ESEGUITO; B complessivo**, nessuna deroga implicita, merge/deploy o task successivo.

- A: introduzione server-side esclusiva del modo hero `none`, nome/Business Description dal tenant gia validato in `ApplyHomeSeo`, Literal encoded e microcopy neutro se la descrizione manca. Un solo link catalogo, nessuna immagine nuova o lista tassonomica duplicata. I tre casi banner esistenti, inclusa conversione laterale in hero, restano intatti.
- B: griglia esistente alimentata dal filtro tassonomico gia disponibile (identita positiva, descrizione e URL `st` esatto, deduplica), limite 12; navigazione hero/editoriale limitata a 9 come prima. Pochi reparti non lasciano sei colonne fittizie; testo lungo resta nel DOM e fallback immagine iniziale gia esistente preservato. Nessuna categoria/tipologia scelta implicitamente, query o classificazione merceologica nuova.
- C: il pannello generico compare solo senza selezioni prodotto renderizzate e quando non duplica la nuova introduzione; testo neutro, nessuna dichiarazione di catalogo vuoto/esaurito che confonda errore DB e assenza dati. Con introduzione visibile, omessa anche la CTA catalogo ripetuta nell'intestazione reparti. La descrizione trust non viene ripetuta sotto l'introduzione, anche nel percorso successivo di composizione. Sezioni prodotto/editoriali, nota IVA OR delle righe effettive e lifecycle client dei Visti di recente preservati.
- D: solo regole aggiunte sotto `body.ks-page-home` e classi adattive; nessun override globale o geometria card/Swiper/header/PDP/MiniCart. Focus visibile, CTA minima 44px, contrasto CTA su colore tema `primary-2`, wrap lungo e griglia ridotta per 1/2/3 reparti. Nessuna nuova libreria o asset runtime.

Design Gate: esaminato ONSUS originale `Public/assets/keepstore/index.html` nella storia `a97a799^`, struttura `.s-banner-wrapper`, `.banner-image-product-4`, `.content/.box-title/.box-btn`, oltre ai guardrail Home Card. Fonti correnti consultate 2026-10-18: [Baymard category navigation](https://baymard.com/blog/ecommerce-category-page), [W3C reflow](https://www.w3.org/WAI/WCAG21/Understanding/reflow), [W3C target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum). Nessuna equivalenza pixel-perfect o certificazione WCAG completa.

| Aspetto | ONSUS originale | Benchmark attuale | KeepStore corrente | Decisione |
| --- | --- | --- | --- | --- |
| Hero assente | Gerarchia titolo/copy/CTA | Navigazione prima di promo non pertinenti | Nasconde hero senza banner | Intro testuale tenant, senza contenuti demo |
| Catalogo piccolo | Navigazione per reparti | Evitare passaggi intermedi inutili | Griglia esistente | Una griglia, URL st reali, colonne proporzionate |
| Mobile | Blocchi impilati e CTA | Reflow e focus/target accessibili | CSS/azioni card stabilizzati | Solo bridge adattivo, CTA KeepStore 44px |

QA esclusivamente `C:\Temp\KeepStoreHomeAdaptiveShopping1A`: **244/244 asserzioni PASS** sui metodi della HOME realmente precompilata (reflection, controlli System.Web, contesti/identita Tech/Food sintetici, nessun ProcessRequest/IIS/SQL). Coperti hero/side/none, 0/1/3/6/15 reparti, URL incoerenti/deduplica, descrizione presente/assente/encoded, composizione ripetuta, pool 0/1/8, recenti e trust. Non e un lifecycle HTTP completo o prova di listini/stock reali.

**Chrome reale 155.0.8059.79: 70/70 configurazioni PASS**, Tech/Food x 360/390/430/768/1365 x sette casi (intro vuota/singola/molti-testi-lunghi, hero+laterali, solo hero, laterale convertito, banner senza pool). Markup fixture derivato dagli ASPX e helper reali, prodotti/trasporto sintetici; contesti offline e service worker bloccati. Zero page errors e richieste esterne; CTA tastiera/destinazione sintetica/focus/target, overflow, H1 del caso fixture e griglia verificati. Dimensioni card campione identiche con CSS base/candidato; reference originale acquisita ai cinque viewport con immagini neutre sintetiche. Screenshot 390/1365 esaminati; non sono HOME IIS completa, animazioni/Swiper attivi, dispositivi fisici o tenant/endpoint reali.

**Precompile completa ASP.NET 4.8.10001.0 PASS** via `aspnet_compiler.exe` diretto, 353 input tracked e dipendenze locali, configurazione sintetica da zero con connessioni vuote, UTF-8, riferimenti Framework e binding dalle DLL effettive. Configurazioni operative lette/copiate: **0**; nessun cambio ExecutionPolicy o bypass, nessuna chiamata applicativa. Gli errori iniziali del sandbox (riferimenti/codifica mancanti) sono stati risolti solo nella configurazione QA, senza patch fuori manifest. I successivi test compilati e il candidato ASPX/VB risultano PASS, senza estendere la certificazione IIS.

Evidenze SHA-256: `server-results.json` = `E93A39D95FA33E8F253C045BB52D33167A53BB601532B2DCAF58D40749727D8E`; `browser-results.json` = `F723776F11D198EF5D3D8170A8FC0B576ED6FCD18B39064F4EFFBBDF05A49A5D`; `precompile.log` = `EB70056FC8954B99ADBDDB91BBC48C81E43459E8EE39B0F54B90065C15EEB18D`. Contratti/diff-check/manifest/segreti nelle aggiunte verificati; 1.932 file/stati fuori manifest, web.config, quattro cancellazioni e 54 untracked confrontati con inventario/hash iniziali. Contrasto dei nuovi testi/CTA verificato nelle fixture >=4,5:1; nessuna certificazione WCAG complessiva. SQL, resolver, card, prezzi/IVA/promo/stock/TCId, token e script condivisi invariati; variazioni query attese **0**, TTFB non misurato. Nessuna ripetizione di #360/#359/#352. Nessun finding bloccante fuori scope.

Gate successivo: review indipendente della PR DRAFT, poi solo futuro smoke applicativo autorizzato e decisione PO. Nessuna deroga precedente estesa; la build sintetica non certifica il deploy/endpoint della #360. **FILE PRONTI PER FUTURO SMOKE SERVER DEL PRODUCT OWNER**: i quattro runtime del manifest, senza autorizzare upload. `SECURITY-DB-CREDENTIALS-HARDENING-1A` PIANIFICATO / NON AVVIATO; nessuna credenziale/configurazione o PR preesistente modificata. KS-E01 resta PARZIALE, nessun `StorefrontCapabilityProfile`, task successivo o ecommerce dichiarato completo.

### HEADER-SEARCH-CONTINUITY-1A — KS-A01 / KS-B01, PR #360, CHIUSO A / SOURCE INTEGRATION ONLY

**WAIVER-PR360 — SOURCE INTEGRATION ONLY**, autorizzazione esplicita PO 2026-10-18: review indipendente ChatGPT A, review GitHub #5564548438 sul runtime immutato `0916a1ddcb0c6e0cc2c479c83381e1c4af942e18`. Autorizzati un solo commit docs-only figlio diretto e integrazione FF-only su `frontend-rebuild`, dalla base sotto indicata; identita finale dal Git, senza commit ricorsivi. Evidenze gia acquisite 418/418, 108 scenari Tech/Food, Chrome fixture 10/10 e controlli tecnici PASS riutilizzati senza nuovi test.

**Precompile ASP.NET 4.8 NON ESEGUITA** (ExecutionPolicy prima dell'avvio del compilatore); **smoke IIS NON ESEGUITO**, nessuna verifica dell'applicazione reale o endpoint effettivo. La deroga vale soltanto per integrazione sorgente, non produzione. Prima del deploy sono obbligatori compilazione compatibile .NET Framework 4.8, smoke applicativo della ricerca header, verifica reale desktop/mobile sui due tenant e regressioni pertinenti. Nessun controllo mancante diventa PASS; nessuna deroga precedente, inclusa #359, viene estesa.

Mandato PO 2026-10-18: unico batch per (A) concorrenza e intento corrente, (B) stati/risposte suggest, (C) invio e destinazioni, (D) lifecycle desktop/mobile. Base esatta `ffab4224a3c8c1ccf0d8072cc3cf1f47fa25c5c5`; branch `task/header-search-continuity-1a`, un commit runtime e solo closeout documentale. Il mandato finale autorizza esclusivamente il merge FF-only; nessun deploy, accesso IIS/DB, account o operazione commerciale.

Manifest esclusivo: `Public/assets/keepstore/js/ks-page-flags.js`, il solo cache-buster relativo in `Page.master`, questo Masterplan, START_HERE e PRODUCT_ROADMAP. Versione asset `20261018-header-search-continuity1a`. Nessuna modifica ad ASCX/VB, endpoint, CSS, provider, query, prezzi/IVA/promo/stock, sessioni backend, credenziali o privilegi MySQL.

- A: generazione monotona per istanza, invalidata immediatamente prima del debounce a ogni cambio query/ambito o chiusura. Tutte le continuazioni suggest/lookup verificano generazione, snapshot query/ambito e presenza del controllo corrente. Abort best-effort, non requisito di correttezza; A->B->A distingue anche URL identici. Coordinamento delle sole navigazioni fra desktop/mobile, senza condividere risultati o selezioni.
- B: envelope `ok === true`, array e identita/titolo/URL minimi coerenti; prezzo e altri metadati commerciali restano facoltativi. Pending, vuoto valido, envelope invalido, errore e timeout distinti; nessuna voce precedente attivabile. Recupero catalogo con query/ambito correnti, output encoded, listbox/option e ARIA expanded/selected/active-descendant coerenti, senza dichiarare conformita WCAG completa.
- C: Enter, bottone e submit guard condividono lo stesso invio; debounce cancellato e lookup equivalenti coalescenti, anche nel passaggio reale di focus Enter->clic. Lookup superati non navigano dopo nuovo input, altra istanza o scelta valida. Codice/EAN forte conservato soltanto su envelope e destinazione prodotto validi; fallback catalogo esistente, destinazioni same-origin limitate ad articolo/catalogo, nessuna estensione verso URL esterni o malformati.
- D: binding limitato ai due marker header esistenti, idempotente anche per input sostituito; HOME e form estranei non intercettati. Escape, blur, clic esterno, selezione/frecce/Enter, IME e click/tap correnti verificati; nessuna riapertura tardiva. Restano 220 ms debounce, 4200 ms timeout suggest e 900 ms lookup, senza retry/polling o nuovo storage.

Design Gate proporzionato, senza redesign: riferimento ONSUS originale `Public/assets/keepstore/shop-default.html` dalla storia Git `a97a799^` (form, ambito, input e bottone), stili KeepStore esistenti preservati byte-per-byte e contratto reale SiteHeader/HomeDepartmentsMenu/CatalogMenuProvider/search_suggest consultato read-only. Riferimento accessibilita aggiornato: [W3C APG Combobox](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/), per focus sull'input, frecce/Enter/Escape e relazione con le opzioni. Nessun benchmark retailer generale o modifica estetica; mobile-first verificato sulle sole fixture dichiarate.

QA temporaneo esclusivamente `C:\Temp\KeepStoreHeaderSearchContinuity1A`: `runner.cjs`, `deterministic.js`, `fixture.html`, `qa-results.json`, screenshot ai cinque viewport e `precompile.log`. **418/418 controlli PASS**: 54 scenari e 209 asserzioni per catalogo sintetico Tech/Food (108 scenari totali). Funzioni JavaScript effettive e DOM Chromium reale; trasporto, clock e sink di navigazione controllati, anche senza AbortController e con trasporto che ignora l'abort. Non e un test dell'endpoint reale o del suo database.

**Browser reale fixture: 10/10 PASS**, Chrome `155.0.8059.79`, due cataloghi sintetici a 360/390/430/768/1365, touch emulato alle tre larghezze mobili. Script runtime non strumentato nel controllo browser, trasporto sintetico e routing locale intercettato; contesti offline, service worker bloccati, zero richieste esterne inattese e zero page errors. Verificati render, selezione/ARIA, chiusura, ambito, Enter->bottone senza lookup doppio, lookup stale, click/tap e overflow; screenshot 390/1365 esaminati. Non certifica dispositivi fisici, screen reader, HTML completo dello storefront, IIS o tenant reali.

Regressioni protette: confronto esatto con la base di cinque regioni non interessate (recenti/cookie/storage, stili condivisi, trasporto comune, helper ranking e intero blocco menu/mobile/HOME/ranking/compare/API pubbliche), piu prove di menu e form estranei. Non ripetuti i 207 test account #359, audit generali o benchmark HOME.

**Precompile ASP.NET 4.8 NON ESEGUITA**: unico tentativo di avvio del runner safe versionato rifiutato dalla ExecutionPolicy Windows; compilatore non avviato. Nessun cambio policy, bypass, installazione o riconfigurazione strumenti; log sanitizzato nel solo QA. Sintassi JS verificata; controlli finali diff/manifest/segreti e preservazione nel rapporto/PR. Preflight pubblicazione GitHub: 0 workflow, 0 webhook, 0 deployment; Pages 404, nessun hook locale attivo rilevato. Nessun automatismo di deploy rilevato nel perimetro verificato.

Review indipendente A acquisita; integrazione source autorizzata dalla sola WAIVER-PR360 sopra, con gate pre-deploy ancora obbligatori e nessuna certificazione IIS. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER**, soltanto dopo nuova autorizzazione: `Public/assets/keepstore/js/ks-page-flags.js` e `Page.master`. File non installati. Main e configurazioni/quattro cancellazioni/54 untracked preservati; `SECURITY-DB-CREDENTIALS-HARDENING-1A` resta PIANIFICATO / NON AVVIATO, rotazione delle credenziali gia esposte con priorita anticipata e autorizzazione separata. Nessun task successivo avviato.

### ACCOUNT-SESSION-REVOCATION-1A — PR #359, CHIUSO A / SOURCE INTEGRATION ONLY

Decisione PO 2026-10-18: integrare #359 in `frontend-rebuild` esclusivamente FF-only, senza chiuderla come PR non integrata. Review indipendente A acquisita; base stabile verificata `e5a8b309c7dc7f4c171a15b080bc22cc897e0d59`, runtime originario revisionato `be1033112bd5ad3acce4d21480800da612fe59e2`, un commit figlio diretto della base. Aggiunto esclusivamente un commit docs-only sui tre manuali canonici; `Page.master.vb` resta identico alla candidata. Identita del commit documentale/finale e stato MERGED/CLOSED si leggono dal Git/PR reali, evitando un commit ricorsivo per auto-inserire lo SHA.

**Waiver PO: SOURCE INTEGRATION ONLY. Smoke IIS 0/8 NON ESEGUITO**, per il blocco permessi `web.config`; mai PASS. L'analisi read-only successiva non ha eseguito HTTP e non ha installato la candidata su Integration: runtime installato e prerequisiti IIS/DB non certificavano #359. La deroga consente soltanto l'integrazione sorgente, non un deploy, una prova operativa o una certificazione account. Login/password reali, pagine account complete, driver/host reali, browser, IIS autenticato e produzione restano NON CERTIFICATI; KS-C02 resta PARZIALE.

Evidenze gia acquisite, riusate senza ripetizione: baseline immutabile 6/6 PASS; suite candidata System.Web 207/207 PASS su 42 richieste in-process; precompile safe ASP.NET Framework64 4.8 PASS; review A. Provider MySql/host e osservatori di scrittura erano sintetici; nessuna prova live aggiunta. Nuove verifiche limitate a SHA/parent/manifest, diff documentale, segreti nelle aggiunte, FF e preservazione dello stato locale.

Preflight auto-deploy: GitHub verificato con 0 workflow, 0 webhook e 0 deployment registrati, Pages assente, nessuno status/check sul commit; nessun hook locale attivo rilevato. Nessun automatismo di deploy rilevato nel perimetro verificato. Integrazione tramite push normale; nessun merge commit, rebase, reset, clean, force push o mutazione di altre PR. `main` e `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`; `web.config` locale, quattro tracked deletions, 54 untracked e staging preservati con inventario/hash. Nessuna operazione su DB/IIS, runtime Integration, connessioni, credenziali, produzione, ordini, pagamenti o e-mail.

### Checkpoint storico SECURITY-DB-CREDENTIALS-HARDENING-1A — pianificazione prima del Batch A

Decisione storica: account dedicati per applicazione/consumer, privilegi minimi, protezione segreti e migrazione graduale, mantenendo DB condiviso e isolamento aziende. La selezione del database nella connection string non limita i privilegi. Il successivo mandato 2026-10-20 autorizza il solo Batch A software nel checkpoint corrente, che prevale su PIANIFICATO/NON AVVIATO; nessuna operazione operativa implicita e nessuna ripetizione della bonifica dei finding storici.

### Checkpoint precedente — ACCOUNT-SESSION-REVOCATION-1A, A tecnico locale prima di review/deroga

Mandato PO 2026-10-16, base esatta #358 `e5a8b309c7dc7f4c171a15b080bc22cc897e0d59`, branch `task/account-session-revocation-1a`. #358 MERGED/CLOSED verificata, review A e smoke IIS 28/28 acquisito; #357 resta chiusa con 19/19 e coperture residue accettate. I checkpoint sottostanti conservano lo stato storico precedente al merge; non riaprono i task.

APAT-F01 e un finding statico MEDIUM dell'audit account concluso e sigillato: il marker `AuthenticatedAziendaID` coerente evitava il controllo corrente dei due flag attivi, consentendo alla propria Session gia autenticata di sopravvivere alla disabilitazione. Nessun accesso a dati di altri proprietari o attacco reale dimostrato. La correzione riguarda soltanto `Page.master.vb`: query `vlogin` parametrizzata con LoginId/azienda, entrambi i flag attivi e confronto owner, anche per sessioni marcate; legacy privo del marker idratato soltanto dal record verificato. Listino e fiscalita legittimi preservati; nessuna query auth nuova agli anonimi. Riuso positivo limitato a HttpContext.Items e alla stessa identita/tenant/listino della singola request, mai Session o cache cross-request.

Revoca centrale e ripristino del listino/IVA anonimi del tenant precedono un errore HTTP generico terminale; anche il cambio storefront che aveva gia cancellato il login ferma la richiesta corrente. Il controllo resta in Init, dopo tenant/default autorevoli e prima di Load/postback; CompleteRequest da solo non e considerato una barriera sufficiente. Nessun Session.Clear/Abandon introdotto, carrello e altri dati anonimi non eliminati, nessun nuovo redirect o dettaglio SQL nella risposta/log.

Blocco precedente e ripresa autorizzata: ESET aveva impedito il caricamento del runner `Run-SessionRevocation.ps1`; il rilevamento non e classificato come falso positivo. Dopo disinstallazione ESET e riavvio dichiarati dal PO, verificato Microsoft Defender in modalita Normal, protezione realtime attiva, firme non obsolete; scansione ufficiale del runner conclusa (eventi 1000/1001 correlati, scan ID `588FA827-4BF4-4570-BB58-7CF5D1E523B1`) e zero rilevamenti pertinenti. Runner originale 7.694 byte, SHA256 invariato `540956f929da12e3a4ea3e77860cf9e41cc24d9ba179b9cf3ffc6de1bc31e5f7`. Nessuna esclusione, disattivazione, bypass AMSI o modifica ExecutionPolicy. Il primo tentativo consentito ha evidenziato soltanto un errore API nella fixture VB: corretto `GetHttpVerb` in `GetHttpVerbName`; aggiunti poi contatori di cleanup e due casi tenant, soltanto fuori repository, con nuove scansioni Defender negative delle dipendenze prima dell'esecuzione. Nessuna alterazione del runner per eludere il blocco.

QA locale finale: baseline immutabile 6/6 assert PASS su tre richieste simulate, incluso POST con Session disabilitata che raggiunge la scrittura sentinella prima del fix; candidata 207/207 assert PASS su 42 richieste in-process. Metodi master/LeggiAzienda/IVA/Init e logout estratti dal sorgente, policy e provider prezzi reali; Page.ProcessRequest, MasterPage, Session, ViewState firmato ed event validation System.Web effettivi. Provider MySql, host resolver e pagine/handler sentinella sintetici, nessun listener o connessione reale. GET/POST validi raggiungono il controllo positivo; login/utente disabilitati, login mancante, owner/azienda incoerenti ed errore/timeout simulato terminano prima di Load e dei tre POST profilo/indirizzo/predefinito, anche con ID stale acquisiti prima di Init. Coperti due tenant, legacy con owner valido/mancante/incoerente, cambio storefront, logout e successivo contratto Session di login legittimo, carrello/listino/IVA anonimi preservati. Anonimi: zero query auth aggiunte; stessa identita: una query per request anche con tre LeggiAzienda; nuova request o identita diversa richiede nuova verifica.

Unica review read-only candidata: nessun bypass residuo dimostrato; confermato un LOW di cleanup nei due rami 421 con tenant assente/incoerente. Correzione minima nello stesso master: chiusura reader/connessione prima dell'arresto, con Finally che mantiene la revoca anche in caso di errore di cleanup; entrambi i casi verificati dal provider fake senza risorse aperte. Precompile safe ASP.NET Framework64 4.8 ripetuta sul runtime finale PASS (353 input, zero configurazioni operative copiate, cleanup PASS); diff-check, manifest e scan delle aggiunte PASS. Prove e sorgenti QA supplementari conservati tramite interfaccia ufficiale nella raccolta standalone `artifacts/session-revocation-validation`, distinta dall'audit sigillato, mai modificato.

Esito A tecnico locale; consegna autorizzata con commit unico e PR DRAFT, non integrazione. Nessuna connessione DB reale, HTTP/IIS, account reale, deploy o mutazione operativa eseguita. Login/password UI, pagine account complete, tenant/driver DB reali e autenticato IIS NON CERTIFICATI: il test successivo al login usa il contratto Session sintetico, non autentica un account. Review indipendente ChatGPT della PR e valutazione smoke Integration restano gate successivi; KS-C02 complessivo NON certificato. Manifest: MODIFIED `Page.master.vb` e soli tre checkpoint canonici; nessun ADDED/DELETED/RENAMED runtime, nessuna dipendenza o cache-buster nuovo. Stato locale protetto fuori manifest preservato byte-per-byte; staging finale vuoto. FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER: solo `Page.master.vb`, previa review e autorizzazione separata del target/operazioni, con backup e rollback; nessun deploy o merge da questo mandato.

### Checkpoint precedente — conferma registrazione (stato antecedente alla chiusura #358)

### ACCOUNT-JOURNEY-READINESS-1A — KS-C02 / F01, A tecnico locale

Ripresa PO 2026-10-16, branch `task/account-journey-readiness-1a`, base stabile locale/origin `401d57a0dc8fd004d00f4ba2952f2f613d12b2b0`; main/origin invariati `976e99f17cabc8a5c6a8715463444edfeaadcd91`. #356 e #357 verificate MERGED/CLOSED: #356 mantiene la deroga PO allo smoke Integration NON ESEGUITO; F02 owner/azienda e F03 binding #357 chiusi, 19/19 smoke Integration acquisiti con coperture residue accettate dal PO. I checkpoint antecedenti sotto restano storici, non riaprono tali PR. KS-C02 complessivo rimane PARZIALE.

F01 riprodotto prima della patch con input innocuo: interpolazione diretta di `redirect` nel meta-refresh coupon permette uscita dall'attributo HTML; nessuna disclosure/exploit live attestata. Correzione esclusivamente nella conferma: `state` singolo risolto in PreInit per master e copy coerenti, `redirect` singolo senza ReturnUrl concorrente, normalizzazione e `BuildLoginUrl` dalla policy esistente READ-ONLY. Unica destinazione request-scoped per refresh e link, entrambi con encoding dell'intero attributo. Policy/allowlist non duplicate: esterni, schemi pericolosi, encoding ambiguo, traversal, token e redirect annidati rifiutati; checkout degrada a carrello. Coupon senza destinazione valida va al login locale, standard sempre allo shop; niente recuperi da Session/referrer. Rimosso TitleContent incompatibile con Coupon.master; titolo impostato in Load dopo aver svuotato il solo HtmlTitle dei placeholder, senza modificare i master.

Copy: registrazione completata distinta dall'invio e-mail non verificato, come richiesto dal backend che puo proseguire dopo errore del sender. Messaggio e CTA coupon indicano login; standard indicano shop. Design Gate proporzionato al fix: esaminato modal account originale in `_aspnet_precompile_checkout4_20260520184528/Public/assets/keepstore/my-account.html` e struttura KeepStore; classi/layout responsive conservati, nessun redesign/CSS/JS o nuovo meccanismo client. Fonte primaria consultata 2026-10-16: [W3C, link purpose](https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html), soltanto per etichette/destinazioni coerenti; non benchmark esteso ne certificazione visuale/accessibilita.

QA: **86 scenari / 1.352 assert PASS** con HttpRuntime.ProcessRequest .NET Framework 4.8, ASPX/VB reali e due policy byte-identiche, due host tenant sintetici; GET e quattro POST con ViewState realmente emesso e IsPostBack verificato. Master sintetici senza DB, con i placeholder effettivi dei due master: rendering/title e binding del contenuto reali, non esecuzione dei master commerciali. Coperti positivi/default, coupon, assenza/duplicati/case alias/ReturnUrl concorrente, URL esterni/cross-host/porta/schema, JavaScript/data, quote innocue, caratteri speciali, doppia codifica, NULL/CRLF, traversal, pagine tecniche, loop, downgrade checkout, query catalogo con virgola e promo legacy. Il breakout originale non si riproduce; link manuale e refresh concordano. Precompile safe dell'app completa PASS (353 input, Framework64 4.8, zero configurazioni operative copiate, cleanup PASS). Review read-only separata del candidato senza bypass/regressioni concreti; verifica mirata aggiuntiva di duplicati con chiave percent-encoded e titolo System.Web PASS, non review ChatGPT della PR pubblicata. Harness/evidenze supplementari fuori repository; diff-check e scan delle aggiunte PASS. Nessuna nuova query, asset, richiesta funzionale o misura TTFB; timer originale conservato.

Limiti: host/tenant simulati non certificano risoluzione commerciale o autenticazione; IIS/HTTP autenticato, browser visuale, creazione account, consegna e-mail e percorso coupon completo NON ESEGUITI. Il backend storico perde gia il redirect nel ramo coupon e coupon_opzioni.aspx e fuori allowlist: nessun ampliamento policy o riparazione dei processi coupon, solo fallback sicuro quando la conferma non riceve una destinazione ammessa. Il ramo registrazione dal carrello continua direttamente a carrello.aspx, byte-invariato. Auth, Session, merge, persistenza account, reset, prezzi, documenti e processi coupon restano fuori manifest.

Manifest: MODIFIED `registrazioneok.aspx`, `registrazioneok.aspx.vb`; tre documenti di ingresso/evidenze aggiornati, nessun ADDED/DELETED/RENAMED runtime. Dipendenze esistenti READ-ONLY `PostLoginReturnUrlPolicy` e `LegacyPromotionRoutePolicy`, master e login invariati; nessun Bin/asset/cache-buster nuovo. FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER: soltanto i due runtime insieme, su release compatibile con la base e dopo review/autorizzazione target/operazioni; backup byte/hash e rollback di entrambi, senza copiare configurazioni. Nessun Apply, deploy, IIS, DB, gateway, ordine o e-mail; nessun merge. Review indipendente PR e smoke autentico restano gate separati; valutazione dei criteri KS-C02 residui NON AVVIATA.

### Checkpoint precedente — KS-C01 (stati antecedenti alla chiusura #356)

### ORDER-JOURNEY-CONTINUITY-1A — KS-C01 / A tecnico, B complessivo

REV1 #356 — F01 MEDIUM: riprodotto isolatamente sulla versione `2a34319f788b65e577885aa015042121495856c0` con Repeater System.Web ricostruito da ViewState, quantita positiva e ricaricamento del read model simulato fallito: avviso assente e azioni visibili. Nessuna attestazione IIS. Correzione solo in `carrello.aspx.vb`: avviso indipendente dal numero dei controlli, righe/totali/azioni/checkout non presentati come utilizzabili finche la lettura e non verificabile. Guard finale in PreRenderComplete dopo i callback dei controlli; flag della sola request evita che ApplyCheckoutStepUi riapra il percorso o cambi Session dopo l'oscuramento UI. IsCartEmptyState e i precedenti rami Session rimangono invariati, nessuna riga/quantita cancellata. 95 verifiche compilate mirate PASS (matrice hasItems/owner/load, modello assente, ViewState, riabilitazioni tardive, pieno/vuoto validi, Session preservata), 11 invarianti sorgente PASS e precompile safe 4.8 PASS con 353 input, zero configurazioni operative copiate e cleanup PASS. Ripristino dei singoli stati child/ViewState e fallimento read model simulati in memoria, non ciclo HTTP WebForms completo. Prove precedenti non influenzate riutilizzate; nessun nuovo browser/IIS/DB o test transazionale. Delta runtime REV1: un solo VB; aggiornamento minimo dei tre documenti gia in PR. A tecnico REV1 / B complessivo per review indipendente REV1 e gate applicativo NON ESEGUITO; nessun merge o task successivo.

Mandato FEATURE-BATCH PO 2026-10-15, base `5e31cbd6ef24c34a191117dad9d16971e85d43b3`, branch `task/order-journey-continuity-1a`. #355 MERGED/CLOSED e sync locale A: due commit originali, FF-only, deroga PO specifica allo smoke Integration NON ESEGUITO registrata nella conversazione PR; nessun deploy #355 attestato. Il checkpoint #355 sotto conserva le evidenze antecedenti al merge, non riapre quel batch. KS-C01 non eredita la deroga.

Gap dimostrati e delta minimo: (A) errore del read model svuota la lista ma `ArticoliCarrello` rendeva il messaggio di carrello vuoto; ora il solo rendering distingue `HasOwner/LoadSucceeded` request-scoped e propone Ricarica, senza alterare i rami Session/checkout. Il read model e gia stato caricato dalle sorgenti dei repeater, nessuna query aggiuntiva. (B) riepilogo con descrizioni generiche; ora descrizioni dai radio server checked/enabled e dalla DataKey esatta corrispondente al draft validato, incluse spedizioni promozionali e opzione gratuita `-1/-2`. Mai dai campi client. Output encoded, fallback esplicito verso Modifica se mancano draft o metadati affidabili; nessuna scelta o disponibilita inventata. Il testo distingue riepilogo da ordine inviato. (C) ricevuta prometteva sempre e-mail: ora distingue ordine registrato da pagamento, lasciando stato e istruzioni autorevoli al rendering esistente.

Percorsi gia conformi preservati: ReturnUrl locale carrello/login e merge owner-scoped; guard delle quantita dirty/in-flight; modifica spedizione/pagamento e draft; validator/consenso; dispatcher first-wins 303/PRG; stock/prezzo rivalidati, replay sul documento esistente, ramo commit incerto con messaggio proprio `Non ripetere l'invio`, e-mail/gateway post-commit. Nessun nuovo listener/intercettazione submit, calcolo client o transazione. La lettura sorgente non certifica un invio reale. Timeout di rete indefinito del salvataggio quantita resta candidato UX separato, non corretto implicitamente.

Design Gate proporzionato: reference locale `shop-cart.html`, `checkout.html`, `order-details.html` nel package `_aspnet_precompile_checkout4_20260520184528/Public/assets/keepstore`; stepper, colonne contenuto/riepilogo, azioni distinte, ricevuta e metodo pagamento. Consultati 2026-10-15 [Baymard review-order mobile](https://baymard.com/mcommerce-usability/benchmark/mobile-page-types/review-order), [checkout UX](https://baymard.com/research-articles/current-state-of-checkout-ux), [W3C error suggestion](https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion). Nessuna importazione di dati demo, checkout ospite o motore nuovo.

| Aspetto | ONSUS | Benchmark | KeepStore prima | Soluzione |
| --- | --- | --- | --- | --- |
| Scelte nel riepilogo | Metodo e totale riconoscibili | Revisione prima della conferma | Etichette generiche | Descrizioni server esatte o fallback trasparente; layout originale conservato |
| Recupero lettura | Messaggi separati dal contenuto | Errore comprensibile e correggibile | Errore tecnico sembrava vuoto | Alert con Ricarica, distinto dal vuoto verificato |
| Esito | Ricevuta e pagamento distinti | Riepilogo non confuso con conferma | Promessa assoluta e-mail | Copy pre-invio e ordine ricevuto senza promessa di incasso/e-mail |

QA isolata: 68/68 controlli VB compilati con i metodi reali di binding estratti, System.Web GridView/DataKeys/RadioButton, fixture Tech/Food; checked/disabled/ID discordanti, encoding, draft assente/rifiutato, promo/standard/gratuita, pagamento, cinque stati visibilita. Identity/draft/read model/indirizzi sono stub, non verifica dell'autorita commerciale. Conway non caricabile nel processo harness per Windows `0x80131515`: nessun unblock; RadioButton System.Web con sola proprieta Value aggiunta nel test. Precompile safe dell'app completa .NET 4.8 PASS: 353 input, configurazione sintetica, zero copie operative, cleanup proprio PASS. 20/20 scenari compilati del modello recovery, 15/15 engine quantita corrente con fake DOM/fetch/snapshot e 16 invarianti sorgente PASS. Nessuna rete commerciale/DB/ordine/SMTP nei test.

Limiti runner storici: `Test-CheckoutFailureRecovery.ps1` ha superato 13 assert sorgente e si e fermato a SOURCE14, che cerca il vecchio `Vettore <= 0` invece dell'attuale `= 0` gia presente nella base; il modello 20 scenari e stato compilato separatamente, non dichiarati 40/40. Il vecchio harness quantita non raggiungeva l'enhancement per DOM incompleto: usata sola copia temporanea adattata al contratto attuale, non modificati runtime o test storici per ottenere PASS.

Browser reale Codex In-app Browser su fixture statiche loopback GET-only, CSP senza connessioni/form, asset montati effettivi: Tech/Food, 360/390/430/768/1024/1366, 36 combinazioni dei tre stati modificati PASS, nessun overflow; CTA misurate nel set Tech almeno 46 px. Prove aggiuntive: vuoto/anonimo, selezioni, fallback descrizione e azione Modifica da tastiera, consenso mancante blocca invio; consenso accettato produce un solo submit sintetico intercettato. Ramo incerto estratto dal literal reale di ordine.aspx.vb, non simulato come errore certo. Screenshot prima/dopo di riepilogo, errore lettura e ricevuta in `%TEMP%\ks-c01-evidence`. Fixture ASPX statiche con metadati server e valori sintetici: non eseguono WebForms/AutoPostBack, autenticazione, DB o ordine. La navigazione e i binding server effettivi restano gate applicativi NON ESEGUITI. Nessuna certificazione smartphone fisico/screen reader o full checkout.

Performance: zero nuovi asset/richieste funzionali, JS/CSS e cache-buster invariati; nessuna query aggiunta, pooling/cache globale o calcolo commerciale. Il beneficio qui e chiarezza/recuperabilita, non un'accelerazione o conversione misurata; TTFB live NON MISURATO. Invarianti verificati: vecchi controlli/ID/form/ValidationGroup/OnClientClick e query conservati, nucleo ordine/draft/ownership/idempotenza, prezzi/IVA/stock/TCId e flussi gateway/e-mail byte-identici alla base nei file pertinenti.

Manifest runtime MODIFIED esatto (3): `carrello.aspx`, `carrello.aspx.vb`, `ordine.aspx` (solo un paragrafo statico). Nessun ADDED/DELETED/RENAMED runtime, App_Code/Bin o dipendenza nuova; `checkout-ui.css` non montato e non modificato, nessun cambiamento CSS/JS. Documenti aggiornati: Masterplan, PRODUCT_ROADMAP, START_HERE. Sintassi, diff-check, manifest, scan delle aggiunte e hash/inventario protetti PASS; web.config, quattro cancellazioni, 54 untracked preservati fuori staging. Stable/main invariati; commit/PR da Git, un solo commit task e PR DRAFT per review.

FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER: i tre runtime del manifest, insieme e su release compatibile con la base #355, solo dopo autorizzazione target/operazioni. Prerequisito: confronto del runtime effettivamente installato e dipendenze esistenti; backup byte/hash dei tre originali, rollback dei tre e verifica hash; non copiare configurazioni. Nessun IIS/FTP/server/DB/deploy/ordine/pagamento/e-mail o merge eseguito. A tecnico / B complessivo per review indipendente e gate applicativo, senza deroga automatica. Collaudo reale varianti/autenticato, ordine/gateway e rollout persistente rimangono aperti nei propri gate. Nessun handoff gestionale nuovo. Candidato successivo KS-C02 `ACCOUNT-JOURNEY-READINESS-1A`, soltanto NON AVVIATO dopo chiusura/decisione PO.

### SHOPPING-MOBILE-EXCELLENCE-1A — KS-B01 / A tecnico, B review e smoke applicativo

REV1 PR #355, finding F01 MEDIUM della review indipendente: ritorno focus ora prioritario al trigger `filterShop`, non al precedente `document.activeElement`. Se sostituito viene risolto il nodo corrente; se nascosto su desktop si usa il primo controllo visibile dei filtri, altrimenti il contenitore catalogo utilizzabile con tabindex -1 (fuori ordine Tab). Destinazioni disconnesse, disabled, invisibili, inert o aria-hidden escluse. Nessun nuovo listener; `close(false)` per altro overlay e lifecycle rimangono invariati.

QA REV1 mirata PASS su browser Codex In-app Browser, fixture statiche isolate Tech/Food: click DOM senza focus automatico partendo da input, Escape/Chiudi/overlay con ritorno a Filtri e ripristino stato, apertura tastiera e Tab/Shift+Tab; 360/390 e resize 1024 -> 1366 con fallback visibile; trigger sostituito, trigger nascosto con fallback catalogo, UpdatePanel simulato begin/endRequest e sostituzione dei tre nodi, cinque inizializzazioni sullo stesso controller e singolo ritorno focus. Altro offcanvas: zero chiamate di ritorno al trigger, nessun focus rubato. Nessun overflow nella verifica 390; screenshot `C:\Temp\ks-mobile-evidence\rev1-focus-return-390.jpg`. Reduced motion usato per rendere deterministiche le prove focus, non tap nativo o dispositivo fisico. Sintassi JS, diff-check, manifest e secret scan PASS; hash/inventario protetti preservati. Precompile e prove layout/PDP/MiniCart precedenti riutilizzate, non ripetute: nessun relativo runtime cambiato nella REV1. Runtime REV1: solo catalog-ui.js e cache-buster JS in articoli.aspx (`20261015-mobile-excellence1a-rev1`); CSS invariati. A tecnico REV1 / B complessivo: review indipendente REV1 e smoke applicativo autorizzato ancora pendenti; nessun IIS/DB/deploy/merge o task successivo.

Mandato FEATURE-BATCH PO 2026-10-15, base `7ef9482e6795403cad7587313c1593aa16d7251f`, branch `task/shopping-mobile-excellence-1a`. #354 MERGED/CLOSED e sync locale verificati; due commit lineari, smoke Integration NON ESEGUITO per deroga PO autorizzata, non promosso a PASS. Production deployed/functional #354 dichiarati dal PO, non verifica indipendente di file, tenant o acquisti. Il checkpoint CORE sotto conserva lo storico antecedente alla chiusura.

Gap riprodotti su browser con asset reali e fixture isolate: canvas catalogo privo di ruolo/stato modal, focus iniziale/trap/ritorno e chiusura da tastiera (span); convenzioni responsive 992/1200 non uniformi. Nella fixture moderna c'era gia un solo accesso/overlay, non due: nessuna duplicazione dichiarata senza prova. Il vecchio adattatore con FAB non gestisce il catalogo corrente e resta solo per le pagine legacy senza marker. CTA card circa 43,33 px nella fixture; stepper PDP 30x30 e senza etichette. Spedizioni precedevano quantita/CTA. Card gia equal-height con slot categoria/titolo: nessun redesign o modifica globale ProductCard.

Design Gate: esaminati shop-default.html, product-detail.html e shop-cart.html del reference locale `_aspnet_precompile_checkout4_20260520184528/Public/assets/keepstore` (fuori runtime); canvas originale, gerarchia buybox, righe/cart e quantita. Consultati 2026-10-15 [Baymard mobile ecommerce](https://baymard.com/research/mcommerce-usability), [filtering](https://baymard.com/mcommerce-usability/benchmark/mobile-page-types/filtering-options), [product lists](https://baymard.com/mcommerce-usability/benchmark/mobile-page-types/product-list), [W3C target minimum](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum), [focus not obscured](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum). Il minimo WCAG 2.5.8 e 24 CSS px con eccezioni; 44/48 px sono la scelta piu ampia KeepStore per i controlli qui coinvolti, non una certificazione WCAG globale. HTML pubblici Bytecno, Prezzoforte ed e-Stayon consultabili, non percorsi mobile/transazionali verificati; nessuna copia o promessa di conversione.

| Elemento | Reference originale | Benchmark | KeepStore prima | Decisione |
| --- | --- | --- | --- | --- |
| Filtri | Canvas laterale e trigger toolbar | Riferimenti mobile/filter e focus | Canvas senza contratto modal completo | Stessi nodi, trigger/overlay unici, breakpoint 1200, focus/Tab/Escape/inert/ARIA e scroll ripristinati |
| Card | Informazioni e azioni allineate | Liste leggibili e target accessibili | Slot/allineamenti gia presenti, CTA circa 43 px | Conservare le quattro viste e i dati; minimo 44 px alla CTA nativa scoped |
| PDP | Prezzo/spedizione/quantita/CTA | Gerarchia leggibile e focus visibile | Spedizione prima dell'acquisto, stepper 30 px | Stessa unica CTA/form, quantita prima delle spedizioni, 48 px su mobile/tablet, etichette; niente nuova sticky |
| MiniCart/carrello | Drawer, righe e totale | Continuita shopping | Contratto gia consolidato | Nessun delta runtime; verifiche sul MiniCart con markup/CSS effettivi, senza certificare il checkout |

Implementazione: adattatore presentation-only sul canvas server-rendered corrente, non nuovo pannello; capture dei soli toggle catalogo per evitare doppi toggle legacy e scroll-lock residui. Nessun filtro/clonazione/URL commerciale ricostruito. Chiuso non raggiungibile (inert/aria-hidden/visibility), background isolato/restaurato, apertura non concorrente a modal/offcanvas, uscita su evento altro overlay, resize desktop e hook begin/endRequest idempotenti con dispose per nodi sostituiti. Transizione scoped con reduced motion. Binding prezzo, AutoPostBack, reset/chip/offerte/pid, Marche/load-more, ID/controlli server e native form/CSRF restano invariati. Spedizione solo spostata nel DOM dopo le azioni, senza calcoli o informazioni rimosse.

QA: browser reale Codex In-app Browser su fixture statiche loopback Tech/Food, markup estratto dagli ASPX/ASCX e asset effettivi, valori/URL commerciali sintetici, nessun IIS/DB. Sei larghezze 360/390/430/768/1024/1366 e quattro viste: 48 combinazioni, 336 controlli geometria/contenuti/ID/CTA/stato disabled/allineamento PASS. Focus/ARIA/ritorno: 20 controlli mirati PASS sui due cataloghi. PDP: 82 PASS (target, ordine, etichette, stepper e un submit sintetico per click, intercettato senza rete); MiniCart vuoto/pieno: 42 PASS. Checklist aggiuntiva browser: Tab/Shift+Tab, chiusura pointer/Escape, riaperture, resize, UpdatePanel simulato multi-callback e sostituzione nodi, evento altro overlay, zero-results e landscape 844x390 PASS; reduced motion verificato. Stato PDP non acquistabile simulato disabled; pinch 2x osservato e ripristinato, non test di reflow/browser zoom universale. Nessun errore JS inatteso nella fixture. Emulazione touch disponibile, dispatch del tap nativo non supportato dal browser integrato; telefono fisico/tastiera virtuale/screen reader NON CERTIFICATI.

18 controlli statici sui contratti reali PASS: stessi controlli/binding/espressioni server, form/postback, letterali commerciali e helper query/chip/brand invariati; blocchi CSS bilanciati e sintassi JS PASS. Precompile safe .NET 4.8 PASS, 353 input, configurazione sintetica, zero copie operative, cleanup proprio PASS. Diff-check/manifest/secret scan e hash/inventario locali verificati prima della consegna. Screenshot prima/dopo locali in `C:\Temp\ks-mobile-evidence`; non attestano l'intera applicazione o il server pubblicato.

Performance proporzionata: overlay moderni 1 -> 1, nessun FAB/pannello aggiuntivo, zero nuove richieste funzionali/query; controller unico con rimozione listener alla sostituzione, nessun motore nuovo. Delta aggregato dei quattro asset modificati circa +9.154 byte UTF-8 / +2.261 byte gzip (misura locale, non trasferimento HTTP osservato); nessun TTFB/INP/conversione inventato. Le prove del carrello sono boundary UI sintetici: nessuna certificazione di stock/prezzo/autenticazione o mutazione server; smoke reale shopping/autorizzazioni separate ancora necessari.

Manifest runtime MODIFIED esatto (6): `articoli.aspx`, `Public/assets/keepstore/js/catalog-ui.js`, `Public/assets/keepstore/css/catalog-filters-ui.css`, `Public/assets/keepstore/css/catalog-product-flow.css`, `articolo.aspx`, `Public/assets/keepstore/css/product-ui.css`. ADDED/DELETED/RENAMED runtime: nessuno; App_Code/Bin invariati. Cache-buster `20261015-mobile-excellence1a` nei rispettivi ASPX per i quattro asset. Documenti: questo Masterplan, START_HERE e PRODUCT_ROADMAP. Nessun cambiamento a main, configurazioni, SQL, prezzi/IVA/stock/TCId, servizi, endpoint, login, ordine/gateway/e-mail o asset protetti.

FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER: soltanto i sei runtime elencati, nella working copy canonica, su base compatibile con #354 e dipendenze gia installate; non autorizzazione al deploy. Backup byte/hash dei sei originali, copia coerente ASPX+asset, rollback dei sei e verifica hash; nessuna configurazione da copiare. A tecnico / B complessivo per review indipendente e smoke applicativo autorizzato pendenti. Nessun Apply/GET IIS/DB, acquisto, merge o task successivo. Dopo chiusura, candidato KS-C01: collaudo controllato carrello/checkout su ambiente/fixture autorizzati, soltanto NON AVVIATO.

### CORE-SHOPPING-CONTINUITY-1A — ricerca HOME coerente / A tecnico, B gate applicativo

REV1 PR #354, stessa base e branch: review indipendente sul primo commit `cf1ac4e40fc94cb3072186389a84ad73e12fc6a5` B per F01 (HTTP 200 + `ok:false` interpretato come zero risultati) e F02 (prodotti gia renderizzati ancora visibili durante il debounce). Corretti soltanto il client HOME e il suo cache-buster: successo richiede `ok:true`, array suggestions e dati minimi di card validi; errori applicativi/JSON/payload malformati usano lo stato temporaneamente non disponibile con recupero q encoded. Lo stato pending e immediato al nuovo input valido e riusato senza ricreare il blocco a ogni tasto; nessuna richiesta aggiuntiva. Guard di generazione conservati anche per gli errori obsoleti, focus/input non sostituiti. Nessuna modifica endpoint/ranking o logica commerciale.

Test REV1 isolati sulla funzione reale: **90/90 PASS**, contro 38 failure su 90 prima della patch, con/senza AbortController; errore applicativo HTTP 200, vero zero-results, JSON/envelope/card malformati, risultati gia visibili -> nuovo input, recupero dopo errore, query breve, conteggio richieste/aggiornamenti DOM e successi/errori fuori ordine. Test VM con timer/fetch/DOM sintetici, non prova visuale browser o IIS. I precedenti 174 controlli e la precompile safe restano evidenze del primo commit, non rieseguiti integralmente: nessuna modifica VB/struttura ASPX. Sintassi JS, diff-check, manifest e secret scan REV1 PASS. Review indipendente REV1 e smoke applicativo autorizzato ancora pendenti: A tecnico / B complessivo, PR sempre DRAFT, nessun merge/Apply/GET IIS/DB o task successivo.

Mandato FEATURE-BATCH PO acquisito 2026-10-15 per KS-A01, base esatta #353 `8fdeebe7e269ef40a7113bb0cb922d420b5f34dc` (MERGED/CLOSED e sync locale A), branch `task/core-shopping-continuity-1a`. Tre percorsi analizzati proporzionalmente: HOME -> catalogo, catalogo -> PDP, prodotto -> carrello. Nessun rifacimento di menu, provider, resolver o logica commerciale; nessun benchmark HOME/HEAD o task parallelo. Il checkpoint CANONICAL-DOCS sottostante e ora storico/integrato, non task attivo.

Gap riprodotti nel codice reale `home-default.js`, con promise/timer controllati e senza endpoint applicativo: F01 una risposta/errore della vecchia ricerca, anche dopo query breve o modifica durante il debounce, poteva sovrascrivere la richiesta corrente; AbortController da solo non protegge promise gia risolte o ambienti senza supporto. F02 clic Ragiona/esempio con debounce pendente poteva inviare due ricerche. F03 errore corrente lasciava il testo "Sto confrontando" accanto allo stato di errore. Atteso: risultati/messaggio sempre riferiti all'intento corrente, una richiesta per submit, recupero nel catalogo con q corretto. Fix: generazione locale monotona, invalidazione/abort best-effort e timer cancellato prima di nuovo intento, guard su successo/errore, reset count/query breve e messaggio errore esplicito. Identita prodotti, URL/encoding, endpoint mode=ai/limit=8/credentials, ranking, listino/prezzi/IVA/promo/stock/TCId e storage esistente invariati.

Design Gate proporzionato al fix d'interazione, non redesign: esaminati i reference locali originali `index.html`, `shop-default.html`, `product-detail.html`, `shop-cart.html` nel package storico `_aspnet_precompile_checkout4_20260520184528/Public/assets/keepstore`. Preservati gerarchia visuale, CTA e layout. Consultati il 2026-10-15 [Baymard filter UI](https://baymard.com/blog/ecommerce-filter-ui), [Baymard PLP](https://baymard.com/blog/product-listing-page-plp-ux), [W3C target size minimum](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum): contesto/recupero leggibili e controlli accessibili come riferimenti, non prova di conversione o conformita WCAG completa. Nessuna matrice redesign necessaria, nessuna nuova CSS o merceologia demo importata.

Verifiche: ricerca su funzione reale 40 PASS (prima del fix 14 failure su 38 controlli iniziali; successivamente due controlli del messaggio errore aggiunti), abort presente/assente, successo/errore fuori ordine, query breve, debounce/submit/Enter/esempi, zero-result e recovery q, fixture Tech/Food e output encoded. Handler Cerca e sei helper URL reali estratti/compilati in memoria .NET Framework con controlli WebForms reali e Response/contesto fake: 32 PASS, scope desktop/mobile, chip/reset/offerte/pid/ricondizionato e paginazione. Client carrello reale ai boundary sintetici: 70 PASS, id+TCId esatto, delta quantita, busy anti-duplicazione, risposta valida -> stato/card/header/MiniCart, stock 422, 503/indeterminate, rete/JSON invalido -> messaggio senza falso successo o svuotamento del carrello. Rendering MiniCart e servizio server restano boundary simulati, non acquisti verificati. Quattro viste su funzione JS reale con DOM sintetico: 32 PASS. Totale **174 controlli isolati**, non test e-commerce E2E, SQL engine o tenant commerciali reali.

Browser realmente usato: Codex In-app Browser, fixture statica dedicata su loopback effimero, solo markup della sezione ricerca estratto da Default.aspx, asset reali selezionati e fetch sostituito con risposte sintetiche; nessun IIS/DB. Viewport 360/390/430/768/1365: ricerca/Enter, risposta vecchia trattenuta e rilasciata dopo la nuova, query breve, zero/errori e link recupero verificati; nella fixture nessun overflow orizzontale e nessun errore JS inatteso. Non certifica l'intera HOME, header/menu, tutte le CSS/branding tenant, focus trap, screen reader o layout/storefront completo. Il gate browser applicativo e lo smoke HOME -> catalogo -> PDP -> carrello su IIS restano **NON ESEGUITI / B**, poiche il target esistente puo usare DB operativo e non c'e autorizzazione specifica a richieste/mutazioni. Nessuna richiesta IIS, Apply o fixture DB tentata.

Precompile safe .NET Framework 4.8 PASS: 353 input tracked, configurazione sintetica, zero copie di configurazione operativa, cleanup proprio PASS. Sintassi JS, diff-check, manifest, scan segreti delle aggiunte e preservazione locale PASS. Nessuna suite globale ripetuta. Performance circoscritta: debounce+submit passa da due richieste sintetiche a una, nessuna nuova query/per-card, nessun numero TTFB/LCP/INP dichiarato.

Manifest runtime esatto MODIFIED: `Default.aspx` (solo cache-buster `home-default.js`), `Public/assets/keepstore/js/home-default.js`; ADDED/DELETED/RENAMED runtime: nessuno. Documenti: START_HERE, PRODUCT_ROADMAP e questo Masterplan, nello stesso commit. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER**, non autorizzazione al caricamento: `C:\KeepStoreWeb\KeepStore3.0\Default.aspx` e `C:\KeepStoreWeb\KeepStore3.0\Public\assets\keepstore\js\home-default.js`. Nessuna nuova dipendenza App_Code/Bin; usare base server compatibile e verificare le dipendenze stabili #351/#352, incluso HomeServerStageTiming se non installato. Cache-buster REV1 `20261015-shopping-continuity1a-rev1`; nessun altro chiamante runtime di home-default.js rilevato.

Futuro smoke solo dopo autorizzazione: backup byte/hash dei due file target, installazione coerente del delta su base verificata, rollback dei due originali e verifica hash; preservare web.config/asset/App_Data e non applicare modifiche DB/IIS. Controllare ricerca rapida/query breve/errore e link catalogo, poi i soli percorsi applicativi autorizzati; nessuna pubblicazione automatica o acquisto/ordine/gateway/e-mail. Un commit coerente e PR DRAFT, A tecnico / B complessivo per review/smoke, nessun merge. Stable/main invariati, staging finale vuoto; configurazioni, quattro cancellazioni e 54 untracked autorizzati preservati con hash/inventario. Candidato successivo KS-B01 soltanto NON AVVIATO, dopo chiusura e decisione PO.

### CANONICAL-DOCS-REORG-1A — checkpoint prevalente 2026-10-15 / DOCS-ONLY

Base Git verificata: `frontend-rebuild` locale/origin = `b14113767d115e6b5596f0eab3c048c62928c751`; parent `e6831baaaf10d0ac689974437bf64b1a647d6b85`; main/origin/main `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariati. PR #351 e #352 integrate; #352 MERGED/CLOSED verificata su GitHub, sincronizzazione locale A acquisita e SHA confermati. `HOME-DB-OPEN-LATENCY-1A` CLOSED / A / INTEGRATED. Questo checkpoint supera lo stato DRAFT e i gate pendenti sotto, senza cancellare il rapporto del benchmark. La #352 contiene due commit originali, non merge commit; prestazioni misurate soltanto su Integration, non attestazione di deploy produzione.

Mandato PO 2026-10-15: ecommerce affidabile, moderno/premium, mobile e completo fino all'ordine prima di polish/performance non bloccanti/SEO avanzata/integrazioni. Sicurezza, pagamento e integrita commerciale/ordine restano gate di rilascio. Task attivo esclusivamente questa riconciliazione; nessun nuovo runtime autorizzato. Regole ONE-SHOT, LOCAL-FIRST, FEATURE-BATCH, ruoli, Design Gate e release sono consolidate in AGENTS, non ridefinite qui. Requisiti HOME adattiva/assistente e priorita vivono nella nuova roadmap; i dettagli AI/search nel relativo Blueprint. START_HERE contiene l'indice classificato dei documenti root/docs e i limiti degli snapshot IIS/pagamenti.

`HOME-TTFB-WARM-RESIDUAL-ATTRIBUTION-1A`: diagnosi read-only A, attribuzione al singolo componente B; campioni warm #352 con residui 3.228,240 / 3.261,403 ms (Taikun/Webaffare), ottenuti mediante unione degli span, non somma inclusiva. Finestre candidate: circa 0,94 s prima di Page.Init, 1,83 s fra callback Page.Load e PreRender, 0,47 s nei PreRender figli. Master/header/footer/carrello candidati, nessun costo singolo dimostrato. Strumentazione proposta NON IMPLEMENTATA e ora DIFFERITA; HEAD/cold separato e NON AVVIATO. Non riaprire #352 o ripetere benchmark. Helper `App_Code/HomeServerStageTiming.vb` integrato da #351, dipendenza runtime da includere nei pacchetti autorizzati se assente nel destinatario; diagnostica disattivata per default.

Riconciliazione pagamenti: il checkpoint 2026-09-23 sottostante e System Blueprint 5.8.1 attestano PayPal Orders v2 LIVE CONFIGURED / ENABLED e OAuth LIVE HTTP 200, NON pagamento reale end-to-end LIVE VERIFIED. Le sezioni NVP/Express, READY FOR LIVE CONFIGURATION e summary payment precedente sono snapshot storici, non la configurazione corrente. BancaSella mantiene gate proprio, non eredita il collaudo PayPal. Documenti gestionali Enzo e runbook restano riferimenti specialistici, con stato pannello/DB/deploy distinto. I limiti su password/hash, rollout carrello persistente, #342/#343/#345 e varianti/autenticato finale restano nella roadmap, non sono test promossi a PASS.

Manifest massimo nove documenti; nessun runtime/config cambiato. Un solo commit DOCS-ONLY e PR DRAFT sul branch `task/keepstore-canonical-docs-reorg-1a`, senza merge. Gate successivo: review documentale indipendente; nessun task runtime parte da questa consegna. Stato produzione per la #352 DA VERIFICARE, nessuna pubblicazione implicita.

## Archivio dei checkpoint e delle decisioni precedenti

**Nota di lettura prevalente:** tutto lo storico seguente e conservato integralmente. Stati task/PR/SHA e scalette si riferiscono alle rispettive date; non costituiscono task attivi o autorizzazioni. Per lo stato attuale usare START_HERE/Git, per priorita PRODUCT_ROADMAP e per metodo AGENTS. Contratti tecnici non sostituiti restano consultabili tramite System Blueprint/runbook; copie storiche di regole non sono seconde norme attive. In particolare le sezioni "Contratto operativo", "Roadmap sintetica" e "Prossimi step consigliati" non competono con le fonti canoniche nuove.

### HOME-DB-OPEN-LATENCY-1A — closeout Integration / A tecnico e prestazionale, PR #352 DRAFT non integrata

Review indipendente ChatGPT A sulla REV1 `e6831baaaf10d0ac689974437bf64b1a647d6b85`; smoke autorizzato concluso con **un solo Apply e sei GET HTTPS non mutative**, tre per tenant, rollback PASS. Questo checkpoint aggiorna il gate live pendente della REV1 sottostante, conservandone lo storico. Chiusura corrente esclusivamente documentale sul medesimo branch/PR: runtime invariato, nessun nuovo test, Apply, GET o benchmark. Stable locale/origin `9eaead27127ec39fdd6f54349ed6fd9243d8cfb9` e main/origin/main `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariati; merge NON eseguito, in attesa di autorizzazione finale FF-only.

Evidenze locali private rilette senza modificarle: `C:\Temp\KeepStoreIntegration\backups\home-db-open-pr352-20261015-093408-6090a743`, in particolare `sanitized-comparison-summary.json`, metriche HTTP, sei tracce server, collegamenti richiesta/traccia, recovery, controlli HTML e `rollback-receipt.json`. Sei HTTP 200, TLS verificato su loopback :18443 con hostname/SNI corretti, zero redirect, canonical PASS. Correlazioni tenant/campione/requestId distinte per aziende 1 (Taikun) e 2 (Webaffare); 30 recovery events, cinque per richiesta fino a trace_written, **zero entry scartate**. Ogni traccia contiene una Open e dieci Fill nei loader HOME strumentati: **10 -> 1 Open, nove aperture evitate**, non una sola connessione per l'intera richiesta/master/provider.

Medie campioni 2-3 di ciascun tenant, millisecondi; prima = baseline storica #351, dopo = smoke #352:

| Tenant | Open prima -> dopo | TTFB prima -> dopo | Riduzione TTFB osservata |
| --- | --- | --- | --- |
| Taikun | 4.334,662 -> 439,550 | 9.638,166 -> 5.470,462 | 43,24% |
| Webaffare | 4.196,145 -> 427,759 | 9.514,302 -> 5.498,777 | 42,21% |

Il confronto e storico, NON un esperimento simultaneo controllato: il calo e coerente con nove Open evitate, ma non attribuisce causalmente alla patch tutte le differenze di TTFB/Fill, dati, cache o carico. Le osservazioni commerciali ordinate dei tre nuovi campioni coincidono per ciascun tenant (88 record attributi Taikun, 64 Webaffare; non conteggi di prodotti unici); **parita commerciale completa con la baseline storica NON certificata**, mancando uno snapshot HTML storico equivalente. I campioni iniziali restano separati: 16 HEAD per tenant, circa 24,4 s, TTFB iniziale 46,104 s Taikun / 31,431 s Webaffare. Tempi HTTP e pageObserved hanno confini distinti; nessuna spiegazione inventata per il loro scarto iniziale. Residuo warm non attribuito circa 3,2 s (3.228,240 / 3.261,403 ms): finding distinto, NON AVVIATO, come l'attesa HEAD iniziale.

Rollback documentato PASS: inventario del rapporto di esecuzione **1.117 file non diagnostici identici**, esclusi soltanto i due log diagnostici locali conservati. Ricevuta e hash correnti ricontrollati in sola lettura: Integration `web.config` SHA-256 `70B58D9DA3C363E1AAE305DE73E886F4EB9C2B43230942B7CB40383CD8A661E3`; `Default.aspx.vb` originale SHA-256 `6667E6E817A8A2933B04B0D0C8A478C67A23585F8969DDD2149C4C005DCA6F72`; helper temporaneo `App_Code/HomeServerStageTiming.vb` nuovamente assente, flag diagnostici rimossi secondo il rapporto/backup. L'inventario completo e attestato dal confronto del ciclo smoke, non ricostruito retroattivamente da una nuova baseline. Backup e prove rimangono privati fuori Git.

`Pooling=false` conservato; nessuna attivazione Connection Reset, modifica provider, SQL, carrello o configurazioni permanenti. Nessun intervento su KeepStoreSmoke/:8443, produzione o IIS permanente. Nessuna scrittura DB invocata dal percorso autorizzato; non e una certificazione indipendente mediante audit del server DB. Working copy: web.config, quattro cancellazioni tracked e 54 untracked protetti; staging del solo Masterplan. Nessun deploy produzione, merge o task successivo. Il manifest cumulativo PR resta `Default.aspx.vb` e questo documento; i 211 test e la precompile gia PASS non vengono ripetuti.

### HOME-DB-OPEN-LATENCY-1A / REV1 — connessione HOME request-scoped, A tecnico / B complessivo

Base stabile `9eaead27127ec39fdd6f54349ed6fd9243d8cfb9`, stesso branch `task/home-db-open-latency-1a`; frontend-rebuild locale/origin e main/origin/main invariati. REV architetturale esplicitamente autorizzata dal Product Owner: sostituisce la proposta configurativa e il gate di revisione del reset sotto, senza cambiare provider/carrello o autorizzare pooling globale. La diagnosi precedente, gia presente localmente, e conservata integralmente come evidenza storica. Manifest esclusivo: `Default.aspx.vb` e questo Masterplan.

Call graph verificato: BindHome sincrono -> due letture banner tramite SafeTableQuery -> sette pool prodotti tramite TryLoadProducts -> lettura marche tramite SafeTableQuery; recenti/fallback possono aggiungere SELECT nel medesimo perimetro secondo i dati, senza una nuova apertura quando la connessione resta valida. Le query candidate sono SELECT sequenziali, senza SET SESSION/variabili utente, transazioni, DML, procedure o reader lasciati aperti. Provider menu/promo/master mantengono le loro connessioni e restano fuori modifica: **una apertura dei percorsi strumentati**, non una sola apertura dell'intera richiesta IIS.

Ownership: due campi privati di istanza Page delimitano soltanto BindHome; guard contro scope annidati, apertura lazy al primo accesso, nessun Shared/Static/Session/Application/Cache/singleton. Ogni query conserva il proprio command, parametri, DataAdapter e DataTable in Using. La lease prende in prestito la connessione del BindHome senza disporla al termine della query; fuori dal BindHome possiede una nuova connessione e mantiene il rilascio per singola chiamata. Il Finally di BindHome disattiva il perimetro, scollega il riferimento e tenta Close e Dispose anche se binding, Open, Fill o cleanup falliscono. Diagnostica cleanup soltanto a messaggi fissi, senza dettagli connessione, SQL, credenziali o eccezioni grezze aggiunti.

Failure: il Catch originale conserva log/fallback, ma invalida prima l'owner della richiesta. Connessione non Open, query fallita, Fill o Dispose adapter falliti non vengono riusati; solo una query successiva puo creare un nuovo owner. Nessun retry interno o ciclo di reconnect. Cleanup best-effort tenta sempre Dispose anche dopo Close fallito; il riferimento incerto viene rimosso prima dei tentativi e non rimane nella pagina. Il guard reentrancy non chiude l'owner del BindHome gia attivo. Errore applicativo del binding preservato senza essere mascherato dagli errori cleanup.

Strumentazione #351 invariata: ogni Open realmente tentato e' misurato con il nome stage esistente, nessuno span Open sintetico per il riuso; Fill e callback conservati. Nel caso riuscito corrispondente ai dieci accessi baseline: **10 -> 1 Open**, dieci Fill, una connessione disposta alla fine. Zero query -> zero Open. Errori o connessione non valida possono produrre piu aperture reali, registrate senza una garanzia fittizia di una sola Open in errore. Beneficio atteso: nove aperture evitate; NON un TTFB migliorato o un risparmio di 3.8 s gia misurati.

**211 controlli dinamici sintetici PASS**, .NET Framework/VB con helper di ownership e metodi SafeTableQuery/TryLoadProducts estratti dal sorgente reale, perimetro Try/Finally reale del BindHome e callback commerciali sostituiti da fixture. DAL in memoria, zero DB/HTTP: dieci query -> un Open/un Dispose; apertura lazy; richieste e tenant/listini sintetici distinti, anche concorrenti; seconda chiamata BindHome e percorso esterno con owner nuovi; primo Open fallito, errore persistente senza retry, Fill fallito alle posizioni 1/5/10, fallback SafeTable identico, risultati vuoti, stato Closed/Broken imprevisto, Dispose adapter fallito, eccezione binding, doppio errore Close/Dispose e scope annidato. Parita candidate/base di schema/ordine/valori delle tabelle fixture, SQL/ordine/parametri/tipi, chiamate promo e lifetime dei dieci command/adapter. Il DAL fake non certifica connessioni TCP, isolamento MySQL live, engine SQL o prezzi reali; i provider commerciali non sono stati sostituiti nel runtime.

Verifiche statiche: **167 metodi preesistenti non interessati invariati**, inclusi overload; corpo commerciale BindHome e costruzione SQL TryLoadProducts identici alla base, nessun accesso asincrono/parallelo aggiunto alla connessione. Precompile ASP.NET Framework 4.8 safe PASS, 353 input, configurazione sintetica, zero copie di configurazioni operative, cleanup della sola directory temporanea PASS. Diff-check, manifest e scan segreti delle aggiunte PASS. Test #351 e benchmark storici riutilizzati, non ripetuti.

Configurazioni intatte: Pooling=false resta prerequisito del deploy, Connection Reset non attivato, timeout/TLS/DLL/credenziali invariati; web.config non versionato in questa REV. Helper HomeServerStageTiming, carrello, HEAD/cache asset, ordine dei pool/deduplica/listino/IVA/prezzi/promo/stock/TCId non modificati. File locali protetti: web.config, quattro cancellazioni e 54 untracked conservati con hash/inventario verificati; Integration/runtime/runner precedenti invariati. Un solo commit REV1 e push normale del task, PR DRAFT verso frontend-rebuild; nessun merge.

Gate successivo: review indipendente della PR, poi NUOVA autorizzazione specifica a smoke/benchmark Integration con backup privato, runtime/hash verificati, diagnostica #351, Pooling=false confermato, massimo sei GET non mutative e rollback byte-per-byte. Confrontare Open/Fill/pageObserved/TTFB dei campioni successivi al primo per ciascun tenant; dichiarare differenze di release/dati/cache e non attribuire alla REV prime HEAD/warm-up o residui non strumentati. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER, solo dopo i gate: `Default.aspx.vb`**. L'helper diagnostico e gia stabile e non appartiene al manifest modificato. Nessun Apply, GET, DML/DDL, IIS, produzione, deploy o task successivo eseguito in questa REV; gate complessivo B fino alla prova live autorizzata.

### HOME-DB-OPEN-LATENCY-1A — diagnosi configurazione confermata / B sul gate di sicurezza pooling

Base esatta `9eaead27127ec39fdd6f54349ed6fd9243d8cfb9`, PR #351 verificata MERGED/CLOSED, frontend-rebuild locale/origin allineati; branch `task/home-db-open-latency-1a` creato dalla base, main/origin/main `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariati. Il checkpoint #351 sottostante e storico pre-merge; le evidenze REV2 restano valide e non sono state ripetute.

Nuova evidenza locale read-only: `Pooling=false` sia nel web.config versionato sia nella configurazione Integration caricata tramite WebConfigurationManager con mapping del sito. Provider `MySql.Data.MySqlClient`; DLL Bin Integration `MySql.Data 8.0.33.0`, SHA-256 `83AB8FA1EF25C37460B394CEE9BC24E56DF24F8F659BB8F449240C75F2975EF4`. Connection Reset non esplicitato, default effettivo **false** confermato dal builder della DLL installata; pooling default del builder true, ma sovrascritto dalla configurazione. Nessuna connection string, identita/credenziale DB o confronto di credenziali in chiaro pubblicato; nessuna connessione DB aperta. Configurazione Integration invariata SHA-256 `70B58D9DA3C363E1AAE305DE73E886F4EB9C2B43230942B7CB40383CD8A661E3`.

Le dieci aperture STRUMENTATE per campione #351 appartengono a due letture banner, sette QueryProducts (deals, featured, new arrivals, top rated, bestseller, current year, fallback) e una lettura marche. Connessioni/command/adapter sono racchiusi in Using in QueryProducts e SafeTableQuery. Il pool top-selling viene copiato dal bestseller nel percorso valido #345. Dieci span non equivalgono al numero totale di connessioni di master/controlli/provider, non interamente strumentati, ne a dieci nuove connessioni TCP misurate. Pooling disabilitato e una causa candidata forte dei circa 4.2-4.3 s di Open nei campioni successivi; causalita e beneficio restano NON MISURATI.

**F01 BLOCKER / SAME-TASK CANDIDATE:** non attivare semplicemente Pooling=true. CartTransactionRetryPolicy imposta `SET SESSION innodb_lock_wait_timeout = 5` a ogni tentativo e rilascia la connessione nel Finally, senza ripristinare tale variabile; pertanto Connection Reset=false consentirebbe di conservare stato di sessione. LAST_INSERT_ID del carrello e invece letto sulla medesima connessione/transazione dell'INSERT, non richiede persistenza attraverso una riapertura. Le identita tenant/listino rimangono applicative e non sono sostituite dall'identita del pool/database.

Connection Reset=true e supportato, ma nel provider 8.0.33 emerge un ramo non dimostrato fail-closed: MySqlPool.GetPooledConnectionAsync intercetta l'eccezione di Driver.ResetAsync, esegue ClearAsync e puo proseguire con il driver corrente non azzerato. ClearAsync marca il pool in dismissione e chiude gli idle rimasti, non certifica l'eliminazione del driver gia estratto. Conferma statica anche nel MoveNext della DLL installata: ResetAsync IL 604, catch System.Exception 709, ClearAsync 739, driver letto nuovamente 843; nessun azzeramento/rilancio tra gestione del reset e successivo controllo del driver. Il reset nativo di questa versione usa CHANGE_USER/ri-autenticazione, non va confuso con un COM_RESET_CONNECTION senza autenticazione. Nessun reset fallito o contaminazione reale riprodotti sul DB operativo; questa e evidenza del contratto di errore, non un incidente cross-tenant dichiarato.

Fonti primarie: [Oracle pooling](https://dev.mysql.com/doc/connector-net/en/connector-net-connections-pooling.html), [opzioni Connection Reset](https://dev.mysql.com/doc/connector-net/en/connector-net-8-0-connection-options.html), [MySqlPool 8.0.33](https://github.com/mysql/mysql-connector-net/blob/8.0.33/MySQL.Data/src/MySqlPool.cs), [NativeDriver 8.0.33](https://github.com/mysql/mysql-connector-net/blob/8.0.33/MySQL.Data/src/NativeDriver.cs). Reset/ping comportano round trip, quindi non si promette l'azzeramento del costo Open. Pool e sessione server condivisi non sostituiscono i guardrail host/tenant/listino.

**17 controlli offline PASS**, limitati a parsing pooling/reset, alias, valori/default validi, provider/opzioni invalidi, modifica in memoria delle sole due opzioni, conservazione di timeout/pool size/lifetime e metadati sintetici distinti. Non provano riutilizzo/reset reale, isolamento sessione server o prezzi di due tenant. Ispezione configurazione/IL senza Open/SQL. Sintassi script, diff-check e manifest documentale verificati; nessuna suite diagnostica #351 ripetuta e nessuna precompile necessaria per runtime invariato.

Gate sicurezza **B** prima della preparazione di un Apply: il solo Connection Reset=true non garantisce il ramo di errore richiesto. Plan operativo non dichiarato PASS, runner #351 preservato e non eseguito; nessun nuovo runner Apply predisposto per ignorare il finding. Proposta configurativa solo condizionale: Pooling=true + Connection Reset=true, temporanei su Integration con due flag diagnostici #351, backup privato byte-per-byte/rollback, massimo sei GET e confronto dei campioni successivi; NON ESEGUITA. Occorre risolvere/certificare il contratto fail-closed del reset con una REV esplicitamente autorizzata prima del successivo gate autorizzazione Apply; cambiare provider/versione o aggiungere un workaround non e autorizzato qui.

Nessun Apply, GET, apertura DB, DML/DDL, cambio IIS, deploy, nuovo commit/push/PR o merge. Solo questo checkpoint locale autorizzato; staging vuoto, web.config canonico/quattro cancellazioni/54 untracked preservati. Credenziale presente nel web.config versionato: finding separato gia segnalato, nessun valore esposto e nessuna rotazione/rimozione effettuata. HEAD/asset iniziali e residui non attribuiti restano fuori scope. STOP B, nessun task successivo avviato.

### HOME-TTFB-SERVER-STAGE-TIMING-1A — chiusura evidenze REV2 / A tecnico e documentale, PR DRAFT non integrata

Smoke eseguito sul commit REV2 `d50fb5ab111ff0d0ab90158fac298e514c3953b4`, review indipendente runtime A acquisita. Chiusura DOCS-ONLY sullo stesso branch/PR #351, parent documentale REV2; stable `3adb97a461ff7407bed8839685a5f6f2e1d3fc64` e main/origin/main `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariati. Questa nota prevale sui gate pre-smoke sottostanti. PR OPEN/DRAFT, nessun merge autorizzato da questa chiusura.

Fonte obbligatoria riletta in sola lettura: `C:\Temp\KeepStoreIntegration\backups\home-stage-timing-20261014-170606-07f951e8`. Esattamente sei metriche, sei trace JSON e 30 record recovery: tre richieste sequenziali Taikun/companyId 1 e tre Webaffare/companyId 2, sample 0/1/2 per tenant, GUID univoci, HTTP 200 sia client sia trace, zero entry scartate. Ogni GUID ha activation_entered -> activation_passed -> tenant_validated -> completion_entered -> trace_written; companyId 0 prima della validazione, poi tenant atteso, stesso fingerprint applicativo validato. Trace schema home-stage-timing-v1/recovery home-stage-status-v1. Canonical, TLS e loopback PASS nel transcript runner del medesimo smoke; non ricertificati con nuove richieste. La serializzazione sanitizzata delle metriche non conserva campi curl TLS/canonical: distinguere tale limite dalle correlazioni verificabili nei file.

Misure confermate rispetto al rapporto precedente, in **ms**; campione 1 = sample 0/inizializzazione per tenant, campioni 2-3 successivi. 72 entry nei primi campioni, 56 nei successivi, nessuna entry persa. Prima richiesta dopo installazione/configurazione, cache fredda globale NON certificata.

| Tenant/campione | TTFB ms | Totale ms | pageObservedMs | requestId diagnostico |
| --- | ---: | ---: | ---: | --- |
| Taikun 1 | 52346.158 | 52348.126 | 37197.225 | `c035408aaf4d48029d349a4ab57191f3` |
| Taikun 2 | 9600.227 | 9603.705 | 9582.643 | `50f40e4cd2114a129c5797d739a7edb5` |
| Taikun 3 | 9676.105 | 9677.554 | 9640.591 | `867326ea85b24171a65ef8d77b197fde` |
| Webaffare 1 | 35562.537 | 35583.492 | 35550.495 | `8183b4a2c7294ce0a4de03bee6a75e1c` |
| Webaffare 2 | 9502.302 | 9522.333 | 9479.453 | `acc5741350e246e1bc57047d92d6d71b` |
| Webaffare 3 | 9526.302 | 9539.979 | 9504.541 | `b5b7db52cce14120b89964706bc3b717` |

Conteggi e somme ricavati dai soli span corrispondenti: **10 Open, 10 Fill, 13 DataBind e 1 Render per campione**. HEAD 16 nei primi campioni, 0 nei successivi. Verificata non sovrapposizione degli intervalli all'interno di ciascuna categoria sommata; non aggiungere a queste somme i parent inclusivi home.bind/pool/page.load/home.brands.

| Tenant/campione | Open ms (10) | Fill ms (10) | HEAD ms (n) | DataBind ms (13) | Render ms (1) | Fuori callback top-level ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Taikun 1 | 4135.546 | 1538.348 | 24352.109 (16) | 99.784 | 62.210 | 5760.524 |
| Taikun 2 | 4295.026 | 1551.473 | 0.000 (0) | 16.559 | 8.270 | 3213.310 |
| Taikun 3 | 4374.297 | 1522.619 | 0.000 (0) | 10.493 | 4.821 | 3241.157 |
| Webaffare 1 | 4293.229 | 1527.872 | 24405.035 (16) | 6.765 | 11.922 | 4835.716 |
| Webaffare 2 | 4162.369 | 1543.572 | 0.000 (0) | 10.810 | 13.186 | 3266.147 |
| Webaffare 3 | 4229.920 | 1533.695 | 0.000 (0) | 7.238 | 4.380 | 3232.488 |

Diagnosi limitata alle evidenze: nei quattro campioni successivi Open 4162.369-4374.297 ms e Fill 1522.619-1551.473 ms; media Open Taikun 4334.662 ms/Webaffare 4196.145 ms. Open e' la prima priorita persistente identificata, NON prova di pooling disabilitato, dieci connessioni TCP fisiche nuove o errore MySQL. Fill comprende attesa DB/rete e materializzazione client, NON solo esecuzione SQL. DataBind 7.238-16.559 ms e Render 4.380-13.186 ms nei successivi, quindi non prioritari. Prime HEAD 24352.109/24405.035 ms; home.brands.resolve inclusivo 24870.990/24881.529 ms, da NON sommare alle HEAD/DB. Nei successivi home.brands.resolve 434.770-451.608 ms e zero HEAD. Cold/startup e cache per tenant restano distinti dalla latenza persistente; nessun miglioramento prima/dopo o percentuale causale attribuito alla #345 o alla diagnostica.

Residui: pageObservedMs meno copertura dei sei callback/span top-level non sovrapposti lascia 3213.310-3266.147 ms nei successivi, NON attribuiti a uno specifico componente. Principali intervalli tra callback successivi: circa 0.90-0.97 s tra PreInit e Init, 1.81-1.85 s tra termine Load e PreRender, 0.46-0.47 s tra PreRender e Render; non sono automaticamente costo del metodo precedente o seguente. Primo Taikun: TTFB - pageObservedMs = 15148.933 ms; differenza tra intervalli/client-clock e server-clock con estremi differenti, NON misura separata del pre-PreInit e NON prova di compilazione/IIS/rete. pageObserved termina a Unload prima della scrittura timing, non copre EndRequest o richiesta completa. Overhead diagnostico non misurato separatamente e confronto con baseline circa 9.2 s non controllato.

Integrita evidenze (SHA-256):

- `sanitized-http-metrics.jsonl`: `52299F30BEDC938F21A1B31AA85D1552009DDD97F58FCB4212A17504D0A33D97`.
- `sanitized-recovery-status.jsonl`: `70BBFF02E2D64221BBFF8EAC6249ED3AE7C73E0A3A6D785922AA0CCC40A5CCA6`.
- `sanitized-server-timing.log`: `17679FD07A55B6469DE463E4573FF38CDB6E3E9552A5CA410A002265B2133A7D`.

Rollback obbligatorio PASS nel transcript Apply e confermato dai backup/file finali, senza nuovo Apply: Default.aspx.vb SHA-256 `6667E6E817A8A2933B04B0D0C8A478C67A23585F8969DDD2149C4C005DCA6F72`, web.config SHA-256 `70B58D9DA3C363E1AAE305DE73E886F4EB9C2B43230942B7CB40383CD8A661E3`, entrambi byte-per-byte corrispondenti ai backup. Helper Integration originariamente assente, finalmente assente; due flag rimossi/diagnostica OFF. Non esiste una ricevuta rollback separata nel backup: attestazione nel transcript, corroborata dagli hash e dal controllo finale. Solo i due log diagnostici privati sono stati creati/aggiornati dallo smoke e conservati intenzionalmente; nessuna modifica runtime/configurazione/IIS permanente.

Chiusura: nessuna nuova GET/Apply/test, nessuna modifica runtime/runner/Integration/SQL/DB/produzione, nessuna nuova PR/merge. Un solo commit documentale di questo Masterplan e push normale nella PR #351 DRAFT; file runtime invariati rispetto alla REV2, web.config canonico/quattro cancellazioni/54 untracked preservati e staging finale vuoto. Gate successivo: review indipendente del checkpoint/evidenze e autorizzazione specifica a eventuale FF-only. Prossima priorita performance: diagnosi mirata del costo MySqlConnection.Open(), **NON AVVIATA**; HEAD e residui restano separati, nessuna ottimizzazione simultanea o nuovo caching implicitamente autorizzati.

### HOME-TTFB-SERVER-STAGE-TIMING-1A / REV2 — completion senza Page.Response in Unload, A tecnico / B complessivo

Stesso branch e PR #351 OPEN/DRAFT, parent REV2 `5f1ced30506b3c71818a3f7ac04fc06b20c6f120`; stable `3adb97a461ff7407bed8839685a5f6f2e1d3fc64` e main/origin/main `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariati. Questa nota prevale sul gate storico REV1 sotto. Ultimo Apply autorizzato sulla REV1: **1/6 GET**, Taikun HTTP 200/TLS/canonical PASS, TTFB 51,761563 s e total 51,763173 s conservati; altre cinque GET NON ESEGUITE. Recovery `activation_entered -> activation_passed -> tenant_validated -> completion_not_reached`, nessun timing completo. Prima richiesta post-installazione, NON confronto con baseline calda 9,2 s, nessuna fase SQL/server dominante ancora attribuita. Evidenze private in `C:\Temp\KeepStoreIntegration\backups\home-stage-timing-20261014-162142-1dd51570`; rollback PASS: Default/config originali identici, helper assente, flag rimossi, solo recovery privata conservata.

Causa dimostrata e acquisita dal Product Owner: il framework azzera `Page._response` in ProcessRequestCleanup PRIMA di UnloadRecursive; la valutazione di `Response.StatusCode` nell'argomento di Complete genera `Response_not_available`, intercettata dal Catch, senza entrare in Complete. Nessun nuovo audit IIS, permessi o SQL necessario. Manifest REV2 esclusivo: `Default.aspx.vb` e questo Masterplan; `App_Code/HomeServerStageTiming.vb` invariato byte-per-byte.

Correzione minima: campo Integer privato request-scoped inizializzato/reset a **0**, sentinella esplicita **status non osservato**, NON HTTP 200. Solo con recorder attivo e al termine di Render riuscito, acquisire il Page.Response.StatusCode ancora disponibile, accettando 100..599. Acquisizione fallita, valore fuori range, Render non raggiunto/fallito o recapture fallita mantengono 0. OnUnload passa soltanto il campo a Complete nel Finally, senza leggere Page.Response; preservati output/status effettivo, callback commerciali ed eccezioni applicative originali. Il valore registrato e' lo status OSSERVATO al termine del rendering, non una certificazione dello status finale dopo eventuali moduli IIS successivi. Helper, schema timing/recovery, gate Integration/HTTPS/loopback, OFF per default e budget esistenti invariati. Nessuna modifica a pool/SQL/prezzi/promo/stock/tenant/SEO/cache #345 o runner.

**79 nuovi controlli mirati sintetici PASS**: metodi Render/OnUnload estratti dal sorgente aggiornato, base lifecycle sintetica e helper reale; status 100/200/206/301/403/421/500/503/599, 0/600, Response rimossa prima di Unload, acquisizione fallita, assenza Render, errore applicativo Render/Unload, finally completion, nuova acquisizione fallita senza riuso del vecchio 200, due tenant sintetici, OFF/no getter/no output alterato. Verifica esatta di tutti gli statement HOME commerciali rispetto al parent e blob helper invariato. Nessuna certificazione IIS da questi test; i 192+64 precedenti non ripetuti. Precompile ASP.NET Framework 4.8 safe PASS (353 input, configurazione sintetica, zero copie operative, cleanup PASS), diff-check/manifest/secret scan PASS.

REV2: un solo commit e push normale sul branch esistente, nessuna nuova PR o merge. Integration, runner locale, configurazioni, web.config canonico, quattro cancellazioni e 54 untracked preservati; staging finale vuoto. **Nessun Apply, GET, installazione runtime, modifica IIS/DB, deploy o task successivo. FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER, dopo review e nuova autorizzazione:** cumulativo PR `Default.aspx.vb` e `App_Code/HomeServerStageTiming.vb` (helper identico alla REV1). Il runner resta intenzionalmente vincolato allo SHA REV1 e non e' stato modificato/eseguito: il futuro smoke richiede autorizzazione e allineamento al nuovo SHA revisionato, non un bypass. Unico gate successivo: review indipendente REV2, poi smoke Integration autorizzato con backup/rollback e misure complete. Gate complessivo B fino a tale prova.

### HOME-TTFB-SERVER-STAGE-TIMING-1A / REV1 — osservabilita del blocker, A tecnico / B complessivo

Stesso branch e PR #351 DRAFT, HEAD iniziale `74c7f0f0b683da1505965c5fe48b6c33c12a1d64`; stable `3adb97a461ff7407bed8839685a5f6f2e1d3fc64` e main/origin/main `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariati. Questa nota aggiorna il gate Integration; il checkpoint tecnico originale sotto resta storico. Un solo Apply autorizzato ha eseguito **1/6 GET**, Taikun HTTP 200/TLS/canonical PASS, poi `ItemNotFoundException` in MEASURE per `home-stage-timing.log` assente. Le altre cinque GET NON ESEGUITE; TTFB/total della prima GET non conservati, nessuna durata server/gap disponibile. Rollback PASS verificato indipendentemente: Default/config originali identici, helper nuovamente assente e due flag rimossi. Il permesso NTFS Modify non dimostra una scrittura. La causa originaria resta NON DIMOSTRATA; nessuna attribuzione a SQL/DB o beneficio prestazionale.

Diagnosi statica mirata: il runner richiede **`/Default.aspx`, NON `/`**, coerente col gate `~/Default.aspx`; nessuna estensione del gate al percorso root. Tenant validato viene passato a SetCompany nel Page_Load; Complete resta nel Finally di OnUnload. Il percorso atteso del runner e' App_Data/Logs della stessa applicazione, ma il runtime effettivamente eseguito non e' certificato dalla sola risposta 200. I Catch originali non esponevano rifiuti/errori. Difetto runner dimostrato: Get-Content della traccia precedeva la conservazione dei tempi curl. Inoltre una lettura immediata non attendeva la completion server-side; race possibile, NON dichiarata causa del primo fallimento. Il preflight parent originale non era compatibile con un successivo commit REV1.

Manifest effettivo REV1: solo `App_Code/HomeServerStageTiming.vb` e questo Masterplan; `Default.aspx.vb` identico al blob originale, nessuna modifica agli statement HOME/SQL/pool/ordine/prezzi/promo/tenant/SEO/cache #345. Recupero privato `App_Data/home-stage-timing-status.log`, indipendente dal file timing sotto Logs: due flag amministrativi originali, Integration, HTTPS e peer loopback verificati PRIMA di ogni record, OFF per default, nessuna attivazione via input pubblico e nessun corpo/header HTTP. Codici fissi per attivazione/path, tenant, completion, serializzazione, scrittura e budget; callback AddOnRequestCompleted osserva completion non raggiunta senza mutare la risposta. Solo schema/revisione, GUID diagnostico, UTC, codice, tenant numerico e fingerprint SHA-256 del root applicativo normalizzato; niente path in chiaro, URL, SQL, parametri, messaggi eccezione, utenti/sessioni/cookie. Limiti: otto record recovery/request e 256 KiB sul file recovery; timing originale 192 entry/request e 4 MiB. Nessun fallback pubblico: se codice/gate non vengono raggiunti o entrambi i sink privati falliscono, l'assenza resta evidenza insufficiente, NON prova di una causa. Overhead diagnostico live NON MISURATO.

Runner locale `C:\Temp\Invoke-KeepStoreHomeTimingIntegration.ps1` corretto dopo backup byte-per-byte della versione originale SHA-256 `9E399426D557552C46AC0DDF4BD3272907E79326935412BE76ED684BE1A9E03B`. Diff limitato a: preflight per originale/REV1 lineare e manifest, controllo flag salvati, metriche HTTP sanitizzate persistite PRIMA dei controlli traccia, assente/vuoto/non aggiornato/troncato/concorrenza distinti, attesa di soli file fino a 3 s senza retry GET, stato recovery allowlisted e correlazione GUID/tenant/root. Destinazioni, sei GET massime, TLS, backup/rollback e divieti immutati. Script esterno al repository, soggetto a review indipendente separata; prepararlo NON autorizza Apply.

**64 nuovi controlli sintetici REV1 PASS**: gate, percorso esatto runner, default OFF/no output, due tenant sintetici, lifecycle/correlazione, fingerprint, tenant non validato, completion omessa simulata, serializzazione e scrittura fallite, due sink falliti non bloccanti, limiti, stati runner assente/vuoto/stale/concorrenza, allowlist e conservazione metriche senza log; sintassi script e blob HOME invariato. I test non sono richieste IIS e non certificano la callback IIS in esecuzione; i 192 controlli precedenti non ripetuti. Precompile ASP.NET 4.8 safe PASS (353 input sintetici, zero copie operative, cleanup PASS); diff-check/manifest/secret scan PASS. Integration e :8443, configurazioni, DB, stable/main, web.config locale, quattro cancellazioni e 54 untracked preservati. Nessuna GET, nuovo Apply, installazione runtime, attivazione flag, restart, DML/DDL, merge o task successivo eseguito nella REV.

**FILE PRONTI PER REVIEW CHATGPT:** helper REV1 e runner locale; runtime cumulativo della PR: `Default.aspx.vb` e `App_Code/HomeServerStageTiming.vb`. Non copiare/attivare ora. Unico gate successivo: review indipendente del commit REV1 e del runner, poi NUOVA autorizzazione Product Owner per smoke temporaneo con backup/rollback. PR #351 resta OPEN/DRAFT e gate Integration B.

### HOME-TTFB-SERVER-STAGE-TIMING-1A — checkpoint originale A tecnico, B complessivo: attivazione Integration e misure live pendenti

Base `3adb97a461ff7407bed8839685a5f6f2e1d3fc64`, branch `task/home-ttfb-server-stage-timing-1a`; main/origin/main invariati. PR #350 verificata MERGED/CLOSED e working copy riallineata: il checkpoint pre-merge sotto resta storico. HOME-TTFB-PERFORMANCE-VERIFY-1A chiuso A limitatamente alla baseline HTTP, NON all'ottimizzazione della latenza. Cinque misure per tenant: TTFB Taikun 10,748/9,180/9,197/9,133/9,225 s (mediana 9,197), Webaffare 9,263/9,192/9,221/9,224/9,124 s (mediana 9,221). Corpi HTML 887.979 e 767.667 byte; tempo totale mediano 9,199 e 9,223 s, HTTP 200/canonical corretti. Warm-up Webaffare 34,893 s; misura warm-up Taikun non conservata per errore del runner, prima misura Taikun con sessione nuova e Webaffare gia inizializzata. Cache fredda non certificata; nessun confronto prima/dopo o beneficio percentuale attribuito alla #345. I due tenant NON sono una coppia di confronto prestazionale della patch.

Manifest minimo definito prima delle modifiche: `App_Code/HomeServerStageTiming.vb`, `Default.aspx.vb` e questo Masterplan. Diagnostica request-scoped con Stopwatch.GetTimestamp/Frequency, GUID diagnostico indipendente da sessione/carrello e tenant numerico derivato dal PriceDisplayContext server-side validato. Misure inclusive/nesting espliciti: callback PreInit/Init/Load/PreRender, marker PreRenderComplete/SaveStateComplete, Render e Unload; BindHome, singoli pool, DataBind, apertura connessioni e DataAdapter.Fill; risoluzione marche e HEAD di verifica asset quando effettivamente eseguita. Fill include attese rete/DB e materializzazione client: NON e solo tempo SQL. Marker/offset permettono di vedere intervalli tra eventi, ma non attribuiscono automaticamente i gap a un componente. Non sommare span inclusivi annidati. Attesa IIS/TLS/compilazione anteriore a PreInit, dettaglio dei resolver commerciali condivisi, EndRequest e tempi SQL interni NON misurati; pageObservedMs finisce a Unload prima della scrittura del log, NON equivale a TTFB o richiesta server completa.

Spenta per default. Attivazione esclusivamente mediante appSettings amministrativi `KeepStore.Diagnostics.HomeStageTiming.Enabled=true` E `KeepStore.Diagnostics.Environment=Integration`, piu GET della HOME, HTTPS e peer loopback effettivo; nessun query/header/cookie puo attivarla. Nessuna modifica a web.config in questo task. Log esclusivamente in App_Data/Logs/home-stage-timing.log, senza output/header HTTP, SQL/parametri, URL, cookie, sessioni, utenti o eccezioni; massimo 192 entry/request e stop scrittura a 4 MiB. Request senza tenant validato non scrive. Errori diagnostici/logging non alterano HTTP; nessuna cache persistente, mutazione DB o cambio ai contratti commerciali. Gli stessi statement/query/ordine originali restano invariati, inclusa la copia bestseller #345.

**192 controlli mirati sintetici PASS**: matrice flag/ambiente/localita/HTTPS/metodo/path, query di attivazione ininfluenti con flag assente, disabilitazione/no output, due tenant sintetici, correlazioni separate, clock monotono, durate inclusive/depth, disposal/completion idempotenti, label unsafe rifiutate, no dati sensibili, budget e fallimento logging non bloccante. Verifica integrale degli statement HOME originali dopo esclusione dei soli hook/wrapper diagnostici e separazione dichiarazione/assegnazione; nessuna query o ramo commerciale alterato. Precompile ASP.NET Framework 4.8 safe PASS (353 input, configurazione sintetica, zero copie operative e cleanup PASS), diff-check/manifest/secret scan PASS. Nessuna ripetizione dei 526 test #345, 153 test catalogo o benchmark precedente. Overhead live e parita HTML reale NON MISURATI in questo task.

**MISURE SERVER LIVE NON ESEGUITE; nessuna fase dominante o causa dei 9,2 s ancora determinata.** Integration disponibile, ma il runtime diagnostico e i due flag non sono installati/attivati: le precedenti autorizzazioni temporanee per #350 e HOME stable non sono estese implicitamente al nuovo deployment/configurazione. Predisposta una sola procedura locale Integration con verifica blob, backup Default/helper/config, attivazione limitata, sei GET sequenziali complessive sui due tenant, log sanitizzato e rollback/hash; Apply richiede autorizzazione esplicita. Nessuna modifica IIS, Integration, DB o produzione eseguita ora. Web.config, quattro cancellazioni e 54 untracked preservati; staging finale vuoto, frontend-rebuild/main invariati. Consegna tecnica: un commit e PR DRAFT. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** `Default.aspx.vb` e `App_Code/HomeServerStageTiming.vb`, solo dopo review e autorizzazione della procedura Integration. Prossimo/unico gate: attivazione temporanea controllata e acquisizione delle durate reali, con rollback; nessuna ottimizzazione, merge o task successivo autorizzato.

### CATALOG-SEARCH-LEGACY-GET-WRITE-1A — A tecnico, review e smoke reali pendenti

Base autorizzata `da7fc0c96eeee6136c1f0416b1515beb0e986dac`, branch `task/catalog-search-legacy-get-write-1a`; main/origin/main invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. PR #349 verificata MERGED/CLOSED e working copy gia allineata; il checkpoint pre-merge sotto e storico. PR #346 originale chiusa come sostituita, branch e commit conservati. Nessuna ripetizione dei collaudi header gia acquisiti.

Manifest esclusivo: `articoli.aspx.vb` e questo Masterplan. Rimosso soltanto l'INSERT automatico in `query_string` da Page_LoadComplete: il mirror Session("q") deriva dalla QueryString corrente e rendeva mutativa anche la GET con ricerca, refresh e paginazione. Non sostituito con logging su POST generico, deduplica Session o nuovo collector: un binding non rappresenta un evento analytics esplicito. Tutto il code-behind restante e identico alla base, compresi ricerca codice/EAN, query prodotti, binding, filtri/reset, pager, prezzi/IVA/promo/stock, SEO e azioni ecommerce esplicite.

Consumer verificati sul codice versionato: Page.master carica ks-page-flags.js, il cui endpoint moderno e search_suggest.aspx, indipendente da query_string/conteggia_querystring; anche SearchSuggest usa sorgenti distinte. search.aspx.vb resta un endpoint legacy direttamente raggiungibile, con reader storico e compressione intatti, ma non sono stati trovati chiamanti storefront di search.aspx nei sorgenti runtime versionati. Nessun consumer analytics attivo del catalogo identificato nel perimetro ispezionato; integrazioni esterne non certificate. Tabelle, vista, dati storici, reader e altri writer legacy NON modificati: le nuove consultazioni del catalogo non alimentano piu quel conteggio. GET logging in articolix/wishlist/rettificaMagazzino e compressione mutativa del suggeritore legacy restano finding separati, NON RISOLTI; questa patch non certifica l'intera applicazione come read-only.

**153 controlli mirati PASS**, con Page_LoadComplete, SyncCatalogSessionFromQuery, QS e pager reali estratti prima/dopo e compilati VB.NET: due tenant/cataloghi sintetici (elettronica/alimentari), q presente/assente/stale, whitespace, codice/EAN, query lunga, refresh, scope, filtri/offerte/pager e invocazione del lifecycle di postback. Prima una chiamata INSERT con q corrente, dopo zero; ordine dei binding, label e output del renderer sintetico equivalenti; contesto invalido fail-closed. Dipendenze, sink DB e renderer sono sintetici: NON prova HTML/IIS/postback reale. Equivalenza integrale del sorgente esclusa la sola rimozione autorizzata; consumer moderni/legacy, markup e master identici alla base. Precompile ASP.NET Framework 4.8 safe PASS (352 input, configurazione sintetica, zero copie operative e cleanup PASS); diff-check, manifest e scan segreti delle aggiunte PASS.

Nessun accesso DB, HTTP o IIS in questo task. Integration mantiene il runtime precedente con INSERT legacy: non distribuito automaticamente il nuovo file e non seguiti redirect q sul DB remoto operativo. Smoke funzionale reale **NON ESEGUITO**, TTFB **NON MISURATO**; la riduzione dimostrata riguarda una chiamata INSERT nel solo percorso con q, non il conteggio totale delle operazioni della request. Web.config, quattro cancellazioni tracked e 54 untracked preservati con hash/inventario, fuori staging. Consegna: un commit e PR DRAFT verso frontend-rebuild; nessun merge, deploy, modifica configurazioni/DB o task successivo. **FILE PRONTO PER SMOKE SERVER DEL PRODUCT OWNER:** solo `articoli.aspx.vb`, dopo review e verifica del target/lifecycle non mutativo. Prossimo gate: review indipendente e smoke mirato autorizzato, senza riaprire gli audit chiusi.

### HEADER-DESKTOP-MENU-VIEWSTATE-DEDUPLICATION-1A — A funzionale, PR sostitutiva pronta per gate Git

Base stabile `058ff2fd25d96a41c002cc4f9a8fd313738b5f4a`, branch `task/header-desktop-menu-viewstate-deduplication-final-1a`; main/origin/main invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Le PR documentali #347/#348 sono integrate e restano integralmente preservate. La [PR #346](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/346), HEAD originale `56ad564e5e5a99bb3b478fc2212d76bc4d3c5503` con parent `d2117e34dc2feb96997d1f8a6e29dc9dbd15ab2c`, conserva branch, commit e stato OPEN/DRAFT. La sostitutiva nasce dalla stable corrente: nessun rebase, force push, cherry-pick o merge della cronologia precedente.

Manifest esclusivo: `Public/ui/controls/SiteHeader.ascx`, `Public/ui/controls/SiteHeader.ascx.vb` e questo Masterplan. Riapplicato esclusivamente il diff runtime gia approvato e collaudato: EnableViewState=false sul solo litDesktopCatalogMegaMenu; nei postback PreRender ricarica il tree mediante LoadCatalogMenuCached, risolve il current-scope dalla QueryString e ribinda soltanto il Literal desktop. Blob dei due file e diff runtime esattamente identici alla #346. GET iniziale, select/input, repeater mobile, cache/provider, resolver, URL, ricerca, contatti, promo e JS/CSS invariati; nessuna nuova scelta UI o ampliamento N04.

Review indipendente del codice **A** acquisita e confermata dal Product Owner; **687 controlli sintetici WebForms PASS** della #346 riutilizzati, NON ripetuti. Il 2026-10-13, **38 controlli HTTP/WebForms reali distinti PASS**, 19 per tenant, su KeepStoreIntegration con runtime originale #346: HOME/catalogo HTTP 200, sessioni anonime separate e canonical coerenti per aziende 1/2, postback HOME neutro e con settore/categoria HTTP 200, menu identico prima/dopo, current/ancestor/aria-current preservati, ricerca desktop/mobile HTTP 302 con query e scope corretti. ViewState e event validation originali, MAC attivo e TLS verificato; nessuna disabilitazione dei controlli. Le GET di ricerca con q NON seguite per evitare l'INSERT legacy in query_string; nessuna mutazione ecommerce o DML/DDL dalle prove. Browser visuale **NON ESEGUITO**, distinto dal PASS HTTP/HTML; nessuna certificazione visuale 360/390 o miglioramento TTFB dedotto.

HTTPS Integration :18443 predisposto dal Product Owner tramite script amministrativo con quattro binding SNI loopback IPv4/IPv6 e certificato esistente valido per i due hostname; trasporto locale verificato, sito distinto da KeepStoreSmoke :8443. Il DB remoto condiviso e operativo, NON un database isolato: consentiti soltanto i percorsi certificati non mutativi. Backup/rollback infrastrutturali restano locali, senza segreti nei documenti. In questo ciclo Git nessuna modifica di Integration, configurazioni IIS o DB e nessun nuovo smoke. **Precompile ASP.NET Framework 4.8 safe PASS** sulla working copy riallineata (352 input, configurazione sintetica, zero copie di configurazioni operative); equivalenza runtime verificata, senza ripetere i 687 test o i 38 smoke. Le misure sintetiche della #346 riguardano il solo stato del Literal, non ViewState totale, TTFB o DOM completo.

Web.config, quattro cancellazioni tracked e 54 untracked preservati con inventario/hash, fuori staging. Consegna: un solo commit con parent diretto della stable e PR DRAFT sostitutiva, pronta per review Git finale; **nessun merge in questo ciclo**, deploy o task successivo. Nessun nuovo upload runtime richiesto per riutilizzare lo smoke: i due file restano identici a quelli gia collaudati. I debiti IIS #342/#343 e collaudo finale varianti reali/autenticato restano separati e non sanati. Prossimo passo: gate Git della sostitutiva ed eventuale FF-only soltanto secondo l'autorizzazione successiva.

### HOME-TTFB-PERFORMANCE-1A / Fase B — A tecnico, review indipendente pendente

Base autorizzata `b77239f4141d40849b2475a7d2b0dc8780885630`, branch `task/home-ttfb-performance-1a`; main/origin/main invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. PR #344 MERGED/CLOSED: governance EXPERIENCE-FIRST + PERFORMANCE-FIRST integrata, questa nota prevale sul suo checkpoint pre-merge. Fase A approvata dal Product Owner dopo verifica indipendente delle due query equivalenti. Nessun nuovo audit promozionale, benchmark generale o redesign.

Manifest esclusivo: `Default.aspx.vb` e questo Masterplan. In BindHome il pool bestseller mantiene il caricamento originale; se valido/non vuoto, topSellingPool usa una DataTable.Copy indipendente nella medesima richiesta. Nothing o pool vuoto mantengono GetPureTopSellingPool(120) nel solo ramo Else, senza valutazione anticipata. Nessuna modifica SQL/resolver, schema, ordine/priorita dei pool, TakeDiverseRows, binding, prezzi/IVA/promozioni/stock/TCId, deduplica, markup o asset. Nessuna cache persistente, Session/Application/statica o cross-request.

**526 controlli sintetici PASS**: blocchi di caricamento prima/dopo e metodi reali di selezione/chiavi/deduplica estratti dal sorgente e compilati .NET con loader strumentati e fixture in memoria; due tenant/cataloghi sintetici (elettronica e alimentari), pool popolato/vuoto/Nothing, fallback lazy, ordine e limiti delle altre chiamate, schema e valori commerciali completi inclusi NULL/varianti/precisione, dimensioni e ordine delle sezioni, duplicati business/display esclusi, indipendenza di righe/schema della copia e sorgenti inalterati. Verificata equivalenza delle due query wrapper e dell'intero code-behind dopo esclusione della sola modifica autorizzata. Loader sintetici: NON nuove query SQL o smoke HTTP/DB reali.

Performance gate circoscritto: nel percorso valido/non vuoto i caricamenti dei pool prodotti HOME passano da **8 a 7**; vuoto/non disponibile conservano **8 a 8** e il recupero legacy. Non sono il conteggio totale delle query della richiesta e non dimostrano tempi SQL/server/rete/browser. **TTFB live NON MISURATO**, nessuna percentuale o promessa di accelerazione; nessun benchmark su ambienti non certificati. Precompile ASP.NET 4.8 safe, diff-check, manifest e scan segreti PASS. Nessuna suite generale ripetuta.

Web.config, quattro cancellazioni tracked e 54 untracked preservati con inventario/hash, fuori staging. Nessun DB access, DML/DDL, configurazione, deploy, merge o task successivo. I gate residui degli otto scenari IIS #342, deroga smoke #343 e collaudo finale varianti reali/autenticato restano NON CERTIFICATI/NON ESEGUITI/NON AVVIATO secondo le note precedenti; questa ottimizzazione non li sana. Consegna: un commit e PR DRAFT verso frontend-rebuild. **FILE PRONTO PER SMOKE SERVER DEL PRODUCT OWNER:** solo `Default.aspx.vb`. Prossimo gate: review indipendente del diff minimo e verifica autorizzata che prodotti/composizione/ordine HOME restino coerenti; nessun merge implicito.

### ECOMMERCE-UX-PERFORMANCE-GOVERNANCE-1A — A documentale, review indipendente pendente

Base stabile `cfdb2caaf3ba8aee4dc3eee7a6ef749081c27bb0`, branch `task/ecommerce-ux-performance-governance-1a`; main/origin/main invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. PR #343 verificata MERGED/CLOSED FF-only, unico parent `97b4cbadef2365118b0a23ea988411c421a56d4c`, review indipendente A e 50 controlli sintetici/statici PASS acquisiti. Per dichiarazione esplicita del Product Owner, integrazione con deroga al solo smoke IIS della #343: NON ESEGUITO, non trasformato in certificazione live. PR #342 gia integrata nella base precedente, review A e 269 controlli PASS; gli otto scenari dello smoke IIS isolato rimangono NON CERTIFICATI. Le deroghe non sanano tale debito, non certificano l'ecommerce globale e non anticipano il collaudo finale varianti reali/autenticato, ancora NON AVVIATO. Questa nota prevale sui checkpoint pre-merge #342/#343 senza riaprire i task chiusi.

Task DOCS-ONLY con manifest esclusivo `AGENTS.md`, `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md`, questo Masterplan. Standard permanente EXPERIENCE-FIRST + PERFORMANCE-FIRST aggiunto vicino al Design Gate in AGENTS.md; dettaglio operativo nel [Blueprint 2.1.3](KEEPSTORE_SYSTEM_BLUEPRINT.md#213-governance-experience-first-e-performance-first). Identificare bisogno, percorso/attriti e riuso; scegliere metriche/costi pertinenti e budget proporzionato, baseline e confronto omogenei quando misurabili, senza target arbitrari, promesse o misure inventate. Riutilizzare fonti sufficienti e aggiornarle solo quando necessario; almeno due tenant/cataloghi sintetici di merceologie differenti nelle nuove funzioni condivise trasversali; innovazione con beneficio/costo/fattibilita/rischio/priorita, proposta non autorizzazione. Nessuna regressione di sicurezza, regole commerciali, accessibilita, SEO, isolamento o funzionalita stabilizzate.

Consultati contratti Design Gate, MULTITENANT-BY-DESIGN, ADAPTIVE-MULTI-MERCHANDISE-STOREFRONT e Token-Safe / One-Shot. [Benchmark navigazione](KEEPSTORE_NAVIGATION_UX_BENCHMARK.md) riusato read-only, data 2026-10-09: reference ONSUS e link IKEA/Decathlon/MediaWorld/Baymard/W3C gia registrati, nessuna nuova ricerca o verifica live. Il suo elenco di slice e una proposta storica, non una roadmap nuova; nessun modulo indipendente riprioritizzato. Documenti collegati tramite riferimenti canonici, Design Gate e contratti esistenti non riscritti. Verifica coerenza, riferimenti locali/anchor e fonti registrate, diff-check, manifest e scan segreti PASS; nessuna misura prestazionale nuova o dichiarazione di incremento conversione/velocita.

Web.config, quattro cancellazioni tracked e 54 untracked preservati con inventario/hash, fuori staging; nessun runtime, DB, configurazione, UI/business logic o PR precedente modificato. Nessuna build/precompile, suite tecnica, smoke IIS/browser, test mutativo o deploy. Consegna: un commit e PR DRAFT docs-only verso frontend-rebuild; nessun merge o task successivo. Prossimo gate: review indipendente dei tre documenti e successiva autorizzazione Git; nessun file runtime da copiare sul server.

### CART-STOCK-ERROR-FEEDBACK-1A — A tecnico, review indipendente pendente

Base stabile `97b4cbadef2365118b0a23ea988411c421a56d4c`, branch `task/cart-stock-error-feedback-1a`. PR #342 verificata MERGED/CLOSED, integrazione FF-only con unico parent `b73910f562ecd816e8b26437c226f0bc93100d2e` e main invariato. Questa nota prevale sul checkpoint pre-merge #342: review indipendente A e 269 controlli sintetici/statici PASS acquisiti; merge per eccezione esplicitamente comunicata dal Product Owner, SENZA certificazione dello smoke IIS isolato. Gli otto scenari IIS restano NON CERTIFICATI, non convertiti in PASS dai test riferiti dal Product Owner. Il tentativo di ripristino isolato si e fermato prima di avvio, copie runtime o fixture per impossibilita di certificare il mapping IIS senza privilegi/elevazione vietata; nessuna prova sul DB operativo. Collaudo finale varianti reali/autenticato ancora NON AVVIATO.

Manifest esclusivo: `catalog_cart_async.aspx.vb` e questo Masterplan. Il rifiuto tipizzato StockInsufficient conserva HTTP 422 ma restituisce il testo esatto: "Disponibilità insufficiente per la quantità richiesta. Controlla il carrello o prova con una quantità inferiore." Commercial conserva HTTP 422 e messaggio generico precedente; Technical, Indeterminate, refreshRequired, Abandon/Complete, successo e payload invariati. Nessun uso di ErrorMessage per classificare, nessun dettaglio stock/prezzo/DB aggiunto alla risposta. Servizi commerciali, stock, checkout, JavaScript/CSS/configurazioni invariati.

Verificato read-only `keepstore-product.js`: la risposta di errore usa data.message, il catch passa il testo al renderer di stato e il renderer usa textContent. Nessuna modifica frontend necessaria e nessun nuovo comportamento grafico/progettazione UI. **50 controlli mirati PASS** su ramo risultato e Reject reali estratti dal sorgente e compilati con response/intent sintetici: StockInsufficient/Commercial/testo esatto, Technical 503, Indeterminate 503 con refreshRequired e senza Abandon, risultato assente/inconsistente fail-closed, successo/identificativi/Complete invariati; equivalenza dell'intero endpoint dopo esclusione della sola differenza autorizzata e contratto JS statico/byte-equivalente. Fixture esclusivamente in memoria, non HTTP/IIS/browser reali e nessun DB access. Precompile ASP.NET 4.8 safe PASS senza copie di configurazioni operative, diff-check, manifest e scan segreti PASS. Nessuna ripetizione dei 269 controlli o dello smoke ambientale bloccato.

Web.config, quattro cancellazioni tracked e 54 untracked preservati con inventario/hash, fuori staging; frontend-rebuild/main invariati al nuovo stable. Nessun deploy, DB write, ordine/pagamento/SMTP, merge della nuova PR o task successivo. **FILE PRONTO PER SMOKE SERVER DEL PRODUCT OWNER:** solo `catalog_cart_async.aspx.vb`, dopo review indipendente. Prossimo gate: review del diff minimo e verifica mirata del testo secondo autorizzazione/ambiente disponibili; il collaudo controllato degli otto scenari stock rimane un gate residuo distinto, NON ESEGUITO in questo task.

### CART-STOCK-PRECHECK-1A / REV1 — A tecnico, review indipendente e smoke IIS pendenti

Base stabile `b73910f562ecd816e8b26437c226f0bc93100d2e`, branch `task/cart-stock-precheck-1a`. PR #341 verificata MERGED/CLOSED; review indipendente e smoke IIS A acquisiti dal Product Owner per la parita disponibilita, ora integrata nella base. Questa nota prevale sul checkpoint pre-merge #341 e sulla precedente esclusione del precheck carrello dal task disponibilita. Manifest REV1 autorizzato: `App_Code/CartMutationService.vb`, `App_Code/OrderInventoryAvailabilityService.vb`, `catalog_cart_async.aspx.vb`, questo Masterplan. Nessun cambio a helper display, resolver prezzi, JavaScript, UI, endpoint quantita o checkout.

Precheck centralizzato prima delle scritture add/batch, SET prodotto e `UpdateStandardQuantities`: quantita finale aggregata per identita inventariale articolo/TCId, solo SKU interessati. Per add/SET si usa la variante effettiva del resolver commerciale gia esistente e persistita dal percorso; per aggiornamento per CartRowId si conserva l'identita inventariale delle righe persistite, come nell'ordine. Si includono tutte le righe duplicate dello stesso SKU, anche quelle non modificate; varianti positive distinte non condividono stock. Owner, azienda, database e listino restano dal contesto server-side validato, non dai parametri legacy del caller. Nessun nuovo fallback commerciale o variante introdotto.

Una sola SELECT inventario parametrizzata per tutti gli aumenti, nel database corrente e nel medesimo magazzino del controllo ordine; nessuna query stock per singolo prodotto e nessuna lettura stock per sole riduzioni/no-op. Netto tramite `CalculateNetAvailableQuantity(Giacenza, Impegnata)`, senza override da Disponibilita memorizzata o InOrdine. NULL Giacenza/Impegnata equivalenti a zero secondo il contratto ordine; identita inventariale assente = stock insufficiente, identita ambigua/dati malformati/errore di lettura = errore tecnico, mai disponibilita inventata. Nessuna scrittura su inventario, lock inventariali aggiuntivi espliciti o prenotazione; isolamento transazionale carrello esistente preservato. Il precheck non garantisce lo stock futuro: verifica definitiva con lock/procedura al checkout invariata.

Nuove aggiunte e aumenti oltre il netto rifiutati; diminuzioni e quantita aggregate invariate consentite dal precheck anche se ancora sopra lo stock sopravvenuto. Remove/clear invariati e indipendenti dallo stock. SKU estranei alla mutazione non bloccano il precheck; restano i controlli commerciali/revalidation gia esistenti. Un batch rifiutato non entra nel ciclo di scrittura; errori durante le scritture restano nel rollback transazionale esistente. Nessuna vendita su ordinazione implicita: eventuali eccezioni richiedono un contratto separato.

Risultati add/batch espongono `CartMutationFailureKind` strutturato: None, Commercial, StockInsufficient, Technical, Indeterminate. Default fail-closed Technical; successo soltanto dopo esecuzione/commit confermati. Resolver prezzi interrogati sui flag esistenti, mai sul testo ErrorMessage. Un Abort con rollback confermato conserva il risultato commerciale anche nel percorso quantita; rollback non confermato o errore tecnico non vengono trasformati in stock insufficiente. `catalog_cart_async.aspx.vb`: rifiuto commerciale/stock HTTP 422; impossibilita tecnica HTTP 503 (catch inatteso 500); esito indeterminato 503 con richiesta di riconciliazione, senza Abandon dell'intent. Replay, CSRF, same-origin, validazione parametri e altri contratti HTTP preesistenti invariati. Messaggi client sanitizzati, senza dettagli DB. Caller tradizionali continuano a usare Succeeded/HasBlockingError; endpoint quantita gia distingue tecnico 503 e commerciale 422, ora riceve il rifiuto stock anziche perderlo nel fallback tecnico.

**269 controlli mirati PASS**, harness esterni fuori manifest/repository: 150 su assembly App_Code reale, helper privati, SQL parametrizzato, ordine delle chiamate e ramo esatto di rifiuto endpoint compilato con risposta/intent sintetici; 55 sul sorgente reale del lettore stock con ADO fake, inclusi NULL, assenza, ambiguita e failure di lettura; 64 sui sorgenti reali CartMutationService/OrderInventoryAvailabilityService con ADO, transazione/retry, scope, prezzi e lifecycle simulati. Add, SET, aumenti/riduzioni/no-op, aggregazione righe/input duplicati, varianti, due scope/listini/owner sintetici, rifiuto atomico prima delle scritture, rollback simulato dopo errore, classificazione tecnica/indeterminata e remove/clear PASS. Metodi definitivi ordine e percorso remove/clear equivalenti alla base verificati staticamente. Nessuna connessione, transazione o mutazione su DB operativo; queste prove NON sono uno smoke HTTP/IIS reale, una prova concorrente su MySQL o il collaudo con varianti/autenticato reali. Precompile ASP.NET 4.8 safe PASS, senza copie di configurazioni operative; diff-check, manifest e scan segreti PASS. Nessuna suite generale ripetuta.

Protetti web.config, quattro cancellazioni tracked e 54 untracked con inventario/hash invariati, fuori staging; frontend-rebuild e main invariati. Nessun merge/deploy/DML/DDL/ordine/pagamento/e-mail o task successivo. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** `App_Code/CartMutationService.vb`, `App_Code/OrderInventoryAvailabilityService.vb`, `catalog_cart_async.aspx.vb`, insieme dopo review indipendente. Prossimo gate: review mirata e smoke IIS su ambiente/fixture esplicitamente autorizzati per add/quantita insufficienti, riduzione e distinzione 422/5xx; nessuna mutazione sul DB operativo eseguita da questo task. Collaudo finale varianti reali/autenticato resta NON AVVIATO; nessuna dichiarazione di ecommerce completo.

### STOREFRONT-AVAILABILITY-PARITY-1A / REV1 — A tecnico, review indipendente pendente

Base stabile `61bca13f16ab342009efe520dbb3cb73804e278b`, branch `task/storefront-availability-parity-1a`. PR #340 chiusa A/integrata e smoke visuale A comunicati dal Product Owner; percorso confronto 1A/1B/1C concluso, collaudo finale varianti reali/autenticato ancora NON AVVIATO. Questa nota prevale sui checkpoint pre-merge #340 e sul vecchio contratto presentazionale che preservava il fallback Giacenza grezza/Disponibilita positiva. Manifest esteso autorizzato: `App_Code/OrderInventoryAvailabilityService.vb`, `App_Code/AvailabilityDisplayHelper.vb`, questo Masterplan.

Audit precedente read-only: articolo 16483 con Giacenza 1/Impegnata 0 e coerente con ordine; falsi positivi reali 15152 (1/1) e 12384 (1/2), Disponibilita memorizzata 0. Regola unica ora estratta in `OrderInventoryAvailabilityService.CalculateNetAvailableQuantity(Decimal, Decimal)`: `Math.Max(0D, giacenza - impegnata)`, funzione pura senza DB/Session/HttpContext. Il controllo ordine richiama tale funzione nel medesimo punto della formula inline, con corpo/query/lock/transazioni e normalizzazione NULL invariati. L'helper riusa la funzione per quantita effettiva e IsAvailable; Disponibilita memorizzata non sovrascrive il netto, neppure positiva. Zero netto resta non disponibile/in arrivo secondo gli arrivi gia previsti, mai acquistabile per il solo valore raw. Nessun nuovo arrotondamento, clamp degli input, prenotazione, query o modifica carrello/prezzi/IVA/promo.

Modalita sintetica/numerica, soglia ScortaMinima prodotto -> DispoMinima tenant -> default 2, testi legacy/arrivi, metriche, tooltip, HTML e normalizzazione NULL/mancanti dell'helper preservati. Gli ingressi web ed espliciti usano lo stesso core; catalogo/PDP e provider confronto continuano a consumare l'helper senza modifiche ai caller. Nessuna eccezione o bypass stock speciale risulta implementata nel controllo ordine esaminato: nessuna regola speciale aggiunta o reinterpretata. Eventuali nuove eccezioni di dominio richiedono decisione separata, non un override positivo memorizzato. La scelta se bloccare l'aggiunta al carrello senza stock resta FUORI PERIMETRO; questa modifica non rende le CTA catalogo/PDP condizionate a stock e non tocca CartMutationService.

Harness esterno .NET Framework con helper, funzione ordine, provider e resolver commerciali reali; solo dipendenze log/scope estranee stubbed: **307 PASS**. Casi 1/0->1, 1/1->0, 1/2->0, 0/0->0, 10/3->7, negativi netti clamped e quantita frazionarie, raw Disponibilita negativo/zero/positivo/100 senza override, entrambe le modalita, parita matematica con formula ordine precedente anche per input firmati, soglie prodotto/tenant, NULL/mancanti, arrivi e testi; provider confronto coerente con helper, prezzi invariati e stock incompleto NotVerified. Fixture esclusivamente in memoria: nessun DB operativo o ordine eseguito. Caller catalogo/PDP verificati staticamente, non un nuovo smoke browser/IIS end-to-end. Equivalenza sorgente ordine, esclusa estrazione/chiamata, PASS: query/lock/transazioni identici. Precompile ASP.NET 4.8 safe senza copie operative, diff-check, manifest e scan segreti PASS. Nessuna suite generale ripetuta.

Protetti web.config, quattro cancellazioni tracked e 54 untracked fuori staging; main invariato. Nessun merge/deploy/DB write/ordine/pagamento/e-mail o task successivo. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** `App_Code/OrderInventoryAvailabilityService.vb` e `App_Code/AvailabilityDisplayHelper.vb`, insieme e dopo review indipendente. Verificare la disponibilita presentata per i tre casi reali e gli ingressi catalogo/PDP/confronto, senza effettuare ordini o mutazioni carrello. Nessuna certificazione del collaudo finale varianti/autenticato.

### COMPARE-COMMERCIAL-SNAPSHOT-1C / PR #340 REV1 — solo F01 layout, A tecnico / smoke visuale pendente

Parent REV1 `08266c4f2b27f16bb6469ea642f6c741e5cca1f8`, stesso branch `task/compare-commercial-snapshot-1c`, nessuna risincronizzazione. Smoke Product Owner precedente B per layout: le regole tema delle card erano limitate all'offcanvas, mentre la pagina aveva soltanto immagini width 100% senza una propria griglia. Manifest REV1: `compare.aspx`, `Public/assets/keepstore/css/theme-overrides.css`, `Page.master` soltanto cache-buster CSS, questo Masterplan. Questa nota prevale sull'assenza di CSS/modifiche visuali del checkpoint 1C precedente. Nessun JavaScript/provider/endpoint/helper commerciale modificato.

Design Gate: reperito ed esaminato il riferimento originale ONSUS `compare.html` nella copia locale storica `C:\KeepStoreWeb\_precompile_verify_pr95\Public\assets\keepstore\compare.html`, oltre alle regole tema versionate tf-table-compare/tf-compare-col/tf-compare e offcanvas. Il template usa colonne affiancate, immagini limitate e scroller dedicato; KeepStore conserva il renderer/card gia approvato e i soli dati reali, adottando lo stesso principio senza importare tabella/prodotti demo o aggiungere attributi commerciali. Reflow e scorrimento nativo confinato alla sezione secondo [W3C WAI Reflow](https://www.w3.org/WAI/WCAG21/Understanding/reflow); nessuna dichiarazione di conformita accessibile/visuale completa senza browser.

Tutte le nuove regole sono scoped a `#ksComparePage`: grid a colonne con card 260px mobile e 280px da 768px, gap 16/20px, overflow-x auto/max-width 100%/min-width 0/box-sizing border-box, snap proximity e contenimento dello scroll. Nessun overflow nascosto sul body per mascherare il problema. Immagini box 168px con contain e massimo interno 144px; card bordate/radius tema, categoria/titolo/metadati/IVA/prezzo/stato/azioni in righe coerenti, titolo max tre righe, pulsanti almeno 44px e slot azioni allineato anche quando Aggiungi e assente. Scroller focusabile con nome e istruzione visibile; remove, clear ed empty-state invariati. Page.master cambia esclusivamente la versione di theme-overrides.css, senza alterare il drawer o gli altri consumer.

F02 commerciale non modificato per decisione esplicita del Product Owner: AvailabilityDisplayHelper resta l'autorita con il fallback Giacenza gia esistente; provider/JSON/JS invariati. L'idoneita commerciale del fallback sull'articolo 16483 e una decisione separata, non un fix nascosto nel CSS. Nessuna nuova verifica commerciale o modifica DB in REV1.

**53 controlli statici PASS**, CSS bilanciato/scoped, regole precedenti e drawer inalterati, immagini/slot/target/focus, regione HTML, master solo cache-buster, JavaScript equivalente alla HEAD precedente; modello geometrico per 320/360/390/768/1365 con card entro il pannello e piu colonne entro lo scroller. Questi controlli NON misurano il layout reale del browser. Precompile ASP.NET 4.8 safe PASS senza copie operative, diff-check/manifest/scan segreti PASS. Skill Browser consultata, interfaccia di controllo js assente: overflow effettivo, allineamento visuale, scorrimento/tastiera e viewport 360/390/desktop NON CERTIFICATI, da smoke Product Owner prima del merge. Nessuna suite commerciale ripetuta.

Protetti web.config, quattro cancellazioni tracked e 54 untracked fuori staging; nessun merge/deploy/DB write/ordine/pagamento/task successivo. **FILE RUNTIME REV1 PER SMOKE:** `compare.aspx`, `Public/assets/keepstore/css/theme-overrides.css`, `Page.master`. Per un server non ancora aggiornato alla 1C sono necessari anche i file runtime cumulativi della PR, non soltanto REV1. Prossimo gate: review mirata REV1, poi smoke visuale reale almeno due prodotti affiancati, 360/390/desktop, immagini/titoli/azioni, scroll confinato, empty/remove/clear e drawer invariato.

### COMPARE-COMMERCIAL-SNAPSHOT-1C — collegamento UI, A tecnico / smoke visuale e review indipendente pendenti

Base `e2dddb9bb70113637f239552821542a0336bb6bd`; branch `task/compare-commercial-snapshot-1c`. PR #339 verificata MERGED/CLOSED, provider/endpoint 1A e 1B integrati; questa nota prevale sul vecchio checkpoint pre-merge 1B. Manifest: `compare.aspx`, `Public/assets/keepstore/js/keepstore-product.js`, questo Masterplan; `Default.aspx`, `articoli.aspx`, `articolo.aspx` esclusivamente cache-buster dello stesso script. Nessun altro runtime, CSS, provider, handler o DB modificato.

La pagina confronto proietta dallo storage solo id/TCId e metadati descrittivi; non legge prezzo, stock o URL carrello memorizzati. Un POST JSON same-origin/no-store, token gia emesso dal master, massimo 12 coppie validate/deduplicate; varianti positive esatte, alias 0/-1 normalizzati come ingresso senza variante, sempre sottoposto alla validazione autorevole del provider (nessun fallback se il prodotto possiede varianti). Endpoint risolto con ResolveUrl nel solo compare.aspx. Risposta Ready validata integralmente per struttura, IVA, identificativi esatti e univoci e facts commerciali; mapping per chiave, non posizione. NotVerified e risposta malformata non espongono facts. Prezzo solo formattato in italiano a due decimali, nessun calcolo fiscale o commerciale nel browser.

Loading/errore HTTP/rete/timeout 10 secondi/CSRF-Session invalidi/nodo mancante: nessun prezzo o stock storage, stato esplicito e link Vedi prodotto. Aggiungi presente soltanto per item verificato e disponibile, URL id+TCId costruito dai soli identificativi; mutazione sempre delegata al percorso server esistente, non provata con ordine/add reale. Revisioni richiesta, annullamento quando disponibile e guardia indipendente dall'abort impediscono risposte obsolete dopo remove/clear o richieste successive. Storage cross-tab e ritorno bfcache invalidano la pagina e richiedono nuova verifica. Nessun prezzo/stock del server viene scritto in localStorage; chiave, dati salvati, deduplica, limite e renderer drawer esistenti invariati. Il drawer non e incluso nella certificazione di freschezza commerciale della pagina.

Design Gate proporzionato, senza redesign: riferimento HTML originale ONSUS non reperito nei percorsi consultati; esaminati asset tema versionati `styles.css` (tf-compare-item/wrap) e `theme-overrides.css` (immagine contain) e markup confronto gia approvato. Preservati classi/card/azioni/mobile CSS, aggiunto solo stato live persistente con role=status/aria-atomic e aria-busy sul grid, coerente con [W3C WAI ARIA22](https://www.w3.org/WAI/WCAG21/Techniques/aria/ARIA22). Nessun benchmark generale o nuovo layout. Browser controllabile non disponibile (tool js richiesto dalla skill assente): desktop/mobile 360/390, overflow, focus e interazione reale NON CERTIFICATI; questo limite non e sostituito dai test sintetici.

Harness Node esterno con funzioni JS reali e DOM/storage/fetch/timer sintetici: **127 PASS**; Verified disponibile/indisponibile, NotVerified con facts spurie ignorate, varianti in ordine risposta invertito, 14 risposte malformate, HTTP/HTML/rete/timeout, risposte tardive/fuori ordine, empty/add/dedup/clear/cross-tab/bfcache, token/fetch mancanti, max12 e alias, identita invalide, zero richieste dalle pagine prive di grid, storage non aggiornato dal server, renderer drawer equivalente alla base. Sintassi JS, precompile ASP.NET 4.8 safe senza copie operative, diff-check, manifest e scan segreti delle aggiunte PASS. Fixture varianti solo sintetiche: supporto reale resta disabilitato, gate finale varianti/autenticato invariato.

Protetti web.config, quattro cancellazioni tracked e 54 untracked fuori staging. Nessun merge/deploy/DML/DDL/ordine/pagamento/e-mail o task successivo. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** `compare.aspx`, `Public/assets/keepstore/js/keepstore-product.js`, `Default.aspx`, `articoli.aspx`, `articolo.aspx`, dopo review indipendente. Smoke mirato: confronto con articoli reali, prezzi/label IVA/stock verificati, Aggiungi assente per non verificati o indisponibili (senza effettuare mutazioni), remove/clear, errore/rete e drawer invariato, mobile 360/390 e desktop. Nessuna dichiarazione di ecommerce completo.

### COMPARE-COMMERCIAL-SNAPSHOT-1B — review A, smoke IIS e varianti simulate; gate finale varianti differito dal Product Owner

PR #339 revisionata indipendentemente A dal Product Owner sul commit `ac49fa16d3d483b2c13f13cd38f886cfbdbc2c81`; non ancora integrata. Smoke IIS locale HTTPS con Session anonima e token CSRF realmente emesso dal master: POST articolo 21813 HTTP 200, prezzo IVA inclusa 3660 e disponibilita zero coerenti con lettura della view autorevole; prodotto/variante inesistenti NotVerified senza prezzo/disponibilita; CSRF assente/errato e Session assente 403, GET 405, JSON invalido e 13 prodotti 400, JSON/no-cache/no-store PASS. Nessun errore IIS nelle richieste eseguite. Contesto autenticato reale non disponibile e non certificato; contesto anonimo/autenticato sintetico resta coperto dai 320 controlli precedenti. Smoke reale sull'articolo 16483, prezzo 3600, riferito PASS dal Product Owner: evidenza umana, non una nuova verifica automatizzata Codex.

Il DB locale non contiene righe in `articoli_tagliecolori`; supporto varianti attualmente disabilitato. Il Product Owner autorizza simulazioni senza attivazione e rinvia esplicitamente il collaudo reale con varianti abilitate al completamento del progetto. Harness esterno mirato sul provider e serializer JSON reali gia compilati: **39 PASS**, varianti 99/100/101 dello stesso articolo con prezzi e stock distinti, promo esatta senza contaminare altre varianti, stock zero verificato, variante/prodotto assenti senza fallback o facts commerciali, due scope tenant e batch cross-tenant rifiutato, contesto autenticato con override IVA, variante ambigua fail-closed, deduplica/alias 0 e -1, limite 12/13. Dati esclusivamente sintetici in memoria; nessun accesso DB o attivazione dal harness. Queste prove NON certificano il lifecycle completo delle varianti su IIS/DB reale. Nessun resolver/runtime modificato, DML/DDL, deploy, merge o fase 1C.

### Gate obbligatorio di fine progetto — ecommerce completo con varianti abilitate e contesto autenticato

Prima della certificazione finale dell'ecommerce, eseguire un collaudo dedicato con supporto `articoli_tagliecolori` abilitato a 1 tramite il contratto di configurazione autorevole, su ambiente e fixture esplicitamente autorizzati dal Product Owner, includendo obbligatoriamente il contesto autenticato reale, oggi non certificato. **NON AVVIATO / DIFFERITO**, non soddisfatto dai test sintetici e non attivabile automaticamente da questa nota. Per il momento lasciare il supporto disabilitato e non creare/modificare righe o flag nel DB.

La matrice finale deve coprire almeno PDP e selezione variante, HOME/catalogo/ricerca e confronto con coppia id+TCId esatta, prezzo/listino/IVA/promo e stock specifici della variante, assenza di fallback su variante inesistente/invalida, carrello/MiniCart e quantita/remove/clear, persistenza e transizione anonimo/login, checkout e righe documento. Provare anonimo/autenticato, almeno due tenant/listini, varianti con stock/prezzi differenti e indisponibili, deduplica e limiti batch, errori/CSRF/no-cache, desktop e mobile. Ordini, mutazioni carrello, attivazione del supporto e qualsiasi fixture DB richiedono autorizzazione dedicata e piano di ripristino; nessun pagamento, gateway o e-mail reale implicitamente autorizzato. Registrare separatamente PASS/FAIL runtime reali e limiti sintetici, senza dichiarare l'ecommerce completo finche il gate non e superato.

### COMPARE-COMMERCIAL-SNAPSHOT-1B — endpoint read-only, review indipendente pendente

Base autorizzata `80d74b6b4cd363ee8638e24970d1e542948d087b`; branch `task/compare-commercial-snapshot-1b`. Manifest: `compare-commercial-snapshot.ashx`, `App_Code/CompareCommercialSnapshotHandler.vb`, questo Masterplan. Convenzione Web Site gia usata da `search-suggest.ashx`: direttiva handler e classe in App_Code, senza endpoint ASPX/master o nuove dipendenze. Provider/resolver, Page.master, compare.aspx, JavaScript e carrello invariati.

POST HTTPS con body UTF-8 `application/json`: `{ "products": [{ "id": 123, "TCId": -1 }] }`. Massimo 12 coppie in input, solo interi numerici validi, root e campi allowlisted, limite 8192 byte verificato anche sullo stream effettivo; serializzazione JavaScriptSerializer limitata, nessun tipo CLR selezionabile dal client. Alias 0/-1 e deduplica restano nel provider. Querystring vietata. Same-origin su Origin/Referer e Sec-Fetch-Site, header `X-Requested-With: XMLHttpRequest` e `X-KeepStore-CSRF` validato tramite CatalogAsyncCartSupport; il token e gia emesso dal master storefront, non viene creato dall'handler. JSON no-cache/no-store, Vary Cookie e nosniff anche per gli errori; nessun CORS/JSONP.

Contesto: tenant risolto per host tramite StorefrontSeoTenantContext, confronto con i tre default fiscali scalari server-owned salvati da PageMaster.LeggiAzienda in Session (azienda, listino default, modalita tenant), SetTenantDefaults soltanto in HttpContext.Items, poi GetCurrent con i guardrail tenant/account/listino/IVA esistenti. IReadOnlySessionState e nessuna scrittura Session. Account IvaTipo non diventa mai default tenant; nessuna adozione di Session cross-tenant o fallback anonimo. Una pagina storefront deve aver gia idratato i default e il CSRF: Session nuova, vecchia/incompleta o incoerente restituisce 403 `storefront_context_required`, senza ricostruzione autonoma di regole fiscali/auth; host sconosciuto 421. Il futuro consumer 1C deve richiedere una nuova inizializzazione della pagina se necessario, non usare prezzi storage in fallback. La dipendenza dalle tre chiavi scalari private del master e esplicita: eventuali cambiamenti al contratto di idratazione devono aggiornare e verificare anche questo handler.

LoadCurrent e l'unico ingresso commerciale. Risposta: ok/state/items; ciascun item contiene id/TCId/verified, e soltanto se Verified espone price decimale e availability (available/text). NotVerified contiene solo identificativi, stato e motivo; nessun prezzo/disponibilita. Modalita/label IVA del Context soltanto per lettura Ready. 200 significa lettura completata, non che ogni item sia verificato: il consumer deve controllare verified per prodotto. Errori tecnici 503, contesto invalido 403, input invalido 400, body oltre limite 413, metodo non POST 405.

Harness ASP.NET esterno con handler/provider/core reali e richieste Worker/Session/tenant sintetici: **320 PASS**. Anonimo/autenticato, due scope tenant/listino e label IVA, Session stale/cross-tenant, POST/GET, JSON/MIME/UTF-8/allowlist/integer/range, 0/1/12/13 e varianti/alias, same-origin/CSRF, limiti dichiarati/effettivi, no-cache/nosniff, Session invariata, decimal JSON invariante e omissione totale delle informazioni commerciali non verificate. Letture non-empty con connessione sintetica non raggiungibile provano il fail-closed reale del provider; payload Verified/missing/unavailable verificati con snapshot sintetici. Logger/UI estranei stubbed; nessun database operativo o configurazione operativa copiati nel harness. Non e uno smoke IIS/browser o commerciale end-to-end; test 1A non rieseguiti. Precompile ASP.NET 4.8 safe, diff-check, manifest e secret scan delle aggiunte **PASS**.

Nessun DML/DDL, deploy, merge, ordine, pagamento o e-mail. Protetti web.config, quattro cancellazioni tracked e 54 untracked fuori staging. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** esclusivamente `compare-commercial-snapshot.ashx` e `App_Code/CompareCommercialSnapshotHandler.vb`, dopo review indipendente; nessuna UX nuova da certificare. Sequenza: 1A integrata, 1B endpoint, 1C collegamento UI **NON AUTORIZZATO / NON AVVIATO**.

### COMPARE-COMMERCIAL-SNAPSHOT-1A — CHIUSO / A / INTEGRATED

PR #338 verificata MERGED a `80d74b6b4cd363ee8638e24970d1e542948d087b`. Review A comunicata dal Product Owner; copia canonica riallineata soltanto FF-only, stato locale preservato. Questa nota prevale sui checkpoint pre-merge Fase A/REV1 seguenti; nessun task chiuso riaperto.

### COMPARE-COMMERCIAL-SNAPSHOT-1A / REV1 — F01/F02 corretti, review indipendente pendente

PR #338 e branch `task/compare-commercial-snapshot-1a` invariati; parent REV1 `d8d52dd924118b0f2f6febb565281d6467b26e3a`, base stabile `4e50cfd21b05d3bebd3099cc65c40ef76b333eef`. Manifest sempre soltanto provider e questo Masterplan. F01: la stessa SELECT batch proietta ora `vsuperarticoli.ScortaMinima`, fonte autorevole proveniente dalle giacenze; soglia prodotto e fallback tenant rimangono quelli di `AvailabilityDisplayHelper`, senza nuovi calcoli o query.

F02: verificati read-only schema e definizione della view locale. `Giacenza`, `Disponibilita` e `Impegnata` sono gia normalizzate a zero dalla view tramite IF NULL; un NULL residuo in queste tre proiezioni non e certificabile e restituisce `NotVerified` senza prezzo/disponibilita. `InOrdine` puo legittimamente essere NULL nel percorso legacy e conserva lo zero dell'helper. `ScortaMinima` NULL/zero conserva il fallback tenant; valore presente malformato o colonna assente fallisce chiuso come gli altri dati stock. Nessun cambiamento ai resolver o alla presentazione sintetica/numerica dell'helper. Questa nota supera soltanto l'accettazione indiscriminata dei NULL stock del checkpoint Fase A.

Harness esterno REV1: **58 PASS**, soglia articolo maggiore/minore di quella tenant, fallback NULL/zero, stock zero verificato, NULL incoming ammesso e arrivi positivi, NULL obbligatori rifiutati, cinque colonne assenti/malformate, double SQL, promo/variante e modalita display delegate. SELECT aggiornata verificata read-only sullo schema locale con `LIMIT 0`. Precompile 4.8 safe, diff-check, manifest e secret scan delle aggiunte **PASS**. I precedenti 84 test restano evidenza storica per il perimetro non modificato e non sono stati rieseguiti integralmente; il caso NULL stock modificato e coperto dalla REV1.

Nessun nuovo endpoint, DB write, deploy, merge o Fase B. Configurazione, quattro cancellazioni tracked e 54 untracked protetti fuori staging. Prossimo gate: review indipendente della REV1; file runtime pronto soltanto `App_Code/CompareCommercialSnapshotProvider.vb`.

### COMPARE-COMMERCIAL-SNAPSHOT-1A / FASE A — provider server-side, review indipendente pendente

Base autorizzata `4e50cfd21b05d3bebd3099cc65c40ef76b333eef`; branch `task/compare-commercial-snapshot-1a`. Manifest esclusivo: `App_Code/CompareCommercialSnapshotProvider.vb` e questo Masterplan. La working copy era gia allineata: nessuna risincronizzazione. `main` / `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

Foundation non montata: `LoadCurrent(HttpContext, IEnumerable(Of CompareCommercialProductKey))` riceve soltanto identificativi, massimo 12 elementi in input, deduplicati per `id + TCId`; `0` e `-1` rappresentano lo stesso articolo senza varianti. Contesto fiscale/listino dal `StorefrontPriceDisplayContextProvider` validato dal master; utente e scope promozionale da `ProductPromotionEligibilityResolver.CreateContext`. Nessun prezzo, disponibilita o parametro commerciale proveniente dal browser. Una SELECT parametrizzata sul database configurato/listino corrente carica tutti i prodotti abilitati/esportabili; verifica l'associazione esatta alla variante ed esclude il sentinel senza variante quando l'articolo ha varianti. Nessun fallback ad altre varianti. Ripetizioni identiche della view vengono deduplicate; fatti commerciali discordanti sono NON VERIFICATI.

Un solo `ProductPromotionEligibilityResolver.CreateBatch` per l'intero insieme; prezzo fiscale da `StorefrontEffectivePriceResolver`, selezione netto/lordo dal Context, promozione autorevole applicabile a quantita 1 e disponibilita da `AvailabilityDisplayHelper`. Nessun nuovo calcolo commerciale, arrotondamento anticipato o query per singolo prodotto. Lo snapshot non prenota prezzi o stock: sono letture correnti, non una transazione commerciale atomica. Errori di contesto/query/batch, prodotti mancanti, varianti invalide o dati ambigui restituiscono `NotVerified`, motivo esplicito, prezzo e disponibilita nulli e testo vuoto. `Ready` significa lettura completata, NON che ogni elemento sia verificato: il futuro consumer deve controllare lo stato di ciascun elemento e non sostituire errori con valori commerciali da localStorage.

Harness esterno isolato con provider e resolver fiscali/promozionali/disponibilita reali: **84 PASS**. Input invalidi/null, deduplica `0/-1`, limite 12/13, ordine del batch, due scope tenant/listino sintetici, mismatch tenant/listino/utente, context Session anonimo/autenticato e stale, netto/lordo, override 0/frazionario, RC 0/5 e precedenza, promo a quantita 1/tier non applicabile/variante esatta, indisponibilita verificata distinta da errore, prodotto mancante/variante errata, ambiguita e dati mancanti. Log e dipendenze estranee stubbed nel solo harness; nessuna fixture DB. SELECT reale verificata sullo schema locale con `LIMIT 0`, read-only; non e uno smoke commerciale end-to-end di tenant reali. Precompile ASP.NET Framework 4.8 safe **PASS**, con configurazione sintetica e zero copie operative; diff-check, manifest e secret scan delle aggiunte **PASS**.

Nessun endpoint pubblico, modifica `compare.aspx`/JavaScript/carrello/checkout/resolver, deploy, merge, DML/DDL o operazione ecommerce. Preservati `web.config`, quattro cancellazioni tracked e 54 untracked, fuori staging. Fase B JavaScript **NON AUTORIZZATA / NON AVVIATA**; gate successivo: review indipendente del provider e delle regole commerciali. File runtime pronto per review: soltanto `App_Code/CompareCommercialSnapshotProvider.vb`.

### COMPARE-DRAWER-EMPTY-STATE-1A — CHIUSO / A / INTEGRATED

PR #337 integrata al commit `4e50cfd21b05d3bebd3099cc65c40ef76b333eef`, parent `6ba454b910049f6e5c240b198a7f5d21ec418f86`; review e smoke A comunicati dal Product Owner. Questa nota prevale sul checkpoint pre-merge seguente. Storage, limite 12, deduplica e pagina confronto restano invariati dalla foundation Fase A.

### COMPARE-DRAWER-EMPTY-STATE-1A — A tecnico / B complessivo, review e smoke Product Owner pendenti

Base verificata `frontend-rebuild` / `origin/frontend-rebuild` = `6ba454b910049f6e5c240b198a7f5d21ec418f86`; branch `task/compare-drawer-empty-state-1a`. Manifest esclusivo: `Page.master`, `Public/assets/keepstore/js/keepstore-product.js`, `Default.aspx`, `articoli.aspx`, `articolo.aspx`, `compare.aspx` (questi quattro soltanto cache-buster), questo Masterplan. `main` / `origin/main` invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

L'offcanvas globale `#compare` mantiene messaggio e struttura ONSUS; a lista vuota offre il link nativo `Vai al catalogo` verso `articoli.aspx` e nasconde il solo blocco azioni del drawer tramite `d-none`. `renderCompareDrawer()` ripristina le azioni esistenti quando e presente almeno un prodotto. Le chiamate gia presenti dopo add/remove/clear aggiornano anche questa visibilita, senza listener, stato o dipendenze nuovi. Chiave `ks_compare_products`, dati memorizzati, deduplica, limite 12, handling errori storage e renderer della pagina confronto restano invariati; `compare.aspx` cambia solo la versione dello script. Cache-buster coerente sui quattro chiamanti: `20261010-compare-drawer-empty-state-1a`.

Design Gate proporzionato: offcanvas/azioni del riferimento originale ONSUS `shop-default.html`, classi `tf-btn btn-fill` e CTA gia presenti nell'empty-state della pagina confronto KeepStore. Link nativo con destinazione e nome espliciti coerente con [W3C WAI H91](https://www.w3.org/WAI/WCAG21/Techniques/html/H91). Nessun redesign, CSS o benchmark generale retailer.

Harness esterno isolato Node con funzioni JavaScript reali e soli DOM/storage sintetici: **178 PASS**. Apertura vuota, add primo/multiplo, deduplica, remove intermedio/ultimo, clear e riapertura, limite 12, lettura/scrittura storage fallite, JSON non valido, pagina senza drawer; pagina confronto vuota/popolata e card drawer identiche alla base. Equivalenza completa sorgente esclusi CTA, classe iniziale, due righe renderer e quattro cache-buster PASS; sintassi JS, precompile ASP.NET Framework 4.8 safe PASS. Diff-check, manifest e secret scan richiesti prima del commit.

Skill Browser letta, ma interfaccia di esecuzione richiesta non disponibile: browser desktop/360/390, navigazione reale, overflow e accessibilita visuale NON CERTIFICATI. I test sintetici non sostituiscono il browser o lo smoke IIS. Preservati `web.config`, quattro cancellazioni tracked e 54 untracked con hash/inventario invariati, fuori staging. Nessun accesso DB, deploy, ordine, pagamento, e-mail, merge o task successivo.

**FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** soltanto `Page.master`, `Public/assets/keepstore/js/keepstore-product.js`, `Default.aspx`, `articoli.aspx`, `articolo.aspx`, `compare.aspx`, dopo review indipendente. Smoke: drawer vuoto e CTA, primo prodotto, ultimo remove/clear e riapertura, confronto popolato e pagina confronto esistente, desktop e mobile 360/390. Il catalogo complessivo resta aperto per i residui P1/P2.

### CATALOG-EMPTY-FACET-VISIBILITY-1A — CHIUSO / A / INTEGRATED

PR #336 verificata MERGED al commit `6ba454b910049f6e5c240b198a7f5d21ec418f86`, unico parent `edc6589bd67f23f02beca731006e308f5b1bb00b`. Review e smoke A comunicati dal Product Owner; copia canonica riallineata FF-only. Questa nota prevale sul checkpoint tecnico pre-merge seguente e non dichiara completo il catalogo.

### CATALOG-EMPTY-FACET-VISIBILITY-1A — A tecnico / B complessivo, review e smoke Product Owner pendenti

Base verificata `frontend-rebuild` / `origin/frontend-rebuild` = `edc6589bd67f23f02beca731006e308f5b1bb00b`; branch `task/catalog-empty-facet-visibility-1a`. Manifest esclusivo: `articoli.aspx`, `articoli.aspx.vb`, questo Masterplan. `main` / `origin/main` invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

I quattro contenitori ONSUS Marche, Tipologie, Gruppi e Sottogruppi hanno soltanto nuovi riferimenti server. I rispettivi handler DataList PreRender nascondono anche titolo e contenitore quando `Items.Count = 0`; le sezioni con opzioni restano integralmente presenti. Page_Load riapre i soli contenitori prima del binding per non ereditare una visibilita obsoleta dal ViewState; la decisione finale resta basata sui conteggi correnti. `FormView1`, `TitoloCategoria`, binding differito ricerca, chip, Offerte/Ricondizionati, Mostra altro oltre sette marche e autoespansione marca attiva restano invariati. Nessuna query, CSS, JS, postback aggiuntivo o logica commerciale.

Design Gate proporzionato: struttura originale ONSUS `shop-default.html` e contratti sidebar/adattivita multi-merceologia canonici, senza redesign o benchmark generale. Harness esterno isolato con handler VB reali, DataList/FormView/HtmlGenericControl e traversal PreRender WebForms reale: **231 PASS**, conteggi 0/1/7/8/50 e due dataset sintetici Tech/Food; wrapper e titolo assenti a zero, opzioni preservate, soglia Mostra altro, controllo categoria reperibile dopo hide/reset, chip e controlli commerciali indipendenti. Equivalenza completa sorgenti esclusi i soli riferimenti/assegnazioni di visibilita PASS: SQL, prezzi, promozioni, pager, URL e carrello invariati. Non e una verifica dei due tenant end-to-end o del listing MySQL.

Precompile ASP.NET Framework 4.8 safe, diff-check, manifest e secret scan richiesti prima del commit. Browser desktop/mobile non disponibile (Node REPL `js` assente): nessuna certificazione visuale, overflow o autoespansione interattiva. Nessun GET catalogo con scritture legacy, accesso DB, DML/DDL, operazione ecommerce, deploy o merge. Preservati `web.config`, quattro cancellazioni tracked e 54 untracked con hash/inventario invariati e fuori staging. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** soltanto `articoli.aspx` e `articoli.aspx.vb`, dopo review indipendente. Verificare sidebar con facet vuoti/popolati, ricerca/zero-results e chip, Mostra altro/marca attiva oltre sette su desktop e mobile. Nessun task successivo avviato.

### SEARCH-SUGGEST-REFURBISHED-BINARY-CONSISTENCY-1A — CHIUSO / A / INTEGRATED

PR #335 verificata MERGED al commit `edc6589bd67f23f02beca731006e308f5b1bb00b`, unico parent `9692bc2db9eca6bb7dd875716070744da0bdc88d`. Review e smoke A comunicati dal Product Owner; copia canonica riallineata FF-only. Questa nota prevale sul checkpoint tecnico pre-merge seguente, senza dichiarare completa la ricerca o il catalogo.

### SEARCH-SUGGEST-REFURBISHED-BINARY-CONSISTENCY-1A — A tecnico / B complessivo, review e smoke Product Owner pendenti

Base verificata `frontend-rebuild` / `origin/frontend-rebuild` = `9692bc2db9eca6bb7dd875716070744da0bdc88d`; branch `task/search-suggest-refurbished-binary-consistency-1a`. Manifest esclusivo: `search_suggest.aspx.vb`, questo Masterplan. `main` / `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

Due sole righe runtime autorizzate: `AppendFilterClauses` richiede `COALESCE(...Ricondizionato,0) = 1`; `MapSuggestions` assegna `item.IsRefurbished` solo per `ReadInt(...,0) = 1`. `0`, `NULL`, `2`, `-1` non classificano il prodotto come ricondizionato; nessuna inferenza dal settore. Ricerca testuale e recenti condividono questi metodi. `BuildBadges`, `BuildReason`, `SerializeItem`, `ReadFilters`, ranking, codice/EAN, prezzi/listini, URL e nomi JSON restano identici alla base. Nessun CSS/JS/markup o nuovo endpoint/query/configurazione. Catalogo #333/#334 invariato; il residuo MEDIUM search-suggest segnalato nel checkpoint precedente e risolto tecnicamente in questo perimetro, non ancora integrato.

Harness isolato con intero code-behind reale compilato e sole boundary DB/media/formattazione di budget sintetiche: **562 PASS**. Valori `0/1/2/-1/NULL`, badge/reason/JSON, Promo/Disponibile, prezzo e score, codice/EAN, query normale, filtro ricondizionati ON/OFF e recenti; due dataset tenant sintetici separati. SQL prodotto catturato e dati filtrati nel fake boundary, nessuna query MySQL eseguita. Parametri ricerca e order recent preservati; equivalenza completa sorgente dopo normalizzazione delle sole due righe PASS. Non e una certificazione dell'isolamento tenant end-to-end o del database reale; il resolver/configurazione tenant e invariato.

Precompile ASP.NET Framework 4.8 safe PASS con zero copie di configurazione operativa. Diff-check, manifest e secret scan delle aggiunte obbligatori prima del commit. Browser desktop/mobile, GET endpoint e smoke IIS NON ESEGUITI; nessuna certificazione visuale o suite generale ripetuta. Correzione meccanica della classificazione dati, nessuna nuova decisione UX/design o ampliamento funzionale.

Preservati `web.config`, quattro cancellazioni tracked e 54 untracked con hash/inventario invariati, fuori staging. Nessun accesso DB, DML/DDL, ordine, pagamento, e-mail, deploy, merge o task successivo. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** solo `search_suggest.aspx.vb`, dopo review indipendente. Non dichiarata completa la ricerca o il catalogo.

### CATALOG-REFURBISHED-BADGE-CONSISTENCY-1A — CHIUSO / A / INTEGRATED

PR #334 verificata MERGED al commit `9692bc2db9eca6bb7dd875716070744da0bdc88d`, unico parent `8737dc7c2264ef241abdb0bb35e2ec23621a19bc`. Review e smoke A comunicati dal Product Owner; copia canonica riallineata FF-only. Questa nota prevale sul checkpoint tecnico pre-merge seguente e non dichiara risolti altri moduli fuori manifest.

### CATALOG-REFURBISHED-BADGE-CONSISTENCY-1A — A tecnico / B complessivo, review e smoke Product Owner pendenti

Base verificata `frontend-rebuild` / `origin/frontend-rebuild` = `8737dc7c2264ef241abdb0bb35e2ec23621a19bc`; branch `task/catalog-refurbished-badge-consistency-1a`. Manifest esclusivo: `articoli.aspx`, `articoli.aspx.vb`, questo Masterplan. `main` / `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

**Regola commerciale definitiva Product Owner, multi-tenant:** soltanto il valore numerico `Ricondizionato=1` determina il badge; `0`, `NULL` e altri valori non lo mostrano. Il settore, incluso il 34, non classifica mai automaticamente il prodotto. Il gestionale e l'unico punto di decisione commerciale. Questa regola prevale sui checkpoint storici che descrivono un filtro nonzero o un fallback di settore; non autorizza modifiche ai dati o ad altri moduli.

Il precedente STOP B commerciale e risolto: il Product Owner ha corretto l'articolo `21813`. Verifica parametrizzata sul DB applicativo, in transazione read-only conclusa con rollback: flag attuale `1`, alias badge `visible`. Nessun dato modificato da Codex.

SELECT catalogo: proietta il flag autorevole `COALESCE(vsuperarticoli.Ricondizionato,0) AS Ricondizionato`; alias storico `refurbished` mantenuto, coerente con `=1`. Card inline e modello ProductCard usano entrambi `UiData.Int(dataItem, "Ricondizionato") = 1`, senza fallback settore/alias. Solo i due predicati listing/facet sono allineati da nonzero a `=1`, come autorizzato. Nessuna nuova query, modifica URL/helper filtro, prezzi/IVA/promo/listini/cart o classificazione DB. ProductCard.ascx e relativo code-behind restano invariati.

Design Gate proporzionato alla correzione meccanica: riferimento ONSUS esistente e contratti card/stack angolare gia approvati; nessuna nuova scelta visuale o benchmark generale. Markup badge, classe, testo, badge promo, CSS/JS e quattro viste restano identici, cambia soltanto la condizione server-side.

Harness isolato con UiData reale e condizioni VB estratte: **384 PASS**, flag `0/1/2/-1/NULL`, settori 34 e diversi, DataRow/DataRowView, flag assente, alias legacy ingannevole e due tenant sintetici; rendering PlaceHolder WebForms e condizioni delle quattro viste. Parita listing/facet verificata sui predicati reali e DataTable sintetica; non e un'esecuzione del listing MySQL. Equivalenza completa dei sorgenti esclusi i soli blocchi autorizzati PASS: prezzi, badge promo, URL, viste e carrello non modificati. Precompile ASP.NET Framework 4.8 safe PASS, zero copie di configurazione operativa. Diff-check, manifest e scan segreti delle aggiunte obbligatori prima del commit.

Finding separato MEDIUM, non blocker del catalogo: `search_suggest.aspx.vb` mantiene filtro e badge nonzero (`AppendFilterClauses` / assegnazione `item.IsRefurbished`); puo divergere dalla regola definitiva se vengono introdotti flag diversi da 0/1. File fuori manifest, invariato. Proposta `SEARCH-SUGGEST-REFURBISHED-BINARY-CONSISTENCY-1A`, NON AVVIATO, previa autorizzazione dopo review/smoke/chiusura di questo task. Nessuna dichiarazione di allineamento di tutte le superfici KeepStore.

Browser mobile/desktop e smoke IIS NON ESEGUITI: nessuna certificazione visuale/overflow o suite ecommerce reale. Nessun DML/DDL, ordine, pagamento, e-mail, deploy o merge. Preservati `web.config`, quattro cancellazioni tracked e 54 untracked con hash/inventario invariati, fuori staging. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** solo `articoli.aspx` e `articoli.aspx.vb`, dopo review indipendente. Nessun task successivo avviato.

### CATALOG-REFURBISHED-FACET-1A — CHIUSO / A / INTEGRATED

PR #333 verificata MERGED al commit `8737dc7c2264ef241abdb0bb35e2ec23621a19bc`, unico parent `c85a2983fff065059b82ee012d7c6bbe6cf413df`. Chiusura A comunicata dal Product Owner e copia canonica riallineata FF-only. Questa nota prevale sul checkpoint storico pre-merge seguente; la successiva regola binaria definitiva sopra sostituisce la precedente semantica nonzero.

### CATALOG-REFURBISHED-FACET-1A — A tecnico / B complessivo, review e smoke Product Owner pendenti

Base verificata `frontend-rebuild` / `origin/frontend-rebuild` = `c85a2983fff065059b82ee012d7c6bbe6cf413df`; branch `task/catalog-refurbished-facet-1a` dalla stessa base. Manifest esclusivo: `articoli.aspx`, `articoli.aspx.vb`, questo Masterplan. `main` / `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

Sidebar ONSUS: sezione `Condizione`, link server-side `Solo ricondizionati`, stato attivo e nome accessibile; disponibile anche nello zero-results. Soltanto un parametro `ricondizionato=1` attiva il filtro; parametro assente, invalido o duplicato resta inattivo. Chip removibile `Ricondizionati`. Toggle/chip riusano gli helper URL esistenti, preservano contesto tassonomico, ricerca, offerte/campagna e filtri compatibili, azzerano la paginazione. I reset esistenti rimuovono anche `ricondizionato`, mantenendo lo scope strutturale/commerciale previsto dal loro contratto.

Fonte esclusiva della condizione: `vsuperarticoli.Ricondizionato`. Predicato identico `COALESCE(vsuperarticoli.Ricondizionato,0) <> 0` aggiunto al listing e al WHERE condiviso dei conteggi facet, usando l'alias effettivamente presente nelle query. Nessuna query aggiuntiva, modifica di prezzi/IVA/promo/listini, classificazione tramite settore o nuovo filtro client-side. Renderer/card, quattro viste e carrello restano invariati a livello sorgente; non sono dichiarati collaudati su database reale.

Finding separato, NON corretto: il badge storico `phRefurbBadge` nel template catalogo puo ancora mostrare `Ricondizionato` per `st=34` / `SettoriId=34` anche senza flag. Inoltre l'alias SQL storico `refurbished` usa `Ricondizionato=1`, mentre il contratto filtro/search-suggest accetta qualunque valore non zero. Sono differenze statiche concrete: nessun prodotto reale classificato erroneamente e stato dimostrato senza accesso DB. Queste regole visuali non entrano nel predicato del nuovo filtro; nessuna introduzione di etichette Nuovo/Usato.

Design Gate proporzionato: riferimento originale ONSUS `shop-default.html`, struttura facet esistente e classi link gia presenti; controllo HTML nativo con stato/nome accessibile secondo [W3C WAI H91](https://www.w3.org/WAI/WCAG22/Techniques/html/H91). Nessun CSS/JS, redesign o benchmark generale.

Verifiche isolate: metodi VB e binding WebForms reali estratti, URL attiva/disattiva/chip/reset, combinazioni tassonomia/ricerca/marca/prezzo/disponibilita/offerte/campagna/pagina, invalidi/duplicati, due host sintetici e parita predicato listing/facet: **400/400 PASS**. Il predicato reale viene valutato su DataTable sintetica con NULL/zero/nonzero e settore 34, inclusi conteggi marca e zero-results; non e un'esecuzione SQL MySQL. Equivalenza del metodo commerciale escluso il solo predicato autorizzato e metodi promo/card invariati PASS. Precompile ASP.NET Framework 4.8 safe PASS, zero copie di configurazione operativa. Diff-check, manifest e secret scan delle aggiunte obbligatori prima del commit.

Browser reale/viewport, GET catalogo e risultati DB NON ESEGUITI. Nessun accesso DB, DML/DDL, ordine, pagamento, e-mail, deploy o merge. Review indipendente e smoke Product Owner restano gate separati. Preservati `web.config`, quattro cancellazioni tracked e 54 untracked con hash/inventario invariati, fuori staging. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** solo `articoli.aspx` e `articoli.aspx.vb`. Nessun task successivo avviato, nessuna dichiarazione di catalogo completo.

### CATALOG-DEALS-FACET-1A / REV1 — CHIUSO / A / INTEGRATED

PR #332 verificata MERGED al commit `c85a2983fff065059b82ee012d7c6bbe6cf413df`, parent `08969a24036644db70ac54698d9d6b584122b13e`. Chiusura A comunicata dal Product Owner; stable locale/origin riallineata solo FF-only. Questa nota prevale sul checkpoint tecnico pre-merge seguente.

### CATALOG-DEALS-FACET-1A / REV1 — A tecnico / B complessivo, review e smoke Product Owner pendenti

Base verificata `frontend-rebuild` / `origin/frontend-rebuild` = `08969a24036644db70ac54698d9d6b584122b13e`; PR #331 MERGED. Branch `task/catalog-deals-facet-1a` dalla stessa base. `main` / `origin/main` invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Manifest esclusivo: `articoli.aspx`, `articoli.aspx.vb`, questo Masterplan.

Il blocker precedente e riprodotto con il metodo VB reale: `Session("InOfferta")=1` manteneva attivo il catalogo offerte dopo la rimozione di `inpromo`. REV1 autorizzata: il filtro corrente dipende esclusivamente dall'URL `inpromo=1`; `inpromo=0` e assenza del parametro non sono riattivati da `Session("InOfferta")` o `Session("Promo")`. Nessun nuovo stato Session. I link storici di `promo.aspx` con solo `pid` vengono normalizzati mediante redirect locale verso lo stesso URL con `inpromo=1`, prima del binding: campagne valide e input invalidi/duplicati attraversano `TryReadPromotionCampaignId` e il provider autorevole gia esistenti. Con `inpromo=0` il `pid` dipendente viene rimosso. `promo.aspx`, provider, SQL commerciale, prezzi, IVA, listini, owner e regole quantita restano invariati.

Sidebar: sezione `Offerte`, link server-side `Solo offerte`, classe attiva e testo `Attivo`, label accessibile che indica azione/stato, URL con encoding dell'attributo. Il controllo resta fuori dal pannello facet differito, quindi e disponibile anche nello zero-results. Il toggle mantiene settore/categoria, ricerca e filtri compatibili; conserva `pid` nell'attivazione, rimuove `inpromo` e `pid` nella disattivazione e azzera le chiavi di paginazione. Disattivazione e chip `In offerta` riusano lo stesso helper. Il reset generale conserva intenzionalmente lo scope offerte gia presente nell'URL, come da contratto esistente; dopo disattivazione, reset/refresh/navigazione neutra non lo riattivano.

Design Gate proporzionato: esaminata la struttura `widget-facet / facet-fieldset / box-fieldset-item / fieldset-item` del riferimento originale `shop-default.html` disponibile nella copia storica esterna al repository; adattamento tramite i link facet e classi gia presenti nel catalogo corrente, nessuna checkbox demo/nuova logica JavaScript. Fonte accessibilita aggiornata: [W3C WAI H91](https://www.w3.org/WAI/WCAG22/Techniques/html/H91), controllo HTML nativo con nome accessibile e navigazione da tastiera. Nessun redesign, CSS/JS nuovo o dichiarazione di benchmark visuale retailer completo.

Verifiche isolate dei metodi VB reali e rendering WebForms del link: **692/692 PASS**; sei casi del blocker, attiva/disattiva/refresh/reset/chip, campagne valide/invalide/duplicate, settore/categoria, ricerca, marca, prezzo, disponibilita e pagina, due host sintetici. Compilati anche provider e SQL builder reali: parametri separati per due aziende/listini sintetici, owner anonimo azzerato e guard SQL azienda/owner/campagna invariati. Prova di equivalenza di `CaricaArticoli` esclusa la sola assegnazione legacy rimossa: query e regole commerciali non cambiano. I test SQL verificano generazione/parametrizzazione, non eseguono query o certificano risultati di un database reale. Precompile ASP.NET Framework 4.8 safe PASS, senza copie di configurazione operativa. Diff-check, manifest e secret scan delle aggiunte PASS prima del commit.

Browser reale e viewport 360/390/tablet/desktop NON ESEGUITI; nessun GET sul catalogo per evitare scritture legacy. Nessun accesso DB, ordine, pagamento, e-mail, deploy o merge. Review indipendente e smoke Product Owner restano gate separati. Preservare `web.config`, quattro cancellazioni tracked e 54 untracked fuori staging. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** solo `articoli.aspx` e `articoli.aspx.vb`. Nessun task successivo avviato e nessuna dichiarazione di catalogo completo.

### CATALOG-LEGACY-SHOP-HANDLER-ISOLATION-1A — CHIUSO / A / INTEGRATED

PR #331 verificata MERGED al commit `08969a24036644db70ac54698d9d6b584122b13e`, unico parent `b021a5453a6ae2f7143a333598557df7fe3e45a4`. Review e smoke Product Owner A comunicati; stable locale/origin riallineata esclusivamente FF-only. Questa nota prevale sul checkpoint tecnico pre-merge seguente.

### CATALOG-LEGACY-SHOP-HANDLER-ISOLATION-1A — A tecnico / B complessivo, review e smoke Product Owner pendenti

Base esatta verificata `frontend-rebuild` / `origin/frontend-rebuild` = `b021a5453a6ae2f7143a333598557df7fe3e45a4`; PR #330 MERGED. Branch `task/catalog-legacy-shop-handler-isolation-1a` dalla stessa base. `main` / `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Il Product Owner ha autorizzato per questo task il gate alternativo Node/DOM isolato al posto del Browser non disponibile e il manifest definitivo di cinque file, inclusi i soli cache-buster nei chiamanti.

Due guard sull'esistente `#ksCatalogPage`: `shop.js` ritorna da `filterProducts()` prima di registrare i binding demo; `catalog-ui.js` ritorna da `renderActiveFilters()` prima di cercare/creare/svuotare l'host chip. Sono preservati chip e URL server-side anche quando l'ID WebForms dell'host e prefissato o l'host e assente nello zero-results. Nessun return globale, rimozione asset, nuova logica URL, query o filtro commerciale. `loadmoreFilter()` e auto-expand della marca attiva restano identici alla base. `filterSort()` e `filterPrice()` restano invariati: il markup reale del catalogo usa select WebForms e non presenta i rispettivi trigger `.select-item`, `.min-price`, `.max-price`, `.btn-filter-price`. Le pagine senza marker conservano gli handler preesistenti.

Design Gate proporzionato al fix meccanico: reference del `shop.js` originale gia versionato, gerarchia e contratti del catalogo KeepStore conservati; nessun redesign o benchmark generale. `shop-default.html` non trovato nel package locale consultato; nessuna dichiarazione di nuovo audit visuale completo. I due URL script usano `v=20261010-catalog-legacy-isolation1a` per non riutilizzare asset stale.

Manifest esclusivo: `Public/assets/keepstore/js/shop.js`, `Public/assets/keepstore/js/catalog-ui.js`, `Page.master` (solo cache-buster shop), `articoli.aspx` (solo cache-buster catalog-ui), questo Masterplan. Harness Node con adapter DOM/jQuery controllato, senza nuove dipendenze: **270/270 PASS**, 15 scenari su generale, settore/categoria, offerte con `pid`, filtri/pagina combinati e ricerca senza risultati; host esatto, ID prefissato e host assente. Eseguiti i file JS reali: riproduzione del reset legacy che svuota chip/riscrive conteggio sulla base; dopo fix assenza di binding concorrenti, nessun host client aggiunto, chip/URL/conteggi/card/prezzi preservati, load-more inizializzato con limite sette e successiva espansione, auto-expand della marca oltre posizione sette, comportamento senza marker. Prova di equivalenza del resto dei due JS e dei chiamanti, esclusi soltanto guard/cache-buster: viste, pager, ordinamento, page-size, prezzo, multiselect e carrello non modificati.

Sintassi JS e precompile ASP.NET Framework 4.8 safe **PASS**, zero copie di configurazioni operative. Il harness non e un browser reale: nessuno smoke browser automatizzato, misura viewport, prova layout o GET al catalogo dichiarato PASS. Review indipendente e smoke manuale Product Owner rimangono gate separati; nessun merge, deploy, DB write, ordine, pagamento o invio esterno. Preservare `web.config`, quattro cancellazioni tracked e 54 untracked fuori staging.

**FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** `Public/assets/keepstore/js/shop.js`, `Public/assets/keepstore/js/catalog-ui.js`, `Page.master`, `articoli.aspx`. Smoke manuale massimo tre verifiche: (1) desktop/mobile, filtri combinati/offerte, chip singolo e reset conservano contesto e conteggi coerenti; (2) Marche oltre sette, Mostra altro e marca attiva oltre posizione sette; (3) ordinamento/page-size, quattro viste e reset zero-results senza regressioni. Nessun trasferimento/deploy eseguito da Codex. Questo micro-task non dichiara completo il catalogo.

### CATALOG-ZERO-RESULTS-RESET-CONTEXT-1A — CHIUSO / A / INTEGRATED

PR #330 verificata MERGED al commit `b021a5453a6ae2f7143a333598557df7fe3e45a4`, unico parent `0417b891b9244e4ad1bc2649359a0340c8924250`. Integrazione FF-only e chiusura A comunicate dal Product Owner; stable locale/origin allo stesso commit. Questa nota prevale sul report tecnico pre-merge seguente.

Base verificata `frontend-rebuild` / `origin/frontend-rebuild` = `0417b891b9244e4ad1bc2649359a0340c8924250`; PR #329 MERGED. Copia canonica gia allineata alla base, nuovo branch `task/catalog-zero-results-reset-context-1a`. `main` / `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

Nell'`EmptyDataTemplate` di `articoli.aspx`, il solo link `Reset filtri` riusa ora `ClearCatalogFiltersUrl`, con encoding HTML dell'attributo come i reset desktop/mobile esistenti. Il link distinto `Vai al catalogo` resta `articoli.aspx`, senza query. Nessuna nuova funzione o logica URL: il builder esistente rimuove ricerca, tipologia, facet, prezzi, disponibilita, ordinamento, varianti e paginazione; conserva `st`, `ct`, `inpromo`, `pid` e gli altri parametri non rimossi dal contratto corrente. Code-behind, query, filtri commerciali, prezzi, SEO, carrello, JS e CSS invariati.

Manifest esclusivo: `articoli.aspx` e questo Masterplan. Harness isolato delle funzioni URL reali estratte: **262/262 PASS**, 10 casi su due host sintetici, generale, settore/categoria con filtri, ricerca senza risultati, offerte con/senza `pid`, combinazione completa e pagina. Verificati destinazione esatta, conservazione del contesto, rimozione dei filtri, reset idempotente, encoding dell'attributo e destinazione generale della seconda CTA. Contratto markup **3/3 PASS**; precompile ASP.NET Framework 4.8 safe **PASS**, zero copie di configurazione operativa. Nessun GET al runtime catalogo e nessun accesso DB: i casi zero-results sono fixture isolate, non una certificazione visuale o funzionale server del Product Owner. Review indipendente e smoke Product Owner ancora pendenti; nessun merge, deploy o task successivo.

Diff-check, manifest e secret scan delle aggiunte **PASS**. `web.config`, quattro cancellazioni tracked preesistenti e 54 untracked preservati con hash/inventario invariati; nessuno appartiene al commit. **FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** soltanto `articoli.aspx`. Questo micro-task non dichiara completo il catalogo.

### CATALOG-MOBILE-RESET-CONTEXT-1A — CHIUSO / A / INTEGRATED

PR #329 verificata MERGED al commit `0417b891b9244e4ad1bc2649359a0340c8924250`, parent `5a1332a729a151c3275d48e70c94e9cdb2cbc8d3`. Un commit e due file; reset mobile contestuale integrato. Questa nota prevale sul report tecnico pre-merge riportato sotto.

Base `frontend-rebuild` / `origin/frontend-rebuild` = `5a1332a729a151c3275d48e70c94e9cdb2cbc8d3`; PR #328 MERGED e `CATALOG-TAXONOMY-H1-CONTEXT-1A` **CHIUSO / A / INTEGRATED** con review e smoke Product Owner A. Nuovo branch `task/catalog-mobile-reset-context-1a` dalla stessa base. `main` / `origin/main` invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

Nel drawer mobile di `articoli.aspx`, `Reset filtri` ora riusa `ClearCatalogFiltersUrl`, come desktop `Rimuovi tutto`. Non aggiunge logica: il builder esistente rimuove q, tp, facet/gruppo/sottogruppo, disponibilita, prezzi, ordinamento, varianti e pagina, mantenendo settore/categoria e gli altri parametri non elencati, incluso `inpromo`/scope offerte. Nessuna query DB aggiunta; `ClearCatalogFiltersFromUrl`, i singoli chip, route e filtri restano invariati. L'escaping HTML server-side e applicato all'attributo URL come per il link desktop.

Manifest: `articoli.aspx` e questo Masterplan. Harness delle funzioni URL reali estratte: **95 PASS** su catalogo generale, settore, settore+categoria, offerte e combinazione completa con pagina `pg>1`; verifica rimozione di ricerca, tp, mr, gr, sg, prezzi, disponibilita, ordinamento, varianti e paginazione, con conservazione di `st`, `ct`, `inpromo`, `pid` e parametri estranei. GET locali read-only **4/4 HTTP 200**: generale, st, st+ct e filtri combinati; il link desktop compare solo quando esistono filtri attivi e in quel caso il suo URL e identico al reset mobile. Caso combinato: destinazione `st=2&ct=35&inpromo=1`. Precompile ASP.NET Framework 4.8 safe PASS; diff-check/manifest/secret scan PASS. Nessuna query o scrittura DB aggiunta, nessun deploy o merge.

### CATALOG-TAXONOMY-H1-CONTEXT-1A — CHIUSO / A / INTEGRATED

PR #328 MERGED fast-forward al commit `5a1332a729a151c3275d48e70c94e9cdb2cbc8d3`, parent `d41fa5a11b798011518cfafabd3435167bad5958`. Un commit e tre file: `articoli.aspx`, `articoli.aspx.vb`, Masterplan. H1 visibile, semantico e HTML encoded da `CatalogTaxonomyContext.MostSpecificName`, senza query aggiuntive; titolo piu specifico con fallback Catalogo. Precompile, harness resolver/encoding e GET locali PASS; review indipendente e smoke Product Owner A. Nessuna modifica a SEO, breadcrumb, filtri/prezzi o resolver. Nessuna certificazione ulteriore dell'intero catalogo.

Base autorizzata e stable verificata `d41fa5a11b798011518cfafabd3435167bad5958`; PR #327 verificata MERGED. `HEADER-DESKTOP-CATALOG-CURRENT-PATH-1A` e **CHIUSO / A / INTEGRATED**, review e smoke Product Owner A acquisiti; questa nota prevale sul checkpoint storico pre-merge sotto. Copia canonica riallineata fast-forward prima del branch `task/catalog-taxonomy-h1-context-1a`. `main` / `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

Unico H1 visibile del catalogo: `CatalogTaxonomyContext.MostSpecificName` dal contesto request-scoped gia usato dal breadcrumb, con `Literal Mode="Encode"` e ViewState disabilitato. Tipologia valida, categoria, settore, poi `Catalogo`; genitori discordanti e figli invalidi seguono esattamente il resolver esistente, senza nuova classificazione. Un figlio invalido non elimina un genitore indipendente valido. Query libera, offerte e facet non diventano nomi tassonomici. Il blocco prima nascosto ora mostra soltanto il titolo; i suoi contatori legacy restano nascosti come prima, senza duplicare la toolbar.

Design Gate proporzionato: esaminato il riferimento ONSUS locale `shop-default.html`, struttura container/breadcrumb/catalogo senza hero aggiuntivo; [W3C WAI headings](https://www.w3.org/WAI/tutorials/page-structure/headings/) per titolo descrittivo e semantico. KeepStore mantiene il breadcrumb e aggiunge un H1 compatto usando esclusivamente classi gia disponibili (`py-3`, `h4`, `mb-0`, `text-break`), senza nuovo CSS o cache-buster. Nessuna dichiarazione di benchmark visuale retailer o certificazione mobile: browser interattivo non disponibile; viewport 360/390/768/1365 e layout reali restano al gate visuale Product Owner.

Manifest effettivo: `articoli.aspx`, `articoli.aspx.vb`, questo Masterplan. Binding runtime: una sola assegnazione aggiunta prima del breadcrumb. Restante code-behind identico alla base: Title SEO, canonical, robots, JSON-LD, resolver, query SQL, listing/facet/prezzi, filtri, ricerca, paginazione e carrello invariati. HOME/PDP/header/mobile #325–#327 e cache non modificati; nessuna nuova query DB.

Verifiche: binding reale estratto + rendering Literal/encoding **22 PASS**, due tenant sintetici Tessuti/Alimenti, stessa gerarchia con nomi distinti, fallback, parent mismatch, tipologia e testo lungo; harness resolver esistente **89 PASS**. Precompile ASP.NET Framework 4.8 safe PASS, zero copie di configurazione operativa. GET catalogo generale/S/C/T/settore inesistente/q/offerte/filtri combinati HTTP 200: esattamente un H1, nessun antenato nascosto. `ct=35` e `st=1&ct=35` conservano HTTP 302 della normalizzazione preesistente, senza seguire redirect. HOME/PDP sorgenti invariati. Manifest/diff-check/scan delle aggiunte per pattern segreti PASS; HTTP/markup non equivalgono a certificazione visuale. Preservati `web.config`, quattro cancellazioni e 54 untracked; soltanto `promotion-display.log` riceve append runtime gia autorizzati durante i GET e resta fuori staging, senza reset del log. Nessun DB write, deploy, ordine, pagamento, e-mail o merge.

**FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER:** soltanto `articoli.aspx` e `articoli.aspx.vb`. Review indipendente e smoke prima di qualsiasi merge. Questo task non dichiara completo il catalogo: filtri residui, informazioni commerciali e verifica complessiva catalogo/PDP restano separati e NON AVVIATI.

### HEADER-DESKTOP-CATALOG-CURRENT-PATH-1A — A tecnico / B complessivo, review e smoke Product Owner pendenti

Base autorizzata `frontend-rebuild` / `origin/frontend-rebuild` = `d847823737838789faea4f6270de47f8e2598778`. PR #326 verificata MERGED; `HEADER-MOBILE-CATALOG-PROGRESSIVE-PANELS-1A` **CHIUSO / A / INTEGRATED**, review e smoke server A comunicati dal Product Owner. Questa nota prevale sul checkpoint storico pre-merge sotto. Copia canonica riallineata FF-only prima del nuovo branch `task/header-desktop-catalog-current-path-1a`. `main` / `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

Design Gate proporzionato: applicato il design gia approvato in `KEEPSTORE_NAVIGATION_UX_BENCHMARK.md`, slice desktop percorso corrente; nessun nuovo audit generale o benchmark. Mega-menu originale ONSUS a due aree e albero KeepStore preservati. Contesto tassonomico #322 gia risolto per i select ricerca conservato soltanto nell'istanza del controllo della request e riusato dal renderer desktop. Nessun secondo resolver, chiamata provider o SQL aggiunta. Un solo link piu specifico valido emette `aria-current="location"` e `data-ks-current-path="current"`; antenati marcati `ancestor`, settore contenitore identificato per l'anteprima iniziale. Contesto neutro/invalidita non marca il primo settore; discordanza di genitori validi segue il resolver autorevole, senza modificarlo.

CSS soltanto desktop >=1200px: posizione reale con indicatore laterale persistente, nodo corrente sottolineato e colore/sfondo del tema; anteprima hover/focus usa superficie neutra e non modifica marcature, query, ricerca o URL. Il pannello iniziale mostra il settore reale quando disponibile; in assenza di contesto il primo pannello rimane semplice anteprima non selezionata. Focus ha precedenza sull'hover e outline visibile. Conservati tutti i link, testi, ordine e destinazioni, senza nuovo JavaScript o markup mobile.

Manifest effettivo: `Public/ui/controls/SiteHeader.ascx.vb`, `Public/assets/keepstore/css/theme-overrides.css`, `Page.master` (solo cache-buster CSS) e questo Masterplan. `SiteHeader.ascx`, JS, resolver/provider/cache, route, breadcrumb/JSON-LD e componenti commerciali invariati. GET locali HTTP 200 su HOME/PDP e settore inesistente: zero current/ancestor; settore valido: un current e zero antenati; categoria: un current/un antenato; tipologia: un current/due antenati. Category-only e mismatch conservano HTTP 302 della normalizzazione esistente, senza seguire redirect; harness verifica la derivazione autorevole. 678 destinazioni mobile nelle risposte server-side verificate; non e una prova DOM/browser. Preservati `web.config`, quattro cancellazioni tracked e 54 untracked con hash/inventario invariati; zero DB write, deploy o mutazioni ecommerce.

Verifiche: harness con metodi reali estratti **142 PASS** su due tenant sintetici, contesti neutro/S/C/T/invalidi/duplicati/discordanti, primo/ultimo settore, nomi lunghi, 40 categorie e tutti gli URL/testi/ordine invariati. Regressioni rendering **37 PASS**, current-scope **341 controlli / 31 scenari PASS**, cache **49 PASS**, statici **7 PASS**; script storico adattato solo in memoria per il manifest corrente e campo request-scoped, nessun Tools modificato. Harness sintetico pannelli mobile #326 **39 PASS**. Precompile ASP.NET Framework 4.8 safe PASS; diff-check, manifest e scan delle aggiunte per pattern segreti obbligatori prima del commit. Browser interattivo non disponibile: desktop 1365/1920, mobile 360/390/768, geometria/overflow e tastiera/hover reali **NON ESEGUITI da Codex**, non dedurre A visuale dai test del renderer. Review indipendente e smoke server obbligatori prima del merge; nessun task successivo avviato.

### HEADER-MOBILE-CATALOG-PROGRESSIVE-PANELS-1A — A tecnico / B complessivo, review e smoke Product Owner pendenti

Base autorizzata `frontend-rebuild` / `origin/frontend-rebuild` = `29f3ca87ec524d51e4772be2fc4e3a7a42ad8db9`. PR #325 verificata MERGED; `HEADER-MOBILE-CATALOG-ENTRY-DISCOVERABILITY-1A` **CHIUSO / A / INTEGRATED**, smoke server A comunicato dal Product Owner. Questa nota prevale sul checkpoint storico pre-merge riportato sotto. Branch corrente `task/header-mobile-catalog-progressive-panels-1a`; `main` / `origin/main` protetti a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Nessun merge o deploy autorizzato per questo nuovo task.

Design gia approvato nel task di navigazione: riferimento ONSUS offcanvas/collapse, navigazione progressiva con accesso Vedi tutto al livello corrente e gerarchia KeepStore autorevole. Nessun nuovo benchmark o audit generale. Il mobile riutilizza e sposta gli stessi pannelli server-rendered, senza clonare albero, destinazioni o controlli ricerca. Bootstrap rimane l'unico proprietario degli stati collapse/offcanvas: l'adattatore usa API ed eventi ufficiali per presentare un livello commerciale alla volta, con Indietro, titolo contestuale, focus e scroll per livello. Nessuna animazione aggiuntiva; desktop, query, provider, resolver e current-scope invariati.

Settori all'apertura iniziale; categorie e tipologie nei livelli successivi. Indietro non naviga e ripristina focus/scroll; chiusura/riapertura nello stesso documento conserva il percorso, una nuova GET riparte dalla radice. Ricerca unica fuori dallo scroller dei prodotti; contenuto menu e utility condividono lo scroller. CSS mobile-only senza indentazione cumulativa, target 44/48px, fallback per viewport di altezza ridotta. Senza adattatore resta il menu Bootstrap originale; senza JavaScript il medesimo albero viene reso leggibile dal fallback noscript. Nessun nuovo endpoint, fetch, storage, dipendenza o controllo WebForms. Cache-buster CSS/JS aggiornati esclusivamente in `Page.master`.

Manifest effettivo: `Public/ui/controls/SiteHeader.ascx`, `Public/assets/keepstore/css/theme-overrides.css`, `Public/assets/keepstore/js/ks-page-flags.js`, `Page.master` (solo version string) e questo Masterplan. `SiteHeader.ascx.vb` non necessita modifiche; nessun Tools modificato. GET locali anonimi HOME, catalogo `st=2&ct=35`, PDP `id=21906`: **HTTP 200**, 678 destinazioni catalogo mobile, tre controlli ricerca mobile unici e una toolbar in ogni risposta. Questi risultati descrivono l'HTML server-side, non il DOM live dopo JavaScript. Diff-check e scan delle aggiunte per pattern di segreti PASS. Preservati `web.config`, quattro cancellazioni tracked preesistenti e 54 untracked con hash/inventario invariati. Zero DB write, ordini, pagamenti, gateway, e-mail o deploy.

Verifiche tecniche: precompile ASP.NET Framework 4.8 safe PASS; sintassi JS PASS; harness sintetico DOM/API **39 PASS** su due tenant, livelli/back/focus/scroll/riapertura/fallback/URL e assenza rete/storage. Questo harness non esegue un browser o il vero Bootstrap. Regressioni con script storico adattato soltanto in memoria per escludere le superfici ora autorizzate: renderer **37 PASS**, current-scope **341 controlli / 31 scenari PASS**, cache **49 PASS**, invarianti statici **8 PASS**. La matrice browser 360/390/tablet/desktop, Escape/touch, overflow e accessibilita visuale resta **NON ESEGUITA da Codex**, per assenza dell'interfaccia browser; non dichiarare A visuale. Review indipendente e smoke server Product Owner obbligatori prima del merge. `HEADER-DESKTOP-CURRENT-PATH-1A` e ogni altro task successivo **NON AVVIATI**.

### HEADER-MOBILE-CATALOG-ENTRY-DISCOVERABILITY-1A — A tecnico / B complessivo, smoke Product Owner pendente

Base autorizzata e stable corrente: `frontend-rebuild` / `origin/frontend-rebuild` = `7600422be83d7708253b33e5b7a11d6fb95fece9`; PR #324 verificata MERGED. Branch dedicato `task/header-mobile-catalog-entry-discoverability-1a`; manifest esclusivo `Public/ui/controls/SiteHeader.ascx` e questo Masterplan. Design e implementazione autorizzati dal Product Owner: nessun nuovo audit o benchmark, nessun merge/deploy implicito. `main` / `origin/main` invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.

Modifica minima del solo markup mobile: Catalogo prima di Home; button root senza `collapsed`, `aria-expanded="true"`, contenitore `#ks-mobile-catalog-root` con `collapse show`. Bootstrap conserva target/controlli e gestione degli stati; nessun reset alla riapertura del drawer. Settori/categorie interni inizialmente chiusi; tutti i nodi, ordine, testi, URL `st/ct/tp`, Vedi tutto, ricerca, desktop e compattazione #323 preservati. Nessun nuovo CSS/JS, endpoint, query, filtro, pannello progressivo o valore hardcoded.

Gate tecnici: confronto esatto con la base ammette soltanto spostamento Home e due stati root; parita di tutti i template/link e controlli WebForms PASS, root interno ancora compatto. Regressioni riusate senza modificare Tools: renderer #323 37 controlli, current-scope #322 341, cache #321 49, 11 controlli statici PASS. Le due asserzioni storiche di ordine/stato root sono sostituite solo in memoria dal gate esatto della modifica corrente; renderer e harness reali invariati. Fixture sintetiche di due tenant, rami senza figli/null e catalogo locale grande verificati, senza DB write. Precompile ASP.NET Framework 4.8 con configurazione sintetica PASS; diff-check, manifest e secret scan obbligatori prima del commit.

Smoke GET tenant-aware locale `www.taikun.it:8443`, connessione esclusivamente loopback: HOME, catalogo `st=2&ct=35` e PDP HTTP 200, root `collapse show` e 678 destinazioni su ciascuna pagina. Primo tentativo sandbox TLS non eseguibile, primo GET fuori sandbox in timeout; successiva terna conclusa 200, nessun intervento IIS/cache/configurazione. Browser interattivo non disponibile: matrice 360x800 / 390x844 / 768x1024 / 1365x900, touch/tastiera/focus, overflow, scroll e chiusura/riapertura NON ESEGUITI, riservati allo smoke Product Owner. Nessun PASS visuale dedotto dall'HTML.

Working copy canonica sul task branch con file runtime pronti: copiare per lo smoke server **esclusivamente `Public/ui/controls/SiteHeader.ascx`**, non docs o Tools. Preservati `web.config`, quattro cancellazioni tracked e tutti i 54 untracked con hash/inventario invariati e fuori staging. Un solo commit e PR DRAFT verso `frontend-rebuild`; review indipendente e smoke server restano gate pre-merge. Prossimo candidato `HEADER-MOBILE-CATALOG-PROGRESSIVE-PANELS-1A`: NON AVVIATO, richiede chiusura della slice corrente e manifest/autorizzazione propri.

### STOREFRONT-NAVIGATION-UX-BENCHMARK-1A — CHIUSO / A / INTEGRATED

Nota di prevalenza 2026-10-09: PR #324 MERGED al commit `7600422be83d7708253b33e5b7a11d6fb95fece9`, parent `ab471b6e95da1fcda101ef4f5dfbe27985a3e381`; design approvato. Il checkpoint sottostante descrive la consegna documentale originaria; la prima slice e ora autorizzata e implementata come indicato sopra. Le altre due slice restano NON AVVIATE. Il documento UX integrato non e stato modificato dal task runtime.

Base verificata e stable corrente: `frontend-rebuild` / `origin/frontend-rebuild` = `ab471b6e95da1fcda101ef4f5dfbe27985a3e381`; PR #323 MERGED. Working copy canonica sincronizzata FF-only alla medesima base, preservando `web.config`, quattro cancellazioni tracked e 54 untracked. `main` / `origin/main` invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Questo checkpoint prevale sugli stati storici sotto: cache #321, current-scope #322 e compattazione #323 non sono task da riavviare.

Consegna docs-only sul branch `task/storefront-navigation-ux-benchmark-1a`: [KEEPSTORE_NAVIGATION_UX_BENCHMARK.md](KEEPSTORE_NAVIGATION_UX_BENCHMARK.md). Design Gate: reference ONSUS locale (HTML/SCSS/JS), IKEA/Decathlon e MediaWorld consultati il 2026-10-09 tramite fonti pubbliche, Baymard/W3C e architettura KeepStore. Matrice, proposta 360/390 e 1365px e roadmap massima di tre slice. Browser interattivo non disponibile: comportamento visuale/touch dei retailer e nuova UX KeepStore non certificati; nessuna nuova suite, query DB, modifica runtime, deploy o merge.

Un solo primo micro-task raccomandato: `HEADER-MOBILE-CATALOG-ENTRY-DISCOVERABILITY-1A`, mostrare il primo livello reale gia espanso all'apertura del drawer e prima di Home, conservando tutti i nodi, ricerca e Bootstrap; superficie runtime prevista solo `Public/ui/controls/SiteHeader.ascx`. Poi, se approvati, `HEADER-MOBILE-CATALOG-PROGRESSIVE-PANELS-1A` e `HEADER-DESKTOP-CATALOG-CURRENT-PATH-1A`. Tutti **NON AVVIATI**: ChatGPT deve approvare design/priorita e manifest prima dell'implementazione. Nessuna chiusura globale della navigazione; crescita DOM/ViewState, lazy loading e handler legacy LOW restano separati.

### HEADER-MENU-MARKUP-COMPACTION-1A — CHIUSO / A / INTEGRATED

Base originaria: `c4e1d25f9e4e47725461115fbc8d6ce17a20dd6a`, PR #322 MERGED; `HEADER-CURRENT-SCOPE-1A` e CHIUSO / A / INTEGRATED con smoke production Product Owner A. **PR #323 verificata MERGED**, unico commit `ab471b6e95da1fcda101ef4f5dfbe27985a3e381`, parent diretto pari alla base originaria; integrazione fast-forward, zero merge commit. Review indipendente e **smoke production Product Owner A** acquisiti. Working copy canonica ora riallineata alla nuova stable. `main` / `origin/main` restano `976e99f17cabc8a5c6a8715463444edfeaadcd91`. La chiusura vale per la compattazione, non per l'intera navigazione; nessun nuovo deploy eseguito dal successivo task documentale.

Scope esclusivamente presentazionale: compattato il whitespace inter-tag nei template del catalogo mobile di `Public/ui/controls/SiteHeader.ascx`; rimossi soltanto gli span senza attributi dei link tipologia, mobile e desktop (`SiteHeader.ascx.vb`). Nessun filtro o troncamento della tassonomia; provider/cache #321, resolver/current-scope #322, repeater, dati, URL, ordine, encoding, search, attributi ARIA, target Bootstrap, icone, CSS e JS restano invariati. Nessun nuovo endpoint, lazy loading, dipendenza o redesign. I template sono intenzionalmente compatti: non reintrodurre l'indentazione serializzata per ogni tipologia senza misurarne l'impatto.

Design Gate proporzionato: riutilizzato l'audit precedente del riferimento ONSUS `shop-default.html` disponibile localmente e dei contratti KeepStore. Riferimenti gia registrati nel Masterplan: W3C APG/WAI e Baymard search scope; consultati anche [Baymard View All](https://baymard.com/research-articles/mobile-main-nav-view-all) e [categorie principali mobile](https://baymard.com/research-articles/main-navigation-product-categories). IKEA/Decathlon restano riferimenti proposti dal Product Owner per il futuro confronto UX, non benchmark visuali certificati da questa compattazione.

| Aspetto | ONSUS originale | Benchmark pertinente | KeepStore corrente | Decisione |
| --- | --- | --- | --- | --- |
| Navigazione mobile | Offcanvas e collapse annidati | Disclosure e accesso al livello intero | Un solo offcanvas, button separati dai link Vedi tutto | Conservare interazioni e tutte le destinazioni |
| Tassonomia | Esempi statici del template | Categorie riconoscibili e progressive | Tree reale condiviso dal provider cached | Nessun limite, omissione o nuova sorgente |
| Markup tipologie | Link, talvolta con span decorativo | Semantica dei link e nomi accessibili | Span senza attributi, nessun selettore necessario trovato | Rimuovere solo questi wrapper, senza cambiare etichette |
| Prestazioni | Struttura di riferimento, non budget dati | DOM strettamente necessario | Entrambe le versioni server-rendered | Eliminare sprechi; nessun caricamento differito in questa slice |

Prova runtime locale GET-only su HOME, catalogo `st=2&ct=35` e PDP: stesso insieme ordinato di URL, testi, gerarchia e attributi, 18 settori / 132 categorie / 528 tipologie e 678 destinazioni mobile uniche. HtmlAgilityPack confronta i frammenti pubblici server-side, ignorando soltanto whitespace inter-tag e gli span autorizzati: non e un conteggio del DOM live dopo JavaScript. Catalogo mobile: **567.813 -> 165.453 byte UTF-8 non compressi (-70,9%)**, whitespace-only text node **4.347 -> 0**. Frammenti desktop + catalogo mobile + due select HOME: **737.495 -> 328.271 byte**, elementi **5.487 -> 4.431**. Audit precedente intero header/offcanvas: **752.671 byte / 5.644 elementi**; GET finale: **343.446 byte / 4.588 elementi**. HOME intera: **7.425 -> 6.369 elementi**. Nessuna promessa di INP o latenza: il tempo complessivo GET non isola il costo dell'header.

Verifiche Codex gia concluse: whitelist statica delle sole trasformazioni autorizzate, harness con metodi desktop reali estratti dal codice e tree sintetici/encoding/fail-safe, confronti runtime e controlli negativi su URL/testo/ARIA/gerarchia **529 PASS**; current-scope #322 **341 controlli / 31 scenari PASS**; cache #321 **49 PASS**; statici **13 PASS**. Precompile ASP.NET Framework 4.8 safe PASS, senza copiare configurazioni operative. Primo GET post-edit: BC30560 su piu controlli; successivi GET HOME/catalogo/PDP HTTP 200, senza recycle IIS, modifica configurazioni o pulizia cache. Browser interattivo Codex non disponibile: la matrice **360/390/768/1365, touch, focus, tastiera, apertura/chiusura/scroll e overflow non e stata eseguita da Codex**. Il Product Owner ha successivamente comunicato **smoke production A** prima del merge; non attribuire tale prova a Codex o inventare dettagli dei singoli dispositivi. HTTP 200 e harness non equivalgono da soli ad A visuale.

Postback locali di sola ricerca desktop e mobile: eventi ricavati dal markup, ViewState/event validation originali mantenuti soltanto in memoria, sessioni anonime temporanee; entrambi HTTP 302 verso catalogo con `st=2&ct=35&q=hp`, senza seguire il redirect. Nessuna mutazione carrello o altro flusso commerciale. Questa prova conferma il percorso WebForms, non il comportamento visuale del browser.

Manifest massimo: i due runtime citati, `Tools/HeaderMenuMarkupHarness.vb`, `Tools/Test-HeaderMenuMarkup.ps1` e questo Masterplan. Lo script puo acquisire soltanto frammenti pubblici dei menu da un host risolto loopback in una directory nuova fuori repository; non salva cookie, hidden fields o account. Tools mai nel deploy ordinario. Preservati `web.config`, quattro cancellazioni tracked preesistenti e 54 untracked autorizzati; zero DB write, ordini, pagamenti, gateway, e-mail o nuove fixture DB. Nessuna certificazione di tutti i tenant o della produzione.

Manifest smoke server gia approvato: soltanto `Public/ui/controls/SiteHeader.ascx` e `Public/ui/controls/SiteHeader.ascx.vb`; gate review ChatGPT e smoke Product Owner A conclusi. Il successivo `STOREFRONT-NAVIGATION-UX-BENCHMARK-1A` e autorizzato **soltanto come progetto documentale**, descritto nel checkpoint prevalente sopra; nessuna implementazione UX avviata. ViewState e duplicazione integrale desktop/mobile restano finding separati: questa compattazione non risolve la crescita lineare del menu con la tassonomia.

### TENANT-EMAIL-WEB-RUNTIME-CUTOVER-1A - CHIUSO / A / INTEGRATED

Checkpoint corrente verificato su GitHub: PR #319 MERGED con fast-forward, commit finale `07ef3d61ca35f7be49b4a21aa7139621cc341861`, parent diretto `0b15fad2555285e1cc99fece6e80715e2e080d1d`. `frontend-rebuild` e `origin/frontend-rebuild` sono allo SHA finale; `main` / `origin/main` restano `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Il precedente checkpoint PR #318 e superato; PR #318 e stata chiusa senza merge come `SUPERSEDED / DO NOT MERGE`, mantenendo il branch.

`TENANT-EMAIL-ADMINISTRATIVE-COPY-1A` / PR #317 e CHIUSO / A / INTEGRATED al checkpoint storico `e71e1420aabafab45612180f160cb467f74b6bc1`. La policy tenant-scoped resta quella descritta sotto e nella matrice e-mail: `ORDER_CONFIRMATION`, `ACCOUNT_REGISTRATION` e `ACCOUNT_PROFILE_UPDATED` ricevono la copia amministrativa prevista dal profilo; `PASSWORD_RESET` resta cliente-only; `CONTACT_REQUEST` usa il destinatario operativo del profilo con Reply-To del cliente. La PR #319 ha modificato in `PasswordResetTokenService.vb` soltanto il gate legacy che richiedeva la mail aziendale; token, hash, scadenza, monouso, anti-enumeration e PRG non sono stati cambiati. Il timing post-commit e il flusso commerciale ordine sono invariati.

Il runtime web operativo usa `aziende_email_transport` come source of truth per provider/SMTP, CredentialReference, From, Envelope-From, Reply-To, BCC amministrativa e destinatario operativo `CONTACT_REQUEST`. I sender web non usano le colonne legacy `aziende.Smtp`, `aziende.User_smtp`, `aziende.Password_smtp`, `aziende.email` o `Session("AziendaEmail")` per routing SMTP, credenziali o gate di consegna; `aziende.email` resta informazione pubblica/branding soltanto.

Smoke Product Owner sul server production Taikun: A per `CONTACT_REQUEST`, `PASSWORD_RESET`, `ACCOUNT_REGISTRATION` e `ORDER_CONFIRMATION`; per i quattro flussi sono state confermate `EMAIL_SENT` e la consegna reale. La copia amministrativa/BCC e stata verificata dove prevista. La causa iniziale era `CREDENTIAL_FILE_MISSING` in fase `credential-load`, risolta con provisioning DPAPI `LocalMachine` sul server IIS e riferimento opaco `dpapi-v1`; nessun segreto, riferimento reale o identificatore di correlazione e registrato qui. Questa evidenza certifica soltanto i flussi web TRANSACTIONAL di Taikun production, non tutti i tenant o ogni consumer esterno.

Verifier standalone: la REV2 ha spostato `TenantEmailMessageClassifications` nel contratto condiviso `App_Code/TenantEmailTransportContracts.vb`; il verifier resta transport-only. Verifiche tecniche riportate: verifier build, runtime core 260/260, callers 69/69, suite ordine, precompile ASP.NET Framework 4.8, diff-check e secret scan PASS.

`documenti.aspx.vb` e `coupon_utente.aspx.vb` restano queue-only verso `INVIADOCUMENTI`: il consumer gestionale/esterno non e certificato dal runtime web e `EXTERNAL-DOCUMENT-EMAIL-TRANSPORT-AUDIT-1A` resta NON AVVIATO. OAuth2 Google/Microsoft resta NON OPERATIVO; il pannello gestionale non e completato. La procedura manuale di provisioning server-side resta valida finche il pannello non sara implementato; ogni altro tenant richiede provisioning e verifica separati. Non copiare credenziali, file DPAPI o riferimenti tra macchine.

Prossimo task tecnico candidato: `CATALOG-MENU-CACHE-CONSUMERS-1A` — NON AVVIATO. L'audit ha rilevato letture duplicate della tassonomia tra `SiteHeader`, `HomeDepartmentsMenu` e `Default.aspx`; la cache esistente usa una chiave globale non tenant/database-scoped e non va adottata senza un contratto di scope sicuro. Nessun runtime del catalog menu e modificato o avviato dal closeout.

### Checkpoint prevalente 2026-10-04 — VAT / commercial storefront pricing

`frontend-rebuild` / `origin/frontend-rebuild` = `b4da5b56829225764e6057ce25c834613d50586a`; `main` / `origin/main` = `976e99f17cabc8a5c6a8715463444edfeaadcd91` invariati. Le PR #300–#308 risultano MERGED su GitHub in sequenza lineare, ciascuna con il commit della PR come merge point: #300 `5bc050554c01e1a1405ee95899324c97b604a662`; #301 `4e26419f66bfdad0d780ccf8f123ad6f5b0eeac8`; #302 `ffa5beda613702ae0143dee4a3af49069c508b18`; #303 `3ce5ffd66023fef9d4a4b1b86005505c031fa3d5`; #304 `87c031c68352c3e1cd8c9c24a147ecdb7ba68477`; #305 `1addcf1e94d498b9f6b8cbeaf641eb5d45bec000`; #306 `5a3be27effe79d33ac6061d5e5f9ffd70e07221c`; #307 `de611eb755865d072a266c832c8adc31b925b6c3`; #308 `b4da5b56829225764e6057ce25c834613d50586a`. Le PR #300–#308 sono state integrate con fast-forward; non sono stati creati merge commit. Questo checkpoint prevale sulle roadmap precedenti: task qui indicati come futuri o `NON AVVIATO` sono storici se sostituiti dalle integrazioni elencate.

| PR | Blocco integrato | Commit / checkpoint |
| --- | --- | --- |
| #300 | `PERSISTENT-CART-DOCS-DEPLOYMENT-CLOSEOUT-1A` | `5bc050554c01e1a1405ee95899324c97b604a662` |
| #301 | `STOREFRONT-CURRENCY-PRESENTATION-1A` | `4e26419f66bfdad0d780ccf8f123ad6f5b0eeac8` |
| #302 | `STOREFRONT-CART-CHECKOUT-CTA-RESPONSIVE-1A` | `ffa5beda613702ae0143dee4a3af49069c508b18` |
| #303 | `STOREFRONT-CART-CONVERSION-UX-1A` | `3ce5ffd66023fef9d4a4b1b86005505c031fa3d5` |
| #304 | `STOREFRONT-VAT-PRICE-DISPLAY-CONTEXT-FOUNDATION-1A` | `87c031c68352c3e1cd8c9c24a147ecdb7ba68477` |
| #305 | `STOREFRONT-VAT-PDP-CONTEXT-1A` | `1addcf1e94d498b9f6b8cbeaf641eb5d45bec000` |
| #306 | `STOREFRONT-VAT-HOME-CONTEXT-1A` | `5a3be27effe79d33ac6061d5e5f9ffd70e07221c` |
| #307 | `STOREFRONT-VAT-CATALOG-CONTEXT-1A` | `de611eb755865d072a266c832c8adc31b925b6c3` |
| #308 | `STOREFRONT-VAT-CATALOG-PRICE-SORT-FILTER-1B` | `b4da5b56829225764e6057ce25c834613d50586a` |

Le PR #308 completa il sottoblocco di presentazione commerciale/prezzi VAT qui descritto; i soli file runtime di #308 sono `App_Code/StorefrontPromotionCatalogProvider.vb` e `articoli.aspx.vb`. Il task documentale riconcilia il perimetro implementato, non certifica l'intero storefront, tutti i tenant o la produzione.

Contratto definitivo:

- Owner autenticato: `database + AziendaId + LoginId`; anonimo legacy: `database + AziendaId + ksc1`; anonimo persistente: `database + AziendaId + ksc2`. L'azienda deriva dal resolver host-scoped; nessun owner commerciale viene accettato dal browser.
- Cookie `__Host-KeepStoreCart`: formato `v2.<43 Base64URL>`, secret casuale di 256 bit, prima parte, `Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`, nessun `Domain`. Non contiene dati personali/commerciali leggibili. Raw secret e valore cookie non entrano in DB, Session o log; il token derivato non e il raw secret.
- Registry `carrello_anonimo_persistenza`, stati `ACTIVE`, `CONSUMED`, `REVOKED`; clock autorevole `UTC_TIMESTAMP(6)`. Creazione soltanto alla prima mutazione anonima effettiva, adozione atomica delle righe `ksc1` in `ksc2`; GET/read/no-op non creano o estendono la durata.
- Mutazione effettiva: sliding massimo 30 giorni. Svuotamento: `REVOKED`. Login: merge atomico `ksc2 + eventuale ksc1 + account`, revalidation prezzi/promo/listino server-side, `CONSUMED`, eliminazione cookie; un replay non ripete il merge. Nessuna prenotazione stock dovuta alla persistenza del carrello.
- Commit indeterminate: niente ritentativo cieco o perdita dell'owner; riconciliazione con evidenza autorevole e fail-closed. Cookie stale terminale eliminato best-effort. SET tradizionale protetto da RequestId ViewState e payload unico `cart-set-batch`; transizione owner vincolata allo stesso intent autorizzato.
- Cleanup esplicito `PersistentAnonymousCartCleanupService` e `Tools/Invoke-PersistentCartRegistryCleanup.ps1`: default 100, massimo 1000 candidati per batch. `ACTIVE` scaduto: sole righe anonime + registry atomicamente; `CONSUMED/REVOKED` scaduti: eliminazione solo senza righe anonime residue. Anomalie conservate fail-closed; righe account mai eliminate. Nessun endpoint pubblico o scheduler automatico nel runtime.
- Privacy: `privacy.aspx` documenta il cookie tecnico; footer Privacy -> `privacy.aspx`. Nessun banner/CMP aggiunto per questo cookie; non si dichiara conformita GDPR garantita dell'intero sito.

Prove approvate dei blocchi integrati: smoke lifecycle e login merge, anti-replay/transizione owner, SET tradizionale, cleanup bounded con rollback/retry e preservazione account, privacy HTTP 200 e layout 360/390/desktop, precompile/diff/secret PASS. Questo task documentale non le riesegue e non amplia la certificazione alla produzione.

**Stato release: INTEGRATED / NOT YET PRODUCTION-CERTIFIED.** Il runbook [PERSISTENT_ANONYMOUS_CART_DEPLOYMENT_RUNBOOK.md](PERSISTENT_ANONYMOUS_CART_DEPLOYMENT_RUNBOOK.md) governa il futuro rollout: allowlist esplicita, backup, foundation, deploy, smoke, batch manuale, scheduler e prima esecuzione verificata. In questa chiusura non sono eseguiti deploy, cleanup, scheduler o operazioni DB.

`CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A` resta CHIUSO E / DIFFERITO: concerne la durabilita oltre Session/InProc del registro anti-replay delle mutazioni, non la persistenza delle righe anonime. Non e risolto da #297/#298/#299.

`STOREFRONT-CART-CONVERSION-UX-1A` non e piu backlog: e CHIUSO / A / INTEGRATED con PR #303. Le integrazioni Merchant e abandoned-cart restano ambiti distinti soggetti alle rispettive decisioni, prerequisiti e autorizzazioni; questo checkpoint non seleziona ne avvia un task successivo.

### Contratto stabile VAT / commercial price display

- `StorefrontPriceDisplayContextProvider` crea un contesto server-side request-scoped, dopo la validazione tenant/azienda e listino. Per l'anonimo il modo di visualizzazione deriva dall'IVA default del tenant salvata nel database, quando la relativa opzione e abilitata (`IvaTipo` nel default tenant); per l'autenticato prevale la preferenza IVA coerente con l'account nella stessa azienda. Non si deduce il modo da host grezzi o da valori inviati dal browser.
- Label canoniche: `Prezzi visualizzati IVA inclusa` e `Prezzi visualizzati IVA esclusa`. Il checkout mantiene la propria esposizione distinta `Imponibile / IVA / Totale`.
- Nessuna aliquota IVA generale hardcoded: l'IVA prodotto puo variare; `Iva_Vettori` e separata dall'IVA dei prodotti. `Iva_Utente = -1` significa nessun override, mentre `0` e un override valido. Prezzo lordo effettivo: reverse charge prodotto se abilitato per l'account, poi override account (anche 0), altrimenti lordo autorevole DB. Se la modalita selezionata non ha un prezzo valido, non si sostituisce con la modalita opposta.
- Il contesto e riusato tra PDP e relativi output pubblici di prezzo, HOME e catalogo. Il catalogo applica al prezzo visualizzato, sortato e filtrato una proiezione commerciale qty=1: offerte autorizzate, variante esatta prima del fallback articolo, prezzo netto promo migliore e tie-break `OfferDetailId`. `QntMinima > 0` deve essere soddisfatta da qty=1; in alternativa `Multipli > 0` deve ammettere qty=1. Entrambi positivi e una regola ambigua; entrambi non positivi non sono applicabili. E ammesso un prezzo assoluto positivo o uno sconto 1–99% solo se il promo netto risulta positivo e inferiore al netto base. Il promo lordo segue il rapporto tra lordo effettivo base e netto base. Calcoli fiscali e promo restano server-side, senza arrotondamento prematuro.
- Ordinamenti prezzo crescente/decrescente e range inclusivo `pmin/pmax` usano lo stesso `CatalogDisplayPrice` della card; prezzi assenti/non validi non soddisfano il range. I facet seguono l'insieme commerciale del range quando attivo. La proiezione/join promo qty=1 e lazy: si attiva per ordinamento o range prezzo, non nel catalogo ordinario. Sort e tie sono deterministici.
- Il range validato e stato URL della listing e sopravvive a sort, paging, facet e page-size; il bridge Session legacy e one-shot. Nuova ricerca, clear o URL senza range non ereditano stato obsoleto. I range prezzo seguono la policy SEO esistente delle listing filtrate (`noindex,follow`). SQL usa parametri Decimal tipizzati e ingressi ambigui/duplicati non sono trattati come range valido.

Gate registrati per #301–#308: test focalizzati di contesto/resolver e parita SQL, EXPLAIN, lifecycle range, precompile .NET Framework 4.8, diff/secret scan e smoke automatici HTTP/responsive riportati PASS; review indipendente e smoke Product Owner PC/mobile del blocco finale sono A. Il percorso browser di IVA esclusa non aveva una fixture anonima/account disponibile ed e stato verificato tecnicamente, non dichiarato come smoke visivo. Nessun deploy multi-tenant o certificazione globale deriva da questi esiti.

### Checkpoint precedenti — storico preservato

- Aggiornato: 2026-09-25.
- **Decisione prevalente 2026-09-25:** PR #284 integrata; il contesto commerciale bulk e disponibile. PR #285 e sola progettazione/versionamento di schemi modulari, **non installazione**. Dopo la review/chiusura della PR #285, priorita ecommerce: HOME -> catalogo/PDP e funzioni residue -> MyAccount. Nessun task successivo e avviato automaticamente.
- La foundation IndexNow gia integrata e inattiva. `INDEXNOW-PUBLIC-STATE-RECONCILER-1A`, sender, key endpoint e scheduler sono **RINVIATI**, non il prossimo task. Google, social, marketplace, licenze e AI restano **PROGETTATI O DA PROGETTARE / SVILUPPO RINVIATO**. La SEO tecnica di base resta Core e non dipende da un modulo vendibile.
- Architettura prevalente: una sola applicazione modulare sullo stack esistente, con configurazione e schermata distinte per SEO avanzata, Google, Social/Marketing, Amazon, eBay, TikTok Shop, pagamenti e licenze. `aziende_seo` non e piu il contenitore universale. Specifiche e stato nel `docs/KEEPSTORE_MODULAR_PLATFORM_BLUEPRINT.md`.
- Working copy canonica: C:\KeepStoreWeb\KeepStore3.0\.
- Runtime PayPal stabile: frontend-rebuild integra PAYPAL-CHECKOUT-ORDERS-V2-LIVE-1A (PR #270) e PAYPAL-DB-DRIVEN-CREDENTIALS-1A (PR #271); ultimo SHA runtime PayPal b5e75c28e534c28c8fd7d0e9c25f50d28f5c6dc4.
- Branch protetto: main / origin/main invariati a 976e99f17cabc8a5c6a8715463444edfeaadcd91.
- AGENTS.md resta la fonte canonica del metodo operativo corrente e include il contratto permanente MULTITENANT-BY-DESIGN per gateway e integrazioni cliente.
- Blocco PayPal Checkout Orders API v2: CHIUSO lato web/configurazione e ABILITATO LIVE, senza smoke di pagamento reale per scelta esplicita del Product Owner. Non usare la dicitura LIVE VERIFIED finche non viene eseguita una transazione reale end-to-end.
- Produzione: migration Orders v2 e migration credenziali DB-driven applicate; account PayPal, mapping azienda e metodi pagamento attivati; Client ID, Client Secret, Merchant ID e Webhook ID sono data-driven nel DB; nessuna credenziale PayPal e richiesta nel web.config condiviso.
- Webhook REST della LIVE app configurato sul listener HTTPS del sito e verificato via Webhooks Management API con i cinque eventi: CHECKOUT.ORDER.APPROVED, CHECKOUT.PAYMENT-APPROVAL.REVERSED, PAYMENT.CAPTURE.PENDING, PAYMENT.CAPTURE.COMPLETED, PAYMENT.CAPTURE.DENIED.
- CHECKOUT.PAYMENT-APPROVAL.REVERSED e stato aggiunto/riconciliato tramite API REST perche non risultava selezionabile nella UI Dashboard usata durante il setup; un PATCH successivo ha restituito WEBHOOK_PATCH_REQUEST_NO_CHANGE e il GET autorevole ha confermato l'intero set dei cinque eventi.
- Multi-tenant PayPal: uno stesso account puo servire piu aziende oppure aziende diverse possono usare account distinti senza patch al codice. Mapping, payee, brand e valuta restano tenant-scoped.
- Configurazione corrente di riferimento: TAIKUN usa il mapping azienda/metodo previsto; WEBAFFARE usa paypal@webaffare.it. I valori reali di Client Secret e altri segreti non sono documentati.
- Handoff Enzo: il gestionale desktop deve implementare la nuova schermata PayPal Checkout Orders v2 e scrivere documenti.OrigineOrdine='INTERNO' nello stesso salvataggio che crea un ordine manuale idoneo al pagamento remoto. Fino a tale modifica il flusso ordine interno non e dichiarato completato.
- Il manuale canonico Enzo e docs/PAYPAL_CHECKOUT_ORDERS_V2_GESTIONALE_ENZO.md; il documento Word consegnato al Product Owner ne rappresenta la versione operativa per il gestionale.
- Terminato il blocco PayPal, la roadmap generale riprende dalle priorita gia registrate; nessun nuovo task viene avviato automaticamente senza scelta del Product Owner.
- Directory non tracciate autorizzate e asset locali restano da preservare secondo AGENTS.md.
- `HOME-CATALOG-NAVIGATION-1A` / PR #274: CHIUSO / A, merge fast-forward su `frontend-rebuild` a `7f2e9c37a8afe64fc7e3b0bdd9aeb163bbac4915`; `main` resta a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Precompile e smoke funzionale PASS; visual responsive non certificato e nessun deploy pubblico dichiarato. La chiusura riguarda solo il micro-task, non la HOME intera.
- `HOME-DEPARTMENTS-MENU-MOBILE-AUDIT-1A` ha separato due finding. La semantica delle route e chiusa su `frontend-rebuild` a `56c63e61bd0e9d8f7113419748340d19d39543d9` dalla PR #286: settore = `st`, categoria = `st+ct`, tipologia = `st+ct+tp` solo se esplicita; `ct` senza settore o con settore incoerente ricava quello autorevole, senza default figli. `MOBILE-CATALOG-NAVIGATION-UX-A11Y-1A` corregge il finding UI sul branch dedicato, con PR DRAFT in attesa di review/smoke server: handler collapse custom rimosso, Bootstrap 5.3.2 unico proprietario di `.collapsed`/`aria-expanded`, hamburger/close/toggle come button semantici, target touch di 44px e focus visibile. L'architettura ONSUS a offcanvas unico e i link `Vedi tutto` restano; i tab `Menu/Categories` originali sono stati valutati ma non adottati. Benchmark corrente: navigazione per categorie progressiva e link espliciti al livello intero; nessuna grafica o logica di altri siti copiata. Smoke locale GET su HOME/catalogo/PDP a `360x800`, `390x844`, `768x1024`, `1365x900`: HTTP 200, route `st`, `st+ct`, `st+ct+tp`, ARIA, tastiera, Escape, focus return, scroll e assenza di overflow/errori pagina PASS; precompile ASP.NET 4.8 PASS. Nessun DB write, merge o deploy pubblico autorizzato da questo checkpoint.

Questo checkpoint va aggiornato dopo ogni blocco importante. E una mappa di ripartenza, non sostituisce la verifica diretta di Git, del root AGENTS.md e delle fonti pertinenti.



### Modalita operativa permanente LOCAL-FIRST + GITHUB SOURCE OF TRUTH

Decisione Product Owner del 2026-09-24: la working copy `C:\KeepStoreWeb\KeepStore3.0\` non e soltanto una copia da sincronizzare a fine merge, ma la **working copy operativa primaria** dei task runtime. Questa regola deve sopravvivere a nuove chat ed e vincolante insieme a `AGENTS.md`.

Flusso standard:
1. ChatGPT definisce micro-task, base SHA, manifest, test e stop condition.
2. Codex lavora direttamente nella working copy canonica, sincronizzata FF-only allo stable autorizzato, preservando configurazioni locali e untracked autorizzati.
3. Codex implementa e testa localmente nella stessa cartella; i file finali del manifest restano disponibili sul PC.
4. Dopo PASS tecnico, Codex crea un singolo commit, pusha il task branch e apre/aggiorna la PR DRAFT.
5. Codex dichiara `FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER` e fornisce l'elenco esatto dei file che Germano puo copiare sul server per lo smoke reale pre-merge.
6. Germano puo effettuare lo smoke server senza operazioni Git e senza considerarlo deploy definitivo.
7. ChatGPT controlla indipendentemente GitHub/PR/diff, assegna A/B/E e decide se servono REV.
8. Solo dopo A + autorizzazione esplicita di Germano si integra con fast-forward.
9. Codex riallinea quindi la working copy canonica al nuovo stable e verifica locale/origin, parent, staging e stato autorizzato.

Regole:
- GitHub resta la source of truth per versionamento, review e merge; la cartella locale resta la source operativa dei file su cui Codex lavora.
- Vietato usare come normale workflow un clone/copia temporanea che lasci `C:\KeepStoreWeb\KeepStore3.0\` non allineata al task.
- Nessun upload server durante una modifica incompleta: il Product Owner copia file solo dopo PASS tecnico/commit/PR e dalla lista manifest dichiarata.
- Nessun file fuori manifest e autorizzato allo smoke/deploy per implicazione.
- Il server di smoke non diventa source of truth e non sostituisce GitHub.
- Il mancato accesso diretto di ChatGPT al filesystem locale non cambia il modello: Codex verifica il locale, ChatGPT verifica GitHub in modo indipendente.
- Questa modalita e il default per tutte le nuove chat KeepStore e deve essere letta da `AGENTS.md` prima di ogni task importante.


### Decisione architetturale SEO/AI 2026 - Semantic Commerce Layer

Decisione Product Owner/ChatGPT del 2026-09-24: KeepStore non deve ne riscrivere integralmente la SEO tecnica gia stabilizzata ne continuare ad aggiungere correzioni SEO isolate pagina per pagina. Le fondamenta tecniche sane restano in uso e vengono classificate `KEEP`; la logica editoriale/semantica dispersa o merceologia-specifica viene classificata `REFACTOR/REMOVE` e fatta convergere progressivamente in un unico **Semantic Commerce Layer multi-tenant**. Questa sezione prevale sui riferimenti storici di roadmap che trattavano `llms.txt`, `llms.ashx`, "Gemini SEO" o patch SEO pagina-per-pagina come obiettivi prioritari.

#### Perimetro reale multi-storefront

KeepStore serve gia storefront con merceologie e modelli commerciali differenti: Taikun, Webaffare, PittureShabby, I Filandari, Marea Distribuzione, NDA Food, VP Sposa, Italcomed e ulteriori tenant in arrivo. I nomi dei database e altri identificativi infrastrutturali restano esclusi dalla documentazione versionata.

Taikun e Webaffare sono il caso di riferimento same-catalog: possono condividere database, catalogo e identita tecnica del prodotto, ma restano storefront commercialmente distinti. Dominio, `AziendaID`, clienti/account, listino, prezzi applicabili, offerte, promozioni e contesto `Offer` sono tenant-scoped. KeepStore possiede gia strutture/tabelle dedicate a listini, offerte e promozioni e relativi resolver commerciali: il nuovo layer SEO/AI deve **riusare quelle fonti**, non introdurre un secondo motore prezzi/promozioni, non duplicare tabelle e non ricostruire il prezzo tramite AI.

Regola permanente:
- **Product facts**: nome, descrizioni, marca, codice commerciale, EAN/GTIN/MPN, immagini, tassonomia e attributi reali possono essere condivisi quando il catalogo e realmente condiviso.
- **Offer facts**: prezzo, promo, tier, disponibilita commerciale, listino e condizioni applicabili si risolvono sempre nel contesto tenant/listino/owner autorevole tramite i resolver KeepStore esistenti.
- Un embedding, un indice semantico o un RAG futuro non memorizzano prezzo/promo/disponibilita come verita durevole: recuperano il prodotto e demandano il dato commerciale live al runtime KeepStore.

#### Fonti autorevoli del Semantic Commerce Layer

Il layer non e un nuovo database e non autorizza una mega-riscrittura. E un contratto di convergenza sopra componenti gia esistenti:

1. **Store Identity**: `aziende` risolta per host; nome, `Descrizione`, URL canonico, alias, logo e contatti autorizzati.
2. **Catalog Taxonomy**: Settori -> Categorie -> Tipologie -> Gruppi -> Sottogruppi e altre classificazioni realmente disponibili.
3. **Product Facts**: dati prodotto reali, brand, codici, GTIN/MPN, descrizioni, immagini e attributi applicabili.
4. **Commercial Context**: azienda, listino, owner, prezzo, offerte/promozioni, disponibilita e spedizione tramite i resolver commerciali esistenti.
5. **Editorial Content**: pagine CMS, banner e contenuti tenant esplicitamente configurati; nessun claim viene dedotto dal catalogo quando rappresenta un servizio o una promessa commerciale.

`aziende.Descrizione` assume il ruolo canonico di **Business Description pubblica dello storefront**. Puo alimentare presentazione HOME, meta description, Open Graph/Twitter description, structured data dell'OnlineStore/Organization, profilo Merchant e futuro contesto AI. Non classifica i singoli prodotti, non crea tassonomie, non prova che un servizio sia offerto, non abilita capability, non decide ranking e non sostituisce dati di prodotto o promozione.

#### KEEP / REFACTOR / REMOVE

**KEEP e audit 2026, non riscrivere da zero**:
- `StorefrontSeoTenantContext` e selezione host-scoped;
- `StorefrontCanonicalHostPolicy`, canonical HTTPS e fail-closed;
- robots e sitemap dinamici tenant-aware;
- matrice index/noindex delle superfici pubbliche/private;
- Product/Offer deterministico PDP, GTIN/brand/codice/prezzo/disponibilita reali;
- isolamento same-database e resolver listino/prezzo/promo gia certificati.

**REFACTOR progressivo**:
- title/description/Open Graph/Twitter/JSON-LD duplicati o definiti localmente nelle singole pagine;
- helper SEO locali duplicati, con convergenza verso il builder/contratto comune;
- HOME/catalogo/PDP che usano copy non derivato dalle fonti autorevoli;
- feed e superfici discovery future, che devono consumare lo stesso Product/Offer contract.

**REMOVE o vietato per nuovo codice**:
- hardcoding Taikun/elettronica nel runtime condiviso;
- immagini social merceologiche hardcoded usate come default globale;
- fallback catalogo/hero/badge specifici di elettronica quando i dati reali mancano;
- servizi/claim dedotti automaticamente dal catalogo;
- SEO generata da LLM senza facts verificati;
- fork cliente o SEO dedicata per singolo tenant.

#### Strategia discovery 2026

`SEO-DISCOVERY-CONFIG-SCHEMA-1A` progetta, ma non installa, la separazione modulare: `aziende_seo` 1:1 contiene solo override SEO avanzati, IndexNow e Bing; `aziende_google` e `aziende_social` sono draft distinti; TikTok Shop ha un draft account/shop separato, mentre Amazon, eBay e pagamenti riusano le strutture esistenti da auditare. Le nuove strutture hanno zero colonne nullable e i futuri segreti `Enc` restano nel modulo proprietario, con master key esterna ancora da progettare. Stringa vuota significa comportamento automatico/fonte autorevole quando applicabile; `1000-01-01 00:00:00` significa scadenza non configurata o ignota e non autorizza l'uso di un token. Nessun flag di licenza puo disattivare le fondamenta SEO standard.

`aziende` resta source of truth di nome, `Descrizione` (Business Description), URL canonici/alias, logo, dati legali e commerciali. Nessun modulo copia Product, Offer, prezzi, promozioni, tassonomia o stato operativo IndexNow. I quattro mapping legacy progettati sono `google_merchant_id -> aziende_google.GoogleMerchantId`, `facebook_pixel_id -> aziende_social.MetaPixelId`, `statistiche_visite -> aziende_social.TrackingScriptLegacy`, `facebookLink -> aziende_social.FacebookUrl`; nessun valore viene trasferito, nessuna colonna legacy viene eliminata e i reader non cambiano. Copia manuale, parity e audit riferimenti restano gate futuri. `TrackingScriptLegacy` e sola compatibilita: nessuna nuova integrazione vi inserisce HTML/JS arbitrario.

I quattro script SEO e i quattro schemi draft separati sono **NON INSTALLATI / NON PRONTI AL ROLLOUT**: richiedono futura review MySQL/ambiente, allowlist Product Owner e procedure di deployment dedicate. Nessun SQL viene eseguito in questo task. Il progetto schermate Enzo, separato per modulo e campo, e in `docs/KEEPSTORE_MODULAR_PLATFORM_BLUEPRINT.md`; le schermate reali e il manuale finale restano `FUTURE / NON AVVIATO`.

Addendum **Marketplace readiness, superato nella forma accorpata**: TikTok Shop Seller (shop gia attivo per il Product Owner), Amazon SP-API ed eBay Sell/OAuth restano capability future **distinte**, senza Shopify o middleware come prerequisito. Product/Offer restano autorevoli; listing, ordini, code, webhook, prezzi/stock inviati e telemetria stanno nelle strutture operative del modulo. Le credenziali non entrano in `aziende_seo`. I vecchi campi MWS Amazon e la configurazione eBay legacy richiedono audit/migrazione separati; prima di adapter TikTok Shop serve audit Product/Order/Fulfillment/Return-Refund/Webhook. Nessuna UI o integrazione marketplace e implementata ora.

`INDEXNOW-DISCOVERY-AUDIT-1A` e chiuso A: nel runtime precedente non esisteva un sender IndexNow; la sitemap tenant-aware emette Product/catalog con `lastmod` assente, e le tabelle commerciali esaminate non forniscono un watermark uniforme affidabile. Architettura approvata: **hybrid tenant-scoped**, con eventi web dove disponibili e riconciliazione dei fingerprint dello stato pubblico per intercettare anche modifiche dal gestionale. Key e outbox sono separate per host canonico; la sitemap resta complementare. `INDEXNOW-TENANT-SNAPSHOT-FOUNDATION-1A` introduce soltanto contratto configurazione/candidate e stato operativo versionato in `App_Data/IndexNow`: nessuna key reale, rete, sender, scheduler, endpoint, query commerciali o DDL. `INDEXNOW-PUBLIC-STATE-RECONCILER-1A`: **RINVIATO**, non il prossimo task; quando ripreso dovra usare resolver autorevoli e una scansione read-only completa prima di rilevare cancellazioni. Verifica key e sender restano successivi e rinviati. Lo stato file non e fonte di verita di Product/Offer.

`COMMERCIAL-BULK-RESOLUTION-CONTEXT-1A` / PR #284 ha rimosso il prerequisito architetturale emerso nel preflight del reconciler: il resolver promo puo caricare un solo snapshot esplicito per database/azienda/listino/data/campagna/owner e riusarlo fuori da `HttpContext.Items`; display promo e disponibilita esplicita passano dagli stessi core usati dal web. Il contesto pubblico anonimo non legge Session e non crea un falso `HttpContext`. Non cambiano regole di prezzo, promo o disponibilita, ne i call-site WebForms. Il reconciler resta **RINVIATO** e non viene riavviato da questa modifica.

Per Google AI Overviews/AI Mode e Bing AI/Copilot non viene creato un SEO parallelo. La priorita e produrre pagine crawlable, utili, veloci, coerenti, semanticamente chiare e con structured data aderente al contenuto visibile e ai facts commerciali reali.

Roadmap di discovery (architettura storica conservata, **sviluppo rinviato** dalla decisione prevalente del checkpoint):
- **P0 Multi-tenant storefront correctness**: rimuovere assunzioni merceologiche e contaminazioni cross-tenant.
- **P1 Semantic SEO Foundation**: far convergere identity, taxonomy, product facts e commercial context nel contratto comune.
- **P2 Search-engine discovery**: structured data, sitemap/canonical e IndexNow dove applicabile, senza duplicare resolver.
- **P3 Merchant Center**: feed/store context per storefront; `product_type` deriva dalla tassonomia KeepStore, mentre eventuale `google_product_category` e un mapping/override separato e verificabile, mai un'inferenza commerciale non controllata.
- **P4 Autonomous SEO Audit**: controlli automatici su title/description, canonical, indexability, GTIN/brand/image, Product/Offer, sitemap/feed, coerenza prezzo/promo/disponibilita e segnali di performance disponibili.
- **P5 Hybrid Search**: exact identifiers + retrieval deterministico + semantic/vector retrieval, con ranking e filtro commerciale tenant-aware.
- **P6 RAG Shopping Assistant**: soltanto dopo dati e retrieval maturi; RAG recupera knowledge/prodotti reali e il runtime KeepStore risolve sempre prezzo/promo/disponibilita live.

`llms.txt`, `llms.ashx` e file/markup "AI SEO" non standard restano **esperimenti opzionali**, da introdurre solo se un consumer rilevante ne dimostra utilita concreta. Non sono prerequisiti per Google AI Overviews/AI Mode, Merchant o Bing discovery.

#### Sequenza runtime storica e priorita vigente

La sequenza proposta nel 2026-09-24 (`HOME-TENANT-IDENTITY-SEO-1A`, `HOME-MULTIMERCH-FALLBACK-DEHARDEN-1A`, `SEO-2026-CENTRALIZATION-1A`) e conservata come decisione storica: non autorizza una ripresa automatica e va verificata contro i task gia chiusi. La priorita vigente del Product Owner e **HOME -> catalogo/PDP e funzioni residue -> MyAccount**. Ogni intervento richiede un micro-task separato e un finding ancora aperto; la SEO avanzata/IndexNow, Merchant, marketplace, licenze, vector DB, embeddings e RAG restano rinviati.


### Fondamenta SEO tecniche multi-tenant

- La SEO tecnica e una funzione standard per tutte le installazioni KeepStore presenti e future: nessun flag, licenza, entitlement, piano o controllo di pagamento puo disattivarla o differenziarla tra clienti.
- L'identita SEO autorevole deriva da `aziende.url1/url2` e dai dati azienda risolti server-side. L'host richiesto viene confrontato esattamente con gli alias configurati; `Host` e `X-Forwarded-Host` non sono fonti di canonical. Host sconosciuti falliscono chiusi (`421` sulle pagine, `404` sugli endpoint SEO) e non producono redirect o URL riflessi.
- Canonical: assoluta, HTTPS, una sola per pagina pubblica indicizzabile. HOME usa `/`; PDP usa `articolo.aspx?id=...` e conserva `TCid` soltanto quando identifica la variante richiesta; catalogo base e tassonomie ammesse hanno canonical deterministica. Ricerca, campagne, ordinamenti, paginazione, selezioni multiple e parametri tecnici sono prudenzialmente `noindex,follow` con canonical ripulita secondo la policy catalogo. Parametri come `ReturnUrl`, token, sessioni e fragment non entrano nelle canonical.
- Matrice permanente: HOME, catalogo base, tassonomie ammesse e PDP valide sono `index,follow`; carrello, login, registrazione, account, wishlist, documenti, checkout, pagamento, endpoint mutativi/tecnici e route promo legacy sono `noindex,nofollow` e senza canonical pubblica. Ricerca e catalogo promo moderno sono `noindex,follow`; errori e route mancanti ricevono `X-Robots-Tag: noindex,nofollow`.
- `/robots.txt` e `/sitemap.xml` sono endpoint ASP.NET dinamici, tenant-aware e compatibili GET/HEAD; i file statici concorrenti sono rimossi. Robots indica la sitemap del tenant e disallow delle superfici private. La sitemap usa esclusivamente URL pubblici canonici del tenant corrente, XML escaped, prodotti abilitati del listino di default e tassonomie valide; esclude carrello, auth, documenti, ordine, pagamenti, route legacy e URL tecnici. Nessun nome database determina il comportamento.
- Inventario metadati: HOME mantiene title, description, canonical, Open Graph e JSON-LD esistente; catalogo mantiene title/description/canonical e `CollectionPage` JSON-LD valido; PDP mantiene title/description/canonical e Open Graph. Il contratto `Product`/`Offer` avanzato e ora implementato nel micro-task dedicato descritto sotto, senza estenderlo a HOME o catalogo.
- Problemi risolti: host cliente hardcoded in policy, HOME, robots e sitemap; canonical ricavate dall'authority della richiesta; risoluzione azienda tramite confronto SQL parziale dell'host; segnali statici/dinamici conflittuali; pagine private con canonical/checkout JSON-LD; sitemap su route inesistente e connection key specifica; link social condivisi specifici di un cliente.
- Prove anti-regressione: harness compilato sulla policy reale con due tenant sintetici e host alterato; canonical/robots/sitemap isolati; matrice HTTP con header `Purpose: prefetch`; XML sitemap valido e univoco; JSON-LD esistente parseabile; precompile ASP.NET Framework 4.8, diff check, secret scan e confronto delle aree commerciali protette. Nessuna DDL/DML, ordine, carrello, pagamento, e-mail o modifica dati appartiene al task.
- Residui separati: Merchant Center, sender/reconciler IndexNow, Search Console/Bing performance, feed e integrazioni AI restano `NON AVVIATI`; la loro priorita segue ora la sezione `Decisione architetturale SEO/AI 2026 - Semantic Commerce Layer`. La sola foundation IndexNow inattiva e descritta sopra. `llms.txt`/`llms.ashx` sono esperimenti opzionali e non una foundation SEO.

### Contratto Google Product structured data

- `articolo.aspx` emette un solo grafo JSON-LD con `Organization`, `WebSite`, `WebPage`, `BreadcrumbList`, `Product` e un solo `Offer`. HOME e catalogo non emettono `Product`/`Offer` da questo modulo. Gli `@id` sono stabili e derivano esclusivamente dagli URL HTTPS canonici del tenant.
- Il builder e deterministico, privo di accesso dati e fail-closed: se tenant, canonical, prezzo, valuta, disponibilita o risoluzione commerciale non sono autorevoli, non emette JSON-LD. Errori tecnici promozionali non diventano assenza di promo o prezzo stimato.
- Prezzo, disponibilita e promozione provengono dallo stesso snapshot server-side usato dalla PDP visibile. `Offer.price` rappresenta sempre la quantita `1`; un tier futuro `Da ...` non sostituisce il prezzo principale e non genera `AggregateOffer`. `priceValidUntil` compare solo quando la promozione applicabile alla quantita `1` ha una scadenza reale.
- Dati facoltativi: descrizione testuale sanificata, codice commerciale come `sku`, marca e categoria reali. Il GTIN e pubblicato soltanto come `gtin8`, `gtin12`, `gtin13` o `gtin14` quando lunghezza, cifre e check digit sono validi; in caso contrario viene omesso. Non si usa mai l'ID tecnico come SKU.
- Immagini e logo devono esistere localmente nel tenant e diventano URL HTTPS same-tenant; placeholder, demo, data URI, URL esterni e asset mancanti sono omessi. Il seller dell'offerta e l'`Organization` del tenant, senza hardcode cliente e senza identita account/sessione nell'output.
- `ProductGroup`, varianti, recensioni/rating, MPN, condizione, spedizione e resi sono omessi finche non esiste una fonte autorevole e un contratto dedicato. La policy resi globale appartiene eventualmente a `Organization`, non viene inventata nel prodotto.
- La conformita sintattica e i campi idonei non garantiscono la visualizzazione di un rich result: la decisione resta di Google. Il task non promette ranking, indicizzazione, Merchant Center o risultati arricchiti.
- Copertura tecnica: 18 gruppi fixture / 46 asserzioni, due tenant sintetici e host sconosciuto, prezzo normale/promo/tier, disponibilita, GTIN, immagini, caratteri speciali, anonimo e contesto owner-scoped; query DB aggiuntive del builder `0`. Smoke Product Owner anonimo/PROVA superato: un solo Product e un solo Offer annidato, prezzo coerente con la risposta, canonical tenant e nessun dato personale o contaminazione cross-owner. PR #263 chiusa A e integrata.

### Contratto asset runtime tenant fail-closed

#### Architettura multi-cliente di temi e asset — stato corrente e target

KeepStore e un prodotto ecommerce distribuito a clienti diversi; non e il sito di un singolo cliente. La piattaforma deve servire installazioni con aziende, domini, database, dati, cataloghi, merceologie e identita visive differenti, mantenendo una sola codebase e una release condivisa. Il cliente puo richiedere logo, palette, font, favicon, immagini istituzionali, piccoli adattamenti o, quando cambia davvero l'esperienza, un tema completo. Separare core applicativo, presentazione del tema e personalizzazione tenant evita copie del progetto, fork, branch o patch cliente-specifiche, condizioni `IF Cliente`, CSS inseriti nelle pagine e sostituzioni manuali a ogni aggiornamento. Questo riduce le regressioni, accelera onboarding e manutenzione e consente di aggiornare il core per tutti senza sovrascrivere il branding del cliente; un cambiamento di branding non deve richiedere una modifica al core.

**Stato corrente — root del tema e percorsi degli asset.** `ThemeManager` centralizza la costruzione degli URL. Il default e `/Public/assets/keepstore/`; `KeepStore.Theme.AssetsBaseUrl` e `KeepStore.Theme.BaseUrl` configurano la root dell'applicazione, mentre `KeepStore.Theme.Name` abilita il fallback `/Public/assets/{ThemeName}/`. Oggi questi valori sono letti dagli `appSettings` dell'applicazione ASP.NET: la root cosi configurata non costituisce ancora una selezione di tema per singolo tenant quando piu vetrine condividono la stessa applicazione. Le pagine richiedono percorsi relativi, ad esempio `ThemeManager.Asset("css/catalog-ui.css")` e `ThemeManager.Asset("js/keepstore-product.js")`, senza conoscere la root fisica attiva. La struttura canonica e `css/`, `js/`, `images/`, `fonts/` e `icons/`; CSS e JavaScript custom non vanno lasciati nella root quando esiste la directory tipizzata.

**Target — temi completi intercambiabili.** Ogni tema alternativo mantiene le stesse directory sotto `/Public/assets/{ThemeName}/`, cosi le pagine continuano a richiedere i medesimi percorsi relativi. Il meccanismo di configurazione della root e gia presente; un catalogo di temi alternativi completo e la sua eventuale assegnazione autorevole per tenant sono obiettivi architetturali, non funzionalita tenant-specifiche gia certificate. Un tema distinto e giustificato da cambi reali a struttura dell'header o navigazione, layout delle card, composizione HOME o design system; colori, logo, font, favicon e piccoli aggiustamenti non richiedono una copia completa del tema.

**Target — branding e override tenant.** Per le sole differenze di branding, il modello desiderato e un tema base condiviso piu un override tenant leggero, data-driven e caricato dopo il tema. L'override deve contenere soltanto le differenze necessarie, evitando copie quasi identiche. Il percorso canonico futuro, la chiave tenant/asset e il relativo contratto di caricamento non sono decisi da questa sezione e saranno definiti in un task dedicato. Logo, favicon, palette e altri valori possono provenire dalla configurazione o dai dati autorevoli del tenant solo tramite resolver esistenti o futuri validati; il database non deve contenere o generare codice arbitrario.

**Stato corrente — CSS tenant legacy supportato.** Il valore `aziende.css` passa da `Session("css")` a `TenantRuntimeAssetResolver`, che valida il nome del file, l'estensione `.css`, l'assenza di path/traversal e l'esistenza sotto `/Public/style/`; l'URL pubblico corrente e `/Public/style/{filename.css}`. Il percorso e ancora legacy ma il meccanismo e supportato e fallisce chiuso. Non e la root del tema `ThemeManager` e non viene modernizzato qui. La futura migrazione dovra scegliere in modo controllato directory canonica, associazione tenant, caricamento, ownership/isolation, validazione, fallback, cache, deployment e migrazione dal percorso esistente.

**Confini e precedenza visiva.** L'identita tenant corrente continua a essere determinata dal database configurato, dall'host autorevole e dall'unica riga `aziende` valida, secondo `MULTITENANT-BY-DESIGN`. Tema e override devono essere deterministici e non contaminare un tenant con CSS, logo, immagini, colori, configurazioni o asset di un altro; nomi cliente, database e domini non diventano hardcode nel sorgente condiviso. Il modello visuale futuro e: framework/base necessario, tema corrente, UI shared KeepStore, CSS di pagina/componente, override visuale tenant finale. Questo ordine e concettuale: il caricamento effettivo sara verificato nel task dedicato e l'override non modifica la business logic. Il database e la configurazione forniscono selezioni e valori autorizzati, non markup, script o CSS arbitrario; ogni resolver deve validare filename, path, estensione, esistenza e ambito tenant secondo il proprio contratto.

**Aggiornabilita e riferimento UI.** Un aggiornamento del core KeepStore deve restare distribuibile a tutti i clienti senza sovrascrivere il loro branding; un aggiornamento del branding di un cliente non deve modificare il core condiviso. Il template originale resta soltanto riferimento esterno UI/UX: non e il nome del tema runtime, una dipendenza, un identificatore cliente, una fonte di dati demo o di business logic. I pattern adottati diventano KeepStore e restano compatibili con il contratto `TEMPLATE-REFERENCE / RUNTIME-INDEPENDENCE`.

- `TEMPLATE-REFERENCE-PUBLIC-CLEANUP-1A`: rimossi esattamente 66 file reference/demo orfani dal webroot: 40 HTML top-level del tema, 23 file sotto `Public/assets/images/demo/` e 3 demo IcoMoon (`demo.html`, `demo-files/demo.css`, `demo-files/demo.js`). Audit di runtime, CSS/JS, App_Code, configurazione, build/tooling, SEO e percorsi dinamici: zero consumer runtime esterni o dipendenze applicative; i link fra candidati e le menzioni documentali non sono consumer. Il default document generico `index.html`, lasciato invariato, esponeva la directory del tema: GET locali tenant-aware pre-cleanup directory/index/shop-default/product-detail/IcoMoon demo `200`, immagine demo WebP `404`; post-cleanup directory `403`, cinque file `404`. I riferimenti relativi `images/demo/` degli HTML risolvevano sotto la directory del tema, dove quella sottodirectory non esisteva. Il reference originale resta fuori dal webroot, nel package esterno e nella storia Git; nessuna nuova directory pubblica reference. CSS/JS/font/icon runtime (inclusi IcoMoon `style.css`, font e definizioni), branding e immagini cliente preservati; nessuna modifica UI/business, DB o configurazione. La verifica locale non costituisce deploy o smoke server Product Owner.

Obiettivo finale: KeepStore mantiene un solo core applicativo e uno schema funzionale condiviso; `ThemeManager` risolve una root intercambiabile con struttura standard, mentre il branding specifico del cliente e applicato da un livello tenant leggero e separato. Un nuovo cliente o tema non richiede un fork e gli aggiornamenti del core restano distribuibili a tutte le installazioni.

- Causa storica CSS: `Page.master.vb` emetteva sempre il valore `aziende.css` sotto il percorso legacy `Public/style/`, senza validare nome, estensione o esistenza. Un valore configurato ma non distribuito generava un `<link>` first-party 404 su ogni pagina che usa il master.
- Causa storica sfondo: se la query `sfondi` non restituiva una riga attiva, il master costruiva automaticamente `Default{AziendaID}.png`; inoltre il foglio globale `css/keepstore.css` conteneva un gradiente celeste `body` estratto da `Coupon.master`. La REV0, omettendo correttamente l'immagine inesistente, aveva reso visibile quel gradiente preesistente.
- Regola permanente: il moderno layout ONSUS non interroga o applica automaticamente `sfondi`, `Default{AziendaID}.png` o gradienti globali legacy. Il CSS tenant resta facoltativo ed e caricato soltanto se filename, percorso, estensione ed esistenza superano la validazione; in sua assenza restano le superfici neutre KeepStore/ONSUS, senza effetto inventato.
- Non sono autorizzati asset demo, copie legacy o fallback arbitrari. Un asset valido gia distribuito continua a essere caricato; tenant differenti sono risolti per richiesta senza cache condivisa o contaminazione.
- REV1 same-database: la connection string seleziona il database, poi l'host normalizzato deve corrispondere esattamente a una sola identita `aziende`. La lista delle identita e memorizzata con chiave derivata dal database configurato, ma la scelta resta per-request e host-scoped. `Page.master` ricarica il record selezionato quando l'azienda di sessione non coincide, quindi CSS, sfondo, logo, nome e contatti non possono restare quelli di un'altra vetrina dello stesso catalogo. Match multipli, host sconosciuti e configurazioni prive di `url1` falliscono chiusi.
- REV2 deployment: due applicazioni IIS possono avere physical path e `web.config` distinti, eseguire la stessa release e puntare allo stesso database. La configurazione corrente non espone un identificatore storefront esplicito: il contratto sufficiente per identita e asset resta connection string di deploy + host normalizzato + unica corrispondenza `url1/url2`. Un eventuale identificatore applicativo e un finding opzionale del task commerciale successivo e, se introdotto, dovra essere coerente con l'host o fallire chiuso.
- Confine commerciale: `ListinoDefault` e `ListinoUser` sono letti dalla medesima riga selezionata; il secondo e l'assegnazione iniziale della registrazione e non sostituisce il listino poi memorizzato nell'anagrafica. Account, carrelli, prezzi, promo, provenienza ordine e replay/idempotenza richiedono la certificazione separata `MULTI-STOREFRONT-COMMERCIAL-ISOLATION-1A`; nessuna di queste logiche viene modificata dal task asset.
- REV3 visuale: nessun `background-image` viene piu aggiunto inline al `body`; il gradiente globale storico e rimosso dalla sorgente caricata e il relativo CSS usa un cache-buster dedicato. CSS tenant valido continua a poter personalizzare intenzionalmente il tema senza fallback verso asset di un'altra vetrina.
- Il validatore onboarding estrae dagli URL espliciti gli asset first-party presenti in `src`, `href` e style inline, ignora commenti HTML, data URL ed elementi esterni, usa soltanto GET/HEAD e fallisce su asset CSS/JS/immagine/font non HTTP 200. Registra URL, status e referrer senza crawling generale o login.
- Prove: fixture asset e harness same-database su due applicazioni/vetrine sintetiche con identita database e articolo condivisi, canonical/alias, CSS, `ListinoDefault` e `ListinoUser` distinti, sequenza A-B-A, host sconosciuto e duplicato; HOME, catalogo, PDP, carrello e login HTTP 200 sull'host tenant valido e riferimenti legacy assenti. Product JSON-LD, SEO e promo restano invariati. Residuo: controllo visuale Product Owner su PDP desktop, `390x844` e `360x800` per confermare assenza di flash, sfondo rotto o perdita stili.

### Contratto prezzi, listini e account same-database

- La riga `aziende` selezionata dall'host e l'unica fonte di `AziendaID`, `ListinoDefault` anonimo e `ListinoUser` iniziale. La registrazione passa entrambi i valori al contratto `Newutenti` e recupera l'utente creato con query parametrizzata e azienda esplicita.
- Il login e sempre `AziendaID + username`; non esiste fallback username-only. Dopo il login prevale il listino persistito nell'anagrafica e `ListinoUser` non lo sovrascrive. La sessione registra l'azienda autenticata; un passaggio A-B invalida LoginId e dati account e ripristina il listino anonimo B.
- HOME, catalogo, PDP e recenti usano il listino positivo gia stabilito dal tenant context, senza fallback cliente `1`. Product JSON-LD riusa il prezzo quantita `1` della PDP. La cache promo include fingerprint non reversibile del database configurato, azienda, listino, stato autenticato e owner; `TechnicalError` non viene memorizzato.
- Matrice sintetica same-database: 17 scenari / 22 asserzioni, inclusi anonimo A/B, A-B-A, account A/B, stale LoginId, registrazione, listino persistito, prezzi differenti, promo immediata/tier, parita delle superfici, JSON-LD e failure cache. Regressioni: promo/error-state `141/141`, bulk `19/19`, SEO same-database `41/41 + 44/44`, Product structured data `46/46`, precompile e GET locali HOME/catalogo/PDP sull'host tenant valido.
- I banner HOME correnti sono ora filtrati con l'azienda risolta e parametri SQL. Residui separati da quel task: endpoint feed HOME legacy non collegato con fallback listino storico e pagine listini/coupon legacy. Il carrello same-database e stato chiuso da `MULTI-STOREFRONT-CART-ISOLATION-1A`; provenienza ordine, numerazione ed e-mail tenant-aware sono il perimetro del checkpoint corrente `MULTI-STOREFRONT-ORDER-PROVENANCE-EMAIL-1A`.

### Contratto permanente MULTITENANT-BY-DESIGN e onboarding

KeepStore deve installare lo stesso commit presso clienti con azienda, dominio, database, asset e merceologia differenti senza modificare o ricompilare il codice condiviso. Sono supportati entrambi i modelli: database separato per installazione e piu vetrine/righe `aziende` nello stesso database e catalogo. L'identita runtime e la combinazione database configurato + host autorevole + unica riga `aziende`, mai il solo database. Sono vietati nomi cliente, domini, database, tabelle qualificate per database e logica dedicata a una sola azienda nel runtime comune. Configurazione e dati tenant restano separati dal sorgente; host sconosciuti, duplicati e contaminazione cross-tenant falliscono chiusi; ogni funzione tenant-aware usa almeno due tenant sintetici nei test. Migrazioni e stored procedure sono standard, senza `USE` o riferimenti cliente nel corpo canonico. Attributi prodotto mancanti o non applicabili sono omessi, mai inventati.

#### Sottocontratto ADAPTIVE-MULTI-MERCHANDISE-STOREFRONT

Questa e un'estensione di `MULTITENANT-BY-DESIGN`, non un contratto concorrente. KeepStore e un solo prodotto: stesso sorgente e stessa release per cataloghi di merceologie differenti, senza fork, branch o patch per cliente o settore. Informatica/elettronica, Pittura Vintage/decorazione, abiti da sposa, Food & Beverage, ferramenta, olio, pane/panini e alimentari, abbigliamento e scarpe sono esempi illustrativi, non una tassonomia chiusa ne valori da codificare nel runtime.

- HOME, catalogo, PDP, filtri/facet, ricerca, suggerimenti, raccomandazioni, merchandising, SEO e futura AI si adattano a tenant risolto, catalogo e tassonomia reali e ad attributi/capacita effettivamente disponibili. Settori, categorie, tipologie, marche, varianti, attributi e contenuti non si inventano.
- Il codice condiviso non fissa categorie o ID settore/categoria, non usa testi o fallback elettronica come regola generale e non presume che ogni prodotto abbia marca, taglia o specifiche tecniche. Una funzione compare solo se supportata da dati autorevoli e pertinente: taglia/colore per alcuni cataloghi moda, caratteristiche tecniche per alcuni cataloghi elettronica/ferramenta, formati/pesi per altri sono esempi condizionali. Attributi mancanti, non applicabili o non affidabili vengono omessi, mai simulati o inferiti arbitrariamente. Ingredienti, allergeni, resa pittura e misure specialistiche non sono dichiarati capacita correnti: richiedono audit schema e task dedicati.
- `StorefrontCapabilityProfile` e soltanto una direzione architetturale futura: profilo server-side deterministico da dati/configurazione autorevoli, non una classificazione LLM opaca o basata solo su keyword descrittive. Estensioni verticali mancanti entrano tramite capability, modulo o configurazione riutilizzabile e task dedicato, non con fork cliente.
- Le future funzioni adattive richiedono test con almeno due tenant/cataloghi sintetici di merceologia differente: stesso codice condiviso, nessun testo o categoria di un altro tenant, nessuna funzione irrilevante e nessun dato inventato. ONSUS resta riferimento UI/UX, non modello merceologico: KeepStore fornisce dati, tassonomia e capacita; il template non impone categorie o contenuti demo. **TEMPLATE-REFERENCE / RUNTIME-INDEPENDENCE:** il template originale e una fonte esterna di benchmark/reference UI/UX, non una dipendenza runtime. Il runtime custom KeepStore non usa il nome del template in identificatori, classi, funzioni, variabili, selettori, version string/cache-buster, commenti operativi, DOM marker, log o path/file custom e non importa dati, prodotti, categorie, prezzi, immagini o business logic demo. Ogni pattern adottato viene adattato alla semantica KeepStore; le menzioni restano ammesse in manuali, audit, storico e documentazione/reference. Gli asset runtime di ogni tema rispettano una struttura tipizzata sotto ThemeManager.AssetsBaseUrl: CSS in css/, JavaScript in js/, immagini, font e icone nelle rispettive directory. Non sono ammessi duplicati runtime o fogli CSS/JS custom sciolti nella root del tema quando esiste la directory canonica. Temi alternativi mantengono la stessa struttura in /Public/assets/{ThemeName}/; configurazione e asset tenant restano separati dal codice condiviso.

Origine e responsabilita verificate sul runtime dopo PR #261:

| Ambito | Fonte autorevole e contratto |
| --- | --- |
| Database dell'installazione | La connection string applicativa `EntropicConnectionString`, fornita dalla configurazione di deploy, seleziona il database fisico usato dal runtime. Un database puo contenere una sola vetrina oppure piu righe `aziende` e un catalogo condiviso; il database non determina da solo l'identita storefront. |
| Identita tenant | Nel database selezionato, `StorefrontSeoTenantContext` confronta l'host normalizzato con tutte le identita configurate e richiede una sola corrispondenza esatta. `Page.master.LeggiAzienda()` rilegge quel record per ID e riallinea la sessione quando cambia vetrina. Nessuna prima riga o fallback verso un'altra azienda. |
| Dominio e alias | `aziende.url1` e la base canonica primaria; `aziende.url2` e l'alias secondario. Gli URL sono normalizzati a origin HTTPS e devono contenere host DNS validi. |
| Validazione host | `StorefrontCanonicalHostPolicy` usa confronto esatto case-insensitive. `url1` e il canonico obbligatorio e `url2` l'alias facoltativo. `Global.asax` devia un alias ammesso verso il canonico e risponde fail-closed a host sconosciuti o compatibili con piu righe; `Host` e `X-Forwarded-Host` grezzi non sono fonti di canonical. |
| Dati aziendali | Nome/ragione sociale, descrizione, indirizzo e contatti, dati legali, logo/favicon, listini, IVA, disponibilita e opzioni storefront provengono dal record tenant e dai dati del database selezionato. |
| Deploy IIS/configurazione | Binding host, certificato TLS, connection string, machine key, endpoint/servizi esterni e impostazioni ambientali restano responsabilita del deploy IIS/configurazione, non del codice tenant-aware. |
| Asset cliente | Logo e favicon azienda, immagini marche, articoli, categorie/settori e vettori sono dati o asset di deploy; i nomi file vengono validati e non autorizzano URL esterni o traversal. |
| Valori esclusi da Git | Password, token, chiavi API/gateway, connection string, machine key, certificati e chiavi private, credenziali SMTP, cookie/sessioni, dati personali, nomi host/database interni e file di configurazione reali non entrano in commit, PR, manuali, log o output. |

Checklist numerata di installazione cliente:

1. Preparare ambiente, versioni .NET Framework/MySQL supportate, account di servizio e segregazione accessi, senza copiare segreti nel repository.
2. Creare il database dal modello KeepStore e applicare in ordine le migration standard approvate, con allowlist esplicita del Product Owner.
3. Configurare `EntropicConnectionString` nell'ambiente di deploy affinche punti esclusivamente al database autorizzato; non riportarne il valore nel verbale.
4. Registrare nel record `aziende` identita, ragione sociale, dati legali e parametri storefront reali del cliente.
5. Registrare `url1` come origin canonico HTTPS e `url2` soltanto come alias autorizzato; non usare URL con path, credenziali o host locali.
6. Creare binding IIS HTTP/HTTPS e installare il certificato TLS corretto per canonico e alias.
7. Verificare redirect permanente da alias e non-www verso il canonico, preservando path/query sicuri e rifiutando host sconosciuti.
8. Distribuire logo, favicon, immagini marche/articoli/settori e altri asset autorizzati nei percorsi previsti, controllando esistenza, tipo e assenza di traversal.
9. Verificare dati legali, indirizzi, contatti e condizioni pubbliche direttamente dalle fonti tenant; non inserire valori fittizi.
10. Configurare lingua, cultura, valuta, fuso orario, regole IVA e listini coerenti con il cliente e con il mercato servito.
11. Configurare e-mail e servizi esterni nell'ambiente sicuro; nel manifest indicare solo presenza/assenza e stato del collaudo, mai credenziali.
12. Importare catalogo, tassonomie, marche, codici, EAN/GTIN/MPN, prezzi, disponibilita e immagini reali della merceologia del cliente.
13. Eseguire il validatore read-only su HOME, catalogo, PDP, alias, route private, robots e sitemap; verificare canonical unica e isolamento tenant.
14. Eseguire smoke anonimo e autenticato con fixture dedicate, snapshot iniziale/finale e nessun ordine/pagamento/e-mail reale salvo autorizzazione separata.
15. Collaudare almeno `360x800`, `390x844`, tablet e desktop: navigazione, leggibilita, asset, touch target e assenza overflow.
16. Verificare backup, restore e rollback indipendente di configurazione, database e asset prima della consegna.
17. Compilare e firmare il verbale finale con commit KeepStore, manifest sanitizzato, esiti, anomalie e autorizzazione alla consegna.

Modello sanitizzato `Manifest installazione cliente`:

| Campo | Valore da registrare |
| --- | --- |
| Codice tenant | Identificatore operativo non segreto |
| Nome azienda | Ragione sociale/denominazione autorizzata |
| Ambiente | Sviluppo, collaudo o produzione |
| Dominio canonico | Origin HTTPS autorizzato |
| Alias | Elenco esplicito oppure `nessuno` |
| Nome logico database | Alias operativo non contenente credenziali |
| Localizzazione | Lingua, valuta e fuso orario |
| Tipologia merceologica | Descrizione sintetica del catalogo reale |
| Percorsi asset | Percorsi pubblici/autorizzati per logo, favicon e immagini |
| E-mail | Configurazione presente/non presente e testata/non testata |
| Analytics/servizi esterni | Presenti/non presenti, senza ID sensibili o chiavi |
| Data installazione | Data e fuso orario del verbale |
| Versione KeepStore | Commit Git distribuito |
| Esito controlli | PASS/FAIL per preflight, SEO, smoke e mobile; anomalie collegate |

Il validatore canonico e `Tools/Test-KeepStoreTenantOnboarding.ps1`: richiede target espliciti, usa esclusivamente GET/HEAD, non effettua login o accesso DB, non disabilita TLS e non produce mutazioni. Parametri principali: `CanonicalUrl`, `AliasUrls`, `HomePath`, `CatalogPath`, `ProductPath`, `PrivatePaths`, `ForbiddenTenantHosts` e `UnknownHostUrls`. HTTPS e obbligatorio; `AllowHttpForLoopbackTest` ammette HTTP soltanto su loopback durante test sintetici locali.

Esempio con soli placeholder non instradabili:

```powershell
.\Tools\Test-KeepStoreTenantOnboarding.ps1 `
  -CanonicalUrl 'https://shop-a.example.invalid/' `
  -AliasUrls @('https://www.shop-a.example.invalid/') `
  -HomePath '/' `
  -CatalogPath '/articoli.aspx' `
  -ProductPath '/articolo.aspx?id=42' `
  -PrivatePaths @('/login.aspx', '/carrello.aspx') `
  -ForbiddenTenantHosts @('shop-b.example.invalid') `
  -UnknownHostUrls @('https://unknown.example.invalid/')
```

### Chiusura WORKFLOW-GOVERNANCE-1A

- `WORKFLOW-GOVERNANCE-1A` e CHIUSO / A e integrato in `frontend-rebuild`. Il contratto permanente corrente e nel root `AGENTS.md`; le ripetizioni nei manuali restano supporto e storico, non una fonte concorrente.
- Restano vincolanti micro-task dedicati, base SHA verificata, manifest rigido, `main` protetto, push e PR prima della review, gate separato per il merge e integrazione esclusivamente fast-forward autorizzata.

### Chiusura CART-BATCH-ATOMICITY-1A

- `CART-BATCH-ATOMICITY-1A` e CHIUSO / A. PR runtime #242 `fix: make standard cart batches atomic`, branch `task/cart-batch-atomicity-1a`, merge fast-forward in `frontend-rebuild` a `df5436deae0bdc672dbed1c7965941a031bb3d49`; due commit integrati, zero merge commit e `main` invariato.
- Un unico motore batch standard tipizzato serve anche le API single-item. Applica limite raw e canonico, normalizzazione `Decimal` a scala coerente, aggregazione checked, deduplica, canonicalizzazione del payload, ordinamento deterministico e convergenza dei TC effettivi.
- Owner e listino sono determinati server-side. Il batch usa una sola connessione e una transazione `Serializable`, lock deterministici owner-scoped, risoluzione nella transazione di prezzi, IVA, promozioni, TC e spedizione gratuita, pianificazione completa prima delle scritture, verifica finale delle righe, commit unico e rollback totale.
- Idempotenza e protezione replay impediscono il completamento dell'intent prima del commit; feedback, visite e completamento intent avvengono soltanto dopo il commit. La persistenza idempotente corrente resta `Session`/`InProc` e non e certificata per recycle, web farm o piu nodi: questo limite appartiene al futuro `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A`.
- Copertura runtime del task: batch catalogo, wishlist, bundle PDP, `aggiungi.aspx` e rettifica magazzino nei limiti definiti dal task. Il fix wishlist rende il binding deterministico prima di conteggio e visibilita e ammette un solo rebind correttivo per page index non piu valido.
- Smoke reale A: login account test PROVA; carrello anonimo e merge; batch catalogo valido/invalido; batch wishlist valido/invalido; wishlist vuota, una riga e due righe; rendering desktop, `390px` e `360px`; articolo `21906` con `1 -> 4,09 EUR @27003`, `5 -> 3,28 EUR @27004`, `6 -> 4,09 EUR @27003`, `10 -> 3,28 EUR @27004`; logout e nuovo login; checkout senza ordine, email, pagamento o gateway; fixture ripristinate; nessun HTTP 500, perdita o duplicazione.
- Non e certificato l'isolamento tra due account autenticati, perche nello smoke era disponibile un solo account. Sono invece verificati owner server-side, carrello account non visibile dopo logout, conservazione al nuovo login e query/DML owner-scoped.

### Chiusura CART-DEADLOCK-RETRY-1A

- `CART-DEADLOCK-RETRY-1A` e CHIUSO / A. PR #245 `fix: retry transient cart transactions safely`, base precedente `ef3bce60af997b35a2779f43a102c2df5c4ae7c7`, commit e checkpoint stabile `d773408588c4fc91472a4b71ef9d3980e1c93072`; merge fast-forward only, un commit integrato e zero merge commit.
- Il retry transazionale ammette al massimo tre tentativi complessivi entro un budget di 20 secondi e imposta `innodb_lock_wait_timeout=5` nella singola sessione DB. Ogni tentativo apre una nuova connessione e una nuova transazione, rilegge owner, quantita, prezzi, IVA, promozioni e spedizione gratuita e applica un backoff breve con jitter; boundary annidate non sono ammesse.
- Sono retryable esclusivamente MySQL `1213` e `1205`; `1205` richiede rollback esplicito riuscito. Errori `0`, `1062`, `2006`, `2013`, validazioni, resolver ed errori generici non vengono ritentati. Un esito ambiguo durante il commit fallisce chiuso e rende l'intent idempotente `indeterminate`; il logging e strutturato e non contiene dati sensibili.
- Percorsi inclusi: add/batch standard, set quantita, aggiornamento quantita, merge anonimo/account e rivalidazione standalone. Restano esclusi ordine e `Carrello_Documento`, transazioni ambient, pagamento/gateway, e-mail/pixel, rimozione singola, svuotamento e coupon legacy.
- L'idempotenza distingue `processing`, `completed` e `indeterminate`: il replay `completed` non ripete DML, il replay `indeterminate` fallisce chiuso e una collisione di payload viene respinta in modo controllato. La persistenza resta `Session`/`InProc`; `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A` rimane aperto.
- Nel merge anonimo/account si bloccano prima le righe account e poi quelle della sessione anonima, con query separate owner-scoped, `ORDER BY ID FOR UPDATE` e indici `IX_carrello_LoginId_ID` / `IX_carrello_SessionId_ID`, usando la stessa connessione e transazione e senza commit intermedi.
- Prove A: precompile .NET Framework 4.8; fault harness con 45 asserzioni; lock timeout reale con retry e delta esatto; smoke autenticato con 43 controlli, matrice articolo `21906` invariata, concorrenza e checkout senza documento; fixture ripristinate. Smoke post-merge 18/18 su desktop, `390px` e `360px`, nessun HTTP 500; `git diff --check` e secret scan puliti.
- Finding residui al checkpoint PR #245: `CART-REMOVE-TRANSACTION-HARDENING-1A`, `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A`, `ORDER-DOCUMENT-INVENTORY-LOCK-AUDIT-1A` e `PROMO-AMBIGUOUS-STATE-REACHABILITY-1A`. Lo stato corrente prevalente e nel checkpoint sopra: remove e audit ordine/inventario sono stati chiusi dai task successivi; la persistenza del registro idempotente delle mutazioni carrello resta E/differita ed e distinta dal carrello anonimo persistente ora integrato; promo ambigua e recesso digitale restano separati.

### Chiusura CART-HISTORY-STOCKERROR-MINICART-UX-1A

- Esito A runtime e PR #252 integrata fast-forward nel checkpoint stabile `055cb6e5c5d764222d5610e1b391d1c184f59882`; tre commit lineari, zero merge commit e `main` invariato.
- Risolte la collisione dei selettori legacy `.remove` / `.remove-cart` di `main.js`, la permanenza del fault hook TEST-ONLY `1213` nel runtime, la gestione incompleta della bfcache, la mancata risoluzione owner-scoped del codice articolo e l'assenza globale di `minicart-ui.css`.
- Contratto definitivo: Remove/Clear sono POST-only, owner-scoped, atomici e idempotenti; nessun fault hook di test e raggiungibile nel runtime pubblicato; i listener JavaScript sono scoped e non interferiscono con i postback WebForms; i messaggi mostrano il codice commerciale, mai l'ID tecnico; MiniCart e globale e carica `minicart-ui.css`, con immagine `64x64`, target touch minimo `44x44`, supporto desktop/tablet/mobile e cache-buster obbligatorio a ogni modifica CSS/JavaScript.
- Prove runtime A: sessioni autenticata e anonima; Remove prima/centrale/ultima; Clear, refresh e Back/Forward; stock zero e insufficiente; MiniCart su HOME, catalogo, PDP e carrello; quattro viewport; CSRF `403` e GET mutativo `405`; zero HTTP `500`, pageerror, overflow orizzontale e doppie mutazioni.
- Fixture finali ripristinate: carrello PROVA allo stato iniziale; documenti, wishlist e `Impegnata` invariati.
- Guardrail permanenti: ogni hook o fault injection deve essere irraggiungibile nel runtime pubblicato; ogni componente globale deve caricare i propri stili su tutte le pagine che lo renderizzano; prima di introdurre nuove classi UI vanno verificati i selettori JavaScript legacy generici.

### Chiusura tecnica ORDER-DURABLE-IDEMPOTENCY-1A REV5

- `ORDER-DURABLE-IDEMPOTENCY-1A` e chiuso A: la PR #254 e stata integrata fast-forward nel checkpoint `9fed039d4563fd20ecc02859236d90e7a2f0be5d`. Il registro MySQL persistente lega la richiesta all'owner e al payload; claim, documento, prenotazione inventario, svuotamento carrello e completamento condividono la transazione. Replay completato, doppio clic e risposta ambigua non ripetono documento, prenotazione, e-mail o gateway; la conferma valida resta Post/Redirect/Get con token opaco owner-scoped.
- Il falso esito ordine era causato dalla collisione case-insensitive fra il flag checkout legacy `C=N` e la chiave token `c`: la richiesta veniva classificata come conferma non valida e deviata verso `documenti.aspx?t=4` prima della verifica stock. Il token di conferma viene ora letto soltanto con chiave dal casing esatto e gli esiti checkout passano da un dispatcher terminale first-wins con `303` e interruzione esplicita dei chiamanti.
- Per stock insufficiente, il POST finale rivaluta server-side l'intero carrello owner-scoped prima di entrare in `ordine.aspx`; conserva tutte le righe, mostra tutti i codici commerciali interessati in un pannello accessibile e responsive, evidenzia le righe e termina soltanto su `carrello.aspx?stockerror=1#ksCartStockError`. Non vengono chiamati stored procedure ordine, completamento idempotenza, e-mail, pixel o gateway.
- Smoke autenticato sanitizzato del 2026-09-15 su `https://localhost:8443`: account test PROVA preservato; fixture `PF/PT10`, `ZAP80-A4`, `3343N`; carrello iniziale/finale 3 righe; documenti web iniziali/finali 4; registro idempotenza iniziale/finale una riga `COMPLETED` associata al documento di collaudo 261; `Impegnata` delle fixture invariata. Refresh, Back/Forward e reinvio del vecchio form non hanno raggiunto `documenti.aspx`, creato ordini o prodotto doppie mutazioni; nessun pagamento, gateway o e-mail e stato eseguito.
- Regola permanente: **ogni esito terminale del checkout deve avere una sola destinazione, interrompere esplicitamente tutti i chiamanti ed essere coperto da un test end-to-end. `documenti.aspx` non e mai una destinazione di fallback per errori checkout.**

### Chiusura STOREFRONT-PROMO-MODERN-PARITY-1A

- La route moderna `articoli.aspx?inpromo=1` seleziona i candidati con provider set-based e rivalida la promozione tramite il resolver condiviso. Azienda, listino, autenticazione e owner restano server-side; `pid` ammette un solo intero positivo, viene preservato nella navigazione e fallisce chiuso se invalido, inesistente o in errore tecnico.
- Le card non si fidano piu del solo flag materializzato `InOfferta`: una sola card rappresenta ogni prodotto, con tie-break deterministico. Il prezzo principale e sempre il miglior prezzo applicabile alla quantita predefinita `1`; un tier futuro non lo sostituisce e compare come teaser separato `Da ...` con la propria condizione. `ZAP80-A4` rende quindi `5,00 EUR` come prezzo principale, `Da 4,00 EUR - MULTIPLI 5 PZ.` separato e due offerte attive; la PDP continua a mostrare entrambe le offerte.
- I blocchi `Visti di recente` di catalogo e HOME usano card ricalcolate dal server per badge, prezzo e regola promo. LocalStorage conserva soltanto la cronologia minima di navigazione e non prezzi, badge, owner, disponibilita o condizioni commerciali; il fallback client resta non commerciale. Il blocco prezzo HOME riserva geometria stabile anche con importi lunghi, incluso il caso `1.500,00 EUR` / `3.600,00 EUR`.
- Verifiche tecniche: harness `160/160`, runtime HTTPS senza `500` o disclosure MySQL, precompile ASP.NET Framework 4.8, JavaScript syntax check e cache-buster CSS/JavaScript. Nessuna modifica DB, ordine, pagamento, gateway o e-mail.
- Il task e CHIUSO / A e integrato con PR #255 nel checkpoint `260b470d5cff0350899f0b4433efca2c1f9c3441`. Il confronto finale certifica anonimo `887/887`, PROVA `840/840`, `SoloLegacy=0`, `SoloModern=0` e duplicati zero su entrambe le route. Questa chiusura non dichiara completi catalogo, HOME, PDP, UX promo o intero storefront.

### Chiusura STOREFRONT-PROMO-ROUTE-RETIREMENT-1A

- `promozioni.aspx` non e piu una UI/query commerciale: il markup e ridotto alla direttiva WebForms e il code-behind produce esclusivamente un redirect locale. GET/HEAD validi usano `301`; POST e postback legacy usano `303`, senza ripetere il POST, body legacy, query DB, filtri Session o vecchio add-to-cart.
- Destinazione canonica operativa: `articoli.aspx?inpromo=1`. Mapping ammesso, con singoli ID interi positivi: `pid -> pid`, `pmr -> mr`, `pst -> st`, `pct -> ct`, `ptp -> tp`, `pgr -> gr`, `psg -> sg`; `pid=0` equivale all'assenza di campagna. Duplicati, valori negativi/testuali/overflow, chiavi sconosciute e ReturnUrl annidati falliscono chiusi su una destinazione moderna controllata.
- `part` filtrava direttamente `ArticoliId` nella pagina legacy e non ha un equivalente esatto nel catalogo moderno: la sua presenza fallisce chiusa e non viene mai trasformata in “tutte le promozioni”. I vecchi ReturnUrl locali verso la route sono normalizzati dalla policy post-login; destinazioni esterne restano rifiutate.
- La route legacy resta fuori sitemap e non restituisce una pagina indicizzabile. Il listing moderno filtrato conserva `noindex,follow`, canonical moderno e nessun riferimento alla route ritirata. Nessuna modifica DB, schema, stored procedure, migration o dato commerciale.
- Verifiche: harness route-retirement `126/126`, harness commerciale `160/160`, anonimo `887/887`, PROVA `840/840`, campagne singola/multipla/inesistente `1/2/0`, ZAP80-A4 `5,00 EUR` a quantita `1-4` e `4,00 EUR` a quantita `5`; precompile ASP.NET Framework 4.8 e regression GET HOME/catalogo/PDP superati, senza mutazioni ecommerce.
- Il task e CHIUSO / A con PR #256 integrata fast-forward nel checkpoint `192701ae65ecac00c294399a686af52d98d398c1`, catena lineare `260b470d... -> 5ab2f084... -> c689b4e0... -> 192701ae...` e zero merge commit. Lo smoke visuale Product Owner REV2 ha approvato desktop, tablet `768x1024`, mobile `390x844` e `360x800`, inclusi prezzo non duplicato, label `Promo` separata, tier `Da ...`, condizioni quantitative, layout e spaziatura delle card.

### Chiusura STOREFRONT-OFFERS-PROMO-UX-1A

- Il task uniforma esclusivamente la presentazione promo di HOME, catalogo normale/promozionale, `Visti di recente` e PDP, adattando al markup KeepStore i pattern ONSUS per prezzo corrente/precedente, sale badge e offerte quantitative. Restano fuori scope logica commerciale, query, carrello, ordine, pagamento, gateway, e-mail e database.
- Contratto visuale: il prezzo applicabile alla quantita `1` compare una sola volta; il precedente e barrato soltanto se realmente valido; label `Promo` e percentuale valida compaiono una sola volta; il tier futuro resta separato come `Da ...` con la propria condizione e non sostituisce il prezzo principale. Un prodotto senza offerta valida non rende label, percentuali, contenitori vuoti o spazi anomali.
- La PDP rende `Offerte attive` come elenco leggibile: il prezzo immediato non duplica quello principale, i tier e le condizioni restano distinti, le date compaiono soltanto quando reali e nessun ID tecnico o dato owner entra nel DOM. La selezione commerciale, `ProductPromotionEligibilityResolver`, `StorefrontPromotionCatalogProvider`, i calcoli `Decimal`, owner/listino/azienda/campagna, tie-break e `data-ks-price` restano invariati.
- REV2 HOME: `Occasione Imperdibile` usa un solo pool, ammette soltanto promozioni autorizzate con `Giacenza >= 1`, ordina per vendite annuali positive, scadenza autorizzata piu vicina, venduti, visite e ID, senza fallback non promozionale. Il massimo e sei; deduplica `BusinessKey` e `DisplayKey` e anche `Visti di recente` condivide gli stessi insiemi. La barra mostra `Venduti`, `Disponibili` da `Giacenza` e la percentuale reale `VendutiAnno / (VendutiAnno + Giacenza) * 100`, normalizzata `0-100`, con `aria-valuetext`; il countdown compare soltanto con una scadenza autorizzata reale.
- REV2 PDP: nel buy-box il pannello offerte usa una colonna fluida `minmax(0, 1fr)`, figli restringibili e testo a capo. Le card Simili, Correlati e Visti di recente riusano il modello promozionale cache; il badge `Promo -NN%` esiste soltanto per una promo immediata reale, il tier usa il riepilogo condiviso `Da ...`, le offerte multiple mantengono un contatore e l'assenza di promo non produce contenitori vuoti.
- REV3 PDP/HOME: il logo principale della marca deriva esclusivamente da `Marche_img` della riga prodotto corrente, riusa il link catalogo per marca e resta affiancato al nome nello stesso collegamento accessibile. Sono ammessi soltanto file locali realmente esistenti; valore vuoto, percorso non valido o file assente producono esclusivamente il nome testuale, mai asset demo o immagine rotta. Le card `Occasione Imperdibile` usano slide allungate e slot distinti per categoria, titolo completo fino a tre righe, prezzo, tier, disponibilita, risparmio, countdown e progresso; gli slot opzionali vuoti preservano la geometria senza inventare contenuti e non vengono annunciati agli screen reader.
- Verifiche REV2: harness promozionale completo `544/544`; matrice card reale con promo immediata, tier-only, mista, multi-offerta e nessuna promo; retirement `126/126`; parita anonima `887/887` e PROVA `840/840`, con elementi solo-route e duplicati a zero; precompile ASP.NET Framework 4.8 superata. Nessuna scrittura ecommerce o DB e nessuna modifica a resolver, provider o formule prezzo.
- Verifiche tecniche REV3: prove focalizzate `121/121`, harness finale `620/620`, retirement `126/126`, parita anonima `887/887` e PROVA `840/840` con differenze e duplicati a zero, logo locale HTTP 200 e fallback testuale, precompile ASP.NET Framework 4.8. Il browser interattivo non era disponibile nella sessione: nessuna misura geometrica o conclusione sulla fascia vuota e stata inventata.
- Il controllo visuale reale sui quattro viewport e la fixture stabile del logo hanno completato il gate Product Owner; PR #257 e stata integrata in `frontend-rebuild` al checkpoint `cab4486d229e8c8e8168e2a68798b0ea6d267c4e`. Questa chiusura non dichiara complete HOME, catalogo, PDP, promo o intero storefront.

### Chiusura HOME-ASYNC-CART-1A

- La HOME riusa esclusivamente `catalog_cart_async.aspx`, `CatalogAsyncCartSupport`, `CartMutationIdempotencyService`, `CartMutationService`, la risposta MiniCart esistente e `window.KeepStoreCartState`; non introduce endpoint, business logic, resolver o provider commerciali alternativi.
- La configurazione asincrona vive nel contenitore HOME dedicato e viene risolta dal controllo `.js-ks-cart-link` nel contenitore configurato piu vicino. Il `body` non abilita globalmente il comportamento e `#ksCatalogPage` conserva il contratto esistente.
- RequestId, busy state e replay restano idempotenti; dopo successo vengono aggiornate tutte le card equivalenti `ArticoliId/TCId`, i contatori desktop/mobile e il MiniCart, senza reload. Il form `ksNativeCartForm` resta il fallback nativo quando `fetch` non e disponibile.
- Il gate finale browser reale anonimo e PROVA e stato certificato dal Product Owner a `1365x900`, `768x1024`, `390x844` e `360x800`, inclusi scroll/slider, MiniCart, doppio click, errore visibile e assenza di doppio handler. PR #258 e integrata nel checkpoint `b87ad17a5dd346d07f9e53c0697bb562c5cb4a93`; la HOME non e per questo dichiarata completa.

### Chiusura PROMO-DISPLAY-ERROR-STATE-HARDENING-1A

- `ProductPromotionDisplayModel` distingue esplicitamente `ResolvedWithOffers`, `ResolvedWithoutOffers` e `TechnicalError`. Stato tecnico del resolver, eccezione del resolver, risultato malformato ed eccezione nel caricamento offerte falliscono chiusi, conservano soltanto il prezzo base ricevuto, producono logging sanitizzato e non rendono badge, tier, percentuali o dettagli interni.
- HOME mantiene separati snapshot riuscito ed errore tecnico e non ricade sui campi promo legacy dopo un errore; catalogo e PDP non memorizzano `TechnicalError` nelle cache di richiesta. Prezzi, IVA, resolver, provider, condizioni quantitative, campagne, carrello, checkout e ordine restano invariati.
- Verifiche tecniche: fixture isolata VB.NET `20/20`, harness promozionale `638/638`, parita anonimo `887/887`, PROVA `840/840`, differenze e duplicati zero, retirement `126/126`, precompile ASP.NET Framework 4.8, diff check e secret scan superati. Nessuna scrittura o modifica DB.
- Il task e CHIUSO / A con PR #259 integrata fast-forward nel checkpoint `23f21e6da00e726db9e361ace68de39b3d8f77eb`, un commit lineare e zero merge commit.

### STOREFRONT-PROMO-BULK-PERFORMANCE-1A - misure e correzione focalizzata

- Baseline request-scoped con un warm-up e due misure comparabili: ogni scenario anonimo ha caricato un solo snapshot ed eseguito una sola query promozionale per contesto. HOME `948` chiamate a `BuildForProduct`, `617` chiavi uniche e `331` duplicazioni; catalogo normale e con recenti `22/12/10`; catalogo promo `12/12/0`; PDP con Simili/Correlati/Recenti `32/32/0`; campagne singola/multipla `1/1/0` e `2/2/0`. Lo snapshot anonimo conteneva `919` righe-offerta. Il contesto PROVA, misurato read-only senza login o mutazioni, ha caricato `908` righe con una sola query e conserva parita `840/840`.
- Causa certa: la HOME eseguiva la risoluzione promozionale su tutti i pool ordinari prima che `TakeDiverseRows` scegliesse le card realmente visibili. Non e emerso alcun N+1 SQL; catalogo e PDP riusavano gia correttamente snapshot e model cache request-scoped. I dieci tentativi ripetuti del catalogo normale sono stati lasciati invariati perche corrispondono a `TechnicalError`/input non valido, stato che per contratto non puo essere memorizzato come assenza commerciale.
- Correzione minima: il pool promozionale autorizzato continua a essere risolto integralmente per filtro e ordinamento; Featured, Best Seller e Recenti vengono risolti soltanto dopo la selezione finale. Una cache per istanza pagina include articolo, variante TC, chiave completa del contesto, prezzo netto e lordo e non memorizza mai `TechnicalError`. Resolver, provider, formule, owner, campagna, HTML, CSS, JavaScript, carrello e checkout restano invariati.
- Post-fix HOME: `438` chiamate, `438` chiavi uniche, duplicazioni `0`, snapshot/query ancora `1/1` e `919` righe; riduzione di `510` chiamate (`53,8%`). I tempi di risoluzione osservati sono rimasti sostanzialmente stabili, quindi il miglioramento certificato e nei conteggi e nel lavoro evitato, non in una promessa di latenza. Tutti gli altri scenari conservano i conteggi baseline.

### Funzione digitale di recesso B2C - documentata e differita

- Base normativa primaria: [Direttiva (UE) 2023/2673](https://eur-lex.europa.eu/legal-content/IT/TXT/?uri=CELEX:32023L2673) e [D.Lgs. 31 dicembre 2025, n. 209](https://www.gazzettaufficiale.it/eli/id/2026/01/08/26G00002/SG), con introduzione dell'art. 54-bis del Codice del consumo nell'[articolo 1](https://www.gazzettaufficiale.it/atto/serie_generale/caricaArticolo?art.codiceRedazionale=26G00002&art.dataPubblicazioneGazzetta=2026-01-08&art.flagTipoArticolo=0&art.idArticolo=1&art.idGruppo=0&art.idSottoArticolo=1&art.idSottoArticolo1=10&art.progressivo=0&art.versione=1). L'[articolo 4](https://www.gazzettaufficiale.it/atto/serie_generale/caricaArticolo?art.codiceRedazionale=26G00002&art.dataPubblicazioneGazzetta=2026-01-08&art.flagTipoArticolo=0&art.idArticolo=4&art.idGruppo=0&art.idSottoArticolo=1&art.idSottoArticolo1=10&art.progressivo=0&art.versione=1) rende applicabili le modifiche dal 19 giugno 2026 ai contratti conclusi successivamente a tale data.
- Per i contratti a distanza conclusi mediante interfaccia online ai quali si applica il diritto di recesso, la funzione dovra essere evidente, facilmente accessibile e disponibile continuativamente durante il periodo di recesso. Dovra essere identificata con `Recedere dal contratto qui` o formulazione equivalente inequivocabile.
- Il consumatore deve poter fornire o confermare nome, elementi identificativi del contratto e recapito elettronico per la conferma. Dopo il riepilogo deve essere disponibile un secondo comando `Conferma recesso` o formulazione equivalente. La dichiarazione inviata prima della scadenza e tempestiva; senza indebito ritardo deve seguire una ricevuta su supporto durevole con contenuto, data e ora di trasmissione.
- La legge non prescrive esclusivamente il footer. Il disegno KeepStore prevede un accesso globale visibile, preferibilmente nel footer condiviso, e una CTA contestuale nel dettaglio ordine. La funzione pubblica non deve dipendere esclusivamente dal login; l'area autenticata puo precompilare dati noti, che il consumatore deve poter confermare.
- La motivazione non deve diventare obbligatoria e l'indirizzo IP completo non e un requisito dell'art. 54-bis. PDF, email e modulo stampabile restano canali aggiuntivi e non sostitutivi. La data ordine non equivale automaticamente all'inizio del termine per i beni: consegne multiple, consegna non conosciuta ed eccezioni richiedono regole specifiche. Nei casi incerti la richiesta va acquisita come `Da verificare`, non respinta automaticamente.
- Testi legali, privacy, esclusioni, politica resi e classificazione B2C/B2B richiedono approvazione professionale prima del rilascio. Questo manuale registra requisiti e piano tecnico, non fornisce parere legale.

Task e gate:

1. `B2C-WITHDRAWAL-COMPLIANCE-AUDIT-1A`: documentato ma differito per decisione del Product Owner; se verra nuovamente prioritizzato restera interamente read-only. Dovra mappare pagine legali, footer, area ordini, documenti vendita web, ownership, `AziendeId`, multi-dominio, distinzione B2C/B2B, fonte reale della consegna, consegne multiple, eventuali resi/RMA, mailer/template/code/retry e identificazione ordine pubblica/autenticata; proporre modello dati, DDL, indici, `EXPLAIN` read-only, manifest runtime e matrice test. Nessuna implementazione o DDL senza nuova autorizzazione.
2. `B2C-WITHDRAWAL-FUNCTION-1A`: condizionato ad audit A, review ChatGPT, autorizzazione Germano e validazione legale; potenziale release blocker. Dovra coprire percorso pubblico e autenticato, precompilazione sicura, recesso totale e valutazione separata del recesso parziale, doppia conferma, persistenza atomica, dichiarazione immutabile, timestamp UTC e vista locale, riferimento non enumerabile, ricevuta web/email durevole, outbox/retry, storico stati, notifica interna, CSRF, Origin/Referer, POST-only, idempotenza, anti-replay, rate limiting, anti-enumerazione, owner e `AziendeId` server-side, mobile-first e accessibilita.
3. `B2C-WITHDRAWAL-REFUND-AUTOMATION-1A`: futuro, separato e non autorizzato. Il primo rilascio acquisisce e prova la dichiarazione ma non annulla ordini, non effettua rimborsi, non chiama gateway, non genera movimenti magazzino e non decide automaticamente l'ammissibilita nei casi incerti.

Stime provvisorie, da aggiornare dopo l'audit: audit normativo/funzionale/architetturale `8-16h`; schema dati e servizio transazionale `12-20h`; UI pubblica/autenticata e ordini `16-28h`; ricevuta, email/outbox e gestione `12-24h`; sicurezza, test, review, PR, merge e smoke `16-28h`; sviluppo totale `64-116h`, pari a `8-14,5` giornate da 8 ore. Validazione legale esterna `4-8h`, separata; calendario indicativo `2-5` settimane, dipendente da DDL, mailer e approvazioni.

Responsabilita: Codex esegue audit e implementazioni tecniche solo nei manifest autorizzati; ChatGPT verifica fonti, perimetro, diff e gate A/B/E; Germano decide priorita, scelte commerciali e autorizzazioni; il consulente legale approva testi, privacy, esclusioni e politica resi prima del rilascio.

### Chiusura LOGIN-RETURN-CONTEXT-1A

- Base `f04fb72b407106cb2017aba8d3b652eb226a4268`, commit `ffbd78ffceaca8db96baf77548732e9b94724b1e`, merge fast-forward only e nessun merge commit. Smoke: `SMOKE UTENTE LOGIN-RETURN-CONTEXT-1A: A`.
- Contratto definitivo: `ReturnUrl` esplicito e sicuro, contesto dedicato con TTL, querystring catalogo/PDP preservata e fallback finale `/Default.aspx`.
- Header desktop, icona mobile e menu mobile condividono la policy centralizzata `PostLoginReturnUrlPolicy`; login fallito non consuma la destinazione e il login diretto senza contesto non porta piu automaticamente a `myaccount.aspx`.
- Pagine tecniche, endpoint con effetti collaterali, checkout diretto, gateway, token, redirect annidati e destinazioni esterne sono bloccati. Un checkout interrotto degrada al carrello quando necessario: nessun open redirect.

### Chiusura LOGIN-ACCESS-AUDIT-1A

- Base `ffbd78ffceaca8db96baf77548732e9b94724b1e`, commit `2ae053771284f6d3769c7d7bfd18e3a34436bc72`, merge fast-forward only e nessun merge commit. Smoke: `SMOKE UTENTE LOGIN-ACCESS-AUDIT-1A: A`, eseguito da Germano con fixture autenticata gestita fuori da Git.
- Il nuovo `App_Code/LoginAccessAuditRecorder.vb` registra subito dopo una vera autenticazione valida, sia dal login corrente sia dal percorso legacy della master: `UltimoAccesso = NOW()`, IP validato/normalizzato con `IPAddress.TryParse`, query parametrizzata, `NumeroAccessi = COALESCE(NumeroAccessi, 0) + 1` e verifica di una sola riga aggiornata.
- IPv4, IPv6, IPv4-mapped e loopback sono supportati; gli header proxy non sono considerati affidabili automaticamente. L'incremento e singolo per autenticazione e non avviene per password errata, refresh, accesso negato o visita login di un utente gia autenticato. `LoginUltimoAccesso` conserva l'accesso precedente.
- Audit e sincronizzazione carrello sono separati: una loro anomalia non espone dettagli all'utente e non blocca il login. La diagnostica non registra credenziali, token o IP completi.
- Migrazione DB manuale, fuori Git e verificata da Germano: `login.UltimoIp` da `VARCHAR(15) NULL` a `VARCHAR(45) NULL`, con charset/collation `utf8mb4 / utf8mb4_0900_ai_ci` preservati. `UltimoAccesso` resta `DATETIME NULL` e `NumeroAccessi` resta `BIGINT NULL DEFAULT 0`; nessun dato utente e stato modificato manualmente e nessun DDL/migration file e stato aggiunto al repository.

### Chiusura badge e correttezza commerciale promo

- `HOTFIX-STOREFRONT-PROMO-DEMO-BADGE-1A` e CHIUSO / A. Catena integrata: `f28052d821e6d0ee25f707732159030aa016d173`, REV1 finale `185511889279078e7b4b56c4b53b5fb59e46c1f5`; smoke `SMOKE UTENTE STOREFRONT-PROMO-DEMO-BADGE-1A: A`. Il testo hardcoded `Demo` e eliminato: prima riga `Promo`, seconda riga `-NN%` oppure `Offerta` quando manca una percentuale positiva valida. Il caso `6,00 EUR -> 4,00 EUR` rende `-33%`; un prodotto non promo non espone il badge. HOME e ProductCard/catalogo sono coerenti. Ogni precedente finding che descrive `Demo` come ancora aperto e storico superato.
- L'audit commerciale read-only sul listino 1 ha rilevato 755 testate attive, 97 scadute, 920 righe `voffertearticoli`, 894 articoli, 745 offerte, 10 testate attive non materializzate, 918 righe promo in `vsuperarticoli`, 912 promo inferiori al prezzo base e 6 uguali o superiori. Le offerte anomale sono `6534`, `19570`, `19571`, `12565`, `17332`, `17654`: cinque superiori al prezzo base e una uguale. La correzione commerciale dei dati resta manuale e fuori Git. Le 10 testate non materializzate puntano ad articoli disabilitati e sono legittimamente escluse dallo storefront; l'eventuale pulizia amministrativa e facoltativa.
- Finding architetturale promo: `CreaVistaPromo()` esegue cancellazione globale e reinserimento non atomico, senza staging/swap o transazione robusta; la tabella materializzata non ha chiave univoca e usa precisione a tre decimali. `AggiornaOfferte2` non e equivalente e non va usata come sostituzione senza audit DB dedicato. Audit e runtime non hanno effettuato scritture DB.
- `PROMO-COMMERCIAL-CORRECTNESS-1A` e CHIUSO / A sul branch `task/promo-commercial-correctness-1a`: base `185511889279078e7b4b56c4b53b5fb59e46c1f5`, commit principale `9e4f33ec11afe738ae4a08fac43a73af29e2d1a3`, REV1 finale/stable `e4211b7eb50c384898c78f78ce0b38e2832ce472`, merge fast-forward only senza merge commit; smoke `SMOKE UTENTE PROMO-COMMERCIAL-CORRECTNESS-1A REV1: A`.
- Contratto commerciale: una promo diventa prezzo principale solo se valida, attiva, applicabile alla quantita 1, positiva e inferiore al prezzo base. `QntMinima` e `Multipli` restano regole distinte; un tier non sostituisce il prezzo immediato ed e comunicato separatamente con quantita minima o multipli. Storefront e carrello non devono promettere prezzi incompatibili. HOME usa uno snapshot in-memory per prodotto; catalogo mantiene prezzo visibile e `data-ks-price` coerenti; PDP usa il riepilogo condiviso ed esclude promo invalide. Il carrello resta fonte di verita. Non tutti gli N+1 promo sono eliminati: bulk e performance restano backlog.
- REV1 HOME: le CTA superiori seguono la struttura ONSUS dei Visti di recente, con pulsante circolare a sola icona carrello, area stabile `44x44px`, nessuna espansione geometrica in hover/focus/active/busy, tooltip desktop non essenziale e funzione disponibile su touch. Il vecchio contratto della CTA HOME rettangolare rossa con testo `Acquista` espandibile resta storico autentico ma e superato dalla REV1 corrente.
- Badge `Promo` e `Ricondizionato` sono raccolti in uno stack angolare fuori dal flusso, senza sovrapposizioni. Verifica reale articolo `16483`: `Promo -58%`, prezzo promo `1.500,00 €`, listino `3.600,00 €`; slot prezzi deterministici `66px` emphasized e `52px` compact, nessun valore troncato o simbolo euro separato, sei DealCard della stessa altezza. QA mobile reale `360/390/430/768px` e desktop `1365px`.
- Contratto EAN/GTIN: le etichette umane delle superfici runtime autorizzate usano `EAN/GTIN`, inclusi ricerca desktop/mobile, PDP/Informazioni prodotto e pagine stampa/documenti/promozioni coperte. Nomi tecnici DB `Ean`, variabili, SQL, business key `EAN:`, feed, CSV/XML, integrazioni e proprieta JSON-LD `gtin*` restano invariati; EAN e comunicato come GTIN-13 senza migrazione dei contratti macchina. Il cleanup globale non e completo: `Public/ui/controls/ProductDetailView.ascx`, preview diagnostica non operativa, conserva due label `EAN:` come finding nominativo futuro.

### Chiusura PROMO-OWNER-ENFORCEMENT-1A REV2.7A

- Esito definitivo: implementazione A, review conclusiva indipendente A e `SMOKE UTENTE PROMO-OWNER-ENFORCEMENT-1A REV2.7A: A`. Catena integrata fast-forward, senza merge commit: `9ed2802aebd6b40468fe99e79a644b0fe549bcd8` -> `3b207c3a58e52af6c6d603ba4748b0d2cd788c4f` -> `1f646b2a4e0069c8fb0ea62b15c21030157db77a` -> `30928ee81b9bbdc23b55c5aaa057ef1bf4b5d3ef`; `main` / `origin/main` invariati.
- Contratto owner storico di quel checkpoint (ora prevale il modello ksc1/ksc2): Contratto owner: il carrello anonimo appartiene a `Session.SessionID`; quello autenticato a `LoginId`. La promozione del carrello di sessione al login non equivale all'autorizzazione alle offerte personali: una promo pubblica ha `UtentiId IS NULL OR UtentiId <= 0`, mentre una promo personale e applicabile solo all'utente autenticato corrispondente. L'identita commerciale non proviene mai dal browser.
- Policy promo uniforme su HOME, catalogo, PDP, add-to-cart, carrello e ordine: corrispondenza prima su `ArticoliId + TCId`, poi fallback articolo consentito; tra le offerte valide vince il prezzo netto piu basso e, a parita, l'`OfferteDettaglioId` deterministico. Offerte disabilitate, fuori data/listino/owner, non positive o non migliorative sono escluse. La combinazione ambigua `QntMinima + Multipli` e esclusa fail-closed; un errore tecnico e distinto da "nessuna promo" e blocca l'operazione sensibile.
- Quantita delta firmata: `quantita finale = quantita esistente + delta`. Quindi `0 + 1 = 1`, `2 + 0 = 2`, `2 + 1 = 3`, `5 + (-2) = 3`; un delta che porterebbe a zero rimuove la riga secondo il percorso autorizzato, mentre risultati negativi o richieste non valide sono rifiutati. Il server, non il client, resta autorita.
- Atomicita: quantita, netto, lordo, `OfferteDettaglioId` e spedizione gratuita sono ricalcolati server-side con `Decimal` e persistiti nella stessa transazione, sotto lock owner-scoped e con rollback completo. Login merge, modifica carrello, add e ordine rivalidano la promo; ordine e `Carrello_Documento` condividono la transazione. Un errore tecnico blocca l'ordine e conserva il carrello; una promo scaduta viene rimossa/ricalcolata prima della conferma.
- `Prodotto_Gratis` significa spedizione gratuita, non articolo omaggio. Il valore client `pg` non e autorevole: l'idoneita e ricalcolata da stato abilitato, date e token listino esatto (`1` non coincide con `11`); valori malformati falliscono chiusi. La regola e rivalidata su add, variazione quantita, merge login, carrello e ordine.
- Presentazione anonima: percentuali e prezzi promo derivano direttamente da `Decimal`, mai da testo, `SafeDbl` o `Double`; valori null/non numerici sono nascosti e la percentuale valida e `1-99`. Fixture `21906`: anonimo q1 `5,00 / -17%`, multiplo 5 `4,00 / -33%`; prove: q1 `4,09` offerta `27003`, q5 `3,28` offerta `27004`, q6 `4,09` offerta `27003`, q10 `3,28` offerta `27004`.
- Mutazioni HTTP: `cart_add.aspx`, `aggiungi.aspx` e `catalog_cart_async.aspx` accettano solo POST; GET/HEAD non mutano, rendono `405 Method Not Allowed` con `Allow: POST`. CSRF legato alla sessione, controllo Origin/Referer, `ReturnUrl` locale e dati commerciali ignorati dal browser restano obbligatori. Ogni intenzione/CTA usa un GUID; fingerprint owner/operazione/articolo/TCId/delta e stati pending/processing/completed/indeterminate governano replay, collisioni, lease e redirect `303`, con chiave massima 64 caratteri e TTL 15 minuti.
- Prerequisiti DB verificati: indici `IX_carrello_LoginId_ID (LoginId, id)` e `IX_carrello_SessionId_ID (SessionId, id)`; gli `EXPLAIN` owner-scoped non devono degradare a `ALL`. Dipendenza runtime: `Bin/System.Threading.Tasks.Extensions.dll`, assembly `4.2.0.1`, 25.984 byte, SHA-256 `4F81FFD0DC7204DB75AFC35EA4291769B07C440592F28894260EEA76626A23C6`, richiesta da MySql.Data 8.0.33; nessun binding redirect necessario nel runtime verificato.
- Debiti cart esplicitamente aperti, in ordine: `CART-REMOVE-TRANSACTION-HARDENING-1A`, `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A`, `CART-MOBILE-RESPONSIVE-UX-1A`, touch target rimozione `44x44` e audit dei monetari DB `DOUBLE`. `CART-BATCH-ATOMICITY-1A` e `CART-DEADLOCK-RETRY-1A` sono chiusi. Coupon/Groupon non e stato corretto o certificato: Germano non usa oggi quel flusso; resta differito a `COUPON-CART-LIFECYCLE-1A` e non va riaperto senza richiesta esplicita. I percorsi GET legacy non vanno presentati come funzionanti.

### Storico audit e hotfix route promozioni legacy

- Stato storico al momento dell'audit, superato dalle PR #255 e #256: `STOREFRONT-PROMO-ROUTES-AUDIT-1A` fu COMPLETATO / A come audit interamente read-only, con zero file, branch, commit o scritture DB. In quel checkpoint `promozioni.aspx` era ancora una route legacy classificata C e non sostituibile tramite redirect immediato.
- La route legacy mantiene GridView/markup, selettore campagna `pid`, filtri legacy, potenziale inclusione per `UtentiID`, `noindex,follow`, canonical verso `/promozioni.aspx`, assenza dalla sitemap, autoriferimenti e whitelist post-login. Non e collegata dalle superfici storefront moderne. La route moderna e invece collegata da header desktop/mobile e HOME e usa listing ONSUS, filtri, ordinamento, paginazione, ProductCard, promo helper condiviso e add-to-cart asincrono.
- Le route non sono equivalenti: 25 prodotti risultano solo nella moderna e 22 solo nella legacy. Contratti `pid` e `UtentiID`, quantita minima/multipli e filtri legacy non sono ancora migrati. Tre offerte personalizzate sono attive globalmente, ma nessuna era applicabile al listino 1 della sessione verificata. Le querystring tassonomiche presenti nel markup legacy non risultano mappate in modo affidabile dalla pipeline corrente.
- Causa del 500 provata: `CaricaArticoli()` leggeva `vOfferteDettagli`, inseriva descrizione, immagine, date, prezzi e altri dati DB dentro literal SQL e generava centinaia di `UNION ALL`. Un apostrofo chiudeva il literal e un successivo `@CLIP` diventava un falso parametro MySQL, con `Parameter '@CLIP' must be defined`. Sono state rilevate 13 descrizioni attive con apostrofo e 2 contenenti `@CLIP`; `pid=6534` riproduceva il problema, mentre `pid=14556` dimostrava che `@CLIP` da solo non era la causa.
- `STOREFRONT-PROMO-ROUTES-HOTFIX-1A` e CHIUSO / A: branch `task/storefront-promo-routes-hotfix-1a`, base `e8dd8abf35afabd783c28090bca2df58ae7d7d7b`, commit/stable `c088988080e54371a60c27c1f5979adf957358f1`, manifest esclusivo `promozioni.aspx.vb`, diffstat 66 inserimenti e 132 eliminazioni. Merge fast-forward only, nessun merge commit, parent diretto `e8dd8abf35afabd783c28090bca2df58ae7d7d7b`; smoke `SMOKE UTENTE STOREFRONT-PROMO-ROUTES-HOTFIX-1A: A`.
- Contratto finale: rimosso il reader generatore di SQL, eliminate concatenazioni DB e catena `UNION ALL`, nessun escaping manuale. Una query set-based a colonne esplicite unisce `vOfferteDettagli` e `varticolilistini`, usa ordinamento deterministico e 11 parametri tipizzati (`NListino`, `UtentiID`, `Data`, `pid`, `pmr`, `pst`, `pct`, `ptp`, `pgr`, `psg`, `part`). I dati restano dati, le Session numeriche sono convertite in interi e il risultato vuoto produce HTTP 200 con zero righe.
- Parita tecnica: 935/935 righe, differenza multiset zero complessiva e per i `pid` verificati. `pid=6534`: HTTP 200 e una riga; `pid=14556`: HTTP 200 e due righe; `pid=99999999`: HTTP 200 e zero righe. Zero scritture DB.
- Campione tecnico, non benchmark generale: query precedente circa 505.646 caratteri, 934 rami e 933 `UNION ALL`; query fissa circa 1.487 caratteri. Prova read-only: riferimento circa 9.696 ms, set-based circa 1.689 ms. Sono risolti la rottura/second-order SQL injection causata dai contenuti DB, l'apostrofo, il falso parametro `@CLIP` e la query monolitica; non sono dichiarate risolte performance promo generali, N+1 storefront, materializzazione, grafica legacy, output encoding complessivo, migrazione route, offerte personalizzate, filtri legacy o SEO complessiva.

### Stato promo e roadmap

1. `STOREFRONT-PROMO-MODERN-PARITY-1A`: CHIUSO / A e integrato con PR #255.
2. `STOREFRONT-PROMO-ROUTE-RETIREMENT-1A`: CHIUSO / A e integrato con PR #256 al checkpoint `192701ae65ecac00c294399a686af52d98d398c1`.
3. `STOREFRONT-OFFERS-PROMO-UX-1A`: CHIUSO / A e integrato con PR #257 al checkpoint `cab4486d229e8c8e8168e2a68798b0ea6d267c4e`.
4. `HOME-ASYNC-CART-1A`: CHIUSO / A e integrato con PR #258 al checkpoint `b87ad17a5dd346d07f9e53c0697bb562c5cb4a93`; `PDP-BRAND-LOGO-1A` e assorbito dalla REV3 e non resta un task separato.
5. `PROMO-DISPLAY-ERROR-STATE-HARDENING-1A`: CHIUSO / A e integrato con PR #259 al checkpoint `23f21e6da00e726db9e361ace68de39b3d8f77eb`.
6. `STOREFRONT-PROMO-BULK-PERFORMANCE-1A`: CHIUSO / A e integrato con PR #260 al checkpoint `eb020eb7f2431d7c91e500e2f1768edcb5cc5d70`.
7. `STOREFRONT-SEO-TECHNICAL-AUDIT-1A`: CHIUSO / A e integrato con PR #261 al checkpoint `37bbfdc102ac1686a96b1b97eadd9cc6b385e0d0`.
8. `KEEPSTORE-MULTITENANT-ONBOARDING-CONTRACT-1A`: task documentale/operativo corrente; nessun runtime o database modificato.
9. Dopo chiusura A e merge: `GOOGLE-PRODUCT-STRUCTURED-DATA-1A`, quindi Merchant/AI/LLMS nei rispettivi task dedicati.

Finding separati ancora aperti: materializzazione promo, `articolix.aspx` HTTP 500 e due label `EAN:` nella preview diagnostica `ProductDetailView.ascx`. I precedenti delta 25/22, la parita owner/campagna, GridView/add-to-cart di `promozioni.aspx`, HOME async cart e performance bulk promo sono superati dalle PR #255-#260. Catalogo, PDP, Google structured data e AI non sono dichiarati completi dal solo task SEO tecnico.

### Chiusura PDP-COMMERCIAL-INFO-SHIPPING-1A

- Perimetro chiuso: informazioni commerciali e tariffe spedizione della sola PDP `articolo.aspx`. La catena runtime e `f32e3b1e0153cc8931c2fe282f78da489983ceb8` -> `afc4c72c148984ba729c6cb20de38161dc56e2b4` -> `91cbc10b3b343217e18c5a9a6707b72997467b00`; merge fast-forward only, nessun merge commit, smoke Germano A. Questa chiusura non dichiara completa la PDP ne il catalogo.
- `Visite` e ora dentro `Informazioni prodotto`: incremento parametrizzato soltanto sul primo GET valido dell'articolo nella sessione; postback, refresh successivi dello stesso articolo e prefetch sono esclusi, mentre una nuova sessione viene conteggiata normalmente.
- Garanzia: `Mesi` e `Garanzia` producono la sintesi; `NormeGaranzia` alimenta il testo esteso reale in disclosure accessibile. Output HTML-encoded, dato mancante `—`, nessuna durata o norma inventata.
- Prezzo di Listino: usa `ListinoUfficiale`, memorizzato netto. Con `IvaTipo=1` resta netto; altrimenti segue reverse charge, IVA utente e IVA articolo. Non viene sostituito dal prezzo di vendita e non genera un falso sconto.
- Peso: `articoli.Peso` e stato verificato in Kg e viene mostrato solo quando positivo e valido; dato assente o non valido conserva il fallback.
- Contratto spedizione corrente: la spedizione gratuita valida per listino e date ha priorita. In caso contrario la PDP risolve server-side le tariffe reali del singolo articolo da `vvettoricosti` e `vettoricosti`, filtrate per `AziendeId`, `Abilitato=1`, `Web=1`, `Promo=0`, costo positivo, assenza di soglie dipendenti dall'ordine e prima fascia `PesoMax` compatibile. Mostra tutti i vettori applicabili: due opzioni immediate e le ulteriori in disclosure, con logo, descrizione e prezzo. Il fallback e neutro, senza `0,00 €`, vettori inventati o immagini rotte.
- Il precedente contratto storico `Spese di spedizione calcolate nel carrello.` e superato. Oggi la PDP mostra tariffe reali applicabili al singolo articolo e al suo peso; il carrello resta fonte di verita per composizione completa dell'ordine, destinazione, promozioni, metodo selezionato e costo definitivo. Resta corretta la frase `Le opzioni e il costo definitivo vengono mostrati nel carrello.`
- REV1 IVA: l'implementazione iniziale usava impropriamente `vettori.Iva`; la REV1 adotta il contratto del carrello. `IvaTipo=1` mostra `CostoFisso` netto; altrimenti usa `CostoFisso * (1 + Iva_Vettori/100)`. Se `Iva_Vettori` e assente, negativo o non valido non inventa importi e attiva il fallback neutro. Il comportamento copre utenti autenticati, esenti o con IVA personalizzata.
- Sicurezza loghi: path `/Public/assets/images/vettori/`, solo basename proveniente dal DB, estensioni in whitelist, esistenza fisica obbligatoria e blocco di traversal, URL esterni e schemi. In assenza di logo valido resta il fallback testuale. Gli unici asset nominativamente tracciati dal task sono `LICCARDI.png` e `sda.jpg`.
- Manifest runtime complessivo: `App_Code/ProductShippingRateResolver.vb`, `Public/assets/images/vettori/LICCARDI.png`, `Public/assets/images/vettori/sda.jpg`, `Public/assets/keepstore/css/product-ui.css`, `articolo.aspx`, `articolo.aspx.vb`.
- Verifiche concluse: precompile ASP.NET Framework 4.8, HTTP essenziali, dati DB/rendering, visite tra sessione/refresh/postback/prefetch, spedizione gratuita e fallback, desktop/mobile reali a `1365`, `768`, `430`, `390` e `360px`, nessun overflow, `git diff --check` e secret scan tutti OK; smoke Germano A.
- Roadmap storica al checkpoint 2026-09-03: `LOGIN-RETURN-CONTEXT-1A`, `PDP-BRAND-LOGO-1A`, verifica promo soltanto con dati reali attivati, infine AI/Gemini/LLMS. E superata dalla roadmap promo corrente nel checkpoint 2026-09-04.

## Contratto operativo Germano / ChatGPT / Codex

### Germano

- Decide priorita e perimetro.
- Concede le autorizzazioni finali richieste, incluso il merge, e valuta il risultato commerciale.
- Approva scelte funzionali e grafiche.
- Non esegue comandi Git, operazioni GitHub, creazione/aggiornamento PR o merge.
- Puo fermare o riorientare i micro-task in qualsiasi momento.

### ChatGPT

- Analizza contesto e report.
- Pianifica micro-task.
- Scrive istruzioni operative per Codex.
- Definisce guardrail.
- Verifica i report Codex.
- Applica la lettura documentale proporzionata definita nel root `AGENTS.md`, verifica direttamente GitHub/Git reale e legge i file runtime o template coinvolti prima dei prompt importanti.
- Controlla stable, task branch, commit, parent, compare e diff pertinenti prima di valutare il problema o scrivere un prompt.
- Classifica gli esiti come A/B/E.
- Dopo la review indipendente del diff pubblicato stabilisce se il lavoro puo avanzare.
- Decide il prossimo micro-task da proporre.
- Mantiene aggiornato il masterplan.
- Non deve saltare passaggi o cambiare metodo.

### Codex

- Esegue materialmente tutte le operazioni tecniche autorizzate.
- Crea branch dedicati.
- Modifica file entro il perimetro autorizzato.
- Esegue build, precompilazioni, `git diff --check`, smoke tecnici e browser automatizzabili.
- Dopo commit e push riusciti apre o aggiorna la PR verso la base indicata, salvo stop condition esplicita.
- Per ogni branch runtime esegue il push su origin prima del report finale e della review ChatGPT, salvo impedimento tecnico esplicitamente documentato.
- Non deve cambiare perimetro senza fermarsi.
- Controlla la superficie autorizzata e le dipendenze dirette pertinenti; cerca attivamente bug collegati, regressioni, rischi e incoerenze di sicurezza, performance o UX.
- Classifica ogni finding significativo con evidenza, superficie, severita, impatto, capacita di bloccare il requisito e proposta `SAME-TASK CANDIDATE` o `SEPARATE MICRO-TASK`; non lo implementa senza decisione ChatGPT.
- Non deve toccare `main`.
- Non deve creare pagamenti, ordini o chiamate gateway senza autorizzazione.
- Dopo A di ChatGPT e autorizzazione esplicita di Germano esegue il merge fast-forward, la sincronizzazione e le verifiche finali; non decide autonomamente il merge.
- Riporta esiti in modo preciso.

### Metodo

- Ogni lavoro passa da micro-task.
- A ogni chiusura con esito A, il rapporto conclusivo deve indicare automaticamente il prossimo task consigliato, ricavato dal manuale e dai finding aperti. Deve riportare nome, motivo, prerequisiti e stato NON AVVIATO. Nessun task successivo deve essere avviato o implementato senza autorizzazione del Product Owner.
- Un solo task resta attivo per volta e il successivo non parte finche il prerequisito non e chiuso.
- Il solo sistema corrente di classificazione e A/B/E: `A` = requisito autorizzato completato, verificato e chiudibile, senza blocker noti nel perimetro; `B` = direzione valida ma task incompleto, bloccato o in attesa di fix, autorizzazione, verifica tecnica o smoke; `E` = premessa, strategia o modifica errata/pericolosa, regressione grave introdotta o approccio da abbandonare e riprogettare. Un blocker tecnico scoperto prima di una modifica pericolosa e normalmente B, non E.
- Un task UI in attesa di una conferma umana obbligatoria e non automatizzabile resta B. Non usare classificazioni operative diverse; le lettere presenti in task-id o record storici restano invariate.
- Ogni merge avviene soltanto dopo esito A e autorizzazione esplicita; merge e docs-only non ripetono build/browser/smoke gia conclusi.
- Per refactor UI si usa prima audit ONSUS, poi implementazione coerente.
- Niente patch sul vecchio layout quando si cambia grafica/impostazione.
- Usare sempre campi DB esistenti e query/logiche esistenti quando possibile.
- Modifiche strutturali o logiche vecchie richiedono prima analisi impatto e proposta micro-task.

### Metodo Codex Token-Safe / One-Shot

- Prima di dare prompt a Codex, ChatGPT deve consolidare piano, scope, file ammessi, vincoli, verifiche, output e criterio A/B/E.
- I prompt devono essere piccoli, one-shot e contenere solo il contesto necessario; non copiare l'intera storia della chat.
- HEAD, manifest, divieti, verifiche e output devono essere sempre espliciti.
- Evitare prompt esplorativi quando causa e fix sono gia chiari: un task deve avere un solo prompt operativo principale.
- Revisioni successive sono ammesse per blocchi reali, non per perfezionismo documentale o per inseguire il commit documentale appena creato.
- La documentazione deve registrare PR, branch, commit funzionale principale, stato, smoke e decisioni; i commit documentali successivi restano tracciati da Git/PR e non generano automaticamente nuove REV.
- Cleanup branch e housekeeping sono secondari: usarli solo su richiesta esplicita o se sbloccano il flusso. Prima di cancellare branch verificare sempre che non esistano commit assenti da `frontend-rebuild`.
- Se un problema e solo sospetto o non riproducibile, prima fare test manuale mirato; aprire PR diagnostiche solo se il problema torna riproducibile.
- ChatGPT decide piano, ordine e priorita; Codex esegue task piccoli, verificabili e con confini rigidi. Evitare task generici tipo "controlla tutto".
- Dopo commit e push Codex apre o aggiorna la PR; ChatGPT verifica indipendentemente il diff pubblicato. PR e merge restano separati: Codex esegue il merge solo dopo A di ChatGPT e autorizzazione esplicita di Germano.
- Priorita: regressioni o blocker, smoke, merge controllato, documentazione minima, poi task successivo. Cleanup solo se richiesto o necessario a sbloccare il flusso.
- Evitare audit generici tipo "controlla tutto" e verifiche ripetute senza un motivo tecnico reale. Le idee fuori scope vanno registrate nel backlog, non implementate subito.
- I comportamenti gia accettati diventano guardrail anti-regressione dei task successivi.

Richiamo operativo alla policy permanente definita nel System Blueprint, sezione `2.1.1`:

- ChatGPT assegna a ogni task un profilo `ECONOMY`, `STANDARD`, `DEEP` o `CRITICAL`, scegliendo il livello meno costoso compatibile con una elevata probabilita di A al primo passaggio; qualita, sicurezza e test necessari non si riducono per risparmiare token.
- Policy corrente: `ECONOMY` = GPT-5.6 Luna / Medium; `STANDARD` = GPT-5.6 Terra / Medium; `DEEP` = GPT-5.6 Sol / High; `CRITICAL` = GPT-5.6 Sol / Extra High. GPT-6 Astra e riservato a casi eccezionali e trasversali scelti esplicitamente da ChatGPT; Max e Ultra non sono default e Ultra non si usa ordinariamente. Ogni prompt dichiara modello, reasoning e motivazione; la policy va rivalutata se cambia la disponibilita reale dei modelli.
- Ogni task runtime applica la Minimum Verification Baseline e una proactive engineering review mirata alla superficie e alle dipendenze reali, con root cause e controlli anti-regressione proporzionati.
- Codex analizza, testa e segnala finding, ma non amplia autonomamente scope/manifest e non implementa migliorie extra. ChatGPT decide se ignorare, mettere in backlog, creare un micro-task, richiedere una REV o autorizzare un'estensione.
- Con causa gia dimostrata `ECONOMY`/`STANDARD` possono procedere con un prompt implementativo diretto; `DEEP` con root cause incerta richiede investigazione read-only; `CRITICAL` richiede preflight/investigazione prima delle modifiche, salvo correzione gia completamente dimostrata e autorizzata. Non separare artificialmente investigazione e implementazione se cio duplica il lavoro senza ridurre il rischio.
- La metrica economica e il costo totale per task chiuso correttamente: rework, REV evitabili e regressioni sono inefficienza. Il dettaglio normativo completo e la Definition of Done restano nel System Blueprint, senza duplicazione nel Masterplan.

### Protocollo canonico fonti, continuita e Git

Il root `AGENTS.md` e la fonte canonica delle regole operative permanenti. Prima dei prompt importanti ChatGPT verifica Git/codice reale e applica una lettura proporzionata:

1. nuova chat o audit generale: checkpoint Masterplan e fonti necessarie a ricostruire lo stato; lettura integrale solo se richiesta dall'ampiezza dell'audit;
2. nuovo task: checkpoint corrente, sezioni pertinenti, contratti chiusi collegati e file runtime coinvolti;
3. task UI: anche contratti ONSUS, mobile e componenti stabilizzati;
4. carrello, login, prezzi, promo, checkout, ordine, DB o sicurezza: sezioni architetturali e di sicurezza pertinenti;
5. search/AI/RAG/SEO AI/assistenza acquisto: anche AI Assisted Search Blueprint;
6. task documentale trasversale o riconciliazione generale: lettura completa delle fonti coinvolte.

Ordine vincolante delle fonti:

1. richiesta corrente approvata da Germano;
2. Git, codice, database e runtime reale per lo stato tecnico;
3. root `AGENTS.md` per le regole operative permanenti;
4. checkpoint corrente del Masterplan;
5. System Blueprint per architettura, flussi e contratti;
6. AI Assisted Search Blueprint soltanto per search, AI, RAG, SEO AI o assistenza acquisto;
7. handoff, memoria, chat e allegati come supporto non autoritativo.

Gli SHA e lo stato Git reale prevalgono sui checkpoint documentali non ancora aggiornati. Handoff, memoria e allegati sono supporto, non source of truth. Nessuna richiesta corrente autorizza implicitamente modifiche a `main`, esposizione di segreti o merge non approvati.

#### Contratto permanente WORKING-COPY-CANONICA e sincronizzazione post-merge

- `C:\KeepStoreWeb\KeepStore3.0\` e la working copy operativa canonica del Product Owner: da qui Germano preleva i file approvati per copiarli sul server. Deve rappresentare il `frontend-rebuild` stabile approvato, non conservare permanentemente file runtime di task non ancora approvati/mergeati. I task possono usare worktree isolate; durante uno smoke e ammessa una sostituzione temporanea nella copia canonica solo con backup e ripristino byte-per-byte verificati.
- Ogni branch runtime o docs deve essere pushato su origin prima del report; una modifica solo locale o solo descritta in chat non e chiusa.
- Ogni task parte con `git fetch` e verifica degli SHA. Dopo ogni merge runtime autorizzato, la chiusura tecnica richiede la sincronizzazione fast-forward della copia canonica allo stesso SHA di `frontend-rebuild == origin/frontend-rebuild`: i file runtime approvati devono essere realmente presenti nella cartella da cui Germano distribuisce. Verificare staging vuoto e preservare modifiche locali/configurazioni autorizzate, incluso `web.config`, e tutti gli untracked autorizzati. Se la sincronizzazione e bloccata, esito B: non dichiarare chiuso il runtime lasciando la copia canonica indietro.
- Per task docs-only, i manuali si allineano nel normale merge/sincronizzazione stabile; la sincronizzazione runtime non impone build o smoke non pertinenti.
- Gli aggiornamenti locali sono esclusivamente fast-forward; reset, rebase e force non autorizzati sono vietati. `main` non va modificato.
- Le directory non tracciate `Public/assets/images/articoli/`, `Public/assets/images/marche/`, `Public/assets/images/settori/` e `Public/assets/images/vettori/` vanno sempre preservate fuori da staging e commit, salvo asset nominativamente autorizzati dal manifest.

### Contratto permanente MOBILE-FIRST / MOBILE-EXCELLENCE e divisione efficiente dei test

- Smartphone e tablet sono superfici ecommerce primarie, non versioni ridotte o secondarie: progettazione e QA sono mobile-first, nell'ordine `360px`, `390px`, tablet, desktop. Le funzioni pertinenti devono mantenere parita funzionale e qualita UX almeno pari nei compiti di consultazione e acquisto; differenze desktop/mobile sono intenzionali e non eliminano capacita essenziali. Responsive significa uso agevole, non solo layout che non si rompe.
- Navigazione, ricerca, catalogo, filtri, PDP, varianti, wishlist/compare quando pertinenti, carrello, login/account, checkout e funzioni commerciali devono funzionare con touch; nessuna funzione ecommerce essenziale e desktop-only o hover-only.
- QA UI/UX: verificare touch target, leggibilita, ordine visuale, densita, layout responsive, offcanvas/menu, scrolling, modali, immagini, CTA, form/input, assenza di overflow orizzontale e di contenuti essenziali nascosti. ONSUS resta riferimento UI/UX anche responsive, ma non impone pattern incompatibili con dati e funzioni reali KeepStore.
- Nessun task UI/UX dichiara A visuale mobile senza verifica browser pertinente. Una verifica desktop non certifica smartphone/tablet; se la verifica visuale mobile manca, dichiararlo esplicitamente senza promettere perfezione assoluta.
- Codex esegue per impostazione predefinita tutti i test e smoke tecnici/browser automatizzabili: build/precompile, JavaScript, DOM/computed style, console/runtime, sicurezza, diff, manifest, branch e working tree.
- Germano interviene soltanto per conferme umane visive, commerciali o funzionali realmente non automatizzabili o dipendenti da sue fixture/dispositivi; ChatGPT fornisce pochi passaggi semplici. Germano non esegue Git/GitHub.
- Un blocco tecnico di strumenti, autenticazione o permessi produce B con prova precisa: non va aggirato e l'operazione non va trasferita automaticamente a Germano. Merge e task docs-only non ripetono test gia conclusi e non pertinenti.

### Contratto permanente stack, linguaggio e sicurezza

- Ogni prompt runtime Codex deve includere una sezione "Stack e divieti tecnici".
- Stack obbligatorio da dichiarare: ASP.NET WebForms, VB.NET, .NET Framework 4.x, MySQL, code-behind `.aspx.vb`/`.ascx.vb`, `Page.master`, controlli ASCX e `App_Code`.
- Codex non deve proporre o introdurre C#, ASP.NET Core, Razor Pages, MVC/MVC Core, Blazor, Entity Framework Core, migrations, controller/API rewrite, dependency injection moderna non presente, minimal API, template ASP.NET Core, TypeScript build pipeline, npm/Vite/Webpack non gia presenti o nuove librerie senza audit e approvazione.
- Non convertire pagine WebForms in MVC/Razor/Core e non proporre riscritture architetturali non autorizzate. Se sembra necessaria una tecnologia diversa, Codex deve fermarsi, motivare e non modificare file.
- Ogni modifica deve restare compatibile con WebForms/VB.NET, .NET Framework 4.x e con il ciclo di build/precompile ASP.NET gia usato.
- "Codice fresco ma compatibile": UX, sicurezza e qualita possono modernizzarsi con HTML/CSS/JS compatibile, ma WebForms server-side resta fonte di verita per carrello, prezzi, listini, IVA, promo, sessione, login e checkout. Nessun calcolo commerciale solo browser e nessuna duplicazione della logica carrello lato JS.
- Ogni task che tocca input utente, URL, querystring, form, carrello, login, checkout, ordine, e-mail, upload, immagini o redirect deve verificare validazione server-side, query parametrizzate, whitelist per campi dinamici/ordinamenti/redirect/nomi file, output encoding, CSRF/ViewState dove pertinente, nessun open redirect, nessun segreto hardcoded, nessun log con dati sensibili, nessun path traversal, nessun `Public/Images/` legacy e nessuna modifica DB/schema/SP senza task dedicato.
- Riferimenti metodologici: OWASP Top 10, OWASP ASVS e documentazione Microsoft ASP.NET WebForms / ASP.NET 4.x security.
- Nessun sito va dichiarato "a prova di hacker" in senso assoluto. Obiettivo operativo: ridurre superficie d'attacco, rendere ogni modifica verificabile, applicare controlli server-side, eseguire scan/test, proteggere segreti/sessioni/redirect e tenere sotto controllo le regressioni.

### Stato reale, perimetro chiuso e scaletta prioritaria ufficiale

Stato Git corrente al 2026-09-03 dopo il fast-forward `PDP-COMMERCIAL-INFO-SHIPPING-1A`:

- `frontend-rebuild` / `origin/frontend-rebuild`: `91cbc10b3b343217e18c5a9a6707b72997467b00`.
- `main` e `origin/main`: `976e99f17cabc8a5c6a8715463444edfeaadcd91`.
- Working tree atteso: pulito salvo eventuali asset immagini non tracciati preservati. Le directory `Public/assets/images/articoli/`, `Public/assets/images/marche/` e `Public/assets/images/settori/` non vanno committate; eventuali loghi locali in `Public/assets/images/vettori/` richiedono autorizzazione nominativa nel manifest.

Regola permanente "task specifico chiuso" vs "area/pagina completa":

- Un micro-task chiuso certifica solo il perimetro dichiarato nel task, non l'intera pagina o area funzionale.
- Non scrivere "pagina completa", "catalogo completo", "articoli.aspx completata" o formule equivalenti se manca un task dedicato di parity/audit completo con ONSUS, smoke reale desktop/mobile e documentazione.
- Quando una pagina ha molti task chiusi, descrivere sempre "micro-task X/Y/Z chiusi su quella pagina" e tenere separato lo stato della pagina intera.
- Esempio vincolante `articoli.aspx`: sono chiusi multiselect catalogo / `Aggiungi selezionati al carrello`, quantita gia nel carrello su card catalogo, delta quantita catalogo, visual mobile della quantita gia in carrello e CTA `Acquista` catalogo con icona standard. Esistono inoltre micro-task documentati su search/suggest, zero-results, sidebar/facet e applied filters, ma non vanno letti come chiusura completa di quelle funzioni dentro la pagina catalogo.
- Nota anti-false-closure: `articoli.aspx` non e una pagina dichiarata completa. I micro-task chiusi non equivalgono alla parita ONSUS completa. `CATALOG-ONSUS-PARITY-AUDIT-1` e terminato; immagini prodotto 404, pager/posizione recent, quattro viste mobile e compact grid sono stati chiusi da task successivi; Price e chiuso dalla PR #310 e Marche load-more e implementato dal micro-task sotto riportato, con review/smoke server ancora richiesti. Restano da completare per micro-task sidebar/facet residui, tassonomie, active-filter legacy/reset, Deals/Condition, Reviews solo con dati reali, performance, componenti commerciali e responsive complessivo.
- `articoli.aspx` resta area aperta per ONSUS parity completa: `1A` ha stabilizzato stato/paging e `1B` ha riallineato toolbar/view controls, senza chiudere gli altri gap dell'audit.

Stato sintetico dei blocchi chiusi:

- Catalogo `articoli.aspx`: oltre ai micro-task multiselect, quantita/delta/visual mobile in carrello e CTA `Acquista`, sono chiusi `CATALOG-ONSUS-PARITY-1A` per stato/paging deterministico, `CATALOG-ONSUS-PARITY-1B-TOOLBAR-CONTROLS` per toolbar, `1C` per immagini prodotto e il blocco mobile/cart/catalog corrente per quattro viste, compact grid, pager, posizione recent e geometria card. Zero-results, sidebar/facet, Settori/applied filters, performance e search/suggest mantengono il proprio perimetro documentato. I gap P1/P2 residui restano aperti: non dichiarare il catalogo completo.
- PDP `articolo.aspx`: chiusi `PDP-BUY-CTA-ACQUISTA-AUDIT-1`, runtime `PDP-BUY-CTA-ACQUISTA-1A/1B` e il micro-perimetro quantita/stato carrello assorbito da `STOREFRONT-CART-STATE-PERSISTENCE-1A`; la pagina non e dichiarata completa. Il blocco typography globale e chiuso, mentre side cart e altre evoluzioni restano task separati.
- Riconciliazione storica PDP: eventuali righe precedenti che elencano `PDP-BUY-CTA-ACQUISTA-1A` come backlog descrivono lo stato al momento della relativa chiusura catalogo/HOME/header e sono superate dalla chiusura PDP a HEAD `3b0b2ac97564c497abd26d224e5e945834a2ec26`.
- HOME: chiusa CTA `Acquista` HOME, allineamento `icon-cart-2` con catalogo, blocco `Occasione Imperdibile` e standard CTA commerciale unico.
- Carrello: chiuso `Continua lo Shopping` verso ultima pagina/contesto reale con URL locali normalizzati e protezione checkout/loginrequired preservata.
- Header/menu: chiusa leggibilita desktop del mega menu `Catalogo`; menu Catalogo mobile resta aperto.
- Stack/sicurezza: chiuso e documentato il contratto permanente WebForms/VB.NET/.NET Framework/MySQL, con divieti C#/ASP.NET Core e checklist sicurezza.
- Typography storefront: blocco CHIUSO / A. `GLOBAL-TYPOGRAPHY-ONSUS-AUDIT-1`, `GLOBAL-TYPOGRAPHY-ONSUS-1A` e `GLOBAL-TYPOGRAPHY-ONSUS-1B` sono chiusi con esito A; foundation deterministica `Arial, sans-serif`, famiglie testuali residue normalizzate nel layer KeepStore finale, Icomoon preservato e scale ONSUS invariate. `GLOBAL-TYPOGRAPHY-ONSUS-1C` e NON NECESSARIO / NON CREATO dopo smoke Germano A e assenza di Times/Poppins accidentali sulle superfici testate. La chiusura vale soltanto per la typography e non rende complete HOME, catalogo, PDP, header o footer.
- Cart-state storefront: `STOREFRONT-CART-STATE-PERSISTENCE-REGRESSION-AUDIT-1` chiuso come audit diagnostico B/procedibile e `STOREFRONT-CART-STATE-PERSISTENCE-1A` chiuso con esito A al commit `68325c1879e2859628b59f297fe2a329b5aadb35`; HOME, catalogo e PDP condividono ora uno snapshot server-side request-scoped. Questa chiusura non rende complete le tre pagine.

### Chiusura CATALOG-ASYNC-CART-1A e revisione ReturnUrl

- `CATALOG-ASYNC-CART-1A` e CHIUSO / A. Branch `task/catalog-async-cart-1a`, base `588bde58a328df8ee7a430652b2397a77bdb726c`, commit iniziale `e92139f4e81e5619b632c14d8808ef76ffe55375`, revisione finale e merge point `b80f8d4683bbb9bb6ec8a7a486a79048bfae094f`. Merge fast-forward in `frontend-rebuild`, senza merge commit; `SMOKE UTENTE CATALOG-ASYNC-CART-1A REV1: A`.
- Contratto finale: POST asincrona same-origin limitata a `#ksCatalogPage` verso `catalog_cart_async.aspx`, con riuso della business logic reale di `aggiungi.aspx`; CSRF di sessione, parametri validati, request-id idempotente e JSON privo di dettagli sensibili. Non avvengono reload, redirect o cambio URL; quantita, stato card, header desktop/mobile e MiniCart vengono aggiornati preservando querystring, filtri, ordinamento, vista e scroll. Il doppio click genera una sola POST e una sola aggiunta; anonimo e autenticato sono verificati; acquisto multiplo e fallback senza `fetch` restano invariati.
- Revisione ReturnUrl inclusa in `b80f8d...`: `Continua lo shopping` nel MiniCart chiude soltanto l'offcanvas; `Vai al carrello` passa un `ReturnUrl` relativo e salva lo scroll. Il carrello completo risolve in ordine `ReturnUrl -> referrer -> sessione -> /articoli.aspx`; i postback non sovrascrivono la provenienza. `StorefrontReturnUrlPolicy` respinge URL esterni, protocol-relative, tecnici, circolari, traversal e schemi pericolosi. Lo scroll viene consumato solo dopo il ripristino sulla destinazione esatta. Provenienza verificata da catalogo con `q`, filtri/pagina/vista, PDP e pagina informativa.

### Chiusura STOREFRONT-CARD-BUY-CTA-STABILITY-1A

- Task CHIUSO / A, branch `task/storefront-card-buy-cta-stability-1a`, base `b80f8d4683bbb9bb6ec8a7a486a79048bfae094f`, commit e merge point `58f4ee43c363d629b3124fc0fb1a10beaeeef48a`. Merge fast-forward senza merge commit; `SMOKE UTENTE STOREFRONT-CARD-BUY-CTA-STABILITY-1A: A`.
- Causa: testo inline espandibile e flex wrapping cambiavano dimensione e posizione durante hover, focus e click. Contratto corrente: classe condivisa `.ks-compact-buy-cta`, controllo fisso `44x44px` in normal/hover/focus/active/busy/disabled, icona centrata, tooltip desktop fuori flusso, etichetta accessibile e spinner busy interno senza layout shift. Nessuna funzione essenziale dipende dall'hover.
- La purchase row dipende dalla larghezza reale della card tramite container query: card larga su una riga; card stretta su due righe con quantita e CTA affiancate; CTA mai sola su una terza riga. Copertura: quattro viste catalogo e tutti i renderer HOME. PDP, Recent, multiselect e CTA full-width sono preservati perche gia stabili. Il hotfix non modifica JavaScript.
- Riconciliazione storica: le chiusure `CATALOG-BUY-CTA-ACQUISTA-*` e `HOME-BUY-CTA-ACQUISTA-*` restano autentiche, ma il loro precedente contratto di testo espandibile su hover/focus e superato. Il contratto vigente per le CTA compatte e esclusivamente il quadrato fisso con tooltip esterno.

### Chiusura HOTFIX-CARD-LAYOUT-1A

- Task `HOTFIX-CARD-LAYOUT-1A`, branch runtime `task/storefront-card-layout-regression-1a`, base `ab86e01220ac219fdb82c41ab240d96994d83550`, commit runtime/stable `982cc83bcbcbb913dd1e320ece456957801f8121`.
- Merge in `frontend-rebuild` eseguito fast-forward only, senza merge commit. `SMOKE UTENTE HOTFIX-CARD-LAYOUT-1A: A`; `main` invariato a `976e99f17cabc8a5c6a8715463444edfeaadcd91`.
- Manifest runtime: 10 file modificati, 141 inserimenti, 67 rimozioni, nessun file aggiunto/eliminato: `Default.aspx`, `Default.aspx.vb`, `Page.master`, `Public/assets/keepstore/css/theme-overrides.css`, `Public/assets/keepstore/js/keepstore-recently-viewed.js`, `Public/ui/controls/ProductCard.ascx`, `Public/ui/controls/ProductCard.ascx.vb`, `articoli.aspx`, `articoli.aspx.vb`, `articolo.aspx`.
- Causa altezza catalogo: sidebar facet alta `4644.1px` nel normale flusso flex. Il fix la contiene su desktop nel viewport a circa `868px`, sticky e con scroll interno, mantenendo accessibili tutti i facet. `scrollHeight` pagina `5616 -> 4073px`; spazio anomalo Recent/footer `1631.4 -> 0px`.
- Causa disallineamento METEOR: slide/card Recently Viewed non estese, con altezze `565.8`, `513.8`, `491.8px`; dopo il fix tutte circa `589.1px` a viewport 1365.
- Contratto semantico condiviso limitato alle product card: `.ks-card-category` sopra `.ks-card-title`; categoria massimo e spazio riservato per 2 righe, titolo massimo e spazio riservato per 3 righe, geometria `2lh`/`3lh` basata sul line-height reale. Testo completo nel DOM, nessun `CompactText`/`Substring`; categoria assente = area vuota senza fallback inventato.
- Copertura: rendering server, snapshot server-generated e fallback JavaScript; HOME Grid/Deal/Row/Big/Recent, catalogo quattro viste/ProductCard/Recent, PDP frequent/similar/related/recent. Desktop e mobile verificati ai viewport `1920`, `1365`, `768`, `430`, `390`, `360px`.
- Questa chiusura riguarda esclusivamente la regressione geometria/altezza e non dichiara completi catalogo, `articoli.aspx`, PDP o `articolo.aspx`.

### Chiusura storefront mobile/cart/catalog block 2

- Consolidamento runtime fast-forward only da base `300b97a7a8873d3cd0cb750be2e949523a8ebaa0` a stable `b31f8177e09cffcd5e9193e1e26eb3bbec4f8e6b`, con ahead/behind pre-merge `0 / 7`. Catena lineare incorporata, in ordine: `3cdea2709712d133cfa82adb717ea9df69d0ed88` (`fix: add storefront cart feedback and awareness`), `c747b1ca2baa2a353251e1204b9b6775a44b5c01` (`fix: restore catalog mobile view layouts`), `55709258786405c9f75057f171d65742cf395ffc` (`fix: align catalog cards with cart awareness`), `bcb1cf5e048d5641119f7d829936a423d33ec2c7` (`fix: remove catalog cart state side accent`), `1e5c4070db5da39dfee26b7fa55362909dcae292` (`fix: stabilize storefront product card geometry`), `925244d17a87add4098266b273e8a45b2428c2c4` (`fix: stabilize catalog recent cards on mobile`), `b31f8177e09cffcd5e9193e1e26eb3bbec4f8e6b` (`fix: refine catalog structure and compact view`).
- Smoke Germano esplicitamente A: `STOREFRONT-CART-FEEDBACK-AND-AWARENESS-1A`, `CATALOG-MOBILE-FOUR-VIEWS-1A`, `CATALOG-CART-AWARENESS-CARD-ALIGNMENT-1A`, `CATALOG-MOBILE-RECENT-CARD-TAG-CONTAINMENT-1A` e `CATALOG-STRUCTURE-PAGER-COMPACT-GRID-1A`. I polish intermedi senza stringa smoke dedicata sono incorporati nella stable, ma non ricevono un esito A inventato.
- Add-to-cart normale: non forza piu sempre `carrello.aspx`; ritorna a un URL shopping locale validato e puo preservare querystring, filtri e `pg`. Il feedback success e one-shot dopo aggiunta reale e il refresh non ripete la toast. Lo stato persistente `Nel carrello attivo: N pz.` resta sulle superfici prodotto ed e derivato dallo snapshot server-side `CartStateSnapshotProvider`.
- Contratto carrello: `window.KeepStoreCartState` e soltanto snapshot client per decorazione UI; `localStorage` non e fonte di verita. Il leggero green state resta, la barra verticale verde laterale e rimossa e il badge non si sovrappone alla fotografia. La semantica delta PDP resta `2 -> 2 = 2`, `2 -> 3 = 3`, `2 -> 5 = 5`. Side cart/offcanvas non e completato e resta roadmap separata.
- Quattro layout catalogo funzionano anche mobile: `tabgrid-1`, `tabgrid-2`, `tablist-1`, `tablist-2`. La preferenza `sessionStorage["KeepStore:CatalogLayout"]` e solo presentazionale. Guardrail permanente: non usare `.tf-view-layout-switch`; usare `.ks-view-layout-switch` per evitare il reset distruttivo del `main.js` ONSUS. Disponibilita, cart-awareness, quantita, multiselect e `Acquista` restano presenti in tutte le viste.
- `tabgrid-2` e una vera compact grid: due colonne mobile dove appropriato e cinque colonne a desktop `1365`. Fotografia prodotto con fondo bianco, `border: 0`, `object-fit: contain`, `object-position: center` e breathing space minimo. I metadata secondari possono ridursi, ma prezzo, disponibilita, cart-awareness, quantita, multiselect e `Acquista` sono obbligatori.
- Contratto geometria: card equal-height dove necessario, layout flex, purchase row ancorata naturalmente al fondo e nessuna fixed height usata per compensare cart-awareness. Cart-awareness non altera l'allineamento; titoli e meta restano confinati. Il `product-tag` mobile usa containment/ellipsis; il Recently Viewed dinamico catalogo ha flex dedicato e CTA bottom-aligned. Nessun horizontal overflow nei viewport QA testati.
- Superfici immagini relation/bundle/catalog compact: fotografia su fondo bianco con `object-fit: contain` e `object-position: center`, senza gray panel esterno. Restano invariati il resolver `ThemeManager`, il path prodotto `/Public/assets/images/articoli/`, il placeholder `/Public/assets/images/img/placeholder.svg` e il path Settori `/Public/assets/images/settori/`.
- Titoli: card prodotto `articoli.aspx` e Recently Viewed catalogo limitati presentazionalmente a circa tre righe desktop/mobile. La vecchia troncatura server-side `CompactText(Descrizione1, 72)` e rimossa dal fallback catalogo: il testo completo resta nel DOM. Il titolo PDP `.product-info-name` resta completo senza clamp. Le card HOME sono state portate a massimo tre righe nel task availability/presentation accettato, con testo completo nel DOM.
- Pager catalogo: source of truth invariata `pg` querystring + `DataPager`; il DataPager resta motore ma non UI finale visibile. UI server-side: `«`, `Precedente`, `Pagina [N] di [TOT]`, `Prossimo`, `»`; `BuildCatalogPageUrl()` preserva lo stato catalogo legittimo. Visibile solo con `totalPages > 1`; First/Previous/Next/Last accessibili e correttamente disabled. QA reale: `1/45`, `2/45`, `23/45`, `45/45`.
- Ordine finale in `articoli.aspx`: `gridLayout` < `ksMultiFooter` < `ksPagerWrap` < `ksRecentlyViewedBlock`. I Visti di recente seguono quindi prodotti, acquisto multiplo e pager, coerentemente con la separazione di `shop-default.html`.
- Browser QA reale riusabile su IIS locale `https://localhost:8443`: viewport `360x800`, `390x844`, `430x932`, `768x1024`, `1365x900` e sanity `1920x1080`. Guardrail: per task UI significativi non dichiarare A desktop/mobile dalla sola analisi CSS; usare il runtime browser reale. Se non disponibile, riportare B visuale. Non aggiungere dipendenze browser/Playwright al repository.
- Anti-false-closure: catalogo e `articoli.aspx` non sono completi. Restano gap P1/P2, dove applicabili: Marche/load-more, tassonomie, active filters legacy/reset, Price, Deals, Condition/Ricondizionato, Reviews soltanto con dati reali, performance e ulteriori componenti commerciali/responsive. Pager, posizione recent, quattro viste mobile, compact grid e containment recent non vanno invece lasciati come problemi aperti.
- `STOREFRONT-AVAILABILITY-PRESENTATION-1A` e integrato con fast-forward in `frontend-rebuild`; codice applicativo accettato a `2b4e751d0041aa6ee4ec5be26a1cd138c3b3bc71` e merge point con documentazione iniziale a `b78cbedab9cd21806cd57d7efb0d91e8c0a8d0f3`.
- `CATALOG-ASYNC-CART-1A` e ora chiuso / A. Nota storica al checkpoint precedente: `LOGIN-RETURN-CONTEXT-1A` era il successivo audit/implementation del flusso login. E stato poi chiuso / A; la roadmap vigente e riportata nel checkpoint 2026-09-04. Side cart/offcanvas, catalog parity P1/P2 e gli altri blocchi restano separati; AI/Gemini/LLMS resta finale.

### STOREAVAIL-1A integrato in frontend-rebuild

- Branch runtime conservato: `task/storefront-availability-presentation-1a`; base originale `a5eb1c5823997b83430cd49874c794a9d1bfa18e`; HEAD applicativo accettato `2b4e751d0041aa6ee4ec5be26a1cd138c3b3bc71`; merge point applicativo/documentale `b78cbedab9cd21806cd57d7efb0d91e8c0a8d0f3`.
- `main` e `origin/main` restano preservati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. STOREAVAIL-1A risulta integrato in `frontend-rebuild` con fast-forward, senza merge commit.
- Manifest applicativo cumulativo, 13 file modificati e nessun file aggiunto/eliminato: `App_Code/AvailabilityDisplayHelper.vb`, `Default.aspx`, `Default.aspx.vb`, `Page.master`, `Public/assets/keepstore/css/theme-overrides.css`, `Public/assets/keepstore/js/keepstore-recently-viewed.js`, `Public/ui/controls/ProductCard.ascx`, `Public/ui/controls/ProductCard.ascx.vb`, `articoli.aspx`, `articoli.aspx.vb`, `articolo.aspx`, `articolo.aspx.vb`, `carrello.aspx`.
- Contratto disponibilita: la modalita arriva da `Session("DispoTipo")`, caricata da `Page.master.vb`, e viene interpretata dal solo `AvailabilityDisplayHelper`. `DispoMinima`/`ScortaMinima` sono preservate con fallback centralizzato. La modalita `1` mostra uno stato sintetico compatto senza numeri; la modalita `2` mostra sempre `Disponibili`, `Impegnati` e `In arrivo`. `In arrivo` deriva dal dato reale `InOrdine`; zero, `DBNull` e valori mancanti diventano visivamente `0` senza rimuovere la metrica. Stati e colori sintetici restano nella whitelist verde/ambra/rosso.
- Nessuna business logic disponibilita e stata affidata al JavaScript. HOME usa la query esistente estesa con `InOrdine`, senza SELECT per card e senza N+1. I Visti di recente ricevono uno snapshot strutturato generato server-side; il fallback legacy resta escaped.
- Copertura accettata: HOME; ProductCard/catalogo; PDP principale; Spesso acquistati insieme; Scopri articoli simili; Prodotti correlati; bundle; Visti di recente; carrello normale; carrello con soglia spedizione gratuita.
- HOME: titolo card massimo tre righe con testo completo nel DOM; corretto il clipping della disponibilita con titoli lunghi, incluso METEOR `15440`; le tre metriche restano presenti anche con `In arrivo = 0`. Menu desktop canonico nell'header e offcanvas canonico mobile preservati; pannello hero menu legacy escluso, nessun doppio menu o sovrapposizione hero, struttura ONSUS invariata. Cache-buster finali verificati nel codice: `theme-overrides.css?v=20260901-availability1a-pdpcardtext1` e `keepstore-recently-viewed.js?v=20260901-availability1a`.
- Standard card PDP vincolante per Spesso acquistati insieme, Scopri articoli simili, Prodotti correlati e Visti di recente: categoria massimo due righe, area fissa `44px`, `line-height: 22px`; titolo massimo tre righe, area fissa `54px`, `line-height: 18px`. Il testo completo resta nel DOM, senza troncamento server-side; `CompactText` e stato eliminato dai quattro renderer interessati e non sono usate `Substring` o abbreviazioni sui titoli. Tipografia ONSUS, font, dimensione, peso, colori e spacing non sono stati compressi; checkbox, segni `+`, bundle, prezzi, disponibilita, CTA, caroselli e responsive sono preservati.
- Smoke utente superati e distinti dalle verifiche automatiche: HOME/disponibilita; menu HOME; card PDP; disponibilita catalogo/carrello.
- Verifiche tecniche registrate nel task runtime: browser reale `https://localhost:8443/`, viewport desktop/mobile, HTTP senza errori tecnici, build/precompile ASP.NET Framework 4.8, sintassi JavaScript, assenza di overflow non intenzionale, `git diff --check`, secret scan e controllo manifest. Queste verifiche non vengono rieseguite nel task docs-only.

Limitazione obbligatoria: “Presentazione offerte e promozioni non validata perché i dati/funzioni erano disattivati durante lo smoke. Non considerare questa parte coperta dall’accettazione STOREAVAIL-1A.”

#### Task futuri separati

`CATALOG-ASYNC-CART-1A` era un task futuro nel checkpoint STOREAVAIL e non una regressione availability; quella diagnosi resta storica. Il task e ora CHIUSO / A a `b80f8d4683bbb9bb6ec8a7a486a79048bfae094f`: il flusso catalogo usa il contratto server asincrono sicuro documentato sopra, senza refresh/redirect, con MiniCart/header/card aggiornati, doppio click protetto, stato catalogo preservato e copertura anonimo/autenticato; acquisto multiplo e fallback legacy restano preservati.

`PDP-BRAND-LOGO-1A` non e implementato. I loghi copiati localmente dall'utente in `/Public/assets/images/marche/` restano non tracciati e fuori dal commit. Il task futuro richiede audit della relazione reale articolo-marca e dei campi/path esistenti, nessun filename dedotto, risoluzione server-side, contenitore stabile nella testata PDP, testo marca preservato per SEO/accessibilita, fallback senza immagine rotta, verifica desktop/mobile e coerenza ONSUS, con manifest asset esplicito prima di qualsiasi commit.

`STOREFRONT-OFFERS-PROMO-VERIFY-1A` e condizionato all'attivazione di offerte/promozioni da parte di Germano nell'ambiente test. Scope futuro, senza inventare colonne, tabelle o regole:

1. inventario dei campi reali offerte/promozioni nel DB e nella business logic esistente;
2. nessun campo inventato;
3. confronto con vecchio sito funzionante e template ONSUS;
4. prezzo normale;
5. prezzo precedente/barrato, solo se previsto dai dati reali;
6. prezzo promozionale;
7. percentuale o valore sconto, solo se previsto;
8. badge offerta/promozione;
9. date di validita, se previste;
10. descrizioni o etichette promozionali reali;
11. priorita quando piu condizioni commerciali coesistono;
12. HOME;
13. catalogo nelle quattro viste;
14. PDP;
15. correlati, simili, bundle e recenti;
16. carrello;
17. desktop e mobile;
18. allineamento con disponibilita, titolo, categoria, prezzo e CTA;
19. assenza di sovrapposizioni, clipping e salti di altezza;
20. smoke utente obbligatorio.

Problemi affrontati e risolti:

- `Continua lo Shopping` tornava alla HOME perche `articoli.aspx` salvava un URL assoluto in sessione e `SafeRedirectLocal` lo scartava: ora gli URL same-host sono normalizzati a `PathAndQuery`, gli esterni sono rifiutati e si torna al contesto shopping valido.
- La quantita gia in carrello sul catalogo rischiava somme errate: il delta e stato corretto, quindi `2 -> 2` resta `2`, `2 -> 3` diventa `3`, `2 -> 5` diventa `5`.
- Il visual mobile della quantita gia in carrello non era robusto quando dipendeva soprattutto da CSS `:has()`: ora `ProductCard` espone classi server-side stabili `ks-card-in-cart` e `ks-cart-qty-present`.
- La CTA catalogo `Acquista` era inizialmente troppo pill/bombata: e stata resa piu squadrata/professionale con radius circa `6px`, colore tema e icona coerente.
- La CTA HOME usava una linea/icona diversa: e stata allineata allo standard catalogo con `icon-cart-2`.
- Il blocco HOME `Occasione Imperdibile` aveva override/stile CTA diverso dagli altri blocchi: e stato allineato allo stesso standard.
- L'errore intermittente WebForms `BC30560 public_ui_controls_breadcrumb_ascx ambiguo nello spazio dei nomi ASP` e stato osservato una volta e non riprodotto: audit read-only senza duplicati reali `Breadcrumb`; causa piu probabile cache/compilazione dinamica ASP.NET temporanea, nessun fix applicato.

Chiusura progressiva catalog parity audit / `1A` / `1B`:

- `CATALOG-ONSUS-PARITY-AUDIT-1`: COMPLETATO / READ-ONLY, esito operativo E. La E non indica audit fallito: l'audit e completo e utile, non ha modificato file e ha individuato P0 reali che hanno interrotto la parity puramente visuale. P0 originari: contaminazione dello stato catalogo da Session (`st`, `ct`, `q`), paging non deterministico/pagina 2 instabile e immagini prodotto 404. Stato e paging sono chiusi da `1A`; immagini prodotto 404 sono chiuse da `1C`: tutti e tre i P0 risultano chiusi.
- `CATALOG-ONSUS-PARITY-1A`: CHIUSO / A sul branch `task/catalog-onsus-parity-1a`, commit `1acbba90a4e9973da695ec08a80840fd113a90fa` (`fix: stabilize catalog request state and paging`), runtime limitato a `articoli.aspx.vb`. QueryString e la source of truth dello stato catalogo; Session e solo mirror di compatibilita della request corrente. Rimossi i fallback stale di `st`, `ct`, `q` e `pg`: `q=hp` non eredita settore/categoria, una request senza `q` non eredita ricerche precedenti, `st/ct` e combinazioni esplicite `q+st` restano valide.
- Paging `1A`: `pg` assente/invalido porta a pagina 1; `pg=N` positivo porta a N; nessun recupero pagina da Session. Root cause: la modifica programmatica di `DataPager.PageSize` attivava `PagePropertiesChanging` con indice zero e perdeva `pg`. Il guard `catalogPagerSettingsApplying` protegge il lifecycle. QA A: pagina 2 diversa dalla 1, refresh/back/forward stabili, filtri e sort coerenti con `pg`.
- Page-size `1A`: whitelist `12`, `24`, `48`, `96`; valori Session legacy come `15` normalizzati a `12`; `Drop_Righe` e `DataPager.PageSize` coerenti; cambio page-size azzera a pagina 1. Codex A, smoke Germano `SMOKE UTENTE CATALOG-ONSUS-PARITY-1A: A`, HTTP 200, build/precompile A, nessuna modifica DB/schema/SP.
- `CATALOG-ONSUS-PARITY-1B-TOOLBAR-CONTROLS`: CHIUSO / A sul branch `task/catalog-onsus-parity-1b-toolbar-controls`, commit `9903687f89f99073d29cc0598746e17511f7e546` (`fix: align catalog toolbar with Onsus controls`), merge fast-forward `--ff-only`. Smoke Germano `SMOKE UTENTE CATALOG-ONSUS-PARITY-1B-TOOLBAR-CONTROLS: A`.
- Toolbar derivata da `Public/assets/keepstore/shop-default.html`: `.tf-shop-control`, `.tf-control-view`, `.tf-control-layout`, `.tf-control-sort`, `.tf-sort`; espone result range, quattro viste, Mostra, Ordina e Filtri responsive. Le icone `icon-menu-dots`, `icon-dot-line`, `icon-list-1`, `icon-list-2` mappano `tabgrid-1`, `tabgrid-2`, `tablist-1`, `tablist-2`; default `tabgrid-1`.
- Guardrail layout: KeepStore usa `.ks-view-layout-switch`, non `.tf-view-layout-switch`, per evitare il reset distruttivo delle classi card operato dal `main.js` ONSUS. Il JS modifica soltanto classi presentation consentite e preserva classi server/cart-state. `sessionStorage` usa la chiave `KeepStore:CatalogLayout` esclusivamente per la preferenza grafica, con whitelist delle quattro viste; non governa carrello, quantita, filtri business, prezzi o autenticazione.
- Tutte le viste preservano quantita, `+/-`, checkbox multiselect, una sola CTA `Acquista`, `icon-cart-2`, stato `Nel carrello`, `ks-card-in-cart`, quick actions, page-size, sort e pagination. `tabgrid-2` mantiene intenzionalmente i controlli ecommerce KeepStore che il comportamento ONSUS puro nasconderebbe.
- `Mostra` conserva il backend server-side `12/24/48/96`, senza introdurre il valore demo `50`. `Ordina` conserva i value `Consigliati`, `P_basso`, `P_alto`, `P_offerta`, `P_disponibilita`, `P_recenti`, `P_popolarita`, `P_codice`, `P_descrizione`; cambia solo la UI.
- Result range ONSUS-like senza query DB aggiuntive: `1-12 di 539 risultati per "hp"` e `13-24 di 539 risultati per "hp"`; query output-encoded. QA reale: desktop `1365x900` A (Filtri nascosto, quattro viste, Mostra/Ordina, nessun overflow), tablet `820x900` A (Filtri visibile, wrap coerente), mobile `390x844` A (controlli touch, nessun overflow/accavallamento).
- Manifest `1B`: modificati `articoli.aspx`, `articoli.aspx.vb`, `Public/assets/keepstore/css/catalog-ui.css`, `Public/assets/keepstore/js/catalog-product-flow.js`; aggiunti 0, eliminati 0; cache-buster `20260829-onsus-toolbar1b`.
- P0 immagini: CHIUSO / A da `CATALOG-ONSUS-PARITY-1C-IMAGE-PATH-404`, branch `task/catalog-onsus-parity-1c-image-path-404`, commit `817966edc417c907a79a20f22f9cf6f84d4a17f6` (`fix: centralize product image resolution`) e polish `9a6e5b1babc836adb33cd43f930a112cd6e77103` (`fix: polish missing product image placeholder`), merge fast-forward `--ff-only` e smoke Germano A. Le directory non tracciate `Public/assets/images/articoli/` e `Public/assets/images/settori/` non vanno committate automaticamente.
- `CATALOG-BRAND-LOADMORE-1A`: CHIUSO / A, PR #312 MERGED con fast-forward a `4149e537fe5af92686445eb847daac109909a744`; review e smoke server acquisiti prima del task tassonomico. Causa: ONSUS `shop.js` nasconde le `.fieldset-item` oltre 7, ma il facet Marche non rendeva `.btn-loadmore`. Ripristinato il controllo nativo `Mostra altro`, freccia in basso, touch target 44px e focus-visible; il tema espande tutte le marche e rimuove il pulsante senza navigazione/postback. Visibilita server da `DataList2.Items.Count > 7`, nessuna query aggiunta; wrapper DataList senza spazio residuo per elementi nascosti. Se una `.ks-filter-option.active` e oltre la settima posizione, solo il facet Marche parte espanso dopo l'inizializzazione del tema; nessun cambio a `mr`, multiselezione, ordine o conteggi SQL.
- Design Gate Marche: pattern originale `shop-default.html` dalla storia Git, benchmark [Baymard: truncation design](https://baymard.com/research-articles/truncation-design), riuso dell'architettura reale `shop.js`/DataList e QA mobile-first. Fixture locale reale: catalogo generale 222 marche; `st=40` 2 marche; selezione multipla delle prime 8 con marca attiva in posizione 8, auto-expand e rimozione/chip verificati. QA Chrome locale GET-only 360x800, 390x844, 768x1024, 1365x900; Enter/Space, focus, apertura Filtri, espansione senza chiusura pannello, conteggi/URL/prezzi invariati, nessun overflow o errore console/asset. Edge DOM 0/3/7/8/40 e reinizializzazione idempotente; precompile 4.8 PASS. La conferma server del solo task Marche e stata acquisita separatamente nella chiusura #312; nessuna chiusura complessiva catalogo implicita.
- Gap P1/P2 aperti: orientamento tassonomico header/search e relativa densita (sidebar S/C corretta tecnicamente dal task progressive disclosure sotto, con review/smoke server ancora pendenti), active filters server + JS legacy, reset mobile contesto `st/ct`, Deals, Condition/Ricondizionato, Reviews solo con fonte reale, performance/N+1 promo, positioning Recently Viewed, Compare empty-state e ulteriori componenti commerciali/parity ONSUS. Price facet (PR #310) e Marche/load-more (PR #312) sono chiusi; non sono finding implementativi aperti.

### Contratto tassonomico storefront — navigazione, facet e scope commerciali

Contratto permanente chiarito dal Product Owner nella REV1 documentale di `CATALOG-BRAND-LOADMORE-1A` / PR #312. E un approfondimento catalogo di `MULTITENANT-BY-DESIGN` e `ADAPTIVE-MULTI-MERCHANDISE-STOREFRONT`, non un contratto concorrente. Il CURRENT sottostante distingue il runtime dai TARGET residui. Nota di prevalenza 2026-10-06: `CATALOG-TAXONOMY-NAVIGATION-1A` e gia nella base stabile `17e56459bc0f7003b116c83373c7e09406ee0bcb`; il suo report iniziale pre-merge sotto resta storico. Anche `CATALOG-SIDEBAR-TAXONOMY-PROGRESSIVE-DISCLOSURE-1A` e CHIUSO / A / MERGED: PR #314 integrata fast-forward nella stable `e51d38f8c417d085db8efc8f1d323334cd886997`, review indipendente A e smoke server Product Owner A. Il nuovo task search sotto resta distinto dalla tassonomia condivisa gia chiusa.

#### Classificazione autorevole e ruoli

L'anagrafica articolo assegna direttamente, quando applicabili, `MarcheId`, `SettoriId`, `CategorieId`, `TipologieId`, `GruppiId`, `SottogruppiId`, oppure gli equivalenti reali esposti dalle view runtime. Gruppo e Sottogruppo possono non essere valorizzati: un prodotto valido non li richiede. Nessuna classificazione viene dedotta da template o AI. Nomi, descrizioni e associazioni provengono dai dati della specifica installazione/cliente, senza tassonomia elettronica o tenant hardcoded.

| Dimensione | Ruolo storefront | Semantica URL |
| --- | --- | --- |
| Settore | L1, reparto e primo scope strutturale | `st` |
| Categoria | L2, famiglia appartenente a un Settore | `ct` |
| Tipologia | L3, leaf appartenente a una Categoria; anche facet controllato nel listing | `tp` |
| Marca | Facet ortogonale / brand dimension, non figlia di Categoria o Tipologia | `mr` |
| Gruppo | Raffinamento/facet facoltativo | `gr` |
| Sottogruppo | Raffinamento/facet facoltativo | `sg` |
| Offerte | Commercial scope overlay, non livello tassonomico | `inpromo=1` |

La PRIMARY NAVIGATION TAXONOMY e esclusivamente `Settore -> Categoria -> Tipologia`. I parent autorevoli derivano dal catalogo reale: `categorie.SettoriId / Id_settore` e `tipologie.CategorieId / Id_categoria`, con compatibilita fra schemi preservata. Marca non appartiene alla catena. Nonostante i nomi storici, Gruppo/Sottogruppo non diventano automaticamente L4/L5; servirebbero un futuro contratto dati autorevole con vera relazione parent/child e una modifica esplicita di questo contratto da parte del Product Owner.

#### CURRENT / TARGET — navigazione, listing e breadcrumb

Tipologia ha un doppio ruolo intenzionale: leaf strutturale L3 nel mega-menu `Settore -> Categoria -> Tipologia`, e facet `Tipologie` nella Product Listing Page per passare fra tipologie sorelle o selezionarne piu di una. Una sola `tp` coerente con `ct/st` puo rappresentare il leaf corrente; piu valori `tp` sono uno stato faceted, non un unico nodo gerarchico. Preservare gli URL storici e la multiselezione supportati.

In `articoli.aspx`, Settore e Categoria definiscono lo scope principale; una Tipologia singola coerente puo definirne il leaf ed e selezionata quando raggiunta dal menu, restando modificabile nel facet. Marca, Gruppo e Sottogruppo restringono il result-set indipendentemente. Opzioni disponibili e conteggi derivano dai prodotti reali del contesto; Gruppo/Sottogruppo vuoti o non pertinenti non devono lasciare UI vuota. Titolo/H1 TARGET: nodo tassonomico valido piu specifico, `Tipologia -> Categoria -> Settore -> Catalogo`; mai Marca/Gruppo/Sottogruppo come heading strutturale.

Il breadcrumb rappresenta esclusivamente la posizione gerarchica. Catalogo CURRENT: `Home -> Settore -> Categoria -> Tipologia`; PDP CURRENT: `Home -> Settore -> Categoria -> Tipologia -> Prodotto`, tramite lo stesso resolver e controllo `Breadcrumb`. I livelli realmente mancanti/non validi vengono omessi in sicurezza, senza inventare parent; senza struttura valida si usa `Home -> Catalogo` e in PDP si aggiunge il Prodotto. Marca, Gruppo, Sottogruppo, prezzo, disponibilita, promo, condition e altri facet non entrano nella catena. Il livello corrente non e un link e usa `aria-current="page"`; nomi e URL locali sono encoded. Il controllo rimane nascosto sulle pagine che non lo bindano esplicitamente.

Il RETURN / LIST CONTEXT resta separato dal breadcrumb: conserva filtri, ordinamento, paging e query di provenienza. Il breadcrumb non serve a ricordare lo stato della precedente lista. Nella PDP la Marca rimane dato prodotto separato e link facet contestuale tramite `mr`, preservando il taxonomy scope valido. Gruppo/Sottogruppo possono comparire come metadata, caratteristiche o raffinamenti utili, mai come livelli del breadcrumb. I percorsi legacy che mescolavano brand e raffinamenti sono storico, non il target del nuovo storefront.

#### CURRENT / TARGET — offerte, normalizzazione e confine SEO

`articoli.aspx?inpromo=1` sovrappone lo scope commerciale alla stessa tassonomia e agli stessi facet del catalogo normale: `Offerte + Settore -> Categoria -> Tipologia + facet`. Restringe il product set alle offerte/prodotti realmente applicabili; Marca, Gruppo, Sottogruppo, prezzo e disponibilita filtrano quel sottoinsieme. Non creare una seconda tassonomia offerte. `promozioni.aspx` resta route legacy ritirata secondo il contratto gia documentato.

`st/ct` identificano scope tassonomici; `tp` identifica una Tipologia leaf oppure lo stato facet Tipologie; `mr/gr/sg` sono facet; `inpromo` e scope commerciale. `pmin/pmax`, disponibilita, condition e gli altri attributi restano facet/commercial filters, non livelli di navigazione.

Validazione CURRENT: il resolver ricava dal tree autorevole i parent di una `tp` singola valida o di una `ct` valida; `articoli.aspx` normalizza i parent mancanti/incoerenti con un solo redirect, prima della SEO, preservando gli altri parametri. La ricerca libera `q` e il `pid` legacy senza `inpromo=1` mantengono la policy di navigazione precedente. Un child invalido resta filtro invalido nella query, senza broadening; solo parent validi indipendenti possono comparire nel breadcrumb. Con piu Tipologie non esiste un leaf unico: si puo mostrare la Categoria comune, oppure il Settore comune, solo dopo avere validato tutti i valori. Un ID invalido impedisce l'inferenza dal sottoinsieme valido; selezioni cross-settore non inventano un parent comune. I parent inferiti multi sono esclusivamente visuali: non vengono aggiunti alla query, a Session o ai filtri SQL. Session resta mirror della request effettiva.

Confine SEO: route tassonomiche singole/coerenti possono rappresentare scope strutturali; stati faceted/combinati restano soggetti alla policy noindex/canonical gia documentata. `IsSeoIndexAllowed()` e `BuildSeoCanonicalUrl()` sono preservate, non riscritte. Marca/Gruppo/Sottogruppo non diventano tassonomia SEO per la sola presenza in querystring. UI e `BreadcrumbList` JSON-LD derivano dalla stessa lista di nomi/URL strutturali, assoluti HTTPS same-tenant; nessun facet nei ListItem. `SeoBuilder.BuildSimplePageJsonLd()` e `ProductStructuredDataInput` accettano breadcrumb opzionali: vecchi caller/input preservati, trail custom invalido/cross-tenant respinto con fallback sicuro. In PDP `Product.category` preferisce il nodo valido piu specifico, con fallback ai dati precedenti solo senza struttura valida; Product/Offer, prezzo, seller e canonical restano invariati.

#### CURRENT verificato e gap verso il TARGET

- `CatalogMenuProvider` costruisce gia `Settore -> Categoria -> Tipologia` con parent reali e URL `st`, `st+ct`, `st+ct+tp`; HOME/header consumano questo tree per il menu. Questo non certifica la completezza visuale di ogni menu o pagina.
- `CatalogCategoryLabel()` usa gia `Tipologia -> Categoria -> Settore`, senza Marca/Gruppo/Sottogruppo. Non equivale ancora al riallineamento di tutti gli H1 sul context condiviso TARGET.
- PDP `BuildCategoryCatalogUrl()` usa `CatalogTaxonomyContext.MostSpecificUrl`; `BuildBrandCatalogUrl()` aggiunge soltanto `mr` a quel contesto valido. Gruppo/Sottogruppo restano filtri indipendenti, non livelli strutturali.
- `CATALOG-TAXONOMY-NAVIGATION-1A`, registrazione originaria pre-merge: implementato / A tecnico locale, B complessivo in attesa di review e smoke server; branch `task/catalog-taxonomy-navigation-1a`, base stabile `4149e537fe5af92686445eb847daac109909a744`, un solo commit e PR DRAFT verso `frontend-rebuild`, nessun merge/deploy autorizzato in quella fase. Il checkpoint Git corrente prevale come precisato sopra. Resolver condiviso `App_Code/CatalogTaxonomyResolver.vb`, context per pagina/request, `LookupSettoreIdByCategoria()` rimosso e zero consumer residui; nessuna query taxonomy aggiuntiva, nessun secondo tree/cache. La risoluzione riusa `CatalogMenuProvider.LoadCatalogMenuCached()` e la compatibilita schema gia posseduta dal provider. Non viene dichiarata una misurazione SQL live prima/dopo.
- Breadcrumb catalogo e PDP taxonomy-aware e parita structured data implementati. Root cause precisata: prima del task la PDP aveva un trail fisso `Home -> Catalogo -> Prodotto`; il catalogo emetteva `CollectionPage` senza `BreadcrumbList`, non un trail tassonomico. Il catalogo ora emette un solo `BreadcrumbList` coerente con la UI. Return/list context resta separato; heading/H1 nascosto, menu e search non sono riallineati in questa slice.
- Promo moderna GET-only certificata sullo stesso resolver: fixture dinamica `pid=15830`, prodotto `19743` / `DTSE9G2/64GB`, `st=2&ct=102&tp=134`; un redirect conserva `inpromo=1/pid`, product-set, prezzi, conteggi facet e robots/canonical. Finding preesistente separato: la route legacy `pid=15830&tp=134` senza `inpromo=1` restituisce HTTP 500 `varticolibase.OfferteId`; il ramo SQL e identico nella base ed e lasciato invariato, senza confonderlo con la promo moderna o correggerlo in questo task.
- `CATALOG-NAVIGATION-TRUNCATION-AUDIT-1A`: AUDIT CHIUSO / A READ-ONLY. Fixture corrente: 18 Settori / 132 Categorie / 528 Tipologie; Informatica ha 35 Categorie. Root cause F01: la vecchia sidebar eliminava i Settori oltre 12 e le Categorie oltre 10, salvo il nodo attivo, senza controllo di espansione. Header desktop/mobile espongono l'intero tree ma restano densi; HOME corrente non monta il legacy `HomeDepartmentsMenu`. F02 Search selector HIGH separato: label selezionata incoerente, custom div non accessibile da tastiera, lista alta e UX mobile insufficiente. Letture menu duplicate su header/HOME MEDIUM e handler mobile legacy LOW separati; l'audit non ha modificato questi componenti.
- `CATALOG-SIDEBAR-TAXONOMY-PROGRESSIVE-DISCLOSURE-1A`: CHIUSO / A / MERGED con PR #314, un commit fast-forward dalla base `17e56459bc0f7003b116c83373c7e09406ee0bcb` alla stable `e51d38f8c417d085db8efc8f1d323334cd886997`; review ChatGPT A e smoke server Product Owner A. Manifest esclusivo: `articoli.aspx.vb`, `Public/assets/keepstore/css/catalog-ui.css`, questo Masterplan. Zero omissione di Settori/Categorie renderizzabili: `CatalogNavInitialSectors=12` e `CatalogNavInitialCategories=10` sono initial-visible, non data limits. Tutti i nodi validi sono nel DOM una sola volta; gli extra conservano l'ordine autorevole dentro `li > details > summary + ul`. Label con conteggio e singolare/plurale, `Mostra meno` a gruppo aperto; active extra auto-open, senza spostarlo nelle prime N. Nodi Nothing/testo vuoto esclusi dal conteggio tramite `CatalogNavText()` esistente. Zero JS/postback/storage, niente max-height o scrollbar taxonomy aggiuntiva. URL `st/ct`, `inpromo/pid`, resolver, breadcrumb, SEO, listing/facet/prezzi e provider cached invariati; nessuna nuova query, verificata dal diff e dal caller sintetico, senza dichiarare un profiling SQL live.
- QA progressive disclosure: Chrome locale isolato, solo GET, `https://www.taikun.it:8443`, ordine mobile-first 360x800, 390x844, 768x1024, 1365x900 PASS. Apertura/chiusura, active Settore 34 posizione 13 e Categoria 11 posizione 11, ultimo extra raggiungibile, Filtri ancora aperto, touch 44px, Tab/Enter/Space e focus-visible PASS; zero overflow orizzontale/doppio scroll taxonomy/errori JavaScript/first-party 404 aggiuntivi. `st=1` ha 7 Categorie, tutte visibili senza disclosure categorie. Baseline prima/dopo su sei GET, inclusa promo moderna `inpromo=1&pid=15830&st=2&ct=102&tp=134`: stessi product-set/prezzi/facet/breadcrumb/URL; vecchi link identici. Link sidebar base 12 -> 18, `st=2` 22 -> 53, `st=34` 19 -> 24, `st=2&ct=11` 23 -> 53. Metodi VB reali estratti e compilati in memoria: 15 fixture sintetiche / 470 controlli, con due tree multi-tenant/multi-merceologia PASS, inclusi 0/pochi/molti nodi, <=12 Settori, <=10 Categorie, label singolari e nodi non renderizzabili; nessuna fixture DB creata. Marche Mostra altro preservato, prezzo/altri facet/paging/sort verificati con GET e confronto sorgenti; add-to-cart/MiniCart invariati e controllati staticamente, senza mutazioni. Precompile ASP.NET Framework 4.8, HTML structural check, diff-check e secret scan PASS. Nessuna DML/DDL, ordine, pagamento, e-mail o deploy; questa QA locale non sostituisce lo smoke umano server.
- QA tecnico: resolver puro 89 controlli su due tree sintetici multi-merceologia; Google Product 19 fixture / 80 controlli, copertura precedente preservata; SEO 41 policy + 44 scenari same-DB tenant. Matrice locale 22 casi catalog/PDP, promo moderna e invalid/multi no-broadening PASS; fixture PDP reale `10767` / `TL-SF1005D`, `st=2&ct=25&tp=223`, `gr=246/sg=70` esclusi dal trail. Chrome locale GET-only `https://www.taikun.it:8443`, catalogo/PDP 360x800, 390x844, 768x1024, 1365x900 PASS: parent tappabili, nessun overflow/sovrapposizione, filtri mobile, Marche 7 -> 222, price facet, JSON-LD parseable e same-tenant. Zero errori console/rete sulle superfici moderne testate, zero nuovi first-party 404; il 500 legacy sopra e distinto. Precompile ASP.NET Framework 4.8 PASS; nessuna DML/DDL o mutazione ecommerce.
- `CATALOG-BRAND-LOADMORE-1A` / PR #312 e CHIUSO / A e MERGED: Marca resta facet ortogonale. `7 valori + Mostra altro`, conteggi, multiselezione e auto-expand della marca attiva sono preservati; i quattro file runtime di quel task sono read-only in questa slice.

#### CURRENT condiviso e roadmap residua

`CatalogTaxonomyResolver` e implementato sopra il tree/cache autorevole di `CatalogMenuProvider`. Input: `st/ct/tp` oppure classificazione articolo. Output `CatalogTaxonomyContext`: `SectorId/Name/Url`, `CategoryId/Name/Url`, `TipologyId/Name/Url`, validita/coerenza e stato single/multi. L'overload puro accetta il tree esplicito per harness senza DB; l'entry point production usa soltanto il provider cached esistente. Catalogo, PDP, breadcrumb e JSON-LD condividono lo stesso context nella request; nessun N+1, secondo sistema tassonomico o hardcode tenant/merceologia.

TARGET residui: eventuale ulteriore consumo del context da `SiteHeader` e futura search/category guidance; riallineamento del titolo/H1 sul nodo piu specifico e orientamento/densita menu/search. Non rimontare il legacy `HomeDepartmentsMenu` nella HOME corrente. La sidebar S/C e ora completa nel DOM nel task progressive disclosure, non e una chiusura globale catalogo/header/search. Non attivato `ksPageTitle ... d-none`, non riscritte search o SEO; la full parity catalogo/PDP e la completezza SEO non sono dichiarate. Il contratto resta universale per tenant, database e merceologie differenti.

`SEARCH-CATEGORY-SELECTOR-ACCESSIBILITY-1A`: CURRENT implementato / A tecnico locale REV1; B complessivo in attesa di nuova review ChatGPT e smoke server Product Owner. Branch `task/search-category-selector-accessibility-1a`, base `e51d38f8c417d085db8efc8f1d323334cd886997`, due commit lineari e PR #315 OPEN/DRAFT verso `frontend-rebuild`; nessun merge/deploy. Manifest esclusivo: `Public/ui/controls/SiteHeader.ascx`, relativo `.ascx.vb`, `Page.master.vb`, `Public/assets/keepstore/css/theme-overrides.css`, `Page.master` e questo Masterplan. Manifest del solo commit REV1: `Page.master.vb` e questo Masterplan.

Desktop e mobile usano i DropDownList reali con label associata `Ambito di ricerca`. Il server ID desktop `product_cat` resta, ma `ClientIDMode=AutoID` evita il target `select#product_cat` di `main.js`: nessun div/popup custom o mirror della selezione. Nomi Categoria = `Settore / Categoria` dai dati reali; tutti i valori URL e l'ordine restano invariati. Il mobile espone lo scope anche a 360/390, su prima riga full-width, input e bottone 44x44 sulla seconda. `Cerca()` rimane wrapper compatibile; submit mobile e TextChanged mobile privilegiano i rispettivi controlli. REV1: il valore del controllo primario esistente e sempre autorevole, anche vuoto; `Tutti i settori` usa intenzionalmente URL vuoto e una query vuota non recupera testo stale. Il controllo opposto e fallback soltanto se il primario non esiste. Suggest e dimensionamento riusano `.dropdown_product_cat` e `resizeSearchCategory()` esistenti. Zero nuovo motore search, query, business logic o cache; `main.js`, `ks-page-flags.js`, `styles.css`, provider e resolver invariati. Solo cachebuster `theme-overrides.css`: `20261006-search-category-native1a`.

Design Gate del task applicato alle cause confermate nel tema versionato e nel runtime; [W3C APG](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-select-only/), [WAI labels](https://www.w3.org/WAI/tutorials/forms/labels/) e [Baymard search scope](https://baymard.com/research-articles/autodirect-searches-matching-category-scopes) consultati il 2026-10-06.

| Aspetto | ONSUS originale | Benchmark attuale | KeepStore corrente | Decisione KeepStore |
| --- | --- | --- | --- | --- |
| Scope desktop | Select nascosto, div click-driven e prima option come label | Semantica HTML e label associata | 151 option, selezione server gia corretta | Select nativo visibile, label reale e ID client gerarchico |
| Scope mobile | Search shell compatta | Scope di ricerca raggiungibile e leggibile | Wrapper nascosto sotto 576px | Due righe, select full-width e bottone 44x44 |
| Search/suggest | Shell del template | Categoria e ricerca cooperano | JS trova gia il select per classe, server privilegia desktop | JS preservato e fallback server source-aware |

QA su runtime locale tenant-aware `https://www.taikun.it:8443`: 151 option = 1 base + 18 Settori + 132 Categorie, zero duplicati inattesi; selected base/st=2/st=2&ct=25 coerente su entrambi i select. Chromium locale isolato: 360x800, 390x844, 768x1024, 1365x900, 1440x900 e 1920x1080 PASS, senza overflow/overlap; focus-visible, Tab, frecce, Home/End, type-ahead, accessibilita nativa nominata e touch in emulazione PASS. Suggest reale st/ct/q e posizionamento desktop/mobile PASS, incluso cambio verso altra Categoria; ricerca JS base/Settore/Categoria/codice e menu Catalogo PASS. Fallback server provato con JavaScript disabilitato e POST WebForms equivalente: ViewState/event validation originali e `__EVENTTARGET` ricavato dal markup del bottone; HTTP 302 desktop `st=2&ct=25&q=hp`, mobile `st=40&ct=183&q=hp` con desktop stale `st=2&ct=25`. Non e una certificazione del picker OS su telefono fisico. Metodi VB reali estratti/compilati: 101 controlli PASS, tree sintetici 0/pochi/molti Settori e nomi Categoria duplicati su Settori diversi, nessun DB fixture. Precompile ASP.NET 4.8, manifest, diff-check e secret scan PASS; zero nuovi errori console/first-party 404 osservati sulle superfici verificate. Nessuna DML/DDL o mutazione ecommerce; log runtime automatici preservati. Queste prove non sostituiscono review indipendente e smoke server.

QA REV1 2026-10-06: review indipendente B per un solo finding confermato e riprodotto prima del fix su desktop e mobile: `Tutti i settori` con valore vuoto recuperava erroneamente la categoria stale del controllo opposto. Corrette soltanto quattro condizioni di `Cerca(preferMobile)`; wrapper, eventi mobile, trim, URL encoding e redirect invariati. Test A/B con postback WebForms equivalente reale, JavaScript disabilitato e ViewState/eventvalidation originali: reset base da `st=2&ct=25`, scope opposto stale, HTTP 302 `articoli.aspx?q=hp`, senza `st/ct`, su entrambi i percorsi. Test C/D: desktop Categoria A con mobile B -> `st=2&ct=25&q=hp`; mobile B con desktop A -> `st=40&ct=183&q=hp`, HTTP 302. Test E sui metodi VB reali estratti/compilati: testo primario vuoto/whitespace, scope base vuoto, controllo primario assente e fallback autorizzato, entrambe le direzioni PASS; 18 nuovi controlli, 119 totali PASS, nessuna fixture DB. Test F browser locale 390/1365: JS base/Settore/Categoria+q, suggest `st/ct/q`, codice ZAP80-A4 ed EAN reale della stessa fixture PASS su desktop/mobile; 151 option e label/native select invariati, zero nuovi errori console/first-party 404. Precompile ASP.NET 4.8 safe, diff-check, secret scan e manifest REV1 PASS. Gli altri quattro runtime approvati sono identici all'HEAD precedente `e1135b736948211691fd7f52327863b9b69a7a98`; nessun redesign, DB write o deploy. Smoke server Product Owner e nuova review ancora pendenti.

Nota di prevalenza 2026-10-07: `SEARCH-CATEGORY-SELECTOR-ACCESSIBILITY-1A` e CHIUSO / A / INTEGRATED, PR #315 MERGED con fast-forward e stable `8f75551c5c9dcacce67f394be897558a31a82e22`, dopo review ChatGPT e smoke server Product Owner A. Le indicazioni OPEN/DRAFT e gate pendenti sopra descrivono il checkpoint pre-merge e sono superate; non riaprire quel task.

#### HEADER-MOBILE-IMAGE-CONTAINMENT-1A — implementazione CSS circoscritta

2026-10-07: A tecnico locale / B complessivo, in attesa di review indipendente e smoke server Product Owner. Branch `task/header-mobile-image-containment-1a`, base `8f75551c5c9dcacce67f394be897558a31a82e22`; un solo file runtime `Public/assets/keepstore/css/theme-overrides.css`, piu questa sezione documentale. Nessun merge/deploy.

Causa confermata sul DOM WebForms locale: `.ks-mobile-nav-media` era `display:inline`, dimensioni `auto`, `overflow:visible`; l'immagine usava `object-fit:fill` e la propria dimensione intrinseca. Immagini reali 65x49 e 65x52 alzavano le righe a 49/52px; una fixture solo DOM 100x2000 portava la riga a 2000px. Il desktop aveva gia un contratto media 30x30 con containment. Nessun problema del provider, della tassonomia o degli asset corretto da questo task.

Design Gate: esaminati markup e `_header.scss` nel package ONSUS originale locale (offcanvas/collapse, righe flex e freccia separata), confrontati con il runtime KeepStore e con [W3C CSS Images](https://www.w3.org/TR/css-images-3/#the-object-fit) e [WAI target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced/) consultati il 2026-10-07. Decisione: mantenere shell, gerarchia e target KeepStore da 44px; contenere soltanto il media aggiunto dai dati reali, senza importare asset/markup demo o ridisegnare il menu.

Soluzione scoped a `#mobileMenu`: entry flex centrata con gap 10px e `min-width:0`; media 30x30, `flex:0 0 30px`, centratura e `overflow:hidden`; immagine block, max-width/max-height 100%, `object-fit:contain`, `object-position:center`; label con wrapping sicuro. Nessun upscale delle immagini piccole, crop o deformazione. Assenza e failure mantengono lo spazio riservato; il renderer `.is-empty`/onerror esistente resta invariato, senza nuovi placeholder. Il box media non altera i button/collapse o gli URL `st`, `st+ct`, `st+ct+tp`.

QA Chromium locale isolato sul runtime tenant-aware, solo GET e interazioni di menu: 360x800, 390x844, 768x1024 PASS, con 18 Settori / 15 immagini reali e tutte le righe a 44px. Fixture esclusivamente browser/DOM landscape 2000x100, portrait 100x2000, square 1000x1000, piccola 8x6, assente e broken PASS su tutti e tre i viewport; asset failure simulato con 404 intercettato dal browser, non creato sul server. Centro, aspect ratio, box, altezza riga e posizione freccia verificati; nessun overflow, espansione/chiusura Settore e Categoria/Tipologia PASS, 678 href tassonomici identici tra i viewport. Desktop 1365x900 PASS: media ancora contained e geometria header/search/media identica alla base con confronto A/B del CSS. Screenshot locali controllati. Zero nuove eccezioni JavaScript o first-party failure osservate, esclusa la failure sintetica intenzionale.

Precompile ASP.NET Framework 4.8 safe, diff-check, secret scan e manifest PASS. Nessuna modifica ASCX/VB, JS, `styles.css`, `Page.master`, provider/cache, query, DB o business logic. Cache-buster esistente preservato per rispettare il manifest: QA con contesto browser nuovo; lo smoke server deve verificare il CSS aggiornato con cache browser ricaricata. Questi esiti non certificano un telefono fisico, il deploy multi-tenant o l'intero header/catalogo.

Restano aperti e separati `CATALOG-MENU-CACHE-CONSUMERS` MEDIUM (letture duplicate), `HEADER-CURRENT-SCOPE` MEDIUM, header density/DOM scalability e handler mobile legacy LOW (`rptNavTipologieMobile_ItemDataBound`); AI-SEARCH resta roadmap. Nessun task successivo avviato e nessuna chiusura globale search/header/catalogo/PDP/SEO o autorizzazione DB/deploy implicita.

### Chiusura immagini prodotto catalogo e prossimo finding PDP

- I tre P0 originari di `CATALOG-ONSUS-PARITY-AUDIT-1` sono chiusi: contaminazione stato request/Session e paging pagina 2 da `1A`; product-image 404 da `1C`. Questa chiusura non dichiara completa `articoli.aspx` e non equivale alla full parity ONSUS: i gap P1/P2 e il responsive complessivo finale restano aperti.
- Contratto permanente product-image: directory fisica/pubblica canonica `/Public/assets/images/articoli/`; unico resolver runtime in `ThemeManager` tramite `ProductImageUrl()`, `ProductThumbnailImageUrl()` e `PlaceholderProductImageUrl()`. Non reintrodurre resolver product-image verso `Public/foto`, `Public/Foto`, `Public/Images` o `/Public/images/nofoto.gif`.
- `ProductImageUrl()` preserva URL HTTP/HTTPS/data; per valori locali normalizza in sicurezza al solo filename finale, respinge path traversal, verifica il file per-file nella directory canonica e URL-escapa il filename. File presente -> immagine reale; file assente -> placeholder, senza produrre deliberatamente URL locali rotti.
- `ProductThumbnailImageUrl()` usa `_filename` solo se il thumbnail esiste; in caso contrario usa la full image reale e, se manca anche questa, il placeholder. Catalogo, HOME, PDP, suggest, home runtime feed, carrello, MiniCart, wishlist, documenti, vetrina, search legacy, `articolix` ed export/feed convergono sul resolver centrale. Il vecchio ripristino client `normalizeCartImage()` + `img.onerror` e stato rimosso: il server rende gia thumbnail, full o placeholder.
- Placeholder canonico `/Public/assets/images/img/placeholder.svg`: SVG vettoriale responsive `800x800`, neutro/professionale, icona immagine, accento KeepStore `#D80027`, testo visibile `Immagine non disponibile`, Arial, accessibile, senza script o riferimenti remoti. Se il file fisico non e disponibile nel deployment, `ThemeManager` restituisce come last-resort un piccolo `data:image/svg+xml,...`; il data URI non sostituisce lo standard primario.
- Contratto Settori separato, confermato da Germano: `/Public/assets/images/settori/`. Il resolver product-image non e un resolver generico Settori e non deve confondere `articoli` con `settori`.
- QA `1C`: product-image 404 su `q=hp` pari a 0; HOME, catalogo, catalogo `pg=2`, PDP, carrello e placeholder HTTP 200; build/precompile .NET Framework 4.8, `git diff --check` e secret scan A; smoke Germano A con placeholder visibile e nessuna broken image nelle superfici testate. Manifest: commit `817966ed` con 23 file runtime modificati, 0 aggiunti/eliminati; polish `9a6e5b1b` su `ThemeManager.vb` e `placeholder.svg`; cumulativo 24 file unici modificati, 0 aggiunti, 0 eliminati.
- Finding separato: `articolix.aspx` puo ancora restituire HTTP 500 per binding legacy `TCid`; non e causato dal resolver immagini, non e corretto da `1C` e resta backlog autonomo.
- Riconciliazione stato: il precedente finding `PDP-TITLE-SHIPPING-INFO-1A` resta storico utile e non descrive piu il prossimo runtime. Il titolo PDP `.product-info-name` e preservato completo; la pagina `articolo.aspx` non e comunque dichiarata completa.
- Stato successivo a quel finding: `STOREFRONT-AVAILABILITY-PRESENTATION-1A` e implementato, accettato e integrato in `frontend-rebuild`; source of truth `AvailabilityDisplayHelper`, `Session("DispoTipo")`, copertura HOME/catalogo/PDP/carrello, nessun N+1 e titoli HOME a massimo tre righe. `CATALOG-ASYNC-CART-1A`, `LOGIN-RETURN-CONTEXT-1A` e `LOGIN-ACCESS-AUDIT-1A` sono poi stati chiusi; la priorita vigente e nel checkpoint 2026-09-04.
- Side cart/offcanvas resta separato; AI/Gemini/LLMS resta priorita finale.

Scaletta prioritaria ufficiale:

1. Priorita 1 - PDP / scheda prodotto `articolo.aspx`.
   - `PDP-BUY-CTA-ACQUISTA-AUDIT-1`: CHIUSO.
   - `PDP-BUY-CTA-ACQUISTA-1A/1B`: CHIUSO; smoke Germano A desktop/mobile.
   - `GLOBAL-TYPOGRAPHY-ONSUS-AUDIT-1`: CHIUSO / A, audit read-only globale.
   - `GLOBAL-TYPOGRAPHY-ONSUS-1A`: CHIUSO / A; foundation deterministica `Arial, sans-serif`, smoke Germano A desktop/mobile.
   - `STOREFRONT-CART-STATE-PERSISTENCE-REGRESSION-AUDIT-1`: CHIUSO / B diagnostico e procedibile; nessuna root cause regressiva specifica catalogo dimostrata.
   - `STOREFRONT-CART-STATE-PERSISTENCE-1A`: CHIUSO / A; stato carrello server-side unificato su HOME/catalogo/PDP, smoke Germano A.
   - `ARTICOLO-CART-QTY-IN-PDP-AUDIT-1` e `ARTICOLO-CART-QTY-IN-PDP-1A`: ASSORBITI / SODDISFATTI dai due task cart-state precedenti; non sono piu task futuri indipendenti.
   - `GLOBAL-TYPOGRAPHY-ONSUS-1B`: CHIUSO / A; normalizzazione scoped delle famiglie esplicite residue e polish clipping titoli HOME inclusi.
   - `GLOBAL-TYPOGRAPHY-ONSUS-1C`: NON NECESSARIO / NON CREATO dopo esito A di `1B`; resta solo riferimento storico.
   - `PDP-TITLE-SHIPPING-INFO-1A`: perimetro storico incorporato nella stable; non e il task runtime corrente e non dichiara completa `articolo.aspx`.
   - `PDP-COMMERCIAL-INFO-SHIPPING-1A`: CHIUSO / A a `91cbc10b3b343217e18c5a9a6707b72997467b00`; chiude solo informazioni commerciali e tariffe reali del singolo articolo, con REV1 IVA allineata al carrello. `articolo.aspx` resta non dichiarata completa.
   - `STOREFRONT-AVAILABILITY-PRESENTATION-1A`: INTEGRATO con fast-forward, merge point `b78cbedab9cd21806cd57d7efb0d91e8c0a8d0f3`. Storicamente fu seguito da `CATALOG-ASYNC-CART-1A` e `LOGIN-RETURN-CONTEXT-1A`, entrambi chiusi; l'ordine corrente parte dall'hotfix promo nel checkpoint 2026-09-04.
2. Priorita 2 - Catalogo `articoli.aspx` full ONSUS parity.
   - `CATALOG-ONSUS-PARITY-AUDIT-1`: COMPLETATO / READ-ONLY, esito operativo E per P0 reali individuati.
   - `CATALOG-ONSUS-PARITY-1A`: CHIUSO / A; stato request e paging deterministici.
   - `CATALOG-ONSUS-PARITY-1B-TOOLBAR-CONTROLS`: CHIUSO / A; toolbar ONSUS-like e quattro viste.
   - `CATALOG-ONSUS-PARITY-1C-IMAGE-PATH-404`: CHIUSO / A; resolver centrale, path canonico e placeholder fail-safe, smoke Germano A.
   - Proseguire poi con i gap P1 secondo audit e priorita effettiva, senza dichiarare completa `articoli.aspx`.
3. Priorita 3 - Side cart/offcanvas.
   - `SIDE-CART-OFFCANVAS-ONSUS-AUDIT-1`: audit read-only del flusso post add-to-cart.
   - `SIDE-CART-OFFCANVAS-ONSUS-1A`: implementazione solo dopo audit, preservando carrello/checkout.
4. Priorita 4 - Payments, checkout, email.
   - `PAYPAL-ONLINE-AUDIT-1`.
   - `PAYPAL-ONLINE-FIX-1A`.
   - `EMAIL-LEGACY-MAP-1`.
   - `EMAIL-TEMPLATE-MIGRATION-1A`.
5. Priorita 5 - Account, documenti, login.
   - `DOCUMENTIDETTAGLIO-NULLREF-AUDIT-1`.
   - `DOCUMENTIDETTAGLIO-NULLREF-FIX-1A`.
   - `ACCOUNT-PROFILE-1A`.
   - `ACCOUNT-ADDRESS-1A`.
   - `LOGIN-REGISTER-1A`.
   - `RESET-PASSWORD-TOKEN-VERIFY-1`.
6. Priorita 6 - Search, navigazione, mobile.
   - `AI-SEARCH-HEADER-HOME-AUDIT-1`.
   - `AI-SEARCH-HEADER-HOME-1A`.
   - `MOBILE-CATALOG-MENU-AUDIT-1`.
   - `MOBILE-CATALOG-MENU-1A`.
   - `HOME-DEPARTMENTS-MENU-ALIGN-AUDIT-1`.
   - `HOME-DEPARTMENTS-MENU-ALIGN-1A`.
7. Priorita 7 - Visual/commercial avanzato.
   - `PRODUCT-IMAGE-BRIGHTNESS-PREVIEW-AUDIT-1`.
   - `PRODUCT-IMAGE-BRIGHTNESS-PREVIEW-1A`.
   - `COMPARE-WISHLIST-QUICKVIEW-AUDIT-1`.
   - `COMPARE-WISHLIST-QUICKVIEW-1A`.
   - `CROSS-SELL-UPSELL-RECENTLY-VIEWED-AUDIT-1`.
   - `CROSS-SELL-UPSELL-RECENTLY-VIEWED-1A`.
8. Priorita 8 - SEO / AI crawler / proposta Gemini, solo alla fine.
   - `LLMS-TXT-ASHX-JSONLD-AUDIT-1`: solo read-only, valutazione della proposta Gemini a fine roadmap; compatibilita WebForms/VB.NET/.NET Framework/IIS Aruba; pagina prodotto reale `articolo.aspx` e non `prodotto.aspx`; niente C#, ASP.NET Core, controller o routing Core; valutare mapping `llms.txt` -> `llms.ashx` via `web.config`, output `text/plain` Markdown, cache 60s con `HttpContext.Current.Cache`, MySQL ADO.NET/MySqlConnection/MySqlCommand, JSON-LD dinamico, esposizione di prezzi/stock/dati strategici, cache/rate limiting.
   - `LLMS-TXT-ASHX-JSONLD-1A`: solo se audit A e approvazione esplicita Germano.

Regola operativa sulla scaletta:

- Seguire la scaletta sopra e non aprire task paralleli se non servono a sbloccare un problema reale.
- Se emerge un'idea nuova nello stesso perimetro, va analizzata/progettata/implementata nel task corrente solo se non allarga lo scope in modo rischioso.
- Se emerge un'idea su altra area, va registrata in backlog/manuali e trattata quando la scaletta arriva a quel punto.
- Sequenza standard: audit read-only se l'area e delicata, micro-task runtime, smoke Codex, smoke Germano per UI/UX/percorso reale, merge controllato, docs-only, merge docs.
- Deployment guardrail per nuovi file tracked: prima dello smoke/deploy finale costruire il manifest Git distinguendo `added`, `modified`, `deleted` e `renamed`; ogni file `added` va verificato esplicitamente nel target. Per nuovi `App_Code/*.vb`, quando l'ambiente lo consente, controllare presenza nel webroot, cold compile/recycle del solo application pool e HTTP 200. Una build repository OK non prova che il deployment abbia incluso i nuovi file. Se Codex non ha privilegi IIS, dichiarare `runtime deployment sanity non verificabile`; questo da solo non blocca il merge Git quando lo smoke reale Germano e A e il repository non mostra problemi.
- Non implementare `llms.ashx`, `llms.txt`, JSON-LD dinamico, side cart/offcanvas o image brightness preview prima dei relativi audit e del punto corretto in scaletta.

### Chiusura typography globale storefront

- `GLOBAL-TYPOGRAPHY-ONSUS-AUDIT-1` e CHIUSO / A, read-only e senza file modificati. Il runtime e stato misurato su desktop `1365x900` e mobile `390x844`, includendo HOME, catalogo, PDP, carrello di riferimento e componenti condivisi. `styles.css` dichiara `"Inter", serif`, ma `font.css` contiene solo MADE Outer e UTM Banque: l'assenza di `@font-face`/asset Inter e il font effettivo Times New Roman sulle superfici interessate sono stati confermati con CDP `CSS.getPlatformFontsForNode`. La regola legacy `font-size: 1rem !important` in `keepstore.css`, proveniente dal blocco Coupon.master e concorrente al body runtime 16px, e stata rilevata ma non modificata.
- `carrello.aspx` usa `"Inter", Arial, sans-serif`, ma senza Inter il font realmente approvato e Arial. Per questo `GLOBAL-TYPOGRAPHY-ONSUS-1A` e CHIUSO / A sul branch runtime `task/global-typography-onsus-1a`, commit `d0f5f500f75da70aaf0c4a961762cf35f3db51ac` (`fix: establish Arial typography foundation`), con foundation deterministica `Arial, sans-serif`, variabile `--ks-font-ui`, applicata in `Page.master`/`theme-overrides.css` a body, controlli form e heading senza selettore universale e senza interferire con Icomoon; cache-buster `?v=20260829-typography1a`.
- `1A` ha cambiato solo la famiglia. Restano intatte le scale ONSUS: body di riferimento `15/24`, titolo PDP `22/600/25`, CTA PDP `15/600/24`, titolo card catalogo `14/600/22`, prezzo card `20/500/22`, metadata/caption `12-14px`, quantita dedicata e gerarchia responsive HOME. `carrello.aspx` e riferimento di leggibilita, non una dimensione universale da copiare.
- `GLOBAL-TYPOGRAPHY-ONSUS-1B` e CHIUSO / A sul branch `task/global-typography-onsus-1b`, con commit `efae083a3d2dece257290d3c3b5d6bde39d6af32` (`fix: normalize storefront typography families`) e polish `df98e70ced14a6f635d7819fadebe22d09f103ee` (`fix: prevent home product title clipping`), merge fast-forward `--ff-only`.
- Il layer KeepStore finale `theme-overrides.css` normalizza a `var(--ks-font-ui)` le famiglie esplicite pertinenti residue: CTA prodotto HOME; MegaMenu settore, categoria e tipologia/empty; `.font-main`; `.font-2`; `.box-sale-wrap p`; `.ft-heading`; `.sib-form`; card prodotto catalogo; CTA `Acquista` catalogo; quantita catalogo gia presente nel carrello. `styles.css` non e stato riscritto e non e stato fatto alcun mass edit del CSS ONSUS.
- Risultato verificato: HOME, catalogo, PDP, header/MegaMenu, footer e carrello risolvono Arial; Times New Roman e Poppins accidentali risultano assenti sulle superfici storefront visibili testate; Icomoon e preservato. Nessuna modifica generale a font-size, font-weight, letter-spacing, spacing, breakpoint o struttura/layout ONSUS. Una platform font puo mostrare Arial Black su un titolo con peso 800 senza rappresentare un cambio della family CSS.
- Polish HOME incluso in `1B`: sulle card `In Evidenza` e `Best Seller`, `body.ks-page-home .ks-home-main .name-product` usa `line-height: 20px` e `min-height: 40px`. Restano invariati font-size desktop `14px`, mobile `12px`, weight, Arial, uppercase, colore, `-webkit-line-clamp: 2`, overflow e massimo due righe. La causa misurata era la combinazione precedente `min-height: 48px` con line-height `18.2px` desktop / `15.6px` mobile, che lasciava clipping o una porzione indesiderata della riga successiva.
- QA finale: 8 card `In Evidenza` e 8 card `Best Seller` verificate; desktop `1365x900` A e mobile `390x844` A; nessuna terza linea parziale, nessun clipping e prezzi/CTA/allineamento card invariati. `Occasione Imperdibile` non esponeva una product card reale nella fixture e non e stata modificata inutilmente. Smoke Germano A; HTTP post-merge 200 su `Default.aspx`, `articoli.aspx?q=hp`, `articolo.aspx?id=12384&TCid=-1` e `carrello.aspx`.
- Manifest runtime storico `1B`: modificati soltanto `Page.master` e `Public/assets/keepstore/css/theme-overrides.css`; file aggiunti 0, eliminati 0. Il deployment guardrail generale sui nuovi file tracked, in particolare `App_Code/*.vb`, resta comunque valido.
- `GLOBAL-TYPOGRAPHY-ONSUS-1C` e NON NECESSARIO / NON CREATO: `1B` e smoke Germano sono A, Times/Poppins accidentali sono assenti sulle superfici testate, Icomoon e preservato e il clipping HOME e corretto senza regressioni desktop/mobile. Il blocco typography storefront e CHIUSO; questa chiusura non dichiara complete HOME, `articoli.aspx`, `articolo.aspx`, header, footer o l'intera area ecommerce.

### Chiusura cart-state storefront condiviso

- `STOREFRONT-CART-STATE-PERSISTENCE-REGRESSION-AUDIT-1` e CHIUSO come audit diagnostico B/procedibile. La regressione specifica catalogo non e stata riprodotta nel caso anonimo `TCId=-1`: acquisto singolo e multiselect recuperavano quantita e stato corretti. L'audit ha invece confermato la frammentazione tra snapshot catalogo, master, badge HOME e stato PDP; HOME/PDP erano parziali o cosmetici e nessun commit regressivo catalogo e stato dimostrato.
- `STOREFRONT-CART-STATE-PERSISTENCE-1A` e CHIUSO / A sul branch `task/storefront-cart-state-persistence-1a`, commit `68325c1879e2859628b59f297fe2a329b5aadb35` (`fix: unify storefront cart state`), merge fast-forward `--ff-only`, smoke Germano A desktop/mobile.
- Il nuovo `App_Code/CartStateSnapshotProvider.vb` e la fonte server-side condivisa: cache solo request-scoped in `HttpContext.Items`, owner `LoginId` -> `LoginID` -> `LOGINID` con fallback anonimo `Session.SessionID`, query MySQL parametrizzata e aggregata per `ArticoliId + TCId + SUM(Qnt)`, `TCId <= 0` normalizzato a `-1`, massimo uno snapshot prodotti per request e nessuna query per card. Il normale aggregato header/totale resta separato; nessun DB/schema/SP e stato modificato.
- `Page.master.vb` pubblica `window.KeepStoreCartState.items` (`id`, `tcid`, `qty`) dal provider. `articoli.aspx` conserva classi, quantita, delta, multiselect e CTA gia approvati, delegando il vecchio reader locale al provider condiviso. HOME mostra `Nel carrello: X` dalle sole informazioni server e rimuove lo stato allo svuotamento.
- `articolo.aspx` mostra `Nel carrello: X` nella buy-box e usa `txtQty` come totale desiderato. Semantica: `qtyToAdd = desiredQty - existingQty`; `2 -> 2` non aggiunge, `2 -> 3` invia delta `1`, `2 -> 5` invia delta `3`; se il totale desiderato non supera l'esistente non avviene redirect e compare feedback. `Session("Carrello_Quantita")` e il parametro `qty` verso `aggiungi.aspx` contengono il delta. Business logic bundle, `ks_product_bundle_cart_items`, `Carrello_SelezioneMultipla` e `Acquista selezionati` restano invariati; bundle e Simili/Correlati/Recenti possono mostrare lo stato quando riconoscibili nello snapshot.
- `keepstore-cart-state.js` e ora soltanto renderer UI di `window.KeepStoreCartState.items`: rimossi `localStorage`, `STORAGE_KEY`, persistenza click e fallback browser come source of truth. Matching esatto `ArticoliId + TCId` per varianti positive; aggregazione per articolo solo su superfici generiche; nessun secondo badge JS sulle card server-side del catalogo.
- `ARTICOLO-CART-QTY-IN-PDP-AUDIT-1` e `ARTICOLO-CART-QTY-IN-PDP-1A` sono ASSORBITI / SODDISFATTI da audit e runtime cart-state globale e non restano task futuri autonomi. La chiusura riguarda stato e delta quantita, non dichiara `articolo.aspx` completa.
- Limiti test storici del cart-state: `TCId > 0` non era certificato runtime da Codex per assenza fixture reale. Il limite storico sul login non certificato e superato dallo smoke autenticato Germano A dei task `LOGIN-RETURN-CONTEXT-1A` e `LOGIN-ACCESS-AUDIT-1A`; cio non estende automaticamente la certificazione ai casi cart-state `TCId > 0` non coperti.
- Incidente deployment durante lo smoke Germano: errore `BC30002` (`CartStateSnapshotProvider` non definito) causato da deploy incompleto, con codice dipendente aggiornato ma nuovo file tracked `App_Code/CartStateSnapshotProvider.vb` assente dal webroot. Germano ha ripristinato il file corretto; nessun fix sorgente e stato necessario e lo smoke finale cart-state e A. Non classificare l'incidente come timeout sessione, problema anonimo, DB issue o regressione logica carrello.

Backlog sicurezza separato: `CART-ADD-QTY-SERVER-MAX-HARDENING-AUDIT-1`. L'audit PDP CTA ha osservato che `cart_add.aspx` accetta una quantita positiva server-side ma non risulta applicare lo stesso massimo `9999` usato altrove. Non e dichiarata una vulnerabilita critica e non va corretto senza audit dedicato; mantenerlo visibile prima del go-live finale.

Backlog hardening separato: `CART-SESSIONID-LOG-REDACTION-1A`. L'audit cart-state ha rilevato log legacy in `aggiungi.aspx.vb` che possono includere il SessionId completo; il runtime non e stato modificato in `STOREFRONT-CART-STATE-PERSISTENCE-1A` e la severita va determinata con audit dedicato, senza dichiarazioni critiche preventive.

### Conoscenza storica integrata / anti-regressione

- Nota di prevalenza cart-state: nei record storici precedenti, le frasi che indicano la quantita gia in carrello su `articolo.aspx` come backlog descrivono lo stato dell'epoca. Sono superate dalla chiusura `STOREFRONT-CART-STATE-PERSISTENCE-1A`; non costituiscono task futuri autonomi.
- Dai vecchi file `AGENTS.md` e patch notes resta confermata la separazione fondamentale: KeepStore e il motore dati/logica/permessi, ONSUS e la sorgente UI/UX, e tra i due servono componenti e contratti dati chiari. Non mischiare nello stesso micro-task logica VB, query SQL, HTML, SEO, JS e template se non e indispensabile e autorizzato.
- Non fare task larghi tipo "sistema tutto" e non riaprire blocchi chiusi senza bug live verificato. Le vecchie istruzioni ZIP/copia-incolla e patch manuali sono storiche, non metodo operativo attuale: oggi si lavora con branch, commit, PR verso `frontend-rebuild`, review, smoke e merge controllato.
- Header, search e catalogo devono restare ONSUS source-first: provider catalogo unico dove applicabile, gerarchia reale `settore > categoria > tipologia`, immagini settore moderne da `/Public/assets/images/settori/`, top bar con dati reali da `aziende`/`vettori` e hook ONSUS per compare, wishlist e cart. PR #210 e PR #214 restano chiuse; eventuali evoluzioni sono nuovi audit mirati, non regressioni.
- Ricerca intelligente resta roadmap separata: prima ranking deterministico coerente tra suggest e risultati (`codice/EAN` esatto, inizio parola, contenuto, marca + descrizione), preview immagine, recenti client-side e redirect coerente verso `articoli.aspx`; solo dopo audit dati reali si valuta AI/search assistita.
- Le patch sicurezza storiche indicano hardening incrementale, non sicurezza completata: backlog progressivo su `AntiCsrfPage`, `KeepStoreSecurity`, encoding output, query parametrizzate/whitelist, escape LIKE e parsing numerico. Non modificare auth, DB o pagine sensibili senza task dedicato e verifica dello stato reale.
- Feature flag/kill-switch sono solo backlog/policy futura: se serviranno, dovranno essere espliciti, admin-only, auditati, CSRF-protected, con storage controllato e logging. Evitare chiavi `Application` opache e output JS inline; nessuna tabella o implementazione DB viene autorizzata da questa nota.

### Regola multi-azienda / dominio / runtime

- Ogni installazione usa il database esplicitamente selezionato dalla propria configurazione di deploy. Nel database selezionato, `aziende` e la fonte autorevole dell'identita tenant; `url1` e il canonico e `url2` l'eventuale alias.
- Domini diversi possono avere webroot/configurazioni IIS separate oppure condividere il runtime solo quando l'isolamento e la topologia sono stati autorizzati. Prima di un test sensibile si registrano ambiente, host, tenant risolto e commit, senza segreti.
- `localhost` e gli altri loopback sono esclusivamente facilitazioni di laboratorio e non determinano l'identita commerciale. Un test tenant-aware usa mapping sintetici o configurazione locale esplicita e non deduce mai il cliente dal nome del database o da valori storici.
- Non confondere visibilita di un metodo di pagamento con configurazione del gateway. Credenziali, account e fallback di servizi esterni sono tenant-specifici e non si copiano tra aziende senza autorizzazione esplicita.
- Il contratto prevalente e `MULTITENANT-BY-DESIGN`: nessun nuovo cliente richiede branch, patch del sorgente, dominio hardcoded o stored procedure personalizzata.

### Ripartenza rapida in nuova chat

- In una nuova chat partire dal root `AGENTS.md`, dal checkpoint corrente e dalle fonti necessarie a ricostruire lo stato; leggere integralmente i manuali solo quando l'ampiezza dell'audit lo richiede, verificando comunque Git e codice reale prima dei prompt importanti.
- Usare il checkpoint operativo iniziale per HEAD stabile, ultimo task chiuso, task attivo, prossimo runtime, directory consentite e blocker; verificarlo sempre contro Git.
- Non richiedere o produrre un enorme riepilogo della chat e non rifare audit gia chiusi. Handoff e memoria sono supporto, non source of truth.
- Mantenere lo stesso metodo Germano/ChatGPT/Codex: micro-task, branch dedicati, PR verso `frontend-rebuild`, merge controllati e cleanup separati.
- La continuita dipende da Git e documentazione corrente. Aggiornare checkpoint e sezioni di stato dopo ogni blocco importante.

## 1. Metodo ChatGPT + Codex

### Ruoli

- ChatGPT mantiene la direzione funzionale, la sequenza dei task e i criteri di accettazione; applica `AGENTS.md` e la lettura proporzionata e, dopo il push, controlla direttamente branch/commit/diff GitHub prima di assegnare A/B/E.
- Codex lavora su branch dedicati, legge codice e dipendenze pertinenti, applica patch piccole, svolge discovery proattiva, crea commit, pusha e apre/aggiorna la PR; dopo A ChatGPT e autorizzazione Germano esegue il merge fast-forward e le verifiche finali.
- Ogni task deve avere una modalita chiara: implementazione, verifica sola lettura, merge controllato, smoke, cleanup.

### Regole operative

- Branch base ordinario: `frontend-rebuild`.
- Non lavorare su `main` e non aprire PR verso `main`.
- Usare branch `task/<nome-task>`.
- Ogni implementazione termina con:
  - diff circoscritto;
  - precompilazione ASP.NET quando richiesta;
  - `git diff --check`;
  - commit;
  - push del task branch su origin prima della review finale ChatGPT;
  - apertura o aggiornamento PR verso `frontend-rebuild`.
- La review della PR, separata dal merge, e in sola lettura:
  - niente commit;
  - niente push;
  - niente merge;
  - niente ordini o pagamenti.
- Ogni merge deve confermare:
  - PR open;
  - base corretta;
  - compare corretto;
  - head commit atteso;
  - `mergeable=true`;
  - `mergeable_state=clean`;
  - PR non verso `main`;
  - `main == origin/main`.
- Dopo autorizzazione, Codex esegue il merge fast-forward e poi:
  - sincronizza locale `frontend-rebuild` da origin;
  - verifica parent e assenza di merge commit;
  - conferma `HEAD == origin/frontend-rebuild` e `main == origin/main`;
  - conferma staging vuoto, tracked tree pulito e asset protetti preservati.

### Sicurezza

- Non inserire secret nel repository.
- Non stampare password, API signature, client secret, token completi o NVP completi.
- Non usare account PayPal reale.
- Non inserire dati carta reali.
- Non chiamare gateway live salvo autorizzazione esplicita in task dedicato.
- Non modificare DB/dump SQL salvo task DB esplicito con backup.

#### Account di collaudo PROVA ed evidenza smoke

- L'account di collaudo PROVA deve essere conservato per l'intera durata del progetto. E vietato cancellarlo, disabilitarlo, rinominarlo, modificarne la password o eliminare intenzionalmente i suoi dati e audit storici. Soltanto il Product Owner potra cancellarlo alla fine del progetto.
- Password e altre credenziali dell'account non devono comparire in repository, commit, PR, manuali, log o output. Le credenziali necessarie a uno smoke restano nei soli canali locali sicuri autorizzati.
- Ogni smoke autenticato con PROVA conserva evidenza sanitizzata di: task e data; ambiente e URL; fixture/articoli; stato iniziale e finale di carrello, documenti, wishlist e inventario pertinente; operazioni; risultati; anomalie; conferma dell'assenza di pagamenti, gateway, e-mail e ordini reali.
- E consentito ripristinare tramite i percorsi applicativi il carrello e le fixture allo stato iniziale per evitare contaminazioni tra test. Il ripristino non autorizza la cancellazione dell'account o l'omissione dell'evidenza dello smoke.

## 2. Regola ONSUS per refactor UI

ONSUS e il riferimento grafico principale per i refactor UI del frontend KeepStore.
Quando si rifattorizza o si adegua una pagina, la priorita visuale e di esperienza utente va data a ONSUS e a una UX moderna 2026.

Principio operativo:

- KeepStore legacy resta fonte dati, contratti, permessi e logica esistente.
- La presentazione deve seguire ONSUS quando offre una struttura piu efficace.
- Le informazioni devono essere chiare, intuitive, sintetiche e leggibili senza percorsi macchinosi.
- Non bisogna replicare automaticamente schermate legacy se il template ONSUS permette una lettura piu moderna.
- Se una logica legacy e vecchia, errata o poco moderna, non va corretta di nascosto dentro un refactor grafico: serve prima analisi impatto e proposta micro-task.
- Germano decide se intervenire subito sulla logica o rimandare.

Quando si rifattorizza una pagina:

- analizzare prima il template ONSUS corrispondente;
- preservare la logica server e i permessi esistenti;
- sostituire la struttura grafica senza cambiare contratti DB o gateway;
- separare chiaramente dati gestionali e stati di pagamento;
- mantenere layout responsive e coerente con `Public/assets/keepstore`;
- modificare `theme-overrides.css` solo per aggiustamenti piccoli e mirati;
- non toccare header, footer, MiniCart, checkout o gateway se non richiesto.

## 3. Stato Git storico — prevale il checkpoint 2026-10-01

Stato corrente al 2026-09-10 dopo il merge fast-forward runtime della PR #245:

- Branch stabile: `frontend-rebuild`
- HEAD locale/origin `frontend-rebuild`: `d773408588c4fc91472a4b71ef9d3980e1c93072`.
- Catena retry deadlock integrata: base `ef3bce60af997b35a2779f43a102c2df5c4ae7c7`, commit/stable `d773408588c4fc91472a4b71ef9d3980e1c93072`; PR #245, fast-forward only, un commit e zero merge commit.
- La base precedente `ef3bce60af997b35a2779f43a102c2df5c4ae7c7` incorpora la documentazione B2C della PR #244; la relativa iniziativa resta differita per decisione del Product Owner.
- Catena batch atomico integrata: base `516442a46869353daaac20407cd0c263c466ae72`, commit `08d2b77bbb2b7d1403d5c73107d54587bd0c1d94` e commit finale `df5436deae0bdc672dbed1c7965941a031bb3d49`; PR #242, fast-forward only, due commit e zero merge commit.
- Nota storica del checkpoint shipping: HEAD locale/origin `frontend-rebuild` era `91cbc10b3b343217e18c5a9a6707b72997467b00`; resta uno storico autentico e non il checkpoint corrente.
- Commit async cart finale: `b80f8d4683bbb9bb6ec8a7a486a79048bfae094f`; commit CTA stability finale: `58f4ee43c363d629b3124fc0fb1a10beaeeef48a`.
- Commit PDP commercial info/shipping: `afc4c72c148984ba729c6cb20de38161dc56e2b4`; REV1 IVA e merge point: `91cbc10b3b343217e18c5a9a6707b72997467b00`.
- Branch hotfix conservato: `task/storefront-card-layout-regression-1a` a `982cc83bcbcbb913dd1e320ece456957801f8121`.
- Branch availability conservato: `task/storefront-availability-presentation-1a` a `b78cbedab9cd21806cd57d7efb0d91e8c0a8d0f3`.
- `main` / `origin/main` invariati: `976e99f17cabc8a5c6a8715463444edfeaadcd91`
- Base cumulativa precedente: `300b97a7a8873d3cd0cb750be2e949523a8ebaa0`; consolidamento lineare fast-forward only di 7 commit, ahead/behind pre-merge `0 / 7`.
- Commit PDP CTA: `b56277c7777345c70021e21270628b72a51a2f4c` e `3b0b2ac97564c497abd26d224e5e945834a2ec26`; merge `--ff-only`, smoke Germano finale A desktop/mobile.
- Commit foundation typography: `d0f5f500f75da70aaf0c4a961762cf35f3db51ac` (`fix: establish Arial typography foundation`); runtime limitato a `Page.master` e `Public/assets/keepstore/css/theme-overrides.css`, smoke Germano A desktop/mobile.
- Commit typography `1B`: `efae083a3d2dece257290d3c3b5d6bde39d6af32` (`fix: normalize storefront typography families`) e `df98e70ced14a6f635d7819fadebe22d09f103ee` (`fix: prevent home product title clipping`); merge fast-forward `--ff-only`, smoke Germano A desktop/mobile, blocco typography chiuso.
- Commit cart-state storefront: `68325c1879e2859628b59f297fe2a329b5aadb35` (`fix: unify storefront cart state`); merge fast-forward `--ff-only`, smoke Germano A desktop/mobile.
- Commit catalog parity `1A`: `1acbba90a4e9973da695ec08a80840fd113a90fa` (`fix: stabilize catalog request state and paging`); stato URL e paging deterministici, smoke Germano A.
- Commit catalog toolbar `1B`: `9903687f89f99073d29cc0598746e17511f7e546` (`fix: align catalog toolbar with Onsus controls`); merge fast-forward `--ff-only`, smoke Germano A.
- Commit product-image `1C`: `817966edc417c907a79a20f22f9cf6f84d4a17f6` (`fix: centralize product image resolution`) e polish/stable `9a6e5b1babc836adb33cd43f930a112cd6e77103` (`fix: polish missing product image placeholder`); merge fast-forward `--ff-only`, smoke Germano A.
- Merge PR #208 fix binding carrello `TCid`/`TCId`: `3cf52876ecec1033fdde3ab51d13a7c4a25390f9`
- Merge PR #206 documentazione chiusura promo/carrello/IVA: `08a68f27ca7938a999cda6992ae0086cab7b3447`
- Merge PR #204 promo/offerte legacy su scheda/catalogo/carrello: `daae01b0ab0cf2e52afc685c047ddd45779fad89`
- Merge PR #205 coerenza `Totale articoli` carrello IVA inclusa/esclusa: `1d87f083f488f06acbdd38b617ee8f7d68f276a0`
- Smoke finale promo/carrello/IVA: `FINAL-SMOKE-PROMO-CART-VAT-1A = A`
- Merge PR #196 scheda prodotto ONSUS: `6e28c859`
- Merge PR #197 disponibilita `Aziende.DispoTipo`: `741d141f`
- Merge PR #198 disponibilita legacy/promo/listino/tooltip scheda articolo: `eaf2618a7a243a43fc733f906061f28a52a559cc`
- Merge PR #199 deduplica prezzo/disponibilita/promo e icona tooltip reale: `94c328c16f172b352bc1a5a99915dcc56b766c50`
- Merge PR #98: `12f4fd5ec2dff6c15ee7479e854628bd71dc9ed5`
- Merge PR #100: `f0eeccc12d701268641dc10950bb1253670f86fa`
- Merge PR #101: `7bfd40cb685e0500f427cf4a481516f70038d235`
- Merge PR #102: `919b342bd0d0c9ff7b7bddc0453f99e4efe79fbc`
- Merge PR #103: `8a3efe677fce31c7eb7f590747ac1a7d2cf7197d`
- Merge PR #104: `7279f797be01090b573d514a9a64d5519ebe4489`
- Merge PR #105: `fbafc68ca36b2ba19a9d16d50af05313e3824209`
- Merge PR #107: `a4381b83ec5c617c6dc75022d30580ded5394f62`
- Merge PR #109: `7fe10f0edfbc7b7d5951116697c6654a100ba60f`
- Merge PR #111: `90c13d3bb41ff8d437f3cc9605a736659b04f4ce`
- Merge PR #112: `3d1873f5e3ea071ef187cc906f5d8712a58a09e6`
- Merge PR #117: `f51ab9a4df9afb71760a31db97ed0eac547cd9c3`
- Merge PR #121: `f11cf0b434b9be111d470b995083edf9d18b481b`
- Merge PR #122: `3415094758e4b3cdc38d5284daf1e847695766c4`
- Merge PR #123: `93a186e850caf5195b8bb7b3e21c42e5cf1c15af`
- Merge PR #124: `9d9d56661db0bcf4f6cdfa1dae331db05b7d5f20`
- Merge PR #126: `c5b85354f9f589354d2e08ec14502f6ac5d159c2`
- Merge PR #127: `30be626aeb285f3fa6cb6e6f98bc47ba081edba0`
- Merge PR #128: `687198cf51a8d57f61acc997856ffd2eac7cd9e4`
- Merge PR #130: `e621eca0a110d2b02d4b83afc27716738108a64a`
- Merge PR #132: `3c50d87962f7791bd7424be1fa376377889b90f8`
- Merge PR #133: `1e0bea8fdcf6e623d22b74ab481b763bfcad6a52`
- Merge PR #134: `7d7205871f85fb33a7cd74dbfbc790cb8f435718`
- Merge PR #135: `54f7bea85c817e7d2a37ab42db0e2e61428d3f9d`
- Merge PR #136: `6160bd8f1f81eff63e789ea7f5a15c130be8f4ba`
- Merge PR #137: `08d5b197393c5d8786dc6a6e108c83beadff0445`
- Merge PR #138: `86d9abfe5fd2567c6ab586167230c455a6325a87`
- Merge PR #139: `2d9c11d9df99a3973593d6f7e7109f5517d3501c`
- Merge PR #140: `73ac6bdf2f303e3581c539ae6dcfca9d1a64f969`
- Merge PR #141: `f8c75acd94531ceb7e2a1488bddc5eb5e27704da`
- Merge PR #142: `3e3efd58268597b6ea1ce978e00bf673dd14a783`
- Merge PR #143: `ccb41fc019100e38d2ba01840ac293956a7a0260`
- Merge PR #144: `42dc685c3c7b99fe9d19284f477ff9f26fb5ee20`
- Merge PR #145: `1fe259a44e9d9252a9733a4c721b13d933963d46`
- Merge PR #146: `c999ecd5e890b2e11bd05c204f2738492f086b07`
- Merge PR #147: `5c4ec079528c8d0610a85d66ec766d266f1b6c3b`
- Merge PR #148: `7558e7dbd8a3221425d5b9bc432fcf272c45625e`
- Merge PR #149: `05a43e54821af795ce897f50465405a7cae21bea`
- Merge PR #150: `b41cc367366fd0a2cfb470edc9afb259cbde2c71`
- Merge PR #151: `a5e39aa9ff226af1de7604503489d0d34efbe4a8`
- Merge PR #152: `c0896bfe40c40cc88aabd6944e309a738e37156f`
- Merge PR #153: `5a0e2565fa94b3ab8705842c3e10359d381f46e6`
- Merge PR #154: `1b7e77b2a7ef6cb4f6fcd6f490a3e3d3bad6abea`
- Merge PR #155: `6c3724ba36bc146fe7551a0d1f90676403fd4ad7`
- Merge PR #156: `5718df4067cd73a1ce5e9fb958e5d6b74577f0ca`
- Merge PR #157: `6d103d68df9931bc4f44e28b5c89018dfd86dd29`
- Merge PR #158: `19e5ff8ce9cca198c0458aa0bd5ef70fe5a9bf5d`
- Merge PR #159: `a23f2a6153b57048769dd5b2a6153f2d13ced445`
- `main` invariato: `976e99f17cabc8a5c6a8715463444edfeaadcd91`

Branch PayPal/config/document detail/my orders/account dashboard/account profile gia mergiati e, dove previsto, puliti:

- PR #81 PayPal state contract and sandbox-safe launcher skeleton
- PR #82 PayPal post-order routing to launcher
- PR #83 PayPal Express Checkout NVP implementation
- PR #84 DB-backed PayPal Express configuration
- PR #85 v3 clean schema alignment
- PR #86 fixed internal PayPal NVP version
- PR #87 transaction currency fix
- PR #88 cancel transaction state fix
- PR #89 PendingReason/ReasonCode tracking
- PR #90 pending transaction recheck
- PR #91 ONSUS document detail refactor
- PR #92 hide empty Pay Now card
- PR #94 ONSUS my orders list refactor
- PR #95 stato filter fix, superato dal fix definitivo successivo
- PR #96 documenti filters GET fix
- PR #98 ONSUS account dashboard refactor
- PR #100 ONSUS account profile refactor
- PR #101 account sidebar root-level links fix
- PR #102 account sidebar active/current fix
- PR #103 masterplan update after account profile closure
- PR #104 masterplan sidebar inline debt correction
- PR #105 account sidebar inline cleanup phase 1 simple pages
- PR #107 account address ONSUS read-only refactor
- PR #109 account documenti sidebar cleanup phase 2 with dynamic document selector
- PR #111 account password canonical flow
- PR #112 account password confirmation validation hotfix
- PR #117 login/registrazione/reminder immediate security mitigations
- PR #121 feedback Germano su reset token, gestionale e `aziende.ScadenzaPassword`
- PR #122 masterplan post PR #121 closure alignment
- PR #123 script DB idempotente `login_password_reset_tokens` versionato, non eseguito
- PR #124 handoff operativo Vincenzo per script DB reset tokenizzato
- PR #133 chiusura documentale reset password tokenizzato fase 1
- PR #134 cleanup warning legacy `remind.aspx.vb`
- PR #135 chiusura documentale post cleanup warning reset/remind
- PR #136 account profile validation hardening
- PR #137 account smoke hotfix
- PR #138 account smoke hotfix follow-up
- PR #139 account address defaults
- PR #140 account address/login UX polish
- PR #154 audit e-mail transazionali documentale

## 4. Roadmap sintetica

### Pagamenti

1. Distribuire la migration Orders v2 soltanto dopo review e autorizzazione separata.
2. Configurare l'account condiviso e i mapping tenant Taikun/Webaffare nel gestionale.
3. Provisionare Client ID, Client Secret e Webhook ID nel secret/config store del server.
4. Eseguire verify read-only e poi un unico smoke LIVE controllato, senza dichiarare prima `LIVE VERIFIED`.
5. Mantenere BancaSella e gli altri metodi separati dal nuovo motore PayPal.

### UI account/documenti

1. Continuare refactor ONSUS sulle pagine area account non ancora migrate.
2. Separare sempre:
   - stato ordine;
   - stato pagamento.
3. Mantenere dashboard, lista ordini e dettaglio ordine coerenti tra loro.
4. Aggiungere smoke desktop/mobile per ogni refactor.
5. Evitare azioni gateway dirette nelle liste: il retry pagamento resta nel dettaglio ordine salvo task dedicato.
6. Stato area account gia stabilizzata:
   - `documentidettaglio.aspx`: stabile;
   - `documenti.aspx`: stabile con AccountSidebar globale e selector documenti dinamico;
   - `myaccount.aspx`: stabile;
   - `my-account-edit.aspx`: stabile.
   - `wishlist.aspx`: stabile;
   - `my-account-address.aspx`: stabile read-only ONSUS.
   - `password.aspx`: stabile come pagina canonica cambio password.
   - `cambiapassword.aspx`: legacy redirect controllato verso `password.aspx`.

### Documentazione

1. Aggiornare questo masterplan dopo merge importanti.
2. Aggiungere note operative per smoke PayPal sandbox.
3. Mantenere documenti tecnici senza secret.

### Sicurezza login/registrazione/reminder

1. LOGIN-REGISTER-SECURITY-1 e chiuso lato codice con PR #117.
2. Login, registrazione e reminder sono mitigati senza schema change e senza hash migration.
3. Reminder automatico password disabilitato e trasformato in recupero assistito.
4. Registrazione non deve esporre password in email, URL o sessione.
5. Hash migration, reset tokenizzato e audit gestionale restano task separati.

## 5. Stato PayPal

### Decisione tecnica

Stato corrente dopo `PAYPAL-CHECKOUT-ORDERS-V2-LIVE-1A`: **READY FOR LIVE CONFIGURATION**, non ancora LIVE VERIFIED.

KeepStore usa esclusivamente PayPal Checkout Orders API v2 REST LIVE:

- OAuth client credentials su configurazione deploy server-side;
- Create Order, Get Order e Capture Order `/v2/checkout/orders`;
- `PayPal-Request-Id` deterministico e persistito per create/capture;
- webhook REST con verifica ufficiale della firma ed EventId univoco;
- profilo esatto `AziendeId + PagamentiTipoId`, senza fallback cross-tenant;
- `PP-ORDER:<OrderId>` pending e `TXN:<CaptureId>` completed.

Il runtime rifiuta localhost/loopback, HTTP, tenant non autorevole, credenziali mancanti e mismatch di documento/importo/valuta/payee/merchant. `Pagato=1` è possibile soltanto dopo capture autorevole `COMPLETED`.

### Checkpoint storico superato

Il blocco seguente descrive il motore precedente e non è più un contratto runtime. KeepStore usava PayPal Express Checkout classico NVP:

- `SetExpressCheckout`
- `GetExpressCheckoutDetails`
- `DoExpressCheckoutPayment`
- `GetTransactionDetails` per recheck pending

Questa decisione è stata sostituita da Orders API v2.
Non usare `_xclick` come checkout principale.
Non usare `ipn.aspx.vb` come autorita primaria.

### Configurazione

Storicamente PayPal Express leggeva configurazione da DB tramite `vpaypal_express_azienda`; tali strutture sono ora solo oggetto di migrazione/rimozione.

Schema runtime definitivo:

- `ApiUsername`
- `ApiPasswordProtetta`
- `ApiSignatureProtetta`
- `BusinessAccount`
- `Environment`
- `CurrencyCode`
- `AllowLive`
- `Attivo`

Scelte definitive:

- niente dipendenza runtime da `VersioneApi`;
- niente dipendenza runtime da `CredenzialiProtette`;
- niente alias intermedi nella view;
- `DEFAULT_PAYPAL_NVP_VERSION = "204.0"` in `PayPalCheckoutConfig.vb`;
- `VERSION=204.0` per Set/Get/Do/Recheck.

### Diagnosi multi-azienda PayPal ON-LINE

Audit `PAYPAL-ONLINE-CONFIG-VERIFY-1A` chiuso con esito A: il problema PayPal osservato in locale non e un bug gateway generico, ma una differenza di contesto azienda/configurazione.

- DB condiviso multi-azienda: Taikun = `AziendeId=1`, Webaffare = `AziendeId=2`.
- Nota storica superata dalla policy same-database REV1: in presenza di piu righe `aziende`, `localhost` senza un host mapping autorevole non seleziona alcuna vetrina e fallisce chiuso. I test tenant-aware usano sempre il dominio/mapping della riga destinataria.
- `pagamentitipo` contiene PayPal ON-LINE per entrambe le aziende:
  - Taikun/Azienda 1: pagamento `19`, `PayPal ON-LINE`, `OnLine=2`, `Abilitato=1`, `Web=1`, `CostoMassimo=5000`;
  - Webaffare/Azienda 2: pagamento `12`, `-PayPal ON-LINE`, `OnLine=2`, `Abilitato=1`, `Web=1`, `CostoMassimo=1000`.
- `vpagamentitipo` restituisce PayPal per entrambe le aziende con i totali test, quindi la visibilita del metodo non e il blocco principale.
- `vpaypal_express_azienda` contiene configurazione Express solo per Taikun/Azienda 1 + pagamento `19`, ambiente `sandbox`, credenziali presenti e `AllowLive=0`.
- Non e presente configurazione Express per Webaffare/Azienda 2 + pagamento `12`; i fallback `PAYPAL_EXPRESS_*` risultano assenti in `web.config/appSettings` e environment.
- Conclusione operativa: per Taikun/Azienda 1 la base di configurazione PayPal Express sembra presente e va testata solo con contesto Taikun; per Webaffare/Azienda 2 PayPal puo apparire come metodo ma non puo partire correttamente finche manca la configurazione Express o una decisione di disabilitazione/nascondimento.
- Prossimi task separati: `PAYPAL-TAIKUN-SANDBOX-SMOKE-1A`, `PAYPAL-WEBAFFARE-EXPRESS-CONFIG-DECISION-1A`, eventuale `MULTI-AZIENDA-RUNTIME-DIAGNOSTIC-1A` solo se approvato esplicitamente.

### Stato pagamento KeepStore

Campi documento usati:

- `Pagato`
- `IdTransazione`
- `StatoPagamentoWeb`
- `DataStatoPagamentoWeb`
- `UltimoEsitoPagamentoWeb`

Mapping operativo:

- `0` o `NULL`: non avviato
- `1`: in attesa / in verifica PayPal
- `2`: pagato
- `3`: non completato / errore
- `4`: annullato dall'utente
- `5`: fallback legacy / in verifica

Regola vincolante corrente:

- `Pagato=1` solo dopo capture Orders v2 `COMPLETED`, verificata contro documento, tenant, account, importo, valuta, payee e merchant.
- Recheck usa Get Order e non ripete una capture già completata.

### Token e TransactionID

Convenzione corrente:

- ordine PayPal creato/pending: `PP-ORDER:<OrderId>` in `documenti.IdTransazione`;
- capture completata: `TXN:<CaptureId>` in `documenti.IdTransazione`.

Nei log/report:

- token sempre mascherato;
- transaction id sempre mascherato se mostrato;
- nessuna query NVP completa.

### Stato Express/Sandbox storico

Smoke principali:

- SetExpressCheckout sandbox: stabile, token creato, redirect sandbox OK.
- Cancel sandbox: stabile, documento `StatoPagamentoWeb=4`, retry Pay Now consentito se policy legacy lo permette.
- Transazione cancel: `paypal_express_transazioni.Stato=CANCELED`.
- Pending sandbox: stabile con `PaymentStatus=Pending`, `PendingReason=paymentreview`, `Pagato=0`, `StatoPagamentoWeb=1`, Pay Now non visibile.
- Recheck pending: implementato con `GetTransactionDetails`, senza richiamare Do.

Documenti PayPal di riferimento:

- `167333` / ordine `162`: pending `paymentreview` con recheck.
- `167334` / ordine `163`: pending `paymentreview`.
- `167336` / ordine `165`: canceled, retry PayPal disponibile.

## 6. Stato Document Detail

La pagina `documentidettaglio.aspx` e stata rifattorizzata con struttura ONSUS.

Concetti separati:

- Stato ordine: stato gestionale/documento, per esempio `Inviato`.
- Stato pagamento: derivato da `Pagato`, `StatoPagamentoWeb`, `UltimoEsitoPagamentoWeb` e motivazioni PayPal salvate.

Blocchi principali:

- breadcrumb Home / Account / Ordini / Dettaglio;
- overview ordine;
- card Stato ordine;
- card Stato pagamento;
- card Spedizione, pagamento e tracking;
- card indirizzi;
- card Prodotti;
- card Riepilogo;
- card Paga adesso, solo se esiste un'azione reale.

### Pay Now

Stato dopo PR #92:

- pending PayPal `StatoPagamentoWeb=1`: nessun link Pay Now/PayPal e nessuna card vuota `Paga adesso`;
- canceled PayPal `StatoPagamentoWeb=4`: card visibile solo se retry ammesso e contiene link reale a `paypalcheckout.aspx?id=<documentId>`;
- documento pagato: card non visibile;
- BancaSella: URL/logica invariati, cambia solo la visibilita del contenitore.

Smoke DOC-DETAIL-2C-D:

- `167334`: pending, card `Paga adesso` non visibile.
- `167333`: pending, card `Paga adesso` non visibile.
- `167336`: canceled, card visibile con link reale PayPal retry.
- mobile `390x844`: nessuna card vuota e nessun overflow sui casi principali.

## 7. Stato My Orders / documenti.aspx

MY-ORDERS-1 e chiuso.
ACCOUNT-SIDEBAR-INLINE-CLEANUP-2B su `documenti.aspx` e chiuso.

Esiti principali:

- MY-ORDERS-1A audit ONSUS: A.
- MY-ORDERS-1B/1C refactor lista ONSUS: completato.
- PR #94 merge commit: `b3970df0838a805adb6db6d4eb1adfc1126582b4`.
- MY-ORDERS-1D filtro stato: superato dalla correzione successiva.
- PR #95 merge commit: `c96fe7ef95574831d9874a497df85c283c31099b`.
- MY-ORDERS-1E fix definitivo filtri GET: completato.
- PR #96 merge commit: `41a709b22ce37bf6b1669f52b690824082e4ebc1`.
- Smoke MY-ORDERS-1E-D: A.
- Cleanup branch MY-ORDERS: completato.
- PR #109 merge commit: `7fe10f0edfbc7b7d5951116697c6654a100ba60f`.
- Branch task PR #109: `task/account-sidebar-inline-cleanup-2b-documenti`.
- Cleanup branch PR #109 completato: branch locale e remoto rimossi.

Comportamento finale `documenti.aspx`:

- layout ONSUS account/orders;
- `Page.master.vb` include `documenti.aspx` tra le pagine con `body.ks-page-account`;
- AccountSidebar globale visibile/usabile;
- voce Ordini/Documenti active/current corretta con una sola voce `active` e un solo `aria-current`;
- nav inline legacy `.myaccount-nav` rimossa/non visibile;
- nessuna doppia sidebar visibile;
- selector dinamico `sdsTipo` mantenuto/ripristinato;
- `asp:Repeater rTipo` mantenuto con `DataSourceID="sdsTipo"`;
- `LinkButton lbTipoDocumento` mantenuto con attributo `tipoDocumento`, `tipoDocumentoClick` e `preRenderClick`;
- hardcoding esclusivo `t=4/2/1` eliminato;
- tipi documento extra non esclusi;
- colonne: Numero, Data, Totale, Metodo pagamento, Stato ordine, Stato pagamento, Azione;
- Azione solo `Dettaglio`;
- azione Dettaglio invariata;
- nessun Pay Now diretto in lista;
- nessun link PayPal/BancaSella/gateway diretto in lista;
- nessun Pay Now/gateway diretto introdotto;
- tracking non in Azione;
- filtri GET validati;
- filtro `Inviato`: OK;
- filtro `ultimo mese`: OK;
- filtro `In lavorazione`: OK;
- combinazione `Inviato + ultimo mese`: OK;
- mobile `390x844`: OK;
- nessun ordine, pagamento o gateway chiamato nello smoke.
- `documenti.aspx.vb` invariato.

File modificati da ACCOUNT-SIDEBAR-INLINE-CLEANUP-2B:

- `Page.master.vb`
- `documenti.aspx`

File non modificati:

- `documenti.aspx.vb`
- `documentidettaglio.aspx`
- `documentidettaglio.aspx.vb`
- `datiutente.aspx`
- `datiutente.aspx.vb`
- `datiutente-ui.js`
- `password.aspx`
- `password.aspx.vb`
- `cambiapassword.aspx`
- `cambiapassword.aspx.vb`
- `myaccount.aspx`
- `my-account-edit.aspx`
- `my-account-address.aspx`
- `wishlist.aspx`
- `web.config`
- markup `Page.master`
- DB/schema/dump SQL
- checkout/carrello/gateway/pagamenti
- asset ONSUS originali

Smoke finale ACCOUNT-SIDEBAR-INLINE-CLEANUP-2H:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Login PROVA OK.
- `documenti.aspx` desktop OK.
- Redirect previsto a `documenti.aspx?t=4`.
- `body.ks-page-account` presente.
- AccountSidebar visibile/usabile.
- Ordini/Documenti active/current con 1 `active` e 1 `aria-current`.
- `.myaccount-nav` assente/non visibile.
- Nessuna doppia sidebar visibile.
- Selector dinamico `sdsTipo` presente e recepito.
- Hardcoding esclusivo `t=4/2/1` assente.
- Tipi documento visibili da datasource:
  - Preventivo
  - Ordine
  - D.D.T.
  - Fattura Immediata
  - Fattura Differita
  - Nota di Credito
- Tipi extra non esclusi.
- `t=4`, `t=2`, `t=1` verificati solo lista/read-only.
- `t=18` verificato con redirect sicuro a `t=4`, nessun errore.
- Lista documenti/stato vuoto OK.
- Azione Dettaglio presente dove ci sono righe, ma nessun dettaglio aperto.
- Pay Now/gateway diretto assente.
- Mobile `390x844` OK.
- Nessun overflow orizzontale grave.
- Nessun errore ASP.NET/MySQL/Object reference/500.
- Nessun PayPal, BancaSella, gateway, carrello, checkout o ordine invocato.
- Password non modificata.
- Dati utente non modificati.
- Dati sensibili non esposti.

Regola UX confermata:

- la lista ordini mostra lo stato pagamento senza obbligare l'utente ad aprire dettagli tecnici;
- il retry pagamento resta nel dettaglio ordine;
- stato ordine e stato pagamento restano concetti separati.

## 8. Stato Account Dashboard / myaccount.aspx

ACCOUNT-DASHBOARD-1 e chiuso.

Esiti principali:

- ACCOUNT-DASHBOARD-1A audit ONSUS `my-account.html`: B, pronto con note.
- ACCOUNT-DASHBOARD-1B refactor dashboard ONSUS: completato.
- PR #98 merge commit: `12f4fd5ec2dff6c15ee7479e854628bd71dc9ed5`.
- Smoke ACCOUNT-DASHBOARD-1B-D: A.
- Cleanup branch ACCOUNT-DASHBOARD-1: completato.

Comportamento finale `myaccount.aspx`:

- layout ONSUS account/dashboard;
- sidebar account coerente con l'area account;
- hero/saluto con fallback sicuro;
- card Profilo con dati essenziali;
- card Indirizzi con indirizzo principale o fallback;
- card Ordini recenti, massimo 5 righe;
- ordini recenti con Stato ordine e Stato pagamento visibili;
- link `Dettaglio` verso `documentidettaglio.aspx?id=<id>`;
- link `Vedi tutti gli ordini` verso `documenti.aspx?t=4`;
- nessun Pay Now diretto;
- nessun link PayPal/BancaSella/gateway diretto;
- mobile `390x844`: OK;
- nessun errore server, MySql, Object reference o BC30002 nello smoke.

Stato area account stabilizzata per funzionalita principali:

- `documentidettaglio.aspx`: stabile con layout ONSUS e stato pagamento separato;
- `documenti.aspx`: stabile con layout ONSUS, AccountSidebar globale, selector documenti dinamico, filtri GET validati e azione solo Dettaglio;
- `myaccount.aspx`: stabile con dashboard ONSUS, profilo, indirizzi e ordini recenti;
- `my-account-edit.aspx`: stabile con profilo ONSUS, salvataggio campi contatto validato e AccountSidebar condivisa coerente.
- `wishlist.aspx`: stabile con AccountSidebar globale e nav inline legacy rimossa/non visibile nella fase 1 cleanup.
- `my-account-address.aspx`: stabile read-only ONSUS, con AccountSidebar globale e gestione indirizzi legacy rimandata.
- `password.aspx`: stabile come pagina canonica cambio password, dentro shell account con AccountSidebar globale.
- `cambiapassword.aspx`: legacy redirect controllato verso `password.aspx`.
- AccountSidebar condivisa validata.
- Cleanup sidebar fase 1 chiuso.
- Cleanup documenti fase 2 chiuso.
- Consolidamento password chiuso con hotfix.

Nota: questa stabilizzazione non equivale al cleanup completo di tutte le nav/sidebar inline legacy presenti nelle pagine account. Quel debito UI resta separato.

## 9. Stato Account Profile / my-account-edit.aspx

ACCOUNT-PROFILE-1B e chiuso.

Esiti principali:

- PR #100 merge commit: `f0eeccc12d701268641dc10950bb1253670f86fa`.
- PR #100 ha introdotto il profilo account ONSUS su `my-account-edit.aspx`.
- PR #101 merge commit: `7bfd40cb685e0500f427cf4a481516f70038d235`.
- PR #101 ha corretto i link root-level della sidebar account.
- PR #102 merge commit: `919b342bd0d0c9ff7b7bddc0453f99e4efe79fbc`.
- PR #102 ha corretto lo stato active/current della sidebar account.
- Smoke finale ACCOUNT-PROFILE-1B-T: A.
- Cleanup branch ACCOUNT-PROFILE-1B: completato.

Nota hardening ACCOUNT-PROFILE-1A:

- `my-account-edit.aspx` mantiene layout ONSUS e AccountSidebar invariati.
- Validazioni server-side rafforzate su email, contatti e campi indirizzo profilo.
- Messaggi utente non tecnici confermati; nessun `ex.Message` esposto.
- Query parametrizzate confermate.
- Update profilo vincolato a `LoginId` e `UtentiId` della sessione.
- `datiutente.aspx`, `my-account-address.aspx`, DB/schema, password/reset/remind e gateway non toccati.

Nota hotfix ACCOUNT-SMOKE-HOTFIX-1A:

- `datiutente.aspx?edit=1&tab=addr` gestito con binding legacy protetto e messaggi non tecnici.
- Newsletter footer/modal non blocca piu i submit account/password con validazione HTML5 globale.
- `password.aspx` usa messaggi professionali vicino al form e ValidationGroup dedicato.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota hotfix ACCOUNT-SMOKE-HOTFIX-1C:

- `datiutente.aspx?tab=addr` e `datiutente.aspx?edit=1&tab=addr` protetti dal caso `edit` assente in querystring.
- Submit newsletter footer gestito con evento dedicato e messaggi inline senza validazione HTML5 globale.
- Password/account verificati senza regressioni statiche.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-ADDRESS-1A:

- `my-account-address.aspx` diventa la pagina moderna ONSUS per gestione indirizzi account.
- Visualizza indirizzo principale da `utenti` e sedi alternative da `utentiindirizzi`.
- Evidenzia la sede alternativa predefinita e consente di impostarne una nuova.
- Update predefinito vincolato a `UtenteId` della sessione e transazione con massimo un `Predefinito=1` per utente.
- Carrello non modificato: legge gia `utentiindirizzi.Predefinito` e usa fallback/selezione indirizzo esistenti.
- Nessun DB/schema modificato e nessun SQL schema eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-ADDRESS-LOGIN-UX-1A:

- Rifinitura `my-account-address.aspx`: mantiene una sola `AccountSidebar`, rimuove le azioni duplicate in testata e forza wrapping locale dei valori lunghi nelle card indirizzo.
- `RagioneSociale` e `CognomeNome` dell'indirizzo principale sono esposti come campi distinti.
- `RagioneSocialeA` e `NomeA` delle sedi alternative sono esposti entrambi, senza fallback che nasconda uno dei due valori.
- `login.aspx` aggiunge solo il toggle client-side mostra/nascondi password; `login.aspx.vb` e il flusso auth restano invariati.
- Carrello non modificato: selezione manuale indirizzo e link "modifica indirizzo" restano da verificare/correggere in task separato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-ADDRESS-UX-1C:

- `my-account-address.aspx` viene rifinita come pagina moderna definitiva per gestione sedi alternative account.
- Causa menu sdoppiato: la pagina renderizzava una `AccountSidebar` locale mentre `Page.master` renderizza gia la sidebar globale dentro `.ks-account-shell`; la sidebar locale e stata rimossa.
- Causa valori tagliati: layout a colonne/card troppo stretto dentro la shell account e valori lunghi non sempre in campi full-width; la lista sedi alternative passa a card full-width con wrapping locale.
- L'indirizzo principale espone chiaramente `Ragione Sociale/Cognome` e `Nome`.
- Le sedi alternative espongono chiaramente `RagioneSocialeA` come `Ragione Sociale/Cognome` e `NomeA` come `Nome`.
- Il link operativo principale verso `datiutente.aspx?edit=1&tab=addr` viene rimosso dalla pagina moderna.
- Add/edit sedi alternative viene gestito direttamente in `my-account-address.aspx`, con form server-side, query parametrizzate e `UtenteId` risolto dalla sessione.
- Il salvataggio verifica sempre che l'id sede appartenga all'`UtenteId` corrente.
- La scelta `Imposta come predefinito` resta disponibile e preserva al massimo una sede alternativa predefinita per utente.
- Delete indirizzi non implementato in questa fase; da valutare solo con task dedicato.
- `datiutente.aspx` resta legacy e non viene modificata.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL schema eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-ADDRESS-UX-1E:

- Hotfix visuale post smoke live su `my-account-address.aspx`: i valori indirizzo passano da colonne Bootstrap strette a griglie locali elastiche con wrapping esplicito.
- Causa valori ancora tagliati: alcune righe usavano colonne troppo strette dentro la shell account (`col-md-*`/`col-lg-*`) e header flex con badge, quindi i valori lunghi risultavano compressi anche se wrappabili.
- Indirizzo principale: `Ragione Sociale/Cognome` e `Nome` restano etichette distinte e leggibili, con valori non troncati.
- Sedi alternative: `RagioneSocialeA` e `NomeA` restano etichette distinte e leggibili, con card coerenti fra sede predefinita e sedi successive.
- Nessuna modifica funzionale DB: add/edit, messaggi, badge predefinito e cambio predefinito restano invariati.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL schema eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-PROFILE-FISCAL-LABELS-1A:

- Hotfix visuale/testuale su `my-account-edit.aspx`, sezione "Dati fiscali / intestazione".
- Causa anomalia: i valori erano gia associati ai campi corretti (`RagioneSociale` e `CognomeNome`), ma le label "Ragione sociale" e "Nome / Cognome" non erano coerenti con la convenzione account validata.
- La label di `RagioneSociale` diventa `Ragione Sociale / Cognome`.
- La label di `CognomeNome` diventa `Nome`, mantenendo lo schema legacy senza concatenazioni o inversioni.
- PIVA e Codice Fiscale restano invariati e read-only.
- Nessuna modifica a indirizzi, carrello, login/reset/password flow.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-PROFILE-FISCAL-LABELS-1C:

- Hotfix testuale su `my-account-edit.aspx`, sezione "Dati fiscali / intestazione", dopo smoke live PR #143.
- Diagnosi: il valore sotto la label "Nome" arriva dal campo storico `CognomeNome`, popolato da `vlogin.cognomenome`; nella query locale non esiste un campo `Nome` separato.
- La label di `CognomeNome` diventa `Nome e Cognome`, senza split automatici, concatenazioni nuove o inversioni.
- La label `Ragione Sociale / Cognome` resta associata a `RagioneSociale`.
- PIVA e Codice Fiscale restano invariati e read-only.
- Nessuna modifica a indirizzi, carrello, login/reset/password flow.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun DB/schema modificato e nessun SQL eseguito.
- Nessun percorso legacy immagini introdotto.

Nota ACCOUNT-PROFILE-NAME-FIELD-1B:

- Rettifica funzionale post diagnosi schema: `utenti.Nome` non esiste nello schema versionato, quindi non viene inventato ne usato.
- Il campo reale per la label `Nome` resta lo storico `CognomeNome`, letto da `utenti.CognomeNome` con fallback compatibile su `vlogin.cognomenome`.
- `RagioneSociale` resta il campo per la label `Ragione Sociale / Cognome`.
- `my-account-edit.aspx` riallinea la label fiscale a `Nome`, lasciando PIVA e Codice Fiscale invariati e read-only.
- `myaccount.aspx` separa nel riquadro `Profilo` `Ragione Sociale / Cognome` e `Nome`, senza fallback che fonda i due valori.
- Nessuno split automatico, nessuna concatenazione nuova e nessuna inversione dei campi legacy.
- Nessuna modifica a DB/schema, nessun SQL di modifica, nessuna modifica indirizzi/carrello/login/reset/password.
- Carrello non modificato: resta follow-up dedicato `CART-ADDRESS-SELECTION-1A`.
- Nessun percorso legacy immagini introdotto.

Chiusura blocco ACCOUNT-PROFILE-ADDRESS-CLOSE-1A:

- Blocco account profilo/indirizzi chiuso dopo PR #136, #137, #138, #139, #140, #141, #142, #143, #144 e #145.
- Smoke live finale Germano su ACCOUNT-PROFILE-NAME-FIELD: login OK; `my-account-edit.aspx` OK; sezione "Dati fiscali / intestazione" OK; `Ragione Sociale / Cognome` da `RagioneSociale` OK; `Nome` da `CognomeNome` OK; PIVA/CF invariati e read-only OK; salvataggio profilo campo non critico OK; `myaccount.aspx` OK; riquadro `Profilo` con `Ragione Sociale / Cognome` e `Nome` OK; `my-account-address.aspx` senza regressioni visive; anomalie: no.
- `myaccount.aspx`: dashboard account stabile, quick links coerenti, sezione `Profilo` allineata con `RagioneSociale` e `CognomeNome` separati.
- `my-account-edit.aspx`: dettagli account stabili, validazioni server-side profilo consolidate, PIVA/CF read-only invariati, salvataggio profilo campo non critico verificato live.
- `my-account-address.aspx`: pagina moderna autonoma per indirizzi; indirizzo principale e sedi alternative visibili; add/edit sede alternativa funzionanti; scelta predefinito funzionante; reload mantiene il predefinito; massimo un predefinito; valori non tagliati; label `Ragione Sociale/Cognome` e `Nome` coerenti.
- `datiutente.aspx`: non e piu il percorso operativo principale per gestione indirizzi account, resta legacy/compatibilita e non crasha sui percorsi verificati.
- `login.aspx`: toggle mostra/nascondi password verificato, backend login non modificato.
- Newsletter/footer/password: fix precedenti non regrediti, password/account non bloccati dalla newsletter.
- Nessuna modifica DB/schema, nessun SQL eseguito, nessuna tabella creata.
- Nessun percorso legacy `Public/Images/` introdotto; per nuovi asset resta la regola `/Public/assets/images/...`.
- Prossimo blocco operativo: `CART-ADDRESS-SELECTION-1A`.

Comportamento finale area profilo:

- `myaccount.aspx`: dashboard stabile con riquadro `Profilo` separato tra `Ragione Sociale / Cognome` da `RagioneSociale` e `Nome` da `CognomeNome`.
- Click `Modifica dati`: porta a `my-account-edit.aspx`.
- `my-account-edit.aspx`: pagina profilo ONSUS visibile e coerente con area account.
- Sezioni presenti: dati accesso/profilo, dati fiscali read-only, contatti, indirizzo fatturazione.
- Sezione "Dati fiscali / intestazione": `Ragione Sociale / Cognome` da `RagioneSociale`, `Nome` da `CognomeNome`.
- Username read-only.
- Email con limite coerente a 50 caratteri.
- Campi opzionali `Telefono`, `Cellulare`, `Fax` svuotabili.
- Update `login.Email` ristretto al login corrente.
- Salvataggio, svuotamento e ripristino `Fax` validati.
- Pulsante `Annulla` validato.
- Mobile `390x844`: validato.

Sidebar condivisa AccountSidebar finale:

- Link root-level:
  - `/myaccount.aspx`
  - `/my-account-edit.aspx`
  - `/my-account-address.aspx`
  - `/documenti.aspx`
  - `/wishlist.aspx`
  - `/password.aspx`
  - `/logout.aspx`
- Nessun link `Public/ui/controls/...` nella sidebar condivisa `AccountSidebar`.
- Active/current della sidebar condivisa corretto con una sola voce `active` e un solo `aria-current="page"` per pagina.
- Validato su dashboard, dettagli account, indirizzi, ordini, wishlist e password.
- Non affermare che tutte le sidebar/nav inline legacy dell'area account siano gia state rimosse.

Smoke finale ACCOUNT-PROFILE-1B-T:

- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Nessun errore ASP.NET/MySQL/Object reference/500.
- Nessun gateway/carrello/checkout/ordine invocato.
- Password non modificata.
- Dati sensibili non esposti.

Follow-up password:

- `ACCOUNT-PASSWORD-AUDIT-1A`: chiuso.
- `ACCOUNT-PASSWORD-SECURITY-1B`: chiuso con PR #111.
- `ACCOUNT-PASSWORD-SECURITY-1I`: hotfix chiusa con PR #112.
- Hash/migrazione password non implementati: richiedono audit login/registrazione/reset password separato.

## 10. Stato Account Address / my-account-address.aspx

ACCOUNT-ADDRESS-1B e chiuso.

Esiti principali:

- PR #107 merge commit: `a4381b83ec5c617c6dc75022d30580ded5394f62`.
- Branch task: `task/account-address-1b-onsus-readonly`.
- Cleanup branch completato: branch locale e remoto rimossi.

File modificati da ACCOUNT-ADDRESS-1B:

- `Page.master.vb`
- `my-account-address.aspx`

File non modificati:

- `my-account-address.aspx.vb`
- `datiutente.aspx`
- `datiutente.aspx.vb`
- `datiutente-ui.js`
- `documenti.aspx`
- `password.aspx`
- `cambiapassword.aspx`
- `documentidettaglio.aspx`
- `web.config`
- markup `Page.master`
- DB/schema/dump SQL
- checkout/carrello/gateway/pagamenti
- asset ONSUS originali

Comportamento finale `my-account-address.aspx`:

- layout ONSUS/UX 2026 moderno e autonomo;
- `Page.master.vb` include `my-account-address.aspx` tra le pagine con `body.ks-page-account`;
- AccountSidebar globale visibile/usabile;
- voce `Indirizzi` active/current corretta;
- nav inline legacy `.myaccount-nav` rimossa/non visibile;
- nessuna doppia sidebar visibile;
- card indirizzo fatturazione presente;
- card contatti/destinazioni presente;
- sedi alternative visibili;
- add indirizzo funzionante;
- edit indirizzo funzionante;
- scelta predefinito funzionante;
- reload mantiene il predefinito;
- massimo un predefinito;
- valori non tagliati;
- label `Ragione Sociale/Cognome` e `Nome` coerenti;
- `datiutente.aspx` resta legacy/compatibilita, non percorso operativo principale per indirizzi account;
- delete indirizzi non implementato in questa fase, da valutare solo con task dedicato;
- nessuna modifica DB/schema e nessun SQL eseguito.

Smoke finale ACCOUNT-ADDRESS-1B-D:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Login PROVA OK.
- `my-account-address.aspx` desktop OK.
- `body.ks-page-account` presente.
- AccountSidebar visibile/usabile.
- `Indirizzi` active/current.
- `.myaccount-nav` assente/non visibile.
- Nessuna doppia sidebar visibile.
- Card indirizzo e card contatti/destinazioni presenti.
- Link legacy verificati senza salvataggi.
- Mobile `390x844` OK.
- Nessun errore ASP.NET/MySQL/Object reference/500.
- Nessun PayPal, BancaSella, gateway, carrello, checkout o ordine invocato.
- Password non modificata.
- Dati utente non modificati.
- Dati sensibili non esposti.

Debito residuo indirizzi:

- `datiutente.aspx` resta legacy con tab/JS e gestione destinazioni.
- Non e stata migrata la gestione add/edit/delete indirizzi.
- Le destinazioni alternative restano nel pannello legacy.
- Eventuale migrazione della gestione indirizzi richiede audit/task dedicato e autorizzazione Germano.

## 11. Debito UI residuo sidebar inline account

SIDEBAR-DOC-AUDIT-1A ha confermato che la nota Codex post DOCS-4 era reale/parziale. ACCOUNT-SIDEBAR-INLINE-CLEANUP fase 1 e chiuso, ma il cleanup completo di tutte le nav/sidebar inline legacy account non e ancora concluso.

- `Page.master` renderizza la sidebar condivisa `AccountSidebar` in `ks-account-aside`.
- `AccountSidebar` condivisa e corretta e validata:
  - link root-level OK;
  - active/current dinamico OK;
  - target password attuale: `/password.aspx`;
  - mapping legacy presente per `datiutente.aspx`, `documentidettaglio.aspx` e `cambiapassword.aspx`.
- Diverse pagine account contengono ancora nav/sidebar inline legacy nel `MainContent`, in particolare strutture tipo `myaccount-nav`.
- Alcune nav inline hanno `active` hardcoded.
- Alcune pagine contengono ancora link legacy verso `datiutente.aspx`.
- Impatto funzionale attuale: medio, non bloccante sul profilo, ma da non ignorare prima dei prossimi refactor account.

### Fase 1 cleanup sidebar inline account chiusa

ACCOUNT-SIDEBAR-INLINE-CLEANUP fase 1 e chiuso.

Esiti principali:

- PR #105 merge commit: `fbafc68ca36b2ba19a9d16d50af05313e3824209`.
- Branch task: `task/account-sidebar-inline-cleanup-1b-simple-pages`.
- Cleanup branch completato: branch locale e remoto rimossi.

Perimetro chiuso in fase 1:

- `Page.master.vb` abilita `body.ks-page-account` solo sulle tre pagine fase 1:
  - `myaccount.aspx`
  - `my-account-edit.aspx`
  - `wishlist.aspx`
- `AccountSidebar` globale ora e visibile/usabile sulle tre pagine.
- Nav inline legacy rimossa/non visibile su:
  - `myaccount.aspx`
  - `my-account-edit.aspx`
  - `wishlist.aspx`
- Active/current corretto sulle tre pagine.
- Nessuna doppia sidebar visibile.
- Layout desktop e mobile validato.

Smoke finale ACCOUNT-SIDEBAR-INLINE-CLEANUP-1F:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Desktop OK su `myaccount.aspx`, `my-account-edit.aspx`, `wishlist.aspx`.
- Mobile `390x844` OK sulle stesse tre pagine.
- Nessun errore ASP.NET/MySQL/Object reference/500.
- Nessun gateway/carrello/checkout/ordine invocato.
- Password non modificata.
- Dati profilo non modificati.
- Dati sensibili non esposti.

Pagine escluse dalla fase 1:

- `documenti.aspx`
- `password.aspx`
- `datiutente.aspx`
- `cambiapassword.aspx`
- `documentidettaglio.aspx`

### Fase 2 cleanup documenti chiusa

ACCOUNT-SIDEBAR-INLINE-CLEANUP-2B su `documenti.aspx` e chiuso.

Esiti principali:

- PR #109 merge commit: `7fe10f0edfbc7b7d5951116697c6654a100ba60f`.
- Branch task: `task/account-sidebar-inline-cleanup-2b-documenti`.
- Cleanup branch completato: branch locale e remoto rimossi.

Perimetro chiuso in fase 2:

- `Page.master.vb` abilita `body.ks-page-account` anche su `documenti.aspx`.
- AccountSidebar globale visibile/usabile su `documenti.aspx`.
- Voce Ordini/Documenti active/current corretta.
- Nav inline legacy `.myaccount-nav` rimossa/non visibile.
- Nessuna doppia sidebar visibile.
- Selector dinamico `sdsTipo` mantenuto/ripristinato.
- `asp:Repeater rTipo` mantenuto con `DataSourceID="sdsTipo"`.
- `LinkButton lbTipoDocumento` mantenuto con `tipoDocumento`, `tipoDocumentoClick` e `preRenderClick`.
- Hardcoding esclusivo `t=4/2/1` eliminato.
- Tipi documento extra non esclusi.
- Lista documenti invariata.
- Azione Dettaglio invariata.
- Nessun Pay Now/gateway diretto introdotto.
- `documenti.aspx.vb` invariato.

Smoke finale ACCOUNT-SIDEBAR-INLINE-CLEANUP-2H:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Desktop e mobile `390x844` OK.
- `t=4`, `t=2`, `t=1` verificati solo lista/read-only.
- `t=18` verificato con redirect sicuro a `t=4`, nessun errore.
- Tipi documento visibili da datasource: Preventivo, Ordine, D.D.T., Fattura Immediata, Fattura Differita, Nota di Credito.
- Nessun dettaglio ordine aperto.
- Nessun PayPal, BancaSella, gateway, carrello, checkout o ordine invocato.
- Password e dati utente non modificati.
- Dati sensibili non esposti.

### Consolidamento password account chiuso

ACCOUNT-PASSWORD-SECURITY-1B e chiuso. ACCOUNT-PASSWORD-SECURITY-1I hotfix e chiuso.

Esiti principali:

- PR #111 merge commit: `90c13d3bb41ff8d437f3cc9605a736659b04f4ce`.
- Branch task PR #111: `task/account-password-security-1b-canonical-flow`.
- Cleanup branch PR #111 completato: branch locale e remoto rimossi.
- PR #112 merge commit: `3d1873f5e3ea071ef187cc906f5d8712a58a09e6`.
- Branch task PR #112: `task/account-password-security-1i-confirm-hotfix`.
- Cleanup branch PR #112 completato: branch locale e remoto rimossi.

File modificati da ACCOUNT-PASSWORD-SECURITY-1B / PR #111:

- `Page.master.vb`
- `password.aspx`
- `password.aspx.vb`
- `cambiapassword.aspx`
- `cambiapassword.aspx.vb`
- `datiutente.aspx`

File modificati da ACCOUNT-PASSWORD-SECURITY-1I / PR #112:

- `password.aspx.vb`

File non modificati:

- `datiutente.aspx.vb`
- `datiutente-ui.js`
- `login.aspx`
- registrazione/reset password
- `web.config`
- markup `Page.master`
- DB/schema/dump SQL
- checkout/carrello/gateway/pagamenti
- pagine account stabilizzate non previste
- asset ONSUS originali

Comportamento finale password:

- `password.aspx` e la pagina canonica per cambio password account.
- `cambiapassword.aspx` e legacy redirect controllato verso `password.aspx`.
- I link "Cambia password" in `datiutente.aspx` puntano a `password.aspx`.
- Il redirect scadenza password in `Page.master.vb` punta a `password.aspx`.
- `password.aspx` e dentro la shell account con `body.ks-page-account`.
- AccountSidebar globale visibile/usabile su `password.aspx`.
- Voce Cambia password active/current corretta.
- Nav inline legacy `.myaccount-nav` rimossa/non visibile.
- Nessuna doppia sidebar visibile.
- Diagnostica tecnica legacy rimossa/disabilitata.
- Nessun `ex.Message`, stack, path, identity o dettaglio tecnico a schermo.
- Confronto vecchia password case-sensitive.
- Policy server-side:
  - minimo 8 caratteri;
  - massimo 25 caratteri;
  - conferma obbligatoria;
  - nuova password diversa dalla vecchia.
- Query parametrizzate.
- `DataPassword` aggiornata solo su cambio password valido e riuscito.
- Hash implementato: no.
- DB schema modificato: no.
- Login/registrazione/reset password non modificati.

Hotfix ACCOUNT-PASSWORD-SECURITY-1I:

- Smoke post-merge PR #111 aveva dato E sul caso conferma non coincidente.
- Problema rilevato: conferma non coincidente aggiornava la password.
- Hotfix PR #112 circoscritta a `password.aspx.vb`.
- Update DB centralizzato dopo validazioni.
- Conferma non coincidente gestita server-side.
- Guard SQL con confronto case-sensitive: `BINARY @newpwd = BINARY @confirmpwd`.
- Nessun update `Password` se:
  - vecchia password errata;
  - nuova password troppo corta;
  - conferma non coincidente;
  - nuova uguale alla vecchia.
- Nessun update `DataPassword` nei casi falliti.
- `DataPassword` aggiornata solo su successo.
- Diagnostica tecnica assente.
- Hash non implementato.
- DB schema non modificato.

Smoke finale ACCOUNT-PASSWORD-SECURITY-1L:

- Esito: A.
- Ambiente: `https://www.taikun.it/`.
- Utente test: PROVA, senza password nei report.
- Login iniziale PROVA OK.
- `password.aspx` loggato OK.
- `body.ks-page-account` presente.
- AccountSidebar visibile/usabile.
- Cambia password active/current.
- `.myaccount-nav` assente/non visibile.
- Nessuna doppia sidebar visibile.
- Negativo A, vecchia password errata: OK, nessun update inatteso.
- Negativo B, nuova password troppo corta: OK.
- Negativo C, conferma non coincidente: OK.
- Negativo D, nuova uguale alla vecchia: OK.
- Test positivo controllato: OK.
- Login finale PROVA riuscito.
- Password finale in stato noto conforme.
- Redirect loop assente.
- `cambiapassword.aspx` redirect controllato confermato.
- `datiutente.aspx`: errore generico legacy/preesistente, nessun salvataggio.
- Nessun errore server/browser bloccante.
- Nessun PayPal, BancaSella, gateway, carrello, checkout o ordine invocato.
- Nessun dettaglio ordine aperto.
- Dati profilo/indirizzi non modificati.
- Dati sensibili non esposti.

## 12. Stato Login / Registrazione / Reminder

LOGIN-REGISTER-SECURITY-1 e chiuso lato codice.

Esiti principali:

- PR #117 merged.
- Merge commit PR #117: `f51ab9a4df9afb71760a31db97ed0eac547cd9c3`.
- Branch task: `task/login-register-security-1b-no-schema`.
- Cleanup branch LOGIN-REGISTER-SECURITY-1I completato: branch locale e remoto rimossi.
- Smoke post-merge LOGIN-REGISTER-SECURITY-1H: A.

File modificati da PR #117:

- `Page.master.vb`
- `login.aspx.vb`
- `registrazione.aspx`
- `registrazione.aspx.vb`
- `registrazioneok.aspx`
- `remind.aspx`
- `remind.aspx.vb`

File esclusi/non modificati:

- `password.aspx`
- `password.aspx.vb`
- `cambiapassword.aspx`
- `cambiapassword.aspx.vb`
- `datiutente.aspx`
- `datiutente.aspx.vb`
- `web.config`
- markup `Page.master`
- DB/schema/dump SQL
- gateway/pagamenti
- carrello/checkout/ordini
- asset ONSUS originali

Mitigazioni applicate:

- Login enumeration ridotta con messaggio generico unico.
- Reminder trasformato in recupero assistito.
- Reminder non promette azioni non eseguite.
- Reminder non invia password esistente.
- Reminder non invia email reale.
- Reminder non fa enumeration.
- Registrazione non invia password in email.
- Password in URL rimossa/neutralizzata.
- Password in sessione rimossa/neutralizzata.
- Policy registrazione allineata a 8-25.
- Lowercase forzato password rimosso.
- Diagnostica tecnica rimossa.
- Hash implementato: no.
- DB schema modificato: no.
- `password.aspx` invariata/stabile.

Smoke post-merge LOGIN-REGISTER-SECURITY-1H:

- Ambiente: `https://www.taikun.it/`.
- Utente test PROVA: login OK, senza password nei report.
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

Stato finale area sicurezza/login:

- Cambio password canonico gia stabile su `password.aspx`.
- Login/registrazione/reminder ora mitigati senza hash.
- Reminder automatico password disabilitato e sostituito dal reset tokenizzato fase 1.
- Registrazione non espone password in email/URL/sessione.
- Hash migration ancora non implementata.
- Reset tokenizzato fase 1 operativo e validato live.

### Reset tokenizzato - progettazione DB chiusa

REMIND-RESET-DB-REVIEW-1 e chiuso a livello documentale/progettuale.

Esiti principali:

- PR #121 merged e chiusa.
- Merge commit PR #121: `f11cf0b434b9be111d470b995083edf9d18b481b`.
- Branch task PR #121: `task/remind-reset-db-review-1g-germano-feedback`.
- Cleanup branch PR #121 completato con esito A: branch locale e remoto rimossi.

File aggiornati da PR #121:

- `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md`
- `docs/REMIND_RESET_DB_MANUALE_VINCENZO.md`

Stato finale PR #121:

- Manuale Vincenzo aggiornato solo a livello progettuale.
- Blueprint aggiornato solo a livello progettuale.
- Feedback Germano integrato su gestionale, tabella `login`, `login.Password`, `login.DataPassword`, `aziende.ScadenzaPassword`, relazione `login.DataPassword + aziende.ScadenzaPassword`, strategia legacy-compatible, rollout multi-azienda e futura UI JANUS token reset.
- Nessun codice runtime modificato.
- Nessun DB modificato.
- Nessuna tabella `login_password_reset_tokens` creata.
- Nessuno script SQL eseguito.
- Nessun reset tokenizzato implementato.
- Nessun hash implementato.
- Nessun dato sensibile esposto.

Prossimo step consigliato:

- Preparare uno script DB idempotente e controllato per `login_password_reset_tokens`, senza eseguirlo, da verificare con Vincenzo prima di qualunque modifica DB.

### Reset tokenizzato - script DB preparato

REMIND-RESET-DB-SCRIPT-1A e avviato/preparato a livello documentale.

Esito previsto del task:

- Script SQL creato in `docs/db/login_password_reset_tokens.mysql.sql`.
- Script pensato per revisione Vincenzo ed esecuzione controllata sui singoli DB cliente/azienda.
- Script non eseguito.
- DB non modificato.
- Nessuna tabella `login_password_reset_tokens` creata da Codex.
- Nessuna modifica runtime login/registrazione/reminder/password.
- Nessuna modifica a `connessioni` o `city_registry`.

Prossimo step:

- Review/approvazione dello script SQL con Germano/Vincenzo prima di qualunque esecuzione DB o implementazione runtime.

### Reset tokenizzato - handoff Vincenzo preparato

REMIND-RESET-DB-HANDOFF-1A prepara la consegna operativa dello script DB a Vincenzo.

Stato:

- Manuale Vincenzo aggiornato con appendice operativa per `docs/db/login_password_reset_tokens.mysql.sql`.
- Script SQL gia versionato e non modificato da questo handoff.
- Script SQL non eseguito.
- DB non modificato.
- Nessuna tabella `login_password_reset_tokens` creata da Codex.
- Nessuna modifica runtime login/registrazione/reminder/password.
- Nessuna modifica a `connessioni` o `city_registry`.

Gate successivo:

- Germano approva la consegna operativa.
- Vincenzo approva ed eventualmente esegue lo script sul DB cliente/azienda corretto, dopo backup e verifica tecnica.
- Solo dopo conferma creazione tabella e verifica post-esecuzione si puo aprire il task runtime reset tokenizzato fase 1.

### Reset tokenizzato - gate DB taikun completato

REMIND-RESET-DB-GATE-1A registra l'esito comunicato da Germano per l'esecuzione manuale controllata su SQLyog Ultimate 64.

Esito DB `taikun`:

- Backup confermato.
- Tabella `login_password_reset_tokens` creata manualmente.
- `SHOW TABLES` OK.
- `SHOW CREATE TABLE` coerente.
- `COUNT(*) = 0` subito dopo la creazione.
- Nessuna anomalia comunicata.
- Nessun dato/token reale inserito.
- Runtime reset tokenizzato non era ancora implementato al momento del gate DB; fase 1 completata successivamente.
- Codex non ha eseguito SQL e non ha modificato DB.

Prossimo step:

- Implementazione runtime reset tokenizzato fase 1 su branch dedicato, senza hash e mantenendo i guardrail legacy gia documentati.

### Reset tokenizzato - runtime fase 1 avviato

REMIND-RESET-IMPLEMENT-1E avvia l'implementazione runtime legacy-compatible su branch dedicato.

Stato previsto:

- DB `taikun` gia predisposto con tabella `login_password_reset_tokens`.
- Reminder convertito a richiesta reset tokenizzata anti-enumeration.
- Nuova pagina reset password anonima con token monouso e scadenza 30 minuti.
- Reset riuscito aggiorna `login.Password` legacy e `login.DataPassword`.
- Hash password rimandato a task separato.
- Smoke runtime richiesti prima di merge.

### Reset tokenizzato - disambiguazione account

REMIND-RESET-IMPLEMENT-1I aggiorna il runtime PR #126 per rendere deterministico il reset in presenza di email duplicate.

- `remind.aspx` richiede email e Codice fiscale o Partita IVA.
- Il runtime usa email, CF/PIVA normalizzato e contesto URL/AziendaId quando determinabile.
- Il campo CF/PIVA e alternativo: il valore inserito puo corrispondere a `CodiceFiscale` oppure a `Piva`, senza richiedere entrambi.
- La ricerca viene de-duplicata per `LoginId`: piu righe `vlogin` dello stesso account contano come un solo candidato.
- Se la ricerca produce zero candidati non viene generato alcun token.
- Se la ricerca produce un solo candidato valido viene generato un solo token.
- Se la ricerca resta ambigua con candidati multipli distinti per `LoginId` non viene generato alcun token.
- Nessuna scelta arbitraria del primo record e nessuna email con link multipli.
- Nessun dato fiscale, azienda o tipo utente viene salvato nel token, inserito nel link o scritto nei log.
- Nessun DB schema modificato; PR #126 resta da smoke finale.

### Reset tokenizzato - UX reset password

REMIND-RESET-UX-1A aggiorna `resetpassword.aspx` sul ramo PR #126.

- Aggiunto toggle mostra/nascondi password sui campi nuova password e conferma nuova password.
- I campi restano mascherati di default.
- Il toggle e client-side, accessibile da tastiera e non invia submit accidentali.
- Nessuna password viene salvata in JavaScript globale, storage, cookie o log.
- Nessun DB/schema modificato e nessuna logica token/password server-side modificata.

### Reset tokenizzato - refresh sicuro remind

REMIND-RESET-POST-REFRESH-1A corregge `remind.aspx` con pattern POST/Redirect/GET.

- Dopo una richiesta reset processata, la pagina redirige a `remind.aspx?sent=1`.
- Il messaggio post-redirect resta generico e anti-enumeration.
- Refresh/F5 ricarica solo la GET e non reinvia il POST.
- Nessun dato email, fiscale o token viene salvato in querystring.
- Nessun DB/schema modificato e nessuna logica token/password server-side modificata.

REMIND-RESET-POST-REFRESH-1C rafforza il comportamento live di `remind.aspx` e migliora la qualita della comunicazione email reset.

- Il redirect post-submit usa una risposta 303 verso `remind.aspx?sent=1`, con `CompleteRequest()` e uscita immediata dal click handler.
- `sent=1` e gestito come GET di conferma generica e non genera token/email, anche in caso di POST artificiale verso la stessa querystring.
- Il template email reset e HTML professionale con versione testuale alternativa, CTA, fallback link, nota sicurezza e footer aziendale.
- Le avvertenze anti-phishing esplicite sono presenti in HTML e plain text: non condividere il link, nessuna richiesta password via email, nessuna password inclusa nella mail.
- I dati azienda per mittente/footer vengono letti dalla tabella reale `aziende` quando associabili all'account, con fallback alle sessioni legacy.
- Il token in chiaro resta solo nel link email; nessun token, hash, password, CF/PIVA o dato personale viene inserito nei log o nei documenti.
- Nessun DB/schema modificato e nessun hash implementato.

RESET-LOGIN-REDIRECT-1A corregge il redirect post-login dopo reset password.

- `resetpassword.aspx`, `remind.aspx` e URL contenenti token/reset/remind non sono destinazioni valide per `ReturnUrl` o `Pagina_visitata`.
- I redirect post-login accettano solo URL relative interne sicure e rifiutano URL assolute esterne.
- Se la destinazione non e sicura, il fallback post-login e `myaccount.aspx`.
- La master non salva piu pagine reset/remind come ultima pagina visitata e pulisce sessioni di redirect legacy non sicure.
- Nessun DB/schema modificato e nessun hash implementato.

REMIND-RESET-SENT-UX-1B migliora lo stato di conferma `remind.aspx?sent=1`.

- La GET `sent=1` mostra una card di conferma evidente in alto, subito sotto il titolo `Recupero accesso`.
- Il form email + CF/PIVA viene nascosto nello stato di conferma e i campi vengono puliti server-side.
- Loader, testi operativi e immagini loader non vengono renderizzati su GET normale o `sent=1`.
- Le azioni disponibili sono `Vai al login` e `Effettua una nuova richiesta`, con nuova richiesta verso `remind.aspx` pulito.
- Il messaggio resta generico e anti-enumeration.
- PRG/F5 invariato: la GET `sent=1` non genera token/email.
- Nessun DB/schema modificato.

### Reset tokenizzato - fase 1 chiusa

REMIND-RESET-FINAL-CLOSE-1B registra la chiusura funzionale e documentale del blocco reset password tokenizzato fase 1.

PR completate:

- PR #126 merged: implementazione reset password tokenizzato fase 1 legacy-compatible.
- PR #127 merged: primo hotfix POST/Redirect/GET su `remind.aspx`.
- PR #128 merged: PRG definitivo e email reset professionale con riferimenti aziendali e avvertenze anti-phishing.
- PR #130 merged: fix redirect post-login dopo reset.
- PR #132 merged: UX finale `remind.aspx?sent=1` con card conferma evidente, form non ambiguo e loader/testi operazione rimossi.
- PR #133 merged: chiusura documentale reset password tokenizzato fase 1.
- PR #134 merged: cleanup warning legacy `BC42024` in `remind.aspx.vb` con rimozione di codice email legacy disabilitato.

Smoke live finale Germano:

- Reset password via link email OK.
- Cambio password OK.
- Login con nuova password OK.
- Redirect post-login verso pagina sicura OK.
- Nessun ritorno a `resetpassword.aspx`.
- URL finale senza token.
- PRG/F5 `remind.aspx` OK.
- Nessuna seconda email su F5.
- Email reset professionale OK, con riferimenti aziendali e avvertenze anti-phishing.
- `remind.aspx?sent=1` mostra card conferma evidente.
- Form nascosto/non dominante su `sent=1`.
- Loader/testi `Operazione in corso` assenti.
- Nessuna immagine loader rotta.
- Nessuna anomalia finale comunicata.

Comportamento finale fase 1:

- Reset tokenizzato operativo e legacy-compatible.
- `remind.aspx` richiede email e Codice fiscale oppure Partita IVA.
- CF/PIVA sono alternativi, non cumulativi.
- La ricerca de-duplica per `LoginId`.
- Zero candidati o candidati multipli distinti: nessun token generato.
- Un candidato valido: un solo token generato.
- Token single-use con scadenza 30 minuti.
- Il DB salva solo `TokenHash`; il token chiaro resta solo nel link email.
- Reset riuscito aggiorna `login.Password` legacy e `login.DataPassword`.
- `aziende.ScadenzaPassword` invariato.
- Email reset professionale con riferimenti aziendali e avvertenze anti-phishing.
- `remind.aspx` usa PRG/F5 sicuro e lo stato `sent=1` ha UX chiara.
- `resetpassword.aspx` include toggle mostra/nascondi password client-side.
- Redirect post-login sanificato: `resetpassword.aspx`, `remind.aspx` e URL con token/reset/remind sono esclusi da `ReturnUrl` e redirect sessione.
- Fallback sicuro post-login: `myaccount.aspx`.
- Hash password non implementato; rimandato a task futuro.

Stato finale post-cleanup warning:

- Runtime reset tokenizzato chiuso.
- UX `remind.aspx?sent=1` chiusa.
- Redirect post-login sicuro chiuso.
- Email reset professionale chiusa.
- Documentazione finale chiusa.
- Cleanup warning legacy `remind.aspx.vb` chiuso.
- Reset behavior invariato.
- PRG/F5 invariato.
- Anti-enumeration invariata.
- Regola email + CF oppure email + PIVA invariata.
- Nessun vecchio invio password via email ripristinato.

### Debito residuo dopo consolidamento password

- Hash/migrazione password non implementati.
- Audit hash/login/registrazione/reset password da fare in task separato.
- Password legacy ancora in chiaro nel DB.
- Login usa ancora meccanismo legacy, non hash.
- Reminder fase 1 ora tokenizzato e legacy-compatible; hash migration non implementata.
- Tabella `login_password_reset_tokens` creata manualmente su DB `taikun`; rollout su eventuali altri DB cliente/azienda ancora da gestire separatamente.
- Script DB idempotente per `login_password_reset_tokens` preparato a livello repository e gia eseguito manualmente su `taikun` da Germano/Vincenzo, non da Codex.
- Registrazione va ulteriormente modernizzata lato UX e sicurezza.
- `AntiCsrfPage` non ancora applicato ai flussi auth.
- Hash/salt/versione algoritmo non presenti.
- Serve coordinamento con Vincenzo/gestionale prima di modifiche DB.
- Warning legacy di precompile in `remind.aspx.vb` chiusi da REMIND-CLEANUP-WARNINGS-1A con rimozione di codice email legacy disabilitato e import inutilizzati.
- Cleanup limitato a codice morto/variabili inutilizzate: nessuna modifica funzionale a reset tokenizzato, PRG/F5, anti-enumeration o regola email + CF/PIVA.
- Errori JS legacy su `registrazione.aspx` da valutare in task separato.
- `datiutente.aspx` resta legacy/compatibilita con tab/JS e gestione salvataggi/destinazioni non piu percorso operativo principale per indirizzi account.
- `my-account-address.aspx` e stabile come pagina moderna autonoma per indirizzi account; add/edit sedi alternative e scelta predefinito sono verificati live.
- Delete indirizzi resta da valutare solo con task dedicato.
- `CART-ADDRESS-SELECTION-1A` corregge il debito carrello indirizzi: la dropdown spedizione fa postback, la scelta manuale viene salvata in sessione per il flusso corrente, l'ID selezionato viene validato contro `UtenteId` e il rebind non deve piu sovrascrivere la scelta manuale con il predefinito.
- Il default carrello resta `utentiindirizzi.Predefinito = 1` quando presente, con fallback all'indirizzo principale `utenti` se non ci sono sedi alternative predefinite.
- Il riepilogo indirizzo spedizione viene aggiornato dalla scelta corrente; in caso di indirizzo non valido/non appartenente all'utente si torna al default sicuro con messaggio utente non tecnico.
- La modifica inline legacy indirizzo nel carrello viene stabilizzata sostituendo le azioni rotte con link sicuri a `my-account-address.aspx`; la gestione add/edit indirizzi resta nella pagina account moderna.
- Nessun gateway/pagamento, costo, totale, DB/schema o SQL viene modificato da `CART-ADDRESS-SELECTION-1A`.
- `CART-ADDRESS-SELECTION-1B` estende la stessa PR #147 con UX carrello piu vicina a ONSUS: riferimento a `Public/assets/keepstore/shop-cart.html` e `checkout.html`, card indirizzo selezionato piu chiara, badge predefinito/manuale, micro-copy locale di controllo CAP/citta/provincia, trust box sobrie e riepilogo piu rassicurante.
- Gli accorgimenti "AI-style" restano euristici locali: nessuna API esterna, nessun modello, nessun invio dati, nessuna modifica DB. Sono solo suggerimenti e micro-copy basati sui campi indirizzo gia presenti nella pagina.
- Anche nell'estensione UX restano invariati gateway, pagamenti, costi, sconti, IVA, totali e flusso ordine.
- `CART-ADDRESS-SELECTION-1D` corregge i residui emersi nello smoke live post-merge: stato selezione indirizzo reso visibile anche accanto alla dropdown, link gestione indirizzi reso diretto verso `/my-account-address.aspx`, pannello legacy inline destinazione escluso dal rendering della pagina carrello.
- Il follow-up 1D resta confinato a UI/UX carrello e documentazione: nessuna modifica a gateway/pagamenti, costi, totali, DB/schema, SQL o flussi account gia chiusi.
- PR #148 e mergiata con merge commit `7558e7dbd8a3221425d5b9bc432fcf272c45625e`; cleanup branch `task/cart-address-selection-1d` completato.
- Smoke live `CART-ADDRESS-SELECTION-1F` conferma carrello moderno, badge predefinito, scelta indirizzo diverso, riepilogo aggiornato, link gestione indirizzi e pannello legacy non raggiungibile; nessun gateway avviato nello smoke base.
- `CART-INLINE-ADDRESS-PAYPAL-RETURN-1A` introduce il passo successivo: add/edit indirizzi alternativi inline nel carrello, link area account solo secondario, euristiche locali di qualita indirizzo, audit statico del ritorno PayPal post-pagamento e continuita chat nel masterplan.
- Diagnosi PayPal del task 1A: il CTA problematico "Torna indietro" e nel nostro `documentidettaglio.aspx` come `javascript:history.back()`; non appartiene al gateway PayPal. Va sostituito con destinazioni sicure senza modificare credenziali, importi, cattura pagamento o stato gateway.
- `CART-INLINE-ADDRESS-PAYPAL-RETURN-1A` non modifica DB/schema/SQL, gateway core, importi gateway, calcoli prezzi, sconti, spedizione, IVA o totali documento.
- `CART-INLINE-ADDRESS-CITYREGISTRY-STEP-1A` si e fermato con Esito B per assenza dello schema completo del DB separato `city_registry` nel dump locale `Database Taikun/KeepStore.sql`; nessun codice e stato modificato in quel passaggio.
- `CART-INLINE-ADDRESS-CITYREGISTRY-STEP-1B` riprende con schema reale `city_registry` fornito da dump separato e verificato in sola lettura: tabelle `cities`, `postcode_codes`, `provinces`, `countries` e campi CAP/citta/provincia richiesti risultano disponibili alla connessione applicativa.
- Il carrello ora usa lookup server-side parametrizzato su `city_registry.postcode_codes`, `city_registry.cities` e `city_registry.provinces` per guidare CAP -> citta/provincia nel form add/edit indirizzo inline; citta e provincia restano non editabili manualmente quando risolte dal CAP.
- Se un CAP corrisponde a piu citta, il form mostra una dropdown e il salvataggio richiede una scelta coerente; se il CAP non e riconosciuto, il salvataggio viene bloccato con messaggio utente non tecnico.
- Durante add/edit indirizzo inline, le azioni non pertinenti del carrello/checkout vengono bloccate lato UI e lato server finche l'utente salva o annulla.
- Il checkout carrello introduce un vero step finale `Conferma`: il pulsante nella fase spedizione/pagamento porta prima al riepilogo finale, mentre l'avvio del flusso ordine/gateway resta consentito solo dal pulsante finale nello step `Conferma`.
- `CART-INLINE-ADDRESS-CITYREGISTRY-STEP-1B` non modifica DB/schema/SQL, gateway core, importi gateway, calcoli prezzi, sconti, spedizione, IVA, totali documento, login/reset/password o area account chiusa.
- PR #149 e mergiata con merge commit `05a43e54821af795ce897f50465405a7cae21bea`; PR #150 e mergiata con merge commit `b41cc367366fd0a2cfb470edc9afb259cbde2c71`.
- `CART-ADDRESS-SELECTION`, `CART-INLINE-ADDRESS-PAYPAL-RETURN` e `CART-INLINE-ADDRESS-CITYREGISTRY-STEP` sono chiusi come blocco unico carrello/indirizzi/CAP/step `Conferma`.
- Smoke live `CART-INLINE-ADDRESS-CITYREGISTRY-STEP-1D` completato con esito A: login OK, carrello aperto, layout ONSUS stabile, indirizzo predefinito e indirizzo manuale selezionabili, riepilogo aggiornato, add/edit inline funzionanti, CAP con lookup `city_registry`, multi-citta gestita, citta/provincia bloccate quando il CAP e riconosciuto, azioni bloccate durante edit, step `Conferma` attivo, gateway avviabile solo dal pulsante finale, nessuna anomalia rilevata.
- `documentidettaglio.aspx` non usa piu `history.back()` per il CTA post-pagamento coinvolto dal blocco: le CTA post-PayPal/post-documento restano su destinazioni sicure.
- Durante tutto il blocco non sono stati modificati gateway PayPal/BancaSella, core checkout, costi, sconti, spedizione, IVA, totali documento, DB/schema, SQL, login/reset/password o area account gia chiusa.
- Stato finale carrello/checkout: `carrello.aspx` stabile per UI carrello, selezione indirizzi, add/edit inline e step `Conferma`; il core pagamenti/gateway resta separato e va trattato solo con task dedicati.
- Non riaprire il blocco carrello/indirizzi/CAP/step `Conferma` salvo bug live verificato.
- `ORDER-CONFIRMATION-UX-1A` modernizza `documentidettaglio.aspx` come pagina post-acquisto/dettaglio ordine compatibile: hero stile e-commerce ONSUS/Taikun, messaggio "Grazie per il tuo ordine" solo nel contesto post-conferma o rientro pagamento, dati ordine principali, stampa ordine, copia numero ordine, CTA sicure, card pagamento/spedizione/fatturazione/riepilogo/prossimi passi/supporto e timeline locale.
- Il riferimento UX fornito da Germano viene usato solo come ispirazione generica post-acquisto: nessun brand/testo/asset dello screenshot, nessuna immagine esterna, nessuna API AI o tracking esterno introdotto.
- File coinvolti da `ORDER-CONFIRMATION-UX-1A`: `documentidettaglio.aspx`, `documentidettaglio.aspx.vb`, `Public/assets/keepstore/css/order-ui.css`, `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`, `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md`.
- `ORDER-CONFIRMATION-UX-1A` non modifica gateway core PayPal/BancaSella/IwBank, credenziali, endpoint, autorizzazione/cattura, importi inviati ai gateway, calcolo prezzi, sconti, spedizione, IVA, totale documento, generazione ordine/documento, DB/schema o SQL.
- PR #152 e mergiata con merge commit `c0896bfe40c40cc88aabd6944e309a738e37156f`; smoke live post-merge resta da eseguire senza pagamento reale.
- `CART-SESSION-TIMEOUT-1A` registra una anomalia live su `carrello.aspx`: se una sessione utente scade mentre la pagina resta aperta, un refresh/F5 puo portare a pagina bianca o stato incoerente prima dei binding del carrello/checkout.
- Fix previsto in `CART-SESSION-TIMEOUT-1A`: guard server-side iniziale su sessione ASP.NET ricreata da cookie scaduto, redirect sicuro a `login.aspx?ReturnUrl=carrello.aspx&sessionExpired=1`, messaggio utente non tecnico su login e blocco degli eventi sensibili del carrello quando la sessione e scaduta.
- `CART-SESSION-TIMEOUT-1A` non modifica gateway core, PayPal/BancaSella, importi gateway, calcolo prezzi, sconti, spedizione, IVA, totali documento, generazione ordine/documento, DB/schema o SQL.
- Smoke live richiesto dopo eventuale merge: carrello con sessione valida, simulazione o attesa timeout, F5 senza pagina bianca, redirect/messaggio sessione scaduta, login con ritorno al carrello se previsto, nessun gateway avviato.
- PR #153 e mergiata con merge commit `5a0e2565fa94b3ab8705842c3e10359d381f46e6`; cleanup branch `task/cart-session-timeout-1a` completato. Lo smoke live mirato session timeout resta da eseguire da Germano senza pagamento reale.
- Smoke live `CART-SESSION-TIMEOUT-1C` completato con esito A: sessione valida OK, sessione scaduta + F5 senza pagina bianca, redirect controllato a login con messaggio chiaro e `ReturnUrl`, rientro al carrello funzionante, postback protetti, add/edit indirizzo, CAP/`city_registry`, step `Conferma` e `documentidettaglio.aspx` verificati; nessun gateway, pagamento, ordine o dato sensibile coinvolto.
- `CART-UX-SUMMARY-STEPPER-TIMEOUT-1A` risolve le anomalie residue del carrello: un solo riepilogo visibile `Riepilogo ordine`, riepilogo tecnico legacy mantenuto solo per le label server-side, stepper superiore navigabile in modo coerente tra `Carrello`, `Spedizione e checkout` e `Conferma` senza avviare gateway, timeout sessione standardizzato a 30 minuti in `web.config` e in `carrello.aspx.vb`.
- Il task resta confinato a UX carrello, gestione sessione e documentazione: nessuna modifica a gateway PayPal/BancaSella, core checkout, costi, sconti, spedizione, IVA, totali documento, generazione ordine/documento, DB/schema, SQL, login/reset/password o area account gia chiusa.
- Smoke live `CART-UX-SUMMARY-STEPPER-TIMEOUT-1C = B`: carrello/riepilogo, stepper normale, timeout/sessionExpired, add/edit indirizzo, CAP/`city_registry` e `documentidettaglio.aspx` risultano OK; resta da correggere il lock coerente durante add/edit indirizzo, per impedire stepper e azioni carrello/checkout finche l'utente salva o annulla.
- `CART-ADD-EDIT-LOCK-1A` registra il follow-up mirato: durante add/edit indirizzo inline il checkout entra in stato lock, con UI disabilitata e guard server-side centralizzata su stepper, procedi ordine, conferma/gateway, righe carrello, coupon, cambio indirizzo, spedizione e pagamento.
- Lo stesso task corregge il logo header desktop/mobile: sorgente `Aziende.LogoWeb`, path pubblico `/Public/assets/images/logo/{LogoWeb}`, nome file sanificato, fallback interno `logo.svg` nella stessa cartella e nessun path legacy `Public/Images/`.
- `FOOTER-LOGOWEB-1A` completa la standardizzazione logo iniziata con PR #156: anche il footer usa `Aziende.LogoWeb`, path `/Public/assets/images/logo/{LogoWeb}`, nome file sanificato e fallback interno controllato; nessun carrello, gateway, totale, DB/schema o SQL modificato.
- Smoke live `CART-LOGO-LOCK-FINAL-1C = B`: logo header/footer OK, carrello normale OK, stepper/procedi/gateway lock OK, CAP/sessione OK; residua solo anomalia dei controlli quantita `+/-` che cambiano valore a video durante add/edit indirizzo.
- `CART-ADD-EDIT-QTY-LOCK-1A` corregge il residuo: durante add/edit indirizzo anche il quantity stepper `+/-` e l'input quantita sono inibiti lato UI, mentre il guard server-side continua a bloccare ogni update riga.
- Anomalia live `ACCESS-DENIED-PAGE-404`: richiesta `/accessonegato.aspx` restituisce 404 ASP.NET "Impossibile trovare la risorsa" invece di una pagina utente coerente. La causa locale e una pagina legacy non canonica rispetto al code-behind esistente e al deploy live; `ACCESS-DENIED-PAGE-1A` ripristina una pagina runtime mirata per accesso negato/sessione non valida, senza modificare carrello, logo, gateway, totali, DB/schema o web.config.
- Smoke live `CART-ADD-EDIT-QTY-LOCK-1C = A`: carrello normale, quantity `+/-`, pulsante Aggiorna, riepilogo unico `Riepilogo ordine`, add/edit indirizzo, microcopy, lock stepper/procedi/aggiorna, blocco click `+/-` e input quantita durante add/edit, ripristino con Annulla/Salva, CAP/`city_registry`, session timeout + F5 e `documentidettaglio.aspx` tutti OK. Step `Conferma` non avvia gateway da solo, gateway solo da pulsante finale Conferma; logo header desktop, header mobile e footer OK; nessun 404 logo, errore 500, stack trace, loop redirect o pagamento reale.
- Smoke live `ACCESS-DENIED-PAGE-1C = A`: `/accessonegato.aspx` apre correttamente, non mostra piu il 404 ASP.NET, usa layout sito, titolo `Accesso non consentito` o equivalente, messaggio non tecnico, CTA `Accedi` verso `login.aspx`, CTA home verso `Default.aspx`/home, nessun loop redirect, `ReturnUrl=carrello.aspx` gestito con pagina richiesta locale, `ReturnUrl` esterno non produce redirect esterno, nessun open redirect evidente, homepage/carrello/documentidettaglio e logo header/footer OK.
- Blocco carrello/session timeout/riepilogo/stepper/add-edit/quantity lock/logo/accessonegato chiuso live su HEAD stabile `a23f2a6153b57048769dd5b2a6153f2d13ced445`.
- Gli smoke finali non hanno modificato gateway, PayPal/BancaSella, totali, costi, spedizione, IVA, sconti, DB/schema, SQL, `web.config` o sistema email runtime.
- `EMAIL-ENGINE-1A` e il prossimo blocco operativo consigliato.
- `EMAIL-SYSTEM-AUDIT-1A` apre il blocco e-mail transazionali Taikun/KeepStore, solo documentale e senza runtime: audit invii esistenti, fonti DB ordine/pagamento/spedizione/logo, benchmark sintetico fornitori, standard template e roadmap micro-task futuri.
- Manuale creato: `docs/KEEPSTORE_EMAIL_STANDARD.md`. Contiene mappa invii attuali, dati DB reali, standard HTML/plain text, varianti bonifico/contrassegno/PayPal/carta/Banca Sella, oggetti consigliati e roadmap `EMAIL-ENGINE`, `EMAIL-ORDER-CONFIRMATION`, `EMAIL-BANKTRANSFER`, `EMAIL-COD`, `EMAIL-ORDER-STATUS`, `EMAIL-AUTH`, preview/test e deliverability.
- Benchmark sintetico recepito: email chiare su stato pagamento, importi, causale bonifico, pagamento alla consegna, CTA sicure, riepilogo ordine completo, layout table-based 600/640 px, logo azienda da DB e nessun asset esterno/legacy.
- Audit iniziale conferma che la conferma ordine parte da `ordine.aspx.vb`, il reset password tokenizzato da `App_Code/PasswordResetTokenService.vb`, registrazione/profilo da `registrazione.aspx.vb`; cambio password, reset completato, cambio stato ordine e tracking/spedizione non risultano inviati dal runtime web auditato.
- `documenti.aspx` inserisce richieste in `inviadocumenti`; invio reale documento/fattura/proforma da gestionale/processo esterno resta da confermare con Vincenzo.
- Nessun codice runtime, CSS, DB/schema, SQL, gateway, carrello/checkout, login/reset/registrazione o template applicativo viene modificato da `EMAIL-SYSTEM-AUDIT-1A`.
- `EMAIL-ENGINE-1A` introduce la fondazione runtime `App_Code/KeepStoreEmailTemplate.vb`: renderer HTML table-based + plain text, logo da `Aziende.LogoWeb` con path `/Public/assets/images/logo/{LogoWeb}` e fallback interno `logo.svg`, subject helper e microcopy pagamento/spedizione.
- Primo invio runtime migrato: NON MIGRATO. Gli invii legacy in `ordine.aspx.vb`, `registrazione.aspx.vb` e `App_Code/PasswordResetTokenService.vb` restano invariati in questo task.
- `EMAIL-ENGINE-1A` non modifica SMTP, `web.config`, appSettings, connection string, DB/schema, SQL, gateway, carrello/checkout, calcolo importi/totali/costi, login/reset/registrazione runtime o sistema email runtime esistente.
- Prossimo passo consigliato dopo merge/verifica di `EMAIL-ENGINE-1A`: `EMAIL-ORDER-CONFIRMATION-1A`, migrazione controllata della sola conferma ordine usando il renderer condiviso, senza modificare gateway o totali.
- `LOCAL-ASSET-UNTRACKED-CLEANUP-1A = B`: dopo merge `EMAIL-ENGINE-1B` la working tree locale era sporca solo per asset non tracciati sotto `Public/assets/images/...`; 684 asset non referenziati sono stati spostati in quarantena fuori repository in `C:\KeepStoreWeb\_untracked_assets_quarantine\20260609-2352`, con manifest dedicato, senza cancellare file tracciati e senza commit.
- `REFERENCED-ASSETS-DECISION-1A`: i 22 asset rimasti sono stati versionati perche referenziati da runtime attivo o template inclusi nel repository (`coupon*.aspx`, `carrello.aspx`, `documenti.aspx.vb`, `SiteHeader.ascx.vb`, template mailing/eBay legacy). Gli ulteriori 78 asset locali extra non referenziati, ricomparsi fuori dal perimetro dei 22, sono stati spostati in quarantena separata `C:\KeepStoreWeb\_untracked_assets_quarantine\referenced-assets-extra-20260610-0007`.
- Stato atteso dopo `REFERENCED-ASSETS-DECISION-1A`: working tree pulita, nessun codice runtime modificato, nessun DB/schema/SQL, gateway, carrello, email engine, `web.config`, header/footer/logo o `Page.master` modificati. Prossimo task operativo resta `EMAIL-ORDER-CONFIRMATION-1A`.
- `EMAIL-ORDER-CONFIRMATION-1A` parte da base HEAD `78acd2585c9135f30054b633bac9ec6ea6aaae7f` e migra la sola email conferma ordine/preventivo in `ordine.aspx.vb` al renderer standard `App_Code/KeepStoreEmailTemplate.vb`.
- Trigger, timing, destinatario cliente, BCC azienda, mittente, SMTP, credenziali SMTP e condizioni di invio restano invariati; non vengono introdotti invii duplicati o anticipati.
- Il subject usa gli helper standard: conferma ordine generica oppure variante bonifico quando il metodo pagamento esistente indica bonifico. Il vecchio body HTML resta come fallback se il renderer fallisce.
- Il nuovo body usa HTML table-based e plain text, logo aziendale da `Aziende.LogoWeb` tramite sessione azienda gia popolata, riepilogo documento, cliente/indirizzi gia disponibili, righe, importi gia calcolati, pagamento, spedizione e CTA sicura al dettaglio documento.
- Le varianti pagamento supportate usano microcopy standard per bonifico, PayPal/carta/online, contrassegno e pagamento generico; non viene dichiarato pagamento ricevuto senza conferma gia presente nel flusso.
- `EMAIL-ORDER-CONFIRMATION-1A` non modifica gateway PayPal/BancaSella, carrello/checkout, importi, costi, IVA, spedizione, sconti, generazione ordine/documento, DB/schema, SQL, `web.config`, connection string, appSettings o impostazioni SMTP.
- Prossimo task: `EMAIL-ORDER-CONFIRMATION-1B` review/merge PR.
- `EMAIL-ORDER-CONFIRMATION-1C = B`: smoke live parziale su ordine test/preventivo con bonifico ha confermato e-mail ricevuta e subject coerente, ma il sorgente MIME risultava errato: HTML dentro una parte `text/plain` e plain text separato.
- `EMAIL-ORDER-CONFIRMATION-MIME-1A` corregge solo MIME/AlternateViews della conferma ordine/preventivo: plain text come `text/plain; charset=utf-8`, HTML come `text/html; charset=utf-8`, senza modificare trigger, destinatario, subject, SMTP, ordine, gateway, totali, DB/schema o `web.config`.
- Backlog futuro: `EMAIL-LEGACY-SENDS-CLEANUP-1A` per mappare e bonificare i vecchi invii e-mail legacy dopo stabilizzazione dei nuovi flussi ordine/registrazione/reset, senza rimuovere codice legacy in task MIME.
- `EMAIL-ORDER-CONFIRMATION-MIME-1C = B`: nuovo smoke live conferma MIME corretto, `text/plain` e `text/html` OK, caratteri italiani/euro OK, ordine/preventivo creato, email ricevuta una sola volta, righe/quantita/importi/pagamento bonifico OK e nessuna falsa dichiarazione di pagamento ricevuto. Restano da rifinire subject con numero/data, data ordine nel corpo, logo email non visibile, CTA `Visualizza ordine` che passa da typo `/accesonegato.aspx` e layout email da arricchire.
- `EMAIL-ORDER-CONFIRMATION-POLISH-1A` rifinisce solo subject/data/logo/CTA/layout della conferma ordine: logo email multi-azienda da `Aziende.LogoWeb` con URL assoluto HTTPS, CTA protetta via `login.aspx?ReturnUrl=...`, correzione typo `accesonegato.aspx`, hero/blocchi riepilogo/prossimi passi piu ricchi e data ordine pulita. Trigger, destinatario, mittente, SMTP, ordine, gateway, totali, DB/schema e `web.config` restano invariati.
- Backlog `EMAIL-LEGACY-SENDS-CLEANUP-1A` confermato: mappare e bonificare vecchi invii ordine/registrazione/reset solo dopo stabilizzazione dei nuovi flussi basati su `KeepStoreEmailTemplate`.
- `EMAIL-ORDER-CONFIRMATION-POLISH-1C = A`: smoke funzionale OK su ordine test bonifico, email ricevuta con MIME corretto, subject/logo/CTA/layout migliorati; nessun pagamento reale, gateway o cliente reale coinvolto.
- `EMAIL-ORDER-CONFIRMATION-PRO-1A` completa la rifinitura professionale della conferma ordine: causale bonifico `Pagamento ordine n. ... del ...`, foto prodotto ottimizzata con `_nomefile` se disponibile sotto asset pubblici moderni, tabella prodotti con codice/EAN/descrizione/quantita/prezzo unitario/totale riga, footer azienda da `Aziende`, vettori deduplicati da `vettori.Descrizione`/`vettori.Informazioni`, prezzi prodotto coerenti con flag IVA cliente e nota IVA spostata fuori dal blocco importi.
- Scope invariato per `EMAIL-ORDER-CONFIRMATION-PRO-1A`: trigger, destinatario, mittente, BCC, SMTP, ordine/documento, gateway, PayPal/BancaSella, importi/totali/costi/IVA reali, DB/schema, SQL e `web.config` non vengono modificati.
- Backlog `EMAIL-LEGACY-SENDS-CLEANUP-1A` resta aperto: mappare successivamente vecchi invii dopo ordine e registrazione nuovo cliente, poi disattivarli/rimuoverli solo quando il nuovo sistema email e stabile.
- `EMAIL-ORDER-CONFIRMATION-PRO-1C = B`: smoke live su ordine test 190 ha confermato email ricevuta, MIME corretto, subject corretto, causale bonifico corretta, tabella prodotti presente, importi coerenti, footer aziendale, CTA funzionante e vettore deduplicato; restano anomalie di rifinitura su copy CTA, nota legale documento vendita, font/leggibilita, riepilogo ordine e foto mancanti per le prime due righe prodotto.
- `EMAIL-ORDER-CONFIRMATION-FINAL-POLISH-1A` interviene solo su `ordine.aspx.vb`, `App_Code/KeepStoreEmailTemplate.vb` e documentazione per CTA copy, nota legale, tipografia email-safe, riepilogo ordine piu leggibile e risoluzione foto prodotto piu robusta con candidati `Img1..Img6` da articolo.
- Scope invariato per `EMAIL-ORDER-CONFIRMATION-FINAL-POLISH-1A`: nessun gateway, PayPal/BancaSella, carrello/checkout, totali/costi/IVA/spedizione/sconti reali, generazione/stato ordine-documento, DB/schema, SQL, `web.config`, SMTP, header/footer/logo sito o vecchi invii email rimossi.
- `EMAIL-ORDER-CONFIRMATION-FINAL-POLISH-1C = B`: smoke live su ordine test 192 ha confermato email complessivamente rifinita, ma le prime due righe prodotto risultavano ancora senza foto mentre una terza riga mostrava correttamente immagine assoluta HTTPS da `/Public/assets/images/articoli/`; il renderer email era corretto, la risoluzione candidati immagine restava incompleta.
- `EMAIL-ORDER-CONFIRMATION-PRODUCT-IMAGES-1A` corregge solo la risoluzione foto prodotto della conferma ordine: candidati da `vdocumentirighe.Img1`, immagini variante tramite `articoli_tagliecolori.immaginiId` / `immagini.Immagine1..Immagine6`, poi `articoli.Img1..Img6`; priorita alla versione compressa `_nomefile`, fallback al nome originale, nome file sanificato e segmento URL encodato, nessun codice prodotto hardcoded, nessun base64/allegato/path legacy.
- Scope invariato per `EMAIL-ORDER-CONFIRMATION-PRODUCT-IMAGES-1A`: nessun gateway, PayPal/BancaSella, carrello/checkout, totali/costi/IVA/spedizione/sconti reali, generazione/stato ordine-documento, DB/schema, SQL, `web.config`, SMTP, header/footer/logo sito, layout generale email o vecchi invii email rimossi.
- `EMAIL-ORDER-CONFIRMATION-ARUBA-COMPAT-1A` registra anomalia live su ordine test 197: Hotmail/Outlook legge correttamente la conferma ordine, mentre Aruba Webmail comprime la tabella prodotti e spezza verticalmente le intestazioni perche il layout usa troppe colonne affiancate; anche il riepilogo superiore rischia compressione.
- Fix previsto: sostituire la tabella prodotti a 7 colonne con product card email-safe table-based, foto fissa e dettagli label/value; rendere il riepilogo superiore e il riepilogo ordine label/value verticali. Scope invariato: nessun SMTP, MIME, subject, causale bonifico, gateway, DB/schema, checkout/sessione, query immagini, prezzi, IVA, spedizione o totali modificati.
- `ORDER-NOTES-LIMIT-1A` registra anomalia live durante invio ordine: note checkout troppo lunghe causano errore tecnico DB `Data too long for column 'pNoteSpedizione' at row 1`. PR #173 su branch `task/order-notes-limit-1a`, commit iniziale `8d7fdc34293e6797cbe97751bf0d669ccf37e490`, merged e confermata post-smoke. Fonte DB verificata: stored procedure `carrello_Documento`, parametro `pNoteSpedizione VARCHAR(255)`, salvato in `documenti.NoteEsterne` senza modifica schema. Fix implementato: limite UI 255 caratteri su `txtNoteSpedizione` in `carrello.aspx`, contatore/hint, validazione server-side in `carrello.aspx.vb` prima della creazione ordine e guard difensivo in `ordine.aspx.vb` prima di stored procedure, email e gateway. Smoke `CART-CHECKOUT-SMOKE-1D = A`: incolla oltre limite bloccato/limitato a 255, contatore `255 / 255`, nessun errore tecnico; nessun troncamento silenzioso. Scope invariato: nessuna modifica DB/schema, gateway, prezzi, IVA, SMTP o template email.
- REV1 documentale PR #173 registrata con commit `d64961b1fe04f4a539d5605e3a34ddf27eedab19`: integrazione documentale dopo review bloccata; PR tecnicamente conforme, documentazione integrata e pronta per nuova review/merge `ORDER-NOTES-LIMIT-1B`, poi smoke manuale note ordine.
- Checkbox consenso condizioni: PR #169 storica non mergiata e sostituita da PR #174; PR #169 va chiusa come superseded e non mergiata.
- `CART-TERMS-CONSENT-1B` / PR #174 su branch `task/cart-terms-consent-1b`, commit funzionale `3b20195aca524c06cd13e7f4a88cac84af96dc8e`, merge commit `e837206c2c31e1ab7e9282f0a6bbe5aa3a4effd0`: sostituisce PR #169 non recuperata per conflitti con PR #173 su `carrello.aspx` / `carrello.aspx.vb` e per asset CSS/JS fuori scope. Regola: consenso condizioni vendita obbligatorio prima di creare ordine, gateway o email; preservato fix PR #173 limite note ordine 255, contatore/hint, validazione server-side e guard difensiva. Smoke `CART-CHECKOUT-SMOKE-1D = A`: checkbox visibile, testo corretto, link `condizioni-vendita.aspx` OK, pagina condizioni leggibile, blocco UI senza consenso OK, nessun ordine/gateway/email senza consenso, carrello preservato, con consenso pulsante/flusso abilitato senza completare ordine, nessun errore tecnico o JS console. Prossimo step: cleanup sicuro branch gia mergiati, poi valutare PR #171 diagnostica sessione post-ordine solo se il problema logout/sessione e ancora riproducibile.
- Checkout note ordine + consenso condizioni e chiuso con smoke A: PR #173 e PR #174 sono merged e validate live; PR #169 chiusa come superseded. Test manuale sessione/logout post-ordine: esito A, problema non riproducibile ora; PR #171 resta backlog non attivo e non va ripresa finche il problema non torna riproducibile.
- Backlog `EMAIL-HOTMAIL-DELIVERY-DELAY-1A`: non modificare SMTP/template in questo task. Analisi rinviata a disponibilita `.eml` Hotmail o persistenza ritardo; confrontare `.eml` Aruba e Hotmail, `Date`, catena `Received`, SPF/DKIM/DMARC, SCL/spam/quarantena e copie/BCC gestore.
- `EMAIL-AUTH-TEMPLATE-1A` / PR #175 su branch `task/email-auth-template-1a`, commit funzionale `6f11e652f5b20d78dbdaac46da808edebd774568`, migra gli invii registrazione nuovo cliente e aggiornamento profilo legacy da `registrazione.aspx.vb` al renderer condiviso `App_Code/KeepStoreEmailTemplate.vb`. Destinatari, BCC aziendale, mittente e SMTP/config esistenti restano invariati; non vengono inserite password nel body, non sono previsti invii duplicati e il vecchio body HTML hardcoded viene sostituito da HTML/plain text standard. Reset/remind password, email ordine, DB/schema, SQL, gateway, carrello/checkout, prezzi/IVA/totali, `web.config`, appSettings e connection string restano fuori scope. Prossimo step dopo PR: smoke controllato registrazione/profilo, senza invii live o utenti live non autorizzati.
- `EMAIL-PASSWORD-TEMPLATE-1A` / PR #176 su branch `task/email-password-template-1a`, commit funzionale `49ee7888f10eddcbe65b96ba257b94657bc9d880`, migra il rendering dell'email reset/remind password tokenizzato da `App_Code/PasswordResetTokenService.vb` al renderer condiviso `App_Code/KeepStoreEmailTemplate.vb`. Il flow tokenizzato resta invariato: generazione, salvataggio, scadenza, validazione, consumo token, destinatario, mittente, SMTP/config e anti-enumerazione non cambiano; nessuna password viene inserita nel body, registrazione/profilo ed email ordine restano fuori scope. Prossimo step: review/merge PR #176, poi smoke statico o runtime solo con SMTP sink/test.
- Blocco email account/auth/password chiuso: PR #175 e PR #176 mergeate; smoke statico registrazione/profilo `EMAIL-AUTH-SMOKE-1A = A` e smoke statico reset/remind `EMAIL-PASSWORD-TEMPLATE-1C = A`. Nessuna email live inviata, nessun utente live creato, nessuna password reale resettata. SMTP/config, DB/schema, gateway, carrello/checkout, prezzi/IVA ed email ordine restano invariati; il token flow reset password preserva generation, validation, expiry, storage/consume e anti-enumerazione. Rendering runtime non eseguito per assenza di ambiente test autorizzato con SMTP sink; eventuale smoke runtime futuro richiede DB test, account test e SMTP sink.
- `EMAIL-LEGACY-SENDS-CLEANUP-1A` / PR #177 su branch `task/email-legacy-sends-cleanup-1a`: inventario controllato residui email legacy dopo migrazione ordine, registrazione/profilo e reset/remind a `KeepStoreEmailTemplate`. Commit funzionale non necessario: nessun codice runtime rimosso perche gli elementi rimasti sono trasporto SMTP vivo (`MailMessage`/`SmtpClient`), fallback legacy ordine prudenziale ancora attivo se il renderer fallisce, invii contatto/main fuori scope o import non bloccanti. SMTP/config, destinatari, BCC/mittente, token flow, ordine, DB/schema, gateway, carrello/checkout, prezzi/IVA e documenti runtime restano invariati. La PR registra l'esito di cleanup controllato; smoke runtime resta ammesso solo con SMTP sink/test.
- `EMAIL-MAIN-CONTACT-CLEANUP-1A` / PR #178 su branch `task/email-main-contact-cleanup-1a`, commit funzionale `f5132b24413dd91b3c29a74317468559fe856c89`, mette in sicurezza solo l'invio contatto legacy di `main.aspx.vb`: body raw HTML eliminato a favore di `KeepStoreEmailTemplate`, From utente non piu usato come mittente diretto, Reply-To utente preservato, destinatario aziendale e SMTP/config invariati, `ex.Message` non piu esposto all'utente. `Contattaci.aspx.vb`, ordine, registrazione/profilo, reset/remind, DB/schema, gateway, carrello/checkout, prezzi/IVA e `web.config` restano fuori scope. Prossimo step eventuale: `EMAIL-CONTATTI-TEMPLATE-1A`.
- `EMAIL-CONTATTI-TEMPLATE-1A` / PR #179 su branch `task/email-contatti-template-1a`, commit funzionale `fe75c8874fca5d9ae6ecf436f76c3f51a1c085f6`, migra il rendering dell'email contatto di `Contattaci.aspx.vb` al renderer condiviso `KeepStoreEmailTemplate`. Restano preservati destinatario aziendale, mittente aziendale, Reply-To utente, subject `[Contatto sito]`, SMTP/config, logging e messaggi utente non tecnici; `main.aspx.vb`, ordine, registrazione/profilo, reset/remind, DB/schema, gateway, carrello/checkout, prezzi/IVA e `web.config` restano fuori scope. Prossimo step: review/merge PR #179 e smoke statico post-merge.
- Blocco email `KeepStoreEmailTemplate` chiuso: email ordine, PR #175 registrazione/profilo, PR #176 reset/remind password con token flow preservato, PR #178 contatto legacy `main.aspx.vb` e PR #179 `Contattaci.aspx.vb` sono completate e validate con smoke statici A dove richiesto. Nessuna email live inviata, nessun utente live creato, nessuna password reale resettata; SMTP/config, DB/schema, gateway, carrello/checkout, prezzi/IVA e `main` restano invariati. Rendering/runtime non eseguito per assenza di ambiente autorizzato con SMTP sink; eventuale smoke runtime futuro richiede DB test, account test e SMTP sink.
- `ACCOUNT-DATIUTENTE-VALIDATION-1A` / PR #180 su branch `task/account-datiutente-validation-1a`, commit funzionale `82c85d13d73128824613018f3975b22fe9165569`, hardenizza la pagina legacy `datiutente.aspx`: verifica login/sessione preservata e rafforzata, ownership update utente vincolata a `LoginId`/`UtentiId`, update indirizzi vincolati a `UtenteId`, validazioni server-side minime su email, fatturazione, CAP/provincia/contatti e destinazione alternativa, messaggi errore non tecnici. File runtime modificato: `datiutente.aspx.vb`; documentazione aggiornata. PR #180 mergeata; non sono stati modificati DB/schema/stored procedure, checkout/carrello/ordine, gateway, email/template, `web.config`, `registrazione.aspx`, `myaccount.aspx`, `my-account-edit.aspx` o `my-account-address.aspx`; nessun dato cliente reale e stato modificato.
- `ACCOUNT-DATIUTENTE-UI-1A` / PR #181 su branch `task/account-datiutente-ui-1a`, commit funzionale `bd26979e7d9572fe03a864aa6de18ec6f862dbfc`, sistema solo la resa UI della pagina legacy `datiutente.aspx` dopo smoke manuale B leggero visivo: card ponte "Gestione dati account", CTA coerenti verso `my-account-edit.aspx`, `my-account-address.aspx` e `myaccount.aspx`, sezione legacy incapsulata in card moderna e fix CSS dedicato per non mostrare wrapper FormView vuoti. PR #181 mergeata; logica dati hardenizzata da PR #180 preservata, nessun cambio DB/schema/stored procedure, checkout/carrello/ordine, gateway, email/template, `web.config`, `registrazione.aspx` o pagine account moderne; nessun dato cliente reale modificato.
- `ACCOUNT-DATIUTENTE-UI-FIX-1A` / PR #182 su branch `task/account-datiutente-ui-fix-1a`, commit funzionale `a0023fbc7b27e06a2f82aea49c475576b7fcdb38`, rimuove il blocco legacy duplicato fuori layout rimasto visibile dopo PR #181: breadcrumb legacy, intestazione "Dati di accesso / account" e tab duplicati "Dettagli account" / "Indirizzi" non sono piu renderizzati fuori dalla card moderna. Restano solo la UI account centrale e la sezione legacy incapsulata; `datiutente.aspx.vb` e la logica dati PR #180 restano invariati. Nessun cambio DB/schema/stored procedure, checkout/carrello/ordine, gateway, email/template, `web.config`, `registrazione.aspx` o pagine account moderne; nessun dato cliente reale modificato. PR #182 mergeata su `frontend-rebuild` con HEAD post-merge `d5df0a85fec9b071da3a2aa1bf1b749038d98824`.
- `ACCOUNT-AREA-LEGACY-DUPLICATES-1A`: audit statico post-merge PR #182 su `myaccount.aspx`, `my-account-edit.aspx`, `my-account-address.aspx`, `datiutente.aspx`, `AccountSidebar.ascx` e CSS account. Non risultano duplicati legacy evidenti fuori layout ne sidebar/nav inline visibili da correggere; i vecchi selettori CSS `wrap-sidebar-account` non risultano agganciati al markup account ispezionato. Nessun branch o fix applicativo aggiuntivo creato; logica dati/login/sessione/ownership, checkout/carrello/ordine, DB/schema/SP, gateway ed email/template invariati. Prossimo step: smoke manuale UI area account.
- Blocco Area Cliente UI/datiutente chiuso con smoke manuale A: accesso anonimo a `datiutente.aspx` protetto senza dati personali visibili; accesso loggato coerente, blocco legacy duplicato non piu visibile; link `my-account-edit.aspx`, `my-account-address.aspx` e `myaccount.aspx` funzionanti; `myaccount.aspx`, `my-account-edit.aspx`, `my-account-address.aspx` e `carrello.aspx` OK. Nessun dato cliente reale modificato; checkout/carrello/ordine/gateway/email/DB/schema/SP non toccati.
- `ACCOUNT-ADDRESS-ORDER-GUARD-1A` chiuso: PR #183 mergeata con guard difensiva in `ordine.aspx.vb` su `Session("SCEGLIINDIRIZZO")`. `Nothing`, vuoto o `0` mantengono il flusso storico; valori > 0 richiedono ownership parametrizzata `Id=?Id AND UtenteId=?UtentiId`; indirizzi invalidi, stale o non appartenenti bloccano prima di `Carrello_Documento` con redirect generico `carrello.aspx?addresserror=1`, senza ordine, gateway, email o svuotamento carrello. Smoke statico post-merge `ACCOUNT-ADDRESS-ORDER-GUARD-1C = A`; smoke runtime rimandato a ambiente sicuro con account test, carrello test, gateway non reale e SMTP sink. Carrello, DB/schema/SP, gateway/pagamenti, email/template, prezzi/IVA/totali/documenti e dati cliente reali restano invariati.
- `CART-ADDRESS-ERROR-MESSAGE-1A` / PR #185 su branch `task/cart-address-error-message-1a`, commit funzionale `d3b5de9097328b8b28b6729d899d36e1402e6508`, mergeata e validata con smoke `SMOKE CART ADDRESS ERROR: A`: `carrello.aspx?addresserror=1` mostra un alert fisso e non tecnico sul carrello ("L'indirizzo di spedizione selezionato non è più valido. Seleziona nuovamente l'indirizzo e conferma l'ordine.") usando il canale messaggi indirizzo gia presente. Il valore querystring non viene riflesso in HTML; nessun cambio a `ordine.aspx.vb`, `Carrello_Documento`, DB/schema/SP, gateway/pagamenti, email/template, prezzi/IVA/totali/righe o dati cliente reali.
- `CART-LEGACY-DUPLICATE-AUDIT-FIX-1A` / PR #186 su branch `task/cart-legacy-duplicate-audit-fix-1a`, commit funzionale `38cdab5a76c305940d8735cbf21b3ecc96406959`, mergeata e validata con smoke `SMOKE CART CHECKOUT UI: A`: corregge un duplicato UI in `carrello.aspx`, dove durante lo step checkout il wrapper principale `CartItemsWrap` restava visibile mentre venivano renderizzati shell checkout e riepilogo laterale. Fix applicato in `carrello.aspx.vb`: `CartItemsWrap` viene nascosto con `d-none` solo quando `tOrdine`/checkout e visibile e ripristinato nello step carrello. Restano preservati controlli server, ID, postback, scelta indirizzo, note ordine, consenso condizioni e pulsanti checkout/conferma. Nessun cambio a `ordine.aspx.vb`, `Carrello_Documento`, DB/schema/SP, gateway/pagamenti, email/template, prezzi/IVA/totali/righe o asset legacy `Public/Images/`.
- Blocco carrello/checkout UI chiuso con smoke manuale A: PR #185 mergeata con `SMOKE CART ADDRESS ERROR: A` e messaggio `addresserror=1` visibile, singolo, generico e non tecnico; PR #186 mergeata con `SMOKE CART CHECKOUT UI: A`, duplicato checkout confermato e risolto nascondendo `CartItemsWrap` solo quando `tOrdine`/checkout e visibile. In fase carrello normale resta una sola lista prodotti; in checkout non compaiono due carrelli/listati prodotti. Scelta indirizzo, note ordine, consenso condizioni, pulsanti checkout/conferma, riepilogo, prezzi/IVA/totali/righe restano preservati; ordine/gateway/email, DB/schema/SP e asset legacy `Public/Images/` non modificati. Nessun ordine reale creato, nessun gateway reale avviato e nessuna email live inviata.
- `LOGIN-PASSWORD-TOGGLE-1A` chiuso: PR #184 mergeata e smoke manuale A su `login.aspx`; il toggle custom resta l'unico controllo visibile e il reveal nativo browser e nascosto in modo mirato. `login.aspx.vb`, logica auth, sessione/cookie, registrazione/reset/remind, DB/schema/SP, checkout/carrello/ordine/gateway ed email/template restano invariati.
- `AUTH-LEGACY-DUPLICATE-AUDIT-FIX-1A` / PR #187 su branch `task/auth-legacy-duplicate-audit-fix-1a`, commit funzionale `52d9fd15e1fd1796f45e335542670d84736378ed`, completa audit mirato di `login.aspx`, `registrazione.aspx`, `remind.aspx` e `resetpassword.aspx`: nessuna doppia form login, registrazione, remind o reset rilevata. `login.aspx` conserva un solo toggle custom gia stabilizzato; `resetpassword.aspx` aveva toggle custom sui due campi nuova/conferma password senza nascondere il reveal nativo browser. Fix applicato solo in CSS inline di `resetpassword.aspx`: `::-ms-reveal` e `::-ms-clear` nascosti in modo mirato su `tbPasswordNuova` e `tbPasswordConferma`. Nessun cambio a code-behind, login/auth server-side, sessioni/cookie, logica registrazione, reset token, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali o asset legacy `Public/Images/`. Prossimo step: review/merge PR #187 e smoke manuale UI login/reset senza utenti live o email live.
- `RESET-PASSWORD-TOKEN-GUARD-1A` / PR #188 su branch `task/reset-password-token-guard-1a`, commit funzionale `748a23e1102677ca1395795bdca18955c059af91`, corregge la `NullReferenceException` in `resetpassword.aspx` quando il parametro `token` e mancante, vuoto o non valido. Causa: `CurrentToken()` chiamava `.Trim()` su `Request.QueryString("token")` potenzialmente `Nothing`; il fix rende `CurrentToken()` null-safe e fa gestire a `LoadResetState()` token assenti/vuoti con pannello controllato e messaggio generico non tecnico. Restano invariati generazione, validazione, scadenza, storage e consumo token, hashing/password algorithm, login/auth, sessioni/cookie, registrazione, remind generation, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali. Prossimo step: review/merge PR #188 e smoke manuale reset password con token assente, vuoto, invalido e valido test.
- Blocco reset password token guard chiuso con `SMOKE RESET TOKEN: A`: PR #187 mergeata per fix UI reveal/toggle password reset e PR #188 mergeata per guard null-safe su `resetpassword.CurrentToken()`. Verificati manualmente `resetpassword.aspx`, `resetpassword.aspx?token=` e token non valido senza errore server, stack trace o dettagli tecnici; il messaggio resta controllato e il form reset non e utilizzabile senza token valido. Login/auth/sessioni/cookie, registrazione/remind/generazione token, reset token validation/consume, `PasswordResetTokenService.vb`, email/template, DB/schema/SP, carrello/ordine/gateway/prezzi/totali restano invariati; nessun debug abilitato e nessun asset legacy `Public/Images/` introdotto. Il path legacy preesistente `Public/Images/` in `registrazione.aspx` resta backlog separato.
- `REGISTRATION-LEGACY-ASSET-PATH-1A` / PR #189 su branch `task/registration-legacy-asset-path-1a`, commit funzionale `65645745cd5c3789e2d2b90623af2a60e0b827ac`, rimuove l'unico path legacy immagine in `registrazione.aspx`: `Public/Images/loghi_agevolazione.jpg`, non presente nel repository e fuori dallo schema asset KeepStore 3.0. REV1: il fallback generico `/Public/assets/images/placeholder.svg` e stato rifiutato perche degradava la UI; il path finale usa l'asset reale e coerente `/Public/assets/images/coupon/Struttura/sconto_50px.png`. Restano invariati form registrazione, controlli server, ID, eventi, validatori, code-behind, login/auth/sessioni/cookie, salvataggi, email/password, reset/remind/token, DB/schema/SP, carrello/ordine/gateway/prezzi/totali. Prossimo step: review/merge PR #189 e smoke manuale registrazione UI senza utenti live o email live.
- Blocco `REGISTRATION-LEGACY-ASSET-PATH` chiuso con `SMOKE REGISTRATION UI: A`: PR #189 mergeata, REV1 applicata e validata manualmente. La pagina registrazione apre senza errori; il blocco "LISTINI AGEVOLATI" non mostra placeholder o immagine mancante, l'icona sconto `/Public/assets/images/coupon/Struttura/sconto_50px.png` e visibile e coerente, la form registrazione resta normale. Nessun utente reale creato, nessuna email live inviata; logica registrazione/auth/sessioni/email/DB, reset/remind/token, carrello/ordine/gateway/prezzi/totali e asset legacy `Public/Images/` restano invariati/non introdotti.
- `LEGACY-ASSET-PATH-AUDIT-FIX-1A` / PR #190 su branch `task/legacy-asset-path-audit-fix-1a`, commit funzionale `8aad9f697aa0f5161c22eb59552df25da2aebda0`: audit mirato dei riferimenti runtime `Public/Images/` in `.aspx`, `.ascx`, `.master`, CSS e JS. Fix applicato solo al caso semplice e decorativo `coupon_esito_acquisto.aspx`, dove `Public/Images/servizio_clienti.jpg` e stato sostituito con l'asset esistente `/Public/assets/images/headphone-2.svg`. Backlog non corretto per assenza di equivalente moderno certo o per rischio funzionale: `carrello.aspx` (`Ok.png`, `Remove.png`, `interrogativo.png`, commento `StepCarrello1.png`), `coupon_dettagli.aspx` (`Acquistati.png`, `Visite.png`), `coupon_utente.aspx` (`Pagato.png`, `Paga_Ora.png`), `articolix.aspx` (`WhatsApp-Symbolo.png`, `spazio_vuoto.gif`, `selection.gif`, `aggiungiMultiplo.png`), `documenti.aspx` (`close_pop.png`, `Ok.png`, `calendar_icon.gif`), `promo_in_scadenza.aspx` (`angolo.png`, `promoSpGratis.png`, `angolo_x.png`), `wishlist.aspx` (`aggiungiMultiplo.png`) e `rettificaMagazzino.aspx` (`back.jpg`, `bollinoPromoVetrina.png`, `selection.gif`, `aggiungiMultiplo.png`). Nessun cambio a DB/schema/SP, auth/sessioni/cookie, registrazione/reset/remind/token, email/template, carrello/ordine/gateway/prezzi/totali; prossimo step review/merge PR #190.
- `CART-DISCOUNT-LEGACY-ICONS-1A` / PR #192 su branch `task/cart-discount-legacy-icons-1a`, commit funzionale `a5876359a9ed23b5f479ac824ecf693b16c1b1f2`, sostituisce solo le due icone legacy del feedback buono sconto in `carrello.aspx`: `Public/Images/Ok.png` -> `/Public/assets/images/ico/modalok.svg` e `Public/Images/Remove.png` -> `/Public/assets/images/ico/modalno.svg`. Restano fuori scope e invariati `Public/Images/interrogativo.png` e il commento legacy `Public/Images/StepCarrello1.png`; PR #191 e tutti i file coupon non toccati. Nessun cambio a logica carrello/buoni sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP o auth/sessioni/cookie. Prossimo step: review/merge PR #192 e smoke carrello/buono sconto se disponibile.
- `CART-DISCOUNT-FIELD-UX-1A` / PR #193 su branch `task/cart-discount-field-ux-1a`, commit funzionale `376898aea8c483e2087442cad43aca08dfd7d335`, corregge la leggibilita del campo buono sconto dopo smoke manuale post-PR #192: il pannello in `carrello.aspx` ora espone titolo `Hai un codice sconto?`, microcopy, placeholder `Inserisci codice sconto`, bottone `Applica` e layout responsive coerente con i riferimenti ONSUS `shop-cart.html` e `checkout.html`. I controlli server, ID, postback e feedback OK/KO restano preservati con `/Public/assets/images/ico/modalok.svg` e `/Public/assets/images/ico/modalno.svg`; PR #191/coupon non toccata. Nessun cambio a logica buoni sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP o auth/sessioni/cookie. Prossimo step: review/merge PR #193 e smoke manuale desktop/mobile su carrello e buono sconto.
- `CART-CHECKOUT-UX-SMOKE-FIX-1A` / PR #194 su branch `task/cart-checkout-ux-smoke-fix-1a`, commit funzionale `715bcbf6882f51c90200a9d12a451283ab249091`, nasce da smoke reale `SMOKE CART DISCOUNT UX: B` post-PR #193: coupon non visibile, pulsanti scuri poco leggibili e step spedizione/checkout troppo compresso. Causa tecnica: `cart-ui.css` non era caricato da `carrello.aspx` e il CSS ONSUS globale rendeva il bottone `.ip-discount-code .tf-btn` assoluto; quindi le regole cart-specific di PR #193 non arrivavano al runtime. Fix applicato solo a UI: link a `cart-ui.css` nella pagina carrello, bottone coupon riportato a layout flex normale, contrasto bottoni carrello e spacing checkout/section grid migliorati secondo `shop-cart.html` e `checkout.html`. PR #191/coupon non toccati; nessun cambio a logica carrello/sconto, prezzi/IVA/totali/righe, ordine/gateway/email/DB/schema/SP/auth/sessioni. Prossimo step: review/merge PR #194 e nuovo smoke manuale desktop/mobile senza inviare ordine.
- REV1 `CART-CHECKOUT-UX-SMOKE-FIX-1C` su PR #194, commit funzionale `f19e9ae6f643ca92b5ceaad8c48410e6da304e91`, riordina realmente carrello, checkout e conferma dopo nuovo smoke B: titolo step dinamico (`Il tuo carrello`, `Spedizione e checkout`, `Conferma ordine`), layout carrello con coupon e riepilogo stabile a destra, bottoni secondari leggibili, sidebar checkout stile ONSUS applicata fuori dallo scope `.s-shoping-cart`, stato codice sconto non interattivo in checkout e conferma finale con sola CTA primaria `Invia ordine con obbligo di pagamento`. Nessun cambio a code-behind, logica sconto, prezzi/IVA/totali/righe, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie o PR #191/coupon. Prossimo step: smoke manuale desktop/mobile PR #194 aggiornato.
- REV2 `CART-CHECKOUT-UX-SMOKE-FIX-1D` su PR #194, commit funzionale `1734e1ef8d5c2a78d87db6cf71b1bdf32176308d`, chiude il nuovo smoke B reale sui tre step: il blocco `CartActionsWrap` con `Panel_BuoniSconto` era ancora dentro `CartItemsWrap`, che il code-behind nasconde negli step checkout/conferma; ora il pannello sconto/riepilogo/azioni e fratello del wrapper prodotti, quindi lo stesso controllo server coupon resta unico e visibile anche nello step checkout. CSS REV2 scoped a `.ks-cart-page`: step 1 prodotti + coupon + riepilogo + azioni; step 2 mostra coupon inseribile/validabile e nasconde riepilogo/azioni carrello duplicati; step 3 nasconde il support panel e conserva solo la CTA finale `Invia ordine con obbligo di pagamento`. Cache bust `cart-ui.css` aggiornato. Nessun cambio a code-behind, ID/eventi/validatori, logica sconto, prezzi/IVA/totali/righe, spedizione/pagamento, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie; PR #191/coupon resta sospesa e non toccata. Prossimo step: smoke manuale desktop/mobile PR #194 REV2 senza inviare ordine.
- REV3 `CART-CHECKOUT-UX-SMOKE-FIX-1E` su PR #194, commit funzionale `4ef5407b9871a0d18ad29b1bac00d74da5b4c28b`, rifinisce definitivamente lo smoke B REV2: font minimi allineati a ONSUS, card con padding 20-28px, step 1 con coupon + riepilogo importi + azioni dentro container, step 2 con coupon ancora inseribile/validabile, box indirizzo piu compatto e riepilogo prodotti con miniatura/nome/qta/prezzo, step 3 gerarchia finale con sola CTA primaria `Invia ordine con obbligo di pagamento`. La modifica resta limitata a `carrello.aspx` per cache bust e `cart-ui.css`; nessun cambio a controlli server, ID/eventi/validatori, code-behind, logica sconto, prezzi/IVA/totali/righe, checkout business logic, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie. PR #191 e tutti i file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale desktop/mobile PR #194 REV3 senza inviare ordine.
- REV4 `CART-CHECKOUT-UX-SMOKE-FIX-1F` su PR #194, commit funzionale `32308a1eb5caebada8fcf7e5e38475514d13e31b`, corregge i tre problemi reali dello smoke REV3: doppio incremento quantita causato da due handler JS attivi (`cart-ui.js` + `checkout-ui.js`), coupon step 2 non percepibile perche rimasto nel support panel fuori dal contenuto checkout, lista indirizzi generata in chiaro dal vecchio enhancer JS. Fix chirurgico: `cart-ui.js` lascia gli stepper carrello `.ks-wg-quantity` al solo handler `checkout-ui.js`, `checkout-ui.js` sposta l'unico `CartActionsWrap` nello slot visibile `CheckoutCouponSlot` dello step 2 senza duplicare controlli server, e disabilita la lista card indirizzi mantenendo la select compatta `LstScegliIndirizzo`. Nessun cambio a controlli server, ID/eventi/validatori, code-behind, logica sconto/indirizzi, prezzi/IVA/totali/righe, checkout business logic, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale PR #194 REV4 su +/-, coupon step 2 e indirizzi compatti senza inviare ordine.
- REV5 `CART-CHECKOUT-UX-SMOKE-FIX-1G` su PR #194, commit funzionale `b2681ee51c008fa078ef55206948d31cf52efa33`, corregge la causa reale del coupon ancora assente nello step 2: `Panel_BuoniSconto.Visible` dipendeva da `TableConteggi.Visible`, quindi quando il riepilogo conteggi non era renderizzato il pannello con `TB_BuonoSconto`, `BT_ApplicaBuonoSconto` e feedback non arrivava proprio nell'HTML. La visibilita dell'input sconto e ora separata dal riepilogo conteggi: viene mostrato se i buoni sono abilitati, il carrello ha articoli e lo step corrente non e conferma; lo step 3 resta senza input sconto. Nessun cambio a `TB_BuonoSconto_TextChanged`, eventi/ID, sessioni sconto, calcoli sconto, prezzi/IVA/totali/righe, indirizzi, quantita REV4, ordine/gateway/email, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale PR #194 REV5 su step 1/2/3 coupon senza inviare ordine.
- REV6/FINAL `CART-CHECKOUT-UX-FINAL-ALIGN-1A` su PR #194, commit funzionale `bd4ee5ed5e0895ac32560aca1f9caa68cd6ae0a7`, riallinea il carrello al modello ONSUS verificato su `shop-cart.html` e `checkout.html`: step 1 focalizzato su prodotti, quantita, prezzi e totale articoli/subtotale prodotti, senza input coupon o costi checkout anticipati; step 2 con l'unico pannello coupon reale (`TB_BuonoSconto`, `BT_ApplicaBuonoSconto`, feedback) spostato nello slot checkout; step 3 senza coupon e senza CTA `Procedi con l'ordine`, lasciando la CTA finale `Invia ordine con obbligo di pagamento`. La visibilita server del pannello sconto ora richiede lo step checkout e non conferma. Corretto anche il blocco runtime post-`Applica`: gli helper SEO di `carrello.aspx.vb` non aggiungono piu controlli a `Header.Controls` quando il `<head>` contiene blocchi inline, evitando l'errore "Impossibile modificare la raccolta Controls". Nessun cambio a calcoli sconto, prezzi/IVA/totali/righe, indirizzi, quantita REV4, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale finale PR #194 sui tre step e click `Applica`, senza inviare ordine.
- REV7 `CART-CHECKOUT-ORDER-FINAL-UX-1A` su PR #194, commit funzionale `97b19096cb88a996b91b65827cf45e9f3cfe22f2`, chiude l'allineamento UI dopo smoke `SMOKE CART CHECKOUT FINAL: B`: step 1 resta focalizzato su prodotti, quantita, prezzi e totale articoli; nello step 2 il pannello coupon reale viene collocato dopo `Pagamento` e prima di `Dati fatturazione`, con titolo `Codice sconto`, microcopy dedicata, input `TB_BuonoSconto`, bottone `Applica` e feedback OK/KO stilato; la sidebar mostra solo lo stato del codice. `Dati fatturazione` e piu compatto e i font checkout/carrello sono leggermente aumentati. `ordine.aspx` diventa pagina post-submit leggibile e stampabile per ordini non-gateway: hero `Ordine inviato`, numero/data/stato, azioni stampa/area cliente/continua acquisti, riepilogo cliente, indirizzi, metodo, righe prodotti, totali, prossimi passi e CSS print. Redirect gateway/coupon esistenti preservati; nessun cambio a calcoli sconto, prezzi/IVA/totali/righe, spedizione, pagamento, gateway, email/template, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Runtime live non eseguito: prossimo step smoke manuale finale PR #194 senza creare ordine reale, gateway o email.
- REV8 `CART-CHECKOUT-ORDER-FINAL-UX-1B` su PR #194, commit funzionale `31ea74597b58951523bd265e6d4e545dff82f9b6`, corregge l'unico residuo dello smoke `SMOKE CART CHECKOUT ORDER REV7: B`: dopo cambio step il browser restava in basso per ripristino scroll WebForms (`MaintainScrollPositionOnPostBack=True`). Fix solo client in `checkout-ui.js`: i click sui controlli di transizione step registrano lo step atteso in `sessionStorage`; al nuovo rendering, se lo step e cambiato, la viewport viene riportata in alto su `.ks-cart-page`/`.checkout-status` con scroll immediato. Azioni minori nello stesso step, come coupon, quantita e cambio spedizione/pagamento, non vengono marcate come transizione. Layout step 1/2/3, posizione coupon, ricevuta ordine stampabile, sconti, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie restano invariati. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale finale REV8 sui passaggi step senza inviare ordine.
- REV9 `CART-CHECKOUT-ORDER-FINAL-UX-1C` su PR #194, commit funzionale `1866451e5db60a066cc2441583ff68315be61fe4`, corregge i residui dello smoke `SMOKE CART CHECKOUT REV8: B`: coupon ghost nello step 1, informazioni coupon duplicate nello step 2, scroll ancora instabile verso conferma e CTA mobile troppo anticipata. Causa: `GV_BuoniSconti` era fratello del pannello coupon reale e restava renderizzato fuori card quando `Panel_BuoniSconto` veniva spostato; la sidebar checkout aveva anche un box separato `Codice sconto`. Fix: il GridView descrittivo del buono ora vive dentro `Panel_BuoniSconto`, il box coupon sidebar viene rimosso lasciando solo la riga economica `Sconto`, lo scroll step usa piu tentativi postback, e su mobile la stessa area azioni finale viene spostata dopo il riepilogo ordine tramite slot dedicato senza duplicare `btInviaOrdine`. Nessun cambio a logica sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon restano sospesi/fuori scope. Prossimo step: smoke manuale finale REV9 senza inviare ordine.
- REV10 `CART-CHECKOUT-ORDER-FINAL-UX-1D` su PR #194, commit funzionale `e2e028dc171f8508cc0609b45677258fbe3f23d8`, corregge il residuo dello smoke `SMOKE CART CHECKOUT REV9: B`: su mobile nello step `Conferma` il modulo CTA finale veniva sovrapposto dal riepilogo ordine. Causa: il wrapper checkout restava un flex row custom anche sotto breakpoint mobile, mentre lo slot mobile della CTA era un flex item dopo la sidebar. Fix solo CSS mobile: `tf-checkout-wrap`, contenuto checkout, sidebar, riepilogo e slot CTA vengono forzati nel normale flow verticale, con larghezza 100%, `position: static`, `clear: both`, margini adeguati e puntamento attivo; lo stesso `btInviaOrdine` resta unico e viene solo spostato dallo script REV9. Desktop, step 1/2, coupon, scroll, ricevuta ordine, logica sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie restano invariati. Prossimo step: smoke manuale mobile REV10 senza inviare ordine.
- REV11 `ORDER-RECEIPT-POLISH-1A` su PR #194, commit funzionale `41994ea64063b33beb533fe030c5572a86816505`, rifinisce `ordine.aspx` dopo conferma utente che carrello/checkout REV10 funzionano: bottoni ricevuta riallineati al brand ONSUS/Taikun, bottone `Stampa ordine` primario rosso, azioni secondarie outline/light, layout web della ricevuta piu ordinato e intestazione aziendale stampabile in cima al documento. I dati azienda arrivano da `LoadOrderEmailBrandData(conn)` / tabella `Aziende` con fallback sessione gia esistente; il logo usa `Aziende.LogoWeb` tramite helper `KeepStoreEmailLogo` su `/Public/assets/images/logo/{LogoWeb}`. CSS print nasconde header/menu/footer/newsletter/bottoni e mantiene logo, dati azienda, riferimento ordine, articoli, indirizzi, metodo, importi e assistenza. Nessun cambio a creazione ordine, calcoli, prezzi/IVA/totali/righe, spedizione, pagamento, gateway, email/template, DB/schema/SP, auth/sessioni/cookie, carrello/checkout o PR #191/coupon. Prossimo step: smoke manuale `ordine.aspx` web + stampa/anteprima senza creare nuovo ordine, gateway o email.
- REV12 `CART-EMPTY-STATE-CLEANUP-1A` su PR #194, commit funzionale `1795dab6603fb2048810a02dd1e7c15f8cd45455`, parte da `SMOKE ORDER RECEIPT REV11: A` confermato dall'utente e non tocca piu `ordine.aspx`. Risolve il duplicato/stato legacy del carrello vuoto standardizzando `CartEmptyPanel` come unica card moderna: classe pagina `ks-cart-is-empty`, bottoni `Sfoglia il catalogo` primario brand e `Torna alla home` secondario, CSS responsive scoped e guard UI server-side su `CartItemsWrap`, `CartActionsWrap`, `CartSummaryColumn`, coupon e checkout quando `numero = 0`. Carrello pieno, step 1/2/3, coupon step 2, mobile CTA conferma, scroll step, quantita, indirizzi, prezzi/IVA/totali/righe, ordine/gateway/email/template, DB/schema/SP, auth/sessioni/cookie e PR #191/coupon restano invariati. Prossimo step: smoke manuale carrello vuoto desktop/mobile e regressione carrello pieno senza inviare ordine.
- REV13 `CART-EMPTY-STATE-CLEANUP-1B` su PR #194, commit funzionale `417497d5d6a844c5e9abc33c1c20eaae1efca07d`, corregge il residuo di `SMOKE CART EMPTY REV12: B`: sopra la card moderna restavano il conteggio `0 articoli nel carrello` e la nota prezzi, cioe informazione legacy fuori layout. Il code-behind nasconde `lblArticoli`, `lblPresenti` e `lblPrezzi` quando `numero = 0` e li ripristina a carrello pieno; il CSS scoped `.ks-cart-page.ks-cart-is-empty` impedisce la ricomparsa del blocco heading/meta empty fuori card. La card moderna resta l'unica comunicazione di carrello vuoto; bottoni, desktop/mobile, carrello pieno, step 1/2/3, mobile CTA, `ordine.aspx` REV11, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie e PR #191/coupon restano invariati. Prossimo step: smoke manuale carrello vuoto REV13 e regressione carrello pieno.
- REV14 `CART-EMPTY-STATE-CLEANUP-1C` su PR #194, commit funzionale `faace786eb4810a49e1d616c0171f1eebac4ffff`, corregge il residuo di `SMOKE CART EMPTY REV13: B`: il titolo esterno statico `Il tuo carrello` dentro `.heading-section` restava visibile sopra la card moderna. Fix solo CSS scoped: `.ks-cart-page.ks-cart-is-empty .heading-section { display: none; }`, con cache bust REV14. A carrello pieno il titolo resta preservato; a carrello vuoto rimangono solo stepper e card moderna. Nessun cambio a logica carrello, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie, `ordine.aspx` REV11 o PR #191/coupon. Prossimo step: smoke manuale carrello vuoto REV14 e regressione carrello pieno.
- REV15 `CART-COUPON-APPLY-STATE-1A` su PR #194, commit funzionale `35e4abacce2e3b248978b7d78257bc50171bd6e3`, disabilita lo stesso bottone `BT_ApplicaBuonoSconto` quando `Session("BuonoSconto_id")` indica un coupon gia applicato e lo riabilita dopo `Elimina codice`/rimozione coupon. Causa: il lock UI indirizzi poteva rieseguire lo stato dei controlli e lasciare `Applica` attivo dopo postback pur con buono valido. Fix solo UI server-side con `SyncCouponUiState()` e CSS disabled scoped: nessun nuovo bottone, nessuna duplicazione controlli, nessun cambio a verifica coupon, calcoli sconto, prezzi/IVA/totali/righe, checkout/ordine/gateway, email/template, DB/schema/SP, auth/sessioni/cookie. PR #191 e file coupon dedicati restano sospesi/non toccati. Prossimo step: smoke manuale REV15 su applica/elimina codice senza inviare ordine.
- `CART-RECENTLY-VIEWED-1A` su branch `task/cart-recently-viewed-1a`, commit funzionale `c0e8cbeaf697805426f993ce3fd67028fc391bb6`, aggiunge in `carrello.aspx` un blocco ONSUS-style `Visti di recente` / consigliati sotto carrello e checkout, escluso dallo step `Conferma`. La fonte e il tracking reale gia esistente `ks_recent*` di scheda prodotto/home; se non ci sono dati recenti validi il blocco resta nascosto, senza prodotti statici ONSUS o immagini demo. La query usa solo prodotti reali disponibili da `vsuperarticoli`, massimo 8, esclude gli articoli gia nel carrello e propone solo CTA `Vedi prodotto` verso scheda articolo, senza add-to-cart diretto. Nessun cambio a `ordine.aspx`, gateway, email/template, auth/sessioni/cookie, DB/schema/SP, prezzi/IVA/totali/righe/spedizione/pagamento o PR #191/coupon; PR #194 non viene riaperta. Prossimo step: review/merge nuova PR e smoke manuale utente su carrello, checkout e conferma senza creare ordine.
- REV2 `CART-RECENTLY-VIEWED-1B` su PR #195, commit funzionale `fbbb184d4e670c2ba869f7e09eee973c36972d4c`, nasce dallo smoke utente `SMOKE CART RECENTLY PR195: B`: il modulo non compariva in step 1/2 perche REV1 mostrava solo recenti reali e restava nascosta quando `ks_recent*` era vuoto, non leggibile, tutto escluso perche gia in carrello o senza prodotti validi. La pipeline ora e: prima recenti reali con titolo `Visti di recente`; se non producono item, fallback reale `Potrebbe interessarti anche` basato sugli articoli nel carrello, con categoria/tipologia/marca/settore da `vsuperarticoli`, massimo 8, esclusione prodotti gia nel carrello, immagini helper moderne e CTA solo `Vedi prodotto`. Se neppure il fallback trova prodotti reali il modulo resta nascosto senza statici/demo. Step 1 e step 2 mostrano il blocco se ci sono item; step `Conferma` resta senza raccomandazioni. Nessun cambio a `ordine.aspx`, gateway, email/template, auth/sessioni/cookie, DB/schema/SP, prezzi/IVA/totali/righe/spedizione/pagamento o PR #191/coupon; PR #194 non viene riaperta. Prossimo step: review/merge PR #195 aggiornata e smoke manuale su recenti/fallback senza creare ordine.
- REV3 `CART-RECENTLY-VIEWED-1C` su PR #195, commit funzionale `a0695b98411ab138809c231804f8d1c5da8fc698`, corregge lo smoke `SMOKE CART RECENTLY REV2: B` dovuto a layout sformato: REV1/REV2 usavano classi globali ONSUS (`card-product`, `product-img`, `tf-btn`) dentro un wrapper custom e la griglia era nel Repeater, con rischio di immagini fuori scala, testi dispersi e header percepito senza card nello step checkout. Il markup ora e unico e scoped (`ks-cart-recommendations`, griglia esterna, card `ks-cart-recommendation-*`), con microcopy dinamica recenti/fallback, immagini in box controllato, desktop 4 colonne, tablet 2, mobile 1 e modulo visibile solo se ci sono card bindate. Pipeline REV2 preservata; nessun cambio a business carrello/checkout, coupon, `ordine.aspx`, gateway, email/template, auth/sessioni/cookie, DB/schema/SP, prezzi/IVA/totali/righe/spedizione/pagamento o PR #191/coupon. Prossimo step: smoke manuale REV3 su step 1, step 2, step 3 e mobile senza creare ordine.
- REV4 `CART-RECENTLY-VIEWED-1D` su PR #195, commit funzionale `6136ff9a7ae6ec61e44c4a5a9467900026c88af1`, rifonda il rendering dopo smoke REV3 B: rimosso il Repeater/markup ibrido e sostituito con un unico host server-side `RecommendedProductsPanel` + `RecommendedProductsHtml`. L'intera sezione, header, microcopy, griglia e card viene renderizzata solo dopo aver prodotto card valide; se non ci sono card non compare nessun titolo/testo orfano. La pipeline dati REV2 resta preservata e aggiunge un terzo fallback catalogo reale leggero da `vsuperarticoli` quando recenti e correlati non producono item. Step 1 e step 2 possono mostrare il modulo se esistono prodotti reali validi; step `Conferma` e carrello vuoto restano senza raccomandazioni. Nessun statico ONSUS, nessun add-to-cart, nessun nuovo `Public/Images/`; nessun cambio a business carrello/checkout, coupon, `ordine.aspx`, gateway, email/template, auth/sessioni/cookie, DB/schema/SP, prezzi/IVA/totali/righe/spedizione/pagamento o PR #191/coupon. Prossimo step: smoke manuale REV4 su step 1, step 2, step 3 e mobile senza creare ordine.
- REV5 `CART-RECENTLY-VIEWED-1E` su PR #195, commit funzionale `e9c8092f4c94b2b92a722e19b333d8f48bc843fa`, corregge lo smoke reale `SMOKE CART RECENTLY REV4: B`: il modulo risultava ancora non governato perche l'host viene renderizzato fuori dalle sezioni `.ks-cart-page`, mentre il CSS REV4 era scoped a `.ks-cart-page .ks-cart-recommendations*`. REV5 rende il modulo autosufficiente: classi uniche `.ks-rv-*`, HTML completo generato server-side nel solo `RecommendedProductsPanel`/`RecommendedProductsHtml`, nessun testo/link statico in ASPX, card con `ks-rv-image-box`, immagini con attributi `loading`, `width` e `height` piu CSS limitante, desktop 4 colonne, tablet 2 e mobile 1. Pipeline recenti/fallback correlati/fallback catalogo reale preservata, massimo 8, esclusione prodotti gia in carrello, nessun statico ONSUS, nessun add-to-cart e nessun asset legacy. Nessun cambio a business carrello/checkout, coupon, `ordine.aspx`, gateway, email/template, auth/sessioni/cookie, DB/schema/SP, prezzi/IVA/totali/righe/spedizione/pagamento o PR #191/coupon. Prossimo step: smoke manuale REV5 su step 1, step 2, step 3 e mobile senza creare ordine.
- REV6 `CART-RECENTLY-VIEWED-1F` su PR #195, commit funzionale `c3ff976fbb5d72c5d5931bb1f245b5360e65f765`, rifinisce lo smoke reale `SMOKE CART RECENTLY REV5: B`: REV5 ha reso visibile il modulo, ma alcune card risultavano ancora poco professionali per immagini mancanti/non caricabili, spaziature e allineamento. REV6 non rifà la pipeline dati: filtra immagini vuote/non sicure prima di generare la card, evita `placeholder.svg`, gestisce immagini non caricabili con placeholder CSS interno `.ks-rv-image-box.is-missing`, migliora altezza card, hover, box immagine, titolo max 2 righe, prezzo evidente e CTA `Vedi prodotto` allineata in basso. Desktop resta max 4 card, tablet 2, mobile 1. Nessun cambio a business carrello/checkout, coupon, `ordine.aspx`, gateway, email/template, auth/sessioni/cookie, DB/schema/SP, prezzi/IVA/totali/righe/spedizione/pagamento o PR #191/coupon. Prossimo step: smoke manuale REV6 su step 1, step 2, step 3 e mobile senza creare ordine.
- REV7 `CART-RECENTLY-VIEWED-1G` su PR #195, commit funzionale `0f88ab9a6cad084cf1fbbde3da921958d975845a`, chiude i residui di `SMOKE CART RECENTLY REV6: B`: modulo visibile e dati funzionanti, ma font/proporzioni non ancora coerenti con carrello/ONSUS, possibili duplicati articolo e card senza immagine non abbastanza stabile. REV7 mantiene la pipeline REV5/REV6 ma aggiunge deduplica finale prima del rendering per ID, codice, URL e nome+prezzo, massimo 8 card dopo deduplica, e allinea le classi `.ks-rv-*` a `font-family: inherit`, heading 20/22px, nome prodotto 14/15px, codice 11/12px, prezzo 15/16px e CTA coerente. Le card senza immagine restano gestite con filtro immagine e placeholder CSS interno; nessun `placeholder.svg`, asset statico ONSUS o `Public/Images`. Nessun cambio a business carrello/checkout, coupon, `ordine.aspx`, gateway, email/template, auth/sessioni/cookie, DB/schema/SP, prezzi/IVA/totali/righe/spedizione/pagamento o PR #191/coupon. Prossimo step: smoke manuale REV7 su step 1, step 2, step 3 e mobile senza creare ordine.
- Blocco carrello/checkout/recently chiuso: PR #194 mergeata con merge commit `02e7ec16b832bb333e7f0c21871aa724822dd51b` e smoke utente OK; PR #195 mergeata con merge commit `7ad1d9b7c296b58881f796a9032b0e2eeff7d8e2` e smoke finale utente `SMOKE CART RECENTLY REV7: A`. Stato finale: carrello vuoto moderno, carrello pieno step 1 stabile, step 2 checkout stabile, step 3 conferma stabile, coupon applica/elimina stabile, CTA mobile conferma stabile, `ordine.aspx` ricevuta/stampa stabile e modulo `Visti di recente` / `Potrebbe interessarti anche` stabile. Nessun cambio a DB/schema/SP, gateway, email/template, auth/sessioni/cookie, prezzi/IVA/totali/righe/spedizione/pagamento. Non riaprire il carrello per micro-rifiniture non bloccanti: future raccomandazioni ecommerce vanno trattate come moduli separati, non regressioni del carrello.
- Regola ecommerce permanente: il carrello e il checkout vanno valutati anche come superfici commerciali, non solo grafiche. Futuri micro-task potranno aggiungere correlati, accessori, cross-sell, upsell, bundle e raccomandazioni piu intelligenti, ma sempre da dati reali, con esclusione prodotti gia in carrello, senza dati statici demo e senza alterare calcoli/gateway. SEO/AI search e Google/AI discovery richiedono dati prodotto leggibili, URL canonici e in futuro structured data dedicati, da trattare in task separati.
- `PRODUCT-DETAIL-SHELL-1A` apre il blocco scheda prodotto reale `articolo.aspx?id=...`: rifinitura UI shell ONSUS/KeepStore su branch `task/product-detail-shell-1a`, con wrapper scoped `.ks-product-detail-page`, layout principale desktop a due colonne gallery/info-buy box, gallery piu ordinata, buy box piu ecommerce, tab descrizione/info piu contenuti e mobile a colonna. Il task resta solo visuale: nessun cambio a prezzi/promo, disponibilita, varianti TC, quantita, add-to-cart, carrello/checkout/ordine/recently/coupon, DB/schema/SP, gateway, email/template o auth. Prossimi step possibili dopo review/smoke: `PRODUCT-DETAIL-SEO-1A` o `PRODUCT-DETAIL-RELATED-1A`.
- REV1 `PRODUCT-DETAIL-SHELL-1B` aggiorna PR #196 dopo smoke reale `SMOKE PRODUCT DETAIL SHELL PR196: B`: allinea la typography della scheda prodotto alla scala ONSUS (`Inter`, body 15/24, titolo prodotto 22/25, prezzo 30/36, price-text 20/22, metadati 12/22, body-md/body-text 14/22-20, CTA 15/600), rifinendo solo `product-ui.css` su selettori scoped `.ks-product-detail-page` e sezioni prodotto gia presenti. Nessun cambio a `articolo.aspx.vb`, business, prezzo/promo, disponibilita, varianti TC, quantita, add-to-cart, carrello/checkout/ordine/recently/coupon, DB/schema/SP, gateway, email/template o auth.
- REV2 `PRODUCT-DETAIL-SHELL-1C` aggiorna PR #196 con misurazione reale da `Public/assets/keepstore/product-detail.html` + `css/styles.css` ONSUS e applicazione puntuale solo in `product-ui.css`: variabili locali scoped `.ks-product-detail-page` per font `Inter`, body pagina 15/24, `body-text-3` 14/20, `body-md-2` 14/22, `caption` 12/22, titolo prodotto 22/25 peso 600, tab 18/24, prezzo principale 30/36 rosso `#ff3d3d`, prezzi card 20/22 colore testo `#333e48`, nomi card 14/22 blu `#004ec3`, CTA `tf-btn` 15/24 peso 600 con padding 10x16 e radius 8. Colori fonte ONSUS confermati: testo `#333e48`, muted `#73787d`, primary `#ff3d3d`, secondary `#004ec3`, border/panel `#ebebeb`/`#f5f5f5`. Nessun cambio a `articolo.aspx`, `articolo.aspx.vb`, controlli server, business, prezzo/promo, disponibilita, varianti TC, quantita, add-to-cart, SEO/JSON-LD, recensioni, carrello/checkout/ordine/recently/coupon, DB/schema/SP, gateway, email/template o auth.
- REV3 `PRODUCT-DETAIL-SHELL-1D` risponde allo smoke reale `SMOKE PRODUCT DETAIL SHELL PR196 REV2: B` con confronto computed-style oggettivo via Chrome headless su `Public/assets/keepstore/product-detail.html` e harness statico KeepStore sulle classi runtime PR #196. Valori fonte desktop ONSUS: titolo `h5.product-info-name.fw-semibold` = `Inter` 22/600/25 `#333e48`, prezzo principale `.product-info-price h4.text-primary` = `Inter` 30/500/36 `#ff3d3d`, body `.body-text-3` = 14/400/20 `#333e48`, tab `.tab-link.product-title.fw-semibold` = 18/600/24 `#004ec3`, card name `.name-product.body-md-2.fw-semibold.text-secondary.link` = 14/600/22 `#004ec3`, card price `.new-price.price-text.fw-medium` = 20/500/22 `#333e48`, CTA `.tf-btn` = 15/600/24 con padding 10x16 e altezza 44. KeepStore prima REV3 divergeva solo su prezzo principale peso 700 e tab mobile 16px; REV3 porta prezzo principale a peso 500, tab mobile a 18px e margine titolo responsive coerente con ONSUS. Runtime KeepStore reale resta da smoke manuale utente; nessun cambio a `articolo.aspx`, `articolo.aspx.vb`, business, carrello/checkout/ordine, DB/schema/SP, gateway, email/template o auth.
- REV4 `PRODUCT-DETAIL-SHELL-1E` riallinea la struttura del top prodotto al template ONSUS reale dopo il confronto su `Public/assets/keepstore/product-detail.html`: la causa del disallineamento non era piu la typography, ma CSS custom KeepStore che trasformava l'area info in griglia/card. REV4 neutralizza solo regole scoped in `product-ui.css`: `.ks-product-info-layout` torna a flex/wrap ONSUS, `.ks-product-summary` perde card/bordo/ombra, `.ks-product-feature-grid` torna lista verticale con label a 72px, `.ks-product-purchase-card` resta buy box ONSUS con bordo 1px/radius 6/gap 18 e larghezza piena, gallery e tab non ricevono wrapper-card aggiuntivi. Nessun cambio a `articolo.aspx.vb`, controlli server, prezzo/promo, disponibilita, varianti TC, quantita, add-to-cart, SEO/JSON-LD, recensioni, carrello/checkout/ordine/recently/coupon, DB/schema/SP, gateway, email/template o auth.
- REV5 `PRODUCT-DETAIL-SHELL-1F` applica reset controllato dopo smoke reale `SMOKE PRODUCT DETAIL SHELL PR196 REV4: B`: la causa reale di REV1-REV4 era stratificazione di override `ks-*` sopra ONSUS, non un singolo font/padding. REV5 riparte da `Public/assets/keepstore/product-detail.html`, lascia le classi ONSUS come struttura primaria in `articolo.aspx`, rimuove classi visuali `ks-*` ridondanti dal top prodotto/tabs/sezioni e riscrive `product-ui.css` in tre blocchi: variabili ONSUS misurate, bridge WebForms minimo, fix runtime sicuri per media/descrizioni/dati reali. Regola permanente: non si parte da CSS custom; si mappa prima markup ONSUS reale, si innestano server control WebForms, si usano classi `ks-*` solo per bridge minimo e non si dichiara identico senza verifica runtime.
- REV6 `PRODUCT-DETAIL-SHELL-1G` risponde allo smoke reale `SMOKE PRODUCT DETAIL SHELL PR196 REV5: B` con visual lock piu severo: `product-ui.css` non deve piu contenere variabili tipografiche locali o override custom su `.product-info-name`, `.price-text`, `.new-price`, `.name-product` e `.tab-link`. Il CSS resta solo bridge minimo per WebForms/select/quantita, immagini reali `object-fit: contain`, overflow descrizioni, brand testuale e responsive dove il markup runtime non puo essere identico al template. In `articolo.aspx` sono rimosse classi visuali `ks-*` non piu usate da prezzo, stepper quantita e card prodotto, lasciando le classi ONSUS primarie. Misura ONSUS eseguita via browser su server statico locale `127.0.0.1`, viewport 1440/791/390, con output JSON locale fuori repo `C:\Users\Taikun\AppData\Local\Temp\ks-product-detail-rev6\onsus-metrics.json`; screenshot non prodotti per timeout della capture browser, e runtime KeepStore non misurato per assenza di host WebForms locale sicuro. Esito REV6 da considerare non-A finche non viene completato smoke runtime comparativo.
- REV7 `PRODUCT-DETAIL-SHELL-1H` aggiorna PR #196 dopo confronto runtime reale tra ONSUS `product-detail.html` e KeepStore `https://localhost:8443/articolo.aspx?id=20150`, viewport 1440/791/390. La prima regola fissata e distinguere asset failure da CSS failure: gli URL immagini articolo sono moderni `/Public/assets/images/articoli/...`, non legacy, ma se il file fisico manca la gallery non deve collassare ne mostrare alt text lungo. Il fix resta visuale: handler `onload/onerror` solo sugli `<img>` di gallery/card, placeholder CSS interno "Immagine non disponibile", gallery quadrata stabile, thumbs piu compatte, titolo clamp 2 righe desktop/tablet e 3 mobile, prezzo principale hero rosso/30px, body prodotto scoped 15px, feature list/tabs/card/recently piu contenuti con selector stabile `ks-recently-viewed-section`. Nessun cambio a `articolo.aspx.vb`, prezzi numerici, disponibilita, varianti TC, quantita, add-to-cart, carrello/checkout/ordine/recently data source/coupon, DB/schema/SP, gateway, email/template o auth.
- REV8 `PRODUCT-DETAIL-SHELL-1I` chiude residui visuali runtime di PR #196 su `https://localhost:8443/articolo.aspx?id=20150` confrontato con ONSUS statico `http://127.0.0.1:8766/Public/assets/keepstore/product-detail.html`, viewport 1440/791/390. Intervento solo CSS/cache-bust: feature list da 132px a 98px, tab desktop da 463px a 311px, tab tablet da 752px a 326px, tab mobile stabile da 380px a 376px, card desktop da 404px a 386px, card tablet da 342px a 324px, card mobile da 336px a 322px, `product-ui.css?v=pr196-rev8`. Gallery, thumbs, titolo clamp, prezzo hero e recently restano stabili; nessun cambio a `articolo.aspx.vb`, prezzi/promo, disponibilita business, varianti TC, quantita, add-to-cart, carrello/checkout/ordine, DB/schema/SP, gateway, email/template o auth. PR #197 / `AvailabilityDisplayHelper.vb` / DispoTipo restano fuori scope e non incorporati.
- `PRODUCT-DETAIL-FONT-LOCK-1A` verifica oggettiva font PR #196: ONSUS e KeepStore dichiarano e computano `Inter, serif` sul runtime browser, con `document.fonts.check("15px Inter")` OK su entrambi. Il template ONSUS non dichiara un `@font-face` locale per Inter; `fonts/font.css` resta limitato a `MADE Outer` e `UTM Banque`, mentre `styles.css` dichiara lo stack `Inter, serif`. KeepStore carica lo stesso stack via `styles.css` e usa `product-ui.css?v=pr196-rev8` solo per bridge scoped. Nessun font Aptos va introdotto: Word puo mostrare `Aptos (Corpo)` come sostituzione del copia/incolla, ma il riferimento resta il browser/runtime. Font locali ONSUS/KeepStore dichiarati nel template rispondono 200; nessun font 404 rilevato. Nessun fix CSS/font necessario, nessun cambio a codice/business/DB/gateway/email/auth e PR #197 resta fuori scope.

| Area top prodotto | ONSUS reale | KeepStore prima REV4 | Azione REV4 |
| --- | --- | --- | --- |
| Layout info | `.tf-product-info-list` flex/wrap con contenuto e buy box in flusso | `.ks-product-info-layout` forzava grid a due colonne interne | Neutralizzata la grid custom, ripristinato flex/wrap scoped |
| Summary | `.tf-product-info-content` trasparente, separatori interni e gap | Card con bordo, padding, ombra | Rimossa card custom, mantenuti gap e sezioni ONSUS |
| Feature list | `.product-fearture-list` lista verticale label/valore | Griglia di card 2 colonne | Ripristinata lista verticale con label fissa e nessuna card |
| Buy box | `.tf-product-info-choose-option` box semplice 1px/radius 6/gap 18 | Sidebar compressa max 340px | Buy box a larghezza piena nel flow ONSUS, senza ombra |
| Gallery/tab | Wrapper ONSUS senza card extra | Alcuni wrapper aggiungevano padding/card | Ridotto il custom senza toccare immagini o tab runtime |

| Elemento | ONSUS markup/classe | KeepStore prima REV5 | Differenza | Azione REV5 |
| --- | --- | --- | --- | --- |
| Wrapper top prodotto | `tf-sp-2`, `tf-main-product`, `row` | Sezione `ks-product-main-section/ks-product-shell-section`, row con `ks-product-shell-grid` | Ritmo custom sopra ONSUS | Ripristinata sezione `tf-sp-2` e row ONSUS |
| Gallery principale | `tf-product-media-wrap thumbs-default`, `tf-product-media-main` | Classi ONSUS piu `ks-product-gallery-*` | Wrapper visuale extra | Rimosse classi visuali, mantenuto solo object-fit runtime |
| Thumbnails | `tf-product-media-thumbs`, `.item img` | Thumb con classe `ks-product-thumb` | Dimensione/ritmo custom possibile | Rimossa classe visuale, ONSUS guida thumb |
| Colonna info | `tf-product-info-wrap`, `tf-product-info-list` | Classi ONSUS piu `ks-product-info-*` | Layout alternativo stratificato | Rimosse classi visuali, flex ONSUS nativo |
| Titolo | `h5.product-info-name.fw-semibold` | `h1.product-info-name` | Gerarchia diversa dal template | Tornato a `h5` ONSUS senza cambiare binding |
| Metadati | `product-info-rate-wrap`, caption/link | `ks-product-meta` aggiungeva ritmo custom | Custom non necessario | Rimossa classe visuale |
| Prezzo principale | `product-info-price` | Classe ONSUS piu `ks-product-price` | Serve solo bridge HTML prezzo VB | Tenuto bridge minimo sui frammenti prezzo |
| Lista caratteristiche | `product-fearture-list` | `ks-product-feature-grid` | Rischio box/grid custom | Rimossa classe visuale, lista ONSUS |
| In breve | `infor-bottom`, `product-about-list` | Gia ONSUS | Differenze solo dati reali | Preservato |
| Buy box | `tf-product-info-choose-option sticky-top` | `ks-product-buy/ks-product-purchase-card` | Sidebar/card custom | Rimosse classi visuali, ONSUS guida box |
| Quantita | `product-quantity`, `wg-quantity` | `ks-product-option/ks-qty-stepper` | Bridge non necessario salvo data attr | Rimossa classe option, preservati ID/data attr |
| Aggiungi al carrello | `product-box-btn`, `tf-btn` | `ks-product-actions` | Custom non necessario | Rimossa classe visuale, evento preservato |
| Vedi nel carrello | Seconda CTA ONSUS-style | Gia `tf-btn btn-gray` | Link reale KeepStore | Preservato |
| Tab prodotto | `flat-title-tab-product-des` | `ks-product-tabs` wrapper card | Card extra non ONSUS | Rimossa classe visuale |
| Spesso acquistati insieme | `tab-usually`, `card-usually` | Markup ONSUS con dati reali | CSS custom prezzo/card | Lasciato a ONSUS, bridge solo font/prezzo minimo |
| Card simili | `card-product style-img-border` | `ks-product-relation-section` customizzava card | Card diverse dal template | Rimossi override sezione/card custom |
| Card correlati | `card-product style-img-border` | Come sopra | Come sopra | Come sopra |
| Brand strip | `themesFlat`, brand item reale | Classe `ks-brand-strip` per dati reali | Serve contenimento logo/testo reale | Bridge minimo preservato |
| Visti di recente | `tf-sw-products`, `card-product` | Sezione con classi custom relation/recent | Custom non necessario | Rimosse classi sezione, ONSUS guida card |
| Service icon boxes | `tf-icon-box` | Classe wrapper runtime | Nessuna criticita | Preservato senza redesign |

| Elemento REV6 | ONSUS selector | ONSUS desktop computed/bounding rilevato | KeepStore runtime prima REV6 | Azione REV6 |
| --- | --- | --- | --- | --- |
| Breadcrumb | `.breakcrumbs` | `Inter` 15/400/24, flex, gap `0 10`, box 1250x25 | Non misurato runtime | Nessun override custom, eredita ONSUS |
| Titolo prodotto | `.product-info-name` | `Inter` 22/600/25, `#333e48`, box 610x50 | Non misurato runtime | Rimossi override titolo da `product-ui.css` |
| Categoria/metadati | `.infor-heading .caption` | `Inter` 12/400/22, box 610x22 | Non misurato runtime | Nessun override caption custom |
| Rating | `.product-info-rate-wrap` | flex, gap `0 16`, box 610x22 | Non misurato runtime | Lasciato a classi ONSUS |
| Prezzo/top | `.product-info-price` | flex, gap 10, box 610x36 | Non misurato runtime | Rimossi bridge prezzo `.ks-product-price`; HTML prezzo continua a usare classi ONSUS emesse dal VB |
| Lista feature | `.product-fearture-list` | flex, gap 4, box 610x100 | Non misurato runtime | Nessun grid/card custom |
| In breve | `.product-about-list` | grid, gap 10, box 610x170 | Non misurato runtime | Solo overflow reale preservato |
| Buy box | `.tf-product-info-choose-option` | bordo 1px, radius 6, gap 18, padding 20, box 610x510 | Non misurato runtime | Rimossi max-width/sticky custom; bridge solo responsive necessario |
| Quantita | `.wg-quantity` | flex, gap 2, box 94x30 | Non misurato runtime | Rimossa classe `ks-qty-stepper`, mantenuti ID/data attr/eventi |
| CTA add-to-cart | `.product-box-btn .tf-btn` | 15/600/24, padding 10x16, radius 8, h 44 | Non misurato runtime | Nessun font/padding custom; width bridge per WebForms |
| Tab | `.flat-title-tab-product-des .menu-tab-line` | flex, gap 30, padding 13x18, box 1248x51 | Non misurato runtime | Rimossi override `.tab-link` |
| Bundle | `#prd-usually` | block, box 1248x202 | Non misurato runtime | Layout ONSUS preservato |
| Card prodotti | `.tf-sw-products .card-product` | flex, gap 20, box 226x344 | Non misurato runtime | Rimossi override card/name/price e classe `ks-product-card-image` |
| Brand strip | `.tf-brand` | flex, gap 30, padding 25x0, box 1250x75 | Non misurato runtime | Solo contenimento logo/testo reale |
| Service icon boxes | `.tf-sw-iconbox` | block, box 1250x106 | Non misurato runtime | Nessun redesign |

KeepStore UI Typography Standard - ONSUS Computed Source of Truth:

| Elemento | ONSUS selector/computed | KeepStore selector prima REV3 | Azione REV3 | Expected KeepStore |
| --- | --- | --- | --- | --- |
| Titolo prodotto | `h5.product-info-name.fw-semibold`: `Inter`, 22px, 600, 25px, `#333e48` | `.product-info-name`: gia 22/600/25, margine tablet non coerente | margine responsive allineato | 22/600/25, `#333e48`, margin ONSUS |
| Prezzo principale | `.product-info-price h4.text-primary`: `Inter`, 30px, 500, 36px, `#ff3d3d` | `.product-info-price.ks-product-price .new-price`: 30px, 700, 36px | `font-weight:500` scoped | 30/500/36, `#ff3d3d` |
| Body/descrizione | `.body-text-3`: `Inter`, 14px, 400, 20px, `#333e48` | `.ks-product-description .body-text-3`: gia 14/400/20 | conferma valori espliciti | 14/400/20, `#333e48` |
| Tab | `.tab-link.product-title.fw-semibold`: `Inter`, 18px, 600, 24px, active `#004ec3` | `.flat-title-tab-product-des .tab-link`: desktop 18, mobile 16 | mobile riportato a 18 | 18/600/24, `#004ec3` |
| Nome card | `.name-product.body-md-2.fw-semibold.text-secondary.link`: 14px, 600, 22px, `#004ec3` | `.ks-product-relation-section .name-product`: gia 14/600/22 | conferma valori espliciti | 14/600/22, `#004ec3` |
| Prezzo card | `.new-price.price-text.fw-medium`: 20px, 500, 22px, `#333e48` | `.price-wrap .new-price`: gia 20/500/22 | conferma valori espliciti | 20/500/22, `#333e48` |
| CTA | `.tf-btn`: 15px, 600, 24px, padding 10px 16px, height 44px | `.ks-product-actions .tf-btn`: gia coerente | conferma valori espliciti | 15/600/24, padding 10x16, height 44 |
- KeepStore UI Typography Standard - ONSUS aligned: la foundation runtime deterministica approvata e `Arial, sans-serif`, perche il repository non include Inter e uno stack che preferisce un Inter eventualmente installato sul device produrrebbe rendering non deterministico. Ogni nuova pagina o refactoring deve partire dal template ONSUS reale, evitare famiglie inventate e CSS globali aggressivi e preservare la gerarchia ONSUS per title/subtitle/body/small/price/buttons, line-height, touch target, contrasto e densita. `GLOBAL-TYPOGRAPHY-ONSUS-AUDIT-1` e `1A` sono chiusi con esito A; `1B` normalizza solo le famiglie esplicite residue e `1C` e condizionale. Un eventuale Inter locale e un task separato con asset/pesi, `font-display`, CSP e smoke Germano.
- `AVAILABILITY-DISPTIPO-CORE-1A` apre il blocco disponibilita con helper centrale `App_Code/AvailabilityDisplayHelper.vb` basato su `Aziende.DispoTipo` gia in `Session("DispoTipo")`: `1` usa disponibilita sintetica con pallino e testo (`Disponibile` verde se `AvailableQty > LowStockThreshold`, `Pochi pezzi` arancione se `AvailableQty > 0 And AvailableQty <= LowStockThreshold`, `In arrivo` arancione se `AvailableQty <= 0 And IncomingQty > 0`, `Non disponibile` rosso se `AvailableQty <= 0 And IncomingQty <= 0`; fallback soglia bassa `2` se `ScortaMinima` e nulla/non valida), `2` abilita righe numeriche `Disponibilita`, `Impegnati`, `In Arrivo` e stato finale verde/rosso. Applicazione iniziale limitata a `articolo.aspx.vb`; home, catalogo, product card e carrello restano fuori scope per task dedicati. PR #196 e gia mergeata e resta preservata; nessun cambio a DB/schema/SP, prezzi, promo, carrello, ordine, gateway, email/template o auth/sessioni/cookie.
- `ARTICLE-AVAILABILITY-PROMO-LEGACY-1A` corregge il caso scheda prodotto `id=12384`: la disponibilita numerica `DispoTipo=2` usa i campi legacy reali `Giacenza`, `Impegnata`, `InOrdine` mostrando `Disponibilita: 10`, `Impegnati: 3`, `In Arrivo: 2` e stato verde `Disponibile`; quando `Aziende.DispoTipo=1` resta il pallino sintetico. La scheda ordina le righe `vsuperarticoli` per promo attiva piu vantaggiosa e aggiunge un renderer offerte read-only da `voffertedettagli`: prezzo listino/standard `40,00 euro`, prezzo promo finale `9,76 euro`, sconto `-76%`, righe `MULTIPLI 10 PZ. 36,00 euro`, `MINIMO 1 PZ. 12,20 euro`, `MULTIPLI 5 PZ. 9,76 euro`, date `25/06/2026-31/07/2026`. Nessun cambio a carrello/add-to-cart, quantita, TC, prezzi applicati all'ordine, DB/schema/SP, gateway, email/template, auth, home o catalogo.
- `ARTICLE-AVAILABILITY-PROMO-LEGACY-1B` / PR #198 REV2 completa solo la scheda prodotto: test ufficiale `articolo.aspx?id=12384`, tooltip accessibile su `In Arrivo` quando `InOrdine > 0`, promo valide solo con `DataInizio <= oggi <= DataFine`, articolo collegato, `AziendeId` uguale alla sessione sito e listino coerente. Le query promo restano mirate a articolo/azienda/listino e non devono pescare offerte di altri siti nello stesso DB; se il contesto azienda manca, la scheda non deve mostrare offerte generiche. Il confronto legacy Webaffare resta riferimento per disponibilita 10, impegnati 3, in arrivo 2, date `25/06/2026-31/07/2026`, sconto `-76%` e prezzo finale `9,76 euro`. Home, catalogo, carrello, `cart_add.aspx` e `ordine.aspx` restano fuori scope.
- `ARTICLE-AVAILABILITY-PROMO-LEGACY-1B` / PR #198 REV3 chiarisce il test su DB live: il valore numerico atteso per `Disponibilita` va letto dal DB corrente (il caso `id=12384` puo mostrare `9` dopo fatturazione, non piu `10` fisso), mentre con `Aziende.DispoTipo=2` le righe `Disponibilita`, `Impegnati` e `In Arrivo` devono essere sempre visibili. La scheda articolo rinfresca il contesto azienda/listino/IVA/DispoTipo dal dominio corrente usando la fonte `Aziende` gia esistente, cosi Host `www.webaffare.it` resta su listino 10 e prezzi IVA inclusa senza hardcode; il renderer promo mantiene filtro azienda/listino/data sulla vista dedicata e usa come fallback read-only le colonne offerta delle sole righe `vsuperarticoli` dell'articolo/listino corrente quando la vista promo dedicata non restituisce righe. Nessun cambio a Home/catalogo/carrello/`cart_add.aspx`/ordine, DB/schema/SP, gateway, email/auth.
- `ARTICLE-AVAILABILITY-PROMO-LEGACY-1B` / PR #198 REV4 limita il testo informativo `In Arrivo` a un trigger compatto `i` con `title`/`aria-label`/tooltip CSS scoped: la riga resta `In Arrivo: 2`, il testo lungo non e piu un blocco HTML fisso nella buy-box e compare solo su hover/focus. Logica `DispoTipo=2`, disponibilita numerica, promo listino 10 Webaffare, prezzi IVA inclusa, add-to-cart e scope non-catalogo/non-carrello/non-ordine restano invariati.
- Chiusura finale del blocco PR #196-#199 della scheda articolo: PR #196 layout ONSUS, PR #197 disponibilita `Aziende.DispoTipo`, PR #198 recupero disponibilita/promo/offerte/listino legacy e PR #199 deduplica visuale sono mergeate su `frontend-rebuild`; HEAD stabile post-merge PR #199 `94c328c16f172b352bc1a5a99915dcc56b766c50`, `main` invariato `976e99f17cabc8a5c6a8715463444edfeaadcd91`. E chiuso quel perimetro specifico, non l'intera pagina `articolo.aspx`; typography globale, quantita PDP, side cart e funzioni future restano task separati. Test ufficiale: `articolo.aspx?id=12384`, variante `articolo.aspx?id=12384&TCid=-1`, riferimento legacy `https://www.webaffare.it/articolo.aspx?id=12384&TCid=-1`. Regola campo: usare sempre `DispoTipo` (`1` sintetico/pallini, `2` numerico), mai `DispTipo`. Con `DispoTipo=2` validati `Disponibilita: 9`, `Impegnati: 3`, `In Arrivo: 2`, stato `Disponibile` verde; `9` e corretto per DB live aggiornato dopo fatturazione. Tooltip `In Arrivo`: icona info reale inline SVG, nessun asset immagine aggiunto, fallback `title`/`aria-label`/`data-tooltip`, desktop/mobile OK e non copre prezzo/CTA. PR #199 stabilisce una sola fonte visuale commerciale: il blocco alto `.infor-center` non ripete prezzo/stock/promo, mentre la buy-box `.tf-product-info-choose-option` resta fonte unica per prezzo, disponibilita, promo/offerte, quantita e CTA. Promo Webaffare/listino 10: prezzi IVA inclusa, prezzo listino `40,00`, prezzo standard `40,00`/`36,00` dove previsto, prezzo finale `9,76`, sconto `76%`, `MULTIPLI 10`, `MINIMO 1`, `MULTIPLI 5`, date `25/06/2026-31/07/2026`, promo scadute escluse da filtro data. Multi-azienda: stesso DB per piu siti, filtro `AziendeId` + listino + data; Webaffare usa listino 10 e le promo non devono attraversare aziende/listini. Home, catalogo, product card, carrello, `cart_add.aspx`, ordine, DB/schema/SP, gateway, email e auth non sono stati modificati da PR #198/#199. `Public/assets/images/articoli/` resta asset directory non tracciata fuori scope.
- `CART-PROMO-PRICE-REVALIDATION-1A` aperto su branch `task/cart-promo-price-revalidation-1a`: audit conferma che `cart_add.aspx.vb` rientra nel flusso storico `aggiungi.aspx.vb`, dove prezzo/listino/promo vengono risolti da `vsuperarticoli` e salvati in `Newcarrello`; `carrello.aspx.vb` aggiorna quantita e dati IVA senza sostituire il prezzo unitario; `ordine.aspx.vb` crea il documento solo tramite `Carrello_Documento`. Il fix introduce revalidazione centrale prima della conferma finale e guard difensiva prima di `Carrello_Documento`: se promo/listino/prezzo cambiano, il carrello viene aggiornato, viene mostrato avviso con vecchio/nuovo prezzo e l'utente deve riconfermare. In caso di variazione non partono ordine, gateway, email o svuotamento carrello. Nessun cambio a DB/schema/SP, gateway core, email/template, auth, Home/catalogo/scheda prodotto o PR coupon.
- REV2 PR #200: `CartPriceRevalidationHelper` mantiene il prezzo base da `vsuperarticoli`, ma applica una promo solo se il dettaglio offerta risulta collegato alla stessa azienda della sessione (`AziendaID`/`AziendeId`) tramite `voffertedettagli.AziendeId`; se il contesto azienda manca o non coincide, la promo non viene usata per la riconferma carrello. Nessun cambio a DB/schema/SP, gateway, email/template, auth, Home/catalogo/scheda prodotto o PR coupon.
- `PROMO-OFFERS-LEGACY-DISPLAY-1A` / PR #204 e chiusa su `frontend-rebuild` con merge commit `daae01b0ab0cf2e52afc685c047ddd45779fad89`: il display commerciale promo e stato esteso in modo read-only e coerente a scheda articolo, catalogo/product card e carrello usando `ProductPromotionDisplayHelper`, fonte preferita `vOfferteDettagli` e fallback controllato `vsuperarticoli`, senza cambiare il calcolo ordine. Caso riferimento `id=12384`: prezzo principale qty 1 `12,20`, miglior prezzo `9,76`, sconto `-76%`, offerte `MULTIPLI 10`, `QUANTITA/MINIMO 1`, `MULTIPLI 5`, validita `25/06/2026 - 31/07/2026`; eliminata la duplicazione `PROMO PROMO`, date senza orario dopo PR #203, JSON-LD prezzo principale preservato a `12.20`.
- `CART-SUMMARY-VAT-CONSISTENCY-1A` / PR #205 e chiusa su `frontend-rebuild` con merge commit `1d87f083f488f06acbdd38b617ee8f7d68f276a0`: il riepilogo carrello usa `TotaleMerce` per `Totale articoli`, evitando l'uso errato di `lblImponibile` in contesti IVA inclusa. Per utenti anonimi/Webaffare il subtotale visuale resta lordo/IVA inclusa e coerente con le righe prodotto; per `IvaTipo=1` resta preservata la vista netta/IVA esclusa storica. Smoke finale su quantita 1/3/5/10: `12,20`, `36,60`, `48,80`, `97,60`; nessun cambio a prezzi unitari, promo, ordine, gateway, email, DB/schema/SP o auth.
- Smoke conclusivo `FINAL-SMOKE-PROMO-CART-VAT-1A = A`: scheda articolo, catalogo/card, carrello anonimo/Webaffare, carrello IVA inclusa, carrello `IvaTipo=1`, ordine protetto via `accessonegato.aspx`, Home e flussi principali verificati senza errori runtime; nessun ordine live, gateway o email live generati; build/precompile, `git diff --check` e secret scan OK. La directory non tracciata `Public/assets/images/articoli/` resta esclusa e non va inclusa in task documentali o merge.
- `CART-TCID-DATABINDING-ERROR-1A` / PR #208 e chiusa su `frontend-rebuild` con merge commit `3cf52876ecec1033fdde3ab51d13a7c4a25390f9`: corretto l'errore runtime di `carrello.aspx` `DataBinding: 'System.Data.DataRowView' non contiene una proprieta con nome 'TCid'`, osservabile dopo refresh/F5, sessione lunga/nuova o datasource in certe condizioni. Causa: markup con `Eval("TCid")` mentre la view/datasource espone `TCId`, e due `SqlDataSource` dichiarative non selezionavano esplicitamente `vcarrello.TCId`. Fix: aggiunto `vcarrello.TCId` alle datasource e sostituiti gli `Eval("TCid")` con `Eval("TCId")`, preservando il parametro URL storico `&TCid=`. Test: carrello vuoto HTTP 200, carrello con articolo `12384&TCid=-1` HTTP 200, refresh/F5/sessione nuova senza errore, `ordine.aspx` solo protezione/redirect, PR #204 promo non regressa, PR #205 IVA/totali non regressa, build/precompile, `git diff --check` e secret scan OK. Nessun cambio a DB/schema/SP, gateway, email, auth, ordine, prezzi/promo/IVA o asset; `Public/assets/images/articoli/` resta non tracciata e fuori commit.
- `CART-TAGLIA-DATABINDING-ERROR-1A` / PR #212 e chiusa su `frontend-rebuild` con merge commit `7c6febc951d2476ac0fd5fc121b7387f3f04a8ce`; dopo PR #211 docs l'HEAD stabile e `5e3f44112e9a3388177b5306b23ac19cc89e6e87`. Corretto l'errore runtime di `carrello.aspx?loginrequired=1#ksCartLoginRequired` dopo inattivita/sessione scaduta e refresh/F5: `DataBinding: 'System.Data.DataRowView' non contiene una proprieta con nome 'taglia'` nello stack `ASP.carrello_aspx.__DataBinding__control8`. Causa: i binding `Eval("taglia")`/`Eval("colore")` in `gvArticoliGratis` e `Repeater1` richiedevano campi non esposti dalle datasource dichiarative `sdsArticoli` e `sdsArticoli_Spedizione_Gratis`, famiglia bug analoga a PR #208 ma su campi diversi. Fix: aggiunti `LEFT OUTER JOIN` verso `articoli_tagliecolori`, `taglie`, `colori` ed esposti `taglie.descrizione AS taglia` e `colori.descrizione AS colore`; la scelta LEFT preserva righe carrello senza varianti/taglia/colore, incluso `TCid=-1`. Validazioni post-merge: mergeability GitHub `true`, merge simulato locale OK, build/precompile OK, `git diff --check` OK, secret scan OK, nessun nuovo riferimento legacy `Public/Images/`, smoke `carrello.aspx` e `carrello.aspx?loginrequired=1#ksCartLoginRequired` HTTP 200, refresh/F5 e sessione isolata OK, articolo `12384&TCid=-1` visibile dopo add/refresh/loginrequired, nessun errore `taglia`, `colore`, `TCid`, `DataRowView` o stack trace; home/catalogo/scheda articolo OK e header catalog PR #210 presente. Nessun cambio a prezzi, promo, IVA/totali, ordine, gateway, PayPal, email/auth, DB/schema/SP, header/menu o asset.
- `CART-LOGINREQUIRED-FAST-PATH-1A` / PR #215 e chiusa su `frontend-rebuild` con merge commit `0b925a0935398021f3b653ca2efdf27373507d7a`: corretto il timeout di `carrello.aspx?loginrequired=1#ksCartLoginRequired` dopo inattivita/sessione scaduta e refresh/F5, distinto dai precedenti bug DataBinding `TCid`, `taglia` e `colore`. Diagnosi: la pagina mostrava il pannello `pnlLoginRequired`, ma continuava a configurare e bindare il carrello completo con `vcarrello`, promo, spedizioni, pagamenti, riepiloghi e `FillTableInfo()`, causando lavoro inutile fino a `System.Web.HttpException: Timeout della richiesta`. Fix: fast-path in `Page_Load` solo quando `loginrequired=1` e `LoginId <= 0`; in quel caso mostra il pannello login required e salta `ConfigureCartDataSources()`, `FillTableInfo()`, promo, spedizioni, pagamenti e riepiloghi, senza usare `Response.End` e senza aumentare il timeout ASP.NET. La prima versione della PR era troppo ampia perche basata solo su `loginrequired=1`; la guard corretta richiede anche utente anonimo/sessione scaduta. Smoke post-merge e conferma manuale utente dopo inattivita: OK, F5 OK, nessun timeout, nessun errore `TCid`/`taglia`/`colore`, articolo `12384&TCid=-1`, Home/catalogo/scheda articolo OK. Runtime locale ancora generalmente lento: eventuale performance audit resta backlog separato. Preservati prezzi/promo/IVA/totali, ordine/checkout/gateway, PayPal, email/auth, DB/schema/SP, header PR #210 e compare PR #214.
- `CART-STALE-SESSION-F5-TIMEOUT-1A` / PR #220 e chiusa su `frontend-rebuild` con merge commit `f214063059ae4742e082a41b6f67c452cb0fe32c`: estende la correzione timeout al caso generale `carrello.aspx` normale dopo lunga inattivita/sessione scaduta o stale + F5, diverso da PR #215 che copriva solo `carrello.aspx?loginrequired=1`. Fix in `carrello.aspx.vb`: guard iniziale `IsStaleLoggedCartSessionRequest()`, fast-path controllato senza redirect, pannello login-required esistente, ritorno da `Page_Load` prima di `Aggiorna_Prezzi_Carrello()`, `ConfigureCartDataSources()` e `FillTableInfo()`, DataSourceID repeater/summary scollegati e binding pesanti evitati. Utente loggato valido e carrello anonimo normale preservati; nessun loop redirect. Smoke tecnico Codex: `carrello.aspx` HTTP 200, `carrello.aspx?loginrequired=1` HTTP 200, simulazione sessione scaduta/stale senza timeout, build/precompile OK, `git diff --check` OK, secret scan OK. Smoke reale Germano: login effettuato, `carrello.aspx` aperto, attesa oltre 5 ore, F5 sulla stessa pagina, esito OK con pannello "Accedi per inviare l'ordine" e nessun `[HttpException: Timeout della richiesta]`. Nessun cambio a DB/schema/SP, web.config, gateway/PayPal, ordine/checkout, prezzi/promo/IVA/totali, search/AI, header/compare, CSS/JS o asset.
- `COMPARE-TRIGGER-NORMALIZE-SMOKE-1A` / PR #214 e chiusa su `frontend-rebuild` con merge fast-forward `0c4738d33880bf2bbfbfb5d8fd5116e4adc61446`: normalizzati i trigger compare non-ProductCard in `Default.aspx.vb`, `Public/ui/controls/SiteHeader.ascx` e `articolo.aspx`. Compare/offcanvas era gia presente con offcanvas globale `#compare`, pagina `compare.aspx`, JS `keepstore-product.js`, `localStorage` e chiave `ks_compare_products`; ProductCard era gia corretta. Il confronto ONSUS ha confermato il pattern `href="#compare"`, `data-bs-toggle="offcanvas"`, offcanvas `#compare` e icona `icon-compare1`; il fix aggiunge dove mancavano `data-bs-target="#compare"` e `aria-controls="compare"`, preservando `href`, `data-bs-toggle`, classi ONSUS/KeepStore, `js-ks-compare` e `data-ks-*`. Non modificati ProductCard, JS, storage key, `compare.aspx`, carrello/ordine, fast-path PR #215, header catalog PR #210, DB/schema/SP, gateway/email/auth e PayPal. Validazioni: PR rebased su base aggiornata, mergeability GitHub true, merge-tree OK, build/precompile OK, `git diff --check` OK, secret scan OK, smoke HTTP 200 su home, catalogo, scheda articolo, `compare.aspx`, carrello e `loginrequired`; nessun errore `TCid`/`taglia`/`colore`, `DataRowView` o timeout. Conferma manuale utente: home/catalogo compare prodotto OK, scheda articolo compare OK, mobile link `Confronta prodotti` OK, `compare.aspx` OK, carrello normale OK, carrello `loginrequired` OK. Backlog separato: eventuale polish grafico/commerciale di `compare.aspx` va fatto in task dedicato, confrontando prima ONSUS e componenti gia presenti, senza mischiarlo con la normalizzazione trigger chiusa.
- `HEADER-CATALOG-ALL-CATEGORIES-1A` / PR #210 e chiusa su `frontend-rebuild` con merge commit `85e3e06460068a32cb1b56cd15a37d9120565373` e HEAD PR `4745d330b58ad22a02064c43564fb39c863ac5e5`: il catalogo desktop reale KeepStore e stato separato dal `main-nav-menu` e riallineato al pattern ONSUS "All Categories" tramite blocco `ks-header-all-categories`, rendering settori/categorie/tipologie in `SiteHeader.ascx.vb`, immagini settore da `/Public/assets/images/settori/`, fallback immagini settore, CSS scoped in `Public/assets/keepstore/css/theme-overrides.css` e cache-busting `theme-overrides.css?v=20260629-headercatalog2` in `Page.master`. Rimossi dal blocco catalogo i CSS inline strutturali; nessun JS modificato e nessun nuovo path legacy `Public/Images/`. Preservati search, account, mini cart, mobile/offcanvas, carrello, promo, PayPal/gateway, email/auth e DB/schema/SP. Validazioni: mergeability GitHub `true`, merge simulato locale OK, build/precompile OK, `git diff --check` OK, secret scan OK, smoke HTTP home/catalogo/articolo `12384&TCid=-1`/carrello OK, nessun errore `TCid`, mobile/offcanvas 390px OK con "Menu / Tutti i settori" e 791px stabile senza overflow. Validazione visuale manuale pre-merge: homepage desktop chiusa OK, catalogo aperto OK, menu non esplode piu in altezza, immagini settore presenti, mobile offcanvas OK. Smoke post-merge classificato B solo per limite del browser automation su `:hover`, non per regressione funzionale; non riaprire il fix per questo. Nota base aggiornata: dopo PR #210 e stata mergeata PR #212 carrello taglia/colore con HEAD `7c6febc951d2476ac0fd5fc121b7387f3f04a8ce`, task separato da documentare fuori da questa chiusura header. Backlog separato: eventuale rifinitura mobile categorie/ONSUS tab, ulteriore polish desktop solo con screenshot/anomalie reali, compare/offcanvas e ricerca AI/header/home; PayPal non va riaperto.
- `HEADER-CATALOG-MEGAMENU-READABILITY-1A` e chiuso su `frontend-rebuild` con HEAD stabile `3d75d5349df857f1b594760590bbdc22c553f2d8`: migliorata la leggibilita del mega menu desktop `Catalogo` nell'header, solo per lo scope desktop. File runtime modificati nel task: `Page.master` e `Public/assets/keepstore/css/theme-overrides.css`. Causa corretta: il primo CSS colpiva soprattutto il pannello settore non visibile subito all'apertura, mentre la lista settori reale restava visivamente quasi invariata; aggiornato anche il cache-buster di `theme-overrides.css` in `Page.master`. Stile finale: categorie/titoli principali piu evidenti, colore tema ONSUS/KeepStore `var(--primary-2, #D80027)` senza arancio e-stayon, titoli uppercase con font-family `"Inter", serif`, circa `19px / 800`, sottocategorie scure circa `16px / 24px`, linea divisoria sottile sotto i titoli, colonne piu ordinate e nessun overflow desktop rilevato. URL preservati: `articoli.aspx?st=...`, `articoli.aspx?st=...&ct=...`, `articoli.aspx?st=...&ct=...&tp=...`. Il menu mobile non e stato modificato e non va dichiarato visualmente OK per questo task perche lo scope era desktop. Smoke visuale Germano OK, build/precompile OK, `git diff --check` OK e secret scan OK. La CTA prodotto `Acquista` su HOME e stata poi chiusa da `HOME-BUY-CTA-ACQUISTA-1A/1B/1C`; backlog separati da non segnare come completati: CTA prodotto `Acquista` su scheda prodotto/PDP, immagini prodotto piu brillanti, `BUG-ADD-TO-CART-ANON-MOBILE-LOGIN-MESSAGE` se ricompare, side cart/offcanvas ONSUS, quantita gia nel carrello su `articolo.aspx`, revisione menu Catalogo mobile e riallineamento `HomeDepartmentsMenu`.
- `AI-ASSISTED-COMMERCE-SEARCH-BLUEPRINT-1A` apre solo il livello architetturale/documentale dell'assistente acquisto AI multi-merceologia: nuovo documento `docs/KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md`, nessun runtime implementato. La regola e che l'assistente futuro non abbia domande hardcoded Taikun-only, ma derivi comportamento da catalogo reale del sito/azienda: settori, categorie, tipologie, marche, descrizioni, schede tecniche dove auditabili, disponibilita, promo, prezzi, recent searches e recent viewed. La blueprint distingue ricerca deterministica attuale, assistente locale futuro non-LLM e AI/LLM opzionale successiva con task privacy dedicato; nessuna API esterna, tabella, endpoint, chatbot o correzione search viene introdotta da questo task. Roadmap prioritaria: `SEARCH-SUGGEST-CATALOGURL-PARAM-1A`, `SEARCH-SUGGEST-ERROR-HARDENING-1A`, `SEARCH-RANKING-ALIGN-1A`, `SEARCH-ZERO-RESULTS-ASSIST-1A`, poi audit/prototipo assistente.
- Blocco search suggest/ranking chiuso cumulativamente: PR #222 mergeata con commit `a78636863ceb6daac3dc53ebfb35df87f1180f54` ha corretto `search_suggest.aspx.vb` in `BuildCatalogUrl`, generando `disponibile=1` invece di `available=1` e `ordinamento=...` invece di `sort=...`, allineando i parametri ai valori realmente letti da `articoli.aspx` senza cambiare ranking o query SQL; PR #223 mergeata con commit `a7e3eaccec936c777e14f3f1d8d9e2471310c282` ha rimosso `ex.Message` dal JSON pubblico di `search_suggest.aspx.vb`, mantenendo formato compatibile `ok=false` + campo `error` con messaggio generico `Servizio suggerimenti temporaneamente non disponibile.` e preservando ranking/query/catalogUrl; PR #224 mergeata con commit `3738d33b88619daa0572dd44597de432b59d3a01` ha aggiornato solo `articoli.aspx.vb`, ampliando `SearchScore` catalogo per avvicinarlo al suggest con `DescrizioneHTML` solo nello scoring, marca+descrizione, tassonomie e token multi-parola, senza modificare `search_suggest.aspx.vb`, filtro principale, `Export +500`, Codice/EAN o query numeriche. Test registrati: `hp` non peggiorato e resta `18933,20018`; `stampante hp` migliorato verso suggest con `20810,17698`; `12384` invariato con nessun ID catalogo e suggest `total=0`; smoke suggest/articoli/carrello OK, build/precompile OK nelle PR runtime, `git diff --check` OK e secret scan OK. Nessun cambio a DB/schema/SP, gateway/PayPal/email/auth, carrello/checkout/ordine, CSS/JS, web.config o asset.
- `SEARCH-ZERO-RESULTS-CATALOG-ASSIST-1A` / PR #226 e chiusa su `frontend-rebuild` con merge commit `60dfa32878e7777f6bd4ef9efe1ef47374969764`: `articoli.aspx` ora ha un `EmptyDataTemplate` zero-results piu utile, mostra la query corrente con HTML encoding, preserva la CTA `Reset filtri`, aggiunge `Vai al catalogo` e genera solo chip/link sicuri derivati dai token della query. I fallback statici merceologici/elettronica (`Toner stampante`, `Notebook ricondizionato`, `Accessori smartphone`, `Cavi USB`) sono stati rimossi per mantenere KeepStore multi-merceologia; nessuna dichiarazione AI attiva e nessun prodotto inventato. `search_suggest.aspx.vb`, ranking/SearchScore, query DB, DB/schema/SP, PayPal/gateway/email/auth, carrello/checkout/ordine, CSS/JS e asset non sono stati modificati. Test Codex: zero-results HTTP 200, encoding caratteri speciali OK, `articoli.aspx?q=hp` OK, suggest zero-results OK, carrello OK, build/precompile OK, `git diff --check` OK, secret scan OK. Smoke manuale Germano: `articoli.aspx?q=zzzznonexistentkeepstore` visualmente OK, query mostrata, CTA presenti, nessun fallback elettronica/Taikun hardcoded, `articoli.aspx?q=hp` mostra prodotti normalmente.
- Blocco filtri catalogo/performance sidebar chiuso cumulativamente: PR #228 mergeata con commit `d2e4d567755da1fec2587068b327177aa3185377` ha modificato solo `articoli.aspx.vb`, differendo/evitando facet laterali e `showFilters()` quando una ricerca con `q` produce zero risultati, usando `lvProdotti.Items.Count` gia disponibile in `PreRender`; query prodotti principale, ranking/SearchScore ed empty-state PR #226 restano invariati. Beneficio indicativo: zero-results circa `10,7s` -> circa `8,8s`; `12384` circa `10,4s` -> circa `8,3s`. PR #229 mergeata con commit `196cbec713e8b40a03fc8a8aa442773d39ead209` ha riallineato la sidebar catalogo in `articoli.aspx`, `articoli.aspx.vb` e `Public/assets/keepstore/css/catalog-ui.css`: ordine finale `Marche > Tipologie > Gruppi > Sottogruppi > Disponibilita > Varianti`, rimozione del facet laterale `Categoria` dopo rettifica Germano, `ct` querystring preservato, label legacy `Categorie/Sottocategorie` eliminate e label `Gruppi`/`Sottogruppi` corrette; query prodotti principale e SearchScore invariati. PR #230 mergeata con commit `54850ea30b7168e796b0268205250de41c703efd` ha modificato solo `Public/assets/keepstore/css/catalog-ui.css`, con CSS scoped sotto `#ksCatalogPage` e selettori reali `#ksCatalogPage .widget-facet.facet-fieldset`, `.facet-title.title-sidebar`, `.box-fieldset-item`, `.ks-filter-list`, `.fieldset-item`, compattando realmente la spaziatura della sidebar senza toccare `articoli.aspx.vb`; smoke visuale Germano OK, spaziatura piu compatta e ordine invariato. Motivazione stabile: il catalogo deve seguire la logica del gestionale KeepStore; `Settori/st` resta livello alto/header, `ct` resta supportato come querystring ma non come blocco sidebar in questa fase. Linea ONSUS: avvicinarsi a `shop-default.html` per micro-task progressivi su dati reali KeepStore, senza copiare ONSUS in blocco. Prossimo step consigliato dopo PR #232: `CATALOG-SIDEBAR-CATEGORIES-ONSUS-AUDIT-1A`; solo dopo valutare price range, grid/list e review con audit dedicati.
- `CATALOG-APPLIED-FILTERS-ONSUS-1A` / PR #232 e chiusa su `frontend-rebuild` con merge commit `950ac4c31cadbad9fcda36ccab545a6103072cd7`: `articoli.aspx`, `articoli.aspx.vb` e `Public/assets/keepstore/css/catalog-ui.css` integrano i filtri applicati in stile ONSUS-like con `.meta-filter-shop`, `#applied-filters`, `.remove-all-filters` e `icon-close`. I chip singoli sono visibili e rimuovono il singolo filtro via GET sicuro; `Rimuovi tutto` e stato reso visibile, vicino ai chip, leggibile e funzionante dopo smoke visuale Germano; il remove-all preserva `st/ct` come contesto. Non sono piu mostrati chip tecnici solo ID: se una label non e risolta viene usato un fallback descrittivo come `Marca selezionata`. La sidebar resta invariata nell'ordine `Marche > Tipologie > Gruppi > Sottogruppi > Disponibilita > Varianti`; zero-results PR #226 resta preservato. Query prodotti principale, ranking/SearchScore, DB/schema/SP, `search_suggest.aspx.vb`, ProductCard, gateway/PayPal/email/auth, carrello/checkout/ordine e JS non sono stati modificati; il CSS e scoped sotto `#ksCatalogPage`. Test registrati: filtri singoli OK, filtri combinati OK, contesto `st/ct` OK, zero-results OK, smoke suggest OK, smoke carrello OK, build/precompile OK, `git diff --check` OK e secret scan OK. Smoke visuale Germano finale OK: chip visibili, `Rimuovi tutto` vicino ai chip, testo leggibile e sidebar invariata.
- `CATALOG-SIDEBAR-CATEGORIES-ONSUS-1A` / PR #234 e chiusa su `frontend-rebuild` con merge commit `8a2e089b75e11d119af82e97134b954a48226b6f`: `articoli.aspx` aggiunge sopra i facet una navigazione catalogo ONSUS-like, rinominata correttamente `Settori` dopo rettifica Germano perche il primo livello usa dati `CatalogMenuSector` e querystring `st`. Non e un filtro facet e non reintroduce `Categoria` nella sidebar: i facet restano `Marche > Tipologie > Gruppi > Sottogruppi > Disponibilita > Varianti`, mentre `ct` resta supportato come querystring per le categorie. La gerarchia visuale e `Settori > Categorie`, con dati reali KeepStore da `CatalogMenuProvider`, categorie del settore attivo, URL puliti `articoli.aspx?st=...` e `articoli.aspx?st=...&ct=...`, senza trascinare `q`, `mr/tp/gr/sg`, `disponibile`, varianti o paging. `LoadCatalogMenuCached()` usa key `KeepStore:CatalogMenuProvider:Menu` e durata 600s; il rendering e limitato a 12 settori e 10 categorie del settore attivo. Nessun hardcoding merceologico, query prodotti principale, ranking/SearchScore, DB/schema/SP, `search_suggest.aspx.vb`, gateway/PayPal, carrello/checkout/ordine e JS restano invariati; il CSS e scoped sotto `#ksCatalogPage`. Applied filters PR #232 e zero-results PR #226 restano preservati. Performance warm-cache registrata: `q=hp` circa 18-20s, `st` circa 18s, `st+ct` circa 15s, zero-results circa 8s, suggest circa 0,7s; smoke visuale Germano post-merge OK su `articoli.aspx?q=hp`, `articoli.aspx?st=1`, `articoli.aspx?st=1&ct=1` e `articoli.aspx?q=zzzznonexistentkeepstore`.
- `CATALOG-PRODUCT-CARD-RUNTIME-CSS-POLISH-1A` / PR #236 e chiusa su `frontend-rebuild` con merge commit `bc0d157e89239ef732481caac945be2eead81f37`: rifinita la card prodotto runtime reale `article.card-product`, non il fallback `.ks-catalog-card`, con CSS scoped sotto `#ksCatalogPage` in `Public/assets/keepstore/css/catalog-ui.css`. La diff finale modifica solo il CSS; i commit intermedi su `ProductCard.ascx` sono stati neutralizzati dal fix DB-first immagini e `ProductCard.ascx` non resta modificato rispetto alla base. Tipografia ONSUS verificata su `shop-default.html` / `css/styles.css`: `font-family: "Inter", serif`, titolo prodotto `14px / 600 / 22px`, prezzo `20px / 500 / 22px`, dettagli codice/disponibilita `12px / 22px`. Migliorati immagini, titolo, prezzo, disponibilita/codice e spaziature card. Regola immagini: se esiste riferimento/path immagine da DB si usa quello; non si coprono path DB esistenti con placeholder browser-side; placeholder ONSUS `/Public/assets/images/img/placeholder.svg` solo se `ImageUrl` e assente/null/vuoto; `onerror` aggressivo rimosso/neutralizzato. Eventuali immagini rotte con path DB presente restano backlog separato asset/path. Nessun asset aggiunto, nessun nuovo path legacy `Public/Images/`, `ProductCard.ascx.vb`, `ThemeManager.vb`, `ProductPromotionDisplayHelper.vb`, add-to-cart, quantita/checkbox/selezione multipla, wishlist/compare/quickview, query prodotti principale, ranking/SearchScore, DB/schema/SP, `search_suggest.aspx.vb`, carrello/checkout/ordine, gateway/PayPal/email/auth e Settori/sidebar/filtri/applied filters restano invariati. Smoke visuale Germano OK. Tempi registrati: `q=hp` circa 17,83s, `st` circa 18,27s, `st+ct` circa 14,55s, `tp` circa 17,20s, zero-results circa 7,57s, suggest circa 0,80s, carrello circa 9,76s / 8,07s.
- `CATALOG-CARD-QUANTITY-CHECKBOX-CSS-GUARD-1A` / PR #238 e chiusa su `frontend-rebuild` con merge commit `07ac8cd42eb812d2b5ccad431e475690e9c09512`: polish CSS-only dell'area quantita/checkbox/selezione multipla nella card catalogo runtime `article.card-product`, modificando solo `Public/assets/keepstore/css/catalog-ui.css` con CSS scoped sotto `#ksCatalogPage`. La quantita risulta piu ordinata, la checkbox meno legacy, input quantita e bottoni `-`/`+` restano visibili e preservati. Nessuna modifica funzionale: invariati `tbQuantita`, `CheckBox_SelezioneMultipla`, hidden field `hfID`/`hfTCId`, `data-ks-*`, `ProductCard.ascx`, `ProductCard.ascx.vb`, `articoli.aspx`, `articoli.aspx.vb`, JS catalogo/card, link `cart_add.aspx`, add-to-cart, wishlist, compare e quickview. In PR #238 non era ancora stato aggiunto nessun bottone globale "aggiungi selezionati"; quell'azione e stata poi chiusa separatamente con PR #240. Query prodotti principale, ranking/SearchScore, DB/schema/SP, `search_suggest.aspx.vb`, carrello/checkout/ordine, gateway/PayPal/email/auth, Settori/sidebar/filtri/applied filters e immagini/path asset restano invariati; card typography PR #236 preservata. Smoke visuale Germano OK / "TUTTO OK". Performance ricontrollata: pre-merge `q=hp` circa 18,6s, `st` circa 20,3s, `st+ct` circa 13,4s, zero-results circa 8,1s, suggest circa 0,7s, carrello circa 10,7s / 11,3s; post-merge `q=hp` circa 18,6s, `st` circa 19,7s, `st+ct` circa 13,3s, zero-results circa 8,1s, suggest circa 0,7s, carrello circa 10,0s / 8,6s.
- `CATALOG-MULTISELECT-ADD-BUTTON-1A` / PR #240 e chiusa su `frontend-rebuild` con HEAD `166f5e90fa8a8d84ee0d5dc74c7699f0e96a44cb`: completata la selezione multipla dal catalogo in `articoli.aspx` con CTA globale `Aggiungi selezionati al carrello`. Flusso utente validato: spuntare `Seleziona` sulla card prodotto, impostare la quantita e usare la CTA globale nel riquadro footer `Acquisto multiplo`. UX finale: label `Seleziona` visibile e cliccabile vicino al checkbox, icona CSS multi-check accanto alla label e nel riquadro `Acquisto multiplo`, istruzioni chiare, CTA globale distinta da checkout/pagamento e stato hover/active/focus corretto senza virare al nero al click; desktop e mobile verificati. Il fix usa il flusso carrello server-side esistente e non modifica `ProductCard.ascx`, `ProductCard.ascx.vb`, JS, `cart_add.aspx`, `aggiungi.aspx`, query prodotti/ranking/search, DB/schema/SP, checkout/ordine/PayPal/gateway/email/auth, Settori/sidebar/filtri/applied filters o immagini/path asset. Smoke funzionale Codex OK, smoke visuale/funzionale Germano OK, build/precompile OK, `git diff --check` OK e secret scan OK. Le directory non tracciate `Public/assets/images/articoli/` e `Public/assets/images/settori/` restano escluse dai commit. Backlog separati da non segnare come chiusi: quantita gia presente nel carrello su `articolo.aspx`, side cart/offcanvas ONSUS dopo add-to-cart, audit funzioni mancanti `articoli.aspx` vs ONSUS e audit immagini rotte/path DB.
- `CATALOG-BUY-CTA-ACQUISTA-1A/1B` e chiusa su `frontend-rebuild` con HEAD `d5000b18e93e2857d591e3443273cec874b2fe09`, includendo i commit runtime `2f0b7c715c1c02666f13961fd64b024d9d63d044` e `d5000b18e93e2857d591e3443273cec874b2fe09`. Scope: solo catalogo `articoli.aspx` tramite `ProductCard` runtime; file modificati `Public/ui/controls/ProductCard.ascx`, `Public/ui/controls/ProductCard.ascx.vb` e `Public/assets/keepstore/css/catalog-ui.css`. UX chiusa: rimossa dall'area quick actions sopra Wishlist la CTA/tooltip generica `Carrello` / `Aggiungi al carrello`; aggiunta CTA `Acquista` con icona carrello vicino al box quantita; polish 1B con forma meno pill/bombata, piu squadrata/professionale, `border-radius: 6px`, colore tema `var(--primary-2, #D80027)` e nessun arancio e-stayon. Desktop verificato: icona vicino quantita e testo `Acquista` espandibile/visibile in hover/focus con focus accessibile. Mobile verificato con viewport `390x844`: `Acquista` sempre visibile, touch target circa 44px, nessun overflow o accavallamento. Preservati `.js-ks-cart-link`, `href` verso `cart_add.aspx`, `.ks-qty`, `data-ks-existing-cart-qty`, tutti i `data-ks-*`, delta quantita (`2 -> 2`, `2 -> 3`, `2 -> 5`), selezione multipla PR #240, quantita gia nel carrello ed evidenziazione card desktop/mobile. Non modificati HOME in questo task, `articolo.aspx`, MiniCart, carrello, `cart_add`, `aggiungi`, checkout/ordine/login/auth, query prodotti/ranking/search, DB/schema/SP, immagini/path asset o side cart/offcanvas. Smoke tecnico Codex e smoke utente Germano OK; add singolo OK; build/precompile OK; `git diff --check` OK; secret scan OK. La CTA HOME e stata poi chiusa da `HOME-BUY-CTA-ACQUISTA-1A/1B/1C`; backlog separati ancora aperti e non completati: `PDP-BUY-CTA-ACQUISTA-1A`, `PRODUCT-IMAGE-BRIGHTNESS-PREVIEW-1A`, side cart/offcanvas ONSUS, quantita gia nel carrello su `articolo.aspx`, eventuale bug login message anonimo/mobile con URL reale, menu Catalogo mobile e riallineamento `HomeDepartmentsMenu`.
- `HOME-BUY-CTA-ACQUISTA-1A/1B/1C` e chiusa su `frontend-rebuild` con HEAD `116000c64c2b09192e6aba5dc25916010dad9197`: le CTA carrello delle card prodotto HOME sono allineate allo standard commerciale `Acquista` gia approvato su catalogo. Branch runtime `task/home-buy-cta-acquista-1a`; commit originari prima del rebase `d3ecb36ffab53bb9e063377f2d61597d787b7a94`, `40a83ec0da6e72eb29726ed91e2ec77a79b2652f`, `8adcc942429df53b26992b605bc8f651c6e5b374`; commit dopo rebase su `frontend-rebuild` aggiornato `a0d0163efcee60e859a469662679323e1f1697d6`, `6561ed3e47ba318b3dc9086dba13c451a9341e9b`, `116000c64c2b09192e6aba5dc25916010dad9197`. File runtime modificati: `Default.aspx.vb` e `Public/assets/keepstore/css/theme-overrides.css`. Renderer coinvolti: `RenderActionButtons`, `RenderGridCard`, `RenderDealCard`, `RenderRowCardFromRow`, `RenderBigCard`, `rptDealOfDay` / blocco `Occasione Imperdibile`. Comportamento finale: CTA con icona `icon-cart-2`, testo `Acquista`, `aria-label/title` `Acquista: aggiungi al carrello`, colore tema `var(--primary-2, #D80027)`, border-radius circa `6px`, forma rettangolare/elegante non pill; desktop compatto con espansione hover/focus; mobile `390x844` sempre visibile/toccabile; `Occasione Imperdibile` allineato agli altri blocchi HOME; nessun overflow/accavallamento rilevato. Preservati `href` `cart_add.aspx`, `.js-ks-cart-link`, `data-ks-*`, id articolo, `TCid`, `qty`, querystring/flusso add-to-cart HOME. ProductCard/catalogo, `articolo.aspx`, carrello, `cart_add`, `aggiungi`, checkout, MiniCart, DB/schema/SP e immagini/path asset non modificati. Rebase pulito, merge fast-forward, Desktop HOME OK, Mobile `390x844` OK, add-to-cart HOME reale OK, catalogo `articoli.aspx?q=hp` invariato e add catalogo OK, HTTP 200 HOME/catalogo/carrello, build/precompile OK, `git diff --check` OK, secret scan OK, smoke Germano OK su 1A/1B/1C. Dopo questa chiusura HOME non e piu backlog; restano separati PDP `Acquista`, immagini brillanti, side cart/offcanvas, quantita su `articolo.aspx`, bug login anonimo/mobile se ricompare, menu Catalogo mobile, `HomeDepartmentsMenu` e valutazione futura `llms.ashx`/`llms.txt`/JSON-LD dinamico.
- Regola UX CTA equivalenti: funzioni uguali o equivalenti devono mantenere standard unico di icona, linea grafica, semantica testo/aria-label e criteri responsive/accessibilita; differenze tra pagine sono ammesse solo se motivate e documentate.
- `PDP-BUY-CTA-ACQUISTA-AUDIT-1` e `PDP-BUY-CTA-ACQUISTA-1A/1B` sono chiusi su `frontend-rebuild` con HEAD `3b0b2ac97564c497abd26d224e5e945834a2ec26`. Branch runtime `task/pdp-buy-cta-acquista-1a`; commit `b56277c7777345c70021e21270628b72a51a2f4c` (`feat: standardize PDP buy CTAs`) e `3b0b2ac97564c497abd26d224e5e945834a2ec26` (`fix: align PDP bundle buy CTA`), merge fast-forward `--ff-only`. CTA principale `articolo.aspx`: testo `Acquista`, `icon-cart-2`, `aria-label`/title coerenti, struttura ONSUS `.product-box-btn`/`.tf-btn` preservata, `btnAddToCart_Click`, quantita, TCId, sessioni e flusso `aggiungi.aspx` invariati. Bundle `Spesso acquistati insieme`: `Acquista selezionati`, stile primario rosso con testo/icona bianchi, `icon-cart-2`, handler `btnBundleAddToCart_Click`, `ks_product_bundle_cart_items` e `Carrello_SelezioneMultipla` invariati. Simili/Correlati/Recenti: semantica `Acquista`, `icon-cart2` normalizzato a `icon-cart-2`, `.js-ks-cart-link`, `AddToCartUrl`, href/id/TCId/qty e card ONSUS preservati, nessuna migrazione a ProductCard. Accessibilita: icone decorative `aria-hidden`, focus-visible, quick action tastiera e touch target smartphone migliorato. Smoke Germano finale `PDP-BUY-CTA-ACQUISTA-1B = A`, desktop reale A e mobile reale A. Product detail shell PR #196/#197/#198/#199 non riaperto. Questa chiusura riguarda solo le CTA: `articolo.aspx` non e dichiarata completa; typography, quantita PDP, side cart e funzioni future restano separati.
- `CART-QTY-IN-CATALOG-1A` e chiusa su `frontend-rebuild` con HEAD `14e3aa43d64dfad97710f4fd15903490914e79fb`: su `articoli.aspx`, se un prodotto/TCId e gia presente nel carrello, la card catalogo mostra la quantita reale gia in carrello direttamente nel box quantita esistente e la card viene evidenziata in modo leggero/professionale. Implementazione limitata al catalogo: `articolo.aspx` non e ancora coperto e resta backlog separato. La quantita viene letta read-only dalla tabella `carrello` e non da `vcarrello`, con owner `LoginId`/`LOGINID` per utenti loggati oppure `Session.SessionID` per anonimi, chiave `ArticoliId + TCId` e snapshot/dizionario senza query per card. Se `CartQty = 0`, card normale, box normale e valore `1`; se `CartQty > 0`, il box mostra la quantita reale, numero verde/grassetto/leggibile, card con bordo/fondo/ombra soft, nessun testo/pill/badge esterno `In carrello` o `Nel carrello`, mentre `title`/`aria-label` mantengono il significato accessibile `Nel carrello: X`. Il delta e gestito nel layer catalogo: server-side per WebForms/selezione multipla, JS catalogo per link add-to-cart reale e cache-buster su `keepstore-product.js` per evitare handler browser vecchi. Test Germano e Codex OK: carrello vuoto `1 -> 1`, carrello `2 -> 2` resta `2`, `2 -> 3` diventa `3`, `2 -> 5` diventa `5`, selezione multipla preservata, svuota carrello OK, desktop OK, build/precompile OK. Lo smoke mobile reale ha aperto backlog separati e quindi non va dichiarato `mobile OK` finche quei percorsi non sono verificati e chiusi. `git diff --check` OK e secret scan OK. Non modificati `articolo.aspx`/`.vb`, `ProductCard.ascx`/`.vb`, `cart_add.aspx`/`.vb`, `aggiungi.aspx`/`.vb`, `carrello.aspx`/`.vb`, `MiniCart.ascx`/`.vb`, DB/schema/SP, checkout/ordine/PayPal/gateway/email/auth, query prodotti/ranking/search, Settori/sidebar/filtri/applied filters o immagini/path asset. Backlog separati da mantenere: quantita gia presente su `articolo.aspx`, side cart/offcanvas ONSUS post add-to-cart, audit funzioni mancanti `articoli.aspx` vs ONSUS e audit immagini rotte/path DB.
- `CART-QTY-MOBILE-VISUAL-FIX-1A` e chiusa su `frontend-rebuild` con HEAD stabile `be4cfcb12e9f4aa5323f8a39c84f2ce40eca214e`: resa stabile anche su mobile la grafica `prodotto gia nel carrello` su `articoli.aspx`. Problema risolto: la quantita era memorizzata e riletta correttamente, ma la card runtime `ProductCard` renderizzava `article.card-product` fisso e lo stato visuale dipendeva soprattutto da CSS `:has(.ks-cart-qty-input-present)`, fragile su mobile/browser reale. Soluzione: `ProductCard` ora supporta classi server-side stabili quando `CartQty > 0`, con `ks-card-in-cart` sulla card e `ks-cart-qty-present` sul wrapper quantita; `:has()` resta fallback e non meccanismo principale. File runtime modificati: `articoli.aspx.vb`, `Public/ui/controls/ProductCard.ascx`, `Public/ui/controls/ProductCard.ascx.vb`, `Public/assets/keepstore/css/catalog-ui.css`. Comportamento finale: `CartQty=0` lascia card/box normali; `CartQty>0` evidenzia card e box, mostra il numero verde/grassetto/leggibile, senza testo visibile `In carrello`/`Nel carrello` e senza pill/badge esterni; `title`/`aria-label` mantengono `Nel carrello: X`. Mobile verificato realmente con viewport mobile, desktop verificato, smoke utente Germano OK, HOME controllata nello smoke utente perche `ProductCard` e condiviso. Delta preservato (`2 -> 2`, `2 -> 3`, `2 -> 5`), selezione multipla PR #240 preservata, build/precompile OK, `git diff --check` OK e secret scan OK. Non modificati `carrello.aspx`/`.vb`, `cart_add.aspx`/`.vb`, `aggiungi.aspx`/`.vb`, checkout/ordine/login/auth, `MiniCart.ascx`/`.vb`, `keepstore-product.js`, query prodotti/ranking/search, DB/schema/SP, Settori/sidebar/filtri/applied filters o immagini/path asset.
- `CART-CONTINUE-SHOPPING-1A` e chiusa su `frontend-rebuild` con HEAD stabile `09bdd4f749522e9a9dd7b0b884620f54dc9d5624`: `carrello.aspx` ora fa tornare il pulsante `Continua lo Shopping` all'ultima pagina/contesto reale da cui l'utente ha aggiunto prodotti, invece della HOME generica. File runtime modificati: `carrello.aspx.vb` e `aggiungi.aspx.vb`. Causa: `btContinua` usava `Session("Pagina_visitata_Articoli")`; `articoli.aspx` salvava li un URL assoluto; `SafeRedirectLocal` accettava solo URL locali, quindi l'assoluto veniva scartato e il fallback portava a `default.aspx`. Soluzione: `ResolveContinueShoppingUrl()` in `carrello.aspx.vb` sceglie in priorita `Session("Carrello_Pagina")` valida, `Session("Pagina_visitata_Articoli")` valida/normalizzabile, referrer locale idoneo e fallback sicuro; `Session("Carrello_Pagina")` non viene piu azzerata troppo presto in `aggiungi.aspx.vb`. Sicurezza: URL assoluti dello stesso host convertiti in `PathAndQuery`; URL esterni, `javascript:`, `data:`, `//host`, backslash e pagine non shopping respinti; ammesse solo destinazioni shopping idonee `Default.aspx`, `articoli.aspx` e `articolo.aspx`; escluse carrello, checkout, ordine, pagamento, login, gateway, logout, reset/remind/token. Comportamento finale: da `articoli.aspx?q=hp` torna a `q=hp`; da `articoli.aspx?st=2&ct=96&tp=27` torna allo stesso contesto; da `articolo.aspx?id=...` torna alla scheda o a un contesto shopping valido; da HOME torna a HOME o fallback shopping valido; carrello aperto direttamente usa fallback sicuro. Desktop smoke Germano OK; mobile verificato da Codex almeno su catalogo `st/ct/tp` e smoke Germano OK. Checkout anonimo/loginrequired preservato: la protezione checkout non e stata rimossa. Side cart/offcanvas non implementato in questo task. Build/precompile OK, `git diff --check` OK e secret scan OK.
- Regola operativa Germano post `CART-QTY-IN-CATALOG-1A`: ogni micro-task KeepStore che tocca UI, catalogo, carrello, checkout, login, sessione o flussi ecommerce deve verificare esplicitamente e separatamente funzionamento logico, resa grafica desktop, resa grafica mobile, utente anonimo, utente loggato quando pertinente, percorso reale di click/submit usato dall'utente e comportamento ecommerce corretto. Vietato dichiarare `mobile OK`, `desktop/mobile verificati` o `responsive OK` senza verifica reale della resa mobile del percorso interessato; se mobile non e verificato va scritto `non verificato`. Se un comportamento non e certo, fermarsi, fare audit read-only, confrontare codice reale, manuali progetto, template ONSUS reale e documentazione tecnica disponibile, dichiarare cosa e verificato e cosa no e non procedere con fix a tentativi. Regola ecommerce/carrello: aggiungere prodotti al carrello non deve richiedere login; l'utente anonimo deve poter riempire il carrello; la richiesta login deve comparire solo su ordine/checkout/conferma; messaggi tipo `Accedi per inviare l'ordine` non devono essere presentati come conseguenza del semplice add-to-cart. Backlog aperti da non segnare come completati: `BUG-ADD-TO-CART-ANON-MOBILE-LOGIN-MESSAGE`, quantita carrello su `articolo.aspx` e side cart/offcanvas ONSUS. `BUG-CART-QTY-MOBILE-VISUAL` e stato chiuso separatamente da `CART-QTY-MOBILE-VISUAL-FIX-1A`.
- Backlog mobile/ecommerce aperti post smoke Germano: `BUG-ADD-TO-CART-ANON-MOBILE-LOGIN-MESSAGE` indica che su mobile, dopo semplice add-to-cart anonimo, l'articolo viene salvato nel carrello ma `carrello.aspx` mostra `Accedi per inviare l'ordine`; va auditato e corretto in task runtime separato, verificando anche desktop, e login required deve restare solo su checkout/conferma ordine. `articolo.aspx` resta backlog separato per la quantita gia in carrello. Side cart/offcanvas ONSUS resta backlog separato: dopo add-to-cart dovra mostrare anteprima/offcanvas e permettere di continuare lo shopping, senza mischiarlo con bug loginrequired o visual mobile.
- Backlog successivo non immediato: eventuale retest mobile reale, verifiche IVA esclusa con dati certi, `documentidettaglio.aspx`, header/menu hover, compare/offcanvas, ricerca AI/header/home, spinner/loading e moduli ecommerce evoluti restano task separati da scegliere dal backlog non PayPal. Non riaprire PayPal o promo/carrello/IVA per micro-rifiniture non bloccanti.
- `ACCOUNT-PROFILE-1B` resta chiuso.
- `ACCOUNT-SIDEBAR-INLINE-CLEANUP fase 1` resta chiuso.
- `ACCOUNT-SIDEBAR-INLINE-CLEANUP fase 2 documenti` resta chiuso.
- `ACCOUNT-ADDRESS-1B` resta chiuso.
- `ACCOUNT-PASSWORD-SECURITY-1B` resta chiuso.
- `ACCOUNT-PASSWORD-SECURITY-1I` resta chiuso.
- `LOGIN-REGISTER-SECURITY-1` resta chiuso.

Task consigliato separato per eventuale proseguimento:

- `ACCOUNT-SIDEBAR-INLINE-CLEANUP-3A`: eventuale audit/cleanup delle sidebar inline legacy residue solo dopo audit datiutente, nella pagina:
  - `datiutente.aspx`
- Obiettivo: decidere con Germano se rimuovere, nascondere o riallineare le nav inline legacy, mantenendo `AccountSidebar` condivisa come fonte di navigazione account.
- Vincolo: non modificare dati utente o salvataggi legacy senza autorizzazione Germano.

## 13. Prossimi step consigliati

### Immediati — scaletta storica superata

Per la priorita corrente usare la roadmap commerciale nel checkpoint 2026-10-01. Questa scaletta conserva la cronologia e non riavvia i task gia integrati.

1. Completare review e chiusura A di `KEEPSTORE-MULTITENANT-ONBOARDING-CONTRACT-1A`, mantenendo runtime, database e configurazioni cliente invariati.
2. Solo dopo il merge, proporre `GOOGLE-PRODUCT-STRUCTURED-DATA-1A` per il contratto dinamico multi-tenant e multi-merceologia `Product`/`Offer`/`Breadcrumb`/`Organization`. Stato: `NON AVVIATO` e non autorizzato all'implementazione.
3. Audit futuro dello schema monetario ancora `DOUBLE`.
4. Candidati separati da conservare senza implementarli ora:
   - `PROMO-AMBIGUOUS-STATE-REACHABILITY-1A`: verificare la raggiungibilita di `AmbiguousCommercialRule`; oggi risultano zero offerte ambigue attive ed e un task commerciale non prioritario rispetto al carrello.
   - `B2C-WITHDRAWAL-COMPLIANCE-AUDIT-1A`: requisiti gia documentati, ma audit differito per decisione Germano; non avviarlo senza nuova priorita esplicita.
   - `HOME-TTFB-PERFORMANCE-1A`.
   - `MYSQL-CONNECTOR-DEPENDENCY-AUDIT-1A`.
   - EMAIL-ORDER-CONFIRMATION-1A: prossimo blocco consigliato dopo `EMAIL-ENGINE-1A`; migrare la conferma ordine standard con varianti pagamento senza toccare gateway, costi o totali.
   - EMAIL-BANKTRANSFER-1A: istruzioni bonifico dedicate, solo dopo conferma fonti coordinate bancarie.
   - EMAIL-COD-1A: microcopy contrassegno/contanti, senza modificare pagamento reale.
   - ORDER-CONFIRMATION-UX smoke live: verificare la nuova UX post-ordine, senza pagamento reale.
   - AUDIT-FINALE-CHECKOUT-PAGAMENTI-1A: audit separato di checkout/pagamenti/gateway, senza confonderlo con UI carrello.
   - Prossima pagina o area scelta da Germano su branch dedicato.
   - PASSWORD-HASH-SCHEMA-2B / PASSWORD-HASH-MIGRATION-2C: futuro task hash password; hash password non ancora implementato.
   - GESTIONALE-PASSWORD-AUDIT-1A / JANUS-PASSWORD-RESET-1A: audit gestionale Janus per reset/hash.
   - REGISTRATION-POLICY-1A / REGISTRATION-UX-1A: refinement residuo login/registrazione.
   - PR #171 diagnostica sessione/logout post-ordine: non attiva ora; riprendere solo se il problema torna riproducibile con test manuale mirato.
4. `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A` resta chiuso E e differito: non promuoverlo senza decisione sulla topologia/infrastruttura.
5. Mantenere PayPal, BancaSella, gateway e pagamenti in task separati dal carrello UI e dalla funzione di recesso.
6. AUTH-CSRF-AUDIT-1A: audit `AntiCsrfPage` sui flussi auth.
7. AUTH-JS-LEGACY-AUDIT-1A: audit errori JS legacy residui.
8. DATIUTENTE-LEGACY-AUDIT-1A per errore generico, tab/JS legacy e salvataggi/destinazioni.

### PayPal Checkout Orders v2

1. Stato: `READY FOR LIVE CONFIGURATION`.
2. Pending/denied/failed/canceled mantengono `Pagato=0`; il recheck usa Get Order senza recapture.
3. Solo capture `COMPLETED` validata produce `Pagato=1`, `StatoPagamentoWeb=2` e `IdTransazione=TXN:<CaptureId>`.
4. Il primo pagamento LIVE richiede autorizzazione, configurazione server e webhook già verificati.

### UI

1. REGISTRATION-UX-1A: modernizzazione registrazione, se Germano la prioritizza.
2. ACCOUNT-ADDRESS-2A solo se Germano autorizza audit/migrazione della gestione indirizzi legacy.
3. DATIUTENTE-LEGACY-AUDIT-1A: errore generico preesistente, tab/JS legacy, salvataggi e destinazioni.
4. ACCOUNT-SIDEBAR-INLINE-CLEANUP-3A solo dopo audit datiutente.
5. Proseguire altra pagina account secondo priorita Germano.
6. Per ogni refactor UI:
   - audit ONSUS prima;
   - verificare prima template ONSUS originale e componenti gia presenti, poi scrivere codice nuovo solo se il componente non esiste o non basta;
   - micro-task implementativo dopo;
   - smoke desktop/mobile;
   - nessuna patch sul vecchio layout quando si cambia impostazione grafica.

## 14. Guardrail permanenti

- Non toccare `main` senza task esplicito.
- Non creare PR verso `main`.
- Non modificare DB/dump SQL senza backup e task DB dedicato.
- Non modificare gateway PayPal/BancaSella in task UI.
- Non creare ordini o pagamenti senza autorizzazione esplicita.
- Non chiamare PayPal live senza task dedicato e consenso esplicito.
- Non inserire o stampare secret.
- Non esporre token o transaction id completi in UI/log/report.
- Non confondere stato ordine con stato pagamento.

## Chiusura CART-MOBILE-RESPONSIVE-UX-1A

`CART-MOBILE-RESPONSIVE-UX-1A` è chiuso con esito A su `frontend-rebuild`, checkpoint `4e1c84a7f0d3528e6479b1b5e2fa6604a8649423`, PR #249 integrata fast-forward con un commit e zero merge commit. Il manifest runtime effettivo è `Public/assets/keepstore/css/cart-ui.css` e `Public/ui/controls/MiniCart.ascx`.

Contratto visuale: desktop 1365×900 mantiene la tabella; tablet 768×1024 e mobile 390×844/360×800 usano card/grid con ordine immagine, titolo, disponibilità/promozione, prezzo, quantità, totale e rimozione. Etichette Prezzo/Quantità/Totale, riepilogo e CTA full-width mobile, MiniCart coerente ONSUS, immagine senza stile inline, target touch 44×44 e focus/naming accessibile sono verificati senza overflow. Sul desktop restano 36×48 per rimozione e 30×30 per quantità, scelta di densità puntatore e non blocker.

L’audit `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A` resta chiuso con esito E, implementazione differita e nessun DDL: Session/InProc conserva rischi su recycle e topologie multi-nodo. Recesso digitale e Coupon/Groupon restano differiti dal Product Owner.

Roadmap al checkpoint storico: `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A` resta chiuso E e differito; mobile UX, target touch mobile e `ORDER-DURABLE-IDEMPOTENCY-1A` sono chiusi A, con PR #254 integrata nel checkpoint `9fed039d4563fd20ecc02859236d90e7a2f0be5d`. La roadmap corrente prevalente e quella della REV2 PR #267; audit monetario, AntiCsrfPage e promo ambigua restano separati, mentre Coupon/Groupon e recesso restano differiti.

## Chiusura CART-REMOVE-TRANSACTION-HARDENING-1A

Chiusura A registrata con PR #247, integrata fast-forward in `frontend-rebuild` al checkpoint `2e3384a6a72d06b5cd090e4030d2548d96e4b165` (base `e7834f42eff4c5b11b39bae59780e88863c6e2bf`). Un commit integrato, zero merge commit. Remove/clear sono owner-scoped, transazionali, idempotenti e protetti da CSRF e same-origin; GET non muta. Smoke anonimo/autenticato, retry/rollback, concorrenza, 21906, checkout non distruttivo, viewport, precompile, diff-check e secret scan superati; fixture ripristinate. Il pulsante Svuota non è renderizzato a carrello vuoto: il no-op è stato verificato prima del merge, senza regressione.

Roadmap cart: `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A`, `CART-MOBILE-RESPONSIVE-UX-1A`, touch target rimozione 44×44, audit schema monetario DOUBLE. Recesso digitale e Coupon/Groupon restano differiti.
## Regola permanente multi-database KeepStore

Database-per-cliente con schema canonico condiviso. Nessuna nuova stored procedure, migrazione o modifica schema può essere considerata completata se non comprende sia l’upgrade dei database esistenti sia il provisioning automatico dei nuovi database.

Ogni rollout DB deve essere ripetibile e verificabile per database, con preflight globale read-only, backup/rollback indipendente, applicazione sequenziale e report sanitizzato. Il nome del database è un parametro di deployment e non deve essere hardcoded nel corpo canonico della procedura.

La compatibilità strutturale non costituisce autorizzazione al deployment. L’allowlist dei database destinatari è stabilita esclusivamente dal Product Owner.

## Checkpoint MULTI-STOREFRONT-CART-ISOLATION-1A

Task implementato sul branch `task/multistorefront-cart-isolation-1a`, base stabile `f34a4a5229f318234a772d1c8263a5c1a9238b50`, con PR da mantenere DRAFT fino alla review e agli eventuali smoke richiesti. Esito tecnico locale A; nessun merge autorizzato in questa fase.

Audit certo: `carrello` non contiene `AziendaId`; le righe autenticate erano selezionate tramite il solo `LoginId`, mentre le anonime usavano il `SessionID` ASP.NET grezzo in servizi, revalidation, snapshot, MiniCart, header e pagina carrello. Il `LoginId` e univoco nel database e viene ora accettato soltanto con marker server-side `AuthenticatedAziendaID` coerente con l'azienda risolta per host. Per l'anonimo, la colonna esistente `SessionId varchar(50)` contiene un token opaco deterministico di 47 caratteri derivato da identita database sanitizzata, `AziendaId` e sessione; non serve DDL.

Contratto dimostrato:

- owner autenticato `database + AziendaId + LoginId`; owner anonimo `database + AziendaId + token sessione`;
- host/azienda/database/listino provengono solo dal contesto server-side; host sconosciuto, marker account incompatibile o alias non canonicalizzato impediscono la mutazione;
- `CartMutationService`, `CartOwnershipService`, `CartPriceRevalidationHelper`, `CartStateSnapshotProvider`, MiniCart, header e query pagina carrello consumano lo stesso owner;
- add standard singolo/multiplo, async e POST nativo, quantita, remove, clear, prezzi/promo e merge post-login restano atomici e tenant-scoped;
- la fingerprint idempotente include database, azienda e owner; `ReturnUrl` esterni, GET mutativi e CSRF invalidi restano respinti;
- righe anonime legacy basate sul solo `SessionID` non sono reclamate automaticamente, perche la loro azienda originaria non e dimostrabile senza introdurre una fuga cross-tenant.

Harness same-database sintetico: 25/25 scenari PASS piu rollback; conteggi laboratorio `0 -> 0`. Verificati A=2 e B=3 sullo stesso articolo, update/remove/clear isolati, replay singolo, login/merge A e B distinti, A-B-A senza contaminazione, prezzi tenant `5,00` e `6,25`, batch isolato e parita MiniCart/pagina/header/checkout. Zero documenti, ordini e idempotenza ordine. Regression gate: pricing/account PASS, promotion parity/error-state 141/141, promotion bulk 19/19, SEO/same-database 41/41 e 44/44, Product structured data 46/46, precompile ASP.NET Framework 4.8 PASS. Nessun database reale, account reale, ordine, e-mail, pagamento o gateway coinvolto.

Nota storica (superata dal checkpoint 2026-10-01): Il task successivo a questo checkpoint carrello e `MULTI-STOREFRONT-ORDER-PROVENANCE-EMAIL-1A`, ora implementato nel checkpoint seguente e ancora soggetto a review/merge. Merchant Center resta sospeso e, nella roadmap aggiornata, segue persistent anonymous cart e cart conversion UX.

## Checkpoint MULTI-STOREFRONT-ORDER-PROVENANCE-EMAIL-1A

Task implementato sul branch `task/multistorefront-order-provenance-email-1a`, base stabile `2d6ebd540a29ff906a01fa0820ebf65706150408`; PR da mantenere DRAFT fino alla review indipendente e agli eventuali smoke autorizzati. Nessun database cliente, ordine, SMTP, pagamento o gateway viene usato per la prova tecnica.

Audit e modello:

- `Carrello_Documento` risolve `vlogin.UtentiId/AziendeId`, inserisce `documenti.AziendeId` nella stessa transazione e usa il contatore globale per tipo/anno; la provenienza e gia persistente e non serve una migration duplicata;
- la numerazione resta condivisa fra storefront nello stesso database (`A -> N`, `B -> N+1`, `A -> N+2`) e non contiene un filtro azienda;
- il vecchio ramo `Session("AziendaId") = 2` nell'e-mail era una differenziazione cliente hardcoded: e rimosso, non sostituito con un altro ID;
- checkout token, confirmation token, fingerprint, claim, completion e replay verificano database configurato, azienda, login, tipo documento, listino, opzioni e carrello;
- ricevuta PRG, lista e dettaglio documento richiedono insieme account/utente e `AziendeId` del tenant autorevole;
- branding, URL, destinatario cliente e copia amministrativa derivano dall'azienda persistita nel documento; From/envelope e trasporto sono risolti dal profilo tenant centrale della stessa azienda. L'invio resta dopo il commit; replay, rollback, stock error e collisione non inviano.

Harness same-database: 26 scenari richiesti piu concorrenza globale A/B, tutti su fixture sintetiche e fake e-mail sink. Sono coperti provenienza, numerazione, listini/promo, inventario condiviso, clear dei soli carrelli owner, replay/collisione, lista/dettaglio/ricevuta cross-tenant, una sola e-mail, rollback/stock/deadlock, errore SMTP post-commit e atomicita. La sequenza successiva aggiornata e registrata nella REV2 seguente; nessun task successivo e avviato prima della chiusura della PR #267.

### REV2 - submit checkout osservabile e roadmap carrello (storico)

La roadmap di questa REV2 descriveva lo stato precedente: login autofill e persistent anonymous cart sono ora integrati; prevale il checkpoint 2026-10-01. I debiti separati e i vincoli di sicurezza restano validi.

- Causa certa del refresh silenzioso: `vlogin` puo produrre duplicati fisici identici della stessa tupla logica account/listino; `OrderStorefrontContext.VerifyAccount`, introdotto dal commit ordine `7c6c63863275faa5a7ae389a0d719a6448c3fb49`, interpretava la seconda riga come ambiguita e falliva chiuso. Il problema veniva amplificato dal `Catch` di `btInviaOrdine_Click`, che registrava l'eccezione senza rendere osservabile l'esito e lasciava quindi un `HTTP 200` senza ordine ne messaggio.
- Correzione REV2: la verifica account deduplica con `DISTINCT` la tupla logica, continuando a fallire chiusa se esistono tuple realmente differenti; il submit dispone di CSRF dedicato, controlli espliciti per validator, carrello, indirizzo, spedizione, pagamento, tipo documento, prezzo e stock, e mostra un errore accessibile e sanitizzato con reset del busy state quando non puo proseguire. Successo e replay conservano PRG/`303`; login, stock e variazioni commerciali mantengono destinazioni dedicate; nessun ramo puo concludersi con un refresh silenzioso.
- La matrice terminale obbligatoria della REV2 copre handler, validazione pagina, termini, spedizione, pagamento, tipo documento, carrello vuoto, stock, prezzo, login scaduto, CSRF, RequestId, collisione payload, doppio clic, replay, deadlock/timeout, eccezione annidata, errore e-mail post-commit, assenza di rami silenziosi e coerenza pagina/MiniCart/header. I test restano sintetici o read-only e non autorizzano ordini, e-mail, pagamenti, gateway o DML reali.
- Stato: PR #267 ancora DRAFT e non merge-safe fino allo smoke Product Owner sul commit REV2 pubblicato. Il checkpoint non dichiara concluso il task e non autorizza il task successivo.
- Stato login/sessione verificato: timeout applicativo di 30 minuti di inattivita; autenticazione dipendente da `Session("LoginId")`; carrello autenticato persistito nel DB e recuperato dopo un nuovo login; cookie annuale con solo username, non credenziale e non autenticazione; timeout idle/recycle dell'Application Pool non ancora certificato. La REV2 non modifica alcun timeout.
- Forensica REV4: il riferimento assistenza mostrato dal checkout reale non e presente nei log applicativi disponibili e il tentativo non ha creato claim idempotente, documento o e-mail. Poiche fase ed eccezione non sono state persistite, lo stop E vieta fix dedotti dal solo stato UI; PR #267 resta DRAFT fino a una diagnosi causale osservabile.
- `LOGIN-PASSWORD-MANAGER-AUTOFILL-1A` e registrato ma `NON AVVIATO`: dovra rendere il login desktop/mobile compatibile con i password manager tramite form e nomi input stabili, HTTPS, `autocomplete="username"` e `autocomplete="current-password"`, con verifica Edge, Chrome, Firefox e Safari e audit dei JavaScript che cancellano o alterano gli input. Il browser e l'utente restano gli unici a decidere salvataggio e riempimento; logout continua a invalidare l'autenticazione. Sono vietati password in cookie, Web Storage, Session, ViewState, hidden field, query string, HTML/server prefill e log, cosi come autenticazione persistente nascosta.
- Roadmap storica, superata dai checkpoint successivi: in quella fotografia post-PR #267 i task erano tutti `NON AVVIATO`; in seguito login autofill #295, persistent cart #297–#299 e `STOREFRONT-CART-CONVERSION-UX-1A` #303 sono stati chiusi e integrati. La sequenza storica includeva Merchant feed e abandoned-cart recovery, che restano ambiti distinti da rivalutare con prerequisiti e autorizzazione propri; non costituisce la roadmap prevalente corrente.
- `STOREFRONT-PERSISTENT-ANONYMOUS-CART-1A` riguarda durata e recupero delle righe anonime; non coincide con `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A`, che riguarda i registri anti-replay delle mutazioni e resta E/differito.

## Checkpoint storico MULTIPROVIDER-TENANT-EMAIL-TRANSPORT-1A — stato locale 2026-09-21

Questo checkpoint descrive la foundation locale prima del provisioning Taikun production e dello smoke #319. I riferimenti alla sola macchina `KeepStoreSmoke` e alla mancata certificazione production che seguono sono storici; lo stato corrente e riportato nel checkpoint operativo in testa al documento.

Audit, contratto e migrazione completa dei chiamanti REV1 sono eseguiti sulla PR #268, base stabile `a4bb16fe354dc27226ac0e98e89d6bd438decce4`. Il 20 settembre 2026 la migration autorizzata e stata applicata al database locale `taikun`: `aziende_email_transport` e presente e verificata. Il 21 settembre 2026 il Product Owner ha completato sulla sola macchina locale, sito/Application Pool `KeepStoreSmoke`, il provisioning DPAPI `LocalMachine` fuori da webroot/repository per i due profili `TRANSACTIONAL`; entrambi risultano `Enabled=1`, `VerificationStatus=VERIFIED`, con timestamp valorizzato e codice sanitizzato `EMAIL_CONNECTION_VERIFIED`. Il runner ha verificato esclusivamente TLS, autenticazione e `QUIT`, senza costruire o inviare messaggi. Questo checkpoint non certifica ne configura la produzione.

Tutti i sender applicativi presenti nel repository condividono ora `TenantEmailDeliveryService`: conferma ordine e BCC amministrativa, registrazione e aggiornamento profilo, reset password con link monouso, contatto moderno e contatto legacy. Tenant e database derivano da contesto server autorevole o dall'azienda persistita nel documento; lo scopo e sempre `TRANSACTIONAL`. From ed envelope sono imposti dal profilo; Reply-To del contatto, destinatari multipli, CC/BCC, HTML/plain text, allegati, classificazione e correlation ID attraversano il solo facade. Nessun chiamante crea `SmtpClient`, legge configurazione SMTP da `aziende`/Session o usa fallback legacy.

Il contratto schema e versionato come `20260920_MULTIPROVIDER_TENANT_EMAIL_TRANSPORT_1A v2`: una sola tabella `aziende_email_transport` per database, PK tecnica `EmailTransportId`, FK a `aziende.id` e unique `(AziendeId, Purpose)`. Ogni azienda puo avere un profilo `TRANSACTIONAL` e, in futuro, uno `MARKETING`; tutti gli invii correnti migreranno sul primo. Host 253, identita e-mail/username 254, `CredentialReference` 512, display name Unicode e timeout 5-300 sono espliciti. I valori controllati sono testuali e validati, non `ENUM`, per evoluzione compatibile. Nessun profilo o segreto legacy e copiato; default `Enabled=0`, attivazione solo dopo TLS/auth riusciti. Altri database richiedono sempre allowlist e autorizzazione separate.

Il nucleo provider-neutral e implementato. MailKit `4.18.0` e MimeKit `4.18.0`, con dipendenze transitive fissate, licenze, SHA-256 e restore dalla sorgente NuGet ufficiale, sono distribuiti nelle DLL `Bin` richieste dal Web Site .NET Framework 4.8. Resolver e trasporto sono tenant-scoped per identita database, azienda e scopo; STARTTLS e TLS implicito sono espliciti, certificato e hostname obbligatori, plaintext/downgrade vietati, log sanitizzati e stati tecnici fail-closed. La tabella `aziende` conserva fisicamente i campi SMTP legacy per compatibilita, ma il runtime e-mail non li legge piu e `Page.master` non copia credenziali SMTP in Session. Il secret store usa DPAPI `LocalMachine` fuori dal webroot e riferimenti opachi. Il solo tool amministrativo `Tools/Set-EmailTransportCredential.ps1` deriva l'identita database dal `web.config`, richiede due volte la credenziale con input mascherato, configura ACL protette e scrive atomicamente; non accetta password o database identity da riga di comando, non scrive il database e non modifica IIS. OAuth2 Google/Microsoft resta `NON OPERATIVO` fino a `SMTP-OAUTH-CONNECTORS-1A`.

`MULTIPROVIDER-TENANT-EMAIL-VERIFY-RUNNER-1A` aggiunge `Tools/Verify-EmailTransportConnection.ps1`, runner amministrativo esclusivamente locale. Compila in una directory temporanea e riusa direttamente i sorgenti canonici `App_Code` di contratti, resolver, secret store e `MailKitEmailTransport`, quindi non introduce un secondo motore e-mail; l'output temporaneo viene eliminato. Accetta soltanto `AziendaId`, `Purpose`, application root, nome connection string e credential root, genera internamente il correlation ID e non accetta password, host, username, reference DPAPI o database identity. Non espone endpoint, listener, pagine o handler, non modifica DB/IIS e non costruisce messaggi: `VerifyConnection` usa il resolver amministrativo, DPAPI e TLS/AUTH/QUIT reali senza `MAIL FROM`, `RCPT TO` o `DATA`. Output e codici di uscita sono sanitizzati e stabili: `0` successo, `10` configurazione, `20` profilo, `21` credenziale, `30` TLS/certificato, `31` autenticazione, `32` timeout, `33` trasporto e `40` errore interno.

Il censimento non ha trovato sender distinti per verifica indirizzo, promemoria username o variazione stato ordine nel runtime web. `documenti.aspx.vb` e `coupon_utente.aspx.vb` accodano soltanto `INVIADOCUMENTI`: il sender reale e esterno al repository, quindi il contratto di coda e preservato e non viene dichiarato migrato. Registrazione/profilo non inviano password; il recupero usa il token monouso e mantiene risposta anti-enumerazione. Se l'e-mail ordine fallisce dopo il commit, documento e idempotenza restano validi e non parte alcun retry nello stesso request; i contatti non mostrano una falsa conferma.

Il runtime core e completo e i chiamanti applicativi censiti usano il facade tenant-scoped senza fallback ai campi SMTP legacy. Storicamente i due profili locali furono verificati senza invio reale; successivamente Taikun production ha completato provisioning DPAPI server-side e smoke Product Owner A dei quattro flussi web TRANSACTIONAL, come registrato nel checkpoint corrente in testa a questo documento. `INVIADOCUMENTI` resta affidata al consumer esterno e non viene dichiarata migrata o certificata dal runtime web.

Il contratto operativo per Enzo resta `BOZZA TECNICA` in `docs/MULTIPROVIDER_TENANT_EMAIL_CONFIG_ENZO.md`: non autorizza il pannello gestionale. La procedura manuale server-side resta valida finche tale pannello non sara implementato. Il provisioning DPAPI `LocalMachine` e specifico della macchina/runtime e non trasferibile; Taikun production e verificato per i flussi elencati, mentre ogni altro tenant richiede provisioning, verifica e attivazione separati. Nessun valore, riferimento reale o segreto e conservato nei manuali. Rotazione credenziali, pannello gestionale, OAuth2, certificazione del consumer esterno, rimozione fisica dei campi legacy e `DATABASE-DUMP-REPOSITORY-HYGIENE-1A` restano attivita distinte; il rollout o la certificazione di altri tenant non sono impliciti.
