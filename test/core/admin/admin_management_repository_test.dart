import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/admin/admin_repository.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';

import '../../support/fake_api_server.dart';

void _installStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : const <String, dynamic>{};
    if (call.method == 'read' && args['key'] == 'hope.access_token') {
      return 'token';
    }
    return null;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeApiServer server;
  late ApiAdminRepository repository;

  setUp(() async {
    _installStorage();
    server = await FakeApiServer.start();
    repository = ApiAdminRepository(
      ApiClient(SecureStore(), baseUrl: server.baseUrl),
    );
  });

  tearDown(() => server.close());

  test('panel access exposes the primary-owner flag', () async {
    server.handlers['/admin/access'] = (request, body) async {
      expect(request.method, 'GET');
      await respondJson(request, 200, {
        'data': {
          'verified': true,
          'primaryAdmin': true,
          'permissions': ['admin.manage_admins'],
        }
      });
    };

    final access = await repository.getPanelAccess();
    expect(access['verified'], isTrue);
    expect(access['primaryAdmin'], isTrue);
    expect((access['permissions'] as List), contains('admin.manage_admins'));
  });

  test('admin user preserves the primary-owner marker from the API', () {
    final owner = HopeAdminUser.fromMap({
      'id': 'owner-1',
      'email': 'amir.davodpour@gmail.com',
      'displayName': 'Owner',
      'role': 'ADMIN',
      'status': 'ACTIVE',
      'primaryAdmin': true,
    });
    final operator = HopeAdminUser.fromMap({
      'id': 'admin-1',
      'email': 'ops@example.com',
      'displayName': 'Ops',
      'role': 'ADMIN',
      'status': 'ACTIVE',
      'primaryAdmin': false,
    });

    expect(owner.primaryAdmin, isTrue);
    expect(operator.primaryAdmin, isFalse);
  });

  test('promote and revoke administrator call the protected routes', () async {
    server.handlers['/admin/admins'] = (request, body) async {
      expect(request.method, 'POST');
      expect(body['email'], 'new.admin@example.com');
      await respondJson(request, 200, {
        'data': {
          'id': 'admin-2',
          'email': 'new.admin@example.com',
          'displayName': 'New Admin',
          'role': 'ADMIN',
          'status': 'ACTIVE',
        }
      });
    };
    server.handlers['/admin/admins/admin-2'] = (request, body) async {
      expect(request.method, 'DELETE');
      await respondJson(request, 200, {
        'data': {
          'id': 'admin-2',
          'email': 'new.admin@example.com',
          'displayName': 'New Admin',
          'role': 'USER',
          'status': 'ACTIVE',
        }
      });
    };

    final granted = await repository.grantAdminByEmail('new.admin@example.com');
    expect(granted['role'], 'ADMIN');

    await repository.revokeAdministrator('admin-2');
    // The fake server assertions above verify the DELETE contract.
  });
}
