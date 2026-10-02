import test from 'node:test';
import assert from 'node:assert/strict';

import { handleCandidateRoutes } from '../src/routes/job_handlers.js';

function ctxFor({ me = { id: 'owner-1' }, candidates = [] } = {}) {
  return {
    authUser: async () => me,
    repo: {
      listCandidatesForEmployerMatching: async () => candidates,
    },
    readBody: async () => ({}),
    sendJson: async (_res, status, body) => ({ status, body }),
    HttpError: class extends Error {
      constructor(status, code, message) {
        super(message);
        this.status = status;
        this.code = code;
      }
    },
    rankEmployerCandidates: (job, items) => items.map((item, index) => ({
      ...item,
      rank: index + 1,
      score: 90 - index,
      matchReasons: ['SKILL_MATCH'],
      matchComponents: { skills: 100 },
    })),
    id: () => 'unused',
    db: {},
    legacyJobs: {},
    createAudit: async () => {},
    now: () => '2026-10-02T00:00:00.000Z',
    findUser: () => null,
    publicUser: (user) => user,
    notifyApplicationCandidate: async () => {},
    NOTIFICATION_TYPES: {},
  };
}

test('employer candidate matching rejects non-owners', async () => {
  const ctx = ctxFor({ me: { id: 'other' } });
  const job = { id: 'job-1', ownerId: 'owner-1', kind: 'JOB' };

  await assert.rejects(
    () => handleCandidateRoutes(ctx, {}, {}, ['jobs', 'job-1', 'candidate-matches'], job),
    (error) => error.status === 403 && error.code === 'FORBIDDEN',
  );
});

test('employer candidate matching returns ranked job applicants', async () => {
  const ctx = ctxFor({
    candidates: [{
      userId: 'worker-1',
      displayName: 'Worker 1',
      application: { id: 'app-1', status: 'PENDING', skills: 'Flutter' },
      profile: { skills: ['Flutter'] },
      completedJobs: [],
      applicationHistory: [],
    }],
  });
  const job = { id: 'job-1', ownerId: 'owner-1', kind: 'JOB' };

  const result = await handleCandidateRoutes(
    ctx,
    { method: 'GET' },
    {},
    ['jobs', 'job-1', 'candidate-matches'],
    job,
  );

  assert.equal(result.status, 200);
  assert.equal(result.body.jobId, 'job-1');
  assert.equal(result.body.kind, 'JOB');
  assert.equal(result.body.candidates[0].rank, 1);
  assert.equal(result.body.candidates[0].userId, 'worker-1');
});

test('employer candidate matching supports mission offerers', async () => {
  const ctx = ctxFor({
    candidates: [{
      userId: 'worker-2',
      displayName: 'Worker 2',
      offer: { id: 'offer-1', status: 'PENDING', price: '4000000' },
      profile: { skills: ['Flutter'], desiredKinds: ['MISSION'] },
      completedJobs: [],
      applicationHistory: [],
    }],
  });
  const job = {
    id: 'mission-1',
    ownerId: 'owner-1',
    kind: 'MISSION',
    budgetMin: '3000000',
    budgetMax: '5000000',
  };

  const result = await handleCandidateRoutes(
    ctx,
    { method: 'GET' },
    {},
    ['jobs', 'mission-1', 'candidate-matches'],
    job,
  );

  assert.equal(result.status, 200);
  assert.equal(result.body.kind, 'MISSION');
  assert.equal(result.body.candidates[0].offer.id, 'offer-1');
  assert.equal(result.body.candidates[0].requiresApproval, undefined);
});
