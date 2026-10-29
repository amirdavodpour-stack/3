#!/usr/bin/env sh
set -eu

# Unconditionally required in production.
required='ACCESS_TOKEN_SECRET REFRESH_TOKEN_SECRET DATABASE_URL PUBLIC_BASE_URL METRICS_TOKEN S3_BUCKET RESET_TOKEN_DELIVERY_SECRET ALLOWED_CORS_ORIGINS'
for name in $required; do
  eval "value=\${$name-}"
  [ -n "$value" ] || { echo "Missing required production variable: $name" >&2; exit 1; }
done

case "$PUBLIC_BASE_URL" in https://*) ;; *) echo 'PUBLIC_BASE_URL must use HTTPS.' >&2; exit 1;; esac
case "$PAYMENT_PROVIDER" in webhook|internal) ;; *) echo 'PAYMENT_PROVIDER must be webhook or internal in production.' >&2; exit 1;; esac

# The staging project also uses a Railway environment named "production".
# Only the effective enabled state (internal provider + both flags) is scoped
# to that project. Partial flag configuration remains fail-closed in the API,
# but must not prevent an otherwise safe service from starting.
case "${INTERNAL_WALLET_USER_TOPUP_ENABLED:-false}:${STAGING_ALLOW_INTERNAL_WALLET_TOPUP:-false}" in
  true:true)
    if [ "$PAYMENT_PROVIDER" = internal ]; then
      [ "${RAILWAY_PROJECT_ID:-}" = '8c686259-09c6-4609-bbe7-4ea25e769e18' ] || { echo 'Staging internal wallet top-up is permitted only for the designated Staging Railway project.' >&2; exit 1; }
    fi
    ;;
esac
if [ "$PAYMENT_PROVIDER" = "internal" ]; then
  [ "${PAYMENT_CURRENCY:-TOMAN}" = "TOMAN" ] || { echo 'PAYMENT_CURRENCY=TOMAN is required when PAYMENT_PROVIDER=internal.' >&2; exit 1; }
fi
case "$STORAGE_BACKEND" in s3) ;; *) echo 'STORAGE_BACKEND must be s3 in production.' >&2; exit 1;; esac
[ "${RESET_TOKEN_DELIVERY_MODE:-}" = "webhook" ] || { echo 'RESET_TOKEN_DELIVERY_MODE=webhook is required in production.' >&2; exit 1; }
case "$ALLOWED_CORS_ORIGINS" in *'*'*) echo 'Wildcard CORS is forbidden in production.' >&2; exit 1;; esac

# Match the runtime URL parser: every comma-separated entry must be a true
# origin, without credentials, paths, queries, or fragments. HTTP is local-only.
printf '%s' "$ALLOWED_CORS_ORIGINS" | node --input-type=module -e '
let input = "";
for await (const chunk of process.stdin) input += chunk;
const origins = input.split(",").map((value) => value.trim()).filter(Boolean);
const fail = (message) => { console.error(message); process.exit(1); };
if (!origins.length || origins.includes("*") || origins.some((origin) => origin.includes("*"))) {
  fail("ALLOWED_CORS_ORIGINS must explicitly list non-wildcard origins in production.");
}
for (const origin of origins) {
  let parsed;
  try { parsed = new URL(origin); } catch { fail("ALLOWED_CORS_ORIGINS must contain valid origins."); }
  if (!["https:", "http:"].includes(parsed.protocol) || parsed.username || parsed.password || parsed.pathname !== "/" || parsed.search || parsed.hash) {
    fail("ALLOWED_CORS_ORIGINS must contain origin URLs without credentials, paths, queries, or fragments.");
  }
  if (parsed.protocol !== "https:" && parsed.hostname !== "localhost") {
    fail("Non-local production CORS origins must use HTTPS.");
  }
}
'

if [ -n "${S3_ENDPOINT:-}" ]; then
  case "$S3_ENDPOINT" in https://*) ;; *) echo 'S3_ENDPOINT must use HTTPS when set in production.' >&2; exit 1;; esac
fi

