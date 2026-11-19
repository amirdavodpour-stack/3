import { PRODUCTION_RAILWAY_PROJECT_ID, STAGING_RAILWAY_PROJECT_ID } from './railway_project_ids.js';

export function isProductionRailwayProject(env = process.env) {
  return env.RAILWAY_PROJECT_ID === PRODUCTION_RAILWAY_PROJECT_ID;
}

export function isDesignatedRenderStagingService(env = process.env) {
  const serviceId = String(env.RENDER_SERVICE_ID || '').trim();
  const approvedServiceId = String(env.STAGING_RENDER_SERVICE_ID || '').trim();
  return env.RENDER === 'true'
    && env.HOPE_STAGING_MODE === 'true'
    && env.HOPE_STAGING_PROVIDER === 'render'
    && serviceId.length > 0
    && approvedServiceId.length > 0
    && serviceId === approvedServiceId;
}

export function isDesignatedStagingRuntime(env = process.env) {
  if (isProductionRailwayProject(env)) return false;
  return env.RAILWAY_PROJECT_ID === STAGING_RAILWAY_PROJECT_ID || isDesignatedRenderStagingService(env);
}

export { PRODUCTION_RAILWAY_PROJECT_ID, STAGING_RAILWAY_PROJECT_ID };
