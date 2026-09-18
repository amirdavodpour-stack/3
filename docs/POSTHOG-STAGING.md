# PostHog — Staging Integration

## Scope

PostHog is an optional product-analytics sink for the HOPE Flutter client.

The first-party HOPE Telemetry service remains the primary diagnostics path. PostHog is fail-open and must never become a dependency of authentication, wallet, payment, upload, or job execution.

## Activation contract

PostHog capture is active only when all of the following build-time defines are true:

- `HOPE_ENV=staging`
- `POSTHOG_ENABLED=true`
- `POSTHOG_PROJECT_TOKEN` is non-empty
- `POSTHOG_HOST` is a valid HTTPS origin

Recommended hosted default:

`https://us.i.posthog.com`

The PostHog project token is intended for client-side event ingestion. It is still supplied from the staging CI secret/environment so the target project can be changed without editing source code.

## Privacy boundary

The adapter sends anonymous events only and sets `$process_person_profile=false`.

Only low-risk properties are allowlisted:

`action`, `appVersion`, `code`, `environment`, `feature`, `mode`, `platform`, `reason`, `releaseChannel`, `result`, `screen`, `source`, `status`.

Balances, amounts, IBANs, access/refresh tokens, stack traces, error messages, file paths, and arbitrary identifiers are not forwarded.

The existing Telemetry consent remains the gate. With consent disabled (the default), neither first-party analytics nor PostHog receives the event.

## CI contract

The staging certification workflow accepts:

- `POSTHOG_PROJECT_TOKEN` — optional; when present, the workflow performs a harmless ingestion preflight and builds the pilot APK with PostHog enabled.
- `POSTHOG_HOST` — optional; defaults to `https://us.i.posthog.com`.

When the token is absent, the staging build remains functional with PostHog disabled.

Production builds forcibly set:

- `HOPE_ENV=production`
- `POSTHOG_ENABLED=false`
- empty PostHog project token

## Current implementation

- `lib/core/telemetry/posthog_analytics_service.dart`
- `lib/core/telemetry/telemetry_service.dart`
- `tools/build_apk_debug.sh`
- `tools/build_apk_release.sh`
- `.github/workflows/staging-certification.yml`
- `test/core/posthog_analytics_service_test.dart`

## References

PostHog capture API:
https://posthog.com/docs/api/capture

PostHog Flutter:
https://posthog.com/docs/libraries/flutter

PostHog Flutter opt-out:
https://posthog.com/docs/libraries/flutter#opt-out-of-data-capture
