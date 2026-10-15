import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/opportunity/opportunity_agent_repository.dart';
import 'package:hope_mobile/features/home/opportunity_agent_panel.dart';

void main() {
  testWidgets('shows the highest-priority action and approval boundary', (tester) async {
    const state = HopeOpportunityAgentState(
      profileCompleteness: HopeOpportunityAgentProfileCompleteness(
        score: 1,
        onboardingCompleted: true,
      ),
      activity: HopeOpportunityAgentActivity(),
      approvalRequired: ['PREPARE_APPLICATION'],
      actions: [
        HopeOpportunityAgentAction(
          type: 'PREPARE_APPLICATION',
          title: 'Flutter developer',
          reasons: ['SKILL_MATCH'],
          score: 91,
          requiresApproval: true,
        ),
      ],
    );

    var tapped = false;
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
        home: Scaffold(
          body: OpportunityAgentPanel(
            state: state,
            onAction: (_) => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Flutter developer'), findsOneWidget);
    expect(find.text('نیاز به تأیید شما'), findsOneWidget);
    expect(find.text('آماده‌سازی درخواست'), findsOneWidget);

    await tester.tap(find.text('آماده‌سازی درخواست'));
    expect(tapped, isTrue);
  });

  testWidgets('renders nothing when the agent has no next action', (tester) async {
    const state = HopeOpportunityAgentState(
      profileCompleteness: HopeOpportunityAgentProfileCompleteness(
        score: 1,
        onboardingCompleted: true,
      ),
      activity: HopeOpportunityAgentActivity(),
      actions: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpportunityAgentPanel(state: state, onAction: (_) {}),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('opportunity-agent-panel')), findsNothing);
  });

  testWidgets('localizes machine-readable recommendation reasons in Persian', (tester) async {
    const state = HopeOpportunityAgentState(
      profileCompleteness: HopeOpportunityAgentProfileCompleteness(),
      activity: HopeOpportunityAgentActivity(),
      actions: [
        HopeOpportunityAgentAction(
          type: 'PREPARE_APPLICATION',
          title: 'Flutter developer',
          reasons: ['SKILL_MATCH'],
          requiresApproval: true,
        ),
      ],
    );

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
        home: Scaffold(
          body: OpportunityAgentPanel(state: state, onAction: (_) {}),
        ),
      ),
    );

    expect(find.text('هم‌خوانی مهارت‌ها'), findsOneWidget);
    expect(find.text('SKILL_MATCH'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('localizes profile completion title and backend field names', (tester) async {
    const state = HopeOpportunityAgentState(
      profileCompleteness: HopeOpportunityAgentProfileCompleteness(),
      activity: HopeOpportunityAgentActivity(),
      actions: [
        HopeOpportunityAgentAction(
          type: 'COMPLETE_PROFILE',
          title: 'Complete your work profile',
          reason: 'Missing: resumeText, skills, preferredCategories',
          missingFields: ['resumeText', 'skills', 'preferredCategories'],
        ),
      ],
    );

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
        home: Scaffold(
          body: OpportunityAgentPanel(state: state, onAction: (_) {}),
        ),
      ),
    );

    expect(find.text('تکمیل پروفایل کاری'), findsOneWidget);
    expect(find.textContaining('رزومه'), findsOneWidget);
    expect(find.textContaining('مهارت‌ها'), findsOneWidget);
    expect(find.textContaining('زمینه‌های کاری موردعلاقه'), findsOneWidget);
    expect(find.textContaining('resumeText'), findsNothing);
    expect(find.textContaining('preferredCategories'), findsNothing);
    expect(find.textContaining('Missing:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
