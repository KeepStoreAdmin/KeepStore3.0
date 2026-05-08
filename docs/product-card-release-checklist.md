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
- [ ] Verificare visualmente la resa finale su catalogo reale.

## 3. Funzionalita' gia' validate

- [x] Preview demo gated con parametro debug.
- [x] Preview reale gated con parametro debug.
- [x] Replace di una card gated.
- [x] Replace di N card gated, con massimo iniziale 3.
- [x] Replace all gated tramite parametro debug.
- [x] Feature flag interna aggiunta con default disattivato.
- [x] Precompilazione ASP.NET eseguita con esito positivo nei micro-task precedenti.
- [ ] Validazione browser completa su dati live.

## 4. Funzionalita' ancora gated

- [x] `ksCardPreview=1` resta solo debug.
- [x] `ksCardPreviewReal=1` resta solo debug.
- [x] `ksCardReplaceOne=1` resta solo debug.
- [x] `ksCardReplaceCount=N` resta solo debug.
- [x] `ksCardReplaceAll=1` resta solo debug.
- [x] `UseNewCatalogProductCard` resta `False`.
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

- [ ] Aprire `articoli.aspx` da utente anonimo.
- [ ] Verificare lista prodotti.
- [ ] Verificare immagini prodotto.
- [ ] Verificare prezzi.
- [ ] Verificare link dettaglio.
- [ ] Verificare carrello rapido da anonimo.
- [ ] Verificare nessun errore JavaScript.

## 7. Checklist catalogo utente loggato

- [ ] Eseguire login con utente cliente.
- [ ] Aprire `articoli.aspx`.
- [ ] Verificare lista prodotti.
- [ ] Verificare prezzi coerenti con utente.
- [ ] Verificare carrello rapido.
- [ ] Verificare wishlist.
- [ ] Verificare logout e ritorno a comportamento anonimo.

## 8. Checklist listini cliente

- [ ] Verificare listino default.
- [ ] Verificare listino utente loggato.
- [ ] Verificare listino cliente speciale, se disponibile.
- [ ] Verificare prodotto con prezzo normale.
- [ ] Verificare prodotto con prezzo promozionale.
- [ ] Verificare assenza di prezzi in formato non coerente.

## 9. Checklist promo/offerte

- [ ] Verificare prodotto non in offerta.
- [ ] Verificare prodotto in offerta valida.
- [ ] Verificare prodotto con offerta scaduta.
- [ ] Verificare prezzo barrato solo se promo reale.
- [ ] Verificare badge promo solo se coerente.
- [ ] Verificare nessuna promo duplicata o inventata.

## 10. Checklist IVA, reverse charge, esenzione

- [ ] Verificare prezzo ivato standard.
- [ ] Verificare utente con reverse charge, se disponibile.
- [ ] Verificare utente con esenzione IVA, se disponibile.
- [ ] Verificare coerenza tra catalogo, dettaglio e carrello.
- [ ] Verificare nessun formato prezzo anomalo.

## 11. Checklist disponibilita', giacenza, impegnato, arrivi

- [ ] Verificare prodotto disponibile.
- [ ] Verificare prodotto non disponibile.
- [ ] Verificare prodotto con giacenza bassa.
- [ ] Verificare prodotto impegnato.
- [ ] Verificare prodotto in arrivo.
- [ ] Verificare testo disponibilita' nella card.
- [ ] Verificare CSS disponibilita' nella card.

## 12. Checklist TCId, taglie, colori

- [ ] Verificare prodotto senza variante.
- [ ] Verificare prodotto con `TCId` reale.
- [ ] Verificare fallback `TCId=-1` dove previsto.
- [ ] Verificare link carrello con TCId corretto.
- [ ] Verificare wishlist con TCId corretto.
- [ ] Verificare nessun duplicato causato da varianti.

## 13. Checklist carrello rapido

- [ ] Verificare click carrello rapido da card.
- [ ] Verificare URL carrello generato.
- [ ] Verificare `ArticoliId` corretto.
- [ ] Verificare `TCId` corretto.
- [ ] Verificare quantita' corretta.
- [ ] Verificare prodotto visibile in carrello.
- [ ] Verificare MiniCart/header count.

## 14. Checklist quantita'

- [ ] Verificare quantita' default 1.
- [ ] Verificare modifica quantita' nella card.
- [ ] Verificare quantita' usata dal carrello rapido.
- [ ] Verificare normalizzazione valori non validi.
- [ ] Verificare postback senza perdita quantita'.

## 15. Checklist multiselezione

