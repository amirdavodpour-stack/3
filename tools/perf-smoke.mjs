#!/usr/bin/env node
import path from 'node:path';

// The certification workflow executes from backend/ and expects the report at
// backend/perf-smoke.json. Keep the canonical implementation in backend/tools
// while preserving the workflow's existing root-tools invocation path.
if (!process.env.PERF_OUTPUT) {
  process.env.PERF_OUTPUT = path.resolve(process.cwd(), 'perf-smoke.json');
}

await import('../backend/tools/perf-smoke.mjs');
