import { OAuth2Client } from 'google-auth-library';

const googleClient = new OAuth2Client();

export async function verifyGoogleIdToken(idToken, audience) {
  const token = String(idToken || '').trim();
  const expectedAudience = String(audience || '').trim();
  if (!token || token.length > 16_384) throw new Error('INVALID_GOOGLE_TOKEN');
  if (!expectedAudience) throw new Error('GOOGLE_AUTH_NOT_CONFIGURED');

  const ticket = await googleClient.verifyIdToken({
    idToken: token,
    audience: expectedAudience,
  });
  const payload = ticket.getPayload();
  if (!payload || !payload.sub || !payload.email || payload.email_verified !== true) {
    throw new Error('INVALID_GOOGLE_TOKEN');
  }

  const issuer = String(payload.iss || '');
  if (issuer !== 'accounts.google.com' && issuer !== 'https://accounts.google.com') {
    throw new Error('INVALID_GOOGLE_TOKEN');
  }

  const displayName = String(payload.name || payload.given_name || payload.email.split('@')[0]).trim().slice(0, 120);
  return {
    subject: String(payload.sub),
    email: String(payload.email).trim().toLowerCase(),
    displayName: displayName || 'HOPE user',
    picture: payload.picture ? String(payload.picture) : null,
    locale: payload.locale ? String(payload.locale) : null,
  };
}
