export function createRecommendationProfileRoutes({
  authUser,
  readBody,
  sendJson,
  HttpError,
  repo,
  enrichRecommendationProfile,
  buildRecommendationInterviewPrompt,
  parseInterviewResponse,
  askAI,
}) {
  return async function routeHandler(req, res, parts) {
    const me = await authUser(req);
    if (parts.length !== 1) throw new HttpError(404, 'NOT_FOUND', 'Recommendation profile route not found');

    if (req.method === 'GET') {
      const profile = await repo.getRecommendationProfile(me.id);
      return sendJson(res, 200, profile || {
        onboardingCompleted: false,
        resumeText: '',
        skills: [],
        interests: [],
        preferredCategories: [],
        preferredCities: [],
        desiredKinds: [],
      });
    }

    if (req.method === 'POST') {
      const body = await readBody(req);
      if (!body || typeof body !== 'object' || Array.isArray(body)) {
        throw new HttpError(400, 'INVALID_BODY', 'Request body is required');
      }
      const history = Array.isArray(body.history) ? body.history : [];
      const message = typeof body.message === 'string' ? body.message.trim() : '';
      if (message.length > 4000) throw new HttpError(400, 'MESSAGE_TOO_LONG', 'Interview message is too long');
      if (!message && history.length > 0) throw new HttpError(400, 'MESSAGE_REQUIRED', 'Message is required');
      let raw;
      try {
        raw = await askAI(buildRecommendationInterviewPrompt(history, message));
      } catch {
        throw new HttpError(503, 'AI_PROVIDER_UNAVAILABLE', 'Recommendation interview is temporarily unavailable');
      }
      return sendJson(res, 200, parseInterviewResponse(raw));
    }

    if (req.method === 'PUT') {
      const body = await readBody(req);
      if (!body || typeof body !== 'object' || Array.isArray(body)) {
        throw new HttpError(400, 'INVALID_BODY', 'Request body is required');
      }
      const enriched = await enrichRecommendationProfile({
        profile: body,
        transcript: typeof body.transcript === 'string' ? body.transcript : '',
        askAI,
      });
      const stored = await repo.upsertRecommendationProfile(me.id, enriched);
      return sendJson(res, 200, stored);
    }

    throw new HttpError(405, 'METHOD_NOT_ALLOWED', 'Method not allowed');
  };
}
