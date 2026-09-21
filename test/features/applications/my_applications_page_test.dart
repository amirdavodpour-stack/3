import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/profile/profile_repository.dart';
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

class _FailingProfileRepository implements ProfileRepository {
  bool fail = true;

  final HopeApplication application = HopeApplication(
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

void main() {
  testWidgets('applications do not expose unknown backend statuses',
      (tester) async {
    final application = HopeApplication(
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
      scrollable: find.byType(ListView).first,
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
