import test from 'node:test';
import assert from 'node:assert/strict';

import {
  SATISFACTION_QUESTIONS,
  parseSatisfactionAnalysis,
  evaluateSettlementGate,
} from '../src/services/job_satisfaction.js';

test('satisfaction flow is fixed-scope and does not expose a general AI chat surface', () => {
  assert.equal(SATISFACTION_QUESTIONS.length, 4);
  assert.ok(SATISFACTION_QUESTIONS.every((question) => question.id && question.prompt && question.type));
  assert.equal(SATISFACTION_QUESTIONS.some((question) => question.id === 'free_chat'), false);
});

test('AI satisfaction analysis is normalized to safe fields', () => {
  const result = parseSatisfactionAnalysis(JSON.stringify({
    summary: 'همکاری مطابق توافق انجام شد.',
    satisfactionScore: 120,
    sentiment: 'SATISFIED',
    tags: ['QUALITY', 'COMMUNICATION', 'QUALITY'],
    riskFlags: ['none', 'hidden'],
  }));
  assert.equal(result.satisfactionScore, 100);
  assert.equal(result.sentiment, 'SATISFIED');
  assert.deepEqual(result.tags, ['QUALITY', 'COMMUNICATION']);
  assert.deepEqual(result.riskFlags, ['none']);
});

test('settlement gate requires completed job, release-pending payment and satisfied reports from both sides', () => {
  const ready = evaluateSettlementGate({
    jobStatus: 'COMPLETED',
    paymentStatus: 'RELEASE_PENDING',
    feedback: [
      { userId:'worker-1', role:'WORKER', satisfied:true, overallRating:5, completedAsAgreed:true, status:'ANALYZED' },
      { userId:'owner-1', role:'EMPLOYER', satisfied:true, overallRating:4, completedAsAgreed:true, status:'ANALYZED' },
    ],
  });
  assert.equal(ready.ready, true);

  const blocked = evaluateSettlementGate({
    jobStatus: 'COMPLETED',
    paymentStatus: 'RELEASE_PENDING',
    feedback: [
      { userId:'worker-1', role:'WORKER', satisfied:true, overallRating:5, completedAsAgreed:true, status:'ANALYZED' },
      { userId:'owner-1', role:'EMPLOYER', satisfied:false, overallRating:2, completedAsAgreed:false, status:'ANALYZED' },
    ],
  });
  assert.equal(blocked.ready, false);
  assert.ok(blocked.reason);
});
