# Payment workstream final summary

## Executive summary

The online payment workstream is closed at application level for document and
My Account payments.

BancaSella/Axerve is the operative online flow for documents. My Account Pay
Now generates a direct server-side link to `/bancasella.aspx`, the launcher
reaches Axerve/GestPay, the server-to-server callback updates the document
payment state, and the browser return page shows user-friendly OK/KO messages.

PayPal for documents and My Account remains hidden and not operational. It is
classified as UI/legacy only and requires a dedicated design and sandbox test
workstream before it can be enabled.

No real payment was completed during the tests. No card data was entered.
`main` was not touched during this workstream.

## Final BancaSella state

My Account Pay Now for BancaSella uses a direct server-generated link to
`/bancasella.aspx`. The document detail no longer relies on the fragile
WebForms postback path for the operative BancaSella action.

The BancaSella link is generated only when all relevant policy checks pass:

- the document belongs to the logged-in user;
- the payment type is online;
- `PermettiPagamentoSuccessivo = 1`;
- `Pagato = 0`;
- there is no `CodiceAutorizzazione`;
- the document state is valid and not cancelled;
- the document total is greater than zero;
- `StatoPagamentoWeb IN (0,1,3,5)`;
- `PagamentiTipoOnline = 3`.

The Pay Now launcher URL contains only the operational parameters required by
the BancaSella launcher:

- `currency`;
- `amount`;
- `shopTransactionId`;
- `idDocumento`;
- `sitoWeb`.

The My Account Pay Now link does not add `buyerName`, `buyerEmail`, card data,
tokens, or secrets.

## BancaSella launcher and Axerve/GestPay

File: `bancasella.aspx.vb`

The launcher reads the BancaSella configuration, builds `customInfo`, creates
the GestPay encryption request, and calls `objCrypt.Encrypt(...)`.

Before the gateway call, it forces TLS 1.2 through
`EnsureBancaSellaTls12()`. This uses the numeric TLS 1.2 value for
compatibility with older .NET Framework references.

The SOAP endpoint remains the Axerve/GestPay host/path:

- `https://ecomms2s.sella.it/gestpay/GestPayWS/WsCryptDecrypt.asmx`

After a successful encryption response, the browser is redirected to the
Axerve/GestPay payment page:

- `https://ecomm.sella.it/pagam/pagam.aspx`

The implementation does not disable certificate validation and does not install
a permissive `ServerCertificateValidationCallback`.

## Server-to-server callback

File: `BancaSella/comunication.aspx.vb`

This callback is the authoritative point for payment DB updates. The browser
return page is not authoritative.

On `TransactionResult = "OK"`:

- duplicate insert into `bancasella_ordini_pagati` is avoided by checking
  existing rows for the document or authorization code;
- `documenti.Pagato` is set to `1`;
- `documenti.StatoPagamentoWeb` is set to `2`;
- `documenti.DataStatoPagamentoWeb` is set to `CURRENT_TIMESTAMP`;
- `documenti.UltimoEsitoPagamentoWeb` is set to
  `BancaSella pagamento autorizzato`.

On non-OK result:

- `documenti.Pagato` is not set to `1`;
- `documenti.StatoPagamentoWeb` is set to `3`;
- `documenti.DataStatoPagamentoWeb` is set to `CURRENT_TIMESTAMP`;
- `documenti.UltimoEsitoPagamentoWeb` is populated with a sanitized outcome,
  capped at 255 characters.

The callback logs only sanitized technical information. It does not log card
data, credentials, tokens, or complete encrypted gateway payloads.

Residual risk: the callback does not yet verify the paid amount against the
document total. That remains future work.

## Browser return UX

File: `BancaSella/responseClient.aspx.vb`

The browser return endpoint handles user experience only. It does not update
`documenti.Pagato`, `StatoPagamentoWeb`, or other authoritative payment state.

On OK browser return for a valid document, it redirects to:

- `documentidettaglio.aspx?id=<id>&payreturn=ok`

The order detail then shows an informational message that the payment was
received by the gateway and the automatic confirmation is being verified.

On KO browser return for a valid document, it redirects to:

