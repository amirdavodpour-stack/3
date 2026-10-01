Future<void> main() async {
  const outputRoot = 'docs/audit/evidence/android-runtime';

  print('HOPE_DRIVER_CWD:${Directory.current.path}');
  print('HOPE_DRIVER_OUTPUT_ROOT:$outputRoot');

  await integrationDriver(
    responseDataCallback: null,
    onScreenshot: (String name, List<int> image, [Map<String, Object?>? args]) async {
      final file = File('$outputRoot/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(image, flush: true);
      print('HOPE_DRIVER_SCREENSHOT_WRITTEN:${file.path}:bytes=${image.length}');
      if (!await file.exists() || await file.length() < 16) {
        print('HOPE_DRIVER_SCREENSHOT_INVALID:${file.path}');
        return false;
      }
      final validPng = image.length >= 8 &&
          image[0] == 0x89 &&
          image[1] == 0x50 &&
          image[2] == 0x4e &&
          image[3] == 0x47 &&
          image[4] == 0x0d &&
          image[5] == 0x0a &&
          image[6] == 0x1a &&
          image[7] == 0x0a;
      if (!validPng) {
        print('HOPE_DRIVER_SCREENSHOT_INVALID_PNG:${file.path}');
      }
      return validPng;
    },
  );
}