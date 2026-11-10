# KeepStore — Accesso MySQL online come sola fonte dati QA

Decisione PO 2026-11-10. Contratto permanente in AGENTS.md; standard comune segreti in KEEPSTORE_SECRET_PROTECTION_STANDARD.md. **Runbook documentale: non configura connessioni o password.**

## Ambito e scopo

Quando servono righe reali per comparare prezzi, listini, IVA, stock, articoli o varianti, preferire poche SELECT MySQL online con un account dedicato read-only, anziche allestire o ricostruire un LAB soltanto per acquisire campioni. Vietati INSERT, UPDATE, DELETE, DDL, GRANT, procedure con effetti, lock, test transazionali/ordini, modifica di oggetti SQL, EXPLAIN, EXPLAIN ANALYZE, benchmark, dump e scansioni pesanti sul server online. I test che mutano dati restano in LAB autorizzato; i dati online non sostituiscono una certificazione IIS e prestazionale.

## Prima configurazione, una sola volta sul PC

1. Il PO mette a disposizione un **account MySQL gia predisposto con soli SELECT** sugli oggetti commerciali strettamente necessari, senza GRANT OPTION, modifiche o accessi di amministrazione. Non usare root o l'account web con DML. Se non esiste, STOP: crearlo o modificarne privilegi richiede un mandato amministrativo distinto.
2. Codex, eseguito sul PC Windows del PO, verifica le ACL del profilo privato e prepara un deposito fuori da C:\KeepStoreWeb, dalla webroot e da cartelle condivise. Preferenza: Gestione credenziali Windows (credenziale generica) con API WinCred autorizzata; alternativa: Get-Credential tramite prompt mascherato e Export-Clixml di PSCredential, cifrato via DPAPI CurrentUser, sotto APPDATA in cartella con ACL gia riservate. Non inventare cifrature nuove o modificare l'architettura KSAES2 del runtime.
3. Il PO digita password e username **solo nel prompt locale mascherato**, mai nella chat. Codex utilizza il deposito dal medesimo account Windows tramite API appropriate, senza mostrare password, stringhe di connessione integrali o trasferirle in command-line, environment, log, transcript o file temporanei.
4. Conservare la credenziale finche valida e necessaria al progetto. La protezione DPAPI CurrentUser dipende dal profilo e computer: non e un backup portabile. Quando cambia la password, aggiornarla localmente; a fine progetto il PO elimina il deposito e revoca l'account sul server.
5. La chat ChatGPT conserva la **regola**, non la credenziale. Nessuna promessa di memoria password o accesso diretto al PC dalla chat.

## Sequenza per ogni task

1. Verificare che il task richieda davvero dati online, quale tenant/listino e quali campi non personali; riusare campioni gia acquisiti quando appropriati.
2. Identificare il server atteso dalla configurazione privata, verificare TLS con certificato e host validi e account con soli SELECT; se fallisce, non indebolire i controlli.
3. Imporre timeout lato client/sessione, SELECT parametrizzate con filtro tenant e limite di cardinalita, transazione READ ONLY, preferibilmente 10-100 righe per campione. Evitare scansioni generali o query ad alto costo; interrompere in presenza di carico anomalo.
4. Usare risultati per confronti read-only circoscritti o fixture sintetiche offline. Non estrarre dati clienti, ordini personali, email o pagamento; non salvare dump con PII e non trasmettere valori sensibili ad assistenti.
5. Registrare solo SQL sanitizzato, tipo/numero di righe, condizioni di prova e limiti; chiudere connessioni. Mai modificare il server online per superare un errore.

## Stato del collaudo precedente

KS-A02-CATALOG-MYSQL-READONLY-1A: B, account LAB audit/web senza SHOW VIEW sulle viste vsuperarticoli e varticolilistini, nessun GRANT eseguito; query complete ed EXPLAIN non certificati. Recovery LAB REV6 A e ambiente ripristinato. L'uso della produzione come fonte dati limitata puo accelerare confronti futuri, ma **non** trasforma questo B in A e non certifica prestazioni o flussi mutativi.

Nessun segreto, connessione, privilegio, test, codice applicativo o deploy modificato dal presente runbook.
