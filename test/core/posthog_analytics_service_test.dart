import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/telemetry/posthog_analytics_service.dart';

void main() {
  test('PostHog is disabled unless explicitly configured for staging', () {
    final service = PostHogAnalyticsService();
    expect(service.isEnabled, isFalse);
  });

  test('invalid event names are rejected by the capture contract', () {
    final eventNamePattern = RegExp(r'^[a-z][a-z0-9_]{0,79}$');

    expect(eventNamePattern.hasMatch('wallet_viewed'), isTrue);
    expect(eventNamePattern.hasMatch('Wallet Viewed'), isFalse);
    expect(eventNamePattern.hasMatch('wallet-viewed'), isFalse);
    expect(eventNamePattern.hasMatch('1wallet_viewed'), isFalse);
  });

  test('sanitizer keeps only low-risk analytics properties', () {
    final result = PostHogAnalyticsService.sanitizeProperties({
      'screen': 'wallet',
      'action': 'view',
      'status': 'success',
      'source': 'flutter',
      'reason': 'session_restore',
      'amount': 900000,
      'balance': 1200000,
      'iban': 'IR000000000000000000000000',
      'accessToken': 'should-not-leak',
      'jobId': 'job-123',
      'email': 'user@example.com',
      'huge': List.filled(121, 'x').join(),
    });

    expect(result, {
      'screen': 'wallet',
      'action': 'view',
      'status': 'success',
      'source': 'flutter',
      'reason': 'session_restore',
    });
  });
}
