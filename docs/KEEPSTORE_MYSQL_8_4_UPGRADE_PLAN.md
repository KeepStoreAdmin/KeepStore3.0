# KeepStore - passaggio del database a MySQL 8.4 LTS: fatti, rischi e piano (DB-MYSQL-8-4-UPGRADE-1A)

Stato: **NON AVVIATO** (solo documentato il 24/11/2026). Richiesta del PO (24/11/2026): valutare con Enzo il passaggio da MySQL 8.0 a **MySQL 8.4 LTS** (ultima patch, oggi 8.4.13), con .NET Framework 4.8, e capire se il sito funziona lo stesso o servono modifiche. Il PO ha deciso di **documentare tutto adesso** e di procedere in seguito ai punti 2, 3 e 4. Nessun codice, database, server o configurazione e stato toccato.

## 1. Autorizzazioni

- **Concessa dal PO (24/11/2026), per quando il task si apre:** installare sul PC di sviluppo MySQL 8.4 dal pacchetto scaricato in `C:\KeepStoreWeb\mysql-8.4.13.1-winx64-debug-test` come **seconda istanza LAB**, senza toccare l'istanza LAB attuale (MySQL 8.0.46, porta 13317, vedi [registro del LAB](KEEPSTORE_LAB_DB_OPERATING_RECORD.md)).
- **Non concessa (serve un mandato distinto):** qualsiasi operazione sul server di produzione (aggiornamento sul posto, modifica del file di configurazione, account, riavvii), sostituzione delle librerie nella cartella `Bin` del sito (il connettore), pubblicazione in produzione. Letture sul server vero: solo quelle che Enzo esegue di sua mano.

## 2. Fatti acquisiti (24/11/2026)

**Produzione** (risultato della SELECT eseguita da Enzo): MySQL Community Server **8.0.42**; `sql_mode` = `STRICT_TRANS_TABLES, NO_ZERO_IN_DATE, NO_ZERO_DATE, ERROR_FOR_DIVISION_BY_ZERO, NO_ENGINE_SUBSTITUTION` (**senza `ONLY_FULL_GROUP_BY`**); set di caratteri del server `utf8mb4`; `tls_version` TLSv1.2,TLSv1.3; `require_secure_transport` = 0. La versione di partenza e una 8.0 recente: il passaggio diretto 8.0 -> 8.4 e il percorso previsto da MySQL. **Ancora sconosciuti:** gli account e i loro tipi di password, il contenuto del file di configurazione, i nomi riservati nel database vero, strumenti di backup e replica.

**LAB (copia del database di produzione del 17/11/2026, MySQL 8.0.46):** `sql_mode` con `ONLY_FULL_GROUP_BY` (il LAB e piu severo della produzione: query che passano nel LAB passano anche in produzione, non viceversa). 639 routine, 22 trigger, 159 viste, 284 tabelle, tutte InnoDB (set di caratteri: 207 tabelle latin1, 59 utf8mb3, 17 utf8mb4, 1 ascii).

**Software:**

| Parte | Versione trovata |
|---|---|
| Sito (cartella `Bin`) | `MySql.Data` **8.0.33** (con BouncyCastle 2.7, Google.Protobuf 3.19.1), .NET Framework 4.8 |
| Gestionale (repository `KeepStoreRepo`, sola lettura) | `MySql.Data` **9.7.0**, .NET Framework 4.8; usa `AllowPublicKeyRetrieval=True` e `SslMode=Preferred` (segno che almeno alcuni account usano la password nuova `caching_sha2_password`) |
| Collegamento del sito | `pooling=false`, SSL predefinito (Preferred), `Allow Zero Datetime`/`Convert Zero Datetime` attivi |

