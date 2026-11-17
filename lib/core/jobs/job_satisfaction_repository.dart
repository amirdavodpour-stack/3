import '../network/api_client.dart';

class HopeJobSatisfaction {
  const HopeJobSatisfaction({
    required this.id,
    required this.jobId,
    required this.userId,
    required this.role,
    required this.overallRating,
    required this.completedAsAgreed,
    required this.communicationRating,
    required this.reportText,
    required this.aiSummary,
    required this.aiSatisfactionScore,
    required this.aiSentiment,
    required this.status,
  });

  final String id;
  final String jobId;
  final String userId;
  final String role;
  final int overallRating;
  final bool completedAsAgreed;
  final int communicationRating;
  final String reportText;
  final String aiSummary;
  final int aiSatisfactionScore;
  final String aiSentiment;
  final String status;

  factory HopeJobSatisfaction.fromMap(Map<String, dynamic> map) =>
      HopeJobSatisfaction(
        id: '${map['id'] ?? ''}',
        jobId: '${map['jobId'] ?? ''}',
        userId: '${map['userId'] ?? ''}',
        role: '${map['role'] ?? ''}'.toUpperCase(),
        overallRating: int.tryParse('${map['overallRating'] ?? 0}') ?? 0,
        completedAsAgreed: map['completedAsAgreed'] == true,
        communicationRating:
            int.tryParse('${map['communicationRating'] ?? 0}') ?? 0,
        reportText: '${map['reportText'] ?? ''}',
        aiSummary: '${map['aiSummary'] ?? ''}',
        aiSatisfactionScore:
            int.tryParse('${map['aiSatisfactionScore'] ?? 0}') ?? 0,
        aiSentiment: '${map['aiSentiment'] ?? 'NEEDS_REVIEW'}',
        status: '${map['status'] ?? 'UNKNOWN'}',
      );
}

class JobSatisfactionState {
  const JobSatisfactionState({
    required this.jobId,
    required this.role,
    required this.questions,
    required this.submitted,
    required this.feedback,
    required this.submittedCount,
    required this.requiredCount,
    required this.dispute,
  });

  final String jobId;
  final String role;
  final List<Map<String, dynamic>> questions;
  final bool submitted;
  final HopeJobSatisfaction? feedback;
  final int submittedCount;
  final int requiredCount;
  final Map<String, dynamic>? dispute;

  factory JobSatisfactionState.fromMap(Map<String, dynamic> map) {
    final rawQuestions = map['questions'];
    final rawFeedback = map['feedback'];
    final progress = map['progress'];
    return JobSatisfactionState(
      jobId: '${map['jobId'] ?? ''}',
      role: '${map['role'] ?? ''}',
      questions: (rawQuestions is List ? rawQuestions : const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false),
      submitted: map['submitted'] == true,
      feedback: rawFeedback is Map
          ? HopeJobSatisfaction.fromMap(Map<String, dynamic>.from(rawFeedback))
          : null,
      submittedCount: progress is Map
          ? int.tryParse('${progress['submittedCount'] ?? 0}') ?? 0
          : 0,
      requiredCount: progress is Map
          ? int.tryParse('${progress['requiredCount'] ?? 2}') ?? 2
          : 2,
      dispute: map['dispute'] is Map
          ? Map<String, dynamic>.from(map['dispute'] as Map)
          : null,
    );
  }
}

abstract interface class JobSatisfactionRepository {
  Future<JobSatisfactionState> getState(String jobId);

  Future<Map<String, dynamic>> submit({
    required String jobId,
    required int overallRating,
    required bool completedAsAgreed,
    required int communicationRating,
    required String report,
  });

  Future<List<HopeJobSatisfaction>> history();
}

class ApiJobSatisfactionRepository implements JobSatisfactionRepository {
  const ApiJobSatisfactionRepository(this._api);
  final ApiClient _api;

  String _id(String jobId) => Uri.encodeComponent(jobId);

  @override
  Future<JobSatisfactionState> getState(String jobId) async {
    final raw = await _api.request(
      'GET',
      '/jobs/${_id(jobId)}/satisfaction',
      auth: true,
    );
    return JobSatisfactionState.fromMap(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  @override
  Future<Map<String, dynamic>> submit({
    required String jobId,
    required int overallRating,
    required bool completedAsAgreed,
    required int communicationRating,
    required String report,
  }) async {
    final raw = await _api.request(
      'POST',
      '/jobs/${_id(jobId)}/satisfaction',
      auth: true,
      body: {
        'overallRating': overallRating,
        'completedAsAgreed': completedAsAgreed,
        'communicationRating': communicationRating,
        'report': report.trim(),
      },
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<List<HopeJobSatisfaction>> history() async {
    final raw = await _api.request(
      'GET',
      '/jobs/satisfaction-history',
      auth: true,
    );
    final map = Map<String, dynamic>.from(raw as Map);
    final values = map['history'];
    return values is List
        ? values
            .whereType<Map>()
            .map(
              (item) => HopeJobSatisfaction.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const [];
  }
}
