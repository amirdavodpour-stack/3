import { readFileSync } from 'node:fs';
import path from 'node:path';
const ROOT = path.resolve(new URL('..', import.meta.url).pathname);
import test from 'node:test';
import assert from 'node:assert/strict';
import { sanitizeTelemetryProperties, anonymizedEmail, buildDataExport } from '../src/privacy.js';
import { normalizeCrash } from '../src/analytics.js';

test('privacy sanitizer removes direct identifiers and bounds long strings', () => {
  const value = sanitizeTelemetryProperties({email:'a@b.c',name:'Alice',ok:true,description:'x'.repeat(500)});
  assert.equal(value.email, undefined);
  assert.equal(value.name, undefined);
  assert.equal(value.ok, true);
  assert.equal(value.description.length, 200);
});

test('deleted email is non-routable and deterministic per user', () => {
  assert.match(anonymizedEmail('abc-123'), /^deleted\+abc-123@invalid\.local$/);
});

test('data export omits payment credentials', () => {
  const out=buildDataExport({user:{id:'u1',email:'a@b.c',displayName:'A',role:'USER',status:'ACTIVE',createdAt:'now'}});
  assert.equal(out.exportVersion,'1.2');
  assert.deepEqual(out.evidence,[]);
  assert.deepEqual(out.uploads,[]);
  assert.ok(!('providerRef' in (out.payments[0] || {})));
});


test('password reset delivery never logs the reset token', () => {
  const source = readFileSync(path.join(ROOT, 'src/services/session.js'), 'utf8');
  assert.ok(source.includes("action: 'PASSWORD_RESET_DELIVERY'"));
  const segment = source.slice(source.indexOf("action: 'PASSWORD_RESET_DELIVERY'"), source.indexOf("return;", source.indexOf("action: 'PASSWORD_RESET_DELIVERY'")));
  assert.doesNotMatch(segment, /token\s*[,}]/);
});


