# HOPE Staging Mock Payment Provider

A provider facade for staging and CI that exercises the existing HOPE `PAYMENT_PROVIDER=webhook` boundary without moving real money.

## Endpoints

- `GET /health`
- `POST /create`
- `POST /release`
- `POST /refund`
- `POST /emit-webhook` (optional callback emitter)

The operation endpoints require:

- `Authorization: Bearer <PAYMENT_PROVIDER_TOKEN>`
- `Idempotency-Key: <unique key>`

The response contract matches `backend/src/payment_provider.js`:

- create → `status=HELD`, `providerRef`
- release → `status=RELEASED`, `releaseRef`
- refund → `status=REFUNDED`, `refundRef`

Set `PAYMENT_CURRENCY=TOMAN` in HOPE staging.

## Failure injection

- `MOCK_PAYMENT_OUTCOME=SUCCESS|FAILED|UNKNOWN`
- `MOCK_PAYMENT_CREATE_OUTCOME=SUCCESS|FAILED|UNKNOWN`
- `MOCK_PAYMENT_RELEASE_OUTCOME=SUCCESS|FAILED|UNKNOWN`
- `MOCK_PAYMENT_REFUND_OUTCOME=SUCCESS|FAILED|UNKNOWN`

The state is in-memory by design. It is a test/staging provider, never the source of financial truth.

## Optional webhook emitter

Set:

- `PAYMENT_WEBHOOK_SECRET`
- `MOCK_PAYMENT_WEBHOOK_TARGET_URL=https://<staging-api>/api/v1/payments/webhook`

Then call `POST /emit-webhook` with the same provider bearer token.

The emitter uses HOPE's timestamped HMAC format:
`sha256=HMAC_SHA256(timestamp.eventId.rawBody)`.
