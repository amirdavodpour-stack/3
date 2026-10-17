import 'package:flutter/material.dart';

import '../../core/opportunity/opportunity_agent_repository.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/components.dart';
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

  String _title(BuildContext context, HopeOpportunityAgentAction action) {
    final rawTitle = action.title.trim();
    if (action.type == 'COMPLETE_PROFILE') {
      return _t(context, 'تکمیل پروفایل کاری', 'Complete your work profile');
    }
    if (action.type == 'FOLLOW_UP_APPLICATION' &&
        (rawTitle.toLowerCase() == 'follow up on your application' ||
            rawTitle.isEmpty)) {
      return _t(context, 'پیگیری درخواست', 'Follow up on your application');
    }
    if (action.type == 'PREPARE_APPLICATION' &&
        (rawTitle.toLowerCase() == 'prepare application' || rawTitle.isEmpty)) {
      return _t(context, 'آماده‌سازی درخواست', 'Prepare application');
    }
    if (action.type == 'REVIEW_OPPORTUNITY' &&
        (rawTitle.toLowerCase() == 'review opportunity' || rawTitle.isEmpty)) {
      return _t(context, 'بررسی فرصت پیشنهادی', 'Review opportunity');
    }
    // Job and application titles are user/content data, not machine labels.
    return rawTitle;
  }

  String _missingFieldLabel(BuildContext context, String field) {
    switch (field.trim()) {
      case 'resumeText':
        return _t(context, 'رزومه و سابقه کاری', 'Resume and work history');
      case 'skills':
        return _t(context, 'مهارت‌ها', 'Skills');
      case 'interests':
        return _t(context, 'علاقه‌مندی‌ها', 'Interests');
      case 'preferredCategories':
        return _t(context, 'زمینه‌های کاری موردعلاقه', 'Preferred work categories');
      case 'preferredCities':
        return _t(context, 'شهرهای موردنظر', 'Preferred cities');
      case 'desiredKinds':
        return _t(context, 'نوع همکاری موردنظر', 'Preferred opportunity types');
      case 'workMode':
        return _t(context, 'شیوه همکاری', 'Work mode');
      case 'goals':
        return _t(context, 'هدف‌های شغلی', 'Career goals');
      default:
        return '';
    }
  }

  String _reasonLabel(BuildContext context, String reason) {
    switch (reason.trim().toUpperCase()) {
      case 'SKILL_MATCH':
      case 'SKILLS_MATCH':
        return _t(context, 'هم‌خوانی مهارت‌ها', 'Skills match');
      case 'WORK_MODE_MATCH':
        return _t(context, 'تناسب شیوه همکاری', 'Work mode match');
      case 'CATEGORY_MATCH':
        return _t(context, 'تناسب با حوزه کاری موردعلاقه', 'Preferred category match');
      case 'CITY_MATCH':
      case 'LOCATION_MATCH':
        return _t(context, 'تناسب با موقعیت مکانی شما', 'Location matches your preferences');
      case 'RECENT_POST':
        return _t(context, 'این فرصت به‌تازگی ثبت شده است', 'Recently posted opportunity');
      default:
        // Never expose unknown backend enum values as user-facing copy.
        return _t(
          context,
          'این فرصت بر اساس پروفایل شما پیشنهاد شده است',
          'Recommended based on your profile',
        );
    }
  }

  String? _reason(BuildContext context, HopeOpportunityAgentAction action) {
    if (action.type == 'COMPLETE_PROFILE') {
      final fields = action.missingFields
          .map((field) => _missingFieldLabel(context, field))
          .where((label) => label.isNotEmpty)
          .toList(growable: false);
      if (fields.isEmpty) {
        return _t(
          context,
          'اطلاعات پروفایل کاری خود را کامل کنید.',
          'Add the missing details to complete your work profile.',
        );
      }
      return _t(
        context,
        'برای تکمیل پروفایل، این موارد را اضافه کنید: ${fields.join('، ')}',
        'To complete your profile, add: ${fields.join(', ')}',
      );
    }

    if (action.reasons.isNotEmpty) {
      return _reasonLabel(context, action.reasons.first);
    }

    if (action.type == 'FOLLOW_UP_APPLICATION' && action.ageDays != null) {
      final days = action.ageDays!;
      return _t(
        context,
        'این درخواست $days روز در انتظار پاسخ بوده است.',
        'This application has been pending for $days days.',
      );
    }

    if (action.type == 'PREPARE_APPLICATION') {
      return _t(
        context,
        'برای ادامه، درخواست را آماده کنید؛ ارسال نهایی به تأیید شما نیاز دارد.',
        'Prepare the application; final submission still requires your approval.',
      );
    }

    if (action.type == 'REVIEW_OPPORTUNITY') {
      return _t(
        context,
        'این فرصت بر اساس پروفایل شما پیشنهاد شده است.',
        'This opportunity was recommended based on your profile.',
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (state.actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final action = state.actions.first;
    final requiresApproval = action.requiresApproval;
    final title = _title(context, action);
    final reason = _reason(context, action);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final actionAccent = requiresApproval
        ? (dark ? HopeV2Colors.warningDark : HopeV2Colors.warning)
        : (dark ? HopeV2Colors.primaryDark : HopeV2Colors.primary);
    final actionForeground = requiresApproval
        ? (dark ? HopeV2Colors.warningDark : HopeV2Colors.warningOnLight)
        : (dark ? HopeV2Colors.primaryDark : HopeV2Colors.primaryOnLight);
    final icon = switch (action.type) {
      'COMPLETE_PROFILE' => HopeV2Icons.profile,
      'FOLLOW_UP_APPLICATION' => HopeV2Icons.message,
      'PREPARE_APPLICATION' => HopeV2Icons.job,
      'REVIEW_OPPORTUNITY' => HopeV2Icons.featured,
      _ => HopeV2Icons.featured,
    };

    return Container(
      key: const ValueKey('opportunity-agent-panel'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HopeV2Radii.lg),
        border: Border.all(
          color: actionAccent.withValues(alpha: .22),
        ),
      ),
      child: PremiumPanel(
        glass: false,
        highlight: !requiresApproval,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PremiumDomainMarker(
              domain: HopeProductDomain.intelligence,
              compact: true,
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: actionAccent.withValues(alpha: .12),
              ),
              child: Center(
                child: HopeIcon( icon,
                  size: 19,
                  color: actionForeground,
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
                    title,
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
                      switch (action.type) {
                        'COMPLETE_PROFILE' =>
                          _t(context, 'تکمیل پروفایل', 'Complete profile'),
                        'FOLLOW_UP_APPLICATION' =>
                          _t(context, 'پیگیری درخواست', 'Follow up application'),
                        'PREPARE_APPLICATION' =>
                          _t(context, 'آماده‌سازی درخواست', 'Prepare application'),
                        _ => _t(context, 'بررسی فرصت', 'Review opportunity'),
                      },
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
