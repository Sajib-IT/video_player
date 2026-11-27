import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player_app/core/constants/media_formats.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';

/// Abstraction for scanning device video & audio files so tests stay pure.
abstract interface class LocalVideoScanner {
  Future<List<VideoItem>> scanVideos();
  Future<VideoItem?> pickSingleVideoFile();
}

/// Scans device storage via `photo_manager` (videos + audio/MP3) and app
/// downloads folder, with `file_picker` direct-file fallback.
class PhotoManagerVideoScanner implements LocalVideoScanner {
  const PhotoManagerVideoScanner();

  static const int _pageSize = 100;
  static const int _resolveBatchSize = 16;

  @override
  Future<List<VideoItem>> scanVideos() async {
    final seenKeys = <String>{};
    final items = <VideoItem>[];

    // Include completed downloads saved in app-local downloads folder.
    final downloaded = await _scanAppDownloadsFolder();
    for (final item in downloaded) {
      if (seenKeys.add(item.mediaKey)) {
        items.add(item);
      }
    }

    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      return items;
    }

    final filter = FilterOptionGroup(
      videoOption: const FilterOption(needTitle: true),
      audioOption: const FilterOption(needTitle: true),
      orders: const <OrderOption>[
        OrderOption(type: OrderOptionType.updateDate, asc: false),
      ],
    );

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.video + RequestType.audio,
      hasAll: false,
      filterOption: filter,
    );

    for (final album in paths) {
      final count = await album.assetCountAsync;
      if (count <= 0) continue;

      for (var start = 0; start < count; start += _pageSize) {
        final end = (start + _pageSize) > count ? count : (start + _pageSize);
        final assets = await album.getAssetListRange(start: start, end: end);

        for (var i = 0; i < assets.length; i += _resolveBatchSize) {
          final slice = assets.sublist(
            i,
            (i + _resolveBatchSize) > assets.length
                ? assets.length
                : (i + _resolveBatchSize),
          );
          final resolved = await Future.wait(
            slice.map((asset) => _mapAsset(asset, albumName: album.name)),
          );
          for (final item in resolved) {
            if (item != null && seenKeys.add(item.mediaKey)) {
              items.add(item);
            }
          }
        }
      }
    }

    return items;
  }

  Future<List<VideoItem>> _scanAppDownloadsFolder() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(docsDir.path, 'downloads'));
      if (!await downloadsDir.exists()) return const <VideoItem>[];

      final results = <VideoItem>[];
      await for (final entity in downloadsDir.list()) {
        if (entity is! File) continue;
        final path = entity.path;
        final isVideo = MediaFormats.isSupportedVideo(path);
        final isAudio = MediaFormats.isSupportedAudio(path);
        if (!isVideo && !isAudio) continue;

        final stat = await entity.stat();
        results.add(
          VideoItem.fromPickedFile(
            filePath: path,
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
            isAudioOnly: isAudio && !isVideo,
          ),
        );
      }
      return results;
    } catch (_) {
      return const <VideoItem>[];
    }
  }

  Future<VideoItem?> _mapAsset(
    AssetEntity asset, {
    required String albumName,
  }) async {
    try {
      final file = await asset.file;
      final mediaPath = file?.path ?? await asset.getMediaUrl();
      if (mediaPath == null || mediaPath.trim().isEmpty) return null;

      final normalizedPath = mediaPath.contains('://')
          ? mediaPath
          : p.normalize(mediaPath);
      final rawTitle = asset.title?.trim();
      final diskName = file != null ? p.basename(file.path) : '';
      final fileName = diskName.isNotEmpty
          ? diskName
          : ((rawTitle != null && rawTitle.isNotEmpty)
                ? rawTitle
                : 'media_${asset.id}');
      final strippedTitle = p.basenameWithoutExtension(fileName);
      final title = strippedTitle.isNotEmpty
          ? strippedTitle
          : ((rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : fileName);

      final sizeBytes = file != null && await file.exists()
          ? await file.length()
          : await asset.fileSize;

      final folderPath = !normalizedPath.contains('://')
          ? p.dirname(normalizedPath)
          : (asset.relativePath ?? albumName);
      final folderName = albumName.trim().isNotEmpty
          ? albumName.trim()
          : (p.basename(folderPath).isNotEmpty
                ? p.basename(folderPath)
                : 'Media');

      final isAudio = asset.type == AssetType.audio ||
          MediaFormats.isSupportedAudio(fileName);

      return VideoItem(
        mediaKey: normalizedPath,
        filePath: normalizedPath,
        fileName: fileName,
        title: title,
        folderPath: folderPath,
        folderName: folderName,
        duration: asset.videoDuration,
        sizeBytes: sizeBytes,
        width: asset.orientatedWidth > 0 ? asset.orientatedWidth : null,
        height: asset.orientatedHeight > 0 ? asset.orientatedHeight : null,
        modifiedAt: asset.modifiedDateTime,
        assetId: asset.id,
        isAudioOnly: isAudio,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<VideoItem?> pickSingleVideoFile() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Select Video or Audio File',
      type: FileType.any,
    );
    if (picked == null) return null;

    final localPath = picked.path;
    final resolvedPath = (localPath != null && localPath.trim().isNotEmpty)
        ? localPath
        : picked.uri.toString();
    if (resolvedPath.trim().isEmpty) return null;

    final file = localPath != null ? File(localPath) : null;
    final stat = (file != null && await file.exists()) ? await file.stat() : null;
    final sizeBytes = stat?.size ?? await picked.length() ?? 0;

    return VideoItem.fromPickedFile(
      filePath: resolvedPath,
      fileNameOverride: picked.name,
      sizeBytes: sizeBytes,
      modifiedAt: stat?.modified ?? DateTime.now(),
    );
  }
}
