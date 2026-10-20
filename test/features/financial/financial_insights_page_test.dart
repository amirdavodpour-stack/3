import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/financial/financial_insights_repository.dart';
import 'package:hope_mobile/features/financial/financial_insights_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _Wave24InsightsRepository implements FinancialInsightsRepository {
  const _Wave24InsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      const HopeFinancialInsights(
        currency: 'TOMAN',
        months: 6,
        summary: HopeFinancialSummary(
          availableBalance: '1200000',
          lockedBalance: '150000',
          totalInflow: '500000',
          totalOutflow: '120000',
          totalReserved: '30000',
          netCashFlow: '380000',
        ),
        monthlyCashFlow: [
          HopeMonthlyCashFlow(month: '2026-05', label: 'اردیبهشت', inflow: '80', outflow: '25', reserved: '10', net: '45'),
          HopeMonthlyCashFlow(month: '2026-06', label: 'خرداد', inflow: '90', outflow: '30', reserved: '12', net: '48'),
          HopeMonthlyCashFlow(month: '2026-07', label: 'تیر', inflow: '100', outflow: '32', reserved: '14', net: '54'),
          HopeMonthlyCashFlow(month: '2026-08', label: 'مرداد', inflow: '110', outflow: '35', reserved: '15', net: '60'),
          HopeMonthlyCashFlow(month: '2026-09', label: 'شهریور', inflow: '120', outflow: '40', reserved: '18', net: '62'),
          HopeMonthlyCashFlow(month: '2026-10', label: 'مهر', inflow: '130', outflow: '42', reserved: '20', net: '68'),
        ],
        balanceTrend: [
          HopeBalancePoint(date: '2026-05', balance: '700000'),
          HopeBalancePoint(date: '2026-06', balance: '820000'),
          HopeBalancePoint(date: '2026-07', balance: '920000'),
          HopeBalancePoint(date: '2026-08', balance: '1000000'),
          HopeBalancePoint(date: '2026-09', balance: '1100000'),
          HopeBalancePoint(date: '2026-10', balance: '1200000'),
        ],
        bySource: [
          HopeFinancialSource(source: 'JOB', credit: '500000', debit: '120000', amount: '380000'),
        ],
      );
}

class _LongSummaryInsightsRepository implements FinancialInsightsRepository {
  const _LongSummaryInsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      const HopeFinancialInsights(
        currency: 'TOMAN',
        months: 6,
        summary: HopeFinancialSummary(
          availableBalance: '987654321098765432',
          lockedBalance: '876543210987654321',
          totalInflow: '765432109876543210',
          totalOutflow: '654321098765432109',
          totalReserved: '543210987654321098',
          netCashFlow: '432109876543210987',
        ),
        monthlyCashFlow: [],
        balanceTrend: [],
        bySource: [],
      );
}

class _EmptyBalanceInsightsRepository implements FinancialInsightsRepository {
  const _EmptyBalanceInsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      const HopeFinancialInsights(
        currency: 'TOMAN',
        months: 6,
        summary: HopeFinancialSummary(
          availableBalance: '0',
          lockedBalance: '0',
          totalInflow: '0',
          totalOutflow: '0',
          totalReserved: '0',
          netCashFlow: '0',
        ),
        monthlyCashFlow: [],
        balanceTrend: [],
        bySource: [],
      );
}


class _MalformedSummaryInsightsRepository implements FinancialInsightsRepository {
  const _MalformedSummaryInsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      const HopeFinancialInsights(
        currency: 'TOMAN',
        months: 6,
        summary: HopeFinancialSummary(
          availableBalance: '1200000',
          lockedBalance: '150000',
          totalInflow: 'not-recorded',
          totalOutflow: 'invalid',
          totalReserved: '',
          netCashFlow: 'NaN',
        ),
        monthlyCashFlow: [],
        balanceTrend: [],
        bySource: [],
      );
}


class _MissingSummaryInsightsRepository implements FinancialInsightsRepository {
  const _MissingSummaryInsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      HopeFinancialInsights.fromMap(const {
        'currency': 'TOMAN',
        'range': {'months': 6},
        'monthlyCashFlow': [],
        'balanceTrend': [],
        'bySource': [],
      });
}


