# KeepStore AI Assisted Commerce Search Blueprint

Stato: blueprint architetturale, non implementazione runtime.

Questo documento definisce la direzione futura per una ricerca assistita / assistente acquisto multi-merceologia in KeepStore 3.0. La funzione deve nascere sopra la ricerca deterministica esistente e sopra i dati reali del catalogo, senza introdurre API AI, nuove tabelle, endpoint o modifiche runtime in questa fase.

Nota permanente stack/sicurezza: qualunque task runtime futuro legato a search, assistenza acquisto o AI deve rispettare il contratto tecnico generale KeepStore: ASP.NET WebForms, VB.NET, .NET Framework 4.x e MySQL; niente C#, ASP.NET Core, Razor/MVC/Blazor, EF Core, migrations, API rewrite, nuove pipeline npm/Vite/Webpack o librerie senza audit e approvazione. Input, querystring, redirect, output e dati catalogo devono restare validati/encoded lato server, con query parametrizzate e whitelist dove servono. OWASP Top 10, OWASP ASVS e Microsoft ASP.NET WebForms / ASP.NET 4.x security sono i riferimenti metodologici.

Nota roadmap permanente: le funzioni search/AI/SEO seguono la scaletta prioritaria del masterplan e non devono scavalcare i blocchi ecommerce/UX gia pianificati. La proposta futura `llms.ashx` / `llms.txt` / JSON-LD dinamico resta in Priorita 8 e richiede prima `LLMS-TXT-ASHX-JSONLD-AUDIT-1` read-only, con approvazione esplicita Germano prima di qualunque runtime. Non usare C#, ASP.NET Core, controller o routing Core; la pagina prodotto reale e `articolo.aspx`, non `prodotto.aspx`.

Regola stato: chiudere un micro-task su `articoli.aspx` non significa dichiarare completa la pagina catalogo. Il catalogo ha task chiusi su search, zero-results, filtri, card, selezione multipla, quantita in carrello, visual mobile e CTA `Acquista`, ma full ONSUS parity, funzioni residue, controlli, sort/layout e responsive complessivo restano aperti fino a `CATALOG-ONSUS-PARITY-AUDIT-1` e task successivi.

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
- prodotti in carrello solo in futuro, con task privacy esplicito;
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

