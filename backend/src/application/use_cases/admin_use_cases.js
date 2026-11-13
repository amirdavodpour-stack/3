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
    grantAdminByEmail: (email, actorId, options) => repository.grantAdminByEmail(email, actorId, options),
    revokeAdminById: (id, actorId, options) => repository.revokeAdminById(id, actorId, options),
    revokeUserSessions: (id, options) => repository.revokeUserSessions(id, options),
    moderateJob: (id, status, options) => repository.moderateJob(id, status, options),
    deleteJob: (id, options) => repository.deleteJob(id, options),
    trustReports: (status) => repository.listTrustReports(status),
    updateTrustReportStatus: (id, status, options) => repository.updateTrustReportStatus(id, status, options),
    shortlist: (id, options) => repository.transitionAdminJobApplication(id, 'PENDING', 'SHORTLISTED', options),
    forward: (id, options) => repository.transitionAdminJobApplication(id, ['PENDING', 'SHORTLISTED'], 'FORWARDED', options),
    reject: (id, options) => repository.transitionAdminJobApplication(id, ['PENDING', 'SHORTLISTED'], 'REJECTED', options),
  });
}
