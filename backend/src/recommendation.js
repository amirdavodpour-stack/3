const TOKEN_RE = /[\p{L}\p{N}]+/gu;

export const RECOMMENDATION_VERSION = '2.3';

export const RECOMMENDATION_WEIGHTS = Object.freeze({
  skills: 0.20,
  category: 0.15,
  experience: 0.15,
  location: 0.10,
  workMode: 0.10,
  salary: 0.10,
  preference: 0.10,
  behavior: 0.05,
  freshness: 0.05,
});

const RECENCY_DECAY_DAYS = 90;

function recencyScore(value) {
  if (!value) return .5;
  const ageMs = Date.now() - Date.parse(value);
  if (!Number.isFinite(ageMs) || ageMs <= 0) return 1;
  const days = ageMs / 86400000;
  return Math.exp(-days / RECENCY_DECAY_DAYS);
}

function diversityPenalty(job, seen = new Set()) {
  const key = String(job.categoryId || job.category || 'unknown');
  return seen.has(key) ? 0.85 : 1;
}

function tokens(value) {
  return new Set((String(value || '').toLocaleLowerCase().match(TOKEN_RE) || []).filter(t => t.length >= 2));
}
function overlap(a, b) {
  if (!a.size || !b.size) return 0;
  let hit = 0; for (const x of a) if (b.has(x)) hit++;
  return Math.min(1, hit / Math.max(1, Math.min(a.size, 8)));
}
function clamp01(n) { return Math.max(0, Math.min(1, Number(n) || 0)); }

export function buildCandidateProfile(applications = [], context = {}) {
  const skills = new Set();
  const experienceTokens = new Set();
  const interestTokens = new Set();
  const categories = new Map();
  const cities = new Map();
  const kinds = new Map();
  const workModes = new Map();
  const behaviorCategories = new Map();
  const behaviorCities = new Map();
  const behaviorKinds = new Map();
  const preference = context.profile || {};
  let salaryMin = preference.salaryMin == null ? null : Number(preference.salaryMin);
  let salaryMax = preference.salaryMax == null ? null : Number(preference.salaryMax);
  let total = Number(preference.interactionCount || 0);

  for (const t of tokens(preference.skills)) skills.add(t);
  for (const value of preference.interests || []) for (const t of tokens(value)) interestTokens.add(t);
  if (preference.goals) for (const t of tokens(preference.goals)) interestTokens.add(t);
  for (const value of preference.desiredKinds || []) {
    const key = String(value).toUpperCase();
    if (key) kinds.set(key, (kinds.get(key) || 0) + 3);
  }
  for (const value of preference.preferredCategories || []) categories.set(String(value), (categories.get(String(value)) || 0) + 3);
  for (const value of preference.preferredCities || []) cities.set(String(value), (cities.get(String(value)) || 0) + 3);
  if (preference.workMode) workModes.set(String(preference.workMode).toUpperCase(), 3);

  for (const a of applications) {
    total++;
    for (const t of tokens(a.skills)) skills.add(t);
    const weight = ['SHORTLISTED','FORWARDED','INTERVIEW','ACCEPTED','HIRED','COMPLETED'].includes(String(a.status || '').toUpperCase()) ? 3 : 1;
    if (a.categoryId) categories.set(String(a.categoryId), (categories.get(String(a.categoryId)) || 0) + weight);
    if (a.jobCity) cities.set(String(a.jobCity), (cities.get(String(a.jobCity)) || 0) + weight);
    if (a.jobKind) kinds.set(String(a.jobKind).toUpperCase(), (kinds.get(String(a.jobKind).toUpperCase()) || 0) + weight);
    if (a.workMode) workModes.set(String(a.workMode).toUpperCase(), (workModes.get(String(a.workMode).toUpperCase()) || 0) + weight);
    const s = Number(a.monthlySalary);
    if (Number.isFinite(s) && s > 0) { salaryMin = salaryMin == null ? s : Math.min(salaryMin, s); salaryMax = salaryMax == null ? s : Math.max(salaryMax, s); }
  }

  for (const job of context.completedJobs || []) {
    total += 2;
    for (const t of tokens(job.title || '')) { experienceTokens.add(t); skills.add(t); }
    for (const t of tokens(job.description || job.attributes?.skills || '')) experienceTokens.add(t);
    if (job.categoryId) categories.set(String(job.categoryId), (categories.get(String(job.categoryId)) || 0) + 5);
    if (job.city) cities.set(String(job.city), (cities.get(String(job.city)) || 0) + 2);
    if (job.kind) kinds.set(String(job.kind).toUpperCase(), (kinds.get(String(job.kind).toUpperCase()) || 0) + 5);
  }

  for (const search of context.savedSearches || []) {
    total++;
    for (const t of tokens(search.query)) interestTokens.add(t);
    if (search.category && search.category !== 'ALL') categories.set(String(search.category), (categories.get(String(search.category)) || 0) + 2);
    if (search.city && search.city !== 'AUTO') cities.set(String(search.city), (cities.get(String(search.city)) || 0) + 2);
    if (search.kind && search.kind !== 'ALL') kinds.set(String(search.kind).toUpperCase(), (kinds.get(String(search.kind).toUpperCase()) || 0) + 2);
  }

  for (const event of context.events || []) {
    total++;
    const props = event?.properties || {};
    for (const t of tokens(props.query)) interestTokens.add(t);
    if (props.categoryId) behaviorCategories.set(String(props.categoryId), (behaviorCategories.get(String(props.categoryId)) || 0) + 1);
    if (props.city) behaviorCities.set(String(props.city), (behaviorCities.get(String(props.city)) || 0) + 1);
    if (props.kind) behaviorKinds.set(String(props.kind).toUpperCase(), (behaviorKinds.get(String(props.kind).toUpperCase()) || 0) + 1);
  }

  const top = map => [...map.entries()].sort((a,b)=>b[1]-a[1]).slice(0,8).map(x=>x[0]);
  return {
    skills, experienceTokens, interestTokens, categories, cities, kinds, workModes,
    behaviorCategories, behaviorCities, behaviorKinds,
    topCategories:top(categories), topCities:top(cities), topKinds:top(kinds), topWorkModes:top(workModes),
    topBehaviorCategories:top(behaviorCategories), topBehaviorCities:top(behaviorCities), topBehaviorKinds:top(behaviorKinds),
    salaryMin, salaryMax, interactionCount:total,
    resumeText:String(preference.resumeText || '').slice(0, 12000),
    interests:Array.isArray(preference.interests) ? preference.interests.slice(0, 20) : [],
    goals:String(preference.goals || '').slice(0, 2000),
  };
}

