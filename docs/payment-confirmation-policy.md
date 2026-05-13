# Payment confirmation policy

## 1. Scopo

Questo documento definisce la policy proposta per la gestione parametrica degli ordini con pagamento online. L'obiettivo e' separare in modo esplicito la conferma dell'ordine dall'esito del pagamento, lasciando configurabile il comportamento per ogni modalita' di pagamento.

Il documento e' solo una proposta tecnica e funzionale. PAY-2 non introduce modifiche al codice applicativo, al database o alle stored procedure. Il database operativo e' gia' stato aggiornato manualmente con i campi descritti in questo documento; i task successivi dovranno leggere i campi reali.

## 2. Stato attuale

Nel flusso attuale l'ordine viene creato prima del completamento del pagamento online.

- `Carrello_Documento` crea il documento e svuota il carrello.
- L'email ordine viene inviata prima dell'esito del gateway.
- BancaSella aggiorna `documenti.Pagato=1` solo quando riceve un esito positivo.
- Se il pagamento carta o PayPal fallisce, l'ordine resta comunque creato e visibile.
- PayPal richiede una verifica dedicata del flusso completo.
- My Account e dettaglio documento prevedono gia' il concetto di "Paga ora".

Questo comportamento puo' essere utile quando si vuole permettere all'utente di pagare successivamente dal My Account, ma non e' adatto ai casi in cui l'ordine non deve essere confermato finche' il pagamento online non va a buon fine.

## 3. Flusso attuale sintetico

1. `carrello.aspx`
2. `btInviaOrdine_Click`
3. `SendOrder`
4. valorizzazione `Session("Ordine_*")`
5. redirect verso `ordine.aspx`
6. chiamata a `Carrello_Documento`
7. creazione documento, righe e piede documento
8. svuotamento carrello
9. invio email ordine
10. redirect a gateway pagamento oppure a dettaglio documento
11. eventuale callback pagamento

## 4. Rischi attuali

- Ordine potenzialmente evadibile anche se non pagato.
- Email ordine inviata prima del pagamento.
- Carrello svuotato troppo presto per una policy bloccante.
- Retry pagamento non completamente validato.
- Rischio di doppio pagamento o doppio ordine nei retry non controllati.
- PayPal risulta meno chiaro di BancaSella e richiede verifica dedicata.
- Il gestionale puo' creare ordini online da far pagare successivamente.

## 5. Obiettivo funzionale

Definire un comportamento parametrico per ogni modalita' di pagamento:

- ordine immediato anche se non pagato;
- ordine creato in attesa pagamento con possibilita' di "Paga ora";
- ordine non confermato finche' il pagamento online non risulta riuscito;
- invio email ordine configurabile rispetto all'esito del pagamento.

La policy deve essere configurabile per metodo di pagamento, senza affidarsi a regole implicite basate solo sulla descrizione o sul gateway.

## 6. Campi DB gia' creati

I campi seguenti risultano gia' creati sul database operativo. Il file SQL aggiornato non e' ancora stato fornito al repository; appena disponibile, andra' aggiornato e allineato in un task separato.

### 6.1 `pagamentitipo`

| Campo | Tipo | Default | Valori ammessi | Significato operativo |
| --- | --- | --- | --- | --- |
| `ConfermaOrdinePrimaPagamento` | `TINYINT(1) NOT NULL` | `1` | `0`, `1` | `1` crea/conferma ordine prima del pagamento; `0` mantiene l'ordine in attesa finche' il pagamento non risulta riuscito. |
| `PermettiPagamentoSuccessivo` | `TINYINT(1) NOT NULL` | `1` | `0`, `1` | `1` mostra/consente "Paga ora" da My Account se l'ordine online non e' pagato; `0` non consente pagamento successivo. |
| `InviaEmailOrdinePrimaPagamento` | `TINYINT(1) NOT NULL` | `1` | `0`, `1` | `1` invia email ordine subito; `0` rinvia l'email di conferma fino a pagamento riuscito o a una policy email dedicata. |

### 6.2 `documenti`

| Campo | Tipo | Default | Valori ammessi | Significato operativo |
| --- | --- | --- | --- | --- |
| `StatoPagamentoWeb` | `TINYINT NOT NULL` | `0` | `0`, `1`, `2`, `3`, `4`, `5` | Stato logico del pagamento web associato al documento. |
| `DataStatoPagamentoWeb` | `DATETIME` | `NULL` | data/ora o `NULL` | Data ultimo aggiornamento dello stato pagamento web. |
| `UltimoEsitoPagamentoWeb` | `VARCHAR(255)` UTF-8 | `NULL` | testo esito o `NULL` | Ultimo esito tecnico/funzionale ricevuto dal gateway o dal flusso pagamento. |

Valori di `documenti.StatoPagamentoWeb`:

- `0` = non richiesto/non online;
- `1` = in attesa pagamento;
- `2` = pagato;
- `3` = fallito;
- `4` = annullato;
- `5` = pagamento successivo disponibile.

## 7. Matrice comportamenti

