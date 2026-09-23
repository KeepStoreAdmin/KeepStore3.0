# PayPal Checkout Orders API v2 - manuale gestionale Enzo

## 1. Scopo

Questa e la specifica operativa per aggiornare il gestionale desktop KeepStore alla nuova integrazione PayPal Checkout Orders API v2 REST LIVE. Sostituisce integralmente la vecchia gestione PayPal Express/NVP-SOAP nel pannello gestionale.

Il gestionale deve rimanere generico e multi-cliente: nessun nome database, dominio, AziendeId, PagamentiTipoId, account PayPal, Merchant ID, Client ID, Client Secret, Webhook ID, payee email o brand deve essere hardcoded nel sorgente desktop.

Lo stesso eseguibile deve funzionare per installazioni KeepStore con database differenti, una o piu aziende per database e uno o piu account PayPal, cambiando esclusivamente dati e configurazione autorizzata.

## 2. Architettura dati autorevole

### 2.1 Tabella paypal_checkout_account

Un record identifica un account PayPal REST utilizzabile da una o piu aziende.

Campi gestiti:
- Id: chiave tecnica, sola lettura in edit.
- NomeProfilo: nome descrittivo.
- CredentialKey: chiave logica univoca; pattern ^[A-Z][A-Z0-9_]{2,63}$.
- MerchantId: Merchant ID PayPal.
- ClientId: Client ID della REST app LIVE.
- ClientSecret: segreto API riservato.
- WebhookId: ID del webhook REST della stessa app.
- Attivo: 0/1.
- Note: note amministrative non sensibili.
- CreatedAt, UpdatedAt: sola lettura.

Regola Client Secret: il valore esistente non deve mai essere caricato in chiaro in un controllo UI, log, export, report o clipboard automatica. In modifica il campo password appare vuoto; vuoto significa non sostituire il segreto esistente. La sostituzione richiede un'azione esplicita dell'operatore.

### 2.2 Tabella paypal_checkout_azienda

Un record collega l'esatta coppia azienda/metodo di pagamento a un account PayPal.

Campi:
- Id
- AziendeId
- PagamentiTipoId
- PayPalAccountId
- PayeeEmail
- BrandName
- CurrencyCode
- Attivo
- Note

Vincolo funzionale: una configurazione appartiene alla coppia AziendeId + PagamentiTipoId. Il gestionale non deve ereditare automaticamente configurazioni di un'altra azienda.

### 2.3 Tabelle operative da non modificare manualmente

- paypal_checkout_transazioni
- paypal_checkout_eventi

Queste tabelle appartengono al runtime web. Il gestionale puo eventualmente mostrarle in diagnostica read-only, ma non deve creare, correggere o cancellare righe.

## 3. Nuova schermata: PayPal Checkout - Impostazioni Azienda

La vecchia schermata PayPal Express deve essere sostituita, non affiancata.

### 3.1 Intestazione

Mostrare:
- Tecnologia: PayPal Checkout - Orders API v2
- Ambiente: LIVE
- Stato account: Attivo/Inattivo
- Stato credenziali: Configurate/Incomplete
- Stato webhook: Configurato/Non configurato

Non mostrare riferimenti NVP/SOAP, API Username, API Password, Signature, Sandbox o IPN legacy.

### 3.2 Sezione Conto PayPal

Controlli previsti:
1. Nome profilo
2. Credential Key
3. Merchant ID
4. Client ID
5. Client Secret - PasswordBox write-only
6. Webhook ID
7. Note
8. CheckBox Attivo
9. Stato sintetico credenziali
10. Stato sintetico webhook

Pulsanti:
- Nuovo
- Salva
- Sostituisci Client Secret
- Disattiva
- Annulla
- Verifica configurazione

Verifica configurazione deve essere read-only: controlla presenza/validita strutturale del profilo e dei mapping senza creare ordini o acquisire pagamenti.

### 3.3 Sezione Aziende collegate

Griglia:
- Azienda
- Metodo pagamento
- Account PayPal
- Payee email
- Brand checkout
- Valuta
- Attivo

Pulsanti: Nuovo collegamento, Salva, Disattiva, Annulla, Verifica configurazione.

Non cancellare fisicamente un mapping gia referenziato da transazioni. Preferire disattivazione logica.

## 4. Mockup funzionale

+----------------------------------------------------------------------------------+
| PayPal Checkout - Impostazioni Azienda                         Ambiente: LIVE     |
+----------------------------------------------------------------------------------+
| CONTO PAYPAL                                                                     |
| Nome profilo     [___________________________________________]                    |
| Credential Key   [________________________]  Stato: [ATTIVO / INATTIVO]           |
| Merchant ID      [___________________________________________]                    |
| Client ID        [___________________________________________]                    |
| Client Secret    [***********************] [Sostituisci secret]                   |
| Webhook ID       [___________________________________________]                    |
| Note             [___________________________________________]                    |
| Credenziali: [CONFIGURATE]      Webhook: [CONFIGURATO]                            |
| [Nuovo] [Salva] [Disattiva] [Annulla] [Verifica configurazione]                  |
+----------------------------------------------------------------------------------+
| AZIENDE COLLEGATE                                                                |
| Azienda | Metodo | Account | Payee email | Brand | Valuta | Attivo               |
| ... dati letti dal database ...                                                  |
| [Nuovo collegamento] [Salva] [Disattiva] [Annulla] [Verifica]                   |
+----------------------------------------------------------------------------------+