export function scoreRecommendation(job, profile, context = {}) {
  const reasons = [];
  const rawJobSkills = Array.isArray(job.skills) ? job.skills.join(' ') : (job.skills || job.attributes?.skills || '');
  const jobText = tokens(`${job.title || ''} ${job.description || ''} ${job.acceptanceCriteria || ''} ${rawJobSkills}`);
  const skillScore = overlap(profile?.skills || new Set(), jobText);
  let categoryScore = 0;
  if (job.categoryId && profile?.categories?.has(String(job.categoryId))) categoryScore = 1;
  const explicitInterestScore = overlap(profile?.interestTokens || new Set(), jobText);
  let experienceScore = overlap(profile?.experienceTokens || new Set(), jobText);
  const experienceTokens = tokens(job.experience || job.providerExperience || '');
  if (experienceTokens.size && profile?.skills) {
    experienceScore = Math.max(experienceScore, overlap(profile.skills, experienceTokens));
  }
  let locationScore = 0;
  let distanceKm = null;
  if (context.lat != null && context.lng != null && context.cityCoords?.[job.city]) {
    distanceKm = context.distanceFn(context.lat, context.lng, context.cityCoords[job.city][0], context.cityCoords[job.city][1]);
    locationScore = distanceKm <= 5 ? 1 : distanceKm <= 20 ? .85 : distanceKm <= 60 ? .60 : distanceKm <= 150 ? .25 : 0;
  } else if (context.city && job.city === context.city) locationScore = 1;
  else if (job.city === 'آنلاین') locationScore = .55;
  const preferredModes = profile?.workModes instanceof Map ? [...profile.workModes.keys()] : (Array.isArray(profile?.workModes) ? profile.workModes : []);
  const workModeScore = job.workMode ? (preferredModes.includes(String(job.workMode)) ? 1 : 0) : (job.city === 'آنلاین' ? .55 : .4);
  let salaryScore = .5;
  const budget = Number(job.monthlySalary || job.budgetMax || 0);
  if (budget > 0 && profile?.salaryMin != null) {
    const center = (profile.salaryMin + profile.salaryMax) / 2;
    salaryScore = 1 - Math.min(1, Math.abs(budget - center) / Math.max(center, 1));
  }
  const kindScore = profile?.kinds?.has(String(job.kind || 'JOB').toUpperCase()) ? 1 : .5;
  const behaviorCategoryScore = job.categoryId && profile?.behaviorCategories?.has(String(job.categoryId)) ? 1 : 0;
  const behaviorCityScore = job.city && profile?.behaviorCities?.has(String(job.city)) ? .8 : 0;
  const behaviorKindScore = profile?.behaviorKinds?.has(String(job.kind || 'JOB').toUpperCase()) ? .8 : 0;
  const preferenceScore = Math.max(
    context.categoryId && String(job.categoryId) === String(context.categoryId) ? 1 : categoryScore,
    explicitInterestScore,
  );
  const behaviorMatch = Math.max(behaviorCategoryScore, behaviorCityScore, behaviorKindScore);
  const behaviorScore = Math.min(1, Number(profile?.interactionCount || 0) / 20) * .35 + Math.max(kindScore, behaviorMatch) * .65;
  const freshnessScore = recencyScore(job.updatedAt || job.publishedAt || job.createdAt);
  const diversityMultiplier = diversityPenalty(job, context.seenCategories);
  const scores = { skills:skillScore, category:categoryScore, experience:experienceScore, location:locationScore, workMode:workModeScore, salary:salaryScore, preference:preferenceScore, behavior:behaviorScore, freshness:freshnessScore };
  let score = Object.entries(RECOMMENDATION_WEIGHTS).reduce((sum,[k,w])=>sum+scores[k]*w,0) * 100 * diversityMultiplier;
  if (skillScore >= .5) reasons.push('SKILL_MATCH');
  if (categoryScore >= 1) reasons.push('CATEGORY_MATCH');
  if (locationScore >= .85) reasons.push(distanceKm != null && distanceKm <= 5 ? 'VERY_NEAR' : 'NEARBY');
  else if (job.city === 'آنلاین' && locationScore > 0) reasons.push('REMOTE');
  if (workModeScore >= .9) reasons.push('WORK_MODE_MATCH');
  if (salaryScore >= .8) reasons.push('SALARY_FIT');
  if (behaviorScore >= .7) reasons.push('BEHAVIOR_MATCH');
  if (preferenceScore >= .9 && categoryScore < 1) reasons.push('PREFERENCE_MATCH');
  if (!reasons.length) reasons.push('GENERAL_MATCH');
  const componentScores = {...Object.fromEntries(Object.entries(scores).map(([k,v])=>[k,Number((v*100).toFixed(1))]))};
  const scoreByComponents = Object.entries(RECOMMENDATION_WEIGHTS).reduce((sum,[k,w])=>sum + componentScores[k] * w, 0) * diversityMultiplier;
  if (Math.abs(score - scoreByComponents) > 0.05) throw new Error('Recommendation score invariant violated');
  return { version: RECOMMENDATION_VERSION, score:Number(score.toFixed(2)), distanceKm:distanceKm == null ? null : Number(distanceKm.toFixed(1)), reasons, componentScores };
}

