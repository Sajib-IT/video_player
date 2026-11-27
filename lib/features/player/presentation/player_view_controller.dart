import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/features/player/presentation/player_hud_state.dart';
import 'package:video_player_app/features/player/services/device_control_service.dart';
import 'package:video_player_app/features/player/services/pip_service.dart';
import 'package:video_player_app/features/player/services/player_service.dart';

enum OrientationMode {
  autoSensor('Auto Rotate'),
  landscape('Landscape'),
  portrait('Portrait');

  final String label;

  const OrientationMode(this.label);
}

/// Coordinates player overlay visibility, auto-hide timer, swipe/tap gestures,
/// hardware brightness, system volume + software audio boost, orientation,
/// screenshot, Night Mode, Sleep Timer, Background Audio, and PiP.
class PlayerViewController extends ChangeNotifier {
  final PlayerService playerService;
  final DeviceControlService deviceControlService;
  final PipService pipService;

  static const Duration autoHideDuration = Duration(milliseconds: 3500);
  static const Duration hudLingerDuration = Duration(milliseconds: 1100);
  static const Duration _doubleTapResetWindow = Duration(milliseconds: 950);

  bool _controlsVisible = true;
  bool _showRemainingTime = false;
  OrientationMode _orientationMode = OrientationMode.autoSensor;
  bool _isScrubbing = false;
  bool _isModalOpen = false;
  bool _unlockHintVisible = false;
  bool _isPipSupported = false;
  PlayerHudState _hudState = PlayerHudState.hidden;

  double _cachedBrightness = 0.5;
  double _cachedSystemVolume = 0.5;
  double _unifiedVolumePercent = 50.0;

  bool _verticalDragLeft = true;
  double _horizontalDragStartMs = 0;
  double _horizontalAccumulatedDx = 0;
  Duration _horizontalPreviewTarget = Duration.zero;

  int _accumulatedDoubleTapSeconds = 0;
  bool? _lastDoubleTapForward;
  DateTime _lastDoubleTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _autoHideTimer;
  Timer? _hudTimer;
  Timer? _unlockHintTimer;
  StreamSubscription<dynamic>? _snapshotSub;
  StreamSubscription<bool>? _pipSub;
  bool _isDisposed = false;

  PlayerViewController({
    required this.playerService,
    DeviceControlService? deviceControlService,
    PipService? pipService,
  }) : deviceControlService =
           deviceControlService ?? const PluginDeviceControlService(),
       pipService = pipService ?? const MethodChannelPipService() {
    _snapshotSub = playerService.snapshotStream.listen((snapshot) {
      if (snapshot.isTouchLocked && _controlsVisible) {
        _controlsVisible = false;
        _autoHideTimer?.cancel();
        notifyListeners();
      }
      if (!snapshot.isPlaying && !_controlsVisible && !snapshot.isTouchLocked) {
        _autoHideTimer?.cancel();
      }
    });
    _pipSub = this.pipService.isInPipModeStream.listen((inPip) {
      playerService.setInPipMode(inPip);
      if (inPip) {
        _controlsVisible = false;
      }
      notifyListeners();
    });
  }

  bool get controlsVisible => _controlsVisible;
  bool get showRemainingTime => _showRemainingTime;
  OrientationMode get orientationMode => _orientationMode;
  bool get isLandscape => _orientationMode == OrientationMode.landscape;
  bool get isScrubbing => _isScrubbing;
  bool get unlockHintVisible => _unlockHintVisible;
  bool get isPipSupported => _isPipSupported;
  PlayerHudState get hudState => _hudState;

  Future<void> initialize() async {
    _cachedBrightness = await deviceControlService.getBrightness();
    _cachedSystemVolume = await deviceControlService.getSystemVolume();
    _isPipSupported = await pipService.isPipSupported();
    final playerBoost = playerService.snapshot.playerVolumePercent;
    _unifiedVolumePercent = playerBoost > 100.5
        ? playerBoost
        : (_cachedSystemVolume * 100.0);
    _scheduleAutoHide();
    notifyListeners();
  }

  void toggleRemainingTime() {
    _showRemainingTime = !_showRemainingTime;
    _scheduleAutoHide();
    notifyListeners();
  }

