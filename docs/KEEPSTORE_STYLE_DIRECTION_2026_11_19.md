# KeepStore — linea di stile del negozio (decisione del 2026-11-19)

Task `UX-STYLE-DIRECTION-1A`. Mandato del PO (2026-11-19): «Devi ragionare con ChatGPT e risolvere queste difformità, e decidere l'andamento dello style da utilizzare»; «Deve essere impeccabile»; «il nostro dovrà essere adeguato ed innovativo»; «non voglio sempre ripetere le stesse cose».

Questo documento è la **guida dei prossimi task grafici**. Non cambia il prodotto: ogni regola diventa codice in un task suo, con il flusso di revisione di [AGENTS](../AGENTS.md). Vale per ogni negozio servito dallo stesso sorgente (multi-azienda, multi-merceologia): nessuna regola è legata a un cliente o a un settore. Le regole permanenti restano in AGENTS (Design Gate, telefono prima, dati veri, numeri di giacenza solo a chi può vederli).

## 1. Come è stata decisa

1. **Misura del nostro sito** (sito LAB, Edge, 390 e 1280 px, stili calcolati su HOME, elenco delle offerte, scheda prodotto, carrello).
2. **Riferimenti indicati dal PO**, letti come struttura il 2026-11-19 (nessuna copia di testi, marchi o immagini): modello ONSUS (`C:\KeepStoreWeb\Templatre_Onsus`), Bytecno (HOME e scheda prodotto), Unieuro (HOME), Stay On (`e-stayon.com`, HOME).
3. **Ragionamento con ChatGPT** (ragionamento approfondito) su sette ipotesi scritte «da smontare». Ha confermato l'applicazione per gradi e l'uso dei soli dati veri; ha smentito tre punti della bozza, corretti qui sotto (sezioni 3.2, 3.5, 3.6).

**Limiti dichiarati.** Le misure sono campioni (una scheda per tipo e per pagina), non un inventario completo. Il menu su telefono dei siti di riferimento non è stato ancora osservato nel browser. Sul LAB mancano le immagini dei prodotti. I caratteri realmente disegnati su Android e iOS non sono stati misurati.

## 2. Che cosa non è coerente oggi (fatti misurati)

| Elemento | HOME | Elenco | Scheda prodotto | Carrello |
| --- | --- | --- | --- | --- |
| Carattere | Arial | Arial | Arial | «Inter» dichiarato in `cart-ui.css` (non caricato) e Arial |
| Colore del testo | `#1F2933` su fondo `#F5F5F5` | `#333E48` su bianco | `#333E48` su bianco | `#333E48` |
| Titolo di sezione | 22 px, peso 600 | 21 / 26 px, peso 700 | 21 / 26 px, peso 700 | — |
| Titolo della scheda | blu `#004EC3` | blu `#004EC3` | correlati: grigio scuro | — |
| Prezzo | occasioni: rosso 28 px; griglie: nero 22 px | nero 22 px | rosso 30-32 px, peso 500 | — |
| Scheda | bianca, raggio 8 px | senza fondo, raggio 0 | correlati: senza fondo | — |
| Raggi nella pagina | 0, 6, 8, 10 px | 0, 3, 4, 8 px | 0, 6, 8, 10 px | 0, 8 px |
| Pulsante a bordo | raggio 6 px | raggio 8 px | raggio 8 px | raggio 8 px |

Altri fatti: la scheda prodotto su telefono è alta circa 9.200 px, con descrizione, informazioni e recensioni sempre aperte (circa 3.700 px in tre blocchi); il modello ONSUS dichiara «Inter» e «Poppins», ma nel nostro sito sono caricati solo «MADE Outer» e «UTM Banque» e il testo è portato ad Arial da una variabile (`--ks-font-ui`, `theme-overrides.css`); oggi il colore del prezzo non segue ovunque lo stesso stato commerciale (la classe del prezzo corrente viene emessa anche senza sconto, e «in offerta» comprende anche i soli sconti a quantità).

Non tutte le differenze sono difetti: il prezzo più grande nella scheda prodotto ha una ragione (è la pagina della decisione) e resta.

## 3. Decisioni

