# KeepStore Masterplan Operativo

Aggiornato: 2026-08-29

Questo documento e il punto di ripartenza operativo per nuove chat ChatGPT/Codex sul repository `KeepStoreAdmin/KeepStore3.0`.
Non contiene credenziali, token, password, API signature, dati carta o account PayPal reali.

## Contratto operativo Germano / ChatGPT / Codex

### Germano

- Decide priorita e perimetro.
- Autorizza merge, smoke, pagamenti sandbox/live, modifiche DB e modifiche gateway.
- Approva scelte funzionali e grafiche.
- Puo fermare o riorientare i micro-task in qualsiasi momento.

### ChatGPT

- Analizza contesto e report.
- Pianifica micro-task.
- Scrive istruzioni operative per Codex.
- Definisce guardrail.
- Verifica i report Codex.
- Prima dei prompt importanti legge i tre manuali e confronta direttamente branch, commit e diff pubblicati su GitHub con lo stato runtime documentato.
- Classifica gli esiti come A/B/E.
- Decide il prossimo micro-task da proporre.
- Mantiene aggiornato il masterplan.
- Non deve saltare passaggi o cambiare metodo.

### Codex

- Esegue operativamente nel repository.
- Crea branch dedicati.
- Modifica file entro il perimetro autorizzato.
- Esegue build, precompilazioni, `git diff --check` e smoke test richiesti.
- Apre PR verso la base indicata.
- Per ogni branch runtime esegue il push su origin prima del report finale e della review ChatGPT, salvo impedimento tecnico esplicitamente documentato.
- Non deve cambiare perimetro senza fermarsi.
- Non deve toccare `main`.
- Non deve creare pagamenti, ordini o chiamate gateway senza autorizzazione.
- Riporta esiti in modo preciso.

### Metodo

- Ogni lavoro passa da micro-task.
- Ogni PR passa da verifica B.
- Ogni merge passa da smoke D.
- Ogni cleanup avviene solo dopo smoke A/B.
- Per refactor UI si usa prima audit ONSUS, poi implementazione coerente.
- Niente patch sul vecchio layout quando si cambia grafica/impostazione.
- Usare sempre campi DB esistenti e query/logiche esistenti quando possibile.
- Modifiche strutturali o logiche vecchie richiedono prima analisi impatto e proposta micro-task.

### Metodo Codex Token-Safe / One-Shot

- Prima di dare prompt a Codex, ChatGPT deve consolidare piano, scope, file ammessi, vincoli, verifiche, output e criterio A/B/E.
- Evitare prompt esplorativi quando causa e fix sono gia chiari: un task deve avere un solo prompt operativo principale.
- Revisioni successive sono ammesse per blocchi reali, non per perfezionismo documentale o per inseguire il commit documentale appena creato.
- La documentazione deve registrare PR, branch, commit funzionale principale, stato, smoke e decisioni; i commit documentali successivi restano tracciati da Git/PR e non generano automaticamente nuove REV.
- Cleanup branch e housekeeping sono secondari: usarli solo su richiesta esplicita o se sbloccano il flusso. Prima di cancellare branch verificare sempre che non esistano commit assenti da `frontend-rebuild`.
- Se un problema e solo sospetto o non riproducibile, prima fare test manuale mirato; aprire PR diagnostiche solo se il problema torna riproducibile.
- ChatGPT decide piano, ordine e priorita; Codex esegue task piccoli, verificabili e con confini rigidi. Evitare task generici tipo "controlla tutto".
- Dopo il commit runtime Codex deve pubblicare il task branch su origin prima della review finale; ChatGPT usa il diff GitHub per verificare scope e dichiarazioni, mentre merge e approvazione restano bloccati fino al via libera ChatGPT/Germano.
- Priorita: bug bloccanti/regressioni utente, smoke, documentazione minima, poi cleanup. Non consumare token su attivita non funzionali mentre ci sono step piu importanti aperti.

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

Stato Git stabile dopo `CATALOG-ONSUS-PARITY-1B-TOOLBAR-CONTROLS`:

- `frontend-rebuild` e `origin/frontend-rebuild`: `9903687f89f99073d29cc0598746e17511f7e546`.
- `main` e `origin/main`: `976e99f17cabc8a5c6a8715463444edfeaadcd91`.
- Working tree atteso: pulito salvo eventuali directory non tracciate `Public/assets/images/articoli/` e `Public/assets/images/settori/`, che non vanno committate.

