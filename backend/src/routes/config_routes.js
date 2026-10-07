export function createConfigRoutes({ sendJson, config }) {
  return async function configRoutes(req, res, parts) {
    if (req.method !== 'GET' || parts.length !== 1 || parts[0] !== 'capabilities') {
      return false;
    }

    const internalTopUp =
      config.paymentProvider === 'internal' &&
      config.internalWalletUserTopUpEnabled &&
      (process.env.NODE_ENV !== 'production' ||
        process.env.STAGING_ALLOW_INTERNAL_WALLET_TOPUP === 'true');

    return sendJson(res, 200, {
      capabilities: {
        googleSignIn: Boolean(config.googleAuthEnabled && config.googleOAuthClientId),
        wallet: true,
        walletTransfer: true,
        walletWithdraw: config.paymentProvider === 'internal',
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
