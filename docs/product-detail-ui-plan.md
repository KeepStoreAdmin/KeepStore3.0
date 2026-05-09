# Piano UI scheda prodotto

## 1. Stato branch e perimetro

- Branch di lavoro: `task/product-detail-ui-plan`.
- La fase iniziale era solo pianificazione tecnica; ora esiste anche una preview demo locale e gated.
- La scheda reale `pnlProduct` non e' stata sostituita.
- Nessun flusso applicativo reale viene cambiato dalla preview.
- Ogni step operativo futuro dovra' restare gated, reversibile e disattivato di default.

## 2. File coinvolti nella scheda prodotto

- `articolo.aspx`
- `articolo.aspx.vb`
- `App_Code/ThemeManager.vb`
- `App_Code/UiPriceFormatter.vb`
- `App_Code/KeepStoreSecurity.vb`
- `Public/assets/keepstore/css/product-ui.css`
- `Public/assets/keepstore/js/product-ui.js`
- `Public/assets/keepstore/js/keepstore-product.js`
- `Public/assets/keepstore/js/keepstore-recently-viewed.js`
- Asset collegati: `drift-basic.min.css`, `photoswipe.css`, Swiper, Drift, PhotoSwipe.

## 3. Struttura attuale di articolo.aspx

La pagina usa `Page.master` e definisce contenuti per title, head, breadcrumb, main content e script.

La struttura visibile comprende:

- stato prodotto non trovato;
- gallery immagini con thumbs;
- informazioni prodotto principali;
- prezzo principale;
- badge ricondizionato;
- descrizione breve;
- buy box sticky;
- scelta variante;
- quantita';
- pulsante server-side di aggiunta al carrello;
- tab descrizione, informazioni e recensioni;
- bundle/acquisto combinato;
- prodotti compatibili;
- prodotti correlati;
- brand/marche;
- visti di recente;
- icon box servizi.

## 4. Flusso articolo.aspx.vb

`Page_Load` esegue:

- parsing di `id` e `TCid`;
- scelta listino corrente;
- lettura stato varianti da `Session("TC")`;
- su primo load chiama `LoadPage()`.

`LoadPage()`:

- carica la riga prodotto da `vsuperarticoli`;
- gestisce fallback TCid;
- mostra not found se non trova dati;
- esegue `BindProduct`;
- traccia visti di recente;
- applica SEO;
- carica recensioni;
- carica relazioni prodotto.

## 5. Parametri browser id e TCid

- `id`: obbligatorio, deve essere intero positivo.
- `TCid`: opzionale, accetta anche `-1` come valore storico di non-variante.
- Se `TCid` non e' valido, la pagina redirige a `articolo.aspx?id=...`.
- Se `TCid` e' presente ma non trova una variante valida, viene tentato fallback sul prodotto base.

## 6. Query e viste usate

La riga prodotto principale viene letta da:

- `vsuperarticoli`
- filtro `ID=@id`
- filtro `NListino=@nlistino`
- filtro opzionale `TCid=@tcid`

Altre sorgenti:

- `articoli_tagliecolori`
- `taglie`
- `colori`
- `articoli_correlati`
- `articoli_compatibili`
- `articoli_recensioni`
- `vsuperarticoli` per correlati, compatibili, brand e visti recentemente.

## 7. Campi prodotto letti

Campi principali rilevati:

- `ID` / `id`
- `TCid`
- `Codice`
- `SKU`
- `Ean` / `EAN`
- `Descrizione1`
- `Nome`
- `Descrizione`
- `Descrizione2`
- `DescrizioneHTML`
- `DescrizioneLunga`
- `Img1` ... `Img6`
- `MarcheDescrizione`
- `Marca`
- `MarcheId`, `MarcaId`, `IdMarca`
- `SettoriDescrizione`
- `CategorieDescrizione`
- `TipologieDescrizione`
- `Prezzo`
- `PrezzoIvato`
- `PrezzoPromo`
- `PrezzoPromoIvato`
- `InOfferta`
- `Giacenza`
- `Impegnata`
- `Disponibilita`
- `InOrdine`
- `Arrivo` / `arrivi`
- `Ricondizionato`
- `NoteRicondizionato`
- `SpeditoGratis`
- `MetaDescription`

