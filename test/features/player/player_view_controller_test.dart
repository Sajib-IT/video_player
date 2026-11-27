import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/features/player/domain/ab_loop_range.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/domain/player_snapshot.dart';
import 'package:video_player_app/features/player/presentation/player_hud_state.dart';
import 'package:video_player_app/features/player/presentation/player_view_controller.dart';
import 'package:video_player_app/features/player/services/device_control_service.dart';
import 'package:video_player_app/features/player/services/pip_service.dart';
import 'package:video_player_app/features/player/services/player_service.dart';

class _FakeDeviceControlService implements DeviceControlService {
  double brightness = 0.5;
  double systemVolume = 0.5;
  bool resetBrightnessCalled = false;

  @override
  Future<double> getBrightness() async => brightness;

  @override
  Future<void> setBrightness(double value) async {
    brightness = value.clamp(0.0, 1.0);
  }

  @override
  Future<void> resetBrightness() async {
    resetBrightnessCalled = true;
  }

  @override
  Future<double> getSystemVolume() async => systemVolume;

  @override
  Future<void> setSystemVolume(double value) async {
    systemVolume = value.clamp(0.0, 1.0);
  }
}

class _SpyPlayerService implements PlayerService {
  final ValueNotifier<PlayerSnapshot> _notifier = ValueNotifier(
    const PlayerSnapshot(
      isEngineReady: true,
      isPlaying: true,
      position: Duration(seconds: 60),
      duration: Duration(minutes: 10),
      maxVolumePercent: 200.0,
    ),
  );
  final StreamController<PlayerSnapshot> _stream =
      StreamController<PlayerSnapshot>.broadcast();

  final List<Duration> seekToCalls = <Duration>[];
  final List<Duration> seekByCalls = <Duration>[];
  final List<double> playerVolumeCalls = <double>[];

  void emit(PlayerSnapshot next) {
    _notifier.value = next;
    _stream.add(next);
  }

  @override
  ValueListenable<PlayerSnapshot> get snapshotListenable => _notifier;

  @override
  Stream<PlayerSnapshot> get snapshotStream => _stream.stream;

  @override
  PlayerSnapshot get snapshot => _notifier.value;

  @override
  VideoController? get videoController => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> openMedia(
    MediaPlaybackRequest request, {
    bool autoPlay = true,
  }) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> playOrPause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seekTo(Duration position) async {
    seekToCalls.add(position);
    emit(snapshot.copyWith(position: position));
  }