- `documentidettaglio.aspx?id=<id>&payreturn=ko`

The order detail then shows a user-friendly message that the payment was not
completed and can be retried from the order.

The expected race condition is documented: the browser OK return can arrive
before the server-to-server callback. In that case the user sees a verification
message while the callback remains responsible for the DB update.

## PayPal decision

PayPal document and My Account payments are not operational.

Current state:

- `btPayPal` exists in `documentidettaglio.aspx`;
- `btPayPal` is hidden;
- there is no verified document handler;
- there is no document PayPal launcher;
- there is no document PayPal return/cancel UX;
- there is no reliable document callback or webhook aligned with
  `StatoPagamentoWeb`;
- `ipn.aspx.vb` and coupon PayPal code are legacy and must not be copied into
  document payments without redesign.

The dedicated status document is:

- `docs/paypal-document-payment-status.md`

Current decision:

- do not enable PayPal for documents;
- keep BancaSella as the operative online payment flow;
- start any future PayPal work from a dedicated design, sandbox, callback, and
  idempotency task.

## Main PRs and commits

Known integrated work from `frontend-rebuild` history:

| Task | Commit | Merge commit | Summary |
| --- | --- | --- | --- |
| PAY-BUG-20 | `83d67184` | `c0d8130d` | Replaced BancaSella Pay Now postback with a direct link. |
| PAY-BUG-22 | `2c87f047` | `c8d59a36` | Removed temporary Pay Now diagnostics. |
| PAY-GW-1 | `436abcef` | `ac62d5ed` | Enforced TLS 1.2 in the BancaSella launcher. |
| PAY-GW-4 | `948ca5a7` | `c6109254` | Updated BancaSella callback payment status. |
| PAY-GW-6 | `5481a4b4` | `8f7ef6e7` | Improved BancaSella browser return OK/KO UX. |
| PAY-PAYPAL-2 | `2d3009dd` | `223c18c9` | Documented PayPal document payment status. |

Earlier supporting work also included the My Account Pay Now launch path,
legacy status support, detail button visibility, postback diagnostics, and
catalog redirect fixes. Those were intermediate steps toward the final direct
link implementation.

## Tests performed

The workstream included static checks, precompilation checks for code changes,
and browser smoke tests.

Verified:

- My Account order list Pay Now path reaches the order detail;
- BancaSella Pay Now link is visible for the payable test order;
- the operative BancaSella control is a direct link, not an input submit;
- the generated link points to `/bancasella.aspx`;
- the link contains the expected general parameters;
- no full token, secret, card data, or complete gateway query was reported;
- the launcher reaches Axerve/GestPay;
- the TLS error was fixed after enforcing TLS 1.2;
- `payreturn=ok` shows the expected order-detail alert;
- `payreturn=ko` shows the expected order-detail alert;
- invalid `payreturn` values are ignored;
- PayPal remains hidden and was not exercised.

No real payment was completed. No card data was entered. No PayPal credentials
were entered.

## Residual risks and future work

Remaining items:

- run a real sandbox or controlled gateway callback test for BancaSella OK and
  KO;
- verify callback amount against the expected document total;
- monitor BancaSella logs after the first real or sandbox payment;
- handle any root CA, proxy, or firewall issue if TLS/channel errors reappear;
- decide and implement deferred email behavior for
  `InviaEmailOrdinePrimaPagamento = 0`;
- keep PayPal out of document payments until a separate PayPal design and
  sandbox workstream exists;
- keep PayPal callback/IPN legacy code out of the document flow until it has
  been redesigned or replaced.

## Future operating rules

- Do not enable document PayPal without sandbox coverage.
- Do not modify My Account Pay Now and gateway callbacks in the same task.
- Do not log tokens, encrypted gateway strings, card data, credentials, or full
  gateway payloads.
- Do not disable certificate validation.
- Do not add permissive certificate callbacks.
- Do not use `git add Public/assets/images/`.
- Do not push unintended image assets.
- Verify the PR base is `frontend-rebuild`.
- Verify `main` is not touched.
- Keep DB schema and dump changes in separate dedicated tasks.