class _MissingCashFlowSeriesInsightsRepository implements FinancialInsightsRepository {
  const _MissingCashFlowSeriesInsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      HopeFinancialInsights.fromMap(const {
        'currency': 'TOMAN',
        'range': {'months': 6},
        'summary': {
          'availableBalance': 0,
          'lockedBalance': 0,
          'totalInflow': 0,
          'totalOutflow': 0,
          'totalReserved': 0,
          'netCashFlow': 0,
        },
        'monthlyCashFlow': [
          {'month': '2026-10', 'label': 'October', 'outflow': '120'},
        ],
        'balanceTrend': [],
        'bySource': [],
      });
}


class _MissingBalancePointInsightsRepository implements FinancialInsightsRepository {
  const _MissingBalancePointInsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      HopeFinancialInsights.fromMap(const {
        'currency': 'TOMAN',
        'range': {'months': 6},
        'summary': {
          'availableBalance': 0,
          'lockedBalance': 0,
          'totalInflow': 0,
          'totalOutflow': 0,
          'totalReserved': 0,
          'netCashFlow': 0,
        },
        'monthlyCashFlow': [],
        'balanceTrend': [{'date': '2026-10'}],
        'bySource': [],
      });
}


class _GappedBalanceTrendInsightsRepository implements FinancialInsightsRepository {
  const _GappedBalanceTrendInsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      HopeFinancialInsights.fromMap(const {
        'currency': 'TOMAN',
        'range': {'months': 3},
        'summary': {
          'availableBalance': 0,
          'lockedBalance': 0,
          'totalInflow': 0,
          'totalOutflow': 0,
          'totalReserved': 0,
          'netCashFlow': 0,
        },
        'monthlyCashFlow': [],
        'balanceTrend': [
          {'date': '2026-08', 'balance': '100000'},
          {'date': '2026-09'},
          {'date': '2026-10', 'balance': '300000'},
        ],
        'bySource': [],
      });
}

class _MissingSourceAmountInsightsRepository implements FinancialInsightsRepository {
  const _MissingSourceAmountInsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      HopeFinancialInsights.fromMap(const {
        'currency': 'TOMAN',
        'range': {'months': 6},
        'summary': {
          'availableBalance': 0,
          'lockedBalance': 0,
          'totalInflow': 0,
          'totalOutflow': 0,
          'totalReserved': 0,
          'netCashFlow': 0,
        },
        'monthlyCashFlow': [],
        'balanceTrend': [],
        'bySource': [
          {'source': 'JOB'},
        ],
      });
}


class _NonFiniteCashFlowInsightsRepository implements FinancialInsightsRepository {
  const _NonFiniteCashFlowInsightsRepository();

  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      HopeFinancialInsights.fromMap(const {
        'currency': 'TOMAN',
        'range': {'months': 6},
        'summary': {
          'availableBalance': '1200',
          'lockedBalance': '0',
          'totalInflow': '0',
          'totalOutflow': '0',
          'totalReserved': '0',
          'netCashFlow': '0',
        },
        'monthlyCashFlow': [
          {
            'month': '2026-10',
            'label': 'October',
            'inflow': 'NaN',
            'outflow': 'Infinity',
            'reserved': '-Infinity',
            'net': 'NaN',
          },
        ],
        'balanceTrend': [],
        'bySource': [],
      });
}

