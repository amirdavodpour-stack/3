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
    final effectiveMin = kind == 'JOB' ? salary.text : min.text;
    final effectiveMax = kind == 'JOB' ? salary.text : max.text;
    final selectedCategory = categoryId;
    if (selectedCategory == null || selectedCategory.isEmpty) {
      HopeFeedback.show(context, HopeCopy.of(context).copy_choose_a_professional_category_b4cf5b8, tone: HopeFeedbackTone.warning);
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
      HopeFeedback.show(context, validation.error!, tone: HopeFeedbackTone.warning);
      return;
    }
    if (kind == 'JOB' && deadline.text.trim().isEmpty) {
      HopeFeedback.show(context, HopeCopy.of(context).copy_set_an_application_deadline_for_jobs_5fd80f8, tone: HopeFeedbackTone.warning);
      return;
    }
    setState(() => busy = true);
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
      await useCase.publish(created.id);
      if (!mounted) return;
      HopeFeedback.show(context, HopeCopy.of(context).copy_opportunity_published_81a9fd1, tone: HopeFeedbackTone.success);
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      HopeFeedback.show(context, apiErrorMessage(error, fallback: HopeCopy.of(context).copy_the_server_did_not_return_data_try_again_bccfbb3), tone: HopeFeedbackTone.error);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          HopeCopy.of(context).copy_post_a_new_opportunity_f7fe3d9,
        ),
      ),
      body: PremiumPageFrame(
        maxWidth: 980,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 72),
        child: SizedBox.expand(
          child: Column(
            children: [
              PremiumHeader(
                eyebrow: HopeCopy.of(context).copy_post_a_new_opportunity_f7fe3d9,
                title: _t('ثبت فرصت جدید', 'Post an opportunity'),
                subtitle: _t(
                  'نوع فرصت، مشخصات، مبلغ و شرایط را مشخص کنید.',
                  'Set the opportunity type, details, budget, and requirements.',
                ),
                trailing: const HopeIconTile(
                  HopeV2Icons.add,
                  size: 52,
                  filled: true,
                ),
              ),
              const SizedBox(height: HopeV2Spacing.lg),
              Expanded(
                child: _CreateJobForm(
                  title: title,
                  description: desc,
                  minBudget: min,
                  maxBudget: max,
                  duration: duration,
                  salary: salary,
                  deadline: deadline,
                  acceptanceCriteria: accept,
                  busy: busy,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
