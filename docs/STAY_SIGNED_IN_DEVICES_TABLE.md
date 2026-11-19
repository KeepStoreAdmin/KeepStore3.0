# «Resta collegato»: tabella dei dispositivi ricordati

`AUTH-STAY-SIGNED-IN-2A`. Decisione del PO del 2026-11-19: tabella nuova autorizzata, durata 30 giorni dall'ultimo uso. Questa pagina serve al PO (che applica lo script **solo su `taikun`**) e a Enzo (il programma di allineamento porta la tabella sugli altri database). Codice: `App_Code/KeepStoreStaySignedIn.vb`.

**Stato: script NON applicato a nessun database reale.** Provato sul LAB locale dal test `Tools/Test-StaySignedIn.ps1`, che crea la tabella leggendo lo script di questa pagina.

## 1. Che cosa contiene la tabella
Una riga per ogni dispositivo su cui un cliente ha scelto «Resta collegato». **Non contiene password ne dati personali**: solo impronte non reversibili.

| Campo | Tipo | Predefinito | NULL | Significato |
| --- | --- | --- | --- | --- |
| `id` | `BIGINT`, contatore | automatico | no | Chiave della riga |
| `LoginId` | `INT` | nessuno | no | `login.id` del cliente |
| `AziendeId` | `INT` | nessuno | no | Azienda del sito su cui il dispositivo e stato ricordato |
| `TokenHash` | `CHAR(64)` ascii | nessuno | no | Impronta SHA-256 del codice custodito nel cookie del browser; unica |
| `CredentialStamp` | `CHAR(64)` ascii | nessuno | no | Impronta di controllo di utente, nome utente e password al momento del ricordo: se uno di questi cambia, il dispositivo non vale piu |
| `CreatedUtc` | `DATETIME` | nessuno | no | Quando il dispositivo e stato ricordato (ora UTC) |
| `LastUsedUtc` | `DATETIME` | nessuno | no | Ultimo uso registrato (aggiornato al massimo una volta ogni 24 ore) |
| `ExpiresUtc` | `DATETIME` | nessuno | no | Scadenza: 30 giorni dopo l'ultimo uso |
| `RevokedUtc` | `DATETIME` | NULL | si | Quando e stato annullato (uscita, cambio password, limite, controllo fallito) |
| `RevokeReason` | `VARCHAR(20)` | NULL | si | Motivo in una parola: `logout`, `password`, `credentials`, `account`, `limit`, `replaced` |

## 2. Verifica prima (sola lettura)
Deve restituire 0: la tabella non esiste ancora.
```sql
SELECT COUNT(*) AS gia_presente FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'login_remembered_devices';
```

## 3. Creazione
```sql
CREATE TABLE IF NOT EXISTS login_remembered_devices (
  id BIGINT NOT NULL AUTO_INCREMENT,
  LoginId INT NOT NULL,
  AziendeId INT NOT NULL,
  TokenHash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  CredentialStamp CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  CreatedUtc DATETIME NOT NULL,
  LastUsedUtc DATETIME NOT NULL,
  ExpiresUtc DATETIME NOT NULL,
  RevokedUtc DATETIME NULL DEFAULT NULL,
  RevokeReason VARCHAR(20) CHARACTER SET ascii COLLATE ascii_general_ci NULL DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_login_remembered_devices_tokenhash (TokenHash),
  KEY idx_login_remembered_devices_login (LoginId, RevokedUtc),
  KEY idx_login_remembered_devices_expires (ExpiresUtc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Nessuna chiave esterna, come per `login_password_reset_tokens`. L'account del sito deve poter fare `SELECT`, `INSERT`, `UPDATE`, `DELETE` su questa tabella.

## 4. Verifica dopo (sola lettura)
Deve restituire 10 colonne e i quattro indici (`PRIMARY`, `uq_..._tokenhash`, `idx_..._login`, `idx_..._expires`).
```sql
SELECT COUNT(*) AS colonne FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'login_remembered_devices';
SELECT INDEX_NAME, NON_UNIQUE, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS colonne FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'login_remembered_devices' GROUP BY INDEX_NAME, NON_UNIQUE;
```

## 5. Ritorno indietro
Togliere la tabella scollega soltanto i dispositivi ricordati: i clienti rientrano con nome utente e password. Nessun altro dato dipende da questa tabella.
```sql
DROP TABLE IF EXISTS login_remembered_devices;
```

## 6. Controllo periodico (sola lettura)
```sql
SELECT COUNT(*) AS righe, SUM(RevokedUtc IS NULL AND ExpiresUtc > UTC_TIMESTAMP()) AS attive, SUM(RevokedUtc IS NOT NULL) AS annullate, SUM(ExpiresUtc <= UTC_TIMESTAMP()) AS scadute FROM login_remembered_devices;
SELECT RevokeReason, COUNT(*) AS n FROM login_remembered_devices WHERE RevokedUtc IS NOT NULL GROUP BY RevokeReason;
```
Il sito pulisce da solo le righe scadute di un cliente quando quel cliente ricorda un nuovo dispositivo; non c'e un processo programmato. Limite: 10 dispositivi attivi per cliente (il piu vecchio viene annullato).

## 7. Per Enzo
- Nessuna modifica richiesta al gestionale. Se nel gestionale si cambia la password web di un cliente, o si riassegna un accesso a un altro utente, i suoi dispositivi ricordati smettono di valere da soli al primo utilizzo (l'impronta di controllo non coincide piu).
- Facoltativo, utile in futuro: una griglia «Dispositivi ricordati» per cliente (data, ultimo uso, scadenza, stato) con un pulsante «Scollega», che equivale a `UPDATE login_remembered_devices SET RevokedUtc = UTC_TIMESTAMP(), RevokeReason = 'gestionale' WHERE LoginId = <id> AND RevokedUtc IS NULL`.
- La tabella va creata in ogni database che usa il sito (programma di allineamento).

## 8. Stato dell'attivazione
Fase 1 (questa): servizio e tabella, **nessun effetto per i clienti**. Fase 2 (task successivo): casella «Resta collegato» nella pagina di accesso, ripristino dell'accesso, uscita, cambio password. Finche la tabella non esiste il sito si comporta come oggi, senza errori.
