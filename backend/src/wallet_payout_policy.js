import { STAGING_RAILWAY_PROJECT_ID } from './wallet_topup_policy.js';

export function isInternalWalletPayoutEnabled({ paymentProvider, env = process.env } = {}) {
  if (paymentProvider !== 'internal') return false;
  if (env.NODE_ENV !== 'production') return true;
  return env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT === 'true' &&
    env.RAILWAY_PROJECT_ID === STAGING_RAILWAY_PROJECT_ID;
}
