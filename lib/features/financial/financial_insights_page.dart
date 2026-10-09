import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/financial/financial_insights_repository.dart';
import '../../core/ui/components.dart';
import '../../core/ui/hope_async_state.dart';
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

  String _money(int value) {
    final formatter = MaterialLocalizations.of(context);
    return '${formatter.formatDecimal(value)} ${_t('تومان', 'TOMAN')}';
  }

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
              compactWidth ? 12 : 20,
              shortViewport ? 8 : 18,
              compactWidth ? 12 : 20,
              shortViewport ? 24 : 72,
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
                            const SizedBox(height: HopeV2Spacing.md),
                            _ChartCard(
                              title: _t('روند موجودی', 'Balance trend'),
                              subtitle: _t(
                                'آخرین موجودی ثبت‌شده در لجر',
                                'Recorded closing balance from the ledger',
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
  final String Function(int) money;
  final String Function(String, String) t;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final compact = this.compact || MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium;
    final metrics = <({String label, String value, bool highlight})>[
      (
        label: t('قابل استفاده', 'Available'),
        value: money(summary.available),
        highlight: true,
      ),
      (
        label: t('قفل‌شده', 'Locked'),
        value: money(summary.locked),
        highlight: false,
      ),
      (
        label: t('ورودی', 'Inflow'),
        value: money(int.tryParse(summary.totalInflow) ?? 0),
        highlight: false,
      ),
      (
        label: t('خروجی', 'Outflow'),
        value: money(int.tryParse(summary.totalOutflow) ?? 0),
        highlight: false,
      ),
    ];

    return PremiumPanel(
      highlight: true,
      padding: EdgeInsets.all(compact ? 12 : 18),
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
              const gap = 8.0;
              final metricWidth = (constraints.maxWidth - gap) / 2;
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
      constraints: BoxConstraints(minHeight: compact ? 60 : 74),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? accent.withValues(alpha: dark ? .14 : .07)
            : HopeV2Surfaces.panelSoft(context),
        borderRadius: BorderRadius.circular(HopeV2Radii.md),
        border: Border.all(
          color: highlight
              ? accent.withValues(alpha: dark ? .30 : .22)
              : HopeV2Surfaces.border(context).withValues(alpha: dark ? .42 : .65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? HopeV2Colors.darkMuted
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.clip,
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
    final chartHeight = shortViewport ? 106.0 : compact ? 148.0 : 172.0;
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
            color: HopeV2Surfaces.panelSoft(context).withValues(alpha: .32),
            borderRadius: BorderRadius.circular(HopeV2Radii.md),
            border: Border.all(
              color: HopeV2Surfaces.border(context).withValues(alpha: .52),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              shortViewport ? 4 : compact ? 8 : 10,
              10,
              shortViewport ? 4 : compact ? 8 : 10,
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

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});
  final List<HopeMonthlyCashFlow> data;

  @override
  Widget build(BuildContext context) {
    final shortViewport = MediaQuery.sizeOf(context).height < 800;
    final theme = Theme.of(context);
    final inflow = theme.colorScheme.primary;
    final outflow = theme.colorScheme.tertiary;
    final reserved = theme.colorScheme.secondary;
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: shortViewport ? 3 : 5),
        Wrap(
          key: const ValueKey('financial-cashflow-legend'),
          spacing: shortViewport ? 5 : HopeV2Spacing.sm,
          runSpacing: shortViewport ? 2 : HopeV2Spacing.xs,
          children: [
            _FinancialLegendItem(color: inflow, label: english ? 'Inflow' : 'ورودی'),
            _FinancialLegendItem(color: outflow, label: english ? 'Outflow' : 'خروجی'),
            _FinancialLegendItem(color: reserved, label: english ? 'Reserved' : 'رزرو شده'),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keep each month readable instead of squeezing all labels into
              // the viewport; the chart becomes horizontally scrollable only
              // when the real series count needs more width.
              final chartWidth =
                  math.max(constraints.maxWidth, data.length * 42.0).toDouble();
              return SingleChildScrollView(
                key: const ValueKey('financial-cashflow-chart-scroll'),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  height: constraints.maxHeight,
                  child: CustomPaint(
                    painter: _BarChartPainter(
                      data,
                      inflow,
                      outflow,
                      reserved,
                      theme.colorScheme.outline,
                      Directionality.of(context),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),

      ],
    );
  }
}

class _FinancialLegendItem extends StatelessWidget {
  const _FinancialLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
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
    this.textDirection,
  );
  final List<HopeMonthlyCashFlow> data;
  final Color inflowColor;
  final Color outflowColor;
  final Color reservedColor;
  final Color axisColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final values = data
        .expand((x) => [x.inflowValue, x.outflowValue, x.reservedValue])
        .toList();
    final maxValue = values.isEmpty ? 1.0 : math.max(1.0, values.reduce(math.max));
    final labelHeight = size.height < 150 ? 14.0 : 18.0;
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
        final height = plotHeight * bars[j] / maxValue;
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
    canvas.drawLine(Offset(0, plotBottom), Offset(size.width, plotBottom), axis);
    for (var i = 0; i < data.length; i++) {
      final value = data[i].label.trim().isEmpty ? data[i].month : data[i].label;
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: axisColor.withValues(alpha: .82),
            fontSize: groupWidth < 38 ? 9 : 11,
            height: 1,
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
      oldDelegate.textDirection != textDirection;
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points});
  final List<HopeBalancePoint> points;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A stable minimum plot width prevents date labels from colliding on
        // narrow screens while retaining the exact backend point sequence.
        final chartWidth =
            math.max(constraints.maxWidth, points.length * 52.0).toDouble();
        return SingleChildScrollView(
          key: const ValueKey('financial-balance-chart-scroll'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            height: constraints.maxHeight,
            child: CustomPaint(
              painter: _LineChartPainter(
                points,
                color,
                color.withValues(alpha: .12),
                Directionality.of(context),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.points, this.color, this.fillColor, this.textDirection);
  final List<HopeBalancePoint> points;
  final Color color;
  final Color fillColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = points.map((p) => p.value).toList();
    final maxValue = math.max(1.0, values.reduce(math.max));
    final minValue = values.reduce(math.min);
    final range = math.max(1.0, maxValue - minValue);
    final labelHeight = size.height < 150 ? 14.0 : 18.0;
    final plotHeight = math.max(1.0, size.height - labelHeight).toDouble();
    final labelWidth = math.max(1.0, size.width / math.max(1, points.length) - 2).toDouble();
    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final y = plotHeight -
          ((points[i].value - minValue) / range) * (plotHeight - 14) -
          7;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);

    if (points.length > 1) {
      final fill = Path.from(path)
        ..lineTo(size.width, plotHeight)
        ..lineTo(0, plotHeight)
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
          text: points[i].date,
          style: TextStyle(
            color: color.withValues(alpha: .76),
            fontSize: labelWidth < 36 ? 9 : 10,
            height: 1,
          ),
        ),
        textDirection: textDirection,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: labelWidth);
      final pointX = points.length == 1 ? size.width / 2 : i * size.width / (points.length - 1);
      final x = (pointX - painter.width / 2)
          .clamp(0.0, math.max(0.0, size.width - painter.width))
          .toDouble();
      painter.paint(canvas, Offset(x, plotHeight + 1));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.textDirection != textDirection;
}

class _SourceChart extends StatelessWidget {
  const _SourceChart({required this.data, required this.t});
  final List<HopeFinancialSource> data;
  final String Function(String, String) t;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(t('داده کافی وجود ندارد.', 'Not enough data yet.')),
      );
    }
    final total = math.max(
      1.0,
      data.fold<double>(0, (sum, item) => sum + item.value),
    );
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: math.min(5, data.length),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = data[index];
        final ratio = item.value / total;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.source,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('${(ratio * 100).toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: ratio, minHeight: 8),
            ),
          ],
        );
      },
    );
  }
}
