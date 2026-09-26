part of 'transaction_page.dart';

extension on _TransactionPageState {
  Widget _flow(BuildContext context, HopeJob? job, String paymentStatus) {
    final current = _stepFor(job, paymentStatus).clamp(0, 5);
    const en = ['Fund', 'Hold', 'Work', 'Deliver', 'Approve', 'Payout'];
    const fa = ['تأمین وجه', 'در امانت', 'در حال انجام', 'تحویل', 'تأیید', 'تسویه'];
    const icons = [
      HopeV2Icons.wallet,
      HopeV2Icons.secure,
      HopeV2Icons.job,
      HopeV2Icons.activity,
      HopeV2Icons.completed,
      HopeV2Icons.payments,
    ];

    return PremiumPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      highlight: paymentStatus == 'HELD' ||
          paymentStatus == 'RELEASED' ||
          paymentStatus == 'HOLD_PENDING' ||
          paymentStatus == 'RELEASE_PENDING',
      semanticLabel: _t('مسیر کامل مالی و انجام کار', 'Full payment and work lifecycle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _t('مسیر مالی و انجام کار', 'Payment & job flow'),
                  style: HopeV2Type.section(context),
                ),
              ),
              PremiumTag(
                icon: _statusIcon(paymentStatus),
                label: _statusLabel(paymentStatus),
                color: _statusColor(paymentStatus),
              ),
            ],
          ),
          const SizedBox(height: 15),
          for (var i = 0; i < en.length; i++)
            _lifecycleStep(
              context,
              index: i,
              current: current,
              label: _t(fa[i], en[i]),
              icon: icons[i],
              last: i == en.length - 1,
            ),
          const SizedBox(height: 6),
          Text(
            _statusHint(paymentStatus),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _lifecycleStep(
    BuildContext context, {
    required int index,
    required int current,
    required String label,
    required Object icon,
    required bool last,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final completed = index < current;
    final active = index == current;
    final color = completed || active ? scheme.primary : scheme.onSurfaceVariant;
    final fill = completed
        ? scheme.primary
        : active
            ? scheme.primary.withValues(alpha: .12)
            : HopeV2Surfaces.panel(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : HopeV2Motion.fast,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    border: Border.all(
                      color: completed || active
                          ? scheme.primary.withValues(alpha: .35)
                          : HopeV2Surfaces.border(context),
                    ),
                  ),
                  child: HopeIcon(
                    completed ? HopeV2Icons.completed : icon,
                    size: 15,
                    color: completed ? scheme.onPrimary : color,
                    strokeWidth: 1.9,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        color: completed
                            ? scheme.primary.withValues(alpha: .42)
                            : HopeV2Surfaces.border(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Container(
                constraints: const BoxConstraints(minHeight: 42),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? scheme.primary.withValues(alpha: .07)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(HopeV2Radii.md),
                  border: active
                      ? Border.all(color: scheme.primary.withValues(alpha: .16))
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: active || completed
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                      ),
                    ),
                    if (active)
                      PremiumTag(
                        label: _t('مرحله فعلی', 'Current'),
                        color: scheme.primary,
                      )
                    else if (completed)
                      PremiumTag(
                        icon: Icons.check_rounded,
                        label: _t('انجام شد', 'Done'),
                        color: scheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, HopeJob? job, String paymentStatus) {
    final owner = _isOwner(job);
    final provider = _isProvider(job);
    final actions = <Widget>[];
    if (paymentStatus == 'NO_TRANSACTION' && owner) {
      actions.add(FilledButton.icon(
        onPressed: loading ? null : () => action('fund'),
        icon: HopeIcon(HopeV2Icons.wallet, size: 19),
        label: Text(_t('تأمین وجه', 'Fund payment')),
      ));
    }
    if (paymentStatus == 'HOLD_PENDING' || paymentStatus == 'HOLD_FAILED') {
      actions.add(OutlinedButton.icon(
        onPressed: loading ? null : refresh,
        icon: HopeIcon(HopeV2Icons.refresh, size: 19),
        label: Text(_t('بررسی وضعیت تأمین', 'Refresh funding status')),
      ));
    }
    if (paymentStatus == 'HELD' && job?.status == 'FUNDED' && provider) {
      actions.add(FilledButton.icon(
        onPressed: loading ? null : () => _jobAction('start'),
        icon: HopeIcon(HopeV2Icons.mission, size: 19),
        label: Text(_t('شروع کار', 'Start work')),
      ));
    }
    if (job?.status == 'IN_PROGRESS' && provider) {
      actions.add(FilledButton.icon(
        onPressed: loading ? null : () => _jobAction('deliver'),
        icon: HopeIcon(HopeV2Icons.activity, size: 19),
        label: Text(_t('تحویل برای بررسی', 'Submit delivery')),
      ));
    }
    if ((job?.status == 'DELIVERED' || job?.status == 'UNDER_REVIEW') &&
        paymentStatus == 'HELD' &&
        owner) {
      actions.add(FilledButton.icon(
        onPressed: loading ? null : () => _jobAction('accept'),
        icon: HopeIcon(HopeV2Icons.completed, size: 19),
        label: Text(_t('تأیید و تکمیل', 'Approve & complete')),
      ));
    }
    if (paymentStatus == 'HELD' && owner) {
      actions.add(OutlinedButton.icon(
        onPressed: loading ? null : () => _confirmAction('refund'),
        icon: HopeIcon(HopeV2Icons.transferOut, size: 19),
        label: Text(_t('درخواست بازپرداخت', 'Request a refund')),
      ));
    }
    if (job?.status == 'COMPLETED' &&
        (paymentStatus == 'RELEASE_PENDING' ||
            paymentStatus == 'RELEASE_FAILED') &&
        owner) {
      actions.add(FilledButton.icon(
        onPressed: loading ? null : () => action('release'),
        icon: HopeIcon(HopeV2Icons.payments, size: 19),
        label: Text(_t('تسویه با مجری', 'Release payout')),
      ));
    }
    if (actions.isEmpty && paymentStatus == 'RELEASED') {
      actions.add(PremiumPanel(
        highlight: true,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          HopeIcon(HopeV2Icons.completed, color: AppColors.success, size: 20),
          const SizedBox(width: 9),
          Expanded(
              child: Text(_t(
            'این چرخه مالی با موفقیت تسویه شده است.',
            'This financial cycle is fully settled.',
          ))),
        ]),
      ));
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          actions[i],
          if (i != actions.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }

  Widget _buildPage(BuildContext context) {
    if (loading && payment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null && payment == null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: HopeAsyncState(
                kind: HopeStateKind.error,
                title: _t(
                  'به‌روزرسانی پرداخت ناموفق بود',
                  'Payment refresh failed',
                ),
                message: error!,
                action: FilledButton.icon(
                  onPressed: loading ? null : refresh,
                  icon: HopeIcon(HopeV2Icons.refresh, size: 19),
                  label: Text(HopeCopy.of(context).copy_retry_49f3eba),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final status = payment?.status ?? 'NO_TRANSACTION';
    final job = payment?.job;
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'en'
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            leading: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Localizations.localeOf(context).languageCode == 'en'
                    ? Icons.arrow_back_rounded
                    : Icons.arrow_forward_rounded),
                tooltip: HopeCopy.of(context).copy_back_6e09f79),
            title: Text(HopeCopy.of(context).copy_transaction_7e0ea3b)),
        body: PremiumPageFrame(
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 72),
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
              if (error != null) ...[
                HopeAsyncState(
                  kind: HopeStateKind.error,
                  title: _t('به‌روزرسانی پرداخت ناموفق بود', 'Payment refresh failed'),
                  message: error!,
                  action: FilledButton.icon(
                    onPressed: loading ? null : refresh,
                    icon: HopeIcon(HopeV2Icons.refresh, size: 19),
                    label: Text(HopeCopy.of(context).copy_retry_49f3eba),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job?.title ??
                              HopeCopy.of(context).copy_transaction_7e0ea3b,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment?.id == null
                              ? _t(
                                  'پرداخت هنوز ساخته نشده',
                                  'Payment has not been created yet',
                                )
                              : _t('شناسه پرداخت: ' + payment!.id, 'Payment ID: ' + payment!.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PremiumTag(
                    icon: _statusIcon(status),
                    label: _statusLabel(status),
                    color: _statusColor(status),
                  ),
                  IconButton(
                    onPressed: loading ? null : refresh,
                    tooltip: _t('به‌روزرسانی وضعیت', 'Refresh status'),
                    icon: HopeIcon(HopeV2Icons.refresh, size: 19),
                  ),
                ],
              ),
              if (job != null) ...[
                const SizedBox(height: 7),
                StatusPill(
                  _jobStatusLabel(job.status),
                  color: AppColors.muted,
                  icon: HopeV2Icons.job,
                ),
              ],
              const SizedBox(height: 12),
              PremiumPanel(
                padding: const EdgeInsets.all(18),
                highlight: status == 'HELD' ||
                    status == 'RELEASED' ||
                    status == 'HOLD_PENDING' ||
                    status == 'RELEASE_PENDING',
                semanticLabel:
                    _t('خلاصه مالی این کار', 'Financial summary for this job'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('خلاصه مالی', 'Financial summary'),
                                style: HopeV2Type.section(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                HopeCopy.of(context).copy_payment_status_e1b6f0c,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        PremiumTag(
                          icon: _statusIcon(status),
                          label: _statusLabel(status),
                          color: _statusColor(status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      HopeCopy.of(context).copy_amount_6400812,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      alignment: AlignmentDirectional.centerStart,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        moneyLabel(context, payment?.amount ?? '—'),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.8,
                            ),
                      ),
                    ),
                    if (payment?.providerRef?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              _t('شناسه مرجع', 'Reference'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              payment!.providerRef!.trim(),
                              softWrap: true,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      _statusHint(status),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.35,
                          ),
                    ),
                    if (status == 'NO_TRANSACTION') ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          HopeCopy.of(context).copy_no_payment_1337b58,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                    if (status == 'RELEASED') ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          HopeCopy.of(context)
                              .copy_payment_has_been_settled_f8f8f83,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _flow(context, job, status),
              const SizedBox(height: 14),
              _actions(context, job, status),
              if (payment?.fees != null) ...[
                const SizedBox(height: 12),
                PremiumPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              HopeCopy.of(context)
                                  .copy_financial_details_f24007d,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          _moneyRow(
                              context,
                              HopeCopy.of(context).copy_base_amount_82586c0,
                              payment!.fees!.baseAmount),
                          _moneyRow(
                              context,
                              HopeCopy.of(context).copy_employer_fee_3a30b60,
                              payment!.fees!.employerFee),
                          _moneyRow(
                              context,
                              HopeCopy.of(context).copy_worker_fee_85a35aa,
                              payment!.fees!.workerFee),
                          const Divider(height: 20),
                          _moneyRow(
                              context,
                              HopeCopy.of(context).copy_employer_charge_9740283,
                              payment!.fees!.employerCharge,
                              strong: true),
                          _moneyRow(
                              context,
                              HopeCopy.of(context).copy_worker_payout_45f6bb9,
                              payment!.fees!.providerPayout,
                              strong: true),
                        ])),
              ],
              const SizedBox(height: 14),
              if (job != null) ...[
                const SizedBox(height: 14),
                EvidenceActions(
                    repository: widget.repository,
                    uploadQueue: widget.uploadQueue,
                    jobId: widget.jobId,
                    job: {
                      ...job.toMap(),
                      'paymentStatus': payment?.paymentStatus,
                    },
                    onChanged: refresh),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
