# KeepStore – STEP 2 Hardening (SQL / Output Encoding / CSRF)

Data: 2026-01-14

## Obiettivo di questo step
Hardening della pagina **articoli** con:
- mitigazioni **SQL injection** (escape robusto su input testuali usati nelle LIKE e cast/whitelist su ID numerici);
- miglioramenti **output encoding** in punti critici (testi su UI e attributi HTML/URL);
- protezione **CSRF** per i postback/state-changing actions tramite token legato a ViewStateUserKey.

Nota: questo step non completa ancora la refactor completa a query totalmente parameterized per tutti i DataSource (richiede un intervento più strutturale). L’obiettivo qui è un hardening incrementale “safe by default” senza rompere la logica esistente.

---

## Patch incluse in questo ZIP
### Nuovi file
- `App_Code/AntiCsrfPage.vb`  
  Base page anti-CSRF (ViewStateUserKey + token in cookie HttpOnly + validazione su postback).
- `App_Code/KeepStoreSecurity.vb`  
  Helper condivisi: HTML/attr/js/url encode, parsing int, escape LIKE MySQL.
- `articoli.security.vb`  
  Helper specifici per `articoli` (WhatsApp share URL e icon URL, correttamente url-encoded e attribute-safe).

### File modificati
- `articoli.aspx.vb`
  - `Inherits AntiCsrfPage` (abilita CSRF protection).
  - Hardening ricerca: **non** inserisce più input “raw” nelle LIKE; usa escape robusto `SqlEscapeLike(...)`.
  - `alert(...)`: ora usa `JavaScriptStringEncode`.
  - `PopulateFilterTCDropdownlist(...)`: cast numerico su ID per evitare injection tramite valori non numerici.
- `articoli.aspx`
  - Fix tag canonical (HTML valido).
  - Encoded output per `lblCategoria`.
  - WhatsApp share: URL generato con helper dedicato, url-encoded e attribute-safe.

---

## Checklist – cosa verificare dopo la pubblicazione
### 1) Regressioni funzionali
- [ ] Filtri (marche/tipologie/gruppo/sottogruppo/settore): selezione, reset, persistenza con querystring.
- [ ] Ricerca testuale (una parola e più parole).
- [ ] Taglia/Colore: dropdown popolati correttamente (se abilitati).
- [ ] Wishlist / “aggiungi a wishlist” da card prodotto.
- [ ] Paginazione grid.

### 2) SQL Injection (test pratici)
Eseguire test su querystring `?q=`:
- [ ] `?q=' OR 1=1 --` non deve rompere la pagina né ampliare i risultati “in modo anomalo”.
- [ ] `?q=%27%3B%20DROP%20TABLE%20...` non deve generare errori SQL.
- [ ] Log/stacktrace: non devono esporre SQL completi o connection string.

### 3) XSS / Output Encoding (test pratici)
- [ ] `?q=<img src=x onerror=alert(1)>` deve essere visualizzato come testo (escaped), senza esecuzione.
- [ ] Verificare che titoli/descrizioni in UI non “rompano” l’HTML se contengono caratteri speciali (', ", <, >, &).
- [ ] WhatsApp share: link funzionante e testo correttamente codificato.

### 4) CSRF
- [ ] Postback/azioni (es. add wishlist) funzionano normalmente.
- [ ] In caso di token mancante/mismatch su postback: deve emergere un errore “Anti-CSRF token validation failed” (meglio intercettarlo con una pagina d’errore custom e logging server-side).

---

## Prossimo step naturale (STEP 3)
Hardening **wishlist.aspx(.vb)** e **rettificaMagazzino.aspx(.vb)** con lo stesso pattern:
1) farle ereditare da `AntiCsrfPage`;
2) centralizzare HTML/Attr/JS encoding usando `KeepStoreSecurity`;
3) eliminare concatenazioni SQL con input non numerico, portando dove possibile a **query parameterizzate** (MySqlCommand + MySqlParameter);
4) audit di tutte le `Response.Write`, `Label.Text`, `NavigateUrl`, `href/src` costruite via string concat.

