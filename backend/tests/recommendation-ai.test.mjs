import test from 'node:test';
import assert from 'node:assert/strict';

import { rerankWithAI } from '../src/recommendation.js';

const profile = {
  topCategories: ['design'],
  topCities: ['تهران'],
  topKinds: ['JOB'],
  topWorkModes: ['REMOTE'],
  salaryMin: 30000000,
  salaryMax: 50000000,
  interactionCount: 4,
};

const jobs = [
  {
    id: 'job-a',
    title: 'Flutter UI engineer',
    description: 'Build Flutter mobile interfaces',
    category: 'design',
    city: 'تهران',
    kind: 'JOB',
    workMode: 'REMOTE',
    monthlySalary: 45000000,
  },
  {
    id: 'job-b',
    title: 'Backend developer',
    description: 'Node.js API development',
    category: 'engineering',
    city: 'اصفهان',
    kind: 'JOB',
    workMode: 'ONSITE',
    monthlySalary: 40000000,
  },
];
test('rerankWithAI parses model rankings and returns scores by job id', async () => {
  let receivedPrompt = '';
  const result = await rerankWithAI({
    askAI: async (prompt) => {
      receivedPrompt = prompt;
      return JSON.stringify({
        rankings: [
          { id: 'job-b', score: 91, confidence: 0.8, reasons: ['strong backend fit'] },
          { id: 'job-a', score: 72, confidence: 0.7, reasons: ['good skill overlap'] },
        ],
      });
    },
    profile,
    jobs,
  });

  assert.deepEqual(result.map((x) => x.id), ['job-b', 'job-a']);
  assert.equal(result[0].score, 91);
  assert.deepEqual(result[0].reasons, ['strong backend fit']);
  assert.match(receivedPrompt, /job-a/);
  assert.match(receivedPrompt, /topCategories/);
});

test('rerankWithAI ignores unknown jobs and clamps malformed scores', async () => {
  const result = await rerankWithAI({
    askAI: async () => JSON.stringify({
      rankings: [
        { id: 'unknown', score: 999, confidence: 4, reasons: [] },
        { id: 'job-a', score: 120, confidence: -1, reasons: ['x', 123] },
      ],
    }),
    profile,
    jobs,
  });

  assert.deepEqual(result, [
    { id: 'job-a', score: 100, confidence: 0, reasons: ['x'] },
  ]);
});

test('rerankWithAI returns null when the model response is not valid ranking JSON', async () => {
  const result = await rerankWithAI({
    askAI: async () => 'not-json',
    profile,
    jobs,
  });

  assert.equal(result, null);
});

[executed on device: localhost (ad4940fb-3108-4ab5-af41-ee34669dd70c)]