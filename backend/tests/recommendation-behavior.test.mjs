import test from 'node:test';
import assert from 'node:assert/strict';

import { buildCandidateProfile, scoreRecommendation } from '../src/recommendation.js';

test('candidate profile learns from saved searches, viewed opportunities, applications, and completed work', () => {
  const profile = buildCandidateProfile(
    [{
      skills: 'Dart Flutter',
      categoryId: 'software-development',
      jobCity: 'تهران',
      jobKind: 'JOB',
      workMode: 'REMOTE',
      monthlySalary: '40000000',
      status: 'SHORTLISTED',
    }],
    {
      profile: {
        skills: ['Flutter'],
        interests: ['mobile development'],
        preferredCategories: ['software-development'],
        preferredCities: ['تهران'],
        desiredKinds: ['JOB'],
        workMode: 'REMOTE',
        resumeText: 'Flutter developer',
        goals: 'Build mobile apps',
      },
      savedSearches: [{
        query: 'Flutter remote',
        category: 'software-development',
        city: 'تهران',
        kind: 'JOB',
      }],
      events: [{
        eventName: 'opportunity_viewed',
        properties: {
          categoryId: 'software-development',
          city: 'تهران',
          kind: 'JOB',
          query: 'Flutter',
        },
      }],
      completedJobs: [{
        title: 'Flutter mobile app',
        description: 'Dart Flutter application',
        categoryId: 'software-development',
        city: 'تهران',
        kind: 'JOB',
      }],
    }
  );

  assert.equal(profile.topCategories[0], 'software-development');
  assert.equal(profile.topCities[0], 'تهران');
  assert.equal(profile.topKinds[0], 'JOB');
  assert.equal(profile.topWorkModes[0], 'REMOTE');
  assert.ok(profile.experienceTokens.has('flutter'));
  assert.ok(profile.interestTokens.has('flutter'));

  const match = scoreRecommendation({
    id: 'job-1',
    title: 'Flutter remote developer',
    description: 'Build Android mobile apps with Dart and Flutter.',
    categoryId: 'software-development',
    city: 'تهران',
    kind: 'JOB',
    workMode: 'REMOTE',
    monthlySalary: '45000000',
  }, profile, { city: 'تهران' });

  assert.ok(match.score > 50);
  assert.ok(match.reasons.includes('SKILL_MATCH'));
  assert.ok(match.reasons.includes('CATEGORY_MATCH'));
  assert.ok(match.reasons.includes('WORK_MODE_MATCH'));
});
