import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/vazirmatn_loader.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadVazirmatnFont();
  await testMain();
}
