import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final root = Platform.environment['HOPE_SCREENSHOT_OUTPUT_ROOT'];
  if (root == null || root.isEmpty) {
    throw StateError('HOPE_SCREENSHOT_OUTPUT_ROOT is required.');
  }

  final directory = Directory(root);
  await directory.create(recursive: true);

  await integrationDriver(
    responseDataCallback: null,
    onScreenshot: (String name, List<int> image, [Map<String, Object?>? args]) async {
      final file = File('\${directory.path}/\$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(image, flush: true);
      if (!await file.exists() || await file.length() < 16) {
        return false;
      }
      return image.length >= 8 &&
          image[0] == 0x89 &&
          image[1] == 0x50 &&
          image[2] == 0x4e &&
          image[3] == 0x47 &&
          image[4] == 0x0d &&
          image[5] == 0x0a &&
          image[6] == 0x1a &&
          image[7] == 0x0a;
    },
  );
}
