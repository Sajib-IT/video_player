import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_app/app.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/data/local/dao/cached_video_dao.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/saved_subtitle_dao.dart';
import 'package:video_player_app/data/local/dao/watch_history_dao.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/playback_settings.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/data/local/models/vault_models.dart';
import 'package:video_player_app/features/library/data/local_video_scanner.dart';
import 'package:video_player_app/features/library/data/media_library_repository.dart';
import 'package:video_player_app/features/library/data/media_permission_service.dart';
import 'package:video_player_app/features/library/domain/library_permission_status.dart';
import 'package:video_player_app/features/library/domain/library_sort_option.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';
import 'package:video_player_app/features/library/presentation/library_controller.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/domain/player_snapshot.dart';
import 'package:video_player_app/features/player/presentation/player_screen.dart';
import 'package:video_player_app/features/player/services/device_control_service.dart';
import 'package:video_player_app/features/player/services/player_service.dart';
import 'package:video_player_app/features/subtitles/data/local_subtitle_picker.dart';
import 'package:video_player_app/features/subtitles/data/opensubtitles_api_client.dart';
import 'package:video_player_app/features/subtitles/data/subtitle_repository.dart';
import 'package:video_player_app/features/subtitles/domain/online_subtitle_result.dart';
import 'package:video_player_app/features/subtitles/domain/subtitle_search_query.dart';
import 'package:video_player_app/features/vault/data/vault_repository.dart';
import 'package:video_player_app/features/vault/presentation/vault_controller.dart';

class _StubPlayerService implements PlayerService {
  final ValueNotifier<PlayerSnapshot> _snapshot = ValueNotifier(
    const PlayerSnapshot(isEngineReady: true),
  );
  final StreamController<PlayerSnapshot> _stream =
      StreamController<PlayerSnapshot>.broadcast();

  @override
  ValueListenable<PlayerSnapshot> get snapshotListenable => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshotStream => _stream.stream;

  @override
  PlayerSnapshot get snapshot => _snapshot.value;

