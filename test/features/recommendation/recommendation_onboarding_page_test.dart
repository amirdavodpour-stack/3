import 'dart:async';
import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/recommendation/recommendation_profile_repository.dart';
import 'package:hope_mobile/features/recommendation/recommendation_onboarding_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _InterviewCall {
  const _InterviewCall({required this.history, required this.message});

  final List<Map<String, String>> history;
  final String message;
}

class _FakeRecommendationProfileRepository
    implements RecommendationProfileRepository {
  _FakeRecommendationProfileRepository({
    required this.replies,
    Set<int>? failingInterviewCalls,
    Set<int>? failingSaveCalls,
  }) : failingInterviewCalls = failingInterviewCalls ?? <int>{},
       failingSaveCalls = failingSaveCalls ?? <int>{};

  final List<RecommendationInterviewReply> replies;
  final Set<int> failingInterviewCalls;
  final Set<int> failingSaveCalls;
  final List<_InterviewCall> calls = [];
  final List<HopeRecommendationProfile> savedProfiles = [];
  int saveAttempts = 0;

  @override
  Future<HopeRecommendationProfile> get() async =>
      const HopeRecommendationProfile();

  @override
  Future<HopeRecommendationProfile> save(
    HopeRecommendationProfile profile,
  ) async {
    final attempt = saveAttempts++;
    if (failingSaveCalls.contains(attempt)) {
      throw StateError('profile save unavailable');
    }
    savedProfiles.add(profile);
    return profile;
  }

  @override
  Future<RecommendationInterviewReply> interview({
    required List<Map<String, String>> history,
    required String message,
  }) async {
    final index = calls.length;
    calls.add(
      _InterviewCall(
        history: history
            .map((entry) => Map<String, String>.from(entry))
            .toList(growable: false),
        message: message,
      ),
    );
    if (failingInterviewCalls.contains(index)) {
      throw StateError('interview unavailable');
    }
    if (replies.isEmpty) {
      return const RecommendationInterviewReply(
        reply: 'Tell me about your work preferences.',
        complete: false,
        profilePatch: HopeRecommendationProfile(),
      );
    }
    return replies[index < replies.length ? index : replies.length - 1];
  }
}

RecommendationInterviewReply _reply(
  String reply, {
  bool complete = false,
  HopeRecommendationProfile profilePatch = const HopeRecommendationProfile(),
}) =>
    RecommendationInterviewReply(
      reply: reply,
      complete: complete,
      profilePatch: profilePatch,
    );

Widget _pageHost(
  RecommendationProfileRepository repository, {
  String locale = 'fa',
  double textScale = 1,
}) {
  return Provider<RecommendationProfileRepository>.value(
    value: repository,
    child: MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (textScale == 1) return child!;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      theme: ThemeData(brightness: Brightness.dark),
      home: RecommendationOnboardingPage(key: ValueKey(locale)),
    ),
  );
}

Widget _navigatorHost(
  _FakeRecommendationProfileRepository repository,
  Completer<bool?> result,
) {
  return MaterialApp(
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(brightness: Brightness.dark),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('open-recommendation-interview'),
            onPressed: () async {
              final value = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) =>
                      Provider<RecommendationProfileRepository>.value(
                    value: repository,
                    child: const RecommendationOnboardingPage(),
                  ),
                ),
              );
              if (!result.isCompleted) result.complete(value);
            },
            child: const Text('Open interview'),
          ),
        ),
      ),
    ),
  );
}

