import { createServer } from 'node:http';
import { URL } from 'node:url';
import crypto from 'node:crypto';
import { config, HOPE_VERSION } from './config.js';
import { initDatabase, db, isPostgresConfigured } from './db.js';
import { createRepositories } from './repositories/index.js';
import { createRepositoryPorts } from './application/ports.js';
import { createPaymentUseCases } from './application/use_cases/payment_use_cases.js';
import { createJobUseCases } from './application/use_cases/job_use_cases.js';
import { createApplicationUseCases } from './application/use_cases/application_use_cases.js';
import { createAdminUseCases } from './application/use_cases/admin_use_cases.js';
import { createAppViewHelpers } from './application/view_helpers.js';
import { createWalletRoutes } from './routes/wallet_routes.js';
import { createAccountRoutes } from './routes/account_routes.js';
import { createAuthRoutes } from './routes/auth_routes.js';
import { createProviderRoutes } from './routes/provider_routes.js';
import { createPaymentRoutes } from './routes/payment_routes.js';
import { createJobRoutes } from './routes/job_routes.js';
import { createOfferRoutes } from './routes/offer_routes.js';
import { createSavedSearchRoutes } from './routes/saved_search_routes.js';
import { createApplicationRoutes } from './routes/application_routes.js';
import { createStorageRoutes } from './routes/storage_routes.js';
import { createAdminRoutes } from './routes/admin_routes.js';
import { createHealthRoutes } from './routes/health_routes.js';
import { createAnalyticsRoutes } from './routes/analytics_routes.js';
import { createNotificationRoutes } from './routes/notification_routes.js';
import { createObservabilityRoutes } from './routes/observability_routes.js';
import { createErrorHandler, HttpError, sendJson, readBody, readRawBody, readMultipartSingleFile } from './http.js';
import { authUser, getUserByEmail, getUserById, findUser, issueSession, hashPassword, verifyPassword, DUMMY_PASSWORD_HASH, passwordNeedsRehash, PASSWORD_MAX_LENGTH, randomToken, sha256, signAccessToken, requireAdmin } from './auth.js';
import { now } from './utils.js';
import { anonymizedEmail, buildDataExport, deletionCredential } from './privacy.js';
import { logEvent } from './observability.js';
import { rateLimitAuthAccount } from './rate_limit.js';
import { notifyUser, notifyApplicationCandidate, NOTIFICATION_TYPES } from './notifications.js';
import { createAudit, getJob, calculatePaymentBreakdown } from './service.js';
import { processPaymentCreateHoldNow, processPaymentReleaseNow, processPaymentRefundNow } from './application/payments.js';
import { fundingJournal, releaseJournal, payoutJournal, refundJournal } from './application/financial_journals.js';
import { createAccountLegacyAdapter } from './application/legacy/account_legacy.js';
import { createAdminLegacyAdapter } from './application/legacy/admin_legacy.js';
import { createApplicationLegacyAdapter } from './application/legacy/application_legacy.js';
import { createAuthLegacyAdapter } from './application/legacy/auth_legacy.js';
import { createJobLegacyAdapter } from './application/legacy/job_legacy.js';
import { createOfferLegacyAdapter } from './application/legacy/offer_legacy.js';
import { createPaymentLegacyAdapter } from './application/legacy/payment_legacy.js';
import { createSavedSearchLegacy } from './application/legacy/saved_search_legacy.js';
import { createStorageLegacyAdapter } from './application/legacy/storage_legacy.js';
import { enumField, textField, moneyField, tomanField, dateOnlyField, requireFields } from './validation.js';
import { JOB_TYPES, JOB_KINDS, JOB_VISIBILITY, JOB_SCHEDULES, BUDGET_TYPES } from './taxonomy.js';

const repositories = createRepositories({ db, config });
const repo = repositories;
const isTestRuntime = process.env.NODE_ENV === 'test';
const storage = repositories.storage;
const viewCategories = repositories.categories || [];
const appLegacy = repositories.legacy;

function createRequestContext(input) {
  return Object.freeze({ ...input });
}

function requestId(req) {
  return req.headers['x-request-id'] || crypto.randomUUID();
}

function traceContext(req) {
  const header = req.headers.traceparent;
  if (header) {
    const parts = String(header).split('-');
    if (parts.length === 4 && /^[0-9a-f]{32}$/.test(parts[1])) return { traceId: parts[1], parentSpanId: parts[2] };
  }
  return { traceId: crypto.randomBytes(16).toString('hex'), parentSpanId: null };
}

