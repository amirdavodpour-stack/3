import test from 'node:test';
import assert from 'node:assert/strict';

import { buildOpportunityAgentState } from '../src/services/opportunity_agent.js';

test('agent prioritizes profile completion before opportunity actions', () => {
  const state = buildOpportunityAgentState({
    now: '2026-10-02T12:00:00.000Z',
    profile: {
      onboardingCompleted: false,
      skills: [],
      preferredCategories: [],
      preferredCities: [],
      desiredKinds: [],
      workMode: null,
      goals: '',
    },
    applications: [],
    events: [],
    savedSearches: [],
    completedJobs: [],
    recommendations: [{
      id: 'job-1',
      title: 'Flutter developer',
      kind: 'JOB',
      recommendationScore: 92,
      recommendationReasons: ['SKILL_MATCH'],
    }],
  });

  assert.equal(state.actions[0].type, 'COMPLETE_PROFILE');
  assert.equal(state.actions[0].requiresApproval, false);
  assert.ok(state.profileCompleteness.missing.length >= 1);
});

test('agent proposes review and application preparation for a strong unseen job', () => {
  const state = buildOpportunityAgentState({
    now: '2026-10-02T12:00:00.000Z',
    profile: {
      onboardingCompleted: true,
      resumeText: 'Flutter developer',
      skills: ['Flutter'],
      interests: ['mobile'],
      preferredCategories: ['software-development'],
      preferredCities: ['تهران'],
      desiredKinds: ['JOB'],
      workMode: 'REMOTE',
      goals: 'Build mobile apps',
    },
    applications: [],
    events: [],
    savedSearches: [],
    completedJobs: [],
    recommendations: [{
      id: 'job-1',
      title: 'Flutter remote developer',
      kind: 'JOB',
      recommendationScore: 91,
      recommendationReasons: ['SKILL_MATCH', 'WORK_MODE_MATCH'],
    }],
  });

  assert.deepEqual(state.actions.map((item) => item.type), [
    'REVIEW_OPPORTUNITY',
    'PREPARE_APPLICATION',
  ]);
  assert.equal(state.actions[1].requiresApproval, true);
  assert.equal(state.actions[1].jobId, 'job-1');
});

test('agent suggests follow-up only for a pending application older than the threshold', () => {
  const state = buildOpportunityAgentState({
    now: '2026-10-10T12:00:00.000Z',
    profile: { onboardingCompleted: true, resumeText: 'Developer', skills: ['Dart'] },
    applications: [{
      id: 'application-1',
      jobId: 'job-2',
      jobTitle: 'Dart developer',
      status: 'PENDING',
      updatedAt: '2026-10-01T12:00:00.000Z',
    }],
    events: [],
    savedSearches: [],
    completedJobs: [],
    recommendations: [],
  });

  assert.equal(state.actions.length, 1);
  assert.equal(state.actions[0].type, 'FOLLOW_UP_APPLICATION');
  assert.equal(state.actions[0].applicationId, 'application-1');
  assert.equal(state.actions[0].requiresApproval, false);
});

test('agent does not recommend applying to an already submitted or withdrawn opportunity', () => {
  const state = buildOpportunityAgentState({
    now: '2026-10-02T12:00:00.000Z',
    profile: { onboardingCompleted: true, resumeText: 'Developer', skills: ['Dart'] },
    applications: [{
      id: 'application-2',
      jobId: 'job-3',
      status: 'WITHDRAWN',
      updatedAt: '2026-10-02T10:00:00.000Z',
    }],
    events: [{
      eventName: 'opportunity_viewed',
      properties: { jobId: 'job-3' },
    }],
    savedSearches: [],
    completedJobs: [],
    recommendations: [{
      id: 'job-3',
      title: 'Dart developer',
      kind: 'JOB',
      recommendationScore: 95,
      recommendationReasons: ['SKILL_MATCH'],
    }],
  });

  assert.deepEqual(state.actions.map((item) => item.type), []);
});
