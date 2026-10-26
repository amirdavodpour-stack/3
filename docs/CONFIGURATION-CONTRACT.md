# HOPE Configuration Contract

**Contract version:** 2026-09-06
**Application version:** 4.0.2+3
**Source of truth:** `backend/src/config.js` plus the production policy validator in `backend/scripts/validate-production-env.sh`.

This document defines the supported environment variables and the policy by environment. Secrets shown here are placeholders only; real secret material must come from the deployment secret store.

## Environment policy

| Environment | PostgreSQL | Storage | Payments | Reset delivery | CORS | Secret policy |
|---|---|---|---|---|---|---|
| local/development | optional | local | simulator | console | explicit local origins | safe local placeholders allowed |
| test | optional | test adapter/local | simulator | console | test-configured | isolated test values only |
| staging | required | S3-compatible | webhook/sandbox | webhook | explicit HTTPS origins | real staging secrets |
| production | required | S3 | internal or webhook | webhook | explicit non-wildcard origins | fail-closed, 32+ char auth/reset secrets and configured admin username |

## Variables

### Runtime / HTTP
`NODE_ENV`, `HOST`, `PORT`, `DATA_FILE`, `PUBLIC_BASE_URL`, `API_BASE_URL_PRODUCTION` (CI/release only), `REQUEST_TIMEOUT_MS`, `HEADERS_TIMEOUT_MS`, `KEEP_ALIVE_TIMEOUT_MS`, `MAX_REQUEST_BYTES`, `TRUST_PROXY`, `TRUSTED_PROXY_IPS`.

### Authentication / authorization
`ACCESS_TOKEN_SECRET`, `REFRESH_TOKEN_SECRET`, `ACCESS_TOKEN_TTL`, `REFRESH_TOKEN_TTL`, `ACCESS_TOKEN_ISSUER`, `ACCESS_TOKEN_AUDIENCE`, `RESET_TOKEN_TTL`, `RESET_TOKEN_DELIVERY_MODE`, `RESET_TOKEN_DELIVERY_URL`, `RESET_TOKEN_DELIVERY_SECRET`, `EXPOSE_RESET_TOKEN_IN_DEVELOPMENT`, `GOOGLE_AUTH_ENABLED`, `GOOGLE_OAUTH_CLIENT_ID`, `ADMIN_PANEL_USERNAME`, `ADMIN_PANEL_ALLOWED_EMAIL`, `ADMIN_PANEL_VERIFICATION_MINUTES`.

### CORS / rate limiting
`ALLOWED_CORS_ORIGINS`, `RATE_LIMIT_STORE`, `RATE_LIMIT_WINDOW_MS`, `AUTH_RATE_LIMIT_MAX`, `GENERAL_RATE_LIMIT_WINDOW_MS`, `GENERAL_RATE_LIMIT_MAX`, `HEALTH_RATE_LIMIT_WINDOW_MS`, `HEALTH_RATE_LIMIT_MAX`.

### Persistence / storage
`DATABASE_URL`, `PG_POOL_MAX`, `STORAGE_BACKEND`, `STORAGE_DIR`, `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT`, `S3_FORCE_PATH_STYLE`, `S3_PREFIX`, `S3_SERVER_SIDE_ENCRYPTION`, `UPLOAD_INTENT_TTL_SECONDS`, `MAX_UPLOAD_BYTES`, `MAX_CONCURRENT_UPLOADS`.

### Internal wallet staging controls
`INTERNAL_WALLET_USER_TOPUP_ENABLED`, `STAGING_ALLOW_INTERNAL_WALLET_TOPUP`, `INTERNAL_WALLET_ADMIN_CREDIT_ENABLED`. User top-up requires `PAYMENT_PROVIDER=internal` and `INTERNAL_WALLET_USER_TOPUP_ENABLED=true`; it is enabled when `NODE_ENV` is not `production`, or when `STAGING_ALLOW_INTERNAL_WALLET_TOPUP=true`. The staging Railway project's environment is also named `production`, so this override is currently an out-of-band staging exception and is not an independent proof of deployment identity. Do not set the override on the real production service; runtime exposure remains unverified until effective values are confirmed. Admin sandbox credit is fail-closed in production unless explicitly enabled by deployment policy.

