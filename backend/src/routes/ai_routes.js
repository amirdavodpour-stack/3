export function createAiRoutes({
  authUser,
  readBody,
  sendJson,
  HttpError,
  askAI,
}) {
  return async function aiRoutes(req, res, parts) {
    if (req.method !== 'POST' || parts.length !== 1 || parts[0] !== 'chat') {
      throw new HttpError(405, 'METHOD_NOT_ALLOWED', 'Method not allowed');
    }

    await authUser(req);
    const body = await readBody(req);
    const message = typeof body?.message === 'string' ? body.message.trim() : '';

    if (!message) {
      throw new HttpError(400, 'MESSAGE_REQUIRED', 'message is required');
    }
    if (message.length > 12000) {
      throw new HttpError(413, 'MESSAGE_TOO_LARGE', 'message is too large');
    }

    const answer = await askAI(message);
    return sendJson(res, 200, { answer });
  };
}
