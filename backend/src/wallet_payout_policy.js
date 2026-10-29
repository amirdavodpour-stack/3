import { STAGING_RAILWAY_PROJECT_ID } from './wallet_topup_policy.js';

export const PRODUCTION_RAILWAY_PROJECT_ID = 'b12b7c1e-4dcc-470e-b87a-c63035c6e342';

export function isInternalWalletPayoutEnabled({ paymentProvider, env = process.env } = {}) {
  if (paymentProvider !== 'internal') return false;
  // Never enable the synthetic payout adapter on the actual production project,
  // even if NODE_ENV is missing or accidentally misconfigured.
  if (env.RAILWAY_PROJECT_ID === PRODUCTION_RAILWAY_PROJECT_ID) return false;
  if (env.NODE_ENV !== 'production') return true;
  return env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT === 'true' &&
    env.RAILWAY_PROJECT_ID === STAGING_RAILWAY_PROJECT_ID;
}