- [ ] Verificare checkbox multiselezione su card inline.
- [ ] Verificare checkbox multiselezione su ProductCard.
- [ ] Verificare aggiunta multipla con prodotti misti.
- [ ] Verificare quantita' per ogni prodotto selezionato.
- [ ] Verificare TCId per ogni prodotto selezionato.
- [ ] Verificare nessun prodotto non selezionato nel carrello.

## 16. Checklist wishlist

- [ ] Verificare wishlist da anonimo, se prevista.
- [ ] Verificare wishlist da loggato.
- [ ] Verificare `ArticoliId` corretto.
- [ ] Verificare `TCId` corretto.
- [ ] Verificare nessun doppio inserimento non previsto.
- [ ] Verificare feedback UI.

## 17. Checklist quick view

- [ ] Verificare apertura quick view.
- [ ] Verificare immagine.
- [ ] Verificare nome prodotto.
- [ ] Verificare codice.
- [ ] Verificare prezzo.
- [ ] Verificare disponibilita'.
- [ ] Verificare carrello rapido dalla quick view, se previsto.

## 18. Checklist compare

- [ ] Verificare aggiunta compare.
- [ ] Verificare assenza duplicati.
- [ ] Verificare dati minimi prodotto.
- [ ] Verificare offcanvas/pannello compare.
- [ ] Verificare persistenza client-side.
- [ ] Verificare rimozione compare.

## 19. Checklist filtri

- [ ] Verificare filtro categoria.
- [ ] Verificare filtro sottogruppo.
- [ ] Verificare filtro marca.
- [ ] Verificare filtro tipologia.
- [ ] Verificare combinazione filtri.
- [ ] Verificare rimozione singolo filtro.
- [ ] Verificare pulizia tutti i filtri.

## 20. Checklist ordinamento

- [ ] Verificare ordinamento default.
- [ ] Verificare ordinamento prezzo crescente.
- [ ] Verificare ordinamento prezzo decrescente.
- [ ] Verificare ordinamento nome.
- [ ] Verificare ordinamento disponibilita', se previsto.
- [ ] Verificare persistenza ordinamento con filtri.

## 21. Checklist paginazione

- [ ] Verificare prima pagina.
- [ ] Verificare pagina successiva.
- [ ] Verificare pagina precedente.
- [ ] Verificare ultima pagina.
- [ ] Verificare card dopo cambio pagina.
- [ ] Verificare postback e ViewState.

## 22. Checklist mobile/responsive

- [ ] Verificare desktop largo.
- [ ] Verificare notebook.
- [ ] Verificare tablet.
- [ ] Verificare mobile 414.
- [ ] Verificare mobile 390.
- [ ] Verificare mobile 360.
- [ ] Verificare nessun overflow orizzontale.
- [ ] Verificare bottoni card cliccabili.
- [ ] Verificare immagini proporzionate.

## 23. Checklist SEO/link prodotto

- [ ] Verificare link immagine verso scheda prodotto.
- [ ] Verificare link titolo verso scheda prodotto.
- [ ] Verificare URL prodotto corretto.
- [ ] Verificare parametri necessari.
- [ ] Verificare attributi alt immagini.
- [ ] Verificare nessun link vuoto.

## 24. Checklist performance

- [ ] Misurare tempo render catalogo con card inline.
- [ ] Misurare tempo render catalogo con ProductCard.
- [ ] Verificare peso HTML.
- [ ] Verificare immagini lazyload.
- [ ] Verificare assenza query duplicate.
- [ ] Verificare assenza DataBind manuali extra.
- [ ] Verificare console JavaScript pulita.

## 25. Piano rollback

- [x] Rollback immediato: mantenere o riportare `UseNewCatalogProductCard=False`.
- [x] I parametri debug restano manuali e non attivano produzione.
- [x] La card inline legacy resta nel markup.
- [x] Nessuna modifica database necessaria per rollback.
- [x] Nessuna modifica `web.config` necessaria per rollback.
- [ ] Verificare branch e commit di rollback prima del rilascio.

## 26. Criteri per attivare ProductCard

- [ ] Tutti i test catalogo anonimo superati.
- [ ] Tutti i test catalogo loggato superati.
- [ ] Prezzi/listini/IVA verificati.
- [ ] Disponibilita' e TCId verificati.
- [ ] Carrello rapido verificato.
- [ ] Wishlist, quick view e compare verificati.
- [ ] Filtri, ordinamento e paginazione verificati.
- [ ] Mobile/responsive approvato.
- [ ] Performance accettabile.
- [ ] Approvazione finale ricevuta.

## 27. Criteri per NON attivare ProductCard

- [ ] Prezzi non coerenti con catalogo legacy.
- [ ] Carrello rapido non affidabile.
- [ ] Quantita' o multiselezione instabili.
- [ ] Wishlist/quick view/compare con regressioni.
- [ ] Filtri o paginazione alterati.
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

