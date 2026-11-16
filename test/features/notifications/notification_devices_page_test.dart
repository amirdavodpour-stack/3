import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/notifications/notification.dart';
import 'package:hope_mobile/core/notifications/notification_repository.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/features/notifications/notification_devices_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

HopeNotificationDevice _device(String id, String platform) =>
    HopeNotificationDevice(
      id: id,
      platform: platform,
      enabled: true,
    );

class _PendingDeviceRepository extends _SequencedDeviceRepository {
  final Completer<List<HopeNotificationDevice>> pending =
      Completer<List<HopeNotificationDevice>>();

  @override
  Future<List<HopeNotificationDevice>> listDevices() => pending.future;
}

class _LongDeviceRepository extends _SequencedDeviceRepository {
  @override
  Future<List<HopeNotificationDevice>> listDevices() async =>
      [_device('compact-ios', 'IOS')];
}

class _SequencedDeviceRepository implements NotificationRepository {
  int listCalls = 0;
  final Completer<List<HopeNotificationDevice>> staleRefresh =
      Completer<List<HopeNotificationDevice>>();

  @override
  Future<List<HopeNotificationDevice>> listDevices() {
    listCalls += 1;
    if (listCalls == 1) return Future.value([_device('initial', 'ANDROID')]);
    if (listCalls == 2) return staleRefresh.future;
    return Future.value([_device('fresh', 'IOS')]);
  }

  @override
  Future<void> disableDevice(String id) async {}

  @override
  Future<HopeNotificationPage> listNotifications({
    int limit = 50,
    int offset = 0,
  }) =>
      throw UnimplementedError();

  @override
  Future<HopeNotification> markRead(String id) =>
      throw UnimplementedError();

  @override
  Future<int> markAllRead() async => 0;

  @override
  Future<HopeNotificationPreferences> getPreferences() =>
      throw UnimplementedError();

  @override
  Future<HopeNotificationPreferences> updatePreferences(
    Map<String, bool> patch,
  ) =>
      throw UnimplementedError();
}

Widget _host(
  _SequencedDeviceRepository repository, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) =>
    MaterialApp(
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
        value: repository,
        child: const NotificationDevicesPage(),
      ),
    );

void main() {
  testWidgets(
    'notification device loading uses a card-shaped skeleton instead of a lone spinner',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _PendingDeviceRepository();
      await tester.pumpWidget(_host(repository));
      await tester.pump();

      final panel = find.byType(PremiumPanel).first;
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SkeletonBox), findsAtLeastNWidgets(3));
      expect(
        tester.getSize(panel).height,
        lessThanOrEqualTo(112),
        reason: 'Device loading should preview the same compact row shape as the loaded device card.',
      );
      expect(tester.takeException(), isNull);

      repository.pending.complete(const []);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('latest device refresh wins over an older in-flight load',
      (tester) async {
    final repository = _SequencedDeviceRepository();
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(
      tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame)).padding.bottom,
      24,
      reason: 'Device settings use the scroll tail and avoid a second large page-frame gutter.',
    );
    expect(find.text('Android'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(repository.listCalls, 2);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 3);
    expect(find.text('iPhone / iPad'), findsOneWidget);

    repository.staleRefresh.complete([_device('stale', 'ANDROID')]);
    await tester.pumpAndSettle();

    expect(find.text('iPhone / iPad'), findsOneWidget);
    expect(find.text('Android'), findsNothing);
  });
  testWidgets(
    'notification device title retains usable width beside disable action at 1.5x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _LongDeviceRepository();
      await tester.pumpWidget(
        _host(
          repository,
          locale: const Locale('fa'),
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text('iPhone / iPad');
      final actionFinder = find.text('غیرفعال کنید');
      expect(titleFinder, findsOneWidget);
      expect(actionFinder, findsOneWidget);

      final titleRect = tester.getRect(titleFinder);
      final actionRect = tester.getRect(actionFinder);
      expect(
        titleRect.width,
        greaterThanOrEqualTo(96),
        reason: 'The device title must not be squeezed into a narrow sliver by the trailing action.',
      );
      expect(titleRect.left, greaterThanOrEqualTo(0));
      expect(titleRect.right, lessThanOrEqualTo(320));
      expect(actionRect.left, greaterThanOrEqualTo(0));
      expect(actionRect.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    },
  );

}