| Metodo pagamento | `ConfermaOrdinePrimaPagamento` | `PermettiPagamentoSuccessivo` | `InviaEmailOrdinePrimaPagamento` | Crea ordine subito | Stato iniziale ordine | `StatoPagamentoWeb` | "Paga ora" | Se pagamento fallisce |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bonifico/manuale | `1` | `0` o `1` secondo scelta gestionale | `1` | Si | Confermato/manuale | `0` | Di norma no, salvo scelta gestionale | Non applicabile |
| Contrassegno | `1` | `0` | `1` | Si | Confermato/manuale | `0` | No | Non applicabile |
| Carta comportamento attuale | `1` | `1` | `1` | Si | Confermato | `1` fino a OK gateway, poi `2` | Si se non pagato | Ordine resta creato e pagabile da My Account |
| PayPal comportamento attuale | `1` | `1` | `1` | Si | Confermato | `1` fino a OK gateway, poi `2` | Si se non pagato | Ordine resta creato e pagabile da My Account |
| Carta in attesa pagamento | `1` | `1` | `0` | Si | In attesa pagamento | `1` o `5` | Si | Ordine resta in attesa e pagabile da My Account |
| PayPal in attesa pagamento | `1` | `1` | `0` | Si | In attesa pagamento | `1` o `5` | Si | Ordine resta in attesa e pagabile da My Account |
| Carta bloccante | `0` | `0` | `0` | No, salvo bozza tecnica non evadibile | Non confermato | `1`, `3` o `4` secondo esito | No | Utente torna al checkout/carrello recuperabile |
| PayPal bloccante | `0` | `0` | `0` | No, salvo bozza tecnica non evadibile | Non confermato | `1`, `3` o `4` secondo esito | No | Utente torna al checkout/carrello recuperabile |

## 8. Stati ordine/pagamento suggeriti

Stati logici da formalizzare prima di modifiche applicative:

- confermato/manuale;
- in attesa pagamento;
- pagamento successivo disponibile;
- pagamento fallito;
- pagato;
- annullato;
- confermato manualmente.

La mappatura applicativa dovra' usare i campi reali `documenti.StatoPagamentoWeb`, `documenti.DataStatoPagamentoWeb` e `documenti.UltimoEsitoPagamentoWeb`, senza introdurre stati impliciti basati solo su testo o descrizione pagamento.

## 9. My Account / Paga ora

"Paga ora" deve comparire solo per ordini online:

- non pagati;
- non annullati;
- senza autorizzazione pagamento gia' registrata;
- con `pagamentitipo.PermettiPagamentoSuccessivo=1`;
- con `documenti.StatoPagamentoWeb` coerente con pagamento in attesa, fallito o successivo disponibile.

Il flusso deve funzionare sia per ordini creati dal checkout sia per ordini creati da gestionale. Deve rigenerare il gateway in sicurezza usando l'id documento lato server e deve evitare doppi pagamenti se `documenti.Pagato=1`, se `StatoPagamentoWeb=2` o se esiste gia' un'autorizzazione valida.

## 10. Gateway

Punti da verificare nei task successivi:

- callback BancaSella con esito OK;
- callback BancaSella con esito KO;
- flusso PayPal completo;
- retry pagamento da My Account;
- passaggio sicuro dell'id documento;
- tracciamento transazione;
- aggiornamento di `documenti.Pagato`;
- aggiornamento di `documenti.StatoPagamentoWeb`;
- aggiornamento di `documenti.DataStatoPagamentoWeb`;
- aggiornamento di `documenti.UltimoEsitoPagamentoWeb`;
- email pagamento riuscito;
- email pagamento fallito o ordine in attesa.

## 11. Roadmap proposta

- PAY-3: audit schema DB aggiornato e allineamento codice-database.
- PAY-4: leggere i nuovi flag in checkout/ordine.
- PAY-5: aggiornare My Account "Paga ora" usando `PermettiPagamentoSuccessivo` e `StatoPagamentoWeb`.
- PAY-6: far aggiornare a BancaSella/PayPal `StatoPagamentoWeb`, `DataStatoPagamentoWeb` e `UltimoEsitoPagamentoWeb`.
- PAY-7: definire policy email ordine/pagamento basata su `InviaEmailOrdinePrimaPagamento`.

## 12. Test obbligatori futuri

- Bonifico.
- Contrassegno.
- Carta pagamento OK.
- Carta pagamento KO.
- PayPal OK.
- PayPal KO.
- Retry "Paga ora".
- Ordine da gestionale con pagamento online.
- Doppio click conferma ordine.
- Refresh ritorno gateway.
- My Account ordine pagato.
- My Account ordine non pagato.
- Verifica `StatoPagamentoWeb` per ordini online.
- Verifica `DataStatoPagamentoWeb` dopo callback gateway.
- Verifica `UltimoEsitoPagamentoWeb` per esiti OK/KO.

## 13. Nota repository e migrazioni

PAY-2 documenta la policy e i campi gia' creati sul database operativo, ma non esegue migrazioni e non modifica dump SQL.

Il file SQL aggiornato non e' ancora stato fornito al repository. Quando sara' disponibile, dovra' essere integrato in un task separato con verifica dedicata, evitando modifiche miste tra schema, codice applicativo e policy documentale.