function handleRouteError(error, req, res) {
  if (error instanceof HttpError) return sendJson(res, error.status, { error: error.code, message: error.message });
  const rid = req.context?.requestId;
  console.error('[request-error]', { requestId: rid, error });
  return sendJson(res, 500, { error: 'INTERNAL_ERROR', message: 'Internal server error', requestId: rid });
}

let initialized = false;
export async function initialize() {
  if (!initialized) {
    await initDatabase();
    initialized = true;
  }
  return { repositories, config, isPostgresConfigured, version: HOPE_VERSION };
}

const findUserById = (id) => process.env.DATABASE_URL ? repo.findUserById(id) : appLegacy.findUserById(id);
const findUserLegacyAware = findUserById;
const findUserView = (id) => process.env.DATABASE_URL ? undefined : appLegacy.findUserById(id);
const findUser = (id) => process.env.DATABASE_URL ? undefined : appLegacy.findUserById(id);
async function getJob(id) { return process.env.DATABASE_URL ? repo.findJobById(id) : appLegacy.findJobById(id); }

const repositoryPorts = createRepositoryPorts(repo);
const paymentUseCases = createPaymentUseCases({ payments: repositoryPorts.payments });
const jobUseCases = createJobUseCases({ jobs: repositoryPorts.jobs });
const applicationUseCases = createApplicationUseCases({ applications: repositoryPorts.applications });
const adminUseCases = createAdminUseCases({ admin: repositoryPorts.admin });
const adminLegacy = createAdminLegacyAdapter({ db, findUser, now });
const accountLegacy = createAccountLegacyAdapter({ db, findUser, now });
const paymentLegacy = createPaymentLegacyAdapter({ db, withTransaction: db.withTransaction, fundingJournal, refundJournal, releaseJournal, payoutJournal, now });
const authLegacy = createAuthLegacyAdapter({ db, findUser, issueSession, withTransaction: db.withTransaction, now });
const applicationLegacy = createApplicationLegacyAdapter({ db, id: db.id, now });
const offerLegacy = createOfferLegacyAdapter({ db, id: db.id, now, withTransaction: db.withTransaction });
const storageLegacy = createStorageLegacyAdapter({ db, id: db.id, now });

const storageRoutes = createStorageRoutes({
  authUser, storage, config, readBody, readMultipartSingleFile, requireFields, stringField: textField,
  sendJson, HttpError, repo, legacy: storageLegacy, id: db.id, now, logEvent,
});

const adminRoutes = createAdminRoutes({
  authUser, requireAdmin, readBody, sendJson, HttpError, enumField, repo, adminUseCases, legacyAdmin: adminLegacy, config, now, paymentUseCases,
  createAudit: (...args) => createAudit(...args), findUser, getJob: (...args) => getJob(...args),
  notifyApplicationCandidate: (...args) => notifyApplicationCandidate(...args), URL,
  listUnknownPayouts: repo.listUnknownPayouts,
  resolvePayoutUnknown: repo.resolvePayoutUnknown,
});

const accountRoutes = createAccountRoutes({
  authUser, readBody, sendJson, HttpError, hashPassword, privacyRepo: repositoryPorts.privacy, legacyAccount: accountLegacy, storage, anonymizedEmail, deletionCredential, buildDataExport, logEvent,
});

const {
  getProvider, categoryBy, publicUser, authUserView, categoryView, buildOfferCountMap,
  offerCountFor, jobView, paymentView, relatedJob, enforceJobState, createAudit: createViewAudit,
} = createAppViewHelpers({
  repo, config, getUserById, now, HttpError, env: process.env, categories: viewCategories, id: appLegacy.id,
  legacy: process.env.DATABASE_URL ? {} : {
    providers: appLegacy.findProvidersForView(),
    offers: appLegacy.findOffersForView(),
    insertAudit: appLegacy.insertAudit,
  },
});

const jobLegacy = createJobLegacyAdapter({ db, categoryBy, relatedJob, findUser, publicUser, now });

