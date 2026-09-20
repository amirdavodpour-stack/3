import 'dart:convert';

import 'package:flutter/services.dart';

const _vazirmatnAsset = 'assets/fonts/vazirmatn_wght.ttf.b64';

Future<void> loadVazirmatnFont() async {
  final encoded = await rootBundle.loadString(_vazirmatnAsset);
  final bytes = base64Decode(encoded);
  final loader = FontLoader('Vazirmatn');
  loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}
