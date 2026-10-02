import { assertAutomatedAiAccess, assertSystemAiTask } from '../application/ai_access_policy.js';
import { buildSatisfactionAnalysisPrompt, evaluateSettlementGate, SATISFACTION_QUESTIONS, parseSatisfactionAnalysis } from '../services/job_satisfaction.js';
import { analyzeDisputeWithAI } from '../services/dispute_resolution.js';
import { analyzeDisputeWithAI, parseDisputeDecision } from '../services/dispute_resolution.js';

export function createJobSatisfactionRoutes({
  authUser, readBody, sendJson, HttpError, repo, getJob, paymentUseCases,
  askAI, processPaymentReleaseNow, createAudit, notifyUser, NOTIFICATION_TYPES, now,
}) {
  const participantRole = (me, job) => {
    if (job.ownerId === me.id) return 'EMPLOYER';
    if (job.providerId === me.id) return 'WORKER';
    return null;
  };


  async function ensureDisputeIfNeeded(job, feedback) {
    if (!Array.isArray(feedback) || feedback.length < 2) return null;
    const conflict = feedback.some((item) => item.completedAsAgreed !== true || item.aiSentiment !== 'SATISFIED') ||
      Number(feedback[0]?.overallRating) !== Number(feedback[1]?.overallRating) ||
      Boolean(feedback[0]?.completedAsAgreed) !== Boolean(feedback[1]?.completedAsAgreed);
    if (!conflict) return null;
    const existing = await repo.getJobDispute(job.id);
    const dispute = existing || await repo.createJobDispute({ jobId: job.id, triggerType: 'SATISFACTION_CONFLICT' });
    if (dispute?.status === 'RESOLVED') return dispute;
    const context = await repo.getJobDisputeContext(job.id);
    assertAutomatedAiAccess({ route: 'dispute-resolution', source: 'SYSTEM' });
    try {
      const analysis = await analyzeDisputeWithAI({ askAI, context });
      const stored = await repo.updateJobDisputeAnalysis(dispute.id, analysis);
      await createAudit('AI_DISPUTE_ANALYSIS', null, 'job_dispute', dispute.id, {
        jobId: job.id,
        decision: analysis.decision,
        confidence: analysis.confidence,
        manualReview: analysis.manualReview,
        rulesetVersion: analysis.rulesetVersion,
      });
      return stored;
    } catch (error) {
      await repo.markJobDisputeAdminReview(dispute.id);
      await createAudit('AI_DISPUTE_ANALYSIS_FAILED', null, 'job_dispute', dispute.id, {
        jobId: job.id,
        code: error?.code || 'AI_ANALYSIS_FAILED',
      });
      return repo.getJobDispute(job.id);
    }
  }

  async function settleIfReady(me, job) {
    const payment = await paymentUseCases.findByJob(job.id);
    const feedback = await repo.listJobSatisfactionFeedback(job.id);
    const gate = evaluateSettlementGate({ jobStatus: job.status, paymentStatus: payment?.status, feedback });
    if (!gate.ready || !payment) {
      if (payment && feedback.length === 2 && feedback.every((item) => item.status === 'ANALYZED')) {
        const conflict = await repo.createJobDispute({ jobId: job.id, openedBy: me.id, triggerType: 'SATISFACTION_CONFLICT' });
        if (conflict.status === 'AI_ANALYZED' || conflict.status === 'ADMIN_REVIEW') {
          return { gate, payment, autoReleased:false, dispute:conflict };
        }
        if (conflict.status !== 'RESOLVED') {
          try {
            assertAutomatedAiAccess({ route: 'dispute-adjudication', source: 'SYSTEM' });
            assertSystemAiTask({ task: 'DISPUTE_ADJUDICATION' });
            const context = await repo.getJobDisputeContext(job.id);
            const analysis = await analyzeDisputeWithAI({ askAI, context });
            const analyzed = await repo.updateJobDisputeAnalysis(conflict.id, analysis);
            await createAudit('JOB_DISPUTE_AUTO_ANALYZE', me.id, 'job_dispute', conflict.id, { jobId: job.id, decision: analyzed.aiDecision, confidence: analyzed.aiConfidence, rulesetVersion: analyzed.legalRulesetVersion });
            return { gate, payment, autoReleased:false, dispute:analyzed };
          } catch (_) {
            return { gate, payment, autoReleased:false, dispute:conflict };
          }
        }
      }
      return { gate, payment: payment || null, autoReleased:false };
    }

    let event;
    try {
      event = await paymentUseCases.release({
        jobId: job.id,
        ownerId: job.ownerId,
        paymentId: payment.id,
        dedupeKey: `PAYMENT_RELEASE:AUTO_SATISFACTION:${payment.id}`,
      });
    } catch (error) {
      if (error?.code === 'INVALID_PAYMENT_STATE') {
        const current = await paymentUseCases.findByJob(job.id);
        if (current?.status === 'RELEASED') return { gate, payment: current, autoReleased: true };
      }
      throw error;
    }
    let autoReleased = false;
    try {
      const result = await processPaymentReleaseNow(event?.id);
      autoReleased = result?.completed === true;
    } catch (_) {
      autoReleased = false;
    }
    if (autoReleased) {
      await createAudit('PAYMENT_AUTO_RELEASE_SATISFACTION', me.id, 'payment', payment.id, { jobId: job.id });
      await notifyUser({
        userId: job.providerId,
        type: NOTIFICATION_TYPES.PAYMENT_UPDATE,
        title: 'پرداخت خودکار تسویه شد',
        body: `پس از تکمیل گزارش رضایت دو طرف، پرداخت «${job.title}» به کیف پول شما اعمال شد.`,
        data: { jobId: job.id, paymentId: payment.id, status: 'RELEASED' },
        dedupeKey: `payment:${payment.id}:AUTO_SATISFACTION_RELEASED`,
        channels: ['IN_APP','PUSH','EMAIL'],
      });
    }
    return { gate, payment, autoReleased, dispute: null };
  }

  return async function route(req, res, parts) {
    if (parts.length < 2 || parts[0] !== 'jobs') throw new HttpError(404, 'NOT_FOUND', 'Satisfaction route not found');
    const me = await authUser(req);
    if (parts.length === 2 && parts[0] === 'jobs' && parts[1] === 'satisfaction-history') {
      if (req.method !== 'GET') throw new HttpError(405, 'METHOD_NOT_ALLOWED', 'Method not allowed');
      const history = await repo.listUserSatisfactionHistory(me.id);
      return sendJson(res, 200, { history });
    }
    const job = await getJob(parts[1]);
    if (!job) throw new HttpError(404, 'JOB_NOT_FOUND', 'Job not found');
    const role = participantRole(me, job);
    if (!role) throw new HttpError(403, 'FORBIDDEN', 'Only the employer or worker can use job satisfaction');

    if (req.method === 'GET' && parts.length === 3 && parts[2] === 'satisfaction') {
      const feedback = await repo.getJobSatisfactionFeedbackForUser(job.id, me.id);
      const all = await repo.listJobSatisfactionFeedback(job.id);
      return sendJson(res, 200, {
        jobId: job.id,
        role,
        questions: SATISFACTION_QUESTIONS,
        submitted: Boolean(feedback),
        feedback,
        progress: { submittedCount: all.length, requiredCount: 2 },
      });
    }

    if (req.method === 'POST' && parts.length === 3 && parts[2] === 'satisfaction') {
      if (job.status !== 'COMPLETED') throw new HttpError(409, 'JOB_NOT_COMPLETED', 'Satisfaction starts after job completion');
      const existing = await repo.getJobSatisfactionFeedbackForUser(job.id, me.id);
      if (existing?.status === 'ANALYSIS_FAILED') {
        assertAutomatedAiAccess({ route: 'job-satisfaction-retry', source: 'SYSTEM' });
        assertSystemAiTask({ task: 'JOB_SATISFACTION' });
        let analysis;
        try {
          const raw = await askAI(buildSatisfactionAnalysisPrompt({
            role,
            answers: {
              overallRating: existing.overallRating,
              completedAsAgreed: existing.completedAsAgreed,
              communicationRating: existing.communicationRating,
              report: existing.reportText,
            },
          }));
          analysis = parseSatisfactionAnalysis(raw);
        } catch (_) {
          return sendJson(res, 202, { retrying: true, settlement: { ready: false, reason: 'AI_ANALYSIS_UNAVAILABLE', autoReleased: false } });
        }
        const feedback = await repo.updateJobSatisfactionAnalysis(existing.id, analysis);
        const settlement = await settleIfReady(me, job);
        return sendJson(res, 200, { feedback, settlement: { ready: settlement.gate.ready, reason: settlement.gate.reason, autoReleased: settlement.autoReleased } });
      }
      if (existing) throw new HttpError(409, 'FEEDBACK_ALREADY_SUBMITTED', 'Feedback already submitted');

      const body = await readBody(req);
      const overallRating = Number(body?.overallRating);
      const communicationRating = Number(body?.communicationRating);
      const completedAsAgreed = body?.completedAsAgreed === true;
      const reportText = String(body?.report || '').trim();
      if (!Number.isInteger(overallRating) || overallRating < 1 || overallRating > 5) throw new HttpError(400, 'INVALID_OVERALL_RATING', 'overallRating must be 1..5');
      if (!Number.isInteger(communicationRating) || communicationRating < 1 || communicationRating > 5) throw new HttpError(400, 'INVALID_COMMUNICATION_RATING', 'communicationRating must be 1..5');
      if (reportText.length > 2000) throw new HttpError(400, 'REPORT_TOO_LONG', 'Report is too long');

      assertAutomatedAiAccess({ route: 'job-satisfaction', source: 'SYSTEM' });
      assertSystemAiTask({ task: 'JOB_SATISFACTION' });
      let analysis;
      let status = 'ANALYZED';
      try {
        const raw = await askAI(buildSatisfactionAnalysisPrompt({
          role,
          answers: { overallRating, completedAsAgreed, communicationRating, report: reportText },
        }));
        analysis = parseSatisfactionAnalysis(raw);
      } catch (_) {
        analysis = parseSatisfactionAnalysis({});
        status = 'ANALYSIS_FAILED';
      }

      const feedback = await repo.insertJobSatisfactionFeedback({
        jobId: job.id, userId: me.id, role, overallRating, completedAsAgreed, communicationRating,
        reportText, analysis, status,
      });
      await createAudit('JOB_SATISFACTION_SUBMIT', me.id, 'job', job.id, {
        role,
        overallRating,
        completedAsAgreed,
        communicationRating,
        aiSatisfactionScore: analysis.satisfactionScore,
        aiSentiment: analysis.sentiment,
      });
      const settlement = await settleIfReady(me, job);
      return sendJson(res, 200, {
        feedback,
        settlement: {
          ready: settlement.gate.ready,
          reason: settlement.gate.reason,
          autoReleased: settlement.autoReleased,
          dispute: settlement.dispute || null,
        },
      });
    }

    throw new HttpError(404, 'NOT_FOUND', 'Satisfaction route not found');
  };
}
