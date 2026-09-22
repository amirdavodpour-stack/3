import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/notifications/notification_repository.dart';
import 'package:hope_mobile/features/notifications/notification_devices_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

HopeNotificationDevice _device(String id, String platform) =>
    HopeNotificationDevice(
      id: id,
      platform: platform,
      enabled: true,
    );

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

Widget _host(_SequencedDeviceRepository repository) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Provider<NotificationRepository>.value(
        value: repository,
        child: const NotificationDevicesPage(),
      ),
    );

void main() {
  testWidgets('latest device refresh wins over an older in-flight load',
      (tester) async {
    final repository = _SequencedDeviceRepository();
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

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
}