const AI_RERANK_MAX_CANDIDATES = 20;

function aiSafeText(value, maxLength) {
  return String(value ?? '').replace(/\s+/g, ' ').trim().slice(0, maxLength);
}

function parseAiRanking(raw, validIds) {
  if (typeof raw !== 'string' || !raw.trim()) return null;
  let payload;
  try {
    payload = JSON.parse(raw.trim());
  } catch {
    const start = raw.indexOf('{');
    const end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      payload = JSON.parse(raw.slice(start, end + 1));
    } catch {
      return null;
    }
  }

  const rankings = Array.isArray(payload)
    ? payload
    : (Array.isArray(payload?.rankings) ? payload.rankings : null);
  if (!rankings) return null;

  const seen = new Set();
  return rankings
    .map((item) => {
      if (!item || typeof item.id !== 'string' || !validIds.has(item.id) || seen.has(item.id)) return null;
      seen.add(item.id);
      const score = clamp01(Number(item.score) / 100) * 100;
      const confidence = clamp01(item.confidence);
      const reasons = Array.isArray(item.reasons)
        ? item.reasons.filter((reason) => typeof reason === 'string' && reason.trim()).slice(0, 3)
        : [];
      return { id: item.id, score: Number(score.toFixed(2)), confidence: Number(confidence.toFixed(2)), reasons };
    })
    .filter(Boolean);
}

