import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/chat/chat_repository.dart';
import 'package:hope_mobile/features/chat/chat_page.dart';

class FakeChatRepository implements ChatRepository {
  @override
  Future<List<HopeChatConversation>> listConversations() async => const [
        HopeChatConversation(
          id: 'chat-1',
          kind: 'JOB',
          jobId: 'job-1',
          status: 'OPEN',
          title: 'Test job',
          otherUserName: 'Worker',
        ),
      ];

  @override
  Future<HopeChatThread> getMessages(String conversationId) async =>
      const HopeChatThread(
        conversation: HopeChatConversation(
          id: 'chat-1',
          kind: 'JOB',
          jobId: 'job-1',
          status: 'OPEN',
          title: 'Test job',
          otherUserName: 'Worker',
        ),
        messages: [],
      );

  String? lastMessage;
  @override
  Future<HopeChatMessage> sendMessage(String conversationId, String message) async {
    lastMessage = message;
    return HopeChatMessage(
      id: 'message-1',
      conversationId: conversationId,
      senderId: 'me',
      senderName: 'Me',
      body: message,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  testWidgets('ChatPage sends a human message', (tester) async {
    final repository = FakeChatRepository();

    await tester.pumpWidget(
      MaterialApp(home: ChatPage(repository: repository, jobId: 'job-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(repository.lastMessage, 'hello');
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('ChatPage does not send an empty message', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatPage(repository: repository, jobId: 'job-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(repository.lastMessage, isNull);
  });
}
