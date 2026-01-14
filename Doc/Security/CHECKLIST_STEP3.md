# Checklist STEP 3 - Verifiche (post patch)

## Wishlist
- [ ] Accesso anonimo -> redirect login (https).
- [ ] Lista prodotti: immagini, promo/non promo.
- [ ] Nessun errore MySql quando un prodotto non ha promo.
- [ ] Log query_string: non deve registrare entità HTML rotte.

## Rettifica Magazzino (solo gestore)
- [ ] Accesso senza GestoreId -> 403 o redirect login.
- [ ] Ricerca `q` (1 parola / più parole) -> risultati coerenti.
- [ ] Ricerca con caratteri speciali (%, _, \) -> nessun errore SQL e risultati sensati.
- [ ] Filtri (ct/mr/tp/gr/sg/st/dispo/spedgratis) -> coerenti.
- [ ] ViewState postback -> funziona (AntiCsrfPage).
- [ ] UI: “Risultati per …” non esegue HTML/JS (XSS).

## Log/Sicurezza
- [ ] Verifica IIS log + MySql log per eventuali 500/timeout.
- [ ] Verifica che gli header di sicurezza non rompano risorse (frame/iframe se usati).
