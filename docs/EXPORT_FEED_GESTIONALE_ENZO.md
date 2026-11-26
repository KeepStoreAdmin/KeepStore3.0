# Feed per i comparatori: consegna per Enzo (gestionale)

`EXPORT-FEED-GESTIONALE-1A` (task 4 del progetto feed, [manuale](KEEPSTORE_FEED_COMPARATORI_AUDIT_2026_11_25.md)). Questa pagina dice a Enzo che cosa cambiare nelle maschere `frmSettaggiExport` e `frmSettaggiExportGest` e che cosa trova gia pronto nel database e nel sito. Il repository del gestionale e stato letto in sola lettura: il codice VB qui sotto e **un modello** sul tuo `SalvaDati`, da adattare. Disegni delle maschere: [elenco](images/feed-comparatori/1-elenco-export.jpg), [scheda generale](images/feed-comparatori/2-scheda-generale.jpg), [colonne del file](images/feed-comparatori/3-colonne-del-file.jpg) (riquadro **arancione** = nuovo, **rosso tratteggiato** = tolto).

## 1. Prima di tutto: ordine di rilascio e compatibilita
1. Il PO esegue sul database gli script [EXPORT_FEED_DB_SCRIPTS](EXPORT_FEED_DB_SCRIPTS.md) (preflight, forward, verify; descrizione in [EXPORT_FEED_DB_TABLES](EXPORT_FEED_DB_TABLES.md)). **La tabella `export` non cambia e le routine esistenti nemmeno**: il gestionale attuale continua a salvare i feed come oggi (provato con un programma che riproduce `AggiungiDati` e `ExecStoreTrnNoCommit` sul registro reale). Le novita stanno in tre tabelle nuove e quattro routine nuove.
2. **Riavviare il gestionale** dopo lo script: `CheckParametri` legge `sysparametristored` una volta per processo; senza riavvio le routine nuove danno `False` senza messaggio.
3. Poi la tua nuova versione delle maschere. I feed creati dal gestionale vecchio **non hanno la riga di opzioni** (e quindi nemmeno il codice del link): la maschera nuova la crea al primo salvataggio (§4).
4. Il sito (`feed.aspx`) si consegna a parte (task 3): senza le tabelle risponde 503.

## 2. La regola del prezzo (chiarita dal PO, vale per ogni feed)
Nella scheda c'e **gia** il combo del listino (`cmbListini`, campo `NListino`): **sceglie da quale listino prende i prezzi il feed**. Per ogni articolo il feed pubblica **il prezzo offerta per 1 pezzo se, in quel momento, e in promozione per quel listino** (stessa regola del sito: promozione valida oggi, valida per il listino e per l'azienda, non riservata a un utente), **altrimenti il prezzo standard di quel listino**; mai prezzi a scaglioni; IVA inclusa o esclusa come da `IvaTipo`; arrotondato al centesimo. `NListino2` serve solo al campo `#Prezzo2#` (prezzo di riferimento). La valuta (` EUR`) e il **suffisso** della colonna del prezzo. Mettere una nota accanto al combo: «Prezzo: offerta per 1 pz se presente, altrimenti prezzo del listino scelto».

## 3. Che cosa leggere (SQL)
- **Elenco** (le ultime tre colonne sono di sola lettura; i feed mai generati non hanno la riga di stato: `LEFT JOIN`):
  `SELECT e.ID, e.Descrizione, e.Tipo, e.Abilitato, e.NListino, e.Azienda, o.Id AS OpzioniId, o.TokenAccesso, s.UltimaGenerazioneUtc, s.UltimaRichiestaUtc, s.UltimeRighe, s.UltimeScartate, s.UltimoErrore FROM export e LEFT JOIN export_opzioni o ON o.ExportId = e.ID LEFT JOIN export_stato s ON s.ExportId = e.ID ORDER BY e.Descrizione`.
  «Ultimo accesso» = `UltimaRichiestaUtc` (convertire dall'UTC); `UltimoErrore` e un **codice** (lista in [EXPORT_FEED_ENGINE](EXPORT_FEED_ENGINE.md) §3): mostrarlo accanto a una descrizione.
- **Scheda**: `Select * from export where id=<id>` (come oggi); `Select * from export_opzioni where ExportId=<id>` (0 righe = feed senza opzioni: usare i predefiniti e salvare come nuovo); `Select * from export_colonne where ExportId=<id> order by Posizione`; `Select * from exportcampi order by NomeCampo` (ora comprende `CategoriaPercorso`); le selezioni come oggi (`vexport_filtri`, **non toccare le sue prime 8 colonne**: `NewExport_Filtri` le passa per posizione).

## 4. Come salvare (la parte delicata)
`AggiungiDati(nomestore, riga, True)` passa **tutte le colonne dalla seconda all'ultima per posizione** e poi l'`id` nell'ultimo posto; i parametri delle routine si leggono da `sysparametristored`. Quindi: **mai aggiungere colonne alle tabelle `export` e `export_opzioni`** (la forma di `Select *` e un contratto: le opzioni future vanno in un'altra tabella) e usare queste regole per le tabelle nuove:

| Routine | Parametri registrati | Uso |
|---|---|---|
| `Newexport_opzioni` | `parExportId`, `parTokenAccesso`, 15 opzioni, `parRetVal` (OUT = `Id` della riga) | **inserisce o aggiorna** le opzioni del feed (una riga per `ExportId`); il valore del codice e **ignorato** (mettere `rw("TokenAccesso") = ""`: in DEBUG il gestionale stampa i parametri); un valore `DBNull` vale il predefinito della colonna |
| `Newexport_colonne` | `parExportId`, `parPosizione`, titolo, campo, prefisso, suffisso, valore fisso, massimo caratteri, se vuoto, `parRetVal` | una colonna del file; prima `Delete from export_colonne where ExportId=...` (come per i filtri) |
| `Modexport_codice` | `parId` (= `ExportId`), `parRetVal` | nuovo codice del link; `False` se il feed non ha la riga di opzioni (0 righe) |
| `Dupexport` | `parId`, `parRetVal` (OUT = id del nuovo feed, **-1** se l'origine non esiste) | copia feed, opzioni, colonne e filtri; codice **nuovo**, `Abilitato = 0`, nome con `_copia` |

Ordine nella transazione di `SalvaDati` (stessa transazione, un solo `CommitTrns`; **leggere ogni id prima della chiamata successiva**: `ValorePar` e una variabile globale):
1. `NewExport` / `ModExport` come oggi (la riga di `export`; **`FormatString`**: il vecchio controllo la vuole non vuota; comporla dalle colonne della griglia, `#Campo#|#Campo#`, cosi i feed vecchi e il nuovo motore restano coerenti).
2. `Newexport_opzioni` con la riga di `Select * from export_opzioni where id=-1` (**`notnull = False`**: con `True` i `DBNull` diventano `-1` anche nelle colonne di testo). `rw("ExportId") = idExport`, `rw("TokenAccesso") = ""`.
3. `Delete from export_colonne where ExportId=<id>` e poi `Newexport_colonne` per ogni riga della griglia (`Posizione` 1, 2, 3...; non due uguali).
4. Filtri come oggi.
Ogni errore => `RollBackTrns` e messaggio; **attenzione ai difetti gia presenti**: se `OpenTransaction` fallisce `SalvaDati` prosegue senza transazione, `CommitTrns` ignora gli errori e il ritorno di `EseguiSqlTrn` sulla `Delete` dei filtri non e controllato.

```vb
' Modello, sul tuo SalvaDati (nomi di controlli di esempio).
Dim dtO As DataTable = MyConnection.GetDatatable("Select * from export_opzioni where id=-1")
Dim ro As DataRow = dtO.NewRow
ro("ExportId") = idExport
ro("TokenAccesso") = ""                       ' ignorato dalla routine
ro("Separatore") = txtSeparatore.Text
ro("DelimitatoreTesto") = txtDelimitatore.Text
ro("Codifica") = cmbCodifica.SelectedValue     ' utf-8, iso-8859-1, windows-1252
ro("SeparatoreDecimale") = cmbDecimale.SelectedValue ' "." o ","
ro("Intestazione") = IIf(chIntestazione.Checked, 1, 0)
ro("XmlRadice") = txtXmlRadice.Text
ro("XmlElemento") = txtXmlElemento.Text
ro("TogliHtml") = IIf(chTogliHtml.Checked, 1, 0)
ro("MinutiCache") = numMinuti.Value            ' 15 - 1440
ro("ParolaDisponibile") = txtDisp.Text
ro("ParolaInArrivo") = txtInArrivo.Text
ro("ParolaNonDisponibile") = txtNonDisp.Text
ro("SenzaImmagine") = IIf(chSenzaImmagine.Checked, 1, 0)
ro("SenzaEan") = IIf(chSenzaEan.Checked, 1, 0)
ro("PrezzoZero") = IIf(chScartaPrezzoZero.Checked, 1, 0)
If Not AggiungiDati("Newexport_opzioni", ro, True) Then Throw New Exception("Errore Salvataggio Opzioni")

MyConnection.EseguiSqlTrn("Delete from export_colonne where ExportId=" & idExport)
Dim dtC As DataTable = MyConnection.GetDatatable("Select * from export_colonne where id=-1")
Dim pos As Integer = 0
For Each g As DataRow In jColonne.DataSource.Rows        ' la griglia "Colonne del file"
    If g.RowState = DataRowState.Deleted Then Continue For
    pos += 1
    Dim rc As DataRow = dtC.NewRow
    rc("ExportId") = idExport : rc("Posizione") = pos
    rc("TitoloColonna") = g("TitoloColonna") : rc("Campo") = g("Campo")
    rc("Prefisso") = g("Prefisso") : rc("Suffisso") = g("Suffisso")
    rc("ValoreFisso") = g("ValoreFisso") : rc("MassimoCaratteri") = g("MassimoCaratteri")
    rc("SeVuoto") = g("SeVuoto")
    If Not AggiungiDati("Newexport_colonne", rc, True) Then Throw New Exception("Errore Salvataggio Colonne")
Next
```

## 5. I pulsanti e il link
- **Link** (sola lettura, sostituisce la costruzione del vecchio link di `export.aspx` (identificativo, password e nome del comparatore) in `cmbAzienda_SelectedIndexChanged` e `cmbTipoExport_SelectedIndexChanged`): `https://<Azienda>/feed.aspx?c=<TokenAccesso>`; **Copia link** copia questo testo. Nessun `&google=1`.
- **Nuovo codice**: conferma («il link attuale smettera di funzionare»), `Modexport_codice`, rileggere `TokenAccesso`. Effetto sul sito entro 60 secondi.
- **Duplica**: `Dupexport` dentro la transazione; poi riaprire l'elenco sul nuovo feed (spento).
- **Anteprima**: apre `<link>&anteprima=1` nel browser (o lo scarica e lo mostra): sono le **prime 20 righe** (xml: le prime 80) del **file pronto**, `text/plain`; l'intestazione `X-Feed-Generato` dice quando e stato generato (il file puo avere fino a `MinutiCache` minuti: dire all'utente l'ora). Se il feed non e mai stato letto, la prima richiesta lo genera (qualche secondo).
- **Abilitato**: `Abilitato = 0` spegne il link entro 60 secondi.

## 6. Controlli da fare nella maschera (stesse regole del motore: se sbagliati il feed non si genera e l'errore finisce in `UltimoErrore`)
Formato `txt`/`csv`/`tsv`/`xml` (`Tipo`); separatore di 1 o 2 caratteri e **diverso dal delimitatore**; separatore **diverso dal decimale** se il delimitatore e vuoto; delimitatore vuoto o 1 carattere; decimale `.` o `,`; codifica `utf-8`/`iso-8859-1`/`windows-1252` (l'xml e sempre utf-8); `MinutiCache` tra 15 e 1440 (fuori: il motore usa 60); per l'xml il titolo di ogni colonna e il nome di un elemento (lettere, cifre, `_`, `.`, `-`; senza spazi, due punti o prefissi; non inizia con `xml`; massimo 60 caratteri), cosi `radice` ed `elemento`; ogni `Campo` deve essere uno dei campi di `exportcampi` oppure vuoto (valore fisso); almeno una colonna.

## 7. Amazon: cosa togliere (senza cancellare dati)
`chAmazon` (casella, logo, handler `chAmazon_CheckedChanged`), il ramo `chAmazon.CheckState` di `SalvaDati` (le colonne `Google`, `Amazon`, `NoVettoreSuGratis` restano in `export` e si continuano a passare con il loro valore), la colonna Amazon dell'elenco, il logo e la casella Google, la casella «Disabilita Vettore se la spedizione e gratis». Il progetto Amazon e a parte.

## 8. Prova per Enzo (checklist)
1. Con il gestionale **vecchio** dopo lo script: nuovo feed e modifica salvano.
2. Gestionale nuovo: nuovo feed -> opzioni e colonne salvate; riaprire e ritrovarle; salvare di nuovo senza modifiche (stesso `Id` di `export_opzioni`, stesso codice).
3. Un feed creato dal gestionale vecchio: aprire, salvare -> compare la riga di opzioni con un codice.
4. Duplica, Nuovo codice, Anteprima, Copia link.
5. Cancellare un feed dall'elenco: spariscono opzioni, colonne e stato (cascata).
6. Errore a meta salvataggio (due colonne con la stessa posizione): nessun dato a meta.

## 9. Domande aperte
Il programma di allineamento porta **lo script** sugli altri database? Il chiamante di `AggiornaDb` (rigenerazione del registro) e `sysappversion.LastProcedureUpdate` sui database reali non sono visibili nel repository.
