import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/financial/financial_insights_repository.dart';
import 'package:hope_mobile/features/financial/financial_insights_page.dart';
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

void main() {
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
        expect(bars.label, contains('اردیبهشت'));
        expect(bars.label, contains('ورودی'));
        expect(bars.label, contains('رزرو شده'));

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
        final balance = tester.getSemantics(
          find.byKey(const ValueKey('financial-balance-chart-semantics')),
        );
        expect(balance.label, contains('2026-05'));
        expect(balance.label, contains('2026-10'));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );
}
