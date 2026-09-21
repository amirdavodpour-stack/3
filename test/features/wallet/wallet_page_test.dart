import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/features/wallet/wallet_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

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

  @override
  Future<HopeWallet> getWallet() async => HopeWallet.fromMap({
        'id': 'wallet-1',
        'userId': 'u1',
        'currency': currency,
        'availableBalance': 2500000,
        'lockedBalance': 1000000,
        'status': 'ACTIVE',
      });

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
  }) async =>
      const {};

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
      expect(find.text('موجودی قابل‌استفاده'), findsWidgets);
      expect(find.text('قفل‌شده'), findsWidgets);
      expect(find.text('برداشت‌های در جریان'), findsOneWidget);
    },
  );

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

    expect(find.textContaining('2,500,000 Toman'), findsOneWidget);
    expect(find.textContaining('2,500,000 IRR'), findsNothing);
    expect(find.textContaining('1,000,000 Toman'), findsOneWidget);
    expect(find.textContaining('IRR'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('+500,000 Toman'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('+500,000 Toman'), findsOneWidget);
    expect(find.text('+500,000 IRR'), findsNothing);

    await tester.scrollUntilVisible(
      find.textContaining('400,000 Toman'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('400,000 Toman'), findsOneWidget);
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
      find.text('400,000 Toman'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('400,000 Toman'));
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

}
