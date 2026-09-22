import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/notifications/notification.dart';
import 'package:hope_mobile/core/notifications/notification_repository.dart';
import 'package:hope_mobile/features/notifications/notifications_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _Repo implements NotificationRepository {
  int readAllCalls = 0;
  int markReadCalls = 0;
  List<HopeNotification> items = [
    const HopeNotification(
      id: 'n1',
      type: 'JOB',
      title: 'عنوان اعلان',
      body: 'متن اعلان',
      createdAt: null,
      readAt: null,
    ),
  ];

  @override
  Future<HopeNotificationPage> listNotifications(
          {int limit = 50, int offset = 0}) async =>
      HopeNotificationPage(
          items: items, unreadCount: items.where((e) => e.isUnread).length);

  @override
  Future<HopeNotification> markRead(String id) async {
    markReadCalls++;
    final index = items.indexWhere((e) => e.id == id);
    if (index >= 0) {
      items = [
        for (var i = 0; i < items.length; i++)
          if (i == index)
            HopeNotification(
                id: items[i].id,
                type: items[i].type,
                title: items[i].title,
                body: items[i].body,
                createdAt: items[i].createdAt,
                readAt: 'now')
          else
            items[i],
      ];
    }
    return items[index];
  }

  @override
  Future<HopeNotificationPreferences> getPreferences() async => const HopeNotificationPreferences(inApp: true, push: true, email: true, jobAlerts: true, applicationUpdates: true, paymentUpdates: true, marketing: false);

  @override
  Future<HopeNotificationPreferences> updatePreferences(Map<String, bool> patch) async => getPreferences();

  @override
  Future<int> markAllRead() async {
    readAllCalls++;
    items = [
      for (final item in items)
        HopeNotification(
            id: item.id,
            type: item.type,
            title: item.title,
            body: item.body,
            createdAt: item.createdAt,
            readAt: 'now')
    ];
    return items.length;
  }
  @override
  Future<List<HopeNotificationDevice>> listDevices() async => const [];

  @override
  Future<void> disableDevice(String id) async {}

}

class _SequencedNotificationRepository extends _Repo {
  int listCalls = 0;
  final Completer<HopeNotificationPage> staleRefresh =
      Completer<HopeNotificationPage>();

  @override
  Future<HopeNotificationPage> listNotifications({
    int limit = 50,
    int offset = 0,
  }) {
    listCalls += 1;
    if (listCalls == 1) {
      return Future.value(HopeNotificationPage(
        items: items,
        unreadCount: items.where((e) => e.isUnread).length,
      ));
    }
    if (listCalls == 2) return staleRefresh.future;
    return Future.value(const HopeNotificationPage(
      items: [
        HopeNotification(
          id: 'fresh',
          type: 'JOB',
          title: 'Fresh notification',
          body: 'Fresh',
          createdAt: null,
          readAt: null,
        ),
      ],
      unreadCount: 1,
    ));
  }
}

Widget _app(_Repo repo) => MaterialApp(
      theme: ThemeData.light(),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Provider<NotificationRepository>.value(
        value: repo,
        child: const NotificationsPage(),
      ),
    );

void main() {
testWidgets('latest notification refresh wins over an older in-flight load',
      (tester) async {
    final repo = _SequencedNotificationRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('عنوان اعلان'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(repo.listCalls, 2);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(repo.listCalls, 3);
    expect(find.text('Fresh notification'), findsOneWidget);

    repo.staleRefresh.complete(const HopeNotificationPage(
      items: [
        HopeNotification(
          id: 'stale',
          type: 'JOB',
          title: 'عنوان اعلان',
          body: 'متن اعلان',
          createdAt: null,
          readAt: null,
        ),
      ],
      unreadCount: 1,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Fresh notification'), findsOneWidget);
    expect(find.text('عنوان اعلان'), findsNothing);
  });

  testWidgets('notifications page renders unread content', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('عنوان اعلان'), findsOneWidget);
    expect(find.text('متن اعلان'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
  });

  testWidgets('tapping an unread notification marks it read and reloads',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عنوان اعلان'));
    await tester.pumpAndSettle();
    expect(repo.markReadCalls, 1);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });

  testWidgets('empty notification state disables mark-all control',
      (tester) async {
    final repo = _Repo()..items = [];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    final markAll = buttons.where((button) =>
        button.icon is Icon &&
        (button.icon as Icon).icon == Icons.done_all_rounded);
    expect(markAll, hasLength(1));
    expect(markAll.single.onPressed, isNull);
  });
}
