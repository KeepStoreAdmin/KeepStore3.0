# KeepStore — foto dei prodotti più nitide e belle: il sistema (decisione del 2026-11-20)

Task `PRODUCT-PHOTOS-SYSTEM-1A`. Richiesta del PO (2026-11-19): «Esiste un sistema per rendere la visualizzazione delle foto nel sito più brillanti e più belle? Studia un sistema che possa ottenere questo risultato. Scrivilo nel manuale e poi confrontati con ChatGPT, fate ricerca e poi procedete.»

Questo documento descrive il sistema deciso e l'ordine dei task. Ogni task di codice segue il flusso di revisione di [AGENTS](../AGENTS.md). Vale per ogni negozio servito dallo stesso sorgente: ciascuno ha le proprie foto.

## 1. Regole che non si toccano

1. **Le foto caricate dal negozio non si modificano mai**: sono dati del cliente. Il sito può mostrare **copie derivate** generate dal server, rigenerabili e cancellabili.
2. **Nessun ritocco automatico che possa far sembrare il prodotto diverso**: niente sbiancamento dello sfondo, ritaglio, aumento di colore o di contrasto applicati a tutte le foto. Un prodotto bianco o trasparente non si distingue in modo sicuro dallo sfondo (osservazione di ChatGPT, accolta).
3. **Niente librerie nuove** senza approvazione: si usa ciò che il framework ha già.

## 2. Fatti misurati

**Come sono servite oggi.** Le pagine puntano al file originale; nessun ridimensionamento sul server, nessuna scelta della misura da parte del browser (`srcset` / `sizes` assenti).

**Campione di 14 foto reali** (prima pagina pubblica delle offerte, 2026-11-19): lato da 780 a 1.523 px; peso da 25 a 639 KB; sfondo bianco puro in 6, quasi bianco in 4, grigio o scuro in 4; il prodotto occupa dal 34% al 100% dell'inquadratura; due foto non quadrate.

**Miniature già presenti sul server.** Per ogni foto esiste una miniatura `_nomefile` da **150 × 150 px** (tre misurate). Il sito la usa nel carrello, nei suggerimenti di ricerca, nella ricevuta e — qui sta il difetto — **come seconda immagine delle schede della HOME** (quella che compare passando il mouse), dentro riquadri larghi 200-290 px: lì la foto diventa sfocata.

**Esperimento del 2026-11-20** (6 foto reali, riquadro da 220 px, browser Edge; quattro versioni affiancate, viste a densità 1 e a densità 2 come sui telefoni):

| Versione | Peso totale delle 6 foto | Resa su schermo normale | Resa su telefono (alta densità) |
| --- | --- | --- | --- |
| A — originale, rimpicciolito dal browser (oggi) | 1.964 KB | buona | buona |
| B — copia del server a 220 px | 57 KB | uguale ad A | **sfocata** |
| C — copia del server a 440 px (il doppio del riquadro) | 146 KB | uguale ad A | uguale ad A |
| D — copia a 440 px con nitidezza leggera | 163 KB | appena più definita | **visibilmente più definita** (scritte, codici a barre, bordi) |

Che cosa dice l'esperimento:
- il browser rimpicciolisce già bene: una copia ridotta **da sola non rende la foto più bella**;
- una copia della misura «giusta» ma non doppia **peggiora** la resa sui telefoni: mai una sola misura;
- la copia doppia pesa **13 volte meno** dell'originale a pari resa: pagine più leggere e più veloci;
- una **nitidezza leggera dopo la riduzione** è l'unico intervento che rende le foto visibilmente più brillanti senza cambiare colori, sfondo o inquadratura.

**Altri fatti.** La finestra di ingrandimento della scheda prodotto dichiara sempre 800 × 800 px, anche per foto di altra misura o non quadrate. La risposta del server per le foto non indica per quanto tempo il browser può tenerle (impostazione del server, fuori dal mandato di questo progetto: da valutare con il PO ed Enzo).

## 3. Il sistema

### 3.1 Mai una foto più piccola del riquadro (subito)
Una miniatura da 150 px si usa solo dove la foto è mostrata a 75 px o meno (carrello, suggerimenti). In ogni riquadro più grande si usa la foto piena o una copia adeguata. Primo intervento: la seconda immagine delle schede della HOME.

