import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/opportunity/opportunity_agent_repository.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(this.response)
      : super(SecureStore(), baseUrl: 'http://127.0.0.1:3000/api/v1');

  final Object response;
  String? method;
  String? path;
  bool? auth;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    bool auth = false,
  }) async {
    this.method = method;
    this.path = path;
    this.auth = auth;
    return response;
  }
}

void main() {
  test('ApiOpportunityAgentRepository loads authenticated next actions', () async {
    final repository = ApiOpportunityAgentRepository(FakeApiClient({
      'version': '1.0',
      'profileCompleteness': {
        'score': 0.75,
        'missing': ['goals'],
        'onboardingCompleted': true,
      },
      'activity': {
        'savedSearches': 2,
        'views': 3,
        'applications': 1,
        'completedJobs': 4,
      },
      'automationPolicy': {
        'automatic': ['DISCOVER', 'RANK', 'EXPLAIN', 'LEARN'],
        'approvalRequired': ['PREPARE_APPLICATION', 'APPLY'],
      },
      'actions': [{
        'type': 'PREPARE_APPLICATION',
        'title': 'Flutter developer',
        'jobId': 'job-1',
        'score': 91,
        'reasons': ['SKILL_MATCH'],
        'requiresApproval': true,
      }],
    }));

    final state = await repository.getState();

    expect(state.actions, hasLength(1));
    expect(state.actions.first.type, 'PREPARE_APPLICATION');
    expect(state.actions.first.requiresApproval, isTrue);
  });

  test('repository uses the authenticated opportunity-agent endpoint', () async {
    final api = FakeApiClient({'actions': []});
    final repository = ApiOpportunityAgentRepository(api);

    await repository.getState();

    expect(api.method, 'GET');
    expect(api.path, '/opportunity-agent');
    expect(api.auth, isTrue);
  });

  test('repository tolerates malformed action entries', () async {
    final repository = ApiOpportunityAgentRepository(FakeApiClient({
      'actions': [
        null,
        {'type': '', 'title': ''},
        {'type': 'REVIEW_OPPORTUNITY', 'title': 'Review this'},
      ],
    }));

    final state = await repository.getState();

    expect(state.actions.map((action) => action.type), ['REVIEW_OPPORTUNITY']);
  });
}
