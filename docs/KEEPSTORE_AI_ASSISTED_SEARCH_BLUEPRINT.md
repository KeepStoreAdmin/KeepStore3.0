# KeepStore AI Assisted Commerce Search Blueprint

Stato: blueprint architetturale, non implementazione runtime.

Questo documento definisce la direzione futura per una ricerca assistita / assistente acquisto multi-merceologia in KeepStore 3.0. La funzione deve nascere sopra la ricerca deterministica esistente e sopra i dati reali del catalogo, senza introdurre API AI, nuove tabelle, endpoint o modifiche runtime in questa fase.

Nota permanente stack/sicurezza: qualunque task runtime futuro legato a search, assistenza acquisto o AI deve rispettare il contratto tecnico generale KeepStore: ASP.NET WebForms, VB.NET, .NET Framework 4.x e MySQL; niente C#, ASP.NET Core, Razor/MVC/Blazor, EF Core, migrations, API rewrite, nuove pipeline npm/Vite/Webpack o librerie senza audit e approvazione. Input, querystring, redirect, output e dati catalogo devono restare validati/encoded lato server, con query parametrizzate e whitelist dove servono. OWASP Top 10, OWASP ASVS e Microsoft ASP.NET WebForms / ASP.NET 4.x security sono i riferimenti metodologici.

Nota roadmap permanente: le funzioni search/AI/SEO seguono la scaletta prioritaria del masterplan e non devono scavalcare i blocchi ecommerce/UX gia pianificati. La proposta futura `llms.ashx` / `llms.txt` / JSON-LD dinamico resta in Priorita 8 e richiede prima `LLMS-TXT-ASHX-JSONLD-AUDIT-1` read-only, con approvazione esplicita Germano prima di qualunque runtime. Non usare C#, ASP.NET Core, controller o routing Core; la pagina prodotto reale e `articolo.aspx`, non `prodotto.aspx`.

Regola stato: chiudere un micro-task su `articoli.aspx` non significa dichiarare completa la pagina catalogo. Sono chiusi micro-task su card, selezione multipla, quantita/delta/visual mobile in carrello, CTA `Acquista`, stato/paging deterministico, toolbar/quattro viste, product-image 404, compact grid, pager/posizione recent e containment mobile; search/suggest, zero-results, sidebar/facet e filtri applicati mantengono i perimetri documentati. `CATALOG-ONSUS-PARITY-AUDIT-1` e completato e i tre P0 sono chiusi, ma full ONSUS parity e gap P1/P2 restano aperti.

Nota anti-false-closure: `articoli.aspx` non e una pagina dichiarata completa. I micro-task chiusi non equivalgono alla parita ONSUS completa. Restano sidebar/facet residui, tassonomie/load-more, active filters legacy/reset, Price/Deals/Condition, Reviews con dati reali, performance, componenti commerciali e responsive complessivo. Pager, posizione recent, quattro viste mobile, compact grid e containment recent non vanno invece lasciati come gap aperti.

