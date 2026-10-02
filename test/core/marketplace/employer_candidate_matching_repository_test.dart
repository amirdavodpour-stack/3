import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/marketplace/employer_candidate_matching_repository.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(this.response)
      : super(SecureStore(), baseUrl: 'http://127.0.0.1:3000/api/v1');

  final Object response;
  String? method;
  String? path;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    bool auth = false,
  }) async {
    this.method = method;
    this.path = path;
    return response;
  }
}

void main() {
  test('parses ranked employer candidate matches', () async {
    final api = FakeApiClient({
      'jobId': 'job-1',
      'kind': 'JOB',
      'candidateCount': 1,
      'candidates': [{
        'rank': 1,
        'userId': 'worker-1',
        'displayName': 'Worker 1',
        'score': 91.4,
        'matchReasons': ['SKILL_MATCH', 'EXPERIENCE_MATCH'],
        'matchComponents': {'skills': 100, 'experience': 90},
        'application': {
          'id': 'app-1',
          'status': 'PENDING',
          'resumeHighlights': 'Flutter developer',
          'skills': 'Flutter Dart',
        },
      }],
    });
    final repository = ApiEmployerCandidateMatchingRepository(api);

    final result = await repository.listForJob('job-1');

    expect(result.jobId, 'job-1');
    expect(result.kind, 'JOB');
    expect(result.candidates.single.rank, 1);
    expect(result.candidates.single.score, 91.4);
    expect(result.candidates.single.applicationId, 'app-1');
    expect(result.candidates.single.reasons, ['SKILL_MATCH', 'EXPERIENCE_MATCH']);
  });

  test('uses authenticated candidate-match endpoint', () async {
    final api = FakeApiClient({
      'jobId': 'mission-1',
      'kind': 'MISSION',
      'candidateCount': 0,
      'candidates': [],
    });
    final repository = ApiEmployerCandidateMatchingRepository(api);

    await repository.listForJob('mission-1');

    expect(api.method, 'GET');
    expect(api.path, '/jobs/mission-1/candidate-matches');
  });

  test('ignores malformed candidate rows', () async {
    final repository = ApiEmployerCandidateMatchingRepository(FakeApiClient({
      'jobId': 'job-1',
      'kind': 'JOB',
      'candidateCount': 2,
      'candidates': [
        null,
        {'rank': 1, 'userId': 'worker-1', 'displayName': 'Worker', 'score': 80},
      ],
    }));

    final result = await repository.listForJob('job-1');

    expect(result.candidates, hasLength(1));
  });
}
