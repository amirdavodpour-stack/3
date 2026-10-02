import { assertAutomatedAiAccess } from '../application/ai_access_policy.js';

export function createAiRoutes({ authUser, readBody, sendJson, HttpError, askAI }) {
  return async function aiRoutes(req, res, parts) {
    if (parts.length !== 1 || parts[0] !== 'chat') throw new HttpError(404, 'NOT_FOUND', 'AI route not found');
    if (req.method !== 'POST') throw new HttpError(405, 'METHOD_NOT_ALLOWED', 'Method not allowed');

    await authUser(req);
    assertAutomatedAiAccess({ route: 'chat', source: 'USER' });
    const body = await readBody(req);
    const message = typeof body?.message === 'string' ? body.message.trim() : '';
    if (!message) throw new HttpError(400, 'INVALID_MESSAGE', 'message is required');
    if (message.length > 12000) throw new HttpError(400, 'MESSAGE_TOO_LONG', 'message is too long');

    const answer = await askAI(message);
    return sendJson(res, 200, { answer });
  };
}
