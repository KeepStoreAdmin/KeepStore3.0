# ProductCard release checklist

Documento operativo per decidere quando attivare la nuova `ProductCard.ascx` nel catalogo prodotti.

Stato intenzionale:

- [x] La nuova ProductCard e' pronta tecnicamente per test gated.
- [x] La flag `UseNewCatalogProductCard` resta disattivata di default.
- [x] L'attivazione reale richiede approvazione finale.
- [x] Il rollback immediato consiste nel mantenere o riportare `UseNewCatalogProductCard=False`.

## 1. Stato branch e perimetro

- [x] Branch di checklist: `task/catalog-product-card-release-checklist`.
- [x] La checklist e' documentale.
- [x] Nessuna modifica applicativa prevista da questo documento.
- [x] Nessun merge su `main` previsto da questa checklist.
- [ ] Verificare prima del rilascio che il branch candidato includa tutti i commit ProductCard approvati.
- [ ] Verificare che il branch candidato sia pulito prima dell'eventuale attivazione.

## 2. Stato tecnico attuale ProductCard

- [x] `ProductCard.ascx` esiste come UserControl riutilizzabile.
- [x] `ProductCard.ascx.vb` espone proprieta' pubbliche per dati catalogo.
- [x] La card supporta modalita' demo e modalita' reale.
- [x] La card supporta controlli legacy opzionali tramite `EnableLegacyServerControls`.
- [x] Gli helper di `articoli.aspx.vb` sono predisposti per leggere anche da ProductCard.
- [x] La sostituzione card e' stata introdotta con modalita' gated.
- [x] Resa catalogo/ProductCard verificata sui test browser eseguiti.
- [ ] Verificare scenari gestionali completi prima dell'attivazione globale.

## 3. Funzionalita' gia' validate

- [x] Preview demo gated con parametro debug.
- [x] Preview reale gated con parametro debug.
- [x] Replace di una card gated.
- [x] Replace di N card gated, con massimo iniziale 3.
- [x] `ksCardReplaceCount=1` validato.
- [x] `ksCardReplaceCount=3` validato.
- [x] `ksCardReplaceCount=99` validato con limite massimo 3.
- [x] `ksCardReplaceCount=abc` validato con nessuna sostituzione.
- [x] Replace all gated tramite parametro debug.
- [x] Feature flag `True` testata su branch separato.
- [x] Catalogo normale con flag `False` invariato.
- [x] Carrello rapido validato.
- [x] Wishlist validata.
- [x] Quick view validata.
- [x] Compare validato.
- [x] Quantita' validata.
- [x] Multiselezione validata.
- [x] Filtri validati.
- [x] Ordinamento validato.
- [x] Paginazione validata.
- [x] Mobile/responsive validato.
- [x] Console browser senza errori.
- [x] Feature flag interna aggiunta con default disattivato.
- [x] Precompilazione ASP.NET eseguita con esito positivo nei micro-task precedenti.
- [ ] Validazione completa con utente loggato, listino, IVA, promo, disponibilita' e ordine.

## 4. Funzionalita' ancora gated

- [x] `ksCardPreview=1` resta solo debug.
- [x] `ksCardPreviewReal=1` resta solo debug.
- [x] `ksCardReplaceOne=1` resta solo debug.
- [x] `ksCardReplaceCount=N` resta solo debug.
- [x] `ksCardReplaceAll=1` resta solo debug.
- [x] `UseNewCatalogProductCard` resta `False`.
- [x] Branch separato con flag `True` usato solo per test.
- [ ] Attivazione reale senza parametri debug.

## 5. Feature flag UseNewCatalogProductCard

- [x] Flag presente in `articoli.aspx.vb`.
- [x] Valore default richiesto: `False`.
- [x] Con valore `False`, catalogo normale invariato.
- [x] Con valore `True`, comportamento equivalente al replace all interno.
- [x] I parametri debug hanno priorita' sulla feature flag.
- [x] Le preview hanno priorita' assoluta.
- [ ] Attivare solo dopo approvazione finale.

## 6. Checklist catalogo anonimo

- [x] Aprire `articoli.aspx` da utente anonimo.
- [x] Verificare lista prodotti.
- [x] Verificare immagini prodotto.
- [x] Verificare prezzi base visualizzati.
- [x] Verificare link dettaglio.
- [x] Verificare carrello rapido da anonimo.
- [x] Verificare nessun errore JavaScript in console.

## 7. Checklist catalogo utente loggato

- [ ] Eseguire login con utente cliente.
- [ ] Aprire `articoli.aspx`.
- [ ] Verificare lista prodotti.
- [ ] Verificare prezzi coerenti con utente.
- [ ] Verificare carrello rapido.
- [ ] Verificare wishlist.
- [ ] Verificare logout e ritorno a comportamento anonimo.

## 8. Checklist listini cliente

