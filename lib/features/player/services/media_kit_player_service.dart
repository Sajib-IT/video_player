import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/config/subtitle_languages.dart';
import 'package:video_player_app/core/constants/media_formats.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/saved_subtitle_dao.dart';
import 'package:video_player_app/data/local/dao/watch_history_dao.dart';
import 'package:video_player_app/data/local/models/playback_settings.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/features/player/domain/ab_loop_range.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/domain/media_track_info.dart';
import 'package:video_player_app/features/player/domain/player_snapshot.dart';
import 'package:video_player_app/features/player/services/background_audio_handler.dart';
import 'package:video_player_app/features/player/services/player_service.dart';

typedef PlayerFactory = Player Function(PlayerConfiguration configuration);
typedef VideoControllerFactory =
    VideoController Function(
      Player player,
      VideoControllerConfiguration configuration,
    );
typedef DocumentsDirectoryProvider = Future<Directory> Function();

/// Production `media_kit` (`libmpv` + `FFmpeg`) implementation of [PlayerService].
///
/// Manages player engine lifecycle, HW/SW acceleration, 0.25x–8.0x speed,
/// software audio boost (>100%), quick mute, Night Mode, Sleep Timer, frame
/// screenshots, PiP/background audio `MediaSession`, embedded/external
/// subtitles (`libass` + Flutter overlay), A-B loop, and SQLite persistence.
class MediaKitPlayerService implements PlayerService {
  final WatchHistoryDao _watchHistoryDao;
  final PlaybackSettingsDao _settingsDao;
  final SavedSubtitleDao _savedSubtitleDao;
  final WakelockGateway _wakelockGateway;
  final BackgroundAudioController _backgroundAudioController;
  final PlayerFactory _playerFactory;
  final VideoControllerFactory _videoControllerFactory;
  final DocumentsDirectoryProvider _documentsDirProvider;
  final bool attachVideoController;

  final ValueNotifier<PlayerSnapshot> _snapshotNotifier = ValueNotifier(
    const PlayerSnapshot(),
  );
  final StreamController<PlayerSnapshot> _snapshotController =
      StreamController<PlayerSnapshot>.broadcast();

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  Player? _player;
  VideoController? _videoController;
  PlaybackSettings _settings = PlaybackSettings.defaults();
  Timer? _progressSaveTimer;
  Timer? _sleepTimer;
  Completer<void>? _initCompleter;

  bool _isDisposed = false;
  bool _pauseDueToBackground = false;
  bool _wakelockActive = false;
  double _preMuteVolumePercent = 100.0;

  Duration? _pendingResumePosition;
  String? _pendingAudioTrackId;
  String? _pendingEmbeddedSubtitleId;
  SavedSubtitle? _pendingExternalSubtitle;
  DateTime _lastLoopJumpAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _incrementPlayCountOnCurrentMedia = false;

  MediaKitPlayerService({
    WatchHistoryDao? watchHistoryDao,
    PlaybackSettingsDao? settingsDao,
    SavedSubtitleDao? savedSubtitleDao,
    WakelockGateway? wakelockGateway,
    BackgroundAudioController? backgroundAudioController,
    PlayerFactory? playerFactory,
    VideoControllerFactory? videoControllerFactory,
    DocumentsDirectoryProvider? documentsDirProvider,
    this.attachVideoController = true,
  }) : _watchHistoryDao = watchHistoryDao ?? WatchHistoryDao(),
       _settingsDao = settingsDao ?? PlaybackSettingsDao(),
       _savedSubtitleDao = savedSubtitleDao ?? SavedSubtitleDao(),
       _wakelockGateway = wakelockGateway ?? const PluginWakelockGateway(),
       _backgroundAudioController =
           backgroundAudioController ?? AudioServiceBackgroundController(),
       _playerFactory =
           playerFactory ?? ((config) => Player(configuration: config)),
       _videoControllerFactory =
           videoControllerFactory ??
           ((player, config) =>
               VideoController(player, configuration: config)),
       _documentsDirProvider =
           documentsDirProvider ?? getApplicationDocumentsDirectory;

  @override
  ValueListenable<PlayerSnapshot> get snapshotListenable => _snapshotNotifier;

  @override
  Stream<PlayerSnapshot> get snapshotStream => _snapshotController.stream;

  @override
  PlayerSnapshot get snapshot => _snapshotNotifier.value;

  @override
  VideoController? get videoController => _videoController;

