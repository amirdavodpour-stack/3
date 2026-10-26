export const STAGING_RAILWAY_PROJECT_ID = '8c686259-09c6-4609-bbe7-4ea25e769e18';

export function isInternalWalletUserTopUpEnabled({ paymentProvider, enabled, env = process.env }) {
  if (paymentProvider !== 'internal' || enabled !== true) return false;
  if (env.NODE_ENV !== 'production') return true;
  return env.STAGING_ALLOW_INTERNAL_WALLET_TOPUP === 'true' &&
    env.RAILWAY_PROJECT_ID === STAGING_RAILWAY_PROJECT_ID;
}
