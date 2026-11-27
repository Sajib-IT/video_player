import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';

/// Persisted playback progress, resume position, and per-video preferences.
class WatchHistoryEntry {
  final int? id;
  final String mediaKey;
  final String filePath;
  final String title;
  final String folderPath;
  final int fileSizeBytes;
  final int positionMs;
  final int durationMs;
  final bool isWatched;
  final double playbackSpeed;
  final AspectRatioMode aspectRatioMode;
  final String? audioTrackId;
  final String? subtitleTrackId;
  final int subtitleDelayMs;
  final int playCount;
  final int lastPlayedAtMs;
  final int updatedAtMs;

  const WatchHistoryEntry({
    this.id,
    required this.mediaKey,
    required this.filePath,
    required this.title,
    this.folderPath = '',
    this.fileSizeBytes = 0,
    this.positionMs = 0,
    this.durationMs = 0,
    this.isWatched = false,
    this.playbackSpeed = 1.0,
    this.aspectRatioMode = AspectRatioMode.fit,
    this.audioTrackId,
    this.subtitleTrackId,
    this.subtitleDelayMs = 0,
    this.playCount = 0,
    required this.lastPlayedAtMs,
    required this.updatedAtMs,
  });

  Duration get position => Duration(milliseconds: positionMs);
  Duration get duration => Duration(milliseconds: durationMs);
  Duration get subtitleDelay => Duration(milliseconds: subtitleDelayMs);

  double get progressRatio {
    if (durationMs <= 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  /// Whether this entry has meaningful resume progress that should be restored.
  bool get hasResumableProgress {
    if (isWatched) return false;
    if (positionMs < AppConfig.resumeMinThreshold.inMilliseconds) return false;
    if (durationMs > 0 && progressRatio >= AppConfig.watchedCompletionRatio) {
      return false;
    }
    return true;
  }

  WatchHistoryEntry copyWith({
    int? id,
    String? mediaKey,
    String? filePath,
    String? title,
    String? folderPath,
    int? fileSizeBytes,
    int? positionMs,
    int? durationMs,
    bool? isWatched,
    double? playbackSpeed,
    AspectRatioMode? aspectRatioMode,
    String? audioTrackId,
    bool clearAudioTrackId = false,
    String? subtitleTrackId,
    bool clearSubtitleTrackId = false,
    int? subtitleDelayMs,
    int? playCount,
    int? lastPlayedAtMs,
    int? updatedAtMs,
  }) {
    return WatchHistoryEntry(
      id: id ?? this.id,
      mediaKey: mediaKey ?? this.mediaKey,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      folderPath: folderPath ?? this.folderPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      isWatched: isWatched ?? this.isWatched,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      aspectRatioMode: aspectRatioMode ?? this.aspectRatioMode,
      audioTrackId: clearAudioTrackId
          ? null
          : (audioTrackId ?? this.audioTrackId),
      subtitleTrackId: clearSubtitleTrackId
          ? null
          : (subtitleTrackId ?? this.subtitleTrackId),
      subtitleDelayMs: subtitleDelayMs ?? this.subtitleDelayMs,
      playCount: playCount ?? this.playCount,
      lastPlayedAtMs: lastPlayedAtMs ?? this.lastPlayedAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'media_key': mediaKey,
      'file_path': filePath,
      'title': title,
      'folder_path': folderPath,
      'file_size_bytes': fileSizeBytes,
      'position_ms': positionMs,
      'duration_ms': durationMs,
      'is_watched': isWatched ? 1 : 0,
      'playback_speed': playbackSpeed,
      'aspect_ratio_mode': aspectRatioMode.id,
      'audio_track_id': audioTrackId,
      'subtitle_track_id': subtitleTrackId,
      'subtitle_delay_ms': subtitleDelayMs,
      'play_count': playCount,
      'last_played_at': lastPlayedAtMs,
      'updated_at': updatedAtMs,
    };
  }

  factory WatchHistoryEntry.fromMap(Map<String, Object?> map) {
    return WatchHistoryEntry(
      id: map['id'] as int?,
      mediaKey: map['media_key'] as String,
      filePath: map['file_path'] as String,
      title: map['title'] as String,
      folderPath: (map['folder_path'] as String?) ?? '',
      fileSizeBytes: (map['file_size_bytes'] as int?) ?? 0,
      positionMs: (map['position_ms'] as int?) ?? 0,
      durationMs: (map['duration_ms'] as int?) ?? 0,
      isWatched: ((map['is_watched'] as int?) ?? 0) == 1,
      playbackSpeed: ((map['playback_speed'] as num?) ?? 1.0).toDouble(),
      aspectRatioMode: AspectRatioMode.fromId(
        map['aspect_ratio_mode'] as String?,
      ),
      audioTrackId: map['audio_track_id'] as String?,
      subtitleTrackId: map['subtitle_track_id'] as String?,
      subtitleDelayMs: (map['subtitle_delay_ms'] as int?) ?? 0,
      playCount: (map['play_count'] as int?) ?? 0,
      lastPlayedAtMs: (map['last_played_at'] as int?) ?? 0,
      updatedAtMs: (map['updated_at'] as int?) ?? 0,
    );
  }
}
