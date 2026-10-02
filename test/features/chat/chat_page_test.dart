import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/chat/chat_repository.dart';
import 'package:hope_mobile/features/chat/chat_page.dart';

class FakeChatRepository implements ChatRepository {
  String? lastMessage;

  @override
  Future<String> sendMessage(String message) async {
    lastMessage = message;
    return 'AI_OK';
  }
}

void main() {
  testWidgets('ChatPage sends a message and renders the assistant answer',
      (tester) async {
    final repository = FakeChatRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(repository: repository),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.lastMessage, 'hello');
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('AI_OK'), findsOneWidget);
  });

  testWidgets('ChatPage does not send an empty message', (tester) async {
    final repository = FakeChatRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(repository: repository),
      ),
    );

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(repository.lastMessage, isNull);
  });
}
