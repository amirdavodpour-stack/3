import { requirePort } from '../ports/repositories.js';

export function createAdminUseCases({ admin }) {
  const repository = requirePort(admin, 'admin repository');
  return Object.freeze({
    summary: () => repository.getAdminSummary(),
    users: () => repository.listAdminUsers(),
    getAdminUser: (id) => repository.getAdminUser(id),
    jobs: () => repository.listAdminJobs(),
    applications: () => repository.listAdminApplications(),
    audit: () => repository.listAdminAudit(),
    setUserStatus: (id, status, options) => repository.setUserStatus(id, status, options),
    grantAdminByEmail: (email, actorId) => repository.grantAdminByEmail(email, actorId),
    revokeAdminById: (id, actorId) => repository.revokeAdminById(id, actorId),
    revokeUserSessions: (id) => repository.revokeUserSessions(id),
    moderateJob: (id, status, options) => repository.moderateJob(id, status, options),
    deleteJob: (id, options) => repository.deleteJob(id, options),
    trustReports: (status) => repository.listTrustReports(status),
    updateTrustReportStatus: (id, status, options) => repository.updateTrustReportStatus(id, status, options),
    shortlist: (id) => repository.transitionJobApplication(id, 'PENDING', 'SHORTLISTED'),
    forward: (id) => repository.selectJobApplication(id),
    reject: (id) => repository.transitionJobApplication(id, ['PENDING', 'SHORTLISTED'], 'REJECTED'),
  });
}
