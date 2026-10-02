const TOKEN_RE = /[\p{L}\p{N}]+/gu;

const MATCH_WEIGHTS = Object.freeze({
  skills: 0.28,
  experience: 0.20,
  category: 0.15,
  location: 0.10,
  workMode: 0.10,
  kind: 0.05,
  compensation: 0.07,
  availability: 0.05,
});

const ACTIVE_APPLICATION_STATUSES = new Set([
  'PENDING',
  'SHORTLISTED',
  'FORWARDED',
  'INTERVIEW',
  'OFFERED',
  'ACCEPTED',
]);

const ACTIVE_OFFER_STATUSES = new Set(['PENDING', 'ACCEPTED']);

const tokens = (value) =>
  new Set(
    String(value || '')
      .toLocaleLowerCase()
      .match(TOKEN_RE)?.filter((item) => item.length >= 2) || [],
  );

function overlap(a, b) {
  if (!a?.size || !b?.size) return 0;
  let hits = 0;
  for (const value of a) if (b.has(value)) hits++;
  return Math.min(1, hits / Math.max(1, Math.min(a.size, 8)));
}

function list(value) {
  return Array.isArray(value) ? value.filter((item) => item != null).map(String) : [];
}

function amount(value) {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : null;
}

function rangeFit(value, min, max) {
  const v = amount(value);
  const lo = amount(min);
  const hi = amount(max);
  if (v == null || lo == null || hi == null || hi < lo) return 0.5;
  if (v >= lo && v <= hi) return 1;
  const distance = v < lo ? lo - v : v - hi;
  return Math.max(0, 1 - distance / Math.max(v, lo, hi, 1));
}

function compensationScore(job, candidate) {
  if (String(job.kind || 'JOB').toUpperCase() === 'MISSION') {
    if (!candidate.offer) return 0.5;
    return rangeFit(candidate.offer.price, job.budgetMin, job.budgetMax);
  }
  const salary = amount(job.monthlySalary);
  if (salary == null) return 0.5;
  return rangeFit(salary, candidate.profile?.salaryMin, candidate.profile?.salaryMax);
}

function jobKeywords(job) {
  return tokens([
    job.title,
    job.description,
    job.acceptanceCriteria,
    job.attributes?.skills,
    job.experience,
  ].join(' '));
}

function candidateSkills(candidate) {
  const values = [
    ...(candidate.profile?.skills || []),
    candidate.application?.skills || '',
    ...(candidate.completedJobs || []).map((job) => job.attributes?.skills || ''),
  ];
  const result = new Set();
  for (const value of values) for (const token of tokens(value)) result.add(token);
  return result;
}

function candidateExperience(candidate) {
  const result = new Set();
  for (const value of [
    candidate.profile?.resumeText || '',
    candidate.profile?.goals || '',
    candidate.application?.resumeText || '',
    ...(candidate.completedJobs || []).map((job) =>
      [job.title, job.description, job.acceptanceCriteria, job.attributes?.skills].join(' '),
    ),
  ]) {
    for (const token of tokens(value)) result.add(token);
  }
  return result;
}

function preferredSet(candidate, field) {
  return new Set(list(candidate.profile?.[field]).map((item) => item.trim()).filter(Boolean));
}

const POSITIVE_APPLICATION_STATUSES = new Set([
  'SHORTLISTED',
  'FORWARDED',
  'INTERVIEW',
  'OFFERED',
  'ACCEPTED',
  'HIRED',
  'COMPLETED',
]);

function historicalMatch(candidate, field, value) {
  if (!value) return false;
  return (candidate.completedJobs || []).some((job) => String(job?.[field] || '') === String(value))
    || (candidate.applicationHistory || []).some((item) =>
      POSITIVE_APPLICATION_STATUSES.has(String(item?.status || '').toUpperCase())
      && String(item?.[field] || '') === String(value)
    );
}

