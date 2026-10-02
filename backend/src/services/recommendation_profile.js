const KINDS = new Set(['MISSION', 'JOB']);
const WORK_MODES = new Set(['REMOTE', 'HYBRID', 'ONSITE', 'FLEXIBLE']);
export const RECOMMENDATION_PROFILE_VERSION = '1.0';

function cleanText(value, max) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

function listValue(value, max = 30) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value
    .filter((item) => typeof item === 'string')
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => item.slice(0, 120)))]
    .slice(0, max);
}

function money(value) {
  if (value == null || value === '') return null;
  const raw = String(value).trim().replace(/,/g, '');
  return /^\d{1,18}(?:\.\d{1,2})?$/.test(raw) ? raw : null;
}

export function normalizeRecommendationProfile(input = {}) {
  const desiredKinds = listValue(input.desiredKinds)
    .map((value) => value.toUpperCase())
    .filter((value) => KINDS.has(value));
  const workMode = cleanText(input.workMode, 24).toUpperCase();
  let salaryMin = money(input.salaryMin);
  let salaryMax = money(input.salaryMax);

  if (salaryMin && salaryMax) {
    const min = BigInt(salaryMin.split('.')[0]);
    const max = BigInt(salaryMax.split('.')[0]);
    if (min > max) [salaryMin, salaryMax] = [salaryMax, salaryMin];
  }

  return {
    resumeText: cleanText(input.resumeText, 20000),
    skills: listValue(input.skills),
    interests: listValue(input.interests),
    preferredCategories: listValue(input.preferredCategories),
    preferredCities: listValue(input.preferredCities),
    desiredKinds: [...new Set(desiredKinds)],
    workMode: WORK_MODES.has(workMode) ? workMode : null,
    availability: cleanText(input.availability, 120) || null,
    salaryMin,
    salaryMax,
    experienceLevel: cleanText(input.experienceLevel, 80) || null,
    goals: cleanText(input.goals, 2000),
    onboardingCompleted: input.onboardingCompleted === true,
    sourceVersion: RECOMMENDATION_PROFILE_VERSION,
  };
}

function parseJson(raw) {
  if (typeof raw !== 'string') return null;
  const value = raw.trim();
  const start = value.indexOf('{');
  const end = value.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try { return JSON.parse(value.slice(start, end + 1)); } catch { return null; }
}

function profilePatchFromModel(payload) {
  return normalizeRecommendationProfile({
    resumeText: payload.resumeText,
    skills: payload.skills,
    interests: payload.interests,
    preferredCategories: payload.preferredCategories,
    preferredCities: payload.preferredCities,
    desiredKinds: payload.desiredKinds,
    workMode: payload.workMode,
    availability: payload.availability,
    salaryMin: payload.salaryMin,
    salaryMax: payload.salaryMax,
    experienceLevel: payload.experienceLevel,
    goals: payload.goals,
    onboardingCompleted: false,
  });
}

export function buildProfileExtractionPrompt({ profile, transcript = '' }) {
  return [
    'You are HOPE profile extraction assistant.',
    'Extract only job-relevant facts explicitly stated by the user from the supplied profile and interview transcript.',
    'Never infer protected or sensitive attributes. Never invent qualifications, experience, salary, location, or preferences.',
    'Return ONLY JSON with keys: resumeText, skills, interests, preferredCategories, preferredCities, desiredKinds, workMode, availability, salaryMin, salaryMax, experienceLevel, goals.',
    'desiredKinds may contain only MISSION or JOB. workMode may contain only REMOTE, HYBRID, ONSITE, or FLEXIBLE.',
    'PROFILE: ' + JSON.stringify(profile),
    'INTERVIEW_TRANSCRIPT: ' + transcript.slice(0, 12000),
  ].join('\n');
}

export async function enrichRecommendationProfile({ profile, transcript = '', askAI }) {
  const base = normalizeRecommendationProfile(profile);
  if (typeof askAI !== 'function') return base;

  try {
    const raw = await askAI(buildProfileExtractionPrompt({ profile: base, transcript }));
    const extracted = parseJson(raw);
    if (!extracted) return base;
    const next = normalizeRecommendationProfile(extracted);
    return {
      ...base,
      resumeText: next.resumeText || base.resumeText,
      skills: listValue([...base.skills, ...next.skills]),
      interests: listValue([...base.interests, ...next.interests]),
      preferredCategories: listValue([...base.preferredCategories, ...next.preferredCategories]),
      preferredCities: listValue([...base.preferredCities, ...next.preferredCities]),
      desiredKinds: listValue([...base.desiredKinds, ...next.desiredKinds]).filter((x) => KINDS.has(x)),
      workMode: base.workMode || next.workMode,
      availability: base.availability || next.availability,
      salaryMin: base.salaryMin || next.salaryMin,
      salaryMax: base.salaryMax || next.salaryMax,
      experienceLevel: base.experienceLevel || next.experienceLevel,
      goals: base.goals || next.goals,
      onboardingCompleted: base.onboardingCompleted,
      sourceVersion: RECOMMENDATION_PROFILE_VERSION,
    };
  } catch {
    return base;
  }
}

export function buildRecommendationInterviewPrompt(history = [], message = '') {
  const safeHistory = Array.isArray(history)
    ? history.slice(-16).filter((item) => item && typeof item.role === 'string' && typeof item.content === 'string')
        .map((item) => ({ role: item.role === 'assistant' ? 'assistant' : 'user', content: item.content.slice(0, 3000) }))
    : [];

  return [
    'You are HOPE onboarding interviewer for professional opportunity matching.',
    'Your job is to learn only job-relevant preferences and experience, one question at a time.',
    'You need to cover: professional background/resume, skills, interests, preferred categories, cities, mission vs job preference, work mode, availability, salary range, experience level, and career goals.',
    'Ask one focused question at a time. Use earlier answers to avoid repeating questions.',
    'Do not ask for or infer protected/sensitive information.',
    'When enough information is collected, set complete=true.',
    'Return ONLY JSON: {"reply":"...","complete":false,"profilePatch":{"skills":[],"interests":[],"preferredCategories":[],"preferredCities":[],"desiredKinds":[],"workMode":null,"availability":null,"salaryMin":null,"salaryMax":null,"experienceLevel":null,"goals":""}}',
    'HISTORY: ' + JSON.stringify(safeHistory),
    'LATEST_USER_MESSAGE: ' + message.slice(0, 3000),
  ].join('\n');
}

export function parseInterviewResponse(raw) {
  const parsed = parseJson(raw);
  if (!parsed) {
    return {
      reply: String(raw || '').trim().slice(0, 4000),
      complete: false,
      profilePatch: normalizeRecommendationProfile({}),
    };
  }
  return {
    reply: cleanText(parsed.reply, 4000) || 'کمی بیشتر درباره تجربه و ترجیحات کاری‌تان بگویید.',
    complete: parsed.complete === true,
    profilePatch: profilePatchFromModel(parsed.profilePatch || {}),
  };
}
