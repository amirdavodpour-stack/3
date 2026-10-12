import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/config/backend_capabilities.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';

class _CapabilitiesApi extends ApiClient {
  _CapabilitiesApi(this.response)
      : super(SecureStore(), baseUrl: 'http://127.0.0.1:3000/api/v1');

  final Object? response;
  String? method;
  String? path;
  bool? auth;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    bool auth = false,
    Map<String, String>? headers,
  }) async {
    this.method = method;
    this.path = path;
    this.auth = auth;
    return response;
  }
}

void main() {
  test('loads server capabilities from the public config endpoint', () async {
    final api = _CapabilitiesApi({
      'capabilities': {
        'googleSignIn': true,
        'wallet': true,
        'walletTransfer': true,
        'walletWithdraw': false,
        'walletDeposit': true,
        'notifications': true,
        'savedOpportunities': false,
        'matchImprovementHints': false,
        'candidateComparison': false,
        'lifetimeEarnings': false,
        'verifiedIdentity': true,
        'reputation': false,
        'responseTime': false,
        'distance': true,
        'humanReferences': false,
      },
      'currency': 'TOMAN',
    });

    final capabilities =
        await ApiBackendCapabilitiesRepository(api).load();

    expect(api.method, 'GET');
    expect(api.path, '/config/capabilities');
    expect(api.auth, isFalse);
    expect(capabilities.wallet, isTrue);
    expect(capabilities.walletTransfer, isTrue);
    expect(capabilities.walletWithdraw, isFalse);
    expect(capabilities.walletDeposit, isTrue);
    expect(capabilities.savedOpportunities, isFalse);
    expect(capabilities.humanReferences, isFalse);
  });

  test('unknown or non-boolean financial capabilities fail closed', () async {
    final api = _CapabilitiesApi({
      'capabilities': {
        'wallet': true,
        'walletWithdraw': 'true',
        'walletDeposit': 1,
        'walletTransfer': null,
      },
    });

    final capabilities =
        await ApiBackendCapabilitiesRepository(api).load();

    expect(capabilities.wallet, isTrue);
    expect(capabilities.walletWithdraw, isFalse);
    expect(capabilities.walletDeposit, isFalse);
    expect(capabilities.walletTransfer, isFalse);
    expect(capabilities.savedOpportunities, isFalse);
  });

  test('malformed config does not silently enable backend capabilities',
      () async {
    final api = _CapabilitiesApi({'currency': 'TOMAN'});

    expect(
      () => ApiBackendCapabilitiesRepository(api).load(),
      throwsFormatException,
    );
  });
}
