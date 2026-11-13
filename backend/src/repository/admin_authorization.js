const DEFAULT_PRIMARY_ADMIN_EMAIL = 'amir.davodpour@gmail.com';

function fail(code, message, status = 403) {
  const error = new Error(message);
  error.code = code;
  error.status = status;
  throw error;
}

/**
 * Revalidate an administrator while holding the account row lock.
 * All callers must invoke this helper before locking domain rows. Optional
 * target users are locked in the same deterministic UUID order as the actor
 * to avoid reciprocal actor/target deadlocks.
 */
export async function lockAuthorizedAdminActor(client, {
  actorId,
  targetUserIds = [],
  sessionJti = null,
  verificationMinutes = 5,
  requiredScope = 'WRITE',
  requireStepUp = true,
  primaryAdminEmail = DEFAULT_PRIMARY_ADMIN_EMAIL,
} = {}) {
  const actor = String(actorId || '').trim();
  if (!actor) fail('ADMIN_ACTOR_REQUIRED', 'Administrator actor is required', 401);

  const ids = [...new Set([actor, ...(Array.isArray(targetUserIds) ? targetUserIds : [])]
    .map((value) => String(value || '').trim())
    .filter(Boolean))].sort();

  const { rows } = await client.query(
    `SELECT id,email,google_subject,role,status,
            admin_panel_verified_at,admin_panel_verified_session_jti,
            admin_panel_verified_scope
       FROM users
      WHERE id=ANY($1::uuid[])
      ORDER BY id
      FOR UPDATE`,
    [ids],
  );

  const actorRow = rows.find((row) => String(row.id) === actor);
  if (!actorRow || actorRow.role !== 'ADMIN' || actorRow.status !== 'ACTIVE') {
    fail('ADMIN_REQUIRED', 'An active administrator account is required');
  }

  const canonicalOwner = String(actorRow.email || '').trim().toLowerCase()
    === String(primaryAdminEmail || DEFAULT_PRIMARY_ADMIN_EMAIL).trim().toLowerCase();
  if (canonicalOwner && !String(actorRow.google_subject || '').trim()) {
    fail('PRIMARY_ADMIN_IDENTITY_REQUIRED', 'Link a verified Google identity before administering HOPE');
  }

  if (requireStepUp) {
    const requestedScope = String(requiredScope || 'WRITE').trim().toUpperCase();
    const acceptedScopes = requestedScope === 'READ' ? ['READ', 'WRITE'] : ['WRITE'];
    const storedScope = String(actorRow.admin_panel_verified_scope || '').trim().toUpperCase();
    const jti = String(sessionJti || '').trim();
    const storedJti = String(actorRow.admin_panel_verified_session_jti || '').trim();
    const verifiedAt = actorRow.admin_panel_verified_at
      ? new Date(actorRow.admin_panel_verified_at).getTime()
      : Number.NaN;
    const age = Date.now() - verifiedAt;
    const minutes = Math.min(120, Math.max(1, Number(verificationMinutes) || 5));
    if (
      !jti ||
      storedJti !== jti ||
      !acceptedScopes.includes(storedScope) ||
      !Number.isFinite(verifiedAt) ||
      age < -5_000 ||
      age > minutes * 60_000
    ) {
      fail('ADMIN_PANEL_LOCKED', 'Administrator action requires current-session step-up verification');
    }
  }

  const targets = new Map(rows
    .filter((row) => String(row.id) !== actor)
    .map((row) => [String(row.id), row]));
  return Object.freeze({ actor: actorRow, targets });
}
