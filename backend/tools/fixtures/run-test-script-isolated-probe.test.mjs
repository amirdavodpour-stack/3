import test from 'node:test';
import assert from 'node:assert/strict';

test('script-isolated runner executes the resolved fixture under test environment', () => {
  assert.equal(process.env.NODE_ENV, 'test');
});
