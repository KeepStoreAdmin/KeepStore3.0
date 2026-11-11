# KeepStore — merchandising e pubblicazione web: consegna a Enzo

## Perimetro e legenda

Task `KS-T09-ENZO-MERCHANDISING-HANDOFF-1A`, 11/11/2026. Primo intervento Task09, **DOCS ONLY** sulla stable `a9bd163506f1ad77285bea36d9dbbd26b8a2a99a`. Le due schermate sotto sono specifiche **TARGET, NON IMPLEMENTATE**. Questo manuale non autorizza modifiche al gestionale, dati, procedure, configurazioni o pubblicazione.

- **CURRENT ATTIVO:** comportamento SOURCE effettivamente richiamato dalla composizione web alla baseline; non equivale a collaudo del database installato.
- **CURRENT LEGACY/INUTILIZZATO:** codice presente ma non usato dalla composizione HOME corrente.
- **TARGET:** comportamento richiesto alla futura implementazione gestionale, da autorizzare e verificare separatamente.
- **DA VERIFICARE:** informazione non dimostrata dalle fonti disponibili; non trasformarla in un esito positivo.

Ogni verifica operativa distingue **C — idoneità commerciale**, **S — eleggibilità nella specifica selezione**, **P — presenza effettiva nella HOME**. C non implica S; S non implica P: ordinamento, limiti, deduplicazione e precedenze possono escludere una riga idonea. Le checklist sono istruzioni TARGET per Enzo fondate sui contratti CURRENT indicati, non prove runtime eseguite.

## R1 — Glossario e autorità dei dati

| Dato | Classificazione e significato verificabile | Cosa non dimostra |
| --- | --- | --- |
| `Vetrina` | **CURRENT ATTIVO:** flag dell'articolo, richiesto a 1 dai pool prodotto HOME correnti insieme ad abilitazione, listino e altre condizioni. | Non garantisce pubblicazione nella HOME, promozione o acquisto; non è un consenso separato per ciascuna azienda. |
| `DataCreazione` | **CURRENT ATTIVO:** data gestionale di tipo DATE, nullable nel DDL SOURCE, esposta da `vsuperarticoli`; alimenta Novità e l'ordinamento catalogo «Inseriti di recente». | Non certifica la prima pubblicazione web. La conservazione automatica nella UI desktop è **DA VERIFICARE**. |
| `Visite` | **CURRENT ATTIVO:** contatore condiviso dell'articolo; la PDP incrementa una volta per articolo nella sessione sui GET ammessi, senza postback/prefetch. È usato come segnale di ordinamento, anche nelle offerte. | Non conta vendite, clienti unici o accessi attribuibili con certezza a un'azienda/variante. Altri incrementi legacy SOURCE esistono: non ricostruisce una metrica di traffico esatta. |
| `InOrdine` | **CURRENT ATTIVO:** quantità separata da giacenza/disponibilità, presente in `articoli_giacenze`; il pool In arrivo ammette valori positivi anche senza stock. | Non è disponibilità immediata, data d'arrivo né consegna garantita al cliente. Il significato documentale desktop effettivo è **DA VERIFICARE**. |
| `articoli_arrivi` | **CURRENT ATTIVO:** il catalogo legge righe con quantità positiva e data futura, sommandole per articolo/data. Il DDL contiene anche `TCid`, ma questa proiezione catalogo raggruppa per articolo. | La data non prova disponibilità della variante selezionata né una promessa di spedizione/consegna. Non è un requisito del pool HOME In arrivo. |
| `Giacenza` | **CURRENT ATTIVO:** quantità di stock della riga; l'identità SOURCE della giacenza è magazzino + articolo + TCId. Nei pool HOME ordinari `stk` somma le righe per articolo. | Stock positivo aggregato non garantisce stock della variante scelta né quantità libera. |
| `Impegnata` | **CURRENT ATTIVO:** quantità impegnata, distinta dalla giacenza. I controlli di disponibilità netta non devono essere aggirati. | Non va corretta per far apparire una card. Nessun documento o impegno è modificato in questo task. |
| `Disponibilita` | **CURRENT ATTIVO:** campo memorizzato distinto dallo stock; il helper di presentazione usa lo stock netto e non permette al valore memorizzato di sovrascriverlo. La discovery usa `GREATEST(0,Giacenza-Impegnata)` della variante esatta. | Non deve essere presentata come giacenza o sommata a `InOrdine`. Un campo positivo isolato non autorizza una CTA acquisto. |

