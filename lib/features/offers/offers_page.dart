import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/marketplace/application.dart';
import '../../core/marketplace/offer_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/theme/app_theme.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key, this.jobId});
  final String? jobId;
  @override State<OffersPage> createState()=>_OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  List<HopeOffer> _items = const [];
  Object? _loadError;
  bool _loading = true;
  int _reloadRequestId = 0;
  String _filter='ALL';
  String? _acceptingId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final requestId = ++_reloadRequestId;
    final repository = context.read<OfferRepository>();
    final hasExistingItems = _items.isNotEmpty;
    setState(() {
      _loadError = null;
      if (!hasExistingItems) _loading = true;
    });
    try {
      final items = widget.jobId == null
          ? await repository.listMine()
          : await repository.listForJob(widget.jobId!);
      if (!mounted || requestId != _reloadRequestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || requestId != _reloadRequestId) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }
  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _money(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return value;
    return '${NumberFormat.decimalPattern('en_US').format(parsed)} ${_t('تومان', 'Toman')}';
  }
  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return _t('در انتظار بررسی', 'Pending');
      case 'ACCEPTED':
        return _t('پذیرفته‌شده', 'Accepted');
      case 'REJECTED':
        return _t('رد شده', 'Rejected');
      default:
        return _t('نیازمند بررسی', 'Needs review');
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppColors.warning;
      case 'ACCEPTED':
        return AppColors.success;
      case 'REJECTED':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _items;
    final rows = _filter == 'ALL'
        ? all
        : all.where((x) => x.status.toUpperCase() == _filter).toList();

    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jobId == null
            ? _t('پیشنهادهای من', 'My offers')
            : _t('پیشنهادهای این فرصت', 'Job offers')),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: HopeIcon(HopeV2Icons.refresh, size: 19),
            tooltip: _t('بازخوانی', 'Refresh'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: PremiumPageFrame(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              PremiumHeader(
                eyebrow: _t('پیشنهادها', 'OFFERS'),
                title: _t('پیشنهادهای کاری', 'Job offers'),
                subtitle: _t(
                  'مبلغ، وضعیت و اقدام مجاز هر پیشنهاد را بررسی کنید.',
                  'Review amount, status, and the next allowed action for each offer.',
                ),
                trailing: PremiumTag(
                  icon: HopeV2Icons.featured,
                  label: all.length.toString(),
                ),
              ),
              const SizedBox(height: 20),
              if (_loadError != null) ...[
                HopeAsyncState(
                  kind: hopeStateKindForError(_loadError!),
                  title: _t(
                    'پیشنهادها در دسترس نیستند',
                    'Offers unavailable',
                  ),
                  message: apiErrorMessage(_loadError!),
                  action: FilledButton(
                    onPressed: _reload,
                    child: Text(_t('تلاش دوباره', 'Retry')),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final x in const ['ALL','PENDING','ACCEPTED','REJECTED'])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: PremiumFilterChip(
                          selected: _filter == x,
                          label: x == 'ALL' ? _t('همه', 'All') : _statusLabel(x),
                          color: x == 'ALL'
                              ? Theme.of(context).colorScheme.primary
                              : _statusColor(context, x),
                          onTap: () => setState(() => _filter = x),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                EmptyState(
                  icon: HopeV2Icons.featured,
                  title: _t('پیشنهادی وجود ندارد', 'No offers'),
                  message: _t(
                    'در این وضعیت پیشنهادی برای نمایش وجود ندارد.',
                    'There are no offers in this state.',
                  ),
                )
              else
                ...rows.map(_card),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(HopeOffer o) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: PremiumPanel(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            button: true,
            excludeSemantics: true,
            label: _t(
              'پیشنهاد ${o.id}، مبلغ ${_money(o.price)}، ${_statusLabel(o.status)}',
              'Offer ${o.id}, amount ${_money(o.price)}, ${_statusLabel(o.status)}',
            ),
            onTap: () => _showDetails(o),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _showDetails(o),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const HopeIconTile(HopeV2Icons.payments, filled: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_t('مبلغ', 'Amount')}: ${_money(o.price)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      StatusPill(
                        _statusLabel(o.status),
                        color: _statusColor(context, o.status),
                      ),
                    ],
                  ),
                  if (o.message.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        o.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${_t('شناسه فرصت', 'Job')}: ${o.jobId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (o.createdAt != null)
                    Text(
                      '${_t('ایجاد', 'Created')}: ${o.createdAt}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      _t('برای جزئیات لمس کنید', 'Tap for details'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.jobId != null && o.isPending)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                onPressed: _acceptingId == o.id ? null : () => _accept(o),
                icon: _acceptingId == o.id
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(_acceptingId == o.id
                    ? _t('در حال پذیرش...', 'Accepting...')
                    : _t('پذیرش پیشنهاد', 'Accept offer')),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _showDetails(HopeOffer summary) async {
    try {
      final detail = await context.read<OfferRepository>().get(summary.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_t('جزئیات پیشنهاد','Offer details'), style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: HopeIcon(HopeV2Icons.payments, size: 20),
                  title: Text(_t('مبلغ','Amount')),
                  subtitle: Text(_money(detail.price)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: HopeIcon(HopeV2Icons.pending, size: 20),
                  title: Text(_t('وضعیت','Status')),
                  subtitle: Text(_statusLabel(detail.status)),
                ),
                if (detail.message.trim().isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: HopeIcon(HopeV2Icons.activity, size: 20),
                    title: Text(_t('پیام','Message')),
                    subtitle: Text(detail.message),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: HopeIcon(HopeV2Icons.job, size: 20),
                  title: Text(_t('فرصت','Opportunity')),
                  subtitle: Text(detail.jobId),
                ),
                if (detail.createdAt != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: HopeIcon(HopeV2Icons.pending, size: 20),
                    title: Text(_t('ایجاد شده','Created')),
                    subtitle: Text(detail.createdAt!),
                  ),
                if (widget.jobId != null && detail.isPending)
                  FilledButton.icon(
                    onPressed: _acceptingId == detail.id
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _accept(detail);
                          },
                    icon: HopeIcon(HopeV2Icons.completed, size: 19),
                    label: Text(_t('پذیرش پیشنهاد','Accept offer')),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _accept(HopeOffer o) async {
    if (_acceptingId != null || !mounted) return;
    final repository = context.read<OfferRepository>();
    setState(() => _acceptingId = o.id);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('پذیرش پیشنهاد؟', 'Accept this offer?')),
          content: Text(_t(
            'پذیرش پیشنهاد یک اقدام مالی/قراردادی است. قبل از تأیید مبلغ و شرایط را بررسی کنید.',
            'Accepting an offer is a contractual/financial action. Review the amount and terms before confirming.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('لغو', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t('تأیید', 'Confirm')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await repository.accept(o.id);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('پیشنهاد پذیرفته شد', 'Offer accepted'))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }
}
