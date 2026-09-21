import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';

void main() {
  testWidgets('opportunity card labels mission budget in Toman',
      (tester) async {
    final job = HopeJob.fromMap({
      'id': 'job-1',
      'title': 'طراحی صفحه',
      'description': 'یک توضیح کافی برای نمایش فرصت.',
      'categoryId': 'design',
      'category': 'طراحی',
      'jobType': 'FIXED',
      'budgetMin': '100000',
      'budgetMax': '200000',
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: OpportunityCard(job: job),
        ),
      ),
    );

    expect(find.textContaining('تومان'), findsOneWidget);
  });
}