**CURRENT ATTIVO — contesti distinti:** articolo, data, Vetrina e Visite sono condivisi quando le aziende usano lo stesso database/articolo. Prezzo, IVA, offerte e disponibilità acquistabile vanno valutati con azienda, listino e variante esatti. `ListinoDefault` è il listino anonimo della vetrina; l'account usa il proprio listino persistito e validato. `ListinoUser` serve all'assegnazione iniziale in registrazione, non sostituisce il listino dell'account. Aziende con database indipendenti non condividono automaticamente gli stessi articoli.

**TARGET — precauzione gestionale:** mostrare il database come identità non segreta, senza credenziali; elencare le aziende interessate in sola consultazione soltanto se la relazione è verificabile. Non dedurre «tutte le aziende» dal solo numero articolo né trasferire prezzi fra listini. Contesto incompleto: **DA VERIFICARE**, niente diagnosi commerciale positiva.

Fonti baseline: [articoli e DataCreazione](<../Database%20Taikun/KeepStore.sql#L194>) (`Database Taikun/KeepStore.sql:194`, campi 223/227/230); [giacenze](<../Database%20Taikun/KeepStore.sql#L364>) (`:364`); [arrivi](<../Database%20Taikun/KeepStore.sql#L259>) (`:259`); [vista](<../Database%20Taikun/KeepStore.sql#L25736>) (`:25736`). [Blueprint contesti](KEEPSTORE_SYSTEM_BLUEPRINT.md#L363) (`docs/KEEPSTORE_SYSTEM_BLUEPRINT.md:363`, `:365`, `:373`). [Helper disponibilità](../App_Code/AvailabilityDisplayHelper.vb#L57) (`App_Code/AvailabilityDisplayHelper.vb:57`, `:261`); [visite PDP](../articolo.aspx.vb#L1788) (`articolo.aspx.vb:1788`, chiamata `:284`). Il DDL è una fonte versionata, non attestazione dello schema operativo.

## CURRENT ATTIVO — cosa alimenta realmente la HOME

`BindHome` richiama offerte, novità, arrivi e indice commerciale; riserva chiavi comuni prima di recenti e discovery. I nomi dei metodi non sono nomi commerciali certificati.

**C — precondizioni condivise, da distinguere dal risultato finale:** `TryLoadProducts` filtra `NListino` corrente, ID positivo, articolo abilitato e `Vetrina=1`. Fuori discovery, l'ammissione preliminare considera almeno un prezzo grezzo/base/promo netto/lordo positivo: questo non basta a certificare il prezzo fiscale effettivamente mostrabile. Promozioni, prezzi e CTA devono restare quelli dei resolver/renderer correnti, senza calcoli gestionali sostitutivi. I pool ordinari usano stock aggregato per articolo; non attribuirgli la certezza di una giacenza per TCId. **P:** nessun pool promette presenza se C o S risultano positivi.

| Selezione CURRENT ATTIVA | S — condizioni e ordine specifici, oltre alle precondizioni condivise | P — selezione finale corrente |
| --- | --- | --- |
| Offerte, `GetDealOfferPool` | Prefiltro `InOfferta=1`, intervallo di listini dell'offerta e stock almeno 1; snapshot promozionale autorizzato obbligatorio. Ordine finale: scadenza verificata prima, poi visite, ID e TCId. Il flag da solo non autorizza sconti. | Pool richiesto fino a 96; fino a 6 card diverse, con chiavi business/display comuni alle sezioni successive. Se vuoto, sezione omessa. |
| Novità, `GetNewArrivalsPool` | Stock almeno 1, `InOrdine<=0`, `DataCreazione` da oggi meno 90 giorni incluso a domani escluso; ordine data DESC, ID DESC, TCId ASC. NULL e date oltre oggi non entrano qui. | Pool fino a 60, una variante eleggibile per articolo; alternanza con In arrivo e massimo 8 card complessive, non 8 per pool. |
| In arrivo, `GetIncomingPool` | `InOrdine>0`; ammissione stock almeno 1 **oppure** InOrdine positivo. Ordine InOrdine DESC, ID DESC, TCId ASC; nessun requisito di data in `articoli_arrivi`. | Pool fino a 60, alternato con Novità; riga marcata informativa se proveniente da arrivi e giacenza non positiva o helper non disponibile. Il renderer omette i pulsanti azione di quelle card. Non promettere l'acquisto. |
| Indice commerciale, `GetBestSellerPool` | `CommercialScore>0`, poi score DESC, ultima attività DESC, ID DESC, TCId ASC. Attività su documenti ammissibili nei 12 mesi attraverso oggi, movimenti configurati di uscita, righe ordinarie positive, stati validi e senza note credito. Score prudente: massimo fra somme quantità ordini/impegni e scarichi, non somma dei due. | Pool fino a 120, una variante eleggibile per articolo, fino a 8 articoli distinti. La sezione `HomeLegacyBestSection`, nonostante il nome tecnico, è attiva quando ci sono righe. Non è una certificazione di vendite/Bestseller. |
| Visti di recente, `GetRecentlyViewedProducts` | ID ricordati per il visitatore, listino corrente, stock almeno 1; ordine degli ID recenti. Nessun riempimento automatico in assenza di cronologia. | Fino a 8, esclusi articoli/chiavi già selezionati secondo la deduplicazione corrente. Non è una scelta amministrativa Enzo. |
| Dal nostro catalogo, `LoadHomeCatalogDiscovery` / `GetCatalogFallbackPool` | Solo se offerte, indice e recenti sono vuoti e arrivi assenti oppure **tutti** strettamente informativi. Magazzino 1 e TCId esatto, identità stock univoca, netto almeno 1 e prezzo base positivo nella modalità IVA corrente prima del ranking; TCId -1 o positivo. | Una sola lettura pool, massimo 8, ordinati data/visite/ID/TCId; niente duplicati con arrivi, niente riempimento artificiale. Un pool piccolo può dare meno di 8 card. |

**CURRENT ATTIVO — immagini:** i pool attivi sopra non impongono `Img1` come filtro universale. Il renderer usa il resolver immagini/placeholder esistente. Segnalare immagine assente come qualità del contenuto, senza convertirla in «non pubblicabile» o obbligare modifiche a prezzi/stock. Una card con placeholder non prova un file immagine valido.

**CURRENT ATTIVO — indice e aziende:** l'aggregato di attività può includere aziende con identità IVA italiana formalmente valida e coincidente secondo la policy esistente; identità non verificata resta locale. Questo riguarda il solo indice: non estende listini, account o autorità commerciali. Non ricostruire vendite nette esatte dall'indice.

### CURRENT LEGACY/INUTILIZZATO — non usare per promettere pubblicazione

- `GetFeaturedPool` contiene Vetrina, `Img1` non vuota e stock, ma non ha call-site nella composizione HOME attiva: **il suo filtro immagine non è la regola delle Novità correnti**.
- `GetMostViewedPool` esiste ed è richiamato da `GetTopRatedPool`; nessuno dei due alimenta l'attuale `BindHome`. Non presentare una selezione HOME «più visti» autonoma come attiva.
- `HomeLegacyEditorialSection` e `HomeLowerColumnsSection` sono forzate a `Visible=False`. Il codice conservato non equivale a una sezione pubblicata.

Riferimenti baseline: [call-site e limiti](../Default.aspx.vb#L341) (`Default.aspx.vb:341`, `:356`, `:368`, `:386`, `:396`, `:406`); [sezioni disabilitate](../Default.aspx.vb#L381) (`:381`, `:421`); [offerte](../Default.aspx.vb#L1015) (`:1015`, `:1023`, `:1704`); [legacy e pool attivi](../Default.aspx.vb#L1057) (`:1057`, `:1063`, `:1073`, `:1079`, `:1085`); [indice](../Default.aspx.vb#L1116) (`:1116`); [alternanza informativa](../Default.aspx.vb#L1161) (`:1161`, `:1187`); [discovery](../Default.aspx.vb#L1211) (`:1211`, `:1248`, `:1259`); [recenti](../Default.aspx.vb#L1280) (`:1280`); [query condivisa](../Default.aspx.vb#L1429) (`:1429`, `:1488`, `:1493`, `:1501`, `:1541`, `:1546`); [stock](../Default.aspx.vb#L1692) (`:1692`, `:1696`); [renderer informativo](../Default.aspx.vb#L3474) (`:3474`); [placeholder](../Default.aspx.vb#L2567) (`:2567`).

## R2 — TARGET: Anagrafica / Pubblicazione web

Wireframe 1 — specifica da implementare soltanto con mandato futuro:

```text
+--------------------------------------------------------------------+
| TARGET / NON IMPLEMENTATO — Anagrafica / Pubblicazione web          |
| Database: [identita senza segreti]  Articolo: [ID] Codice: [codice]   |
| Aziende interessate (informativo): [elenco verificato / da verificare]|
|                                                                    |
| [ ] Vetrina                                                        |
| Vetrina attiva non garantisce presenza nella HOME o acquisto.        |
|                                                                    |
| DataCreazione originale: [gg/mm/aaaa / NULL] (sola lettura)           |
| [Rettifica data]                                                   |
|   Nuova data: [gg/mm/aaaa]  Motivo: [.............................]   |
|   [ ] Confermo la rettifica esplicita della data originale           |
|   [messaggio di validazione; aziende interessate prima di confermare]|
|                                                                    |
| [Salva] [Annulla]   [Apri Verifica ecommerce]                        |
+--------------------------------------------------------------------+
```

**CURRENT ATTIVO, evidenza SOURCE del contratto dati:** `Newarticoli` accetta `parDataCreazione DATE`; `Modarticoli` riceve lo stesso parametro e assegna `DataCreazione=parDataCreazione`. Il parametro può quindi riscrivere la data; non è dimostrato che il desktop la conservi. [Firme procedure](<../Database%20Taikun/KeepStore.sql#L11814>) (`Database Taikun/KeepStore.sql:11814`, `:15361`), [assegnazione Modarticoli](<../Database%20Taikun/KeepStore.sql#L12408>) (`:12408`). Installazione e uso effettivi delle procedure nel gestionale restano **DA VERIFICARE**.

**TARGET — salvataggio ordinario:** conservare il valore originale letto per l'articolo, compreso un NULL preesistente; passarlo inalterato a `Modarticoli` senza sostituirlo con oggi. Creazione nuova: proporre la data gestionale concordata e validarla; non rinominare il campo «prima pubblicazione». Se il dato corrente cambia durante la modifica, fermare il salvataggio e richiedere rilettura/confronto, senza sovrascrittura silenziosa.

**TARGET — Rettifica data:** azione separata, con data precedente/nuova, motivo obbligatorio, conferma esplicita e contesto articolo/database/aziende visibile. La tracciabilità della rettifica e l'identità dell'operatore sono requisiti futuri: non esiste in questo documento una tabella, colonna o API di audit già disponibile. Se non è predisposta una soluzione autorizzata di audit, non abilitare la rettifica; consentire l'annullamento senza effetto sui dati.

**TARGET — validazioni proposte, non già certificate:** formato data valido e compatibile con DATE; per nuove date/richieste di rettifica non accettare una data futura rispetto al giorno gestionale concordato. NULL storico va segnalato e conservato in modifica ordinaria, senza riparazione automatica. Un'eventuale futura policy diversa richiede decisione esplicita. Messaggi: «Data non valida», «Data futura: verificare la rettifica», «Indicare il motivo e confermare la rettifica», «Contesto articolo cambiato: rileggere prima di salvare». Queste validazioni non sono dedotte dal solo tipo SQL DATE.

## R3 — TARGET: Verifica ecommerce

Wireframe 2 — diagnostica proposta, non un nuovo resolver né una lettura eseguita:

```text
+--------------------------------------------------------------------+
| TARGET / NON IMPLEMENTATO — Verifica ecommerce                      |
| Database [identita]  Articolo [ID/codice]  Variante TCId [esatto]     |
| Azienda [selezione autorizzata]  Listino [autorevole / non verificato]|
| Modalita IVA [dal contesto]                                         |
| Vetrina [si/no]  Img1 [presente/assente; non requisito universale]    |
| Magazzino [contesto] Giacenza [...] Impegnata [...] Netto [...]       |
| Disponibilita memorizzata [...]  InOrdine [...]                      |
| Arrivi documentati [data/quantita; articolo o variante verificata]   |
| Nessuna data di consegna garantita.                                 |
|                                                                    |
| C — Commerciale [verificato / non idoneo / non verificabile]         |
|     Prezzo/IVA/offerta/stock dalla medesima autorita web              |
| S — Selezione     Esito e ragione secondo il pool corrente           |
|     Novita [...] Arrivi [...] Offerte [...] Indice [...]             |
| P — Presenza     [osservata / non osservata / non verificata]        |
|     Limite, posizione, deduplica e precedenze se dimostrabili        |
| [Aggiorna diagnosi] [Torna all'anagrafica]                           |
+--------------------------------------------------------------------+
```

**TARGET — esiti sicuri:** produrre C soltanto riusando le autorità commerciali esistenti, con identità articolo/TCId/azienda/listino conservata; errore tecnico o contesto incompleto dà «non verificabile», non «disponibile» o prezzo sostitutivo. La quantità netta della variante non si deduce dallo stock aggregato di un pool. Non abilitare acquisto o assegnare una promozione dalla sola diagnostica.

**TARGET — S e P separati:** riportare le condizioni della tabella CURRENT sopra per la specifica selezione. P va dichiarata «osservata» soltanto su una composizione effettivamente verificata, nel contesto e momento indicati; S positiva, da sola, lascia P «non verificata». Nessun pulsante deve forzare la presenza con alterazioni di stock, data, visite o prezzo.

**CURRENT ATTIVO — catalogo, distinto dalla HOME:** «Inseriti di recente» usa `CatalogCreatedDate`: date future o NULL in fondo, senza escludere l'articolo dal catalogo per questa sola ragione. «Più visualizzati» usa il segnale visite e gli spareggi esistenti, non vendite. Gli arrivi catalogo aggregano quantità positive e date future per articolo/data, senza attestare la variante: la diagnostica TARGET deve dichiarare tale granularità. Fonti: [proiezione data](../articoli.aspx.vb#L893) (`articoli.aspx.vb:893`), [ordinamento](../articoli.aspx.vb#L1147) (`:1147`), [arrivi](../articoli.aspx.vb#L1240) (`:1240`).

## R4 — TARGET: istruzioni operative per Enzo

Queste procedure preparano la futura UI. Non autorizzano a eseguire operazioni sul database o a correggere dati in questo task. Applicare sempre i tre livelli C/S/P, senza usare una condizione del pool come autorizzazione commerciale.

| Operazione TARGET | C — controllo commerciale | S — controllo selezione | P — verifica presenza |
| --- | --- | --- | --- |
| 1. Creare un articolo | Confermare database, codice, articolo e varianti, azienda/listino autorizzati; prezzo/IVA e stock dai flussi competenti. Non copiare il prezzo di un'altra azienda. | Impostare consapevolmente Vetrina e data gestionale; confrontare ciascun pool CURRENT, non `GetFeaturedPool`. | Non promettere inserimento automatico: verificare limiti/ordine/dedup della composizione, altrimenti «non verificata». |
| 2. Modificare l'anagrafica | Conservare ID/TCId e contesto, senza cambiare dati commerciali estranei. Leggere e preservare DataCreazione originale, anche NULL storico. | Una modifica testuale non deve ringiovanire il prodotto nella finestra Novità. Passare la data originale a Modarticoli. | La modifica non azzera priorità né garantisce una nuova posizione; distinguere aggiornamento anagrafico da osservazione HOME. |
| 3. Rettificare la data | Richiedere autorizzazione, motivo, confronto prima/dopo e audit TARGET; se indisponibile, annullare. | Esplicitare che la rettifica può cambiare Novità e ordinamento, senza promettere inclusione. Applicare le validazioni TARGET R2. | Verificare soltanto dopo un salvataggio autorizzato; nessuna rettifica per ottenere artificialmente una card. |
| 4. Abilitare/disabilitare Vetrina | Mostrare le aziende che condividono l'articolo e confermare il perimetro; Vetrina non corregge stock/prezzo. | Vetrina=1 è necessaria nei pool attivi ma non sufficiente. Vetrina=0 esclude le loro righe. | Non presentare il toggle come pubblicazione istantanea: P richiede una composizione verificata, non il solo salvataggio. |
| 5. Capire l'apparizione HOME | Verificare il contesto e l'esito dei resolver, inclusi eventuali errori tecnici. | Controllare Novità, In arrivo, Offerte e Indice con le condizioni specifiche; recenti dipendono dal visitatore e discovery dai pool vuoti/informativi. | Controllare ordine, limiti 6/8 e chiavi condivise; l'esclusione per dedup non è un errore commerciale. |
| 6. Distinguere merce disponibile/ordinata/prevista | Leggere giacenza, impegno e netto dell'esatta variante/magazzino. InOrdine non aumenta il netto vendibile. | Arrivi HOME richiede InOrdine positivo; arrivi datati catalogo deriva da articoli_arrivi, con la granularità dichiarata. | Una card In arrivo può essere informativa e senza acquisto; niente data di consegna garantita. |
| 7. Cambiare azienda/listino/variante | Riconfermare l'intera identità; listino anonimo della vetrina distinto da quello autenticato. Nessun fallback al listino 1 o a un altro TCId. | Ricalcolare la diagnosi S sul nuovo contesto, senza ereditare offerta o disponibilità dal precedente. | P appartiene al contesto verificato: un'apparizione su Taikun non prova la presenza su Webaffare. |
| 8. Diagnosticare dati incompleti | Segnalare «non verificabile» e il dato mancante; non modificare prezzi, stock, impegni o listini per far passare C. | Confrontare solo la regola del pool realmente chiamato; immagine assente non implica esclusione universale. | Separare causa dimostrata da ipotesi. Nessuna forzatura di ranking, visite o date; lasciare P non verificata se manca osservazione. |

### TARGET — casi limite per l'approvazione della futura schermata

| Caso | C — idoneità commerciale | S — eleggibilità | P — presenza effettiva |
| --- | --- | --- | --- |
| Immagine assente | Non inventare un prezzo o una disponibilità; segnalare qualità immagine. | Img1 non è requisito dei pool attivi sopra; il filtro Img1 di GetFeaturedPool è legacy. | Possibile placeholder corrente, non garanzia di card né di asset valido. |
| Giacenza zero | Non vendere come disponibile; distinguere quantità ordinata. | Normalmente fuori pool stock; In arrivo può ammettere InOrdine>0 e restare informativo. Discovery esclusa. | Nessuna promessa di acquisto o consegna dalla sola card. |
| Giacenza positiva ma netto nullo | Non mostrare quantità acquistabile positiva aggirando l'impegno. | Il prefiltro di stock ordinario non prova il netto; discovery richiede netto>=1. | Una presenza informativa o un'ammissione preliminare non autorizza acquisto. |
| Data futura o NULL | Non altera da sola l'autorità su prezzo/stock; conservare l'anomalia storica senza ripararla implicitamente. | Non entra in Novità; catalogo p_recenti colloca in fondo, non rimuove per sola data. Nuove date/rettifiche seguono R2 TARGET. | Altre selezioni possono essere idonee: non dedurre assenza generale dalla finestra Novità. |
| Variante senza riga giacenza | Non sostituire con lo stock di altra variante o dell'articolo aggregato. | Discovery richiede identità stock esatta/univoca; pool aggregati non provano la variante. | Eventuale riga HOME non basta a certificare C per il TCId richiesto. |
| Vetrina attiva, pool non soddisfatto | Ricontrollare C indipendentemente dalla visibilità. | Indicare la ragione specifica: data, InOrdine, offerta non autorizzata o score assente, soltanto se dimostrata. | S negativa oppure limiti/dedup possono spiegare l'assenza; nessuna forzatura dati. |
| Aziende stesso DB, listini differenti | Articolo/data/Vetrina condivisi, ma prezzi/IVA/offerte dal contesto proprio, con TCId esatto. | Idoneità in un listino non trasferibile all'altro. L'eventuale scope fiscale dell'indice non amplia i listini. | Presenza e contenuto vanno verificati separatamente, senza dichiarare un tenant reale esercitato in questo task. |

## R5 — TARGET: criteri di accettazione del futuro gestionale

1. Database, codice, articolo e TCId esatti, con azienda/listino coerenti; contesto mancante fermato o marcato non verificabile. Nessuna modifica accidentale al listino di un'altra azienda.
2. Modifica ordinaria con DataCreazione invariata, incluso NULL preesistente; Newarticoli e Modarticoli ricevono il valore deliberato senza assegnazioni automatiche a oggi. Verificare la UI desktop reale prima di dichiarare il criterio soddisfatto.
3. Rettifica data separata, motivata, confermata e tracciabile con soluzione di audit approvata; annullamento senza scritture. Nessuna tabella/colonna di audit presunta disponibile.
4. Diagnostica distinta C/S/P, allineata ai resolver esistenti; stock netto per variante, errore tecnico e dato mancante non diventano disponibilità o offerta. Nessuna formula economica o autorità commerciale nuova.
5. Vetrina=1 non implica pubblicazione automatica; Img1 non è un blocco universale; limiti/dedup e priorità spiegati senza alterare ranking o dati per ottenere visibilità.
6. InOrdine e arrivi datati separati dalla disponibilità immediata; nessuna data di consegna garantita. Non attribuire una data aggregata per articolo a una variante non verificata.
7. Verificare i sette casi limite R4 nell'implementazione futura autorizzata, distinguendo C/S/P e aziende con listini differenti. Non dichiararli collaudati tramite questo documento.

## R6 — Riferimenti, verifiche e Non certificato

Le righe SOURCE citate sono riferite al commit baseline sopra; i numeri potranno cambiare nei commit futuri. Il dump SQL versionato è stato letto da Git: la sua assenza locale protetta non è stata ripristinata. Nessun SQL è stato eseguito.

Riusare il [manuale attributi prodotto Enzo](KEEPSTORE_SHOPPING_ATTRIBUTES_ENZO.md) per la distinta materia attributi/assistente, senza duplicarla qui. I contratti commerciali rimangono nel [System Blueprint](KEEPSTORE_SYSTEM_BLUEPRINT.md); requisiti/priorità nella [Roadmap](KEEPSTORE_PRODUCT_ROADMAP.md), evidenze nel [Masterplan](KEEPSTORE_MASTERPLAN_OPERATIVO.md), governance in [AGENTS](../AGENTS.md).

**Non certificato:** entrambe le schermate TARGET non sono implementate; il repository web non dimostra il comportamento effettivo della UI desktop Enzo, le sue validazioni o l'uso delle procedure installate. Nessun database operativo consultato, nessuna query, nessun collaudo MySQL/IIS/LAB/browser/precompile eseguito. Nessuna metrica di vendita esatta, prestazione o risultato commerciale certificato. Nessun rilascio o modifica di configurazione autorizzati. I controlli di questo task sono solo documentali: manifest, link, riferimenti sulla baseline, classificazioni, diff-check, secret guard incrementale e CI del candidato.

Task09 resta **PARZIALE**: consegna progettuale documentale, non completamento del gestionale. PR DRAFT; prima di eventuale integrazione servono review indipendenti ChatGPT e Claude sullo stesso SHA, CI richiesta PASS e autorizzazione PO, poi FF-only e sincronizzazione Windows A–I. Nessun merge, deploy o task successivo. Coupon/Groupon STANDBY. **CONSEGNA SERVER SOSPESA.**
