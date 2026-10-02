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

  double get inflowValue => double.tryParse(inflow) ?? 0;
  double get outflowValue => double.tryParse(outflow) ?? 0;
  double get reservedValue => double.tryParse(reserved) ?? 0;
  double get netValue => double.tryParse(net) ?? 0;
}

class HopeBalancePoint {
  const HopeBalancePoint({required this.date, required this.balance});
  final String date;
  final String balance;
  double get value => double.tryParse(balance) ?? 0;
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
  double get value => double.tryParse(amount) ?? 0;
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
    return HopeFinancialInsights(
      currency: '${map['currency'] ?? 'TOMAN'}',
      months: int.tryParse('${rawRange is Map ? rawRange['months'] : 6}') ?? 6,
      summary: HopeFinancialSummary(
        availableBalance: '${rawSummary is Map ? rawSummary['availableBalance'] : 0}',
        lockedBalance: '${rawSummary is Map ? rawSummary['lockedBalance'] : 0}',
        totalInflow: '${rawSummary is Map ? rawSummary['totalInflow'] : 0}',
        totalOutflow: '${rawSummary is Map ? rawSummary['totalOutflow'] : 0}',
        totalReserved: '${rawSummary is Map ? rawSummary['totalReserved'] : 0}',
        netCashFlow: '${rawSummary is Map ? rawSummary['netCashFlow'] : 0}',
      ),
      monthlyCashFlow: (map['monthlyCashFlow'] is List
              ? map['monthlyCashFlow'] as List
              : const [])
          .whereType<Map>()
          .map((item) => HopeMonthlyCashFlow(
                month: '${item['month'] ?? ''}',
                label: '${item['label'] ?? item['month'] ?? ''}',
                inflow: '${item['inflow'] ?? 0}',
                outflow: '${item['outflow'] ?? 0}',
                reserved: '${item['reserved'] ?? 0}',
                net: '${item['net'] ?? 0}',
              ))
          .toList(growable: false),
      balanceTrend: (map['balanceTrend'] is List
              ? map['balanceTrend'] as List
              : const [])
          .whereType<Map>()
          .map((item) => HopeBalancePoint(
                date: '${item['date'] ?? ''}',
                balance: '${item['balance'] ?? 0}',
              ))
          .toList(growable: false),
      bySource: (map['bySource'] is List ? map['bySource'] as List : const [])
          .whereType<Map>()
          .map((item) => HopeFinancialSource(
                source: '${item['source'] ?? 'OTHER'}',
                credit: '${item['credit'] ?? 0}',
                debit: '${item['debit'] ?? 0}',
                amount: '${item['amount'] ?? 0}',
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
