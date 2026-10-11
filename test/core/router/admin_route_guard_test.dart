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
              onPressed: () => Navigator.push(context, route()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  expect(find.text('Admin access is restricted.'), findsOneWidget);
  expect(find.text('Admin panel verification'), findsNothing);
  expect(find.text('Admin control center'), findsNothing);

  Navigator.of(
    tester.element(find.text('Admin access is restricted.')),
  ).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('admin-only routes do not expose admin pages to guests', (tester) async {
    for (final route in <Route<void> Function()>[
      HopeRoutes.adminAccess,
      HopeRoutes.admin,
      HopeRoutes.adminOperations,
      HopeRoutes.adminDisputes,
      HopeRoutes.adminChat,
    ]) {
      await _pushAndAssertRestricted(tester, route);
    }
  });
}
