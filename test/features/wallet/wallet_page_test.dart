import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/config/backend_capabilities.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/features/wallet/wallet_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _WalletEnabledCapabilities implements BackendCapabilitiesRepository {
  @override
  Future<BackendCapabilities> load() async => const BackendCapabilities(
        wallet: true,
        walletTransfer: true,
        walletWithdraw: true,
      );
}

class _FakeWallet implements WalletRepository {
  _FakeWallet({
    this.currency = 'TOMAN',
    this.transactionCurrency = 'TOMAN',
    this.payoutCurrency = 'TOMAN',
    this.payoutStatus = 'REQUESTED',
    this.entryType = 'TRANSFER',
    this.direction = 'CREDIT',
    this.pendingWithdrawalBalance = 0,
    this.availableBalance = 2500000,
    this.lockedBalance = 1000000,
    this.escrowBalance = 1000000,
    this.totalBalance = 3500000,
  });

  final String currency;
  final String transactionCurrency;
  final String payoutCurrency;
  final String payoutStatus;
  final String entryType;
  final String direction;
  final int pendingWithdrawalBalance;
  final int availableBalance;
  final int lockedBalance;
  final int escrowBalance;
  final int totalBalance;
  Object? transferError;
  bool failLoad = false;

  @override
  Future<HopeWallet> getWallet() async {
    if (failLoad) throw StateError('wallet refresh unavailable');
    return HopeWallet.fromMap({
        'id': 'wallet-1',
        'userId': 'u1',
        'currency': currency,
        'availableBalance': availableBalance,
        'lockedBalance': lockedBalance,
        'escrowBalance': escrowBalance,
        'pendingWithdrawalBalance': pendingWithdrawalBalance,
        'totalBalance': totalBalance,
        'status': 'ACTIVE',
      });
  }

  @override
  Future<WalletTransactionsPage> listTransactions({
    int limit = 30,
    String? cursor,
  }) async =>
      WalletTransactionsPage(
        items: [
          HopeWalletTransaction.fromMap({
            'id': 'tx-1',
            'entryType': entryType,
            'direction': direction,
            'amount': 500000,
            'currency': transactionCurrency,
            'referenceType': 'TRANSFER',
            'referenceId': 'ref-1',
            'financialOperationId': 'op-1',
            'createdAt': '2026-09-21T00:00:00Z',
          }),
        ],
      );

  @override
  Future<List<HopePayout>> listPayouts() async => [
        HopePayout.fromMap({
          'id': 'payout-1',
          'walletId': 'wallet-1',
          'amount': 400000,
          'currency': payoutCurrency,
          'provider': 'internal',
          'status': payoutStatus,
          'idempotencyKey': 'key-1',
        }),
      ];

  @override
  Future<Map<String, dynamic>> transfer({
    required String destinationWalletId,
    required int amount,
    required String idempotencyKey,
  }) async {
    if (transferError != null) throw transferError!;
    return const {};
  }

  @override
  Future<Map<String, dynamic>> requestPayout({
    required int amount,
    required String idempotencyKey,
  }) async =>
      const {};

  @override
  Future<Map<String, dynamic>> topUp({
    required int amount,
    required String idempotencyKey,
  }) async =>
      const {};
}

class _PagedWallet implements WalletRepository {
  final Completer<WalletTransactionsPage> olderPage =
      Completer<WalletTransactionsPage>();
  int transactionCalls = 0;

  HopeWallet _wallet(int balance) => HopeWallet.fromMap({
        'id': 'wallet-1',
        'userId': 'u1',
        'currency': 'TOMAN',
        'availableBalance': balance,
        'lockedBalance': 1000000,
        'status': 'ACTIVE',
      });

  HopeWalletTransaction _tx(String id, int amount) =>
      HopeWalletTransaction.fromMap({
        'id': id,
        'entryType': 'TRANSFER',
        'direction': 'CREDIT',
        'amount': amount,
        'currency': 'TOMAN',
        'referenceType': 'TRANSFER',
        'financialOperationId': 'op-$id',
        'createdAt': '2026-09-21T00:00:00Z',
      });

