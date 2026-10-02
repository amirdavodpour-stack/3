const FOLLOW_UP_DAYS = 7;
const REVIEW_SCORE = 70;
const APPLY_SCORE = 75;

function clean(value, max = 240) {
  return String(value ?? '').replace(/\s+/g, ' ').trim().slice(0, max);
}

function list(value) {
  return Array.isArray(value) ? value.filter((item) => typeof item === 'string' && item.trim()).slice(0, 40) : [];
}

function dateMs(value) {
  const parsed = Date.parse(String(value || ''));
  return Number.isFinite(parsed) ? parsed : null;
}

function hasValue(value) {
  if (Array.isArray(value)) return value.length > 0;
  return value != null && String(value).trim() !== '';
}

export function profileCompleteness(profile = {}) {
  const checks = [
    ['resumeText', hasValue(profile.resumeText)],
    ['skills', hasValue(profile.skills)],
    ['interests', hasValue(profile.interests)],
    ['preferredCategories', hasValue(profile.preferredCategories)],
    ['preferredCities', hasValue(profile.preferredCities)],
    ['desiredKinds', hasValue(profile.desiredKinds)],
    ['workMode', hasValue(profile.workMode)],
    ['goals', hasValue(profile.goals)],
  ];
  const missing = checks.filter(([, present]) => !present).map(([name]) => name);
  return {
    score: Number(((checks.length - missing.length) / checks.length).toFixed(2)),
    missing,
    onboardingCompleted: profile.onboardingCompleted === true,
  };
}

