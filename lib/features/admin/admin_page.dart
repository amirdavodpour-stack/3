import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/router/app_routes.dart';
import '../../core/admin/admin_repository.dart';
import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/marketplace/job.dart';
import '../../core/marketplace/application.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/components.dart';
import '../../core/theme/app_theme.dart';

import '../../core/ui/premium_components.dart';
import '../../core/theme/hope_v2_design.dart';

ApplicationRegistry _applicationRegistry(BuildContext context) => applicationRegistryOf(context);

// Runtime certification marker: compact Control Center composition batch.

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late Future<HopeAdminSummary> _summary;
  late Future<List<HopeJob>> _jobs;
  late Future<List<HopeApplication>> _applications;
  late Future<List<HopeAdminUser>> _users;
  late Future<List<HopeAdminAuditEvent>> _audit;
  late TabController _tabs;
  bool _actionBusy = false;
  bool _panelVerified = false;
  bool _checkingPanel = true;
  bool _isPrimaryAdmin = false;
  String _currentAdminId = '';
  Set<String> _permissions = <String>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _summary = Future.value(const HopeAdminSummary(values: {}));
    _jobs = Future.value(const <HopeJob>[]);
    _applications = Future.value(const <HopeApplication>[]);
    _users = Future.value(const <HopeAdminUser>[]);
    _audit = Future.value(const <HopeAdminAuditEvent>[]);
    _checkPanelAccess();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _checkPanelAccess() async {
    try {
      final access = await context.read<AdminRepository>().getPanelAccess();
      if (!mounted) return;
      if (access['verified'] != true) {
        setState(() => _checkingPanel = false);
        Navigator.pushReplacement(context, HopeRoutes.adminAccess());
        return;
      }
      final repository = context.read<AdminRepository>();
      final summary = repository.getSummary();
      final jobs = repository.listJobs();
      final applications = repository.listApplications();
      final users = repository.listUsers();
      final audit = repository.listAudit();
      setState(() {
        _panelVerified = true;
        _isPrimaryAdmin = access['primaryAdmin'] == true;
        _currentAdminId = '${access['userId'] ?? ''}';
        _permissions = (access['permissions'] is List)
            ? (access['permissions'] as List).whereType<String>().toSet()
            : <String>{};
        _checkingPanel = false;
        _summary = summary;
        _jobs = jobs;
        _applications = applications;
        _users = users;
        _audit = audit;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingPanel = false);
      Navigator.pushReplacement(context, HopeRoutes.adminAccess());
    }
  }

  void _reload() {
    final repository = context.read<AdminRepository>();
    _summary = repository.getSummary();
    _jobs = repository.listJobs();
    _applications = repository.listApplications();
    _users = repository.listUsers();
    _audit = repository.listAudit();
    if (mounted) setState(() {});
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await action();
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(apiErrorMessage(error,
                fallback: HopeCopy.of(context).copy_operation_failed_eb38c4c))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  String _initial(String value) {
    final text = value.trim();
    return text.isEmpty ? '?' : text.characters.first.toUpperCase();
  }

  bool _hasPermission(String permission) => _permissions.contains(permission);

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _jobKindLabel(String value) => switch (value.trim().toUpperCase()) {
        'MISSION' => _t('ماموریت', 'Mission'),
        'JOB' => _t('شغل', 'Job'),
        _ => _t('سایر', 'Other'),
      };

  String _jobStatusLabel(String value) => switch (value.trim().toUpperCase()) {
        'DRAFT' => _t('پیش‌نویس', 'Draft'),
        'PUBLISHED' => _t('منتشر شده', 'Published'),
        'FUNDED' => _t('تأمین وجه شده', 'Funded'),
        'ASSIGNED' => _t('اختصاص داده شده', 'Assigned'),
        'IN_PROGRESS' => _t('در حال انجام', 'In progress'),
        'DELIVERED' => _t('تحویل شده', 'Delivered'),
        'UNDER_REVIEW' => _t('در حال بررسی', 'Under review'),
        'COMPLETED' => _t('تکمیل شده', 'Completed'),
        'CANCELLED' => _t('لغو شده', 'Cancelled'),
        _ => _t('نیازمند بررسی', 'Needs review'),
      };

  String _applicationStatusLabel(String value) => switch (value.trim().toUpperCase()) {
        'PENDING' => _t('در انتظار بررسی', 'Pending'),
        'SHORTLISTED' => _t('در فهرست کوتاه', 'Shortlisted'),
        'FORWARDED' => _t('ارسال‌شده', 'Forwarded'),
        'INTERVIEW' => _t('مصاحبه', 'Interview'),
        'OFFERED' => _t('پیشنهاد داده شد', 'Offer sent'),
        'HIRED' => _t('استخدام شد', 'Hired'),
        'REJECTED' => _t('رد شده', 'Rejected'),
        'WITHDRAWN' => _t('پس گرفته شد', 'Withdrawn'),
        _ => _t('نیازمند بررسی', 'Needs review'),
      };

  String _userRoleLabel(String value) => switch (value.trim().toUpperCase()) {
        'USER' => _t('کاربر', 'User'),
        'ADMIN' => _t('مدیر', 'Admin'),
        _ => _t('سایر', 'Other'),
      };

  String _userStatusLabel(String value) => switch (value.trim().toUpperCase()) {
        'ACTIVE' => _t('فعال', 'Active'),
        'SUSPENDED' => _t('معلق', 'Suspended'),
        _ => _t('نیازمند بررسی', 'Needs review'),
      };

  String _auditActionLabel(String value) => switch (value.trim().toUpperCase()) {
        'ADMIN_JOB_MODERATE' => _t('مدیریت فرصت', 'Opportunity moderation'),
        'JOB_MODERATED' => _t('مدیریت فرصت', 'Opportunity moderation'),
        'ADMIN_JOB_DELETE' => _t('حذف فرصت', 'Opportunity deletion'),
        'ADMIN_USER_STATUS' => _t('تغییر وضعیت کاربر', 'User status change'),
        'ADMIN_APPLICATION_SHORTLIST' => _t('انتخاب اولیه درخواست', 'Application shortlist'),
        'ADMIN_APPLICATION_FORWARD' => _t('ارسال درخواست', 'Application forwarding'),
        'ADMIN_APPLICATION_REJECT' => _t('رد درخواست', 'Application rejection'),
        'TRUST_REPORT_STATUS' => _t('تغییر وضعیت گزارش اعتماد', 'Trust report status'),
        _ => _t('رویداد سیستمی', 'System event'),
      };

  String _entityTypeLabel(String value) => switch (value.trim().toUpperCase()) {
        'USER' => _t('کاربر', 'User'),
        'JOB' => _t('فرصت', 'Opportunity'),
        'JOB_APPLICATION' => _t('درخواست', 'Application'),
        'TRUST_REPORT' => _t('گزارش اعتماد', 'Trust report'),
        'PAYOUT' => _t('تسویه', 'Payout'),
        _ => _t('سایر', 'Other'),
      };

  @override
  Widget build(BuildContext context) {
    if (_checkingPanel) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_panelVerified) return const SizedBox.shrink();
    return Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: PremiumPageFrame(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  PremiumHeader(
                    page: HopePageId.admin,
                    domain: HopeProductDomain.control,
                    eyebrow: HopeCopy.of(context).copy_control_center_15e20c8,
                    title: HopeCopy.of(context)
                        .copy_monitor_and_manage_hope_in_one_place_bea3b7d,
                    subtitle: HopeCopy.of(context)
                        .copy_review_users_opportunities_applications_an_e30b9d2,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PremiumIconButton(
                          icon: HopeV2Icons.message,
                          tooltip: _t('گفتگوی مدیران', 'Admin chat'),
                          onPressed: _actionBusy
                              ? null
                              : () => Navigator.push(context, HopeRoutes.adminChat()),
                        ),
                        const SizedBox(width: 6),
                        PremiumIconButton(
                          icon: HopeV2Icons.secure,
                          tooltip: _t('قفل پنل', 'Lock admin panel'),
                          onPressed: _actionBusy
                              ? null
                              : () async {
                                  final repository = context.read<AdminRepository>();
                                  final navigator = Navigator.of(context);
                                  await repository.lockPanel();
                                  if (!mounted) return;
                                  navigator.pushReplacement(HopeRoutes.adminAccess());
                                },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                FutureBuilder<HopeAdminSummary>(
                    future: _summary,
                    builder: (context, s) => _summaryGrid(context, s.data)),
                const SizedBox(height: 11),
                PremiumQuickActionStrip(
                  domain: HopeProductDomain.control,
                  title: _t('کنترل‌های اصلی', 'Control actions'),
                  subtitle: _t(
                    'عملیات حساس، اختلاف‌ها و ارتباط داخلی مدیران در سطح اختصاصی کنترل.',
                    'Sensitive operations, disputes, and internal administrator communication.',
                  ),
                  actions: [
                    PremiumQuickAction(
                      label: _t('مرکز عملیات', 'Operations center'),
                      icon: HopeV2Icons.insights,
                      primary: true,
                      onPressed: () => Navigator.push(
                        context,
                        HopeRoutes.adminOperations(),
                      ),
                    ),
                    PremiumQuickAction(
                      label: _t('مرکز اختلاف', 'Dispute center'),
                      icon: HopeV2Icons.pending,
                      onPressed: () => Navigator.push(
                        context,
                        HopeRoutes.adminDisputes(),
                      ),
                    ),
                    PremiumQuickAction(
                      label: _t('گفتگوی مدیران', 'Admin chat'),
                      icon: HopeV2Icons.message,
                      onPressed: () => Navigator.push(
                        context,
                        HopeRoutes.adminChat(),
                      ),
                    ),
                  ],
                ),
                if (_isPrimaryAdmin && _hasPermission('admin.manage_admins')) ...[
                  const SizedBox(height: 14),
                  PremiumSectionHeader(
                    page: HopePageId.admin,
                    domain: HopeProductDomain.control,
                    title: _t('مدیریت مدیران', 'Administrator management'),
                    subtitle: _t(
                      'افزودن یا لغو دسترسی مدیریتی فقط در این سطح محافظت‌شده.',
                      'Admin promotion and access revocation stay inside this protected control surface.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _adminManagementSection(),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _actionBusy ? null : _showGrantAdminDialog,
                    icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                    label: Text(_t('افزودن مدیر جدید', 'Add new administrator')),
                  ),
                ],
                const SizedBox(height: 13),
                TabBar(controller: _tabs, isScrollable: true, tabs: [
                  Tab(text: HopeCopy.of(context).copy_opportunities_015066e),
                  Tab(text: HopeCopy.of(context).copy_applications_6655869),
                  Tab(text: HopeCopy.of(context).copy_users_200338b),
                  Tab(text: HopeCopy.of(context).copy_audit_log_ff87181),
                ]),
                SizedBox(
                    height: 580,
                    child: TabBarView(controller: _tabs, children: [
                      _jobsTab(context),
                      _applicationsTab(context),
                      _usersTab(context),
                      _auditTab(context)
                    ])),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Future<void> _showGrantAdminDialog() async {
    final emailController = TextEditingController();
    try {
      final email = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('افزودن مدیر جدید', 'Add new administrator')),
          content: TextField(
            controller: emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
            decoration: InputDecoration(
              labelText: _t('ایمیل کاربر موجود', 'Existing user email'),
              hintText: 'name@example.com',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_t('انصراف', 'Cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, emailController.text.trim()),
              child: Text(_t('اعطای نقش مدیر', 'Grant admin role')),
            ),
          ],
        ),
      );
      if (!mounted || email == null || email.trim().isEmpty) return;
      await _runAction(() async {
        final result = await context.read<AdminRepository>().grantAdminByEmail(email);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(
            'نقش مدیر برای ${result['displayName'] ?? result['email']} فعال شد.',
            'Administrator role granted to ${result['displayName'] ?? result['email']}.',
          ))),
        );
      });
    } finally {
      emailController.dispose();
    }
  }
  Widget _adminManagementSection() => FutureBuilder<List<HopeAdminUser>>(
        future: _users,
        builder: (context, snapshot) {
          final admins = (snapshot.data ?? const <HopeAdminUser>[])
              .where((u) => u.role.toUpperCase() == 'ADMIN')
              .toList(growable: false);
          return PremiumPanel(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('مدیریت مدیران', 'Administrator management'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(_t('افزودن، لغو نقش و خروج اجباری نشست‌های مدیران فقط در اختیار مالک است.', 'Promoting admins, revoking their role, and forcing session revocation are owner-only controls.')),
              const SizedBox(height: 10),
              if (admins.isEmpty) Text(_t('مدیر دیگری ثبت نشده است.', 'No administrators found.'))
              else ...admins.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const HopeIconTile(HopeV2Icons.secure),
                  title: Text(u.displayName.isEmpty ? u.email : u.displayName),
                  subtitle: Text(u.email),
                  trailing: u.id == _currentAdminId
                      ? Chip(label: Text(_t('مالک فعلی', 'Current owner')))
                      : Wrap(spacing: 6, children: [
                          IconButton(tooltip: _t('خروج همه نشست‌ها', 'Revoke sessions'), onPressed: _actionBusy ? null : () => _revokeAdminSessions(u), icon: const Icon(Icons.logout)),
                          IconButton(tooltip: _t('لغو نقش مدیر', 'Revoke admin'), onPressed: _actionBusy ? null : () => _revokeAdmin(u), icon: const Icon(Icons.remove_moderator_outlined)),
                        ]),
                ),
              )),
            ]),
          );
        },
      );

  Future<void> _revokeAdmin(HopeAdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('لغو نقش مدیر؟', 'Revoke administrator role?')),
        content: Text(_t('دسترسی مدیریتی ${user.displayName.isEmpty ? user.email : user.displayName} قطع می‌شود.', 'Administrator access for ${user.displayName.isEmpty ? user.email : user.displayName} will be removed.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('انصراف', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('لغو نقش', 'Revoke role'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runAction(() => context.read<AdminRepository>().revokeAdministrator(user.id));
  }

  Future<void> _revokeAdminSessions(HopeAdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('خروج همه نشست‌ها؟', 'Revoke all sessions?')),
        content: Text(_t('همه نشست‌های فعلی این مدیر باطل می‌شوند.', 'All current sessions for this administrator will be invalidated.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('انصراف', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('خروج همه', 'Revoke all'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runAction(() => context.read<AdminRepository>().revokeUserSessions(user.id));
  }
  Widget _summaryGrid(BuildContext context, HopeAdminSummary? raw) {
    final m = raw;
    final items = <Map<String, Object>>[
      {
        'key': 'users',
        'label': HopeCopy.of(context).copy_users_200338b,
        'icon': HopeV2Icons.profile,
      },
      {
        'key': 'published_opportunities',
        'label': HopeCopy.of(context).copy_published_1a00f35,
        'icon': HopeV2Icons.insights,
      },
      {
        'key': 'missions',
        'label': HopeCopy.of(context).copy_missions_a833d13,
        'icon': HopeV2Icons.mission,
      },
      {
        'key': 'jobs',
        'label': HopeCopy.of(context).copy_jobs_ebf9a80,
        'icon': HopeV2Icons.job,
      },
      {
        'key': 'pending_applications',
        'label': HopeCopy.of(context).copy_pending_86ad26d,
        'icon': HopeV2Icons.pending,
      },
      {
        'key': 'audit_events',
        'label': HopeCopy.of(context).copy_audit_events_7f47fd5,
        'icon': HopeV2Icons.completed,
      },
    ];

    return GridView.extent(
      maxCrossAxisExtent: 340,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.45,
      children: items.map((item) {
        final key = item['key']! as String;
        return PremiumStatCard(
          label: item['label']! as String,
          value: '${m?[key] ?? 0}',
          icon: item['icon']!,
          accent: Theme.of(context).colorScheme.primary,
        );
      }).toList(),
    );
  }
  Widget _errorState(BuildContext context, Object? error,
      {required VoidCallback retry}) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.all(20),
        child: EmptyState(
            icon: HopeV2Icons.pending,
            title: HopeCopy.of(context).copy_connection_failed_1b34bc9,
            message: apiErrorMessage(error,
                fallback: HopeCopy.of(context)
                    .copy_the_server_did_not_return_data_try_again_bccfbb3),
            action: FilledButton(
                onPressed: retry,
                child: Text(HopeCopy.of(context).copy_retry_49f3eba))));
  }

  Widget _jobsTab(BuildContext context) => FutureBuilder<List<HopeJob>>(
      future: _jobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(context, snapshot.error, retry: _reload);
        }
        final list = snapshot.data ?? const <HopeJob>[];
        if (list.isEmpty) {
          return EmptyState(
              icon: HopeV2Icons.job,
              title: HopeCopy.of(context).copy_no_opportunities_a112400,
              message:
                  HopeCopy.of(context).copy_opportunities_appear_here_d85bef9);
        }
        return ListView(
            padding: const EdgeInsets.only(top: 14),
            children: list.take(50).map<Widget>((job) {
              final status = job.status ?? '—';
              return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PremiumPanel(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        HopeIconTile(
                            job.isJob
                                ? HopeV2Icons.job
                                : HopeV2Icons.mission,
                            filled: true),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(job.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 3),
                              Text(
                                  '${_jobKindLabel(job.kind)} • ${job.city ?? HopeCopy.of(context).copy_remote_dcbb625} • ${_jobStatusLabel(status)}')
                            ])),
                        if (status == 'DRAFT')
                          IconButton(
                              onPressed: () =>
                                  _moderateJob(job.id, 'PUBLISHED'),
                              tooltip:
                                  HopeCopy.of(context).copy_publish_5cfd26b,
                              icon: const HopeIcon(HopeV2Icons.completed, size: 19)),
                        if (status == 'PUBLISHED')
                          IconButton(
                              onPressed: () =>
                                  _moderateJob(job.id, 'CANCELLED'),
                              tooltip:
                                  HopeCopy.of(context).copy_disable_73bea34,
                              icon: const HopeIcon(HopeV2Icons.secure, size: 19)),
                        if (_hasPermission('admin.delete_jobs'))
                          IconButton(
                            onPressed: () => _removeJob(job.id),
                            tooltip: HopeCopy.of(context).copy_delete_b17eb9d,
                            icon: const HopeIcon(HopeV2Icons.close, size: 19, color: AppColors.danger)),
                      ])));
            }).toList());
      });

  Widget _applicationsTab(BuildContext context) => FutureBuilder<
          List<HopeApplication>>(
      future: _applications,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(context, snapshot.error, retry: _reload);
        }
        final list = snapshot.data ?? const <HopeApplication>[];
        if (list.isEmpty) {
          return EmptyState(
              icon: HopeV2Icons.mission,
              title: HopeCopy.of(context).copy_no_applications_0917e11,
              message: HopeCopy.of(context)
                  .copy_job_applications_are_managed_here_1b21e96);
        }
        return ListView(
            padding: const EdgeInsets.only(top: 14),
            children: list.take(50).map<Widget>((a) {
              final status = a.status;
              return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PremiumPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const HopeIconTile(
                                HopeV2Icons.mission,
                                filled: true),
                            title: Text(
                                HopeCopy.of(context).copy_candidate_c67d7bf),
                            subtitle: Text(
                                '${a.jobTitle.isEmpty ? HopeCopy.of(context).copy_job_ce2feba : a.jobTitle} • ${_applicationStatusLabel(status)}')),
                        if (status == 'PENDING')
                          Row(children: [
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _applicationAction(a.id, 'shortlist'),
                                    icon: const HopeIcon(HopeV2Icons.featured, size: 19),
                                    label: Text(HopeCopy.of(context)
                                        .copy_shortlist_8a78995))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: FilledButton.icon(
                                    onPressed: () =>
                                        _applicationAction(a.id, 'select'),
                                    icon: const HopeIcon(HopeV2Icons.arrowRight, size: 19),
                                    label: Text(HopeCopy.of(context)
                                        .copy_forward_5ec70ea))),
                            const SizedBox(width: 8),
                            IconButton(
                                onPressed: () =>
                                    _applicationAction(a.id, 'reject'),
                                tooltip: HopeCopy.of(context)
                                    .copy_reject_application_9682e01,
                                icon: const HopeIcon(HopeV2Icons.close, size: 19, color: AppColors.danger))
                          ]),
                        if (status == 'SHORTLISTED')
                          Row(children: [
                            Expanded(
                                child: FilledButton.icon(
                                    onPressed: () =>
                                        _applicationAction(a.id, 'select'),
                                    icon: const HopeIcon(HopeV2Icons.arrowRight, size: 19),
                                    label: Text(HopeCopy.of(context)
                                        .copy_forward_to_employer_0baa2e1))),
                            IconButton(
                                onPressed: () =>
                                    _applicationAction(a.id, 'reject'),
                                tooltip: HopeCopy.of(context)
                                    .copy_reject_application_9682e01,
                                icon: const HopeIcon(HopeV2Icons.close, size: 19, color: AppColors.danger))
                          ])
                      ])));
            }).toList());
      });

  Widget _usersTab(BuildContext context) => FutureBuilder<List<HopeAdminUser>>(
      future: _users,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(context, snapshot.error, retry: _reload);
        }
        final list = snapshot.data ?? const <HopeAdminUser>[];
        if (list.isEmpty) {
          return EmptyState(
              icon: HopeV2Icons.profile,
              title: HopeCopy.of(context).copy_users_200338b,
              message: HopeCopy.of(context)
                  .copy_the_server_did_not_return_data_try_again_bccfbb3);
        }
        return ListView(
            padding: const EdgeInsets.only(top: 14),
            children: list.take(100).map<Widget>((u) {
              final status = u.status;
              return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PremiumPanel(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              child: Text(_initial(u.displayName))),
                          title: Text(u.displayName),
                          subtitle: Text(
                              '${u.email.isEmpty ? '—' : u.email} • ${_userRoleLabel(u.role)} • ${_userStatusLabel(status)}'),
                          trailing: u.role == 'ADMIN'
                              ? null
                              : IconButton(
                                  onPressed: () => _setUserStatus(
                                      u.id,
                                      status == 'ACTIVE'
                                          ? 'SUSPENDED'
                                          : 'ACTIVE'),
                                  tooltip: status == 'ACTIVE'
                                      ? HopeCopy.of(context)
                                          .copy_suspend_44bded8
                                      : HopeCopy.of(context)
                                          .copy_activate_2215693,
                                  icon: HopeIcon(status == 'ACTIVE'
                                      ? HopeV2Icons.secure
                                      : HopeV2Icons.completed,
                                    size: 19)))));
            }).toList());
      });

  Widget _auditTab(BuildContext context) =>
      FutureBuilder<List<HopeAdminAuditEvent>>(
          future: _audit,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _errorState(context, snapshot.error, retry: _reload);
            }
            final list = snapshot.data ?? const <HopeAdminAuditEvent>[];
            return ListView(
                padding: const EdgeInsets.only(top: 14),
                children: list.take(100).map<Widget>((a) {
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PremiumPanel(
                          padding: const EdgeInsets.all(12),
                          child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading:
                                  const HopeIconTile(HopeV2Icons.activity),
                              title: Text(_auditActionLabel(a.action)),
                              subtitle: Text(
                                  '${a.actorName.isEmpty ? HopeCopy.of(context).copy_system_bf4e081 : a.actorName} • ${_entityTypeLabel(a.entityType)} • ${a.createdAt}'))));
                }).toList());
          });

  Future<void> _applicationAction(String id, String action) {
    final repository = context.read<AdminRepository>();
    return _runAction(() async {
      switch (action) {
        case 'shortlist':
          return await repository.shortlistApplication(id);
        case 'select':
          return await repository.forwardApplication(id);
        case 'reject':
          return await repository.rejectApplication(id);
        default:
          throw ArgumentError.value(action, 'action');
      }
    });
  }

  Future<void> _moderateJob(String id, String status) =>
      _runAction(() => _applicationRegistry(context).adminCommands.moderateJob(id, status));

  Future<void> _setUserStatus(String id, String status) => _runAction(
      () => _applicationRegistry(context).adminCommands.setUserStatus(id, status));

  Future<void> _removeJob(String id) async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEn ? 'Delete opportunity?' : 'فرصت حذف شود؟'),
        content: Text(isEn
            ? 'This action permanently removes the opportunity. Review the record before continuing.'
            : 'این عملیات فرصت را به‌صورت دائمی حذف می‌کند. قبل از ادامه، رکورد را بررسی کنید.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isEn ? 'Cancel' : 'انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isEn ? 'Delete' : 'حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction(
      () => _applicationRegistry(context).adminCommands.deleteJob(id),
    );
  }
}