  @override
  Future<HopeWallet> getWallet() async => _wallet(2500000);

  @override
  Future<WalletTransactionsPage> listTransactions({
    int limit = 30,
    String? cursor,
  }) async {
    transactionCalls += 1;
    if (cursor == null) {
      return WalletTransactionsPage(
        items: [_tx('fresh', 7000000)],
        nextCursor: 'cursor-1',
      );
    }
    return olderPage.future;
  }

  @override
  Future<List<HopePayout>> listPayouts() async => const [];

  @override
  Future<Map<String, dynamic>> transfer({
    required String destinationWalletId,
    required int amount,
    required String idempotencyKey,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> requestPayout({
    required int amount,
    required String idempotencyKey,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> topUp({
    required int amount,
    required String idempotencyKey,
  }) async => const {};
}


class _ConcurrentWallet implements WalletRepository {
  int _getWalletCalls = 0;
  final Completer<HopeWallet> firstRefresh = Completer<HopeWallet>();

  HopeWallet _wallet(int balance) => HopeWallet.fromMap({
        'id': 'wallet-concurrent',
        'userId': 'u1',
        'currency': 'TOMAN',
        'availableBalance': balance,
        'lockedBalance': 0,
        'status': 'ACTIVE',
      });

  @override
  Future<HopeWallet> getWallet() async {
    _getWalletCalls += 1;
    if (_getWalletCalls == 1) return _wallet(2500000);
    if (_getWalletCalls == 2) return firstRefresh.future;
    return _wallet(9900000);
  }

  @override
  Future<WalletTransactionsPage> listTransactions({
    int limit = 30,
    String? cursor,
  }) async => const WalletTransactionsPage(items: []);

  @override
  Future<List<HopePayout>> listPayouts() async => const [];

  @override
  Future<Map<String, dynamic>> transfer({
    required String destinationWalletId,
    required int amount,
    required String idempotencyKey,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> requestPayout({
    required int amount,
    required String idempotencyKey,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> topUp({
    required int amount,
    required String idempotencyKey,
  }) async => const {};
}

class _AuthRepo implements AuthRepository {
  @override
  Future<AuthSession> loginWithGoogle(String _) =>
      throw UnimplementedError();
  @override
  Future<AuthSession> login(String e, String p) => throw UnimplementedError();
  @override
  Future<AuthSession> register(String e, String p, String n) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset(String e) async {}
}

void main() {
  testWidgets(
    'Wave 43 payout amount and status stay consistent between history row and details',
    (tester) async {
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _FakeWallet(payoutStatus: 'REQUESTED');

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Withdrawals'),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      final historyAmount = find.text('400,000 TOMAN');
      final historyStatus = find.text('Requested');
      expect(historyAmount, findsOneWidget);
      expect(historyStatus, findsOneWidget);

      await tester.tap(historyStatus);
      await tester.pumpAndSettle();

      final detailsSheet = find.byType(BottomSheet);
      expect(detailsSheet, findsOneWidget);
      expect(find.descendant(of: detailsSheet, matching: find.text('Withdrawal details')), findsOneWidget);
      expect(find.descendant(of: detailsSheet, matching: find.text('Amount')), findsOneWidget);
      expect(find.descendant(of: detailsSheet, matching: find.text('Status')), findsOneWidget);
      expect(
        find.descendant(of: detailsSheet, matching: find.text('400,000 TOMAN')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: detailsSheet, matching: find.text('Requested')),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending withdrawal summary agrees with the reserved payout row',
    (tester) async {
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _FakeWallet(
        payoutStatus: 'RESERVED',
        pendingWithdrawalBalance: 400000,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pendingMetric =
          find.byKey(const ValueKey('wallet-balance-metric-pending'));
      expect(pendingMetric, findsOneWidget);
      expect(
        find.descendant(
          of: pendingMetric,
          matching: find.text('۴۰۰٬۰۰۰ تومان'),
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('برداشت‌ها'),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('۴۰۰٬۰۰۰ تومان'), findsNWidgets(2));
      expect(find.text('رزروشده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an older refresh response cannot overwrite a newer refresh result',
    (tester) async {
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _ConcurrentWallet();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2,500,000 TOMAN'), findsWidgets);

      final refreshIndicator =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      final olderRefresh = refreshIndicator.onRefresh();
      await tester.pump();

      final newerRefresh = refreshIndicator.onRefresh();
      await newerRefresh;
      await tester.pumpAndSettle();

      expect(find.textContaining('9,900,000 TOMAN'), findsWidgets);

      wallet.firstRefresh.complete(wallet._wallet(2500000));
      await olderRefresh;
      await tester.pumpAndSettle();

      expect(find.textContaining('9,900,000 TOMAN'), findsWidgets);
      expect(find.textContaining('2,500,000 TOMAN'), findsNothing);
    },
  );


  testWidgets(
    'refresh invalidates an older wallet load-more response',
    (tester) async {
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _PagedWallet();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final loadMore = find.byKey(
        const ValueKey('wallet-transactions-load-more'),
      );
      await tester.scrollUntilVisible(
        loadMore,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(loadMore);
      await tester.pump();
      await tester.tap(loadMore);
      await tester.pump();

      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(
        find.textContaining('7,000,000'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('7,000,000'), findsOneWidget);

      wallet.olderPage.complete(
        WalletTransactionsPage(
          items: [_PagedWallet()._tx('stale', 9999999)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('9,999,999 Toman'), findsNothing);
      expect(find.textContaining('7,000,000'), findsOneWidget);
    },
  );

  testWidgets(
    'wallet keeps total balance, available, protected and pending signals distinct',
    (tester) async {
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: _FakeWallet()),
            ],
            child: WalletPage(repository: _FakeWallet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('۳٬۵۰۰٬۰۰۰ تومان'), findsOneWidget);
      expect(find.textContaining('۲٬۵۰۰٬۰۰۰ تومان'), findsOneWidget);
      expect(find.text('قابل استفاده'), findsOneWidget);
      expect(find.text('در امانت HOPE'), findsOneWidget);
      expect(find.text('محافظت‌شده'), findsNothing);
      expect(find.text('برداشت در انتظار'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('برداشت‌ها'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('برداشت‌ها'), findsOneWidget);
    },
  );

  testWidgets(
    'wallet hero exposes compact financial signals without inventing lifetime balance',
    (tester) async {
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _FakeWallet();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('wallet-balance-hero')), findsOneWidget);
      expect(find.text('کل موجودی'), findsOneWidget);
      expect(find.text('شامل مبالغ قفل‌شده است'), findsOneWidget);
      expect(find.text('کل قفل‌شده'), findsOneWidget);
      expect(find.text('برداشت در انتظار'), findsOneWidget);
      expect(find.text('موجودی مادام‌العمر'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('برداشت‌ها'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('برداشت‌ها'), findsOneWidget);
    },
  );

  testWidgets('very large wallet balances keep the compact hero in a two-column metric grid',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    const large = 9123456789123456789;
    final wallet = _FakeWallet(
      availableBalance: large,
      lockedBalance: 1000000,
      escrowBalance: 1000000,
      totalBalance: 3500000,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('wallet-balance-hero'));
    final available = find.byKey(const ValueKey('wallet-balance-metric-available'));
    final held = find.byKey(const ValueKey('wallet-balance-metric-protected'));
    expect(hero, findsOneWidget);
    expect(available, findsOneWidget);
    expect(held, findsOneWidget);
    expect(tester.getSize(available).width, lessThan(240));
    expect(tester.getSize(held).width, lessThan(240));
    expect(tester.getSize(hero).height, lessThan(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet initial error state keeps recovery near the first fold',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    final wallet = _FakeWallet()..failLoad = true;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final errorTitle = find.text('Wallet could not be loaded');
    expect(errorTitle, findsOneWidget);
    expect(
      tester.getTopLeft(errorTitle).dy,
      lessThan(120),
      reason: 'The initial error state should not push recovery below a 160dp spacer.',
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet refresh failure keeps stale wallet visible with retry error',
      (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    final wallet = _FakeWallet();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2,500,000 TOMAN'), findsWidgets);
    wallet.failLoad = true;

    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('2,500,000 TOMAN'), findsWidgets);
    expect(find.text('Wallet refresh failed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'wallet history rows stay compact when the visible facts fit on two lines',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _FakeWallet();

      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
              Provider<BackendCapabilitiesRepository>.value(
                value: _WalletEnabledCapabilities(),
              ),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('wallet-history-entry-tx-1'));
      await tester.scrollUntilVisible(
        card,
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(card, findsOneWidget);
      expect(find.text('Internal transfer'), findsOneWidget);
      expect(find.text('+500,000 TOMAN'), findsOneWidget);
      expect(
        tester.getSize(card).height,
        lessThan(100),
        reason:
            'When title, date and amount fit, a compact wallet row should not reserve a third line.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wallet history cards avoid duplicate reference text and expose date to assistive tech',
    (tester) async {
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _FakeWallet();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: auth),
                Provider<WalletRepository>.value(value: wallet),
              ],
              child: WalletPage(repository: wallet),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final card = find.byKey(
          const ValueKey('wallet-history-entry-tx-1'),
        );
        await tester.scrollUntilVisible(
          card,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final tile = tester.widget<ListTile>(
          find.descendant(of: card, matching: find.byType(ListTile)),
        );
        final subtitle = tile.subtitle as Text;
        expect(subtitle.data, isNotEmpty);
        expect(subtitle.data, isNot(contains('انتقال داخلی')));
        expect(subtitle.data, isNot(contains('\n')));

        final rowSemantics = find.ancestor(
          of: card,
          matching: find.byType(Semantics),
        ).first;
        final semanticLabel = tester.getSemantics(rowSemantics).label;
        expect(
          semanticLabel,
          contains(subtitle.data),
          reason: 'The date shown in the ledger row must also be present in its grouped screen-reader label.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('wallet transaction rows expose grouped finance semantics',
      (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    final wallet = _FakeWallet();

    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('انتقال داخلی'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final semanticAncestors = find.ancestor(
      of: find.text('انتقال داخلی'),
      matching: find.byType(Semantics),
    );
    expect(semanticAncestors, findsAtLeastNWidgets(1));
    final labels = <String>[];
    for (var i = 0; i < semanticAncestors.evaluate().length; i++) {
      labels.add(tester.getSemantics(semanticAncestors.at(i)).label);
    }
    expect(
      labels.any((label) => label.contains('انتقال داخلی')),
      isTrue,
    );
    expect(
      labels.any((label) => label.contains('\u2066+۵۰۰٬۰۰۰ تومان\u2069')),
      isTrue,
    );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('wallet payout rows expose grouped finance semantics',
      (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    final wallet = _FakeWallet();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('برداشت‌ها'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    try {
      final row = find.ancestor(
        of: find.text('درخواست‌شده'),
        matching: find.byType(Semantics),
      ).first;
      final node = tester.getSemantics(row);
      expect(node.label, '۴۰۰٬۰۰۰ تومان، کیف پول داخلی، درخواست‌شده');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('wallet treats backend ledger currencies as internal Toman',
      (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    final wallet = _FakeWallet(
      currency: 'IRR',
      transactionCurrency: 'IRR',
      payoutCurrency: 'IRR',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('3,500,000 TOMAN'), findsOneWidget);
    expect(find.textContaining('2,500,000 IRR'), findsNothing);
    expect(find.textContaining('1,000,000 TOMAN'), findsWidgets);
    expect(find.textContaining('IRR'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('+500,000 TOMAN'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('+500,000 TOMAN'), findsOneWidget);
    expect(find.text('+500,000 IRR'), findsNothing);

    await tester.scrollUntilVisible(
      find.textContaining('400,000 TOMAN'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('400,000 TOMAN'), findsOneWidget);
    expect(find.text('400,000 IRR'), findsNothing);
  });
  testWidgets('wallet credit and debit amounts use semantic foregrounds in light and dark themes',
      (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final isCredit in [true, false]) {
        final auth = AuthController(_AuthRepo(), SecureStore());
        await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
        final wallet = _FakeWallet(direction: isCredit ? 'CREDIT' : 'DEBIT');
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? ThemeData.dark()
                : ThemeData.light(),
            locale: const Locale('en'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: auth),
                Provider<WalletRepository>.value(value: wallet),
              ],
              child: WalletPage(repository: wallet),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final amountLabel = isCredit ? '+500,000 TOMAN' : '-500,000 TOMAN';
        final transactionRow = find.byKey(
          const ValueKey('wallet-history-entry-tx-1'),
        );
        await tester.scrollUntilVisible(
          transactionRow,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final amountFinder = find.descendant(
          of: transactionRow,
          matching: find.text(amountLabel),
        );
        final amountText = tester.widget<Text>(amountFinder);
        final amountContext = tester.element(amountFinder);
        expect(
          amountText.style?.color,
          isCredit
              ? HopeV2SemanticColors.incomingAmount(amountContext)
              : HopeV2SemanticColors.negativeAmount(amountContext),
          reason: 'Credit/debit amounts must use semantic foreground roles in $brightness mode.',
        );
        expect(
          amountText.style?.color,
          isNot(Theme.of(amountContext).colorScheme.primary),
          reason: 'Ledger amounts must not use the brand action foreground in $brightness mode.',
        );
      }
    }
  });

  testWidgets('pending payout amount and label use warning semantics in light and dark themes',
      (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _FakeWallet(payoutStatus: 'RESERVED');
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark
              ? ThemeData.dark()
              : ThemeData.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Reserved'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final amountFinder = find.text('400,000 TOMAN');
      final statusFinder = find.text('Reserved');
      final context = tester.element(statusFinder);
      expect(
        tester.widget<Text>(amountFinder).style?.color,
        HopeV2SemanticColors.pendingAmount(context),
      );
      expect(
        tester.widget<Text>(statusFinder).style?.color,
        HopeV2SemanticColors.pending(context),
      );
      expect(
        tester.widget<Text>(statusFinder).style?.color,
        isNot(Theme.of(context).colorScheme.primary),
        reason: 'Pending payout status is semantic state, not a brand action label.',
      );
      expect(
        tester.widget<Text>(amountFinder).style?.color,
        isNot(Theme.of(context).colorScheme.primary),
        reason: 'Pending payout amounts must not be colored as primary actions.',
      );
    }
  });

  testWidgets('wallet presents backend enums as localized user-facing labels',
      (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: _FakeWallet()),
          ],
          child: WalletPage(repository: _FakeWallet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsWidgets);
    expect(find.text('ACTIVE'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Wallet history'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Internal transfer'), findsWidgets);
    expect(find.text('TRANSFER'), findsNothing);

    await tester.tap(find.text('Internal transfer').first);
    await tester.pumpAndSettle();

    expect(find.text('Credit'), findsOneWidget);
    expect(find.text('CREDIT'), findsNothing);
    expect(find.text('Entry type'), findsOneWidget);
    expect(find.text('Reference type'), findsOneWidget);
    expect(find.text('ref-1'), findsNothing);
    expect(find.text('op-1'), findsNothing);
  });

  testWidgets('wallet does not expose raw unknown ledger entry types',
      (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    final wallet = _FakeWallet(entryType: 'RECONCILIATION_ENTRY');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Wallet history'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Internal transfer').first);
    await tester.pumpAndSettle();

    final detailsSheet = find.byType(BottomSheet);
    expect(detailsSheet, findsOneWidget);
    expect(
      find.descendant(
        of: detailsSheet,
        matching: find.text('Other activity'),
      ),
      findsOneWidget,
    );
    expect(find.text('RECONCILIATION_ENTRY'), findsNothing);
  });

  testWidgets('wallet uses a safe localized fallback for unknown payout statuses',
      (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});

    final wallet = _FakeWallet(payoutStatus: 'AWAITING_PROVIDER_RECONCILIATION');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('400,000 TOMAN'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('400,000 TOMAN'));
    await tester.pumpAndSettle();

    expect(find.text('Needs review'), findsWidgets);
    expect(find.text('AWAITING_PROVIDER_RECONCILIATION'), findsNothing);
  });

  testWidgets('wallet localizes finance copy and provider labels',
      (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});

    final wallet = _FakeWallet();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ledger entries'), findsNothing);
    expect(find.textContaining('cursor'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('۴۰۰٬۰۰۰ تومان'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('۴۰۰٬۰۰۰ تومان'));
    await tester.pumpAndSettle();

    final detailsSheet = find.byType(BottomSheet);
    expect(detailsSheet, findsOneWidget);
    expect(
      find.descendant(
        of: detailsSheet,
        matching: find.text('کیف پول داخلی'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: detailsSheet,
        matching: find.text('internal'),
      ),
      findsNothing,
    );
  });

  testWidgets('wallet does not expose raw API errors in action failures',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    final wallet = _FakeWallet()
      ..transferError = ApiException(
        'INSUFFICIENT_FUNDS',
        'backend-only diagnostic detail',
        status: 409,
      );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
              Provider<BackendCapabilitiesRepository>.value(
                value: _WalletEnabledCapabilities(),
              ),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Wallet actions')); await tester.pumpAndSettle(); await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-transfer-destination')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-transfer-amount')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('wallet-transfer-destination')),
      'wallet-destination',
    );
    await tester.enterText(
      find.byKey(const ValueKey('wallet-transfer-amount')),
      '1000',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Transfer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('INSUFFICIENT_FUNDS'), findsNothing);
    expect(find.textContaining('backend-only diagnostic detail'), findsNothing);
    expect(find.text('Action could not be completed.'), findsOneWidget);
  });


  testWidgets('wallet transfer dialog formats the available limit in Toman',
      (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    final wallet = _FakeWallet();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
              Provider<BackendCapabilitiesRepository>.value(
                value: _WalletEnabledCapabilities(),
              ),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Wallet actions')); await tester.pumpAndSettle(); await tester.tap(find.text('Transfer').first);
    await tester.pumpAndSettle();

    expect(find.text('Maximum: 2,500,000 TOMAN'), findsOneWidget);
    expect(find.text('Maximum: 2500000'), findsNothing);
    expect(find.textContaining('TOMAN'), findsWidgets);
    expect(find.text('Toman'), findsNothing);
  });

  testWidgets('wallet uses a compact finance header on narrow surfaces', (tester) async {
    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
    final wallet = _FakeWallet();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<WalletRepository>.value(value: wallet),
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('wallet-finance-header'));
    expect(header, findsOneWidget);
    expect(tester.getSize(header).height, lessThan(120));
    expect(
      tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame)).padding.bottom,
      12,
      reason: 'The wallet ListView already owns navigation-aware end padding; its outer frame should stay compact.',
    );

    expect(find.byKey(const ValueKey('wallet-balance-hero')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-provider-status')), findsOneWidget);
    final historyGap = find.byKey(
      const ValueKey('wallet-history-transition-gap'),
    );
    expect(historyGap, findsOneWidget);
    expect(tester.getSize(historyGap).height, 4);
    final availableMetric =
        find.byKey(const ValueKey('wallet-balance-metric-available'));
    expect(availableMetric, findsOneWidget);
    expect(tester.getSize(availableMetric).height, greaterThanOrEqualTo(42));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wallet actions stay in the first mobile viewport',
    (tester) async {
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _FakeWallet();

      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final actions =
          find.byKey(const ValueKey('wallet-actions-panel'));
      expect(actions, findsOneWidget);
      expect(tester.getBottomRight(actions).dy, lessThan(830));
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'wallet action labels do not truncate at 1.5x on a compact viewport',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _FakeWallet();

      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
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
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
              Provider<BackendCapabilitiesRepository>.value(
                value: _WalletEnabledCapabilities(),
              ),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // This fixture enables withdrawal; deposit is disabled by its backend capability state.
      for (final label in ['Withdraw', 'History']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '$label must remain fully readable at 1.5x in a 320dp wallet.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wallet transaction detail amounts retain semantic foregrounds in light and dark themes',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final isCredit in [true, false]) {
          SharedPreferences.setMockInitialValues({});
          final auth = AuthController(_AuthRepo(), SecureStore());
          await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
          final wallet = _FakeWallet(direction: isCredit ? 'CREDIT' : 'DEBIT');
          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.dark
                  ? ThemeData.dark()
                  : ThemeData.light(),
              locale: const Locale('en'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: auth),
                  Provider<WalletRepository>.value(value: wallet),
                ],
                child: WalletPage(repository: wallet),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final transactionRow = find.byKey(
            const ValueKey('wallet-history-entry-tx-1'),
          );
          await tester.scrollUntilVisible(
            transactionRow,
            500,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final amountLabel = isCredit ? '+500,000 TOMAN' : '-500,000 TOMAN';
          await tester.tap(transactionRow);
          await tester.pumpAndSettle();

          final detailAmount = find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText && widget.data == amountLabel,
          );
          expect(detailAmount, findsOneWidget);
          final detailContext = tester.element(detailAmount);
          expect(
            tester.widget<SelectableText>(detailAmount).style?.color,
            isCredit
                ? HopeV2SemanticColors.incomingAmount(detailContext)
                : HopeV2SemanticColors.negativeAmount(detailContext),
            reason:
                'Transaction detail amount must preserve direction semantics in $brightness mode.',
          );
          final detailSheet = find.byType(BottomSheet);
          expect(detailSheet, findsOneWidget);
          Navigator.of(tester.element(detailSheet)).pop();
          await tester.pumpAndSettle();
        }
      }
    },
  );

  testWidgets(
    'pending payout detail amount retains warning foreground in light and dark themes',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        SharedPreferences.setMockInitialValues({});
        final auth = AuthController(_AuthRepo(), SecureStore());
        await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
        final wallet = _FakeWallet(payoutStatus: 'RESERVED');
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? ThemeData.dark()
                : ThemeData.light(),
            locale: const Locale('en'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: auth),
                Provider<WalletRepository>.value(value: wallet),
              ],
              child: WalletPage(repository: wallet),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reservedStatus = find.text('Reserved');
        await tester.scrollUntilVisible(
          reservedStatus,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(reservedStatus);
        await tester.pumpAndSettle();

        final detailAmount = find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText && widget.data == '400,000 TOMAN',
        );
        expect(detailAmount, findsOneWidget);
        final detailContext = tester.element(detailAmount);
        expect(
          tester.widget<SelectableText>(detailAmount).style?.color,
          HopeV2SemanticColors.pendingAmount(detailContext),
          reason:
              'Pending withdrawal detail amount must remain semantically pending in $brightness mode.',
        );
        final detailSheet = find.byType(BottomSheet);
        expect(detailSheet, findsOneWidget);
        Navigator.of(tester.element(detailSheet)).pop();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'wallet withdraw action label uses a readable semantic foreground',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthController(_AuthRepo(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _FakeWallet();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const brandIndigo = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: brandIndigo),
          ),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<WalletRepository>.value(value: wallet),
              Provider<BackendCapabilitiesRepository>.value(
                value: _WalletEnabledCapabilities(),
              ),
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final withdraw = find.text('Withdraw');
      expect(withdraw, findsOneWidget);
      final text = tester.widget<Text>(withdraw);
      final context = tester.element(withdraw);
      expect(
        text.style?.color,
        HopeV2SemanticColors.readableAccent(
          context,
          Theme.of(context).colorScheme.primary,
        ),
        reason: 'The primary wallet action label must resolve through semantic readable colors.',
      );
      expect(
        text.style?.color,
        isNot(Theme.of(context).colorScheme.primary),
        reason: 'The withdraw action label must not reuse the raw indigo action color.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  // Runtime certification trigger: grouped Wave G-2 after compile-scope repair.
}
