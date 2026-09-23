import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/transactions/wallet.dart';
import '../../core/transactions/wallet_repository.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/theme/hope_v2_design.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.repository});

  final WalletRepository repository;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // Top-up is an internal/sandbox backend capability and is disabled by the
  // production API. Keep it out of the normal UI unless the app is explicitly
  // built for an environment where that capability is enabled.
  static const _internalTopUpEnabled = bool.fromEnvironment(
    'HOPE_ENABLE_INTERNAL_TOP_UP',
    defaultValue: false,
  );
  HopeWallet? _wallet;
  List<HopeWalletTransaction> _transactions = const [];
  List<HopePayout> _payouts = const [];
  String? _nextCursor;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int _loadRequestId = 0;
  bool _actionBusy = false;
  String _historyFilter = 'ALL';

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  String _t(String fa, String en) => _isEnglish ? en : fa;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final requestId = ++_loadRequestId;
    final hasExistingWallet = _wallet != null;
    setState(() {
      _error = null;
      _loadingMore = false;
      if (!hasExistingWallet) _loading = true;
    });
    try {
      final wallet = await widget.repository.getWallet();
      final page = await widget.repository.listTransactions(limit: 30);
      final payouts = await widget.repository.listPayouts();
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _wallet = wallet;
        _transactions = page.items;
        _nextCursor = page.nextCursor;
        _payouts = payouts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (_loadingMore || cursor == null || cursor.isEmpty) return;
    final requestId = _loadRequestId;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.listTransactions(
        limit: 30,
        cursor: cursor,
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _transactions = [..._transactions, ...page.items];
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('بارگذاری بیشتر انجام نشد.', 'Could not load more transactions.'))),
      );
    }
  }

  String _money(int amount) {
    final grouped = amount.toString().replaceAllMapped(
      RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$grouped ${_t('تومان', 'Toman')}';
  }

  String _date(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    return '${parsed.year}/${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')} · ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  String _walletStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return _t('فعال', 'Active');
      case 'INACTIVE':
        return _t('غیرفعال', 'Inactive');
      case 'SUSPENDED':
        return _t('تعلیق‌شده', 'Suspended');
      case 'LOCKED':
        return _t('قفل‌شده', 'Locked');
      default:
        return _t('نیازمند بررسی', 'Needs review');
    }
  }

  String _providerLabel(String provider) {
    switch (provider.toUpperCase()) {
      case 'INTERNAL':
        return _t('کیف پول داخلی', 'Internal wallet');
      default:
        return _t('ارائه‌دهنده پرداخت', 'Payment provider');
    }
  }

  String _referenceTypeLabel(String value) {
    final type = value.toUpperCase();
    if (type.contains('TRANSFER')) return _t('انتقال داخلی', 'Internal transfer');
    if (type.contains('TOP_UP')) return _t('شارژ کیف پول', 'Wallet top-up');
    if (type.contains('PAYOUT') || type.contains('WITHDRAW')) return _t('برداشت', 'Withdrawal');
    if (type.contains('HOLD')) return _t('رزرو مبلغ', 'Funds held');
    if (type.contains('RELEASE')) return _t('آزادسازی مبلغ', 'Funds released');
    if (type.contains('REFUND')) return _t('بازگشت وجه', 'Refund');
    return _t('سایر فعالیت‌ها', 'Other activity');
  }

  String _entryTypeLabel(String value) {
    switch (value.toUpperCase()) {
      case 'TRANSFER':
        return _t('انتقال داخلی', 'Internal transfer');
      case 'TOP_UP':
        return _t('شارژ کیف پول', 'Wallet top-up');
      case 'PAYOUT':
      case 'WITHDRAW':
        return _t('برداشت', 'Withdrawal');
      case 'HOLD':
        return _t('رزرو مبلغ', 'Funds held');
      case 'RELEASE':
        return _t('آزادسازی مبلغ', 'Funds released');
      case 'REFUND':
        return _t('بازگشت وجه', 'Refund');
      default:
        return _t('سایر فعالیت‌ها', 'Other activity');
    }
  }

  String _directionLabel(String value) {
    switch (value.toUpperCase()) {
      case 'CREDIT':
        return _t('ورودی', 'Credit');
      case 'DEBIT':
        return _t('خروجی', 'Debit');
      default:
        return _t('نامشخص', 'Unknown');
    }
  }

  String _entryTitle(HopeWalletTransaction item) =>
      _referenceTypeLabel(item.referenceType);

  Color _directionColor(BuildContext context, bool credit) {
    final colors = Theme.of(context).colorScheme;
    return credit ? colors.tertiary : colors.error;
  }

  Object _directionIcon(bool credit) => credit ? HopeV2Icons.transferIn : HopeV2Icons.transferOut;

  Future<void> _openTopUp() async {
    final amount = await _amountDialog(
      title: _t('شارژ کیف پول', 'Top up wallet'),
      action: _t('شارژ', 'Top up'),
    );
    if (amount == null) return;
    await _runAction(() async {
      final key = await _pendingKey('TOP_UP', {'amount': amount});
      await widget.repository.topUp(amount: amount, idempotencyKey: key);
      await _clearPendingKey('TOP_UP', {'amount': amount});
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('شارژ داخلی ثبت شد.', 'Internal top-up recorded.'))),
      );
    }, clearPendingOnError: () => _clearPendingKey('TOP_UP', {'amount': amount}));
  }

  Future<void> _openTransfer() async {
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (context) => _TransferDialog(
        isEnglish: _isEnglish,
        maxAmount: _wallet?.availableBalance,
        maxAmountLabel:
            _wallet == null ? null : _money(_wallet!.availableBalance),
      ),
    );
    if (result == null) return;
    final (destination, amount) = result;
    if (_wallet != null && amount > _wallet!.availableBalance) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('مبلغ انتقال بیشتر از موجودی قابل استفاده است.', 'Transfer amount exceeds your available balance.'))),
      );
      return;
    }
    await _runAction(() async {
      final key = await _pendingKey('TRANSFER', {
        'destinationWalletId': destination,
        'amount': amount,
      });
      await widget.repository.transfer(
        destinationWalletId: destination,
        amount: amount,
        idempotencyKey: key,
      );
      await _clearPendingKey('TRANSFER', {
        'destinationWalletId': destination,
        'amount': amount,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('انتقال داخلی ثبت شد.', 'Internal transfer recorded.'))),
      );
    }, clearPendingOnError: () => _clearPendingKey('TRANSFER', {
      'destinationWalletId': destination,
      'amount': amount,
    }));
  }

  Future<void> _openWithdraw() async {
    final amount = await _amountDialog(
      title: _t('درخواست برداشت', 'Request withdrawal'),
      action: _t('درخواست برداشت', 'Withdraw'),
      maxAmount: _wallet?.availableBalance,
    );
    if (amount == null) return;
    await _runAction(() async {
      final key = await _pendingKey('PAYOUT', {'amount': amount});
      await widget.repository.requestPayout(amount: amount, idempotencyKey: key);
      await _clearPendingKey('PAYOUT', {'amount': amount});
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('درخواست برداشت ثبت شد.', 'Withdrawal request recorded.'))),
      );
    }, clearPendingOnError: () => _clearPendingKey('PAYOUT', {'amount': amount}));
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  String _operationFingerprint(String operation, Map<String, dynamic> payload) {
    final normalized = Map<String, dynamic>.from(payload)..['walletId'] = _wallet?.id ?? '';
    final ordered = normalized.keys.toList()..sort();
    final canonical = <String, dynamic>{for (final key in ordered) key: normalized[key]};
    return '$operation:${jsonEncode(canonical)}';
  }

  String _pendingStorageKey(String fingerprint) =>
      'hope.wallet.pending-idempotency.${base64Url.encode(utf8.encode(fingerprint))}';

  Future<String> _pendingKey(String operation, Map<String, dynamic> payload) async {
    final fingerprint = _operationFingerprint(operation, payload);
    final prefs = await _prefs();
    final storageKey = _pendingStorageKey(fingerprint);
    final existing = prefs.getString(storageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final key = 'wallet-$operation-${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(storageKey, key);
    return key;
  }

  Future<void> _clearPendingKey(String operation, Map<String, dynamic> payload) async {
    final prefs = await _prefs();
    await prefs.remove(_pendingStorageKey(_operationFingerprint(operation, payload)));
  }

  Future<int?> _amountDialog({required String title, required String action, int? maxAmount}) async {
    final controller = TextEditingController();
    String? errorText;
    final value = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                onChanged: (_) { if (errorText != null) setDialogState(() => errorText = null); },
                decoration: InputDecoration(
                  labelText: _t('مبلغ به تومان', 'Amount in Toman'),
                  suffixText: _t('تومان', 'Toman'),
                  helperText: maxAmount == null
                      ? _t('عدد صحیح وارد کنید.', 'Enter a whole-number amount.')
                      : _t('حداکثر قابل استفاده: ${_money(maxAmount)}', 'Maximum available: ${_money(maxAmount)}'),
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('انصراف', 'Cancel'))),
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim();
                final parsed = int.tryParse(raw);
                const maxFinancialAmount = 9000000000000000;
                if (parsed == null || parsed <= 0) {
                  setDialogState(() => errorText = _t('مبلغ معتبر وارد کنید.', 'Enter a valid amount.'));
                  return;
                }
                if (parsed > maxFinancialAmount) {
                  setDialogState(() => errorText = _t('مبلغ از سقف مجاز بیشتر است.', 'Amount exceeds the financial limit.'));
                  return;
                }
                if (maxAmount != null && parsed > maxAmount) {
                  setDialogState(() => errorText = _t('مبلغ از موجودی قابل استفاده بیشتر است.', 'Amount exceeds your available balance.'));
                  return;
                }
                Navigator.pop(context, parsed);
              },
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return value;
  }

  bool _isTerminalClientError(Object error) {
    if (error is! ApiException) return false;
    return switch (error.code) {
      'INVALID_AMOUNT' ||
      'VALIDATION_ERROR' ||
      'INVALID_WALLET' ||
      'WALLET_NOT_FOUND' ||
      'WALLET_UNAVAILABLE' ||
      'INSUFFICIENT_FUNDS' ||
      'PAYOUT_NOT_AVAILABLE' ||
      'PAYOUT_ALREADY_ACTIVE' ||
      'NOT_FOUND' ||
      'IDEMPOTENCY_CONFLICT' => true,
      _ => false,
    };
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    Future<void> Function()? clearPendingOnError,
  }) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await action();
    } catch (error) {
      if (_isTerminalClientError(error)) await clearPendingOnError?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('عملیات انجام نشد.', 'Action could not be completed.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _showTransaction(HopeWalletTransaction item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(_entryTitle(item), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              _DetailRow(label: _t('مبلغ', 'Amount'), value: '${item.isCredit ? '+' : '-'}${_money(item.amount)}'),
              _DetailRow(label: _t('نوع ثبت', 'Entry type'), value: _entryTypeLabel(item.entryType)),
              _DetailRow(label: _t('جهت', 'Direction'), value: _directionLabel(item.direction)),
              _DetailRow(label: _t('نوع مرجع', 'Reference type'), value: _referenceTypeLabel(item.referenceType)),
              if (item.referenceId != null && item.referenceId!.isNotEmpty)
                _DetailRow(label: _t('شناسه مرجع', 'Reference ID'), value: item.referenceId!),
              _DetailRow(label: _t('عملیات مالی', 'Financial operation'), value: item.financialOperationId),
              if (item.balanceAfter != null)
                _DetailRow(label: _t('موجودی پس از تراکنش', 'Balance after'), value: _money(item.balanceAfter!)),
              _DetailRow(label: _t('زمان', 'Timestamp'), value: _date(item.createdAt)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyText(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('شناسه کیف پول کپی شد.', 'Wallet ID copied.'))),
    );
  }

  Future<void> _showPayout(HopePayout payout) async {
    final status = payout.status.toUpperCase();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  const HopeIconTile(HopeV2Icons.transferIn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t('جزئیات برداشت', 'Withdrawal details'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  StatusPill(_payoutLabel(status), color: _payoutColor(context, status), icon: _payoutIcon(status)),
                ],
              ),
              const SizedBox(height: 18),
              _DetailRow(label: _t('مبلغ', 'Amount'), value: _money(payout.amount)),
              _DetailRow(label: _t('وضعیت', 'Status'), value: _payoutLabel(status)),
              _DetailRow(label: _t('ارائه‌دهنده', 'Provider'), value: _providerLabel(payout.provider)),
              _DetailRow(label: _t('زمان ثبت', 'Created'), value: _date(payout.createdAt)),
              if (status == 'UNKNOWN')
                PremiumPanel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HugeIcon(icon: HopeV2Icons.pending, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_t(
                          'نتیجه برداشت قطعی نیست؛ برای جلوگیری از برداشت تکراری، تا دریافت نتیجه نهایی درخواست جدید ارسال نکنید.',
                          'The payout result is not final. Do not submit another withdrawal until the provider outcome is reconciled to avoid a duplicate payout.',
                        )),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _payoutLabel(String status) {
    switch (status.toUpperCase()) {
      case 'REQUESTED': return _t('درخواست‌شده', 'Requested');
      case 'RESERVED': return _t('رزروشده', 'Reserved');
      case 'PROCESSING': return _t('در حال پردازش', 'Processing');
      case 'UNKNOWN': return _t('نیازمند بررسی', 'Needs review');
      case 'SUCCEEDED': return _t('موفق', 'Succeeded');
      case 'FAILED': return _t('ناموفق', 'Failed');
      default: return _t('نیازمند بررسی', 'Needs review');
    }
  }

  Color _payoutColor(BuildContext context, String status) {
    final colors = Theme.of(context).colorScheme;
    switch (status.toUpperCase()) {
      case 'SUCCEEDED': return AppColors.success;
      case 'FAILED': return colors.error;
      case 'UNKNOWN': return AppColors.warning;
      default: return colors.primary;
    }
  }

  List<HopeWalletTransaction> _visibleTransactions() {
    switch (_historyFilter) {
      case 'CREDIT':
        return _transactions.where((item) => item.isCredit).toList(growable: false);
      case 'DEBIT':
        return _transactions.where((item) => !item.isCredit).toList(growable: false);
      case 'HOLD':
        return _transactions.where((item) => item.referenceType.toUpperCase().contains('HOLD')).toList(growable: false);
      default:
        return _transactions;
    }
  }

  int get _pendingPayoutCount => _payouts.where((p) => const {
        'REQUESTED', 'RESERVED', 'PROCESSING', 'UNKNOWN'
      }.contains(p.status.toUpperCase())).length;

  Object _payoutIcon(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCEEDED': return HopeV2Icons.completed;
      case 'FAILED': return HopeV2Icons.error;
      case 'UNKNOWN': return HopeV2Icons.pending;
      default: return HopeV2Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isGuest) {
      return Center(
        child: EmptyState(
          icon: HopeV2Icons.secure,
          title: _t('کیف پول خصوصی است', 'Your wallet is private'),
          message: _t(
            'برای مشاهده و مدیریت کیف پول وارد حساب شوید.',
            'Sign in to view and manage your wallet.',
          ),
        ),
      );
    }

    if (_loading && _wallet == null) {
      return HopeAsyncState(
        kind: HopeStateKind.loading,
        title: _t('در حال بارگذاری', 'Loading wallet'),
        message: _t(
          'کیف پول و فعالیت‌های مالی در حال دریافت است.',
          'Wallet and financial activity are loading.',
        ),
      );
    }

    if (_wallet == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 160),
            HopeAsyncState(
              kind: hopeStateKindForError(_error ?? StateError('wallet-load')),
              title: _t('کیف پول بارگذاری نشد', 'Wallet could not be loaded'),
              message: _t(
                'اتصال یا سرویس مالی در دسترس نبود. برای تلاش دوباره، دوباره بارگذاری کنید.',
                'The wallet service could not be reached. Refresh to try again.',
              ),
              action: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_t('تلاش دوباره', 'Try again')),
              ),
            ),
          ],
        ),
      );
    }

    final wallet = _wallet!;
    final canAct = !_actionBusy && wallet.isActive;

    Widget balanceHero() {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HopeV2Radii.hero),
          gradient: HopeV2Gradients.heroDark,
          boxShadow: HopeV2Shadows.heroDark,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const HopeIconTile(
                  HopeV2Icons.wallet,
                  size: 48,
                  filled: true,
                ),
                const Spacer(),
                PremiumTag(
                  icon: wallet.isActive
                      ? HopeV2Icons.verified
                      : HopeV2Icons.pending,
                  label: _walletStatusLabel(wallet.status),
                  color: Colors.white,
                  inverse: true,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _t('موجودی قابل استفاده', 'Available balance'),
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              alignment: AlignmentDirectional.centerStart,
              fit: BoxFit.scaleDown,
              child: Text(
                _money(wallet.availableBalance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PremiumTag(
                  icon: HopeV2Icons.secure,
                  label: _t(
                    'قفل‌شده ${_money(wallet.lockedBalance)}',
                    'Locked ${_money(wallet.lockedBalance)}',
                  ),
                  color: Colors.white,
                  inverse: true,
                ),
                PremiumTag(
                  icon: HopeV2Icons.secure,
                  label: _providerLabel('INTERNAL'),
                  color: scheme.tertiary,
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget actionsPanel() {
      return PremiumPanel(
        highlight: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('عملیات مالی', 'Money movement'),
              style: HopeV2Type.section(context),
            ),
            const SizedBox(height: 5),
            Text(
              _t(
                'عملیات داخلی کیف پول را از همین‌جا مدیریت کنید.',
                'Manage internal wallet actions from here.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_internalTopUpEnabled)
              FilledButton.tonalIcon(
                onPressed: canAct ? _openTopUp : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(_t('شارژ کیف پول', 'Top up')),
              ),
            if (_internalTopUpEnabled) const SizedBox(height: 9),
            FilledButton.icon(
              onPressed: canAct ? _openTransfer : null,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(_t('انتقال داخلی', 'Transfer')),
            ),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: canAct ? _openWithdraw : null,
              icon: HugeIcon(icon: HopeV2Icons.transferIn, size: 18),
              label: Text(_t('درخواست برداشت', 'Request withdrawal')),
            ),
            if (!wallet.isActive) ...[
              const SizedBox(height: 12),
              Text(
                _t(
                  'کیف پول فعال نیست؛ عملیات مالی جدید در دسترس نیست.',
                  'This wallet is not active; new financial actions are unavailable.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: PremiumPageFrame(
        maxWidth: 1020,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (_error != null) ...[
              HopeAsyncState(
                kind: hopeStateKindForError(_error!),
                title: _t('به‌روزرسانی کیف پول ناموفق بود', 'Wallet refresh failed'),
                message: _t(
                  'اطلاعات قبلی حفظ شده است. وضعیت را دوباره بررسی کنید.',
                  'The last loaded wallet data is preserved. Refresh to try again.',
                ),
                action: OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_t('تلاش دوباره', 'Try again')),
                ),
              ),
              const SizedBox(height: 14),
            ],
            PremiumHeader(
              eyebrow: _t('مالی', 'FINANCE'),
              title: _t('کیف پول', 'Wallet'),
              subtitle: _t(
                'موجودی، حرکت وجه و سابقه مالی در یک نمای واحد.',
                'Balance, money movement, and financial history in one view.',
              ),
              trailing: PremiumTag(
                icon: HopeV2Icons.secure,
                label: _providerLabel('INTERNAL'),
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: HopeV2Spacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final hero = balanceHero();
                final actions = actionsPanel();
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      hero,
                      const SizedBox(height: 12),
                      actions,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: hero),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: actions),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            PremiumPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const HopeIconTile(HopeV2Icons.wallet, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('شناسه کیف پول', 'Wallet ID'),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          wallet.id,
                          maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _t('کپی شناسه', 'Copy wallet ID'),
                    onPressed: wallet.id.isEmpty ? null : () => _copyText(wallet.id),
                    icon: HugeIcon(icon: HopeV2Icons.copy, size: 19),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
                final tiles = [
                  PremiumStatCard(
                    label: _t('موجودی قابل‌استفاده', 'Available balance'),
                    value: _money(wallet.availableBalance),
                    icon: HopeV2Icons.wallet,
                    caption: _t('قابل خرج یا انتقال', 'Ready to spend or transfer'),
                  ),
                  PremiumStatCard(
                    label: _t('قفل‌شده', 'Locked balance'),
                    value: _money(wallet.lockedBalance),
                    icon: HopeV2Icons.secure,
                    accent: secondaryAccent(context),
                    caption: _t('تا آزادسازی قابل استفاده نیست', 'Unavailable until released'),
                  ),
                  PremiumStatCard(
                    label: _t('برداشت‌های در جریان', 'Pending payouts'),
                    value: '${_pendingPayoutCount}',
                    icon: HopeV2Icons.pending,
                    accent: AppColors.warning,
                    caption: _t('درخواست‌های نیازمند پیگیری', 'Requests awaiting completion'),
                  ),
                ];
                return GridView.count(
                  crossAxisCount: columns,
                  childAspectRatio: columns == 1 ? 3.2 : 1.65,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: tiles,
                );
              },
            ),
            const SizedBox(height: 24),
            PremiumSectionHeader(
              title: _t('تاریخچه کیف پول', 'Wallet history'),
              subtitle: _t(
                'ثبت‌های مالی به ترتیب زمانی، با بارگذاری مرحله‌ای.',
                'Financial entries in chronological order, loaded in pages.',
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in const ['ALL', 'CREDIT', 'DEBIT', 'HOLD']) ...[
                    PremiumFilterChip(
                      label: switch (filter) {
                        'CREDIT' => _t('ورودی', 'Credits'),
                        'DEBIT' => _t('خروجی', 'Debits'),
                        'HOLD' => _t('قفل‌ها', 'Holds'),
                        _ => _t('همه', 'All'),
                      },
                      selected: _historyFilter == filter,
                      onTap: () => setState(() => _historyFilter = filter),
                    ),
                    if (filter != 'HOLD') const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_visibleTransactions().isEmpty)
              HopeAsyncState(
                kind: HopeStateKind.empty,
                title: _t('تراکنشی پیدا نشد', 'No transactions found'),
                message: _t(
                  'برای این فیلتر هنوز فعالیت مالی ثبت نشده است.',
                  'There is no financial activity for this filter yet.',
                ),
              )
            else
              ..._visibleTransactions().map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    container: true,
                    button: true,
                    explicitChildNodes: false,
                    label:
                        '${_entryTitle(item)}، ${_directionLabel(item.direction)}، ${item.isCredit ? '+' : '-'}${_money(item.amount)}',
                    onTap: () => _showTransaction(item),
                    child: ExcludeSemantics(
                      child: PremiumPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _showTransaction(item),
                          leading: HopeIconTile(
                            _directionIcon(item.isCredit),
                            color: _directionColor(context, item.isCredit),
                            filled: true,
                            size: 44,
                          ),
                          title: Text(
                            _entryTitle(item),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${_date(item.createdAt)}\n${_referenceTypeLabel(item.referenceType)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            '${item.isCredit ? '+' : '-'}${_money(item.amount)}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _directionColor(context, item.isCredit),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            PremiumSectionHeader(
              title: _t('برداشت‌ها', 'Withdrawals'),
              subtitle: _t(
                'وضعیت درخواست‌های برداشت داخلی.',
                'Status of your withdrawal requests.',
              ),
            ),
            const SizedBox(height: 12),
            if (_payouts.isEmpty)
              PremiumPanel(
                padding: const EdgeInsets.all(18),
                child: Text(
                  _t(
                    'درخواستی برای برداشت ثبت نشده است.',
                    'No withdrawal requests yet.',
                  ),
                ),
              )
            else
              ..._payouts.take(10).map(
                (payout) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PremiumPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Semantics(
                      container: true,
                      button: true,
                      excludeSemantics: true,
                      label:
                          '${_money(payout.amount)}، ${_providerLabel(payout.provider)}، ${_payoutLabel(payout.status)}',
                      onTap: () => _showPayout(payout),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _showPayout(payout),
                        leading: HopeIconTile(
                          _payoutIcon(payout.status),
                          color: _payoutColor(context, payout.status),
                          filled: true,
                          size: 44,
                        ),
                        title: Text(
                          _money(payout.amount),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${_date(payout.createdAt)}\n${_providerLabel(payout.provider)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: StatusPill(
                          _payoutLabel(payout.status),
                          color: _payoutColor(context, payout.status),
                          icon: _payoutIcon(payout.status),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_nextCursor != null && _nextCursor!.isNotEmpty) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(_t('تراکنش‌های بیشتر', 'Load more')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(width: 16),
            Flexible(
              child: SelectableText(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({
    required this.isEnglish,
    this.maxAmount,
    this.maxAmountLabel,
  });
  final bool isEnglish;
  final int? maxAmount;
  final String? maxAmountLabel;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final destination = TextEditingController();
  final amount = TextEditingController();
  String? errorText;

  String t(String fa, String en) => widget.isEnglish ? en : fa;

  @override
  void dispose() {
    destination.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(t('انتقال داخلی', 'Internal transfer')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: destination,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: t('شناسه کیف پول مقصد', 'Destination wallet ID')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
              onChanged: (_) { if (errorText != null) setState(() => errorText = null); },
              decoration: InputDecoration(
                labelText: t('مبلغ به تومان', 'Amount in Toman'),
                suffixText: t('تومان', 'Toman'),
                helperText: widget.maxAmountLabel == null
                    ? null
                    : t(
                        'حداکثر: ${widget.maxAmountLabel!}',
                        'Maximum: ${widget.maxAmountLabel!}',
                      ),
                errorText: errorText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('انصراف', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final target = destination.text.trim();
              final value = int.tryParse(amount.text.trim());
              const maxFinancialAmount = 9000000000000000;
              if (target.isEmpty) {
                setState(() => errorText = t('شناسه کیف پول مقصد را وارد کنید.', 'Enter a destination wallet ID.'));
                return;
              }
              if (value == null || value <= 0 || value > maxFinancialAmount) {
                setState(() => errorText = t('مبلغ واردشده معتبر نیست.', 'Enter a valid amount within the financial limit.'));
                return;
              }
              if (widget.maxAmount != null && value > widget.maxAmount!) {
                setState(() => errorText = t('مبلغ از موجودی قابل استفاده بیشتر است.', 'Amount exceeds your available balance.'));
                return;
              }
              Navigator.pop(context, (target, value));
            },
            child: Text(t('انتقال', 'Transfer')),
          ),
        ],
      );
}
