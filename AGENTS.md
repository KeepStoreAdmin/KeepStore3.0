# KeepStore 3.0 - regole operative permanenti

Fonte unica delle regole permanenti. Ingresso operativo: [START_HERE](docs/KEEPSTORE_START_HERE.md). Requisiti e priorita: [PRODUCT_ROADMAP](docs/KEEPSTORE_PRODUCT_ROADMAP.md). Evidenze/storico: [Masterplan](docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md). I Blueprint conservano i contratti tecnici, non una seconda governance.

## Decisione PO 2026-11-12 — Esecuzione autonoma Claude Code (PERMANENTE, PREVALENTE per i nuovi micro-task)

**Mandato.** Il PO (Master Prompt 2026-11-12) designa **Claude Code unico agente responsabile delle nuove esecuzioni** sulla working copy canonica `C:\KeepStoreWeb\KeepStore3.0\` e su GitHub. Per i micro-task ordinari approvati dalla [PRODUCT_ROADMAP](docs/KEEPSTORE_PRODUCT_ROADMAP.md) lo autorizza, senza conferme per singola PR, a: ricognizione mirata, implementazione, test locali/sintetici, branch `task/<nome-task>` dallo SHA reale della stable, commit, push ordinario, PR, verifica CI, **integrazione FF-only in `frontend-rebuild`**, sincronizzazione Windows Fasi A–I, aggiornamento dei documenti canonici e del checkpoint, e passaggio al micro-task successivo finche' la sessione e' attiva.

**Prevalenza e storico.** Per i soli micro-task avviati dopo questa decisione sostituisce il passaggio ChatGPT -> Claude -> Codex e il protocollo a doppia review preventiva con autorizzazione PO al merge del [Coordinamento](#coordinamento-chatgpt--claude--codex--decisione-po-2026-11-07-permanente) (punto 5). Quel testo resta come storico e vale ancora per PR gia aperte o precedenti e per lavoro assegnato a ChatGPT/Codex. Ogni altra regola di questo file (sicurezza, multitenant, manifest, Design Gate, segreti, protezione dati e asset) resta vincolante; la presente decisione non crea permessi tecnici che policy di Windows, GitHub, organizzazione o Claude Code non concedono.

**Gate del merge autonomo: tutti PASS, altrimenti STOP B.** (1) Manifest limitato al micro-task e base uguale allo SHA reale della stable. (2) Test pertinenti e **self-review** in fase distinta dall'implementazione, rileggendo il diff; un subagent interno e ammesso ma non e un reviewer esterno indipendente. (3) Required check `keepstore-source-gates` SUCCESS sullo **SHA head esatto** da integrare. (4) Preflight remoto immediatamente prima del merge: parent diretto uguale alla stable, HEAD candidato immutato, nessun branch concorrente. (5) Integrazione **solo fast-forward**, spingendo su `frontend-rebuild` lo stesso SHA gia verificato; mai squash, merge commit, rebase o force. (6) Dopo il push: PR MERGED/CLOSED, stable uguale al candidato, CI della stable SUCCESS. (7) Sincronizzazione Windows Fasi A–I con inventario 53/52/4 preservato e staging vuoto. Se GitHub non riconosce MERGED la PR dopo il push, fermarsi in B senza chiuderla artificialmente.

**Modelli.** Default Claude Sonnet 5.5, effort medium. Escalation a Claude Opus 5.5, effort high, per bug architetturali o sistemici, isolamento azienda/listino/variante, concorrenza, retry, idempotenza e checkout non ovvi, conflitti fra moduli, regressioni inspiegate, sicurezza o prima diagnosi non risolta; si torna a Sonnet a problema risolto. Valgono solo i modelli effettivamente disponibili: se un nome non e supportato si usa il piu vicino per ruolo e si annota la sostituzione. Non si usano API a consumo senza autorizzazione economica.

**Revisione ChatGPT del piano e catena operativa (aggiornamento PO 2026-11-12, versione con revisione ChatGPT e LAB DB, PREVALENTE).** Per ogni modifica significativa a sorgenti o pagine ASP.NET la catena e: ricognizione mirata -> micro-task -> proposta di piano -> revisione ChatGPT -> valutazione critica e decisione finale di Claude -> implementazione -> test -> self-review -> CI -> merge FF-only -> sincronizzazione A–I -> checkpoint -> task successivo. La proposta e scritta nell'area di scambio locale `.ai-review/proposta.md`, esclusa localmente con `.git/info/exclude`, mai versionata e non contata nell'inventario 53/52/4, e sottoposta a ChatGPT tramite la configurazione locale di Codex con login ChatGPT (`codex exec` non interattivo, sandbox read-only, nessuna API a consumo). La revisione e **consultiva**: Claude filtra i falsi positivi, decide in autonomia e riporta cosa ha accolto o scartato e perche; non e un gate di merge e non sostituisce test, self-review o CI. Non si simula e non si dichiara eseguita senza una risposta effettiva del canale: se il canale non e disponibile l'esito e **NON ESEGUITO**, mai PASS; per task CRITICAL (prezzi, promozioni, carrello, autenticazione, checkout, ordini, pagamenti, isolamento azienda/listino) senza una revisione effettiva si applica STOP B circoscritto a quel task e si prosegue su task indipendenti. Verso ChatGPT passano soltanto piano e diff del task: mai segreti, connection string, token, dati personali o contenuti dei depositi di credenziali. I task solo documentali e le correzioni meccaniche non richiedono la revisione. Canale verificato il 2026-11-12 con un ping senza contenuto di progetto: Codex CLI 0.167.0-alpha.4.1 (pacchetto `OpenAI.Codex`, non nel PATH: risolvere il percorso con `Get-AppxPackage OpenAI.Codex*`), login ChatGPT, risposta ricevuta. Questa catena integra il mandato precedente aggiungendo la revisione consultiva del piano prima dell'implementazione; self-review, gate del merge autonomo e storico restano invariati.

**LAB database locale (aggiornamento PO 2026-11-12, PREVALENTE).** Claude e autorizzato, senza conferme per singola operazione, a operare sul database LAB locale di sviluppo e test (MySQL 8 sulla macchina locale, documentato in [LOCAL_IIS_ENVIRONMENT](docs/KEEPSTORE_LOCAL_IIS_ENVIRONMENT.md) come istanza dedicata su `127.0.0.1:13317`) con script, query, DDL e DML di prova, validazioni di schema e verifiche di magazzino, varianti, listini e transazioni, negli stessi ambiti in cui Codex e gia abilitato. Condizioni: (1) prima di ogni scrittura verificare l'identita dell'istanza (marcatore o UUID, porta locale, data directory e nome del database lab) e che non sia il database online; (2) credenziali soltanto dal deposito locale previsto dallo [standard dei segreti](docs/KEEPSTORE_SECRET_PROTECTION_STANDARD.md) (Windows Credential Manager o DPAPI CurrentUser), mai in chiaro in commit, log, output, argv o report, e nessuna lettura di depositi di altri strumenti, per esempio la cartella utente di Codex; (3) il LAB certifica soltanto il LAB, non produzione, IIS reale o MySQL operativo; (4) backup o ripristino secondo la prassi LAB prima di mutazioni non reversibili; (5) il MySQL online resta sorgente read-only del runbook 2026-11-10. Produzione, server remoti, DB operativi reali, pagamenti LIVE, ordini reali e riavvii IIS/server restano fuori mandato. Stato verificato il 2026-11-12: nessun processo MySQL in esecuzione e nessun listener sulla porta documentata, quindi il LAB risulta non avviato; avvio, riprovisioning o recupero delle credenziali non sono stati eseguiti da questa registrazione e, quando serviranno, vanno condotti entro queste condizioni. Il repository pubblico collegato `KeepStoreAdmin/KeepStore_web` (SQL e documenti) e riconosciuto come riferimento: questa registrazione non lo modifica e non vi concede scritture.

**Limiti della sessione, checkpoint e ripresa.** L'autonomia e operativa e decisionale, non temporale: vale solo mentre una sessione Claude Code e realmente attiva con permessi e risorse disponibili. Nessun lavoro in background simulato, nessuna ripartenza autonoma senza orchestratore esterno autorizzato e verificato, nessun aggiramento di quote. Alla chiusura di ogni micro-task e prima di un'interruzione prevedibile si aggiorna il checkpoint gia previsto (START_HERE e Masterplan), separando operazioni completate da pianificate, senza segreti. Alla ripresa lo stato reale di filesystem, Git e GitHub prevale sul checkpoint: non si ripetono commit, push o PR gia conclusi e si completa il task in corso prima del successivo.

**STOP B / STOP E.** B circoscritto quando: la stable diverge, il manifest eccede il mandato, preflight o CI richiesta non sono verdi, il FF-only non e possibile, l'inventario locale e a rischio, policy o permessi impediscono l'azione, manca una decisione commerciale essenziale o un risultato non e verificabile; si prosegue solo su task indipendenti e sicuri. E quando c'e rischio concreto per dati, isolamento tenant, ordini, prezzi/IVA, sicurezza o file protetti: si ferma il componente, si proteggono prove e stato e non si procede sui task dipendenti. Mai `reset --hard`, `clean`, force push o rebase come scorciatoia.

**Invarianti e perimetro escluso.** `main` e `origin/main` restano congelati a `976e99f17cabc8a5c6a8715463444edfeaadcd91`; inventario 53/52/4 e delta ACL storico preservati; MULTITENANT-BY-DESIGN invariato; Coupon/Groupon STANDBY; SOMEC escluso. **Restano fuori da questo mandato e richiedono mandato distinto e specifico:** deploy produttivo, scritture o migrazioni su DB operativi di produzione o remoti (il solo LAB locale e coperto dal paragrafo dedicato), letture MySQL online fuori dal runbook read-only, riavvii IIS/server, pagamenti LIVE, ordini reali, creazione o revoca di credenziali, DNS/firewall/certificati, servizi esterni a pagamento. SOURCE INTEGRATED non equivale a produzione pubblicata. **CONSEGNA SERVER SOSPESA.**

**Report al PO.** Al termine di ogni ciclo, in italiano e sintetico: `[KEEPSTORE AUTONOMOUS RESULT] Task | esito | PR | stable SHA | funzionalita | test | CI | Windows sync | revisione ChatGPT | LAB | limiti | prossimo task`, dove la revisione ChatGPT e `eseguita` (con sintesi di accolto e scartato), `NON ESEGUITA` o `non richiesta`, e il LAB e `usato` (con esito) o `non usato`. Il checkpoint di uno STOP B o E riporta data, branch, SHA, stato PR, esito dei test LAB e prossimo passo sicuro.

## Decisione PO 2026-11-10 — MySQL online come sola fonte dati QA (PERMANENTE)

**Mandato permanente:** per verifiche che richiedono dati reali, Codex puo usare il MySQL online esclusivamente come sorgente read-only, senza perdere tempo a ricreare il LAB per semplici letture. Sono consentite solo SELECT mirate, parametrizzate, filtrate per tenant e limitate per righe e tempo, sotto TLS e transazioni READ ONLY. Non modificare query/viste memorizzate, tabelle, dati, configurazioni o privilegi; vietati DDL/DML, GRANT, stored procedure mutative, lock, dump generali, query pesanti, EXPLAIN ANALYZE, EXPLAIN o benchmark sulla produzione. Le prove di ordine/checkout, mutazioni, carico e IIS restano su ambienti isolati con autorizzazione distinta.

**Minimo privilegio e privacy:** usare un account DB dedicato con soli SELECT sugli oggetti strettamente necessari, mai root, account web scriventi o utenti amministrativi. Verificare identita del server, certificato TLS e scope dei privilegi prima della prima lettura. Non leggere PII clienti, documenti personali, pagamenti, password o segreti per il normale QA catalogo. I dati letti servono a confronti e fixture minimali anonimizzate, non a nuovi dump o copie persistenti della produzione. Se account, permessi o TLS non sono adeguati, STOP circoscritto: questa decisione non autorizza provisioning, GRANT o cambi firewall.

**Segreti per l'intera durata del progetto:** il PO non deve scrivere password in ChatGPT, Claude, memoria, prompt, Git o report. Una volta predisposta un'utenza read-only, il PO inserisce la password tramite prompt mascherato direttamente sul PC; Codex la custodisce con Windows Credential Manager o DPAPI CurrentUser, fuori dal repository/webroot, senza esposizione in output o argv. ChatGPT non puo conservare credenziali in memoria in modo permanente. Il deposito locale rimane disponibile fino a fine progetto, rotazione o revoca (nei limiti del profilo/PC), poi va cancellato e l'utenza DB revocata.

**Evidenza e sicurezza:** la lettura online non certifica prestazioni, IIS, ordini, sicurezza del runtime o prontezza al deploy. Nessuna modifica ad account/GRANT operativi, database o server e autorizzata implicitamente. Preferire questa strada per la sola esigenza di dati, senza ripetere recovery LAB non necessari. Vedere [procedura](docs/KEEPSTORE_MYSQL_ONLINE_READONLY_DATA_RUNBOOK.md) e [contratto segreti](docs/KEEPSTORE_SECRET_PROTECTION_STANDARD.md). CONSEGNA SERVER SOSPESA.

## Autorizzazione operativa PO permanente — 2026-11-07: NTFS, ACL e GitHub (PREVALENTE)

Il Product Owner autorizza **a tempo indeterminato, fino a revoca o modifica esplicita**, ChatGPT e Codex a svolgere le operazioni tecniche necessarie a ciascun micro-task **gia' approvato**, nelle cartelle del progetto da lui condivise/autorizzate e nei repository GitHub cui gli account/connector hanno effettivo accesso. Claude opera sui soli task specificamente assegnatigli dal PO, secondo le responsabilita e le eccezioni del Coordinamento sottostante; Codex resta l'esecutore Windows ordinario. Include lettura, scrittura, strumenti di sviluppo, branch task, commit/push, verifiche tecniche e gestione mirata dei permessi NTFS/ACL quando necessaria e tecnicamente consentita. **Non richiedere nuove conferme per i normali permessi di lavoro e non riaprire audit ACL/SID forensi generici a ogni task.** Il consenso non crea privilegi Windows, GitHub o accesso a cartelle non condivise; usare i permessi realmente disponibili, senza dichiarare accessi locali non effettuati.

**Eccezione ambientale ACL storica, permanente e strettamente tipizzata:** nella copia canonica `C:\KeepStoreWeb\KeepStore3.0\`, il forense ACL-FORENSIC-1A del 2026-11-07 ha confrontato la baseline REV1 originale (due copie identiche; impronta registrata nel rapporto locale) e rilevato su **51/53** elementi l'aggiunta di **tre ACE Allow ereditate**, `Modify, Synchronize`, mask `0x001301BF`, provenienti da due regole esplicite nel parent `C:\KeepStoreWeb` e una nella cartella del progetto. Nessuna ACE rimossa, DACL protection invariata; hash, owner, attributi e date **53/53** invariati; inventario storico **53 protetti / 52 untracked / quattro cancellazioni tracked**, staging vuoto. Causa temporale/autore non identificabili. I SID completi restano esclusivamente nel rapporto forense locale, **non committarli** in questo repository pubblico.

**Regola di preservazione efficiente:** considera queste sole tre ACE gia' inventariate un *delta ambientale autorizzato* nel confronto con la baseline REV1, senza cancellare, aggiornare o sostituire tale baseline. Usa i SID/ACE esatti del rapporto locale quando accessibile; non estendere la deroga ad ACE diverse, nuovi percorsi o permessi ulteriori. Conserva una comparazione pre/post **leggera** dello stato effettivo del task e i controlli di hash/owner/metadati, inventario 53/52/4, staging e ref Git. Una nuova variazione indotta dal task va corretta o circoscritta; un'anomalia significativa non documentata va segnalata **una sola volta con evidenza precisa**, senza avviare cicli ripetuti di audit né interrompere automaticamente lavoro isolato che non coinvolga la risorsa. Nessun ripristino indiscriminato tramite `icacls /reset`, `takeown` o modifica delle ACL dei parent.

**Limiti invariati:** la standing authorization non autorizza a toccare `main`, force/rebase/reset, bypass dei controlli commerciali, operazioni fuori task, modifiche globali alla sicurezza del computer, merge/deploy non autorizzati o interventi su server, LAB, IIS, MySQL operativo, Aruba, pagamenti, email. PR #419 MERGED/CLOSED il 2026-11-07, HEAD `a551d75a4d124ac9898633f09d44bf7b92a42909` (frase storica "DRAFT fino a review" superata); Task08 NON AVVIATO. Per modifiche necessarie ai file del task nessun audit generale ACL aggiuntivo; se il PC Windows non e' accessibile dagli strumenti di questa sessione, non simulare accesso o modifiche locali.

**Eccezione manifest esplicita PO:** `AGENTS.md` e' aggiunto al manifest cumulativo della PR #419 esclusivamente per registrare questa nuova decisione permanente; non consente altri ampliamenti di scope.

## Coordinamento ChatGPT – Claude – Codex — decisione PO 2026-11-07 (PERMANENTE)

> **Aggiornamento 2026-11-12:** per i micro-task avviati dopo la [Decisione PO 2026-11-12](#decisione-po-2026-11-12--esecuzione-autonoma-claude-code-permanente-prevalente-per-i-nuovi-micro-task) il flusso a cinque fasi e il doppio gate del punto 5 sono sostituiti dal ciclo autonomo Claude Code con i gate ivi elencati. Il testo seguente e conservato come storico e resta applicabile a PR gia aperte o precedenti e a lavoro assegnato ad altri assistenti.

Germano non e' un programmatore e trasferisce i messaggi fra gli assistenti. Ogni task segue cinque fasi, con etichetta in testa al messaggio:

1. **[PROPOSTA ChatGPT]** — ragionamento, gate A/B/C/D e bozza del prompt esecutivo. Germano la incolla a Claude.
2. **[REVISIONE Claude]** — verifica indipendente su Git/codice reali; restituisce il prompt migliorato e separa `ESEGUE CLAUDE` (attivita' cloud/read-only: analisi, elenco gap con file e riga, review di diff/PR, bozze di manuali e prompt) da `ESEGUE CODEX` (tutto cio' che richiede Windows: PowerShell, precompile 4.8, IIS/browser locali). Claude resta il revisore indipendente ordinario; l'esecuzione Windows tramite Claude Code e' ammessa solo come eccezione esplicitamente autorizzata dal PO (vedi punto 4). Germano la incolla a ChatGPT.
3. **[DECISIONE ChatGPT]** — accetta o contesta punto per punto con motivazione breve ed emette il prompt finale. E' consentito **al massimo un chiarimento tecnico** ChatGPT–Claude; poi ChatGPT assume la decisione tecnica, esplicitando l'eventuale disaccordo. Germano mantiene l'autorita sulle decisioni commerciali, priorita, perimetro, autorizzazioni, merge, deploy e deroghe. La decisione tecnica non amplia il mandato e non sostituisce il gate di review del punto 5.
4. **ESECUZIONE / [RISULTATO Codex]** — **un solo esecutore per working copy/branch**: vietati due esecutori simultanei. Codex e' l'esecutore Windows ordinario. Claude Code puo' eseguire attivita' sul PC Windows soltanto quando e' incaricato espressamente dal Product Owner e dispone di accesso effettivo al filesystem. E' consentito un solo esecutore attivo per working copy/branch. Le operazioni Git/GitHub del task (branch, commit, push, PR DRAFT) le svolge l'esecutore assegnato, normalmente Codex, oppure Claude quando il PO gli assegna esplicitamente un task cloud/docs (es. `DOCS-COORDINATION-CLAUDE-1A`).
5. **REVIEW / [REVIEW ChatGPT] / [REVIEW Claude]** — **prima di qualsiasi merge**, servono due review indipendenti, una ChatGPT e una Claude, entrambe senza blocker e registrate nella PR con attribuzione corretta e riferimento allo SHA candidato. Nuovi commit richiedono la riconferma delle review sul nuovo SHA; una review retrospettiva non soddisfa il gate preventivo. I revisori distinguono i propri controlli dai test riportati dall'esecutore, senza presentarli come rieseguiti. **Esito A solo senza blocker in entrambe le review**; una verifica SOURCE non equivale a certificazione IIS/MySQL/produzione. La decisione tecnica del punto 3 non sostituisce una review mancante o con blocker. Solo dopo questo doppio gate e l'autorizzazione esplicita del PO l'esecutore incaricato puo integrare esclusivamente FF-only; nessun merge autonomo. Questo e' il protocollo canonico: le altre sezioni vi rinviano senza definirne varianti.

Le autorizzazioni restano per singolo task; questo coordinamento non sblocca server, LAB, IIS, MySQL operativo, Aruba, deploy, pagamenti, e-mail o funzioni in STANDBY. `CLAUDE.md` nella radice contiene soltanto `@AGENTS.md`: questo file resta la fonte unica delle regole per tutti gli assistenti.

## KS-RIPRENDI — contratto di bootstrap

Quando Germano scrive `KS-RIPRENDI`, con accesso al repository:

1. Verificare GitHub, HEAD/stable/main, PR pertinenti, staging e working state disponibili; per l'ultima PR integrata e le PR aperte controllare SHA, stato CI, le due review previste dal Coordinamento (con relativa collocazione prima/dopo il merge) e stato della sincronizzazione Windows. La presenza delle review non prova l'allineamento locale: usare riscontri effettivi dell'esecutore o segnare DA VERIFICARE. Rispettare lo scope di sola lettura della ripartenza; dichiarare GitHub non accessibile quando manca, senza inventare stati remoti o risincronizzare automaticamente.
2. Leggere questo AGENTS, START_HERE e PRODUCT_ROADMAP; poi soltanto Blueprint/runbook pertinenti, usando il Masterplan per evidenze o conflitti puntuali.
3. Riconciliare checkpoint e Git reale; identificare ultimo task chiuso, task attivo, blocker, gate e stato deploy per tenant. Source integrated, Integration tested e production deployed sono stati distinti.
4. Presentare stato sintetico e prossimo ONE-SHOT proponibile, con prerequisiti e stato NON AVVIATO; non chiedere informazioni gia disponibili.
5. La parola chiave non autorizza implementazione, merge, deploy, scritture DB, gateway, e-mail o operazioni amministrative. Servono le rispettive autorizzazioni correnti.

## Metodo permanente ONE-SHOT e ripartenza informata

Obbligatorio in ogni nuova chat e sessione Codex: **prima di fare domande o formulare diagnosi**, seguire KS-RIPRENDI, consultare il checkpoint breve e la roadmap, i contratti pertinenti e, per IIS/test, il manuale IIS letto insieme ai checkpoint successivi indicati in START_HERE. Evitare di richiedere nuovamente screenshot, test e informazioni gia' documentati. Distinguere sempre dati attuali, evidenze storiche e il singolo dato essenziale ancora sconosciuto. L'errore di autorizzazione su `applicationHost.config` non prova che browser o IIS siano inutilizzabili.

- **Prompt completo al primo invio:** ChatGPT verifica anticipatamente implementazione, dipendenze, manifest, rischi, gate gia' superati e ostacoli prevedibili. Codex riceve un task completo risolutivo con casi positivi/negativi, test mirati e stop condition, senza catene di audit esplorativi evitabili.
- **Autonomia nel perimetro:** Codex risolve dettagli tecnici ordinari senza continue richieste, riusa harness e test gia' validi, e non ripete suite/benchmark per rituale. Zero ampliamenti impliciti di scope.
- **Review e decisione:** applicare il doppio gate preventivo della sezione Coordinamento, punto 5; la sola review ChatGPT non abilita il merge. Dopo i gate e le autorizzazioni PO, completare i passaggi gia' autorizzati (compreso FF-only e sincronizzazione) senza ulteriori conferme ridondanti. Se B, comunicare un blocker specifico e una sola azione minima risolutiva, non cicli identici.
- **Sicurezza non negoziabile:** merge, deploy, scritture DB, pagamenti, e-mail, test su dati operativi e deroghe smoke seguono le autorizzazioni esplicite correnti. Le deroghe non si estendono ad altre PR e prove sintetiche non diventano certificazione IIS.
- **Documentazione snella:** annotare fatti nuovi e decisioni nel documento canonico pertinente, senza nuove PR per ripetizioni. Separare PC sviluppo, IIS locale, tenant sul DB condiviso e server pubblicati.
- **Handoff nuove chat:** recuperare stato stabile, PR aperte, collaudi pendenti, topologia IIS, tenant e debiti aperti dai documenti/version control. Memoria e conversazione sono solo supporto e non prevalgono sui dati correnti.

## Gate anti-spreco e affidabilita del coordinamento — vincolo PO 2026-10-23

Questi quattro controlli integrano, senza sostituire, KS-RIPRENDI, ONE-SHOT, la gerarchia delle fonti, i gate di sicurezza e il processo LOCAL-FIRST/FF-only. **Sono obbligatori per ChatGPT in ogni nuova chat, prima di ogni prompt Codex o proposta di audit/test.** L'efficienza non giustifica omissioni di prove critiche.

1. **Bloccare lo spreco alla fonte.** Verificare prima le decisioni esplicite del Product Owner, le esclusioni e funzioni in STANDBY/DIFFERITE nella PRODUCT_ROADMAP e nei contratti pertinenti, gli eventuali aggiornamenti in START_HERE e le PR gia chiuse. Una funzione sospesa **non genera nuovi audit, test, bugfix, refactoring, modernizzazione o task**, neppure se emerge un difetto nel codice: conservare eventualmente il rilievo come storico, senza attivarlo. Solo una nuova autorizzazione PO puo revocare lo standby. **Coupon/Groupon: STANDBY; non toccare finche il PO non lo autorizza.**
2. **Ridurre il consumo Codex senza ridurre la qualita.** ChatGPT esegue direttamente le verifiche read-only possibili con gli strumenti disponibili (GitHub, cronologia PR, diff, file e contratti) **prima** di inviare un prompt. Codex riceve solo il lavoro effettivamente necessario sulla working copy Windows: task completo ONE-SHOT mirato, profilo/modello proporzionato, riuso di harness ed evidenze ancora pertinenti, soli test influenzati. Vietati audit esplorativi ripetuti, suite rituali e prompt successivi nati da una diagnosi non verificata. Una prova critica mancante resta un gate aperto/B: non viene saltata per risparmiare token.
3. **Distinguere lavoro utile da lavoro evitabile.** Prima di autorizzare il task qualificare il beneficio atteso per il cliente, la necessita tecnica/commerciale e l'eventuale duplicazione o rinviabilita. Separare `NECESSARIO / UTILE ORA` da `DIFFERITO / SUPERFLUO`; non spendere tempo o token su quest'ultimo. Se si rileva un errore di coordinamento, documentare sinteticamente causa, attivita realmente evitabile e misura preventiva nel Masterplan, senza riaprire il task o creare processi burocratici. Registrare costi, tempi e consumi solo quando misurati o forniti, mai inventarli.
4. **Gate pre-prompt verificabile (quattro esiti).** Prima di redigere un nuovo prompt, ChatGPT deve accertare: **(A)** mandato PO vigente e assenza di standby/divieti; **(B)** requisito/priorita della PRODUCT_ROADMAP e beneficio concreto; **(C)** prova tecnica nel Git/runtime della causa o del requisito residuo, distinguendo esplicitamente `DIFETTO RIPRODOTTO`, `EVIDENZA SORGENTE`, `IPOTESI` e `MIGLIORAMENTO`; **(D)** assenza di duplicati rispetto a codice integrato, PR chiuse e task gia eseguiti. Il risultato va riportato in forma brevissima nel mandato o nella decisione che precede il prompt, senza creare un audit separato. Se un controllo fallisce, **STOP: niente prompt Codex, test o PR** sulla funzione esclusa; chiedere decisione solo se davvero indispensabile, oppure avanzare sulla prossima priorita autorizzata.

Un finding fuori perimetro non e di per se un'autorizzazione; le eccezioni richiedono una decisione PO distinta. Questo gate non autorizza merge, deploy, accessi operativi a DB/IIS, email o pagamenti e non modifica la regola **CONSEGNA SERVER SOSPESA**.

### FEATURE-BATCH e Definition of Done

Decisione PO 2026-10-23, TASK COMPLETI: un task realizza un risultato cliente coerente, includendo quando utile 2-4 sottorequisiti collegati, una PR, un perimetro reversibile e una Definition of Done unica. Non frammentare dettagli ordinari in catene di prompt/audit. Non accorpare rischi indipendenti: gateway, integrita ordine, autenticazione e DB mantengono gate separati. Il manifest massimo resta esplicito; i finding fuori scope non vengono implementati implicitamente.

DoD runtime: risultato autorizzato implementato, causa affrontata, manifest/dipendenze verificati, casi positivi e failure pertinenti, regressioni influenzate, evidenze sintetiche/runtime distinte, branch pushato e PR DRAFT pronta per review indipendente. Gate critico indisponibile resta B; una deroga esplicita resta NON ESEGUITO, non PASS. Privilegiare qualita al primo ciclo e costo totale del risultato chiuso, senza sacrificare sicurezza/test per risparmiare token. Nessuna nuova review o suite rituale quando prove e runtime pertinenti sono immutati.

## Repository, branch e working copy

- Repository: `KeepStoreAdmin/KeepStore3.0`.
- Working copy canonica: `C:\KeepStoreWeb\KeepStore3.0\`.
- Branch stabile di sviluppo: `frontend-rebuild`.
- `main` e `origin/main` sono protetti: vietati modifiche, commit, push e PR.
- Aggiornamenti/integrazioni solo fast-forward. Vietati merge commit, rebase, reset e force push non autorizzati.
- Si lavora su branch dedicati `task/<nome-task>`, creati dal preciso SHA autorizzato di `frontend-rebuild`.
- Un solo task attivo; il successivo attende chiusura, stop o sostituzione esplicita di Germano.
- Ogni task mutativo inizia con `git fetch`, verifica ref/SHA e staging vuoto. Il tracked tree e pulito salvo modifiche preesistenti esplicitamente autorizzate: censirle con hash/inventario e preservarle fuori staging insieme agli untracked. Un audit read-only verifica i ref senza mutazioni non autorizzate.

### Windows PowerShell 5.1

ChatGPT e Codex possono utilizzare Windows PowerShell 5.1 per script, test, verifiche e operazioni locali comprese nei task autorizzati. Quando necessario e consentita ExecutionPolicy `RemoteSigned` limitata al processo. Non sono autorizzati implicitamente `Bypass`, elevazione, modifiche permanenti delle policy, operazioni su server/database/IIS o deploy. ChatGPT utilizza soltanto gli strumenti concretamente disponibili; l'autorizzazione non implica accesso diretto al PC Windows.

### Priorita ecommerce e moduli futuri

**Prima ecommerce funzionale, affidabile, moderno, bello e navigabile da smartphone, lungo tutto il percorso fino all'ordine/conferma/account; poi rifinimenti e performance non bloccanti, SEO avanzata, integrazioni e automazioni.** Sicurezza, pagamento, correttezza commerciale, SEO tecnica indispensabile e integrita ordine che impediscono un rilascio affidabile non sono polish differibile. La priorita dei requisiti vive soltanto nella PRODUCT_ROADMAP: non riavviare automaticamente task chiusi, differiti o semplicemente proposti. HOME adattiva e assistente acquisti restano requisiti approvati, non funzioni gia completate. Le nuove integrazioni restano progettazione non installata nel [Blueprint modulare](docs/KEEPSTORE_MODULAR_PLATFORM_BLUEPRINT.md), senza licenziare il Core o duplicare resolver Product/Offer.


### Modalita permanente LOCAL-FIRST + GITHUB SOURCE OF TRUTH

Questa modalita e obbligatoria per i task runtime KeepStore salvo deroga esplicita del Product Owner.

- Codex lavora **direttamente nella working copy canonica** `C:\KeepStoreWeb\KeepStore3.0\` durante investigazione, modifica e test. Non deve lavorare in una copia temporanea o clone alternativo lasciando la cartella canonica indietro rispetto al task.
- GitHub resta la **source of truth versionata** per branch, commit, diff, PR e merge. La working copy locale e la superficie operativa; GitHub e la superficie di controllo e storico.
- Prima di creare il branch task, Codex sincronizza `frontend-rebuild` nella working copy solo con fast-forward al preciso SHA autorizzato, preservando configurazioni locali e untracked autorizzati; una divergenza non risolvibile senza rebase/reset/force produce STOP B.
- Durante il task, i file finali modificati restano materialmente nella working copy canonica. Dopo PASS tecnico, commit e push, la working copy deve essere sul task branch e i file tracked del manifest devono corrispondere al commit pubblicato.
- Dopo PASS tecnico e PR DRAFT, Codex deve dichiarare esplicitamente `FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER` e fornire la lista **esatta** dei file manifest che Germano puo copiare sul server. Nessun file fuori manifest e implicitamente autorizzato al deploy/smoke.
- Lo smoke server del Product Owner, quando richiesto o utile, avviene **prima del merge stabile** usando solo i file indicati. Un upload manuale per smoke non equivale a deploy definitivo e non autorizza merge.
- Le review Git del branch/commit/diff pubblicato seguono esclusivamente il Coordinamento, punto 5. Il fatto che Codex abbia modificato la working copy locale non le sostituisce.
- Solo dopo il doppio gate preventivo del Coordinamento e l'autorizzazione esplicita di Germano, il merge resta esclusivamente fast-forward. Dopo il merge Codex riallinea la working copy canonica al nuovo `frontend-rebuild` stabile e verifica che i file runtime del task coincidano con lo stable, preservando lo stato locale autorizzato.
- Germano non deve eseguire operazioni Git: puo limitarsi a copiare sul server i file manifest dichiarati pronti e a fare verifiche umane/commerciali che non siano automatizzabili.
- ChatGPT, quando non dispone di accesso diretto al filesystem Windows locale, non dichiara di avere modificato o verificato `C:\...` direttamente: usa GitHub per la review indipendente e il report Codex per lo stato locale. Codex, eseguito sul PC, e responsabile della verifica reale della working copy canonica.
- Nei prompt runtime futuri questa modalita va considerata **default permanente** e non deve essere reintrodotta come eccezione della singola chat.

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


## Ruoli e autorita

- **Germano** decide priorita, perimetro e risultato commerciale e concede le autorizzazioni finali richieste. Non esegue operazioni Git/GitHub.
- **ChatGPT** coordina: definisce requisito, profilo, manifest, test e stop; controlla il diff, valuta report/finding, assegna A/B/E e autorizza l'avanzamento.
- **Codex** investiga e implementa l'autorizzato; esegue branch, test e smoke automatizzabili, commit, push, apertura/aggiornamento PR, merge autorizzato, sincronizzazione e verifiche finali. Non decide ampliamenti, manifest o merge. E' l'esecutore Windows ordinario.
- **Claude** (dal 2026-11-07) e' revisore indipendente ordinario di prompt e PR ed esegue attivita' cloud/read-only; svolge operazioni Git/GitHub solo nei task cloud/docs che il PO gli assegna esplicitamente; tramite Claude Code puo' essere esecutore Windows soltanto su incarico esplicito del PO e con accesso effettivo al filesystem. Un solo esecutore sulla stessa working copy/branch; nessuna autorizzazione implicita a merge, deploy, database o server. Non decide merge e non lavora mai sulla stessa working copy/branch di un altro esecutore. Coordinamento nella sezione dedicata sopra.

## Gerarchia delle fonti

In caso di conflitto si applica questo ordine:

1. richiesta corrente approvata da Germano;
2. Git, codice, database e runtime reale per lo stato tecnico;
3. questo `AGENTS.md` per le regole operative permanenti;
4. `docs/KEEPSTORE_START_HERE.md` per bootstrap e checkpoint breve; `docs/KEEPSTORE_PRODUCT_ROADMAP.md` per requisiti, priorita e criteri di prodotto;
5. `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md` per task/evidenze/storico, non come roadmap alternativa;
6. `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` per contratti architetturali; AI Assisted Search Blueprint per dettagli AI/search; runbook specialistici per i rispettivi domini;
7. benchmark datati e sezioni dichiarate storiche come riferimenti, non istruzioni operative attive; memoria/chat come supporto. Una decisione PO corrente acquisita nel repository prevale sullo snapshot antecedente.

SHA e Git reale prevalgono sui checkpoint. Nessuna richiesta autorizza implicitamente modifiche a `main`, segreti esposti o merge non approvati.

## Lettura documentale proporzionata

Git e codice reale vanno verificati prima dei prompt importanti. Leggere quanto serve a non perdere contratti pertinenti, senza riletture indiscriminate:

- nuova chat/audit generale: START_HERE e PRODUCT_ROADMAP, poi fonti necessarie; lettura integrale solo se richiesta dall'ampiezza;
- nuovo task: checkpoint breve, requisito della roadmap, sezioni pertinenti, contratti collegati e file runtime coinvolti;
- task UI: anche contratti ONSUS, mobile e componenti stabilizzati;
- carrello, login, prezzi, promo, checkout, ordine, DB o sicurezza: sezioni tecniche e di sicurezza pertinenti;
- search, AI, RAG, SEO AI o assistenza acquisto: anche AI Assisted Search Blueprint;
- task documentale trasversale o riconciliazione: inventario file/headings/riferimenti, lettura mirata e approfondimento integrale dei punti in conflitto, salvo mandato piu ampio. Non ricostruire a ogni prompt tutta la storia.

## Manifest, scope e discovery proattiva

- Ogni task dichiara obiettivo, base SHA, manifest esclusivo, divieti, verifiche e output. Vietato modificare file fuori manifest.
- Vietati scope creep, refactoring, cleanup, dipendenze o fix estranei "gia che ci siamo".
- Codex non e cieco: controlla superficie e dipendenze pertinenti; cerca bug, regressioni e rischi di sicurezza, performance o UX, inclusi aspetti prima ignoti a ChatGPT.
- Per ogni finding significativo riporta descrizione, evidenza, file/superficie, severita (`BLOCKER`, `HIGH`, `MEDIUM`, `LOW`), impatto, capacita di blocco e proposta `SAME-TASK CANDIDATE` o `SEPARATE TASK`.
- La discovery non autorizza fix. ChatGPT decide: `IGNORE / NON RILEVANTE`, `BACKLOG`, `TASK SUCCESSIVO`, `REV DEL TASK CORRENTE` o `ESTENSIONE AUTORIZZATA DEL TASK`.
- Finding indispensabile per correttezza, sicurezza o non regressione ma fuori manifest: fermarsi con B ed evidenza precisa.

Regola centrale: **CODEX CERCA, ANALIZZA, TESTA E PROPONE; CHATGPT DECIDE; CODEX IMPLEMENTA SOLTANTO DOPO AUTORIZZAZIONE.**

## Profili, modello e investigazione

Ogni prompt dichiara profilo, modello, reasoning e motivazione, scegliendo il profilo meno costoso compatibile con il rischio reale e un'elevata probabilita di esito A. I nomi sotto sono preferenze alla data del checkpoint, non garanzia di disponibilita: usare i modelli realmente disponibili e non riproporre selettori obsoleti. Rivalutare quando cambia l'offerta; niente rate card o cambio modello automatico.

- `ECONOMY`: GPT-6 Luna, Medium; documentazione semplice, Git/merge, modifiche meccaniche, verifiche circoscritte e operazioni a rischio minimo.
- `STANDARD`: GPT-6.1 Sol, Medium; sviluppo o bugfix circoscritto con causa nota, UI/UX non critica e implementazioni localizzate.
- `DEEP`: GPT-6.1 Sol, High; root cause incerta, piu componenti, DB, sicurezza, regressioni e investigazioni tecniche non banali.
- `CRITICAL`: GPT-6.1 Sol, Extra High/xhigh; modifiche effettive a prezzi, promozioni, carrello, autenticazione, dati, checkout, ordini, pagamenti o contratti trasversali ad alto rischio.
- `EXCEPTIONAL`: GPT-6 Astra, High, Extra High/xhigh o Max soltanto se giustificato; problemi eccezionalmente complessi e trasversali, architettura ad altissimo rischio o casi in cui GPT-6.1 Sol non e sufficiente, con scelta esplicita di ChatGPT.
- GPT-6 Sol non e il default: e il modello precedente/fallback rispetto a GPT-6.1 Sol. Usarlo solo se GPT-6.1 Sol non e disponibile oppure per confronto/compatibilita esplicitamente richiesti.

Il profilo deriva dalla modifica effettivamente richiesta, non dal solo dominio nominale: un merge FF-only di un task cart e `ECONOMY`; documentazione checkout e `ECONOMY`; un fix UI circoscritto e `STANDARD`; audit root cause DB/cart e `DEEP`; una modifica runtime owner/pricing/auth/checkout e `CRITICAL`. Citare carrello, autenticazione o ordini senza modificare il relativo runtime non assegna automaticamente `CRITICAL`.

Con causa dimostrata, `ECONOMY`/`STANDARD` possono implementare direttamente. `DEEP` con root cause incerta parte read-only. `CRITICAL` richiede preflight proporzionato al rischio prima delle modifiche, salvo fix gia dimostrato e autorizzato. Il preflight copre secondo pertinenza Git, manifest, chiamanti, schema/indici DB, dipendenze, build, fixture e test. Non separare investigazione e implementazione se cio duplica il lavoro senza ridurre il rischio. Un test fallito non comporta da solo l'escalation: distinguere prima errore ambiente, fixture, prerequisito disattivato e difetto reale del codice. Escalare modello o reasoning solo quando aumenta concretamente la probabilita di risolvere un problema tecnico complesso. Astra richiede escalation esplicita.

## Stack e divieti tecnici

Stack reale: ASP.NET WebForms, VB.NET, .NET Framework 4.x, MySQL, code-behind `.aspx.vb`/`.ascx.vb`, `Page.master`, controlli ASCX e `App_Code`.

- Non introdurre C#, ASP.NET Core, Razor/MVC, Blazor, minimal API, controller rewrite, EF Core, migrations, nuova dependency injection, pipeline TypeScript/npm/Vite/Webpack o librerie senza audit e approvazione.
- Non convertire WebForms o proporre rewrite non autorizzati. Tecnologia diversa indispensabile: B motivato.
- Il server resta fonte di verita per sessione, login, carrello, prezzi, listini, IVA, promo, checkout e ordine; niente logica commerciale affidata o duplicata nel browser.

## MULTITENANT-BY-DESIGN

KeepStore e un prodotto multi-cliente: lo stesso sorgente deve poter servire aziende, domini, database, identita visive e merceologie differenti cambiando esclusivamente configurazione, dati e asset autorizzati. Ogni task nuovo o modificato deve rispettare questo contratto permanente:

- sono supportati sia database separati per installazione sia piu vetrine/aziende nello stesso database e catalogo;
- sono supportate applicazioni IIS distinte, con physical path e configurazioni di deploy separate, che eseguono la stessa release e possono puntare allo stesso database; binding e connection string non sostituiscono comunque la selezione host-scoped della riga `aziende`;
- l'identita runtime non deriva mai dal solo database: segue `database configurato -> host normalizzato -> confronto esatto con url1/url2 -> una sola riga aziende`; `url1` e il canonico e `url2` l'eventuale alias;
- nessuna prima riga, `LIMIT 1` senza ID gia risolto, match parziale o cache del tenant indicizzata soltanto per database; host sconosciuti o compatibili con piu righe falliscono chiusi;
- la lista delle aziende puo essere memorizzata per database configurato, ma la selezione resta per-request e host-scoped; sessione, asset, canonical, seller, robots e sitemap devono provenire dalla stessa riga selezionata;

- zero nomi cliente, domini cliente, nomi database o tabelle qualificate per database nel codice condiviso;
- zero logica progettata esclusivamente per una singola azienda e nessuna supposizione sulla merceologia;
- configurazione, dati e asset tenant separati dal codice; un nuovo cliente deve essere installabile senza patch o ricompilazione del sorgente;
- Gateway e integrazioni specifiche cliente usano dati tenant/installazione: nessun valore cliente nel codice o nelle stored procedure e nessuna credenziale/valore commerciale gateway obbligatorio nel `web.config` condiviso, che resta infrastrutturale.
- host e alias validati server-side contro la sorgente autorevole; host sconosciuti o contaminazione cross-tenant falliscono chiusi;
- funzioni tenant-aware provate con almeno due tenant sintetici, verificando isolamento degli URL e assenza di dati incrociati;
- catalogo e numerazione documenti possono essere condivisi, mentre identita, account, carrello e regole di prezzo restano storefront-scoped; il listino anonimo deriva da `ListinoDefault`, `ListinoUser` vale solo come assegnazione iniziale in registrazione e poi prevale il listino dell'anagrafica utente;
- login e recupero di un account richiedono sempre l'`AziendaID` risolto per la richiesta; sono vietati fallback username-only tra aziende. La sessione autenticata conserva l'azienda verificata e viene invalidata quando cambia storefront o il marker non coincide;
- HOME, catalogo, PDP, recenti e Product JSON-LD consumano lo stesso listino/sessione e gli snapshot commerciali autorevoli. Le cache prezzo/promo includono almeno identita database sanitizzata, azienda, listino, stato autenticato e owner; gli stati tecnici non vengono memorizzati come assenza commerciale;
- il nucleo prodotto usa solo dati reali disponibili. Attributi mancanti o non applicabili sono omessi, mai simulati o inventati;
- migrazioni e stored procedure restano standard e riutilizzabili, senza `USE`, nomi database o riferimenti cliente nel corpo canonico;
- valori di deploy e segreti, inclusi connection string, password, token, chiavi, certificati privati, machine key, credenziali SMTP/gateway e dati personali, non entrano in sorgenti, commit, PR, manuali, log o output.

La compatibilita strutturale non autorizza un deployment. Database, domini e ambienti destinatari sono sempre indicati esplicitamente dal Product Owner; discovery o similarita non ampliano l'allowlist. Il collaudo di onboarding usa target espliciti, richieste non mutative e un manifest sanitizzato, e registra commit KeepStore, ambiente, dominio canonico, alias, identita, percorsi asset e risultati senza segreti.

### Carrello multi-storefront

- L'owner autenticato del carrello e la tupla `database + AziendaId + LoginId`; l'owner anonimo e `database + AziendaId + identita sessione anonima`.
- Il `SessionID` ASP.NET grezzo non e una chiave carrello sufficiente: la persistenza anonima usa un token opaco deterministico legato anche a database e azienda, entro il limite della colonna esistente.
- Letture, add singolo/multiplo/asincrono, fallback POST, quantita, remove, clear, MiniCart, header, revalidation e merge post-login devono risolvere l'owner esclusivamente dal contesto server-side autorevole. `AziendaId`, `LoginId`, listino o owner forniti dal client non sono attendibili.
- Un account e valido per il carrello solo quando `AuthenticatedAziendaID` coincide con l'azienda risolta per host; cambio storefront incompatibile, host ambiguo/sconosciuto o alias non canonicalizzato falliscono chiusi prima di una mutazione.
- Fingerprint e registri idempotenti del carrello includono sempre database, azienda e owner. Cache/snapshot commerciali includono inoltre listino e stato autenticato secondo il contratto storefront.
- Carrelli anonimi storici identificati soltanto dal `SessionID` grezzo non vengono reclamati automaticamente: non e possibile attribuirli in sicurezza a una delle aziende dello stesso database.
- Ogni POST finale di checkout termina in un solo esito osservabile: conferma PRG, redirect specializzato, errore di validazione accessibile sulla pagina, `403` CSRF, replay/collisione fail-closed oppure errore tecnico sanitizzato. Sono vietati catch silenziosi, refresh `200` senza messaggio e prosecuzione dopo un esito terminale; gli effetti esterni restano post-commit.
- `STOREFRONT-PERSISTENT-ANONYMOUS-CART-1A` e **CLOSED A / INTEGRATED**: runtime #297 (`6789fc1784bd695e3ec2bd0041d13b43154b08de`), cleanup #298 (`44016ffc2f29cae1cf235e46e6b115d8035ab6d6`) e privacy #299 (`a4238abfc8eae7fefbb985672d4cd5bddabf4118`) sono integrati. Il cookie tecnico `__Host-KeepStoreCart` contiene un token casuale opaco senza dati personali; e host-only, `Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`, senza `Domain`. La persistenza massima e 30 giorni dall'ultima mutazione effettiva; GET, letture e no-op non rinnovano la scadenza. L'owner persistente e isolato per database e `AziendaId`; il merge login e idempotente, con rotazione e consumo/invalidazione del token, rivalidazione server-side di prezzi/promo/stock e nessuna prenotazione inventario. Il cleanup server-side e disponibile, senza scheduler automatico. La produzione **NON e ancora certificata** finche non viene eseguito `docs/PERSISTENT_ANONYMOUS_CART_DEPLOYMENT_RUNBOOK.md` con tutti i gate PASS; privacy e cookie policy restano gate di rilascio. `CART-IDEMPOTENCY-PERSISTENCE-AUDIT-1A` resta debito separato **E / differito**, non risolto da questa integrazione. Dopo il closeout la roadmap e: `STOREFRONT-CART-CONVERSION-UX-1A`, poi `GOOGLE-MERCHANT-CENTER-FEED-1A`, poi `STOREFRONT-ABANDONED-CART-RECOVERY-1A` soltanto per utenti autenticati e dopo contratto privacy/consenso; tutti **NON AVVIATI**, senza autorizzazione implicita.

### Ordini, documenti ed e-mail multi-storefront

- La provenienza dell'ordine e il `documenti.AziendeId` persistito dalla procedura canonica nella stessa transazione del documento; la sessione non e una fonte storica sufficiente.
- La numerazione documenti resta globale nel database per contatore/tipo/anno: non va partizionata per azienda quando piu storefront condividono catalogo e inventario.
- Token checkout/conferma, fingerprint e replay durevole legano sempre fingerprint del database configurato, `AziendaId`, `LoginId`, tipo documento, opzioni commerciali e snapshot carrello. Un replay di un'altra azienda o con payload diverso fallisce chiuso.
- Lista, dettaglio e ricevuta documento richiedono congiuntamente owner utente e `AziendeId` del tenant autorevole; un solo `LoginId`/`UtentiId` non sostituisce il confine azienda.
- Branding, mittente, reply-to, destinatario amministrativo, SMTP e URL della conferma e-mail derivano dall'azienda persistita nel documento. Vietati ID azienda, nomi cliente, domini o destinatari hardcoded nel flusso condiviso.
- L'e-mail ordine parte soltanto dopo il commit e mai su replay, rollback, stock insufficiente o collisione. Un errore SMTP post-commit viene registrato in forma sanitizzata e non annulla o duplica il documento.
- I test del flusso usano tenant/account sintetici e fake e-mail sink; nessun SMTP, ordine, pagamento o gateway reale senza autorizzazione esplicita.

## Baseline minima di verifica

Ogni task verifica: diff/manifest; `git diff --check`; sintassi/logica; dipendenze dirette; percorso positivo; un failure pertinente; regressioni influenzate; secret scan; branch, staging e working tree.

- Runtime: build/precompile e test tecnici pertinenti.
- Codex esegue per default tutti gli smoke tecnici e browser automatizzabili. Germano interviene solo per conferme umane visive, commerciali o funzionali non automatizzabili o dipendenti da sue fixture/dispositivi, con pochi passaggi semplici definiti da ChatGPT.
- Docs-only: niente build, precompile o smoke runtime se il runtime non cambia; verificare invece coerenza, riferimenti, definizioni, manifest e diff.
- Dichiarare test non eseguibili o senza fixture; mai inventare esiti. Profondita proporzionata al rischio.

## Mobile-first e ONSUS

- Il mobile e l'esperienza primaria. Progettazione e QA progrediscono da `360px`, `390px`, `430px`, poi tablet e desktop; indicare dispositivi/browser effettivamente verificati. Pochi viewport non certificano ogni dispositivo.
- Nessuna funzione essenziale hover-only. Verificare touch target, ordine, leggibilita, densita, offcanvas e scrolling.
- Nessun A visuale senza browser mobile reale; coinvolgere Germano solo quando la conferma necessaria non e automatizzabile.
- KeepStore e fonte di dati/logica/permessi; ONSUS e fonte UI/UX. Un refactor grafico non autorizza fix nascosti alla business logic. **TEMPLATE-REFERENCE / RUNTIME-INDEPENDENCE:** il template originale e una fonte esterna di benchmark/reference UI/UX, non una dipendenza runtime. Il runtime custom KeepStore non usa il nome del template in identificatori, classi, funzioni, variabili, selettori, version string/cache-buster, commenti operativi, DOM marker, log o path/file custom e non importa dati, prodotti, categorie, prezzi, immagini o business logic demo. Ogni pattern adottato viene adattato alla semantica KeepStore; le menzioni restano ammesse in manuali, audit, storico e documentazione/reference. Gli asset runtime di ogni tema rispettano una struttura tipizzata sotto ThemeManager.AssetsBaseUrl: CSS in css/, JavaScript in js/, immagini, font e icone nelle rispettive directory. Non sono ammessi duplicati runtime o fogli CSS/JS custom sciolti nella root del tema quando esiste la directory canonica. Temi alternativi mantengono la stessa struttura in /Public/assets/{ThemeName}/; configurazione e asset tenant restano separati dal codice condiviso.

### Storefront UX Design Gate — obbligatorio

Per ogni task UI/UX che tocchi HOME, header, menu, navigazione, catalogo, PDP, product card, ricerca visuale, filtri, carrello/MiniCart/offcanvas, checkout UI, MyAccount UI, modali, componenti interattivi, responsive, layout, CTA o accessibilita storefront, seguire **prima di progettare o modificare la UI** questa sequenza, con profondita proporzionata: **ONSUS originale -> benchmark ecommerce contemporaneo -> architettura KeepStore reale -> implementazione mobile-first**.

1. **ONSUS originale.** Esaminare il package/template originale pertinente, quando accessibile, invece di basarsi su screenshot o memoria. Identificare markup, gerarchia visuale, comportamento e motivazione dell'interazione, responsive, offcanvas/collapse/modal, CTA, spacing e mobile behavior. Se il package non e accessibile, dichiararlo e usare gli asset/template originali gia versionati, se disponibili; non inventare il comportamento. ONSUS guida UI/UX, non dati commerciali, tassonomia, Product/Offer, prezzi, promozioni, claim, contenuti demo o business logic.
2. **Benchmark ecommerce contemporaneo.** Effettuare ricerca web aggiornata al momento del task, scegliendo grandi ecommerce, retailer verticali, marketplace comparabili e fonti UX/accessibilita autorevoli in funzione del pattern, non del prestigio o di una lista fissa di brand. Valutare friction point, navigazione, discoverability, progressive disclosure, touch, feedback di stato, densita, accessibilita e conversione. Non copiare branding, grafica o testi proprietari, business logic, feature estranee o pattern incompatibili; negli anni successivi non congelare le scelte alle pratiche del 2026.
3. **Architettura KeepStore reale.** Verificare il runtime WebForms/VB.NET, i componenti autorevoli gia consolidati, multi-tenant e multi-merceologia, CatalogMenuProvider/tassonomia reale, contratti Product/Offer e URL/SEO, resolver commerciali, sessione/carrello/account, progressive enhancement, performance, accessibilita e non regressione. Non duplicare un componente esistente ne adottare un pattern moderno che comprometta autorita server-side, business logic o compatibilita.
4. **Implementazione mobile-first.** Seguire la progressione viewport del contratto Mobile-first sopra. Secondo pertinenza controllare target touch, apertura/chiusura/riapertura, scroll e overflow, focus/tastiera/ARIA, feedback di stato, testi/immagini/CTA, densita, progressive disclosure e orientamento. Il desktop non compensa un mobile mediocre; restano vietate funzioni essenziali hover-only.

Nessuna delle tre fonti iniziali prevale automaticamente: scegliere la soluzione KeepStore piu semplice, chiara, veloce, accessibile, mobile-usable, coerente e manutenibile, utile alla conversione e compatibile con multi-tenant/multi-merceologia, senza regressioni. I futuri prompt UI/UX significativi devono citare questo gate o dichiararne l'applicazione; per scelte rilevanti riportare una matrice sintetica `Aspetto | ONSUS originale | Benchmark attuale | KeepStore corrente | Decisione KeepStore`. La profondita e proporzionata: piccoli fix puramente meccanici non richiedono una ricerca estesa, ma una decisione UX/design/navigation non puo saltare il gate. Se ONSUS pertinente e disponibile ma non esaminato, non dichiarare completo il design audit; se manca la ricerca corrente per una scelta UX contemporanea, non dichiararla best practice attuale e segnalare il limite.

### EXPERIENCE-FIRST + PERFORMANCE-FIRST

Standard permanente per le evoluzioni ecommerce, complementare al Design Gate, a MULTITENANT-BY-DESIGN e al metodo ONE-SHOT/FEATURE-BATCH. Questa e la fonte normativa unica; il Blueprint documenta applicazioni tecniche e metriche, non una seconda policy.

- **Esperienza.** Nei task con impatto UX identificare bisogno del cliente, percorso attuale, passaggi/attriti e componenti gia riutilizzabili. Preferire meno ambiguita, attese ed errori, feedback chiari e interazioni mobili accessibili; ogni nuova funzione deve migliorare almeno un aspetto concreto di esperienza o efficienza senza peggiorare gli altri.
- **Prestazioni.** Nei task che incidono ragionevolmente sul costo operativo scegliere almeno una metrica pertinente e un budget proporzionato: TTFB, LCP/INP/CLS, query MySQL/tempi SQL/N+1, richieste duplicate, payload/DOM, JS/CSS, immagini, serializzazione, caching o lavoro server-side. Raccogliere baseline e confronto prima/dopo omogenei quando misurabili; dichiarare misura reale, stima, non applicabilita o limite, mai inventare un miglioramento.
- **Proporzione.** Nessun benchmark generale o target numerico arbitrario per piccoli fix. Una misura non pertinente va motivata, non eseguita per rituale; una verifica critica indisponibile resta B, non PASS. Riusare audit/fonti ancora validi e aggiornare solo quelli necessari alla decisione corrente.
- **Design.** Il gate ONSUS originale -> benchmark ecommerce pertinente -> architettura KeepStore -> mobile-first resta vincolante, non viene riscritto. Usare il [benchmark navigazione registrato](docs/KEEPSTORE_NAVIGATION_UX_BENCHMARK.md) come riferimento datato con limiti espliciti, non come roadmap attuale o prova visuale universale. Le scelte dei concorrenti non autorizzano copie automatiche o dati demo.
- **Multi-merceologia.** Dati/capacita e configurazione tenant-scoped decidono attributi e funzioni pertinenti, senza hardcode di settori o cliente. Le nuove funzioni condivise trasversali richiedono almeno due tenant/cataloghi sintetici di settori differenti, verificando funzioni irrilevanti, dati assenti e isolamento commerciale; non autorizzano DB fixture o attivazioni reali.
- **Innovazione utile.** Segnalare proposte pertinenti con beneficio cliente/conversione/velocita, fattibilita nello stack, costo/complessita, rischi e priorita. Niente widget o animazioni decorative che peggiorano usabilita/prestazioni. Codex propone; ChatGPT decide scope/roadmap; nessuna implementazione extra implicita.
- **Non regressione.** Una ottimizzazione non sacrifica sicurezza, regole commerciali, accessibilita, SEO, isolamento tenant o funzioni stabilizzate. Cache e dati restano coerenti con tenant, listino, account e autorita server-side; non si rende veloce un dato commerciale obsoleto o non verificato.
- **Consegna.** Per task UX/performance significativi riportare problema, fonti pertinenti, soluzione/motivo, beneficio atteso, metriche prima/dopo o limiti, verifiche mobile/desktop, rischi/regressioni e compatibilita multi-tenant/multi-merceologia. Beneficio atteso non equivale a risultato misurato, conversione certificata o ecommerce completo.

## Standard permanente dei segreti

Prima di modificare un campo password/token, un form credenziali, una connessione o un consumer esterno, **classificare la finalita del dato e consultare obbligatoriamente lo [standard canonico](docs/KEEPSTORE_SECRET_PROTECTION_STANDARD.md) e la sua mappa progressiva**. La regola si applica automaticamente, senza promemoria del PO. Segreti riutilizzabili: destinazione comune KSAES2 autenticata; password di login: hashing dedicato, non cifratura reversibile. DPAPI e-mail e RSA Tools restano CURRENT, non KSAES2 gia implementato o distribuito.
Nessuna nuova persistenza in chiaro, funzione crittografica isolata o fallback da formato autenticato invalido. Aggiornare solo le superfici del manifest; riusare finding/mappa esistenti senza scansioni generali, conversioni massive, bonifiche/avvisi ripetuti sulle esposizioni pregresse o blocchi delle funzionalita indipendenti. Dettagli KSAES2 non attestati vanno formalizzati prima dell'implementazione. Nessuna modifica automatica a configurazioni, chiavi, credenziali o aree fuori scope; i gate operativi esistenti restano validi.

## Protezione dati, segreti e asset

- Non esporre password, token, secret, connection string, session id, dati personali, carte o transazioni. Sanitizzare output/log.
- Nessuna scrittura DB, modifica schema/SP/dump, chiamata gateway, pagamento, ordine reale o invio esterno senza task e autorizzazione. Preferire query read-only con rollback.
- Per input, form, redirect, upload e DB verificare validazione server, query parametrizzate, whitelist, encoding, CSRF/ViewState, traversal e log sensibili.
- Lasciare fuori staging gli untracked in `Public/assets/images/articoli/`, `marche/`, `settori/`, `vettori/`. Non pulire/spostare directory; asset solo se nominativamente autorizzato.

## Commit, push, review, smoke e merge

### CI dei gate sorgente

`CI-FOUNDATION-1A` definisce il job univoco `keepstore-source-gates`: Git/diff, secret guard incrementale, carrello isolato e precompile safe 4.8 su Windows/PowerShell 5.1, senza configurazioni operative, credenziali o deploy. Il file YAML da solo non prova CI funzionante: verificare run, job, risultato e SHA effettivi su GitHub. Per il FF deve esistere un risultato verde sullo **SHA head integrabile**, prodotto dal push task; il solo check sul merge sintetico PR non basta. Nessun gate obbligatorio puo essere saltato o trasformato in successo dopo un errore.

L'attivazione del required check su `frontend-rebuild` segue il primo verde verificato: solo questo contesto, sorgente GitHub Actions, senza obbligo PR/merge queue o aggiornamenti tramite merge commit; mantenere compatibile il push FF diretto. Non rimuovere protezioni preesistenti. Stato effettivo della regola e dei run dal GitHub corrente/closeout; assenza o errore resta B salvo deroga PO esplicita e specifica. La deroga CI della #382 vale soltanto per #382. Review indipendente e autorizzazione PO al merge rimangono obbligatorie; CI verde non le sostituisce e non certifica IIS/MySQL/produzione.

### Consegna release e handoff gestionale

Per ogni task runtime fornire il manifest esatto `added/modified/deleted/renamed` (origine/destinazione per rename), dipendenze `App_Code`/Bin e asset/cache-buster pertinenti, commit sorgente, destinazioni esplicitamente autorizzate, prerequisiti configurazione, backup, rollback e test con relativi limiti. I file aggiunti sono obbligatori quanto i modificati: evitare pacchetti parziali. Nessuna destinazione di produzione si deduce da un tenant compatibile. PR integrata non significa file pubblicati: registrare separatamente source integrated, Integration tested e production deployed/verified per tenant. Docs-only: nessun file da pubblicare sul server.

Se il risultato richiede contratti/dati/interventi del gestionale, consegnare schermata funzionale proposta e manuale operativo per Enzo/Vincenzo secondo responsabilita effettive (interfaccia gestionale, schema/provisioning e gestione dati da confermare nel singolo handoff). Specifica pronta non significa pannello implementato o DB aggiornato; nessuna modifica DB automatica e nessuna sostituzione dei rispettivi manuali specialistici.

- Se emerge un blocker fuori scope, chiudere con B senza committare modifiche incomplete.
- A ogni chiusura con esito A, il rapporto conclusivo deve indicare automaticamente il prossimo task consigliato, ricavato dal manuale e dai finding aperti. Deve riportare nome, motivo, prerequisiti e stato NON AVVIATO. Nessun task successivo deve essere avviato o implementato senza autorizzazione del Product Owner.
- Se implementazione e test sono completi, Codex crea un solo commit, pusha il solo task branch e apre o aggiorna la PR verso `frontend-rebuild`, salvo stop condition esplicita.
- PR e merge sono momenti separati: il push non autorizza merge/deploy; ChatGPT assegna A solo dopo la review indipendente del diff pubblicato.
- Codex esegue il merge solo dopo il doppio gate preventivo del Coordinamento, punto 5, e l'autorizzazione esplicita di Germano, esclusivamente fast-forward. Non decide il merge.
- Nessun push, PR o merge verso `main`. Dopo il merge Codex sincronizza locale/remoto e verifica parent, assenza di merge commit, `frontend-rebuild == origin/frontend-rebuild`, `main == origin/main`, staging, tracked tree e asset protetti.
- Se strumenti, autenticazione o permessi bloccano un'operazione tecnica, Codex si ferma con B e prova precisa: non aggira protezioni, recupera credenziali o trasferisce automaticamente l'operazione a Germano.

## Esiti A/B/E

- `A`: requisito autorizzato completato, verificato e chiudibile; nessun blocker noto nel perimetro.
- `B`: direzione valida ma task incompleto, bloccato o in attesa di fix, autorizzazione, verifica tecnica o smoke.
- `E`: premessa, strategia o modifica errata/pericolosa; regressione grave introdotta o approccio da abbandonare e riprogettare.

Un blocker tecnico scoperto correttamente prima di una modifica pericolosa e normalmente B, non E. Un task UI in attesa dello smoke obbligatorio resta B. Un task A non dichiara automaticamente completa la pagina o l'area.

## Stop conditions

Codex si ferma con B senza ampliare il manifest quando diverge la base; tracked tree o staging non sono puliti; servono file, DB, librerie, tecnologia, strumenti, autenticazione, permessi o obiettivi fuori scope; manca una decisione; una verifica critica non e eseguibile; un contratto chiuso verrebbe violato; emerge un blocker non autorizzato; oppure correttezza, sicurezza o non regressione non sono garantibili.

Regola di esecuzione: **CHATGPT CONTROLLA E AUTORIZZA L'AVANZAMENTO; GERMANO APPROVA LE DECISIONI FINALI; CODEX ESEGUE TUTTE LE OPERAZIONI TECNICHE AUTORIZZATE.**
