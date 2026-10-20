# KeepStore — configurazione DB privata e Protected Configuration

Checkpoint REV1 2026-10-20: **PR #362 DRAFT**, finding `DBCFG-GUARD-F01` della review 5585799761 sul candidato `bae99d30` corretto nel guard; prove mirate PASS e nuova review differenziale indipendente pendente. Delta 5 percorsi entro manifest cumulativo 25, nessun merge/deploy. Rapporto REV1 `C:\Temp\KeepStoreDbConfigHardening1A\20261020-rev1-c516f63b\final-report.md`/`final-report.json`; le prove Batch A sotto sono riusate senza ripetere RSA/e-mail/parity/precompile o #361.

Data: 2026-10-20. Task `SECURITY-DB-CREDENTIALS-HARDENING-1A`, **solo Batch A software implementato e testato tecnico-localmente PASS; PR DRAFT da revisionare**. Base source #361 REV2 `32bc8714b081f2ecea5b2ad2d13653c21c764512`; branch `task/security-db-credentials-hardening-1a`. Commit e URL PR dal rapporto finale sanitizzato e Git reale; nessun merge/deploy. Fonte del metodo: [AGENTS](../AGENTS.md); manifest e decisioni: [Masterplan](KEEPSTORE_MASTERPLAN_OPERATIVO.md#security-db-credentials-hardening-1a--batch-a-software).

## 1. Perimetro autorizzato e stati separati

Batch A autorizza i 25 percorsi, compilazione e prove sintetiche locali, chiavi RSA temporanee CurrentUser, manuali, un commit, push task branch e PR DRAFT. Non modifica contenuto/ACL della configurazione operativa. Nessuna destinazione server e autorizzata; template e Tools non costituiscono un pacchetto da caricare sul sito. Il solo runtime applicativo modificato e `App_Code/SearchSuggest.vb`, che richiede review e successiva autorizzazione prima di qualunque pubblicazione.

Laboratorio DB, account/grant/TLS, IIS/pool/servizi/job, migrazione consumer, revoca credenziali e machineKey **NON AVVIATI / fuori autorizzazione**. Questi interventi separati non impediscono l'A tecnico-locale del Batch A. Nessuna connessione DB, SMTP, richiesta HTTP applicativa, login reale, ordine o pagamento e necessario ai test di questo batch. Integration usa riferimenti DB condivisi e non e un laboratorio isolato.

