# KeepStore - manuale operativo della catena ordini (`ORDER_CHAIN_UNIVERSAL_1A`)

Valido per **ogni database KeepStore**: stessi file, stessi passi, nessun nome di database o di cliente. Cambiano solo i valori che l'operatore legge dal preflight. Regola generale: [AGENTS](../AGENTS.md#multitenant-by-design), paragrafo «Schema unico, codice standard e universale».

**Stato.** Provata sul LAB e **dal PO con SQLyog su una copia debug del suo database sul server online** (forward, verify, rollback, secondo forward, verify: vedi Masterplan `KS-DB-ORDER-CHAIN-DEBUG-REHEARSAL-1A`); **applicata dal PO anche a `taikun`**, il suo database funzionale sul server online (forward e verify 99 OK, poi un ordine web reale coerente: Masterplan `KS-GOV-ALIGN-PROGRAM-1A`). **Piano dal 2026-11-13 (sera):** le modifiche si applicano soltanto su `taikun` e gli altri database li allinea il programma di allineamento di Enzo, che imposta l'account esatto per ogni nome di database; questa procedura manuale resta valida per `taikun`, per le copie di prova e per un database fuori dal programma, sempre con il via esplicito del PO. CONSEGNA SERVER SOSPESA.

**Ambiente provato.** MySQL 8.0.17 o successivo (obbligatorio: lo script lo controlla; LAB 8.0.46; copia debug del PO su 8.0.42 con SQLyog), routine con coppia di caratteri `utf8mb3`/`utf8mb3_general_ci` oppure `utf8mb4`/`utf8mb4_0900_ai_ci`. Su MySQL 5.7, MariaDB o altre coppie i controlli si fermano (STOP) per costruzione: la compatibilita va provata prima, non si forza.

## Cosa fa
Porta un database dal livello **iniziale** (routine `Carrello_Documento` = corpo di `ORDER_INVENTORY_ATOMIC_RESERVATION`, installato dal 2026-09-12, qualunque fine riga) al livello **finale**, in un solo passaggio:

