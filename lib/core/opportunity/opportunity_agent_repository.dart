import '../network/api_client.dart';

class HopeOpportunityAgentAction {
  const HopeOpportunityAgentAction({
    required this.type,
    required this.title,
    this.reason,
    this.jobId,
    this.applicationId,
    this.score,
    this.ageDays,
    this.reasons = const [],
    this.missingFields = const [],
    this.requiresApproval = false,
  });

  final String type;
  final String title;
  final String? reason;
  final String? jobId;
  final String? applicationId;
  final double? score;
  final int? ageDays;
  final List<String> reasons;
  final List<String> missingFields;
  final bool requiresApproval;

  factory HopeOpportunityAgentAction.fromMap(Map<String, dynamic> map) {
    List<String> strings(Object? value) => value is List
        ? value.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).take(6).toList(growable: false)
        : const <String>[];
    return HopeOpportunityAgentAction(
      type: '${map['type'] ?? ''}'.trim(),
      title: '${map['title'] ?? ''}'.trim(),
      reason: map['reason'] == null ? null : '${map['reason']}'.trim(),
      jobId: map['jobId'] == null ? null : '${map['jobId']}'.trim(),
      applicationId: map['applicationId'] == null ? null : '${map['applicationId']}'.trim(),
      score: map['score'] is num ? (map['score'] as num).toDouble() : double.tryParse('${map['score']}'),
      ageDays: map['ageDays'] is num ? (map['ageDays'] as num).toInt() : int.tryParse('${map['ageDays']}'),
      reasons: strings(map['reasons']),
      missingFields: strings(map['missingFields']),
      requiresApproval: map['requiresApproval'] == true,
    );
  }
}

class HopeOpportunityAgentActivity {
  const HopeOpportunityAgentActivity({
    this.savedSearches = 0,
    this.views = 0,
    this.applications = 0,
    this.completedJobs = 0,
  });

  final int savedSearches;
  final int views;
  final int applications;
  final int completedJobs;

  factory HopeOpportunityAgentActivity.fromMap(Map<String, dynamic> map) => HopeOpportunityAgentActivity(
        savedSearches: _int(map['savedSearches']),
        views: _int(map['views']),
        applications: _int(map['applications']),
        completedJobs: _int(map['completedJobs']),
      );
}

class HopeOpportunityAgentProfileCompleteness {
  const HopeOpportunityAgentProfileCompleteness({
    this.score = 0,
    this.missing = const [],
    this.onboardingCompleted = false,
  });

  final double score;
  final List<String> missing;
  final bool onboardingCompleted;

  factory HopeOpportunityAgentProfileCompleteness.fromMap(Map<String, dynamic> map) {
    final missing = map['missing'] is List
        ? (map['missing'] as List).whereType<String>().toList(growable: false)
        : const <String>[];
    return HopeOpportunityAgentProfileCompleteness(
      score: map['score'] is num ? (map['score'] as num).toDouble() : double.tryParse('${map['score']}') ?? 0,
      missing: missing,
      onboardingCompleted: map['onboardingCompleted'] == true,
    );
  }
}

class HopeOpportunityAgentState {
  const HopeOpportunityAgentState({
    required this.profileCompleteness,
    required this.activity,
    required this.actions,
    this.version = '1.0',
    this.automatic = const [],
    this.approvalRequired = const [],
  });

  final String version;
  final HopeOpportunityAgentProfileCompleteness profileCompleteness;
  final HopeOpportunityAgentActivity activity;
  final List<HopeOpportunityAgentAction> actions;
  final List<String> automatic;
  final List<String> approvalRequired;

  factory HopeOpportunityAgentState.fromMap(Map<String, dynamic> map) {
    final rawActions = map['actions'] is List ? map['actions'] as List : const [];
    final actions = rawActions
        .whereType<Map>()
        .map((item) => HopeOpportunityAgentAction.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.type.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);
    final profile = map['profileCompleteness'] is Map
        ? HopeOpportunityAgentProfileCompleteness.fromMap(
            Map<String, dynamic>.from(map['profileCompleteness'] as Map),
          )
        : const HopeOpportunityAgentProfileCompleteness();
    final activity = map['activity'] is Map
        ? HopeOpportunityAgentActivity.fromMap(
            Map<String, dynamic>.from(map['activity'] as Map),
          )
        : const HopeOpportunityAgentActivity();
    final policy = map['automationPolicy'] is Map
        ? Map<String, dynamic>.from(map['automationPolicy'] as Map)
        : const <String, dynamic>{};
    return HopeOpportunityAgentState(
      version: '${map['version'] ?? '1.0'}',
      profileCompleteness: profile,
      activity: activity,
      actions: actions,
      automatic: _strings(policy['automatic']),
      approvalRequired: _strings(policy['approvalRequired']),
    );
  }
}

abstract interface class OpportunityAgentRepository {
  Future<HopeOpportunityAgentState> getState();
}

class ApiOpportunityAgentRepository implements OpportunityAgentRepository {
  const ApiOpportunityAgentRepository(this._api);

  final ApiClient _api;

  @override
  Future<HopeOpportunityAgentState> getState() async {
    final data = await _api.request('GET', '/opportunity-agent', auth: true);
    if (data is! Map) {
      throw const FormatException('Invalid opportunity agent response');
    }
    return HopeOpportunityAgentState.fromMap(Map<String, dynamic>.from(data));
  }
}

int _int(Object? value) => value is num ? value.toInt() : int.tryParse('${value ?? 0}') ?? 0;

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).take(12).toList(growable: false)
    : const <String>[];
