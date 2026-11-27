import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';

/// Abstraction for native file rename, delete, and OS share sheet actions.
abstract interface class MediaFileOperations {
  Future<String> renameVideo(VideoItem item, String newBaseName);
  Future<void> deleteVideo(VideoItem item);
  Future<void> shareVideo(VideoItem item);
}

/// Platform implementation supporting direct disk files, MediaStore deletion,
/// and `share_plus` sharing.
class DeviceMediaFileOperations implements MediaFileOperations {
  const DeviceMediaFileOperations();

  @override
  Future<String> renameVideo(VideoItem item, String newBaseName) async {
    final cleaned = newBaseName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    if (cleaned.isEmpty) {
      throw const SubtitleFileException('Filename cannot be empty.');
    }

    if (item.filePath.contains('://')) {
      throw const StoragePermissionException(
        'Cannot rename content-provider URIs directly on this OS version.',
      );
    }

    final file = File(item.filePath);
    if (!await file.exists()) {
      throw const SubtitleFileException('Original video file no longer exists.');
    }

    final ext = p.extension(item.filePath);
    final newPath = p.join(p.dirname(item.filePath), '$cleaned$ext');
    if (newPath == item.filePath) return newPath;

    if (await File(newPath).exists()) {
      throw const SubtitleFileException(
        'A file with that name already exists in this folder.',
      );
    }

    final renamed = await file.rename(newPath);
    return renamed.path;
  }

  @override
  Future<void> deleteVideo(VideoItem item) async {
    final assetId = item.assetId;
    if (!kIsWeb &&
        (Platform.isAndroid || Platform.isIOS) &&
        assetId != null &&
        assetId.isNotEmpty) {
      final deleted = await PhotoManager.editor.deleteWithIds(<String>[assetId]);
      if (deleted.isNotEmpty) return;
    }

    if (!item.filePath.contains('://')) {
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Future<void> shareVideo(VideoItem item) async {
    if (item.filePath.contains('://')) {
      await SharePlus.instance.share(
        ShareParams(text: '${item.title}\n${item.filePath}'),
      );
      return;
    }

    final file = File(item.filePath);
    if (!await file.exists()) {
      throw const SubtitleFileException('File not found to share.');
    }

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        text: item.title,
      ),
    );
  }
}
