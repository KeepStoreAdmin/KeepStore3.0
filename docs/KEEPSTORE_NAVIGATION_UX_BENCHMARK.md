# KeepStore Navigation UX Benchmark

Task: `STOREFRONT-NAVIGATION-UX-BENCHMARK-1A`.
Data di consultazione e progetto: **2026-10-09**, Europe/Rome.
Base verificata: `ab471b6e95da1fcda101ef4f5dfbe27985a3e381`, PR #323 MERGED, parent `c4e1d25f9e4e47725461115fbc8d6ce17a20dd6a`.
Stato: **A documentale candidato alla review; proposta UX, non implementazione o certificazione visuale**.
Manifest di questo task: questo documento e `KEEPSTORE_MASTERPLAN_OPERATIVO.md`. Nessun runtime modificato, build, smoke, query DB, deploy o merge.

## 1. Decisione proposta e limiti

**Il catalogo deve essere il contenuto principale del menu mobile, non una scelta nascosta nel menu.** Primo intervento raccomandato: mostrare subito i settori reali all'apertura del drawer esistente. Conservare ricerca, Bootstrap, tutti i link e il desktop. Non partire da un secondo menu, un nuovo motore di ricerca o lazy loading.

Il target successivo e una navigazione mobile a un livello per volta, con genitore visibile, ritorno esplicito e accesso all'intero livello. Sul desktop conservare il mega-menu a due aree e distinguere il percorso corrente dalla semplice anteprima di un settore. Le tre slice sono ordinate in sezione 7; tutte **NON AVVIATE** e subordinate ad approvazione.

Metodo applicato: ONSUS originale -> fonti ecommerce/UX attuali -> architettura KeepStore -> proposta mobile-first. Browser interattivo non disponibile in questa sessione: consultati codice, reference locale e pagine pubbliche tramite estrazione web. **Nessuno screenshot nuovo, tap, hover, focus, screen reader, misura live del DOM o test visuale a 360/390/1365 effettuato.** I wireframe e le dimensioni sotto sono specifiche proposte, non risultati QA. Lo smoke production A della PR #323 e un gate comunicato dal Product Owner, distinto da questo benchmark.

## 2. Fonti e osservazioni verificabili

### ONSUS originale

Reference disponibile in sola lettura: `C:\KeepStoreWeb\_aspnet_precompile_checkout4_20260520184528\Public\assets\keepstore\`. E una copia locale del template presente in un precedente output di precompile, non una nuova verifica di versione/licenza del package upstream e non una sorgente runtime da distribuire.

Esaminati:

- `shop-default.html`: header con All Categories separato dalla navigazione generale; mega-menu della navigazione principale; offcanvas `#mobileMenu`, tab Menu/Categories e collapse di categorie demo. La ricerca del drawer e nel tab Menu, non in una testata permanente condivisa dai due tab.
- `scss/component/_header.scss`: `.canvas-mb`, `.mb-body`, `.mb-canvas-content`, `.nav-ul-mb`, mega-menu; scrolling del corpo, divisori, righe flex e indicatore separato di espansione.
- `scss/_responsive.scss`: separazione desktop sotto/sopra 1200px e drawer mobile con massimo 320px nel riferimento.
- `js/main.js`: controllo apertura `.active-container/.btn-active`, adattamenti menu, `sidebarMobile`, trasformazione del select demo e gestione header sticky. Sono meccanismi di riferimento, non codice da importare o reinizializzare.

**Da riusare:** famiglia visuale, spaziatura coerente, superfici pulite, offcanvas, lista gerarchica e navigazione desktop separata. **Da non copiare:** tab che aggiungono una barriera prima dei prodotti, close in uno span, ancore demo `#`, toggle con stato ARIA non coerente, custom select o dati/icone merceologiche demo. KeepStore ha gia corretto diversi di questi limiti: non regredire per somigliare al template.

