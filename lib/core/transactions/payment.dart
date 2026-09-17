import '../marketplace/job.dart';

/// Typed participant-safe payment view returned by the backend payment routes.
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
              Map<String, dynamic>.from(map['fees'] as Map))
          : null,
      createdAt: map['createdAt'] == null ? null : '${map['createdAt']}',
      updatedAt: map['updatedAt'] == null ? null : '${map['updatedAt']}',
    );
  }

  static String? _moneyString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final parsed = num.tryParse(value.trim());
      return parsed?.toString();
    }
    if (value is num) return value.toString();
    final parsed = num.tryParse('$value');
    return parsed?.toString();
  }

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

  final num? baseAmount;
  final num? employerFee;
  final num? workerFee;
  final num? platformFee;
  final num? employerCharge;
  final num? providerPayout;
  final String policyVersion;
  final String currency;

  factory HopePaymentFees.fromMap(Map<String, dynamic> map) => HopePaymentFees(
        baseAmount: _money(map['baseAmount']),
        employerFee: _money(map['employerFee']),
        workerFee: _money(map['workerFee']),
        platformFee: _money(map['platformFee']),
        employerCharge: _money(map['employerCharge']),
        providerPayout: _money(map['providerPayout']),
        policyVersion: '${map['policyVersion'] ?? 'legacy'}',
        currency: '${map['currency'] ?? 'TOMAN'}'.toUpperCase(),
      );

  static num? _money(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return num.tryParse('$value');
  }

}
