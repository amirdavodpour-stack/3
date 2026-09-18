# HOPE/V2hope Payment Certification

## Purpose

This module extends the existing HOPE payment architecture rather than replacing it.

The canonical flow is:

`payment request → provider adapter → outbox → provider response → payment state → ledger/wallet boundary`.

### Staging

The current free live-staging mode remains `PAYMENT_PROVIDER=internal` with `PAYMENT_CURRENCY=TOMAN`; it does not require a real PSP.

The repository also contains a Mock Payment Provider for certifying the external-provider boundary. When that mode is enabled, use:

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

The GitHub Actions payment certification workflow uses a local PostgreSQL 17 service and starts the repository's Mock Payment Provider locally. The backend is configured as `PAYMENT_PROVIDER=webhook`, so the CI path exercises the same provider boundary used for an external PSP, while allowing only loopback HTTP in the explicit test runtime.

The certification directly exercises that running Mock Provider process for create/release/refund, replay/idempotency, authentication, and currency enforcement. A PostgreSQL end-to-end gate then routes real API funding and refund operations through the same webhook adapter and Mock Provider, including the outbox-to-payment-state transition. It then runs the existing real-PostgreSQL marketplace/payment lifecycle suite, the internal wallet/ledger lifecycle coverage, and PostgreSQL invariant checks.

No real PSP credential is required.

## Free staging constraint

The Mock Payment Provider is also packaged as a deployable staging helper, but the current Railway workspace has reached its free-plan resource provisioning limit. The existing notification provider service is intentionally not repurposed for payment traffic. Until a resource slot is available, live staging remains on the internal TOMAN configuration and the external-provider boundary is certified through the isolated CI Mock Provider instead.

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