### Ecommerce: consultazione 2026-10-09

Nel Masterplan corrente i brand esplicitamente nominati per questo confronto sono **IKEA e Decathlon**; erano proposte di benchmark, non precedenti collaudi visuali. Aggiunto **MediaWorld** come grande retailer di elettronica: comprende anche elettrodomestici e accessori, quindi aiuta a valutare una navigazione ampia, senza trasformare KeepStore in un catalogo tech obbligatorio.

| Fonte primaria | Osservato nell'estrazione pubblica | Trasferibile / limite |
| --- | --- | --- |
| [IKEA prodotti](https://www.ikea.com/it/it/cat/prodotti-products/) | Famiglie riconoscibili, sottogruppi e accesso esplicito all'intera famiglia | Collegare chiaramente il livello ampio ai figli; non copiare nomi o organizzazione merceologica |
| [IKEA ambienti](https://www.ikea.com/it/it/rooms/), [HOME](https://www.ikea.com/it/it/) | Percorso per ambienti distinto da quello per prodotti | Interessante per orientamento, ma KeepStore non ha qui dati autorevoli per un secondo albero per esigenze: differito |
| [Decathlon HOME](https://www.decathlon.it/), [indice sport](https://www.decathlon.it/tutti-gli-sport) | Ricerca, famiglie sportive e indice completo organizzato alfabeticamente | Dimostra come un catalogo ampio possa restare esplorabile; non adottare l'ordine alfabetico contro l'ordine del provider |
| [MediaWorld HOME](https://www.mediaworld.it/) | Ricerca e accesso alle categorie; collegamenti a famiglie come Computer e Telefonia, separati dalle offerte | Coordinare ricerca e navigazione, non sostituire tutto con promozioni |

Per tutti e tre: verificati contenuti/etichette e link estratti, **non** geometria, mega-menu aperto, transizioni mobili, numero effettivo di tap, ricerca sticky o accessibilita end-to-end. Un successivo accesso all'indice Decathlon ha restituito errore del fetch, poi l'apertura e riuscita; la pagina Computer di MediaWorld non e stata acquisita dal tool. Non sono evidenze di guasti dei siti. Non si attribuisce a nessun retailer il drill-down qui proposto senza averlo osservato.

### Ricerca UX e accessibilita

- [Baymard, navigazione ecommerce](https://baymard.com/research-articles/ecommerce-navigation-best-practice): articolo aggiornato 2025-09-30; utile per evitare sovraffollamento, rendere riconoscibile il contesto e chiarire le destinazioni. Non impone una soglia numerica universale o un limite ai dati KeepStore.
- [Baymard, primo livello mobile](https://baymard.com/research-articles/main-navigation-product-categories): pubblicato 2023-01-24; supporta l'esposizione diretta delle famiglie prodotto, senza un ulteriore gate generico. Motiva la priorita 1, non una promessa di incremento delle vendite.
- [Baymard, accesso al livello intero](https://baymard.com/research-articles/mobile-main-nav-view-all): pubblicato 2022-11-16; raccomanda un accesso esplicito e iniziale al livello ampio. KeepStore lo possiede gia: va preservato, non ricostruito.
- [W3C APG, disclosure navigation](https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/): riferimento per button/link, stato espanso e tastiera; normale navigazione di sito, non un widget `role=menu` imposto. Gli esempi richiedono QA reale con tecnologie assistive.

Tutte le fonti sono state consultate alla data del task. Gli articoli non sono nuovi studi KeepStore: nessun tasso di conversione, tempo di completamento o superiorita visuale e stato misurato. Il progetto sotto e una **deduzione di design** da queste evidenze e dal codice, non una descrizione copiata dei retailer.

## 3. KeepStore corrente: cosa mantenere, cosa migliorare

Fonti locali: `Public/ui/controls/SiteHeader.ascx` e relativo code-behind; `Public/assets/keepstore/css/theme-overrides.css`; `Public/assets/keepstore/js/ks-page-flags.js`; `App_Code/CatalogMenuProvider.vb`; checkpoint Masterplan, System Blueprint 2.0.2.1/2.6.1/5.4 e AI Assisted Search, guardrail e ricerca deterministica. Riutilizzati gli audit precedenti, senza nuove query DB o ripetizione delle suite.

### Gia valido: conservare

- Un solo `#mobileMenu`; apertura/chiusura e collapse di Bootstrap 5.3.2, button distinti dalle destinazioni, focus-visible e target minimi 44px gia presenti. Immagini settore 30x30 contain, corrette dalla PR #316.
- Tree completo `Settore -> Categoria -> Tipologia`; link `st`, `st+ct`, `st+ct+tp`; accessi Vedi tutto il settore / Vedi tutta la categoria. Nessuna categoria o tipologia di default.
- Select nativi desktop/mobile della PR #315; current-scope condiviso della PR #322 tramite resolver reale; neutro per contesto mancante/invalidita. Il submit primario, anche vuoto, resta autorevole. Espandere una voce del menu **non deve** cambiare l'ambito di ricerca.
- Provider cached della PR #321: tree condiviso dai consumer, chiave database configurato/fingerprint e durata 600s. E una cache di tassonomia, non una cache di tenant, account o prezzi. Nessun secondo tree o resolver da introdurre.
- Compattazione #323 integrata: non ripristinare span e whitespace serializzati solo per comodita di formattazione; non duplicare i template.

Fixture dell'audit precedente: **18 settori, 132 categorie, 528 tipologie; Informatica ha 35 categorie; 678 destinazioni mobile uniche**. Sono dati osservati di Taikun, non costanti, target universali o una nuova lettura del DB. Misure #323 riutilizzate: header/offcanvas **343.446 byte UTF-8 non compressi / 4.588 elementi server-side**, rispetto ai precedenti 752.671 byte / 5.644 elementi. Non sono il DOM live dopo JavaScript, gzip o una misura di INP.

### Attriti dimostrati e rischi distinti

| Finding | Evidenza / severita | Impatto e decisione |
| --- | --- | --- |
| N01: settori nascosti alla prima apertura | ASCX: Home precede Catalogo; `#ks-mobile-catalog-root` e `collapse`, button `collapsed`, `aria-expanded=false`. MEDIUM UX | Un'attivazione aggiuntiva prima di vedere i reparti. **Primo micro-task**, non blocker di questa consegna docs |
| N02: navigazione mobile verticalmente cumulativa | Tre disclosure annidate; nessun `data-bs-parent` limita le espansioni; nessun ritorno esplicito al genitore. MEDIUM UX | Piu rami possono allungare lo scroll e i figli perdono larghezza per l'indentazione. Seconda slice; non dichiarare un overflow non misurato |
| N03: ambito di ricerca corretto, ma anteprima non equivale a percorso | Code-behind applica il context ai select; builder mega-menu non emette il percorso corrente; CSS puo evidenziare il primo settore all'apertura indipendentemente da `st`. MEDIUM UX | Distinguere hover/focus, anteprima e posizione corrente. Terza slice, senza riaprire #322 |
| N04: costo residuo del catalogo completo | Audit #323: versioni desktop/mobile e select ancora server-rendered; riduzione byte non elimina crescita lineare. MEDIUM performance | Debito separato: niente lazy loading, endpoint, ViewState surgery o promessa di latenza in questa roadmap UX |

N01 e il tap superfluo verificabile nel markup; N02/N03 sono rischi sostenuti dalla struttura, **non risultati di un nuovo test utente**. Il comportamento di ricerca gia stabilizzato non e un finding da correggere.

## 4. Matrice Design Gate

| Aspetto | ONSUS | Ecommerce benchmark | KeepStore corrente | Proposta |
| --- | --- | --- | --- | --- |
| Primo accesso mobile | Tab Menu/Categories | Baymard: prodotti disponibili subito | Gate Catalogo chiuso | Primo livello aperto e prioritario, senza tab aggiuntivi |
| Livello ampio | Link demo, non contratto dati | IKEA: famiglie e accesso completo; Baymard: accesso esplicito | Vedi tutto gia presente | Preservare URL e prima posizione nel ramo |
| Gerarchia | Collapse annidati | Decathlon: ampiezza organizzata; drill-down retailer non collaudato | S/C/T completi, rami cumulativi | Un pannello alla volta nel target successivo, non tagliare nodi |
| Ricerca | Ricerca nel tab Menu, custom select demo | Decathlon/MediaWorld: ricerca nell'estrazione | Select reali, scope corretto | Preservare controlli e submit; testata del drawer accessibile nel target |
| Orientamento | Stile active/hover del template | Baymard: contesto riconoscibile | Select corretto; preview desktop del primo settore | Percorso reale distinto dall'anteprima, senza inferenze da etichette |
| Desktop | All Categories e mega-menu separati | MediaWorld: famiglie riconoscibili, non mega-menu osservato | Lista settori + pannello a tre colonne | Tenere struttura; migliorare orientamento, non rifare tutto |
| Spazio e accessibilita | Drawer 320px, righe flex | W3C: disclosure e HTML semantico | 44px/30px, focus e Bootstrap | Nessuna riduzione touch; ritorno e focus deterministici da testare |
| Prestazioni | Demo statica | Nessun budget misurato sui retailer | Tree cached e HTML compattato | Riuso dei nodi presenti; zero fetch/query extra o duplicazione |

## 5. Progetto mobile 360/390px

### Slice iniziale, deliberatamente piccola

Conservare larghezza, ricerca, spacing, close e lista esistenti. Portare Catalogo prima di Home e renderizzare il suo root **gia espanso**, con classe `show`, button non `collapsed` e `aria-expanded=true` coerenti. Non aprire automaticamente tutti i settori/categorie: solo il primo livello.

Alla prima apertura del drawer i reparti diventano immediatamente leggibili/scorribili. Alla riapertura nella stessa pagina mantenere lo stato scelto dall'utente, senza un handler che forzi il reset. Un nuovo GET riparte dal root aperto. Anche richiudere Catalogo resta possibile: Bootstrap conserva il controllo. Nessun nuovo JS, CSS o modifica desktop necessaria per questa slice.

I 18 settori attuali sono tutti raggiungibili, nell'ordine del provider; non devono stare tutti nel primo viewport. Non creare un massimo di 18, una selezione di 6 "migliori", gruppi inventati o scomposizioni in tab. Cataloghi vuoti/piccoli/grandi non devono causare settori fittizi, duplicazioni o crash.

### Target successivo: percorso guidato, non muro di voci

Schema funzionale proposto, non mockup visuale certificato:

```text
ROOT                          SETTORE                         CATEGORIA
Catalogo             [X]      [< Tutti i settori]    [X]      [< Settore padre]    [X]
Ambito di ricerca             Ambito di ricerca               Ambito di ricerca
[select nativo]               [select nativo]                 [select nativo]
[Cerca prodotti] [Cerca]      [Cerca prodotti] [Cerca]        [Cerca prodotti] [Cerca]
Tutti i settori               Nome settore                    Settore / Categoria
[media] Nome settore [>]      Vedi tutto il settore           Vedi tutta la categoria
[media] Nome settore [>]      Nome categoria          [>]     Nome tipologia -> catalogo
... tutti, con scroll         ... categorie, con scroll       ... tipologie, con scroll
Home / Offerte / Contatti     ... ritorno allo stesso punto   ... ritorno allo stesso punto
```

- Drawer target full-width sui telefoni 360/390, massimo 390px, padding orizzontale 16px; non applicare un mega-menu desktop in miniatura. Sotto 1200px mantenere la variante mobile/tablet; desktop da 1200px come oggi.
- Ricerca su due righe con select full-width e input + submit 44px, preservando ID, naming container, label e un solo esemplare dei controlli WebForms. Nessun form HTML annidato o copia del suggest.
- Testata con close e ricerca fuori dal corpo scorrevole; un solo scroller di contenuto. Con tastiera virtuale o viewport basso, privilegiare input e contenuto raggiungibile: testata non deve consumare tutta l'altezza. No footer utility permanente alto che sottragga spazio ai prodotti; utility dopo il contenuto, sempre raggiungibili.
- Un solo livello commerciale visibile per volta, label complete che possono andare a capo, immagini reali 30px dove gia presenti; righe almeno 44px, indicativamente 48px. Corpo senza indentazione cumulativa. Non aggiungere immagini per categoria/tipologia se il provider non le espone.
- Ogni ramo comincia con il suo link Vedi tutto; button sull'intera riga apre i figli, link distinto naviga. Nessuna doppia azione invisibile tra testo e freccia. La freccia decorativa non costituisce un secondo target touch.
- Ritorno al genitore senza GET e senza perdere posizione/focus; la X chiude il drawer e restituisce focus all'hamburger. Nuova richiesta = stato pulito. La riapertura nella stessa pagina conserva percorso/scroll; nessuna nuova persistenza localStorage/cookie.
- Bootstrap resta proprietario di offcanvas/collapse e degli attributi di stato. Eventuale adattatore di pannelli/focus lavora tramite API/eventi ufficiali e classi presentazionali, non un secondo motore di toggle. Senza adattatore il tree server-rendered e le disclosure attuali restano il fallback; nessun contenuto essenziale escluso dal DOM.
- La sola anteprima di un ramo non modifica URL, selezione di ricerca o stato commerciale. Ricerca sempre esplicita nell'ambito mostrato; select neutro continua a significare tutti i settori, non un settore nascosto ricordato dall'altro controllo.

**Budget di interazioni, dedotto dalla struttura**, partendo da drawer chiuso e rami chiusi; scroll escluso, nessuna misura di tempo o successo utente:

| Destinazione | Oggi | Primo intervento | Target a pannelli |
| --- | --- | --- | --- |
| Vedere i settori | 2: hamburger + Catalogo | 1: hamburger | 1 |
| Tutto un settore | 4: hamburger, Catalogo, settore, Vedi tutto | 3 | 3 |
| Tutta una categoria | 5: aggiunge categoria + Vedi tutto | 4 | 4 |
| Una tipologia | 5: hamburger, Catalogo, settore, categoria, tipologia | 4 | 4 |

Il target a pannelli migliora orientamento e larghezza, non riduce ulteriormente i tap sul percorso sopra. Non promettere di risolvere il catalogo a un solo tap.

## 6. Desktop 1365px e WOW utile

Conservare il blocco Catalogo distinto dai link Home/Offerte/Contatti. Alla larghezza 1365 il menu corrente offre massimo 1040px, lista settori 270px e pannello restante; questi sono valori letti dal CSS, non geometria browser misurata ora. Tenere limite legato all'altezza viewport e scrolling raggiungibile delle due aree, senza spingere il documento.

Target: lista settori con media esistente e nomi leggibili; nel pannello titolo del settore, link esplicito all'intero settore e gruppi categoria con heading cliccabile. Conservare tutte le categorie/tipologie e l'ordine autorevole; nessun limite alle 35 categorie di Informatica. Tipologie nei gruppi reali, non in nuove famiglie dedotte. Il percorso corrente e distinto dal ramo semplicemente esplorato: la prima anteprima non deve sembrare una scelta tassonomica dell'utente. CSS responsive senza nuovi spazi promozionali o card prodotto nel mega-menu.

Click/focus/tastiera devono offrire le stesse destinazioni dell'hover. Chiusura con Escape, fuori menu e uscita dal percorso di focus da verificare nel task pertinente; non dichiarate oggi PASS. In particolare, il listener `mouseenter` corrente apre immediatamente: il ritardo hover e un rischio da collaudare, **non** parte del primo intervento mobile, e non motiva ora un algoritmo di mouse intent.

| Miglioramento utile | Fattibilita | Scelta |
| --- | --- | --- |
| Settori subito disponibili | Stato iniziale del markup esistente, zero nuova logica | Priorita 1 |
| Ritorno con posizione/focus preservati | Tree gia nel DOM; adattatore presentation-only, QA necessario | Priorita 2, nessuna persistenza nuova |
| Percorso corrente riconoscibile | Context/resolver esistenti; distinguere route reale e anteprima | Priorita 3, niente secondo resolver |
| Animazione breve e non necessaria al compito | Solo presentation, rispettare reduced-motion | Facoltativa nella slice 2, non un nuovo task |
| Catalogo per esigenze, raccomandazioni AI o link personalizzati | Richiede dati/capability/privacy e nuovi contratti | Differito: non implementare in questa sequenza |

WOW significa **trovare il reparto, sapere dove si e e poter tornare**, non una nuova animazione, un banner commerciale, contatori prodotti inventati o ordinamento per popolarita non disponibile. ViewState, lazy loading, cache invalidation e handler legacy LOW restano debiti separati, non micro-task avviati qui.

## 7. Roadmap: massimo tre slice, nessuna avviata

### 1. HEADER-MOBILE-CATALOG-ENTRY-DISCOVERABILITY-1A — PRIMO RACCOMANDATO

- Problema/gain: N01; risparmiare il tap generico iniziale e mostrare subito la merceologia reale.
- Funzione: Catalogo prima di Home; root espanso al rendering con classi/ARIA coerenti; settori/categorie interni restano chiusi e controllati da Bootstrap. Stato della riapertura mantenuto senza nuovi handler.
- **Superficie runtime prevista: solo `Public/ui/controls/SiteHeader.ascx`.** Checkpoint nel Masterplan nel futuro manifest autorizzato; nessun CSS/JS/VB/Page.master necessario alla soluzione minima.
- Rischio basso: contenuto iniziale piu lungo; mantenere scroll, ricerca e utility accessibili. Dipendenza: approvazione di questo design e base Git aggiornata. Non riformattare il template compatto #323.
- Test indispensabili: browser 360/390, poi 768/1365; apertura iniziale, close/reopen, collassa/espandi, ultimo settore e ultimi figli raggiungibili, target/focus/tastiera, scroll e assenza overflow. Confronto URL/testi/ordine/678 destinazioni sulla fixture disponibile; tree sintetici vuoto/piccolo/grande e due merceologie. Search neutra/scoped desktop/mobile, HOME/catalogo/PDP e assenza duplicazioni/regressione desktop. Precompile 4.8 e smoke server Product Owner nel futuro task runtime.
- Stato: **NON AVVIATO**. Non anticipa il drill-down o la nuova geometria.

### 2. HEADER-MOBILE-CATALOG-PROGRESSIVE-PANELS-1A

- Problema/gain: N02; evitare scroll cumulativo e perdita di larghezza, dare un ritorno esplicito al punto di scelta.
- Funzione: un livello per volta, testata/search accessibili, Vedi tutto iniziale, back con scroll/focus, transizioni senza rete. Root della slice 1 e baseline funzionale.
- **Superficie runtime prevista:** `Public/ui/controls/SiteHeader.ascx`, relativo `.ascx.vb`, `Public/assets/keepstore/css/theme-overrides.css`, `Public/assets/keepstore/js/ks-page-flags.js`, `Page.master` soltanto per cache-buster. Nessun endpoint, provider, resolver, asset o modifica search handler. Il manifest esatto va approvato prima dell'implementazione.
- Rischio medio: state machine, Bootstrap transizioni, focus e WebForms search. Riusare i nodi/controlli; vietato copiare e reinizializzare menu o suggest. Dipendenza: slice 1 chiusa e review del mapping eventi Bootstrap. Se questo richiede un altro motore di navigazione o superficie diversa, STOP B.
- Test: quattro viewport, tastiera virtuale, cambio orientamento, percorsi S/C/T, ritorno e scroll, riapertura, Escape/focus trap, reduced-motion, rami senza figli, ultime voci e label lunghe; search durante ogni livello, controlli server unici e stesso submit; fallback senza adattatore, parita URL/DOM e nessuna richiesta DB/rete aggiuntiva. Precompile e smoke server.
- Stato: **NON AVVIATO**, non autorizzato da questa PR documentale.

### 3. HEADER-DESKTOP-CATALOG-CURRENT-PATH-1A

- Problema/gain: N03; distinguere la posizione reale dall'anteprima/hover del mega-menu mantenendo l'impianto desktop.
- Funzione: segnare il percorso tassonomico valido usando il resolver esistente, evidenziare il nodo corrente e genitori con stati distinti; titolo settore e accesso all'intero settore chiari. Un contesto assente/invalido resta neutro, senza deduzione per nome o primo nodo. Focus/anteprima non modificano route o scope della ricerca. Nessuna nuova attribuzione PDP da query DB dedicata.
- **Superficie runtime prevista:** `Public/ui/controls/SiteHeader.ascx.vb`, `Public/assets/keepstore/css/theme-overrides.css`, `Page.master` solo cache-buster. Se serve toccare ASCX/JS o harden la chiusura, nuova decisione di manifest prima di procedere, non fix implicito.
- Rischio medio: stile current contro primo pannello automatico e tab order. Dipendenza: #322/#323 preservate, context riusato in request e QA del percorso senza query duplicate. Non rifare select nativi o breadcrumb/JSON-LD.
- Test: 1365 e 1920, zoom/tastiera, neutral/valid/mismatch/duplicate st-ct-tp, primo/ultimo settore, nomi lunghi, click heading e tipologie, stessa tassonomia e ricerca; 360/390/768 invariati, due tree di merceologia diversa. Precompile e smoke server. Nessuna promessa di risolvere la densita totale con un semplice highlight.
- Stato: **NON AVVIATO**; segue il mobile, non blocca la prima slice.

## 8. Gate documentale e non-regressione

La proposta non introduce una nuova fonte dati: il provider decide albero, ordine, URL e asset disponibili; il resolver decide il contesto; i renderer producono HTML encoded; Bootstrap e gli handler stabilizzati decidono le rispettive interazioni. Navigazione e facet restano separati. Nessun hardcode di ID, brand, database, nomi di reparti o numero di nodi nei futuri sorgenti; fixture 18/132/528 solo documentale.

Ricerca deterministica, suggest, ranking, endpoint, prezzi/listini/IVA/promo, cart-state, autenticazione, checkout, email, canonical/breadcrumb/JSON-LD restano invariati. La AI Assisted Search Blueprint e un confine di compatibilita, non autorizzazione ad AI/RAG o uso di cookie/carrello/account per personalizzare il menu. Nessun servizio, query per nodo, DB write o dato commerciale inventato.

Checklist della consegna: due soli documenti; checkpoint #323 chiuso con SHA/Git e smoke Product Owner distinti dalle prove Codex; fonti con link/data/limiti; matrice e specifiche proposte; tre micro-task non avviati e un solo primo consigliato; diff-check e secret scan. Niente precompile o smoke runtime per questa PR docs-only.

Prossimo passo: review indipendente ChatGPT della PR DRAFT documentale; approvazione di design, priorita e manifest della sola slice 1. **Nessun merge o avvio runtime implicito.**
