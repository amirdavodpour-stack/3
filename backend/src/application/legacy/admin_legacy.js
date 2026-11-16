import { config } from '../../config.js';
import { randomUUID } from 'node:crypto';
/** Explicit test-only admin adapter over the legacy in-memory DB facade. */
export function createAdminLegacyAdapter({ db, findUser, now }) {
  return Object.freeze({
    financialSummary() {
      const payments = db.collection.payments;
      const refunds = db.collection.refunds;
      const settlements = db.collection.settlements;
      const ledgerEntries = db.collection.ledgerEntries;
      return {
        payments: payments.length,
        pending: payments.filter((p) => ['HOLD_PENDING','REFUND_PENDING','RELEASE_PENDING','RELEASE_FAILED'].includes(p.status)).length,
        held: payments.filter((p) => p.status === 'HELD').length,
        released: payments.filter((p) => p.status === 'RELEASED').length,
        refunded: payments.filter((p) => p.status === 'REFUNDED').length,
        platformFees: payments.reduce((s, p) => s + Number(p.platformFee || 0), 0),
        employerCharges: payments.reduce((s, p) => s + Number(p.employerCharge || p.amount || 0), 0),
        providerPayouts: payments.reduce((s, p) => s + Number(p.providerPayout || p.amount || 0), 0),
        refunds: refunds.length,
        settlements: settlements.length,
        ledgerEntries: ledgerEntries.length,
      };
    },
    summary() {
      const users = db.collection.users;
      const jobs = db.collection.jobs;
      const apps = db.collection.jobApplications;
      return {
        users: users.length,
        admins: users.filter((u) => u.role === 'ADMIN').length,
        active_users: users.filter((u) => u.role === 'USER' && u.status === 'ACTIVE').length,
        suspended_users: users.filter((u) => u.status !== 'ACTIVE').length,
        opportunities: jobs.length,
        published_opportunities: jobs.filter((j) => j.status === 'PUBLISHED').length,
        draft_opportunities: jobs.filter((j) => j.status === 'DRAFT').length,
        missions: jobs.filter((j) => j.kind === 'MISSION').length,
        jobs: jobs.filter((j) => j.kind === 'JOB').length,
        applications: apps.length,
        pending_applications: apps.filter((a) => ['PENDING','SHORTLISTED'].includes(a.status)).length,
        audit_events: db.collection.audit.length,
      };
    },
    users: () => db.collection.users.slice().sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt))).map((user) => {
      const review = (db.collection.adminUserStatusReviewCases || [])
        .filter((item) => item.userId === user.id && item.status === 'OPEN')
        .sort((a,b) => String(b.createdAt).localeCompare(String(a.createdAt)))[0];
      return {
        ...user,
        statusReviewCaseId: review?.id || null,
        statusReviewReason: review?.reason || null,
        statusReviewDueAt: review?.reviewDueAt || null,
      };
    }),
    getAdminUser(id) { return db.collection.users.find((x) => x.id === id) || null; },
    grantAdminByEmail(email, actorId) {
      const actor = db.collection.users.find((x) => x.id === actorId);
      if (
        !actor ||
        actor.role !== 'ADMIN' ||
        actor.status !== 'ACTIVE' ||
        String(actor.email || '').trim().toLowerCase() !== 'amir.davodpour@gmail.com' ||
        !String(actor.googleSubject || '').trim()
      ) {
        const error = new Error('PRIMARY_ADMIN_ONLY');
        error.code = 'PRIMARY_ADMIN_ONLY';
        error.status = 403;
        throw error;
      }
      const targetEmail = String(email || '').trim().toLowerCase();
      const target = db.collection.users.find((x) => String(x.email || '').trim().toLowerCase() === targetEmail);
      if (!target) return null;
      if (target.status !== 'ACTIVE') {
        const error = new Error('ADMIN_TARGET_NOT_ACTIVE');
        error.code = 'ADMIN_TARGET_NOT_ACTIVE';
        error.status = 409;
        throw error;
      }
      if (!String(target.googleSubject || '').trim()) {
        const error = new Error('ADMIN_PROVIDER_IDENTITY_REQUIRED');
        error.code = 'ADMIN_PROVIDER_IDENTITY_REQUIRED';
        error.status = 409;
        throw error;
      }
      if (String(target.role || '').toUpperCase() === 'ADMIN') {
        return { ...target, roleGrantApplied: false };
      }
      target.role = 'ADMIN';
      target.sessionVersion = Number(target.sessionVersion || 0) + 1;
      target.adminPanelVerifiedAt = null;
      target.adminPanelVerifiedSessionJti = null;
      target.adminPanelVerifiedScope = null;
      db.touch('users');
      return { ...target, roleGrantApplied: true };
    },
    setUserStatus(id, status, { actorId, reason, reviewDueAt } = {}) {
      const user = db.collection.users.find((x) => x.id === id);
      if (!user) return null;
      if (user.status === 'DELETED') {
        const error = new Error('ACCOUNT_DELETION_TERMINAL');
        error.code = 'ACCOUNT_DELETION_TERMINAL';
        error.status = 409;
        throw error;
      }
      if (String(reason || '').trim().length < 3 || String(reason || '').trim().length > 1000) {
        const error = new Error('ADMIN_USER_STATUS_REASON_REQUIRED');
        error.code = 'ADMIN_USER_STATUS_REASON_REQUIRED';
        error.status = 400;
        throw error;
      }
      const why = String(reason).trim();
      const currentTime = typeof now === 'function' ? new Date(now()) : new Date();
      const cases = db.collection.adminUserStatusReviewCases ||= [];
      let reviewCaseId = null;
      let due = null;
      if (status === 'SUSPENDED') {
        due = new Date(reviewDueAt);
        const delta = due.getTime() - currentTime.getTime();
        if (!Number.isFinite(currentTime.getTime()) || !Number.isFinite(due.getTime()) || delta < 60*60*1000 || delta > 7*24*60*60*1000) {
          const error = new Error('INVALID_REVIEW_DEADLINE');
          error.code = 'INVALID_REVIEW_DEADLINE';
          error.status = 400;
          throw error;
        }
        const review = {
          id: randomUUID(), userId: id, status: 'OPEN', reason: why,
          createdBy: actorId, createdAt: currentTime.toISOString(),
          reviewDueAt: due.toISOString(), resolvedBy: null,
          resolvedAt: null, resolutionReason: null,
        };
        cases.push(review);
        reviewCaseId = review.id;
      } else {
        const review = cases.find((item) => item.userId === id && item.status === 'OPEN');
        if (review) {
          review.status = 'RESOLVED';
          review.resolvedBy = actorId;
          review.resolvedAt = currentTime.toISOString();
          review.resolutionReason = why;
          reviewCaseId = review.id;
        }
      }
      user.status = status;
      user.sessionVersion = Number(user.sessionVersion || 0) + 1;
      // Legacy persistence serializes the complete state after a known collection is marked dirty.
      // adminUserStatusReviewCases is an extension field, not a registered DB collection.
      db.touch('users');
      return { ...user, reviewCaseId, reviewDueAt: due?.toISOString() || null };
    },
    revokeAdminById(id, actorId) {
      const actor = db.collection.users.find((x) => x.id === actorId);
      if (
        !actor ||
        actor.role !== 'ADMIN' ||
        actor.status !== 'ACTIVE' ||
        String(actor.email || '').trim().toLowerCase() !== 'amir.davodpour@gmail.com' ||
        !String(actor.googleSubject || '').trim()
      ) {
        const error = new Error('PRIMARY_ADMIN_ONLY');
        error.code = 'PRIMARY_ADMIN_ONLY';
        error.status = 403;
        throw error;
      }
      const target = db.collection.users.find((x) => x.id === id);
      if (!target) return null;
      if (String(target.email || '').trim().toLowerCase() === 'amir.davodpour@gmail.com') {
        const error = new Error('PRIMARY_ADMIN_PROTECTED');
        error.code = 'PRIMARY_ADMIN_PROTECTED';
        error.status = 403;
        throw error;
      }
      if (target.role !== 'ADMIN') {
        const error = new Error('NOT_AN_ADMIN');
        error.code = 'NOT_AN_ADMIN';
        error.status = 409;
        throw error;
      }
      target.role = 'USER';
      target.sessionVersion = Number(target.sessionVersion || 0) + 1;
      target.adminPanelVerifiedAt = null;
      target.adminPanelVerifiedSessionJti = null;
      target.adminPanelVerifiedScope = null;
      db.touch('users');
      return target;
    },
    revokeUserSessions(id) {
      const user=db.collection.users.find((x)=>x.id===id);
      if(!user) return null;
      user.sessionVersion=Number(user.sessionVersion||0)+1;
      db.touch('users');
      return {id:user.id,sessionVersion:Number(user.sessionVersion)};
    },
    trustReports(status) {
      return db.collection.trustReports
        .filter((r) => !status || r.status === status)
        .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
    },
    updateTrustReportStatus(id, status) {
      const report = db.collection.trustReports.find((x) => x.id === id);
      if (!report) return null;
      report.status = status;
      report.updatedAt = now();
      db.touch('trustReports');
      return report;
    },
    audit() {
      return db.collection.audit
        .slice()
        .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))
        .map((a) => ({ ...a, actorName: findUser(a.actorId)?.displayName || null }));
    },
    jobs: () => db.collection.jobs.slice().sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt))),
    moderateJob(id, status) {
      const job = db.collection.jobs.find((x) => x.id === id);
      if (!job) return null;
      if (['COMPLETED','ASSIGNED','FUNDED','IN_PROGRESS','DELIVERED','UNDER_REVIEW'].includes(job.status)) {
        const error = new Error('JOB_LOCKED');
        error.code = 'JOB_LOCKED';
        throw error;
      }
      job.status = status;
      job.updatedAt = now();
      if (status === 'PUBLISHED' && !job.publishedAt) job.publishedAt = now();
      db.touch('jobs');
      return job;
    },
    deleteJob(id) {
      const financial = db.collection.payments.find((p) => p.jobId === id);
      if (financial) {
        const error = new Error('JOB_HAS_FINANCIAL_RECORDS');
        error.code = 'JOB_HAS_FINANCIAL_RECORDS';
        throw error;
      }
      db.collection.jobs = db.collection.jobs.filter((j) => j.id !== id);
      db.collection.offers = db.collection.offers.filter((o) => o.jobId !== id);
      db.collection.jobApplications = db.collection.jobApplications.filter((a) => a.jobId !== id);
      db.collection.evidence = db.collection.evidence.filter((e) => e.jobId !== id);
      db.touch('jobs', 'offers', 'jobApplications', 'evidence');
      return true;
    },
    applications: () => db.collection.jobApplications
      .slice()
      .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))
      .map((a) => {
        const job = db.collection.jobs.find((j) => j.id === a.jobId);
        const user = findUser(a.candidateId);
        return { ...a, jobTitle: job?.title || '—', candidateName: user?.displayName || '—' };
      }),
    shortlist(id) {
      const application = db.collection.jobApplications.find((x) => x.id === id && x.status === 'PENDING');
      if (!application) return null;
      application.status = 'SHORTLISTED';
      application.updatedAt = now();
      db.touch('jobApplications');
      return application;
    },
    forward(id) {
      const application = db.collection.jobApplications.find((x) => x.id === id && ['PENDING','SHORTLISTED'].includes(x.status));
      if (!application) return null;
      application.status = 'FORWARDED';
      application.updatedAt = now();
      db.touch('jobApplications');
      return application;
    },
    reject(id) {
      const application = db.collection.jobApplications.find((x) => x.id === id && ['PENDING','SHORTLISTED'].includes(x.status));
      if (!application) return null;
      application.status = 'REJECTED';
      application.updatedAt = now();
      db.touch('jobApplications');
      return application;
    },
    save: () => db.save(),
  });
}
