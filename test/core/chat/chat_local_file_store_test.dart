import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/chat/chat_local_file_store.dart';

void main() {
  test('temporary voice media is written and its isolated directory can be cleaned', () async {
    const store = IoChatLocalFileStore();
    final temporary = await store.createTemporaryMediaFile(
      Uint8List.fromList([1, 2, 3, 4]),
      'm4a',
    );
    addTearDown(() async {
      try {
        await store.deleteDirectory(temporary.directoryPath);
      } catch (_) {}
    });

    expect(await store.fileExists(temporary.path), isTrue);
    expect(await File(temporary.path).readAsBytes(), [1, 2, 3, 4]);

    await store.deleteDirectory(temporary.directoryPath);

    expect(await store.fileExists(temporary.path), isFalse);
  });

  test('temporary media extension is reduced to a safe filename token', () async {
    const store = IoChatLocalFileStore();
    final temporary = await store.createTemporaryMediaFile(
      Uint8List.fromList([5, 6]),
      '../m4a',
    );
    addTearDown(() async {
      try {
        await store.deleteDirectory(temporary.directoryPath);
      } catch (_) {}
    });

    expect(temporary.path.split(Platform.pathSeparator).last, 'voice.m4a');
    expect(await store.fileExists(temporary.path), isTrue);
  });
}
