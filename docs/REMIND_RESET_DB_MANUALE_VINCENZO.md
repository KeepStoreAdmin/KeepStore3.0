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
- Hash password non implementato.

## 4. Nuova tabella proposta

Nome tabella proposto: `login_password_reset_tokens`.

Scopo: gestire richieste reset password tramite token sicuro, monouso, con scadenza e consumo atomico.

La tabella e pensata per il database cliente/azienda che contiene `login`, non per registry esterni.

## 5. Schema tabella proposto

Script indicativo MySQL da revisionare da Vincenzo. Non eseguire automaticamente. Adattare charset, collation, naming e opzioni allo standard reale del DB cliente.

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

Nota: non inserire foreign key se lo schema storico KeepStore non le usa in modo esteso, salvo decisione esplicita di Vincenzo.

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

- `DataPassword` va aggiornata solo su reset riuscito.
- `ScadenzaPassword` resta nella logica azienda/sessione.
- Il reset riuscito deve evitare loop di cambio password se la policy aziendale lo consente.
- Verificare con Vincenzo come il gestionale usa questi campi.

## 11. Deployment multi-azienda

- La tabella va creata in ogni DB cliente/azienda che usa il sito.
- Il nome database puo cambiare in base al cliente.
- `connessioni` serve al gestionale per indirizzare il DB corretto.
- Non creare tabella nel DB `connessioni`, salvo diversa decisione.
- Non creare tabella nel DB `city_registry`.
- Serve procedura di rollout multi-database.

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

## 13. Relazione con `vlogin` e `Newlogin`

- `vlogin` e `Newlogin` sono da riconciliare tra schema versionato, DB operativo e codice.
- Il reset tokenizzato deve aggiornare il dato effettivo letto dal login.
- Prima della migrazione hash serve audit dedicato.
- Per il reset legacy iniziale basta aggiornare `login.Password` solo se confermato da Vincenzo.

## 14. Relazione con futura hash migration

- La tabella token e compatibile con hash migration.
- Oggi puo supportare update legacy.
- Domani potra chiamare adapter password per scrivere hash/salt/versione.
- Non deve mai recuperare password precedente.
- Non deve mai inviare password.

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