Checkpoint corrente 2026-09-04: `frontend-rebuild` / `origin/frontend-rebuild` a `e4211b7eb50c384898c78f78ce0b38e2832ce472`, integrato fast-forward only senza merge commit; `main` / `origin/main` invariati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`. Le directory non tracciate `Public/assets/images/articoli/`, `Public/assets/images/marche/` e `Public/assets/images/settori/` restano escluse dai commit. Anche eventuali loghi locali non tracciati sotto `Public/assets/images/vettori/` vanno preservati e possono essere aggiunti solo se nominativamente autorizzati da uno specifico manifest.

Stato login/roadmap rilevante per le future superfici AI/search: `LOGIN-RETURN-CONTEXT-1A` e `LOGIN-ACCESS-AUDIT-1A` sono chiusi / A con merge fast-forward only rispettivamente a `ffbd78ffceaca8db96baf77548732e9b94724b1e` e `2ae053771284f6d3769c7d7bfd18e3a34436bc72`. ReturnUrl e contesto shopping sono centralizzati e sicuri; l'audit accessi usa recorder server-side parametrizzato, IP diretto validato senza header proxy fidati implicitamente, incremento singolo e diagnostica senza segreti/IP completi. La migrazione manuale esterna a Git ha esteso `login.UltimoIp` a `VARCHAR(45) NULL`, lasciando invariati `UltimoAccesso DATETIME NULL` e `NumeroAccessi BIGINT NULL DEFAULT 0`.

Stato promo corrente: `HOTFIX-STOREFRONT-PROMO-DEMO-BADGE-1A` e CHIUSO / A (`f28052d821e6d0ee25f707732159030aa016d173`, REV1 `185511889279078e7b4b56c4b53b5fb59e46c1f5`) e `PROMO-COMMERCIAL-CORRECTNESS-1A` e CHIUSO / A (`9e4f33ec11afe738ae4a08fac43a73af29e2d1a3`, REV1/stable `e4211b7eb50c384898c78f78ce0b38e2832ce472`), entrambi con smoke Germano A. Il finding `Demo` e superato: badge umano `Promo` + `-NN%` o `Offerta`; promo principale solo se valida, attiva, positiva, applicabile a quantita 1 e inferiore al prezzo base. Tier, `QntMinima` e `Multipli` restano comunicati separatamente; il carrello e la fonte di verita.

Vincoli discovery promo/EAN: le label umane `EAN/GTIN` migliorano la chiarezza semantica, ma identificatori strutturati `gtin`, `gtin13`, `gtin14`, JSON-LD, feed, CSV/XML e integrazioni non sono stati modificati. I prezzi promo pubblicati devono coincidere con la logica commercialmente applicabile. HTML server-rendered, URL canonici, performance, dati prodotto completi e structured data validi restano prerequisiti; route HTTP 500 come `promozioni.aspx` devono essere risolte o classificate prima dell'indicizzazione. Non dichiarare KeepStore `SEO completo`, `Google pronto` o `AI ready`.

Roadmap vigente: `STOREFRONT-PROMO-ROUTES-AUDIT-1A` read-only; eventuale hotfix se la route e attiva o decisione separata redirect/canonical/noindex se legacy; `STOREFRONT-OFFERS-PROMO-UX-1A`; `HOME-ASYNC-CART-1A`; `PDP-BRAND-LOGO-1A`; quindi audit performance/bulk N+1, SEO tecnico, Google Product structured data e infine AI/Gemini/LLMS. `LLMS-TXT-ASHX-JSONLD-AUDIT-1` resta read-only e finale: nessun `llms.txt`, `llms.ashx`, API AI o JSON-LD dinamico e implementato ora. `articolix.aspx` 500 legacy e le due label `EAN:` nella preview non operativa `ProductDetailView.ascx` restano backlog nominativi separati. HOME, catalogo, PDP e redesign promo complessivo non sono dichiarati completi.

Richiamo operativo, senza duplicare il Masterplan: prima di ogni risposta operativa ChatGPT rilegge integralmente i tre manuali dal ref corrente, verifica direttamente GitHub/Git e i file runtime/template coinvolti. GitHub/Git prevale su manuali, handoff e memoria; ogni conflitto documentale va riconciliato. Il mobile e esperienza primaria: QA da `360px`/`390px`, nessun A visuale senza browser mobile reale, nessuna funzione essenziale hover-only. Codex esegue test strumentali; Germano verifica resa commerciale e percorsi utente semplici. Branch runtime/docs sempre pushati prima del report, un solo task attivo e solo classificazione A/B/E.

Stato storefront mobile/cart/catalog corrente, senza impatto sulla logica AI/search:

- Catena runtime incorporata: `3cdea2709712d133cfa82adb717ea9df69d0ed88`, `c747b1ca2baa2a353251e1204b9b6775a44b5c01`, `55709258786405c9f75057f171d65742cf395ffc`, `bcb1cf5e048d5641119f7d829936a423d33ec2c7`, `1e5c4070db5da39dfee26b7fa55362909dcae292`, `925244d17a87add4098266b273e8a45b2428c2c4`, `b31f8177e09cffcd5e9193e1e26eb3bbec4f8e6b`.
- Cart awareness e feedback: add-to-cart con ritorno a URL shopping locale validato, feedback success one-shot, stato `Nel carrello attivo: N pz.` da `CartStateSnapshotProvider`; `window.KeepStoreCartState` resta decorazione client e `localStorage` non e source of truth. Green state leggero senza barra laterale e senza badge sovrapposto alla fotografia; delta PDP `2 -> 2`, `2 -> 3`, `2 -> 5` preservato. Side cart/offcanvas resta aperto.
- Catalogo mobile: `tabgrid-1`, `tabgrid-2`, `tablist-1`, `tablist-2`; preferenza soltanto presentazionale in `sessionStorage["KeepStore:CatalogLayout"]`; usare `.ks-view-layout-switch`, mai `.tf-view-layout-switch`. Disponibilita, cart-awareness, quantita, multiselect e `Acquista` restano presenti.
- `tabgrid-2` compact: due colonne mobile dove appropriato, cinque a desktop `1365`; foto bianche/contain/center. Card flex/equal-height, purchase row bottom-aligned, titoli/meta contenuti, `product-tag` mobile con ellipsis e Recently Viewed dinamico con flex dedicato. Titoli catalogo/recent circa tre righe via CSS; testo completo nel DOM dopo rimozione di `CompactText(Descrizione1, 72)`; titolo PDP completo preservato.
- Pager server-side: source of truth `pg` + `DataPager`, UI `« Precedente Pagina N di TOT Prossimo »`, URL da `BuildCatalogPageUrl()`, visibile solo con piu pagine. Ordine pagina: `gridLayout`, `ksMultiFooter`, `ksPagerWrap`, `ksRecentlyViewedBlock`.
- Smoke Germano A espliciti: `STOREFRONT-CART-FEEDBACK-AND-AWARENESS-1A`, `CATALOG-MOBILE-FOUR-VIEWS-1A`, `CATALOG-CART-AWARENESS-CARD-ALIGNMENT-1A`, `CATALOG-MOBILE-RECENT-CARD-TAG-CONTAINMENT-1A`, `CATALOG-STRUCTURE-PAGER-COMPACT-GRID-1A`. I polish intermedi sono solo incorporati, senza smoke A inventati.
- Browser QA reale su `https://localhost:8443`: `360x800`, `390x844`, `430x932`, `768x1024`, `1365x900`, sanity `1920x1080`. A visuale richiede il browser runtime reale; senza browser va dichiarato B. Nessuna dipendenza browser/Playwright nel repository.
- `HOTFIX-CARD-LAYOUT-1A` e chiuso al commit `982cc83bcbcbb913dd1e320ece456957801f8121`: contratto product card condiviso `.ks-card-category`/`.ks-card-title`, categoria 2 righe, titolo 3 righe, testo completo nel DOM, HOME/catalogo/PDP/recenti e fallback JavaScript coperti; sidebar catalogo contenuta senza perdere facet e Recent METEOR riallineata. Non rende completi catalogo o PDP.
- `CATALOG-ASYNC-CART-1A` e CHIUSO / A sul branch `task/catalog-async-cart-1a`, base `588bde58a328df8ee7a430652b2397a77bdb726c`, commit `e92139f4e81e5619b632c14d8808ef76ffe55375` e revisione finale `b80f8d4683bbb9bb6ec8a7a486a79048bfae094f`, incorporati fast-forward. Smoke autorizzante: `SMOKE UTENTE CATALOG-ASYNC-CART-1A REV1: A`. Il catalogo usa POST asincrono same-origin verso l'endpoint WebForms esistente, riusa validazione e logica commerciale server-side, include protezione CSRF/ViewState pertinente e conserva idempotenza e stato carrello senza reload; JavaScript non diventa source of truth per prezzi, quantita o carrello.
- Revisione `ReturnUrl`: accettare solo destinazioni shopping locali validate, normalizzare gli URL assoluti same-host a `PathAndQuery`, rifiutare schemi/host esterni e mantenere priorita deterministica tra contesto esplicito valido, sessione shopping valida, referrer locale idoneo e fallback sicuro. Login/checkout e redirect sensibili restano separati dal semplice add-to-cart anonimo.
- `STOREFRONT-CARD-BUY-CTA-STABILITY-1A` e CHIUSO / A al commit storico `58f4ee43c363d629b3124fc0fb1a10beaeeef48a`, branch `task/storefront-card-buy-cta-stability-1a`, base `b80f8d4683bbb9bb6ec8a7a486a79048bfae094f`, merge fast-forward e smoke utente A. La CTA `.ks-compact-buy-cta` resta un controllo quadrato stabile `44x44`, con icona, tooltip accessibile, spinner senza salto geometrico e adattamento via container query. I precedenti riferimenti storici alla CTA con testo `Acquista` espandibile su hover/focus sono superati da questo contratto; nessuna logica ecommerce o JavaScript e stata cambiata dal polish di stabilita.
- `PDP-COMMERCIAL-INFO-SHIPPING-1A` e CHIUSO / A a `91cbc10b3b343217e18c5a9a6707b72997467b00`, dopo implementazione `afc4c72c148984ba729c6cb20de38161dc56e2b4` e REV1 IVA allineata al carrello; merge fast-forward, nessun merge commit, smoke Germano A. Il micro-task riguarda informazioni commerciali e tariffe reali del singolo articolo; non modifica search, ranking o runtime AI e non dichiara complete PDP o catalogo.
- Nota storica: `LOGIN-RETURN-CONTEXT-1A` era il prossimo runtime ufficiale ed e ora chiuso / A, insieme a `LOGIN-ACCESS-AUDIT-1A`. La precedente roadmap che partiva dall'hotfix `Demo` e dall'audit promo ONSUS e superata dalle chiusure promo correnti e dalla roadmap route/UX/HOME async sopra. Side cart, parity P1/P2 e blocchi ecommerce restano separati; SEO/AI/Gemini/LLMS rimane priorita finale. Catalogo e PDP non sono dichiarati completi.

## 1. Principio multi-merceologia

L'assistente acquisto non deve contenere domande hardcoded valide per tutti i negozi. KeepStore e rivendibile e multi-azienda: Taikun, Webaffare e futuri ecommerce possono avere merceologie molto diverse.

Il comportamento futuro deve derivare il piu possibile da:

- settori, categorie, tipologie, gruppi e sottogruppi;
- marche;
- codice articolo ed EAN;
- descrizione breve, descrizione estesa e descrizione HTML;
- schede tecniche o campi tecnici gia disponibili, da auditare prima di usarli;
- attributi/varianti gia presenti, come taglia, colore e TC;
- disponibilita, promo, prezzo, listino e immagini;
- prodotti visti di recente e ricerche recenti client-side;
- lo stato UI dei prodotti in carrello esiste gia nello storefront tramite snapshot server-side; il suo eventuale uso come contesto dell'assistente AI/search resta futuro e richiede task privacy/consenso esplicito;
- configurazioni azienda/sito solo con task dedicato.

