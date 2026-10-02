import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/opportunity/opportunity_agent_repository.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/premium_components.dart';

class OpportunityAgentPanel extends StatelessWidget {
  const OpportunityAgentPanel({
    super.key,
    required this.state,
    required this.onAction,
  });

  final HopeOpportunityAgentState state;
  final ValueChanged<HopeOpportunityAgentAction> onAction;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  @override
  Widget build(BuildContext context) {
    if (state.actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final action = state.actions.first;
    final requiresApproval = action.requiresApproval;
    final reason = action.reasons.isNotEmpty
        ? action.reasons.first
        : action.reason;
    final icon = switch (action.type) {
      'COMPLETE_PROFILE' => HopeV2Icons.profile,
      'FOLLOW_UP_APPLICATION' => HopeV2Icons.message,
      _ => HopeV2Icons.featured,
    };

    return Container(
      key: const ValueKey('opportunity-agent-panel'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HopeV2Radii.lg),
        border: Border.all(
          color: (requiresApproval
                  ? HopeV2Colors.warningDark
                  : HopeV2Colors.primary)
              .withValues(alpha: .22),
        ),
      ),
      child: PremiumPanel(
        glass: true,
        highlight: !requiresApproval,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (requiresApproval
                        ? HopeV2Colors.warningDark
                        : HopeV2Colors.primary)
                    .withValues(alpha: .12),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  size: 19,
                  color: requiresApproval
                      ? HopeV2Colors.warningDark
                      : HopeV2Colors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(context, 'قدم بعدی', 'Next step'),
                    style: HopeV2Type.eyebrow(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (reason != null && reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HopeV2Colors.darkMuted,
                          ),
                    ),
                  ],
                  if (requiresApproval) ...[
                    const SizedBox(height: 7),
                    Text(
                      _t(
                        context,
                        'نیاز به تأیید شما',
                        'Requires your approval',
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: HopeV2Colors.warningDark,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: () => onAction(action),
                    child: Text(
                      action.type == 'COMPLETE_PROFILE'
                          ? _t(context, 'تکمیل پروفایل', 'Complete profile')
                          : _t(context, 'بررسی فرصت', 'Review opportunity'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
