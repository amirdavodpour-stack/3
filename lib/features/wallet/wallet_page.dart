import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

import '../../core/config/backend_capabilities.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/transactions/wallet.dart';
import '../../core/transactions/wallet_repository.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_display_formatters.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/ui/hope_signature_components.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/router/app_routes.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({
    super.key,
    required this.repository,
    this.showPrimaryNavigation = true,
  });

  final WalletRepository repository;
  final bool showPrimaryNavigation;

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
  BackendCapabilities? _backendCapabilities;
  bool _capabilitiesLookupAttempted = false;
  bool _capabilitiesSourceAvailable = false;
  bool _capabilitiesLoadFailed = false;
  bool _capabilitiesProviderMissing = false;
  bool _capabilitiesRetrying = false;
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
  final _historyKey = GlobalKey();

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  String _t(String fa, String en) => _isEnglish ? en : fa;

  bool get _capabilitiesResolved => _backendCapabilities != null;
  bool get _canWithdraw =>
      _backendCapabilities?.wallet == true &&
      _backendCapabilities?.walletWithdraw == true;
  bool get _canTransfer =>
      _backendCapabilities?.wallet == true &&
      _backendCapabilities?.walletTransfer == true;
  bool get _canDeposit =>
      _internalTopUpEnabled &&
      _backendCapabilities?.wallet == true &&
      _backendCapabilities?.walletDeposit == true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_capabilitiesLookupAttempted) return;
    _capabilitiesLookupAttempted = true;
    try {
      final repository = context.read<BackendCapabilitiesRepository>();
      _capabilitiesSourceAvailable = true;
      unawaited(_loadBackendCapabilities(repository));
    } on ProviderNotFoundException {
      _capabilitiesSourceAvailable = false;
      _capabilitiesProviderMissing = true;
      _capabilitiesLoadFailed = true;
    }
  }

  Future<void> _loadBackendCapabilities(
    BackendCapabilitiesRepository repository,
  ) async {
    try {
      final capabilities = await repository.load();
      if (!mounted) return;
      setState(() {
        _backendCapabilities = capabilities;
        _capabilitiesProviderMissing = false;
        _capabilitiesLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _backendCapabilities = null;
        _capabilitiesLoadFailed = true;
      });
    }
  }

  Future<void> _retryBackendCapabilities() async {
    if (_capabilitiesRetrying) return;
    final repository = context.read<BackendCapabilitiesRepository>();
    setState(() => _capabilitiesRetrying = true);
    try {
      await _loadBackendCapabilities(repository);
    } finally {
      if (mounted) setState(() => _capabilitiesRetrying = false);
    }
  }

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

  String _money(int amount) => HopeDisplayFormatter.money(
        amount,
        locale: Localizations.localeOf(context).languageCode,
      );

  String _signedMoney(HopeWalletTransaction item) =>
      HopeDisplayFormatter.signedMoney(
        item.amount,
        positive: item.isCredit,
        locale: Localizations.localeOf(context).languageCode,
      );

  String _date(String? raw) => HopeDisplayFormatter.relativeDateTime(
        raw,
        locale: Localizations.localeOf(context).languageCode,
      ) ?? '';

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

  String _transactionSemanticsLabel(HopeWalletTransaction item) {
    final date = _date(item.createdAt);
    return [
      _entryTitle(item),
      _directionLabel(item.direction),
      _signedMoney(item),
      if (date.isNotEmpty) date,
    ].join('، ');
  }

  Color _directionColor(BuildContext context, bool credit) => credit
      ? HopeV2SemanticColors.incomingAmount(context)
      : HopeV2SemanticColors.negativeAmount(context);

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
                  suffixText: _t('تومان', 'TOMAN'),
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
              const SizedBox(height: 12),
              _DetailRow(
                label: _t('مبلغ', 'Amount'),
                value: _signedMoney(item),
                valueColor: _directionColor(context, item.isCredit),
              ),
              _DetailRow(label: _t('جهت', 'Direction'), value: _directionLabel(item.direction)),

              if (item.balanceAfter != null)
                _DetailRow(
                    label: _t('موجودی پس از تراکنش', 'Balance after'),
                    value: _money(item.balanceAfter!),
                    valueColor: HopeV2SemanticColors.amount(context),
                  ),
              _DetailRow(label: _t('زمان', 'Timestamp'), value: _date(item.createdAt)),
            ],
          ),
        ),
      ),
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
              _DetailRow(
                label: _t('مبلغ', 'Amount'),
                value: _money(payout.amount),
                valueColor: _isPendingPayout(status)
                    ? HopeV2SemanticColors.pendingAmount(context)
                    : HopeV2SemanticColors.amount(context),
              ),
              _DetailRow(label: _t('وضعیت', 'Status'), value: _payoutLabel(status)),
              _DetailRow(label: _t('ارائه‌دهنده', 'Provider'), value: _providerLabel(payout.provider)),
              _DetailRow(label: _t('زمان ثبت', 'Created'), value: _date(payout.createdAt)),
              if (status == 'UNKNOWN')
                PremiumPanel(
                  glass: false,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HopeIcon( HopeV2Icons.pending, size: 20),
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

  bool _isPendingPayout(String status) => switch (status.toUpperCase()) {
        'REQUESTED' || 'RESERVED' || 'PROCESSING' || 'UNKNOWN' => true,
        _ => false,
      };

  Color _payoutColor(BuildContext context, String status) {
    switch (status.toUpperCase()) {
      case 'SUCCEEDED':
        return HopeV2SemanticColors.success(context);
      case 'FAILED':
        return HopeV2SemanticColors.error(context);
      default:
        // Pending and unknown payout states are financial status, not actions.
        return HopeV2SemanticColors.pending(context);
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
    final content = _buildContent(context);
    if (!widget.showPrimaryNavigation) return content;
    return PremiumPrimaryNavigationScaffold(
      selectedIndex: 3,
      onDestinationSelected: (index) => _navigatePrimary(context, index),
      child: content,
    );
  }

  void _navigatePrimary(BuildContext context, int index) {
    if (index == 3) return;
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        HopeRoutes.home(),
        (_) => false,
      );
      return;
    }
    final route = switch (index) {
      1 => HopeRoutes.jobs(),
      2 => HopeRoutes.transactions(),
      3 => HopeRoutes.walletFromContext(context),
      4 => HopeRoutes.profile(),
      _ => null,
    };
    if (route != null) {
      Navigator.of(context).pushReplacement(route);
    }
  }

  Widget _walletInitialLoadingSkeleton(
    BuildContext context, {
    required bool compact,
    required bool enlargedText,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final denseViewport = width < 800;
    final tightViewport = compact || denseViewport;

    Widget metricTile(double cellWidth, int index) => Container(
          constraints: BoxConstraints(minHeight: compact ? 36 : 40),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 7,
            vertical: compact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: HopeV2Colors.walletBalanceMetricFill,
            borderRadius: BorderRadius.circular(HopeV2Radii.sm),
            border: Border.all(color: HopeV2Colors.walletBalanceMetricBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(
                height: 9,
                width: cellWidth * (index.isEven ? .54 : .66),
                radius: HopeV2Radii.sm,
              ),
              const SizedBox(height: 4),
              SkeletonBox(
                height: 13,
                width: cellWidth * (index == 0 ? .72 : .58),
                radius: HopeV2Radii.sm,
              ),
            ],
          ),
        );

    Widget transactionRow(String keyName) => PremiumPanel(
          key: ValueKey(keyName),
          glass: false,
          quiet: true,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 9 : 12,
          ),
          child: Row(
            children: [
              SkeletonBox(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                radius: HopeV2Radii.md,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(height: 12, width: 148),
                    const SizedBox(height: 6),
                    const SkeletonBox(height: 10, width: 92),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const SkeletonBox(height: 14, width: 82),
            ],
          ),
        );

    Widget actionTile() => Padding(
          padding: const EdgeInsets.all(4),
          child: SkeletonBox(
            height: compact ? 36 : 40,
            radius: HopeV2Radii.md,
          ),
        );

    return Semantics(
      container: true,
      liveRegion: true,
      label: _t('در حال بارگذاری کیف پول', 'Loading wallet'),
      child: PremiumPageFrame(
        page: HopePageId.wallet,
        maxWidth: 1020,
        padding: EdgeInsets.fromLTRB(
          tightViewport ? 12 : 16,
          tightViewport ? 6 : 14,
          tightViewport ? 12 : 16,
          tightViewport ? 12 : 20,
        ),
        child: ListView(
          padding: HopeV2Navigation.scrollEndPadding(context),
          children: [
            PremiumHeader(
              key: const ValueKey('wallet-loading-header'),
              dense: true,
              page: HopePageId.wallet,
              domain: HopeProductDomain.finance,
              eyebrow: _t('کیف پول', 'WALLET'),
              title: _t('کیف پول داخلی HOPE', 'HOPE internal wallet'),
              subtitle: denseViewport
                  ? null
                  : _t('موجودی و تراکنش‌های تومانی', 'Toman balance and transactions'),
            ),
            SizedBox(height: tightViewport ? 2 : HopeV2Spacing.sm),
            Column(
              key: const ValueKey('wallet-loading-skeleton'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const ValueKey('wallet-loading-balance-hero'),
                  padding: EdgeInsets.fromLTRB(
                    14,
                    compact ? 10 : 14,
                    14,
                    compact ? 10 : 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(HopeV2Radii.hero),
                    gradient: const LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        HopeV2Colors.walletBalanceHeroStart,
                        HopeV2Colors.walletBalanceHeroMiddle,
                        HopeV2Colors.walletBalanceHeroEnd,
                      ],
                      stops: [0, .58, 1],
                    ),
                    border: Border.all(
                      color: HopeV2Colors.primary.withValues(alpha: .24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SkeletonBox(
                            width: 30,
                            height: 30,
                            radius: HopeV2Radii.md,
                          ),
                          const Spacer(),
                          const SkeletonBox(
                            width: 74,
                            height: 22,
                            radius: HopeV2Radii.sm,
                          ),
                          const SizedBox(width: 6),
                          const SkeletonBox(
                            width: 62,
                            height: 22,
                            radius: HopeV2Radii.sm,
                          ),
                        ],
                      ),
                      SizedBox(height: denseViewport ? 6 : 10),
                      const SkeletonBox(
                        width: 126,
                        height: 12,
                        radius: HopeV2Radii.sm,
                      ),
                      const SizedBox(height: 5),
                      const SkeletonBox(
                        width: 204,
                        height: 25,
                        radius: HopeV2Radii.sm,
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 4.0;
                          final singleColumn =
                              enlargedText || constraints.maxWidth < 280;
                          final cellWidth = singleColumn
                              ? constraints.maxWidth
                              : (constraints.maxWidth - gap) / 2;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (var i = 0; i < 4; i++)
                                SizedBox(
                                  width: cellWidth,
                                  child: metricTile(cellWidth, i),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 4 : 12),
                PremiumPanel(
                  key: const ValueKey('wallet-loading-actions'),
                  quiet: true,
                  padding: EdgeInsets.zero,
                  child: enlargedText && denseViewport
                      ? Column(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) const SizedBox(height: 6),
                              actionTile(),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(child: actionTile()),
                            ],
                          ],
                        ),
                ),
                SizedBox(height: compact ? 8 : 12),
                PremiumSectionHeader(
                  key: const ValueKey('wallet-loading-history-title'),
                  domain: HopeProductDomain.finance,
                  title: _t('تاریخچه کیف پول', 'Wallet history'),
                  subtitle: compact
                      ? null
                      : _t(
                          'ثبت‌های مالی به ترتیب زمانی، با بارگذاری مرحله‌ای.',
                          'Financial entries in chronological order, loaded in pages.',
                        ),
                ),
                SizedBox(height: compact ? 8 : 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filterWidth in const [42.0, 58.0, 58.0, 52.0])
                      SkeletonBox(
                        width: filterWidth,
                        height: 28,
                        radius: HopeV2Radii.pill,
                      ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 12),
                transactionRow('wallet-loading-history-row-0'),
                const SizedBox(height: 8),
                transactionRow('wallet-loading-history-row-1'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final denseViewport = MediaQuery.sizeOf(context).width < 800;
    final tightViewport = compact || denseViewport;
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
      return _walletInitialLoadingSkeleton(
        context,
        compact: compact,
        enlargedText: enlargedText,
      );
    }

    if (_wallet == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: HopeV2Navigation.scrollEndPadding(context),
          children: [
            const SizedBox(height: 16),
            HopeAsyncState(
              kind: hopeStateKindForError(_error ?? StateError('wallet-load')),
              title: _t('کیف پول بارگذاری نشد', 'Wallet could not be loaded'),
              message: _t(
                'اتصال یا سرویس مالی در دسترس نبود. برای تلاش دوباره، دوباره بارگذاری کنید.',
                'The wallet service could not be reached. Refresh to try again.',
              ),
              action: OutlinedButton.icon(
                onPressed: _load,
                icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
                label: Text(_t('تلاش دوباره', 'Try again')),
              ),
            ),
          ],
        ),
      );
    }

    final wallet = _wallet!;
    final canAct = !_actionBusy && wallet.isActive && _capabilitiesResolved;

    Widget walletHeroMetric(
      BuildContext context,
      String label,
      String value, {
      String? keyName,
      bool emphasized = false,
    }) =>
        Container(
          key: keyName == null ? null : ValueKey(keyName),
          constraints: BoxConstraints(
            minHeight: emphasized ? (compact ? 42 : 46) : (compact ? 36 : 40),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: emphasized ? 10 : 6,
            vertical: compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: emphasized
                ? HopeV2Colors.primary.withValues(alpha: .18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              emphasized ? HopeV2Radii.md : HopeV2Radii.sm,
            ),
            border: emphasized
                ? Border.all(
                    color: HopeV2Colors.primary.withValues(alpha: .30),
                  )
                : Border.all(color: Colors.transparent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                softWrap: true,
                style: TextStyle(
                  color: emphasized ? HopeV2Colors.walletBalanceOnHero : HopeV2Colors.walletBalanceOnHeroMuted,
                  fontSize: 12,
                  height: 1.12,
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                softWrap: true,
                style: TextStyle(
                  color: HopeV2Colors.walletBalanceOnHero,
                  fontSize: emphasized ? 14 : 12,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );

    Widget balanceHero() {
      final scheme = Theme.of(context).colorScheme;
      final width = MediaQuery.sizeOf(context).width;
      final denseViewport = width < 800;
      final totalBalanceValue = _money(wallet.totalBalance);
      final longTotalBalance = totalBalanceValue.length > 18;
      final mediumViewport =
          !compact && width < 760 && !longTotalBalance;

      Widget totalBlock() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _t('کل موجودی', 'Total balance'),
                    style: const TextStyle(
                      color: HopeV2Colors.walletBalanceOnHeroMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _t('شامل مبالغ قفل‌شده است', 'Includes locked funds'),
                    style: const TextStyle(
                      color: HopeV2Colors.walletBalanceOnHeroSubtle,
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                totalBalanceValue,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: HopeV2Colors.walletBalanceOnHero,
                  fontSize: compact ? 22 : (denseViewport ? 26 : 32),
                  height: 1.02,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
             ],
          );

      final items = <({
        String key,
        String label,
        String value,
        bool emphasized,
      })>[
        (
          key: 'wallet-balance-metric-available',
          label: _t('قابل استفاده', 'Available'),
          value: _money(wallet.availableBalance),
          emphasized: true,
        ),
        (
          key: 'wallet-balance-metric-protected',
          label: _t('در امانت HOPE', 'Held in HOPE escrow'),
          value: _money(wallet.escrowBalance),
          emphasized: false,
        ),
        (
          key: 'wallet-balance-metric-pending',
          label: _t('برداشت در انتظار', 'Pending withdrawal'),
          value: _money(wallet.pendingWithdrawalBalance),
          emphasized: false,
        ),
        (
          key: 'wallet-balance-metric-locked-total',
          label: _t('کل قفل‌شده', 'Total locked'),
          value: _money(wallet.lockedBalance),
          emphasized: false,
        ),
      ];

      Widget cell(({
        String key,
        String label,
        String value,
        bool emphasized,
      }) item) {
        return Container(
          key: ValueKey(item.key),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 7,
            vertical: compact ? 1 : 3,
          ),
          decoration: BoxDecoration(
            color: item.emphasized
                ? HopeV2Colors.primary.withValues(alpha: .16)
                : HopeV2Colors.walletBalanceMetricFill,
            borderRadius: BorderRadius.circular(HopeV2Radii.sm),
            border: Border.all(
              color: item.emphasized
                  ? HopeV2Colors.walletBalanceMetricBorderEmphasized
                  : HopeV2Colors.walletBalanceMetricBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                maxLines: enlargedText ? null : 2,
                softWrap: true,
                overflow: enlargedText
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: item.emphasized ? HopeV2Colors.walletBalanceOnHero : HopeV2Colors.walletBalanceOnHeroMuted,
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                maxLines: null,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: HopeV2Colors.walletBalanceOnHero,
                  fontSize: item.emphasized ? 12.5 : 12,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }

      Widget metricsBlock() => LayoutBuilder(
            builder: (context, constraints) {
              final gap = compact ? 2.0 : 4.0;
              final longMetricCount = items.where((item) => item.value.length > 18).length;
                final singleColumnMetrics = enlargedText ||
                    constraints.maxWidth < 280 || longMetricCount >= 3;
              final cellWidth = singleColumnMetrics
                  ? constraints.maxWidth
                  : (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: cellWidth,
                      child: cell(item),
                    ),
                ],
              );
            },
          );

      return Container(
        key: const ValueKey('wallet-balance-hero'),
        padding: EdgeInsets.fromLTRB(
          14,
          compact ? 2 : 8,
          14,
          8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HopeV2Radii.hero),
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              HopeV2Colors.walletBalanceHeroStart,
              HopeV2Colors.walletBalanceHeroMiddle,
              HopeV2Colors.walletBalanceHeroEnd,
            ],
            stops: [0, .58, 1],
          ),
          border: Border.all(
            color: HopeV2Colors.primary.withValues(alpha: .24),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // English provider/status labels need a vertical rail on compact phones.
            if (width < 400 || enlargedText || longTotalBalance)
              Column(
                key: const ValueKey('wallet-provider-status'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HopeIconTile(
                        HopeV2Icons.wallet,
                        size: 30,
                        filled: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _providerLabel('INTERNAL'),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: HopeV2Colors.walletBalanceOnHero,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PremiumTag(
                      icon: wallet.isActive
                          ? HopeV2Icons.verified
                          : HopeV2Icons.pending,
                      label: _walletStatusLabel(wallet.status),
                      color: HopeV2Colors.walletBalanceOnHero,
                      inverse: true,
                    ),
                  ),
                ],
              )
            else
              Row(
                key: const ValueKey('wallet-provider-status'),
                children: [
                  HopeIconTile(
                    HopeV2Icons.wallet,
                    size: compact ? 28 : (denseViewport ? 30 : 36),
                    filled: true,
                  ),
                  const Spacer(),
                  PremiumTag(
                    icon: HopeV2Icons.secure,
                    label: _providerLabel('INTERNAL'),
                    color: scheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  PremiumTag(
                    icon: wallet.isActive
                        ? HopeV2Icons.verified
                        : HopeV2Icons.pending,
                    label: _walletStatusLabel(wallet.status),
                    color: HopeV2Colors.walletBalanceOnHero,
                    inverse: true,
                  ),
                ],
              ),
            SizedBox(height: denseViewport ? 2 : 8),
            if (mediumViewport)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: totalBlock()),
                  const SizedBox(width: 12),
                  Expanded(flex: 7, child: metricsBlock()),
                ],
              )
            else ...[
              totalBlock(),
              SizedBox(height: compact ? 1 : 6),
              metricsBlock(),
            ],
          ],
        ),
      );
    }

    Widget actionsPanel() {
      final stackActions = enlargedText && denseViewport;

      Widget action({
        required Object icon,
        required String fa,
        required String en,
        required VoidCallback? onPressed,
        bool primary = false,
      }) {
        final color = primary
            ? Theme.of(context).colorScheme.primary
            : HopeV2Colors.secondaryDark;
        final enabled = onPressed != null;

        return Semantics(
          button: true,
          enabled: enabled,
          label: _t(fa, en),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(HopeV2Radii.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: HopeV2Touch.minimum,
                ),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: primary
                        ? color.withValues(alpha: .15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(HopeV2Radii.md),
                    border: Border.all(
                      color: enabled
                          ? color.withValues(alpha: primary ? .22 : .12)
                          : color.withValues(alpha: .05),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HopeIcon(
                        icon,
                        color: enabled ? color : HopeV2Colors.darkMuted,
                        size: 19,
                        strokeWidth: 1.9,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _t(fa, en),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: enabled
                                ? HopeV2SemanticColors.readableAccent(
                                    context,
                                    color,
                                  )
                                : HopeV2Colors.darkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      final actionWidgets = <Widget>[];
      if (_canDeposit) {
        actionWidgets.add(
          action(
            icon: HopeV2Icons.transferIn,
            fa: 'واریز',
            en: 'Deposit',
            onPressed: canAct ? _openTopUp : null,
          ),
        );
      }
      if (_canWithdraw) {
        actionWidgets.add(
          action(
            icon: HopeV2Icons.transferOut,
            fa: 'برداشت',
            en: 'Withdraw',
            onPressed: canAct ? _openWithdraw : null,
            primary: true,
          ),
        );
      }
      actionWidgets.add(
        action(
          icon: HopeV2Icons.completed,
          fa: 'تاریخچه',
          en: 'History',
          onPressed: () {
            final target = _historyKey.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
            }
          },
        ),
      );

      return PremiumPanel(
        key: const ValueKey('wallet-actions-panel'),
        quiet: true,
        padding: EdgeInsets.zero,
        child: stackActions
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < actionWidgets.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == actionWidgets.length - 1 ? 0 : 6,
                      ),
                      child: actionWidgets[index],
                    ),
                ],
              )
            : Row(
                children: [
                  for (var index = 0; index < actionWidgets.length; index++) ...[
                    Expanded(child: actionWidgets[index]),
                    if (index < actionWidgets.length - 1)
                      const SizedBox(width: 6),
                  ],
                ],
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: PremiumPageFrame(
        page: HopePageId.wallet,
        maxWidth: 1020,
        padding: EdgeInsets.fromLTRB(
            tightViewport ? 12 : 16,
            tightViewport ? 6 : 14,
            tightViewport ? 12 : 16,
            tightViewport ? 12 : 20,
          ),
        child: ListView(
          padding: HopeV2Navigation.scrollEndPadding(context),
          children: [
            PremiumHeader(
              key: const ValueKey('wallet-finance-header'),
              dense: true,
              page: HopePageId.wallet,
              domain: HopeProductDomain.finance,
              eyebrow: _t('کیف پول', 'WALLET'),
              title: _t('کیف پول داخلی HOPE', 'HOPE internal wallet'),
              subtitle: denseViewport
                  ? null
                  : _t(
                      'موجودی و تراکنش‌های تومانی',
                      'Toman balance and transactions',
                    ),
              trailing: PopupMenuButton<String>(
                tooltip: _t('اقدامات کیف پول', 'Wallet actions'),
                icon: const HopeIcon(HopeV2Icons.menu),
                onSelected: (value) {
                  switch (value) {
                    case 'transfer':
                      if (canAct && _canTransfer) _openTransfer();
                      break;
                    case 'insights':
                      Navigator.push(
                        context,
                        HopeRoutes.financialInsights(),
                      );
                      break;
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'transfer',
                    enabled: canAct && _canTransfer,
                    child: Text(_t('انتقال داخلی', 'Transfer')),
                  ),
                  PopupMenuItem(
                    value: 'insights',
                    child: Text(_t('تحلیل مالی', 'Financial insights')),
                  ),
                ],
              ),
            ),
            SizedBox(height: tightViewport ? 2 : HopeV2Spacing.sm),
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
                  icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
                  label: Text(_t('تلاش دوباره', 'Try again')),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_capabilitiesLoadFailed)
              Padding(
                key: const ValueKey('wallet-capability-error'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          _capabilitiesProviderMissing
                              ? 'پیکربندی قابلیت‌های کیف پول در دسترس نیست؛ عملیات غیرفعال است.'
                              : 'وضعیت عملیات مالی از سرور دریافت نشد؛ عملیات مالی موقتاً غیرفعال است.',
                          _capabilitiesProviderMissing
                              ? 'Wallet actions are disabled because capability configuration is unavailable.'
                              : 'Wallet actions are temporarily disabled because server capabilities could not be loaded.',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (_capabilitiesSourceAvailable) ...[
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          key: const ValueKey('wallet-capability-retry'),
                          onPressed: _capabilitiesRetrying
                              ? null
                              : _retryBackendCapabilities,
                          icon: _capabilitiesRetrying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const HopeIcon(HopeV2Icons.refresh, size: 18),
                          label: Text(
                            _capabilitiesRetrying
                                ? _t('در حال تلاش دوباره…', 'Retrying…')
                                : _t('تلاش دوباره', 'Retry'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            SizedBox(height: tightViewport ? 2 : HopeV2Spacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final hero = balanceHero();
                final actions = actionsPanel();
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      hero,
                      SizedBox(height: compact ? 4 : 12),
                      actions,
                      SizedBox(height: compact ? 4 : 12),
                      if (!compact || enlargedText)
                        HopeWalletFlowSignature(wallet: wallet),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: hero),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: actions),
                      ],
                    ),
                    const SizedBox(height: 10),
                    HopeWalletFlowSignature(wallet: wallet),
                  ],
                );
              },
            ),
            SizedBox(
              key: const ValueKey('wallet-history-transition-gap'),
              // Short phones spend this gap on first-fold financial content;
              // taller compact screens retain a small editorial separation.
              height: compact
                  ? (MediaQuery.sizeOf(context).height <= 700 ? 0 : 4)
                  : (tightViewport ? 0 : 16),
            ),
            Container(
              key: _historyKey,
              child: PremiumSectionHeader(
                key: const ValueKey('wallet-history-title'),
                domain: HopeProductDomain.finance,
                title: _t('تاریخچه کیف پول', 'Wallet history'),
                subtitle: compact
                    ? null
                    : _t(
                        'ثبت‌های مالی به ترتیب زمانی، با بارگذاری مرحله‌ای.',
                        'Financial entries in chronological order, loaded in pages.',
                      ),
              ),
            ),
            SizedBox(height: compact ? 4 : 12),
            Wrap(
              key: const ValueKey('wallet-history-filters'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in const ['ALL', 'CREDIT', 'DEBIT', 'HOLD'])
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
              ],
            ),
            SizedBox(
              height: tightViewport ? 4 : (compact ? 8 : 12),
            ),
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
                    excludeSemantics: true,
                    label: _transactionSemanticsLabel(item),
                    onTap: () => _showTransaction(item),
                    child: ExcludeSemantics(
                      child: PremiumPanel(
                        key: ValueKey('wallet-history-entry-${item.id}'),
                        glass: false,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 14,
                          vertical: compact ? 9 : 12,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _showTransaction(item),
                          leading: HopeIconTile(
                            _directionIcon(item.isCredit),
                            color: _directionColor(context, item.isCredit),
                            filled: false,
                            size: compact ? 34 : 38,
                          ),
                          title: Semantics(
                            container: true,
                            label: _entryTitle(item),
                            child: Text(
                              _entryTitle(item),
                              maxLines: enlargedText ? null : 1,
                              softWrap: true,
                              overflow: enlargedText
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          subtitle: Text(
                            _date(item.createdAt),
                            maxLines: enlargedText ? null : 1,
                            softWrap: true,
                            overflow: enlargedText
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                          isThreeLine: enlargedText,
                          trailing: enlargedText
                              ? Text(
                                  _signedMoney(item),
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _directionColor(context, item.isCredit),
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _signedMoney(item),
                                    maxLines: 1,
                                    softWrap: false,
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
              ),
            if (_nextCursor != null && _nextCursor!.isNotEmpty) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                key: const ValueKey('wallet-transactions-load-more'),
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const HopeIcon(HopeV2Icons.arrowRight, size: 19),
                label: Text(_loadingMore
                    ? _t('در حال دریافت تراکنش‌ها…', 'Loading transactions…')
                    : _t('تراکنش‌های بیشتر', 'Load more transactions')),
              ),
            ],
            if (compact && !enlargedText) ...[
              const SizedBox(height: 8),
              HopeWalletFlowSignature(wallet: wallet),
            ],
            SizedBox(height: tightViewport ? 8 : 16),
            PremiumSectionHeader(
              key: const ValueKey('wallet-withdrawals-title'),
              domain: HopeProductDomain.finance,
              title: _t('برداشت‌ها', 'Withdrawals'),
              subtitle: _t(
                'وضعیت درخواست‌های برداشت داخلی.',
                'Status of your withdrawal requests.',
              ),
            ),
            const SizedBox(height: 12),
            if (_payouts.isEmpty)
              PremiumPanel(
                glass: true,
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
                    glass: false,
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
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _isPendingPayout(payout.status)
                                ? HopeV2SemanticColors.pendingAmount(context)
                                : HopeV2SemanticColors.amount(context),
                          ),
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
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

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
                style: TextStyle(fontWeight: FontWeight.w800, color: valueColor),
              ),
            ),
          ],
        ),
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
              key: const ValueKey('wallet-transfer-destination'),
              controller: destination,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: t('شناسه کیف پول مقصد', 'Destination wallet ID')),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('wallet-transfer-amount'),
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
              onChanged: (_) { if (errorText != null) setState(() => errorText = null); },
              decoration: InputDecoration(
                labelText: t('مبلغ به تومان', 'Amount in Toman'),
                suffixText: t('تومان', 'TOMAN'),
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
