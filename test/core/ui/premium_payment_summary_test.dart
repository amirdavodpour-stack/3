import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/ui/premium_payment_summary.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

HopePayment _payment({String currency = 'IRR', String status = 'HELD'}) => HopePayment(
      id: 'p1',
      status: status,
      amount: '1000000',
      job: HopeJob.fromMap({
        'id': 'j1',
        'title': 'Design landing page',
        'description': 'Deliver a landing page.',
        'categoryId': 'c1',
        'kind': 'MISSION',
        'status': 'FUNDED',
        'ownerId': 'u1',
        'providerId': 'u2',
        'visibility': 'PUBLIC',
        'budgetMin': '1000000',
        'budgetMax': '1500000',
        'offerCount': 0,
        'isOwner': true,
      }),
      fees: HopePaymentFees(
        baseAmount: '1000000',
        employerFee: '100000',
        workerFee: '100000',
        platformFee: '200000',
        employerCharge: '1100000',
        providerPayout: '900000',
        policyVersion: 'v1',
        currency: currency,
      ),
    );

void main() {
  testWidgets('PremiumPaymentSummary safely localizes unknown payment status',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: PremiumPaymentSummary(
            payment: _payment(status: 'UNKNOWN_STATUS'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('UNKNOWN_STATUS'), findsNothing);

    final iconFinder = find.byKey(const ValueKey('premium-payment-status-icon'));
    expect(iconFinder, findsOneWidget);
    final icon = tester.widget<HopeIcon>(iconFinder);
    final iconContext = tester.element(iconFinder);
    expect(icon.color, HopeV2SemanticColors.pending(iconContext));
    expect(
      icon.color,
      isNot(Theme.of(iconContext).colorScheme.primary),
      reason: 'An unknown/pending payment state is semantic status, not the brand action color.',
    );
  });

  testWidgets(
      'PremiumPaymentSummary groups integral decimal amounts without exposing a decimal suffix',
      (tester) async {
    final payment = _payment();
    final decimalPayment = HopePayment(
      id: payment.id,
      status: payment.status,
      amount: '2000000.0',
      providerRef: payment.providerRef,
      job: payment.job,
      fees: HopePaymentFees(
        baseAmount: '2000000.0',
        employerFee: payment.fees!.employerFee,
        workerFee: payment.fees!.workerFee,
        platformFee: payment.fees!.platformFee,
        employerCharge: payment.fees!.employerCharge,
        providerPayout: payment.fees!.providerPayout,
        policyVersion: payment.fees!.policyVersion,
        currency: payment.fees!.currency,
      ),
      createdAt: payment.createdAt,
      updatedAt: payment.updatedAt,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: PremiumPaymentSummary(payment: decimalPayment),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2,000,000 Toman'), findsOneWidget);
    expect(find.text('2000000.0 Toman'), findsNothing);
  });


  testWidgets(
      'PremiumPaymentSummary prefers canonical baseAmount over the legacy amount field',
      (tester) async {
    final original = _payment(currency: 'TOMAN');
    final payment = HopePayment(
      id: original.id,
      status: original.status,
      amount: '2500000',
      providerRef: original.providerRef,
      job: original.job,
      fees: original.fees,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: PremiumPaymentSummary(payment: payment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Base amount'), findsOneWidget);
    expect(find.text('1,000,000 Toman'), findsOneWidget);
    expect(find.text('2,500,000 Toman'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Payment status: Funds held, Base amount 1,000,000 Toman, Employer charge 1,100,000 Toman, Worker payout 900,000 Toman',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'PremiumPaymentSummary displays employer and worker fee amounts separately',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: PremiumPaymentSummary(payment: _payment(currency: 'TOMAN')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Base amount'), findsOneWidget);
    expect(find.text('Employer charge'), findsOneWidget);
    expect(find.text('Worker payout'), findsOneWidget);
    expect(find.text('Employer fee'), findsOneWidget);
    expect(find.text('Worker fee'), findsOneWidget);
    expect(find.text('100,000 Toman'), findsNWidgets(2));
    expect(find.text('Platform fee'), findsOneWidget);
    expect(find.text('200,000 Toman'), findsOneWidget);
    expect(find.text('1,100,000 Toman'), findsOneWidget);
    expect(find.text('900,000 Toman'), findsOneWidget);
  });

  testWidgets(
      'PremiumPaymentSummary preserves the JOB fee contract with zero worker fee',
      (tester) async {
    final payment = HopePayment.fromMap({
      'id': 'job-payment',
      'status': 'HELD',
      'amount': '30000000',
      'job': {
        'id': 'job-1',
        'title': 'Monthly job',
        'description': 'First month salary',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
      },
      'fees': {
        'baseAmount': '30000000',
        'employerFee': '9000000',
        'workerFee': '0',
        'platformFee': '9000000',
        'employerCharge': '39000000',
        'providerPayout': '30000000',
        'policyVersion': '2026-08-v1',
        'currency': 'TOMAN',
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: PremiumPaymentSummary(payment: payment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Employer fee'), findsOneWidget);
    expect(find.text('Worker fee'), findsOneWidget);
    expect(find.text('9,000,000 Toman'), findsNWidgets(2));
    expect(find.text('0 Toman'), findsOneWidget);
    expect(find.text('39,000,000 Toman'), findsOneWidget);
  });

  testWidgets(
      'PremiumPaymentSummary formats Persian Toman with Persian digits',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: PremiumPaymentSummary(payment: _payment(currency: 'TOMAN')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('۱٬۰۰۰٬۰۰۰ تومان'), findsWidgets);
    expect(find.textContaining('1,000,000 تومان'), findsNothing);
  });

  testWidgets(
      'PremiumPaymentSummary always formats monetary amounts as Toman',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: PremiumPaymentSummary(payment: _payment(currency: 'IRR')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final values = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .toList();

    expect(values.where((value) => value.contains('IRR')), isEmpty);
    expect(values.any((value) => value.contains('1,000,000 Toman')), isTrue);
    expect(values.any((value) => value.contains('1,100,000 Toman')), isTrue);
    expect(values.any((value) => value.contains('900,000 Toman')), isTrue);

    for (final amount in [
      '1,000,000 Toman',
      '1,100,000 Toman',
      '900,000 Toman',
    ]) {
      final amountFinder = find.text(amount);
      expect(amountFinder, findsOneWidget);
      final amountText = tester.widget<Text>(amountFinder);
      expect(
        amountText.style?.color,
        HopeV2SemanticColors.price(tester.element(amountFinder)),
        reason: 'Every displayed payment amount must use the shared semantic price foreground.',
      );
    }
  });

  testWidgets('PremiumPaymentSummary exposes one financial summary semantics boundary',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: PremiumPaymentSummary(payment: _payment()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump();
    expect(
      find.bySemanticsLabel(
        'Payment status: Funds held, Base amount 1,000,000 Toman, Employer charge 1,100,000 Toman, Worker payout 900,000 Toman',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Payment details, Funds held'),
      findsNothing,
    );
    semantics.dispose();
  });
}
