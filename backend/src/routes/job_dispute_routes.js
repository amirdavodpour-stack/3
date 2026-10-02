import crypto from 'node:crypto';
import { assertAutomatedAiAccess } from '../application/ai_access_policy.js';
import { DISPUTE_DECISIONS, analyzeDisputeWithAI, parseDisputeDecision } from '../services/dispute_resolution.js';

export function createJobDisputeRoutes({ authUser, requireAdmin, readBody, sendJson, HttpError, repo, askAI, paymentUseCases, processPaymentReleaseNow, processPaymentRefundNow, createAudit, notifyUser, NOTIFICATION_TYPES, now }) {
  const participantRole = (me, job) => job?.ownerId === me.id ? 'EMPLOYER' : job?.providerId === me.id ? 'WORKER' : null;

  async function analyzeCase(dispute) {
    const context = await repo.getJobDisputeContext(dispute.jobId);
    assertAutomatedAiAccess({ route: 'dispute-adjudication', source: 'SYSTEM' });
    let analysis;
    try {
      analysis = await analyzeDisputeWithAI({ askAI, context });
    } catch (_) {
      analysis = parseDisputeDecision(null);
    }
    return repo.updateJobDisputeAnalysis(dispute.id, analysis);
  }

  async function resolvePayment(dispute, resolution, adminId, reason) {
    const context = await repo.getJobDisputeContext(dispute.jobId);
    const payment = context?.payment;
    const job = context?.job;
    if (!payment || !job) throw new HttpError(404,'PAYMENT_OR_JOB_NOT_FOUND','Payment or job not found');
    if (resolution === 'HOLD') return { paymentStatus: payment.status, outbox: null };
    if (resolution === 'RELEASE') {
      if (!['RELEASE_PENDING','RELEASE_FAILED'].includes(payment.status)) {
        if (payment.status === 'RELEASED') return { paymentStatus: 'RELEASED', outbox: null, alreadyDone: true };
        throw new HttpError(409,'INVALID_PAYMENT_STATE','Payment cannot be released from its current state');
      }
      const event = await paymentUseCases.release({ jobId: job.id, ownerId: job.ownerId, paymentId: payment.id, dedupeKey: `PAYMENT_RELEASE:ADMIN_DISPUTE:${payment.id}` });
      let result;
      try { result = await processPaymentReleaseNow(event?.id); } catch (error) { throw new HttpError(503,'PAYMENT_RELEASE_PROCESSING','Release was queued but could not be finalized now', { cause: error }); }
      if (!result?.completed && !result?.alreadyDone) throw new HttpError(409,'PAYMENT_RELEASE_NOT_COMPLETED','Payment release was not completed');
      return { paymentStatus:'RELEASED', outbox:event, processing:result };
    }
    if (resolution === 'REFUND') {
      if (!['HELD','RELEASE_PENDING','RELEASE_FAILED'].includes(payment.status)) {
        if (payment.status === 'REFUNDED') return { paymentStatus:'REFUNDED', outbox:null, alreadyDone:true };
        throw new HttpError(409,'INVALID_PAYMENT_STATE','Payment cannot be refunded from its current state');
      }
      const created = await paymentUseCases.refund({ jobId:job.id, paymentId:payment.id, ownerId:job.ownerId, amount:payment.amount, id:crypto.randomUUID(), idempotencyKey:`DISPUTE_REFUND:${dispute.id}`, createdAt:now(), allowPendingRelease:true });
      try { await processPaymentRefundNow(); } catch (_) {}
      const refreshed = await paymentUseCases.findByJob(job.id);
      if (refreshed?.status !== 'REFUNDED') throw new HttpError(202,'PAYMENT_REFUND_PENDING','Refund is queued for processing');
      return { paymentStatus:'REFUNDED', refund:created.refund, outbox:created.outboxEvent };
    }
    throw new HttpError(400,'INVALID_DISPUTE_RESOLUTION','resolution must be RELEASE, REFUND, or HOLD');
  }

  return async function route(req,res,parts) {
    if (parts[0] === 'admin') {
      const me = requireAdmin(await authUser(req));
      if (process.env.DATABASE_URL && !(await repo.isAdminPanelVerified(me.id, 15))) throw new HttpError(403,'ADMIN_PANEL_LOCKED','Admin panel requires identity verification');
      if (parts.length === 2 && parts[1] === 'disputes' && req.method === 'GET') return sendJson(res,200,await repo.listAdminDisputes());
      if (parts.length === 3 && parts[1] === 'disputes' && req.method === 'GET') {
        const dispute = await repo.getAdminDispute(parts[2]); if (!dispute) throw new HttpError(404,'DISPUTE_NOT_FOUND','Dispute not found'); return sendJson(res,200,dispute);
      }
      if (parts.length === 3 && parts[1] === 'disputes' && req.method === 'POST' && parts[2]) {
        const body=await readBody(req); const resolution=String(body?.resolution||'').toUpperCase(); if(!DISPUTE_DECISIONS.includes(resolution)) throw new HttpError(400,'INVALID_DISPUTE_RESOLUTION','resolution must be RELEASE, REFUND, or HOLD');
        const dispute=await repo.getAdminDispute(parts[2]); if(!dispute) throw new HttpError(404,'DISPUTE_NOT_FOUND','Dispute not found');
        await resolvePayment(dispute,resolution,me.id,String(body?.reason||'').trim().slice(0,2000));
        const resolved=await repo.resolveJobDispute(dispute.id,{resolution,reason:String(body?.reason||'').trim().slice(0,2000),adminId:me.id});
        await createAudit('ADMIN_DISPUTE_RESOLVE',me.id,'job_dispute',dispute.id,{jobId:dispute.jobId,resolution,aiDecision:dispute.aiDecision,aiConfidence:dispute.aiConfidence});
        await notifyUser({userId:dispute.worker.id,type:NOTIFICATION_TYPES.PAYMENT_UPDATE,title:'نتیجه بررسی اختلاف همکاری',body:`اختلاف مربوط به «${dispute.jobTitle}» تعیین تکلیف شد.`,data:{jobId:dispute.jobId,disputeId:dispute.id,resolution},dedupeKey:`dispute:${dispute.id}:resolved:worker`,channels:['IN_APP','PUSH','EMAIL']}).catch(()=>{});
        return sendJson(res,200,resolved);
      }
      throw new HttpError(404,'NOT_FOUND','Dispute route not found');
    }

    if (parts[0] !== 'jobs' || parts.length < 3 || parts[2] !== 'dispute') throw new HttpError(404,'NOT_FOUND','Dispute route not found');
    const me=await authUser(req); const job=await (async()=>{ const context=await repo.getJobDisputeContext(parts[1]); return context?.job||null; })();
    if(!job) throw new HttpError(404,'JOB_NOT_FOUND','Job not found');
    if(!participantRole(me,job)) throw new HttpError(403,'FORBIDDEN','Only the employer or worker can use disputes');
    if(job.status!=='COMPLETED') throw new HttpError(409,'JOB_NOT_COMPLETED','Disputes start after job completion');
    if(req.method==='GET'){
      const dispute=await repo.getJobDispute(job.id);
      return sendJson(res,200,{dispute:dispute ? {
        id: dispute.id, status: dispute.status, aiDecision: dispute.aiDecision,
        aiConfidence: dispute.aiConfidence, legalRulesetVersion: dispute.legalRulesetVersion,
        aiReport: dispute.aiReport, resolution: dispute.resolution, resolutionReason: dispute.resolutionReason,
      } : null});
    }
    if(req.method==='POST'){
      const body=await readBody(req); const existing=await repo.getJobDispute(job.id);
      if(existing?.status==='RESOLVED') throw new HttpError(409,'DISPUTE_RESOLVED','This dispute is already resolved');
      const dispute=existing||await repo.createJobDispute({jobId:job.id,openedBy:me.id,triggerType:'USER'});
      const analyzed=await analyzeCase(dispute);
      await createAudit('JOB_DISPUTE_OPEN',me.id,'job',job.id,{disputeId:dispute.id,triggerType:existing?.triggerType||'USER'});
      return sendJson(res,200,{dispute:analyzed});
    }
    throw new HttpError(405,'METHOD_NOT_ALLOWED','Method not allowed');
  };
}