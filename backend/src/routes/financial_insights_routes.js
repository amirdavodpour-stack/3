import { getWalletFinancialInsights } from '../repository/financial_insights.js';

export function createFinancialInsightsRoutes({ authUser, sendJson, HttpError, repo = null }) {
  return async function financialInsightsRoutes(req, res, parts) {
    if (parts.length !== 2 || parts[0] !== 'wallet' || parts[1] !== 'financial-insights') {
      throw new HttpError(404, 'NOT_FOUND', 'Financial insights route not found');
    }
    if (req.method !== 'GET') throw new HttpError(405, 'METHOD_NOT_ALLOWED', 'Method not allowed');
    const me = await authUser(req);
    const url = new URL(req.url, 'http://localhost');
    const months = Math.min(Math.max(Number(url.searchParams.get('months')) || 6, 1), 12);
    const insights = await getWalletFinancialInsights(me.id, { months });
    return sendJson(res, 200, insights);
  };
}
