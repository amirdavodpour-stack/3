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
  assert.equal(out.exportVersion,'1.3');
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
    recommendationProfile:{resumeText:'My own resume text',skills:['Flutter']},
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

  assert.equal(out.account.email, 'a@b.c');
  assert.equal(out.recommendationProfile.resumeText, 'My own resume text');
  assert.deepEqual(out.recommendationProfile.skills, ['Flutter']);
  assert.equal(out.analyticsEvents[0].eventName, 'screen_view');
  assert.equal(out.analyticsEvents[0].properties.email_address, undefined);
  assert.equal(out.analyticsEvents[0].properties.phone_number, undefined);
  assert.equal(out.analyticsEvents[0].properties.safe_count, 7);
  assert.equal(out.crashReports[0].context.recipientName, undefined);
  assert.equal(out.crashReports[0].context.homeLocation, undefined);
  assert.equal(out.crashReports[0].context.coordinates, undefined);
  assert.equal(out.crashReports[0].context.safe, true);
});


test('data export redacts simple PII aliases from stored telemetry but preserves owned profile data and safe event metadata', () => {
  const telemetryFields = {
    name: 'Private Person',
    lat: 52.52,
    lng: 13.405,
    lon: 13.406,
    resumeText: 'Sensitive resume payload',
    documentUrl: 'https://private.invalid/resume.pdf',
    nested: {
      name: 'Nested Private Person',
      lat: 52.5,
      lng: 13.4,
      lon: 13.41,
      resumeText: 'Nested resume payload',
      documentUrl: 'https://private.invalid/nested.pdf',
      safe_count: 9,
    },
  };
  const out = buildDataExport({
    user: { id:'u10', email:'owner@example.com', displayName:'Owner', role:'USER', status:'ACTIVE', createdAt:'now' },
    recommendationProfile: { resumeText: 'The account holder\'s own resume', skills: ['Flutter'] },
    analyticsEvents: [{
      id:'a10',
      eventName:'screen_view',
      properties: { ...telemetryFields, eventName:'screen_view', safe_count:7, platform:'ANDROID' },
    }],
    crashReports: [{
      id:'c10',
      message:'crash',
      context: { ...telemetryFields, safe:true },
    }],
  });

  for (const payload of [out.analyticsEvents[0].properties, out.crashReports[0].context]) {
    for (const key of ['name', 'lat', 'lng', 'lon', 'resumeText', 'documentUrl']) {
      assert.equal(payload[key], undefined, `telemetry export should redact ${key}`);
      assert.equal(payload.nested[key], undefined, `telemetry export should recursively redact ${key}`);
    }
  }
  assert.equal(out.analyticsEvents[0].eventName, 'screen_view');
  assert.equal(out.analyticsEvents[0].properties.eventName, 'screen_view');
  assert.equal(out.analyticsEvents[0].properties.safe_count, 7);
  assert.equal(out.analyticsEvents[0].properties.platform, 'ANDROID');
  assert.equal(out.analyticsEvents[0].properties.nested.safe_count, 9);
  assert.equal(out.crashReports[0].context.safe, true);
  assert.equal(out.recommendationProfile.resumeText, 'The account holder\'s own resume');
  assert.deepEqual(out.recommendationProfile.skills, ['Flutter']);
});


