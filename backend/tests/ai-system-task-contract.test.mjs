import test from 'node:test';
import assert from 'node:assert/strict';
import { AUTOMATED_AI_TASKS, assertSystemAiTask } from '../src/application/ai_access_policy.js';

test('all system AI calls must name an allowlisted task', () => {
  for (const task of AUTOMATED_AI_TASKS) assert.equal(assertSystemAiTask({ task }), true);
  assert.throws(() => assertSystemAiTask({ task: 'FREE_FORM_CHAT' }), /AI_TASK_NOT_ALLOWLISTED/);
});