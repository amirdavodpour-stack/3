part of 'create_job_page.dart';

class _TypeHero extends StatelessWidget {
  const _TypeHero({required this.kind, required this.onChanged});

  final String kind;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return HopeSurface(
      highlight: true,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            HopeCopy.of(context)
                .copy_first_choose_what_kind_of_opportunity_you__f035ca9,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = [
                _tile(
                  context,
                  'MISSION',
                  Icons.bolt_rounded,
                  HopeCopy.of(context).copy_mission_fb4c5e1,
                  HopeCopy.of(context)
                      .copy_a_defined_task_with_defined_pay_77b1068,
                ),
                _tile(
                  context,
                  'JOB',
                  Icons.business_center_rounded,
                  HopeCopy.of(context).copy_job_ce2feba,
                  HopeCopy.of(context)
                      .copy_part_full_time_with_monthly_pay_abd5afd,
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
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    String value,
    IconData icon,
    String title,
    String sub,
  ) {
    final selected = kind == value;

    return PressableScale(
      onTap: () => onChanged(value),
      semanticLabel: '$title. $sub',
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF6C4DFF), Color(0xFF22B8A7)],
                )
              : null,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: selected ? Colors.white70 : null,
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

  final IconData icon;
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
      child: HopeSurface(
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
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
        children: [
          _TypeHero(
            kind: kind,
            onChanged: onKindChanged,
          ),
          const SizedBox(height: 18),
          SectionTitle(
            title: HopeCopy.of(context).copy_audience_visibility_5a0ddcb,
            subtitle:
                HopeCopy.of(context).copy_make_it_public_or_specialized_e890215,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _VisibilityCard(
                  icon: Icons.public_rounded,
                  title: HopeCopy.of(context).copy_public_21e97be,
                  sub: HopeCopy.of(context).copy_for_everyone_ebc769c,
                  value: 'PUBLIC',
                  selected: visibility == 'PUBLIC',
                  onSelected: onVisibilityChanged,
                ),
                _VisibilityCard(
                  icon: Icons.auto_awesome_rounded,
                  title: HopeCopy.of(context).copy_specialized_5d1ca04,
                  sub: HopeCopy.of(context).copy_for_a_specific_field_9b79bd6,
                  value: 'SPECIALIZED',
                  selected: visibility == 'SPECIALIZED',
                  onSelected: onVisibilityChanged,
                ),
              ];

              if (constraints.maxWidth < 500) {
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
          const SizedBox(height: 20),
          HopeSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: HopeCopy.of(context).copy_title_d4694a2,
                    prefixIcon: const Icon(Icons.title_rounded),
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
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 11),
                FutureBuilder<List<HopeCategory>>(
                  future: categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return HopeSurface(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off_rounded),
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
                              icon: const Icon(Icons.refresh_rounded),
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
                        prefixIcon: const Icon(Icons.category_outlined),
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
                    prefixIcon: const Icon(Icons.location_on_outlined),
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
          const SizedBox(height: 20),
          SectionTitle(
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
                      prefixIcon: const Icon(Icons.payments_outlined),
                      suffixText: translate('تومان', 'TOMAN'),
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
                      prefixIcon:
                          const Icon(Icons.account_balance_wallet_outlined),
                      suffixText: translate('تومان', 'TOMAN'),
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
                prefixIcon: const Icon(Icons.payments_rounded),
                suffixText: translate('تومان', 'TOMAN'),
              ),
            ),
          const SizedBox(height: 11),
          if (kind == 'MISSION')
            TextField(
              controller: duration,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: HopeCopy.of(context).copy_duration_hours_f4ca1cf,
                prefixIcon: const Icon(Icons.schedule_rounded),
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
                    prefixIcon: const Icon(Icons.timelapse_rounded),
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
                    prefixIcon: const Icon(Icons.event_outlined),
                    suffixIcon: const Icon(Icons.calendar_month_rounded),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          HopeSurface(
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
          const SizedBox(height: 22),
          TextField(
            controller: acceptanceCriteria,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: HopeCopy.of(context)
                  .copy_acceptance_selection_criteria_a061aef,
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.fact_check_outlined),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy ? null : onSubmit,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    HopeCopy.of(context).copy_publish_opportunity_9993b91,
                  ),
          ),
        ],
      );
  }
}
