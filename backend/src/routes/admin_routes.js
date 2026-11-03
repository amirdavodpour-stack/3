import { ADMIN_PERMISSIONS, assertAdminPermission, assertPrimaryAdmin, getAdminPermissions, isPrimaryAdmin, isPrimaryAdminEmail, verifyAdminPanelCredentials } from '../application/admin_panel_access.js';

const legacyVerifiedAdmins = new Map();

export function createAdminRoutes({ authUser, requireAdmin, jobDisputeRoutes, readBody, sendJson, HttpError, enumField, adminUseCases, legacyAdmin, config, now, createAudit, findUser, getJob, notifyApplicationCandidate, paymentUseCases, URL, listUnknownPayouts, resolvePayoutUnknown, repo, processPaymentReleaseNow, processPaymentRefundNow, notifyUser, NOTIFICATION_TYPES, verifyPassword, verifyGoogleIdToken, rateLimitAuth, rateLimitAuthAccount, DUMMY_PASSWORD_HASH, PASSWORD_MAX_LENGTH }) {
  return async function adminRoutes(req,res,parts){
    const me=requireAdmin(await authUser(req));
    if (req.method==='GET' && parts[0]==='admin' && parts[1]==='access' && parts.length===2) {
      const verified = process.env.DATABASE_URL
        ? await repo.isAdminPanelVerified(me.id, config.adminPanelVerificationMinutes)
        : (legacyVerifiedAdmins.get(me.id) || 0) > Date.now();
      return sendJson(res,200,{verified:Boolean(verified),primaryAdmin:isPrimaryAdmin(me),userId:me.id,permissions:getAdminPermissions(me),expiresInMinutes:config.adminPanelVerificationMinutes});
    }
    if (req.method==='POST' && parts[0]==='admin' && parts[1]==='access' && parts.length===2) {
      const body=await readBody(req);
      if (typeof rateLimitAuth !== 'function' || typeof rateLimitAuthAccount !== 'function' ||
          typeof verifyPassword !== 'function' || typeof verifyGoogleIdToken !== 'function') {
        throw new HttpError(503,'ADMIN_REAUTH_UNAVAILABLE','Admin reauthentication is unavailable');
      }
      const [ipAllowed,accountAllowed] = await Promise.all([
        rateLimitAuth(req, config.authRateLimitMax, config.rateLimitWindowMs),
        rateLimitAuthAccount(`admin-panel:${me.id}`, config.authRateLimitMax, config.rateLimitWindowMs),
      ]);
      if (!ipAllowed || !accountAllowed) {
        throw new HttpError(429,'RATE_LIMITED','Too many authentication requests');
      }

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
      if (hasPassword === hasGoogle) {
        throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
      }

      let method;
      if (hasPassword) {
        if (password.length > PASSWORD_MAX_LENGTH) {
          throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
        }
        const passwordOk = await verifyPassword(password, me.passwordHash || DUMMY_PASSWORD_HASH);
        if (!me.passwordHash || !passwordOk) {
          throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
        }
        method = 'password';
      } else {
        if (!config.googleAuthEnabled || !config.googleOAuthClientId || !String(me.googleSubject || '').trim()) {
          throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
        }
        let identity;
        try {
          identity = await verifyGoogleIdToken(idToken, config.googleOAuthClientId);
        } catch {
          throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
        }
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
          tokenAgeMs < -30_000 ||
          tokenAgeMs > 5 * 60 * 1000
        ) {
          throw new HttpError(401,'ADMIN_REAUTH_FAILED','Admin panel reauthentication failed');
        }
        method = 'google';
      }

      if (process.env.DATABASE_URL) await repo.setAdminPanelVerified(me.id);
      else legacyVerifiedAdmins.set(me.id, Date.now() + config.adminPanelVerificationMinutes * 60000);
      await createAudit('ADMIN_PANEL_UNLOCK',me.id,'admin',me.id,{expiresInMinutes:config.adminPanelVerificationMinutes,method});
      return sendJson(res,200,{verified:true,primaryAdmin:isPrimaryAdmin(me),userId:me.id,permissions:getAdminPermissions(me),expiresInMinutes:config.adminPanelVerificationMinutes});
    }
    if (req.method==='POST' && parts[0]==='admin' && parts[1]==='access' && parts[2]==='lock' && parts.length===3) {
      if (process.env.DATABASE_URL) await repo.clearAdminPanelVerification(me.id);
      else legacyVerifiedAdmins.delete(me.id);
      await createAudit('ADMIN_PANEL_LOCK',me.id,'admin',me.id);
      return sendJson(res,200,{verified:false});
    }
    if (process.env.DATABASE_URL) {
      const verified=await repo.isAdminPanelVerified(me.id,config.adminPanelVerificationMinutes);
      if (!verified) throw new HttpError(403,'ADMIN_PANEL_LOCKED','Admin panel requires identity verification');
    } else if ((legacyVerifiedAdmins.get(me.id) || 0) <= Date.now()) {
      legacyVerifiedAdmins.delete(me.id);
      throw new HttpError(403,'ADMIN_PANEL_LOCKED','Admin panel requires identity verification');
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
      return sendJson(res,200,u.map(x=>({id:x.id,email:x.email,displayName:x.displayName,role:x.role,status:x.status,createdAt:x.createdAt})));
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='users' && parts[3]==='status'){
      assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_USERS);
      const id=parts[2]; const body=await readBody(req); const status=enumField(body?.status,new Set(['ACTIVE','SUSPENDED']),'status');
      const target=process.env.DATABASE_URL ? await adminUseCases.getAdminUser(id) : legacyAdmin.getAdminUser(id);
      if(!target) throw new HttpError(404,'USER_NOT_FOUND','User not found');
      if(target.role==='ADMIN'){
        if(isPrimaryAdminEmail(target.email)) throw new HttpError(403,'PRIMARY_ADMIN_PROTECTED','The primary administrator account cannot be changed by the user-status control');
        assertAdminPermission(me, ADMIN_PERMISSIONS.MANAGE_ADMINS);
      }
      if(id===me.id && status==='SUSPENDED') throw new HttpError(400,'SELF_SUSPEND_FORBIDDEN','An admin cannot suspend their own account');
      const updated=process.env.DATABASE_URL ? await adminUseCases.setUserStatus(id,status) : legacyAdmin.setUserStatus(id,status); if(!updated) throw new HttpError(404,'USER_NOT_FOUND','User not found'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await createAudit('ADMIN_USER_STATUS',me.id,'user',id,{status}); return sendJson(res,200,{id,status:updated.status});
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
