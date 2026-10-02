import { assertAutomatedAiAccess } from '../application/ai_access_policy.js';
import { buildSatisfactionAnalysisPrompt, evaluateSettlementGate, SATISFACTION_QUESTIONS, parseSatisfactionAnalysis } from '../services/job_satisfaction.js';

export function createJobSatisfactionRoutes({
  authUser, readBody, sendJson, HttpError, repo, getJob, paymentUseCases,
  askAI, processPaymentReleaseNow, createAudit, notifyUser, NOTIFICATION_TYPES, now,
}) {
  const participantRole = (me, job) => {
    if (job.ownerId === me.id) return 'EMPLOYER';
    if (job.providerId === me.id) return 'WORKER';
    return null;
  };

  async function settleIfReady(me, job) {
    const payment = await paymentUseCases.findByJob(job.id);
    const feedback = await repo.listJobSatisfactionFeedback(job.id);
    const gate = evaluateSettlementGate({ jobStatus: job.status, paymentStatus: payment?.status, feedback });
    if (!gate.ready || !payment) return { gate, payment: payment || null, autoReleased:false };

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
    return { gate, payment, autoReleased };
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
      const settlement = await settleIfReady(me, job);
      return sendJson(res, 200, {
        feedback,
        settlement: {
          ready: settlement.gate.ready,
          reason: settlement.gate.reason,
          autoReleased: settlement.autoReleased,
        },
      });
    }

    throw new HttpError(404, 'NOT_FOUND', 'Satisfaction route not found');
  };
}