Gli esempi merceologici sono linee guida, non logiche da hardcodare:

- alimentari: gusto, formato, quantita, dieta/intolleranze se presenti nei dati, marca, prezzo e disponibilita;
- bibite: tipo bevanda, gusto, formato, zucchero/zero, confezione e marca;
- pittura, Vintage, Shabby Chic: superficie, effetto desiderato, colore, finitura, uso interno/esterno e accessori collegati se presenti;
- elettronica/informatica: compatibilita, marca, modello, codice/EAN e caratteristiche tecniche;
- cartucce/toner: marca stampante, modello stampante, codice cartuccia, colore, originale/compatibile se presente nei dati.

Regola permanente: l'assistente deve leggere il catalogo del sito corrente e proporre domande coerenti con quella merceologia. Non deve trasformare esempi Taikun/Webaffare in comportamento fisso per tutti.

## 2. Stato ricerca attuale

Audit `SEARCH-HEADER-CATALOG-AI-AUDIT-1A`: esito A.

Elementi gia esistenti:

- header desktop: `tbCerca`, `product_cat`, `btnSearch`, `ksSearchSuggestDesktop`;
- header mobile: `tbCercaMobile`, `product_cat_mobile`, `btnSearchMobile`, `ksSearchSuggestMobile`;
- home: blocco "AI locale KeepStore" in `Default.aspx` con `home-default.js`;
- endpoint suggest: `/search_suggest.aspx`, anche con `mode=ai`;
- pagina risultati: `articoli.aspx`;
- datasource principale: `vsuperarticoli`;
- ranking deterministico gia presente;
- preview immagini suggest gia presente;
- recent searches/recent viewed lato client gia presenti.

Campi gia cercati o disponibili nella ricerca attuale:

- `Codice`;
- `Ean`;
- `Descrizione1`;
- `Descrizione2`;
- `DescrizioneLunga`;
- `DescrizioneHTML`;
- `MarcheDescrizione`;
- `SettoriDescrizione`;
- `CategorieDescrizione`;
- `TipologieDescrizione`;
- `GruppiDescrizione`;
- `SottogruppiDescrizione`;
- disponibilita, promo, prezzo/listino, vetrina, visite, immagini e TC dove gia esposti.

Stato micro-task search deterministica post PR #222/#223/#224:

- `CATALOG-ONSUS-PARITY-AUDIT-1`: COMPLETATO / READ-ONLY, esito operativo E per P0 reali, non audit fallito. Nessun file modificato. P0: stato `st/ct/q` contaminabile da Session, paging/pagina 2 non deterministici e immagini prodotto 404. Stato e paging sono chiusi da `1A`; immagini sono chiuse da `1C`: tutti e tre i P0 risultano CHIUSI.
- `CATALOG-ONSUS-PARITY-1A`: CHIUSO / A, commit `1acbba90a4e9973da695ec08a80840fd113a90fa`. QueryString e source of truth, Session solo mirror corrente; niente fallback stale di `st/ct/q/pg`. Paging: `pg` invalido/assente -> 1, positivo -> N, guard `catalogPagerSettingsApplying`; page-size server-side whitelist `12/24/48/96`, legacy `15 -> 12`, cambio size -> pagina 1. Smoke Codex/Germano A, HTTP/build A.
- `CATALOG-ONSUS-PARITY-1B-TOOLBAR-CONTROLS`: CHIUSO / A, commit/stable `9903687f89f99073d29cc0598746e17511f7e546`, merge fast-forward e smoke Germano A. Toolbar reale da `shop-default.html`, quattro viste `tabgrid-1/tabgrid-2/tablist-1/tablist-2`, result range encoded, Mostra/Ordina server-side e Filtri responsive. Desktop `1365x900`, tablet `820x900`, mobile `390x844` A.
- Guardrail toolbar: `.ks-view-layout-switch` evita il reset distruttivo del `main.js` associato a `.tf-view-layout-switch`; `sessionStorage` key `KeepStore:CatalogLayout` conserva solo la preferenza grafica whitelist e non diventa fonte di verita per carrello, quantita, prezzi, filtri business o autenticazione. Ecommerce e cart-state restano preservati in tutte le viste.
- `CATALOG-ONSUS-PARITY-1C-IMAGE-PATH-404`: CHIUSO / A, branch `task/catalog-onsus-parity-1c-image-path-404`, commit `817966edc417c907a79a20f22f9cf6f84d4a17f6` (`fix: centralize product image resolution`) e polish/stable `9a6e5b1babc836adb33cd43f930a112cd6e77103` (`fix: polish missing product image placeholder`), merge fast-forward e smoke Germano A.
- Contratto product-image: path canonico `/Public/assets/images/articoli/`; `ThemeManager.ProductImageUrl()`, `ProductThumbnailImageUrl()` e `PlaceholderProductImageUrl()` sono l'unica source of truth. HTTP/HTTPS/data preservati; valori locali normalizzati al solo filename, path traversal respinto, esistenza verificata per-file e filename URL-escaped. Thumbnail reale -> thumbnail; thumbnail assente -> full; full assente -> placeholder. Vietato riattivare resolver product-image verso `Public/foto`, `Public/Foto`, `Public/Images` o `/Public/images/nofoto.gif`.
- Placeholder canonico `/Public/assets/images/img/placeholder.svg`: SVG `800x800`, responsive, professionale, accento `#D80027`, testo `Immagine non disponibile`, Arial, accessibile, statico e senza riferimenti remoti. Se il file fisico manca, `ThemeManager` usa un piccolo data URI SVG di emergenza. `/Public/assets/images/settori/` resta dominio separato; entrambe le directory asset non tracciate non vanno committate automaticamente.
- Le superfici product-image rilevanti convergono sul resolver centrale, incluso carrello senza piu `normalizeCartImage()`/`img.onerror` riparativo. QA: q=hp image 404 = 0; HOME/catalogo/pg=2/PDP/carrello/placeholder HTTP 200; build, diff check, secret scan e smoke Germano A. Manifest cumulativo: 24 file unici modificati, 0 aggiunti/eliminati. `articolix.aspx` 500 per binding legacy `TCid` resta backlog estraneo alle immagini.
- Gap successivi: Marche load-more, tassonomie troncate, active filters legacy/reset mobile `st/ct`, Price, Deals, Condition/Ricondizionato, Reviews solo con dati reali, performance/N+1 promo, Recently Viewed, Compare empty-state e componenti commerciali. Nessuno e risolto da `1A/1B`.

