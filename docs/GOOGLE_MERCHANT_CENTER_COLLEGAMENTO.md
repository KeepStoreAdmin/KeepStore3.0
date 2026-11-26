# GOOGLE_MERCHANT_CENTER_COLLEGAMENTO - guida passo passo per collegare il feed a Google Merchant Center

Task `GOOGLE-MERCHANT-CENTER-FEED-1A` (26/11/2026). Stato: **SOURCE, nulla pubblicato**. Questa guida dice che cosa fare, in ordine, per far leggere a Google il feed di prodotti del negozio. Non promette l'approvazione degli articoli ne tempi: decide Google. Le regole di Google citate sono quelle pubblicate il 26/11/2026 (Aiuto di Merchant Center: specifica dei dati prodotto, file con tabulazioni, titolo, GTIN); possono cambiare.

## 0. Prima di tutto: due avvertenze

**Non compilare `aziende.google_merchant_id` per il feed.** Il feed non ne ha bisogno. Quel campo, se valorizzato, e usato dalla pagina del documento ordine (`documentidettaglio.aspx.vb`) per mostrare dopo ogni ordine il sondaggio **Google Customer Reviews**, passando a Google il numero d'ordine e **l'email dell'acquirente**. Compilarlo equivale ad attivare quel sondaggio: serve prima l'iscrizione al programma Customer Reviews in Merchant Center e l'informativa privacy aggiornata. Finche non decidi questo, lascia il campo vuoto.

**Il feed va collegato con un file di prova, non con tutto il catalogo, la prima volta**: i problemi che Google segnala (titoli, identificativi, spedizione) si correggono meglio su poche righe. Usa un feed con un filtro di merciologia (scheda Merciologia Selezionata) o gli articoli di un solo marchio.

## 1. Che cosa deve essere pronto sul server (una volta)

1. Il motore dei feed aggiornato: file `App_Code/KeepStoreFeedEngine.vb` (con i campi `CondizioneInglese`, `EanValido`, `DescrizioneSoloTesto`, `TitoloNormalizzato`). Senza, un feed che li usa risponde con un errore di configurazione.
2. La cartella `Public/assets/images/export` del sito esiste e il processo del sito puo scriverci (e non e raggiungibile direttamente dal browser: il file si legge sempre da `feed.aspx`).
3. Database: i blocchi di [EXPORT_FEED_ESEMPI](EXPORT_FEED_ESEMPI.md) `campi` (registra i campi nel gestionale) ed `esempi` (crea i tre feed di esempio, disabilitati), nell'ordine, con il tuo si per ogni database.

## 2. Preparare il feed nel gestionale

1. Apri il feed `ESEMPIO Google Merchant (azienda ...)` e usa **Duplica**: lavora sulla copia, l'esempio resta come modello.
2. Scheda Generale: scegli il **vettore** dell'azienda con le fasce di costo (altrimenti la colonna `shipping` resta vuota) e i **giorni di spedizione**. Il listino e l'IVA inclusa sono gia quelli giusti; non cambiarli.
3. Scheda Merciologia Selezionata: per la prima prova scegli un solo marchio o una categoria con poche decine di articoli.
4. **Abilita** il feed (casella Abilitato) e salva. Il feed ha un codice lungo casuale: il link e `https://<dominio del negozio>/feed.aspx?c=<codice>`. Il codice si cambia con **Nuovo codice** (il vecchio smette di funzionare).
5. **Anteprima**: aggiungi `&anteprima=1` al link e aprilo: mostra le prime 20 righe senza contare come lettura di Google. Controlla a occhio:
   - `title`: le parole maiuscole sono diventate «Parola Parola» (sigle come USB diventano `Usb`: e voluto, e meglio di tutto maiuscolo che Google non ammette);
   - `price`: `12.34 EUR`, IVA inclusa, uguale alla scheda articolo (per gli articoli in offerta valida oggi per 1 pezzo e il prezzo di offerta);
   - `condition`: `new` oppure `refurbished`;
   - `gtin`: o un codice con 8, 12, 13 o 14 cifre, o vuoto (codici interni del negozio non validi vengono lasciati vuoti di proposito);
   - `mpn`: il codice articolo del negozio (vedi il limite sotto);
   - `shipping`: `IT::Standard:5.90 EUR`.

## 3. Collegare Merchant Center (nel sito di Google, tu)

