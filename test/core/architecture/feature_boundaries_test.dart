import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture-contract tests that keep the feature layer decoupled:
///  1. No feature file may touch the transport layer (`package:http`) —
///     all networking must go through the core repositories.
///  2. No feature file may construct `MaterialPageRoute` directly —
///     navigation goes exclusively through `HopeRoutes` so routing policy
///     stays centralized in `lib/core/router`.
///  3. `dart:io` is allowed only in file-picking UI (picking a local file is
///     an inherently platform/UI concern and feeds the core upload queue).
void main() {
  final featureFiles = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('architecture fixture sanity: lib/features exists', () {
    expect(featureFiles, isNotEmpty, reason: 'lib/features should exist');
  });

  // File-picker and voice-attachment surfaces legitimately handle local paths
  // and pass files to core repositories. Keep this allow-list explicit so other
  // feature pages cannot import dart:io opportunistically.
  const allowedIoFiles = {
    'evidence_picker.dart',
    'transaction_page.dart',
    'chat_page.dart',
  };

  for (final file in featureFiles) {
    final rel = file.path.replaceAll('\\', '/');
    final basename = file.path.split(Platform.pathSeparator).last;

    test('feature file keeps transport out of the UI: $rel', () {
      final src = file.readAsStringSync();
      expect(src.contains("package:http/"), isFalse,
          reason: '$rel must not import package:http; use core repositories.');
      if (!allowedIoFiles.contains(basename)) {
        expect(src.contains('dart:io'), isFalse,
            reason: '$rel must not import dart:io; use core uploads.');
      }
    });

    test('feature file navigates only through HopeRoutes: $rel', () {
      final src = file.readAsStringSync();
      expect(src.contains('MaterialPageRoute('), isFalse,
          reason:
              '$rel must use HopeRoutes.* instead of raw MaterialPageRoute.');
    });
  }
}