Regola permanente "task specifico chiuso" vs "area/pagina completa":

- Un micro-task chiuso certifica solo il perimetro dichiarato nel task, non l'intera pagina o area funzionale.
- Non scrivere "pagina completa", "catalogo completo", "articoli.aspx completata" o formule equivalenti se manca un task dedicato di parity/audit completo con ONSUS, smoke reale desktop/mobile e documentazione.
- Quando una pagina ha molti task chiusi, descrivere sempre "micro-task X/Y/Z chiusi su quella pagina" e tenere separato lo stato della pagina intera.
- Esempio vincolante `articoli.aspx`: sono chiusi multiselect catalogo / `Aggiungi selezionati al carrello`, quantita gia nel carrello su card catalogo, delta quantita catalogo, visual mobile della quantita gia in carrello e CTA `Acquista` catalogo con icona standard. Esistono inoltre micro-task documentati su search/suggest, zero-results, sidebar/facet e applied filters, ma non vanno letti come chiusura completa di quelle funzioni dentro la pagina catalogo.
- Nota anti-false-closure: `articoli.aspx` non e una pagina dichiarata completa. I micro-task chiusi non equivalgono alla parita ONSUS completa. `CATALOG-ONSUS-PARITY-AUDIT-1` e terminato, ma i gap individuati devono essere completati per micro-task: immagini prodotto 404, sidebar/facet residui, Marche load-more, tassonomie troncate, active-filter legacy, Price/Deals/Condition, performance, componenti commerciali e responsive complessivo.
- `articoli.aspx` resta area aperta per ONSUS parity completa: `1A` ha stabilizzato stato/paging e `1B` ha riallineato toolbar/view controls, senza chiudere gli altri gap dell'audit.

Stato sintetico dei blocchi chiusi:

- Catalogo `articoli.aspx`: oltre ai micro-task multiselect, quantita/delta/visual mobile in carrello e CTA `Acquista`, sono chiusi `CATALOG-ONSUS-PARITY-1A` per stato/paging deterministico e `CATALOG-ONSUS-PARITY-1B-TOOLBAR-CONTROLS` per toolbar e quattro viste. L'audit parity e completato; immagini 404 e gap P1/P2 restano aperti. Zero-results, sidebar/facet, Settori/applied filters, performance e search/suggest mantengono il proprio perimetro documentato. Non dichiarare il catalogo completo.
- PDP `articolo.aspx`: chiusi `PDP-BUY-CTA-ACQUISTA-AUDIT-1`, runtime `PDP-BUY-CTA-ACQUISTA-1A/1B` e il micro-perimetro quantita/stato carrello assorbito da `STOREFRONT-CART-STATE-PERSISTENCE-1A`; la pagina non e dichiarata completa. Il blocco typography globale e chiuso, mentre side cart e altre evoluzioni restano task separati.
- Riconciliazione storica PDP: eventuali righe precedenti che elencano `PDP-BUY-CTA-ACQUISTA-1A` come backlog descrivono lo stato al momento della relativa chiusura catalogo/HOME/header e sono superate dalla chiusura PDP a HEAD `3b0b2ac97564c497abd26d224e5e945834a2ec26`.
- HOME: chiusa CTA `Acquista` HOME, allineamento `icon-cart-2` con catalogo, blocco `Occasione Imperdibile` e standard CTA commerciale unico.
- Carrello: chiuso `Continua lo Shopping` verso ultima pagina/contesto reale con URL locali normalizzati e protezione checkout/loginrequired preservata.
- Header/menu: chiusa leggibilita desktop del mega menu `Catalogo`; menu Catalogo mobile resta aperto.
- Stack/sicurezza: chiuso e documentato il contratto permanente WebForms/VB.NET/.NET Framework/MySQL, con divieti C#/ASP.NET Core e checklist sicurezza.
- Typography storefront: blocco CHIUSO / A. `GLOBAL-TYPOGRAPHY-ONSUS-AUDIT-1`, `GLOBAL-TYPOGRAPHY-ONSUS-1A` e `GLOBAL-TYPOGRAPHY-ONSUS-1B` sono chiusi con esito A; foundation deterministica `Arial, sans-serif`, famiglie testuali residue normalizzate nel layer KeepStore finale, Icomoon preservato e scale ONSUS invariate. `GLOBAL-TYPOGRAPHY-ONSUS-1C` e NON NECESSARIO / NON CREATO dopo smoke Germano A e assenza di Times/Poppins accidentali sulle superfici testate. La chiusura vale soltanto per la typography e non rende complete HOME, catalogo, PDP, header o footer.
- Cart-state storefront: `STOREFRONT-CART-STATE-PERSISTENCE-REGRESSION-AUDIT-1` chiuso come audit diagnostico B/procedibile e `STOREFRONT-CART-STATE-PERSISTENCE-1A` chiuso con esito A al commit `68325c1879e2859628b59f297fe2a329b5aadb35`; HOME, catalogo e PDP condividono ora uno snapshot server-side request-scoped. Questa chiusura non rende complete le tre pagine.

