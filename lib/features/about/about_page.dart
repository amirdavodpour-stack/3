import 'package:flutter/material.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/components.dart';
import '../../core/theme/app_theme.dart';

class AboutHopePage extends StatelessWidget {
  const AboutHopePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar:
            AppBar(title: Text(HopeCopy.of(context).copy_about_hope_f8ee86b)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            const HeroBanner(),
            const SizedBox(height: 18),
            const Center(child: HopeMark(size: 72, showText: true)),
            const SizedBox(height: 20),
            Text(HopeCopy.of(context).copy_what_is_hope_83013ad,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 9),
            Text(
              HopeCopy.of(context).copy_about_mission_description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            _infoCard(
                context,
                Icons.task_alt_rounded,
                HopeCopy.of(context).copy_mission_fb4c5e1,
                HopeCopy.of(context)
                    .copy_a_defined_task_with_a_clear_price_and_deli_bf299f3),
            const SizedBox(height: 10),
            _infoCard(
                context,
                Icons.business_center_rounded,
                HopeCopy.of(context).copy_job_ce2feba,
                HopeCopy.of(context)
                    .copy_a_part_time_or_full_time_role_with_monthly_ac5f029),
            const SizedBox(height: 22),
            HopeSurface(
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
                          Icons.percent_rounded),
                      const Divider(height: 22),
                      _feeRow(
                          context,
                          HopeCopy.of(context).copy_job_ce2feba,
                          HopeCopy.of(context).copy_about_job_fee_short,
                          Icons.calendar_month_rounded),
                    ])),
            const SizedBox(height: 22),
            SectionTitle(
                title: HopeCopy.of(context).copy_trust_privacy_9f90033,
                subtitle: HopeCopy.of(context)
                    .copy_transparent_selection_without_unnecessary__32e249a),
            const SizedBox(height: 12),
            HopeSurface(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  _bullet(
                      context,
                      Icons.shield_outlined,
                      HopeCopy.of(context)
                          .copy_for_jobs_admins_send_only_the_professional_e6e694e),
                  _bullet(
                      context,
                      Icons.visibility_off_outlined,
                      HopeCopy.of(context)
                          .copy_candidate_identity_stays_hidden_during_sel_6a73883),
                  _bullet(
                      context,
                      Icons.admin_panel_settings_outlined,
                      HopeCopy.of(context)
                          .copy_admins_can_remove_opportunities_that_viola_82df522),
                ])),
            const SizedBox(height: 24),
            Center(
                child: Text(
                    HopeCopy.of(context).copy_hope_work_grow_together_6a1d9f0,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppColors.muted))),
            const SizedBox(height: 6),
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
    );
  }

  Widget _infoCard(
          BuildContext context, IconData icon, String title, String text) =>
      HopeSurface(
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
          BuildContext context, String title, String value, IconData icon) =>
      Row(children: [
        HopeIconTile(icon, size: 42),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        Text(value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium)
      ]);
  Widget _bullet(BuildContext context, IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 21, color: secondaryAccent(context)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge))
      ]));
}

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 180,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                scheme.primary,
                scheme.secondary,
                scheme.surfaceContainerHighest,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -42,
                top: -56,
                child: ExcludeSemantics(
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .16),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -26,
                bottom: -74,
                child: ExcludeSemantics(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Work marketplace' : 'فرصت‌های کاری',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn ? 'Available opportunities' : 'فرصت‌های موجود',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
