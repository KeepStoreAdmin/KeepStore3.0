# Manuale tecnico DB reset password tokenizzato

## 1. Frontespizio tecnico

| Campo | Valore |
| --- | --- |
| Titolo documento | Manuale tecnico DB reset password tokenizzato |
| Progetto | KeepStore 3.0 |
| Destinatario | Vincenzo Iacobelli |
| Scopo | Proposta DB preparatoria per futuro reset password tokenizzato |
| Data | 2026-06-05 |
| Branch di riferimento | `frontend-rebuild` |
| HEAD di riferimento | `29abf63ebfc5413f1360214f8525a6580fab1b67` |
| Stato | Documento progettuale; nessuna modifica DB applicata |

Questo documento e destinato alla revisione tecnica di Vincenzo Iacobelli per valutare la futura introduzione della tabella token reset password. Non e uno script di deploy automatico e non autorizza modifiche al database.

## 1.1 Decisioni preliminari Germano

Le seguenti decisioni derivano dalla revisione manuale Germano su SQLyog/gestionale KeepStore. Non riportare valori reali visibili negli screenshot.

- Confermato nome tabella: `login_password_reset_tokens`.
- Confermati i campi generali proposti.
- Confermata la tabella `login` come riferimento operativo per la password web.
- La tabella token va creata in ogni DB cliente/azienda che usa il sito.
- Gestione FK: lasciare decisione tecnica a noi/Vincenzo; proposta no FK iniziale.
- Rollout multi-azienda da definire tecnicamente; proposta script controllato per DB cliente.
- Il gestionale oggi mostra password web in chiaro nella griglia "Accesso Utenti Web".
- Una schermata gestionale token reset sarebbe utile in futuro.
- Confermato campo `aziende.ScadenzaPassword` come policy aziendale in giorni.
- Confermata relazione funzionale: `login.DataPassword + aziende.ScadenzaPassword`.
- Scelta tecnica consigliata: Opzione B, reset tokenizzato hash-ready ma fase 1 legacy-compatible.

## 2. Scopo della modifica futura

La modifica futura dovra sostituire il vecchio reminder password con un reset tramite token monouso, evitando invio o visualizzazione di password esistenti.

Obiettivi:

- evitare invio password in chiaro;
- introdurre reset tramite token sicuro, monouso e con scadenza;
- mantenere compatibilita iniziale con password legacy;
- predisporre l'evoluzione futura verso hash migration;
- separare recupero accesso da cambio password autenticato.

## 3. Stato attuale

- `remind.aspx` oggi e recupero assistito.
- `remind.aspx` non invia password.
- `remind.aspx` non invia email reset automatica.
- Non esiste ancora una tabella token reset password.
- `password.aspx` resta la pagina di cambio password autenticato.
- `login.Password` e ancora campo legacy.
- `DataPassword` viene aggiornata su cambio password riuscito.
- `aziende.ScadenzaPassword` esiste e rappresenta la policy aziendale di scadenza password in giorni.
- Hash password non implementato.
- Il gestionale ha una griglia "Accesso Utenti Web" che visualizza anche la password web in chiaro.

## 4. Nuova tabella proposta

Nome tabella proposto: `login_password_reset_tokens`.

Scopo: gestire richieste reset password tramite token sicuro, monouso, con scadenza e consumo atomico.

La tabella e pensata per il database cliente/azienda che contiene `login`, non per registry esterni. Il DB cliente puo cambiare nome in base all'azienda; il gestionale usa `connessioni` per indirizzare il DB corretto, ma i token reset appartengono al DB operativo cliente.

## 5. Schema tabella proposto

Script indicativo MySQL da revisionare da Vincenzo. Non eseguire automaticamente. Adattare charset, collation, naming e opzioni allo standard reale del DB cliente.

Prima dell'esecuzione Vincenzo deve confermare:

- tipo effettivo di `login.id` e quindi tipo coerente di `LoginId`;
- tipo effettivo da usare per `Id`;
- charset/collation reale;
- indici;
- assenza FK iniziale;
- compatibilita MySQL reale dei DB clienti.

```sql
CREATE TABLE login_password_reset_tokens (
    Id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    LoginId INT NOT NULL,
    TokenHash CHAR(64) NOT NULL,
    CreatedAt DATETIME NOT NULL,
    ExpiresAt DATETIME NOT NULL,
    UsedAt DATETIME NULL,
    IsRevoked TINYINT(1) NOT NULL DEFAULT 0,
    RevokedAt DATETIME NULL,
    RevokedReason VARCHAR(255) NULL,
    Attempts INT NOT NULL DEFAULT 0,
    RequestIpHash CHAR(64) NULL,
    UserAgentHash CHAR(64) NULL,
    PRIMARY KEY (Id),
    UNIQUE KEY UX_login_password_reset_tokens_TokenHash (TokenHash),
    KEY IX_login_password_reset_tokens_LoginId (LoginId),
    KEY IX_login_password_reset_tokens_ExpiresAt (ExpiresAt),
    KEY IX_login_password_reset_tokens_Usable (TokenHash, UsedAt, IsRevoked, ExpiresAt)
);
```

