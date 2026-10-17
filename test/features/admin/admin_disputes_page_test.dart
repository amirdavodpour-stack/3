import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/admin/admin_repository.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/features/admin/admin_disputes_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _AdminDisputesRepository extends Fake implements AdminRepository {
  List<Map<String, dynamic>> disputes = const [];
  Map<String, dynamic> detail = const {};

  @override
  Future<List<Map<String, dynamic>>> listDisputes() async => disputes;

  @override
  Future<Map<String, dynamic>> getDispute(String id) async => detail;

  @override
  Future<Map<String, dynamic>> getPanelAccess() async => const {
        'verified': true,
        'permissions': <String>[],
      };
}

void main() {
  testWidgets('admin disputes page uses a compact editorial page tail',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Provider<AdminRepository>.value(
          value: _AdminDisputesRepository(),
          child: const AdminDisputesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame)).padding.bottom,
      24,
    );
    expect(find.text('No dispute cases need attention'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('admin dispute detail separates metadata labels from values on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _AdminDisputesRepository()
      ..disputes = const [
        {
          'id': 'd1',
          'jobTitle': 'Mobile detail role',
          'workerName': 'Worker',
          'ownerName': 'Employer',
          'aiDecision': 'HOLD',
          'status': 'REVIEWING',
          'paymentStatus': 'HELD',
        },
      ]
      ..detail = const {
        'id': 'd1',
        'jobTitle': 'Mobile detail role',
        'status': 'REVIEWING',
        'aiDecision': 'HOLD',
        'aiConfidence': '0.72',
        'legalRulesetVersion': 'v1',
        'jobStatus': 'OPEN',
        'ownerName': 'Employer',
        'workerName': 'Worker',
        'paymentStatus': 'HELD',
        'paymentAmount': '250000',
      };

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Provider<AdminRepository>.value(
          value: repository,
          child: const AdminDisputesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mobile detail role').first);
    await tester.pumpAndSettle();

    expect(find.text('AI status'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('REVIEWING'),
      ),
      findsOneWidget,
    );
    expect(find.text('Legal ruleset'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'admin dispute card preserves a long opportunity title at 1.5x text scale',
    (tester) async {
      const longTitle =
          'Senior workplace dispute resolution and financial settlement workflow across multiple partner teams';
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _AdminDisputesRepository()
        ..disputes = [
          {
            'id': 'long-title-dispute',
            'jobTitle': longTitle,
            'workerName': 'Worker',
            'ownerName': 'Employer',
            'aiDecision': 'HOLD',
            'status': 'REVIEWING',
            'paymentStatus': 'HELD',
          },
        ];

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('fa')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: Provider<AdminRepository>.value(
            value: repository,
            child: const AdminDisputesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text(longTitle);
      expect(titleFinder, findsOneWidget);
      final title = tester.widget<Text>(titleFinder);
      expect(
        title.maxLines,
        isNull,
        reason:
            'Admin dispute titles must retain their full wording at enlarged system text.',
      );
      expect(title.overflow, TextOverflow.visible);
      expect(
        tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