### 3.2 Copie derivate della misura giusta, con nitidezza leggera
Un gestore del sito produce, per una foto e per poche larghezze ammesse, una copia ridotta con ricampionamento di alta qualità e nitidezza leggera, la salva e la riusa. Le pagine dichiarano le misure disponibili, così ogni dispositivo sceglie la sua (i telefoni la doppia). Condizioni obbligatorie (punti bloccanti di ChatGPT, accolti):
- **solo le foto del negozio dell'host**: cartella e copie separate per azienda, nessun indirizzo esterno scaricato dal server, nessun percorso libero;
- **limiti**: larghezze da un elenco chiuso, peso e numero di punti massimi dell'originale, quota della cartella delle copie, una sola generazione alla volta per copia, scrittura su file temporaneo e sostituzione in un colpo;
- **mai un errore visibile**: se la copia non si può fare, il sito mostra l'originale come oggi;
- il nome della copia contiene azienda, misura, versione del metodo e impronta dell'originale: cambiando foto o metodo cambia il nome, quindi il browser può tenerla a lungo;
- la nitidezza ha un valore solo, misurato e provato su casi difficili (bordi scuri su fondo bianco) per escludere aloni;
- foto ruotate dai metadati, con profili di colore particolari, trasparenti, rovinate o molto piccole: provate una per una; nel dubbio si mostra l'originale;
- la funzione nasce **spenta** e si accende per negozio; la cartella delle copie sul server va concordata alla consegna (oggi sospesa).

### 3.3 Riquadro e ingrandimento
- Riquadro uguale in tutte le schede (bianco, quadrato, stesso margine interno): gran parte è già così in HOME e catalogo; si completa dove manca, seguendo la [linea di stile](KEEPSTORE_STYLE_DIRECTION_2026_11_19.md).
- Dimensioni dichiarate nelle pagine, così la pagina non salta mentre le foto arrivano.
- L'ingrandimento della scheda prodotto usa le misure vere della foto e non ingrandisce foto piccole.
- Quando una pagina cambia la foto mostrata (seconda immagine, miniature della galleria) aggiorna anche l'elenco delle misure, altrimenti resta visibile quella vecchia.

### 3.4 Un elenco per il negozio (aiuto, non giudice)
Uno strumento di sola lettura che elenca le foto mancanti, molto piccole, non quadrate o con sfondo non chiaro. Serve a chi cura il catalogo per decidere quali rifare: una foto ambientata o non quadrata può andare benissimo.

### 3.5 Foto migliorate solo su approvazione (in seguito)
Sfondo portato a bianco e prodotto inquadrato sempre allo stesso modo danno molto, ma solo foto per foto: lo strumento prepara «prima e dopo», il negozio approva, e la versione approvata diventa una copia che affianca l'originale. Nessun automatismo.

## 4. Ordine dei task

1. **`PHOTO-HOME-HOVER-SHARP-1A`** (piccolo): la seconda immagine delle schede della HOME non usa più la miniatura da 150 px.
2. **`PHOTO-ZOOM-REAL-SIZE-1A`**: ingrandimento della scheda prodotto con le misure vere.
3. **`PHOTO-DERIVED-COPIES-1A`** (livello L per sicurezza e multi-azienda): gestore delle copie con le condizioni della sezione 3.2, prima sull'elenco, spento per difetto, provato sul LAB con foto vere.
4. **`PHOTO-QUALITY-REPORT-1A`**: l'elenco della sezione 3.4.
5. **`PHOTO-APPROVED-ENHANCE-1A`**: la sezione 3.5, dopo una decisione del PO su come approvare.

## 5. Che cosa deve provare ogni task
Confronto a vista «prima e dopo» su foto vere a densità 1 e 2; peso delle immagini della pagina prima e dopo; nessuna foto più piccola del riquadro; nessun salto della pagina; due negozi con foto dallo stesso nome; richieste di misure non ammesse, nomi di file con percorsi, originali enormi, due richieste insieme della stessa copia, cartella non scrivibile.

## 6. Limiti dichiarati
Campione di 14 foto di un solo negozio; sul PC di sviluppo ci sono 5 foto, le altre stanno sul server; nessuna prova sul server (consegna sospesa); la resa finale dipende dalla qualità delle foto caricate: il sistema le mostra al meglio, non le sostituisce.
