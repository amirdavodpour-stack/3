import test from 'node:test';
import assert from 'node:assert/strict';

import { buildCandidateProfile } from '../src/recommendation.js';

test('recommendation served events do not create behavioral preference signals', () => {
  const profile = buildCandidateProfile([], {
    profile: {
      onboardingCompleted: true,
      skills: ['Flutter'],
    },
    events: [{
      eventName: 'recommendation_served',
      properties: {
        categoryId: 'unrelated',
        city: 'شیراز',
        kind: 'MISSION',
        query: 'unrelated',
      },
    }],
  });

  assert.equal(profile.interactionCount, 0);
  assert.equal(profile.behaviorCategories.has('unrelated'), false);
  assert.equal(profile.behaviorCities.has('شیراز'), false);
  assert.equal(profile.behaviorKinds.has('MISSION'), false);
});

test('real opportunity interaction events continue learning behavior', () => {
  const profile = buildCandidateProfile([], {
    profile: {
      onboardingCompleted: true,
      skills: ['Flutter'],
    },
    events: [{
      eventName: 'opportunity_viewed',
      properties: {
        categoryId: 'software-development',
        city: 'تهران',
        kind: 'JOB',
        query: 'Flutter',
      },
    }],
  });

  assert.equal(profile.interactionCount, 1);
  assert.equal(profile.topBehaviorCategories[0], 'software-development');
  assert.equal(profile.topBehaviorCities[0], 'تهران');
  assert.equal(profile.topBehaviorKinds[0], 'JOB');
  assert.ok(profile.interestTokens.has('flutter'));
});
