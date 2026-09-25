# KeepStore 3.0 - regole operative permanenti

Fonte canonica del metodo. I manuali in `docs/` conservano checkpoint, architettura, contratti e roadmap.

## Repository, branch e working copy

- Repository: `KeepStoreAdmin/KeepStore3.0`.
- Working copy canonica: `C:\KeepStoreWeb\KeepStore3.0\`.
- Branch stabile di sviluppo: `frontend-rebuild`.
- `main` e `origin/main` sono protetti: vietati modifiche, commit, push e PR.
- Aggiornamenti/integrazioni solo fast-forward. Vietati merge commit, rebase, reset e force push non autorizzati.
- Si lavora su branch dedicati `task/<nome-task>`, creati dal preciso SHA autorizzato di `frontend-rebuild`.
- Un solo task attivo; il successivo attende chiusura, stop o sostituzione esplicita di Germano.
- Ogni task inizia con `git fetch`, verifica ref/SHA, staging vuoto e tracked tree pulito. Censire e preservare gli untracked autorizzati.

### Priorita ecommerce e moduli futuri

Prima si stabilizzano HOME, catalogo/PDP, funzioni commerciali residue e MyAccount. Le nuove integrazioni Google, social, marketplace, licenze, IndexNow autonomo e AI sono progettate/documentate ma rinviate: una nuova chat non le riavvia automaticamente. KeepStore resta un'applicazione modulare sullo stack attuale; Core commerciale e SEO tecnica di base non dipendono da licenze. Ogni provider conserva configurazione, schermata e dati operativi nel proprio dominio, senza duplicare i resolver Product/Offer o usare un token come prova di diritto d'uso. Il blueprint modulare vigente e `docs/KEEPSTORE_MODULAR_PLATFORM_BLUEPRINT.md`; nessuno schema draft e installato da questa decisione.


### Modalita permanente LOCAL-FIRST + GITHUB SOURCE OF TRUTH

Questa modalita e obbligatoria per i task runtime KeepStore salvo deroga esplicita del Product Owner.

- Codex lavora **direttamente nella working copy canonica** `C:\KeepStoreWeb\KeepStore3.0\` durante investigazione, modifica e test. Non deve lavorare in una copia temporanea o clone alternativo lasciando la cartella canonica indietro rispetto al task.
- GitHub resta la **source of truth versionata** per branch, commit, diff, PR e merge. La working copy locale e la superficie operativa; GitHub e la superficie di controllo e storico.
- Prima di creare il branch task, Codex sincronizza `frontend-rebuild` nella working copy solo con fast-forward al preciso SHA autorizzato, preservando configurazioni locali e untracked autorizzati; una divergenza non risolvibile senza rebase/reset/force produce STOP B.
- Durante il task, i file finali modificati restano materialmente nella working copy canonica. Dopo PASS tecnico, commit e push, la working copy deve essere sul task branch e i file tracked del manifest devono corrispondere al commit pubblicato.
- Dopo PASS tecnico e PR DRAFT, Codex deve dichiarare esplicitamente `FILE PRONTI PER SMOKE SERVER DEL PRODUCT OWNER` e fornire la lista **esatta** dei file manifest che Germano puo copiare sul server. Nessun file fuori manifest e implicitamente autorizzato al deploy/smoke.
- Lo smoke server del Product Owner, quando richiesto o utile, avviene **prima del merge stabile** usando solo i file indicati. Un upload manuale per smoke non equivale a deploy definitivo e non autorizza merge.
- ChatGPT effettua la review indipendente del branch/commit/diff pubblicato su GitHub e assegna A/B/E. Il fatto che Codex abbia modificato la working copy locale non sostituisce la review Git.
- Dopo A di ChatGPT e autorizzazione esplicita di Germano, il merge resta esclusivamente fast-forward. Dopo il merge Codex riallinea la working copy canonica al nuovo `frontend-rebuild` stabile e verifica che i file runtime del task coincidano con lo stable, preservando lo stato locale autorizzato.
- Germano non deve eseguire operazioni Git: puo limitarsi a copiare sul server i file manifest dichiarati pronti e a fare verifiche umane/commerciali che non siano automatizzabili.
- ChatGPT, quando non dispone di accesso diretto al filesystem Windows locale, non dichiara di avere modificato o verificato `C:\...` direttamente: usa GitHub per la review indipendente e il report Codex per lo stato locale. Codex, eseguito sul PC, e responsabile della verifica reale della working copy canonica.
- Nei prompt runtime futuri questa modalita va considerata **default permanente** e non deve essere reintrodotta come eccezione della singola chat.


## Ruoli e autorita

- **Germano** decide priorita, perimetro e risultato commerciale e concede le autorizzazioni finali richieste. Non esegue operazioni Git/GitHub.
- **ChatGPT** coordina: definisce requisito, profilo, manifest, test e stop; controlla il diff, valuta report/finding, assegna A/B/E e autorizza l'avanzamento.
- **Codex** investiga e implementa l'autorizzato; esegue branch, test e smoke automatizzabili, commit, push, apertura/aggiornamento PR, merge autorizzato, sincronizzazione e verifiche finali. Non decide ampliamenti, manifest o merge.

## Gerarchia delle fonti

In caso di conflitto si applica questo ordine:

1. richiesta corrente approvata da Germano;
2. Git, codice, database e runtime reale per lo stato tecnico;
3. questo `AGENTS.md` per le regole operative permanenti;
4. checkpoint corrente di `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`;
5. `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` per architettura, flussi e contratti;
6. `docs/KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md` soltanto per search, AI, RAG, SEO AI o assistenza acquisto;
7. handoff, memoria, chat e allegati come supporto non autoritativo.

SHA e Git reale prevalgono sui checkpoint. Nessuna richiesta autorizza implicitamente modifiche a `main`, segreti esposti o merge non approvati.

## Lettura documentale proporzionata

Git e codice reale vanno verificati prima dei prompt importanti. Leggere quanto serve a non perdere contratti pertinenti, senza riletture indiscriminate:

- nuova chat/audit generale: checkpoint Masterplan e fonti necessarie; lettura integrale solo se richiesta dall'ampiezza;
- nuovo task: checkpoint, sezioni pertinenti, contratti collegati e file runtime coinvolti;
- task UI: anche contratti ONSUS, mobile e componenti stabilizzati;
- carrello, login, prezzi, promo, checkout, ordine, DB o sicurezza: sezioni tecniche e di sicurezza pertinenti;
- search, AI, RAG, SEO AI o assistenza acquisto: anche AI Assisted Search Blueprint;
- task documentale trasversale o riconciliazione: lettura completa delle fonti coinvolte.

## Manifest, scope e discovery proattiva

- Ogni task dichiara obiettivo, base SHA, manifest esclusivo, divieti, verifiche e output. Vietato modificare file fuori manifest.
- Vietati scope creep, refactoring, cleanup, dipendenze o fix estranei "gia che ci siamo".
- Codex non e cieco: controlla superficie e dipendenze pertinenti; cerca bug, regressioni e rischi di sicurezza, performance o UX, inclusi aspetti prima ignoti a ChatGPT.
- Per ogni finding significativo riporta descrizione, evidenza, file/superficie, severita (`BLOCKER`, `HIGH`, `MEDIUM`, `LOW`), impatto, capacita di blocco e proposta `SAME-TASK CANDIDATE` o `SEPARATE MICRO-TASK`.
- La discovery non autorizza fix. ChatGPT decide: `IGNORE / NON RILEVANTE`, `BACKLOG`, `MICRO-TASK SUCCESSIVO`, `REV DEL TASK CORRENTE` o `ESTENSIONE AUTORIZZATA DEL TASK`.
- Finding indispensabile per correttezza, sicurezza o non regressione ma fuori manifest: fermarsi con B ed evidenza precisa.

Regola centrale: **CODEX CERCA, ANALIZZA, TESTA E PROPONE; CHATGPT DECIDE; CODEX IMPLEMENTA SOLTANTO DOPO AUTORIZZAZIONE.**

## Profili, modello e investigazione

Ogni prompt dichiara profilo, modello, reasoning e motivazione. Rivalutare la policy se cambiano i modelli; niente rate card.

- `ECONOMY`: GPT-5.6 Luna, Medium; docs semplici o modifica meccanica a rischio minimo.
- `STANDARD`: GPT-5.6 Terra, Medium; sviluppo o bugfix circoscritto.
- `DEEP`: GPT-5.6 Sol, High; causa incerta, piu componenti, DB, sicurezza o regressioni.
- `CRITICAL`: GPT-5.6 Sol, Extra High; prezzi, promo, carrello, auth, dati, checkout, ordine, pagamento o cambi trasversali.
- GPT-6 Astra: solo casi eccezionali trasversali scelti da ChatGPT. Max e Ultra non sono default; Ultra non si usa ordinariamente.

Con causa dimostrata, `ECONOMY`/`STANDARD` possono implementare direttamente. `DEEP` con root cause incerta parte read-only. `CRITICAL` richiede preflight prima delle modifiche, salvo fix gia dimostrato e autorizzato. Il preflight copre secondo pertinenza Git, manifest, chiamanti, schema/indici DB, dipendenze, build, fixture e test. Non separare investigazione e implementazione se cio duplica il lavoro senza ridurre il rischio.

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
- `STOREFRONT-PERSISTENT-ANONYMOUS-CART-1A` e un task futuro, non una capacita gia attiva: dovra usare 30 giorni dall'ultima attivita, token casuale opaco senza dati personali, cookie host-only `Secure`, `HttpOnly`, `SameSite=Lax`, righe DB isolate per database e `AziendaId`, merge login una sola volta con rotazione e invalidazione del token, rivalidazione di prezzi/promo/stock, nessuna prenotazione inventario e cleanup server-side. Privacy e cookie policy sono gate di rilascio. Questa roadmap e distinta dall'idempotenza delle mutazioni carrello e non ne modifica lo stato corrente.

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

- Il mobile e l'esperienza primaria. Progettazione e QA iniziano da `360px` e `390px`, poi tablet e desktop.
- Nessuna funzione essenziale hover-only. Verificare touch target, ordine, leggibilita, densita, offcanvas e scrolling.
- Nessun A visuale senza browser mobile reale; coinvolgere Germano solo quando la conferma necessaria non e automatizzabile.
- KeepStore e fonte di dati/logica/permessi; ONSUS e fonte UI/UX. Un refactor grafico non autorizza fix nascosti alla business logic.

## Protezione dati, segreti e asset

- Non esporre password, token, secret, connection string, session id, dati personali, carte o transazioni. Sanitizzare output/log.
- Nessuna scrittura DB, modifica schema/SP/dump, chiamata gateway, pagamento, ordine reale o invio esterno senza task e autorizzazione. Preferire query read-only con rollback.
- Per input, form, redirect, upload e DB verificare validazione server, query parametrizzate, whitelist, encoding, CSRF/ViewState, traversal e log sensibili.
- Lasciare fuori staging gli untracked in `Public/assets/images/articoli/`, `marche/`, `settori/`, `vettori/`. Non pulire/spostare directory; asset solo se nominativamente autorizzato.

## Commit, push, review, smoke e merge

- Se emerge un blocker fuori scope, chiudere con B senza committare modifiche incomplete.
- A ogni chiusura con esito A, il rapporto conclusivo deve indicare automaticamente il prossimo task consigliato, ricavato dal manuale e dai finding aperti. Deve riportare nome, motivo, prerequisiti e stato NON AVVIATO. Nessun task successivo deve essere avviato o implementato senza autorizzazione del Product Owner.
- Se implementazione e test sono completi, Codex crea un solo commit, pusha il solo task branch e apre o aggiorna la PR verso `frontend-rebuild`, salvo stop condition esplicita.
- PR e merge sono momenti separati: il push non autorizza merge/deploy; ChatGPT assegna A solo dopo la review indipendente del diff pubblicato.
- Codex esegue il merge solo dopo A di ChatGPT e autorizzazione esplicita di Germano, esclusivamente fast-forward. Non decide il merge.
- Nessun push, PR o merge verso `main`. Dopo il merge Codex sincronizza locale/remoto e verifica parent, assenza di merge commit, `frontend-rebuild == origin/frontend-rebuild`, `main == origin/main`, staging, tracked tree e asset protetti.
- Se strumenti, autenticazione o permessi bloccano un'operazione tecnica, Codex si ferma con B e prova precisa: non aggira protezioni, recupera credenziali o trasferisce automaticamente l'operazione a Germano.

## Esiti A/B/E

- `A`: requisito autorizzato completato, verificato e chiudibile; nessun blocker noto nel perimetro.
- `B`: direzione valida ma task incompleto, bloccato o in attesa di fix, autorizzazione, verifica tecnica o smoke.
- `E`: premessa, strategia o modifica errata/pericolosa; regressione grave introdotta o approccio da abbandonare e riprogettare.

Un blocker tecnico scoperto correttamente prima di una modifica pericolosa e normalmente B, non E. Un task UI in attesa dello smoke obbligatorio resta B. Un micro-task A non dichiara automaticamente completa la pagina o l'area.

## Stop conditions

Codex si ferma con B senza ampliare il manifest quando diverge la base; tracked tree o staging non sono puliti; servono file, DB, librerie, tecnologia, strumenti, autenticazione, permessi o obiettivi fuori scope; manca una decisione; una verifica critica non e eseguibile; un contratto chiuso verrebbe violato; emerge un blocker non autorizzato; oppure correttezza, sicurezza o non regressione non sono garantibili.

Regola di esecuzione: **CHATGPT CONTROLLA E AUTORIZZA L'AVANZAMENTO; GERMANO APPROVA LE DECISIONI FINALI; CODEX ESEGUE TUTTE LE OPERAZIONI TECNICHE AUTORIZZATE.**