test('PostgreSQL privacy export selects the notifications schema columns', () => {
  const repository = [
    readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8'),
    readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8'),
  ].join('\n');
  assert.match(repository, /SELECT id,type,title,body,created_at,read_at FROM notifications WHERE user_id=\$1/);
  assert.doesNotMatch(repository, /SELECT id,type,title,message,created_at,read_at FROM notifications/);
  assert.match(repository, /notifications:n\.rows\.map\(r=>\(\{id:r\.id,type:r\.type,title:r\.title,body:r\.body/);
});


test('data export contract uses body for notifications', () => {
  const out=buildDataExport({
    user:{id:'u2',email:'a@b.c',displayName:'A',role:'USER',status:'ACTIVE',createdAt:'now'},
    notifications:[{id:'n1',type:'TEST',title:'Title',body:'Body',createdAt:'now',readAt:null}],
  });
  assert.deepEqual(out.notifications, [{id:'n1',type:'TEST',title:'Title',body:'Body',createdAt:'now',readAt:null}]);
  assert.equal(out.notifications[0].message, undefined);
});


test('data export includes user-owned telemetry and trust reports', () => {
  const out=buildDataExport({
    user:{id:'u3',email:'a@b.c',displayName:'A',role:'USER',status:'ACTIVE',createdAt:'now'},
    analyticsEvents:[{id:'a1',eventName:'screen_view',userId:'u3'}],
    crashReports:[{id:'c1',fingerprint:'fp',message:'boom',userId:'u3'}],
    trustReports:[{id:'t1',reporterId:'u3',entityType:'USER',entityId:'u4',reason:'spam',status:'OPEN'}],
  });
  assert.equal(out.analyticsEvents.length,1);
  assert.equal(out.crashReports.length,1);
  assert.equal(out.trustReports.length,1);
});


test('data export strips internal payment and telemetry transport fields recursively', () => {
  const out=buildDataExport({
    user:{id:'u4',email:'a@b.c',displayName:'A',role:'USER',status:'ACTIVE',createdAt:'now'},
    payments:[{id:'p1',amount:10,providerRef:'secret-ref',idempotencyKey:'secret-key'}],
    analyticsEvents:[{id:'a1',eventName:'x',dedupeKey:'internal-dedupe',properties:{iban:'secret',ok:true}}],
    crashReports:[{id:'c1',message:'boom',stack:'stack',context:{token:'secret',safe:true}}],
    provider:{id:'pr1',providerRef:'secret-provider',verificationStatus:'VERIFIED'},
  });
  assert.equal(out.payments[0].providerRef, undefined);
  assert.equal(out.payments[0].idempotencyKey, undefined);
  assert.equal(out.analyticsEvents[0].dedupeKey, undefined);
  assert.equal(out.analyticsEvents[0].properties.iban, undefined);
  assert.equal(out.analyticsEvents[0].properties.ok, true);
  assert.equal(out.crashReports[0].context.token, undefined);
  assert.equal(out.provider.providerRef, undefined);
});

test("data export includes the user recommendation profile and satisfaction history", () => {
  const out = buildDataExport({
    user: { id: 'u5', email: 'a@b.c', displayName: 'A', role: 'USER', status: 'ACTIVE', createdAt: 'now' },
    recommendationProfile: {
      onboardingCompleted: true,
      resumeText: 'User-authored resume text',
      skills: ['Flutter', 'SQL'],
      preferredCities: ['Berlin'],
    },
    satisfactionHistory: [{
      id: 's1',
      jobId: 'j1',
      userId: 'u5',
      role: 'WORKER',
      overallRating: 5,
      reportText: 'User-authored satisfaction feedback',
      status: 'SUBMITTED',
    }],
  });

  assert.deepEqual(out.recommendationProfile, {
    onboardingCompleted: true,
    resumeText: 'User-authored resume text',
    skills: ['Flutter', 'SQL'],
    preferredCities: ['Berlin'],
  });
  assert.deepEqual(out.satisfactionHistory, [{
    id: 's1',
    jobId: 'j1',
    userId: 'u5',
    role: 'WORKER',
    overallRating: 5,
    reportText: 'User-authored satisfaction feedback',
    status: 'SUBMITTED',
  }]);
});


test("privacy export strips snake_case credential aliases recursively", () => {
  const out = buildDataExport({
    user: { id:'u6', email:'a@b.c', displayName:'A', role:'USER', status:'ACTIVE', createdAt:'now' },
    crashReports: [{
      id:'c2',
      message:'boom',
      context:{
        refresh_token:'secret-refresh',
        nested:{ password_hash:'secret-password', safe:true },
      },
    }],
    analyticsEvents:[{
      id:'a2',
      eventName:'diagnostic',
      properties:{ provider_ref:'internal-reference', idempotency_key:'private-key', ok:true },
    }],
  });

  assert.equal(out.crashReports[0].context.refresh_token, undefined);
  assert.equal(out.crashReports[0].context.nested.password_hash, undefined);
  assert.equal(out.analyticsEvents[0].properties.provider_ref, undefined);
  assert.equal(out.analyticsEvents[0].properties.idempotency_key, undefined);
  assert.equal(out.crashReports[0].context.nested.safe, true);
  assert.equal(out.analyticsEvents[0].properties.ok, true);
});


test('privacy export does not return deep objects unsanitized', () => {
  const out = buildDataExport({
    user: { id:'u7', email:'a@b.c', displayName:'A', role:'USER', status:'ACTIVE', createdAt:'now' },
    crashReports: [{
      id:'c3',
      context:{ level1:{ level2:{ level3:{ level4:{ refresh_token:'secret-too-deep' } } } } },
    }],
  });

  assert.equal(out.crashReports[0].context.level1.level2.level3, null);
});

test('telemetry sanitizer normalizes identifier and credential aliases', () => {
  const out = sanitizeTelemetryProperties({
    email_address:'private@example.com',
    phone_number:'+49 151 00000000',
    refresh_token:'secret-refresh',
    safe_count:3,
  });

  assert.equal(out.email_address, undefined);
  assert.equal(out.phone_number, undefined);
  assert.equal(out.refresh_token, undefined);
  assert.equal(out.safe_count, 3);
});


test('account deletion removes recommendation profile data', () => {
  const repository = readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8');
  const deletion = repository.slice(repository.indexOf('export async function deleteUserPrivacyBundle'));
  assert.match(deletion, /DELETE FROM recommendation_profiles WHERE user_id=\$1/);
});


test('data export includes user-owned saved searches', () => {
  const out = buildDataExport({
    user: { id:'u8', email:'a@b.c', displayName:'A', role:'USER', status:'ACTIVE', createdAt:'now' },
    savedSearches: [{
      id:'search-1',
      name:'Remote Flutter',
      query:'Flutter',
      kind:'JOB',
      visibility:'ALL',
      city:'Berlin',
      category:'Software',
      createdAt:'now',
      updatedAt:'now',
    }],
  });

  assert.deepEqual(out.savedSearches, [{
    id:'search-1',
    name:'Remote Flutter',
    query:'Flutter',
    kind:'JOB',
    visibility:'ALL',
    city:'Berlin',
    category:'Software',
    createdAt:'now',
    updatedAt:'now',
  }]);
});

test('PostgreSQL privacy export and deletion handle saved searches', () => {
  const repository = readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8');
  const deletion = repository.slice(repository.indexOf('export async function deleteUserPrivacyBundle'));
  assert.match(repository, /SELECT \* FROM saved_searches WHERE user_id=\$1 ORDER BY updated_at DESC/);
  assert.match(repository, /savedSearches: savedSearches\.rows/);
  assert.match(deletion, /DELETE FROM saved_searches WHERE user_id=\$1/);
});

test('legacy privacy export and deletion handle saved searches', () => {
  const legacy = readFileSync(path.join(ROOT, 'src/application/legacy/account_legacy.js'), 'utf8');
  assert.match(legacy, /savedSearches: db\.collection\.savedSearches\.filter/);
  assert.match(legacy, /db\.collection\.savedSearches = db\.collection\.savedSearches\.filter/);
  assert.match(legacy, /db\.touch\([^)]*savedSearches/);
});


test('telemetry sanitizers redact compound field-name aliases in crash context', () => {
  const telemetry = sanitizeTelemetryProperties({
    recipientName: 'Private Person',
    homeLocation: 'Berlin',
    lat: 52.52,
    platform: 'ANDROID',
    safeCount: 3,
  });
  assert.equal(telemetry.recipientName, undefined);
  assert.equal(telemetry.homeLocation, undefined);
  assert.equal(telemetry.lat, undefined);
  assert.equal(telemetry.platform, 'ANDROID');
  assert.equal(telemetry.safeCount, 3);

  const crash = normalizeCrash({
    message: 'crash report',
    fingerprint: 'crash-pii-1234',
    platform: 'WEB',
    context: {
      recipientName: 'Private Person',
      homeLocation: 'Berlin',
      coordinates: { latitude: 52.52, longitude: 13.405 },
      nested: { email_address: 'private@example.com', safe: true },
    },
  });
  assert.equal(crash.context.recipientName, undefined);
  assert.equal(crash.context.homeLocation, undefined);
  assert.equal(crash.context.coordinates, undefined);
  assert.equal(crash.context.nested.email_address, undefined);
  assert.equal(crash.context.nested.safe, true);
});


test('account deletion removes user-only chat state', () => {
  const repository = readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8');
  const deletion = repository.slice(repository.indexOf('export async function deleteUserPrivacyBundle'));
  const tables = deletion.match(/const tables = \[([^\]]+)\]/s)?.[1] || '';
  for (const table of ['chat_presence', 'chat_conversation_preferences', 'chat_message_reads']) {
    assert.match(tables, new RegExp("'" + table + "'"));
  }
});


test('account deletion erases applicant resume content while retaining application history', () => {
  const repository = readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8');
  const deletion = repository.slice(repository.indexOf('export async function deleteUserPrivacyBundle'));
  assert.match(deletion, /UPDATE job_applications SET resume_text='', skills='' WHERE candidate_id=\$1/);

  const legacy = readFileSync(path.join(ROOT, 'src/application/legacy/account_legacy.js'), 'utf8');
  const legacyDeletion = legacy.slice(legacy.indexOf('async deleteUserPrivacyBundle'));
  assert.match(legacyDeletion, /x\.resumeText = ''; x\.skills = ''/);
  assert.match(legacyDeletion, /'jobApplications'/);
});


test('account deletion strips pseudonymous telemetry identifiers and raw crash payloads', () => {
  const repository = readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8');
  const deletion = repository.slice(repository.indexOf('export async function deleteUserPrivacyBundle'));
  assert.match(deletion, /UPDATE analytics_events SET user_id=NULL, anonymous_id=NULL, session_id=NULL, properties='\{\}'::jsonb, dedupe_key=NULL WHERE user_id=\$1/);
  assert.match(deletion, /UPDATE crash_reports SET user_id=NULL, anonymous_id=NULL, message='\[REDACTED\]', stack=NULL, context='\{\}'::jsonb WHERE user_id=\$1/);
});


test('data export redacts compound PII aliases in stored telemetry recursively', () => {
  const out = buildDataExport({
    user: { id:'u9', email:'a@b.c', displayName:'A', role:'USER', status:'ACTIVE', createdAt:'now' },
    analyticsEvents: [{
      id:'a9',
      eventName:'screen_view',
      properties:{ email_address:'private@example.com', phone_number:'+491234567', safe_count:7 },
    }],
    crashReports: [{
      id:'c9',
      message:'crash',
      context:{
        recipientName:'Private Person',
        homeLocation:'Berlin',
        coordinates:{latitude:52.52,longitude:13.405},
        safe:true,
      },
    }],
  });

  assert.equal(out.analyticsEvents[0].properties.email_address, undefined);
  assert.equal(out.analyticsEvents[0].properties.phone_number, undefined);
  assert.equal(out.analyticsEvents[0].properties.safe_count, 7);
  assert.equal(out.crashReports[0].context.recipientName, undefined);
  assert.equal(out.crashReports[0].context.homeLocation, undefined);
  assert.equal(out.crashReports[0].context.coordinates, undefined);
  assert.equal(out.crashReports[0].context.safe, true);
});
