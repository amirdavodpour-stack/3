import '../network/api_client.dart';

class HopeFinancialSummary {
  const HopeFinancialSummary({
    required this.availableBalance,
    required this.lockedBalance,
    required this.totalInflow,
    required this.totalOutflow,
    required this.totalReserved,
    required this.netCashFlow,
  });

  final String availableBalance;
  final String lockedBalance;
  final String totalInflow;
  final String totalOutflow;
  final String totalReserved;
  final String netCashFlow;

  int get available => int.tryParse(availableBalance) ?? 0;
  int get locked => int.tryParse(lockedBalance) ?? 0;
}

class HopeMonthlyCashFlow {
  const HopeMonthlyCashFlow({
    required this.month,
    required this.label,
    required this.inflow,
    required this.outflow,
    required this.reserved,
    required this.net,
  });

  final String month;
  final String label;
  final String inflow;
  final String outflow;
  final String reserved;
  final String net;

  double? get inflowValue => double.tryParse(inflow);
  double? get outflowValue => double.tryParse(outflow);
  double? get reservedValue => double.tryParse(reserved);
  double? get netValue => double.tryParse(net);
}

class HopeBalancePoint {
  const HopeBalancePoint({required this.date, required this.balance});
  final String date;
  final String balance;
  double? get value {
    final parsed = double.tryParse(balance);
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}

class HopeFinancialSource {
  const HopeFinancialSource({
    required this.source,
    required this.credit,
    required this.debit,
    required this.amount,
  });
  final String source;
  final String credit;
  final String debit;
  final String amount;
  double? get value {
    final parsed = double.tryParse(amount);
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}

class HopeFinancialInsights {
  const HopeFinancialInsights({
    required this.currency,
    required this.months,
    required this.summary,
    required this.monthlyCashFlow,
    required this.balanceTrend,
    required this.bySource,
  });

  final String currency;
  final int months;
  final HopeFinancialSummary summary;
  final List<HopeMonthlyCashFlow> monthlyCashFlow;
  final List<HopeBalancePoint> balanceTrend;
  final List<HopeFinancialSource> bySource;

  factory HopeFinancialInsights.fromMap(Map<String, dynamic> map) {
    final rawSummary = map['summary'];
    final rawRange = map['range'];
    String summaryValue(String key) {
      if (rawSummary is! Map) return '';
      final value = rawSummary[key];
      return value == null ? '' : '$value';
    }

    return HopeFinancialInsights(
      currency: '${map['currency'] ?? 'TOMAN'}',
      months: int.tryParse('${rawRange is Map ? rawRange['months'] : 6}') ?? 6,
      summary: HopeFinancialSummary(
        availableBalance: summaryValue('availableBalance'),
        lockedBalance: summaryValue('lockedBalance'),
        totalInflow: summaryValue('totalInflow'),
        totalOutflow: summaryValue('totalOutflow'),
        totalReserved: summaryValue('totalReserved'),
        netCashFlow: summaryValue('netCashFlow'),
      ),
      monthlyCashFlow: (map['monthlyCashFlow'] is List
              ? map['monthlyCashFlow'] as List
              : const [])
          .whereType<Map>()
          .map((item) => HopeMonthlyCashFlow(
                month: '${item['month'] ?? ''}',
                label: '${item['label'] ?? item['month'] ?? ''}',
                inflow: item['inflow'] == null ? '' : '${item['inflow']}',
                outflow: item['outflow'] == null ? '' : '${item['outflow']}',
                reserved: item['reserved'] == null ? '' : '${item['reserved']}',
                net: item['net'] == null ? '' : '${item['net']}',
              ))
          .toList(growable: false),
      balanceTrend: (map['balanceTrend'] is List
              ? map['balanceTrend'] as List
              : const [])
          .whereType<Map>()
          .map((item) => HopeBalancePoint(
                date: '${item['date'] ?? ''}',
                balance: item['balance'] == null ? '' : '${item['balance']}',
              ))
          .toList(growable: false),
      bySource: (map['bySource'] is List ? map['bySource'] as List : const [])
          .whereType<Map>()
          .map((item) => HopeFinancialSource(
                source: '${item['source'] ?? 'OTHER'}',
                credit: '${item['credit'] ?? 0}',
                debit: '${item['debit'] ?? 0}',
                amount: item['amount'] == null ? '' : '${item['amount']}',
              ))
          .toList(growable: false),
    );
  }
}

abstract interface class FinancialInsightsRepository {
  Future<HopeFinancialInsights> getInsights({int months = 6});
}

class ApiFinancialInsightsRepository implements FinancialInsightsRepository {
  const ApiFinancialInsightsRepository(this._api);
  final ApiClient _api;

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async {
    final safeMonths = months.clamp(1, 12);
    final raw = await _api.request(
      'GET',
      '/wallet/financial-insights?months=$safeMonths',
      auth: true,
    );
    return HopeFinancialInsights.fromMap(Map<String, dynamic>.from(raw as Map));
  }
}
