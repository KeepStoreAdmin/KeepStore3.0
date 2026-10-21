# KeepStore — preparazione offline del rilascio per applicazione

Contratto KS-G01, 2026-10-21: fase 1 `TENANT-RELEASE-PACKAGE-1A` integrata nella #367, fase 2 `TENANT-RELEASE-FILE-ATTESTATION-1A` sviluppata e provata esclusivamente su directory sintetiche TEMP. **CONSEGNA SERVER SOSPESA PER DECISIONE PO**: nessuna destinazione reale autorizzata, raccolta sul server, copia, archivio operativo, migrazione o deploy. Regole permanenti in [AGENTS](../AGENTS.md), stato in [START_HERE](KEEPSTORE_START_HERE.md), priorita in [PRODUCT_ROADMAP](KEEPSTORE_PRODUCT_ROADMAP.md).

## 1. Sorgente integrato e sito aggiornato sono due fatti distinti

La PR #366 e CHIUSA A / SOURCE INTEGRATED nel commit `c8373b08eff0cf9557798802ea4a2d6bfb8e4822`. Questo attesta il codice Git revisionato. Non attesta quale versione sia installata in alcuna applicazione IIS. Due vetrine possono usare lo stesso codice e database, ma physical path, configurazione, identita, asset e data di aggiornamento differenti. Anche due applicazioni con database separati seguono il medesimo procedimento. Il database non identifica da solo la destinazione.

Il generatore confronta **due commit espliciti**. Il parametro FROM indica solo la baseline del confronto: non viene mai trasformato in un commit installato verificato. Il record di destinazione resta UNKNOWN e il piano resta bloccato per la pubblicazione. Un risultato tecnico A di questo batch non chiude KS-G01 per il rilascio reale.

