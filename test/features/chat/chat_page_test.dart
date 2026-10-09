import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/chat/chat_repository.dart';
import 'package:hope_mobile/features/chat/chat_page.dart';

class FakeChatRepository implements ChatRepository {
  bool failList = false;
  bool failSend = false;
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
    if (failSend) throw StateError('send failed');
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
    await tester.pump();
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
  testWidgets(
    'Wave 28 chat is organized for compact phones and keeps primary targets at 48dp',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeChatRepository();

      await tester.pumpWidget(
        MaterialApp(home: ChatPage(repository: repository, jobId: 'job-1')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chat-conversation-header')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-message-list')), findsNothing);
      expect(find.text('Worker'), findsOneWidget);
      expect(find.text('Test job'), findsOneWidget);
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('chat-message-input')),
      );
      expect(input.decoration?.prefixIcon, isNull);
      final sendRect = tester.getRect(find.byKey(const ValueKey('chat-send-button')));
      expect(sendRect.width, greaterThanOrEqualTo(48));
      expect(sendRect.height, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(find.byKey(const ValueKey('chat-composer-panel'))).bottom,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Wave 28 failed chat send restores the exact draft for retry',
      (tester) async {
    final repository = FakeChatRepository()..failSend = true;
    await tester.pumpWidget(
      MaterialApp(home: ChatPage(repository: repository, jobId: 'job-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chat-message-input')),
      'keep this draft',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(
        find.byKey(const ValueKey('chat-message-input')),
      ).controller?.text,
      'keep this draft',
    );
    expect(find.text('Message action failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wave 28 groups consecutive messages from the same sender',
      (tester) async {
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
            id: 'm1',
            conversationId: 'chat-1',
            senderId: 'worker-1',
            senderName: 'Worker',
            body: 'First line',
            createdAt: DateTime(2026, 1, 1, 13, 45),
          ),
          HopeChatMessage(
            id: 'm2',
            conversationId: 'chat-1',
            senderId: 'worker-1',
            senderName: 'Worker',
            body: 'Second line',
            createdAt: DateTime(2026, 1, 1, 13, 46),
          ),
        ],
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatPage(repository: repository, jobId: 'job-1')),
    );
    await tester.pumpAndSettle();

    final messages = find.byKey(const ValueKey('chat-message-list'));
    expect(messages, findsOneWidget);
    expect(
      find.descendant(of: messages, matching: find.text('Worker')),
      findsOneWidget,
    );
    expect(find.text('First line'), findsOneWidget);
    expect(find.text('Second line'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