### Payments
`PAYMENT_PROVIDER`, `PAYMENT_CURRENCY`, `PAYMENT_WEBHOOK_SECRET`, `PAYMENT_PROVIDER_TOKEN`, `PAYMENT_PROVIDER_CREATE_URL`, `PAYMENT_PROVIDER_RELEASE_URL`, `PAYMENT_PROVIDER_REFUND_URL`, `PAYMENT_PROVIDER_PAYOUT_STATUS_URL`, `PAYMENT_PROVIDER_TIMEOUT_MS`, `PAYMENT_PROVIDER_MAX_ATTEMPTS`, `PAYMENT_PROVIDER_RETRY_BASE_MS`, `PAYMENT_WEBHOOK_MAX_AGE_SECONDS`. Production accepts `internal` or `webhook`; `internal` requires `PAYMENT_CURRENCY=TOMAN` and does not require external PSP credentials/endpoints.

### Notifications / telemetry / alerts
`NOTIFICATION_PUSH_URL`, `NOTIFICATION_EMAIL_URL`, `NOTIFICATION_PROVIDER_TOKEN`, `NOTIFICATION_MAX_ATTEMPTS`, `NOTIFICATION_RETRY_BASE_MS`, `NOTIFICATION_DELIVERY_TIMEOUT_MS`, `METRICS_TOKEN`, `ALERT_WEBHOOK_URL`, `ALERT_WEBHOOK_TOKEN`, `ALERT_WEBHOOK_TIMEOUT_MS`.

### Workers / idempotency
`OUTBOX_POLL_MS`, `OUTBOX_WORKER_CONCURRENCY`, `OUTBOX_MAX_ATTEMPTS`, `OUTBOX_LEASE_SECONDS`, `MAX_IDEMPOTENCY_KEY_LENGTH`.

## Secret rules

Never commit real secret values. Production must reject placeholder authentication secrets, missing metrics token, missing payment/reset secrets, missing `ADMIN_PANEL_USERNAME` (runtime contract: 4–120 characters), wildcard CORS, non-HTTPS external endpoints, non-PostgreSQL persistence, local storage, and simulator payments. External PSP credentials/endpoints are required only when `PAYMENT_PROVIDER=webhook`; internal ledger mode is explicitly allowed for the temporary non-bank-money phase.

## Machine validation

Run:

```bash
cd backend
npm run check:config-contract
./scripts/validate-production-env.sh
```

The first command verifies repository consistency. The second validates the production-specific policy and requires real production variables in its calling environment. The `production-release` and `release-validation` workflows map `ADMIN_PANEL_USERNAME_PRODUCTION` into `ADMIN_PANEL_USERNAME`; configure that GitHub Actions secret and the matching runtime variable before releasing a candidate that includes the production admin identity gate.


## Internal wallet / temporary payment mode

When `PAYMENT_PROVIDER=internal` and `PAYMENT_CURRENCY=TOMAN`, payment funding and release use the PostgreSQL internal wallet ledger. `GET /api/v1/wallet/me` exposes the authenticated user's internal balance; `GET /api/v1/wallet/transactions` exposes wallet transaction history. `POST /api/v1/wallet/transfer` supports internal currency transfers with an idempotency key. `POST /api/v1/wallet/top-up` is a user-scoped internal-provider staging operation. It requires `INTERNAL_WALLET_USER_TOPUP_ENABLED=true` and is denied when `NODE_ENV=production` unless `STAGING_ALLOW_INTERNAL_WALLET_TOPUP=true`; that exception exists because the staging Railway project itself has an environment named `production`. Do not configure the exception on the real production service, and treat exposure as unverified until effective variable values are confirmed. `POST /api/v1/wallet/sandbox-credit` remains admin-only for controlled test funding.

[executed on device: localhost (ad4940fb-3108-4ab5-af41-ee34669dd70c)]
