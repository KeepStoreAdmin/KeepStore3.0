# KeepStore — attributi prodotto per l'assistente

## CURRENT — candidato F01 Catalog-driven Advisor 1C

Il motore legge un pool autorizzato dal contesto commerciale e costruisce un dizionario soltanto per la richiesta. Non e una nuova anagrafica, non modifica il database e non certifica attributi assenti. Il dump storico non attesta il catalogo corrente; i casi Tech/Food delle prove sono sintetici.

La policy `ks-attributes-1c.1` e un mapping scritto e versionato nel codice, non un'approvazione automatica di ogni etichetta scoperta. ID stabili derivano da scope catalogo, famiglia tassonomica reale, etichetta esatta e unita. Nessun ID commerciale o segreto viene comunicato al browser. La famiglia non deriva da una descrizione o da un nome merceologico.

| Fonte/etichetta esatta | Tipo e operatori | Regola CURRENT |
| --- | --- | --- |
| `MarcheDescrizione` / Marca | testo, uguaglianza | Etichetta nominativa del catalogo, non deduzione di un ID marca da testo |
| Colore del prodotto; Materiale; Formato; Tecnologia di stampa | testo, uguaglianza | Coppia strutturata non ambigua, confronto letterale del valore osservato |
| Memoria installata; Memoria massima | numero, = / almeno / al massimo | MB, GB, TB, MiB, GiB, TiB distinti; nessuna conversione o fusione dei due significati |
| Peso netto; Peso logistico | numero, = / almeno / al massimo | g e kg distinti; netto e logistico non equivalenti |
| Volume; Capacita; Capacità | numero, = / almeno / al massimo | ml e l distinti; anche le due grafie di capacita conservano ID distinti |
| Fronte/retro automatico | booleano, uguaglianza | Soltanto si/sì/true oppure no/false espliciti; altri valori sconosciuti |
| Altre etichette | scoperta non approvata | Consultabili come dati attribuiti; nessuna domanda o hard filter implicito |

Sono acquisibili tabelle a due celle per riga e liste dt/dd non annidate. Layout, celle contenitore, strutture sbilanciate, valori opachi, negazioni, conflitti, Unicode invalido o superamento dei bound non diventano fatti noti. Testo libero e citazioni sono evidenze attribuite, non specifiche certificate. Ogni evidenza conserva campo, riferimento alla fonte e identita articolo/TCId; le citazioni sono brevi, l'HTML originale non arriva al browser.

**Scope variante:** le descrizioni dell'articolo non provano una caratteristica della variante positiva. Senza fonte specifica affidabile restano ambigue/UNKNOWN per il filtro hard; il prezzo e l'identita della variante continuano a provenire dai resolver commerciali. Marca nativa resta dato nominativo del catalogo. Le assenze non significano False o zero.

Compatibilita, allergeni, ingredienti, certificazioni e costo consumabili non sono attributi operativi dedotti dalla descrizione. Non esiste un calcolo del costo per pagina: mancano relazione consumabile-prodotto, resa e prezzo applicabile documentati. Questi requisiti non possono essere soddisfatti o rilassati automaticamente.

## TARGET — schermata gestionale «Attributi prodotto», non implementata

Wireframe funzionale proposto per Enzo:

```text
Articolo [selezione tramite ID e codice]   Variante [nessuna / TCId esatto]
Famiglia tassonomica [ID validati, sola lettura dal prodotto]
Attributo [mapping approvato e versione]    Tipo [testo/numero/booleano/insieme]
Valore [editor tipizzato]                  Unita [allowlist del mapping]
Applicabilita [articolo / variante esatta / esplicitamente tutte le varianti]
Fonte [documento produttore / scheda tecnica / revisione ingredienti]
Riferimento [identificativo e posizione nel documento]
Stato [da verificare / verificato / ambiguo / in conflitto / scaduto]
Revisione [versione e data]                Verifica [responsabile autorizzato]
Conflitti [valori e fonti discordanti, senza cancellazione automatica]
Azioni [Salva bozza] [Richiedi verifica] [Approva mapping/valore autorizzato]
```

Istruzioni operative prima di un futuro sviluppo:

1. Inventariare le fonti disponibili senza compilare valori ipotetici. Separare dati dell'articolo da dati della singola variante.
2. Proporre il mapping con significato, tipo, unita, operatori, ambito e rischio. Alias o conversioni richiedono una regola esplicita, versionata e testata; non unire etichette simili per somiglianza.
3. Validare numero/intervallo/unita, booleani espliciti, fonte, revisione e applicabilita. La validazione non autorizza automaticamente domande o filtri hard.
4. Conservare conflitti e assenze; richiedere revisione competente per compatibilita, sicurezza, composizione e allergeni. Non correggere documenti storici o fatti commerciali tramite questa schermata.
5. Definire separatamente permessi, audit, aggiornamento/revoca e isolamento dell'installazione. L'approvazione di un mapping non autorizza la sua applicazione ad altri tenant o varianti.

Nessuna schermata del gestionale, tabella, migrazione o workflow di verifica e stata installata da questo task. La realizzazione TARGET richiede un mandato distinto; CURRENT funziona senza inventare questi dati.

## Limiti operativi e rilascio

Le prove preparate misurano estrazione, falsi hard e comportamento su fixture; non certificano tutti i cataloghi o la sicurezza universale. La fonte tecnica del contratto resta il Blueprint AI; evidenze e gate nel Masterplan. Task08 NON AVVIATO. **SERVER, LAB, IIS, MYSQL OPERATIVO, ARUBA E DEPLOY SOSPESI.**
