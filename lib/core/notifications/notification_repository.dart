import '../network/api_client.dart';
import 'notification.dart';

class HopeNotificationDevice {
  const HopeNotificationDevice({
    required this.id,
    required this.platform,
    required this.enabled,
    this.createdAt,
  });

  final String id;
  final String platform;
  final bool enabled;
  final String? createdAt;

  factory HopeNotificationDevice.fromMap(Map<String, dynamic> map) =>
      HopeNotificationDevice(
        id: '${map['id'] ?? ''}',
        platform: '${map['platform'] ?? 'UNKNOWN'}'.toUpperCase(),
        enabled: map['enabled'] != false,
        createdAt: map['createdAt'] == null ? null : '${map['createdAt']}',
      );
}

abstract interface class NotificationRepository {
  Future<HopeNotificationPage> listNotifications(
      {int limit = 50, int offset = 0});
  Future<HopeNotification> markRead(String id);
  Future<int> markAllRead();
  Future<HopeNotificationPreferences> getPreferences();
  Future<HopeNotificationPreferences> updatePreferences(Map<String, bool> patch);
  Future<List<HopeNotificationDevice>> listDevices();
  Future<void> disableDevice(String id);
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api);
  final ApiClient _api;

  @override
  Future<HopeNotificationPage> listNotifications(
      {int limit = 50, int offset = 0}) async {
    final data = await _api.request(
      'GET',
      '/notifications?limit=$limit&offset=$offset',
      auth: true,
    );
    final map = Map<String, dynamic>.from(data as Map);
    final rawItems = map['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) =>
                HopeNotification.fromMap(Map<String, dynamic>.from(item)))
            .toList()
        : const <HopeNotification>[];
    return HopeNotificationPage(
      items: items,
      unreadCount:
          map['unreadCount'] is num ? (map['unreadCount'] as num).toInt() : 0,
    );
  }

  @override
  Future<HopeNotification> markRead(String id) async {
    final data =
        await _api.request('POST', '/notifications/$id/read', auth: true);
    return HopeNotification.fromMap(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<HopeNotificationPreferences> getPreferences() async {
    final data = await _api.request('GET', '/notifications/preferences', auth: true);
    return HopeNotificationPreferences.fromMap(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<HopeNotificationPreferences> updatePreferences(Map<String, bool> patch) async {
    final data = await _api.request(
      'PUT',
      '/notifications/preferences',
      auth: true,
      body: Map<String, dynamic>.from(patch),
    );
    return HopeNotificationPreferences.fromMap(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<int> markAllRead() async {
    final data =
        await _api.request('POST', '/notifications/read-all', auth: true);
    final map = Map<String, dynamic>.from(data as Map);
    return map['updated'] is num ? (map['updated'] as num).toInt() : 0;
  }

  @override
  Future<List<HopeNotificationDevice>> listDevices() async {
    final data = await _api.request('GET', '/notifications/devices', auth: true);
    final raw = data is Map ? data['items'] : data;
    if (raw is! List) return const <HopeNotificationDevice>[];
    return raw.whereType<Map>().map((item) =>
      HopeNotificationDevice.fromMap(Map<String, dynamic>.from(item))).toList();
  }

  @override
  Future<void> disableDevice(String id) async {
    await _api.request('DELETE', '/notifications/devices/$id', auth: true);
  }
}
