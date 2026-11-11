import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');

function block(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  const end = endMarker ? source.indexOf(endMarker, start) : source.length;
  assert.ok(start >= 0 && end > start, `Expected source block: ${startMarker}`);
  return source.slice(start, end);
}

test('shared admin actor lock helper uses stable actor/target order and verifies role, identity and exact-session step-up', () => {
  const helper = read('backend/src/repository/admin_authorization.js');
  assert.match(helper, /ORDER BY id\s+FOR UPDATE/);
  assert.match(helper, /role\s*!==\s*'ADMIN'/);
  assert.match(helper, /status\s*!==\s*'ACTIVE'/);
  assert.match(helper, /google_subject/);
  assert.match(helper, /admin_panel_verified_session_jti/);
  assert.match(helper, /admin_panel_verified_scope/);
  assert.match(helper, /verificationMinutes/);
});

test('admin session revocation validates actor and commits audit under the same transaction', () => {
  const repo = read('backend/src/repository/admin.js');
  const revoke = block(repo, 'export async function revokeUserSessions(', 'export async function listAdminAudit(');
  assert.match(revoke, /withSqlTransaction/);
  assert.match(revoke, /lockAuthorizedAdminActor/);
  assert.match(revoke, /targetUserId/);
  assert.match(revoke, /INSERT INTO audit_logs/);
  assert.match(revoke, /ADMIN_SESSIONS_REVOKE/);
});

test('admin session revocation route passes actor session provenance and avoids a second PostgreSQL audit', () => {
  const route = read('backend/src/routes/admin_routes.js');
  const revoke = block(route, "if(req.method==='POST' && parts[0]==='admin' && parts[1]==='users' && parts[3]==='revoke-sessions')", "if (parts[0] === 'admin' && parts[1] === 'disputes')");
  assert.match(revoke, /actorId:\s*me\.id/);
  assert.match(revoke, /sessionJti:\s*me\.sessionJti/);
  assert.match(revoke, /if\(!process\.env\.DATABASE_URL\)[\s\S]*createAudit/);
});

test('trust status and dispute claim revalidate current admin identity and WRITE step-up inside their SQL transaction', () => {
  const trust = read('backend/src/repository/trust.js');
  const trustUpdate = block(trust, 'export async function updateTrustReportStatus(', 'export async function listCandidatesForComparison(');
  assert.match(trustUpdate, /lockAuthorizedAdminActor/);

  const disputes = read('backend/src/repository/disputes.js');
  const claim = block(disputes, 'export async function claimJobDisputeResolution(', 'export async function completeJobDisputeResolution(');
  assert.match(claim, /lockAuthorizedAdminActor/);
  assert.match(claim, /sessionJti/);
});

test('unknown payout resolution requires an explicit ADMIN or PROVIDER_RECONCILIATION source', () => {
  const payouts = read('backend/src/repository/payouts.js');
  const resolve = block(payouts, 'export async function resolvePayoutUnknown(', 'export async function completePayoutOutbox(');
  assert.match(resolve, /source/);
  assert.match(resolve, /PROVIDER_RECONCILIATION/);
  assert.match(resolve, /lockAuthorizedAdminActor/);

  const worker = read('backend/src/reconciliation_worker.js');
  assert.match(worker, /source:\s*'PROVIDER_RECONCILIATION'/);

  const route = read('backend/src/routes/admin_routes.js');
  assert.match(route, /source:\s*'ADMIN'/);
  assert.match(route, /adminSessionJti:\s*me\.sessionJti/);
});

test('MFA enrollment start and completion both serialize against admin role/status changes', () => {
  const mfa = read('backend/src/repository/admin_mfa.js');
  const begin = block(mfa, 'export async function beginAdminMfaEnrollment(', 'export async function completeAdminMfaEnrollment(');
  const complete = block(mfa, 'export async function completeAdminMfaEnrollment(', 'export async function consumeAdminTotpCounter(');
  assert.match(begin, /lockAuthorizedAdminActor/);
  assert.match(complete, /lockAuthorizedAdminActor/);
});

