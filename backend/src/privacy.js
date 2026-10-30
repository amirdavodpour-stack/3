import crypto from 'node:crypto';

export const PRIVACY_VERSION = '1.3';

const MAX_EXPORT_ARRAY_ITEMS = 500;

const normalizeFieldKey = (key) => String(key).replace(/[^a-zA-Z0-9]/g, '').toLowerCase();

const exportSensitiveKeys = new Set(['passwordHash','providerRef','idempotencyKey','dedupeKey','authorization','token','accessToken','refreshToken','cvv','cardNumber','iban'].map(normalizeFieldKey));
const telemetryExportSensitiveKeyPattern = /^(?:name|lat|lng|lon)$|(?:full|first|last|display|user|recipient|sender|owner|candidate|provider|worker|employer|contact|person|applicant|given|family|legal)name$|email|phone|mobile|address|location|coordinates?|latitude|longitude|resume|document|token|password|authorization|cookie|national|iban|card|cvv/i;

function sanitizeExportObject(value, depth = 0) {
  if (value == null || typeof value !== 'object') return value;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value.toISOString();
  // Never return an un-sanitized object merely because its nesting exceeded the safety bound.
  if (depth > 4) return null;
  if (Array.isArray(value)) return value.slice(0, MAX_EXPORT_ARRAY_ITEMS).map(v => sanitizeExportObject(v, depth + 1));
  const out = {};
  for (const [key, val] of Object.entries(value)) {
    const normalizedKey = normalizeFieldKey(key);
    if (exportSensitiveKeys.has(normalizedKey)) continue;
    if ((key === 'stack' || key === 'message' || key === 'details' || key === 'notes') && typeof val === 'string') {
      out[key] = val.slice(0, 4000);
    } else {
      out[key] = sanitizeExportObject(val, depth + 1);
    }
  }
  return out;
}

function sanitizeTelemetryExportObject(value, depth = 0) {
  if (value == null || typeof value !== 'object') return value;
  if (depth > 4) return null;
  if (Array.isArray(value)) return value.slice(0, MAX_EXPORT_ARRAY_ITEMS).map(v => sanitizeTelemetryExportObject(v, depth + 1));
  const out = {};
  for (const [key, val] of Object.entries(value)) {
    const normalizedKey = normalizeFieldKey(key);
    if (exportSensitiveKeys.has(normalizedKey) || telemetryExportSensitiveKeyPattern.test(normalizedKey)) continue;
    if ((key === 'stack' || key === 'message' || key === 'details' || key === 'notes') && typeof val === 'string') {
      out[key] = val.slice(0, 4000);
    } else {
      out[key] = sanitizeTelemetryExportObject(val, depth + 1);
    }
  }
  return out;
}

function sanitizeTelemetryExportRecord(value) {
  const out = sanitizeExportObject(value);
  if (!out || typeof out !== 'object' || Array.isArray(out)) return out;
  if (Object.prototype.hasOwnProperty.call(out, 'properties')) {
    out.properties = sanitizeTelemetryExportObject(out.properties);
  }
  if (Object.prototype.hasOwnProperty.call(out, 'context')) {
    out.context = sanitizeTelemetryExportObject(out.context);
  }
  return out;
}


const sensitiveKeys = new Set([
  'email','emailAddress','phone','phoneNumber','mobile','mobileNumber','name','userName','firstName','lastName',
  'displayName','fullName','address','lat','lng','location','resume','resumeText',
  'token','accessToken','refreshToken','password','passwordHash','authorization',
].map(normalizeFieldKey));
const sensitiveKeyPattern = /password|passwd|token|secret|authorization|cookie|email|phone|mobile|name|address|location|coordinate|latitude|longitude|resume|document|national|iban|card|cvv/i;

export function sanitizeTelemetryProperties(input = {}) {
  const source = input && typeof input === 'object' && !Array.isArray(input) ? input : {};
  const out = {};
  for (const [key, value] of Object.entries(source)) {
    const normalizedKey = normalizeFieldKey(key);
    if (sensitiveKeys.has(normalizedKey) || sensitiveKeyPattern.test(normalizedKey) || ['lat', 'lng', 'lon'].includes(normalizedKey)) continue;
    if (typeof value === 'string' && value.length > 200) out[key] = value.slice(0, 200);
    else if (typeof value === 'number' || typeof value === 'boolean' || value == null || typeof value === 'string') out[key] = value;
  }
  return out;
}

export function anonymizedEmail(userId) { return `deleted+${String(userId).replace(/[^a-zA-Z0-9_-]/g, '').slice(0,32)}@invalid.local`; }
export function deletionCredential() { return crypto.randomBytes(48).toString('hex'); }

export function buildDataExport({ user, provider, jobs = [], applications = [], offers = [], payments = [], walletAccounts = [], walletEntries = [], walletHolds = [], payouts = [], notifications = [], evidence = [], uploads = [], preferences = null, analyticsEvents = [], crashReports = [], trustReports = [], recommendationProfile = null, satisfactionHistory = [], savedSearches = [] }) {
  const exportCollections = {
    jobs, applications, offers, payments, walletAccounts, walletEntries, walletHolds, payouts,
    notifications, evidence, uploads, analyticsEvents, crashReports, trustReports, satisfactionHistory, savedSearches,
  };
  const truncatedTopLevelCollections = Object.entries(exportCollections)
    .filter(([, records]) => Array.isArray(records) && records.length > MAX_EXPORT_ARRAY_ITEMS)
    .map(([name]) => name);
  const safeAccount = sanitizeExportObject({
    id: user.id, email: user.email, displayName: user.displayName, role: user.role, status: user.status, createdAt: user.createdAt,
  });
  return {
    exportVersion: PRIVACY_VERSION,
    exportLimits: {
      maxRecordsPerCollection: MAX_EXPORT_ARRAY_ITEMS,
      truncatedTopLevelCollections,
    },
    generatedAt: new Date().toISOString(),
    account: safeAccount,
    provider: sanitizeExportObject(provider || null),
    jobs: sanitizeExportObject(jobs),
    applications: sanitizeExportObject(applications),
    offers: sanitizeExportObject(offers),
    payments: sanitizeExportObject(payments),
    walletAccounts: sanitizeExportObject(walletAccounts),
    walletEntries: sanitizeExportObject(walletEntries),
    walletHolds: sanitizeExportObject(walletHolds),
    payouts: sanitizeExportObject(payouts),
    notifications: sanitizeExportObject(notifications),
    evidence: sanitizeExportObject(evidence),
    analyticsEvents: sanitizeExportObject(analyticsEvents.map(sanitizeTelemetryExportRecord)),
    crashReports: sanitizeExportObject(crashReports.map(sanitizeTelemetryExportRecord)),
    trustReports: sanitizeExportObject(trustReports),
    uploads: sanitizeExportObject(uploads),
    notificationPreferences: sanitizeExportObject(preferences),
    recommendationProfile: sanitizeExportObject(recommendationProfile),
    satisfactionHistory: sanitizeExportObject(satisfactionHistory),
    savedSearches: sanitizeExportObject(savedSearches),
  };
}
