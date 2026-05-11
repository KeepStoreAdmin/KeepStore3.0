# Catalog manual test checklist

## Scopo

Questa checklist definisce i test manuali minimi per verificare il catalogo e la `ProductCard.ascx` live prima di qualunque modifica futura alla card prodotto.
La checklist va usata come baseline prima dei micro-task ProductCard e come regressione dopo ogni modifica impattante.

## Prerequisiti

- Branch operativo: `frontend-rebuild`.
- Working tree pulito.
- Ambiente locale o staging disponibile.
- `ProductCard.ascx` live nel catalogo reale.
- Guardrail ProductCard documentati in `docs/catalog-product-card-guardrails.md`.
- Browser con DevTools disponibile per verifica console.

## Checklist manuale

| ID test | Area | URL o azione | Cosa verificare | Esito atteso | Risultato manuale |
|---|---|---|---|---|---|
| CAT-T01 | Apertura catalogo | `/articoli.aspx` | Pagina catalogo senza filtri | Catalogo visibile, nessun errore, prodotti caricati | Da compilare |
| CAT-T02 | ProductCard live | `/articoli.aspx` | Card renderizzata nel listing reale | Card visibile con immagine, nome, prezzo e disponibilita' | Da compilare |
| CAT-T03 | Prodotto normale | Aprire catalogo con prodotto non promo | Prezzo standard e assenza badge promo errato | Prezzo e informazioni coerenti | Da compilare |
| CAT-T04 | Prodotto promo | Aprire catalogo/offerte, per esempio `?inpromo=1` | Badge promo, prezzo nuovo e prezzo vecchio | Promo visibile e coerente | Da compilare |
| CAT-T05 | Prodotto senza immagine | Trovare un prodotto con immagine mancante | Fallback immagine | Placeholder visibile e layout stabile | Da compilare |
| CAT-T06 | TCId reale | Trovare un prodotto con variante reale | Link dettaglio, add-to-cart e dati card con TCId | TCId valorizzato e coerente | Da compilare |
| CAT-T07 | TCId -1 | Trovare un prodotto senza variante | Flusso dettaglio/add-to-cart con TCId fallback | Nessuna rottura con TCId `-1` | Da compilare |
| CAT-T08 | Dettaglio prodotto | Click su nome, immagine o dettagli card | Navigazione verso scheda prodotto | Apertura `articolo.aspx?id=...` corretta | Da compilare |
| CAT-T09 | Add-to-cart icona | Click icona carrello sulla card | Aggiunta prodotto al carrello | Prodotto aggiunto o flusso carrello corretto | Da compilare |
| CAT-T10 | Add-to-cart pulsante | Click pulsante principale card | Aggiunta prodotto al carrello | Prodotto aggiunto o flusso carrello corretto | Da compilare |
| CAT-T11 | MiniCart | Aprire MiniCart dopo add-to-cart | Prodotto, quantita' e totale | MiniCart aggiornato correttamente | Da compilare |
| CAT-T12 | Wishlist | Click wishlist su card | Azione wishlist | Comportamento atteso per login/non login | Da compilare |
| CAT-T13 | Compare | Click compare su card | Dati prodotto in compare | Compare/offcanvas funzionante e coerente | Da compilare |
| CAT-T14 | Quick view | Click quick view su card | Modal quick view e dati prodotto | Modal aperta, dati coerenti, nessun errore console | Da compilare |
| CAT-T15 | Filtro marca | Applicare filtro marca | Lista prodotti e URL filtro | Filtro applicato correttamente | Da compilare |
| CAT-T16 | Filtro categoria/gruppo | Applicare filtro categoria o gruppo | Lista prodotti e filtro attivo | Filtro applicato correttamente | Da compilare |
| CAT-T17 | Filtro tipologia | Applicare filtro tipologia | Lista prodotti | Filtro applicato correttamente | Da compilare |
| CAT-T18 | Filtro disponibilita' | Selezionare "Solo disponibili" | Prodotti disponibili | Lista aggiornata correttamente | Da compilare |
| CAT-T19 | Taglia/colore | Se attivi, usare dropdown taglia/colore | Query, lista prodotti e TCId | Filtri funzionanti senza rompere le card | Da compilare |
| CAT-T20 | Ordinamento prezzo | Ordinare per prezzo crescente/decrescente | Ordine lista prodotti | Ordinamento coerente | Da compilare |
| CAT-T21 | Ordinamento offerte | Ordinare per offerte | Prodotti promo e priorita' lista | Ordinamento coerente | Da compilare |
| CAT-T22 | Paging | Cambiare pagina catalogo | Prodotti pagina successiva | Paging funzionante e card renderizzate | Da compilare |
| CAT-T23 | Numero righe | Cambiare valore "Mostra" | Page size catalogo | Numero prodotti coerente | Da compilare |
| CAT-T24 | Mobile | Aprire catalogo in viewport mobile | Layout card, filtri e azioni touch | Nessun overflow, azioni utilizzabili | Da compilare |
| CAT-T25 | Console browser | Aprire DevTools console | Errori JavaScript | Nessun errore nuovo | Da compilare |
| CAT-T26 | Preview locale | Solo locale: `/articoli.aspx?ksCardPreview=1` | Preview demo ProductCard | Preview visibile, azioni demo/non operative | Da compilare |
| CAT-T27 | Preview real locale | Solo locale: `/articoli.aspx?ksCardPreviewReal=1` | Preview ProductCard con azioni reali | Preview funzionante senza rompere catalogo | Da compilare |
| CAT-T28 | Replace one locale | Solo locale: `/articoli.aspx?ksCardReplaceOne=1` | Una card sostituita | Card nuova visibile, carrello e TCId OK | Da compilare |
| CAT-T29 | Replace count locale | Solo locale: `/articoli.aspx?ksCardReplaceCount=3` | Numero limitato di card sostituite | Massimo tre sostituzioni, comportamento stabile | Da compilare |
| CAT-T30 | Replace all locale | Solo locale: `/articoli.aspx?ksCardReplaceAll=1` | Tutte le card sostituite | Catalogo navigabile, azioni e TCId OK | Da compilare |

## Nota sui parametri locali

I parametri `ksCardPreview`, `ksCardPreviewReal`, `ksCardReplaceOne`, `ksCardReplaceAll` e `ksCardReplaceCount` vanno eseguiti solo in ambiente locale quando il codice li vincola a `Request.IsLocal`.
Non sostituiscono i test del catalogo reale senza parametri.

## Regola operativa

- Eseguire prima i test baseline.
- Procedere poi con eventuale micro-task ProductCard.
- Dopo ogni modifica ripetere almeno i test impattati.
- Se falliscono add-to-cart, TCId, `data-ks-*`, wishlist, compare o quick view, fermare il task e valutare rollback.
- Non unire modifiche funzionali e rifiniture markup nello stesso micro-task.