- PR #222 chiusa: `catalogUrl` suggest usa `disponibile=1` e `ordinamento=...`, allineati ad `articoli.aspx`; ranking/query SQL invariati.
- PR #223 chiusa: JSON pubblico suggest non espone piu `ex.Message`; errore generico `Servizio suggerimenti temporaneamente non disponibile.` con formato `ok=false` + `error`.
- PR #224 chiusa: `SearchScore` catalogo ampliato in `articoli.aspx.vb` con `DescrizioneHTML` solo scoring, marca+descrizione, tassonomie e token multi-parola; query filtro principale, `Export +500`, Codice/EAN e query numeriche preservati.
- PR #226 chiusa: zero-results catalogo migliorato in `articoli.aspx` con query HTML encoded, CTA generiche e chip da token query; fallback statici merceologici/elettronica rimossi per multi-merceologia, senza AI attiva, prodotti inventati, query DB extra o modifiche a suggest/ranking.
- PR #228/#229/#230 chiuse: performance zero-results e sidebar filtri catalogo stabilizzate senza AI attiva. PR #228 evita facet/`showFilters()` su zero-results usando `lvProdotti.Items.Count`; PR #229 fissa l'ordine `Marche > Tipologie > Gruppi > Sottogruppi > Disponibilita > Varianti`, rimuove `Categoria` dalla sidebar e preserva `ct` come querystring; PR #230 compatta lo spacing con CSS scoped sotto `#ksCatalogPage`. Query prodotti principale, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine e gateway restano invariati.
- PR #232 chiusa: filtri applicati catalogo in stile ONSUS-like con `.meta-filter-shop`, `#applied-filters`, `.remove-all-filters` e `icon-close`; rimozione singola filtro via GET sicuro, remove-all visibile e funzionante, `st/ct` preservati, nessun chip tecnico solo ID, sidebar invariata e zero-results preservato. Query prodotti principale, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine, gateway e JS restano invariati; CSS scoped sotto `#ksCatalogPage`.
- PR #234 chiusa: navigazione `Settori` ONSUS-like sopra i facet catalogo, basata su `CatalogMenuSector` e `CatalogMenuProvider`, gerarchia `Settori > Categorie`, URL puliti `st`/`st+ct`, parametri sporchi azzerati, cache `LoadCatalogMenuCached()` 600s e rendering limitato. La label `Categoria/Categorie` e stata corretta in `Settori`; non e un facet laterale e non modifica query prodotti, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine, gateway o JS. Applied filters PR #232 e zero-results PR #226 restano preservati.
- PR #236 chiusa: card prodotto runtime catalogo `article.card-product` rifinita in stile ONSUS-like con CSS scoped sotto `#ksCatalogPage`; `.ks-catalog-card` resta fallback, non target principale. Tipografia verificata: `"Inter", serif`, titolo `14px / 600 / 22px`, prezzo `20px / 500 / 22px`, dettagli codice/disponibilita `12px / 22px`. Regola immagini DB-first documentata: placeholder `/Public/assets/images/img/placeholder.svg` solo se `ImageUrl` manca, niente `onerror` aggressivo; immagini rotte con path DB presente restano backlog asset/path. Query prodotti, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine, gateway, Settori/sidebar/filtri/applied filters e asset restano invariati.
- PR #238 chiusa: polish CSS-only di quantita/checkbox nella card runtime `article.card-product`, scoped sotto `#ksCatalogPage`. Restano invariati `tbQuantita`, `CheckBox_SelezioneMultipla`, `hfID`/`hfTCId`, `data-ks-*`, `ProductCard.ascx`, `ProductCard.ascx.vb`, `articoli.aspx`, `articoli.aspx.vb`, JS, link `cart_add.aspx`, add-to-cart, wishlist, compare e quickview; in PR #238 nessun bottone globale selezionati era ancora stato aggiunto. L'azione globale e stata poi chiusa separatamente con PR #240. Query prodotti, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine, gateway, Settori/sidebar/filtri/applied filters e asset restano invariati; card typography PR #236 preservata. Smoke visuale Germano OK / "TUTTO OK" e performance pre/post merge documentata.
- PR #240 chiusa: CTA globale `Aggiungi selezionati al carrello` completata in `articoli.aspx` per acquisto multiplo dal catalogo. Flusso: spunta `Seleziona` sulla card, quantita, invio dal footer `Acquisto multiplo`; label e icona CSS multi-check rendono chiara la selezione, la CTA resta rossa in hover/active/focus e non diventa nera al click. Usa il flusso carrello server-side esistente senza modificare `ProductCard.ascx`/`.vb`, JS, `cart_add.aspx`, `aggiungi.aspx`, query/ranking/search, DB/schema/SP, checkout/ordine, gateway/PayPal/email/auth, Settori/sidebar/filtri/applied filters o asset. Smoke Codex e Germano OK; build/precompile, diff check e secret scan OK. La quantita PDP, allora backlog, e ora assorbita da `STOREFRONT-CART-STATE-PERSISTENCE-1A`; restano side cart/offcanvas ONSUS, audit funzioni mancanti `articoli.aspx` vs ONSUS e audit immagini rotte/path DB.
- `CATALOG-BUY-CTA-ACQUISTA-1A/1B` chiuso su `frontend-rebuild` con HEAD `d5000b18e93e2857d591e3443273cec874b2fe09`: CTA add-to-cart delle card catalogo `articoli.aspx` resa piu commerciale senza modificare search/AI. Runtime: `ProductCard.ascx`, `ProductCard.ascx.vb`, `catalog-ui.css`. Rimossa la CTA/tooltip superiore `Carrello` / `Aggiungi al carrello` sopra Wishlist; aggiunta CTA `Acquista` con icona carrello vicino al box quantita; polish estetico con forma piu squadrata/professionale, `border-radius: 6px`, colore `var(--primary-2, #D80027)`, nessun arancio e-stayon. Desktop verificato con testo `Acquista` espandibile in hover/focus; mobile `390x844` verificato con testo sempre visibile e touch target circa 44px. Preservati `.js-ks-cart-link`, `href` `cart_add.aspx`, `.ks-qty`, `data-ks-existing-cart-qty`, `data-ks-*`, delta `2 -> 2`, `2 -> 3`, `2 -> 5`, selezione multipla, quantita gia nel carrello ed evidenziazione card. HOME non modificata in questo task, poi chiusa separatamente da `HOME-BUY-CTA-ACQUISTA-1A/1B/1C`; `articolo.aspx`, MiniCart, carrello, `cart_add`, `aggiungi`, checkout/ordine/auth, query/ranking/search, DB/schema/SP e asset non modificati. Smoke Codex/Germano, build/precompile, diff check e secret scan OK. Backlog separati residui: `PDP-BUY-CTA-ACQUISTA-1A`, `PRODUCT-IMAGE-BRIGHTNESS-PREVIEW-1A`, side cart/offcanvas, quantita su `articolo.aspx`, bug login anonimo/mobile se ricompare, menu Catalogo mobile e `HomeDepartmentsMenu`.
- `HOME-BUY-CTA-ACQUISTA-1A/1B/1C` chiuso su `frontend-rebuild` con HEAD `116000c64c2b09192e6aba5dc25916010dad9197`: le CTA carrello delle card prodotto HOME sono allineate allo standard commerciale `Acquista` gia approvato sul catalogo. Branch runtime chiuso `task/home-buy-cta-acquista-1a`; commit originari prima del rebase `d3ecb36ffab53bb9e063377f2d61597d787b7a94`, `40a83ec0da6e72eb29726ed91e2ec77a79b2652f`, `8adcc942429df53b26992b605bc8f651c6e5b374`; dopo rebase su `frontend-rebuild` aggiornato `a0d0163efcee60e859a469662679323e1f1697d6`, `6561ed3e47ba318b3dc9086dba13c451a9341e9b`, `116000c64c2b09192e6aba5dc25916010dad9197`. File runtime: `Default.aspx.vb` e `theme-overrides.css`. Coinvolti `RenderActionButtons`, `RenderGridCard`, `RenderDealCard`, `RenderRowCardFromRow`, `RenderBigCard` e `rptDealOfDay` / `Occasione Imperdibile`. CTA finale: icona standard `icon-cart-2`, testo `Acquista`, `aria-label/title` `Acquista: aggiungi al carrello`, colore `var(--primary-2, #D80027)`, radius circa `6px`, forma rettangolare/elegante non pill, desktop compatta con espansione hover/focus e mobile `390x844` sempre visibile/toccabile. `Occasione Imperdibile` e allineato agli altri blocchi HOME. Preservati `href` `cart_add.aspx`, `.js-ks-cart-link`, `data-ks-*`, id articolo, `TCid`, `qty`, querystring/flusso add-to-cart HOME; ProductCard/catalogo, `articolo.aspx`, carrello, `cart_add`, `aggiungi`, checkout, MiniCart, DB/schema/SP e immagini/path asset non modificati. Rebase pulito, merge fast-forward, HTTP 200 HOME/catalogo/carrello, add-to-cart HOME reale OK, catalogo `articoli.aspx?q=hp` invariato e add catalogo OK, build/precompile, diff check e secret scan OK. Smoke utente Germano OK su 1A, 1B e 1C. Dopo questa chiusura HOME non e piu backlog; restano separati `PDP-BUY-CTA-ACQUISTA-1A`, `PRODUCT-IMAGE-BRIGHTNESS-PREVIEW-1A`, side cart/offcanvas, quantita su `articolo.aspx`, bug login anonimo/mobile se ricompare, menu Catalogo mobile, `HomeDepartmentsMenu` e valutazione futura `llms.ashx`/`llms.txt`/JSON-LD dinamico.
- `HEADER-CATALOG-MEGAMENU-READABILITY-1A` chiuso su `frontend-rebuild` con HEAD `3d75d5349df857f1b594760590bbdc22c553f2d8`: migliorata la leggibilita desktop del mega menu `Catalogo` nell'header, senza modificare mobile, search/suggest, ranking o dati catalogo. Il fix ha toccato solo `Page.master` e `Public/assets/keepstore/css/theme-overrides.css`: selettori reali del menu desktop, primo pannello categorie visibile all'apertura e cache-buster CSS aggiornato. Stile finale: colore tema ONSUS/KeepStore `var(--primary-2, #D80027)`, nessun arancio e-stayon, titoli uppercase `"Inter", serif` circa `19px / 800`, sottocategorie scure circa `16px / 24px`, linea sottile sotto i titoli, colonne ordinate, URL `st/ct/tp` preservati e nessun overflow desktop rilevato. Smoke visuale Germano OK; build/precompile, diff check e secret scan OK. La CTA prodotto `Acquista` su HOME e stata poi chiusa da `HOME-BUY-CTA-ACQUISTA-1A/1B/1C`; restano backlog separati scheda prodotto/PDP, immagini prodotto piu brillanti, bug add-to-cart anonimo/mobile login message se ricompare, side cart/offcanvas ONSUS, quantita su `articolo.aspx`, menu Catalogo mobile e `HomeDepartmentsMenu`. Il bug visual mobile quantita carrello e stato chiuso da `CART-QTY-MOBILE-VISUAL-FIX-1A`.
- `CART-QTY-IN-CATALOG-1A` chiuso: `articoli.aspx` mostra nella card catalogo la quantita reale gia presente nel carrello per `ArticoliId + TCId`, usando snapshot read-only da tabella `carrello` e owner `LoginId`/`LOGINID` oppure `Session.SessionID`, senza query per card. Se `CartQty=0` la card resta normale e il box vale `1`; se `CartQty>0` il box mostra il totale reale in verde/grassetto e la card e evidenziata in modo professionale, senza testo/pill/badge esterni. Il delta e corretto nel layer catalogo: `2 -> 2` resta `2`, `2 -> 3` diventa `3`, `2 -> 5` diventa `5`, con gestione server-side WebForms/multiselect e JS link add-to-cart reale; cache-buster su `keepstore-product.js` evita handler vecchi in browser. La successiva estensione PDP e ora assorbita da `STOREFRONT-CART-STATE-PERSISTENCE-1A`. Query prodotti, SearchScore/ranking, suggest, DB/schema/SP, ProductCard, `cart_add.aspx`, `aggiungi.aspx`, carrello runtime, checkout/ordine, gateway/PayPal/email/auth, Settori/sidebar/filtri/applied filters e asset restano invariati.
- `CART-QTY-MOBILE-VISUAL-FIX-1A` chiuso su `frontend-rebuild` con HEAD `be4cfcb12e9f4aa5323f8a39c84f2ce40eca214e`: resa stabile anche su mobile la grafica `prodotto gia nel carrello` su `articoli.aspx`. La quantita era corretta, ma la card runtime `ProductCard` usava `article.card-product` fisso e l'evidenziazione dipendeva soprattutto da CSS `:has(.ks-cart-qty-input-present)`. Ora `ProductCard` supporta classi server-side stabili: `ks-card-in-cart` sulla card e `ks-cart-qty-present` sul wrapper quantita quando `CartQty > 0`; `:has()` resta fallback. Mobile reale verificato con viewport mobile, desktop e HOME verificati nello smoke utente Germano; nessun testo/pill/badge esterno `In carrello`/`Nel carrello`, accessibilita via `title`/`aria-label`, delta `2 -> 2`, `2 -> 3`, `2 -> 5` e selezione multipla PR #240 preservati. Non modificati carrello, `cart_add`, `aggiungi`, checkout/ordine/login/auth, MiniCart, JS, query/ranking/search, DB/schema/SP, Settori/sidebar/filtri/applied filters o asset; build/precompile, diff check e secret scan OK.
- `CART-CONTINUE-SHOPPING-1A` chiuso su `frontend-rebuild` con HEAD `09bdd4f749522e9a9dd7b0b884620f54dc9d5624`: `carrello.aspx` ora riporta `Continua lo Shopping` all'ultima pagina/contesto shopping reale invece della HOME generica. File runtime: `carrello.aspx.vb` e `aggiungi.aspx.vb`. Causa: `btContinua` usava `Session("Pagina_visitata_Articoli")`, dove `articoli.aspx` salvava un URL assoluto; `SafeRedirectLocal` accettava solo locali e scartava l'assoluto verso fallback `default.aspx`. Soluzione: `ResolveContinueShoppingUrl()` con priorita `Session("Carrello_Pagina")`, `Session("Pagina_visitata_Articoli")` normalizzabile, referrer locale idoneo e fallback sicuro; `aggiungi.aspx.vb` conserva `Session("Carrello_Pagina")` fino alla pagina carrello. Sicurezza: same-host assoluti convertiti in `PathAndQuery`, esterni e scheme/percorso rischiosi respinti, whitelist `Default.aspx`/`articoli.aspx`/`articolo.aspx`, esclusi carrello/checkout/ordine/pagamento/login/gateway/logout/reset/remind/token. Test: ritorno da `q=hp`, da `st/ct/tp`, da scheda articolo, da HOME e fallback diretto; desktop e mobile smoke Germano OK, Codex mobile su `st/ct/tp`, checkout anonimo/loginrequired preservato, nessun side cart/offcanvas implementato, build/precompile, diff check e secret scan OK.
- Regola operativa mobile/ecommerce: nessun task UI/catalogo/carrello/checkout/login/sessione/flusso ecommerce puo dichiarare `mobile OK`, `desktop/mobile verificati` o `responsive OK` senza verifica reale del percorso mobile interessato; se non verificato, deve dirlo. Le verifiche vanno separate per logica, desktop, mobile, anonimo, loggato quando pertinente, click/submit reale e comportamento ecommerce. Add-to-cart deve restare libero per anonimo; login required solo su checkout/ordine/conferma. Backlog aperti post smoke mobile: `BUG-ADD-TO-CART-ANON-MOBILE-LOGIN-MESSAGE` e side cart/offcanvas ONSUS; quantita PDP e visual mobile quantita sono stati chiusi dai rispettivi task cart-state/visual.
- Dettaglio backlog post smoke mobile: `BUG-ADD-TO-CART-ANON-MOBILE-LOGIN-MESSAGE` salva il prodotto in carrello ma mostra `Accedi per inviare l'ordine` su `carrello.aspx` dopo semplice add-to-cart anonimo mobile, da verificare anche desktop; `BUG-CART-QTY-MOBILE-VISUAL` e stato chiuso da `CART-QTY-MOBILE-VISUAL-FIX-1A` con classi server-side stabili e verifica mobile reale. Side cart/offcanvas ONSUS resta separato: anteprima dopo add-to-cart e continuazione shopping, senza mischiarlo con loginrequired o visual mobile.
- Test registrati: `hp` non peggiorato (`18933,20018`), `stampante hp` migliorato verso suggest (`20810,17698`), `12384` invariato con nessun ID catalogo e suggest `total=0`; smoke suggest/articoli/carrello OK.
- Limiti residui: LIKE su molte colonne lunghe puo diventare costoso; zero results ora e assistito ma resta locale/non-AI; eventuale AI/LLM resta fase successiva con privacy task.
- `PDP-BUY-CTA-ACQUISTA-AUDIT-1` e `PDP-BUY-CTA-ACQUISTA-1A/1B` sono chiusi con HEAD `3b0b2ac97564c497abd26d224e5e945834a2ec26`, commit `b56277c7777345c70021e21270628b72a51a2f4c` + `3b0b2ac97564c497abd26d224e5e945834a2ec26`, merge fast-forward e smoke Germano finale A desktop/mobile. Main PDP `Acquista`, bundle `Acquista selezionati` e carousel Simili/Correlati/Recenti condividono semantica e `icon-cart-2`; handler, sessioni, TCId, qty, `.js-ks-cart-link`, `AddToCartUrl` e shell ONSUS restano preservati. La chiusura vale solo per le CTA e non dichiara `articolo.aspx` completa. Eventuali riferimenti precedenti a PDP CTA come backlog nei riepiloghi storici HOME/catalogo/header sono superati da questa chiusura.
- Stato typography trasversale: `GLOBAL-TYPOGRAPHY-ONSUS-AUDIT-1`, `GLOBAL-TYPOGRAPHY-ONSUS-1A` e `GLOBAL-TYPOGRAPHY-ONSUS-1B` sono CHIUSI / A. L'audit ha confermato l'assenza di Inter nel repository e il possibile fallback Times di `"Inter", serif`; la foundation deterministica `Arial, sans-serif` e stata fissata al commit `d0f5f500f75da70aaf0c4a961762cf35f3db51ac`. `1B`, commit `efae083a3d2dece257290d3c3b5d6bde39d6af32` e polish `df98e70ced14a6f635d7819fadebe22d09f103ee`, normalizza nel layer KeepStore finale le famiglie testuali residue di HOME, catalogo, PDP, header/MegaMenu, footer e carrello senza riscrivere `styles.css` ne modificare scale/layout ONSUS. Times New Roman e Poppins accidentali risultano assenti sulle superfici testate e Icomoon e preservato; smoke Germano A desktop/mobile.
- Polish HOME typography incluso in `1B`: `body.ks-page-home .ks-home-main .name-product` usa `line-height: 20px` e `min-height: 40px`, preservando font-size `14px` desktop / `12px` mobile, weight, uppercase, colore, clamp a due righe e overflow. Verificate 8 card `In Evidenza` e 8 `Best Seller` a `1365x900` e `390x844`, senza clipping o terza linea parziale e senza regressioni prezzi/CTA/allineamento; `Occasione Imperdibile` non aveva product card reale nella fixture.
- `GLOBAL-TYPOGRAPHY-ONSUS-1C` e NON NECESSARIO / NON CREATO e il blocco typography storefront e CHIUSO. Questa chiusura non dichiara complete HOME, catalogo, PDP, header o footer. Audit catalog parity e runtime `1A/1B/1C`, availability, hotfix card-layout, async cart, login return e login access sono chiusi; `articoli.aspx` resta esplicitamente non completa. Il riferimento storico alla roadmap che partiva dall'hotfix `Demo` e superato: valgono le chiusure promo e la roadmap corrente in apertura. Side cart resta separato e Gemini/LLMS resta Priorita 8/finale. Nessuna query, logica search/AI, ranking o runtime AI e stata modificata da questi blocchi o dalla sola riconciliazione docs.
- Riconciliazione storica PDP: il finding `PDP-TITLE-SHIPPING-INFO-1A` descriveva il precedente clamp di `.product-info-name`; nella stable corrente il titolo PDP resta completo. Non e piu il prossimo runtime e non dichiara full PDP parity.
- `STOREFRONT-AVAILABILITY-PRESENTATION-1A` deve usare dati reali KeepStore tramite `AvailabilityDisplayHelper` e `Session("DispoTipo")`, senza inventare disponibilita o consegna, senza query per card e senza cambiare la priorita finale AI/Gemini/LLMS.
- Stato cart-state trasversale: `STOREFRONT-CART-STATE-PERSISTENCE-REGRESSION-AUDIT-1` e CHIUSO / B diagnostico-procedibile e `STOREFRONT-CART-STATE-PERSISTENCE-1A` e CHIUSO / A al commit `68325c1879e2859628b59f297fe2a329b5aadb35`. `CartStateSnapshotProvider` usa cache request-scoped, owner centralizzato e query parametrizzata aggregata; master pubblica `window.KeepStoreCartState.items`, catalogo delega il reader condiviso, HOME/PDP mostrano `Nel carrello: X` e PDP usa totale desiderato con delta `2 -> 2`, `2 -> 3`, `2 -> 5`. `keepstore-cart-state.js` e solo renderer e non usa piu localStorage come source of truth. `ARTICOLO-CART-QTY-IN-PDP-AUDIT-1/1A` sono ASSORBITI / SODDISFATTI; nessuna pagina e dichiarata completa. TCId positivo e login non sono certificati live da Codex per assenza fixture/credenziali.
- Backlog sicurezza separato `CART-ADD-QTY-SERVER-MAX-HARDENING-AUDIT-1`: verificare il massimo server-side di `cart_add.aspx` rispetto al limite `9999`, senza fix o classificazione critica prima dell'audit.
- Backlog hardening separato `CART-SESSIONID-LOG-REDACTION-1A`: auditare i log legacy di `aggiungi.aspx.vb` che possono includere SessionId completo; nessun fix e nessuna classificazione critica sono inclusi nel cart-state.
- Incidente deployment cart-state: `BC30002` e comparso perche il runtime aveva codice dipendente aggiornato ma non il nuovo file tracked `App_Code/CartStateSnapshotProvider.vb`. Germano ha ripristinato il file, senza modifica sorgente, e lo smoke finale e A. Guardrail: verificare nel deploy i file Git `added` oltre ai `modified`, con controllo speciale per `App_Code/*.vb`; se l'ambiente Codex non puo leggere IIS, dichiarare la sanity runtime non verificabile senza inventare esiti.

