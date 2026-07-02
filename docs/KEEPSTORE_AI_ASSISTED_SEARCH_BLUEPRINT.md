# KeepStore AI Assisted Commerce Search Blueprint

Stato: blueprint architetturale, non implementazione runtime.

Questo documento definisce la direzione futura per una ricerca assistita / assistente acquisto multi-merceologia in KeepStore 3.0. La funzione deve nascere sopra la ricerca deterministica esistente e sopra i dati reali del catalogo, senza introdurre API AI, nuove tabelle, endpoint o modifiche runtime in questa fase.

## 1. Principio multi-merceologia

L'assistente acquisto non deve contenere domande hardcoded valide per tutti i negozi. KeepStore e rivendibile e multi-azienda: Taikun, Webaffare e futuri ecommerce possono avere merceologie molto diverse.

Il comportamento futuro deve derivare il piu possibile da:

- settori, categorie, tipologie, gruppi e sottogruppi;
- marche;
- codice articolo ed EAN;
- descrizione breve, descrizione estesa e descrizione HTML;
- schede tecniche o campi tecnici gia disponibili, da auditare prima di usarli;
- attributi/varianti gia presenti, come taglia, colore e TC;
- disponibilita, promo, prezzo, listino e immagini;
- prodotti visti di recente e ricerche recenti client-side;
- prodotti in carrello solo in futuro, con task privacy esplicito;
- configurazioni azienda/sito solo con task dedicato.

Gli esempi merceologici sono linee guida, non logiche da hardcodare:

- alimentari: gusto, formato, quantita, dieta/intolleranze se presenti nei dati, marca, prezzo e disponibilita;
- bibite: tipo bevanda, gusto, formato, zucchero/zero, confezione e marca;
- pittura, Vintage, Shabby Chic: superficie, effetto desiderato, colore, finitura, uso interno/esterno e accessori collegati se presenti;
- elettronica/informatica: compatibilita, marca, modello, codice/EAN e caratteristiche tecniche;
- cartucce/toner: marca stampante, modello stampante, codice cartuccia, colore, originale/compatibile se presente nei dati.

Regola permanente: l'assistente deve leggere il catalogo del sito corrente e proporre domande coerenti con quella merceologia. Non deve trasformare esempi Taikun/Webaffare in comportamento fisso per tutti.

## 2. Stato ricerca attuale

Audit `SEARCH-HEADER-CATALOG-AI-AUDIT-1A`: esito A.

Elementi gia esistenti:

- header desktop: `tbCerca`, `product_cat`, `btnSearch`, `ksSearchSuggestDesktop`;
- header mobile: `tbCercaMobile`, `product_cat_mobile`, `btnSearchMobile`, `ksSearchSuggestMobile`;
- home: blocco "AI locale KeepStore" in `Default.aspx` con `home-default.js`;
- endpoint suggest: `/search_suggest.aspx`, anche con `mode=ai`;
- pagina risultati: `articoli.aspx`;
- datasource principale: `vsuperarticoli`;
- ranking deterministico gia presente;
- preview immagini suggest gia presente;
- recent searches/recent viewed lato client gia presenti.

Campi gia cercati o disponibili nella ricerca attuale:

- `Codice`;
- `Ean`;
- `Descrizione1`;
- `Descrizione2`;
- `DescrizioneLunga`;
- `DescrizioneHTML`;
- `MarcheDescrizione`;
- `SettoriDescrizione`;
- `CategorieDescrizione`;
- `TipologieDescrizione`;
- `GruppiDescrizione`;
- `SottogruppiDescrizione`;
- disponibilita, promo, prezzo/listino, vetrina, visite, immagini e TC dove gia esposti.

Stato micro-task search deterministica post PR #222/#223/#224:

