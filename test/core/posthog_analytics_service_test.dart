import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/telemetry/posthog_analytics_service.dart';

void main() {
  test('PostHog is disabled unless explicitly configured for staging', () {
    final service = PostHogAnalyticsService();
    expect(service.isEnabled, isFalse);
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
      'huge': 'x' * 121,
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
