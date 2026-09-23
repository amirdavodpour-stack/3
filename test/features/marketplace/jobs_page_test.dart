import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/category.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/marketplace/marketplace_repository.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/features/jobs/jobs_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements MarketplaceRepository {
  final calls = <String>[];

  /// All jobs this fake server "knows about", spread across a couple of
  /// cities plus one online job -- used so tests can tell apart "server
  /// filtered by city" from "server ignored the filter", the way a real
  /// backend with an exact-match `city` filter would.
  late final List<HopeJob> _allJobs = [
    job('m1', 'طراحی اپ', 'MISSION', 'تهران'),
    job('j1', 'استخدام Flutter', 'JOB', 'تهران'),
    job('online', 'کار آنلاین', 'MISSION', 'آنلاین'),
    job('d1', 'طراحی گرافیک', 'MISSION', 'تهران',
        categoryId: 'design', category: 'طراحی'),
    job('s1', 'همکاری تخصصی', 'MISSION', 'تهران', visibility: 'SPECIALIZED'),
    job('shiraz1', 'طراحی در شیراز', 'MISSION', 'شیراز'),
  ];

  HopeCategory get techCategory => const HopeCategory(
        id: 'tech',
        slug: 'tech',
        name: 'فناوری',
        nameEn: 'Technology',
        description: '',
        parentId: null,
        sortOrder: 0,
        isActive: true,
      );

  HopeCategory get designCategory => const HopeCategory(
        id: 'design',
        slug: 'design',
        name: 'طراحی',
        nameEn: 'Design',
        description: '',
        parentId: null,
        sortOrder: 1,
        isActive: true,
      );

  HopeJob job(
    String id,
    String title,
    String kind,
    String city, {
    String visibility = 'PUBLIC',
    String categoryId = 'tech',
    String category = 'فناوری',
  }) =>
      HopeJob.fromMap({
        'id': id,
        'title': title,
        'description': 'شرح $title',
        'categoryId': categoryId,
        'category': category,
        'kind': kind,
        'visibility': visibility,
        'city': city,
      });

  @override
  Future<HopeJob> getOpportunity(String id) async =>
      _allJobs.firstWhere((j) => j.id == id, orElse: () => _allJobs.first);

  @override
  Future<List<HopeCategory>> listCategories() async {
    calls.add('categories');
    return [techCategory, designCategory];
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
  }) async {
    calls.add('jobs:${city ?? 'ALL'}:$personalizedRecommendations');
    if (personalizedRecommendations || city == null) return _allJobs;
    return _allJobs.where((j) => (j.city ?? '') == city).toList();
  }

  @override
  Future<HopeJob> createOpportunity(Map<String, dynamic> body) =>
      throw UnimplementedError();

  @override
  Future<void> publishOpportunity(String id) async {}
}

