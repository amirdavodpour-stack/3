import test from 'node:test';
import assert from 'node:assert/strict';

import {
  normalizeRecommendationProfile,
  buildRecommendationInterviewPrompt,
  parseInterviewResponse,
  enrichRecommendationProfile,
} from '../src/services/recommendation_profile.js';

test('normalizeRecommendationProfile canonicalizes job preferences and money', () => {
  const profile = normalizeRecommendationProfile({
    resumeText: 'Flutter developer',
    skills: ['Dart', 'Dart'],
    desiredKinds: ['job', 'MISSION', 'other'],
    workMode: 'remote',
    salaryMin: '50000000',
    salaryMax: '30000000',
  });
  assert.deepEqual(profile.skills, ['Dart']);
  assert.deepEqual(profile.desiredKinds, ['JOB', 'MISSION']);
  assert.equal(profile.workMode, 'REMOTE');
  assert.equal(profile.salaryMin, '30000000');
  assert.equal(profile.salaryMax, '50000000');
});

test('interview prompt asks one focused question and forbids sensitive inference', () => {
  const prompt = buildRecommendationInterviewPrompt(
    [{ role: 'assistant', content: 'چه نوع کاری را ترجیح می‌دهید؟' }],
    'دورکاری و توسعه موبایل'
  );
  assert.match(prompt, /one question at a time/i);
  assert.match(prompt, /sensitive/i);
  assert.match(prompt, /profilePatch/i);
});

test('parseInterviewResponse clamps the model output to the supported profile shape', () => {
  const result = parseInterviewResponse(JSON.stringify({
    reply: 'در مورد مهارت‌هایتان بگویید.',
    complete: false,
    profilePatch: {
      skills: ['Flutter', 'Dart'],
      desiredKinds: ['JOB', 'INVALID'],
      workMode: 'REMOTE',
      salaryMin: '30000000',
      salaryMax: '50000000',
    },
  }));
  assert.equal(result.complete, false);
  assert.deepEqual(result.profilePatch.skills, ['Flutter', 'Dart']);
  assert.deepEqual(result.profilePatch.desiredKinds, ['JOB']);
  assert.equal(result.profilePatch.workMode, 'REMOTE');
});

test('enrichRecommendationProfile safely merges explicit AI-extracted facts', async () => {
  const result = await enrichRecommendationProfile({
    profile: {
      interests: ['mobile'],
      skills: [],
      preferredCategories: [],
      preferredCities: [],
      desiredKinds: ['JOB'],
      resumeText: 'Flutter developer',
      goals: '',
    },
    transcript: 'User: I prefer remote work and building Android apps.',
    askAI: async (prompt) => {
      assert.match(prompt, /INTERVIEW_TRANSCRIPT/);
      return JSON.stringify({
        interests: ['Android'],
        skills: ['Flutter'],
        workMode: 'REMOTE',
        goals: 'Build Android apps',
      });
    },
  });
  assert.deepEqual(result.skills, ['Flutter']);
  assert.deepEqual(result.interests, ['mobile', 'Android']);
  assert.equal(result.workMode, 'REMOTE');
  assert.equal(result.goals, 'Build Android apps');
});