# External payment facade is required only for the real webhook adapter.
if [ "$PAYMENT_PROVIDER" = "webhook" ]; then
  for name in PAYMENT_PROVIDER_TOKEN PAYMENT_PROVIDER_CREATE_URL PAYMENT_PROVIDER_RELEASE_URL PAYMENT_PROVIDER_REFUND_URL PAYMENT_WEBHOOK_SECRET; do
    eval "value=\${$name-}"
    [ -n "$value" ] || { echo "Missing required production variable: $name" >&2; exit 1; }
  done
  for name in PAYMENT_PROVIDER_CREATE_URL PAYMENT_PROVIDER_RELEASE_URL PAYMENT_PROVIDER_REFUND_URL; do
    eval "value=\${$name-}"
    case "$value" in https://*) ;; *) echo "$name must use HTTPS." >&2; exit 1;; esac
  done
  [ "${#PAYMENT_PROVIDER_TOKEN}" -ge 24 ] || { echo 'PAYMENT_PROVIDER_TOKEN is too short for production.' >&2; exit 1; }
  [ "${#PAYMENT_WEBHOOK_SECRET}" -ge 24 ] || { echo 'PAYMENT_WEBHOOK_SECRET is too short for production.' >&2; exit 1; }
fi

# Notification delivery is optional: only validated when actually set,
# mirroring src/config.js. Leaving both blank keeps in-app notifications only.
for name in NOTIFICATION_PUSH_URL NOTIFICATION_EMAIL_URL; do
  eval "value=\${$name-}"
  if [ -n "$value" ]; then
    case "$value" in https://*) ;; *) echo "$name must use HTTPS when set." >&2; exit 1;; esac
  fi
done
if [ -n "${NOTIFICATION_PUSH_URL:-}" ] || [ -n "${NOTIFICATION_EMAIL_URL:-}" ]; then
  value="${NOTIFICATION_PROVIDER_TOKEN:-}"
  [ "${#value}" -ge 24 ] || { echo 'NOTIFICATION_PROVIDER_TOKEN must be set and sufficiently long when external notification delivery is configured.' >&2; exit 1; }
fi

# Password-reset delivery is webhook-only in production and must be authenticated.
value="${RESET_TOKEN_DELIVERY_URL:-}"
case "$value" in https://*) ;; *) echo 'RESET_TOKEN_DELIVERY_URL must use HTTPS in production.' >&2; exit 1;; esac
value="${RESET_TOKEN_DELIVERY_SECRET:-}"
[ "${#value}" -ge 32 ] || { echo 'RESET_TOKEN_DELIVERY_SECRET must be at least 32 characters in production.' >&2; exit 1; }

value="${ADMIN_PANEL_USERNAME:-}"
[ "${#value}" -ge 4 ] || { echo 'ADMIN_PANEL_USERNAME must be configured for production admin access.' >&2; exit 1; }
[ "${#value}" -le 120 ] || { echo 'ADMIN_PANEL_USERNAME must be at most 120 characters in production.' >&2; exit 1; }

for name in ACCESS_TOKEN_SECRET REFRESH_TOKEN_SECRET METRICS_TOKEN; do
  eval "value=\${$name-}"
  [ "${#value}" -ge 24 ] || { echo "$name is too short for production." >&2; exit 1; }
done
[ "${#ACCESS_TOKEN_SECRET}" -ge 32 ] || { echo 'ACCESS_TOKEN_SECRET must be at least 32 characters in production.' >&2; exit 1; }
[ "${#REFRESH_TOKEN_SECRET}" -ge 32 ] || { echo 'REFRESH_TOKEN_SECRET must be at least 32 characters in production.' >&2; exit 1; }
[ "$ACCESS_TOKEN_SECRET" != "$REFRESH_TOKEN_SECRET" ] || { echo 'ACCESS_TOKEN_SECRET and REFRESH_TOKEN_SECRET must be different in production.' >&2; exit 1; }
case "$ACCESS_TOKEN_SECRET" in change-this*) echo 'ACCESS_TOKEN_SECRET and REFRESH_TOKEN_SECRET must not use placeholder secrets in production.' >&2; exit 1;; esac
case "$REFRESH_TOKEN_SECRET" in change-this*) echo 'ACCESS_TOKEN_SECRET and REFRESH_TOKEN_SECRET must not use placeholder secrets in production.' >&2; exit 1;; esac

echo 'Production environment contract PASS.'
