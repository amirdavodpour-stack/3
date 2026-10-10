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
    expect(find.text('Worker One'), findsWidgets);
    expect(find.text('۹۱٫۴٪'), findsWidgets);
    expect(find.text('مهارت'), findsWidgets);
    expect(find.text('تجربه'), findsWidgets);
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
  testWidgets('wide candidate view compares real component scores in one matrix',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const data = HopeEmployerCandidateMatchList(
      jobId: 'job-compare',
      kind: 'JOB',
      candidates: [
        HopeEmployerCandidateMatch(
          rank: 1,
          userId: 'worker-1',
          displayName: 'Candidate One',
          score: 94.0,
          reasons: ['SKILL_MATCH'],
          components: {'skills': 98.0, 'experience': 90.0, 'location': 94.0, 'salary': 87.0},
          applicationId: 'app-1',
          status: 'PENDING',
          skills: 'Flutter, Dart',
        ),
        HopeEmployerCandidateMatch(
          rank: 2,
          userId: 'worker-2',
          displayName: 'Candidate Two',
          score: 91.0,
          reasons: ['EXPERIENCE_MATCH'],
          components: {'skills': 90.0, 'experience': 92.0, 'location': 91.0, 'salary': 89.0},
          applicationId: 'app-2',
          status: 'PENDING',
          skills: 'Flutter, UI',
        ),
        HopeEmployerCandidateMatch(
          rank: 3,
          userId: 'worker-3',
          displayName: 'Candidate Three',
          score: 84.0,
          reasons: ['LOCATION_MATCH'],
          components: {'skills': 84.0, 'experience': 83.0, 'location': 95.0, 'salary': 82.0},
          applicationId: 'app-3',
          status: 'PENDING',
          skills: 'Dart, design',
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
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('candidate-comparison-matrix')),
      findsOneWidget,
    );
    expect(find.text('Candidate One'), findsWidgets);
    expect(find.text('Candidate Two'), findsWidgets);
    expect(find.text('Candidate Three'), findsWidgets);
    expect(find.text('۹۸٪'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