- PR #222 chiusa: `catalogUrl` suggest usa `disponibile=1` e `ordinamento=...`, allineati ad `articoli.aspx`; ranking/query SQL invariati.
- PR #223 chiusa: JSON pubblico suggest non espone piu `ex.Message`; errore generico `Servizio suggerimenti temporaneamente non disponibile.` con formato `ok=false` + `error`.
- PR #224 chiusa: `SearchScore` catalogo ampliato in `articoli.aspx.vb` con `DescrizioneHTML` solo scoring, marca+descrizione, tassonomie e token multi-parola; query filtro principale, `Export +500`, Codice/EAN e query numeriche preservati.
- PR #226 chiusa: zero-results catalogo migliorato in `articoli.aspx` con query HTML encoded, CTA generiche e chip da token query; fallback statici merceologici/elettronica rimossi per multi-merceologia, senza AI attiva, prodotti inventati, query DB extra o modifiche a suggest/ranking.
- PR #228/#229/#230 chiuse: performance zero-results e sidebar filtri catalogo stabilizzate senza AI attiva. PR #228 evita facet/`showFilters()` su zero-results usando `lvProdotti.Items.Count`; PR #229 fissa l'ordine `Marche > Tipologie > Gruppi > Sottogruppi > Disponibilita > Varianti`, rimuove `Categoria` dalla sidebar e preserva `ct` come querystring; PR #230 compatta lo spacing con CSS scoped sotto `#ksCatalogPage`. Query prodotti principale, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine e gateway restano invariati.
- PR #232 chiusa: filtri applicati catalogo in stile ONSUS-like con `.meta-filter-shop`, `#applied-filters`, `.remove-all-filters` e `icon-close`; rimozione singola filtro via GET sicuro, remove-all visibile e funzionante, `st/ct` preservati, nessun chip tecnico solo ID, sidebar invariata e zero-results preservato. Query prodotti principale, SearchScore/ranking, suggest, DB/schema/SP, carrello/checkout/ordine, gateway e JS restano invariati; CSS scoped sotto `#ksCatalogPage`.
- Test registrati: `hp` non peggiorato (`18933,20018`), `stampante hp` migliorato verso suggest (`20810,17698`), `12384` invariato con nessun ID catalogo e suggest `total=0`; smoke suggest/articoli/carrello OK.
- Limiti residui: LIKE su molte colonne lunghe puo diventare costoso; zero results ora e assistito ma resta locale/non-AI; eventuale AI/LLM resta fase successiva con privacy task.

## 3. Architettura a strati

### 3.1 UI widget

Futura UI possibile:

- chatbox/assistente acquisto non invasivo;
- entry point da header search, home, catalogo, zero results e scheda articolo;
- stile ONSUS/KeepStore, mobile-first e accessibile;
- CTA orientativa, per esempio "Ti aiuto a trovare il prodotto giusto";
- nessuna promessa di disponibilita, prezzo o compatibilita non presente nei dati.

### 3.2 Understanding locale

Prima di qualunque LLM, il sistema deve fare comprensione locale:

- normalizzazione testo;
- tokenizzazione;
- riconoscimento codice articolo ed EAN;
- riconoscimento marca;
- riconoscimento settore/categoria/tipologia;
- riconoscimento parole frequenti del catalogo;
- sinonimi solo se derivabili dai dati o configurabili;
- limite lunghezza input.

### 3.3 Retrieval deterministico

La base deve restare deterministica:

- cercare prima sui dati reali del catalogo;
- codice/EAN esatto sempre prioritario;
- match a inizio parola sopra contenuto generico;
- marca + descrizione sopra descrizione generica;
- scheda tecnica/campi tecnici da includere solo dopo audit;
- disponibilita e promo come boost controllati, non come sostituti della pertinenza;
- risultati sempre collegati a prodotti reali;
- spiegazione breve del perche un prodotto viene proposto.

### 3.4 Domande guidate

Se la richiesta e generica, l'assistente deve fare una domanda invece di inventare:

