import '../network/api_client.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  factory AuthSession.fromResponse(Object? data) {
    if (data is! Map || data['user'] is! Map) {
      throw const FormatException('Invalid authentication response');
    }
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const FormatException('Authentication tokens were not returned');
    }
    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      user: Map<String, dynamic>.from(data['user'] as Map),
    );
  }
}

abstract interface class GoogleAccountLinkRepository {
  Future<void> linkGoogleAccount(String idToken);
}

abstract interface class AuthRepository {
  Future<AuthSession> login(String email, String password);
  Future<AuthSession> loginWithGoogle(String idToken);
  Future<void> register(String email, String password, String displayName);
  Future<AuthSession> verifyEmail(String code);
  Future<void> resendEmailVerification(String email);
  Future<void> logout();
  Future<void> requestPasswordReset(String email);
}

class ApiAuthRepository implements AuthRepository, GoogleAccountLinkRepository {
  ApiAuthRepository(this._api);
  final ApiClient _api;

  @override
  Future<AuthSession> login(String email, String password) async {
    final data = await _api.request('POST', '/auth/login', body: {
      'email': email,
      'password': password,
    });
    return AuthSession.fromResponse(data);
  }

  @override
  Future<void> register(
      String email, String password, String displayName) async {
    await _api.request('POST', '/auth/register', body: {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
  }

  @override
  Future<AuthSession> verifyEmail(String code) async {
    final data = await _api.request('POST', '/auth/email/verify', body: {
      'code': code,
    });
    return AuthSession.fromResponse(data);
  }

  @override
  Future<void> resendEmailVerification(String email) async {
    await _api.request('POST', '/auth/email/verification/resend', body: {
      'email': email,
    });
  }

  @override
  Future<AuthSession> loginWithGoogle(String idToken) async {
    final data = await _api.request('POST', '/auth/google', body: {
      'idToken': idToken,
    });
    return AuthSession.fromResponse(data);
  }

  @override
  Future<void> linkGoogleAccount(String idToken) async {
    await _api.request('POST', '/auth/google/link', auth: true, body: {
      'idToken': idToken,
    });
  }

  @override
  Future<void> logout() async {
    await _api.request('POST', '/auth/logout', auth: true);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _api.request('POST', '/auth/password-reset/request', body: {
      'email': email,
    });
  }
}