test('database-backed admin step-up checks always enforce operation scope even when MFA enrollment is optional', () => {
  const admin = read('backend/src/routes/admin_routes.js');
  assert.match(admin, /repo\.setAdminPanelVerified\(me\.id,sessionJti,scope,/);
  assert.ok(admin.includes('repo.isAdminPanelVerified(me.id,ttlMinutes,me.sessionJti,requiredScope)'));
  assert.doesNotMatch(admin, /repo\.isAdminPanelVerified\(me\.id,config\.adminPanelVerificationMinutes\s*,\s*me\.sessionJti\)/);

  const disputes = read('backend/src/routes/job_dispute_routes.js');
  assert.match(disputes, /repo\.isAdminPanelVerified\(me\.id,verificationMinutes,me\.sessionJti,requiredScope\)/);
  assert.doesNotMatch(disputes, /repo\.isAdminPanelVerified\(me\.id,config\?\.adminPanelVerificationMinutes\s*\?\?\s*15,me\.sessionJti\)/);

  const wallet = read('backend/src/application/wallet_routes.js');
  assert.ok(wallet.includes("walletRepo.isAdminPanelVerified(me.id, config?.adminPanelWriteVerificationMinutes ?? 5, me.sessionJti, 'WRITE')"));

  const chat = read('backend/src/routes/human_chat_routes.js');
  assert.match(chat, /repo\.isAdminPanelVerified\(admin\.id,req\.method === 'GET'[\s\S]*?admin\.sessionJti,req\.method === 'GET' \? 'READ' : 'WRITE'\)/);
  assert.doesNotMatch(chat, /repo\.isAdminPanelVerified\(admin\.id,config\?\.adminPanelVerificationMinutes\s*\?\?\s*15,admin\.sessionJti\)/);

  const analytics = read('backend/src/routes/analytics_routes.js');
  assert.ok(analytics.includes("repo.isAdminPanelVerified(me.id, config?.adminPanelReadVerificationMinutes ?? config?.adminPanelVerificationMinutes ?? 15, me.sessionJti, 'READ')"));

  const payment = read('backend/src/routes/payment_routes.js');
  assert.ok(payment.includes("repo.isAdminPanelVerified(admin.id, config?.adminPanelReadVerificationMinutes ?? config?.adminPanelVerificationMinutes ?? 15, admin.sessionJti, 'READ')"));
});

test('Admin panel unlock/lock and MFA setup/enrollment commit security state with audit in the same repository transaction', () => {
  const disputes = read('backend/src/repository/disputes.js');
  const unlock = block(disputes, 'export async function setAdminPanelVerified(', 'export async function isAdminPanelVerified(');
  const lock = block(disputes, 'export async function clearAdminPanelVerification(');
  assert.match(unlock, /withSqlTransaction/);
  assert.match(unlock, /ADMIN_PANEL_UNLOCK/);
  assert.match(unlock, /INSERT INTO audit_logs/);
  assert.match(lock, /withSqlTransaction/);
  assert.match(lock, /ADMIN_PANEL_LOCK/);
  assert.match(lock, /INSERT INTO audit_logs/);

  const mfa = read('backend/src/repository/admin_mfa.js');
  const begin = block(mfa, 'export async function beginAdminMfaEnrollment(', 'export async function completeAdminMfaEnrollment(');
  const complete = block(mfa, 'export async function completeAdminMfaEnrollment(', 'export async function consumeAdminTotpCounter(');
  assert.match(begin, /withSqlTransaction/);
  assert.match(begin, /ADMIN_MFA_SETUP_STARTED/);
  assert.match(begin, /INSERT INTO audit_logs/);
  assert.match(complete, /withSqlTransaction/);
  assert.match(complete, /ADMIN_MFA_ENROLLED/);
  assert.match(complete, /INSERT INTO audit_logs/);
});

test('admin application shortlist/forward/reject commit actor audit and retryable notification outbox with the status transition', () => {
  const applications = read('backend/src/repository/applications.js');
  const transition = block(applications, 'const ADMIN_APPLICATION_ACTIONS', 'export async function transitionEmployerApplication(');
  assert.match(transition, /withSqlTransaction/);
  assert.match(transition, /lockAuthorizedAdminActor/);
  assert.match(transition, /FOR UPDATE/);
  assert.match(transition, /INSERT INTO audit_logs/);
  assert.match(transition, /queueNotificationWithClient/);
  assert.match(transition, /ADMIN_APPLICATION_SHORTLIST/);
  assert.match(transition, /ADMIN_APPLICATION_FORWARD/);
  assert.match(transition, /ADMIN_APPLICATION_REJECT/);

  const notifications = read('backend/src/repository/notifications.js');
  assert.match(notifications, /export async function queueNotificationWithClient/);
  assert.match(notifications, /reserveOutboxDedupeKeyWithClient/);
  assert.match(notifications, /insertReservedOutboxEventWithClient/);
  assert.match(notifications, /conflictPolicy:'FIRST_WINS'/);
  assert.match(notifications, /payload:\{schemaVersion:2,channel\}/);

  const useCases = read('backend/src/application/use_cases/admin_use_cases.js');
  assert.match(useCases, /transitionAdminJobApplication\(id,\s*'PENDING',\s*'SHORTLISTED',\s*options\)/);
  assert.match(useCases, /transitionAdminJobApplication\(id,\s*\['PENDING',\s*'SHORTLISTED'\],\s*'FORWARDED',\s*options\)/);
  assert.match(useCases, /transitionAdminJobApplication\(id,\s*\['PENDING',\s*'SHORTLISTED'\],\s*'REJECTED',\s*options\)/);

  const ports = read('backend/src/application/ports/repository_ports.js');
  assert.match(ports, /'transitionAdminJobApplication'/);

  const routes = read('backend/src/routes/admin_routes.js');
  for (const marker of ['ADMIN_APPLICATION_SHORTLIST','ADMIN_APPLICATION_FORWARD','ADMIN_APPLICATION_REJECT']) {
    assert.ok(routes.includes(marker), `route should preserve notification type ${marker}`);
  }
  assert.match(routes, /adminUseCases\.shortlist\(id,applicationOptions\)/);
  assert.match(routes, /adminUseCases\.forward\(id,applicationOptions\)/);
  assert.match(routes, /adminUseCases\.reject\(id,applicationOptions\)/);
});

test('sandbox wallet credit attributes the ledger operation and idempotency principal to the acting administrator', () => {
  const walletRoutes = read('backend/src/application/wallet_routes.js');
  const sandboxCall = walletRoutes.slice(walletRoutes.indexOf("if (req.method === 'POST' && parts[1] === 'sandbox-credit')"));
  assert.ok(sandboxCall.includes('userId:String(body.userId)'));
  assert.ok(sandboxCall.includes('idempotencyKey:`sandbox:${body.idempotencyKey}`'));
  assert.ok(sandboxCall.includes('actorId:me.id'));
  assert.match(sandboxCall, /metadata:\{\s*actorId:me\.id,\s*sandbox:true\s*\}/);
});


test('all inherited database admin mutations revalidate exact-session WRITE access under their SQL transaction', () => {
  const repository = read('backend/src/repository/admin.js');
  const methods = [
    ['setUserStatus', 'revokeAdminById'],
    ['revokeAdminById', 'revokeUserSessions'],
    ['moderateJob', 'listAdminJobs'],
    ['deleteJob', 'grantAdminByEmail'],
    ['grantAdminByEmail', null],
  ];

  for (const [name, nextName] of methods) {
    const source = block(
      repository,
      `export async function ${name}(`,
      nextName ? `export async function ${nextName}(` : null,
    );
    assert.match(source, /withSqlTransaction/,`${name} must retain one SQL transaction`);
    assert.match(source, /lockAuthorizedAdminActor\(client/,`${name} must lock/revalidate the actor under that transaction`);
    assert.match(source, /sessionJti/,`${name} must bind step-up to the authenticated session`);
    assert.match(source, /requiredScope:\s*'WRITE'/,`${name} must require current WRITE step-up`);
  }

  for (const name of ['setUserStatus', 'revokeAdminById', 'grantAdminByEmail']) {
    const source = block(
      repository,
      `export async function ${name}(`,
      name === 'setUserStatus' ? 'export async function revokeAdminById(' :
        name === 'revokeAdminById' ? 'export async function revokeUserSessions(' :
        null,
    );
    assert.match(source, /targetUserIds:\s*\[.*\]/s,`${name} must use stable actor/target row locking`);
  }
});

test('admin mutation routes pass the authenticated session JTI and write-verification TTL into repositories', () => {
  const route = read('backend/src/routes/admin_routes.js');
  const slices = [
    block(route, "if(req.method==='POST' && parts[0]==='admin' && parts[1]==='admins' && parts.length===2)", "if(req.method==='DELETE' && parts[0]==='admin' && parts[1]==='admins'"),
    block(route, "if(req.method==='DELETE' && parts[0]==='admin' && parts[1]==='admins'", "if(req.method==='POST' && parts[0]==='admin' && parts[1]==='users'"),
    block(route, "if(req.method==='POST' && parts[0]==='admin' && parts[1]==='users' && parts[3]==='status')", "if(req.method==='GET' && parts[0]==='admin' && parts[1]==='trust-reports')"),
    block(route, "if(req.method==='POST' && parts[0]==='admin' && parts[1]==='jobs' && parts[3]==='moderate')", "if(req.method==='DELETE' && parts[0]==='admin' && parts[1]==='jobs'"),
    block(route, "if(req.method==='DELETE' && parts[0]==='admin' && parts[1]==='jobs'", "if(req.method==='POST' && parts[0]==='admin' && parts[1]==='applications'"),
  ];

  for (const source of slices) {
    assert.match(source, /sessionJti:\s*me\.sessionJti/);
    assert.match(source, /verificationMinutes:\s*config(?:\?\.)?\.?.*adminPanelWriteVerificationMinutes|verificationMinutes:\s*config\?\.adminPanelWriteVerificationMinutes/);
  }
});
