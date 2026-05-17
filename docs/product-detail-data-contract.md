# Product Detail Data Contract

## 1. Scopo

Questo documento descrive il contratto dati reale della scheda prodotto KeepStore (`articolo.aspx`) per guidare una futura evoluzione di `ProductDetailView` senza alterare il flusso attuale.

Non introduce modifiche applicative, non cambia query, carrello, varianti, SEO, gallery, disponibilita o asset. Serve come mappa tecnica prima di qualunque sostituzione UI controllata.

## 2. Fonte authoritative

La UI prodotto authoritative oggi e':

- `articolo.aspx`
- `articolo.aspx.vb`

`Public/ui/controls/ProductDetailView.ascx` e' una preview/demo locale, caricata sopra la scheda reale solo quando il gate debug lo consente. Non e' una sostituzione operativa della scheda prodotto.

## 3. Input richiesti dalla pagina

La pagina legge:

- `id`: obbligatorio, deve essere intero positivo. Se assente o non valido, la pagina redirige a `default.aspx`.
- `TCid`: opzionale, accetta anche `-1` come valore storico di non-variante.
- `ksProductDetailPreview=1`: abilita la preview solo se `Request.IsLocal` e' vero.

Fallback e prodotto non trovato:

- se `TCid` e' presente ma non valido, la pagina redirige a `articolo.aspx?id=<id>`;
- se `TCid` e' presente ma non trova una variante valida, il codice prova il prodotto base e puo' redirigere alla variante/default;
- se nessuna riga prodotto viene trovata, `ShowNotFound()` nasconde `pnlProduct` e mostra il messaggio prodotto non disponibile.

Dipendenze Session rilevanti:

- `Session("Listino")` e fallback `Session("listino")`: listino corrente, default anonimo robusto;
- `Session("TC")`: abilita gestione taglia/colore/varianti;
- `Session("IvaTipo")`: decide prezzo IVA esclusa/inclusa;
- `Session("AziendaNome")`: usata best-effort nel JSON-LD Organization;
- `Session("ks_recent_ids")` / `Session("ks_recent_session")`: prodotti recenti;
- sessioni recensione: `ks_review_flash`, `ks_review_last_submit`, dati utente/nome/email se presenti;
- sessioni carrello: valorizzate solo durante add-to-cart, non al semplice rendering.

## 4. Fonte dati principale

La fonte principale e' la view/tabella `vsuperarticoli`, letta da `GetProductRow()` / `TryGetProductRowInternal()` con:

- `ID=@id`
- `NListino=@nlistino`
- filtro opzionale `TCid=@tcid`

La query principale usa `SELECT * FROM vsuperarticoli`, quindi il contratto dipende dai campi realmente disponibili nella view.

Query ausiliarie principali:

- `articoli_tagliecolori`, `taglie`, `colori`: varianti `TCid`;
- `articoli_compatibili`, `articoli_collegati`, relazioni manuali e fallback smart su `vsuperarticoli`: bundle, simili, correlati;
- `articoli_recensioni`: recensioni prodotto;
- cookie/session `ks_recent`: prodotti recenti.

Campi stock e disponibilita:

- `Giacenza`
- `Impegnata`
- `Disponibilita`
- `InOrdine`
- `Arrivo` / `arrivi`

Campi prezzo/listino:

- `Prezzo`
- `PrezzoIvato`
- `PrezzoPromo`
- `PrezzoPromoIvato`
- `InOfferta`

Campi variante/TC:

- `TCid`
- dati da `articoli_tagliecolori`
- descrizioni taglia/colore/barcode quando disponibili

Campi ricondizionato:

- `Ricondizionato`
- `NoteRicondizionato`

## 5. Campi prodotto base

La UI reale mappa:

- ID articolo: `ID` / `id`
- variante: `TCid`
- nome: `Descrizione1`, fallback `Nome`, `Descrizione`, poi `Articolo`
- codice: `Codice`, fallback `SKU`
- EAN: `Ean` / `EAN`
- marca: `MarcheDescrizione`, fallback `Marca`
- categoria: `TipologieDescrizione`, `CategorieDescrizione`, `SettoriDescrizione`
- URL prodotto: `BuildProductUrl(id, tcid, includeTcid)`
- descrizione breve: `Descrizione2`, fallback `Sottotitolo`
- descrizione estesa: `DescrizioneHTML`, fallback `DescrizioneLunga`, `Descrizione2`
- meta description: `MetaDescription`, fallback descrizioni/nome
- note ricondizionato: `NoteRicondizionato`

Le descrizioni lunghe sono normalizzate con `NormalizeDescriptionHtml()`, che permette HTML base e rimuove blocchi/script pericolosi.

## 6. Prezzi

Il prezzo e' costruito da `BuildPriceContext()` e formattato da `BuildPriceHtml()` / `BuildPriceText()`.

Regole principali:

- `Session("IvaTipo") = 1`: usa prezzo IVA esclusa (`Prezzo`);
- altrimenti usa prezzo IVA inclusa (`PrezzoIvato`);
- se `InOfferta=1` e il prezzo promo e' valido/minore del prezzo base, usa `PrezzoPromo` o `PrezzoPromoIvato`;
- se il prezzo corrente non e' valido, usa il primo valore positivo fra prezzo ivato, prezzo netto, promo ivato, promo netto;
- se non esiste prezzo positivo, mostra `Prezzo su richiesta`;
- vecchio prezzo mostrato solo quando promo valida e inferiore al prezzo base;
- valuta/formato: `it-IT`, `C2`.

La ProductCard usa logiche affini ma non deve diventare fonte authoritative per il dettaglio.

## 7. Disponibilita

`BuildAvailabilityText()` calcola:

- `Giacenza - Impegnata > 0`: `Disponibile`;
- `Arrivo` / `arrivi` presente: `In arrivo: <testo compatto>`;
- `Disponibilita > 0`: `Disponibile su ordinazione`;
- `InOrdine > 0`: `In ordine`;
- altrimenti: `Verifica disponibilita`.

`BuildAvailabilityHtml()` assegna classi:

- `ks-availability-ok` per testo che contiene `Disponibile`;
- `ks-availability-wait` per arrivo/ordine;
- `ks-availability-check` negli altri casi.

Il testo disponibilita e' usato in area dati, buy box, informazioni, correlati/quick view e JSON-LD availability.

## 8. Immagini e gallery

Campi immagine:

- `Img1`
- `Img2`
- `Img3`
- `Img4`
- `Img5`
- `Img6`

`BindImages()`:

- normalizza ogni URL con `NormalizeImageUrl()`;
- deduplica immagini;
- usa `ThemeManager.PlaceholderProductImageUrl()` se mancano immagini;
- porta la lista a 6 immagini ripetendo la prima valida;
- binda `rptMainImages` e `rptThumbs`.

Path immagini prodotto:

- operativo: `/Public/assets/images/articoli/`;
- non versionare in massa questi asset;
- vecchi path o nomi file vengono normalizzati verso il path operativo quando possibile.

Gallery reale:

- markup principale: `#gallery-swiper-started`, `.ks-product-gallery-main`;
- thumbnail: `#thumbs-swiper-started`, `.ks-product-gallery-thumbs`;
- zoom: `.tf-image-zoom`, `data-zoom`, Drift;
- lightbox: PhotoSwipe con anchor `data-pswp-width` / `data-pswp-height`;
- script: `product-ui.js`, `keepstore-product.js`, PhotoSwipe modules, Swiper/Drift dal tema.

Requisiti futuri per `ProductDetailView`:

- non duplicare ID `gallery-swiper-started` / `thumbs-swiper-started` se la scheda reale resta in pagina;
- usare ID univoci o inizializzazione scoped;
- preservare fallback immagini e deduplica;
- non affidarsi a immagini versionate in Git sotto `Public/assets/images/articoli/`.