La [decisione PO 2026-10-20](KEEPSTORE_MASTERPLAN_OPERATIVO.md#decisione-po-2026-10-20--esposizioni-pregresse) stabilisce che le esposizioni storiche gia censite non richiedono nuovi audit, richieste di bonifica o avvisi ripetuti per completare il batch o proseguire attivita indipendenti. Restano controlli incrementali sulle nuove modifiche e sulla non regressione. Nessuna cancellazione, rotazione o bonifica storica viene dichiarata eseguita.

## 2. Contratto della configurazione

- Il runtime mantiene `ConfigurationManager.ConnectionStrings("EntropicConnectionString")`. SearchSuggest usa soltanto tale nome: nessun alias `taikun` o `ConnectionStrings(0)`, query/ranking e risposta invariati.
- `web.config` e configurazione operativa privata. La rimozione riguarda soltanto il tracking Git; il file locale deve rimanere identico per bytes, ACL, attributi, creazione e ultima scrittura. Non viene cancellato sul server o inserito in liste di cancellazione della release.
- `web.config.example` e un modello strutturale versionato senza segreti o dati d'installazione: nessuna password reale, machineKey, destinazione o credenziale SMTP/gateway. Non e una configurazione operativa pronta all'avvio.
- RSA e la proposta di riferimento per ogni applicazione/installazione, con contenitore dedicato e identita non amministrativa; la prova sintetica non certifica chiavi/ACL application pool o portabilita sul server destinatario.
- Server, porta e database restano invariati. Un cambiamento puo alterare le identita derivate per scope e-mail/carrello e richiede decisione distinta. Account per consumer effettivo e isolamento applicativo azienda/listino sono controlli complementari, anche con DB condiviso.

## 3. Nuova installazione da template — procedura futura

Richiede destinazione e intervento autorizzati separatamente. Non avviare l'applicazione usando il template o valori sintetici.

1. Estrarre codice e dipendenze dal commit approvato; registrare il manifest effettivo e il responsabile dell'installazione. Nessun clone di sviluppo alternativo o discovery automatica dei target.
2. Se `web.config` e assente, predisporre la copia privata a partire dal template, fuori dal pacchetto distribuibile. Se il file e presente, fermare questa procedura di nuova installazione e seguire l'aggiornamento; nessuna sovrascrittura automatica.
3. L'amministratore completa localmente i soli valori d'installazione autorizzati mediante strumenti protetti, senza segreti in argv, stdout, transcript, ticket o chat. Nessuna nuova machineKey viene assegnata automaticamente dal batch; conservarne il contratto operativo concordato.
4. Prima dell'avvio, attestare configurazione completa, provider e chiave dedicati, accesso dell'identita applicativa, recupero e account corretti. Il tool di protezione non crea questi prerequisiti.
5. Proteggere la sezione solo nella finestra autorizzata, verificare la lettura tramite codice/strumenti reali e poi eseguire il collaudo operativo approvato. Non dedurre disponibilita o TLS DB dal solo caricamento della configurazione.

## 4. Aggiornamento release e altre working copy

La pubblicazione manuale dei soli file approvati da Germano e gia attestata. Non richiede un nuovo audit generale. Preparare sempre il delta dal commit realmente installato; includere dipendenze aggiunte quando necessarie.

- Escludere `web.config` operativo dal pacchetto, dalle sovrascritture e dalle liste di cancellazione. **REMOVED-FROM-TRACKING non significa DELETED sul server.** Non copiare indiscriminatamente template, harness o Tools nella webroot.
- Prima dell'aggiornamento autorizzato, predisporre il recupero cifrato della configurazione corrente, metadati/ACL e chiavi pertinenti in deposito protetto fuori repository/webroot. Nessuna copia in chiaro indiscriminata delle configurazioni storiche.
- Verificare bytes e metadati prima/dopo il trasferimento file; non leggere o stampare il diff di cancellazione di `web.config`. Eventuali nuove impostazioni strutturali si applicano come intervento esplicito, non sostituendo il file privato con il template.
- Per le altre working copy, un normale `git pull` puo eliminare un file precedentemente tracciato quando arriva la rimozione. Prima del passaggio: censire il file, predisporre recupero cifrato verificato, impedire che la copia serva richieste durante un intervallo senza configurazione, applicare l'aggiornamento controllato e ripristinare la copia privata senza aggiungerla al tracking. Verificare hash/metadati e lettura prima di riaprire il servizio. Nessun `git pull` in una webroot operativa.
- Se non e possibile garantire il recupero della copia specifica, fermare quell'aggiornamento; non considerare sufficiente `.gitignore`. Nessuna cancellazione o rigenerazione di configurazioni locali per risolvere divergenze.

Nel checkout canonico del batch la sola operazione ammessa, dopo le prove sintetiche pertinenti, e `git rm --cached -- web.config`, senza force. Il file fisico resta preservato; untracked/asset e quattro cancellazioni preesistenti restano fuori staging.

## 5. Build e precompile senza segreti operativi

`Tools/Test-KeepStorePrecompileSafe.ps1` usa `web.config.example` per la configurazione di compilazione sintetica. Non legge `web.config` operativo, non richiede le sue chiavi e non ne copia elementi per ottenere la build. Mantiene controllo input, dipendenze e diagnostica sanitizzata; nessun aggiornamento/downgrade delle DLL.

Nel processo Windows PowerShell autorizzato il comando di precompile e:

```powershell
& 'C:\KeepStoreWeb\KeepStore3.0\Tools\Test-KeepStorePrecompileSafe.ps1' `
    -RepositoryRoot 'C:\KeepStoreWeb\KeepStore3.0'
```

Gli output sono temporanei e separati dalla copia canonica. Successo di build non equivale a connessione DB, smoke IIS o deploy. Il guard controlla nuove aggiunte, template e artefatti pubblicabili; non riesamina storia, vecchie copie/dump/log o righe eliminate dalla configurazione.

REV1 `DBCFG-GUARD-F01`: prima di escludere file dalla lettura, il guard verifica i **metadati Git dell'indice rispetto a base e HEAD**, con delimitatori NUL/UTF-8 e `--no-renames`. Le destinazioni aggiunte `A` corrispondenti a configurazioni private sono rifiutate anche se il filtro dei contenuti le esclude; il controllo non apre tali file. Il template ammesso resta controllabile, `D` di rimozione dal tracking non costituisce nuova introduzione e `web.config` locale ignorato rimane preservato. Non aggiungere il file privato all'indice, neppure forzatamente: un exit non zero `PRIVATE_PUBLICATION_PATH` richiede rimuovere dal candidato la nuova pubblicazione privata, senza stamparne o copiarne il contenuto. Questo gate incrementale non scandisce la storia o le configurazioni escluse dal mandato.

## 6. Lettore comune e strumenti amministrativi

`Tools/KeepStoreConfigurationReader.vb` espone `ReadConnectionString(applicationRoot, connectionName)` e `ReadConnectionStringFromFile(configPath, connectionName)`; il nome canonico resta `EntropicConnectionString`. Usa `WebConfigurationManager.OpenMappedWebConfiguration`, verifica target/origine/provider/valore e rifiuta che una voce ereditata da un altro file sostituisca il nome assente nel target. Richiede server/database espliciti e restituisce invariata la stringa originale. `XmlReader` verifica soltanto metadati di origine/protezione prima della risoluzione nativa, senza estrarre valori delle connessioni; la chiave esistente e verificata prima del decrypt per evitare creazioni implicite. Non risolve configurazioni del processo host, alias o prima voce disponibile.

`Tools/Import-KeepStoreConfigurationReader.ps1` carica il lettore per Windows PowerShell 5.1/.NET Framework. Gli eseguibili VB includono lo stesso sorgente nella compilazione. Una configurazione esplicita non cifrata resta supportata per compatibilita; una sezione protetta illeggibile fallisce senza degradazione. Non esportare il valore restituito in output, pipeline tra processi o file temporanei; le stringhe CLR sono gestite e non se ne promette azzeramento completo.

| Consumatore | Contratto aggiornato | Limite delle prove Batch A |
| --- | --- | --- |
| Provisioning e-mail | Identita DB dal lettore comune; input credenziale e-mail mascherato e scope invariati | Fake/sink e fixture; nessun provisioning operativo |
| Verificatore e-mail e wrapper | Lettore condiviso compilato; diagnostica/exit code sanitizzati | Lettura/validazione offline; nessun DB o TLS/AUTH SMTP reale |
| Cleanup e runner | Argomenti interni: percorso configurazione, azienda, batch; lettura interna al processo | Compilazione e lettura fixture; nessun `RunBatch` DB |
| Bulk harness e parity | Configurazione richiesta esplicitamente; parity default offline, DB solo con `-EnableDirectParity -ConfigPath`, HTTP solo con `-EnableRuntime -BaseUrl`; precedenti switch Skip preservati | Nessun profilo reale, query o operazione DB |

Esecuzione amministrativa reale, `-Apply` del cleanup, verifica SMTP e job restano soggetti ai rispettivi mandati operativi. La compatibilita del lettore non autorizza tali azioni.

## 7. Strumento di protezione RSA

`Tools/Set-DatabaseProtectedConfiguration.ps1` richiede target, provider e contenitore espliciti. **Default non mutativo**: nessuna configurazione canonica scelta automaticamente.

Interfaccia, con soli segnaposto da sostituire dopo verifica/autorizzazione del target:

```powershell
& '<RELEASE_APPROVATA>\Tools\Set-DatabaseProtectedConfiguration.ps1' `
    -ConfigPath '<CONFIG_ESPLICITA>' -ProviderName '<PROVIDER_DEDICATO>' `
    -KeyContainerName '<CONTENITORE_DEDICATO>' -KeyScope CurrentUser
```

Per una mutazione autorizzata sono necessari anche `-Apply`, `-EncryptedBackupPath` e `-EncryptedRecoveryKeyPath`. Nel Batch A Apply si esegue esclusivamente su fixture sintetiche; mai sulla configurazione canonica o di Integration.

Prerequisiti dello strumento:

1. Provider gia presente nella configurazione e di tipo nativo `RsaProtectedConfigurationProvider`, con nome dedicato, `keyContainerName` esplicito e `useMachineContainer` coerente con `-KeyScope CurrentUser|LocalMachine`.
2. Chiave gia esistente e accessibile. Il tool usa la chiave esistente, non genera contenitori, non modifica provider/ACL e non ruota credenziali. Contenitori standard/condivisi non sono una scelta ammessa.
3. Per Apply, due file gia cifrati DPAPI CurrentUser: backup contenente esattamente i bytes della configurazione corrente e recupero contenente l'export privato XML RSA della medesima chiave. Corrispondenza verificata soltanto in memoria, senza stdout o temporanei in chiaro. Il tool non genera/esporta il materiale di recupero.
4. Configurazione gia protetta dallo stesso provider: verifica/idempotenza, nessuna nuova cifratura inutile. Provider incompatibile, key/scope errati, backup/recovery non conformi o sezione illeggibile: fallimento sanitizzato, nessuna lettura alternativa.

Apply protegge soltanto `connectionStrings` e preserva ACL/attributi del file. Su fallimento ripristina le sole modifiche effettuate, compresi bytes, ACL, attributi e date originali, quindi segnala errore. Non presenta un ripristino fallito come successo.

**DPAPI CurrentUser non rende il recupero portabile per la sola copia del file su un altro server/utente.** Il materiale richiesto qui serve al contesto esplicitamente verificato; custodia operativa, protezione della chiave di recupero e ripristino RSA su server sostitutivo richiedono una procedura autorizzata e provata separatamente. La suite Batch A dimostra soltanto il round-trip/recupero sintetico nel contesto autorizzato.

## 8. Esecutore e risorse sintetiche autorizzate

La ripresa PO 2026-10-20 autorizza **RemoteSigned nello scope Process dei soli processi Windows PowerShell 5.1 Desktop dedicati**, senza profili/elevazione. Prima degli script acquisire versione, `Get-ExecutionPolicy -List` e policy effettiva; Group Policy prevale. L'abilitazione avviene prima del caricamento dello script e nello stesso processo che esegue la prova:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned `
    -File '<SCRIPT_LOCALE_AUTORIZZATO>'
```

Oppure `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned` nella sessione dedicata. Il caricamento dello script sintetico innocuo, poi rimosso, certifica soltanto l'esecutore. Ogni nuovo processo indipendente deve applicare la modalita autorizzata: non presumere ereditarieta da una precedente chiamata exec.

Nessuna modifica persistente a CurrentUser/LocalMachine/MachinePolicy/UserPolicy, profili o registro. Nessun Bypass, Unrestricted, Invoke-Expression, conversione inline per eludere un blocco o alterazione di antivirus/AMSI/AppLocker/WDAC. In finally: attendere/chiudere soltanto i figli creati per il batch, terminare i processi dedicati oppure ripristinare il precedente valore Process se la sessione resta aperta. Verificare scope persistenti invariati, senza imporre Restricted come rollback inventato.

Root delle evidenze della ripresa: `C:\Temp\KeepStoreDbConfigHardening1A\20261020-resume-967934c1`. Risorse ammesse: soli file sintetici, eseguibili di prova, rapporti sanitizzati e chiavi CurrentUser univoche `KS-DBCFG-TEST-<GUID>` registrate prima della creazione. Cleanup in finally delle sole risorse create; nessun riuso di chiavi preesistenti, certificato installato nel trust store, identita Windows aggiuntiva, listener, servizio o DB. I rapporti possono conservare metadati/esiti di cleanup, senza segreti o chiavi private.

## 9. Criteri di accettazione e consegna Batch A

Prove mirate REV1 del codice candidato effettivo: **28 selftest guard, 20 casi Git sull'entrypoint reale, 22 casi ArtifactRoot e 24 file candidati PASS**. L'aggiunta privata staged passava con exit 0 prima del fix ed e rifiutata con exit 1 `PRIVATE_PUBLICATION_PATH` dopo il fix. Rimozione dal tracking e copia locale ignorata con file bloccato PASS, senza lettura privata; template esplicito ammesso. RSA/e-mail/parity/precompile/#361 immutati, prove precedenti riusate e non ripetute. Nessuna chiave nuova o operazione operativa in REV1; un commit figlio del candidato revisionato sulla stessa PR DRAFT e review differenziale ChatGPT ancora pendente. Le evidenze seguenti sono il Batch A precedente.

I due self-test sono modalita esplicite separate: `-SelfTest` prova le regole del guard; `-GitCandidateSelfTest` crea esclusivamente fixture Git sintetiche nella `-TestRoot` autorizzata. La modalita normale non crea fixture implicitamente. Esempi Windows PowerShell 5.1 per il solo perimetro REV1 autorizzato, senza estendere la destinazione ad ambienti operativi:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned `
    -File 'C:\KeepStoreWeb\KeepStore3.0\Tools\Test-DatabaseSecretsGuard.ps1' -SelfTest

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned `
    -File 'C:\KeepStoreWeb\KeepStore3.0\Tools\Test-DatabaseSecretsGuard.ps1' `
    -GitCandidateSelfTest -TestRoot 'C:\Temp\KeepStoreDbConfigHardening1A\20261020-rev1-c516f63b'
```

Eseguire il codice candidato effettivo: nome/origine e assenza fallback; configurazione assente/vuota/malformata/provider errato; RSA nativa, chiave assente/errata e ciphertext corrotto; recupero sintetico e cleanup; default non mutativo/Apply/idempotenza/failure rollback; lettura con consumatori reali e wrapper/runner compilati; e-mail/parity offline; precompile 4.8 senza configurazione operativa; conservazione file/metadati e stato locale; guard positivo/negativo; diff/manifest/invarianti.

Evidenze tecnico-locali PASS: **43 asserzioni RSA (42 core + probe aggregata), 13 check dei consumatori reali**, **45 risorse / 3 chiavi di prova / 0 residui**; provisioning **21/21**, verifier **7/7 + 33/33**, parity offline **141/141 + 20/20 fixture**, guard **28 selftest PASS** e controllo incrementale dei **24 file candidati**. Integrazione sintetica **12 check PASS** su installazione da template fail-closed, update preservato, untracking senza cancellazione locale, guard artefatti positivo/negativo e precompile da export con zero `web.config` operativo. Precompile ASP.NET Framework 4.8 dal template **353 input PASS**, anche da export. Rapporti finali `final-report.md`/`final-report.json` nella root evidenze, con commit/URL PR e verifiche conclusive di preservazione/manifest; nessun nuovo test operativo attestato. Riutilizzate #361 e le prove immutate nel loro perimetro, senza ripeterne il collaudo o usarle per certificare la nuova protezione. Misure locali di costo non dimostrano miglioramenti di prestazioni del sito.

Dopo PASS tecnico: stage esclusivo 25 percorsi, un commit, push del solo task branch e PR DRAFT verso `frontend-rebuild`. CI **NON CONFIGURATA**, non PASS; push autorizzato dal mandato corrente, nessuna deroga #361 riutilizzata. Stable/main invariati; nessun merge/deploy. Prossimo passo unico: review indipendente della PR da parte di ChatGPT.

## 10. Migrazione, revoca e recupero operativo — non avviati

Il progetto completo distingue B laboratorio DB isolato con dati sintetici, C rollout graduale per consumer effettivo, D invalidazione credenziali esposte e verifica finale. Servono manifest e autorizzazioni propri, senza riaprire audit generici o richiedere bonifiche storiche per il Batch A.

Prima di C/D il responsabile attesta applicazione/consumer, ambiente, ConfigPath, identita/pool, riferimento opaco account, oggetti/operazioni, DEFINER, versione/autenticazione server, TLS, finestra e recupero. Non dedurre tutti i consumer dalle connessioni attive o applicazioni diverse dai soli domini. Nessun `GRANT ALL`, privilegio globale, DROP/RENAME dell'account esposto o supposizione sulle password doppie. Web richiede anche scritture legittime; includere routine/viste e letture `city_registry.postcode_codes`, `cities`, `provinces` pertinenti.

TLS target: verifica certificato e hostname con `VerifyFull`, senza fallback silenzioso. Non cambiare endpoint per aggirare un certificato incompatibile. Migrare un consumer alla volta e collaudare connessioni fisiche nuove; gestire richieste, callback, job e sessioni InProc con interventi mirati, senza riavvio IIS globale.

Backup cifrato fuori repository/webroot: configurazione, ACL, riferimenti provider e materiale di recupero chiavi, con custode e prova ripristino. Nessuna copia in chiaro indiscriminata delle configurazioni censite, pulizia di dump o eliminazione implicita di credenziali SMTP. Prima della revoca deve esistere una release compatibile con configurazione protetta e una configurazione di recupero con credenziali valide nuove/sostitutive. **Il vecchio file con password revocata non ripristina il servizio.** Nessuna riattivazione del vecchio segreto come rollback permanente o restore automatico dei dati operativi.

Handoff a Enzo/Vincenzo per gestionale e INVIADOCUMENTI: consumer/versione e responsabile, origine effettiva della configurazione, riferimento opaco account, metodo sicuro di aggiornamento, dipendenze, test e rollback. Il registry `connessioni` e una dipendenza da attestare, non un pannello gia compatibile con Protected Configuration. Nessuna interfaccia gestionale e implementata dal Batch A; un eventuale adattamento deve avere specifica e autorizzazione proprie.

L'A operativo richiede migrazione/collaudo dei consumer in scope, privilegi/TLS verificati, vecchie credenziali inutilizzabili per nuove autenticazioni, sessioni residue e DEFINER gestiti e recupero provato. Rotazione machineKey e riscrittura storia Git restano separate; non dichiarare tutti i segreti del sistema bonificati. Questi criteri non sono condizioni mancanti dell'A tecnico-locale software.
