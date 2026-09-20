import { creditWallet, transferAvailable, INTERNAL_CURRENCY } from '../wallet_ledger.js';
import { requestPayoutAtomic, listPayoutsForUser } from '../repository/payouts.js';

export function createWalletRoutes({ authUser, adminGuard, readBody, sendJson, HttpError, config, walletRepo }) {
  return async function walletRoutes(req, res, parts) {
    if (req.method === 'GET' && parts[1] === 'me') {
      const me = await authUser(req);
      const wallet = await walletRepo.getWalletForUser(me.id);
      return sendJson(res, 200, { wallet: wallet || { currency: INTERNAL_CURRENCY, availableBalance: '0', lockedBalance: '0', status: 'ACTIVE' }, currency: INTERNAL_CURRENCY });
    }
    if (req.method === 'GET' && parts[1] === 'transactions') {
      const me = await authUser(req);
      const url = new URL(req.url, 'http://localhost');
      let result;
      try {
        result = await walletRepo.listWalletTransactions(me.id, INTERNAL_CURRENCY, {
          limit: url.searchParams.get('limit'),
          cursor: url.searchParams.get('cursor'),
        });
      } catch (error) {
        if (error.code === 'INVALID_CURSOR') throw new HttpError(400, 'INVALID_CURSOR', 'Invalid wallet transaction cursor');
        throw error;
      }
      return sendJson(res, 200, { currency: INTERNAL_CURRENCY, transactions: result.items, nextCursor: result.nextCursor });
    }
    if (req.method === 'POST' && parts[1] === 'transfer') {
      const me = await authUser(req);
      const body = await readBody(req);
      const destinationWalletId = String(body?.destinationWalletId || '').trim();
      const destinationUserId = String(body?.destinationUserId || '').trim();
      if ((!destinationWalletId && !destinationUserId) || !body?.amount || !body?.idempotencyKey) {
        throw new HttpError(400,'INVALID_WALLET_TRANSFER','destinationWalletId, amount and idempotencyKey are required');
      }
      try {
        let resolvedDestinationUserId = destinationUserId;
        let resolvedWalletId = destinationWalletId || null;
        if (destinationWalletId) {
          const destinationWallet = await walletRepo.getWalletById(destinationWalletId);
          if (!destinationWallet) throw Object.assign(new Error('WALLET_NOT_FOUND'), { code: 'WALLET_NOT_FOUND' });
          resolvedDestinationUserId = destinationWallet.userId;
          resolvedWalletId = destinationWallet.id;
        }
        const result = await transferAvailable({ sourceUserId:me.id, destinationUserId:String(resolvedDestinationUserId), amount:body.amount, idempotencyKey:String(body.idempotencyKey), referenceType:'WALLET_TRANSFER', referenceId:null, metadata:{ source:'api', destinationWalletId:resolvedWalletId } });
        return sendJson(res, 200, result);
      } catch (error) {
        if (error.code === 'INSUFFICIENT_FUNDS') throw new HttpError(409,'INSUFFICIENT_FUNDS','Insufficient internal currency balance');
        if (error.code === 'INVALID_AMOUNT') throw new HttpError(400,'INVALID_AMOUNT','Amount must be a positive integer amount in TOMAN');
        if (error.code === 'IDEMPOTENCY_CONFLICT') throw new HttpError(409,'IDEMPOTENCY_CONFLICT','Idempotency key was already used for different transfer parameters');
        if (error.code === 'IDEMPOTENCY_IN_PROGRESS') throw new HttpError(409,'IDEMPOTENCY_IN_PROGRESS','An identical transfer is already being processed');
        if (error.code === 'WALLET_NOT_FOUND') throw new HttpError(404,'WALLET_NOT_FOUND','Destination wallet not found');
        if (error.code === 'WALLET_UNAVAILABLE') throw new HttpError(409,'WALLET_UNAVAILABLE','Wallet is unavailable');
        if (error.code === 'SELF_TRANSFER_NOT_ALLOWED') throw new HttpError(400,'SELF_TRANSFER_NOT_ALLOWED','Source and destination wallets must differ');
        throw error;
      }
    }
    if (req.method === 'GET' && parts[1] === 'payouts') {
      const me = await authUser(req);
      const url = new URL(req.url, 'http://localhost');
      const payouts = await listPayoutsForUser(me.id, { limit: url.searchParams.get('limit') });
      return sendJson(res, 200, { currency: INTERNAL_CURRENCY, payouts });
    }
    if (req.method === 'POST' && parts[1] === 'withdraw') {
      const me = await authUser(req);
      const body = await readBody(req);
      if (!body?.amount || !body?.idempotencyKey) throw new HttpError(400,'INVALID_WITHDRAWAL','amount and idempotencyKey are required');
      try {
        const payout = await requestPayoutAtomic({ userId:me.id, amount:body.amount, idempotencyKey:String(body.idempotencyKey), referenceType:'PAYOUT', referenceId:null });
        return sendJson(res, 202, { payout, currency:INTERNAL_CURRENCY, status:payout.status });
      } catch (error) {
        if (error.code === 'INSUFFICIENT_FUNDS') throw new HttpError(409,'INSUFFICIENT_FUNDS','Insufficient internal currency balance');
        if (error.code === 'INVALID_AMOUNT') throw new HttpError(400,'INVALID_AMOUNT','Amount must be a positive integer amount in TOMAN');
        if (error.code === 'IDEMPOTENCY_CONFLICT') throw new HttpError(409,'IDEMPOTENCY_CONFLICT','Idempotency key was already used for different payout parameters');
        if (error.code === 'WALLET_NOT_FOUND') throw new HttpError(404,'WALLET_NOT_FOUND','Wallet not found');
        if (error.code === 'WALLET_UNAVAILABLE') throw new HttpError(409,'WALLET_UNAVAILABLE','Wallet is unavailable');
        if (error.code === 'PAYOUT_PROVIDER_NOT_ENABLED') throw new HttpError(409,'PAYOUT_NOT_AVAILABLE','Payout is not enabled in this environment');
        throw error;
      }
    }
    if (req.method === 'POST' && parts[1] === 'top-up') {
      const me = await authUser(req);
      // Production deployments keep this endpoint off by default. The
      // explicit staging flag permits the internal TOMAN funding path in the
      // hardening environment even though Railway's environment is named
      // "production". It never enables an external payment provider.
      const stagingSandbox = process.env.STAGING_ALLOW_INTERNAL_WALLET_TOPUP === 'true';
      const enabled = config.paymentProvider === 'internal' && config.internalWalletUserTopUpEnabled && (process.env.NODE_ENV !== 'production' || stagingSandbox);
      if (!enabled) {
        throw new HttpError(404, 'NOT_FOUND', 'Wallet top-up is disabled in this environment');
      }
      const body = await readBody(req);
      if (!body?.amount || !body?.idempotencyKey) throw new HttpError(400, 'INVALID_TOP_UP', 'amount and idempotencyKey are required');
      try {
        const result = await creditWallet({
          userId: me.id,
          amount: body.amount,
          idempotencyKey: `user-topup:${body.idempotencyKey}`,
          referenceType: 'WALLET_TOP_UP',
          metadata: { source: 'internal-provider', sandbox: true },
          actorId: me.id,
        });
        return sendJson(res, 200, { ...result, status: 'SUCCEEDED', sandbox: true });
      } catch (error) {
        if (error.code === 'INVALID_AMOUNT') throw new HttpError(400, 'INVALID_AMOUNT', 'Amount must be a positive integer amount in TOMAN');
        if (error.code === 'IDEMPOTENCY_CONFLICT') throw new HttpError(409, 'IDEMPOTENCY_CONFLICT', 'Idempotency key was already used for different top-up parameters');
        if (error.code === 'IDEMPOTENCY_IN_PROGRESS') throw new HttpError(409, 'IDEMPOTENCY_IN_PROGRESS', 'An identical top-up is already being processed');
        throw error;
      }
    }
    if (req.method === 'POST' && parts[1] === 'sandbox-credit') {
      const me = await authUser(req);
      await adminGuard(me);
      if (process.env.NODE_ENV === 'production' && !config.internalWalletAdminCreditEnabled) {
        throw new HttpError(404,'NOT_FOUND','Wallet sandbox credit is disabled');
      }
      const body = await readBody(req);
      if (!body?.userId || !body?.amount || !body?.idempotencyKey) throw new HttpError(400,'INVALID_SANDBOX_CREDIT','userId, amount and idempotencyKey are required');
      const result = await creditWallet({ userId:String(body.userId), amount:body.amount, idempotencyKey:`sandbox:${body.idempotencyKey}`, metadata:{ actorId:me.id, sandbox:true } });
      return sendJson(res, 200, result);
    }
    throw new HttpError(404,'NOT_FOUND','Wallet route not found');
  };
}