Problemi affrontati e risolti:

- `Continua lo Shopping` tornava alla HOME perche `articoli.aspx` salvava un URL assoluto in sessione e `SafeRedirectLocal` lo scartava: ora gli URL same-host sono normalizzati a `PathAndQuery`, gli esterni sono rifiutati e si torna al contesto shopping valido.
- La quantita gia in carrello sul catalogo rischiava somme errate: il delta e stato corretto, quindi `2 -> 2` resta `2`, `2 -> 3` diventa `3`, `2 -> 5` diventa `5`.
- Il visual mobile della quantita gia in carrello non era robusto quando dipendeva soprattutto da CSS `:has()`: ora `ProductCard` espone classi server-side stabili `ks-card-in-cart` e `ks-cart-qty-present`.
- La CTA catalogo `Acquista` era inizialmente troppo pill/bombata: e stata resa piu squadrata/professionale con radius circa `6px`, colore tema e icona coerente.
- La CTA HOME usava una linea/icona diversa: e stata allineata allo standard catalogo con `icon-cart-2`.
- Il blocco HOME `Occasione Imperdibile` aveva override/stile CTA diverso dagli altri blocchi: e stato allineato allo stesso standard.
- L'errore intermittente WebForms `BC30560 public_ui_controls_breadcrumb_ascx ambiguo nello spazio dei nomi ASP` e stato osservato una volta e non riprodotto: audit read-only senza duplicati reali `Breadcrumb`; causa piu probabile cache/compilazione dinamica ASP.NET temporanea, nessun fix applicato.

Chiusura progressiva catalog parity audit / `1A` / `1B`:

- `CATALOG-ONSUS-PARITY-AUDIT-1`: COMPLETATO / READ-ONLY, esito operativo E. La E non indica audit fallito: l'audit e completo e utile, non ha modificato file e ha individuato P0 reali che hanno interrotto la parity puramente visuale. P0 originari: contaminazione dello stato catalogo da Session (`st`, `ct`, `q`), paging non deterministico/pagina 2 instabile e immagini prodotto 404. I primi due sono chiusi da `1A`; le immagini restano APERTE / P0.
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
- P0 immagini: APERTO. Prossimo runtime ufficiale `CATALOG-ONSUS-PARITY-1C-IMAGE-PATH-404`, per distinguere path DB, file fisico, mapping `/Public/assets/images/articoli/`, deploy asset, `ThemeManager.ProductImageUrl` e uso appropriato del placeholder, senza anticipare la soluzione. Le directory non tracciate `Public/assets/images/articoli/` e `Public/assets/images/settori/` non vanno committate automaticamente e da sole non provano la root cause.
- Gap P1/P2 aperti: Marche oltre 7/load-more, Settori/Categorie limitati o troncati, active filters server + JS legacy, reset mobile contesto `st/ct`, Price facet, Deals, Condition/Ricondizionato, Reviews solo con fonte reale, performance/N+1 promo, positioning Recently Viewed, Compare empty-state e ulteriori componenti commerciali/parity ONSUS.

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
2. Priorita 2 - Catalogo `articoli.aspx` full ONSUS parity.
   - `CATALOG-ONSUS-PARITY-AUDIT-1`: COMPLETATO / READ-ONLY, esito operativo E per P0 reali individuati.
   - `CATALOG-ONSUS-PARITY-1A`: CHIUSO / A; stato request e paging deterministici.
   - `CATALOG-ONSUS-PARITY-1B-TOOLBAR-CONTROLS`: CHIUSO / A; toolbar ONSUS-like e quattro viste.
   - `CATALOG-ONSUS-PARITY-1C-IMAGE-PATH-404`: PROSSIMO TASK RUNTIME UFFICIALE; audit/fix root cause immagini prodotto 404.
   - Dopo il P0 immagini, proseguire con i gap P1 secondo audit e priorita effettiva, senza dichiarare completa `articoli.aspx`.
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
- Limiti test dichiarati: `TCId > 0` non certificato runtime da Codex per assenza fixture reale; login runtime non certificato per assenza credenziali. Alias e migrazione login sono stati verificati staticamente e nessuna auth e stata modificata.
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