La [#367 CHIUSA A / SOURCE INTEGRATED](https://github.com/KeepStoreAdmin/KeepStore3.0/pull/367) aggiunge il generatore al sorgente stabile `55bd8173fb03fd85f6a892bf2a728e7a02d61748`. Non lo installa sui siti. La fase 2 confronta i soli file espliciti ammessi con gli hash del piano, conservando sconosciuti commit installato e readiness del sito.

## 2. Preparare e leggere il piano

Operazione locale per Codex o un tecnico incaricato; all'operatore viene consegnato il rapporto leggibile. Lo strumento e [New-KeepStoreTenantReleasePlan.ps1](../Tools/New-KeepStoreTenantReleasePlan.ps1), compatibile con Windows PowerShell 5.1 e Git gia presente. Non ha modalita Apply, deploy, ZIP, accesso remoto, lettura IIS/DB o sincronizzazione siti.

Esempio **storico non operativo**, con cartella TEMP nuova fuori dal repository:

```powershell
$output = Join-Path $env:TEMP ('KeepStore-plan-' + [Guid]::NewGuid().ToString('N'))
& .\Tools\New-KeepStoreTenantReleasePlan.ps1 `
    -RepoRoot 'C:\KeepStoreWeb\KeepStore3.0' `
    -FromCommit 'de85cdd4ba8dfe80ec3a9dcf12390480bd1afc42' `
    -ToCommit 'c8373b08eff0cf9557798802ea4a2d6bfb8e4822' `
    -OutputDirectory $output `
    -TargetLabel 'historical-comparison-only'
```

Non creare prima la directory finale: il generatore rifiuta directory esistenti e non cancella o sovrascrive output. Il padre deve esistere. Repo e output devono essere locali, senza reparse point o percorsi di rete; l'output deve stare nella TEMP del processo e fuori dal repository. Occorrono SHA completi, esistenti e in relazione antenato-discendente; sono ammessi due SHA uguali per verificare un delta vuoto. L'etichetta e opaca (lettere, numeri, trattino, underscore), non un dominio o un percorso privato.

Prodotti: **solo `plan.json` e `plan.md`**, UTF-8, senza payload. JSON e Markdown sono deterministici a parita di commit, oggetti Git ed etichetta; non contengono data corrente, radice privata o valori di configurazione. Codice uscita 0 significa piano generato, **non** pronto al rilascio. Codice 1 indica precondizione, oggetto Git o I/O non verificabile; l'errore e sanitizzato. Un output incompleto dopo un errore non va utilizzato: conservarlo per diagnosi e usare una directory nuova, senza pulizie automatiche.

| Campo / esito | Significato e azione dell'operatore |
| --- | --- |
| `Comparison.FromCommit` / `ToCommit` | Estremi esatti del confronto; verificare che appartengano al mandato |
| `Changes` | Tutte le differenze, comprese quelle escluse o bloccate |
| `RuntimePaths` | Superfici web interessate; leggere anche `Disposition`, non usarlo come lista di copia |
| `CANDIDATE_PLAN_ONLY` | Percorso runtime classificato; nessuna copia autorizzata |
| `EXCLUDED_FROM_TRANSFER` | Tools, manuali, configurazioni, chiavi, dati, SQL, archivi o test; contenuto non letto dal generatore |
| `BLOCKED_REVIEW_REQUIRED` | Percorso/tipo ignoto, ambiguita Windows, symlink, submodule o tipo cambiato: fermare il gruppo e chiedere verifica tecnica |
| `BeforeSHA256` / `AfterSHA256` | Hash dei byte esatti dei blob runtime ammessi; nessuna conversione CRLF, filtro di checkout o file della working copy |
| `Dependencies` | Dipendenze dirette controllate nel commit candidato, hash e appartenenza al delta; non equivalgono a presenza sul sito |
| `SourceAnalysis=REVIEW_REQUIRED` | Limite o dipendenza da valutare; non e automaticamente un difetto applicativo |
| `ReleaseReadiness=BLOCKED_TARGET_NOT_VERIFIED` | Esito obbligatorio di questa fase per ogni destinazione |

ADDED rimane ADDED: il file deve risultare realmente assente prima di una futura aggiunta. Se esiste gia, non diventa silenziosamente MODIFIED. MODIFIED richiede un hash iniziale riconosciuto e backup. DELETED e RENAMED sono richieste di verifica futura, mai comandi eseguibili; conservano origine/destinazione e hash quando il contenuto e ammesso. Le rinomine sono riconosciute al **100% di identita del blob**, senza leggere configurazioni escluse per stimarne la somiglianza. Uno spostamento con modifica resta DELETE + ADD, entrambi visibili e soggetti a review/backup. Le rinomine che cambiano solo maiuscole e minuscole richiedono un piano Windows manuale.

Percorsi con spazi e Unicode e file binari sono supportati. Slash relativi canonici, segmenti, nomi riservati, controlli, traversal, lunghezze Windows, collisioni case-insensitive e di normalizzazione sono verificati. Il generatore legge gli alberi e blob Git, mai file untracked/ignorati o `web.config`. Non applica filtri Git, textconv o lazy fetch; un oggetto mancante ferma il piano. Richiede il supporto all'opzione Git `--no-lazy-fetch` (verificata su Git 2.52.0.windows.1); una versione incompatibile si ferma, senza tentare fetch o installazioni. Limiti di risorse dichiarati: 32 MiB per lettura Git, 128 MiB complessivi di blob memorizzati, 2 MiB per scansione testuale diretta. Non dividere una release in copie parziali per eludere un limite: chiedere la pianificazione tecnica del gruppo.

## 3. Completezza e dipendenze WebForms

Sono riconosciuti pagine, master, controlli ASCX e code-behind VB, handler/servizi/global WebForms, App_Code, DLL Bin, risorse ASP.NET e asset tracciati CSS/JS/immagini/font. Un'estensione non riconosciuta resta bloccata. Non vengono aggiunte automaticamente intere directory del sito o asset privati.

Il generatore controlla riferimenti letterali `CodeFile`, `CodeBehind`, `MasterPageFile`, `Register Src`, coppie markup/code-behind, src/href statici del markup, URL CSS e varianti tracciate di `ThemeManager.Asset`. La presenza di cache-buster viene registrata, senza riportare valori query; correttezza/versione del token e tema attivo restano da verificare. Riferimenti JavaScript costruiti dinamicamente, espressioni ASP.NET generiche, classi usate dal codice, configurazioni e caricamenti condizionali non vengono risolti per approssimazione: hanno gate di review, compilazione e smoke. Nessuna chiusura transitiva automatica dichiarata.

Una dipendenza presente solo nel sorgente e `SOURCE_PRESENT`, con target `NOT_VERIFIED`. Se non e nel delta, non viene copiata automaticamente: il futuro inventario deve dimostrare la compatibilita installata. Una dipendenza non trovata e `MISSING_IN_SOURCE`, non una prova che manchi in produzione; un asset tenant potrebbe essere intenzionalmente fuori Git. In entrambi i casi serve una decisione tecnica prima di liberare il gruppo.

Esempio storico #363 -> #366: **23 differenze Git = 13 runtime + 4 Tools + 6 manuali** (6 ADDED, 17 MODIFIED; nessun DELETE/RENAME in questo intervallo). I due ADDED runtime sono `App_Code/SearchSuggestCommercialSupport.vb` e `Public/assets/keepstore/js/ks-shopping-guide.js`: ometterli produce una consegna incompleta. Dal codice reale, `search_suggest.aspx.vb` usa il nuovo helper; helper e catalogo dipendono da `StorefrontEffectivePriceSqlBuilder` e `StorefrontPromotionCatalogProvider`. La HOME referenzia il nuovo JS e il controller HOME; master/header, CSS e cache-buster partecipano allo stesso rilascio. Le dipendenze non cambiate (ad esempio code-behind della master, controlli e script comuni) rimangono oggetto di verifica target; non vengono proclamate aggiornate.

## 4. Record indipendente di ogni destinazione

`Target` e un modello preparatorio, non un input per aggirare i gate. Il generatore emette soltanto UNKNOWN / NOT_VERIFIED / NOT_EXECUTED e `Approval=NOT_AUTHORIZED`. Un futuro processo autorizzato dovra mantenere provenienza ed evidenze opache delle attestazioni, senza segreti o percorsi privati nei rapporti pubblicabili.

| Dato per applicazione | Ora | Requisito futuro prima del rilascio |
| --- | --- | --- |
| Id opaco / ambiente / identita applicazione | Etichetta / UNKNOWN | Destinazione e ambiente attestati e autorizzati |
| Commit installato | UNKNOWN, SHA nullo | VERIFIED con registro affidabile e inventario/hash coerenti |
| Commit candidato | SHA TO verificato in Git | Release revisionata e autorizzata |
| Physical path | UNKNOWN, valore nullo | VERIFIED separatamente dalla connessione DB o dal dominio |
| Configurazione, branding e asset | NOT_VERIFIED | Compatibilita e preservazione attestate senza esportare segreti |
| Backup / ripristino | NOT_VERIFIED | Backup protetto, metadati e prova recupero validi |
| Compilation / smoke | NOT_EXECUTED | Framework compatibile e prove pertinenti autorizzate PASS |
| Database / migrazioni | NOT_ASSESSED_NOT_EXECUTED | Stato schema/contratti attestato, eventuali operazioni separatamente autorizzate |
| Rollback / pubblicazione | NOT_VERIFIED / NOT_EXECUTED | Piano provato, autorizzazione PO e registrazione esito |

Come si accerta il commit installato, **in una fase futura autorizzata**: un tecnico identifica l'applicazione e il physical path realmente servito, consulta l'ultimo registro di rilascio attendibile e confronta l'inventario dei file effettivi con i blob di quella release. Un solo hash, il logo, un dominio, un branch o il database non provano un intero commit. File differenti non riconosciuti o inventario parziale mantengono UNKNOWN; non sovrascriverli per rendere il confronto uniforme. Ogni applicazione ha il proprio record anche con DB condiviso. La topologia storica nel [manuale IIS](KEEPSTORE_LOCAL_IIS_ENVIRONMENT.md) non autorizza una destinazione.

## 5. Backup, applicazione e rollback futuri

La sequenza seguente e una checklist progettuale, **non** un'autorizzazione o script di esecuzione.

1. Verificare target, commit installato, release candidata, allowlist PO e assenza di gate critici aperti. Completare review e dipendenze; nessuna deroga ereditata dalla #366.
2. Rilevare hash e stato effettivo dei soli file coinvolti, inclusi entrambi i percorsi delle rinomine e le assenze iniziali. Un hash differente non prova una versione vecchia riconosciuta. Bloccare le sostituzioni ambigue.
3. Preparare backup cifrato fuori webroot/repository dei file coinvolti, ACL, attributi e date, con verifica hash e prova di ripristino. Custodire configurazioni e chiavi secondo lo standard segreti, senza copiarle nel piano o in un archivio indiscriminato.
4. Pianificare il gruppo coerente di markup, code-behind, App_Code, DLL, JS/CSS e cache-buster. Gestire ricompilazione, sessioni InProc, callback e job nella finestra approvata; nessun restart IIS globale implicito. Creazione del payload e trasferimento richiedono un mandato separato.
5. Prima di ogni futura cancellazione/rinomina servono stato reale verificato, backup valido e autorizzazione specifica. Il piano non contiene comandi di cancellazione, overwrite, restore o copia sito.
6. Dopo un futuro intervento autorizzato, verificare hash candidati e collaudi tenant-scoped anonimi/autenticati, prezzi/listini, navigazione e flussi interessati, oltre a compilazione e sicurezza/TLS pertinenti. Un hash corretto non e uno smoke PASS.
7. Rollback file: ripristino completo del gruppo e metadati, verifica hash originari; rimozione di un'aggiunta solo se l'assenza iniziale e documentata e la rimozione e autorizzata. Configurazioni private, asset, upload e dati cliente devono risultare preservati.

Rollback Git/file, rollback DB e recupero dati sono distinti. Il piano non inventa una transazione sul database, non annulla ordini o migrazioni e non ripristina credenziali revocate. Se un aggiornamento richiede un cambiamento DB, il relativo backup/recupero deve essere definito e autorizzato separatamente. Per checkout, carrello persistente, ordini, e-mail e gateway valgono anche i rispettivi runbook e gate.

## 6. Materiale storico e prove

La cartella conservata `C:\Temp\KeepStoreReleaseDelivery\20261020-76d97a2c-cb2febd7` contiene sei file: collector PS1, manifest JSON/CSV, guida e due rapporti. E stata esaminata in sola lettura per nomi, formati, hash e logica; nessuno script eseguito o materiale spostato/modificato. Il riferimento `76d97a2c...` e una release storica, non un FROM installato attestato. La lista fissa di 84 percorsi, etichette tenant, remapping logo e istruzioni di raccolta/server non sono trasferiti nel generatore riutilizzabile.

Riusati i principi deny-first dei percorsi, rifiuto dei reparse point, hash binari e distinzione fra identico/assente/differente non riconosciuto, gruppi di dipendenze e backup/rollback con metadati. L'autorizzazione storica alla raccolta non viene ripresa. Lo strumento canonico e uno solo e prepara il delta Git; non e un secondo collector di siti.

Suite: [Test-KeepStoreTenantReleasePlan.ps1](../Tools/Test-KeepStoreTenantReleasePlan.ps1), Windows PowerShell 5.1 in processo dedicato `RemoteSigned` secondo l'autorizzazione documentata nel Masterplan; nessuna policy persistente cambiata. Fixture Git sintetiche senza remoti, dati operativi o rete; rapporti in TEMP, cleanup in finally della sola radice univoca delle fixture. Copertura add/modify/delete/rename, Unicode/spazi/binario, esclusioni, helper/JS/CSS e cache-buster, missing/unknown, symlink/submodule, collisioni Windows e traversal, SHA/ancestry, output protetto, determinismo, due applicazioni sintetiche con baseline diverse e confronto storico 23/13. Anche dopo un PASS, compilazione ASP.NET, MySQL, login reale, IIS/HTTP e produzione non sono certificati da questa suite.

Fermarsi e chiedere verifica tecnica per BLOCKED/REVIEW_REQUIRED, record UNKNOWN, hash target differente non riconosciuto, dipendenza mancante/ambigua, backup non provato, compilation/smoke non PASS o autorizzazione target assente. L'uscita 0 del generatore e il completamento della suite non concedono il deploy.

## 7. Verificare i file osservabili: fase 2

Lo strumento [New-KeepStoreTenantFileAttestation.ps1](../Tools/New-KeepStoreTenantFileAttestation.ps1) e un lettore di file, senza funzioni di copia, cancellazione o aggiornamento. Usa Windows PowerShell 5.1 Desktop e API Windows/.NET gia disponibili, senza moduli o programmi da installare. Nella fase corrente **si esegue solo sulle cartelle sintetiche create dalla suite**. Prima di usarlo su una cartella realmente servita occorrono review e autorizzazione separate, con directory esplicita e piano approvato; non cerca siti IIS o altre installazioni.

| Elemento | Cosa dimostra |
| --- | --- |
| Manifest Git (`plan.json`) | Quali file differiscono tra FROM e TO e quali hash sono attesi; FROM non e una prova di installazione |
| Osservazioni (`attestation.json` / `.md`) | Quali byte sono stati letti nei soli percorsi runtime ammessi in quella cartella |
| Commit installato verificato | Richiede registro affidabile, identita/mapping dell'applicazione e inventario coerente completo; un confronto parziale non basta |
| Readiness e autorizzazione al deploy | Richiedono inoltre dipendenze, configurazioni/asset preservati, backup/ripristino, prove applicative e decisione di rilascio |

I quattro parametri sono tutti obbligatori: `PlanPath` (JSON locale del generatore #367), `InspectionRoot` (directory locale esplicita), `OutputDirectory` (nuova directory sotto la TEMP del processo, disgiunta dal target) e `TargetLabel` (etichetta opaca di 1-64 caratteri alfanumerici, trattino o underscore; nessun dominio, percorso o dato personale). Il verificatore non usa Git e non riesegue il generatore: controlla il contratto e gli hash dichiarati dal piano, non ne certifica provenienza o firma. Prima di un uso reale il tecnico deve accertare l'origine del piano.

Prima di leggere il target rifiuta schema/modo/permessi errati, SHA e hash non validi, contatori o RuntimePaths incoerenti, classificazioni/disposizioni incompatibili, tipi Git non regolari, percorsi ostili e collisioni Windows anche nei prefissi delle directory. I metadati Changes gia esclusi coerentemente dal generatore sono accettati come **inerti**: non diventano percorsi da ispezionare, non ricevono hash e non sono ripubblicati nei rapporti. Tentare di promuovere `web.config`, dati o Tools a runtime viene rifiutato. Dipendenze e file non elencati non vengono cercati automaticamente: nessuna enumerazione ricorsiva del target.

Percorsi assoluti/device/ADS/traversal nel manifest, root di rete e redirect filesystem non sono ammessi. La catena locale e controllata con handle aperti senza seguire il reparse dell'elemento; nome finale e tipo vengono verificati prima di leggere dati. Directory case-sensitive, junction/symlink, hardlink, file offline o tipi inattesi sono bloccati; se il sistema non permette di accertare questi metadati l'osservazione fallisce chiusa. Un accesso negato non va risolto elevando privilegi o saltando il controllo. La TEMP e le sue antenate devono consentire le necessarie letture di metadati. Nessuna ACL viene modificata.

| Stato per percorso | Interpretazione |
| --- | --- |
| `CANDIDATE_MATCH` | Hash dei byte identico all'hash TO dichiarato dal piano; non certifica l'intero candidato installato |
| `BASELINE_MATCH` | Hash identico a FROM, senza dedurre il commit installato |
| `MISSING` | File o directory intermedia assente; nessuna creazione autorizzata |
| `DIFFERENT_UNKNOWN` | File presente con hash non riconosciuto: richiede verifica prima di qualsiasi sostituzione |
| `UNREADABLE` | Lettura completa/stabile impossibile, sharing/accesso negato, metadati o budget non verificabili; nessun hash parziale positivo |
| `BLOCKED_UNSAFE_PATH` | Reparse, tipo, hardlink, collisione o altro percorso non sicuro; non seguire il redirect |

Per ADDED sono distinte assenza reale, candidato gia presente e collisione preesistente con contenuto diverso. Per DELETED sono distinte assenza e baseline ancora presente, senza suggerire rimozioni automatiche. RENAMED produce due righe indipendenti, origine e destinazione. Quando baseline e candidato hanno lo stesso hash, `MatchesBothExpected` lo rende esplicito; a parita di hash la riga ordinaria privilegia lo stato candidato. Non si applica questa priorita a un'origine di rinomina o a DELETED, che hanno solo l'hash di origine pertinente.

Il JSON include schema `KeepStore.TenantFileAttestation.v1`, SHA256 del piano, FROM/TO, etichetta, percorsi relativi, hash attesi/osservati ammessi, stati, motivi, conteggi, limiti e gate. Il Markdown e la lettura sintetica per l'operatore. Sono gli unici due file creati, senza contenuti, path fisico completo, account Windows o dati di configurazione. Output gia esistenti sono rifiutati. Codice 0 significa che le osservazioni sono state prodotte, **anche se alcune sono UNREADABLE/BLOCKED**; non significa target verificato. Codice 1 segnala piano/precondizione/output non validi in forma sanitizzata; non usare un output incompleto e non cancellarlo automaticamente. A parita di input e stato osservabile i report sono deterministici, senza timestamp corrente.

Gli hash sono calcolati in streaming sullo stesso handle aperto solo in lettura con condivisione che rifiuta normali writer e cancellazioni durante l'apertura. Due passate e metadati confrontati rilevano cambiamenti osservabili, senza promettere una transazione o uno snapshot atomico di tutti i file. Limiti: piano 4 MiB, massimo 4096 record per array, percorso manifest 200 caratteri e percorso completo 240; massimo 128 MiB per file e 512 MiB complessivi di lettura (due passate comprese). Budget cooperativi di 15 secondi per file e 120 secondi tra le operazioni: non sono deadline capaci di interrompere una singola chiamata nativa bloccata. Un limite raggiunto non produce match con hash parziale.

**READ-ONLY e date di accesso.** Lo strumento non scrive contenuti o metadati del target. La lettura puo pero aggiornare automaticamente LastAccessTime secondo filesystem e Windows ([Microsoft File Times](https://learn.microsoft.com/en-us/windows/win32/sysinfo/file-times)). La decisione tecnica `TEST20-LASTACCESS-ENVIRONMENT-1A`, assunta da ChatGPT nel mandato generale, ammette esclusivamente questo effetto informativo: non e una nuova dichiarazione specifica del PO. Restano invarianti contenuti/SHA256, dimensione, CreationTime, LastWriteTime, attributi e ACL. Vietati SetFileTime/SetLastAccessTime, correzioni artificiali delle date, registro o policy per mascherare la variazione. La suite verifica separatamente che il file di controllo non letto mantenga anche LastAccessTime.

Le prove [Test-KeepStoreTenantFileAttestation.ps1](../Tools/Test-KeepStoreTenantFileAttestation.ps1), **73/73 PASS** su PS 5.1.26100.9711, creano un repository sintetico senza remoti e due cartelle A/B in TEMP, invocando una volta il generatore reale per il piano. Provano i sei stati, aggiunte/cancellazioni/rinomine, byte binari e Unicode, junction reale, hardlink, errori di lettura, JSON/percorso ostile, esclusioni, assenza di dati privati nell'output, determinismo, test 20 e cleanup finally. Il caso non leggibile e una violazione di sharing riproducibile, non una certificazione di ACL operative. Non e stata forzata una modifica arbitraria durante la lettura con filesystem o driver ostile: nessuna atomicita certificata. I 59 test del generatore #367 sono riusati per i contratti immutati, non ripetuti; nessuna prova applicativa/IIS/DB o cartella operativa da questa suite.

Lo stato complessivo e sempre **TARGET_ATTESTATION_INCOMPLETE**, anche con tutti i percorsi CANDIDATE_MATCH. Inventario completo, identita IIS, commit installato indipendentemente verificato, backup/ripristino, compatibilita/dipendenze, prove commerciali e autorizzazione al rilascio restano gate aperti. Le applicazioni A e B hanno rapporti indipendenti, anche con database condiviso; nessuna attestazione passa automaticamente da una all'altra.
