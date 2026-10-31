import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/auth/google_sign_in_service.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import '../network/test_fixtures.dart';

class _LinkingRepository implements AuthRepository, GoogleAccountLinkRepository {
  String? linkedToken;
  Object? linkFailure;

  @override
  Future<void> linkGoogleAccount(String idToken) async {
    if (linkFailure != null) throw linkFailure!;
    linkedToken = idToken;
  }

  @override
  Future<AuthSession> login(String email, String password) => throw UnimplementedError();
  @override
  Future<AuthSession> loginWithGoogle(String idToken) => throw UnimplementedError();
  @override
  Future<AuthSession> register(String email, String password, String displayName) => throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset(String email) async {}
}

class _GoogleSignIn extends GoogleSignInService {
  _GoogleSignIn() : super(serverClientId: 'test-server-client');

  @override
  Future<String> authenticate() async => 'verified-google-id-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => installFakeSecureStorageForTests());

  test('Google linking reauthenticates, binds the verified token, and keeps the HOPE session', () async {
    final repository = _LinkingRepository();
    final auth = AuthController(repository, SecureStore());
    await auth.applyRefreshedUser({'id': 'user-1', 'email': 'member@example.com'});

    await auth.linkGoogleAccount(_GoogleSignIn());

    expect(repository.linkedToken, 'verified-google-id-token');
    expect(auth.user?['id'], 'user-1');
    expect(auth.user?['googleLinked'], isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.loading, isFalse);
    expect(auth.error, isNull);
  });

  test('Google linking exposes a safe conflict message and restores idle state', () async {
    final repository = _LinkingRepository()
      ..linkFailure = ApiException('GOOGLE_LINK_EMAIL_MISMATCH', 'email mismatch', status: 403);
    final auth = AuthController(repository, SecureStore());
    await auth.applyRefreshedUser({'id': 'user-1', 'email': 'member@example.com'});

    await expectLater(auth.linkGoogleAccount(_GoogleSignIn()), throwsA(isA<ApiException>()));

    expect(auth.isAuthenticated, isTrue);
    expect(auth.loading, isFalse);
    expect(auth.error, 'ایمیل حساب گوگل باید با ایمیل حساب HOPE شما یکسان باشد.');
  });
}
