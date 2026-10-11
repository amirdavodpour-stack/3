import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/admin/admin_access_guard.dart';
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

Future<void> _pump(WidgetTester tester, {required String? role}) async {
  final auth = AuthController(_AuthRepo(), SecureStore());
  if (role == null) {
    auth.continueAsGuest();
  } else {
    await auth.applyRefreshedUser({
      'id': 'u1',
      'displayName': 'Test User',
      'email': 'user@example.com',
      'role': role,
    });
  }

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: const AdminOnly(
          child: Text('ADMIN CONTENT'),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('admin-only surface is hidden from guests', (tester) async {
    await _pump(tester, role: null);
    expect(find.text('ADMIN CONTENT'), findsNothing);
    expect(find.text('Admin access is restricted.'), findsOneWidget);
  });

  testWidgets('admin-only surface is hidden from standard users', (tester) async {
    await _pump(tester, role: 'USER');
    expect(find.text('ADMIN CONTENT'), findsNothing);
    expect(find.text('Admin access is restricted.'), findsOneWidget);
  });

  testWidgets('admin-only surface is rendered for administrators', (tester) async {
    await _pump(tester, role: 'ADMIN');
    expect(find.text('ADMIN CONTENT'), findsOneWidget);
    expect(find.text('Admin access is restricted.'), findsNothing);
  });
}
