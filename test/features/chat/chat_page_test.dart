import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/chat/chat_repository.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/features/chat/chat_page.dart';

class FakeChatRepository implements ChatRepository {
  bool failList = false;
  bool failSend = false;
  String conversationStatus = 'OPEN';
  HopeChatThread? threadOverride;
  List<HopeChatConversation>? conversationsOverride;

  @override
  Future<List<HopeChatConversation>> listConversations() async {
    if (failList) throw StateError('list failed');
    if (conversationsOverride != null) return conversationsOverride!;
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
  testWidgets(
    'Wave49 Chat send failure keeps full error and Retry reachable at 1.5x in both directions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final locale in const [Locale('fa'), Locale('en')]) {
        final repository = FakeChatRepository()..failSend = true;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: ChatPage(
              key: ValueKey('chat-locale-${locale.languageCode}'),
              repository: repository,
              jobId: 'job-1',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('chat-message-input')),
          'keep this draft for retry',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('chat-send-button')));
        await tester.pumpAndSettle();

        final banner = find.byKey(const ValueKey('chat-send-error'));
        final errorText = find.byKey(
          const ValueKey('chat-send-error-message'),
        );
        final retry = find.byKey(
          const ValueKey('chat-send-error-retry'),
        );
        expect(banner, findsOneWidget);
        expect(errorText, findsOneWidget);
        expect(retry, findsOneWidget);
        expect(tester.widget<Text>(errorText).maxLines, isNull);
        expect(
          tester.widget<TextField>(
            find.byKey(const ValueKey('chat-message-input')),
          ).controller?.text,
          'keep this draft for retry',
        );
        expect(tester.getRect(banner).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(banner).right, lessThanOrEqualTo(320));
        expect(tester.getRect(retry).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(retry).right, lessThanOrEqualTo(320));
        final headerRect = tester.getRect(
          find.byKey(const ValueKey('chat-conversation-header')),
        );
        final bannerRect = tester.getRect(banner);
        final retryRect = tester.getRect(retry);
        final composerRect = tester.getRect(
          find.byKey(const ValueKey('chat-composer-panel')),
        );
        expect(bannerRect.top, greaterThanOrEqualTo(headerRect.bottom));
        expect(bannerRect.bottom, lessThanOrEqualTo(composerRect.top));
        expect(retryRect.top, greaterThanOrEqualTo(bannerRect.top));
        expect(retryRect.bottom, lessThanOrEqualTo(bannerRect.bottom));
        expect(composerRect.bottom, lessThanOrEqualTo(640));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Chat header keeps full participant and job titles visible at 1.5x on compact phones',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final locale in const [Locale('fa'), Locale('en')]) {
        final isEnglish = locale.languageCode == 'en';
        final participantName = isEnglish
            ? 'Senior product designer responsible for international delivery'
            : 'طراح ارشد محصول مسئول تحویل و هماهنگی بین‌المللی';
        final jobTitle = isEnglish
            ? 'Cross-functional mobile product redesign and acceptance review'
            : 'بازطراحی محصول موبایل و بازبینی معیارهای پذیرش';
        final repository = FakeChatRepository()
          ..threadOverride = HopeChatThread(
            conversation: HopeChatConversation(
              id: 'chat-1',
              kind: 'JOB',
              jobId: 'job-1',
              status: 'OPEN',
              title: jobTitle,
              otherUserName: participantName,
            ),
            messages: const [],
          );

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: ChatPage(repository: repository, jobId: 'job-1'),
          ),
        );
        await tester.pumpAndSettle();

        final titleFinder = find.byKey(
          const ValueKey('chat-conversation-title'),
        );
        final contextFinder = find.byKey(
          const ValueKey('chat-conversation-context'),
        );
        expect(titleFinder, findsOneWidget);
        expect(contextFinder, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
          isFalse,
          reason: 'The full participant name must wrap rather than truncate in the compact 320dp / 1.5x layout.',
        );
        expect(
          tester.renderObject<RenderParagraph>(contextFinder).didExceedMaxLines,
          isFalse,
          reason: 'The full job context must wrap rather than truncate in the compact 320dp / 1.5x layout.',
        );
        expect(tester.getRect(titleFinder).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(titleFinder).right, lessThanOrEqualTo(320));
        expect(tester.getRect(contextFinder).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(contextFinder).right, lessThanOrEqualTo(320));
        expect(
          tester.getRect(find.byKey(const ValueKey('chat-composer-panel'))).bottom,
          lessThanOrEqualTo(640),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

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
    'Wave47 successful empty chat keeps the composer available',
    (tester) async {
      final repository = FakeChatRepository();
      await tester.pumpWidget(
        MaterialApp(home: ChatPage(repository: repository, jobId: 'job-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No messages yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-message-list')), findsNothing);
      expect(find.byKey(const ValueKey('chat-composer-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-message-input')), findsOneWidget);
      expect(find.text('Loading conversation'), findsNothing);
      expect(find.text('Conversation unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
    final timestampWidget = tester.widget<Text>(
      find.byKey(const ValueKey('chat-message-timestamp-message-1')),
    );
    expect(timestampWidget.textDirection, TextDirection.ltr);
    expect(
      timestampWidget.style?.fontSize,
      greaterThanOrEqualTo(12),
      reason: 'Message times must remain legible beside the message content.',
    );
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
    expect(find.byKey(const ValueKey('chat-send-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Chat sender name wraps instead of truncating on a compact large-text viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const senderName =
          'Senior product designer responsible for international delivery';
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
              id: 'long-sender',
              conversationId: 'chat-1',
              senderId: 'worker-1',
              senderName: senderName,
              body: 'Please review the attached delivery.',
              createdAt: DateTime(2026, 1, 1, 13, 45),
            ),
          ],
        );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: ChatPage(repository: repository, jobId: 'job-1'),
        ),
      );
      await tester.pumpAndSettle();

      final senderFinder = find.byKey(
        const ValueKey('chat-sender-long-sender'),
      );
      final timestampFinder = find.byKey(
        const ValueKey('chat-message-timestamp-long-sender'),
      );
      expect(senderFinder, findsOneWidget);
      expect(timestampFinder, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(senderFinder).didExceedMaxLines,
        isFalse,
        reason: 'The full sender name must be readable when the sender/timestamp row is narrow and text is enlarged.',
      );
      expect(tester.getRect(senderFinder).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(senderFinder).right, lessThanOrEqualTo(320));
      expect(tester.getRect(timestampFinder).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(timestampFinder).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    },
  );

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

  
  testWidgets('Indigo inbox filters by participant and context text', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(MaterialApp(home: ChatPage(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-inbox-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-inbox-list')), findsOneWidget);
    expect(find.text('Worker'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('chat-inbox-search')), 'missing-conversation');
    await tester.pumpAndSettle();
    expect(find.text('No matching conversations.'), findsOneWidget);
    expect(find.text('Worker'), findsNothing);
    expect(tester.takeException(), isNull);
  });


  testWidgets(
    'Indigo Atelier inbox cards show editorial context and search/filter correctly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = FakeChatRepository()
        ..conversationsOverride = [
          HopeChatConversation(
            id: 'orion',
            kind: 'JOB',
            jobId: 'job-orion',
            status: 'OPEN',
            title: 'Orion Website Refresh',
            otherUserName: 'Mina Rahimi',
            lastMessageBody: 'Deliverables are ready for review.',
            lastMessageAt: DateTime.now(),
            unreadCount: 2,
            isPinned: true,
          ),
          HopeChatConversation(
            id: 'atlas',
            kind: 'JOB',
            jobId: 'job-atlas',
            status: 'OPEN',
            title: 'Atlas Mobile App',
            otherUserName: 'Daniel Reed',
            lastMessageBody: 'The schedule was updated.',
            lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          const HopeChatConversation(
            id: 'admin',
            kind: 'ADMIN',
            jobId: '',
            status: 'OPEN',
            title: 'HOPE Admin Room',
            otherUserName: '',
            lastMessageBody: 'Operations check-in.',
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ChatPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chat-inbox-card-orion')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-card-atlas')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-card-admin')), findsOneWidget);
      expect(find.text('PROJECT CHAT'), findsNWidgets(2));
      expect(find.text('HOPE TEAM'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-context-orion')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-preview-orion')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-time-orion')), findsOneWidget);
      expect(find.text('2 UNREAD'), findsOneWidget);
      final unreadBadge = tester.widget<Container>(
        find.byKey(const ValueKey('chat-inbox-unread-orion')),
      );
      expect(
        (unreadBadge.decoration as BoxDecoration).color,
        HopeV2Colors.primaryAction,
      );
      expect(find.text('PINNED'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final search = find.byKey(const ValueKey('chat-inbox-search'));
      await tester.enterText(search, 'Atlas');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-inbox-card-atlas')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-card-orion')), findsNothing);
      expect(find.byKey(const ValueKey('chat-inbox-card-admin')), findsNothing);

      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Unread'));
      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-inbox-card-orion')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-card-atlas')), findsNothing);
      expect(find.byKey(const ValueKey('chat-inbox-card-admin')), findsNothing);

      await tester.ensureVisible(find.text('Projects'));
      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-inbox-card-orion')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-card-atlas')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-card-admin')), findsNothing);
    },
  );

  testWidgets(
    'Indigo Atelier inbox cards remain inside a compact RTL viewport at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = FakeChatRepository()
        ..conversationsOverride = [
          HopeChatConversation(
            id: 'compact',
            kind: 'JOB',
            jobId: 'job-compact',
            status: 'OPEN',
            title: 'بازطراحی محصول موبایل و هماهنگی بین‌المللی',
            otherUserName: 'طراح ارشد محصول مسئول تحویل نهایی',
            lastMessageBody: 'نسخه نهایی برای بازبینی و تأیید ارسال شده است.',
            lastMessageAt: DateTime.now(),
            unreadCount: 3,
            isPinned: true,
            isImportant: true,
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: ChatPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('chat-inbox-card-compact'));
      expect(card, findsOneWidget);
      expect(tester.getRect(card).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(card).right, lessThanOrEqualTo(320));
      expect(find.byKey(const ValueKey('chat-inbox-name-compact')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-inbox-preview-compact')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

}
