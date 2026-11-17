import { requirePool } from './context.js';

const listValue = (value) =>
  Array.isArray(value)
    ? value.filter((item) => typeof item === 'string').slice(0, 40)
    : [];

function fromRow(row) {
  return {
    userId: row.user_id,
    resumeText: row.resume_text || '',
    skills: listValue(row.skills),
    interests: listValue(row.interests),
    preferredCategories: listValue(row.preferred_categories),
    preferredCities: listValue(row.preferred_cities),
    desiredKinds: listValue(row.desired_kinds),
    workMode: row.work_mode || null,
    availability: row.availability || null,
    salaryMin: row.salary_min == null ? null : String(row.salary_min),
    salaryMax: row.salary_max == null ? null : String(row.salary_max),
    experienceLevel: row.experience_level || null,
    goals: row.goals || '',
    onboardingCompleted: row.onboarding_completed === true,
    sourceVersion: row.source_version || '1.0',
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
    updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at,
  };
}

export async function getRecommendationProfile(userId) {
  const { rows } = await requirePool().query(
    'SELECT * FROM recommendation_profiles WHERE user_id=$1',
    [userId],
  );
  return rows[0] ? fromRow(rows[0]) : null;
}

export async function upsertRecommendationProfile(userId, profile) {
  const { rows } = await requirePool().query(
    `INSERT INTO recommendation_profiles(
      user_id,resume_text,skills,interests,preferred_categories,preferred_cities,
      desired_kinds,work_mode,availability,salary_min,salary_max,experience_level,
      goals,onboarding_completed,source_version,updated_at
    ) VALUES(
      $1,$2,$3::jsonb,$4::jsonb,$5::jsonb,$6::jsonb,$7::jsonb,$8,$9,$10,$11,$12,
      $13,$14,$15,NOW()
    )
    ON CONFLICT(user_id) DO UPDATE SET
      resume_text=EXCLUDED.resume_text,
      skills=EXCLUDED.skills,
      interests=EXCLUDED.interests,
      preferred_categories=EXCLUDED.preferred_categories,
      preferred_cities=EXCLUDED.preferred_cities,
      desired_kinds=EXCLUDED.desired_kinds,
      work_mode=EXCLUDED.work_mode,
      availability=EXCLUDED.availability,
      salary_min=EXCLUDED.salary_min,
      salary_max=EXCLUDED.salary_max,
      experience_level=EXCLUDED.experience_level,
      goals=EXCLUDED.goals,
      onboarding_completed=EXCLUDED.onboarding_completed,
      source_version=EXCLUDED.source_version,
      updated_at=NOW()
    RETURNING *`,
    [
      userId,
      profile.resumeText || '',
      JSON.stringify(profile.skills || []),
      JSON.stringify(profile.interests || []),
      JSON.stringify(profile.preferredCategories || []),
      JSON.stringify(profile.preferredCities || []),
      JSON.stringify(profile.desiredKinds || []),
      profile.workMode || null,
      profile.availability || null,
      profile.salaryMin == null ? null : profile.salaryMin,
      profile.salaryMax == null ? null : profile.salaryMax,
      profile.experienceLevel || null,
      profile.goals || '',
      profile.onboardingCompleted === true,
      profile.sourceVersion || '1.0',
    ],
  );
  return fromRow(rows[0]);
}

export async function listRecommendationEvents(userId, limit = 120) {
  const size = Math.min(Math.max(Number(limit) || 120, 1), 300);
  const { rows } = await requirePool().query(
    `SELECT event_name, properties, occurred_at
       FROM analytics_events
      WHERE user_id=$1
        AND event_name IN (
          'search_viewed',
          'opportunity_viewed',
          'application_submitted',
          'application_withdrawn',
          'recommendation_served'
        )
      ORDER BY occurred_at DESC
      LIMIT $2`,
    [userId, size],
  );
  return rows.map((row) => ({
    eventName: row.event_name,
    properties: row.properties || {},
    occurredAt: row.occurred_at?.toISOString?.() ?? row.occurred_at,
  }));
}

export async function listProviderWorkHistory(userId, limit = 50) {
  const size = Math.min(Math.max(Number(limit) || 50, 1), 100);
  const { rows } = await requirePool().query(
    `SELECT *
       FROM jobs
      WHERE provider_id=$1
        AND status IN ('COMPLETED','SETTLED')
      ORDER BY updated_at DESC
      LIMIT $2`,
    [userId, size],
  );
  return rows;
}
