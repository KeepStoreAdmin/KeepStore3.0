# Home Card Componentization Guardrails

## Scopo

Questo documento definisce lo stato attuale delle card prodotto della home e i guardrail per future modifiche o componentizzazioni.

La regola corrente e' conservativa: le card prodotto della home restano renderizzate inline da `Default.aspx.vb`. Non devono essere migrate direttamente a `ProductCard.ascx` o `ProductCardStatic.ascx` senza un task dedicato, una sezione pilota e una matrice test completa.

## Stato attuale home

La home `Default.aspx` usa markup editoriale e repeater WebForms. Il rendering delle card prodotto dinamiche e' centralizzato in helper inline di `Default.aspx.vb`, non in `ProductCard.ascx`.

Sezioni prodotto/dinamiche mappate:

| Sezione | Controllo | Rendering | Note |
| --- | --- | --- | --- |
| Featured products | `rptHomeFeaturedProducts` | `RenderGridCard(Container.DataItem)` | Griglia home con card `ks-grid-card`. |
| Offerte/deals | `rptDealOfDay` | `RenderDealCard(Container.DataItem)` | Slider Swiper con card `ks-deal-card`, mini-gallery, progress bar e countdown. |
| Legacy best seller | `rptBestSeller` | `RenderGridCard(Container.DataItem)` | Sezione legacy/condizionale con Swiper. |
| Recently viewed fallback server | `rptRecentlyViewed` | `RenderGridCard(Container.DataItem)` | Fallback server per prodotti visti di recente; convive con rendering client-side. |
| Legacy editorial row/big cards | repeater legacy `rptFeature*`, `rptToprate*`, `rptOnSale*` | `RenderRowCard(...)`, `RenderBigCard(...)` | Sezione legacy attualmente non principale, ma gli helper esistono ancora. |

Sezioni non-card o editoriali:

- hero e banner laterali;
- categorie principali;
- ricerca/assistente home;
- collection/promo/editorial links;
- brand slider;
- servizi/trust block.

Queste sezioni non devono essere confuse con le card prodotto dinamiche.

## Contratto dati card home

Le card inline della home usano dati prodotto reali caricati da `Default.aspx.vb`, con query principali su `vsuperarticoli` e join/aggregazioni ausiliarie per stock e venduto.

Campi e aree dati rilevanti:

| Area | Dati attuali |
| --- | --- |
| Identity | `id`, `TCid`, `Codice`, `Ean`. |
| Nome | `Descrizione1`, `Descrizione2`, normalizzati da helper come `ProductTitle(...)`. |
| Brand/categoria | `MarcheDescrizione`, `SettoriDescrizione`, `CategorieDescrizione`, `TipologieDescrizione`, `GruppiDescrizione`. |
| Prezzo/listino | `Prezzo`, `PrezzoIvato`, `PrezzoPromo`, `PrezzoPromoIvato`, listino corrente da sessione. |
| Promo | `InOfferta`, date offerta, listini offerta, quantita' minima, multipli, sconto/prezzo offerta. |
| Disponibilita' | `Giacenza`, `Disponibilita`, `Impegnata`, `VendutiAnno`, `QtaVenduta`. |
| Immagini | `Img1`, `Img2`, `Img3`, `Img4`; `Img1` e' primaria, gli altri campi alimentano mini-gallery quando disponibili. |
| Ricondizionato | `Ricondizionato` e stato prodotto, valutati dagli helper home. |
| URL | dettaglio prodotto tramite `ProductUrl(id)`. |
| Fallback immagine | gestito dagli helper immagine e dal placeholder tema quando il campo prodotto non e' valido. |

La home dipende anche da sessioni/preferenze gia' esistenti, per esempio listino e reverse charge. Una futura componentizzazione non deve cambiare il modo in cui questi dati vengono calcolati.

## Azioni card home

Le azioni delle card home sono generate inline da `RenderActionButtons(...)` e helper collegati.

Azioni attuali:

