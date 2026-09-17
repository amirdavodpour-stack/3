import '../network/api_client.dart';
import 'wallet.dart';

class WalletTransactionsPage {
  const WalletTransactionsPage({required this.items, this.nextCursor});

  final List<HopeWalletTransaction> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

abstract interface class WalletRepository {
  Future<HopeWallet> getWallet();
  Future<WalletTransactionsPage> listTransactions({int limit = 30, String? cursor});
  Future<List<HopePayout>> listPayouts();
  Future<Map<String, dynamic>> transfer({
    required String destinationWalletId,
    required int amount,
    required String idempotencyKey,
  });
  Future<Map<String, dynamic>> requestPayout({
    required int amount,
    required String idempotencyKey,
  });
  Future<Map<String, dynamic>> topUp({
    required int amount,
    required String idempotencyKey,
  });
}

class ApiWalletRepository implements WalletRepository {
  const ApiWalletRepository(this._api);

  final ApiClient _api;

  @override
  Future<HopeWallet> getWallet() async {
    final raw = await _api.request('GET', '/wallet/me', auth: true);
    final map = Map<String, dynamic>.from(raw as Map);
    final wallet = map['wallet'];
    if (wallet is! Map) throw const FormatException('Wallet payload is missing');
    return HopeWallet.fromMap(Map<String, dynamic>.from(wallet));
  }

  @override
  Future<WalletTransactionsPage> listTransactions({
    int limit = 30,
    String? cursor,
  }) async {
    final query = <String, String>{'limit': '${limit.clamp(1, 100)}'};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    final uri = Uri(path: '/wallet/transactions', queryParameters: query);
    final raw = await _api.request(
      'GET',
      '${uri.path}?${uri.query}',
      auth: true,
    );
    final map = Map<String, dynamic>.from(raw as Map);
    final rawItems = map['transactions'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => HopeWalletTransaction.fromMap(
                Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <HopeWalletTransaction>[];
    return WalletTransactionsPage(
      items: items,
      nextCursor:
          map['nextCursor'] == null ? null : '${map['nextCursor']}',
    );
  }

  @override
  Future<List<HopePayout>> listPayouts() async {
    final raw = await _api.request('GET', '/wallet/payouts', auth: true);
    final map = Map<String, dynamic>.from(raw as Map);
    final rawItems = map['payouts'];
    return rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => HopePayout.fromMap(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <HopePayout>[];
  }

  @override
  Future<Map<String, dynamic>> transfer({
    required String destinationWalletId,
    required int amount,
    required String idempotencyKey,
  }) async {
    final raw = await _api.request(
      'POST',
      '/wallet/transfer',
      auth: true,
      body: {
        'destinationWalletId': destinationWalletId.trim(),
        'amount': '$amount',
        'idempotencyKey': idempotencyKey,
      },
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<Map<String, dynamic>> requestPayout({
    required int amount,
    required String idempotencyKey,
  }) async {
    final raw = await _api.request(
      'POST',
      '/wallet/withdraw',
      auth: true,
      body: {'amount': '$amount', 'idempotencyKey': idempotencyKey},
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<Map<String, dynamic>> topUp({
    required int amount,
    required String idempotencyKey,
  }) async {
    final raw = await _api.request(
      'POST',
      '/wallet/top-up',
      auth: true,
      body: {'amount': '$amount', 'idempotencyKey': idempotencyKey},
    );
    return Map<String, dynamic>.from(raw as Map);
  }
}
