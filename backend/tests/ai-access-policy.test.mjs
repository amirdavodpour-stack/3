import test from 'node:test';
import assert from 'node:assert/strict';

import { assertAutomatedAiAccess, AUTOMATED_AI_TASKS } from '../src/application/ai_access_policy.js';

test('AI user access is disabled while system-managed automation remains allowlisted', () => {
  assert.deepEqual(
    AUTOMATED_AI_TASKS,
    ['REGISTRATION_PROFILE', 'RECOMMENDATIONS', 'OPPORTUNITY_AGENT', 'JOB_SATISFACTION'],
  );
  assert.throws(
    () => assertAutomatedAiAccess({ route:'chat', source:'USER' }),
    (error) => error.code === 'AI_USER_ACCESS_DISABLED' && error.status === 403,
  );
  assert.doesNotThrow(
    () => assertAutomatedAiAccess({ route:'job-satisfaction', source:'SYSTEM' }),
  );
});
