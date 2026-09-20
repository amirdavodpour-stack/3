part of 'transaction_page.dart';

extension on _TransactionPageState {
  Widget _flow(BuildContext context, HopeJob? job, String paymentStatus) {
    final current = _stepFor(job, paymentStatus);
    const en = ['Fund', 'Hold', 'Work', 'Deliver', 'Approve', 'Payout'];
    const fa = ['تأمین', 'نگهداری', 'کار', 'تحویل', 'تأیید', 'تسویه'];
    return HopeSurface(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
      highlight: current > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t('مسیر مالی و انجام کار', 'Payment & job flow'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 520,
              child: Row(
                children: [
                  for (var i = 0; i < en.length; i++) ...[
                    Expanded(
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i <= current
                                  ? AppColors.success
                                  : Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: .45),
                            ),
                            child: Icon(
                              i <= current
                                  ? Icons.check_rounded
                                  : Icons.circle_outlined,
                              size: 16,
                              color:
                                  i <= current ? Colors.white : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _t(fa[i], en[i]),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _statusLabel(paymentStatus),
            style: Theme.of(context).textTheme.bodySmall,
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
        icon: const Icon(Icons.account_balance_wallet_rounded),
        label: Text(_t('تأمین وجه', 'Fund payment')),
      ));
    }
    if (paymentStatus == 'HOLD_PENDING' || paymentStatus == 'HOLD_FAILED') {
      actions.add(OutlinedButton.icon(
        onPressed: loading ? null : refresh,
        icon: const Icon(Icons.sync_rounded),
        label: Text(_t('بررسی وضعیت تأمین', 'Refresh funding status')),
      ));
    }
    if (paymentStatus == 'HELD' && job?.status == 'FUNDED' && provider) {
      actions.add(FilledButton.icon(
        onPressed: loading ? null : () => _jobAction('start'),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(_t('شروع کار', 'Start work')),
      ));
    }
    if (job?.status == 'IN_PROGRESS' && provider) {
      actions.add(FilledButton.icon(
        onPressed: loading ? null : () => _jobAction('deliver'),
        icon: const Icon(Icons.outbox_rounded),
        label: Text(_t('تحویل برای بررسی', 'Submit delivery')),
      ));
    }
    if ((job?.status == 'DELIVERED' || job?.status == 'UNDER_REVIEW') &&
        paymentStatus == 'HELD' &&
        owner) {
      actions.add(FilledButton.icon(
        onPressed: loading ? null : () => _jobAction('accept'),
        icon: const Icon(Icons.verified_rounded),
        label: Text(_t('تأیید و تکمیل', 'Approve & complete')),
      ));
    }
    if (paymentStatus == 'HELD' && owner) {
      actions.add(OutlinedButton.icon(
        onPressed: loading ? null : () => _confirmAction('refund'),
        icon: const Icon(Icons.undo_rounded),
        label: Text(_t('درخواست بازپرداخت', 'Request a refund')),
      ));
    }
    if (job?.status == 'COMPLETED' &&
        (paymentStatus == 'RELEASE_PENDING' ||
            paymentStatus == 'RELEASE_FAILED') &&
        owner) {
      actions.add(FilledButton.icon(
        onPressed: loading ? null : () => action('release'),
        icon: const Icon(Icons.payments_rounded),
        label: Text(_t('تسویه با مجری', 'Release payout')),
      ));
    }
    if (actions.isEmpty && paymentStatus == 'RELEASED') {
      actions.add(HopeSurface(
        highlight: true,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
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
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: loading ? null : refresh,
                        child: Text(HopeCopy.of(context).copy_retry_49f3eba))
                  ]))));
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
        body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 500;
                  return Row(
                    children: [
                      HopeMark(
                        size: 38,
                        showText: !compact,
                      ),
                      const Spacer(),
                      StatusPill(
                        _statusLabel(status),
                        color: _statusColor(status),
                        icon: _statusIcon(status),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              if (job != null) ...[
                Text(job.title,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusPill(
                    job.status ?? 'UNKNOWN',
                    color: AppColors.muted,
                    icon: Icons.work_history_outlined,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      payment?.id == null
                          ? _t('پرداخت هنوز ساخته نشده',
                              'Payment has not been created yet')
                          : _t('شناسه پرداخت: ${payment!.id}',
                              'Payment ID: ${payment!.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    onPressed: loading ? null : refresh,
                    tooltip: _t('به‌روزرسانی وضعیت', 'Refresh status'),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              HopeSurface(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            HopeCopy.of(context).copy_payment_status_e1b6f0c,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _statusLabel(status),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            HopeCopy.of(context).copy_amount_6400812,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            moneyLabel(context, payment?.amount ?? '—'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: Text(
                              HopeCopy.of(context).copy_reference_aa63360,
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Flexible(
                        child: Text(
                          payment?.providerRef ?? '—',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    ]),
                  ])),
              const SizedBox(height: 10),
              HopeSurface(
                padding: const EdgeInsets.all(14),
                highlight: status == 'HELD' || status == 'RELEASED',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_statusIcon(status), color: _statusColor(status)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusHint(status),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (payment?.fees != null) ...[
                const SizedBox(height: 12),
                HopeSurface(
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
              _flow(context, job, status),
              const SizedBox(height: 14),
              _actions(context, job, status),
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
    );
  }
}
