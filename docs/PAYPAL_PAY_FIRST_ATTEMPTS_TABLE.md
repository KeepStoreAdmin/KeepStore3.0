# Tabella dei tentativi di pagamento PayPal (fase P2 del pay-first) - script e regole

SOURCE, non applicata a nessun database operativo. Serve alla funzione «l'ordine si salva solo se il pagamento PayPal riesce» ([progetto](PAYPAL_PAY_FIRST_DESIGN.md)): ogni pagamento nasce come **tentativo** PRIMA del documento (nessun numero ordine esiste ancora), con una riga durevole creata prima di qualunque chiamata a PayPal. Gli script sono **standard e universali**: nessun nome di database, di cliente o di dominio, nessun `USE`; lo stesso testo vale per ogni database KeepStore. Li applica il PO su `taikun` (poi il programma di Enzo). I nuovi file `.sql` sono respinti dal controllo dei segreti, per questo gli script stanno in questa pagina; il test li legge da qui (fonte unica).

**Prima di applicare:** esistono `paypal_checkout_account` e `paypal_checkout_azienda` (migrazione 20260922) e MySQL e almeno 8.0.16 (CHECK applicati). Ordine: preflight, forward, verify. Il rollback rifiuta di cancellare la tabella se contiene qualunque riga (anche COMPLETED: e la memoria che impedisce un secondo pagamento della stessa bozza).

## Stati (13) e transizioni dirette
CREATING -> CREATED | FAILED | UNKNOWN. CREATED -> AUTHORIZED | CANCELED | FAILED | UNKNOWN. AUTHORIZED -> DOC_COMMITTED (solo `BindDocument`) | VOIDING | FAILED (solo `RecordAuthorizationLost`) | CAPTURED_ORPHAN | UNKNOWN. VOIDING -> VOIDED | CAPTURED_ORPHAN | UNKNOWN. DOC_COMMITTED -> CAPTURING | COMPLETED (incasso manuale riconciliato) | VOIDING | UNKNOWN. CAPTURING -> COMPLETED | CAPTURE_REFUSED | UNKNOWN. CAPTURE_REFUSED -> COMPLETED | VOIDING. VOIDED, FAILED, CANCELED -> CAPTURED_ORPHAN (incasso tardivo dal pannello PayPal). COMPLETED e CAPTURED_ORPHAN: nessuna uscita. UNKNOWN(precedente) -> il precedente o un suo successore diretto, mai DOC_COMMITTED e mai UNKNOWN. Lo slot «corrente» (un solo tentativo vivo per bozza) si libera solo con FAILED, CANCELED, VOIDED, CAPTURED_ORPHAN.

## Regole di blocco (ordine globale: tentativo -> documenti -> transazioni)
Nessuna transazione tiene una riga del tentativo mentre chiama PayPal. Nella transazione che crea il documento il tentativo si blocca PER PRIMO (`LockForDocument`), poi si inserisce il documento e si lega (`BindDocument`): un doppio invio aspetta prima di prendere `documenti`. Il ritorno del cliente legge senza lock. Le altre transizioni sono UPDATE brevi di una sola riga guardati dallo stato.

## Regole di recupero (eseguite da P3, qui solo classificate da `RecommendedAction`)
CREATING senza ordine PayPal dopo 10 minuti -> FAILED. CREATED fermo da oltre 30 minuti -> si rilegge l'ordine su PayPal, mai CANCELED senza lettura. AUTHORIZED senza documento a bozza scaduta -> VOIDING e annullo. DOC_COMMITTED fermo da oltre 2 minuti -> BeginCapture. CAPTURING fermo da oltre 2 minuti -> si rilegge PayPal e si ripete l'incasso con lo stesso request id (un solo esecutore: `TryClaimCaptureRetry`). VOIDING fermo -> si ripete l'annullo. UNKNOWN -> si rilegge PayPal e si risolve. CAPTURE_REFUSED e CAPTURED_ORPHAN -> riconciliazione manuale.

## preflight

