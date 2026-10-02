import { signAccessToken, verifyAccessToken } from '../security.js';

const normalize = (value) => String(value ?? '').trim();

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
