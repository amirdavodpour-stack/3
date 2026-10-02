import { buildCandidateProfile, scoreRecommendation } from '../recommendation.js';

export function createOpportunityAgentRoutes({
  authUser,
  sendJson,
  HttpError,
  repo,
  buildOpportunityAgentState,
  parseOpportunityAgentState,
}) {
  return async function routeHandler(req, res, parts) {
    if (parts.length !== 1 || parts[0] !== 'opportunity-agent') {
      throw new HttpError(404, 'NOT_FOUND', 'Opportunity agent route not found');
    }
    if (req.method !== 'GET') {
      throw new HttpError(405, 'METHOD_NOT_ALLOWED', 'Method not allowed');
    }

    const me = await authUser(req);
    const [
      applications,
      profile,
      savedSearches,
      events,
      completedJobs,
    ] = await Promise.all([
      repo.listCandidateApplications(me.id),
      repo.getRecommendationProfile(me.id),
      repo.listSavedSearches(me.id),
      repo.listRecommendationEvents(me.id),
      repo.listProviderWorkHistory(me.id),
    ]);

    let recommendations = [];
    if (process.env.DATABASE_URL) {
      const rows = await repo.listJobViews({
        status: 'PUBLISHED',
        kind: null,
        categoryId: null,
        city: null,
        visibility: null,
        search: null,
      });
      const candidate = buildCandidateProfile(applications, {
        profile: profile || {},
        savedSearches,
        events,
        completedJobs,
      });
      recommendations = rows
        .map(({ job }) => {
          const match = scoreRecommendation(job, candidate, { seenCategories: new Set() });
          return {
            id: String(job.id),
            title: job.title,
            kind: job.kind || (job.jobType === 'FIXED' ? 'MISSION' : 'JOB'),
            recommendationScore: match.score,
            recommendationReasons: match.reasons,
          };
        })
        .sort((a, b) => (b.recommendationScore - a.recommendationScore) || String(a.id).localeCompare(String(b.id)))
        .slice(0, 20);
    }

    return sendJson(res, 200, parseOpportunityAgentState(buildOpportunityAgentState({
      profile: profile || {},
      applications,
      events,
      savedSearches,
      completedJobs,
      recommendations,
    })));
  };
}
