# Censimento delle funzioni tolte o spente per la regola «solo dati veri» (19/11/2026)

Richiesta del PO del 2026-11-19: «Fammi una ricerca e scrivimi se c'e qualche altra funzione che hai tolto per questa regola, e decidero io se procedere al ripristino oppure lasciare cosi». Ricognizione in sola lettura sulla storia Git (2.873 commit: ricerca nei messaggi e nel contenuto), sui manuali, sui test che vietano qualcosa al sito pubblico e sul modello ONSUS. **Nessuna funzione e stata ripristinata con questo documento: decide il PO, voce per voce.**

**Decisione del PO gia presa (2026-11-19):** «Ti autorizzo a ripristinare questa funzione anche se viola quanto noi abbiamo detto, ma in questo caso, autorizzo io» = la **barra delle vendite in «Occasione Imperdibile»** (voce 1) si ripristina. Task `HOME-DEAL-PROGRESS-1A` nella Roadmap.

## A. Funzioni che esistevano nel sito e sono state tolte, spente o azzerate

| N. | Funzione e pagina | Quando e commit | Che cosa mostrava | Perche fu tolta | Oggi | Dato vero per riaccenderla |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **Barra «venduti / disponibili»** nelle offerte della HOME («Occasione Imperdibile», «Offerte») e nell'anteprima rapida | 2026-10-22, `5bc68e6f` (parte visibile); i numeri `QtaVenduta` e `VendutiAnno` azzerati in `06886eaf` (2026-10-22) e `f744df72` (2026-10-23) | Titolo «Vendite annuali», percentuale, barra rossa, «Venduti: N», «Disponibili: N» | Le somme di vendita erano per articolo, senza filtro per azienda ne per variante: il numero non certificava le vendite | Vietata dal test `Tools/Test-HomeSalesPublicClaims.ps1` | Giacenza: si. Venduto: somma delle righe degli ordini, da correggere per azienda e variante. **RIPRISTINO AUTORIZZATO DAL PO** |
| 2 | **Titolo «Best Seller»** nella HOME | 2026-10-21, `f225d78d` | Titolo «Best Seller» su una selezione mista | La selezione mescolava venduti, piu visti e ripieghi di catalogo | Gia riacceso in parte come «I piu scelti dai clienti» (`06886eaf`, indice interno su ordini di 12 mesi per azienda, senza numeri pubblici); test `Tools/Test-HomeBestSellerClaim.ps1` | Disponibile (indice interno) |
| 3 | **Piede di pagina del modello**: fascia «10% sul primo ordine», iscrizione alla newsletter, icone dei social, loghi dei pagamenti fissi, «Categorie popolari», collegamenti «Nuovi arrivi / Migliori offerte» | 2026-11-15, `f9771f63` | Telefono ed e-mail finti, promozione e newsletter che non salvavano nulla, social generici, loghi fissi | Dati inventati o collegamenti che non portavano dove dicevano | Riaccesi con dati veri: contatti, ragione sociale, settori reali, pagamenti come testo. **Ancora spenti:** newsletter, promozione primo ordine, social, loghi dei pagamenti (task `PAYMENT-LOGOS-1A`). Test `Tools/Test-FooterTruth.ps1` | Newsletter e promozione: nessun archivio trovato. Social: tabelle `social_buttons` (oggi usate per WhatsApp) |
| 4 | **Fascia «vantaggi» a icone** nella HOME | 2026-09-24, `b5f1f664` | «Assistenza tecnica specializzata», «Ritiro in negozio / spedizione», «Prodotti selezionati», «Supporto post-vendita» | Testi fissi uguali per ogni azienda | Assente | Serve un testo per azienda (campo non trovato nel codice) |
| 5 | **Contenuti di ripiego fissi** nella HOME | 2026-09-24, `b5f1f664` | Banner di ripiego, quattro reparti finti, riquadro «Promozioni», titolo «Rivenditori Ufficiali - I migliori Brand», etichette dedotte dal titolo | Contenuti non veri per l'azienda | Senza dati la sezione sparisce; il titolo e «Marche del catalogo» | «Rivenditore ufficiale» richiederebbe un dato per marca |
| 6 | **Marche senza logo** nella HOME | 2026-10-19, `32bc8714` | Loghi da indirizzi esterni o segnaposto | Immagini non nostre o finte | Logo solo se il file esiste in `Public/assets/images/marche/` | File del logo |
| 7 | **Reparti e marche senza articoli** nella HOME | 2026-10-30, `c2bb83a1` | Voci che portavano a elenchi vuoti | Assortimento non reale | Solo voci con articoli; test `Tools/Test-HomeNavigationRealAssortment.ps1` | Catalogo |
| 8 | **Diciture sulle recensioni** nella scheda prodotto | 2026-11-18, `0cbaa155` | «Recensioni verificate», «il parere di chi ha gia acquistato», cinque stelle fisse in testata | Nessuna recensione reale | Le recensioni ESISTONO come funzione (tabella `articoli_recensioni`) ma la tabella e vuota; test `Tools/Test-PdpReviewStars.ps1` | Servono recensioni vere |
| 9 | **Prezzo barrato, etichetta di sconto e «Risparmi»** nella HOME | 2026-11-14, `47ce7fe4` | Sconti anche di pochi millesimi | Sconto non significativo | Mostrati solo sopra 0,01 euro o 1%; test `Tools/Test-HomePriceDisplay.ps1` | Disponibile |
| 10 | **Etichetta «Ricondizionato»** nel catalogo | 2026-10-10, `9692bc2d` | Etichetta su tutto un settore | Non tutti gli articoli lo erano | Solo con il campo `Ricondizionato = 1` | Disponibile |
| 11 | **Ricerche suggerite fisse** a zero risultati | 2026-07-01, `bbc17565` | «Toner stampante», «Notebook ricondizionato»... | Suggerimenti da elettronica uguali per tutti | Assenti | Servirebbero ricerche reali per azienda |
| 12 | **Etichetta «Demo»** sulla scheda in elenco | 2026-09-04, `f28052d8` | Scritta «Demo» | Segnaposto | Sostituita dal valore reale della promozione | Disponibile |

