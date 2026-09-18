# HOPE Staging Secret Audit

Scope: current staging/hardening branch only. Secret values are never stored in this document.

## PRESENT + REFERENCED

- API_BASE_URL_STAGING
- DRILL_DATABASE_URL
- SOURCE_DATABASE_URL
- NOTIFICATION_PROVIDER_TOKEN
- NOTIFICATION_PUSH_URL
- STAGING_AWS_ACCESS_KEY_ID
- STAGING_AWS_SECRET_ACCESS_KEY
- STAGING_METRICS_TOKEN
- STAGING_S3_BUCKET
- STAGING_S3_ENDPOINT
- STAGING_S3_REGION
- Android release secrets used by the release workflows

## PRESENT + STAGING-RELEVANT

- PAYMENT_WEBHOOK_SECRET
- PAYMENT_PROVIDER_TOKEN
- PAYMENT_PROVIDER_CREATE_URL
- PAYMENT_PROVIDER_RELEASE_URL
- PAYMENT_PROVIDER_REFUND_URL

The PAYMENT_PROVIDER_* set is only required when staging uses the external/webhook provider boundary. The current staging certification workflow remains on the internal TOMAN payment mode, so no real PSP credential is required.

## PRESENT BUT CURRENTLY UNUSED

- PAYOUT_WEBHOOK_SECRET

This staging-only secret was added to Railway because the planned payout webhook boundary is not yet implemented. No code or workflow currently consumes it.

## NAMING GAP FIXED

staging-certification.yml previously used STAGING_DATABASE_URL, while the canonical current secret is SOURCE_DATABASE_URL. The workflow now accepts:

STAGING_DATABASE_URL || SOURCE_DATABASE_URL

This avoids creating a duplicate database credential solely for naming compatibility.

## FUTURE / NOT REQUIRED NOW

- PAYMENT_PROVIDER_PAYOUT_STATUS_URL

Used only when the external provider exposes a payout-status/reconciliation endpoint.

## PRODUCTION SECRETS

Production-specific secrets remain outside this change set. Main/production was not modified.