import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/profile/profile_repository.dart';
import 'package:hope_mobile/core/ui/hope_async_state.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/features/applications/my_applications_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.application);

  final HopeApplication application;

  @override
  Future<HopeProviderProfile> getProviderProfile() =>
      throw UnimplementedError();

  @override
  Future<List<HopeApplication>> listApplications() async => [application];

  @override
  Future<HopeApplication> withdrawApplication(String applicationId) =>
      throw UnimplementedError();
}

class _SequencedProfileRepository implements ProfileRepository {
  final Completer<List<HopeApplication>> initialLoad =
      Completer<List<HopeApplication>>();

  final HopeApplication staleApplication = const HopeApplication(
    id: 'stale-app',
    jobId: 'stale-job',
    jobTitle: 'Stale application',
    jobCity: 'Berlin',
    jobKind: 'JOB',
    resumeText: '',
    skills: '',
    status: 'PENDING',
    createdAt: null,
    updatedAt: null,
  );

  final HopeApplication freshApplication = const HopeApplication(
    id: 'fresh-app',
    jobId: 'fresh-job',
    jobTitle: 'Fresh application',
    jobCity: 'Berlin',
    jobKind: 'JOB',
    resumeText: '',
    skills: '',
    status: 'ACCEPTED',
    createdAt: null,
    updatedAt: null,
  );

  int calls = 0;

  @override
  Future<HopeProviderProfile> getProviderProfile() =>
      throw UnimplementedError();

  @override
  Future<List<HopeApplication>> listApplications() {
    calls += 1;
    if (calls == 1) return initialLoad.future;
    return Future<List<HopeApplication>>.value([freshApplication]);
  }

  @override
  Future<HopeApplication> withdrawApplication(String applicationId) =>
      throw UnimplementedError();
}

class _FailingProfileRepository implements ProfileRepository {
  bool fail = true;

  final HopeApplication application = const HopeApplication(
    id: 'app-1',
    jobId: 'job-1',
    jobTitle: 'Design task',
    jobCity: 'Berlin',
    jobKind: 'JOB',
    resumeText: '',
    skills: '',
    status: 'PENDING',
    createdAt: null,
    updatedAt: null,
  );

  @override
  Future<HopeProviderProfile> getProviderProfile() =>
      throw UnimplementedError();

  @override
  Future<List<HopeApplication>> listApplications() async {
    if (fail) throw StateError('applications unavailable');
    return [application];
  }

  @override
  Future<HopeApplication> withdrawApplication(String applicationId) =>
      throw UnimplementedError();
}


class _ManyApplicationsRepository implements ProfileRepository {
  static const items = <HopeApplication>[
    HopeApplication(
      id: 'pending-app',
      jobId: 'pending-job',
      jobTitle: 'Active design task',
      jobCity: 'Berlin',
      jobKind: 'JOB',
      resumeText: '',
      skills: '',
      status: 'PENDING',
      createdAt: null,
      updatedAt: null,
    ),
    HopeApplication(
      id: 'withdrawn-app',
      jobId: 'withdrawn-job',
      jobTitle: 'Withdrawn design task',
      jobCity: 'Berlin',
      jobKind: 'JOB',
      resumeText: '',
      skills: '',
      status: 'WITHDRAWN',
      createdAt: null,
      updatedAt: null,
    ),
    HopeApplication(
      id: 'accepted-app',
      jobId: 'accepted-job',
      jobTitle: 'Accepted design task',
      jobCity: 'Berlin',
      jobKind: 'JOB',
      resumeText: '',
      skills: '',
      status: 'ACCEPTED',
      createdAt: null,
      updatedAt: null,
    ),
  ];

  @override
  Future<HopeProviderProfile> getProviderProfile() =>
      throw UnimplementedError();

  @override
  Future<List<HopeApplication>> listApplications() async => items;

  @override
  Future<HopeApplication> withdrawApplication(String applicationId) =>
      throw UnimplementedError();
}

