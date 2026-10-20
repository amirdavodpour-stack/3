import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/financial/financial_insights_repository.dart';
import '../../core/ui/components.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/ui/hope_display_formatters.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/hope_v2_design.dart';

class FinancialInsightsPage extends StatefulWidget {
  const FinancialInsightsPage({super.key});

  @override
  State<FinancialInsightsPage> createState() => _FinancialInsightsPageState();
}

class _FinancialInsightsPageState extends State<FinancialInsightsPage> {
  late Future<HopeFinancialInsights> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<HopeFinancialInsights> _load() =>
      context.read<FinancialInsightsRepository>().getInsights(months: 6);

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _money(Object? value) => HopeDisplayFormatter.money(
        value,
        locale: Localizations.localeOf(context).languageCode,
      );

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final compactWidth = viewport.width < HopeV2Breakpoints.medium;
    final shortViewport = viewport.height < 800;
    return Scaffold(
        body: SafeArea(
          child: PremiumPageFrame(
            maxWidth: 1100,
            padding: EdgeInsets.fromLTRB(
              compactWidth ? 12 : 16,
              shortViewport ? 6 : 14,
              compactWidth ? 12 : 16,
              shortViewport ? 20 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumHeader(
                  page: HopePageId.financialInsights,
                  domain: HopeProductDomain.finance,
                  eyebrow: _t('مالی', 'FINANCE'),
                  title: _t('تحلیل مالی', 'Financial insights'),
                  subtitle: shortViewport
                      ? _t('بر پایه لجر داخلی تومان.', 'Internal TOMAN ledger.')
                      : _t(
                          'تصویر مالی شما بر پایه لجر داخلی تومان و فعالیت‌های ثبت‌شده در HOPE.',
                          'A ledger-based view of your balance and recorded financial activity in HOPE.',
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PremiumIconButton(
                        icon: Localizations.localeOf(context).languageCode == 'en'
                            ? HopeV2Icons.arrowLeft
                            : HopeV2Icons.arrowRight,
                        tooltip: _t('بازگشت', 'Back'),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 8),
                      PremiumIconButton(
                        icon: HopeV2Icons.refresh,
                        tooltip: _t('بازخوانی', 'Refresh'),
                        onPressed: () => setState(() => _future = _load()),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: shortViewport ? 8 : HopeV2Spacing.lg),
                Expanded(
                  child: FutureBuilder<HopeFinancialInsights>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return HopeAsyncState(
                          kind: HopeStateKind.loading,
                          title: _t('در حال تحلیل کیف پول', 'Analyzing wallet'),
                          message: _t(
                            'روند موجودی و جریان‌های مالی شما در حال محاسبه است.',
                            'Your balance and cash-flow trends are being calculated.',
                          ),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return HopeAsyncState(
                          kind: HopeStateKind.error,
                          title: _t(
                            'تحلیل مالی در دسترس نیست',
                            'Financial insights unavailable',
                          ),
                          message: _t(
                            'داده‌های مالی فعلاً قابل دریافت نیستند.',
                            'Financial data is temporarily unavailable.',
                          ),
                          action: OutlinedButton.icon(
                            onPressed: () => setState(() => _future = _load()),
                            icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
                            label: Text(_t('تلاش دوباره', 'Try again')),
                          ),
                        );
                      }
                      final data = snapshot.data!;
                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() => _future = _load());
                          await _future;
                        },
                        child: ListView(
                          key: const ValueKey('financial-insights-list'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            _SummaryCard(data: data, money: _money, t: _t, compact: shortViewport),
                            SizedBox(
                              height: shortViewport
                                  ? 8
                                  : MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact
                                      ? HopeV2Spacing.md
                                      : HopeV2Spacing.section,
                            ),
                            PremiumSectionHeader(
                              page: HopePageId.financialInsights,
                              domain: HopeProductDomain.finance,
                              title: _t('روندهای مالی', 'Financial trends'),
                              subtitle: shortViewport
                                  ? _t('شش ماه ثبت‌شده', 'Six recorded months')
                                  : _t(
                                      'جریان نقدی، موجودی و منابع فعالیت را در یک نمای واحد ببینید.',
                                      'Review cash flow, balance, and activity sources in one view.',
                                    ),
                            ),
                            const SizedBox(height: HopeV2Spacing.md),
                            _ChartCard(
                              title: _t('جریان نقدی ماهانه', 'Monthly cash flow'),
                              subtitle: _t(
                                'ورودی، خروجی و مبلغ رزروشده',
                                'Inflow, outflow and reserved funds',
                              ),
                              child: _BarChart(data: data.monthlyCashFlow),
                            ),
                            const SizedBox(height: HopeV2Spacing.xs),
                            _MonthlyCashFlowDetails(
                              data: data.monthlyCashFlow,
                              t: _t,
                            ),
                            const SizedBox(height: HopeV2Spacing.md),
                            _ChartCard(
                              title: _t('روند موجودی', 'Balance trend'),
                              subtitle: _t(
                                'آخرین موجودی ثبت‌شده در لجر (تومان)',
                                'Recorded closing balance from the ledger (TOMAN)',
                              ),
                              child: _LineChart(points: data.balanceTrend),
                            ),
                            const SizedBox(height: HopeV2Spacing.md),
                            _ChartCard(
                              title: _t('منابع فعالیت مالی', 'Financial activity sources'),
                              subtitle: _t(
                                'بر اساس نوع مرجع تراکنش',
                                'Grouped by transaction reference',
                              ),
                              child: _SourceChart(data: data.bySource, t: _t),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.money, required this.t, required this.compact});

  final HopeFinancialInsights data;
  final String Function(Object?) money;
  final String Function(String, String) t;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final compact = this.compact || MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium;
    final metrics = <({String label, String value, bool highlight})>[
      (
        label: t('قابل استفاده', 'Available'),
        value: money(summary.availableBalance),
        highlight: true,
      ),
      (
        label: t('قفل‌شده', 'Locked'),
        value: money(summary.lockedBalance),
        highlight: false,
      ),
      (
        label: t('ورودی', 'Inflow'),
        value: money(summary.totalInflow),
        highlight: false,
      ),
      (
        label: t('خروجی', 'Outflow'),
        value: money(summary.totalOutflow),
        highlight: false,
      ),
      (
        label: t('کل رزرو‌شده', 'Total reserved'),
        value: money(summary.totalReserved),
        highlight: false,
      ),
      (
        label: t('خالص جریان نقدی', 'Net cash flow'),
        value: money(summary.netCashFlow),
        highlight: false,
      ),
    ];

    return PremiumPanel(
      highlight: true,
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('تصویر مالی', 'Financial snapshot'),
            style: (compact ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge)?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(t(
            compact ? 'لجر داخلی تومان؛ بدون تخمین.' : 'بر پایه لجر داخلی TOMAN و بدون تخمین‌های خارج از تراکنش‌ها.',
            compact ? 'Internal TOMAN ledger only.' : 'Based on the internal TOMAN ledger only; no off-ledger estimates.',
          )),
          SizedBox(height: compact ? 8 : 13),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 6.0;
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final columns = compact &&
                      constraints.maxWidth >= 300 &&
                      textScale <= 1.2
                  ? 3
                  : 2;
              final metricWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: metricWidth,
                      child: _Metric(
                        label: metric.label,
                        value: metric.value,
                        compact: compact,
                        highlight: metric.highlight,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.compact,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool compact;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 54 : 68),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? accent.withValues(alpha: dark ? .14 : .07)
            : HopeV2Surfaces.panelSoft(context),
        borderRadius: BorderRadius.circular(HopeV2Radii.sm),
        border: Border.all(
          color: highlight
              ? accent.withValues(alpha: dark ? .28 : .20)
              : HopeV2Surfaces.border(context).withValues(alpha: dark ? .18 : .28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? HopeV2Colors.darkMuted
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium;
    final shortViewport = MediaQuery.sizeOf(context).height < 800;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final baseChartHeight =
        shortViewport ? 122.0 : compact ? 156.0 : 172.0;
    final chartHeight =
        (baseChartHeight + math.max(0.0, textScale - 1.0) * 112.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 7),
        DecoratedBox(
          decoration: BoxDecoration(
            color: HopeV2Surfaces.panelSoft(context).withValues(alpha: .22),
            borderRadius: BorderRadius.circular(HopeV2Radii.sm),
            border: Border.all(
              color: HopeV2Surfaces.border(context).withValues(alpha: .24),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              8,
              shortViewport ? 4 : compact ? 7 : 9,
              8,
              shortViewport ? 4 : compact ? 7 : 9,
            ),
            child: SizedBox(
              height: chartHeight,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyCashFlowDetails extends StatelessWidget {
  const _MonthlyCashFlowDetails({
    required this.data,
    required this.t,
  });

  final List<HopeMonthlyCashFlow> data;
  final String Function(String, String) t;

  String _money(String raw, String locale) {
    final parsed = HopeDisplayFormatter.parseInteger(raw);
    return parsed == null ? '—' : HopeDisplayFormatter.money(parsed, locale: locale);
  }

  Widget _amountRow(BuildContext context, String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              amount,
              textAlign: TextAlign.end,
              maxLines: 2,
              softWrap: true,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).languageCode;
    return PremiumPanel(
      quiet: true,
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: const ValueKey('financial-cashflow-exact-values-toggle'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(t('مشاهدهٔ مقادیر دقیق', 'View exact values')),
        subtitle: Text(t('مبالغ هر ماه به تومان', 'Monthly amounts in TOMAN')),
        children: [
          for (final month in data.reversed)
            Container(
              key: ValueKey('financial-cashflow-details-${month.month}'),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: HopeV2Surfaces.border(context).withValues(alpha: .35),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    month.label.trim().isEmpty ? month.month : month.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 5),
                  _amountRow(context, t('ورودی', 'Inflow'), _money(month.inflow, locale)),
                  _amountRow(context, t('خروجی', 'Outflow'), _money(month.outflow, locale)),
                  _amountRow(context, t('رزرو شده', 'Reserved'), _money(month.reserved, locale)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

double _cashFlowAxisMaximum(num maximum) {
  if (maximum < 4) return 4;
  final targetStep = maximum / 4;
  final exponent = (math.log(targetStep) / math.ln10).floor();
  final magnitude = math.pow(10, exponent).toDouble();
  final fraction = targetStep / magnitude;
  final niceStep = fraction <= 1
      ? 1.0
      : fraction <= 2
          ? 2.0
          : fraction <= 2.5
              ? 2.5
              : fraction <= 5
                  ? 5.0
                  : 10.0;
  return niceStep * magnitude * 4;
}


/// Formats visible balance-chart ticks independently from their exact semantic dates.
/// Persian labels use Solar Hijri month names; the accessible chart summary keeps
/// the original recorded ISO date and value unchanged.
String formatBalanceTrendAxisLabel(String rawDate, String locale) {
  final match = RegExp(r'^(\d{4})-(\d{2})(?:-(\d{2}))?$')
      .firstMatch(rawDate.trim());
  if (match == null) return rawDate;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3) ?? '1');
  if (month < 1 || month > 12) return rawDate;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return rawDate;
  }
  if (!locale.toLowerCase().startsWith('fa')) {
    const gregorianMonths = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return gregorianMonths[month - 1];
  }
  final solar = _gregorianToSolarHijri(year, month, day);
  const solarMonths = <String>[
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];
  return solarMonths[solar[1] - 1];
}

List<int> _gregorianToSolarHijri(int gy, int gm, int gd) {
  const gregorianMonthDays = <int>[
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
  ];
  final adjustedYear = gy - 1600;
  final adjustedMonth = gm - 1;
  final adjustedDay = gd - 1;
  var gregorianDayNumber = 365 * adjustedYear +
      ((adjustedYear + 3) ~/ 4) -
      ((adjustedYear + 99) ~/ 100) +
      ((adjustedYear + 399) ~/ 400);
  for (var index = 0; index < adjustedMonth; index++) {
    gregorianDayNumber += gregorianMonthDays[index];
  }
  final isLeapYear = gy % 4 == 0 && (gy % 100 != 0 || gy % 400 == 0);
  if (adjustedMonth > 1 && isLeapYear) gregorianDayNumber++;
  gregorianDayNumber += adjustedDay;

  var jalaliDayNumber = gregorianDayNumber - 79;
  final jalaliCycles = jalaliDayNumber ~/ 12053;
  jalaliDayNumber %= 12053;
  var jy = 979 + 33 * jalaliCycles + 4 * (jalaliDayNumber ~/ 1461);
  jalaliDayNumber %= 1461;
  if (jalaliDayNumber >= 366) {
    jy += (jalaliDayNumber - 1) ~/ 365;
    jalaliDayNumber = (jalaliDayNumber - 1) % 365;
  }
  final jm = jalaliDayNumber < 186
      ? 1 + jalaliDayNumber ~/ 31
      : 7 + (jalaliDayNumber - 186) ~/ 30;
  final jd = jalaliDayNumber < 186
      ? 1 + jalaliDayNumber % 31
      : 1 + (jalaliDayNumber - 186) % 30;
  return <int>[jy, jm, jd];
}

String _cashFlowAxisLabel(int value, String locale) {
  final fa = locale.toLowerCase().startsWith('fa');
  if (value >= 1000000000) {
    return '${_localizeAxisScale(value / 1000000000, locale)}${fa ? 'میلیارد' : 'B'}';
  }
  if (value >= 1000000) {
    return '${_localizeAxisScale(value / 1000000, locale)}${fa ? 'م' : 'M'}';
  }
  if (value >= 1000) {
    return '${_localizeAxisScale(value / 1000, locale)}${fa ? 'هزار' : 'k'}';
  }
  return HopeDisplayFormatter.integer(value, locale: locale);
}

String _localizeAxisScale(double value, String locale) {
  final rounded = (value * 100).round() / 100;
  final raw = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
  return HopeDisplayFormatter.localizeDigits(raw, locale: locale);
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});
  final List<HopeMonthlyCashFlow> data;

  @override
  Widget build(BuildContext context) {
    final shortViewport = MediaQuery.sizeOf(context).height < 800;
    final theme = Theme.of(context);
    final inflow = HopeV2ChartColors.cashIn(context);
    final outflow = HopeV2ChartColors.cashOut(context);
    final reserved = HopeV2ChartColors.reserved(context);
    final locale = Localizations.localeOf(context).languageCode;
    final english = locale.toLowerCase().startsWith('en');
    final values = data
        .expand((month) => [
              month.inflowValue,
              month.outflowValue,
              month.reservedValue,
            ])
        .whereType<double>()
        .toList(growable: false);
    final maximum = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final scaleMaximum = _cashFlowAxisMaximum(maximum);
    final hasRecordedAmounts = values.isNotEmpty;
    final hasRecordedFlow = values.any((value) => value > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: shortViewport ? 3 : 5),
        Wrap(
          key: const ValueKey('financial-cashflow-legend'),
          spacing: shortViewport ? 5 : HopeV2Spacing.sm,
          runSpacing: shortViewport ? 2 : HopeV2Spacing.xs,
          children: [
            _FinancialLegendItem(
              color: inflow,
              icon: HopeV2Icons.transferIn,
              label: english ? 'Inflow' : 'ورودی',
            ),
            _FinancialLegendItem(
              color: outflow,
              icon: HopeV2Icons.transferOut,
              label: english ? 'Outflow' : 'خروجی',
            ),
            _FinancialLegendItem(
              color: reserved,
              icon: HopeV2Icons.secure,
              label: english ? 'Reserved' : 'رزرو شده',
            ),
          ],
        ),
        Expanded(
          child: !hasRecordedFlow
              ? Center(
                  key: const ValueKey('financial-cashflow-zero-state'),
                  child: Text(
                    data.isEmpty
                        ? (english
                            ? 'No recorded cash-flow data.'
                            : 'داده‌ای برای جریان نقدی ثبت نشده است.')
                        : !hasRecordedAmounts
                            ? (english
                                ? 'No cash-flow amounts were recorded for this period.'
                                : 'برای این دوره مبلغی برای جریان نقدی ثبت نشده است.')
                            : (english
                                ? 'No cash flow recorded for this period.'
                                : 'برای این دوره جریان نقدی ثبت‌شده‌ای وجود ندارد.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const axisWidth = 70.0;
                    const axisGap = 8.0;
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final monthWidth = math.max(58.0, 58.0 * textScale);
                    final chartViewportWidth = math.max(
                      0.0,
                      constraints.maxWidth - axisWidth - axisGap,
                    ).toDouble();
                    final chartWidth = math.max(
                      chartViewportWidth,
                      data.length * monthWidth,
                    ).toDouble();
                    final hasHorizontalOverflow =
                        chartWidth > chartViewportWidth;
                    final scrollHintHeight = math.max(22.0, 18.0 * textScale).toDouble();
                    final chartViewportHeight = math.max(
                      1.0,
                      constraints.maxHeight -
                          (hasHorizontalOverflow ? scrollHintHeight : 0),
                    ).toDouble();
                    final labelHeight = math.max(
                      chartViewportHeight < 150 ? 20.0 : 24.0,
                      14.0 * textScale,
                    ).toDouble();
                    final axisTicks = textScale > 1.2
                        ? const [4, 2, 0]
                        : const [4, 3, 2, 1, 0];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasHorizontalOverflow)
                          SizedBox(
                            height: scrollHintHeight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  HopeV2Icons.roleSwitch,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    english
                                        ? 'Swipe the chart sideways to view other months'
                                        : 'برای دیدن ماه‌های دیگر، نمودار را افقی بکشید',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: axisWidth,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: labelHeight + 3,
                                      child: Align(
                                        alignment: AlignmentDirectional.centerEnd,
                                        child: Text(
                                          english ? 'TOMAN' : 'تومان',
                                          key: const ValueKey('financial-cashflow-axis-unit'),
                                          maxLines: 1,
                                          overflow: TextOverflow.clip,
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Column(
                                          key: const ValueKey('financial-cashflow-y-axis'),
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            for (final tick in axisTicks)
                                              Text(
                                                _cashFlowAxisLabel(
                                                  (scaleMaximum * tick / 4).round(),
                                                  locale,
                                                ),
                                                key: ValueKey('financial-cashflow-y-tick-$tick'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.end,
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      fontSize: 10,
                                                      height: 1,
                                                      fontWeight: tick == 0 || tick == 4
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                key: ValueKey('financial-cashflow-axis-gutter'),
                                width: axisGap,
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  key: const ValueKey('financial-cashflow-chart-scroll'),
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: chartWidth,
                                    height: chartViewportHeight,
                                    child: Semantics(
                                      key: const ValueKey('financial-cashflow-chart-semantics'),
                                      container: true,
                                      label: english
                                          ? 'Monthly cash flow; amounts in TOMAN; ${data.length} recorded months. ' +
                                              data.map((month) =>
                                                '${month.month} (${month.label}): inflow ${HopeDisplayFormatter.money(month.inflow, locale: locale)}, outflow ${HopeDisplayFormatter.money(month.outflow, locale: locale)}, reserved ${HopeDisplayFormatter.money(month.reserved, locale: locale)}'
                                              ).join('. ')
                                          : 'جریان نقدی ماهانه؛ مبالغ به تومان؛ ${data.length} ماه ثبت‌شده. ' +
                                              data.map((month) =>
                                                '${month.month} (${month.label}): ورودی ${HopeDisplayFormatter.money(month.inflow, locale: locale)}، خروجی ${HopeDisplayFormatter.money(month.outflow, locale: locale)}، رزرو شده ${HopeDisplayFormatter.money(month.reserved, locale: locale)}'
                                              ).join('؛ '),
                                      child: CustomPaint(
                                        painter: _BarChartPainter(
                                          data,
                                          inflow,
                                          outflow,
                                          reserved,
                                          theme.colorScheme.outline,
                                          Directionality.of(context),
                                          textScale,
                                          scaleMaximum,
                                        ),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FinancialLegendItem extends StatelessWidget {
  const _FinancialLegendItem({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      );
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter(
    this.data,
    this.inflowColor,
    this.outflowColor,
    this.reservedColor,
    this.axisColor,
    this.textDirection, [
    this.textScale = 1,
    this.scaleMaximum = 1,
  ]);
  final List<HopeMonthlyCashFlow> data;
  final Color inflowColor;
  final Color outflowColor;
  final Color reservedColor;
  final Color axisColor;
  final TextDirection textDirection;
  final double textScale;
  final double scaleMaximum;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = math.max(1.0, scaleMaximum);
    final labelHeight = math.max(
      size.height < 150 ? 20.0 : 24.0,
      14.0 * textScale,
    ).toDouble();
    final plotTop = labelHeight + 3;
    final plotBottom =
        math.max(plotTop + 1, size.height - 3).toDouble();
    final plotHeight = math.max(1.0, plotBottom - plotTop).toDouble();
    final groupWidth = size.width / math.max(1, data.length);
    final paints = [
      Paint()..color = inflowColor.withValues(alpha: .72),
      Paint()..color = outflowColor.withValues(alpha: .62),
      Paint()..color = reservedColor.withValues(alpha: .58),
    ];

    for (var i = 0; i < data.length; i++) {
      final bars = [
        data[i].inflowValue,
        data[i].outflowValue,
        data[i].reservedValue,
      ];
      for (var j = 0; j < bars.length; j++) {
        final amount = bars[j];
        if (amount == null) continue;
        final height = plotHeight * amount / maxValue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              i * groupWidth + groupWidth * (.12 + j * .24),
              plotBottom - height,
              groupWidth * .18,
              height,
            ),
            const Radius.circular(5),
          ),
          paints[j],
        );
      }
    }

    final axis = Paint()
      ..color = axisColor.withValues(alpha: .35)
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = axisColor.withValues(alpha: .14)
      ..strokeWidth = 1;
    for (var tick = 0; tick <= 4; tick++) {
      final y = plotBottom - plotHeight * tick / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(Offset(0, plotBottom), Offset(size.width, plotBottom), axis);
    for (var i = 0; i < data.length; i++) {
      final value = data[i].label.trim().isEmpty ? data[i].month : data[i].label;
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: axisColor.withValues(alpha: .92),
            fontSize: (12.0 * textScale).toDouble(),
            height: 1.1,
          ),
        ),
        textDirection: textDirection,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(1.0, groupWidth - 2).toDouble());
      final x = (i * groupWidth + (groupWidth - painter.width) / 2)
          .clamp(0.0, math.max(0.0, size.width - painter.width))
          .toDouble();
      painter.paint(canvas, Offset(x, 0));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.inflowColor != inflowColor ||
      oldDelegate.outflowColor != outflowColor ||
      oldDelegate.reservedColor != reservedColor ||
      oldDelegate.axisColor != axisColor ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScale != textScale ||
      oldDelegate.scaleMaximum != scaleMaximum;
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points});
  final List<HopeBalancePoint> points;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final locale = Localizations.localeOf(context).languageCode;
    final english = locale.toLowerCase().startsWith('en');
    final recordedPoints = points
        .where((point) => point.value != null)
        .toList(growable: false);
    if (recordedPoints.isEmpty) {
      return Center(
        key: const ValueKey('financial-balance-zero-state'),
        child: Padding(
          padding: const EdgeInsets.all(HopeV2Spacing.sm),
          child: Text(
            english
                ? 'No closing balance recorded for this period.'
                : 'برای این دوره مانده پایانی ثبت نشده است.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep both axes and data derived from the same recorded point values.
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final pointWidth = math.max(64.0, 64.0 * textScale);
        final axisWidth =
            math.max(70.0, 70.0 * math.min(textScale, 1.4)).toDouble();
        const axisGap = 8.0;
        final values = recordedPoints
            .map((point) => point.value!)
            .toList(growable: false);
        final rawMinimum = values.reduce((a, b) => a < b ? a : b);
        final rawMaximum = values.reduce((a, b) => a > b ? a : b);
        var scaleMinimum = rawMinimum;
        var scaleMaximum = rawMaximum;

        // A flat series still needs a meaningful visual range; these are axis
        // bounds only and never replace or alter the recorded balance values.
        if (rawMinimum == rawMaximum) {
          if (rawMaximum == 0) {
            scaleMinimum = 0;
            scaleMaximum = 4;
          } else {
            final padding = math.max(1.0, rawMaximum.abs() * .1);
            scaleMinimum = rawMinimum >= 0
                ? math.max(0.0, rawMinimum - padding).toDouble()
                : rawMinimum - padding;
            scaleMaximum = rawMaximum + padding;
          }
        }
        final axisValues = <int>[
          scaleMaximum.round(),
          ((scaleMaximum + scaleMinimum) / 2).round(),
          scaleMinimum.round(),
        ];
        final chartViewportWidth = math.max(
          0.0,
          constraints.maxWidth - axisWidth - axisGap,
        ).toDouble();
        final chartWidth = math.max(
          chartViewportWidth,
          points.length * pointWidth,
        ).toDouble();
        final hasHorizontalOverflow = chartWidth > chartViewportWidth;
        final scrollHintHeight = math.max(22.0, 18.0 * textScale).toDouble();
        final chartViewportHeight = math.max(
          1.0,
          constraints.maxHeight -
              (hasHorizontalOverflow ? scrollHintHeight : 0),
        ).toDouble();
        final labelHeight = math.max(
          chartViewportHeight < 150 ? 20.0 : 24.0,
          14.0 * textScale,
        ).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHorizontalOverflow)
              SizedBox(
                key: const ValueKey('financial-balance-scroll-hint'),
                height: scrollHintHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      HopeV2Icons.roleSwitch,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        english
                            ? 'Swipe the chart sideways to view other months'
                            : 'برای دیدن ماه‌های دیگر، نمودار را افقی بکشید',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: axisWidth,
                    height: chartViewportHeight,
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: labelHeight),
                            child: Column(
                              key: const ValueKey('financial-balance-y-axis'),
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final tick in axisValues)
                                  Text(
                                    _cashFlowAxisLabel(tick, locale),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 10,
                                          height: 1,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    key: ValueKey('financial-balance-axis-gutter'),
                    width: axisGap,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('financial-balance-chart-scroll'),
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth,
                        height: chartViewportHeight,
                        child: Semantics(
                          key: const ValueKey(
                            'financial-balance-chart-semantics',
                          ),
                          container: true,
                          label: (english
                                  ? 'Balance trend; recorded closing balance in TOMAN. '
                                  : 'روند موجودی؛ مانده پایانی ثبت‌شده به تومان. ') +
                              points.map((point) {
                                final recordedValue = point.value;
                                if (recordedValue == null) {
                                  return english
                                      ? '${point.date}: no closing balance recorded'
                                      : '${point.date}: مانده پایانی ثبت نشده';
                                }
                                final value = HopeDisplayFormatter.money(
                                  recordedValue.round(),
                                  locale: locale,
                                );
                                return '${point.date}: $value';
                              }).join('. '),
                          child: CustomPaint(
                            painter: _LineChartPainter(
                              points,
                              color,
                              color.withValues(alpha: .12),
                              Theme.of(context).colorScheme.onSurfaceVariant,
                              Directionality.of(context),
                              Localizations.localeOf(context).languageCode,
                              textScale,
                              scaleMinimum,
                              scaleMaximum,
                              labelHeight,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(
    this.points,
    this.color,
    this.fillColor,
    this.labelColor,
    this.textDirection,
    this.locale,
    this.textScale,
    this.scaleMinimum,
    this.scaleMaximum,
    this.labelHeight,
  );

  final List<HopeBalancePoint> points;
  final Color color;
  final Color fillColor;
  final Color labelColor;
  final TextDirection textDirection;
  final String locale;
  final double textScale;
  final double scaleMinimum;
  final double scaleMaximum;
  final double labelHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final range =
        math.max(1.0, scaleMaximum - scaleMinimum).toDouble();
    final plotTop = 7.0;
    final plotBottom =
        math.max(plotTop + 1, size.height - labelHeight - 7).toDouble();
    final plotHeight = math.max(1.0, plotBottom - plotTop).toDouble();
    final labelWidth =
        math.max(1.0, size.width / math.max(1, points.length) - 2).toDouble();

    final grid = Paint()
      ..color = color.withValues(alpha: .14)
      ..strokeWidth = 1;
    for (var tick = 0; tick <= 2; tick++) {
      final y = plotBottom - plotHeight * tick / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path();
    var segmentOpen = false;
    for (var i = 0; i < points.length; i++) {
      final value = points[i].value;
      if (value == null) {
        // Preserve the original month slot and break the trend across missing data.
        segmentOpen = false;
        continue;
      }
      final x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final y = plotBottom -
          ((value - scaleMinimum) / range) * plotHeight;
      if (segmentOpen) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
      }
      segmentOpen = true;
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);

    if (points.length > 1 && points.every((point) => point.value != null)) {
      final fill = Path.from(path)
        ..lineTo(size.width, plotBottom)
        ..lineTo(0, plotBottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
    }

    for (var i = 0; i < points.length; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: formatBalanceTrendAxisLabel(points[i].date, locale),
          style: TextStyle(
            color: labelColor,
            fontSize: (12.0 * textScale).toDouble(),
            height: 1.1,
          ),
        ),
        textDirection: textDirection,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: labelWidth);
      // Labels occupy the center of each month slot rather than the
      // extreme data-point coordinates, preventing edge glyph clipping.
      final pointX = (i + .5) * size.width / points.length;
      final x = (pointX - painter.width / 2)
          .clamp(0.0, math.max(0.0, size.width - painter.width))
          .toDouble();
      painter.paint(canvas, Offset(x, size.height - labelHeight + 1));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.locale != locale ||
      oldDelegate.textScale != textScale ||
      oldDelegate.scaleMinimum != scaleMinimum ||
      oldDelegate.scaleMaximum != scaleMaximum ||
      oldDelegate.labelHeight != labelHeight;
}

class _SourceChart extends StatelessWidget {
  const _SourceChart({required this.data, required this.t});
  final List<HopeFinancialSource> data;
  final String Function(String, String) t;

  String _sourceLabel(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'JOB':
        return t('فرصت شغلی', 'Job');
      case 'MISSION':
        return t('ماموریت', 'Mission');
      case 'TRANSFER':
      case 'WALLET_TRANSFER':
        return t('انتقال داخلی', 'Internal transfer');
      case 'TOP_UP':
      case 'TOPUP':
      case 'DEPOSIT':
        return t('واریز', 'Top-up');
      case 'PAYOUT':
      case 'WITHDRAWAL':
        return t('برداشت', 'Withdrawal');
      case 'REFUND':
        return t('بازپرداخت', 'Refund');
      case 'FEE':
      case 'PLATFORM_FEE':
        return t('کارمزد', 'Fee');
      default:
        return t('سایر', 'Other');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(t('داده کافی وجود ندارد.', 'Not enough data yet.')),
      );
    }
    final locale = Localizations.localeOf(context).languageCode;
    final english = locale == 'en';
    final recordedAmounts = data.map((item) => item.value).whereType<double>().toList(growable: false);
    final total = math.max(1.0, recordedAmounts.fold<double>(0, (sum, value) => sum + value));
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: math.min(5, data.length),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = data[index];
        final amountValue = item.value;
        final ratio = amountValue == null ? null : amountValue / total;
        final sourceLabel = _sourceLabel(item.source);
        final amount = amountValue == null ? '—' : HopeDisplayFormatter.money(amountValue.round(), locale: locale);
        final share = ratio == null ? '—' : HopeDisplayFormatter.percent(ratio * 100, locale: locale);
        final semanticLabel = english
            ? '$sourceLabel: amount $amount; $share of recorded source activity.'
            : '$sourceLabel؛ مبلغ $amount؛ سهم $share از منابع ثبت‌شده';
        return Semantics(
          key: ValueKey('financial-source-row-${item.source.trim().toUpperCase()}'),
          container: true,
          label: semanticLabel,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sourceLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(share),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  english ? 'Amount: $amount' : 'مبلغ: $amount',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (ratio != null) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: ratio, minHeight: 8),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
