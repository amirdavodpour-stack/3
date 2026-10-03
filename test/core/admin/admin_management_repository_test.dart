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
    expect(access.verified, isTrue);
    expect(access.primaryAdmin, isTrue);
    expect(access.permissions, contains('admin.manage_admins'));
  });

  test('owner can list administrators through the admin repository', () async {
    server.handlers['/admin/admins'] = (request, body) async {
      expect(request.method, 'GET');
      await respondJson(request, 200, {
        'data': [
          {
            'id': 'owner-1',
            'email': 'amir.davodpour@gmail.com',
            'displayName': 'Owner',
            'role': 'ADMIN',
            'status': 'ACTIVE',
            'primaryAdmin': true,
          },
          {
            'id': 'admin-1',
            'email': 'ops@example.com',
            'displayName': 'Ops',
            'role': 'ADMIN',
            'status': 'ACTIVE',
            'primaryAdmin': false,
          },
        ],
      });
    };

    final admins = await repository.listAdmins();
    expect(admins, hasLength(2));
    expect(admins.first.primaryAdmin, isTrue);
    expect(admins.last.email, 'ops@example.com');
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
    expect(granted.role, 'ADMIN');

    final revoked = await repository.revokeAdmin('admin-2');
    expect(revoked.role, 'USER');
  });
}
