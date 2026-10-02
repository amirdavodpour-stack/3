import test from 'node:test';
import assert from 'node:assert/strict';
import { buildDisputeDecisionPrompt, parseDisputeDecision } from '../src/services/dispute_resolution.js';

test('parses a bounded dispute decision and preserves legal citations', () => {
  const result = parseDisputeDecision(JSON.stringify({
    decision: 'RELEASE',
    confidence: 1.4,
    summary: 'Completion is supported by the supplied record.',
    legalBasis: [{ source: 'قانون مدنی', article: '۲۱۹', principle: 'contract is binding' }],
    factualFindings: ['The job is completed.'],
    missingEvidence: ['No independent acceptance artifact.'],
  }));
  assert.equal(result.decision, 'RELEASE');
  assert.equal(result.confidence, 1);
  assert.equal(result.legalBasis[0].article, '۲۱۹');
  assert.equal(result.manualReview, false);
});

test('invalid or unsupported AI decisions fail closed to HOLD and manual review', () => {
  const result = parseDisputeDecision('{"decision":"DELETE_WALLET","confidence":99}');
  assert.equal(result.decision, 'HOLD');
  assert.equal(result.confidence, 0);
  assert.equal(result.manualReview, true);
});

test('decision prompt anchors the assessment in Iranian legal sources and evidence rules', () => {
  const prompt = buildDisputeDecisionPrompt({ job: { title: 'نمونه' }, payment: { amount: 1000, status: 'HELD' }, feedback: [] });
  assert.match(prompt, /۲۱۹/);
  assert.match(prompt, /۲۲۵/);
  assert.match(prompt, /۱۲۵۷/);
  assert.match(prompt, /۱۲/);
  assert.match(prompt, /۴۵۴/);
  assert.match(prompt, /۴۶۶/);
  assert.match(prompt, /evidence|ادله/i);
});