void main() {
  test('balance-chart tick labels use compact localized months', () {
    expect(formatBalanceTrendAxisLabel('2026-05', 'en'), 'May');
    expect(formatBalanceTrendAxisLabel('2026-05', 'fa'), 'اردیبهشت');
    expect(formatBalanceTrendAxisLabel('2026-08-01', 'fa'), 'مرداد');
    expect(formatBalanceTrendAxisLabel('2026-10', 'en'), 'Oct');
    expect(formatBalanceTrendAxisLabel('2026-13', 'en'), '2026-13');
    expect(formatBalanceTrendAxisLabel('not-a-date', 'fa'), 'not-a-date');
  });

  testWidgets(
    'financial snapshot preserves long metric labels and amounts at 1.5x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _LongSummaryInsightsRepository(),
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final summary = find.byType(PremiumPanel).first;
      final metricTexts = tester.widgetList<Text>(
        find.descendant(of: summary, matching: find.byType(Text)),
      ).where((text) {
        final value = text.data ?? '';
        return RegExp(r'-?[\d,]+\s*TOMAN').hasMatch(value) ||
            const {
              'Available',
              'Locked',
              'Inflow',
              'Outflow',
              'Total reserved',
              'Net cash flow',
            }.contains(value);
      }).toList(growable: false);

      expect(metricTexts, hasLength(12));
      expect(
        metricTexts.every(
          (text) => text.maxLines == null && text.overflow == TextOverflow.visible,
        ),
        isTrue,
        reason: 'Large text must never clip a recorded financial label or amount in the summary card.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 43 financial snapshot exposes the recorded reserved total and net cash flow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _Wave24InsightsRepository(),
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total reserved'), findsOneWidget);
      expect(find.text('Net cash flow'), findsOneWidget);
      expect(find.text('30,000 TOMAN'), findsOneWidget);
      expect(find.text('380,000 TOMAN'), findsOneWidget);
      expect(
        tester.widget<PremiumPageFrame>(
          find.byType(PremiumPageFrame),
        ).padding.bottom,
        24,
        reason: 'The financial insights shell should not reserve a duplicate 64dp dead band beneath its scroll view.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 43 source chart localizes source types and displays recorded amounts',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          Provider<FinancialInsightsRepository>.value(
            value: const _Wave24InsightsRepository(),
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FinancialInsightsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Financial activity sources'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final cashflowAxis = find.byKey(
          const ValueKey('financial-cashflow-y-axis'),
        );
        expect(cashflowAxis, findsOneWidget);
        expect(
          find.descendant(of: cashflowAxis, matching: find.byType(Text)),
          findsNWidgets(5),
        );

        expect(find.text('Job'), findsOneWidget);
        expect(find.text('JOB'), findsNothing);
        expect(find.textContaining('380,000 TOMAN'), findsOneWidget);
        final sourceSemantics = tester.getSemantics(
          find.byKey(const ValueKey('financial-source-row-JOB')),
        );
        expect(sourceSemantics.label, contains('Job'));
        expect(sourceSemantics.label, contains('380,000 TOMAN'));
        expect(sourceSemantics.label, contains('100%'));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'Wave 24 financial chart legend describes the three real cash-flow series',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _Wave24InsightsRepository(),
          child: MaterialApp(
            theme: ThemeData.light(),
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final legend = find.byKey(const ValueKey('financial-cashflow-legend'));
      await tester.scrollUntilVisible(
        legend,
        140,
        scrollable: find.byType(Scrollable).first,
      );
      expect(legend, findsOneWidget);
      expect(
        find.byKey(const ValueKey('financial-cashflow-chart-scroll')),
        findsOneWidget,
      );
      final balanceChart = find.byKey(
        const ValueKey('financial-balance-chart-scroll'),
      );
      final pageList = find.byKey(
        const ValueKey('financial-insights-list'),
      );
      for (var attempt = 0;
          attempt < 6 && balanceChart.evaluate().isEmpty;
          attempt++) {
        await tester.drag(pageList, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      expect(balanceChart, findsOneWidget);
      for (final label in ['ورودی', 'خروجی', 'رزرو شده']) {
        expect(
          find.descendant(of: legend, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'monthly cash-flow chart exposes exact values on demand',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _Wave24InsightsRepository(),
          child: MaterialApp(
            theme: ThemeData.light(),
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final exactValues = find.byKey(
        const ValueKey('financial-cashflow-exact-values-toggle'),
      );
      await tester.scrollUntilVisible(
        exactValues,
        140,
        scrollable: find.byType(Scrollable).first,
      );
      expect(exactValues, findsOneWidget);
      await tester.tap(exactValues);
      await tester.pumpAndSettle();
      expect(find.text('۱۳۰ تومان'), findsOneWidget);
      expect(find.text('۴۲ تومان'), findsOneWidget);
      expect(find.text('۲۰ تومان'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 28 keeps the real cash-flow legend inside the initial 360x640 viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _Wave24InsightsRepository(),
          child: MaterialApp(
            theme: ThemeData.light(),
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final legend = find.byKey(const ValueKey('financial-cashflow-legend'));
      expect(legend, findsOneWidget);
      final bounds = tester.getRect(legend);
      final plotBounds = tester.getRect(
        find.byKey(const ValueKey('financial-cashflow-chart-scroll')),
      );
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(
        bounds.bottom,
        lessThanOrEqualTo(640),
        reason: 'The first cash-flow legend must be visible without a user scroll.',
      );
      expect(
        bounds.bottom,
        lessThanOrEqualTo(plotBounds.top),
        reason: 'Explain the series before rendering their plot.',
      );
      expect(plotBounds.top, lessThan(640));
      expect(plotBounds.height, greaterThan(0));
      expect(legend.hitTestable(), findsOneWidget);
      for (final label in ['ورودی', 'خروجی', 'رزرو شده']) {
        expect(
          find.descendant(of: legend, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'monthly cash-flow chart advertises horizontal navigation only when needed',
    (tester) async {
      const hintFa = 'برای دیدن ماه‌های دیگر، نمودار را افقی بکشید';
      const hintEn = 'Swipe the chart sideways to view other months';
      for (final width in [360.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          Provider<FinancialInsightsRepository>.value(
            value: const _Wave24InsightsRepository(),
            child: MaterialApp(
              locale: const Locale('fa'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FinancialInsightsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final chart = find.byKey(
          const ValueKey('financial-cashflow-chart-scroll'),
        );
        await tester.scrollUntilVisible(
          chart,
          140,
          scrollable: find.byType(Scrollable).first,
        );
        final hint = find.text(hintFa);
        if (width == 360) {
          expect(hint, findsOneWidget);
          expect(hint.hitTestable(), findsOneWidget);
          expect(find.text(hintEn), findsNothing);
        } else {
          expect(hint, findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets(
    'Wave 34 financial chart labels remain readable and scrollable at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _Wave24InsightsRepository(),
          child: MaterialApp(
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final legend = find.byKey(const ValueKey('financial-cashflow-legend'));
      await tester.scrollUntilVisible(
        legend,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(legend, findsOneWidget);
      expect(
        find.byKey(const ValueKey('financial-cashflow-chart-scroll')),
        findsOneWidget,
      );
      final balanceChart = find.byKey(
        const ValueKey('financial-balance-chart-scroll'),
      );
      final pageList = find.byKey(
        const ValueKey('financial-insights-list'),
      );
      for (var attempt = 0;
          attempt < 12 && balanceChart.evaluate().isEmpty;
          attempt++) {
        await tester.drag(pageList, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(balanceChart, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'balance trend preserves a missing month instead of compressing the timeline',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(240, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          Provider<FinancialInsightsRepository>.value(
            value: const _GappedBalanceTrendInsightsRepository(),
            child: MaterialApp(
              locale: const Locale('fa'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FinancialInsightsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final balanceScroll = find.byKey(
          const ValueKey('financial-balance-chart-scroll'),
        );
        await tester.scrollUntilVisible(
          balanceScroll,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final chartSemantics = tester.getSemantics(
          find.byKey(const ValueKey('financial-balance-chart-semantics')),
        );
        expect(chartSemantics.label, contains('2026-08'));
        expect(chartSemantics.label, contains('2026-09'));
        expect(chartSemantics.label, contains('2026-10'));
        expect(chartSemantics.label, contains('مانده پایانی ثبت نشده'));

        final chartSurface = find.descendant(
          of: balanceScroll,
          matching: find.byType(SizedBox),
        ).first;
        expect(
          tester.getSize(chartSurface).width,
          greaterThanOrEqualTo(192),
          reason: 'Keep all three month slots even when the middle value is absent.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'Wave 36 financial charts expose recorded series values to semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          Provider<FinancialInsightsRepository>.value(
            value: const _Wave24InsightsRepository(),
            child: MaterialApp(
              locale: const Locale('fa'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FinancialInsightsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final barScroll = find.byKey(
          const ValueKey('financial-cashflow-chart-scroll'),
        );
        await tester.scrollUntilVisible(
          barScroll,
          140,
          scrollable: find.byType(Scrollable).first,
        );
        final bars = tester.getSemantics(
          find.byKey(const ValueKey('financial-cashflow-chart-semantics')),
        );
        expect(bars.label, contains('جریان نقدی ماهانه'));
        expect(bars.label, contains('2026-05'));
        expect(bars.label, contains('تومان'));
        expect(bars.label, contains('اردیبهشت'));
        expect(bars.label, contains('ورودی'));
        expect(bars.label, contains('رزرو شده'));
        // Protect data fidelity, not just the presence of axis/series labels.
        expect(bars.label, contains('ورودی ۸۰ تومان'));
        expect(bars.label, contains('خروجی ۲۵ تومان'));
        expect(bars.label, contains('رزرو شده ۱۰ تومان'));

        final balanceScroll = find.byKey(
          const ValueKey('financial-balance-chart-scroll'),
        );
        final pageList = find.byKey(
          const ValueKey('financial-insights-list'),
        );
        for (var attempt = 0;
            attempt < 12 && balanceScroll.evaluate().isEmpty;
            attempt++) {
          await tester.drag(pageList, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(const ValueKey('financial-balance-scroll-hint')),
          findsOneWidget,
          reason: 'Six recorded months on a 360dp viewport must expose the horizontal-scroll cue.',
        );
        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey('financial-balance-scroll-hint'),
            ),
            matching: find.text('برای دیدن ماه‌های دیگر، نمودار را افقی بکشید'),
          ),
          findsOneWidget,
        );
        final balanceAxis = find.byKey(
          const ValueKey('financial-balance-y-axis'),
        );
        expect(balanceAxis, findsOneWidget);
        expect(
          find.descendant(of: balanceAxis, matching: find.byType(Text)),
          findsNWidgets(3),
        );
        final balance = tester.getSemantics(
          find.byKey(const ValueKey('financial-balance-chart-semantics')),
        );
        expect(balance.label, contains('روند موجودی'));
        expect(balance.label, contains('تومان'));
        expect(balance.label, contains('2026-05'));
        expect(balance.label, contains('2026-10'));
        // First and last recorded closing balances must be announced exactly.
        expect(balance.label, contains('2026-05: ۷۰۰٬۰۰۰ تومان'));
        expect(balance.label, contains('2026-10: ۱٬۲۰۰٬۰۰۰ تومان'));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'balance trend shows an explicit no-data state when no closing balances exist',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _EmptyBalanceInsightsRepository(),
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final zeroState = find.byKey(
        const ValueKey('financial-balance-zero-state'),
      );
      await tester.scrollUntilVisible(
        zeroState,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(zeroState, findsOneWidget);
      expect(
        find.text('No closing balance recorded for this period.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 3 recorded net cash flow matches the corresponding source activity amount',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          Provider<FinancialInsightsRepository>.value(
            value: const _Wave24InsightsRepository(),
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FinancialInsightsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Snapshot labels precede the chart legend, which repeats these labels.
        expect(find.text('Inflow').first, findsOneWidget);
        expect(find.text('500,000 TOMAN'), findsOneWidget);
        expect(find.text('Outflow').first, findsOneWidget);
        expect(find.text('120,000 TOMAN'), findsOneWidget);
        expect(find.text('Net cash flow'), findsOneWidget);

        final netValueFinder = find.text('380,000 TOMAN');
        expect(netValueFinder, findsOneWidget);
        final snapshotNetValue = tester.widget<Text>(netValueFinder).data!;
        expect(snapshotNetValue, '380,000 TOMAN');

        // Scroll to the independent source rollup and compare it to the
        // exact net value captured from the snapshot above.
        await tester.scrollUntilVisible(
          find.text('Financial activity sources'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final sourceSemantics = tester.getSemantics(
          find.byKey(const ValueKey('financial-source-row-JOB')),
        );
        expect(sourceSemantics.label, contains('Job'));
        expect(sourceSemantics.label, contains('amount $snapshotNetValue'));
        expect(sourceSemantics.label, contains('100%'));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );


  testWidgets(
    'malformed recorded summary values are shown as unrecorded, never as zero',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _MalformedSummaryInsightsRepository(),
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 TOMAN'), findsNothing);
      expect(find.text('—'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'a missing financial summary stays unrecorded instead of manufacturing six zero balances',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _MissingSummaryInsightsRepository(),
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 TOMAN'), findsNothing);
      expect(find.text('—'), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'missing monthly cash-flow series remain unrecorded in details and chart semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          Provider<FinancialInsightsRepository>.value(
            value: const _MissingCashFlowSeriesInsightsRepository(),
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FinancialInsightsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final toggle = find.byKey(
          const ValueKey('financial-cashflow-exact-values-toggle'),
        );
        await tester.scrollUntilVisible(
          toggle,
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();

        final details = find.byKey(
          const ValueKey('financial-cashflow-details-2026-10'),
        );
        expect(
          find.descendant(of: details, matching: find.text('—')),
          findsNWidgets(2),
        );
        expect(
          find.descendant(of: details, matching: find.text('120 TOMAN')),
          findsOneWidget,
        );

        final chart = tester.getSemantics(
          find.byKey(const ValueKey('financial-cashflow-chart-semantics')),
        );
        expect(chart.label, contains('inflow —'));
        expect(chart.label, contains('outflow 120 TOMAN'));
        expect(chart.label, contains('reserved —'));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );


  testWidgets('balance-trend points without a recorded amount are not plotted as zero', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(Provider<FinancialInsightsRepository>.value(
      value: const _MissingBalancePointInsightsRepository(),
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const FinancialInsightsPage(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Balance trend'), 160,
      scrollable: find.byType(Scrollable).first);
    expect(find.text('No closing balance recorded for this period.'), findsOneWidget);
    expect(find.byKey(const ValueKey('financial-balance-chart-semantics')), findsNothing);
    expect(tester.takeException(), isNull);
  });


  testWidgets(
    'financial source rows do not invent zero amounts or shares when amount is missing',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          Provider<FinancialInsightsRepository>.value(
            value: const _MissingSourceAmountInsightsRepository(),
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FinancialInsightsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Financial activity sources'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final row = tester.getSemantics(
          find.byKey(const ValueKey('financial-source-row-JOB')),
        );
        expect(row.label, contains('amount —'));
        expect(row.label, contains('— of recorded source activity'));
        expect(row.label, isNot(contains('amount 0 TOMAN')));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );


  testWidgets(
    'non-finite cash-flow amounts stay unrecorded and cannot poison chart scaling',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _NonFiniteCashFlowInsightsRepository(),
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'NaN and infinite amounts must not reach chart scale calculations.',
      );

      final noRecordedValues = find.byKey(
        const ValueKey('financial-cashflow-zero-state'),
      );
      await tester.scrollUntilVisible(
        noRecordedValues,
        140,
        scrollable: find.byType(Scrollable).first,
      );
      expect(noRecordedValues, findsOneWidget);
      expect(
        find.text('No cash-flow amounts were recorded for this period.'),
        findsOneWidget,
      );

      final exactValues = find.byKey(
        const ValueKey('financial-cashflow-exact-values-toggle'),
      );
      await tester.scrollUntilVisible(
        exactValues,
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(exactValues);
      await tester.pumpAndSettle();

      final details = find.byKey(
        const ValueKey('financial-cashflow-details-2026-10'),
      );
      expect(
        find.descendant(of: details, matching: find.text('—')),
        findsNWidgets(3),
      );
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'financial charts reserve enough x-axis label height at 2x scale on a compact viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _Wave24InsightsRepository(),
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cashFlowChart = find.byKey(
        const ValueKey('financial-cashflow-chart-scroll'),
      );
      await tester.scrollUntilVisible(
        cashFlowChart,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      final cashFlowChartRow = find.ancestor(
        of: cashFlowChart,
        matching: find.byType(Row),
      ).first;
      final xAxisLabelRegion = find.descendant(
        of: cashFlowChartRow,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.height != null &&
              widget.height! < 40 &&
              widget.child is Align,
        ),
      );
      expect(xAxisLabelRegion, findsOneWidget);
      expect(
        tester.widget<SizedBox>(xAxisLabelRegion).height!,
        greaterThanOrEqualTo(29.4),
        reason: 'A 2x-scaled 12sp label needs at least 26.4dp plus the 3dp plot gap.',
      );

      final balanceChart = find.byKey(
        const ValueKey('financial-balance-chart-scroll'),
      );
      await tester.scrollUntilVisible(
        balanceChart,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      final balanceYAxis = find.byKey(
        const ValueKey('financial-balance-y-axis'),
      );
      final labelPaddingFinder = find.ancestor(
        of: balanceYAxis,
        matching: find.byType(Padding),
      ).first;
      final bottomLabelPadding =
          (tester.widget<Padding>(labelPaddingFinder).padding as EdgeInsets).bottom;
      expect(
        bottomLabelPadding,
        greaterThanOrEqualTo(26.4),
        reason: 'The balance plot must reserve the full 2x-scaled x-axis label height.',
      );
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'cash-flow chart series use distinct HOPE semantic tones in light and dark themes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> verifySeries(Brightness brightness) async {
        await tester.pumpWidget(
          Provider<FinancialInsightsRepository>.value(
            value: const _Wave24InsightsRepository(),
            child: MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.dark()
                  : AppTheme.light(),
              locale: const Locale('fa'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FinancialInsightsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final legend = find.byKey(const ValueKey('financial-cashflow-legend'));
        await tester.scrollUntilVisible(
          legend,
          140,
          scrollable: find.byType(Scrollable).first,
        );

        final dark = brightness == Brightness.dark;
        final expectedInflow = dark
            ? HopeV2TonalPalettes.success.shade400
            : HopeV2TonalPalettes.success.shade700;
        final expectedOutflow = dark
            ? HopeV2TonalPalettes.danger.shade400
            : HopeV2TonalPalettes.danger.shade700;
        final expectedReserved = dark
            ? HopeV2TonalPalettes.warning.shade300
            : HopeV2TonalPalettes.warning.shade700;

        Color? legendColor(IconData icon) => tester
            .widget<Icon>(
              find.descendant(of: legend, matching: find.byIcon(icon)),
            )
            .color;

        expect(
          legendColor(HopeV2Icons.transferIn),
          expectedInflow,
          reason: 'Cash inflow uses the success family, not the brand action hue.',
        );
        expect(
          legendColor(HopeV2Icons.transferOut),
          expectedOutflow,
          reason: 'Cash outflow has a distinct danger/negative-flow series.',
        );
        expect(
          legendColor(HopeV2Icons.secure),
          expectedReserved,
          reason: 'Reserved cash uses the amber pending family.',
        );
        expect(tester.takeException(), isNull);
      }

      await verifySeries(Brightness.light);
      await verifySeries(Brightness.dark);
    },
  );


  testWidgets(
    'cash-flow axis unit aligns with the tick-label edge in Persian RTL',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        Provider<FinancialInsightsRepository>.value(
          value: const _Wave24InsightsRepository(),
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FinancialInsightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unit = find.byKey(
        const ValueKey('financial-cashflow-axis-unit'),
      );
      await tester.scrollUntilVisible(
        unit,
        140,
        scrollable: find.byType(Scrollable).first,
      );
      expect(unit, findsOneWidget);
      expect(tester.widget<Text>(unit).data, 'تومان');

      final unitAlignment = find.byKey(
        const ValueKey('financial-cashflow-axis-unit-alignment'),
      );
      expect(unitAlignment, findsOneWidget);
      expect(
        tester.widget<Align>(unitAlignment).alignment,
        AlignmentDirectional.centerEnd,
        reason:
            'In Persian RTL, the unit should share the inner axis edge with the tick labels, not float at the outer card edge.',
      );

      final topTick = find.byKey(
        const ValueKey('financial-cashflow-y-tick-4'),
      );
      expect(topTick, findsOneWidget);
      expect(tester.widget<Text>(topTick).textAlign, TextAlign.end);
      expect(tester.takeException(), isNull);
    },
  );

}