- se emergono piu intenti, proporre una scelta;
- se manca un dato critico, chiedere dettaglio;
- se la merceologia ha attributi ricorrenti, trasformarli in domande;
- se i dati non contengono l'attributo, non fingere di averlo.

Esempi:

- "Che modello di stampante Brother hai?";
- "Ti serve per interno o esterno?";
- "Preferisci senza zucchero?";
- "Hai un budget massimo?";
- "Vuoi prodotti disponibili subito?".

### 3.5 Risultati

Le risposte devono mostrare card prodotto reali:

- immagine;
- nome;
- prezzo;
- disponibilita;
- promo se presente;
- motivazione breve;
- filtri suggeriti;
- CTA "vedi prodotto" e "confronta".

`Aggiungi al carrello` dall'assistente e ammesso solo in una fase futura, dopo task dedicato su sicurezza, quantita, TC, promo e carrello.

### 3.6 Zero results evoluto

Quando non ci sono risultati:

- proporre categorie vicine;
- proporre query alternative locali;
- mostrare prodotti popolari o visti di recente;
- chiedere chiarimento;
- evitare messaggi tecnici;
- non mostrare prodotti inventati.

### 3.7 AI/LLM futura

AI/LLM resta opzionale e successiva:

- solo dopo ranking deterministico stabile;
- solo con task dedicato;
- nessuna API esterna senza autorizzazione;
- invio fuori sistema solo di dati minimi e autorizzati;
- nessun dato personale, account o carrello senza task privacy esplicito;
- risposte vincolate ai prodotti reali;
- niente consigli inventati;
- niente promesse su prezzo/disponibilita se non presenti nei dati.

## 4. Fonti dati future

Fonti da considerare in audit successivi:

- codice articolo;
- EAN;
- marca;
- descrizione breve;
- descrizione lunga;
- descrizione HTML;
- scheda tecnica/campi tecnici se gia presenti;
- settore/categoria/tipologia/gruppo/sottogruppo;
- disponibilita;
- promo;
- listino/prezzo;
- immagini;
- taglia/colore/varianti TC;
- ricondizionato;
- spedizione gratuita;
- vetrina;
- visite/statistiche gia usate.

La posizione dei campi "scheda tecnica" non e ancora chiusa in questa blueprint. Prima di usarli serve `AI-ASSISTANT-DATA-PROFILE-AUDIT-1A`, senza inventare tabelle o query.

## 5. WOW features future

Roadmap funzionale, non promessa runtime:

- "Parla con il negozio": chatbox che capisce l'esigenza.
- "Guidami nella scelta": domande progressive.
- "Trova compatibile": toner, cavi, accessori, ricambi.
- "Confronta per me": usa compare esistente.
- "Miglior scelta per budget": prezzo, disponibilita e promo.
- "Mi serve per...": ricerca per uso/esigenza.
- "Non so il nome": navigazione conversazionale.
- "Hai gia visto questi": recenti/cronologia client-side.
- "Ti manca anche...": cross-sell futuro.
- "Scelta rapida": chip suggeriti dinamici.
- "Modalita esperto": codice, EAN e scheda tecnica.
- "Modalita semplice": domande guidate.

## 6. Governance multi-cliente

Regole:

- nessun testo fisso Taikun-only;
- nessuna merceologia hardcoded nel runtime;
- vocabolario derivato dagli articoli dell'azienda/sito corrente;
- eventuali configurazioni per azienda solo con task separato;
- nessun nuovo schema DB in questa fase;
- configurazione AI aziendale solo con task DB esplicito;
- log/telemetria solo se approvati e senza dati sensibili.

## 7. Sicurezza e privacy

Vincoli:

- non inviare dati personali a modelli esterni senza autorizzazione;
- non inviare carrello/account senza task privacy esplicito;
- non esporre query SQL o errori tecnici;
- non restituire `ex.Message` agli utenti;
- output HTML/JSON sempre encoded;
- input con limite lunghezza e normalizzazione;
- valutare rate limit o throttling;
- considerare prompt injection se si usera LLM;
- ogni risposta deve riferirsi a prodotti reali;
- nessun dato prodotto/cliente fuori sistema senza task dedicato.

