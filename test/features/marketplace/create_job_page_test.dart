import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/category.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/marketplace/marketplace_repository.dart';
import 'package:hope_mobile/core/router/app_routes.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/features/marketplace/create_job_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Behavior tests for the create-opportunity form: validation gating, kind
/// switching, fee copy, delegation of create+publish, busy state and
/// navigation intent. All repositories are fresh per test.
class _FakeMarket implements MarketplaceRepository {
  final List<String> calls = [];

  bool failCreate = false;

  /// When set, createOpportunity waits on this gate so the busy state can be
  /// observed deterministically.
  Completer<HopeJob>? createGate;

  @override
  Future<HopeJob> getOpportunity(String id) => throw UnimplementedError();

  @override
  Future<List<HopeCategory>> listCategories() async => const [
        HopeCategory(
            id: '1',
            slug: 'design',
            name: 'طراحی',
            nameEn: 'Design',
            description: '',
            parentId: null,
            sortOrder: 1,
            isActive: true),
        HopeCategory(
            id: '2',
            slug: 'dev',
            name: 'توسعه',
            nameEn: 'Development',
            description: '',
            parentId: '1',
            sortOrder: 2,
            isActive: true),
        HopeCategory(
            id: '3',
            slug: 'off',
            name: 'غیرفعال',
            nameEn: 'Inactive',
            description: '',
            parentId: null,
            sortOrder: 3,
            isActive: false),
      ];

  @override
  Future<HopeJob> createOpportunity(Map<String, dynamic> body) async {
    calls.add('create:${body['kind']}:${body['title']}');
    if (failCreate) throw Exception('create boom');
    if (createGate != null) return createGate!.future;
    return HopeJob.fromMap({
      ...body,
      'id': 'job-new',
      'status': 'PUBLISHED',
      'ownerId': 'u1',
      'offerCount': 0,
    });
  }

  @override
  Future<void> publishOpportunity(String id) async {
    calls.add('publish:$id');
  }

  @override
  Future<List<HopeJob>> listOpportunities({
    required String? city,
    required bool personalizedRecommendations,
    double? latitude,
    double? longitude,
    String? search,
    String? kind,
    String? visibility,
    String? categoryId,
  }) async =>
      const [];
}