- [x] Verificare listino default.
- [ ] Verificare listino utente loggato.
- [ ] Verificare listino cliente speciale, se disponibile.
- [ ] Verificare cambio listino dopo login.
- [ ] Verificare prodotto con prezzo normale.
- [ ] Verificare prodotto con prezzo promozionale.
- [ ] Verificare assenza di prezzi in formato non coerente.

## 9. Checklist promo/offerte

- [x] Verificare prodotto non in offerta.
- [x] Verificare prodotto in offerta valida in scenario base.
- [ ] Verificare prodotto con offerta scaduta.
- [ ] Verificare prezzo barrato solo se promo reale.
- [ ] Verificare badge promo solo se coerente.
- [ ] Verificare nessuna promo duplicata o inventata.
- [ ] Verificare promo con data inizio/fine.
- [ ] Verificare promo con quantita' minima.
- [ ] Verificare promo con multipli.

## 10. Checklist IVA, reverse charge, esenzione

- [x] Verificare prezzo ivato standard in scenario base.
- [ ] Verificare cliente con IVA diversa.
- [ ] Verificare utente con reverse charge, se disponibile.
- [ ] Verificare utente con esenzione IVA, se disponibile.
- [ ] Verificare coerenza tra catalogo, dettaglio e carrello.
- [ ] Verificare nessun formato prezzo anomalo.

## 11. Checklist disponibilita', giacenza, impegnato, arrivi

- [x] Verificare visualizzazione disponibilita' base.
- [ ] Verificare prodotto disponibile con disponibilita' numerica.
- [ ] Verificare prodotto non disponibile con disponibilita' numerica.
- [ ] Verificare disponibilita' con solo logo disponibile/non disponibile.
- [ ] Verificare prodotto con giacenza bassa.
- [ ] Verificare prodotto impegnato.
- [ ] Verificare prodotto in ordine.
- [ ] Verificare prodotto in arrivo.
- [ ] Verificare testo disponibilita' nella card.
- [ ] Verificare CSS disponibilita' nella card.

## 12. Checklist TCId, taglie, colori

- [x] Verificare prodotto senza variante in scenario base.
- [ ] Verificare prodotto con `TCId` reale.
- [ ] Verificare fallback `TCId=-1` dove previsto.
- [ ] Verificare link carrello con TCId corretto.
- [ ] Verificare wishlist con TCId corretto.
- [ ] Verificare nessun duplicato causato da varianti.

## 13. Checklist carrello rapido

- [x] Verificare click carrello rapido da card.
- [x] Verificare URL carrello generato.
- [x] Verificare `ArticoliId` corretto nello scenario testato.
- [x] Verificare `TCId` nello scenario testato.
- [x] Verificare quantita' corretta nello scenario testato.
- [x] Verificare prodotto visibile in carrello nello scenario testato.
- [x] Verificare MiniCart/header count nello scenario testato.
- [ ] Ripetere carrello rapido con utente loggato e listino cliente.

## 14. Checklist quantita'

- [x] Verificare quantita' default 1.
- [x] Verificare modifica quantita' nella card.
- [x] Verificare quantita' usata dal carrello rapido.
- [x] Verificare normalizzazione valori non validi nello scenario testato.
- [x] Verificare postback senza perdita quantita' nello scenario testato.

## 15. Checklist multiselezione

- [x] Verificare checkbox multiselezione su card inline.
- [x] Verificare checkbox multiselezione su ProductCard.
- [x] Verificare aggiunta multipla con prodotti misti nello scenario testato.
- [x] Verificare quantita' per ogni prodotto selezionato nello scenario testato.
- [x] Verificare TCId per ogni prodotto selezionato nello scenario testato.
- [x] Verificare nessun prodotto non selezionato nel carrello nello scenario testato.
- [ ] Ripetere multiselezione con TCId reale e listino cliente.

## 16. Checklist wishlist

- [x] Verificare wishlist nello scenario testato.
- [ ] Verificare wishlist da anonimo, se prevista.
- [ ] Verificare wishlist da loggato.
- [x] Verificare `ArticoliId` corretto nello scenario testato.
- [x] Verificare `TCId` corretto nello scenario testato.
- [x] Verificare nessun doppio inserimento non previsto nello scenario testato.
- [x] Verificare feedback UI nello scenario testato.

## 17. Checklist quick view

- [x] Verificare apertura quick view.
- [x] Verificare immagine.
- [x] Verificare nome prodotto.
- [x] Verificare codice.
- [x] Verificare prezzo.
- [x] Verificare disponibilita' nello scenario testato.
- [x] Verificare carrello rapido dalla quick view, se previsto.

## 18. Checklist compare

- [x] Verificare aggiunta compare.
- [x] Verificare assenza duplicati.
- [x] Verificare dati minimi prodotto.
- [x] Verificare offcanvas/pannello compare.
- [x] Verificare persistenza client-side.
- [x] Verificare rimozione compare.

## 19. Checklist filtri