## 8. Scelta listino

Il listino corrente viene determinato da `GetCurrentListino()`:

- prima `Session("Listino")`;
- poi `Session("listino")`;
- fallback `1`;
- riallineamento di entrambe le chiavi sessione.

La futura UI non deve scegliere o ricalcolare il listino lato JavaScript.

## 9. Prezzi e promo

La pagina usa `BuildPriceContext()`:

- se `Session("IvaTipo") = 1`, usa prezzi netti;
- altrimenti usa prezzi ivati;
- la promo e' valida solo se `InOfferta = 1`;
- il prezzo promo deve essere maggiore di zero;
- il prezzo promo deve essere minore del prezzo base;
- il prezzo barrato viene mostrato solo in caso di promo coerente.

Prezzo, listino e promo devono restare server-side.

## 10. IVA, reverse charge, esenzione

La pagina dettaglio usa direttamente `Session("IvaTipo")` per scegliere netto/ivato.

Non e' stata rilevata logica UI diretta per:

- reverse charge;
- esenzione IVA;
- campi `IdIvaRC`;
- campi `idEsenzioneIva`.

Queste condizioni non devono essere ricostruite in JavaScript. La futura UI deve consumare il risultato server-side gia' calcolato.

## 11. Disponibilita'

La disponibilita' viene costruita da `BuildAvailabilityText()`:

- se `Giacenza - Impegnata > 0`: disponibile;
- se esiste `Arrivo` / `arrivi`: in arrivo;
- se `Disponibilita > 0`: disponibile su ordinazione;
- se `InOrdine > 0`: in ordine;
- fallback: verifica disponibilita'.

Il rendering usa classi server-side di stato:

- `ks-availability-ok`
- `ks-availability-wait`
- `ks-availability-check`

Disponibilita', giacenza, impegnato e arrivi non devono essere ricalcolati in JavaScript.

## 12. TCId, taglie, colori, varianti

La pagina usa:

- `_tcid`;
- `_tcidPresent`;
- `_tcEnabled`;
- `Session("TC")`;
- tabella `articoli_tagliecolori`;
- tabelle `taglie` e `colori`.

Il dropdown varianti usa `ddlTc` con `AutoPostBack=True`.

Al cambio variante:

- viene costruito URL prodotto con `TCid`;
- viene fatto redirect alla variante selezionata.

## 13. Add-to-cart e sessioni legacy

Il pulsante principale e' `btnAddToCart`, server-side.

Il flusso deve restare server-side:

- normalizza quantita';
- risolve `TCid`;
- ricarica la riga prodotto;
- imposta `Session("ProdottoGratis")`;
- imposta `Session("Carrello_ArticoloId")`;
- imposta `Session("Carrello_TCId")`;
- imposta `Session("Carrello_Quantita")`;
- imposta `Session("Carrello_Pagina")`;
- imposta `Session("Carrello_SelezioneMultipla")`;
- redirige a `aggiungi.aspx`.

La futura UI non deve sostituire questo flusso con JavaScript.

## 14. Quantita'

La quantita' usa `txtQty` con default `1`.

Server-side:

- `NormalizeCartQuantity`;
- fallback `1`;
- massimo `9999`.

Client-side:

- stepper con `data-ks-qty`;
- logiche presenti in `product-ui.js` e `keepstore-product.js`.

Rischio da testare: doppio binding degli handler `+` e `-`.

## 15. Wishlist, compare, quick view nelle card correlate

La scheda principale non espone un blocco wishlist/compare dedicato rilevante.

Le card correlate, compatibili e recenti usano:

- `BuildCartAddUrl`;
- `BuildWishlistAddUrl`;
- `BuildActionDataAttributes`;
- `js-ks-cart-link`;
- `js-ks-wishlist-link`;
- `js-ks-quickview`;
- `js-ks-compare`.

Questi hook sono funzionali e non vanno rimossi senza alternativa equivalente.

## 16. Gallery immagini, zoom, PhotoSwipe, Drift, Swiper

`BindImages()` legge `Img1` ... `Img6`.

Comportamento:

- normalizzazione URL immagini;
- deduplica immagini;
- fallback placeholder;
- riempimento fino a 6 slot;
- binding su `rptMainImages`;
- binding su `rptThumbs`.

La UI usa:

- Swiper per gallery e thumbs;
- Drift per zoom;
- PhotoSwipe per lightbox;
- classi `tf-image-zoom`, `ks-product-gallery-main`, `ks-product-gallery-thumbs`.

## 17. Correlati, compatibili, brand, visti recentemente

Sezioni rilevate:

- bundle / acquisto combinato;
- compatibili;
- correlati;
- brand strip;
- visti di recente.

I dati derivano da:

- tabelle relazionali dedicate;
- fallback smart su categoria, tipologia e marca;
- cookie/sessione per recenti;
- `keepstore-recently-viewed.js`.

## 18. SEO, canonical, Open Graph, JSON-LD

`ApplySeo()` imposta:

- `Page.Title`;
- meta description;
- robots `index,follow`;
- canonical;
- Open Graph type/title/description/url/image;
- JSON-LD in head.

Il JSON-LD include:

- Organization;
- WebSite;
- WebPage;
- BreadcrumbList;
- Product;
- Offer se esiste prezzo valido.

La futura UI non deve degradare canonical, Open Graph o JSON-LD.

## 19. Asset CSS e JS usati

CSS:

- `drift-basic.min.css`
- `photoswipe.css`
- `product-ui.css`

JS:

- `product-ui.js`
- `keepstore-product.js`
- `keepstore-recently-viewed.js`

Dipendenze di tema/master:

- Swiper;
- Bootstrap;
- Drift;
- PhotoSwipe.

## 20. Parti grafiche migrabili

Sono candidati alla migrazione grafica:

- layout gallery;
- blocco informazioni prodotto;
- buy box;
- area prezzo;
- badge ricondizionato;
- feature list;
- tab descrizione/informazioni/recensioni;
- card correlate;
- icon box servizi;
- spaziature desktop/mobile.

## 21. Parti funzionali da non rompere

Non vanno rotti:

- parsing `id`;
- parsing `TCid`;
- fallback TCid;
- scelta listino;
- calcolo prezzo server-side;
- IVA server-side;
- promo server-side;
- disponibilita' server-side;
- add-to-cart server-side;
- sessioni carrello legacy;
- varianti;
- SEO;
- recensioni;
- recenti;
- sanitizzazione descrizione HTML.

## 22. Rischi principali

- Doppio incremento quantita' se piu' JS intercettano lo stepper.
- Perdita `TCid` nel carrello.
- Prezzo errato per listino o IVA.
- Promo mostrata senza coerenza con prezzo base.
- Disponibilita' non allineata a giacenza/impegnato/arrivi.
- Add-to-cart rotto se si sostituisce il postback.
- SEO incompleto.
- Gallery non inizializzata.
- PhotoSwipe/Drift rotti.
- Descrizione HTML non sanitizzata.
- Hook quick view/compare/wishlist persi sulle card correlate.

## 23. File critici da non toccare nella prima fase

- `articolo.aspx.vb`
- `aggiungi.aspx.vb`
- `cart_add.aspx.vb`
- `carrello.aspx`
- `carrello.aspx.vb`
- `Public/ui/controls/MiniCart.ascx`
- `Public/ui/controls/MiniCart.ascx.vb`
- `Page.master`
- `Page.master.vb`
- `web.config`
- database e query gestionali.

