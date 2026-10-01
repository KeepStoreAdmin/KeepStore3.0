# Persistent Anonymous Cart — deployment e rollout

Data: 2026-10-01. Release runtime di riferimento: `frontend-rebuild` al checkpoint `a4238abfc8eae7fefbb985672d4cd5bddabf4118` (#297 runtime, #298 cleanup, #299 privacy; tutti CHIUSI A e integrati FF-only). Questo runbook e una procedura futura, non evidenza di deployment gia eseguito. Stato iniziale: **INTEGRATED / NOT YET PRODUCTION-CERTIFIED**.

## 1. Scopo

Rilasciare il carrello anonimo persistente, la relativa informativa e il cleanup bounded su istanze KeepStore esplicitamente autorizzate. Nessun ordine, pagamento, gateway o e-mail e necessario. Nessuna discovery automatica, installazione automatica di scheduler o modifica delle credenziali. Masterplan e System Blueprint descrivono il contratto; questo documento descrive l'esecuzione operativa.

## 2. Prerequisiti

- Autorizzazione Product Owner per ciascuna coppia istanza/database + azienda, server, finestra e operazioni consentite, compresi smoke mutativi tramite applicazione e cleanup. Compatibilita non significa autorizzazione.
- HTTPS funzionante sul dominio canonico, ASP.NET Framework 4.8/WebForms, MySQL con foundation verificata; nessuna modifica automatica a hosts/TLS/IIS.
- Identificare physical path reale e configurazione dell'istanza, senza copiarne i segreti nel pacchetto, nella command line o nei log.
- Account test autorizzato e fixture ripristinabili. PROVA, se usato, resta conservato con password e audit invariati per tutta la durata del progetto.
- Release completa estratta dal commit Git approvato, non da una working directory con untracked. Nessun `git pull` nella webroot del server.

Inventario operativo comunicato dal Product Owner: `taikun`, `food`, `italcomed`, `ks_marea`, `ks_panificiosa`, `ks_vpsposa`, `miranda`, `tecind`. `ks_debug` NON e produzione. **Questa lista e inventario corrente, NON autorizzazione automatica al deployment**. Uno stesso database puo servire piu aziende/applicazioni IIS: elencare ogni ConfigPath + CompanyId autorizzato, non dedurlo dal nome database.

## 3. Pre-flight

1. Confermare commit della release e allowlist firmata/approvata; nessuna aggiunta automatica di database o aziende.
2. Verificare HTTPS, hostname canonico e isolamento tenant; preservare integralmente `web.config` server e secret/configurazioni specifici. Il cookie host-only non e condivisibile tra storefront.
3. Verificare backup DB fresco e backup dei file del sito con possibilita di recupero. Registrare percorsi protetti e hash del manifest, non credenziali.
4. Verificare foundation DB e `carrello(SessionId)` nella sola allowlist (sezione 5); STOP se un prerequisito e assente/non conforme. Non correggere schema durante il deploy file.
5. Identificare manutentore, finestra a basso traffico e criterio di rollback. Valutare impatto dell'AppDomain/recycle su autenticazione e idempotenza Session/InProc; non confondere questi registri con la persistenza del carrello.
6. Per cleanup/scheduler verificare Windows PowerShell, compilatore VB .NET Framework 4.8, dipendenze `Bin` della release e ACL dell'identita di manutenzione. Nessuna password o stringa di connessione negli argomenti.

## 4. Backup

- Prima di ogni deploy autorizzato: backup completo fresco del DB target, consistente e recuperabile, conservato in area protetta fuori repository/webroot. Non eseguire restore di prova sul DB operativo.
- Backup della release/file sito esistenti, inclusi nuovi file App_Code da confrontare con il manifest precedente. Conservare configurazioni locali/secret separatamente, protetti, senza distribuirli nel pacchetto.
- Registrare commit precedente, manifest/hash, data, ambiente e responsabile; nessun cookie, owner token, raw secret o dato personale nei report.
- Un backup non autorizza rollback distruttivi dei dati creati dopo lo snapshot.

## 5. Verifica foundation DB

Sulla connessione amministrativa autorizzata del solo destinatario usare la verifica read-only:

- [20260929_PERSISTENT_ANONYMOUS_CART_REGISTRY_1A_verify.sql](../Database%20Taikun/Migrations/20260929_PERSISTENT_ANONYMOUS_CART_REGISTRY_1A_verify.sql).
- Per preparare un eventuale intervento separato: [preflight](../Database%20Taikun/Migrations/20260929_PERSISTENT_ANONYMOUS_CART_REGISTRY_1A_preflight.sql). Non rilanciare il forward su uno schema gia valido.

Verificare registry `carrello_anonimo_persistenza`, struttura/constraint/indici canonici, collations case-sensitive dell'owner, tempi UTC a precisione richiesta, motori InnoDB e indice `IX_carrello_SessionId_ID` con colonne `(SessionId, id)` nell'ordine canonico. La verifica richiede anche `SessionId varchar(50)` con collation `utf8mb4_0900_bin`. Tutti i risultati richiesti devono essere conformi; se mancano, STOP e richiedere distinta autorizzazione alla migration, non improvvisare DDL.

Il precedente allineamento DB approvato non sostituisce questa verifica nel server destinatario. Il contratto di provisioning dei nuovi DB deve includere la stessa foundation; nessun nome database hardcoded nel runtime.

## 6. Deploy file

Preparare un pacchetto dal commit release approvato mantenendo percorsi e hash, confrontato con il commit realmente installato. Se la release precedente e quella ante #297, il manifest runtime cumulativo #297–#299 e:

```text
App_Code/CartMutationIdempotencyService.vb
App_Code/CartMutationService.vb
App_Code/CartOwnershipService.vb
App_Code/CartStorefrontOwnerContext.vb
App_Code/CartStorefrontScopePolicy.vb
App_Code/PersistentAnonymousCartOwnerService.vb
App_Code/PersistentAnonymousCartMutationActivation.vb
App_Code/PersistentAnonymousCartLifecycleService.vb
App_Code/PersistentAnonymousCartLoginMergeService.vb
App_Code/PersistentAnonymousCartCleanupService.vb
carrello.aspx.vb
privacy.aspx
Public/ui/controls/SiteFooter.ascx
```

1. Verificare anche le dipendenze preesistenti, in particolare `App_Code/CartTransactionRetryPolicy.vb`, i resolver/commercial services e `Bin/MySql.Data.dll`: questo delta non e un sito installabile da zero.
2. Copiare i soli file release autorizzati in finestra controllata, senza lasciare un App_Code parzialmente aggiornato. Preservare `web.config`, asset, uploads, App_Data/log e tutte le configurazioni locali. Nessun dump o credenziale nel pacchetto.
3. Per manutenzione amministrativa predisporre anche `Tools/Invoke-PersistentCartRegistryCleanup.ps1` e `Tools/PersistentCartCleanupRunner.vb` della stessa release, in area protetta non pubblicamente accessibile, con struttura `Tools`/`App_Code`/`Bin` compatibile col runner. Non copiare gli harness come endpoint production; negare accesso HTTP a Tools/configurazioni o usare un bundle di manutenzione fuori webroot.
4. Attendere la compilazione ASP.NET. Recycle IIS soltanto se necessario e autorizzato, mai come azione automatica per nascondere un errore. STOP su errore di compilazione, dipendenza mancante o host incoerente; registrare solo diagnostica sanitizzata.
5. Verificare commit/manifest realmente installati e HTTPS prima dello smoke. Non dichiarare la copia riuscita come RELEASE READY.

## 7. Post-deploy smoke

Un solo percorso tramite applicazione, con snapshot iniziale/finale sanitizzato; zero ordini, pagamenti, gateway o e-mail. Non stampare/salvare il valore del cookie: verificarne soltanto presenza e attributi tramite strumenti locali autorizzati.

1. Aprire browser anonimo pulito sul dominio autorizzato; un GET iniziale non deve creare il cookie carrello (il cookie ASP.NET di sessione preesistente e distinto).
2. Aggiungere una fixture disponibile con il normale percorso applicativo.
3. Verificare `__Host-KeepStoreCart`, Secure/HttpOnly/SameSite=Lax/Path=/, nessun Domain; nessun contenuto commerciale leggibile.
4. Aprire nuova sessione/browser context preservando soltanto il cookie carrello in memoria, senza trasferire autenticazione o salvarne il valore in file/log; verificare che il carrello si ritrovi.
5. Annotare scadenza, fare GET/read/no-op e verificare che non venga rinnovata; effettuare modifica reale quantita/add e verificare sliding 30 giorni (clock DB autorevole).
6. Svuotare tramite UI: registry REVOKED e cookie revocato/scaduto; non cancellare i record con SQL diretto.
7. Creare un nuovo carrello di fixture e accedere con account test autorizzato: merge con righe account iniziali e deduplicazione/rivalidazione corrette; registry CONSUMED e cookie eliminato.
8. Secondo refresh/login: nessun incremento duplicato. Nessuna prenotazione inventario, documento o effetto esterno.
9. `privacy.aspx` HTTP 200; informativa 30 giorni e link Privacy footer corretto. Verificare leggibilita mobile e desktop.
10. Ripristinare solo carrello/fixture tramite percorsi applicativi; conservare account test e audit, lasciando evidenza di task/data, ambiente/URL, articoli, snapshot carrello/documenti/wishlist/inventario, operazioni, esiti/anomalie e zero pagamenti/gateway/e-mail/ordini reali.

Le letture DB di supporto sono circoscritte all'istanza/azienda autorizzata. Non copiare righe carrello/owner, dati personali o cookie nei report.

## 8. Cleanup registry

Unico runner: [Tools/Invoke-PersistentCartRegistryCleanup.ps1](../Tools/Invoke-PersistentCartRegistryCleanup.ps1). Richiede `-Apply`, `ConfigPath` del `web.config` protetto dell'istanza corretta, `CompanyId` esplicito/autorizzato. Protezione del file tramite ACL e compatibilita col lettore XML del runner devono essere verificate prima; non esportare configurazioni/secret o disabilitarne la protezione per aggirare un errore.

Prima attivazione: un batch manuale controllato da 100, con nuova autorizzazione operativa. Output aggregato atteso: `ActiveExpiredProcessed`, `ActiveCartRowsDeleted`, `ConsumedDeleted`, `RevokedDeleted`, `Anomalies`, `Errors`, `CandidatesExamined`. Nessuna stringa di connessione in command line; il runner legge la configurazione in memoria e usa stdin internamente.

`ACTIVE` expired -> sole righe anonime + registry, atomicamente; `CONSUMED/REVOKED` expired -> registry soltanto se nessuna riga anonima residua. Account rows mai eliminate. Exit code non zero, Anomalies > 0 o Errors > 0: STOP e verifica manuale; non eliminare automaticamente anomalie terminali. Un batch riuscito non prova che tutto il backlog sia stato smaltito.

## 9. Windows Task Scheduler

Questa sezione documenta configurazione futura: **nessun task viene creato da questo runbook o dal runtime**. Raccomandazione: una esecuzione giornaliera a basso traffico, per ogni coppia ConfigPath + CompanyId esplicitamente autorizzata. Niente discovery automatica. L'identita Windows dedicata deve avere privilegi minimi adeguati per configurazione, compilazione/temp e manutenzione DB; nessuna credenziale negli argomenti o nell'output.

Predisporre, dopo autorizzazione e review operativa, un wrapper amministrativo protetto fuori area pubblica con l'esempio sotto. Task Scheduler deve chiamare Windows PowerShell con `-NoProfile -NonInteractive -File` sul wrapper, directory di avvio esplicita, esecuzioni non sovrapposte e controllo del risultato. Configurare un allarme operativo sui fallimenti (non e-mail inviata da questo task); verificare manualmente la prima esecuzione schedulata.

Limiti per coppia: BatchSize = 100, MaxBatchesPerRun = 100; massimo teorico 10.000 candidati esaminati nella finestra, non necessariamente record eliminati. Ripetere fino a `CandidatesExamined=0`, oppure STOP/FAIL al limite. Un batch da 100 non va assunto sufficiente; niente loop infinito. Tempi/timeout operativi vanno fissati nella finestra concordata e monitorati, senza aumentare automaticamente i limiti o ripetere job falliti.

Esempio generico e sanitizzato, **non eseguito da questa documentazione**. Sostituire `<COMPANY_ID>` con il solo ID autorizzato; il percorso e un placeholder, non il server reale. Il processo PowerShell separato e necessario perche lo script runner termina con `exit`: non chiamarlo direttamente nello stesso processo del loop.

```powershell
$ErrorActionPreference = 'Stop'
$releaseRoot = 'C:\Path\To\KeepStore'
$companyPlaceholder = '<COMPANY_ID>'
$companyId = 0
if (-not [int]::TryParse($companyPlaceholder, [ref]$companyId) -or $companyId -le 0) {
    Write-Output 'CLEANUP_COMPANY_REQUIRED'
    exit 2
}
$runnerPath = Join-Path $releaseRoot 'Tools\Invoke-PersistentCartRegistryCleanup.ps1'
$configPath = Join-Path $releaseRoot 'web.config'
$powershellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$batchSize = 100
$maxBatchesPerRun = 100

try {
    for ($batch = 1; $batch -le $maxBatchesPerRun; $batch++) {
        $lines = @(& $powershellPath -NoProfile -NonInteractive -File $runnerPath `
            -ConfigPath $configPath -CompanyId $companyId -BatchSize $batchSize -Apply 2>&1)
        $runnerExit = $LASTEXITCODE
        if ($runnerExit -ne 0) {
            Write-Output 'CLEANUP_BATCH_FAILED'
            exit 1
        }
        $metrics = @{}
        foreach ($name in @('CandidatesExamined', 'Anomalies', 'Errors')) {
            $matchesForMetric = @($lines | Where-Object { [string]$_ -match ('^' + $name + '=([0-9]+)$') })
            if ($matchesForMetric.Count -ne 1) { throw 'CLEANUP_METRICS_INVALID' }
            $value = 0
            if (-not [int]::TryParse(([string]$matchesForMetric[0]).Split('=')[1], [ref]$value)) {
                throw 'CLEANUP_METRICS_INVALID'
            }
            $metrics[$name] = $value
        }
        if ($metrics['CandidatesExamined'] -gt $batchSize) { throw 'CLEANUP_METRICS_INVALID' }
        if ($metrics['Anomalies'] -gt 0 -or $metrics['Errors'] -gt 0) {
            Write-Output 'CLEANUP_MANUAL_REVIEW_REQUIRED'
            exit 1
        }
        Write-Output ('Batch={0};CandidatesExamined={1};Anomalies=0;Errors=0' -f $batch, $metrics['CandidatesExamined'])
        if ($metrics['CandidatesExamined'] -eq 0) {
            Write-Output 'CLEANUP_WINDOW_COMPLETE'
            exit 0
        }
    }
    Write-Output 'CLEANUP_BATCH_LIMIT_REACHED_ALERT'
    exit 1
} catch {
    Write-Output 'CLEANUP_WRAPPER_FAILED'
    exit 2
}
```

Non stampare output raw o eccezioni. Metriche mancanti/duplicate/non valide falliscono chiuse. Non aggiungere wrapper, task o log al repository durante questa attivita documentale; la loro predisposizione operativa richiede autorizzazione separata. Se 100 batch non raggiungono zero, FAIL/ALERT: analizzare carico e backlog prima di un'altra finestra.

## 10. Rollback

- **Codice:** se il deploy fallisce prima dell'attivazione runtime, ripristinare i file della precedente release approvata dal backup/manifest, comprese rimozioni dei soli nuovi file release, senza toccare configurazioni/asset. Nessun reset indiscriminato della webroot.
- **Runtime gia attivato:** preservare DB e raccogliere evidenze sanitizzate prima di decidere il rollback. Il codice precedente puo non leggere `ksc2`; un rollback file non garantisce accessibilita dei carrelli gia persistenti. Nessuna conversione `ksc2 -> ksc1` o riadozione automatica.
- **Foundation DB:** NON suggerire DROP automatici se esistono dati. La presenza del registry dopo un rollback codice e preferibile alla perdita dei dati; eventuale rollback schema richiede preflight dedicato e nuova autorizzazione.
- **Dati cart:** nessun restore automatico di carrelli consumati/revocati o di snapshot vecchi su carrelli correnti. Non ricreare righe gia adottate dall'account, account/documenti o owner scaduti senza analisi; il cleanup completato non e reversibile dal solo rollback codice.
- Disabilitazione di un job gia attivato/recycle sono azioni operative da autorizzare e documentare; non eseguite da questo task.

## 11. Evidenze finali

Conservare report sanitizzato con data/task/ambiente, release SHA e manifest/hash, allowlist approvata, backup verificati, foundation preflight, risultati smoke e ripristino fixture, attributi/scadenze senza cookie value, contatori cleanup, numero batch/exit, configurazione schedulata approvata e prima esecuzione, anomalie e decisioni. Zero password, connection string, raw secret, OwnerToken, dati personali o contenuti carrello nei log. Conservare PROVA e i suoi audit, mai credenziali.

Non dichiarare deployment, cleanup o scheduler PASS sulla sola base dei precedenti test locali. Ogni coppia autorizzata conserva le proprie evidenze; un PASS non si propaga automaticamente agli altri storefront.

## 12. RELEASE_READY

Tutti i controlli seguenti devono essere PASS su ogni istanza/azienda autorizzata:

- [ ] Runtime deployed, manifest completo e compilazione server riuscita.
- [ ] DB foundation verified e indice SessionId conforme.
- [ ] Smoke anonymous persistence tra sessioni.
- [ ] Sliding su mutazione reale, GET/no-op invariati.
- [ ] Revoke su svuotamento.
- [ ] Login merge atomico e cookie eliminato.
- [ ] No duplication su secondo refresh/login.
- [ ] Privacy page HTTP 200, disclosure e footer corretti.
- [ ] Cleanup manual batch con contatori/esiti validi.
- [ ] Scheduler configured con target esplicito, loop bounded e allarme.
- [ ] First scheduled execution verified e finestra completata a zero candidati.
- [ ] Logs sanitized, backup recuperabili ed evidenze conservate.
- [ ] No operational anomaly unresolved; nessun ordine/pagamento/gateway/e-mail prodotti dallo smoke.

Solo allora: **PERSISTENT ANONYMOUS CART = RELEASE READY**. Fino ad allora: **INTEGRATED / NOT YET PRODUCTION-CERTIFIED**. Questa checklist non garantisce conformita GDPR complessiva e non autorizza l'avvio del task commerciale successivo.
