# KeepStore — standard comune di protezione dei segreti

Decisione PO: 2026-10-20. Task: `KEEPSTORE-SECRET-STANDARD-CONTRACT-1A`, DOCS-ONLY.
Questo e il contratto tecnico canonico per sito, gestionale e configurazioni. La regola permanente di applicazione vive in [AGENTS](../AGENTS.md); stato e priorita in [START_HERE](KEEPSTORE_START_HERE.md) e [PRODUCT_ROADMAP](KEEPSTORE_PRODUCT_ROADMAP.md). Nessuna migrazione e autorizzata da questo documento.

## 1. Ambito, autorita e stati

Prima di cambiare password/token, form credenziali, connessioni o consumer esterni, classificare il dato e consultare questo contratto e la mappa del paragrafo 7. Esaminare soltanto le superfici coinvolte nel manifest, aggiungendo progressivamente quelle incontrate. Vietate nuove persistenze in chiaro, funzioni crittografiche isolate e conversioni automatiche fuori scope. Non richiedere al PO un promemoria della regola.

| Stato | Significato e situazione corrente |
| --- | --- |
| CURRENT IMPLEMENTED | E-mail: `EmailCredentialStore.vb`, DPAPI LocalMachine, envelope KSEMAIL1 e CredentialReference dpapi-v1; deposito esterno alla webroot, scope identita database/azienda/scopo. #362: lettore strumenti e protezione esplicita RSA disponibili nel sorgente, non configurazioni operative cifrate dal batch. |
| TARGET APPROVATO | KSAES2 come destinazione comune dei segreti reversibili; adattatore Protected Configuration per connectionStrings; contratto interoperabile sito/gestionale. Decisione progettuale, non runtime installato. |
| DA IMPLEMENTARE | Specifica crittografica completa, componente condiviso, adattatori, adeguamento Tools, distribuzione chiavi, migrazione e prove dei consumer pertinenti. |
| DEPLOYED | Richiede evidenza per ambiente/tenant/versione. Lo storico Taikun e-mail DPAPI attesta soltanto i flussi web TRANSACTIONAL indicati nel Masterplan; non altri tenant o INVIADOCUMENTI. Nessun deploy KSAES2 attestato. #362 CHIUSA A / SOURCE INTEGRATED, nessun deploy implicito. |

`EMAIL_CONNECTION_VERIFIED` e un esito SMTP (TLS, autenticazione e QUIT, senza invio), non una funzione crittografica. L'evidenza non attesta la protezione di altre credenziali.
Il runtime e-mail attuale e gli strumenti RSA rimangono invariati fino a un intervento autorizzato specifico.

## 2. Segreti riutilizzabili — target KSAES2

DB, SMTP, API e altri servizi richiedono un valore protetto reversibile o un riferimento opaco al deposito protetto, mai la riproposizione del segreto al client. Il target PO e AES-256-CBC con HMAC-SHA256, secondo Encrypt-then-MAC, chiavi separate per cifratura e autenticazione, salt e IV casuali, versione della chiave e contesto autenticato.

- Riutilizzare un nucleo comune o un contratto interoperabile tra C# e VB.NET con vettori di test comuni. Nessuna copia di AES_Encrypt nelle pagine. Questa decisione non autorizza introdurre C# o nuove librerie nel runtime WebForms/VB.NET.
- Autenticare envelope e contesto atteso prima di decifrare o usare il plaintext; verificare il tag senza confronti dipendenti dal contenuto. Associare il contesto atteso dal consumer autorevole, non fidarsi del solo contesto dichiarato nel payload.
- Un KSAES2 malformato, non autenticato, di versione sconosciuta o di scope errato fallisce chiuso: nessun tentativo automatico AES storico, DPAPI alternativo o plaintext.
- Quando il componente di un ambito sara implementato e adottato, tutte le nuove scritture di quell'ambito useranno il formato finale. Letture legacy soltanto mediante percorso esplicito, limitato e revisionato nel mandato di migrazione, mai dopo un KSAES2 invalido.
- Separare scope e chiavi per installazione/tenant/scopo; sistema comune non significa chiave comune fra clienti. Le chiavi restano fuori dai dati protetti, dal repository, dai template e dal client, con accessi minimi.
- DPAPI puo custodire localmente materiale chiave; non e il formato interoperabile del dato. LocalMachine non sostituisce le ACL e non garantisce portabilita del recupero.
- Versionare formato e chiavi senza cancellare le chiavi necessarie ai dati ancora validi. Errori sanitizzati, nessun segreto in log, argv, stdout, transcript, HTML/JSON o temporanei non protetti. Nessuna promessa di azzeramento totale delle stringhe CLR.
- Recupero: backup cifrato separato, responsabilita e ACL definite, ripristino verificato sul contesto destinatario prima dell'adozione. Il vecchio segreto esposto non e rollback permanente; invalidazione delle credenziali resta un intervento operativo distinto.

