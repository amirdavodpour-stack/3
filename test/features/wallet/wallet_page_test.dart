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
  @override
  Future<HopeWallet> getWallet() async => const HopeWallet(
        id: 'wallet-1',
        userId: 'u1',
        currency: 'TOMAN',
        availableBalance: 2500000,
        lockedBalance: 1000000,
        status: 'ACTIVE',
      );

  @override
  Future<WalletTransactionsPage> listTransactions({
    int limit = 30,
    String? cursor,
  }) async =>
      WalletTransactionsPage(
        items: [
          HopeWalletTransaction.fromMap({
            'id': 'tx-1',
            'entryType': 'TRANSFER',
            'direction': 'CREDIT',
            'amount': 500000,
            'currency': 'TOMAN',
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
          'currency': 'TOMAN',
          'provider': 'internal',
          'status': 'REQUESTED',
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
      final statCards = tester.widgetList<PremiumStatCard>(
        find.byType(PremiumStatCard),
      );
      expect(
        statCards.any((card) => card.label == 'برداشت‌های در جریان' && card.value == '1'),
        isTrue,
      );
      expect(find.text('موجودی قابل استفاده'), findsWidgets);
      expect(find.text('قفل‌شده'), findsWidgets);
      expect(find.text('برداشت‌های در جریان'), findsOneWidget);
    },
  );
}