## B. Funzioni del modello ONSUS mai portate, o nascoste perche manca il dato

- **Stelle e numero di recensioni sulle schede in elenco** (`index.html` r. 6983, `shop-default.html`): servono recensioni reali.
- **Istogramma delle stelle e filtro** (`product-detail.html` r. 1294-1383): nel sito il markup c'e, mancano i dati.
- **«Sold: N» nella scheda prodotto e nell'anteprima** (`product-detail.html` r. 936, `index.html` r. 7001): serve il venduto corretto per azienda e variante (come la voce A1).
- **Conto alla rovescia** (`index.html` r. 1108): nel sito ESISTE, solo con una data di fine promozione reale.
- **Fascia a icone «Consegna gratuita, Assistenza 24/7, Pagamenti, Garanzia 30 giorni»** (`index.html` r. 940-1000): servono testi per azienda (come la voce A4).
- **«Reso entro 30 giorni» e «Assistenza» nel riquadro di acquisto** (`product-detail.html` r. 1073): serve la politica dei resi per azienda.
- **Stima «consegna entro»**: nel sito ci sono le tariffe reali, manca la stima dei tempi.
- **«Acquista ora»** (`product-detail.html`): non presente (scelta, non dato).
- **Testimonianze dei clienti** (`shop-cart.html` r. 1006), **newsletter e blog** (`index.html` r. 6156, `blog-grid.html`): nessun archivio ne contenuti.
- **«Appena arrivati»**: omesso perche manca una data di carico certa.

## C. Tolte per altri motivi (non per questa regola)
Numeri di giacenza solo per chi ha fatto l'accesso (`39cb9308`, decisione del PO); codice morto della HOME (`48f99422`, `84b167c0`); Ricerca Avanzata (`d79087ce`); `rettificaMagazzino` (`4d24d427`); comparatori (`ba130b46`); filtro di categoria (`75e81749`).

## Limiti della ricognizione
Circa 200 commit di gennaio-maggio 2026 hanno il messaggio vuoto: le rimozioni fatte li sono coperte solo dalla ricerca nel contenuto. Nessun test eseguito e nessuna lettura del database per questo censimento: «il dato esiste» viene dalla lettura del codice. Carrello, checkout e area cliente non controllati a fondo. Non lette tutte le pagine del modello (`shop-fullwidth`, `shop-right-sidebar`, `checkout`).