## 3. Architettura a strati

### 3.1 UI widget

Futura UI possibile:

- chatbox/assistente acquisto non invasivo;
- entry point da header search, home, catalogo, zero results e scheda articolo;
- stile ONSUS/KeepStore, mobile-first e accessibile;
- CTA orientativa, per esempio "Ti aiuto a trovare il prodotto giusto";
- nessuna promessa di disponibilita, prezzo o compatibilita non presente nei dati.

### 3.2 Understanding locale

Prima di qualunque LLM, il sistema deve fare comprensione locale:

- normalizzazione testo;
- tokenizzazione;
- riconoscimento codice articolo ed EAN;
- riconoscimento marca;
- riconoscimento settore/categoria/tipologia;
- riconoscimento parole frequenti del catalogo;
- sinonimi solo se derivabili dai dati o configurabili;
- limite lunghezza input.

### 3.3 Retrieval deterministico

La base deve restare deterministica:

- cercare prima sui dati reali del catalogo;
- codice/EAN esatto sempre prioritario;
- match a inizio parola sopra contenuto generico;
- marca + descrizione sopra descrizione generica;
- scheda tecnica/campi tecnici da includere solo dopo audit;
- disponibilita e promo come boost controllati, non come sostituti della pertinenza;
- risultati sempre collegati a prodotti reali;
- spiegazione breve del perche un prodotto viene proposto.

