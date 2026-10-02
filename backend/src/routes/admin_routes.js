import crypto from 'node:crypto';
import { assertPrimaryAdmin, isPrimaryAdmin, PRIMARY_ADMIN_EMAIL, verifyAdminPanelCredentials } from '../application/admin_panel_access.js';
import { DISPUTE_DECISIONS } from '../services/dispute_resolution.js';

const legacyVerifiedAdmins = new Map();

export function createAdminRoutes({ authUser, requireAdmin, readBody, sendJson, HttpError, enumField, adminUseCases, legacyAdmin, config, now, createAudit, findUser, getJob, notifyApplicationCandidate, paymentUseCases, URL, listUnknownPayouts, resolvePayoutUnknown, repo, processPaymentReleaseNow, processPaymentRefundNow, notifyUser, NOTIFICATION_TYPES }) {
  return async function adminRoutes(req,res,parts){
    const me=requireAdmin(await authUser(req));
    if (req.method==='GET' && parts[0]==='admin' && parts[1]==='access' && parts.length===2) {
      const verified = process.env.DATABASE_URL
        ? await repo.isAdminPanelVerified(me.id, config.adminPanelVerificationMinutes)
        : (legacyVerifiedAdmins.get(me.id) || 0) > Date.now();
      return sendJson(res,200,{verified:Boolean(verified),primaryAdmin:isPrimaryAdmin(me),expiresInMinutes:config.adminPanelVerificationMinutes});
    }
    if (req.method==='POST' && parts[0]==='admin' && parts[1]==='access' && parts.length===2) {
      const body=await readBody(req);
      verifyAdminPanelCredentials({ user: me, name: body?.name, username: body?.username, expectedUsername: config.adminPanelUsername, expectedEmail: PRIMARY_ADMIN_EMAIL });
      if (process.env.DATABASE_URL) await repo.setAdminPanelVerified(me.id);
      else legacyVerifiedAdmins.set(me.id, Date.now() + config.adminPanelVerificationMinutes * 60000);
      await createAudit('ADMIN_PANEL_UNLOCK',me.id,'admin',me.id,{expiresInMinutes:config.adminPanelVerificationMinutes});
      return sendJson(res,200,{verified:true,primaryAdmin:isPrimaryAdmin(me),expiresInMinutes:config.adminPanelVerificationMinutes});
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
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='disputes' && parts.length===2){
      return sendJson(res,200,await repo.listAdminDisputes());
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='disputes' && parts.length===3){
      const dispute=await repo.getAdminDispute(parts[2]);
      if(!dispute) throw new HttpError(404,'DISPUTE_NOT_FOUND','Dispute not found');
      return sendJson(res,200,dispute);
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='disputes' && parts.length===3){
      const body=await readBody(req);
      const resolution=String(body?.resolution||'').toUpperCase();
      if(!DISPUTE_DECISIONS.includes(resolution)) throw new HttpError(400,'INVALID_DISPUTE_RESOLUTION','resolution must be RELEASE, REFUND, or HOLD');
      const reason=String(body?.reason||'').trim().slice(0,2000);
      const dispute=await repo.getAdminDispute(parts[2]);
      if(!dispute) throw new HttpError(404,'DISPUTE_NOT_FOUND','Dispute not found');
      const payment=dispute.context?.payment;
      const job=dispute.context?.job;
      if(!payment || !job) throw new HttpError(404,'PAYMENT_OR_JOB_NOT_FOUND','Payment or job not found');
      if(resolution==='RELEASE'){
        if(payment.status==='RELEASED') {
          // Already applied; continue so the dispute itself is resolved and audited.
        } else {
        if(!['RELEASE_PENDING','RELEASE_FAILED'].includes(payment.status)) throw new HttpError(409,'INVALID_PAYMENT_STATE','Payment cannot be released from its current state');
        const event=await paymentUseCases.release({jobId:job.id,ownerId:job.ownerId,paymentId:payment.id,dedupeKey:`PAYMENT_RELEASE:ADMIN_DISPUTE:${payment.id}`});
        const result=await processPaymentReleaseNow(event?.id);
        if(!result?.completed && !result?.alreadyDone) throw new HttpError(409,'PAYMENT_RELEASE_NOT_COMPLETED','Payment release was not completed');
        }
      } else if(resolution==='REFUND'){
        if(payment.status==='REFUNDED') {
          // Already applied; continue so the dispute itself is resolved and audited.
        } else {
        if(!['HELD','RELEASE_PENDING','RELEASE_FAILED'].includes(payment.status)) throw new HttpError(409,'INVALID_PAYMENT_STATE','Payment cannot be refunded from its current state');
        const created=await paymentUseCases.refund({jobId:job.id,paymentId:payment.id,ownerId:job.ownerId,amount:payment.amount,id:crypto.randomUUID(),idempotencyKey:`DISPUTE_REFUND:${dispute.id}`,createdAt:now(),allowPendingRelease:true});
        try { await processPaymentRefundNow(); } catch (_) {}
        const refreshed=await paymentUseCases.findByJob(job.id);
        if(refreshed?.status!=='REFUNDED') throw new HttpError(202,'PAYMENT_REFUND_PENDING','Refund is queued for processing');
        void created;
        }
      }
      const resolved=await repo.resolveJobDispute(dispute.id,{resolution,reason,adminId:me.id});
      await createAudit('ADMIN_DISPUTE_RESOLVE',me.id,'job_dispute',dispute.id,{jobId:dispute.jobId,resolution,aiDecision:dispute.aiDecision,aiConfidence:dispute.aiConfidence,reason});
      await notifyUser({userId:dispute.worker.id,type:NOTIFICATION_TYPES.PAYMENT_UPDATE,title:'نتیجه بررسی اختلاف همکاری',body:`اختلاف مربوط به «${dispute.jobTitle}» تعیین تکلیف شد.`,data:{jobId:dispute.jobId,disputeId:dispute.id,resolution},dedupeKey:`dispute:${dispute.id}:resolved:worker`,channels:['IN_APP','PUSH','EMAIL']}).catch(()=>{});
      return sendJson(res,200,resolved);
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='finance' && parts.length===3 && parts[2]==='summary'){
      if(process.env.DATABASE_URL){ return sendJson(res,200,await paymentUseCases.adminFinancialSummary()); }
            return sendJson(res,200,{...legacyAdmin.financialSummary(),currency:config.paymentCurrency});
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='summary'){
      if(process.env.DATABASE_URL){ return sendJson(res,200,await adminUseCases.summary()); }
            return sendJson(res,200,legacyAdmin.summary());
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='users'){
      const u=process.env.DATABASE_URL ? await adminUseCases.users() : legacyAdmin.users();
      return sendJson(res,200,u.map(x=>({id:x.id,email:x.email,displayName:x.displayName,role:x.role,status:x.status,createdAt:x.createdAt})));
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='users' && parts[3]==='status'){
      const id=parts[2]; const body=await readBody(req); const status=enumField(body?.status,new Set(['ACTIVE','SUSPENDED']),'status'); if(id===me.id && status==='SUSPENDED') throw new HttpError(400,'SELF_SUSPEND_FORBIDDEN','An admin cannot suspend their own account');
      const updated=process.env.DATABASE_URL ? await adminUseCases.setUserStatus(id,status) : legacyAdmin.setUserStatus(id,status); if(!updated) throw new HttpError(404,'USER_NOT_FOUND','User not found'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await createAudit('ADMIN_USER_STATUS',me.id,'user',id,{status}); return sendJson(res,200,{id,status:updated.status});
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='trust-reports'){
      const status=req.url?new URL(req.url,'http://localhost').searchParams.get('status'):null;
      if(process.env.DATABASE_URL){ return sendJson(res,200,await adminUseCases.trustReports(status)); }
      const reports=legacyAdmin.trustReports(status);
      return sendJson(res,200,reports.map(r=>({...r,reporterName:findUser(r.reporterId)?.displayName||null})));
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='trust-reports' && parts[3]==='status'){
      const id=parts[2]; const body=await readBody(req); const status=enumField(body?.status,new Set(['OPEN','REVIEWING','RESOLVED','DISMISSED']),'status');
      const updated=process.env.DATABASE_URL ? await adminUseCases.updateTrustReportStatus(id,status) : legacyAdmin.updateTrustReportStatus(id,status);
      if(!updated) throw new HttpError(404,'REPORT_NOT_FOUND','Trust report not found'); if(!process.env.DATABASE_URL) await legacyAdmin.save();
      await createAudit('TRUST_REPORT_STATUS',me.id,'trust_report',id,{status}); return sendJson(res,200,{id,status:updated.status});
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='payouts' && parts[2]==='unknown'){
      const limit = new URL(req.url, 'http://localhost').searchParams.get('limit');
      if (typeof listUnknownPayouts !== 'function') throw new HttpError(503, 'FINANCIAL_CONTROL_UNAVAILABLE', 'Payout controls are unavailable');
      return sendJson(res, 200, { payouts: await listUnknownPayouts({ limit }) });
    }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='payouts' && parts[3]==='resolve'){
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
      if(process.env.DATABASE_URL){ return sendJson(res,200,await adminUseCases.audit()); }
      const logs=legacyAdmin.audit();
      return sendJson(res,200,logs);
    }
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='jobs'){ const jobs=process.env.DATABASE_URL ? await adminUseCases.jobs() : legacyAdmin.jobs(); return sendJson(res,200,jobs); }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='jobs' && parts[3]==='moderate'){
      const id=parts[2]; const body=await readBody(req); const status=enumField(body?.status,new Set(['DRAFT','PUBLISHED','CANCELLED']),'status');
      const job=await getJob(id); if(!job) throw new HttpError(404,'JOB_NOT_FOUND','Job not found');
      try { const updated=process.env.DATABASE_URL ? await adminUseCases.moderateJob(id,status) : legacyAdmin.moderateJob(id,status); if(!updated) throw new HttpError(404,'JOB_NOT_FOUND','Job not found'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await createAudit('ADMIN_JOB_MODERATE',me.id,'job',id,{status}); return sendJson(res,200,updated); } catch(e){ if(e?.code==='JOB_LOCKED') throw new HttpError(409,'JOB_LOCKED','This opportunity is already in a protected lifecycle state'); throw e; }
    }
    if(req.method==='DELETE' && parts[0]==='admin' && parts[1]==='jobs' && parts[2]){
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
    if(req.method==='GET' && parts[0]==='admin' && parts[1]==='applications'){ const apps=process.env.DATABASE_URL ? await adminUseCases.applications() : legacyAdmin.applications(); return sendJson(res,200,apps); }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='applications' && parts[3]==='shortlist'){ const id=parts[2]; const changed=process.env.DATABASE_URL ? await adminUseCases.shortlist(id) : legacyAdmin.shortlist(id); if(!changed) throw new HttpError(409,'INVALID_APPLICATION_STATE','Application is not pending'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await notifyApplicationCandidate(id, 'APPLICATION_SHORTLISTED', 'درخواست شما وارد فهرست کوتاه شد', 'درخواست شما برای بررسی بیشتر انتخاب شده است.'); await createAudit('ADMIN_APPLICATION_SHORTLIST',me.id,'job_application',id); return sendJson(res,200,{id,status:changed.status}); }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='applications' && parts[3]==='select'){ const id=parts[2]; const changed=process.env.DATABASE_URL ? await adminUseCases.forward(id) : legacyAdmin.forward(id); if(!changed) throw new HttpError(409,'INVALID_APPLICATION_STATE','Application cannot be forwarded'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await notifyApplicationCandidate(id, 'APPLICATION_FORWARDED', 'درخواست شما برای کارفرما ارسال شد', 'رزومه و اطلاعات حرفه‌ای شما برای بررسی کارفرما ارسال شده است.'); await createAudit('ADMIN_APPLICATION_FORWARD',me.id,'job_application',id); return sendJson(res,200,{id,status:changed.status}); }
    if(req.method==='POST' && parts[0]==='admin' && parts[1]==='applications' && parts[3]==='reject'){ const id=parts[2]; const changed=process.env.DATABASE_URL ? await adminUseCases.reject(id) : legacyAdmin.reject(id); if(!changed) throw new HttpError(409,'INVALID_APPLICATION_STATE','Application cannot be rejected from its current state'); if(!process.env.DATABASE_URL) await legacyAdmin.save(); await notifyApplicationCandidate(id, 'APPLICATION_REJECTED', 'درخواست شما پذیرفته نشد', 'درخواست شما برای این شغل در این مرحله ادامه پیدا نکرد.'); await createAudit('ADMIN_APPLICATION_REJECT',me.id,'job_application',id); return sendJson(res,200,{id,status:changed.status}); }
    throw new HttpError(404,'NOT_FOUND','Admin route not found');
  };
}
