import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

test('AI chat route is authenticated, validates input, and supports the configured model service', async () => {
  const [app, route, service] = await Promise.all([
    readFile(new URL('../src/app.js', import.meta.url), 'utf8'),
    readFile(new URL('../src/routes/ai_routes.js', import.meta.url), 'utf8'),
    readFile(new URL('../src/services/ai.js', import.meta.url), 'utf8'),
  ]);

  assert.match(app, /replace\(\/\^\\\/api\(\?:\\\/v1\)\?\\\/?\//);
  assert.match(app, /parts\[0\] === 'chat'/);
  assert.match(route, /await authUser\(req\)/);
  assert.match(route, /MESSAGE_REQUIRED/);
  assert.match(route, /MESSAGE_TOO_LARGE/);
  assert.match(service, /AI_ROUTER_API_KEY/);
  assert.match(service, /AI_MODEL/);
  assert.match(service, /apmix\/deepseek-v4-flash-free/);
  assert.doesNotMatch(service, /sk-[A-Za-z0-9-]{20,}/);
});