test('account data export includes wallet snapshot, ledger entries, holds and payouts without internal provider/idempotency keys', () => {
  const out = buildDataExport({
    user: { id:'u11', email:'wallet-owner@example.com', displayName:'Wallet Owner', role:'USER', status:'ACTIVE', createdAt:'now' },
    walletAccounts: [{
      id:'wallet-11', currency:'TOMAN', availableBalance:'900', lockedBalance:'100',
      status:'ACTIVE', createdAt:'created', updatedAt:'updated',
    }],
    walletEntries: [{
      id:'entry-11', walletId:'wallet-11', entryType:'TRANSFER', direction:'CREDIT',
      amount:'40', currency:'TOMAN', referenceType:'WALLET_TRANSFER', referenceId:'transfer-11',
      financialOperationId:'operation-11', balanceAfter:'900',
      metadata:{ source:'api', idempotency_key:'private-key', nested:{ provider_ref:'private-ref', safe:true } },
      createdAt:'entry-created',
    }],
    walletHolds: [{
      id:'hold-11', walletId:'wallet-11', holdType:'PAYOUT_RESERVATION',
      referenceType:'PAYOUT', referenceId:'payout-11', financialOperationId:'operation-12',
      amount:'100', status:'RELEASED', createdAt:'hold-created', releasedAt:'hold-released',
    }],
    payouts: [{
      id:'payout-11', walletId:'wallet-11', amount:'100', currency:'TOMAN', provider:'internal',
      status:'SUCCEEDED', providerRef:'private-payout-ref', idempotencyKey:'private-payout-key',
      failureCode:null, createdAt:'payout-created', completedAt:'payout-completed',
    }],
  });

  assert.equal(out.exportVersion, '1.3');
  assert.equal(out.walletAccounts[0].availableBalance, '900');
  assert.equal(out.walletEntries[0].referenceType, 'WALLET_TRANSFER');
  assert.equal(out.walletEntries[0].metadata.idempotency_key, undefined);
  assert.equal(out.walletEntries[0].metadata.nested.provider_ref, undefined);
  assert.equal(out.walletEntries[0].metadata.nested.safe, true);
  assert.equal(out.walletHolds[0].holdType, 'PAYOUT_RESERVATION');
  assert.equal(out.payouts[0].status, 'SUCCEEDED');
  assert.equal(out.payouts[0].providerRef, undefined);
  assert.equal(out.payouts[0].idempotencyKey, undefined);
});

test('PostgreSQL privacy export selects only the current user wallet, ledger, hold and payout records', () => {
  const repository = readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8');
  assert.match(repository, /FROM wallet_accounts WHERE user_id=\$1/);
  assert.match(repository, /FROM wallet_entries e JOIN wallet_accounts w ON w\.id=e\.wallet_id WHERE w\.user_id=\$1/);
  assert.match(repository, /FROM wallet_holds h JOIN wallet_accounts w ON w\.id=h\.wallet_id WHERE w\.user_id=\$1/);
  assert.match(repository, /FROM payouts WHERE user_id=\$1/);
  for (const field of ['walletAccounts:', 'walletEntries:', 'walletHolds:', 'payouts:']) {
    assert.ok(repository.includes(field), 'privacy bundle must return ' + field);
  }
});

test('account deletion response reports the active privacy export version', () => {
  const route = readFileSync(path.join(ROOT, 'src/routes/account_routes.js'), 'utf8');
  assert.match(route, /import \{ PRIVACY_VERSION \} from '\.\.\/privacy\.js'/);
  assert.match(route, /privacyVersion:PRIVACY_VERSION/);
});


test('privacy export serializes PostgreSQL Date instances as ISO timestamps', () => {
  const createdAt = new Date('2026-10-30T01:02:03.000Z');
  const out = buildDataExport({
    user: { id:'u12', email:'date-owner@example.com', displayName:'Date Owner', role:'USER', status:'ACTIVE', createdAt },
    walletAccounts: [{
      id:'wallet-12', currency:'TOMAN', availableBalance:'50', lockedBalance:'0',
      status:'ACTIVE', createdAt, updatedAt:createdAt,
    }],
    walletEntries: [{
      id:'entry-12', walletId:'wallet-12', entryType:'TRANSFER', direction:'CREDIT',
      amount:'50', currency:'TOMAN', createdAt,
    }],
  });

  assert.equal(out.walletAccounts[0].createdAt, '2026-10-30T01:02:03.000Z');
  assert.equal(out.walletAccounts[0].updatedAt, '2026-10-30T01:02:03.000Z');
  assert.equal(out.walletEntries[0].createdAt, '2026-10-30T01:02:03.000Z');
});


