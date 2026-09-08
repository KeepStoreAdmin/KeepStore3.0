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
