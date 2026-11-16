# PayPal Checkout - verifica di sola lettura della configurazione (per il PO e per Enzo)

Scopo: dire, per ogni metodo di pagamento PayPal (`pagamentitipo.OnLine = 2`) del database SELEZIONATO, se la configurazione e completa e perche no. Nasce da PAYPAL-TINYINT-FLAGS-1A (16/11/2026). Testo standard e universale: non nomina database, clienti o domini; non scrive nulla; non mostra MAI il valore di una credenziale (solo se c'e: 1 o 0).

Come si usa (SQLyog o qualunque client MySQL): selezionare il database dell'installazione, incollare il blocco sotto ed eseguirlo. Risultato: una riga per metodo PayPal di ogni azienda.

Come si legge: il carrello offre PayPal solo se `Abilitato = 1`, `Web = 1`, l'importo del carrello rientra in `TettoImporto` e `ConfigurazioneCompleta = SI`. I flag `MappingAttivo` e `AccountAttivo` sono mostrati come numeri salvati: devono valere **esattamente 1** (0 = non attivo; qualunque altro valore, per esempio -1, e anomalo e il programma lo tratta come NON attivo). `TentativiRegistrati` conta i tentativi di pagamento PayPal gia registrati. Il manuale per Enzo resta [PAYPAL_CHECKOUT_ORDERS_V2_GESTIONALE_ENZO](PAYPAL_CHECKOUT_ORDERS_V2_GESTIONALE_ENZO.md).

```sql
-- PAYPAL-CHECKOUT-READINESS-READONLY-1A. Read-only check of the PayPal Checkout configuration of the SELECTED database.
-- Standard and universal: the same text runs on every KeepStore database; it names no database, customer, domain or template.
-- The target is the database the operator has selected (DATABASE()). Nothing is written. Credential VALUES are never read out:
-- only whether each one is present (1) or empty (0). No customer, order, document or personal data is read.
-- One row per payment method of type PayPal (pagamentitipo.OnLine = 2) of every company in the database.
-- How to read it: the cart offers the method only when it is enabled for the web (Abilitato, Web) and every column
-- ConfigurazioneCompleta ... is 1. The flags are shown as the stored numbers (tinyint(1)): 1 = active, 0 = not active.
SELECT p.AziendeID AS AziendaId,
       p.id AS PagamentoId,
       p.Descrizione,
       p.Abilitato,
       p.Web,
       p.CostoMassimo AS TettoImporto,
       c.Id AS MappingId,
       CAST(c.Attivo AS SIGNED) AS MappingAttivo,
       a.Id AS AccountId,
       CAST(a.Attivo AS SIGNED) AS AccountAttivo,
       (a.CredentialKey REGEXP '^[A-Z][A-Z0-9_]{2,63}$') AS ChiaveProfiloValida,
       (a.MerchantId IS NOT NULL AND TRIM(a.MerchantId) <> '') AS MerchantIdPresente,
       (a.ClientId IS NOT NULL AND TRIM(a.ClientId) <> '') AS ClientIdPresente,
       (a.ClientSecret IS NOT NULL AND TRIM(a.ClientSecret) <> '') AS ClientSecretPresente,
       (a.WebhookId IS NOT NULL AND TRIM(a.WebhookId) <> '') AS WebhookIdPresente,
       (c.PayeeEmail IS NOT NULL AND c.PayeeEmail REGEXP '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$') AS PayeeEmailValida,
       (c.BrandName IS NOT NULL AND TRIM(c.BrandName) <> '') AS BrandPresente,
       (c.CurrencyCode REGEXP '^[A-Z]{3}$') AS ValutaValida,
       CASE WHEN c.Id IS NULL THEN 'NO: manca il collegamento azienda/metodo'
            WHEN a.Id IS NULL THEN 'NO: manca l''account PayPal'
            WHEN c.Attivo NOT IN (0, 1) OR a.Attivo NOT IN (0, 1) THEN 'NO: flag Attivo con valore anomalo (deve essere 0 o 1)'
            WHEN c.Attivo <> 1 OR a.Attivo <> 1 THEN 'NO: collegamento o account non attivo'
            WHEN NOT (a.CredentialKey REGEXP '^[A-Z][A-Z0-9_]{2,63}$')
              OR a.MerchantId IS NULL OR TRIM(a.MerchantId) = ''
              OR a.ClientId IS NULL OR TRIM(a.ClientId) = ''
              OR a.ClientSecret IS NULL OR TRIM(a.ClientSecret) = ''
              OR c.PayeeEmail IS NULL OR NOT (c.PayeeEmail REGEXP '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$')
              OR c.BrandName IS NULL OR TRIM(c.BrandName) = ''
              OR NOT (c.CurrencyCode REGEXP '^[A-Z]{3}$') THEN 'NO: dati incompleti'
            ELSE 'SI' END AS ConfigurazioneCompleta,
       (SELECT COUNT(*) FROM paypal_checkout_transazioni t WHERE t.AziendeId = p.AziendeID AND t.PagamentiTipoId = p.id) AS TentativiRegistrati
FROM pagamentitipo p
LEFT JOIN paypal_checkout_azienda c ON c.AziendeId = p.AziendeID AND c.PagamentiTipoId = p.id
LEFT JOIN paypal_checkout_account a ON a.Id = c.PayPalAccountId
WHERE p.OnLine = 2
ORDER BY p.AziendeID, p.id;
```