- [x] Verificare filtro categoria.
- [x] Verificare filtro sottogruppo.
- [x] Verificare filtro marca.
- [x] Verificare filtro tipologia.
- [x] Verificare combinazione filtri.
- [x] Verificare rimozione singolo filtro.
- [x] Verificare pulizia tutti i filtri.

## 20. Checklist ordinamento

- [x] Verificare ordinamento default.
- [x] Verificare ordinamento prezzo crescente.
- [x] Verificare ordinamento prezzo decrescente.
- [x] Verificare ordinamento nome.
- [x] Verificare ordinamento disponibilita', se previsto.
- [x] Verificare persistenza ordinamento con filtri.

## 21. Checklist paginazione

- [x] Verificare prima pagina.
- [x] Verificare pagina successiva.
- [x] Verificare pagina precedente.
- [x] Verificare ultima pagina.
- [x] Verificare card dopo cambio pagina.
- [x] Verificare postback e ViewState nello scenario testato.

## 22. Checklist mobile/responsive

- [x] Verificare desktop largo.
- [x] Verificare notebook.
- [x] Verificare tablet.
- [x] Verificare mobile 414.
- [x] Verificare mobile 390.
- [x] Verificare mobile 360.
- [x] Verificare nessun overflow orizzontale nello scenario testato.
- [x] Verificare bottoni card cliccabili.
- [x] Verificare immagini proporzionate.
- [ ] Ripetere test su browser multipli.

## 23. Checklist SEO/link prodotto

- [x] Verificare link immagine verso scheda prodotto.
- [x] Verificare link titolo verso scheda prodotto.
- [x] Verificare URL prodotto corretto nello scenario testato.
- [x] Verificare parametri necessari nello scenario testato.
- [x] Verificare attributi alt immagini nello scenario testato.
- [x] Verificare nessun link vuoto nello scenario testato.

## 24. Checklist performance

- [x] Verificare performance percepita nello scenario testato.
- [ ] Misurare tempo render catalogo con card inline.
- [ ] Misurare tempo render catalogo con ProductCard.
- [ ] Verificare peso HTML.
- [ ] Verificare immagini lazyload.
- [x] Verificare assenza query duplicate introdotte dalla sostituzione card.
- [x] Verificare assenza DataBind manuali extra.
- [x] Verificare console JavaScript pulita.
- [ ] Test performance con molte righe per pagina.

## 25. Piano rollback

- [x] Rollback immediato: mantenere o riportare `UseNewCatalogProductCard=False`.
- [x] I parametri debug restano manuali e non attivano produzione.
- [x] La card inline legacy resta nel markup.
- [x] Nessuna modifica database necessaria per rollback.
- [x] Nessuna modifica `web.config` necessaria per rollback.
- [x] Verificare branch e commit di rollback logico prima del rilascio.

## 26. Criteri per attivare ProductCard

- [x] Test catalogo anonimo superati nello scenario validato.
- [ ] Tutti i test catalogo loggato superati.
- [ ] Prezzi/listini/IVA verificati.
- [ ] Disponibilita' e TCId verificati.
- [x] Carrello rapido verificato nello scenario validato.
- [x] Wishlist, quick view e compare verificati nello scenario validato.
- [x] Filtri, ordinamento e paginazione verificati nello scenario validato.
- [x] Mobile/responsive approvato nello scenario validato.
- [ ] Performance accettabile su dataset esteso.
- [ ] Approvazione finale ricevuta.

## 27. Criteri per NON attivare ProductCard

- [x] Prezzi non coerenti con catalogo legacy: criterio bloccante da mantenere.
- [x] Carrello rapido non affidabile: criterio bloccante da mantenere.
- [x] Quantita' o multiselezione instabili: criterio bloccante da mantenere.
- [x] Wishlist/quick view/compare con regressioni: criterio bloccante da mantenere.
- [x] Filtri o paginazione alterati: criterio bloccante da mantenere.
- [ ] Problemi con listini cliente.
- [ ] Problemi con IVA/reverse charge/esenzione.
- [ ] Layout mobile non approvato.
- [ ] Performance peggiorata in modo significativo.
- [ ] Mancanza di approvazione finale.

## 28. Esito finale e approvazione

- [ ] Checklist completata.
- [ ] Esito tecnico approvato.
- [ ] Esito UX approvato.
- [ ] Esito commerciale approvato.
- [ ] Piano rollback confermato.
- [ ] Decisione finale: attivare `UseNewCatalogProductCard=True`.
- [ ] Decisione finale: mantenere `UseNewCatalogProductCard=False`.

## 29. Decisione attuale

- [x] ProductCard tecnicamente validata.
- [x] Attivazione globale non ancora approvata.
- [x] `UseNewCatalogProductCard` deve restare `False` su `frontend-rebuild`.
- [x] Prossimo passo: test finale con utente loggato, listino, IVA, promo, disponibilita' e ordine.
- [x] Rollback: mantenere o riportare `UseNewCatalogProductCard=False`.