### 3.4 Domande guidate

Se la richiesta e generica, l'assistente deve fare una domanda invece di inventare:

- se emergono piu intenti, proporre una scelta;
- se manca un dato critico, chiedere dettaglio;
- se la merceologia ha attributi ricorrenti, trasformarli in domande;
- se i dati non contengono l'attributo, non fingere di averlo.

Esempi:

- "Che modello di stampante Brother hai?";
- "Ti serve per interno o esterno?";
- "Preferisci senza zucchero?";
- "Hai un budget massimo?";
- "Vuoi prodotti disponibili subito?".

### 3.5 Risultati

Le risposte devono mostrare card prodotto reali:

- immagine;
- nome;
- prezzo;
- disponibilita;
- promo se presente;
- motivazione breve;
- filtri suggeriti;
- CTA "vedi prodotto" e "confronta".

`Aggiungi al carrello` dall'assistente e ammesso solo in una fase futura, dopo task dedicato su sicurezza, quantita, TC, promo e carrello.

### 3.6 Zero results evoluto

Quando non ci sono risultati:

- proporre categorie vicine;
- proporre query alternative locali;
- mostrare prodotti popolari o visti di recente;
- chiedere chiarimento;
- evitare messaggi tecnici;
- non mostrare prodotti inventati.

### 3.7 AI/LLM futura

