export const CHAT_KINDS = Object.freeze(['JOB','ADMIN']);
export const CHAT_STATUSES = Object.freeze(['OPEN','CLOSED']);

const normalized = (value) => String(value ?? '').trim().toUpperCase();

export function canAccessConversation(conversation, userId, role) {
  if (!conversation || !userId) return false;
  const kind = normalized(conversation.kind);
  if (kind === 'ADMIN') return normalized(role) === 'ADMIN';
  if (kind === 'JOB') return String(conversation.ownerId) === String(userId) || String(conversation.workerId) === String(userId);
  return false;
}

export function canSendToConversation(conversation, userId, role) {
  return normalized(conversation?.status) === 'OPEN' && canAccessConversation(conversation, userId, role);
}
