import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/router/app_routes.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:provider/provider.dart';

class _AuthRepo implements AuthRepository {
  @override
  Future<AuthSession> login(String email, String password) => throw UnimplementedError();
  @override
  Future<AuthSession> register(String email, String password, String displayName) => throw UnimplementedError();
  @override
  Future<AuthSession> loginWithGoogle(String idToken) => throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset(String email) async {}
}

Future<void> _pushAndAssertRestricted(
  WidgetTester tester,
  Route<void> Function() route,
) async {
  final auth = AuthController(_AuthRepo(), SecureStore())..continueAsGuest();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const ValueKey('admin-route-guard-open'),
              onPressed: () => Navigator.push(context, route()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  final openButton = find.byKey(const ValueKey('admin-route-guard-open'));
  expect(openButton, findsOneWidget);
  await tester.tap(openButton);
  await tester.pumpAndSettle();

  expect(find.text('Admin access is restricted.'), findsOneWidget);
  expect(find.text('Admin panel verification'), findsNothing);
  expect(find.text('Admin control center'), findsNothing);
}

void main() {
  testWidgets('admin access route remains restricted to guests', (tester) async {
    await _pushAndAssertRestricted(tester, HopeRoutes.adminAccess);
  });

  testWidgets('admin control route remains restricted to guests', (tester) async {
    await _pushAndAssertRestricted(tester, HopeRoutes.admin);
  });

  testWidgets('admin operations route remains restricted to guests', (tester) async {
    await _pushAndAssertRestricted(tester, HopeRoutes.adminOperations);
  });

  testWidgets('admin disputes route remains restricted to guests', (tester) async {
    await _pushAndAssertRestricted(tester, HopeRoutes.adminDisputes);
  });

  testWidgets('admin chat route remains restricted to guests', (tester) async {
    await _pushAndAssertRestricted(tester, HopeRoutes.adminChat);
  });
}