## 24. Primo micro-task sicuro successivo

Stato aggiornato:

- la preview gated locale e' stata introdotta;
- la preview e' visibile solo con `ksProductDetailPreview=1` in ambiente locale;
- la protezione usa `Request.IsLocal`;
- la UI normale non e' stata sostituita;
- non cambiare query;
- non cambiare add-to-cart;
- non cambiare prezzi/listino/IVA/promo/disponibilita'/TCId;
- usare dati gia' bindati dal server;
- mantenere rollback immediato rimuovendo o disattivando il parametro debug.

Primo step consigliato dopo lo stato attuale:

- aggiungere tab descrizione/info demo dentro la preview;
- rifinire il layout preview senza sostituire `pnlProduct`;
- valutare solo dopo una preview replace gated;
- introdurre eventuale feature flag separata solo dopo validazione completa.

## 25. Piano a fasi

1. Consolidare la mappa dati scheda prodotto. Stato: completato a livello documentale.
2. Definire un modello UI server-side per il dettaglio prodotto, senza usarlo in produzione. Stato: `ProductDetailViewModel` preparatorio creato.
3. Creare preview gated locale della nuova UI. Stato: completato con `ksProductDetailPreview=1` e `Request.IsLocal`.
4. Portare nella preview solo layout, gallery, buy box e blocchi informativi, mantenendo funzioni server-side esistenti. Stato: avviato con `ProductDetailView.ascx` demo, gallery statica, mini buy-box non operativa e blocchi descrizione/info demo.
5. Validare prezzo, listino, IVA, promo, disponibilita' e TCId.
6. Validare carrello da scheda prodotto.
7. Validare gallery reale, zoom e lightbox.
8. Validare SEO e JSON-LD.
9. Rifinire blocchi descrizione/info demo e layout piu' vicino alla UI finale.
10. Valutare una preview replace gated, senza attivazione produzione.
11. Introdurre eventuale feature flag separata, disattivata di default.
12. Attivare solo dopo test commerciale e gestionale.

## 26. Checklist test obbligatoria prima dell'attivazione

- [ ] Prodotto base senza `TCid`.
- [ ] Prodotto con `TCid=-1`.
- [ ] Prodotto con `TCid` reale.
- [ ] Cambio variante.
- [ ] Listino anonimo.
- [ ] Listino utente loggato.
- [ ] Cambio listino dopo login.
- [ ] Prezzo ivato.
- [ ] Prezzo netto.
- [ ] Promo valida.
- [ ] Promo non valida.
- [ ] Prezzo su richiesta.
- [ ] Disponibile da giacenza.
- [ ] Disponibile con impegnato.
- [ ] In arrivo.
- [ ] In ordine.
- [ ] Non disponibile / verifica disponibilita'.
- [ ] Add-to-cart da scheda prodotto.
- [ ] Quantita' 1.
- [ ] Quantita' maggiore di 1.
- [ ] Quantita' non valida.
- [ ] Bundle / acquisto combinato.
- [ ] Correlati.
- [ ] Compatibili.
- [ ] Wishlist nelle card correlate.
- [ ] Quick view nelle card correlate.
- [ ] Compare nelle card correlate.
- [ ] Gallery desktop.
- [ ] Gallery mobile.
- [ ] Zoom Drift.
- [ ] PhotoSwipe.
- [ ] Visti di recente.
- [ ] Recensioni.
- [ ] Canonical.
- [ ] Open Graph.
- [ ] JSON-LD Product / Offer.
- [ ] Console browser senza errori.
- [ ] Nessun doppio incremento quantita'.
- [ ] Checkout successivo al carrello.
- [ ] Ordine leggibile dal gestionale.

## 27. Stato reale preview ProductDetailView

La preview `ProductDetailView` e' stata introdotta come strato demo sopra la scheda reale, senza sostituire `pnlProduct`.