  @override
  Future<void> seekBy(Duration delta) async {
    seekByCalls.add(delta);
    emit(snapshot.copyWith(position: snapshot.position + delta));
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setPlayerVolume(double volumePercent) async {
    playerVolumeCalls.add(volumePercent);
    emit(snapshot.copyWith(playerVolumePercent: volumePercent));
  }

  @override
  Future<void> setAspectRatioMode(AspectRatioMode mode) async {
    emit(snapshot.copyWith(aspectRatioMode: mode));
  }

  @override
  Future<void> cycleAspectRatioMode() async {
    await setAspectRatioMode(snapshot.aspectRatioMode.next());
  }

  @override
  void setTouchLocked(bool locked) {
    emit(snapshot.copyWith(isTouchLocked: locked));
  }

  @override
  void toggleTouchLock() => setTouchLocked(!snapshot.isTouchLocked);

  @override
  Future<void> setLoopPointA([Duration? position]) async {}

  @override
  Future<void> setLoopPointB([Duration? position]) async {}

  @override
  Future<void> toggleABLoop() async {
    emit(
      snapshot.copyWith(
        abLoop: const ABLoopRange(pointA: Duration(seconds: 15)),
      ),
    );
  }

  @override
  Future<void> clearABLoop() async {}

  @override
  Future<void> selectAudioTrack(String trackId) async {}

  @override
  Future<void> selectSubtitleTrack(String trackId) async {}

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> disableSubtitles() async {}

  @override
  Future<void> setSubtitleDelay(Duration delay) async {}

  @override
  Future<void> stepSubtitleDelay(Duration delta) async {}

  @override
  Future<void> setSubtitleScale(double scale) async {}

  @override
  Future<void> setSubtitleFontSize(double fontSize) async {}

  @override
  Future<void> setMuted(bool muted) async {
    emit(snapshot.copyWith(isMuted: muted));
  }

  @override
  Future<void> toggleMute() async => setMuted(!snapshot.isMuted);

  @override
  Future<void> setNightModeEnabled(bool enabled) async {
    emit(snapshot.copyWith(isNightMode: enabled));
  }

  @override
  Future<void> toggleNightMode() async =>
      setNightModeEnabled(!snapshot.isNightMode);

  @override
  Future<void> setBackgroundAudioEnabled(bool enabled) async {
    emit(snapshot.copyWith(isBackgroundAudioEnabled: enabled));
  }

  @override
  Future<void> toggleBackgroundAudio() async =>
      setBackgroundAudioEnabled(!snapshot.isBackgroundAudioEnabled);

  @override
  void setInPipMode(bool inPipMode) {
    emit(snapshot.copyWith(isInPipMode: inPipMode));
  }

  @override
  Future<void> setSleepTimer(Duration? duration) async {
    emit(snapshot.copyWith(sleepTimerRemaining: duration));
  }

  @override
  Future<void> setSleepAfterCurrentVideo() async {
    emit(snapshot.copyWith(sleepAfterCurrentVideo: true));
  }

  @override
  Future<void> cancelSleepTimer() async {
    emit(
      snapshot.copyWith(
        clearSleepTimerRemaining: true,
        sleepAfterCurrentVideo: false,
      ),
    );
  }

  @override
  Future<String?> captureScreenshot() async => '/tmp/shot_1.png';

  @override
  Future<void> setHardwareAccelerationEnabled(bool enabled) async {
    emit(snapshot.copyWith(hardwareAccelerationEnabled: enabled));
  }

  @override
  Future<void> toggleHardwareAcceleration() async =>
      setHardwareAccelerationEnabled(!snapshot.hardwareAccelerationEnabled);

  @override
  Future<void> setLibassEnabled(bool enabled) async {}

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {}

  @override
  Future<void> flushWatchProgress() async {}

  @override
  Future<void> dispose() async {
    await _stream.close();
    _notifier.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDeviceControlService deviceControls;
  late _SpyPlayerService playerService;
  late PlayerViewController viewController;

  setUp(() async {
    deviceControls = _FakeDeviceControlService();
    playerService = _SpyPlayerService();
    viewController = PlayerViewController(
      playerService: playerService,
      deviceControlService: deviceControls,
    );
    await viewController.initialize();
  });

  tearDown(() async {
    viewController.dispose();
    await playerService.dispose();
  });

  test('left vertical swipe adjusts brightness and resets on dispose', () async {
    await viewController.onVerticalDragStart(isLeftHalf: true);
    await viewController.onVerticalDragUpdate(deltaDy: -130, viewportHeight: 400);

    expect(deviceControls.brightness, greaterThan(0.9));
    expect(viewController.hudState.type, HudFeedbackType.brightness);

    viewController.onVerticalDragEnd();
    viewController.dispose();
    expect(deviceControls.resetBrightnessCalled, isTrue);
  });

  test('right vertical swipe adjusts volume then engages >100% boost', () async {
    await viewController.onVerticalDragStart(isLeftHalf: false);
    // Swipe up strongly from 50% into boost zone (>100%)
    await viewController.onVerticalDragUpdate(deltaDy: -200, viewportHeight: 400);

    expect(deviceControls.systemVolume, 1.0);
    expect(playerService.snapshot.playerVolumePercent, greaterThan(100.0));
    expect(viewController.hudState.type, HudFeedbackType.volume);
    expect(viewController.hudState.isAudioBoosted, isTrue);
  });

  test('horizontal swipe previews seek and seeks on release', () async {
    viewController.onHorizontalDragStart();
    viewController.onHorizontalDragUpdate(deltaDx: 200, viewportWidth: 800);

    expect(viewController.hudState.type, HudFeedbackType.seekPreview);
    expect(viewController.hudState.seekDelta, const Duration(milliseconds: 22500));

    await viewController.onHorizontalDragEnd();
    expect(
      playerService.seekToCalls.last,
      const Duration(milliseconds: 82500),
    );
  });

  test('double tap seeks +-10s and accumulates consecutive taps', () async {
    await viewController.onDoubleTap(isRightHalf: true);
    await viewController.onDoubleTap(isRightHalf: true);

    expect(playerService.seekByCalls.length, 2);
    expect(viewController.hudState.type, HudFeedbackType.doubleTapSeek);
    expect(viewController.hudState.seekDelta, const Duration(seconds: 20));
  });

  test('Kids Touch Lock blocks gestures and shows unlock hint on tap', () async {
    viewController.toggleTouchLock();
    expect(playerService.snapshot.isTouchLocked, isTrue);
    expect(viewController.controlsVisible, isFalse);

    await viewController.onDoubleTap(isRightHalf: true);
    expect(playerService.seekByCalls, isEmpty);

    viewController.onSingleTap();
    expect(viewController.unlockHintVisible, isTrue);
  });

  test('toggles Mute, Night Mode, Background Audio, HW/SW, and 3-way Orientation', () async {
    await viewController.toggleMute();
    expect(playerService.snapshot.isMuted, isTrue);

    await viewController.toggleNightMode();
    expect(playerService.snapshot.isNightMode, isTrue);

    await viewController.toggleBackgroundAudio();
    expect(playerService.snapshot.isBackgroundAudioEnabled, isTrue);

    await viewController.toggleHardwareDecoder();
    expect(playerService.snapshot.hardwareAccelerationEnabled, isFalse);

    expect(viewController.orientationMode, OrientationMode.autoSensor);
    await viewController.toggleOrientation();
    expect(viewController.orientationMode, OrientationMode.landscape);
    await viewController.toggleOrientation();
    expect(viewController.orientationMode, OrientationMode.portrait);
    await viewController.toggleOrientation();
    expect(viewController.orientationMode, OrientationMode.autoSensor);
  });

  test('enterPipMode sets isInPipMode optimistically and reverts on failure', () async {
    final pipStream = StreamController<bool>.broadcast();
    final fakePip = _FakePipService(
      supported: true,
      enterResult: true,
      stream: pipStream.stream,
    );
    final pipController = PlayerViewController(
      playerService: playerService,
      deviceControlService: deviceControls,
      pipService: fakePip,
    );
    await pipController.initialize();
    expect(pipController.isPipSupported, isTrue);

    await pipController.enterPipMode();
    expect(playerService.snapshot.isInPipMode, isTrue);

    pipStream.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(playerService.snapshot.isInPipMode, isFalse);

    fakePip.enterResult = false;
    await pipController.enterPipMode();
    expect(playerService.snapshot.isInPipMode, isFalse);

    pipController.dispose();
    await pipStream.close();
  });
}

class _FakePipService implements PipService {
  final bool supported;
  bool enterResult;
  final Stream<bool> stream;

  _FakePipService({
    required this.supported,
    required this.enterResult,
    required this.stream,
  });

  @override
  Stream<bool> get isInPipModeStream => stream;

  @override
  Future<bool> isPipSupported() async => supported;

  @override
  Future<bool> enterPipMode({int width = 16, int height = 9}) async =>
      enterResult;
}
