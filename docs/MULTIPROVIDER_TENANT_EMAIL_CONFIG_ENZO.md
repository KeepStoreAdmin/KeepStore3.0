# Contratto configurazione e-mail multi-provider per il gestionale

## Scopo e confini

Questo documento definisce il contratto che Enzo dovra usare per realizzare il pannello di configurazione e-mail di KeepStore. Non abilita ancora il runtime, non rende operativo OAuth2 e non autorizza alcun deployment. La tabella `aziende` resta invariata; i campi SMTP legacy restano temporaneamente disponibili durante la transizione.

La configurazione appartiene all'azienda/storefront, non all'utente ecommerce che effettua un ordine. Ogni database KeepStore contiene una sola tabella `aziende_email_transport`, condivisa dalle aziende presenti in quel database. Ogni riga appartiene a una sola azienda e a un solo scopo. Gli invii applicativi correnti (ordine, registrazione/profilo, reset password e contatti) useranno in futuro esclusivamente `TRANSACTIONAL`; `MARKETING` e riservato a una capacita futura e distinta.

## Schema logico e relazione

```text
aziende                                      aziende_email_transport
---------------------                        --------------------------------
id (PK)                 1 ─────────────── n   EmailTransportId (PK tecnica)
...                                          AziendeId (FK -> aziende.id)
                                             Purpose
                                             UNIQUE (AziendeId, Purpose)
                                             configurazione non sensibile
                                             CredentialReference, mai segreto
```

La foreign key impedisce profili orfani. La primary key tecnica consente piu scopi per azienda, mentre l'unicita `(AziendeId, Purpose)` impedisce profili duplicati per lo stesso scopo. Non esistono tabelle per singola azienda, valori tenant hardcoded o riferimenti a password/token.

I valori controllati sono `varchar` con confronto case-sensitive, non `ENUM`. Questa scelta mantiene gli script compatibili con le versioni MySQL supportate e permette di introdurre un provider o uno stato mediante una revisione applicativa/migration esplicita, senza dipendere dalla semantica di modifica degli `ENUM`. Il server applicativo applica whitelist rigorose e lo script `verify` intercetta valori fuori contratto.

## Campi persistiti

| Colonna | Tipo | Regola |
| --- | --- | --- |
| `EmailTransportId` | `bigint unsigned` auto-increment | PK tecnica, sola lettura |
| `AziendeId` | `int` | FK obbligatoria verso `aziende.id` |
| `Purpose` | `varchar(24)` ASCII binario | `TRANSACTIONAL` o futuro `MARKETING`; univoco con azienda |
| `ProviderKind` | `varchar(32)` ASCII binario | `CUSTOM_SMTP`, `ARUBA`, `GOOGLE`, `MICROSOFT`, `LIBERO`, `VIRGILIO` |
| `Host` | `varchar(253)` ASCII | Nome DNS esplicito, senza schema o porta |
| `Port` | `smallint unsigned` | 1-65535 |
| `SecurityMode` | `varchar(24)` ASCII binario | `STARTTLS` o `IMPLICIT_TLS`; nessun plaintext/fallback automatico |
| `AuthenticationMode` | `varchar(24)` ASCII binario | `PASSWORD`, `APP_PASSWORD`, `OAUTH2` |
| `Username` | `varchar(254)` UTF-8 binario | Identita completa, inclusi indirizzi e-mail |
| `CredentialReference` | `varchar(512)` ASCII binario | Puntatore opaco restituito dal secret service; mai segreto |
| `FromAddress` | `varchar(254)` UTF-8 binario | Mittente header valido e autorizzato |
| `FromDisplayName` | `varchar(255)` UTF-8 Unicode | Nome visualizzato, senza markup/control character |
| `ReplyToAddress` | `varchar(254)` UTF-8 binario, null | Reply-To opzionale |
| `EnvelopeFromAddress` | `varchar(254)` UTF-8 binario, null | Envelope sender opzionale e autorizzato |
| `TimeoutSeconds` | `smallint unsigned` | 5-300, default 30 |
| `Enabled` | `tinyint(1)` | default 0; attivabile solo dopo verifica riuscita |
| `VerificationStatus` | `varchar(24)` ASCII binario | `NOT_VERIFIED`, `VERIFIED`, `FAILED`, `EXPIRED`, `REVOKED` |
| `LastVerifiedAtUtc` | `datetime(6)`, null | valorizzato dal servizio di verifica in UTC |
| `LastVerificationCode` | `varchar(64)` ASCII binario, null | codice sanitizzato, mai messaggio raw |
| `CreatedAtUtc` | `datetime(6)` | data creazione UTC |
| `UpdatedAtUtc` | `datetime(6)` | aggiornamento automatico UTC |

