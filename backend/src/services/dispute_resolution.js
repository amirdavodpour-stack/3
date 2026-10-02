export const DISPUTE_DECISIONS = Object.freeze(['RELEASE','REFUND','HOLD']);
export const LEGAL_RULESET_VERSION = 'IR-2026-10-02-v1';

export const IRAN_LEGAL_RULES = Object.freeze([
  { source: 'قانون کار', article: '۲', principle: 'کارگر شخصی است که در مقابل دریافت حق‌السعی به درخواست کارفرما کار می‌کند.' },
  { source: 'قانون کار', article: '۷', principle: 'قرارداد کار رابطه‌ای است که به موجب آن کارگر در قبال حق‌السعی برای مدت موقت یا غیرموقت برای کارفرما کار می‌کند.' },
  { source: 'قانون کار', article: '۱۰', principle: 'قرارداد کار باید نوع کار، مزد، ساعات کار، محل، تاریخ و مدت را مشخص کند و موارد عرفی لازم نیز می‌تواند جزء آن باشد.' },
  { source: 'قانون کار', article: '۱۵۷', principle: 'اختلافات فردی ناشی از اجرای قانون کار و قرارداد کار مسیر سازش مستقیم و در صورت عدم سازش مراجع تشخیص و حل اختلاف کار را دارند.' },
  { source: 'قانون مدنی', article: '۱۰', principle: 'قراردادهای خصوصی در حدود قانون نافذند.' },
  { source: 'قانون مدنی', article: '۲۱۹', principle: 'عقد صحیح برای طرفین لازم‌الاتباع است مگر سبب قانونی برای انحلال وجود داشته باشد.' },
  { source: 'قانون مدنی', article: '۲۲۰', principle: 'تعهدات قراردادی، آثار قانونی و عرفی عقد را نیز دربر می‌گیرند.' },
  { source: 'قانون مدنی', article: '۲۲۱', principle: 'نقض تعهد می‌تواند موجب مسئولیت جبران خسارت در شرایط مقرر شود.' },
  { source: 'قانون مدنی', article: '۲۲۳', principle: 'معامله واقع‌شده اصولاً محمول بر صحت است مگر فساد آن معلوم شود.' },
  { source: 'قانون مدنی', article: '۲۲۴', principle: 'الفاظ عقد بر معانی عرفی حمل می‌شوند.' },
  { source: 'قانون مدنی', article: '۲۲۵', principle: 'عرف متعارفِ منصرف‌الیه عقد می‌تواند در حکم ذکر در عقد باشد.' },
  { source: 'قانون مدنی', article: '۱۲۵۷', principle: 'مدعی حق باید آن را اثبات کند و ادعای دفاعی محتاج دلیل نیز بر عهده مدعی آن است.' },
  { source: 'قانون تجارت الکترونیکی', article: '۱۲', principle: 'داده‌پیام صرفاً به دلیل قالب الکترونیکی قابل رد به‌عنوان دلیل نیست.' },
  { source: 'قانون تجارت الکترونیکی', article: '۱۳', principle: 'ارزش اثباتی داده‌پیام با عوامل اطمینان و تناسب روش‌های ایمنی سنجیده می‌شود.' },
  { source: 'قانون تجارت الکترونیکی', article: '۱۴', principle: 'سابقه و داده‌پیام مطمئن می‌تواند در حکم سند معتبر و قابل استناد باشد.' },
  { source: 'قانون آیین دادرسی مدنی', article: '۴۵۴', principle: 'ارجاع اختلاف به داوری با تراضی طرفین امکان‌پذیر است.' },
  { source: 'قانون آیین دادرسی مدنی', article: '۴۵۵', principle: 'شرط داوری می‌تواند ضمن معامله یا قرارداد جداگانه با تراضی مقرر شود.' },
  { source: 'قانون آیین دادرسی مدنی', article: '۴۵۸', principle: 'در تنظیم موافقت‌نامه داوری، موضوع اختلاف و مشخصات و حدود مأموریت داور باید به نحو مقرر تعیین شود.' },
  { source: 'قانون آیین دادرسی مدنی', article: '۴۶۶', principle: 'برخی اشخاص فاقد شرایط قانونی را نمی‌توان داور تعیین کرد.' },
  { source: 'قانون آیین دادرسی مدنی', article: '۴۸۹', principle: 'مواردی وجود دارد که رأی داوری برخلاف قوانین موجد حق یا خارج از موضوع و حدود اختیار داور باطل و غیرقابل اجراست.' },
] );

const clean = (v, max = 1600) => String(v ?? '').replace(/\s+/g, ' ').trim().slice(0, max);
const arrayOfText = (v, maxItems = 8, maxText = 600) => Array.isArray(v) ? v.filter(x => typeof x === 'string' && x.trim()).slice(0, maxItems).map(x => clean(x, maxText)) : [];

