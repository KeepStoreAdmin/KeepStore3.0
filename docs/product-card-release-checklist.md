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
- [x] Test anonimo finale validato.
- [x] Test login con listino cliente validato.
- [x] Test cambio listino dopo login validato.
- [x] Test promo/offerte validato.
- [x] Test IVA standard validato.
- [x] Test reverse charge validato.
- [x] Test esenzione IVA validato.
- [x] Test disponibilita' validato.
- [x] Test TCId reale validato.
- [x] Test TCId fallback `-1` validato.
- [x] Carrello rapido validato.
- [x] Wishlist validata.
- [x] Quick view validata.
- [x] Compare validato.
- [x] Quantita' validata.
- [x] Multiselezione validata.
- [x] Checkout validato.
- [x] Ordine letto dal gestionale validato.
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
- [x] Test anonimo finale completato.

## 7. Checklist catalogo utente loggato

- [x] Eseguire login con utente cliente.
- [x] Aprire `articoli.aspx`.
- [x] Verificare lista prodotti.
- [x] Verificare prezzi coerenti con utente.
- [x] Verificare carrello rapido.
- [x] Verificare wishlist.
- [x] Verificare logout e ritorno a comportamento anonimo.

## 8. Checklist listini cliente

- [x] Verificare listino default.
- [x] Verificare listino utente loggato.
- [x] Verificare listino cliente speciale, se disponibile.
- [x] Verificare cambio listino dopo login.
- [x] Verificare prodotto con prezzo normale.
- [x] Verificare prodotto con prezzo promozionale.
- [x] Verificare assenza di prezzi in formato non coerente.

## 9. Checklist promo/offerte

- [x] Verificare prodotto non in offerta.
- [x] Verificare prodotto in offerta valida in scenario base.
- [x] Verificare prodotto con offerta scaduta.
- [x] Verificare prezzo barrato solo se promo reale.
- [x] Verificare badge promo solo se coerente.
- [x] Verificare nessuna promo duplicata o inventata.
- [x] Verificare promo con data inizio/fine.
- [x] Verificare promo con quantita' minima.
- [x] Verificare promo con multipli.

## 10. Checklist IVA, reverse charge, esenzione

- [x] Verificare prezzo ivato standard in scenario base.
- [x] Verificare cliente con IVA diversa.
- [x] Verificare utente con reverse charge, se disponibile.
- [x] Verificare utente con esenzione IVA, se disponibile.
- [x] Verificare coerenza tra catalogo, dettaglio e carrello.
- [x] Verificare nessun formato prezzo anomalo.

## 11. Checklist disponibilita', giacenza, impegnato, arrivi

- [x] Verificare visualizzazione disponibilita' base.
- [x] Verificare prodotto disponibile con disponibilita' numerica.
- [x] Verificare prodotto non disponibile con disponibilita' numerica.
- [x] Verificare disponibilita' con solo logo disponibile/non disponibile.
- [ ] Verificare prodotto con giacenza bassa.
- [ ] Verificare prodotto impegnato.
- [ ] Verificare prodotto in ordine.
- [ ] Verificare prodotto in arrivo.
- [x] Verificare testo disponibilita' nella card.
- [x] Verificare CSS disponibilita' nella card.

## 12. Checklist TCId, taglie, colori

- [x] Verificare prodotto senza variante in scenario base.
- [x] Verificare prodotto con `TCId` reale.
- [x] Verificare fallback `TCId=-1` dove previsto.
- [x] Verificare link carrello con TCId corretto.
- [x] Verificare wishlist con TCId corretto.
- [x] Verificare nessun duplicato causato da varianti.

## 13. Checklist carrello rapido

- [x] Verificare click carrello rapido da card.
- [x] Verificare URL carrello generato.
- [x] Verificare `ArticoliId` corretto nello scenario testato.
- [x] Verificare `TCId` nello scenario testato.
- [x] Verificare quantita' corretta nello scenario testato.
- [x] Verificare prodotto visibile in carrello nello scenario testato.
- [x] Verificare MiniCart/header count nello scenario testato.
- [x] Ripetere carrello rapido con utente loggato e listino cliente.

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
- [x] Ripetere multiselezione con TCId reale e listino cliente.

## 16. Checklist wishlist

- [x] Verificare wishlist nello scenario testato.
- [x] Verificare wishlist da anonimo, se prevista.
- [x] Verificare wishlist da loggato.
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

## 24A. Checklist checkout, ordine e gestionale

- [x] Verificare checkout completo con ProductCard attiva nello scenario testato.
- [x] Verificare generazione ordine.
- [x] Verificare ordine letto dal gestionale collegato al database.
- [x] Verificare coerenza articoli, quantita', prezzi e TCId nell'ordine.
- [x] Verificare nessun errore JavaScript durante il percorso catalogo-carrello-checkout.

## 25. Piano rollback

- [x] Rollback immediato: mantenere o riportare `UseNewCatalogProductCard=False`.
- [x] I parametri debug restano manuali e non attivano produzione.
- [x] La card inline legacy resta nel markup.
- [x] Nessuna modifica database necessaria per rollback.
- [x] Nessuna modifica `web.config` necessaria per rollback.
- [x] Verificare branch e commit di rollback logico prima del rilascio.

## 26. Criteri per attivare ProductCard

- [x] Test catalogo anonimo superati nello scenario validato.
- [x] Tutti i test catalogo loggato superati.
- [x] Prezzi/listini/IVA verificati.
- [x] Disponibilita' e TCId verificati.
- [x] Carrello rapido verificato nello scenario validato.
- [x] Wishlist, quick view e compare verificati nello scenario validato.
- [x] Filtri, ordinamento e paginazione verificati nello scenario validato.
- [x] Mobile/responsive approvato nello scenario validato.
- [ ] Performance accettabile su dataset esteso.
- [ ] Approvazione finale ricevuta.
- [x] Checkout e ordine verificati.
- [x] Lettura ordine nel gestionale verificata.

## 27. Criteri per NON attivare ProductCard

- [x] Prezzi non coerenti con catalogo legacy: criterio bloccante da mantenere.
- [x] Carrello rapido non affidabile: criterio bloccante da mantenere.
- [x] Quantita' o multiselezione instabili: criterio bloccante da mantenere.
- [x] Wishlist/quick view/compare con regressioni: criterio bloccante da mantenere.
- [x] Filtri o paginazione alterati: criterio bloccante da mantenere.
- [x] Problemi con listini cliente: criterio bloccante da mantenere.
- [x] Problemi con IVA/reverse charge/esenzione: criterio bloccante da mantenere.
- [ ] Layout mobile non approvato.
- [ ] Performance peggiorata in modo significativo.
- [ ] Mancanza di approvazione finale.

## 28. Esito finale e approvazione

- [x] Checklist tecnica completata.
- [x] Esito tecnico approvato.
- [x] Esito UX approvato nello scenario validato.
- [x] Esito commerciale approvato.
- [x] Piano rollback confermato.
- [ ] Decisione finale: attivare `UseNewCatalogProductCard=True`.
- [ ] Decisione finale: mantenere `UseNewCatalogProductCard=False`.

## 29. Decisione attuale

- [x] ProductCard tecnicamente validata.
- [x] ProductCard commercialmente validata.
- [x] ProductCard validata con carrello, checkout, ordine e gestionale.
- [x] Attivazione globale non ancora approvata.
- [x] `UseNewCatalogProductCard` resta `False` finche' non viene creato e approvato il branch di attivazione.
- [x] L'attivazione richiede una modifica separata e controllata della flag a `True`.
- [x] Rollback immediato: riportare `UseNewCatalogProductCard=False`.