- link dettaglio prodotto verso `articolo.aspx`;
- add-to-cart tramite `cart_add.aspx`;
- wishlist tramite `wishlist_add.aspx`;
- quick view tramite `#quickView`;
- compare tramite `#compare`;
- attributi `data-ks-*` per popolare quick view, compare e dati azione client-side.

Attributi `data-ks-*` rilevanti:

- `data-ks-id`;
- `data-ks-tcid`;
- `data-ks-title`;
- `data-ks-brand`;
- `data-ks-category`;
- `data-ks-code`;
- `data-ks-url`;
- `data-ks-img`;
- `data-ks-price`;
- `data-ks-sold`;
- `data-ks-available`;
- `data-ks-progress`;
- `data-ks-cart-url`;
- `data-ks-description`.

Guardrail hard: non modificare add-to-cart, wishlist, quick view, compare, URL o `data-ks-*` senza un task dedicato e test browser. Queste azioni possono modificare stato utente/carrello o alimentare UI condivise con catalogo.

## Badge ricondizionato

Il badge ricondizionato della home deve restare coerente con catalogo e PDP.

Path corretto:

```text
/Public/assets/images/img/refurbished.png
```

Path vecchio da non usare:

```text
/Public/assets/images/ico/refurbished.png
```

Non introdurre nuovi asset immagine e non versionare immagini prodotto sotto `Public/assets/images/articoli/` in task applicativi.

## Confronto con ProductCard

`ProductCard.ascx` e' stabile nel catalogo e ha un contratto piu' centralizzato:

- proprieta' pubbliche per identity, prezzi, disponibilita', URL e immagini;
- modalita' demo/reale;
- azioni quick view, compare, wishlist e add-to-cart;
- attributi Bootstrap e `data-ks-*` piu' strutturati;
- controlli legacy opzionali tramite `EnableLegacyServerControls`;
- supporto a hidden field e quantita' nei percorsi catalogo.

Motivi per cui non e' una sostituzione diretta della home:

- la home ha layout specializzati (`ks-grid-card`, `ks-deal-card`, `ks-row-card`, `ks-big-card`);
- le card deal includono mini-gallery, countdown, progress bar e dati venduto/disponibile;
- le dimensioni card sono legate a Swiper e agli override CSS home;
- il catalogo ha vincoli WebForms e legacy diversi dalla home;
- una sostituzione diretta cambierebbe markup, dimensioni, azioni e potenzialmente ClientID/rendering.

Conclusione: `ProductCard.ascx` resta il componente catalogo. Non usarlo come drop-in replacement delle card home.

## Confronto con ProductCardStatic

`ProductCardStatic.ascx` e' un controllo demo/statico:

- immagini hardcoded;
- bottoni demo/disabilitati;
- nessun modello dati dinamico;
- nessun binding a `vsuperarticoli`;
- nessuna azione reale home/catalogo.

Puo' servire come riferimento visuale, ma non e' adatto alla home dinamica senza un refactor sostanziale. Trasformarlo in componente reale equivalerebbe di fatto a creare un nuovo componente.

## Rischi componentizzazione

Rischi principali da valutare prima di qualunque migrazione:

- regressioni Swiper su slider deals, best seller e recently viewed;
- cambi dimensioni card o altezza slide;
- hover/action overlay non allineati al layout home;
- rottura quick view o compare per dati `data-ks-*` incompleti;
- modifiche a add-to-cart/wishlist con impatti su carrello o stato utente;
- fallback immagini non coerente;
- badge refurbished duplicato, assente o con path errato;
- performance peggiorata se si caricano molti UserControl dinamici;
- ClientID WebForms e ID duplicati;
- collisioni CSS con catalogo/PDP;
- drift tra home e catalogo se si centralizza solo una parte del contratto;
- regressioni mobile a 390px/414px;
- test insufficienti su prodotto normale, promo, ricondizionato e senza immagine.

## Opzioni future

### A. Mantenere card home inline e documentare guardrail

Pro:

- rischio minimo;
- preserva il comportamento live stabile;
- evita impatti su catalogo, PDP, carrello e checkout;
- rollback immediato.

Contro:

- duplicazione rispetto a `ProductCard`;
- il contratto azioni home/catalogo puo' divergere nel tempo.

Rischio: basso.

Effort: basso.

Test necessari: smoke home desktop/mobile, quick view/compare se toccati, regressione catalogo/PDP se cambia CSS condiviso.

### B. Migrare una sezione pilota a ProductCardStatic

Pro:

- possibile esperimento visuale isolato.

Contro:

- `ProductCardStatic` non ha dati reali;
- bottoni e immagini sono demo;
- per usarlo davvero servirebbe refactor del controllo.

Rischio: medio se reso dinamico.

Effort: medio.

Test necessari: test visuale sezione pilota, verifica azioni disabilitate/assenti, smoke home.

### C. Migrare sezioni dinamiche a ProductCard

Pro:

- contratto piu' condiviso con catalogo;
- riduce duplicazione di azioni e markup nel lungo periodo.

Contro:

- alto rischio su layout home, Swiper, mobile e azioni;
- `ProductCard` e' pensata per catalogo, non per deal/home editoriali;
- possibile aumento complessita' WebForms e performance.

Rischio: alto.

Effort: alto.

Test necessari: home completa desktop/mobile, catalogo, PDP, quick view, compare, wishlist, add-to-cart, MiniCart, prodotto promo, ricondizionato, senza immagine.

### D. Creare nuovo HomeProductCard dedicato

Pro:

- mantiene layout e contratti specifici home;
- consente centralizzazione graduale;
- evita di piegare `ProductCard` catalogo a esigenze diverse;
- rollback piu' semplice se introdotto per una sola sezione pilota.

Contro:

- nuovo componente da progettare e mantenere;
- serve definire un data contract home esplicito;
- non elimina subito tutta la duplicazione.

Rischio: medio.

Effort: medio/alto.

Test necessari: sezione pilota, desktop/mobile, Swiper, quick view/compare, smoke catalogo/PDP, verifica nessun impatto su carrello/checkout.

### E. Non intervenire ora

Pro:

- nessun rischio tecnico immediato;
- la home resta stabile.

Contro:

- duplicazione e drift restano non governati;
- ogni fix futuro richiede attenzione manuale agli helper inline.

Rischio: basso nel breve periodo, medio nel lungo periodo.

Effort: nullo.

Test necessari: nessuno oltre ai normali smoke post-release.

## Raccomandazione

Scelta consigliata ora: A, mantenere le card home inline e usare questo documento come guardrail operativo.

Strada migliore futura, se la componentizzazione diventa prioritaria: D, progettare un nuovo `HomeProductCard` dedicato e provarlo su una sola sezione pilota.

Non procedere ora con migrazione diretta a `ProductCard.ascx` o `ProductCardStatic.ascx`.

## Guardrail operativi

Per task futuri sulla home:

- non toccare catalogo mentre si lavora sulle card home;
- non toccare PDP nello stesso task;
- non modificare checkout o pagamenti;
- non modificare add-to-cart o wishlist senza task dedicato;
- non cambiare query/datasource insieme al markup;
- non cambiare `cart_add.aspx`, `wishlist_add.aspx`, quick view, compare o `data-ks-*` senza test dedicati;
- non versionare asset prodotto sotto `Public/assets/images/articoli/`;
- mantenere il path refurbished corretto;
- mantenere CSS scoped a `body.ks-page-home` quando possibile;
- testare desktop e mobile;
- testare quick view e compare se le card o gli attributi azione cambiano;
- fare smoke catalogo e PDP dopo interventi CSS/JS home;
- mantenere rollback rapido, preferibilmente con una sezione pilota e flag/visibilita' controllata.

## Prossimi step suggeriti

Possibili prossimi micro-task:

- `FRONT-HOME-10 - Decide HomeProductCard pilot scope`
- `FRONT-HOME-10 - Close home block summary`

La scelta dipende dalla priorita': se serve ridurre duplicazione, preparare un pilot scope per `HomeProductCard`; se il blocco home e' considerato stabile, chiudere con una sintesi dello stato e dei guardrail.