Future<void> _pump(
  WidgetTester tester,
  _FakeMarket repo, {
  HopeSettingsController? settings,
  double width = 900,
  ThemeData? theme,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = Size(width, 3400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final controller = settings ?? HopeSettingsController();
  await controller.load();
  // Providers must sit ABOVE the MaterialApp so routes pushed onto the
  // app Navigator (CreateJobPage via HopeRoutes) still resolve them.
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: controller),
      Provider<MarketplaceRepository>.value(value: repo),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData.light(),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('fa')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.push(context, HopeRoutes.createJob()),
              child: const Text('open form'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open form'));
  await tester.pumpAndSettle();
  expect(find.byType(CreateJobPage), findsOneWidget);
}

Future<void> _selectCategory(WidgetTester tester, String label) async {
  final dropdown = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  // Exact match first (child categories carry a '  ↳ ' indent prefix).
  var item = find.text(label);
  if (item.evaluate().isEmpty) item = find.textContaining(label);
  await tester.tap(item.last);
  await tester.pumpAndSettle();
}

Future<void> _advance(WidgetTester tester) async {
  final next = find.byKey(const ValueKey('create-opportunity-next-step'));
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<void> _advanceToReview(WidgetTester tester) async {
  for (var step = 0; step < 4; step++) {
    await _advance(tester);
  }
}

Future<void> _fillMissionForm(WidgetTester tester, {String? category}) async {
  await _advance(tester); // Details
  await tester.enterText(
      find.widgetWithText(TextField, 'Title'), 'Design a landing page');
  await tester.enterText(find.widgetWithText(TextField, 'Full description'),
      'A complete landing page design for an online shop');
  if (category != null) {
    await _selectCategory(tester, category);
  }
  await _advance(tester); // Compensation
  await tester.enterText(
      find.widgetWithText(TextField, 'Minimum pay'), '500000');
  await tester.enterText(
      find.widgetWithText(TextField, 'Maximum pay'), '800000');
  await _advance(tester); // Fee and acceptance criteria
  await tester.enterText(
      find.widgetWithText(TextField, 'Acceptance / selection criteria'),
      'Deliver PSD and Figma files');
  await _advance(tester); // Final review
}

void main() {
  testWidgets(
      'selected type tile stays paint-safe in dark RTL runtime styling',
      (tester) async {
    final repo = _FakeMarket();
    await _pump(
      tester,
      repo,
      width: 390,
      theme: ThemeData.dark(),
      locale: const Locale('fa'),
    );
    await _open(tester);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'create job stays render-safe with keyboard inset and landscape orientation',
      (tester) async {
    final repo = _FakeMarket();

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetViewPadding);

    await _pump(tester, repo, width: 360);
    await _open(tester);
    expect(tester.takeException(), isNull);

    tester.view.resetViewInsets();
    tester.view.physicalSize = const Size(800, 360);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CreateJobPage), findsOneWidget);
  });

  testWidgets('mission publish delegates create then publish and pops back',
      (tester) async {
    final repo = _FakeMarket();
    await _pump(tester, repo);
    await _open(tester);

    await _fillMissionForm(tester, category: 'Design');
    await tester.ensureVisible(find.text('Publish opportunity'));
    await tester.tap(find.text('Publish opportunity'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('create:MISSION:Design a landing page'));
    expect(repo.calls, contains('publish:job-new'));
    expect(find.text('Opportunity published.'), findsOneWidget);
    // Navigation intent: the page popped back to the host.
    expect(find.byType(CreateJobPage), findsNothing);
  });

  testWidgets('validation failure blocks submit without category',
      (tester) async {
    final repo = _FakeMarket();
    await _pump(tester, repo);
    await _open(tester);

    await _advanceToReview(tester);
    await tester.ensureVisible(find.text('Publish opportunity'));
    await tester.tap(find.text('Publish opportunity'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Select a professional field.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets(
      'create opportunity type choices stay side by side at usable mobile width',
      (tester) async {
    final repo = _FakeMarket();
    await _pump(tester, repo, width: 390);
    await _open(tester);

    final mission = find.text('Mission');
    final job = find.text('Job');
    expect(mission, findsOneWidget);
    expect(job, findsOneWidget);
    expect(
      (tester.getTopLeft(job).dy - tester.getTopLeft(mission).dy).abs(),
      lessThan(50),
    );
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact create keeps type choices side by side while budget fields stack',
      (tester) async {
    final repo = _FakeMarket();
    await _pump(tester, repo, width: 360);
    await _open(tester);

    expect(
      (tester.getTopLeft(find.text('Job')).dy -
              tester.getTopLeft(find.text('Mission')).dy)
          .abs(),
      lessThan(50),
    );
    expect(
      tester.getTopLeft(find.text('Specialized')).dy,
      greaterThan(tester.getBottomRight(find.text('Public')).dy),
    );

    await _advance(tester); // Details
    await _advance(tester); // Compensation

    final minField = find.widgetWithText(TextField, 'Minimum pay');
    final maxField = find.widgetWithText(TextField, 'Maximum pay');
    expect(minField, findsOneWidget);
    expect(maxField, findsOneWidget);
    expect(
      tester.getTopLeft(maxField).dy,
      greaterThan(tester.getBottomRight(minField).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching types swaps price fields, fee copy and job deadline',
      (tester) async {
    final repo = _FakeMarket();
    await _pump(tester, repo);
    await _open(tester);

    expect(find.text('Minimum pay'), findsNothing);
    expect(find.text('Monthly salary'), findsNothing);
    await tester.tap(find.text('Job'));
    await tester.pumpAndSettle();
    await _advance(tester); // Details

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Flutter developer');
    await tester.enterText(find.widgetWithText(TextField, 'Full description'),
        'Build and ship the mobile application');
    await _selectCategory(tester, 'Development');
    await _advance(tester); // Compensation

    expect(find.text('Monthly salary'), findsOneWidget);
    expect(find.text('Application deadline'), findsOneWidget);
    expect(find.text('Minimum pay'), findsNothing);
    expect(find.text('Duration (hours)'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, 'Monthly salary'), '12000000');
    await _advance(tester); // Fee and acceptance criteria
    expect(find.textContaining('30% of the candidate'), findsOneWidget);
    await _advance(tester); // Final review

    await tester.ensureVisible(find.text('Publish opportunity'));
    await tester.tap(find.text('Publish opportunity'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Set the application deadline.'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('create-opportunity-previous-step')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-opportunity-previous-step')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, 'Application deadline'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('30').last);
    await tester.pumpAndSettle();
    if (find.text('OK').evaluate().isNotEmpty) {
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();
    }
    await _advance(tester); // Fee and criteria
    await _advance(tester); // Final review
    await tester.ensureVisible(find.text('Publish opportunity'));
    await tester.tap(find.text('Publish opportunity'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('create:JOB:Flutter developer'));
    expect(repo.calls, contains('publish:job-new'));
  });

  testWidgets('busy state disables the submit action while in flight',
      (tester) async {
    final repo = _FakeMarket()..createGate = Completer<HopeJob>();
    await _pump(tester, repo);
    await _open(tester);

    await _fillMissionForm(tester, category: 'Design');
    await tester.ensureVisible(find.text('Publish opportunity'));
    await tester.tap(find.text('Publish opportunity'));
    await tester.pump();

    final submitArea = find.byType(FilledButton);
    expect(submitArea, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    repo.createGate!.complete(HopeJob.fromMap({
      'id': 'job-new',
      'title': 'Design a landing page',
      'status': 'PUBLISHED',
    }));
    await tester.pumpAndSettle();
    expect(find.text('Opportunity published.'), findsOneWidget);
    expect(repo.calls, contains('publish:job-new'));
  });

  testWidgets('create failure surfaces server error snackbar', (tester) async {
    final repo = _FakeMarket()..failCreate = true;
    await _pump(tester, repo);
    await _open(tester);

    await _fillMissionForm(tester, category: 'Design');
    await tester.ensureVisible(find.text('Publish opportunity'));
    await tester.tap(find.text('Publish opportunity'));
    await tester.pumpAndSettle();

    expect(find.text('No data was returned by the server. Please try again.'),
        findsOneWidget);
    // Still on the form: the pop only happens on success.
    expect(find.byType(CreateJobPage), findsOneWidget);
  });

  testWidgets(
    'Wave 34 create opportunity is a real five-stage flow with staged fields and final publish',
    (tester) async {
      final repo = _FakeMarket();
      await _pump(tester, repo, width: 360);
      await _open(tester);

      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.byKey(const ValueKey('create-opportunity-next-step')), findsOneWidget);
      expect(find.byKey(const ValueKey('create-opportunity-previous-step')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Title'), findsNothing);

      await _advance(tester);
      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Minimum pay'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('create-opportunity-previous-step')));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Mission'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
