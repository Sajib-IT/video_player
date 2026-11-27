import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/domain/player_snapshot.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Abstraction for screen wake lock control so player lifecycle tests run without plugins.
abstract interface class WakelockGateway {
  Future<void> setEnabled(bool enabled);
}

class PluginWakelockGateway implements WakelockGateway {
  const PluginWakelockGateway();

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (_) {
      // Ignore missing platform bindings in headless tests or unsupported hosts.
    }
  }
}

/// Core contract for controlling media playback, tracks, subtitles, and persistence.
abstract class PlayerService {
  ValueListenable<PlayerSnapshot> get snapshotListenable;
  Stream<PlayerSnapshot> get snapshotStream;
  PlayerSnapshot get snapshot;

  /// Null only when running headless tests without an attached video surface.
  VideoController? get videoController;

  Future<void> initialize();
  Future<void> openMedia(
    MediaPlaybackRequest request, {
    bool autoPlay = true,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> stop();

  Future<void> seekTo(Duration position);
  Future<void> seekBy(Duration delta);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setPlayerVolume(double volumePercent);
  Future<void> setMuted(bool muted);
  Future<void> toggleMute();

  Future<void> setAspectRatioMode(AspectRatioMode mode);
  Future<void> cycleAspectRatioMode();
  void setTouchLocked(bool locked);
  void toggleTouchLock();
  Future<void> setNightModeEnabled(bool enabled);
  Future<void> toggleNightMode();
  Future<void> setBackgroundAudioEnabled(bool enabled);
  Future<void> toggleBackgroundAudio();
  void setInPipMode(bool inPipMode);

  Future<void> setSleepTimer(Duration? duration);
  Future<void> setSleepAfterCurrentVideo();
  Future<void> cancelSleepTimer();
  Future<String?> captureScreenshot();

  Future<void> setLoopPointA([Duration? position]);
  Future<void> setLoopPointB([Duration? position]);
  Future<void> toggleABLoop();
  Future<void> clearABLoop();

  Future<void> selectAudioTrack(String trackId);
  Future<void> selectSubtitleTrack(String trackId);
  Future<SavedSubtitle> attachExternalSubtitle({
    required String filePath,
    String? title,
    String? languageCode,
    String? languageName,
    SubtitleSource source = SubtitleSource.local,
    String? externalId,
    String? movieHash,
    bool persistInDb = true,
  });
  Future<void> disableSubtitles();
  Future<void> setSubtitleDelay(Duration delay);
  Future<void> stepSubtitleDelay(Duration delta);
  Future<void> setSubtitleScale(double scale);
  Future<void> setSubtitleFontSize(double fontSize);

  Future<void> setLibassEnabled(bool enabled);
  Future<void> setHardwareAccelerationEnabled(bool enabled);
  Future<void> toggleHardwareAcceleration();
  Future<void> handleAppLifecycleState(AppLifecycleState state);
  Future<void> flushWatchProgress();
  Future<void> dispose();
}
