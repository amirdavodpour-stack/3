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
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: PremiumPageFrame(
            maxWidth: 1100,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumHeader(
                  eyebrow: _t('مالی', 'FINANCE'),
                  title: _t('تحلیل مالی', 'Financial insights'),
                  subtitle: _t(
                    'تصویر مالی شما بر پایه لجر داخلی تومان و فعالیت‌های ثبت‌شده در HOPE.',
                    'A ledger-based view of your balance and recorded financial activity in HOPE.',
                  ),
                  trailing: const HopeIconTile(
                    HopeV2Icons.insights,
                    size: 52,
                    filled: true,
                  ),
                ),
                const SizedBox(height: HopeV2Spacing.lg),
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
                            _SummaryCard(data: data, money: _money, t: _t),
                            const SizedBox(height: HopeV2Spacing.section),
                            PremiumSectionHeader(
                              title: _t('روندهای مالی', 'Financial trends'),
                              subtitle: _t(
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.money, required this.t});
  final HopeFinancialInsights data;
  final String Function(int) money;
  final String Function(String, String) t;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    return PremiumPanel(
      highlight: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('تصویر مالی', 'Financial snapshot'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(t(
            'بر پایه لجر داخلی TOMAN و بدون تخمین‌های خارج از تراکنش‌ها.',
            'Based on the internal TOMAN ledger only; no off-ledger estimates.',
          )),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric(label: t('قابل استفاده', 'Available'), value: money(summary.available)),
              _Metric(label: t('قفل‌شده', 'Locked'), value: money(summary.locked)),
              _Metric(
                label: t('ورودی', 'Inflow'),
                value: money(int.tryParse(summary.totalInflow) ?? 0),
              ),
              _Metric(
                label: t('خروجی', 'Outflow'),
                value: money(int.tryParse(summary.totalOutflow) ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 145),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HopeV2Radii.md),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      );
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
  Widget build(BuildContext context) => PremiumPanel(
        glass: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            SizedBox(height: 190, child: child),
          ],
        ),
      );
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});
  final List<HopeMonthlyCashFlow> data;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BarChartPainter(
          data,
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.tertiary,
          Theme.of(context).colorScheme.secondary,
          Theme.of(context).colorScheme.outline,
        ),
        child: const SizedBox.expand(),
      );
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter(this.data, this.inflowColor, this.outflowColor, this.reservedColor, this.axisColor);
  final List<HopeMonthlyCashFlow> data;
  final Color inflowColor;
  final Color outflowColor;
  final Color reservedColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    final values = data
        .expand((x) => [x.inflowValue, x.outflowValue, x.reservedValue])
        .toList();
    final maxValue = values.isEmpty ? 1.0 : math.max(1.0, values.reduce(math.max));
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
        final height = size.height * bars[j] / maxValue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              i * groupWidth + groupWidth * (.12 + j * .24),
              size.height - height - 2,
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
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      axis,
    );
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.inflowColor != inflowColor ||
      oldDelegate.outflowColor != outflowColor ||
      oldDelegate.reservedColor != reservedColor;
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points});
  final List<HopeBalancePoint> points;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _LineChartPainter(
          points,
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primary.withValues(alpha: .12),
        ),
        child: const SizedBox.expand(),
      );
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.points, this.color, this.fillColor);
  final List<HopeBalancePoint> points;
  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = points.map((p) => p.value).toList();
    final maxValue = math.max(1.0, values.reduce(math.max));
    final minValue = values.reduce(math.min);
    final range = math.max(1.0, maxValue - minValue);
    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final y = size.height -
          ((points[i].value - minValue) / range) * (size.height - 14) -
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
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.fillColor != fillColor;
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
