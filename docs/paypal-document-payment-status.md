# PayPal Checkout document payment status

## Current checkpoint

`PAYPAL-CHECKOUT-ORDERS-V2-LIVE-1A` replaces the former PayPal Express engine with PayPal Checkout Orders API v2 REST, LIVE-only. The code and offline fake-transport tests are complete; the status is **READY FOR LIVE CONFIGURATION**, not LIVE VERIFIED.

No NVP/SOAP, classic Express Checkout, runtime Sandbox or legacy IPN path remains usable. The coupon `_xclick` branch and `ipn.aspx` were removed. `aziende.AccountPaypal` is retained only as a shared legacy management column because the desktop procedures still reference it; the web PayPal runtime never reads it.

## Authoritative configuration

- `paypal_checkout_account` identifies one PayPal business account through a validated `CredentialKey`; it contains no client secret.
- `paypal_checkout_azienda` maps an exact `AziendeId + PagamentiTipoId` to account, payee email, checkout brand and currency.
- Server/deploy settings resolve `<CredentialKey>_CLIENT_ID`, `<CredentialKey>_CLIENT_SECRET` and `<CredentialKey>_WEBHOOK_ID` fail-closed.
- A tenant without its own active mapping cannot inherit another tenant's configuration.
- The public runtime accepts only HTTPS on the authoritative tenant host and rejects localhost/loopback.

Taikun and Webaffare may reference the same account, merchant and credential key while retaining distinct `AziendeId`, payee email and brand. Those values are always loaded server-side and never accepted from the browser.

## Payment contract

`paypalcheckout.aspx` creates an Orders v2 order with intent `CAPTURE`, an exact payee, canonical return/cancel URLs and a persisted deterministic `PayPal-Request-Id`. The approval URL must be HTTPS on `www.paypal.com`.

`documenti.OrigineOrdine` is authoritative: `WEB` is persisted in the same transaction as the checkout document and durable idempotency record; `INTERNO` must be written by the desktop management application when it creates a manual order. `NULL` or any other origin fails closed for later payment. Both PayPal and Banca Sella use one internal-order eligibility policy. Web orders may launch the selected gateway only from the initial server-side, session-bound checkout context; they never acquire a later My Account “Pay now” option. PayPal keeps that context for at most five minutes solely to resume the same owner/session, document, checkout identity, attempt, create request ID and exact payload after a technical failure. Sella remains one-shot.

PayPal transactions are attempt-aware: `(DocumentiId,TentativoNo)` is unique and exactly one row per document may own `CurrentSlot=1`. Prior attempts retain `CurrentSlot=NULL`. Technical retries reuse the same create/capture request IDs; a new voluntary internal-order attempt requires authoritative Get Order reconciliation and a locked transition to `SUPERSEDED`. A completed or pending capture, an approved order, ambiguous response or capture in progress never opens a new attempt. Old returns and approved webhooks never capture a superseded order; an authentic old completed capture still marks the document paid, preventing a second payment.

`paypalreturn.aspx` distrusts browser fields. It loads the persisted order, calls Get Order, verifies tenant, document, IDs, amount, currency, payee and merchant, then captures with the already persisted capture request ID. Order amount and actually captured amount are parsed independently; exactly one purchase unit and at most one full capture are accepted. A completed capture without its own positive amount and currency, or one that differs from the document and persisted attempt, cannot set `Pagato=1`. Ambiguous incomplete responses remain for reconciliation rather than authorizing a new Web attempt. Duplicate return, refresh or retry cannot create another logical capture.

`paypalrecheck.aspx` performs Get Order only. It never recaptures. `paypalwebhook.aspx` rejects local, loopback, HTTP and unknown ingress before any PayPal transport; it then verifies the raw PayPal signature with the configured webhook ID before writes and processes unique event IDs monotonically. The authorized webhook ingress host need not equal the order tenant host when the same PayPal account serves multiple storefronts; the tenant and account are resolved from the persisted transaction.

Document markers:

- `PP-ORDER:<OrderId>` means created/approved/pending and never means paid;
- `TXN:<CaptureId>` is written only for an authoritative `COMPLETED` capture;
- `Pagato=1` and `StatoPagamentoWeb=2` are allowed only for that completed capture;
- pending, denied, declined, failed and canceled states keep `Pagato=0`.

## Database transition

The migration set `20260922_PAYPAL_CHECKOUT_ORDERS_V2_LIVE_1A_*` creates only account, tenant, attempt-aware transaction and event-idempotency tables. It adds the nullable document origin when absent and removes obsolete PayPal Express objects without copying their data or secrets. MySQL DDL performs implicit commits: preflight and verified backup are mandatory, and rollback is a separately authorized emergency procedure. This migration has not been executed against production by this task.

## Security and tests

Credentials, OAuth tokens, authorization headers and complete webhook payloads must never be logged. Offline tests use an injectable fake HTTP transport and cover OAuth, create/get/capture, mismatches, hostile approval URLs, deterministic retries, webhook verification/idempotency, tenant A/B/A isolation and fail-closed configuration. A separate isolated, named-pipe-only MySQL harness verifies that invalid or partial captures do not write paid state, while a valid capture and concurrent replay produce one paid state and event. No real PayPal call is permitted before LIVE configuration and an explicitly authorized smoke.

## Remaining LIVE gate

Before the first real payment, Enzo must deploy the migration, configure the shared account plus the two tenant mappings, provision the three server settings, configure the production webhook and run read-only verification. Only then may an explicitly authorized controlled LIVE payment establish `LIVE VERIFIED`.
