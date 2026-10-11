import 'dart:async';

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
  final Completer<WalletTransactionsPage> olderPage = Completer();
  int transactionCalls = 0;

  HopeWalletTransaction _transaction(int index) => HopeWalletTransaction(
        id: index == 0 ? 'wave24-wallet-row' : 'wave24-wallet-row-$index',
        entryType: 'JOB_PAYMENT_RELEASE',
        direction: 'CREDIT',
        amount: 125000 + index,
        currency: 'TOMAN',
        referenceType: 'JOB',
        financialOperationId: 'wave24-operation-$index',
        createdAt: '2026-10-09T12:00:00Z',
      );

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
  }) async {
    transactionCalls += 1;
    if (cursor != null) return olderPage.future;
    return WalletTransactionsPage(
      items: List.generate(12, _transaction),
      nextCursor: 'wave29-older-page',
    );
  }

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
          matching: find.text('۱٬۰۰۰٬۰۰۰ تومان'),
        ),
        findsOneWidget,
        reason: 'Show the aggregate locked balance even when active-hold detail totals are zero.',
      );
      expect(historyFilters, findsOneWidget);
      expect(dock, findsOneWidget);
      for (final label in ['همه', 'ورودی', 'خروجی', 'قفل‌ها']) {
        expect(find.text(label), findsOneWidget, reason: 'Filter "$label" should be visible.');
      }
      final firstTransaction = find.byKey(
        const ValueKey('wallet-history-entry-wave24-wallet-row'),
      );
      final firstAmount = find.text('\u2066+۱۲۵٬۰۰۰ تومان\u2069');
      expect(firstTransaction, findsOneWidget);
      expect(firstAmount, findsOneWidget);
      final firstTransactionRect = tester.getRect(firstTransaction);
      final firstAmountRect = tester.getRect(firstAmount);
      final initialDockRect = tester.getRect(dock);
      expect(
        firstTransactionRect.top,
        lessThan(initialDockRect.top - 40),
        reason: 'The first ledger entry should enter the compact first fold, not start under the dock.',
      );
      expect(
        firstAmountRect.bottom,
        lessThanOrEqualTo(initialDockRect.top - 4),
        reason: 'The first signed Toman amount must be visible above the fixed navigation dock.',
      );
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
        const ValueKey('wallet-history-entry-wave24-wallet-row-11'),
      );
      await tester.scrollUntilVisible(
        transactionRow,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
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
      await tester.tap(transactionRow);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 29 load-more is adjacent to transaction history and safely appends older entries',
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

      final loadMore = find.byKey(
        const ValueKey('wallet-transactions-load-more'),
      );
      await tester.scrollUntilVisible(
        loadMore,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(loadMore, findsOneWidget);
      expect(wallet.transactionCalls, 1);

      await tester.tap(loadMore);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('در حال دریافت تراکنش‌ها…'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(loadMore).onPressed, isNull);
      expect(wallet.transactionCalls, 2);

      wallet.olderPage.complete(
        WalletTransactionsPage(
          items: [
            const HopeWalletTransaction(
              id: 'wave29-older-row',
              entryType: 'JOB_PAYMENT_RELEASE',
              direction: 'CREDIT',
              amount: 98765,
              currency: 'TOMAN',
              referenceType: 'JOB',
              financialOperationId: 'wave29-older-operation',
              createdAt: '2026-10-08T12:00:00Z',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(loadMore, findsNothing);

      final olderRow = find.byKey(
        const ValueKey('wallet-history-entry-wave29-older-row'),
      );
      await tester.scrollUntilVisible(
        olderRow,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(olderRow);
      await tester.pumpAndSettle();

      final dock = find.byKey(const ValueKey('hope-navigation-dock'));
      final rowRect = tester.getRect(olderRow);
      final dockRect = tester.getRect(dock);
      expect(
        rowRect.bottom,
        lessThanOrEqualTo(dockRect.top - HopeV2Navigation.scrollEndGap),
      );
      expect(olderRow.hitTestable(), findsOneWidget);
      await tester.tap(olderRow);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave30 Wallet money-flow signature expands for English LTR at 1.5x text scale',
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
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: MultiProvider(
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

      final signature = find.byKey(
        const ValueKey('wallet-money-flow-signature'),
      );
      await tester.scrollUntilVisible(
        signature,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(signature, findsOneWidget);
      expect(find.text('Money flow in the ledger'), findsOneWidget);
      final flowHeading = tester.widget<Text>(
        find.text('Money flow in the ledger'),
      );
      expect(flowHeading.maxLines, isNull);
      expect(flowHeading.overflow, isNull);
      final flowExplanation = tester.widget<Text>(
        find.text(
          'Balance movements are recorded in the internal ledger; reserved funds are released after work approval.',
        ),
      );
      expect(flowExplanation.maxLines, isNull);
      expect(flowExplanation.overflow, TextOverflow.visible);
      for (final label in ['Ledger entry', 'Hold for approval', 'Release funds']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

}
