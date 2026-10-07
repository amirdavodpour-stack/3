import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

import 'package:hope_mobile/core/marketplace/employer_candidate_matching_repository.dart';
import 'package:hope_mobile/features/marketplace/employer_candidate_matches_page.dart';

void main() {
  testWidgets('renders ranked candidates with compatibility score and reasons',
      (tester) async {
    const data = HopeEmployerCandidateMatchList(
      jobId: 'job-1',
      kind: 'JOB',
      candidates: [
        HopeEmployerCandidateMatch(
          rank: 1,
          userId: 'worker-1',
          displayName: 'Worker One',
          score: 91.4,
          reasons: ['SKILL_MATCH', 'EXPERIENCE_MATCH'],
          components: {'skills': 100, 'experience': 90},
          applicationId: 'app-1',
          status: 'PENDING',
          skills: 'Flutter Dart',
        ),
      ],
    );

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
          body: EmployerCandidateMatchesPage(
            data: data,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('پذیرندگان بر اساس انطباق'), findsOneWidget);
    expect(find.text('Worker One'), findsOneWidget);
    expect(find.text('91.4٪'), findsOneWidget);
    expect(find.text('مهارت'), findsOneWidget);
    expect(find.text('تجربه'), findsOneWidget);
  });

  testWidgets('shows empty state when no workers accepted the opportunity',
      (tester) async {
    const data = HopeEmployerCandidateMatchList(
      jobId: 'mission-1',
      kind: 'MISSION',
      candidates: [],
    );

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
          body: EmployerCandidateMatchesPage(
            data: data,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('هنوز پذیرنده‌ای برای این موقعیت نیست.'), findsOneWidget);
  });
}