Future<void> _pump(WidgetTester tester, _Repo repo,
    {HopeSettingsController? settings}) async {
  HopeSettingsController resolvedSettings;
  if (settings != null) {
    resolvedSettings = settings;
  } else {
    SharedPreferences.setMockInitialValues({});
    resolvedSettings = HopeSettingsController();
    await resolvedSettings.load();
  }
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: resolvedSettings),
        Provider<MarketplaceRepository>.value(value: repo),
      ],
      child: const JobsPage(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapFilter(
  WidgetTester tester,
  String label,
) async {
  final all = find.text(label, skipOffstage: false);
  expect(all, findsWidgets);
  final target = all.first;
  await tester.ensureVisible(target);
  await tester.tap(target);
}

void main() {
  testWidgets('jobs page requests categories and opportunities',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.byType(JobsPage), findsOneWidget);
    expect(find.text('طراحی اپ'), findsOneWidget);
    expect(repo.calls, contains('categories'));
    expect(repo.calls.any((e) => e.startsWith('jobs:تهران:')), isTrue);
  });

  testWidgets('search narrows the rendered opportunity list', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Flutter');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.calls.where((call) => call.startsWith('jobs:')).length,
        greaterThanOrEqualTo(2));
    expect(find.text('استخدام Flutter'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
  });

  testWidgets('online jobs remain visible for a selected city', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('کار آنلاین'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('کار آنلاین'), findsOneWidget);
  });

  testWidgets('kind chip narrows the list to missions only', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'ماموریت‌ها');
    await tester.pumpAndSettle();
    expect(find.text('طراحی اپ'), findsOneWidget);
    expect(find.text('استخدام Flutter'), findsNothing);
  });

  testWidgets('kind chip narrows the list to jobs only', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'شغل‌ها');
    await tester.pumpAndSettle();
    expect(find.text('استخدام Flutter'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
  });

  testWidgets('visibility chip narrows the list to specialized only',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'تخصصی');
    await tester.pumpAndSettle();
    expect(find.text('همکاری تخصصی'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
  });

  testWidgets('visibility chip toggles from specialized back to public',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'تخصصی');
    await tester.pumpAndSettle();
    expect(find.text('طراحی اپ'), findsNothing);
    await _tapFilter(tester, 'عمومی');
    await tester.pumpAndSettle();
    expect(find.text('طراحی اپ'), findsOneWidget);
    expect(find.text('همکاری تخصصی'), findsNothing);
  });

  testWidgets(
      'selecting a category filters the list and shows its localized label '
      '(regression: picker used to leak the raw slug and never match any job)',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await _tapFilter(tester, 'همه حوزه‌ها');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'طراحی'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'طراحی'));
    await tester.pumpAndSettle();

    expect(find.text('طراحی'), findsOneWidget);
    expect(find.text('design'), findsNothing);
    expect(find.text('طراحی گرافیک'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
    expect(find.text('استخدام Flutter'), findsNothing);
    expect(find.text('کار آنلاین'), findsNothing);
  });

  testWidgets('choosing "همه حوزه‌ها" again clears the category filter',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'همه حوزه‌ها');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'طراحی'));
    await tester.pumpAndSettle();

    await _tapFilter(tester, 'طراحی');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'همه حوزه‌ها'));
    await tester.pumpAndSettle();

    expect(find.text('طراحی اپ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('طراحی گرافیک'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('طراحی گرافیک'), findsOneWidget);
  });

  testWidgets(
      'selecting "همه" (all cities) surfaces jobs from every city '
      '(regression: the literal word used to be sent to the server as the '
      'city filter, and since no job\'s city equals that string the '
      'server returned zero jobs)', (tester) async {
    final repo = _Repo();
    SharedPreferences.setMockInitialValues({});
    final settings = HopeSettingsController();
    await settings.load();
    await settings.setPersonalizedRecommendations(false);
    await _pump(tester, repo, settings: settings);
    await tester.pumpAndSettle();

    expect(find.text('طراحی در شیراز'), findsNothing);
    await _tapFilter(tester, 'اطراف تهران');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.widgetWithText(ListTile, 'همه شهرها'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.widgetWithText(ListTile, 'همه شهرها'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'همه شهرها'));
    await tester.pumpAndSettle();

    expect(find.text('طراحی اپ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('طراحی در شیراز'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('طراحی در شیراز'), findsOneWidget);
  });

  testWidgets(
      'picking a specific city still shows online jobs '
      '(regression: forwarding the city filter to the server used to drop '
      'every online job, since the server has no carve-out for them)',
      (tester) async {
    final repo = _Repo();
    SharedPreferences.setMockInitialValues({});
    final settings = HopeSettingsController();
    await settings.load();
    await settings.setPersonalizedRecommendations(false);
    await _pump(tester, repo, settings: settings);
    await tester.pumpAndSettle();

    await _tapFilter(tester, 'اطراف تهران');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'شیراز'));
    await tester.pumpAndSettle();

    expect(find.text('کار آنلاین'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
    await tester.scrollUntilVisible(find.text('طراحی در شیراز'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('طراحی در شیراز'), findsOneWidget);
  });
}