## 5. Letture SQL consigliate

### 5.1 Elenco account senza esporre il Client Secret

SELECT
    Id,
    NomeProfilo,
    CredentialKey,
    MerchantId,
    ClientId,
    WebhookId,
    Attivo,
    Note,
    CreatedAt,
    UpdatedAt,
    CASE WHEN ClientSecret IS NULL OR ClientSecret='' THEN 0 ELSE 1 END AS ClientSecretConfigurato
FROM paypal_checkout_account
ORDER BY NomeProfilo, Id;

Il gestionale non deve selezionare ClientSecret per popolare la UI.

### 5.2 Mapping aziende

SELECT
    c.Id,
    c.AziendeId,
    c.PagamentiTipoId,
    c.PayPalAccountId,
    c.PayeeEmail,
    c.BrandName,
    c.CurrencyCode,
    c.Attivo,
    c.Note
FROM paypal_checkout_azienda c
ORDER BY c.AziendeId, c.PagamentiTipoId;

## 6. Scritture SQL - sempre parametrizzate

### 6.1 Inserimento nuovo account

INSERT INTO paypal_checkout_account
    (NomeProfilo, CredentialKey, MerchantId, ClientId, ClientSecret, WebhookId, Attivo, Note)
VALUES
    (@NomeProfilo, @CredentialKey, @MerchantId, @ClientId, @ClientSecret, @WebhookId, @Attivo, @Note);

### 6.2 Aggiornamento account senza cambiare secret

UPDATE paypal_checkout_account
SET NomeProfilo=@NomeProfilo,
    CredentialKey=@CredentialKey,
    MerchantId=@MerchantId,
    ClientId=@ClientId,
    WebhookId=@WebhookId,
    Attivo=@Attivo,
    Note=@Note
WHERE Id=@Id;

### 6.3 Sostituzione esplicita Client Secret

Eseguire solo dopo comando esplicito Sostituisci Client Secret:

UPDATE paypal_checkout_account
SET ClientSecret=@ClientSecret
WHERE Id=@Id;

Mai trasformare un campo UI vuoto in ClientSecret=''.

### 6.4 Inserimento mapping azienda

INSERT INTO paypal_checkout_azienda
    (AziendeId, PagamentiTipoId, PayPalAccountId, PayeeEmail, BrandName, CurrencyCode, Attivo, Note)
VALUES
    (@AziendeId, @PagamentiTipoId, @PayPalAccountId, @PayeeEmail, @BrandName, UPPER(@CurrencyCode), @Attivo, @Note);

### 6.5 Aggiornamento mapping

UPDATE paypal_checkout_azienda
SET PayPalAccountId=@PayPalAccountId,
    PayeeEmail=@PayeeEmail,
    BrandName=@BrandName,
    CurrencyCode=UPPER(@CurrencyCode),
    Attivo=@Attivo,
    Note=@Note
WHERE Id=@Id
  AND AziendeId=@AziendeId
  AND PagamentiTipoId=@PagamentiTipoId;

## 7. Validazioni obbligatorie

Prima di salvare un account:
- NomeProfilo non vuoto.
- CredentialKey valida e univoca.
- MerchantId, ClientId, ClientSecret presenti per rendere l'account operativo.
- WebhookId presente per dichiarare il webhook configurato.
- nessun segreto scritto in log/error message.

Prima di salvare un mapping:
- azienda esistente;
- PagamentiTipoId appartenente alla stessa azienda;
- pagamentitipo.OnLine=2;
- account PayPal esistente;
- email formalmente valida;
- BrandName non vuoto;
- CurrencyCode di tre lettere;
- unicita di AziendeId + PagamentiTipoId.

Un account puo essere condiviso da piu aziende. Aziende diverse possono anche usare account diversi.

## 8. Webhook REST

Per ogni REST app LIVE va registrato un webhook verso il listener HTTPS previsto dall'installazione.

Set eventi supportato dal runtime KeepStore:
1. CHECKOUT.ORDER.APPROVED
2. CHECKOUT.PAYMENT-APPROVAL.REVERSED
3. PAYMENT.CAPTURE.PENDING
4. PAYMENT.CAPTURE.COMPLETED
5. PAYMENT.CAPTURE.DENIED

Se la Dashboard PayPal non espone uno degli eventi, la gestione puo essere completata con la Webhooks Management API REST. Il WebhookId restituito va salvato nell'account DB corretto.

Il gestionale non deve usare la pagina/app legacy NVP SOAP Webhooks.

## 9. Ordine interno con pagamento remoto

### 9.1 Nuovo requisito obbligatorio

Quando il gestionale crea manualmente un nuovo ordine che deve poter essere pagato successivamente dal cliente, deve salvare:

documenti.OrigineOrdine = 'INTERNO'

nello stesso salvataggio/transazione che crea il documento.

Non eseguire backfill dei documenti storici.

Non impostare INTERNO per ordini importati da Amazon, eBay o altri canali. Se la provenienza non e autorevole, lasciare NULL oppure il valore di canale previsto dal relativo contratto.

### 9.2 Prerequisiti ordine interno

- cliente collegato all'account web della medesima azienda;
- documento di tipo ordine idoneo al web;
- documenti.Pagato=0;
- totale positivo;
- metodo della stessa azienda;
- PayPal: pagamentitipo.OnLine=2;
- Banca Sella: pagamentitipo.OnLine=3;
- PermettiPagamentoSuccessivo=1;
- per PayPal, account e mapping Orders v2 completi e attivi.

### 9.3 Query di verifica

SELECT d.Id, d.AziendeId, d.UtentiId, d.TipoDocumentiId,
       d.OrigineOrdine, d.PagamentiTipoId, d.Pagato,
       d.StatoPagamentoWeb, d.StatiId,
       td.Web, td.Abilitato, td.ImpegnaQnt,
       p.OnLine, p.PermettiPagamentoSuccessivo,
       pie.TotaleDocumento
FROM documenti d
JOIN tipodocumenti td ON td.Id=d.TipoDocumentiId
JOIN pagamentitipo p ON p.Id=d.PagamentiTipoId
JOIN documentipie pie ON pie.DocumentiId=d.Id
WHERE d.Id=@DocumentiId
  AND d.AziendeId=@AziendeId;

Il sito abilita il pagamento successivo solo quando la provenienza autorevole e INTERNO. WEB, NULL, AMAZON, EBAY o valori sconosciuti non devono essere trattati come ordine interno.

## 10. Stato pagamento

Il gestionale non deve impostare un ordine come pagato sulla base di:
- creazione PayPal Order;
- approvazione browser;
- redirect di ritorno;
- presenza di un PayPal Order ID.

Solo una capture PayPal COMPLETED verificata dal runtime web puo produrre:
- documenti.Pagato=1;
- documenti.StatoPagamentoWeb=2;
- marker TXN:<CaptureId>.

## 11. Procedura di onboarding di un nuovo cliente

1. Applicare le migration KeepStore approvate al database del cliente.
2. Creare la REST app PayPal LIVE del cliente.
3. Inserire un record paypal_checkout_account.
4. Registrare il webhook REST con i cinque eventi previsti.
5. Salvare il relativo WebhookId.
6. Creare uno o piu mapping paypal_checkout_azienda.
7. Verificare che i metodi PayPal abbiano OnLine=2.
8. Abilitare account, mapping e metodo solo dopo configurazione completa.
9. Verificare isolamento tra aziende quando il DB contiene piu storefront.
10. Non modificare sorgente, stored procedure o web.config per valori PayPal specifici del cliente.

## 12. Configurazione corrente di riferimento

| Azienda | Payee email | Brand | Valuta | Account |
| --- | --- | --- | --- | --- |
| TAIKUN | info@taikun.it | TAIKUN | EUR | condiviso |
| WEBAFFARE | paypal@webaffare.it | WEBAFFARE | EUR | condiviso |

Questi sono dati della specifica installazione, non valori da hardcodare nel gestionale.

## 13. Cosa rimuovere dal vecchio gestionale

Non usare piu come configurazione runtime PayPal Orders v2:
- Express Checkout;
- NVP/SOAP;
- API Username;
- API Password legacy;
- Signature;
- EC-TOKEN;
- IPN legacy;
- Sandbox runtime;
- vecchie tabelle PayPal Express rimosse dalla migration.

La colonna storica aziende.AccountPaypal non alimenta il runtime web Orders v2.

## 14. Collaudo Enzo

Test account:
- nuovo account valido;
- modifica account senza sostituire il secret;
- sostituzione esplicita del secret;
- CredentialKey duplicata rifiutata;
- account incompleto non dichiarato configurato.

Test mapping:
- stessa azienda/metodo duplicato rifiutato;
- due aziende sullo stesso account;
- due aziende su account differenti;
- metodo non OnLine=2 rifiutato;
- mapping disattivato non operativo.

Test ordine interno:
- nuovo ordine manuale: OrigineOrdine='INTERNO';
- ordine web esistente: non sovrascritto;
- Amazon/eBay: non convertiti in INTERNO;
- cliente/azienda errati: nessun pagamento successivo;
- ordine gia pagato: nessun nuovo pagamento.

## 15. Criteri di accettazione

Il lavoro Enzo e accettabile solo se:
- nessun valore cliente e hardcoded;
- nessuna credenziale PayPal e richiesta nel web.config;
- Client Secret non compare in UI/log/export;
- account e mapping sono gestibili dal DB;
- schermata legacy Express non e piu la configurazione autorevole;
- ordine interno scrive OrigineOrdine='INTERNO' nella creazione;
- nessuna modifica manuale alle tabelle transazioni/eventi;
- due tenant sintetici possono usare configurazioni distinte senza contaminazione.
