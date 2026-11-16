import { isInternalWalletUserTopUpEnabled } from '../wallet_topup_policy.js';
import { isInternalWalletPayoutEnabled } from '../wallet_payout_policy.js';

export function createConfigRoutes({ sendJson, config, env = process.env }) {
  return async function configRoutes(req, res, parts) {
    if (req.method !== 'GET' || parts.length !== 1 || parts[0] !== 'capabilities') {
      return false;
    }

    const internalTopUp = isInternalWalletUserTopUpEnabled({
      paymentProvider: config.paymentProvider,
      enabled: config.internalWalletUserTopUpEnabled,
    });
    const internalPayout = isInternalWalletPayoutEnabled({
      paymentProvider: config.paymentProvider,
      env,
    });

    return sendJson(res, 200, {
      capabilities: {
        googleSignIn: Boolean(config.googleAuthEnabled && config.googleOAuthClientId),
        wallet: true,
        walletTransfer: true,
        walletWithdraw: internalPayout,
        walletDeposit: internalTopUp,
        notifications: true,
        savedOpportunities: false,
        matchImprovementHints: false,
        candidateComparison: false,
        lifetimeEarnings: false,
        verifiedIdentity: true,
        reputation: false,
        responseTime: false,
        distance: true,
        humanReferences: false,
      },
      currency: String(config.paymentCurrency || 'TOMAN').toUpperCase(),
    });
  };
}
