import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui/hope_display_formatters.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/notifications/notification.dart';
import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/router/app_routes.dart';
import '../../core/transactions/transaction_repository.dart';
import '../../core/uploads/upload_queue.dart';

ApplicationRegistry _applicationRegistry(BuildContext context) => applicationRegistryOf(context);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<HopeNotification> items = const [];
  bool loading = true;
  String? error;
  HopeNotificationPreferences? preferences;
  bool preferencesLoading = false;
  int _loadRequestId = 0;
  String? _preferenceBusyKey;

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final requestId = ++_loadRequestId;
    final hasExistingItems = items.isNotEmpty;
    setState(() {
      error = null;
      if (!hasExistingItems) loading = true;
    });
    try {
      final page =
          await _applicationRegistry(context).listNotifications();
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        items = page.items;
        loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        error = apiErrorMessage(e,
            fallback:
                HopeCopy.of(context).copy_could_not_load_notifications_a904a88);
        loading = false;
      });
    }
  }

  Widget _notificationsLoadError({required bool retainsRows}) {
    return HopeAsyncState(
      kind: HopeStateKind.error,
      title: retainsRows
          ? _t(
              'اعلان‌ها قابل تازه‌سازی نیستند',
              'Could not refresh notifications',
            )
          : _t(
              'اعلان‌ها در دسترس نیستند',
              'Notifications unavailable',
            ),
      message: error ?? _t(
        'خطای نامشخص در دریافت اعلان‌ها',
        'An unknown error occurred while loading notifications.',
      ),
      action: FilledButton.icon(
        onPressed: loading ? null : _load,
        icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
        label: Text(HopeCopy.of(context).copy_retry_49f3eba),
      ),
    );
  }

  Future<void> _read(String id) async {
    try {
      await _applicationRegistry(context).markNotificationRead(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(apiErrorMessage(e,
                fallback:
                    HopeCopy.of(context).copy_operation_failed_eb38c4c))));
      }
      return;
    }
    await _load();
  }

  Future<void> _openPreferences() async {
    if (preferencesLoading) return;
    setState(() => preferencesLoading = true);
    try {
      preferences ??= await _applicationRegistry(context).loadNotificationPreferences();
      if (!mounted || preferences == null) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          var current = preferences!;
          return StatefulBuilder(
            builder: (context, setSheetState) => Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t('تنظیمات اعلان‌ها', 'Notification settings'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(_t('کانال‌ها و دسته‌بندی اعلان‌ها را کنترل کنید.', 'Control notification channels and categories.')),
                  const SizedBox(height: 12),
                  _preferenceSwitch(_t('اعلان داخل برنامه', 'In-app notifications'), current.inApp, (value) async { await _changePreference('inApp', () async { current = await _savePreference('inApp', value, current); setSheetState(() {}); }); }),
                  _preferenceSwitch('Push', current.push, (value) async { await _changePreference('push', () async { current = await _savePreference('push', value, current); setSheetState(() {}); }); }),
                  _preferenceSwitch(_t('ایمیل', 'Email'), current.email, (value) async { await _changePreference('email', () async { current = await _savePreference('email', value, current); setSheetState(() {}); }); }),
                  _preferenceSwitch(_t('به‌روزرسانی درخواست‌ها', 'Application updates'), current.applicationUpdates, (value) async { await _changePreference('applicationUpdates', () async { current = await _savePreference('applicationUpdates', value, current); setSheetState(() {}); }); }),
                  _preferenceSwitch(_t('به‌روزرسانی پرداخت‌ها', 'Payment updates'), current.paymentUpdates, (value) async { await _changePreference('paymentUpdates', () async { current = await _savePreference('paymentUpdates', value, current); setSheetState(() {}); }); }),
                  _preferenceSwitch(_t('بازاریابی', 'Marketing'), current.marketing, (value) async { await _changePreference('marketing', () async { current = await _savePreference('marketing', value, current); setSheetState(() {}); }); }),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(e, fallback: _t('ذخیره تنظیمات اعلان‌ها ناموفق بود.', 'Could not save notification settings.')),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => preferencesLoading = false);
    }
  }

  Future<void> _changePreference(
      String key, Future<void> Function() action) async {
    if (_preferenceBusyKey != null || !mounted) return;
    setState(() => _preferenceBusyKey = key);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                error,
                fallback: _t(
                  'ذخیره تنظیمات اعلان‌ها ناموفق بود.',
                  'Could not save notification settings.',
                ),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _preferenceBusyKey = null);
    }
  }

  Widget _preferenceSwitch(
      String title, bool value, Future<void> Function(bool) onChanged) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: value,
        onChanged: _preferenceBusyKey != null
            ? null
            : (next) => onChanged(next),
      );

  Future<HopeNotificationPreferences> _savePreference(
      String key, bool value, HopeNotificationPreferences current) async {
    final next = await _applicationRegistry(context).updateNotificationPreferences({key: value});
    preferences = next;
    return next;
  }

  Future<void> _openNotification(HopeNotification n) async {
    if (n.isUnread) {
      try { await _applicationRegistry(context).markNotificationRead(n.id); } catch (_) {}
    }
    if (!mounted) return;
    final jobId = n.jobId;
    if (n.paymentId != null && jobId != null && jobId.isNotEmpty) {
      await Navigator.push(context, HopeRoutes.transaction(
        repository: context.read<TransactionRepository>(),
        uploadQueue: context.read<UploadQueue>(),
        jobId: jobId,
      ));
      return;
    }
    if (jobId != null && jobId.isNotEmpty) {
      try {
        final job = await _applicationRegistry(context).getOpportunity(jobId);
        if (!mounted) return;
        await Navigator.push(context, HopeRoutes.jobDetail(job));
        return;
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('جزئیات پروژه در دسترس نیست.', 'Project details are unavailable.'))));
      }
    }
    await _load();
  }

  Future<void> _readAll() async {
    try {
      await _applicationRegistry(context).markAllNotificationsRead();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(apiErrorMessage(e,
                fallback:
                    HopeCopy.of(context).copy_operation_failed_eb38c4c))));
      }
      return;
    }
    await _load();
  }
  Widget _notificationCard(HopeNotification n) {
    final unread = n.isUnread;
    final compactText = MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final titleWidget = Text(
      n.title,
      key: ValueKey('notification-title-${n.id}'),
      maxLines: compactText ? null : 2,
      softWrap: true,
      overflow: compactText ? TextOverflow.visible : TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium,
    );
    final unreadTag = KeyedSubtree(
      key: ValueKey('notification-unread-tag-${n.id}'),
      child: PremiumTag(
        label: _t('جدید', 'New'),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    final heading = compactText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: unreadTag,
                  ),
                ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleWidget),
              if (unread) ...[
                const SizedBox(width: 8),
                unreadTag,
              ],
            ],
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumPanel(
        key: ValueKey('notification-card-${n.id}'),
        padding: const EdgeInsets.all(12),
        quiet: !unread,
        highlight: unread,
        semanticLabel: n.title,
        child: InkWell(
          onTap: n.hasAction || unread ? () => _openNotification(n) : null,
          borderRadius: BorderRadius.circular(HopeV2Radii.md),
          onLongPress: unread ? () => _read(n.id) : null,
          child: Semantics(
            // Match screen-reader semantics to the actual tap contract:
            // read notifications with a valid destination remain actionable.
            button: unread || n.hasAction,
            label: unread || n.hasAction
                ? '${n.title}، ${n.hasAction ? n.actionLabel : HopeCopy.of(context).copy_tap_to_mark_as_read_5c9917a}'
                : n.title,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HopeIconTile(
                  unread
                      ? HopeV2Icons.notifications
                      : HopeV2Icons.notifications,
                  filled: unread,
                  color: unread
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      const SizedBox(height: 5),
                      Text(
                        n.body,
                        key: ValueKey('notification-body-${n.id}'),
                        maxLines: compactText ? null : 3,
                        softWrap: true,
                        overflow: compactText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (n.hasAction) ...[
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => _openNotification(n),
                          icon: const HopeIcon(HopeV2Icons.arrowRight, size: 18),
                          label: Text(n.actionLabel),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Text(
                        HopeDisplayFormatter.relativeDateTime(
                              n.createdAt,
                              locale: Localizations.localeOf(context).languageCode,
                            ) ?? '',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final unreadCount = items.where((item) => item.isUnread).length;
    final unreadCountLabel = HopeDisplayFormatter.integer(
      unreadCount,
      locale: Localizations.localeOf(context).languageCode,
    );
    return Scaffold(
      body: SafeArea(
        child: PremiumPageFrame(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          child: Column(
            children: [
              PremiumHeader(
                page: HopePageId.notifications,
                domain: HopeProductDomain.communication,
                dense: true,
                eyebrow: _t('اعلان‌ها', 'NOTIFICATIONS'),
                title: _t('اعلان‌ها', 'Notifications'),
                subtitle: loading
                    ? _t(
                        'در حال دریافت آخرین اعلان‌ها',
                        'Loading latest notifications',
                      )
                    : error != null
                        ? _t(
                            'وضعیت اعلان‌ها تازه‌سازی نشد',
                            'Notification status could not be refreshed',
                          )
                        : unreadCount > 0
                            ? _t(
                                '$unreadCountLabel اعلان خوانده‌نشده در فهرست زیر',
                                '$unreadCountLabel unread in this list',
                              )
                            : _t(
                                'به‌روزرسانی درخواست‌ها، کارها و پرداخت‌ها • همه خوانده شده‌اند',
                                'Updates for applications, work, and payments • All caught up',
                              ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: _t('اقدامات اعلان', 'Notification actions'),
                      icon: const HopeIcon(HopeV2Icons.menu),
                      onSelected: (value) {
                        switch (value) {
                          case 'settings':
                            _openPreferences();
                            break;
                          case 'devices':
                            Navigator.push(
                              context,
                              HopeRoutes.notificationDevices(),
                            );
                            break;
                          case 'read':
                            if (unreadCount > 0) _readAll();
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'settings',
                          child: Text(
                            _t(
                              'تنظیمات اعلان‌ها',
                              'Notification settings',
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'devices',
                          child: Text(
                            _t(
                              'دستگاه‌های اعلان',
                              'Notification devices',
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'read',
                          enabled: unreadCount > 0,
                          child: Text(
                            HopeCopy.of(context).copy_mark_all_read_500a31c,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HopeV2Spacing.md),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: loading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: HopeV2Navigation.scrollEndPadding(context),
                          children: [
                            const SizedBox(height: 32),
                            HopeAsyncState(
                              kind: HopeStateKind.loading,
                              title: _t(
                                'در حال بارگذاری اعلان‌ها',
                                'Loading notifications',
                              ),
                              message: _t(
                                'آخرین به‌روزرسانی‌های حساب و کارهای شما در حال دریافت است.',
                                'The latest account and work updates are loading.',
                              ),
                            ),
                          ],
                        )
                      : error != null && items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: HopeV2Navigation.scrollEndPadding(context, top: 24),
                              children: [
                                _notificationsLoadError(retainsRows: false),
                              ],
                            )
                          : items.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: HopeV2Navigation.scrollEndPadding(context, top: 24),
                                  children: [
                                    PremiumEmptyState(
                                      icon: HopeV2Icons.notifications,
                                      title: _t(
                                        'اعلانی وجود ندارد',
                                        'No notifications',
                                      ),
                                      message: HopeCopy.of(context)
                                          .copy_you_have_no_new_notifications_45f9685,
                                      dense: true,
                                    ),
                                  ],
                                )
                              : ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: HopeV2Navigation.scrollEndPadding(context),
                                  children: [
                                    if (error != null) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _notificationsLoadError(
                                          retainsRows: true,
                                        ),
                                      ),
                                    ],
                                    ...items.map(_notificationCard),
                                  ],
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
