# Limite ai tentativi sulla password: tabella `login_attempt_limits`

`AUTH-ATTEMPT-LIMIT-1A`. Decisione del PO del 2026-11-24: tabella nuova autorizzata purche non tocchi nulla di quello che esiste. Questa pagina serve al PO (che applica lo script **solo su `taikun`**) e a Enzo (il cui programma di allineamento la porta sugli altri database). Un solo script, identico per ogni database: nessun nome di database, nessun account, nessun `DEFINER`.

**Stato: script NON applicato a nessun database reale.** Provato sul LAB locale dal test `Tools/Test-AuthAttemptLimit.ps1`, che crea la tabella leggendo lo script di questa pagina. Finche la tabella non esiste il sito si comporta come prima (nessun limite) e scrive una riga nel registro `App_Data/Logs/auth-attempt-limit.log` (al massimo una ogni 10 minuti).

## 1. Che cosa fa il limite
- **Accesso:** dopo 5 password sbagliate in 15 minuti sullo stesso accesso, per 15 minuti il sito risponde «Troppi tentativi» **anche con la password giusta**. Chi ricade nel blocco entro 24 ore ne ha uno di 30 minuti, poi di 60 (tetto). Mai un blocco permanente: la casella `Abilitato` del pannello resta il solo blocco permanente.
- **Cambio password e cambio e-mail** (pagine con la password attuale): stesso limite, un solo conteggio condiviso fra le due pagine.
- **Recupero password:** completare il recupero (codice ricevuto per e-mail dal titolare) toglie subito il blocco dell'accesso.
- **Non cambia:** nessuna colonna di `login`, `utenti` o altra tabella; nessuna routine, vista o trigger; il gestionale e il pannello «Accesso Utenti Web» non sanno che la tabella esiste e non la leggono. Il limite NON copre una password provata su molti accessi diversi (compito a parte, dopo la misura sugli indirizzi) ne il «Resta collegato» (non confronta password).

## 2. Che cosa contiene la tabella
Una riga per ogni accesso con tentativi recenti. **Nessun nome utente, nessuna password, nessun indirizzo:** solo un'impronta. Le righe vecchie si cancellano da sole (oltre 48 ore e mai un blocco attivo).

| Campo | Tipo | Predefinito | NULL | Significato |
| --- | --- | --- | --- | --- |
| `AziendeId` | `INT` | nessuno | no | Azienda del sito su cui avviene il tentativo |
| `ScopeCode` | `TINYINT` | nessuno | no | 1 accesso, 2 password attuale (cambio password o e-mail), 3 nome utente inesistente, 4 riservato (indirizzo, non usato) |
| `KeyHash` | `CHAR(64)` ascii | nessuno | no | Impronta SHA-256 della chiave (identificativo dell'accesso o nome digitato in minuscolo) |
| `FailCount` | `INT` | 0 | no | Errori presunti nella finestra corrente |
| `WindowStartUtc` | `DATETIME` | nessuno | no | Inizio della finestra di 15 minuti (ora UTC del database) |
| `BlockedUntilUtc` | `DATETIME` | NULL | si | Fine del blocco; vuoto se non bloccato |
| `StrikeLevel` | `TINYINT` | 0 | no | Ricadute: 0 poi 15 minuti, 1 poi 30, 2 poi 60 |
| `StrikeExpiresUtc` | `DATETIME` | NULL | si | Quando il livello torna a 0 (24 ore dopo l'ultimo blocco) |
| `UpdatedUtc` | `DATETIME` | nessuno | no | Ultima scrittura; serve alla pulizia |

Chiave primaria: `(AziendeId, ScopeCode, KeyHash)`.

## 3. Verifica prima (sola lettura)
Deve restituire 0: la tabella non esiste ancora.
```sql
SELECT COUNT(*) AS gia_presente FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'login_attempt_limits';
```

## 4. Creazione
```sql
CREATE TABLE IF NOT EXISTS login_attempt_limits (
  AziendeId INT NOT NULL,
  ScopeCode TINYINT NOT NULL,
  KeyHash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  FailCount INT NOT NULL DEFAULT 0,
  WindowStartUtc DATETIME NOT NULL,
  BlockedUntilUtc DATETIME NULL DEFAULT NULL,
  StrikeLevel TINYINT NOT NULL DEFAULT 0,
  StrikeExpiresUtc DATETIME NULL DEFAULT NULL,
  UpdatedUtc DATETIME NOT NULL,
  PRIMARY KEY (AziendeId, ScopeCode, KeyHash),
  KEY idx_login_attempt_limits_updated (UpdatedUtc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Nessuna chiave esterna, come per `login_password_reset_tokens`. L'account del sito deve poter fare `SELECT`, `INSERT`, `UPDATE`, `DELETE` su questa tabella (stessi privilegi che ha gia su `login_password_reset_tokens`).

## 5. Verifica dopo (sola lettura)
Deve restituire 9 colonne e due indici (`PRIMARY` su tre colonne e `idx_login_attempt_limits_updated`).
```sql
SELECT COUNT(*) AS colonne FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'login_attempt_limits';
SELECT INDEX_NAME, NON_UNIQUE, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS colonne FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'login_attempt_limits' GROUP BY INDEX_NAME;
```

## 6. Assistenza: un cliente dice di essere bloccato
Il blocco dura al massimo 15, 30 o 60 minuti e finisce da solo; il cliente puo anche usare «Password dimenticata». Per vedere quanti blocchi sono attivi (nessun dato personale):
```sql
SELECT AziendeId, ScopeCode, COUNT(*) AS bloccati FROM login_attempt_limits WHERE BlockedUntilUtc > UTC_TIMESTAMP() GROUP BY AziendeId, ScopeCode;
```
Per togliere tutti i blocchi in caso di emergenza (il sito riparte da zero, nessun'altra conseguenza):
```sql
DELETE FROM login_attempt_limits;
```
Per spegnere il limite senza togliere la tabella, aggiungere nel `web.config` del sito la chiave `KeepStore.AuthAttemptLimit.Enabled` con valore `false` (sezione `appSettings`).

## 7. Ritorno indietro
Togliere la tabella spegne il limite: il sito torna a comportarsi come prima. Nessun altro dato dipende da questa tabella.
```sql
DROP TABLE IF EXISTS login_attempt_limits;
```