**DA FORMALIZZARE PRIMA DELL'IMPLEMENTAZIONE:** layout binario/envelope e codifica, lunghezze e limiti, padding, derivazione delle chiavi e ruolo/parametri del salt, sorgente casuale, composizione autenticata di versione/key-id/IV/ciphertext/contesto, serializzazione canonica del contesto, politica versioni e ciclo di vita chiavi. Il nome KSAES2 non dimostra che tale specifica sia completa. Nessun parametro storico e inventato qui.

Prima dell'adozione serviranno vettori comuni C#/VB.NET, rifiuto delle manomissioni di ogni elemento autenticato, chiave/versione/scope errati, input malformati e limiti, assenza di fallback e perdite nei messaggi, recupero e compatibilita dei consumer reali. Sono requisiti futuri, NON prove eseguite da questo task.

### Riferimento AES storico

Il mandato PO descrive `AesUtility(1).cs`: AES-256-CBC, SHA256(key), IV casuale anteposto e Base64; decrypt con tentativo automatico del formato storico; HMAC assente. E un riferimento di compatibilita, non il componente da distribuire invariato e non KSAES2. In questo task non e attestata la lettura diretta dell'allegato ne calcolato un suo hash.
Il link di conversazione condivisa non era leggibile nella sessione ChatGPT secondo il mandato: non ne e attestata la lettura integrale. La decisione KSAES2 e recepita dall'autorizzazione PO corrente, senza attribuire prove a quel link.

## 3. Password di autenticazione utenti

Una password usata per verificare il login richiede hashing dedicato per password, con salt e costo adeguati al sistema approvato; non KSAES2 reversibile e non SHA-256 semplice. L'uniformita riguarda classificazione, interfaccia, autorizzazione, errori e gestione del ciclo di vita. Login/reset/schema e relativo legacy restano invariati in questo task; non si dichiara gia migrata l'autenticazione. Un eventuale intervento segue contratto auth, manifest e autorizzazione propri.

## 4. Configurazione DB e bootstrap

Preservare il contratto delle pagine:

```vb
ConfigurationManager.ConnectionStrings("EntropicConnectionString")
```

TARGET: un adattatore `ProtectedConfigurationProvider` protegge la sezione `connectionStrings` riutilizzando il nucleo comune; risoluzione/decrittazione trasparenti tramite le API native .NET Framework. Nessun secondo resolver o riscrittura delle connessioni nelle pagine. `Password=<ciphertext>` non e una password direttamente decifrabile dal provider MySQL.

Dipendenze da risolvere insieme prima dell'adozione:

1. Provider e dipendenze caricabili prima della lettura della configurazione; packaging e bootstrap compatibili con Web Site .NET Framework 4.8, senza presumere la disponibilita anticipata di App_Code.
2. Materiale chiave accessibile prima di aprire il DB, senza query al medesimo DB; scope installazione/scopo disponibile al bootstrap. Configurazione condivisa non implica poter usare una chiave tenant richiesta prima che il tenant sia risolto.
3. Adeguare `Tools/KeepStoreConfigurationReader.vb`, oggi limitato al provider protetto RSA, caricatore, wrapper, tool di protezione e consumer e-mail/cleanup/parity, con prove reali di lettura protetta. Il supporto attuale a configurazioni esplicite non protette non e un fallback da decrypt fallito.
4. Preservare nome connessione, provider dati, server/porta/database e identita derivate per e-mail e carrello. Nessun cambio di host/account o logica commerciale implicito.
5. Template senza segreti o key material; configurazione operativa privata preservata, mai sovrascritta da template o pacchetto. Test sintetici senza credenziali/chiavi operative.

