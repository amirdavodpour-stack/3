import 'package:flutter/services.dart';

/// Native Android recorder/player bridge without an additional package.
class HopeChatVoiceBridge {
  HopeChatVoiceBridge._();
  static const MethodChannel _channel = MethodChannel('hope.chat/voice');

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