  void setModalOpen(bool open) {
    _isModalOpen = open;
    if (open) {
      _autoHideTimer?.cancel();
    } else {
      _scheduleAutoHide();
    }
  }

  void onScrubStart() {
    _isScrubbing = true;
    _autoHideTimer?.cancel();
    notifyListeners();
  }

  void onScrubEnd() {
    _isScrubbing = false;
    _scheduleAutoHide();
    notifyListeners();
  }

  void showControls() {
    if (playerService.snapshot.isTouchLocked ||
        playerService.snapshot.isInPipMode) {
      return;
    }
    _controlsVisible = true;
    _scheduleAutoHide();
    notifyListeners();
  }

  void hideControls() {
    if (!_controlsVisible) return;
    _controlsVisible = false;
    _autoHideTimer?.cancel();
    notifyListeners();
  }

  void onSingleTap() {
    if (playerService.snapshot.isInPipMode) return;
    if (playerService.snapshot.isTouchLocked) {
      _flashUnlockHint();
      return;
    }
    if (_controlsVisible) {
      hideControls();
    } else {
      showControls();
    }
  }

  Future<void> onDoubleTap({required bool isRightHalf}) async {
    if (playerService.snapshot.isTouchLocked ||
        playerService.snapshot.isInPipMode) {
      if (playerService.snapshot.isTouchLocked) _flashUnlockHint();
      return;
    }

    final now = DateTime.now();
    final sameDirection = _lastDoubleTapForward == isRightHalf;
    if (!sameDirection ||
        now.difference(_lastDoubleTapAt) > _doubleTapResetWindow) {
      _accumulatedDoubleTapSeconds = 0;
    }
    _lastDoubleTapForward = isRightHalf;
    _lastDoubleTapAt = now;

    final stepSeconds = AppConfig.doubleTapSeekStep.inSeconds;
    _accumulatedDoubleTapSeconds += isRightHalf ? stepSeconds : -stepSeconds;

    final delta = Duration(seconds: isRightHalf ? stepSeconds : -stepSeconds);
    await playerService.seekBy(delta);

    _showHud(
      PlayerHudState(
        type: HudFeedbackType.doubleTapSeek,
        seekDelta: Duration(seconds: _accumulatedDoubleTapSeconds),
        doubleTapForward: isRightHalf,
      ),
    );
    if (_controlsVisible) _scheduleAutoHide();
  }

  void onHorizontalDragStart() {
    if (playerService.snapshot.isTouchLocked) return;
    _autoHideTimer?.cancel();
    _horizontalAccumulatedDx = 0;
    _horizontalDragStartMs =
        playerService.snapshot.position.inMilliseconds.toDouble();
    _horizontalPreviewTarget = playerService.snapshot.position;
  }

  void onHorizontalDragUpdate({
    required double deltaDx,
    required double viewportWidth,
  }) {
    if (playerService.snapshot.isTouchLocked || viewportWidth <= 0) return;

    final durationMs =
        playerService.snapshot.duration.inMilliseconds.toDouble();
    _horizontalAccumulatedDx += deltaDx;

    final maxWindowMs = durationMs > 0 && durationMs < 90000
        ? durationMs
        : 90000.0;
    final offsetMs = (_horizontalAccumulatedDx / viewportWidth) * maxWindowMs;
    final rawTargetMs = _horizontalDragStartMs + offsetMs;
    final clampedMs = durationMs > 0
        ? rawTargetMs.clamp(0.0, durationMs)
        : rawTargetMs.clamp(0.0, double.infinity);

    _horizontalPreviewTarget = Duration(milliseconds: clampedMs.round());
    final delta = Duration(
      milliseconds: (_horizontalPreviewTarget.inMilliseconds -
          _horizontalDragStartMs.round()),
    );

    _hudState = PlayerHudState(
      type: HudFeedbackType.seekPreview,
      seekTarget: _horizontalPreviewTarget,
      seekDelta: delta,
      mediaDuration: playerService.snapshot.duration,
    );
    _hudTimer?.cancel();
    notifyListeners();
  }

  Future<void> onHorizontalDragEnd() async {
    if (playerService.snapshot.isTouchLocked) return;
    if (_hudState.type == HudFeedbackType.seekPreview) {
      await playerService.seekTo(_horizontalPreviewTarget);
      _scheduleHudHide();
    }
    _scheduleAutoHide();
  }

