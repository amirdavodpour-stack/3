const ROLES = new Set(['WORKER', 'EMPLOYER']);
const SENTIMENTS = new Set(['SATISFIED', 'MIXED', 'UNSATISFIED', 'NEEDS_REVIEW']);
const TAGS = new Set(['QUALITY', 'COMMUNICATION', 'TIMELINESS', 'VALUE', 'SCOPE', 'PROFESSIONALISM', 'OTHER']);

export const SATISFACTION_QUESTIONS = Object.freeze([
  Object.freeze({ id:'overall_rating', type:'RATING', prompt:'رضایت کلی شما از این همکاری چقدر بود؟', min:1, max:5 }),
  Object.freeze({ id:'completed_as_agreed', type:'BOOLEAN', prompt:'آیا کار/همکاری مطابق توافق انجام شد؟' }),
  Object.freeze({ id:'communication_rating', type:'RATING', prompt:'ارتباط و هماهنگی در طول همکاری چطور بود؟', min:1, max:5 }),
  Object.freeze({ id:'report', type:'TEXT', prompt:'یک گزارش کوتاه از نتیجه همکاری بنویسید.', maxLength:2000 }),
]);

function clampInt(value, min, max, fallback) {
  const n = Number(value);
  if (!Number.isInteger(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function normalizeTags(values) {
  return [...new Set((Array.isArray(values) ? values : [])
    .map((value) => String(value || '').trim().toUpperCase())
    .filter((value) => TAGS.has(value)))].slice(0, 8);
}

function normalizeRiskFlags(values) {
  return [...new Set((Array.isArray(values) ? values : [])
    .map((value) => String(value || '').trim())
    .filter(Boolean))].slice(0, 8);
}

export function parseSatisfactionAnalysis(raw) {
  let value = raw;
  if (typeof raw === 'string') {
    try { value = JSON.parse(raw); } catch { value = {}; }
  }
  if (!value || typeof value !== 'object') value = {};
  const score = clampInt(value.satisfactionScore, 0, 100, 0);
  const rawSentiment = String(value.sentiment || 'NEEDS_REVIEW').trim().toUpperCase();
  const sentiment = SENTIMENTS.has(rawSentiment) ? rawSentiment : 'NEEDS_REVIEW';
  const summary = String(value.summary || '').trim().slice(0, 1200);
  return {
    summary,
    satisfactionScore: score,
    sentiment,
    tags: normalizeTags(value.tags),
    riskFlags: normalizeRiskFlags(value.riskFlags).filter((flag) => flag.toLowerCase() !== 'hidden'),
  };
}

export function buildSatisfactionAnalysisPrompt({ role, answers }) {
  return [
    'You are HOPE internal satisfaction-analysis automation.',
    'Do not provide general advice, chat, or perform unrelated tasks.',
    'Analyze only this completed job satisfaction report and return JSON.',
    'Never infer protected or sensitive attributes. Do not invent facts.',
    'JSON fields: summary, satisfactionScore(0..100), sentiment(SATISFIED|MIXED|UNSATISFIED|NEEDS_REVIEW), tags, riskFlags.',
    `ROLE: ${role}`,
    `REPORT: ${JSON.stringify(answers)}`,
  ].join('\n');
}

export function evaluateSettlementGate({ jobStatus, paymentStatus, feedback = [] } = {}) {
  if (String(jobStatus || '').toUpperCase() !== 'COMPLETED') return { ready:false, reason:'JOB_NOT_COMPLETED' };
  if (String(paymentStatus || '').toUpperCase() !== 'RELEASE_PENDING') return { ready:false, reason:'PAYMENT_NOT_RELEASE_PENDING' };
  const byRole = new Map();
  for (const item of Array.isArray(feedback) ? feedback : []) {
    if (!item || !ROLES.has(String(item.role || '').toUpperCase())) continue;
    byRole.set(String(item.role).toUpperCase(), item);
  }
  if (byRole.size !== 2) return { ready:false, reason:'BOTH_REPORTS_REQUIRED' };
  for (const role of ['WORKER', 'EMPLOYER']) {
    const item = byRole.get(role);
    if (!item || item.status !== 'ANALYZED' || item.satisfied !== true || item.completedAsAgreed !== true || Number(item.overallRating) < 4) {
      return { ready:false, reason:`REPORT_NOT_SATISFACTORY:${role}` };
    }
  }
  const userIds = [...byRole.values()].map((item) => String(item.userId || ''));
  if (!userIds[0] || !userIds[1] || userIds[0] === userIds[1]) return { ready:false, reason:'INVALID_PARTICIPANTS' };
  return { ready:true, reason:'READY_FOR_AUTO_RELEASE' };
}
