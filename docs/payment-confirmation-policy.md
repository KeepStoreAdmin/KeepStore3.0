# Payment confirmation policy

## 1. Scopo

Questo documento definisce la policy proposta per la gestione parametrica degli ordini con pagamento online. L'obiettivo e' separare in modo esplicito la conferma dell'ordine dall'esito del pagamento, lasciando configurabile il comportamento per ogni modalita' di pagamento.

Il documento e' solo una proposta tecnica e funzionale. Non introduce modifiche al codice applicativo, al database o alle stored procedure.

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
- ordine non confermato finche' il pagamento online non risulta riuscito.

La policy deve essere configurabile per metodo di pagamento, senza affidarsi a regole implicite basate solo sulla descrizione o sul gateway.

## 6. Campo DB proposto

Campo proposto su `pagamentitipo`:

`PoliticaConfermaOrdineOnline`

Valori proposti:

- `0` = conferma ordine subito, comportamento attuale;
- `1` = crea ordine in attesa pagamento, abilita "Paga ora";
- `2` = non confermare ordine finche' il pagamento non riuscito.

Questa e' solo una proposta di design. Nessuna migrazione e' stata eseguita.

## 7. Matrice comportamenti

| Metodo pagamento | Crea ordine subito | Invia email subito | Svuota carrello | Stato iniziale ordine | `Pagato` | "Paga ora" | Se pagamento fallisce |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bonifico/manuale | Si | Si | Si | Confermato/manuale | `0` o gestione manuale | No | Non applicabile |
| Contrassegno | Si | Si | Si | Confermato/manuale | `0` o gestione manuale | No | Non applicabile |
| Carta policy `0` | Si | Si | Si | Confermato | `0` fino a OK gateway | Si | Ordine resta creato e pagabile da My Account |
| Carta policy `1` | Si | No, oppure email "in attesa pagamento" | Si | In attesa pagamento | `0` | Si | Ordine resta in attesa e pagabile da My Account |
| Carta policy `2` | No, oppure bozza tecnica non evadibile | No | No, salvo scelta esplicita | Non confermato | `0` | No | Utente torna al checkout/carrello recuperabile |
| PayPal policy `0` | Si | Si | Si | Confermato | `0` fino a OK gateway | Si | Ordine resta creato e pagabile da My Account |
| PayPal policy `1` | Si | No, oppure email "in attesa pagamento" | Si | In attesa pagamento | `0` | Si | Ordine resta in attesa e pagabile da My Account |
| PayPal policy `2` | No, oppure bozza tecnica non evadibile | No | No, salvo scelta esplicita | Non confermato | `0` | No | Utente torna al checkout/carrello recuperabile |

## 8. Stati ordine/pagamento suggeriti

Stati logici da formalizzare prima di modifiche applicative:

- confermato/manuale;
- in attesa pagamento;
- pagamento fallito;
- pagato;
- annullato;
- confermato manualmente.

Questi stati possono essere mappati su campi esistenti o su nuove configurazioni, ma la mappatura va definita in un task dedicato prima di qualsiasi migrazione o modifica codice.

## 9. My Account / Paga ora

"Paga ora" deve comparire solo per ordini online:

- non pagati;
- non annullati;
- senza autorizzazione pagamento gia' registrata;
- configurati per consentire pagamento successivo.

Il flusso deve funzionare sia per ordini creati dal checkout sia per ordini creati da gestionale. Deve rigenerare il gateway in sicurezza usando l'id documento lato server e deve evitare doppi pagamenti se `Pagato=1` o se esiste gia' un'autorizzazione valida.

## 10. Gateway

Punti da verificare nei task successivi:

- callback BancaSella con esito OK;
- callback BancaSella con esito KO;
- flusso PayPal completo;
- retry pagamento da My Account;
- passaggio sicuro dell'id documento;
- tracciamento transazione;
- aggiornamento di `Pagato`;
- email pagamento riuscito;
- email pagamento fallito o ordine in attesa.

## 11. Roadmap proposta

- PAY-3: proposta migrazione DB per la policy pagamento.
- PAY-4: adattamento checkout/ordine alla policy.
- PAY-5: verifica e correzione My Account "Paga ora".
- PAY-6: test gateway BancaSella/PayPal.
- PAY-7: policy email ordine/pagamento.

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
