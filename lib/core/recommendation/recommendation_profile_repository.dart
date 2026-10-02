import '../network/api_client.dart';

class HopeRecommendationProfile {
  const HopeRecommendationProfile({
    this.resumeText = '',
    this.skills = const [],
    this.interests = const [],
    this.preferredCategories = const [],
    this.preferredCities = const [],
    this.desiredKinds = const [],
    this.workMode,
    this.availability,
    this.salaryMin,
    this.salaryMax,
    this.experienceLevel,
    this.goals = '',
    this.onboardingCompleted = false,
  });

  final String resumeText;
  final List<String> skills;
  final List<String> interests;
  final List<String> preferredCategories;
  final List<String> preferredCities;
  final List<String> desiredKinds;
  final String? workMode;
  final String? availability;
  final String? salaryMin;
  final String? salaryMax;
  final String? experienceLevel;
  final String goals;
  final bool onboardingCompleted;

  factory HopeRecommendationProfile.fromMap(Map<String, dynamic> map) {
    List<String> list(Object? value) => value is List
        ? value.whereType<String>().map((x) => x.trim()).where((x) => x.isNotEmpty).toList(growable: false)
        : const <String>[];
    return HopeRecommendationProfile(
      resumeText: '${map['resumeText'] ?? ''}',
      skills: list(map['skills']),
      interests: list(map['interests']),
      preferredCategories: list(map['preferredCategories']),
      preferredCities: list(map['preferredCities']),
      desiredKinds: list(map['desiredKinds']),
      workMode: map['workMode'] == null ? null : '${map['workMode']}',
      availability: map['availability'] == null ? null : '${map['availability']}',
      salaryMin: map['salaryMin'] == null ? null : '${map['salaryMin']}',
      salaryMax: map['salaryMax'] == null ? null : '${map['salaryMax']}',
      experienceLevel: map['experienceLevel'] == null ? null : '${map['experienceLevel']}',
      goals: '${map['goals'] ?? ''}',
      onboardingCompleted: map['onboardingCompleted'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'resumeText': resumeText,
    'skills': skills,
    'interests': interests,
    'preferredCategories': preferredCategories,
    'preferredCities': preferredCities,
    'desiredKinds': desiredKinds,
    'workMode': workMode,
    'availability': availability,
    'salaryMin': salaryMin,
    'salaryMax': salaryMax,
    'experienceLevel': experienceLevel,
    'goals': goals,
    'onboardingCompleted': onboardingCompleted,
  };
}

abstract interface class RecommendationProfileRepository {
  Future<HopeRecommendationProfile> get();
  Future<HopeRecommendationProfile> save(HopeRecommendationProfile profile);
  Future<RecommendationInterviewReply> interview({
    required List<Map<String, String>> history,
    required String message,
  });
}

class RecommendationInterviewReply {
  const RecommendationInterviewReply({
    required this.reply,
    required this.complete,
    required this.profilePatch,
  });

  final String reply;
  final bool complete;
  final HopeRecommendationProfile profilePatch;
}

class ApiRecommendationProfileRepository implements RecommendationProfileRepository {
  const ApiRecommendationProfileRepository(this._api);
  final ApiClient _api;

  @override
  Future<HopeRecommendationProfile> get() async {
    final data = await _api.request('GET', '/recommendation-profile', auth: true);
    if (data is! Map) throw const FormatException('Invalid recommendation profile response');
    return HopeRecommendationProfile.fromMap(Map<String, dynamic>.from(data));
  }

  @override
  Future<HopeRecommendationProfile> save(HopeRecommendationProfile profile) async {
    final data = await _api.request('PUT', '/recommendation-profile', auth: true, body: profile.toMap());
    if (data is! Map) throw const FormatException('Invalid recommendation profile response');
    return HopeRecommendationProfile.fromMap(Map<String, dynamic>.from(data));
  }

  @override
  Future<RecommendationInterviewReply> interview({
    required List<Map<String, String>> history,
    required String message,
  }) async {
    final data = await _api.request(
      'POST',
      '/recommendation-profile',
      auth: true,
      body: {'history': history, 'message': message},
    );
    if (data is! Map) throw const FormatException('Invalid recommendation interview response');
    final map = Map<String, dynamic>.from(data);
    return RecommendationInterviewReply(
      reply: '${map['reply'] ?? ''}',
      complete: map['complete'] == true,
      profilePatch: HopeRecommendationProfile.fromMap(
        map['profilePatch'] is Map ? Map<String, dynamic>.from(map['profilePatch'] as Map) : const {},
      ),
    );
  }
}