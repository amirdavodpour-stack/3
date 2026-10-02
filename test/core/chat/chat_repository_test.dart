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
  }) async {
    this.method = method;
    this.path = path;
    this.body = body;
    this.auth = auth;
    return response;
  }
}

void main() {
  test('ApiChatRepository sends an authenticated message and returns answer', () async {
    final api = FakeApiClient({
      'data': {'answer': 'سلام'},
    });
    final repository = ApiChatRepository(api);

    final answer = await repository.sendMessage('hello');

    expect(answer, 'سلام');
    expect(api.method, 'POST');
    expect(api.path, '/chat');
    expect(api.body, {'message': 'hello'});
    expect(api.auth, isTrue);
  });

  test('ApiChatRepository rejects a response without an answer', () async {
    final repository = ApiChatRepository(FakeApiClient({'data': {}}));

    await expectLater(
      repository.sendMessage('hello'),
      throwsA(isA<FormatException>()),
    );
  });
}
