import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/features/wallet/wallet_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWallet implements WalletRepository {
  _FakeWallet({
    this.currency = 'TOMAN',
    this.transactionCurrency = 'TOMAN',
    this.payoutCurrency = 'TOMAN',
    this.payoutStatus = 'REQUESTED',
    this.entryType = 'TRANSFER',
  });

  final String currency;
  final String transactionCurrency;
  final String payoutCurrency;
  final String payoutStatus;
  final String entryType;
  Object? transferError;
  bool failLoad = false;

  @override
  Future<HopeWallet> getWallet() async {
    if (failLoad) throw StateError('wallet refresh unavailable');
    return HopeWallet.fromMap({
        'id': 'wallet-1',
        'userId': 'u1',
        'currency': currency,
        'availableBalance': 2500000,
        'lockedBalance': 1000000,
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
            'direction': 'CREDIT',
            'amount': 500000,
            'currency': transactionCurrency,
            'referenceType': 'TRANSFER',
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

      final loadMore = find.widgetWithText(OutlinedButton, 'Load more');
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
    'wallet keeps available, locked and pending payout metrics distinct',
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

      expect(
        find.textContaining('2,500,000 تومان'),
        findsWidgets,
      );
      expect(
        find.textContaining('1,000,000 تومان'),
        findsWidgets,
      );
      await tester.scrollUntilVisible(
        find.text('برداشت‌های در جریان'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final statCards = tester.widgetList<PremiumStatCard>(
        find.byType(PremiumStatCard),
      ).toList();
      expect(
        statCards.map((card) => '${card.label}=${card.value}').toList(),
        contains('برداشت‌های در جریان=1'),
      );
      expect(find.textContaining('2,500,000 تومان'), findsWidgets);
      expect(find.text('قفل‌شده'), findsWidgets);
      expect(find.text('برداشت‌های در جریان'), findsOneWidget);
    },
  );

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
    expect(labels, contains('انتقال داخلی'));
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
      expect(node.label, '400,000 تومان، کیف پول داخلی، درخواست‌شده');
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

    expect(find.textContaining('2,500,000 TOMAN'), findsOneWidget);
    expect(find.textContaining('2,500,000 IRR'), findsNothing);
    expect(find.textContaining('1,000,000 TOMAN'), findsOneWidget);
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

    expect(find.text('Other activity'), findsOneWidget);
    expect(find.text('Ledger entry'), findsNothing);
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
      find.text('400,000 تومان'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('400,000 تومان'));
    await tester.pumpAndSettle();

    expect(find.text('کیف پول داخلی'), findsOneWidget);
    expect(find.text('internal'), findsNothing);
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
            ],
            child: WalletPage(repository: wallet),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Destination wallet ID'), findsOneWidget);
    expect(find.bySemanticsLabel('Amount in Toman'), findsOneWidget);

    await tester.enterText(
      find.bySemanticsLabel('Destination wallet ID'),
      'wallet-destination',
    );
    await tester.enterText(
      find.bySemanticsLabel('Amount in Toman'),
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
          ],
          child: WalletPage(repository: wallet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfer').first);
    await tester.pumpAndSettle();

    expect(find.text('Maximum: 2,500,000 TOMAN'), findsOneWidget);
    expect(find.text('Maximum: 2500000'), findsNothing);
    expect(find.textContaining('TOMAN'), findsWidgets);
    expect(find.text('Toman'), findsNothing);
  });

}