Nota FK: non imporre foreign key nella prima fase. Usare `LoginId` come riferimento logico indicizzato verso `login.id`.

Motivazione no FK iniziale:

- lo schema storico KeepStore non usa FK in modo esteso;
- riduce rischio di blocchi in DB clienti non perfettamente allineati;
- facilita rollout multi-azienda;
- Vincenzo potra decidere in seguito se aggiungere FK dove compatibile.

FK opzionale solo dopo approvazione esplicita di Vincenzo.

## 6. Descrizione campi

| Campo | Tipo suggerito | Obbligatorio | Scopo | Note sicurezza |
| --- | --- | ---: | --- | --- |
| `Id` | `BIGINT UNSIGNED AUTO_INCREMENT` | si | PK token | nessun dato sensibile |
| `LoginId` | `INT` | si | riferimento a `login` | non esporre in URL |
| `TokenHash` | `CHAR(64)` | si | hash SHA-256 token | mai salvare token chiaro |
| `CreatedAt` | `DATETIME` | si | creazione | usare ora server DB/app |
| `ExpiresAt` | `DATETIME` | si | scadenza | consigliati 30 minuti |
| `UsedAt` | `DATETIME NULL` | no | token consumato | valorizzare su successo |
| `IsRevoked` | `TINYINT(1)` | si | revoca manuale/sistema | default 0 |
| `RevokedAt` | `DATETIME NULL` | no | data revoca | opzionale |
| `RevokedReason` | `VARCHAR(255)` | no | motivo revoca | no dati sensibili |
| `Attempts` | `INT` | si | tentativi uso token | rate limit |
| `RequestIpHash` | `CHAR(64) NULL` | no | audit IP hashato | non salvare IP chiaro se possibile |
| `UserAgentHash` | `CHAR(64) NULL` | no | audit user agent hashato | opzionale |

## 7. Regole sicurezza DB

- Salvare solo `TokenHash`.
- Token in chiaro solo nel link email.
- Token minimo 256 bit di entropia.
- Token monouso.
- Scadenza consigliata: 30 minuti.
- Consumo atomico.
- Nessun token in log.
- Nessuna password in email.
- Nessuna password in URL.
- Nessun dato personale nei log reset.
- Pulizia periodica token scaduti/usati.

## 8. Query operative indicative

Le query seguenti sono indicative, sanificate e non esecutive. Usare sempre query parametrizzate lato applicazione.

### A. Inserimento token

```sql
INSERT INTO login_password_reset_tokens
    (LoginId, TokenHash, CreatedAt, ExpiresAt, UsedAt, IsRevoked, Attempts, RequestIpHash, UserAgentHash)
VALUES
    (@LoginId, @TokenHash, NOW(), DATE_ADD(NOW(), INTERVAL 30 MINUTE), NULL, 0, 0, @RequestIpHash, @UserAgentHash);
```

### B. Lettura token valido

```sql
SELECT Id, LoginId
FROM login_password_reset_tokens
WHERE TokenHash = @TokenHash
  AND UsedAt IS NULL
  AND IsRevoked = 0
  AND ExpiresAt >= NOW()
LIMIT 1;
```

### C. Consumo token

```sql
UPDATE login_password_reset_tokens
SET UsedAt = NOW()
WHERE Id = @TokenId
  AND UsedAt IS NULL
  AND IsRevoked = 0
  AND ExpiresAt >= NOW();
```

### D. Aggiornamento password legacy iniziale

```sql
UPDATE login
SET Password = @NewPassword,
    DataPassword = NOW()
WHERE Id = @LoginId;
```

Nota obbligatoria: l'update password e legacy e dovra essere sostituito o esteso in fase hash migration.

### E. Pulizia token scaduti

```sql
DELETE FROM login_password_reset_tokens
WHERE ExpiresAt < DATE_SUB(NOW(), INTERVAL 30 DAY)
   OR UsedAt IS NOT NULL;
```

## 9. Transazione consigliata

Il reset riuscito dovrebbe essere atomico:

- validazione token;
- aggiornamento password;
- aggiornamento `DataPassword`;
- marcatura token usato.

