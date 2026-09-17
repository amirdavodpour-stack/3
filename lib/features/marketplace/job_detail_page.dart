import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/application/application_registry_context.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/marketplace/application.dart';
import '../../core/marketplace/job.dart';
import '../../core/marketplace/job_detail_controller.dart';
import '../../core/marketplace/job_detail_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/router/app_routes.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/storage/secure_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/transactions/payment.dart';
import '../../core/transactions/transaction_repository.dart';
import '../../core/ui/components.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/ui/premium_components.dart';
import '../../core/uploads/upload_queue.dart';

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({super.key, required this.job});

  final HopeJob job;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  late final JobDetailController _controller;
  late Future<List<HopeCandidate>> _candidatesFuture;
  String? _candidateBusyId;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _controller = JobDetailController(
      job: widget.job,
      repository: context.read<JobDetailRepository>(),
    );
    _candidatesFuture = _controller.candidatesFuture;
  }

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  Future<void> _applyOrOffer() async {
    if (loading) return;
    if (widget.job.isJob) {
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
                HopeCopy.of(context).copy_apply_for_this_job_3a75a03,
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
                  labelText: HopeCopy.of(context).copy_resume_94f1a74,
                  prefixIcon: const Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: skills,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: HopeCopy.of(context).copy_skills_f9d9ce1,
                  prefixIcon: const Icon(Icons.auto_awesome_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(
                    context,
                    [resume.text.trim(), skills.text.trim()],
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: Text(
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
      if (values == null) return;
      if (submittedResume.length < 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(HopeCopy.of(context)
                .copy_add_a_concise_resume_and_relevant_skills_298a4f1),
          ));
        }
        return;
      }
      if (!context.mounted) return;
      setState(() => loading = true);
      try {
        await _controller.apply(
          resumeText: values.isNotEmpty ? values[0] : submittedResume,
          skills: values.length > 1 ? values[1] : submittedSkills,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(HopeCopy.of(context)
                .copy_your_application_was_sent_for_admin_review_5d9c43a),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(apiErrorMessage(e,
                fallback: HopeCopy.of(context).copy_operation_failed_eb38c4c)),
          ));
        }
      } finally {
        if (mounted) setState(() => loading = false);
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
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: 'TOMAN',
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
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                [price.text, message.text],
              ),
              child: Text(HopeCopy.of(context).copy_send_offer_8aa1351),
            ),
          ],
        ),
      ),
    );
    final submittedPrice =
        result?.isNotEmpty == true ? result![0] : price.text;
    final submittedMessage =
        result != null && result.length > 1 ? result[1] : message.text;
    price.dispose();
    message.dispose();
    if (result == null) return;
    final offerPrice = submittedPrice.trim();
    if (!RegExp(r'^\d+$').hasMatch(offerPrice) ||
        BigInt.tryParse(offerPrice) == null ||
        BigInt.parse(offerPrice) <= BigInt.zero ||
        BigInt.parse(offerPrice) > BigInt.from(9000000000000000)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(HopeCopy.of(context).copy_operation_failed_eb38c4c),
        ));
      }
      return;
    }
    if (!context.mounted) return;
    setState(() => loading = true);
    try {
      await _controller.sendOffer(
        price: offerPrice,
        message: submittedMessage.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(HopeCopy.of(context).copy_your_offer_was_submitted_75e3409),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e,
              fallback: HopeCopy.of(context).copy_operation_failed_eb38c4c)),
        ));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _candidateAction(String candidateId, String action) async {
    if (_candidateBusyId != null) return;
    setState(() => _candidateBusyId = candidateId);
    try {
      await _controller.candidateAction(candidateId, action);
      if (mounted) {
        setState(() => _candidatesFuture = _controller.candidatesFuture);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(apiErrorMessage(error,
            fallback: HopeCopy.of(context).copy_operation_failed_eb38c4c)),
      ));
    } finally {
      if (mounted) setState(() => _candidateBusyId = null);
    }
  }

  Future<void> _compareCandidates(List<HopeCandidate> candidates) async {
    final selected = candidates.take(5).toList(growable: false);
    if (selected.length < 2) return;
    try {
      final result = await context.read<JobDetailRepository>().compareCandidates(
            widget.job.id,
            selected.map((c) => c.id).toList(),
          );
      if (!context.mounted) return;
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
                  ? Text(_t(
                      'داده‌ای برای مقایسه برنگشت.',
                      'No comparison data returned.',
                    ))
                  : Column(
                      children: rows
                          .map(
                            (row) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: HopeSurface(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _t(
                                          'متقاضی ناشناس', 'Anonymous candidate'),
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .titleSmall,
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
                                      '${row['status'] ?? '—'}',
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .bodySmall,
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(apiErrorMessage(
          e,
          fallback: _t('مقایسه ناموفق بود.', 'Comparison failed.'),
        )),
      ));
    }
  }

  Future<void> _reportJob() async {
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
            onPressed: () =>
                Navigator.pop(ctx, reason.text.trim().length >= 3),
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
      await context.read<JobDetailRepository>().reportJob(
            widget.job.id,
            reason: r,
            details: d,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('گزارش ثبت شد.', 'Report submitted.')),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isJob
              ? HopeCopy.of(context).copy_job_details_e815855
              : HopeCopy.of(context).copy_mission_details_78d58d8,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Center(
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
                          : _applyOrOffer,
                  icon: Icon(
                    canViewFinance
                        ? Icons.account_balance_wallet_rounded
                        : isJob
                            ? Icons.send_rounded
                            : Icons.bolt_rounded,
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1180,
                minHeight: constraints.maxHeight,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: SizedBox(
                      height: 175,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/hope_marketplace_hero.png',
                            fit: BoxFit.cover,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: .65),
                                ],
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            start: 16,
                            bottom: 16,
                            end: 16,
                            child: Text(
                              j.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      StatusPill(
                        isJob
                            ? HopeCopy.of(context).copy_job_ce2feba
                            : HopeCopy.of(context).copy_mission_fb4c5e1,
                        color:
                            isJob ? secondaryAccent(context) : AppColors.primary,
                        icon: isJob
                            ? Icons.business_center_rounded
                            : Icons.bolt_rounded,
                      ),
                      StatusPill(
                        visibility == 'SPECIALIZED'
                            ? HopeCopy.of(context).copy_specialized_5d1ca04
                            : HopeCopy.of(context).copy_public_21e97be,
                        color: visibility == 'SPECIALIZED'
                            ? AppColors.warning
                            : secondaryAccent(context),
                        icon: Icons.visibility_outlined,
                      ),
                      if (j.city != null)
                        StatusPill(
                          j.city!,
                          color: AppColors.muted,
                          icon: Icons.location_on_outlined,
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
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
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
                          icon: Icons.payments_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricTile(
                          label: HopeCopy.of(context).copy_field_fcb7b26,
                          value: j.category ?? j.categoryId ?? '—',
                          icon: Icons.category_outlined,
                          color: secondaryAccent(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  HopeSurface(
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
                            Icons.schedule_rounded,
                            HopeCopy.of(context).copy_schedule_3af1939,
                            j.schedule == 'PART_TIME'
                                ? HopeCopy.of(context).copy_part_time_086787b
                                : HopeCopy.of(context).copy_full_time_1e4bd4e,
                          ),
                          _line(
                            context,
                            Icons.event_outlined,
                            HopeCopy.of(context)
                                .copy_application_deadline_0a6c25c,
                            j.applicationDeadline ?? '—',
                          ),
                        ],
                        if (!isJob)
                          _line(
                            context,
                            Icons.timelapse_rounded,
                            HopeCopy.of(context).copy_duration_cc42be6,
                            '${j.duration ?? '—'} ${HopeCopy.of(context).copy_hours_7408608}',
                          ),
                        _line(
                          context,
                          Icons.fact_check_outlined,
                          HopeCopy.of(context).copy_acceptance_criteria_f213cb2,
                          j.acceptanceCriteria ?? '—',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  _JobLifecycleCard(job: j),
                  const SizedBox(height: 13),
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
                          return HopeSurface(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    HopeCopy.of(context)
                                        .copy_operation_failed_eb38c4c,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: HopeCopy.of(context).copy_retry_49f3eba,
                                  onPressed: () => setState(() {
                                    _candidatesFuture =
                                        _controller.candidatesFuture;
                                  }),
                                  icon: const Icon(Icons.refresh_rounded),
                                ),
                              ],
                            ),
                          );
                        }
                        final list =
                            snapshot.data ?? const <HopeCandidate>[];
                        if (list.isEmpty) {
                          return HopeSurface(
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
                        return HopeSurface(
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
                                      onPressed: () =>
                                          _compareCandidates(list),
                                      icon: const Icon(
                                        Icons.compare_arrows_rounded,
                                        size: 18,
                                      ),
                                      label: Text(_t('مقایسه', 'Compare')),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...list.map<Widget>((candidate) {
                                final status = candidate.status;
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 9),
                                  child: HopeSurface(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const HopeIconTile(
                                              Icons.person_search_rounded,
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: Text(
                                                HopeCopy.of(context)
                                                    .copy_anonymous_candidate_ba01a0d,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall,
                                              ),
                                            ),
                                            StatusPill(
                                              _candidateStatusLabel(status),
                                              icon: Icons.flag_outlined,
                                              color:
                                                  secondaryAccent(context),
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
                                                onPressed: _candidateBusyId ==
                                                        candidate.id
                                                    ? null
                                                    : () => _candidateAction(
                                                        candidate.id,
                                                        'interview'),
                                                icon: _candidateBusyId ==
                                                        candidate.id
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2),
                                                      )
                                                    : const Icon(
                                                        Icons.forum_outlined,
                                                        size: 18,
                                                      ),
                                                label: Text(
                                                  HopeCopy.of(context)
                                                      .copy_interview_9734f37,
                                                ),
                                              ),
                                            if (status == 'INTERVIEW')
                                              OutlinedButton.icon(
                                                onPressed: _candidateBusyId ==
                                                        candidate.id
                                                    ? null
                                                    : () => _candidateAction(
                                                        candidate.id, 'offer'),
                                                icon: _candidateBusyId ==
                                                        candidate.id
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2),
                                                      )
                                                    : const Icon(
                                                        Icons.request_quote_outlined,
                                                        size: 18,
                                                      ),
                                                label: Text(
                                                  HopeCopy.of(context)
                                                      .copy_offer_cc3327c,
                                                ),
                                              ),
                                            if (status == 'OFFERED')
                                              FilledButton.icon(
                                                onPressed: _candidateBusyId ==
                                                        candidate.id
                                                    ? null
                                                    : () => _candidateAction(
                                                        candidate.id, 'hire'),
                                                icon: _candidateBusyId ==
                                                        candidate.id
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2),
                                                      )
                                                    : const Icon(
                                                        Icons.verified_rounded,
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
                        icon: const Icon(Icons.flag_outlined),
                        label: Text(_t('گزارش فرصت', 'Report opportunity')),
                      ),
                    ),
                  if (canViewFinance)
                    HopeSurface(
                      padding: const EdgeInsets.all(16),
                      highlight: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                  Icons.account_balance_wallet_rounded),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _t('وضعیت مالی این کار',
                                      'Financial state for this work'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(_t(
                            'تأمین وجه، نگهداری، تحویل، تأیید و تسویه را از یک مسیر دنبال کنید.',
                            'Track funding, hold, delivery, approval, and settlement from one flow.',
                          )),
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
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: Text(HopeCopy.of(context)
                                .copy_view_transaction_a91f1e6),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _line(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _candidateStatusLabel(String status) => switch (status) {
        'FORWARDED' => _t('ارجاع‌شده', 'Forwarded'),
        'INTERVIEW' => _t('مصاحبه', 'Interview'),
        'OFFERED' => _t('پیشنهاد', 'Offered'),
        'HIRED' => _t('استخدام‌شده', 'Hired'),
        _ => status,
      };
}
