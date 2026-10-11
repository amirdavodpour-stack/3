import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/jobs/job_satisfaction_repository.dart';
import 'package:hope_mobile/features/jobs/job_satisfaction_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeJobSatisfactionRepository implements JobSatisfactionRepository {
  bool submitted = false;
  bool failNextSubmit = false;
  int submitAttempts = 0;
  String? submittedJobId;
  int? submittedOverallRating;
  bool? submittedCompletedAsAgreed;
  int? submittedCommunicationRating;
  String? submittedReport;

  @override
  Future<JobSatisfactionState> getState(String jobId) async =>
      JobSatisfactionState(
        jobId: jobId,
        role: 'CLIENT',
        questions: const [],
        submitted: false,
        feedback: null,
        submittedCount: 0,
        requiredCount: 2,
        dispute: null,
      );

  @override
  Future<Map<String, dynamic>> submit({
    required String jobId,
    required int overallRating,
    required bool completedAsAgreed,
    required int communicationRating,
    required String report,
  }) async {
    submitAttempts += 1;
    submittedJobId = jobId;
    submittedOverallRating = overallRating;
    submittedCompletedAsAgreed = completedAsAgreed;
    submittedCommunicationRating = communicationRating;
    submittedReport = report;
    if (failNextSubmit) {
      failNextSubmit = false;
      throw StateError('simulated submit failure');
    }
    submitted = true;
    return <String, dynamic>{};
  }

  @override
  Future<List<HopeJobSatisfaction>> history() async => const [];
}

void expectRenderedSemantics(
  WidgetTester tester, {
  required String label,
  required String value,
  required String hint,
}) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
  final node = tester.getSemantics(finder);
  expect(node.label, label);
  expect(node.value, value);
  expect(node.hint, hint);
}

