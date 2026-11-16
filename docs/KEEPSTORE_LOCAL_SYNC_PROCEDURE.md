# KeepStore 3.0 — Procedura di sincronizzazione della copia locale canonica (allegato normativo di AGENTS)

Testo integrale spostato da [AGENTS](../AGENTS.md) il 2026-11-16 (task `KS-GOV-AGENTS-ARCHIVE-1A`, su richiesta del PO per alleggerire il file caricato a ogni sessione), **senza modifiche**. **Vale quanto la sezione omonima di AGENTS**, che ne riporta il riassunto vincolante; in caso di dubbio prevale questo testo integrale. Decisione PO 2026-11-07, permanente.

---

### Procedura operativa obbligatoria — sincronizzazione della copia locale canonica (decisione PO 2026-11-07, PERMANENTE)

Applicazione permanente — KeepStore 3.0. Questa procedura deve essere applicata dopo ogni merge autorizzato in `frontend-rebuild` e ogni volta che il Product Owner richiede il riallineamento della copia locale canonica.

Repository: `KeepStoreAdmin/KeepStore3.0` · Branch stabile: `frontend-rebuild` · Percorso canonico: `C:\KeepStoreWeb\KeepStore3.0`

#### FASE A — Controlli preliminari

L'esecutore Windows incaricato deve:

1. Verificare l'esistenza del percorso canonico e che appartenga al repository KeepStore corretto.
2. Leggere le regole pertinenti di `AGENTS.md`.
3. Identificare branch, HEAD locale e SHA di `origin/frontend-rebuild`.
4. Eseguire `git fetch origin` senza modificare il working tree.
5. Verificare lo stato dello staging, i file tracked modificati, i file untracked e le cancellazioni locali.
6. Identificare il commit esatto approvato dal Product Owner.
7. Confrontare lo stato corrente con quello remoto, individuando i file applicativi da aggiornare.
8. Verificare che non vi siano operazioni Git incomplete o un secondo esecutore attivo sullo stesso percorso.

Il comando `git fetch` non autorizza automaticamente merge, reset o sovrascritture.
Non utilizzare `git pull` indiscriminatamente. Prima di integrare i commit remoti occorre verificare che l'operazione sia compatibile con le protezioni della copia locale.
Se il percorso non è quello atteso oppure il repository remoto non corrisponde a KeepStore, interrompere l'operazione.

#### FASE B — Protezione dello stato locale

Prima della sincronizzazione:

1. Identificare le modifiche locali non committate.
2. Preservare l'inventario storico protetto **53/52/4** (53 protetti, 52 untracked, quattro cancellazioni tracked) secondo il rapporto locale: e' la notazione dell'inventario da preservare, non tre gruppi necessariamente disgiunti da sommare.
3. Preservare gli untracked inventariati e gli ulteriori contenuti locali legittimi.
4. Conservare configurazioni operative, immagini, credenziali, upload e dati non versionati.
5. Predisporre una copia di sicurezza verificabile dei soli elementi a rischio di modifica, collocata fuori dal percorso di lavoro.
6. Registrare i percorsi coinvolti e, quando pertinente, le impronte dei file da preservare.

Il backup non deve diventare un nuovo archivio completo del progetto a ogni task, salvo effettiva necessità.
Non utilizzare `git stash` indiscriminatamente sui file protetti.
Non eseguire `git clean`, `git reset --hard`, `git checkout --force`, modifiche ACL generali o altri comandi che possano cancellare lo stato locale.

#### FASE C — Determinazione della strategia di aggiornamento

L'esecutore deve scegliere automaticamente la strategia meno invasiva.

**Caso 1 — Working tree compatibile con fast-forward.** Quando il branch locale è un antenato di `origin/frontend-rebuild` e non vi sono modifiche locali che possano essere sovrascritte:

- Verificare che lo SHA remoto sia quello autorizzato.
- Eseguire unicamente l'avanzamento fast-forward del branch locale.
- Non creare merge commit.
- Non effettuare rebase.
- Non utilizzare force.

