import 'package:google_sign_in/google_sign_in.dart';

import '../network/api_client.dart';

class GoogleSignInService {
  GoogleSignInService();

  static const serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  final GoogleSignIn _signIn = GoogleSignIn.instance;
  Future<void>? _initializeFuture;

  bool get isConfigured => serverClientId.trim().isNotEmpty;

  Future<void> initialize() {
    if (!isConfigured) return Future<void>.value();
    return _initializeFuture ??= _signIn.initialize(
      serverClientId: serverClientId.trim(),
    );
  }

  Future<String> authenticate() async {
    if (!isConfigured) {
      throw ApiException(
        'GOOGLE_AUTH_UNAVAILABLE',
        'Google sign-in is not configured for this build.',
      );
    }
    await initialize();
    try {
      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw ApiException(
          'INVALID_GOOGLE_TOKEN',
          'Google did not return a usable identity token.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw ApiException('GOOGLE_SIGN_IN_CANCELED', 'Google sign-in was canceled.');
      }
      throw ApiException(
        'GOOGLE_SIGN_IN_FAILED',
        'Google sign-in failed.',
      );
    }
  }
}
