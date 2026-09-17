class HopeWallet {
  const HopeWallet({
    required this.id,
    required this.userId,
    required this.currency,
    required this.availableBalance,
    required this.lockedBalance,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String currency;
  final int availableBalance;
  final int lockedBalance;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  int get totalBalance => availableBalance + lockedBalance;
  bool get isActive => status == 'ACTIVE';

  factory HopeWallet.fromMap(Map<String, dynamic> map) => HopeWallet(
        id: '${map['id'] ?? ''}',
        userId: '${map['userId'] ?? ''}',
        currency: '${map['currency'] ?? 'TOMAN'}'.toUpperCase(),
        availableBalance: _integer(map['availableBalance']),
        lockedBalance: _integer(map['lockedBalance']),
        status: '${map['status'] ?? 'ACTIVE'}'.toUpperCase(),
        createdAt: map['createdAt'] == null ? null : '${map['createdAt']}',
        updatedAt: map['updatedAt'] == null ? null : '${map['updatedAt']}',
      );

  static int _integer(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }
}

class HopeWalletTransaction {
  const HopeWalletTransaction({
    required this.id,
    required this.entryType,
    required this.direction,
    required this.amount,
    required this.currency,
    required this.referenceType,
    required this.financialOperationId,
    required this.createdAt,
    this.referenceId,
    this.balanceAfter,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String entryType;
  final String direction;
  final int amount;
  final String currency;
  final String referenceType;
  final String financialOperationId;
  final String? referenceId;
  final int? balanceAfter;
  final String? createdAt;
  final Map<String, dynamic> metadata;

  bool get isCredit => direction == 'CREDIT';

  factory HopeWalletTransaction.fromMap(Map<String, dynamic> map) =>
      HopeWalletTransaction(
        id: '${map['id'] ?? ''}',
        entryType: '${map['entryType'] ?? map['transactionType'] ?? ''}'.toUpperCase(),
        direction: '${map['direction'] ?? ''}'.toUpperCase(),
        amount: HopeWallet._integer(map['amount']),
        currency: '${map['currency'] ?? 'TOMAN'}'.toUpperCase(),
        referenceType: '${map['referenceType'] ?? ''}',
        referenceId:
            map['referenceId'] == null ? null : '${map['referenceId']}',
        financialOperationId: '${map['financialOperationId'] ?? ''}',
        balanceAfter: map['balanceAfter'] == null
            ? null
            : HopeWallet._integer(map['balanceAfter']),
        createdAt: map['createdAt'] == null ? null : '${map['createdAt']}',
        metadata: map['metadata'] is Map
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : const <String, dynamic>{},
      );
}

class HopePayout {
  const HopePayout({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.status,
    required this.idempotencyKey,
    this.providerRef,
    this.referenceType,
    this.referenceId,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String walletId;
  final int amount;
  final String currency;
  final String provider;
  final String status;
  final String idempotencyKey;
  final String? providerRef;
  final String? referenceType;
  final String? referenceId;
  final String? createdAt;
  final String? updatedAt;
  final String? completedAt;

  factory HopePayout.fromMap(Map<String, dynamic> map) => HopePayout(
        id: '${map['id'] ?? ''}',
        walletId: '${map['walletId'] ?? ''}',
        amount: HopeWallet._integer(map['amount']),
        currency: '${map['currency'] ?? 'TOMAN'}'.toUpperCase(),
        provider: '${map['provider'] ?? 'internal'}',
        status: '${map['status'] ?? ''}'.toUpperCase(),
        idempotencyKey: '${map['idempotencyKey'] ?? ''}',
        providerRef:
            map['providerRef'] == null ? null : '${map['providerRef']}',
        referenceType:
            map['referenceType'] == null ? null : '${map['referenceType']}',
        referenceId:
            map['referenceId'] == null ? null : '${map['referenceId']}',
        createdAt: map['createdAt'] == null ? null : '${map['createdAt']}',
        updatedAt: map['updatedAt'] == null ? null : '${map['updatedAt']}',
        completedAt:
            map['completedAt'] == null ? null : '${map['completedAt']}',
      );
}
