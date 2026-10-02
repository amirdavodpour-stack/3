const normalize = (value) => String(value ?? '').trim();

export function verifyAdminPanelCredentials({ user, name, username, expectedUsername } = {}) {
  const ok = user?.role === 'ADMIN' &&
    normalize(name) === normalize(user.displayName) &&
    normalize(username) !== '' &&
    normalize(expectedUsername) !== '' &&
    normalize(username) === normalize(expectedUsername);
  if (!ok) {
    const error = new Error('ADMIN_PANEL_CREDENTIALS_INVALID');
    error.code = 'ADMIN_PANEL_CREDENTIALS_INVALID';
    error.status = 403;
    throw error;
  }
  return true;
}