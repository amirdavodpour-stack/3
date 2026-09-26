// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/core/ui/components.dart';
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

Future<void> _pumpBenchmark(WidgetTester tester, Widget child) async {
  final stopwatch = Stopwatch()..start();
  await tester.pumpWidget(
    MaterialApp(
      supportedLocales: const [Locale('fa'), Locale('en')],
      theme: ThemeData.light(),
      home: child,
    ),
  );
  print('HOPE_BENCHMARK:pumpWidget_ms=${stopwatch.elapsedMilliseconds}');
  await tester.pump(const Duration(milliseconds: 800));
  print('HOPE_BENCHMARK:pump_ms=${stopwatch.elapsedMilliseconds}');
}

Future<void> _pumpWallet(
  WidgetTester tester, {
  required Locale locale,
}) async {
  print(
    'HOPE_TEST_PROGRESS:${locale.languageCode}:auth-prepare',
  );
  final auth = AuthController(_EvidenceAuthRepository(), SecureStore());
  await auth.applyRefreshedUser({
    'id': 'runtime-user',
    'displayName': 'HOPE Runtime',
  });
  print(
    'HOPE_TEST_PROGRESS:${locale.languageCode}:auth-ready',
  );

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
  print(
    'HOPE_TEST_PROGRESS:${locale.languageCode}:widget-pumped',
  );

  await tester.pump(const Duration(milliseconds: 800));
  print(
    'HOPE_TEST_PROGRESS:${locale.languageCode}:frame-advanced',
  );

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
  print(
    'HOPE_TEST_PROGRESS:${locale.languageCode}:assertions-passed',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Wallet runtime baseline render benchmark', (tester) async {
    await _pumpBenchmark(tester, const Scaffold(body: Center(child: Text('baseline'))));
    expect(find.text('baseline'), findsOneWidget);
    print('HOPE_BENCHMARK:baseline_pass');
  });

  testWidgets('Wallet primitives render benchmark', (tester) async {
    await _pumpBenchmark(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const HopeSurface(child: Text('surface-1')),
              const SizedBox(height: 8),
              const HopeSurface(child: Text('surface-2')),
              const SizedBox(height: 8),
              const HopeSurface(child: Text('surface-3')),
              const SizedBox(height: 8),
              const MetricTile(label: 'Metric', value: '2,500,000 Toman'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('surface-1'), findsOneWidget);
    expect(find.text('Metric'), findsOneWidget);
    print('HOPE_BENCHMARK:primitives_pass');
  });

  testWidgets('Wallet runtime rendered evidence — fa RTL', (tester) async {
    print('HOPE_TEST_STARTED:wallet-fa-rtl');
    await _pumpWallet(tester, locale: const Locale('fa'));
    await tester.pump();
    print('HOPE_SCREENSHOT_READY:wallet-fa-rtl');
    await Future<void>.delayed(const Duration(seconds: 4));
  });

  testWidgets('Wallet runtime rendered evidence — en LTR', (tester) async {
    print('HOPE_TEST_STARTED:wallet-en-ltr');
    await _pumpWallet(tester, locale: const Locale('en'));
    await tester.pump();
    print('HOPE_SCREENSHOT_READY:wallet-en-ltr');
    await Future<void>.delayed(const Duration(seconds: 4));
  });
}
