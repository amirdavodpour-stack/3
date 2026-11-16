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

  test('conversation model maps preview, unread and organization fields', () {
    final value = HopeChatConversation.fromMap({
      'id':'c1','kind':'JOB','jobId':'j1','status':'OPEN','title':'Project',
      'otherUserName':'Partner','lastMessageBody':'Ready for review',
      'lastMessageType':'TEXT','lastMessageAt':'2026-10-17T10:00:00Z',
      'unreadCount':3,'isPinned':true,'isImportant':true,'isArchived':false,
    });
    expect(value.lastMessageBody, 'Ready for review');
    expect(value.unreadCount, 3);
    expect(value.isPinned, isTrue);
    expect(value.isImportant, isTrue);
    expect(value.isArchived, isFalse);
  });

  test('message model maps attachment metadata and read receipts', () {
    final value = HopeChatMessage.fromMap({
      'id':'m1','conversationId':'c1','senderId':'u1','senderName':'Partner',
      'body':'Attachment','messageType':'ATTACHMENT','createdAt':'2026-10-17T10:00:00Z',
      'attachments':[{'id':'a1','filename':'brief.pdf','contentType':'application/pdf','size':2048,'downloadPath':'/messaging/attachments/a1/content'}],
      'readReceipts':[{'userId':'u2','userName':'Reader','readAt':'2026-10-17T10:01:00Z'}],
    });
    expect(value.messageType, 'ATTACHMENT');
    expect(value.attachments.single.filename, 'brief.pdf');
    expect(value.attachments.single.size, 2048);
    expect(value.attachments.single.downloadPath, '/messaging/attachments/a1/content');
    expect(value.readReceipts.single.userId, 'u2');
  });

}
