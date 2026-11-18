# Conferma di pagamento Banca Sella: regole e indice facoltativo

`BANCASELLA-CALLBACK-AUTH-1A` (PR 561). Regole nel sorgente: `App_Code/BancaSellaCallback.vb`. Questa pagina serve al PO e a Enzo.

## Che cosa fa il sito quando la banca conferma
1. Accetta solo un negozio (`shopLogin`) presente in `bancasella_impostazioni_azienda`; il servizio della banca non viene chiamato per altri.
2. Il negozio deve essere uno di quelli dell'azienda del documento. Non contano `Attivo` ne `PagamentiTipoId`: disattivare la riga dopo un pagamento non fa perdere l'incasso.
3. Esito OK con codice di autorizzazione: il documento passa a pagato una volta sola (solo da `Pagato = 0`) e nasce una riga in `bancasella_ordini_pagati` per coppia documento e codice. Se il documento era gia pagato la riga viene aggiunta lo stesso e il registro avvisa: e la prova per un rimborso.
4. Esito KO: stato «fallito» solo se il documento non e pagato. Esito in sospeso: nessuna scrittura.
5. Importo, valuta, numero dell'ordine e metodo diversi dall'atteso: solo un avviso in `bancasella_log` (campo `Log`, testo «avvisi=»).

## Controllo periodico consigliato (sola lettura)
```sql
SELECT Time, Log FROM bancasella_log WHERE Log LIKE 'BancaSella %avvisi=%' OR Log LIKE 'BancaSella % rifiutato%' OR Log LIKE '%azione=Rejected%' ORDER BY idLog DESC LIMIT 50;
```

## Indice unico facoltativo (decisione del PO, da applicare solo su `taikun`; il programma di allineamento aggiorna gli altri database)
Il sito e gia protetto dal blocco della riga del documento; l'indice e una seconda difesa. La chiave e la coppia, mai il solo codice (i codici dell'emittente si ripetono negli anni).

Verifica prima (deve restituire zero righe):
```sql
SELECT DocumentiId, codiceAutorizzazione, COUNT(*) AS righe FROM bancasella_ordini_pagati GROUP BY DocumentiId, codiceAutorizzazione HAVING COUNT(*) > 1;
```
Applicazione:
```sql
ALTER TABLE bancasella_ordini_pagati ADD UNIQUE KEY UQ_bancasella_ordini_pagati_documento_codice (DocumentiId, codiceAutorizzazione);
```
Verifica dopo:
```sql
SELECT INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS colonne FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bancasella_ordini_pagati' AND NON_UNIQUE = 0 GROUP BY INDEX_NAME;
```
Ritorno indietro:
```sql
ALTER TABLE bancasella_ordini_pagati DROP INDEX UQ_bancasella_ordini_pagati_documento_codice;
```
Stato: script NON applicato a nessun database (sul LAB la verifica restituisce zero righe: 125 righe, 125 coppie distinte).