import { signAccessToken, verifyAccessToken } from '../security.js';

const normalize = (value) => String(value ?? '').trim();

export const PRIMARY_ADMIN_EMAIL = 'amir.davodpour@gmail.com';

export const ADMIN_PERMISSIONS = Object.freeze({
  VIEW_ADMIN_CENTER: 'admin.view_center',
  MANAGE_USERS: 'admin.manage_users',
  MODERATE_JOBS: 'admin.moderate_jobs',
  DELETE_JOBS: 'admin.delete_jobs',
  MANAGE_APPLICATIONS: 'admin.manage_applications',
  TRUST_SAFETY: 'admin.trust_safety',
  VIEW_FINANCE: 'admin.view_finance',
  VIEW_PAYOUTS: 'admin.view_payouts',
  RESOLVE_DISPUTES: 'admin.resolve_disputes',
  RESOLVE_PAYOUTS: 'admin.resolve_payouts',
  VIEW_AUDIT: 'admin.view_audit',
  MANAGE_ADMINS: 'admin.manage_admins',
  REVOKE_SESSIONS: 'admin.revoke_sessions',
});

const OPERATIONAL_ADMIN_PERMISSIONS = Object.freeze([
  ADMIN_PERMISSIONS.VIEW_ADMIN_CENTER,
  ADMIN_PERMISSIONS.MANAGE_USERS,
  ADMIN_PERMISSIONS.MODERATE_JOBS,
  ADMIN_PERMISSIONS.MANAGE_APPLICATIONS,
  ADMIN_PERMISSIONS.TRUST_SAFETY,
  ADMIN_PERMISSIONS.VIEW_FINANCE,
  ADMIN_PERMISSIONS.VIEW_PAYOUTS,
  ADMIN_PERMISSIONS.VIEW_AUDIT,
]);

export function isPrimaryAdminEmail(email) {
  return normalize(email).toLowerCase() === PRIMARY_ADMIN_EMAIL;
}

export function shouldBootstrapPrimaryAdmin({ email, verifiedIdentity = false } = {}) {
  return Boolean(verifiedIdentity) && isPrimaryAdminEmail(email);
}

export function isPrimaryAdmin(user) {
  return user?.role === 'ADMIN' && isPrimaryAdminEmail(user.email);
}

export function getAdminPermissions(user) {
  if (user?.role !== 'ADMIN') return [];
  if (isPrimaryAdmin(user)) return Object.values(ADMIN_PERMISSIONS);
  return [...OPERATIONAL_ADMIN_PERMISSIONS];
}

export function hasAdminPermission(user, permission) {
  return getAdminPermissions(user).includes(permission);
}

export function assertAdminPermission(user, permission) {
  if (!hasAdminPermission(user, permission)) {
    const error = new Error('ADMIN_PERMISSION_DENIED');
    error.code = 'ADMIN_PERMISSION_DENIED';
    error.status = 403;
    throw error;
  }
  return true;
}

export function assertPrimaryAdmin(user) {
  if (!isPrimaryAdmin(user)) {
    const error = new Error('PRIMARY_ADMIN_ONLY');
    error.code = 'PRIMARY_ADMIN_ONLY';
    error.status = 403;
    throw error;
  }
  return true;
}

export function verifyAdminPanelCredentials({ user, name, username, expectedUsername, expectedEmail } = {}) {
  const ok = user?.role === 'ADMIN' &&
    normalize(name) === normalize(user.displayName) &&
    normalize(username) !== '' &&
    normalize(expectedUsername) !== '' &&
    normalize(username) === normalize(expectedUsername) &&
    (!normalize(expectedEmail) || normalize(user.email).toLowerCase() === normalize(expectedEmail).toLowerCase());
  if (!ok) {
    const error = new Error('ADMIN_PANEL_CREDENTIALS_INVALID');
    error.code = 'ADMIN_PANEL_CREDENTIALS_INVALID';
    error.status = 403;
    throw error;
  }
  return true;
}

export function issueAdminPanelToken({ user, secret, ttlSeconds = 900 } = {}) {
  if (!user?.id || user.role !== 'ADMIN' || !secret) {
    const error = new Error('ADMIN_PANEL_TOKEN_INVALID');
    error.code = 'ADMIN_PANEL_TOKEN_INVALID';
    error.status = 403;
    throw error;
  }
  return signAccessToken(
    { sub: user.id, role: 'ADMIN', sv: Number(user.sessionVersion || 0), purpose: 'ADMIN_PANEL' },
    secret,
    ttlSeconds,
    { issuer: 'hope-admin-panel', audience: 'hope-admin-panel' },
  );
}

export function verifyAdminPanelToken(token, secret) {
  try {
    const payload = verifyAccessToken(token, secret, {
      issuer: 'hope-admin-panel',
      audience: 'hope-admin-panel',
      maxBytes: 8192,
    });
    if (payload.role !== 'ADMIN' || payload.purpose !== 'ADMIN_PANEL' || !payload.sub) throw new Error('invalid');
    return payload;
  } catch {
    const error = new Error('ADMIN_PANEL_TOKEN_INVALID');
    error.code = 'ADMIN_PANEL_TOKEN_INVALID';
    error.status = 403;
    throw error;
  }
}
