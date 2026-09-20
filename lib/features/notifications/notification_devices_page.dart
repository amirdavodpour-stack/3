import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui/components.dart';

import '../../core/notifications/notification_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/premium_components.dart';

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

  NotificationRepository get _repo => context.read<NotificationRepository>();

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _repo.listDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
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

  IconData _icon(String platform) {
    switch (platform.toUpperCase()) {
      case 'ANDROID':
        return Icons.android_rounded;
      case 'IOS':
        return Icons.phone_iphone_rounded;
      case 'WEB':
        return Icons.language_rounded;
      default:
        return Icons.devices_other_rounded;
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
    return Scaffold(
      appBar: AppBar(title: Text(_t('دستگاه‌های اعلان', 'Notification devices'))),
      body: PremiumPageFrame(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
          children: [
            PremiumHeader(
              eyebrow: _t('اعلان‌ها', 'NOTIFICATIONS'),
              title: _t('دستگاه‌های متصل', 'Connected devices'),
              subtitle: _t(
                'دستگاه‌هایی که Push برای حساب شما روی آن‌ها فعال است را ببینید و هرکدام را جداگانه غیرفعال کنید.',
                'Review devices registered for Push notifications and disable any device independently.',
              ),
              trailing: const HopeIconTile(Icons.devices_rounded, size: 50, filled: true),
            ),
            const SizedBox(height: 18),
            if (!_loading && _error == null)
              PremiumStatCard(
                label: _t('دستگاه فعال برای Push', 'Active Push devices'),
                value: '$activeCountExpr',
                icon: Icons.notifications_active_rounded,
                accent: Theme.of(context).colorScheme.primary,
                caption: _t(
                  'فقط توکن‌ها و وضعیت لازم برای مدیریت اعلان نمایش داده می‌شود.',
                  'Only the state needed to manage notifications is exposed.',
                ),
              ),
            if (!_loading && _error == null) const SizedBox(height: 12),
            if (_loading)
              const PremiumPanel(
                child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
              )
            else if (_error != null)
              PremiumPanel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 34),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_t('تلاش دوباره', 'Retry')),
                    ),
                  ],
                ),
              )
            else if (_devices.isEmpty)
              PremiumPanel(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.notifications_off_outlined, size: 38),
                    const SizedBox(height: 12),
                    Text(
                      _t('دستگاه فعالی برای اعلان ثبت نشده است.', 'No active notification devices are registered.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: _devices.map((device) {
                    final busy = _busyId == device.id;
                    return ListTile(
                      leading: HopeIconTile(_icon(device.platform), filled: true),
                      title: Text(
                        _platformLabel(device.platform),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Row(
                        children: [
                          PremiumTag(
                            icon: device.enabled
                                ? Icons.check_circle_rounded
                                : Icons.pause_circle_outline_rounded,
                            label: device.enabled
                                ? _t('فعال', 'Enabled')
                                : _t('غیرفعال', 'Disabled'),
                            color: device.enabled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ],
                      ),
                      trailing: device.enabled
                          ? TextButton(
                              onPressed: busy ? null : () => _disable(device),
                              child: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(_t('غیرفعال کنید', 'Disable')),
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 14),
            PremiumPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded),
                  const SizedBox(width: 10),
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