export function scoreEmployerCandidate(job, candidate = {}) {
  const jobTokens = jobKeywords(job);
  const skillsScore = overlap(candidateSkills(candidate), jobTokens);
  const experienceScore = overlap(candidateExperience(candidate), jobTokens);

  const categories = preferredSet(candidate, 'preferredCategories');
  const categoryScore =
    (job.categoryId && categories.has(String(job.categoryId))) || historicalMatch(candidate, 'categoryId', job.categoryId)
      ? 1
      : 0;

  const cities = preferredSet(candidate, 'preferredCities');
  const locationScore =
    !job.city ? 0.5 :
    cities.has(String(job.city)) || historicalMatch(candidate, 'city', job.city)
      ? 1
      : 0;

  const desiredKinds = new Set(
    list(candidate.profile?.desiredKinds).map((item) => item.toUpperCase()),
  );
  const jobKind = String(job.kind || 'JOB').toUpperCase();
  const kindScore =
    desiredKinds.has(jobKind) || historicalMatch(candidate, 'kind', jobKind)
      ? 1
      : 0.5;

  const preferredWorkMode = String(candidate.profile?.workMode || '').toUpperCase();
  const jobWorkMode = String(job.workMode || job.attributes?.workMode || '').toUpperCase();
  const workModeScore =
    !jobWorkMode ? 0.5 : preferredWorkMode === jobWorkMode ? 1 : 0;

  const availabilityText = tokens(candidate.profile?.availability || '');
  const scheduleText = tokens(job.schedule || '');
  const availabilityScore =
    !scheduleText.size || !availabilityText.size ? 0.5 : overlap(availabilityText, scheduleText);

  const compensation = compensationScore(job, candidate);
  const scores = {
    skills: skillsScore,
    experience: experienceScore,
    category: categoryScore,
    location: locationScore,
    workMode: workModeScore,
    kind: kindScore,
    compensation,
    availability: availabilityScore,
  };

  const score = Object.entries(MATCH_WEIGHTS)
    .reduce((total, [key, weight]) => total + scores[key] * weight, 0) * 100;

  const reasons = [];
  if (skillsScore >= 0.5) reasons.push('SKILL_MATCH');
  if (experienceScore >= 0.5) reasons.push('EXPERIENCE_MATCH');
  if (categoryScore >= 1) reasons.push('CATEGORY_MATCH');
  if (locationScore >= 1) reasons.push('LOCATION_MATCH');
  if (workModeScore >= 1) reasons.push('WORK_MODE_MATCH');
  if (kindScore >= 1) reasons.push('KIND_MATCH');
  if (compensation >= 0.85) {
    reasons.push(String(job.kind || 'JOB').toUpperCase() === 'MISSION'
      ? 'BUDGET_FIT'
      : 'SALARY_FIT');
  }
  if (availabilityScore >= 0.85) reasons.push('AVAILABILITY_MATCH');
  if (!reasons.length) reasons.push('GENERAL_MATCH');

  return {
    score: Number(Math.max(0, Math.min(100, score)).toFixed(2)),
    reasons: reasons.slice(0, 5),
    components: Object.fromEntries(
      Object.entries(scores).map(([key, value]) => [key, Number((value * 100).toFixed(1))]),
    ),
  };
}

function statusRank(status) {
  return {
    ACCEPTED: 6,
    OFFERED: 5,
    INTERVIEW: 4,
    FORWARDED: 3,
    SHORTLISTED: 2,
    PENDING: 1,
  }[String(status || '').toUpperCase()] || 0;
}

export function rankEmployerCandidates(job, candidates = []) {
  const eligible = candidates.filter((candidate) => {
    const status = String(candidate.application?.status || candidate.offer?.status || '').toUpperCase();
    const kind = String(job.kind || 'JOB').toUpperCase();
    return kind === 'MISSION'
      ? ACTIVE_OFFER_STATUSES.has(status)
      : ACTIVE_APPLICATION_STATUSES.has(status);
  });

  return eligible
    .map((candidate) => {
      const match = scoreEmployerCandidate(job, candidate);
      return {
        ...candidate,
        score: match.score,
        matchReasons: match.reasons,
        matchComponents: match.components,
      };
    })
    .sort((a, b) =>
      (b.score - a.score)
      || (statusRank(b.application?.status || b.offer?.status) - statusRank(a.application?.status || a.offer?.status))
      || String(a.userId || '').localeCompare(String(b.userId || '')),
    )
    .map((candidate, index) => ({ ...candidate, rank: index + 1 }));
}
