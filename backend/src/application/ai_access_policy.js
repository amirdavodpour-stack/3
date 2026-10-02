export const AUTOMATED_AI_TASKS = Object.freeze([
  'REGISTRATION_PROFILE',
  'RECOMMENDATIONS',
  'OPPORTUNITY_AGENT',
  'JOB_SATISFACTION',
]);

export function assertAutomatedAiAccess({ route, source = 'USER' } = {}) {
  if (String(source).toUpperCase() === 'SYSTEM') return true;
  const error = new Error('General AI access is disabled for users');
  error.code = 'AI_USER_ACCESS_DISABLED';
  error.status = 403;
  error.route = String(route || '');
  throw error;
}
