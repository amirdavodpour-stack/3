import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/chat/chat_repository.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(this.response)
      : super(SecureStore(), baseUrl: 'http://127.0.0.1:3000/api/v1');

  final Object response;
  String? method;
  String? path;
  Object? body;
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
    this.body = body;
    this.auth = auth;
    return response;
  }
}

void main() {
  test('ApiChatRepository sends an authenticated message and returns the created message', () async {
    final api = FakeApiClient({
      'id': 'message-1',
      'conversationId': 'conversation-1',
      'senderId': 'user-1',
      'senderName': 'User',
      'body': 'سلام',
      'createdAt': '2026-11-16T19:00:00.000Z',
    });
    final repository = ApiChatRepository(api);

    final message = await repository.sendMessage('conversation-1', 'hello');

    expect(message.body, 'سلام');
    expect(message.conversationId, 'conversation-1');
    expect(api.method, 'POST');
    expect(api.path, '/messaging/conversations/conversation-1');
    expect(api.body, {'message': 'hello'});
    expect(api.auth, isTrue);
  });

  test('ApiChatRepository rejects a response without a message id', () async {
    final repository = ApiChatRepository(FakeApiClient({}));

    await expectLater(
      repository.sendMessage('conversation-1', 'hello'),
      throwsA(isA<FormatException>()),
    );
  });
}