## 9. Varianti / TCid

La variante reale e' gestita da:

- `pnlVariants`
- `ddlTc`
- `ddlTc_SelectedIndexChanged`
- `LoadVariantOptions()`
- `BuildProductUrl()`

Comportamento:

- `Session("TC")` abilita la modalita varianti;
- se esiste piu di una variante, `ddlTc` e' visibile;
- cambio variante fa redirect a `articolo.aspx?id=<id>&TCid=<selected>`;
- `TCid=-1` resta il default storico di non-variante;
- `btnAddToCart_Click` rilegge/risolve il `TCid` effettivo prima del redirect carrello.

Gap attuale `ProductDetailView`:

- mostra solo testo descrittivo su varianti e `SelectedVariantTCId`;
- non contiene `DropDownList`;
- non gestisce autopostback o redirect;
- non preserva da sola il `TCid` operativo per il carrello.

## 10. Quantita e add-to-cart

Controlli reali:

- `txtQty`: quantita WebForms server-side;
- bottoni `data-ks-qty="minus/plus"`: stepper client-side;
- `btnAddToCart`: `LinkButton` server-side;
- `btnBundleAddToCart`: flusso bundle.

Validazioni:

- `NormalizeCartQuantity()` forza fallback 1, minimo 1, massimo 9999;
- `btnAddToCart_Click` ricarica il prodotto, risolve il `TCid`, imposta sessioni carrello e redirige.

Sessioni carrello impostate:

- `Session("ProdottoGratis")`
- `Session("Carrello_ArticoloId")`
- `Session("Carrello_TCId")`
- `Session("Carrello_Quantita")`
- `Session("Carrello_Pagina")`
- `Session("Carrello_SelezioneMultipla")`

Redirect:

- singolo prodotto: `aggiungi.aspx?id=<id>&TCid=<tcid>&qty=<qty>`;
- bundle: `aggiungi.aspx`.

Guardrail: non toccare `txtQty`, `ddlTc`, `btnAddToCart`, sessioni carrello o checkout nello stesso task di UI, salvo task dedicato e test espliciti.

## 11. Badge ricondizionato

Condizione:

- `Ricondizionato = 1`

Testo:

- mostra `Articolo ricondizionato`;
- aggiunge `NoteRicondizionato` se presente.

Asset corretto:

- `/Public/assets/images/img/refurbished.png`

Path da non usare:

- `/Public/assets/images/ico/refurbished.png`

Il path deve restare coerente con catalogo e home.

## 12. Tab e contenuti

Tab reali:

- `Spesso acquistati insieme`
- `Descrizione`
- `Informazioni prodotto`
- `Recensioni`

Contenuti:

- bundle con checkbox disabilitate e totale selezione;
- descrizione lunga sanificata;
- informazioni prodotto: categoria, marca, codice, EAN, disponibilita, prezzo, IVA;
- recensioni: media, distribuzione, lista, form recensione.

Nota recensioni:

- `BindProductReviews()` puo' creare/verificare tabella `articoli_recensioni`;
- `btnReviewSubmit_Click` inserisce recensioni;
- un futuro lavoro UI deve trattare recensioni come flusso separato, non come semplice markup.

## 13. Correlati, recenti e bundle

Sezioni reali:

- bundle/spesso acquistati insieme (`rptBundle`, `btnBundleAddToCart`);
- prodotti simili (`phSimilar`, `rptSimilar`);
- prodotti correlati (`phRelated`, `rptRelated`);
- brand strip (`phBrands`, `rptBrands`);
- visti di recente (`phRecentlyViewed`, `rptRecentlyViewed`).

Fonti/helper:

- `LoadPairRelation()`;
- `LoadManualRelated()`;
- `LoadSmartRelationFallback()`;
- `LoadSimilarProducts()`;
- `LoadCompanionProducts()`;
- `BindBrandCarousel()`;
- `BindRecentlyViewed()`;
- `TrackRecentlyViewed()`.

