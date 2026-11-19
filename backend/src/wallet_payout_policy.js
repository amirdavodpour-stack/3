import { PRODUCTION_RAILWAY_PROJECT_ID, isDesignatedStagingRuntime, isProductionRailwayProject } from './staging_project_identity.js';

export { PRODUCTION_RAILWAY_PROJECT_ID };

export function isInternalWalletPayoutEnabled({ paymentProvider, env = process.env } = {}) {
  if (paymentProvider !== 'internal') return false;
  // Never enable the synthetic payout adapter on the actual production project,
  // even if NODE_ENV is missing or accidentally misconfigured.
  if (isProductionRailwayProject(env)) return false;
  if (env.NODE_ENV !== 'production') return true;
  return env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT === 'true' && isDesignatedStagingRuntime(env);
}