## Contratto del pannello

| Etichetta italiana | Colonna/proprieta | Controllo | Obbligatorio | Validazione e valori | Creazione/modifica |
| --- | --- | --- | --- | --- | --- |
| Azienda | `AziendeId` | selettore aziende autorizzate | si | ID esistente e tenant selezionato server-side | fissato alla creazione; sola lettura dopo il salvataggio |
| Scopo | `Purpose` | select | si | `TRANSACTIONAL`; `MARKETING` solo quando autorizzato | non mutare lo scopo di una riga: creare un profilo distinto |
| Provider | `ProviderKind` | select | si | `CUSTOM_SMTP`, `ARUBA`, `GOOGLE`, `MICROSOFT`, `LIBERO`, `VIRGILIO` | i preset propongono soltanto valori iniziali |
| Server SMTP | `Host` | input testo | si | DNS ASCII 1-253, niente URL, IP solo se contrattualmente autorizzato | modificabile; invalida la verifica precedente |
| Porta | `Port` | input numerico | si | 1-65535 | modificabile; invalida la verifica precedente |
| Sicurezza | `SecurityMode` | select | si | `STARTTLS` o `IMPLICIT_TLS` | nessuna modalita automatica o downgrade |
| Autenticazione | `AuthenticationMode` | select | si | `PASSWORD`, `APP_PASSWORD`, `OAUTH2` | il cambio richiede nuova credenziale/consenso e verifica |
| Nome utente | `Username` | input testo | si | 1-254, nessun CR/LF/control character | non mascherare come password; non inserire nei log |
| Credenziale | stato derivato da `CredentialReference` | indicatore + pulsanti | si per verificare/attivare | mostra solo configurata/non configurata | sostituisci o revoca; non rileggere mai il valore |
| Mittente | `FromAddress` | input e-mail | si | indirizzo valido massimo 254 | modificabile; invalida la verifica precedente |
| Nome mittente | `FromDisplayName` | input Unicode | si | 1-255, niente markup/CR/LF/control character | modificabile; invalida la verifica precedente |
| Reply-To | `ReplyToAddress` | input e-mail | no | null oppure indirizzo valido massimo 254 | stringa vuota normalizzata a null |
| Envelope sender | `EnvelopeFromAddress` | input e-mail | no | null oppure indirizzo autorizzato massimo 254 | stringa vuota normalizzata a null |
| Timeout | `TimeoutSeconds` | input numerico | si | intero 5-300 | default 30 |
| Stato attivo | `Enabled` | switch | si | booleano; attivazione soggetta ai gate | default disattivato; non abilitabile prima della verifica |
| Stato verifica | `VerificationStatus` | badge sola lettura | si | valori contrattuali | scritto solo dal servizio server-side |
| Ultima verifica | `LastVerifiedAtUtc` | data/ora sola lettura | no | UTC | scritto solo dal servizio server-side |
| Codice verifica | `LastVerificationCode` | testo sola lettura | no | codice sanitizzato massimo 64 | mai mostrare eccezioni o risposte contenenti identita |

