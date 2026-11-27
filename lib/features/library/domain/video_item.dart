import 'package:path/path.dart' as p;
import 'package:video_player_app/core/constants/media_formats.dart';
import 'package:video_player_app/data/local/models/cached_video_record.dart';
import 'package:video_player_app/data/local/models/watch_history_entry.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';

/// Immutable library representation of a local video or audio track paired
/// with SQLite watch history.
class VideoItem {
  final String mediaKey;
  final String filePath;
  final String fileName;
  final String title;
  final String folderPath;
  final String folderName;
  final Duration duration;
  final int sizeBytes;
  final int? width;
  final int? height;
  final DateTime modifiedAt;
  final String? assetId;
  final bool isAudioOnly;
  final WatchHistoryEntry? watchHistory;

  const VideoItem({
    required this.mediaKey,
    required this.filePath,
    required this.fileName,
    required this.title,
    required this.folderPath,
    required this.folderName,
    required this.duration,
    required this.sizeBytes,
    this.width,
    this.height,
    required this.modifiedAt,
    this.assetId,
    this.isAudioOnly = false,
    this.watchHistory,
  });

  factory VideoItem.fromCachedRecord(
    CachedVideoRecord record, {
    WatchHistoryEntry? watchHistory,
  }) {
    return VideoItem(
      mediaKey: record.mediaKey,
      filePath: record.filePath,
      fileName: record.fileName,
      title: p.basenameWithoutExtension(record.fileName),
      folderPath: record.folderPath,
      folderName: record.folderName,
      duration: Duration(milliseconds: record.durationMs),
      sizeBytes: record.sizeBytes,
      width: record.width,
      height: record.height,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(record.modifiedAtMs),
      isAudioOnly: MediaFormats.isSupportedAudio(record.fileName),
      watchHistory: watchHistory,
    );
  }

  factory VideoItem.fromPickedFile({
    required String filePath,
    String? fileNameOverride,
    required int sizeBytes,
    required DateTime modifiedAt,
    bool? isAudioOnly,
    WatchHistoryEntry? watchHistory,
  }) {
    final normalized = filePath.contains('://')
        ? filePath
        : p.normalize(filePath);
    final fileName = (fileNameOverride != null && fileNameOverride.isNotEmpty)
        ? fileNameOverride
        : p.basename(normalized);
    final folderPath = normalized.contains('://') ? '' : p.dirname(normalized);
    final folderName = p.basename(folderPath).isNotEmpty
        ? p.basename(folderPath)
        : 'Device';
    return VideoItem(
      mediaKey: normalized,
      filePath: normalized,
      fileName: fileName,
      title: p.basenameWithoutExtension(fileName),
      folderPath: folderPath,
      folderName: folderName,
      duration: watchHistory?.duration ?? Duration.zero,
      sizeBytes: sizeBytes,
      modifiedAt: modifiedAt,
      isAudioOnly: isAudioOnly ?? MediaFormats.isSupportedAudio(fileName),
      watchHistory: watchHistory,
    );
  }

  bool get isWatched => watchHistory?.isWatched ?? false;
  bool get hasResumeProgress => watchHistory?.hasResumableProgress ?? false;
  Duration get resumePosition => watchHistory?.position ?? Duration.zero;

  Duration get effectiveDuration {
    if (duration > Duration.zero) return duration;
    return watchHistory?.duration ?? Duration.zero;
  }

  double get progressRatio {
    final totalMs = effectiveDuration.inMilliseconds;
    if (totalMs <= 0 || watchHistory == null) return 0.0;
    if (isWatched) return 1.0;
    return (watchHistory!.positionMs / totalMs).clamp(0.0, 1.0);
  }

  String get containerLabel {
    final ext = MediaFormats.extensionOf(fileName);
    if (ext.isNotEmpty) return ext.toUpperCase();
    return isAudioOnly ? 'AUDIO' : 'VIDEO';
  }

  String? get resolutionLabel {
    if (isAudioOnly) return 'AUDIO';
    final h = height;
    final w = width;
    if (h == null || w == null || h <= 0 || w <= 0) return null;
    final minDim = w < h ? w : h;
    if (minDim >= 2100) return '4K';
    if (minDim >= 1050) return '1080p';
    if (minDim >= 700) return '720p';
    if (minDim >= 460) return '480p';
    return '${minDim}p';
  }

  VideoItem copyWith({
    Duration? duration,
    int? sizeBytes,
    int? width,
    int? height,
    String? assetId,
    bool? isAudioOnly,
    WatchHistoryEntry? watchHistory,
    bool clearWatchHistory = false,
  }) {
    return VideoItem(
      mediaKey: mediaKey,
      filePath: filePath,
      fileName: fileName,
      title: title,
      folderPath: folderPath,
      folderName: folderName,
      duration: duration ?? this.duration,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      modifiedAt: modifiedAt,
      assetId: assetId ?? this.assetId,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      watchHistory: clearWatchHistory
          ? null
          : (watchHistory ?? this.watchHistory),
    );
  }

  MediaPlaybackRequest toPlaybackRequest({Duration? initialPosition}) {
    return MediaPlaybackRequest(
      mediaKey: mediaKey,
      uriOrPath: filePath,
      title: title,
      folderPath: folderPath,
      fileSizeBytes: sizeBytes,
      initialPosition: initialPosition,
      isAudioOnly: isAudioOnly,
    );
  }

  CachedVideoRecord toCachedRecord({int? scannedAtMs}) {
    return CachedVideoRecord(
      mediaKey: mediaKey,
      filePath: filePath,
      fileName: fileName,
      folderPath: folderPath,
      folderName: folderName,
      durationMs: effectiveDuration.inMilliseconds,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      modifiedAtMs: modifiedAt.millisecondsSinceEpoch,
      scannedAtMs: scannedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
