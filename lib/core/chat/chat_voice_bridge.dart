import 'dart:async';

import 'package:flutter/services.dart';

/// Native Android recorder/player bridge without an additional package.
class HopeChatVoiceBridge {
  HopeChatVoiceBridge._();
  static const MethodChannel _channel = MethodChannel('hope.chat/voice');
  static final StreamController<void> _playbackCompletedController =
      StreamController<void>.broadcast();
  static bool _nativeEventHandlerInstalled = false;

  /// Emits when Android's MediaPlayer reaches the end of the current voice note.
  static Stream<void> get playbackCompleted {
    _installNativeEventHandler();
    return _playbackCompletedController.stream;
  }

  static void _installNativeEventHandler() {
    if (_nativeEventHandlerInstalled) return;
    _nativeEventHandlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'playbackCompleted') {
        _playbackCompletedController.add(null);
      }
    });
  }

  static Future<String> startRecording() async {
    final path = await _channel.invokeMethod<String>('startRecording');
    if (path == null || path.isEmpty) throw PlatformException(code: 'VOICE_RECORDING_FAILED');
    return path;
  }

  static Future<String> stopRecording() async {
    final path = await _channel.invokeMethod<String>('stopRecording');
    if (path == null || path.isEmpty) throw PlatformException(code: 'VOICE_RECORDING_FAILED');
    return path;
  }

  static Future<void> playFile(String path) => _channel.invokeMethod<void>('playFile', {'path': path});
  static Future<void> stopPlayback() => _channel.invokeMethod<void>('stopPlayback');
}
