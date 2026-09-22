import 'package:flutter/material.dart';
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

  IconData _directionIcon(bool credit) => credit ? Icons.south_west_rounded : Icons.north_east_rounded;

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
                  const HopeIconTile(Icons.south_west_rounded),
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
                HopeSurface(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded),
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

  IconData _payoutIcon(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCEEDED': return Icons.check_circle_outline;
      case 'FAILED': return Icons.error_outline;
      case 'UNKNOWN': return Icons.help_outline;
      default: return Icons.schedule_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isGuest) {
      return Center(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: _t('کیف پول خصوصی است', 'Your wallet is private'),
          message: _t('برای مشاهده و مدیریت کیف پول وارد حساب شوید.', 'Sign in to view and manage your wallet.'),
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
              kind: HopeStateKind.error,
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
    return RefreshIndicator(
      onRefresh: _load,
      child: PremiumPageFrame(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (_error != null) ...[
              HopeAsyncState(
                kind: HopeStateKind.error,
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
                'موجودی، انتقال داخلی و تاریخچه مالی.',
                'Balance, internal transfers, and financial history.',
              ),
              trailing: PremiumTag(
                icon: Icons.shield_outlined,
                label: wallet.isActive
                    ? _t('فعال', 'Active')
                    : _t('غیرفعال', 'Inactive'),
                color: wallet.isActive ? AppColors.success : AppColors.warning,
              ),
            ),
            const SizedBox(height: HopeV2Spacing.xl),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                boxShadow: HopeV2Shadows.hero,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const HopeIconTile(
                        Icons.account_balance_wallet_rounded,
                        size: 48,
                        filled: true,
                      ),
                      const Spacer(),
                      StatusPill(
                        _walletStatusLabel(wallet.status),
                        color: Colors.white,
                        icon: wallet.isActive
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _t('موجودی قابل استفاده', 'Available balance'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  FittedBox(
                    alignment: AlignmentDirectional.centerStart,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _money(wallet.availableBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('قفل‌شده: ', 'Locked: ') +
                        _money(wallet.lockedBalance),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          HopeSurface(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t('شناسه کیف پول', 'Wallet ID'), style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 3),
                      SelectableText(wallet.id, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _t('کپی شناسه', 'Copy wallet ID'),
                  onPressed: wallet.id.isEmpty ? null : () => _copyText(wallet.id),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_internalTopUpEnabled)
                _ActionButton(icon: Icons.add_rounded, label: _t('شارژ', 'Top up'), onTap: (!_actionBusy && wallet.isActive) ? _openTopUp : null),
              _ActionButton(icon: Icons.swap_horiz_rounded, label: _t('انتقال', 'Transfer'), onTap: (!_actionBusy && wallet.isActive) ? _openTransfer : null),
              _ActionButton(icon: Icons.south_west_rounded, label: _t('برداشت', 'Withdraw'), onTap: (!_actionBusy && wallet.isActive) ? _openWithdraw : null),
            ],
          ),
          if (!wallet.isActive) ...[
            const SizedBox(height: 10),
            HopeSurface(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t(
                        'کیف پول فعال نیست؛ عملیات مالی جدید تا فعال‌شدن آن در دسترس نیست.',
                        'This wallet is not active. New financial actions are unavailable until it is reactivated.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 680
                      ? 2
                      : 1;
              final tiles = [
                PremiumStatCard(
                  label: _t('موجودی قابل‌استفاده', 'Available balance'),
                  value: _money(wallet.availableBalance),
                  icon: Icons.account_balance_wallet_outlined,
                  caption: _t('قابل خرج یا انتقال', 'Ready to spend or transfer'),
                ),
                PremiumStatCard(
                  label: _t('قفل‌شده', 'Locked balance'),
                  value: _money(wallet.lockedBalance),
                  icon: Icons.lock_clock_outlined,
                  accent: secondaryAccent(context),
                  caption: _t('تا آزادسازی قابل استفاده نیست', 'Unavailable until released'),
                ),
                PremiumStatCard(
                  label: _t('برداشت‌های در جریان', 'Pending payouts'),
                  value: '$_pendingPayoutCount',
                  icon: Icons.schedule_send_outlined,
                  accent: AppColors.warning,
                  caption: _t('درخواست‌های نیازمند پیگیری', 'Requests awaiting completion'),
                ),
              ];
              return GridView.count(
                crossAxisCount: columns,
                childAspectRatio: 1.55,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: tiles,
              );
            },
          ),
          const SizedBox(height: 24),
          SectionTitle(
            title: _t('تاریخچه کیف پول', 'Wallet history'),
            subtitle: _t('ثبت‌های مالی به ترتیب زمانی، با بارگذاری مرحله‌ای.', 'Financial entries in chronological order, loaded in pages.'),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 8,
              children: [
                for (final filter in const ['ALL', 'CREDIT', 'DEBIT', 'HOLD'])
                  ChoiceChip(
                    selected: _historyFilter == filter,
                    onSelected: (_) => setState(() => _historyFilter = filter),
                    label: Text(switch (filter) {
                      'CREDIT' => _t('ورودی', 'Credits'),
                      'DEBIT' => _t('خروجی', 'Debits'),
                      'HOLD' => _t('قفل‌ها', 'Holds'),
                      _ => _t('همه', 'All'),
                    }),
                  ),
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
            ..._visibleTransactions().map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HopeSurface(
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Semantics(
                  container: true,
                  button: true,
                  excludeSemantics: true,
                  label: '${_entryTitle(item)}، ${_directionLabel(item.direction)}، ${item.isCredit ? '+' : '-'}${_money(item.amount)}',
                  onTap: () => _showTransaction(item),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showTransaction(item),
                    leading: HopeIconTile(
                    _directionIcon(item.isCredit),
                    color: _directionColor(context, item.isCredit),
                    filled: true,
                    size: 44,
                  ),
                  title: Text(_entryTitle(item), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${_date(item.createdAt)}\n${_referenceTypeLabel(item.referenceType)}'),
                  isThreeLine: true,
                  trailing: Text(
                    '${item.isCredit ? '+' : '-'}${_money(item.amount)}',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontWeight: FontWeight.w900, color: _directionColor(context, item.isCredit)),
                  ),
                  ),
                ),
              ),
            )),
          const SizedBox(height: 24),
          SectionTitle(
            title: _t('برداشت‌ها', 'Withdrawals'),
            subtitle: _t('وضعیت درخواست‌های برداشت داخلی.', 'Status of your withdrawal requests.'),
          ),
          const SizedBox(height: 12),
          if (_payouts.isEmpty)
            HopeSurface(
              padding: const EdgeInsets.all(20),
              child: Text(_t('درخواستی برای برداشت ثبت نشده است.', 'No withdrawal requests yet.')),
            )
          else
            ..._payouts.take(10).map((payout) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HopeSurface(
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Semantics(
                  container: true,
                  button: true,
                  excludeSemantics: true,
                  label: '${_money(payout.amount)}، ${_providerLabel(payout.provider)}، ${_payoutLabel(payout.status)}',
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
                  title: Text(_money(payout.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${_date(payout.createdAt)}\n${_providerLabel(payout.provider)}'),
                  isThreeLine: true,
                  trailing: StatusPill(
                    _payoutLabel(payout.status),
                    color: _payoutColor(context, payout.status),
                    icon: _payoutIcon(payout.status),
                  ),
                  ),
                ),
              ),
            )),
          if (_nextCursor != null && _nextCursor!.isNotEmpty) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
                        'حداکثر: ' + widget.maxAmountLabel!,
                        'Maximum: ' + widget.maxAmountLabel!,
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
