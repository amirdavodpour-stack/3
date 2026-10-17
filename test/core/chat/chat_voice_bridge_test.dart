import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/chat/chat_voice_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('hope.chat/voice');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'startRecording': return '/cache/voice.m4a';
        case 'stopRecording': return '/cache/voice.m4a';
        case 'playFile': return true;
        case 'stopPlayback': return true;
        default: return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('native playback completion is forwarded to Dart listeners', () async {
    final completed = Completer<void>();
    final subscription = HopeChatVoiceBridge.playbackCompleted.listen((_) {
      if (!completed.isCompleted) completed.complete();
    });
    addTearDown(subscription.cancel);

    const codec = StandardMethodCodec();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'hope.chat/voice',
      codec.encodeMethodCall(const MethodCall('playbackCompleted')),
      (_) {},
    );

    await completed.future.timeout(const Duration(seconds: 1));
  });

  test('voice bridge dispatches native recording and playback controls', () async {
    expect(await HopeChatVoiceBridge.startRecording(), '/cache/voice.m4a');
    expect(await HopeChatVoiceBridge.stopRecording(), '/cache/voice.m4a');
    await HopeChatVoiceBridge.playFile('/cache/voice.m4a');
    await HopeChatVoiceBridge.stopPlayback();
    expect(calls, ['startRecording','stopRecording','playFile','stopPlayback']);
  });
}
