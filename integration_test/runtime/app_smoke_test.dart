import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:hope_mobile/main.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class _SmokeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login(String email, String password) =>
      throw UnimplementedError();
  @override
  Future<AuthSession> register(
          String email, String password, String displayName) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset(String email) async {}
}

Future<T> _retry<T>(
  Future<T> Function() operation, {
  int attempts = 6,
  Duration delay = const Duration(seconds: 3),
}) async {
  Object? lastError;
  StackTrace? lastStack;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await operation();
    } catch (error, stack) {
      lastError = error;
      lastStack = stack;
      if (attempt == attempts) break;
      await Future<void>.delayed(delay * attempt);
    }
  }
  Error.throwWithStackTrace(
    lastError ?? StateError('retry exhausted'),
    lastStack ?? StackTrace.current,
  );
}

Future<http.Response> _getWithRetry(Uri uri) {
  return _retry(() => http.get(uri).timeout(const Duration(seconds: 10)));
}

Future<void> _pump(WidgetTester tester) async {
  final settings = HopeSettingsController();
  await settings.load();
  final auth = AuthController(_SmokeAuthRepository(), SecureStore());
  auth.continueAsGuest();
  // The production entrypoint awaits session restoration before runApp. This
  // integration test injects AuthController directly, so mark the test state
  // initialized explicitly to exercise the real guest home surface rather
  // than the transient branded loading screen.
  auth.initialized = true;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<HopeSettingsController>.value(value: settings),
      ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(settings)),
      ChangeNotifierProvider<AuthController>.value(value: auth),
    ],
    child: const WorkMarketplaceApp(),
  ));

  // The home shell intentionally contains an indefinitely repeating skeleton
  // shimmer while asynchronous discovery is pending. `pumpAndSettle()` can
  // therefore wait forever on an actual device even though the app is healthy.
  // Advance the frame clock without requiring global animation quiescence.
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HOPE boots on an actual Flutter runtime surface',
      (tester) async {
    await _pump(tester);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('configured staging live and categories endpoints are reachable',
      (tester) async {
    const enabled = bool.fromEnvironment(
      'CI_DEVICE_INTEGRATION',
      defaultValue: false,
    );
    if (!enabled) return;
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    expect(baseUrl, isNotEmpty);
    expect(Uri.parse(baseUrl).scheme, 'https');
    final live = await _getWithRetry(Uri.parse('$baseUrl/live'));
    expect(live.statusCode, 200);
    expect(live.headers['content-type'] ?? '', contains('application/json'));

    final categories = await _getWithRetry(Uri.parse('$baseUrl/categories'));
    expect(categories.statusCode, 200);
    expect(
        categories.headers['content-type'] ?? '', contains('application/json'));
    final body = jsonDecode(categories.body);
    expect(body, isA<Map>());
    expect((body['data'] as List), isNotEmpty);
  });
}