AI/LLM resta opzionale e successiva:

- solo dopo ranking deterministico stabile;
- solo con task dedicato;
- nessuna API esterna senza autorizzazione;
- invio fuori sistema solo di dati minimi e autorizzati;
- nessun dato personale, account o carrello senza task privacy esplicito;
- risposte vincolate ai prodotti reali;
- niente consigli inventati;
- niente promesse su prezzo/disponibilita se non presenti nei dati.

## 4. Fonti dati future

Fonti da considerare in audit successivi:

- codice articolo;
- EAN;
- marca;
- descrizione breve;
- descrizione lunga;
- descrizione HTML;
- scheda tecnica/campi tecnici se gia presenti;
- settore/categoria/tipologia/gruppo/sottogruppo;
- disponibilita;
- promo;
- listino/prezzo;
- immagini;
- taglia/colore/varianti TC;
- ricondizionato;
- spedizione gratuita;
- vetrina;
- visite/statistiche gia usate.

La posizione dei campi "scheda tecnica" non e ancora chiusa in questa blueprint. Prima di usarli serve `AI-ASSISTANT-DATA-PROFILE-AUDIT-1A`, senza inventare tabelle o query.

## 5. WOW features future

Roadmap funzionale, non promessa runtime:

- "Parla con il negozio": chatbox che capisce l'esigenza.
- "Guidami nella scelta": domande progressive.
- "Trova compatibile": toner, cavi, accessori, ricambi.
- "Confronta per me": usa compare esistente.
- "Miglior scelta per budget": prezzo, disponibilita e promo.
- "Mi serve per...": ricerca per uso/esigenza.
- "Non so il nome": navigazione conversazionale.
- "Hai gia visto questi": recenti/cronologia client-side.
- "Ti manca anche...": cross-sell futuro.
- "Scelta rapida": chip suggeriti dinamici.
- "Modalita esperto": codice, EAN e scheda tecnica.
- "Modalita semplice": domande guidate.

## 6. Governance multi-cliente

Regole:

- nessun testo fisso Taikun-only;
- nessuna merceologia hardcoded nel runtime;
- vocabolario derivato dagli articoli dell'azienda/sito corrente;
- eventuali configurazioni per azienda solo con task separato;
- nessun nuovo schema DB in questa fase;
- configurazione AI aziendale solo con task DB esplicito;
- log/telemetria solo se approvati e senza dati sensibili.

## 7. Sicurezza e privacy

Vincoli:

- non inviare dati personali a modelli esterni senza autorizzazione;
- non inviare carrello/account senza task privacy esplicito;
- non esporre query SQL o errori tecnici;
- non restituire `ex.Message` agli utenti;
- output HTML/JSON sempre encoded;
- input con limite lunghezza e normalizzazione;
- valutare rate limit o throttling;
- considerare prompt injection se si usera LLM;
- ogni risposta deve riferirsi a prodotti reali;
- nessun dato prodotto/cliente fuori sistema senza task dedicato.

## 8. Roadmap micro-task token-safe

1. `SEARCH-SUGGEST-CATALOGURL-PARAM-1A`
   - chiuso con PR #222;
   - `available -> disponibile` e `sort -> ordinamento`;
   - ranking/query SQL invariati.

2. `SEARCH-SUGGEST-ERROR-HARDENING-1A`
   - chiuso con PR #223;
   - `ex.Message` rimosso dal JSON pubblico;
   - messaggio generico compatibile con `ok=false` + `error`.

3. `SEARCH-RANKING-ALIGN-1A`
   - chiuso con PR #224;
   - `SearchScore` catalogo avvicinato al suggest;
   - codice/EAN, query numeriche, `Export +500` e filtro principale preservati.

4. `SEARCH-ZERO-RESULTS-ASSIST-1A`
   - chiuso con PR #226;
   - empty state catalogo piu utile;
   - query HTML encoded, CTA generiche e chip da token query;
   - nessun fallback hardcoded merceologico, nessuna AI attiva e nessuna query DB extra.

5. `CATALOG-APPLIED-FILTERS-ONSUS-AUDIT-1A`
   - chiuso prima della PR #232;
   - confermato mapping con ONSUS `shop-default.html` per chip/filtri applicati e remove all;
   - mantenuta logica KeepStore: `Settori/st` livello alto/header, `ct` querystring supportata ma non facet laterale in questa fase.

6. `CATALOG-APPLIED-FILTERS-ONSUS-1A`
   - chiuso con PR #232;
   - chip filtri applicati, remove singolo via GET e `Rimuovi tutto` visibile/chiaro sono integrati;
   - ranking/SearchScore, suggest, DB, query prodotti, zero-results e sidebar filtri preservati.

