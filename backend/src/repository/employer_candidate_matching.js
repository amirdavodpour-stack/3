import { requirePool } from './context.js';

function profileFromRow(row) {
  if (!row?.profile_user_id) return null;
  const list = (value) =>
    Array.isArray(value)
      ? value.filter((item) => typeof item === 'string').slice(0, 40)
      : [];
  return {
    userId: row.profile_user_id,
    resumeText: row.resume_text || '',
    skills: list(row.profile_skills),
    interests: list(row.profile_interests),
    preferredCategories: list(row.preferred_categories),
    preferredCities: list(row.preferred_cities),
    desiredKinds: list(row.desired_kinds),
    workMode: row.profile_work_mode || null,
    availability: row.profile_availability || null,
    salaryMin: row.salary_min == null ? null : String(row.salary_min),
    salaryMax: row.salary_max == null ? null : String(row.salary_max),
    experienceLevel: row.experience_level || null,
    goals: row.profile_goals || '',
    onboardingCompleted: row.onboarding_completed === true,
  };
}

export async function listCandidatesForEmployerMatching(jobId) {
  const jobResult = await requirePool().query(
    'SELECT id, kind FROM jobs WHERE id=$1',
    [jobId],
  );
  const job = jobResult.rows[0];
  if (!job) return [];

  let candidates;
  if (String(job.kind || 'JOB').toUpperCase() === 'MISSION') {
    const { rows } = await requirePool().query(
      `SELECT o.id AS offer_id,o.provider_id,o.price,o.message,o.status,o.created_at,o.updated_at,
              u.display_name,
              rp.user_id AS profile_user_id,
              rp.resume_text,
              rp.skills AS profile_skills,
              rp.interests AS profile_interests,
              rp.preferred_categories,
              rp.preferred_cities,
              rp.desired_kinds,
              rp.work_mode AS profile_work_mode,
              rp.availability AS profile_availability,
              rp.salary_min,rp.salary_max,rp.experience_level,rp.goals AS profile_goals,
              rp.onboarding_completed
         FROM offers o
         JOIN users u ON u.id=o.provider_id
         LEFT JOIN recommendation_profiles rp ON rp.user_id=o.provider_id
        WHERE o.job_id=$1
          AND o.status IN ('PENDING','ACCEPTED')
        ORDER BY o.created_at ASC`,
      [jobId],
    );
    candidates = rows.map((row) => ({
      userId: row.provider_id,
      displayName: row.display_name || '',
      profile: profileFromRow(row),
      offer: {
        id: row.offer_id,
        providerId: row.provider_id,
        price: String(row.price ?? '0'),
        message: row.message || '',
        status: row.status,
        createdAt: row.created_at?.toISOString?.() ?? row.created_at,
        updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at,
      },
    }));
  } else {
    const { rows } = await requirePool().query(
      `SELECT a.id AS application_id,a.candidate_id,a.resume_text AS application_resume_text,
              a.skills AS application_skills,a.status AS application_status,
              a.created_at AS application_created_at,a.updated_at AS application_updated_at,
              u.display_name,
              rp.user_id AS profile_user_id,
              rp.resume_text,
              rp.skills AS profile_skills,
              rp.interests AS profile_interests,
              rp.preferred_categories,
              rp.preferred_cities,
              rp.desired_kinds,
              rp.work_mode AS profile_work_mode,
              rp.availability AS profile_availability,
              rp.salary_min,rp.salary_max,rp.experience_level,rp.goals AS profile_goals,
              rp.onboarding_completed
         FROM job_applications a
         JOIN users u ON u.id=a.candidate_id
         LEFT JOIN recommendation_profiles rp ON rp.user_id=a.candidate_id
        WHERE a.job_id=$1
          AND a.status IN ('PENDING','SHORTLISTED','FORWARDED','INTERVIEW','OFFERED','ACCEPTED')
        ORDER BY a.created_at ASC`,
      [jobId],
    );
    candidates = rows.map((row) => ({
      userId: row.candidate_id,
      displayName: row.display_name || '',
      profile: profileFromRow(row),
      application: {
        id: row.application_id,
        candidateId: row.candidate_id,
        resumeText: row.application_resume_text || '',
        skills: row.application_skills || '',
        status: row.application_status,
        createdAt: row.application_created_at?.toISOString?.() ?? row.application_created_at,
        updatedAt: row.application_updated_at?.toISOString?.() ?? row.application_updated_at,
      },
    }));
  }

  const ids = [...new Set(candidates.map((candidate) => candidate.userId).filter(Boolean))];
  if (!ids.length) return candidates;

  const [applicationHistory, completedWork, events] = await Promise.all([
    requirePool().query(
      `SELECT a.candidate_id,j.category_id,j.city,j.kind,a.status,a.updated_at
         FROM job_applications a
         JOIN jobs j ON j.id=a.job_id
        WHERE a.candidate_id = ANY($1::uuid[])
        ORDER BY a.updated_at DESC`,
      [ids],
    ),
    requirePool().query(
      `SELECT provider_id,title,description,acceptance_criteria,category_id,city,kind,attributes
         FROM jobs
        WHERE provider_id = ANY($1::uuid[])
          AND status IN ('COMPLETED','SETTLED')
        ORDER BY updated_at DESC`,
      [ids],
    ),
    requirePool().query(
      `SELECT user_id,event_name,properties,occurred_at
         FROM analytics_events
        WHERE user_id = ANY($1::uuid[])
          AND event_name IN ('search_viewed','opportunity_viewed','application_submitted','application_withdrawn')
        ORDER BY occurred_at DESC`,
      [ids],
    ),
  ]);

  const applicationsByUser = new Map();
  for (const row of applicationHistory.rows) {
    const key = String(row.candidate_id);
    const list = applicationsByUser.get(key) || [];
    list.push({
      categoryId: row.category_id,
      city: row.city,
      kind: row.kind,
      status: row.status,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at,
    });
    applicationsByUser.set(key, list.slice(0, 50));
  }

  const completedByUser = new Map();
  for (const row of completedWork.rows) {
    const key = String(row.provider_id);
    const list = completedByUser.get(key) || [];
    list.push({
      title: row.title,
      description: row.description,
      acceptanceCriteria: row.acceptance_criteria,
      categoryId: row.category_id,
      city: row.city,
      kind: row.kind,
      attributes: row.attributes || {},
    });
    completedByUser.set(key, list.slice(0, 50));
  }

  const eventsByUser = new Map();
  for (const row of events.rows) {
    const key = String(row.user_id);
    const list = eventsByUser.get(key) || [];
    list.push({
      eventName: row.event_name,
      properties: row.properties || {},
      occurredAt: row.occurred_at?.toISOString?.() ?? row.occurred_at,
    });
    eventsByUser.set(key, list.slice(0, 100));
  }

  return candidates.map((candidate) => ({
    ...candidate,
    applicationHistory: applicationsByUser.get(String(candidate.userId)) || [],
    completedJobs: completedByUser.get(String(candidate.userId)) || [],
    events: eventsByUser.get(String(candidate.userId)) || [],
  }));
}
