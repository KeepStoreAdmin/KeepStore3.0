# KeepStore STEP 3 - Hardening (wishlist + rettificaMagazzino)

Data: 2026-01-14

## Obiettivo
Continuazione dell’hardening richiesto (SQL injection / output encoding / CSRF) sulle pagine:
- `wishlist.aspx.vb`
- `rettificaMagazzino.aspx.vb`

## Cosa cambia (sintesi)
### 1) CSRF
- Entrambe le pagine ora ereditano da `AntiCsrfPage` (ViewStateUserKey + token su postback, lato server).

### 2) Security headers + HTTPS
- Aggiunte chiamate a `KeepStoreSecurity.AddSecurityHeaders(Response)` e `KeepStoreSecurity.RequireHttps(Request, Response)`.

### 3) SQL injection
- `wishlist.aspx.vb`: `controlla_promo_articolo()` ora usa query parametrizzata (niente concatenazioni).
- `rettificaMagazzino.aspx.vb`: ricerca `q` trasformata in token parametrizzati (`@w0..@wN`) con `LIKE ... ESCAPE '\'` e valori in `SelectParameters`.
- `rettificaMagazzino.aspx.vb`: rimosse concatenazioni di session IVA nel `strSelect` introducendo `@iva` e `@ivaRC` + parametri.

### 4) Output encoding (anti-XSS)
- `rettificaMagazzino.aspx.vb`: `lblRisultati` e `titolo_pagina` ora ricevono testo passato da `HtmlEncode`.

### 5) Authorization gate (rettificaMagazzino)
- Accesso negato se manca `Session("GestoreId")` o se è <= 0.

## File inclusi
- `App_Code/KeepStoreSecurity.vb` (esteso con helper: NormalizeSearchTerm/TokenizeSearch/EscapeLikeValue/SafeFileName)
- `App_Code/AntiCsrfPage.vb`
- `wishlist.aspx.vb`
- `rettificaMagazzino.aspx.vb`

## Note operative
- Patch incrementale: sostituisci i file omonimi nel progetto mantenendo i path.
- Ricompila e fai smoke-test: ricerca, filtri, aggiunta/rimozione wishlist, rettifica magazzino, paginazione.