test('privacy export explicitly reports top-level collections truncated by the 500-record safety cap', () => {
  const walletEntries = Array.from({ length: 501 }, (_, index) => ({
    id: `entry-${index}`, entryType:'TRANSFER', direction:'CREDIT', amount:String(index), currency:'TOMAN',
  }));
  const payouts = Array.from({ length: 501 }, (_, index) => ({
    id: `payout-${index}`, amount:'1', currency:'TOMAN', status:'SUCCEEDED',
  }));
  const out = buildDataExport({
    user: { id:'u13', email:'limit-owner@example.com', displayName:'Limit Owner', role:'USER', status:'ACTIVE', createdAt:'now' },
    walletEntries,
    payouts,
  });

  assert.equal(out.walletEntries.length, 500);
  assert.equal(out.payouts.length, 500);
  assert.deepEqual(out.exportLimits, {
    maxRecordsPerCollection: 500,
    truncatedTopLevelCollections: ['walletEntries', 'payouts'],
  });
});


test('account data export includes user-owned refund and settlement records without provider references', () => {
  const out = buildDataExport({
    user: { id:'u14', email:'payments-owner@example.com', displayName:'Payments Owner', role:'USER', status:'ACTIVE', createdAt:'now' },
    refunds: [{
      id:'refund-14', paymentId:'payment-14', amount:'130.33', currency:'USD', status:'REFUNDED',
      providerRef:'private-refund-ref', idempotencyKey:'private-refund-key',
      createdAt:new Date('2026-10-29T09:00:00.000Z'), updatedAt:new Date('2026-10-29T09:01:00.000Z'),
    }],
    settlements: [{
      id:'settlement-14', paymentId:'payment-15', amount:'100.25', currency:'USD', status:'RELEASED',
      providerRef:'private-release-ref',
      createdAt:new Date('2026-10-28T09:00:00.000Z'), updatedAt:new Date('2026-10-28T09:01:00.000Z'),
    }],
  });

  assert.equal(out.refunds[0].paymentId, 'payment-14');
  assert.equal(out.refunds[0].status, 'REFUNDED');
  assert.equal(out.refunds[0].currency, 'USD');
  assert.equal(out.refunds[0].providerRef, undefined);
  assert.equal(out.refunds[0].idempotencyKey, undefined);
  assert.equal(out.refunds[0].createdAt, '2026-10-29T09:00:00.000Z');
  assert.equal(out.settlements[0].status, 'RELEASED');
  assert.equal(out.settlements[0].providerRef, undefined);
});

test('PostgreSQL privacy export scopes refund and settlement rows through the current user payments', () => {
  const repository = readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8');
  assert.match(repository, /FROM refunds r JOIN payments p ON p\.id=r\.payment_id WHERE p\.payer_id=\$1 OR p\.payee_id=\$1/);
  assert.match(repository, /FROM settlements s JOIN payments p ON p\.id=s\.payment_id WHERE p\.payer_id=\$1 OR p\.payee_id=\$1/);
  assert.match(repository, /refunds: refunds\.rows/);
  assert.match(repository, /settlements: settlements\.rows/);
});


test('PostgreSQL privacy export reads every collection from one read-only repeatable-read snapshot', () => {
  const repository = readFileSync(path.join(ROOT, 'src/repository/privacy.js'), 'utf8');
  const bundle = repository.slice(
    repository.indexOf('export async function getUserPrivacyBundle'),
    repository.indexOf('export async function deleteUserPrivacyBundle'),
  );
  assert.match(bundle, /return withSqlTransaction\(async \(client\) => \{/);
  assert.match(bundle, /SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY/);
  assert.match(bundle, /client\.query\(/);
  assert.doesNotMatch(bundle, /pool\.query\(/);
});
