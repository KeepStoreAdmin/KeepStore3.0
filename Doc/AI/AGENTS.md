# PACCHETTO 1 – HEADER, MENU CATALOGO, TOP BAR, SEARCH  
**Istruzioni operative per l’agente CODEX AI**

---

## 🎯 OBIETTIVO
Stabilizzare il foundation layer della HOME e dell’header senza intervenire sui blocchi prodotto della HOME, salvo i punti strettamente necessari per coerenza markup/hook.

Il pacchetto deve rendere corretti e coerenti:

- Top bar  
- Header  
- Ricerca desktop/mobile  
- Catalog navigation desktop/mobile  
- Compare / wishlist / cart hooks nell’header  
- Coerenza classi CSS/JS con il template  
- Nessuna regressione sui binding WebForms  

---

## 📄 PRIMA LEGGI QUESTI FILE

- `Page.master`  
- `Page.master.vb`  
- `SiteHeader.ascx`  
- `SiteHeader.ascx.vb`  
- `HomeDepartmentsMenu.ascx`  
- `HomeDepartmentsMenu.ascx.vb`  
- `CatalogMenuProvider.vb`  
- `search_suggest.aspx.vb`  
- `articoli.aspx`  
- `articoli.aspx.vb`  
- `Public/assets/keepstore/theme-overrides.css`  
- `Public/assets/keepstore/home-default.js`  
- `Public/assets/keepstore/ks-page-flags.js`  
- Pagina sorgente Onsus usata per header/menu/search mobile  
- CSS Onsus relativo a:  
  - `tf-nav-menu`  
  - `submenu`  
  - `mobile offcanvas`  
  - `compare hooks`  

---

## ⚙️ REGOLE TECNICHE

### 1) Menu catalogo
- Non inventare nulla.  
- Trapianta il markup Onsus reale per:  
  - `tf-nav-menu`  
  - `menu-category-list`  
  - `sub-menu-container`  
  - struttura mobile offcanvas/collapse  

### 2) Provider catalogo
- Deve essere **unico**.  
- Usato sia da `SiteHeader` sia da `HomeDepartmentsMenu`.

### 3) Dati catalogo
- Solo settori con `Abilitato = 1`.  
- Ordine:  
  - `Predefinito DESC`  
  - `Ordinamento ASC`  
  - `Descrizione ASC`  
- Immagine settore:  
  `/Public/assets/images/settori/ + settori.img`

### 4) Gerarchia desktop/mobile
- `settore > categoria > tipologia`  
- `gruppo` solo se realmente presente e richiesto dalla UI  
- Nessuna gerarchia inventata

### 5) Top bar
- Telefono da `aziende`  
- Promo spedizione da `vettori.Promo` e `vettori.CostoMinimo`  
- Valuta: `EUR` fisso  
- Lingua: `IT` default, `EN` solo se esiste davvero il meccanismo previsto  

### 6) Ricerca
- Ranking coerente tra suggest e risultati finali  
- Ordine match:  
  1. codice/EAN esatto  
  2. inizio parola  
  3. contenuto  
  4. marca + descrizione  
- Preview immagine se disponibile  
- Recenti solo client-side  
- Redirect coerente verso `articoli.aspx`

### 7) Compare / wishlist / cart
- Non inventare classi custom  
- Usare gli hook del template Onsus  
- Il flusso server-side deve restare quello KeepStore  

### 8) `theme-overrides.css`
- Solo override **scoped**  
- No reset globali aggressivi  
- No alterazioni tipografiche generali  

### 9) `Page.master` / `Page.master.vb`
- Verificare che header/menu non vengano popolati due volte  
- Eliminare solo wiring duplicato o legacy in conflitto  

---

## ✅ CRITERI DI ACCETTAZIONE

- **Desktop:** il menu catalogo si apre lateralmente, non resta chiuso nel box  
- **Mobile:** il menu usa struttura e comportamento del template Onsus  
- Top bar mostra dati reali da DB  
- Ricerca desktop e mobile seguono gli stessi criteri logici  
- Nessun placeholder hardcoded residuo  
- Nessun file nuovo non autorizzato  
- ZIP finale pronto al copia/incolla  

---

## 📦 OUTPUT FINALE RICHIESTO

A. File letti  
B. File modificati  
C. Classi/hook Onsus realmente trapiantati  
D. Query/binding dati cambiati  
E. Test eseguiti  
F. Rischi residui  
G. ZIP finale  
