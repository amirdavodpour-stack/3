import { config } from './config.js';
import { claimOutboxEvent, completePaymentCreateHoldOutbox, completePaymentReleaseOutbox, completePaymentRefundOutbox, completeOutboxEvent, failOutboxEvent } from './repository.js';
import { paymentProvider } from './payment_provider.js';
import { deliverNotification } from './notification_provider.js';
import { logEvent, logEventAndWait, recordOutboxFailed, recordOutboxProcessed, recordCategoryFailure } from './observability.js';
import { completePayoutOutbox, failPayoutOutbox, markPayoutUnknown } from './repository/payouts.js';
import { isInternalWalletPayoutEnabled } from './wallet_payout_policy.js';
import { dispatchSecurityAlert } from './alerting.js';
import { dispatchNotificationOutbox } from './repository/notifications.js';
import { normalizeOutboxFailureMetadata } from './outbox_failure_metadata.js';

function failureCategory(event) {
  const type = event?.event_type || '';
  if (type.startsWith('PAYMENT_')) return 'payment';
  if (type === 'AUTH_REFRESH_REUSE_ALERT' || type === 'SECURITY_ALERT_TERMINAL_FAILURE_SIGNAL') return 'security';
  if (type === 'NOTIFICATION_DISPATCH') {
    const channel = event?.payload?.channel;
    if (channel === 'PUSH') return 'push';
    if (channel === 'EMAIL') return 'email';
  }
  return null;
}