7. `CATALOG-SIDEBAR-CATEGORIES-ONSUS-AUDIT-1A`
   - chiuso prima della PR #234;
   - confermata separazione tra navigazione catalogo e facet laterali;
   - evitare copia massiva ONSUS e usare dati reali KeepStore.

8. `CATALOG-SIDEBAR-CATEGORIES-ONSUS-1A`
   - chiuso con PR #234;
   - sezione visibile `Settori` sopra i facet, dati reali `CatalogMenuSector`, gerarchia `Settori > Categorie`;
   - URL `st`/`st+ct` puliti, nessun parametro sporco, no hardcoding merceologico;
   - query prodotti, SearchScore/ranking, suggest, zero-results e filtri applicati preservati.

9. `CATALOG-PRODUCT-CARD-RUNTIME-CSS-POLISH-1A`
   - chiuso con PR #236;
   - card runtime reale `article.card-product` rifinita con CSS scoped sotto `#ksCatalogPage`;
   - tipografia ONSUS reale, immagini stabilizzate e regola DB-first per placeholder immagini;
   - query prodotti, SearchScore/ranking, suggest, zero-results, filtri applicati e navigazione Settori preservati.

10. `CATALOG-CARD-QUANTITY-CHECKBOX-CSS-GUARD-1A`
   - chiuso con PR #238;
   - polish CSS-only di quantita e checkbox selezione multipla nella card runtime `article.card-product`;
   - nessun cambio a WebForms, add-to-cart, `cart_add.aspx`, `data-ks-*`, JS o query/ranking;
   - bottone globale "aggiungi selezionati" demandato al task successivo e poi chiuso con PR #240.

11. `CATALOG-MULTISELECT-ADD-BUTTON-1A`
   - chiuso con PR #240;
   - CTA globale `Aggiungi selezionati al carrello` per acquisto multiplo da catalogo;
   - label `Seleziona`, icona CSS multi-check e footer `Acquisto multiplo` chiariscono il flusso;
   - usa il carrello server-side esistente senza modificare ProductCard, JS, `cart_add.aspx`, `aggiungi.aspx`, query/ranking/search o DB;
   - la quantita PDP, allora backlog, e ora assorbita dal cart-state globale; restano side cart/offcanvas, funzioni ONSUS mancanti e immagini rotte/path DB.

12. `CATALOG-BUY-CTA-ACQUISTA-1A/1B`
   - chiuso su `frontend-rebuild` con HEAD `d5000b18e93e2857d591e3443273cec874b2fe09`;
   - CTA `Acquista` con icona carrello vicino al box quantita delle card catalogo `articoli.aspx` / `ProductCard`;
   - rimossi `Carrello` / `Aggiungi al carrello` dall'area quick actions sopra Wishlist;
   - forma finale piu squadrata/professionale con `border-radius: 6px`, colore tema `var(--primary-2, #D80027)`, desktop hover/focus e mobile `390x844` sempre leggibile;
   - preservati `.js-ks-cart-link`, `href`, `.ks-qty`, `data-ks-*`, delta quantita, selezione multipla e quantita gia nel carrello;
   - HOME, `articolo.aspx`, side cart/offcanvas e immagini piu brillanti restano backlog separati.

13. `CART-QTY-IN-CATALOG-1A`
   - chiuso su `frontend-rebuild` con HEAD `14e3aa43d64dfad97710f4fd15903490914e79fb`;
   - `articoli.aspx` mostra la quantita reale gia presente nel carrello nel box quantita della card e usa delta corretto per add singolo/multiselect;
   - dati letti da `carrello` con snapshot read-only, owner login/sessione e chiave `ArticoliId + TCId`;
   - nessun cambio a query/ranking/search, ProductCard, `cart_add.aspx`, `aggiungi.aspx`, carrello runtime o DB;
   - l'estensione equivalente su `articolo.aspx` e stata successivamente assorbita da `STOREFRONT-CART-STATE-PERSISTENCE-1A`;
   - smoke mobile reale ha aperto backlog separato `BUG-ADD-TO-CART-ANON-MOBILE-LOGIN-MESSAGE`; `BUG-CART-QTY-MOBILE-VISUAL` e stato poi chiuso con verifica mobile reale da `CART-QTY-MOBILE-VISUAL-FIX-1A`.

14. `CART-CONTINUE-SHOPPING-1A`
   - chiuso su `frontend-rebuild` con HEAD `09bdd4f749522e9a9dd7b0b884620f54dc9d5624`;
   - `carrello.aspx` torna all'ultima pagina/contesto shopping reale invece della HOME generica;
   - priorita URL: `Session("Carrello_Pagina")`, `Session("Pagina_visitata_Articoli")`, referrer locale idoneo, fallback sicuro;
   - URL assoluti same-host normalizzati a `PathAndQuery`, URL esterni e pagine non shopping respinti;
   - preservati checkout anonimo/loginrequired e separato il backlog side cart/offcanvas.

15. `STOREFRONT-CART-STATE-PERSISTENCE-REGRESSION-AUDIT-1` / `STOREFRONT-CART-STATE-PERSISTENCE-1A`
   - audit chiuso B diagnostico/procedibile e runtime chiuso A al commit `68325c1879e2859628b59f297fe2a329b5aadb35`;
   - stato server-side unico per HOME, catalogo e PDP tramite `CartStateSnapshotProvider`, senza N+1 e senza localStorage source-of-truth;
   - PDP totale desiderato/delta e vecchi task `ARTICOLO-CART-QTY-IN-PDP-*` assorbiti;
   - nessuna abilitazione dei dati carrello per AI/search: uso AI resta futuro e soggetto a privacy/consenso.

16. `AI-ASSISTANT-DATA-PROFILE-AUDIT-1A`
   - audit campi e vocabolario per merceologie;
   - capire dove sta la scheda tecnica;
   - nessuna modifica DB.

6. `AI-ASSISTANT-UI-ONSUS-AUDIT-1A`
   - verificare pattern ONSUS per chat/offcanvas/search;
   - decidere widget UI;
   - nessuna implementazione.

7. `AI-ASSISTANT-LOCAL-PROTOTYPE-1A`
   - primo prototipo non-LLM;
   - domande guidate e retrieval deterministico;
   - nessuna API esterna.

8. `AI-ASSISTANT-RAG-DECISION-1A`
   - solo dopo prototipo locale;
   - decisione AI esterna o motore locale;
   - privacy, costi, logging e governance.

9. `AI-ASSISTANT-MULTI-AZIENDA-CONFIG-1A`
   - eventuale configurazione per azienda;
   - solo se serve;
   - DB task separato.

10. `AI-ASSISTANT-COMMERCIAL-MODULES-1A`
    - cross-sell, upsell, bundle e compare intelligente.

## 9. Criteri di non-regressione

Ogni task futuro deve dichiarare esplicitamente:

- se e solo documentale, audit, UI o runtime;
- branch e HEAD attesi;
- file ammessi;
- nessun PayPal/gateway/email/auth salvo task dedicato;
- nessun carrello/checkout/ordine salvo task dedicato;
- nessun DB/schema/SP salvo task DB esplicito;
- nessuna API esterna salvo task AI/privacy approvato;
- nessun asset non tracciato incluso.

Questa blueprint non implementa AI, chatbot, endpoint, DB, UI runtime o correzioni search. Registra solo architettura e roadmap.