**Caso 2 — Modifiche locali protette presenti.** Quando sono presenti modifiche o cancellazioni tracked protette:

- Non ripristinarle automaticamente.
- Non sovrascriverle per ottenere artificialmente uno stato Git pulito.
- Individuare se i commit remoti interessano gli stessi percorsi.
- Se non esistono conflitti, utilizzare una procedura Git non distruttiva compatibile con le modifiche locali.
- Se esistono conflitti, preservare i contenuti e sospendere esclusivamente l'aggiornamento incompatibile.
- Non utilizzare il ripristino forzato come soluzione.

**Caso 3 — Branch locale divergente.** Se il branch locale contiene commit propri non presenti sul remoto, non eseguire reset o rebase automatici.
L'esecutore deve distinguere i commit locali da quelli ufficiali, proteggere il lavoro esistente e segnalare il conflitto.
Un branch divergente non può essere dichiarato allineato attraverso una semplice copia di file.

**Caso 4 — Aggiornamento completo temporaneamente impossibile.** Se le protezioni impediscono la sincronizzazione integrale:

- Aggiornare soltanto ciò che è compatibile e autorizzato.
- Lasciare invariati i file in conflitto.
- Documentare esattamente i percorsi non allineati.
- Dichiarare B — ALLINEAMENTO PARZIALE.

Non è consentito usare una copia temporanea o un altro worktree come prova che il percorso canonico sia stato effettivamente aggiornato.

#### FASE D — Sincronizzazione applicativa

Durante l'aggiornamento devono essere inclusi tutti i file versionati appartenenti ai commit integrati, secondo il loro stato finale nel branch ufficiale:

- Pagine ASPX e code-behind VB.NET.
- Master Page e User Controls.
- Classi e servizi `App_Code`.
- JavaScript, CSS e risorse applicative versionate.
- Componenti e dipendenze necessarie.
- Test e strumenti.
- Manuali e documentazione canonica.

Devono essere considerate anche aggiunte, rinominazioni ed eliminazioni versionate, rispettando le eccezioni locali protette.
La sincronizzazione deve essere cumulativa: non deve limitarsi ai file dell'ultima PR se la copia locale risulta arretrata rispetto a commit precedenti.
Non è autorizzato trasferire file dal pacchetto di rilascio ZIP come sostituto della sincronizzazione Git.
La directory canonica deve rappresentare lo stato SOURCE più recente effettivamente integrato e autorizzato.

#### FASE E — Verifica dell'integrità

Completata la sincronizzazione, l'esecutore deve:

1. Confrontare HEAD locale e HEAD remoto.
2. Verificare la corrispondenza dei file versionati previsti.
3. Controllare che le modifiche locali protette siano rimaste inalterate.
4. Confrontare l'inventario protetto pre/post.
5. Verificare che non siano stati introdotti file temporanei nello staging.
6. Controllare che nessun file critico dell'applicazione sia rimasto a una revisione precedente senza essere dichiarato.
7. Verificare eventuali dipendenze non ancora soddisfatte.
8. Eseguire compilazione e test mirati soltanto quando necessari o richiesti dal micro-task.

Non ripetere suite complete o audit forensi già acquisiti in assenza di modifiche pertinenti.
Le verifiche dei file versionati devono distinguere eventuali differenze locali autorizzate da discrepanze applicative non autorizzate.
La corrispondenza dello SHA del branch non è sufficiente per certificare la corrispondenza del filesystem.

#### FASE F — Classificazione dell'esito

**A — ALLINEAMENTO COMPLETO.** Consentito soltanto se:

- Lo SHA locale corrisponde al commit remoto approvato.
- Tutti i file applicativi richiesti risultano aggiornati.
- Le protezioni locali sono preservate.
- Non esistono differenze applicative non riconciliate.
- Il controllo finale è stato effettuato direttamente sul percorso canonico.

**B — ALLINEAMENTO PARZIALE.** Da utilizzare quando almeno un file o una dipendenza richiesta non può essere aggiornata o verificata.
Il rapporto deve specificare quali elementi mancano e perché.

