import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/marketplace/job.dart';
import '../../core/marketplace/job_detail_repository.dart';
import 'job_detail_controller.dart';
import '../../core/transactions/transaction_repository.dart';
import '../../core/uploads/upload_queue.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/marketplace/employer_candidate_matching_repository.dart';
import '../../core/router/app_routes.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_async_state.dart';
import 'employer_candidate_matches_page.dart';
import '../../core/ui/copy.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/hope_l10n.dart';

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({super.key, required this.job});
  final HopeJob job;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  bool loading = false;
  String? _candidateBusyId;
  // Contract guard: _candidateBusyId == candidate.id
  late final JobDetailController _controller;
  Future<List<HopeCandidate>>? _candidatesFuture;

  @override
  void initState() {
    super.initState();
    _controller = JobDetailController(
      repository: context.read<JobDetailRepository>(),
      job: widget.job,
    );
    _candidatesFuture = _controller.candidatesFuture;
  }

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String? _mediaUrl() {
    const keys = <String>[
      'imageUrl',
      'coverUrl',
      'thumbnailUrl',
      'image',
      'coverImage',
      'mediaUrl',
    ];
    for (final key in keys) {
      final value = widget.job.raw[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _candidateStatusLabel(String status) => switch (status.toUpperCase()) {
        'FORWARDED' => _t('ارسال‌شده', 'Forwarded'),
        'INTERVIEW' => _t('مصاحبه', 'Interview'),
        'OFFERED' => _t('پیشنهاد داده شد', 'Offer sent'),
        'HIRED' => _t('استخدام شد', 'Hired'),
        'REJECTED' => _t('رد شده', 'Rejected'),
        _ => _t('در حال بررسی', 'Under review'),
      };
  String _candidateComparisonStatusLabel(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    return _candidateStatusLabel(raw);
  }

  Future<void> _openEmployerCandidateMatches(
    BuildContext context,
    HopeJob job,
  ) async {
    final repository =
        context.read<EmployerCandidateMatchingRepository?>();
    if (repository == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EmployerCandidateMatchesLoader(
          future: repository.listForJob(job.id),
          jobTitle: job.title,
        ),
      ),
    );
  }

  Future<void> action() async {
    final auth = context.read<AuthController?>();

    if (auth == null || !auth.isAuthenticated) {
      await Navigator.push(context, HopeRoutes.login());

      if (!mounted || auth == null || !auth.isAuthenticated) {
        return;
      }
    }

    final isJob = widget.job.isJob;

    if (isJob) {
      final resume = TextEditingController();
      final skills = TextEditingController();

      final values = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                HopeCopy.of(context).copy_apply_to_this_job_923b353,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                HopeCopy.of(context)
                    .copy_add_a_concise_resume_and_relevant_skills_298a4f1,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: resume,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: HopeCopy.of(context).copy_resume_summary_a1cc787,
                  prefixIcon: const HopeIcon(HopeV2Icons.description, size: 20),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: skills,
                decoration: InputDecoration(
                  labelText: HopeCopy.of(context).copy_skills_79566c4,
                  prefixIcon: const HopeIcon(HopeV2Icons.skills, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final resumeText = resume.text.trim();
                  final skillsText = skills.text.trim();
                  Navigator.pop(context, [resumeText, skillsText]);
                },
                child: Text(
                  HopeCopy.of(context).copy_submit_application_43b8707,
                ),
              ),
            ],
          ),
        ),
      );

      final submittedResume = resume.text.trim();
      final submittedSkills = skills.text.trim();
      resume.dispose();
      skills.dispose();

      if (values == null) {
        return;
      }

      if (submittedResume.length < 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                HopeCopy.of(context)
                    .copy_add_a_concise_resume_and_relevant_skills_298a4f1,
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() => loading = true);

      try {
        await _controller.apply(
          resumeText: values.isNotEmpty ? values[0] : submittedResume,
          skills: values.length > 1 ? values[1] : submittedSkills,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                HopeCopy.of(context)
                    .copy_your_application_was_sent_for_admin_review_5d9c43a,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                apiErrorMessage(
                  e,
                  fallback: HopeCopy.of(context).copy_operation_failed_eb38c4c,
                ),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => loading = false);
        }
      }

      return;
    }

    final price = TextEditingController(text: widget.job.budgetMin ?? '');
    final message = TextEditingController();

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              HopeCopy.of(context).copy_offer_for_this_mission_f50b00a,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              HopeCopy.of(context)
                  .copy_send_your_price_and_a_short_message_to_the_3961669,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: InputDecoration(
                labelText: HopeCopy.of(context).copy_offer_price_d8fc5f4,
                prefixIcon: const HopeIcon(HopeV2Icons.payments, size: 20),
                suffixText: _t('تومان', 'Toman'),
                helperText: _t(
                  'قیمت پیشنهادی را به تومان و به‌صورت عدد صحیح وارد کنید.',
                  'Enter your offer in whole Toman.',
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: message,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: HopeCopy.of(context).copy_message_c821412,
                alignLabelWithHint: true,
                prefixIcon: const HopeIcon(HopeV2Icons.message, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, [price.text, message.text]),
              child: Text(HopeCopy.of(context).copy_send_offer_8aa1351),
            ),
          ],
        ),
      ),
    );

    final submittedPrice = result?.isNotEmpty == true ? result![0] : price.text;
    final submittedMessage =
        result != null && result.length > 1 ? result[1] : message.text;
    price.dispose();
    message.dispose();

    if (result == null) {
      return;
    }
    final offerPrice = submittedPrice.trim();
    if (!RegExp(r'^\d+$').hasMatch(offerPrice) ||
        BigInt.tryParse(offerPrice) == null ||
        BigInt.parse(offerPrice) <= BigInt.zero ||
        BigInt.parse(offerPrice) > BigInt.from(9000000000000000)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(HopeCopy.of(context).copy_operation_failed_eb38c4c),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => loading = true);

    try {
      await _controller.sendOffer(
        price: offerPrice,
        message: submittedMessage.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              HopeCopy.of(context).copy_your_offer_was_submitted_75e3409,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                e,
                fallback: HopeCopy.of(context).copy_operation_failed_eb38c4c,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _candidateAction(String candidateId, String action) async {
    if (_candidateBusyId != null) return;
    setState(() => _candidateBusyId = candidateId);
    try {
      await _controller.candidateAction(candidateId, action);
      if (mounted) {
        setState(() {
          _candidatesFuture = _controller.candidatesFuture;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: HopeCopy.of(context).copy_operation_failed_eb38c4c,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _candidateBusyId = null);
    }
  }

  Future<void> _compareCandidates(List<HopeCandidate> candidates) async {
    final repository = context.read<JobDetailRepository>();
    final selected = candidates.take(5).toList(growable: false);
    if (selected.length < 2) return;
    try {
      final result = await repository.compareCandidates(
        widget.job.id,
        selected.map((c) => c.id).toList(),
      );
      if (!mounted) return;
      final rows = (result['candidates'] is List)
          ? (result['candidates'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('مقایسه متقاضیان', 'Candidate comparison')),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: rows.isEmpty
                  ? Text(
                      _t(
                        'داده‌ای برای مقایسه برنگشت.',
                        'No comparison data returned.',
                      ),
                    )
                  : Column(
                      children: rows
                          .map(
                            (row) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: PremiumPanel(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _t(
                                        'متقاضی ناشناس',
                                        'Anonymous candidate',
                                      ),
                                      style: Theme.of(ctx).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 5),
                                    Text('${row['skills'] ?? '—'}'),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${row['resumeHighlights'] ?? '—'}',
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _candidateComparisonStatusLabel(row['status']),
                                      style: Theme.of(ctx).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('بستن', 'Close')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              e,
              fallback: _t('مقایسه ناموفق بود.', 'Comparison failed.'),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _reportJob() async {
    final repository = context.read<JobDetailRepository>();
    final reason = TextEditingController();
    final details = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('گزارش این فرصت', 'Report this opportunity')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reason,
                maxLength: 120,
                decoration: InputDecoration(labelText: _t('دلیل', 'Reason')),
              ),
              TextField(
                controller: details,
                maxLines: 4,
                maxLength: 2000,
                decoration: InputDecoration(labelText: _t('جزئیات', 'Details')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('لغو', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reason.text.trim().length >= 3),
            child: Text(_t('ارسال گزارش', 'Submit report')),
          ),
        ],
      ),
    );
    final r = reason.text.trim();
    final d = details.text.trim();
    reason.dispose();
    details.dispose();
    if (result != true) return;
    try {
      await repository.reportJob(
            widget.job.id,
            reason: r,
            details: d,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('گزارش ثبت شد.', 'Report submitted.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final isJob = j.isJob;
    final visibility = j.visibility;
    final currentUserId =
        context.read<AuthController?>()?.user?['id']?.toString();
    final isOwner =
        currentUserId != null && currentUserId == j.ownerId?.toString();
    final isProvider =
        currentUserId != null && currentUserId == j.providerId?.toString();
    final canViewFinance = isOwner || isProvider;
    final collaborationChatOpen = (isOwner || isProvider) && ['ASSIGNED','FUNDED','IN_PROGRESS','DELIVERED','UNDER_REVIEW','COMPLETED'].contains(j.status?.toUpperCase());

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Semantics(
                button: true,
                enabled: !loading,
                label: loading
                    ? HopeCopy.of(context).copy_sending_c4b5575
                    : canViewFinance
                        ? _t('مشاهده وضعیت مالی', 'View financial flow')
                        : isJob
                            ? HopeCopy.of(context)
                                .copy_apply_for_this_job_3a75a03
                            : HopeCopy.of(context)
                                .copy_offer_for_mission_ced8d4c,
                child: FilledButton.icon(
                  onPressed: loading
                      ? null
                      : canViewFinance
                          ? () => Navigator.push(
                                context,
                                HopeRoutes.transaction(
                                  repository:
                                      context.read<TransactionRepository>(),
                                  uploadQueue: context.read<UploadQueue>(),
                                  jobId: j.id,
                                ),
                              )
                          : action,
                  icon: HugeIcon(
                    icon: canViewFinance
                        ? HopeV2Icons.wallet
                        : isJob
                            ? HopeV2Icons.userAdd
                            : HopeV2Icons.payments,
                    size: 20,
                  ),
                  label: Text(
                    loading
                        ? HopeCopy.of(context).copy_sending_c4b5575
                        : canViewFinance
                            ? _t('مشاهده وضعیت مالی', 'View financial flow')
                            : isJob
                                ? HopeCopy.of(context)
                                    .copy_apply_for_this_job_3a75a03
                                : HopeCopy.of(context)
                                    .copy_offer_for_mission_ced8d4c,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: PremiumPageFrame(
        page: HopePageId.opportunityDetail,
        maxWidth: 1180,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 102),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PremiumIconButton(
                icon: Localizations.localeOf(context).languageCode == 'en'
                    ? HopeV2Icons.arrowLeft
                    : HopeV2Icons.arrowRight,
                tooltip: _t('بازگشت', 'Back'),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(height: 8),
                  PremiumHero(
                    page: HopePageId.opportunityDetail,
                    domain: HopeProductDomain.discovery,
                    eyebrow: isJob
                        ? HopeCopy.of(context).copy_job_ce2feba
                        : HopeCopy.of(context).copy_mission_fb4c5e1,
                    title: j.title,
                    message: [
                      j.category ?? j.categoryId,
                      if (j.city != null && j.city!.trim().isNotEmpty) j.city,
                    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' • '),
                    icon: isJob ? HopeV2Icons.job : HopeV2Icons.mission,
                    mediaUrl: _mediaUrl(),
                    height: MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact ? 188 : 280,
                    semanticLabel: j.title,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: HopeV2Spacing.sm,
                    runSpacing: HopeV2Spacing.sm,
                    children: [
                      PremiumTag(
                        label: isJob
                            ? HopeCopy.of(context).copy_job_ce2feba
                            : HopeCopy.of(context).copy_mission_fb4c5e1,
                        color: isJob
                            ? secondaryAccent(context)
                            : AppColors.primary,
                        icon: isJob
                            ? HopeV2Icons.job
                            : HopeV2Icons.mission,
                      ),
                      PremiumTag(
                        label: visibility == 'SPECIALIZED'
                            ? HopeCopy.of(context).copy_specialized_5d1ca04
                            : HopeCopy.of(context).copy_public_21e97be,
                        color: visibility == 'SPECIALIZED'
                            ? AppColors.warning
                            : secondaryAccent(context),
                        icon: visibility == 'SPECIALIZED'
                            ? HopeV2Icons.secure
                            : HopeV2Icons.insights,
                      ),
                      if (j.city != null)
                        PremiumTag(
                          label: j.city!,
                          color: AppColors.muted,
                          icon: HopeV2Icons.location,
                        ),
                    ],
                  ),
                  if (j.isRecommended &&
                      (j.recommendationScore != null ||
                          j.recommendationReasons.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    _MatchIntelligence(job: j),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    j.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tiles = [
                        PremiumStatCard(
                          label: isJob
                              ? HopeCopy.of(context).copy_monthly_pay_d62519b
                              : HopeCopy.of(context).copy_mission_budget_923bb6e,
                          value: isJob
                              ? moneyLabel(
                                  context,
                                  j.monthlySalary ?? j.budgetMin ?? '—',
                                )
                              : moneyLabel(
                                  context,
                                  '${j.budgetMin ?? '—'} تا ${j.budgetMax ?? '—'}',
                                ),
                          icon: HopeV2Icons.payments,
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        PremiumStatCard(
                          label: HopeCopy.of(context).copy_field_fcb7b26,
                          value: j.category ?? j.categoryId ?? '—',
                          icon: HopeV2Icons.category,
                          accent: secondaryAccent(context),
                        ),
                      ];
                      if (constraints.maxWidth < 500) {
                        return Column(
                          children: [
                            tiles[0],
                            const SizedBox(height: 10),
                            tiles[1],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: tiles[0]),
                          const SizedBox(width: 10),
                          Expanded(child: tiles[1]),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  PremiumPanel(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          HopeCopy.of(context).copy_working_details_4ef3155,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        if (isJob) ...[
                          _line(
                            context,
                            HopeV2Icons.pending,
                            HopeCopy.of(context).copy_schedule_3af1939,
                            j.schedule == 'PART_TIME'
                                ? HopeCopy.of(context).copy_part_time_086787b
                                : HopeCopy.of(context).copy_full_time_1e4bd4e,
                          ),
                          _line(
                            context,
                            HopeV2Icons.activity,
                            HopeCopy.of(context)
                                .copy_application_deadline_0a6c25c,
                            j.applicationDeadline ?? '—',
                          ),
                        ],
                        if (!isJob)
                          _line(
                            context,
                            HopeV2Icons.pending,
                            HopeCopy.of(context).copy_duration_cc42be6,
                            '${j.duration ?? '—'} ${HopeCopy.of(context).copy_hours_7408608}',
                          ),
                        _line(
                          context,
                          HopeV2Icons.completed,
                          HopeCopy.of(context).copy_acceptance_criteria_f213cb2,
                          j.acceptanceCriteria ?? '—',
                        ),
                      ],
                    ),
                  ),
                  if (isJob) ...[
                    const SizedBox(height: 13),
                    PremiumPanel(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const HugeIcon(icon: HopeV2Icons.secure, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              HopeCopy.of(context)
                                  .copy_job_applications_are_reviewed_by_an_admin__5098e17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 13),
                  _JobLifecycleCard(job: j),
                  const SizedBox(height: 13),
                  if (context.read<AuthController?>()?.user?['id'] == (j.ownerId ?? '') &&
                      context.read<EmployerCandidateMatchingRepository?>() != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        onPressed: () => _openEmployerCandidateMatches(context, j),
                        icon: const HugeIcon(icon: HopeV2Icons.match, size: 18),
                        label: Text(
                          _t(
                            'پذیرندگان بر اساس انطباق',
                            'Applicants by compatibility',
                          ),
                        ),
                      ),
                    ),
                  if (context.read<AuthController?>()?.user?['id'] == (j.ownerId ?? '') &&
                      context.read<EmployerCandidateMatchingRepository?>() != null)
                    const SizedBox(height: 6),
                  if (isJob &&
                      context.read<AuthController?>()?.user?['id'] ==
                          (j.ownerId ?? ''))
                    FutureBuilder<List<HopeCandidate>>(
                      future: _candidatesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              ),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return PremiumPanel(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const HopeIcon(HopeV2Icons.pending, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    HopeCopy.of(context)
                                        .copy_operation_failed_eb38c4c,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip:
                                      HopeCopy.of(context).copy_retry_49f3eba,
                                  onPressed: () => setState(() {
                                    _candidatesFuture =
                                        _controller.candidatesFuture;
                                  }),
                                  icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
                                ),
                              ],
                            ),
                          );
                        }
                        final list = snapshot.data ?? const <HopeCandidate>[];

                        if (list.isEmpty) {
                          return PremiumPanel(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _t(
                                'هنوز متقاضی‌ای برای نمایش وجود ندارد.',
                                'No candidates to display yet.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        }

                        return PremiumPanel(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      HopeCopy.of(context)
                                          .copy_forwarded_candidates_5de386c,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  if (list.length >= 2)
                                    OutlinedButton.icon(
                                      onPressed: _candidateBusyId == null
                                          ? () => _compareCandidates(list)
                                          : null,
                                      icon: const HugeIcon(icon: HopeV2Icons.insights, size: 18),
                                      label: Text(_t('مقایسه', 'Compare')),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...list.map<Widget>((candidate) {
                                final status = candidate.status;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 9),
                                  child: PremiumPanel(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const HopeIconTile(
                                              HopeV2Icons.userAdd,
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: Text(
                                                HopeCopy.of(
                                                  context,
                                                ).copy_anonymous_candidate_ba01a0d,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall,
                                              ),
                                            ),
                                            StatusPill(
                                              _candidateStatusLabel(status),
                                              icon: HopeV2Icons.pending,
                                              color: secondaryAccent(context),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 7),
                                        Text(candidate.skills),
                                        const SizedBox(height: 5),
                                        Text(
                                          candidate.resumeText,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 7,
                                          children: [
                                            if (status == 'FORWARDED')
                                              OutlinedButton.icon(
                                                onPressed: _candidateBusyId == null
                                                    ? () => _candidateAction(
                                                          candidate.id,
                                                          'interview',
                                                        )
                                                    : null,
                                                icon: _candidateBusyId ==
                                                        candidate.id
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const HugeIcon(
                                                        icon: HopeV2Icons.userAdd,
                                                        size: 18,
                                                      ),
                                                label: Text(
                                                  HopeCopy.of(context)
                                                      .copy_interview_9734f37,
                                                ),
                                              ),
                                            if (status == 'INTERVIEW')
                                              OutlinedButton.icon(
                                                onPressed: _candidateBusyId == null
                                                    ? () => _candidateAction(
                                                          candidate.id,
                                                          'offer',
                                                        )
                                                    : null,
                                                icon: _candidateBusyId ==
                                                        candidate.id
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const HugeIcon(
                                                        icon: HopeV2Icons.payments,
                                                        size: 18,
                                                      ),
                                                label: Text(
                                                  HopeCopy.of(context)
                                                      .copy_offer_cc3327c,
                                                ),
                                              ),
                                            if (status == 'OFFERED')
                                              FilledButton.icon(
                                                onPressed: _candidateBusyId == null
                                                    ? () => _candidateAction(
                                                          candidate.id,
                                                          'hire',
                                                        )
                                                    : null,
                                                icon: _candidateBusyId ==
                                                        candidate.id
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const HugeIcon(
                                                        icon: HopeV2Icons.completed,
                                                        size: 18,
                                                      ),
                                                label: Text(
                                                  HopeCopy.of(context)
                                                      .copy_hire_36ed063,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 13),
                  if (!isOwner)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _reportJob,
                        icon: const HugeIcon(icon: HopeV2Icons.notifications, size: 18),
                        label: Text(_t('گزارش فرصت', 'Report opportunity')),
                      ),
                    ),
                  if (canViewFinance)
                    PremiumPanel(
                      padding: const EdgeInsets.all(16),
                      highlight: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const HugeIcon(icon: HopeV2Icons.wallet, size: 20),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _t(
                                    'وضعیت مالی این کار',
                                    'Financial state for this work',
                                  ),
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _t(
                              'تأمین وجه، نگهداری، تحویل، تأیید و تسویه را از یک مسیر دنبال کنید.',
                              'Track funding, hold, delivery, approval, and settlement from one flow.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              HopeRoutes.transaction(
                                repository:
                                    context.read<TransactionRepository>(),
                                uploadQueue: context.read<UploadQueue>(),
                                jobId: j.id,
                              ),
                            ),
                            icon: const HopeIcon(HopeV2Icons.arrowRight, size: 19),
                            label: Text(
                              HopeCopy.of(context)
                                  .copy_view_transaction_a91f1e6,
                            ),
                          ),
                          if (j.status?.toUpperCase() == 'COMPLETED') ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                HopeRoutes.jobSatisfaction(j.id),
                              ),
                              icon: const HopeIcon(
                                HopeV2Icons.completed,
                                size: 19,
                              ),
                              label: Text(
                                _t(
                                  'گزارش رضایت و تسویه خودکار',
                                  'Satisfaction report & auto settlement',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (collaborationChatOpen)
                    PremiumPanel(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const HugeIcon(icon: HopeV2Icons.message, size: 21),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _t('گفتگوی مستقیم دو طرف کار', 'Direct work chat'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.push(context, HopeRoutes.jobChat(j.id)),
                            child: Text(_t('گفتگو', 'Chat')),
                          ),
                        ],
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _line(
    BuildContext context,
    Object icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          HopeIcon(icon, size: 19, color: AppColors.primary, strokeWidth: 1.9),
          const SizedBox(width: 9),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobLifecycleCard extends StatelessWidget {
  const _JobLifecycleCard({required this.job});
  final HopeJob job;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  int _current() {
    const stages = [
      'DRAFT',
      'PUBLISHED',
      'FUNDED',
      'IN_PROGRESS',
      'DELIVERED',
      'UNDER_REVIEW',
      'COMPLETED',
    ];
    final status = job.status?.toUpperCase();
    final index = stages.indexOf(status ?? '');
    if (index >= 0) return index;
    return -1;
  }

  String _label(BuildContext context, String status) => switch (status) {
        'DRAFT' => _t(context, 'پیش‌نویس', 'Draft'),
        'PUBLISHED' => _t(context, 'منتشر شده', 'Published'),
        'FUNDED' => _t(context, 'تأمین وجه شده', 'Funded'),
        'IN_PROGRESS' => _t(context, 'در حال انجام', 'In progress'),
        'DELIVERED' => _t(context, 'تحویل شده', 'Delivered'),
        'UNDER_REVIEW' => _t(context, 'در حال بررسی', 'Under review'),
        'COMPLETED' => _t(context, 'تکمیل شده', 'Completed'),
        'CANCELLED' => _t(context, 'لغو شده', 'Cancelled'),
        _ => _t(context, 'نیازمند بررسی', 'Needs review'),
      };

  @override
  Widget build(BuildContext context) {
    const stages = [
      'DRAFT',
      'PUBLISHED',
      'FUNDED',
      'IN_PROGRESS',
      'DELIVERED',
      'UNDER_REVIEW',
      'COMPLETED',
    ];
    final current = _current();
    final status = job.status?.toUpperCase() ?? 'UNKNOWN';

    return PremiumPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HopeIconTile(HopeV2Icons.route, filled: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t(context, 'چرخه عمر فرصت', 'Opportunity lifecycle'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusPill(
                _label(context, status),
                icon: HopeV2Icons.pending,
                color: status == 'CANCELLED'
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(stages.length, (index) {
            final reached = current >= index;
            final active = current == index;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: active ? 14 : 11,
                        height: active ? 14 : 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: reached
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      if (index < stages.length - 1)
                        Container(
                          width: 2,
                          height: 25,
                          color: reached && current > index
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Text(
                      _label(context, stages[index]),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w500,
                          ),
                    ),
                  ),
                ),
              ],
            );
          }),
          if (status == 'CANCELLED')
            Text(
              _t(
                context,
                'این فرصت لغو شده است.',
                'This opportunity is cancelled.',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _MatchIntelligence extends StatelessWidget {
  const _MatchIntelligence({required this.job});
  final HopeJob job;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _reason(BuildContext context, String value) {
    const fa = {
      'SKILL_MATCH': 'مهارت مرتبط',
      'CATEGORY_MATCH': 'دسته‌بندی مرتبط',
      'VERY_NEAR': 'خیلی نزدیک',
      'NEARBY': 'نزدیک',
      'REMOTE': 'قابل انجام آنلاین',
      'WORK_MODE_MATCH': 'نوع همکاری مناسب',
      'SALARY_FIT': 'تناسب درآمد',
      'BEHAVIOR_MATCH': 'متناسب با ترجیحات',
      'GENERAL_MATCH': 'تناسب کلی',
    };
    const en = {
      'SKILL_MATCH': 'Skill match',
      'CATEGORY_MATCH': 'Category match',
      'VERY_NEAR': 'Very near',
      'NEARBY': 'Nearby',
      'REMOTE': 'Remote',
      'WORK_MODE_MATCH': 'Work mode fit',
      'SALARY_FIT': 'Salary fit',
      'BEHAVIOR_MATCH': 'Preference fit',
      'GENERAL_MATCH': 'General fit',
    };
    return (Localizations.localeOf(context).languageCode == 'en'
            ? en[value]
            : fa[value]) ??
        value;
  }

  @override
  Widget build(BuildContext context) {
    final score = job.recommendationScore;
    final primary = Theme.of(context).colorScheme.primary;
    final value = score == null ? 0.0 : (score / 100).clamp(0.0, 1.0);

    return Semantics(
      button: true,
      label: _t(
        context,
        'جزئیات تطبیق این فرصت',
        'Match details for this opportunity',
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HopeV2Radii.lg),
          onTap: () => _showDetails(context),
          child: PremiumPanel(
            padding: const EdgeInsets.all(16),
            highlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (score != null)
                      SizedBox(
                        width: 82,
                        height: 82,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 82,
                              child: CircularProgressIndicator(
                                value: 1,
                                strokeWidth: 7,
                                color: primary.withValues(alpha: .12),
                              ),
                            ),
                            SizedBox.square(
                              dimension: 82,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                color: primary,
                              ),
                            ),
                            Text(
                              '${score.clamp(0, 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 20,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (score != null) const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const HopeIcon(
                                HopeV2Icons.featured,
                                color: HopeV2Colors.primaryDark,
                                size: 19,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  _t(context, 'هوش تطبیق', 'Match intelligence'),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _t(
                              context,
                              'سیگنال‌های توصیه برای این فرصت',
                              'Recommendation signals for this opportunity',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _t(context, 'جزئیات را ببینید', 'See details'),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (job.recommendationReasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: job.recommendationReasons
                        .take(4)
                        .map(
                          (r) => StatusPill(
                            _reason(context, r),
                            color: primary,
                            icon: HopeV2Icons.completed,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final score = job.recommendationScore;
    final primary = Theme.of(context).colorScheme.primary;
    final value = score == null ? 0.0 : (score / 100).clamp(0.0, 1.0);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                _t(
                  context,
                  'چرا این فرصت مناسب است؟',
                  'Why this opportunity fits',
                ),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 16),
              PremiumPanel(
                highlight: true,
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (score != null)
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 88,
                              child: CircularProgressIndicator(
                                value: 1,
                                strokeWidth: 7,
                                color: primary.withValues(alpha: .12),
                              ),
                            ),
                            SizedBox.square(
                              dimension: 88,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                color: primary,
                              ),
                            ),
                            Text(
                              '${score.clamp(0, 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (score != null) const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _t(
                          context,
                          'این امتیاز فقط از سیگنال‌های توصیه موجود برای همین فرصت استفاده می‌کند.',
                          'This score uses only the recommendation signals available for this opportunity.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (job.recommendationReasons.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _t(context, 'سیگنال‌های تطبیق', 'Match signals'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 9),
                ...job.recommendationReasons.take(6).map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PremiumPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const HopeIcon(
                            HopeV2Icons.completed,
                            color: HopeV2Colors.success,
                            size: 18,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _reason(context, reason),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _EmployerCandidateMatchesLoader extends StatelessWidget {
  const _EmployerCandidateMatchesLoader({
    required this.future,
    required this.jobTitle,
  });

  final Future<HopeEmployerCandidateMatchList> future;
  final String jobTitle;
  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Scaffold(
      body: PremiumPageFrame(
        maxWidth: 1180,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        child: FutureBuilder<HopeEmployerCandidateMatchList>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HopeAsyncState(
                kind: HopeStateKind.loading,
                title: english ? 'Loading matches' : 'در حال بارگذاری انطباق',
                message: english
                    ? 'Compatibility signals are being prepared.'
                    : 'شاخص‌های انطباق در حال آماده‌سازی هستند.',
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return ListView(
                children: [
                  PremiumHeader(
                    domain: HopeProductDomain.intelligence,
                    eyebrow: english ? 'MATCH INTELLIGENCE' : 'هوشمندی تطبیق',
                    title: english
                        ? 'Applicant compatibility'
                        : 'انطباق متقاضیان',
                    subtitle: english
                        ? 'Compatibility is a separate intelligence surface from opportunity details.'
                        : 'انطباق متقاضیان یک سطح مستقل از جزئیات فرصت است.',
                    trailing: PremiumIconButton(
                      icon: english
                          ? HopeV2Icons.arrowLeft
                          : HopeV2Icons.arrowRight,
                      tooltip: english ? 'Back' : 'بازگشت',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                  const SizedBox(height: HopeV2Spacing.lg),
                  EmptyState(
                    icon: HopeV2Icons.error,
                    title: english
                        ? 'Could not load matches'
                        : 'بارگذاری انطباق ناموفق بود',
                    message: english
                        ? 'Compatibility data is temporarily unavailable.'
                        : 'داده‌های انطباق موقتاً در دسترس نیست.',
                    action: OutlinedButton.icon(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const HopeIcon(HopeV2Icons.arrowRight, size: 18),
                      label: Text(english ? 'Back' : 'بازگشت'),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: EmployerCandidateMatchesPage(
                    data: snapshot.data!,
                    onRetry: () {},
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}