Tutti i controlli scrivono solo sul profilo dell'`AziendeId` selezionato e autorizzato server-side. Il client non puo scegliere un'altra azienda mediante hidden field o payload alterato. La concorrenza deve essere gestita con controllo versione/ultima modifica e messaggio di conflitto, non con overwrite silenzioso.

## Provider e preset

Il pannello offre Custom SMTP, Aruba, Google, Microsoft, Libero e Virgilio. Un preset puo proporre host, porta, sicurezza e modalita di autenticazione quando si crea un profilo nuovo. Non deve dedurre il provider dal dominio, cambiare una configurazione salvata, provare porte alternative o sovrascrivere una scelta manuale. Host e porte reali vengono validati contro la documentazione corrente del provider al momento dell'onboarding.

## Credenziali e OAuth2

Il browser invia una nuova credenziale direttamente al servizio autorizzato su TLS, senza riproporla nelle risposte. Il secret service restituisce un `CredentialReference` opaco; la tabella memorizza soltanto quel riferimento. Il pannello mostra “credenziale configurata” o “non configurata” e permette sostituzione e revoca. Password, password applicative, access token e refresh token non vengono mai riletti, visualizzati, inclusi in HTML/JSON, log, eccezioni, PR o backup applicativi.

Per `OAUTH2` il pannello futuro espone: “Collega account”, stato del consenso, token valido/scaduto, “Revoca collegamento” e “Autorizza nuovamente”. Il collegamento deve essere tenant-scoped e state/redirect devono essere protetti. Questa e soltanto un'interfaccia contrattuale: OAuth2 e `NON OPERATIVO` finche `SMTP-OAUTH-CONNECTORS-1A` non realizza registrazione applicativa, consenso, refresh, revoca e secret store.

## Verifica configurazione e attivazione

Il pulsante “Verifica configurazione” chiama un servizio server-side per lo stesso `AziendeId`/`Purpose`. In sequenza verifica DNS, connessione TCP, TLS obbligatorio, certificato e hostname, capability SMTP e autenticazione. La sessione SMTP termina con `QUIT` subito dopo l'autenticazione e prima di `MAIL FROM`, `RCPT TO` o `DATA`; non viene inviata alcuna e-mail.

Il pannello riceve soltanto esito, fase, codice sanitizzato, data/ora UTC e messaggio comprensibile. Non riceve host sensibili, username completo, secret reference, certificati, banner raw o eccezioni. Una modifica a host, porta, sicurezza, autenticazione, username, credenziale o identita mittente riporta il profilo a `NOT_VERIFIED` e `Enabled=0`.

L'attivazione e vietata quando manca un campo obbligatorio o il riferimento credenziale, il test TLS/auth non e riuscito, il certificato/hostname non e valido, la verifica e scaduta/revocata oppure il profilo appartiene a un'altra azienda. Un profilo attivo che fallisce non effettua downgrade plaintext o fallback ai campi legacy: fallisce chiuso con diagnostica sanitizzata.

## Esempi sanitizzati

| Azienda | Scopo | Provider | Stato | Credenziale |
| --- | --- | --- | --- | --- |
| Azienda 1 | `TRANSACTIONAL` | `CUSTOM_SMTP` | disabilitato / `NOT_VERIFIED` | riferimento opaco configurato |
| Azienda 2 | `TRANSACTIONAL` | `GOOGLE` | disabilitato / `NOT_VERIFIED` | riferimento opaco configurato |

Gli esempi non rappresentano clienti o endpoint reali. Le due righe possono convivere nello stesso database senza condividere host, identita o credenziale. Una futura riga `MARKETING` usa una diversa combinazione azienda/scopo.

## Checklist di installazione per ogni database cliente