Pseudoflusso:

1. `BEGIN`;
2. `SELECT` token valido;
3. `UPDATE login`;
4. `UPDATE token UsedAt`;
5. `COMMIT`;
6. se errore: `ROLLBACK`.

## 10. Integrazione con `DataPassword` e `ScadenzaPassword`

- `aziende.ScadenzaPassword` e la policy aziendale di scadenza password espressa in giorni.
- Esempio operativo: valore 999 significa che l'utente dovra cambiare password dopo 999 giorni dall'ultimo cambio/reset.
- `login.DataPassword` e la data dell'ultimo cambio/reset password del singolo utente.
- La logica corretta e: `login.DataPassword + aziende.ScadenzaPassword = data di scadenza password utente`.
- Il reset tokenizzato deve aggiornare `login.DataPassword = NOW()` solo dopo reset riuscito.
- Il reset tokenizzato non deve modificare `aziende.ScadenzaPassword`.
- La durata del token reset e indipendente da `aziende.ScadenzaPassword`.
- Durata token consigliata: 30 minuti.
- `ScadenzaPassword` governa la validita della password nel tempo, non la validita del link reset.
- Se il reset avviene correttamente, il ciclo di scadenza password riparte da `DataPassword`.
- Eventuali valori speciali, nulli o anomali di `ScadenzaPassword` vanno verificati nel codice esistente e con Vincenzo, senza cambiarli in questo task.

## 11. Deployment multi-azienda

- La tabella va creata in ogni DB cliente/azienda che usa il sito.
- Il nome database puo cambiare in base al cliente.
- `connessioni` serve al gestionale per indirizzare il DB corretto.
- Non creare tabella nel DB `connessioni`, salvo diversa decisione.
- Non creare tabella nel DB `city_registry`.
- Serve procedura di rollout multi-database.
- Backup del DB cliente prima del deploy.
- Script SQL idempotente o preceduto da controllo `INFORMATION_SCHEMA`.
- Esecuzione controllata su ogni DB cliente/azienda.
- Nessuna esecuzione cieca su `connessioni` o `city_registry`.
- Registrare quali DB sono stati aggiornati.
- Prevedere rollback.
- Allineare la versione gestionale/sito prima di attivare la funzione reset.
- Il deploy va coordinato da Vincenzo.

## 12. Impatto sul gestionale

Domande per Vincenzo:

- Il gestionale legge o scrive `login.Password`?
- Il gestionale crea utenti in `login`?
- Il gestionale modifica `DataPassword`?
- Il gestionale usa `ScadenzaPassword`?
- Il gestionale deve mostrare o revocare token reset?
- Il gestionale ha un proprio recupero password?
- Il gestionale usa `vlogin` o `Newlogin`?
- Il gestionale richiede aggiornamento per la tabella token?
- Come viene gestito il deploy su piu database cliente?

Compatibilita gestionale fase 1:

- Il gestionale oggi visualizza password web in chiaro nella griglia "Accesso Utenti Web".
- Quindi la fase 1 del reset tokenizzato non deve introdurre hash.
- La fase 1 deve aggiornare ancora `login.Password` legacy e `login.DataPassword`.
- Hash/salt/versione algoritmo saranno introdotti solo in task successivi.
- Prima della hash migration il gestionale dovra essere adeguato per non dipendere piu da password in chiaro.
- La visibilita della password nel gestionale e un debito tecnico da chiudere con progetto dedicato.

## 13. Relazione con `vlogin` e `Newlogin`

- `vlogin` e `Newlogin` sono da riconciliare tra schema versionato, DB operativo e codice.
- Il reset tokenizzato deve aggiornare il dato effettivo letto dal login.
- Prima della migrazione hash serve audit dedicato.
- Per il reset legacy iniziale basta aggiornare `login.Password` solo se confermato da Vincenzo.
- Germano ritiene probabile l'uso di `vlogin`.
- Non cambiare `vlogin` / `Newlogin` in questa fase.
- Se `vlogin` legge da `login.Password`, l'update legacy su `login.Password` e coerente.
- Se esistono differenze fra schema versionato, DB operativo e gestionale, Vincenzo dovra confermare.
- Ogni modifica a `vlogin` / `Newlogin` resta fuori scope e va fatta solo dopo audit dedicato.

## 14. Relazione con futura hash migration

- La tabella token e compatibile con hash migration.
- Oggi puo supportare update legacy.
- Domani potra chiamare adapter password per scrivere hash/salt/versione.
- Non deve mai recuperare password precedente.
- Non deve mai inviare password.

Debito gestionale per hash migration:

- Il gestionale oggi mostra password in chiaro.
- Questa funzionalita e incompatibile con futura hash migration.
- Nella fase hash il gestionale dovra non visualizzare piu password.
- Il gestionale non dovra pretendere di leggere password in chiaro.
- Il gestionale potra eventualmente permettere solo "imposta nuova password temporanea" o "invia link reset".
- Il workflow gestionale dovra usare reset sicuro.

## 14.1 Futura schermata gestionale token reset

Questa schermata non va implementata ora. Va progettata come task futuro: `GESTIONALE-RESET-TOKEN-UI-1A`.

Proposta menu/sezione:

- `Accesso Utenti Web`;
- oppure `Utility > Reset Password Web`.

Componente suggerito: griglia JANUS coerente con stile gestionale KeepStore.

Scopo:

- vedere richieste reset;
- filtrare token attivi/scaduti/usati/revocati;
- revocare token;
- verificare audit senza mostrare token;
- eventualmente inviare nuovo link reset in task futuro.

Colonne consigliate:

- `Id`;
- `LoginId`;
- `UserName`;
- `Email` mascherata o parzialmente oscurata;
- `CreatedAt`;
- `ExpiresAt`;
- `UsedAt`;
- `IsRevoked`;
- `RevokedAt`;
- `RevokedReason`;
- `Attempts`;
- `Stato` calcolato: Attivo, Scaduto, Usato, Revocato;
- `UltimaOperazione`.

Colonne da non mostrare:

- `TokenHash` completo;
- token in chiaro, che non deve mai stare nel DB;
- IP chiaro;
- user agent chiaro;
- password.

Azioni future:

- `Revoca token`;
- `Filtra attivi`;
- `Filtra scaduti`;
- `Filtra usati`;
- `Filtra revocati`;
- eventuale `Invia nuovo link reset`, solo dopo implementazione email sicura.

## 15. Checklist approvazione Vincenzo

- [ ] Approva nome tabella.
- [ ] Approva tipi campo.
- [ ] Approva indici.
- [ ] Approva assenza/presenza FK.
- [ ] Approva durata token.
- [ ] Approva rollout su DB clienti.
- [ ] Conferma impatto gestionale.
- [ ] Conferma query update password.
- [ ] Conferma relazione con `vlogin` / `Newlogin`.
- [ ] Conferma strategia backup/rollback.

## 16. Strategia rollback

- Backup DB prima del deploy.
- Script `DROP TABLE` solo se la tabella e appena creata e non usata.
- Se la tabella e gia usata, non droppare senza export.
- La tabella token non deve alterare tabelle esistenti.
- Rollback codice separato dal rollback DB.

## 17. Rischi e mitigazioni

| Rischio | Mitigazione |
| --- | --- |
| Token rubato | HTTPS, scadenza breve, monouso, nessun token nei log |
| Token riutilizzato | `UsedAt` valorizzato e controllo atomico |
| Enumeration | risposta generica e tempi non rivelatori |
| Email non configurata | fallback assistenza, nessun errore tecnico pubblico |
| Utente non abilitato | nessun invio reset e risposta generica |
| DB cliente non aggiornato | checklist rollout per ogni DB cliente |
| Gestionale non compatibile | approvazione Vincenzo prima di deploy |
| Differenza tra DB clienti | procedura multi-azienda con verifica post-deploy |

## 18. Decisioni richieste

A Germano:

- confermare Opzione B;
- confermare durata token 30 minuti;
- confermare testo email reset;
- confermare se attivare reset via email o solo assistito nella prima fase.

A Vincenzo:

- validare schema;
- confermare impatto gestionale;
- confermare rollout multi-azienda;
- confermare query legacy password iniziale;
- confermare strategia hash futura.

## 19. Prossimi task suggeriti

- `REMIND-RESET-DB-MANUAL-1D`: verifica manuale con Germano/Vincenzo.
- `REMIND-RESET-IMPLEMENT-1E`: implementazione reset tokenizzato senza hash.
- `REMIND-RESET-SMOKE-1F`: smoke controllato reset su PROVA.
- `PASSWORD-HASH-SCHEMA-2B`: schema hash/salt/versione.
- `PASSWORD-HASH-MIGRATION-2C`: migrazione progressiva.

## 20. Appendice

Vincoli chiave:

- nessuna password in email;
- nessun token in DB chiaro;
- nessun dato sensibile nel log;
- nessun reset tokenizzato implementato da questo documento;
- nessuna tabella creata da questo documento.

Glossario breve:

| Termine | Definizione |
| --- | --- |
| `TokenHash` | Hash del token reset; il token chiaro non viene salvato |
| `UsedAt` | Data/ora di consumo del token |
| `IsRevoked` | Flag di revoca manuale o automatica |
| `DataPassword` | Data ultimo cambio/reset password |
| `ScadenzaPassword` | Valore policy scadenza password aziendale/sessione |
| Hash migration | Migrazione da password legacy a hash/salt/versione |

## 21. Appendice operativa - Script login_password_reset_tokens

Script versionato:

- `docs/db/login_password_reset_tokens.mysql.sql`

Stato:

- script versionato nel repository;
- script non eseguito;
- DB non modificato;
- tabella `login_password_reset_tokens` non creata da Codex;
- nessun reset tokenizzato implementato;
- nessun hash implementato.

Target di esecuzione:

- eseguire solo nel DB cliente/azienda selezionato;
- esempio DB cliente/azienda: `taikun`;
- non eseguire su `connessioni`;
- non eseguire su `city_registry`;
- non eseguire su DB di registry, backup, dump o ambienti non autorizzati.

Checklist prima dell'esecuzione:

- confermare il DB cliente/azienda corretto;
- confermare backup DB verificato e ripristinabile;
- confermare versione MySQL e compatibilita charset/collation;
- verificare se `login_password_reset_tokens` esiste gia e, se esiste, confrontare struttura e indici prima di procedere;
- confermare che non saranno inseriti dati reali o token reali manualmente;
- confermare che nessun runtime KeepStore dipende ancora dalla tabella;
- confermare approvazione Germano e approvazione tecnica Vincenzo.

Checklist di esecuzione:

- selezionare manualmente nel client SQL il DB cliente/azienda corretto;
- eseguire solo lo script approvato `docs/db/login_password_reset_tokens.mysql.sql`;
- non eseguire script modificati al volo senza nuova approvazione;
- non fare `INSERT` manuali nella tabella;
- non modificare `login.Password`;
- non modificare `login.DataPassword`;
- non modificare `aziende.ScadenzaPassword`;
- non creare foreign key obbligatorie nella fase 1.

Checklist post-esecuzione:

```sql
SHOW TABLES LIKE 'login_password_reset_tokens';
SHOW CREATE TABLE login_password_reset_tokens;
SELECT COUNT(*) FROM login_password_reset_tokens;
```

Esito atteso subito dopo la creazione:

- la tabella e presente;
- `SHOW CREATE TABLE` corrisponde allo script approvato o alle eventuali variazioni tecniche autorizzate da Vincenzo;
- `SELECT COUNT(*)` restituisce `0`;
- nessun token reale e presente;
- nessun dato personale e presente;
- evidenza tecnica salvata senza password, token, hash reali, email reali, IP reali, connection string o dati cliente.

Esito gate DB `taikun` comunicato da Germano:

- esecuzione manuale controllata completata su SQLyog Ultimate 64;
- backup effettuato;
- tabella `login_password_reset_tokens` creata sul DB `taikun`;
- `SHOW TABLES` OK;
- `SHOW CREATE TABLE` coerente;
- `SELECT COUNT(*)` pari a `0` subito dopo la creazione;
- nessuna anomalia comunicata;
- nessun dato reale inserito;
- nessun token reale inserito;
- runtime reset tokenizzato non ancora implementato al momento del gate DB;
- fase runtime successiva da eseguire solo su branch dedicato.

Nota finale dopo runtime fase 1:

- La tabella `login_password_reset_tokens` risulta gia creata sul DB `taikun` tramite esecuzione manuale controllata, non da Codex.
- Il runtime reset password tokenizzato fase 1 e completato in modalita legacy-compatible.
- Nessun dato/token reale e stato inserito manualmente nella tabella durante il gate documentato.
- La tabella era vuota subito dopo la creazione; i token runtime devono restare gestiti solo dal codice applicativo.
- Nessuna ulteriore modifica DB/schema e stata eseguita da Codex in questa chiusura documentale.
- Hash migration rimandata a task futuro coordinato con Vincenzo/gestionale.

Criterio di approvazione:

- Germano approva la consegna operativa;
- Vincenzo approva ed eventualmente esegue lo script sul DB cliente/azienda corretto;
- solo dopo conferma della creazione tabella e verifica post-esecuzione si puo aprire il task runtime `REMIND-RESET-IMPLEMENT-1E` o equivalente per reset tokenizzato fase 1.

Nota sicurezza:

- il token in chiaro dovra esistere solo nel futuro link email di reset;
- il DB dovra contenere solo `TokenHash`;
- non inserire token reali in documenti, log, issue, PR o report;
- non riportare password, hash reali, cookie, session id, email reali, IP reali o dati personali nelle evidenze.
