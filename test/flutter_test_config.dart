import 'dart:async';

import 'package:hope_mobile/core/theme/vazirmatn_loader.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadVazirmatnFont();
  await testMain();
}