const authRoutes = createAuthRoutes({
  authUser, authUserView, getUserByEmail, issueSession, deliverPasswordReset: authLegacy.deliverPasswordReset, findUser, rateLimitAuthAccount,
  readBody, sendJson, HttpError, requireFields, repo, config, now, hashPassword,
  verifyPassword, passwordNeedsRehash, PASSWORD_MAX_LENGTH, randomToken, sha256, signAccessToken, createViewAudit, DUMMY_PASSWORD_HASH, logEvent, stringField: textField,
  id: db.id, legacy: authLegacy,
});
const providerRoutes = createProviderRoutes({
  authUser, getProvider, publicUser, repo, sendJson, HttpError, now, id: appLegacy.id,
  insertProvider: appLegacy.insertProvider,
  legacy: { jobs: process.env.DATABASE_URL ? [] : appLegacy.jobs() },
});
const paymentRoutes = createPaymentRoutes({
  authUser, readBody, readRawBody, sendJson, HttpError, config, repo, getJob, enforceJobState, paymentUseCases,
  readIdempotencyKey: (req) => req.headers['idempotency-key'] || null, requireFields, enumField, paymentView, relatedJob, withTransaction: db.withTransaction, createAudit,
  calculatePaymentBreakdown, fundingJournal, releaseJournal, payoutJournal, refundJournal, paymentLegacy, processPaymentCreateHoldNow,
  processPaymentReleaseNow, processPaymentRefundNow, notifyUser, NOTIFICATION_TYPES, logEvent, now,
});

const jobRoutes = createJobRoutes({ getJob, authUser, id: db.id, repo, legacyJobs: jobLegacy, jobUseCases, readBody, sendJson, HttpError, requireFields, textField, moneyField, tomanField, enumField, JOB_TYPES, JOB_KINDS, JOB_VISIBILITY, JOB_SCHEDULES, BUDGET_TYPES, dateOnlyField, categoryBy, jobView, paymentView, buildOfferCountMap, relatedJob, enforceJobState, createAudit, now, findUser, publicUser, notifyApplicationCandidate, NOTIFICATION_TYPES });
const offerRoutes = createOfferRoutes({ authUser, readBody, sendJson, HttpError, requireFields, textField, moneyField, tomanField, repo, legacy: offerLegacy, id: db.id, getJob, enforceJobState, createAudit, now, jobView });
const savedSearchLegacy = createSavedSearchLegacy({ db, textField, now });
const savedSearchRoutes = createSavedSearchRoutes({ authUser, repo, legacy: savedSearchLegacy, readBody, sendJson, HttpError, textField });
const applicationRoutes = createApplicationRoutes({ authUser, readBody, sendJson, HttpError, requireFields, textField, repo, applicationUseCases, legacy: applicationLegacy, id: db.id, getJob, createAudit, now, notifyUser, NOTIFICATION_TYPES });

export async function handle(req, res) {
  const startedAt = process.hrtime.bigint();
  const rid = requestId(req);
  const trace = traceContext(req);
  Object.defineProperty(req, 'context', {
    value: createRequestContext({
      requestId: rid,
      traceId: trace.traceId,
      method: req.method,
      path: new URL(req.url, `http://${req.headers.host || 'localhost'}`).pathname,
    }),
    enumerable: false,
    configurable: false,
    writable: false,
  });
  res.setHeader('X-Request-Id', rid);
  res.setHeader('X-Trace-Id', trace.traceId);
  try {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const pathname = url.pathname;
    const method = req.method || 'GET';
    if (pathname === '/live' || pathname === '/health') return (await createHealthRoutes({ repo, config, HOPE_VERSION }).handle(method, pathname, req, res));
    if (pathname.startsWith('/api/auth')) return authRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/providers')) return providerRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/payments')) return paymentRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/jobs')) return jobRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/offers')) return offerRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/saved-searches')) return savedSearchRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/applications')) return applicationRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/wallet')) return walletRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/account')) return accountRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/storage')) return storageRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/admin')) return adminRoutes(method, pathname, req, res);
    if (pathname.startsWith('/api/analytics')) return createAnalyticsRoutes({ authUser, repo, logEvent }).handle(method, pathname, req, res);
    if (pathname.startsWith('/api/notifications')) return createNotificationRoutes({ authUser, repo }).handle(method, pathname, req, res);
    if (pathname.startsWith('/api/observability')) return createObservabilityRoutes({ authUser, repo, config }).handle(method, pathname, req, res);
    sendJson(res, 404, { error: 'NOT_FOUND' });
  } catch (error) {
    handleRouteError(error, req, res);
  } finally {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1e6;
    res.setHeader('Server-Timing', `app;dur=${durationMs.toFixed(1)}`);
  }
}

export async function createAppServer() {
  await initialize();
  return createServer((req, res) => handle(req, res));
}