  @override
  Future<void> initialize() async {
    _ensureNotDisposed();
    if (_player != null) return;
    final inFlight = _initCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      _settings = await _settingsDao.getSettings();
      await _backgroundAudioController.initialize(
        onPlay: play,
        onPause: pause,
        onStop: stop,
        onSeek: seekTo,
        onSeekBy: seekBy,
      );
      await _createEngine();
      _emitSnapshot(
        snapshot.copyWith(
          isEngineReady: true,
          playbackSpeed: _settings.defaultPlaybackSpeed,
          aspectRatioMode: _settings.defaultAspectRatio,
          maxVolumePercent: _settings.maxVolumePercent,
          isNightMode: _settings.nightModeEnabled,
          isBackgroundAudioEnabled: _settings.backgroundAudioEnabled,
          useLibass: _settings.useLibass,
          hardwareAccelerationEnabled: _settings.hardwareAccelerationEnabled,
          subtitleScale: _settings.subtitleScale,
          subtitleFontSize: _settings.subtitleFontSize,
        ),
      );
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  Future<void> _createEngine() async {
    final config = PlayerConfiguration(
      title: AppConfig.appName,
      libass: _settings.useLibass,
      libassAndroidFont: AppConfig.libassAndroidFontAsset,
      libassAndroidFontName: AppConfig.libassAndroidFontName,
      bufferSize: AppConfig.playerBufferSizeBytes,
      logLevel: MPVLogLevel.error,
    );

    final player = _playerFactory(config);
    _player = player;

    if (attachVideoController) {
      _videoController = _videoControllerFactory(
        player,
        VideoControllerConfiguration(
          enableHardwareAcceleration: _settings.hardwareAccelerationEnabled,
        ),
      );
    }

    _attachPlayerStreams(player);
    // Do not block engine creation on VideoController's post-frame completer.
    unawaited(_applyNativeEngineProperties(player));
  }

  Future<void> _applyNativeEngineProperties(Player player) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;

    await platform.setProperty(
      'volume-max',
      _settings.maxVolumePercent.round().toString(),
    );
    await platform.setProperty(
      'sub-scale',
      snapshot.subtitleScale.toStringAsFixed(2),
    );
    await platform.setProperty(
      'sub-delay',
      (snapshot.subtitleDelay.inMilliseconds / 1000.0).toStringAsFixed(2),
    );
  }

