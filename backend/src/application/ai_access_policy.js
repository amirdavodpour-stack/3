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

export function assertAssignedAiTaskAccess({ task, onboardingCompleted = false } = {}) {
  if (!AUTOMATED_AI_TASKS.includes(String(task || ''))) {
    const error = new Error('AI task is not allowlisted');
    error.code = 'AI_TASK_NOT_ALLOWLISTED';
    error.status = 403;
    throw error;
  }
  if (onboardingCompleted) {
    const error = new Error('Completed assigned AI task is no longer user-accessible');
    error.code = 'AI_USER_ACCESS_DISABLED';
    error.status = 403;
    throw error;
  }
  return true;
}
