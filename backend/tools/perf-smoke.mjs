#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';

const majorNodeVersion = Number(process.versions.node.split('.')[0]);
if (majorNodeVersion < 24) throw new Error(`Node 24+ required for performance certification; found ${process.versions.node}`);

const baseUrl = String(process.env.PERF_BASE_URL || 'http://127.0.0.1:3000').replace(/\/$/, '');
const totalRequests = positiveInt(process.env.PERF_REQUESTS, 500);
const concurrency = positiveInt(process.env.PERF_CONCURRENCY, 50);
const warmupRequests = positiveInt(process.env.PERF_WARMUP_REQUESTS, Math.min(concurrency, totalRequests));
const p95BudgetMs = nonNegativeInt(process.env.PERF_P95_BUDGET_MS, 1000);
const p99BudgetMs = nonNegativeInt(process.env.PERF_P99_BUDGET_MS, 2000);
const max5xxRate = boundedNumber(process.env.PERF_MAX_5XX_RATE, 0.01, 0, 1);
const output = process.env.PERF_OUTPUT || path.resolve(process.cwd(), 'artifacts/perf/perf-smoke.json');
const endpoints = String(process.env.PERF_ENDPOINTS || '/live,/health,/api/v1/jobs').split(',').map((value) => value.trim()).filter(Boolean);
const minSuccessRate = boundedNumber(process.env.PERF_MIN_SUCCESS_RATE, 0.995, 0, 1);
if (!endpoints.length) throw new Error('PERF_ENDPOINTS must contain at least one endpoint');

function positiveInt(value, fallback) {
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : fallback;
}
function nonNegativeInt(value, fallback) {
  const n = Number(value);
  return Number.isInteger(n) && n >= 0 ? n : fallback;
}
function boundedNumber(value, fallback, min, max) {
  const n = Number(value);
  return Number.isFinite(n) && n >= min && n <= max ? n : fallback;
}
function percentile(values, p) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil(sorted.length * p) - 1));
  return sorted[idx];
}

async function requestEndpoint(endpoint) {
  const started = performance.now();
  try {
    const response = await fetch(`${baseUrl}${endpoint}`, {
      headers: { 'Cache-Control': 'no-cache' },
    });
    // Consume the full response body before starting the next request. Undici
    // can then deterministically return the connection to its pool instead of
    // making the measurement depend on unread response streams.
    await response.arrayBuffer();
    return {
      endpoint,
      latencyMs: performance.now() - started,
      status: response.status,
    };
  } catch (error) {
    return {
      endpoint,
      latencyMs: performance.now() - started,
      status: 0,
      error: error?.message || String(error),
    };
  }
}

async function runRequests(requestCount, workerCount) {
  const results = [];
  let next = 0;

  async function worker() {
    while (true) {
      const index = next++;
      if (index >= requestCount) return;
      results.push(await requestEndpoint(endpoints[index % endpoints.length]));
    }
  }

  const started = performance.now();
  await Promise.all(Array.from({ length: Math.min(workerCount, requestCount) }, () => worker()));
  return {
    results,
    elapsedMs: performance.now() - started,
  };
}

async function run() {
  const startedAt = new Date().toISOString();

  // Warm the runner↔staging connections before the measured window. This is
  // a standard load-test warm-up and prevents cold DNS/TLS/socket establishment
  // from dominating the p95/p99 of an otherwise healthy steady-state service.
  const warmup = await runRequests(warmupRequests, Math.min(concurrency, warmupRequests));
  const measurement = await runRequests(totalRequests, concurrency);
  const latencies = measurement.results.map((result) => result.latencyMs);

  let completed = 0;
  let ok = 0;
  let degraded = 0;
  let errors5xx = 0;
  let errors4xx = 0;
  const errors = [];

  for (const result of measurement.results) {
    completed += 1;
    if (result.error) {
      errors5xx += 1;
      if (errors.length < 20) errors.push({ endpoint: result.endpoint, message: result.error });
    } else if (result.status >= 500) {
      errors5xx += 1;
    } else if (result.status >= 400) {
      errors4xx += 1;
    } else if (result.status === 200) {
      ok += 1;
    } else {
      degraded += 1;
    }
  }

  const elapsedMs = measurement.elapsedMs;
  const p50 = percentile(latencies, 0.50);
  const p95 = percentile(latencies, 0.95);
  const p99 = percentile(latencies, 0.99);
  const rps = elapsedMs > 0 ? (completed / elapsedMs) * 1000 : 0;
  const errorRate5xx = completed ? errors5xx / completed : 1;
  const requireAllOk = String(process.env.PERF_REQUIRE_ALL_OK || '0') === '1';
  const successRate = completed ? ok / completed : 0;
  const passed = completed === totalRequests && p95 <= p95BudgetMs && p99 <= p99BudgetMs && errorRate5xx <= max5xxRate && successRate >= minSuccessRate && (!requireAllOk || errors4xx === 0 && degraded === 0 && errors5xx === 0);

  const report = {
    schemaVersion: 2,
    startedAt,
    finishedAt: new Date().toISOString(),
    target: baseUrl,
    workload: { totalRequests, concurrency, warmupRequests, endpoints },
    warmup: {
      completed: warmup.results.length,
      elapsedMs: Number(warmup.elapsedMs.toFixed(2)),
      errors: warmup.results.filter((result) => result.error).length,
    },
    thresholds: { p95BudgetMs, p99BudgetMs, max5xxRate, minSuccessRate, requireAllOk },
    results: {
      completed,
      ok,
      degraded,
      errors4xx,
      errors5xx,
      errorRate5xx: Number(errorRate5xx.toFixed(6)),
      successRate: Number(successRate.toFixed(6)),
      elapsedMs: Number(elapsedMs.toFixed(2)),
      requestsPerSecond: Number(rps.toFixed(2)),
      latencyMs: {
        p50: Number(p50.toFixed(2)),
        p95: Number(p95.toFixed(2)),
        p99: Number(p99.toFixed(2)),
        max: Number(Math.max(...latencies, 0).toFixed(2)),
      },
    },
    passed,
    errors,
  };

  await fs.mkdir(path.dirname(output), { recursive: true });
  await fs.writeFile(output, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  console.log(JSON.stringify(report, null, 2));
  if (!passed) process.exitCode = 1;
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