Le card correlate/recenti espongono `AddToCartUrl`, `WishlistUrl`, `QuickViewAttrs`, `CompareAttrs` e attributi `data-ks-*` per quick view/compare.

Gap preview:

- `ProductDetailView` non renderizza bundle, correlati, simili, recenti, brand strip o azioni card.

## 14. SEO/meta

SEO e meta sono gestiti dalla pagina parent tramite `ApplySeo()`.

Elementi gestiti:

- `Page.Title`;
- meta description;
- robots `index,follow`;
- canonical;
- Open Graph: `og:type`, `og:title`, `og:description`, `og:url`, `og:image`;
- JSON-LD `@graph` con Organization, WebSite, WebPage, BreadcrumbList, Product, Offer.

Il JSON-LD usa nome, descrizione, SKU/codice, EAN/GTIN, immagine, brand, prezzo, disponibilita e canonical.

Guardrail: finche non viene progettata una sostituzione SEO dedicata, `ApplySeo()` deve restare nella pagina parent e non va spostato dentro `ProductDetailView`.

## 15. Contratto minimo per ProductDetailView futura

| Area | Campo/proprieta richiesta | Fonte attuale | In IProductDetailView | In ProductDetailView | Criticita | Note |
| --- | --- | --- | --- | --- | --- | --- |
| Identity | ProductId | `ID`/`id` | No | No | Alta | Serve per carrello, review, data-ks e URL. |
| Identity | TCId | `TCid`, querystring | Si | Si | Alta | Oggi solo visuale nella preview. |
| Identity | ProductName | `Descrizione1`/fallback | Si | Si | Media | Usato anche come alt/SEO. |
| Identity | ProductCode | `Codice`/`SKU` | Si | Si | Media | Necessario in info e quick view. |
| Identity | Ean | `Ean`/`EAN` | Si | Si | Media | Necessario info/JSON-LD. |
| Identity | BrandName | `MarcheDescrizione`/`Marca` | Si | Si | Media | Manca link marca nella preview. |
| Identity | CategoryName | categorie/tipologie/settori | Si | Si | Media | Manca link categoria nella preview. |
| Pricing | PriceHtml | `BuildPriceHtml()` | Si | Si | Alta | HTML generato dalla pagina. |
| Pricing | CurrentPrice numeric | `PriceContext.CurrentPrice` | No | No | Alta | Serve per JSON-LD/compare e test. |
| Pricing | OldPriceText | `PriceContext.OldPrice` | Si | Si | Media | Solo testo. |
| Pricing | IvaLabel | `Session("IvaTipo")` | Si | Si | Media | Preview lo mostra. |
| Pricing | IsPromo | `InOfferta` + promo validi | Si | Si | Media | Preview indica solo promo attiva. |
| Availability | AvailabilityHtml | `BuildAvailabilityHtml()` | Si | Si | Alta | HTML condiviso. |
| Availability | AvailabilityText | `BuildAvailabilityText()` | No | No | Alta | Serve per aria, data-ks, JSON-LD. |
| Availability | Stock fields | `Giacenza`, `Impegnata`, `Disponibilita`, `InOrdine` | No | No | Alta | Necessari per logica/diagnostica. |
| Images/gallery | MainImageUrl | `Img1` normalizzata | Si | Si | Media | Preview mostra immagine semplice. |
| Images/gallery | GalleryImageUrls | `Img1..Img6` | Si | Si | Alta | Preview statica, senza gallery reale. |
| Images/gallery | Placeholder image | `ThemeManager.PlaceholderProductImageUrl()` | No | No | Media | Va preservato. |
| Images/gallery | Gallery ids/config | markup `articolo.aspx` | No | No | Alta | Evitare ID duplicati. |
| Variants | ShowVariants | `Session("TC")` + opzioni | Si | Si | Alta | Solo descrittivo nella preview. |
| Variants | SelectedVariantTCId | `ddlTc` / row `TCid` | Si | Si | Alta | Serve comportamento operativo. |
| Variants | VariantOptions | `LoadVariantOptions()` | No | No | Alta | Mancano opzioni UI/postback. |
| Add-to-cart | QuantityText | default/`txtQty` | Si | Si | Alta | Solo testo; manca input reale. |
| Add-to-cart | AddToCartEnabled | prodotto valido | Si | Si | Alta | Solo messaggio demo. |
| Add-to-cart | Cart event target | `btnAddToCart_Click` | No | No | Critica | Necessario prima di replace. |
| Add-to-cart | Cart session payload | sessioni carrello | No | No | Critica | Non duplicare senza task dedicato. |
| Descriptions/tabs | ShortDescriptionHtml | `Descrizione2`/`Sottotitolo` | Si | Si | Media | Preview non usa tab. |
| Descriptions/tabs | LongDescriptionHtml | HTML sanificato | Si | Si | Media | Preview lo mostra ma non come UI finale. |
| Descriptions/tabs | Info fields | categoria/marca/codice/EAN/prezzo/IVA/disponibilita | Parziale | Parziale | Media | Serve parita con tab reale. |
| Descriptions/tabs | Reviews | `articoli_recensioni` | No | No | Alta | Flusso DB separato. |
| Refurbished | IsRefurbished | `Ricondizionato` | Si | Si | Media | Preview testo, non asset finale. |
| Refurbished | RefurbishedText | `NoteRicondizionato` | Si | Si | Media | Path badge da preservare. |
| Related/recent | Similar/related items | helper relazioni | No | No | Alta | Mancano sezioni intere. |
| Related/recent | Recently viewed | cookie/session recenti | No | No | Media | Da decidere se fuori controllo o incluso. |
| Related/recent | Bundle items | `StoreBundleCartItems()` | No | No | Critica | Impatta carrello. |
| SEO | Title/meta/canonical/OG | `ApplySeo()` | No | No | Alta | Restare nella parent per ora. |
| SEO | JSON-LD | `BuildProductJsonLd()` | No | No | Alta | Non duplicare/spostare ora. |
| Mobile/JS | Swiper | `keepstore-product.js` + tema | No | No | Alta | Necessaria init scoped. |
| Mobile/JS | PhotoSwipe/Drift | `keepstore-product.js` | No | No | Alta | Preview non li usa. |
| Mobile/JS | Qty stepper | `data-ks-qty` | No | No | Alta | Collegato a input server. |