```sql preflight
SELECT 'PREFLIGHT' AS fase,
  IF((SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('paypal_checkout_account','paypal_checkout_azienda'))=2, 'OK', 'FAIL_MANCANO_LE_TABELLE_PAYPAL') AS tabelle_paypal,
  IF((SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi')=0, 'OK', 'FAIL_LA_TABELLA_ESISTE_GIA') AS tabella_nuova,
  IF(@@version REGEXP '^8\\.(0\\.(1[6-9]|[2-9][0-9])|[1-9])' OR @@version REGEXP '^(9|[1-9][0-9])\\.', 'OK', 'FAIL_SERVE_MYSQL_8_0_16') AS versione;
```

## forward

```sql forward
CREATE TABLE `paypal_checkout_tentativi` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `AttemptKey` char(32) NOT NULL,
  `AziendeId` int NOT NULL,
  `LoginId` bigint NOT NULL,
  `UtentiId` bigint NOT NULL,
  `PagamentiTipoId` int NOT NULL,
  `PayPalAccountId` int NOT NULL,
  `DatabaseScopeKey` varchar(128) NOT NULL,
  `DraftRequestId` char(32) NOT NULL,
  `PayloadFingerprint` varchar(128) NOT NULL,
  `DraftExpiresAt` datetime NOT NULL,
  `TentativoNo` int NOT NULL,
  `CurrentSlot` tinyint(1) DEFAULT NULL,
  `Stato` varchar(24) NOT NULL,
  `StatoPrecedente` varchar(24) DEFAULT NULL,
  `Importo` decimal(15,2) NOT NULL,
  `Valuta` char(3) NOT NULL,
  `PayeeEmail` varchar(254) NOT NULL,
  `MerchantId` varchar(128) NOT NULL,
  `CreateRequestId` varchar(80) NOT NULL,
  `AuthorizeRequestId` varchar(80) NOT NULL,
  `CaptureRequestId` varchar(80) NOT NULL,
  `VoidRequestId` varchar(80) NOT NULL,
  `PayPalOrderId` varchar(100) DEFAULT NULL,
  `PayPalAuthorizationId` varchar(100) DEFAULT NULL,
  `PayPalCaptureId` varchar(100) DEFAULT NULL,
  `AuthorizationExpiresAt` datetime DEFAULT NULL,
  `DocumentiId` int DEFAULT NULL,
  `UltimoEsito` varchar(255) DEFAULT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UX_ppt_key` (`AttemptKey`),
  UNIQUE KEY `UX_ppt_draft_attempt` (`AziendeId`,`LoginId`,`DraftRequestId`,`TentativoNo`),
  UNIQUE KEY `UX_ppt_draft_current` (`AziendeId`,`LoginId`,`DraftRequestId`,`CurrentSlot`),
  UNIQUE KEY `UX_ppt_order` (`PayPalOrderId`),
  UNIQUE KEY `UX_ppt_authorization` (`PayPalAuthorizationId`),
  UNIQUE KEY `UX_ppt_capture` (`PayPalCaptureId`),
  UNIQUE KEY `UX_ppt_document` (`DocumentiId`),
  UNIQUE KEY `UX_ppt_create_request` (`CreateRequestId`),
  UNIQUE KEY `UX_ppt_authorize_request` (`AuthorizeRequestId`),
  UNIQUE KEY `UX_ppt_capture_request` (`CaptureRequestId`),
  UNIQUE KEY `UX_ppt_void_request` (`VoidRequestId`),
  KEY `IX_ppt_stato` (`Stato`,`UpdatedAt`),
  KEY `IX_ppt_owner` (`AziendeId`,`LoginId`),
  CONSTRAINT `FK_ppt_company` FOREIGN KEY (`AziendeId`,`PagamentiTipoId`) REFERENCES `paypal_checkout_azienda` (`AziendeId`,`PagamentiTipoId`),
  CONSTRAINT `FK_ppt_account` FOREIGN KEY (`PayPalAccountId`) REFERENCES `paypal_checkout_account` (`Id`),
  CONSTRAINT `CK_ppt_stato` CHECK (`Stato` IN ('CREATING','CREATED','AUTHORIZED','VOIDING','DOC_COMMITTED','CAPTURING','COMPLETED','CAPTURE_REFUSED','VOIDED','FAILED','CANCELED','CAPTURED_ORPHAN','UNKNOWN')),
  CONSTRAINT `CK_ppt_slot` CHECK ((`Stato` IN ('FAILED','CANCELED','VOIDED','CAPTURED_ORPHAN') AND `CurrentSlot` IS NULL) OR (`Stato` NOT IN ('FAILED','CANCELED','VOIDED','CAPTURED_ORPHAN') AND COALESCE(`CurrentSlot`,0)=1)),
  CONSTRAINT `CK_ppt_previous` CHECK ((`Stato`='UNKNOWN' AND COALESCE(`StatoPrecedente`,'') IN ('CREATING','CREATED','AUTHORIZED','VOIDING','DOC_COMMITTED','CAPTURING')) OR (`Stato`<>'UNKNOWN' AND `StatoPrecedente` IS NULL)),
  CONSTRAINT `CK_ppt_amount` CHECK (`Importo` > 0),
  CONSTRAINT `CK_ppt_currency` CHECK (`Valuta` REGEXP '^[A-Z]{3}$'),
  CONSTRAINT `CK_ppt_number` CHECK (`TentativoNo` > 0),
  CONSTRAINT `CK_ppt_outcome` CHECK (`UltimoEsito` IS NULL OR `UltimoEsito` REGEXP '^[A-Z0-9_:. -]{0,255}$'),
  CONSTRAINT `CK_ppt_key` CHECK (`AttemptKey` REGEXP '^[0-9a-f]{32}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## verify

```sql verify
SELECT 'VERIFY' AS fase,
  IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi')=31, 'OK', 'FAIL_COLONNE') AS colonne,
  IF((SELECT COUNT(DISTINCT INDEX_NAME) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi' AND NON_UNIQUE=0 AND INDEX_NAME<>'PRIMARY')=11, 'OK', 'FAIL_UNIQUE') AS indici_unici,
  IF((SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi' AND INDEX_NAME='IX_ppt_stato')=2, 'OK', 'FAIL_INDICE_STATO') AS indice_stato,
  IF((SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi' AND CONSTRAINT_TYPE='FOREIGN KEY')=2, 'OK', 'FAIL_FOREIGN_KEY') AS chiavi_esterne,
  IF((SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi' AND CONSTRAINT_TYPE='CHECK')=8, 'OK', 'FAIL_CHECK') AS vincoli_check,
  IF((SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND CONSTRAINT_NAME LIKE 'CK\\_ppt\\_%' AND CHECK_CLAUSE LIKE '%CAPTURED_ORPHAN%')>=2, 'OK', 'FAIL_CLAUSOLE') AS clausole;
```

## rollback

```sql rollback
SET @ks_rows = (SELECT COUNT(*) FROM `paypal_checkout_tentativi`);
SET @ks_sql = IF(@ks_rows = 0, 'DROP TABLE `paypal_checkout_tentativi`', 'SELECT 1 FROM `ks_rollback_rifiutato_la_tabella_contiene_righe`');
PREPARE ks_rollback_stmt FROM @ks_sql;
EXECUTE ks_rollback_stmt;
DEALLOCATE PREPARE ks_rollback_stmt;
```

## monitor

```sql monitor
SELECT Id, AziendeId, LoginId, Stato, StatoPrecedente, TIMESTAMPDIFF(MINUTE, UpdatedAt, NOW()) AS MinutiFermo, DocumentiId, PayPalOrderId, PayPalAuthorizationId, UltimoEsito
FROM paypal_checkout_tentativi
WHERE Stato IN ('CREATING','CREATED','AUTHORIZED','VOIDING','DOC_COMMITTED','CAPTURING','UNKNOWN','CAPTURE_REFUSED','CAPTURED_ORPHAN')
  AND UpdatedAt < NOW() - INTERVAL 10 MINUTE
ORDER BY UpdatedAt;
```

Limiti: la tabella va creata sul database di destinazione prima della fase P3; il LAB certifica solo il LAB; nessuna pulizia automatica delle righe vecchie (la conservazione e una decisione da prendere prima di attivare la funzione). CONSEGNA SERVER SOSPESA.