## 8. Roadmap micro-task token-safe

1. `SEARCH-SUGGEST-CATALOGURL-PARAM-1A`
   - chiuso con PR #222;
   - `available -> disponibile` e `sort -> ordinamento`;
   - ranking/query SQL invariati.

2. `SEARCH-SUGGEST-ERROR-HARDENING-1A`
   - chiuso con PR #223;
   - `ex.Message` rimosso dal JSON pubblico;
   - messaggio generico compatibile con `ok=false` + `error`.

3. `SEARCH-RANKING-ALIGN-1A`
   - chiuso con PR #224;
   - `SearchScore` catalogo avvicinato al suggest;
   - codice/EAN, query numeriche, `Export +500` e filtro principale preservati.

4. `SEARCH-ZERO-RESULTS-ASSIST-1A`
   - chiuso con PR #226;
   - empty state catalogo piu utile;
   - query HTML encoded, CTA generiche e chip da token query;
   - nessun fallback hardcoded merceologico, nessuna AI attiva e nessuna query DB extra.

5. `CATALOG-APPLIED-FILTERS-ONSUS-AUDIT-1A`
   - chiuso prima della PR #232;
   - confermato mapping con ONSUS `shop-default.html` per chip/filtri applicati e remove all;
   - mantenuta logica KeepStore: `Settori/st` livello alto/header, `ct` querystring supportata ma non facet laterale in questa fase.

6. `CATALOG-APPLIED-FILTERS-ONSUS-1A`
   - chiuso con PR #232;
   - chip filtri applicati, remove singolo via GET e `Rimuovi tutto` visibile/chiaro sono integrati;
   - ranking/SearchScore, suggest, DB, query prodotti, zero-results e sidebar filtri preservati.

7. `CATALOG-SIDEBAR-CATEGORIES-ONSUS-AUDIT-1A`
   - audit dedicato separato prima di valutare categorie/sidebar, price range, grid/list o review;
   - evitare copia massiva ONSUS e usare dati reali KeepStore.

8. `AI-ASSISTANT-DATA-PROFILE-AUDIT-1A`
   - audit campi e vocabolario per merceologie;
   - capire dove sta la scheda tecnica;
   - nessuna modifica DB.

6. `AI-ASSISTANT-UI-ONSUS-AUDIT-1A`
   - verificare pattern ONSUS per chat/offcanvas/search;
   - decidere widget UI;
   - nessuna implementazione.

7. `AI-ASSISTANT-LOCAL-PROTOTYPE-1A`
   - primo prototipo non-LLM;
   - domande guidate e retrieval deterministico;
   - nessuna API esterna.

8. `AI-ASSISTANT-RAG-DECISION-1A`
   - solo dopo prototipo locale;
   - decisione AI esterna o motore locale;
   - privacy, costi, logging e governance.

9. `AI-ASSISTANT-MULTI-AZIENDA-CONFIG-1A`
   - eventuale configurazione per azienda;
   - solo se serve;
   - DB task separato.

10. `AI-ASSISTANT-COMMERCIAL-MODULES-1A`
    - cross-sell, upsell, bundle e compare intelligente.

## 9. Criteri di non-regressione

Ogni task futuro deve dichiarare esplicitamente:

- se e solo documentale, audit, UI o runtime;
- branch e HEAD attesi;
- file ammessi;
- nessun PayPal/gateway/email/auth salvo task dedicato;
- nessun carrello/checkout/ordine salvo task dedicato;
- nessun DB/schema/SP salvo task DB esplicito;
- nessuna API esterna salvo task AI/privacy approvato;
- nessun asset non tracciato incluso.

Questa blueprint non implementa AI, chatbot, endpoint, DB, UI runtime o correzioni search. Registra solo architettura e roadmap.
