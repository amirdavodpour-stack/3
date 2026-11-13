import { PRODUCTION_RAILWAY_PROJECT_ID, STAGING_RAILWAY_PROJECT_ID } from './railway_project_ids.js';

export { PRODUCTION_RAILWAY_PROJECT_ID, STAGING_RAILWAY_PROJECT_ID };

export function isInternalWalletUserTopUpEnabled({ paymentProvider, enabled, env = process.env }) {
  if (paymentProvider !== 'internal' || enabled !== true) return false;
  // Project identity wins over NODE_ENV; a misconfigured production environment must fail closed.
  if (env.RAILWAY_PROJECT_ID === PRODUCTION_RAILWAY_PROJECT_ID) return false;
  if (env.NODE_ENV !== 'production') return true;
  return env.STAGING_ALLOW_INTERNAL_WALLET_TOPUP === 'true' &&
    env.RAILWAY_PROJECT_ID === STAGING_RAILWAY_PROJECT_ID;
}