### 3.1 Un carattere, una scala
- **Un solo carattere per tutto il sito**, quello già definito dalla variabile `--ks-font-ui` (carattere di sistema, nessun file da scaricare: pagina più veloce). Il carrello si allinea; il carattere delle icone resta il suo. «MADE Outer» resta solo dove è già un elemento grafico di marca.
- **Scala** (telefono / schermo grande): titolo di pagina 22 / 26 px peso 700; titolo di sezione 20 / 24 px peso 700; titolo della scheda 14 px negli elenchi e 16 px nelle schede grandi, peso 600; testo 14-16 px; note 12 px. Interlinea e ingrandimento del testo vanno provati a 320 px e con testo al 200%.
- Non si promette «nessun salto del testo»: si misura (CLS) quando si applica.

### 3.2 Colori con un ruolo, prezzo legato allo stato commerciale vero
Il rosso `#D80027` ha tre soli usi: azione principale, prezzo **scontato subito**, bollino dello sconto. Il colore del prezzo si decide dallo stato che il modello commerciale già calcola, mai da una classe generica:

| Stato | Che cosa vede il cliente |
| --- | --- |
| Prezzo normale | prezzo nero |
| Sconto immediato (vale per un pezzo) | prezzo rosso, prezzo precedente barrato in grigio, bollino con la percentuale |
| Promozione condizionata (per esempio «da 5 pezzi») | prezzo **nero** e riquadro «Prezzo quantità» che dice la condizione; mai prezzo rosso |
| Prezzo non disponibile | testo «Prezzo su richiesta», nessun colore di offerta |

Altri ruoli: titolo della scheda **blu collegamento `#004EC3`** su tutto il sito (anche nei correlati della scheda prodotto); testo `#1F2933`; note `#666`; verde e ambra solo per la disponibilità. Tutte le coppie restano sopra il contrasto 4,5:1 già fissato dai test dei colori. Ogni stato ha anche un'indicazione di testo (non solo il colore).

