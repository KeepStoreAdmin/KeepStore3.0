# Catalog ProductCard guardrails

## Scopo

Questo documento fissa i guardrail operativi per modifiche future alla ProductCard del catalogo KeepStore.
La ProductCard non e' una preview isolata: e' gia' nel percorso reale del listing prodotti, quindi ogni modifica deve essere trattata come potenzialmente funzionale.

## Stato attuale

- `Public/ui/controls/ProductCard.ascx` e' live nel catalogo reale.
- `UseNewCatalogProductCard = True` in `articoli.aspx.vb`.
- Il controllo viene caricato da `articoli.aspx.vb` con `LoadControl("~/Public/ui/controls/ProductCard.ascx")`.
- Il model viene creato in `BuildProductCardModel(dataItem)`.
- La card viene inserita in `phReplacementProductCard`.
- `phInlineProductCard` resta il fallback inline della pagina.
- Il flusso passa da `lvProdotti_ItemDataBound`, quindi dipende dal binding del `ListView`.

## Guardrail hard

Non modificare senza micro-task dedicato e test completo:

- link carrello e costruzione `CartUrl`;
- `TCId`, fallback `TCid`/`TCId` e valore `-1`;
- `ArticoliId`/`ProductId`;
- quantita' e normalizzazione `QuantityText`;
- hidden fields `hfID` e `hfTCId`;
- `phLegacyServerControls`;
- `data-ks-*` generati da `CatalogActionDataAttributes`;
- wishlist e `WishlistUrl`;
- compare e `CompareTarget`;
- quick view e `QuickViewTarget`;
- classi `js-ks-*`;
- classi funzionali legate a carrello, wishlist, quick view, compare e quantita';
- server controls dentro `ProductCard.ascx`;
- proprieta' pubbliche di `ProductCard.ascx.vb`;
- `BuildProductCardModel`;
- `lvProdotti_ItemDataBound`;
- `phReplacementProductCard` e `phInlineProductCard`;
- `ListView`, `ItemTemplate`, datasource, filtri, paging e ordinamento.

## Parti a basso rischio

Sono candidabili solo con task piccolo e diff minimo:

- markup statico non funzionale;
- wrapper visuali che non cambiano ordine, ID o binding;
- classi neutre gia' disponibili;
- spacing e leggibilita' visuale;
- testo statico non commerciale e senza cambio di significato.

Anche in questi casi non sono ammessi:

- nuovi binding;
- nuovi `data-*`;
- nuovi hook JavaScript;
- nuovi link;
- nuovi server controls;
- modifiche a proprieta' o metodi code-behind;
- modifiche a query, datasource o carrello.

## Condizioni di stop automatico

Fermare il task prima di modificare se la richiesta richiede:

- modifica a `ProductCard.ascx.vb`;
- modifica a proprieta' pubbliche della card;
- modifica a `BuildProductCardModel`;
- modifica a `lvProdotti_ItemDataBound`;
- modifica a `CartUrl`, `WishlistUrl`, `QuickViewTarget` o `CompareTarget`;
- modifica a `CatalogCartAddUrl`, `CatalogWishlistAddUrl`, `CatalogProductUrl` o `CatalogActionDataAttributes`;
- modifica a `data-ks-*`;
- modifica a classi `js-ks-*`;
- modifica a `data-bs-toggle`;
- modifica a `hfID`, `hfTCId`, `tbQuantita` o `CheckBox_SelezioneMultipla`;
- modifica a `EnableLegacyServerControls`;
- modifica a `TCId`, `ArticoliId` o quantita';
- modifica a `ListView`, `ItemTemplate`, filtri, paging, ordinamento o datasource;
- modifica a query o database;
- aggiunta JavaScript o CSS;
- impossibilita' di eseguire i test manuali minimi.

## Matrice test manuale minima

Prima e dopo qualunque modifica alla ProductCard verificare:

- prodotto normale;
- prodotto promo;
- prodotto senza immagine;
- prodotto con `TCId` reale;
- prodotto con `TCId = -1`;
- link dettaglio prodotto;
- add-to-cart da icona;
- add-to-cart da pulsante principale;
- MiniCart dopo aggiunta;
- wishlist;
- compare;
- quick view;
- mobile;
- filtro disponibilita';
- filtri marca, tipologia, gruppo e sottogruppo;
- filtri taglia/colore se attivi;
- paging;
- ordinamento;
- console browser senza errori.

## Parametri e debug mode noti

Parametri locali noti:

- `ksCardPreview=1`;
- `ksCardPreviewReal=1`;
- `ksCardReplaceOne=1`;
- `ksCardReplaceAll=1`;
- `ksCardReplaceCount=N`.

Le modalita' debug sono gated da `Request.IsLocal` dove previsto dal codice.
Non usare questi parametri come sostituti dei test del catalogo reale.

## Regola operativa

- Prima documentazione e matrice test.
- Poi eventuale micro-task visuale piccolo.
- Mai unire modifiche funzionali e rifiniture markup nello stesso task.
- Mai modificare ProductCard live senza test browser completi su catalogo, carrello, MiniCart e azioni rapide.
