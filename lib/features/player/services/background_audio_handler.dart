import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:video_player_app/core/config/app_config.dart';

/// Callbacks triggered by OS lock-screen / media notification controls.
typedef SeekCallback = Future<void> Function(Duration position);
typedef SeekDeltaCallback = Future<void> Function(Duration delta);
typedef VoidAsyncCallback = Future<void> Function();

/// Contract for synchronizing active media playback with OS background audio controls.
abstract interface class BackgroundAudioController {
  Future<void> initialize({
    required VoidAsyncCallback onPlay,
    required VoidAsyncCallback onPause,
    required VoidAsyncCallback onStop,
    required SeekCallback onSeek,
    required SeekDeltaCallback onSeekBy,
  });

  Future<void> updateMedia({
    required String id,
    required String title,
    String? album,
    required Duration duration,
  });

  Future<void> updateState({
    required bool isPlaying,
    required bool isBuffering,
    required bool isCompleted,
    required Duration position,
    required double speed,
  });

  Future<void> clear();
}

/// No-op implementation for headless tests or platforms without AudioService.
class NoopBackgroundAudioController implements BackgroundAudioController {
  const NoopBackgroundAudioController();

  @override
  Future<void> initialize({
    required VoidAsyncCallback onPlay,
    required VoidAsyncCallback onPause,
    required VoidAsyncCallback onStop,
    required SeekCallback onSeek,
    required SeekDeltaCallback onSeekBy,
  }) async {}

  @override
  Future<void> updateMedia({
    required String id,
    required String title,
    String? album,
    required Duration duration,
  }) async {}

  @override
  Future<void> updateState({
    required bool isPlaying,
    required bool isBuffering,
    required bool isCompleted,
    required Duration position,
    required double speed,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _CineVaultAudioHandler extends BaseAudioHandler with SeekHandler {
  VoidAsyncCallback? onPlayCallback;
  VoidAsyncCallback? onPauseCallback;
  VoidAsyncCallback? onStopCallback;
  SeekCallback? onSeekCallback;
  SeekDeltaCallback? onSeekByCallback;

  @override
  Future<void> play() async => onPlayCallback?.call();

  @override
  Future<void> pause() async => onPauseCallback?.call();

  @override
  Future<void> stop() async {
    await onStopCallback?.call();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => onSeekCallback?.call(position);

  @override
  Future<void> fastForward() async =>
      onSeekByCallback?.call(AppConfig.doubleTapSeekStep);

  @override
  Future<void> rewind() async =>
      onSeekByCallback?.call(-AppConfig.doubleTapSeekStep);
}

/// Production `audio_service` + `audio_session` controller for lock-screen and
/// notification media controls during background video/MP3 playback.
class AudioServiceBackgroundController implements BackgroundAudioController {
  static _CineVaultAudioHandler? _sharedHandler;
  static Future<void>? _sharedInitFuture;

  VoidAsyncCallback? _onPlay;
  VoidAsyncCallback? _onPause;
  VoidAsyncCallback? _onStop;
  SeekCallback? _onSeek;
  SeekDeltaCallback? _onSeekBy;
  bool _unavailable = false;

  @override
  Future<void> initialize({
    required VoidAsyncCallback onPlay,
    required VoidAsyncCallback onPause,
    required VoidAsyncCallback onStop,
    required SeekCallback onSeek,
    required SeekDeltaCallback onSeekBy,
  }) async {
    _onPlay = onPlay;
    _onPause = onPause;
    _onStop = onStop;
    _onSeek = onSeek;
    _onSeekBy = onSeekBy;

    if (_unavailable) return;

    try {
      if (_sharedHandler == null) {
        _sharedInitFuture ??= _initSharedAudioService();
        await _sharedInitFuture;
      }
      final handler = _sharedHandler;
      if (handler != null) {
        handler.onPlayCallback = _onPlay;
        handler.onPauseCallback = _onPause;
        handler.onStopCallback = _onStop;
        handler.onSeekCallback = _onSeek;
        handler.onSeekByCallback = _onSeekBy;
      }
    } catch (_) {
      _unavailable = true;
    }
  }

  Future<void> _initSharedAudioService() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final handler = _CineVaultAudioHandler();
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.cinevault.player.channel.audio',
        androidNotificationChannelName: 'CineVault Background Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    _sharedHandler = handler;
  }

  @override
  Future<void> updateMedia({
    required String id,
    required String title,
    String? album,
    required Duration duration,
  }) async {
    final handler = _sharedHandler;
    if (handler == null || _unavailable) return;
    handler.mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        album: album?.isNotEmpty == true ? album : AppConfig.appName,
        duration: duration > Duration.zero ? duration : null,
      ),
    );
  }

  @override
  Future<void> updateState({
    required bool isPlaying,
    required bool isBuffering,
    required bool isCompleted,
    required Duration position,
    required double speed,
  }) async {
    final handler = _sharedHandler;
    if (handler == null || _unavailable) return;

    final processingState = isCompleted
        ? AudioProcessingState.completed
        : (isBuffering
              ? AudioProcessingState.buffering
              : AudioProcessingState.ready);

    handler.playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.rewind,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.playPause,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: processingState,
        playing: isPlaying,
        updatePosition: position,
        speed: speed,
      ),
    );
  }

  @override
  Future<void> clear() async {
    final handler = _sharedHandler;
    if (handler == null || _unavailable) return;
    handler.playbackState.add(
      PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }
}
