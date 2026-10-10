import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/jobs/job_satisfaction_repository.dart';
import 'package:hope_mobile/features/jobs/job_satisfaction_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeJobSatisfactionRepository implements JobSatisfactionRepository {
  bool submitted = false;

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
    submitted = true;
    return <String, dynamic>{};
  }

  @override
  Future<List<HopeJobSatisfaction>> history() async => const [];
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
      for (final digit in ['۱', '۲', '۳', '۴', '۵']) {
        expect(
          find.text(digit),
          findsNWidgets(2),
          reason: 'Both Persian rating controls should localize digit $digit.',
        );
      }
      final agreement = tester.widget<SegmentedButton<bool>>(
        find.byKey(const ValueKey('satisfaction-agreement-choice')),
      );
      expect(agreement.selected, isEmpty);
      final submit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('job-satisfaction-submit')),
      );
      expect(submit.onPressed, isNull);
      expect(repository.submitted, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
