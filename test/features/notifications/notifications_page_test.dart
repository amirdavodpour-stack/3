import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/notifications/notification.dart';
import 'package:hope_mobile/core/notifications/notification_repository.dart';
import 'package:hope_mobile/core/ui/hope_async_state.dart';
import 'package:hope_mobile/features/notifications/notifications_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _Repo implements NotificationRepository {
  int readAllCalls = 0;
  int markReadCalls = 0;
  bool failList = false;
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
  Future<HopeNotificationPage> listNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    if (failList) throw StateError('list failed');
    return HopeNotificationPage(
      items: items,
      unreadCount: items.where((e) => e.isUnread).length,
    );
  }

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
              readAt: 'now',
            )
          else
            items[i],
      ];
    }
    return items[index];
  }

  @override
  Future<HopeNotificationPreferences> getPreferences() async =>
      const HopeNotificationPreferences(
        inApp: true,
        push: true,
        email: true,
        jobAlerts: true,
        applicationUpdates: true,
        paymentUpdates: true,
        marketing: false,
      );

  @override
  Future<HopeNotificationPreferences> updatePreferences(
    Map<String, bool> patch,
  ) async =>
      getPreferences();

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
          readAt: 'now',
        ),
    ];
    return items.length;
  }

  @override
  Future<List<HopeNotificationDevice>> listDevices() async => const [];

  @override
  Future<void> disableDevice(String id) async {}
}

class _PendingNotificationRepository extends _Repo {
  final Completer<HopeNotificationPage> initialLoad =
      Completer<HopeNotificationPage>();

  @override
  Future<HopeNotificationPage> listNotifications({
    int limit = 50,
    int offset = 0,
  }) =>
      initialLoad.future;
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

Widget _app(
  _Repo repo, {
  Locale locale = const Locale('fa'),
  double textScale = 1,
}) => MaterialApp(
      theme: ThemeData.light(),
      locale: locale,
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Provider<NotificationRepository>.value(
        value: repo,
        child: const NotificationsPage(),
      ),
    );

void main() {
  testWidgets(
    'Wave49 Notifications preserve title/body at narrow FA-RTL and EN-LTR 1.5x',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const locales = [Locale('fa'), Locale('en')];
      const widths = [320.0, 360.0, 600.0, 1200.0];
      for (final locale in locales) {
        for (final width in widths) {
          final scales = width <= 360 ? [1.0, 1.5] : [1.0];
          for (final scale in scales) {
            final repo = _Repo()
              ..items = [
                HopeNotification(
                  id: 'responsive',
                  type: 'JOB',
                  title: locale.languageCode == 'fa'
                      ? 'اعلان مهم برای بررسی چیدمان در صفحه باریک و متن بزرگ'
                      : 'An important notification title for the narrow and enlarged responsive layout',
                  body: locale.languageCode == 'fa'
                      ? 'این پیام جزئیات اعلان را در عرض کم و اندازه متن بزرگ حفظ می‌کند تا متن مهم پنهان نشود.'
                      : 'This notification body contains the details needed to understand the event and must remain readable on a narrow viewport with enlarged text.',
                  createdAt: null,
                  readAt: null,
                ),
              ];
            tester.view.physicalSize = Size(width, 800);
            await tester.pumpWidget(
              _app(repo, locale: locale, textScale: scale),
            );
            await tester.pumpAndSettle();

            final titleFinder =
                find.byKey(const ValueKey('notification-title-responsive'));
            final bodyFinder =
                find.byKey(const ValueKey('notification-body-responsive'));
            final unreadTagFinder = find.byKey(
              const ValueKey('notification-unread-tag-responsive'),
            );
            expect(titleFinder, findsOneWidget);
            expect(bodyFinder, findsOneWidget);
            expect(unreadTagFinder, findsOneWidget);
            final titleWidget = tester.widget<Text>(titleFinder);
            final bodyWidget = tester.widget<Text>(bodyFinder);
            final titleRect = tester.getRect(titleFinder);
            final bodyRect = tester.getRect(bodyFinder);
            final tagRect = tester.getRect(unreadTagFinder);
            expect(titleRect.left, greaterThanOrEqualTo(0));
            expect(titleRect.right, lessThanOrEqualTo(width));
            expect(bodyRect.left, greaterThanOrEqualTo(0));
            expect(bodyRect.right, lessThanOrEqualTo(width));
            expect(tagRect.left, greaterThanOrEqualTo(0));
            expect(tagRect.right, lessThanOrEqualTo(width));
            if (width < 380 || scale > 1.2) {
              expect(titleWidget.maxLines, isNull);
              expect(bodyWidget.maxLines, isNull);
              expect(tagRect.top, greaterThan(titleRect.bottom - 1));
            } else {
              expect(titleWidget.maxLines, 2);
              expect(bodyWidget.maxLines, 3);
            }
            expect(
              tester.takeException(),
              isNull,
              reason: 'Unexpected notification layout at ${locale.languageCode}, ${width}dp, ${scale}x.',
            );
          }
        }
      }
    },
  );

  testWidgets(
    'notifications loading uses the canonical async state inside the page shell',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _PendingNotificationRepository();
      await tester.pumpWidget(_app(repo));
      await tester.pump();

      expect(find.byType(HopeAsyncState), findsOneWidget);
      final loadingTitle = find.text('در حال بارگذاری اعلان‌ها');
      expect(loadingTitle, findsOneWidget);
      final contentList = find.byType(ListView).last;
      expect(
        tester.getTopLeft(loadingTitle).dy -
            tester.getTopLeft(contentList).dy,
        lessThan(120),
        reason: 'Loading feedback should not be pushed down by a large decorative spacer.',
      );
      expect(
        find.text('به‌روزرسانی درخواست‌ها، کارها و پرداخت‌ها • همه خوانده شده‌اند'),
        findsNothing,
      );

      repo.initialLoad.complete(
        const HopeNotificationPage(
          items: [],
          unreadCount: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('اعلانی وجود ندارد'), findsOneWidget);
    },
  );