  @override
  VideoController? get videoController => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> openMedia(
    MediaPlaybackRequest request, {
    bool autoPlay = true,
  }) async {
    _snapshot.value = _snapshot.value.copyWith(
      currentMedia: request,
      isPlaying: autoPlay,
      duration: const Duration(minutes: 4),
      isBackgroundAudioEnabled:
          request.isAudioOnly || _snapshot.value.isBackgroundAudioEnabled,
    );
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> playOrPause() async {}

  @override
  Future<void> stop() async {
    _snapshot.value = _snapshot.value.copyWith(
      clearCurrentMedia: true,
      isPlaying: false,
    );
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> seekBy(Duration delta) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setPlayerVolume(double volumePercent) async {}

  @override
  Future<void> setAspectRatioMode(AspectRatioMode mode) async {}

  @override
  Future<void> cycleAspectRatioMode() async {}

  @override
  void setTouchLocked(bool locked) {
    _snapshot.value = _snapshot.value.copyWith(isTouchLocked: locked);
    _stream.add(_snapshot.value);
  }

  @override
  void toggleTouchLock() => setTouchLocked(!_snapshot.value.isTouchLocked);

  @override
  Future<void> setLoopPointA([Duration? position]) async {}

  @override
  Future<void> setLoopPointB([Duration? position]) async {}

  @override
  Future<void> toggleABLoop() async {}

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
  Future<void> setSubtitleDelay(Duration delay) async {
    _snapshot.value = _snapshot.value.copyWith(subtitleDelay: delay);
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> stepSubtitleDelay(Duration delta) async {
    await setSubtitleDelay(_snapshot.value.subtitleDelay + delta);
  }

  @override
  Future<void> setSubtitleScale(double scale) async {}

  @override
  Future<void> setSubtitleFontSize(double fontSize) async {}

  @override
  Future<void> setLibassEnabled(bool enabled) async {}

  @override
  Future<void> setMuted(bool muted) async {
    _snapshot.value = _snapshot.value.copyWith(isMuted: muted);
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> toggleMute() async => setMuted(!_snapshot.value.isMuted);

  @override
  Future<void> setNightModeEnabled(bool enabled) async {
    _snapshot.value = _snapshot.value.copyWith(isNightMode: enabled);
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> toggleNightMode() async =>
      setNightModeEnabled(!_snapshot.value.isNightMode);

  @override
  Future<void> setBackgroundAudioEnabled(bool enabled) async {
    _snapshot.value = _snapshot.value.copyWith(isBackgroundAudioEnabled: enabled);
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> toggleBackgroundAudio() async =>
      setBackgroundAudioEnabled(!_snapshot.value.isBackgroundAudioEnabled);

  @override
  void setInPipMode(bool inPipMode) {
    _snapshot.value = _snapshot.value.copyWith(isInPipMode: inPipMode);
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> setSleepTimer(Duration? duration) async {
    _snapshot.value = _snapshot.value.copyWith(sleepTimerRemaining: duration);
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> setSleepAfterCurrentVideo() async {
    _snapshot.value = _snapshot.value.copyWith(sleepAfterCurrentVideo: true);
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> cancelSleepTimer() async {
    _snapshot.value = _snapshot.value.copyWith(
      clearSleepTimerRemaining: true,
      sleepAfterCurrentVideo: false,
    );
    _stream.add(_snapshot.value);
  }

  @override
  Future<String?> captureScreenshot() async => null;

  @override
  Future<void> setHardwareAccelerationEnabled(bool enabled) async {
    _snapshot.value = _snapshot.value.copyWith(
      hardwareAccelerationEnabled: enabled,
    );
    _stream.add(_snapshot.value);
  }

  @override
  Future<void> toggleHardwareAcceleration() async =>
      setHardwareAccelerationEnabled(!_snapshot.value.hardwareAccelerationEnabled);

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {}

  @override
  Future<void> flushWatchProgress() async {}

  @override
  Future<void> dispose() async {
    await _stream.close();
    _snapshot.dispose();
  }
}

class _StaticPermissionService implements MediaPermissionService {
  @override
  Future<LibraryPermissionStatus> checkStatus() async =>
      LibraryPermissionStatus.granted;

  @override
  Future<LibraryPermissionStatus> requestPermission() async =>
      LibraryPermissionStatus.granted;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> presentLimitedSelection() async {}
}

class _StaticScanner implements LocalVideoScanner {
  const _StaticScanner();

  @override
  Future<List<VideoItem>> scanVideos() async => <VideoItem>[
    VideoItem(
      mediaKey: '/Movies/Demo.mkv',
      filePath: '/Movies/Demo.mkv',
      fileName: 'Demo.mkv',
      title: 'Demo Movie',
      folderPath: '/Movies',
      folderName: 'Movies',
      duration: const Duration(minutes: 42),
      sizeBytes: 1024 * 1024 * 250,
      modifiedAt: DateTime(2026, 2, 14),
    ),
    VideoItem(
      mediaKey: '/Music/Soundtrack.mp3',
      filePath: '/Music/Soundtrack.mp3',
      fileName: 'Soundtrack.mp3',
      title: 'Soundtrack Theme',
      folderPath: '/Music',
      folderName: 'Music',
      duration: const Duration(minutes: 4),
      sizeBytes: 1024 * 1024 * 6,
      modifiedAt: DateTime(2026, 2, 14),
      isAudioOnly: true,
    ),
  ];

  @override
  Future<VideoItem?> pickSingleVideoFile() async => null;
}

class _InMemoryRepo extends MediaLibraryRepository {
  _InMemoryRepo({
    required super.scanner,
    required super.watchHistoryDao,
    required super.cachedVideoDao,
    required super.settingsDao,
  });

  @override
  Future<LibrarySortOption> loadSortOption() async => const LibrarySortOption();

  @override
  Future<void> saveSortOption(LibrarySortOption sortOption) async {}

  @override
  Future<List<VideoItem>> loadCachedVideos() async => const <VideoItem>[];

  @override
  Future<List<VideoItem>> scanAndCacheVideos() =>
      const _StaticScanner().scanVideos();

  @override
  Future<List<VideoItem>> attachHistory(List<VideoItem> items) async => items;

  @override
  Future<PlaybackSettings> getSettings() async => PlaybackSettings.defaults();
}

class _NoopDeviceControlService implements DeviceControlService {
  const _NoopDeviceControlService();
  @override
  Future<double> getBrightness() async => 0.5;
  @override
  Future<double> getSystemVolume() async => 0.5;
  @override
  Future<void> resetBrightness() async {}
  @override
  Future<void> setBrightness(double brightness) async {}
  @override
  Future<void> setSystemVolume(double volume) async {}
}

class _StubOnlineSubClient implements OnlineSubtitleClient {
  @override
  Future<Uint8List> downloadFileBytes({
    required int fileId,
    required String apiKey,
  }) async => Uint8List(0);

  @override
  Future<List<OnlineSubtitleResult>> search({
    required SubtitleSearchQuery query,
    required String apiKey,
  }) async => const <OnlineSubtitleResult>[];
}

class _StubLocalSubPicker implements LocalSubtitlePicker {
  @override
  Future<PickedSubtitleFile?> pickSubtitleFile() async => null;
}

class _StubSubtitleRepository extends SubtitleRepository {
  _StubSubtitleRepository({
    required super.settingsDao,
    required super.savedSubtitleDao,
  }) : super(
         apiClient: _StubOnlineSubClient(),
         localPicker: _StubLocalSubPicker(),
       );

  @override
  Future<String?> computeMovieHash(String videoPath) async => null;

  @override
  Future<String> getEffectiveApiKey() async => '';

  @override
  Future<String> getEffectiveOpenAiApiKey() async => '';

  @override
  Future<String> getPreferredLanguageCode() async => 'en';
}

class _InMemoryVaultRepository implements VaultRepository {
  VaultConfig? _config;
  String? _pin;
  final List<VaultVideoRecord> _videos = <VaultVideoRecord>[];

  @override
  Future<VaultConfig?> getConfig() async => _config;

  @override
  Future<bool> isPinConfigured() async => _config != null;

  @override
  Future<bool> isBiometricAvailable() async => true;

  @override
  Future<void> setPin(String pin, {bool biometricEnabled = true}) async {
    _pin = pin.trim();
    _config = VaultConfig(
      pinHash: 'hash',
      pinSalt: 'salt',
      biometricEnabled: biometricEnabled,
      updatedAtMs: 1,
    );
  }

  @override
  Future<bool> verifyPin(String pin) async => _pin != null && pin.trim() == _pin;

  @override
  Future<void> setBiometricEnabled(bool enabled) async {}

  @override
  Future<bool> authenticateWithBiometrics() async => _config != null;

  @override
  Future<List<VaultVideoRecord>> getVaultVideos() async => List.of(_videos);

  @override
  Future<VaultVideoRecord> moveVideoToVault(VideoItem video) async {
    throw UnimplementedError();
  }

  @override
  Future<String> restoreVideoFromVault(VaultVideoRecord record) async => '';

  @override
  Future<void> deleteVaultVideo(VaultVideoRecord record) async {}
}

void main() {
  testWidgets('CineVaultApp renders LibraryScreen folders and All Videos toggle', (
    tester,
  ) async {
    final dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final playerService = _StubPlayerService();
    final libraryController = LibraryController(
      permissionService: _StaticPermissionService(),
      repository: _InMemoryRepo(
        scanner: _StaticScanner(),
        watchHistoryDao: WatchHistoryDao(dbHelper: dbHelper),
        cachedVideoDao: CachedVideoDao(dbHelper: dbHelper),
        settingsDao: PlaybackSettingsDao(dbHelper: dbHelper),
      ),
    );

    await tester.pumpWidget(
      CineVaultApp(
        playerService: playerService,
        databaseHelper: dbHelper,
        libraryController: libraryController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppConfig.appName), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);

    await tester.tap(find.text('All Videos'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Movie'), findsOneWidget);

    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    expect(find.text('Soundtrack Theme'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    libraryController.dispose();
  });

  testWidgets('PlayerScreen renders custom controls and Kids Touch Lock', (
    tester,
  ) async {
    final playerService = _StubPlayerService();
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          playerService: playerService,
          deviceControlService: const _NoopDeviceControlService(),
          request: MediaPlaybackRequest.fromFilePath('/Movies/Demo.mkv'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1x'), findsOneWidget);
    expect(find.text('Fit'), findsOneWidget);
    expect(find.text('A-B Loop'), findsOneWidget);
    expect(find.byTooltip('Quick Mute'), findsOneWidget);
    expect(find.byTooltip('Night Mode'), findsOneWidget);

    await tester.tap(find.byTooltip('Quick Mute'));
    await tester.pump();
    expect(playerService.snapshot.isMuted, isTrue);

    await tester.tap(find.byTooltip('Kids Touch Lock'));
    await tester.pump();

    expect(find.text('Touch Locked • Tap to Unlock'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await playerService.dispose();
  });

  testWidgets('SubtitleManagerSheet renders Tracks, Download, AI, and Sync & Style tabs', (
    tester,
  ) async {
    final dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final playerService = _StubPlayerService();
    final subRepo = _StubSubtitleRepository(
      settingsDao: PlaybackSettingsDao(dbHelper: dbHelper),
      savedSubtitleDao: SavedSubtitleDao(dbHelper: dbHelper),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          playerService: playerService,
          deviceControlService: const _NoopDeviceControlService(),
          subtitleRepository: subRepo,
          request: MediaPlaybackRequest.fromFilePath('/Movies/Demo.mkv'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Audio & Subtitles').first);
    await tester.pumpAndSettle();

    expect(find.text('Tracks'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('AI Subtitles'), findsOneWidget);
    expect(find.text('Sync & Style'), findsOneWidget);

    await tester.tap(find.text('Sync & Style'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+0.1s'));
    await tester.pump();
    expect(find.text('+0.1s'), findsWidgets);
    expect(playerService.snapshot.subtitleDelay, const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await playerService.dispose();
  });

  testWidgets('narrow 360x740 portrait screen renders without overflow, Vault PIN & Background Mini Player work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final playerService = _StubPlayerService();
    final vaultController = VaultController(repository: _InMemoryVaultRepository());
    final libraryController = LibraryController(
      permissionService: _StaticPermissionService(),
      repository: _InMemoryRepo(
        scanner: _StaticScanner(),
        watchHistoryDao: WatchHistoryDao(dbHelper: dbHelper),
        cachedVideoDao: CachedVideoDao(dbHelper: dbHelper),
        settingsDao: PlaybackSettingsDao(dbHelper: dbHelper),
      ),
    );

    await tester.pumpWidget(
      CineVaultApp(
        playerService: playerService,
        databaseHelper: dbHelper,
        libraryController: libraryController,
        vaultController: vaultController,
      ),
    );
    await tester.pumpAndSettle();

    // Open Vault tab and set up PIN
    await tester.tap(find.text('Vault'));
    await tester.pumpAndSettle();
    expect(find.text('Set Up Private Video Vault'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Create Vault PIN (4–8 digits)'),
      '4321',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm Vault PIN'),
      '4321',
    );
    await tester.tap(find.text('Create Vault PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Lock Vault'), findsOneWidget);

    // Lock Vault and test wrong PIN then right PIN
    await tester.tap(find.text('Lock Vault'));
    await tester.pumpAndSettle();
    expect(find.text('Private Vault Locked'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Vault PIN'),
      '9999',
    );
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect Vault PIN. Try again.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Vault PIN'),
      '4321',
    );
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Lock Vault'), findsOneWidget);

    // Switch to Audio and open PlayerScreen -> toggle Night Mode -> verify Background Audio & Mini Player Bar!
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soundtrack Theme'));
    await tester.pumpAndSettle();

    expect(find.text('Soundtrack Theme'), findsWidgets);
    expect(find.text('Audio Playback Mode'), findsOneWidget);
    expect(playerService.snapshot.isBackgroundAudioEnabled, isTrue);

    await tester.ensureVisible(find.byTooltip('Night Mode'));
    await tester.tap(find.byTooltip('Night Mode'));
    await tester.pump();
    expect(playerService.snapshot.isNightMode, isTrue);

    // Toggle Background Audio OFF then back ON
    await tester.ensureVisible(find.byTooltip('Background Audio'));
    await tester.tap(find.byTooltip('Background Audio'));
    await tester.pump();
    expect(playerService.snapshot.isBackgroundAudioEnabled, isFalse);
    await tester.tap(find.byTooltip('Background Audio'));
    await tester.pump();
    expect(playerService.snapshot.isBackgroundAudioEnabled, isTrue);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Audio Playback Mode'), findsNothing);
    expect(playerService.snapshot.currentMedia, isNotNull);
    expect(playerService.snapshot.isBackgroundAudioEnabled, isTrue);

    // Mini Player Bar remains visible because Background Audio was enabled.
    expect(find.byTooltip('Stop Background Playback'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop Background Playback'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Stop Background Playback'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    vaultController.dispose();
    libraryController.dispose();
  });
}