  Future<void> onVerticalDragStart({required bool isLeftHalf}) async {
    if (playerService.snapshot.isTouchLocked) return;
    _verticalDragLeft = isLeftHalf;
    _hudTimer?.cancel();

    if (_verticalDragLeft) {
      _cachedBrightness = await deviceControlService.getBrightness();
    } else {
      _cachedSystemVolume = await deviceControlService.getSystemVolume();
      final playerVol = playerService.snapshot.playerVolumePercent;
      _unifiedVolumePercent = playerVol > 100.5
          ? playerVol
          : (_cachedSystemVolume * 100.0);
    }
  }

  Future<void> onVerticalDragUpdate({
    required double deltaDy,
    required double viewportHeight,
  }) async {
    if (playerService.snapshot.isTouchLocked || viewportHeight <= 0) return;
    final sensitivityHeight = viewportHeight * 0.65;
    final normalizedDelta = -deltaDy / sensitivityHeight;

    if (_verticalDragLeft) {
      _cachedBrightness = (_cachedBrightness + normalizedDelta).clamp(0.0, 1.0);
      await deviceControlService.setBrightness(_cachedBrightness);
      _hudState = PlayerHudState(
        type: HudFeedbackType.brightness,
        brightness: _cachedBrightness,
      );
      notifyListeners();
      return;
    }

    final maxPercent = playerService.snapshot.maxVolumePercent;
    _unifiedVolumePercent =
        (_unifiedVolumePercent + normalizedDelta * maxPercent)
            .clamp(0.0, maxPercent);

    if (_unifiedVolumePercent <= 100.0) {
      _cachedSystemVolume = (_unifiedVolumePercent / 100.0).clamp(0.0, 1.0);
      await deviceControlService.setSystemVolume(_cachedSystemVolume);
      if (playerService.snapshot.playerVolumePercent != 100.0 ||
          playerService.snapshot.isMuted) {
        await playerService.setPlayerVolume(100.0);
      }
    } else {
      if (_cachedSystemVolume < 1.0) {
        _cachedSystemVolume = 1.0;
        await deviceControlService.setSystemVolume(1.0);
      }
      await playerService.setPlayerVolume(_unifiedVolumePercent);
    }

    _hudState = PlayerHudState(
      type: HudFeedbackType.volume,
      volumePercent: _unifiedVolumePercent,
    );
    notifyListeners();
  }

  void onVerticalDragEnd() {
    if (playerService.snapshot.isTouchLocked) return;
    _scheduleHudHide();
  }

  Future<void> cycleAspectRatio() async {
    await playerService.cycleAspectRatioMode();
    showTransientToast(
      'Aspect Ratio: ${playerService.snapshot.aspectRatioMode.label}',
    );
    _scheduleAutoHide();
  }

  Future<void> toggleMute() async {
    await playerService.toggleMute();
    showTransientToast(
      playerService.snapshot.isMuted ? 'Audio Muted' : 'Audio Unmuted',
    );
    _scheduleAutoHide();
  }

  Future<void> toggleNightMode() async {
    await playerService.toggleNightMode();
    showTransientToast(
      playerService.snapshot.isNightMode ? 'Night Mode ON' : 'Night Mode OFF',
    );
    _scheduleAutoHide();
  }

  Future<void> toggleBackgroundAudio() async {
    await playerService.toggleBackgroundAudio();
    showTransientToast(
      playerService.snapshot.isBackgroundAudioEnabled
          ? 'Background Audio ON'
          : 'Background Audio OFF',
    );
    _scheduleAutoHide();
  }

  Future<void> toggleHardwareDecoder() async {
    await playerService.toggleHardwareAcceleration();
    showTransientToast(
      playerService.snapshot.hardwareAccelerationEnabled
          ? 'Decoder: Hardware (HW+)'
          : 'Decoder: Software (SW)',
    );
    _scheduleAutoHide();
  }

  Future<void> captureScreenshot() async {
    try {
      final path = await playerService.captureScreenshot();
      if (path != null) {
        showTransientToast('Screenshot saved: ${p.basename(path)}');
      } else {
        showTransientToast('Unable to capture frame screenshot');
      }
    } catch (_) {
      showTransientToast('Screenshot unavailable for this stream');
    }
    _scheduleAutoHide();
  }

