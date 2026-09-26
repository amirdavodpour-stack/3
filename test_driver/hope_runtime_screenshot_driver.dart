import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    responseDataCallback: null,
    onScreenshot:
        (String name, List<int> image, [Map<String, Object?>? args]) async {
      if (image.length < 16) {
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
