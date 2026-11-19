# HOPEv2 Render Staging (Free Preview only)

This blueprint defines a **non-production** Node.js Web Service for the isolated branch `integration/hopev2-free-staging-serverless-20261119`. It does not create a database, persistent disk, paid resource, or Production deployment. `autoDeploy` is disabled. Do not change the branch, plan, or environment identity to target Production.

## Service contract

- Render Free Web Service; Node.js 24; `backend` is the service root.
- Build: `npm ci`, backend syntax/contract checks, and migration-file syntax checks.
- Start: the existing `npm start` Node server. Its normal Outbox, payout reconciliation, and upload-cleanup workers remain enabled with a reduced Free-tier poll profile: one Outbox worker every 30 seconds, reconciliation every five minutes with a one-item batch, and upload cleanup hourly with a ten-item batch. This avoids the default four concurrent one-second Outbox pollers and reduces outbound database/object-storage traffic. The signed internal maintenance route and HMAC scheduler are Vercel Preview-only; this Render lane does not configure or invoke them.
- Health check: `/ready`, which verifies PostgreSQL connectivity. The optional Cloudflare keepalive helper calls `/live` only if separately enabled; it is unscheduled by default and does not certify database readiness.
- Render's `RENDER_EXTERNAL_URL` supplies the HTTPS origin. `PUBLIC_BASE_URL` and the default CORS origin use that value unless explicitly overridden with the same origin.
- Database: a **new isolated Neon Staging database**, never Railway, Neon `main`, or Production. Use the Neon pooled connection string (`-pooler`) with TLS required. Neon `suspend_timeout_seconds=0` means the default five-minute idle suspend, not “never suspend”; the account rejected custom timeout changes, so retain this default and the fixed 0.25 CU compute. See [Neon API endpoint schema](https://github.com/neondatabase/neon-api-python/blob/main/v2.json). The service checks the exact migration 001–062 checksums read-only at startup; it never migrates or seeds on restart. Maintenance uses an expiring singleton DB lease, durable request-id replay records, and an owner-matched release so concurrent invocations cannot overlap through transaction pooling.
- Object storage: the existing private Supabase bucket `v2hope-private`, but only under the dedicated `hope-staging/` key prefix. No public bucket and no persistent Render disk.
- Payment: internal ledger only, `TOMAN` only. No external payment, email, push, or alert egress is configured by this blueprint.
- Trust boundary: Render routes public Web Service traffic through Cloudflare and its load balancer. The API uses `CF-Connecting-IP` for client rate-limit keys only when a syntactically valid `CF-Ray` ID is also present, and never trusts caller-controlled `X-Forwarded-For`.

## Required secret values

Set each `sync: false` variable in the Render service's private Environment page. Never paste these values into chat or source control:

- `DATABASE_URL`: pooled connection string for the separate Neon Staging database, with TLS required.
- `ACCESS_TOKEN_SECRET` and `REFRESH_TOKEN_SECRET`: distinct random secrets, each at least 32 bytes.
- `METRICS_TOKEN`: at least 24 bytes.
- `GOOGLE_OAUTH_CLIENT_ID`.
- `ADMIN_PANEL_USERNAME` and `ADMIN_PANEL_ALLOWED_EMAIL`.
- `ADMIN_MFA_ENCRYPTION_KEY`: at least 32 bytes.
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`: server-side Supabase S3 credentials scoped to the existing project.
- `SUPABASE_SERVICE_ROLE_KEY`: backend-only key used only to mint native `upsert=false` signed upload URLs. Never expose it to Flutter or the browser.

Render provides `RENDER=true`, `RENDER_SERVICE_ID`, and `RENDER_EXTERNAL_URL`. Do not manually set those provider-owned variables. After the service is created, copy its exact `RENDER_SERVICE_ID` into `STAGING_RENDER_SERVICE_ID`; the app refuses to start if the values are missing or do not match. This value is not secret but is kept as a manually approved environment setting. Confirm the service is actually marked Free before deploying.

## Database migration sequence

1. Create a new isolated Neon database/branch dedicated to Render Staging. Do not point this service at Neon `main`, the Railway Staging volume, or any Production database.
2. From a trusted local checkout of this branch, use the Staging database's connection string privately in the local shell and run `NODE_ENV=test npm run migrate` from `backend/`. Do not include the connection string in command output, screenshots, shell history, or chat; use a protected local environment file or secret prompt.
3. Verify `npm run migrate:status` reports exactly the committed migration head and checksums (001–062).
4. Add the Neon pooled connection string to Render's `DATABASE_URL`. The service refuses to start if any migration is missing, extra, or checksum-drifted.

The Render service intentionally does not run migrations automatically. A restart is not a migration operation.

## Wallet sandbox controls

The blueprint leaves user top-up, admin credit, and internal wallet payout disabled. This is intentional.

After the service exists, verify the Render-generated `RENDER_SERVICE_ID`. Only if the separate Staging database is confirmed and an isolated wallet test is explicitly approved, set `STAGING_RENDER_SERVICE_ID` to that exact service ID and enable only the required individual feature flags (`INTERNAL_WALLET_USER_TOPUP_ENABLED` plus `STAGING_ALLOW_INTERNAL_WALLET_TOPUP`; `INTERNAL_WALLET_ADMIN_CREDIT_ENABLED`; or `STAGING_ALLOW_INTERNAL_WALLET_PAYOUT`). A missing or mismatched service-ID confirmation keeps these financial features disabled. The known Railway Production project ID remains a hard denial.

## Free-instance idle behavior

The strict $0 configuration intentionally allows Render Free to spin down after 15 minutes without inbound traffic. A waking request takes about one minute. While the process is asleep, the app's in-process Outbox, reconciliation, and storage-cleanup timers do not run; they resume when the service wakes. This is acceptable only for Preview/Testing, not reliable Production processing.

The separate Cloudflare probe helper in `cloudflare-render-keepalive/` is **disabled by default**: Wrangler has no Cron Trigger configured, no public Workers.dev endpoint, and no preview URL. Do not deploy or schedule it for the default zero-cost lane. If later approved, set `RENDER_STAGING_HEALTH_URL` to the exact Render `/live` URL and explicitly add a 12-minute Cron Trigger. The helper only accepts the `*.onrender.com` HTTPS `/live` path and does not call business APIs.

A 12-minute keepalive would generate about 3,600 requests per 30-day month and keep one Render instance active for roughly 720 hours. Render's 750 Free instance-hours are shared across all Free services in the workspace, leaving only about 30 hours before considering other services or restarts. Free web services also count against workspace outbound-bandwidth and build-pipeline allowances; exceeding these can suspend Free services or result in charges depending on payment/spend-limit settings. Render may also suspend a Free service that initiates unusually high outbound traffic to external databases or object storage. Check the Render Dashboard's included usage and spend-limit/payment settings before considering a keepalive. This arrangement is not a Production hosting guarantee.
## Deploy and verify

1. In the Render Dashboard, create the Web Service from this repository and verify the exact integration branch.
2. Review the blueprint diff in Render. Confirm plan `free`, branch exact, `autoDeploy=false`, root `backend`, and no disk or extra service.
3. Complete the required secrets privately and apply the new Neon schema first.
4. Only then manually trigger the first Staging deploy. Do not configure a Production environment or domain.
5. Verify `/ready` returns ready=true, `/live` returns 200, the deployed commit matches this branch, logs contain no secret values, and the Staging DB records the exact migration head.
6. Leave the separate Cloudflare keepalive Worker unscheduled by default. Enable its Cron only after reviewing remaining workspace Free instance-hours and explicitly deciding that the Staging service should stay warm.
7. Run the relevant first-launch API, upload, identity, wallet, payment-state, security, and accessibility tests against this isolated Staging environment. Release certification remains NOT CERTIFIED until the repository's documented gates and evidence are complete.

Render Free is for Preview/Testing, not Production. This setup is a temporary no-cost Staging lane only; a commercial Production launch requires a hosting plan and architecture that meet the provider's current terms and reliability requirements.