RSA resta l'implementazione software esistente della #362, non il nuovo formato comune target. Nessuna nuova attivazione RSA operativa automatica; un futuro mandato dovra scegliere esplicitamente il percorso coerente con il target e gestire la transizione. Non riaprire #362 ne dichiarare che abbia cifrato il web.config operativo.

## 5. Schermate e handoff Enzo

Specifica funzionale da adottare nel gestionale e nelle superfici pertinenti; non un pannello gia implementato:

- Mostrare credenziale configurata/non configurata e stato della verifica; input nuova credenziale mascherato, mai precaricato.
- Sostituzione esplicita con conferma quando pertinente. Campo vuoto significa nessuna sostituzione, mai cancellazione implicita; la revoca e un'azione distinta dal salvataggio.
- Valore salvato mai restituito in HTML, JSON o campi nascosti; nessuna chiave master al client. Mascherare un input non cifra il dato nel database.
- Verifica server-side pertinente al consumer, con esito e codice sanitizzati, senza messaggi raw. Verificare autorizzazione del soggetto e isolamento tenant; nessuna identita database/azienda/scopo arbitraria dal client.
- Nel DB conservare il valore protetto o un riferimento opaco secondo il contratto del consumer; l'e-mail corrente continua a usare CredentialReference e deposito DPAPI esterno.
- Enzo riusa il contratto comune; origine configurazione, distribuzione/custodia chiavi e identita del processo devono essere specificate nel futuro handoff. Non presumere un servizio gia esistente; nessun nuovo servizio IIS/infrastruttura da questa decisione.

Il [manuale e-mail Enzo](MULTIPROVIDER_TENANT_EMAIL_CONFIG_ENZO.md) resta il riferimento del dominio e delle operazioni SMTP consentite. INVIADOCUMENTI e la distribuzione gestionale non diventano certificati per effetto di questa specifica.

## 6. Applicazione progressiva e focus

Ogni task pertinente: classificare la finalita, consultare mappa/contratto, dichiarare CURRENT/TARGET e aggiornare solo le superfici del manifest, conservando compatibilita e gate operativi. Se la specifica/componente necessario manca, non improvvisare crittografia: esplicitare la dipendenza circoscritta prima della modifica pertinente.
Nessuna scansione generale, dump o ricerca di credenziali reali. Riutilizzare finding e mappa esistenti; niente conversione massiva, avvisi o bonifiche ripetuti sulle esposizioni pregresse e nessun blocco delle funzionalita indipendenti. La decisione PO non dichiara bonificate o invalidate credenziali storiche.

#362 CHIUSA A / SOURCE INTEGRATED al commit `76d97a2c004f7661b61e66d6f744f1fb7e8d1231`; hardening operativo non completato implicitamente. `TENANT-RELEASE-PACKAGE-1A` SOSPESO PER DECISIONE PO: manifest, rilevatore e guida conservati; nessuna esecuzione o rigenerazione richiesta ora.
Prossimo batch funzionale resta `SHOPPING-ASSISTANT-GUIDED-ENTRY-1A`, NON AVVIATO, con nome/privacy e due merceologie da definire/approvare nel relativo mandato. Nessun micro-task di audit viene creato da questo documento.

## 7. Mappa progressiva senza valori

Questa mappa riusa superfici note; non e un nuovo censimento e non contiene valori, identificativi operativi di account o riferimenti reali a credenziali.

