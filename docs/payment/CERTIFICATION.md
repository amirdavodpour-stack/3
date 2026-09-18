# HOPE/V2hope Payment Certification

## Purpose

This module extends the existing HOPE payment architecture rather than replacing it.

The canonical flow is:

`payment request → provider adapter → outbox → provider response → payment state → ledger/wallet boundary`.

### Staging

Use the free Mock Payment Provider behind `PAYMENT_PROVIDER=webhook` when validating the external-provider boundary.

Required staging configuration:

```env
PAYMENT_PROVIDER=webhook
PAYMENT_CURRENCY=TOMAN
PAYMENT_PROVIDER_TOKEN=<staging-only token>
PAYMENT_PROVIDER_CREATE_URL=https://<mock-provider>/create
PAYMENT_PROVIDER_RELEASE_URL=https://<mock-provider>/release
PAYMENT_PROVIDER_REFUND_URL=https://<mock-provider>/refund
PAYMENT_WEBHOOK_SECRET=<staging-only webhook secret>
```

Production configuration remains fail-closed and does not allow the simulator.

## CI

The GitHub Actions payment certification workflow uses a local PostgreSQL 17 service, the existing simulator/provider tests, PostgreSQL invariant checks, and the existing real-PostgreSQL marketplace/payment lifecycle suite.

No real PSP credential is required.

## Financial invariants

The certification gate checks:

- Posted journals are balanced and non-empty.
- Wallet balances never become negative.
- Wallet entries reference existing financial operations.
- Terminal financial operations have completion timestamps.
- Payment idempotency is unique per payer.
- Provider event identifiers are unique per provider.
- Payment records retain provider references.

## Webhook security

Inbound payment webhooks continue to use the existing timestamped HMAC boundary in `backend/src/application/payment_webhook.js`, with provider events claimed before financial mutation.

The optional Mock Provider webhook emitter uses the exact same signed format and a fixed target URL configured by environment, rather than accepting an arbitrary callback URL.
