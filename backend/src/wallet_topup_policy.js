import { PRODUCTION_RAILWAY_PROJECT_ID, STAGING_RAILWAY_PROJECT_ID, isDesignatedStagingRuntime, isProductionRailwayProject } from './staging_project_identity.js';

export { PRODUCTION_RAILWAY_PROJECT_ID, STAGING_RAILWAY_PROJECT_ID };

export function isInternalWalletUserTopUpEnabled({ paymentProvider, enabled, env = process.env }) {
  if (paymentProvider !== 'internal' || enabled !== true) return false;
  // Project identity wins over NODE_ENV; a misconfigured production environment must fail closed.
  if (isProductionRailwayProject(env)) return false;
  if (env.NODE_ENV !== 'production') return true;
  return env.STAGING_ALLOW_INTERNAL_WALLET_TOPUP === 'true' && isDesignatedStagingRuntime(env);
}