## 16. Guardrail futuri

- Non sostituire o nascondere `pnlProduct` senza flag locale/gated e rollback rapido.
- Non introdurre `ksProductDetailReplace=1` finche `ProductDetailView` resta demo.
- Non duplicare ID gallery (`gallery-swiper-started`, `thumbs-swiper-started`, `ks-product-thumbs-wrap`).
- Non rompere o rinominare `txtQty`, `ddlTc`, `btnAddToCart`, `btnBundleAddToCart`.
- Non spostare SEO/meta/JSON-LD fuori da `ApplySeo()` senza task dedicato.
- Non toccare carrello, checkout o pagamenti insieme alla sostituzione visuale.
- Non versionare asset prodotto sotto `Public/assets/images/articoli/`.
- Non introdurre nuove dipendenze JS/CSS per la preview senza task dedicato.
- Non usare la ProductCard come fonte dati authoritative della scheda prodotto.
- Mantenere sempre la scheda reale testabile senza querystring debug.

## 17. Prossimi step suggeriti

1. PDP-4: allineare `IProductDetailView` al data contract, solo proprieta/modello, senza UI operativa.
2. PDP-5: estendere `ProductDetailView` in parallelo, ancora gated locale, per coprire parita visuale senza carrello.
3. PDP-6: test browser locale della preview estesa su prodotto base, `TCid=-1`, variante reale, ricondizionato e mobile.
4. PDP-7: progettare varianti/add-to-cart server-side solo dopo parita visuale e contratto dati stabile.
5. PDP-8: valutare eventuale replace locale/gated con rollback, senza deploy globale.