Stato micro-task:

- [x] PD-4: aggiunta preview shell gated locale con `phProductDetailPreview`.
- [x] PD-4: parametro debug `ksProductDetailPreview=1` protetto da `Request.IsLocal`.
- [x] PD-6: aggiunto `ProductDetailViewModel` preparatorio in `articolo.aspx.vb`.
- [x] PD-6: il model legge solo dati gia' caricati dalla pagina prodotto.
- [x] PD-7: preview alimentata con dati reali minimi.
- [x] PD-8: creato `ProductDetailView.ascx` demo.
- [x] PD-8: creato `ProductDetailView.ascx.vb` con proprieta' pubbliche.
- [x] PD-9: preview arricchita con immagine, marca, categoria, promo, IVA, disponibilita' e ricondizionato.
- [x] PD-11: introdotto `IProductDetailView` in `App_Code`.
- [x] PD-11: rimosso `CallByName` e sostituito con contratto tipizzato.
- [x] PD-12: aggiunta gallery demo statica.
- [x] PD-13: aggiunta mini buy-box demo non operativa.
- [x] PD-15: aggiunti blocchi descrizione/info demo alla preview.
- [x] PD-15: i blocchi descrizione/info demo mostrano descrizione breve, descrizione lunga, codice, EAN, marca, categoria, TCId e stato varianti.

Conferme di perimetro:

- [x] `pnlProduct` non e' stato sostituito.
- [x] La preview e' visibile solo con `ksProductDetailPreview=1` in ambiente locale.
- [x] La preview usa `Request.IsLocal`.
- [x] `ProductDetailViewModel` resta preparatorio.
- [x] `ProductDetailView.ascx` resta demo.
- [x] La gallery demo e' statica.
- [x] La gallery demo non usa Swiper, Drift o PhotoSwipe.
- [x] La mini buy-box e' non operativa.
- [x] I blocchi descrizione/info demo non usano tab JavaScript.
- [x] I tab reali di `articolo.aspx` non sono stati modificati.
- [x] Le recensioni reali non sono state modificate.
- [x] Il carrello reale resta nella scheda originale sotto la preview.
- [x] `btnAddToCart_Click` non e' stato modificato.
- [x] Query e datasource non sono stati modificati.
- [x] SEO, `ApplySeo`, gallery reale e `BindImages` non sono stati modificati.
- [x] Non sono stati aggiunti JavaScript o CSS.

Test browser eseguiti e OK:

- [x] Articolo normale senza parametro.
- [x] Preview locale con `ksProductDetailPreview=1`.
- [x] Dati prodotto visibili nella preview.
- [x] Gallery demo statica visibile.
- [x] Gallery reale visibile e invariata.
- [x] Mini buy-box demo visibile e non operativa.
- [x] Preview descrizione/info demo visibile.
- [x] Descrizione breve/lunga visibile.
- [x] Codice, EAN, marca, categoria e TCId visibili.
- [x] Tab reali della scheda originale funzionanti.
- [x] Carrello reale funzionante dalla scheda originale.
- [x] Quantita' reale funzionante dalla scheda originale.
- [x] Varianti/TCId reali funzionanti dalla scheda originale.
- [x] Console browser senza errori.
- [ ] Recensioni reali non testate in PD-15.

Rischi residui:

- [ ] Preview ancora demo.
- [ ] Mini buy-box non operativa.
- [ ] Gallery statica non finale.
- [ ] Nessuna sostituzione della scheda reale ancora eseguita.
- [ ] Recensioni reali non testate in questo micro-task.
- [ ] Futuro replace da fare solo con parametro gated e rollback rapido.

Prossimi step consigliati:

- [ ] Rifinire layout preview.
- [ ] Valutare eventuale preview replace gated.
- [ ] Testare recensioni reali.
- [ ] Introdurre feature flag separata solo dopo validazione completa.
