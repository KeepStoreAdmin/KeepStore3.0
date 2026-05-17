# PayPal document payment status

## Scope

This note records the current status of PayPal for document and My Account
payments in KeepStore.

As of PAY-PAYPAL-1, PayPal is classified as:

**C - UI/legacy only, not operational for documents.**

BancaSella remains the only verified online Pay Now flow for documents.

## Current status

PayPal document payments are not operational for My Account documents.

The order detail page still contains a legacy `btPayPal` control, but it is
hidden by default and must remain hidden. The control has
`CommandName="PagamentoPayPal"`, but there is no verified document handler in
`documentidettaglio.aspx.vb`.

The document detail Pay Now logic currently exposes BancaSella only when the
document is payable and `PagamentiTipoOnline = 3`. PayPal is explicitly kept
hidden until a document payment flow is designed and tested.

There is no complete PayPal document flow today:

- no My Account PayPal launcher or server-generated document link;
- no document-specific PayPal return URL;
- no document-specific PayPal cancel URL;
- no reliable document callback or webhook aligned with the new payment state
  fields;
- no PayPal update of `documenti.StatoPagamentoWeb`;
- no verified idempotency for document PayPal callbacks.

## Existing legacy pieces

The repository contains PayPal-related legacy pieces, but they are not a
complete document payment implementation.

- `documentidettaglio.aspx` contains hidden `btPayPal` markup.
- `pagamentitipo.OnLine = 2` is the conceptual value for PayPal.
- `ipn.aspx.vb` contains a legacy IPN handler.
- Coupon code contains a legacy PayPal branch.
- Company configuration includes `aziende.AccountPaypal`, loaded into
  `Session("AccountPaypal")`.

No sensitive values are documented here. Account identifiers, credentials,
tokens, client IDs, secrets, and gateway parameters must not be copied into
documentation or logs.

## What not to do

Do not enable `btPayPal` for documents.

Do not copy the coupon PayPal flow into document payments without a dedicated
design and security audit.

Do not reuse the legacy IPN handler as authoritative for documents without
redesigning it around document identity, amount validation, idempotency, and
the new web payment status fields.

Do not set `documenti.Pagato = 1` without also updating the web payment status
fields consistently:

- `documenti.StatoPagamentoWeb`;
- `documenti.DataStatoPagamentoWeb`;
- `documenti.UltimoEsitoPagamentoWeb`.

Do not enable real PayPal payments before sandbox testing covers success,
failure, cancellation, duplicate callback, amount mismatch, and missing
callback cases.

## Requirements for a future document PayPal flow

A future PayPal document flow must start from a dedicated design task.

Required decisions and implementation points:

- choose the architecture: modern PayPal Checkout, or legacy/IPN only if
  explicitly justified;
- configure and test sandbox credentials before live use;
- create a server-generated Pay Now launcher/link for documents;
- include return and cancel UX for the browser return path;
- implement an authoritative callback or webhook;
- validate that the callback belongs to the expected document and amount;
- update `documenti.Pagato` only on verified successful payment;
- update `documenti.StatoPagamentoWeb`;
- update `documenti.DataStatoPagamentoWeb`;
- update `documenti.UltimoEsitoPagamentoWeb` with sanitized text;
- make callbacks idempotent;
- store sanitized logs only;
- avoid exposing buyer data, tokens, credentials, or full gateway payloads.

Minimum test matrix:

- PayPal success;
- PayPal failure;
- user cancellation;
- duplicate callback;
- callback before browser return;
- browser return before callback;
- missing callback;
- amount mismatch;
- document already paid;
- retry Pay Now after failure or cancellation.

## Current decision

PayPal remains hidden and not implemented for document and My Account payments.

BancaSella remains the operative online payment flow for documents.

Any future PayPal work must begin with a dedicated audit/design task before
any UI is enabled or any live payment path is exposed.
