import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/features/marketplace/job_detail_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/marketplace/employer_candidate_matching_repository.dart';
import 'package:hope_mobile/features/marketplace/employer_candidate_matches_page.dart';

void main() {
  testWidgets(
    'candidate compensation component renders in the localized salary breakdown',
    (tester) async {
      const data = HopeEmployerCandidateMatchList(
        jobId: 'candidate-compensation',
        kind: 'JOB',
        candidates: [
          HopeEmployerCandidateMatch(
            rank: 1,
            userId: 'worker-compensation',
            displayName: 'Candidate Compensation',
            score: 91,
            components: {'skills': 90, 'compensation': 85},
            applicationId: 'app-compensation',
            status: 'PENDING',
          ),
        ],
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
            body: EmployerCandidateMatchesPage(data: data, onRetry: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final salarySignal = find.byKey(
        const ValueKey('candidate-signal-salary'),
      );
      expect(salarySignal, findsOneWidget);
      expect(
        find.descendant(of: salarySignal, matching: find.text('Salary')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: salarySignal, matching: find.text('85%')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'candidate card preserves the full skills summary at 1.5x text scale',
    (tester) async {
      const longSkills =
          'Flutter, Dart, accessibility audits, financial workflow reconciliation and responsive interface engineering';
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const data = HopeEmployerCandidateMatchList(
        jobId: 'job-long-card-skills',
        kind: 'JOB',
        candidates: [
          HopeEmployerCandidateMatch(
            rank: 1,
            userId: 'worker-long-card-skills',
            displayName: 'Candidate One',
            score: 94,
            reasons: ['SKILL_MATCH'],
            components: {'skills': 98, 'experience': 90},
            applicationId: 'app-long-card-skills',
            status: 'PENDING',
            skills: longSkills,
          ),
        ],
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: EmployerCandidateMatchesPage(data: data, onRetry: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final skillsFinder = find.text(longSkills);
      expect(skillsFinder, findsOneWidget);
      final skills = tester.widget<Text>(skillsFinder);
      expect(
        skills.maxLines,
        isNull,
        reason: 'The ranked candidate card should not hard-truncate a skills summary when system text is enlarged.',
      );
      expect(skills.overflow, TextOverflow.visible);
      expect(
        tester.renderObject<RenderParagraph>(skillsFinder).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'candidate component progress bars remain safe for out-of-range API values',
    (tester) async {
      const data = HopeEmployerCandidateMatchList(
        jobId: 'invalid-components',
        kind: 'JOB',
        candidates: [
          HopeEmployerCandidateMatch(
            rank: 1,
            userId: 'worker-invalid-components',
            displayName: 'Candidate with stale scoring data',
            score: 92,
            components: {
              'skills': 150,
              'experience': -25,
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
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

      final indicators = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .where((indicator) => indicator.value != null)
          .toList(growable: false);
      expect(indicators, hasLength(2));
      for (final indicator in indicators) {
        expect(indicator.value, inInclusiveRange(0.0, 1.0));
      }
      expect(tester.takeException(), isNull);
    },
  );



  testWidgets(
    'fractional candidate scores normalize before display and gap calculation',
    (tester) async {
      const data = HopeEmployerCandidateMatchList(
        jobId: 'fractional-scores',
        kind: 'JOB',
        candidates: [
          HopeEmployerCandidateMatch(
            rank: 1,
            userId: 'worker-94',
            displayName: 'Candidate 94',
            score: 0.94,
          ),
          HopeEmployerCandidateMatch(
            rank: 2,
            userId: 'worker-91',
            displayName: 'Candidate 91',
            score: 0.91,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
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
        find.descendant(
          of: find.byKey(const ValueKey('candidate-comparison-best-score')),
          matching: find.text('94%'),
        ),
        findsOneWidget,
      );
      expect(find.text('91%'), findsWidgets);
      expect(find.text('3 percentage-point gap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );


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
          reasons: ['SKILL_MATCH', 'EXPERIENCE_MATCH', 'FUTURE_SIGNAL_CODE'],
          components: {'skills': 100, 'experience': 90},
          applicationId: 'app-1',
          status: 'PENDING',
          skills: 'Flutter Dart',
          offerPrice: '1250000',
        ),
        HopeEmployerCandidateMatch(
          rank: 2,
          userId: 'worker-2',
          displayName: 'Worker Two',
          score: 86.4,
          reasons: ['SKILL_MATCH'],
          components: {'skills': 82, 'experience': 86},
          applicationId: 'app-2',
          status: 'PENDING',
          skills: 'Flutter UI',
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
    expect(find.text('اختلاف ۵ واحد درصد'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('candidate-comparison-best-score')),
        matching: find.text('۹۱٫۴٪'),
      ),
      findsOneWidget,
      reason: 'The Best Match overview must preserve the source score precision.',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('candidate-match-score-worker-1')),
        matching: find.text('۹۱٫۴٪'),
      ),
      findsOneWidget,
      reason: 'The first candidate card must use the same score precision.',
    );
    expect(find.text('مهارت'), findsWidgets);
    expect(find.text('تجربه'), findsWidgets);
    expect(
      find.text('FUTURE_SIGNAL_CODE'),
      findsNothing,
      reason: 'Unknown backend reason codes must never be shown as customer-facing labels.',
    );
    expect(
      find.textContaining('۱٬۲۵۰٬۰۰۰ تومان'),
      findsOneWidget,
      reason: 'Offer amounts on candidate cards must use the shared fa-RTL Toman formatter.',
    );
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
          components: {'skills': 84.0, 'experience': 83.0, 'location': 95.0},
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
        theme: AppTheme.dark(),
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
    final leadingCandidateHeader = tester.widget<Container>(
      find.byKey(
        const ValueKey('candidate-comparison-leading-candidate-header'),
      ),
    );
    expect(
      (leadingCandidateHeader.decoration as BoxDecoration).color,
      isNotNull,
      reason: 'The best-ranked real candidate should remain visually identifiable down the comparison matrix.',
    );
    final leadingHeaderText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('candidate-comparison-matrix')),
        matching: find.text('Candidate One'),
      ),
    );
    final matrixContext = tester.element(
      find.byKey(const ValueKey('candidate-comparison-matrix')),
    );
    expect(
      leadingHeaderText.style?.color,
      HopeV2SemanticColors.textPrimary(matrixContext),
      reason: 'Candidate matrix headings must stay neutral; indigo is reserved for action and selection graphics.',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('candidate-comparison-matrix')),
        matching: find.text('۹۸٪'),
      ),
      findsOneWidget,
      reason: 'Matrix percentages must use the shared Persian display formatter.',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('candidate-comparison-matrix')),
        matching: find.text('98٪'),
      ),
      findsNothing,
      reason: 'Raw Latin digits must not leak into the Persian comparison matrix.',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('candidate-comparison-matrix')),
        matching: find.text('ثبت نشده'),
      ),
      findsOneWidget,
      reason: 'Missing score data must be identified as unavailable, never presented as zero or left as an ambiguous dash.',
    );
    expect(tester.takeException(), isNull);
  });


  testWidgets(
    'Wave 34 compact phones can compare real candidate values in a horizontal matrix',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const data = HopeEmployerCandidateMatchList(
        jobId: 'job-compact-compare',
        kind: 'JOB',
        candidates: [
          HopeEmployerCandidateMatch(
            rank: 1,
            userId: 'worker-1',
            displayName: 'Candidate One',
            score: 94,
            reasons: ['SKILL_MATCH'],
            components: {'skills': 98, 'experience': 90, 'location': 94, 'salary': 87},
            applicationId: 'app-1',
            status: 'PENDING',
            skills: 'Flutter, Dart',
          ),
          HopeEmployerCandidateMatch(
            rank: 2,
            userId: 'worker-2',
            displayName: 'Candidate Two',
            score: 91,
            reasons: ['EXPERIENCE_MATCH'],
            components: {'skills': 90, 'experience': 92, 'location': 91, 'salary': 89},
            applicationId: 'app-2',
            status: 'PENDING',
            skills: 'Flutter, UI',
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
            body: EmployerCandidateMatchesPage(data: data, onRetry: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final matrix = find.byKey(const ValueKey('candidate-comparison-matrix'));
      expect(matrix, findsOneWidget);
      final horizontalScroll = find.descendant(
        of: matrix,
        matching: find.byType(SingleChildScrollView),
      );
      expect(horizontalScroll, findsOneWidget);
      expect(find.text('Candidate Two'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'candidate names preserve their full wording at 1.5x text scale',
    (tester) async {
      const longName =
          'Senior financial systems analyst responsible for marketplace settlement operations';
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const data = HopeEmployerCandidateMatchList(
        jobId: 'job-long-candidate-name',
        kind: 'JOB',
        candidates: [
          HopeEmployerCandidateMatch(
            rank: 1,
            userId: 'worker-long-name',
            displayName: longName,
            score: 94,
            reasons: ['SKILL_MATCH'],
            components: {'skills': 98, 'experience': 90},
            applicationId: 'app-long-name',
            status: 'PENDING',
            skills: 'Flutter and financial workflows',
          ),
        ],
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: EmployerCandidateMatchesPage(data: data, onRetry: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text(longName);
      expect(titleFinder, findsNWidgets(2));
      for (final title in tester.widgetList<Text>(titleFinder)) {
        expect(
          title.maxLines,
          isNull,
          reason:
              'Both the best-match overview and ranked candidate card must preserve the full display name at enlarged system text.',
        );
        expect(title.overflow, TextOverflow.visible);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'candidate comparison matrix fully wraps long names and skills at 1.5x',
    (tester) async {
      const longName =
          'Senior financial systems analyst responsible for marketplace settlement operations';
      const longSkills =
          'Flutter, Dart, accessibility audits, financial workflow reconciliation and responsive interface engineering';
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const data = HopeEmployerCandidateMatchList(
        jobId: 'job-long-matrix-values',
        kind: 'JOB',
        candidates: [
          HopeEmployerCandidateMatch(
            rank: 1,
            userId: 'worker-long-matrix-name',
            displayName: longName,
            score: 94,
            reasons: ['SKILL_MATCH'],
            components: {'experience': 90, 'location': 82},
            applicationId: 'app-long-matrix-name',
            status: 'PENDING',
            skills: longSkills,
          ),
          HopeEmployerCandidateMatch(
            rank: 2,
            userId: 'worker-second-matrix',
            displayName: 'Candidate Two',
            score: 86,
            reasons: ['CATEGORY_MATCH'],
            components: {'experience': 84, 'location': 80},
            applicationId: 'app-second-matrix',
            status: 'PENDING',
            skills: 'Flutter',
          ),
        ],
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: EmployerCandidateMatchesPage(data: data, onRetry: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final matrix = find.byKey(
        const ValueKey('candidate-comparison-matrix'),
      );
      expect(matrix, findsOneWidget);

      for (final wording in [longName, longSkills]) {
        final valueFinder = find.descendant(
          of: matrix,
          matching: find.text(wording),
        );
        expect(valueFinder, findsOneWidget);
        final value = tester.widget<Text>(valueFinder);
        expect(
          value.maxLines,
          isNull,
          reason:
              'Candidate names and skills inside the comparison matrix must retain their full wording at enlarged text.',
        );
        expect(value.overflow, TextOverflow.visible);
        expect(
          tester.renderObject<RenderParagraph>(valueFinder).didExceedMaxLines,
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'candidate match loader uses a single compact page shell in loading and loaded states',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pending = Completer<HopeEmployerCandidateMatchList>();
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
          home: EmployerCandidateMatchesLoader(
            future: pending.future,
            jobTitle: 'Flutter role',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Loading matches'), findsOneWidget);
      expect(find.byType(PremiumPageFrame), findsOneWidget);
      expect(
        tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame)).padding,
        const EdgeInsets.fromLTRB(14, 10, 14, 24),
      );
      expect(tester.takeException(), isNull);

      pending.complete(
        const HopeEmployerCandidateMatchList(
          jobId: 'job-1',
          kind: 'JOB',
          candidates: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PremiumPageFrame), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

}
