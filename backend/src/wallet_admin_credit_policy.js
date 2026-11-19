import { isDesignatedStagingRuntime, isProductionRailwayProject } from './staging_project_identity.js';

export function isInternalWalletAdminCreditEnabled({ enabled, env = process.env } = {}) {
  // The real production project must never allow synthetic admin-issued credit,
  // even if NODE_ENV is misconfigured or the feature flag is accidentally true.
  if (isProductionRailwayProject(env)) return false;

  // Local, test and non-production environments retain the existing sandbox
  // workflow. Railway's staging environment may itself be named "production",
  // so production-mode exceptions require both the explicit flag and exact project.
  if (env.NODE_ENV !== 'production') return true;

  return enabled === true && isDesignatedStagingRuntime(env);
}
