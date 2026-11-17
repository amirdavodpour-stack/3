import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/profile/profile_repository.dart';
import 'package:hope_mobile/core/ui/hope_async_state.dart';
import 'package:hope_mobile/features/applications/my_applications_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.application);

  final HopeApplication application;
  Completer<HopeApplication>? withdrawResult;
  bool failList = false;
  int withdrawCalls = 0;

  @override
  Future<HopeProviderProfile> getProviderProfile() =>
      throw UnimplementedError();

  @override
  Future<List<HopeApplication>> listApplications() async {
    if (failList) throw StateError('applications unavailable');
    return [application];
  }

  @override
  Future<HopeApplication> withdrawApplication(String applicationId) {
    withdrawCalls += 1;
    return withdrawResult?.future ?? Future<HopeApplication>.value(application);
  }
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

HopeApplication _pendingApplication() => const HopeApplication(
      id: 'pending-app',
      jobId: 'pending-job',
      jobTitle: 'Pending application',
      jobCity: 'Berlin',
      jobKind: 'JOB',
      resumeText: 'A concise resume.',
      skills: 'Flutter',
      status: 'PENDING',
      createdAt: null,
      updatedAt: null,
    );

Future<void> _pumpApplicationsPage(
  WidgetTester tester,
  ProfileRepository repository,
) async {
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
        value: ApplicationRegistry(profile: repository),
        child: const MyApplicationsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'withdrawing an application disables the action until completion',
    (tester) async {
      final application = _pendingApplication();
      final repository = _FakeProfileRepository(application)
        ..withdrawResult = Completer<HopeApplication>();
      await _pumpApplicationsPage(tester, repository);

      final withdraw = find.byTooltip('Withdraw');
      expect(withdraw, findsOneWidget);
      await tester.tap(withdraw);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pump();

      expect(repository.withdrawCalls, 1);
      final button = tester.widget<IconButton>(withdraw);
      expect(button.onPressed, isNull);

      repository.withdrawResult!.complete(application);
      await tester.pumpAndSettle();
      expect(repository.withdrawCalls, 1);
    },
  );

  testWidgets(
    'withdraw refresh failure keeps the existing application visible',
    (tester) async {
      final application = _pendingApplication();
      final repository = _FakeProfileRepository(application)
        ..withdrawResult = Completer<HopeApplication>();
      await _pumpApplicationsPage(tester, repository);

      await tester.tap(find.byTooltip('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pump();

      repository.failList = true;
      repository.withdrawResult!.complete(application);
      await tester.pumpAndSettle();

      expect(find.text('Could not load applications.'), findsOneWidget);
      expect(find.text('Pending application'), findsOneWidget);
    },
  );

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
      expect(find.text('در حال بارگذاری درخواست‌ها'), findsOneWidget);

      profile.initialLoad.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('You have not submitted any applications yet.'), findsOneWidget);
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

}