export function buildAiRerankPrompt(profile, jobs) {
  const profilePayload = {
    resumeText: String(profile?.resumeText || '').slice(0, 6000),
    interests: Array.isArray(profile?.interests) ? profile.interests.slice(0, 20) : [],
    goals: String(profile?.goals || '').slice(0, 2000),
    topCategories: profile?.topCategories ?? [],
    topCities: profile?.topCities ?? [],
    topKinds: profile?.topKinds ?? [],
    topWorkModes: profile?.topWorkModes ?? [],
    topBehaviorCategories: profile?.topBehaviorCategories ?? [],
    topBehaviorCities: profile?.topBehaviorCities ?? [],
    topBehaviorKinds: profile?.topBehaviorKinds ?? [],
    salaryMin: profile?.salaryMin ?? null,
    salaryMax: profile?.salaryMax ?? null,
    interactionCount: profile?.interactionCount ?? 0,
    experienceKeywords: profile?.experienceTokens ? [...profile.experienceTokens].slice(0, 30) : [],
    interestKeywords: profile?.interestTokens ? [...profile.interestTokens].slice(0, 30) : [],
  };
  const opportunities = jobs.slice(0, AI_RERANK_MAX_CANDIDATES).map((job) => ({
    id: aiSafeText(job.id, 80),
    title: aiSafeText(job.title, 160),
    description: aiSafeText(job.description, 700),
    category: aiSafeText(job.category, 100),
    city: aiSafeText(job.city, 100),
    kind: aiSafeText(job.kind, 30),
    workMode: aiSafeText(job.workMode ?? job.attributes?.workMode, 40),
    budgetMin: aiSafeText(job.budgetMin, 40),
    budgetMax: aiSafeText(job.budgetMax, 40),
    monthlySalary: aiSafeText(job.monthlySalary, 40),
    duration: aiSafeText(job.duration, 40),
    acceptanceCriteria: aiSafeText(job.acceptanceCriteria, 500),
  }));

  return [
    'You are HOPE’s opportunity matching engine.',
    'Rank the supplied opportunities for this candidate only from the supplied job and profile facts.',
    'Do not invent qualifications or missing preferences. Do not use protected or sensitive attributes.',
    'Return ONLY valid JSON with this shape:',
    '{"rankings":[{"id":"job-id","score":0,"confidence":0,"reasons":["reason"]}]}',
    'score is 0-100; confidence is 0-1; include at most 3 concise reasons per job.',
    'PROFILE: ' + JSON.stringify(profilePayload),
    'OPPORTUNITIES: ' + JSON.stringify(opportunities),
  ].join('\n');
}

export async function rerankWithAI({ askAI, profile, jobs, maxCandidates = AI_RERANK_MAX_CANDIDATES } = {}) {
  if (typeof askAI !== 'function' || !Array.isArray(jobs) || jobs.length < 2) return null;
  const candidates = jobs.slice(0, Math.min(AI_RERANK_MAX_CANDIDATES, Math.max(2, Number(maxCandidates) || AI_RERANK_MAX_CANDIDATES)));
  if (candidates.length < 2) return null;

  let raw;
  try {
    raw = await askAI(buildAiRerankPrompt(profile, candidates));
  } catch {
    return null;
  }

  return parseAiRanking(raw, new Set(candidates.map((job) => String(job.id))));
}

export function evaluateRecommendationRanking(items = [], relevantFn = () => false, k = 10) {
  const top = items.slice(0, Math.max(1, Number(k) || 10));
  const relevant = top.map(relevantFn);
  const hits = relevant.filter(Boolean).length;
  const precisionAtK = Number((hits / Math.max(1, top.length)).toFixed(4));
  const totalRelevant = items.filter(relevantFn).length;
  const recallAtK = Number((hits / Math.max(1, totalRelevant)).toFixed(4));
  let dcg = 0;
  for (let i = 0; i < relevant.length; i++) if (relevant[i]) dcg += 1 / Math.log2(i + 2);
  const idealN = Math.min(top.length, totalRelevant);
  let idcg = 0;
  for (let i = 0; i < idealN; i++) idcg += 1 / Math.log2(i + 2);
  const ndcgAtK = Number((idcg ? dcg / idcg : 1).toFixed(4));
  const reasonCoverage = Number((top.filter(x => Array.isArray(x.recommendationReasons) && x.recommendationReasons.length > 0).length / Math.max(1, top.length)).toFixed(4));
  return { k: Math.max(1, Number(k) || 10), hits, totalRelevant, precisionAtK, recallAtK, ndcgAtK, reasonCoverage };
}

[executed on device: localhost (ad4940fb-3108-4ab5-af41-ee34669dd70c)]