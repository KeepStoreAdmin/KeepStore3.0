# Local Product Detail Preview Setup

## 1. Scopo

Questo documento descrive i requisiti e la procedura minima per preparare un ambiente locale WebForms dove testare la preview `ProductDetailView` con dati reali.

La preview deve essere usata solo per confronto visuale e tecnico, attivandola con:

- `Request.IsLocal=True`
- `ksProductDetailPreview=1`

Il documento non abilita la preview in produzione, non modifica il flusso reale `articolo.aspx` e non introduce configurazioni applicative nuove.

## 2. Stato attuale

La preview prodotto e' gated da codice in `articolo.aspx.vb`:

- `IsProductDetailPreviewEnabled()` ritorna vero solo se `IsProductDetailDebugModeAllowed()` e' vero;
- `IsProductDetailDebugModeAllowed()` richiede `Request.IsLocal`;
- oltre al gate locale, serve `ksProductDetailPreview=1`;
- il controllo e' caricato via `IProductDetailView`;
- `BindProductDetailPreview(row)` viene eseguito dopo `BindProduct(row)`.

Il live pubblico non puo' attivare la preview perche' le richieste al dominio pubblico non hanno `Request.IsLocal=True`.

La UI reale resta authoritative:

- `articolo.aspx` e `articolo.aspx.vb` continuano a governare prodotto, gallery, SEO, disponibilita, varianti e buy box reale;
- `pnlProduct` non deve essere sostituito;
- la preview resta affiancata/diagnostica;
- add-to-cart reale e varianti operative restano fuori perimetro.

## 3. Requisiti minimi

Per testare la preview localmente servono:

- Windows con .NET Framework 4.x e ASP.NET 4.x;
- IIS Express oppure IIS locale;
- supporto ASP.NET WebForms abilitato;
- repository disponibile, per esempio `C:\KeepStoreWeb\KeepStore3.0` o path equivalente;
- `web.config` valido per l'ambiente locale;
- accesso DB compatibile con la connection string `EntropicConnectionString`;
- permessi temporanei di lettura/scrittura per cartelle runtime ASP.NET e, se usata dall'app, `App_Data`;
- browser per aprire l'URL locale.

In questa sessione e' stato rilevato:

- `aspnet_compiler.exe` Framework 4.x presente;
- IIS locale non presente;
- IIS Express non presente;
- Visual Studio/WebForms host non presente;
- `web.config` contiene `EntropicConnectionString`;
- reachability DB non confermata.

## 4. Opzione consigliata: IIS Express

IIS Express e' l'opzione piu' semplice per un test locale reversibile.

Comando indicativo:

```powershell
iisexpress.exe /path:C:\KeepStoreWeb\KeepStore3.0 /port:8085
```

Note operative:

- usare una porta locale non privilegiata, ad esempio `8085`;
- adattare solo il path se il repository si trova altrove;
- non modificare `web.config` per il solo test;
- non fare deploy live;
- non esporre il binding verso IP pubblici;
- chiudere il processo IIS Express dopo il test.

URL atteso dopo l'avvio:

```text
http://localhost:8085/
```

## 5. Opzione alternativa: IIS locale

Se si usa IIS locale:

- creare un sito o'applicazione locale puntata alla root del repository;
- usare un application pool .NET Framework 4.x;
- verificare se la pipeline richiesta e' Integrated o Classic;
- registrare/abilitare ASP.NET 4.x se necessario;
- usare binding solo locale, per esempio `localhost:8085`;
- evitare binding pubblici o LAN se non strettamente controllati;
- non modificare configurazioni globali permanenti senza task dedicato;
- non usare il sito locale come deploy/staging pubblico.

La configurazione IIS locale deve restare reversibile e separata dal live.

## 6. DB e configurazione

La pagina prodotto richiede accesso DB tramite `web.config`.

Regole:

- non stampare o copiare la connection string completa in issue, PR, log o documenti;
- non riportare password, utenti, host o altri segreti;
- verificare solo la presenza della configurazione e la reachability del DB;
- se il DB non e' raggiungibile, la preview non potra' caricare dati reali;
- non usare DB produzione per test che scrivono dati;
- nei test PDP non cliccare add-to-cart, non creare carrelli, ordini o pagamenti.

