import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fail-open PostHog ingestion for HOPE staging.
///
/// This adapter intentionally has no dependency on PostHog SDK state. It uses
/// PostHog's documented public capture endpoint, while keeping the existing
/// first-party TelemetryService as the primary diagnostics path.
///
/// Safety properties:
/// - Never active outside HOPE_ENV=staging.
/// - Requires an explicit build-time POSTHOG_ENABLED=true and a project token.
/// - Reuses the first-party anonymous ID; no identify/person profile is sent.
/// - Only whitelisted low-risk event properties are forwarded.
/// - Never sends balances, amounts, IBANs, access/refresh tokens, stacks, or
///   arbitrary error messages to PostHog.
/// - All network failures are swallowed so analytics cannot block the product.
class PostHogAnalyticsService {
  static const _enabled = bool.fromEnvironment(
    'POSTHOG_ENABLED',
    defaultValue: false,
  );
  static const _environment = String.fromEnvironment(
    'HOPE_ENV',
    defaultValue: '',
  );
  static const _projectToken = String.fromEnvironment(
    'POSTHOG_PROJECT_TOKEN',
    defaultValue: '',
  );
  static const _legacyProjectToken = String.fromEnvironment(
    'POSTHOG_API_KEY',
    defaultValue: '',
  );
  static const _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  static const _allowedPropertyKeys = <String>{
    'action',
    'appVersion',
    'code',
    'environment',
    'feature',
    'mode',
    'platform',
    'reason',
    'releaseChannel',
    'result',
    'screen',
    'source',
    'status',
  };

  String get _effectiveProjectToken =>
      _projectToken.isNotEmpty ? _projectToken : _legacyProjectToken;

  bool get isEnabled =>
      _enabled &&
      _environment == 'staging' &&
      _effectiveProjectToken.isNotEmpty &&
      _validHost(_host);

  static bool _validHost(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }

  Future<void> capture(
    String eventName, {
    required String distinctId,
    Map<String, Object?> properties = const {},
  }) async {
    if (!isEnabled || distinctId.isEmpty) return;
    if (!RegExp(r'^[a-z][a-z0-9_]{0,79}$').hasMatch(eventName)) return;

    final sanitized = sanitizeProperties(properties);
    sanitized['platform'] ??= _platform;
    sanitized['environment'] = 'staging';
    sanitized['releaseChannel'] = 'staging';
    // Prevent anonymous events from creating person profiles.
    sanitized['\$process_person_profile'] = false;

    try {
      final host = _host.trim().replaceFirst(RegExp(r'/+$'), '');
      await http
          .post(
            Uri.parse('$host/i/v0/e/'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'api_key': _effectiveProjectToken,
              'event': eventName,
              'distinct_id': distinctId,
              'properties': sanitized,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Analytics must never affect the product path.
    }
  }

  Future<void> captureError({
    required String distinctId,
    required Object error,
    Map<String, Object?> context = const {},
  }) async {
    final safeContext = <String, Object?>{};
    for (final entry in context.entries) {
      if (entry.key == 'source' || entry.key == 'reason') {
        safeContext[entry.key] = entry.value;
      }
    }

    await capture(
      'app_error',
      distinctId: distinctId,
      properties: <String, Object?>{
        'source': 'flutter',
        'code': error.runtimeType.toString(),
        ...safeContext,
      },
    );
  }

  /// Public for focused unit tests and future analytics call sites.
  static Map<String, Object?> sanitizeProperties(
      Map<String, Object?> properties) {
    final sanitized = <String, Object?>{};
    for (final entry in properties.entries) {
      if (!_allowedPropertyKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value == null || value is bool || value is num) {
        sanitized[entry.key] = value;
      } else if (value is String && value.length <= 120) {
        sanitized[entry.key] = value;
      }
    }
    return sanitized;
  }

  String get _platform {
    if (kIsWeb) return 'WEB';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ANDROID';
      case TargetPlatform.iOS:
        return 'IOS';
      default:
        return 'UNKNOWN';
    }
  }
}