- crea `Carrello_Totali` (sola lettura: unica fonte dell'aritmetica del totale del documento);
- sostituisce `Carrello_Documento` (stessi 19 parametri) con la versione che include: IVA riga scritta come id (P1), numero documento restituito (P0b), arrotondamento half-up sul riepilogo, totali presi da `Carrello_Totali`;
- conserva `DEFINER`, set di caratteri e collation originali della routine.

Il web nuovo (carrello che legge `Carrello_Totali`) funziona solo dopo questo passaggio; senza, mostra «n/d» e il checkout si ferma in modo chiuso.

## File (cartella `Database Taikun/Migrations/`)
| File | Scrive? | A cosa serve |
|---|---|---|
| `20261113_ORDER_CHAIN_UNIVERSAL_1A_preflight.sql` | no | controlli e valori da copiare; riga 99 deve essere OK |
| `20261113_ORDER_CHAIN_UNIVERSAL_1A_forward.sql` | **si** | esegue il passaggio |
| `20261113_ORDER_CHAIN_UNIVERSAL_1A_verify.sql` | no | conferma il livello finale; riga 99 deve essere OK |
| `20261113_ORDER_CHAIN_UNIVERSAL_1A_rollback.sql` | **si** | torna al livello iniziale, anche da uno stato parziale |

## Prima di toccare un database (sempre)
1. **Interruzione sugli errori in SQLyog.** Nelle preferenze abilita *Halt Execution of Queries on Error* (interrompi l'esecuzione delle query in caso di errore). Senza questa opzione una guardia che dice STOP **non** ferma i comandi seguenti, compresi i DROP. Prova: esegui `SELECT * FROM information_schema.KEEPSTORE_STOP_TEST;` seguito da `SELECT 'NON DEVE APPARIRE';`: deve comparire l'errore e **non** la seconda riga.
2. **Dopo qualunque STOP o errore chiudi la connessione** (disconnetti e riconnetti) prima di eseguire altro: la sessione resta con SQL mode, set di caratteri e variabili temporanei dello script interrotto.
3. **Finestra di manutenzione**: checkout chiuso (nessun ordine in corso), sito in manutenzione o chiuso agli acquisti.
4. **Backup privato** del testo esatto: in SQLyog `SHOW CREATE PROCEDURE Carrello_Documento;`, copia la colonna `Create Procedure` in un file privato fuori dal repository, rileggilo. Annota anche i **permessi di routine** (diagnosi, riga 08: normalmente nessuno).
5. **Via del PO per quel database**, per iscritto in chat.

## Passi
1. Apri il **preflight**, seleziona il database nella barra di SQLyog, `Ctrl+A`, `F9`. Leggi la griglia:
   - riga 01: database, versione, **UUID del server**;
   - riga 03: **il literal del DEFINER** (esempio `` `utente`@`host` ``): copialo;
   - righe 10-20 e **99: tutte OK**. Se una riga e STOP, non proseguire e manda la griglia a Claude.
2. Apri il **forward** in una scheda nuova e fai due cose nel testo, prima di eseguirlo:
   - `Modifica > Sostituisci` (`Ctrl+H`): cerca `__KEEPSTORE_ORIGINAL_DEFINER__`, sostituisci con il literal della riga 03, **Sostituisci tutto**. Questo e l'unico valore che cambia da database a database: MySQL non permette di leggere il DEFINER dentro `CREATE PROCEDURE` (errore 1295, provato), quindi lo si inserisce una volta. Lo script lo confronta con la routine installata **prima di cancellare qualunque cosa**, controlla `Carrello_Totali` appena creata contro il DEFINER originale **prima del DROP**, e a fine lavoro controlla entrambe le routine nuove contro lo stesso originale.
   - in cima al file aggiungi (una sola volta, con i valori letti nel preflight):
     ```sql
     SET @KeepStoreRoutineBackupVerified=1;
     SET @KeepStoreCheckoutQuiesced=1;
     SET @KeepStoreExpectedServerUuid='<UUID della riga 01>';
     SET @KeepStoreExpectedDatabase='<database della riga 01>';
     ```
     Metti `1` solo se backup e checkout chiuso sono **veri**: le variabili non sostituiscono i controlli, li confermano.
3. Esegui tutto il forward (`Ctrl+A`, `F9`). Esito atteso: `ORDER_CHAIN_FORWARD_PRECHECK_A`, `ORDER_CHAIN_DEFINER_SLOT_A`, `ORDER_CHAIN_TOTALI_DEFINER_A`, `ORDER_CHAIN_FORWARD_A`.
4. Esegui il **verify**: riga 99 OK; le righe 02-04 mostrano DEFINER, set di caratteri e impronta di entrambe le routine (il DEFINER deve essere quello del literal del preflight).
5. **Permessi: gate esplicito.** Il verify non vede i permessi a livello di routine (il DROP li elimina). Confrontali con la nota presa prima (diagnosi, righe 08-09): per i database dove il web ha `Execute` a livello di database non cambia nulla; se c'erano permessi di routine vanno riapplicati e riverificati. **Non riaprire il checkout senza questo confronto**, anche con il verify tutto OK.
6. Riapri il checkout solo dopo il verify OK e il confronto dei permessi; un ordine di prova solo se il PO lo autorizza.

## Se qualcosa si ferma
| Cosa vedi | Significato | Cosa fare |
|---|---|---|
| `Unknown table 'KEEPSTORE_STOP_ORDER_CHAIN_PRECONDITION'` | una guardia ha detto STOP | dipende da quale: vedi le righe sotto; se e la prima guardia nulla e cambiato |
| errore alla creazione di `ks_chain_definer_probe` | segnaposto non sostituito, account sbagliato o privilegio mancante (`SET_USER_ID`/`SUPER`) | nulla e stato cancellato; chiudi la connessione, correggi, riparti |
| STOP subito dopo `ORDER_CHAIN_FORWARD_PRECHECK_A`, senza `ORDER_CHAIN_DEFINER_SLOT_A` | il DEFINER inserito non e quello della routine installata | nulla e stato cancellato; usa il literal della riga 03 del preflight |
| STOP dopo `ORDER_CHAIN_DEFINER_SLOT_A` ma **senza** `ORDER_CHAIN_TOTALI_DEFINER_A` | `Carrello_Totali` e stata creata con un DEFINER diverso dall'originale; `Carrello_Documento` e ancora quella vecchia | stato **parziale A**: esegui il **rollback** (rimuove `Carrello_Totali`) oppure `DROP PROCEDURE Carrello_Totali;`, poi correggi e riparti |
| errore **dopo** `DROP PROCEDURE Carrello_Documento` | `Carrello_Documento` puo mancare (stato **parziale B**) | **non riaprire il checkout**; esegui il **rollback** (riparte anche da routine mancante, usando DEFINER e set di caratteri di `Carrello_Totali`), oppure ricrea dal backup privato; poi preflight o verify |
| STOP a fine forward (`ORDER_CHAIN_FORWARD_A` mancante) | le routine nuove non hanno il DEFINER originale o il testo atteso | non riaprire il checkout; esegui il rollback e manda la griglia a Claude |
| errore di connessione a meta | sessione persa dopo un passo | chiudi tutto, esegui il preflight o il verify per vedere lo stato; se `Carrello_Totali` esiste e `Carrello_Documento` e quella vecchia (stato A) o manca (stato B) segui le righe sopra |

## Rollback
Stessa procedura (`Sostituisci tutto` del DEFINER, con il literal della riga 03 del **verify** o del preflight, e le quattro variabili in cima) con il file `rollback`. Parte dal livello finale e anche dagli stati parziali A e B. Elimina `Carrello_Totali` e ricrea `Carrello_Documento` con il corpo iniziale, conservando DEFINER e metadati letti da `Carrello_Totali`. Il testo ripristinato e uguale **in codice** all'originale; byte per byte solo il backup privato lo riproduce se l'originale era formattato diversamente. Le pagine web nuove mostrano «n/d» finche non si riesegue il forward.

## Limiti dichiarati
- Provata su MySQL 8.0.46 (LAB, routine «ombra»: i totali scritti da 56 casi coincidono byte per byte con quelli della routine reale del LAB allo stesso livello) e su MySQL 8.0.42 con SQLyog (copia debug del PO). Non provata su MySQL 5.7 o MariaDB (il controllo della versione le rifiuta), ne con test di concorrenza rieseguito (il corpo finale e lo stesso gia provato), ne con i permessi di routine prima e dopo (saltati sulla copia debug).
- Il testo di entrambe le routine (iniziale e finale) si confronta in **forma canonica**: fine riga CRLF come LF, spazi a fine riga e righe vuote ignorati; un CR isolato no. Motivo, provato sulla copia debug del PO: **SQLyog toglie le righe vuote** quando esegue uno script (`Carrello_Documento` 11.428 caratteri invece di 11.460, `Carrello_Totali` 1.551 invece di 1.552) e usa LF, quindi il testo memorizzato differisce dal file ma il codice e lo stesso. I testi iniziali accettati sono **tre** forme canoniche derivate dal solo corpo `ORDER_INVENTORY_ATOMIC_RESERVATION` (con commenti; con l'ultima riga senza rientro; senza commenti, cioe come lo memorizza il client `mysql`, anche con gli spazi a fine riga tolti). Una modifica di **codice**, anche di una cifra, o una riga in piu con del codice, si ferma. Il confronto usa `REGEXP_REPLACE`, che dalla 8.0.17 restituisce testo UTF-8: sotto quella versione, o su MariaDB, il controllo iniziale dice STOP. Limite noto: la forma canonica renderebbe uguali due literal di stringa multi-riga diversi; nessun corpo ne ha (lo verifica il test statico) e va ricontrollato se un corpo cambia.
- Non certifica IIS, il sito pubblico ne la produzione. Restano le domande per Enzo (differenza negativa, riconciliazione della fattura elettronica per aliquota, comportamento di `controllaArrotondamento`) prima del server online.
- I file contengono un solo segnaposto per il DEFINER: e l'unica eccezione alla regola «nessuna sostituzione nel testo», imposta dal limite di MySQL descritto sopra.