  void _attachPlayerStreams(Player player) {
    _cancelSubscriptions();

    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      player.stream.playing.listen(_onPlayingChanged),
      player.stream.buffering.listen((buffering) {
        _emitSnapshot(snapshot.copyWith(isBuffering: buffering));
        _syncBackgroundAudioState();
      }),
      player.stream.completed.listen(_onCompletedChanged),
      player.stream.position.listen(_onPositionChanged),
      player.stream.duration.listen(_onDurationChanged),
      player.stream.buffer.listen((buffer) {
        _emitSnapshot(snapshot.copyWith(buffer: buffer));
      }),
      player.stream.rate.listen((rate) {
        _emitSnapshot(snapshot.copyWith(playbackSpeed: rate));
      }),
      player.stream.volume.listen((volume) {
        _emitSnapshot(
          snapshot.copyWith(
            playerVolumePercent: volume,
            isMuted: volume <= 0.01,
          ),
        );
      }),
      player.stream.width.listen((width) {
        _emitSnapshot(
          snapshot.copyWith(videoWidth: width, clearVideoWidth: width == null),
        );
      }),
      player.stream.height.listen((height) {
        _emitSnapshot(
          snapshot.copyWith(
            videoHeight: height,
            clearVideoHeight: height == null,
          ),
        );
      }),
      player.stream.tracks.listen(_onTracksChanged),
      player.stream.track.listen(_onSelectedTrackChanged),
      player.stream.error.listen((message) {
        if (message.trim().isNotEmpty) {
          _emitSnapshot(snapshot.copyWith(errorMessage: message));
        }
      }),
    ]);
  }

  @override
  Future<void> openMedia(
    MediaPlaybackRequest request, {
    bool autoPlay = true,
  }) async {
    await initialize();
    _ensureNotDisposed();

    final player = _requirePlayer();

    if (snapshot.currentMedia != null) {
      await flushWatchProgress();
    }

    _settings = await _settingsDao.getSettings();
    final history = await _watchHistoryDao.getByMediaKey(request.mediaKey);
    final savedSubs = await _savedSubtitleDao.getForMedia(request.mediaKey);
    final activeSavedSub = savedSubs.where((s) => s.isActive).firstOrNull;

    final resumePosition = _resolveResumePosition(request, history);
    final targetSpeed = (history?.playbackSpeed ?? _settings.defaultPlaybackSpeed)
        .clamp(AppConfig.minPlaybackSpeed, AppConfig.maxPlaybackSpeed);
    final targetAspectRatio =
        history?.aspectRatioMode ?? _settings.defaultAspectRatio;
    final targetSubDelay = Duration(
      milliseconds: (activeSavedSub?.delayMs ?? history?.subtitleDelayMs ?? 0)
          .clamp(
            AppConfig.minSubtitleDelay.inMilliseconds,
            AppConfig.maxSubtitleDelay.inMilliseconds,
          ),
    );
    final backgroundEnabled =
        request.isAudioOnly || _settings.backgroundAudioEnabled;

    _pendingResumePosition = resumePosition > Duration.zero
        ? resumePosition
        : null;
    _pendingAudioTrackId = history?.audioTrackId;
    _pendingExternalSubtitle = activeSavedSub;
    _pendingEmbeddedSubtitleId = activeSavedSub == null
        ? history?.subtitleTrackId
        : null;
    _incrementPlayCountOnCurrentMedia = true;

    _emitSnapshot(
      snapshot.copyWith(
        currentMedia: request,
        isPlaying: autoPlay,
        isBuffering: true,
        isCompleted: false,
        position: resumePosition,
        duration: Duration.zero,
        buffer: Duration.zero,
        playbackSpeed: targetSpeed,
        aspectRatioMode: targetAspectRatio,
        abLoop: const ABLoopRange(),
        isTouchLocked: false,
        isNightMode: _settings.nightModeEnabled,
        isBackgroundAudioEnabled: backgroundEnabled,
        maxVolumePercent: _settings.maxVolumePercent,
        subtitleDelay: targetSubDelay,
        subtitleScale: _settings.subtitleScale,
        subtitleFontSize: _settings.subtitleFontSize,
        savedSubtitles: savedSubs,
        selectedAudioTrackId: history?.audioTrackId ?? 'auto',
        selectedSubtitleTrackId: activeSavedSub != null
            ? _externalTrackId(activeSavedSub)
            : (history?.subtitleTrackId ?? 'auto'),
        clearVideoWidth: true,
        clearVideoHeight: true,
        clearErrorMessage: true,
      ),
    );

    try {
      await player.open(Media(request.uriOrPath), play: autoPlay);
      await player.setRate(targetSpeed);
      await _applyNativeEngineProperties(player);

      if (player.state.duration > Duration.zero) {
        await _applyPendingResumeSeek();
      }
      await _syncWakelock(autoPlay);
      await _syncBackgroundAudioMedia(request, player.state.duration);
      await _syncBackgroundAudioState();
      _startProgressTimer();
    } catch (error, stackTrace) {
      await _syncWakelock(false);
      _emitSnapshot(
        snapshot.copyWith(
          isBuffering: false,
          isPlaying: false,
          errorMessage: 'Failed to open media: $error',
        ),
      );
      throw PlaybackException(
        'Unable to open "${request.title}".',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Duration _resolveResumePosition(
    MediaPlaybackRequest request,
    dynamic history,
  ) {
    if (request.initialPosition != null) {
      return request.initialPosition!;
    }
    if (_settings.resumePlaybackEnabled &&
        history != null &&
        history.hasResumableProgress) {
      return history.position;
    }
    return Duration.zero;
  }

  @override
  Future<void> play() async {
    _ensureNotDisposed();
    await _requirePlayer().play();
  }

  @override
  Future<void> pause() async {
    _ensureNotDisposed();
    await _requirePlayer().pause();
    await flushWatchProgress();
  }

  @override
  Future<void> playOrPause() async {
    _ensureNotDisposed();
    final player = _requirePlayer();
    if (snapshot.isCompleted && snapshot.currentMedia != null) {
      await player.seek(Duration.zero);
      await player.play();
      return;
    }
    await player.playOrPause();
  }

  @override
  Future<void> stop() async {
    _ensureNotDisposed();
    await flushWatchProgress();
    _stopProgressTimer();
    await cancelSleepTimer();
    await _syncWakelock(false);
    await _backgroundAudioController.clear();
    await _player?.stop();
    _emitSnapshot(
      snapshot.copyWith(
        clearCurrentMedia: true,
        isPlaying: false,
        isBuffering: false,
        isCompleted: false,
        position: Duration.zero,
        duration: Duration.zero,
        buffer: Duration.zero,
        abLoop: const ABLoopRange(),
        videoTracks: const <MediaTrackInfo>[],
        audioTracks: const <MediaTrackInfo>[],
        subtitleTracks: const <MediaTrackInfo>[],
        savedSubtitles: const <SavedSubtitle>[],
        clearVideoWidth: true,
        clearVideoHeight: true,
      ),
    );
  }

  @override
  Future<void> seekTo(Duration position) async {
    _ensureNotDisposed();
    final clamped = _clampDuration(position, snapshot.duration);
    _emitSnapshot(snapshot.copyWith(position: clamped, isCompleted: false));
    await _requirePlayer().seek(clamped);
    await _syncBackgroundAudioState();
  }

  @override
  Future<void> seekBy(Duration delta) async {
    await seekTo(snapshot.position + delta);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _ensureNotDisposed();
    final clamped = speed.clamp(
      AppConfig.minPlaybackSpeed,
      AppConfig.maxPlaybackSpeed,
    );
    await _requirePlayer().setRate(clamped);
    _emitSnapshot(snapshot.copyWith(playbackSpeed: clamped));
    await _syncBackgroundAudioState();
    await flushWatchProgress();
  }

  @override
  Future<void> setPlayerVolume(double volumePercent) async {
    _ensureNotDisposed();
    final clamped = volumePercent.clamp(
      AppConfig.minVolumePercent,
      snapshot.maxVolumePercent,
    );
    if (clamped > 0.01) {
      _preMuteVolumePercent = clamped;
    }
    await _requirePlayer().setVolume(clamped);
    _emitSnapshot(
      snapshot.copyWith(
        playerVolumePercent: clamped,
        isMuted: clamped <= 0.01,
      ),
    );
  }

  @override
  Future<void> setMuted(bool muted) async {
    _ensureNotDisposed();
    if (muted) {
      if (snapshot.playerVolumePercent > 0.01) {
        _preMuteVolumePercent = snapshot.playerVolumePercent;
      }
      await _requirePlayer().setVolume(0.0);
      _emitSnapshot(
        snapshot.copyWith(playerVolumePercent: 0.0, isMuted: true),
      );
      return;
    }

    final restore = _preMuteVolumePercent > 0.01 ? _preMuteVolumePercent : 100.0;
    await setPlayerVolume(restore);
  }

  @override
  Future<void> toggleMute() async {
    await setMuted(!snapshot.isMuted);
  }

  @override
  Future<void> setAspectRatioMode(AspectRatioMode mode) async {
    _ensureNotDisposed();
    _emitSnapshot(snapshot.copyWith(aspectRatioMode: mode));
    await flushWatchProgress();
  }

  @override
  Future<void> cycleAspectRatioMode() async {
    await setAspectRatioMode(snapshot.aspectRatioMode.next());
  }

  @override
  void setTouchLocked(bool locked) {
    _ensureNotDisposed();
    _emitSnapshot(snapshot.copyWith(isTouchLocked: locked));
  }

  @override
  void toggleTouchLock() {
    setTouchLocked(!snapshot.isTouchLocked);
  }

  @override
  Future<void> setNightModeEnabled(bool enabled) async {
    _ensureNotDisposed();
    _settings = await _settingsDao.saveSettings(
      _settings.copyWith(nightModeEnabled: enabled),
    );
    _emitSnapshot(snapshot.copyWith(isNightMode: enabled));
  }

  @override
  Future<void> toggleNightMode() async {
    await setNightModeEnabled(!snapshot.isNightMode);
  }

  @override
  Future<void> setBackgroundAudioEnabled(bool enabled) async {
    _ensureNotDisposed();
    _settings = await _settingsDao.saveSettings(
      _settings.copyWith(backgroundAudioEnabled: enabled),
    );
    _emitSnapshot(snapshot.copyWith(isBackgroundAudioEnabled: enabled));
    if (enabled && snapshot.currentMedia != null) {
      await _syncBackgroundAudioMedia(
        snapshot.currentMedia!,
        snapshot.duration,
      );
      await _syncBackgroundAudioState();
    } else if (!enabled) {
      await _backgroundAudioController.clear();
    }
  }

  @override
  Future<void> toggleBackgroundAudio() async {
    await setBackgroundAudioEnabled(!snapshot.isBackgroundAudioEnabled);
  }

  @override
  void setInPipMode(bool inPipMode) {
    if (_isDisposed) return;
    _emitSnapshot(snapshot.copyWith(isInPipMode: inPipMode));
  }

  @override
  Future<void> setSleepTimer(Duration? duration) async {
    _ensureNotDisposed();
    _sleepTimer?.cancel();
    _sleepTimer = null;

    if (duration == null || duration <= Duration.zero) {
      _emitSnapshot(
        snapshot.copyWith(
          clearSleepTimerRemaining: true,
          sleepAfterCurrentVideo: false,
        ),
      );
      return;
    }

    _emitSnapshot(
      snapshot.copyWith(
        sleepTimerRemaining: duration,
        sleepAfterCurrentVideo: false,
      ),
    );

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_isDisposed) return;
      final remaining = snapshot.sleepTimerRemaining;
      if (remaining == null) {
        _sleepTimer?.cancel();
        return;
      }
      final next = remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _sleepTimer?.cancel();
        _sleepTimer = null;
        _emitSnapshot(
          snapshot.copyWith(
            clearSleepTimerRemaining: true,
            sleepAfterCurrentVideo: false,
          ),
        );
        if (snapshot.isPlaying) {
          await pause();
        }
        return;
      }
      _emitSnapshot(snapshot.copyWith(sleepTimerRemaining: next));
    });
  }

  @override
  Future<void> setSleepAfterCurrentVideo() async {
    _ensureNotDisposed();
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _emitSnapshot(
      snapshot.copyWith(
        clearSleepTimerRemaining: true,
        sleepAfterCurrentVideo: true,
      ),
    );
  }

  @override
  Future<void> cancelSleepTimer() async {
    if (_isDisposed) return;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _emitSnapshot(
      snapshot.copyWith(
        clearSleepTimerRemaining: true,
        sleepAfterCurrentVideo: false,
      ),
    );
  }

  @override
  Future<String?> captureScreenshot() async {
    _ensureNotDisposed();
    final player = _requirePlayer();
    final bytes = await player.screenshot(
      format: 'image/png',
      includeLibassSubtitles: snapshot.useLibass,
    );
    if (bytes == null || bytes.isEmpty) return null;

    final rawTitle = (snapshot.currentMedia?.title ?? 'frame')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_')
        .trim();
    final safeTitle = rawTitle.isEmpty ? 'frame' : rawTitle;
    final filename =
        '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.png';

    final docsDir = await _documentsDirProvider();
    final shotsDir = Directory(p.join(docsDir.path, 'screenshots'));
    if (!await shotsDir.exists()) {
      await shotsDir.create(recursive: true);
    }
    final outFile = File(p.join(shotsDir.path, filename));
    await outFile.writeAsBytes(bytes, flush: true);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await PhotoManager.editor.saveImage(
          bytes,
          filename: filename,
          title: safeTitle,
        );
      } catch (_) {
        // File in app screenshots folder remains available if gallery export fails.
      }
    }
    return outFile.path;
  }

  @override
  Future<void> setLoopPointA([Duration? position]) async {
    _ensureNotDisposed();
    final target = position ?? snapshot.position;
    final nextLoop = snapshot.abLoop.withPointA(target);
    _emitSnapshot(snapshot.copyWith(abLoop: nextLoop));
  }

  @override
  Future<void> setLoopPointB([Duration? position]) async {
    _ensureNotDisposed();
    final target = position ?? snapshot.position;
    final nextLoop = snapshot.abLoop.withPointB(target);
    _emitSnapshot(snapshot.copyWith(abLoop: nextLoop));
    if (nextLoop.isActive && nextLoop.pointA != null) {
      await seekTo(nextLoop.pointA!);
    }
  }

  @override
  Future<void> toggleABLoop() async {
    final loop = snapshot.abLoop;
    if (!loop.hasPointA) {
      await setLoopPointA();
    } else if (!loop.hasPointB) {
      await setLoopPointB();
    } else {
      await clearABLoop();
    }
  }

  @override
  Future<void> clearABLoop() async {
    _ensureNotDisposed();
    _emitSnapshot(snapshot.copyWith(abLoop: const ABLoopRange()));
  }

  @override
  Future<void> selectAudioTrack(String trackId) async {
    _ensureNotDisposed();
    final player = _requirePlayer();
    final matching = player.state.tracks.audio
        .where((t) => t.id == trackId)
        .firstOrNull;
    final target =
        matching ?? (trackId == 'no' ? AudioTrack.no() : AudioTrack.auto());
    await player.setAudioTrack(target);
    _emitSnapshot(snapshot.copyWith(selectedAudioTrackId: target.id));
    await flushWatchProgress();
  }

  @override
  Future<void> selectSubtitleTrack(String trackId) async {
    _ensureNotDisposed();
    final player = _requirePlayer();
    final media = snapshot.currentMedia;

    if (trackId == 'no') {
      await disableSubtitles();
      return;
    }

    final savedMatch = snapshot.savedSubtitles
        .where((s) => _externalTrackId(s) == trackId)
        .firstOrNull;
    if (savedMatch != null) {
      await attachExternalSubtitle(
        filePath: savedMatch.localFilePath,
        title: savedMatch.fileName,
        languageCode: savedMatch.languageCode,
        languageName: savedMatch.languageName,
        source: savedMatch.source,
        externalId: savedMatch.externalId,
        movieHash: savedMatch.movieHash,
        persistInDb: true,
      );
      return;
    }

    final embeddedMatch = player.state.tracks.subtitle
        .where((t) => t.id == trackId)
        .firstOrNull;
    final target =
        embeddedMatch ??
        (trackId == 'auto' ? SubtitleTrack.auto() : SubtitleTrack.no());
    await player.setSubtitleTrack(target);

    if (media != null) {
      await _savedSubtitleDao.setActiveSubtitle(media.mediaKey, null);
      final refreshedSubs = await _savedSubtitleDao.getForMedia(media.mediaKey);
      _emitSnapshot(
        snapshot.copyWith(
          selectedSubtitleTrackId: target.id,
          savedSubtitles: refreshedSubs,
        ),
      );
    } else {
      _emitSnapshot(snapshot.copyWith(selectedSubtitleTrackId: target.id));
    }
    await flushWatchProgress();
  }

  @override
  Future<SavedSubtitle> attachExternalSubtitle({
    required String filePath,
    String? title,
    String? languageCode,
    String? languageName,
    SubtitleSource source = SubtitleSource.local,
    String? externalId,
    String? movieHash,
    bool persistInDb = true,
  }) async {
    _ensureNotDisposed();
    final player = _requirePlayer();

    if (!filePath.contains('://')) {
      final file = File(filePath);
      if (!await file.exists()) {
        throw SubtitleFileException('Subtitle file does not exist: $filePath');
      }
      if (!MediaFormats.isSupportedSubtitle(filePath)) {
        throw SubtitleFileException(
          'Unsupported subtitle format: ${p.extension(filePath)}',
        );
      }
    }

    final resolvedName = title?.trim().isNotEmpty == true
        ? title!.trim()
        : p.basename(filePath);
    final resolvedLangCode = (languageCode ?? 'und').trim().toLowerCase();
    final resolvedLangName = languageName?.trim().isNotEmpty == true
        ? languageName!.trim()
        : SubtitleLanguages.labelForCode(resolvedLangCode);

    final uri = filePath.contains('://')
        ? filePath
        : Uri.file(filePath).toString();

    await player.setSubtitleTrack(
      SubtitleTrack.uri(
        uri,
        title: resolvedName,
        language: resolvedLangCode,
      ),
    );

    final media = snapshot.currentMedia;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var saved = SavedSubtitle(
      mediaKey: media?.mediaKey ?? '',
      localFilePath: filePath,
      fileName: resolvedName,
      languageCode: resolvedLangCode,
      languageName: resolvedLangName,
      format: MediaFormats.extensionOf(filePath),
      source: source,
      externalId: externalId,
      movieHash: movieHash,
      delayMs: snapshot.subtitleDelay.inMilliseconds,
      isActive: true,
      createdAtMs: nowMs,
    );

    if (persistInDb && media != null) {
      saved = await _savedSubtitleDao.upsert(saved);
      final refreshed = await _savedSubtitleDao.getForMedia(media.mediaKey);
      _emitSnapshot(
        snapshot.copyWith(
          savedSubtitles: refreshed,
          selectedSubtitleTrackId: _externalTrackId(saved),
        ),
      );
      await flushWatchProgress();
    } else {
      _emitSnapshot(
        snapshot.copyWith(selectedSubtitleTrackId: _externalTrackId(saved)),
      );
    }

    return saved;
  }

  @override
  Future<void> disableSubtitles() async {
    _ensureNotDisposed();
    await _requirePlayer().setSubtitleTrack(SubtitleTrack.no());
    final media = snapshot.currentMedia;
    if (media != null) {
      await _savedSubtitleDao.setActiveSubtitle(media.mediaKey, null);
      final refreshed = await _savedSubtitleDao.getForMedia(media.mediaKey);
      _emitSnapshot(
        snapshot.copyWith(
          selectedSubtitleTrackId: 'no',
          savedSubtitles: refreshed,
        ),
      );
      await flushWatchProgress();
    } else {
      _emitSnapshot(snapshot.copyWith(selectedSubtitleTrackId: 'no'));
    }
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    _ensureNotDisposed();
    final clampedMs = delay.inMilliseconds.clamp(
      AppConfig.minSubtitleDelay.inMilliseconds,
      AppConfig.maxSubtitleDelay.inMilliseconds,
    );
    final snappedMs = (clampedMs / 100).round() * 100;
    final snapped = Duration(milliseconds: snappedMs);

    final platform = _player?.platform;
    if (platform is NativePlayer) {
      await platform.setProperty(
        'sub-delay',
        (snappedMs / 1000.0).toStringAsFixed(2),
      );
    }

    _emitSnapshot(snapshot.copyWith(subtitleDelay: snapped));
    final activeSaved = snapshot.savedSubtitles
        .where((s) => s.isActive && s.id != null)
        .firstOrNull;
    if (activeSaved != null) {
      await _savedSubtitleDao.updateDelay(activeSaved.id!, snappedMs);
    }
    await flushWatchProgress();
  }

  @override
  Future<void> stepSubtitleDelay(Duration delta) async {
    await setSubtitleDelay(snapshot.subtitleDelay + delta);
  }

  @override
  Future<void> setSubtitleScale(double scale) async {
    _ensureNotDisposed();
    final clamped = scale.clamp(
      AppConfig.minSubtitleScale,
      AppConfig.maxSubtitleScale,
    );
    final platform = _player?.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('sub-scale', clamped.toStringAsFixed(2));
    }

    _settings = await _settingsDao.saveSettings(
      _settings.copyWith(subtitleScale: clamped),
    );
    _emitSnapshot(snapshot.copyWith(subtitleScale: clamped));
  }

  @override
  Future<void> setSubtitleFontSize(double fontSize) async {
    _ensureNotDisposed();
    final clamped = fontSize.clamp(
      AppConfig.minSubtitleFontSize,
      AppConfig.maxSubtitleFontSize,
    );
    final proportionalScale = (clamped / 28.0).clamp(
      AppConfig.minSubtitleScale,
      AppConfig.maxSubtitleScale,
    );

    final platform = _player?.platform;
    if (platform is NativePlayer) {
      await platform.setProperty(
        'sub-scale',
        proportionalScale.toStringAsFixed(2),
      );
    }

    _settings = await _settingsDao.saveSettings(
      _settings.copyWith(
        subtitleFontSize: clamped,
        subtitleScale: proportionalScale,
      ),
    );
    _emitSnapshot(
      snapshot.copyWith(
        subtitleFontSize: clamped,
        subtitleScale: proportionalScale,
      ),
    );
  }

  @override
  Future<void> setLibassEnabled(bool enabled) async {
    await _reconfigureEngine(
      nextSettings: _settings.copyWith(useLibass: enabled),
      shouldSkip: _settings.useLibass == enabled && _player != null,
    );
  }

  @override
  Future<void> setHardwareAccelerationEnabled(bool enabled) async {
    await _reconfigureEngine(
      nextSettings: _settings.copyWith(hardwareAccelerationEnabled: enabled),
      shouldSkip:
          _settings.hardwareAccelerationEnabled == enabled && _player != null,
    );
  }

  @override
  Future<void> toggleHardwareAcceleration() async {
    await setHardwareAccelerationEnabled(!snapshot.hardwareAccelerationEnabled);
  }

  Future<void> _reconfigureEngine({
    required PlaybackSettings nextSettings,
    required bool shouldSkip,
  }) async {
    _ensureNotDisposed();
    if (shouldSkip) return;

    _settings = await _settingsDao.saveSettings(nextSettings);

    final activeMedia = snapshot.currentMedia;
    final resumeAt = snapshot.position;
    final wasPlaying = snapshot.isPlaying;

    await flushWatchProgress();
    _stopProgressTimer();
    _cancelSubscriptions();

    await _player?.dispose();
    _player = null;
    _videoController = null;

    await _createEngine();
    _emitSnapshot(
      snapshot.copyWith(
        useLibass: _settings.useLibass,
        hardwareAccelerationEnabled: _settings.hardwareAccelerationEnabled,
      ),
    );

    if (activeMedia != null) {
      await openMedia(
        MediaPlaybackRequest(
          mediaKey: activeMedia.mediaKey,
          uriOrPath: activeMedia.uriOrPath,
          title: activeMedia.title,
          folderPath: activeMedia.folderPath,
          fileSizeBytes: activeMedia.fileSizeBytes,
          initialPosition: resumeAt,
          isAudioOnly: activeMedia.isAudioOnly,
        ),
        autoPlay: wasPlaying,
      );
    }
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (_isDisposed) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      await flushWatchProgress();
      final allowBackground =
          snapshot.isBackgroundAudioEnabled || snapshot.isInPipMode;
      if (snapshot.isPlaying && !allowBackground) {
        _pauseDueToBackground = true;
        await _player?.pause();
      }
      if (!snapshot.isInPipMode) {
        await _syncWakelock(false);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_pauseDueToBackground) {
        _pauseDueToBackground = false;
        await _player?.play();
      }
      if (snapshot.isPlaying && !snapshot.isBackgroundAudioEnabled) {
        await _syncWakelock(true);
      }
    }
  }

  @override
  Future<void> flushWatchProgress() async {
    final media = snapshot.currentMedia;
    if (media == null) return;

    final incrementCount = _incrementPlayCountOnCurrentMedia;
    _incrementPlayCountOnCurrentMedia = false;

    await _watchHistoryDao.saveProgress(
      mediaKey: media.mediaKey,
      filePath: media.uriOrPath,
      title: media.title,
      folderPath: media.folderPath,
      fileSizeBytes: media.fileSizeBytes,
      position: snapshot.position,
      duration: snapshot.duration,
      playbackSpeed: snapshot.playbackSpeed,
      aspectRatioMode: snapshot.aspectRatioMode,
      audioTrackId: snapshot.selectedAudioTrackId,
      subtitleTrackId: snapshot.selectedSubtitleTrackId,
      subtitleDelayMs: snapshot.subtitleDelay.inMilliseconds,
      incrementPlayCount: incrementCount,
    );
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    await flushWatchProgress();
    _isDisposed = true;
    _stopProgressTimer();
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _cancelSubscriptions();
    await _syncWakelock(false);
    await _backgroundAudioController.clear();
    await _player?.dispose();
    _player = null;
    _videoController = null;
    await _snapshotController.close();
    _snapshotNotifier.dispose();
  }

  Future<void> _onPlayingChanged(bool playing) async {
    _emitSnapshot(
      snapshot.copyWith(
        isPlaying: playing,
        isCompleted: playing ? false : snapshot.isCompleted,
      ),
    );
    await _syncWakelock(playing);
    await _syncBackgroundAudioState();
    if (!playing) {
      await flushWatchProgress();
    }
  }

  Future<void> _onCompletedChanged(bool completed) async {
    if (completed &&
        snapshot.abLoop.isActive &&
        snapshot.abLoop.pointA != null) {
      await seekTo(snapshot.abLoop.pointA!);
      await play();
      return;
    }

    final shouldClearSleep = completed && snapshot.sleepAfterCurrentVideo;
    _emitSnapshot(
      snapshot.copyWith(
        isCompleted: completed,
        isPlaying: completed ? false : snapshot.isPlaying,
        sleepAfterCurrentVideo: shouldClearSleep
            ? false
            : snapshot.sleepAfterCurrentVideo,
      ),
    );

    if (completed) {
      await _syncWakelock(false);
      await _syncBackgroundAudioState();
      final media = snapshot.currentMedia;
      if (media != null) {
        await _watchHistoryDao.saveProgress(
          mediaKey: media.mediaKey,
          filePath: media.uriOrPath,
          title: media.title,
          folderPath: media.folderPath,
          fileSizeBytes: media.fileSizeBytes,
          position: snapshot.duration,
          duration: snapshot.duration,
          playbackSpeed: snapshot.playbackSpeed,
          aspectRatioMode: snapshot.aspectRatioMode,
          audioTrackId: snapshot.selectedAudioTrackId,
          subtitleTrackId: snapshot.selectedSubtitleTrackId,
          subtitleDelayMs: snapshot.subtitleDelay.inMilliseconds,
          forceWatched: true,
        );
      }
    }
  }

  void _onPositionChanged(Duration position) {
    _emitSnapshot(snapshot.copyWith(position: position));

    final loop = snapshot.abLoop;
    if (loop.shouldLoopAt(position) && loop.pointA != null) {
      final now = DateTime.now();
      if (now.difference(_lastLoopJumpAt) > const Duration(milliseconds: 300)) {
        _lastLoopJumpAt = now;
        unawaited(seekTo(loop.pointA!));
      }
    }
  }

  Future<void> _onDurationChanged(Duration duration) async {
    _emitSnapshot(snapshot.copyWith(duration: duration));
    if (duration > Duration.zero) {
      await _applyPendingResumeSeek();
      await _attachPendingExternalSubtitleIfReady();
      if (snapshot.currentMedia != null) {
        await _syncBackgroundAudioMedia(snapshot.currentMedia!, duration);
      }
    }
  }

  Future<void> _applyPendingResumeSeek() async {
    final pendingPos = _pendingResumePosition;
    if (pendingPos == null) return;
    _pendingResumePosition = null;
    await seekTo(pendingPos);
  }

  Future<void> _attachPendingExternalSubtitleIfReady() async {
    final pendingExt = _pendingExternalSubtitle;
    if (pendingExt == null) return;
    _pendingExternalSubtitle = null;
    if (await File(pendingExt.localFilePath).exists()) {
      await attachExternalSubtitle(
        filePath: pendingExt.localFilePath,
        title: pendingExt.fileName,
        languageCode: pendingExt.languageCode,
        languageName: pendingExt.languageName,
        source: pendingExt.source,
        externalId: pendingExt.externalId,
        movieHash: pendingExt.movieHash,
        persistInDb: false,
      );
    }
  }

  Future<void> _onTracksChanged(Tracks tracks) async {
    final mappedVideo = tracks.video
        .map(
          (t) => MediaTrackInfo(
            id: t.id,
            kind: MediaTrackKind.video,
            title: t.title,
            languageCode: t.language,
            codec: t.codec,
            width: t.w,
            height: t.h,
            isDefault: t.isDefault ?? false,
          ),
        )
        .toList(growable: false);

    final mappedAudio = tracks.audio
        .map(
          (t) => MediaTrackInfo(
            id: t.id,
            kind: MediaTrackKind.audio,
            title: t.title,
            languageCode: t.language,
            codec: t.codec,
            channels: t.channels,
            isDefault: t.isDefault ?? false,
            isExternal: t.uri,
          ),
        )
        .toList(growable: false);

    final mappedSubs = tracks.subtitle
        .map(
          (t) => MediaTrackInfo(
            id: t.id,
            kind: MediaTrackKind.subtitle,
            title: t.title,
            languageCode: t.language,
            codec: t.codec,
            isDefault: t.isDefault ?? false,
            isExternal: t.uri || t.data,
          ),
        )
        .toList(growable: false);

    _emitSnapshot(
      snapshot.copyWith(
        videoTracks: mappedVideo,
        audioTracks: mappedAudio,
        subtitleTracks: mappedSubs,
      ),
    );

    await _applyPendingTrackSelections(mappedAudio, mappedSubs);
  }

  Future<void> _applyPendingTrackSelections(
    List<MediaTrackInfo> audioTracks,
    List<MediaTrackInfo> subtitleTracks,
  ) async {
    final pendingAudio = _pendingAudioTrackId;
    if (pendingAudio != null &&
        audioTracks.any((t) => t.id == pendingAudio)) {
      _pendingAudioTrackId = null;
      await selectAudioTrack(pendingAudio);
    }

    if (_pendingExternalSubtitle != null &&
        (snapshot.duration > Duration.zero ||
            audioTracks.length > 2 ||
            subtitleTracks.length > 2)) {
      await _attachPendingExternalSubtitleIfReady();
      return;
    }

    final pendingSub = _pendingEmbeddedSubtitleId;
    if (pendingSub != null &&
        subtitleTracks.any((t) => t.id == pendingSub)) {
      _pendingEmbeddedSubtitleId = null;
      await selectSubtitleTrack(pendingSub);
    }
  }

  void _onSelectedTrackChanged(Track track) {
    final activeSaved = snapshot.savedSubtitles
        .where((s) => s.isActive)
        .firstOrNull;
    final subId =
        (track.subtitle.uri || track.subtitle.data) && activeSaved != null
        ? _externalTrackId(activeSaved)
        : track.subtitle.id;

    _emitSnapshot(
      snapshot.copyWith(
        selectedAudioTrackId: track.audio.id,
        selectedSubtitleTrackId: subId,
      ),
    );
  }

  Future<void> _syncBackgroundAudioMedia(
    MediaPlaybackRequest media,
    Duration duration,
  ) async {
    if (!snapshot.isBackgroundAudioEnabled) return;
    await _backgroundAudioController.updateMedia(
      id: media.mediaKey,
      title: media.title,
      album: media.folderPath.isNotEmpty
          ? p.basename(media.folderPath)
          : AppConfig.appName,
      duration: duration,
    );
  }

  Future<void> _syncBackgroundAudioState() async {
    if (!snapshot.isBackgroundAudioEnabled || !snapshot.hasMedia) return;
    await _backgroundAudioController.updateState(
      isPlaying: snapshot.isPlaying,
      isBuffering: snapshot.isBuffering,
      isCompleted: snapshot.isCompleted,
      position: snapshot.position,
      speed: snapshot.playbackSpeed,
    );
  }

  String _externalTrackId(SavedSubtitle sub) => 'ext:${sub.localFilePath}';

  Duration _clampDuration(Duration target, Duration maxDuration) {
    if (target <= Duration.zero) return Duration.zero;
    if (maxDuration > Duration.zero && target > maxDuration) {
      return maxDuration;
    }
    return target;
  }

  Future<void> _syncWakelock(bool shouldKeepAwake) async {
    if (_wakelockActive == shouldKeepAwake) return;
    _wakelockActive = shouldKeepAwake;
    await _wakelockGateway.setEnabled(shouldKeepAwake);
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressSaveTimer = Timer.periodic(AppConfig.progressSaveInterval, (_) {
      if (snapshot.isPlaying && snapshot.currentMedia != null) {
        unawaited(flushWatchProgress());
      }
    });
  }

  void _stopProgressTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
  }

  void _cancelSubscriptions() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
  }

  void _emitSnapshot(PlayerSnapshot next) {
    if (_isDisposed) return;
    _snapshotNotifier.value = next;
    if (!_snapshotController.isClosed) {
      _snapshotController.add(next);
    }
  }

  Player _requirePlayer() {
    final player = _player;
    if (player == null) {
      throw const PlaybackException(
        'PlayerService has not been initialized yet.',
      );
    }
    return player;
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw const PlaybackException('PlayerService has already been disposed.');
    }
  }
}
