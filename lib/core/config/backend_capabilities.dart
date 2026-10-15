import '../network/api_client.dart';

class BackendCapabilities {
  const BackendCapabilities({
    this.googleSignIn = false,
    this.wallet = false,
    this.walletTransfer = false,
    this.walletWithdraw = false,
    this.walletDeposit = false,
    this.notifications = false,
    this.savedOpportunities = false,
    this.matchImprovementHints = false,
    this.candidateComparison = false,
    this.lifetimeEarnings = false,
    this.verifiedIdentity = false,
    this.reputation = false,
    this.responseTime = false,
    this.distance = false,
    this.humanReferences = false,
  });

  final bool googleSignIn;
  final bool wallet;
  final bool walletTransfer;
  final bool walletWithdraw;
  final bool walletDeposit;
  final bool notifications;
  final bool savedOpportunities;
  final bool matchImprovementHints;
  final bool candidateComparison;
  final bool lifetimeEarnings;
  final bool verifiedIdentity;
  final bool reputation;
  final bool responseTime;
  final bool distance;
  final bool humanReferences;

  factory BackendCapabilities.fromResponse(Object? response) {
    if (response is! Map || response['capabilities'] is! Map) {
      throw const FormatException('Backend capabilities map is missing.');
    }
    final values = Map<String, dynamic>.from(response['capabilities'] as Map);
    bool enabled(String key) => values[key] == true;
    return BackendCapabilities(
      googleSignIn: enabled('googleSignIn'),
      wallet: enabled('wallet'),
      walletTransfer: enabled('walletTransfer'),
      walletWithdraw: enabled('walletWithdraw'),
      walletDeposit: enabled('walletDeposit'),
      notifications: enabled('notifications'),
      savedOpportunities: enabled('savedOpportunities'),
      matchImprovementHints: enabled('matchImprovementHints'),
      candidateComparison: enabled('candidateComparison'),
      lifetimeEarnings: enabled('lifetimeEarnings'),
      verifiedIdentity: enabled('verifiedIdentity'),
      reputation: enabled('reputation'),
      responseTime: enabled('responseTime'),
      distance: enabled('distance'),
      humanReferences: enabled('humanReferences'),
    );
  }
}

abstract interface class BackendCapabilitiesRepository {
  Future<BackendCapabilities> load();
}

class ApiBackendCapabilitiesRepository implements BackendCapabilitiesRepository {
  const ApiBackendCapabilitiesRepository(this._api);
  final ApiClient _api;

  @override
  Future<BackendCapabilities> load() async {
    final response = await _api.request('GET', '/config/capabilities', auth: false);
    return BackendCapabilities.fromResponse(response);
  }
}