### 3.3 Una scheda prodotto, un contratto
Oggi le schede nascono in più punti (`RenderGridCard` e `RenderDealCard` in `Default.aspx.vb`, `ProductCard.ascx` nell'elenco, il modello dei correlati in `articolo.aspx`, le schede dei visti di recente scritte da JavaScript). **Non si riscrive tutto in un componente solo**: si fissa un contratto visivo che ogni produttore rispetta, tenendo moduli, identificativi e percorsi d'acquisto di ciascuno.

Ordine degli elementi (quelli fra parentesi compaiono solo se il dato c'è): bollino dello sconto; immagine; categoria (una riga); titolo (tre righe riservate); (barra dei venduti); prezzo e prezzo precedente; (riquadro della promozione a quantità); disponibilità; azione. Nella scheda grande delle occasioni conto alla rovescia e barra restano insieme nel piede: è la variante «grande» del contratto.

Tre misure: grande (occasioni), media (griglie della HOME, correlati), compatta (elenco). Stessa superficie ovunque: bianca, bordo sottile, raggio 8 px.

### 3.4 Raggi e superfici
- Raggio **8 px** per schede, riquadri, pulsanti e campi.
- Eccezioni con un nome: **cerchio** per bollini e pulsanti a icona; **pillola** (999 px) per etichette di stato e barre.
- I raggi 3, 4, 6 e 10 px si eliminano quando si tocca il componente, non con una passata generale.
- **Fondo della pagina**: bianco in elenco, scheda prodotto, carrello e area personale; la HOME tiene il grigio chiaro `#F5F5F5` con schede bianche (sono molte sezioni diverse e il fondo le separa). Se il PO preferisce il bianco anche in HOME, è una sola variabile.

### 3.5 Spazi: che cosa si può riservare e che cosa no
Il PO non vuole spazio inutile. Regola precisa (i test la verificano nel browser):
- **Riserve ammesse**, perché tengono allineate le schede della fila: tre righe per il titolo, una riga per la categoria, bersagli per il dito di almeno 44 px, la scheda alta quanto la più alta della fila con l'azione ancorata in fondo.
- **Riserve vietate**: altezze fisse attorno a prezzo e promozione, righe vuote, margini che si sommano allo spazio del contenitore, elementi di spaziatura nel markup.
- Su telefono 24 px sopra e 32 px sotto il contenuto delle pagine di servizio; fra le sezioni della HOME e della scheda prodotto lo spazio si decide nel task della pagina.

### 3.6 Scheda prodotto su telefono
Le sezioni lunghe (descrizione, informazioni, recensioni) diventano **a scomparsa** su telefono, come nei riferimenti. Condizioni obbligatorie, da provare nel task `PDP-LAYOUT-ORDER-1A`:
- l'indice della pagina **apre** la sezione prima di portarci il cliente e mette lì il fuoco della tastiera;
- la prima sezione con contenuto è aperta; una sezione senza contenuto non compare;
- un errore di un modulo dentro una sezione la lascia aperta dopo l'invio;
- in stampa tutte le sezioni sono aperte; da tastiera e con lettore di schermo ogni sezione ha un pulsante con stato aperto / chiuso.
La gerarchia è per componente (un'azione principale per riquadro), non «una per schermata».

### 3.7 Innovazione utile, solo con dati veri
Si adotta dai riferimenti ciò che il nostro database può dire davvero:
- **Sì**: barra dei venduti (fatta); riquadro dell'offerta con la **scadenza vera** della promozione; risparmio in euro e percentuale calcolato dal prezzo; garanzie e condizioni scritte nell'anagrafica dell'azienda; loghi dei **soli pagamenti attivi** per l'azienda dell'host; sezioni a scomparsa; caroselli per reparto.
- **No, finché il dato non esiste**: «prezzo consigliato dal produttore»; «prezzo più basso degli ultimi 30 giorni» (un prezzo barrato non è lo storico); rate; «ordina entro… lo ricevi…»; recensioni e sigilli del negozio non nostri; contatori di urgenza inventati.
Ogni dato mostrato porta con sé provenienza, validità nel tempo e contesto (azienda, listino, variante).

## 4. Ordine dei prossimi task

1. **`STYLE-BASELINE-1A`** (strumento, nessun cambio al prodotto): fotografia riproducibile dello stile, con selettore, variante, visibilità, larghezza e schermata per ogni campione, su tutte le superfici (anche catalogo senza filtro, griglie della HOME, carrello pieno). Serve a non unificare partendo da un campione solo.
2. **`STYLE-PRICE-STATES-1A`** (livello L: prezzi): i quattro stati del prezzo della sezione 3.2, uguali su HOME, elenco e scheda prodotto, derivati dal modello commerciale; prove con una promozione solo a quantità e con un prezzo normale.
3. **`STYLE-TYPE-TITLES-1A`**: un carattere e la scala della sezione 3.1 (carrello compreso), titolo della scheda dello stesso colore ovunque.
4. **`HOME-MOBILE-MENU-1A`**: prima l'osservazione nel browser del menu dei riferimenti e del modello ONSUS, poi il progetto.
5. **`PDP-LAYOUT-ORDER-1A`**: riquadro dell'offerta, sezioni a scomparsa con le condizioni della sezione 3.6, ordine dei blocchi.
6. **`PAYMENT-LOGOS-1A`**: loghi dei soli metodi attivi.
7. **Superficie e raggi delle schede** (sezioni 3.3 e 3.4), un produttore alla volta.

## 5. Che cosa deve provare ogni task (oltre ai test già esistenti)
Promozione solo a quantità che non colora il prezzo; prezzo normale mai rosso; categoria o titolo vuoti; immagine caricata e immagine mancante; ordine degli elementi uguale nel markup e a schermo (nessun riordino fatto solo con lo stile); 320 px e testo ingrandito; due negozi con dati diversi; sezione chiusa raggiunta dall'indice; invio di un modulo che lascia aperto il pannello con l'errore. I test dei colori esistenti provano le coppie di colori, non che il colore sia sullo stato giusto: ogni task aggiunge la prova dello stato.

## 6. Decisioni lasciate al PO
1. Fondo della HOME: grigio chiaro con schede bianche (proposta, è lo stato attuale) oppure bianco come il resto del sito.
2. Titolo delle schede: blu collegamento (proposta, è lo stato attuale di HOME ed elenco) oppure quasi nero.
Senza una risposta si procede con le due proposte, che non cambiano nulla di ciò che oggi si vede in HOME ed elenco.