- PR #222 chiusa: `catalogUrl` suggest usa `disponibile=1` e `ordinamento=...`, allineati ad `articoli.aspx`; ranking/query SQL invariati.
- PR #223 chiusa: JSON pubblico suggest non espone piu `ex.Message`; errore generico `Servizio suggerimenti temporaneamente non disponibile.` con formato `ok=false` + `error`.
- PR #224 chiusa: `SearchScore` catalogo ampliato in `articoli.aspx.vb` con `DescrizioneHTML` solo scoring, marca+descrizione, tassonomie e token multi-parola; query filtro principale, `Export +500`, Codice/EAN e query numeriche preservati.
- PR #226 chiusa: zero-results catalogo migliorato in `articoli.aspx` con query HTML encoded, CTA generiche e chip da token query; fallback statici merceologici/elettronica rimossi per multi-merceologia, senza AI attiva, prodotti inventati, query DB extra o modifiche a suggest/ranking.
- PR #228/#229/#230 chiuse: performance zero-results e sidebar filtri catalogo stabilizzate senza AI attiva. PR #228 evita facet/`showFilters()` su zero-results usando `lvProdotti.Items.Count`; PR #229 fissa l'ordine `Marche > Tipologie > Gruppi > Sottogruppi > Disponibilita > Varianti`, rimuove `Categoria` dalla sidebar e preserva `ct` come querystring; PR #230 compatta lo spacing con CSS scoped sotto `#ksCatalogPage`. Query prodotti principale, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine e gateway restano invariati.
- PR #232 chiusa: filtri applicati catalogo in stile ONSUS-like con `.meta-filter-shop`, `#applied-filters`, `.remove-all-filters` e `icon-close`; rimozione singola filtro via GET sicuro, remove-all visibile e funzionante, `st/ct` preservati, nessun chip tecnico solo ID, sidebar invariata e zero-results preservato. Query prodotti principale, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine, gateway e JS restano invariati; CSS scoped sotto `#ksCatalogPage`.
- PR #234 chiusa: navigazione `Settori` ONSUS-like sopra i facet catalogo, basata su `CatalogMenuSector` e `CatalogMenuProvider`, gerarchia `Settori > Categorie`, URL puliti `st`/`st+ct`, parametri sporchi azzerati, cache `LoadCatalogMenuCached()` 600s e rendering limitato. La label `Categoria/Categorie` e stata corretta in `Settori`; non e un facet laterale e non modifica query prodotti, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine, gateway o JS. Applied filters PR #232 e zero-results PR #226 restano preservati.
- PR #236 chiusa: card prodotto runtime catalogo `article.card-product` rifinita in stile ONSUS-like con CSS scoped sotto `#ksCatalogPage`; `.ks-catalog-card` resta fallback, non target principale. Tipografia verificata: `"Inter", serif`, titolo `14px / 600 / 22px`, prezzo `20px / 500 / 22px`, dettagli codice/disponibilita `12px / 22px`. Regola immagini DB-first documentata: placeholder `/Public/assets/images/img/placeholder.svg` solo se `ImageUrl` manca, niente `onerror` aggressivo; immagini rotte con path DB presente restano backlog asset/path. Query prodotti, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine, gateway, Settori/sidebar/filtri/applied filters e asset restano invariati.
- PR #238 chiusa: polish CSS-only di quantita/checkbox nella card runtime `article.card-product`, scoped sotto `#ksCatalogPage`. Restano invariati `tbQuantita`, `CheckBox_SelezioneMultipla`, `hfID`/`hfTCId`, `data-ks-*`, `ProductCard.ascx`, `ProductCard.ascx.vb`, `articoli.aspx`, `articoli.aspx.vb`, JS, link `cart_add.aspx`, add-to-cart, wishlist, compare e quickview; in PR #238 nessun bottone globale selezionati era ancora stato aggiunto. L'azione globale e stata poi chiusa separatamente con PR #240. Query prodotti, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine, gateway, Settori/sidebar/filtri/applied filters e asset restano invariati; card typography PR #236 preservata. Smoke visuale Germano OK / "TUTTO OK" e performance pre/post merge documentata.
- PR #240 chiusa: CTA globale `Aggiungi selezionati al carrello` completata in `articoli.aspx` per acquisto multiplo dal catalogo. Flusso: spunta `Seleziona` sulla card, quantita, invio dal footer `Acquisto multiplo`; label e icona CSS multi-check rendono chiara la selezione, la CTA resta rossa in hover/active/focus e non diventa nera al click. Usa il flusso carrello server-side esistente senza modificare `ProductCard.ascx`/`.vb`, JS, `cart_add.aspx`, `aggiungi.aspx`, query/ranking/search, DB/schema/SP, checkout/ordine, gateway/PayPal/email/auth, Settori/sidebar/filtri/applied filters o asset. Smoke Codex e Germano OK; build/precompile, diff check e secret scan OK. Backlog separati: quantita gia presente nel carrello su `articolo.aspx`, side cart/offcanvas ONSUS, audit funzioni mancanti `articoli.aspx` vs ONSUS e audit immagini rotte/path DB.
- `CATALOG-BUY-CTA-ACQUISTA-1A/1B` chiuso su `frontend-rebuild` con HEAD `d5000b18e93e2857d591e3443273cec874b2fe09`: CTA add-to-cart delle card catalogo `articoli.aspx` resa piu commerciale senza modificare search/AI. Runtime: `ProductCard.ascx`, `ProductCard.ascx.vb`, `catalog-ui.css`. Rimossa la CTA/tooltip superiore `Carrello` / `Aggiungi al carrello` sopra Wishlist; aggiunta CTA `Acquista` con icona carrello vicino al box quantita; polish estetico con forma piu squadrata/professionale, `border-radius: 6px`, colore `var(--primary-2, #D80027)`, nessun arancio e-stayon. Desktop verificato con testo `Acquista` espandibile in hover/focus; mobile `390x844` verificato con testo sempre visibile e touch target circa 44px. Preservati `.js-ks-cart-link`, `href` `cart_add.aspx`, `.ks-qty`, `data-ks-existing-cart-qty`, `data-ks-*`, delta `2 -> 2`, `2 -> 3`, `2 -> 5`, selezione multipla, quantita gia nel carrello ed evidenziazione card. HOME non modificata in questo task, poi chiusa separatamente da `HOME-BUY-CTA-ACQUISTA-1A/1B/1C`; `articolo.aspx`, MiniCart, carrello, `cart_add`, `aggiungi`, checkout/ordine/auth, query/ranking/search, DB/schema/SP e asset non modificati. Smoke Codex/Germano, build/precompile, diff check e secret scan OK. Backlog separati residui: `PDP-BUY-CTA-ACQUISTA-1A`, `PRODUCT-IMAGE-BRIGHTNESS-PREVIEW-1A`, side cart/offcanvas, quantita su `articolo.aspx`, bug login anonimo/mobile se ricompare, menu Catalogo mobile e `HomeDepartmentsMenu`.
- `HOME-BUY-CTA-ACQUISTA-1A/1B/1C` chiuso su `frontend-rebuild` con HEAD `116000c64c2b09192e6aba5dc25916010dad9197`: le CTA carrello delle card prodotto HOME sono allineate allo standard commerciale `Acquista` gia approvato sul catalogo. Branch runtime chiuso `task/home-buy-cta-acquista-1a`; commit originari prima del rebase `d3ecb36ffab53bb9e063377f2d61597d787b7a94`, `40a83ec0da6e72eb29726ed91e2ec77a79b2652f`, `8adcc942429df53b26992b605bc8f651c6e5b374`; dopo rebase su `frontend-rebuild` aggiornato `a0d0163efcee60e859a469662679323e1f1697d6`, `6561ed3e47ba318b3dc9086dba13c451a9341e9b`, `116000c64c2b09192e6aba5dc25916010dad9197`. File runtime: `Default.aspx.vb` e `theme-overrides.css`. Coinvolti `RenderActionButtons`, `RenderGridCard`, `RenderDealCard`, `RenderRowCardFromRow`, `RenderBigCard` e `rptDealOfDay` / `Occasione Imperdibile`. CTA finale: icona standard `icon-cart-2`, testo `Acquista`, `aria-label/title` `Acquista: aggiungi al carrello`, colore `var(--primary-2, #D80027)`, radius circa `6px`, forma rettangolare/elegante non pill, desktop compatta con espansione hover/focus e mobile `390x844` sempre visibile/toccabile. `Occasione Imperdibile` e allineato agli altri blocchi HOME. Preservati `href` `cart_add.aspx`, `.js-ks-cart-link`, `data-ks-*`, id articolo, `TCid`, `qty`, querystring/flusso add-to-cart HOME; ProductCard/catalogo, `articolo.aspx`, carrello, `cart_add`, `aggiungi`, checkout, MiniCart, DB/schema/SP e immagini/path asset non modificati. Rebase pulito, merge fast-forward, HTTP 200 HOME/catalogo/carrello, add-to-cart HOME reale OK, catalogo `articoli.aspx?q=hp` invariato e add catalogo OK, build/precompile, diff check e secret scan OK. Smoke utente Germano OK su 1A, 1B e 1C. Dopo questa chiusura HOME non e piu backlog; restano separati `PDP-BUY-CTA-ACQUISTA-1A`, `PRODUCT-IMAGE-BRIGHTNESS-PREVIEW-1A`, side cart/offcanvas, quantita su `articolo.aspx`, bug login anonimo/mobile se ricompare, menu Catalogo mobile, `HomeDepartmentsMenu` e valutazione futura `llms.ashx`/`llms.txt`/JSON-LD dinamico.
- `HEADER-CATALOG-MEGAMENU-READABILITY-1A` chiuso su `frontend-rebuild` con HEAD `3d75d5349df857f1b594760590bbdc22c553f2d8`: migliorata la leggibilita desktop del mega menu `Catalogo` nell'header, senza modificare mobile, search/suggest, ranking o dati catalogo. Il fix ha toccato solo `Page.master` e `Public/assets/keepstore/css/theme-overrides.css`: selettori reali del menu desktop, primo pannello categorie visibile all'apertura e cache-buster CSS aggiornato. Stile finale: colore tema ONSUS/KeepStore `var(--primary-2, #D80027)`, nessun arancio e-stayon, titoli uppercase `"Inter", serif` circa `19px / 800`, sottocategorie scure circa `16px / 24px`, linea sottile sotto i titoli, colonne ordinate, URL `st/ct/tp` preservati e nessun overflow desktop rilevato. Smoke visuale Germano OK; build/precompile, diff check e secret scan OK. La CTA prodotto `Acquista` su HOME e stata poi chiusa da `HOME-BUY-CTA-ACQUISTA-1A/1B/1C`; restano backlog separati scheda prodotto/PDP, immagini prodotto piu brillanti, bug add-to-cart anonimo/mobile login message se ricompare, side cart/offcanvas ONSUS, quantita su `articolo.aspx`, menu Catalogo mobile e `HomeDepartmentsMenu`. Il bug visual mobile quantita carrello e stato chiuso da `CART-QTY-MOBILE-VISUAL-FIX-1A`.
- `CART-QTY-IN-CATALOG-1A` chiuso: `articoli.aspx` mostra nella card catalogo la quantita reale gia presente nel carrello per `ArticoliId + TCId`, usando snapshot read-only da tabella `carrello` e owner `LoginId`/`LOGINID` oppure `Session.SessionID`, senza query per card. Se `CartQty=0` la card resta normale e il box vale `1`; se `CartQty>0` il box mostra il totale reale in verde/grassetto e la card e evidenziata in modo professionale, senza testo/pill/badge esterni. Il delta e corretto nel layer catalogo: `2 -> 2` resta `2`, `2 -> 3` diventa `3`, `2 -> 5` diventa `5`, con gestione server-side WebForms/multiselect e JS link add-to-cart reale; cache-buster su `keepstore-product.js` evita handler vecchi in browser. `articolo.aspx` resta backlog separato. Query prodotti, SearchScore/ranking, suggest, DB/schema/SP, ProductCard, `cart_add.aspx`, `aggiungi.aspx`, carrello runtime, checkout/ordine, gateway/PayPal/email/auth, Settori/sidebar/filtri/applied filters e asset restano invariati.
- `CART-QTY-MOBILE-VISUAL-FIX-1A` chiuso su `frontend-rebuild` con HEAD `be4cfcb12e9f4aa5323f8a39c84f2ce40eca214e`: resa stabile anche su mobile la grafica `prodotto gia nel carrello` su `articoli.aspx`. La quantita era corretta, ma la card runtime `ProductCard` usava `article.card-product` fisso e l'evidenziazione dipendeva soprattutto da CSS `:has(.ks-cart-qty-input-present)`. Ora `ProductCard` supporta classi server-side stabili: `ks-card-in-cart` sulla card e `ks-cart-qty-present` sul wrapper quantita quando `CartQty > 0`; `:has()` resta fallback. Mobile reale verificato con viewport mobile, desktop e HOME verificati nello smoke utente Germano; nessun testo/pill/badge esterno `In carrello`/`Nel carrello`, accessibilita via `title`/`aria-label`, delta `2 -> 2`, `2 -> 3`, `2 -> 5` e selezione multipla PR #240 preservati. Non modificati carrello, `cart_add`, `aggiungi`, checkout/ordine/login/auth, MiniCart, JS, query/ranking/search, DB/schema/SP, Settori/sidebar/filtri/applied filters o asset; build/precompile, diff check e secret scan OK.
- `CART-CONTINUE-SHOPPING-1A` chiuso su `frontend-rebuild` con HEAD `09bdd4f749522e9a9dd7b0b884620f54dc9d5624`: `carrello.aspx` ora riporta `Continua lo Shopping` all'ultima pagina/contesto shopping reale invece della HOME generica. File runtime: `carrello.aspx.vb` e `aggiungi.aspx.vb`. Causa: `btContinua` usava `Session("Pagina_visitata_Articoli")`, dove `articoli.aspx` salvava un URL assoluto; `SafeRedirectLocal` accettava solo locali e scartava l'assoluto verso fallback `default.aspx`. Soluzione: `ResolveContinueShoppingUrl()` con priorita `Session("Carrello_Pagina")`, `Session("Pagina_visitata_Articoli")` normalizzabile, referrer locale idoneo e fallback sicuro; `aggiungi.aspx.vb` conserva `Session("Carrello_Pagina")` fino alla pagina carrello. Sicurezza: same-host assoluti convertiti in `PathAndQuery`, esterni e scheme/percorso rischiosi respinti, whitelist `Default.aspx`/`articoli.aspx`/`articolo.aspx`, esclusi carrello/checkout/ordine/pagamento/login/gateway/logout/reset/remind/token. Test: ritorno da `q=hp`, da `st/ct/tp`, da scheda articolo, da HOME e fallback diretto; desktop e mobile smoke Germano OK, Codex mobile su `st/ct/tp`, checkout anonimo/loginrequired preservato, nessun side cart/offcanvas implementato, build/precompile, diff check e secret scan OK.
- Regola operativa mobile/ecommerce: nessun task UI/catalogo/carrello/checkout/login/sessione/flusso ecommerce puo dichiarare `mobile OK`, `desktop/mobile verificati` o `responsive OK` senza verifica reale del percorso mobile interessato; se non verificato, deve dirlo. Le verifiche vanno separate per logica, desktop, mobile, anonimo, loggato quando pertinente, click/submit reale e comportamento ecommerce. Add-to-cart deve restare libero per anonimo; login required solo su checkout/ordine/conferma. Backlog aperti post smoke mobile: `BUG-ADD-TO-CART-ANON-MOBILE-LOGIN-MESSAGE`, quantita su `articolo.aspx` e side cart/offcanvas ONSUS. `BUG-CART-QTY-MOBILE-VISUAL` e chiuso da `CART-QTY-MOBILE-VISUAL-FIX-1A`.
- Dettaglio backlog post smoke mobile: `BUG-ADD-TO-CART-ANON-MOBILE-LOGIN-MESSAGE` salva il prodotto in carrello ma mostra `Accedi per inviare l'ordine` su `carrello.aspx` dopo semplice add-to-cart anonimo mobile, da verificare anche desktop; `BUG-CART-QTY-MOBILE-VISUAL` e stato chiuso da `CART-QTY-MOBILE-VISUAL-FIX-1A` con classi server-side stabili e verifica mobile reale. Side cart/offcanvas ONSUS resta separato: anteprima dopo add-to-cart e continuazione shopping, senza mischiarlo con loginrequired o visual mobile.
- Test registrati: `hp` non peggiorato (`18933,20018`), `stampante hp` migliorato verso suggest (`20810,17698`), `12384` invariato con nessun ID catalogo e suggest `total=0`; smoke suggest/articoli/carrello OK.
- Limiti residui: LIKE su molte colonne lunghe puo diventare costoso; zero results ora e assistito ma resta locale/non-AI; eventuale AI/LLM resta fase successiva con privacy task.

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
   - restano backlog separati side cart/offcanvas, quantita gia presente nel carrello su `articolo.aspx`, funzioni ONSUS mancanti e immagini rotte/path DB.

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
   - `articolo.aspx` resta backlog separato;
   - smoke mobile reale ha aperto backlog separato `BUG-ADD-TO-CART-ANON-MOBILE-LOGIN-MESSAGE`; `BUG-CART-QTY-MOBILE-VISUAL` e stato poi chiuso con verifica mobile reale da `CART-QTY-MOBILE-VISUAL-FIX-1A`.

14. `CART-CONTINUE-SHOPPING-1A`
   - chiuso su `frontend-rebuild` con HEAD `09bdd4f749522e9a9dd7b0b884620f54dc9d5624`;
   - `carrello.aspx` torna all'ultima pagina/contesto shopping reale invece della HOME generica;
   - priorita URL: `Session("Carrello_Pagina")`, `Session("Pagina_visitata_Articoli")`, referrer locale idoneo, fallback sicuro;
   - URL assoluti same-host normalizzati a `PathAndQuery`, URL esterni e pagine non shopping respinti;
   - preservati checkout anonimo/loginrequired e separato il backlog side cart/offcanvas.

15. `AI-ASSISTANT-DATA-PROFILE-AUDIT-1A`
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
