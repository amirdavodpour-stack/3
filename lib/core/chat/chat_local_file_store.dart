import 'dart:io';
import 'dart:typed_data';

class ChatTemporaryMediaFile {
  const ChatTemporaryMediaFile({
    required this.path,
    required this.directoryPath,
  });

  final String path;
  final String directoryPath;
}

abstract interface class ChatLocalFileStore {
  Future<void> deleteFile(String path);
  Future<bool> fileExists(String path);
  Future<ChatTemporaryMediaFile> createTemporaryMediaFile(
    Uint8List bytes,
    String extension,
  );
  Future<void> deleteDirectory(String path);
}

/// The only chat-layer adapter allowed to touch the local file system.
///
/// UI code passes picked/recorded paths through this boundary; repositories
/// perform the upload and the store owns temporary media lifecycle.
class IoChatLocalFileStore implements ChatLocalFileStore {
  const IoChatLocalFileStore();

  @override
  Future<void> deleteFile(String path) async {
    await File(path).delete();
  }

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<void> deleteDirectory(String path) async {
    await Directory(path).delete(recursive: true);
  }

  @override
  Future<ChatTemporaryMediaFile> createTemporaryMediaFile(
    Uint8List bytes,
    String extension,
  ) async {
    final normalizedExtension = extension
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final safeExtension = normalizedExtension.isNotEmpty &&
            normalizedExtension.length <= 8
        ? normalizedExtension
        : 'm4a';
    final directory =
        await Directory.systemTemp.createTemp('hope-chat-voice-');
    try {
      final file = File('${directory.path}/voice.$safeExtension');
      await file.writeAsBytes(bytes, flush: true);
      return ChatTemporaryMediaFile(
        path: file.path,
        directoryPath: directory.path,
      );
    } catch (_) {
      try {
        await directory.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }
}