1. Ottenere dal Product Owner l'allowlist esplicita del database; la discovery non autorizza il deployment.
2. Eseguire `preflight` in sola lettura e fermarsi a ogni `STOP`.
3. Creare e verificare un backup recuperabile secondo la procedura del cliente.
4. Eseguire una sola volta `forward`; una seconda esecuzione deve essere un no-op conforme.
5. Eseguire `verify` e richiedere tutti i controlli `OK`.
6. Creare dal gestionale un profilo `TRANSACTIONAL` disabilitato per ciascuna azienda autorizzata.
7. Eseguire la prova TLS/certificato e poi la sola autenticazione, senza messaggio.
8. Attivare esplicitamente il singolo profilo soltanto dopo verifica riuscita.
9. Monitorare codici sanitizzati, isolamento tenant ed error rate senza segreti/dati personali.
10. Usare il rollback soltanto se la tabella e vuota; con profili presenti fermarsi e pianificare una migrazione dati separata.

La migration viene eseguita una volta per database, non una volta per azienda. Gli script generici non contengono ID azienda, nomi di database, domini, provider o endpoint cliente.

## Piano di transizione legacy

1. Conservare temporaneamente i campi SMTP legacy in `aziende`.
2. Creare il nuovo profilo disabilitato, senza copiare `Password_smtp`.
3. Configurare un nuovo segreto nel secret service e verificare TLS/autenticazione.
4. Attivare esplicitamente il profilo per il singolo tenant.
5. Far selezionare al nuovo runtime soltanto profili attivi e verificati dello stesso tenant.
6. Vietare downgrade plaintext e fallback automatico ai campi legacy.
7. Migrare progressivamente ordine, registrazione/profilo, reset password e contatti al profilo `TRANSACTIONAL`.
8. Rimuovere dal runtime l'uso dei campi legacy quando tutti i chiamanti e tenant sono migrati.
9. Eliminare fisicamente i campi legacy soltanto con un task futuro separato, backup e rollout autorizzato.

## Matrice di validazione

| Caso | Esito richiesto |
| --- | --- |
| Azienda inesistente | rifiuto FK/server-side |
| Secondo profilo stesso `AziendeId`/`Purpose` | rifiuto unique |
| `TRANSACTIONAL` e `MARKETING` per la stessa azienda | ammessi come righe distinte |
| Host 253, e-mail/username 254, reference 512, display name Unicode 255 | accettati |
| Valore oltre il limite o con CR/LF/control character | rifiutato prima della persistenza |
| Porta 0 o timeout fuori 5-300 | rifiutato |
| Provider/security/auth/purpose sconosciuto | rifiutato dalla whitelist |
| Profilo nuovo | `Enabled=0`, `NOT_VERIFIED` |
| Attivazione senza credenziale/verifica/certificato valido | rifiutata |
| Modifica di campo sensibile alla verifica | disabilitazione e nuova verifica obbligatorie |
| Lettura/modifica di profilo di altra azienda | rifiuto fail-closed |
| Test configurazione | DNS/TCP/TLS/capability/AUTH, poi `QUIT`; zero messaggi |

## Task successivi ordinati

1. `MULTIPROVIDER-TENANT-EMAIL-SCHEMA-ROLLOUT-1A`: rollout allowlist della migration dopo approvazione.
2. `SMTP-SECRET-EXTERNALIZATION-ROTATION-1A`: secret service, import controllato e rotazione delle credenziali legacy.
3. `MULTIPROVIDER-TENANT-EMAIL-ADMIN-UI-1A`: pannello Enzo conforme a questo contratto.
4. `MULTIPROVIDER-TENANT-EMAIL-RUNTIME-1A`: loader/transport unico e fail-closed per `TRANSACTIONAL`.
5. `SMTP-OAUTH-CONNECTORS-1A`: Google/Microsoft OAuth2, consenso, refresh e revoca.
6. `SMTP-LEGACY-FIELDS-RETIREMENT-1A`: rimozione fisica futura, solo dopo completa migrazione.

Tutti i task sono `NON AVVIATO`; questo documento non autorizza installazione, runtime, invio, autenticazione live o rimozione di campi.
