import 'package:flutter/material.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/components.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/hope_v2_design.dart';

class AboutHopePage extends StatelessWidget {
  const AboutHopePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        body: PremiumPageFrame(
          page: HopePageId.about,
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
            PremiumHero(
              page: HopePageId.about,
              domain: HopeProductDomain.overview,
              eyebrow: isEn ? 'ABOUT HOPE' : 'درباره HOPE',
              title: isEn ? 'A work marketplace built around trust' : 'بازار کار HOPE با محوریت اعتماد',
              message: HopeCopy.of(context).copy_about_mission_description,
              icon: HopeV2Icons.insights,
              height: 192,
            ),
            const SizedBox(height: 10),
            const Center(child: HopeMark(size: 48, showText: true)),
            const SizedBox(height: 8),
            Text(HopeCopy.of(context).copy_what_is_hope_83013ad,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _infoCard(
                context,
                HopeV2Icons.mission,
                HopeCopy.of(context).copy_mission_fb4c5e1,
                HopeCopy.of(context)
                    .copy_a_defined_task_with_a_clear_price_and_deli_bf299f3),
            const SizedBox(height: 10),
            _infoCard(
                context,
                HopeV2Icons.job,
                HopeCopy.of(context).copy_job_ce2feba,
                HopeCopy.of(context)
                    .copy_a_part_time_or_full_time_role_with_monthly_ac5f029),
            const SizedBox(height: 22),
            PremiumPanel(
                highlight: true,
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(HopeCopy.of(context).copy_hope_revenue_model_8506ac2,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      _feeRow(
                          context,
                          HopeCopy.of(context).copy_mission_fb4c5e1,
                          HopeCopy.of(context).copy_about_mission_fee_short,
                          HopeV2Icons.payments),
                      const Divider(height: 22),
                      _feeRow(
                          context,
                          HopeCopy.of(context).copy_job_ce2feba,
                          HopeCopy.of(context).copy_about_job_fee_short,
                          HopeV2Icons.pending),
                    ])),
            const SizedBox(height: 22),
            PremiumSectionHeader(
                title: HopeCopy.of(context).copy_trust_privacy_9f90033,
                subtitle: HopeCopy.of(context)
                    .copy_transparent_selection_without_unnecessary__32e249a),
            const SizedBox(height: 12),
            PremiumPanel(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  _bullet(
                      context,
                      HopeV2Icons.secure,
                      HopeCopy.of(context)
                          .copy_for_jobs_admins_send_only_the_professional_e6e694e),
                  _bullet(
                      context,
                      HopeV2Icons.secure,
                      HopeCopy.of(context)
                          .copy_candidate_identity_stays_hidden_during_sel_6a73883),
                  _bullet(
                      context,
                      HopeV2Icons.secure,
                      HopeCopy.of(context)
                          .copy_admins_can_remove_opportunities_that_viola_82df522),
                ])),
            const SizedBox(height: 24),
            // Reuses the same build-time HOPE_VERSION convention already
            // used by telemetry_service.dart, so About always shows the
            // actual shipped version rather than a hard-coded string.
            Center(
                child: Text(
                    'HOPE v${const String.fromEnvironment('HOPE_VERSION', defaultValue: '0.0.0')}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.muted))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
          BuildContext context, Object icon, String title, String text) =>
      PremiumPanel(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            HopeIconTile(icon, filled: true, size: 46),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(text, style: Theme.of(context).textTheme.bodyMedium)
                ]))
          ]));
  Widget _feeRow(
          BuildContext context, String title, String value, Object icon) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final titleStyle = Theme.of(context).textTheme.titleMedium;
          final valueStyle = Theme.of(context).textTheme.bodyMedium;
          if (constraints.maxWidth < 420) {
            // Long Persian fee labels and values cannot share a single compact
            // row with the icon. Stack the amount below the label instead of
            // clipping or horizontally overflowing real financial copy.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HopeIconTile(icon, size: 42),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: titleStyle)),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 54),
                  child: Text(
                    value,
                    softWrap: true,
                    textAlign: TextAlign.end,
                    style: valueStyle,
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              HopeIconTile(icon, size: 42),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: titleStyle)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  softWrap: true,
                  textAlign: TextAlign.end,
                  style: valueStyle,
                ),
              ),
            ],
          );
        },
      );
  Widget _bullet(BuildContext context, Object icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        HopeIcon(icon, size: 21, color: secondaryAccent(context), strokeWidth: 1.9),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge))
      ]));
}
