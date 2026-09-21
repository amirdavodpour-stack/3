import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/features/wallet/wallet_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _EvidenceWalletRepository implements WalletRepository {
  @override
  Future<HopeWallet> getWallet() async => HopeWallet.fromMap({
        'id': 'wallet-runtime-evidence',
        'userId': 'runtime-user',
        'currency': 'TOMAN',
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
            'id': 'tx-runtime-1',
            'entryType': 'TRANSFER',
            'direction': 'CREDIT',
            'amount': 500000,
            'currency': 'TOMAN',
            'referenceType': 'TRANSFER',
            'financialOperationId': 'runtime-op-1',
            'createdAt': '2026-09-21T06:00:00Z',
          }),
        ],
      );

  @override
  Future<List<HopePayout>> listPayouts() async => [
        HopePayout.fromMap({
          'id': 'payout-runtime-1',
          'walletId': 'wallet-runtime-evidence',
          'amount': 400000,
          'currency': 'TOMAN',
          'provider': 'internal',
          'status': 'REQUESTED',
          'idempotencyKey': 'runtime-key-1',
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

class _EvidenceAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> loginWithGoogle(String _) => throw UnimplementedError();

  @override
  Future<AuthSession> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> register(
    String email,
    String password,
    String displayName,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}
}

Future<void> _pumpWallet(
  WidgetTester tester, {
  required Locale locale,
}) async {
  final auth = AuthController(_EvidenceAuthRepository(), SecureStore());
  await auth.applyRefreshedUser({
    'id': 'runtime-user',
    'displayName': 'HOPE Runtime',
  });
  final repository = _EvidenceWalletRepository();

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.light(),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<WalletRepository>.value(value: repository),
        ],
        child: WalletPage(repository: repository),
      ),
    ),
  );

  // WalletPage contains a repeating shimmer while data is pending.
  // Do not wait for global animation quiescence; advance a bounded frame
  // window so the real rendered surface can be asserted and captured.
  await tester.pump(const Duration(milliseconds: 800));

  expect(find.byType(WalletPage), findsOneWidget);
  expect(
    find.textContaining(
      locale.languageCode == 'fa' ? '2,500,000 تومان' : '2,500,000 Toman',
    ),
    findsWidgets,
  );
  expect(
    find.text(
      locale.languageCode == 'fa'
          ? 'موجودی قابل‌استفاده'
          : 'Available balance',
    ),
    findsWidgets,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Wallet runtime rendered evidence — fa RTL', (tester) async {
    await _pumpWallet(tester, locale: const Locale('fa'));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    print('HOPE_SCREENSHOT_READY:wallet-fa-rtl');
    await Future<void>.delayed(const Duration(seconds: 4));
  });

  testWidgets('Wallet runtime rendered evidence — en LTR', (tester) async {
    await _pumpWallet(tester, locale: const Locale('en'));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    print('HOPE_SCREENSHOT_READY:wallet-en-ltr');
    await Future<void>.delayed(const Duration(seconds: 4));
  });
}
