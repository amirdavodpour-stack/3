import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/admin/admin_repository.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';

import '../../support/fake_api_server.dart';

void _installStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : const <String, dynamic>{};
    if (call.method == 'read' && args['key'] == 'hope.access_token') {
      return 'token';
    }
    return null;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeApiServer server;
  late ApiAdminRepository repository;
  setUp(() async {
    _installStorage();
    server = await FakeApiServer.start();
    repository =
        ApiAdminRepository(ApiClient(SecureStore(), baseUrl: server.baseUrl));
  });
  tearDown(() => server.close());

  test('summary converts numeric strings and numbers consistently', () async {
    server.handlers['/admin/summary'] = (request, body) async {
      await respondJson(request, 200, {
        'data': {'users': '12', 'jobs': 7.9}
      });
    };
    final summary = await repository.getSummary();
    expect(summary['users'], 12);
    expect(summary['jobs'], 7);
    expect(summary['missing'], 0);
  });

  test('admin list endpoints ignore malformed non-map items', () async {
    server.handlers['/admin/users'] = (request, body) async {
      await respondJson(request, 200, {
        'data': [
          {'id': 'u1', 'displayName': 'A', 'email': 'a@example.com'},
          'bad',
        ]
      });
    };
    final users = await repository.listUsers();
    expect(users, hasLength(1));
    expect(users.single.id, 'u1');
  });

  test('moderateJob sends the requested status', () async {
    server.handlers['/admin/jobs/j1/moderate'] = (request, body) async {
      expect(body['status'], 'APPROVED');
      await respondJson(request, 200, {});
    };
    await repository.moderateJob('j1', 'APPROVED');
  });

  test('setUserStatus sends reason and bounded review deadline', () async {
    server.handlers['/admin/users/u1/status'] = (request, body) async {
      expect(body['status'], 'SUSPENDED');
      expect(body['reason'], 'Reasoned temporary restriction');
      expect(body['reviewDueAt'], '2026-11-09T12:00:00.000Z');
      await respondJson(request, 200, {});
    };
    await repository.setUserStatus('u1', 'SUSPENDED', reason: 'Reasoned temporary restriction', reviewDueAt: DateTime.utc(2026, 11, 9, 12));
  });

  test('deleteJob uses DELETE and authentication', () async {
    server.handlers['/admin/jobs/j1'] = (request, body) async {
      expect(request.method, 'DELETE');
      expect(request.headers.value('authorization'), 'Bearer token');
      await respondJson(request, 200, {});
    };
    await repository.deleteJob('j1');
  });

  test('event reconciliation repository sends an authenticated paginated GET', () async {
    server.handlers['/admin/reconciliation-cases/outbox-events'] = (request, body) async {
      expect(request.method, 'GET');
      expect(request.uri.queryParameters['limit'], '25');
      expect(request.uri.queryParameters['cursor'], 'opaque cursor+/=');
      expect(request.headers.value('authorization'), 'Bearer token');
      await respondJson(request, 200, {
        'data': {
          'cases': [
            {
              'id': 'case-1',
              'resourceType': 'outbox_event',
              'severity': 'CRITICAL',
            },
            'malformed',
          ],
          'hasMore': true,
          'nextCursor': 'next-cursor',
        },
      });
    };

    final page = await repository.listActiveOutboxEventReconciliationCases(
      limit: 25,
      cursor: 'opaque cursor+/=',
    );

    expect(page['cases'], hasLength(1));
    expect((page['cases'] as List).single['id'], 'case-1');
    expect(page['hasMore'], isTrue);
    expect(page['nextCursor'], 'next-cursor');
  });


  test('event investigation history repository sends an authenticated case-scoped paginated GET', () async {
    server.handlers['/admin/reconciliation-cases/outbox-events/case-01/investigation-notes'] = (request, body) async {
      expect(request.method, 'GET');
      expect(request.uri.queryParameters['limit'], '1');
      expect(request.uri.queryParameters['cursor'], 'opaque history cursor+/=');
      expect(request.headers.value('authorization'), 'Bearer token');
      await respondJson(request, 200, {
        'data': {
          'notes': [
            {'id':'note-1','reason':'Verified mismatch','actorDisplayName':'Primary Admin'},
            'malformed',
          ],
          'hasMore': true,
          'nextCursor': 'next-history-cursor',
        },
      });
    };

    final page = await repository.listOutboxEventReconciliationNotes(
      'case-01',
      limit: 1,
      cursor: 'opaque history cursor+/=',
    );

    expect(page['notes'], hasLength(1));
    expect((page['notes'] as List).single['id'], 'note-1');
    expect(page['hasMore'], isTrue);
    expect(page['nextCursor'], 'next-history-cursor');
  });

  test('event investigation history repository safely handles malformed payloads', () async {
    server.handlers['/admin/reconciliation-cases/outbox-events/case-01/investigation-notes'] = (request, body) async {
      await respondJson(request, 200, {'data': 'unexpected'});
    };
    final page = await repository.listOutboxEventReconciliationNotes('case-01');
    expect(page['notes'], isEmpty);
    expect(page['hasMore'], isFalse);
    expect(page['nextCursor'], isNull);
  });

  test('event investigation note repository posts evidence fields with authentication', () async {
    server.handlers['/admin/reconciliation-cases/outbox-events/case-01/investigation-notes'] = (request, body) async {
      expect(request.method, 'POST');
      expect(request.headers.value('authorization'), 'Bearer token');
      expect(body['reason'], 'Confirmed event mismatch after independent reconciliation.');
      expect(body['evidenceReference'], 'incident:outbox-case-01');
      expect(body['verification'], {
        'eventIdentity':'MISMATCH_CONFIRMED',
        'canonicalPayout':'NOT_VERIFIED',
        'providerOutcome':'NOT_CHECKED',
      });
      expect(body['idempotencyKey'], 'event-note-test-idempotency-01');
      await respondJson(request, 200, {
        'data': {
          'action':'INVESTIGATION_NOTE_ADDED',
          'caseStatus':'INVESTIGATING',
          'replayed':false,
        },
      });
    };

    final result = await repository.appendOutboxEventReconciliationNote(
      'case-01',
      reason: 'Confirmed event mismatch after independent reconciliation.',
      evidenceReference: 'incident:outbox-case-01',
      verification: const {
        'eventIdentity':'MISMATCH_CONFIRMED',
        'canonicalPayout':'NOT_VERIFIED',
        'providerOutcome':'NOT_CHECKED',
      },
      idempotencyKey: 'event-note-test-idempotency-01',
    );
    expect(result['action'], 'INVESTIGATION_NOTE_ADDED');
    expect(result['caseStatus'], 'INVESTIGATING');
  });

  test('event reconciliation repository returns a safe empty page for malformed payloads', () async {
    server.handlers['/admin/reconciliation-cases/outbox-events'] = (request, body) async {
      await respondJson(request, 200, {'data': 'unexpected'});
    };

    final page = await repository.listActiveOutboxEventReconciliationCases();

    expect(page['cases'], isEmpty);
    expect(page['hasMore'], isFalse);
    expect(page['nextCursor'], isNull);
  });

  test('event attestation repository posts the reviewed snapshot and source provenance', () async {
    server.handlers['/admin/reconciliation-cases/outbox-events/case-01/investigation-attestations'] = (request, body) async {
      expect(request.method, 'POST');
      expect(request.headers.value('authorization'), 'Bearer token');
      expect(body['action'], 'INVESTIGATION_ATTESTATION_RECORDED');
      expect(body['sourceType'], 'PROVIDER_ARTIFACT');
      expect(body['issuer'], 'Example Provider');
      expect(body['evidenceReference'], 'provider-case:case-01');
      expect(body['artifactSha256'], 'a' * 64);
      expect(body['sourceObservedAt'], '2026-11-15T19:00:00.000Z');
      expect(body['reviewedCaseDigest'], 'b' * 64);
      expect(body['verification'], {
        'eventIdentity': {
          'result':'MISMATCH_CONFIRMED',
          'verificationLevel':'SOURCE_ARTIFACT_REVIEWED',
        },
        'canonicalPayout': {
          'result':'NOT_VERIFIED',
          'verificationLevel':'NOT_CHECKED',
        },
        'providerOutcome': {
          'result':'NOT_CHECKED',
          'verificationLevel':'NOT_CHECKED',
        },
      });
      expect(body['idempotencyKey'], 'attestation-test-key-01');
      await respondJson(request, 200, {
        'data': {
          'action':'INVESTIGATION_ATTESTATION_RECORDED',
          'caseStatus':'INVESTIGATING',
          'replayed':false,
        },
      });
    };

    final result = await repository.recordOutboxEventReconciliationAttestation(
      'case-01',
      action:'INVESTIGATION_ATTESTATION_RECORDED',
      reason:'The event identity was compared with source evidence.',
      sourceType:'PROVIDER_ARTIFACT',
      issuer:'Example Provider',
      evidenceReference:'provider-case:case-01',
      artifactSha256:'A' * 64,
      sourceObservedAt:'2026-11-15T19:00:00.000Z',
      verification:const {
        'eventIdentity': {
          'result':'MISMATCH_CONFIRMED',
          'verificationLevel':'SOURCE_ARTIFACT_REVIEWED',
        },
        'canonicalPayout': {
          'result':'NOT_VERIFIED',
          'verificationLevel':'NOT_CHECKED',
        },
        'providerOutcome': {
          'result':'NOT_CHECKED',
          'verificationLevel':'NOT_CHECKED',
        },
      },
      reviewedCaseDigest:'B' * 64,
      idempotencyKey:'attestation-test-key-01',
    );

    expect(result['action'], 'INVESTIGATION_ATTESTATION_RECORDED');
    expect(result['caseStatus'], 'INVESTIGATING');
  });
}