- KeepStore usa un database condiviso multi-azienda: `AziendeId=1` identifica Taikun, `AziendeId=2` identifica Webaffare.
- I domini possono puntare allo stesso DB ma usare spazi webroot e `web.config` separati; prima di validare bug sensibili a pagamenti, logo, listini, promo, gateway o dati azienda bisogna annotare dominio/host, `AziendaID` risolta e contesto runtime.
- `localhost` non rappresenta automaticamente Taikun: nel runtime verificato mappa Webaffare/Azienda 2 tramite `Aziende.URL2=localhost`. Per test Taikun usare host/domain mapping corretto, ad esempio host locale coerente o `--resolve`, e dichiararlo nel report.
- Non confondere "metodo pagamento visibile" con "gateway configurato": `pagamentitipo`/`vpagamentitipo` determinano visibilita del metodo, mentre il gateway PayPal Express richiede configurazione aziendale dedicata in `vpaypal_express_azienda` o fallback espliciti `PAYPAL_EXPRESS_*`.
- Non copiare configurazioni gateway tra aziende senza decisione esplicita del titolare. PayPal Taikun e PayPal Webaffare restano task separati.

### Ripartenza rapida in nuova chat

- In caso di chat satura o bloccata, aprire una nuova chat e scrivere: "Leggi docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md e riparti dall'ultimo HEAD stabile."
- Il file contiene HEAD stabile, ultimo blocco completato, task corrente, PR aperte/chiuse, vincoli di scope e prossimi step.
- Non consumare token ripetendo tutta la storia: leggere questo masterplan, verificare Git e ripartire dal micro-task successivo.
- Mantenere lo stesso metodo Germano/ChatGPT/Codex: micro-task, branch dedicati, PR verso `frontend-rebuild`, merge controllati e cleanup separati.
- Aggiornare questa sezione dopo ogni blocco importante.

## 1. Metodo ChatGPT + Codex

### Ruoli

- ChatGPT mantiene la direzione funzionale, la sequenza dei task e i criteri di accettazione; legge i manuali e, dopo il push, controlla direttamente branch/commit/diff GitHub prima di assegnare A/B/E.
- Codex lavora su branch dedicati, legge il codice prima di modificare, applica patch piccole, crea commit e pubblica il task branch su origin prima del report finale/review ChatGPT; il merge resta vietato fino all'approvazione ChatGPT/Germano.
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
  - PR verso `frontend-rebuild`.
- Ogni verifica PR e in sola lettura:
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
- Dopo merge:
  - aggiornare locale `frontend-rebuild` da origin;
  - confermare `HEAD == origin/frontend-rebuild`;
  - confermare working tree pulita.

### Sicurezza

- Non inserire secret nel repository.
- Non stampare password, API signature, client secret, token completi o NVP completi.
- Non usare account PayPal reale.
- Non inserire dati carta reali.
- Non chiamare gateway live salvo autorizzazione esplicita in task dedicato.
- Non modificare DB/dump SQL salvo task DB esplicito con backup.

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

## 3. Stato Git attuale

Stato di riferimento corrente dopo chiusura e merge fast-forward `CATALOG-ONSUS-PARITY-1B-TOOLBAR-CONTROLS`:

