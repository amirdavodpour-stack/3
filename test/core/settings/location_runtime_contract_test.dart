import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';

void main() {
  test('location requests are not hard-gated by unreliable service probes', () {
    final source =
        File('lib/core/settings/settings_controller.dart').readAsStringSync();
    expect(source, isNot(contains('if (!serviceEnabled)')));
    expect(source, contains('LocationServiceDisabledException'));
    expect(source, contains('timeLimit: Duration(seconds: 15)'));
  });


  test('location controller exposes distinct failure reasons', () {
    expect(LocationFailureReason.values, containsAll([
      LocationFailureReason.serviceDisabled,
      LocationFailureReason.permissionDenied,
      LocationFailureReason.positionUnavailable,
      LocationFailureReason.unsupportedPlatform,
    ]));
    final source = File('lib/core/settings/settings_controller.dart').readAsStringSync();
    expect(source, contains('onLocationFailure'));
    expect(source, contains('positionUnavailable'));
  });

  test('location operation exposes a busy gate and request generation guard', () {
    final source =
        File('lib/core/settings/settings_controller.dart').readAsStringSync();
    expect(source, contains('bool _locationBusy = false;'));
    expect(source, contains('int _locationRequestId = 0;'));
    expect(source, contains('if (_locationBusy) return false;'));
    expect(source, contains('requestId != _locationRequestId'));
    expect(source, contains('bool get locationBusy => _locationBusy;'));
  });

  test('location switch is disabled while the controller is busy', () {
    final source =
        File('lib/features/profile/profile_page.dart').readAsStringSync();
    expect(source, contains('onChanged: settings.locationBusy'));
  });

  test('location failures expose platform settings recovery actions', () {
    final source =
        File('lib/core/settings/settings_controller.dart').readAsStringSync();
    final profile =
        File('lib/features/profile/profile_page.dart').readAsStringSync();
    expect(source, contains('openLocationSettings()'));
    expect(source, contains('openAppSettings()'));
    expect(profile, contains('LocationFailureReason.serviceDisabled'));
    expect(profile, contains('LocationFailureReason.permissionDenied'));
    expect(profile, contains('SnackBarAction'));
  });

  test('location permission denial clears persisted location state', () {
    final source =
        File('lib/core/settings/settings_controller.dart').readAsStringSync();
    expect(source, contains("_prefs?.setBool(_locationKey, false)"));
    expect(source, contains("_prefs?.remove(_latitudeKey)"));
    expect(source, contains("_prefs?.remove(_longitudeKey)"));
  });
}


