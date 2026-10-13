import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/config/backend_capabilities.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/features/wallet/wallet_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _WalletRepository implements WalletRepository {
  @override
  Future<HopeWallet> getWallet() async => HopeWallet.fromMap({
        'id': 'wallet-ui-test',
        'userId': 'user-ui-test',
        'currency': 'TOMAN',
        'availableBalance': 2500000,
        'lockedBalance': 1000000,
        'totalBalance': 3500000,
        'status': 'ACTIVE',
      });

  @override
  Future<WalletTransactionsPage> listTransactions({
    int limit = 30,
    String? cursor,
  }) async =>
      const WalletTransactionsPage(items: []);

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

class _AuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> loginWithGoogle(String idToken) =>
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

class _CapabilitiesRepository implements BackendCapabilitiesRepository {
  const _CapabilitiesRepository(this.capabilities) : error = null;
  _CapabilitiesRepository.failing()
      : capabilities = null,
        error = StateError('capabilities endpoint unavailable');

  final BackendCapabilities? capabilities;
  final Object? error;

  @override
  Future<BackendCapabilities> load() async {
    if (error != null) throw error!;
    return capabilities!;
  }
}

class _RecoveringCapabilitiesRepository implements BackendCapabilitiesRepository {
  int calls = 0;

  @override
  Future<BackendCapabilities> load() async {
    calls += 1;
    if (calls == 1) {
      throw StateError('temporary capability lookup failure');
    }
    return const BackendCapabilities(
      wallet: true,
      walletWithdraw: true,
      walletTransfer: true,
    );
  }
}

Future<void> _pumpWallet(
  WidgetTester tester, {
  required BackendCapabilitiesRepository capabilities,
}) async {
  final auth = AuthController(_AuthRepository(), SecureStore());
  await auth.applyRefreshedUser({
    'id': 'user-ui-test',
    'displayName': 'Test user',
  });
  final wallet = _WalletRepository();

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
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<WalletRepository>.value(value: wallet),
          Provider<BackendCapabilitiesRepository>.value(value: capabilities),
        ],
        child: WalletPage(repository: wallet),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'wallet hides unavailable withdraw and disables unavailable transfer',
    (tester) async {
      await _pumpWallet(
        tester,
        capabilities: const _CapabilitiesRepository(
          BackendCapabilities(
            wallet: true,
            walletWithdraw: false,
            walletDeposit: false,
            walletTransfer: false,
          ),
        ),
      );

      expect(find.text('Withdraw'), findsNothing);
      expect(find.text('Deposit'), findsNothing);

      await tester.tap(find.byTooltip('Wallet actions'));
      await tester.pumpAndSettle();
      final transferItem = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Transfer'),
      );
      expect(transferItem.enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wallet fails closed with a safe message when server capabilities fail',
    (tester) async {
      await _pumpWallet(
        tester,
        capabilities: _CapabilitiesRepository.failing(),
      );

      expect(find.byKey(const ValueKey('wallet-capability-error')), findsOneWidget);
      expect(find.text('Withdraw'), findsNothing);
      await tester.tap(find.byTooltip('Wallet actions'));
      await tester.pumpAndSettle();
      final transferItem = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Transfer'),
      );
      expect(transferItem.enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wallet exposes withdraw and transfer only when the server allows them',
    (tester) async {
      await _pumpWallet(
        tester,
        capabilities: const _CapabilitiesRepository(
          BackendCapabilities(
            wallet: true,
            walletWithdraw: true,
            walletDeposit: true,
            walletTransfer: true,
          ),
        ),
      );

      expect(find.text('Withdraw'), findsOneWidget);
      await tester.tap(find.byTooltip('Wallet actions'));
      await tester.pumpAndSettle();
      final transferItem = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Transfer'),
      );
      expect(transferItem.enabled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wallet parent capability blocks child actions when wallet is disabled',
    (tester) async {
      await _pumpWallet(
        tester,
        capabilities: const _CapabilitiesRepository(
          BackendCapabilities(
            wallet: false,
            walletWithdraw: true,
            walletDeposit: true,
            walletTransfer: true,
          ),
        ),
      );

      expect(find.text('Withdraw'), findsNothing);
      await tester.tap(find.byTooltip('Wallet actions'));
      await tester.pumpAndSettle();
      final transferItem = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Transfer'),
      );
      expect(transferItem.enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'wallet retries backend capabilities after a transient lookup failure',
    (tester) async {
      final capabilities = _RecoveringCapabilitiesRepository();
      await _pumpWallet(tester, capabilities: capabilities);

      expect(capabilities.calls, 1);
      expect(find.byKey(const ValueKey('wallet-capability-error')), findsOneWidget);
      expect(find.text('Withdraw'), findsNothing);
      expect(find.byKey(const ValueKey('wallet-capability-retry')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('wallet-capability-retry')));
      await tester.pumpAndSettle();

      expect(capabilities.calls, 2);
      expect(find.byKey(const ValueKey('wallet-capability-error')), findsNothing);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

}
