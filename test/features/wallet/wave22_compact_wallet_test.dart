import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/features/wallet/wallet_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _Wave22WalletRepository implements WalletRepository {
  @override
  Future<HopeWallet> getWallet() async => HopeWallet.fromMap({
        'id': 'wave22-wallet',
        'userId': 'u1',
        'currency': 'TOMAN',
        'availableBalance': 2500000,
        'lockedBalance': 1000000,
        'escrowBalance': 0,
        'totalBalance': 3500000,
        'status': 'ACTIVE',
      });

  @override
  Future<WalletTransactionsPage> listTransactions({
    int limit = 30,
    String? cursor,
  }) async =>
      const WalletTransactionsPage(items: [
        HopeWalletTransaction(
          id: 'wave24-wallet-row',
          entryType: 'JOB_PAYMENT_RELEASE',
          direction: 'CREDIT',
          amount: 125000,
          currency: 'TOMAN',
          referenceType: 'JOB',
          financialOperationId: 'wave24-operation',
          createdAt: '2026-10-09T12:00:00Z',
        ),
      ]);

  @override
  Future<List<HopePayout>> listPayouts() async => const [];

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

class _Wave22AuthRepository implements AuthRepository {
  @override
  Future<AuthSession> loginWithGoogle(String _) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> register(String email, String password, String name) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}
}

void main() {
  testWidgets(
    'Wave 22 compact wallet exposes the history heading and every filter above navigation',
    (tester) async {
      final auth = AuthController(_Wave22AuthRepository(), SecureStore());
      await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'Ali'});
      final wallet = _Wave22WalletRepository();

      tester.view.physicalSize = const Size(360, 640);
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

      final historyTitle = find.text('تاریخچه کیف پول');
      final historyFilters =
          find.byKey(const ValueKey('wallet-history-filters'));
      final dock = find.byKey(const ValueKey('hope-navigation-dock'));

      expect(historyTitle, findsOneWidget);
      final lockedMetric =
          find.byKey(const ValueKey('wallet-balance-metric-locked-total'));
      expect(lockedMetric, findsOneWidget);
      expect(
        find.descendant(
          of: lockedMetric,
          matching: find.text('1,000,000 تومان'),
        ),
        findsOneWidget,
        reason: 'Show the aggregate locked balance even when active-hold detail totals are zero.',
      );
      expect(historyFilters, findsOneWidget);
      expect(dock, findsOneWidget);
      for (final label in ['همه', 'ورودی', 'خروجی', 'قفل‌ها']) {
        expect(find.text(label), findsOneWidget, reason: 'Filter "$label" should be visible.');
      }
      expect(
        tester.getTopLeft(historyTitle).dy,
        lessThan(tester.getTopLeft(dock).dy),
        reason: 'Wallet history should be discoverable above the navigation dock.',
      );
      expect(
        tester.getTopLeft(historyFilters).dy,
        lessThan(tester.getTopLeft(dock).dy),
        reason: 'Wallet filters should be available without hidden horizontal scrolling.',
      );
      final transactionRow = find.byKey(
        const ValueKey('wallet-history-entry-wave24-wallet-row'),
      );
      expect(transactionRow, findsOneWidget);
      await tester.ensureVisible(transactionRow);
      await tester.pumpAndSettle();
      final rowRect = tester.getRect(transactionRow);
      final dockRect = tester.getRect(dock);
      expect(
        rowRect.bottom,
        lessThanOrEqualTo(dockRect.top - HopeV2Navigation.scrollEndGap),
        reason: 'The transaction row must remain fully reachable above the dock.',
      );
      expect(transactionRow, hitTestable());
      expect(tester.takeException(), isNull);
    },
  );
}
