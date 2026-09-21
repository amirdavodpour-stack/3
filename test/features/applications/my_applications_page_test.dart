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
  Future<HopeProviderProfile> getProviderProfile() => throw UnimplementedError();

  @override
  Future<List<HopeApplication>> listApplications() async => [application];

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
}
