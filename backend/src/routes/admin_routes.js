import { ADMIN_PERMISSIONS, assertAdminPermission, assertPrimaryAdmin, getAdminPermissions, isPrimaryAdmin, isPrimaryAdminEmail, verifyAdminPanelCredentials } from '../application/admin_panel_access.js';
import { buildTotpUri, decryptTotpSecret, encryptTotpSecret, generateRecoveryCodes, generateTotpSecret, hashRecoveryCode, verifyTotpCode } from '../security/admin_mfa.js';

const legacyVerifiedAdmins = new Map();

function isLegacyAdminPanelVerified(userId, sessionJti, requiredScope = 'READ') {
  const verification = legacyVerifiedAdmins.get(userId);
  if (!verification || verification.expiresAt <= Date.now()) {
    legacyVerifiedAdmins.delete(userId);
    return false;
  }
  const required = String(requiredScope || 'READ').toUpperCase();
  const stored = String(verification.scope || 'READ').toUpperCase();
  return Boolean(sessionJti && verification.sessionJti === sessionJti && (required === 'READ' ? ['READ','WRITE'].includes(stored) : required === 'WRITE' && stored === 'WRITE'));
}

export function createAdminRoutes({ authUser, requireAdmin, jobDisputeRoutes, readBody, sendJson, HttpError, enumField, adminUseCases, legacyAdmin, config, now, createAudit, findUser, getJob, notifyApplicationCandidate, paymentUseCases, URL, listUnknownPayouts, resolvePayoutUnknown, repo, processPaymentReleaseNow, processPaymentRefundNow, notifyUser, NOTIFICATION_TYPES, verifyPassword, verifyGoogleIdToken, rateLimitAuth, rateLimitAuthAccount, DUMMY_PASSWORD_HASH, PASSWORD_MAX_LENGTH }) {
  async function enforceAuthRateLimits(req, me) {
    if (typeof rateLimitAuth !== 'function' || typeof rateLimitAuthAccount !== 'function') {
      throw new HttpError(503,'ADMIN_REAUTH_UNAVAILABLE','Admin reauthentication is unavailable');
    }
    const [ipAllowed,accountAllowed] = await Promise.all([
      rateLimitAuth(req, config.authRateLimitMax, config.rateLimitWindowMs),
      rateLimitAuthAccount(`admin-panel:${me.id}`, config.authRateLimitMax, config.rateLimitWindowMs),
    ]);
    if (!ipAllowed || !accountAllowed) throw new HttpError(429,'RATE_LIMITED','Too many authentication requests');
  }

  async function verifyPrimaryFactor(me, body, req) {
    const sessionJti = String(me.sessionJti || '').trim();
    if (!sessionJti) throw new HttpError(401,'UNAUTHORIZED','Authentication required');
    await enforceAuthRateLimits(req, me);
    verifyAdminPanelCredentials({
      user: me,
      name: body?.name,
      username: body?.username,
      expectedUsername: config.adminPanelUsername,
      expectedEmail: isPrimaryAdminEmail(me.email) ? config.adminPanelAllowedEmail : undefined,
    });
    const password = typeof body?.password === 'string' ? body.password : '';
    const idToken = typeof body?.idToken === 'string' ? body.idToken : '';
    const hasPassword = password.length > 0;
    const hasGoogle = idToken.length > 0;
    if (hasPassword === hasGoogle) throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');

    if (hasPassword) {
      if (password.length > PASSWORD_MAX_LENGTH) throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
      const passwordOk = await verifyPassword(password, me.passwordHash || DUMMY_PASSWORD_HASH);
      if (!me.passwordHash || !passwordOk) throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
      return 'password';
    }

    if (!config.googleAuthEnabled || !config.googleOAuthClientId || !String(me.googleSubject || '').trim()) {
      throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
    }
    let identity;
    try { identity = await verifyGoogleIdToken(idToken, config.googleOAuthClientId); }
    catch { throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed'); }
    const issuedAt = Number(identity?.issuedAt);
    const tokenAgeMs = Date.now() - issuedAt * 1000;
    const identityEmail = String(identity?.email || '').trim().toLowerCase();
    const accountEmail = String(me.email || '').trim().toLowerCase();
    if (
      !identity?.subject ||
      identity.subject !== me.googleSubject ||
      !identityEmail ||
      identityEmail !== accountEmail ||
      !Number.isSafeInteger(issuedAt) ||
      issuedAt <= 0 ||
      tokenAgeMs < -5_000 ||
      tokenAgeMs > 5 * 60 * 1000
    ) throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
    return 'google';
  }

  async function verifyAdminMfa(me, body) {
    if (!config.adminMfaRequired) return { method:'not_required' };
    if (typeof repo.getAdminMfaCredential !== 'function') {
      throw new HttpError(503,'ADMIN_MFA_UNAVAILABLE','Administrator MFA is unavailable');
    }
    const credential = await repo.getAdminMfaCredential(me.id);
    if (!credential?.enrolledAt || !credential.secretCiphertext) {
      throw new HttpError(403,'ADMIN_MFA_ENROLLMENT_REQUIRED','Enroll an authenticator before opening the administrator panel');
    }
    const totpCode = typeof body?.totpCode === 'string' ? body.totpCode.trim() : '';
    const recoveryCode = typeof body?.recoveryCode === 'string' ? body.recoveryCode.trim() : '';
    if (Boolean(totpCode) === Boolean(recoveryCode)) {
      throw new HttpError(401,'ADMIN_MFA_REQUIRED','Enter exactly one authenticator code or recovery code');
    }
    if (totpCode) {
      let secret;
      try { secret = decryptTotpSecret(credential.secretCiphertext, config.adminMfaEncryptionKey); }
      catch { throw new HttpError(503,'ADMIN_MFA_UNAVAILABLE','Administrator MFA secret could not be opened'); }
      const nowMs = Date.parse(typeof now === 'function' ? now() : new Date().toISOString());
      const verified = verifyTotpCode(secret, totpCode, Number.isFinite(nowMs) ? nowMs : Date.now(), {
        lastAcceptedCounter: Number(credential.lastTotpCounter ?? -1),
      });
      if (!verified.valid || !(await repo.consumeAdminTotpCounter(me.id, verified.counter))) {
        throw new HttpError(401,'ADMIN_MFA_CODE_INVALID','Authenticator code is invalid or has already been used');
      }
      return { method:'totp' };
    }
    let recoveryHash;
    try { recoveryHash = hashRecoveryCode(recoveryCode); }
    catch { throw new HttpError(401,'ADMIN_MFA_CODE_INVALID','Recovery code is invalid or has already been used'); }
    const consumed = await repo.consumeAdminRecoveryCode(me.id, recoveryHash);
    if (!consumed) throw new HttpError(401,'ADMIN_MFA_CODE_INVALID','Recovery code is invalid or has already been used');
    return { method:'recovery_code' };
  }

  return async function adminRoutes(req,res,parts){
    const me=requireAdmin(await authUser(req));
    if (req.method==='GET' && parts[0]==='admin' && parts[1]==='access' && parts[2]==='mfa' && parts.length===3) {
      const status = config.adminMfaRequired && typeof repo.getAdminMfaStatus === 'function'
        ? await repo.getAdminMfaStatus(me.id)
        : { enabled:false, enrollmentPending:false, recoveryCodesRemaining:0 };
      return sendJson(res,200,status);
    }
    if (req.method==='POST' && parts[0]==='admin' && parts[1]==='access' && parts[2]==='mfa' && parts[3]==='setup' && parts.length===4) {
      const body=await readBody(req);
      await verifyPrimaryFactor(me,body,req);
      if (!config.adminMfaEncryptionKey || Buffer.byteLength(config.adminMfaEncryptionKey,'utf8') < 32) {
        throw new HttpError(503,'ADMIN_MFA_UNAVAILABLE','Administrator MFA encryption is not configured');
      }
      const existing = await repo.getAdminMfaStatus(me.id);
      if (existing?.enabled) throw new HttpError(409,'ADMIN_MFA_ALREADY_ENROLLED','An authenticator is already enrolled');
      const secret = generateTotpSecret();
      const encrypted = encryptTotpSecret(secret,config.adminMfaEncryptionKey);
      const minutes = config.adminMfaEnrollmentMinutes ?? 10;
      const expiresAt = new Date(Date.now()+minutes*60000).toISOString();
      const created = await repo.beginAdminMfaEnrollment(me.id,encrypted,expiresAt);
      if (!created) throw new HttpError(409,'ADMIN_MFA_ALREADY_ENROLLED','An authenticator is already enrolled');
      await createAudit('ADMIN_MFA_SETUP_STARTED',me.id,'admin',me.id,{expiresInMinutes:minutes});
      return sendJson(res,200,{pending:true,secret,otpauthUri:buildTotpUri({secret,email:me.email}),expiresInMinutes:minutes});
    }
    if (req.method==='POST' && parts[0]==='admin' && parts[1]==='access' && parts[2]==='mfa' && parts[3]==='confirm' && parts.length===4) {
      const body=await readBody(req);
      await enforceAuthRateLimits(req,me);
      const credential=await repo.getAdminMfaCredential(me.id);
      const expiresAt=credential?.pendingExpiresAt ? new Date(credential.pendingExpiresAt).getTime() : Number.NaN;
      if (!credential?.pendingSecretCiphertext || !Number.isFinite(expiresAt) || expiresAt<=Date.now()) {
        throw new HttpError(409,'ADMIN_MFA_ENROLLMENT_EXPIRED','Start authenticator setup again');
      }
      let secret;
      try { secret=decryptTotpSecret(credential.pendingSecretCiphertext,config.adminMfaEncryptionKey); }
      catch { throw new HttpError(503,'ADMIN_MFA_UNAVAILABLE','Administrator MFA secret could not be opened'); }
      const nowMs=Date.parse(typeof now==='function'?now():new Date().toISOString());
      const verified=verifyTotpCode(secret,body?.code,Number.isFinite(nowMs)?nowMs:Date.now());
      if (!verified.valid) throw new HttpError(401,'ADMIN_MFA_CODE_INVALID','Authenticator code is invalid');
      const recovery=generateRecoveryCodes(10);
      const completed=await repo.completeAdminMfaEnrollment(me.id,{
        secretCiphertext:credential.pendingSecretCiphertext,
        recoveryCodeHashes:recovery.hashes,
        lastTotpCounter:verified.counter,
      });
      if (!completed) throw new HttpError(409,'ADMIN_MFA_ENROLLMENT_EXPIRED','Start authenticator setup again');
      await createAudit('ADMIN_MFA_ENROLLED',me.id,'admin',me.id,{recoveryCodesIssued:recovery.codes.length});
      return sendJson(res,200,{enabled:true,recoveryCodes:recovery.codes});
    }
    if (req.method==='GET' && parts[0]==='admin' && parts[1]==='access' && parts.length===2) {
      const verified = config.adminMfaRequired
        ? await repo.isAdminPanelVerified(me.id, config.adminPanelReadVerificationMinutes ?? config.adminPanelVerificationMinutes, me.sessionJti, 'READ')
        : process.env.DATABASE_URL
          ? await repo.isAdminPanelVerified(me.id, config.adminPanelVerificationMinutes, me.sessionJti)
          : isLegacyAdminPanelVerified(me.id, me.sessionJti, 'READ');
      return sendJson(res,200,{verified:Boolean(verified),primaryAdmin:isPrimaryAdmin(me),userId:me.id,permissions:getAdminPermissions(me),expiresInMinutes:config.adminPanelReadVerificationMinutes ?? config.adminPanelVerificationMinutes});
    }
    if (req.method==='POST' && parts[0]==='admin' && parts[1]==='access' && parts.length===2) {
      const body=await readBody(req);
      const sessionJti=String(me.sessionJti||'').trim();
      if (!sessionJti) throw new HttpError(401,'UNAUTHORIZED','Authentication required');
      const primaryMethod=await verifyPrimaryFactor(me,body,req);
      const mfa=await verifyAdminMfa(me,body);
      const scope=String(body?.scope||'WRITE').trim().toUpperCase();
      if (!['READ','WRITE'].includes(scope)) throw new HttpError(400,'INVALID_ADMIN_PANEL_SCOPE','scope must be READ or WRITE');
      if (config.adminMfaRequired) {
        const verified=await repo.setAdminPanelVerified(me.id,sessionJti,scope);
        if (!verified) throw new HttpError(403,'ADMIN_PANEL_LOCKED','Admin panel requires identity verification');
      } else if (process.env.DATABASE_URL) {
        const verified=await repo.setAdminPanelVerified(me.id,sessionJti);
        if (!verified) throw new HttpError(403,'ADMIN_PANEL_LOCKED','Admin panel requires identity verification');
      } else {
        legacyVerifiedAdmins.set(me.id,{
          expiresAt:Date.now()+(scope==='WRITE'?(config.adminPanelWriteVerificationMinutes??5):(config.adminPanelReadVerificationMinutes??15))*60000,
          sessionJti,
          scope,
        });
      }
      await createAudit('ADMIN_PANEL_UNLOCK',me.id,'admin',me.id,{
        scope,
        expiresInMinutes:scope==='WRITE'?(config.adminPanelWriteVerificationMinutes??5):(config.adminPanelReadVerificationMinutes??15),
        method:primaryMethod,
        mfaMethod:mfa.method,
      });
      return sendJson(res,200,{verified:true,scope,primaryAdmin:isPrimaryAdmin(me),userId:me.id,permissions:getAdminPermissions(me),expiresInMinutes:scope==='WRITE'?(config.adminPanelWriteVerificationMinutes??5):(config.adminPanelReadVerificationMinutes??15)});
    }
    if (req.method==='POST' && parts[0]==='admin' && parts[1]==='access' && parts[2]==='lock' && parts.length===3) {
      if (process.env.DATABASE_URL || config.adminMfaRequired) await repo.clearAdminPanelVerification(me.id);
      else legacyVerifiedAdmins.delete(me.id);
      await createAudit('ADMIN_PANEL_LOCK',me.id,'admin',me.id);
      return sendJson(res,200,{verified:false});
    }
    const requiredScope=req.method==='GET'?'READ':'WRITE';
    const ttlMinutes=requiredScope==='WRITE'
      ? (config.adminPanelWriteVerificationMinutes??5)
      : (config.adminPanelReadVerificationMinutes??15);
    if (config.adminMfaRequired) {
      const verified=await repo.isAdminPanelVerified(me.id,ttlMinutes,me.sessionJti,requiredScope);
      if (!verified) throw new HttpError(403,'ADMIN_PANEL_LOCKED','Admin panel requires current-session step-up verification');
    } else if (process.env.DATABASE_URL) {
      const verified=await repo.isAdminPanelVerified(me.id,config.adminPanelVerificationMinutes ?? 15,me.sessionJti);
      if (!verified) throw new HttpError(403,'ADMIN_PANEL_LOCKED','Admin panel requires identity verification');
    } else if (!isLegacyAdminPanelVerified(me.id,me.sessionJti,requiredScope)) {
      throw new HttpError(403,'ADMIN_PANEL_LOCKED','Admin panel requires identity verification');
    }
    if (req.method==='GET' && parts[0]==='admin' && parts[1]==='privacy' && parts[2]==='chat-retention' && parts[3]==='dry-run' && parts.length===4) {
      assertAdminPermission(me, ADMIN_PERMISSIONS.VIEW_AUDIT);
      if (typeof repo.buildChatRetentionDryRun !== 'function') {
        throw new HttpError(503,'CHAT_RETENTION_UNAVAILABLE','Chat-retention assessment is unavailable');
      }
      const requestUrl = new URL(req.url || '/', 'http://localhost');
      const rawLimit = requestUrl.searchParams.get('limit');
      const limit = rawLimit == null ? 200 : Number(rawLimit);
      if (!Number.isSafeInteger(limit) || limit < 1 || limit > 1000) {
        throw new HttpError(400,'INVALID_RETENTION_LIMIT','limit must be an integer between 1 and 1000');
      }
      const cursor = requestUrl.searchParams.get('cursor') || null;
      if (cursor && cursor.length > 1024) {
        throw new HttpError(400,'INVALID_RETENTION_CURSOR','cursor token is too long');
      }
      let plan;
      try {
        plan = await repo.buildChatRetentionDryRun({limit,cursor});
      } catch (error) {
        if (error?.code === 'INVALID_RETENTION_CURSOR') {
          throw new HttpError(400,'INVALID_RETENTION_CURSOR','cursor token is invalid');
        }
        throw error;
      }
      await createAudit(
        'ADMIN_CHAT_RETENTION_DRY_RUN',
        me.id,
        'chat_retention',
        'dry-run',
        'Read-only retention eligibility assessment',
        {
          wouldMutate:plan?.wouldMutate === true,
          scanned:Number(plan?.scanned || 0),
          limit:Number(plan?.limit || limit),
          totalCount:Number(plan?.totalCount || 0),
          hasMore:plan?.hasMore === true,
          inventoryComplete:plan?.inventoryComplete === true,
          cursorProvided:plan?.cursorProvided === true,
        },
      );
      return sendJson(res,200,plan);
    }

    if (req.method==='POST' && parts[0]==='admin' && parts[1]==='privacy' && parts[2]==='chat-retention' && parts[3]==='holds' && parts.length===4) {
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_ADMINS);
      assertPrimaryAdmin(me);
      const body=await readBody(req);
      const conversationId=String(body?.conversationId || '').trim();
      const holdKind=String(body?.holdKind || '').trim().toUpperCase();
      const reason=String(body?.reason || '').trim();
      const uuidPattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      if (!uuidPattern.test(conversationId)) {
        throw new HttpError(400,'INVALID_CONVERSATION_ID','conversationId must be a UUID');
      }
      if (!['LEGAL','ADMIN'].includes(holdKind)) {
        throw new HttpError(400,'INVALID_HOLD_KIND','holdKind must be LEGAL or ADMIN');
      }
      if (!reason || reason.length>1000) {
        throw new HttpError(400,'INVALID_HOLD_REASON','reason must contain between 1 and 1000 characters');
      }
      if (typeof repo.createChatConversationLegalHold !== 'function') {
        throw new HttpError(503,'CHAT_RETENTION_UNAVAILABLE','Chat-retention legal holds are unavailable');
      }
      const hold=await repo.createChatConversationLegalHold({
        conversationId,
        holdKind,
        reason,
        createdBy:me.id,
      });
      if (!hold) throw new HttpError(404,'CHAT_CONVERSATION_NOT_FOUND','Job conversation not found');
      await createAudit(
        'ADMIN_CHAT_LEGAL_HOLD_CREATED',
        me.id,
        'chat_retention',
        hold.id,
        reason,
        {conversationId,holdKind,reason},
      );
      return sendJson(res,201,hold);
    }

    if (req.method==='POST' && parts[0]==='admin' && parts[1]==='privacy' && parts[2]==='chat-retention' && parts[3]==='holds' && parts[5]==='release' && parts.length===6) {
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_ADMINS);
      assertPrimaryAdmin(me);
      const holdId=String(parts[4] || '').trim();
      const body=await readBody(req);
      const reason=String(body?.reason || '').trim();
      const uuidPattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      if (!uuidPattern.test(holdId)) {
        throw new HttpError(400,'INVALID_HOLD_ID','holdId must be a UUID');
      }
      if (!reason || reason.length>1000) {
        throw new HttpError(400,'INVALID_HOLD_RELEASE_REASON','release reason must contain between 1 and 1000 characters');
      }
      if (typeof repo.releaseChatConversationLegalHold !== 'function') {
        throw new HttpError(503,'CHAT_RETENTION_UNAVAILABLE','Chat-retention legal holds are unavailable');
      }
      let hold;
      try {
        hold=await repo.releaseChatConversationLegalHold({
          holdId,
          releasedBy:me.id,
          releaseReason:reason,
        });
      } catch (error) {
        if (error?.code==='CHAT_LEGAL_HOLD_ALREADY_RELEASED') {
          throw new HttpError(409,'CHAT_LEGAL_HOLD_ALREADY_RELEASED','Legal hold has already been released');
        }
        throw error;
      }
      if (!hold) throw new HttpError(404,'CHAT_LEGAL_HOLD_NOT_FOUND','Active legal hold not found');
      await createAudit(
        'ADMIN_CHAT_LEGAL_HOLD_RELEASED',
        me.id,
        'chat_retention',
        hold.id,
        reason,
        {reason,conversationId:hold.conversationId},
      );
      return sendJson(res,200,hold);
    }

    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='admins' && parts.length===2){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_ADMINS);
      const u=process.env.DATABASE_URL ? await adminUseCases.users() : legacyAdmin.users();
      return sendJson(res,200,u.filter(x=>x.role==='ADMIN').map(x=>({id:x.id,email:x.email,displayName:x.displayName,status:x.status,createdAt:x.createdAt,primaryAdmin:isPrimaryAdmin(x)})));
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='admins' && parts.length===2){
      assertPrimaryAdmin(me);
      const body=await readBody(req);
      const email=String(body?.email||'').trim().toLowerCase();
      if(!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(email)) throw new HttpError(400,'INVALID_EMAIL','A valid email is required');
      const promoted=process.env.DATABASE_URL
        ? await adminUseCases.grantAdminByEmail(email, me.id)
        : legacyAdmin.grantAdminByEmail(email, me.id);
      if(!promoted) throw new HttpError(404,'USER_NOT_FOUND','No existing user was found for this email');
      await createAudit('ADMIN_ROLE_GRANT',me.id,'user',promoted.id,{role:'ADMIN',email:promoted.email});
      return sendJson(res,200,{id:promoted.id,email:promoted.email,displayName:promoted.displayName,role:promoted.role});
    }
    if(req.method==='DELETE' && parts[0]==='admin' && parts[1]==='admins' && parts[2]){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_ADMINS);
      const id=parts[2];
      try {
        const revoked=process.env.DATABASE_URL ? await adminUseCases.revokeAdminById(id,me.id) : legacyAdmin.revokeAdminById(id,me.id);
        if(!revoked) throw new HttpError(404,'USER_NOT_FOUND','Administrator not found');
        if(!process.env.DATABASE_URL) await legacyAdmin.save();
        await createAudit('ADMIN_ROLE_REVOKE',me.id,'user',id,{role:'USER',email:revoked.email});
        return sendJson(res,200,{id:revoked.id,email:revoked.email,displayName:revoked.displayName,role:revoked.role});
      } catch(error) {
        if(error?.code==='PRIMARY_ADMIN_PROTECTED') throw new HttpError(403,'PRIMARY_ADMIN_PROTECTED','The primary administrator cannot be removed');
        if(error?.code==='NOT_AN_ADMIN') throw new HttpError(409,'NOT_AN_ADMIN','User is not an administrator');
        throw error;
      }
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='users' && parts[3]==='revoke-sessions'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.REVOKE_SESSIONS);
      const id=parts[2];
      const revoked=process.env.DATABASE_URL ? await adminUseCases.revokeUserSessions(id) : legacyAdmin.revokeUserSessions(id);
      if(!revoked) throw new HttpError(404,'USER_NOT_FOUND','User not found');
      await createAudit('ADMIN_SESSIONS_REVOKE',me.id,'user',id,{sessionVersion:revoked.sessionVersion});
      return sendJson(res,200,{...revoked,revoked:true});
    }
    if (parts[0] === 'admin' && parts[1] === 'disputes') {
      if (typeof jobDisputeRoutes !== 'function') {
        throw new HttpError(503, 'DISPUTE_CONTROL_UNAVAILABLE', 'Dispute controls are unavailable');
      }
      return jobDisputeRoutes(req, res, parts);
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='finance' && parts.length===3 && parts[2]==='summary'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.VIEW_FINANCE);
      if(process.env.DATABASE_URL){ return sendJson(res,200,await paymentUseCases.adminFinancialSummary()); }
            return sendJson(res,200,{...legacyAdmin.financialSummary(),currency:config.paymentCurrency});
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='summary'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.VIEW_ADMIN_CENTER);
      if(process.env.DATABASE_URL){ return sendJson(res,200,await adminUseCases.summary()); }
            return sendJson(res,200,legacyAdmin.summary());
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='users'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_USERS);
      const u=process.env.DATABASE_URL ? await adminUseCases.users() : legacyAdmin.users();
      return sendJson(res,200,u.map(x=>({id:x.id,email:x.email,displayName:x.displayName,role:x.role,status:x.status,createdAt:x.createdAt,statusReviewCaseId:x.statusReviewCaseId || null,statusReviewReason:x.statusReviewReason || null,statusReviewDueAt:x.statusReviewDueAt || null})));
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='users' && parts[3]==='status'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_USERS);
      const id=parts[2];
      const body=await readBody(req);
      const status=enumField(body?.status,new Set(['ACTIVE','SUSPENDED']),'status');
      const reason=String(body?.reason || '').trim();
      if(reason.length<3 || reason.length>1000) throw new HttpError(400,'ADMIN_USER_STATUS_REASON_REQUIRED','A reason between 3 and 1000 characters is required');
      let reviewDueAt=null;
      if(status==='SUSPENDED'){
        const requested=body?.reviewDueAt ? new Date(body.reviewDueAt) : new Date(Date.now()+72*60*60*1000);
        const delta=requested.getTime()-Date.now();
        if(!Number.isFinite(requested.getTime()) || delta<60*60*1000 || delta>7*24*60*60*1000) {
          throw new HttpError(400,'INVALID_REVIEW_DEADLINE','Review deadline must be between one hour and seven days from now');
        }
        reviewDueAt=requested.toISOString();
      }
      const target=process.env.DATABASE_URL ? await adminUseCases.getAdminUser(id) : legacyAdmin.getAdminUser(id);
      if(!target) throw new HttpError(404,'USER_NOT_FOUND','User not found');
      if(target.status==='DELETED') throw new HttpError(409,'ACCOUNT_DELETION_TERMINAL','Deleted accounts cannot be reactivated or changed');
      if(target.role==='ADMIN'){
        if(isPrimaryAdminEmail(target.email)) throw new HttpError(403,'PRIMARY_ADMIN_PROTECTED','The primary administrator account cannot be changed by the user-status control');
        assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_ADMINS);
      }
      if(id===me.id && status==='SUSPENDED') throw new HttpError(400,'SELF_SUSPEND_FORBIDDEN','An admin cannot suspend their own account');
      let updated;
      try {
        const options={actorId:me.id,reason,reviewDueAt};
        updated=process.env.DATABASE_URL
          ? await adminUseCases.setUserStatus(id,status,options)
          : legacyAdmin.setUserStatus(id,status,options);
      } catch(error) {
        if(['ACCOUNT_DELETION_TERMINAL','USER_STATUS_UNCHANGED'].includes(error?.code)) throw new HttpError(409,error.code,'The requested user status cannot be applied');
        if(['MANAGE_ADMINS_REQUIRED','PRIMARY_ADMIN_PROTECTED'].includes(error?.code)) throw new HttpError(403,error.code,'Only the verified primary administrator can change administrator or reserved-owner accounts');
        if(error?.code==='INVALID_REVIEW_DEADLINE') throw new HttpError(400,error.code,'Review deadline must be between one hour and seven days from now');
        throw error;
      }
      if(!updated) throw new HttpError(404,'USER_NOT_FOUND','User not found');
      if(!process.env.DATABASE_URL) {
        await legacyAdmin.save();
        await createAudit('ADMIN_USER_STATUS',me.id,'user',id,{
          status,
          reason,
          reviewCaseId:updated.reviewCaseId || null,
          reviewDueAt:updated.reviewDueAt || reviewDueAt,
          manualReviewRequired:status==='SUSPENDED',
          reviewAction:status==='SUSPENDED'?'OPENED':'HUMAN_RESOLUTION',
        });
      }
      return sendJson(res,200,{id,status:updated.status,reviewCaseId:updated.reviewCaseId || null,reviewDueAt:updated.reviewDueAt || reviewDueAt});

    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='trust-reports'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.TRUST_SAFETY);
      const status=req.url?new URL(req.url,'http://localhost').searchParams.get('status'):null;
      if(process.env.DATABASE_URL){ return sendJson(res,200,await adminUseCases.trustReports(status)); }
      const reports=legacyAdmin.trustReports(status);
      return sendJson(res,200,reports.map(r=>({...r,reporterName:findUser(r.reporterId)?.displayName||null})));
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='trust-reports' && parts[3]==='status'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.TRUST_SAFETY);
      const id=parts[2]; const body=await readBody(req); const status=enumField(body?.status,new Set(['OPEN','REVIEWING','RESOLVED','DISMISSED']),'status');
      const updated=process.env.DATABASE_URL ? await adminUseCases.updateTrustReportStatus(id,status) : legacyAdmin.updateTrustReportStatus(id,status);
      if(!updated) throw new HttpError(404,'REPORT_NOT_FOUND','Trust report not found'); if(!process.env.DATABASE_URL) await legacyAdmin.save();
      await createAudit('TRUST_REPORT_STATUS',me.id,'trust_report',id,{status}); return sendJson(res,200,{id,status:updated.status});
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='payouts' && parts[2]==='unknown'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.VIEW_PAYOUTS);
      const limit = new URL(req.url, 'http://localhost').searchParams.get('limit');
      if (typeof listUnknownPayouts !== 'function') throw new HttpError(503, 'FINANCIAL_CONTROL_UNAVAILABLE', 'Payout controls are unavailable');
      return sendJson(res, 200, { payouts: await listUnknownPayouts({ limit }) });
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='payouts' && parts[3]==='resolve'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.RESOLVE_PAYOUTS);
      if (typeof resolvePayoutUnknown !== 'function') throw new HttpError(503, 'FINANCIAL_CONTROL_UNAVAILABLE', 'Payout controls are unavailable');
      const payoutId = parts[2];
      const body = await readBody(req);
      try {
        const result = await resolvePayoutUnknown({ payoutId, decision: body?.decision, providerRef: body?.providerRef, adminId: me.id, reason: body?.reason });
        if (!result) throw new HttpError(404, 'PAYOUT_NOT_FOUND', 'Payout not found');
        return sendJson(res, 200, result);
      } catch (error) {
        if (error.code === 'INVALID_UNKNOWN_RESOLUTION') throw new HttpError(400, 'INVALID_UNKNOWN_RESOLUTION', 'decision must be SUCCEEDED or FAILED');
        if (error.code === 'PROVIDER_REF_REQUIRED') throw new HttpError(400, 'PROVIDER_REF_REQUIRED', 'providerRef is required for successful resolution');
        if (error.code === 'PAYOUT_NOT_UNKNOWN') throw new HttpError(409, 'PAYOUT_NOT_UNKNOWN', 'Payout is not awaiting unknown resolution');
        throw error;
      }
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='audit'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.VIEW_AUDIT);
      if(process.env.DATABASE_URL){ return sendJson(res,200,await adminUseCases.audit()); }
      const logs=legacyAdmin.audit();
      return sendJson(res,200,logs);
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='jobs'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MODERATE_JOBS); const jobs=process.env.DATABASE_URL ? await adminUseCases.jobs() : legacyAdmin.jobs(); return sendJson(res,200,jobs); }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='jobs' && parts[3]==='moderate'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MODERATE_JOBS);
      const id=parts[2]; const body=await readBody(req); const status=enumField(body?.status,new Set(['DRAFT','PUBLISHED','CANCELLED']),'status');
      const job=await getJob(id); if(!job) throw new HttpError(404,'JOB_NOT_FOUND','Job not found');
      try { const updated=process.env.DATABASE_URL ? await adminUseCases.moderateJob(id,status) : legacyAdmin.moderateJob(id,status); if(!updated) throw new HttpError(404,'JOB_NOT_FOUND','Job not found'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await createAudit('ADMIN_JOB_MODERATE',me.id,'job',id,{status}); return sendJson(res,200,updated); } catch(e){ if(e?.code==='JOB_LOCKED') throw new HttpError(409,'JOB_LOCKED','This opportunity is already in a protected lifecycle state'); throw e; }
    }
    if(req.method==='DELETE' && parts[0]==='admin' && parts[1]==='jobs' && parts[2]){
      assertAdminPermission(me, ADMIN_PERMISSIONS.DELETE_JOBS);
      const id=parts[2]; const job=await getJob(id); if(!job) throw new HttpError(404,'JOB_NOT_FOUND','Job not found');
      if(!['DRAFT','PUBLISHED'].includes(job.status)) throw new HttpError(409,'JOB_NOT_DELETABLE','Only draft or published opportunities can be deleted by admins');
      if(process.env.DATABASE_URL) await adminUseCases.deleteJob(id);
      else {
        try { legacyAdmin.deleteJob(id); } catch (error) {
          if (error?.code === 'JOB_HAS_FINANCIAL_RECORDS') throw new HttpError(409,'JOB_HAS_FINANCIAL_RECORDS','This opportunity has financial records and cannot be deleted');
          throw error;
        }
        await legacyAdmin.save();
      }
      await createAudit('ADMIN_JOB_DELETE',me.id,'job',id); return sendJson(res,200,{deleted:true,id});
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='applications'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_APPLICATIONS); const apps=process.env.DATABASE_URL ? await adminUseCases.applications() : legacyAdmin.applications(); return sendJson(res,200,apps); }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='applications' && parts[3]==='shortlist'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_APPLICATIONS); const id=parts[2]; const changed=process.env.DATABASE_URL ? await adminUseCases.shortlist(id) : legacyAdmin.shortlist(id); if(!changed) throw new HttpError(409,'INVALID_APPLICATION_STATE','Application is not pending'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await notifyApplicationCandidate(id, 'APPLICATION_SHORTLISTED', 'درخواست شما وارد فهرست کوتاه شد', 'درخواست شما برای بررسی بیشتر انتخاب شده است.'); await createAudit('ADMIN_APPLICATION_SHORTLIST',me.id,'job_application',id); return sendJson(res,200,{id,status:changed.status}); }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='applications' && parts[3]==='select'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_APPLICATIONS); const id=parts[2]; const changed=process.env.DATABASE_URL ? await adminUseCases.forward(id) : legacyAdmin.forward(id); if(!changed) throw new HttpError(409,'INVALID_APPLICATION_STATE','Application cannot be forwarded'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await notifyApplicationCandidate(id, 'APPLICATION_FORWARDED', 'درخواست شما برای کارفرما ارسال شد', 'رزومه و اطلاعات حرفه‌ای شما برای بررسی کارفرما ارسال شده است.'); await createAudit('ADMIN_APPLICATION_FORWARD',me.id,'job_application',id); return sendJson(res,200,{id,status:changed.status}); }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='applications' && parts[3]==='reject'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_APPLICATIONS); const id=parts[2]; const changed=process.env.DATABASE_URL ? await adminUseCases.reject(id) : legacyAdmin.reject(id); if(!changed) throw new HttpError(409,'INVALID_APPLICATION_STATE','Application cannot be rejected from its current state'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await notifyApplicationCandidate(id, 'APPLICATION_REJECTED', 'درخواست شما پذیرفته نشد', 'درخواست شما برای این شغل در این مرحله ادامه پیدا نکرد.'); await createAudit('ADMIN_APPLICATION_REJECT',me.id,'job_application',id); return sendJson(res,200,{id,status:changed.status}); }
    throw new HttpError(404,'NOT_FOUND','Admin route not found');
  };
}
