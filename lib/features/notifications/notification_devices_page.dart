import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui/components.dart';

import '../../core/notifications/notification_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/hope_v2_design.dart';

class NotificationDevicesPage extends StatefulWidget {
  const NotificationDevicesPage({super.key});

  @override
  State<NotificationDevicesPage> createState() => _NotificationDevicesPageState();
}

class _NotificationDevicesPageState extends State<NotificationDevicesPage> {
  List<HopeNotificationDevice> _devices = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;
  int _loadRequestId = 0;

  NotificationRepository get _repo => context.read<NotificationRepository>();

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
    final hasExistingDevices = _devices.isNotEmpty;
    setState(() {
      _error = null;
      if (!hasExistingDevices) _loading = true;
    });
    try {
      final devices = await _repo.listDevices();
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(error,
            fallback: _t('دستگاه‌ها قابل دریافت نیستند.', 'Could not load notification devices.'));
      });
    }
  }

  Future<void> _disable(HopeNotificationDevice device) async {
    if (_busyId != null) return;
    setState(() => _busyId = device.id);
    try {
      await _repo.disableDevice(device.id);
      if (!mounted) return;
      setState(() {
        _devices = _devices.where((item) => item.id != device.id).toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error,
            fallback: _t('غیرفعال‌سازی دستگاه ناموفق بود.', 'Could not disable device.')))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Object _icon(String platform) {
    switch (platform.toUpperCase()) {
      case 'ANDROID':
        return HopeV2Icons.android;
      case 'IOS':
        return HopeV2Icons.apple;
      case 'WEB':
        return HopeV2Icons.web;
      default:
        return HopeV2Icons.device;
    }
  }

  String _platformLabel(String platform) {
    switch (platform.toUpperCase()) {
      case 'ANDROID':
        return 'Android';
      case 'IOS':
        return 'iPhone / iPad';
      case 'WEB':
        return 'Web';
      default:
        return platform.isEmpty ? _t('دستگاه', 'Device') : platform;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compactDeviceLayout =
        MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Scaffold(
      body: PremiumPageFrame(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: HopeV2Navigation.scrollEndPadding(context),
          children: [
            PremiumHeader(
              page: HopePageId.notificationDevices,
              domain: HopeProductDomain.communication,
              eyebrow: _t('اعلان‌ها', 'NOTIFICATIONS'),
              title: _t('دستگاه‌های متصل', 'Connected devices'),
              subtitle: _t(
                'دستگاه‌هایی که Push برای حساب شما روی آن‌ها فعال است را ببینید و هرکدام را جداگانه غیرفعال کنید.',
                'Review devices registered for Push notifications and disable any device independently.',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumIconButton(
                    icon: Localizations.localeOf(context).languageCode == 'en'
                        ? HopeV2Icons.arrowLeft
                        : HopeV2Icons.arrowRight,
                    tooltip: _t('بازگشت', 'Back'),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 8),
                  PremiumIconButton(
                    icon: HopeV2Icons.refresh,
                    tooltip: _t('بازخوانی', 'Refresh'),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (!_loading && _error == null)
              PremiumStatCard(
                label: _t('دستگاه فعال برای Push', 'Active Push devices'),
                value: '${_devices.where((device) => device.enabled).length}',
                icon: HopeV2Icons.notifications,
                accent: Theme.of(context).colorScheme.primary,
                caption: _t(
                  'فقط توکن‌ها و وضعیت لازم برای مدیریت اعلان نمایش داده می‌شود.',
                  'Only the state needed to manage notifications is exposed.',
                ),
              ),
            if (!_loading && _error == null) const SizedBox(height: 8),
            if (_loading)
              Semantics(
                container: true,
                liveRegion: true,
                label: _t('در حال بارگذاری دستگاه‌های اعلان', 'Loading notification devices'),
                child: PremiumPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const SkeletonBox(
                        width: 36,
                        height: 36,
                        radius: HopeV2Radii.md,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(height: 14, width: 112),
                            SizedBox(height: 6),
                            SkeletonBox(height: 10, width: 76),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SkeletonBox(
                        width: 64,
                        height: 28,
                        radius: HopeV2Radii.md,
                      ),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              PremiumPanel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const HopeIcon(HopeV2Icons.error, size: 28),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
                      label: Text(_t('تلاش دوباره', 'Retry')),
                    ),
                  ],
                ),
              )
            else if (_devices.isEmpty)
              PremiumPanel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const HopeIcon(HopeV2Icons.notifications, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      _t('دستگاه فعالی برای اعلان ثبت نشده است.', 'No active notification devices are registered.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t('وقتی Push را در یک دستگاه فعال کنید، اینجا نمایش داده می‌شود.',
                          'A device appears here after Push notifications are enabled.'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              PremiumPanel(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: _devices.map((device) {
                    final busy = _busyId == device.id;
                    final leading = HopeIconTile(
                      _icon(device.platform),
                      size: 36,
                      filled: true,
                    );
                    final title = Text(
                      _platformLabel(device.platform),
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    );
                    final status = PremiumTag(
                      icon: device.enabled
                          ? HopeV2Icons.completed
                          : HopeV2Icons.pending,
                      label: device.enabled
                          ? _t('فعال', 'Enabled')
                          : _t('غیرفعال', 'Disabled'),
                      color: device.enabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    );
                    final action = device.enabled
                        ? TextButton(
                            onPressed: busy ? null : () => _disable(device),
                            child: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(_t('غیرفعال کنید', 'Disable')),
                          )
                        : null;

                    if (compactDeviceLayout) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                leading,
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      title,
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: status,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (action != null)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: action,
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    return ListTile(
                      leading: leading,
                      title: title,
                      subtitle: Row(children: [status]),
                      trailing: action,
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 14),
            PremiumPanel(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HopeIcon(HopeV2Icons.insights, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_t(
                      'این صفحه فقط دستگاه‌های ثبت‌شده را مدیریت می‌کند؛ توکن Push خام در رابط کاربری نمایش داده نمی‌شود.',
                      'This screen manages registered devices without exposing raw Push tokens in the UI.',
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
}
