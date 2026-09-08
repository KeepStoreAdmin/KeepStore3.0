# KeepStore 3.0 - regole operative permanenti

Fonte canonica del metodo di lavoro, sintetica e senza cronologia. I manuali in `docs/` conservano checkpoint, architettura, contratti e roadmap.

## Repository, branch e working copy

- Repository: `KeepStoreAdmin/KeepStore3.0`.
- Working copy canonica: `C:\KeepStoreWeb\KeepStore3.0\`.
- Branch stabile di sviluppo: `frontend-rebuild`.
- `main` e `origin/main` sono protetti in modo assoluto: non modificarli, non committarvi, non pusharvi e non aprire PR verso `main`.
- Aggiornamenti e integrazioni sono esclusivamente fast-forward. Vietati merge commit, rebase, reset e force push non autorizzati.
- Si lavora su branch dedicati `task/<nome-task>`, creati dal preciso SHA autorizzato di `frontend-rebuild`.
- Un solo task puo essere attivo. Il successivo non parte finche il corrente non e chiuso, fermato o sostituito esplicitamente da Germano.
- Ogni task inizia con `git fetch`, verifica ref/SHA, staging vuoto e tracked tree pulito. Censire e preservare gli untracked autorizzati.

## Ruoli e autorita

- **Germano** decide priorita e perimetro, approva scelte funzionali o commerciali e autorizza merge, smoke reali, modifiche DB, pagamenti e gateway. Puo fermare o riorientare il task.
- **ChatGPT** coordina: ricostruisce lo stato, definisce requisito, profilo, manifest, guardrail, test e stop conditions; valuta report, diff e finding; assegna A/B/E e propone il merge.
- **Codex** investiga il repository, implementa soltanto cio che e autorizzato, esegue i controlli tecnici pertinenti, pubblica il task branch e riporta evidenze, limiti e finding. Non decide ampliamenti di obiettivi o manifest e non esegue merge.

## Gerarchia delle fonti

In caso di conflitto si applica questo ordine:

1. richiesta corrente approvata da Germano;
2. Git, codice, database e runtime reale per lo stato tecnico;
3. questo `AGENTS.md` per le regole operative permanenti;
4. checkpoint corrente di `docs/KEEPSTORE_MASTERPLAN_OPERATIVO.md`;
5. `docs/KEEPSTORE_SYSTEM_BLUEPRINT.md` per architettura, flussi e contratti;
6. `docs/KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md` soltanto per search, AI, RAG, SEO AI o assistenza acquisto;
7. handoff, memoria, chat e allegati come supporto non autoritativo.

SHA e stato Git reale prevalgono sui checkpoint non aggiornati. Nessuna richiesta autorizza implicitamente modifiche a `main`, esposizione di segreti o merge non approvati.

## Lettura documentale proporzionata

Git e codice reale vanno verificati prima dei prompt importanti. Leggere quanto serve a non perdere contratti pertinenti, senza riletture indiscriminate:

- nuova chat o audit generale: checkpoint del Masterplan e fonti necessarie a ricostruire lo stato; lettura integrale solo se richiesta dall'ampiezza dell'audit;
- nuovo task: checkpoint corrente, sezioni pertinenti, contratti chiusi collegati e file runtime coinvolti;
- task UI: anche contratti ONSUS, mobile e componenti stabilizzati;
- carrello, login, prezzi, promo, checkout, ordine, DB o sicurezza: sezioni architetturali e di sicurezza pertinenti;
- search, AI, RAG, SEO AI o assistenza acquisto: anche AI Assisted Search Blueprint;
- task documentale trasversale o riconciliazione: lettura completa delle fonti coinvolte.

## Manifest, scope e discovery proattiva

- Ogni task dichiara obiettivo, base SHA, manifest esclusivo, divieti, verifiche e output. Vietato modificare file fuori manifest.
- Vietati scope creep, refactoring, cleanup, dipendenze o correzioni estranee motivati da "gia che ci siamo".
- Codex non e un esecutore cieco. In investigazione, implementazione e test controlla superficie e dipendenze dirette pertinenti; cerca bug collegati, regressioni, rischi e problemi di sicurezza, performance o UX, inclusi aspetti prima ignoti a ChatGPT.
- Per ogni finding significativo riporta descrizione, evidenza, file/superficie, severita (`BLOCKER`, `HIGH`, `MEDIUM`, `LOW`), impatto, capacita di blocco e proposta `SAME-TASK CANDIDATE` o `SEPARATE MICRO-TASK`.
- La discovery non autorizza implementazione. ChatGPT decide: `IGNORE / NON RILEVANTE`, `BACKLOG`, `MICRO-TASK SUCCESSIVO`, `REV DEL TASK CORRENTE` oppure `ESTENSIONE AUTORIZZATA DEL TASK`.
- Finding indispensabile per correttezza, sicurezza o non regressione ma fuori manifest: fermarsi con B ed evidenza precisa.

Regola centrale: **CODEX CERCA, ANALIZZA, TESTA E PROPONE; CHATGPT DECIDE; CODEX IMPLEMENTA SOLTANTO DOPO AUTORIZZAZIONE.**

## Profili, modello e investigazione

Ogni prompt dichiara profilo, modello, reasoning e motivazione. Rivalutare la policy se cambiano i modelli disponibili; niente prezzi o rate card.

- `ECONOMY`: GPT-5.6 Luna, Medium; docs semplici o modifica meccanica a rischio minimo.
- `STANDARD`: GPT-5.6 Terra, Medium; sviluppo o bugfix circoscritto.
- `DEEP`: GPT-5.6 Sol, High; root cause incerta, piu componenti, DB/query, sicurezza o regressioni significative.
- `CRITICAL`: GPT-5.6 Sol, Extra High; prezzi, promo, carrello, auth, dati utente, checkout, ordine, pagamento o cambi trasversali.
- GPT-6 Astra: solo casi eccezionali trasversali scelti da ChatGPT. Max e Ultra non sono default; Ultra non si usa ordinariamente.

Con causa dimostrata, `ECONOMY`/`STANDARD` possono implementare direttamente. `DEEP` con root cause incerta parte read-only. `CRITICAL` richiede preflight prima delle modifiche, salvo fix gia dimostrato e autorizzato. Il preflight copre secondo pertinenza Git, manifest, chiamanti, schema/indici DB, dipendenze, build, fixture e test. Non separare investigazione e implementazione se cio duplica il lavoro senza ridurre il rischio.

## Stack e divieti tecnici

Stack reale: ASP.NET WebForms, VB.NET, .NET Framework 4.x, MySQL, code-behind `.aspx.vb`/`.ascx.vb`, `Page.master`, controlli ASCX e `App_Code`.

- Non introdurre C#, ASP.NET Core, Razor/MVC, Blazor, minimal API, controller rewrite, EF Core, migrations, nuova dependency injection, pipeline TypeScript/npm/Vite/Webpack o librerie senza audit e approvazione.
- Non convertire WebForms e non proporre riscritture architetturali non autorizzate. Se una tecnologia diversa e indispensabile, fermarsi con B e motivare.
- Il server resta fonte di verita per sessione, login, carrello, prezzi, listini, IVA, promo, checkout e ordine; niente logica commerciale affidata o duplicata nel browser.

## Baseline minima di verifica

Ogni task verifica almeno: diff/manifest; `git diff --check`; sintassi/logica; chiamanti e dipendenze dirette; percorso positivo; un limite/failure pertinente; regressioni influenzate; secret scan mirato; branch, staging e working tree.

- Runtime: build/precompile e test tecnici appropriati quando pertinenti allo scope.
- UI: browser reale alle viewport richieste; errori console e overflow quando pertinenti.
- Docs-only: niente build, precompile o smoke runtime se il runtime non cambia; verificare invece coerenza, riferimenti, definizioni, manifest e diff.
- Un test non eseguibile o privo di fixture va dichiarato; non inventare esiti. La profondita cresce con il profilo e il rischio.

## Mobile-first e ONSUS

- Il mobile e l'esperienza primaria. Progettazione e QA iniziano da `360px` e `390px`, poi tablet e desktop.
- Nessuna funzione essenziale puo dipendere dal solo hover. Verificare touch target, ordine contenuti, leggibilita, densita, offcanvas e scrolling.
- Nessun A visuale senza browser mobile reale; quando previsto serve anche smoke Germano.
- KeepStore e fonte di dati/logica/permessi; ONSUS e fonte UI/UX. Un refactor grafico non autorizza fix nascosti alla business logic.

## Protezione dati, segreti e asset

- Non esporre password, token, secret, connection string, cookie/session id, dati personali, carte, firme gateway o transazioni complete. Sanitizzare output e log.
- Nessuna scrittura DB, modifica schema/SP/dump, chiamata gateway, pagamento, ordine reale o invio esterno senza task e autorizzazione. Preferire query read-only con rollback.
- Per input, form, redirect, upload e dati DB verificare validazione server, query parametrizzate, whitelist, encoding, CSRF/ViewState, open redirect, path traversal e log sensibili.
- Preservare e lasciare fuori staging gli asset non tracciati in `Public/assets/images/articoli/`, `marche/`, `settori/` e `vettori/`. Non pulire, spostare o aggiungere intere directory; un asset entra solo se nominativamente autorizzato dal manifest.

## Commit, push, review, smoke e merge

- Se emerge un blocker fuori scope, chiudere con B senza committare modifiche incomplete.
- Se implementazione e test autorizzati sono completi, creare un singolo commit coerente e pushare soltanto il task branch su origin.
- Il push non autorizza merge/deploy. La PR deve avere base esclusiva `frontend-rebuild`.
- ChatGPT assegna A definitivo solo dopo aver verificato il diff pubblicato. Il merge avviene soltanto con A e autorizzazione esplicita di Germano, sempre fast-forward.
- Nessun push, PR o merge verso `main`. Dopo un merge autorizzato verificare `frontend-rebuild == origin/frontend-rebuild`, `main == origin/main`, staging vuoto e tracked tree pulito.

## Esiti A/B/E

- `A`: requisito autorizzato completato, verificato e chiudibile; nessun blocker noto nel perimetro.
- `B`: direzione valida ma task incompleto, bloccato o in attesa di fix, autorizzazione, verifica tecnica o smoke.
- `E`: premessa, strategia o modifica errata/pericolosa; regressione grave introdotta o approccio da abbandonare e riprogettare.

Un blocker tecnico scoperto correttamente prima di una modifica pericolosa e normalmente B, non E. Un task UI in attesa dello smoke obbligatorio resta B. Un micro-task A non dichiara automaticamente completa la pagina o l'area.

## Stop conditions

Codex si ferma con B, senza improvvisare o ampliare il manifest, quando manca o diverge la base richiesta; il tracked tree iniziale o lo staging non sono puliti; servono file, schema DB, librerie, tecnologia, permessi o obiettivi fuori scope; manca una decisione funzionale/commerciale; una verifica critica non e eseguibile; un contratto chiuso verrebbe violato; emerge un finding blocker non autorizzato; oppure correttezza, sicurezza o assenza di regressioni non possono essere garantite nel perimetro.
