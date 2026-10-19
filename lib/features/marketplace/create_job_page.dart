import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/marketplace/category.dart';
import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_signature_components.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/ui/hope_feedback.dart';
import 'create_job_payload.dart';

import '../../core/theme/app_theme.dart';

part 'create_job_widgets.part.dart';

ApplicationRegistry _applicationRegistry(BuildContext context) => applicationRegistryOf(context);

class CreateJobPage extends StatefulWidget {
  const CreateJobPage({super.key});

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage> {
  final title = TextEditingController();
  final desc = TextEditingController();
  final min = TextEditingController();
  final max = TextEditingController();
  final duration = TextEditingController(text: '8');
  final salary = TextEditingController();
  final deadline = TextEditingController();
  final accept = TextEditingController();

  bool busy = false;
  String? _pendingPublishId;
  int activeStep = 0;
  String kind = 'MISSION';
  String visibility = 'PUBLIC';
  String schedule = 'FULL_TIME';
  String city = '';
  String? categoryId;

  late Future<List<HopeCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    city = context.read<HopeSettingsController>().city;
    _categoriesFuture = _loadCategories();
  }

  Future<List<HopeCategory>> _loadCategories() =>
      _applicationRegistry(context).listCategories();

  @override
  void dispose() {
    for (final controller in [
      title,
      desc,
      min,
      max,
      duration,
      salary,
      deadline,
      accept,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    // A stale/double-activated callback must not duplicate create + publish.
    if (busy || _pendingPublishId != null) return;
    final effectiveMin = kind == 'JOB' ? salary.text : min.text;
    final effectiveMax = kind == 'JOB' ? salary.text : max.text;
    final selectedCategory = categoryId;
    if (selectedCategory == null || selectedCategory.isEmpty) {
      HopeFeedback.show(
        context,
        HopeCopy.of(context).copy_choose_a_professional_category_b4cf5b8,
        tone: HopeFeedbackTone.warning,
        bottomClearance: 112,
      );
      return;
    }
    final input = CreateJobPayloadInput(
      title: title.text,
      description: desc.text,
      categoryId: selectedCategory,
      minBudget: effectiveMin,
      maxBudget: effectiveMax,
      duration: duration.text,
      acceptanceCriteria: accept.text,
      city: city.isEmpty ? context.read<HopeSettingsController>().city : city,
      kind: kind,
      visibility: visibility,
      schedule: schedule,
      monthlySalary: salary.text,
      applicationDeadline: deadline.text,
    );
    final validation = validateCreateOpportunity(
      input: input,
      defaultAcceptanceCriteria:
          HopeCopy.of(context).copy_as_described_in_the_opportunity_836cb3e,
    );
    if (!validation.isValid) {
      HopeFeedback.show(
        context,
        validation.error!,
        tone: HopeFeedbackTone.warning,
        bottomClearance: 112,
      );
      return;
    }
    if (kind == 'JOB' && deadline.text.trim().isEmpty) {
      HopeFeedback.show(
        context,
        HopeCopy.of(context).copy_set_an_application_deadline_for_jobs_5fd80f8,
        tone: HopeFeedbackTone.warning,
        bottomClearance: 112,
      );
      return;
    }
    setState(() => busy = true);
    String? createdOpportunityId;
    try {
      final body = buildCreateOpportunityPayload(CreateJobPayloadInput(
        title: title.text,
        description: desc.text,
        categoryId: selectedCategory,
        minBudget: effectiveMin,
        maxBudget: effectiveMax,
        duration: duration.text,
        acceptanceCriteria: accept.text.trim().isEmpty
            ? HopeCopy.of(context).copy_as_described_in_the_opportunity_836cb3e
            : accept.text,
        city: city.isEmpty ? context.read<HopeSettingsController>().city : city,
        kind: kind,
        visibility: visibility,
        schedule: schedule,
        monthlySalary: salary.text,
        applicationDeadline: deadline.text,
      ));
      final useCase = _applicationRegistry(context).createOpportunity;
      final created = await useCase(body);
      createdOpportunityId = created.id;
      // Lock the created record before awaiting publication.
      if (mounted) setState(() => _pendingPublishId = created.id);
      await useCase.publish(created.id);
      if (!mounted) return;
      HopeFeedback.show(context, HopeCopy.of(context).copy_opportunity_published_81a9fd1, tone: HopeFeedbackTone.success);
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final pendingId = createdOpportunityId;
      if (pendingId != null &&
          pendingId.trim().isNotEmpty &&
          _pendingPublishId != pendingId) {
        setState(() => _pendingPublishId = pendingId);
      }
      HopeFeedback.show(context, apiErrorMessage(error, fallback: HopeCopy.of(context).copy_the_server_did_not_return_data_try_again_bccfbb3), tone: HopeFeedbackTone.error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> retryPendingPublication() async {
    if (busy) return;
    final pendingId = _pendingPublishId;
    if (pendingId == null || pendingId.trim().isEmpty) return;

    setState(() => busy = true);
    try {
      await _applicationRegistry(context).createOpportunity.publish(pendingId);
      if (!mounted) return;
      _pendingPublishId = null;
      HopeFeedback.show(
        context,
        HopeCopy.of(context).copy_opportunity_published_81a9fd1,
        tone: HopeFeedbackTone.success,
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      HopeFeedback.show(
        context,
        apiErrorMessage(
          error,
          fallback: HopeCopy.of(context)
              .copy_the_server_did_not_return_data_try_again_bccfbb3,
        ),
        tone: HopeFeedbackTone.error,
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDate: now,
      helpText: _t('مهلت ارسال درخواست', 'Application deadline'),
    );
    if (picked == null || !mounted) return;
    deadline.text = DateFormat('yyyy-MM-dd').format(picked);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shortViewport = MediaQuery.sizeOf(context).height < 420;
    return Scaffold(
      body: PremiumPageFrame(
        maxWidth: 980,
        padding: EdgeInsets.fromLTRB(
          16,
          shortViewport ? 4 : 8,
          16,
          shortViewport ? 8 : 20,
        ),
        child: SizedBox.expand(
          child: Column(
            children: [
              PremiumHeader(
                dense: true,
                page: HopePageId.createOpportunity,
                domain: HopeProductDomain.work,
                eyebrow: shortViewport
                    ? ''
                    : HopeCopy.of(context).copy_post_a_new_opportunity_f7fe3d9,
                title: _t('ثبت فرصت جدید', 'Post an opportunity'),
                subtitle: shortViewport
                    ? null
                    : _t(
                        'نوع فرصت، مشخصات، مبلغ و شرایط را مشخص کنید.',
                        'Set the opportunity type, details, budget, and requirements.',
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PremiumIconButton(
                      icon: Localizations.localeOf(context).languageCode == 'en'
                          ? HopeV2Icons.arrowLeft
                          : HopeV2Icons.arrowRight,
                      tooltip: _t('بازگشت', 'Back'),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 8),
                    const HopeIconTile(
                      HopeV2Icons.add,
                      size: 42,
                      filled: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: shortViewport ? 2 : HopeV2Spacing.sm),
              Expanded(
                child: _pendingPublishId == null
                    ? _CreateJobForm(
                  title: title,
                  description: desc,
                  minBudget: min,
                  maxBudget: max,
                  duration: duration,
                  salary: salary,
                  deadline: deadline,
                  acceptanceCriteria: accept,
                  busy: busy,
                  activeStep: activeStep,
                  onStepChanged: (step) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => activeStep = step.clamp(0, 4));
                  },
                  kind: kind,
                  visibility: visibility,
                  schedule: schedule,
                  city: city,
                  categoryId: categoryId,
                  categoriesFuture: _categoriesFuture,
                  onKindChanged: (value) => setState(() => kind = value),
                  onVisibilityChanged: (value) =>
                      setState(() => visibility = value),
                  onScheduleChanged: (value) =>
                      setState(() => schedule = value),
                  onCityChanged: (value) => setState(() => city = value),
                  onCategoryChanged: (value) =>
                      setState(() => categoryId = value),
                  onRetryCategories: () =>
                      setState(() => _categoriesFuture = _loadCategories()),
                  onPickDeadline: _pickDeadline,
                  onSubmit: submit,
                  translate: _t,
                      )
                    : _CreatePublishRetryState(
                        busy: busy,
                        onRetry: retryPendingPublication,
                        translate: _t,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatePublishRetryState extends StatelessWidget {
  const _CreatePublishRetryState({
    required this.busy,
    required this.onRetry,
    required this.translate,
  });

  final bool busy;
  final Future<void> Function() onRetry;
  final String Function(String, String) translate;

  @override
  Widget build(BuildContext context) => ListView(
        key: const ValueKey('create-opportunity-publish-retry-state'),
        padding: HopeV2Navigation.scrollEndPadding(
          context,
          horizontal: 20,
          top: 16,
        ),
        children: [
          PremiumPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: HopeIconTile(
                    HopeV2Icons.pending,
                    size: 52,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  translate(
                    'فرصت ثبت شد؛ انتشار تکمیل نشد',
                    'Opportunity created; publication incomplete',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  translate(
                    'فرصت یک بار ایجاد شده است. برای جلوگیری از ثبت تکراری، اطلاعات فرم قفل شده و تلاش دوباره فقط همین فرصت را منتشر می‌کند.',
                    'The opportunity has already been created. To avoid a duplicate, its details are locked and retry will publish this same opportunity only.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey('create-opportunity-retry-publish'),
                  onPressed: busy ? null : () => onRetry(),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const HopeIcon( HopeV2Icons.refresh,
                          size: 18,
                        ),
                  label: Text(
                    busy
                        ? translate('در حال انتشار...', 'Publishing...')
                        : translate('تلاش دوباره برای انتشار', 'Retry publication'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

