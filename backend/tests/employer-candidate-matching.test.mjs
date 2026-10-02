import test from 'node:test';
import assert from 'node:assert/strict';

import {
  rankEmployerCandidates,
  scoreEmployerCandidate,
} from '../src/services/employer_candidate_matching.js';

const job = {
  id: 'job-1',
  title: 'Flutter developer',
  description: 'Build Android mobile applications with Dart.',
  categoryId: 'software-development',
  city: 'تهران',
  kind: 'JOB',
  workMode: 'REMOTE',
  monthlySalary: '50000000',
  budgetMin: '40000000',
  budgetMax: '60000000',
  acceptanceCriteria: 'Flutter production experience',
};

test('scores a candidate from profile, application snapshot, and completed work', () => {
  const result = scoreEmployerCandidate(
    job,
    {
      userId: 'worker-1',
      displayName: 'Worker 1',
      profile: {
        resumeText: 'Senior Flutter developer',
        skills: ['Flutter', 'Dart'],
        interests: ['mobile'],
        preferredCategories: ['software-development'],
        preferredCities: ['تهران'],
        desiredKinds: ['JOB'],
        workMode: 'REMOTE',
        salaryMin: '45000000',
        salaryMax: '55000000',
      },
      application: {
        id: 'app-1',
        skills: 'Flutter Dart Android',
        resumeText: 'Five years mobile development',
        status: 'PENDING',
      },
      completedJobs: [{
        title: 'Flutter marketplace app',
        description: 'Dart Android Flutter',
        categoryId: 'software-development',
        city: 'تهران',
        kind: 'JOB',
      }],
    },
  );

  assert.ok(result.score >= 85);
  assert.ok(result.reasons.includes('SKILL_MATCH'));
  assert.ok(result.reasons.includes('EXPERIENCE_MATCH'));
  assert.ok(result.reasons.includes('CATEGORY_MATCH'));
  assert.ok(result.reasons.includes('WORK_MODE_MATCH'));
  assert.ok(result.reasons.includes('SALARY_FIT'));
});

test('mission matching evaluates the provider offer against the mission budget', () => {
  const result = scoreEmployerCandidate(
    {
      ...job,
      kind: 'MISSION',
      monthlySalary: null,
      budgetMin: '3000000',
      budgetMax: '5000000',
    },
    {
      userId: 'worker-2',
      profile: {
        skills: ['Flutter'],
        preferredCategories: ['software-development'],
        preferredCities: ['تهران'],
        desiredKinds: ['MISSION'],
      },
      offer: {
        id: 'offer-1',
        price: '4000000',
        message: 'Can deliver the requested Flutter work',
        status: 'PENDING',
      },
      completedJobs: [],
    },
  );

  assert.ok(result.score >= 70);
  assert.ok(result.reasons.includes('BUDGET_FIT'));
});

test('ranking sorts by compatibility and exposes a stable rank', () => {
  const candidates = rankEmployerCandidates(job, [
    {
      userId: 'worker-low',
      profile: { skills: ['Photoshop'] },
      application: { skills: 'Design', resumeText: '', status: 'PENDING' },
      completedJobs: [],
    },
    {
      userId: 'worker-high',
      profile: {
        skills: ['Flutter', 'Dart'],
        preferredCategories: ['software-development'],
        preferredCities: ['تهران'],
        desiredKinds: ['JOB'],
        workMode: 'REMOTE',
        salaryMin: '45000000',
        salaryMax: '55000000',
      },
      application: { skills: 'Flutter Dart', resumeText: 'Flutter developer', status: 'PENDING' },
      completedJobs: [],
    },
  ]);

  assert.equal(candidates[0].userId, 'worker-high');
  assert.equal(candidates[0].rank, 1);
  assert.equal(candidates[1].rank, 2);
  assert.ok(candidates[0].score >= candidates[1].score);
});

test('withdrawn and rejected applicants are excluded from the ranked acceptor list', () => {
  const candidates = rankEmployerCandidates(job, [
    {
      userId: 'pending',
      profile: { skills: ['Flutter'] },
      application: { status: 'PENDING', skills: 'Flutter' },
      completedJobs: [],
    },
    {
      userId: 'withdrawn',
      profile: { skills: ['Flutter', 'Dart'] },
      application: { status: 'WITHDRAWN', skills: 'Flutter Dart' },
      completedJobs: [],
    },
    {
      userId: 'rejected',
      profile: { skills: ['Flutter', 'Dart'] },
      application: { status: 'REJECTED', skills: 'Flutter Dart' },
      completedJobs: [],
    },
  ]);

  assert.deepEqual(candidates.map((candidate) => candidate.userId), ['pending']);
});
