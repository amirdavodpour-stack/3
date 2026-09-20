import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/notifications/notification.dart';
import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/network/api_error_presenter.dart';

import '../../core/ui/premium_components.dart';
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

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page =
          await _applicationRegistry(context).listNotifications();
      if (!mounted) return;
      setState(() {
        items = page.items;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = apiErrorMessage(e,
            fallback:
                HopeCopy.of(context).copy_could_not_load_notifications_a904a88);
        loading = false;
      });
    }
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
                  _preferenceSwitch(_t('اعلان داخل برنامه', 'In-app notifications'), current.inApp, (value) async { current = await _savePreference('inApp', value, current); setSheetState(() {}); }),
                  _preferenceSwitch('Push', current.push, (value) async { current = await _savePreference('push', value, current); setSheetState(() {}); }),
                  _preferenceSwitch(_t('ایمیل', 'Email'), current.email, (value) async { current = await _savePreference('email', value, current); setSheetState(() {}); }),
                  _preferenceSwitch(_t('به‌روزرسانی درخواست‌ها', 'Application updates'), current.applicationUpdates, (value) async { current = await _savePreference('applicationUpdates', value, current); setSheetState(() {}); }),
                  _preferenceSwitch(_t('به‌روزرسانی پرداخت‌ها', 'Payment updates'), current.paymentUpdates, (value) async { current = await _savePreference('paymentUpdates', value, current); setSheetState(() {}); }),
                  _preferenceSwitch(_t('بازاریابی', 'Marketing'), current.marketing, (value) async { current = await _savePreference('marketing', value, current); setSheetState(() {}); }),
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

  Widget _preferenceSwitch(String title, bool value, Future<void> Function(bool) onChanged) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: value,
        onChanged: (next) { onChanged(next); },
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumPanel(
        padding: const EdgeInsets.all(16),
        highlight: unread,
        semanticLabel: n.title,
        child: InkWell(
          onTap: n.hasAction || unread ? () => _openNotification(n) : null,
          borderRadius: BorderRadius.circular(18),
          onLongPress: unread ? () => _read(n.id) : null,
          child: Semantics(
            button: unread,
            label: unread
                ? '${n.title}، ${n.hasAction ? n.actionLabel : HopeCopy.of(context).copy_tap_to_mark_as_read_5c9917a}'
                : n.title,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HopeIconTile(
                  unread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  filled: unread,
                  color: unread
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 8),
                            PremiumTag(
                              label: _t('جدید', 'New'),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        n.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (n.hasAction) ...[
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: () => _openNotification(n),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(n.actionLabel),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Text(
                        n.createdAt ?? '',
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(HopeCopy.of(context).copy_notifications_370b4a1),
          actions: [
            IconButton(
              onPressed: () =>
                  Navigator.push(context, HopeRoutes.notificationDevices()),
              icon: const Icon(Icons.devices_rounded),
              tooltip: _t('دستگاه‌های اعلان', 'Notification devices'),
            ),
            IconButton(
              onPressed: _openPreferences,
              icon: const Icon(Icons.tune_rounded),
              tooltip: _t('تنظیمات اعلان‌ها', 'Notification settings'),
            ),
            IconButton(
              onPressed: items.isEmpty ? null : _readAll,
              icon: const Icon(Icons.done_all_rounded),
              tooltip: HopeCopy.of(context).copy_mark_all_read_500a31c,
            ),
          ],
        ),
        body: PremiumPageFrame(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          child: RefreshIndicator(
            onRefresh: _load,
            child: loading
                ? const ListView(
                    children: [
                      SizedBox(height: 280),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : error != null
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          EmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: HopeCopy.of(context)
                                .copy_could_not_load_notifications_a904a88,
                            message: error!,
                            action: FilledButton(
                              onPressed: _load,
                              child:
                                  Text(HopeCopy.of(context).copy_retry_49f3eba),
                            ),
                          ),
                        ],
                      )
                    : items.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              EmptyState(
                                icon: Icons.notifications_none_rounded,
                                title: _t('اعلانی وجود ندارد', 'No notifications'),
                                message: HopeCopy.of(context)
                                    .copy_you_have_no_new_notifications_45f9685,
                              ),
                            ],
                          )
                        : ListView(
                            padding:
                                const EdgeInsets.fromLTRB(0, 12, 0, 32),
                            children: [
                              PremiumHeader(
                                eyebrow: _t('اعلان‌ها', 'NOTIFICATIONS'),
                                title: _t('اعلان‌ها', 'Notifications'),
                                subtitle: _t(
                                  'به‌روزرسانی درخواست‌ها، کارها و پرداخت‌ها.',
                                  'Updates for applications, work, and payments.',
                                ),
                                trailing: PremiumTag(
                                  icon:
                                      Icons.notifications_active_outlined,
                                  label: items.length.toString(),
                                ),
                              ),
                              const SizedBox(height: 18),
                              ...items.map(_notificationCard),
                            ],
                          ),
          ),
        ),
      );
}
