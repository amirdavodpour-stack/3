import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/chat/chat_repository.dart';
import 'package:hope_mobile/features/chat/chat_page.dart';

class FakeChatRepository implements ChatRepository {
  bool failList = false;
  String conversationStatus = 'OPEN';
  HopeChatThread? threadOverride;

  @override
  Future<List<HopeChatConversation>> listConversations() async {
    if (failList) throw StateError('list failed');
    return [
      HopeChatConversation(
        id: 'chat-1',
        kind: 'JOB',
        jobId: 'job-1',
        status: conversationStatus,
        title: 'Test job',
        otherUserName: 'Worker',
      ),
    ];
  }

  @override
  Future<HopeChatThread> getMessages(String conversationId) async {
    if (threadOverride != null) return threadOverride!;
    return HopeChatThread(
      conversation: HopeChatConversation(
        id: 'chat-1',
        kind: 'JOB',
        jobId: 'job-1',
        status: conversationStatus,
        title: 'Test job',
        otherUserName: 'Worker',
      ),
      messages: const [],
    );
  }

  String? lastMessage;
  @override
  Future<HopeChatMessage> sendMessage(
    String conversationId,
    String message,
  ) async {
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

  testWidgets(
    'ChatPage keeps load error as the only initial state and clears it after retry',
    (tester) async {
      final repository = FakeChatRepository()..failList = true;
      await tester.pumpWidget(
        MaterialApp(home: ChatPage(repository: repository, jobId: 'job-1')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Conversation unavailable'), findsOneWidget);
      expect(find.text('Loading conversation'), findsNothing);

      repository.failList = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Conversation unavailable'), findsNothing);
      expect(find.text('Loading conversation'), findsNothing);
      expect(find.text('Write a message'), findsOneWidget);
    },
  );

  testWidgets('ChatPage renders a generic closed state without a send composer',
      (tester) async {
    final repository = FakeChatRepository()..conversationStatus = 'CLOSED';
    await tester.pumpWidget(
      MaterialApp(home: ChatPage(repository: repository, jobId: 'job-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('This conversation is closed.'), findsOneWidget);
    expect(find.byTooltip('Send'), findsNothing);
  });

  testWidgets('ChatPage renders message timestamps', (tester) async {
    final repository = FakeChatRepository()
      ..threadOverride = HopeChatThread(
        conversation: const HopeChatConversation(
          id: 'chat-1',
          kind: 'JOB',
          jobId: 'job-1',
          status: 'OPEN',
          title: 'Test job',
          otherUserName: 'Worker',
        ),
        messages: [
          HopeChatMessage(
            id: 'message-1',
            conversationId: 'chat-1',
            senderId: 'worker-1',
            senderName: 'Worker',
            body: 'Hello from the worker',
            createdAt: DateTime(2026, 1, 1, 13, 45),
          ),
        ],
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatPage(repository: repository, jobId: 'job-1')),
    );
    await tester.pumpAndSettle();

    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(ChatPage)),
    );
    final formatted = localizations.formatTimeOfDay(
      const TimeOfDay(hour: 13, minute: 45),
    );

    expect(find.text('Hello from the worker'), findsOneWidget);
    expect(find.text(formatted), findsOneWidget);
  });
}
