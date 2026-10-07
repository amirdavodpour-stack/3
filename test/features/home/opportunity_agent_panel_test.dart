import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/opportunity/opportunity_agent_repository.dart';
import 'package:hope_mobile/features/home/opportunity_agent_panel.dart';

void main() {
  testWidgets('shows the highest-priority action and approval boundary', (tester) async {
    final state = HopeOpportunityAgentState(
      profileCompleteness: const HopeOpportunityAgentProfileCompleteness(
        score: 1,
        onboardingCompleted: true,
      ),
      activity: const HopeOpportunityAgentActivity(),
      approvalRequired: const ['PREPARE_APPLICATION'],
      actions: const [
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
}
