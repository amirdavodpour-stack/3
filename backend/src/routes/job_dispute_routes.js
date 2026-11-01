import crypto from 'node:crypto';
import { ADMIN_PERMISSIONS, assertAdminPermission } from '../application/admin_panel_access.js';
import { assertAutomatedAiAccess, assertSystemAiTask } from '../application/ai_access_policy.js';
import { DISPUTE_DECISIONS, analyzeDisputeWithAI, parseDisputeDecision } from '../services/dispute_resolution.js';

const DISPUTABLE_JOB_STATUSES = new Set(['IN_PROGRESS','DELIVERED','UNDER_REVIEW','COMPLETED']);
const DISPUTE_HOLDABLE_PAYMENT_STATUSES = new Set(['HELD','RELEASE_PENDING','RELEASE_FAILED']);

export function createJobDisputeRoutes({ authUser, requireAdmin, config, readBody, sendJson, HttpError, repo, askAI, paymentUseCases, processPaymentReleaseNow, processPaymentRefundNow, createAudit, notifyUser, NOTIFICATION_TYPES, now }) {
  const participantRole = (me, job) => job?.ownerId === me.id ? 'EMPLOYER' : job?.providerId === me.id ? 'WORKER' : null;

  async function analyzeCase(dispute) {
    const context = await repo.getJobDisputeContext(dispute.jobId);
    assertAutomatedAiAccess({ route: 'dispute-adjudication', source: 'SYSTEM' });
    assertSystemAiTask({ task: 'DISPUTE_ADJUDICATION' });
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
    if (resolution === 'HOLD') {
      const held = await repo.holdPaymentForDispute({ jobId:job.id, paymentId:payment.id });
      if (!held?.held) {
        if (held?.reason === 'PAYMENT_RELEASE_IN_PROGRESS') {
          throw new HttpError(409,'PAYMENT_RELEASE_IN_PROGRESS','A release provider operation is already in progress; retry HOLD after it settles');
        }
        if (held?.reason === 'PAYMENT_NOT_FOUND' || held?.reason === 'JOB_NOT_FOUND') {
          throw new HttpError(404,'PAYMENT_OR_JOB_NOT_FOUND','Payment or job not found');
        }
        throw new HttpError(409,'INVALID_PAYMENT_STATE','Payment cannot be held from its current state');
      }
      return { paymentStatus:'HELD', outbox:null, cancelledReleaseEvents:held.cancelledReleaseEvents };
    }
    if (resolution === 'RELEASE') {
      if (job.status !== 'COMPLETED') throw new HttpError(409,'JOB_NOT_COMPLETED','An active job must finish before funds can be released to the worker');
      if (!['HELD','RELEASE_PENDING','RELEASE_FAILED'].includes(payment.status)) {
        if (payment.status === 'RELEASED') return { paymentStatus: 'RELEASED', outbox: null, alreadyDone: true };
        throw new HttpError(409,'INVALID_PAYMENT_STATE','Payment cannot be released from its current state');
      }
      const event = await paymentUseCases.release({ jobId: job.id, ownerId: job.ownerId, paymentId: payment.id, disputeId:dispute.id, dedupeKey: `PAYMENT_RELEASE:ADMIN_DISPUTE:${payment.id}` });
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
      if (process.env.DATABASE_URL && !(await repo.isAdminPanelVerified(me.id, config?.adminPanelVerificationMinutes ?? 15))) throw new HttpError(403,'ADMIN_PANEL_LOCKED','Admin panel requires identity verification');
      if (parts.length === 2 && parts[1] === 'disputes' && req.method === 'GET') return sendJson(res,200,await repo.listAdminDisputes());
      if (parts.length === 3 && parts[1] === 'disputes' && req.method === 'GET') {
        const dispute = await repo.getAdminDispute(parts[2]); if (!dispute) throw new HttpError(404,'DISPUTE_NOT_FOUND','Dispute not found'); return sendJson(res,200,dispute);
      }
      if (parts.length === 3 && parts[1] === 'disputes' && req.method === 'POST' && parts[2]) {
        assertAdminPermission(me, ADMIN_PERMISSIONS.RESOLVE_DISPUTES);
        const body=await readBody(req); const resolution=String(body?.resolution||'').toUpperCase(); if(!DISPUTE_DECISIONS.includes(resolution)) throw new HttpError(400,'INVALID_DISPUTE_RESOLUTION','resolution must be RELEASE, REFUND, or HOLD');
        const dispute=await repo.getAdminDispute(parts[2]); if(!dispute) throw new HttpError(404,'DISPUTE_NOT_FOUND','Dispute not found');
        const reason=String(body?.reason||'').trim().slice(0,2000);
        const claim=await repo.claimJobDisputeResolution(dispute.id,{resolution,reason,adminId:me.id});
        if(!claim) throw new HttpError(404,'DISPUTE_NOT_FOUND','Dispute not found');
        if(claim.conflict) {
          const code=claim.code||'DISPUTE_RESOLUTION_CONFLICT';
          throw new HttpError(409,code,code==='DISPUTE_ALREADY_RESOLVED'
            ? 'Dispute has already been resolved with a different decision'
            : code==='DISPUTE_RESOLUTION_IN_PROGRESS'
              ? 'Another administrator is resolving this dispute'
              : 'Dispute is not in a resolvable state');
        }
        if(claim.alreadyResolved) return sendJson(res,200,claim.dispute);
        if(claim.inProgress) return sendJson(res,202,{
          disputeId:dispute.id,status:'RESOLVING',resolution:claim.resolution,
          retryAfter:claim.leaseUntil,
        });
        try {
          await resolvePayment(dispute,resolution,me.id,reason);
        } catch (error) {
          if (['PAYMENT_OR_JOB_NOT_FOUND','PAYMENT_NOT_FOUND','INVALID_PAYMENT_STATE','JOB_NOT_COMPLETED','PAYMENT_RELEASE_IN_PROGRESS'].includes(error?.code)) {
            await repo.abandonJobDisputeResolutionClaim(dispute.id,{resolution,token:claim.token});
          }
          throw error;
        }
        const resolved=await repo.completeJobDisputeResolution(dispute.id,{resolution,token:claim.token});
        if(!resolved || resolved.stale) throw new HttpError(409,'DISPUTE_RESOLUTION_CLAIM_STALE','This administrator resolution claim expired or was superseded; retry the same decision');
        await createAudit('ADMIN_DISPUTE_RESOLVE',me.id,'job_dispute',dispute.id,{jobId:dispute.jobId,resolution,aiDecision:dispute.aiDecision,aiConfidence:dispute.aiConfidence});
        const heldPendingReview = resolution === 'HOLD';
        await notifyUser({userId:dispute.worker.id,type:NOTIFICATION_TYPES.PAYMENT_UPDATE,title:heldPendingReview?'وجه تا بررسی بعدی نگه داشته شد':'نتیجه بررسی اختلاف همکاری',body:heldPendingReview?`وجه مربوط به «${dispute.jobTitle}» در escrow باقی ماند و پرونده برای تصمیم بعدی در بررسی ادمین است.`:`اختلاف مربوط به «${dispute.jobTitle}» تعیین تکلیف شد.`,data:{jobId:dispute.jobId,disputeId:dispute.id,resolution},dedupeKey:`dispute:${dispute.id}:${resolution.toLowerCase()}:${resolved.updatedAt||now()}`,channels:['IN_APP','PUSH','EMAIL']}).catch(()=>{});
        return sendJson(res,200,resolved);
      }
      throw new HttpError(404,'NOT_FOUND','Dispute route not found');
    }

    if (parts[0] !== 'jobs' || parts.length < 3 || parts[2] !== 'dispute') throw new HttpError(404,'NOT_FOUND','Dispute route not found');
    const me=await authUser(req);
    const context=await repo.getJobDisputeContext(parts[1]);
    const job=context?.job||null;
    if(!job) throw new HttpError(404,'JOB_NOT_FOUND','Job not found');
    if(!participantRole(me,job)) throw new HttpError(403,'FORBIDDEN','Only the employer or worker can use disputes');
    const existing=await repo.getJobDispute(job.id);
    if(req.method==='GET'){
      return sendJson(res,200,{dispute:existing ? {
        id: existing.id, status: existing.status, aiDecision: existing.aiDecision,
        aiConfidence: existing.aiConfidence, legalRulesetVersion: existing.legalRulesetVersion,
        aiReport: existing.aiReport, resolution: existing.resolution, resolutionReason: existing.resolutionReason,
      } : null});
    }
    if(req.method==='POST'){
      if(existing?.status==='RESOLVED') throw new HttpError(409,'DISPUTE_RESOLVED','This dispute is already resolved');
      if(existing?.status==='RESOLVING') throw new HttpError(409,'DISPUTE_RESOLUTION_IN_PROGRESS','An administrator is currently resolving this dispute');
      if(!DISPUTABLE_JOB_STATUSES.has(String(job.status||'').toUpperCase())) {
        throw new HttpError(409,'JOB_NOT_DISPUTABLE','A dispute may be opened during active work or after delivery');
      }
      const payment=context?.payment;
      if(!payment) throw new HttpError(409,'PAYMENT_REQUIRED','A funded payment is required to open a financial dispute');
      if(payment.status==='RELEASED'||payment.status==='REFUNDED') {
        throw new HttpError(409,'DISPUTE_PAYMENT_ALREADY_SETTLED','The payment has already settled; use the opportunity report path for a post-settlement complaint');
      }
      if(!DISPUTE_HOLDABLE_PAYMENT_STATUSES.has(String(payment.status||'').toUpperCase())) {
        throw new HttpError(409,'DISPUTE_PAYMENT_NOT_HOLDABLE','The payment is not in a state that can be safely held for dispute review');
      }
      const opened=await repo.openJobDisputeWithHold({jobId:job.id,paymentId:payment.id,openedBy:me.id,triggerType:'USER'});
      if(!opened?.opened) {
        if(opened?.reason==='PAYMENT_RELEASE_IN_PROGRESS') {
          throw new HttpError(409,'PAYMENT_RELEASE_IN_PROGRESS','A provider release is already in progress. The case was not opened because the funds could not be safely held.');
        }
        throw new HttpError(409,'DISPUTE_PAYMENT_NOT_HOLDABLE','The payment could not be held safely for dispute review');
      }
      const dispute=opened.dispute;
      const analyzed=await analyzeCase(dispute);
      await createAudit('JOB_DISPUTE_OPEN',me.id,'job',job.id,{disputeId:dispute.id,triggerType:'USER',paymentHeld:true,cancelledReleaseEvents:opened.cancelledReleaseEvents||0});
      return sendJson(res,200,{dispute:analyzed,payment:{status:'HELD'}});
    }
    throw new HttpError(405,'METHOD_NOT_ALLOWED','Method not allowed');
  };
}