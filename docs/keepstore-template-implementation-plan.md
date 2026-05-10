# KeepStore - Piano applicazione template e-commerce

## Decisione ufficiale template

Template base da seguire:

- HOME: Home 1
- SHOP LAYOUT:
  - shop-default
  - shop-cart
- WOO PAGE:
  - Compare
  - Wishlist
  - Check Out
  - Order Detail
  - Track Your Order
  - My Account
- PRODUCT LAYOUTS:
  - Product Detail
- PRODUCT DETAILS:
  - Product Inner Zoom

## Decisione esplicita

- Nessuna migrazione a Home 3.
- Home 3 non e' la base di lavoro.
- Eventuali elementi simili a Home 3 non devono essere interpretati come cambio direzione.
- La direzione ufficiale e' Home 1.

## Strategia di applicazione

- Applicazione progressiva e controllata su KeepStore.
- Nessuna sostituzione totale di pagina senza micro-task dedicato.
- Ogni area deve essere migrata con branch piccoli, test browser e PR verso `frontend-rebuild`.
- `main` non deve essere toccato fino a validazione finale.
- Ogni pagina deve mantenere logiche esistenti: listini, IVA, promo, TCId, carrello, login, checkout, ordini, SEO e query.

## Mappatura KeepStore

Home KeepStore:

- riferimento template: Home 1
- file principali:
  - `Default.aspx`
  - `Default.aspx.vb`
  - `Page.master`
  - `Public/ui/controls/HomeIconBoxes.ascx`
  - controlli home/banner/categorie/prodotti gia' presenti

Catalogo/lista prodotti:

- riferimento template: shop-default
- file principali:
  - `articoli.aspx`
  - `articoli.aspx.vb`
  - `Public/ui/controls/ProductCard.ascx`
  - `Public/ui/controls/ProductCard.ascx.vb`

Carrello:

- riferimento template: shop-cart
- file principali da identificare/verificare nel relativo micro-task

Compare:

- riferimento template: Compare
- file principali da identificare/verificare nel relativo micro-task

Wishlist:

- riferimento template: Wishlist
- file principali da identificare/verificare nel relativo micro-task

Checkout:

- riferimento template: Check Out
- file principali da identificare/verificare nel relativo micro-task

Order Detail:

- riferimento template: Order Detail
- file principali da identificare/verificare nel relativo micro-task

Track Your Order:

- riferimento template: Track Your Order
- file principali da identificare/verificare nel relativo micro-task

My Account:

- riferimento template: My Account
- file principali da identificare/verificare nel relativo micro-task

Scheda prodotto:

- riferimento template:
  - Product Detail
  - Product Inner Zoom
- file principali:
  - `articolo.aspx`
  - `articolo.aspx.vb`
  - `Public/ui/controls/ProductDetailView.ascx`
  - `Public/ui/controls/ProductDetailView.ascx.vb`
  - `App_Code/IProductDetailView.vb`

## Regole operative

- Base branch di lavoro: `frontend-rebuild`.
- PR sempre verso `frontend-rebuild`.
- Non aprire PR verso `main` durante la fase di sviluppo.
- `main` resta stabile.
- Ogni micro-task deve indicare:
  - file modificati;
  - file non toccati;
  - aree funzionali escluse;
  - test browser eseguiti;
  - esito precompilazione se applicabile.

## Priorita' di lavoro

1. Home 1
2. shop-default catalogo
3. Product Detail / Product Inner Zoom
4. shop-cart
5. Check Out
6. My Account
7. Wishlist
8. Compare
9. Order Detail
10. Track Your Order
11. Header/footer/mobile/SEO finale
