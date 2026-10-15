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
  Map<String, String>? headers;

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
    this.headers = headers;
    return response;
  }
}

void main() {
  test('ApiChatRepository sends an authenticated message and returns answer', () async {
    final api = FakeApiClient({
      'id': 'message-1',
      'conversationId': 'conversation-1',
      'senderId': 'u1',
      'senderName': 'Ali',
      'body': 'سلام',
      'createdAt': '2026-10-07T10:00:00Z',
    });
    final repository = ApiChatRepository(api);

    final answer = await repository.sendMessage('conversation-1', 'hello');

    expect(answer.body, 'سلام');
    expect(api.method, 'POST');
    expect(api.path, '/messaging/conversations/conversation-1');
    expect(api.body, {'message': 'hello'});
    expect(api.headers, isNull);
    expect(api.auth, isTrue);
  });

  test('ApiChatRepository rejects a response without an answer', () async {
    final repository = ApiChatRepository(FakeApiClient({'data': {}}));

    await expectLater(
      repository.sendMessage('conversation-1', 'hello'),
      throwsA(isA<FormatException>()),
    );
  });
}