1. Account Merchant Center del negozio: **verifica e rivendica il dominio** del sito (Impostazioni > Informazioni sull'attivita > Sito web). Il dominio del feed deve essere lo stesso dei link (`link` e `image_link` del file sono `https://<dominio>/...`).
2. Impostazioni di **spedizione e resi** in Merchant Center per l'Italia (Google le richiede per gli annunci Shopping; il feed ha solo il costo per articolo).
3. Prodotti > Feed (origini dati) > **Aggiungi origine dati prodotti** > scegli il paese **Italia** e la lingua **Italiano** > **Recupero programmato** (o «Fetch») e incolla il link del feed (con il codice). Nome del file: qualsiasi; formato: file con tabulazioni (`.txt`/`.tsv`): il feed risponde `text/tab-separated-values`, UTF-8, prima riga con i nomi degli attributi.
4. Frequenza: **una volta al giorno**, in un orario in cui il negozio e poco carico. Il file e ricostruito al massimo ogni 60 minuti e tutte le richieste di Google leggono il file gia pronto, senza interrogare il database.
5. **Recupera ora** e aspetta: nella scheda **Diagnostica** compaiono gli errori e gli avvisi per articolo.

## 4. Che cosa guardare nella diagnostica, e che cosa fare

| Segnalazione di Google | Che cosa significa | Che cosa fare |
|---|---|---|
| Valore non valido per `gtin` | un codice a barre non e GS1 valido | non succede per i codici scritti dal feed (solo validi); se compare, cambia l'EAN nel gestionale |
| Identificativi mancanti (`gtin`, `mpn`, `brand`) | articolo senza GTIN valido e codice produttore non riconosciuto | correggi l'EAN o il codice articolo nel gestionale; non e un difetto del feed |
| `mpn` non corrisponde | il codice articolo del negozio non e il codice del produttore | segnala l'articolo: serve il codice vero del produttore (oggi il feed usa `Codice`) |
| Titolo con maiuscole eccessive | resta un titolo troppo maiuscolo | di norma corretto dal feed; segnala quali articoli restano |
| Problemi del file (colonne in meno) | Google non ha letto bene una riga (in particolare per le virgolette nei titoli, 549 titoli contengono `"` dentro il testo) | mandami l'esempio della riga segnalata |
| Prezzo diverso dalla pagina | Google confronta il prezzo con la scheda articolo | il feed usa la stessa regola della scheda (offerta per 1 pezzo valida oggi, altrimenti listino): se Google segnala differenze, controlla le promozioni scadute di recente |
| Immagine non raggiungibile | `image_link` non si apre dal pubblico | controlla che le immagini articolo siano online (cartella immagini del sito) |

Se tutto e a posto sulla prova, estendi la selezione del feed (o usa il feed completo) e ripeti **Recupera ora**.

## 5. Limiti e cose da sapere

1. **Il feed e verificato contro le regole pubblicate da Google, non dentro Merchant Center**: l'approvazione degli articoli e le tempistiche sono di Google.
2. **`mpn` = `Codice`** (decisione del PO 2026-11-25): non e provato che ogni codice sia un vero codice del produttore. Circa 70 articoli su 1.569 (4,5%) non hanno un GTIN valido: per loro Google si basera su marchio e `mpn`.
3. **`identifier_exists` non viene scritto**: per un articolo senza GTIN e senza un `mpn` che Google riconosce, Google chiedera di dichiarare «nessun identificativo».
4. **14 valori di EAN compaiono su articoli diversi** (varianti con lo stesso codice a barre): Google puo segnalarli come duplicati.
5. **Virgolette**: i titoli con virgolette interne (pollici) non vengono modificati; se la diagnostica li segnala, le specifiche non dicono che sia un errore, ma e il primo punto da controllare.
6. **Titoli normalizzati**: regola solo strutturale (parole con cifre invariate, le altre con la sola iniziale maiuscola). Le sigle senza cifre (`USB`, `SSD`, `HDMI`) diventano `Usb`, `Ssd`, `Hdmi`. Se non ti piace, nel feed duplicato usa il campo `Descrizione1` nella colonna `title` (ma i titoli tutto maiuscolo saranno segnalati da Google).
7. Per Trovaprezzi / 7Pixel e idealo vedi [EXPORT_FEED_ESEMPI](EXPORT_FEED_ESEMPI.md): in questa guida c'e solo Google.

CONSEGNA SERVER SOSPESA.