Future<void> revealLazyListChild(
  WidgetTester tester,
  Finder target, {
  double scrollStep = 160,
  int maxAttempts = 24,
}) async {
  final list = find.byType(ListView).first;
  var attempts = 0;
  while (target.evaluate().isEmpty && attempts < maxAttempts) {
    await tester.drag(list, Offset(0, -scrollStep));
    await tester.pumpAndSettle();
    attempts += 1;
  }
  expect(
    target,
    findsOneWidget,
    reason: 'Lazy list child should be built after scrolling the viewport.',
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'satisfaction form never preselects positive answers or permits an incomplete submit',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeJobSatisfactionRepository();
      final semantics = tester.ensureSemantics();

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
          home: Provider<JobSatisfactionRepository>.value(
            value: repository,
            child: const JobSatisfactionPage(jobId: 'job-1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final ratings = tester
          .widgetList<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .toList(growable: false);
      expect(ratings, hasLength(2));
      expect(ratings.every((rating) => rating.selected.isEmpty), isTrue);
      expectRenderedSemantics(
        tester,
        label: 'رضایت کلی',
        value: 'انتخاب نشده',
        hint: 'از ۱ (کاملاً ناراضی) تا ۵ (کاملاً راضی) انتخاب کنید',
      );
      expectRenderedSemantics(
        tester,
        label: 'ارتباط و هماهنگی',
        value: 'انتخاب نشده',
        hint: 'از ۱ (بسیار ضعیف) تا ۵ (عالی) انتخاب کنید',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'رضایت کلی' &&
              widget.properties.value == 'انتخاب نشده' &&
              widget.properties.hint ==
                  'از ۱ (کاملاً ناراضی) تا ۵ (کاملاً راضی) انتخاب کنید',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'ارتباط و هماهنگی' &&
              widget.properties.value == 'انتخاب نشده' &&
              widget.properties.hint ==
                  'از ۱ (بسیار ضعیف) تا ۵ (عالی) انتخاب کنید',
        ),
        findsOneWidget,
      );
      for (final endpoint in ['کاملاً ناراضی', 'کاملاً راضی', 'بسیار ضعیف', 'عالی']) {
        expect(
          find.text(endpoint),
          findsOneWidget,
          reason: 'Rating scales should explain endpoint $endpoint in visible copy.',
        );
      }
      for (final digit in ['۱', '۲', '۳', '۴', '۵']) {
        expect(
          find.text(digit),
          findsNWidgets(2),
          reason: 'Both Persian rating controls should localize digit $digit.',
        );
      }

      await tester.tap(find.text('۳').first);
      await tester.pump();
      expectRenderedSemantics(
        tester,
        label: 'رضایت کلی',
        value: '۳',
        hint: 'از ۱ (کاملاً ناراضی) تا ۵ (کاملاً راضی) انتخاب کنید',
      );
      expect(
        tester.widgetList<SegmentedButton<int>>(
          find.byType(SegmentedButton<int>),
        ).first.selected,
        <int>{3},
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'رضایت کلی' &&
              widget.properties.value == '۳' &&
              widget.properties.hint ==
                  'از ۱ (کاملاً ناراضی) تا ۵ (کاملاً راضی) انتخاب کنید',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('۳').first);
      await tester.pump();
      expectRenderedSemantics(
        tester,
        label: 'رضایت کلی',
        value: 'انتخاب نشده',
        hint: 'از ۱ (کاملاً ناراضی) تا ۵ (کاملاً راضی) انتخاب کنید',
      );
      expect(
        tester.widgetList<SegmentedButton<int>>(
          find.byType(SegmentedButton<int>),
        ).first.selected,
        isEmpty,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'رضایت کلی' &&
              widget.properties.value == 'انتخاب نشده',
        ),
        findsOneWidget,
      );

      final agreement = tester.widget<SegmentedButton<bool>>(
        find.byKey(const ValueKey('satisfaction-agreement-choice')),
      );
      expect(agreement.selected, isEmpty);
      expectRenderedSemantics(
        tester,
        label: 'کار مطابق توافق انجام شد؟',
        value: 'انتخاب نشده',
        hint: 'بله یا خیر را انتخاب کنید',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'کار مطابق توافق انجام شد؟' &&
              widget.properties.value == 'انتخاب نشده' &&
              widget.properties.hint == 'بله یا خیر را انتخاب کنید',
        ),
        findsOneWidget,
      );
      final submitFinder = find.byKey(
        const ValueKey('job-satisfaction-submit'),
      );
      await tester.scrollUntilVisible(
        submitFinder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final submit = tester.widget<FilledButton>(submitFinder);
      expect(submit.onPressed, isNull);
      expect(repository.submitted, isFalse);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'English rating controls expose endpoint guidance and keep incomplete submit disabled',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeJobSatisfactionRepository();
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Provider<JobSatisfactionRepository>.value(
            value: repository,
            child: const JobSatisfactionPage(jobId: 'job-1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final ratings = tester
          .widgetList<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .toList(growable: false);
      expect(ratings, hasLength(2));
      expect(ratings.every((rating) => rating.selected.isEmpty), isTrue);
      expectRenderedSemantics(
        tester,
        label: 'Overall satisfaction',
        value: 'Not selected',
        hint: 'Choose a rating from 1 (Very dissatisfied) to 5 (Very satisfied)',
      );
      expectRenderedSemantics(
        tester,
        label: 'Communication and coordination',
        value: 'Not selected',
        hint: 'Choose a rating from 1 (Very poor) to 5 (Excellent)',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Overall satisfaction' &&
              widget.properties.value == 'Not selected' &&
              widget.properties.hint ==
                  'Choose a rating from 1 (Very dissatisfied) to 5 (Very satisfied)',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Communication and coordination' &&
              widget.properties.value == 'Not selected' &&
              widget.properties.hint ==
                  'Choose a rating from 1 (Very poor) to 5 (Excellent)',
        ),
        findsOneWidget,
      );
      for (final endpoint in [
        'Very dissatisfied',
        'Very satisfied',
        'Very poor',
        'Excellent',
      ]) {
        expect(find.text(endpoint), findsOneWidget);
      }
      final agreement = tester.widget<SegmentedButton<bool>>(
        find.byKey(const ValueKey('satisfaction-agreement-choice')),
      );
      expect(agreement.selected, isEmpty);
      expectRenderedSemantics(
        tester,
        label: 'Was the work completed as agreed?',
        value: 'Not selected',
        hint: 'Choose Yes or No',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Was the work completed as agreed?' &&
              widget.properties.value == 'Not selected' &&
              widget.properties.hint == 'Choose Yes or No',
        ),
        findsOneWidget,
      );
      final submitFinder = find.byKey(
        const ValueKey('job-satisfaction-submit'),
      );
      await tester.scrollUntilVisible(
        submitFinder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final submit = tester.widget<FilledButton>(submitFinder);
      expect(submit.onPressed, isNull);
      expect(repository.submitted, isFalse);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'rating endpoints remain readable and submit stays reachable on compact enlarged-text layouts',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeJobSatisfactionRepository();
      final scenarios = <({Size size, double scale})>[
        (size: const Size(320, 568), scale: 1.5),
        (size: const Size(360, 640), scale: 2.0),
      ];

      for (final scenario in scenarios) {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(
              'satisfaction-responsive-${scenario.size.width}-${scenario.scale}',
            ),
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: MediaQueryData(
                size: scenario.size,
                devicePixelRatio: 1,
                textScaler: TextScaler.linear(scenario.scale),
              ),
              child: Provider<JobSatisfactionRepository>.value(
                value: repository,
                child: const JobSatisfactionPage(jobId: 'job-responsive'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'این فرم فقط برای همین همکاری است. هیچ چت عمومی یا درخواست آزاد از هوش مصنوعی در اختیار شما نیست.',
          ),
          findsOneWidget,
          reason: 'The loaded satisfaction form should replace the async loading state.',
        );
        expect(find.byType(ListView), findsOneWidget);

        final overallFinder = find.byKey(
          const ValueKey('satisfaction-overall-rating'),
        );
        await revealLazyListChild(tester, overallFinder);

        for (final endpoint in ['کاملاً ناراضی', 'کاملاً راضی']) {
          expect(
            find.text(endpoint),
            findsOneWidget,
            reason: 'Overall rating endpoint should remain visible at enlarged text.',
          );
        }
        expect(tester.takeException(), isNull);

        final communicationFinder = find.byKey(
          const ValueKey('satisfaction-communication-rating'),
        );
        await revealLazyListChild(tester, communicationFinder);
        for (final endpoint in ['بسیار ضعیف', 'عالی']) {
          expect(
            find.text(endpoint),
            findsOneWidget,
            reason: 'Communication rating endpoint should remain visible at enlarged text.',
          );
        }
        expect(tester.takeException(), isNull);

        final submitFinder = find.byKey(
          const ValueKey('job-satisfaction-submit'),
        );
        await revealLazyListChild(tester, submitFinder);
        expect(submitFinder, findsOneWidget);
        expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'complete satisfaction feedback enables submit and forwards exact values',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeJobSatisfactionRepository();
      final semantics = tester.ensureSemantics();

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
          home: Provider<JobSatisfactionRepository>.value(
            value: repository,
            child: const JobSatisfactionPage(jobId: 'job-1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final overallField = find.byKey(
        const ValueKey('satisfaction-overall-rating'),
      );
      await tester.ensureVisible(overallField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: overallField, matching: find.text('۴')),
      );
      await tester.pump();

      final agreement = find.byKey(
        const ValueKey('satisfaction-agreement-choice'),
      );
      await tester.ensureVisible(agreement);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: agreement, matching: find.text('خیر')),
      );
      await tester.pump();
      expectRenderedSemantics(
        tester,
        label: 'کار مطابق توافق انجام شد؟',
        value: 'خیر',
        hint: 'بله یا خیر را انتخاب کنید',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'کار مطابق توافق انجام شد؟' &&
              widget.properties.value == 'خیر' &&
              widget.properties.hint == 'بله یا خیر را انتخاب کنید',
        ),
        findsOneWidget,
      );

      final communicationField = find.byKey(
        const ValueKey('satisfaction-communication-rating'),
      );
      await tester.ensureVisible(communicationField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: communicationField, matching: find.text('۵')),
      );
      await tester.pump();

      final reportFinder = find.byType(TextField);
      await tester.ensureVisible(reportFinder);
      await tester.pumpAndSettle();
      await tester.enterText(reportFinder, 'گزارش آزمایشی');
      tester.testTextInput.hide();
      await tester.pump();

      final submitFinder = find.byKey(
        const ValueKey('job-satisfaction-submit'),
      );
      await tester.scrollUntilVisible(
        submitFinder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);

      await tester.tap(submitFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.submitted, isTrue);
      expect(repository.submittedJobId, 'job-1');
      expect(repository.submittedOverallRating, 4);
      expect(repository.submittedCompletedAsAgreed, isFalse);
      expect(repository.submittedCommunicationRating, 5);
      expect(repository.submittedReport, 'گزارش آزمایشی');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'failed satisfaction submit shows feedback and allows retry',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeJobSatisfactionRepository()
        ..failNextSubmit = true;

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
          home: Provider<JobSatisfactionRepository>.value(
            value: repository,
            child: const JobSatisfactionPage(jobId: 'job-1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final overallField = find.byKey(
        const ValueKey('satisfaction-overall-rating'),
      );
      await tester.ensureVisible(overallField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: overallField, matching: find.text('۴')),
      );
      await tester.pump();

      final agreement = find.byKey(
        const ValueKey('satisfaction-agreement-choice'),
      );
      await tester.ensureVisible(agreement);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: agreement, matching: find.text('بله')),
      );
      await tester.pump();

      final communicationField = find.byKey(
        const ValueKey('satisfaction-communication-rating'),
      );
      await tester.ensureVisible(communicationField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: communicationField, matching: find.text('۵')),
      );
      await tester.pump();

      final reportFinder = find.byType(TextField);
      await tester.ensureVisible(reportFinder);
      await tester.pumpAndSettle();
      await tester.enterText(reportFinder, 'گزارش قابل تکرار');
      tester.testTextInput.hide();
      await tester.pump();

      final submitFinder = find.byKey(
        const ValueKey('job-satisfaction-submit'),
      );
      await tester.scrollUntilVisible(
        submitFinder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);

      await tester.tap(submitFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ثبت گزارش انجام نشد.'), findsOneWidget);
      expect(repository.submitAttempts, 1);
      expect(repository.submitted, isFalse);
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);

      await tester.tap(submitFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.submitAttempts, 2);
      expect(repository.submitted, isTrue);
      expect(repository.submittedJobId, 'job-1');
      expect(repository.submittedOverallRating, 4);
      expect(repository.submittedCompletedAsAgreed, isTrue);
      expect(repository.submittedCommunicationRating, 5);
      expect(repository.submittedReport, 'گزارش قابل تکرار');
      expect(tester.takeException(), isNull);
    },
  );
}