**Scansioni gia fatte (nessuna modifica):**
- **Codice del sito e migrazioni:** nessun uso di funzioni rimosse o cambiate in 8.4 (`SQL_CALC_FOUND_ROWS`, `FOUND_ROWS()`, sintassi vecchia di replica `CHANGE MASTER`/`SLAVE`, `PASSWORD()`, `mysql_native_password`, `default_authentication_plugin`, `tx_isolation`, `query_cache`, `SET NAMES`, `sql_mode` impostato dal codice). Le sole impostazioni di sessione del sito sono `innodb_lock_wait_timeout` (valido in 8.4).
- **Nomi riservati dalla 8.4** (`MANUAL`, `PARALLEL`, `QUALIFY`, `TABLESAMPLE`): nessuna tabella, colonna, routine, trigger o vista del LAB li usa come nome ne li contiene nel testo. Va ripetuto sul database vero.
- **.NET Framework 4.8** non e un problema: la versione del database e indipendente da .NET; conta il connettore. `MySql.Data` 8.0.33 funziona su 4.8 e conosce `caching_sha2_password`, ma e **precedente alla 8.4 e non certificato** con essa: da provare.

**Pacchetto scaricato dal PO (controllato senza eseguirlo):** `mysql-8.4.13.1-winx64-debug-test.zip`, estratto in `C:\KeepStoreWeb\mysql-8.4.13.1-winx64-debug-test\mysql-8.4.13.1-winx64` (2,2 GB). E il pacchetto **«Debug Binaries & Test Suite»**: contiene solo `mysqld-debug.exe` (server in versione debug, piu lento, con controlli interni), i file dei simboli (`.pdb`) e la suite di test, e **non contiene** la cartella `share` (messaggi di errore e set di caratteri, indispensabili per avviare il server) ne i programmi client (`mysql.exe`, `mysqldump.exe`, `mysqladmin.exe`: ci sono solo i `.pdb`). **Da solo non basta per avviare un'istanza.** Serve anche lo ZIP standard «Windows (x86, 64-bit), ZIP Archive» della stessa versione (`mysql-8.4.13.1-winx64.zip`), da scaricare dalla pagina ufficiale e da estrarre in una cartella separata. Con lo ZIP standard si fa la prova di compatibilita (binari normali); il pacchetto debug serve solo per diagnosi e **non va mai usato per misurare i tempi ne per la produzione**.

## 3. Rischi (dal piu serio) e stato

1. **Account con `mysql_native_password`:** in 8.4 questo sistema di password e **spento di default**; un account che lo usa non si collega piu dopo l'aggiornamento (a meno di riattivarlo nel file di configurazione o ricreare l'account con `caching_sha2_password`). Va controllato per ogni account usato da sito, gestionale, programma di allineamento di Enzo e strumenti di backup. **Stato: da verificare** (SELECT 2 sotto).
2. **File di configurazione del server (`my.ini`/`my.cnf`):** opzioni eliminate in 8.4 (per esempio `default_authentication_plugin`, vecchie opzioni di replica e registro) impediscono l'avvio. Da leggere con Enzo prima dell'aggiornamento.
3. **`sql_mode` diverso fra produzione e LAB:** in produzione manca `ONLY_FULL_GROUP_BY`, che la 8.4 (come la 8.0) ha nelle impostazioni predefinite. Se dopo l'aggiornamento il file di configurazione non conserva il `sql_mode` attuale, le query scritte con un `GROUP BY` non rigoroso (il sito ne ha avute: wishlist corretta con PR 661; `listini.aspx`, in standby, e altre pagine storiche) iniziano a dare l'errore 1055. **Regola per il passaggio:** mantenere identico il `sql_mode` di produzione nel nuovo file di configurazione, e provare comunque il sito anche con `ONLY_FULL_GROUP_BY` (e il LAB lo fa gia).
4. **Connettore 8.0.33 non certificato con 8.4:** probabile compatibilita, nessuna garanzia. Se la prova fallisce o per prudenza, aggiornare `MySql.Data` a una 8.4.x (sono sostituzioni nella cartella `Bin`, con le librerie collegate: richiedono approvazione del PO, backup della cartella e test).
5. **Replica e backup:** i comandi vecchi della replica (`CHANGE MASTER`, `START SLAVE`, `SHOW SLAVE STATUS`) sono stati eliminati; script di backup o replica di Enzo possono rompersi. Da inventariare.
6. **Strumenti di Enzo** (per esempio SQLyog): devono essere abbastanza recenti per la password nuova e per la 8.4.
7. **Prestazioni:** alcune impostazioni predefinite del motore cambiano; da misurare, non da presumere. Nota: `pooling=false` (ogni richiesta apre una connessione nuova, con negoziazione TLS e verifica della password) pesa di piu con `caching_sha2_password`; e una causa gia nota di lentezza del sito, da riesaminare dopo l'aggiornamento.
8. **Ritorno indietro:** dopo l'aggiornamento sul posto l'archivio dati non si riporta alla 8.0; l'unico ritorno e il ripristino di un backup completo (database, routine, trigger, eventi, account). Da provare prima.
9. **Piu database sullo stesso server:** l'aggiornamento riguarda tutti insieme (schema unico per tutti i clienti, vedi regola dello schema universale): la prova va fatta sul server intero, non solo su `taikun`.

