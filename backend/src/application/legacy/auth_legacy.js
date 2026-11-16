/**
 * Explicit test-runtime adapter for authentication persistence.
 * Production auth routes must use repository interfaces instead.
 */
export function createAuthLegacyAdapter({ db, findUser, issueSession, withTransaction, now }) {
  return Object.freeze({
    createUserWithProvider(user, provider) {
      const created = db.insert('users', user);
      db.insert('providers', provider);
      return created;
    },
    updatePassword(user, passwordHash) {
      user.passwordHash = passwordHash;
      db.touch('users');
    },
    findUserByGoogleSubject(subject) {
      return db.collection.users.find((user) => user.googleSubject === subject) || null;
    },
    linkGoogleSubject(userId, subject, { promoteToPrimaryAdmin = false } = {}) {
      const user = db.collection.users.find((item) => item.id === userId);
      if (!user || user.status !== 'ACTIVE' || (user.googleSubject && user.googleSubject !== subject)) return null;
      if (promoteToPrimaryAdmin && String(user.email || '').trim().toLowerCase() !== 'amir.davodpour@gmail.com') return null;
      if (!String(subject || '').trim()) return null;
      const duplicate = db.collection.users.find((item) => item.id !== userId && item.googleSubject === subject);
      if (duplicate) {
        const error = new Error('GOOGLE_IDENTITY_ALREADY_LINKED');
        error.code = '23505';
        throw error;
      }
      user.googleSubject = subject;
      if (promoteToPrimaryAdmin) user.role = 'ADMIN';
      user.sessionVersion = Number(user.sessionVersion || 0) + 1;
      user.adminPanelVerifiedAt = null;
      user.adminPanelVerifiedSessionJti = null;
      user.adminPanelVerifiedScope = null;
      db.touch('users');
      return user;
    },
    async rotateRefreshToken({ presentedHash, issue }) {
      const item = db.collection.refreshTokens.find((t) => t.tokenHash === presentedHash);
      if (!item || new Date(item.expiresAt).getTime() <= Date.now()) return { kind: 'invalid' };
      if (item.revokedAt) {
        for (const token of db.collection.refreshTokens.filter((t) => t.familyId === item.familyId && !t.revokedAt)) token.revokedAt = now();
        db.touch('refreshTokens'); await db.save();
        return { kind: 'reuse' };
      }
      return withTransaction(async () => {
        const current = db.collection.refreshTokens.find((t) => t.id === item.id);
        if (!current || current.revokedAt) return { kind: 'invalid' };
        const user = findUser(current.userId);
        if (!user || user.status !== 'ACTIVE') return { kind: 'invalid' };
        const issued = await issue(user, current.familyId);
        current.revokedAt = now();
        current.replacedBy = issued.refreshToken; // legacy metadata; reuse detection is based on revoked family state
        db.touch('refreshTokens');
        return { kind: 'ok', issued, user };
      });
    },
    logout(userId) {
      const user = findUser(userId);
      if (!user) return false;
      user.sessionVersion = Number(user.sessionVersion || 0) + 1;
      db.touch('users');
      for (const token of db.collection.refreshTokens.filter((t) => t.userId === user.id && !t.revokedAt)) token.revokedAt = now();
      db.touch('refreshTokens');
      return true;
    },
    async consumeResetToken(tokenHash, passwordHash) {
      const reset = db.collection.resetTokens.find((t) => t.tokenHash === tokenHash && !t.usedAt && new Date(t.expiresAt).getTime() > Date.now());
      if (!reset) return null;
      const user = findUser(reset.userId);
      if (!user || user.status !== 'ACTIVE') return null;
      user.passwordHash = passwordHash;
      user.sessionVersion = Number(user.sessionVersion || 0) + 1;
      reset.usedAt = now();
      for (const token of db.collection.refreshTokens.filter((t) => t.userId === user.id && !t.revokedAt)) token.revokedAt = now();
      db.touch('users', 'refreshTokens', 'resetTokens');
      return user;
    },
    insertResetToken(token) {
      return db.insert('resetTokens', token);
    },
    insertEmailVerificationToken(token) {
      for (const existing of db.collection.emailVerificationTokens.filter((item) => item.userId === token.userId && !item.usedAt)) {
        existing.usedAt = now();
      }
      db.touch('emailVerificationTokens');
      return db.insert('emailVerificationTokens', token);
    },
    invalidateEmailVerificationToken(tokenHash) {
      const token = db.collection.emailVerificationTokens.find((item) => item.tokenHash === tokenHash && !item.usedAt);
      if (!token) return false;
      token.usedAt = now();
      db.touch('emailVerificationTokens');
      return true;
    },
    consumeEmailVerificationToken(tokenHash) {
      const token = db.collection.emailVerificationTokens.find((item) =>
        item.tokenHash === tokenHash && !item.usedAt && new Date(item.expiresAt).getTime() > Date.now(),
      );
      if (!token) return null;
      const user = findUser(token.userId);
      if (!user || user.status !== 'PENDING_EMAIL_VERIFICATION') return null;
      token.usedAt = now();
      user.status = 'ACTIVE';
      for (const existing of db.collection.emailVerificationTokens.filter((item) => item.userId === user.id && !item.usedAt)) {
        existing.usedAt = now();
      }
      db.touch('users', 'emailVerificationTokens');
      return user;
    },
    async save() { await db.save(); },
    markResetDeliveryFailed(tokenHash) {
      const created = db.collection.resetTokens.find((t) => t.tokenHash === tokenHash);
      if (created) { created.usedAt = now(); db.touch('resetTokens'); }
    },
  });
}