export function buildOpportunityAgentState({
  now = new Date().toISOString(),
  profile = {},
  applications = [],
  events = [],
  savedSearches = [],
  completedJobs = [],
  recommendations = [],
} = {}) {
  const nowMs = dateMs(now) ?? Date.now();
  const completeness = profileCompleteness(profile);
  const viewedIds = new Set(
    events
      .filter((event) => event?.eventName === 'opportunity_viewed')
      .map((event) => event?.properties?.jobId)
      .filter(Boolean)
      .map(String),
  );
  const applicationByJobId = new Map(
    applications
      .filter((item) => item?.jobId)
      .map((item) => [String(item.jobId), item]),
  );

  const actions = [];

  if (!profile.onboardingCompleted) {
    actions.push({
      type: 'COMPLETE_PROFILE',
      priority: 100,
      title: 'Complete your work profile',
      reason: completeness.missing.length
        ? `Missing: ${completeness.missing.join(', ')}`
        : 'The work profile has not been completed.',
      requiresApproval: false,
      missingFields: completeness.missing.slice(0, 6),
    });
  }

  for (const job of recommendations.slice(0, 20)) {
    const jobId = clean(job?.id, 80);
    if (!jobId) continue;
    const score = Number(job?.recommendationScore);
    if (!Number.isFinite(score)) continue;
    const application = applicationByJobId.get(jobId);
    const applicationStatus = String(application?.status || '').toUpperCase();

    if (!application && score >= REVIEW_SCORE && !viewedIds.has(jobId)) {
      actions.push({
        type: 'REVIEW_OPPORTUNITY',
        priority: 80,
        title: clean(job.title, 160) || 'Review opportunity',
        jobId,
        score: Number(score.toFixed(2)),
        reasons: list(job.recommendationReasons).slice(0, 3),
        requiresApproval: false,
      });
    }

    if (!application && String(job.kind || '').toUpperCase() === 'JOB' && score >= APPLY_SCORE) {
      actions.push({
        type: 'PREPARE_APPLICATION',
        priority: 70,
        title: clean(job.title, 160) || 'Prepare application',
        jobId,
        score: Number(score.toFixed(2)),
        reasons: list([
          ...list(job.aiRecommendationReasons),
          ...list(job.recommendationReasons),
        ]).slice(0, 3),
        requiresApproval: true,
      });
    }

    if (application && ['WITHDRAWN', 'REJECTED'].includes(applicationStatus)) {
      // The current marketplace keeps an application record for these states.
      // Do not propose another application without an explicit product rule
      // that supports re-application.
      continue;
    }
  }

  for (const application of applications.slice(0, 50)) {
    const status = String(application?.status || '').toUpperCase();
    const updatedMs = dateMs(application?.updatedAt || application?.createdAt);
    const ageDays = updatedMs == null ? 0 : Math.floor((nowMs - updatedMs) / 86400000);
    if (status === 'PENDING' && ageDays >= FOLLOW_UP_DAYS) {
      actions.push({
        type: 'FOLLOW_UP_APPLICATION',
        priority: 60,
        title: clean(application.jobTitle, 160) || 'Follow up on your application',
        applicationId: clean(application.id, 80),
        jobId: clean(application.jobId, 80),
        ageDays,
        requiresApproval: false,
      });
    }
  }

  const seen = new Set();
  const sortedActions = actions
    .sort((a, b) => (b.priority - a.priority) || String(a.jobId || a.applicationId || a.type).localeCompare(String(b.jobId || b.applicationId || b.type)))
    .filter((action) => {
      const key = `${action.type}:${action.jobId || action.applicationId || 'profile'}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .slice(0, 12);

  return {
    version: '1.0',
    profileCompleteness: completeness,
    activity: {
      savedSearches: savedSearches.length,
      views: events.filter((event) => event?.eventName === 'opportunity_viewed').length,
      applications: applications.length,
      completedJobs: completedJobs.length,
    },
    automationPolicy: {
      automatic: ['DISCOVER', 'RANK', 'EXPLAIN', 'LEARN'],
      approvalRequired: ['PREPARE_APPLICATION', 'APPLY', 'ACCEPT', 'NEGOTIATE', 'FINANCIAL_ACTION'],
    },
    actions: sortedActions,
  };
}


export function parseOpportunityAgentState(input = {}) {
  const source = input && typeof input === 'object' ? input : {};
  const rawProfile = source.profileCompleteness && typeof source.profileCompleteness === 'object'
    ? source.profileCompleteness : {};
  const rawActivity = source.activity && typeof source.activity === 'object'
    ? source.activity : {};
  const rawPolicy = source.automationPolicy && typeof source.automationPolicy === 'object'
    ? source.automationPolicy : {};
  const rawActions = Array.isArray(source.actions) ? source.actions : [];
  const stringList = (value, limit = 12) => Array.isArray(value)
    ? value.filter((item) => typeof item === 'string' && item.trim()).map((item) => item.trim()).slice(0, limit)
    : [];
  const actions = rawActions
    .filter((item) => item && typeof item === 'object')
    .map((item) => ({
      ...item,
      type: clean(item.type, 60),
      title: clean(item.title, 240),
      reason: item.reason == null ? null : clean(item.reason, 500),
      jobId: item.jobId == null ? null : clean(item.jobId, 100),
      applicationId: item.applicationId == null ? null : clean(item.applicationId, 100),
      reasons: stringList(item.reasons, 3),
      missingFields: stringList(item.missingFields, 6),
      requiresApproval: item.requiresApproval === true,
    }))
    .filter((item) => item.type && item.title)
    .slice(0, 12);
  return {
    version: clean(source.version || '1.0', 20) || '1.0',
    profileCompleteness: {
      score: clamp01(rawProfile.score),
      missing: stringList(rawProfile.missing, 12),
      onboardingCompleted: rawProfile.onboardingCompleted === true,
    },
    activity: {
      savedSearches: Number(rawActivity.savedSearches) || 0,
      views: Number(rawActivity.views) || 0,
      applications: Number(rawActivity.applications) || 0,
      completedJobs: Number(rawActivity.completedJobs) || 0,
    },
    automationPolicy: {
      automatic: stringList(rawPolicy.automatic, 12),
      approvalRequired: stringList(rawPolicy.approvalRequired, 12),
    },
    actions,
  };
}
