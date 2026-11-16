import { PRODUCTION_RAILWAY_PROJECT_ID, STAGING_RAILWAY_PROJECT_ID } from './railway_project_ids.js';

export { PRODUCTION_RAILWAY_PROJECT_ID };

export function isInternalWalletPayoutEnabled({ paymentProvider, env = process.env } = {}) {
  if (paymentProvider !== 'internal') return false;
  // Never enable the synthetic payout adapter on the actual production project,
  // even if NODE_ENV is missing or accidentally misconfigured.
  if (env.RAILWAY_PROJECT_ID === PRODUCTION_RAILWAY_PROJECT_ID) return false;
  if (env.NODE_ENV !== 'production') return true;
  return env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT === 'true' &&
    env.RAILWAY_PROJECT_ID === STAGING_RAILWAY_PROJECT_ID;
}