void _setCompactViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'initial interview prompt respects fa-RTL and en-LTR at 1.5x on compact width',
    (tester) async {
      _setCompactViewport(tester);

      for (final scenario in [
        (
          locale: 'fa',
          direction: TextDirection.rtl,
          prompt: 'چه مهارت‌هایی دارید؟',
          hint: 'پاسخ خود را بنویسید…',
        ),
        (
          locale: 'en',
          direction: TextDirection.ltr,
          prompt: 'Tell me about your work preferences.',
          hint: 'Write your answer…',
        ),
      ]) {
        final repository = _FakeRecommendationProfileRepository(
          replies: [_reply(scenario.prompt)],
        );
        await tester.pumpWidget(
          _pageHost(repository, locale: scenario.locale, textScale: 1.5),
        );
        await tester.pumpAndSettle();

        expect(find.text(scenario.prompt), findsOneWidget);
        expect(find.text(scenario.hint), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(TextField))),
          scenario.direction,
        );
        expect(repository.calls, hasLength(1));
        expect(repository.calls.single.message, isEmpty);
        expect(repository.calls.single.history, isEmpty);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'sending an answer preserves conversation history and merges profile patches',
    (tester) async {
      _setCompactViewport(tester);
      final repository = _FakeRecommendationProfileRepository(
        replies: [
          _reply(
            'چه مهارت‌هایی دارید؟',
            profilePatch: const HopeRecommendationProfile(
              skills: ['Dart'],
              interests: ['طراحی محصول'],
            ),
          ),
          _reply(
            'پاسخ شما ثبت شد.',
            profilePatch: const HopeRecommendationProfile(
              skills: ['Flutter'],
              preferredCities: ['تهران'],
            ),
          ),
        ],
      );
      await tester.pumpWidget(_pageHost(repository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  توسعه‌دهنده Flutter  ');
      await tester.tap(find.byTooltip('ارسال'));
      await tester.pumpAndSettle();

      expect(find.text('توسعه‌دهنده Flutter'), findsOneWidget);
      expect(find.text('پاسخ شما ثبت شد.'), findsOneWidget);
      expect(repository.calls, hasLength(2));
      expect(repository.calls[1].message, 'توسعه‌دهنده Flutter');
      expect(
        repository.calls[1].history,
        [
          {'role': 'assistant', 'content': 'چه مهارت‌هایی دارید؟'},
        ],
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial interview failure leaves a usable composer for recovery',
    (tester) async {
      _setCompactViewport(tester);
      final repository = _FakeRecommendationProfileRepository(
        replies: [_reply('مصاحبه دوباره در دسترس است.')],
        failingInterviewCalls: {0},
      );
      await tester.pumpWidget(_pageHost(repository));
      await tester.pumpAndSettle();

      expect(
        find.text('مصاحبه هوشمند موقتاً در دسترس نیست.'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

      await tester.enterText(find.byType(TextField), 'مهارت‌های من Flutter است');
      await tester.tap(find.byTooltip('ارسال'));
      await tester.pumpAndSettle();

      expect(find.text('مصاحبه دوباره در دسترس است.'), findsOneWidget);
      expect(repository.calls, hasLength(2));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed answer can be followed by another answer without losing transcript history',
    (tester) async {
      _setCompactViewport(tester);
      final repository = _FakeRecommendationProfileRepository(
        replies: [
          _reply('چه مهارت‌هایی دارید؟'),
          _reply('پاسخ بعد از بازیابی پذیرفته شد.'),
        ],
        failingInterviewCalls: {1},
      );
      await tester.pumpWidget(_pageHost(repository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'پاسخ ناموفق');
      await tester.tap(find.byTooltip('ارسال'));
      await tester.pumpAndSettle();

      expect(find.text('پاسخ ناموفق'), findsOneWidget);
      expect(find.text('پاسخ هوش مصنوعی دریافت نشد.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

      await tester.enterText(find.byType(TextField), 'پاسخ بعد از خطا');
      await tester.tap(find.byTooltip('ارسال'));
      await tester.pumpAndSettle();

      expect(find.text('پاسخ بعد از بازیابی پذیرفته شد.'), findsOneWidget);
      expect(repository.calls, hasLength(3));
      expect(
        repository.calls[2].history,
        [
          {'role': 'assistant', 'content': 'چه مهارت‌هایی دارید؟'},
          {'role': 'user', 'content': 'پاسخ ناموفق'},
        ],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completion saves merged preferences and dismisses the route with true',
    (tester) async {
      _setCompactViewport(tester);
      final repository = _FakeRecommendationProfileRepository(
        replies: [
          _reply(
            'از چه حوزه‌ای خوشتان می‌آید؟',
            profilePatch: const HopeRecommendationProfile(
              skills: ['Figma'],
              goals: 'طراحی محصولات مفید',
            ),
          ),
          _reply(
            'مصاحبه کامل شد.',
            complete: true,
            profilePatch: const HopeRecommendationProfile(
              skills: ['Flutter'],
              interests: ['AI'],
              experienceLevel: 'SENIOR',
            ),
          ),
        ],
      );
      final result = Completer<bool?>();
      await tester.pumpWidget(_navigatorHost(repository, result));
      await tester.tap(find.byKey(const ValueKey('open-recommendation-interview')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'می‌خواهم محصول بسازم');
      await tester.tap(find.byTooltip('ارسال'));
      await tester.pumpAndSettle();

      expect(await result.future, isTrue);
      expect(repository.savedProfiles, hasLength(1));
      expect(
        repository.savedProfiles.single.skills,
        ['Figma', 'Flutter'],
      );
      expect(repository.savedProfiles.single.goals, 'طراحی محصولات مفید');
      expect(repository.savedProfiles.single.interests, ['AI']);
      expect(repository.savedProfiles.single.experienceLevel, 'SENIOR');
      expect(repository.savedProfiles.single.onboardingCompleted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'skip dismisses onboarding with false without saving a partial profile',
    (tester) async {
      _setCompactViewport(tester);
      final repository = _FakeRecommendationProfileRepository(
        replies: [
          _reply(
            'کمی درباره ترجیحات کاری بگویید.',
            profilePatch: const HopeRecommendationProfile(
              skills: ['Dart'],
            ),
          ),
        ],
      );
      final result = Completer<bool?>();
      await tester.pumpWidget(_navigatorHost(repository, result));
      await tester.tap(find.byKey(const ValueKey('open-recommendation-interview')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('بعداً'));
      await tester.pumpAndSettle();

      expect(await result.future, isFalse);
      expect(repository.savedProfiles, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an initially complete interview saves the profile and dismisses with true',
    (tester) async {
      _setCompactViewport(tester);
      final repository = _FakeRecommendationProfileRepository(
        replies: [
          _reply(
            'ترجیحات شما کامل است.',
            complete: true,
            profilePatch: const HopeRecommendationProfile(
              skills: ['Flutter'],
              preferredCities: ['تهران'],
            ),
          ),
        ],
      );
      final result = Completer<bool?>();
      await tester.pumpWidget(_navigatorHost(repository, result));
      await tester.tap(find.byKey(const ValueKey('open-recommendation-interview')));
      await tester.pumpAndSettle();

      expect(await result.future, isTrue);
      expect(repository.savedProfiles, hasLength(1));
      expect(repository.savedProfiles.single.skills, ['Flutter']);
      expect(repository.savedProfiles.single.preferredCities, ['تهران']);
      expect(repository.savedProfiles.single.onboardingCompleted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a failed completion save can be retried without losing the profile',
    (tester) async {
      _setCompactViewport(tester);
      final repository = _FakeRecommendationProfileRepository(
        replies: [
          _reply(
            'ترجیحات شما کامل است.',
            complete: true,
            profilePatch: const HopeRecommendationProfile(
              skills: ['Flutter'],
              preferredCities: ['تهران'],
            ),
          ),
        ],
        failingSaveCalls: {0},
      );
      final result = Completer<bool?>();
      await tester.pumpWidget(_navigatorHost(repository, result));
      await tester.tap(find.byKey(const ValueKey('open-recommendation-interview')));
      await tester.pumpAndSettle();

      expect(repository.saveAttempts, 1);
      expect(repository.savedProfiles, isEmpty);
      expect(
        find.byTooltip('تلاش دوباره برای ذخیره'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.tap(find.byTooltip('تلاش دوباره برای ذخیره'));
      await tester.pumpAndSettle();

      expect(await result.future, isTrue);
      expect(repository.saveAttempts, 2);
      expect(repository.savedProfiles, hasLength(1));
      expect(repository.savedProfiles.single.skills, ['Flutter']);
      expect(repository.savedProfiles.single.preferredCities, ['تهران']);
      expect(repository.savedProfiles.single.onboardingCompleted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new assistant replies are exposed as an announced live region',
    (tester) async {
      _setCompactViewport(tester);
      final semantics = tester.ensureSemantics();
      try {
        final repository = _FakeRecommendationProfileRepository(
          replies: [
            _reply('چه مهارت‌هایی دارید؟'),
            _reply('پاسخ تازه برای دسترس‌پذیری'),
          ],
        );
        await tester.pumpWidget(_pageHost(repository));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'تجربه کاربری');
        await tester.tap(find.byTooltip('ارسال'));
        await tester.pumpAndSettle();

        final liveReply = find.bySemanticsLabel(
          'پاسخ تازه برای دسترس‌پذیری',
        );
        expect(liveReply, findsOneWidget);
        expect(
          tester.getSemantics(liveReply).hasFlag(SemanticsFlag.isLiveRegion),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

}
