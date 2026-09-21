import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
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
        baseAmount: 1000000,
        employerFee: 100000,
        workerFee: 100000,
        platformFee: 0,
        employerCharge: 1100000,
        providerPayout: 900000,
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
  });

  testWidgets(
      'PremiumPaymentSummary always presents the current internal ledger as Toman',
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
  });
}
