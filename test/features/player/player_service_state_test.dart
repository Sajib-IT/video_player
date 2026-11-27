import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/saved_subtitle_dao.dart';
import 'package:video_player_app/data/local/dao/watch_history_dao.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/services/media_kit_player_service.dart';
import 'package:video_player_app/features/player/services/player_service.dart';

class _FakeWakelockGateway implements WakelockGateway {
  final List<bool> events = <bool>[];
  bool current = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    current = enabled;
    events.add(enabled);
  }
}

class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer({required super.configuration});

  final List<Duration> seekCalls = <Duration>[];
  final List<SubtitleTrack> subtitleCalls = <SubtitleTrack>[];
  double lastSetVolume = 100.0;
  double lastSetRate = 1.0;
  bool disposed = false;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    state = state.copyWith(playing: play, completed: false);
    playingController.add(play);
    completedController.add(false);
  }

  @override
  Future<void> play() async {
    state = state.copyWith(playing: true, completed: false);
    playingController.add(true);
    completedController.add(false);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> playOrPause() async {
    if (state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> stop() async {
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> seek(Duration duration) async {
    seekCalls.add(duration);
    state = state.copyWith(position: duration, completed: false);
    positionController.add(duration);
  }

  @override
  Future<void> setRate(double rate) async {
    lastSetRate = rate;
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    lastSetVolume = volume;
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    state = state.copyWith(track: state.track.copyWith(audio: track));
    trackController.add(state.track);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    subtitleCalls.add(track);
    state = state.copyWith(track: state.track.copyWith(subtitle: track));
    trackController.add(state.track);
  }

  void emitDuration(Duration duration) {
    state = state.copyWith(duration: duration);
    durationController.add(duration);
  }

  void emitPosition(Duration position) {
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  void emitTracks(Tracks tracks) {
    state = state.copyWith(tracks: tracks);
    tracksController.add(tracks);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

void main() {
  sqfliteFfiInit();

  late DatabaseHelper dbHelper;
  late WatchHistoryDao historyDao;
  late PlaybackSettingsDao settingsDao;
  late SavedSubtitleDao subtitleDao;
  late _FakeWakelockGateway wakelock;
  late _FakePlatformPlayer fakePlatform;
  late MediaKitPlayerService service;

  setUp(() async {
    dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await dbHelper.database;
    historyDao = WatchHistoryDao(dbHelper: dbHelper);
    settingsDao = PlaybackSettingsDao(dbHelper: dbHelper);
    subtitleDao = SavedSubtitleDao(dbHelper: dbHelper);
    wakelock = _FakeWakelockGateway();

    service = MediaKitPlayerService(
      watchHistoryDao: historyDao,
      settingsDao: settingsDao,
      savedSubtitleDao: subtitleDao,
      wakelockGateway: wakelock,
      attachVideoController: false,
      playerFactory: (config) {
        fakePlatform = _FakePlatformPlayer(configuration: config);
        return Player(configuration: config, platformPlayer: fakePlatform);
      },
    );
    await service.initialize();
  });

  tearDown(() async {
    await service.dispose();
    await dbHelper.close();
  });

  test('resumes saved position, clamps speed/boost, and manages wakelock', () async {
    final request = MediaPlaybackRequest.fromFilePath('/videos/movie.mkv');
    await historyDao.saveProgress(
      mediaKey: request.mediaKey,
      filePath: request.uriOrPath,
      title: request.title,
      position: const Duration(minutes: 15),
      duration: const Duration(minutes: 90),
      playbackSpeed: 1.5,
      aspectRatioMode: AspectRatioMode.fill,
    );

    await service.openMedia(request);
    fakePlatform.emitDuration(const Duration(minutes: 90));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakePlatform.seekCalls, contains(const Duration(minutes: 15)));
    expect(service.snapshot.playbackSpeed, 1.5);
    expect(service.snapshot.aspectRatioMode, AspectRatioMode.fill);
    expect(wakelock.current, isTrue);

    await service.setPlaybackSpeed(5.0);
    expect(service.snapshot.playbackSpeed, 5.0);

    await service.setPlaybackSpeed(12.0);
    expect(service.snapshot.playbackSpeed, 8.0);

    await service.setPlayerVolume(175.0);
    expect(service.snapshot.playerVolumePercent, 175.0);
    expect(service.snapshot.isAudioBoosted, isTrue);

    await service.handleAppLifecycleState(AppLifecycleState.paused);
    expect(wakelock.current, isFalse);
    expect(service.snapshot.isPlaying, isFalse);
  });

  test('attaches external subtitle, persists metadata, and steps delay', () async {
    final tempDir = await Directory.systemTemp.createTemp('sub_attach_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final srtFile = File('${tempDir.path}/movie.bn.srt')
      ..writeAsStringSync('1\n00:00:01,000 --> 00:00:02,000\nহ্যালো\n');

    final request = MediaPlaybackRequest.fromFilePath('/videos/movie.mkv');
    await service.openMedia(request);
    fakePlatform.emitTracks(
      const Tracks(
        audio: <AudioTrack>[AudioTrack('1', 'English', 'eng')],
        subtitle: <SubtitleTrack>[SubtitleTrack('1', 'English', 'eng')],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final saved = await service.attachExternalSubtitle(
      filePath: srtFile.path,
      languageCode: 'bn',
      languageName: 'Bengali',
    );

    expect(saved.languageCode, 'bn');
    expect(service.snapshot.savedSubtitles.length, 1);
    expect(fakePlatform.subtitleCalls.last.uri, isTrue);

    await service.stepSubtitleDelay(const Duration(milliseconds: 300));
    expect(service.snapshot.subtitleDelay, const Duration(milliseconds: 300));

    final persisted = await subtitleDao.getActiveForMedia(request.mediaKey);
    expect(persisted?.delayMs, 300);

    await service.disableSubtitles();
    expect(service.snapshot.selectedSubtitleTrackId, 'no');
  });

  test('A-B loop jumps back to point A when position reaches point B', () async {
    await service.openMedia(
      MediaPlaybackRequest.fromFilePath('/videos/loop.mp4'),
    );
    fakePlatform.emitDuration(const Duration(minutes: 5));
    await service.setLoopPointA(const Duration(seconds: 10));
    await service.setLoopPointB(const Duration(seconds: 25));

    expect(service.snapshot.abLoop.isActive, isTrue);
    fakePlatform.seekCalls.clear();

    fakePlatform.emitPosition(const Duration(seconds: 26));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakePlatform.seekCalls, contains(const Duration(seconds: 10)));
  });

  test('manages Quick Mute, Night Mode, Background Audio, and Sleep Timer', () async {
    await service.openMedia(
      MediaPlaybackRequest.fromFilePath('/videos/night.mkv'),
    );

    await service.toggleMute();
    expect(service.snapshot.isMuted, isTrue);
    await service.toggleMute();
    expect(service.snapshot.isMuted, isFalse);

    await service.toggleNightMode();
    expect(service.snapshot.isNightMode, isTrue);

    await service.toggleBackgroundAudio();
    expect(service.snapshot.isBackgroundAudioEnabled, isTrue);
    // Pausing when app backgrounds must NOT pause playback if background audio is enabled.
    await service.handleAppLifecycleState(AppLifecycleState.paused);
    expect(service.snapshot.isPlaying, isTrue);

    await service.setSleepAfterCurrentVideo();
    expect(service.snapshot.sleepAfterCurrentVideo, isTrue);
    await service.setSleepTimer(const Duration(seconds: 5));
    expect(service.snapshot.sleepTimerRemaining, const Duration(seconds: 5));
    expect(service.snapshot.sleepAfterCurrentVideo, isFalse);

    await service.cancelSleepTimer();
    expect(service.snapshot.hasSleepTimer, isFalse);

    // Entering PiP must also preserve playback when Android pauses Activity.
    service.setInPipMode(true);
    await service.play();
    await service.handleAppLifecycleState(AppLifecycleState.paused);
    expect(service.snapshot.isPlaying, isTrue);
    service.setInPipMode(false);
  });

  test('sleep timer pauses active playback automatically when countdown expires', () async {
    await service.openMedia(
      MediaPlaybackRequest.fromFilePath('/videos/sleep.mkv'),
    );
    expect(service.snapshot.isPlaying, isTrue);

    await service.setSleepTimer(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(service.snapshot.hasSleepTimer, isFalse);
    expect(service.snapshot.isPlaying, isFalse);
  });
}