**E — BLOCCO OPERATIVO.** Da utilizzare quando non è possibile procedere in sicurezza, ad esempio per repository errato, impossibilità di verificare il riferimento remoto, conflitto distruttivo non risolvibile o accesso locale insufficiente.

Nessun esito A può essere attribuito sulla sola base di una dichiarazione non verificata.

#### FASE G — Report finale obbligatorio

Esecutore: **Codex e' l'esecutore Windows ordinario**; Claude Code puo' eseguire la procedura e redigerne il rapporto soltanto quando il PO lo incarica espressamente e dispone di accesso reale al filesystem Windows. Un solo esecutore attivo per working copy/branch.

Al termine dell'operazione, l'esecutore che ha operato realmente sul filesystem deve produrre un rapporto sintetico, preferibilmente entro 12 righe, contenente:

STATO COPIA LOCALE CANONICA

- Esito: A / B / E.
- Percorso effettivamente aggiornato.
- SHA GitHub di riferimento.
- SHA locale finale.
- Numero di file versionati confrontati.
- Numero di file aggiornati, aggiunti, rinominati o eliminati.
- Elenco dei file applicativi aggiornati dal micro-task.
- Stato dei file locali protetti e dell'inventario 53/52/4.
- Eventuali differenze residue.
- Test o compilazione eseguiti, se pertinenti.
- Staging e stato Git finale.
- Conferma esplicita che il filesystem del percorso canonico è stato verificato.

Quando i file modificati sono numerosi, l'elenco completo deve essere conservato in un manifest locale, mentre il rapporto riporta il totale e i percorsi principali.
Il Product Owner deve poter identificare senza ambiguità quali file sono stati realmente modificati nel proprio PC.

#### FASE H — Continuità operativa dei micro-task successivi

Ogni nuovo micro-task deve partire dallo stato ufficiale corrente di `frontend-rebuild`.
Prima di implementare modifiche sul percorso canonico, l'esecutore deve verificarne l'allineamento. Se non è allineato, deve prima eseguire la presente procedura, purché ciò sia compatibile con le autorizzazioni e le protezioni vigenti.
Prevale LOCAL-FIRST: il lavoro runtime ordinario avviene nella working copy canonica `C:\KeepStoreWeb\KeepStore3.0` su un branch `task/<nome-task>` dedicato; worktree esterni o cloni alternativi solo con deroga esplicita del PO, senza un secondo esecutore.
Dopo il merge autorizzato, l'aggiornamento deve raggiungere anche `C:\KeepStoreWeb\KeepStore3.0`.
Non devono rimanere note operative che dichiarano genericamente «sincronizzazione da fare» dopo che l'allineamento è stato realmente completato e verificato.
Le note storiche devono essere conservate; le note di stato correnti devono essere aggiornate.

**Regola fondamentale:** un task applicativo è SOURCE INTEGRATED quando è integrato su GitHub. La sua CONSEGNA LOCALE è completata soltanto quando i file risultano aggiornati e verificati nel percorso canonico Windows. Le due operazioni devono essere tracciate separatamente, ma fanno parte del medesimo ciclo operativo del progetto.

#### FASE I — Limiti e autorizzazioni

Questa procedura non concede autorizzazioni ulteriori rispetto a quelle permanenti già documentate.
Restano vietati senza autorizzazione specifica:

- Modifiche a `main`.
- Force-push, reset distruttivi e rebase non autorizzati.
- Eliminazione dei file locali protetti.
- Modifiche generalizzate alle ACL.
- Accessi o scritture al database operativo.
- Interventi su IIS, Aruba e server pubblico.
- Deploy automatici.
- Pagamenti, invio email o ordini reali.
- Attivazione di funzionalità in STANDBY.
- Avvio del Task08.

La sincronizzazione del filesystem locale non costituisce autorizzazione alla pubblicazione in produzione.
Questa procedura è permanente e deve essere applicata in modo automatico dagli esecutori autorizzati, senza richiedere ripetutamente al Product Owner istruzioni già presenti nei manuali canonici.