  Future<void> enterPipMode() async {
    final snap = playerService.snapshot;
    // Set PiP flag optimistically before native enterPictureInPictureMode so any
    // immediate AppLifecycleState.paused callback won't pause playback in PiP.
    if (_isPipSupported) {
      playerService.setInPipMode(true);
    }
    final ok = await pipService.enterPipMode(
      width: snap.videoWidth ?? 16,
      height: snap.videoHeight ?? 9,
    );
    if (!ok) {
      playerService.setInPipMode(false);
      showTransientToast('Picture-in-Picture requires Android 8.0+');
    }
  }

  Future<void> toggleABLoopAction() async {
    await playerService.toggleABLoop();
    final loop = playerService.snapshot.abLoop;
    if (loop.isActive && loop.pointA != null && loop.pointB != null) {
      showTransientToast(
        'A-B Loop: ${DurationFormatter.format(loop.pointA!)} → ${DurationFormatter.format(loop.pointB!)}',
      );
    } else if (loop.hasPointA && loop.pointA != null) {
      showTransientToast(
        'Loop Point A: ${DurationFormatter.format(loop.pointA!)} (Tap again for B)',
      );
    } else {
      showTransientToast('A-B Loop Cleared');
    }
    _scheduleAutoHide();
  }

  void toggleTouchLock() {
    playerService.toggleTouchLock();
    final locked = playerService.snapshot.isTouchLocked;
    if (locked) {
      _controlsVisible = false;
      _autoHideTimer?.cancel();
      _flashUnlockHint();
    } else {
      _unlockHintVisible = false;
      _unlockHintTimer?.cancel();
      showControls();
    }
    notifyListeners();
  }

  Future<void> toggleOrientation() async {
    final nextIndex = (_orientationMode.index + 1) % OrientationMode.values.length;
    _orientationMode = OrientationMode.values[nextIndex];
    notifyListeners();

    try {
      switch (_orientationMode) {
        case OrientationMode.autoSensor:
          await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
        case OrientationMode.landscape:
          await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        case OrientationMode.portrait:
          await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
            DeviceOrientation.portraitUp,
          ]);
      }
    } catch (_) {}
    showTransientToast('Orientation: ${_orientationMode.label}');
    _scheduleAutoHide();
  }

  Future<void> enterImmersiveMode() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: const <SystemUiOverlay>[],
      );
    } catch (_) {}
  }

  Future<void> restoreSystemChrome() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    } catch (_) {}
  }

  void showTransientToast(String message) {
    _showHud(
      PlayerHudState(type: HudFeedbackType.toast, toastMessage: message),
      duration: const Duration(milliseconds: 1600),
    );
  }

  void _flashUnlockHint() {
    _unlockHintVisible = true;
    _unlockHintTimer?.cancel();
    _unlockHintTimer = Timer(const Duration(milliseconds: 2500), () {
      if (_isDisposed) return;
      _unlockHintVisible = false;
      notifyListeners();
    });
    notifyListeners();
  }

  void _showHud(PlayerHudState state, {Duration duration = hudLingerDuration}) {
    _hudState = state;
    _scheduleHudHide(duration: duration);
    notifyListeners();
  }

  void _scheduleHudHide({Duration duration = hudLingerDuration}) {
    _hudTimer?.cancel();
    _hudTimer = Timer(duration, () {
      if (_isDisposed) return;
      _hudState = PlayerHudState.hidden;
      notifyListeners();
    });
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    if (!_controlsVisible ||
        _isScrubbing ||
        _isModalOpen ||
        playerService.snapshot.isTouchLocked ||
        !playerService.snapshot.isPlaying) {
      return;
    }

    _autoHideTimer = Timer(autoHideDuration, () {
      if (_isDisposed ||
          _isScrubbing ||
          _isModalOpen ||
          !playerService.snapshot.isPlaying) {
        return;
      }
      _controlsVisible = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _autoHideTimer?.cancel();
    _hudTimer?.cancel();
    _unlockHintTimer?.cancel();
    unawaited(_snapshotSub?.cancel());
    unawaited(_pipSub?.cancel());
    unawaited(deviceControlService.resetBrightness());
    super.dispose();
  }
}