Per FRONT-PDP-6/7 la preview locale non e' stata testata perche' mancava un host WebForms locale. La connection string e' presente, ma la reachability DB non e' stata confermata.

## 7. URL di test

Prodotto standard:

```text
http://localhost:8085/articolo.aspx?id=20871&ksProductDetailPreview=1
```

Prodotto ricondizionato:

```text
http://localhost:8085/articolo.aspx?TCid=-1&id=18598&ksProductDetailPreview=1
```

Controllo negativo live:

```text
https://www.taikun.it/articolo.aspx?id=20871&ksProductDetailPreview=1
```

Il controllo live deve mostrare la pagina reale senza marker della preview.

## 8. Checklist test locale

Aprire gli URL locali con browser e verificare:

- la pagina carica senza errore server;
- la UI reale e' ancora presente secondo il comportamento previsto;
- la preview e' visibile localmente;
- nome prodotto coerente;
- codice ed EAN coerenti, se presenti;
- brand e categoria coerenti;
- immagine principale presente;
- gallery valorizzata o fallback coerente;
- prezzo, IVA e promo coerenti;
- disponibilita coerente;
- badge ricondizionato visibile sul prodotto ricondizionato;
- path badge ricondizionato: `/Public/assets/images/img/refurbished.png`;
- descrizioni presenti;
- varianti summary presente se applicabile;
- add-to-cart preview non operativo;
- nessun carrello modificato;
- nessun ordine creato;
- nessun pagamento eseguito.

Non cliccare il pulsante add-to-cart reale durante il test preview.

## 9. Checklist live negativo

Aprire:

```text
https://www.taikun.it/articolo.aspx?id=20871&ksProductDetailPreview=1
```

Verificare:

- status HTTP 200;
- pagina reale visibile;
- preview non visibile;
- marker `Preview nuova scheda prodotto` assente;
- nessun errore server;
- nessun errore compilazione WebForms;
- nessun carrello, ordine o pagamento.

Se la preview compare sul dominio pubblico, il gate e' rotto e va aperto un fix immediato prima di qualunque altro lavoro PDP.

## 10. Troubleshooting

Problemi comuni:

- IIS Express non installato: installare o usare una macchina con Visual Studio/IIS Express.
- IIS locale assente: abilitare IIS e ASP.NET 4.x in modo controllato.
- ASP.NET 4.x non registrato: verificare registrazione/moduli ASP.NET prima di avviare il sito.
- Porta occupata: scegliere un'altra porta locale, per esempio `8086`.
- DB non raggiungibile: la pagina puo' fallire prima di mostrare la preview; verificare rete, firewall e credenziali senza esporre segreti.
- Permessi `App_Data` o cartelle temporanee: concedere solo permessi minimi necessari all'utente/app pool locale.
- Errore compilazione WebForms: eseguire `aspnet_compiler.exe` per isolare errori di compilazione.
- `Request.IsLocal` falso: usare `localhost` o `127.0.0.1`, non dominio pubblico o IP remoto.
- Immagini prodotto non raggiungibili: verificare path asset e fallback, senza versionare immagini prodotto in Git.

## 11. Guardrail

Durante setup e test:

- non abilitare la preview sul live;
- non rimuovere `Request.IsLocal`;
- non sostituire `pnlProduct`;
- non cliccare add-to-cart nei test preview;
- non modificare checkout o carrello;
- non creare ordini;
- non eseguire pagamenti;
- non stampare segreti;
- non versionare asset prodotto sotto `Public/assets/images/articoli/`;
- mantenere rollback rapido;
- tenere ogni cambio futuro gated, reversibile e separato dalla UI reale.

## 12. Prossimi step

Dopo setup locale:

- `FRONT-PDP-9 - Run local ProductDetailView preview browser test`

Se il setup locale non e' disponibile:

- usare una macchina dedicata con IIS Express/IIS;
- oppure usare uno staging non pubblico con binding locale/privato e DB controllato;
- documentare il setup effettivo prima di lavorare sui gap visuali.

Solo dopo un test preview reale con dati e' opportuno aprire task sui gap visuali di `ProductDetailView`.
