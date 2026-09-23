import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui/hope_async_state.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/marketplace/application.dart';
import '../../core/profile/profile_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/router/app_routes.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/components.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/hope_l10n.dart';
import 'profile_controller.dart';

import '../../core/ui/premium_components.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        ProfileController(repository: context.read<ProfileRepository>());
  }

  Future<HopeProviderProfile>? profile;
  Future<List<HopeApplication>>? applications;
  String? _loadedUserId;
  String? _applicationBusyId;
  String? _applicationsReloadError;
  int _applicationsReloadRequestId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.read<AuthController>().user?['id']?.toString();
    if (id == _loadedUserId) return;
    _loadedUserId = id;
    _applicationsReloadError = null;
    if (id == null) {
      profile = null;
      applications = null;
      return;
    }
    // Keep backend errors observable so the UI can communicate an unknown
    // verification/trust state instead of silently presenting empty data.
    profile = _controller.loadProfile();
    applications = _controller.loadApplications();
  }

  Future<void> _reloadApplications() async {
    if (!mounted) return;
    final requestId = ++_applicationsReloadRequestId;
    if (_applicationBusyId == null) {
      setState(() => _applicationsReloadError = null);
    }
    try {
      final items = await _controller.loadApplications();
      if (!mounted || requestId != _applicationsReloadRequestId) return;
      setState(() {
        applications = Future<List<HopeApplication>>.value(items);
        _applicationsReloadError = null;
      });
    } catch (error) {
      if (!mounted || requestId != _applicationsReloadRequestId) return;
      setState(() {
        _applicationsReloadError = apiErrorMessage(
          error,
          fallback: _t(
            context,
            'درخواست‌ها قابل دریافت نیستند.',
            'Could not load applications.',
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final settings = context.watch<HopeSettingsController>();
    final theme = context.watch<ThemeController>();

    if (auth.isGuest) {
      return _guest(context, settings, theme);
    }

    final user = auth.user ?? <String, dynamic>{};
    final name = '${user['displayName'] ?? 'HOPE'}';
    final initial = name.isEmpty ? 'H' : name.characters.first.toUpperCase();

    return PremiumPageFrame(
      maxWidth: 920,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 122),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          PremiumHeader(
            eyebrow: HopeCopy.of(context).copy_profile_8b081d3,
            title: name,
            subtitle: user['email']?.toString().trim().isEmpty == true
                ? null
                : user['email']?.toString(),
            trailing: CircleAvatar(
              radius: 25,
              backgroundColor:
                  HopeV2Colors.primary.withValues(alpha: .14),
              child: Text(
                initial,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: HopeV2Spacing.md),
          PremiumPanel(
            padding: const EdgeInsets.symmetric(
              horizontal: HopeV2Spacing.lg,
              vertical: HopeV2Spacing.md,
            ),
            highlight: true,
            child: Row(
              children: [
                HopeIconTile(HopeV2Icons.secure, filled: true),
                const SizedBox(width: HopeV2Spacing.md),
                Expanded(
                  child: Text(
                    HopeCopy.of(context).copy_active_account_bef80da,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PremiumTag(
                  icon: HopeV2Icons.completed,
                  label: _t(context, 'حساب فعال', 'Active account'),
                  color: HopeV2Colors.secondaryStrong,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PremiumSectionHeader(
            title: HopeCopy.of(context).copy_personal_settings_4ecc5fa,
            subtitle: HopeCopy.of(context)
                .copy_controls_that_make_hope_fit_you_better_ace4c0c,
          ),
          const SizedBox(height: 10),
          _settingsCard(context, settings, theme),
          const SizedBox(height: 19),
          FutureBuilder<HopeProviderProfile>(
            future: profile,
            builder: (context, snapshot) {
              if (snapshot.hasError && _applicationsReloadError == null) {
                return HopeAsyncState(
                  kind: HopeStateKind.error,
                  title: _t(context, 'اطلاعات حرفه‌ای در دسترس نیست', 'Professional profile unavailable'),
                  message: _t(context, 'وضعیت تأیید و شاخص‌های اعتماد فعلاً قابل دریافت نیست.', 'Verification and trust signals are temporarily unavailable.'),
                  action: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      profile = _controller.loadProfile();
                    }),
                    icon: HopeIcon(HopeV2Icons.refresh, size: 19),
                    label: Text(_t(context, 'تلاش دوباره', 'Retry')),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const PremiumPanel(
                  child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                );
              }
              final data = snapshot.data;

              return PremiumPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const HopeIconTile(
                        HopeV2Icons.job,
                      ),
                      title: Text(
                        HopeCopy.of(context).copy_work_profile_885ecac,
                      ),
                      subtitle: Text(
                        '${data?.providerType.isNotEmpty == true ? _providerTypeLabel(context, data!.providerType) : HopeCopy.of(context).copy_professional_user_54818b8} • ${data?.capacity.isNotEmpty == true ? _capacityLabel(context, data!.capacity) : HopeCopy.of(context).copy_open_to_work_aa59263}',
                      ),
                    ),
                    const Divider(height: 1),
                    if (data != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 14),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _trustMetric(context, HopeV2Icons.verified, data.isVerified ? _t(context, 'تأییدشده', 'Verified') : _t(context, 'تأیید نشده', 'Not verified'), data.isVerified ? Theme.of(context).colorScheme.primary : AppColors.muted),
                            if (data.providerType.isNotEmpty)
                              _trustMetric(
                                context,
                                HopeV2Icons.job,
                                _providerTypeLabel(context, data.providerType),
                                Theme.of(context).colorScheme.secondary,
                              ),
                            if (data.capacity.isNotEmpty)
                              _trustMetric(
                                context,
                                HopeV2Icons.pending,
                                _capacityLabel(context, data.capacity),
                                AppColors.warning,
                              ),
                            if (data.completedJobs > 0) _trustMetric(context, HopeV2Icons.completed, '${data.completedJobs} ${_t(context, 'کار تکمیل‌شده', 'completed')}', AppColors.success),
                            if (data.activeJobs > 0) _trustMetric(context, HopeV2Icons.activity, '${data.activeJobs} ${_t(context, 'فعال', 'active')}', Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const HopeIconTile(
                        Icons.admin_panel_settings_outlined,
                      ),
                      title: Text(
                        HopeCopy.of(context).copy_verification_c45fea9,
                      ),
                      subtitle: Text(
                        data?.verificationStatus.isNotEmpty == true
                            ? _verificationStatusLabel(
                                context, data!.verificationStatus)
                            : HopeCopy.of(context).copy_not_completed_f8a6746,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          if (_applicationsReloadError != null) ...[
            HopeAsyncState(
              kind: HopeStateKind.error,
              title: _t(
                context,
                'درخواست‌ها در دسترس نیستند',
                'Applications unavailable',
              ),
              message: _applicationsReloadError!,
              action: OutlinedButton.icon(
                onPressed: _applicationBusyId != null ? null : _reloadApplications,
                icon: HopeIcon(HopeV2Icons.refresh, size: 19),
                label: Text(_t(context, 'تلاش دوباره', 'Retry')),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FutureBuilder<List<HopeApplication>>(
            future: applications,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return HopeAsyncState(
                  kind: HopeStateKind.error,
                  title: _t(context, 'درخواست‌ها در دسترس نیستند', 'Applications unavailable'),
                  message: _t(context, 'امکان دریافت وضعیت درخواست‌ها وجود ندارد.', 'Application status could not be loaded.'),
                  action: OutlinedButton.icon(
                    onPressed: _reloadApplications,
                    icon: HopeIcon(HopeV2Icons.refresh, size: 19),
                    label: Text(_t(context, 'تلاش دوباره', 'Retry')),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const PremiumPanel(
                  child: SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
                );
              }
              final list = snapshot.data ?? const <HopeApplication>[];

              if (list.isEmpty) {
                return const SizedBox.shrink();
              }

              return PremiumPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      HopeCopy.of(context).copy_my_job_applications_90701f0,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ...list.take(6).map<Widget>((a) {
                      final status = a.status;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: HopeIconTile(
                          status == 'ACCEPTED'
                              ? Icons.check_circle_rounded
                              : HopeV2Icons.job,
                          filled: status == 'ACCEPTED',
                        ),
                        title: Text(
                          a.jobTitle.isEmpty
                              ? HopeCopy.of(context).copy_job_ce2feba
                              : a.jobTitle,
                        ),
                        subtitle: Text(a.statusLabel),
                        trailing: a.canWithdraw
                            ? IconButton(
                                onPressed: _applicationBusyId == a.id
                                    ? null
                                    : () async {
                                        setState(() => _applicationBusyId = a.id);
                                        try {
                                          await _controller.withdrawApplication(a.id);
                                          if (!mounted) return;
                                          await _reloadApplications();
                                        } catch (error) {
                                          if (!mounted || !context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(apiErrorMessage(
                                                error,
                                                fallback: HopeCopy.of(context)
                                                    .copy_operation_failed_eb38c4c,
                                              )),
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() => _applicationBusyId = null);
                                          }
                                        }
                                      },
                                tooltip: HopeCopy.of(context).copy_cancel_9955c4b,
                                icon: _applicationBusyId == a.id
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : HopeIcon(HopeV2Icons.transferOut, size: 19),
                              )
                            : null,
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          PremiumSectionHeader(
            title: _t(context, 'مرکز کنترل حساب', 'Account control center'),
            subtitle: _t(
              context,
              'حریم خصوصی، دستگاه‌ها و درخواست‌های کاری را یکجا مدیریت کنید.',
              'Manage privacy, devices, and your work applications in one place.',
            ),
          ),
          const SizedBox(height: 10),
          PremiumPanel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const HopeIconTile(HopeV2Icons.mission, filled: true),
                  title: Text(_t(context, 'درخواست‌های من', 'My applications')),
                  subtitle: Text(_t(context, 'پیگیری مرحله‌به‌مرحله همه درخواست‌های شغلی', 'Track every job application through its workflow')),
                  trailing: const HugeIcon(icon: HopeV2Icons.arrowRight, size: 19),
                  onTap: () => Navigator.push(context, HopeRoutes.myApplications()),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const HopeIconTile(HopeV2Icons.secure, filled: true),
                  title: Text(_t(context, 'دستگاه‌های اعلان', 'Notification devices')),
                  subtitle: Text(_t(context, 'مدیریت دستگاه‌های فعال برای Push', 'Manage devices enabled for Push notifications')),
                  trailing: const HugeIcon(icon: HopeV2Icons.arrowRight, size: 19),
                  onTap: () => Navigator.push(context, HopeRoutes.notificationDevices()),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const HopeIconTile(HopeV2Icons.secure, filled: true),
                  title: Text(_t(context, 'حریم خصوصی و داده‌ها', 'Privacy & data')),
                  subtitle: Text(_t(context, 'دریافت خروجی اطلاعات یا حذف حساب', 'Export your data or delete your account')),
                  trailing: const HugeIcon(icon: HopeV2Icons.arrowRight, size: 19),
                  onTap: () => Navigator.push(context, HopeRoutes.privacyCenter()),
                ),
                ListTile(
                  leading: const HopeIconTile(HopeV2Icons.savedSearches, filled: true),
                  title: Text(_t(context, 'جست‌وجوهای ذخیره‌شده', 'Saved searches')),
                  subtitle: Text(_t(context, 'ویرایش و مدیریت فیلترهای ذخیره‌شده', 'Edit and manage saved-search filters')),
                  trailing: const HugeIcon(icon: HopeV2Icons.arrowRight, size: 19),
                  onTap: () => Navigator.push(context, HopeRoutes.savedSearches()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (auth.user?['role'] == 'ADMIN')
            FilledButton.tonalIcon(
              onPressed: () => Navigator.push(context, HopeRoutes.admin()),
              icon: HopeIcon(HopeV2Icons.secure, size: 19),
              label: Text(
                HopeCopy.of(context).copy_open_admin_panel_39f3cb8,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, HopeRoutes.about()),
            icon: HopeIcon(HopeV2Icons.insights, size: 19),
            label: Text(HopeCopy.of(context).copy_about_hope_f8ee86b),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const HopeIconTile(
              HopeV2Icons.transferOut,
              color: AppColors.danger,
            ),
            title: Text(
              HopeCopy.of(context).copy_log_out_04a94c7,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.dangerDark
                    : AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
            onTap: auth.logout,
          ),
        ],
      ),
    );
  }

  Widget _trustMetric(BuildContext context, Object icon, String label, Color color) {
    return Container(
      constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(HopeV2Radii.md),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HopeIcon(icon, size: 18, color: color, strokeWidth: 1.9),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _providerTypeLabel(BuildContext context, String value) {
    switch (value.trim().toUpperCase()) {
      case 'INDIVIDUAL':
      case 'FREELANCER':
        return _t(context, 'مجری مستقل', 'Independent provider');
      case 'BUSINESS':
        return _t(context, 'کسب‌وکار', 'Business');
      default:
        return HopeCopy.of(context).copy_professional_user_54818b8;
    }
  }

  String _capacityLabel(BuildContext context, String value) {
    switch (value.trim().toUpperCase()) {
      case 'OPEN':
        return HopeCopy.of(context).copy_open_to_work_aa59263;
      case 'FULL_TIME':
        return HopeCopy.of(context).copy_full_time_1e4bd4e;
      case 'PART_TIME':
        return HopeCopy.of(context).copy_part_time_086787b;
      case 'PART_FULL_TIME':
      case 'FULL_TIME_PART_TIME':
        return HopeCopy.of(context).copy_part_full_time_4d952a9;
      default:
        return value;
    }
  }

  String _verificationStatusLabel(BuildContext context, String value) {
    switch (value.trim().toUpperCase()) {
      case 'VERIFIED':
        return _t(context, 'تأییدشده', 'Verified');
      case 'UNVERIFIED':
        return _t(context, 'تأیید نشده', 'Not verified');
      case 'PENDING':
        return _t(context, 'در انتظار بررسی', 'Pending review');
      default:
        return _t(context, 'نیازمند بررسی', 'Needs review');
    }
  }

  Widget _guest(
    BuildContext context,
    HopeSettingsController settings,
    ThemeController theme,
  ) {
    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 122),
        children: [
          const HopeMark(),
          const SizedBox(height: 24),
          Text(
            HopeCopy.of(context).copy_profile_8b081d3,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 6),
          Text(
            HopeCopy.of(context)
                .copy_create_an_account_to_apply_post_and_person_6fd6b91,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          PremiumHero(
            eyebrow: HopeCopy.of(context).copy_hope_account_4ba3966,
            title: HopeCopy.of(context)
                .copy_a_home_for_your_professional_path_52dbb09,
            message: HopeCopy.of(context)
                .copy_keep_your_profile_opportunities_transactio_39f443d,
            icon: HopeV2Icons.profile,
            action: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.push(context, HopeRoutes.register()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      HopeCopy.of(context).copy_create_account_bfa3517,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.push(context, HopeRoutes.login()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    child: Text(
                      HopeCopy.of(context).copy_log_in_b4c960b,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _settingsCard(context, settings, theme),
        ],
      ),
    );
  }

  Widget _settingsCard(
    BuildContext context,
    HopeSettingsController settings,
    ThemeController theme,
  ) {
    return PremiumPanel(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 8),
            child: Row(
              children: [
                const HopeIconTile(
                  HopeV2Icons.insights,
                  filled: true,
                  size: 42,
                ),
                const SizedBox(width: 10),
                Text(
                  HopeCopy.of(context).copy_settings_a8a6c67,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final selector = SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'fa',
                    label: Text(
                      HopeCopy.of(context).copy_persian_62775b3,
                    ),
                  ),
                  ButtonSegment(
                    value: 'en',
                    label: Text(
                      HopeCopy.of(context).copy_english_8396fe3,
                    ),
                  ),
                ],
                selected: {settings.language},
                onSelectionChanged: (value) => settings.setLanguage(value.first),
              );

              final details = ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                leading: const HopeIconTile(HopeV2Icons.translate),
                title: Text(
                  HopeCopy.of(context).copy_app_language_789c9c4,
                ),
                subtitle: Text(
                  settings.language == 'fa'
                      ? HopeCopy.of(context).copy_language_persian_3ffcd3e
                      : HopeCopy.of(context).copy_language_english_d9f5a4a,
                ),
              );

              if (constraints.maxWidth < 500) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
                          child: selector,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                leading: const HopeIconTile(HopeV2Icons.translate),
                title: Text(
                  HopeCopy.of(context).copy_app_language_789c9c4,
                ),
                subtitle: Text(
                  settings.language == 'fa'
                      ? HopeCopy.of(context).copy_language_persian_3ffcd3e
                      : HopeCopy.of(context).copy_language_english_d9f5a4a,
                ),
                trailing: selector,
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const HopeIconTile(HopeV2Icons.secure),
            title: Text(
              HopeCopy.of(context).copy_appearance_c90f540,
            ),
            subtitle: Text(_themeLabel(context, theme.mode)),
            onTap: () => _pickTheme(context, settings, theme),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const HopeIconTile(Icons.location_on_outlined),
            title: Text(
              HopeCopy.of(context).copy_location_city_46ccc39,
            ),
            subtitle: Text(
              '${settings.city} • ${settings.locationEnabled ? HopeCopy.of(context).copy_location_on_dad416c : HopeCopy.of(context).copy_manual_selection_90510b2}',
            ),
            trailing: Switch(
              value: settings.locationEnabled,
              onChanged: settings.locationBusy
                  ? null
                  : (value) async {
                if (value) {
                  final ok = await settings.enableLocation();
                  if (!ok && mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          HopeCopy.of(context)
                              .copy_location_permission_was_not_enabled_you_ca_ba53b81,
                        ),
                      ),
                    );
                  }
                } else {
                  await settings.disableLocation();
                }
              },
            ),
          ),
          ListTile(
            leading: const HopeIconTile(HopeV2Icons.location),
            title: Text(
              HopeCopy.of(context).copy_choose_another_city_1375095,
            ),
            onTap: () => _pickCity(context, settings),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            secondary: const HopeIconTile(
              HopeV2Icons.notifications,
            ),
            title: Text(
              HopeCopy.of(context).copy_notifications_370b4a1,
            ),
            subtitle: Text(
              HopeCopy.of(context)
                  .copy_new_opportunities_and_application_updates_d3e84aa,
            ),
            value: settings.notifications,
            onChanged: settings.setNotifications,
          ),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            secondary: const HopeIconTile(
              HopeV2Icons.featured,
            ),
            title: Text(
              HopeCopy.of(context).copy_personalized_recommendations_a4e4411,
            ),
            subtitle: Text(
              HopeCopy.of(context)
                  .copy_based_on_city_and_professional_interests_e0ba2f1,
            ),
            value: settings.personalizedRecommendations,
            onChanged: settings.setPersonalizedRecommendations,
          ),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            secondary: const HopeIconTile(HopeV2Icons.pending),
            title: Text(
              HopeCopy.of(context).copy_quiet_hours_02885b4,
            ),
            subtitle: Text(
              HopeCopy.of(context).copy_limit_notifications_during_rest_b5e0db3,
            ),
            value: settings.quietHours,
            onChanged: settings.setQuietHours,
          ),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            secondary: const HopeIconTile(HopeV2Icons.activity),
            title: Text(
              HopeCopy.of(context).copy_compact_cards_71ed24c,
            ),
            subtitle: Text(
              HopeCopy.of(context).copy_fit_more_information_on_a_page_aedc497,
            ),
            value: settings.compactCards,
            onChanged: settings.setCompactCards,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const HopeIconTile(Icons.info_outline_rounded),
            title: Text(
              HopeCopy.of(context).copy_about_hope_f8ee86b,
            ),
            subtitle: Text(
              HopeCopy.of(context).copy_mission_jobs_fees_and_privacy_a947037,
            ),
            onTap: () => Navigator.push(context, HopeRoutes.about()),
          ),
        ],
      ),
    );
  }

  String _themeLabel(BuildContext context, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => HopeCopy.of(context).copy_dark_c5832d8,
      ThemeMode.light => HopeCopy.of(context).copy_light_096ac39,
      _ => HopeCopy.of(context).copy_use_system_setting_a8649f8,
    };
  }

  Future<void> _pickTheme(
    BuildContext context,
    HopeSettingsController settings,
    ThemeController theme,
  ) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              HopeCopy.of(context).copy_use_system_setting_a8649f8,
            ),
            onTap: () => Navigator.pop(context, 'system'),
          ),
          ListTile(
            title: Text(HopeCopy.of(context).copy_light_096ac39),
            onTap: () => Navigator.pop(context, 'light'),
          ),
          ListTile(
            title: Text(HopeCopy.of(context).copy_dark_c5832d8),
            onTap: () => Navigator.pop(context, 'dark'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (value != null) {
      await theme.setMode(
        switch (value) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => ThemeMode.system,
        },
      );
    }
  }

  Future<void> _pickCity(
    BuildContext context,
    HopeSettingsController settings,
  ) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(18),
        shrinkWrap: true,
        children: [
          Text(
            HopeCopy.of(context).copy_choose_your_preferred_city_c19f66a,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          ...HopeSettingsController.cities.map(
            (value) => ListTile(
              title: Text(value),
              trailing: value == settings.city
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, value),
            ),
          ),
        ],
      ),
    );

    if (value != null) {
      await settings.setCity(value);
    }
  }
}