- Branch stabile: `frontend-rebuild`
- HEAD stabile locale/origin: `9903687f89f99073d29cc0598746e17511f7e546`
- `main` invariato: `976e99f17cabc8a5c6a8715463444edfeaadcd91`
- Commit PDP CTA: `b56277c7777345c70021e21270628b72a51a2f4c` e `3b0b2ac97564c497abd26d224e5e945834a2ec26`; merge `--ff-only`, smoke Germano finale A desktop/mobile.
- Commit foundation typography: `d0f5f500f75da70aaf0c4a961762cf35f3db51ac` (`fix: establish Arial typography foundation`); runtime limitato a `Page.master` e `Public/assets/keepstore/css/theme-overrides.css`, smoke Germano A desktop/mobile.
- Commit typography `1B`: `efae083a3d2dece257290d3c3b5d6bde39d6af32` (`fix: normalize storefront typography families`) e `df98e70ced14a6f635d7819fadebe22d09f103ee` (`fix: prevent home product title clipping`); merge fast-forward `--ff-only`, smoke Germano A desktop/mobile, blocco typography chiuso.
- Commit cart-state storefront: `68325c1879e2859628b59f297fe2a329b5aadb35` (`fix: unify storefront cart state`); merge fast-forward `--ff-only`, smoke Germano A desktop/mobile.
- Commit catalog parity `1A`: `1acbba90a4e9973da695ec08a80840fd113a90fa` (`fix: stabilize catalog request state and paging`); stato URL e paging deterministici, smoke Germano A.
- Commit catalog toolbar `1B`: `9903687f89f99073d29cc0598746e17511f7e546` (`fix: align catalog toolbar with Onsus controls`); merge fast-forward `--ff-only`, smoke Germano A.
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

1. Stabilizzare PayPal Express in sandbox.
2. Ottenere almeno un esito sandbox `Completed` con buyer Personal distinto dal merchant Business.
3. Verificare recheck pending con `GetTransactionDetails`.
4. Definire gestione amministrativa pending/paymentreview.
5. Preparare cifratura credenziali condivisa tra gestionale e sito.
6. Solo dopo sandbox completa, pianificare eventuale abilitazione live controllata.

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

KeepStore usa PayPal Express Checkout classico NVP:

- `SetExpressCheckout`
- `GetExpressCheckoutDetails`
- `DoExpressCheckoutPayment`
- `GetTransactionDetails` per recheck pending

Non usare REST Orders API v2 nel flusso attuale.
Non usare `_xclick` come checkout principale.
Non usare `ipn.aspx.vb` come autorita primaria.

### Configurazione

PayPal Express e multi-azienda e legge configurazione da DB tramite `vpaypal_express_azienda`.

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
- Il runtime locale verificato con `localhost` mappa Webaffare/Azienda 2 tramite `Aziende.URL2=localhost`; quindi un test locale su `localhost` non prova automaticamente il comportamento Taikun.
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

Regola vincolante:

- `Pagato=1` solo dopo `DoExpressCheckoutPayment` verificato con ACK success e `PaymentStatus=Completed`, oppure dopo recheck `GetTransactionDetails` che conferma stato completed su TransactionID gia esistente.
- Non richiamare `DoExpressCheckoutPayment` su transazione gia creata.

### Token e TransactionID

Convenzione:

- token Express temporaneo: `EC-TOKEN:<token>` in `documenti.IdTransazione`;
- transazione completata: `TXN:<transactionId>` in `documenti.IdTransazione`.

Nei log/report:

- token sempre mascherato;
- transaction id sempre mascherato se mostrato;
- nessuna query NVP completa.

### Stato sandbox recente

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

### Immediati

1. Scegliere il prossimo blocco operativo su `frontend-rebuild` pulito.
2. Possibili candidati:
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
3. Mantenere PayPal, BancaSella, gateway e pagamenti in task separati dal carrello UI.
4. Revocare/cambiare la password dell'utente MySQL temporaneo usato nello smoke, se ancora attivo.
5. Eliminare eventuali variabili ambiente temporanee di smoke.
6. Eliminare o lasciare scadere eventuali link reset test residui.
7. AUTH-CSRF-AUDIT-1A: audit `AntiCsrfPage` sui flussi auth.
8. AUTH-JS-LEGACY-AUDIT-1A: audit errori JS legacy residui.
9. DATIUTENTE-LEGACY-AUDIT-1A per errore generico, tab/JS legacy e salvataggi/destinazioni.

### PayPal Express

1. Riprovare pagamento sandbox con buyer Personal distinto dal merchant Business.
2. Se PayPal restituisce ancora `Pending`:
   - confermare `PendingReason`;
   - non impostare `Pagato=1`;
   - usare recheck.
3. Se PayPal restituisce `Completed`:
   - `Pagato=1`;
   - `StatoPagamentoWeb=2`;
   - `IdTransazione=TXN:<transactionId>`;
   - transazione `COMPLETED`;
   - Pay Now non visibile.

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