void main() {
  testWidgets(
    'applications loading uses the canonical async state',
    (tester) async {
      final profile = _SequencedProfileRepository();
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
          home: Provider<ApplicationRegistry>.value(
            value: ApplicationRegistry(profile: profile),
            child: const MyApplicationsPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HopeAsyncState), findsOneWidget);
      expect(find.text('Loading applications'), findsOneWidget);

      profile.initialLoad.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('You have not submitted any applications yet.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('applications-status-filter-scroll')),
        findsOneWidget,
      );
    },
  );

  testWidgets('applications do not expose unknown backend statuses',
      (tester) async {
    const application = HopeApplication(
      id: 'app-1',
      jobId: 'job-1',
      jobTitle: 'Design task',
      jobCity: 'Berlin',
      jobKind: 'JOB',
      resumeText: '',
      skills: '',
      status: 'UNKNOWN_APPLICATION_STATE',
      createdAt: null,
      updatedAt: null,
    );
    final profile = _FakeProfileRepository(application);

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
        home: Provider<ApplicationRegistry>.value(
          value: ApplicationRegistry(profile: profile),
          child: const MyApplicationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('UNKNOWN_APPLICATION_STATE'), findsNothing);
  });

  testWidgets(
    'application card keeps timeline and withdrawal action within the compact 1.5x layout',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const title =
          'Senior product design lead for editorial systems and accessibility';
      const application = HopeApplication(
        id: 'dense-app',
        jobId: 'job-1',
        jobTitle: title,
        jobCity: 'Frankfurt am Main',
        jobKind: 'JOB',
        resumeText: '',
        skills: '',
        status: 'PENDING',
        createdAt: null,
        updatedAt: null,
      );
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
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: Provider<ApplicationRegistry>.value(
              value: ApplicationRegistry(
                profile: _FakeProfileRepository(application),
              ),
              child: const MyApplicationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text(title);
      expect(titleFinder, findsOneWidget);
      final cardFinder = find.ancestor(
        of: titleFinder,
        matching: find.byType(PremiumPanel),
      );
      expect(cardFinder, findsOneWidget);
      final timelineStage = find.byKey(
        const ValueKey('application-timeline-dense-app-PENDING'),
      );
      final timelineWrap = find.ancestor(
        of: timelineStage,
        matching: find.byType(Wrap),
      );
      expect(timelineWrap, findsOneWidget);
      expect(
        tester.getSize(timelineWrap).height,
        lessThanOrEqualTo(145),
        reason: 'Full stage labels may wrap up to three lines on enlarged text, while keeping the timeline within a compact two-row budget.',
      );
      expect(
        tester.getSize(cardFinder).height,
        lessThanOrEqualTo(390),
        reason: 'A compact application card should keep its full timeline and actions content-sized at 1.5x text.',
      );
      expect(find.byTooltip('Withdraw'), findsOneWidget);
      expect(find.text('View opportunity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact application cards preserve full opportunity titles at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const title = 'Senior product design lead responsible for editorial systems, accessible financial workflows, multilingual experience strategy, component governance, and cross-functional delivery';
      const application = HopeApplication(
        id: 'full-title-app',
        jobId: 'job-1',
        jobTitle: title,
        jobCity: 'Frankfurt am Main',
        jobKind: 'JOB',
        resumeText: '',
        skills: '',
        status: 'PENDING',
        createdAt: null,
        updatedAt: null,
      );

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
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: Provider<ApplicationRegistry>.value(
              value: ApplicationRegistry(
                profile: _FakeProfileRepository(application),
              ),
              child: const MyApplicationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text(title);
      expect(titleFinder, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'On a scrollable page, a long application title should wrap naturally instead of being truncated at large text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'application location names preserve full wording at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longCity =
          'Northern Metropolitan Administrative and Financial District';
      const application = HopeApplication(
        id: 'long-city-app',
        jobId: 'job-1',
        jobTitle: 'Product designer',
        jobCity: longCity,
        jobKind: 'JOB',
        resumeText: '',
        skills: '',
        status: 'PENDING',
        createdAt: null,
        updatedAt: null,
      );

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
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: Provider<ApplicationRegistry>.value(
              value: ApplicationRegistry(
                profile: _FakeProfileRepository(application),
              ),
              child: const MyApplicationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cityFinder = find.text(longCity);
      expect(cityFinder, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(cityFinder).didExceedMaxLines,
        isFalse,
        reason:
            'A long opportunity location should wrap naturally on the application card instead of being clipped by a one-line tag.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('applications load failure shows explicit error state with retry',
      (tester) async {
    final profile = _FailingProfileRepository();

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
        home: Provider<ApplicationRegistry>.value(
          value: ApplicationRegistry(profile: profile),
          child: const MyApplicationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load applications.'), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('applications-status-filter-scroll')),
      findsNothing,
    );
    expect(
      find.text('You have not submitted any applications yet.'),
      findsNothing,
    );

    profile.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Design task'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(
      find.text('Could not load applications.'),
      findsNothing,
    );
  });

  testWidgets(
      'latest application load wins over an older in-flight load',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = _SequencedProfileRepository();

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
        home: Provider<ApplicationRegistry>.value(
          value: ApplicationRegistry(profile: profile),
          child: const MyApplicationsPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(
      find.byType(ListView),
      const Offset(0, 320),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(profile.calls, 2);
    expect(find.text('Fresh application'), findsOneWidget);

    profile.initialLoad.complete([profile.staleApplication]);
    await tester.pump();

    expect(find.text('Fresh application'), findsOneWidget);
    expect(find.text('Stale application'), findsNothing);
  });

  testWidgets(
      'applications refresh failure keeps existing items and exposes retry error',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = _FailingProfileRepository()..fail = false;

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
        home: Provider<ApplicationRegistry>.value(
          value: ApplicationRegistry(profile: profile),
          child: const MyApplicationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Design task'), findsOneWidget);
    expect(
      find.text('You have not submitted any applications yet.'),
      findsNothing,
    );

    profile.fail = true;

    // Trigger the real pull-to-refresh gesture instead of awaiting
    // RefreshIndicatorState.show(), which can hang when the indicator's
    // scroll-position animation never reaches its completion condition.
    await tester.drag(
      find.byType(ListView),
      const Offset(0, 320),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.scrollUntilVisible(
      find.text('Design task'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Design task'), findsOneWidget);
    expect(find.text('Could not load applications.'), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('You have not submitted any applications yet.'),
      findsNothing,
    );
  });


  testWidgets(
    'applications expose a withdrawn filter in a multi-status list',
    (tester) async {
      final profile = _ManyApplicationsRepository();
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
          home: Provider<ApplicationRegistry>.value(
            value: ApplicationRegistry(profile: profile),
            child: const MyApplicationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final withdrawnFilter = find.textContaining('Withdrawn');
      expect(withdrawnFilter, findsOneWidget);
      await tester.tap(withdrawnFilter);
      await tester.pumpAndSettle();

      expect(find.text('Withdrawn design task'), findsOneWidget);
      expect(find.text('Active design task'), findsNothing);
      expect(find.text('Accepted design task'), findsNothing);
      expect(find.text('No applications match this status.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'application timeline exposes a visible label for every stage',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
          home: Provider<ApplicationRegistry>.value(
            value: ApplicationRegistry(profile: _ManyApplicationsRepository()),
            child: const MyApplicationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const stages = <String, String>{
        'PENDING': 'Pending',
        'SHORTLISTED': 'Shortlist',
        'FORWARDED': 'Forwarded',
        'INTERVIEW': 'Interview',
        'OFFERED': 'Offer',
        'ACCEPTED': 'Accepted',
      };
      for (final entry in stages.entries) {
        final label = find.byKey(
          ValueKey('application-timeline-pending-app-${entry.key}'),
        );
        expect(
          label,
          findsOneWidget,
          reason: 'The ${entry.value} marker needs a visible stage label.',
        );
        expect(find.descendant(of: label, matching: find.text(entry.value)), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'application timeline labels do not truncate at 1.5x text on a compact viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: Provider<ApplicationRegistry>.value(
              value: ApplicationRegistry(
                profile: _ManyApplicationsRepository(),
              ),
              child: const MyApplicationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const stages = <String, String>{
        'PENDING': 'Pending',
        'SHORTLISTED': 'Shortlist',
        'FORWARDED': 'Forwarded',
        'INTERVIEW': 'Interview',
        'OFFERED': 'Offer',
        'ACCEPTED': 'Accepted',
      };
      for (final entry in stages.entries) {
        final label = find.byKey(
          ValueKey('application-timeline-pending-app-${entry.key}'),
        );
        expect(label, findsOneWidget);
        final textFinder = find.descendant(
          of: label,
          matching: find.text(entry.value),
        );
        expect(
          tester.widget<Text>(textFinder).style?.fontSize,
          greaterThanOrEqualTo(12),
          reason: '${entry.value} is a meaningful application status and must retain the 12sp floor at 1.5x.',
        );
        final paragraph = tester.renderObject<RenderParagraph>(textFinder);
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '${entry.value} must remain fully visible when system text is scaled to 1.5x.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'application timeline default-scale labels keep 12sp and wrap without truncation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
          home: Provider<ApplicationRegistry>.value(
            value: ApplicationRegistry(
              profile: _ManyApplicationsRepository(),
            ),
            child: const MyApplicationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const stages = <String, String>{
        'PENDING': 'Pending',
        'SHORTLISTED': 'Shortlist',
        'FORWARDED': 'Forwarded',
        'INTERVIEW': 'Interview',
        'OFFERED': 'Offer',
        'ACCEPTED': 'Accepted',
      };
      for (final entry in stages.entries) {
        final label = find.byKey(
          ValueKey('application-timeline-pending-app-${entry.key}'),
        );
        expect(label, findsOneWidget);
        final textFinder = find.descendant(
          of: label,
          matching: find.text(entry.value),
        );
        expect(
          tester.widget<Text>(textFinder).style?.fontSize,
          greaterThanOrEqualTo(12),
          reason: '${entry.value} must keep the 12sp minimum at default text scale.',
        );
        expect(
          tester.renderObject<RenderParagraph>(textFinder).didExceedMaxLines,
          isFalse,
          reason: '${entry.value} must wrap rather than truncate at default text scale.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

}
