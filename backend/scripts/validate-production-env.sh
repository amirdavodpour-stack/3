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
if [ "$PAYMENT_PROVIDER" = "internal" ]; then
  [ "${PAYMENT_CURRENCY:-TOMAN}" = "TOMAN" ] || { echo 'PAYMENT_CURRENCY=TOMAN is required when PAYMENT_PROVIDER=internal.' >&2; exit 1; }
fi
case "$STORAGE_BACKEND" in s3) ;; *) echo 'STORAGE_BACKEND must be s3 in production.' >&2; exit 1;; esac
[ "${RESET_TOKEN_DELIVERY_MODE:-}" = "webhook" ] || { echo 'RESET_TOKEN_DELIVERY_MODE=webhook is required in production.' >&2; exit 1; }
case "$ALLOWED_CORS_ORIGINS" in *'*'*) echo 'Wildcard CORS is forbidden in production.' >&2; exit 1;; esac

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

for name in ACCESS_TOKEN_SECRET REFRESH_TOKEN_SECRET METRICS_TOKEN; do
  eval "value=\${$name-}"
  [ "${#value}" -ge 24 ] || { echo "$name is too short for production." >&2; exit 1; }
done
[ "${#ACCESS_TOKEN_SECRET}" -ge 32 ] || { echo 'ACCESS_TOKEN_SECRET must be at least 32 characters in production.' >&2; exit 1; }
[ "${#REFRESH_TOKEN_SECRET}" -ge 32 ] || { echo 'REFRESH_TOKEN_SECRET must be at least 32 characters in production.' >&2; exit 1; }

echo 'Production environment contract PASS.'