## 4. Piano per fasi (le fasi 2-4 partono quando il PO apre il task)

**Fase 1 - Controlli sul server vero (Enzo, solo lettura). Parzialmente fatta.** Fatta: SELECT della versione. **Da fare:**

```sql
SELECT user, host, plugin FROM mysql.user ORDER BY plugin, user;
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS WHERE UPPER(COLUMN_NAME) IN ('MANUAL','PARALLEL','QUALIFY','TABLESAMPLE');
SELECT ROUTINE_SCHEMA, ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_DEFINITION REGEXP '\\b(manual|parallel|qualify|tablesample)\\b';
```

Poi: copia del file di configurazione (senza password), strumenti di backup e replica in uso, elenco dei database sullo stesso server, sistema operativo e protocolli TLS del server web, versioni di SQLyog e del gestionale. In piu, lo strumento ufficiale di MySQL Shell `util.checkForServerUpgrade` con destinazione 8.4.13 sulla copia del database.

**Fase 2 - Seconda istanza MySQL 8.4 sul PC (CODE, autorizzata dal PO).** Prerequisito: lo ZIP standard (punto 2). Proposta: cartella dati fuori dal repository (stessa struttura dell'istanza LAB attuale), solo `127.0.0.1` su una porta diversa da 13317 (proposta 13318), TLS con certificato autofirmato, account di prova con `caching_sha2_password`, nessuna modifica all'istanza 8.0.46, ai servizi, al firewall o alle ACL. Ripristino del database copia, **una volta sola** (un solo script identico per ogni database, nessun nome scritto nel corpo). Prima di ogni scrittura: verifica dell'identita dell'istanza (porta, cartella dati, UUID).

**Fase 3 - Prove contro la 8.4 (CODE).** Tutte le prove del LAB (catena ordini, totali e arrotondamenti, carrello, listino, PayPal, pagina del listino scaricabile) rieseguite sull'istanza 8.4: con il `sql_mode` di produzione e con quello rigoroso; sito di prova collegato alla 8.4 con il connettore 8.0.33 e, in alternativa, con una 8.4.x. Confronto delle risposte e dei tempi (con i binari normali, non debug). Elenco di ogni difetto e correzione minima.

**Fase 4 - Piano di passaggio (CODE con Enzo, mandato distinto).** Backup completo provato in ripristino, ordine delle operazioni, finestra di manutenzione, account sistemati prima, file di configurazione nuovo con `sql_mode` invariato, controlli dopo l'avvio, piano di ritorno e comunicazione. L'esecuzione sul server di produzione resta di Enzo; CODE non opera sul server.

## 5. Criteri di successo

- Nessun account resta senza accesso; tutte le prove del LAB passano sulla 8.4 in entrambe le modalita di `sql_mode`; il sito di prova funziona con il connettore scelto; backup ripristinato con successo; tempi non peggiori in modo apprezzabile; elenco scritto delle modifiche necessarie al codice (se ce ne sono) e dei limiti di prova.

## 6. Riferimenti

[Registro del LAB](KEEPSTORE_LAB_DB_OPERATING_RECORD.md), [regola dello schema unico](KEEPSTORE_UNIVERSAL_STANDARD_CODE_RULE_2026_11_13.md), [standard dei segreti](KEEPSTORE_SECRET_PROTECTION_STANDARD.md), [ambiente locale](KEEPSTORE_LOCAL_IIS_ENVIRONMENT.md). La versione di partenza e le impostazioni del server vero restano fuori dal repository (nessun indirizzo, porta, account o password in questo documento).
