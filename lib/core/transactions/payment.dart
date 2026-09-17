import '../marketplace/job.dart';

/// Typed participant-safe payment view returned by the backend payment routes.
///
/// Monetary values remain string-backed so TOMAN amounts never pass through a
/// floating-point conversion on the mobile boundary.
class HopePayment {
  const HopePayment({
    this.id,
    required this.status,
    required this.amount,
    this.providerRef,
    required this.job,
    this.fees,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String status;
  final String? amount;
  final String? providerRef;
  final HopeJob job;
  final HopePaymentFees? fees;
  final String? createdAt;
  final String? updatedAt;

  bool get isMissing => status == 'NO_TRANSACTION';
  String get paymentStatus => status;

  HopePayment copyWith({HopeJob? job, String? status}) => HopePayment(
        id: id,
        status: status ?? this.status,
        amount: amount,
        providerRef: providerRef,
        job: job ?? this.job,
        fees: fees,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory HopePayment.fromMap(Map<String, dynamic> map) {
    final rawJob = map['job'];
    if (rawJob is! Map) {
      throw const FormatException('Payment job payload is missing');
    }
    return HopePayment(
      id: map['id'] == null ? null : '${map['id']}',
      status: '${map['status'] ?? map['paymentStatus'] ?? 'NO_TRANSACTION'}'
          .toUpperCase(),
      amount: _moneyString(map['amount']),
      providerRef: map['providerRef'] == null ? null : '${map['providerRef']}',
      job: HopeJob.fromMap(Map<String, dynamic>.from(rawJob)),
      fees: map['fees'] is Map
          ? HopePaymentFees.fromMap(
              Map<String, dynamic>.from(map['fees'] as Map),
            )
          : null,
      createdAt: map['createdAt'] == null ? null : '${map['createdAt']}',
      updatedAt: map['updatedAt'] == null ? null : '${map['updatedAt']}',
    );
  }
}

/// Normalizes a numeric money payload without routing it through a double.
/// Integer TOMAN values therefore remain exact even above JavaScript's safe
/// integer range when they arrive as strings.
String? _moneyString(dynamic value) {
  if (value == null) return null;
  final raw = value is String ? value.trim() : '$value'.trim();
  if (raw.isEmpty) return null;
  if (!RegExp(r'^[+-]?(?:\d+)(?:\.\d+)?$').hasMatch(raw)) return null;

  var normalized = raw;
  final negative = normalized.startsWith('-');
  final positive = normalized.startsWith('+');
  final sign = negative || positive ? normalized.substring(0, 1) : '';
  if (sign.isNotEmpty) normalized = normalized.substring(1);

  final parts = normalized.split('.');
  var integerPart = parts[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (integerPart.isEmpty) integerPart = '0';

  if (parts.length == 1) return '$sign$integerPart';
  // Avoid a trailing decimal point and normalize values such as 125.50.
  final fraction = parts[1].replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$sign$integerPart' : '$sign$integerPart.$fraction';
}

class HopePaymentFees {
  const HopePaymentFees({
    required this.baseAmount,
    required this.employerFee,
    required this.workerFee,
    required this.platformFee,
    required this.employerCharge,
    required this.providerPayout,
    required this.policyVersion,
    required this.currency,
  });

  final String? baseAmount;
  final String? employerFee;
  final String? workerFee;
  final String? platformFee;
  final String? employerCharge;
  final String? providerPayout;
  final String policyVersion;
  final String currency;

  factory HopePaymentFees.fromMap(Map<String, dynamic> map) => HopePaymentFees(
        baseAmount: _moneyString(map['baseAmount']),
        employerFee: _moneyString(map['employerFee']),
        workerFee: _moneyString(map['workerFee']),
        platformFee: _moneyString(map['platformFee']),
        employerCharge: _moneyString(map['employerCharge']),
        providerPayout: _moneyString(map['providerPayout']),
        policyVersion: '${map['policyVersion'] ?? 'legacy'}',
        currency: '${map['currency'] ?? 'TOMAN'}'.toUpperCase(),
      );
}