  testWidgets(
    'notifications error uses the canonical async state and retry recovers',
    (tester) async {
      final repo = _Repo()..failList = true;
      await tester.pumpWidget(_app(repo));
      await tester.pump();
      await tester.pump();

      expect(find.byType(HopeAsyncState), findsOneWidget);
      expect(find.text('اعلان‌ها در دسترس نیستند'), findsOneWidget);
      expect(
        find.text('به‌روزرسانی درخواست‌ها، کارها و پرداخت‌ها • همه خوانده شده‌اند'),
        findsNothing,
      );

      repo.failList = false;
      await tester.tap(find.text('تلاش دوباره'));
      await tester.pumpAndSettle();

      expect(find.text('اعلان‌ها در دسترس نیستند'), findsNothing);
      expect(find.text('عنوان اعلان'), findsOneWidget);
    },
  );

  testWidgets('latest notification refresh wins over an older in-flight load',
      (tester) async {
    final repo = _SequencedNotificationRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('عنوان اعلان'), findsOneWidget);

    final refreshIndicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first);
    final firstRefresh = refreshIndicator.onRefresh();
    await tester.pump();
    expect(repo.listCalls, 2);

    final secondRefresh = refreshIndicator.onRefresh();
    await tester.pumpAndSettle();
    await secondRefresh;

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
    await firstRefresh;
    await tester.pumpAndSettle();

    expect(find.text('Fresh notification'), findsOneWidget);
    expect(find.text('عنوان اعلان'), findsNothing);
  });

  testWidgets(
    'read actionable notification cards expose their action as a semantic button',
    (tester) async {
      final repo = _Repo()
        ..items = [
          const HopeNotification(
            id: 'read-action',
            type: 'JOB_APPLICATION_RECEIVED',
            title: 'به‌روزرسانی درخواست',
            body: 'یک درخواست جدید برای بررسی وجود دارد.',
            createdAt: '2026-10-15T10:30:00Z',
            readAt: '2026-10-15T11:00:00Z',
            data: {'jobId': 'job-42'},
          ),
        ];
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_app(repo));
        await tester.pumpAndSettle();

        final card = find.byKey(
          const ValueKey('notification-card-read-action'),
        );
        expect(card, findsOneWidget);

        final actionableSemantics = find.bySemanticsLabel(
          RegExp('به‌روزرسانی درخواست.*مشاهده پروژه'),
        );
        expect(
          actionableSemantics,
          findsOneWidget,
          reason: 'A read notification with a valid route must expose its title and action to screen readers.',
        );
        final semanticData = tester.getSemantics(actionableSemantics).getSemanticsData();
        expect(semanticData.label, contains('به‌روزرسانی درخواست'));
        expect(semanticData.label, contains('مشاهده پروژه'));
        expect(semanticData.hasFlag(SemanticsFlag.isButton), isTrue);
        expect(semanticData.hasAction(SemanticsAction.tap), isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('notifications page renders unread content', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('عنوان اعلان'), findsOneWidget);
    expect(find.text('متن اعلان'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-card-n1')), findsOneWidget);
    expect(find.text('جدید'), findsOneWidget);
  });

  testWidgets(
    'payment notification without a routeable job id does not show a dead-end CTA',
    (tester) async {
      final repo = _Repo()..items = [
        const HopeNotification(
          id: 'payment-without-job',
          type: 'PAYMENT_UPDATE',
          title: 'Payment update',
          body: 'Payment details are unavailable.',
          createdAt: null,
          readAt: 'now',
          data: {'paymentId': 'payment-123'},
        ),
      ];
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.text('Payment update'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'مشاهده پرداخت'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping an unread notification marks it read and reloads',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عنوان اعلان'));
    await tester.pumpAndSettle();
    expect(repo.markReadCalls, 1);
    expect(find.text('جدید'), findsNothing);
  });

  testWidgets(
    'refresh failure keeps the current notifications visible with a retry action',
    (tester) async {
      final repo = _Repo();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      final existing = find.byKey(const ValueKey('notification-card-n1'));
      expect(existing, findsOneWidget);
      expect(find.text('عنوان اعلان'), findsOneWidget);

      repo.failList = true;
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator).first,
      );
      await refresh.onRefresh();
      await tester.pumpAndSettle();

      expect(find.text('اعلان‌ها قابل تازه‌سازی نیستند'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
      expect(existing, findsOneWidget);
      expect(find.text('عنوان اعلان'), findsOneWidget);
      expect(tester.takeException(), isNull);

      repo.failList = false;
      await tester.tap(find.text('تلاش دوباره'));
      await tester.pumpAndSettle();

      expect(find.text('اعلان‌ها قابل تازه‌سازی نیستند'), findsNothing);
      expect(existing, findsOneWidget);
      expect(find.text('عنوان اعلان'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty notification state disables mark-all control',
      (tester) async {
    final repo = _Repo()..items = [];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    final menu = find.byTooltip('اقدامات اعلان');
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final markAll = find.text('همه را خواندم');
    expect(markAll, findsOneWidget);
    final item = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: markAll,
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(item.enabled, isFalse);
  });
  testWidgets('notification unread counts use Persian digits', (tester) async {
    await tester.pumpWidget(_app(_Repo()));
    await tester.pumpAndSettle();

    expect(find.textContaining('۱ اعلان خوانده‌نشده'), findsOneWidget);
  });

}
