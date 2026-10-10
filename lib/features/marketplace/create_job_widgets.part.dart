part of 'create_job_page.dart';

class _TypeHero extends StatelessWidget {
  const _TypeHero({required this.kind, required this.onChanged});

  final String kind;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    return PremiumPanel(
      highlight: true,
      padding: EdgeInsets.all(compact ? 12 : 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  HopeCopy.of(context)
                      .copy_first_choose_what_kind_of_opportunity_you__f035ca9,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),

            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = [
                _tile(
                  context,
                  'MISSION',
                  HopeV2Icons.mission,
                  HopeCopy.of(context).copy_mission_fb4c5e1,
                  HopeCopy.of(context)
                      .copy_a_defined_task_with_defined_pay_77b1068,
                ),
                _tile(
                  context,
                  'JOB',
                  HopeV2Icons.job,
                  HopeCopy.of(context).copy_job_ce2feba,
                  HopeCopy.of(context)
                      .copy_part_full_time_with_monthly_pay_abd5afd,
                ),
              ];

              // Keep both opportunity types side-by-side on normal phone widths.
              // Stack only for genuinely narrow embedded surfaces.
              if (constraints.maxWidth < 240) {
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
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    String value,
    Object icon,
    String title,
    String sub,
  ) {
    final compact = MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final selected = kind == value;

    return PressableScale(
      onTap: () => onChanged(value),
      semanticLabel: '$title. $sub',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HopeV2Radii.md),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : HopeV2Surfaces.panel(context),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .35)
                : Theme.of(context).dividerColor.withValues(alpha: .75),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(compact ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HopeIcon(
                    icon,
                    color: selected ? Theme.of(context).colorScheme.onPrimaryContainer : AppColors.primary,
                    size: compact ? 22 : 25,
                    strokeWidth: 2.0,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: selected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: selected ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: .78) : null,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final Object icon;
  final String title;
  final String sub;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => onSelected(value),
      semanticLabel: '$title. $sub',
      child: PremiumPanel(
        highlight: selected,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            HopeIconTile(
              icon,
              filled: selected,
              size: 42,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    sub,
                    style: Theme.of(context).textTheme.bodyMedium,
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


class _CreateJobForm extends StatelessWidget {
  const _CreateJobForm({
    required this.title,
    required this.description,
    required this.minBudget,
    required this.maxBudget,
    required this.duration,
    required this.salary,
    required this.deadline,
    required this.acceptanceCriteria,
    required this.busy,
    required this.activeStep,
    required this.onStepChanged,
    required this.kind,
    required this.visibility,
    required this.schedule,
    required this.city,
    required this.categoryId,
    required this.categoriesFuture,
    required this.onKindChanged,
    required this.onVisibilityChanged,
    required this.onScheduleChanged,
    required this.onCityChanged,
    required this.onCategoryChanged,
    required this.onRetryCategories,
    required this.onPickDeadline,
    required this.onSubmit,
    required this.translate,
  });

  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController minBudget;
  final TextEditingController maxBudget;
  final TextEditingController duration;
  final TextEditingController salary;
  final TextEditingController deadline;
  final TextEditingController acceptanceCriteria;
  final bool busy;
  final int activeStep;
  final ValueChanged<int> onStepChanged;
  final String kind;
  final String visibility;
  final String schedule;
  final String city;
  final String? categoryId;
  final Future<List<HopeCategory>> categoriesFuture;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<String> onScheduleChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onRetryCategories;
  final Future<void> Function() onPickDeadline;
  final Future<void> Function() onSubmit;
  final String Function(String, String) translate;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final compact = MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final sectionGap = compact ? 12.0 : 20.0;
    return ListView(
        key: ValueKey('create-opportunity-step-$activeStep'),
        padding: HopeV2Navigation.scrollEndPadding(
          context,
          horizontal: 20,
          top: 6,
        ),
        children: [
          HopeCreationProgress(activeIndex: activeStep),
          const SizedBox(height: 2),
          if (activeStep == 0) ...[
          _TypeHero(
            kind: kind,
            onChanged: onKindChanged,
          ),
          const SizedBox(height: 12),
          PremiumSectionHeader(
            domain: HopeProductDomain.work,
            title: HopeCopy.of(context).copy_audience_visibility_5a0ddcb,
            subtitle:
                HopeCopy.of(context).copy_make_it_public_or_specialized_e890215,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _VisibilityCard(
                  icon: HopeV2Icons.insights,
                  title: HopeCopy.of(context).copy_public_21e97be,
                  sub: HopeCopy.of(context).copy_for_everyone_ebc769c,
                  value: 'PUBLIC',
                  selected: visibility == 'PUBLIC',
                  onSelected: onVisibilityChanged,
                ),
                _VisibilityCard(
                  icon: HopeV2Icons.featured,
                  title: HopeCopy.of(context).copy_specialized_5d1ca04,
                  sub: HopeCopy.of(context).copy_for_a_specific_field_9b79bd6,
                  value: 'SPECIALIZED',
                  selected: visibility == 'SPECIALIZED',
                  onSelected: onVisibilityChanged,
                ),
              ];

              if (constraints.maxWidth < 360) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 10),
                    cards[1],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[1]),
                ],
              );
            },
          ),
          ],
          if (activeStep == 1) ...[
          SizedBox(height: sectionGap),
          PremiumSectionHeader(
            page: HopePageId.createOpportunity,
            domain: HopeProductDomain.work,
            title: translate('اطلاعات فرصت', 'Opportunity details'),
            subtitle: translate(
              'عنوان، توضیحات، دسته‌بندی و موقعیت همکاری.',
              'Title, description, category, and collaboration location.',
            ),
          ),
          const SizedBox(height: 10),
          PremiumPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: HopeCopy.of(context).copy_title_d4694a2,
                    prefixIcon: const HopeIcon(HopeV2Icons.job, size: 20),
                  ),
                ),
                const SizedBox(height: 11),
                TextField(
                  controller: description,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText:
                        HopeCopy.of(context).copy_full_description_c4dea43,
                    alignLabelWithHint: true,
                    prefixIcon: const HopeIcon(HopeV2Icons.activity, size: 20),
                  ),
                ),
                const SizedBox(height: 11),
                FutureBuilder<List<HopeCategory>>(
                  future: categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return PremiumPanel(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const HopeIcon(HopeV2Icons.pending, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(translate(
                                'بارگذاری دسته‌بندی‌ها ناموفق بود.',
                                'Could not load categories.',
                              )),
                            ),
                            IconButton(
                              tooltip: HopeCopy.of(context).copy_retry_49f3eba,
                              onPressed: () => onRetryCategories(),
                              icon: const HugeIcon(icon: HopeV2Icons.refresh, size: 19),
                            ),
                          ],
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: LinearProgressIndicator(),
                      );
                    }
                    final categories = snapshot.data ?? const <HopeCategory>[];
                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: categoryId,
                      decoration: InputDecoration(
                        labelText: HopeCopy.of(context)
                            .copy_professional_category_a8c7c42,
                        hintText:
                            HopeCopy.of(context).copy_choose_a_category_b77d860,
                        prefixIcon: const HopeIcon(HopeV2Icons.category, size: 20),
                      ),
                      items: categories.map((category) {
                        final depth = category.parentId == null ? 0 : 1;
                        return DropdownMenuItem<String>(
                          value: category.slug,
                          child: Text(
                            '${depth == 0 ? '' : '  ↳ '}${category.label(isEn)}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => onCategoryChanged(value),
                    );
                  },
                ),
                const SizedBox(height: 11),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: city,
                  decoration: InputDecoration(
                    labelText: HopeCopy.of(context).copy_city_3d7dc3e,
                    prefixIcon: const HopeIcon(HopeV2Icons.location, size: 20),
                  ),
                  items: [
                    ...HopeSettingsController.cities.map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    ),
                  ],
                  onChanged: (value) => onCityChanged(value ?? city),
                ),
              ],
            ),
          ),
          ],
          if (activeStep == 2) ...[
          SizedBox(height: sectionGap),
          PremiumSectionHeader(
            title: kind == 'MISSION'
                ? HopeCopy.of(context).copy_price_time_4d31a36
                : HopeCopy.of(context).copy_salary_schedule_bab0cb3,
            subtitle: kind == 'MISSION'
                ? HopeCopy.of(context)
                    .copy_set_a_defined_price_and_delivery_time_1e53f1a
                : HopeCopy.of(context)
                    .copy_the_first_month_salary_determines_hope_s_j_ca73bd3,
          ),
          const SizedBox(height: 10),
          if (kind == 'MISSION')
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  TextField(
                    controller: minBudget,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                    ],
                    decoration: InputDecoration(
                      labelText: HopeCopy.of(context).copy_minimum_pay_38cc5ec,
                      prefixIcon: const HopeIcon(HopeV2Icons.payments, size: 20),
                      suffixText: translate('تومان', 'Toman'),
                    ),
                  ),
                  TextField(
                    controller: maxBudget,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                    ],
                    decoration: InputDecoration(
                      labelText: HopeCopy.of(context).copy_maximum_pay_b51ad57,
                      prefixIcon: const HopeIcon(HopeV2Icons.wallet, size: 20),
                      suffixText: translate('تومان', 'Toman'),
                    ),
                  ),
                ];

                if (constraints.maxWidth < 500) {
                  return Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 11),
                      fields[1],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 10),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            )
          else
            TextField(
              controller: salary,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
              decoration: InputDecoration(
                labelText: HopeCopy.of(context).copy_monthly_salary_1d770dc,
                prefixIcon: const HopeIcon(HopeV2Icons.payments, size: 20),
                suffixText: translate('تومان', 'Toman'),
              ),
            ),
          const SizedBox(height: 11),
          if (kind == 'MISSION')
            TextField(
              controller: duration,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: HopeCopy.of(context).copy_duration_hours_f4ca1cf,
                prefixIcon: const HopeIcon(HopeV2Icons.pending, size: 20),
              ),
            )
          else
            Column(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: schedule,
                  decoration: InputDecoration(
                    labelText: HopeCopy.of(context).copy_schedule_3af1939,
                    prefixIcon: const HopeIcon(HopeV2Icons.pending, size: 20),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'PART_TIME',
                      child: Text(
                        HopeCopy.of(context).copy_part_time_086787b,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'FULL_TIME',
                      child: Text(
                        HopeCopy.of(context).copy_full_time_1e4bd4e,
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      onScheduleChanged(value ?? schedule),
                ),
                const SizedBox(height: 11),
                TextField(
                  controller: deadline,
                  readOnly: true,
                  onTap: onPickDeadline,
                  decoration: InputDecoration(
                    labelText:
                        HopeCopy.of(context).copy_application_deadline_782fb61,
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: const HopeIcon(HopeV2Icons.activity, size: 20),
                    suffixIcon: const HopeIcon(HopeV2Icons.activity, size: 20),
                  ),
                ),
              ],
            ),
          ],
          if (activeStep == 3) ...[
          SizedBox(height: sectionGap),
          PremiumSectionHeader(
            page: HopePageId.createOpportunity,
            domain: HopeProductDomain.finance,
            title: translate('کارمزد HOPE', 'HOPE fee'),
            subtitle: translate(
              'هزینه‌های مرتبط با این نوع همکاری قبل از انتشار مشخص است.',
              'The applicable collaboration fee is stated before publishing.',
            ),
          ),
          const SizedBox(height: 10),
          PremiumPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HopeCopy.of(context).copy_hope_fee_2ea514e,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  kind == 'MISSION'
                      ? HopeCopy.of(context)
                          .copy_10_from_the_employer_and_10_from_the_candi_cf15dfa
                      : HopeCopy.of(context)
                          .copy_30_of_the_candidate_s_first_month_pay_is_c_d6da53b,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          SizedBox(height: sectionGap),
          PremiumSectionHeader(
            page: HopePageId.createOpportunity,
            domain: HopeProductDomain.trust,
            title: translate('معیار پذیرش', 'Acceptance criteria'),
            subtitle: translate(
              'شرایطی که مبنای بررسی و تکمیل این همکاری خواهد بود.',
              'The conditions used to review and complete this collaboration.',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: acceptanceCriteria,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: HopeCopy.of(context)
                  .copy_acceptance_selection_criteria_a061aef,
              alignLabelWithHint: true,
              prefixIcon: const HopeIcon(HopeV2Icons.completed, size: 20),
            ),
          ),
          ],
          if (activeStep == 4) ...[
            SizedBox(height: sectionGap),
            PremiumSectionHeader(
              page: HopePageId.createOpportunity,
              domain: HopeProductDomain.trust,
              title: translate('بازبینی نهایی', 'Final review'),
              subtitle: translate(
                'پیش از انتشار، خلاصهٔ داده‌های واردشده را بررسی کنید.',
                'Review the details you entered before publishing.',
              ),
            ),
            const SizedBox(height: 10),
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          key: const ValueKey('opportunity-live-preview-peek'),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 2),
                          childrenPadding: EdgeInsets.zero,
                          initiallyExpanded: true,
                          leading: const HopeIconTile(
                            HopeV2Icons.insights,
                            size: 38,
                            filled: true,
                          ),
                          title: Text(
                            translate('پیش‌نمایش زنده', 'Live preview'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          subtitle: Text(
                            translate(
                              'برای بررسی خلاصه فرصت باز کنید.',
                              'Open to review the opportunity summary.',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          children: [
                            HopeOpportunityLivePreview(
                              kind: kind,
                              visibility: visibility,
                              schedule: schedule,
                              city: city,
                              titleController: title,
                              descriptionController: description,
                              minBudgetController: minBudget,
                              maxBudgetController: maxBudget,
                              salaryController: salary,
                            ),
                          ],
                        ),
                      ),
            
            const SizedBox(height: 10),
            PremiumPanel(
              quiet: true,
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HopeIcon(HopeV2Icons.secure, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(translate(
                      'با انتخاب انتشار، اطلاعات فرم از مسیر فعلی ثبت و سپس منتشر می‌شود؛ مقادیر مالی و شرایط از همان ورودی‌های شما گرفته می‌شوند.',
                      'Publish submits the current form through the existing create-and-publish flow; financial values and conditions come from your entries.',
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('create-opportunity-previous-step'),
                  onPressed: activeStep == 0 || busy
                      ? null
                      : () => onStepChanged(activeStep - 1),
                  icon: const HugeIcon(icon: HopeV2Icons.arrowLeft, size: 18),
                  label: Text(translate('مرحلهٔ قبل', 'Back')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('create-opportunity-next-step'),
                  onPressed: busy
                      ? null
                      : activeStep < 4
                          ? () => onStepChanged(activeStep + 1)
                          : onSubmit,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : HugeIcon(
                          icon: activeStep < 4
                              ? HopeV2Icons.arrowRight
                              : HopeV2Icons.featured,
                          size: 18,
                        ),
                  label: Text(
                    activeStep < 4
                        ? translate('ادامه', 'Continue')
                        : HopeCopy.of(context).copy_publish_opportunity_9993b91,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
  }
}
