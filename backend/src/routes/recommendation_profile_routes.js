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

    if (req.method === 'POST' && parts.length === 1 && bodyIsInterview(req)) {
      // handled by the explicit branch below
    }

    throw new HttpError(405, 'METHOD_NOT_ALLOWED', 'Method not allowed');
  };
}

function bodyIsInterview(req) {
  const header = String(req.headers['x-hope-recommendation-interview'] || '').toLowerCase();
  return header === '1' || header === 'true';
}
