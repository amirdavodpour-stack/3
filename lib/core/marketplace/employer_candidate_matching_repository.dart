import '../network/api_client.dart';

class HopeEmployerCandidateMatch {
  const HopeEmployerCandidateMatch({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.score,
    this.reasons = const [],
    this.components = const {},
    this.applicationId,
    this.status,
    this.resumeHighlights,
    this.skills,
    this.offerId,
    this.offerPrice,
    this.offerMessage,
  });

  final int rank;
  final String userId;
  final String displayName;
  final double score;
  final List<String> reasons;
  final Map<String, double> components;
  final String? applicationId;
  final String? status;
  final String? resumeHighlights;
  final String? skills;
  final String? offerId;
  final String? offerPrice;
  final String? offerMessage;

  bool get isApplication => applicationId != null;
  bool get isOffer => offerId != null;

  factory HopeEmployerCandidateMatch.fromMap(Map<String, dynamic> map) {
    final application = map['application'] is Map
        ? Map<String, dynamic>.from(map['application'] as Map)
        : null;
    final offer = map['offer'] is Map
        ? Map<String, dynamic>.from(map['offer'] as Map)
        : null;
    final rawComponents = map['matchComponents'] is Map
        ? Map<String, dynamic>.from(map['matchComponents'] as Map)
        : const <String, dynamic>{};
    final components = <String, double>{};
    rawComponents.forEach((key, value) {
      final parsed = value is num ? value.toDouble() : double.tryParse('${value}');
      if (parsed != null) components[key] = parsed;
    });
    final rawReasons = map['matchReasons'];
    final reasons = rawReasons is List
        ? rawReasons.whereType<String>().map((value) => value.trim()).where((value) => value.isNotEmpty).take(8).toList(growable: false)
        : const <String>[];

    return HopeEmployerCandidateMatch(
      rank: map['rank'] is num ? (map['rank'] as num).toInt() : int.tryParse('${map['rank']}') ?? 0,
      userId: '${map['userId'] ?? ''}',
      displayName: '${map['displayName'] ?? ''}',
      score: map['score'] is num ? (map['score'] as num).toDouble() : double.tryParse('${map['score']}') ?? 0,
      reasons: reasons,
      components: components,
      applicationId: application?['id'] == null ? null : '${application?['id']}',
      status: (application?['status'] ?? offer?['status']) == null ? null : '${application?['status'] ?? offer?['status']}',
      resumeHighlights: application?['resumeHighlights'] == null ? null : '${application?['resumeHighlights']}',
      skills: application?['skills'] == null ? null : '${application?['skills']}',
      offerId: offer?['id'] == null ? null : '${offer?['id']}',
      offerPrice: offer?['price'] == null ? null : '${offer?['price']}',
      offerMessage: offer?['message'] == null ? null : '${offer?['message']}',
    );
  }
}

class HopeEmployerCandidateMatchList {
  const HopeEmployerCandidateMatchList({
    required this.jobId,
    required this.kind,
    required this.candidates,
  });

  final String jobId;
  final String kind;
  final List<HopeEmployerCandidateMatch> candidates;

  factory HopeEmployerCandidateMatchList.fromMap(Map<String, dynamic> map) {
    final raw = map['candidates'] is List ? map['candidates'] as List : const [];
    final candidates = raw
        .whereType<Map>()
        .map((row) => HopeEmployerCandidateMatch.fromMap(Map<String, dynamic>.from(row)))
        .where((item) => item.userId.trim().isNotEmpty && item.rank > 0)
        .toList(growable: false);
    return HopeEmployerCandidateMatchList(
      jobId: '${map['jobId'] ?? ''}',
      kind: '${map['kind'] ?? 'JOB'}'.toUpperCase(),
      candidates: candidates,
    );
  }
}

abstract interface class EmployerCandidateMatchingRepository {
  Future<HopeEmployerCandidateMatchList> listForJob(String jobId);
}

class ApiEmployerCandidateMatchingRepository implements EmployerCandidateMatchingRepository {
  const ApiEmployerCandidateMatchingRepository(this._api);

  final ApiClient _api;

  @override
  Future<HopeEmployerCandidateMatchList> listForJob(String jobId) async {
    final normalized = jobId.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Job id must not be empty');
    }
    final data = await _api.request(
      'GET',
      '/jobs/${Uri.encodeComponent(normalized)}/candidate-matches',
      auth: true,
    );
    if (data is! Map) {
      throw const FormatException('Invalid employer candidate matching response');
    }
    return HopeEmployerCandidateMatchList.fromMap(
      Map<String, dynamic>.from(data),
    );
  }
}
