import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/features/player/domain/ab_loop_range.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/domain/media_track_info.dart';

/// Immutable consolidated player state snapshot consumed by UI and controllers.
class PlayerSnapshot {
  final MediaPlaybackRequest? currentMedia;
  final bool isEngineReady;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final double playbackSpeed;
  final double playerVolumePercent;
  final double maxVolumePercent;
  final bool isMuted;
  final AspectRatioMode aspectRatioMode;
  final ABLoopRange abLoop;
  final bool isTouchLocked;
  final bool isNightMode;
  final bool isBackgroundAudioEnabled;
  final bool isInPipMode;
  final Duration? sleepTimerRemaining;
  final bool sleepAfterCurrentVideo;
  final bool useLibass;
  final bool hardwareAccelerationEnabled;
  final Duration subtitleDelay;
  final double subtitleScale;
  final double subtitleFontSize;
  final int? videoWidth;
  final int? videoHeight;
  final List<MediaTrackInfo> videoTracks;
  final List<MediaTrackInfo> audioTracks;
  final List<MediaTrackInfo> subtitleTracks;
  final List<SavedSubtitle> savedSubtitles;
  final String selectedAudioTrackId;
  final String selectedSubtitleTrackId;
  final String? errorMessage;

  const PlayerSnapshot({
    this.currentMedia,
    this.isEngineReady = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffer = Duration.zero,
    this.playbackSpeed = 1.0,
    this.playerVolumePercent = 100.0,
    this.maxVolumePercent = 200.0,
    this.isMuted = false,
    this.aspectRatioMode = AspectRatioMode.fit,
    this.abLoop = const ABLoopRange(),
    this.isTouchLocked = false,
    this.isNightMode = false,
    this.isBackgroundAudioEnabled = false,
    this.isInPipMode = false,
    this.sleepTimerRemaining,
    this.sleepAfterCurrentVideo = false,
    this.useLibass = true,
    this.hardwareAccelerationEnabled = true,
    this.subtitleDelay = Duration.zero,
    this.subtitleScale = 1.0,
    this.subtitleFontSize = 28.0,
    this.videoWidth,
    this.videoHeight,
    this.videoTracks = const <MediaTrackInfo>[],
    this.audioTracks = const <MediaTrackInfo>[],
    this.subtitleTracks = const <MediaTrackInfo>[],
    this.savedSubtitles = const <SavedSubtitle>[],
    this.selectedAudioTrackId = 'auto',
    this.selectedSubtitleTrackId = 'auto',
    this.errorMessage,
  });

  bool get hasMedia => currentMedia != null;
  bool get isAudioBoosted => !isMuted && playerVolumePercent > 100.5;
  bool get hasSleepTimer =>
      sleepTimerRemaining != null || sleepAfterCurrentVideo;
  double get progress {
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  PlayerSnapshot copyWith({
    MediaPlaybackRequest? currentMedia,
    bool clearCurrentMedia = false,
    bool? isEngineReady,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    Duration? position,
    Duration? duration,
    Duration? buffer,
    double? playbackSpeed,
    double? playerVolumePercent,
    double? maxVolumePercent,
    bool? isMuted,
    AspectRatioMode? aspectRatioMode,
    ABLoopRange? abLoop,
    bool? isTouchLocked,
    bool? isNightMode,
    bool? isBackgroundAudioEnabled,
    bool? isInPipMode,
    Duration? sleepTimerRemaining,
    bool clearSleepTimerRemaining = false,
    bool? sleepAfterCurrentVideo,
    bool? useLibass,
    bool? hardwareAccelerationEnabled,
    Duration? subtitleDelay,
    double? subtitleScale,
    double? subtitleFontSize,
    int? videoWidth,
    bool clearVideoWidth = false,
    int? videoHeight,
    bool clearVideoHeight = false,
    List<MediaTrackInfo>? videoTracks,
    List<MediaTrackInfo>? audioTracks,
    List<MediaTrackInfo>? subtitleTracks,
    List<SavedSubtitle>? savedSubtitles,
    String? selectedAudioTrackId,
    String? selectedSubtitleTrackId,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PlayerSnapshot(
      currentMedia: clearCurrentMedia
          ? null
          : (currentMedia ?? this.currentMedia),
      isEngineReady: isEngineReady ?? this.isEngineReady,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffer: buffer ?? this.buffer,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      playerVolumePercent: playerVolumePercent ?? this.playerVolumePercent,
      maxVolumePercent: maxVolumePercent ?? this.maxVolumePercent,
      isMuted: isMuted ?? this.isMuted,
      aspectRatioMode: aspectRatioMode ?? this.aspectRatioMode,
      abLoop: abLoop ?? this.abLoop,
      isTouchLocked: isTouchLocked ?? this.isTouchLocked,
      isNightMode: isNightMode ?? this.isNightMode,
      isBackgroundAudioEnabled:
          isBackgroundAudioEnabled ?? this.isBackgroundAudioEnabled,
      isInPipMode: isInPipMode ?? this.isInPipMode,
      sleepTimerRemaining: clearSleepTimerRemaining
          ? null
          : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      sleepAfterCurrentVideo:
          sleepAfterCurrentVideo ?? this.sleepAfterCurrentVideo,
      useLibass: useLibass ?? this.useLibass,
      hardwareAccelerationEnabled:
          hardwareAccelerationEnabled ?? this.hardwareAccelerationEnabled,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      subtitleScale: subtitleScale ?? this.subtitleScale,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      videoWidth: clearVideoWidth ? null : (videoWidth ?? this.videoWidth),
      videoHeight: clearVideoHeight ? null : (videoHeight ?? this.videoHeight),
      videoTracks: videoTracks ?? this.videoTracks,
      audioTracks: audioTracks ?? this.audioTracks,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      savedSubtitles: savedSubtitles ?? this.savedSubtitles,
      selectedAudioTrackId: selectedAudioTrackId ?? this.selectedAudioTrackId,
      selectedSubtitleTrackId:
          selectedSubtitleTrackId ?? this.selectedSubtitleTrackId,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
