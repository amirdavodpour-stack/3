import { spawn } from 'node:child_process';
import fs from 'node:fs';

const steps = [
  ['npm run check', 120000],
  ['node tools/run-test-script-isolated.mjs --script test:fast', 480000],
  ['node tools/run-test-script-isolated.mjs --script test:contract', 480000],
  ['npm run test:backup', 180000],
  ['npm run test:staging-contract', 180000],
  ['npm run test:e2e', 240000],
  ['npm run test:provider', 240000],
  ['npm run test:failure-injection', 240000],
  ['npm run test:postgres', 300000],
  ['node tools/run-test-script-isolated.mjs --files tests/sbom-contract.test.mjs tests/property-workflow.test.mjs tests/property-security.test.mjs tests/e2e-state-guard.test.mjs tests/wave10-release-security.test.mjs', 480000],
  ['npm run check:toolchain-contract', 120000],
];

const summaries = [];

function run(command, timeoutMs) {
  return new Promise((resolve) => {
    const child = spawn('bash', ['-lc', command], {
      cwd: process.cwd(),
      env: process.env,
      stdio: 'inherit',
      detached: true,
    });
    let timedOut = false;
    const killGroup = (signal) => {
      if (!child.pid) return;
      try {
        process.kill(-child.pid, signal);
      } catch (error) {
        if (error?.code !== 'ESRCH') throw error;
      }
    };
    const timer = setTimeout(() => {
      timedOut = true;
      console.error(`\\n[check:all] TIMEOUT: ${command} after ${timeoutMs}ms; terminating process group`);
      killGroup('SIGTERM');
      setTimeout(() => killGroup('SIGKILL'), 30000).unref();
    }, timeoutMs);
    child.on('close', (code, signal) => {
      clearTimeout(timer);
      resolve({ command, timeoutMs, code: timedOut ? 124 : (code ?? 1), signal: signal || null, status: timedOut ? 'timeout' : (code === 0 ? 'pass' : 'fail') });
    });
    child.on('error', (error) => {
      clearTimeout(timer);
      resolve({ command, timeoutMs, code: 1, signal: null, status: 'error', error: error.message });
    });
  });
}

console.log('[check:all] Collect-all mode: every suite runs; failures are aggregated.');
for (const [command, timeoutMs] of steps) {
  const result = await run(command, timeoutMs);
  summaries.push(result);
  console.log(`[check:all] ${result.status.toUpperCase()}: ${command}`);
}

const failed = summaries.filter((item) => item.status !== 'pass');
const summary = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  mode: 'collect-all',
  total: summaries.length,
  passed: summaries.length - failed.length,
  failed: failed.length,
  results: summaries,
};
fs.writeFileSync('check-all-summary.json', JSON.stringify(summary, null, 2) + '\\n', { mode: 0o644 });

if (failed.length) {
  console.error('\\n[check:all] BLOCKED — failed suites:');
  for (const item of failed) console.error(`- ${item.status}: ${item.command} (exit ${item.code})`);
  process.exit(1);
}
console.log('\\n[check:all] PASS — all suites completed successfully.');