export function parseDisputeDecision(raw) {
  let payload = raw;
  if (typeof raw === 'string') {
    try { payload = JSON.parse(raw.trim()); } catch {
      const start = raw.indexOf('{'); const end = raw.lastIndexOf('}');
      try { payload = start >= 0 && end > start ? JSON.parse(raw.slice(start, end + 1)) : null; } catch { payload = null; }
    }
  }
  const rawDecision = String(payload?.decision || '').toUpperCase();
  const decision = DISPUTE_DECISIONS.includes(rawDecision) ? rawDecision : 'HOLD';
  const confidenceRaw = Number(payload?.confidence);
  const confidence = decision === 'HOLD' && rawDecision !== 'HOLD'
    ? 0
    : (Number.isFinite(confidenceRaw) ? Math.max(0, Math.min(1, confidenceRaw)) : 0);
  const manualReview = decision === 'HOLD' || confidence < 0.8 || !payload || !Array.isArray(payload?.legalBasis) || payload.legalBasis.length === 0;
  return {
    rulesetVersion: LEGAL_RULESET_VERSION, decision, confidence: Number(confidence.toFixed(3)), manualReview,
    summary: clean(payload?.summary, 1200),
    paymentRationale: clean(payload?.paymentRationale, 1200),
    factualFindings: arrayOfText(payload?.factualFindings),
    missingEvidence: arrayOfText(payload?.missingEvidence),
    legalBasis: Array.isArray(payload?.legalBasis) ? payload.legalBasis.slice(0, 8).map(item => ({ source: clean(item?.source,120), article: clean(item?.article,30), principle: clean(item?.principle,600) })).filter(item => item.source && item.article && item.principle) : [],
    adminActions: arrayOfText(payload?.adminActions, 6, 500),
  };
}

export function buildDisputeDecisionPrompt(context = {}) {
  const rules = IRAN_LEGAL_RULES.map(r => `${r.source} ماده ${r.article}: ${r.principle}`).join('\n');
  const job = context.job || {}; const payment = context.payment || {}; const feedback = Array.isArray(context.feedback) ? context.feedback : [];
  const payload = JSON.stringify({
    job: { title: clean(job.title,200), description: clean(job.description,3000), acceptanceCriteria: clean(job.acceptanceCriteria,2500), status: clean(job.status,40), kind: clean(job.kind,30), budget: payment.amount ?? null },
    payment: { status: clean(payment.status,40), amount: payment.amount ?? null, currency: clean(payment.currency,20) },
    feedback: feedback.slice(0,2).map(f => ({ role: clean(f.role,30), overallRating: f.overallRating, completedAsAgreed: f.completedAsAgreed, communicationRating: f.communicationRating, reportText: clean(f.reportText,2000), aiSentiment: clean(f.aiSentiment,40) })),
    evidence: Array.isArray(context.evidence) ? context.evidence.slice(0,20) : [],
  });
  return [
    'HOPE INTERNAL DISPUTE ASSESSMENT ENGINE.',
    'This is an internal operational assessment, not a court judgment and not a legally binding arbitral award.',
    'Use only the supplied facts and evidence. Never invent facts, witnesses, customary practices, legal articles, or missing documents.',
    'The final payment action is controlled by an authenticated administrator.',
    'Classify the relationship before applying sector-specific law: use Labour Law provisions only when the supplied facts support a true employer-worker employment relationship; for independent contractor/pimankari or platform service disputes, prioritize the applicable contract and Civil Code principles instead. Never infer the classification without evidence.',
    'Apply contractual terms first; then relevant Iranian law, evidentiary logic, and clearly identified customary practice. Treat custom as secondary and only when supported by the record.',
    'Do not infer protected or sensitive attributes. Do not give general legal advice.',
    'Possible decisions: RELEASE, REFUND, HOLD. Use HOLD whenever material evidence is missing, contradictory, or confidence is insufficient.',
    'Return ONLY JSON: {"decision":"RELEASE|REFUND|HOLD","confidence":0,"summary":"","paymentRationale":"","factualFindings":[],"missingEvidence":[],"legalBasis":[{"source":"","article":"","principle":""}],"adminActions":[]}',
    `LEGAL RULESET ${LEGAL_RULESET_VERSION}:\n${rules}`,
    `CASE: ${payload}`,
  ].join('\n\n');
}

export async function analyzeDisputeWithAI({ askAI, context }) {
  if (typeof askAI !== 'function') return parseDisputeDecision(null);
  const raw = await askAI(buildDisputeDecisionPrompt(context));
  return parseDisputeDecision(raw);
}