export async function processOutboxEvent(event) {
  try {
    const payload = event.payload || {};
    if (event.event_type === 'PAYMENT_CREATE_HOLD') {
      const result = await paymentProvider.createHold({ paymentId: payload.paymentId, amount: payload.amount, currency: payload.currency, idempotencyKey: payload.idempotencyKey });
      if (result.status !== 'HELD' || !result.providerRef) throw new Error('PAYMENT_PROVIDER_UNCONFIRMED');
      const completed = await completePaymentCreateHoldOutbox({ eventId:event.id, jobId:payload.jobId, paymentId:payload.paymentId, providerRef:result.providerRef, actorId:payload.ownerId, leaseToken:event.lease_token });
      if (!completed?.completed) throw new Error(`OUTBOX_CREATE_HOLD_COMMIT_FAILED:${completed?.reason || 'UNKNOWN'}`);
      recordOutboxProcessed();
      logEvent({ level:'info', action:'OUTBOX_PROCESSED', eventId:event.id, eventType:event.event_type });
    } else if (event.event_type === 'PAYMENT_REFUND') {
      const result = await paymentProvider.refundHold({ paymentId: payload.paymentId, providerRef: payload.providerRef, idempotencyKey: payload.idempotencyKey || `refund:${payload.refundId}` });
      if (result.status !== 'REFUNDED' || !result.refundRef) throw new Error('PAYMENT_PROVIDER_REFUND_UNCONFIRMED');
      const completed = await completePaymentRefundOutbox({ eventId:event.id, jobId:payload.jobId, paymentId:payload.paymentId, refundId:payload.refundId, providerRef:result.refundRef, actorId:payload.ownerId, leaseToken:event.lease_token });
      if (!completed?.completed) throw new Error(`OUTBOX_REFUND_COMMIT_FAILED:${completed?.reason || 'UNKNOWN'}`);
      recordOutboxProcessed();
      logEvent({ level:'info', action:'OUTBOX_PROCESSED', eventId:event.id, eventType:event.event_type });
    } else if (event.event_type === 'PAYOUT_EXECUTE') {
      if (!isInternalWalletPayoutEnabled({ paymentProvider: config.paymentProvider })) {
        const disabled = await failPayoutOutbox({
          eventId:event.id,
          payoutId:payload.payoutId,
          error:'PAYOUT_PROVIDER_NOT_ENABLED',
          failureCode:'PAYOUT_PROVIDER_NOT_ENABLED',
          leaseToken:event.lease_token,
        });
        if (!disabled?.completed) throw new Error(`OUTBOX_PAYOUT_DISABLED_COMMIT_FAILED:${disabled?.reason || 'UNKNOWN'}`);
        recordOutboxFailed();
        logEvent({ level:'warn', action:'OUTBOX_PAYOUT_DISABLED', eventId:event.id, eventType:event.event_type, payoutId:payload.payoutId });
        return { processed:false, disabled:true };
      }
      const result = await paymentProvider.createPayout({ payoutId: payload.payoutId, amount: payload.amount, currency: payload.currency, idempotencyKey: payload.idempotencyKey });
      if (result.status === 'UNKNOWN') {
        let unknown;
        try {
          unknown = await markPayoutUnknown({
            eventId:event.id,
            payoutId:payload.payoutId,
            reason:'PROVIDER_UNKNOWN',
            leaseToken:event.lease_token,
          });
        } catch (error) {
          // The provider outcome is ambiguous. Do not send this event through
          // failOutboxEvent: terminal payout failure would unlock funds even
          // though the provider may have completed the disbursement.
          logEvent({
            level:'error',
            action:'OUTBOX_PAYOUT_UNKNOWN_PERSISTENCE_FAILED',
            eventId:event.id,
            payoutId:payload.payoutId,
            errorCode:'PAYOUT_UNKNOWN_PERSISTENCE_FAILED',
          });
          return { processed:false, unknown:true, persistencePending:true };
        }
        if (!unknown?.marked) {
          logEvent({
            level:'error',
            action:'OUTBOX_PAYOUT_UNKNOWN_REQUIRES_RECONCILIATION',
            eventId:event.id,
            payoutId:payload.payoutId,
            reason:unknown?.reason || 'UNKNOWN',
          });
          return { processed:false, unknown:true, persistencePending:true };
        }
        recordOutboxProcessed();
        logEvent({
          level:unknown.requiresReconciliation ? 'error' : 'warn',
          action:unknown.requiresReconciliation ? 'OUTBOX_PAYOUT_UNKNOWN_RECONCILIATION_OPENED' : 'OUTBOX_PAYOUT_UNKNOWN',
          eventId:event.id,
          eventType:event.event_type,
          payoutId:payload.payoutId,
          reason:unknown.reconciliationReason || null,
        });
        return { processed:true, unknown:true, requiresReconciliation:unknown.requiresReconciliation };
      }
      if (result.status !== 'SUCCEEDED' || !result.providerRef) throw new Error(result.status === 'FAILED' ? (result.errorCode || 'PAYOUT_PROVIDER_FAILED') : 'PAYOUT_PROVIDER_UNCONFIRMED');
      const completed = await completePayoutOutbox({ eventId:event.id, payoutId:payload.payoutId, providerRef:result.providerRef, leaseToken:event.lease_token });
      if (!completed?.completed) throw new Error(`OUTBOX_PAYOUT_COMMIT_FAILED:${completed?.reason || 'UNKNOWN'}`);
      recordOutboxProcessed();
      logEvent({ level:'info', action:'OUTBOX_PROCESSED', eventId:event.id, eventType:event.event_type, payoutId:payload.payoutId });
    } else if (event.event_type === 'PAYMENT_RELEASE') {
      const result = await paymentProvider.releaseHold({ paymentId: payload.paymentId, providerRef: payload.providerRef, idempotencyKey: payload.idempotencyKey || `payment-release:${payload.paymentId}` });
      if (result.status !== 'RELEASED' || !result.releaseRef) throw new Error('PAYMENT_PROVIDER_UNCONFIRMED');
      const completed = await completePaymentReleaseOutbox({ eventId:event.id, jobId:payload.jobId, paymentId:payload.paymentId, actorId:payload.ownerId, leaseToken:event.lease_token, providerReleaseRef:result.releaseRef });
      if (!completed?.completed) throw new Error(`OUTBOX_RELEASE_COMMIT_FAILED:${completed?.reason || 'UNKNOWN'}`);
      recordOutboxProcessed();
      logEvent({ level:'info', action:'OUTBOX_PROCESSED', eventId:event.id, eventType:event.event_type });
    } else if (event.event_type === 'AUTH_REFRESH_REUSE_ALERT') {
      const delivered = await dispatchSecurityAlert(event);
      if (!delivered?.dispatched) throw new Error('SECURITY_ALERT_NOT_DISPATCHED');
      const completed = await completeOutboxEvent({eventId:event.id,leaseToken:event.lease_token});
      if (!completed?.completed) throw new Error(`OUTBOX_SECURITY_ALERT_COMMIT_FAILED:${completed?.reason || 'UNKNOWN'}`);
      recordOutboxProcessed();
      logEvent({
        level:'warn',
        action:'SECURITY_ALERT_DISPATCHED',
        eventId:event.id,
        alertCode:payload.alertCode,
      });
    } else if (event.event_type === 'SECURITY_ALERT_TERMINAL_FAILURE_SIGNAL') {
      const sourceEventId=String(payload.sourceEventId || '');
      const validUuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      if (
        event.aggregate_type !== 'outbox_event'
        || String(event.aggregate_id || '') !== sourceEventId
        || !validUuid.test(sourceEventId)
        || payload.sourceEventType !== 'AUTH_REFRESH_REUSE_ALERT'
        || !Number.isSafeInteger(Number(payload.attempts))
        || Number(payload.attempts) < 1
      ) {
        throw new Error('SECURITY_ALERT_TERMINAL_SIGNAL_INVALID');
      }

      // Write before completing the durable signal. A crash after this write
      // can cause a duplicate, so downstream collectors dedupe by signalId.
      await logEventAndWait({
        level:'error',
        action:'OUTBOX_SECURITY_ALERT_TERMINAL_FAILURE',
        eventId:sourceEventId,
        signalId:event.id,
        eventType:payload.sourceEventType,
        attempts:Number(payload.attempts),
        replayCount:Number(payload.replayCount || 0),
        runbook:'docs/runbooks/auth-refresh-token-reuse.md',
      });
      const completed=await completeOutboxEvent({eventId:event.id,leaseToken:event.lease_token});
      if (!completed?.completed) throw new Error(`OUTBOX_SECURITY_ALERT_SIGNAL_COMMIT_FAILED:${completed?.reason || 'UNKNOWN'}`);
      recordOutboxProcessed();
    } else if (event.event_type === 'NOTIFICATION_DISPATCH') {
      const channel = String(payload.channel || '').toUpperCase();
      const url = channel === 'PUSH'
        ? config.notificationPushUrl
        : channel === 'EMAIL'
          ? config.notificationEmailUrl
          : '';
      const result = await dispatchNotificationOutbox(
        event,
        async ({ channel: deliveryChannel, targets, notification }) => {
          for (const target of targets) {
            const body = deliveryChannel === 'PUSH'
              ? {
                  notificationId:notification.id,
                  userId:notification.userId,
                  token:target.token,
                  platform:target.platform,
                  title:notification.title,
                  body:notification.body,
                  data:notification.data || {},
                }
              : {
                  notificationId:notification.id,
                  userId:notification.userId,
                  to:target.email,
                  subject:notification.title,
                  text:notification.body,
                  data:notification.data || {},
                };
            await deliverNotification({
              url,
              payload:body,
              idempotencyKey:`notification:${notification.id}:${deliveryChannel}:${target.token || target.email}`,
            });
          }
        },
        { providerConfigured:channel === 'IN_APP' || Boolean(url) },
      );

      if (result.cancelled) {
        recordOutboxProcessed();
        logEvent({
          level:'info',
          action:'NOTIFICATION_DISPATCH_CANCELLED',
          eventId:event.id,
          notificationId:event.aggregate_id,
          channel,
          reason:result.reason,
        });
      } else if (result.providerNotConfigured) {
        recordOutboxProcessed();
        logEvent({
          level:'info',
          action:'NOTIFICATION_PROVIDER_NOT_CONFIGURED',
          eventId:event.id,
          notificationId:event.aggregate_id,
          channel,
        });
      } else if (result.noTarget) {
        recordOutboxProcessed();
        logEvent({
          level:'info',
          action:'NOTIFICATION_NO_TARGET',
          eventId:event.id,
          notificationId:event.aggregate_id,
          channel,
        });
      } else if (result.processed) {
        recordOutboxProcessed();
        logEvent({
          level:'info',
          action:'NOTIFICATION_DELIVERED',
          eventId:event.id,
          notificationId:event.aggregate_id,
          channel,
          targetCount:result.targetCount || 0,
        });
      } else {
        logEvent({
          level:'debug',
          action:'NOTIFICATION_DISPATCH_STALE',
          eventId:event.id,
          channel,
          reason:result.reason || 'STALE',
        });
      }
    } else {
      throw new Error(`UNSUPPORTED_OUTBOX_EVENT:${event.event_type}`);
    }
    return { processed:true };
  } catch (error) {
    // Metrics and log output are best-effort. A broken telemetry sink must
    // never prevent the lease-checked durable outbox failure transition.
    try {
      recordOutboxFailed();
      const category = failureCategory(event);
      if (category) recordCategoryFailure(category);
      const failureMetadata = normalizeOutboxFailureMetadata({
        eventType:event.event_type,payload:event.payload || {},error,
        retryable:Number(event.attempts || 0) < config.outboxMaxAttempts,
      });
      logEvent({
        level:'warn',action:'OUTBOX_FAILED',eventId:event.id,eventType:event.event_type,
        failureCode:failureMetadata.code,failureCategory:failureMetadata.category,
        retryable:failureMetadata.retryable,httpStatus:failureMetadata.httpStatus,
      });
    } catch {
      // The database Outbox state and structured failure metadata remain the recovery authority.
    }
    const failureResult = await failOutboxEvent({
      eventId:event.id,
      error,
      maxAttempts:config.outboxMaxAttempts,
      leaseToken:event.lease_token,
    });
    return failureResult;
  }
}
