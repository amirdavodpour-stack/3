# HOPE Staging ntfy Provider

A minimal HTTPS-facing adapter for staging notification certification.

- Accepts the exact PUSH payload contract emitted by `backend/src/outbox_handlers.js`.
- Requires a bearer token and idempotency key.
- Publishes only staging notification text to an ntfy topic.
- No production/real-money integration.
- The ntfy topic must be high-entropy and must not contain PII.

Environment:
- `PORT`
- `NOTIFICATION_PROVIDER_TOKEN` (>=24 chars)
- `NTFY_TOPIC` (16-128 chars, random)
- `NTFY_BASE_URL` (default `https://ntfy.sh`)
