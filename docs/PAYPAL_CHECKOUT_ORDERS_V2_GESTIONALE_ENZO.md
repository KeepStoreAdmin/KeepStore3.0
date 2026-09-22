# PayPal Checkout - Impostazioni Azienda

## Scopo

Contratto per la nuova schermata gestionale che sostituisce integralmente la UI PayPal Express. Il sorgente desktop non è in questo repository: questo documento specifica dati, query, validazioni e comportamento senza inventare modifiche al gestionale.

## Sezione Conto PayPal LIVE

Campi visibili:

- Nome profilo;
- Tecnologia: `PayPal Checkout - Orders API v2`;
- Profilo credenziali server: chiave logica, inizialmente `PAYPAL_MAIN`;
- Merchant ID, eventualmente mascherato fuori dalla modalità amministrativa;
- Credenziali API: `Configurate` / `Non configurate`, senza mostrare Client ID completo o Client Secret;
- Webhook: `Configurato` / `Non configurato`;
- Stato attivo/inattivo;
- Ambiente fisso: `LIVE`;
- Ultima verifica e relativo esito sanitizzato;
- pulsante `Verifica ora`.

La tabella autorevole è `paypal_checkout_account`. Insert e update possono modificare solo `NomeProfilo`, `CredentialKey`, `MerchantId`, `Attivo` e `Note`. `CredentialKey` deve rispettare `^[A-Z][A-Z0-9_]{2,63}$` ed essere univoca. Nessun segreto API viene letto o scritto dal gestionale.

`Verifica ora` deve verificare struttura e presenza della configurazione deploy tramite un endpoint amministrativo futuro autenticato e auditato; non deve restituire i valori, creare ordini, acquisire pagamenti o diventare un test LIVE implicito.

## Sezione Aziende collegate

Colonne:

- Azienda;
- Tipo pagamento;
- Email PayPal;
- Brand checkout;
- Valuta;
- Attivo.

Configurazione approvata:

| Azienda | Email PayPal | Brand checkout | Valuta |
| --- | --- | --- | --- |
| TAIKUN | `info@taikun.it` | `TAIKUN` | `EUR` |
| WEBAFFARE | `info@webaffare.it` | `WEBAFFARE` | `EUR` |

Entrambe le righe puntano allo stesso `PayPalAccountId`, ma restano distinte per `AziendeId + PagamentiTipoId`. Il gestionale legge `aziende`, `pagamentitipo`, `paypal_checkout_account` e `paypal_checkout_azienda`; non deduce aziende compatibili e non copia configurazioni fra tenant.

Insert/update richiedono azienda esistente, tipo pagamento con `OnLine=2`, account attivo, email valida, brand non vuoto, valuta ISO a tre lettere e unicità della coppia azienda/pagamento. Un errore mostra un messaggio operativo senza query, credenziali o dati tecnici sensibili.

Pulsanti previsti: `Nuovo collegamento`, `Salva`, `Disattiva`, `Annulla`, `Verifica configurazione`. La disattivazione è logica; la cancellazione è vietata quando esistono transazioni.

## Regole vincolanti

- Nessuna seconda schermata Express, NVP/SOAP, password API o signature legacy.
- Nessun Client Secret visibile, copiabile, esportabile o persistito nel database.
- Nessun fallback globale o cross-tenant.
- `AccountPaypal` storico non alimenta il runtime Orders v2.
- La schermata può dichiarare `Configurata` solo dopo migration, impostazioni deploy e verify; non può dichiarare `LIVE VERIFIED` senza smoke reale separatamente autorizzato.
