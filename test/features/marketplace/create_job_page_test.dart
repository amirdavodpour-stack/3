import 'dart:async';
import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show debugDumpRenderTree, RenderParagraph;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/category.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/marketplace/marketplace_repository.dart';
import 'package:hope_mobile/core/router/app_routes.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/features/marketplace/create_job_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Behavior tests for the create-opportunity form: validation gating, kind
/// switching, fee copy, delegation of create+publish, busy state and
/// navigation intent. All repositories are fresh per test.
class _FakeMarket implements MarketplaceRepository {
  final List<String> calls = [];

  bool failCreate = false;

  int failPublishCount = 0;

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
    if (failPublishCount > 0) {
      failPublishCount--;
      throw Exception('publish boom');
    }
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
  double height = 3400,
  double textScale = 1.0,
  ThemeData? theme,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = Size(width, height);
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
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
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
  await tester.scrollUntilVisible(
    dropdown,
    180,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 30,
  );
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
  expect(
    next.hitTestable(),
    findsOneWidget,
    reason: 'The persistent Create Opportunity action must stay available.',
  );
  final button = tester.widget<FilledButton>(next);
  expect(
    button.style?.backgroundColor?.resolve({}),
    HopeV2Colors.markedPrimaryActionDarkGreen,
  );
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<void> _advanceActiveStep(WidgetTester tester) async {
  var activeStepIndex = -1;
  for (var index = 0; index < 5; index++) {
    if (find.byKey(ValueKey('create-opportunity-step-$index'))
        .evaluate()
        .isNotEmpty) {
      activeStepIndex = index;
      break;
    }
  }
  expect(
    activeStepIndex,
    greaterThanOrEqualTo(0),
    reason: 'An active creation step must be mounted.',
  );

  final next = find.byKey(const ValueKey('create-opportunity-next-step'));
  expect(
    next.hitTestable(),
    findsOneWidget,
    reason: 'Next must stay hit-testable in active step $activeStepIndex.',
  );
  await tester.tap(next);
  await tester.pumpAndSettle();

  expect(
    find.byKey(ValueKey('create-opportunity-step-${activeStepIndex + 1}')),
    findsOneWidget,
    reason: 'Next must mount step ${activeStepIndex + 1} of 5.',
  );
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

    await _pump(tester, repo, width: 360, height: 800);
    await _open(tester);

    final progress = find.byKey(
      const ValueKey('create-opportunity-progress'),
    );
    final dock = find.byKey(
      const ValueKey('create-opportunity-action-dock'),
    );
    final next = find.byKey(
      const ValueKey('create-opportunity-next-step'),
    );
    final pageContext = tester.element(find.byType(CreateJobPage));
    final availableBottom = MediaQuery.sizeOf(pageContext).height -
        MediaQuery.viewInsetsOf(pageContext).bottom;
    expect(progress, findsOneWidget);
    expect(next.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(dock).bottom,
      lessThanOrEqualTo(availableBottom),
      reason: 'The fixed action dock must remain above the open keyboard.',
    );
    expect(tester.takeException(), isNull);

    tester.view.resetViewInsets();
    tester.view.physicalSize = const Size(800, 360);
    await tester.pumpAndSettle();

    final landscapeException = tester.takeException();
    if (landscapeException != null) {
      final pageContext = tester.element(find.byType(CreateJobPage));
      debugPrint(
        'WAVE43 landscape MediaQuery size=${MediaQuery.sizeOf(pageContext)} '
        'viewInsets=${MediaQuery.viewInsetsOf(pageContext)} '
        'padding=${MediaQuery.paddingOf(pageContext)}',
      );
      debugDumpRenderTree();
    }
    expect(
      landscapeException,
      isNull,
      reason: 'Create Opportunity landscape layout: '
          '${landscapeException is FlutterError ? landscapeException.diagnostics.map((node) => node.toString()).join(' | ') : landscapeException}',
    );
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

  testWidgets(
    'Wave 50 compact fa-RTL keeps Specialized audience option scroll-reachable above the fixed dock',
    (tester) async {
      final repo = _FakeMarket();
      await _pump(
        tester,
        repo,
        width: 360,
        height: 640,
        textScale: 1.5,
        locale: const Locale('fa'),
      );
      await _open(tester);

      final stepList = find.byKey(
        const ValueKey('create-opportunity-step-0'),
      );
      final stepScroller = find.descendant(
        of: stepList,
        matching: find.byType(Scrollable),
      ).first;
      final viewport = find.descendant(
        of: stepList,
        matching: find.byType(Viewport),
      ).first;
      final dock = find.byKey(
        const ValueKey('create-opportunity-action-dock'),
      );
      final specialized = find.byWidgetPredicate(
        (widget) =>
            widget is PressableScale &&
            (widget.semanticLabel ?? '').contains('تخصصی'),
      );
      final specializedPanel = find.descendant(
        of: specialized,
        matching: find.byType(PremiumPanel),
      ).first;

      expect(stepList, findsOneWidget);
      expect(viewport, findsOneWidget);
      expect(dock, findsOneWidget);

      // The target lives in a lazy ListView child and may not exist in the
      // widget tree until the first step has been scrolled into the cache.
      await tester.scrollUntilVisible(
        specialized,
        120,
        scrollable: stepScroller,
        maxScrolls: 20,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(specialized);
      await tester.pumpAndSettle();
      expect(specialized, findsOneWidget);

      final viewportRect = tester.getRect(viewport);
      final specializedRect = tester.getRect(specialized);
      final dockRect = tester.getRect(dock);
      expect(specializedRect.top, greaterThanOrEqualTo(viewportRect.top));
      expect(specializedRect.bottom, lessThanOrEqualTo(viewportRect.bottom));
      expect(
        viewportRect.bottom,
        lessThanOrEqualTo(dockRect.top),
        reason: 'The scrollable form viewport must finish above the fixed action dock.',
      );
      expect(specialized.hitTestable(), findsOneWidget);
      expect(tester.widget<PremiumPanel>(specializedPanel).highlight, isFalse);

      await tester.tap(specialized);
      await tester.pumpAndSettle();

      expect(tester.widget<PremiumPanel>(specializedPanel).highlight, isTrue);
      expect(tester.getRect(dock).bottom, closeTo(dockRect.bottom, 0.1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching types swaps price fields, fee copy and job deadline',
      (tester) async {
    final repo = _FakeMarket();
    // Use a real mobile-height viewport: the wizard actions are anchored to
    // the visible form frame instead of being part of the scrolling content.
    await _pump(tester, repo, width: 390, height: 800);
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

    final previous = find.byKey(
      const ValueKey('create-opportunity-previous-step'),
    );
    expect(previous.hitTestable(), findsOneWidget);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(previous.hitTestable(), findsOneWidget);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    final deadlineField =
        find.widgetWithText(TextField, 'Application deadline');
    await tester.ensureVisible(deadlineField);
    expect(deadlineField.hitTestable(), findsOneWidget);
    await tester.tap(deadlineField);
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

  testWidgets(
    'publish handler ignores duplicate callbacks before the busy rebuild',
    (tester) async {
      final repo = _FakeMarket()..createGate = Completer<HopeJob>();
      await _pump(tester, repo);
      await _open(tester);
      await _fillMissionForm(tester, category: 'Design');
      await tester.ensureVisible(
        find.byKey(const ValueKey('create-opportunity-next-step')),
      );

      final submitFinder =
          find.byKey(const ValueKey('create-opportunity-next-step'));
      final submit = tester.widget<FilledButton>(submitFinder).onPressed;
      expect(submit, isNotNull);

      // Simulate two activations before Flutter rebuilds the busy/disabled state.
      submit!();
      submit();
      await tester.pump();

      final createCallsBeforeRelease =
          repo.calls.where((call) => call.startsWith('create:')).length;
      final publishCallsBeforeRelease =
          repo.calls.where((call) => call.startsWith('publish:')).length;

      // Always resolve the gate before asserting so a RED result cannot strand async work.
      repo.createGate!.complete(HopeJob.fromMap({
        'id': 'job-new',
        'title': 'Design a landing page',
        'status': 'DRAFT',
      }));
      await tester.pumpAndSettle();

      expect(
        createCallsBeforeRelease,
        1,
        reason: 'One user intent must not create multiple opportunities.',
      );
      expect(
        publishCallsBeforeRelease,
        0,
        reason: 'Publishing should wait for the single create result.',
      );
      expect(
        repo.calls.where((call) => call.startsWith('publish:')).length,
        1,
        reason: 'A duplicate callback must not publish the same opportunity twice.',
      );
    },
  );

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

  testWidgets(
    'retry after publish failure reuses the created opportunity',
    (tester) async {
      final repo = _FakeMarket()..failPublishCount = 1;
      await _pump(tester, repo);
      await _open(tester);
      await _fillMissionForm(tester, category: 'Design');

      final submit =
          find.byKey(const ValueKey('create-opportunity-next-step'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(
        repo.calls.where((call) => call.startsWith('create:')).length,
        1,
      );
      expect(
        repo.calls.where((call) => call.startsWith('publish:')).toList(),
        ['publish:job-new'],
      );

      final retry =
          find.byKey(const ValueKey('create-opportunity-retry-publish'));
      if (retry.evaluate().isNotEmpty) {
        await tester.tap(retry);
      } else {
        // Current behavior retries the whole form; the regression below
        // proves this creates a duplicate instead of republishing job-new.
        final oldSubmit =
            find.byKey(const ValueKey('create-opportunity-next-step'));
        await tester.ensureVisible(oldSubmit);
        await tester.tap(oldSubmit);
      }
      await tester.pumpAndSettle();

      expect(
        repo.calls.where((call) => call.startsWith('create:')).length,
        1,
        reason: 'Retrying a failed publication must reuse the already-created ID.',
      );
      expect(
        repo.calls.where((call) => call.startsWith('publish:')).toList(),
        ['publish:job-new', 'publish:job-new'],
        reason: 'Retry should reattempt publication on the same opportunity.',
      );
      expect(find.byType(CreateJobPage), findsNothing);
    },
  );

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
    'Wave 43 Create Opportunity type choices stack at 1.5x fa-RTL without layout errors',
    (tester) async {
      final repo = _FakeMarket();
      await _pump(
        tester,
        repo,
        width: 360,
        height: 640,
        textScale: 1.5,
        locale: const Locale('fa'),
      );
      await _open(tester);

      final mission = find.text('ماموریت');
      final job = find.text('شغل');
      expect(mission, findsOneWidget);
      expect(job, findsOneWidget);
      expect(
        tester.getTopLeft(job).dy,
        greaterThanOrEqualTo(tester.getBottomRight(mission).dy),
        reason: 'At enlarged text, choice descriptions need a vertical reading order.',
      );
      expect(find.text('مرحله ۱ از ۵'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 43 entered detail fields and selected category survive step navigation',
    (tester) async {
      final repo = _FakeMarket();
      await _pump(tester, repo, width: 360, height: 640);
      await _open(tester);
      await _advance(tester);

      final title = find.widgetWithText(TextField, 'Title');
      final description = find.widgetWithText(TextField, 'Full description');
      await tester.enterText(title, 'Flutter developer ABC-123');
      await tester.enterText(description, 'Build a Persian and English product.');
      await _selectCategory(tester, 'Development');
      await _advance(tester);
      expect(find.text('Step 3 of 5'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('create-opportunity-previous-step')),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(title).controller!.text, 'Flutter developer ABC-123');
      expect(
        tester.widget<TextField>(description).controller!.text,
        'Build a Persian and English product.',
      );
      final category = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).first,
      );
      expect(category.initialValue, 'dev');

      await _advance(tester);
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('Monthly salary'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
      expect(find.text('Details'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Minimum pay'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('create-opportunity-previous-step')));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Mission'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 45 English creation progress keeps step labels on one line at 1.5x',
    (tester) async {
      final repo = _FakeMarket();
      await _pump(
        tester,
        repo,
        width: 360,
        height: 640,
        textScale: 1.5,
        locale: const Locale('en'),
      );
      await _open(tester);

      final progress = find.byKey(
        const ValueKey('create-opportunity-progress'),
      );
      final criteria = find.descendant(
        of: progress,
        matching: find.text('Criteria'),
      );
      expect(criteria, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(criteria);
      expect(
        paragraph.computeLineMetrics(),
        hasLength(1),
        reason: 'A single-word wizard label must not break mid-word at 1.5x text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 44 progress and action dock remain fixed while the active step scrolls',
    (tester) async {
      final repo = _FakeMarket();
      await _pump(tester, repo, width: 360, height: 560);
      await _open(tester);

      final progress = find.byKey(
        const ValueKey('create-opportunity-progress'),
      );
      final dock = find.byKey(
        const ValueKey('create-opportunity-action-dock'),
      );
      expect(progress, findsOneWidget);
      expect(dock, findsOneWidget);

      final progressTop = tester.getRect(progress).top;
      final dockBottom = tester.getRect(dock).bottom;

      await _advanceActiveStep(tester);
      expect(find.text('Step 2 of 5'), findsOneWidget);
      final stepTwoList = find.byKey(
        const ValueKey('create-opportunity-step-1'),
      );
      final stepTwoScroll = find.descendant(
        of: stepTwoList,
        matching: find.byType(Scrollable),
      ).first;
      final titleField = find.descendant(
        of: stepTwoList,
        matching: find.widgetWithText(TextField, 'Title'),
      );
      final titleTopBeforeScroll = tester.getRect(titleField).top;
      await tester.drag(stepTwoScroll, const Offset(0, -240));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(titleField).top,
        lessThan(titleTopBeforeScroll),
        reason: 'The active form content should scroll independently.',
      );
      expect(tester.getRect(progress).top, closeTo(progressTop, 0.1));
      expect(tester.getRect(dock).bottom, closeTo(dockBottom, 0.1));
      expect(
        find.byKey(const ValueKey('create-opportunity-next-step')).hitTestable(),
        findsOneWidget,
      );

      for (var nextStep = 2; nextStep < 5; nextStep++) {
        await _advanceActiveStep(tester);
        expect(tester.getRect(progress).top, closeTo(progressTop, 0.1));
        expect(tester.getRect(dock).bottom, closeTo(dockBottom, 0.1));
      }
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
      'Wave 41 Create Opportunity progress announces active step changes in fa-RTL',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final repo = _FakeMarket();
      await _pump(tester, repo, width: 360, locale: const Locale('fa'));
      await _open(tester);

      final progress = find.byKey(
        const ValueKey('create-opportunity-progress'),
      );
      var node = tester.getSemantics(progress);
      expect(node.label, contains('مرحله ۱ از ۵'));
      expect(node.value, 'نوع');
      expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);

      await _advance(tester);
      node = tester.getSemantics(progress);
      expect(node.label, contains('مرحله ۲ از ۵'));
      expect(node.value, 'جزئیات');
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
    'Wave 36 creation progress uses Persian stage and circle numerals in RTL',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {

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
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: HopeCreationProgress(activeIndex: 2),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('مرحله ۳ از ۵'), findsOneWidget);
        expect(find.text('مبلغ'), findsOneWidget);
        expect(find.text('شرایط'), findsOneWidget);
        expect(find.text('بازبینی'), findsOneWidget);
        expect(find.text('۳'), findsOneWidget);
        expect(find.text('3'), findsNothing);
        expect(
          tester.getSemantics(
            find.byKey(const ValueKey('create-opportunity-progress')),
          ).label,
          contains('مرحله ۳ از ۵'),
        );
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'Create Opportunity previous and next arrows follow Persian RTL direction',
    (tester) async {
      final repo = _FakeMarket();
      await _pump(
        tester,
        repo,
        width: 390,
        height: 844,
        locale: const Locale('fa'),
      );
      await _open(tester);

      final previousIcon = tester.widget<HopeIcon>(
        find.descendant(
          of: find.byKey(const ValueKey('create-opportunity-previous-step')),
          matching: find.byType(HopeIcon),
        ),
      );
      final nextIcon = tester.widget<HopeIcon>(
        find.descendant(
          of: find.byKey(const ValueKey('create-opportunity-next-step')),
          matching: find.byType(HopeIcon),
        ),
      );

      expect(previousIcon.icon, HopeV2Icons.arrowRight);
      expect(nextIcon.icon, HopeV2Icons.arrowLeft);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 5 English LTR Create Opportunity keeps the active title field above a 320dp keyboard at 1.5x',
    (tester) async {
      final repo = _FakeMarket();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetViewPadding);

      await _pump(
        tester,
        repo,
        width: 390,
        height: 844,
        textScale: 1.5,
        locale: const Locale('en'),
      );
      await _open(tester);

      expect(find.text('Step 1 of 5'), findsOneWidget);
      var pageContext = tester.element(find.byType(CreateJobPage));
      expect(MediaQuery.viewInsetsOf(pageContext).bottom, 320);

      await _advanceActiveStep(tester);
      expect(find.text('Step 2 of 5'), findsOneWidget);

      final stepTwoList = find.byKey(
        const ValueKey('create-opportunity-step-1'),
      );
      final stepTwoScrollable = find.descendant(
        of: stepTwoList,
        matching: find.byType(Scrollable),
      ).first;
      final titleField = find.descendant(
        of: stepTwoList,
        matching: find.widgetWithText(TextField, 'Title'),
      );
      await tester.scrollUntilVisible(
        titleField,
        140,
        scrollable: stepTwoScrollable,
        maxScrolls: 30,
      );
      await tester.ensureVisible(titleField);
      expect(
        tester.widget<TextField>(titleField).decoration?.labelText,
        'Title',
      );
      await tester.tap(titleField);
      await tester.pumpAndSettle();

      pageContext = tester.element(find.byType(CreateJobPage));
      expect(MediaQuery.viewInsetsOf(pageContext).bottom, 320);
      final actionDock = find.byKey(
        const ValueKey('create-opportunity-action-dock'),
      );
      final continueAction = find.byKey(
        const ValueKey('create-opportunity-next-step'),
      );
      expect(actionDock, findsOneWidget);
      expect(continueAction.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(actionDock).bottom,
        lessThanOrEqualTo(
          MediaQuery.sizeOf(pageContext).height -
              MediaQuery.viewInsetsOf(pageContext).bottom,
        ),
        reason: 'The action dock must stay above the keyboard at 1.5x.',
      );
      expect(
        find.byKey(const ValueKey('create-opportunity-progress')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final keyboardTop =
          tester.view.physicalSize.height - MediaQuery.viewInsetsOf(pageContext).bottom;
      final titleRect = tester.getRect(titleField);
      expect(
        titleRect.bottom,
        lessThanOrEqualTo(keyboardTop),
        reason: 'The active field must stay above the simulated keyboard.',
      );
      expect(titleField.hitTestable(), findsOneWidget);

      await tester.enterText(titleField, 'Keyboard-safe opportunity');
      expect(find.text('Keyboard-safe opportunity'), findsOneWidget);
      // The progress header stays mounted even when the step content scrolls.
      expect(
        find.byKey(const ValueKey('create-opportunity-progress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('create-opportunity-step-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

}