| Ambito | File/campo gia noto | Consumer | Protezione corrente | Destinazione | Dipendenze | Task/stato |
| --- | --- | --- | --- | --- | --- | --- |
| SMTP web | App_Code/EmailCredentialStore.vb; aziende_email_transport.CredentialReference | Resolver e trasporto e-mail tenant-scoped | DPAPI LocalMachine, KSEMAIL1, dpapi-v1; scope DB/azienda/scopo | Nucleo KSAES2 con riferimento/deposito protetto | Specifica, custodia chiavi, interoperabilita, migrazione autorizzata | CURRENT implementato; target da implementare; deploy solo nei limiti del Masterplan |
| Configurazione DB | web.config: connectionStrings/EntropicConnectionString | ConfigurationManager; App_Code/SearchSuggest.vb | File privato non versionato; nessuna cifratura operativa attestata dal Batch A | Adattatore Protected Configuration KSAES2 | Bootstrap senza DB, provider caricabile, chiavi, Tools e prove | #362 CHIUSA A / SOURCE INTEGRATED; adattatore DA IMPLEMENTARE |
| Strumenti DB | Tools/KeepStoreConfigurationReader.vb e Import-KeepStoreConfigurationReader.ps1 | Provisioning/verifica e-mail, cleanup carrelli, bulk/parity | API .NET; protezione RSA supportata; input esplicito non protetto compatibile | Lettura protetta col nuovo adattatore, fail-closed | Compilazione/wrapper/tool RSA e prove dei consumer reali | #362 integrata; adeguamento futuro non eseguito |
| Login utente | login.aspx.vb / Page.master.vb; superfici reset e contratto auth/hash legacy | Autenticazione storefront | Verifica password legacy invariata; guard POST/origine aggiuntivo, distinto dalla protezione del segreto | Hash per password dedicato, non AES reversibile | Contratto auth/reset, compatibilita e migrazione autorizzata | LOGIN-POST-ORIGIN-GUARD-1A candidato SOURCE ONLY: nessun nuovo hash/cifratura/token; migrazione password e rigenerazione sessione restano aperte |
| Gestionale/INVIADOCUMENTI | Origine configurazione del consumer esterno non attestata | Gestionale e processo esterno | Non certificata dal runtime web | Contratto interoperabile comune e UI del paragrafo 5 | Responsabile Enzo, identita processo, distribuzione chiavi, prove e rollback | Specifica funzionale; nessuna implementazione/deploy attestati |

Aggiungere solo la superficie effettivamente incontrata nel task pertinente (inclusi eventuali token/API); nessuna affermazione di copertura completa della piattaforma. machineKey e riscrittura della cronologia restano perimetri separati, senza rotazioni implicite.

## 8. Fonti e limiti

Fonti normative di progetto: mandato PO corrente, [AGENTS](../AGENTS.md), [Masterplan](KEEPSTORE_MASTERPLAN_OPERATIVO.md), [runbook DB](KEEPSTORE_DB_CREDENTIALS_HARDENING_RUNBOOK.md) e [manuale e-mail](MULTIPROVIDER_TENANT_EMAIL_CONFIG_ENZO.md). Riscontri sorgente mirati: EmailCredentialStore per DPAPI/envelope/scope; KeepStoreConfigurationReader per il vincolo RSA. Nessun test operativo o lettura di segreti da questo task.

Riferimenti esterni consultati 2026-10-20:
- L'estensione tramite provider personalizzato e prevista da [Microsoft: Implementing a Protected Configuration Provider](https://learn.microsoft.com/en-us/previous-versions/aspnet/wfc2t3az%28v%3Dvs.100%29); non prova che l'adattatore KeepStore esista.
- L'integrita da accompagnare alla cifratura CBC e discussa in [OWASP Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html); non certifica la specifica KSAES2 ancora incompleta.
- La distinzione tra hashing delle password e cifratura reversibile segue [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html). Scelta e parametri implementativi restano nel futuro mandato auth.

Il contratto approvato non equivale a implementazione revisionata, test superati o DEPLOYED. Non dichiarare tutti i segreti del sistema bonificati.
